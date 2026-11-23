extends SceneTree
## Unit test for game/run_splits.gd: the best splits inside a run.
##   godot --headless --path . --script res://tests/run_splits_test.gd
## Prints RUNSPLITS: X/Y passed and exits with 1 when anything fails.

const MI = 1609.344

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func run(date: String, dist_m: float, sec: int, splits = null) -> Dictionary:
	_n += 1
	var s = {"id": "r%d" % _n, "discipline": "run", "date": date, "createdAt": 1700000000000 + _n, "source": "manual", "distanceM": dist_m, "elevationM": 0.0, "durationSec": sec}
	if splits != null:
		s["splits"] = splits
	return s


func _init() -> void:
	# --- which distances a run has ------------------------------------------------------------
	var half = 13.1 * MI
	ok(RunSplits.whole(half) == "half" and RunSplits.whole(3.1 * MI) == "5k" and RunSplits.whole(6.2 * MI) == "10k" and RunSplits.whole(26.2 * MI) == "full" and RunSplits.whole(MI) == "mile" and RunSplits.whole(5000.0) == "5k", "13.1 miles is a half marathon, 3.1 a 5K, 6.2 a 10K, 26.2 a marathon")
	ok(RunSplits.whole(4.0 * MI) == "" and RunSplits.whole(3.3 * MI) == "" and RunSplits.whole(0.0) == "", "4 miles is no distance of its own")
	ok(RunSplits.whole(3.0 * MI) == "" and RunSplits.whole(6.1 * MI) == "" and RunSplits.whole(13.0 * MI) == "" and RunSplits.whole(26.1 * MI) == "" and RunSplits.whole(4980.0) == "", "a tenth of a mile under is not the race: 13.0 miles is no half marathon", [RunSplits.whole(13.0 * MI), RunSplits.whole(26.1 * MI)])
	ok(RunSplits.whole(4990.0) == "5k" and RunSplits.whole(5040.0) == "5k" and RunSplits.whole(5060.0) == "" and RunSplits.whole(13.2 * MI) == "half", "a little past is still the distance (5.04 km a 5K, 13.2 miles a half), further past has it inside")
	ok(RunSplits.offered(13.0 * MI, "mi") == ["mile", "5k", "10k", "10mi"] and not RunSplits.fits("half", 13.0 * MI), "13.0 miles has the shorter distances inside and no half marathon at all", RunSplits.offered(13.0 * MI, "mi"))
	ok(RunSplits.offered(half, "mi") == ["mile", "5k", "10k", "10mi"], "a half marathon in miles: best mile, 5K, 10K and 10 mile (the half is the run itself)", RunSplits.offered(half, "mi"))
	ok(RunSplits.offered(21097.5, "km") == ["1k", "5k", "10k"], "the same in kilometres: the kilometre in place of the mile, no 10 mile", RunSplits.offered(21097.5, "km"))
	ok(RunSplits.offered(14.0 * MI, "mi") == ["mile", "5k", "10k", "10mi", "half"], "a longer run has the half marathon in it too", RunSplits.offered(14.0 * MI, "mi"))
	ok(RunSplits.offered(3.1 * MI, "mi") == ["mile"] and RunSplits.offered(3.0 * MI, "mi") == ["mile"] and RunSplits.offered(3.3 * MI, "mi") == ["mile", "5k"], "3.1 miles is the 5K itself; 3.3 miles has a 5K inside", [RunSplits.offered(3.1 * MI, "mi"), RunSplits.offered(3.3 * MI, "mi")])
	ok(RunSplits.offered(MI, "mi").is_empty() and RunSplits.offered(0.5 * MI, "mi").is_empty() and RunSplits.offered(MI, "km") == ["1k"], "a mile has no split in miles; under a mile there is none at all")
	ok(RunSplits.offered(8000.0, "km", ["mile", "10k"]) == ["1k", "mile", "5k"], "a time already there for another unit's distance stays, while it fits in the run", RunSplits.offered(8000.0, "km", ["mile", "10k"]))
	ok(RunSplits.offered(27.0 * MI, "mi") == ["mile", "5k", "10k", "10mi", "half", "full"] and RunSplits.fits("5k", 6000.0) and not RunSplits.fits("5k", 5000.0) and not RunSplits.fits("nonsense", 99999.0), "an ultra has them all")

	# --- reading a typed time -------------------------------------------------------------------
	ok(RunSplits.parse_time("7:45") == 465 and RunSplits.parse_time("7.45") == 465 and RunSplits.parse_time("7 45") == 465 and RunSplits.parse_time("745") == 465 and RunSplits.parse_time(" 7,45 ") == 465, "7 min 45 s, written five ways (a phone's number pad has a dot and no colon)")
	ok(RunSplits.parse_time("26:10") == 1570 and RunSplits.parse_time("2610") == 1570 and RunSplits.parse_time("26.10") == 1570, "26:10")
	ok(RunSplits.parse_time("1:02:03") == 3723 and RunSplits.parse_time("1.02.03") == 3723 and RunSplits.parse_time("10203") == 3723, "1:02:03")
	ok(RunSplits.parse_time("8") == 480 and RunSplits.parse_time("45") == 2700 and RunSplits.parse_time("75:30") == 4530 and RunSplits.parse_time("7530") == 4530, "one or two digits alone are minutes; minutes may pass sixty")
	ok(RunSplits.parse_time("7:5") == 425 and RunSplits.parse_time("0:59") == 59, "7:5 is 7:05")
	ok(RunSplits.parse_time("") == 0 and RunSplits.parse_time("abc") == 0 and RunSplits.parse_time("7:90") == 0 and RunSplits.parse_time("790") == 0 and RunSplits.parse_time("1:75:00") == 0 and RunSplits.parse_time("1:2:3:4") == 0 and RunSplits.parse_time("7m45") == 0 and RunSplits.parse_time("1234567") == 0 and RunSplits.parse_time(":") == 0, "what is no time is none")
	ok(RunSplits.fmt_time(465) == "7:45" and RunSplits.fmt_time(3723) == "1:02:03" and RunSplits.fmt_time(1570) == "26:10" and RunSplits.parse_time(RunSplits.fmt_time(3723)) == 3723, "and written back")

	# --- the splits of a session ------------------------------------------------------------------
	var hm = run("2026-11-23", half, 6900, {"mile": 465, "5k": 1530, "10k": 3150, "nonsense": 5, "10mi": 0})
	ok(RunSplits.of_session(hm) == {"mile": 465, "5k": 1530, "10k": 3150, "half": 6900}, "a half marathon: what was typed, and the half from the run's own time", RunSplits.of_session(hm))
	var rows = RunSplits.rows(hm)
	ok(rows.map(func(r): return str(r.id)) == ["mile", "5k", "10k", "half"] and rows.map(func(r): return bool(r.whole)) == [false, false, false, true] and str(rows[0].name) == "Mile" and int(rows[1].sec) == 1530 and is_equal_approx(float(rows[1].pace), 306.0), "its rows, shortest first, the run itself marked", rows)
	ok(RunSplits.of_session(run("2026-11-20", 4.0 * MI, 2000)).is_empty() and RunSplits.of_session(run("2026-11-20", 5000.0, 0)).is_empty() and RunSplits.of_session({"discipline": "ride", "distanceM": 5000.0, "durationSec": 900, "splits": {"5k": 900}}).is_empty(), "a run that is no distance, a 5K without a time and a ride have none")
	ok(RunSplits.of_session(run("2026-11-20", 5000.0, 1500)) == {"5k": 1500}, "a 5 km run with a time is a 5K")
	ok(is_equal_approx(RunSplits.pace("mile", 480.0), 480.0 / 1.609344) and is_equal_approx(RunSplits.pace("10k", 3000.0), 300.0), "a split's pace")
	ok(RunSplits.slower_than_run("mile", 600.0, half, 6900.0) and not RunSplits.slower_than_run("mile", 465.0, half, 6900.0) and not RunSplits.slower_than_run("mile", 600.0, half, 0.0) and not RunSplits.slower_than_run("mile", 0.0, half, 6900.0), "a best mile slower than the run's average is a slip of the finger; without a time for the run it cannot be told")

	# --- bests and records -------------------------------------------------------------------------
	var log = [
		run("2026-10-05", 5000.0, 1600),
		run("2026-10-12", 10000.0, 3300, {"5k": 1590, "1k": 290}),
		run("2026-10-19", 4.0 * MI, 2100, {"mile": 500}),
		{"id": "l1", "discipline": "lift", "date": "2026-10-20", "createdAt": 5, "exercises": []},
	]
	var b = RunSplits.bests(log)
	ok(int(b["5k"].sec) == 1590 and str(b["5k"].date) == "2026-10-12" and int(b["10k"].sec) == 3300 and int(b["mile"].sec) == 500 and int(b["1k"].sec) == 290 and not b.has("half"), "the best of each distance: a 5K inside a 10K beats the 5K run", b)
	ok(RunSplits.bests([]).is_empty() and RunSplits.bests([log[3]]).is_empty(), "no runs, no bests")
	var tie = RunSplits.bests([run("2026-11-02", 5000.0, 1500), run("2026-11-01", 5000.0, 1500)])
	ok(str(tie["5k"].date) == "2026-11-01", "of equal times the earlier one holds the record", tie)
	var rec = RunSplits.records(log, [hm])
	ok(rec.map(func(r): return str(r.id)) == ["mile", "5k", "10k"] and int(rec[0].sec) == 465 and int(rec[0].was) == 500 and int(rec[1].was) == 1590 and int(rec[2].was) == 3300, "the half marathon beat three bests; the half itself is a first time, not a record", rec)
	ok(RunSplits.records(log, [run("2026-11-24", 5000.0, 1700)]).is_empty() and RunSplits.records([], [hm]).is_empty(), "a slower 5K beats nothing, and neither does a first run")

	# --- what a run counts as for the rules (trophies, gear, the pace record) ---------------------
	ok(is_equal_approx(float(RunSplits.counted(3.1 * MI)), 5000.0) and is_equal_approx(float(RunSplits.counted(6.2 * MI)), 10000.0) and is_equal_approx(float(RunSplits.counted(13.1 * MI)), 21097.5) and is_equal_approx(float(RunSplits.counted(26.2 * MI)), 42195.0), "3.1, 6.2, 13.1 and 26.2 miles count as the 5K, the 10K, the half and the marathon", [RunSplits.counted(3.1 * MI), RunSplits.counted(13.1 * MI)])
	ok(is_equal_approx(float(RunSplits.counted(3.0 * MI)), 3.0 * MI) and is_equal_approx(float(RunSplits.counted(6.1 * MI)), 6.1 * MI) and is_equal_approx(float(RunSplits.counted(13.0 * MI)), 13.0 * MI) and is_equal_approx(float(RunSplits.counted(26.1 * MI)), 26.1 * MI), "3.0, 6.1, 13.0 and 26.1 miles are what they are")
	var plain = RunSplits.counted(5200)
	ok(plain is int and plain == 5200 and RunSplits.counted(0) is int and RunSplits.counted(null) == null and is_equal_approx(float(RunSplits.counted(5000.0)), 5000.0) and is_equal_approx(float(RunSplits.counted(4.0 * MI)), 4.0 * MI), "any other distance comes back as it went in (a whole number stays one)", plain)
	ok(is_equal_approx(float(RunSplits.counted(4990.0)), 5000.0) and is_equal_approx(float(RunSplits.counted(4980.0)), 4980.0), "in kilometres: 4.99 km counts as the 5K, 4.98 km does not")
	# Through the real rules: a log with one run.
	var one = func(dist_m: float, sec: int): return Derive.derive({"sessions": [run("2026-11-20", dist_m, sec)], "claims": [], "body": [], "purchases": [], "weeklyGoal": 3, "today": "2026-11-23"})
	var s5 = one.call(3.1 * MI, 1440)
	ok(s5.achievements.has("run_5k") and not s5.achievements.has("run_10k") and is_equal_approx(float(s5.prs.longestRunM), 3.1 * MI), "a 3.1 mile run earns the 5K trophy; the record stays 3.1 miles", s5.achievements.keys())
	ok(s5.prs.bestPaceSecPerKm != null and absf(float(s5.prs.bestPaceSecPerKm) - 1440.0 / (3.1 * MI / 1000.0)) < 0.5, "and counts for the fastest pace over a 5K, at the pace it was really run", s5.prs.bestPaceSecPerKm)
	var s3 = one.call(3.0 * MI, 1400)
	ok(not s3.achievements.has("run_5k") and s3.prs.bestPaceSecPerKm == null, "a 3.0 mile run earns neither", s3.achievements.keys())
	var s10 = one.call(6.2 * MI, 3000)
	var s9 = one.call(6.1 * MI, 3000)
	ok(s10.achievements.has("run_10k") and s10.items.has("race_bib") and s9.achievements.has("run_5k") and not s9.achievements.has("run_10k") and not s9.items.has("race_bib"), "6.2 miles earns the 10K trophy and the race bib, 6.1 miles does not", [s10.achievements.keys(), s9.items.keys()])
	var s21 = one.call(13.1 * MI, 6900)
	var s20 = one.call(13.0 * MI, 6900)
	ok(s21.achievements.has("run_half") and s21.achievements.has("run_10k") and s21.achievements.has("run_5k") and s21.items.has("carbon_racers") and not s21.achievements.has("run_marathon"), "13.1 miles earns the half marathon trophy and its shoes", s21.achievements.keys())
	ok(not s20.achievements.has("run_half") and not s20.items.has("carbon_racers") and s20.achievements.has("run_10k"), "13.0 miles does not", s20.achievements.keys())
	var s42 = one.call(26.2 * MI, 14400)
	var s41 = one.call(26.1 * MI, 14400)
	ok(s42.achievements.has("run_marathon") and s42.items.has("marathon_medal") and not s41.achievements.has("run_marathon") and not s41.items.has("marathon_medal") and s41.achievements.has("run_half"), "26.2 miles earns the marathon trophy and its medal, 26.1 miles does not", s42.achievements.keys())
	var km = one.call(21100.0, 6900)
	ok(km.achievements.has("run_half") and one.call(5000.0, 1500).achievements.has("run_5k") and not one.call(4900.0, 1500).achievements.has("run_5k"), "in kilometres nothing changed: 21.1 km and 5 km earn theirs, 4.9 km does not")
	var p_half = Achievements.by_id("run_half").progress.call(s20)
	var p_done = Achievements.by_id("run_half").progress.call(s21)
	ok(is_equal_approx(float(p_half.cur), 13.0 * MI) and int(p_half.target) == 21097 and float(p_done.cur) >= float(p_done.target), "the progress of the half marathon trophy: 13.0 miles on the way, 13.1 miles there", [p_half, p_done])

	print("RUNSPLITS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
