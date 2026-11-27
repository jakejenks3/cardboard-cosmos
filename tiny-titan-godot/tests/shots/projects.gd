extends RefCounted
## Climbing projects walkthrough: the Hero tab's card, picking a project in the
## sheet (the form stays put), a session that tries it, a session that sends
## its grade ("was it your project?" -> yes: gold, +XP), the sheet's Sent list,
## and the save keeping it all. Run with `year` data.

var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheet():
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			return c
	return null


func _close_sheets(tree: SceneTree) -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func _overlay(main: Node):
	for c in ShotHelper.walk(main):
		if c is ResultsOverlay:
			return c
	return null


func _wait_done(ov, tree: SceneTree) -> void:
	var t = 0.0
	while is_instance_valid(ov) and ov._phase != "done" and t < 40.0:
		await ShotHelper.wait(tree, 0.25)
		t += 0.25


func _climb(climbs: Array) -> Dictionary:
	return App.build_session({"discipline": "climb", "date": App.today, "climbs": climbs, "durationSec": 3600})


func run(main: Node, tree: SceneTree) -> void:
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var hint = ShotHelper.find_text(main, "A climb you cannot send yet")
	check(hint != null, "a climber with no project gets the card that offers one")
	if hint != null:
		ShotHelper.reveal(hint)
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "projects_01_card_empty")

	# --- pick a project in the sheet --------------------------------------------------
	ProjectsView.open()
	await ShotHelper.wait(tree, 0.6)
	var sh = _sheet()
	check(sh != null, "the sheet opens")
	if sh == null:
		return
	var add = ShotHelper.find_button(sh, "Add project")
	var y0 = add.global_position.y
	ShotHelper.press(ShotHelper.find_button(sh, "V6"))
	await ShotHelper.frames(tree, 3)
	var name_in = null
	for c in ShotHelper.walk(sh):
		if c is LineEdit:
			name_in = c
	ShotHelper.type_into(name_in, "Blue overhang")
	add = ShotHelper.find_button(sh, "Add project")
	check(absf(add.global_position.y - y0) < 1.0, "picking a grade does not move the Add key")
	ShotHelper.press(add)
	await ShotHelper.wait(tree, 0.4)
	add = ShotHelper.find_button(sh, "Add project")
	check(add != null and absf(add.global_position.y - y0) < 1.0, "adding one does not move the form either")
	var open_list = App.open_projects()
	check(open_list.size() == 1 and int(open_list[0].grade) == 6 and str(open_list[0].name) == "Blue overhang" and str(open_list[0].since) == App.today, "the project is stored: V6, its name, today")
	check(ShotHelper.find_button(sh, "I sent it!") != null, "it is listed with an I sent it! key")
	await ShotHelper.snap(tree, "projects_02_sheet_added")
	await _close_sheets(tree)

	# --- a session that tries it --------------------------------------------------------
	App.commit_sessions([_climb([{"grade": 6, "result": "attempt", "count": 5}, {"grade": 4, "result": "send", "count": 3}])], "Climb logged!")
	await ShotHelper.frames(tree, 3)
	var ov = _overlay(main)
	var types = []
	for e in ov._events:
		types.append(e.type)
	check(types.has("project"), "a session that tried it has a project card (%s)" % ", ".join(PackedStringArray(types)))
	await _wait_done(ov, tree)
	check(ShotHelper.find_text(ov, "Session 1 on it") != null and ShotHelper.find_button(ov, "Yes, I sent it!") == null, "it says session 1, and asks nothing")
	ShotHelper.reveal(ShotHelper.find_text(ov, "Session 1 on it"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "projects_03_reel_tried")
	ShotHelper.press(ShotHelper.find_button(ov, "Continue"))
	await ShotHelper.wait(tree, 0.5)

	# --- a session that sends its grade: was it the project? ------------------------
	App.commit_sessions([_climb([{"grade": 6, "result": "attempt", "count": 2}, {"grade": 6, "result": "send", "count": 1}])], "Climb logged!")
	await ShotHelper.frames(tree, 3)
	ov = _overlay(main)
	await _wait_done(ov, tree)
	var yes = ShotHelper.find_button(ov, "Yes, I sent it!")
	check(yes != null and ShotHelper.find_text(ov, "Was it your project?") != null, "a send of its grade asks: was it your project?")
	if yes == null:
		return
	ShotHelper.reveal(yes)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "projects_04_reel_ask")
	var hero0 = int(App.state.xp.hero)
	ShotHelper.press(yes)
	await ShotHelper.wait(tree, 0.9)
	var p = App.projects()[0]
	check(str(p.sent) == App.today and str(p.sessionId) != "" and App.open_projects().is_empty(), "yes: the project is sent, today, in that session")
	check(App.saved.claims.any(func(c): return str(c.questId) == "project:" + str(p.id) and int(c.xp) == Projects.SEND_XP), "and its XP is a claim")
	check(int(App.state.xp.hero) - hero0 == Projects.SEND_XP, "+%d XP on the hero (%d)" % [Projects.SEND_XP, int(App.state.xp.hero) - hero0])
	check(ShotHelper.find_text(ov, "PROJECT SENT") != null and ShotHelper.find_text(ov, "2 sessions") != null, "the card turns gold: PROJECT SENT, 2 sessions")
	await ShotHelper.snap(tree, "projects_05_reel_sent")
	await ShotHelper.wait(tree, 0.8)
	ShotHelper.press(ShotHelper.find_button(ov, "Continue"))
	await ShotHelper.wait(tree, 0.5)

	# --- the sheet: sent; the save keeps it ---------------------------------------
	ProjectsView.open()
	await ShotHelper.wait(tree, 0.6)
	sh = _sheet()
	check(ShotHelper.find_text(sh, "Sent") != null and ShotHelper.find_text(sh, "Sent today") != null, "the sheet lists it under Sent")
	await ShotHelper.snap(tree, "projects_06_sheet_sent")
	await _close_sheets(tree)
	var back = App.parse_saved(JSON.parse_string(JSON.stringify(App.saved)))
	check(back != null and back.projects.size() == 1 and str(back.projects[0].sent) == App.today, "the save keeps projects")
	# A second ask for the same project never pays twice.
	App.send_project(str(p.id), "", App.today)
	check(App.saved.claims.filter(func(c): return str(c.questId) == "project:" + str(p.id)).size() == 1, "sending it again pays nothing more")
	# Set aside and back on.
	var q = App.add_project(3, "5.10a", "")
	App.set_project_aside(str(q.id), true)
	check(App.open_projects().is_empty(), "set aside: not open")
	App.set_project_aside(str(q.id), false)
	check(App.open_projects().size() == 1 and App.projects().size() == 2, "back on, and nothing was deleted")
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var row = ShotHelper.find_text(main, "0 sessions")
	check(row != null, "the Hero tab lists the open project")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "projects_07_card")
	print("PROJECTS walkthrough: %d failed" % fails)
