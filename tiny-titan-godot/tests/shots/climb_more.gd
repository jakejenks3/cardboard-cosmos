extends RefCounted
## Routes (5.xx) and hangboard in the climbing form: switch the grade keys to
## rope, tap two routes, open the hangboard, log three one-arm hangs with
## added weight, save, and check what was stored. Run with "week" data.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func exact_button(text: String):
	for n in ShotHelper.walk(main):
		if n is Button and n.text == text:
			return n
	return null


func press(text: String) -> void:
	var b = exact_button(text)
	check(b != null, "button '%s' is there" % text)
	if b != null:
		ShotHelper.press(b)
	await ShotHelper.frames(tree, 2)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.open_log("climb")
	await ShotHelper.frames(tree, 4)
	await press("Rope · 5.xx")
	await ShotHelper.snap(tree, "climb_more_01_rope_keys")
	await press("Flash")
	await press("5.10a")
	await press("5.10a")
	await press("Send")
	await press("5.11b")
	await press("Boulder · V")
	await press("V3")
	await ShotHelper.snap(tree, "climb_more_02_routes_and_boulder")
	await press("+ Hangboard")
	await ShotHelper.frames(tree, 2)
	await press("15 mm")
	await press("7 s")
	await press("One arm")
	var add = null
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.has_meta(LogWidgets.FKEY) and n.get_meta(LogWidgets.FKEY) == "hang.add":
			add = n
	check(add != null, "added-weight field found")
	if add != null:
		ShotHelper.type_into(add, "5")
		await ShotHelper.frames(tree, 2)
	for i in range(3):
		await press("+ Hang")
	await press("+ Hang")
	ShotHelper.scroll_main(main, 400)
	await ShotHelper.snap(tree, "climb_more_03_hangboard")
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 4)
	var last = null
	for s in App.sessions():
		if s.discipline == "climb" and (last == null or s.createdAt > last.createdAt):
			last = s
	check(last != null, "a climb session was saved")
	if last != null:
		print("stored: ", JSON.stringify(last))
		var routes = 0
		var boulders = 0
		for c in last.climbs:
			if Xp.is_route(c):
				routes += int(c.count)
			else:
				boulders += int(c.count)
		check(routes == 3 and boulders == 1, "2 × 5.10a flash + 5.11b send + V3 stored")
		var hs = last.get("hangs", [])
		check(hs.size() == 1 and int(hs[0].count) == 4 and int(hs[0].edgeMm) == 15 and int(hs[0].sec) == 7 and int(hs[0].arms) == 1 and float(hs[0].addKg) > 0.0, "4 one-arm 7 s hangs on 15 mm with added weight stored")
		var st = Xp.session_stats(last)
		check(st.maxGradeSent == 3 and Xp.yds_label(st.maxRouteSent) == "5.11b", "V3 is the max boulder, 5.11b the max route")
	await ShotHelper.frames(tree, 20)
	await ShotHelper.snap(tree, "climb_more_04_results")
	if main.get("_results") != null:
		main._results.finished.emit()
	await ShotHelper.frames(tree, 4)
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 1.5)
	ShotHelper.scroll_main(main, 1800)
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "climb_more_05_journey")
	print("CLIMB_MORE DONE, failures: %d" % fails)
