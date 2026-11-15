extends RefCounted
## Journey → Lifts (the lift library): the list, search, filters, sort, the
## detail sheet of a lift with history and of a new one, and "Add to today's
## workout". Run with "year" data.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func exact_button(text: String):
	for n in ShotHelper.walk(main):
		if n is Button and n.text == text:
			return n
	return null


func sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func card_of(root: Node, text: String):
	for n in ShotHelper.walk(root):
		if n is Label and n.text == text:
			var p = n
			while p != null and not (p is Card):
				p = p.get_parent()
			if p != null:
				return p
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.go("journey", "lifts")
	await ShotHelper.wait(tree, 0.8)
	await ShotHelper.snap(tree, "lifts_01_list")
	ShotHelper.scroll_main(main, 700)
	await ShotHelper.snap(tree, "lifts_02_list_b")
	ShotHelper.scroll_main(main, 0)

	# Search keeps the box and only refills the list.
	var search = null
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.placeholder_text.begins_with("Search lifts"):
			search = n
	check(search != null, "search box is there")
	ShotHelper.type_into(search, "cable curl")
	await ShotHelper.frames(tree, 4)
	check(is_instance_valid(search) and ShotHelper.find_text(main, "Cable Curl") != null and ShotHelper.find_text(main, "Bench Press") == null, "typing 'cable curl' narrows the list without rebuilding the box")
	await ShotHelper.snap(tree, "lifts_03_search")
	ShotHelper.type_into(search, "")
	await ShotHelper.frames(tree, 4)

	# Filters and sort.
	ShotHelper.press(exact_button("Chest"))
	await ShotHelper.wait(tree, 0.5)
	ShotHelper.press(exact_button("Dumbbell"))
	await ShotHelper.wait(tree, 0.5)
	check(ShotHelper.find_text(main, "Dumbbell Fly") != null and ShotHelper.find_text(main, "Squat") == null, "Chest + Dumbbell shows dumbbell chest lifts only")
	await ShotHelper.snap(tree, "lifts_04_chest_dumbbell")
	ShotHelper.press(exact_button("Chest"))
	await ShotHelper.wait(tree, 0.4)
	ShotHelper.press(exact_button("Dumbbell"))
	await ShotHelper.wait(tree, 0.4)
	ShotHelper.press(exact_button("Most done"))
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "lifts_05_most_done")

	# Detail of a lift with history.
	var done = null
	for e in LiftLibrary.query(LiftLibrary.rows(App.sessions()), {"show": "mine", "sort": "count"}):
		if done == null:
			done = e
	check(done != null, "the demo data has lifting history")
	var c = card_of(main, done.name)
	check(c != null, "the most done lift (%s) has a row" % done.name)
	c._tap.call()
	await ShotHelper.wait(tree, 0.8)
	check(sheet() != null and ShotHelper.find_text(sheet(), "Sessions") != null and ShotHelper.find_text(sheet(), "Last done") != null and ShotHelper.find_button(sheet(), "Add to today's workout") != null, "its sheet shows history and the add button")
	await ShotHelper.snap(tree, "lifts_06_detail")
	sheet()._scroll.scroll_vertical = 520
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "lifts_07_detail_b")
	sheet().close()
	await ShotHelper.wait(tree, 0.5)

	# Detail of a new lift, then add it to a workout.
	ShotHelper.press(exact_button("New to me"))
	await ShotHelper.wait(tree, 0.5)
	var fresh = null
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.placeholder_text.begins_with("Search lifts"):
			ShotHelper.type_into(n, "bayesian")
	await ShotHelper.frames(tree, 4)
	fresh = card_of(main, "Bayesian Curl")
	check(fresh != null, "Bayesian Curl is offered as new")
	fresh._tap.call()
	await ShotHelper.wait(tree, 0.8)
	check(sheet() != null and ShotHelper.find_text(sheet(), "New to you") != null and ShotHelper.find_button(sheet(), "Hammer Curl") != null, "a new lift's sheet says so and lists variations")
	await ShotHelper.snap(tree, "lifts_08_new")
	ShotHelper.press(ShotHelper.find_button(sheet(), "Add to today's workout"))
	await ShotHelper.wait(tree, 1.0)
	var on_form = false
	for n in ShotHelper.walk(main):
		if (n is Label or n is LineEdit or n is Button) and str(n.text).contains("Bayesian Curl"):
			on_form = true
	check(App.tab == "log" and on_form, "Add to today's workout opens the lift form with it on")
	await ShotHelper.snap(tree, "lifts_09_added")
	print("LIFTS DONE, failures: %d" % fails)
