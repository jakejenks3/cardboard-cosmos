extends RefCounted
## Reps logged as both sides added up (run with the "year" data): a cable
## lateral raise typed as 22, 22, 25 for both arms. Its page says so and aims
## for one more rep where a plain lift with the same numbers is told to go
## heavier; the switch on the page turns it off and on without moving; the
## Progress view goes by one side; the Log tab's "L+R" key marks another lift
## when the workout is saved; the Today card tags the aim. Prints CHECK lines.

const CABLE = "Lateral Raise - Cable"
const PUSHDOWN = "Tricep Pushdown - Rope"
const CURL = "Bicep Curl - Single arm cable"

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			out.append(n)
	return out


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
	await ShotHelper.wait(tree, 0.5)


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


func _log_screen():
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n
	return null


func _sets(rows: Array) -> Array:
	var out = []
	for r in rows:
		out.append({"reps": int(r[0]), "weightKg": Fmt.unit_to_kg(float(r[1]), "lb")})
	return out


func _log(date: String, exercises: Dictionary) -> void:
	var exs = []
	for nm in exercises:
		exs.append({"name": nm, "sets": _sets(exercises[nm])})
	App.commit_sessions([App.build_session({"discipline": "lift", "date": date, "exercises": exs})], "Workout")
	await _dismiss_reels()


## The chip of the exercise card that holds this lift.
func _chip_of(form, part: String):
	for c in _all("exercise_card"):
		var i = int(c.get_meta("exercise_card"))
		if i < form.lift.exercises.size() and str(form.lift.exercises[i].name).contains(part):
			return _find("both_chip", c)
	return null


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# The demo player trains by the weekday: take out what it did on this
	# weekday, today included, so the day's plan is this walkthrough's.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	App.replace_all(clean)
	App.update_settings({"weightUnit": "lb", "split": "pull_push_legs", "focus": ""})
	await ShotHelper.wait(tree, 0.4)

	# Three push days: a cable raise typed as both arms added up, and a
	# pushdown with the very same numbers as plain reps.
	await _log(Dates.add_days(App.today, -9), {"Bench Press - Barbell": [[5, 185], [5, 185]], CABLE: [[20, 17.5], [20, 17.5], [20, 17.5]], PUSHDOWN: [[22, 40], [22, 40], [24, 40]]})
	await _log(Dates.add_days(App.today, -6), {"Bench Press - Barbell": [[5, 185], [5, 185]], CABLE: [[20, 15], [21, 15], [22, 15]], PUSHDOWN: [[21, 40], [21, 40], [22, 40]]})
	await _log(Dates.add_days(App.today, -3), {"Bench Press - Barbell": [[5, 185], [5, 185]], CABLE: [[22, 15], [22, 15], [25, 15]], PUSHDOWN: [[22, 40], [22, 40], [25, 40]]})
	check(App.both_sides(CABLE) and not App.both_sides(PUSHDOWN) and not App.settings().has(Sides.KEY), "the cable raise is both sides by itself, the pushdown is not, nothing is stored")

	# --- the lift's page ---------------------------------------------------------------------
	JourneyLifts.open_named(CABLE, {"view": "compare"})
	await ShotHelper.wait(tree, 0.9)
	var sh = _sheet()
	var words = _find("sides_words", sh)
	var all = ShotHelper.all_text(sh)
	check(_find("sides_tag", sh) != null, "its page has the L+R tag")
	check(words != null and str(words.text) == "Both sides added up: 11 to 13 a side.", "next time says what it is a side (%s)" % (str(words.text) if words != null else "-"))
	check(all.contains("One more rep on set 1: 23 reps") and not all.contains("too light"), "and aims for one more rep, not for more weight")
	await ShotHelper.snap(tree, "sides_1_compare")
	var card = _find("sides_card", sh)
	var sw = _find("sides_switch", sh)
	check(card != null and bool(card.get_meta("sides_card")) and sw != null, "the card with its switch, on")
	if sw != null:
		ShotHelper.reveal(sw)
		await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, "sides_2_switch")
		var at = sw.get_global_rect().position
		await ShotHelper.click(tree, sw)
		await ShotHelper.wait(tree, 0.5)
		var sw2 = _find("sides_switch", sh)
		all = ShotHelper.all_text(sh)
		check(not App.both_sides(CABLE) and sw2 != null and not bool(sw2.get_meta("sides_switch")) and _find("sides_tag", sh) == null, "switched off: stored, the tag is gone")
		check(sw2 != null and sw2.get_global_rect().position.distance_to(at) < 1.0, "the switch stayed under the finger (%s -> %s)" % [str(at), str(sw2.get_global_rect().position) if sw2 != null else "-"])
		check(all.contains("too light") and _find("sides_words", sh) == null, "as plain reps the page says the weight is too light")
		await ShotHelper.snap(tree, "sides_3_off")
		if sw2 != null:
			await ShotHelper.click(tree, sw2)
			await ShotHelper.wait(tree, 0.5)
		var sw3 = _find("sides_switch", sh)
		all = ShotHelper.all_text(sh)
		check(App.both_sides(CABLE) and App.settings()[Sides.KEY].is_empty() and sw3 != null and bool(sw3.get_meta("sides_switch")) and sw3.get_global_rect().position.distance_to(at) < 1.0, "switched on again, in the same place, and nothing is left stored")
		check(not all.contains("too light") and _find("sides_tag", sh) != null and _find("sides_words", sh) != null, "and the page goes by one side again")
	# Progress: the records and the ladder go by one side.
	var prog = ShotHelper.find_button(sh, "Progress")
	if prog != null:
		ShotHelper.reveal(prog)
		await ShotHelper.frames(tree, 3)
		ShotHelper.press(prog)
	await ShotHelper.wait(tree, 0.6)
	all = ShotHelper.all_text(sh)
	check(all.contains("est. 1RM a side") and all.contains("L+R best"), "the records: the best set marked L+R, the estimate a side")
	var ladder = _find("ladder_title", sh)
	check(ladder != null and str(ladder.get_meta("ladder_title")) == "side", "the ladder is reps a side")
	if ladder != null:
		ShotHelper.reveal(ladder)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "sides_4_progress")
	await _close_sheets()

	# The pushdown, with the same numbers as plain reps, is told to go heavier.
	JourneyLifts.open_named(PUSHDOWN, {"view": "compare"})
	await ShotHelper.wait(tree, 0.9)
	sh = _sheet()
	all = ShotHelper.all_text(sh)
	var pcard = _find("sides_card", sh)
	check(all.contains("too light") and _find("sides_tag", sh) == null and pcard != null and not bool(pcard.get_meta("sides_card")), "the pushdown: plain reps, too light, its switch off")
	await _close_sheets()

	# --- the Log tab: the L+R key ---------------------------------------------------------------
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.7)
	var ls = _log_screen()
	var form = ls.form() if ls != null else null
	check(form != null, "the lift form is open")
	if form != null:
		form.lift.exercises = []
		form.lift.add_exercise(CABLE)
		form.lift.add_exercise(CURL)
		await ShotHelper.wait(tree, 0.5)
		var c1 = _chip_of(form, "Lateral Raise")
		var c2 = _chip_of(form, "Bicep Curl")
		check(c1 != null and bool(c1.get_meta("both_chip")) and c2 != null and not bool(c2.get_meta("both_chip")), "the raise comes with L+R on, a new curl with it off")
		check(_all("both_hint").size() == 1 and ShotHelper.all_text(main).contains("· 11 to 13 a side"), "the raise's card says what L+R means, and last time a side")
		# Fill the curl in and switch its key on.
		var i2 = form.lift.exercises.size() - 1
		form.lift._on_set_text("20", i2, 0, "reps")
		form.lift._on_set_text("10", i2, 0, "weight")
		await ShotHelper.frames(tree, 3)
		c2 = _chip_of(form, "Bicep Curl")
		if c2 != null:
			ShotHelper.reveal(c2)
			await ShotHelper.frames(tree, 4)
			c2 = _chip_of(form, "Bicep Curl")
			var at2 = c2.get_global_rect().position
			await ShotHelper.click(tree, c2)
			await ShotHelper.wait(tree, 0.5)
			var c3 = _chip_of(form, "Bicep Curl")
			check(c3 != null and bool(c3.get_meta("both_chip")) and bool(form.lift.exercises[i2].get("both", false)), "tapped: the curl's reps are both sides added up")
			check(c3 != null and c3.get_global_rect().position.distance_to(at2) < 1.0, "the key stayed under the finger (%s -> %s)" % [str(at2), str(c3.get_global_rect().position) if c3 != null else "-"])
			check(_all("both_hint").size() == 2, "and its card says so")
		check(not App.both_sides(CURL), "nothing is stored until the workout is saved")
		await ShotHelper.snap(tree, "sides_5_log")
		var fin = ShotHelper.find_button(main, "Finish session")
		if fin != null:
			ShotHelper.press(fin)
		await ShotHelper.wait(tree, 0.6)
		var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
		if yes != null:
			ShotHelper.press(yes)
			await ShotHelper.wait(tree, 0.6)
		await _dismiss_reels()
		var done = App.lift_today()
		check(done != null and done.exercises.size() == 2, "the workout is saved")
		if done != null:
			check(done.exercises.all(func(ex): return not ex.has("bothSides") and ex.sets.all(func(one): return not one.has("sides"))), "the saved workout has plain exercises and plain sets")
			check(App.both_sides(str(done.exercises[1].name)) and App.settings()[Sides.KEY].size() == 1, "and the curl is both sides from now on (%s)" % str(App.settings().get(Sides.KEY)))

	# --- the Today card: a push day with the raise on it ----------------------------------------
	if App.lift_today() != null:
		App.delete_session(App.lift_today().id)
	App.update_settings({"dayPick": {"date": App.today, "kind": "push"}})
	App.go("home")
	await ShotHelper.wait(tree, 0.9)
	var planned = App.plan().lifts.filter(func(l): return str(l.name) == CABLE)
	check(planned.size() == 1 and int(planned[0].get("sides", 1)) == 2, "today's plan has the raise, as both sides (%s)" % str(App.plan().lifts.map(func(l): return str(l.name))))
	var cap = ShotHelper.find_text(main, "AIM · L+R")
	check(cap != null, "its row's aim is tagged L+R")
	if cap != null:
		ShotHelper.reveal(cap)
		await ShotHelper.wait(tree, 0.4)
	# (the row's orange block: the reps big, "AIM · L+R @ 15 lb" under them; 2026-11-27)
	var said_all = ShotHelper.all_text(main)
	check(said_all.contains("23, 22, 25") and said_all.contains("AIM · L+R @ 15 lb"), "and the aim is one more rep, not more weight")
	await ShotHelper.snap(tree, "sides_6_today")

	print("SIDES WALK: %d failed" % fails)
