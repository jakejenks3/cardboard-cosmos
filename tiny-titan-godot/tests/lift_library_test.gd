extends SceneTree
## Unit test for the lift library (game/lift_library.gd): movements, their
## variations, and the log joined with them. The catalog's own checks (names,
## variations written one way) are in tests/lift_names_test.gd.
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
	var cat = LiftLibrary.catalog()
	var equip_ids = LiftLibrary.EQUIPMENT.map(func(p): return p.id)
	var bad = []
	for e in cat:
		if not equip_ids.has(e.equip) or e.equips.is_empty() or e.equips.any(func(g): return not equip_ids.has(g)):
			bad.append(e.name)
	ok(bad.is_empty(), "every movement has its equipment worked out from its variations", bad)
	var bench = row(cat, "Bench Press")
	ok(bench != null and bench.equip == "barbell" and bench.equips.has("dumbbell") and bench.equips.has("machine"), "bench press: barbell first, dumbbell and machine among its variations", bench.equips if bench != null else null)
	var pull = row(cat, "Lat Pulldown")
	ok(pull != null and pull.equip == "cable" and pull.only == ["Cable"], "a lat pulldown is a cable movement, so the cable is never said")
	ok(row(cat, "Pull-up").equip == "bodyweight", "a pull-up is bodyweight")
	var missing = []
	for n in Summary.DEFAULT_EXERCISES:
		var r = LiftNames.resolve(str(n))
		if r.kind == "new":
			missing.append(n)
	ok(missing.is_empty(), "every suggested exercise is a known movement", missing)

	# The log joins the catalog: each logged variation under its movement.
	var sessions = [
		lift("2026-10-01", {"Squat - Barbell": [[5, 100], [5, 100], [3, 110]], "Calf Raise": [[10, 60]], "Pull-up": [[8, 0], [6, 0]]}),
		lift("2026-10-08", {"Squat - Barbell": [[5, 105], [8, 90]], "Squat - Front": [[5, 80]], "Calf Raise - Seated machine": [[12, 70]], "Jefferson Curl": [[10, 20]]}),
		{"id": "r1", "discipline": "run", "date": "2026-10-09", "createdAt": 1700000000001, "distanceM": 5000.0},
	]
	var rows = LiftLibrary.rows(sessions)
	var sq = row(rows, "Squat")
	ok(sq != null and sq.done.size() == 2 and sq.st != null and int(sq.st.count) == 3, "squat: two variations logged, three sessions in all", sq.done if sq != null else null)
	var back = sq.done.filter(func(d): return d.variation == "Barbell")[0] if sq != null else null
	ok(back != null and int(back.st.count) == 2 and is_equal_approx(back.st.bestKg, 110.0) and int(back.st.bestReps) == 3 and back.st.last == "2026-10-08", "squat - barbell keeps its own records: 2 sessions, best 110 x 3", back.st if back != null else null)
	ok(sq != null and is_equal_approx(sq.st.bestKg, 110.0) and sq.done[0].st.last == "2026-10-08", "the movement's best is the best of its variations; the most recent variation first")
	var marks = LiftLibrary.rep_bests(back.st)
	var by = {}
	for m in marks:
		by[int(m.reps)] = float(m.kg)
	ok(is_equal_approx(by[1], 110.0) and is_equal_approx(by[3], 110.0) and is_equal_approx(by[5], 105.0) and is_equal_approx(by[8], 90.0) and not by.has(10), "rep records of one variation", marks)
	var calf = row(rows, "Calf Raise")
	ok(calf != null and calf.done.size() == 2 and calf.done.any(func(d): return d.variation == ""), "calf raise: with no variation and seated machine", calf.done if calf != null else null)
	var pu = row(rows, "Pull-up")
	ok(pu != null and int(pu.st.bwReps) == 8 and is_equal_approx(pu.st.bestKg, 0.0) and int(pu.st.reps) == 14, "pull-up: bodyweight best set 8, 14 reps in all")
	var own = row(rows, "Jefferson Curl")
	ok(own != null and own.own and own.part == "biceps" and own.done.size() == 1, "a movement of the player's own is listed, part guessed from its name", own)
	ok(row(rows, "Bench Press") != null and row(rows, "Bench Press").st == null, "a movement never done has no stats")

	# The variations to choose from: logged first, then the catalog's others.
	var sv = LiftLibrary.variation_list(sq)
	ok(sv[0].st != null and sv[1].st != null and [sv[0].name, sv[1].name].has("Squat - Front") and [sv[0].name, sv[1].name].has("Squat - Barbell") and sv.any(func(d): return d.variation == "Goblet" and d.st == null), "squat: the logged variations first, then goblet and the rest to try", sv.map(func(d): return d.name))
	var pv = LiftLibrary.variation_list(row(rows, "Pull-up"))
	ok(pv[0].name == "Pull-up" and pv.any(func(d): return d.name == "Pull-up - Weighted"), "pull-up: the plain movement, then weighted and the others", pv.map(func(d): return d.name))
	var dup = {}
	var twice = []
	for d in LiftLibrary.variation_list(row(rows, "Calf Raise")):
		if dup.has(d.name):
			twice.append(d.name)
		dup[d.name] = true
	ok(twice.is_empty(), "no variation is offered twice", twice)

	# Filter, search and sort.
	var mine = LiftLibrary.query(rows, {"show": "mine", "sort": "count"})
	ok(mine.size() == 4 and mine[0].name == "Squat", "Done shows the 4 movements logged, most done first", mine.map(func(e): return e.name))
	var heavy = LiftLibrary.query(rows, {"sort": "best"})
	ok(heavy[0].name == "Squat" and heavy[1].name == "Calf Raise", "Heaviest puts squat then calf raise first", heavy.slice(0, 3).map(func(e): return e.name))
	var chest_cable = LiftLibrary.query(rows, {"part": "chest", "equip": "cable"})
	ok(chest_cable.size() >= 1 and chest_cable.any(func(e): return e.name == "Chest Fly") and chest_cable.all(func(e): return e.part == "chest" and e.equips.has("cable")), "chest + cable: movements with a cable variation", chest_cable.map(func(e): return e.name))
	ok(LiftLibrary.query(rows, {"q": "heel raise"}).size() == 1 and LiftLibrary.query(rows, {"q": "heel raise"})[0].name == "Calf Raise", "search finds a movement by its other name")
	ok(LiftLibrary.query(rows, {"q": "goblet"}).any(func(e): return e.name == "Squat"), "search finds a movement by a variation")
	ok(LiftLibrary.query(rows, {"q": "glutes", "show": "new"}).size() > 5, "search 'glutes' + New to me offers things to try")
	var grouped = LiftLibrary.query(rows, {"sort": "part"})
	var order = []
	for e in grouped:
		if order.is_empty() or order[order.size() - 1] != e.part:
			order.append(e.part)
	ok(order.size() == 13 and order[0] == "chest" and order[11] == "mobility" and order[12] == "full", "body-part sort keeps each part together, in catalog order", order)
	ok(LiftLibrary.query(rows, {"q": "zzzz"}).is_empty(), "no match is an empty list")
	print("LIFTLIB: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
