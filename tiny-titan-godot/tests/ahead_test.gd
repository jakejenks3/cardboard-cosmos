extends SceneTree
## Unit test for the look-ahead (Missions.ahead, lift_habit, pretend_lift,
## pretend_other, ahead_word).
##   godot --headless --path . --script res://tests/ahead_test.gd
## Prints AHEAD: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func lift(date: String, exercises: Dictionary) -> Dictionary:
	_n += 1
	var exs = []
	for name in exercises:
		var sets = []
		for st in exercises[name]:
			sets.append({"reps": st[0], "weightKg": float(st[1])})
		exs.append({"name": name, "sets": sets})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "exercises": exs}


func three(reps: int, kg: float) -> Array:
	return [[reps, kg], [reps, kg], [reps, kg]]


func _init() -> void:
	var PUSH = {"Chest Fly - Cable": three(12, 15), "Arnold Press - Dumbbell": three(8, 20), "Lateral Raise - Dumbbell": three(12, 8), "Tricep Pushdown": three(10, 30)}
	var PULL = {"Bent Over Row - Barbell": three(8, 60), "Lat Pulldown": three(10, 50), "Bicep Curl - Dumbbell": three(10, 12)}
	var LEGS = {"Squat - Barbell": three(5, 100), "Romanian Deadlift - Barbell": three(5, 80), "Calf Raise": three(12, 60)}
	# Two weeks of pull, push, legs with one day off (Nov 15), climbs, a run. The last day (Nov 22) was a pull day.
	var log = []
	var kinds = [PULL, PUSH, LEGS]
	var i = 0
	for d in ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21", "2026-11-22"]:
		log.append(lift(d, kinds[i % 3]))
		i += 1
	for d in ["2026-11-14", "2026-11-21"]:
		log.append({"id": "c" + d, "discipline": "climb", "date": d, "createdAt": 1700000000500, "source": "manual", "climbs": [{"grade": 3, "result": "send", "count": 4}]})
	log.append({"id": "r1", "discipline": "run", "date": "2026-11-16", "createdAt": 1700000001000, "source": "manual", "distanceM": 5000.0, "durationSec": 1800, "inboxKey": "k"})
	var today = "2026-11-23"
	var off = {"weightUnit": "kg", "distanceUnit": "km", "split": "pull_push_legs"}
	var on = off.duplicate()
	on["focus"] = "upper"
	var size_before = log.size()

	# --- without a focus: the split goes on, a day at a time --------------------------------
	var days = Missions.ahead(log, today, {}, off)
	ok(days.size() == Missions.AHEAD_DAYS and days[0].date == "2026-11-24" and days[days.size() - 1].date == "2026-11-29", "the six days after today", days.map(func(a): return str(a.date)))
	ok(days.map(func(a): return str(a.plan.kind)) == ["legs", "pull", "push", "legs", "pull", "push"], "the push of today is taken as done: legs tomorrow, then round the split", days.map(func(a): return str(a.plan.kind)))
	ok(days.all(func(a): return bool(a.lift) and not bool(a.rest)), "every day a lift, no rest day without a focus")
	ok(days.map(func(a): return str(Missions.ahead_word(a).text)) == ["Legs", "Pull", "Push", "Legs", "Pull", "Push"] and days.all(func(a): return str(Missions.ahead_word(a).what) == "lift"), "each day in a word")
	ok(days[0].plan.lifts.map(func(l): return str(l.name)).has("Squat - Barbell") and days[1].plan.lifts.map(func(l): return str(l.name)).has("Lat Pulldown"), "with the lifts of that day", [days[0].plan.lifts.map(func(l): return str(l.name)), days[1].plan.lifts.map(func(l): return str(l.name))])
	ok(log.size() == size_before and not log.any(func(s): return str(s.id).begins_with("pretend")), "nothing is added to the log")
	# The run, a week after the last: pretended on Monday (today), so the next is a week on.
	ok(not days.any(func(a): return a.others.any(func(o): return str(o.discipline) == "run")), "the weekly run was today: none in the six days after", days.map(func(a): return a.others.map(func(o): return str(o.discipline))))
	# A lift already logged today is not pretended on top.
	var done_today = log + [lift(today, PUSH)]
	ok(Missions.ahead(done_today, today, {}, off).map(func(a): return str(a.plan.kind)) == ["legs", "pull", "push", "legs", "pull", "push"], "a push really logged today: the same days after it")
	# A leg day done today in place of the push: the split goes on from what was done.
	ok(Missions.ahead(log + [lift(today, LEGS)], today, {}, off).map(func(a): return str(a.plan.kind)).slice(0, 3) == ["pull", "push", "legs"], "legs done today: pull tomorrow")
	ok(Missions.ahead(log, today, {}, off, 3).size() == 3, "as many days as asked for")
	# A run nearly due (six days after the last) is not pretended a day early: it comes on its weekday.
	var sunday = Missions.ahead(log.filter(func(s): return str(s.date) < "2026-11-22"), "2026-11-22", {}, on)
	ok(sunday[0].date == "2026-11-23" and sunday[0].others.any(func(o): return str(o.discipline) == "run") and is_equal_approx(float(sunday[0].plan.run.targetM), 5500.0) and not sunday.slice(1).any(func(a): return a.others.any(func(o): return str(o.discipline) == "run")), "the weekly run: on its weekday, 10% further, and once", sunday.map(func(a): return [a.date, a.others.map(func(o): return str(o.discipline))]))
	# A rest day on the run day: with a focus the run only ever shows on its day.
	ok(not Missions.ahead(log, today, {}, on).any(func(a): return a.others.any(func(o): return str(o.discipline) == "run")), "the run day (today) is a rest day: the run is not moved to another day")

	# --- with a focus: rest days come due, the press is asked for ---------------------------
	var fd = Missions.ahead(log, today, {}, on)
	# Seven hard days in a row before today: today is a rest day, so nothing is pretended on it.
	ok(fd[0].plan.kind == "push" and bool(fd[0].lift) and not bool(fd[0].rest), "today is a rest day: the push day is tomorrow", [fd[0].plan.kind, fd[0].rest])
	ok(fd[0].plan.lifts[0].has("dose") and str(fd[0].plan.lifts[0].dose.part) == "chest", "and it comes with the press for the chest")
	ok(fd.map(func(a): return str(Missions.ahead_word(a).text)) == ["Push", "Legs", "Pull", "Push", "Legs", "Rest"], "five days round the split, then a rest day", fd.map(func(a): return str(Missions.ahead_word(a).text)))
	ok(bool(fd[5].rest) and not bool(fd[5].lift) and int(fd[5].plan.rest.run) == 5 and fd[5].others.is_empty() and Missions.ahead_word(fd[5]).what == "rest", "the rest day: five lifting days in a row by then, nothing else on it", fd[5].plan.rest)
	ok(str(fd[5].rule) == "rest" and str(fd[5].call) == "" and bool(fd[5].can_lift) and str(fd[0].rule) == "lift" and bool(fd[0].can_lift), "each day says what it is by the rules, and whether it could be a lift day", [fd[5].rule, fd[0].rule])

	# --- the player's call: a day off lifting moves the split a day ---------------------------
	var call = func(base: Dictionary, calls: Dictionary) -> Dictionary:
		var out = base.duplicate()
		out["dayCalls"] = calls
		return out
	var words = func(list: Array) -> Array: return list.map(func(a): return str(Missions.ahead_word(a).text))
	# Tomorrow called a rest day: its push day is the day after, and every day after follows.
	var r1 = Missions.ahead(log, today, {}, call.call(on, {"2026-11-24": "rest"}))
	ok(words.call(r1) == ["Rest", "Push", "Legs", "Pull", "Push", "Legs"], "tomorrow called rest: the push and everything after it a day later", words.call(r1))
	ok(bool(r1[0].rest) and str(r1[0].call) == "rest" and str(r1[0].rule) == "lift" and bool(r1[0].can_lift) and str(r1[0].plan.kind) == "push" and r1[0].plan.lifts.is_empty(), "the day called rest: no lifts on it, and it knows the push day waits", [r1[0].call, r1[0].rule, r1[0].plan.kind])
	ok(r1[1].plan.lifts.map(func(l): return str(l.name)) == fd[0].plan.lifts.map(func(l): return str(l.name)), "the day after has exactly the lifts that were planned for it", r1[1].plan.lifts.map(func(l): return str(l.name)))
	# Today (a rest day by the count) called a lift day: the push is today, and tomorrow the rest is due again.
	var r2 = Missions.ahead(log, today, {}, call.call(on, {today: "lift"}))
	ok(words.call(r2) == ["Rest", "Legs", "Pull", "Push", "Legs", "Pull"] and str(r2[0].rule) == "rest", "today called a lift day: the push is done today, the rest day comes tomorrow", words.call(r2))
	# A rest day ahead called a lift day.
	var r3 = Missions.ahead(log, today, {}, call.call(on, {"2026-11-29": "lift"}))
	ok(bool(r3[5].lift) and not bool(r3[5].rest) and str(r3[5].plan.kind) == "pull" and str(r3[5].call) == "lift" and str(r3[5].rule) == "rest", "a rest day called a lift day: the split goes on that day", [r3[5].plan.kind, r3[5].call])
	# Without a focus there is no rest by the count, but a call works the same.
	var r4 = Missions.ahead(log, today, {}, call.call(off, {"2026-11-24": "rest", "2026-11-26": "rest"}))
	ok(words.call(r4) == ["Rest", "Legs", "Rest", "Pull", "Push", "Legs"], "no focus, two days called rest: each one moves what follows a day", words.call(r4))
	# A rest day is a rest from lifting: the run stays on it.
	var before22 = log.filter(func(s): return str(s.date) < "2026-11-22")
	var r5 = Missions.ahead(before22, "2026-11-22", {}, call.call(on, {"2026-11-23": "rest"}))
	ok(bool(r5[0].rest) and r5[0].others.any(func(o): return str(o.discipline) == "run") and not bool(r5[1].rest) and bool(r5[1].lift), "the run day called rest: the run is still on it, the lifts are the day after", [r5[0].rest, r5[0].others.map(func(o): return str(o.discipline)), r5[1].lift])
	ok(log.size() == size_before, "and still nothing is added to the log")
	# Each day says where the week stands once it is done as planned; the press the plan adds is counted.
	ok(days.all(func(a): return a.week.is_empty()) and fd.all(func(a): return a.week.has("chest") and a.week.has("back")), "with a focus every day carries the week's sets per muscle (none without)")
	ok(is_equal_approx(float(fd[0].plan.doseToday[0].have), 3.0) and int(fd[0].plan.lifts[0].dose.sets) == 4 and is_equal_approx(float(fd[0].week.chest), 10.0), "the push day: 3 chest sets in the week, the flyes and a press of 4 make it 10", [fd[0].plan.doseToday[0], fd[0].week.chest])
	var second_push = fd[3]
	var bench = second_push.plan.lifts.filter(func(l): return str(LiftNames.split(str(l.name)).move) == "Bench Press")
	ok(str(second_push.plan.kind) == "push" and bench.size() == 1 and not bench[0].has("dose") and bool(bench[0].options[0].new) and int(bench[0].options[0].planned) == 4 and bench[0].options[0].last.is_empty(), "the next push day: the press is part of the day now, still new (only planned so far: no weight to aim for)", bench)
	ok(float(fd[3].week.chest) >= 10.0 and float(fd[3].week.chest) <= 16.0 and not log.any(func(s): return s.has("invented")), "and the chest is within its target; nothing of this reaches the log", fd[3].week.chest)
	var longer = Missions.ahead(log, today, {}, on, 8)
	ok(str(longer[6].plan.kind) == "pull" and bool(longer[6].lift) and not bool(longer[6].rest), "the day after the rest day the split goes on", [longer[6].date, longer[6].plan.kind, longer[6].rest])

	# --- pretend sessions ------------------------------------------------------------------------
	var plan = Missions.day_plan(log, today, {}, call.call(on, {today: "lift"}))
	var p = Missions.pretend_lift(log, today, plan)
	ok(p != null and p.id == "pretend-2026-11-23" and p.date == today and p.exercises.map(func(e): return str(e.name)).has("Chest Fly - Cable") and not p.exercises.any(func(e): return str(e.name).begins_with("Bench Press")), "a pretend day: the planned lifts done before, not the one never done", p.exercises.map(func(e): return str(e.name)))
	ok(Missions.pretend_lift([], today, Missions.day_plan([], today, {}, off)) == null, "nothing to pretend without a history")
	var run_o = {"discipline": "run", "avg": 5000.0, "why": ""}
	var pr = Missions.pretend_other(log, today, run_o, plan)
	ok(pr != null and pr.id == "pretend-run-2026-11-23" and is_equal_approx(float(pr.distanceM), 5500.0) and not pr.has("inboxKey") and is_equal_approx(float(log.filter(func(s): return str(s.id) == "r1")[0].distanceM), 5000.0), "a pretend run: the distance the plan aims for; the real one is not touched", pr)
	ok(Missions.pretend_other(log, today, {"discipline": "ride", "avg": 0.0, "why": ""}, plan) == null, "no ride to copy: none")

	# --- a weekday the player does not lift on ---------------------------------------------------
	var mwf = []
	for d in ["2026-10-26", "2026-10-28", "2026-10-30", "2026-11-02", "2026-11-04", "2026-11-06", "2026-11-09", "2026-11-11", "2026-11-13", "2026-11-16", "2026-11-18", "2026-11-20"]:
		mwf.append(lift(d, {"Squat - Barbell": three(5, 100), "Bench Press - Barbell": three(5, 80)}))
	ok(Missions.lift_habit(mwf, "2026-11-23") and not Missions.lift_habit(mwf, "2026-11-24") and Missions.lift_habit([], "2026-11-24"), "a lifting habit by weekday; with nothing to go by, any day")
	var md = Missions.ahead(mwf, "2026-11-21", {}, {"weightUnit": "kg"})
	ok(md.map(func(a): return bool(a.lift)) == [false, true, false, true, false, true], "Monday, Wednesday, Friday: a lift on those, none between", md.map(func(a): return [a.date, a.lift]))
	ok(Missions.ahead_word(md[0]).text == "Off" and Missions.ahead_word(md[0]).what == "" and str(Missions.ahead_word(md[1]).what) == "lift", "a day with nothing likely is Off", [Missions.ahead_word(md[0]), Missions.ahead_word(md[1])])
	ok(str(md[0].rule) == "rest" and bool(md[0].can_lift) and str(md[1].rule) == "lift", "a weekday without lifting is no lift day by the rules, but it could be one")
	var md2 = Missions.ahead(mwf, "2026-11-21", {}, {"weightUnit": "kg", "dayCalls": {"2026-11-22": "lift"}})
	ok(md2.map(func(a): return bool(a.lift)) == [true, true, false, true, false, true] and str(md2[0].call) == "lift", "such a day called a lift day is one", md2.map(func(a): return [a.date, a.lift]))
	# A day called rest hands its lifts to the day after, whatever that weekday's habit.
	var md3 = Missions.ahead(mwf, "2026-11-21", {}, {"weightUnit": "kg", "dayCalls": {"2026-11-23": "rest"}})
	ok(md3.map(func(a): return bool(a.lift)) == [false, false, true, true, false, true] and bool(md3[1].rest) and str(md3[2].rule) == "lift" and str(md3[2].call) == "", "Monday called rest: its lifts are Tuesday's, a day this player never lifts on", md3.map(func(a): return [a.date, a.lift, a.rest]))
	var md4 = Missions.ahead(mwf, "2026-11-21", {}, {"weightUnit": "kg", "dayCalls": {"2026-11-23": "rest", "2026-11-24": "rest"}})
	ok(md4.map(func(a): return bool(a.rest)) == [false, true, true, false, false, false] and bool(md4[3].lift), "and Tuesday called rest too: they are Wednesday's", md4.map(func(a): return [a.date, a.lift, a.rest]))
	# Rides and vest walks are done now and then: never planned, never looked ahead to.
	var riders = mwf.duplicate()
	for d in ["2026-10-27", "2026-11-03", "2026-11-10", "2026-11-17"]:
		riders.append({"id": "ride" + d, "discipline": "ride", "date": d, "createdAt": 1700000002000, "source": "manual", "distanceM": 20000.0, "durationSec": 3600})
		riders.append({"id": "walk" + d, "discipline": "misc", "kind": "vest_walk", "date": d, "createdAt": 1700000003000, "source": "manual", "distanceM": 3000.0, "loadKg": 10.0})
	var rp = Missions.day_plan(riders, "2026-11-24", {}, {"weightUnit": "kg"})
	ok(rp.others.is_empty() and not Missions.ahead(riders, "2026-11-21", {}, {"weightUnit": "kg"}).any(func(a): return not a.others.is_empty()), "four Tuesdays of rides and vest walks: none is planned or looked ahead to", rp.others)
	ok(Missions.ahead([], today, {}, off).all(func(a): return not bool(a.lift) and not bool(a.rest) and a.others.is_empty()), "a new player: nothing to look ahead to")

	print("AHEAD: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
