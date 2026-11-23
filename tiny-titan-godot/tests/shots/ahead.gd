extends RefCounted
## The look-ahead (run with the "year" data): the "Coming up" card under the
## Today card, its sheet with the next days (kind, lifts with aims and other
## ways, the movement to try, PT, the likely climb or run), a lift row opening
## its page, nothing logged by any of it; then, with a log of its own and a
## training focus, a rest day and the press for the chest in the days ahead.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheets() -> Array:
	var out = []
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			out.append(c)
	return out


func _sheet():
	var all = _sheets()
	return all[all.size() - 1] if not all.is_empty() else null


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _all(meta: String, root) -> Array:
	return ShotHelper.walk(root).filter(func(n): return n.has_meta(meta))


func _three(reps: int, kg: float) -> Array:
	return [{"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}]


func _lift(back: int, exercises: Dictionary) -> Dictionary:
	var exs = []
	for name in exercises:
		exs.append({"name": name, "sets": exercises[name]})
	return App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -back), "exercises": exs})


func _open_card() -> void:
	var card = _find("ahead_card")
	if card == null:
		return
	ShotHelper.reveal(card)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.click(tree, card)
	await ShotHelper.wait(tree, 0.7)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"split": "pull_push_legs"})
	App.go("home")
	await ShotHelper.wait(tree, 0.8)

	# --- the card under the Today card ----------------------------------------------------
	var t0 = Time.get_ticks_usec()
	var fresh = Missions.ahead(App.sessions(), App.today, App.pt(), App.settings())
	print("AHEAD took %.1f ms for %d sessions" % [(Time.get_ticks_usec() - t0) / 1000.0, App.sessions().size()])
	var days = App.ahead()
	print("AHEAD ", days.map(func(a): return "%s %s" % [Dates.format_date(str(a.date), {"weekday": "short"}), str(Missions.ahead_word(a).text)]))
	var before = App.sessions().size()
	var card = _find("ahead_card")
	check(card != null and days.size() == Missions.AHEAD_DAYS and fresh.size() == days.size(), "a Coming up card on the Hero tab, six days behind it")
	var text = ShotHelper.all_text(card) if card != null else ""
	check(text.contains(Dates.format_date(str(days[0].date), {"weekday": "short"}).to_upper()) and text.contains(str(Missions.ahead_word(days[0]).text)), "it names tomorrow and what it is (%s)" % str(Missions.ahead_word(days[0]).text))
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "ahead_1_card")

	# --- the sheet --------------------------------------------------------------------------
	await _open_card()
	var sh = _sheet()
	var st = ShotHelper.all_text(sh) if sh != null else ""
	var cards = _all("ahead_day", sh) if sh != null else []
	check(sh != null and st.contains("Coming up") and cards.size() == Missions.AHEAD_DAYS, "its sheet has a card for each of the six days (%d)" % cards.size())
	var lift_day = null
	for a in days:
		if bool(a.lift):
			lift_day = a
			break
	# (the weekday is drawn in pixel letters; the date under it is text)
	check(lift_day != null and st.contains(Dates.format_date(str(lift_day.date), {"month": "short", "day": "numeric"})) and st.contains(str(lift_day.plan.label)), "a lift day says its date and its kind")
	if lift_day != null:
		var l = lift_day.plan.lifts.filter(func(x): return not bool(x.pt))[0]
		check(st.contains(str(LiftNames.split(str(l.options[0].name)).move)), "and its lifts (%s)" % str(l.options[0].name))
	await ShotHelper.snap(tree, "ahead_2_sheet")
	if sh != null:
		ShotHelper.scroll_main(sh, 700)
		await ShotHelper.wait(tree, 0.3)
		await ShotHelper.snap(tree, "ahead_2b_sheet_lower")
		ShotHelper.scroll_main(sh, 1500)
		await ShotHelper.wait(tree, 0.3)
		await ShotHelper.snap(tree, "ahead_2c_sheet_end")
	# A lift of a day ahead opens its page.
	var row = null
	if sh != null:
		for n in ShotHelper.walk(sh):
			if n is Card and n.tooltip_text == "Its page: last time and its history":
				row = n
				break
	check(row != null, "a lift of a day ahead is a row you can tap")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, row)
		await ShotHelper.wait(tree, 0.8)
		check(_sheets().size() == 2, "it opens the lift's page over the look-ahead")
		await ShotHelper.snap(tree, "ahead_3_lift_page")
	await _close_sheets()
	check(App.sessions().size() == before and not App.sessions().any(func(s): return str(s.get("id", "")).begins_with("pretend")), "looking ahead logged nothing (%d sessions as before)" % before)

	# --- with a training focus and a log of its own: rest, and the press -----------------------------
	var push = {"Chest Fly - Cable": _three(12, 15.0), "Arnold Press - Dumbbell": _three(8, 20.0), "Lateral Raise - Dumbbell": _three(12, 8.0), "Tricep Pushdown": _three(10, 30.0)}
	var pull = {"Bent Over Row - Barbell": _three(8, 60.0), "Lat Pulldown": _three(10, 50.0), "Bicep Curl - Dumbbell": _three(10, 12.0)}
	var legs = {"Squat - Barbell": _three(5, 100.0), "Romanian Deadlift - Barbell": _three(5, 80.0), "Calf Raise": _three(12, 60.0)}
	var kinds = [pull, legs, push]
	var data = ShotHelper.demo_saved("new")
	for back in range(1, 14):
		if back != 3:
			data.sessions.append(_lift(back, kinds[(back - 1) % 3]))
	for back in [2, 5, 9]:
		data.sessions.append(App.build_session({"discipline": "climb", "date": Dates.add_days(App.today, -back), "climbs": [{"grade": 3, "result": "send", "count": 4}]}))
	data.sessions.append(App.build_session({"discipline": "run", "date": Dates.add_days(App.today, -6), "distanceM": 5000.0, "durationSec": 1800}))
	data.settings.merge({"split": "pull_push_legs", "focus": "upper"}, true)
	App.replace_all(data)
	await ShotHelper.wait(tree, 0.8)
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	days = App.ahead()
	var words = days.map(func(a): return str(Missions.ahead_word(a).text))
	print("AHEAD focus ", words)
	check(words.has("Rest") and words.has("Push") and words.has("Legs") and words.has("Pull"), "with a focus the days ahead have a rest day among the split's days")
	card = _find("ahead_card")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "ahead_4_card_focus")
	await _open_card()
	sh = _sheet()
	st = ShotHelper.all_text(sh) if sh != null else ""
	check(st.contains("Rest day") and st.contains("hard days in a row by then") and st.contains("FOR CHEST") and st.contains("Incline dumbbell") and st.contains("Dip") and st.contains("Pull-up"), "the sheet: the rest day, the press for the chest and its other ways, a pull-up beside the pulldown")
	check(st.contains("Running") and st.contains("aim 5.5 km"), "and the run with the distance to aim for")
	await ShotHelper.snap(tree, "ahead_5_sheet_focus")
	if sh != null:
		ShotHelper.scroll_main(sh, 800)
		await ShotHelper.wait(tree, 0.3)
		await ShotHelper.snap(tree, "ahead_5b_sheet_focus_lower")
	await _close_sheets()
	print("AHEAD %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
