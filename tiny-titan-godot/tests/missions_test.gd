extends SceneTree
## Unit test for game/missions.gd: the day's plan from the player's own log
## and the daily / weekly missions made from it. Made-up data.
##   godot --headless --path . --script res://tests/missions_test.gd
## Prints MISSIONS: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-20"  # a Friday

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## A lift session: {name: [[reps, kg], ...]}.
func lift(date: String, exercises: Dictionary) -> Dictionary:
	_n += 1
	var exs = []
	for name in exercises:
		var sets = []
		for st in exercises[name]:
			sets.append({"reps": st[0], "weightKg": float(st[1])})
		exs.append({"name": name, "sets": sets})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "exercises": exs}


func climb(date: String, sends: int) -> Dictionary:
	_n += 1
	var climbs = [{"grade": 3, "result": "send", "count": sends}]
	return {"id": "c%d" % _n, "discipline": "climb", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "climbs": climbs}


func find(list: Array, id_end: String):
	for m in list:
		if str(m.id).ends_with(id_end):
			return m
	return null


func names(list: Array) -> Array:
	return list.map(func(l): return str(l.name))


func _init() -> void:
	# Fridays: a back day. Mondays: a chest day. Squats every five days. A PT
	# exercise on most days. Climbing on Saturdays.
	var back = {"Lat Pulldown - Single arm": [[12, 36], [10, 36], [10, 36]], "Bent Over Row - Barbell": [[8, 60], [8, 60], [8, 60]]}
	var chest = {"Bench Press - Barbell": [[5, 80], [5, 80]], "Chest Fly - Cable": [[12, 15], [12, 15]]}
	var log = [
		lift("2026-10-30", back), lift("2026-11-06", back), lift("2026-11-13", back),
		lift("2026-11-09", chest), lift("2026-11-16", chest),
		lift("2026-11-01", {"Squat - Barbell": [[5, 100]]}), lift("2026-11-06", {"Squat - Barbell": [[5, 100]]}),
		lift("2026-11-11", {"Squat - Barbell": [[5, 102.5]]}), lift("2026-11-16", {"Squat - Barbell": [[5, 105]]}),
		lift("2026-11-17", {"Neck 4 Way": [[20, 4.5]]}), lift("2026-11-18", {"Neck 4 Way": [[20, 4.5]]}),
		climb("2026-11-07", 5), climb("2026-11-14", 7),
	]
	var marks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}

	# --- what is likely today -------------------------------------------------------------
	var likely = Missions.likely_lifts(log, TODAY, marks)
	var ln = names(likely)
	ok(ln.size() >= 3 and ln[0] in ["Bent Over Row - Barbell", "Lat Pulldown - Single arm"] and ln.has("Squat - Barbell") and ln.has("Neck 4 Way"), "Friday: the back day's lifts first, the squat that is due, the PT", ln)
	ok(not ln.has("Bench Press - Barbell") and not ln.has("Chest Fly - Cable"), "Monday's chest lifts are not due on a Friday (4 days after, every 7)", ln)
	var lat = likely.filter(func(l): return l.name == "Lat Pulldown - Single arm")[0]
	ok(int(lat.same) == 3 and lat.why == "You often do it on Fridays" and lat.last.date == "2026-11-13", "why it is likely, and the last time", lat)
	var sq = likely.filter(func(l): return l.name == "Squat - Barbell")[0]
	ok(is_equal_approx(sq.gap, 5.0) and str(sq.why).begins_with("You did it on a Friday"), "the squat: every 5 days, and once on a Friday", sq.why)
	ok(Missions.likely_lifts(log, "2026-11-23", marks).any(func(l): return l.name == "Bench Press - Barbell"), "Monday brings the chest day back")

	# --- the plan -------------------------------------------------------------------------
	var plan = Missions.day_plan(log, TODAY, marks)
	ok(plan.group == "back" and plan.label == "Back day", "two back lifts make it a back day", [plan.group, plan.label])
	ok(plan.new != null and plan.new.part == "back" and not ["Lat Pulldown", "Bent Over Row"].has(plan.new.move), "a back movement never done is suggested", plan.new)
	ok(plan.new != null and LiftNames.split(str(plan.new.name)).move == plan.new.move, "suggested with its usual variation", plan.new)
	ok(plan.pt.size() == 1 and plan.pt[0].name == "Neck 4 Way", "PT still to do this week (2 of 3)", plan.pt)
	ok(Missions.day_plan(log, TODAY, marks).new.name == plan.new.name, "the same day suggests the same movement")
	ok(Missions.day_plan(log, "2026-11-21", marks).others.any(func(o): return o.discipline == "climb" and is_equal_approx(o.avg, 6.0)), "Saturday: climbing, about 6 sends")

	# --- the day's missions -----------------------------------------------------------------
	var data = {"sessions": log, "pt": marks, "settings": {"weightUnit": "kg", "distanceUnit": "km", "weeklyGoal": 3}, "reading": []}
	var state = {"levels": {"hero": {"level": 10}}, "sessionXp": {}, "body": {"entries": 0}}
	var day = Missions.daily(TODAY, data, state, [])
	var ids = day.map(func(m): return str(m.id))
	ok(find(day, ":show") != null and day.filter(func(m): return str(m.id).contains(":beat:")).size() == 2 and find(day, ":new") != null and find(day, ":pt") != null, "show up, beat it on two lifts, try something new, PT", ids)
	ok(day.all(func(m): return str(m.unit) != "min"), "no mission is about minutes")
	var beat = day.filter(func(m): return str(m.id).contains(":beat:"))[0]
	ok(beat.has("aim") and str(beat.desc).begins_with("Last time") and str(beat.desc).contains("Aim for") and not beat.done, "beat it says last time and what to aim for", beat.desc)
	ok(find(day, ":read") == null and find(day, ":climb") == null, "no reading mission without any reading, no climb on a Friday")

	# Today's workout: more reps on the pulldown, a new back movement, the PT.
	var todays = lift(TODAY, {"Lat Pulldown - Single arm": [[13, 36], [10, 36], [10, 36]], str(plan.new.name): [[10, 30]], "Neck 4 Way": [[20, 4.5]], "Bent Over Row - Barbell": [[8, 57.5], [8, 57.5]]})
	data.sessions = log + [todays]
	var after = Missions.daily(TODAY, data, state, [])
	ok(after.map(func(m): return str(m.id)) == ids, "logging today does not change the day's missions")
	var lat_m = find(after, ":beat:lat pulldown - single arm")
	var row_m = find(after, ":beat:bent over row - barbell")
	ok(lat_m != null and lat_m.done and row_m != null and not row_m.done, "one more rep beats it; a lighter row does not")
	ok(find(after, ":new").done and find(after, ":pt").done and find(after, ":show").done, "the new movement, the PT and showing up are done", [find(after, ":new"), find(after, ":pt"), find(after, ":show")])
	# "Try something new" is only done by sets really logged: not by the movement
	# added to the workout and left empty, not by a new physical therapy exercise.
	var nw = plan.new
	var offered = [str(nw.move)] + nw.alts.map(func(a): return str(a.move))
	ok(nw.alts.size() == Missions.NEW_ALTS and not nw.alts.any(func(a): return str(a.move) == str(nw.move)) and nw.alts.all(func(a): return a.part == "back" and not ["Lat Pulldown", "Bent Over Row"].has(a.move)), "two more back movements never done are offered beside it", nw.alts.map(func(a): return str(a.name)))
	ok(str(find(day, ":new").desc).contains(Missions.short_name(str(nw.alts[0].name))) and str(find(day, ":new").desc).contains("fits a back day"), "the mission names the others", find(day, ":new").desc)
	ok(Missions.new_by(log + [lift(TODAY, {"Lat Pulldown - Single arm": [[10, 36]]})], TODAY, plan) == "", "nothing new logged: not done")
	var empty_day = lift(TODAY, {"Lat Pulldown - Single arm": [[10, 36]]})
	empty_day.exercises.append({"name": str(nw.name), "sets": []})
	empty_day.exercises.append({"name": str(nw.alts[0].name), "sets": [{"reps": 0, "weightKg": 0.0}]})
	ok(Missions.new_by(log + [empty_day], TODAY, plan) == "", "added to the workout but no set logged: not done", Missions.new_by(log + [empty_day], TODAY, plan))
	ok(Missions.new_by(log + [lift(TODAY, {str(nw.alts[1].name): [[10, 20]]})], TODAY, plan) == str(nw.alts[1].name), "one of the others offered, logged: done by it")
	# Another new movement counts when it has the same goal (a back movement on a
	# back day), not a stretch, a PT exercise or a movement of another area.
	var back_new = ""
	for e in LiftLibrary.catalog():
		if str(e.part) == "back" and not offered.has(str(e.name)) and not ["Lat Pulldown", "Bent Over Row"].has(str(e.name)):
			back_new = str(e.name)
			break
	ok(back_new != "" and Missions.new_by(log + [lift(TODAY, {back_new: [[10, 20]]})], TODAY, plan) == back_new, "another back movement never done counts, by its name", back_new)
	ok(Missions.new_by(log + [lift(TODAY, {"Calf Raise": [[15, 40]]})], TODAY, plan) == "", "a new leg movement on a back day does not")
	ok(Missions.new_by(log + [lift(TODAY, {"Lat Stretch": [[3, 0]], "Toe Stretch": [[3, 0]]})], TODAY, plan) == "", "a new stretch does not")
	var pt_plan = plan.duplicate()
	pt_plan["marks"] = marks.duplicate(true)
	pt_plan.marks[Pt.key(back_new)] = {"name": back_new, "perWeek": 3}
	ok(Missions.new_by(log + [lift(TODAY, {back_new: [[10, 20]]})], TODAY, pt_plan) == "", "a new physical therapy exercise does not (the PT row counts it)")
	ok(Missions.new_by(log + [todays], TODAY, plan) == str(nw.name) and str(find(after, ":new").get("by", "")) == str(nw.name), "the suggested movement, logged: done, and the mission says by what", find(after, ":new"))
	var claimed = Missions.daily(TODAY, data, state, [{"questId": str(lat_m.id)}]).filter(func(m): return m.id == lat_m.id)[0]
	ok(bool(claimed.claimed), "a claim marks it claimed")

	# --- the week ---------------------------------------------------------------------------
	var week = Missions.weekly(Dates.week_key(TODAY), TODAY, data, state, [])
	var wids = week.map(func(m): return str(m.id))
	ok(find(week, ":days") != null and find(week, ":record") != null and find(week, ":new") != null and find(week, ":pt") != null and find(week, ":climb") != null and find(week, ":xp") != null, "days, a record, explore, PT, climbing and XP", wids)
	ok(int(find(week, ":days").progress) == 4 and find(week, ":record").done and find(week, ":new").done and find(week, ":pt").done, "this week: 4 days, a record, a new movement, PT on target", [find(week, ":days").progress, find(week, ":record").progress])
	ok(int(find(week, ":climb").target) == 1 and str(find(week, ":climb").title) == "Climb once", "climbing about as often as usual", find(week, ":climb"))
	ok(find(week, ":body") == null, "no check-in mission before body tracking is used")

	# --- a new player, and a day with no pattern ---------------------------------------------------
	var empty = Missions.daily(TODAY, {"sessions": [], "pt": {}, "settings": {}, "reading": []}, state, [])
	ok(empty.size() == 2 and find(empty, ":show") != null and find(empty, ":xp") != null, "nothing logged yet: show up and an XP goal", empty.map(func(m): return m.id))
	var reader = Missions.daily(TODAY, {"sessions": [], "pt": {}, "settings": {"readingGoal": 25}, "reading": [{"date": TODAY, "pages": 30}]}, state, [])
	ok(find(reader, ":read") != null and int(find(reader, ":read").target) == 25 and find(reader, ":read").done, "a reader gets a reading goal", find(reader, ":read"))

	# --- a training split -----------------------------------------------------------------------
	# Pull, push, legs: a pull day (Fri), legs (Sat), push (Mon), pull (Tue),
	# push with a squat added (Thu), pull (Fri). Saturday: one squat, last Saturday.
	var pull = {"Bent Over Row - Dumbbell": [[10, 30], [10, 30]], "Lat Pulldown - Single arm": [[12, 36]], "Face Pull - Rope": [[15, 20]], "Wrist 3 Way": [[20, 5]]}
	var push = {"Chest Fly - Cable": [[12, 15], [12, 15]], "Lateral Raise - Cable": [[12, 7.5]], "Tricep Pushdown - Rope": [[12, 25]]}
	var split_log = [
		lift("2026-11-13", pull), lift("2026-11-14", {"Squat - Barbell": [[5, 100]], "Calf Raise": [[15, 40]]}),
		lift("2026-11-16", push), lift("2026-11-17", pull),
		lift("2026-11-19", push.merged({"Squat - Barbell": [[5, 100]]})), lift("2026-11-20", pull),
	]
	var cycle = Missions.split_cycle("pull_push_legs")
	ok(cycle == ["pull", "push", "legs"] and Missions.split_cycle("auto").is_empty() and Missions.split_cycle("nonsense").is_empty(), "the splits", cycle)
	ok(Missions.kind_of("Face Pull - Rope") == "pull" and Missions.kind_of("Lateral Raise - Cable") == "push" and Missions.kind_of("Bicep Curl - Reclined") == "pull"
		and Missions.kind_of("Romanian Deadlift - Barbell") == "legs" and Missions.kind_of("Wrist 3 Way") == "" and Missions.kind_of("Plank") == "", "the kind of a lift (face pull pulls, wrists go with any day)")
	ok(Missions.kind_of_day(split_log[4].exercises, cycle) == "push", "push with a squat added is a push day")
	ok(Missions.fits("push", "upper") and Missions.fits("pull", "upper") and Missions.fits("legs", "lower") and not Missions.fits("", "upper"), "upper and lower")
	var sat = "2026-11-21"
	var sp = Missions.day_plan(split_log, sat, {}, {"split": "pull_push_legs"})
	var spn = names(sp.lifts)
	ok(sp.kind == "push" and sp.label == "Push day" and sp.after == "pull" and sp.afterDate == "2026-11-20" and Missions.kind_why(sp) == "Yesterday was a pull day", "after a pull day: a push day", [sp.kind, sp.label, Missions.kind_why(sp)])
	ok(spn.slice(0, 3).all(func(n): return push.has(n)) and not spn.has("Squat - Barbell") and not spn.has("Calf Raise") and not spn.has("Bent Over Row - Dumbbell"), "the push lifts; no legs or pull on a push day", spn)
	ok(sp.lifts[0].why == "On your push days; last done Thursday", "why a push lift is planned", sp.lifts[0].why)
	ok(sp.new != null and Missions.kind_of(str(sp.new.name)) == "push" and not push.has(str(sp.new.name)), "try a push movement never done", sp.new)
	ok(Missions.day_plan(split_log, "2026-11-22", {}, {"split": "pull_push_legs"}).kind == "push" and Missions.kind_why(Missions.day_plan(split_log, "2026-11-22", {}, {"split": "pull_push_legs"})) == "Friday was a pull day", "a rest day does not move the split")
	var after_push = split_log + [lift(sat, push)]
	ok(Missions.day_plan(after_push, "2026-11-22", {}, {"split": "pull_push_legs"}).kind == "legs", "after the push day comes legs")
	var legs_day = Missions.day_plan(after_push, "2026-11-22", {}, {"split": "pull_push_legs"})
	ok(names(legs_day.lifts).has("Squat - Barbell") and names(legs_day.lifts).has("Calf Raise"), "the leg day plans the squat (3 days on) and calves", names(legs_day.lifts))
	var picked = Missions.day_plan(split_log, sat, {}, {"split": "pull_push_legs", "dayPick": {"date": sat, "kind": "legs"}})
	ok(picked.kind == "legs" and picked.picked and Missions.kind_why(picked) == "Your pick for today" and Missions.day_plan(split_log, "2026-11-22", {}, {"split": "pull_push_legs", "dayPick": {"date": sat, "kind": "legs"}}).kind == "push", "a pick counts on its own day only")
	var ul = Missions.day_plan(split_log, sat, {}, {"split": "upper_lower"})
	ok(ul.kind == "lower" and ul.label == "Leg day", "upper, lower: after an upper day, legs", [ul.kind, ul.label])
	var first = Missions.day_plan([], sat, {}, {"split": "push_pull_legs"})
	ok(first.kind == "push" and Missions.kind_why(first) == "The first day of your split", "no lifts yet: the split's first day")
	# Without a split: the one Saturday squat is resting (done 2 days ago, every 5).
	var auto = Missions.day_plan(split_log, sat, {}, {"split": "auto"})
	ok(auto.kind == "" and auto.cycle.is_empty() and not names(auto.lifts).has("Squat - Barbell"), "no split: a squat two days after the last one is not due, Saturday or not", names(auto.lifts))
	var sdata = {"sessions": split_log, "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs"}, "reading": []}
	var sday = Missions.daily(sat, sdata, state, [])
	ok(sday.filter(func(m): return str(m.id).contains(":beat:")).all(func(m): return push.has(str(m.lift))), "the beat-it missions follow the split", sday.map(func(m): return m.id))
	ok(Missions.morning_text(sp, sday, "kg").begins_with("Push day. Yesterday was a pull day."), "the morning message names the split's day", Missions.morning_text(sp, sday, "kg"))

	# --- another movement standing in for a planned one --------------------------------------------
	var tri = Missions.same_of("Tricep Pushdown - Rope", sp)
	ok(Missions.stands_in("Tricep Extension - Overhead dumbbell", tri) and Missions.stands_in("Tricep Kickback - Dumbbell", tri) and not Missions.stands_in("Bicep Curl - Dumbbell", tri) and not Missions.stands_in("Chest Fly - Cable", tri), "overhead triceps extensions stand in for the pushdown; curls and a planned fly do not")
	ok(not Missions.stands_in("Tricep Extension - Cable", tri) and Missions.move_of("Tricep Extension - Cable") == "Tricep Pushdown", "an extension on the cable does not stand in for it: it is the pushdown itself")
	var sho = Missions.same_of("Lateral Raise - Cable", sp)
	ok(sp.new != null and Missions.kind_of(str(sp.new.name)) == "push" and (Missions.part_of(str(sp.new.name)) != "shoulders" or not Missions.stands_in(str(sp.new.name), sho)), "today's new movement counts for itself, not for a planned row", [sp.new.name, sp.moves])
	var ext_day = split_log + [lift(sat, {"Tricep Extension - Cable": [[12, 20]]})]
	ok(Missions.beat_any(ext_day, ["Tricep Pushdown - Rope"], "Tricep Pushdown", sat, tri) and Missions.beat_any(ext_day, ["Tricep Pushdown - Rope"], "Tricep Pushdown", sat), "done by a cable extension, with or without the stand-in rule (the same movement)")
	var over_day = split_log + [lift(sat, {"Tricep Extension - Overhead dumbbell": [[12, 20]]})]
	ok(Missions.beat_any(over_day, ["Tricep Pushdown - Rope"], "Tricep Pushdown", sat, tri) and not Missions.beat_any(over_day, ["Tricep Pushdown - Rope"], "Tricep Pushdown", sat), "done by overhead extensions only with the stand-in rule")

	# --- two names of the library, one exercise: planned once -----------------------------------------
	ok(Missions.move_of("Tricep Extension - Cable") == "Tricep Pushdown" and Missions.move_of("Tricep Extension - Gym cable") == "Tricep Pushdown" and Missions.move_of("Tricep Extension - Rope") == "Tricep Pushdown" and Missions.move_of("Tricep Extension - Single arm cable") == "Tricep Pushdown", "a tricep extension on a cable is a pushdown")
	ok(Missions.move_of("Tricep Extension - Overhead cable") == "Tricep Extension" and Missions.move_of("Tricep Extension - Overhead dumbbell") == "Tricep Extension" and Missions.move_of("Tricep Extension - Lying EZ bar") == "Tricep Extension" and Missions.move_of("Tricep Extension - Dumbbell") == "Tricep Extension" and Missions.move_of("Tricep Extension") == "Tricep Extension", "an overhead, a lying or a dumbbell extension is its own exercise")
	ok(Missions.move_of("Tricep Pushdown - Gym rope") == "Tricep Pushdown" and Missions.move_of("Bench Press - Barbell") == "Bench Press" and Missions.move_of("Pull-up") == "Pull-up" and Missions.move_of("Hip Flexor Thing") == "Hip Flexor Thing", "any other lift is its own movement (a barbell is no bar attachment)")
	var tri_push = func(tri_name: String): return {"Bench Press - Barbell": [[5, 80], [5, 80], [5, 80]], tri_name: [[10, 30], [10, 30], [10, 30]]}
	var one_log = [
		lift("2026-11-12", tri_push.call("Tricep Pushdown - Gym rope")), lift("2026-11-13", {"Squat - Barbell": [[5, 100]]}), lift("2026-11-14", {"Bent Over Row - Barbell": [[8, 60]]}),
		lift("2026-11-15", tri_push.call("Tricep Extension - Cable")), lift("2026-11-16", {"Squat - Barbell": [[5, 100]]}), lift("2026-11-17", {"Bent Over Row - Barbell": [[8, 60]]}),
		lift("2026-11-18", tri_push.call("Tricep Pushdown - Gym rope")), lift("2026-11-19", {"Squat - Barbell": [[5, 100]]}), lift("2026-11-20", {"Bent Over Row - Barbell": [[8, 60]]}),
	]
	var one = Missions.day_plan(one_log, sat, {}, {"split": "pull_push_legs"})
	var one_tri = one.lifts.filter(func(l): return Missions.part_of(str(l.name)) == "triceps")
	ok(one.kind == "push" and one_tri.size() == 1 and str(one_tri[0].name) == "Tricep Pushdown - Gym rope", "logged under both names on different days: the push day plans it once, as it was done last", names(one.lifts))
	ok(names(one_tri[0].options).has("Tricep Extension - Cable") and names(one_tri[0].options)[0] == "Tricep Pushdown - Gym rope", "with the other name as one of its ways", names(one_tri[0].options))
	var swapped = one_log.duplicate()
	swapped[6] = lift("2026-11-18", tri_push.call("Tricep Extension - Cable"))
	var two = Missions.day_plan(swapped, sat, {}, {"split": "pull_push_legs"})
	var two_tri = two.lifts.filter(func(l): return Missions.part_of(str(l.name)) == "triceps")
	ok(two_tri.size() == 1 and str(two_tri[0].name) == "Tricep Extension - Cable" and names(two_tri[0].options).has("Tricep Pushdown - Gym rope"), "the other way round too", names(two.lifts))
	ok(Missions.lift_done(one_tri[0], one, one_log + [lift(sat, {"Tricep Extension - Cable": [[10, 35]]})], sat) == "Tricep Extension - Cable" and Missions.lift_done(one_tri[0], one, one_log + [lift(sat, {"Bicep Curl - Dumbbell": [[10, 10]]})], sat) == "", "and either name ticks its row")
	var one_rows = Missions.picks(one, one_log, sat).filter(func(r): return Missions.part_of(str(r.name)) == "triceps")
	ok(one_rows.size() == 1 and one_rows[0].ways.map(func(w): return str(w.name)).has("Tricep Extension - Cable"), "the Log tab's list has it once as well", one_rows)
	ok(Missions.done_of(ext_day, ["Tricep Pushdown - Rope"], sat, "Tricep Pushdown", tri) == "Tricep Extension - Cable", "the Today row shows what stood in")

	# --- perfect day: every box of the Today card --------------------------------------------------
	var pboxes = Missions.day_boxes(sp, split_log, sat)
	ok(pboxes.size() >= 4 and not pboxes.any(func(b): return bool(b.done)), "the Today card's boxes, none ticked before the day starts", pboxes)
	var pday = Missions.daily(sat, {"sessions": split_log, "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs"}, "reading": []}, state, [])
	var pm = find(pday, ":perfect")
	ok(pm != null and int(pm.target) == pboxes.size() and int(pm.progress) == 0 and int(pm.xp) == Missions.PERFECT_XP and pm.get("perfect", false), "a Perfect day mission, one step per box", pm)
	var all_done = {}
	for l in sp.lifts:
		all_done[str(l.name)] = [[13, 20]]
	all_done[str(sp.new.name)] = [[10, 10]]
	var perfect_log = split_log + [lift(sat, all_done)]
	var pm2 = find(Missions.daily(sat, {"sessions": perfect_log, "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs"}, "reading": []}, state, []), ":perfect")
	ok(pm2.done and int(pm2.progress) == int(pm2.target), "every planned lift and the new movement done: a perfect day", pm2)
	var half_log = split_log + [lift(sat, {str(sp.lifts[0].name): [[13, 20]]})]
	var pm3 = find(Missions.daily(sat, {"sessions": half_log, "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs"}, "reading": []}, state, []), ":perfect")
	ok(not pm3.done and int(pm3.progress) == 1, "one box ticked: not yet", pm3)

	# --- the evening check -------------------------------------------------------------------------
	var ev0 = Missions.evening_text(sp, split_log, sat, false)
	ok(ev0.begins_with("Still open today:") and ev0.contains("- Chest Fly (cable)") and ev0.contains("- Try: ") and ev0.ends_with("0 of %d boxes ticked." % pboxes.size()), "the evening: what is still open, and the count", ev0)
	var ev1 = Missions.evening_text(sp, half_log, sat, false)
	ok(not ev1.contains("- %s" % Missions.short_name(str(sp.lifts[0].name))) and ev1.ends_with("1 of %d boxes ticked." % pboxes.size()), "a lift done drops out", ev1)
	ok(Missions.evening_text(sp, perfect_log, sat, false) == "Every box ticked today. Open your chest in the game!" and Missions.evening_text(sp, perfect_log, sat, true) == "", "all done: the chest, then nothing to say")
	ok(Missions.evening_text(Missions.day_plan([], sat, {}), [], sat, false) == "", "no plan: nothing to say")

	# --- last week's recap to the phone: once a week ------------------------------------------------
	var rs = {"morning": {"on": true, "topic": "t"}}
	ok(MorningAlert.recap_due(rs, split_log, sat) == "2026-11-09", "a new week: last week's recap is due", MorningAlert.recap_due(rs, split_log, sat))
	ok(MorningAlert.recap_due({"morning": {"on": true, "topic": "t", "recapSent": "2026-11-09"}}, split_log, sat) == "" and MorningAlert.recap_due({"morning": {"on": false, "topic": "t"}}, split_log, sat) == ""
		and MorningAlert.recap_due({"morning": {"on": true, "topic": "t", "recap": false}}, split_log, sat) == "" and MorningAlert.recap_due(rs, [], sat) == "", "sent already, off, switched off or an empty week: nothing")

	# --- how you feel: a mark, and nothing changes with it ------------------------------------------------
	var base_set = {"weightUnit": "kg", "split": "pull_push_legs"}
	var shape = func(list: Array): return list.map(func(m): return [m.id, m.title, m.desc, m.get("aim"), m.target, m.xp])
	var plain_day = shape.call(Missions.daily(sat, {"sessions": split_log, "pt": {}, "settings": base_set, "reading": []}, state, []))
	for f in [1, 2, 3]:
		var marked = base_set.duplicate()
		marked["feels"] = {sat: f}
		ok(shape.call(Missions.daily(sat, {"sessions": split_log, "pt": {}, "settings": marked, "reading": []}, state, [])) == plain_day, "marking how you feel (%d) changes no mission, aim or title" % f)
		ok(Missions.feel_of(marked, sat) == f, "and the mark is kept (%d)" % f)
	var old_week = base_set.duplicate()
	old_week["deloadUntil"] = "2026-11-25"
	old_week["feels"] = {sat: 1, "2026-11-20": 1}
	ok(shape.call(Missions.daily(sat, {"sessions": split_log, "pt": {}, "settings": old_week, "reading": []}, state, [])) == plain_day and plain_day.any(func(m): return str(m[1]).begins_with("Beat it: ")) and not plain_day.any(func(m): return str(m[1]).begins_with("Easy day")), "a lighter week set before, tired two days running: still the same goals")
	ok(Missions.feel_of({}, sat) == 0, "no mark: nothing")

	# --- split combos ----------------------------------------------------------------------------------
	var cb = Missions.combo(split_log, "2026-11-20", cycle)
	ok(cb.kinds == ["push", "pull", "push", "pull"] and int(cb.now) == 1 and int(cb.best) == 2, "this week: push, pull (not next: 1), push (next after pull: 2), pull (1)", cb)
	var legs_sun = {"Squat - Barbell": [[5, 100]], "Calf Raise": [[15, 40]]}
	var cb2 = Missions.combo(split_log + [lift(sat, push), lift("2026-11-22", legs_sun)], "2026-11-22", cycle)
	ok(int(cb2.now) == 3 and int(cb2.best) == 3, "pull, push, legs: a combo of 3", cb2)
	ok(int(Missions.combo(split_log, "2026-11-20", []).now) == 0, "no split, no combo")
	var wcombo = find(Missions.weekly(Dates.week_key(sat), "2026-11-22", {"sessions": split_log + [lift(sat, push), lift("2026-11-22", legs_sun)], "pt": {}, "settings": {"split": "pull_push_legs"}, "reading": []}, state, []), ":combo")
	ok(wcombo != null and wcombo.done and int(wcombo.target) == 3, "the weekly Combo week mission", wcombo)

	# --- the ways to do a lift: the player's own variations ------------------------------------------
	# Chest fly on the home cable (Mon) and the gym cable (Thu): one chest fly to plan, two ways.
	var vpull = {"Bent Over Row - Dumbbell": [[10, 30]], "Lat Pulldown - Single arm home": [[12, 36]]}
	var vlog = [
		lift("2026-09-30", {"Push-up": [[20, 0]]}),
		lift("2026-11-14", {"Squat - Barbell": [[5, 100]]}),
		lift("2026-11-16", {"Chest Fly - Home cable": [[12, 15], [12, 15]], "Lateral Raise - Dumbbell": [[12, 8], [12, 8]]}),
		lift("2026-11-17", vpull),
		lift("2026-11-19", {"Chest Fly - Gym cable": [[10, 25], [10, 25]], "Lateral Raise - Gym cable": [[12, 5]]}),
		lift("2026-11-20", vpull),
	]
	var vp = Missions.day_plan(vlog, sat, {}, {"split": "pull_push_legs"})
	var vn = names(vp.lifts)
	ok(vp.kind == "push" and vn.has("Chest Fly - Gym cable") and not vn.has("Chest Fly - Home cable") and vn.has("Lateral Raise - Gym cable") and not vn.has("Lateral Raise - Dumbbell"), "one row per movement: the variation done last", vn)
	var vfly = vp.lifts.filter(func(l): return l.name == "Chest Fly - Gym cable")[0]
	ok(vfly.variations == ["Chest Fly - Gym cable", "Chest Fly - Home cable"], "its variations, the latest first", vfly.variations)
	var vfo = names(vfly.options)
	ok(vfo == ["Chest Fly - Gym cable", "Chest Fly - Home cable", "Pullover - Dumbbell"], "the ways: each variation as done, then a movement that does the same job (a pullover, not the push-ups done once)", vfo)
	ok(is_equal_approx(float(vfly.options[1].last[0].weightKg), 15.0) and is_equal_approx(float(vfly.options[0].last[0].weightKg), 25.0) and not bool(vfly.options[0].new) and not bool(vfly.options[1].new) and bool(vfly.options[2].new) and vfly.options[2].last.is_empty(), "each way done before with its own last time (home 15, gym 25); the one never done is new and has none", vfly.options)
	var vlat = names(vp.lifts.filter(func(l): return l.name == "Lateral Raise - Gym cable")[0].options)
	ok(vlat[0] == "Lateral Raise - Gym cable" and vlat[1] == "Lateral Raise - Dumbbell", "lateral raises: the gym cable or dumbbells, as done", vlat)
	var vdata = {"sessions": vlog, "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs"}, "reading": []}
	var vday = Missions.daily(sat, vdata, state, [])
	var vfm = find(vday, ":beat:chest fly - gym cable")
	ok(vfm != null and vfm.title == "Beat it: Chest Fly" and vfm.lift == "Chest Fly - Gym cable" and str(vfm.desc).begins_with("Last time") and str(vfm.desc).contains("Or: home cable, Pullover (dumbbell)."), "the mission: last time on the gym cable, or the home cable, or a pullover", vfm.desc if vfm != null else null)
	var beat_with = func(exs: Dictionary) -> Dictionary:
		var d = vdata.duplicate()
		d.sessions = vlog + [lift(sat, exs)]
		var m = find(Missions.daily(sat, d, state, []), ":beat:chest fly - gym cable")
		var lm2 = find(Missions.daily(sat, d, state, []), ":beat:lateral raise - gym cable")
		return {"fly": m.done, "lat": lm2.done if lm2 != null else null}
	ok(beat_with.call({"Chest Fly - Home cable": [[12, 17.5], [12, 15]]}).fly, "more than last time on the home cable beats it (lighter than the gym cable, which has its own aim)")
	ok(beat_with.call({"Chest Fly - Machine": [[10, 30]]}).fly, "a variation written the first time counts")
	ok(beat_with.call({"Pullover - Dumbbell": [[12, 15]]}).fly, "a movement standing in for it counts too")
	ok(not beat_with.call({"Push-up": [[22, 0]]}).fly, "a press is not a fly: push-ups do not stand in for it")
	ok(not beat_with.call({"Chest Fly - Home cable": [[10, 15]]}).fly and not beat_with.call({"Lateral Raise - Dumbbell": [[10, 8]]}).lat, "less than last time on the same way does not")
	var vtext = Missions.morning_text(vp, vday, "kg")
	ok(vtext.contains("Chest Fly (gym cable): ") and vtext.contains("  or Chest Fly (home cable): ") and not vtext.contains("or Pullover") and vtext.contains("  or Lateral Raise (dumbbell): "), "the morning message: every way done before, each with its own aim (the new ones are on the card)", vtext)

	# --- options whatever the equipment: the other place, other gear, a movement of the family ------
	var hist = LiftLibrary.stats(vlog)
	var opt_names = func(lift_name: String, avoid: Array) -> Array:
		return Missions.options_for({"name": lift_name, "last": {"date": "", "sets": []}}, hist, avoid).map(func(o): return str(o.name))
	ok(opt_names.call("Lat Pulldown - Single arm home", []) == ["Lat Pulldown - Single arm home", "Lat Pulldown - Single arm gym", "Pull-up", "Chin-up"], "a lift done at home: the same at the gym, then a pull-up and a chin-up", opt_names.call("Lat Pulldown - Single arm home", []))
	ok(opt_names.call("Lat Pulldown - Single arm home", [Xp.normalize_exercise("Pull-up")]) == ["Lat Pulldown - Single arm home", "Lat Pulldown - Single arm gym", "Chin-up", "Straight-Arm Pulldown"], "a movement already in the plan is not offered as a way")
	var glog = vlog + [lift("2026-11-18", {"Sit-up - GHD": [[8, 0]], "Shrug - Barbell": [[10, 60]], "Hip Flexor Thing": [[10, 0]]})]
	var ghist = LiftLibrary.stats(glog)
	var gopts = Missions.options_for({"name": "Sit-up - GHD", "last": {"date": "", "sets": []}}, ghist)
	ok(gopts.map(func(o): return str(o.name)) == ["Sit-up - GHD", "Sit-up", "Crunch", "Leg Raise"] and not bool(gopts[0].new) and gopts.slice(1).all(func(o): return bool(o.new) and o.last.is_empty()), "a GHD sit-up (gym only): a plain sit-up, a crunch, a leg raise", gopts.map(func(o): return str(o.name)))
	ok(Missions.way_word(gopts[1], "Sit-up") == "bodyweight" and Missions.way_word(gopts[2], "Sit-up") == "Crunch" and Missions.way_word(vfly.options[1], "Chest Fly") == "home cable", "a way in a word: the equipment of the plain one, the name of another movement, the variation")
	var lat_opts = Missions.options_for({"name": "Lat Pulldown - Single arm home", "last": {"date": "", "sets": []}}, ghist)
	ok(not lat_opts.any(func(o): return str(o.move) == "Shrug"), "a shrug done before is NOT a way to do a lat pulldown", lat_opts.map(func(o): return str(o.name)))
	ok(Missions.options_for({"name": "Hip Flexor Thing", "last": {"date": "", "sets": []}}, ghist).map(func(o): return str(o.name)) == ["Hip Flexor Thing"], "a movement of the player's own has only itself")
	ok(Missions.other_place("Tricep Pushdown - Gym rope") == "Tricep Pushdown - Home rope" and Missions.other_place("Chest Fly - Home cable") == "Chest Fly - Gym cable" and Missions.other_place("Squat - Barbell") == "" and Missions.other_place("Hip Flexor Thing - Home") == "", "the same lift at the other place, when its name says a place")
	ok(Missions.other_gear(LiftNames.movement("Bicep Curl"), "Bicep Curl - Reclined", []) == "Bicep Curl - Barbell" and Missions.other_gear(LiftNames.movement("Sit-up"), "Sit-up", [Xp.normalize_exercise("Sit-up")]) == "Sit-up - GHD", "a variation on other equipment", [Missions.other_gear(LiftNames.movement("Bicep Curl"), "Bicep Curl - Reclined", []), Missions.other_gear(LiftNames.movement("Sit-up"), "Sit-up", [Xp.normalize_exercise("Sit-up")])])
	ok(Missions.family_of("Lat Pulldown") == ["Pull-up", "Chin-up", "Straight-Arm Pulldown"] and Missions.family_of("Calf Raise").is_empty() and Missions.family_of("Hip Flexor Thing").is_empty(), "families of movements that do the same job")
	var all_fam = []
	var fam_bad = []
	for fam in Missions.FAMILIES:
		for m in fam:
			if LiftNames.movement(str(m)) == null or all_fam.has(str(m)):
				fam_bad.append(str(m))
			all_fam.append(str(m))
	ok(fam_bad.is_empty() and all_fam.size() > 60, "every family member is a library movement, in one family only", fam_bad)
	var gsame = Missions.same_of("Lat Pulldown - Single arm home", vp)
	ok(Missions.stands_in("Pull-up", gsame) and Missions.stands_in("Chin-up - Weighted", gsame) and not Missions.stands_in("Shrug - Barbell", gsame) and not Missions.stands_in("Seated Row", gsame), "a pull-up stands in for a lat pulldown; a shrug or a row does not")
	var own_same = Missions.same_of("Hip Flexor Thing", vp)
	ok(not bool(own_same.known) and own_same.family.is_empty(), "a movement of the player's own has no family (the body part decides, as before)")

	# --- a fuller day: PT does not take a strength place, a lift done once comes back on its day ---
	var big_pull = {"Bent Over Row - Barbell": [[8, 60]], "Lat Pulldown": [[10, 50]], "Bicep Curl - Dumbbell": [[10, 12]], "Seated Row": [[10, 40]], "Hammer Curl - Dumbbell": [[10, 12]], "Chin-up": [[6, 0]], "Neck 4 Way": [[20, 4]], "Wrist Curl": [[15, 8]]}
	var blog = [lift("2026-11-12", big_pull), lift("2026-11-13", {"Chest Fly - Cable": [[12, 15]]}), lift("2026-11-14", {"Squat - Barbell": [[5, 100]]}),
		lift("2026-11-15", big_pull), lift("2026-11-16", {"Chest Fly - Cable": [[12, 15]]}), lift("2026-11-17", {"Squat - Barbell": [[5, 100]]}),
		lift("2026-11-18", big_pull), lift("2026-11-19", {"Chest Fly - Cable": [[12, 15]]}), lift("2026-11-20", {"Squat - Barbell": [[5, 100]]})]
	var bmarks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 7}, "wrist curl": {"name": "Wrist Curl", "perWeek": 7}}
	var bp = Missions.day_plan(blog, sat, bmarks, {"split": "pull_push_legs"})
	var strong_lifts = bp.lifts.filter(func(l): return not bool(l.pt))
	ok(bp.kind == "pull" and strong_lifts.size() == Missions.PLAN_LIFTS and Missions.PLAN_LIFTS == 6, "a pull day with six strength lifts: all six are planned, physical therapy takes none of their places", names(bp.lifts))
	ok(not bp.lifts.any(func(l): return bool(l.pt)) and bp.pt.map(func(r): return str(r.name)).has("Neck 4 Way") and bp.pt.map(func(r): return str(r.name)).has("Wrist Curl"), "no PT exercise among the day's lifts: they are the PT row's (plan.pt)", [names(bp.lifts), bp.pt.map(func(r): return str(r.name))])
	var bday = Missions.daily(sat, {"sessions": blog, "pt": bmarks, "settings": {"split": "pull_push_legs"}, "reading": []}, state, [])
	var bpm = find(bday, ":pt")
	ok(bpm != null and int(bpm.target) == 2 and str(bpm.desc).contains("Neck 4 Way") and bday.filter(func(m): return str(m.get("lift", "")) != "" and Pt.is_pt(bmarks, str(m.lift))).is_empty(), "one PT mission for all of them; no mission names a single PT exercise", bday.map(func(m): return str(m.id)))
	ok(Missions.day_boxes(bp, blog, sat).filter(func(b): return str(b.what) == "pt").size() == 1 and not Missions.day_boxes(bp, blog, sat).any(func(b): return Pt.is_pt(bmarks, str(b.what))), "one PT box on the Today card", Missions.day_boxes(bp, blog, sat))
	ok(not Missions.morning_text(bp, bday, "kg").contains("Neck 4 Way:") and Missions.morning_text(bp, bday, "kg").contains("PT: "), "the morning message: one PT line, no PT exercise as a lift", Missions.morning_text(bp, bday, "kg"))
	var once = blog + [lift("2026-11-18", {"Shrug - Barbell": [[10, 60]]})]
	ok(names(Missions.likely_lifts(once, sat, {}, "pull")).has("Shrug - Barbell"), "a lift done once on the last pull day is planned for the next one")
	ok(not names(Missions.likely_lifts(blog + [lift("2026-11-20", {"Shrug - Barbell": [[10, 60]]})], sat, {}, "pull")).has("Shrug - Barbell") and not names(Missions.likely_lifts(once, sat, {}, "")).has("Shrug - Barbell"), "not the day after it was done, and not without a split (three days after a first time is too soon to call)")

	# --- the plan as a list to pick a workout from (the Log tab's "From today's plan") --------------
	var vpk = Missions.picks(vp, vlog, sat)
	var vfr = vpk.filter(func(r): return str(r.name) == "Chest Fly - Gym cable")
	ok(vfr.size() == 1 and str(vfr[0].kind) == "lift" and str(vfr[0].move) == "Chest Fly" and str(vfr[0].variation) == "Gym cable" and not bool(vfr[0].new) and not bool(vfr[0].pt) and str(vfr[0].done) == "" and is_equal_approx(float(vfr[0].last[0].weightKg), 25.0) and vfr[0].lift == vfly, "a row per planned lift, named as it was done last, with those sets and the lift of the plan", vfr)
	ok(vfr[0].ways.map(func(w): return str(w.name)) == ["Chest Fly - Home cable", "Pullover - Dumbbell"] and vfr[0].ways.map(func(w): return str(w.word)) == ["Home cable", "Pullover (dumbbell)"] and vfr[0].ways.map(func(w): return bool(w.new)) == [false, true], "its other ways: a variation as it is written, another movement by its name, one never done marked new", vfr[0].ways)
	ok(vpk.slice(0, vp.lifts.size()).map(func(r): return str(r.name)) == names(vp.lifts), "the lifts in the order of the Today card", vpk.map(func(r): return str(r.name)))
	var vnew = vpk.filter(func(r): return str(r.kind) == "new")
	ok(vp.new != null and vnew.size() == 1 and vpk.find(vnew[0]) == vp.lifts.size() and str(vnew[0].name) == str(vp.new.name) and bool(vnew[0].new) and vnew[0].lift == null and vnew[0].last.is_empty() and vnew[0].ways.map(func(w): return str(w.name)) == vp.new.alts.map(func(a): return str(a.name)) and vnew[0].ways.all(func(w): return bool(w.new)), "then the movement to try, with the others that count as chips", vnew)
	var uniq = {}
	for r in vpk:
		uniq[Xp.normalize_exercise(str(r.name))] = true
	ok(uniq.size() == vpk.size() and vpk.all(func(r): return r.has("kind") and r.has("ways") and r.has("done") and r.has("sides") and r.has("why")), "no lift twice, every row whole")
	# Done today, one way or another: the row names the lift that did it.
	var vdone = Missions.picks(vp, vlog + [lift(sat, {"Chest Fly - Home cable": [[12, 15]], "Lateral Raise - Gym cable": [[12, 5]]})], sat)
	var done_of = {}
	for r in vdone:
		done_of[str(r.name)] = str(r.done)
	ok(done_of["Chest Fly - Gym cable"] == "Chest Fly - Home cable" and done_of["Lateral Raise - Gym cable"] == "Lateral Raise - Gym cable" and str(vdone.filter(func(r): return str(r.kind) == "new")[0].done) == "", "done today: the fly by its other way, the raise as planned, the new movement not yet", done_of)
	ok(Missions.picks(vp, vlog + [lift(sat, {"Chest Fly - Home cable": []})], sat).all(func(r): return str(r.done) == ""), "a lift added and left empty is not done")
	# Physical therapy is not in the list: it is its one goal (plan.pt, the PT row and mission).
	var bpk = Missions.picks(bp, blog, sat)
	ok(not bpk.any(func(r): return bool(r.pt) or str(r.kind) == "pt") and not bp.pt.is_empty(), "no row per physical therapy exercise in the list, though PT is still needed", bpk.map(func(r): return "%s/%s" % [r.name, r.kind]))
	ok(bpk.filter(func(r): return str(r.kind) == "lift").size() == Missions.PLAN_LIFTS, "the six strength lifts")
	ok(Missions.picks({"lifts": [], "new": null, "pt": [{"name": "Neck 4 Way"}]}, blog, sat).is_empty(), "a plan of only PT gives no list")
	ok(Missions.picks({}, [], sat).is_empty() and Missions.picks(Missions.day_plan([], sat, {}), [], sat).is_empty(), "no plan, no rows")
	ok(Missions.way_label(vfly.options[1], "Chest Fly") == "Home cable" and Missions.way_label(gopts[1], "Sit-up") == "bodyweight" and Missions.way_label(gopts[2], "Sit-up") == "Crunch", "a way's label: the variation as written, else the word for it")

	# --- the morning message --------------------------------------------------------------------
	var text = Missions.morning_text(plan, day, "kg")
	ok(text.begins_with("Probably a back day.") and text.contains("Lat Pulldown (single arm): ") and text.contains("Try: ") and text.contains("PT: Neck 4 Way"), "the morning message", text)
	ok(Missions.morning_text(Missions.day_plan([], TODAY, {}), [], "kg") == "No pattern for today yet: anything counts.", "nothing to say: one line")
	# The workout replay's poses.
	var poses = [Missions.pose_of("Bench Press - Barbell"), Missions.pose_of("Pull-up"), Missions.pose_of("Squat - Barbell"), Missions.pose_of("Bicep Curl - Dumbbell"), Missions.pose_of("Lateral Raise - Dumbbell"), Missions.pose_of("Plank")]
	ok(poses == ["press", "pull", "squat", "curl", "press", "flex"], "replay poses: press, pull, squat, curl", poses)
	print("MISSIONS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
