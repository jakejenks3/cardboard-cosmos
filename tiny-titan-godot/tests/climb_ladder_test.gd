extends SceneTree
## Unit test for game/climb_ladder.gd: flashes, sends and tries that did not
## go, per grade, boulders and routes apart.
##   godot --headless --path . --script res://tests/climb_ladder_test.gd
## Prints CLIMBLADDER: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _climb(id: String, date: String, climbs: Array) -> Dictionary:
	return {"id": id, "date": date, "discipline": "climb", "climbs": climbs}


func _row(lad: Dictionary, g: int):
	for r in lad.rows:
		if int(r.grade) == g:
			return r
	return null


func _init() -> void:
	var log = [
		_climb("a", "2026-03-02", [
			{"grade": 2, "result": "flash", "count": 2},
			{"grade": 4, "result": "attempt", "count": 3},
			{"grade": 4, "result": "send", "count": 1},
		]),
		_climb("b", "2026-03-05", [
			{"grade": 4, "result": "flash", "count": 1},
			{"grade": 5, "result": "attempt", "count": 4},
			{"grade": 3, "style": "rope", "yds": "5.10d", "result": "send", "count": 1},
			{"grade": 4, "style": "rope", "yds": "5.11b", "result": "attempt", "count": 2},
		]),
		{"id": "c", "date": "2026-03-06", "discipline": "lift", "exercises": []},
		_climb("d", "2026-03-09", [
			{"grade": 4, "result": "attempt", "count": 1},
			{"grade": 5, "result": "attempt", "count": 0},
		]),
	]
	var b = ClimbLadder.ladder(log, false)
	var grades = []
	for r in b.rows:
		grades.append(int(r.grade))
	ok(grades == [5, 4, 3, 2], "boulders: hardest first, every grade between, routes left out", grades)
	var v4 = _row(b, 4)
	ok(v4.flash == 1 and v4.send == 1 and v4.attempt == 4, "V4: one flash, one send after tries, four that did not go", v4)
	ok(v4.sent == 2 and v4.tries == 6, "a flash is a send: V4 sent 2 of 6 tries", v4)
	ok(v4.sessions == 3 and v4.firstSent == "2026-03-02" and v4.firstFlash == "2026-03-05" and v4.last == "2026-03-09", "V4: three sessions, first sent, first flashed, last tried", v4)
	var v3 = _row(b, 3)
	ok(v3.tries == 0 and v3.label == "V3", "a grade between with nothing logged is an empty row", v3)
	var v5 = _row(b, 5)
	ok(v5.sent == 0 and v5.attempt == 4 and v5.sessions == 1, "V5 tried, not sent; a count of 0 is nothing", v5)
	ok(b.total.flash == 3 and b.total.send == 1 and b.total.attempt == 8 and b.total.sent == 4 and b.total.tries == 12, "the totals add up", b.total)
	ok(b.hardestSent == 4 and b.hardestFlash == 4, "hardest send and flash", [b.hardestSent, b.hardestFlash])
	ok(ClimbLadder.default_pick(b.rows) == 1, "the first row shown is the hardest grade sent (V4)")
	var r = ClimbLadder.ladder(log, true)
	var labels = []
	for x in r.rows:
		labels.append(str(x.label))
	ok(labels == ["5.11b", "5.11a", "5.10d"], "routes: by YDS, hardest first, the grade between too", labels)
	ok(r.total.sent == 1 and r.total.attempt == 2 and r.hardestSent == Xp.yds_index("5.10d") and r.hardestFlash == null, "route totals; no route flashed", r.total)
	ok(ClimbLadder.has_routes(log) and ClimbLadder.has_boulders(log), "both kinds found")
	ok(not ClimbLadder.has_routes([log[0]]) and ClimbLadder.ladder([], false).rows.is_empty() and ClimbLadder.ladder([], false).hardestSent == null, "no routes, and an empty log")
	ok(ClimbLadder.pct(2, 6) == 33 and ClimbLadder.pct(1, 0) == 0, "percent")
	ok(ClimbLadder.label(-1, false) == "VB" and ClimbLadder.label(Xp.yds_index("5.12a"), true) == "5.12a", "labels")
	print("CLIMBLADDER: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
