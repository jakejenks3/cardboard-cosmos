class_name RpgItems
extends RefCounted
## Belt items (RPG_PLAN.md 7.3): things used in a fight instead of a move. The
## belt has two slots, three from fighter level 6; a stack can be used at most
## RpgDefs.BELT_USES times in one battle and what was used is taken from the
## save only on a win. Pure data: a const table and its readers.
##
## An item: {"id", "name", "icon" (an Icons name), "text", "fx": [effects],
## "price" (ore at the camp shop)}. The effects are the engine's vocabulary
## (the `k` kinds at the top of rpg_battle.gd); an item's effects land on the
## hero unless one says "to".
##
## A row without "text" gets one made from its effects (RpgBattle.fx_words).
##
## To add an item: one more row in ROWS.

const ROWS = [
	{"id": "protein_shake", "name": "Protein Shake", "icon": "it_shake", "price": 25,
		"fx": [{"k": "heal", "pct": 0.35}]},
	{"id": "mega_shake", "name": "Mega Shake", "icon": "it_mega", "price": 60,
		"fx": [{"k": "heal", "pct": 0.7}]},
	{"id": "electrolytes", "name": "Electrolytes", "icon": "it_electro", "price": 30,
		"fx": [{"k": "energy", "n": 4}]},
	{"id": "smelling_salts", "name": "Smelling Salts", "icon": "it_salts", "price": 40,
		"fx": [{"k": "cleanse", "n": 0}, {"k": "status", "id": "pumped", "turns": 2}]},
	{"id": "chalk_ball", "name": "Chalk Ball", "icon": "it_chalk", "price": 35,
		"fx": [{"k": "status", "id": "focus", "stacks": 2}]},
	{"id": "energy_gel", "name": "Energy Gel", "icon": "it_gel", "price": 40,
		"fx": [{"k": "status", "id": "hasted", "turns": 3}]},
	{"id": "ice_pack", "name": "Ice Pack", "icon": "it_ice", "price": 45,
		"fx": [{"k": "shield", "pct": 0.25}, {"k": "cleanse", "ids": ["burn", "bleed"]}]},
	{"id": "pre_workout", "name": "Pre-Workout", "icon": "it_pre", "price": 70,
		"fx": [{"k": "gauge", "n": 40}]},
]

static var _all = null
static var _by_id = null


## Every item, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			var it = row.duplicate(true)
			if str(it.get("text", "")) == "":
				var parts = []
				for e in it.fx:
					var w = RpgBattle.fx_words(e, false)
					if w != "":
						parts.append(w)
				it["text"] = ". ".join(parts) + "."
			list.append(it)
		_all = list
	return _all


## An item by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for it in all():
			map[it.id] = it
		_by_id = map
	return _by_id.get(id)
