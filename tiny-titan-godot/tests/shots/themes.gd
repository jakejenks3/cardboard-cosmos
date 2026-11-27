extends RefCounted
## Switch through every theme the way Settings does and take a screenshot of the
## Hero tab and the lifting form in each. Checks the shell rebuilds cleanly.

func run(main: Node, tree: SceneTree) -> void:
	var fails = 0
	for id in Pal.THEME_ORDER:
		App.update_settings({"theme": id})
		await ShotHelper.wait(tree, 0.9)
		var ok = Pal.theme_id == id and ShotHelper.find_text(main, App.profile().name) != null
		if not ok:
			fails += 1
		print("CHECK %s  theme %s applied and the Hero tab is showing" % ["ok  " if ok else "FAIL", id])
		await ShotHelper.snap(tree, "theme_%s_home" % id)
		App.open_log("lift")
		await ShotHelper.wait(tree, 0.9)
		await ShotHelper.snap(tree, "theme_%s_log" % id)
		App.go("home")
		await ShotHelper.wait(tree, 0.5)
	# The choice is saved with the rest of the settings.
	var on_disk = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
	var saved_ok = on_disk != null and str(on_disk.settings.get("theme", "")) == Pal.THEME_ORDER[-1]
	if not saved_ok:
		fails += 1
	print("CHECK %s  the theme is saved" % ["ok  " if saved_ok else "FAIL"])
	App.update_settings({"theme": "arcade"})
	await ShotHelper.wait(tree, 0.6)
	print("THEMES DONE, failures: %d" % fails)
