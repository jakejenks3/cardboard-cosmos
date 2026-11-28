extends RefCounted
## The tidy-up of 2026-11-27 ("look more clean and crisp and easier to use"; run with "year" data, also
## --fingers): an exercise card's title is the movement with its variation as a tag, and a tap on it brings
## the name box back; last time, the best and the aim share one sunken box; a ticked set's row turns green;
## a new workout of today says it times itself and keeps its time picks behind "Set time"; the day's plan
## puts the lifts done today last, short; Journey -> Log goes week by week with a filter and "Show older
## weeks"; a workout's rows name its movements; its sheet has the date as its title, number tiles and a
## plain list of where the XP came from. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


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


func _close() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _press(b) -> void:
	if b == null:
		return
	ShotHelper.reveal(b)
	await ShotHelper.wait(tree, 0.3)
	if b is BaseButton:
		b.pressed.emit()
	elif b.get("_tap") is Callable:
		b._tap.call()
	await ShotHelper.wait(tree, 0.6)


func _ed():
	var f = main._screen._form if main._screen != null and main._screen.get("_form") != null else null
	return f.lift if f != null else null


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)

	# --- the lift form ---------------------------------------------------------------------------------------
	App.draft_store("lift", null)
	App.pending_workout = ["Bench Press - Barbell", "Overhead Press - Barbell"]
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var ed = _ed()
	check(ed != null and ed.exercises.size() == 2, "a workout of two lifts is open")
	if ed == null:
		print("TIDY FAILED")
		return
	var title = _one("name_title", "Bench Press - Barbell")
	check(title != null and ShotHelper.all_text(title).contains("Bench Press") and ShotHelper.all_text(title).contains("Barbell"), "a lift of the log has the movement as its title and the variation as a tag")
	check(main._screen._find_fkey(main._screen, "ex0.name") == null, "and no name box while it is not renamed")
	var ref = _one("ref_block")
	check(ref != null and _one("last_line", null, ref) != null and _one("aim_line", null, ref) != null and _one("fill_aim", null, ref) != null, "last time and the aim share one box, with Fill")
	check(_one("time_note") != null and _one("set_time") != null, "a new workout of today says it times itself, with a Set time key")
	var plan = _one("plan_card")
	if plan != null:
		var heads = _all("plan_done_head", plan)
		if not heads.is_empty():
			var after = true
			var head_y = heads[0].get_global_rect().position.y
			for k in _all("plan_pick", plan):
				if str(k.get_meta("plan_state")) != "done" and k.get_global_rect().position.y > head_y:
					after = false
			check(after and not _all("plan_done_sets", plan).is_empty(), "the plan's lifts done today come last, a line each with their sets")
	await ShotHelper.snap(tree, "tidy_1_card")

	# a tick turns the row green, in place
	var t00 = _one("set_tick", "0:0")
	var at = t00.get_global_rect().get_center() if t00 != null else Vector2.ZERO
	await _press(t00)
	ed = _ed()
	var green = _one("set_row_done", true)
	check(green != null and _all("set_row_done").filter(func(n): return bool(n.get_meta("set_row_done"))).size() == 1, "a ticked set's row turns green")
	var t00b = _one("set_tick", "0:0")
	check(t00b != null and t00b.get_global_rect().get_center().distance_to(at) < 3.0, "and the tick stays where it was")
	check(_one("time_note") != null and str(_one("time_note").text).contains("since your first tick"), "the time line now counts from the first tick (%s)" % (str(_one("time_note").text) if _one("time_note") != null else "none"))
	await ShotHelper.snap(tree, "tidy_2_ticked")

	# Set time shows the picks
	await _press(_one("set_time"))
	check(_one("set_time") == null and _one("time_note") == null, "Set time brings back the time picks")

	# the title renames
	await _press(_one("name_title", "Bench Press - Barbell"))
	var box = main._screen._find_fkey(main._screen, "ex0.name")
	check(box != null and str(box.text) == "Bench Press - Barbell", "a tap on the title brings the name box back, with the name in it")
	if box != null:
		box.focus_exited.emit()
		await ShotHelper.wait(tree, 0.6)
	check(_one("name_title", "Bench Press - Barbell") != null and main._screen._find_fkey(main._screen, "ex0.name") == null, "leaving the box unchanged puts the title back")
	App.draft_store("lift", null)
	App.go("home")
	await ShotHelper.wait(tree, 0.8)

	# --- Journey -> Log --------------------------------------------------------------------------------------
	App.set_journey_tab("history")
	App.go("journey")
	await ShotHelper.wait(tree, 1.2)
	var weeks = _all("hist_week")
	check(weeks.size() >= 2 and weeks.size() <= JourneyScreen.HIST_WEEKS, "the log goes week by week (%d weeks shown)" % weeks.size())
	var rows = _all("session_row")
	var lifts = rows.filter(func(r): return _one("session_moves", null, r) != null)
	check(not lifts.is_empty(), "a lift workout's row names its movements (%s)" % (str(_one("session_moves", null, lifts[0]).get_meta("session_moves")) if not lifts.is_empty() else "none"))
	check(_one("hist_more") != null, "with Show older weeks under them")
	await ShotHelper.snap(tree, "tidy_3_history")
	var n_before = _all("hist_week").size()
	await _press(_one("hist_more"))
	check(_all("hist_week").size() > n_before, "Show older weeks shows more weeks (%d to %d)" % [n_before, _all("hist_week").size()])
	await _press(_one("hist_filter", "run"))
	var shown = _all("session_row")
	var only_runs = not shown.is_empty()
	for r in shown:
		var s = App.sessions().filter(func(x): return str(x.id) == str(r.get_meta("session_row")))
		if s.is_empty() or str(s[0].discipline) != "run":
			only_runs = false
	check(only_runs, "the Running filter shows runs only (%d)" % shown.size())
	await ShotHelper.snap(tree, "tidy_4_runs")
	await _press(_one("hist_filter", "all"))

	# --- a workout's sheet -----------------------------------------------------------------------------------
	var lift_row = null
	for r in _all("session_row"):
		if _one("session_moves", null, r) != null:
			lift_row = r
			break
	var sess = App.sessions().filter(func(x): return lift_row != null and str(x.id) == str(lift_row.get_meta("session_row")))
	if not sess.is_empty():
		SessionView.open(sess[0])
		await ShotHelper.wait(tree, 0.8)
		var sh = _sheet()
		check(sh != null and sh.has_meta("session_sheet"), "a workout's sheet opens")
		check(_one("session_tiles", null, sh) != null and int(_one("session_tiles", null, sh).get_meta("session_tiles")) >= 3, "with its numbers as tiles")
		check(_one("xp_parts", null, sh) != null, "and a plain list of where the XP came from")
		await ShotHelper.snap(tree, "tidy_5_sheet")
		await _close()
	else:
		check(false, "a lift workout to open")
	JourneyScreen.hist_filter = "all"
	JourneyScreen.hist_weeks = JourneyScreen.HIST_WEEKS

	print("TIDY %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
