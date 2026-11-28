extends RefCounted
## Prep a day ahead (PrepView, game/prep.gd; run with "year" data, also --fingers): Coming up's "Prep tomorrow"
## opens the prep: a card a lift, a way picked, a record to beat put in the first set, a lift added from the
## same muscles, two lifts linked as a superset, saved. Tomorrow's plan is the prep; on that day the Log tab
## starts the workout from it (its ways, sets and superset), and its add-exercise card offers the same muscles'
## lifts as keys. Prints CHECK lines.

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


func _press(b) -> void:
	if b == null:
		return
	ShotHelper.reveal(b)
	await ShotHelper.wait(tree, 0.3)
	if b is BaseButton:
		b.pressed.emit()
	await ShotHelper.wait(tree, 0.6)


func _dismiss_reels() -> void:
	for k in range(6):
		var b = null
		for i in range(20):
			await ShotHelper.wait(tree, 0.3)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.4)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"split": "pull_push_legs"})
	var tomorrow = Dates.add_days(App.today, 1)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var key = _one("prep_tomorrow")
	check(key != null and not bool(key.get_meta("prep_tomorrow")), "Coming up has a Prep tomorrow key")
	if key != null:
		ShotHelper.reveal(key)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "prepday_1_coming_up")
	await _press(key)
	var sh = _sheet()
	check(sh != null and str(sh.get_meta("prep_sheet", "")) == tomorrow, "it opens tomorrow's prep")
	var cards = _all("prep_lift", sh)
	# (some weekdays the demo's plan for tomorrow has one lift only: a lift of the same muscles is added then)
	if cards.size() == 1:
		var sug0 = _one("prep_suggest", null, sh)
		if sug0 != null:
			await _press(sug0)
			sh = _sheet()
			cards = _all("prep_lift", sh)
	check(cards.size() >= 2, "a card a lift of tomorrow's plan, two or more (%d)" % cards.size())
	await ShotHelper.snap(tree, "prepday_2_sheet")
	if cards.size() < 2:
		print("PREPDAY %d FAILED" % fails)
		return

	# A record to beat into the first set of a lift that has one (before any way is switched: a way never done
	# has no records).
	var rec = null
	var rec_i = -1
	for i in range(cards.size()):
		var r = _one("prep_record", null, cards[i])
		if r != null:
			rec = r
			rec_i = i
			break
	check(rec != null, "a lift shows its records to beat")
	if rec != null:
		await _press(rec)
		var s0 = PrepView._lifts[rec_i].sets[-1]
		check(int(s0.reps) > 0 and bool(s0.get("goal", false)), "a tap makes it the goal: its last set (%s reps, %s)" % [str(s0.reps), str(s0.w)])
	sh = _sheet()
	cards = _all("prep_lift", sh)

	# Another way for the first lift.
	var first_name = str(cards[0].get_meta("prep_lift"))
	var other = null
	for w in _all("prep_way", cards[0]):
		if str(w.get_meta("prep_way")) != first_name:
			other = w
			break
	check(other != null, "the first lift offers other ways (%s)" % first_name)
	if other != null:
		var way = str(other.get_meta("prep_way"))
		await _press(other)
		sh = _sheet()
		cards = _all("prep_lift", sh)
		check(str(cards[0].get_meta("prep_lift")) == way and PrepView._lifts[0].name == way, "a tap makes it that way: %s" % way)
		first_name = way

	# A lift of the same muscles.
	sh = _sheet()
	var sug = _one("prep_suggest", null, sh)
	var area = _one("prep_area", null, sh)
	var before_n = PrepView._lifts.size()
	check(sug != null and area != null, "Add a lift offers the same muscles' lifts (%s)" % (str(area.get_meta("prep_area")) if area != null else "none"))
	if sug != null:
		var added = str(sug.get_meta("prep_suggest"))
		await _press(sug)
		check(PrepView._lifts.size() == before_n + 1 and PrepView._lifts[before_n].name == added, "a tap adds it: %s" % added)

	# The first two as a superset.
	sh = _sheet()
	var ss = _one("prep_ss", null, _all("prep_lift", sh)[0])
	await _press(ss)
	check(PrepView._linked(0), "Superset with next links the first two")
	sh = _sheet()
	check(_one("prep_superset_line", 0, sh) != null, "and says so between them")
	await ShotHelper.snap(tree, "prepday_3_edited")
	var prepped_names = PrepView._lifts.map(func(x): return str(x.name))
	await _press(_one("prep_save", null, sh))
	await ShotHelper.wait(tree, 0.8)
	var prep = Prep.of(App.settings(), tomorrow)
	check(prep != null and Prep.lifts_of(prep).map(func(x): return str(x.name)) == prepped_names, "Save stores it for tomorrow (%d lifts)" % (Prep.lifts_of(prep).size() if prep != null else 0))
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var key2 = _one("prep_tomorrow")
	check(key2 != null and bool(key2.get_meta("prep_tomorrow")), "Coming up says tomorrow is prepped")

	# Tomorrow: the plan is the prep, and the Log tab starts from it.
	var real_today = App.today
	App.today = tomorrow
	App._recompute()
	App.changed.emit()
	await ShotHelper.wait(tree, 1.0)
	var plan = App.plan()
	check(bool(plan.get("prepped", false)) and plan.lifts.map(func(l): return str(l.name)) == prepped_names, "on the day, its plan is the prep")
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	check(ShotHelper.all_text(main).contains("YOUR PREP"), "the Today card shows the prepped sets as the aim")
	await ShotHelper.snap(tree, "prepday_4_today")
	App.draft_store("lift", null)
	App.pending_workout = TodayView.workout_names(App.plan())
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var f = main._screen._form if main._screen != null and main._screen.get("_form") != null else null
	check(f != null and f.lift.exercises.size() >= 2, "Start workout opens it")
	if f != null:
		var ex_names = f.lift.exercises.map(func(e): return str(e.name))
		check(ex_names.slice(0, 2) == prepped_names.slice(0, 2), "with the prepped lifts in order (%s)" % str(ex_names))
		var p0 = Prep.lifts_of(prep)[0]
		check(str(f.lift.exercises[0].sets[0].reps) == str(int(p0.sets[0].reps)), "with the prepped sets")
		check(f.lift.linked_next(0), "and the superset")
		var area_cap = _one("area_caption")
		var area_keys = _all("area_lift")
		check(area_cap != null and not area_keys.is_empty(), "the Log tab's Add exercise offers the same muscles' lifts as keys (%d)" % area_keys.size())
		if area_cap != null:
			ShotHelper.reveal(area_cap)
			await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, "prepday_5_log")
		if not area_keys.is_empty():
			var nm = str(area_keys[0].get_meta("area_lift"))
			var n0 = f.lift.exercises.size()
			await _press(area_keys[0])
			await ShotHelper.wait(tree, 0.5)
			check(f.lift.exercises.size() == n0 + 1 and str(f.lift.exercises[n0].name) == nm, "a tap adds it, nothing typed: %s" % nm)
	App.draft_store("lift", null)
	App.today = real_today
	App._recompute()
	App.changed.emit()
	print("PREPDAY %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
