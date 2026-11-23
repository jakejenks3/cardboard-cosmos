extends RefCounted
## The player's units where the rules write kg and km (run with the "year"
## data, pounds and miles): the results reel's record cards after a heavier
## bench and a longer run, the XP labels of a run's sheet, a trophy's words and
## what unlocks a piece of gear. Prints CHECK lines.

const LB = 0.45359237
const MI = 1609.344

var main: Node
var tree: SceneTree
var fails = 0
var reels = []


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


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


## Wait until the reel shows a record card, for a picture of it.
func _wait_record() -> bool:
	for i in range(80):
		await ShotHelper.wait(tree, 0.25)
		if ShotHelper.find_text(main, "NEW RECORD") != null:
			await ShotHelper.wait(tree, 0.5)
			return true
	return false


## A trophy's row as the cabinet makes it (AdventureScreen.open_trophy takes one).
func _trophy(id: String) -> Dictionary:
	var a = Achievements.by_id(id)
	var u = App.state.achievements.get(id)
	var p = a.progress.call(App.state) if (u == null and a.has("progress")) else null
	return {"a": a, "u": u, "p": p, "ratio": Goals.progress_ratio(p) if p != null else 0.0}


func _records(res: Dictionary) -> Array:
	return res.events.filter(func(e): return str(e.type) == "pr")


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	App.result_ready.connect(func(r): reels.append(r))
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	await ShotHelper.wait(tree, 0.4)

	# --- a heavier bench: the record card is in pounds ------------------------------------------
	var bench = App.state.prs.lifts.get("bench press - barbell")
	check(bench != null, "the demo player has a bench record")
	var was_lb = roundf(float(bench.weightKg) / LB) if bench != null else 135.0
	var now_lb = was_lb + 5.0
	App.commit_sessions([App.build_session({"discipline": "lift", "date": App.today, "exercises": [
		{"name": "Bench Press - Barbell", "sets": [{"reps": 3, "weightKg": now_lb * LB}, {"reps": 3, "weightKg": now_lb * LB}]}]})], "Workout")
	await ShotHelper.frames(tree, 3)
	var cards = _records(reels[reels.size() - 1]) if not reels.is_empty() else []
	var lift_card = cards.filter(func(e): return str(e.title) == "Bench Press - Barbell PR")
	check(lift_card.size() == 1 and str(lift_card[0].detail) == "%d lb (was %s)" % [int(now_lb), Fmt.fmt_weight(float(bench.weightKg), "lb")], "the bench record reads in pounds (%s)" % (str(lift_card[0].detail) if lift_card.size() == 1 else str(cards)))
	check(cards.all(func(e): return not str(e.detail).contains(" kg")), "no record card says kg")
	if await _wait_record():
		await ShotHelper.snap(tree, "units_1_lift_record")
	await _dismiss_reels()

	# --- a longer run: miles, a pace per mile, feet climbed -------------------------------------
	var far = float(App.state.prs.longestRunM) + 2.0 * MI
	var miles = snappedf(far / MI, 0.1)
	App.commit_sessions([App.build_session({"discipline": "run", "date": App.today, "distanceM": miles * MI, "elevationM": 300.0 / 3.28084, "durationSec": int(miles * 420.0)})], "Run")
	await ShotHelper.frames(tree, 3)
	cards = _records(reels[reels.size() - 1])
	var run_card = cards.filter(func(e): return str(e.title) == "Longest run!")
	check(run_card.size() == 1 and str(run_card[0].detail).begins_with("%s mi (was " % Units._short(miles, 2)) and str(run_card[0].detail).ends_with(" mi)"), "the longest run reads in miles (%s)" % (str(run_card[0].detail) if run_card.size() == 1 else str(cards)))
	var pace_card = cards.filter(func(e): return str(e.title).begins_with("Fastest pace"))
	check(pace_card.is_empty() or (str(pace_card[0].title) == "Fastest pace (3.11 mi+)!" and str(pace_card[0].detail).contains("/mi")), "a pace record is per mile (%s)" % str(pace_card))
	check(cards.all(func(e): return not str(e.detail).contains(" km") and not str(e.detail).contains("/km") and not str(e.title).contains(" km")), "no record card says km (%s)" % str(cards.map(func(e): return "%s: %s" % [e.title, e.detail])))
	if await _wait_record():
		await ShotHelper.snap(tree, "units_2_run_record")
	await _dismiss_reels()

	# --- the run's sheet: where the XP came from, in miles and feet -----------------------------
	var the_run = null
	for s in App.sessions():
		if str(s.discipline) == "run" and (the_run == null or s.createdAt > the_run.createdAt):
			the_run = s
	SessionView.open(the_run)
	await ShotHelper.wait(tree, 0.8)
	var sh = _sheet()
	var words = ShotHelper.all_text(sh)
	check(words.contains("%s mi  +" % Units._short(miles, 2)) and words.contains("300 ft climbed  +") and not words.contains(" km  +") and not words.contains(" m climbed"), "the run's XP chips are in miles and feet")
	await ShotHelper.snap(tree, "units_3_run_sheet")
	await _close_sheets()

	# --- a trophy and a piece of gear --------------------------------------------------------------
	AdventureScreen.open_trophy(_trophy("lift_220"))
	await ShotHelper.wait(tree, 0.8)
	sh = _sheet()
	var d = _find("trophy_desc", sh)
	check(d != null and str(d.text) == "Lift 485 lb in a set.", "a trophy's words are in pounds (%s)" % (str(d.text) if d != null else "-"))
	await ShotHelper.snap(tree, "units_4_trophy")
	await _close_sheets()
	AdventureScreen.open_trophy(_trophy("run_half"))
	await ShotHelper.wait(tree, 0.8)
	sh = _sheet()
	d = _find("trophy_desc", sh)
	check(d != null and str(d.text) == "Run 13.11 mi in one go.", "and in miles (%s)" % (str(d.text) if d != null else "-"))
	await _close_sheets()

	# Back in kg and km everything reads as the rules wrote it.
	App.update_settings({"weightUnit": "kg", "distanceUnit": "km"})
	await ShotHelper.wait(tree, 0.4)
	AdventureScreen.open_trophy(_trophy("lift_220"))
	await ShotHelper.wait(tree, 0.8)
	d = _find("trophy_desc", _sheet())
	check(d != null and str(d.text) == "Lift 220 kg in a set.", "in kg the trophy reads as before (%s)" % (str(d.text) if d != null else "-"))
	await _close_sheets()
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("UNITS WALK: %d failed" % fails)
