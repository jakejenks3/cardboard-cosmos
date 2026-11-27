class_name RpgWorld
extends RefCounted
## The Ironwild (RPG_PLAN.md 8.1, 8.2, 8.4): the eight regions and their ten
## stages each, the stars, what is open, and everything beyond the road: the
## daily hunt, the weekly rival, the Spire and the echo regions. Pure: plain
## dictionaries in and out, no autoload, no screen, nothing stored here.
##
## A STAGE (8.2), as every function here gives it (every key always there):
##   {"id" ("r3s5"; an echo "e3s5"; "hunt:<date>", "rival:<week>", "spire:<floor>"),
##    "region" (a region id, "" beyond the road), "r", "s", "n" (the difficulty index),
##    "name", "text" (one line of story),
##    "kind": "battle"|"elite"|"cache"|"boss" on the road and in an echo, else "hunt"|"rival"|"spire",
##    "echo": bool, "scene" (the backdrop: the region id, "hunt", "rival", "spire"),
##    "waves": [[{"foe", "n", ...}, ...], ...] (a cache: none), "rules": [ids of RULES],
##    "stars": [objective x3] ([] where there are none), "par": hero turns for the second star (`par_of`),
##    "first": {"ore", "items": [{id, n}], "scroll": id or "", "relic": id or "" ("any" = one the player does not
##        have yet: RpgLoot picks it), "rune": bool} (the first win only),
##    "rec": the recommended power (RpgHero.power of the reference hero of its tier)}
##   The hunt also has "date", "rule", "weak" and "prizes"; the rival "week", "weak", "monster" and "custom" (its foe
##   row, for the setup); a Spire stage "floor".
##
## The road: all_stages(), stage(id), region(id), regions(), region_of(stage id), next_stage(stage id),
##   is_open(rpg, stage id), done(rpg, stage id), best_n(rpg), stars(stage, summary), star_count(rpg, region id),
##   objective_words(objective), waves_fought(stage).
## Beyond it: hunt(date, rpg, boosts), rival(state, rpg), spire(floor), spire_open(rpg), echo_stages(),
##   echoes_open(rpg).
## A battle: stage_of(what, rpg) and setup(what, rpg, hero_unit, pet_unit, seed, today), which is the dictionary
##   RpgBattle.start takes. `what` = {"kind": "stage"|"echo"|"hunt"|"rival"|"spire", "id"}; a hunt also wants
##   "boosts" (RpgBoosts.active) and a rival "state" (App.state), or either may bring the stage itself as "stage".
##
## RULES are the engine's own (RpgBattle.RULES, applied by it from setup.rules): this table gives each a name
## and the words for the prep sheet. Nothing here applies a rule itself; a stage only names it.
##
## What this file decides (the plan leaves it open): the wave lists, the third star of every stage, the first
## rewards, which bosses stand with an add from the start (the ones that summon, from region 5 on), that an
## echo region opens when the echo boss before it falls, and the par of a wave with an elite or a boss (`par_of`).

## The hero turns the second star allows where no par was measured (the hunt,
## the rival, the Spire, an echo's floor): a wave of regular foes, a wave with
## an elite, a wave with a boss. The top of the plan's own bands (4.1: a wave
## 3 to 6 turns, an elite 6 to 11, a boss 11 to 22). The road's stages have
## their own (PAR).
const PAR_PER_WAVE = 6
const PAR_ELITE = 11
const PAR_BOSS = 22
## The road's own pars, set by the balance step (tools/rpg_balance.gd par): 1.3 x the median hero turns of the
## reference hero of the stage's tier, rounded up, so the turns star can be had but is not free. A stage that is
## not here (and everything beyond the road) goes by `par_of`; an echo never asks for fewer turns than its stage.
const PAR = {
	"r1s1": 3, "r1s2": 4, "r1s3": 7, "r1s4": 6, "r1s5": 8, "r1s7": 7, "r1s8": 11, "r1s9": 10, "r1s10": 23,
	"r2s1": 4, "r2s2": 4, "r2s3": 6, "r2s4": 4, "r2s5": 11, "r2s7": 6, "r2s8": 10, "r2s9": 8, "r2s10": 16,
	"r3s1": 6, "r3s2": 7, "r3s3": 6, "r3s4": 8, "r3s5": 15, "r3s7": 8, "r3s8": 16, "r3s9": 10, "r3s10": 16,
	"r4s1": 6, "r4s2": 6, "r4s3": 8, "r4s4": 6, "r4s5": 15, "r4s7": 10, "r4s8": 16, "r4s9": 10, "r4s10": 16,
	"r5s1": 6, "r5s2": 8, "r5s3": 6, "r5s4": 6, "r5s5": 11, "r5s7": 10, "r5s8": 15, "r5s9": 11, "r5s10": 20,
	"r6s1": 6, "r6s2": 4, "r6s3": 6, "r6s4": 6, "r6s5": 13, "r6s7": 7, "r6s8": 15, "r6s9": 8, "r6s10": 23,
	"r7s1": 6, "r7s2": 6, "r7s3": 6, "r7s4": 7, "r7s5": 11, "r7s7": 7, "r7s8": 13, "r7s9": 7, "r7s10": 20,
	"r8s1": 10, "r8s2": 8, "r8s3": 12, "r8s4": 12, "r8s5": 13, "r8s7": 15, "r8s8": 20, "r8s9": 11, "r8s10": 20,
}
## A single hit over this share of max HP loses the "no big hit" star: a wind-up that was not guarded.
const BIG_HIT = 0.25

## id -> {"name", "text"}: the rules a hunt or an echo may carry. The ids are RpgBattle.RULES'.
const RULES = {
	"foes_hasted": {"name": "Tailwind", "text": "The foes start Hasted."},
	"guard_up": {"name": "Thick Skins", "text": "Every foe has 2 more guard."},
	"no_items": {"name": "Empty Pockets", "text": "The belt stays shut."},
	"foes_braced": {"name": "Dug In", "text": "The foes start Braced."},
	"low_energy": {"name": "Cold Start", "text": "You start with 1 energy."},
	"extra_wave": {"name": "Second Helping", "text": "One more wave."},
}
const RULE_IDS = ["foes_hasted", "guard_up", "no_items", "foes_braced", "low_energy", "extra_wave"]

## The relic a region's boss gives the first time it falls.
const BOSS_RELICS = ["chipped_tooth", "cowbell", "roll_of_finger_tape", "frayed_bookmark", "pocket_anvil", "rest_timer", "tuning_fork", "hollow_heart"]
## The belt item a region hands out (its elite a stack of three, stage 4 a pair).
const REGION_ITEMS = ["protein_shake", "energy_gel", "chalk_ball", "smelling_salts", "ice_pack", "mega_shake", "electrolytes", "pre_workout"]
## The bounty monster's weak muscle group as attack schools (8.4).
const PART_SCHOOLS = {"legs": ["legs"], "chest": ["push"], "shoulders": ["push"], "back": ["pull"], "arms": ["push", "pull"], "core": ["legs"]}
const SPIRE_STEP = 2.0
const SPIRE_BEND = 35
const SPIRE_SLOW = 0.5
const HUNT_AHEAD = 2.0
const RIVAL_AHEAD = 5.0
const ECHO_BASE = 80.0
const ECHO_REGION = 3.0
const ECHO_STAGE = 0.3

## The road. A region: id, two lines about it, what it teaches, and ten stages
## as [name, story line, third star, waves] (a cache: no star, no waves). A
## foe new to a region is met alone or in a pair before a pack of three has it.
const ROWS = [
	{"id": "rustyard", "blurb": "The lot behind the gym, where old equipment goes to be forgotten. Lately it has stopped staying put.",
	"teaches": "Weaknesses and the guard break", "stages": [
		["The Back Door", "You step out of the gym and something small and grey rolls at you with intent.", "break", [["dust_bunny"]]],
		["Loading Dock", "The rats out here have been chewing on barbell sleeves. It shows in their teeth.", "no_guard", [["dust_bunny", "rust_rat"]]],
		["Plate Graveyard", "A plate that should be lying down is not lying down. Hit what it is weak to and its guard cracks.", "break", [["squeaky_plate", "dust_bunny"]]],
		["Lost and Found", "A collar nobody claimed has claimed something of its own. It leaves you Weakened.", "hp_half", [["loose_collar", "rust_rat"]]],
		["The Bent Bar", "Somebody loaded it wrong forty years ago and it has not forgiven anyone.", "no_big_hit", [["bent_bar"]]],
		["Dented Locker", "It is not locked. It is not empty either.", "", []],
		["Scrap Row", "They have started moving in groups. That is new.", "schools3", [["dust_bunny", "rust_rat", "loose_collar"]]],
		["The Laundry Pile", "Something in the towels keeps patching the others up. Deal with it first.", "no_items", [["moldy_towel", "dust_bunny"], ["rust_rat", "squeaky_plate", "dust_bunny"]]],
		["Locker Room Hall", "The old iron is all walking the same way. You follow it to a row of lockers.", "break", [["squeaky_plate", "loose_collar", "moldy_towel"]]],
		["Old Iron-Jaw", "The last locker on the left opens by itself. It has teeth, and a page of somebody's training log stuck between them.", "hp_half", [["old_iron_jaw"]]],
	]},
	{"id": "greenmile", "blurb": "A trail that was one mile long when somebody last measured. Everything on it is in a hurry.",
	"teaches": "Speed, the turn order and slows", "stages": [
		["Trailhead", "The page reads: 'Day 1. Lifted the bar. Ran the green mile after.' So you run it.", "no_items", [["burr", "briar_fox"]]],
		["The Soft Stretch", "The mud here throws itself. Slowed means they get more turns than you do.", "hp_half", [["mud_slinger", "burr"]]],
		["Root Tunnel", "A beetle the size of a bench is winding up. When a foe charges, Guard.", "no_big_hit", [["stag_beetle", "briar_fox"]]],
		["Switchbacks", "Everything on this trail is quick. Watch the turn order and hit what moves next.", "schools3", [["burr", "briar_fox", "mud_slinger"]]],
		["The Hill", "Every route has one. This one hits back.", "no_guard", [["the_hill"]]],
		["Trail Register", "A tin box on a post. Sign in, take one thing.", "", []],
		["Half Way", "A sign says half way. It has been saying that for a while.", "no_big_hit", [["briar_fox", "mud_slinger", "stag_beetle"]]],
		["Mile Marker Nine", "The marker is counting down, and not to the finish line.", "hp_half", [["mile_marker", "burr"], ["stag_beetle", "mud_slinger", "burr"]]],
		["The Last Bend", "Fresh footprints in the mud. Very large, very evenly spaced.", "schools3", [["mile_marker", "stag_beetle", "briar_fox"]]],
		["The Pacer", "It has been one stride ahead of everyone since the trail opened, and it is carrying the next page.", "no_big_hit", [["the_pacer"]]],
	]},
	{"id": "chalk", "blurb": "White rock, bad holds, a long way down. What lives up here does not break easily.",
	"teaches": "Heavy guards and breakers", "stages": [
		["Scree Field", "'Ran to the cliffs and back. Something kept pace.' The trail ends where the rock goes up.", "no_guard", [["pebbling", "cliff_bat"]]],
		["First Pitch", "A boulder with a thick guard. Moves that chip two pips at once were made for this.", "break", [["scree_golem", "pebbling"]]],
		["Chalk Ledge", "A wisp of chalk leaves you Exposed. Everything hurts more until it wears off.", "hp_half", [["chalk_wisp", "cliff_bat"]]],
		["The Traverse", "Sideways, slowly, with company.", "break", [["pebbling", "cliff_bat", "scree_golem"]]],
		["Overhang", "The cliff leans out over you. So does what lives under it.", "no_big_hit", [["overhang", "pebbling"]]],
		["Stashed Rope Bag", "Somebody meant to come back for this.", "", []],
		["Bat Roost", "They hang from the good holds, which is rude.", "schools3", [["cliff_bat", "chalk_wisp", "scree_golem"]]],
		["The Chimney", "A rope that is not a rope. Its bite bleeds a little every turn, and it stacks.", "break", [["rope_snake", "pebbling"], ["scree_golem", "chalk_wisp", "cliff_bat"]]],
		["Summit Ridge", "Claw marks in the limestone, each a full arm span from the next.", "no_items", [["rope_snake", "chalk_wisp", "scree_golem"]]],
		["Skyhook", "The cliff drake nests on the only way down the far side. A page lines the nest.", "no_big_hit", [["skyhook"]]],
	]},
	{"id": "stacks", "blurb": "A library nobody has returned anything to in years. The books have opinions about that.",
	"teaches": "Debuffs, cleansing and interrupts", "stages": [
		["Returns Desk", "'Climbed down to the library. Needed answers.' The door is propped open with a kettlebell.", "hp_half", [["bookworm", "ink_blot"]]],
		["Reference Section", "A dust jacket wraps the others in shields. Unwrap it first.", "no_items", [["dust_jacket", "bookworm"]]],
		["The Long Aisle", "A knight folded from overdue slips lowers its lance. That is a wind-up.", "no_big_hit", [["paper_knight", "ink_blot"]]],
		["Periodicals", "Ink that burns. Something in your kit will wash it off.", "no_guard", [["bookworm", "ink_blot", "dust_jacket"]]],
		["The Index", "It knows where everything is, including you.", "hp_half", [["the_index", "bookworm"]]],
		["Book Drop", "The slot says RETURNS ONLY. You take something out anyway.", "", []],
		["Quiet Floor", "Everybody here would like you to keep it down. You will not.", "schools3", [["ink_blot", "dust_jacket", "paper_knight"]]],
		["Card Catalogue", "A final notice, ticking. Stop it before the count runs out, or brace.", "hp_half", [["overdue_notice", "bookworm"], ["paper_knight", "dust_jacket", "ink_blot"]]],
		["Rare Books", "Every book on strength has been pulled, read to pieces and put back wrong.", "break", [["overdue_notice", "paper_knight", "ink_blot"]]],
		["The Unread", "A wraith of dust and ink, made of everything nobody finished. It is using the next page as a bookmark.", "no_big_hit", [["the_unread"]]],
	]},
	{"id": "ironworks", "blurb": "The foundry where the old iron was poured. The furnaces are lit and nobody admits to lighting them.",
	"teaches": "Wind-up hits and Guard", "stages": [
		["Slag Heap", "'Read everything. None of it says when to stop. Poured more iron.' The furnaces are lit.", "no_big_hit", [["rivet_mite", "slag_imp"]]],
		["Casting Floor", "An anvil with legs. Hit it and it hits back, so make the hits count.", "break", [["anvil_back", "rivet_mite"]]],
		["The Bellows", "It pumps the others up. A Pumped foe hits a quarter harder.", "no_items", [["bellows", "slag_imp"]]],
		["Conveyor", "The line is running. Nobody is running it.", "schools3", [["rivet_mite", "slag_imp", "bellows"]]],
		["Press Golem", "It was built to flatten billets. You are roughly billet shaped.", "hp_half", [["press_golem", "rivet_mite"]]],
		["Tool Crib", "The cage is open and the sign-out sheet is blank.", "", []],
		["Furnace Row", "Hot work. Mind the one that swings back.", "break", [["slag_imp", "anvil_back", "bellows"]]],
		["The Pour", "A barbell straight from the mould, still glowing, still angry. Its big hit takes a turn to come.", "no_big_hit", [["molten_barbell", "rivet_mite"], ["bellows", "anvil_back", "slag_imp"]]],
		["Foreman's Stair", "Moulds for plates as wide as doors, all of them used lately.", "schools3", [["molten_barbell", "bellows", "anvil_back"]]],
		["Foreman Slag", "He has been filling an order that never ends. The work sheet is another page.", "no_big_hit", [["foreman_slag", "rivet_mite"]]],
	]},
	{"id": "marsh", "blurb": "Still water that shows you a better rested version of yourself. Things here mend each other faster than you can hit them.",
	"teaches": "Healers, target order and bleed", "stages": [
		["Boardwalk", "'More iron. More is always the answer.' Past the foundry the ground gives up and turns to water.", "no_guard", [["leech", "bog_hopper"]]],
		["Reed Beds", "The wraith in the reeds opens cuts that keep bleeding. They stack.", "hp_half", [["reed_wraith", "bog_hopper"]]],
		["Still Pool", "A mud mender keeps the others on their feet. Choose who goes down first.", "no_items", [["mud_mender", "leech"]]],
		["Sinking Path", "The water shows you with better posture. Do not get distracted.", "schools3", [["bog_hopper", "leech", "reed_wraith"]]],
		["Knotroot", "A root system that has tied itself into something with a temper.", "no_big_hit", [["knotroot", "bog_hopper"]]],
		["Sunken Gym Bag", "Waterlogged, zipped, surprisingly heavy.", "", []],
		["Leech Shallows", "They take your health and keep it. Take it back.", "hp_half", [["leech", "reed_wraith", "mud_mender"]]],
		["The Mirror", "Your shade resists whatever hit it last. Never the same school twice running.", "schools3", [["mirror_shade", "bog_hopper"], ["mud_mender", "reed_wraith", "leech"]]],
		["Tangle", "Bands, ropes and straps knotted across the path, as if somebody stopped untying them.", "no_items", [["mirror_shade", "mud_mender", "reed_wraith"]]],
		["The Knot", "Every stretch that was ever skipped, pulled tight in one place. A page is tied into the middle.", "no_big_hit", [["the_knot", "leech"]]],
	]},
	{"id": "stormspine", "blurb": "A ridge that gets all the weather. Count the seconds between the flash and the bang.",
	"teaches": "Stuns, countdowns and mixed packs", "stages": [
		["Tree Line", "'Stopped stretching. Too big for the doors. Training on the ridge.' Up, then.", "no_big_hit", [["static_mote", "gale_hawk"]]],
		["Goat Track", "A ram lowers its head. That is a wind-up, and the frost on it slows you.", "hp_half", [["rime_goat", "static_mote"]]],
		["Drum Rocks", "The drum speeds the others up. Silence it and the pack falls out of step.", "no_items", [["thunder_drum", "gale_hawk"]]],
		["Exposed Shoulder", "Static in the air. A stun costs a whole turn, so finish the motes early.", "schools3", [["static_mote", "gale_hawk", "rime_goat"]]],
		["Cairn Giant", "A pile of stones that learned to count down.", "break", [["cairn_giant", "static_mote"]]],
		["Summit Box", "A battered tin under the cairn. Others made it this far.", "", []],
		["Windward Face", "Mixed company. Three schools will serve you better than one.", "schools3", [["gale_hawk", "rime_goat", "thunder_drum"]]],
		["Eye of the Storm", "It charges, then the bolt lands. You get one turn of warning.", "no_big_hit", [["storm_eye", "static_mote"], ["thunder_drum", "rime_goat", "gale_hawk"]]],
		["The Saddle", "Handprints pressed into the granite, where something did push-ups.", "hp_half", [["storm_eye", "thunder_drum", "rime_goat"]]],
		["Thunderhead", "The storm has sat on this peak for years, over the way down to the quiet place. It holds the second to last page.", "no_items", [["thunderhead", "static_mote"]]],
	]},
	{"id": "titans_rest", "blurb": "The quiet place at the end of the road, where the first lifter set the bar down. Something has picked it up again.",
	"teaches": "Everything", "stages": [
		["The Long Stair", "'Stronger than the weather now. Nothing left to lift. Going to lie down.' The stair goes down.", "break", [["echo_knight", "stone_acolyte"]]],
		["Hall of Plates", "The guards here wind up slowly and hit like a dropped rack.", "no_big_hit", [["relic_guard", "stone_acolyte"]]],
		["Moth Gallery", "Void moths drink your energy. Spend it before they do.", "no_items", [["void_moth", "echo_knight"]]],
		["Acolytes' Walk", "They tend the stone the way you would tend an old injury.", "hp_half", [["stone_acolyte", "echo_knight", "relic_guard"]]],
		["The Gatekeeper", "It has one job, and it has been doing it since before the gym had walls.", "no_big_hit", [["the_gatekeeper", "void_moth"]]],
		["Offering Bowl", "Chalk, tape, a single glove. People left what they could.", "", []],
		["Echo Chamber", "Your own footsteps, in armour, coming the other way.", "break", [["void_moth", "relic_guard", "echo_knight"]]],
		["Shard Field", "Pieces of the Titan, humming. They go off when the count ends.", "schools3", [["titan_shard", "void_moth"], ["relic_guard", "stone_acolyte", "echo_knight"]]],
		["The Antechamber", "The old iron stands in rows, every piece of it, facing the last door.", "no_big_hit", [["titan_shard", "relic_guard", "void_moth"]]],
		["The Hollow Titan", "The first lifter, or the shell of one. It trained without a day off until nothing was left inside, and it has been calling the iron back ever since.", "schools3", [["the_hollow_titan", "titan_shard"]]],
	]},
]

static var _regions = null
static var _stages = null
static var _order = null
static var _echoes = null
static var _rec = {}


# =============================================================================
# Building the road
# =============================================================================

## A star objective of a kind, with its usual number.
static func objective(k: String, v = null) -> Dictionary:
	var usual = {"win": 1, "turns": PAR_PER_WAVE, "break": 1, "no_items": 0, "hp_half": 0.5, "no_guard": 0, "schools3": 3, "no_big_hit": BIG_HIT}
	return {"k": k, "v": usual.get(k, 0) if v == null else v}


## The recommended power of a difficulty index: the reference hero of its tier.
static func rec_of(n: float) -> float:
	var key = str(snappedf(n, 0.01))
	if not _rec.has(key):
		_rec[key] = snappedf(RpgHero.power(RpgHero.reference_hero(RpgDefs.tier_of_n(n))), 0.1)
	return float(_rec[key])


## "regular", "elite" or "boss": what a wave entry's foe is (its own row, else the catalog's).
static func foe_kind(entry: Dictionary) -> String:
	var row = entry.get("row") if entry.get("row") is Dictionary else RpgFoes.by_id(str(entry.get("foe", "")))
	if row is Dictionary:
		if bool(row.get("boss", false)):
			return "boss"
		if bool(row.get("elite", false)):
			return "elite"
	return "regular"


static func _no_first() -> Dictionary:
	return {"ore": 0, "items": [], "scroll": "", "relic": "", "rune": false}


## What a road stage gives the first time it is won.
static func _first_of(r: int, s: int, kind: String) -> Dictionary:
	var first = _no_first()
	var item = str(REGION_ITEMS[r - 1])
	var scrolls = RpgMoves.scrolls()
	match kind:
		"elite":
			var at = 2 * (r - 1)
			first["scroll"] = str(scrolls[at].id) if at < scrolls.size() else ""
			first["items"] = [{"id": item, "n": 3}]
		"boss":
			first["relic"] = str(BOSS_RELICS[r - 1])
			first["rune"] = true
			first["ore"] = 40 + 20 * r
		"battle":
			match s:
				2:
					first["ore"] = 15 + 10 * r
				4:
					first["items"] = [{"id": item, "n": 2}]
				8:
					first["items"] = [{"id": "protein_shake" if r < 5 else "mega_shake", "n": 2}]
				9:
					first["ore"] = 30 + 15 * r
	return first


static func _waves(lists: Array, n: float) -> Array:
	var out = []
	for list in lists:
		var wave = []
		for id in list:
			wave.append({"foe": str(id), "n": n})
		out.append(wave)
	return out


static func _kind_of(s: int) -> String:
	return "elite" if s == 5 else ("cache" if s == 6 else ("boss" if s == 10 else "battle"))


static func _build() -> void:
	if _regions != null:
		return
	var regions = []
	var stages = {}
	var order = []
	for i in range(ROWS.size()):
		var row = ROWS[i]
		var r = i + 1
		var ids = []
		var list = []
		for j in range(row.stages.size()):
			var src = row.stages[j]
			var s = j + 1
			var n = 10 * (r - 1) + (s - 1)
			var kind = _kind_of(s)
			var waves = _waves(src[3], float(n))
			var par = int(PAR.get("r%ds%d" % [r, s], par_of({"waves": waves})))
			var st = {"id": "r%ds%d" % [r, s], "region": str(row.id), "r": r, "s": s, "n": n,
				"name": str(src[0]), "text": str(src[1]), "kind": kind, "echo": false, "scene": str(row.id),
				"waves": waves, "rules": [],
				"stars": [] if kind == "cache" else [objective("win"), objective("turns", par), objective(str(src[2]))],
				"par": 0 if kind == "cache" else par,
				"first": _no_first() if kind == "cache" else _first_of(r, s, kind),
				"rec": 0.0 if kind == "cache" else rec_of(float(n))}
			stages[st.id] = st
			order.append(st.id)
			ids.append(st.id)
			list.append(st)
		var foes = RpgFoes.of_region(str(row.id))
		regions.append({"id": str(row.id), "r": r, "name": str(RpgDefs.REGION_NAMES.get(str(row.id), str(row.id))),
			"blurb": str(row.blurb), "teaches": str(row.teaches), "scene": str(row.id), "boss": str(foes.boss), "elite": str(foes.elite),
			"stages": list, "ids": ids})
	_regions = regions
	_stages = stages
	_order = order


## The rule an echo stage carries: a different one from stage to stage, and
## never "one more wave" where the first wave has no regular foe to repeat.
static func _echo_rule(r: int, s: int, waves: Array) -> String:
	var at = (r * 5 + s * 7) % RULE_IDS.size()
	var rule = str(RULE_IDS[at])
	if rule == "extra_wave":
		var regular = false
		for en in (waves[0] if not waves.is_empty() else []):
			if foe_kind(en) == "regular":
				regular = true
		if not regular:
			rule = str(RULE_IDS[(at + 1) % RULE_IDS.size()])
	return rule


static func _build_echoes() -> void:
	if _echoes != null:
		return
	_build()
	var list = []
	for id in _order:
		var src = _stages[id]
		var r = int(src.r)
		var s = int(src.s)
		var n = ECHO_BASE + ECHO_REGION * float(r - 1) + ECHO_STAGE * float(s - 1)
		var lists = []
		for wave in src.waves:
			lists.append(wave.map(func(en): return str(en.foe)))
		var waves = _waves(lists, n)
		var kind = str(src.kind)
		var rule = "" if kind == "cache" else _echo_rule(r, s, waves)
		var first = _no_first()
		if kind == "elite":
			first["items"] = [{"id": "mega_shake", "n": 3}]
			first["rune"] = true
		elif kind == "boss":
			first["rune"] = true
			first["ore"] = 200 + 25 * r
		var st = {"id": "e%ds%d" % [r, s], "region": str(src.region), "r": r, "s": s, "n": n,
			"name": str(src.name), "text": "", "kind": kind, "echo": true, "scene": str(src.scene),
			"waves": waves, "rules": [] if rule == "" else [rule], "stars": [], "par": 0, "first": first,
			"rec": 0.0 if kind == "cache" else rec_of(n)}
		st["text"] = "An echo of %s, and something left behind in it." % str(RpgDefs.REGION_NAMES.get(str(src.region), "")) if kind == "cache" \
			else "An echo of %s. %s" % [str(RpgDefs.REGION_NAMES.get(str(src.region), "")), str(RULES[rule].text)]
		if kind != "cache":
			# what the rule's own waves ask, and never fewer turns than the stage it echoes (one wave more: its turns too)
			var par = maxi(par_of(st), int(src.par) + (PAR_PER_WAVE if rule == "extra_wave" else 0))
			st["par"] = par
			st["stars"] = [objective("win"), objective("turns", par), src.stars[2].duplicate()]
		_stages[st.id] = st
		list.append(st)
	_echoes = list


# =============================================================================
# The road
# =============================================================================

## The eight regions in order: {"id", "r", "name", "blurb", "teaches", "scene", "boss", "elite", "stages": [stage x10],
## "ids": [stage ids]}. Do not change what it returns.
static func regions() -> Array:
	_build()
	return _regions


## A region by id, or null.
static func region(id: String) -> Variant:
	for reg in regions():
		if str(reg.id) == id:
			return reg
	return null


## The 80 road stages in order (do not change what it returns).
static func all_stages() -> Array:
	_build()
	var out = []
	for id in _order:
		out.append(_stages[id])
	return out


## The 80 echo stages in order ("e1s1" .. "e8s10").
static func echo_stages() -> Array:
	_build_echoes()
	return _echoes


## A stage by id: a road stage, an echo stage, or "spire:<floor>". Null for
## anything else (the hunt and the rival are made by their own functions).
static func stage(id: String) -> Variant:
	_build()
	if _stages.has(id):
		return _stages[id]
	if id.begins_with("e"):
		_build_echoes()
		return _stages.get(id)
	if id.begins_with("spire:"):
		var f = int(id.substr(6))
		return spire(f) if f >= 1 else null
	return null


## The region id of a road or echo stage ("" for anything else).
static func region_of(stage_id: String) -> String:
	var st = stage(stage_id) if (stage_id.begins_with("r") or stage_id.begins_with("e")) else null
	return str(st.region) if st is Dictionary else ""


## The id of the stage after this one, across regions ("r1s10" -> "r2s1").
## "" after the last stage of the road or of the echoes, and for an id that
## is not a road or echo stage.
static func next_stage(stage_id: String) -> String:
	var st = stage(stage_id)
	if not (st is Dictionary) or not (stage_id.begins_with("r") or stage_id.begins_with("e")):
		return ""
	var r = int(st.r)
	var s = int(st.s)
	var head = "e" if bool(st.echo) else "r"
	if s < RpgDefs.STAGES_PER_REGION:
		return "%s%ds%d" % [head, r, s + 1]
	if r < RpgDefs.REGIONS.size():
		return "%s%ds1" % [head, r + 1]
	return ""


static func _prev(st: Dictionary) -> String:
	var r = int(st.r)
	var s = int(st.s)
	var head = "e" if bool(st.echo) else "r"
	if s > 1:
		return "%s%ds%d" % [head, r, s - 1]
	if r > 1:
		return "%s%ds%d" % [head, r - 1, RpgDefs.STAGES_PER_REGION]
	return "r%ds%d" % [RpgDefs.REGIONS.size(), RpgDefs.STAGES_PER_REGION] if bool(st.echo) else ""


static func _wins(rpg: Dictionary, stage_id: String) -> int:
	var rec = rpg.get("stages", {}).get(stage_id)
	return int(rec.get("wins", 0)) if rec is Dictionary else 0


## Is a road or echo stage behind the player: won, or for a cache, taken?
static func done(rpg: Dictionary, stage_id: String) -> bool:
	var st = stage(stage_id)
	if not (st is Dictionary):
		return false
	if str(st.kind) == "cache":
		return bool(rpg.get("caches", {}).get(stage_id, false))
	return _wins(rpg, stage_id) > 0


## May this be played now? The first stage of the Rustyard always; a stage
## once the one before it is won (a cache: taken), which makes a region open
## when the boss before it falls; the echoes after the Hollow Titan; a Spire
## floor after the second region's boss, floors in order; a hunt and a rival
## whenever there is one.
static func is_open(rpg: Dictionary, stage_id: String) -> bool:
	if stage_id.begins_with("hunt:") or stage_id.begins_with("rival:"):
		return true
	if stage_id.begins_with("dare:"):
		return dare(stage_id.substr(5), rpg) != null
	if stage_id.begins_with("spire:"):
		var f = int(stage_id.substr(6))
		return f >= 1 and spire_open(rpg) and f <= int(rpg.get("spire", {}).get("best", 0)) + 1
	var st = stage(stage_id)
	if not (st is Dictionary):
		return false
	var before = _prev(st)
	return before == "" or done(rpg, before)


## A DARE (RPG_PLAN.md 8.4, added 2026-11-27): a road stage that is already won, fought again with its foes
## raised to the PLAYER'S OWN STRENGTH and one rule of RULES (the stage's own, by its place: the echo's).
## Its foes stand at the highest of: the stage's own index, the highest index won + DARE_OVER, and (when the
## hero's `power` is given) the highest index whose recommended power the hero has (`n_for_power`): a hero
## whose real training is far ahead of his place on the road gets an even fight, not another walk.
## Null for a stage not won, a cache, an echo. Its id is "dare:<stage id>", its kind "dare", "of" the stage.
## No stars. The first win pays `first` and leaves a seal on the stage (saved.rpg.stages[id].dares counts).
const DARE_OVER = 2.0
## No dare stands higher than this index.
const DARE_TOP = 110.0

## The highest whole index from `lo` up whose recommended power (`rec_of`) is at most `power`.
static func n_for_power(power: float, lo: float) -> float:
	var n = lo
	while n + 1.0 <= DARE_TOP and rec_of(n + 1.0) <= power:
		n += 1.0
	return n


static func dare(stage_id: String, rpg: Dictionary, power: float = 0.0) -> Variant:
	var src = stage(stage_id)
	if not (src is Dictionary) or not stage_id.begins_with("r") or str(src.kind) == "cache" or not done(rpg, stage_id):
		return null
	var r = int(src.r)
	var s = int(src.s)
	var n = maxf(float(src.n), best_n(rpg) + DARE_OVER)
	if power > 0.0:
		n = maxf(n, n_for_power(power, float(src.n)))
	n = minf(n, maxf(DARE_TOP, float(src.n)))
	var lists = []
	for wave in src.waves:
		lists.append(wave.map(func(en): return str(en.foe)))
	var waves = _waves(lists, n)
	var rule = _echo_rule(r, s, waves)
	var first = _no_first()
	first["ore"] = int(round(60.0 * pow(1.15, n / 10.0)))
	if str(src.kind) != "battle":
		first["rune"] = true
	return {"id": "dare:" + stage_id, "of": stage_id, "region": str(src.region), "r": r, "s": s, "n": n,
		"name": "%s: Dare" % str(src.name), "text": "A dare: the same place with foes as strong as you are. %s" % str(RULES[rule].text),
		"kind": "dare", "of_kind": str(src.kind), "dare": true, "scene": str(src.scene),
		"waves": waves, "rules": [rule], "rule": rule, "stars": [], "par": 0, "first": first, "rec": rec_of(n)}


## Has the dare of a road stage been won?
static func dared(rpg: Dictionary, stage_id: String) -> bool:
	var rec = rpg.get("stages", {}).get(stage_id)
	return rec is Dictionary and int(rec.get("dares", 0)) > 0


## The dares of a region: {"won", "of" (its stages that can be dared: all but the cache), "next" (the first
## stage that is won and not dared yet, "" when there is none)}. All of them won opens the region's dare chest.
static func dare_progress(rpg: Dictionary, region_id: String) -> Dictionary:
	var out = {"won": 0, "of": 0, "next": ""}
	var reg = region(region_id)
	if reg == null:
		return out
	for id in reg.ids:
		var st = stage(str(id))
		if not (st is Dictionary) or str(st.kind) == "cache":
			continue
		out.of += 1
		if dared(rpg, str(id)):
			out.won += 1
		elif str(out.next) == "" and done(rpg, str(id)):
			out["next"] = str(id)
	return out


## How many stages have their dare won.
static func dare_count(rpg: Dictionary) -> int:
	var n = 0
	var won = rpg.get("stages", {})
	if won is Dictionary:
		for id in won:
			if won[id] is Dictionary and int(won[id].get("dares", 0)) > 0:
				n += 1
	return n


## The highest difficulty index won so far on the road or in the echoes (0 before any win).
static func best_n(rpg: Dictionary) -> float:
	var best = 0.0
	var won = rpg.get("stages", {})
	for id in won:
		if won[id] is Dictionary and int(won[id].get("wins", 0)) > 0:
			var st = stage(str(id))
			if st is Dictionary and float(st.n) > best:
				best = float(st.n)
	return best


## The waves of a stage as they will be fought: with "one more wave" the first
## wave's regular foes stand in front once more (what the engine does).
static func waves_fought(st: Dictionary) -> Array:
	var waves = st.get("waves", []).duplicate(true)
	if st.get("rules", []).has("extra_wave") and not waves.is_empty():
		var again = []
		for en in waves[0]:
			if foe_kind(en) == "regular":
				again.append(en.duplicate(true))
		if not again.is_empty():
			waves.insert(0, again)
	return waves


## The hero turns a stage's second star allows: PAR_PER_WAVE for every wave
## of regular foes as it will be fought, PAR_ELITE for one with an elite,
## PAR_BOSS for one with a boss.
static func par_of(st: Dictionary) -> int:
	var par = 0
	for wave in waves_fought(st):
		var top = PAR_PER_WAVE
		for en in wave:
			var fk = foe_kind(en)
			if fk == "boss":
				top = PAR_BOSS
			elif fk == "elite" and top < PAR_ELITE:
				top = PAR_ELITE
		par += top
	return par


# =============================================================================
# Stars
# =============================================================================

## Is one objective met by how a battle went (RpgBattle.summary)?
static func met(obj: Dictionary, summary: Dictionary) -> bool:
	if not bool(summary.get("win", false)):
		return false
	var v = float(obj.get("v", 0))
	match str(obj.get("k", "")):
		"win":
			return true
		"turns":
			return int(summary.get("turns", 9999)) <= int(v)
		"break":
			return int(summary.get("breaks", 0)) >= maxi(1, int(v))
		"no_items":
			return int(summary.get("items", 0)) == 0
		"hp_half":
			return float(summary.get("hp_share", 0.0)) >= v
		"no_guard":
			return int(summary.get("guards", 0)) == 0
		"schools3":
			var schools = summary.get("schools", [])
			return schools is Array and schools.size() >= maxi(1, int(v))
		"no_big_hit":
			return float(summary.get("worst_share", 1.0)) <= v
	return false


## The three stars of a battle: [win, turns, the stage's own]. All false for a
## loss and for a stage without stars.
static func stars(st: Dictionary, summary: Dictionary) -> Array:
	var out = [false, false, false]
	var objs = st.get("stars", [])
	for i in range(mini(3, objs.size())):
		out[i] = met(objs[i], summary)
	return out


## The stars a region's road stages hold in the save (27 to be had).
static func star_count(rpg: Dictionary, region_id: String) -> int:
	var reg = region(region_id)
	if reg == null:
		return 0
	var count = 0
	var won = rpg.get("stages", {})
	for id in reg.ids:
		var rec = won.get(id)
		if rec is Dictionary and rec.get("stars") is Array:
			for s in rec.stars:
				if s is bool and s:
					count += 1
	return count


## An objective in plain words ("Win in 12 turns or fewer").
static func objective_words(obj: Dictionary) -> String:
	var v = float(obj.get("v", 0))
	match str(obj.get("k", "")):
		"win":
			return "Win the fight"
		"turns":
			return "Win in %d turns or fewer" % int(v)
		"break":
			return "Break a guard" if int(v) <= 1 else "Break %d guards" % int(v)
		"no_items":
			return "Use nothing from the belt"
		"hp_half":
			return "Finish with %d%% of your health or more" % int(round(v * 100.0))
		"no_guard":
			return "Never use Guard"
		"schools3":
			return "Use moves of %d different schools" % int(v)
		"no_big_hit":
			return "Take no single hit over %d%% of your health" % int(round(v * 100.0))
	return ""


# =============================================================================
# Beyond the road
# =============================================================================

## The regular foes a pack may be drawn from: the regions up to `reach` (1..8).
static func _pool(reach: int) -> Array:
	var out = []
	for i in range(clampi(reach, 1, RpgDefs.REGIONS.size())):
		out.append_array(RpgFoes.of_region(str(RpgDefs.REGIONS[i])).regular)
	return out


## Three different regular foes from a pool, by a stream: one healer, one
## bomb and one tank at most (a pack of menders is no fight).
static func _pack(pool: Array, st: Rng.Stream, size: int = 3) -> Array:
	var left = pool.duplicate()
	var out = []
	var roles = {}
	while out.size() < size and not left.is_empty():
		var at = st.next_int(left.size())
		var id = str(left[at])
		left.remove_at(at)
		var role = str(RpgFoes.by_id(id).role)
		if ["healer", "bomb", "tank"].has(role) and roles.has(role):
			continue
		roles[role] = true
		out.append(id)
	return out


## Two different attack schools: the ones given first, the rest drawn by the stream.
static func _two_schools(given: Array, st: Rng.Stream) -> Array:
	var out = []
	for sc in given:
		if RpgDefs.ATTACK_SCHOOLS.has(sc) and not out.has(sc) and out.size() < 2:
			out.append(str(sc))
	var left = RpgDefs.ATTACK_SCHOOLS.filter(func(sc): return not out.has(sc))
	while out.size() < 2 and not left.is_empty():
		var at = st.next_int(left.size())
		out.append(str(left[at]))
		left.remove_at(at)
	return out


## The daily hunt (8.4): one pack at the best index won + 2, one rule, and
## every foe weak to the schools of today's boosts (none: two drawn by the
## date). The same date, progress and boosts give the same hunt. "prizes" =
## the three to pick one from after the day's first win (RpgLoot.hunt_prizes).
static func hunt(date: String, rpg: Dictionary, boosts: Array) -> Dictionary:
	var st = Rng.make_rng("hunt:" + date)
	var best = best_n(rpg)
	var n = best + HUNT_AHEAD
	var reach = int(floor((best + 1.0) / 10.0)) + 1
	var foes = _pack(_pool(reach), st)
	var rule = str(RULE_IDS[st.next_int(RULE_IDS.size())])
	var weak = _two_schools(RpgBoosts.schools(boosts), st)
	var wave = []
	for id in foes:
		wave.append({"foe": id, "n": n, "weak": weak.duplicate()})
	var out = {"id": "hunt:" + date, "region": "", "r": 0, "s": 0, "n": n, "name": "Daily Hunt",
		"text": "A pack has come down to the edge of the Ironwild. %s Today they are weak to %s and %s." % [str(RULES[rule].text),
			str(RpgDefs.SCHOOL_NAMES[weak[0]]), str(RpgDefs.SCHOOL_NAMES[weak[1]])],
		"kind": "hunt", "echo": false, "scene": "hunt", "waves": [wave], "rules": [rule], "stars": [], "par": 0,
		"first": _no_first(), "rec": rec_of(n), "date": date, "rule": rule, "weak": weak, "prizes": []}
	out["par"] = par_of(out)
	out["prizes"] = RpgLoot.hunt_prizes(date, n, rpg)
	return out


## The weekly rival (8.4): the main game's bounty monster of the week (read
## only: state.weekly.current) as a boss at the best index won + 5, weak to
## the schools of its weak muscle group. It fights with the moves of one of
## the road's elites (by the monster), has no phases, and its sprite is the
## monster's own "wk_..." id. Null when there is no bounty this week.
static func rival(state: Dictionary, rpg: Dictionary) -> Variant:
	var weekly = state.get("weekly")
	var cur = weekly.get("current") if weekly is Dictionary else null
	if not (cur is Dictionary) or str(cur.get("monster", "")) == "" or str(cur.get("week", "")) == "":
		return null
	var week = str(cur.week)
	var mon = Bounty.monster(str(cur.monster))
	var mid = str(mon.id)
	var st = Rng.make_rng("rival:" + week)
	var weak = _two_schools(PART_SCHOOLS.get(str(cur.get("weakPart", "")), []), st)
	var model = RpgFoes.by_id(str(regions()[Rng.hash_string("rival-moves:" + mid) % regions().size()].elite))
	var row = {"id": mid, "name": str(mon.name), "region": "", "role": "boss", "weak": weak.duplicate(), "resist": [], "guard": null,
		"moves": model.moves.duplicate(), "pattern": model.pattern.duplicate(), "rules": model.rules.duplicate(true),
		"traits": model.traits.duplicate(true), "phases": [], "boss": true, "elite": false, "text": str(mon.get("epithet", ""))}
	var n = best_n(rpg) + RIVAL_AHEAD
	# the week's one prize: a relic the player does not have yet, or a rune, and ore
	var first = _no_first()
	first["ore"] = RpgDefs.foe_ore(n, "boss")
	if st.next() < 0.5:
		first["relic"] = "any"
	else:
		first["rune"] = true
	return {"id": "rival:" + week, "region": "", "r": 0, "s": 0, "n": n, "name": str(mon.name),
		"text": "%s This week it is weak to %s and %s." % [str(mon.get("epithet", "")), str(RpgDefs.SCHOOL_NAMES[weak[0]]), str(RpgDefs.SCHOOL_NAMES[weak[1]])],
		"kind": "rival", "echo": false, "scene": "rival",
		"waves": [[{"foe": mid, "n": n, "row": row, "weak": weak.duplicate()}]], "rules": [], "stars": [], "par": PAR_BOSS,
		"first": first, "rec": rec_of(n), "week": week, "weak": weak, "monster": mid, "custom": {"foes": {mid: row.duplicate(true)}}}


## The difficulty index of a Spire floor: 10 + 2 a floor to floor 35, then half a point a floor.
static func spire_n(floor_no: int) -> float:
	var f = maxi(1, floor_no)
	if f <= SPIRE_BEND:
		return 10.0 + SPIRE_STEP * float(f)
	return 10.0 + SPIRE_STEP * float(SPIRE_BEND) + SPIRE_SLOW * float(f - SPIRE_BEND)


## The Spire is climbed once the second region's boss has fallen.
static func spire_open(rpg: Dictionary) -> bool:
	return _wins(rpg, "r%ds%d" % [RpgDefs.SPIRE_AFTER_REGION, RpgDefs.STAGES_PER_REGION]) > 0


## A Spire floor (8.4): a fixed pack by the floor's number; an elite with one
## add every fifth floor, a boss every tenth (the road's bosses in turn). It
## has no end.
static func spire(floor_no: int) -> Dictionary:
	var f = maxi(1, floor_no)
	var n = spire_n(f)
	var st = Rng.make_rng("spire:%d" % f)
	var wave = []
	var title = "Floor %d" % f
	var text = "One more flight of stairs. Something is waiting on the landing."
	var first = _no_first()
	if f % 10 == 0:
		var reg = regions()[(int(f / 10.0) - 1) % regions().size()]
		wave.append({"foe": str(reg.boss), "n": n})
		text = "A landing wide enough for something big. %s got here first." % str(RpgFoes.by_id(str(reg.boss)).name)
		first["rune"] = true
		first["relic"] = "any"
	elif f % 5 == 0:
		var reg = regions()[st.next_int(regions().size())]
		var adds = RpgFoes.of_region(str(reg.id)).regular.filter(func(id): return ["swarm", "skirmisher"].has(str(RpgFoes.by_id(id).role)))
		wave.append({"foe": str(reg.elite), "n": n})
		if not adds.is_empty():
			wave.append({"foe": str(adds[st.next_int(adds.size())]), "n": n})
		text = "The stairs open onto a wide landing. %s is taking up most of it." % str(RpgFoes.by_id(str(reg.elite)).name)
		first["rune"] = true
	else:
		for id in _pack(_pool(RpgDefs.REGIONS.size()), st):
			wave.append({"foe": id, "n": n})
	return {"id": "spire:%d" % f, "region": "", "r": 0, "s": 0, "n": n, "name": title, "text": text,
		"kind": "spire", "echo": false, "scene": "spire", "waves": [wave], "rules": [], "stars": [], "par": par_of({"waves": [wave]}),
		"first": first, "rec": rec_of(n), "floor": f}


## The echo regions open once the Hollow Titan has fallen.
static func echoes_open(rpg: Dictionary) -> bool:
	return _wins(rpg, "r%ds%d" % [RpgDefs.REGIONS.size(), RpgDefs.STAGES_PER_REGION]) > 0


# =============================================================================
# A battle
# =============================================================================

## The stage a `what` means, or null. `what` = {"kind", "id"}; it may bring
## the stage itself ("stage"), a hunt wants "boosts" and a rival "state".
static func stage_of(what: Dictionary, rpg: Dictionary) -> Variant:
	if what.get("stage") is Dictionary:
		return what.stage
	var id = str(what.get("id", ""))
	match str(what.get("kind", "")):
		"stage", "echo":
			var st = stage(id)
			return st if (st is Dictionary and (id.begins_with("r") or id.begins_with("e"))) else null
		"dare":
			return dare(id.substr(5), rpg, float(what.get("power", 0.0))) if id.begins_with("dare:") else null
		"spire":
			var f = int(id.substr(6)) if id.begins_with("spire:") else int(what.get("floor", 0))
			return spire(f) if f >= 1 else null
		"hunt":
			var date = id.substr(5) if id.begins_with("hunt:") else str(what.get("date", ""))
			return hunt(date, rpg, what.get("boosts") if what.get("boosts") is Array else []) if date != "" else null
		"rival":
			return rival(what.get("state") if what.get("state") is Dictionary else {}, rpg)
	return null


## What RpgBattle.start takes, for a road or echo stage, a hunt, a rival or a
## Spire floor. {} when there is nothing to fight (an unknown stage, a cache).
## The engine itself sizes the packs, halves an elite's or a boss's adds and
## applies the rules; what the hero has learned of the foes (rpg.seen) goes in
## as "known". "what" in the result is {"kind", "id"} and nothing heavier, so
## a stored battle stays small.
static func setup(what: Dictionary, rpg: Dictionary, hero_unit: Dictionary, pet_unit, battle_seed: int, today: String) -> Dictionary:
	var st = stage_of(what, rpg)
	if not (st is Dictionary) or st.get("waves", []).is_empty():
		return {}
	var known = {}
	var seen = rpg.get("seen", {})
	for k in seen:
		if seen[k] is Array:
			known[str(k)] = seen[k].duplicate()
	var kind = str(what.get("kind", ""))
	if kind == "":
		kind = "echo" if bool(st.get("echo", false)) else ("stage" if ["battle", "elite", "boss"].has(str(st.kind)) else str(st.kind))
	# Move mastery: the hero's equipped moves as he plays them by now (RpgMoves.mastered), as rows of the battle.
	var custom = st.get("custom", {}).duplicate(true)
	var mastery = rpg.get("mastery", {})
	if mastery is Dictionary and hero_unit.get("moves") is Array:
		for id in hero_unit.moves:
			var lvl = RpgDefs.mastery_level(int(mastery.get(str(id), 0)))
			if lvl <= 0:
				continue
			if not (custom.get("moves") is Dictionary):
				custom["moves"] = {}
			if not custom.moves.has(str(id)):
				custom.moves[str(id)] = RpgMoves.mastered(str(id), lvl)
	return {"hero": hero_unit, "pet": pet_unit if pet_unit is Dictionary else null,
		"waves": st.waves.duplicate(true), "seed": battle_seed, "what": {"kind": kind, "id": str(st.id)},
		"rules": st.get("rules", []).duplicate(), "known": known, "day": today,
		"custom": custom}
