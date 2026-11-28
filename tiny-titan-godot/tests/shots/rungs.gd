extends RefCounted
## Progress by reps (run with "new" data, also --fingers). A bench press done the way the game's own aims
## ask for (double progression): the same weight, a rep more each time, then a step heavier. Snaps every
## place that shows how a lift is going, and the reel of a workout that beat last time by one rep.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0
const BENCH = "Bench Press - Barbell"
## [days ago, kg, reps of each set]
const PLAN = [
	[40, 60.0, [8, 8, 7]],
	[37, 60.0, [8, 8, 8]],
	[33, 60.0, [9, 8, 8]],
	[30, 60.0, [9, 9, 8]],
	[26, 60.0, [9, 9, 9]],
	[23, 60.0, [10, 9, 9]],
	[19, 60.0, [10, 10, 9]],
	[16, 60.0, [10, 10, 10]],
	[12, 62.5, [8, 8, 7]],
	[9, 62.5, [8, 8, 8]],
	[5, 62.5, [9, 8, 8]],
]


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


func _session(days_ago: int, kg: float, reps: Array) -> Dictionary:
	var sets = []
	for r in reps:
		sets.append({"reps": int(r), "weightKg": kg})
	return App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -days_ago), "durationSec": 3000,
		"exercises": [{"name": BENCH, "sets": sets}]})


func _dismiss_reels() -> void:
	for k in range(8):
		var b = null
		for i in range(30):
			await ShotHelper.wait(tree, 0.3)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.4)


func _view(key: String) -> void:
	for n in ShotHelper.walk(_sheet()):
		var tip = {"compare": "This time against", "progress": "A chart over time", "logbook": "Every day you did it"}[key]
		if n is BaseButton and str(n.tooltip_text).begins_with(tip):
			n.pressed.emit()
			break
	await ShotHelper.wait(tree, 0.7)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# The history goes straight into the log (no reel for it).
	for p in PLAN:
		App.saved.sessions.append(_session(int(p[0]), float(p[1]), p[2]))
	App._commit()
	await ShotHelper.wait(tree, 0.8)

	# Today: one rep more than last time, at the same weight: the reel says it.
	App.commit_sessions([_session(0, 62.5, [9, 9, 8])], "Session logged!")
	var beat = null
	for k in range(40):
		beat = _one("reel_beat")
		if beat != null:
			break
		await ShotHelper.wait(tree, 0.4)
	check(beat != null and int(beat.get_meta("reel_beat")) == 1, "the reel has a Beat last time card")
	var up_row = _one("beat_row", "up", beat) if beat != null else null
	check(up_row != null and ShotHelper.all_text(up_row).to_upper().contains("+1 REP AT 62.5"), "which says +1 rep at 62.5 kg (%s)" % (ShotHelper.all_text(up_row) if up_row != null else "none"))
	if beat != null:
		ShotHelper.reveal(beat)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "rungs_0_reel")
	await _dismiss_reels()

	JourneyLifts.open_named(BENCH)
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "rungs_1_compare")
	await _view("progress")
	var chart = _one("rung_chart", null, _sheet())
	check(chart != null and int(chart.get_meta("rung_chart")) == PLAN.size() + 1, "Progress opens on the step chart, a bar a workout (%s)" % (str(chart.get_meta("rung_chart")) if chart != null else "none"))
	var bt = _one("progress_beat", null, _sheet())
	check(bt != null and str(bt.get_meta("progress_beat")) == str(PLAN.size()), "every workout beat the one before it: %s of %d" % [str(bt.get_meta("progress_beat")) if bt != null else "?", PLAN.size()])
	var st = _one("progress_steps", null, _sheet())
	check(st != null and str(st.get_meta("progress_steps")) == "1", "one step up, 60 to 62.5 kg")
	var gn = _one("progress_gain", null, _sheet())
	check(gn != null and str(gn.get_meta("progress_gain")) == "+3", "+3 reps on this step (23 to 26)")
	var bn = _one("progress_banner", null, _sheet())
	check(bn != null and int(bn.get_meta("progress_banner")) == PLAN.size(), "and the banner says the streak")
	if chart != null:
		ShotHelper.reveal(chart)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "rungs_2_progress")
	await _view("logbook")
	await ShotHelper.snap(tree, "rungs_3_logbook")
	await _close()

	var today = App.sessions().filter(func(x): return str(x.date) == App.today)
	if not today.is_empty():
		SessionView.open(today[0])
		await ShotHelper.wait(tree, 0.8)
		check(_one("session_beat_line", 1, _sheet()) != null, "a workout's sheet says it beat last time")
		await ShotHelper.snap(tree, "rungs_4_session")
		await _close()
	App.set_journey_tab("lifts")
	App.go("journey")
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "rungs_5_lifts")
	App.set_journey_tab("history")
	App.go("journey")
	await ShotHelper.wait(tree, 1.0)
	check(_all("session_beat").size() >= PLAN.size(), "every workout's row in the log has its beat tag (%d)" % _all("session_beat").size())
	await ShotHelper.snap(tree, "rungs_6_history")
	print("RUNGS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
