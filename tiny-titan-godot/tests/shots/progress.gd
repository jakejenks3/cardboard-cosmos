extends RefCounted
## A lift's three views (run with the "year" data): Compare (this time against
## last time or the best day, set by set, records, next time), Progress (the
## chart with its range, new bests and work bars, the records, the rep ladder)
## and Logbook (the calendar and every session as blocks). Then the phone
## note's review: each exercise has small history bars, and a tap opens its
## page on Compare with the note's sets. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func _count(kind, root = null) -> int:
	var n = 0
	var from = root if root != null else _sheet()
	if from == null:
		return 0
	for c in ShotHelper.walk(from):
		if is_instance_of(c, kind):
			n += 1
	return n


func _first(kind, root = null):
	var from = root if root != null else _sheet()
	if from == null:
		return null
	for c in ShotHelper.walk(from):
		if is_instance_of(c, kind):
			return c
	return null


func _scroll(px: int) -> void:
	var s = _sheet()
	if s != null:
		s._scroll.scroll_vertical = px
	await ShotHelper.frames(tree, 4)


## Press Continue on every results reel that is showing.
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


func _view(name: String) -> void:
	ShotHelper.press(ShotHelper.find_button(_sheet(), name))
	await ShotHelper.frames(tree, 5)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb"})
	var lift = "Bench Press - Barbell"
	# The demo bench only goes up, 5 reps at a time: a lighter day yesterday and
	# sets of 8 today give the page a best day that is not last time, and a ladder.
	var yday = Dates.add_days(App.today, -1)
	App.commit_sessions([
		{"id": "pv1", "discipline": "lift", "date": yday, "createdAt": App.now_ms() - 3600000, "source": "manual",
			"exercises": [{"name": lift, "sets": [{"reps": 8, "weightKg": 60.0}, {"reps": 8, "weightKg": 60.0}, {"reps": 8, "weightKg": 60.0}]}]},
		{"id": "pv2", "discipline": "lift", "date": App.today, "createdAt": App.now_ms(), "source": "manual",
			"exercises": [{"name": lift, "sets": [{"reps": 8, "weightKg": 70.0}, {"reps": 8, "weightKg": 70.0}, {"reps": 7, "weightKg": 70.0}, {"reps": 6, "weightKg": 70.0}]}]},
	], "Workout logged!")
	await _dismiss_reels()
	var st = LiftLibrary.stats(App.sessions()).get(Xp.normalize_exercise(lift))
	check(st != null and int(st.count) > 20, "the year data has a long bench history (%d)" % (int(st.count) if st != null else 0))

	# --- Compare --------------------------------------------------------------------------
	JourneyLifts.open_named(lift, {"view": "compare"})
	await ShotHelper.wait(tree, 0.7)
	var page = _sheet()
	var said = ShotHelper.all_text(page)
	check(page != null and ShotHelper.find_button(page, "Compare") != null and ShotHelper.find_button(page, "Progress") != null and ShotHelper.find_button(page, "Logbook") != null, "the page has the three view keys")
	check(said.contains("LAST TIME") and said.contains("THIS TIME") and said.contains("SET") and said.contains("Last time") and said.contains("Best day"), "Compare: both sessions, the set table, and a choice of last time or the best day")
	var pairs = LiftTrend.pairs(st.history[0].sets, st.history[1].sets)
	check(said.contains(LiftViews.set_text(pairs[0].cur, "lb")) and said.contains(LiftViews.set_text(pairs[0].prev, "lb")), "set 1 shows both numbers (%s / %s)" % [LiftViews.set_text(pairs[0].prev, "lb"), LiftViews.set_text(pairs[0].cur, "lb")])
	check(said.contains("Sets") and said.contains("Reps") and said.contains("Moved") and (said.contains("Every set at") or said.contains("One more rep")), "the totals, and a target for next time")
	await ShotHelper.snap(tree, "progress_1_compare")
	var gh = LiftTrend.ghost(st.history, st.history[0])
	check(gh == null or (said.contains("GHOST DUEL") and (said.contains("beat your ghost") or said.contains("ghost is") or said.contains("Dead heat"))), "the ghost duel against about four weeks back (%s)" % ("none: nothing 3 to 6 weeks back" if gh == null else "%+d%%" % int(round(float(gh.pct)))))
	await _scroll(900)
	await ShotHelper.snap(tree, "progress_2_compare_lower")
	await _scroll(0)
	ShotHelper.press(ShotHelper.find_button(page, "Best day"))
	await ShotHelper.frames(tree, 5)
	said = ShotHelper.all_text(_sheet())
	check(said.contains("BEST DAY") and _sheet() == page, "Best day: the same page, against the best day")
	await ShotHelper.snap(tree, "progress_3_best_day")

	# --- Progress -------------------------------------------------------------------------
	var keys_y = ShotHelper.find_button(page, "Progress").get_global_rect().position.y
	await _view("Progress")
	check(absf(ShotHelper.find_button(page, "Progress").get_global_rect().position.y - keys_y) <= 1.0, "switching views leaves the keys where they were")
	var chart = _first(ProgressChart)
	check(chart != null and chart.points.size() > 20 and not chart.records.is_empty(), "Progress: the chart, with new bests marked (%d points, %d bests)" % [chart.points.size() if chart != null else 0, chart.records.size() if chart != null else 0])
	check(_count(RepLadder) == 1 and ShotHelper.find_button(page, "Top set") != null and ShotHelper.find_button(page, "Est. 1RM") != null and ShotHelper.find_button(page, "3M") != null, "the rep ladder, the metric picker and the range")
	if chart != null:
		chart.hover = chart.points.size() - 3
		chart.queue_redraw()
	await ShotHelper.snap(tree, "progress_4_chart")
	var all_points = chart.points.size() if chart != null else 0
	ShotHelper.press(ShotHelper.find_button(page, "3M"))
	await ShotHelper.frames(tree, 5)
	chart = _first(ProgressChart)
	check(chart != null and chart.points.size() < all_points and chart.points.size() >= 8, "3M shows the last three months only (%d of %d)" % [chart.points.size() if chart != null else 0, all_points])
	ShotHelper.press(ShotHelper.find_button(page, "Est. 1RM"))
	await ShotHelper.frames(tree, 5)
	check(_first(ProgressChart) != null and ShotHelper.find_text(page, "since") != null, "Strength keeps the range and charts again")
	await ShotHelper.snap(tree, "progress_5_strength_3m")
	await _scroll(900)
	await ShotHelper.snap(tree, "progress_6_records_ladder")
	await _scroll(0)

	# --- Logbook --------------------------------------------------------------------------
	await _view("Logbook")
	check(_count(LiftCalendar) == 1 and _count(SetBlocks) == LiftViews.LOGBOOK_SHOWN, "Logbook: the calendar and %d sessions as blocks (%d)" % [LiftViews.LOGBOOK_SHOWN, _count(SetBlocks)])
	await ShotHelper.snap(tree, "progress_7_logbook")
	var more = ShotHelper.find_button(page, "Show all %d sessions" % st.count)
	check(more != null, "a key shows all of them")
	if more != null:
		ShotHelper.press(more)
		await ShotHelper.frames(tree, 6)
	check(_count(SetBlocks) == int(st.count), "all %d sessions" % int(st.count))
	await _scroll(500)
	await ShotHelper.snap(tree, "progress_8_logbook_rows")
	check(LiftViews.last_view == "logbook", "the view picked last is remembered")
	await _close_sheets()

	# A bodyweight lift: reps instead of weight.
	JourneyLifts.open_named("Pull-up", {"view": "progress"})
	await ShotHelper.wait(tree, 0.7)
	check(ShotHelper.find_button(_sheet(), "Best set") != null and ShotHelper.find_button(_sheet(), "Top set") == null and _count(RepLadder) == 0, "a bodyweight lift charts its best set, with no weight and no ladder")
	await ShotHelper.snap(tree, "progress_9_bodyweight")
	await _view("Compare")
	check(ShotHelper.all_text(_sheet()).contains("reps · best set"), "and compares reps")
	await _close_sheets()

	# --- The phone note's review ---------------------------------------------------------------
	var r = App.inbox.check_text("%s\nbench 3x5 @ 230\npull-up 12, 10, 9\nsquat 5, 5, 5 @ 250" % App.today)
	InboxSheet.open(r)
	await ShotHelper.wait(tree, 0.7)
	var review = _sheet()
	check(r.fresh.size() == 1 and _count(SparkBars, review) == 3, "each exercise in the review has its history bars (%d)" % _count(SparkBars, review))
	await ShotHelper.snap(tree, "progress_10_review")
	var row = null
	for n in ShotHelper.walk(review):
		if n is Card and n.tooltip_text == "Trends and history of %s" % lift:
			row = n
	check(row != null, "the bench row")
	if row != null:
		await ShotHelper.click(tree, row)
		await ShotHelper.wait(tree, 0.7)
	said = ShotHelper.all_text(_sheet())
	check(_sheet() != review and said.contains("IN YOUR NOTE") and said.contains("LAST TIME"), "a tap opens it on Compare, the note's sets against last time")
	await ShotHelper.snap(tree, "progress_11_note_compare")
	await _view("Progress")
	var nc = _first(ProgressChart)
	check(nc != null and bool(nc.points[nc.points.size() - 1].get("note", false)), "the note's sets are the chart's last point")
	await ShotHelper.snap(tree, "progress_12_note_chart")
	await _close_sheets()
	print("PROGRESS DONE, failures: %d" % fails)
