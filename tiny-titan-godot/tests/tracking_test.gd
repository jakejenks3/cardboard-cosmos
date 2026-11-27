extends SceneTree
## Unit test for the 2026-11-27 batch ("build all"): notes per lift (LiftNotes), goals with a date
## (LiftGoals), the weekly sets over weeks, the on-target streak, the lift report and the bodyweight trend
## (TrainingReport), heavy and light days (LiftTrend.RANGES, Missions._tag_ranges), the rotation hint
## (Missions._mark_rotation), the free swap of a mission and a muscle's week (Missions).
##   godot --headless --path . --script res://tests/tracking_test.gd
## Prints TRACKING: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
const TODAY = "2026-11-27"


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


func _sets(n: int, reps: int, kg: float) -> Array:
	var out = []
	for i in range(n):
		out.append({"reps": reps, "weightKg": kg})
	return out


func _lift(back: int, exs: Dictionary, id: String = "") -> Dictionary:
	var e = []
	for nm in exs:
		e.append({"name": nm, "sets": exs[nm]})
	return {"id": id if id != "" else "s%d_%d" % [back, randi() % 100000], "discipline": "lift", "date": Dates.add_days(TODAY, -back), "createdAt": 1000 + back, "exercises": e}


func _run() -> void:
	# --- notes ----------------------------------------------------------------------------------------------
	var st = {}
	st[LiftNotes.KEY] = LiftNotes.with_note(st, "Lat Pulldown - Single arm home", "  pin 7,\nseat 4 ", TODAY)
	ok(LiftNotes.of(st, "lat pulldown - single arm home") == "pin 7, seat 4", "a note is kept per lift, one line", st)
	st[LiftNotes.KEY] = LiftNotes.renamed(st, "Lat Pulldown - Single arm home", "Lat Pulldown - Single arm")
	ok(LiftNotes.of(st, "Lat Pulldown - Single arm") == "pin 7, seat 4" and LiftNotes.of(st, "Lat Pulldown - Single arm home") == "", "a renamed lift keeps its note")
	st[LiftNotes.KEY] = LiftNotes.with_note(st, "Lat Pulldown - Single arm", "")
	ok(LiftNotes.of(st, "Lat Pulldown - Single arm") == "" and (st[LiftNotes.KEY] as Dictionary).is_empty(), "an empty note takes it off")
	ok(LiftNotes.with_note({}, "x", "a".repeat(400))["x"].text.length() == LiftNotes.MAX_LEN, "a long note is cut")

	# --- goals --------------------------------------------------------------------------------------------------
	var bench = "Bench Press - Barbell"
	var log = []
	for k in range(6):
		log.append(_lift(35 - k * 7, {bench: _sets(3, 5, 70.0 + 2.5 * k)}))
	var g = LiftGoals.make(bench, 85.0, 5, Dates.add_days(TODAY, 56), log, TODAY, "g1")
	ok(float(g.start) > 0.0 and str(g.at) == TODAY and str(g.done) == "", "a goal starts from the lift's best estimate of the last weeks", g)
	var gs = LiftGoals.status(g, log, TODAY)
	ok(str(gs.state) == "on" and str(gs.eta) > TODAY and str(gs.eta) <= str(g.by) and float(gs.pct) == 0.0, "going up 2.5 kg a week: on track, with a day before the goal's (an estimate)", gs)
	var g_far = LiftGoals.make(bench, 130.0, 5, Dates.add_days(TODAY, 14), log, TODAY, "g2")
	ok(str(LiftGoals.status(g_far, log, TODAY).state) == "behind", "a goal too far for the pace is behind")
	var flat = []
	for k in range(4):
		flat.append(_lift(30 - k * 7, {bench: _sets(3, 5, 80.0)}))
	ok(str(LiftGoals.status(LiftGoals.make(bench, 90.0, 5, "", flat, TODAY, "g3"), flat, TODAY).state) == "slow", "a lift not going up has no date")
	ok(str(LiftGoals.status(LiftGoals.make(bench, 90.0, 5, "", [], TODAY, "g4"), [], TODAY).state) == "unknown", "no history: no forecast")
	var hit = log + [_lift(0, {bench: [{"reps": 6, "weightKg": 85.0}]})]
	ok(LiftGoals.reached_on(g, hit) == TODAY and str(LiftGoals.status(g, hit, TODAY).state) == "done" and LiftGoals.newly_done([g], hit).size() == 1, "a set at the weight for the reps reaches it")
	ok(LiftGoals.reached_on(g, log + [_lift(0, {bench: [{"reps": 4, "weightKg": 90.0}]})]) == "", "heavier for fewer reps does not")
	var old_g = g.duplicate()
	old_g.at = Dates.add_days(TODAY, 1)
	ok(LiftGoals.reached_on(old_g, hit) == "", "a set before the goal was set does not count")
	var parsed = LiftGoals.parse([g, {"id": "", "lift": "x", "kg": 1}, {"id": "a", "lift": "y", "kg": 0}, "no"])
	ok(parsed.size() == 1 and parsed[0].id == "g1", "a save's goals are cleaned", parsed)

	# --- heavy and light days -------------------------------------------------------------------------------------
	ok(LiftTrend.next_range(_sets(3, 6, 80.0)) == "light" and LiftTrend.next_range(_sets(3, 12, 60.0)) == "heavy", "after a heavy day a light one, and back")
	ok(LiftTrend.next_range([{"reps": 10, "weightKg": 0.0}]) == "" and LiftTrend.next_range([{"reps": 15, "weightKg": 0.0, "band": "red"}]) == "", "no range for bodyweight or a band")
	var step = 2.5
	var t_same = LiftTrend.next_target(LiftTrend.tag_range(_sets(3, 7, 80.0), "heavy"), step)
	ok(str(t_same.range) == "heavy" and str(t_same.kind) == "reps" and int(t_same.reps) == 8, "a heavy day after a heavy day: one more rep", t_same)
	var t_top = LiftTrend.next_target(LiftTrend.tag_range(_sets(3, 8, 80.0), "heavy"), step)
	ok(str(t_top.kind) == "weight" and is_equal_approx(float(t_top.sets[0].weightKg), 82.5) and int(t_top.sets[0].reps) == 6, "at the top of the range: heavier, back to 6", t_top)
	var t_sw = LiftTrend.next_target(LiftTrend.tag_range(_sets(3, 6, 80.0), "light"), step)
	ok(bool(t_sw.get("switch", false)) and int(t_sw.sets[0].reps) == 10 and float(t_sw.sets[0].weightKg) < 80.0 and fmod(float(t_sw.sets[0].weightKg), 2.5) < 0.01, "a light day after a heavy one: 10 reps at a lighter weight from the estimate", t_sw)
	var t_up = LiftTrend.next_target(LiftTrend.tag_range(_sets(3, 12, 60.0), "heavy"), step)
	ok(int(t_up.sets[0].reps) == 6 and float(t_up.sets[0].weightKg) > 60.0, "a heavy day after a light one: heavier, 6 reps", t_up)
	ok(LiftTrend.aim_cap(t_sw) == "LIGHT DAY · 10-12" and LiftTrend.aim_cap(LiftTrend.next_target(_sets(3, 7, 80.0), step)) == "AIM", "the aim says which day it is")
	var both = Sides.tag_sets(LiftTrend.tag_range(_sets(3, 14, 20.0), "heavy"), 2)
	var t_both = LiftTrend.next_target(both, step)
	ok(int(t_both.lo) == 12 and int(t_both.sets[0].reps) == 14 + 1 and LiftTrend.aim_cap(t_both).ends_with("A SIDE"), "both sides added up: the range is a side", t_both)
	ok(not LiftTrend.next_target(_sets(3, 7, 80.0), step).has("range"), "untagged sets aim as before")

	# --- the plan tags a build lift, and the rotation hint ----------------------------------------------------------
	var settings = {"focus": "upper", "weightUnit": "kg", "split": "auto"}
	var press = []
	for k in range(7):
		press.append(_lift(28 - k * 4, {bench: _sets(3, 6, 80.0), "Bench Press - Dumbbell" if k == 0 else bench + "x": _sets(1, 1, 1.0)}))
	var l = {"name": bench, "mode": "build", "pt": false, "last": {"date": "x", "sets": _sets(3, 6, 80.0)}, "options": [{"name": bench, "move": "Bench Press", "last": _sets(3, 6, 80.0)}]}
	Missions._tag_ranges(l, settings)
	ok(str(l.range) == "light" and str(l.last.sets[0].range) == "light" and str(l.options[0].last[0].range) == "light", "a lift being built is planned for its next range", l)
	var l2 = {"name": bench, "mode": "keep", "pt": false, "last": {"date": "x", "sets": _sets(3, 6, 80.0)}, "options": []}
	Missions._tag_ranges(l2, settings)
	ok(not l2.has("range"), "a kept muscle's lift is not")
	var l3 = {"name": bench, "mode": "build", "pt": false, "last": {"date": "x", "sets": _sets(3, 6, 80.0)}, "options": []}
	Missions._tag_ranges(l3, {"focus": "upper", "repRanges": false})
	ok(not l3.has("range"), "off in Settings: no ranges")
	var hist = LiftLibrary.stats(press)
	var lr = {"name": bench, "pt": false, "options": [{"name": bench, "move": "Bench Press"}, {"name": "Bench Press - Dumbbell", "move": "Bench Press"}]}
	Missions._mark_rotation(lr, hist)
	ok(not lr.has("rotate"), "a different variation among the last six: no hint", hist.keys())
	var same = []
	for k in range(6):
		same.append(_lift(30 - k * 4, {bench: _sets(3, 6, 80.0)}))
	same.append(_lift(40, {"Bench Press - Dumbbell": _sets(3, 10, 30.0)}))
	Missions._mark_rotation(lr, LiftLibrary.stats(same))
	ok(str(lr.get("rotate", "")) == "Bench Press - Dumbbell", "six times the same way: the other way is offered as a change", lr)

	# --- the weekly sets, the streak --------------------------------------------------------------------------------
	var weekly = []
	var monday = Dates.week_key(TODAY)
	for wkn in range(1, 5):
		var wk = Dates.add_days(monday, -7 * wkn)
		for d in range(3):
			weekly.append(_lift(Dates.days_between(Dates.add_days(wk, d * 2), TODAY), {
				"Bench Press - Barbell": _sets(5, 8, 70.0), "Bent Over Row - Barbell": _sets(6, 8, 60.0), "Lateral Raise - Dumbbell": _sets(4, 12, 8.0),
				"Face Pull - Cable": _sets(3, 12, 20.0), "Bicep Curl - Dumbbell": _sets(4, 10, 12.0), "Tricep Pushdown - Cable": _sets(4, 10, 25.0)}))
	var ws = TrainingReport.weekly_sets(weekly, {}, settings, TODAY)
	ok(ws.weeks.size() == TrainingReport.WEEKS and ws.parts.has("chest") and ws.parts[0] == "chest" or ws.parts.has("chest"), "weekly sets: 8 weeks, every muscle with a target", ws.parts)
	ok(float(ws.weeks[ws.weeks.size() - 2].parts.chest) >= 10.0 and float(ws.weeks[0].parts.chest) == 0.0, "the weeks trained have their sets, the weeks before none", ws.weeks.map(func(w): return w.parts.chest))
	var sk = TrainingReport.streak(weekly, {}, settings, TODAY)
	ok(int(sk.now) == 4 and str(sk.badge) == "Bronze" and int(sk.next) == 2 and str(sk.nextBadge) == "Silver", "four weeks on target in a row: Bronze, two more for Silver", sk)
	ok(int(TrainingReport.streak([], {}, settings, TODAY).now) == 0 and int(TrainingReport.streak(weekly, {}, {"focus": ""}, TODAY).now) == 0, "no log or no focus: no streak")

	# --- the lift report ------------------------------------------------------------------------------------------------
	var rep_log = []
	for k in range(8):
		rep_log.append(_lift(55 - k * 7, {"Squat - Barbell": _sets(3, 5, 100.0 + 5.0 * k), "Overhead Press - Barbell": _sets(3, 5, 50.0 - 1.0 * k), "Bent Over Row - Barbell": _sets(3, 8, 60.0)}))
	rep_log.append(_lift(2, {"Hip Thrust - Barbell": _sets(3, 10, 80.0)}))
	var rep = TrainingReport.lift_report(rep_log, {}, TODAY)
	var names = func(key): return rep[key].map(func(r): return str(r.name))
	ok(names.call("up").has("Squat - Barbell") and names.call("down").has("Overhead Press - Barbell") and names.call("new").has("Hip Thrust - Barbell"), "the report: up, down and new", rep)
	ok(names.call("stuck").has("Bent Over Row - Barbell") or names.call("flat").has("Bent Over Row - Barbell"), "the same every time: holding or stuck", rep)

	# --- the bodyweight trend -------------------------------------------------------------------------------------------
	var body = []
	for k in range(15):
		body.append({"id": "b%d" % k, "date": Dates.add_days(TODAY, -2 * k), "weightKg": 82.0 + 0.1 * k})
	var bt = TrainingReport.body_trend(body, rep_log, {}, TODAY)
	ok(int(bt.n) == 14 and float(bt.weekly) < -0.3 and float(bt.weekly) > -0.4 and float(bt.avg) < 82.5, "the trend: 14 weigh-ins, about 0.35 kg a week down, a 7-day average", bt)
	ok(not (bt.lifts as Array).is_empty(), "with the main lifts meanwhile", bt.lifts)
	ok(int(TrainingReport.body_trend([], [], {}, TODAY).n) == 0, "no weigh-ins: nothing")

	# --- the free swap ------------------------------------------------------------------------------------------------
	var state = {"levels": {"hero": {"level": 3}}, "sessionXp": {}}
	var data = {"sessions": [], "pt": {}, "settings": {}, "reading": [], "now": TODAY, "body": []}
	var list = [Missions._mission("t:%s:show" % TODAY, "daily", TODAY, "Show up", "", "flame", null, 1, 0, "", 150, []),
		Missions._mission("t:%s:beat:x" % TODAY, "daily", TODAY, "Beat it: X", "", "sword", "lift", 1, 0, "", 200, [])]
	ok(not Missions.can_reroll(list[0]) and Missions.can_reroll(list[1]), "Show up cannot be swapped; a lift's mission can")
	var out = Missions.rerolled(list, "t:%s:beat:x" % TODAY, TODAY, data, state, [])
	ok(out.size() == 2 and str(out[1].id) == "t:%s:sets" % TODAY and bool(out[1].rerolled) and str(out[1].swappedFor) == "Beat it: X", "a swapped mission is replaced by a spare one", out[1])
	var s2 = Missions.with_reroll({Missions.REROLLS: {"2026-10-01": "old", Dates.add_days(TODAY, -1): "y"}}, TODAY, "z")
	ok(s2.size() == 2 and str(s2[TODAY]) == "z" and not s2.has("2026-10-01"), "one swap a day, old ones dropped", s2)
	var d0 = Missions.daily(TODAY, data, state, [])
	var pick = ""
	for m in d0:
		if Missions.can_reroll(m) and pick == "":
			pick = str(m.id)
	data.settings = {Missions.REROLLS: {TODAY: pick}}
	var d = Missions.daily(TODAY, data, state, [])
	ok(pick != "" and not d.any(func(m): return str(m.id) == pick) and d.any(func(m): return bool(m.get("rerolled", false))) and d.size() == d0.size(), "the day's missions with today's swap (%s)" % pick, d.map(func(m): return str(m.id)))

	# --- a muscle's week -------------------------------------------------------------------------------------------------
	var short = []
	for k in range(3):
		short.append(_lift(8 + k * 2, {"Bent Over Row - Barbell": _sets(6, 8, 60.0), "Bicep Curl - Dumbbell": _sets(4, 10, 12.0)}))
	var cp = Missions.challenge_part(short, {}, settings, monday)
	ok(cp == "chest" or cp == "side_delts" or cp == "triceps" or cp == "rear_delts", "the muscle that fell shortest last week is this week's (%s)" % cp)
	var wkm = Missions.weekly(monday, TODAY, {"sessions": short, "pt": {}, "settings": settings}, {"body": {}, "levels": {"hero": {"level": 3}}, "sessionXp": {}, "prs": {"lifts": {}}}, [])
	ok(wkm.any(func(m): return str(m.id) == "tw:%s:mus:%s" % [monday, cp]), "the week has its mission", wkm.map(func(m): return str(m.id)))

	print("TRACKING: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
