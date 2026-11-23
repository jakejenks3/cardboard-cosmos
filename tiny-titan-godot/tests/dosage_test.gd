extends SceneTree
## Unit test for game/dosage.gd: the training dose as text.
##   godot --headless --path . --script res://tests/dosage_test.gd
## Prints DOSAGE: X/Y passed and exits with 1 when anything fails.
## With the environment variable DOSAGE_SAVE set to a save file (a copy kept
## OUTSIDE the project) and DOSAGE_TODAY to a date, it also prints that save's text.

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
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "exercises": exs}


func _init() -> void:
	var today = "2026-11-14"
	# Two weeks: bench twice a week, rows once, a PT lift, a stretch, climbs, a run, a vest walk.
	var sessions = []
	for d in ["2026-11-02", "2026-11-05", "2026-11-09", "2026-11-12"]:
		sessions.append(lift(d, {"Bench Press - Barbell": [[5, 80], [5, 80], [5, 80]], "Tricep Pushdown": [[12, 20], [12, 20]]}))
	for d in ["2026-11-03", "2026-11-10"]:
		sessions.append(lift(d, {"Bent Over Row - Barbell": [[8, 60], [8, 60], [8, 60], [8, 60]], "Neck 4 Way": [[20, 4.5]], "Hamstring Stretch": [[1, 0, 30], [1, 0, 30]], "Pull-up": [[6, 0]]}))
	sessions.append(lift("2026-11-14", {"Squat - Barbell": [[5, 100], [5, 100]], "Sky Reach": []}))
	for d in ["2026-11-01", "2026-11-08"]:
		sessions.append({"id": "c" + d, "discipline": "climb", "date": d, "durationSec": 5400, "climbs": [
			{"grade": 3, "result": "flash", "count": 2}, {"grade": 4, "result": "send", "count": 1}, {"grade": 5, "result": "attempt", "count": 4}]})
	sessions.append({"id": "r1", "discipline": "run", "date": "2026-11-07", "distanceM": 5000.0, "durationSec": 1500, "elevationM": 40.0})
	sessions.append({"id": "m1", "discipline": "misc", "kind": "vest_walk", "date": "2026-11-06", "distanceM": 4000.0, "loadKg": 10.0})
	var saved = {"sessions": sessions, "pt": {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}}, "settings": {"weightUnit": "kg", "distanceUnit": "km", "split": "pull_push_legs"},
		"body": [{"date": "2026-11-01", "weightKg": 82.0, "bodyFatPct": 19.0}, {"date": "2026-11-13", "weightKg": 81.0, "bodyFatPct": 18.5}, {"date": "2026-11-14"}]}

	var f = Dosage.figures(saved, today)
	ok(f.first == "2026-11-01" and int(f.span) == 14 and int(f.days) == 14 and is_equal_approx(float(f.weeks), 2.0), "the window is the whole two weeks", [f.first, f.span, f.days])
	ok(int(f.count.lift) == 7 and int(f.count.climb) == 2 and int(f.count.run) == 1 and int(f.count.misc) == 1 and f.trained.size() == 11, "sessions counted by kind, and the days trained", [f.count, f.trained.size()])
	ok(is_equal_approx(float(f.parts.chest.direct), 12.0) and int(f.parts.chest.reps) == 60 and is_equal_approx(float(f.parts.chest.vol), 4800.0), "chest: 12 direct sets, 60 reps, 4,800 kg in two weeks", f.parts.chest)
	ok(is_equal_approx(float(f.parts.triceps.direct), 8.0) and is_equal_approx(float(f.parts.triceps.indirect), 6.0), "triceps: 8 direct sets and half of the 12 bench sets", f.parts.triceps)
	ok(is_equal_approx(float(f.parts.back.direct), 10.0) and int(f.parts.back.last7) == 5, "back: rows and pull-ups; 5 of them in the last 7 days", f.parts.back)
	ok(not f.lifts.has("neck 4 way") and f.mobility.has("neck 4 way") and f.mobility.has("hamstring stretch") and not f.parts.has("neck"), "PT and stretches are kept apart from the lifts", [f.lifts.keys(), f.mobility.keys()])
	ok(not f.lifts.has("sky reach") and int(f.sets) == 32, "an exercise with no sets is not there; 32 working sets in all", f.sets)
	ok(f.bands == [14, 10, 8, 0], "sets by reps: 14 of 1-5, 10 of 6-10, 8 of 11-15", f.bands)
	var bench = f.lifts["bench press - barbell"]
	ok(bench.days.size() == 4 and is_equal_approx(float(bench.best.weightKg), 80.0) and int(bench.best.reps) == 5 and bench.first.date == "2026-11-02" and bench.last.date == "2026-11-12", "a lift: its days, first, latest and heaviest set", bench)

	var t = Dosage.text(saved, today)
	ok(t.contains("Log runs Nov 1, 2026 to Nov 14, 2026 (14 days)") and t.contains("a short log"), "the header says the period and that it is short", t.substr(0, 300))
	ok(t.contains("- Chest: 6 direct, 6 with indirect (last 7 days: 6 direct); on 2 days a week; about 5 reps a set; 2,400 kg moved a week."), "chest, per week", t)
	ok(t.contains("- Triceps: 4 direct, 7 with indirect"), "triceps with the bench's half sets", t)
	ok(t.contains("- Lifting: 3.5 sessions a week (4 in the last 7 days), as a pull / push / legs rotation.") and t.contains("- Climbing: 1 a week (1 in the last 7 days).") and t.contains("- Days with any training: 5.5 of 7 (5 in the last 7 days)."), "the week at a glance", t)
	ok(t.contains("- Bench Press - Barbell [chest]: 4 days; latest Nov 12: 3×5 @ 80 kg; first Nov 2: 3×5 @ 80 kg; heaviest 80 kg × 5."), "a lift's line", t)
	ok(t.contains("PHYSICAL THERAPY AND STRETCHES") and t.contains("- Hamstring Stretch: 2 days, 1 a week; latest Nov 10: ") and t.contains("- Neck 4 Way: 2 days"), "stretches apart, as holds", t)
	ok(t.contains("- 2 sessions, 1 a week, about 1h 30m each.") and t.contains("- Boulders by grade (sent / tried): V5 0/8, V4 2/2, V3 4/4.") and not t.contains("Roped routes by grade") and t.contains("Hardest boulder sent: V4."), "climbing: sessions, grades, the hardest send", t)
	ok(t.contains(" in 25:00 (5:00 /km), 40 m climbed."), "the run with its pace", t)
	ok(t.contains("- Nov 6: Weighted vest walk, ") and t.contains(" km carrying 10 kg."), "the vest walk", t)
	ok(t.contains("- Body weight 81 kg on Nov 13; 82 kg on Nov 1 (-1 kg over 12 days, 2 weigh-ins).") and t.contains("- Body fat 18.5% on Nov 13; 19% on Nov 1"), "the body: weight and fat, first and latest", t)
	ok(t.contains("- Sat, Nov 14: lift (sets: quads 2)") and t.contains("- Tue, Nov 10: lift (sets: back 5) + 2 PT / stretch exercises") and t.contains("- Sun, Nov 8: climb (7 tried, 3 sent, up to V4)"), "day by day", t)
	ok(t.contains("NOT IN THE LOG") and t.contains("WHAT I WANT FROM YOU") and not t.contains("1RM"), "what is missing and what to analyse; no estimates", "")
	ok(Dosage.part("Side Leg Lift - Bench") == "core" and Dosage.part("Bench Press - Barbell") == "chest", "a lift of the player's own named for the core is core")
	ok(Dosage.sets_words("Pull-Apart - Red band", [{"reps": 15, "weightKg": 0.0}, {"reps": 15, "weightKg": 0.0}], func(kg): return Fmt.fmt_weight(float(kg), "kg")) == "2×15 (a band, no weight)", "a band is not bodyweight")
	ok(Dosage.text({"sessions": []}, today).contains("Nothing is logged yet."), "an empty log says so")
	# A long log: the weekly figures are the last four weeks only.
	var long_log = sessions + [lift("2026-08-01", {"Bench Press - Barbell": [[5, 60], [5, 60]]})]
	var f2 = Dosage.figures({"sessions": long_log}, today)
	ok(int(f2.days) == Dosage.WINDOW_DAYS and f2.from == "2026-10-18" and is_equal_approx(float(f2.parts.chest.direct), 12.0) and f2.lifts["bench press - barbell"].first.date == "2026-08-01", "a long log: four weeks for the weekly figures, the whole log for a lift's first day", [f2.days, f2.from])

	print("DOSAGE: %d/%d passed" % [passed, total])
	var path = OS.get_environment("DOSAGE_SAVE")
	if path != "" and FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			print("=====")
			print(Dosage.text(data, OS.get_environment("DOSAGE_TODAY")))
	quit(0 if passed == total else 1)
