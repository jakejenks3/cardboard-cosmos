extends SceneTree
## Unit test for game/prep.gd: a day prepped ahead becomes that day's plan; the lifts of the same muscles.
##   godot --headless --path . --script res://tests/prep_test.gd
## Prints PREP: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
const TODAY = "2026-11-27"
const TOMORROW = "2026-11-28"


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _lift(date: String, exs: Dictionary) -> Dictionary:
	var exercises = []
	for n in exs:
		var sets = []
		for r in exs[n]:
			sets.append({"reps": int(r[0]), "weightKg": float(r[1])})
		exercises.append({"name": n, "sets": sets})
	return {"id": "s" + date + str(exs.size()), "discipline": "lift", "date": date, "createdAt": 1, "exercises": exercises}


func _init() -> void:
	var push = {"Bench Press - Barbell": [[5, 80], [5, 80], [5, 80]], "Overhead Press - Barbell": [[6, 50], [6, 50]], "Tricep Pushdown - Rope": [[12, 25], [12, 25]]}
	var pull = {"Lat Pulldown - Cable": [[10, 55], [10, 55]], "Bent Over Row - Barbell": [[8, 60], [8, 60]], "Bicep Curl - Dumbbell": [[10, 12], [10, 12]]}
	var log = [_lift("2026-11-20", push), _lift("2026-11-21", pull), _lift("2026-11-24", push), _lift("2026-11-25", pull), _lift("2026-11-26", push)]
	var settings = {"weightUnit": "kg", "split": "push_pull_legs"}

	# Storing.
	var lifts = [{"name": "Bench Press - Dumbbell", "sets": [{"reps": 10, "weightKg": 30.0}, {"reps": 10, "weightKg": 30.0}], "ss": 1},
		{"name": "Lateral Raise - Dumbbell", "sets": [{"reps": 15, "weightKg": 8.0}], "ss": 1}, {"name": "", "sets": []}]
	var preps = Prep.with_prep({"preps": {"2026-10-01": {"lifts": [{"name": "Squat", "sets": []}]}}}, TOMORROW, lifts, TODAY, 5)
	ok(preps.has(TOMORROW) and not preps.has("2026-10-01") and (preps[TOMORROW].lifts as Array).size() == 2 and int(preps[TOMORROW].lifts[0].ss) == 1, "a prep is stored by its day, nameless lifts and old days dropped", preps)
	ok(not Prep.with_prep({"preps": preps}, TOMORROW, [], TODAY).has(TOMORROW), "an empty prep takes it off")
	var st2 = settings.duplicate()
	st2["preps"] = preps
	ok(Prep.of(st2, TOMORROW) != null and Prep.of(st2, TODAY) == null, "of: the prep of a day, or null")
	ok(Prep.lift_on(st2, TOMORROW, "bench press - dumbbell") != null and Prep.lift_on(st2, TOMORROW, "Squat") == null, "lift_on: a prepped lift of the day")

	# A prepped day's plan is the prep.
	var plain = Missions.day_plan(log, TOMORROW, {}, settings)
	var prepped = Missions.day_plan(log, TOMORROW, {}, st2)
	ok(not bool(plain.get("prepped", false)) and bool(prepped.prepped), "the plan says it is prepped")
	ok(prepped.lifts.map(func(l): return str(l.name)) == ["Bench Press - Dumbbell", "Lateral Raise - Dumbbell"], "its lifts are the prep's, in order", prepped.lifts.map(func(l): return str(l.name)))
	ok(prepped.lifts.all(func(l): return l.has("aimSets") and str(l.why) == "Your prep") and int(prepped.lifts[0].aimSets[0].reps) == 10, "each with the prepped sets as its aim")
	ok(str(prepped.lifts[0].options[0].name) == "Bench Press - Dumbbell" and prepped.lifts[0].options.size() >= 2, "the way prepped first, the other ways after it")
	ok(int(prepped.lifts[0].ss) == 1 and int(prepped.lifts[1].ss) == 1, "and their superset")
	var day = Missions.daily(TOMORROW, {"sessions": log, "pt": {}, "settings": st2, "reading": []}, {"levels": {"hero": {"level": 5}}, "sessionXp": {}}, [])
	var ch = day.filter(func(m): return bool(m.get("challenge", false)))
	ok(not ch.is_empty() and ch.all(func(m): return ["Bench Press - Dumbbell", "Lateral Raise - Dumbbell"].has(str(m.lift))), "the day's challenges are for the prepped lifts", ch.map(func(m): return m.lift))

	# From the plan: a prep to start from.
	var start = Prep.from_plan(plain.lifts, 2.5)
	ok(start.size() == plain.lifts.filter(func(l): return not bool(l.pt)).size() and start.all(func(x): return not (x.sets as Array).is_empty()), "a prep to start from: the plan's lifts with sets", start.map(func(x): return x.name))
	var bench = start.filter(func(x): return str(x.name) == "Bench Press - Barbell")
	ok(bench.is_empty() or LiftTrend.real_sets(bench[0].sets).size() == 3, "each the aim after last time (next_target)", bench)
	ok(Prep.aim_of([], 2.5) == [{"reps": 8, "weightKg": 0.0}, {"reps": 8, "weightKg": 0.0}, {"reps": 8, "weightKg": 0.0}], "a lift never done: 3 x 8 to start")

	# Coming up follows the prep.
	var ah = Missions.ahead(log, TODAY, {}, st2, 3)
	var tm = ah.filter(func(a): return str(a.date) == TOMORROW)
	ok(not tm.is_empty() and bool(tm[0].plan.get("prepped", false)) and tm[0].plan.lifts.size() == 2, "Coming up shows the prepped day as prepped")

	# A GOAL (2026-11-28): a record picked for a lift of the day goes into the day's prep, its LAST set that record (the ones before work up to it).
	var heavier = {"type": "heavier", "kind": "weight", "kg": 85.0, "reps": 3, "title": "Heavier than ever", "words": "85 kg × 3", "tip": "x", "chip": "85 × 3"}
	var gp = Prep.with_goal(settings, TODAY, "Bench Press - Barbell", heavier, TODAY, plain.lifts, 2.5, [{"reps": 5, "weightKg": 80.0}, {"reps": 5, "weightKg": 80.0}, {"reps": 5, "weightKg": 80.0}])
	var st3 = settings.duplicate()
	st3["preps"] = gp
	var gx = Prep.lift_on(st3, TODAY, "Bench Press - Barbell")
	ok(gx != null and str(Prep.goal_of(gx).get("type", "")) == "heavier" and not Prep.goal_of(gx).has("tip"), "with_goal: the prep is made from the plan, the lift has the goal (without its tip)", gx)
	ok(gx != null and gx.sets.size() >= 2 and bool(gx.sets[-1].get("goal", false)) and int(gx.sets[-1].reps) == 3 and is_equal_approx(float(gx.sets[-1].weightKg), 85.0) and not gx.sets.slice(0, -1).any(func(x): return x.has("goal")) and int(gx.sets[0].reps) != 3, "its last set is the record, marked; the sets before it keep their numbers, unmarked", gx.sets if gx != null else null)
	ok(Prep.lifts_of(Prep.of(st3, TODAY)).size() >= 2, "the other planned lifts are in the prep too")
	var tp = Missions.day_plan(log, TODAY, {}, st3)
	var tb = tp.lifts.filter(func(l): return str(l.name) == "Bench Press - Barbell")
	ok(not tb.is_empty() and str(tb[0].get("goal", {}).get("type", "")) == "heavier", "the day's plan carries the goal")
	var td = Missions.daily(TODAY, {"sessions": log, "pt": {}, "settings": st3, "reading": []}, {"levels": {"hero": {"level": 5}}, "sessionXp": {}}, [])
	var tch = td.filter(func(m): return bool(m.get("challenge", false)))
	ok(not tch.is_empty() and str(tch[0].lift) == "Bench Press - Barbell" and str(tch[0].goal.get("type", "")) == "heavier" and Challenges.same_option(tch[0].options[0], heavier), "the lift with a goal is the first challenge, its goal the first record", tch.map(func(m): return [m.lift, m.options.map(func(o): return o.type)]))
	ok(tch.size() <= Missions.BEAT_MISSIONS and Missions.BEAT_MISSIONS == 3, "three lift challenges a day at most")
	var ungo = Prep.with_goal(st3, TODAY, "Bench Press - Barbell", {}, TODAY, plain.lifts, 2.5)
	var st4 = settings.duplicate()
	st4["preps"] = ungo
	var ux = Prep.lift_on(st4, TODAY, "Bench Press - Barbell")
	ok(ux != null and Prep.goal_of(ux).is_empty() and not ux.sets.any(func(x): return x.has("goal")), "an empty goal takes it off, and the mark")
	# Another way, for the equipment there is: the movement's prepped lift is swapped; its goal goes with the old way.
	var wp = Prep.with_way(st3, TODAY, "Bench Press - Barbell", "Bench Press - Dumbbell", TODAY, plain.lifts, 2.5, [{"reps": 10, "weightKg": 30.0}])
	var st5 = settings.duplicate()
	st5["preps"] = wp
	ok(Prep.lift_on(st5, TODAY, "Bench Press - Barbell") == null and Prep.lift_on(st5, TODAY, "Bench Press - Dumbbell") != null and Prep.goal_of(Prep.lift_on(st5, TODAY, "Bench Press - Dumbbell")).is_empty(), "with_way: the dumbbell bench in the barbell's place, no goal")
	var g2 = Prep.with_goal(st5, TODAY, "Bench Press - Dumbbell", {"type": "reps", "kg": 30.0, "reps": 11, "title": "Rep record", "words": "11 reps at 30 kg"}, TODAY, plain.lifts, 2.5)
	var st6 = settings.duplicate()
	st6["preps"] = g2
	var dx = Prep.lift_on(st6, TODAY, "Bench Press - Dumbbell")
	ok(dx != null and int(dx.sets[-1].reps) == 11 and bool(dx.sets[-1].goal), "a goal on the way picked (its last set)")
	ok(Prep.apply_goal([{"reps": 5, "weightKg": 80.0}], {"type": "day_reps", "reps": 40}).all(func(x): return not x.has("goal")), "a day's total marks no set")
	# The sets before the goal work up to it: one that would already meet it is eased just under it.
	var eased = Prep.apply_goal([{"reps": 10, "weightKg": 25.0}, {"reps": 10, "weightKg": 25.0}, {"reps": 10, "weightKg": 25.0}], {"type": "heavier", "kg": 25.0, "reps": 8}, 2.5)
	ok(bool(eased[2].goal) and int(eased[2].reps) == 8 and is_equal_approx(float(eased[0].weightKg), 22.5) and is_equal_approx(float(eased[1].weightKg), 22.5) and int(eased[0].reps) == 10, "a heavier goal: the sets before it one step lighter", eased)
	var eased2 = Prep.apply_goal([{"reps": 12, "weightKg": 20.0}, {"reps": 8, "weightKg": 20.0}, {"reps": 8, "weightKg": 20.0}], {"type": "reps", "kg": 20.0, "reps": 11}, 2.5)
	ok(int(eased2[0].reps) == 9 and int(eased2[1].reps) == 8 and int(eased2[2].reps) == 11, "a rep record: a set before it that already has the reps gets two fewer, the others stay", eased2)

	# The same muscles.
	ok(Prep.area_parts([], "push") == ["chest", "shoulders", "triceps"], "a push day: chest, shoulders, triceps", Prep.area_parts([], "push"))
	ok(Prep.area_parts(["Bicep Curl - Dumbbell"], "").has("biceps"), "a workout's own lifts name their parts")
	var area = Prep.area_lifts(["chest", "shoulders", "triceps"], log, ["Overhead Press - Barbell"], {}, 8)
	var names = area.map(func(e): return str(e.name))
	ok(names.has("Bench Press - Barbell") and names.has("Tricep Pushdown - Rope") and not names.any(func(n): return str(n).begins_with("Overhead Press")), "the player's own lifts of those muscles, not one already in the workout", names)
	ok(area.size() <= 8 and area.any(func(e): return not bool(e.own)), "then the library's staples", area)
	ok(not names.any(func(n): return Missions.part_of(str(n)) == "back" or Missions.part_of(str(n)) == "biceps"), "never another area's lifts")
	print("PREP: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
