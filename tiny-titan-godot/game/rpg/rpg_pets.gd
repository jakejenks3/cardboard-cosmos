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
## A row without command "text" gets one made from the effects.
##
## To add a kit: one more row in ROWS (the next builder adds the other pets).

const ROWS = [
	# Rep the bulldog: an attacker. Bites every turn; its command opens the foe up.
	{"id": "bulldog",
		"auto": {"name": "Bite", "kind": "attack", "power": 0.5, "school": "push", "fx": [], "every": 1},
		"command": {"name": "Lockjaw", "charge": 3, "power": 1.2, "target": "foe", "school": "push",
			"fx": [{"k": "status", "id": "exposed", "turns": 2}]},
		"passive": []},
	# Sprout: support. A little healing every other turn; its command heals and cleanses.
	{"id": "sprout",
		"auto": {"name": "Fresh Leaf", "kind": "support", "power": 0.0, "school": "flow", "fx": [{"k": "heal", "pct": 0.03}], "every": 2},
		"command": {"name": "Photosynthesis", "charge": 4, "power": 0.0, "target": "self", "school": "flow",
			"fx": [{"k": "heal", "pct": 0.18}, {"k": "cleanse", "n": 0}]},
		"passive": []},
	# Ember the phoenix: burns, and once a battle keeps the hero standing.
	{"id": "phoenix",
		"auto": {"name": "Cinder", "kind": "attack", "power": 0.4, "school": "mind", "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.5}], "every": 1},
		"command": {"name": "Rebirth Flame", "charge": 4, "power": 1.0, "target": "all", "school": "mind",
			"fx": [{"k": "status", "id": "burn", "turns": 3}]},
		"passive": [{"p": "survive", "pct": 0.3}]},
]

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
