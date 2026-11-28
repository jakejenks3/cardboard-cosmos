extends SceneTree
## Unit test for game/sides.gd: lifts whose reps are logged as both sides
## added up, and everything that goes by one side because of it (the aim, the
## estimate, the rep ladder, the day's plan, the training summary, the save).
## Made-up data.
##   godot --headless --path . --script res://tests/sides_test.gd
## Prints SIDES: X/Y passed and exits with 1 when anything fails.

const CABLE = "Lateral Raise - Cable"
const PULLDOWN = "Lat Pulldown - Single arm"
const PUSHDOWN = "Tricep Pushdown - Rope"

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func sets(rows: Array) -> Array:
	var out = []
	for r in rows:
		out.append({"reps": r[0], "weightKg": float(r[1])})
	return out


## A lift session: {name: [[reps, kg], ...]}.
func lift(date: String, exercises: Dictionary) -> Dictionary:
	_n += 1
	var exs = []
	for name in exercises:
		exs.append({"name": name, "sets": sets(exercises[name])})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "exercises": exs}


func planned(plan: Dictionary, name: String):
	for l in plan.lifts:
		if str(l.name) == name:
			return l
	return null


func _init() -> void:
	_run()


func _run() -> void:
	# --- which lifts ---------------------------------------------------------------------------
	ok(Sides.usual(CABLE) and Sides.usual("Lateral Raise - Home cable") and Sides.usual("Lateral Raise - Single arm cable") and Sides.usual("lateral raise - CABLE"), "a lateral raise on a cable is both sides added up")
	ok(not Sides.usual("Lateral Raise - Dumbbell") and not Sides.usual("Lateral Raise") and not Sides.usual("Chest Fly - Cable"), "a dumbbell raise is not, nor any other cable lift")
	ok(Sides.usual(PULLDOWN) and Sides.usual("Lat Pulldown - Single arm gym") and not Sides.usual("Lat Pulldown") and not Sides.usual("Lat Pulldown - Wide") and not Sides.usual("Bent Over Row - Single arm dumbbell"), "a single arm lat pulldown is, a plain pulldown and a single arm row are not")
	ok(Sides.both({}, CABLE) and Sides.n({}, CABLE) == 2 and not Sides.both({}, PUSHDOWN) and Sides.n({}, PUSHDOWN) == 1, "with nothing stored a lift goes by the usual")
	var off = {Sides.KEY: Sides.with_mark({}, CABLE, false)}
	ok(not Sides.both(off, CABLE) and off[Sides.KEY].size() == 1 and off[Sides.KEY]["lateral raise - cable"].name == CABLE and Sides.both(off, PULLDOWN), "switched off: it sticks, and only for that lift", off)
	ok(Sides.with_mark(off, CABLE, true).is_empty(), "switched on again: back to the usual, nothing stored")
	var on = {Sides.KEY: Sides.with_mark({}, PUSHDOWN, true)}
	ok(Sides.both(on, PUSHDOWN) and Sides.both(on, "tricep pushdown - rope") and not Sides.both(on, "Tricep Pushdown - Bar") and Sides.with_mark(on, PUSHDOWN, false).is_empty(), "any lift can be switched on: that movement and variation only", on)
	ok(Sides.names(on, [CABLE, PUSHDOWN, "Bench Press - Barbell"]) == [CABLE, PUSHDOWN] and Sides.with_mark({}, "  ", true).is_empty(), "the lifts that are both sides, of a list")
	ok(Sides.marks({Sides.KEY: "nonsense"}).is_empty() and Sides.both({Sides.KEY: {"lateral raise - cable": "x"}}, CABLE), "a broken mark is no mark")

	# --- a lift renamed stays what it was ---------------------------------------------------------
	var r1 = {Sides.KEY: Sides.renamed({}, CABLE, "Side Raise - Machine", false)}
	ok(Sides.both(r1, "Side Raise - Machine") and r1[Sides.KEY].size() == 1, "a usual one under a new name is still both sides", r1)
	var r2 = {Sides.KEY: Sides.renamed(on, PUSHDOWN, "Tricep Extension - Single arm", false)}
	ok(Sides.both(r2, "Tricep Extension - Single arm") and not Sides.both(r2, PUSHDOWN) and r2[Sides.KEY].size() == 1, "a marked one takes its mark along", r2)
	var r3 = {Sides.KEY: Sides.renamed({}, "Lateral Raise - Dumbbell", "Lateral Raise - Low cable", false)}
	ok(not Sides.both(r3, "Lateral Raise - Low cable"), "one that was not stays not, though its new name is a usual one", r3)
	ok(Sides.renamed(on, PUSHDOWN, "Tricep Pushdown - Bar", true).is_empty() and Sides.renamed({}, "Bench Press - Barbell", "Bench Press - Bar", false).is_empty(), "joined with a lift that was there: that one's way is kept; nothing to keep, nothing stored")

	# --- tags travel with the sets, the sets given are left alone ---------------------------------
	var raw = sets([[22, 8], [22, 8], [25, 8]])
	var tagged = Sides.tag_sets(raw, 2)
	ok(Sides.of_sets(tagged) == 2 and Sides.of_sets(raw) == 1 and not raw[0].has("sides") and int(tagged[2].reps) == 25 and tagged.size() == 3, "tagged copies; the sets given are untouched", [raw, tagged])
	ok(Sides.of_sets(Sides.tag_sets(tagged, 1)) == 1 and Sides.of_sets([]) == 1, "tagged with one side: the tag comes off")
	var hist = [{"date": "2026-11-19", "id": "b", "sets": raw}, {"date": "2026-11-16", "id": "a", "sets": sets([[20, 8]])}]
	var th = Sides.tagged(hist, 2)
	ok(th.size() == 2 and str(th[0].id) == "b" and Sides.of_sets(th[1].sets) == 2 and not hist[1].sets[0].has("sides") and not hist[0].has("sides"), "a history tagged: new rows, new sets")
	ok(Sides.side_range(raw) == [11, 13] and Sides.side_words(raw) == "11 to 13 a side" and Sides.side_words(sets([[26, 8], [26, 8]])) == "13 a side" and Sides.side_words(sets([[25, 8]])) == "12 to 13 a side", "22, 22 and 25 are 11 to 13 a side; 25 is a 12 and a 13", Sides.side_words(raw))
	ok(Sides.side_words([]) == "" and Sides.side_words(sets([[1, 8]])) == "1 a side" and Sides.side_words(sets([[0, 8]])) == "" and is_equal_approx(Sides.a_side(25), 12.5) and is_equal_approx(Sides.a_side(25, 1), 25.0), "no reps, no words; half of 25 is 12.5")

	# --- the aim goes by one side ------------------------------------------------------------------
	var plain = LiftTrend.next_target(raw, 2.5)
	ok(bool(plain.get("heavier", false)) and int(plain.reps) == 10 and int(plain.sides) == 1, "22, 22, 25 as plain reps: too light, go heavier and down to 10 (as before)", plain)
	var aim = LiftTrend.next_target(tagged, 2.5)
	ok(not aim.has("heavier") and aim.kind == "reps" and int(aim.set) == 1 and int(aim.reps) == 23 and int(aim.sides) == 2 and is_equal_approx(float(aim.kg), 8.0), "the same sets as both sides added up: 11 a side is no reason to go heavier, one more rep", aim)
	ok(aim.sets.map(func(s): return int(s.reps)) == [23, 22, 25] and aim.sets.all(func(s): return is_equal_approx(float(s.weightKg), 8.0)) and Sides.of_sets(aim.sets) == 2, "the sets to aim for, still tagged", aim.sets)
	var even = LiftTrend.next_target(Sides.tag_sets(sets([[26, 8], [26, 8], [26, 8]]), 2), 2.5)
	ok(even.kind == "weight" and not even.has("heavier") and int(even.reps) == 26 and is_equal_approx(float(even.addKg), 2.5), "every set the same: more weight, the usual way", even)
	var high = LiftTrend.next_target(Sides.tag_sets(sets([[30, 8], [31, 8]]), 2), 2.5)
	ok(bool(high.get("heavier", false)) and int(high.reps) == 20 and high.sets.all(func(s): return int(s.reps) == 20 and is_equal_approx(float(s.weightKg), 10.5)), "15 a side and more on every set: heavier, down to 10 a side (20)", high)
	var nearly = LiftTrend.next_target(Sides.tag_sets(sets([[29, 8], [31, 8]]), 2), 2.5)
	ok(not nearly.has("heavier") and nearly.kind == "reps" and int(nearly.reps) == 30, "29 is a 14 and a 15: not every side is there yet", nearly)
	var side_hold = LiftTrend.next_target(Sides.tag_sets([{"reps": 2, "weightKg": 0.0, "holdSec": 30}], 2), 2.5)
	ok(side_hold.kind == "hold" and int(side_hold.addSec) == 5, "a hold is a hold either way")

	# --- the estimate and the ladder go by one side --------------------------------------------------
	var d1 = LiftTrend.day(sets([[20, 30]]))
	var d2 = LiftTrend.day(Sides.tag_sets(sets([[20, 30]]), 2))
	ok(is_equal_approx(float(d1.e1rm), 50.0) and is_equal_approx(float(d2.e1rm), 40.0), "20 reps at 30: an estimate of 50 as plain reps, 40 as ten a side", [d1.e1rm, d2.e1rm])
	ok(int(d2.reps) == 20 and int(d2.topReps) == 20 and int(d2.bestReps) == 20 and is_equal_approx(float(d2.volumeKg), 600.0), "the reps and the weight moved stay as logged", d2)
	var lad1 = LiftTrend.rep_ladder([{"date": "2026-11-19", "sets": sets([[9, 10]])}])
	var lad2 = LiftTrend.rep_ladder([{"date": "2026-11-19", "sets": Sides.tag_sets(sets([[9, 10]]), 2)}])
	ok(int(lad1[lad1.size() - 1].to) == 9 and int(lad2[lad2.size() - 1].to) == 4, "9 reps: a ladder up to 9, or up to 4 a side", [lad1, lad2])
	var fix1 = LiftTrend.plateau_fixes([{"date": "2026-11-19", "sets": raw}], CABLE, "kg")
	var fix2 = LiftTrend.plateau_fixes([{"date": "2026-11-19", "sets": tagged}], CABLE, "kg")
	var reps1 = fix1.filter(func(f): return f.title == "Change the reps")[0].text
	var reps2 = fix2.filter(func(f): return f.title == "Change the reps")[0].text
	ok(str(reps1).contains("sets of about 25:") and str(reps2).contains("sets of about 13 a side:") and str(reps2).contains("reps a side."), "the advice on reps speaks of one side", [reps1, reps2])

	# --- the day's plan -------------------------------------------------------------------------------
	var push = {"Bench Press - Barbell": [[5, 80], [5, 80]], CABLE: [[22, 8], [22, 8], [25, 8]], PUSHDOWN: [[22, 20], [22, 20], [25, 20]]}
	var pull = {PULLDOWN: [[14, 30], [11, 30], [11, 30]], "Bent Over Row - Barbell": [[8, 60], [8, 60]]}
	var legs = {"Squat - Barbell": [[5, 100], [5, 100]]}
	# (the cycle is pull, push, legs: the day after a pull day is a push day)
	var log = [lift("2026-11-09", pull), lift("2026-11-10", push), lift("2026-11-11", legs), lift("2026-11-12", pull), lift("2026-11-13", push), lift("2026-11-14", legs), lift("2026-11-15", pull)]
	var day = "2026-11-16"
	var st = {"split": "pull_push_legs", "weightUnit": "kg"}
	var plan = Missions.day_plan(log, day, {}, st)
	var raise = planned(plan, CABLE)
	var down = planned(plan, PUSHDOWN)
	ok(plan.kind == "push" and raise != null and down != null, "a push day with the cable raise and the pushdown", plan.lifts.map(func(l): return str(l.name)))
	if raise != null and down != null:
		ok(int(raise.get("sides", 1)) == 2 and Sides.of_sets(raise.last.sets) == 2 and int(raise.options[0].get("sides", 1)) == 2 and Sides.of_sets(raise.options[0].last) == 2, "the planned raise and the way to do it say their reps are both sides", raise.options[0])
		ok(not down.has("sides") and Sides.of_sets(down.last.sets) == 1 and Sides.of_sets(down.options[0].last) == 1, "the pushdown is plain reps")
		var a_raise = LiftTrend.next_target(raise.options[0].last, 2.5)
		var a_down = LiftTrend.next_target(down.options[0].last, 2.5)
		ok(not a_raise.has("heavier") and a_raise.kind == "reps" and int(a_raise.reps) == 23 and bool(a_down.get("heavier", false)), "the raise aims for one more rep; the pushdown, with the same numbers, for more weight", [a_raise, a_down])
		var morning = Missions.morning_text(plan, [], "kg")
		ok(morning.contains("Lateral Raise (cable): 23, 22, 25 @ 8 kg (both sides added up)") and morning.contains("Tricep Pushdown (rope): 3×10 @ 22.5 kg") and not morning.contains("22.5 kg (both"), "the morning message says so", morning)
	ok(log.all(func(s): return s.exercises.all(func(ex): return ex.sets.all(func(one): return not one.has("sides")))), "the log's own sets are never tagged")
	var p_off = Missions.day_plan(log, day, {}, {"split": "pull_push_legs", Sides.KEY: Sides.with_mark({}, CABLE, false)})
	var p_on = Missions.day_plan(log, day, {}, {"split": "pull_push_legs", Sides.KEY: Sides.with_mark({}, PUSHDOWN, true)})
	ok(not planned(p_off, CABLE).has("sides") and bool(LiftTrend.next_target(planned(p_off, CABLE).options[0].last, 2.5).get("heavier", false)), "switched off for the raise: plain reps again, heavier")
	ok(int(planned(p_on, PUSHDOWN).get("sides", 1)) == 2 and not LiftTrend.next_target(planned(p_on, PUSHDOWN).options[0].last, 2.5).has("heavier"), "switched on for the pushdown: one side, no heavier")
	var pull_plan = Missions.day_plan(log, "2026-11-15", {}, st)
	var pd = planned(pull_plan, PULLDOWN)
	ok(pd != null and int(pd.get("sides", 1)) == 2 and LiftTrend.next_target(pd.options[0].last, 2.5).sets.map(func(s): return int(s.reps)) == [14, 12, 11], "the single arm pulldown is both sides too: 14, 11, 11 aims for 14, 12, 11", pd)
	# The missions: beat it says what it is a side, and never "too light".
	var two = {"Bench Press - Barbell": [[5, 80], [5, 80]], CABLE: [[22, 8], [22, 8], [25, 8]]}
	var log2 = [lift("2026-11-09", pull), lift("2026-11-10", two), lift("2026-11-11", legs), lift("2026-11-12", pull), lift("2026-11-13", two), lift("2026-11-14", legs), lift("2026-11-15", pull)]
	var state = {"levels": {"hero": {"level": 10}}, "sessionXp": {}, "body": {"entries": 0}}
	var missions = Missions.daily(day, {"sessions": log2, "pt": {}, "settings": st, "reading": []}, state, [])
	var beat = missions.filter(func(m): return str(m.id).contains(":beat:") and str(m.title).contains("Lateral Raise"))
	ok(beat.size() == 1 and str(beat[0].desc).contains("Reps are both sides added up.") and LiftTrend.real_sets(beat[0].aim).all(func(one): return int(one.get("sides", 1)) == 2), "the challenge says its reps are both sides added up; its aim goes by a side", beat.map(func(m): return m.desc))
	# The days ahead are made from pretended sessions: the plan is the same after them.
	var ahead = Missions.ahead(log, day, {}, st, 4)
	var again = null
	for a in ahead.slice(1):
		if again == null and planned(a.plan, CABLE) != null:
			again = planned(a.plan, CABLE)
	ok(again != null and int(again.get("sides", 1)) == 2 and not LiftTrend.next_target(again.options[0].last, 2.5).has("heavier"), "the look-ahead plans it as both sides as well", ahead.map(func(a): return a.plan.kind))

	# --- the training summary -------------------------------------------------------------------------
	var sessions = []
	for d in ["2026-11-03", "2026-11-06", "2026-11-10", "2026-11-13"]:
		sessions.append(lift(d, {CABLE: [[22, 8], [23, 8], [25, 8]], "Lateral Raise - Dumbbell": [[12, 8], [13, 8], [13, 8]]}))
	var saved = {"sessions": sessions, "pt": {}, "settings": {"weightUnit": "kg", "distanceUnit": "km"}, "body": []}
	var f = Dosage.figures(saved, "2026-11-14")
	ok(f.bands == [0, 0, 24, 0] and f.both == [CABLE] and is_equal_approx(float(f.parts.shoulders.reps), 4 * 73.0) and is_equal_approx(float(f.parts.shoulders.vol), 4 * 8.0 * 108), "the summary counts one side: every set is in 11-15, and the weight moved is the total", [f.bands, f.both, f.parts.shoulders])
	var text = Dosage.text(saved, "2026-11-14")
	ok(text.contains("- Lateral Raise - Cable [shoulders, L+R]: 4 days; latest Nov 13: 22, 23, 25 @ 8 kg (both sides added up: 11 to 13 a side); first Nov 3: 22, 23, 25 @ 8 kg (both sides added up: 11 to 13 a side); heaviest 8 kg × 25 (12 to 13 a side).")
		and text.contains("- Lateral Raise - Dumbbell [shoulders]: 4 days; latest Nov 13: 12, 13, 13 @ 8 kg; first Nov 3: 12, 13, 13 @ 8 kg; heaviest 8 kg × 13."), "each lift's line: the cable raise marked L+R with its reps a side, the dumbbell raise as it is", text)
	ok(text.contains("about 12 reps a set") and text.contains("11-15 100%") and text.contains("ADDED TOGETHER") and text.contains("count ONE side of those"), "and it says what L+R means", text)
	var plain_saved = saved.duplicate(true)
	plain_saved.settings[Sides.KEY] = Sides.with_mark({}, CABLE, false)
	var pf = Dosage.figures(plain_saved, "2026-11-14")
	var ptext = Dosage.text(plain_saved, "2026-11-14")
	ok(pf.bands == [0, 0, 12, 12] and pf.both.is_empty() and not ptext.contains("L+R") and not ptext.contains("a side"), "switched off: 22 to 25 are plain reps again and nothing is said of sides", [pf.bands, pf.both])

	# --- the reel's "est. 1RM PR" card goes by one side ---------------------------------------------
	var before_log = [lift("2026-11-10", {CABLE: [[22, 8]], "Bench Press - Barbell": [[5, 80]]})]
	var fresh_up = lift("2026-11-13", {CABLE: [[25, 8]], "Bench Press - Barbell": [[6, 80]]})
	var evs = [{"type": "xp"}, {"type": "pr", "title": "Lateral Raise - Cable est. 1RM PR", "detail": "14.7 kg (was 13.9 kg)"}, {"type": "pr", "title": "Bench Press - Barbell est. 1RM PR", "detail": "96 kg (was 93.3 kg)"}]
	var fixed = Sides.fix_estimates(evs, [fresh_up], before_log, {})
	ok(fixed.size() == 3 and str(fixed[1].detail) == "11.3 kg (was 10.9 kg), going by one side" and str(fixed[2].detail) == "96 kg (was 93.3 kg)" and str(evs[1].detail) == "14.7 kg (was 13.9 kg)", "the card of a both-sides lift is worked out for one side; the bench card and the events given are left alone", fixed)
	# 30 at 8 beats 15 at 10 as plain reps (16 against 15), not going by one side (12 against 12.5).
	var not_one = Sides.fix_estimates([{"type": "pr", "title": "Lateral Raise - Cable est. 1RM PR", "detail": "16 kg (was 15 kg)"}], [lift("2026-11-13", {CABLE: [[30, 8]]})], [lift("2026-11-10", {CABLE: [[15, 10]]})], {})
	ok(not_one.is_empty(), "no best for one side: no card", not_one)
	var as_is = Sides.fix_estimates(evs, [fresh_up], before_log, {Sides.KEY: Sides.with_mark({}, CABLE, false)})
	ok(as_is == evs and Sides.fix_estimates(evs, [{"discipline": "run", "id": "r"}], before_log, {}) == evs, "switched off, or no lift logged: the cards as the rules made them")

	# --- the save: the switch, the Log tab's key, a lift renamed --------------------------------------
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		print("SKIP  the save: no App")
	else:
		app.replace_all(app.empty_saved())
		ok(app.both_sides(CABLE) and not app.both_sides(PUSHDOWN) and not app.settings().has(Sides.KEY), "a new save: the usual ones, nothing stored")
		app.set_both_sides(PUSHDOWN, true)
		app.set_both_sides(CABLE, false)
		var kept = app.parse_saved(JSON.parse_string(JSON.stringify(app.saved)))
		ok(app.both_sides(PUSHDOWN) and not app.both_sides(CABLE) and kept != null and Sides.both(kept.settings, PUSHDOWN) and not Sides.both(kept.settings, CABLE), "the switch is stored, and a save file keeps it", app.settings().get(Sides.KEY))
		app.set_both_sides(CABLE, true)
		app.set_both_sides(PUSHDOWN, false)
		ok(app.settings()[Sides.KEY].is_empty(), "switched back: nothing left stored", app.settings().get(Sides.KEY))
		# The Log tab's key: the flag rides on the exercise and is stored with the workout.
		var s1 = app.build_session({"discipline": "lift", "date": app.today, "exercises": [
			{"name": "Bicep Curl - Single arm cable", "sets": sets([[20, 10], [20, 10]]), "bothSides": true},
			{"name": CABLE, "sets": sets([[12, 8]]), "bothSides": false},
			{"name": "Bench Press - Barbell", "sets": sets([[5, 80]])}]})
		app.commit_sessions([s1], "Workout")
		var stored = app.sessions()[0].exercises
		ok(stored.all(func(ex): return not ex.has("bothSides")) and app.both_sides(str(stored[0].name)) and not app.both_sides(CABLE) and not app.both_sides("Bench Press - Barbell"), "saved with the L+R key on and off: stored for those lifts, and the flag is off the exercise", [stored.map(func(ex): return ex.name), app.settings().get(Sides.KEY)])
		ok(stored.all(func(ex): return ex.sets.all(func(one): return not one.has("sides"))) and int(app.state.xp.hero) > 0, "the saved sets are plain sets")
		var curl = str(stored[0].name)
		var plan_now = app.plan()
		var res = app.rename_lift(curl, "Bicep Curl - One arm low cable")
		ok(bool(res.ok) and app.both_sides("Bicep Curl - One arm low cable") and not app.settings()[Sides.KEY].has(Sides.key(curl)), "renamed: still both sides, under its new name", [res, app.settings().get(Sides.KEY)])
		ok(plan_now is Dictionary, "the plan was made")
		app.replace_all(app.empty_saved())

	print("SIDES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
