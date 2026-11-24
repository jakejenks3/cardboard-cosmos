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
	check(not words.has("Rest") and not words.has("Off") and words.has("Push") and words.has("Legs") and words.has("Pull") and days.all(func(a): return bool(a.lift)), "with a focus too every day ahead is a lift day: no rest day is planned by itself")
	card = _find("ahead_card")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "ahead_4_card_focus")
	await _open_card()
	sh = _sheet()
	st = ShotHelper.all_text(sh) if sh != null else ""
	check(not st.contains("Rest day") and st.contains("Every day is planned as a lift day") and st.contains("Counts a lift every day") and st.contains("Bench Press") and st.contains("Pull-up"), "the sheet: no rest day, the press on the next push day, a pull-up beside the pulldown")
	# The plan in numbers: the week it leads to, and what each day gives its muscles.
	var week_card = _find("ahead_week", sh)
	var wt = ShotHelper.all_text(week_card) if week_card != null else ""
	check(week_card != null and wt.contains("IF IT GOES AS PLANNED") and wt.contains("Chest") and wt.contains("Triceps"), "the week the plan leads to, in sets per muscle being built")
	var chest_sum = 0.0
	for a in days:
		chest_sum += float(a.week.get("chest", 0.0))
	check(chest_sum / float(days.size()) >= 10.0, "the planned days give the chest its weekly sets (%s a week)" % Dosage._n(chest_sum / float(days.size())))
	check(_all("ahead_dose", sh).size() >= 3 and st.contains("Chest +") and st.contains("Back +"), "each lift day says what it adds to each of its muscles")
	var tag_words = ""
	for tag_row in _all("ahead_dose", sh):
		tag_words += ShotHelper.all_text(tag_row) + "
"
	check(tag_words.contains("Chest +") and tag_words.contains("/10-16") and _all("ahead_why", sh).size() >= 3, "against the whole range of the week (the chest: 10-16), with a key to what counts")
	check(st.contains("Running") and st.contains("aim 5.5 km"), "and the run with the distance to aim for")
	await ShotHelper.snap(tree, "ahead_5_sheet_focus")
	if sh != null:
		ShotHelper.scroll_main(sh, 800)
		await ShotHelper.wait(tree, 0.3)
		await ShotHelper.snap(tree, "ahead_5b_sheet_focus_lower")
	# --- a key on every day: Rest moves the day's lifts, and all after them, a day ---------------
	if sh != null:
		ShotHelper.scroll_main(sh, 0)
		await ShotHelper.wait(tree, 0.3)
		var n_sessions = App.sessions().size()
		var first = days[0]
		var keys = _all("ahead_call", sh)
		var key = null
		for k in keys:
			if str(k.get_meta("ahead_call")) == "%s:rest" % str(first.date):
				key = k
		check(bool(first.lift) and key != null and keys.size() == days.filter(func(a): return bool(a.lift) or bool(a.can_lift)).size(), "every day has a Rest or a Lift key (%d keys)" % keys.size())
		if key != null:
			ShotHelper.reveal(key)
			await ShotHelper.frames(tree, 3)
			var at = key.get_global_rect().position
			var size0 = key.size
			var kind0 = str(first.plan.kind)
			await ShotHelper.click(tree, key)
			await ShotHelper.wait(tree, 0.8)
			var after = App.ahead()
			var words2 = after.map(func(a): return str(Missions.ahead_word(a).text))
			print("AHEAD after rest ", words2)
			check(bool(after[0].rest) and str(after[0].call) == "rest" and str(after[1].plan.kind) == kind0 and bool(after[1].lift), "Rest on tomorrow: it is a rest day, and its %s day is the day after" % kind0)
			check(Missions.call_of(App.settings(), str(first.date)) == "rest" and App.sessions().size() == n_sessions, "the call is kept in the settings; nothing is logged")
			var back = null
			for k in _all("ahead_call", sh):
				if str(k.get_meta("ahead_call")) == "%s:lift" % str(first.date):
					back = k
			print("AHEAD key ", at, " ", size0, " -> ", back.get_global_rect().position if back != null else null, " ", back.size if back != null else null)
			check(back != null and back.get_global_rect().position.distance_to(at) < 2.0 and ShotHelper.all_text(sh).contains("Your call: a rest from lifting"), "the sheet is rebuilt in place: the key, now Lift, is where the cursor is")
			await ShotHelper.snap(tree, "ahead_6_called_rest")
			# And back again, once the quiet moment after a tap is over.
			await ShotHelper.wait(tree, 0.6)
			if back != null:
				await ShotHelper.click(tree, back)
				await ShotHelper.wait(tree, 0.8)
				check(App.ahead().map(func(a): return str(Missions.ahead_word(a).text)) == words and (App.settings().get("dayCalls", {}) as Dictionary).is_empty(), "Lift: the days are as they were, and no call is left")
	await _close_sheets()
	card = _find("ahead_card")
	check(card != null, "the Hero tab's card is still there after the calls")
	await _close_sheets()
	print("AHEAD %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
