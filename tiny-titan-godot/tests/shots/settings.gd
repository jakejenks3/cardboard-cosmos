extends RefCounted
## Settings walkthrough: open the sheet, change every setting, backup round trip, reset.


func _check(label: String, ok: bool) -> void:
	print(("CHECK OK   " if ok else "CHECK FAIL ") + label)


func _panel():
	for n in ShotHelper.walk(Kit.overlay_root):
		if n is SettingsPanel:
			return n
	return null


## The topmost open sheet.
func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


## Button whose text is exactly `t` inside the settings panel.
func _btn(t: String):
	for n in ShotHelper.walk(_panel()):
		if n is Button and n.text == t:
			return n
	return null


func run(main: Node, tree: SceneTree) -> void:
	App.update_settings({"weightUnit": "kg", "weightStep": 2.5})
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.4)
	var settings_sheet = _sheet()
	await ShotHelper.snap(tree, "settings_1")
	_sheet()._scroll.scroll_vertical = 2000
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "settings_2")
	_sheet()._scroll.scroll_vertical = 0

	# kg -> lb with 2.5 kg selected
	ShotHelper.press(_btn("lb"))
	await ShotHelper.frames(tree, 3)
	var st = App.settings()
	_check("lb selected, step %s valid" % str(st.get("weightStep")), st.weightUnit == "lb" and TTUtil.has_number(TT.WEIGHT_STEPS.lb, st.get("weightStep")) and TT.weight_step_of(st) == 2.5)
	ShotHelper.press(_btn("10 lb"))
	await ShotHelper.frames(tree, 3)
	_check("step 10 lb", float(App.settings().weightStep) == 10.0)
	ShotHelper.press(_btn("kg"))
	await ShotHelper.frames(tree, 3)
	ShotHelper.press(_btn("1 kg"))
	await ShotHelper.frames(tree, 3)
	ShotHelper.press(_btn("lb"))
	await ShotHelper.frames(tree, 3)
	_check("1 kg -> lb resets to 5 (got %s)" % str(App.settings().get("weightStep")), float(App.settings().weightStep) == 5.0)
	ShotHelper.press(_btn("mi"))
	ShotHelper.press(_btn("5"))
	await ShotHelper.frames(tree, 3)
	ShotHelper.press(_btn("Off"))
	await ShotHelper.frames(tree, 3)
	st = App.settings()
	_check("distance mi, weekly goal 5, sound off: %s" % str(st), st.distanceUnit == "mi" and int(st.weeklyGoal) == 5 and st.sound == false and Sfx.enabled == false)

	var edit = null
	for n in ShotHelper.walk(_panel()):
		if n is LineEdit:
			edit = n
			break
	ShotHelper.type_into(edit, "Bricktop")
	ShotHelper.press(_btn(HeroBody.HAIR_STYLES[4]))
	await ShotHelper.frames(tree, 3)
	var p = App.profile()
	_check("profile name/hair: %s" % str(p), p.name == "Bricktop" and int(p.hairStyle) == 4)
	App.update_profile({"skin": 3})
	await ShotHelper.wait(tree, 0.2)
	await ShotHelper.snap(tree, "settings_changed")

	# --- backup round trip (same calls as the buttons, without the file dialog)
	var path = OS.get_environment("TINY_TITAN_SHOTS").path_join("../backup.json")
	var n_sessions = App.sessions().size()
	var n_body = App.body().size()
	var err = App.export_backup(path)
	_check("export ok '%s'" % err, err == "")

	SettingsPanel.ask_reset(settings_sheet)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "settings_reset_confirm")
	_check("not wiped before confirming", App.sessions().size() == n_sessions)
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Reset"))
	await ShotHelper.wait(tree, 0.4)
	_check("still not wiped after first confirm", App.sessions().size() == n_sessions)
	await ShotHelper.snap(tree, "settings_reset_confirm_2")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Delete everything"))
	await ShotHelper.wait(tree, 0.5)
	_check("wiped after confirming (sessions %d, profile %s)" % [App.sessions().size(), str(App.profile())], App.sessions().is_empty() and App.body().is_empty())
	await ShotHelper.snap(tree, "settings_after_reset")

	SettingsPanel.confirm_import(path)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "settings_import_confirm")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Import"))
	await ShotHelper.wait(tree, 0.5)
	_check("restored %d/%d sessions, %d/%d check-ins" % [App.sessions().size(), n_sessions, App.body().size(), n_body], App.sessions().size() == n_sessions and App.body().size() == n_body)
	_check("profile restored", App.profile() != null and App.profile().name == "Bricktop")
	await ShotHelper.snap(tree, "settings_after_import")
