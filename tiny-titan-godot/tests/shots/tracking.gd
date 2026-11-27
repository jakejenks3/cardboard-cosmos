extends RefCounted
## The tracking screens of 2026-11-27 (run with "year" data, also --fingers): a goal with a date set from a
## lift's page and shown on the Hero tab, reached by a workout (a card in the reel) with the workout's
## receipt; Journey -> Stats' sets a week over 8 weeks, the streak and the lift report; Journey -> Body's
## trend; the Weekly sets sheet's 8 weeks; the free swap of a mission; Settings' heavy and light days.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0
const BENCH = "Bench Press - Barbell"


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
	if b is BaseButton:
		b.pressed.emit()
	elif b.get("_tap") is Callable:
		b._tap.call()
	await ShotHelper.wait(tree, 0.5)


func _section(id: String):
	for n in ShotHelper.walk(main):
		if n.has_meta("section") and str(n.get_meta("section")) == id and n is Control and n.is_visible_in_tree():
			return n
	return null


func _dismiss_reels() -> void:
	for k in range(6):
		var b = null
		for i in range(40):
			await ShotHelper.wait(tree, 0.4)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.5)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"focus": "upper"})
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	check(_section("lift_goals") == null, "no GOALS section before a goal is set")

	# --- a goal from the lift's page ---------------------------------------------------------------------------
	JourneyLifts.open_named(BENCH)
	await ShotHelper.wait(tree, 0.9)
	var add = _one("goal_add", BENCH, _sheet())
	check(add != null, "a lift's page has 'Set a goal'")
	if add != null:
		ShotHelper.reveal(add)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_1_lift_page")
	await _press(add)
	var gs = _sheet()
	check(gs != null and gs.has_meta("goal_sheet"), "the goal sheet opens")
	await ShotHelper.snap(tree, "tracking_2_goal_sheet")
	await _press(_one("goal_weeks", 12, gs))
	await _press(_one("goal_save", null, gs))
	await ShotHelper.wait(tree, 0.5)
	check(App.goals().size() == 1 and str(App.goals()[0].by) == Dates.add_days(App.today, 84), "the goal is stored, by 12 weeks from today")
	var row = _one("goal_row", null, _sheet())
	check(row != null, "the lift's page shows its goal (%s)" % (str(row.get_meta("goal_state")) if row != null else "none"))
	await ShotHelper.snap(tree, "tracking_3_goal_on_page")
	await _close()
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var sec = _section("lift_goals")
	check(sec != null and _one("goal_row", null, sec) != null, "the Hero tab has GOALS with the goal")
	if sec != null:
		ShotHelper.reveal(sec)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_4_hero_goals")

	# --- reached by a workout: the reel's goal card and the receipt ------------------------------------------------
	var g = App.goals()[0]
	var s = App.build_session({"discipline": "lift", "date": App.today, "exercises": [
		{"name": BENCH, "sets": [{"reps": int(g.reps), "weightKg": float(g.kg)}, {"reps": int(g.reps), "weightKg": float(g.kg)}]},
		{"name": "Bent Over Row - Barbell", "sets": [{"reps": 8, "weightKg": 60.0}, {"reps": 8, "weightKg": 60.0}, {"reps": 8, "weightKg": 60.0}]}]})
	App.commit_sessions([s], "Session logged!")
	await ShotHelper.wait(tree, 1.0)
	var reel_goal = null
	var receipt = null
	for k in range(30):
		reel_goal = _one("reel_goal")
		receipt = _one("reel_receipt")
		if reel_goal != null and receipt != null:
			break
		await ShotHelper.wait(tree, 0.5)
	check(str(App.goals()[0].done) == App.today, "the goal is marked reached")
	check(reel_goal != null, "the reel has a GOAL REACHED card")
	check(receipt != null and int(receipt.get_meta("reel_receipt")) >= 2, "the reel ends with the workout's receipt (%s muscles)" % (str(receipt.get_meta("reel_receipt")) if receipt != null else "no"))
	if receipt != null:
		ShotHelper.reveal(receipt)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_5_reel")
	await _dismiss_reels()

	# --- Journey -> Stats ------------------------------------------------------------------------------------------
	App.set_journey_tab("stats")
	App.go("journey")
	await ShotHelper.wait(tree, 1.2)
	var ws = _section("weekly_sets")
	check(ws != null and _all("weekly_part", ws).size() >= 4, "Stats has sets a week over 8 weeks, a row a muscle")
	check(_one("target_streak") != null, "with the streak on target")
	if ws != null:
		ShotHelper.reveal(ws)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_6_weekly")
	var rep = _section("lift_report")
	check(rep != null and not _all("report_row", rep).is_empty(), "and the lift report, a row a lift")
	if rep != null:
		ShotHelper.reveal(rep)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_7_report")

	# --- Journey -> Body -------------------------------------------------------------------------------------------
	App.set_journey_tab("body")
	await ShotHelper.wait(tree, 1.0)
	var bt = _section("body_trend")
	check(bt != null and _one("body_avg", null, bt) != null and _one("body_rate", null, bt) != null, "Body has the trend: a 7-day average and the change a week")
	if bt != null:
		ShotHelper.reveal(bt)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "tracking_8_body")

	# --- the Weekly sets sheet -------------------------------------------------------------------------------------
	DoseView.open()
	await ShotHelper.wait(tree, 0.8)
	check(_one("weekly_block", null, _sheet()) != null, "the Weekly sets sheet has the last 8 weeks")
	await ShotHelper.snap(tree, "tracking_9_dose_sheet")
	await _close()

	# --- the free swap -----------------------------------------------------------------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var sw = _one("mission_swap")
	check(sw != null and App.reroll_left(), "MISSIONS offers one swap today")
	if sw != null:
		ShotHelper.reveal(sw)
		await ShotHelper.wait(tree, 0.4)
		await _press(sw)
		var picks = _all("swap_pick", _sheet())
		check(not picks.is_empty(), "the swap sheet lists the missions that can be swapped (%d)" % picks.size())
		await ShotHelper.snap(tree, "tracking_10_swap")
		if not picks.is_empty():
			var id = str(picks[0].get_meta("swap_pick"))
			await _press(picks[0])
			await ShotHelper.wait(tree, 0.8)
			var daily = App.quests().daily
			check(not App.reroll_left() and not daily.any(func(m): return str(m.id) == id) and daily.any(func(m): return bool(m.get("rerolled", false))), "the mission is swapped for another, and no swap is left")
			check(_one("mission_swap") == null, "the swap key is gone for today")

	print("TRACKING %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
