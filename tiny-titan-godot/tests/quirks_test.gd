extends SceneTree
## Unit test for the chase trophies outside climbing (Derive._deal_quirks +
## the "quirk_*" entries in game/achievements.gd).
##   godot --headless --path . --script res://tests/quirks_test.gd
## Prints QUIRKS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func base(disc: String, date: String) -> Dictionary:
	_n += 1
	return {"id": "s%d" % _n, "discipline": disc, "date": date, "createdAt": 1700000000000 + _n * 3600000, "source": "manual"}


## A lifting session from {name: [[reps, kg], ...]}.
func lift(date: String, exercises: Dictionary) -> Dictionary:
	var s = base("lift", date)
	var exs = []
	for name in exercises:
		var sets = []
		for st in exercises[name]:
			sets.append({"reps": st[0], "weightKg": st[1]})
		exs.append({"name": name, "sets": sets})
	s["exercises"] = exs
	return s


func cardio(disc: String, date: String, m: float, sec: int = 0) -> Dictionary:
	var s = base(disc, date)
	s["distanceM"] = m
	s["elevationM"] = 0
	if sec > 0:
		s["durationSec"] = sec
	return s


func derive(sessions: Array) -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": [], "body": [], "weeklyGoal": 3, "today": "2026-11-15"})


func has(s: Dictionary, id: String) -> bool:
	return s.achievements.has(id)


func _init() -> void:
	# Five by five, and the near misses.
	var s1 = derive([lift("2026-10-01", {"Squat": [[5, 80], [5, 80], [5, 80], [5, 80], [5, 80]]})])
	ok(has(s1, "quirk_five_by_five"), "5 × 5 at 80 kg", s1.quirks)
	var s2 = derive([lift("2026-10-01", {"Squat": [[5, 80], [5, 80], [5, 80], [5, 80], [5, 80], [5, 80]]})])
	ok(not has(s2, "quirk_five_by_five"), "6 × 5 is not five by five")
	var s3 = derive([lift("2026-10-01", {"Squat": [[5, 80], [5, 80], [5, 80], [5, 80], [4, 80]]})])
	ok(not has(s3, "quirk_five_by_five"), "5, 5, 5, 5, 4 is not five by five")

	# Ladder and pyramid.
	var s4 = derive([lift("2026-10-02", {"Bench": [[5, 60], [5, 70], [5, 80], [5, 90], [5, 100]]})])
	ok(int(s4.quirks.ladderSets) == 5 and has(s4, "quirk_ladder") and not has(s4, "quirk_pyramid"), "five heavier sets is a ladder, not a pyramid", s4.quirks)
	var s5 = derive([lift("2026-10-02", {"Bench": [[5, 60], [5, 80], [5, 100], [8, 80], [10, 60]]})])
	ok(has(s5, "quirk_pyramid") and int(s5.quirks.ladderSets) == 3, "60 80 100 80 60 is a pyramid", s5.quirks)
	var s6 = derive([lift("2026-10-02", {"Bench": [[5, 60], [5, 80], [5, 100], [8, 80]]})])
	ok(not has(s6, "quirk_pyramid"), "one step down is not a pyramid")

	# Ton up, century set, baker's dozen, sevens, big three.
	var s7 = derive([lift("2026-10-03", {"Deadlift": [[10, 100]], "Push-up": [[100, 0]], "Curl": [[13, 10]]})])
	ok(has(s7, "quirk_ton_set") and has(s7, "quirk_century_set") and has(s7, "quirk_bakers_dozen"), "10 × 100 kg, 100 push-ups, a set of 13", s7.quirks)
	var s8 = derive([lift("2026-10-03", {"Row": [[7, 40], [7, 40], [7, 40], [7, 40], [7, 40], [7, 40], [7, 40]]})])
	ok(has(s8, "quirk_seven_by_seven"), "seven sets of seven")
	var s9 = derive([lift("2026-10-04", {"Back Squat": [[5, 100]], "Bench Press": [[5, 80]], "Deadlift": [[5, 120]]})])
	ok(has(s9, "quirk_big_three"), "squat, bench, deadlift in one session")
	var s10 = derive([lift("2026-10-04", {"Back Squat": [[5, 100]], "Bench Press": [[5, 80]]})])
	ok(not has(s10, "quirk_big_three"), "two of the big three is not enough")

	# Running: exact 5 km, metronome, streak, marathon month.
	var s11 = derive([cardio("run", "2026-10-05", 5000.0, 1500)])
	ok(has(s11, "quirk_run_exact_5") and has(s11, "quirk_run_metronome"), "5.00 km in 25:00", s11.quirks)
	var s12 = derive([cardio("run", "2026-10-05", 5020.0, 1500)])
	ok(not has(s12, "quirk_run_exact_5") and not has(s12, "quirk_run_metronome"), "5.02 km is neither")
	var week = []
	for d in range(6, 13):
		week.append(cardio("run", "2026-10-%02d" % d, 6500.0))
	var s13 = derive(week)
	ok(int(s13.quirks.runDayStreakBest) == 7 and has(s13, "quirk_run_streak") and has(s13, "quirk_run_month"), "seven days running: streak week and 45.5 km in the month", s13.quirks)
	var gap = [cardio("run", "2026-10-06", 5000.0), cardio("run", "2026-10-07", 5000.0), cardio("run", "2026-10-09", 5000.0)]
	ok(int(derive(gap).quirks.runDayStreakBest) == 2, "a missed day resets the run streak")
	var two_same_day = [cardio("run", "2026-10-06", 5000.0), cardio("run", "2026-10-06", 5000.0)]
	ok(int(derive(two_same_day).quirks.runDayStreakBest) == 1, "two runs on one day are one streak day")

	# Riding: exact 50 km, commuter week, big month.
	var s14 = derive([cardio("ride", "2026-10-05", 50000.0)])
	ok(has(s14, "quirk_ride_exact_50"), "50.0 km ride")
	var rides = []
	for d in [5, 6, 7, 8, 9]:  # Mon-Fri of one week
		rides.append(cardio("ride", "2026-10-%02d" % d, 20000.0))
	var s15 = derive(rides)
	ok(int(s15.quirks.bestRideWeekDays) == 5 and has(s15, "quirk_ride_commuter") and not has(s15, "quirk_ride_month"), "five ride days in one week; 100 km is not a big month", s15.quirks)
	var s16 = derive([cardio("ride", "2026-10-05", 150000.0), cardio("ride", "2026-10-19", 150000.0)])
	ok(has(s16, "quirk_ride_month"), "300 km in one month")
	var s17 = derive([cardio("ride", "2026-10-31", 150000.0), cardio("ride", "2026-11-01", 150000.0)])
	ok(not has(s17, "quirk_ride_month"), "300 km across two months is not")

	# General: double header and the calendar.
	var s18 = derive([cardio("run", "2026-10-05", 5000.0), lift("2026-10-05", {"Squat": [[5, 80]]})])
	ok(has(s18, "quirk_double_header"), "a run and a lift on one day")
	var s19 = derive([cardio("run", "2026-10-05", 5000.0), cardio("run", "2026-10-05", 5000.0)])
	ok(not has(s19, "quirk_double_header"), "two runs on one day are not a double header")
	var s20 = derive([lift("2026-11-13", {"Squat": [[5, 80]]}), lift("2028-02-29", {"Squat": [[5, 80]]}), lift("2027-01-01", {"Squat": [[5, 80]]})])
	ok(has(s20, "quirk_friday_13") and has(s20, "quirk_leap_day") and has(s20, "quirk_new_year"), "Friday 13 Nov 2026, 29 Feb 2028, 1 Jan 2027", s20.quirks)
	var s21 = derive([lift("2026-10-13", {"Squat": [[5, 80]]})])
	ok(not has(s21, "quirk_friday_13"), "Tuesday the 13th does not count")

	ok(Achievements.all().size() == 160, "160 trophies in the catalog", Achievements.all().size())
	print("QUIRKS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
