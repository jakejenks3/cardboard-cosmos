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
	ok(Dose.parts_today("push", "") == ["chest", "shoulders", "triceps"] and Dose.parts_today("upper", "").has("back") and Dose.parts_today("upper", "").has("chest") and Dose.parts_today("", "legs") == ["quads", "hamstrings", "glutes", "calves"] and Dose.parts_today("", "").is_empty(), "the muscles of a day", [Dose.parts_today("push", ""), Dose.parts_today("", "legs")])

	# --- the plan: a press for the chest, first ------------------------------------------------
	var plain = Missions.day_plan(log, today, marks, off)
	var plan = Missions.day_plan(log, today, marks, st)
	ok(plain.kind == "push" and plain.focus == "" and not plain.lifts.any(func(l): return l.has("dose") or l.has("mode")) and plain.run == null and not plain.rest.due, "no focus: the plan is as it was", plain.lifts.map(func(l): return str(l.name)))
	ok(plan.focus == "upper" and plan.lifts.size() == plain.lifts.size() + 1 and plan.lifts[0].has("dose") and plan.lifts.slice(1).map(func(l): return str(l.name)) == plain.lifts.map(func(l): return str(l.name)), "with a focus: one extra lift, put first, the usual ones after it", plan.lifts.map(func(l): return str(l.name)))
	var x = plan.lifts[0]
	ok(x.dose.part == "chest" and bool(x.dose.anchor) and int(x.dose.sets) == 3 and is_equal_approx(float(x.dose.have), 6.0) and is_equal_approx(float(x.dose.cover), 3.0) and str(x.why) == "6 of 10 sets in 7 days, no press" and is_equal_approx(float(x.dose.need), 1.0), "the chest is short and has no press: 3 sets of one", [x.dose, x.why])
	ok(x.options.map(func(o): return str(o.name)) == ["Bench Press - Barbell", "Bench Press - Incline dumbbell", "Bench Press - Machine", "Push-up - Weighted", "Dip"] and x.options.all(func(o): return bool(o.new)) and x.name == "Bench Press - Barbell", "a press for every sort of equipment, the barbell first", x.options.map(func(o): return str(o.name)))
	ok(plan.new != null and not ["Bench Press", "Push-up", "Dip"].has(str(plan.new.move)) and not plan.new.alts.any(func(a): return ["Bench Press", "Push-up", "Dip"].has(str(a.move))), "\"try something new\" offers other movements than the press", [plan.new.name, plan.new.alts.map(func(a): return str(a.name))])
	ok(plan.lifts.slice(1).all(func(l): return str(l.mode) == "build") and ["Bench Press", "Push-up", "Dip"].all(func(m): return plan.moves.has(Xp.normalize_exercise(m))), "the day's lifts are for building; the press's movements belong to the plan", plan.moves)
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
	ok(day.filter(func(m): return str(m.id).contains(":beat:")).size() == 2 and not day.any(func(m): return str(m.id).contains(":beat:bench press")) and day.filter(func(m): return str(m.id).contains(":beat:")).all(func(m): return str(m.title).begins_with("Beat it")), "the two Beat it missions are still the usual lifts", day.map(func(m): return str(m.title)))
	data.sessions = two
	ok(int(find(Missions.daily(today, data, state, []), ":dose:chest").progress) == 2 and not find(Missions.daily(today, data, state, []), ":dose:chest").done, "two sets: two of three")
	data.sessions = done3
	var after = Missions.daily(today, data, state, [])
	ok(find(after, ":dose:chest").done and after.map(func(m): return str(m.id)) == day.map(func(m): return str(m.id)), "three sets: done, and logging does not change the day's missions")
	data.sessions = log

	# --- rest ------------------------------------------------------------------------------------------
	var rest = Dose.rest(log, marks, today)
	ok(int(rest.run) == 7 and bool(rest.due) and not bool(rest.today) and bool(plan.rest.due), "seven hard days in a row: a rest day is due", rest)
	var until = func(d: String): return log.filter(func(s): return str(s.date) < d)
	ok(not bool(Dose.rest(until.call("2026-11-20"), marks, "2026-11-20").due) and int(Dose.rest(until.call("2026-11-20"), marks, "2026-11-20").run) == 4 and bool(Dose.rest(until.call("2026-11-21"), marks, "2026-11-21").due), "four in a row is not yet; five is", [Dose.rest(until.call("2026-11-20"), marks, "2026-11-20"), Dose.rest(until.call("2026-11-21"), marks, "2026-11-21")])
	ok(not bool(Dose.rest(done3, marks, today).due) and int(Dose.rest(done3, marks, today).run) == 8, "training anyway: not due any more, and the run goes on")
	var rm = find(day, ":rest")
	ok(rm != null and find(day, ":show") == null and day[0].id == rm.id and not rm.done and str(rm.desc).begins_with("7 days in a row."), "the day's first mission is to rest, in place of showing up", day.map(func(m): return str(m.id)))
	var easy_day = log + [lift(today, {"Neck 4 Way": three(20, 4), "Pec Stretch": [[1, 0, 30]]}), {"id": "w1", "discipline": "misc", "kind": "vest_walk", "date": today, "distanceM": 3000.0, "loadKg": 10.0}]
	var pt_marks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}
	ok(not Dose.hard_on(easy_day, pt_marks, today) and Dose.hard_on(done3, marks, today) and Dose.hard_on(log, marks, "2026-11-21"), "a walk, PT and stretches are not a hard day; a lift or a climb is")
	var next_day = {"sessions": easy_day, "pt": pt_marks, "settings": st, "reading": [], "now": "2026-11-24"}
	ok(find(Missions.daily(today, next_day, state, []), ":rest").done, "the day after: rested (a walk and PT only), the mission is done")
	next_day.sessions = done3
	ok(not find(Missions.daily(today, next_day, state, []), ":rest").done, "trained anyway: not done")
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
	ok(beats.size() == 2 and beats.all(func(m): return str(m.title).begins_with("Beat it: ") and str(m.desc).begins_with("Last time ") and str(m.desc).contains("Aim for ")), "its lifts still have goals to beat", beats.map(func(m): return [m.title, m.desc]))
	ok(beats.map(func(m): return [m.id, m.title, m.desc, m.aim]) == ld_off.filter(func(m): return str(m.id).contains(":beat:")).map(func(m): return [m.id, m.title, m.desc, m.aim]), "the same missions as without a focus")
	var b0 = beats[0]
	var lighter = leg_log + [lift(leg_day, {str(b0.lift): [[5, 60]]})]
	var heavier = leg_log + [lift(leg_day, {str(b0.lift): b0.aim.map(func(one): return [int(one.reps), float(one.weightKg)])})]
	var tail = str(b0.id).substr(str(b0.id).find(":beat:"))
	ok(not find(Missions.daily(leg_day, {"sessions": lighter, "pt": marks, "settings": st, "reading": [], "now": leg_day}, state, []), tail).done and find(Missions.daily(leg_day, {"sessions": heavier, "pt": marks, "settings": st, "reading": [], "now": leg_day}, state, []), tail).done, "a lighter day does not beat it; reaching the aim does")
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
	ok(tx.any(func(l): return str(l.dose.part) == "triceps" and not bool(l.dose.anchor) and l.options.size() >= 1 and Dosage.part(str(l.name)) == "triceps") and not tx.any(func(l): return str(l.dose.part) == "chest"), "triceps short (only the bench's half sets): a triceps movement is added; the chest has its press", tx.map(func(l): return [l.dose, l.options.map(func(o): return str(o.name))]))
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
	var lr = find(week, ":longrun")
	ok(lr != null and is_equal_approx(float(lr.target), 5500.0) and is_equal_approx(float(lr.progress), 0.0) and find(Missions.weekly(wk, today, data_off, state, []), ":longrun") == null, "a Long run mission for the week", lr)
	var ran = log + [{"id": "r2", "discipline": "run", "date": today, "createdAt": 1700000002000, "source": "manual", "distanceM": 5600.0, "durationSec": 2000}]
	ok(find(Missions.weekly(wk, today, {"sessions": ran, "pt": marks, "settings": st, "reading": [], "now": today}, state, []), ":longrun").done and is_equal_approx(float(find(Missions.weekly(wk, today, {"sessions": ran, "pt": marks, "settings": st, "reading": [], "now": today}, state, []), ":longrun").target), 5500.0), "run it: done, and the target has not moved")

	# --- the week: every muscle being built on target at once ------------------------------------------
	var dz = find(week, ":dose")
	ok(dz != null and int(dz.target) == 5 and int(dz.progress) == 4 and str(dz.desc).contains("chest, back, shoulders, biceps, triceps") and find(Missions.weekly(wk, today, data_off, state, []), ":dose") == null, "Dosed right: four of five before the press", dz)
	var full = log + [lift(today, {"Bench Press - Incline dumbbell": three(10, 20), "Chest Fly - Cable": three(12, 15)})]
	ok(Dose.on_target(full, marks, st, today) == 5 and find(Missions.weekly(wk, today, {"sessions": full, "pt": marks, "settings": st, "reading": [], "now": today}, state, []), ":dose").done, "with the press and the flyes: five of five")

	# --- the morning message ---------------------------------------------------------------------------
	var text = Missions.morning_text(plan, day, "kg", "km")
	ok(text.begins_with("Rest day: 7 days in a row.") and text.contains("For your chest, 3 sets: Bench Press (barbell, new)") and text.contains("  or Bench Press (incline dumbbell, new)") and text.contains("Running: aim for 5.5 km"), "the morning message: rest, the press and its other ways, the run", text)
	ok(not Missions.morning_text(plain, day_off, "kg", "km").contains("For your") and not Missions.morning_text(plain, day_off, "kg", "km").contains("Rest day"), "without a focus it is as before")
	var lt = Missions.morning_text(lp, ld, "kg", "km")
	ok(lt.contains("Squat (barbell): 3×5 @ 102.5 kg"), "a leg lift's aim is one step more, as for any lift", lt)

	print("DOSE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
