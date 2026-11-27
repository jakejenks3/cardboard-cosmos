extends SceneTree
## Unit test for the hangboard records by edge (Derive, prs.hangEdge /
## hangOneArm / longestHangSec, the "hang_*" trophies) and the photo milestones
## (s.body.photoSpanDays / photoMonths, the "body_*_on" trophies, the reel moment).
##   godot --headless --path . --script res://tests/extras_test.gd
## Prints EXTRAS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## A climb session holding only hangs: [[edgeMm, sec, arms, addKg, count], ...].
func hangs(date: String, list: Array) -> Dictionary:
	_n += 1
	var hs = []
	for h in list:
		hs.append({"edgeMm": h[0], "sec": h[1], "arms": h[2], "addKg": float(h[3]), "count": h[4]})
	return {"id": "h%d" % _n, "discipline": "climb", "date": date, "createdAt": 1700000000000 + _n * 3600000, "source": "manual", "climbs": [], "hangs": hs}


func photos(date: String, n: int) -> Dictionary:
	_n += 1
	var ph = {}
	for i in range(n):
		ph[TT.PHOTO_ANGLES[i]] = "p%d%d" % [_n, i]
	return {"id": "b%d" % _n, "date": date, "createdAt": 1700000000000 + _n * 3600000, "photos": ph}


func derive(sessions: Array, body: Array = []) -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": [], "body": body, "weeklyGoal": 3, "today": "2026-11-15"})


func has(s: Dictionary, id: String) -> bool:
	return s.achievements.has(id)


func _init() -> void:
	# Nothing hung: every new key stays null (parity-safe).
	var s0 = derive([])
	ok(s0.prs.hangEdge == null and s0.prs.hangOneArm == null and s0.prs.longestHangSec == null and s0.body.photoSpanDays == null and s0.body.photoMonths == null, "new state keys are null until used", s0.prs)

	# Two-arm records by edge; assisted and short hangs set none.
	var s1 = derive([hangs("2026-10-01", [[20, 10, 2, 10, 5], [20, 10, 2, 25, 1], [15, 7, 2, 0, 3], [10, 3, 2, 0, 2], [20, 10, 2, -10, 2]])])
	ok(int(s1.prs.hangEdge["20"]) == 25 and int(s1.prs.hangEdge["15"]) == 0 and not s1.prs.hangEdge.has("10"), "20 mm +25, 15 mm bodyweight, a 3 s hang and an assisted hang are no record", s1.prs.hangEdge)
	ok(int(s1.prs.longestHangSec) == 10 and has(s1, "hang_plus_20") and not has(s1, "hang_plus_40") and not has(s1, "hang_edge_10"), "Weighted Hang earned, Iron Fingers and Micro Edge not", s1.achievements.keys())
	var s2 = derive([hangs("2026-10-02", [[10, 5, 2, 0, 1], [8, 6, 2, 0, 1]])])
	ok(has(s2, "hang_edge_10") and s2.prs.hangOneArm == null, "a 5 s hang on 10 mm is Micro Edge; no one-arm record yet")

	# One arm.
	var s3 = derive([hangs("2026-10-03", [[20, 6, 1, 0, 2]])])
	ok(int(s3.prs.hangOneArm["20"]) == 0 and has(s3, "hang_one_arm") and not has(s3, "hang_one_arm_15") and not has(s3, "hang_plus_20"), "one-arm on 20 mm: One Arm Bandit, not Half the Hands", s3.prs)
	var s4 = derive([hangs("2026-10-03", [[15, 5, 1, 5, 1]])])
	ok(has(s4, "hang_one_arm_15") and int(s4.prs.hangOneArm["15"]) == 5, "one-arm on 15 mm +5: Half the Hands")

	# Records improve across sessions and the chronicle notes the PR.
	var s5 = derive([hangs("2026-10-01", [[20, 10, 2, 10, 5]]), hangs("2026-10-08", [[20, 10, 2, 20, 3]]), hangs("2026-10-15", [[20, 10, 2, 15, 3]])])
	var prs_in_chron = 0
	for c in s5.chronicle:
		if c.kind == "pr" and str(c.title).contains("hang PR"):
			prs_in_chron += 1
	ok(int(s5.prs.hangEdge["20"]) == 20 and prs_in_chron == 1, "20 mm record is +20 after three sessions, one PR line", s5.chronicle)

	# Hang Time and Hour of Power.
	var s6 = derive([hangs("2026-10-04", [[20, 30, 2, 0, 1], [20, 10, 2, 0, 355]])])
	ok(has(s6, "hang_30s") and int(s6.totals.hangSec) == 3580 and not has(s6, "hang_hour"), "a 30 s hang earns Hang Time; 59 min 40 s is not an hour", s6.totals)
	var s7 = derive([hangs("2026-10-04", [[20, 10, 2, 0, 360]])])
	ok(has(s7, "hang_hour"), "3,600 s of hanging is Hour of Power")

	# Photo milestones.
	var b1 = derive([], [photos("2026-01-10", 3), photos("2026-02-08", 1)])
	ok(int(b1.body.photoSpanDays) == 29 and int(b1.body.photoMonths) == 2 and has(b1, "body_month_on") and not has(b1, "body_season_on"), "photos 29 days apart in two months: One Month On", b1.body)
	var b2 = derive([], [photos("2026-01-10", 3), photos("2026-02-05", 1)])
	ok(int(b2.body.photoSpanDays) == 26 and not has(b2, "body_month_on"), "26 days apart is not a month")
	var six = []
	for m in range(1, 7):
		six.append(photos("2026-%02d-03" % m, 2))
	var b3 = derive([], six)
	ok(int(b3.body.photoMonths) == 6 and has(b3, "body_months_6") and has(b3, "body_season_on") and not has(b3, "body_months_12"), "six months of photos: Half a Year of Snaps and Three Months On", b3.body)
	var b4 = derive([], [{"id": "w1", "date": "2026-01-10", "createdAt": 1700000000000, "weightKg": 80.0}])
	ok(b4.body.photoSpanDays == null, "a weigh-in without photos sets no photo milestone")

	# The reel moment when the album reaches a month.
	var first = photos("2026-01-10", 3)
	var second = photos("2026-02-08", 3)
	var before = derive([], [first])
	var after = derive([], [first, second])
	var ev = Diff.diff_body(before, after, second)
	var moment = null
	for e in ev:
		if e.type == "pr" and str(e.title) == "One month on":
			moment = e
	ok(moment != null, "diff_body reports One month on", ev)
	ok(Diff.diff_body(after, derive([], [first, second, photos("2026-02-20", 1)]), second).filter(func(e): return e.type == "pr").is_empty(), "no second One month on once passed")

	ok(Achievements.all().size() == 187, "187 trophies in the catalog", Achievements.all().size())
	print("EXTRAS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
