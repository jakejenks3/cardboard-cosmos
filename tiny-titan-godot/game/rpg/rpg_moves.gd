class_name RpgMoves
extends RefCounted
## The hero's moves (RPG_PLAN.md 5). Pure data: a const table and its readers.
##
## A move, as `all()` / `by_id()` give it (every key always there):
##   {"id", "name", "school": "push"|"pull"|"legs"|"speed"|"grip"|"mind"|"flow"|"grit"|"plain",
##    "kind": "attack"|"support",
##    "scale": {stat id: weight},      the weights sum to 1; two stats: 0.6 / 0.4 in the order written
##    "power": float,                  the power of ALL its hits together (each hit does power / hits)
##    "hits": int, "target": "foe"|"all"|"random"|"self", "splash": float (0 = none),
##    "cost": int (energy), "cd": int (hero turns of rest), "rank": float (0.5 quick .. 1.6 heavy),
##    "chip": int (guard pips a weak hit takes; 1, breakers 2 or 3),
##    "mods": [mod], "fx": [effect],   the vocabulary is at the top of rpg_battle.gd
##    "tags": [String], "text": String, "ult": bool, "tier": int (0 starter, 1..5 board, 9 scroll)}
##
## The table below writes only what differs from the defaults (`DEFAULTS`); the
## id is made from the name (RpgDefs.id_of) and a row without "text" gets one
## made from its mods and effects (RpgBattle.mod_words / fx_words), so the
## words on screen can never say something the move does not do.
##
## Power comes from the budget (RpgDefs.move_budget) minus what else the move
## does; the content test checks it. A move that is not a starter rests (cd 1+).
## An ultimate costs no energy (it uses the whole gauge) and has rank
## RpgDefs.ULT_RANK.
##
## To add a move: one more row in ROWS. Nothing else needs to know.

## The eight moves every hero knows from the start (tier 0, no node).
const STARTERS = ["shove", "yank", "stomp", "dash_strike", "pinch", "burning_page", "deep_breath", "grind"]
## What a new build has equipped.
const FIRST_BUILD = ["shove", "yank", "stomp", "deep_breath"]

const DEFAULTS = {"kind": "attack", "scale": {}, "power": 0.0, "hits": 1, "target": "foe", "splash": 0.0,
	"cost": 0, "cd": 0, "rank": 1.0, "chip": 1, "mods": [], "fx": [], "tags": [], "text": "", "ult": false, "tier": 0}

const ROWS = [
	# --- Push: chest, shoulders, arms ------------------------------------------------------------
	{"name": "Shove", "school": "push", "scale": {"arms": 1.0}, "power": 1.15, "cost": 1,
		"fx": [{"k": "delay", "pct": 0.15}]},
	{"name": "One-Two", "school": "push", "tier": 1, "scale": {"arms": 1.0}, "power": 1.84, "hits": 2, "cost": 2, "cd": 1},
	{"name": "Bench Blast", "school": "push", "tier": 1, "scale": {"chest": 1.0}, "power": 1.6, "cost": 2, "cd": 1,
		"mods": [{"m": "vs_status", "id": "exposed", "pct": 0.3}]},
	{"name": "Lockout", "school": "push", "tier": 2, "scale": {"arms": 0.6, "chest": 0.4}, "power": 1.5, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.7}]},
	{"name": "Haymaker", "school": "push", "tier": 2, "scale": {"arms": 1.0}, "power": 2.5, "cost": 3, "cd": 2, "rank": 1.3},
	{"name": "Press Through", "school": "push", "tier": 2, "scale": {"shoulders": 1.0}, "power": 1.55, "cost": 2, "cd": 1,
		"mods": [{"m": "ignore_def", "pct": 0.5}]},
	{"name": "Bulldoze", "school": "push", "tier": 3, "scale": {"chest": 1.0}, "power": 1.38, "target": "all", "cost": 3, "cd": 2, "rank": 1.1},
	{"name": "Burnout Set", "school": "push", "tier": 3, "scale": {"arms": 1.0}, "power": 3.3, "hits": 4, "cost": 4, "cd": 3, "rank": 1.2,
		"fx": [{"k": "status", "id": "weakened", "turns": 1, "to": "self"}]},
	{"name": "Overhead Smash", "school": "push", "tier": 4, "scale": {"shoulders": 1.0}, "power": 2.9, "cost": 4, "cd": 3, "rank": 1.5, "chip": 2},
	{"name": "Titan Press", "school": "push", "tier": 5, "ult": true, "scale": {"chest": 0.6, "shoulders": 0.4}, "power": 4.2, "chip": 3,
		"fx": [{"k": "status", "id": "exposed", "turns": 2}]},

	# --- Pull: back, arms ------------------------------------------------------------------------
	{"name": "Yank", "school": "pull", "scale": {"back": 1.0}, "power": 1.05, "cost": 1,
		"fx": [{"k": "energy", "n": 1}]},
	{"name": "Row Rip", "school": "pull", "tier": 1, "scale": {"back": 1.0}, "power": 1.35, "cost": 2, "cd": 1,
		"fx": [{"k": "status", "id": "bleed", "turns": 3}]},
	{"name": "Arm Drag", "school": "pull", "tier": 1, "scale": {"arms": 1.0}, "power": 1.55, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.7}]},
	{"name": "Reel In", "school": "pull", "tier": 2, "scale": {"back": 1.0}, "power": 1.28, "cost": 2, "cd": 1, "rank": 0.7},
	{"name": "Chin Check", "school": "pull", "tier": 2, "scale": {"arms": 1.0}, "power": 1.55, "cost": 2, "cd": 1,
		"mods": [{"m": "crit", "add": 0.25}]},
	{"name": "Lat Spread", "school": "pull", "tier": 2, "kind": "support", "target": "self", "scale": {"back": 1.0}, "cost": 2, "cd": 3, "rank": 0.8,
		"fx": [{"k": "shield", "pct": 0.2}]},
	{"name": "Suplex", "school": "pull", "tier": 3, "scale": {"back": 1.0}, "power": 2.15, "cost": 3, "cd": 2, "rank": 1.2,
		"mods": [{"m": "vs_broken", "pct": 0.5}]},
	{"name": "Clinch", "school": "pull", "tier": 3, "scale": {"back": 1.0}, "power": 2.0, "cost": 3, "cd": 4,
		"fx": [{"k": "status", "id": "stun", "chance": 0.45}]},
	{"name": "Deadlift Slam", "school": "pull", "tier": 4, "scale": {"back": 0.6, "legs": 0.4}, "power": 2.9, "cost": 4, "cd": 3, "rank": 1.5, "chip": 2},
	{"name": "Mountain Mover", "school": "pull", "tier": 5, "ult": true, "scale": {"back": 1.0}, "power": 4.0, "splash": 0.4, "chip": 2},

	# --- Legs: legs, core ------------------------------------------------------------------------
	{"name": "Stomp", "school": "legs", "scale": {"legs": 1.0}, "power": 1.3, "cost": 1},
	{"name": "Lunge Strike", "school": "legs", "tier": 1, "scale": {"legs": 1.0}, "power": 1.44, "cost": 2, "cd": 1, "rank": 0.8},
	{"name": "Squat Launch", "school": "legs", "tier": 1, "scale": {"legs": 1.0}, "power": 1.5, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "pumped", "turns": 2, "to": "self"}]},
	{"name": "Knee Crush", "school": "legs", "tier": 2, "scale": {"legs": 1.0}, "power": 1.55, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.7}]},
	{"name": "Dropkick", "school": "legs", "tier": 2, "scale": {"legs": 1.0}, "power": 1.95, "cost": 3, "cd": 2, "rank": 1.1,
		"fx": [{"k": "delay", "pct": 0.4}]},
	{"name": "Calf Spring", "school": "legs", "tier": 2, "kind": "support", "target": "self", "scale": {"legs": 1.0}, "cost": 2, "cd": 4, "rank": 0.6,
		"fx": [{"k": "status", "id": "hasted", "turns": 3}]},
	{"name": "Earthshaker", "school": "legs", "tier": 3, "scale": {"legs": 0.6, "core": 0.4}, "power": 1.4, "target": "all", "cost": 4, "cd": 3, "rank": 1.2,
		"fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.5}]},
	{"name": "Root Stance", "school": "legs", "tier": 3, "kind": "support", "target": "self", "scale": {"legs": 1.0}, "cost": 2, "cd": 3, "rank": 0.7,
		"fx": [{"k": "status", "id": "braced", "turns": 2}, {"k": "status", "id": "counter", "turns": 2, "amount": 1.0}]},
	{"name": "Leg Day", "school": "legs", "tier": 4, "scale": {"legs": 1.0}, "power": 4.0, "cost": 5, "cd": 4, "rank": 1.6,
		"fx": [{"k": "status", "id": "slowed", "turns": 1, "to": "self"}]},
	{"name": "Quake Drop", "school": "legs", "tier": 5, "ult": true, "scale": {"legs": 1.0}, "power": 2.5, "target": "all",
		"fx": [{"k": "status", "id": "stun", "chance": 0.6}]},

	# --- Speed -----------------------------------------------------------------------------------
	{"name": "Dash Strike", "school": "speed", "scale": {"speed": 1.0}, "power": 0.78, "cost": 1, "rank": 0.6},
	{"name": "Flurry", "school": "speed", "tier": 1, "scale": {"speed": 1.0}, "power": 1.84, "hits": 3, "cost": 2, "cd": 1},
	{"name": "Tempo Run", "school": "speed", "tier": 1, "scale": {"speed": 1.0}, "power": 1.0, "cost": 1, "cd": 1, "rank": 0.9,
		"mods": [{"m": "ramp_use", "pct": 0.2, "max": 1.0}]},
	{"name": "Hit and Run", "school": "speed", "tier": 2, "scale": {"speed": 1.0}, "power": 1.55, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "evade", "stacks": 1, "to": "self"}]},
	{"name": "Slipstream", "school": "speed", "tier": 2, "scale": {"speed": 1.0}, "power": 0.9, "target": "all", "cost": 2, "cd": 2, "rank": 0.9,
		"fx": [{"k": "status", "id": "slowed", "turns": 1}]},
	{"name": "Second Wind", "school": "speed", "tier": 2, "kind": "support", "target": "self", "scale": {"speed": 1.0}, "cd": 4, "rank": 0.7,
		"fx": [{"k": "heal", "pct": 0.15}, {"k": "energy", "n": 2}]},
	{"name": "Sprint Start", "school": "speed", "tier": 3, "kind": "support", "target": "self", "scale": {"speed": 1.0}, "cost": 2, "cd": 4, "rank": 0.5,
		"fx": [{"k": "status", "id": "hasted", "turns": 3}, {"k": "gauge", "n": 10}]},
	{"name": "Negative Split", "school": "speed", "tier": 3, "scale": {"speed": 1.0}, "power": 1.3, "cost": 3, "cd": 2,
		"mods": [{"m": "ramp_turn", "pct": 0.15, "max": 1.5}]},
	{"name": "Lap", "school": "speed", "tier": 4, "scale": {"speed": 1.0}, "power": 1.4, "cost": 3, "cd": 3,
		"fx": [{"k": "extra_turn"}]},
	{"name": "Runner's High", "school": "speed", "tier": 5, "ult": true, "scale": {"speed": 1.0}, "power": 4.7, "hits": 6, "target": "random",
		"fx": [{"k": "status", "id": "hasted", "turns": 3, "to": "self"}]},

	# --- Grip ------------------------------------------------------------------------------------
	{"name": "Pinch", "school": "grip", "scale": {"grip": 1.0}, "power": 1.2, "cost": 1,
		"mods": [{"m": "crit", "add": 0.15}]},
	{"name": "Crimp Strike", "school": "grip", "tier": 1, "scale": {"grip": 1.0}, "power": 1.5, "cost": 2, "cd": 1,
		"mods": [{"m": "ignore_def", "pct": 0.6}]},
	{"name": "Chalk Up", "school": "grip", "tier": 1, "kind": "support", "target": "self", "scale": {"grip": 1.0}, "cost": 1, "cd": 3, "rank": 0.5,
		"fx": [{"k": "status", "id": "focus", "stacks": 1}, {"k": "energy", "n": 1}]},
	{"name": "Heel Hook", "school": "grip", "tier": 2, "scale": {"grip": 1.0}, "power": 1.5, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.75}]},
	{"name": "Flash", "school": "grip", "tier": 2, "scale": {"grip": 1.0}, "power": 1.7, "cost": 2, "cd": 2,
		"mods": [{"m": "vs_full_hp", "pct": 0.6}]},
	{"name": "Campus Rush", "school": "grip", "tier": 2, "scale": {"grip": 1.0}, "power": 2.2, "hits": 3, "cost": 3, "cd": 2,
		"mods": [{"m": "crit", "add": 0.1}]},
	{"name": "Dyno", "school": "grip", "tier": 3, "scale": {"grip": 1.0}, "power": 2.2, "cost": 3, "cd": 2, "rank": 1.2,
		"fx": [{"k": "refund", "n": 2}]},
	{"name": "Lock Off", "school": "grip", "tier": 3, "scale": {"grip": 1.0}, "power": 2.0, "cost": 3, "cd": 4,
		"fx": [{"k": "status", "id": "stun", "chance": 0.5}]},
	{"name": "Send It", "school": "grip", "tier": 4, "scale": {"grip": 1.0}, "power": 1.9, "cost": 3, "cd": 2, "rank": 1.1,
		"mods": [{"m": "execute", "below": 0.35, "pct": 1.0}]},
	{"name": "Free Solo", "school": "grip", "tier": 5, "ult": true, "scale": {"grip": 1.0}, "power": 3.0,
		"mods": [{"m": "sure_crit"}, {"m": "ignore_def", "pct": 1.0}]},

	# --- Mind ------------------------------------------------------------------------------------
	{"name": "Burning Page", "school": "mind", "scale": {"mind": 1.0}, "power": 0.9, "cost": 1,
		"fx": [{"k": "status", "id": "burn", "turns": 3, "chance": 0.8}]},
	{"name": "Read the Room", "school": "mind", "tier": 1, "kind": "support", "scale": {"mind": 1.0}, "cost": 1, "cd": 2, "rank": 0.5,
		"fx": [{"k": "status", "id": "insight", "turns": 4, "to": "self"}, {"k": "status", "id": "exposed", "turns": 1, "to": "target"}]},
	{"name": "Hex of Doubt", "school": "mind", "tier": 1, "scale": {"mind": 1.0}, "power": 1.45, "cost": 2, "cd": 2,
		"fx": [{"k": "status", "id": "weakened", "turns": 3, "chance": 0.85}]},
	{"name": "Footnote", "school": "mind", "tier": 2, "scale": {"mind": 1.0}, "power": 1.55, "cost": 2, "cd": 1,
		"mods": [{"m": "vs_debuff", "pct": 0.4}]},
	{"name": "Annotate", "school": "mind", "tier": 2, "kind": "support", "scale": {"mind": 1.0}, "cost": 2, "cd": 3, "rank": 0.6,
		"fx": [{"k": "status", "id": "marked", "to": "target"}]},
	{"name": "Speed Reading", "school": "mind", "tier": 2, "kind": "support", "target": "self", "scale": {"mind": 1.0}, "cost": 2, "cd": 4, "rank": 0.6,
		"fx": [{"k": "status", "id": "hasted", "turns": 2}, {"k": "cd_cut", "n": 1}]},
	{"name": "Plot Twist", "school": "mind", "tier": 3, "scale": {"mind": 1.0}, "power": 1.4, "cost": 3, "cd": 3, "rank": 0.9,
		"fx": [{"k": "interrupt"}, {"k": "delay", "pct": 0.6}]},
	{"name": "Chapter Close", "school": "mind", "tier": 3, "scale": {"mind": 1.0}, "power": 1.8, "cost": 3, "cd": 2,
		"mods": [{"m": "per_debuff", "pct": 0.25, "max": 1.0}]},
	{"name": "Thesis", "school": "mind", "tier": 4, "scale": {"mind": 1.0}, "power": 2.65, "cost": 4, "cd": 3, "rank": 1.3,
		"mods": [{"m": "smart"}]},
	{"name": "Final Chapter", "school": "mind", "tier": 5, "ult": true, "scale": {"mind": 1.0}, "power": 3.7,
		"fx": [{"k": "status", "id": "burn", "turns": 3}, {"k": "status", "id": "weakened", "turns": 3}, {"k": "status", "id": "exposed", "turns": 3}]},

	# --- Flow: the healing school (physical therapy and stretches) ---------------------------------
	{"name": "Deep Breath", "school": "flow", "kind": "support", "target": "self", "scale": {"flow": 1.0}, "cost": 2, "cd": 3, "rank": 0.7,
		"fx": [{"k": "heal", "pct": 0.2}, {"k": "cleanse", "n": 1}]},
	{"name": "Counterstretch", "school": "flow", "tier": 1, "kind": "support", "target": "self", "scale": {"flow": 1.0}, "cost": 1, "cd": 3, "rank": 0.6,
		"fx": [{"k": "status", "id": "braced", "turns": 3}]},
	{"name": "Foam Roll", "school": "flow", "tier": 2, "kind": "support", "target": "self", "scale": {"flow": 1.0}, "cd": 3, "rank": 0.5,
		"fx": [{"k": "cleanse", "n": 0}, {"k": "energy", "n": 2}]},
	{"name": "Balance", "school": "flow", "tier": 2, "scale": {"flow": 1.0}, "power": 1.4, "cost": 2, "cd": 1,
		"fx": [{"k": "lifesteal", "pct": 0.5}]},
	{"name": "Loosen Up", "school": "flow", "tier": 3, "kind": "support", "target": "self", "scale": {"flow": 1.0}, "cost": 2, "cd": 4, "rank": 0.7,
		"fx": [{"k": "status", "id": "regen", "turns": 3}, {"k": "cleanse", "n": 0}]},
	{"name": "Flow State", "school": "flow", "tier": 4, "kind": "support", "target": "self", "scale": {"flow": 1.0}, "cost": 3, "cd": 4, "rank": 0.6,
		"fx": [{"k": "status", "id": "evade", "stacks": 2}]},
	{"name": "Second Life", "school": "flow", "tier": 5, "ult": true, "kind": "support", "target": "self", "scale": {"flow": 1.0},
		"fx": [{"k": "heal", "pct": 0.6}, {"k": "cleanse", "n": 0}, {"k": "status", "id": "regen", "turns": 3}, {"k": "energy", "n": 4}]},

	# --- Grit: the school of showing up -----------------------------------------------------------
	{"name": "Grind", "school": "grit", "scale": {"grit": 1.0}, "power": 1.18, "cost": 1,
		"fx": [{"k": "gauge", "n": 12}]},
	{"name": "Rally", "school": "grit", "tier": 1, "kind": "support", "target": "self", "scale": {"grit": 1.0}, "cost": 2, "cd": 3, "rank": 0.6,
		"fx": [{"k": "status", "id": "pumped", "turns": 3}]},
	{"name": "No Days Off", "school": "grit", "tier": 2, "scale": {"grit": 1.0}, "power": 1.5, "cost": 2, "cd": 1,
		"mods": [{"m": "streak", "pct": 0.1, "max": 0.5}]},
	{"name": "Unbroken", "school": "grit", "tier": 2, "kind": "support", "target": "self", "scale": {"grit": 1.0}, "cost": 2, "cd": 3, "rank": 0.7,
		"fx": [{"k": "status", "id": "braced", "turns": 2}, {"k": "when", "hp_below": 0.4, "do": {"k": "heal", "pct": 0.15}}]},
	{"name": "Dig Deep", "school": "grit", "tier": 3, "kind": "support", "target": "self", "scale": {"grit": 1.0}, "cd": 3, "rank": 0.5,
		"fx": [{"k": "hp_cost", "pct": 0.2}, {"k": "energy", "n": 4}, {"k": "status", "id": "pumped", "turns": 1}]},
	{"name": "Iron Will", "school": "grit", "tier": 4, "kind": "support", "target": "self", "scale": {"grit": 1.0}, "cost": 2, "cd": 4, "rank": 0.7,
		"fx": [{"k": "shield", "pct": 0.25}, {"k": "status", "id": "steady", "turns": 3}]},
	{"name": "Titan Form", "school": "grit", "tier": 5, "ult": true, "kind": "support", "target": "self", "scale": {"grit": 1.0},
		"fx": [{"k": "status", "id": "pumped", "turns": 3}, {"k": "status", "id": "braced", "turns": 3}, {"k": "status", "id": "hasted", "turns": 3}, {"k": "energy", "n": 99}]},
]

static var _all = null
static var _by_id = null


## One table row with every key filled in.
static func _full(row: Dictionary) -> Dictionary:
	var m = DEFAULTS.duplicate(true)
	for k in row:
		m[k] = row[k] if not (row[k] is Dictionary or row[k] is Array) else row[k].duplicate(true)
	m["id"] = RpgDefs.id_of(str(row.get("name", "")))
	if bool(m.ult):
		m["rank"] = RpgDefs.ULT_RANK
		m["cost"] = 0
		m["cd"] = 0
	if str(m.text) == "":
		m["text"] = words(m)
	return m


## What a move does besides its damage, in words: its mods, then its effects.
static func words(move: Dictionary) -> String:
	var parts = []
	if str(move.get("target", "foe")) == "all":
		parts.append("Hits every foe")
	elif str(move.get("target", "foe")) == "random":
		parts.append("%d hits on random foes" % int(move.get("hits", 1)))
	elif int(move.get("hits", 1)) > 1:
		parts.append("%d hits" % int(move.get("hits", 1)))
	if float(move.get("splash", 0.0)) > 0.0:
		parts.append("%d%% splashes onto the other foes" % int(round(float(move.splash) * 100.0)))
	if int(move.get("chip", 1)) > 1 and str(move.get("kind", "attack")) == "attack":
		parts.append("Breaks %d guard on a weak foe" % int(move.chip))
	for mod in move.get("mods", []):
		var w = RpgBattle.mod_words(mod)
		if w != "":
			parts.append(w)
	var attack = str(move.get("kind", "attack")) == "attack"
	for e in move.get("fx", []):
		var w = RpgBattle.fx_words(e, attack)
		if w != "":
			parts.append(w)
	return ". ".join(parts) + ("." if not parts.is_empty() else "")


## Every move, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			list.append(_full(row))
		_all = list
	return _all


## A move by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for m in all():
			map[m.id] = m
		_by_id = map
	return _by_id.get(id)


## The moves of one school, in catalog order.
static func of_school(school: String) -> Array:
	return all().filter(func(m): return str(m.school) == school)


## The stat a move asks for on the skill board: the biggest weight in its
## scale, the first written on a tie (support moves: the board's own stat).
static func main_stat(move: Dictionary) -> String:
	if str(move.get("kind", "attack")) != "attack":
		return str(RpgDefs.BOARD_STAT.get(str(move.get("school", "")), ""))
	var best = ""
	var top = -1.0
	var scale = move.get("scale", {})
	for id in scale:
		if float(scale[id]) > top + 0.000001:
			top = float(scale[id])
			best = str(id)
	return best
