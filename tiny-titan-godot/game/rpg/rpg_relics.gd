class_name RpgRelics
extends RefCounted
## Relics (RPG_PLAN.md 7.2): finds of the Realm alone. A relic changes how a
## build plays; a fighter wears one, a second from level 8, a third from 30
## (RpgDefs.RELIC_SLOTS_AT). Pure data: a const table and its readers.
##
## A relic: {"id" (RpgDefs.id_of(name)), "name", "rarity" ("rare" | "epic" |
## "legendary": 8, 10 and 6 of them), "icon" (an Icons name), "text" (what it
## does, in plain words), "fx": [passive effects]}. The effects are the
## engine's `p` vocabulary (the head of rpg_battle.gd): RpgHero.build puts them
## into the hero's unit. A second copy found is paid out in ore (dup_ore).
##
## To add a relic: one more row in ROWS.

const ROWS = [
	# --- rare ---
	{"id": "coachs_whistle", "name": "Coach's Whistle", "rarity": "rare", "icon": "rl_whistle",
		"text": "You act first, and start with 1 more energy.",
		"fx": [{"p": "first_turn"}, {"p": "en_start", "n": 1}]},
	{"id": "frayed_bookmark", "name": "Frayed Bookmark", "rarity": "rare", "icon": "rl_bookmark",
		"text": "You start every wave with Insight for 1 turn. Your statuses land 10% more often.",
		"fx": [{"p": "start_status", "id": "insight", "turns": 1}, {"p": "status_chance", "add": 0.1}]},
	{"id": "roll_of_finger_tape", "name": "Roll of Finger Tape", "rarity": "rare", "icon": "rl_tape",
		"text": "The first debuff of a battle bounces off you. Debuffs on you last 1 turn less.",
		"fx": [{"p": "bounce"}, {"p": "status_turns", "on": "self_debuff", "add": -1}]},
	{"id": "resistance_band", "name": "Resistance Band", "rarity": "rare", "icon": "rl_band",
		"text": "Each move of the same school as the one before it hits 6% harder, up to 18%.",
		"fx": [{"p": "combo_same", "pct": 0.06, "max": 0.18}]},
	{"id": "broken_chain_link", "name": "Broken Chain Link", "rarity": "rare", "icon": "rl_chain",
		"text": "+20% against Broken foes.",
		"fx": [{"p": "vs_broken", "pct": 0.2}]},
	{"id": "cowbell", "name": "Cowbell", "rarity": "rare", "icon": "rl_bell",
		"text": "The gauge fills 15% faster. Breaking a foe's guard adds 8 to it.",
		"fx": [{"p": "gauge_rate", "pct": 0.15}, {"p": "on", "ev": "break", "do": {"k": "gauge", "n": 8}}]},
	{"id": "chipped_tooth", "name": "Chipped Tooth", "rarity": "rare", "icon": "rl_tooth",
		"text": "A crit makes the foe Bleed for 2 turns.",
		"fx": [{"p": "on", "ev": "crit", "do": {"k": "status", "id": "bleed", "turns": 2, "to": "target"}}]},
	{"id": "pigeon_feather", "name": "Pigeon Feather", "rarity": "rare", "icon": "rl_feather",
		"text": "Every third turn you gain Evade: the next hit misses you.",
		"fx": [{"p": "on", "ev": "turn", "every": 3, "do": {"k": "status", "id": "evade"}}]},
	# --- epic ---
	{"id": "rest_timer", "name": "Rest Timer", "rarity": "epic", "icon": "rl_hourglass",
		"text": "Every move rests 1 turn less.",
		"fx": [{"p": "cd", "school": "all", "add": -1}]},
	{"id": "starting_horn", "name": "Starting Horn", "rarity": "epic", "icon": "rl_horn",
		"text": "Every wave starts with 2 more energy: the first move is as good as free.",
		"fx": [{"p": "on", "ev": "wave", "do": {"k": "energy", "n": 2}}]},
	{"id": "pocket_anvil", "name": "Pocket Anvil", "rarity": "epic", "icon": "rl_anvil",
		"text": "Push, Pull and Legs hits on a weakness chip 1 more guard.",
		"fx": [{"p": "chip", "on": "push", "add": 1}, {"p": "chip", "on": "pull", "add": 1}, {"p": "chip", "on": "legs", "add": 1}]},
	{"id": "tuning_fork", "name": "Tuning Fork", "rarity": "epic", "icon": "bolt",
		"text": "Speed, Grip and Mind hits on a weakness chip 1 more guard.",
		"fx": [{"p": "chip", "on": "speed", "add": 1}, {"p": "chip", "on": "grip", "add": 1}, {"p": "chip", "on": "mind", "add": 1}]},
	{"id": "metronome", "name": "Metronome", "rarity": "epic", "icon": "clock",
		"text": "A move of a different school than your last one hits 12% harder.",
		"fx": [{"p": "combo_alt", "pct": 0.12}]},
	{"id": "spotters_glove", "name": "Spotter's Glove", "rarity": "epic", "icon": "fx_counter",
		"text": "When you Guard you also Counter: whoever hits you before your next turn is hit back.",
		"fx": [{"p": "on", "ev": "guard", "do": {"k": "status", "id": "counter", "turns": 1, "amount": 1.0}}]},
	{"id": "second_wind_flask", "name": "Second Wind Flask", "rarity": "epic", "icon": "potion",
		"text": "Once a battle, under 35% HP, you heal 30% of max HP.",
		"fx": [{"p": "low_hp", "below": 0.35, "do": {"k": "heal", "pct": 0.3}}]},
	{"id": "prospectors_pan", "name": "Prospector's Pan", "rarity": "epic", "icon": "ore",
		"text": "Wins pay 20% more ore and loot luck is 10% better.",
		"fx": [{"p": "reward", "what": "ore", "pct": 0.2}, {"p": "reward", "what": "luck", "pct": 0.1}]},
	{"id": "chalk_brick", "name": "Chalk Brick", "rarity": "epic", "icon": "it_chalk",
		"text": "Breaking a foe's guard gives you 2 energy.",
		"fx": [{"p": "on", "ev": "break", "do": {"k": "energy", "n": 2}}]},
	{"id": "training_log", "name": "Training Log", "rarity": "epic", "icon": "book",
		"text": "Wins give 15% more fighter XP. Buffs you give yourself last 1 turn longer.",
		"fx": [{"p": "reward", "what": "xp", "pct": 0.15}, {"p": "status_turns", "on": "buff", "add": 1}]},
	# --- legendary ---
	{"id": "titans_knuckle", "name": "Titan's Knuckle", "rarity": "legendary", "icon": "rl_ring",
		"text": "A crit chips 1 guard, whatever the school. Crit chance +5%.",
		"fx": [{"p": "chip", "on": "crit", "add": 1}, {"p": "crit_add", "v": 0.05}]},
	{"id": "hollow_heart", "name": "Hollow Heart", "rarity": "legendary", "icon": "heart",
		"text": "Once a battle a blow that would end you leaves you at 1 HP. Once a battle, under 30% HP, you are Pumped for 3 turns.",
		"fx": [{"p": "survive", "pct": 0.0}, {"p": "low_hp", "below": 0.3, "do": {"k": "status", "id": "pumped", "turns": 3}}]},
	{"id": "flywheel", "name": "Flywheel", "rarity": "legendary", "icon": "wheel",
		"text": "Every move costs 1 less energy. Max energy -2.",
		"fx": [{"p": "cost", "school": "all", "add": -1}, {"p": "en_max", "n": -2}]},
	{"id": "glass_barbell", "name": "Glass Barbell", "rarity": "legendary", "icon": "muscle",
		"text": "All damage +20%. Max HP -15%.",
		"fx": [{"p": "school_pct", "school": "all", "pct": 0.2}, {"p": "hp_pct", "pct": -0.15}]},
	{"id": "bramble_belt", "name": "Bramble Belt", "rarity": "legendary", "icon": "belt",
		"text": "All battle long, whoever hits you is hit back.",
		"fx": [{"p": "start_status", "id": "counter", "turns": 0, "amount": 0.5}]},
	{"id": "hunters_compass", "name": "Hunter's Compass", "rarity": "legendary", "icon": "target",
		"text": "You see every foe's weaknesses all battle. +15% against Marked foes.",
		"fx": [{"p": "start_status", "id": "insight", "turns": 0}, {"p": "vs_status", "id": "marked", "pct": 0.15}]},
]

static var _all = null
static var _by_id = null


## Every relic, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			list.append(row.duplicate(true))
		_all = list
	return _all


## A relic by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for r in all():
			map[r.id] = r
		_by_id = map
	return _by_id.get(id)


## The relic ids of one rarity, in catalog order (what a drop is rolled from).
static func ids_of(rarity: String) -> Array:
	var out = []
	for r in all():
		if str(r.rarity) == rarity:
			out.append(r.id)
	return out


## Ore for a relic found a second time.
static func dup_ore(id: String) -> int:
	var r = by_id(id)
	return int(RpgDefs.DUP_ORE.get(str(r.rarity), 0)) if r != null else 0
