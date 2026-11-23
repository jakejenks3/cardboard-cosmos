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

	print("RUNSPLITS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
