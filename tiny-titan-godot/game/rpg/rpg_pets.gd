class_name RpgPets
extends RefCounted
## Companion kits (RPG_PLAN.md 4.7, 7.4): what each of the game's pets does in
## a fight. Ids are the ids of `Pets` (game/pets.gd); a pet's name and rarity
## are read there. Pure data: a const table and its readers.
##
## A kit:
##   {"id",
##    "auto": {"name", "kind": "attack"|"support", "power", "school", "fx": [effects], "every": int},
##        what it does by itself on each of its turns (every: only each Nth turn)
##    "command": {"name", "charge": int (2..4), "power", "target": "foe"|"all"|"self", "school",
##                "fx": [effects], "text"},
##        what the hero may call for, free, once it has that many charges (1 a turn)
##    "passive": [passive effects]}     in force for the hero while it is the companion
##
## A companion is never a target. Its hits use RpgDefs.offence(the hero's best
## body stat * 0.5, 0, the hero's level) * RpgDefs.PET_RARITY[rarity]; they are
## never weak or resisted and never chip a guard (an effect {"k": "chip"} does).
## Its `school` is only the colour of the burst. In an effect, "self" is the
## hero and "target" the foe it hit (a support action: the foe the hero last
## picked).
##
## A row without command "text" gets one made from the effects. What the auto
## action does, in words, is in AUTO_TEXT (the engine's check_pet allows no
## "text" inside "auto"): read both through `words(id)`.
##
## The themes (RPG_PLAN.md 7.4): the five commons each do one small thing, the
## rares one strong thing, Ember keeps the hero standing once, Titan Jr. burns
## everything. Charge 2 to 4: a command comes round about once a wave.
##
## To add a kit: one more row in ROWS and its line in AUTO_TEXT.

const ROWS = [
	# Gloop the slime: slows. Its spit sometimes sticks; its command gums up the whole floor.
	{"id": "slime",
		"auto": {"name": "Goo Spit", "kind": "attack", "power": 0.35, "school": "flow", "fx": [{"k": "status", "id": "slowed", "turns": 1, "chance": 0.35}], "every": 1},
		"command": {"name": "Sticky Floor", "charge": 3, "power": 0.0, "target": "all", "school": "flow",
			"fx": [{"k": "status", "id": "slowed", "turns": 2}], "text": "Every foe is Slowed for 2 turns."},
		"passive": []},
	# Rep the bulldog: an attacker. Bites every turn; its command opens the foe up.
	{"id": "bulldog",
		"auto": {"name": "Bite", "kind": "attack", "power": 0.5, "school": "push", "fx": [], "every": 1},
		"command": {"name": "Lockjaw", "charge": 3, "power": 1.2, "target": "foe", "school": "push",
			"fx": [{"k": "status", "id": "exposed", "turns": 2}]},
		"passive": []},
	# Crimpy the gecko: chips guard, whatever the foe is weak to.
	{"id": "gecko",
		"auto": {"name": "Tail Flick", "kind": "support", "power": 0.0, "school": "grip", "fx": [{"k": "chip", "n": 1}], "every": 2},
		"command": {"name": "Sticky Grip", "charge": 3, "power": 0.6, "target": "foe", "school": "grip",
			"fx": [{"k": "chip", "n": 2}], "text": "A hit that chips 2 guard, whatever the foe is weak to."},
		"passive": []},
	# Coach the pigeon: energy and pace.
	{"id": "pigeon",
		"auto": {"name": "Pace Check", "kind": "support", "power": 0.0, "school": "speed", "fx": [{"k": "energy", "n": 1}], "every": 3},
		"command": {"name": "Pick It Up", "charge": 3, "power": 0.0, "target": "self", "school": "speed",
			"fx": [{"k": "status", "id": "hasted", "turns": 2}, {"k": "energy", "n": 1}], "text": "You are Hasted for 2 turns and get 1 energy."},
		"passive": []},
	# Pedals the hamster: the gauge and energy.
	{"id": "hamster",
		"auto": {"name": "Wheel Time", "kind": "support", "power": 0.0, "school": "grit", "fx": [{"k": "gauge", "n": 4}], "every": 2},
		"command": {"name": "Full Spin", "charge": 4, "power": 0.0, "target": "self", "school": "grit",
			"fx": [{"k": "energy", "n": 3}, {"k": "gauge", "n": 10}], "text": "You get 3 energy and 10 gauge."},
		"passive": []},
	# Sprout: support. A little healing every other turn; its command heals and cleanses.
	{"id": "sprout",
		"auto": {"name": "Fresh Leaf", "kind": "support", "power": 0.0, "school": "flow", "fx": [{"k": "heal", "pct": 0.03}], "every": 2},
		"command": {"name": "Photosynthesis", "charge": 4, "power": 0.0, "target": "self", "school": "flow",
			"fx": [{"k": "heal", "pct": 0.18}, {"k": "cleanse", "n": 0}]},
		"passive": []},
	# Tonnage the ox: slow, heavy hits; its command is a stomp on everybody.
	{"id": "ox",
		"auto": {"name": "Horn Shove", "kind": "attack", "power": 1.0, "school": "legs", "fx": [], "every": 2},
		"command": {"name": "Stomp", "charge": 4, "power": 1.3, "target": "all", "school": "legs",
			"fx": [{"k": "delay", "pct": 0.25}], "text": "A heavy stomp on every foe that pushes their turns back a little."},
		"passive": []},
	# Cliff the goat: stuns.
	{"id": "goat",
		"auto": {"name": "Headbutt", "kind": "attack", "power": 0.45, "school": "grip", "fx": [], "every": 1},
		"command": {"name": "Ram", "charge": 4, "power": 1.0, "target": "foe", "school": "grip",
			"fx": [{"k": "status", "id": "stun", "chance": 0.8}], "text": "A hard hit that will probably Stun: the foe loses its next action."},
		"passive": []},
	# Zoom the greyhound: an extra turn for the hero.
	{"id": "greyhound",
		"auto": {"name": "Nip", "kind": "attack", "power": 0.4, "school": "speed", "fx": [], "every": 1},
		"command": {"name": "Zoomies", "charge": 4, "power": 0.0, "target": "self", "school": "speed",
			"fx": [{"k": "extra_turn"}], "text": "After your next action you act again at once."},
		"passive": [{"p": "spd_pct", "pct": 0.05}]},
	# Draft the falcon: opens up every foe at once.
	{"id": "falcon",
		"auto": {"name": "Dive", "kind": "attack", "power": 0.5, "school": "speed", "fx": [], "every": 1},
		"command": {"name": "Slipstream", "charge": 4, "power": 0.6, "target": "all", "school": "speed",
			"fx": [{"k": "status", "id": "exposed", "turns": 2}], "text": "Hits every foe and leaves them Exposed for 2 turns."},
		"passive": []},
	# Pebble the golemling: shields.
	{"id": "golemling",
		"auto": {"name": "Pebble Wall", "kind": "support", "power": 0.0, "school": "grit", "fx": [{"k": "shield", "pct": 0.05}], "every": 2},
		"command": {"name": "Rock Wall", "charge": 3, "power": 0.0, "target": "self", "school": "grit",
			"fx": [{"k": "shield", "pct": 0.2}], "text": "A Shield of 20% of max HP."},
		"passive": []},
	# Steady the tortoise: Braced, and one big shield.
	{"id": "tortoise",
		"auto": {"name": "Slow and Smooth", "kind": "support", "power": 0.0, "school": "grit", "fx": [{"k": "status", "id": "braced", "turns": 1}], "every": 3},
		"command": {"name": "Shell Up", "charge": 4, "power": 0.0, "target": "self", "school": "grit",
			"fx": [{"k": "shield", "pct": 0.3}, {"k": "status", "id": "braced", "turns": 3}], "text": "A Shield of 30% of max HP, and you are Braced for 3 turns."},
		"passive": []},
	# Deload the cat: weakens, and knocks buffs off the shelf.
	{"id": "cat",
		"auto": {"name": "Swat", "kind": "attack", "power": 0.35, "school": "flow", "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.35}], "every": 1},
		"command": {"name": "Knock It Off", "charge": 3, "power": 0.6, "target": "foe", "school": "flow",
			"fx": [{"k": "dispel", "n": 0}, {"k": "status", "id": "weakened", "turns": 2}], "text": "A hit that strips every buff from the foe and leaves it Weakened for 2 turns."},
		"passive": [{"p": "reward", "what": "luck", "pct": 0.08}]},
	# Ember the phoenix: burns, and once a battle keeps the hero standing.
	{"id": "phoenix",
		"auto": {"name": "Cinder", "kind": "attack", "power": 0.4, "school": "mind", "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.5}], "every": 1},
		"command": {"name": "Rebirth Flame", "charge": 4, "power": 1.0, "target": "all", "school": "mind",
			"fx": [{"k": "status", "id": "burn", "turns": 3}]},
		"passive": [{"p": "survive", "pct": 0.3}]},
	# Titan Jr. the dragon: fire on everybody.
	{"id": "dragon",
		"auto": {"name": "Ember Puff", "kind": "attack", "power": 0.45, "school": "mind", "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.4}], "every": 1},
		"command": {"name": "Dragonfire", "charge": 4, "power": 1.5, "target": "all", "school": "mind",
			"fx": [{"k": "status", "id": "burn", "turns": 3}], "text": "Fire on every foe: a big hit, and they Burn for 3 turns."},
		"passive": []},
	# Page the owl: shows what the foes are weak to, and marks one.
	{"id": "owl",
		"auto": {"name": "Read Ahead", "kind": "support", "power": 0.0, "school": "mind", "fx": [{"k": "status", "id": "insight", "turns": 2}], "every": 3},
		"command": {"name": "Dog-Ear", "charge": 3, "power": 0.0, "target": "foe", "school": "mind",
			"fx": [{"k": "status", "id": "marked"}], "text": "Marks the foe: your next 2 moves on it count as hitting a weakness."},
		"passive": []},
]

## What each auto action does, in plain words.
const AUTO_TEXT = {
	"slime": "Spits goo every turn: a small hit that sometimes Slows the foe.",
	"bulldog": "Bites the foe you last picked, every turn.",
	"gecko": "Every other turn it chips 1 guard off the foe you last picked.",
	"pigeon": "Every third turn it gives you 1 energy.",
	"hamster": "Every other turn it adds 4 to the gauge.",
	"sprout": "Every other turn it heals you a little (3% of max HP).",
	"ox": "Every other turn it lands one heavy hit.",
	"goat": "Headbutts the foe you last picked, every turn.",
	"greyhound": "Nips the foe you last picked, every turn.",
	"falcon": "Dives at the foe you last picked, every turn.",
	"golemling": "Every other turn it gives you a small Shield (5% of max HP).",
	"tortoise": "Every third turn it leaves you Braced for a turn.",
	"cat": "Swats every turn: a small hit that sometimes leaves the foe Weakened.",
	"phoenix": "A small fiery hit every turn that sets the foe on fire half the time.",
	"dragon": "A puff of fire every turn that often sets the foe on fire.",
	"owl": "Every third turn it gives you Insight: you see what the foes are weak to.",
}

static var _all = null
static var _by_id = null


## Every kit, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			var kit = row.duplicate(true)
			if str(kit.command.get("text", "")) == "":
				var parts = []
				if float(kit.command.get("power", 0.0)) > 0.0:
					parts.append("Hits every foe" if str(kit.command.get("target", "foe")) == "all" else "A hard hit")
				for e in kit.command.get("fx", []):
					var w = RpgBattle.fx_words(e, float(kit.command.get("power", 0.0)) > 0.0)
					if w != "":
						parts.append(w)
				kit.command["text"] = ". ".join(parts) + "."
			list.append(kit)
		_all = list
	return _all


## A kit by pet id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for kit in all():
			map[kit.id] = kit
		_by_id = map
	return _by_id.get(id)


## A kit in words: {"auto": what it does by itself, "command": what its command
## does, "passive": what holds while it is the companion ("" = nothing)}; null
## for a pet with no kit.
static func words(id: String) -> Variant:
	var kit = by_id(id)
	if kit == null:
		return null
	var parts = []
	for e in kit.passive:
		var w = RpgBattle.passive_words(e)
		if w != "":
			parts.append(w)
	return {"auto": str(AUTO_TEXT.get(id, "")), "command": str(kit.command.get("text", "")),
		"passive": (". ".join(parts) + ".") if not parts.is_empty() else ""}
