extends SceneTree
## Unit test for game/challenges.gd: the day's records to go for on a lift.
##   godot --headless --path . --script res://tests/challenges_test.gd
## Prints CHALLENGES: X/Y passed and exits with 1 when anything fails.

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
	var fmt = func(kg): return "%s kg" % TTUtil.num_str(float(kg))
	# Newest first, as the game keeps a lift's history.
	var hist = [_h("2026-11-24", 62.5, [8, 7, 7]), _h("2026-11-20", 60.0, [10, 10, 9]), _h("2026-11-16", 60.0, [9, 9, 8]), _h("2026-11-12", 50.0, [12, 12])]
	var o = Challenges.options("Bench Press - Barbell", hist, "2026-11-27", 2.5, fmt)
	var types = o.map(func(x): return str(x.type))
	ok(o.size() == 3 and types[0] == "heavier" and types[1] == "reps" and types.has("ladder"), "three picks: heavier, a rep record, a best for N", types)
	ok(is_equal_approx(float(o[0].kg), 65.0) and int(o[0].reps) == 6 and str(o[0].words) == "65 kg × 6" and str(o[0].sub) == "Your heaviest: 62.5 kg × 8", "heavier than ever: a step past the heaviest, two reps under its best there", o[0])
	ok(int(o[1].reps) == int(LiftProgress.best_reps(hist).filter(func(b): return is_equal_approx(float(b.rung), float(o[1].kg)))[0].reps) + 1, "a rep record: one more than the best at that weight", o[1])
	var lad = o.filter(func(x): return str(x.type) == "ladder")[0]
	ok(float(lad.kg) < 65.0 - 1e-6 + 2.5 and float(lad.kg) - 2.5 < 62.5, "a best for N is below the heaviest (else heavier than ever asks)", lad)
	# The picks move with the date.
	var seen = {}
	for d in ["2026-11-27", "2026-11-28", "2026-11-29", "2026-11-30", "2026-12-01", "2026-12-02"]:
		var od = Challenges.options("Bench Press - Barbell", hist, d, 2.5, fmt)
		seen[str(od.map(func(x): return str(x.words)))] = true
	ok(seen.size() >= 2, "the picks are not the same every day (%d different in 6 days)" % seen.size(), seen.keys())
	# Hit.
	ok(Challenges.hit(o[0], _sets(65.0, [6])) and not Challenges.hit(o[0], _sets(65.0, [5])) and not Challenges.hit(o[0], _sets(62.5, [10])), "heavier: that weight for those reps")
	ok(Challenges.hit(o[1], _sets(float(o[1].kg), [int(o[1].reps)])) and Challenges.hit(o[1], _sets(float(o[1].kg) + 2.5, [int(o[1].reps)])) and not Challenges.hit(o[1], _sets(float(o[1].kg), [int(o[1].reps) - 1])), "a rep record: the reps at that weight or heavier")
	ok(Challenges.hits(o, _sets(65.0, [6, 6])).has("heavier"), "hits by type")
	# Bodyweight, band, hold, never done.
	var bw = Challenges.options("Pull-up", [_h("2026-11-20", 0.0, [10, 8, 7]), _h("2026-11-16", 0.0, [11, 7])], "2026-11-27", 2.5, fmt)
	ok(bw.size() == 2 and int(bw[0].reps) == 12 and int(bw[1].reps) == 27, "bodyweight: one more in a set, two more in a day", bw)
	ok(Challenges.hit(bw[1], _sets(0.0, [10, 9, 8])) and not Challenges.hit(bw[0], _sets(0.0, [11, 11])), "and their hits")
	var band = Challenges.options("Face Pull - Band", [{"date": "2026-11-20", "sets": [{"reps": 15, "weightKg": 0.0, "band": "green"}]}], "2026-11-27", 2.5, fmt)
	ok(band.size() == 2 and str(band[0].type) == "band" and str(band[0].band) == Bands.LADDER[Bands.level("green")] and int(band[1].reps) == 16, "a band: the next band up, or a rep more with it", band)
	var hold = Challenges.options("Plank", [{"date": "2026-11-20", "sets": [{"reps": 3, "weightKg": 0.0, "holdSec": 30}]}], "2026-11-27", 2.5, fmt)
	ok(hold.size() == 1 and int(hold[0].sec) == 35, "a hold: five seconds longer", hold)
	ok(Challenges.options("Squat", [], "2026-11-27", 2.5, fmt).is_empty(), "never done: nothing yet")
	# Any record.
	ok(Challenges.any_record(_sets(62.5, [9]), hist) and Challenges.any_record(_sets(67.5, [1]), hist) and not Challenges.any_record(_sets(60.0, [10]), hist), "any record: a rep record or a heavier set; a tie is none")
	print("CHALLENGES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
