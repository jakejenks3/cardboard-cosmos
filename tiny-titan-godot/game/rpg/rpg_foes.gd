class_name RpgFoes
extends RefCounted
## Foes and what they do (RPG_PLAN.md 8.3). Pure data: two const tables (the
## foes and their moves), their readers, and `make`, which turns a foe of the
## table into a battle unit with the numbers SOLVED from the reference hero
## (RpgDefs.foe_hp, foe_atk, foe_def, foe_spd): no foe number is typed in.
##
## A foe, as `all()` / `by_id()` give it (every key always there):
##   {"id", "name", "region", "role" (a key of RpgDefs.ROLES),
##    "weak": [2 attack schools], "resist": [0 or 1 attack school],
##    "guard": int or null (null = the role's pips),
##    "moves": [foe move ids] (every move it can use: pattern, rules and phases),
##    "pattern": [foe move ids] (done in this order, round and round),
##    "rules": [{"if": "hp_below"|"ally_hurt"|"turn_mod"|"alone"|"hero_has"|"self_lacks", "v", "use": move id, "once": bool}],
##        looked at before the pattern, in order; the first that holds is used:
##        hp_below v = a share of its HP · ally_hurt v = a share: some foe of its side is under it ·
##        turn_mod v = N (every Nth of its turns) or [N, r] · alone: no other foe lives ·
##        hero_has v = a status id · self_lacks v = a status id
##    "traits": [passive effects] (the vocabulary of rpg_battle.gd; `adapt` and `quicken` are for foes),
##    "phases": [{"at": hp share, "say", "pattern", "weak", "resist", "summon": [foe ids], "fx": [effects on itself]}],
##        entered once its HP is at or under `at` (in order); what a phase leaves out stays as it was
##    "boss": bool, "elite": bool, "text"}
##
## A foe move (`move(id)`):
##   {"id", "name", "kind": "attack"|"multi"|"heavy"|"debuff"|"buff"|"heal"|"shield"|"summon"|"drain"|"bomb",
##    "power": float (ALL its hits together, in units of the foe's attack; 0 = no damage),
##    "hits": int, "windup": 0|1 (1: it spends one turn charging first, and says so),
##    "count": int (a bomb: the number of its turns until it goes off),
##    "rank": float, "target": "hero"|"self"|"ally"|"allies",
##    "fx": [effects] (after the damage, in order; an effect lands on the move's target unless it says "to"),
##    "foes": [foe ids a summon brings], "icon": an intent icon ("" = the kind's), "text"}
##   The kind is what the intent shows; what the move DOES is its power, fx and foes.
##
## To add a foe: a row in ROWS and its moves in MOVES. RpgBattle.check_foe says
## whether a row is well formed.

const MOVE_DEFAULTS = {"kind": "attack", "power": 0.0, "hits": 1, "windup": 0, "count": 0, "rank": 1.0,
	"target": "hero", "fx": [], "foes": [], "icon": "", "text": ""}
const FOE_DEFAULTS = {"region": "", "role": "brute", "weak": [], "resist": [], "guard": null, "moves": [], "pattern": [],
	"rules": [], "traits": [], "phases": [], "boss": false, "elite": false, "text": ""}
## The icon an intent shows for each kind of move.
const KIND_ICONS = {"attack": "in_attack", "multi": "in_multi", "heavy": "in_heavy", "debuff": "in_debuff", "buff": "in_buff",
	"heal": "in_heal", "shield": "in_shield", "summon": "in_summon", "drain": "in_drain", "bomb": "in_bomb"}

const MOVES = {
	# --- The Rustyard ----------------------------------------------------------------------------
	"nibble": {"name": "Nibble", "power": 0.95},
	"pounce": {"name": "Pounce", "power": 1.15},
	"scratch": {"name": "Scratch", "power": 0.9},
	"gnaw": {"name": "Gnaw", "kind": "multi", "power": 1.2, "hits": 2},
	"clank": {"name": "Clank", "power": 1.1},
	"plate_slam": {"name": "Plate Slam", "power": 1.5, "rank": 1.2},
	"plate_up": {"name": "Plate Up", "kind": "shield", "target": "self", "fx": [{"k": "shield", "pct": 0.12}]},
	"collar_snap": {"name": "Collar Snap", "power": 1.0},
	"loosen": {"name": "Loosen", "kind": "debuff", "power": 0.7, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.75}]},
	"damp_slap": {"name": "Damp Slap", "power": 0.9},
	"wring_out": {"name": "Wring Out", "kind": "heal", "target": "ally", "fx": [{"k": "heal", "pct": 0.18}]},
	"bar_swing": {"name": "Bar Swing", "power": 1.0},
	"double_swing": {"name": "Double Swing", "kind": "multi", "power": 1.3, "hits": 2},
	"big_bend": {"name": "Big Bend", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2},
	"brace_up": {"name": "Brace Up", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "braced", "turns": 2}]},
	"locker_bite": {"name": "Locker Bite", "power": 1.0},
	"chomp_chomp": {"name": "Chomp Chomp", "kind": "multi", "power": 1.4, "hits": 2},
	"rust_cloud": {"name": "Rust Cloud", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.8}]},
	"door_slam": {"name": "Door Slam", "kind": "heavy", "power": 1.9, "windup": 1, "rank": 1.2},
	"spit_laundry": {"name": "Spit Laundry", "kind": "summon", "target": "self", "foes": ["dust_bunny"]},
	# --- wind-ups (the Ironworks) ----------------------------------------------------------------
	"hot_press": {"name": "Hot Press", "power": 1.0},
	"meltdown": {"name": "Meltdown", "kind": "heavy", "power": 2.2, "windup": 1, "rank": 1.2},
	# --- a countdown (the Greenmile) -------------------------------------------------------------
	"countdown": {"name": "Countdown", "kind": "bomb", "power": 2.4, "count": 3, "fx": [{"k": "self_ko"}]},
	# --- a foe that adapts (Mirror Marsh) --------------------------------------------------------
	"shade_slash": {"name": "Shade Slash", "power": 1.0},
	"mirror_grasp": {"name": "Mirror Grasp", "kind": "debuff", "power": 1.1, "fx": [{"k": "status", "id": "bleed", "turns": 2, "chance": 0.6}]},
	# --- The Pacer (the Greenmile's boss) --------------------------------------------------------
	"stride": {"name": "Stride", "power": 0.9, "rank": 0.9},
	"lap_kick": {"name": "Lap Kick", "kind": "multi", "power": 1.3, "hits": 3},
	"surge": {"name": "Surge", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "hasted", "turns": 2}]},
	"finishing_kick": {"name": "Finishing Kick", "kind": "heavy", "power": 1.8, "windup": 1, "rank": 1.2},
}

const ROWS = [
	# --- The Rustyard: weaknesses and the guard break (leans on push and legs) --------------------
	{"id": "dust_bunny", "name": "Dust Bunny", "region": "rustyard", "role": "swarm", "weak": ["push", "legs"],
		"moves": ["nibble", "pounce"], "pattern": ["nibble", "nibble", "pounce"],
		"text": "It lives under the squat rack and it is not afraid of you."},
	{"id": "rust_rat", "name": "Rust Rat", "region": "rustyard", "role": "skirmisher", "weak": ["legs", "speed"],
		"moves": ["scratch", "gnaw"], "pattern": ["scratch", "gnaw"],
		"text": "Quick, bitey, fond of old iron."},
	{"id": "squeaky_plate", "name": "Squeaky Plate", "region": "rustyard", "role": "tank", "weak": ["push", "grip"], "resist": ["speed"],
		"moves": ["clank", "plate_slam", "plate_up"], "pattern": ["clank", "plate_slam", "plate_up"],
		"text": "A forty-five that nobody racked. It has opinions about that."},
	{"id": "loose_collar", "name": "Loose Collar", "region": "rustyard", "role": "caster", "weak": ["pull", "mind"],
		"moves": ["collar_snap", "loosen"], "pattern": ["collar_snap", "loosen", "collar_snap"],
		"text": "It slips. It always slips."},
	{"id": "moldy_towel", "name": "Moldy Towel", "region": "rustyard", "role": "healer", "weak": ["mind", "legs"], "resist": ["grip"],
		"moves": ["damp_slap", "wring_out"], "pattern": ["damp_slap", "wring_out"],
		"text": "Left in a locker since spring. It mops up its friends."},
	{"id": "bent_bar", "name": "Bent Bar", "region": "rustyard", "role": "elite", "elite": true, "weak": ["push", "legs"], "resist": ["pull"],
		"moves": ["bar_swing", "double_swing", "big_bend", "brace_up"], "pattern": ["bar_swing", "double_swing", "bar_swing", "big_bend"],
		"rules": [{"if": "hp_below", "v": 0.5, "use": "brace_up", "once": true}],
		"text": "Somebody dropped it once. It never forgave anyone."},
	{"id": "old_iron_jaw", "name": "Old Iron-Jaw", "region": "rustyard", "role": "boss", "boss": true, "weak": ["push", "legs"], "resist": ["mind"],
		"moves": ["locker_bite", "rust_cloud", "door_slam", "chomp_chomp", "spit_laundry"],
		"pattern": ["locker_bite", "rust_cloud", "locker_bite", "door_slam"],
		"rules": [{"if": "alone", "v": 0, "use": "spit_laundry", "once": true}],
		"phases": [{"at": 0.5, "say": "The door bursts off its hinges!", "pattern": ["chomp_chomp", "locker_bite", "door_slam", "rust_cloud"],
			"weak": ["pull", "grip"], "resist": [], "summon": ["dust_bunny"], "fx": [{"k": "status", "id": "pumped", "turns": 3}]}],
		"text": "A locker that bites. Nobody remembers the combination."},

	# --- one foe each for a rule the later regions lean on ----------------------------------------
	{"id": "molten_barbell", "name": "Molten Barbell", "region": "ironworks", "role": "brute", "weak": ["legs", "push"], "resist": ["mind"],
		"moves": ["hot_press", "meltdown"], "pattern": ["hot_press", "meltdown", "hot_press"],
		"text": "It glows before it swings. Guard, or get out of the way."},
	{"id": "mile_marker", "name": "Mile Marker", "region": "greenmile", "role": "bomb", "weak": ["speed", "pull"],
		"moves": ["countdown"], "pattern": ["countdown"],
		"text": "It counts down. Be done before it is."},
	{"id": "mirror_shade", "name": "Mirror Shade", "region": "marsh", "role": "brute", "weak": ["mind", "grip"],
		"moves": ["shade_slash", "mirror_grasp"], "pattern": ["shade_slash", "shade_slash", "mirror_grasp"],
		"traits": [{"p": "adapt"}],
		"text": "It learns whatever hit it last. Never the same school twice."},
	{"id": "the_pacer", "name": "The Pacer", "region": "greenmile", "role": "boss", "boss": true, "weak": ["speed", "pull"], "resist": ["legs"],
		"moves": ["stride", "lap_kick", "surge", "finishing_kick"], "pattern": ["stride", "lap_kick", "stride", "finishing_kick"],
		"traits": [{"p": "quicken", "pct": 0.06, "max": 0.6}],
		"phases": [{"at": 0.5, "say": "The Pacer finds another gear.", "pattern": ["lap_kick", "stride", "finishing_kick"],
			"weak": ["pull", "mind"], "resist": ["speed"], "summon": [], "fx": [{"k": "status", "id": "hasted", "turns": 2}]}],
		"text": "Faster every turn. End it early or do not end it."},
]

static var _all = null
static var _by_id = null
static var _moves = null


## Every foe, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			list.append(full(row))
		_all = list
	return _all


## A foe by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for f in all():
			map[f.id] = f
		_by_id = map
	return _by_id.get(id)


## A foe row with every key filled in (a copy).
static func full(row: Dictionary) -> Dictionary:
	var f = FOE_DEFAULTS.duplicate(true)
	for k in row:
		f[k] = row[k] if not (row[k] is Dictionary or row[k] is Array) else row[k].duplicate(true)
	f["id"] = str(row.get("id", RpgDefs.id_of(str(row.get("name", "")))))
	return f


## A foe move row with every key filled in (a copy); `id` is put in.
static func full_move(id: String, row: Dictionary) -> Dictionary:
	var m = MOVE_DEFAULTS.duplicate(true)
	for k in row:
		m[k] = row[k] if not (row[k] is Dictionary or row[k] is Array) else row[k].duplicate(true)
	m["id"] = id
	if str(m.icon) == "":
		m["icon"] = str(KIND_ICONS.get(str(m.kind), "in_attack"))
	return m


## A foe move by id, or null.
static func move(id: String) -> Variant:
	if _moves == null:
		var map = {}
		for k in MOVES:
			map[k] = full_move(k, MOVES[k])
		_moves = map
	return _moves.get(id)


## Every foe move (do not change what it returns).
static func moves() -> Array:
	move("")
	return _moves.values()


## The battle unit of a catalog foe at difficulty index `n` (RPG_PLAN.md 4.1),
## or null for an id nobody knows. `pack_size` = how many regular foes share
## the wave (each has 2 / (c + 1) of the hp and attack). `opts`:
##   "mult": float   the hp and attack share to use instead of the pack's (an elite's or boss's adds: RpgDefs.ADD_MULT)
##   "weak", "resist": [schools]   set by the setup (the hunt, the rival, an echo): shown from the start, never learned
##   "guard_add": int   more guard pips
static func make(id: String, n: float, pack_size: int = 1, opts: Dictionary = {}) -> Variant:
	var row = by_id(id)
	if row == null:
		return null
	return make_from(row, n, pack_size, opts)


## `make` for a foe row that is not in the table (the weekly rival, a test).
static func make_from(row_in: Dictionary, n: float, pack_size: int = 1, opts: Dictionary = {}) -> Dictionary:
	var row = full(row_in)
	var role = RpgDefs.role(str(row.role))
	var big = bool(row.boss) or bool(row.elite)
	var mult = 1.0
	if opts.has("mult"):
		mult = float(opts.mult)
	elif not big:
		mult = RpgDefs.pack_mult(pack_size)
	var agg = RpgBattle.aggregate(row.traits)
	var hp_max = (RpgDefs.foe_hp(n) * float(role[0]) * mult + float(agg.get("hp", 0.0))) * (1.0 + float(agg.get("hp_pct", 0.0)))
	var def = (RpgDefs.foe_def(n) * float(role[4]) + float(agg.get("armor", 0.0))) * (1.0 + float(agg.get("def_pct", 0.0)))
	var tec = RpgDefs.foe_tec(n, bool(row.elite), bool(row.boss))
	var guard = int(role[3]) if row.guard == null else int(row.guard)
	guard = maxi(0, guard + int(opts.get("guard_add", 0)))
	var set_weak = opts.get("weak") is Array and not opts.weak.is_empty()
	var weak = (opts.weak if set_weak else row.weak).duplicate()
	var resist = (opts.resist if opts.get("resist") is Array else row.resist).duplicate()
	if set_weak and not (opts.get("resist") is Array):
		resist = resist.filter(func(sc): return not weak.has(sc))
	return {
		"id": "", "side": "foe", "name": str(row.name), "foe": str(row.id), "role": str(row.role), "n": n,
		"hp": maxi(1, int(round(hp_max))), "hp_max": maxi(1, int(round(hp_max))),
		"atk": RpgDefs.foe_atk(n) * float(role[1]) * mult,
		"def": def,
		"spd": RpgDefs.foe_spd(str(row.role), n) * (1.0 + float(agg.get("spd_pct", 0.0))),
		"res": tec + float(agg.get("res_add", 0.0)), "tec": tec,
		"crit": 0.0 if bool(row.boss) else clampf(RpgDefs.FOE_CRIT + float(agg.get("crit_add", 0.0)), 0.0, 1.0),
		"dodge": clampf(float(agg.get("dodge_add", 0.0)), 0.0, 0.9),
		"at": 0.0, "alive": true, "statuses": [], "stun_guard": 0, "turns": 0,
		"weak": weak, "resist": resist, "shown": set_weak,
		"guard": guard, "guard_max": guard, "broken": false,
		"intent": {}, "pi": 0, "boss": bool(row.boss), "elite": bool(row.elite), "phase": 0, "slot": 0,
		"moves": row.moves.duplicate(), "pattern": row.pattern.duplicate(), "rules": row.rules.duplicate(true),
		"phases": row.phases.duplicate(true), "fx": row.traits.duplicate(true), "flags": {},
	}
