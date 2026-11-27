extends SceneTree
## Unit test for game/lift_names.gd (movement + variation) and the movement
## catalog (LiftLibrary.MOVES).
##   godot --headless --path . --script res://tests/lift_names_test.gd
## Prints LIFTNAMES: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func name_of(typed: String, own: Array = []) -> String:
	return str(LiftNames.resolve(typed, own).name)


func _init() -> void:
	# --- the catalog ------------------------------------------------------------------
	var cat = LiftLibrary.catalog()
	var part_ids = LiftLibrary.PARTS.map(func(p): return p.id)
	var seen = {}
	var dupes = []
	var bad = []
	var not_canon = []
	var vocab_names = []
	for e in cat:
		if not part_ids.has(e.part) or str(e.tip).length() < 10:
			bad.append(e.name)
		for k in e.keys:
			if seen.has(k):
				dupes.append("%s (%s and %s)" % [k, seen[k], e.name])
			seen[k] = e.name
		for v in e.vars:
			var again = LiftNames.canon(LiftMatch.words(str(v)), e)
			if again != str(v):
				not_canon.append("%s - %s -> %s" % [e.name, v, again])
		# Another name may only hold a variation word its movement never says
		# (the cable of a cable row) or one that is part of what it means.
		for o in e.names:
			for ph in LiftNames.phrases_in(LiftMatch.words(str(o))):
				var own_word = LiftMatch.words(str(e.name)).has(LiftMatch.words(ph)[0] if not LiftMatch.words(ph).is_empty() else "")
				if not own_word and not e.only.has(ph) and str(e.usual) != ph and not ["Reverse", "Side", "Seated", "Donkey"].has(ph):
					vocab_names.append("%s: %s (%s)" % [e.name, o, ph])
	ok(cat.size() >= 80, "at least 80 movements", cat.size())
	ok(bad.is_empty(), "every movement has a known part and a tip", bad)
	ok(dupes.is_empty(), "no name is claimed by two movements", dupes)
	ok(not_canon.is_empty(), "every catalog variation is written the way canon writes it", not_canon)
	ok(vocab_names.is_empty(), "other names carry no variation words", vocab_names)
	for p in LiftLibrary.PARTS:
		if p.id != "other":
			ok(cat.any(func(e): return e.part == p.id), "the %s section has movements" % p.name)
	var resolved_vars = []
	for e in cat:
		for v in e.vars:
			var full = LiftNames.join(str(e.name), str(v))
			if name_of(full) != full:
				resolved_vars.append("%s -> %s" % [full, name_of(full)])
	ok(resolved_vars.is_empty(), "every catalog movement and variation reads back as itself", resolved_vars)

	# --- split and join ------------------------------------------------------------------
	ok(LiftNames.split("Shrug - Barbell") == {"move": "Shrug", "variation": "Barbell"} and LiftNames.split("Pull-up") == {"move": "Pull-up", "variation": ""} and LiftNames.split("T-Bar Row - Landmine").move == "T-Bar Row", "split at ' - ' only, never at a hyphen inside a name")
	ok(LiftNames.join("Shrug", "Barbell") == "Shrug - Barbell" and LiftNames.join("Pull-up", "") == "Pull-up", "join")

	# --- the user's way of writing ----------------------------------------------------------
	ok(name_of("shrug - barbell") == "Shrug - Barbell" and name_of("barbell shrug") == "Shrug - Barbell" and name_of("shrugs barbell") == "Shrug - Barbell", "the equipment is the variation, wherever it is written", [name_of("barbell shrug"), name_of("shrugs barbell")])
	ok(name_of("bent-over rows, dumbbell") == "Bent Over Row - Dumbbell" and name_of("bent over row - barbell") == "Bent Over Row - Barbell" and name_of("bent over row") == "Bent Over Row - Barbell", "bent over row, by equipment; barbell when none is said")
	ok(name_of("lat pull-down - 1UE cable") == "Lat Pulldown - Single arm" and name_of("lat pulldown, single arm cable") == "Lat Pulldown - Single arm" and name_of("1 arm lat pulldown, pulley") == "Lat Pulldown - Single arm", "three ways of writing a single arm pulldown are one lift; the cable is not said", [name_of("lat pull-down - 1UE cable"), name_of("1 arm lat pulldown, pulley")])
	ok(name_of("Bicep Curls - Reclined") == "Bicep Curl - Reclined" and name_of("reclined bicep curl") == "Bicep Curl - Reclined", "a position alone stays as written")
	ok(name_of("Cable Chest Fly") == "Chest Fly - Cable" and name_of("chest flys - cable") == "Chest Fly - Cable", "chest fly, cable")
	ok(name_of("Cable Lateral Raises") == "Lateral Raise - Cable" and name_of("lateral raises - cable") == "Lateral Raise - Cable" and name_of("lateral raise") == "Lateral Raise - Dumbbell", "lateral raise: cable, or dumbbell when none is said")
	ok(name_of("Tricep Pushdowns, Cable With Rope") == "Tricep Pushdown - Rope" and name_of("triceps rope push-down") == "Tricep Pushdown - Rope", "a rope is a cable attachment: only the rope is said", name_of("Tricep Pushdowns, Cable With Rope"))
	ok(name_of("GHD Situps") == "Sit-up - GHD" and name_of("ghd sit up") == "Sit-up - GHD", "GHD sit-ups", name_of("GHD Situps"))
	ok(name_of("Squat") == "Squat - Barbell" and name_of("front squat") == "Squat - Front" and name_of("front squat barbell") == "Squat - Front" and name_of("goblet squat") == "Squat - Goblet" and name_of("goblet squat kettlebell") == "Squat - Goblet kettlebell", "squat: barbell when nothing is said; a position needs no barbell", [name_of("front squat barbell"), name_of("goblet squat kettlebell")])
	ok(name_of("Heel Raise") == "Calf Raise" and name_of("seated calf raise machine") == "Calf Raise - Seated machine", "heel raise is a calf raise")
	ok(name_of("Romanian Deadlift") == "Romanian Deadlift - Barbell" and name_of("rdl") == "Romanian Deadlift - Barbell" and name_of("sl rdl") == "Romanian Deadlift - Single leg" and name_of("single leg rdl dumbbell") == "Romanian Deadlift - Single leg dumbbell", "RDLs", [name_of("sl rdl"), name_of("single leg rdl dumbbell")])
	ok(name_of("face pull - red superband") == "Face Pull - Red band" and name_of("face pull") == "Face Pull" and name_of("face pull - rope") == "Face Pull", "face pull: the rope and the cable go without saying; a band is a variation", name_of("face pull - red superband"))
	ok(name_of("Neck 4 Way") == "Neck 4 Way" and name_of("hip airplanes") == "Hip Airplane" and name_of("Jefferson Curl") == "Jefferson Curl", "a movement of the player's own keeps its words", [name_of("hip airplanes")])
	ok(name_of("bench") == "Bench Press - Barbell" and name_of("incline bench") == "Bench Press - Incline" and name_of("incline db press") == "Bench Press - Incline dumbbell" and name_of("close grip bench press") == "Bench Press - Close grip", "bench press variations", [name_of("incline bench"), name_of("incline db press")])
	ok(name_of("pec deck") == "Chest Fly - Machine" and name_of("skull crushers") == "Tricep Extension - Lying EZ bar" and name_of("chest press") == "Bench Press - Machine", "names that hide a variation")
	ok(name_of("pull ups") == "Pull-up" and name_of("weighted pull-up") == "Pull-up - Weighted" and name_of("pullup - bodyweight") == "Pull-up", "bodyweight movements say no bodyweight")
	ok(name_of("seated cable row") == "Seated Row" and name_of("seated row single arm") == "Seated Row - Single arm" and name_of("machine row") == "Seated Row - Machine", "seated row")
	ok(name_of("hammer curls") == "Hammer Curl - Dumbbell" and name_of("rope hammer curl") == "Hammer Curl - Rope", "hammer curls")
	ok(name_of("deadlift - trap bar") == "Deadlift - Trap bar" and name_of("hex bar deadlift") == "Deadlift - Trap bar" and name_of("sumo deadlift") == "Deadlift - Sumo", "deadlifts")
	ok(name_of("single arm cable lateral raise") == "Lateral Raise - Single arm cable" and name_of("cable lateral raise, single arm") == "Lateral Raise - Single arm cable", "word order does not matter")
	ok(name_of("hip thrust") == "Hip Thrust - Barbell" and name_of("single leg hip thrust") == "Hip Thrust - Single leg", "hip thrust")
	ok(name_of("calf stretch - slant board") == "Calf Stretch - Slant board" and name_of("slant board calf stretch") == "Calf Stretch - Slant board" and name_of("slant board") == "Calf Stretch - Slant board" and name_of("wall calf stretch") == "Calf Stretch - Wall", "stretches have variations too")

	# --- how sure ------------------------------------------------------------------------
	ok(LiftNames.resolve("shrug - barbell").kind == "exact" and LiftNames.resolve("bent over row - barbell").kind == "exact" and LiftNames.resolve("heel raise").kind == "exact", "found by name: sure")
	ok(LiftNames.resolve("row").kind == "match" and LiftNames.resolve("barbell row").kind == "match" and LiftNames.resolve("curl").kind == "match", "found by one generic word: the review asks", [LiftNames.resolve("barbell row").kind])
	var jc = LiftNames.resolve("jefferson curl")
	ok(jc.kind == "new" and jc.name == "Jefferson Curl" and jc.closest == "Bicep Curl", "a curl that is not a bicep curl is new, with the closest offered", jc)
	ok(LiftNames.resolve("neck 4 way").kind == "new" and LiftNames.resolve("neck 4 way").closest == "", "nothing near: new, nothing offered")
	ok(LiftNames.resolve("bicpe curl - dumbbell").kind == "match" and LiftNames.resolve("bicpe curl - dumbbell").name == "Bicep Curl - Dumbbell", "a typo: taken, and asked", LiftNames.resolve("bicpe curl - dumbbell"))
	var cw = LiftNames.resolve("cable woodchopper")
	ok(cw.name == "Woodchop - Cable", "another name of a movement with its equipment", cw)
	var nw = LiftNames.resolve("cable zercher hold")
	ok(nw.kind == "new" and nw.name == "Zercher Hold - Cable", "a new movement gives its equipment words to the variation", nw)

	# --- the player's own lifts ------------------------------------------------------------
	var own = ["Neck 4 Way", "Shrug - Barbell", "PT Squat - Barbell"]
	ok(name_of("neck 4 way", own) == "Neck 4 Way" and LiftNames.resolve("neck 4 way", own).kind == "exact", "their own movement, as logged")
	ok(name_of("neck 4 way - light", own) == "Neck 4 Way - Light", "their own movement with a variation", name_of("neck 4 way - light", own))
	ok(name_of("pt squat - barbell", own) == "PT Squat - Barbell", "a name in their log is kept exactly")

	# --- variations in one spelling ----------------------------------------------------------
	ok(LiftNames.canon(LiftMatch.words("cable, single arm")) == "Single arm cable" and LiftNames.canon(LiftMatch.words("dumbbell incline")) == "Incline dumbbell" and LiftNames.canon(LiftMatch.words("ez bar preacher")) == "Preacher EZ bar", "positions first, then equipment", LiftNames.canon(LiftMatch.words("ez bar preacher")))
	ok(LiftNames.canon(LiftMatch.words("ghd")) == "GHD" and LiftNames.canon(LiftMatch.words("green band")) == "Green band" and LiftNames.canon(LiftMatch.words("kettlebell single leg")) == "Single leg kettlebell", "short forms in capitals; colours before the band")
	ok(LiftNames.gear_of("Single arm cable") == ["cable"] and LiftNames.gear_of("Incline dumbbell") == ["dumbbell"] and LiftNames.gear_of("Reclined").is_empty(), "the equipment a variation names")

	# --- old names into the new form ----------------------------------------------------------
	var sp = {"SL KB RDL": "Romanian Deadlift - Single leg kettlebell"}
	var olds = {"dumbbell bent over row": "Bent Over Row - Dumbbell", "lat pull-down - cable, 1UE": "Lat Pulldown - Single arm",
		"Bicep Curls - reclined": "Bicep Curl - Reclined", "Squat": "Squat - Barbell", "Heel Raises": "Calf Raise",
		"Cable Chest Fly": "Chest Fly - Cable", "Cable Lateral Raise": "Lateral Raise - Cable",
		"Rope Tricep Pushdown": "Tricep Pushdown - Rope", "GHD Sit-up": "Sit-up - GHD",
		"Neck 4 Way": "Neck 4 Way", "Romanian Deadlift": "Romanian Deadlift - Barbell", "SL KB RDL": "Romanian Deadlift - Single leg kettlebell",
		"Barbell Row": "Bent Over Row - Barbell",
		"Barbell Shrug": "Shrug - Barbell", "Bench Press": "Bench Press - Barbell", "Incline Dumbbell Press": "Bench Press - Incline dumbbell",
		"Cable Fly": "Chest Fly - Cable", "Dumbbell Row": "Bent Over Row - Dumbbell", "Seated Cable Row": "Seated Row"}
	var wrong = []
	for o in olds:
		if LiftNames.migrate(o, sp) != olds[o]:
			wrong.append("%s -> %s (want %s)" % [o, LiftNames.migrate(o, sp), olds[o]])
	ok(wrong.is_empty(), "old names into movement - variation", wrong)
	var stable = []
	for o in olds:
		var once = LiftNames.migrate(o, sp)
		if LiftNames.migrate(once, sp) != once:
			stable.append(once)
	ok(stable.is_empty(), "a migrated name migrates to itself", stable)
	print("LIFTNAMES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
