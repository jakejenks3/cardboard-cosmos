extends SceneTree
## Unit test for game/units.gd: the texts of the ported rules (kg, km) in the
## player's units, and the results reel's record cards written again from the
## real numbers. Made-up data.
##   godot --headless --path . --script res://tests/units_test.gd
## Prints UNITS: X/Y passed and exits with 1 when anything fails.

const LB = 0.45359237
const MI = 1609.344
const US = {"weightUnit": "lb", "distanceUnit": "mi"}
const METRIC = {"weightUnit": "kg", "distanceUnit": "km"}

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	# --- a text of the rules --------------------------------------------------------------------
	ok(Units.text("Lift 60 kg in a set.", US) == "Lift 132.3 lb in a set." and Units.text("Lift 100 kg in a set.", US) == "Lift 220.5 lb in a set." and Units.text("Lift 220 kg in a set.", US) == "Lift 485 lb in a set.", "the plate trophies in pounds", Units.text("Lift 60 kg in a set.", US))
	ok(Units.text("Move 10,000 kg in one session.", US) == "Move 22,046 lb in one session." and Units.text("Lift 1,000,000 kg lifetime.", US) == "Lift 2,204,623 lb lifetime." and Units.text("Move 1,000 kg in a single set (reps × weight).", US) == "Move 2,205 lb in a single set (reps × weight).", "big weights keep their commas", Units.text("Lift 1,000,000 kg lifetime.", US))
	ok(Units.text("Hang +20 kg on a 20 mm edge.", US) == "Hang +44.1 lb on a 20 mm edge.", "a hang's added weight; the edge stays in millimetres", Units.text("Hang +20 kg on a 20 mm edge.", US))
	ok(Units.text("Run 5 km in one go.", US) == "Run 3.11 mi in one go." and Units.text("Run 21.1 km in one go.", US) == "Run 13.11 mi in one go." and Units.text("Run 42.2 km in one go.", US) == "Run 26.22 mi in one go.", "run distances, exact enough to say what a threshold is", Units.text("Run 21.1 km in one go.", US))
	ok(Units.text("Ride 500 km lifetime.", US) == "Ride 310.7 mi lifetime." and Units.text("Ride 5,000 km lifetime.", US) == "Ride 3,107 mi lifetime." and Units.text("Ride 100 km in one go.", US) == "Ride 62.14 mi in one go.", "longer distances with fewer decimals", Units.text("Ride 500 km lifetime.", US))
	ok(Units.text("Ride 160 km (100 miles) in one go.", US) == "Ride 100 mi in one go.", "the imperial century is 100 miles", Units.text("Ride 160 km (100 miles) in one go.", US))
	ok(Units.text("Average 30 km/h over a 20 km+ ride.", US) == "Average 18.6 mph over a 12.43 mi+ ride.", "a speed and a distance in one text", Units.text("Average 30 km/h over a 20 km+ ride.", US))
	ok(Units.text("Average 5:00 /km or faster over 5 km+.", US) == "Average 8:03 /mi or faster over 3.11 mi+.", "a pace and a distance in one text", Units.text("Average 5:00 /km or faster over 5 km+.", US))
	ok(Units.text("Climb 1,000 m of elevation in one ride.", US) == "Climb 3,281 ft of elevation in one ride." and Units.text("80 m climbed", US) == "262 ft climbed", "metres of elevation in feet", Units.text("Climb 1,000 m of elevation in one ride.", US))
	ok(Units.text("A run of exactly 5.00 km. Not a step more.", US) == "A run of exactly 5.00 km. Not a step more." and Units.text("A ride of exactly 50.0 km.", US) == "A ride of exactly 50.0 km.", "a text about the very number is left alone")
	ok(Units.text("Run a half marathon (21.1 km) in one go", US) == "Run a half marathon (13.11 mi) in one go" and Units.text("Reach cycling level 30 or ride 5,000 km lifetime", US) == "Reach cycling level 30 or ride 3,107 mi lifetime", "what unlocks gear", Units.text("Run a half marathon (21.1 km) in one go", US))
	ok(Units.text("12,340 kg volume", US) == "27,205 lb volume" and Units.text("5.2 km", US) == "3.23 mi" and Units.text("30 min", US) == "30 min" and Units.text("12 reps", US) == "12 reps" and Units.text("", US) == "", "XP labels; minutes and reps are no units to change")
	ok(Units.text("Lift 60 kg in a set.", METRIC) == "Lift 60 kg in a set." and Units.text("Run 5 km in one go.", METRIC) == "Run 5 km in one go." and Units.text("Run 5 km in one go.", {}) == "Run 5 km in one go." and Units.text("Run 5 km in one go.", null) == "Run 5 km in one go.", "kg and km players see the texts as they are")
	ok(Units.text("Lift 60 kg in a set, then run 5 km.", {"weightUnit": "lb", "distanceUnit": "km"}) == "Lift 132.3 lb in a set, then run 5 km." and Units.text("Lift 60 kg in a set, then run 5 km.", {"weightUnit": "kg", "distanceUnit": "mi"}) == "Lift 60 kg in a set, then run 3.11 mi.", "each unit goes by its own setting")
	ok(Units.weight(10.0, "lb") == "22 lb" and Units.weight(20.0 * LB, "lb") == "20 lb" and Units.distance(13.1 * MI, "mi") == "13.1 mi" and Units.distance(5000.0, "mi") == "3.11 mi" and Units.distance(5000.0, "km") == "5 km", "no zeros at the end of a number", [Units.weight(10.0, "lb"), Units.distance(13.1 * MI, "mi")])

	# --- every trophy and every way to unlock gear -----------------------------------------------
	var left = []
	for a in Achievements.all():
		var t = Units.text(str(a.desc), US)
		if not str(a.desc).contains("exactly") and (t.contains(" kg") or t.contains(" km") or t.contains("/km") or t.contains("km/h") or t.contains(" m of elevation")):
			left.append(t)
	for it in Items.all():
		var t = Units.text(Items.unlock_hint(it), US)
		if t.contains(" kg") or t.contains(" km") or t.contains(" m of elevation"):
			left.append(t)
	for p in Pets.all():
		var t = Units.text(str(p.hint), US)
		if t.contains(" kg") or t.contains(" km") or t.contains(" m of elevation"):
			left.append(t)
	ok(left.is_empty(), "no trophy, gear or companion text is left in kg or km for a pounds and miles player", left)
	var same = Achievements.all().all(func(a): return Units.text(str(a.desc), METRIC) == str(a.desc))
	ok(same, "and none changes for a kg and km player")

	# --- the reel's record cards -------------------------------------------------------------------
	var bp = {"lifts": {"bench press - barbell": {"weightKg": 225.0 * LB, "e1rm": 250.0 * LB, "reps": 3}, "squat - barbell": {"weightKg": 300.0 * LB, "e1rm": 330.0 * LB, "reps": 3}},
		"longestRunM": 10.0 * MI, "longestRideM": 0.0, "bestPaceSecPerKm": 330.0, "bestRideSpeedKmh": 24.0, "bestHangKg": 10.0 * LB}
	var ap = {"lifts": {"bench press - barbell": {"weightKg": 230.0 * LB, "e1rm": 255.0 * LB, "reps": 3}, "squat - barbell": {"weightKg": 300.0 * LB, "e1rm": 340.0 * LB, "reps": 5}, "new lift": {"weightKg": 50.0, "e1rm": 55.0, "reps": 5}},
		"longestRunM": 13.1 * MI, "longestRideM": 20000.0, "bestPaceSecPerKm": 300.0, "bestRideSpeedKmh": 30.0, "bestHangKg": 25.0 * LB}
	var evs = [
		{"type": "xp", "xp": 120},
		{"type": "pr", "title": "Bench Press - Barbell PR", "detail": "104.3 kg (was 102.1 kg)"},
		{"type": "pr", "title": "Squat - Barbell est. 1RM PR", "detail": "154.2 kg (was 149.7 kg)"},
		{"type": "pr", "title": "Heaviest hang!", "detail": "+11.3 kg (was +4.5 kg)"},
		{"type": "pr", "title": "Longest run!", "detail": "21.1 km (was 16.1 km)"},
		{"type": "pr", "title": "Fastest pace (5 km+)!", "detail": "5:00 /km (was 5:30)"},
		{"type": "pr", "title": "Fastest ride (20 km+)!", "detail": "30.0 km/h (was 24.0)"},
		{"type": "pr", "title": "New max grade!", "detail": "V5 (was V4)"},
	]
	var out = Units.records(evs, bp, ap, US)
	ok(out.size() == evs.size() and out[0] == evs[0] and out[7] == evs[7], "the other cards are left as they are", out)
	ok(str(out[1].title) == "Bench Press - Barbell PR" and str(out[1].detail) == "230 lb (was 225 lb)", "a lift record in pounds, from the real weights (230, not 229.9)", out[1])
	ok(str(out[2].detail) == "340 lb (was 330 lb)", "an estimate record in pounds", out[2])
	ok(str(out[3].detail) == "+25 lb (was +10 lb)", "a hang record in pounds", out[3])
	ok(str(out[4].detail) == "13.1 mi (was 10 mi)", "the longest run in miles", out[4])
	ok(str(out[5].title) == "Fastest pace (3.11 mi+)!" and str(out[5].detail) == "8:03 /mi (was 8:51)", "the fastest pace per mile, title and all", out[5])
	ok(str(out[6].title) == "Fastest ride (12.43 mi+)!" and str(out[6].detail) == "18.6 mph (was 14.9)", "the fastest ride in miles an hour", out[6])
	ok(str(evs[1].detail) == "104.3 kg (was 102.1 kg)" and Units.records(evs, bp, ap, METRIC) == evs and Units.records(evs, bp, ap, {}) == evs and Units.records(evs, null, ap, US) == evs, "the events given are untouched; kg and km players get them as they are")
	var first_hang = Units.records([{"type": "pr", "title": "Heaviest hang!", "detail": "+11.3 kg"}], {"lifts": {}}, {"lifts": {}, "bestHangKg": 25.0 * LB}, US)
	ok(str(first_hang[0].detail) == "+25 lb", "a first weighted hang", first_hang)
	var only_lb = Units.records(evs, bp, ap, {"weightUnit": "lb", "distanceUnit": "km"})
	ok(str(only_lb[1].detail) == "230 lb (was 225 lb)" and str(only_lb[4].detail) == "21.1 km (was 16.1 km)" and str(only_lb[5].title) == "Fastest pace (5 km+)!", "pounds with kilometres: only the weights change", only_lb)

	# --- a session's XP labels ----------------------------------------------------------------------
	var lift = {"discipline": "lift", "exercises": [{"name": "Bench Press - Barbell", "sets": [{"reps": 5, "weightKg": 200.0 * LB}, {"reps": 5, "weightKg": 200.0 * LB}]}]}
	ok(Units.xp_label(lift, "907 kg volume", US) == "2,000 lb volume" and Units.xp_label(lift, "10 reps", US) == "10 reps" and Units.xp_label(lift, "907 kg volume", METRIC) == "907 kg volume", "a lift's volume from its own sets", Units.xp_label(lift, "907 kg volume", US))
	var run = {"discipline": "run", "distanceM": 13.1 * MI, "elevationM": 100.0 / 3.28084, "durationSec": 6900}
	ok(Units.xp_label(run, "21.1 km", US) == "13.1 mi" and Units.xp_label(run, "30 m climbed", US) == "100 ft climbed" and Units.xp_label(run, "60 min", US) == "60 min", "a run's distance and climb from its own numbers (13.1, not 13.11)", [Units.xp_label(run, "21.1 km", US), Units.xp_label(run, "30 m climbed", US)])
	var walk = {"discipline": "misc", "kind": "vest_walk", "distanceM": 2.0 * MI, "loadKg": 20.0 * LB, "elevationM": 0.0}
	ok(Units.xp_label(walk, "3.2 km carrying 9.1 kg", US) == "2 mi carrying 20 lb" and Units.xp_label(walk, "3.2 km carrying 9.1 kg", {"weightUnit": "lb", "distanceUnit": "km"}) == "3.2 km carrying 20 lb", "a vest walk: its distance and its load (20 lb, not 20.1)", Units.xp_label(walk, "3.2 km carrying 9.1 kg", US))

	# --- the one-side card of a lift logged as both sides (Sides) in pounds ---------------------------
	var before_log = [{"id": "a", "discipline": "lift", "date": "2026-11-10", "createdAt": 1, "exercises": [{"name": "Lateral Raise - Cable", "sets": [{"reps": 20, "weightKg": 15.0 * LB}]}]}]
	var fresh = {"id": "b", "discipline": "lift", "date": "2026-11-13", "createdAt": 2, "exercises": [{"name": "Lateral Raise - Cable", "sets": [{"reps": 24, "weightKg": 15.0 * LB}]}]}
	var side = Sides.fix_estimates([{"type": "pr", "title": "Lateral Raise - Cable est. 1RM PR", "detail": "12.2 kg (was 11.3 kg)"}], [fresh], before_log, US)
	ok(side.size() == 1 and str(side[0].detail) == "21 lb (was 20 lb), going by one side", "a both-sides lift's estimate card in pounds", side)

	print("UNITS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
