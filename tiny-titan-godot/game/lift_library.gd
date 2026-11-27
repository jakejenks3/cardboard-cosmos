class_name LiftLibrary
extends RefCounted
## The lift library: a catalog of MOVEMENTS, each with the variations it is
## done in (position and equipment), joined with what the player has logged.
## A logged lift is named "Movement - Variation" (see game/lift_names.gd), so
## its stats are per variation and the library groups them under the movement.
## Pure logic (no scene, no autoload): tests/lift_library_test.gd. The screen
## is ui/screens/journey_lifts.gd.
##
## Entry (catalog): {name, part, usual (the variation when none is written, or
##   ""), only ([equipment never said: "Cable" for a lat pulldown]), equip (its
##   main equipment id), equips ([every equipment id of its variations]),
##   family (= name), also, tip, vars ([variations]), names ([other names]),
##   keys ([normalized name and other names]), own: false}
## Stats (per normalized full name, see `stats`): {name (as logged), count,
##   last (date), bestKg, bestReps (reps of the heaviest set), e1rm, bwReps,
##   volumeKg, reps, history: [{date, id, sets}] newest first}
## Row (`rows`): an Entry plus "done": [{variation, name, st}] (the variations
##   logged, most recent first) and "st": the stats of all of them together, or
##   null when the movement was never done. A movement of the player's own is a
##   row with own: true.

const PARTS = [
	{"id": "chest", "name": "Chest"},
	{"id": "back", "name": "Back"},
	{"id": "shoulders", "name": "Shoulders"},
	{"id": "biceps", "name": "Biceps"},
	{"id": "triceps", "name": "Triceps"},
	{"id": "forearms", "name": "Forearms"},
	{"id": "quads", "name": "Quads"},
	{"id": "hamstrings", "name": "Hamstrings"},
	{"id": "glutes", "name": "Glutes"},
	{"id": "calves", "name": "Calves"},
	{"id": "core", "name": "Core"},
	{"id": "mobility", "name": "Mobility"},
	{"id": "full", "name": "Full body"},
	{"id": "other", "name": "Your own"},
]

const EQUIPMENT = [
	{"id": "barbell", "name": "Barbell"},
	{"id": "dumbbell", "name": "Dumbbell"},
	{"id": "cable", "name": "Cable"},
	{"id": "machine", "name": "Machine"},
	{"id": "bodyweight", "name": "Bodyweight"},
	{"id": "kettlebell", "name": "Kettlebell"},
	{"id": "band", "name": "Band"},
	{"id": "other", "name": "Other"},
]

const SORTS = [
	{"value": "part", "label": "Body part"},
	{"value": "name", "label": "A-Z"},
	{"value": "count", "label": "Most done"},
	{"value": "best", "label": "Heaviest"},
	{"value": "recent", "label": "Recent"},
]

const REP_MARKS = [1, 3, 5, 8, 10, 12]

## [movement, part, usual variation, [equipment never said], also works, tip,
##  [variations], [other names]]. Variations are written the way
## LiftNames.canon writes them (tests check it): positions first, then
## equipment; the usual equipment is left out next to a position ("Squat -
## Front" is a barbell front squat). Other names never carry a variation word:
## "row" is Bent Over Row, and "dumbbell row" is Bent Over Row - Dumbbell.
const MOVES = [
	# --- chest ---------------------------------------------------------------
	["Bench Press", "chest", "Barbell", ["Flat"], "triceps, front delts", "Shoulder blades pinched, bar to mid-chest, feet planted.",
		["Barbell", "Incline", "Decline", "Close grip", "Paused", "Dumbbell", "Incline dumbbell", "Decline dumbbell", "Machine", "Smith machine", "Incline smith machine"],
		["bench", "bp", "benchpress"]],
	["Chest Fly", "chest", "", [], "front delts", "Soft elbows and a wide arc; squeeze the hands together.",
		["Dumbbell", "Incline dumbbell", "Cable", "Low to high cable", "High to low cable", "Machine"],
		["fly", "pec fly"]],
	["Push-up", "chest", "", ["Bodyweight"], "triceps, core", "Body in one straight line, chest to the floor.",
		["Incline", "Decline", "Diamond", "Wide grip", "Kneeling", "Pike", "Weighted"],
		["pushup", "press up", "pressup"]],
	["Dip", "chest", "", ["Bodyweight"], "triceps, front delts", "Lean forward for chest, stay upright for triceps.",
		["Weighted", "Assisted", "Bench", "Machine", "Rings"],
		["parallel bar dip", "chest dip"]],
	["Pullover", "chest", "Dumbbell", [], "lats, triceps", "Arms long; lower behind your head and pull back over the chest.",
		["Dumbbell", "Cable", "Barbell"],
		[]],
	# --- back ----------------------------------------------------------------
	["Deadlift", "back", "Barbell", [], "glutes, hamstrings, grip", "Bar over mid-foot; brace and push the floor away.",
		["Barbell", "Sumo", "Deficit", "Paused", "Trap bar", "Dumbbell", "Kettlebell"],
		["dl", "dls", "dead", "deads", "conventional deadlift"]],
	["Rack Pull", "back", "Barbell", [], "traps, grip", "The top half of a deadlift, from pins or blocks.",
		["Barbell", "Trap bar"],
		["block pull"]],
	["Bent Over Row", "back", "Barbell", [], "biceps, rear delts", "Hinge to about 45 degrees and pull to the belly.",
		["Barbell", "Pendlay", "Underhand", "Dumbbell", "Single arm dumbbell", "Kettlebell", "Smith machine"],
		["row", "bent row", "bbrow"]],
	["Seated Row", "back", "", ["Cable"], "biceps, rear delts", "Sit tall, pull to the stomach, let the shoulders stretch forward.",
		["Wide grip", "Single arm", "Machine", "Band"],
		["cable row", "seated cable row"]],
	["Chest-Supported Row", "back", "", [], "rear delts, biceps", "Chest on an incline bench; pull without swinging.",
		["Dumbbell", "Barbell", "Machine"],
		["chest supported row", "seal row"]],
	["T-Bar Row", "back", "", [], "biceps, lower back", "Chest over the bar; pull to the stomach.",
		["Landmine", "Machine"],
		["tbar row"]],
	["Inverted Row", "back", "", ["Bodyweight"], "biceps, core", "Body straight under a bar; chest to the bar.",
		["Feet elevated", "Weighted", "TRX", "Rings"],
		["body row", "australian pull-up"]],
	["Lat Pulldown", "back", "", ["Cable"], "biceps", "Lean back a little; pull to the collarbone.",
		["Wide grip", "Close grip", "Neutral grip", "Underhand", "Single arm", "Machine"],
		["pulldown", "lat pull down", "lat pull"]],
	["Straight-Arm Pulldown", "back", "", ["Cable"], "lats, triceps", "Arms nearly straight; sweep the bar to your thighs.",
		["Rope", "Straight bar", "Band"],
		["lat prayer"]],
	["Pull-up", "back", "", ["Bodyweight"], "biceps, grip", "From a dead hang to chin over the bar, no kipping.",
		["Weighted", "Assisted", "Wide grip", "Neutral grip"],
		["pullup"]],
	["Chin-up", "back", "", ["Bodyweight"], "biceps", "Palms toward you; chest to the bar.",
		["Weighted", "Assisted"],
		["chinup", "chin"]],
	["Shrug", "back", "Barbell", [], "traps, grip", "Straight up to the ears, pause, no rolling.",
		["Barbell", "Dumbbell", "Trap bar", "Smith machine", "Cable", "Machine"],
		[]],
	["Back Extension", "back", "", [], "glutes, hamstrings", "Hinge at the hips; hold a plate to load it.",
		["45 degree", "Weighted", "Reverse", "GHD"],
		["hyperextension", "back raise"]],
	# --- shoulders -----------------------------------------------------------
	["Overhead Press", "shoulders", "Barbell", [], "triceps, upper chest", "Glutes tight, bar over mid-foot, head through at the top.",
		["Barbell", "Seated", "Behind the neck", "Dumbbell", "Seated dumbbell", "Single arm kettlebell", "Kettlebell", "Machine", "Landmine", "Smith machine"],
		["ohp", "press", "shoulder press", "military press", "strict press"]],
	["Push Press", "shoulders", "Barbell", [], "triceps, legs", "Dip and drive with the legs, then press.",
		["Barbell", "Dumbbell", "Kettlebell"],
		[]],
	["Arnold Press", "shoulders", "Dumbbell", [], "triceps", "Start palms in and turn them out as you press.",
		["Dumbbell", "Seated"],
		[]],
	["Lateral Raise", "shoulders", "Dumbbell", [], "side delts", "Lead with the elbows to shoulder height; light and strict.",
		["Dumbbell", "Seated", "Cable", "Single arm cable", "Machine", "Band"],
		["side raise", "side lateral raise", "lateral", "laterals"]],
	["Front Raise", "shoulders", "Dumbbell", [], "front delts", "Raise to eye level without swinging.",
		["Dumbbell", "Plate", "Cable", "Barbell", "Band"],
		[]],
	["Rear Delt Fly", "shoulders", "", [], "rear delts, upper back", "Hinge over, arms wide, squeeze the shoulder blades.",
		["Dumbbell", "Seated dumbbell", "Cable", "Machine", "Band"],
		["reverse fly", "rear delt raise", "rear fly", "rear delt"]],
	["Face Pull", "shoulders", "", ["Cable", "Rope"], "rear delts, rotator cuff", "Pull the rope to your eyes, elbows high, ends apart.",
		["Single arm", "Band"],
		[]],
	["Upright Row", "shoulders", "Barbell", [], "traps", "Elbows lead; lift to chest height.",
		["Barbell", "EZ bar", "Dumbbell", "Cable"],
		[]],
	["Pull-Apart", "shoulders", "Band", [], "rear delts, upper back", "Arms straight; pull the band to your chest.",
		["Band", "Cable"],
		["pullapart"]],
	["Handstand Push-up", "shoulders", "", ["Bodyweight"], "triceps", "Head to the floor and press back up.",
		["Wall", "Deficit"],
		["hspu"]],
	# --- arms ----------------------------------------------------------------
	["Bicep Curl", "biceps", "", [], "forearms", "Elbows pinned to your sides; no swinging.",
		["Dumbbell", "Alternating dumbbell", "Barbell", "EZ bar", "Cable", "Incline dumbbell", "Reclined", "Preacher EZ bar", "Preacher machine", "Concentration dumbbell", "Spider dumbbell", "Bayesian cable", "Band", "Machine"],
		["curl", "biceps curl"]],
	["Hammer Curl", "biceps", "Dumbbell", [], "forearms", "Palms facing in; elbows still.",
		["Dumbbell", "Alternating", "Cross body", "Rope"],
		[]],
	["Reverse Curl", "forearms", "", [], "biceps", "Palms down; elbows still.",
		["Barbell", "EZ bar", "Dumbbell", "Cable"],
		[]],
	["Zottman Curl", "forearms", "Dumbbell", [], "biceps", "Curl palms up, lower palms down.",
		["Dumbbell"],
		[]],
	["Tricep Pushdown", "triceps", "", ["Cable"], "forearms", "Elbows at your sides; lock out and squeeze.",
		["Rope", "Straight bar", "V bar", "Single arm", "Band"],
		["pushdown", "triceps pushdown", "cable pushdown"]],
	["Tricep Extension", "triceps", "", [], "", "Upper arms still; only the elbows move.",
		["Overhead cable", "Overhead rope", "Overhead dumbbell", "Single arm overhead dumbbell", "Lying EZ bar", "Lying dumbbell"],
		["triceps extension", "french press"]],
	["Tricep Kickback", "triceps", "Dumbbell", [], "", "Upper arm parallel to the floor; straighten the elbow.",
		["Dumbbell", "Cable", "Single arm cable"],
		["kickback", "triceps kickback"]],
	["Wrist Curl", "forearms", "", [], "grip", "Forearms on your thighs; curl only the wrists.",
		["Barbell", "Dumbbell", "Reverse barbell", "Reverse dumbbell", "Cable"],
		["wrist flexion"]],
	["Wrist Roller", "forearms", "", [], "grip, shoulders", "Arms out in front; roll the weight up and back down.",
		[],
		[]],
	["Farmer Carry", "forearms", "Dumbbell", [], "traps, core", "Stand tall; short, quick steps.",
		["Dumbbell", "Single arm", "Kettlebell", "Single arm kettlebell", "Trap bar"],
		["farmers carry", "farmers walk", "farmer walk", "loaded carry"]],
	["Pinch", "forearms", "Plate", [], "grip", "Pinch the plates smooth side out and hold.",
		["Plate"],
		["plate pinch"]],
	["Dead Hang", "forearms", "", ["Bodyweight"], "shoulders, grip", "Hang from a bar with the shoulders active.",
		["Single arm", "Weighted"],
		["bar hang"]],
	# --- legs ----------------------------------------------------------------
	["Squat", "quads", "Barbell", [], "glutes, core", "Brace, sit between the hips, knees track the toes.",
		["Barbell", "Front", "Paused", "Box", "Zercher", "Overhead", "Safety bar", "Goblet", "Goblet kettlebell", "Dumbbell", "Smith machine", "Bodyweight"],
		["sq", "back squat", "backsquat"]],
	["Hack Squat", "quads", "", ["Machine"], "glutes", "Back flat on the pad; deep and controlled.",
		["Reverse"],
		[]],
	["Leg Press", "quads", "", ["Machine"], "glutes, hamstrings", "Feet shoulder width; keep your hips on the seat.",
		["Single leg"],
		[]],
	["Leg Extension", "quads", "", ["Machine"], "", "Pause at the top; slow on the way down.",
		["Single leg"],
		["quad extension"]],
	["Bulgarian Split Squat", "quads", "Dumbbell", [], "glutes", "Rear foot on a bench; front shin near vertical.",
		["Dumbbell", "Barbell", "Kettlebell", "Smith machine", "Bodyweight"],
		["bss", "rfess", "rear foot elevated split squat"]],
	["Split Squat", "quads", "Dumbbell", [], "glutes", "Long stance; drop the back knee straight down.",
		["Dumbbell", "Barbell", "Bodyweight"],
		[]],
	["Lunge", "quads", "Dumbbell", [], "glutes", "Long step; back knee toward the floor.",
		["Dumbbell", "Walking", "Reverse", "Barbell", "Kettlebell", "Bodyweight"],
		[]],
	["Step-up", "quads", "Dumbbell", [], "glutes", "Drive through the top foot; don't push off the back one.",
		["Dumbbell", "Barbell", "Bodyweight"],
		["stepup"]],
	["Pistol Squat", "quads", "", ["Bodyweight"], "glutes, balance", "One leg; sit all the way down and stand up.",
		["Assisted", "Weighted"],
		["pistol"]],
	["Sissy Squat", "quads", "", ["Bodyweight"], "", "Knees forward, body leaning back in one line.",
		["Weighted"],
		[]],
	["Wall Sit", "quads", "", ["Bodyweight"], "", "Back flat on the wall, thighs level; hold.",
		["Weighted", "Single leg"],
		[]],
	["Romanian Deadlift", "hamstrings", "Barbell", [], "glutes, lower back", "Soft knees; push the hips back, bar close to the legs.",
		["Barbell", "Dumbbell", "Single leg", "Single leg dumbbell", "Single leg kettlebell", "Kettlebell", "Trap bar"],
		["romanian", "rdl"]],
	["Stiff-Leg Deadlift", "hamstrings", "Barbell", [], "lower back", "Legs almost straight; hinge to a hamstring stretch.",
		["Barbell", "Dumbbell"],
		["stiff leg deadlift", "sldl"]],
	["Good Morning", "hamstrings", "Barbell", [], "lower back, glutes", "Bar on your back; hinge until your torso is nearly flat.",
		["Barbell", "Safety bar", "Band"],
		[]],
	["Leg Curl", "hamstrings", "", ["Machine"], "calves", "Hips down; curl all the way.",
		["Lying", "Seated", "Standing", "Single leg", "Stability ball", "Band"],
		["hamstring curl", "ham curl"]],
	["Nordic Curl", "hamstrings", "", ["Bodyweight"], "", "Lower yourself as slowly as you can.",
		["Assisted", "Band"],
		["nordic", "nordic hamstring curl"]],
	["Glute-Ham Raise", "hamstrings", "GHD", [], "glutes", "On the GHD: curl yourself up with the hamstrings.",
		[],
		["ghr"]],
	["Swing", "hamstrings", "Kettlebell", [], "glutes, core", "Hinge and snap the hips; the arms only guide.",
		["Kettlebell", "Single arm", "Dumbbell"],
		[]],
	["Hip Thrust", "glutes", "Barbell", [], "hamstrings", "Chin tucked, ribs down, squeeze at the top.",
		["Barbell", "Single leg", "Machine", "Smith machine", "Dumbbell", "Band"],
		["thrust"]],
	["Glute Bridge", "glutes", "", [], "hamstrings", "Feet flat; squeeze at the top.",
		["Single leg", "Barbell", "Band", "Weighted"],
		["bridge", "hip bridge"]],
	["Pull-Through", "glutes", "Cable", [], "hamstrings", "Hinge, then snap the hips through.",
		["Cable", "Band", "Kettlebell"],
		[]],
	["Glute Kickback", "glutes", "", [], "hamstrings", "Squeeze the glute; don't arch the back.",
		["Cable", "Machine", "Band", "Bodyweight"],
		["donkey kick"]],
	["Hip Abduction", "glutes", "Machine", [], "", "Push the knees out; slow on the way back.",
		["Machine", "Band", "Cable"],
		["abduction", "abductor"]],
	["Hip Adduction", "glutes", "Machine", [], "", "Squeeze the knees together; slow on the way back.",
		["Machine", "Band", "Cable"],
		["adduction", "adductor"]],
	["Lateral Walk", "glutes", "Band", [], "", "Stay low and keep tension on the band.",
		["Band"],
		["monster walk", "band walk"]],
	["Clamshell", "glutes", "", [], "hips", "Hips stacked; open the knee without rolling back.",
		["Band"],
		["clam"]],
	["Calf Raise", "calves", "", [], "", "Full stretch at the bottom, pause at the top.",
		["Standing machine", "Seated machine", "Smith machine", "Barbell", "Dumbbell", "Single leg", "Leg press", "Donkey", "Bodyweight"],
		["heel raise", "calves"]],
	["Tibialis Raise", "calves", "", [], "shins", "Heels down; lift the toes.",
		["Wall", "Machine", "Band"],
		["tib raise", "toe raise", "tibialis"]],
	# --- core ----------------------------------------------------------------
	["Plank", "core", "", ["Bodyweight"], "shoulders", "Squeeze the glutes, ribs down, one straight line.",
		["Side", "Weighted"],
		[]],
	["Crunch", "core", "", ["Bodyweight"], "", "Ribs to hips; short and controlled.",
		["Decline", "Reverse", "Weighted", "Cable", "Machine"],
		[]],
	["Sit-up", "core", "", ["Bodyweight"], "hip flexors", "Feet anchored; all the way up.",
		["Decline", "Weighted", "GHD"],
		["situp"]],
	["Leg Raise", "core", "", ["Bodyweight"], "hip flexors", "Lower slowly; low back stays down.",
		["Hanging", "Lying"],
		[]],
	["Knee Raise", "core", "", ["Bodyweight"], "hip flexors", "Knees to chest without swinging.",
		["Hanging"],
		[]],
	["Toes-to-Bar", "core", "", ["Bodyweight"], "lats, grip", "From a hang, toes all the way to the bar.",
		[],
		["toes to bar", "t2b"]],
	["Rollout", "core", "Ab wheel", [], "lats, shoulders", "Roll out with your ribs down; pull back with the abs.",
		["Ab wheel", "Barbell", "Stability ball"],
		["ab rollout"]],
	["Russian Twist", "core", "", [], "obliques", "Lean back, chest up, turn side to side.",
		["Weighted", "Medicine ball", "Plate"],
		[]],
	["Woodchop", "core", "Cable", [], "obliques, shoulders", "Turn through the hips, arms long.",
		["Cable", "High to low", "Low to high", "Band", "Medicine ball"],
		["wood chop", "woodchopper"]],
	["Pallof Press", "core", "Cable", [], "obliques", "Press out and hold; don't let the cable turn you.",
		["Cable", "Half kneeling", "Band"],
		[]],
	["Dead Bug", "core", "", ["Bodyweight"], "", "Low back down; opposite arm and leg.",
		["Weighted"],
		[]],
	["Hollow Hold", "core", "", ["Bodyweight"], "", "Low back pressed down, arms and legs long.",
		[],
		["hollow body hold"]],
	["Dragon Flag", "core", "", ["Bodyweight"], "", "Body straight from the shoulders; lower slowly.",
		[],
		[]],
	["L-Sit", "core", "", ["Bodyweight"], "hip flexors, triceps", "Legs straight out in front; hold.",
		[],
		["lsit"]],
	# --- mobility ------------------------------------------------------------
	["Calf Stretch", "mobility", "", [], "ankles", "Heel down, knee straight; lean in and hold.",
		["Wall", "Slant board", "Step", "Bent knee"],
		[]],
	["Hamstring Stretch", "mobility", "", [], "", "Hinge with a flat back until you feel the stretch.",
		["Standing", "Seated", "Lying", "Band"],
		[]],
	["Hip Flexor Stretch", "mobility", "", [], "quads", "Tuck the pelvis, squeeze the glute, lean forward.",
		["Half kneeling", "Standing", "Couch"],
		[]],
	["Quad Stretch", "mobility", "", [], "hip flexors", "Heel to glute, knees together.",
		["Standing", "Lying", "Kneeling"],
		[]],
	["Pigeon Stretch", "mobility", "", [], "glutes, hips", "Front shin across, hips square; sink down.",
		["Bench"],
		["pigeon"]],
	["Pec Stretch", "mobility", "", [], "shoulders", "Forearm on a doorframe; step through.",
		["Doorway", "Wall"],
		["chest stretch"]],
	["Thoracic Rotation", "mobility", "", [], "upper back", "Knees stacked; open the top arm and follow it with your eyes.",
		["Lying side", "Kneeling"],
		["open book", "t spine rotation"]],
	["Cat-Cow", "mobility", "", [], "spine", "Round, then arch, slowly, with your breath.",
		[],
		["cat cow"]],
	["90/90 Hip Switch", "mobility", "", [], "hips", "Both knees at 90 degrees; switch side to side.",
		[],
		["90 90", "hip switch"]],
	["Ankle Mobility", "mobility", "", [], "calves", "Knee over the toes; heel stays down.",
		["Band", "Wall"],
		["ankle dorsiflexion"]],
	# --- full body -------------------------------------------------------------
	["Clean", "full", "", ["Barbell"], "legs, back, traps", "Pull fast, drop under, catch on the shoulders.",
		["Power", "Hang", "Hang power", "Dumbbell", "Kettlebell"],
		[]],
	["Clean and Jerk", "full", "", ["Barbell"], "shoulders, legs", "Clean to the shoulders, then drive it overhead.",
		["Power"],
		["clean jerk"]],
	["Snatch", "full", "", ["Barbell"], "back, shoulders", "Floor to overhead in one move.",
		["Power", "Hang", "Dumbbell", "Kettlebell"],
		[]],
	["Thruster", "full", "Barbell", [], "shoulders, quads", "A front squat straight into a press.",
		["Barbell", "Dumbbell", "Kettlebell"],
		[]],
	["Turkish Get-up", "full", "Kettlebell", [], "shoulders, core", "Eyes on the bell; one step at a time.",
		["Kettlebell", "Dumbbell"],
		["tgu", "getup"]],
	["Muscle-up", "full", "", ["Bodyweight"], "lats, chest, triceps", "Pull high and turn over into a dip.",
		["Rings"],
		["muscleup"]],
	["Burpee", "full", "", ["Bodyweight"], "chest, legs", "Chest to the floor, jump at the top.",
		[],
		[]],
	["Box Jump", "full", "", ["Bodyweight"], "quads, calves", "Land soft and stand up tall on the box.",
		[],
		[]],
	["Sled Push", "full", "", [], "quads, glutes", "Low and long; drive with the legs.",
		[],
		["sled"]],
]

static var _catalog = null


## Names a movement answers to, normalized.
static func _keys_of(move_name: String, names: Array) -> Array:
	var keys = [Xp.normalize_exercise(move_name)]
	for o in names:
		var k = Xp.normalize_exercise(str(o))
		if not keys.has(k):
			keys.append(k)
	return keys


static func part_name(id: String) -> String:
	for p in PARTS:
		if p.id == id:
			return p.name
	return id


static func equip_name(id: String) -> String:
	for e in EQUIPMENT:
		if e.id == id:
			return e.name
	return id


## The catalog as entries (no history attached).
static func catalog() -> Array:
	if _catalog == null:
		_catalog = []
		for row in MOVES:
			var usual: String = str(row[2])
			var only: Array = row[3]
			var equips = []
			for v in [usual] + only + Array(row[6]):
				for g in LiftNames.gear_of(str(v)):
					if not equips.has(g):
						equips.append(g)
			var main = "bodyweight" if only.has("Bodyweight") else ""
			if main == "":
				var first = LiftNames.gear_of(usual if usual != "" else (str(only[0]) if not only.is_empty() else ""))
				main = str(first[0]) if not first.is_empty() else (str(equips[0]) if not equips.is_empty() else "other")
			if not equips.has(main):
				equips.append(main)
			_catalog.append({"name": str(row[0]), "part": str(row[1]), "usual": usual, "only": only, "equip": main, "equips": equips,
				"family": str(row[0]), "also": str(row[4]), "tip": str(row[5]), "vars": Array(row[6]), "names": Array(row[7]),
				"keys": _keys_of(str(row[0]), row[7]), "own": false})
	var out = []
	for e in _catalog:
		out.append(e.duplicate())
	return out


# ---------------------------------------------------------------------------
# Searching for an exercise by what is typed (the Log tab's "Add exercise")
# ---------------------------------------------------------------------------

## Every movement with every variation of it, as names to search: [{"name", "key", "words"}]. The words are
## the movement's, the variation's and the movement's other names.
static var _search_index = null

static func _swords(text: String) -> Array:
	var t = text.to_lower()
	for ch in ["-", "(", ")", ",", "/", ".", "'"]:
		t = t.replace(ch, " ")
	return Array(t.split(" ", false))


static func search_index() -> Array:
	if _search_index == null:
		var out = []
		for e in catalog():
			var extra = []
			for n in e.names:
				extra.append_array(_swords(str(n)))
			var vs = e.vars if not (e.vars as Array).is_empty() else [""]
			for v in vs:
				var full = LiftNames.join(str(e.name), str(v))
				out.append({"name": full, "key": Xp.normalize_exercise(full), "words": _swords(str(e.name)) + _swords(str(v)) + extra})
		_search_index = out
	return _search_index


## How a typed word meets a name's words: 3 = a whole word, 2 = the start of one, 1 = inside one or one typo
## away (a typed word of five letters or more), 0 = nowhere.
static func word_hit(q: String, words: Array) -> int:
	var best = 0
	for w in words:
		var ws = str(w)
		if ws == q:
			return 3
		if ws.begins_with(q):
			best = maxi(best, 2)
		elif q.length() >= 3 and ws.contains(q):
			best = maxi(best, 1)
		elif q.length() >= 5 and ws.length() >= 4 and (LiftMatch.typo(q, ws) <= 1 or LiftMatch.typo(q, ws.substr(0, q.length())) <= 1):
			best = maxi(best, 1)
	return best


## How well `query` finds a name with these words: 0 when a typed word is found nowhere, else the sum.
static func search_score(query: String, words: Array) -> int:
	var qs = _swords(query)
	if qs.is_empty():
		return 0
	var total = 0
	for q in qs:
		var h = word_hit(str(q), words)
		if h == 0:
			return 0
		total += h
	return total


## Names for what is typed, best first: the player's own (`mine`, in its order: the most used first) before
## the library's movements and variations; at most `limit`; none twice.
static func search(query: String, mine: Array, limit: int = 12) -> Array:
	var seen = {}
	var own = []
	for i in range(mine.size()):
		var n = str(mine[i])
		var k = Xp.normalize_exercise(n)
		if seen.has(k):
			continue
		var sc = search_score(query, _swords(n))
		if sc > 0:
			seen[k] = true
			own.append([sc, i, n])
	own.sort_custom(func(a, b): return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var lib = []
	var idx = search_index()
	for i in range(idx.size()):
		var r = idx[i]
		if seen.has(r.key):
			continue
		var sc2 = search_score(query, r.words)
		if sc2 > 0:
			seen[r.key] = true
			lib.append([sc2, i, str(r.name)])
	lib.sort_custom(func(a, b): return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var out = []
	for x in own + lib:
		if out.size() >= limit:
			break
		out.append(str(x[2]))
	return out


## What the player has logged, per normalized exercise name (movement and
## variation together: "shrug - barbell").
static func stats(sessions: Array) -> Dictionary:
	var lifts = sessions.filter(func(x): return x.discipline == "lift")
	TTUtil.stable_sort(lifts, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	var out = {}
	for x in lifts:
		for ex in x.get("exercises", []):
			var key = Xp.normalize_exercise(ex.name)
			var done = []
			for one in ex.get("sets", []):
				if int(one.get("reps", 0)) > 0:
					var kept = {"reps": int(one.reps), "weightKg": float(one.get("weightKg", 0))}
					if int(one.get("holdSec", 0)) > 0:
						kept["holdSec"] = int(one.holdSec)
					if Bands.is_band(one):
						kept["band"] = str(one.band).strip_edges().to_lower()
					done.append(kept)
			if key == "" or done.is_empty():
				continue
			if not out.has(key):
				out[key] = {"name": str(ex.name).strip_edges(), "count": 0, "last": x.date, "bestKg": 0.0, "bestReps": 0, "e1rm": 0.0, "bwReps": 0, "volumeKg": 0.0, "reps": 0, "history": []}
			var st = out[key]
			st.count += 1
			st.history.append({"date": x.date, "id": x.id, "sets": done})
			for one in done:
				st.reps += one.reps
				st.volumeKg += one.reps * one.weightKg
				if one.weightKg > 0.0:
					if one.weightKg > st.bestKg + 1e-9 or (absf(one.weightKg - st.bestKg) <= 1e-9 and one.reps > st.bestReps):
						st.bestKg = one.weightKg
						st.bestReps = one.reps
					st.e1rm = maxf(st.e1rm, Xp.e1rm(one.weightKg, one.reps))
				else:
					st.bwReps = maxi(st.bwReps, one.reps)
	return out


## Several logged lifts read as one history (all the variations of a movement).
static func merge_stats(keys: Array, all: Dictionary):
	var found = []
	for k in keys:
		if all.has(k):
			found.append(all[k])
	if found.is_empty():
		return null
	if found.size() == 1:
		return found[0]
	var m = {"name": "", "count": 0, "last": "", "bestKg": 0.0, "bestReps": 0, "e1rm": 0.0, "bwReps": 0, "volumeKg": 0.0, "reps": 0, "history": []}
	for st in found:
		m.count += st.count
		m.reps += st.reps
		m.volumeKg += st.volumeKg
		m.e1rm = maxf(m.e1rm, st.e1rm)
		m.bwReps = maxi(m.bwReps, st.bwReps)
		if st.bestKg > m.bestKg + 1e-9 or (absf(st.bestKg - m.bestKg) <= 1e-9 and st.bestReps > m.bestReps):
			m.bestKg = st.bestKg
			m.bestReps = st.bestReps
		if str(st.last) > str(m.last):
			m.last = st.last
			m.name = st.name
		m.history.append_array(st.history)
	TTUtil.stable_sort(m.history, func(a, b): return a.date > b.date)
	return m


## A guess at the body part of a movement the catalog does not know, from its name.
static func guess_part(key: String) -> String:
	var rules = [
		["stretch", "mobility"], ["mobility", "mobility"],
		["curl", "biceps"], ["tricep", "triceps"], ["pushdown", "triceps"], ["calf", "calves"], ["squat", "quads"],
		["lunge", "quads"], ["deadlift", "back"], ["row", "back"], ["pulldown", "back"], ["pull-up", "back"],
		["bench", "chest"], ["fly", "chest"], ["push-up", "chest"], ["press", "shoulders"], ["raise", "shoulders"],
		["thrust", "glutes"], ["bridge", "glutes"], ["crunch", "core"], ["plank", "core"], ["twist", "core"],
		["wrist", "forearms"], ["grip", "forearms"],
	]
	for r in rules:
		if key.contains(r[0]):
			return r[1]
	return "other"


## Every movement to show: the catalog plus any movement of the player's own,
## each with its logged variations ("done") and their stats together ("st").
static func rows(sessions: Array) -> Array:
	var all = stats(sessions)
	var out = []
	var by_move = {}
	for e in catalog():
		e["done"] = []
		e["st"] = null
		out.append(e)
		for k in e.keys:
			by_move[k] = e
	for key in all:
		var st = all[key]
		var sp = LiftNames.split(str(st.name))
		var mk = Xp.normalize_exercise(str(sp.move))
		var row = by_move.get(mk)
		if row == null:
			row = {"name": str(sp.move), "part": guess_part(mk), "usual": "", "only": [], "equip": "other", "equips": ["other"],
				"family": str(sp.move), "also": "", "tip": "One of your own: not in the library, so it has no notes.",
				"vars": [], "names": [], "keys": [mk], "own": true, "done": [], "st": null}
			out.append(row)
			by_move[mk] = row
		row.done.append({"variation": str(sp.variation), "name": str(st.name), "st": st})
	for row in out:
		if row.done.is_empty():
			continue
		TTUtil.stable_sort(row.done, func(a, b): return str(a.st.last) > str(b.st.last))
		var keys = []
		for d in row.done:
			keys.append(Xp.normalize_exercise(str(d.name)))
		row.st = merge_stats(keys, all)
		for d in row.done:
			for g in LiftNames.gear_of(str(d.variation)):
				if not row.equips.has(g):
					row.equips.append(g)
	return out


## Every variation of a movement row to choose from: the ones logged first (most
## recent first, with their stats), then the catalog's others. [{variation, name, st}]
static func variation_list(row: Dictionary) -> Array:
	var out = []
	var seen = {}
	for d in row.get("done", []):
		out.append(d)
		seen[Xp.normalize_exercise(str(d.variation))] = true
	# The movement with no variation said first, when it has no usual one ("Pull-up").
	var base = [""] if str(row.get("usual", "")) == "" else []
	for v in base + Array(row.get("vars", [])):
		var k = Xp.normalize_exercise(str(v))
		if seen.has(k):
			continue
		seen[k] = true
		out.append({"variation": str(v), "name": LiftNames.join(str(row.name), str(v)), "st": null})
	return out


static func _part_index(id: String) -> int:
	for i in range(PARTS.size()):
		if PARTS[i].id == id:
			return i
	return PARTS.size()


static func _matches(e: Dictionary, words: Array) -> bool:
	var vars = []
	for d in e.get("done", []):
		vars.append(str(d.variation))
	var hay = " ".join(PackedStringArray([str(e.name), " ".join(PackedStringArray(e.keys)), part_name(e.part), " ".join(PackedStringArray(e.equips.map(func(g): return equip_name(str(g))))),
		str(e.also), " ".join(PackedStringArray(e.vars)), " ".join(PackedStringArray(vars))])).to_lower()
	for w in words:
		if not hay.contains(w):
			return false
	return true


## Filter and sort rows. opts = {"q": search text, "part": id or "", "equip": id or "",
## "show": "all" | "mine" | "new", "sort": one of SORTS}.
static func query(all_rows: Array, opts: Dictionary) -> Array:
	var words = []
	for w in str(opts.get("q", "")).to_lower().split(" ", false):
		words.append(w)
	var part = str(opts.get("part", ""))
	var equip = str(opts.get("equip", ""))
	var show = str(opts.get("show", "all"))
	var out = []
	for e in all_rows:
		if part != "" and e.part != part:
			continue
		if equip != "" and not e.equips.has(equip):
			continue
		if show == "mine" and e.st == null:
			continue
		if show == "new" and e.st != null:
			continue
		if not words.is_empty() and not _matches(e, words):
			continue
		out.append(e)
	var by_name = func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	TTUtil.stable_sort(out, by_name)
	match str(opts.get("sort", "part")):
		"part":
			TTUtil.stable_sort(out, func(a, b): return _part_index(a.part) < _part_index(b.part))
		"count":
			TTUtil.stable_sort(out, func(a, b): return (int(a.st.count) if a.st != null else 0) > (int(b.st.count) if b.st != null else 0))
		"best":
			TTUtil.stable_sort(out, func(a, b): return (float(a.st.bestKg) if a.st != null else -1.0) > (float(b.st.bestKg) if b.st != null else -1.0))
		"recent":
			TTUtil.stable_sort(out, func(a, b): return (str(a.st.last) if a.st != null else "") > (str(b.st.last) if b.st != null else ""))
	return out


## The heaviest weight lifted for at least 1, 3, 5, 8, 10 and 12 reps:
## [{"reps": r, "kg": weight}] for the marks that have one.
static func rep_bests(st: Dictionary) -> Array:
	var out = []
	for r in REP_MARKS:
		var best = 0.0
		for h in st.history:
			for one in h.sets:
				if one.reps >= r and one.weightKg > best:
					best = one.weightKg
		if best > 0.0:
			out.append({"reps": r, "kg": best})
	return out
