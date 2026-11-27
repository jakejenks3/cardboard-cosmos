extends RefCounted
## The Log tab's exercise cards, the things added 2026-11-27 (run with "year" data, also --fingers): a tick on
## each set (an empty set ticked is filled from last time), the aim and its Fill key, plates on a barbell lift,
## and the More sheet: swap for another way (same place, same sets), a superset with the next lift (A1 / A2,
## "Next: ..." after a tick), a note for next time (on the card at once and the next time), how hard it was.
## Finish asks about sets left unticked; the saved session holds how hard and the superset, and the time
## from the first tick. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0
var _finger = 40


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _win(p: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * p


func _tap(c: Control) -> void:
	if c == null:
		return
	ShotHelper.reveal(c)
	await ShotHelper.wait(tree, 0.4)
	var p = c.get_global_rect().get_center()
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


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _ed():
	var f = main._screen._form if main._screen != null and main._screen.get("_form") != null else null
	return f.lift if f != null else null


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	Engine.max_fps = 120
	await ShotHelper.wait(tree, 1.0)
	var ts = TouchScroll.new()
	main.add_child(ts)
	ts.only_fingers = true
	App.draft_store("lift", null)
	App.pending_workout = ["Bench Press - Barbell", "Overhead Press - Barbell", "Bent Over Row - Barbell"]
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var ed = _ed()
	check(ed != null and ed.exercises.size() == 3, "a workout of three lifts is open")
	if ed == null:
		print("LOGPLUS FAILED")
		return
	await ShotHelper.snap(tree, "logplus_0_start")

	# --- ticks ---------------------------------------------------------------------------------------------
	var t00 = _one("set_tick", "0:0")
	var at = t00.get_global_rect().get_center() if t00 != null else Vector2.ZERO
	await _tap(t00)
	ed = _ed()
	check(bool(ed.exercises[0].sets[0].get("done", false)) and _one("set_done", true) != null, "a set's tick marks it done")
	var t00b = _one("set_tick", "0:0")
	check(t00b != null and t00b.get_global_rect().get_center().distance_to(at) < 3.0, "the tick stays under the finger")
	check(ed.started > 0.0, "the first tick starts the workout's clock")
	# an empty set: filled from last time when ticked
	ed.exercises[1].sets[0].reps = ""
	ed._changed(true)
	await ShotHelper.wait(tree, 0.5)
	await _tap(_one("set_tick", "1:0"))
	ed = _ed()
	check(str(ed.exercises[1].sets[0].reps) != "" and bool(ed.exercises[1].sets[0].get("done", false)), "an empty set ticked is filled in from last time")
	await ShotHelper.snap(tree, "logplus_1_ticks")

	# --- the aim and plates -----------------------------------------------------------------------------------
	var aim = _one("aim_line")
	check(aim != null and str(aim.get_meta("aim_line")) != "", "a lift with a history shows what to aim for (%s)" % (str(aim.get_meta("aim_line")) if aim != null else "none"))
	var fill = _one("fill_aim", 2)
	if fill != null:
		await _tap(fill)
		ed = _ed()
		var want = ed._aim_of(2)
		check(want != null and LiftHistory.describe_sets(LogLiftEditor.sets_from_draft(ed.exercises[2], ed.wu), ed._fmt_w) == str(want.words), "Fill puts the aim into the sets")
	var pl = _one("plates_line")
	check(pl != null and str(pl.get_meta("plates_line")).contains("each side") or (pl != null and str(pl.get_meta("plates_line")) != ""), "a barbell lift says what goes on the bar (%s)" % (str(pl.get_meta("plates_line")) if pl != null else "none"))

	# --- More: superset ---------------------------------------------------------------------------------------
	await _tap(_one("more_key", 0))
	var sh = _sheet()
	check(sh != null and sh.has_meta("lift_menu"), "More opens the exercise's sheet")
	await ShotHelper.snap(tree, "logplus_2_more")
	var link = _one("superset_key", "link", sh)
	await _tap(link)
	await ShotHelper.wait(tree, 0.5)
	ed = _ed()
	check(ed.group_label(0) == "A1" and ed.group_label(1) == "A2" and _one("superset_line") != null and _one("superset_tag", "A1") != null, "two lifts linked: A1 and A2 with the superset line between them")
	# a tick of A1's next set says A2 is next
	await _tap(_one("set_tick", "0:1"))
	await ShotHelper.snap(tree, "logplus_3_superset")

	# --- More: note ---------------------------------------------------------------------------------------------
	await _tap(_one("more_key", 0))
	sh = _sheet()
	var box = _one("lift_note_box", null, sh)
	if box != null:
		box.text = "Seat 4, close grip"
		await _tap(_one("lift_note_save", null, sh))
	await ShotHelper.wait(tree, 0.5)
	var nl = _one("lift_note")
	check(App.lift_note(str(_ed().exercises[0].name)) == "Seat 4, close grip" and nl != null, "the note is kept for the lift and shown on its card")

	# --- More: effort -------------------------------------------------------------------------------------------
	await _tap(_one("more_key", 1))
	sh = _sheet()
	await _tap(_one("effort_key", "hard", sh))
	check(str(_ed().exercises[1].get("effort", "")) == "hard" and _one("effort_key", "hard", _sheet()) != null, "how hard it was is marked")
	if _sheet() != null:
		_sheet().close()
	await ShotHelper.wait(tree, 0.5)
	check(_one("effort_tag", "hard") != null, "the card says HARD")

	# --- More: swap ---------------------------------------------------------------------------------------------
	var n_sets = _ed().exercises[2].sets.size()
	await _tap(_one("more_key", 2))
	sh = _sheet()
	var ways = _all("swap_way", sh)
	check(not ways.is_empty(), "there are other ways to do a row (%d)" % ways.size())
	if not ways.is_empty():
		var to = str(ways[0].get_meta("swap_way"))
		await _tap(ways[0])
		await ShotHelper.wait(tree, 0.5)
		ed = _ed()
		check(Xp.normalize_exercise(str(ed.exercises[2].name)) == Xp.normalize_exercise(to) and ed.exercises[2].sets.size() == n_sets and ed.exercises.size() == 3, "Swap puts the other way in its place with as many sets (%s)" % to)
	await ShotHelper.snap(tree, "logplus_4_swapped")

	# --- Finish: the unticked sets ------------------------------------------------------------------------------
	ed = _ed()
	ed.started = Time.get_unix_time_from_system() - 40 * 60
	var form = main._screen._form
	form.save()
	await ShotHelper.wait(tree, 0.6)
	sh = _sheet()
	check(sh != null and sh.has_meta("unticked_sheet"), "Finish asks about sets left unticked (%s)" % (str(sh.get_meta("unticked_sheet")) if sh != null and sh.has_meta("unticked_sheet") else "no"))
	await ShotHelper.snap(tree, "logplus_5_unticked")
	var only = _one("unticked_key", "only", sh)
	var before = App.sessions().size()
	await _tap(only)
	await ShotHelper.wait(tree, 0.8)
	# (the planned-lifts question may follow for an untouched lift)
	var sh2 = _sheet()
	if sh2 != null:
		for b in ShotHelper.walk(sh2):
			if b is Button and b.is_visible_in_tree() and str(b.text) == "Yes, save":
				await _tap(b)
				break
	await ShotHelper.wait(tree, 1.5)
	var saved = null
	for s in App.sessions():
		if str(s.discipline) == "lift" and str(s.date) == App.today and int(s.get("durationSec", 0)) >= 39 * 60:
			saved = s
	check(App.sessions().size() == before + 1 and saved != null, "the workout is saved with the time from the first tick (%s)" % (Fmt.fmt_duration_short(int(saved.durationSec)) if saved != null else "none"))
	if saved != null:
		var bench = null
		var press = null
		for ex in saved.exercises:
			if str(ex.name) == "Bench Press - Barbell":
				bench = ex
			if str(ex.name) == "Overhead Press - Barbell":
				press = ex
		check(bench != null and bench.sets.size() == 2, "leaving unticked sets out kept the two ticked bench sets (%d)" % (bench.sets.size() if bench != null else -1))
		check(press != null and str(press.get("effort", "")) == "hard" and str(press.get("superset", "")) == "A" and str(bench.get("superset", "")) == "A", "how hard and the superset are saved with the lifts")
	# the results reel (if any) closed
	for c in Kit.overlay_root.get_children():
		if c.has_method("skip"):
			c.skip()
	await ShotHelper.wait(tree, 1.0)
	print("LOGPLUS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
