class_name RpgPassives
extends RefCounted
## Board passives (RPG_PLAN.md 6): three slots, opened at fighter level 3, 10
## and 20. Pure data: a const table and its readers.
##
## A passive: {"id", "name", "board" (its school), "tier" (1, 3 or 4: the board
## tier of its node), "text", "fx": [passive effects]}. The passive effects are
## the engine's vocabulary (the `p` kinds at the top of rpg_battle.gd); the same
## vocabulary serves gear, runes, sets, relics, pets, boosts and foe traits.
##
## The id is made from the name (RpgDefs.id_of). A row without "text" gets one
## made from its effects (RpgBattle.passive_words).
##
## To add a passive: one more row in ROWS.

const ROWS = [
	# Push
	{"name": "Lockout Strength", "board": "push", "tier": 1, "fx": [{"p": "school_pct", "school": "push", "pct": 0.1}]},
	{"name": "Pressing Momentum", "board": "push", "tier": 3, "fx": [{"p": "next_cost", "school": "push", "add": -1}]},
	{"name": "Spotter", "board": "push", "tier": 4, "fx": [{"p": "low_hp", "below": 0.3, "do": {"k": "shield", "pct": 0.2}}]},
	# Pull
	{"name": "Grip and Rip", "board": "pull", "tier": 1, "fx": [{"p": "school_pct", "school": "pull", "pct": 0.1}]},
	{"name": "Hook Grip", "board": "pull", "tier": 3, "fx": [{"p": "on", "ev": "weak", "do": {"k": "energy", "n": 1}}]},
	{"name": "Lats of Steel", "board": "pull", "tier": 4, "fx": [{"p": "def_pct", "pct": 0.12}]},
	# Legs
	{"name": "Leg Drive", "board": "legs", "tier": 1, "fx": [{"p": "school_pct", "school": "legs", "pct": 0.1}]},
	{"name": "Never Skip", "board": "legs", "tier": 3, "fx": [{"p": "guard_en", "n": 1}, {"p": "guard_pct", "v": 0.1}]},
	{"name": "Tree Trunks", "board": "legs", "tier": 4, "fx": [{"p": "hp_pct", "pct": 0.12}]},
	# Speed
	{"name": "Light Feet", "board": "speed", "tier": 1, "fx": [{"p": "spd_pct", "pct": 0.08}]},
	{"name": "Negative Splits", "board": "speed", "tier": 3, "fx": [{"p": "ramp", "pct": 0.02, "max": 0.2}]},
	{"name": "Off the Line", "board": "speed", "tier": 4, "fx": [{"p": "first_turn"}, {"p": "start_status", "id": "hasted", "turns": 1}]},
	# Grip
	{"name": "Chalk Hands", "board": "grip", "tier": 1, "fx": [{"p": "crit_add", "v": 0.08}]},
	{"name": "Onsight", "board": "grip", "tier": 3, "fx": [{"p": "first_hit", "pct": 0.3}]},
	{"name": "Precision", "board": "grip", "tier": 4, "fx": [{"p": "chip", "on": "crit", "add": 1}]},
	# Mind
	{"name": "Marginalia", "board": "mind", "tier": 1, "fx": [{"p": "status_turns", "on": "debuff", "add": 1}]},
	{"name": "Thinker's Calm", "board": "mind", "tier": 3, "fx": [{"p": "on", "ev": "turn", "every": 3, "do": {"k": "energy", "n": 1}}]},
	{"name": "Well Read", "board": "mind", "tier": 4, "fx": [{"p": "start_status", "id": "insight", "turns": 0}]},
	# Flow
	{"name": "Supple", "board": "flow", "tier": 1, "fx": [{"p": "dodge_add", "v": 0.08}]},
	{"name": "Good Recovery", "board": "flow", "tier": 3, "fx": [{"p": "on", "ev": "turn", "do": {"k": "heal", "pct": 0.03}}]},
	{"name": "Mobility Work", "board": "flow", "tier": 4, "fx": [{"p": "status_turns", "on": "self_debuff", "add": -1}]},
	# Grit
	{"name": "Stubborn", "board": "grit", "tier": 1, "fx": [{"p": "res_add", "v": 15}, {"p": "on", "ev": "guard", "do": {"k": "heal", "pct": 0.03}}]},
	{"name": "Streak Fire", "board": "grit", "tier": 3, "fx": [{"p": "gauge_rate", "pct": 0.25}]},
	{"name": "Last Stand", "board": "grit", "tier": 4, "fx": [{"p": "survive", "pct": 0.0}]},
]

static var _all = null
static var _by_id = null


## What a list of passive effects does, in words (one sentence per effect).
static func words(fx: Array) -> String:
	var parts = []
	for e in fx:
		var w = RpgBattle.passive_words(e)
		if w != "":
			parts.append(w)
	return ". ".join(parts) + ("." if not parts.is_empty() else "")


## Every passive, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			var p = row.duplicate(true)
			p["id"] = RpgDefs.id_of(str(row.name))
			if str(p.get("text", "")) == "":
				p["text"] = words(p.fx)
			list.append(p)
		_all = list
	return _all


## A passive by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for p in all():
			map[p.id] = p
		_by_id = map
	return _by_id.get(id)
