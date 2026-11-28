extends RefCounted
## LOCK-IN in the Log tab (2026-11-28; run with "year" data, also --fingers). The user: "Make a way to finish or
## complete each set and rep... when scrolling or looking you can't tell which has been done yet. So that way it
## locks in that set and then the exercise". With real finger taps (ui/touch_scroll.gd, as a phone sends them):
## a workout of three lifts; two sets of the first locked by their numbers (each row turns into a slim green
## line of the same height, no steppers left in it, the tick where the number was); one unlocked by a tap on its
## line and locked again; "Lock in" folds the card into one green bar under the finger; the head says 1 of 3;
## the workout kept and opened again looks the same; the bar opens the card and Lock in folds it again; Finish
## saves the sets and nothing of the locks. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0
var _finger = 90


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _win(p: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * p


## A finger tap at a point of the screen (no scrolling first).
func _tap_at(p: Vector2) -> void:
	_finger += 1
	var d = InputEventScreenTouch.new()
	d.index = _finger
	d.pressed = true
	d.position = _win(p)
	Input.parse_input_event(d)
	await ShotHelper.wait(tree, 0.07)
	var u = InputEventScreenTouch.new()
	u.index = _finger
	u.pressed = false
	u.position = _win(p)
	Input.parse_input_event(u)
	# (longer than the quiet time after a rebuild that could not keep its key)
	await ShotHelper.wait(tree, 0.6)


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _ed():
	var f = main._screen._form if main._screen != null and main._screen.get("_form") != null else null
	return f.lift if f != null else null


## The row of set j of exercise i: its locked line, or the ground of its editable row.
func _row_of(i: int, j: int):
	var line = _one("set_line", "%d:%d" % [i, j])
	if line != null:
		return line
	var t = _one("set_tick", "%d:%d" % [i, j])
	if t == null:
		return null
	var p = t.get_parent()
	while p != null and not (p is PanelContainer):
		p = p.get_parent()
	return p


func _steppers(root: Node) -> int:
	var n = 0
	for c in ShotHelper.walk(root):
		if c is Stepper:
			n += 1
	return n


## Scroll the page so `c` is at `y` on the screen (as far as the page can go), then let it settle.
func _place(c: Control, y: float) -> void:
	var sc = main._scroll
	sc.scroll_vertical = maxi(0, int(sc.scroll_vertical + c.get_global_rect().position.y - y))
	await ShotHelper.wait(tree, 0.5)


func _cards() -> int:
	return _all("exercise_card").filter(func(n): return n is Card).size()


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	Engine.max_fps = 120
	await ShotHelper.wait(tree, 1.0)
	var ts = TouchScroll.new()
	main.add_child(ts)
	ts.only_fingers = true
	App.draft_store("lift", null)
	var bench = "Bench Press - Barbell"
	# A record picked as the bench's goal in today's prep (the Challenges flow): its set 1 is set up for it.
	var goal = {}
	for o in App.challenge_options(bench):
		if str(o.type) in ["heavier", "reps", "ladder"]:
			goal = o
			break
	if not goal.is_empty():
		App.prep_goal(bench, goal)
		await ShotHelper.wait(tree, 0.5)
	App.pending_workout = [bench, "Overhead Press - Barbell", "Bent Over Row - Barbell"]
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var ed = _ed()
	check(ed != null and ed.exercises.size() == 3, "a workout of three lifts is open")
	if ed == null or ed.exercises.size() < 3:
		print("LOCKIN FAILED")
		return
	var n_sets = ed.exercises[0].sets.size()
	var goal_on = not goal.is_empty() and bool(ed.exercises[0].sets[0].get("goal", false))
	check(goal.is_empty() or (goal_on and _one("goal_set", "0:0") != null), "the bench comes with its goal, set 1 set up for it (%s)" % str(goal.get("words", "no goal today")))
	var prog = _one("lock_progress")
	check(prog != null and str(prog.get_meta("lock_progress")) == "0 of 3", "the form's head counts the exercises done (%s)" % (str(prog.get_meta("lock_progress")) if prog != null else "none"))
	check(_one("lock_exercise", 0) != null and _one("lock_exercise", 0).disabled, "each card ends in Lock in, switched off while no set is locked in")
	await ShotHelper.snap(tree, "lockin_0_start")

	# --- two sets locked in by their numbers -------------------------------------------------------------
	for j in [0, 1]:
		var t = _one("set_tick", "0:%d" % j)
		if t == null:
			check(false, "set %d has its number key" % (j + 1))
			continue
		await _place(t, 330.0)
		t = _one("set_tick", "0:%d" % j)
		var row = _row_of(0, j)
		var h0 = row.size.y if row != null else -1.0
		var y0 = row.global_position.y if row != null else -1.0
		var steps_before = _steppers(row) if row != null else 0
		var below = _row_of(0, j + 1) if j + 1 < n_sets else _one("lock_exercise", 0)
		var below_y = below.global_position.y if below != null else -1.0
		var at = t.get_global_rect().get_center()
		await _tap_at(at)
		ed = _ed()
		var line = _one("set_line", "0:%d" % j)
		check(bool(ed.exercises[0].sets[j].get("done", false)) and line != null, "set %d locked in: its row is a line" % (j + 1))
		if line == null:
			continue
		check(steps_before >= 1 and _steppers(line) == 0 and _one("set_words", null, line) != null, "no stepper left in it, the set in words (%s)" % str(_one("set_words", null, line).get_meta("set_words") if _one("set_words", null, line) != null else ""))
		check(absf(line.size.y - h0) < 0.6 and absf(line.global_position.y - y0) < 1.0, "the line is as tall as the row was, where it was (%.0f -> %.0f px, y %.0f -> %.0f)" % [h0, line.size.y, y0, line.global_position.y])
		var t2 = _one("set_tick", "0:%d" % j)
		check(t2 != null and bool(t2.get_meta("set_done")) and t2.get_global_rect().get_center().distance_to(at) < 3.0, "the green tick is where the number was (%s -> %s)" % [str(at), str(t2.get_global_rect().get_center()) if t2 != null else "none"])
		var below2 = _row_of(0, j + 1) if j + 1 < n_sets else _one("lock_exercise", 0)
		check(below2 != null and absf(below2.global_position.y - below_y) < 1.0, "nothing under it moved (%.0f -> %.0f)" % [below_y, below2.global_position.y if below2 != null else -1.0])
		if j == 0 and goal_on:
			var gt = _one("goal_set", "0:0")
			check(bool(line.get_meta("set_row_goal")) and gt != null and bool(gt.get_meta("goal_met")), "the goal set locked in: green and gold, GOAL MET")
	check(_one("lock_exercise", 0) != null and not _one("lock_exercise", 0).disabled, "with a set locked in, Lock in can be pressed")
	await ShotHelper.snap(tree, "lockin_1_two_locked")

	# --- a tap on a line unlocks it; its number locks it again -----------------------------------------------
	var l1 = _one("set_line", "0:1")
	if l1 != null:
		var h1 = l1.size.y
		var y1 = l1.global_position.y
		var tick_at = _one("set_tick", "0:1").get_global_rect().get_center()
		# (on the words, away from the tick)
		await _tap_at(l1.get_global_rect().get_center())
		ed = _ed()
		var r1 = _row_of(0, 1)
		check(not bool(ed.exercises[0].sets[1].get("done", false)) and _one("set_line", "0:1") == null and r1 != null and _steppers(r1) >= 1, "a tap on the line unlocks the set: its keys are back")
		check(r1 != null and absf(r1.size.y - h1) < 0.6 and absf(r1.global_position.y - y1) < 1.0, "the row is as tall as the line, where it was (%.0f px)" % (r1.size.y if r1 != null else -1.0))
		var t1 = _one("set_tick", "0:1")
		check(t1 != null and t1.get_global_rect().get_center().distance_to(tick_at) < 3.0, "its number is back where the tick was (%s -> %s)" % [str(tick_at), str(t1.get_global_rect().get_center()) if t1 != null else "none"])
		await ShotHelper.snap(tree, "lockin_2_unlocked")
		await _tap_at(t1.get_global_rect().get_center())
		ed = _ed()
		check(bool(ed.exercises[0].sets[1].get("done", false)) and _one("set_line", "0:1") != null, "and its number locks it in again")
	else:
		check(false, "set 2 has a line to tap")

	# --- Lock in: the card folds into one green bar under the finger ---------------------------------------------
	var lk = _one("lock_exercise", 0)
	check(lk != null and (n_sets <= 2) == bool(lk.get_meta("lock_ready")), "Lock in is green only once every set is locked in (%d of %d)" % [2, n_sets])
	if lk == null:
		print("LOCKIN %d FAILED" % fails)
		return
	# (scrolled down past the card's sets: room above for the page to follow the folded card)
	await _place(lk, 140.0)
	lk = _one("lock_exercise", 0)
	var key_at = lk.get_global_rect().get_center()
	var key_top = lk.get_global_rect().position.y
	await _tap_at(key_at)
	ed = _ed()
	var bar = _one("exercise_done", bench)
	check(bool(ed.exercises[0].get("closed", false)) and ed.exercises[0].sets.all(func(s): return LogWidgets.num(s.reps) <= 0.0 or bool(s.get("done", false))), "Lock in locks every set with reps and closes the exercise")
	check(bar != null and _cards() == 2, "the card is one bar now (%d cards left open)" % _cards())
	check(bar != null and bar.get_global_rect().has_point(key_at) and absf(bar.get_global_rect().position.y - key_top) < 2.0, "the bar is under the finger where the key was (%.0f -> %.0f)" % [key_top, bar.get_global_rect().position.y if bar != null else -1.0])
	check(bar != null and _one("bar_sets", null, bar) != null and str(_one("bar_sets", null, bar).get_meta("bar_sets")) != "", "the bar says its sets (%s)" % (str(_one("bar_sets", null, bar).get_meta("bar_sets")) if bar != null and _one("bar_sets", null, bar) != null else ""))
	if goal_on:
		check(bar != null and bool(bar.get_meta("bar_mission")), "its goal was met: the bar says MISSION DONE")
	prog = _one("lock_progress")
	check(prog != null and str(prog.get_meta("lock_progress")) == "1 of 3", "the head says 1 of 3 (%s)" % (str(prog.get_meta("lock_progress")) if prog != null else "none"))
	await ShotHelper.snap(tree, "lockin_3_folded")
	main._scroll.scroll_vertical = 0
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "lockin_3b_top")

	# --- kept: the workout closed and opened again looks the same ------------------------------------------------
	var kept = App.draft_load("lift")
	var kex = kept.exercises[0] if kept != null and not (kept.get("exercises", []) as Array).is_empty() else {}
	check(bool(kex.get("closed", false)) and (kex.get("sets", []) as Array).any(func(s): return bool(s.get("done", false))), "the kept draft holds the lock-ins")
	App.open_log(null)
	await ShotHelper.wait(tree, 0.5)
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.2)
	ed = _ed()
	check(ed != null and _one("exercise_done", bench) != null and _one("lock_progress") != null and str(_one("lock_progress").get_meta("lock_progress")) == "1 of 3", "opened again: the bar and 1 of 3")

	# --- the bar opens the card, Lock in folds it again ---------------------------------------------------------
	bar = _one("exercise_done", bench)
	if bar != null:
		await _place(bar, 360.0)
		bar = _one("exercise_done", bench)
		var bar_at = bar.get_global_rect().get_center()
		var bar_top = bar.get_global_rect().position.y
		await _tap_at(bar_at)
		ed = _ed()
		lk = _one("lock_exercise", 0)
		check(not bool(ed.exercises[0].get("closed", false)) and _one("exercise_done", bench) == null and _cards() == 3, "a tap on the bar opens the card again")
		check(ed.exercises[0].sets.filter(func(s): return bool(s.get("done", false))).size() == ed.exercises[0].sets.filter(func(s): return LogWidgets.num(s.reps) > 0.0).size() and _one("set_line", "0:0") != null, "its sets are still locked in")
		check(lk != null and absf(lk.get_global_rect().position.y - bar_top) < 2.0 and bool(lk.get_meta("lock_ready")), "its Lock in key is where the bar was, green (%.0f -> %.0f)" % [bar_top, lk.get_global_rect().position.y if lk != null else -1.0])
		await ShotHelper.snap(tree, "lockin_4_reopened")
		if lk != null:
			await _tap_at(lk.get_global_rect().get_center())
		check(_one("exercise_done", bench) != null and bool(_ed().exercises[0].get("closed", false)), "and Lock in folds it again")
	else:
		check(false, "a bar to open")

	# --- a superset keeps its line when one of its cards is locked in --------------------------------------------
	ed = _ed()
	ed.link_next(1)
	await ShotHelper.wait(tree, 0.5)
	ed = _ed()
	ed.toggle_set_done(1, 0)
	await ShotHelper.wait(tree, 0.4)
	_ed().lock_exercise(1)
	await ShotHelper.wait(tree, 0.6)
	ed = _ed()
	var rail = _one("superset_line")
	var ohp_bar = _one("exercise_done", str(ed.exercises[1].name))
	check(rail != null and ohp_bar != null and _one("superset_tag", "A1", ohp_bar) != null and _cards() == 1, "a superset's first lift locked in: its bar keeps A1 and the line to A2")
	prog = _one("lock_progress")
	check(prog != null and str(prog.get_meta("lock_progress")) == "2 of 3", "the head says 2 of 3")
	if ohp_bar != null:
		await _place(ohp_bar, 260.0)
	await ShotHelper.snap(tree, "lockin_5_superset")

	# --- Finish: the sets are saved, the locks are not -----------------------------------------------------------
	ed = _ed()
	var want = LogLiftEditor.sets_from_draft(ed.exercises[0], ed.wu)
	var before = App.sessions().size()
	var fin = ShotHelper.find_button(main, "Finish session")
	if fin != null:
		ShotHelper.reveal(fin)
		await ShotHelper.wait(tree, 0.5)
		await ShotHelper.snap(tree, "lockin_6_finish")
		await _tap_at(fin.get_global_rect().get_center())
	await ShotHelper.wait(tree, 0.5)
	# (the two lifts never touched: "Done as shown?")
	for k in range(3):
		var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
		if yes == null:
			break
		await _tap_at(yes.get_global_rect().get_center())
		await ShotHelper.wait(tree, 0.5)
	await ShotHelper.wait(tree, 1.0)
	var saved = null
	for s in App.sessions():
		if str(s.discipline) == "lift" and str(s.date) == App.today and (saved == null or float(s.createdAt) > float(saved.createdAt)):
			saved = s
	check(App.sessions().size() == before + 1 and saved != null, "the workout is saved")
	if saved != null:
		var bp = saved.exercises.filter(func(x): return str(x.name) == bench)
		check(not bp.is_empty() and bp[0].sets.size() == want.size() and bp[0].sets.size() >= 2, "with the bench's sets (%d)" % (bp[0].sets.size() if not bp.is_empty() else -1))
		var stray = []
		for x in saved.exercises:
			for k in ["done", "closed", "goal", "planned"]:
				if x.has(k):
					stray.append("%s.%s" % [str(x.name), k])
			for s in x.sets:
				for k in ["done", "closed", "goal"]:
					if s.has(k):
						stray.append("%s set.%s" % [str(x.name), k])
		check(stray.is_empty(), "and nothing of the locks in it (%s)" % str(stray))
	check(App.draft_load("lift") == null, "the kept draft is gone")
	for c in Kit.overlay_root.get_children():
		if c.has_method("skip"):
			c.skip()
	await ShotHelper.wait(tree, 1.0)
	print("LOCKIN %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
