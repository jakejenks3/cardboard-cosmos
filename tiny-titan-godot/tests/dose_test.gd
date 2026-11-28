extends SceneTree
## Unit test for game/dose.gd (the training focus) and what the plan and the
## missions make of it (game/missions.gd).
##   godot --headless --path . --script res://tests/dose_test.gd
## Prints DOSE: X/Y passed and exits with 1 when anything fails.

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
			var one = {"reps": st[0], "weightKg": float(st[1])}
			if st.size() > 2:
				one["holdSec"] = st[2]
			sets.append(one)
		exs.append({"name": name, "sets": sets})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "exercises": exs}


func climb(date: String) -> Dictionary:
	_n += 1
	return {"id": "c%d" % _n, "discipline": "climb", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "climbs": [{"grade": 3, "result": "send", "count": 4}]}


func find(list: Array, tail: String):
	for m in list:
		if str(m.id).ends_with(tail):
			return m
	return null


func three(reps: int, kg: float) -> Array:
	return [[reps, kg], [reps, kg], [reps, kg]]


func _init() -> void:
	var PUSH = {"Chest Fly - Cable": three(12, 15), "Arnold Press - Dumbbell": three(8, 20), "Lateral Raise - Dumbbell": three(12, 8), "Tricep Pushdown": three(10, 30)}
	var PULL = {"Bent Over Row - Barbell": three(8, 60), "Lat Pulldown": three(10, 50), "Bicep Curl - Dumbbell": three(10, 12)}
	var LEGS = {"Squat - Barbell": three(5, 100), "Romanian Deadlift - Barbell": three(5, 80), "Calf Raise": three(12, 60)}
	# Two weeks of pull, push, legs, one rest day (Nov 15), three climbs, a run.
	var log = []
	var kinds = [PULL, PUSH, LEGS]
	var i = 0
	for d in ["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-21", "2026-11-22"]:
		log.append(lift(d, kinds[i % 3]))
		i += 1
	for d in ["2026-11-14", "2026-11-18", "2026-11-21"]:
		log.append(climb(d))
	log.append({"id": "r1", "discipline": "run", "date": "2026-11-16", "createdAt": 1700000001000, "source": "manual", "distanceM": 5000.0, "durationSec": 1800})
	var today = "2026-11-23"
	var marks = {}
	var off = {"weightUnit": "kg", "distanceUnit": "km", "split": "pull_push_legs", "weeklyGoal": 3}
	var st = off.duplicate()
	st["focus"] = "upper"
	# Seven lifting days in a row before today, and today is still a lift day:
	# no rest day is ever planned by a rule. `rs` is the same day called a rest
	# day by the player (tested under "rest").
	var rs = st.duplicate()
	rs["dayCalls"] = {today: "rest"}
	var state = {"levels": {"hero": {"level": 10}}, "sessionXp": {}, "body": {"entries": 0}}

	# --- the focus and the window --------------------------------------------------------
	ok(Dose.plan_id(off) == "" and Dose.plan_of(off) == null and Dose.plan_id({"focus": "nonsense"}) == "" and Dose.plan_id(st) == "upper", "no focus unless a known one is picked")
	ok(Dose.mode_of(st, "Chest Fly - Cable") == "build" and Dose.mode_of(st, "Squat - Barbell") == "keep" and Dose.mode_of(off, "Squat - Barbell") == "" and Dose.mode_of({"focus": "balanced"}, "Squat - Barbell") == "build", "upper body first builds the chest and keeps the legs; whole body builds both")
	var w = Dose.window(log, marks, st, "2026-11-22")
	# Nov 16 to 22: pull 16, 19, 22; push 17, 20; legs 18, 21; climbs 18, 21.
	ok(is_equal_approx(float(w.parts.chest.direct), 6.0) and is_equal_approx(float(w.parts.chest.total), 6.0) and w.parts.chest.state == "short", "chest: two days of flyes, 6 sets, short of 10", w.parts.chest)
	ok(is_equal_approx(float(w.parts.back.direct), 18.0) and is_equal_approx(float(w.parts.back.indirect), 3.0) and is_equal_approx(float(w.parts.back.climb), 0.0) and is_equal_approx(float(w.parts.back.total), 21.0), "back: 18 lifted and half of the deadlifts' sets; two climbs add nothing to it", w.parts.back)
	ok(is_equal_approx(float(w.parts.biceps.direct), 9.0) and is_equal_approx(float(w.parts.biceps.indirect), 9.0) and is_equal_approx(float(w.parts.biceps.climb), 0.0), "biceps: curls and half of every row and pulldown; nothing from climbing", w.parts.biceps)
	ok(is_equal_approx(float(w.parts.triceps.direct), 6.0) and is_equal_approx(float(w.parts.triceps.indirect), 3.0) and w.parts.triceps.state == "ok", "triceps: pushdowns and half of the presses", w.parts.triceps)
	ok(is_equal_approx(float(w.parts.forearms.climb), 8.0) and w.parts.forearms.mode == "keep" and w.parts.quads.mode == "keep" and w.parts.quads.state == "ok", "forearms come from climbing; the legs are kept and at their sets", [w.parts.forearms, w.parts.quads])
	var wm = Dose.window([lift("2026-11-22", {"Neck 4 Way": three(20, 4), "Pec Stretch": [[1, 0, 30]], "Chest Fly - Cable": []})], {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}, st, "2026-11-22")
	ok(Dose.PARTS.all(func(p): return is_equal_approx(float(wm.parts[p].total), 0.0)), "physical therapy, stretches and empty exercises count for nothing", wm.parts)
	ok(Dose.window(log, marks, off, "2026-11-22").parts.chest.state == "" and is_equal_approx(float(Dose.window(log, marks, off, "2026-11-22").parts.chest.total), 6.0), "without a focus the sets are counted, with no target")
	ok(Dose.parts_today("push", "") == ["chest", "front_delts", "side_delts", "triceps"] and Dose.parts_today("pull", "") == ["back", "rear_delts", "traps", "biceps"] and Dose.parts_today("upper", "").has("back") and Dose.parts_today("upper", "").has("chest") and Dose.parts_today("", "legs") == ["quads", "hamstrings", "glutes", "calves"] and Dose.parts_today("", "").is_empty(), "the muscles of a day", [Dose.parts_today("push", ""), Dose.parts_today("", "legs")])

	# --- the plan: a press for the chest, first ------------------------------------------------
	var plain = Missions.day_plan(log, today, marks, off)
	var plan = Missions.day_plan(log, today, marks, st)
	ok(plain.kind == "push" and plain.focus == "" and not plain.lifts.any(func(l): return l.has("dose") or l.has("mode")) and plain.run == null and not plain.rest.due, "no focus: the plan is as it was", plain.lifts.map(func(l): return str(l.name)))
	ok(plan.focus == "upper" and plan.lifts.size() == plain.lifts.size() + 1 and plan.lifts[0].has("dose") and plan.lifts.slice(1).map(func(l): return str(l.name)) == plain.lifts.map(func(l): return str(l.name)), "with a focus: one extra lift, put first, the usual ones after it", plan.lifts.map(func(l): return str(l.name)))
	var x = plan.lifts[0]
	ok(x.dose.part == "chest" and bool(x.dose.anchor) and int(x.dose.sets) == 3 and is_equal_approx(float(x.dose.have), 6.0) and is_equal_approx(float(x.dose.cover), 3.0) and str(x.why) == "6 of 10 sets in 7 days, no press" and is_equal_approx(float(x.dose.share), 5.0) and is_equal_approx(float(x.dose.need), 2.0), "the chest is short and has no press: 3 sets of one", [x.dose, x.why])
	ok(x.options.map(func(o): return str(o.name)) == ["Bench Press - Barbell", "Bench Press - Incline dumbbell", "Bench Press - Machine", "Push-up - Weighted", "Dip"] and x.options.all(func(o): return bool(o.new)) and x.name == "Bench Press - Barbell", "a press for every sort of equipment, the barbell first", x.options.map(func(o): return str(o.name)))
	# The Log tab's "From today's plan" (Missions.picks): what the focus adds comes first.
	var pk = Missions.picks(plan, log, today)
	ok(str(pk[0].kind) == "extra" and str(pk[0].part) == "chest" and str(pk[0].name) == "Bench Press - Barbell" and bool(pk[0].new) and pk[0].last.is_empty() and pk[0].lift == x and str(pk[0].done) == "" and pk[0].ways.map(func(w): return str(w.name)) == ["Bench Press - Incline dumbbell", "Bench Press - Machine", "Push-up - Weighted", "Dip"] and pk[0].ways.map(func(w): return str(w.word)) == ["Incline dumbbell", "Machine", "Push-up (weighted)", "Dip"], "the list to pick a workout from: the press for the chest first, its other ways as chips", pk[0])
	ok(pk.slice(1, plan.lifts.size()).all(func(r): return str(r.kind) != "extra") and pk.slice(1, plan.lifts.size()).map(func(r): return str(r.name)) == plan.lifts.slice(1).map(func(l): return str(l.options[0].name) if not l.get("options", []).is_empty() else str(l.name)), "then the usual lifts, each as it was done last", pk.map(func(r): return str(r.name)))
	ok(plan.new != null and not ["Bench Press", "Push-up", "Dip"].has(str(plan.new.move)) and not plan.new.alts.any(func(a): return ["Bench Press", "Push-up", "Dip"].has(str(a.move))), "\"try something new\" offers other movements than the press", [plan.new.name, plan.new.alts.map(func(a): return str(a.name))])
	ok(plan.lifts.slice(1).all(func(l): return str(l.mode) == ("keep" if Dose.main_part(str(l.name)) == "front_delts" else "build")) and ["Bench Press", "Push-up", "Dip"].all(func(m): return plan.moves.has(Xp.normalize_exercise(m))), "the day's lifts are for building (a press for the front delts is kept); the press's movements belong to the plan", plan.lifts.map(func(l): return [str(l.name), str(l.mode)]))
	var fly = plan.lifts.filter(func(l): return str(l.name) == "Chest Fly - Cable")[0]
	ok(not fly.options.any(func(o): return str(o.move) == "Bench Press"), "the fly does not offer the press as another way")

	# --- done only by a press, and only once its sets are in ------------------------------------
	var two = log + [lift(today, {"Bench Press - Incline dumbbell": [[10, 20], [9, 20]], "Chest Fly - Cable": three(12, 15)})]
	var done3 = log + [lift(today, {"Bench Press - Incline dumbbell": three(10, 20)})]
	var pull_over = log + [lift(today, {"Pullover - Dumbbell": three(12, 15)})]
	var pushup = log + [lift(today, {"Push-up": three(15, 0)})]
	ok(Missions.lift_done(x, plan, two, today) == "" and int(Dose.extra_done(x, two, today).sets) == 2, "two sets of three: not yet")
	ok(Missions.lift_done(x, plan, done3, today) == "Bench Press - Incline dumbbell" and Missions.lift_done(x, plan, pushup, today) == "Push-up", "three sets of any press: done, by its name")
	ok(Missions.lift_done(x, plan, pull_over, today) == "", "a pullover is not a press")
	ok(Missions.lift_done(fly, plan, done3, today) == "" and Missions.lift_done(fly, plan, two, today) == "Chest Fly - Cable", "the press does not tick the fly's row; the fly does")
	var boxes = Missions.day_boxes(plan, done3, today)
	ok(boxes[0].done and not boxes[1].done, "the Today card's first box is the press", boxes)

	# --- the day's missions ------------------------------------------------------------------------
	var data = {"sessions": log, "pt": marks, "settings": st, "reading": [], "now": today}
	var data_off = {"sessions": log, "pt": marks, "settings": off, "reading": [], "now": today}
	var day = Missions.daily(today, data, state, [])
	var day_off = Missions.daily(today, data_off, state, [])
	var dm = find(day, ":dose:chest")
	ok(find(day_off, ":dose:chest") == null and find(day_off, ":rest") == null and find(day_off, ":show") != null, "no focus: no such missions", day_off.map(func(m): return str(m.id)))
	ok(dm != null and dm.title == "Chest: add a press" and int(dm.target) == 3 and int(dm.progress) == 0 and int(dm.xp) == 250 and dm.lift == "Bench Press - Barbell", "a mission for the press", dm)
	ok(str(dm.desc) == "Chest: 6 of 10 weekly sets, no press in two weeks. A press loads the chest far heavier than flyes can. Do 3 sets of Bench Press (barbell): 6 to 12 reps, the last ones hard. Or: incline dumbbell, machine, Push-up (weighted), Dip.", "it says why, how much and what else counts", dm.desc)
	ok(day.filter(func(m): return str(m.id).contains(":beat:")).size() == 2 and not day.any(func(m): return str(m.id).contains(":beat:bench press")) and day.filter(func(m): return str(m.id).contains(":beat:")).all(func(m): return str(m.title).ends_with(" challenge")), "the two challenges are still the usual lifts", day.map(func(m): return str(m.title)))
	data.sessions = two
	ok(int(find(Missions.daily(today, data, state, []), ":dose:chest").progress) == 2 and not find(Missions.daily(today, data, state, []), ":dose:chest").done, "two sets: two of three")
	data.sessions = done3
	var after = Missions.daily(today, data, state, [])
	ok(find(after, ":dose:chest").done and after.map(func(m): return str(m.id)) == day.map(func(m): return str(m.id)), "three sets: done, and logging does not change the day's missions")
	data.sessions = log

	# --- rest ------------------------------------------------------------------------------------------
	var rest = Dose.rest(log, marks, today)
	ok(int(rest.run) == 7 and not bool(rest.today) and not rest.has("due"), "seven lifting days in a row are counted, and nothing is due because of them", rest)
	ok(not bool(plan.off) and not bool(plan.rest.due) and str(plan.call) == "" and plan.lifts.any(func(l): return not bool(l.pt)), "no call: a lift day, however many lifting days came before it", plan.rest)
	# The same day called a rest day by the player: a rest from lifting.
	var rplan = Missions.day_plan(log, today, marks, rs)
	ok(bool(rplan.off) and bool(rplan.rest.due) and str(rplan.rest.call) == "rest" and str(rplan.call) == "rest", "called rest: a rest day", rplan.rest)
	ok(rplan.lifts.is_empty() and rplan.new == null and rplan.doseToday.is_empty() and int(rplan.set_aside) == 4 and str(rplan.kind) == "push" and str(rplan.label) == "Push day", "a rest day plans no strength lift, no extra, nothing new; it still knows which day waits", [rplan.lifts.map(func(l): return str(l.name)), rplan.set_aside, rplan.kind])
	ok(rplan.others.any(func(o): return str(o.discipline) == "run") and bool(rplan.runToday), "the run stays on a rest day: it is a rest from lifting")
	ok(Missions.kind_why(rplan) == "Your call: push day moves to tomorrow" and Missions.off_moves(rplan) == "Push day moves to tomorrow" and Missions.off_moves({"label": ""}) == "The lifts move to tomorrow", "and says what moves", Missions.kind_why(rplan))
	# On any other day too, and the day after picks the lifts up.
	var c20 = st.duplicate()
	c20["dayCalls"] = {"2026-11-20": "rest"}
	var p20 = Missions.day_plan(log.filter(func(s): return str(s.date) < "2026-11-20"), "2026-11-20", marks, c20)
	var p20_free = Missions.day_plan(log.filter(func(s): return str(s.date) < "2026-11-20"), "2026-11-20", marks, st)
	ok(bool(p20.off) and str(p20.rest.call) == "rest" and p20.lifts.is_empty() and not bool(p20_free.off) and str(p20.kind) == str(p20_free.kind) and Missions.kind_why(p20).begins_with("Your call: "), "a day called rest: no lifts, whatever the count says", [p20.rest, p20.kind])
	var p21 = Missions.day_plan(log.filter(func(s): return str(s.date) < "2026-11-20"), "2026-11-21", marks, c20)
	ok(str(p21.kind) == str(p20_free.kind) and not bool(p21.off) and p21.lifts.filter(func(l): return not l.has("dose")).map(func(l): return str(l.name)) == p20_free.lifts.filter(func(l): return not l.has("dose")).map(func(l): return str(l.name)), "the day after has the lifts the rest day set aside: the split moved a day", [p21.kind, p21.lifts.map(func(l): return str(l.name))])
	var lifted20 = log.filter(func(s): return str(s.date) < "2026-11-20") + [lift("2026-11-20", {"Chest Fly - Cable": three(12, 15)})]
	ok(not bool(Missions.day_plan(lifted20, "2026-11-20", marks, c20).off), "lifting on a day called rest makes it a lift day again")
	var ran20 = log.filter(func(s): return str(s.date) < "2026-11-20") + [{"id": "r20", "discipline": "run", "date": "2026-11-20", "createdAt": 1700000009000, "source": "manual", "distanceM": 5000.0, "durationSec": 1800}, climb("2026-11-20")]
	ok(bool(Missions.day_plan(ran20, "2026-11-20", marks, c20).off) and not Dose.hard_on(ran20, marks, "2026-11-20") and int(Dose.rest(ran20, marks, "2026-11-21").run) == 0, "a run and a climb on it do not: they are no lifting, and the count of days in a row starts again", Dose.rest(ran20, marks, "2026-11-21"))
	# The calls themselves.
	ok(Missions.call_of(c20, "2026-11-20") == "rest" and Missions.call_of(c20, "2026-11-21") == "" and Missions.call_of({}, today) == "" and Missions.call_of({"dayCalls": {today: "nonsense"}}, today) == "" and Missions.call_of({"dayCalls": {today: "lift"}}, today) == "", "a call is rest or nothing (a \"lift\" left by the first version counts for nothing)")
	var wc = Missions.with_call({"dayCalls": {"2026-10-01": "rest", "2026-11-22": "lift", "2026-11-21": "rest"}}, today, true, today)
	ok(wc == {"2026-11-21": "rest", today: "rest"}, "a rest call is added; one older than a month, and anything that is not a rest call, is dropped", wc)
	ok(Missions.with_call({"dayCalls": wc}, today, false, today) == {"2026-11-21": "rest"} and Missions.with_call({}, today, false, today).is_empty(), "taking a call back leaves the others as they are")
	var until = func(d: String): return log.filter(func(s): return str(s.date) < d)
	ok(int(Dose.rest(until.call("2026-11-20"), marks, "2026-11-20").run) == 4 and int(Dose.rest(until.call("2026-11-21"), marks, "2026-11-21").run) == 5, "the count of lifting days in a row, day by day")
	ok(int(Dose.rest(done3, marks, today).run) == 8 and bool(Dose.rest(done3, marks, today).today), "lifting today adds to it")
	ok(find(day, ":rest") == null and find(day, ":show") != null, "a lift day: showing up is the first mission, not resting")
	var rdata = {"sessions": log, "pt": marks, "settings": rs, "reading": [], "now": today}
	var rday = Missions.daily(today, rdata, state, [])
	var rm = find(rday, ":rest")
	ok(rm != null and find(rday, ":show") == null and rday[0].id == rm.id and not rm.done and str(rm.desc).begins_with("Your call. No lifting today") and str(rm.desc).contains("Push day waits for tomorrow"), "a rest day: the first mission is to rest, in place of showing up", rday.map(func(m): return str(m.id)))
	ok(not rday.any(func(m): return str(m.id).contains(":beat:") or str(m.id).contains(":dose:") or str(m.id).ends_with(":new")) and find(rday, ":run") != null, "and no lift is asked for; the run still is", rday.map(func(m): return str(m.id)))
	var easy_day = log + [lift(today, {"Neck 4 Way": three(20, 4), "Pec Stretch": [[1, 0, 30]]}), {"id": "w1", "discipline": "misc", "kind": "vest_walk", "date": today, "distanceM": 3000.0, "loadKg": 10.0}]
	var pt_marks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}
	ok(not Dose.hard_on(easy_day, pt_marks, today) and Dose.hard_on(done3, marks, today) and Dose.hard_on(log, marks, "2026-11-21") and not Dose.hard_on([climb("2026-12-01")], marks, "2026-12-01"), "a walk, PT, stretches, a climb are no lifting; a lift is")
	var next_day = {"sessions": easy_day, "pt": pt_marks, "settings": rs, "reading": [], "now": "2026-11-24"}
	ok(find(Missions.daily(today, next_day, state, []), ":rest").done, "the day after: rested (a walk and PT only), the mission is done")
	next_day.sessions = done3
	ok(find(Missions.daily(today, next_day, state, []), ":rest") == null and find(Missions.daily(today, next_day, state, []), ":show") != null, "lifted anyway: it was a lift day after all, with no rest mission")
	next_day.sessions = easy_day
	next_day.now = today
	ok(not find(Missions.daily(today, next_day, state, []), ":rest").done, "not before the day is over")

	# --- a leg day: no sets are added, its lifts are beaten like any other ---------------------------
	var leg_log = done3 + [lift("2026-11-23", {"Chest Fly - Cable": three(12, 15)})]
	var leg_day = "2026-11-25"
	# Nov 24 off, so no rest mission in the way.
	var lp = Missions.day_plan(leg_log, leg_day, marks, st)
	ok(lp.kind == "legs" and not lp.lifts.any(func(l): return l.has("dose")) and lp.lifts.all(func(l): return str(l.mode) == "keep") and not bool(lp.rest.due), "a leg day: nothing is added, every lift is of a kept muscle", [lp.kind, lp.lifts.map(func(l): return [l.name, l.get("mode")])])
	var ld = Missions.daily(leg_day, {"sessions": leg_log, "pt": marks, "settings": st, "reading": [], "now": leg_day}, state, [])
	var ld_off = Missions.daily(leg_day, {"sessions": leg_log, "pt": marks, "settings": off, "reading": [], "now": leg_day}, state, [])
	var beats = ld.filter(func(m): return str(m.id).contains(":beat:"))
	ok(beats.size() == 2 and beats.all(func(m): return str(m.title).ends_with(" challenge") and str(m.desc).begins_with("Pick one: ") and not (m.options as Array).is_empty()), "its lifts still have records to go for", beats.map(func(m): return [m.title, m.desc]))
	ok(beats.map(func(m): return [m.id, m.title, m.desc, m.aim]) == ld_off.filter(func(m): return str(m.id).contains(":beat:")).map(func(m): return [m.id, m.title, m.desc, m.aim]), "the same missions as without a focus")
	var b0 = beats[0]
	var lighter = leg_log + [lift(leg_day, {str(b0.lift): [[5, 60]]})]
	var heavier = leg_log + [lift(leg_day, {str(b0.lift): [[int(b0.options[0].reps), float(b0.options[0].kg)]]})]
	var tail = str(b0.id).substr(str(b0.id).find(":beat:"))
	ok(not find(Missions.daily(leg_day, {"sessions": lighter, "pt": marks, "settings": st, "reading": [], "now": leg_day}, state, []), tail).done and find(Missions.daily(leg_day, {"sessions": heavier, "pt": marks, "settings": st, "reading": [], "now": leg_day}, state, []), tail).done, "a lighter day does not do it; its first record (heavier than ever) does")
	# Legs that got nothing for a week: still nothing is added (their volume is the player's own business).
	var no_legs = log.filter(func(s): return not (str(s.discipline) == "lift" and s.exercises.any(func(e): return str(e.name) == "Calf Raise") and str(s.date) >= "2026-11-17")) + [lift("2026-11-23", PULL), lift("2026-11-24", PUSH)]
	var sp = Missions.day_plan(no_legs, leg_day, marks, st)
	ok(sp.kind == "legs" and not sp.lifts.any(func(l): return l.has("dose")) and Dose.window(no_legs, marks, st, "2026-11-24").parts.quads.state == "short", "legs short for a week: shown as short, and still nothing is added", [sp.kind, sp.lifts.map(func(l): return str(l.name))])
	ok(Missions.day_plan(no_legs, leg_day, marks, {"focus": "balanced", "split": "pull_push_legs"}).lifts.any(func(l): return l.has("dose") and ["quads", "hamstrings", "glutes", "calves"].has(str(l.dose.part))), "with the whole body focus the legs are built: a lift is added for them")

	# --- more for a muscle that has its anchor ---------------------------------------------------------
	var tri_log = []
	i = 0
	for d in ["2026-11-10", "2026-11-13", "2026-11-17", "2026-11-20"]:
		tri_log.append(lift(d, {"Bench Press - Barbell": [[6, 80], [6, 80], [6, 80], [6, 80]], "Lateral Raise - Dumbbell": three(12, 8)}))
	# Triceps lifts done long ago: known, but no longer part of a push day.
	tri_log.append(lift("2026-09-01", {"Tricep Pushdown": three(10, 30), "Tricep Kickback - Dumbbell": three(12, 8)}))
	tri_log.append(lift("2026-11-22", PULL))
	var tp = Missions.day_plan(tri_log, today, marks, st)
	var tx = tp.lifts.filter(func(l): return l.has("dose"))
	ok(tx.any(func(l): return str(l.dose.part) == "triceps" and not bool(l.dose.anchor) and l.options.size() >= 1 and Dosage.part(str(l.name)) == "triceps") and not tx.any(func(l): return bool(l.dose.anchor)), "triceps short (only the bench's half sets): a triceps movement is added; the chest has its press, so no press is asked for again", tx.map(func(l): return [l.dose, l.options.map(func(o): return str(o.name))]))
	var cx = tx.filter(func(l): return str(l.dose.part) == "chest")
	ok(cx.size() == 1 and is_equal_approx(float(cx[0].dose.share), 5.0) and is_equal_approx(float(cx[0].dose.cover), 4.0) and not ["Bench Press"].has(str(LiftNames.split(str(cx[0].name)).move)) and str(cx[0].why) == "8 of 10 sets in 7 days", "the bench alone (4 sets, twice a week) leaves the chest under its share of 5 a day: another chest movement is added", cx.map(func(l): return [l.name, l.dose, l.why]))

	# --- the day's share of the week, and what a plan gives each muscle ----------------------------
	ok(is_equal_approx(Dose.day_target([10, 16, "build"], 7.5, 2.0), 5.0), "a muscle trained twice a week: half its weekly least a day")
	ok(is_equal_approx(Dose.day_target([10, 16, "build"], 2.0, 2.0), 8.0) and is_equal_approx(Dose.day_target([10, 16, "build"], 4.0, 2.0), 6.0), "a week that is behind asks for what it lacks, up to the most a day may give")
	ok(is_equal_approx(Dose.day_target([10, 16, "build"], 14.0, 2.0), 2.0) and is_equal_approx(Dose.day_target([10, 16, "build"], 17.0, 2.0), 0.0), "never more than keeps the week within its most")
	ok(is_equal_approx(Dose.day_target([8, 16, "build"], 6.0, 3.0), 3.0) and is_equal_approx(Dose.day_target([8, 16, "build"], 0.0, 1.0), 8.0), "three days a week: a third; once a week: all of it")
	ok(is_equal_approx(Dose.freq_of(log, today, "chest", marks), 2.0) and is_equal_approx(Dose.freq_of(log, today, "calves", marks), 2.0) and is_equal_approx(Dose.freq_of([], today, "chest", marks), 1.0), "how often a muscle is trained: four chest days in two weeks is twice a week")
	var dd = plan.doseToday
	ok(dd.map(func(d): return str(d.part)) == ["chest", "front_delts", "side_delts", "triceps"] and plain.doseToday.is_empty(), "the plan says what it gives each muscle of the day (nothing without a focus)", dd.map(func(d): return str(d.part)))
	var dchest = dd[0]
	ok(is_equal_approx(float(dchest.have), 6.0) and is_equal_approx(float(dchest.today), 6.0) and is_equal_approx(float(dchest.after), 12.0) and dchest.state == "ok" and is_equal_approx(float(dchest.share), 5.0), "chest: 6 in the week, the flyes and the added press give 6 more: 12, on target", dchest)
	var plain_dose = Dose.day_dose(plain.lifts, log.filter(func(s): return str(s.date) < today), today, marks, st, "push", "push")
	ok(is_equal_approx(float(plain_dose[0].today), 3.0) and plain_dose[0].state == "short", "without the press the day would leave the chest short (9 of 10)", plain_dose[0])
	ok(Dose.planned_sets(x, marks) == 3 and Dose.planned_sets(fly, marks) == 3 and Dose.planned_sets({"name": "Neck 4 Way", "pt": true, "last": {"sets": [{"reps": 20, "weightKg": 4.0}]}}, marks) == 0, "a lift counts for the sets it was done for; an added one for what it asks; PT for nothing")
	var tm = find(Missions.daily(today, {"sessions": tri_log, "pt": marks, "settings": st, "reading": [], "now": today}, state, []), ":dose:triceps")
	ok(tm != null and tm.title == "More for your triceps", "its mission", tm)

	# --- the weekly run -----------------------------------------------------------------------------------
	var g = Dose.run_goal(log, today, "km")
	ok(g != null and is_equal_approx(float(g.targetM), 5500.0) and g.step == "up" and int(g.gap) == 7 and Dose.run_why(g, "km") == "10% further than Nov 16 (5 km)", "a week after 5 km: 5.5 km", g)
	ok(is_equal_approx(float(Dose.run_goal(log, "2026-12-01", "km").targetM), 5000.0) and Dose.run_goal(log, "2026-12-01", "km").step == "same" and is_equal_approx(float(Dose.run_goal(log, "2026-12-20", "km").targetM), 4000.0) and Dose.run_goal(log, "2026-12-20", "km").step == "back", "two weeks after: the same again; five weeks after: shorter")
	ok(absf(float(Dose.run_goal(log, today, "mi").targetM) - 3.4 * 1609.344) < 0.01 and Dose.run_goal(log, "2026-11-16", "km") == null, "in miles: a tenth of a mile; nothing to go by before the first run", Dose.run_goal(log, today, "mi"))
	ok(plan.run != null and is_equal_approx(float(plan.run.targetM), 5500.0) and plain.run == null and Missions.day_plan(log, today, marks, {"focus": "upper", "runGoal": false, "split": "pull_push_legs"}).run == null, "the plan carries it, unless switched off")
	var run_m = find(day, ":run")
	ok(run_m != null and run_m.title == "Run a little further" and is_equal_approx(float(run_m.target), 5500.0) and str(run_m.desc).begins_with("Go 5.5 km. 10% further than Nov 16 (5 km)."), "the day's run mission aims a little further", run_m)
	ok(find(day_off, ":run") != null and find(day_off, ":run").title == "Get the miles in", "without a focus it is the usual distance")
	var wk = Dates.week_key(today)
	var week = Missions.weekly(wk, today, data, state, [])
	ok(find(week, ":longrun") == null and not week.any(func(m): return str(m.title).to_lower().contains("run")), "no run mission for the week: the run's goals are on its day only", week.map(func(m): return str(m.title)))
	# The second goal of the run's day: a quicker pace than last time (5 km in 30:00 = 6:00 a km) over 3.8 km or more.
	var pace_m = find(day, ":pace")
	ok(is_equal_approx(float(g.paceSec), 360.0) and is_equal_approx(float(g.paceM), 3800.0), "the last run's pace, and the least distance it has to be beaten over", g)
	ok(pace_m != null and pace_m.title == "Run a little faster" and str(pace_m.desc).begins_with("At least 3.8 km at a quicker pace than last time (6:00 /km).") and not pace_m.done and find(day_off, ":pace") == null, "a pace goal beside the distance goal", pace_m)
	var with_run = func(m: float, secs: int) -> Array:
		var s = {"id": "r2", "discipline": "run", "date": today, "createdAt": 1700000002000, "source": "manual", "distanceM": m}
		if secs > 0:
			s["durationSec"] = secs
		return Missions.daily(today, {"sessions": log + [s], "pt": marks, "settings": st, "reading": [], "now": today}, state, [])
	var far_slow = with_run.call(5600.0, 2100)
	ok(find(far_slow, ":run").done and not find(far_slow, ":pace").done, "further but slower: the distance goal only")
	var near_fast = with_run.call(4000.0, 1400)
	ok(not find(near_fast, ":run").done and find(near_fast, ":pace").done, "shorter but quicker: the pace goal only")
	var both = with_run.call(5600.0, 1960)
	ok(find(both, ":run").done and find(both, ":pace").done, "further and quicker: both")
	ok(not find(with_run.call(3000.0, 900), ":pace").done and not find(with_run.call(6000.0, 0), ":pace").done and find(with_run.call(6000.0, 0), ":run").done, "too short, or not timed: no pace goal; a run with no time still counts its distance")
	ok(far_slow.map(func(m): return str(m.id)) == day.map(func(m): return str(m.id)), "logging the run does not change the missions of the day")

	# --- the run's day ---------------------------------------------------------------------------------------
	ok(Dose.run_day(log, {}, today) == 0 and Dose.run_day(log, {"runDay": 3}, today) == 3 and Dose.run_day(log, {"runDay": 3.0}, today) == 3 and Dose.run_day(log, {"runDay": -1}, today) == 0 and Dose.run_day([], {}, today) == -1, "the run day: the one picked, else the weekday of the runs (a Monday here), else none")
	var two_days = log + [{"id": "r3", "discipline": "run", "date": "2026-11-19", "distanceM": 3000.0}, {"id": "r4", "discipline": "run", "date": "2026-11-12", "distanceM": 3000.0}]
	ok(Dose.run_day(two_days, {}, today) == 3, "most runs on a Thursday: Thursday")
	var tue = "2026-11-24"
	var no_run_tue = Missions.day_plan(log, tue, marks, st)
	var tue_day = Missions.daily(tue, {"sessions": log, "pt": marks, "settings": st, "reading": [], "now": tue}, state, [])
	ok(no_run_tue.run == null and not bool(no_run_tue.runToday) and not no_run_tue.others.any(func(o): return str(o.discipline) == "run") and find(tue_day, ":run") == null and find(tue_day, ":pace") == null, "on any other day there is no run on the card and no run mission, however long ago the last one was", [no_run_tue.others, tue_day.map(func(m): return str(m.id))])
	ok(Missions.day_plan(log, tue, marks, off).others.any(func(o): return str(o.discipline) == "run"), "(without a focus a run that is due still shows, as before)")
	var st_tue = st.duplicate()
	st_tue["runDay"] = 1
	var run_tue = Missions.day_plan(log, tue, marks, st_tue)
	ok(bool(run_tue.runToday) and str(run_tue.others[0].discipline) == "run" and str(run_tue.others[0].why) == "Your run day" and run_tue.run != null and not bool(Missions.day_plan(log, today, marks, st_tue).runToday), "Tuesday picked as the run day: the run is on Tuesday, and not on Monday", run_tue.others)
	var no_runs = log.filter(func(s): return str(s.discipline) != "run")
	var first_run = Missions.daily(today, {"sessions": no_runs, "pt": marks, "settings": {"focus": "upper", "split": "pull_push_legs", "runDay": 0}, "reading": [], "now": today}, state, [])
	ok(find(first_run, ":run") != null and find(first_run, ":run").title == "Run day" and find(first_run, ":pace") == null and not bool(Missions.day_plan(no_runs, today, marks, st).runToday), "no run yet: with a day picked the mission is to log one; without, there is no run day", first_run.map(func(m): return str(m.title)))
	# The climb of the day keeps its own mission beside the run's.
	var mon_climbs = log + [{"id": "c9", "discipline": "climb", "date": "2026-11-16", "createdAt": 1700000000900, "source": "manual", "climbs": [{"grade": 3, "result": "send", "count": 4}]}, {"id": "c8", "discipline": "climb", "date": "2026-11-09", "createdAt": 1700000000800, "source": "manual", "climbs": [{"grade": 3, "result": "send", "count": 4}]}]
	var both_day = Missions.daily(today, {"sessions": mon_climbs, "pt": marks, "settings": st, "reading": [], "now": today}, state, [])
	ok(find(both_day, ":climb") != null and find(both_day, ":run") != null and find(both_day, ":pace") != null, "a climbing Monday: the climb mission and both run goals", both_day.map(func(m): return str(m.id)))


	# --- the week: every muscle being built on target at once ------------------------------------------
	var dz = find(week, ":dose")
	var before_press = Dose.on_target(log, marks, st, today)
	ok(dz != null and int(dz.target) == 6 and int(dz.progress) == before_press and before_press < 6 and str(dz.desc).contains("chest, back, side delts, rear delts, biceps, triceps") and find(Missions.weekly(wk, today, data_off, state, []), ":dose") == null, "Dosed right: every muscle being built, the shoulders as their heads (%d of 6 before the press)" % before_press, dz)
	var full = log + [lift(today, {"Bench Press - Incline dumbbell": three(10, 20), "Chest Fly - Cable": three(12, 15), "Face Pull": three(15, 10), "Lateral Raise - Dumbbell": three(12, 8)})]
	ok(Dose.on_target(full, marks, st, today) == 6 and find(Missions.weekly(wk, today, {"sessions": full, "pt": marks, "settings": st, "reading": [], "now": today}, state, []), ":dose").done, "with the press, the flyes and the shoulders' own work: six of six", Dose.window(full, marks, st, today).parts)

	# --- the morning message ---------------------------------------------------------------------------
	var text = Missions.morning_text(plan, day, "kg", "km")
	ok(text.begins_with("Push day. ") and text.contains("For your chest, 3 sets: Bench Press (barbell, new)") and text.contains("  or Bench Press (incline dumbbell, new)") and text.contains("Running: aim for 5.5 km"), "the morning message: the day, the press and its other ways, the run", text)
	var rtext = Missions.morning_text(rplan, rday, "kg", "km")
	ok(rtext.begins_with("Rest day from lifting: your call. Push day moves to tomorrow.") and not rtext.contains("For your chest") and not rtext.contains("Chest Fly") and rtext.contains("Running: aim for 5.5 km"), "on a rest day: the rest, what moves, the run, and no lift", rtext)
	ok(not Missions.morning_text(plain, day_off, "kg", "km").contains("For your") and not Missions.morning_text(plain, day_off, "kg", "km").contains("Rest day"), "without a focus it is as before")
	var lt = Missions.morning_text(lp, ld, "kg", "km")
	ok(lt.contains("Squat (barbell): 3×5 @ 102.5 kg"), "a leg lift's aim is one step more, as for any lift", lt)

	# --- where a muscle's sets came from, lift by lift ----------------------------------------------
	var src_log = [
		lift("2026-11-20", {"Lateral Raise - Dumbbell": three(12, 8), "Overhead Press - Barbell": three(8, 40), "Bench Press - Barbell": three(5, 80), "Chest Fly - Dumbbell": three(12, 12),
			"Tricep Pushdown - Gym rope": three(10, 30)}),
		lift("2026-11-21", {"Bent Over Row - Barbell": three(8, 60), "Face Pull": [[15, 10], [15, 10]], "Tricep Extension - Cable": three(10, 35), "Lateral Raise - Gym cable": three(20, 5),
			"Neck 4 Way": three(20, 4), "Chest Fly - Machine": []}),
		lift("2026-11-10", {"Overhead Press - Barbell": three(8, 40)}),
	]
	var src_marks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}
	var src = Dose.sources(src_log, src_marks, "2026-11-22")
	var side_rows = src.get("side_delts", [])
	var front_rows = src.get("front_delts", [])
	var rear_rows = src.get("rear_delts", [])
	ok(side_rows.map(func(x): return str(x.move)) == ["Lateral Raise", "Overhead Press"] and is_equal_approx(float(side_rows[0].direct), 6.0) and is_equal_approx(float(side_rows[1].half), 1.5), "the side delts: the lateral raises (both kinds), half a set from the overhead press", side_rows)
	ok(front_rows.map(func(x): return str(x.move)) == ["Overhead Press", "Bench Press", "Chest Fly"] and is_equal_approx(float(front_rows[0].direct), 3.0) and is_equal_approx(float(front_rows[1].half), 1.5) and is_equal_approx(float(front_rows[2].half), 0.75), "the front delts: the overhead press, half a set from the bench, a quarter from a fly", front_rows)
	ok(rear_rows.map(func(x): return str(x.move)) == ["Face Pull", "Bent Over Row"] and is_equal_approx(float(rear_rows[0].direct), 2.0) and is_equal_approx(float(rear_rows[1].half), 1.5), "the rear delts: face pulls, half a set from the row", rear_rows)
	ok(not src.has("shoulders"), "no shoulders as one number any more")
	var tr_rows = src.get("triceps", [])
	ok(tr_rows.size() == 3 and str(tr_rows[0].move) == "Tricep Pushdown" and is_equal_approx(float(tr_rows[0].direct), 6.0) and is_equal_approx(float(tr_rows[1].half), 1.5) and is_equal_approx(float(tr_rows[2].half), 1.5), "a pushdown and a cable extension are one lift here too", tr_rows)
	var src_w = Dose.window(src_log, src_marks, st, "2026-11-22")
	var adds_up = true
	for p in Dose.PARTS:
		var d_sum = 0.0
		var h_sum = 0.0
		for src_row in src.get(p, []):
			d_sum += float(src_row.direct)
			h_sum += float(src_row.half)
		if not is_equal_approx(d_sum, float(src_w.parts[p].direct)) or not is_equal_approx(h_sum, float(src_w.parts[p].indirect)):
			adds_up = false
	ok(adds_up, "it adds up to what the week counts for every muscle (physical therapy, empty exercises and older days left out)")
	ok(Dose.sources([], {}, "2026-11-22").is_empty() and not src.has("neck"), "no lifts, no sources")

	# --- the shoulders as three heads, the traps apart from the back ------------------------------------
	ok(Dose.main_part("Lateral Raise - Gym cable") == "side_delts" and Dose.main_part("Upright Row - Barbell") == "side_delts" and Dose.main_part("Overhead Press - Barbell") == "front_delts" and Dose.main_part("Arnold Press - Dumbbell") == "front_delts" and Dose.main_part("Face Pull - Green band") == "rear_delts" and Dose.main_part("Rear Delt Fly - Dumbbell") == "rear_delts", "each shoulder movement of the library trains its head")
	ok(Dose.main_part("Shrug - Barbell") == "traps" and Dose.main_part("Bent Over Row - Barbell") == "back" and Dose.main_part("Bench Press - Barbell") == "chest" and Dose.main_part("Squat - Barbell") == "quads", "shrugs are the traps; every other lift its body part")
	ok(Dose.head_of("Reverse Pec Deck") == "rear_delts" and Dose.head_of("Shoulder Press - Machine") == "front_delts" and Dose.head_of("Y Raise") == "side_delts", "a shoulder lift of the player's own: by its words")
	ok(Dose.also_of("Bench Press - Barbell") == {"triceps": 0.5, "front_delts": 0.5} and Dose.also_of("Chest Fly - Cable") == {"front_delts": 0.25} and Dose.also_of("Bent Over Row - Barbell") == {"biceps": 0.5, "rear_delts": 0.5}, "what a lift also works: half a set, a quarter for a fly", [Dose.also_of("Bench Press - Barbell"), Dose.also_of("Chest Fly - Cable")])
	ok(Dose.also_of("Overhead Press - Barbell") == {"triceps": 0.5, "chest": 0.5, "side_delts": 0.5} and Dose.also_of("Lateral Raise - Dumbbell").is_empty() and Dose.also_of("Shrug - Barbell") == {"forearms": 0.5} and Dose.also_of("Rear Delt Fly") == {"back": 0.25} and Dose.also_of("Upright Row") == {"traps": 0.5}, "an overhead press works the side delts too; nothing counts twice for its own muscle", [Dose.also_of("Overhead Press - Barbell"), Dose.also_of("Shrug - Barbell"), Dose.also_of("Rear Delt Fly")])
	ok(Dose.part_name("side_delts") == "Side delts" and Dose.part_name("traps") == "Traps" and Dose.part_name("chest") == "Chest", "their names")
	# A push day and a pull day as the user logs them: the shoulders no longer read as one big number.
	var heads_log = [
		lift("2026-11-17", {"Bent Over Row - Barbell": three(8, 60), "Lat Pulldown": three(10, 50), "Face Pull": three(15, 10), "Shrug - Barbell": three(10, 80), "Bicep Curl - Dumbbell": three(10, 12)}),
		lift("2026-11-18", {"Chest Fly - Dumbbell": three(12, 14), "Lateral Raise - Dumbbell": three(12, 8), "Overhead Press - Barbell": three(8, 40), "Tricep Pushdown - Gym rope": three(10, 30)}),
		lift("2026-11-20", {"Bent Over Row - Barbell": three(8, 60), "Lat Pulldown": three(10, 50), "Face Pull": three(15, 10), "Shrug - Barbell": three(10, 80), "Bicep Curl - Dumbbell": three(10, 12)}),
		lift("2026-11-21", {"Chest Fly - Dumbbell": three(12, 14), "Lateral Raise - Dumbbell": three(12, 8), "Overhead Press - Barbell": three(8, 40), "Tricep Pushdown - Gym rope": three(10, 30)}),
	]
	var hw = Dose.window(heads_log, {}, st, "2026-11-22").parts
	ok(is_equal_approx(float(hw.side_delts.total), 9.0) and is_equal_approx(float(hw.rear_delts.total), 9.0) and is_equal_approx(float(hw.front_delts.total), 7.5) and is_equal_approx(float(hw.traps.total), 6.0) and is_equal_approx(float(hw.back.total), 12.0), "two push and two pull days: side delts 9 (raises 6, presses 3), rear 9, front 7.5, traps 6, back 12 without the shrugs", [hw.side_delts.total, hw.rear_delts.total, hw.front_delts.total, hw.traps.total, hw.back.total])
	ok(hw.side_delts.state == "ok" and hw.front_delts.mode == "keep" and hw.traps.mode == "keep" and hw.chest.state == "short", "each against its own target; the chest is what is short", [hw.side_delts.state, hw.chest.state])

	# --- a lift done on another kind of day: planned there -------------------------------------------------
	var moved_log = []
	var pull_day = {"Bent Over Row - Barbell": three(8, 60), "Lat Pulldown": three(10, 50), "Lateral Raise - Dumbbell": three(12, 8)}
	var push_day = {"Bench Press - Barbell": three(5, 80), "Chest Fly - Dumbbell": three(12, 14), "Tricep Pushdown - Gym rope": three(10, 30)}
	var legs_day = {"Squat - Barbell": three(5, 100)}
	var mday = "2026-11-08"
	for k in range(5):
		moved_log.append(lift(Dates.add_days(mday, k * 3), pull_day))
		moved_log.append(lift(Dates.add_days(mday, k * 3 + 1), push_day))
		moved_log.append(lift(Dates.add_days(mday, k * 3 + 2), legs_day))
	var mk = Missions.done_kinds(moved_log, "2026-11-23", {})
	ok(str(mk.get("lateral raise", "")) == "pull" and mk.size() == 1, "lateral raises done on pull days and not on the push days between: a pull day's lift now", mk)
	var ppl = {"weightUnit": "kg", "split": "pull_push_legs"}
	var on_pull = Missions.day_plan(moved_log, "2026-11-23", {}, ppl)
	var on_push = Missions.day_plan(moved_log + [lift("2026-11-23", pull_day)], "2026-11-24", {}, ppl)
	ok(on_pull.kind == "pull" and on_pull.lifts.any(func(l): return str(l.name) == "Lateral Raise - Dumbbell") and on_push.kind == "push" and not on_push.lifts.any(func(l): return str(l.name) == "Lateral Raise - Dumbbell"), "so it is planned on the pull day, not the push day", [on_pull.lifts.map(func(l): return str(l.name)), on_push.lifts.map(func(l): return str(l.name))])
	var full_body = []
	for d in ["2026-10-19", "2026-10-26", "2026-11-02", "2026-11-09", "2026-11-16"]:
		full_body.append(lift(d, {"Squat - Barbell": three(5, 100), "Romanian Deadlift - Barbell": three(5, 80), "Bench Press - Barbell": three(5, 80)}))
	ok(Missions.done_kinds(full_body, "2026-11-23", {}).is_empty(), "a full-body day (a leg day by its majority) moves nothing: there were no push days without the bench")
	var once = moved_log.duplicate()
	once.append(lift("2026-11-22", {"Bent Over Row - Barbell": three(8, 60), "Shrug - Barbell": three(10, 80), "Lateral Raise - Dumbbell": three(12, 8)}))
	var back_on_push = once + [lift("2026-11-23", push_day.merged({"Lateral Raise - Dumbbell": three(12, 8)})), lift("2026-11-24", push_day.merged({"Lateral Raise - Dumbbell": three(12, 8)}))]
	ok(not Missions.done_kinds(back_on_push, "2026-11-25", {}).has("lateral raise"), "done on push days again twice: back to the push day")

	print("DOSE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
