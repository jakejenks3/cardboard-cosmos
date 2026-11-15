extends SceneTree
## Unit test for the card-hand climbing trophies (Derive._deal_hands + the
## "hand_*" entries in game/achievements.gd).
##   godot --headless --path . --script res://tests/hands_test.gd
## Prints HANDS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## A boulder session from [[grade, result, count], ...].
func climb(day: int, climbs: Array) -> Dictionary:
	var cs = []
	for c in climbs:
		cs.append({"grade": c[0], "result": c[1], "count": c[2]})
	return {"id": "s%d" % day, "discipline": "climb", "date": "2026-10-%02d" % day, "createdAt": 1700000000000 + day * 86400000, "source": "manual", "climbs": cs}


func derive(sessions: Array) -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": [], "body": [], "weeklyGoal": 3, "today": "2026-11-15"})


func has(s: Dictionary, id: String) -> bool:
	return s.achievements.has(id)


func _init() -> void:
	# One quiet session: nothing dealt.
	var s0 = derive([climb(1, [[2, "send", 1], [3, "flash", 1]])])
	ok(s0.hands.pair == null and s0.hands.straight == null and not has(s0, "hand_pair"), "a V2 and a V3 deal no hand", s0.hands)

	# Pair of V5s: Pair and Pocket Fives, not Pocket Sevens.
	var s1 = derive([climb(2, [[5, "send", 2]])])
	ok(int(s1.hands.pair) == 5 and has(s1, "hand_pair") and has(s1, "hand_pocket_fives") and not has(s1, "hand_pocket_sevens"), "a pair of V5s", s1.hands)

	# A pair of V2s is below the V3 floor.
	var s2 = derive([climb(3, [[2, "send", 2]])])
	ok(not has(s2, "hand_pair"), "a pair of V2s is not a Pair")

	# Two pair, three of a kind, full house.
	var s3 = derive([climb(4, [[4, "send", 3], [3, "flash", 2]])])
	ok(has(s3, "hand_two_pair") and has(s3, "hand_three") and has(s3, "hand_full_house") and not has(s3, "hand_four"), "3 × V4 + 2 × V3 = two pair, three of a kind, full house", s3.hands)

	# Straight V1-V5 (sends), not a straight flush.
	var s4 = derive([climb(5, [[1, "send", 1], [2, "send", 1], [3, "send", 1], [4, "flash", 1], [5, "send", 1]])])
	ok(int(s4.hands.straight) == 5 and has(s4, "hand_straight") and not has(s4, "hand_straight_flush") and not has(s4, "hand_broadway"), "V1-V5 is a straight", s4.hands)

	# A straight with a gap is not a straight.
	var s5 = derive([climb(6, [[1, "send", 1], [2, "send", 1], [4, "send", 1], [5, "send", 1], [6, "send", 1]])])
	ok(s5.hands.straight == null, "V1 V2 V4 V5 V6 is no straight")

	# Straight flush V3-V7 and a flush (5 flashes V3+); Broadway needs a top of V8.
	var s6 = derive([climb(7, [[3, "flash", 1], [4, "flash", 1], [5, "flash", 1], [6, "flash", 1], [7, "flash", 1]])])
	ok(int(s6.hands.straightFlush) == 7 and has(s6, "hand_straight_flush") and has(s6, "hand_flush") and not has(s6, "hand_royal_flush") and not has(s6, "hand_broadway"), "V3-V7 flashed: straight flush and flush", s6.hands)

	# Flashes below V3 do not count toward a flush.
	var s7 = derive([climb(8, [[1, "flash", 3], [2, "flash", 2], [3, "flash", 4]])])
	ok(int(s7.hands.flush) == 4 and not has(s7, "hand_flush"), "only V3+ flashes count toward a flush", s7.hands)

	# Blackjack: exactly 21 sends.
	var s8 = derive([climb(9, [[2, "send", 10], [3, "send", 11]])])
	ok(s8.hands.blackjack and has(s8, "hand_blackjack"), "21 sends is blackjack")
	var s9 = derive([climb(10, [[2, "send", 10], [3, "send", 12]])])
	ok(not s9.hands.blackjack, "22 sends is not blackjack")

	# Snake eyes: exactly two V1s and nothing else (attempts allowed).
	var s10 = derive([climb(11, [[1, "send", 2], [4, "attempt", 3]])])
	ok(s10.hands.snakeEyes and has(s10, "hand_snake_eyes"), "two V1s alone is snake eyes")
	var s11 = derive([climb(12, [[1, "send", 2], [2, "send", 1]])])
	ok(not s11.hands.snakeEyes, "two V1s and a V2 is not snake eyes")

	# Lucky sevens, four of a kind, pocket sevens.
	var s12 = derive([climb(13, [[7, "send", 7]])])
	ok(has(s12, "hand_lucky_sevens") and has(s12, "hand_four") and has(s12, "hand_pocket_sevens"), "seven V7s")

	# Routes are a different deck: 5.xx sends never make a hand.
	var r = climb(14, [])
	r.climbs = [{"grade": 5, "result": "send", "count": 4, "style": "rope", "yds": "5.12a"}]
	var s13 = derive([r])
	ok(s13.hands.pair == null, "routes deal no hands", s13.hands)

	# Hands keep their best across sessions and the trophies pay XP once.
	var s14 = derive([climb(2, [[5, "send", 2]]), climb(15, [[3, "send", 2]])])
	ok(int(s14.hands.pair) == 5 and has(s14, "hand_pocket_fives"), "best pair is kept across sessions", s14.hands)
	ok(Achievements.all().size() == 148 and Achievements.by_id("hand_royal_flush") != null, "148 trophies in the catalog")

	print("HANDS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
