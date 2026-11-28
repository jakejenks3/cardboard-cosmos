extends RefCounted
## The one look (the Workshop, 2026-11-27): a save that still names one of the four old themes opens in it,
## and the Hero tab and the lifting form are snapped.

func run(main: Node, tree: SceneTree) -> void:
	var fails = 0
	for id in ["arcade", "ember"]:
		App.update_settings({"theme": id})
		await ShotHelper.wait(tree, 0.9)
		var ok = Pal.theme_id == "workshop" and ShotHelper.find_text(main, App.profile().name) != null
		if not ok:
			fails += 1
		print("CHECK %s  a save naming the old theme %s opens in the Workshop look, the Hero tab showing" % ["ok  " if ok else "FAIL", id])
	await ShotHelper.snap(tree, "theme_workshop_home")
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	await ShotHelper.snap(tree, "theme_workshop_log")
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("THEMES DONE, failures: %d" % fails)
