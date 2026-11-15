extends SceneTree
## Unit test for the lift library (game/lift_library.gd).
##   godot --headless --path . --script res://tests/lift_library_test.gd
## Prints LIFTLIB: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## A lifting session from {name: [[reps, kg], ...]}.
func lift(date: String, exercises: Dictionary) -> Dictionary:
	_n += 1
	var exs = []
	for name in exercises:
		var sets = []
		for st in exercises[name]:
			sets.append({"reps": st[0], "weightKg": st[1]})
		exs.append({"name": name, "sets": sets})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n * 3600000, "source": "manual", "exercises": exs}


func row(rows: Array, name: String):
	for e in rows:
		if e.name == name:
			return e
	return null


func _init() -> void:
	# The catalog is well formed.
	var cat = LiftLibrary.catalog()
	var part_ids = LiftLibrary.PARTS.map(func(p): return p.id)
	var equip_ids = LiftLibrary.EQUIPMENT.map(func(p): return p.id)
	var seen = {}
	var dupes = []
	var bad = []
	for e in cat:
		if not part_ids.has(e.part) or not equip_ids.has(e.equip) or str(e.tip).length() < 10 or str(e.family) == "":
			bad.append(e.name)
		for k in e.keys:
			if seen.has(k):
				dupes.append(k)
			seen[k] = e.name
	ok(cat.size() >= 150, "at least 150 lifts", cat.size())
	ok(bad.is_empty(), "every lift has a known part, equipment, family and a tip", bad)
	ok(dupes.is_empty(), "no name or alias is claimed twice", dupes)
	for p in LiftLibrary.PARTS:
		if p.id != "other":
			ok(cat.any(func(e): return e.part == p.id), "the %s section has lifts" % p.name)
	# Everything the log form and the phone-note shorthand can produce is in the library.
	var missing = []
	for n in Summary.DEFAULT_EXERCISES:
		if not seen.has(Xp.normalize_exercise(n)):
			missing.append(n)
	for k in QuickLog.ALIASES:
		if not seen.has(Xp.normalize_exercise(QuickLog.ALIASES[k])):
			missing.append(QuickLog.ALIASES[k])
	ok(missing.is_empty(), "default exercises and shorthand names are all in the library", missing)

	# History joins the catalog, including under another name.
	var sessions = [
		lift("2026-10-01", {"Squat": [[5, 100], [5, 100], [3, 110]], "Heel Raise": [[10, 60]], "Pull-up": [[8, 0], [6, 0]]}),
		lift("2026-10-08", {"Squat": [[5, 105], [8, 90]], "Standing Calf Raise": [[12, 70]], "Jefferson Curl": [[10, 20]]}),
		{"id": "r1", "discipline": "run", "date": "2026-10-09", "createdAt": 1700000000001, "distanceM": 5000.0},
	]
	var rows = LiftLibrary.rows(sessions)
	var sq = row(rows, "Squat")
	ok(sq != null and sq.st != null and int(sq.st.count) == 2 and is_equal_approx(sq.st.bestKg, 110.0) and int(sq.st.bestReps) == 3 and sq.st.last == "2026-10-08", "squat: 2 sessions, best 110 x 3, last 8 Oct", sq.st if sq != null else null)
	ok(sq != null and is_equal_approx(sq.st.e1rm, Xp.e1rm(105.0, 5)) and sq.st.history[0].date == "2026-10-08", "squat: e1RM from 105 x 5, newest session first")
	var marks = LiftLibrary.rep_bests(sq.st)
	var by = {}
	for m in marks:
		by[int(m.reps)] = float(m.kg)
	ok(is_equal_approx(by[1], 110.0) and is_equal_approx(by[3], 110.0) and is_equal_approx(by[5], 105.0) and is_equal_approx(by[8], 90.0) and not by.has(10), "rep records: 110 for 1 and 3, 105 for 5, 90 for 8, none for 10", marks)
	var calf = row(rows, "Calf Raise")
	ok(calf != null and calf.st != null and int(calf.st.count) == 2 and is_equal_approx(calf.st.bestKg, 70.0) and calf.st.name == "Standing Calf Raise", "heel raise and standing calf raise are one lift", calf.st if calf != null else null)
	var pu = row(rows, "Pull-up")
	ok(pu != null and int(pu.st.bwReps) == 8 and is_equal_approx(pu.st.bestKg, 0.0) and int(pu.st.reps) == 14, "pull-up: bodyweight best set 8, 14 reps in all")
	var own = row(rows, "Jefferson Curl")
	ok(own != null and own.own and own.part == "biceps", "an unknown lift is listed as your own, part guessed from its name", own)
	ok(row(rows, "Bench Press") != null and row(rows, "Bench Press").st == null, "a lift never done has no stats")

	# Filter, search and sort.
	var mine = LiftLibrary.query(rows, {"show": "mine", "sort": "count"})
	ok(mine.size() == 4 and (mine[0].name == "Squat" or mine[0].name == "Calf Raise"), "Done shows the 4 lifts logged, most done first", mine.map(func(e): return e.name))
	var heavy = LiftLibrary.query(rows, {"sort": "best"})
	ok(heavy[0].name == "Squat" and heavy[1].name == "Calf Raise", "Heaviest puts squat then calf raise first")
	var chest_cable = LiftLibrary.query(rows, {"part": "chest", "equip": "cable"})
	ok(chest_cable.size() == 3 and chest_cable.all(func(e): return e.part == "chest" and e.equip == "cable"), "chest + cable: the three cable flies", chest_cable.map(func(e): return e.name))
	var curls = LiftLibrary.query(rows, {"q": "cable curl"})
	ok(curls.any(func(e): return e.name == "Cable Curl") and curls.all(func(e): return e.equip == "cable"), "search 'cable curl' finds cable curls only", curls.map(func(e): return e.name))
	ok(LiftLibrary.query(rows, {"q": "heel raise"}).size() == 1 and LiftLibrary.query(rows, {"q": "heel raise"})[0].name == "Calf Raise", "search finds a lift by its other name")
	ok(LiftLibrary.query(rows, {"q": "glutes", "show": "new"}).size() > 5, "search 'glutes' + New to me offers things to try")
	var grouped = LiftLibrary.query(rows, {"sort": "part"})
	var order = []
	for e in grouped:
		if order.is_empty() or order[order.size() - 1] != e.part:
			order.append(e.part)
	ok(order.size() == 12 and order[0] == "chest" and order[11] == "full", "body-part sort keeps each part together, in catalog order", order)
	ok(LiftLibrary.query(rows, {"q": "zzzz"}).is_empty(), "no match is an empty list")

	# Variations.
	var v = LiftLibrary.variations(row(rows, "Bench Press"), rows).map(func(e): return e.name)
	ok(v.has("Incline Bench Press") and v.has("Dumbbell Bench Press") and v.has("Close-Grip Bench Press") and not v.has("Bench Press"), "bench press variations", v)

	print("LIFTLIB: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
