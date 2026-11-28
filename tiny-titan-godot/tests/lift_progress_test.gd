extends SceneTree
## Unit test for game/lift_progress.gd: progress counted the way it is earned (a rep more at the same
## weight, then a step heavier).
##   godot --headless --path . --script res://tests/lift_progress_test.gd
## Prints LIFTPROGRESS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _sets(kg: float, reps: Array) -> Array:
	var out = []
	for r in reps:
		out.append({"reps": int(r), "weightKg": kg})
	return out


func _h(date: String, kg: float, reps: Array) -> Dictionary:
	return {"date": date, "sets": _sets(kg, reps)}


func _init() -> void:
	var fmt = func(r): return "%s kg" % TTUtil.num_str(float(r))
	# The key: the top weight, and every rep at it (warm-ups left out).
	var k = LiftProgress.key([{"reps": 10, "weightKg": 20.0}, {"reps": 8, "weightKg": 60.0}, {"reps": 7, "weightKg": 60.0}])
	ok(is_equal_approx(float(k.rung), 60.0) and int(k.reps) == 15 and k.list == [8, 7] and str(k.mode) == "kg", "a day's key: the top weight and its reps", k)
	ok(LiftProgress.cmp(LiftProgress.key(_sets(60.0, [9, 8, 8])), LiftProgress.key(_sets(60.0, [8, 8, 8]))) == 1, "a rep more at the same weight beats it")
	ok(LiftProgress.cmp(LiftProgress.key(_sets(62.5, [8, 8, 7])), LiftProgress.key(_sets(60.0, [10, 10, 10]))) == 1, "a step heavier beats it, with fewer reps")
	ok(LiftProgress.cmp(LiftProgress.key(_sets(60.0, [8, 8, 8])), LiftProgress.key(_sets(60.0, [8, 8, 8]))) == 0, "the same is the same")
	ok(LiftProgress.cmp(LiftProgress.key(_sets(60.0, [8, 8])), LiftProgress.key(_sets(60.0, [8, 8, 8]))) == -1, "a set fewer is short of it")
	var bw = LiftProgress.key([{"reps": 10, "weightKg": 0.0}, {"reps": 8, "weightKg": 0.0}])
	ok(str(bw.mode) == "bw" and int(bw.reps) == 18, "bodyweight: every rep", bw)
	var band = LiftProgress.key([{"reps": 15, "weightKg": 0.0, "band": "green"}, {"reps": 12, "weightKg": 0.0, "band": "red"}])
	ok(str(band.mode) == "band" and int(band.rung) == Bands.level("green") and int(band.reps) == 15, "a band: its level is the rung", band)
	var hold = LiftProgress.key([{"reps": 3, "weightKg": 0.0, "holdSec": 30}])
	ok(str(hold.mode) == "sec" and int(hold.rung) == 30 and int(hold.reps) == 3, "a hold: its seconds are the rung", hold)

	# Days, oldest first, with what each one did.
	var hist = [_h("2026-11-20", 62.5, [8, 8, 7]), _h("2026-11-01", 60.0, [8, 8, 7]), _h("2026-11-04", 60.0, [8, 8, 8]),
		_h("2026-11-08", 60.0, [8, 8, 8]), _h("2026-11-12", 60.0, [9, 8, 8]), _h("2026-11-16", 60.0, [8, 8, 8]), _h("2026-11-24", 62.5, [9, 8, 7])]
	var rows = LiftProgress.days(hist)
	ok(rows.size() == 7 and str(rows[0].date) == "2026-11-01", "one row a day, oldest first", rows.size())
	ok(rows.map(func(r): return int(r.beat)) == [0, 1, 0, 1, -1, 1, 1], "each against the day before", rows.map(func(r): return int(r.beat)))
	ok(rows.map(func(r): return bool(r.record)) == [false, true, false, true, false, true, true], "a best ever: beats every day before", rows.map(func(r): return bool(r.record)))
	ok(rows.map(func(r): return bool(r.rung_up)) == [false, false, false, false, false, true, false] and int(rows[6].rung_index) == 1, "a step up: a weight never reached before")
	ok(bool(rows[1].reps_up) and not bool(rows[5].reps_up), "a rep more at the same weight is said so")
	var sm = LiftProgress.summary(rows)
	ok(int(sm.beat) == 4 and int(sm.same) == 1 and int(sm.down) == 1 and int(sm.streak) == 2 and int(sm.best_streak) == 2, "the summary counts the days", sm)
	ok(int(sm.rungs) == 1 and is_equal_approx(float(sm.first_rung), 60.0) and is_equal_approx(float(sm.rung), 62.5) and int(sm.rung_days) == 2 and int(sm.rung_first_reps) == 23 and int(sm.rung_reps) == 24, "and the current step", sm)
	ok(LiftProgress.ranks(rows) == [1.0, 2.0, 2.0, 3.0, 2.0, 4.0, 5.0], "bars climb with every gain", LiftProgress.ranks(rows))

	# How one day did, in words.
	var before = [_h("2026-11-16", 60.0, [10, 10, 10]), _h("2026-11-12", 60.0, [9, 9, 9])]
	var c1 = LiftProgress.change(_sets(60.0, [10, 10, 11]), before, fmt)
	ok(str(c1.kind) == "up" and str(c1.words) == "+1 rep at 60 kg" and bool(c1.record) and not bool(c1.rung_up), "a rep more", c1)
	var c2 = LiftProgress.change(_sets(62.5, [8, 8, 7]), before, fmt)
	ok(str(c2.kind) == "up" and str(c2.words) == "New rung: 62.5 kg" and bool(c2.rung_up), "a step up", c2)
	var c3 = LiftProgress.change(_sets(60.0, [10, 10, 8]), before, fmt)
	ok(str(c3.kind) == "down" and str(c3.words) == "2 reps short of last time", "short of it", c3)
	ok(str(LiftProgress.change(_sets(60.0, [10, 10, 10]), before, fmt).kind) == "same" and str(LiftProgress.change(_sets(60.0, [8]), [], fmt).kind) == "first", "the same, and a first time")

	# Per session: how many lifts beat the time before.
	var sessions = [
		{"id": "a", "discipline": "lift", "date": "2026-11-01", "createdAt": 1, "exercises": [{"name": "Bench", "sets": _sets(60.0, [8, 8])}, {"name": "Row", "sets": _sets(50.0, [10])}]},
		{"id": "b", "discipline": "lift", "date": "2026-11-04", "createdAt": 2, "exercises": [{"name": "Bench", "sets": _sets(60.0, [9, 8])}, {"name": "Row", "sets": _sets(50.0, [10])}, {"name": "Curl", "sets": _sets(10.0, [12])}]},
		{"id": "c", "discipline": "run", "date": "2026-11-05", "createdAt": 3},
		{"id": "d", "discipline": "lift", "date": "2026-11-08", "createdAt": 4, "exercises": [{"name": "Bench", "sets": _sets(62.5, [6, 6])}, {"name": "Curl", "sets": _sets(10.0, [11])}]},
	]
	var bc = LiftProgress.beat_counts(sessions)
	ok(int(bc.a.of) == 0 and int(bc.b.beat) == 1 and int(bc.b.of) == 2 and int(bc.d.beat) == 1 and int(bc.d.of) == 2 and not bc.has("c"), "beat counts per session (a first time counts in neither)", bc)

	print("LIFTPROGRESS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
