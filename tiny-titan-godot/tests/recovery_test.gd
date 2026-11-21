extends SceneTree
## Unit test for game/recovery.gd (how recently each body part was worked) and
## the muscle map (HeroBody.draw_muscle_map). Made-up data.
##   godot --headless --path . --script res://tests/recovery_test.gd
## Prints RECOVERY: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-21"

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func lift(date: String, exercises: Dictionary) -> Dictionary:
	_n += 1
	var exs = []
	for name in exercises:
		var sets = []
		for i in range(int(exercises[name])):
			sets.append({"reps": 8, "weightKg": 40.0})
		exs.append({"name": name, "sets": sets})
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "exercises": exs}


func _init() -> void:
	var log = [
		lift(TODAY, {"Bench Press - Barbell": 4}),
		lift("2026-11-20", {"Squat - Barbell": 4, "Bicep Curl - Dumbbell": 2}),
		{"id": "c1", "discipline": "climb", "date": "2026-11-19", "climbs": []},
		{"id": "r1", "discipline": "run", "date": "2026-11-20", "distanceM": 5000.0},
		lift("2026-11-10", {"Deadlift - Barbell": 5}),
	]
	var h = Recovery.heat(log, TODAY)
	ok(is_equal_approx(float(h.chest.heat), 1.0) and int(h.chest.days) == 0, "four sets of bench today: chest at full heat", h.chest)
	ok(is_equal_approx(float(h.triceps.heat), 0.5) and is_equal_approx(float(h.shoulders.heat), 0.5), "the parts bench also works: half", [h.triceps, h.shoulders])
	ok(absf(float(h.quads.heat) - 2.0 / 3.0) < 0.01 and int(h.quads.days) == 1, "squats yesterday: quads two thirds (big muscle, three days)", h.quads)
	ok(absf(float(h.biceps.heat) - 0.25) < 0.01, "two sets of curls yesterday: half a day's work, half recovered (small muscle, two days)", h.biceps)
	ok(absf(float(h.forearms.heat) - 0.125) < 0.01, "forearms: the climb two days ago is recovered (small muscle); yesterday's curls warm them a little", h.forearms)
	ok(absf(float(h.calves.heat) - 0.4) < 0.01, "a run yesterday warms the calves", h.calves)
	ok(absf(float(h.back.heat) - 0.8 * (1.0 - 2.0 / 3.0)) < 0.01 and str(h.back.last) == "2026-11-19", "back: the climb two days ago, a third left (big muscle); deadlifts eleven days ago not counted", h.back)
	var warm = Recovery.warm(h, 0.15)
	ok(warm.size() >= 4 and warm[0].part == "chest" and warm.all(func(w): return float(w.heat) >= 0.15), "the warm parts, hottest first", warm)
	ok(Recovery.also_parts("Bench Press - Barbell").has("triceps") and Recovery.also_parts("Bench Press - Barbell").has("shoulders"), "bench also works triceps and shoulders", Recovery.also_parts("Bench Press - Barbell"))
	ok(Recovery.when(0) == "today" and Recovery.when(1) == "yesterday" and Recovery.when(3) == "3 days ago", "when")

	# The map: pec pixels change with chest heat, the calves do not.
	var input = {"heroLevel": 20, "liftLevel": 15, "climbLevel": 10, "runLevel": 5, "rideLevel": 5, "skin": 1, "hairStyle": 0,
		"hairColor": 1, "facialHair": 2, "pose": "idle", "frame": 0, "blink": false, "happy": false}
	var cold = Pix.new(HeroBody.width(), HeroBody.height())
	HeroBody.draw_muscle_map(cold, input, Recovery.heat([], TODAY))
	var warm_map = Pix.new(HeroBody.width(), HeroBody.height())
	HeroBody.draw_muscle_map(warm_map, input, h)
	var m = HeroFigure.metrics(input)
	var changed = {}
	for k in range(cold.data.size()):
		if cold.data[k] != warm_map.data[k]:
			var pi = m.fig.owner[k]
			if pi >= 0:
				var name = str(m.fig.parts[pi].name)
				changed[name] = int(changed.get(name, 0)) + 1
	ok(changed.has("pecL") and changed.has("pecR") and changed.has("thighL"), "chest and thighs glow", changed.keys())
	ok(not changed.has("head") and not changed.has("footL") and not changed.has("footR"), "the head and feet never do", changed.keys())
	var px = 0
	for v in cold.data:
		if v != 0:
			px += 1
	ok(px > 800, "the map is a whole figure (%d pixels)" % px)
	# Mood: pumped on a workout day, tired after six days in a row (a rest day ends it).
	var streak = []
	for k in range(6):
		streak.append(lift(Dates.add_days(TODAY, -k), {"Plank": 1}))
	ok(Recovery.mood(streak, TODAY) == "tired" and Recovery.mood(streak.slice(0, 5), TODAY) == "pumped" and Recovery.mood(streak.slice(1), TODAY) == "", "six days in a row: tired; five with today: pumped; a rest today: nothing",
		[Recovery.mood(streak, TODAY), Recovery.mood(streak.slice(0, 5), TODAY), Recovery.mood(streak.slice(1), TODAY)])
	var moods = {}
	for md in ["", "pumped", "tired"]:
		var one = Pix.new(HeroBody.width(), HeroBody.height())
		var inp = input.duplicate()
		inp["mood"] = md
		HeroBody.draw_hero(one, inp, {"visuals": {}})
		moods[md] = one.data
	ok(moods[""] != moods["pumped"] and moods[""] != moods["tired"] and moods["pumped"] != moods["tired"], "each mood draws the hero differently")
	print("RECOVERY: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
