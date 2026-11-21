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

	# --- the morning message --------------------------------------------------------------------
	var text = Missions.morning_text(plan, day, "kg")
	ok(text.begins_with("Probably a back day.") and text.contains("Lat Pulldown (single arm): ") and text.contains("Try: ") and text.contains("PT: Neck 4 Way"), "the morning message", text)
	ok(Missions.morning_text(Missions.day_plan([], TODAY, {}), [], "kg") == "No pattern for today yet: anything counts.", "nothing to say: one line")
	print("MISSIONS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
