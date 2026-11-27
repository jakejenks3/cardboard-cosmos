extends SceneTree
## Unit test for the Realm's battle engine (RPG_PLAN.md 4, 5, 6, 8.3, 11.3,
## 11.4): game/rpg/rpg_battle.gd (RpgBattle), rpg_ai.gd (RpgAi), rpg_hero.gd
## (RpgHero) and the first catalogs they stand on. Every rule of the plan's
## combat section has a check, every mod / effect / passive kind is used and
## seen to do what it says, the validators turn down a malformed row of each
## kind, a fight replays the same from its seed and through a JSON round trip
## after every action, fifty fights at random end without breaking a bound, and
## the reference hero takes about RpgDefs.TTK turns for a lone plain foe.
## Made-up heroes and foes only; nothing here reads a save.
##   godot --headless --path . --script res://tests/rpg_battle_test.gd
## Prints RPG BATTLE: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0

## The gear attack the test hero has for every school: big, so that a hit is a
## few hundred points and a "+25%" can be read off it to within a percent.
const W = 380.0
const ALL_W = {"push": W, "pull": W, "legs": W, "speed": W, "grip": W, "mind": W, "flow": W, "grit": W}


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a: float, b: float, tol: float = 0.012) -> bool:
	return absf(a - b) <= tol * maxf(1.0, absf(b))


# --- made-up rows ------------------------------------------------------------

## A test move: push, scaled by the chest, power 1, free, no rest.
func mv(over: Dictionary = {}) -> Dictionary:
	var m = {"school": "push", "scale": {"chest": 1.0}, "power": 1.0}
	for k in over:
		m[k] = over[k]
	return m


func sup(fx: Array, over: Dictionary = {}) -> Dictionary:
	var m = {"school": "flow", "kind": "support", "target": "self", "scale": {"flow": 1.0}, "power": 0.0, "fx": fx}
	for k in over:
		m[k] = over[k]
	return m


func custom() -> Dictionary:
	var pull = {"school": "pull", "scale": {"back": 1.0}}
	var moves = {
		"t_push": mv(), "t_pull": mv(pull), "t_mind": mv({"school": "mind", "scale": {"mind": 1.0}}),
		"t_grit": mv({"school": "grit", "scale": {"grit": 1.0}}),
		"t_two": mv({"scale": {"arms": 0.6, "chest": 0.4}}),
		"t_multi": mv({"power": 3.0, "hits": 3}), "t_break": mv({"chip": 2}),
		"t_cost": mv({"cost": 2, "cd": 2, "rank": 1.2}),
		"t_all": mv({"target": "all"}), "t_random": mv({"power": 6.0, "hits": 6, "target": "random"}),
		"t_splash": mv({"power": 2.0, "splash": 0.5}),
		"t_big": mv({"power": 400.0}), "t_tiny": mv({"power": 0.001, "school": "pull", "scale": {"back": 1.0}}),
		"t_ult": mv({"power": 2.0, "ult": true, "rank": 1.6}),
		# one per mod (pull: neither weak nor resisted on the test foes)
		"m_vs_status": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "vs_status", "id": "slowed", "pct": 0.5}]}),
		"m_vs_debuff": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "vs_debuff", "pct": 0.4}]}),
		"m_per_debuff": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "per_debuff", "pct": 0.25, "max": 0.5}]}),
		"m_vs_broken": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "vs_broken", "pct": 0.5}]}),
		"m_vs_full_hp": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "vs_full_hp", "pct": 0.6}]}),
		"m_execute": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "execute", "below": 0.35, "pct": 1.0}]}),
		"m_ignore_def": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "ignore_def", "pct": 0.5}]}),
		"m_crit": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "crit", "add": 1.0}]}),
		"m_sure_crit": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "sure_crit"}]}),
		"m_ramp_use": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "ramp_use", "pct": 0.2, "max": 0.4}]}),
		"m_ramp_turn": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "ramp_turn", "pct": 0.15, "max": 0.3}]}),
		"m_streak": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "streak", "pct": 0.1, "max": 0.2}]}),
		"m_smart": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "smart"}]}),
		"m_smart_mind": mv({"school": "mind", "scale": {"mind": 1.0}, "mods": [{"m": "smart"}]}),
		"m_missing_hp": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "missing_hp", "pct": 0.5}]}),
		# one per effect
		"k_slow": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "status", "id": "slowed", "turns": 2}]}),
		"k_slow_half": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.5}]}),
		"k_weak_self": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "status", "id": "weakened", "turns": 1, "to": "self"}]}),
		"k_expose_all": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "status", "id": "exposed", "turns": 2, "to": "all_foes"}]}),
		"k_burn": mv({"school": "pull", "scale": {"back": 1.0}, "power": 0.001, "fx": [{"k": "status", "id": "burn", "turns": 3}]}),
		"k_bleed": mv({"school": "pull", "scale": {"back": 1.0}, "power": 0.001, "fx": [{"k": "status", "id": "bleed", "turns": 3}]}),
		"k_stun": mv({"school": "pull", "scale": {"back": 1.0}, "power": 0.001, "fx": [{"k": "status", "id": "stun", "chance": 1.0}]}),
		"k_mark": sup([{"k": "status", "id": "marked", "to": "target"}], {"target": "foe"}),
		"k_pump": sup([{"k": "status", "id": "pumped", "turns": 2}]),
		"k_haste": sup([{"k": "status", "id": "hasted", "turns": 3}]),
		"k_focus": sup([{"k": "status", "id": "focus", "stacks": 2}]),
		"k_counter": sup([{"k": "status", "id": "counter", "turns": 3, "amount": 1.0}]),
		"k_heal": sup([{"k": "heal", "pct": 0.2}]),
		"k_shield": sup([{"k": "shield", "pct": 0.2}]),
		"k_shield_small": sup([{"k": "shield", "pct": 0.1}]),
		"k_energy": sup([{"k": "energy", "n": 2}]),
		"k_energy_full": sup([{"k": "energy", "n": 99}]),
		"k_gauge": sup([{"k": "gauge", "n": 30}]),
		"k_delay": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "delay", "pct": 0.5}]}),
		"k_cleanse_1": sup([{"k": "cleanse", "n": 1}]),
		"k_cleanse_all": sup([{"k": "cleanse", "n": 0}]),
		"k_cleanse_ids": sup([{"k": "cleanse", "ids": ["burn"]}]),
		"k_dispel": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "dispel", "n": 1}]}),
		"k_dispel_all": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "dispel", "n": 0}]}),
		"k_interrupt": mv({"school": "pull", "scale": {"back": 1.0}, "power": 0.001, "fx": [{"k": "interrupt"}]}),
		"k_cd_cut": sup([{"k": "cd_cut", "n": 1}], {"cd": 3}),
		"k_hp_cost": sup([{"k": "hp_cost", "pct": 0.2}, {"k": "energy", "n": 1}]),
		"k_lifesteal": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "lifesteal", "pct": 0.5}]}),
		"k_refund": mv({"school": "pull", "scale": {"back": 1.0}, "cost": 2, "fx": [{"k": "refund", "n": 2}]}),
		"k_extra": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "extra_turn"}]}),
		"k_chip": mv({"school": "pull", "scale": {"back": 1.0}, "fx": [{"k": "chip", "n": 1}]}),
		"k_when": sup([{"k": "when", "hp_below": 0.4, "do": {"k": "heal", "pct": 0.1}}]),
		"m_two": mv({"school": "pull", "scale": {"back": 1.0}, "mods": [{"m": "vs_debuff", "pct": 0.4}, {"m": "vs_full_hp", "pct": 0.6}]}),
		"t_flow": mv({"school": "flow", "scale": {"flow": 1.0}}),
		"t_legs": mv({"school": "legs", "scale": {"legs": 1.0}}),
		"k_evade": sup([{"k": "status", "id": "evade", "stacks": 2}]),
		"k_insight": sup([{"k": "status", "id": "insight", "turns": 2}]),
		"k_steady_foe": sup([{"k": "status", "id": "steady", "turns": 3, "to": "target"}], {"target": "foe"}),
	}
	var foe_moves = {
		"poke": {"name": "Poke", "power": 0.001},
		"smack": {"name": "Smack", "power": 1.0},
		"slap": {"name": "Slap", "power": 0.5},
		"twice": {"name": "Twice", "kind": "multi", "power": 1.0, "hits": 2},
		"wind": {"name": "Wind Up", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2},
		"boom": {"name": "Boom", "kind": "bomb", "power": 2.0, "count": 3, "fx": [{"k": "self_ko"}]},
		"nuke": {"name": "Nuke", "kind": "bomb", "power": 900.0, "count": 1, "fx": [{"k": "self_ko"}]},
		"call": {"name": "Call", "kind": "summon", "target": "self", "foes": ["dummy"]},
		"mend": {"name": "Mend", "kind": "heal", "target": "ally", "fx": [{"k": "heal", "pct": 0.2}]},
		"cheer": {"name": "Cheer", "kind": "buff", "target": "allies", "fx": [{"k": "status", "id": "pumped", "turns": 2}]},
		"armor_up": {"name": "Armor Up", "kind": "shield", "target": "self", "fx": [{"k": "shield", "pct": 0.1}]},
		"sap": {"name": "Sap", "kind": "debuff", "power": 0.001, "fx": [{"k": "status", "id": "weakened", "turns": 2}]},
		"daze": {"name": "Daze", "kind": "debuff", "power": 0.001, "fx": [{"k": "status", "id": "stun", "chance": 1.0}]},
		"scorch": {"name": "Scorch", "kind": "debuff", "power": 0.001, "fx": [{"k": "status", "id": "burn", "turns": 3}]},
		"cut": {"name": "Cut", "kind": "debuff", "power": 0.001, "fx": [{"k": "status", "id": "bleed", "turns": 3}]},
		"leech": {"name": "Leech", "kind": "drain", "power": 1.0, "fx": [{"k": "lifesteal", "pct": 1.0}, {"k": "energy", "n": -2}]},
		"rage": {"name": "Rage", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "pumped", "turns": 3}]},
		"kill": {"name": "Kill", "power": 900.0},
		"stall": {"name": "Stall", "power": 0.001, "rank": 0.0},
		"hex": {"name": "Hex", "kind": "debuff", "fx": [{"k": "status", "id": "exposed", "turns": 2}]},
		"cure": {"name": "Cure", "kind": "buff", "target": "allies", "fx": [{"k": "cleanse", "n": 0}]},
		"shove_back": {"name": "Shove Back", "power": 0.001, "fx": [{"k": "delay", "pct": 0.5}]},
		"big_hit": {"name": "Big Hit", "power": 8.0},
	}
	var foes = {
		"dummy": {"name": "Dummy", "role": "brute", "weak": ["push", "legs"], "resist": ["mind"], "moves": ["poke"], "pattern": ["poke"]},
		"plain": {"name": "Plain", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"]},
		"hitter": {"name": "Hitter", "role": "brute", "weak": ["speed", "grip"], "moves": ["smack"], "pattern": ["smack"]},
		"twicer": {"name": "Twicer", "role": "brute", "weak": ["speed", "grip"], "moves": ["twice"], "pattern": ["twice"]},
		"charger": {"name": "Charger", "role": "brute", "weak": ["push", "legs"], "moves": ["wind"], "pattern": ["wind"]},
		"bomber": {"name": "Bomber", "role": "bomb", "weak": ["speed", "grip"], "moves": ["boom"], "pattern": ["boom"]},
		"nuker": {"name": "Nuker", "role": "bomb", "weak": ["speed", "grip"], "moves": ["nuke"], "pattern": ["nuke"]},
		"killer": {"name": "Killer", "role": "brute", "weak": ["speed", "grip"], "moves": ["kill"], "pattern": ["kill"]},
		"caller": {"name": "Caller", "role": "caster", "weak": ["speed", "grip"], "moves": ["call", "poke"], "pattern": ["call", "poke"]},
		"medic": {"name": "Medic", "role": "healer", "weak": ["speed", "grip"], "moves": ["mend", "poke"], "pattern": ["mend", "poke"]},
		"cheerer": {"name": "Cheerer", "role": "caster", "weak": ["speed", "grip"], "moves": ["cheer"], "pattern": ["cheer"]},
		"shieldy": {"name": "Shieldy", "role": "tank", "weak": ["speed", "grip"], "moves": ["armor_up"], "pattern": ["armor_up"]},
		"sapper": {"name": "Sapper", "role": "caster", "weak": ["speed", "grip"], "moves": ["sap"], "pattern": ["sap"]},
		"dazer": {"name": "Dazer", "role": "caster", "weak": ["speed", "grip"], "moves": ["daze"], "pattern": ["daze"]},
		"scorcher": {"name": "Scorcher", "role": "caster", "weak": ["speed", "grip"], "moves": ["scorch"], "pattern": ["scorch"]},
		"cutter": {"name": "Cutter", "role": "caster", "weak": ["speed", "grip"], "moves": ["cut"], "pattern": ["cut"]},
		"leecher": {"name": "Leecher", "role": "skirmisher", "weak": ["speed", "grip"], "moves": ["leech"], "pattern": ["leech"]},
		"adapter": {"name": "Adapter", "role": "brute", "weak": ["push", "legs"], "moves": ["poke"], "pattern": ["poke"], "traits": [{"p": "adapt"}]},
		"quick": {"name": "Quick", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"],
			"traits": [{"p": "quicken", "pct": 0.2, "max": 0.4}]},
		"ruler": {"name": "Ruler", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke", "smack", "slap", "rage", "call", "mend"],
			"pattern": ["poke", "slap"], "rules": []},
		"big": {"name": "Big", "role": "boss", "boss": true, "weak": ["push", "legs"], "resist": ["mind"], "moves": ["poke", "slap"], "pattern": ["poke"],
			"phases": [{"at": 0.5, "say": "Phase two!", "pattern": ["slap"], "weak": ["pull", "grip"], "resist": [], "summon": ["dummy"],
				"fx": [{"k": "status", "id": "pumped", "turns": 3}]}]},
		"captain": {"name": "Captain", "role": "elite", "elite": true, "weak": ["push", "legs"], "moves": ["poke"], "pattern": ["poke"]},
		"noguard": {"name": "No Guard", "role": "brute", "weak": ["push", "legs"], "guard": 0, "moves": ["poke"], "pattern": ["poke"]},
		"ramper": {"name": "Ramper", "role": "brute", "weak": ["speed", "grip"], "moves": ["smack"], "pattern": ["smack"],
			"traits": [{"p": "ramp", "pct": 0.5, "max": 2.0}]},
		"onlymend": {"name": "Only Mend", "role": "healer", "weak": ["speed", "grip"], "moves": ["mend"], "pattern": ["mend"]},
		"staller": {"name": "Staller", "role": "brute", "weak": ["speed", "grip"], "moves": ["stall"], "pattern": ["stall"]},
		"hexer": {"name": "Hexer", "role": "caster", "weak": ["speed", "grip"], "moves": ["hex"], "pattern": ["hex"]},
		"curer": {"name": "Curer", "role": "healer", "weak": ["speed", "grip"], "moves": ["cure"], "pattern": ["cure"]},
		"shover": {"name": "Shover", "role": "brute", "weak": ["speed", "grip"], "moves": ["shove_back"], "pattern": ["shove_back"]},
		"crusher": {"name": "Crusher", "role": "brute", "weak": ["speed", "grip"], "moves": ["big_hit"], "pattern": ["big_hit"]},
		"traity": {"name": "Traity", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"],
			"traits": [{"p": "hp_pct", "pct": 0.5}, {"p": "hp", "v": 100}, {"p": "def_pct", "pct": 0.5}, {"p": "armor", "v": 6}, {"p": "spd_pct", "pct": 0.5},
				{"p": "res_add", "v": 15}, {"p": "crit_add", "v": 0.2}, {"p": "dodge_add", "v": 0.3}]},
		"diehard": {"name": "Diehard", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"], "traits": [{"p": "survive", "pct": 0.5}]},
		"lowly": {"name": "Lowly", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"],
			"traits": [{"p": "low_hp", "below": 0.5, "do": {"k": "status", "id": "braced", "turns": 3}}, {"p": "on", "ev": "hit_taken", "do": {"k": "status", "id": "steady", "turns": 2}},
				{"p": "start_status", "id": "regen", "turns": 2}, {"p": "school_pct", "school": "all", "pct": 0.5}]},
		"bouncer": {"name": "Bouncer", "role": "brute", "weak": ["speed", "grip"], "moves": ["poke"], "pattern": ["poke"], "traits": [{"p": "bounce"}]},
		"ref_dummy": {"name": "Ref Dummy", "role": "caster", "weak": ["speed", "mind"], "moves": ["smack"], "pattern": ["smack"]},
	}
	var pets = {
		"t_biter": {"id": "t_biter", "auto": {"name": "Nip", "kind": "attack", "power": 0.5, "school": "push", "fx": [], "every": 1},
			"command": {"name": "Maul", "charge": 2, "power": 1.5, "target": "foe", "school": "push", "fx": [{"k": "status", "id": "exposed", "turns": 2}]},
			"passive": []},
		"t_nurse": {"id": "t_nurse", "auto": {"name": "Lick", "kind": "support", "power": 0.0, "school": "flow", "fx": [{"k": "heal", "pct": 0.05}], "every": 2},
			"command": {"name": "Big Lick", "charge": 2, "power": 0.0, "target": "self", "school": "flow", "fx": [{"k": "heal", "pct": 0.2}, {"k": "status", "id": "braced", "turns": 2}]},
			"passive": []},
	}
	return {"moves": moves, "foes": foes, "foe_moves": foe_moves, "pets": pets, "items": {}}


var _move_ids = null


## Every test move but the ultimate: the test hero has them all equipped.
func move_ids() -> Array:
	if _move_ids == null:
		_move_ids = custom().moves.keys().filter(func(id): return id != "t_ult")
	return _move_ids.duplicate()


func stats(v: float) -> Dictionary:
	var s = {}
	for id in RpgDefs.STATS:
		s[id] = v
	return s


## The test hero: every stat 30, level 5, no crit, no dodge, far quicker than
## any foe and first to act, so a check can take several turns undisturbed.
func hero(over: Dictionary = {}, fx: Array = []) -> Dictionary:
	var h = {"name": "Tester", "hp_max": 400, "def": 20.0, "spd": 4000.0, "res": 30.0, "tec": 30.0, "crit": 0.0, "dodge": 0.0,
		"s": stats(30.0), "w": ALL_W.duplicate(), "lvl": 5, "en_max": 8,
		"moves": move_ids(), "ult": "",
		"fx": [{"p": "first_turn"}] + fx, "belt": []}
	for k in over:
		h[k] = over[k]
	return h


## A hero no quicker than the foes (they act between its turns).
func slow_hero(over: Dictionary = {}, fx: Array = []) -> Dictionary:
	var o = {"spd": 20.0}
	for k in over:
		o[k] = over[k]
	return hero(o, fx)


func wave(ids: Array, n: float = 20.0) -> Array:
	var w = []
	for id in ids:
		w.append({"foe": str(id), "n": n})
	return w


func begin(h: Dictionary, waves: Array, extra: Dictionary = {}) -> Dictionary:
	var setup = {"hero": h, "pet": null, "waves": waves, "seed": 11, "custom": custom()}
	for k in extra:
		setup[k] = extra[k]
	return RpgBattle.start(setup)


## Foes that will not die in a check.
func tough(B: Dictionary, hp: int = 1000000) -> Dictionary:
	for f in B.foes:
		f["hp_max"] = hp
		f["hp"] = hp
	return B


func move(B: Dictionary, id: String, target: String = "f0") -> Array:
	return RpgBattle.act(B, {"t": "move", "id": id, "target": target})


func put(u: Dictionary, id: String, turns: int = 3, stacks: int = 1, amount: float = 0.0) -> void:
	RpgBattle._put_status(u, id, turns, stacks, amount, "test", false)


## Events of one kind (and, if asked, with one field at one value).
func evs(ev: Array, t: String, key: String = "", val = null) -> Array:
	var out = []
	for e in ev:
		if str(e.get("t", "")) == t and (key == "" or e.get(key) == val):
			out.append(e)
	return out


func first(ev: Array, t: String, key: String = "", val = null) -> Dictionary:
	var list = evs(ev, t, key, val)
	return list[0] if not list.is_empty() else {}


func at_of(ev: Array, t: String, key: String = "", val = null) -> int:
	for i in range(ev.size()):
		if str(ev[i].get("t", "")) == t and (key == "" or ev[i].get(key) == val):
			return i
	return -1


## The middle of what an attack would really do (weaknesses known or not).
func mid(B: Dictionary, id: String, target: String = "f0") -> float:
	var action = {"t": "strike", "target": target} if id == "strike" else {"t": "move", "id": id, "target": target}
	var p = RpgBattle.preview(B, action, true)
	return 0.5 * (float(p.lo) + float(p.hi))


## The hero passes turns (Guard) until `stop` says so; returns every event on the way.
func wait_for(B: Dictionary, stop: Callable, most: int = 200) -> Array:
	var all = []
	for i in range(most):
		if RpgBattle.over(B):
			break
		var ev = RpgBattle.act(B, {"t": "guard"})
		all.append_array(ev)
		if stop.call(ev):
			break
	return all


func rt(B: Dictionary) -> Dictionary:
	return TTUtil.normalize_json(JSON.parse_string(JSON.stringify(B)))


func _init() -> void:
	_start_and_order()
	_hero_turn()
	_guard_break()
	_weakness_knowledge()
	_intents()
	_statuses()
	_foe_moves_and_phases()
	_waves_and_endings()
	_companion()
	_mods()
	_effects()
	_passives()
	_hero_build()
	_ai()
	_validators()
	_words()
	_replay()
	_random_fights()
	_reference_ttk()
	print("RPG BATTLE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# =============================================================================
# 4.1, 4.2: the start, the numbers, the turn order
# =============================================================================

func _start_and_order() -> void:
	var B = begin(hero(), [wave(["dummy", "plain"])])
	var h = B.hero
	ok(RpgBattle.json_safe(B) == "", "a new battle is JSON-safe", RpgBattle.json_safe(B))
	ok(str(h.id) == "hero" and int(h.hp) == 400 and int(h.en) == RpgDefs.EN_START + RpgDefs.EN_TURN and float(h.gauge) == 0.0 and bool(B.wait),
		"the hero starts whole, with 3 energy and 1 more at its first turn", [h.hp, h.en, h.gauge])
	var open = RpgBattle.opening(B)
	ok(first(open, "wave").get("n") == 1 and first(open, "wave").units.size() == 2 and evs(open, "intent").size() == 2
		and first(open, "turn").get("who") == "hero", "the opening: the wave, an intent per foe, the hero's turn", open.map(func(e): return e.t))
	ok(RpgBattle.options(B).targets == ["f0", "f1"] and RpgBattle.foes(B).size() == 2 and RpgBattle.unit(B, "f1").name == "Plain"
		and RpgBattle.unit(B, "nobody") == null and not RpgBattle.over(B) and not RpgBattle.won(B), "units by id, the living foes, the targets")

	# the solved foe numbers (RpgDefs), the pack rule, the roles
	var lone = begin(hero(), [wave(["dummy"], 30.0)]).foes[0]
	var role = RpgDefs.role("brute")
	ok(near(float(lone.hp_max), RpgDefs.foe_hp(30.0) * float(role[0]), 0.01) and near(float(lone.atk), RpgDefs.foe_atk(30.0) * float(role[1]))
		and near(float(lone.def), RpgDefs.foe_def(30.0)) and near(float(lone.spd), RpgDefs.foe_spd("brute", 30.0)) and int(lone.guard) == 3,
		"a lone foe has the solved numbers times its role", [lone.hp_max, lone.atk, lone.def, lone.spd])
	var pack = begin(hero(), [wave(["dummy", "plain", "hitter"], 30.0)]).foes[0]
	ok(near(float(pack.hp_max), float(lone.hp_max) * RpgDefs.pack_mult(3), 0.01) and near(float(pack.atk), float(lone.atk) * RpgDefs.pack_mult(3)),
		"each of three regular foes has 2 / (3 + 1) of the hp and attack", [pack.hp_max, lone.hp_max])
	var with_boss = begin(hero(), [wave(["big", "dummy"], 30.0)])
	ok(near(float(with_boss.foes[0].hp_max), RpgDefs.foe_hp(30.0) * float(RpgDefs.ROLES["boss"][0]), 0.01) and near(float(with_boss.foes[1].hp_max), float(lone.hp_max) * RpgDefs.ADD_MULT, 0.01)
		and float(with_boss.foes[0].crit) == 0.0 and near(float(lone.crit), RpgDefs.FOE_CRIT),
		"a boss is never scaled and never crits; its add has half", [with_boss.foes[0].hp_max, with_boss.foes[1].hp_max])
	ok(near(float(with_boss.foes[0].tec), RpgDefs.ref_stat(4.0) + 20.0) and near(float(lone.tec), RpgDefs.ref_stat(4.0)), "a foe's tec and res: the reference stat, a boss 20 more")

	# the first `at`: half to a whole rank-1 delay; the hero with "first_turn" at 0
	var spread = true
	for f in B.foes:
		var d = RpgDefs.delay(1.0, float(f.spd))
		if float(f.at) < 0.5 * d - 0.001 or float(f.at) > d + 0.001:
			spread = false
	ok(spread and float(h.at) == 0.0, "first `at`: between half and a whole rank-1 delay; a first_turn hero at 0", [B.foes[0].at, h.at])
	var late = begin(hero({"fx": [], "spd": 30.0}), [wave(["dummy"])])
	var d0 = RpgDefs.delay(1.0, 30.0)
	ok(float(late.hero.at) >= 0.5 * d0 - 0.001 and float(late.hero.at) <= d0 + 0.001 and float(late.hero.at) > 0.0, "without it the hero's first `at` is rolled too", late.hero.at)

	# ties: hero, companion, foes in order; the timeline assumes rank 1
	var T = begin(hero(), [wave(["dummy", "plain"])], {"pet": {"pet": "t_biter", "rarity": "common", "charge_max": 2}})
	T.hero["at"] = 5
	T.pet["at"] = 5
	T.foes[0]["at"] = 5
	T.foes[1]["at"] = 5
	ok(RpgBattle.timeline(T, 4) == ["hero", "pet", "f0", "f1"], "a tie: the hero, the companion, then the foes in their order", RpgBattle.timeline(T, 4))
	var tl = RpgBattle.timeline(B, 7)
	ok(tl.size() == 7 and tl[0] == "hero" and tl.count("hero") >= 6, "the timeline lists the next 7; a far quicker hero fills it", tl)
	var even = begin(hero({"spd": float(B.foes[0].spd)}), [wave(["dummy"])])
	even.foes[0]["at"] = 0
	ok(RpgBattle.timeline(even, 6) == ["hero", "f0", "hero", "f0", "hero", "f0"], "equal speeds take turns", RpgBattle.timeline(even, 6))

	# at += delay(rank of what it did, its speed)
	tough(B)
	var at0 = float(h.at)
	RpgBattle.act(B, {"t": "strike", "target": "f0"})
	ok(near(float(h.at), at0 + RpgDefs.delay(RpgDefs.STRIKE_RANK, 4000.0), 0.0001), "after Strike the hero waits delay(0.9, speed)", [at0, h.at])
	at0 = float(h.at)
	move(B, "t_cost")
	ok(near(float(h.at), at0 + RpgDefs.delay(1.2, 4000.0), 0.0001), "a heavy move (rank 1.2) waits longer", [at0, h.at])
	at0 = float(h.at)
	RpgBattle.act(B, {"t": "guard"})
	ok(near(float(h.at), at0 + RpgDefs.delay(RpgDefs.GUARD_RANK, 4000.0), 0.0001), "Guard is quick (rank 0.7)")

	# Hasted and Slowed
	var f = B.foes[0]
	var base = float(f.spd)
	put(f, "slowed")
	ok(near(RpgBattle.speed_of(f), base * RpgDefs.SLOW), "Slowed: speed x0.7", RpgBattle.speed_of(f))
	put(f, "hasted")
	ok(not RpgBattle.has_status(f, "slowed") and not RpgBattle.has_status(f, "hasted") and near(RpgBattle.speed_of(f), base), "Hasted on a Slowed unit: the pair cancels, both are gone")
	put(f, "hasted")
	ok(near(RpgBattle.speed_of(f), base * RpgDefs.HASTE), "Hasted: speed x1.3")

	# a Slow of one turn still makes the foe's next wait longer (the speed it had in the turn counts)
	var S = begin(hero({"spd": 20.0}), [wave(["plain"])])
	var sf = S.foes[0]
	put(sf, "slowed", 1)
	sf["at"] = 0.5
	var before = float(sf.at)
	RpgBattle.act(S, {"t": "guard"})
	ok(not RpgBattle.has_status(sf, "slowed") and near(float(sf.at) - before, RpgDefs.delay(1.0, float(sf.spd) * RpgDefs.SLOW), 0.001),
		"Slowed for 1 turn: the turn it covers ends with the longer wait", [float(sf.at) - before, RpgDefs.delay(1.0, float(sf.spd))])


# =============================================================================
# 4.3: the hero's turn
# =============================================================================

func _hero_turn() -> void:
	# a move: energy, cooldown, what cannot be done
	var B = tough(begin(hero(), [wave(["plain"])]))
	var h = B.hero
	var o = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0]
	ok(o.ok and int(o.cost) == 2 and int(o.cd) == 0 and RpgBattle.options(B).strike and RpgBattle.options(B).guard, "options: a move with its cost, ready")
	var ev = move(B, "t_cost")
	ok(first(ev, "energy").get("v") == 2 and first(ev, "act").get("kind") == "move" and first(ev, "act").get("id") == "t_cost" and first(ev, "act").get("school") == "push"
		and int(h.en) == 3, "a move takes its energy (4 - 2), then the next turn gives 1", [ev.map(func(e): return e.t), h.en])
	o = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0]
	ok(not o.ok and o.why == "cooldown" and int(o.cd) == 2, "it rests: cooldown 2", o)
	ok(move(B, "t_cost") == [{"t": "no", "why": "cooldown"}] and int(h.en) == 3, "used while resting: nothing happens", h.en)
	move(B, "t_pull")
	o = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0]
	ok(not o.ok and int(o.cd) == 1, "one hero turn later: cooldown 1", o)
	move(B, "t_pull")
	o = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0]
	ok(o.ok and int(o.cd) == 0, "two hero turns later it is ready again", o)
	h["en"] = 1
	o = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0]
	ok(not o.ok and o.why == "energy" and move(B, "t_cost") == [{"t": "no", "why": "energy"}], "not enough energy: not allowed", o)
	ok(move(B, "nothing") == [{"t": "no", "why": "unknown"}] and move(B, "shove") == [{"t": "no", "why": "unknown"}], "a move that is not equipped is not allowed")

	# the damage formula, from RpgDefs
	B = tough(begin(hero(), [wave(["plain"])]))
	var f = B.foes[0]
	var base = 1.0 * RpgDefs.offence(30.0, W, 5) * RpgDefs.mitigation(float(f.def))
	var pv = RpgBattle.preview(B, {"t": "move", "id": "t_pull", "target": "f0"}, true)
	ok(int(pv.lo) == int(floor(base * RpgDefs.ROLL_LO)) and int(pv.hi) == int(ceil(base * (RpgDefs.ROLL_LO + RpgDefs.ROLL_SPAN))) and not pv.weak and not pv.resist and int(pv.chip) == 0,
		"preview: power x offence x mitigation, the roll's low and high", [pv, base])
	var in_range = true
	for i in range(12):
		var amount = int(first(move(B, "t_pull"), "dmg").get("amount", -1))
		if amount < int(pv.lo) or amount > int(pv.hi):
			in_range = false
	ok(in_range, "every hit lands inside the previewed range")
	var two = RpgDefs.offence(0.6 * 50.0 + 0.4 * 30.0, W, 5)
	var H2 = hero()
	H2.s["arms"] = 50.0
	B = tough(begin(H2, [wave(["plain"])]))
	ok(near(RpgBattle.offence_of(B.hero, RpgBattle.move_row(B, "t_two")), two, 0.0001), "a two-stat move: 0.6 and 0.4 of its stats", RpgBattle.offence_of(B.hero, RpgBattle.move_row(B, "t_two")))

	# Strike: free, +1 energy, the best body stat, never weak, never chips
	var HS = hero()
	HS.s["legs"] = 60.0
	HS["w"] = {"legs": 100.0, "push": 5.0}
	B = tough(begin(HS, [wave(["dummy"])]))
	h = B.hero
	ok(near(mid(B, "strike"), RpgDefs.STRIKE_POWER * RpgDefs.offence(60.0, 100.0, 5) * RpgDefs.mitigation(float(B.foes[0].def)), 0.02),
		"Strike: power 0.9 with the best body stat (and that stat's school's gear)", mid(B, "strike"))
	var at0 = float(h.at)
	ev = RpgBattle.act(B, {"t": "strike", "target": "f0"})
	var hit = first(ev, "dmg")
	ok(first(ev, "energy").get("v") == 5 and int(h.en) == 6 and hit.get("school") == "plain" and not hit.weak and not hit.resist and int(hit.chip) == 0 and int(B.foes[0].guard) == 3,
		"Strike gives 1 energy, is never weak and never chips", [hit, h.en])
	ok(RpgBattle.summary(B).schools.is_empty(), "Strike is not a school in the summary")

	# Guard
	B = begin(slow_hero(), [wave(["hitter"])])
	h = B.hero
	var foe = B.foes[0]
	var d_open = int(foe.intent.dmg)
	foe["at"] = float(B.now) + 0.5
	ev = RpgBattle.act(B, {"t": "guard"})
	var gm = RpgDefs.guard_mult(30.0)
	var shown = evs(ev, "intent", "who", "f0")
	var took = first(ev, "dmg", "dst", "hero")
	ok(first(ev, "act").get("kind") == "guard" and first(ev, "energy").get("v") == 6 and int(RpgBattle.summary(B).guards) == 1, "Guard gives 2 energy and is counted", ev.map(func(e): return e.t))
	ok(not shown.is_empty() and absf(float(shown[0].intent.dmg) - float(d_open) * gm) <= 1.0, "the foe's intent shows the guarded number at once", [d_open, shown[0].intent.dmg if not shown.is_empty() else null])
	ok(not took.is_empty() and near(float(took.amount), float(d_open) * gm, 0.12) and near(gm, 0.425, 0.001), "a guarded hit is x(0.5 - core / 400)", [took.get("amount"), d_open, gm])
	ok(not bool(h.guarding) and int(foe.intent.dmg) == d_open, "Guard lasts until the hero's next turn: the next intent is whole again", [h.guarding, foe.intent.dmg])

	# energy: 1 a turn, clamped
	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	for i in range(6):
		RpgBattle.act(B, {"t": "guard"})
	ok(int(h.en) == int(h.en_max), "energy never passes its maximum", h.en)

	# items: the belt
	B = tough(begin(hero({"belt": [{"id": "protein_shake", "n": 5}, {"id": "electrolytes", "n": 2}]}), [wave(["plain"])]))
	h = B.hero
	h["hp"] = 100
	h["en"] = 0
	var it = RpgBattle.options(B).items
	ok(it.size() == 2 and it[0].id == "protein_shake" and int(it[0].n) == 5 and it[0].ok, "options: the belt's stacks", it)
	at0 = float(h.at)
	ev = RpgBattle.act(B, {"t": "item", "id": "protein_shake"})
	var want = int(round(0.35 * 400.0 * RpgDefs.heal_mult(30.0)))
	ok(first(ev, "act").get("kind") == "item" and first(ev, "heal").get("amount") == want and near(float(h.at), at0 + RpgDefs.delay(RpgDefs.ITEM_RANK, 4000.0), 0.0001),
		"an item: its effect (a heal by Flow), rank 0.6", [first(ev, "heal"), want])
	h["hp"] = 10
	RpgBattle.act(B, {"t": "item", "id": "protein_shake"})
	h["hp"] = 10
	RpgBattle.act(B, {"t": "item", "id": "protein_shake"})
	it = RpgBattle.options(B).items
	ok(not it[0].ok and int(it[0].n) == 2 and RpgBattle.act(B, {"t": "item", "id": "protein_shake"}) == [{"t": "no", "why": "item"}], "a stack is used 3 times in a battle at most", it[0])
	RpgBattle.act(B, {"t": "item", "id": "electrolytes"})
	h["en"] = 0
	RpgBattle.act(B, {"t": "item", "id": "electrolytes"})
	it = RpgBattle.options(B).items
	var sum = RpgBattle.summary(B)
	ok(not it[1].ok and int(it[1].n) == 0 and sum.used == {"protein_shake": 3, "electrolytes": 2} and int(sum.items) == 5 and sum.schools.is_empty(),
		"an empty stack is done; the summary says what was used", [it[1], sum.used])
	B = tough(begin(hero({"belt": [{"id": "protein_shake", "n": 5}]}), [wave(["plain"])], {"rules": ["no_items"]}))
	ok(not RpgBattle.options(B).items[0].ok and RpgBattle.act(B, {"t": "item", "id": "protein_shake"}) == [{"t": "no", "why": "rule"}], "the rule no_items shuts the belt")

	# the ultimate
	B = tough(begin(hero({"ult": "t_ult"}), [wave(["plain"])]))
	h = B.hero
	ok(not RpgBattle.options(B).ult.ok and RpgBattle.act(B, {"t": "ult", "target": "f0"}) == [{"t": "no", "why": "gauge"}], "the ultimate needs a full gauge")
	h["gauge"] = 100
	at0 = float(h.at)
	ok(RpgBattle.options(B).ult.ok and RpgBattle.options(B).ult.id == "t_ult", "a full gauge: the ultimate is ready")
	ev = RpgBattle.act(B, {"t": "ult", "target": "f0"})
	ok(first(ev, "act").get("kind") == "ult" and first(ev, "gauge").get("v") == 0 and float(h.gauge) == 0.0 and near(float(h.at), at0 + RpgDefs.delay(RpgDefs.ULT_RANK, 4000.0), 0.0001)
		and not first(ev, "dmg").is_empty(), "the ultimate uses the whole gauge and fills none of it; it acts at rank 1.0 whatever its row says", [h.gauge, ev.map(func(e): return e.t)])

	# the gauge
	B = tough(begin(hero(), [wave(["dummy"])]))
	h = B.hero
	var gm2 = RpgDefs.gauge_mult(30.0)
	ev = move(B, "t_pull")
	ok(near(float(h.gauge), RpgDefs.GAUGE_ACT * gm2, 0.002), "gauge: +6 an attacking action, times (1 + grit / 200)", h.gauge)
	ev = move(B, "t_push")
	ok(near(float(h.gauge), (2.0 * RpgDefs.GAUGE_ACT + RpgDefs.GAUGE_WEAK) * gm2, 0.002), "gauge: +4 more for a weakness hit", h.gauge)
	var g0 = float(h.gauge)
	RpgBattle.act(B, {"t": "guard"})
	ok(float(h.gauge) == g0, "Guard fills no gauge")
	move(B, "t_push")
	ev = move(B, "t_push")
	ok(not first(ev, "break").is_empty() and near(float(h.gauge), g0 + (2.0 * (RpgDefs.GAUGE_ACT + RpgDefs.GAUGE_WEAK) + RpgDefs.GAUGE_BREAK) * gm2, 0.002), "gauge: +20 for a break", [h.gauge, g0])
	B = begin(slow_hero({"hp_max": 1000}), [wave(["hitter"])])
	h = B.hero
	B.foes[0]["at"] = float(B.now) + 0.5
	B.foes[0]["crit"] = 0
	ev = RpgBattle.act(B, {"t": "strike", "target": "f0"})
	var lost = int(first(ev, "dmg", "dst", "hero").get("amount", 0))
	ok(lost > 0 and near(float(h.gauge), (RpgDefs.GAUGE_ACT + RpgDefs.GAUGE_HURT * float(lost) / 1000.0) * gm2, 0.01) and int(RpgBattle.summary(B).taken) == lost,
		"gauge: +60 x the share of max HP lost", [h.gauge, lost])
	h["gauge"] = 99
	move(B, "t_push")
	ok(float(h.gauge) == RpgDefs.GAUGE_MAX, "the gauge stops at 100", h.gauge)

	# flee
	B = begin(hero(), [wave(["plain"])])
	ev = RpgBattle.act(B, {"t": "flee"})
	sum = RpgBattle.summary(B)
	ok(ev.size() == 2 and ev[1] == {"t": "end", "win": false} and RpgBattle.over(B) and not RpgBattle.won(B) and sum.fled and not sum.win and RpgBattle.options(B).targets.is_empty()
		and RpgBattle.act(B, {"t": "strike"}) == [{"t": "no", "why": "over"}], "Flee ends the battle as a loss", ev)

	# a missing or dead target becomes the first living foe
	B = tough(begin(hero(), [wave(["plain", "dummy"])]))
	ev = move(B, "t_pull", "nobody")
	ok(first(ev, "dmg").get("dst") == "f0" and first(ev, "act").get("target") == "f0", "a target nobody knows: the first living foe")
	B.foes[0]["hp"] = 1
	move(B, "t_pull", "f0")
	ev = move(B, "t_pull", "f0")
	ok(first(ev, "dmg").get("dst") == "f1" and RpgBattle.options(B).targets == ["f1"], "a dead target: the first living foe", first(ev, "dmg"))


# --- more helpers --------------------------------------------------------------

const STRIKE = {"t": "strike", "target": "f0"}
const GUARD = {"t": "guard"}


## The foe is due right after the hero's next action (the test hero is far
## quicker: the foe acts exactly once before the hero chooses again).
func soon(B: Dictionary, id: String = "f0") -> void:
	RpgBattle.unit(B, id)["at"] = float(B.now) + 0.001


## The hero does `action` (Guard unless told), then the foe has its turn.
func foe_turn(B: Dictionary, id: String = "f0", action: Dictionary = GUARD) -> Array:
	soon(B, id)
	return RpgBattle.act(B, action)


## Stuns a foe with the test move (its chance is capped at 95%: try again).
func stun(B: Dictionary, id: String = "f0") -> Array:
	var ev = []
	for i in range(12):
		ev = move(B, "k_stun", id)
		if RpgBattle.has_status(RpgBattle.unit(B, id), "stun"):
			break
	return ev


func turns_of(u: Dictionary, id: String) -> int:
	var st = RpgBattle.status_of(u, id)
	return -1 if st == null else int(st.turns)


func stacks_of(u: Dictionary, id: String) -> int:
	var st = RpgBattle.status_of(u, id)
	return 0 if st == null else int(st.stacks)


func kinds(ev: Array) -> Array:
	return ev.map(func(e): return str(e.t))


## A copy of the made-up rows with one foe's rules set.
func custom_rules(foe_id: String, rules: Array) -> Dictionary:
	var c = custom()
	c.foes[foe_id]["rules"] = rules
	return c


## Every foe action in `ev` against what that foe's intent said just before it
## acted. `said` = {foe id: the damage its intent showed}; it is kept up to date
## from the intent events on the way. An action counts when nothing came between
## the number and the blow: no crit, no miss, no status that changes damage in
## the middle of it, the hero still standing. Returns {"checked", "wrong",
## "pairs": [[who, said, did]]}.
func intent_check(ev: Array, said: Dictionary) -> Dictionary:
	var out = {"checked": 0, "wrong": 0, "pairs": []}
	var i = 0
	while i < ev.size():
		var e = ev[i]
		var t = str(e.t)
		if t == "intent":
			said[str(e.who)] = int(e.intent.dmg)
		elif t == "act" and str(e.who) != "hero" and str(e.who) != "pet" and not ["lost", "charge", "count"].has(str(e.kind)):
			var who = str(e.who)
			var got = 0
			var hits = 0
			var clean = said.has(who)
			var j = i + 1
			while j < ev.size() and str(ev[j].t) != "turn" and str(ev[j].t) != "act" and str(ev[j].t) != "end":
				var x = ev[j]
				var xt = str(x.t)
				if xt == "dmg" and str(x.src) == who and str(x.dst) == "hero":
					got += int(x.amount) + int(x.absorbed)
					hits += 1
					if bool(x.crit):
						clean = false
				elif xt == "miss" and str(x.src) == who:
					clean = false
				elif xt == "ko" and str(x.dst) == "hero":
					clean = false
				elif xt == "status" and ["braced", "exposed", "pumped", "weakened"].has(str(x.id)):
					clean = false
				elif xt == "intent" and str(x.who) == who:
					break
				j += 1
			if clean:
				var want = int(said[who])
				out.checked += 1
				out.pairs.append([who, want, got])
				if absf(float(got) - float(want)) > 0.09 * float(want) + 1.5 * float(hits) + 1.0:
					out.wrong += 1
		i += 1
	return out


# =============================================================================
# 4.4: guard break
# =============================================================================

func _guard_break() -> void:
	var B = tough(begin(hero(), [wave(["dummy"])]))       # weak to push and legs, resists mind, 3 pips
	var f = B.foes[0]
	var plain = mid(B, "t_pull")
	var pv = RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"}, true)
	ok(pv.weak and not pv.resist and int(pv.chip) == 1 and near(mid(B, "t_push"), plain * RpgDefs.WEAK_MULT), "a weak school: x1.25 and 1 chip", [pv, plain])
	var ev = move(B, "t_push")
	var d = first(ev, "dmg")
	ok(d.weak and int(d.chip) == 1 and int(d.guard) == 2 and int(f.guard) == 2 and int(d.amount) >= int(pv.lo) and int(d.amount) <= int(pv.hi), "the weak hit takes one pip", d)
	pv = RpgBattle.preview(B, {"t": "move", "id": "t_mind", "target": "f0"}, true)
	ok(pv.resist and not pv.weak and int(pv.chip) == 0 and near(mid(B, "t_mind"), plain * RpgDefs.RESIST_MULT), "a resisted school: x0.7", pv)
	ev = move(B, "t_mind")
	d = first(ev, "dmg")
	ok(d.resist and not d.weak and int(d.chip) == 0 and int(f.guard) == 2, "a resisted hit never chips", d)
	ev = move(B, "m_smart_mind")
	ok(int(first(ev, "dmg").chip) == 0 and int(f.guard) == 2, "smart does not chip through a resistance")
	ev = move(B, "m_smart")
	d = first(ev, "dmg")
	ok(not d.weak and int(d.chip) == 1 and int(f.guard) == 1, "smart chips 1 even when the school is not weak", d)
	ev = RpgBattle.act(B, STRIKE)
	ok(int(first(ev, "dmg").chip) == 0 and int(f.guard) == 1, "Strike never chips")

	# ONCE per move per target, however many hits; a breaker takes 2
	B = tough(begin(hero(), [wave(["dummy"])]))
	f = B.foes[0]
	ev = move(B, "t_multi")
	var chips = evs(ev, "dmg").map(func(e): return int(e.chip))
	ok(chips == [1, 0, 0] and int(f.guard) == 2, "three weak hits of one move chip once", chips)
	ev = move(B, "t_break")
	ok(int(first(ev, "dmg").chip) == 2 and not first(ev, "break").is_empty() and bool(f.broken) and int(f.guard) == 0 and int(RpgBattle.summary(B).breaks) == 1,
		"a breaker chips 2; at 0 pips the foe is Broken", [first(ev, "dmg"), f.guard])
	ok(f.intent.kind == "stunned" and int(f.intent.dmg) == 0 and first(ev, "intent", "who", "f0").intent.kind == "stunned", "a Broken foe's intent is cancelled", f.intent)
	ok(near(mid(B, "t_pull"), plain * RpgDefs.BROKEN_MULT), "a Broken foe takes x1.4", [mid(B, "t_pull"), plain])
	ev = move(B, "t_push")
	ok(int(first(ev, "dmg").chip) == 0 and int(f.guard) == 0 and evs(ev, "break").is_empty() and int(RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"}, true).chip) == 0,
		"a Broken foe has nothing to chip")
	ev = foe_turn(B)
	ok(first(ev, "act", "who", "f0").get("kind") == "lost" and evs(ev, "dmg", "dst", "hero").is_empty() and first(ev, "recover").get("guard") == 3
		and not bool(f.broken) and int(f.guard) == 3, "it loses its next action; then the pips are back", kinds(ev))
	ok(near(mid(B, "t_pull"), plain) and f.intent.move == "poke", "x1.4 ends with the lost action; it chooses again", [mid(B, "t_pull"), f.intent])
	ev = move(B, "t_push")
	d = first(ev, "dmg")
	ok(d.weak and int(d.chip) == 0 and int(f.guard) == 3 and int(RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"}, true).chip) == 0,
		"the new pips cannot be chipped until it has acted once", d)
	ev = move(B, "k_chip")
	ok(evs(ev, "chip").is_empty() and int(f.guard) == 3, "not by a chip effect either")
	ev = foe_turn(B)
	ok(first(ev, "act", "who", "f0").get("kind") == "attack", "it acts")
	ev = move(B, "t_push")
	ok(int(first(ev, "dmg").chip) == 1 and int(f.guard) == 2, "after it has acted the pips chip again")

	# the hit that breaks is not yet x1.4; the later hits of the same move are
	B = tough(begin(hero(), [wave(["dummy"])]))
	f = B.foes[0]
	f["guard"] = 1
	ev = move(B, "t_multi")
	var hits = evs(ev, "dmg")
	ok(hits.size() == 3 and at_of(ev, "break") > at_of(ev, "dmg") and float(hits[1].amount) > 1.15 * float(hits[0].amount) and float(hits[2].amount) > 1.15 * float(hits[0].amount),
		"the breaking hit is plain, the hits after it land on a Broken foe", hits.map(func(e): return e.amount))
	B = tough(begin(hero(), [wave(["dummy"])]))
	B.foes[0]["guard"] = 1
	ev = move(B, "t_break")
	ok(int(first(ev, "dmg").chip) == 1 and int(B.foes[0].guard) == 0, "a chip never takes more pips than there are")

	# every target of a move is chipped once: all, splash
	B = tough(begin(hero(), [wave(["dummy", "dummy"])]))
	ev = move(B, "t_all")
	ok(evs(ev, "dmg").size() == 2 and int(B.foes[0].guard) == 2 and int(B.foes[1].guard) == 2, "a move on all foes chips each once")
	ev = move(B, "t_splash", "f0")
	hits = evs(ev, "dmg")
	ok(hits.size() == 2 and hits[0].dst == "f0" and hits[1].dst == "f1" and near(float(hits[1].amount), 0.5 * float(hits[0].amount), 0.2) and int(B.foes[1].guard) == 1,
		"a splash hits the others for its share, and chips them too", hits.map(func(e): return e.amount))

	# a foe with no guard is never Broken
	B = tough(begin(hero(), [wave(["noguard"])]))
	ev = move(B, "t_break")
	ok(first(ev, "dmg").weak and int(first(ev, "dmg").chip) == 0 and evs(ev, "break").is_empty() and not bool(B.foes[0].broken), "a foe without pips is never Broken")
	# a rule of the setup: 2 more pips
	B = begin(hero(), [wave(["dummy"])], {"rules": ["guard_up"]})
	ok(int(B.foes[0].guard) == 5 and int(B.foes[0].guard_max) == 5, "the rule guard_up: 2 more pips")


# =============================================================================
# 4.4: what the player knows of a foe's schools
# =============================================================================

func _weakness_knowledge() -> void:
	var B = tough(begin(hero(), [wave(["dummy", "plain"])]))
	ok(RpgBattle.known(B, "f0") == {"weak": [], "resist": [], "all": false} and RpgBattle.known(B, "hero").weak.is_empty(), "weaknesses start hidden")
	var hidden = RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"})
	ok(not hidden.weak and int(hidden.chip) == 0 and near(0.5 * (float(hidden.lo) + float(hidden.hi)), mid(B, "t_pull")), "the preview tells nothing the player does not know", hidden)
	var ev = move(B, "t_push")
	ok(first(ev, "learn") == {"t": "learn", "key": "dummy", "school": "push"} and RpgBattle.known(B, "f0").weak == ["push"] and RpgBattle.summary(B).learned == {"dummy": ["push"]},
		"a weak hit teaches that school", first(ev, "learn"))
	ok(RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"}).weak, "then the preview says so")
	ev = move(B, "t_push")
	ok(evs(ev, "learn").is_empty(), "it is learned once")
	ev = move(B, "t_mind")
	ok(RpgBattle.known(B, "f0").resist == ["mind"] and RpgBattle.summary(B).learned == {"dummy": ["push"]} and evs(ev, "learn").is_empty(),
		"a resisted hit shows the resistance for this battle and writes nothing")
	ev = RpgBattle.act(B, STRIKE)
	ok(evs(ev, "learn").is_empty() and RpgBattle.known(B, "f0").weak == ["push"], "Strike teaches nothing")
	ev = move(B, "t_pull", "f1")
	ok(evs(ev, "learn").is_empty() and RpgBattle.known(B, "f1").weak.is_empty(), "a hit that is not weak teaches nothing")

	# what the save knew; only the new ones come back
	B = tough(begin(hero(), [wave(["dummy"])], {"known": {"dummy": ["legs"], "nobody": ["push"]}}))
	ok(RpgBattle.known(B, "f0").weak == ["legs"], "weaknesses learned before are shown")
	move(B, "t_legs")
	move(B, "t_push")
	ok(RpgBattle.summary(B).learned == {"dummy": ["push"]} and RpgBattle.known(B, "f0").weak == ["push", "legs"], "the summary gives back only what this battle taught", RpgBattle.summary(B).learned)
	RpgBattle.act(B, {"t": "flee"})
	ok(not RpgBattle.summary(B).win and RpgBattle.summary(B).learned == {"dummy": ["push"]}, "a loss keeps what was learned")

	# Insight: everything shown while it lasts, nothing written
	B = tough(begin(hero(), [wave(["dummy"])]))
	move(B, "k_insight")
	ok(RpgBattle.known(B, "f0") == {"weak": ["push", "legs"], "resist": ["mind"], "all": true} and RpgBattle.summary(B).learned.is_empty()
		and RpgBattle.preview(B, {"t": "move", "id": "t_push", "target": "f0"}).weak, "Insight shows every school and writes nothing", RpgBattle.known(B, "f0"))
	RpgBattle.act(B, GUARD)
	RpgBattle.act(B, GUARD)
	ok(not RpgBattle.has_status(B.hero, "insight") and RpgBattle.known(B, "f0").weak.is_empty(), "when Insight ends the schools are hidden again")

	# set by the setup (the hunt, the rival): always shown, never written
	B = tough(begin(hero(), [[{"foe": "dummy", "n": 20.0, "weak": ["pull", "grip"]}]]))
	ok(bool(B.foes[0].shown) and RpgBattle.known(B, "f0") == {"weak": ["pull", "grip"], "resist": ["mind"], "all": true}, "weaknesses set by the setup are shown from the start", RpgBattle.known(B, "f0"))
	ev = move(B, "t_pull")
	ok(first(ev, "dmg").weak and evs(ev, "learn").is_empty() and RpgBattle.summary(B).learned.is_empty(), "and are never written")
	ev = move(B, "t_push")
	ok(not first(ev, "dmg").weak, "its own weaknesses are replaced")


# =============================================================================
# 4.5: intents
# =============================================================================

func _intents() -> void:
	var B = tough(begin(hero(), [wave(["hitter"])]))
	var f = B.foes[0]
	f["crit"] = 0
	var it = f.intent
	var base = float(f.atk) * RpgDefs.mitigation(20.0)
	ok(it.move == "smack" and it.kind == "attack" and it.icon == "in_attack" and int(it.hits) == 1 and not it.windup and int(it.count) == 0
		and int(it.dmg) == int(floor(base + 0.5)) and it.target == "hero", "an intent: the move, its icon, the damage as things stand", it)
	ok(first(RpgBattle.opening(B), "intent").get("who") == "f0", "the first intent is shown at the start")
	var said = {"f0": int(it.dmg)}
	var ev = foe_turn(B, "f0", STRIKE)
	var res = intent_check(ev, said)
	ok(res.checked == 1 and res.wrong == 0, "the foe does what its intent said", res.pairs)
	ok(at_of(ev, "intent", "who", "f0") > at_of(ev, "act", "who", "f0") and f.intent.move == "smack", "after it acts its next move is chosen and shown")

	# the number follows what happens: statuses on either side
	for c in [["hero", "braced", 1.0 - RpgDefs.BRACE], ["hero", "exposed", 1.0 + RpgDefs.BRACE], ["foe", "pumped", 1.0 + RpgDefs.PUMP], ["foe", "weakened", 1.0 - RpgDefs.PUMP]]:
		B = tough(begin(hero(), [wave(["hitter"])]))
		f = B.foes[0]
		f["crit"] = 0
		put(B.hero if c[0] == "hero" else f, str(c[1]), 5)
		ev = RpgBattle.act(B, STRIKE)
		var shown = int(f.intent.dmg)
		said = {"f0": shown}
		res = intent_check(foe_turn(B, "f0", STRIKE), said)
		ok(absf(float(shown) - base * float(c[2])) <= 1.0 and not evs(ev, "intent", "who", "f0").is_empty() and res.checked == 1 and res.wrong == 0,
			"the %s is %s: the intent says x%s, and it is true" % [c[0], c[1], str(c[2])], [shown, base, res.pairs])

	# Guard, a multi-hit move
	B = tough(begin(hero(), [wave(["twicer"])]))
	f = B.foes[0]
	f["crit"] = 0
	var whole = int(f.intent.dmg)
	ok(int(f.intent.hits) == 2 and f.intent.kind == "multi" and f.intent.icon == "in_multi" and absf(float(whole) - base) <= 2.0, "a two-hit move: the number is both hits together", f.intent)
	said = {"f0": whole}
	res = intent_check(foe_turn(B), said)
	ok(res.checked == 1 and res.wrong == 0 and float(res.pairs[0][1]) < 0.6 * float(whole), "the hero guards: the intent says the guarded number, and it is true", [whole, res.pairs])

	# a wind-up
	B = tough(begin(hero(), [wave(["charger"])]))
	f = B.foes[0]
	f["crit"] = 0
	it = f.intent
	ok(it.windup and not it.charged and it.icon == "in_charge" and it.kind == "heavy" and absf(float(it.dmg) - 2.0 * base) <= 1.0, "a wind-up shows that it charges, and what the hit will do", it)
	said = {"f0": int(it.dmg)}
	var at0 = 0.0
	ev = foe_turn(B, "f0", STRIKE)
	at0 = float(B.now) - float(RpgDefs.delay(RpgDefs.STRIKE_RANK, 4000.0)) + 0.001
	res = intent_check(ev, said)
	ok(first(ev, "act", "who", "f0").get("kind") == "charge" and evs(ev, "dmg", "dst", "hero").is_empty() and f.intent.charged and not f.intent.windup and f.intent.icon == "in_heavy"
		and res.checked == 0, "its first turn is spent charging", [kinds(ev), f.intent])
	ok(near(float(f.at), at0 + RpgDefs.delay(1.0, float(f.spd)), 0.001), "charging is a rank-1 action", [f.at, at0])
	ev = foe_turn(B, "f0", STRIKE)
	res = intent_check(ev, said)
	ok(first(ev, "act", "who", "f0").get("kind") == "heavy" and res.checked == 1 and res.wrong == 0 and f.intent.windup and not f.intent.charged, "then it hits for what it said, and chooses again", res.pairs)
	# a perfect guard: Guard takes the charged blow
	B = tough(begin(hero(), [wave(["charger"])]))
	f = B.foes[0]
	f["crit"] = 0
	f["guard"] = 3
	f["guard_max"] = 3
	foe_turn(B, "f0", STRIKE)
	var g_before = float(B.hero.gauge)
	ev = foe_turn(B, "f0", GUARD)
	var pf = first(ev, "perfect")
	ok(not pf.is_empty() and pf.get("src") == "f0" and int(pf.get("chip", 0)) == RpgDefs.PERFECT_CHIP and int(f.guard) == 3 - RpgDefs.PERFECT_CHIP and int(RpgBattle.summary(B).perfect) == 1
		and float(B.hero.gauge) >= g_before + RpgDefs.GAUGE_PERFECT - 0.01 and at_of(ev, "perfect") > at_of(ev, "dmg", "dst", "hero"), "a Guard that takes a charged blow is a perfect guard: a pip goes and the gauge fills", [pf, f.guard, g_before, B.hero.gauge])
	ok(stacks_of(B.hero, "focus") == RpgDefs.PERFECT_FOCUS and not first(ev, "status", "id", "focus").is_empty(), "and the hero has Focus: his next hit is a sure crit", [stacks_of(B.hero, "focus")])
	var rip = RpgBattle.act(B, STRIKE)
	ok(bool(first(rip, "dmg", "dst", "f0").get("crit", false)) and stacks_of(B.hero, "focus") == 0, "the riposte is a crit, and uses the Focus up", first(rip, "dmg", "dst", "f0"))
	foe_turn(B, "f0", GUARD)
	ok(first(foe_turn(B, "f0", STRIKE), "perfect").is_empty() and int(RpgBattle.summary(B).perfect) == 1 and int(RpgBattle.summary(B).unguarded) == 1, "the same blow taken without Guard is not one, and is counted as taken open", [RpgBattle.summary(B).perfect, RpgBattle.summary(B).unguarded])
	B = tough(begin(hero(), [wave(["dummy"])]))
	ok(first(foe_turn(B, "f0", GUARD), "perfect").is_empty(), "nor is a Guard against a blow that was not charged")
	B = tough(begin(hero(), [wave(["charger"])]))
	f = B.foes[0]
	f["guard"] = 1
	f["guard_max"] = 1
	foe_turn(B, "f0", STRIKE)
	ev = foe_turn(B, "f0", GUARD)
	ok(not first(ev, "perfect").is_empty() and not first(ev, "break", "dst", "f0").is_empty() and bool(f.broken) and at_of(ev, "break") > at_of(ev, "perfect"), "a perfect guard that takes the last pip breaks the foe", kinds(ev))
	foe_turn(B, "f0", STRIKE)
	ev = move(B, "k_interrupt")
	ok(not first(ev, "interrupt").is_empty() and f.intent.windup and not f.intent.charged and not first(ev, "intent", "who", "f0").is_empty(), "an interrupt cancels the charge: it must begin again", f.intent)
	foe_turn(B, "f0", STRIKE)
	stun(B)
	ok(f.intent.kind == "stunned" and f.intent.icon == "in_stunned" and int(f.intent.dmg) == 0 and not f.intent.charged, "a stun cancels the charge; a foe that will lose its action shows stunned", f.intent)
	ev = foe_turn(B, "f0", STRIKE)
	ok(first(ev, "act", "who", "f0").get("kind") == "lost" and evs(ev, "dmg", "dst", "hero").is_empty() and f.intent.windup, "the stunned foe loses the action and starts over", kinds(ev))
	foe_turn(B, "f0", STRIKE)
	f["guard"] = 1
	ev = move(B, "t_push")
	ok(bool(f.broken) and f.intent.kind == "stunned" and not f.intent.charged, "a break cancels the charge")
	B = tough(begin(hero(), [wave(["hitter"])]))
	ev = move(B, "k_interrupt")
	ok(evs(ev, "interrupt").is_empty(), "there is nothing to interrupt in a plain hit")

	# a countdown
	B = tough(begin(hero(), [wave(["bomber"])]))
	f = B.foes[0]
	f["crit"] = 0
	ok(int(f.intent.count) == 3 and f.intent.kind == "bomb" and f.intent.icon == "in_bomb" and absf(float(f.intent.dmg) - 2.0 * float(f.atk) * RpgDefs.mitigation(20.0)) <= 1.0,
		"a countdown shows its number and what it will do", f.intent)
	said = {"f0": int(f.intent.dmg)}
	ev = foe_turn(B, "f0", STRIKE)
	intent_check(ev, said)
	ok(first(ev, "act", "who", "f0").get("kind") == "count" and int(f.intent.count) == 2 and evs(ev, "dmg", "dst", "hero").is_empty(), "each of its turns the number goes down", f.intent)
	intent_check(foe_turn(B, "f0", STRIKE), said)
	ok(int(f.intent.count) == 1, "3, 2, 1")
	ev = foe_turn(B, "f0", STRIKE)
	res = intent_check(ev, said)
	ok(first(ev, "act", "who", "f0").get("kind") == "bomb" and res.checked == 1 and res.wrong == 0 and not first(ev, "ko", "dst", "f0").is_empty() and RpgBattle.won(B)
		and int(RpgBattle.summary(B).kos) == 1, "then it goes off for what it said, and is gone (it still counts)", [kinds(ev), res.pairs])
	B = tough(begin(hero(), [wave(["bomber"])]))
	foe_turn(B, "f0", STRIKE)
	ev = move(B, "k_interrupt")
	ok(not first(ev, "interrupt").is_empty() and int(B.foes[0].intent.count) == 3, "an interrupt sets the countdown back")

	# a foe that ramps: the number is the one of the turn the hit comes in
	B = tough(begin(hero({"hp_max": 100000}), [wave(["ramper"])]))
	f = B.foes[0]
	f["crit"] = 0
	said = {"f0": int(f.intent.dmg)}
	var wrong = 0
	var checked = 0
	var seen = []
	for i in range(4):
		res = intent_check(foe_turn(B, "f0", STRIKE), said)
		wrong += int(res.wrong)
		checked += int(res.checked)
		seen.append(res.pairs)
	ok(checked == 4 and wrong == 0 and int(seen[2][0][2]) > int(seen[0][0][2]), "a foe that hits harder each turn says the number of the turn the hit comes in", seen)

	# the intent after next (Insight)
	B = tough(begin(hero(), [wave(["ruler"])]))
	f = B.foes[0]
	ok(f.intent.move == "poke" and RpgBattle.next_intent(B, "f0").get("move") == "slap" and RpgBattle.next_intent(B, "nobody").is_empty(), "the intent after next: the next step of the pattern")
	foe_turn(B)
	ok(f.intent.move == "slap" and RpgBattle.next_intent(B, "f0").get("move") == "poke", "the pattern goes round")
	B = tough(begin(hero(), [wave(["ruler"])], {"custom": custom_rules("ruler", [{"if": "turn_mod", "v": 2, "use": "smack"}])}))
	ok(B.foes[0].intent.move == "poke" and RpgBattle.next_intent(B, "f0").get("move") == "smack", "the intent after next counts the turn it is for")


# =============================================================================
# 4.6: statuses
# =============================================================================

func _statuses() -> void:
	# Pumped / Weakened: damage dealt; Braced / Exposed: damage taken
	var B = tough(begin(hero(), [wave(["plain"])]))
	var h = B.hero
	var f = B.foes[0]
	var plain = mid(B, "t_pull")
	put(h, "pumped")
	ok(near(mid(B, "t_pull"), plain * (1.0 + RpgDefs.PUMP)), "Pumped: +25% damage dealt", [mid(B, "t_pull"), plain])
	h["statuses"] = []
	put(h, "weakened")
	ok(near(mid(B, "t_pull"), plain * (1.0 - RpgDefs.PUMP)), "Weakened: -25% damage dealt")
	h["statuses"] = []
	put(f, "braced")
	ok(near(mid(B, "t_pull"), plain * (1.0 - RpgDefs.BRACE)), "Braced: -25% damage taken")
	put(f, "exposed")
	ok(not RpgBattle.has_status(f, "braced") and not RpgBattle.has_status(f, "exposed") and near(mid(B, "t_pull"), plain), "Exposed on a Braced unit: the pair cancels")
	put(f, "exposed")
	ok(near(mid(B, "t_pull"), plain * (1.0 + RpgDefs.BRACE)), "Exposed: +25% damage taken")
	put(f, "braced")
	ok(f.statuses.is_empty(), "Braced on an Exposed unit: the pair cancels")
	move(B, "k_pump")
	var ev = move(B, "k_weak_self")
	ok(not RpgBattle.has_status(h, "pumped") and not RpgBattle.has_status(h, "weakened") and first(ev, "status", "id", "weakened").get("cancel") == "pumped"
		and first(ev, "status", "id", "pumped").get("on") == false, "Weakened on a Pumped hero: both are gone, and the events say so", evs(ev, "status"))

	# durations: the unit's own turns, at the end of its turn
	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	f = B.foes[0]
	ev = move(B, "k_pump")
	ok(first(ev, "status", "id", "pumped").get("turns") == 2 and turns_of(h, "pumped") == 2, "a status put on in its own turn: that turn's end does not count", h.statuses)
	RpgBattle.act(B, GUARD)
	ok(turns_of(h, "pumped") == 1, "then one turn less at the end of each of its turns")
	ev = RpgBattle.act(B, GUARD)
	ok(turns_of(h, "pumped") == -1 and first(ev, "status", "id", "pumped").get("on") == false, "at 0 it is gone, with an event")
	move(B, "k_slow")
	RpgBattle.act(B, GUARD)
	RpgBattle.act(B, GUARD)
	ok(turns_of(f, "slowed") == 2, "the hero's turns do not run a foe's status down")
	foe_turn(B)
	ok(turns_of(f, "slowed") == 1, "its own turn does")
	move(B, "k_slow")
	ok(turns_of(f, "slowed") == 2, "the same status again refreshes the duration")
	foe_turn(B)
	foe_turn(B)
	ok(turns_of(f, "slowed") == -1, "and it runs out")
	var always = true
	for i in range(30):
		f["statuses"] = []
		move(B, "k_slow")
		if not RpgBattle.has_status(f, "slowed"):
			always = false
	ok(always, "a status with no chance given always lands")

	# the chance: base + 0.005 x (tec - res), between 15% and 95%
	var foe_res = RpgDefs.ref_stat(3.0)
	for c in [[30.0, 0.5 + 0.005 * (30.0 - foe_res)], [130.0, 0.95], [-170.0, 0.15]]:
		B = tough(begin(hero({"tec": c[0]}), [wave(["plain"])]))
		f = B.foes[0]
		var landed = 0
		for i in range(300):
			f["statuses"] = []
			move(B, "k_slow_half")
			if RpgBattle.has_status(f, "slowed"):
				landed += 1
		ok(absf(float(landed) / 300.0 - float(c[1])) < 0.08, "status chance with tec %d against res %d: about %d%%" % [int(c[0]), int(foe_res), int(round(float(c[1]) * 100.0))], landed)

	# Burn
	B = tough(begin(hero(), [wave(["scorcher"])]))
	h = B.hero
	foe_turn(B)
	var hp0 = int(h.hp)
	ok(turns_of(h, "burn") == 3 and hp0 == 399, "a foe's Burn lands on the hero", [h.statuses, hp0])
	ev = RpgBattle.act(B, GUARD)
	var tick = first(ev, "tick", "id", "burn")
	ok(tick.get("dst") == "hero" and tick.get("amount") == 24 and int(h.hp) == hp0 - 24 and turns_of(h, "burn") == 2, "Burn: 6% of max HP at the end of its turn", tick)
	RpgBattle.act(B, GUARD)
	RpgBattle.act(B, GUARD)
	ok(int(h.hp) == hp0 - 72 and not RpgBattle.has_status(h, "burn") and int(RpgBattle.summary(B).taken) == 400 - int(h.hp), "three turns, three ticks, all in the summary", h.hp)
	B = tough(begin(hero(), [wave(["plain"])]))
	f = B.foes[0]
	move(B, "k_burn")
	var want = maxi(1, int(floor(RpgDefs.BURN_FOE * RpgDefs.offence(30.0, W, 5) * RpgDefs.mitigation(float(f.def)))))
	ev = foe_turn(B)
	ok(first(ev, "tick", "dst", "f0").get("amount") == want and at_of(ev, "tick") > at_of(ev, "act", "who", "f0"), "Burn on a foe: half the applier's Mind offence, after its defence, at the end of its turn",
		[first(ev, "tick"), want])
	B = begin(hero(), [wave(["big"])])
	f = B.foes[0]
	move(B, "k_burn")
	ev = foe_turn(B)
	ok(first(ev, "tick", "dst", "f0").get("amount") == int(floor(RpgDefs.BOSS_DOT_CAP * float(f.hp_max))) and int(floor(RpgDefs.BOSS_DOT_CAP * float(f.hp_max))) < want,
		"a boss loses at most 3% of its max HP to a Burn tick", [first(ev, "tick"), f.hp_max])

	# Bleed
	B = tough(begin(hero(), [wave(["plain"])]))
	f = B.foes[0]
	move(B, "k_bleed")
	ok(stacks_of(f, "bleed") == 1, "Bleed: one stack")
	move(B, "k_bleed")
	move(B, "k_bleed")
	move(B, "k_bleed")
	ok(stacks_of(f, "bleed") == 3, "Bleed again adds a stack, up to 3")
	want = maxi(1, int(floor(RpgDefs.BLEED_FOE * RpgDefs.offence(30.0, W, 5) * 3.0 * RpgDefs.mitigation(float(f.def)))))
	ev = foe_turn(B)
	ok(first(ev, "tick", "id", "bleed").get("amount") == want, "Bleed on a foe: 0.3 x the applier's offence a stack", [first(ev, "tick", "id", "bleed"), want])
	B = tough(begin(hero(), [wave(["cutter"])]))
	h = B.hero
	foe_turn(B)
	ev = foe_turn(B)
	ok(first(ev, "tick", "id", "bleed").get("amount") == 12 and stacks_of(h, "bleed") == 2, "Bleed on the hero: 3% of max HP a stack", first(ev, "tick", "id", "bleed"))
	ev = RpgBattle.act(B, GUARD)
	ok(first(ev, "tick", "id", "bleed").get("amount") == 24, "two stacks, twice as much")

	# Stun on a foe
	B = tough(begin(hero(), [wave(["hitter"])]))
	f = B.foes[0]
	stun(B)
	f["hp"] = 500000
	put(f, "burn", 3, 1, 100.0)
	put(f, "regen", 3)
	ev = foe_turn(B)
	ok(first(ev, "act", "who", "f0").get("kind") == "lost" and evs(ev, "dmg", "dst", "hero").is_empty() and not RpgBattle.has_status(f, "stun")
		and int(f.stun_guard) == RpgDefs.STUN_IMMUNE, "Stunned: it loses its next action", kinds(ev))
	ok(first(ev, "heal", "dst", "f0").get("amount") == 60000 and first(ev, "tick", "dst", "f0").get("amount") == int(floor(100.0 * RpgDefs.mitigation(float(f.def))))
		and turns_of(f, "burn") == 2 and int(f.turns) == 1, "a lost turn is still a turn: Regen, Burn and durations run", [first(ev, "heal"), first(ev, "tick")])
	ev = move(B, "k_stun")
	ok(first(ev, "status", "id", "stun").get("resisted") == true and not RpgBattle.has_status(f, "stun"), "then it cannot be stunned for 2 of its turns")
	foe_turn(B)
	ok(int(f.stun_guard) == 1 and not RpgBattle.has_status(f, "stun"), "one turn of it gone")
	foe_turn(B)
	stun(B)
	ok(RpgBattle.has_status(f, "stun"), "after two of its turns it can be stunned again")
	put(f, "steady")
	f["statuses"] = f.statuses.filter(func(st): return st.id != "stun")
	f["stun_guard"] = 0
	ev = move(B, "k_stun")
	ok(first(ev, "status", "id", "stun").get("resisted") == true and not RpgBattle.has_status(f, "stun"), "Steady: cannot be stunned")

	# Stun on the hero: the lost turn is a turn
	B = tough(begin(hero(), [wave(["dazer"])]))
	h = B.hero
	move(B, "k_cd_cut")          # rests 3 turns: its cooldown is watched
	var c0 = 0
	var t0 = 0
	for i in range(8):
		c0 = int(h.cds.get("k_cd_cut", 0))
		t0 = int(h.turns)
		h["en"] = 0
		h["hp"] = 400
		put(h, "burn", 3)
		ev = foe_turn(B)
		if not evs(ev, "act", "kind", "lost").is_empty():
			break
	ok(first(ev, "act", "kind", "lost").get("who") == "hero" and int(h.turns) == t0 + 2 and int(RpgBattle.summary(B).turns) == int(h.turns), "the stunned hero loses a turn, and it counts as one",
		[kinds(ev), h.turns, t0])
	ok(int(h.en) == 4 and evs(ev, "tick", "id", "burn").size() == 2 and int(h.cds.get("k_cd_cut", 0)) == c0 - 2 and int(h.stun_guard) == RpgDefs.STUN_IMMUNE and not RpgBattle.has_status(h, "stun"),
		"in the lost turn: the energy, the Burn and the cooldowns run", [h.en, h.cds, c0])
	ev = foe_turn(B)
	ok(first(ev, "status", "id", "stun").get("resisted") == true and evs(ev, "act", "kind", "lost").is_empty(), "and the hero cannot be stunned again at once")

	# a boss is not stunned
	B = tough(begin(hero(), [wave(["big"])]))
	f = B.foes[0]
	var at1 = float(f.at)
	for i in range(12):
		ev = move(B, "k_stun")
		if not first(ev, "delay").is_empty():
			break
	ok(first(ev, "delay").get("stun") == true and not RpgBattle.has_status(f, "stun") and near(float(f.at), at1 + RpgDefs.BOSS_STUN_DELAY * RpgDefs.delay(1.0, float(f.spd)), 0.001)
		and int(f.stun_guard) == RpgDefs.STUN_IMMUNE and f.intent.kind != "stunned", "a boss is not stunned: it is pushed back 60% of a turn", [f.at, at1])
	at1 = float(f.at)
	ev = move(B, "k_stun")
	ok(first(ev, "status", "id", "stun").get("resisted") == true and float(f.at) == at1, "and not again for 2 of its turns")

	# Regen
	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	h["hp"] = 100
	put(h, "regen", 2)
	ev = RpgBattle.act(B, GUARD)
	ok(first(ev, "heal").get("amount") == 24 and int(h.hp) == 124 and at_of(ev, "heal") > at_of(ev, "turn", "who", "hero"), "Regen: 6% of max HP at the start of its turn", first(ev, "heal"))

	# Shield
	B = tough(begin(hero(), [wave(["hitter"])]))
	h = B.hero
	f = B.foes[0]
	f["crit"] = 0
	ev = move(B, "k_shield")
	var sh = int(round(0.2 * 400.0 * RpgDefs.heal_mult(30.0)))
	ok(first(ev, "status", "id", "shield").get("amount") == sh and RpgBattle._shield(h) == sh, "Shield: a share of max HP, by Flow", first(ev, "status", "id", "shield"))
	move(B, "k_shield_small")
	ok(RpgBattle._shield(h) == sh, "a new, smaller Shield: the larger is kept")
	for i in range(5):
		RpgBattle.act(B, GUARD)
	ok(RpgBattle._shield(h) == sh, "a Shield has no duration")
	ev = foe_turn(B, "f0", STRIKE)
	var d = first(ev, "dmg", "dst", "hero")
	ok(int(d.amount) == 0 and int(d.absorbed) > 0 and int(h.hp) == 400 and RpgBattle._shield(h) == sh - int(d.absorbed) and int(RpgBattle.summary(B).taken) == 0, "it absorbs the damage", d)
	RpgBattle.status_of(h, "shield")["amount"] = 5
	ev = foe_turn(B, "f0", STRIKE)
	d = first(ev, "dmg", "dst", "hero")
	ok(int(d.absorbed) == 5 and int(d.amount) > 0 and int(h.hp) == 400 - int(d.amount) and not RpgBattle.has_status(h, "shield") and first(ev, "status", "id", "shield").get("on") == false,
		"used up, it is gone and the rest gets through", d)

	# Focus
	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	move(B, "k_focus")
	ok(stacks_of(h, "focus") == 2 and float(RpgBattle.preview(B, {"t": "move", "id": "t_multi", "target": "f0"}).crit) == 1.0, "Focus: stacks, and the preview knows")
	ev = move(B, "t_multi")
	var hits = evs(ev, "dmg")
	ok(hits.map(func(e): return bool(e.crit)) == [true, true, false] and not RpgBattle.has_status(h, "focus") and near(float(hits[0].amount), RpgDefs.CRIT_MULT * float(hits[2].amount), 0.2),
		"Focus: a stack makes one hit a sure crit (x1.5)", hits.map(func(e): return [e.crit, e.amount]))
	move(B, "k_focus")
	move(B, "k_focus")
	ok(stacks_of(h, "focus") == 3, "Focus stacks to 3")

	# Evade
	B = tough(begin(hero(), [wave(["twicer"])]))
	h = B.hero
	f = B.foes[0]
	move(B, "k_evade")
	ok(stacks_of(h, "evade") == 2, "Evade: stacks")
	ev = foe_turn(B, "f0", STRIKE)
	ok(evs(ev, "miss", "dst", "hero").size() == 2 and evs(ev, "dmg", "dst", "hero").is_empty() and not RpgBattle.has_status(h, "evade"), "Evade: a stack dodges one hit", kinds(ev))
	put(f, "evade", 0, 1)
	ev = move(B, "k_slow")
	ok(first(ev, "miss").get("dst") == "f0" and evs(ev, "dmg").is_empty() and not RpgBattle.has_status(f, "slowed"), "a foe's Evade: the hit misses, and what rides on it does not land")
	ev = move(B, "k_slow")
	ok(RpgBattle.has_status(f, "slowed") and not first(ev, "dmg").is_empty(), "the next one lands")

	# Counter
	B = tough(begin(hero(), [wave(["twicer"])]))
	h = B.hero
	f = B.foes[0]
	f["crit"] = 0
	move(B, "k_counter")
	ev = foe_turn(B, "f0", STRIKE)
	var back = evs(ev, "dmg", "src", "hero").filter(func(e): return bool(e.get("counter", false)))
	var want_c = RpgBattle.offence_of(h, RpgBattle.strike_row()) * RpgDefs.mitigation(float(f.def))
	ok(back.size() == 1 and back[0].dst == "f0" and near(float(back[0].amount), want_c, 0.1) and evs(ev, "dmg", "dst", "hero").size() == 2,
		"Counter: hit by an attack, the hero strikes back once with its power", [back, want_c])
	h["statuses"] = []
	put(f, "counter", 3, 1, 1.0)
	ev = move(B, "t_multi")
	var fb = evs(ev, "dmg", "dst", "hero")
	ok(fb.size() == 1 and fb[0].get("counter") == true and not fb[0].crit and near(float(fb[0].amount), float(f.atk) * RpgDefs.mitigation(20.0), 0.12),
		"a foe's Counter strikes back once a move, however many hits", fb)
	ev = RpgBattle.act(B, GUARD)
	ok(evs(ev, "dmg").is_empty(), "nothing to counter when it is not hit")

	# Marked
	B = tough(begin(hero(), [wave(["dummy"])]))
	f = B.foes[0]
	plain = mid(B, "t_pull")
	ev = move(B, "k_mark")
	ok(stacks_of(f, "marked") == RpgDefs.MARKED_STACKS and first(ev, "status", "id", "marked").get("dst") == "f0", "Marked: 2 stacks on the target")
	ok(near(mid(B, "t_pull"), plain * RpgDefs.WEAK_MULT) and RpgBattle.preview(B, {"t": "move", "id": "t_pull", "target": "f0"}).weak, "a move on a Marked foe counts as weak, and the preview says so")
	ev = RpgBattle.act(B, STRIKE)
	ok(stacks_of(f, "marked") == 2 and not first(ev, "dmg").weak, "Strike is not a move: no stack is used")
	ev = move(B, "t_pull")
	d = first(ev, "dmg")
	ok(d.weak and int(d.chip) == 1 and evs(ev, "learn").is_empty() and stacks_of(f, "marked") == 1, "the marked hit is weak and chips, teaches nothing, uses one stack", d)
	ev = move(B, "t_mind")
	ok(first(ev, "dmg").weak and not first(ev, "dmg").resist and not RpgBattle.has_status(f, "marked"), "even a resisted school; after two moves the mark is gone")
	ev = move(B, "t_pull")
	ok(not first(ev, "dmg").weak, "and the next move is plain again")

	# a Stun taken off a foe: its intent says what it will do after all
	B = tough(begin(hero(), [wave(["curer", "hitter"])]))
	stun(B, "f1")
	ok(B.foes[1].intent.kind == "stunned", "the stunned foe shows it")
	ev = foe_turn(B, "f0")
	ok(not RpgBattle.has_status(B.foes[1], "stun") and B.foes[1].intent.move == "smack" and at_of(ev, "intent", "who", "f1") >= 0, "cleansed by an ally, it shows a move again", B.foes[1].intent)
	ev = foe_turn(B, "f1")
	ok(first(ev, "act", "who", "f1").get("kind") == "attack" and not evs(ev, "dmg", "dst", "hero").is_empty(), "and does it")

	# the hero's dodge; foes have none
	B = tough(begin(hero({"dodge": 1.0}), [wave(["twicer"])]))
	ev = foe_turn(B, "f0", STRIKE)
	ok(evs(ev, "miss", "dst", "hero").size() == 2 and evs(ev, "dmg", "dst", "hero").is_empty() and float(B.foes[0].dodge) == 0.0, "a hero who always dodges is never hit; a foe has no dodge")
	B = tough(begin(hero({"dodge": 0.2, "hp_max": 100000}), [wave(["hitter"])]))
	var slipped = 0
	for i in range(300):
		if not evs(foe_turn(B, "f0", STRIKE), "miss", "dst", "hero").is_empty():
			slipped += 1
	ok(slipped >= 36 and slipped <= 84, "a 20% dodge slips about one hit in five", slipped)

	# the rules that start the foes with a status
	B = begin(hero(), [wave(["dummy"])], {"rules": ["foes_hasted", "foes_braced"]})
	ok(turns_of(B.foes[0], "hasted") == RpgBattle.RULE_TURNS and RpgBattle.has_status(B.foes[0], "braced"), "the rules foes_hasted and foes_braced")


# =============================================================================
# 8.3: what foes do
# =============================================================================

func _foe_moves_and_phases() -> void:
	# a heal goes to the most hurt ally; with nobody hurt it is passed over
	var B = tough(begin(hero(), [wave(["medic", "dummy"])]))
	var f = B.foes[0]
	ok(f.intent.move == "poke", "a heal with nobody hurt is not chosen")
	B.foes[1]["hp"] = 400000
	foe_turn(B)
	ok(f.intent.move == "mend" and f.intent.kind == "heal" and int(f.intent.dmg) == 0 and f.intent.target == "ally" and f.intent.icon == "in_heal", "somebody is hurt: the heal is next", f.intent)
	var ev = foe_turn(B)
	ok(first(ev, "heal").get("dst") == "f1" and first(ev, "heal").get("amount") == 200000 and first(ev, "act", "who", "f0").get("target") == "f1", "a heal goes to the most hurt ally", first(ev, "heal"))
	B = tough(begin(hero(), [wave(["onlymend"])]))
	ok(B.foes[0].intent.move == "basic", "a foe with nothing it can use hits plainly")
	ev = foe_turn(B)
	ok(not evs(ev, "dmg", "dst", "hero").is_empty(), "and that is a hit")

	# buffs, shields, debuffs, a drain
	B = tough(begin(hero(), [wave(["cheerer", "dummy"])]))
	ev = foe_turn(B)
	ok(turns_of(B.foes[0], "pumped") == 2 and turns_of(B.foes[1], "pumped") == 2 and evs(ev, "status", "id", "pumped").size() == 2, "a buff for its allies lands on every foe")
	B = begin(hero(), [wave(["shieldy"])])
	f = B.foes[0]
	foe_turn(B)
	var sh = int(round(0.1 * float(f.hp_max)))
	ok(RpgBattle._shield(f) == sh, "a foe's Shield on itself", f.statuses)
	ev = move(B, "t_pull")
	var d = first(ev, "dmg")
	ok(int(d.absorbed) == sh and int(f.hp) == int(f.hp_max) - int(d.amount) and not RpgBattle.has_status(f, "shield"), "the hero's hit goes through it first", d)
	B = tough(begin(hero(), [wave(["sapper"])]))
	ev = foe_turn(B)
	ok(turns_of(B.hero, "weakened") == 2 and first(ev, "status", "id", "weakened").get("dst") == "hero", "a debuff rides on the hit")
	B = tough(begin(hero(), [wave(["hexer"])]))
	ev = foe_turn(B)
	ok(RpgBattle.has_status(B.hero, "exposed") and evs(ev, "dmg").is_empty() and int(B.foes[0].intent.dmg) == 0, "a move with no power is only its effect")
	B = tough(begin(hero(), [wave(["leecher"])]))
	f = B.foes[0]
	f["hp"] = 500000
	f["crit"] = 0
	B.hero["en"] = 5
	ev = foe_turn(B, "f0", STRIKE)
	d = first(ev, "dmg", "dst", "hero")
	ok(first(ev, "heal", "dst", "f0").get("amount") == int(d.amount) and int(B.hero.en) == 5 and first(ev, "act", "who", "f0").get("kind") == "drain", "a drain: it heals by what it dealt and takes energy",
		[d, first(ev, "heal"), B.hero.en])
	B = tough(begin(hero(), [wave(["shover"])]))
	ev = foe_turn(B)
	ok(first(ev, "delay").get("dst") == "hero", "a foe can push the hero's turn back")
	B = tough(begin(hero(), [wave(["hitter"])]))
	f = B.foes[0]
	f["crit"] = 1
	ev = foe_turn(B, "f0", STRIKE)
	d = first(ev, "dmg", "dst", "hero")
	ok(d.crit and near(float(d.amount), RpgDefs.FOE_CRIT_MULT * float(f.atk) * RpgDefs.mitigation(20.0), 0.12), "a foe's crit: x1.25", d)

	# summons: up to three, ids never reused
	B = tough(begin(hero(), [wave(["caller"])]))
	f = B.foes[0]
	ok(f.intent.move == "call" and f.intent.kind == "summon" and f.intent.icon == "in_summon", "a summon is shown")
	ev = foe_turn(B)
	var su = first(ev, "summon")
	ok(su.get("by") == "f0" and su.units.size() == 1 and su.units[0].id == "f1" and su.units[0].foe == "dummy" and RpgBattle.foes(B).size() == 2
		and at_of(ev, "intent", "who", "f1") > at_of(ev, "summon"), "a summon: a new foe with the next id, and its intent", kinds(ev))
	var lone_hp = int(begin(hero(), [wave(["dummy"])]).foes[0].hp_max)
	ok(near(float(B.foes[1].hp_max), float(lone_hp) * RpgDefs.ADD_MULT, 0.01) and int(B.foes[1].slot) == 1 and float(B.foes[1].at) > float(B.now), "the add has half the numbers and the next place")
	foe_turn(B)
	foe_turn(B)
	ok(RpgBattle.foes(B).size() == 3 and B.foes[2].id == "f2", "a second one")
	foe_turn(B)
	ok(f.intent.move == "poke", "with three foes standing a summon is not chosen", f.intent)
	foe_turn(B)
	ok(RpgBattle.foes(B).size() == 3 and f.intent.move == "poke", "nor the next time")
	B.foes[1]["hp"] = 1
	move(B, "t_pull", "f1")
	foe_turn(B)
	ok(f.intent.move == "call", "a place is free again")
	ev = foe_turn(B)
	ok(first(ev, "summon").units[0].id == "f3" and int(RpgBattle.unit(B, "f3").slot) == 1 and int(B.next_id) == 4 and RpgBattle.options(B).targets == ["f0", "f2", "f3"],
		"ids run on and are never reused; the free place is filled", RpgBattle.options(B).targets)

	# rules: looked at before the pattern
	B = tough(begin(hero(), [wave(["ruler", "dummy"])]))
	f = B.foes[0]
	ok(not RpgAi.holds(B, f, {"if": "hp_below", "v": 0.5}) and not RpgAi.holds(B, f, {"if": "ally_hurt", "v": 0.5}), "rules: nobody is hurt")
	B.foes[1]["hp"] = 400000
	ok(RpgAi.holds(B, f, {"if": "ally_hurt", "v": 0.5}) and not RpgAi.holds(B, f, {"if": "hp_below", "v": 0.5}), "rule ally_hurt")
	f["hp"] = 400000
	ok(RpgAi.holds(B, f, {"if": "hp_below", "v": 0.5}), "rule hp_below")
	ok(not RpgAi.holds(B, f, {"if": "turn_mod", "v": 3}) and RpgAi.holds(B, f, {"if": "turn_mod", "v": [3, 1]}), "rule turn_mod: its first turn is 1")
	f["turns"] = 2
	ok(RpgAi.holds(B, f, {"if": "turn_mod", "v": 3}) and not RpgAi.holds(B, f, {"if": "turn_mod", "v": [3, 1]}), "rule turn_mod: every third turn")
	ok(not RpgAi.holds(B, f, {"if": "alone"}) and not RpgAi.holds(B, f, {"if": "hero_has", "v": "weakened"}) and RpgAi.holds(B, f, {"if": "self_lacks", "v": "pumped"}), "rules alone, hero_has, self_lacks: not yet")
	B.foes[1]["alive"] = false
	put(B.hero, "weakened")
	put(f, "pumped")
	ok(RpgAi.holds(B, f, {"if": "alone"}) and RpgAi.holds(B, f, {"if": "hero_has", "v": "weakened"}) and not RpgAi.holds(B, f, {"if": "self_lacks", "v": "pumped"}), "rules alone, hero_has, self_lacks")
	B = tough(begin(hero(), [wave(["ruler"])], {"custom": custom_rules("ruler", [{"if": "hp_below", "v": 0.5, "use": "rage", "once": true}, {"if": "turn_mod", "v": 3, "use": "smack"}])}))
	f = B.foes[0]
	var seq = []
	for i in range(7):
		if i == 1:
			f["hp"] = 400000
		seq.append(first(foe_turn(B), "act", "who", "f0").get("id"))
	ok(seq == ["poke", "slap", "rage", "poke", "slap", "smack", "poke"], "rules come before the pattern, a once rule only once, the pattern goes on where it was", seq)

	# boss phases
	B = begin(hero(), [wave(["big"])])
	f = B.foes[0]
	f["hp_max"] = 100000
	f["hp"] = 50200
	ev = move(B, "t_push")
	var ph = first(ev, "phase")
	ok(first(ev, "learn").get("key") == "big" and ph.get("who") == "f0" and ph.get("say") == "Phase two!" and ph.get("phase") == 2 and int(f.phase) == 1, "a boss enters its phase at the mark", ph)
	ok(f.pattern == ["slap"] and f.weak == ["pull", "grip"] and f.resist.is_empty() and RpgBattle.has_status(f, "pumped") and f.intent.move == "slap" and int(f.guard) == int(f.guard_max),
		"the phase: a new pattern and new weaknesses, its effects, the guard whole, a new intent", [f.pattern, f.weak, f.guard])
	ok(first(ev, "summon").get("by") == "f0" and RpgBattle.foes(B).size() == 2 and at_of(ev, "phase") < at_of(ev, "summon"), "and its adds")
	ok(RpgBattle.seen_key(f) == "big#2" and RpgBattle.known(B, "f0").weak.is_empty(), "the second phase's weaknesses are a secret of their own")
	ev = move(B, "t_pull")
	ok(first(ev, "learn") == {"t": "learn", "key": "big#2", "school": "pull"} and RpgBattle.summary(B).learned == {"big": ["push"], "big#2": ["pull"]}, "learned under the phase's own key", RpgBattle.summary(B).learned)
	ev = move(B, "t_push")
	ok(not first(ev, "dmg").weak and evs(ev, "phase").is_empty(), "a phase is entered once; the old weakness is gone")

	# traits: quicken, adapt
	B = tough(begin(hero(), [wave(["quick"])]))
	f = B.foes[0]
	var spd0 = RpgBattle.speed_of(f)
	foe_turn(B)
	ok(near(RpgBattle.speed_of(f), spd0 * 1.2), "quicken: faster after each of its actions", [RpgBattle.speed_of(f), spd0])
	foe_turn(B)
	foe_turn(B)
	ok(near(RpgBattle.speed_of(f), spd0 * 1.4), "up to its most")
	B = tough(begin(hero(), [wave(["adapter"])]))
	f = B.foes[0]
	ev = move(B, "t_push")
	ok(first(ev, "dmg").weak and first(ev, "adapt").get("school") == "push" and f.resist == ["push"], "adapt: it takes on a resistance to the school that hit it", f.resist)
	ev = move(B, "t_push")
	d = first(ev, "dmg")
	ok(d.resist and not d.weak and int(d.chip) == 0 and RpgBattle.known(B, "f0").resist == ["push"] and RpgBattle.known(B, "f0").weak.is_empty() and evs(ev, "adapt").is_empty(),
		"the same school again is resisted, and shown as such", [d, RpgBattle.known(B, "f0")])
	move(B, "t_pull")
	ev = move(B, "t_push")
	ok(f.resist == ["push"] and first(ev, "dmg").weak, "after another school the first one is weak again", f.resist)
	ev = RpgBattle.act(B, STRIKE)
	ok(evs(ev, "adapt").is_empty() and f.resist == ["push"], "Strike and the support schools change nothing")


# =============================================================================
# 4.8, 4.9: waves, winning, losing
# =============================================================================

func _waves_and_endings() -> void:
	var B = tough(begin(hero(), [wave(["plain"]), wave(["dummy", "plain"])]))
	var h = B.hero
	h["hp"] = 200
	put(h, "pumped", 5)
	put(h, "burn", 5)
	move(B, "t_cost")
	h["gauge"] = 50
	B.foes[0]["hp"] = 1
	var en0 = int(h.en)
	var hp0 = int(h.hp)
	var ev = move(B, "t_pull")
	var w = first(ev, "wave")
	ok(w.get("n") == 2 and w.get("of") == 2 and w.units.map(func(u): return u.id) == ["f1", "f2"] and at_of(ev, "ko") < at_of(ev, "wave") and int(B.wave) == 1 and B.foes.size() == 2
		and RpgBattle.options(B).targets == ["f1", "f2"], "the next wave stands up: new foes, ids that run on", kinds(ev))
	ok(first(ev, "heal").get("amount") == int(round(RpgDefs.wave_heal(30.0) * 400.0)) and int(h.hp) == hp0 + 70 and at_of(ev, "heal") > at_of(ev, "wave"), "between waves the hero heals (10 + flow / 4)%", first(ev, "heal"))
	ok(h.statuses.is_empty() and evs(ev, "tick").is_empty(), "statuses are cleared between waves", h.statuses)
	var cd = RpgBattle.options(B).moves.filter(func(m): return m.id == "t_cost")[0].cd
	ok(int(h.en) == en0 + 1 and near(float(h.gauge), 50.0 + RpgDefs.GAUGE_ACT * RpgDefs.gauge_mult(30.0), 0.002) and int(cd) == 1, "energy, gauge and cooldowns carry over", [h.en, h.gauge, cd])
	ok(float(B.foes[0].at) > float(B.now) and evs(ev, "intent").size() >= 2 and int(RpgBattle.summary(B).waves) == 1 and not RpgBattle.over(B), "the new foes wait their turn and show their intents")
	B.foes[0]["hp"] = 1
	B.foes[1]["hp"] = 1
	ev = move(B, "t_all")
	var sum = RpgBattle.summary(B)
	ok(ev[-1] == {"t": "end", "win": true} and evs(ev, "ko").size() == 2 and RpgBattle.over(B) and RpgBattle.won(B) and sum.win and int(sum.kos) == 3 and int(sum.waves) == 2
		and int(sum.turns) == int(h.turns) and near(float(sum.hp_share), float(h.hp) / 400.0, 0.001) and not sum.fled, "all foes of the last wave down: a win, and its summary", sum)
	ok(RpgBattle.act(B, STRIKE) == [{"t": "no", "why": "over"}] and RpgBattle.options(B).targets.is_empty() and not RpgBattle.options(B).strike and RpgBattle.timeline(B, 5).is_empty(), "nothing more can be done")

	# a target that falls in the middle of a move: the rest goes to the first living foe
	B = tough(begin(hero(), [wave(["plain", "dummy"])]))
	B.foes[0]["hp"] = 1
	ev = move(B, "t_multi", "f0")
	ok(evs(ev, "dmg").map(func(e): return e.dst) == ["f0", "f1", "f1"] and not RpgBattle.over(B), "a target that falls in the middle of a move: the other hits go to the first living foe")
	B = tough(begin(hero(), [wave(["plain", "dummy"])]))
	B.foes[0]["hp"] = 1
	B.foes[1]["hp"] = 1
	ev = move(B, "t_random")
	ok(evs(ev, "dmg").size() == 2 and RpgBattle.won(B), "hits on random foes stop when nobody stands")
	ok(RpgBattle.act(B, {}) == [{"t": "no", "why": "over"}] and RpgBattle.act(tough(begin(hero(), [wave(["plain"])])), {"t": "dance"}) == [{"t": "no", "why": "unknown"}], "an action nobody knows is turned down")

	# a loss; survive
	B = begin(hero(), [wave(["killer"])])
	ev = foe_turn(B)
	sum = RpgBattle.summary(B)
	ok(not first(ev, "ko", "dst", "hero").is_empty() and ev[-1] == {"t": "end", "win": false} and RpgBattle.over(B) and not RpgBattle.won(B) and int(B.hero.hp) == 0
		and float(sum.hp_share) == 0.0 and near(float(sum.worst_share), 1.0) and int(sum.taken) == 400, "hero HP 0: a loss", sum)
	B = begin(hero({}, [{"p": "survive", "pct": 0.0}]), [wave(["killer"])])
	ev = foe_turn(B)
	ok(first(ev, "survive") == {"t": "survive", "dst": "hero", "hp": 1} and int(B.hero.hp) == 1 and not RpgBattle.over(B), "survive: a lethal blow leaves 1 HP", first(ev, "survive"))
	ev = foe_turn(B)
	ok(RpgBattle.over(B) and not RpgBattle.won(B) and evs(ev, "survive").is_empty(), "once a battle")
	B = begin(hero({}, [{"p": "survive", "pct": 0.3}]), [wave(["killer"])])
	foe_turn(B)
	ok(int(B.hero.hp) == 120, "survive at a share of max HP", B.hero.hp)
	B = tough(begin(hero(), [wave(["diehard"])]))
	B.foes[0]["hp"] = 1
	ev = move(B, "t_pull")
	ok(int(B.foes[0].hp) == 500000 and first(ev, "survive").get("dst") == "f0" and not RpgBattle.over(B), "a foe may have it too; it stands at that share even if it had less", B.foes[0].hp)
	B = begin(hero({}, [{"p": "survive", "pct": 0.3}]), [wave(["plain"])])
	B.hero["hp"] = 10
	put(B.hero, "burn", 3)
	ev = RpgBattle.act(B, GUARD)
	ok(int(B.hero.hp) == 120 and first(ev, "survive").get("hp") == 120 and not RpgBattle.over(B), "survive also holds against a Burn", kinds(ev))

	# a win is checked first
	B = begin(hero(), [wave(["nuker"])])
	ev = foe_turn(B)
	ok(at_of(ev, "ko", "dst", "hero") >= 0 and at_of(ev, "ko", "dst", "f0") > at_of(ev, "ko", "dst", "hero") and ev[-1] == {"t": "end", "win": true} and RpgBattle.won(B),
		"a win is checked first: the last foe down wins even if the hero fell in the same action", kinds(ev))
	B = begin(hero(), [wave(["nuker"]), wave(["dummy"])])
	ev = foe_turn(B)
	ok(ev[-1] == {"t": "end", "win": false} and int(B.wave) == 0 and evs(ev, "wave").is_empty(), "but not with a wave still to come", kinds(ev))

	# burn: the hero's own, a foe's own
	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	h["hp"] = 10
	put(h, "burn", 3)
	ev = RpgBattle.act(B, GUARD)
	ok(first(ev, "tick").get("amount") == 10 and at_of(ev, "ko", "dst", "hero") > at_of(ev, "tick") and ev[-1] == {"t": "end", "win": false}, "the hero's own Burn can end the battle", kinds(ev))
	B = begin(hero(), [wave(["plain"])])
	h = B.hero
	h["hp"] = 10
	put(h, "burn", 3)
	B.foes[0]["hp"] = 1
	ev = move(B, "t_pull")
	ok(RpgBattle.won(B) and evs(ev, "tick").is_empty() and int(h.hp) == 10, "the last foe down wins before the hero's turn ends")
	B = begin(hero({}, [{"p": "on", "ev": "kill", "do": {"k": "energy", "n": 2}}]), [wave(["plain"])])
	move(B, "k_burn")
	B.foes[0]["hp"] = 50
	ev = foe_turn(B)
	var ti = at_of(ev, "tick", "dst", "f0")
	ok(ti >= 0 and ev.size() == ti + 3 and ev[ti + 1] == {"t": "ko", "dst": "f0"} and ev[ti + 2] == {"t": "end", "win": true} and int(RpgBattle.summary(B).kos) == 1,
		"a foe killed by its own Burn: tick, ko; no energy, no gauge, no 'on kill'; it still counts", kinds(ev))

	# what a setup may ask for
	B = begin(hero(), [wave(["dummy"])], {"rules": ["low_energy"]})
	ok(int(B.hero.en) == 1 + RpgDefs.EN_TURN, "the rule low_energy: 1 energy to start with")
	B = begin(hero(), [wave(["dummy", "captain"])], {"rules": ["extra_wave"]})
	ok(B.waves.size() == 2 and B.waves[0].size() == 1 and B.waves[0][0].foe == "dummy" and RpgBattle.foes(B).size() == 1 and first(RpgBattle.opening(B), "wave").get("of") == 2,
		"the rule extra_wave: the first wave's regular foes stand in front of it")
	var lone = begin(hero(), [wave(["dummy"])]).foes[0]
	B = begin(hero(), [[{"foe": "dummy", "n": 20.0, "mult": 2.0, "guard_add": 1, "start": [{"id": "shield", "amount": 50}, {"id": "braced", "turns": 2}]}]])
	var f = B.foes[0]
	ok(near(float(f.hp_max), 2.0 * float(lone.hp_max), 0.01) and near(float(f.atk), 2.0 * float(lone.atk)) and int(f.guard) == 4 and RpgBattle._shield(f) == 50 and turns_of(f, "braced") == 2,
		"a wave entry: its own share, more guard, statuses to start with", [f.hp_max, f.guard, f.statuses])
	B = begin(hero(), [])
	ok(RpgBattle.over(B) and RpgBattle.won(B), "no waves: nothing to fight")
	B = begin(hero(), [wave(["nobody"]), wave(["dummy"])])
	ok(not RpgBattle.over(B) and RpgBattle.foes(B).size() == 1 and int(B.wave) == 1, "a wave of foes nobody knows is passed over")
	ok(RpgBattle.json_safe(B) == "" and RpgBattle.json_safe({"a": [1.5, {"b": 0.1234567}]}) != "" and RpgBattle.json_safe({"a": Vector2.ZERO}) != "", "json_safe tells a settled battle from one that is not")

	# a broken catalog cannot hang the game
	B = begin(hero({"hp_max": 100000}), [wave(["staller"])])
	ev = foe_turn(B)
	ok(RpgBattle.over(B) and not RpgBattle.won(B) and not first(ev, "say").is_empty() and evs(ev, "turn", "who", "f0").size() <= 500, "a move that takes no time cannot hang the game: the fight breaks off",
		ev.size())


# =============================================================================
# 4.7: the companion
# =============================================================================

func _companion() -> void:
	var pet = {"pet": "t_biter", "rarity": "rare", "name": "Biter"}
	var B = tough(begin(hero(), [wave(["dummy"])], {"pet": pet}))
	var h = B.hero
	var p = B.pet
	var f = B.foes[0]
	ok(str(p.id) == "pet" and near(float(p.atk), RpgDefs.offence(15.0, 0.0, 5) * 1.2) and near(float(p.spd), RpgDefs.PET_SPD + 2.0 * float(RpgDefs.tier_of_level(5)))
		and int(p.charge) == 0 and int(p.charge_max) == 2, "the companion: half the hero's best body stat, its rarity, speed 34 + 2 a tier, the charges its kit asks for", [p.atk, p.spd, p.charge_max])
	ok(RpgBattle.timeline(B, 60).has("pet") and RpgBattle.unit(B, "pet") == p and not RpgBattle.options(B).targets.has("pet"), "it has a place on the timeline and is not a target")
	var o = RpgBattle.options(B).pet
	ok(not o.ok and o.name == "Maul" and int(o.charge) == 0 and int(o.max) == 2 and RpgBattle.act(B, {"t": "pet", "target": "f0"}) == [{"t": "no", "why": "pet"}], "not charged: no command", o)
	soon(B, "pet")
	var ev = RpgBattle.act(B, GUARD)
	var d = first(ev, "dmg", "src", "pet")
	ok(first(ev, "act", "who", "pet").get("kind") == "auto" and first(ev, "act", "who", "pet").get("name") == "Nip" and not d.weak and not d.crit and int(d.chip) == 0 and int(f.guard) == 3
		and near(float(d.amount), 0.5 * float(p.atk) * RpgDefs.mitigation(float(f.def)), 0.1) and first(ev, "charge").get("v") == 1,
		"its turn: its own action (never weak, never a crit, never a chip) and one charge", [d, kinds(ev)])
	soon(B, "pet")
	RpgBattle.act(B, GUARD)
	o = RpgBattle.options(B).pet
	ok(o.ok and int(o.charge) == 2, "charged")
	soon(B, "pet")
	ev = RpgBattle.act(B, GUARD)
	ok(int(p.charge) == 2 and evs(ev, "charge").is_empty(), "it never holds more charges than its command asks for")
	var at0 = float(h.at)
	var turns0 = int(h.turns)
	var en0 = int(h.en)
	var pvp = RpgBattle.preview(B, {"t": "pet", "target": "f0"})
	ev = RpgBattle.act(B, {"t": "pet", "target": "f0"})
	d = first(ev, "dmg", "src", "pet")
	ok(first(ev, "act").get("kind") == "command" and int(d.amount) >= int(pvp.lo) and int(d.amount) <= int(pvp.hi) and RpgBattle.has_status(f, "exposed") and first(ev, "charge").get("v") == 0
		and int(p.charge) == 0, "the command: its hit (as previewed), its effect, the charges are spent", [d, pvp])
	ok(bool(B.wait) and float(h.at) == at0 and int(h.turns) == turns0 and int(h.en) == en0 and RpgBattle.options(B).strike and evs(ev, "turn").is_empty(), "the command is free: the hero's turn goes on")
	ok(RpgBattle.act(B, {"t": "pet"}) == [{"t": "no", "why": "pet"}] and RpgBattle.summary(B).schools.is_empty() and RpgBattle.json_safe(B) == "", "once; and its school is not in the summary")

	# a tie on the timeline: the hero, the companion, then the foes in their order
	B = tough(begin(hero(), [wave(["dummy", "plain"])], {"pet": pet}))
	B.pet["at"] = float(B.now)
	B.foes[1]["at"] = float(B.now)
	B.foes[0]["at"] = float(B.now)
	ev = RpgBattle.timeline(B, 4)
	ok(ev == ["hero", "pet", "f0", "f1"], "all due at once: the timeline says hero, companion, foes in order", ev)
	ev = RpgBattle.act(B, GUARD)
	ok(evs(ev, "turn").map(func(e): return e.who).slice(0, 4) == ["pet", "f0", "f1", "hero"], "and that is the order they act in", evs(ev, "turn").map(func(e): return e.who))

	# a support companion: its "self" is the hero
	B = tough(begin(hero(), [wave(["dummy"])], {"pet": {"pet": "t_nurse", "rarity": "common"}}))
	h = B.hero
	h["hp"] = 100
	soon(B, "pet")
	ev = RpgBattle.act(B, GUARD)
	ok(evs(ev, "act", "who", "pet").is_empty() and first(ev, "charge").get("v") == 1, "every 2: nothing on its first turn (it still charges)", kinds(ev))
	soon(B, "pet")
	ev = RpgBattle.act(B, GUARD)
	ok(first(ev, "heal").get("dst") == "hero" and first(ev, "heal").get("amount") == int(round(0.05 * 400.0 * RpgDefs.heal_mult(30.0))), "a support action heals the hero, by the hero's Flow", first(ev, "heal"))
	ev = RpgBattle.act(B, {"t": "pet"})
	ok(not first(ev, "heal").is_empty() and RpgBattle.has_status(h, "braced") and evs(ev, "dmg").is_empty(), "a command on the hero's side")

	# none; and a companion's kill
	B = begin(hero(), [wave(["dummy"])])
	ok(B.pet == null and not RpgBattle.timeline(B, 30).has("pet") and RpgBattle.options(B).pet == {"ok": false, "name": "", "charge": 0, "max": 0}
		and RpgBattle.act(B, {"t": "pet"}) == [{"t": "no", "why": "unknown"}], "no companion: no place on the timeline, the key is off")
	B = begin(hero(), [wave(["dummy"])], {"pet": pet})
	B.pet["charge"] = 2
	B.foes[0]["hp"] = 1
	ev = RpgBattle.act(B, {"t": "pet", "target": "f0"})
	ok(RpgBattle.won(B) and ev[-1] == {"t": "end", "win": true}, "the companion's hit can win the battle")


# =============================================================================
# 5: every mod of a move
# =============================================================================

func _mods() -> void:
	var B = tough(begin(hero(), [wave(["plain"])]))
	var h = B.hero
	var f = B.foes[0]
	var plain = mid(B, "t_pull")
	ok(near(mid(B, "m_vs_status"), plain) and near(mid(B, "m_vs_debuff"), plain) and near(mid(B, "m_per_debuff"), plain), "mods that ask for a status do nothing without it")
	put(f, "slowed")
	ok(near(mid(B, "m_vs_status"), plain * 1.5), "vs_status: +50% against a Slowed foe", mid(B, "m_vs_status") / plain)
	ok(near(mid(B, "m_vs_debuff"), plain * 1.4), "vs_debuff: +40% against any debuff")
	ok(near(mid(B, "m_per_debuff"), plain * 1.25), "per_debuff: +25% for one")
	put(f, "weakened")
	put(f, "burn", 3, 1, 1.0)
	ok(near(mid(B, "m_per_debuff"), plain * 1.5), "per_debuff: up to its max", mid(B, "m_per_debuff") / plain)
	ok(near(mid(B, "m_two"), plain * 2.0), "mods add up (+40% and +60% are +100%)", mid(B, "m_two") / plain)
	f["statuses"] = []
	f["broken"] = true
	ok(near(mid(B, "m_vs_broken"), plain * RpgDefs.BROKEN_MULT * 1.5), "vs_broken: +50% on top of what a Broken foe takes", mid(B, "m_vs_broken") / plain)
	f["broken"] = false
	ok(near(mid(B, "m_vs_broken"), plain), "and nothing otherwise")
	ok(near(mid(B, "m_vs_full_hp"), plain * 1.6), "vs_full_hp: +60% on a foe at full HP")
	f["hp"] = int(f.hp_max) - 1
	ok(near(mid(B, "m_vs_full_hp"), plain), "not when it is hurt")
	f["hp"] = 360000
	ok(near(mid(B, "m_execute"), plain), "execute: nothing above its mark")
	f["hp"] = 340000
	ok(near(mid(B, "m_execute"), plain * 2.0), "execute: x2 under 35%")
	ok(near(mid(B, "m_ignore_def"), plain * RpgDefs.mitigation(0.5 * float(f.def)) / RpgDefs.mitigation(float(f.def))), "ignore_def: half the defence is not counted")
	var pv = RpgBattle.preview(B, {"t": "move", "id": "m_crit", "target": "f0"})
	var ev = move(B, "m_crit")
	ok(float(pv.crit) == 1.0 and first(ev, "dmg").crit and near(float(first(ev, "dmg").amount), plain * RpgDefs.CRIT_MULT, 0.1), "crit: chance added for this move; a crit is x1.5", [pv, first(ev, "dmg")])
	ev = move(B, "m_sure_crit")
	ok(near(mid(B, "m_sure_crit"), plain * RpgDefs.CRIT_MULT) and first(ev, "dmg").crit, "sure_crit: every hit, and the preview counts it")
	var none = true
	for i in range(20):
		if first(move(B, "t_pull"), "dmg").crit:
			none = false
	ok(none, "a hero with no crit chance never crits")
	h["hp"] = 200
	ok(near(mid(B, "m_missing_hp"), plain * 1.25), "missing_hp: its share of the HP the hero has lost", mid(B, "m_missing_hp") / plain)

	B = tough(begin(hero(), [wave(["plain"])]))
	var seen = []
	for i in range(4):
		seen.append(mid(B, "m_ramp_use") / plain)
		move(B, "m_ramp_use")
	ok(near(seen[0], 1.0) and near(seen[1], 1.2) and near(seen[2], 1.4) and near(seen[3], 1.4), "ramp_use: per earlier use this battle, up to its max", seen)
	B = tough(begin(hero(), [wave(["plain"])]))
	seen = []
	for i in range(4):
		seen.append(mid(B, "m_ramp_turn") / plain)
		RpgBattle.act(B, GUARD)
	ok(near(seen[0], 1.0) and near(seen[1], 1.15) and near(seen[2], 1.3) and near(seen[3], 1.3), "ramp_turn: per hero turn of the battle", seen)
	B = tough(begin(hero(), [wave(["plain"])]))
	seen = [mid(B, "m_streak") / plain]
	move(B, "t_pull")
	seen.append(mid(B, "m_streak") / plain)
	RpgBattle.act(B, STRIKE)
	seen.append(mid(B, "m_streak") / plain)
	move(B, "t_pull")
	seen.append(mid(B, "m_streak") / plain)
	ok(near(seen[0], 1.0) and near(seen[1], 1.1) and near(seen[2], 1.2) and near(seen[3], 1.2), "streak: per attacking turn in a row (Strike counts)", seen)
	RpgBattle.act(B, GUARD)
	ok(near(mid(B, "m_streak"), plain), "a turn without an attack ends the streak")
	move(B, "t_pull")
	move(B, "k_heal")
	ok(near(mid(B, "m_streak"), plain), "so does a support move")


# =============================================================================
# 5: every effect
# =============================================================================

func _effects() -> void:
	var B = tough(begin(hero(), [wave(["plain", "dummy"])]))
	var h = B.hero
	var f = B.foes[0]
	var ev = move(B, "k_slow")
	ok(RpgBattle.has_status(f, "slowed") and not RpgBattle.has_status(B.foes[1], "slowed") and not RpgBattle.has_status(h, "slowed") and at_of(ev, "status") > at_of(ev, "dmg"),
		"status: on an attack it lands on the target, after the damage")
	move(B, "k_weak_self")
	ok(turns_of(h, "weakened") == 1 and not RpgBattle.has_status(f, "weakened"), "status to self")
	move(B, "k_expose_all")
	ok(RpgBattle.has_status(f, "exposed") and RpgBattle.has_status(B.foes[1], "exposed"), "status to all_foes")
	move(B, "k_pump")
	ok(RpgBattle.has_status(h, "pumped") and not RpgBattle.has_status(f, "pumped"), "status: on a support move it lands on the hero")
	h["hp"] = 100
	ev = move(B, "k_heal")
	ok(first(ev, "heal").get("amount") == int(round(0.2 * 400.0 * RpgDefs.heal_mult(30.0))) and int(h.hp) == 204, "heal: a share of max HP times (1 + flow / 100)", first(ev, "heal"))
	h["hp"] = 390
	ev = move(B, "k_heal")
	ok(first(ev, "heal").get("amount") == 10 and int(h.hp) == 400, "never past max HP")
	h["en"] = 1
	ev = move(B, "k_energy")
	ok(first(ev, "energy").get("v") == 3, "energy: +n")
	h["en"] = 0
	ev = move(B, "k_energy_full")
	ok(first(ev, "energy").get("v") == int(h.en_max), "energy 99: full")
	h["gauge"] = 10
	move(B, "k_gauge")
	ok(float(h.gauge) == 40.0, "gauge: as written, no multiplier", h.gauge)
	h["gauge"] = 90
	move(B, "k_gauge")
	ok(float(h.gauge) == 100.0, "clamped at 100")
	var at0 = float(f.at)
	ev = move(B, "k_delay")
	ok(near(float(f.at), at0 + 0.5 * RpgDefs.delay(1.0, RpgBattle.speed_of(f)), 0.001) and first(ev, "delay").get("dst") == "f0", "delay: a share of the target's rank-1 delay", [f.at, at0])

	h["statuses"] = []
	put(h, "weakened", 9)
	put(h, "burn", 9)
	put(h, "slowed", 9)
	put(h, "regen", 9)
	move(B, "k_cleanse_1")
	ok(not RpgBattle.has_status(h, "weakened") and RpgBattle.has_status(h, "burn") and RpgBattle.has_status(h, "slowed") and RpgBattle.has_status(h, "regen"), "cleanse 1: the oldest debuff")
	move(B, "k_cleanse_ids")
	ok(not RpgBattle.has_status(h, "burn") and RpgBattle.has_status(h, "slowed"), "cleanse by id")
	put(h, "exposed", 9)
	move(B, "k_cleanse_all")
	ok(RpgBattle.debuffs(h) == 0 and RpgBattle.has_status(h, "regen"), "cleanse 0: every debuff, no buff")
	f["statuses"] = []
	put(f, "pumped", 9)
	put(f, "braced", 9)
	put(f, "slowed", 9)
	move(B, "k_dispel")
	ok(not RpgBattle.has_status(f, "pumped") and RpgBattle.has_status(f, "braced") and RpgBattle.has_status(f, "slowed"), "dispel 1: the target's oldest buff")
	put(f, "regen", 9)
	move(B, "k_dispel_all")
	ok(f.statuses.size() == 1 and RpgBattle.has_status(f, "slowed"), "dispel 0: every buff, no debuff", f.statuses)

	h["statuses"] = []
	h["hp"] = 400
	h["en"] = 2
	var taken0 = int(RpgBattle.summary(B).taken)
	ev = move(B, "k_hp_cost")
	ok(first(ev, "tick", "id", "hp_cost").get("amount") == 80 and int(h.hp) == 320 and at_of(ev, "tick") < at_of(ev, "energy") and int(RpgBattle.summary(B).taken) == taken0,
		"hp_cost: a share of current HP; effects happen in the order written", kinds(ev))
	h["hp"] = 1
	ev = move(B, "k_hp_cost")
	ok(evs(ev, "tick").is_empty() and int(h.hp) == 1 and not RpgBattle.over(B), "hp_cost never takes the last HP")
	h["hp"] = 100
	ev = move(B, "k_lifesteal")
	ok(first(ev, "heal").get("amount") == int(round(0.5 * float(first(ev, "dmg").amount))), "lifesteal: a share of the damage dealt", [first(ev, "heal"), first(ev, "dmg")])
	h["en"] = 5
	move(B, "k_refund")
	ok(int(h.en) == 4, "refund: nothing without a kill", h.en)
	h["en"] = 5
	f["hp"] = 1
	ev = move(B, "k_refund")
	ok(int(h.en) == 6 and not first(ev, "ko").is_empty(), "refund: +n energy when the move kills", h.en)

	B = tough(begin(hero(), [wave(["plain"])]))
	h = B.hero
	move(B, "t_cost")
	move(B, "k_cd_cut")
	var cds = {}
	for m in RpgBattle.options(B).moves:
		cds[m.id] = int(m.cd)
	ok(cds["t_cost"] == 0 and cds["k_cd_cut"] == 3, "cd_cut: the other cooldowns go down, not its own", [cds["t_cost"], cds["k_cd_cut"]])
	h["hp"] = 400
	ev = move(B, "k_when")
	ok(evs(ev, "heal").is_empty(), "when: not above its mark")
	h["hp"] = 100
	ev = move(B, "k_when")
	ok(first(ev, "heal").get("amount") == int(round(0.1 * 400.0 * RpgDefs.heal_mult(30.0))), "when: under its mark the effect happens")

	B = tough(begin(hero(), [wave(["hitter"])]))
	h = B.hero
	var at1 = float(h.at)
	var t1 = int(h.turns)
	soon(B)
	ev = move(B, "k_extra")
	ok(float(h.at) == at1 and int(h.turns) == t1 + 1 and evs(ev, "turn", "who", "f0").is_empty() and at_of(ev, "turn", "who", "hero") >= 0, "extra_turn: the hero acts again at once, before anyone", kinds(ev))
	ev = RpgBattle.act(B, GUARD)
	ok(not evs(ev, "turn", "who", "f0").is_empty(), "then time goes on")

	B = tough(begin(hero(), [wave(["dummy"])]))
	f = B.foes[0]
	ev = move(B, "k_chip")
	ok(first(ev, "chip") == {"t": "chip", "dst": "f0", "chip": 1, "guard": 2} and not first(ev, "dmg").weak and int(first(ev, "dmg").chip) == 0, "chip: pips go whatever the school", first(ev, "chip"))
	move(B, "k_chip")
	ev = move(B, "k_chip")
	ok(not first(ev, "break").is_empty() and bool(f.broken), "and the last one breaks")
	B = tough(begin(hero(), [wave(["big"])]))
	f = B.foes[0]
	at0 = float(f.at)
	move(B, "k_delay")
	ok(near(float(f.at), at0 + 0.25 * RpgDefs.delay(1.0, float(f.spd)), 0.001), "a delay is halved on a boss")


# =============================================================================
# 6: every passive effect
# =============================================================================

## The test hero with one "on" passive that makes it Steady when it fires.
func on_hero(evn: String, extra: Dictionary = {}) -> Dictionary:
	var e = {"p": "on", "ev": evn, "do": {"k": "status", "id": "steady", "turns": 0}}
	for k in extra:
		e[k] = extra[k]
	return hero({}, [e])


func fired(B: Dictionary) -> bool:
	return RpgBattle.has_status(B.hero, "steady")


func cost_in(B: Dictionary, id: String) -> int:
	return int(RpgBattle.options(B).moves.filter(func(m): return m.id == id)[0].cost)


func cd_in(B: Dictionary, id: String) -> int:
	return int(RpgBattle.options(B).moves.filter(func(m): return m.id == id)[0].cd)


func _passives() -> void:
	# the ones RpgHero bakes into the hero's numbers
	var raw = stats(40.0)
	var fx = [{"p": "stat_pct", "stat": "chest", "pct": 0.1}, {"p": "stat_pct", "stat": "body", "pct": 0.05}, {"p": "stat_pct", "stat": "all", "pct": 0.05},
		{"p": "hp", "v": 50}, {"p": "hp_pct", "pct": 0.1}, {"p": "armor", "v": 10}, {"p": "def_pct", "pct": 0.2}, {"p": "spd_pct", "pct": 0.1}, {"p": "crit_add", "v": 0.05},
		{"p": "dodge_add", "v": 0.04}, {"p": "res_add", "v": 15}, {"p": "atk", "school": "push", "v": 7}, {"p": "atk", "school": "all", "v": 3}, {"p": "en_max", "n": 2},
		{"p": "en_start", "n": 1}, {"p": "gauge_start", "n": 25}]
	var u = RpgHero._assemble({"raw": raw, "lvl": 10, "fx": fx})
	ok(near(float(u.s.chest), 48.0) and near(float(u.s.legs), 44.0) and near(float(u.s.mind), 42.0), "stat_pct: one stat, the body stats, all of them", [u.s.chest, u.s.legs, u.s.mind])
	ok(int(u.hp_max) == int(round((RpgDefs.hero_hp(42.0, 44.0, 44.0, 10) + 50.0) * 1.1)), "hp and hp_pct: flat first, then the share", u.hp_max)
	ok(near(float(u.def), (RpgDefs.hero_def(44.0, 40.0 + 28.0 / 6.0, 0.0) + 10.0) * 1.2, 0.001), "armor and def_pct (might follows the body stats)", u.def)
	ok(near(float(u.spd), 42.0 * 1.1) and near(float(u.crit), RpgDefs.crit_chance(42.0, 0.05)) and near(float(u.dodge), RpgDefs.dodge_chance(42.0, 0.04)) and near(float(u.res), 57.0),
		"spd_pct, crit_add, dodge_add, res_add", [u.spd, u.crit, u.dodge, u.res])
	ok(near(float(u.w.push), 10.0) and near(float(u.w.pull), 3.0) and int(u.en_max) == RpgDefs.en_max(42.0) + 2, "atk for a school and for all; en_max", [u.w, u.en_max])
	var B = RpgBattle.start({"hero": u, "waves": [wave(["plain"])], "seed": 3, "custom": custom()})
	ok(int(B.hero.en) == RpgDefs.EN_START + 1 + RpgDefs.EN_TURN and float(B.hero.gauge) >= 25.0 and float(B.hero.gauge) < 26.0 and int(B.hero.hp) >= int(u.hp_max) - 2, "en_start and gauge_start; the hero starts whole", [B.hero.en, B.hero.gauge])
	var plain_u = begin(hero(), [wave(["plain"])]).foes[0]
	var tr = begin(hero(), [wave(["traity"])]).foes[0]
	ok(near(float(tr.hp_max), (float(plain_u.hp_max) + 100.0) * 1.5, 0.01) and near(float(tr.def), (float(plain_u.def) + 6.0) * 1.5) and near(float(tr.spd), float(plain_u.spd) * 1.5)
		and near(float(tr.res), float(plain_u.res) + 15.0) and near(float(tr.crit), RpgDefs.FOE_CRIT + 0.2) and near(float(tr.dodge), 0.3), "a foe's traits are baked into its numbers the same way",
		[tr.hp_max, tr.def, tr.spd, tr.res, tr.crit, tr.dodge])

	# damage
	B = tough(begin(hero(), [wave(["plain"])]))
	var plain = mid(B, "t_pull")
	var plain_strike = mid(B, "strike")
	B = tough(begin(hero({}, [{"p": "stat_dmg", "stat": "chest", "pct": 0.2}]), [wave(["plain"])]))
	ok(near(mid(B, "t_push"), plain * 1.2) and near(mid(B, "t_two"), plain * 1.08) and near(mid(B, "t_pull"), plain), "stat_dmg: by the stat's weight in the move", [mid(B, "t_push") / plain, mid(B, "t_two") / plain])
	B = tough(begin(hero({}, [{"p": "school_pct", "school": "pull", "pct": 0.1}]), [wave(["plain"])]))
	ok(near(mid(B, "t_pull"), plain * 1.1) and near(mid(B, "t_push"), plain) and near(mid(B, "strike"), plain_strike), "school_pct: one school")
	B = tough(begin(hero({}, [{"p": "school_pct", "school": "all", "pct": 0.1}]), [wave(["plain"])]))
	ok(near(mid(B, "t_push"), plain * 1.1) and near(mid(B, "strike"), plain_strike * 1.1), "school_pct all: everything, Strike too")
	B = tough(begin(hero({}, [{"p": "vs_broken", "pct": 0.3}, {"p": "vs_status", "id": "exposed", "pct": 0.2}]), [wave(["plain"])]))
	B.foes[0]["broken"] = true
	ok(near(mid(B, "t_pull"), plain * RpgDefs.BROKEN_MULT * 1.3), "vs_broken (passive)")
	B.foes[0]["broken"] = false
	put(B.foes[0], "exposed")
	ok(near(mid(B, "t_pull"), plain * 1.25 * 1.2), "vs_status (passive)")
	B = tough(begin(hero({}, [{"p": "first_hit", "pct": 0.3}]), [wave(["plain", "plain"])]))
	ok(near(mid(B, "t_pull"), plain * 1.3), "first_hit: the first hit on a foe")
	var ev = move(B, "t_multi")
	var hits = evs(ev, "dmg")
	ok(float(hits[0].amount) > 1.05 * float(hits[1].amount) and near(mid(B, "t_pull"), plain) and near(mid(B, "t_pull", "f1"), plain * 1.3), "only the very first hit, and on each foe",
		hits.map(func(e): return e.amount))
	B = tough(begin(hero({}, [{"p": "combo_same", "pct": 0.1, "max": 0.2}]), [wave(["plain"])]))
	var seen = [mid(B, "t_pull") / plain]
	for i in range(3):
		move(B, "t_pull")
		seen.append(mid(B, "t_pull") / plain)
	ok(near(seen[0], 1.0) and near(seen[1], 1.1) and near(seen[2], 1.2) and near(seen[3], 1.2) and near(mid(B, "t_push"), plain), "combo_same: per move of the same school in a row", seen)
	B = tough(begin(hero({}, [{"p": "combo_alt", "pct": 0.15}]), [wave(["plain"])]))
	seen = [mid(B, "t_push") / plain]
	move(B, "t_pull")
	ok(near(seen[0], 1.0) and near(mid(B, "t_push"), plain * 1.15) and near(mid(B, "t_pull"), plain) and near(mid(B, "strike"), plain_strike), "combo_alt: a move of another school than the last")
	B = tough(begin(hero({}, [{"p": "ramp", "pct": 0.02, "max": 0.04}]), [wave(["plain"])]))
	seen = []
	for i in range(4):
		seen.append(mid(B, "t_pull") / plain)
		RpgBattle.act(B, GUARD)
	ok(near(seen[0], 1.0, 0.004) and near(seen[1], 1.02, 0.004) and near(seen[2], 1.04, 0.004) and near(seen[3], 1.04, 0.004), "ramp: per turn of its own already gone", seen)

	# healing, the gauge, Guard
	B = tough(begin(hero({}, [{"p": "heal_pct", "pct": 0.5}]), [wave(["plain"])]))
	B.hero["hp"] = 100
	ok(first(move(B, "k_heal"), "heal").get("amount") == int(round(0.2 * 400.0 * RpgDefs.heal_mult(30.0, 0.5))), "heal_pct")
	B = tough(begin(hero({}, [{"p": "gauge_rate", "pct": 0.25}]), [wave(["plain"])]))
	move(B, "t_pull")
	ok(near(float(B.hero.gauge), RpgDefs.GAUGE_ACT * RpgDefs.gauge_mult(30.0, 0.25), 0.002), "gauge_rate", B.hero.gauge)
	B = tough(begin(hero({}, [{"p": "guard_pct", "v": 0.1}, {"p": "guard_en", "n": 1}]), [wave(["hitter"])]))
	B.foes[0]["crit"] = 0
	B.hero["en"] = 0
	var whole = float(B.foes[0].intent.dmg)
	ev = foe_turn(B)
	ok(first(ev, "energy").get("v") == 3 and absf(float(first(ev, "dmg", "dst", "hero").amount) - whole * RpgDefs.guard_mult(30.0, 0.1)) <= 1.6, "guard_en and guard_pct",
		[first(ev, "energy"), first(ev, "dmg", "dst", "hero"), whole])
	B = tough(begin(hero({}, [{"p": "lifesteal", "pct": 0.1}]), [wave(["plain"])]))
	B.hero["hp"] = 100
	ev = move(B, "t_pull")
	ok(first(ev, "heal").get("amount") == int(round(0.1 * float(first(ev, "dmg").amount))), "lifesteal (passive): a share of what its attacks deal")

	# at the start of every wave
	B = tough(begin(hero({}, [{"p": "start_status", "id": "hasted", "turns": 1}, {"p": "start_status", "id": "insight", "turns": 0}, {"p": "start_shield", "pct": 0.1}]),
		[wave(["plain"]), wave(["plain"])]))
	var h = B.hero
	ok(RpgBattle.has_status(h, "hasted") and RpgBattle.has_status(h, "insight") and RpgBattle._shield(h) == 40 and not first(RpgBattle.opening(B), "status", "id", "hasted").is_empty(),
		"start_status and start_shield", h.statuses)
	RpgBattle.act(B, GUARD)
	RpgBattle.act(B, GUARD)
	ok(not RpgBattle.has_status(h, "hasted") and RpgBattle.has_status(h, "insight"), "a start status of 0 turns lasts the wave")
	h["statuses"] = h.statuses.filter(func(st): return st.id != "shield")
	B.foes[0]["hp"] = 1
	move(B, "t_pull")
	ok(int(B.wave) == 1 and RpgBattle.has_status(h, "hasted") and RpgBattle.has_status(h, "insight") and RpgBattle._shield(h) == 40, "and they come back with every wave", h.statuses)

	# on: every happening
	B = tough(begin(on_hero("break"), [wave(["dummy"])]))
	move(B, "t_push")
	var before = fired(B)
	B.foes[0]["guard"] = 1
	move(B, "t_push")
	ok(not before and fired(B), "on break")
	B = tough(begin(on_hero("kill"), [wave(["plain", "plain"])]))
	move(B, "t_pull")
	before = fired(B)
	B.foes[0]["hp"] = 1
	move(B, "t_pull")
	ok(not before and fired(B), "on kill")
	B = tough(begin(on_hero("crit"), [wave(["plain"])]))
	move(B, "t_pull")
	before = fired(B)
	move(B, "m_sure_crit")
	ok(not before and fired(B), "on crit")
	B = tough(begin(on_hero("weak", {"every": 2}), [wave(["dummy"])]))
	move(B, "t_pull")
	move(B, "t_multi")
	before = fired(B)
	move(B, "t_multi")
	ok(not before and fired(B), "on weak: once an action, however many hits; every 2: the second time")
	B = tough(begin(on_hero("guard"), [wave(["plain"])]))
	RpgBattle.act(B, STRIKE)
	before = fired(B)
	RpgBattle.act(B, GUARD)
	ok(not before and fired(B), "on guard")
	B = tough(begin(on_hero("hit_taken"), [wave(["hitter"])]))
	RpgBattle.act(B, STRIKE)
	before = fired(B)
	foe_turn(B, "f0", STRIKE)
	ok(not before and fired(B), "on hit_taken")
	B = tough(begin(on_hero("turn", {"every": 3}), [wave(["plain"])]))
	before = fired(B)
	RpgBattle.act(B, GUARD)
	before = before or fired(B)
	RpgBattle.act(B, GUARD)
	ok(not before and fired(B), "on turn, every 3: at the start of the third turn")
	B = tough(begin(on_hero("wave"), [wave(["plain"]), wave(["plain"])]))
	before = fired(B)
	B.foes[0]["hp"] = 1
	move(B, "t_pull")
	ok(before and fired(B), "on wave: at the start of every wave")
	B = tough(begin(on_hero("wave", {"once": true}), [wave(["plain"]), wave(["plain"])]))
	before = fired(B)
	B.foes[0]["hp"] = 1
	move(B, "t_pull")
	ok(before and not fired(B) and int(B.wave) == 1, "once: only the first time in a battle")
	B = tough(begin(hero({}, [{"p": "on", "ev": "break", "do": {"k": "status", "id": "exposed", "turns": 2, "to": "target"}}]), [wave(["dummy", "dummy"])]))
	B.foes[0]["guard"] = 1
	move(B, "t_push")
	ok(RpgBattle.has_status(B.foes[0], "exposed") and not RpgBattle.has_status(B.foes[1], "exposed") and not RpgBattle.has_status(B.hero, "exposed"), "an on effect's target is the other unit of what happened")
	B = tough(begin(hero({}, [{"p": "on", "ev": "kill", "do": {"k": "energy", "n": 2}}]), [wave(["plain", "plain"])]))
	B.foes[0]["hp"] = 1
	B.hero["en"] = 2
	move(B, "t_pull")
	ok(int(B.hero.en) == 5, "on kill: +2 energy for the hero's own kill", B.hero.en)

	# low_hp
	B = tough(begin(hero({}, [{"p": "low_hp", "below": 0.3, "do": {"k": "shield", "pct": 0.2}}]), [wave(["hitter"])]))
	h = B.hero
	h["hp"] = 400
	foe_turn(B, "f0", STRIKE)
	before = RpgBattle.has_status(h, "shield")
	h["hp"] = 130
	foe_turn(B, "f0", STRIKE)
	ok(not before and RpgBattle._shield(h) == int(round(0.2 * 400.0 * RpgDefs.heal_mult(30.0))), "low_hp: when its HP falls under the mark", [h.hp, h.statuses])
	h["statuses"] = []
	foe_turn(B, "f0", STRIKE)
	ok(not RpgBattle.has_status(h, "shield"), "once a battle")

	# a foe's traits wait for things too
	B = begin(hero(), [wave(["lowly"])])
	var lf = B.foes[0]
	var plain_dmg = int(begin(hero(), [wave(["plain"])]).foes[0].intent.dmg)
	ok(RpgBattle.has_status(lf, "regen") and int(lf.intent.dmg) >= 1 and int(lf.intent.dmg) >= plain_dmg, "a foe's start_status; its school_pct all is in its intent")
	lf["hp_max"] = 100000
	lf["hp"] = 50300
	lf["atk"] = 1000.0
	move(B, "t_pull")
	ok(RpgBattle.has_status(lf, "braced") and RpgBattle.has_status(lf, "steady"), "a foe's low_hp and on hit_taken fire when the hero hits it", lf.statuses)
	RpgBattle._refresh_intents(B, [])
	ok(absf(float(lf.intent.dmg) - 0.001 * 1000.0 * RpgDefs.mitigation(20.0) * 1.5) <= 1.0, "a foe's school_pct all: its hits are that much harder, and its intent says so", lf.intent.dmg)

	# costs and rests
	B = tough(begin(hero({}, [{"p": "cost", "school": "pull", "add": -1}]), [wave(["plain"])]))
	ok(cost_in(B, "k_refund") == 1 and cost_in(B, "t_cost") == 2 and cost_in(B, "t_pull") == 0, "cost: moves of a school cost less, never under 0")
	B = tough(begin(hero({}, [{"p": "cost", "school": "all", "add": 1}]), [wave(["plain"])]))
	ok(cost_in(B, "t_cost") == 3 and cost_in(B, "t_pull") == 1, "cost all: every move")
	B = tough(begin(hero({}, [{"p": "cd", "school": "push", "add": 1}]), [wave(["plain"])]))
	move(B, "t_cost")
	move(B, "t_push")
	ok(cd_in(B, "t_cost") == 2 and cd_in(B, "t_push") == 1, "cd: moves of a school rest that much longer", [cd_in(B, "t_cost"), cd_in(B, "t_push")])
	B = tough(begin(hero({}, [{"p": "cd", "school": "push", "add": -5}]), [wave(["plain"])]))
	move(B, "t_cost")
	move(B, "t_push")
	ok(cd_in(B, "t_cost") == 0 and cd_in(B, "t_push") == 0, "cd less: a move that rests never rests less than one turn (it is back after one)", [cd_in(B, "t_cost"), cd_in(B, "t_push")])
	B = tough(begin(hero({}, [{"p": "next_cost", "school": "push", "add": -1}]), [wave(["plain"])]))
	h = B.hero
	var c0 = cost_in(B, "t_cost")
	move(B, "t_push")
	var c1 = cost_in(B, "t_cost")
	move(B, "t_pull")
	var c2 = cost_in(B, "t_cost")
	var en0 = int(h.en)
	move(B, "t_cost")
	ok(c0 == 2 and c1 == 1 and c2 == 1 and int(h.en) == en0 - 1 + RpgDefs.EN_TURN and cost_in(B, "t_cost") == 1, "next_cost: after a move of the school the next one of it costs less; it waits for it",
		[c0, c1, c2, h.en, en0])

	# guard pips
	B = tough(begin(hero({"crit": 1.0}, [{"p": "chip", "on": "crit", "add": 1}]), [wave(["dummy"])]))
	B.foes[0]["guard"] = 6
	B.foes[0]["guard_max"] = 6
	ev = move(B, "t_pull")
	var chips = [int(first(ev, "dmg").chip)]
	ev = move(B, "t_multi")
	chips.append_array(evs(ev, "dmg").map(func(e): return int(e.chip)))
	chips.append(int(first(move(B, "t_mind"), "dmg").chip))
	chips.append(int(first(RpgBattle.act(B, STRIKE), "dmg").chip))
	ok(chips == [1, 2, 0, 0, 0, 0], "chip on crit: a crit chips 1 more, once a move a target; never through a resistance, never with Strike", chips)
	B = tough(begin(hero({}, [{"p": "chip", "on": "push", "add": 1}]), [wave(["dummy"])]))
	ev = move(B, "t_push")
	ok(int(first(ev, "dmg").chip) == 2 and int(first(move(B, "m_smart"), "dmg").chip) == 1, "chip on a school: its weak hits chip more")

	# statuses given and taken
	B = tough(begin(hero({}, [{"p": "status_turns", "on": "debuff", "add": 1}, {"p": "status_turns", "on": "buff", "add": 1}]), [wave(["plain"])]))
	move(B, "k_slow")
	move(B, "k_pump")
	ok(turns_of(B.foes[0], "slowed") == 3 and turns_of(B.hero, "pumped") == 3, "status_turns: its debuffs on foes and its own buffs last longer", [B.foes[0].statuses, B.hero.statuses])
	B = tough(begin(hero({}, [{"p": "status_turns", "on": "self_debuff", "add": -1}]), [wave(["sapper"])]))
	foe_turn(B)
	var got = turns_of(B.hero, "weakened")
	B.hero["statuses"] = []
	move(B, "k_weak_self")
	ok(got == 1 and turns_of(B.hero, "weakened") == 1, "status_turns self_debuff: debuffs on it are shorter, never under one turn", got)
	B = tough(begin(hero({}, [{"p": "status_chance", "add": 0.3}]), [wave(["plain"])]))
	var landed = 0
	for i in range(300):
		B.foes[0]["statuses"] = []
		move(B, "k_slow_half")
		if RpgBattle.has_status(B.foes[0], "slowed"):
			landed += 1
	ok(absf(float(landed) / 300.0 - RpgDefs.status_chance(0.8, 30.0, RpgDefs.ref_stat(3.0))) < 0.08, "status_chance: added to the chance", landed)
	B = tough(begin(hero({}, [{"p": "bounce"}]), [wave(["sapper"])]))
	ev = foe_turn(B)
	var bounced = first(ev, "status", "id", "weakened")
	foe_turn(B)
	ok(bounced.get("bounced") == true and bounced.get("on") == false and RpgBattle.has_status(B.hero, "weakened"), "bounce: the first debuff of the battle bounces off, the second lands", bounced)
	B = tough(begin(hero(), [wave(["bouncer"])]))
	move(B, "k_slow")
	before = RpgBattle.has_status(B.foes[0], "slowed")
	move(B, "k_slow")
	ok(not before and RpgBattle.has_status(B.foes[0], "slowed"), "a foe may have it too")

	# rewards are only added up
	B = begin(hero({}, [{"p": "reward", "what": "ore", "pct": 0.1}, {"p": "reward", "what": "ore", "pct": 0.2}, {"p": "reward", "what": "xp", "pct": 0.1}]), [wave(["plain"])])
	var rw = RpgBattle.summary(B).reward
	ok(near(float(rw.ore), 0.3) and near(float(rw.xp), 0.1) and float(rw.luck) == 0.0, "reward: the summary adds them up", rw)

	# the board passives of the catalog, each through a real fight
	var r = RpgHero.reference_hero(6.0, "grip")
	B = RpgBattle.start({"hero": r, "waves": [[{"foe": "squeaky_plate", "n": 50}]], "seed": 9})
	ok(float(r.crit) > RpgDefs.crit_chance(float(r.s.grip)) + 0.07 and float(B.hero.agg.get("first_hit", 0.0)) == 0.3 and float(B.hero.agg.get("chip:crit", 0.0)) == 1.0,
		"the catalog's passives reach the hero (Chalk Hands, Onsight, Precision)", [r.crit, B.hero.agg])


# =============================================================================
# 11.4: RpgHero
# =============================================================================

func sheet_of(v: float, over: Dictionary = {}) -> Dictionary:
	var st = {}
	for id in RpgDefs.STATS:
		st[id] = {"raw": v, "v": v}
	for k in over:
		st[k] = {"raw": over[k], "v": over[k]}
	return {"stats": st, "might": v}


func xp_for(level: int) -> int:
	var xp = 0
	for l in range(1, level):
		xp += RpgDefs.xp_to_next(l)
	return xp


func _hero_build() -> void:
	var rpg = RpgSave.empty()
	var sheet = sheet_of(20.0, {"endurance": 50.0, "grip": 40.0, "flow": 30.0, "speed": 25.0, "mind": 35.0})
	var u = RpgHero.build(sheet, [], rpg, {"items": {}, "pets": {}})
	ok(u.moves == ["shove", "yank", "stomp", "deep_breath"] and u.ult == "" and int(u.lvl) == 1 and u.belt.is_empty() and u.pet == "" and u.fx.is_empty(), "a new save: the four first moves, nothing else", u.moves)
	ok(int(u.hp_max) == int(round(RpgDefs.hero_hp(50.0, 20.0, 20.0, 1))) and near(float(u.def), RpgDefs.hero_def(20.0, 20.0, 0.0)) and int(u.en_max) == RpgDefs.en_max(50.0)
		and near(float(u.crit), RpgDefs.crit_chance(40.0)) and near(float(u.dodge), RpgDefs.dodge_chance(30.0)) and near(float(u.spd), 25.0) and near(float(u.res), 30.0)
		and near(float(u.tec), 35.0), "the hero's numbers come from the sheet by RpgDefs' formulas", [u.hp_max, u.def, u.en_max, u.crit, u.dodge])
	u = RpgHero.build(sheet, [{"fx": [{"p": "stat_pct", "stat": "chest", "pct": 0.2}]}], rpg, {"items": {}, "pets": {}})
	ok(near(float(u.s.chest), 24.0) and u.fx.size() == 1, "the day's boosts are in force")

	# what the save does not know is skipped
	rpg = RpgSave.empty()
	rpg["xp"] = xp_for(6)
	rpg.builds[0]["moves"] = ["haymaker", "shove", "nothing", "yank", "shove"]
	rpg.builds[0]["ult"] = "titan_press"
	rpg.builds[0]["passives"] = ["lockout_strength", "chalk_hands", "lockout_strength"]
	rpg.builds[0]["belt"] = ["protein_shake", "electrolytes", "mega_shake"]
	rpg.builds[0]["pet"] = "phoenix"
	rpg["items"] = {"protein_shake": 4, "mega_shake": 2}
	u = RpgHero.build(sheet, [], rpg, {"items": {}, "pets": {}})
	ok(int(u.lvl) == 6 and u.moves == ["shove", "yank"] and u.ult == "" and u.fx.is_empty() and u.pet == "", "moves, an ultimate, passives not learned and a pet not owned are left out", [u.lvl, u.moves, u.fx])
	ok(u.belt == [{"id": "protein_shake", "n": 4, "used": 0}, {"id": "mega_shake", "n": 2, "used": 0}], "the belt: the stacks the save holds, in the slots the level opens", u.belt)
	rpg["nodes"] = {"push:haymaker": true, "push:titan_press": true, "push:lockout_strength": true}
	var owned = {"items": {}, "pets": {"phoenix": {"at": "2026-01-01"}}}
	u = RpgHero.build(sheet, [], rpg, owned)
	ok(u.moves == ["haymaker", "shove", "yank"] and u.ult == "titan_press" and u.pet == "phoenix", "once learned and owned they are in", [u.moves, u.ult, u.pet])
	ok(u.fx.size() == 2 and u.fx[0].get("p") == "school_pct" and u.fx[1].get("p") == "survive", "a passive in the first slot (level 3), each once; the companion's passive", u.fx)
	var pu = RpgHero.pet_unit(rpg, owned, 6)
	ok(pu != null and pu.pet == "phoenix" and pu.rarity == "epic" and int(pu.charge_max) == 4 and near(float(pu.spd), RpgDefs.PET_SPD + 2.0 * float(RpgDefs.tier_of_level(6)))
		and RpgHero.pet_unit(rpg, {"pets": {}}, 6) == null, "the companion's unit, or none", pu)
	var B = RpgBattle.start({"hero": u, "pet": pu, "waves": [[{"foe": "dust_bunny", "n": 0}, {"foe": "rust_rat", "n": 0}]], "seed": 5})
	ok(RpgBattle.json_safe(B) == "" and RpgBattle.options(B).moves.size() == 3 and RpgBattle.options(B).items.size() == 2 and B.pet != null and int(B.pet.charge_max) == 4
		and near(float(B.pet.atk), RpgDefs.offence(10.0, 0.0, 6) * 1.35), "the built hero and its companion start a battle", RpgBattle.json_safe(B))
	ok(RpgHero.knows_move(rpg, RpgMoves.by_id("shove")) and RpgHero.knows_move(rpg, RpgMoves.by_id("haymaker")) and not RpgHero.knows_move(rpg, RpgMoves.by_id("one_two"))
		and RpgHero.knows_passive(rpg, RpgPassives.by_id("lockout_strength")) and not RpgHero.knows_passive(rpg, RpgPassives.by_id("spotter")), "knows_move, knows_passive")

	# the reference hero
	var kits_ok = true
	for a in RpgHero.ARCHETYPES:
		for kit in RpgHero.ARCHETYPES[a].kits:
			for id in kit.moves:
				if RpgMoves.by_id(str(id)) == null or bool(RpgMoves.by_id(str(id)).ult):
					kits_ok = false
			for id in kit.passives:
				if RpgPassives.by_id(str(id)) == null:
					kits_ok = false
			if str(kit.ult) != "" and (RpgMoves.by_id(str(kit.ult)) == null or not bool(RpgMoves.by_id(str(kit.ult)).ult)):
				kits_ok = false
	ok(kits_ok and RpgHero.ARCHETYPES.size() == 7, "every archetype's kit is made of moves and passives that exist")
	var last = 0.0
	var rising = true
	for t in [1.0, 4.0, 8.0]:
		var r = RpgHero.reference_hero(t)
		ok(int(r.hp_max) == int(round(RpgDefs.ref_hp(t))) and near(float(r.def), RpgDefs.ref_def(t), 0.001) and int(r.lvl) == RpgDefs.ref_level(t) and near(float(r.w.push), RpgDefs.ref_w(t))
			and near(float(r.s.chest), RpgDefs.ref_stat(t)) and near(float(r.s.mind), RpgDefs.ref_side(t)) and r.moves.size() >= 4,
			"the reference hero of tier %d: RpgDefs' HP, defence, level, gear and stats" % int(t), [r.hp_max, r.def, r.lvl])
		if RpgHero.power(r) <= last:
			rising = false
		last = RpgHero.power(r)
	ok(rising and RpgHero.reference_hero(8.0).ult == "titan_press" and RpgHero.reference_hero(1.0).moves == ["shove", "yank", "stomp", "deep_breath"]
		and near(float(RpgHero.reference_hero(4.0, "mind").s.mind), RpgDefs.ref_stat(4.0)), "its power grows with the tier; its kit with it")
	var nums = RpgHero.numbers(u)
	ok(int(nums.hp) == int(u.hp_max) and near(float(nums.guard), RpgDefs.guard_mult(20.0)) and near(float(nums.blocks), 1.0 - RpgDefs.mitigation(float(u.def))) and nums.offence.size() == 8
		and float(nums.offence.grip) > float(nums.offence.push) and float(nums.power) > 0.0, "numbers(): the fight numbers for the Hero page", nums)


# =============================================================================
# Whole fights: setups from the catalog, and a hero without a player
# =============================================================================

const POOLS = [
	[["dust_bunny", "rust_rat"], ["squeaky_plate", "loose_collar", "moldy_towel"]],
	[["dust_bunny", "dust_bunny", "dust_bunny"], ["bent_bar", "moldy_towel"]],
	[["rust_rat", "loose_collar"], ["old_iron_jaw"]],
	[["mile_marker", "dust_bunny"], ["molten_barbell", "moldy_towel"]],
	[["mirror_shade"], ["the_pacer"]],
	[["mile_marker", "mile_marker", "molten_barbell"]],
	[["old_iron_jaw", "dust_bunny", "dust_bunny"]],
	[["mirror_shade", "squeaky_plate", "moldy_towel"], ["bent_bar"], ["the_pacer", "rust_rat"]],
	[["caller", "medic"], ["big"]],
	[["bomber", "leecher", "dazer"], ["charger", "scorcher", "cutter"], ["cheerer", "adapter", "quick"]],
	[["crusher", "sapper"], ["killer"]],         # one nobody walks out of
]
const ARCH = ["balanced", "push", "pull", "legs", "speed", "grip", "mind"]
const TIERS = [1.0, 2.0, 4.0, 6.0, 8.0]
const PETS = ["", "bulldog", "sprout", "phoenix"]
const BELTS = [
	[],
	[{"id": "protein_shake", "n": 2}, {"id": "electrolytes", "n": 5}],
	[{"id": "smelling_salts", "n": 1}, {"id": "chalk_ball", "n": 4}, {"id": "ice_pack", "n": 3}],
	[{"id": "energy_gel", "n": 2}, {"id": "pre_workout", "n": 2}, {"id": "mega_shake", "n": 1}],
]
const RULE_SETS = [[], ["foes_hasted"], ["guard_up", "foes_braced"], [], ["low_energy", "extra_wave"], ["no_items"], []]


## The i-th made-up fight: a reference hero (every third one well above the
## road, so that some fights are won to the end), waves of catalog foes (two
## pools of the test's own), sometimes a companion, a belt, rules.
func fight(i: int, seed_add: int = 0) -> Dictionary:
	var t = float(TIERS[i % TIERS.size()])
	var over_tier = [0.0, 3.0, 6.0][i % 3]
	var h = RpgHero.reference_hero(t + over_tier, ARCH[i % ARCH.size()])
	h["belt"] = BELTS[(i * 3 + 1) % BELTS.size()].duplicate(true)
	var pet_id = str(PETS[(i * 5 + 2) % PETS.size()])
	var pet = null
	if pet_id != "":
		pet = {"pet": pet_id, "rarity": "rare" if i % 2 == 0 else "common", "name": pet_id}
		if pet_id == "phoenix":
			h.fx.append({"p": "survive", "pct": 0.3})
	var waves = []
	var pool = i % POOLS.size()
	for names in POOLS[pool]:
		waves.append(wave(names, 10.0 * (t - 1.0) + float(i % 4) + (300.0 if pool == 10 else 0.0)))
	var setup = {"hero": h, "pet": pet, "waves": waves, "seed": 1000 + i * 7919 + seed_add, "rules": RULE_SETS[i % RULE_SETS.size()].duplicate(),
		"what": {"kind": "test", "i": i}, "day": "2026-01-05"}
	if i % POOLS.size() >= 8:
		setup["custom"] = custom()          # the two pools of the test's own foes
	if i % 2 == 1:
		setup["known"] = {"dust_bunny": ["push"], "old_iron_jaw": ["legs"], "old_iron_jaw#2": ["pull"]}
	return setup


## Plays a fight to its end: {"B", "ev" (every event, the opening too), "acts",
## "refused" (actions the engine turned down), "unsafe" (the first time B was
## not JSON-safe)}. `round_trip`: B goes through JSON after the start and after
## every action, as a stored battle would.
func play(setup: Dictionary, policy: String, round_trip: bool = false, most: int = 600) -> Dictionary:
	var B = RpgBattle.start(setup)
	var out = {"B": B, "ev": RpgBattle.opening(B).duplicate(true), "acts": 0, "refused": 0, "unsafe": RpgBattle.json_safe(B)}
	if round_trip:
		B = rt(B)
	while not RpgBattle.over(B) and int(out.acts) < most:
		var ev = RpgBattle.act(B, RpgAi.hero_action(B, policy))
		out.acts += 1
		if ev.size() == 1 and str(ev[0].t) == "no":
			out.refused += 1
		out.ev.append_array(ev)
		if str(out.unsafe) == "":
			out.unsafe = RpgBattle.json_safe(B)
		if round_trip:
			B = rt(B)
	out.B = B
	return out


func _ai() -> void:
	# the heuristic: always a legal action, and it gets somewhere
	var refused = 0
	var unfinished = 0
	var wins = 0
	var fled = 0
	for i in range(12):
		var res = play(fight(i), "heuristic")
		refused += int(res.refused)
		if not RpgBattle.over(res.B):
			unfinished += 1
		if RpgBattle.won(res.B):
			wins += 1
		if bool(RpgBattle.summary(res.B).fled):
			fled += 1
	ok(refused == 0 and unfinished == 0 and fled == 0, "the heuristic hero only takes legal actions, never flees, and every fight ends", [refused, unfinished, fled])
	ok(wins >= 6, "and it wins the fights a hero above the road should", wins)

	# what it does in plain situations
	var B = tough(begin(hero(), [wave(["charger"])]))
	foe_turn(B, "f0", STRIKE)
	B.hero["hp"] = 30
	# the blow is due before a Guard runs out (the heuristic reads the turn order: with time to spare it would heal first)
	RpgBattle.unit(B, "f0")["at"] = float(B.hero.at)
	ok(RpgAi.hero_action(B, "heuristic") == {"t": "guard"}, "it guards a charged blow that would kill", RpgAi.hero_action(B, "heuristic"))
	B = tough(begin(hero(), [wave(["plain", "plain"])]))
	B.foes[1]["hp"] = 5
	var a = RpgAi.hero_action(B, "heuristic")
	ok(a.get("target") == "f1" and a.get("t") != "guard", "it finishes a foe it can finish", a)
	B = tough(begin(hero(), [wave(["plain"])], {"pet": {"pet": "t_biter", "rarity": "common"}}))
	B.pet["charge"] = 2
	ok(RpgAi.hero_action(B, "heuristic").get("t") == "pet", "it gives the companion's command when it is charged")
	RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
	ok(RpgAi.hero_action(B, "heuristic").get("t") != "pet", "once")

	# the other policies
	B = tough(begin(hero(), [wave(["plain"])]))
	ok(RpgAi.hero_action(B, "loop:t_cost") == {"t": "move", "id": "t_cost", "target": "f0"}, "loop: the move when it can be used")
	RpgBattle.act(B, RpgAi.hero_action(B, "loop:t_cost"))
	ok(RpgAi.hero_action(B, "loop:t_cost") == {"t": "strike", "target": "f0"}, "loop: Strike while it rests")
	B = tough(begin(hero({"ult": "t_ult"}), [wave(["plain"])]))
	B.hero["gauge"] = 100
	ok(RpgAi.hero_action(B, "loop:t_ult") == {"t": "ult", "target": "f0"}, "loop: the ultimate when the gauge is full")
	var rng0 = int(B.rng)
	var first_pick = RpgAi.hero_action(B, "random")
	ok(first_pick == RpgAi.hero_action(B, "random") and int(B.rng) == rng0 and RpgBattle.illegal(B, first_pick) == "" and first_pick.get("t") != "flee",
		"random: a legal action, the same for the same battle, and the battle's dice are not touched", first_pick)
	RpgBattle.act(B, {"t": "flee"})
	ok(RpgAi.hero_action(B, "heuristic") == {"t": "guard"} and RpgAi.hero_action(B, "random") == {"t": "guard"}, "a battle that is over: nothing to choose")

	# a foe's choice reads only
	B = tough(begin(hero(), [wave(["ruler"])]))
	var snap = JSON.stringify(B)
	var pick = RpgAi.choose(B, B.foes[0])
	ok(JSON.stringify(B) == snap and pick.move == "slap" and int(pick.pi) == 0 and int(pick.rule) == -1 and RpgAi.usable(B, B.foes[0], "poke") and not RpgAi.usable(B, B.foes[0], "nope"),
		"choose() changes nothing and says the move, the pattern index after it and the rule", pick)


# =============================================================================
# The validators: a malformed row of each kind is turned down
# =============================================================================

## A well-formed effect of every kind.
func fx_samples() -> Dictionary:
	return {
		"status": {"k": "status", "id": "exposed", "turns": 2, "chance": 0.7},
		"heal": {"k": "heal", "pct": 0.2}, "shield": {"k": "shield", "pct": 0.25}, "energy": {"k": "energy", "n": 2}, "gauge": {"k": "gauge", "n": 10},
		"delay": {"k": "delay", "pct": 0.4}, "cleanse": {"k": "cleanse", "n": 0}, "dispel": {"k": "dispel", "n": 1}, "interrupt": {"k": "interrupt"},
		"cd_cut": {"k": "cd_cut", "n": 1}, "hp_cost": {"k": "hp_cost", "pct": 0.2}, "lifesteal": {"k": "lifesteal", "pct": 0.5}, "refund": {"k": "refund", "n": 2},
		"extra_turn": {"k": "extra_turn"}, "chip": {"k": "chip", "n": 1}, "when": {"k": "when", "hp_below": 0.4, "do": {"k": "heal", "pct": 0.15}}, "self_ko": {"k": "self_ko"}}


## A well-formed mod of every kind.
func mod_samples() -> Dictionary:
	var vals = {"id": "exposed", "pct": 0.3, "max": 0.6, "below": 0.35, "add": 0.2}
	var out = {}
	for m in RpgBattle.MOD_KEYS:
		var row = {"m": m}
		for k in RpgBattle.MOD_KEYS[m]:
			row[k] = vals[k]
		out[m] = row
	return out


## A well-formed passive effect of every kind.
func passive_samples() -> Dictionary:
	var vals = {"stat": "chest", "pct": 0.1, "school": "push", "v": 5, "n": 1, "id": "hasted", "ev": "turn", "below": 0.3, "add": 1, "on": "debuff", "what": "ore", "max": 0.3}
	var out = {}
	for p in RpgBattle.PASSIVE_KEYS:
		var row = {"p": p}
		for k in RpgBattle.PASSIVE_KEYS[p].need:
			row[k] = {"k": "energy", "n": 1} if k == "do" else vals[k]
		out[p] = row
	out["chip"]["on"] = "crit"
	out["start_status"]["turns"] = 2
	out["survive"]["pct"] = 0.3
	out["status_chance"]["add"] = 0.1
	out["gauge_start"]["n"] = 25
	for p in ["crit_add", "dodge_add", "guard_pct"]:
		out[p]["v"] = 0.05
	return out


## `base` passes `check`; each change ([key, value], or [key] to take the key
## away) makes a row that does not.
func rejects(check: Callable, base: Dictionary, changes: Array, what: String) -> void:
	var good = str(check.call(base))
	var missed = []
	for c in changes:
		var row = base.duplicate(true)
		if c.size() == 1:
			row.erase(c[0])
		else:
			row[c[0]] = c[1]
		if str(check.call(row)) == "":
			missed.append(c)
	ok(good == "" and missed.is_empty(), what, [good, missed])


## A kit with one field of its auto action or command changed.
func pet_with(part: String, key: String, value) -> Dictionary:
	var kit = RpgPets.by_id("bulldog").duplicate(true)
	kit[part][key] = value
	return kit


func _validators() -> void:
	# the catalogs pass
	var bad = []
	for m in RpgMoves.all():
		if RpgBattle.check_move(m) != "":
			bad.append(RpgBattle.check_move(m))
	ok(bad.is_empty() and RpgMoves.all().size() >= 74, "every move of the catalog passes check_move", [bad, RpgMoves.all().size()])
	bad = []
	for p in RpgPassives.all():
		for e in p.fx:
			if RpgBattle.check_passive(e) != "":
				bad.append(str(p.id) + ": " + RpgBattle.check_passive(e))
	ok(bad.is_empty() and RpgPassives.all().size() == 24, "every board passive passes check_passive", bad)
	bad = []
	for f in RpgFoes.all():
		if RpgBattle.check_foe(f) != "":
			bad.append(RpgBattle.check_foe(f))
	for mv in RpgFoes.moves():
		if RpgBattle.check_foe_move(mv) != "":
			bad.append(RpgBattle.check_foe_move(mv))
	ok(bad.is_empty() and not RpgFoes.all().is_empty(), "every foe and foe move of the catalog passes", bad)
	bad = []
	for it in RpgItems.all():
		if RpgBattle.check_item(it) != "":
			bad.append(RpgBattle.check_item(it))
	for kit in RpgPets.all():
		if RpgBattle.check_pet(kit) != "":
			bad.append(RpgBattle.check_pet(kit))
	ok(bad.is_empty() and RpgItems.all().size() == 8 and not RpgPets.all().is_empty(), "every item and companion kit passes", bad)
	var c = custom()
	var foe_moves = {}
	for id in c.foe_moves:
		foe_moves[id] = RpgFoes.full_move(id, c.foe_moves[id])
	var big = RpgFoes.full(c.foes.big)
	big["id"] = "big"
	ok(RpgBattle.check_foe(big, foe_moves, ["dummy"]) == "" and RpgBattle.check_foe(big) != "" and RpgBattle.check_foe(big, foe_moves) != "",
		"a foe from outside the catalog is checked with its own moves and the foes it may bring", RpgBattle.check_foe(big, foe_moves, ["dummy"]))
	ok(RpgBattle.check_pet(c.pets.t_biter) == "" and RpgBattle.check_pet(c.pets.t_nurse) == "", "the test's own kits pass")

	var unknown = []
	for p in passive_samples():
		if RpgBattle.aggregate([passive_samples()[p]]).is_empty():
			unknown.append(p)
	ok(unknown.is_empty() and passive_samples().size() == RpgBattle.PASSIVE_KEYS.size(), "every passive kind the validator accepts is one the engine adds up", unknown)

	# effects: a sample of every kind passes; without a needed key, or with a key it does not know, it does not
	var fxs = fx_samples()
	ok(fxs.keys().size() == RpgBattle.FX_KEYS.size(), "the test has a sample of every effect kind")
	for k in RpgBattle.FX_KEYS:
		var changes = [["zzz", 1], ["k", "nope"]]
		for key in RpgBattle.FX_KEYS[k].need:
			changes.append([key])
		rejects(RpgBattle.check_fx, fxs[k], changes, "check_fx: %s" % k)
	rejects(RpgBattle.check_fx, fxs["status"], [["id", "nope"], ["id", "shield"], ["turns", -1], ["turns", 1.5], ["turns"], ["chance", 0.0], ["chance", 1.5], ["stacks", 2], ["amount", 1.0],
		["to", "everyone"]], "check_fx: a status that is not one, a wrong duration, chance, stacks, amount, target")
	rejects(RpgBattle.check_fx, {"k": "status", "id": "counter", "turns": 2, "amount": 1.5}, [["amount", 0], ["amount", "x"]], "check_fx: a Counter's power")
	rejects(RpgBattle.check_fx, {"k": "status", "id": "bleed", "turns": 3, "stacks": 2}, [["stacks", 4], ["stacks", 0], ["stacks", 1.5]], "check_fx: stacks within the status's most")
	rejects(RpgBattle.check_fx, fxs["heal"], [["pct", 0], ["pct", 3.0], ["pct", "a"], ["pct", -0.1]], "check_fx: a share out of range")
	rejects(RpgBattle.check_fx, fxs["energy"], [["n", 0], ["n", 1.5], ["n", "2"]], "check_fx: energy must be a whole number, not 0")
	rejects(RpgBattle.check_fx, fxs["gauge"], [["n", 0], ["n", 500], ["n", -500]], "check_fx: gauge within -100..100, not 0")
	rejects(RpgBattle.check_fx, fxs["cleanse"], [["ids", ["burn"]], ["n"], ["n", -1], ["n", 0.5]], "check_fx: cleanse takes n or ids, one of them")
	rejects(RpgBattle.check_fx, {"k": "cleanse", "ids": ["burn", "bleed"]}, [["ids", []], ["ids", ["nope"]], ["ids", "burn"]], "check_fx: cleanse ids must be statuses")
	rejects(RpgBattle.check_fx, fxs["dispel"], [["n", -1], ["n", 0.5]], "check_fx: dispel n")
	rejects(RpgBattle.check_fx, fxs["hp_cost"], [["pct", 1.0], ["pct", 0]], "check_fx: hp_cost under the whole")
	rejects(RpgBattle.check_fx, fxs["chip"], [["n", 0], ["n", 1.5]], "check_fx: chip, cd_cut, refund take 1 or more")
	rejects(RpgBattle.check_fx, fxs["when"], [["hp_below", 0], ["hp_below", 1.5], ["do", {"k": "nope"}], ["do", "x"], ["do", {"k": "when", "hp_below": 0.5, "do": {"k": "heal", "pct": 0.1}}]],
		"check_fx: when needs a mark and one well-formed effect, not another when")
	ok(RpgBattle.check_fx("heal") != "" and RpgBattle.check_fx(null) != "" and RpgBattle.check_mod([]) != "" and RpgBattle.check_passive(3) != "" and RpgBattle.check_move(null) != ""
		and RpgBattle.check_foe("x") != "" and RpgBattle.check_foe_move(1) != "" and RpgBattle.check_item([]) != "" and RpgBattle.check_pet(null) != "", "nothing but a dictionary is a row")

	# mods
	var mods = mod_samples()
	for m in RpgBattle.MOD_KEYS:
		var changes = [["zzz", 1], ["m", "nope"]]
		for key in RpgBattle.MOD_KEYS[m]:
			changes.append([key])
			changes.append([key, 0])
			changes.append([key, 99.0])
		rejects(RpgBattle.check_mod, mods[m], changes, "check_mod: %s" % m)
	rejects(RpgBattle.check_mod, mods["ramp_use"], [["max", 0.1]], "check_mod: a max under one step")
	rejects(RpgBattle.check_mod, mods["ignore_def"], [["pct", 1.5]], "check_mod: more than the whole defence")
	rejects(RpgBattle.check_mod, mods["vs_status"], [["id", "nope"]], "check_mod: a status that is not one")

	# passive effects
	var ps = passive_samples()
	for p in RpgBattle.PASSIVE_KEYS:
		var changes = [["zzz", 1], ["p", "nope"]]
		for key in RpgBattle.PASSIVE_KEYS[p].need:
			changes.append([key])
		rejects(RpgBattle.check_passive, ps[p], changes, "check_passive: %s" % p)
	rejects(RpgBattle.check_passive, ps["stat_pct"], [["stat", "nope"], ["pct", "x"]], "check_passive: stat_pct")
	rejects(RpgBattle.check_passive, ps["stat_dmg"], [["stat", "all"], ["stat", "nope"]], "check_passive: stat_dmg names one stat")
	rejects(RpgBattle.check_passive, ps["school_pct"], [["school", "nope"]], "check_passive: school_pct")
	rejects(RpgBattle.check_passive, ps["atk"], [["school", "nope"], ["school", "plain"], ["v", "x"]], "check_passive: atk")
	rejects(RpgBattle.check_passive, ps["cost"], [["school", "nope"], ["add", 0], ["add", 0.5]], "check_passive: cost")
	rejects(RpgBattle.check_passive, ps["cd"], [["add", 0]], "check_passive: cd")
	rejects(RpgBattle.check_passive, ps["next_cost"], [["add", 0], ["school", "plain"]], "check_passive: next_cost")
	rejects(RpgBattle.check_passive, ps["en_max"], [["n", 1.5], ["n", "x"]], "check_passive: whole numbers")
	rejects(RpgBattle.check_passive, ps["gauge_start"], [["n", 0], ["n", 200]], "check_passive: gauge_start")
	rejects(RpgBattle.check_passive, ps["status_chance"], [["add", 2.0], ["add", -1.0]], "check_passive: status_chance")
	rejects(RpgBattle.check_passive, ps["start_status"], [["id", "stun"], ["id", "shield"], ["id", "nope"], ["turns", -1], ["turns"], ["stacks", 2]], "check_passive: start_status")
	rejects(RpgBattle.check_passive, ps["start_shield"], [["pct", 0], ["pct", 3.0]], "check_passive: start_shield")
	rejects(RpgBattle.check_passive, ps["on"], [["ev", "nope"], ["do", {"k": "nope"}], ["do", "x"], ["every", 0], ["every", 1.5], ["once", "yes"]], "check_passive: on")
	rejects(RpgBattle.check_passive, ps["low_hp"], [["below", 0], ["below", 1.5], ["do", {"k": "heal"}]], "check_passive: low_hp")
	rejects(RpgBattle.check_passive, ps["survive"], [["pct", 1.0], ["pct", -0.1]], "check_passive: survive")
	rejects(RpgBattle.check_passive, ps["chip"], [["on", "nope"], ["add", 0]], "check_passive: chip")
	rejects(RpgBattle.check_passive, ps["status_turns"], [["on", "nope"], ["add", 0]], "check_passive: status_turns")
	rejects(RpgBattle.check_passive, ps["vs_status"], [["id", "nope"]], "check_passive: vs_status")
	rejects(RpgBattle.check_passive, ps["reward"], [["what", "gold"]], "check_passive: reward")
	rejects(RpgBattle.check_passive, ps["combo_same"], [["max", 0.01], ["pct", 0]], "check_passive: combo_same")
	rejects(RpgBattle.check_passive, ps["ramp"], [["max", 0.01], ["pct", 0]], "check_passive: ramp")
	rejects(RpgBattle.check_passive, ps["quicken"], [["max", 0.01], ["pct", -0.1]], "check_passive: quicken")
	ok(RpgBattle.check_passive({"p": "survive", "pct": 0.0}) == "" and RpgBattle.check_passive({"p": "start_status", "id": "insight", "turns": 0}) == ""
		and RpgBattle.check_passive({"p": "start_status", "id": "focus", "stacks": 2}) == "", "survive at 1 HP, a status for the whole wave, stacks with no turns: fine")

	# hero moves
	var attack = RpgMoves.by_id("haymaker")
	rejects(RpgBattle.check_move, attack, [["id", "Bad Id"], ["id", ""], ["name", ""], ["school", "nope"], ["kind", "magic"], ["scale", {}], ["scale", {"arms": 0.5}], ["scale", {"nope": 1.0}],
		["scale", {"arms": 0.6, "chest": 0.6}], ["scale", "arms"], ["power", 0], ["power", 99], ["power"], ["hits", 0], ["hits", 9], ["hits", 1.5], ["target", "self"], ["target", "nope"],
		["splash", 2.0], ["splash", "x"], ["cost", -1], ["cost", 1.5], ["cd", 10], ["rank", 0.1], ["rank", 3.0], ["chip", 5], ["mods", "x"], ["mods", [{"m": "nope"}]], ["fx", [{"k": "nope"}]],
		["fx", [{"k": "self_ko"}]], ["tags", [1]], ["text", 1], ["ult", "yes"], ["tier", 1.5], ["zzz", 1]], "check_move: an attack with each of its parts wrong")
	var splash_all = attack.duplicate(true)
	splash_all["target"] = "all"
	rejects(RpgBattle.check_move, splash_all, [["splash", 0.5]], "check_move: only an attack on one foe splashes")
	rejects(RpgBattle.check_move, RpgMoves.by_id("deep_breath"), [["power", 1.0], ["hits", 2], ["target", "all"], ["target", "random"], ["mods", [{"m": "smart"}]],
		["fx", [{"k": "lifesteal", "pct": 0.5}]], ["fx", [{"k": "refund", "n": 1}]], ["fx", [{"k": "delay", "pct": 0.3}]], ["fx", [{"k": "status", "id": "exposed", "turns": 2, "to": "target"}]]],
		"check_move: a support move has no power, hits or mods, and needs a foe for what lands on one")
	rejects(RpgBattle.check_move, RpgMoves.by_id("titan_press"), [["cost", 2]], "check_move: an ultimate costs no energy")

	# foe moves and foes
	rejects(RpgBattle.check_foe_move, RpgFoes.move("gnaw"), [["id", ""], ["name", ""], ["kind", "nope"], ["kind", "bomb"], ["kind", "summon"], ["target", "nope"], ["target", "self"], ["power", -1],
		["power", 7], ["hits", 0], ["hits", 1.5], ["windup", 2], ["count", 3], ["rank", 0], ["rank", 2.5], ["fx", "x"], ["fx", [{"k": "extra_turn"}]], ["fx", [{"k": "chip", "n": 1}]],
		["fx", [{"k": "nope"}]], ["foes", ["dust_bunny"]], ["icon", 1], ["text", 1], ["zzz", 1]], "check_foe_move: each of its parts wrong")
	rejects(RpgBattle.check_foe_move, RpgFoes.move("countdown"), [["windup", 1], ["count", 0], ["count", 10]], "check_foe_move: a countdown")
	rejects(RpgBattle.check_foe_move, RpgFoes.move("spit_laundry"), [["foes", []], ["foes", [""]], ["foes", [3]]], "check_foe_move: a summon brings foes")
	ok(RpgBattle.check_foe_move(RpgFoes.full_move("nothing", {"name": "Nothing"})) != "", "check_foe_move: a move that does nothing")
	rejects(RpgBattle.check_foe, RpgFoes.by_id("bent_bar"), [["id", ""], ["name", ""], ["role", "nope"], ["role", "brute"], ["boss", true], ["elite", false], ["elite", 1], ["weak", ["push"]],
		["weak", ["push", "push"]], ["weak", ["push", "flow"]], ["weak", "push"], ["resist", ["pull", "mind"]], ["resist", ["push"]], ["guard", 13], ["guard", 1.5], ["moves", []],
		["moves", ["nope"]], ["pattern", []], ["pattern", ["nibble"]], ["rules", [{"if": "nope", "use": "brace_up"}]], ["rules", [{"if": "hp_below", "v": 2.0, "use": "brace_up"}]],
		["rules", [{"if": "hp_below", "v": 0.5, "use": "nibble"}]], ["rules", [{"if": "turn_mod", "v": 0, "use": "brace_up"}]], ["rules", [{"if": "turn_mod", "v": [3, 3], "use": "brace_up"}]],
		["rules", [{"if": "hero_has", "v": "nope", "use": "brace_up"}]], ["rules", [{"if": "hp_below", "v": 0.5, "use": "brace_up", "once": 1}]], ["rules", [{"if": "alone"}]], ["rules", ["x"]],
		["traits", [{"p": "nope"}]], ["phases", [{"at": 1.5}]], ["phases", [{"at": 0.5}, {"at": 0.6}]], ["phases", [{"at": 0.5, "pattern": ["nibble"]}]], ["phases", [{"at": 0.5, "weak": ["push"]}]],
		["phases", [{"at": 0.5, "resist": ["push", "pull"]}]], ["phases", [{"at": 0.5, "summon": ["nobody"]}]], ["phases", [{"at": 0.5, "fx": [{"k": "nope"}]}]], ["phases", [{"at": 0.5, "zzz": 1}]],
		["phases", [{"say": "no mark"}]], ["text", 1], ["zzz", 1]], "check_foe: each of its parts wrong")
	ok(RpgBattle.check_foe(RpgFoes.by_id("old_iron_jaw")) == "" and RpgBattle.check_foe(RpgFoes.by_id("the_pacer")) == "", "the bosses' phases pass")

	# items and companions
	rejects(RpgBattle.check_item, RpgItems.by_id("ice_pack"), [["id", ""], ["name", ""], ["price", -1], ["price", 1.5], ["fx", []], ["fx", [{"k": "nope"}]], ["fx", [{"k": "refund", "n": 1}]],
		["fx", [{"k": "self_ko"}]], ["icon", 1], ["text"], ["zzz", 1]], "check_item: each of its parts wrong")
	rejects(RpgBattle.check_pet, RpgPets.by_id("bulldog"), [["id", ""], ["auto", "x"], ["command"], ["passive", [{"p": "nope"}]], ["passive", "x"], ["zzz", 1]], "check_pet: its parts")
	var kits = [pet_with("auto", "kind", "nope"), pet_with("auto", "power", 0.0), pet_with("auto", "power", 9.0), pet_with("auto", "every", 0), pet_with("auto", "school", "nope"),
		pet_with("auto", "name", ""), pet_with("auto", "fx", [{"k": "self_ko"}]), pet_with("auto", "zzz", 1), pet_with("command", "charge", 0), pet_with("command", "charge", 7),
		pet_with("command", "target", "nope"), pet_with("command", "fx", [{"k": "hp_cost", "pct": 0.1}]), pet_with("command", "fx", [{"k": "nope"}]), pet_with("command", "power", -1.0)]
	var missed = []
	for i in range(kits.size()):
		if RpgBattle.check_pet(kits[i]) == "":
			missed.append(i)
	ok(missed.is_empty(), "check_pet: an auto action or a command with a part wrong", missed)


# =============================================================================
# Words for the screens
# =============================================================================

## A phrase a screen can show: not empty, no format left over, nothing a float printed raw would leave.
func reads_well(w: String) -> bool:
	return w != "" and not w.contains("%s") and not w.contains("%d") and not w.contains("null") and not w.contains("  ") and not w.contains("{") and not w.contains("_")\
		and w.left(1) == w.left(1).to_upper() and not w.ends_with(" ") and not w.contains(".0") and w.length() < 110


func _words() -> void:
	var poor = []
	var fxs = fx_samples()
	for k in fxs:
		for attack in [true, false]:
			if not reads_well(RpgBattle.fx_words(fxs[k], attack)):
				poor.append([k, RpgBattle.fx_words(fxs[k], attack)])
	for id in RpgDefs.STATUS:
		if id == "shield":
			continue
		for to in ["", "self", "target", "all_foes", "allies", "ally"]:
			var e = {"k": "status", "id": id, "turns": 2}
			if to != "":
				e["to"] = to
			for attack in [true, false]:
				if not reads_well(RpgBattle.fx_words(e, attack)):
					poor.append([id, to, RpgBattle.fx_words(e, attack)])
	ok(poor.is_empty(), "fx_words: every effect kind and every status reads as plain words", poor)
	poor = []
	var mods = mod_samples()
	for m in mods:
		if not reads_well(RpgBattle.mod_words(mods[m])):
			poor.append([m, RpgBattle.mod_words(mods[m])])
	ok(poor.is_empty(), "mod_words: every mod kind", poor)
	poor = []
	var ps = passive_samples()
	for p in ps:
		if not reads_well(RpgBattle.passive_words(ps[p])):
			poor.append([p, RpgBattle.passive_words(ps[p])])
	ok(poor.is_empty(), "passive_words: every passive kind", poor)
	ok(RpgBattle.fx_words({"k": "nope"}) == "" and RpgBattle.mod_words({"m": "nope"}) == "" and RpgBattle.passive_words({"p": "nope"}) == "", "a kind nobody knows has no words")

	var said = [
		[RpgBattle.fx_words({"k": "status", "id": "exposed", "turns": 2, "chance": 0.7}), "Exposed for 2 turns (70%)"],
		[RpgBattle.fx_words({"k": "status", "id": "weakened", "turns": 1, "to": "self"}), "You are Weakened for 1 turn"],
		[RpgBattle.fx_words({"k": "status", "id": "regen", "turns": 3}, false), "Regen for 3 turns"],
		[RpgBattle.fx_words({"k": "status", "id": "stun", "chance": 0.45}), "Stunned (45%)"],
		[RpgBattle.fx_words({"k": "status", "id": "focus", "stacks": 2}, false), "Focus x2"],
		[RpgBattle.fx_words({"k": "status", "id": "exposed", "turns": 2, "to": "all_foes"}), "Every foe: Exposed for 2 turns"],
		[RpgBattle.fx_words({"k": "heal", "pct": 0.2}, false), "Heals 20% of max HP"],
		[RpgBattle.fx_words({"k": "shield", "pct": 0.25}, false), "Shield of 25% of max HP"],
		[RpgBattle.fx_words({"k": "energy", "n": 2}), "+2 energy"],
		[RpgBattle.fx_words({"k": "energy", "n": -2}), "-2 energy"],
		[RpgBattle.fx_words({"k": "energy", "n": 99}), "Energy full"],
		[RpgBattle.fx_words({"k": "gauge", "n": 12}), "+12 gauge"],
		[RpgBattle.fx_words({"k": "delay", "pct": 0.4}), "Pushes the target's turn back 40%"],
		[RpgBattle.fx_words({"k": "cleanse", "n": 0}), "Removes every debuff"],
		[RpgBattle.fx_words({"k": "cleanse", "n": 1}), "Removes 1 debuff"],
		[RpgBattle.fx_words({"k": "cleanse", "ids": ["burn", "bleed"]}), "Removes Burn and Bleed"],
		[RpgBattle.fx_words({"k": "cd_cut", "n": 1}), "Other cooldowns -1"],
		[RpgBattle.fx_words({"k": "refund", "n": 2}), "+2 energy on a kill"],
		[RpgBattle.fx_words({"k": "when", "hp_below": 0.4, "do": {"k": "heal", "pct": 0.15}}, false), "Under 40% HP: heals 15% of max HP"],
		[RpgBattle.mod_words({"m": "vs_status", "id": "exposed", "pct": 0.3}), "+30% against Exposed foes"],
		[RpgBattle.mod_words({"m": "vs_status", "id": "burn", "pct": 0.3}), "+30% against foes with Burn"],
		[RpgBattle.mod_words({"m": "ramp_use", "pct": 0.2, "max": 1.0}), "+20% per use this battle (up to +100%)"],
		[RpgBattle.mod_words({"m": "ignore_def", "pct": 0.5}), "Ignores 50% of the defence"],
		[RpgBattle.mod_words({"m": "ignore_def", "pct": 1.0}), "Ignores the defence"],
		[RpgBattle.mod_words({"m": "execute", "below": 0.35, "pct": 1.0}), "+100% against a foe under 35% HP"],
		[RpgBattle.mod_words({"m": "crit", "add": 0.25}), "Crit chance +25%"],
		[RpgBattle.passive_words({"p": "school_pct", "school": "push", "pct": 0.1}), "Push moves +10%"],
		[RpgBattle.passive_words({"p": "stat_pct", "stat": "body", "pct": 0.05}), "Body stats +5%"],
		[RpgBattle.passive_words({"p": "on", "ev": "turn", "every": 3, "do": {"k": "energy", "n": 1}}), "Every 3 turns: +1 energy"],
		[RpgBattle.passive_words({"p": "on", "ev": "weak", "do": {"k": "energy", "n": 1}}), "On a weakness hit: +1 energy"],
		[RpgBattle.passive_words({"p": "low_hp", "below": 0.3, "do": {"k": "shield", "pct": 0.2}}), "Once a battle, under 30% HP: Shield of 20% of max HP"],
		[RpgBattle.passive_words({"p": "survive", "pct": 0.0}), "Once a battle, survives a lethal hit at 1 HP"],
		[RpgBattle.passive_words({"p": "next_cost", "school": "push", "add": -1}), "After a Push move the next Push move costs 1 less"],
		[RpgBattle.passive_words({"p": "status_turns", "on": "debuff", "add": 1}), "Debuffs you give last 1 turn longer"],
		[RpgBattle.passive_words({"p": "start_status", "id": "insight", "turns": 0}), "Insight all battle"],
		[RpgBattle.passive_words({"p": "chip", "on": "crit", "add": 1}), "A crit chips 1 guard"],
		[RpgBattle.passive_words({"p": "on", "ev": "hit_taken", "every": 3, "do": {"k": "status", "id": "braced", "turns": 1}}), "Every 3rd hit taken: Braced for 1 turn"],
		[RpgBattle.passive_words({"p": "on", "ev": "kill", "once": true, "do": {"k": "heal", "pct": 0.1}}), "Once a battle, on a kill: heals 10% of max HP"],
		[RpgBattle.passive_words({"p": "school_pct", "school": "plain", "pct": 0.1}), "Strike +10%"],
		[RpgBattle.passive_words({"p": "en_start", "n": 1}), "Starts with 1 more energy"],
		[RpgMoves.by_id("overhead_smash").text, "Chips 2 guard on a weak foe."],
		[RpgMoves.by_id("burnout_set").text, "4 hits. You are Weakened for 1 turn."],
		[RpgPassives.by_id("spotter").text, "Once a battle, under 30% HP: Shield of 20% of max HP."],
		[RpgItems.by_id("ice_pack").text, "Shield of 25% of max HP. Removes Burn and Bleed."],
	]
	var off = said.filter(func(pair): return pair[0] != pair[1])
	ok(off.is_empty(), "the words say what the row says", off)

	# every text the catalogs make from their rows
	poor = []
	for m in RpgMoves.all():
		if (not m.mods.is_empty() or not m.fx.is_empty()) and (str(m.text) == "" or not str(m.text).ends_with(".")):
			poor.append(m.id)
	for p in RpgPassives.all():
		if str(p.text) == "" or not str(p.text).ends_with("."):
			poor.append(p.id)
	for it in RpgItems.all():
		if str(it.text) == "" or not str(it.text).ends_with("."):
			poor.append(it.id)
	for kit in RpgPets.all():
		if str(kit.command.get("text", "")) == "":
			poor.append(kit.id)
	ok(poor.is_empty(), "every move, passive, item and command of the catalog has its words", poor)


# =============================================================================
# 4.10, 11.4: the same battle again; a stored battle goes on as the same battle
# =============================================================================

func _replay() -> void:
	var differ = 0
	var same_seed = true
	var same_json = true
	var same_end = true
	var unsafe = ""
	var detail = []
	for i in range(14):
		var policy = "heuristic" if i % 4 == 3 else "random"
		var a = play(fight(i), policy)
		var b = play(fight(i), policy)
		var c = play(fight(i), policy, true)
		var d = play(fight(i, 1), policy)
		var ja = JSON.stringify(a.ev)
		if ja != JSON.stringify(b.ev):
			same_seed = false
			detail.append(["seed", i])
		if ja != JSON.stringify(c.ev):
			same_json = false
			detail.append(["json", i, a.ev.size(), c.ev.size()])
		if JSON.stringify(a.B) != JSON.stringify(c.B) or JSON.stringify(RpgBattle.summary(a.B)) != JSON.stringify(RpgBattle.summary(c.B)):
			same_end = false
			detail.append(["end", i])
		if ja != JSON.stringify(d.ev):
			differ += 1
		if unsafe == "" and str(a.unsafe) != "":
			unsafe = "fight %d: %s" % [i, str(a.unsafe)]
	ok(same_seed, "the same seed gives the same events", detail)
	ok(same_json, "a battle passed through JSON after every action gives the identical events", detail)
	ok(same_end, "and ends as the identical battle, with the identical summary", detail)
	ok(differ >= 12, "another seed gives another fight", differ)
	ok(unsafe == "", "B is JSON-safe after the start and after every action", unsafe)
	var B = RpgBattle.start(fight(2))
	var back = rt(B)
	ok(JSON.stringify(back) == JSON.stringify(B) and RpgBattle.json_safe(back) == "" and typeof(back.rng) == TYPE_INT and JSON.stringify(RpgBattle.options(back)) == JSON.stringify(RpgBattle.options(B))
		and JSON.stringify(RpgBattle.timeline(back, 7)) == JSON.stringify(RpgBattle.timeline(B, 7)), "a battle read back from JSON is the battle that was stored")
	ok(int(B.v) == RpgDefs.VERSION and B.what == {"kind": "test", "i": 2} and B.day == "2026-01-05", "it carries its version, what it is and its day")


# =============================================================================
# Fifty fights at random
# =============================================================================

func _random_fights() -> void:
	var ended = 0
	var wins = 0
	var problems = []
	var seen = {"breaks": 0, "waves": 0, "phases": 0, "summons": 0, "items": 0, "commands": 0, "ults": 0, "intents": 0, "lost": 0, "ticks": 0}
	for i in range(50):
		var setup = fight(i, 31)
		var B = RpgBattle.start(setup)
		var said = {}
		var ids = {}
		var acts = 0
		var ev = RpgBattle.opening(B)
		while true:
			# what happened
			var res = intent_check(ev, said)
			seen.intents += int(res.checked)
			if int(res.wrong) > 0:
				problems.append("fight %d: an intent lied: %s" % [i, str(res.pairs)])
			for e in ev:
				var t = str(e.get("t", ""))
				if t == "":
					problems.append("fight %d: an event without a kind" % i)
				elif t == "no":
					problems.append("fight %d: the engine turned down %s" % [i, str(e)])
				elif t == "wave" or t == "summon":
					for u in e.units:
						if ids.has(str(u.id)):
							problems.append("fight %d: the id %s was used twice" % [i, str(u.id)])
						ids[str(u.id)] = true
					seen[("waves" if t == "wave" else "summons")] += 1
				elif t == "break":
					seen.breaks += 1
				elif t == "phase":
					seen.phases += 1
				elif t == "tick":
					seen.ticks += 1
				elif t == "act":
					if str(e.kind) == "item":
						seen.items += 1
					elif str(e.kind) == "command":
						seen.commands += 1
					elif str(e.kind) == "ult":
						seen.ults += 1
					elif str(e.kind) == "lost":
						seen.lost += 1
				elif t == "dmg" and (int(e.amount) < 0 or int(e.hp) < 0 or int(e.absorbed) < 0):
					problems.append("fight %d: a hit below zero %s" % [i, str(e)])
			# where things stand
			var h = B.hero
			if int(h.hp) < 0 or int(h.hp) > int(h.hp_max) or int(h.en) < 0 or int(h.en) > int(h.en_max) or float(h.gauge) < 0.0 or float(h.gauge) > RpgDefs.GAUGE_MAX:
				problems.append("fight %d: the hero is out of bounds: hp %s en %s gauge %s" % [i, str(h.hp), str(h.en), str(h.gauge)])
			for f in B.foes:
				if int(f.hp) < 0 or int(f.hp) > int(f.hp_max) or int(f.guard) < 0 or int(f.guard) > int(f.guard_max) or (bool(f.alive) != (int(f.hp) > 0)):
					problems.append("fight %d: %s is out of bounds: hp %s guard %s" % [i, str(f.id), str(f.hp), str(f.guard)])
			for u in [h] + B.foes:
				for st in u.statuses:
					if int(st.stacks) < 1 or int(st.stacks) > int(RpgDefs.STATUS[str(st.id)].stacks) or int(st.turns) < 0:
						problems.append("fight %d: a status out of bounds on %s: %s" % [i, str(u.id), str(st)])
			if B.pet != null and (int(B.pet.charge) < 0 or int(B.pet.charge) > int(B.pet.charge_max)):
				problems.append("fight %d: the companion's charge is out of bounds" % i)
			if RpgBattle.foes(B).size() > RpgDefs.FOES_MAX:
				problems.append("fight %d: more than three foes stand" % i)
			var why = RpgBattle.json_safe(B)
			if why != "":
				problems.append("fight %d: %s" % [i, why])
			var opt = RpgBattle.options(B)
			if RpgBattle.over(B):
				if not opt.targets.is_empty():
					problems.append("fight %d: targets after the end" % i)
				break
			if opt.targets.is_empty() or not bool(B.wait):
				problems.append("fight %d: the battle runs and there is nothing to aim at" % i)
				break
			for id in opt.targets:
				if RpgBattle.unit(B, str(id)) == null or not bool(RpgBattle.unit(B, str(id)).alive):
					problems.append("fight %d: a target that does not stand" % i)
			if acts >= 600:
				break
			ev = RpgBattle.act(B, RpgAi.hero_action(B, "random"))
			acts += 1
		if RpgBattle.over(B):
			ended += 1
			var sum = RpgBattle.summary(B)
			if RpgBattle.won(B):
				wins += 1
			var odd = bool(sum.win) != RpgBattle.won(B) or int(sum.turns) != int(B.hero.turns) or float(sum.hp_share) < 0.0 or float(sum.hp_share) > 1.0
			if odd or float(sum.worst_share) < 0.0 or float(sum.worst_share) > 1.0 or int(sum.dealt) < 0 or int(sum.taken) < 0:
				problems.append("fight %d: the summary does not add up: %s" % [i, str(sum)])
			for id in sum.used:
				if int(sum.used[id]) > RpgDefs.BELT_USES or setup.rules.has("no_items"):
					problems.append("fight %d: the belt gave more than it may: %s" % [i, str(sum.used)])
			for sc in sum.schools:
				if not RpgDefs.SCHOOLS.has(sc):
					problems.append("fight %d: a school that is none in the summary: %s" % [i, str(sc)])
		if problems.size() > 12:
			break
	ok(problems.is_empty(), "50 fights at random: every number stays inside its bounds, every intent is true, there is always a target", problems.slice(0, 6))
	ok(ended == 50, "all of them end", ended)
	ok(wins >= 8 and wins <= 48, "some are won, some are lost", wins)
	ok(int(seen.waves) >= 70 and int(seen.phases) >= 1 and int(seen.summons) >= 2 and int(seen.items) >= 10 and int(seen.commands) >= 10 and int(seen.intents) >= 200
		and int(seen.ticks) >= 10, "and between them they see waves, boss phases, summons, items, commands, burns", seen)


# =============================================================================
# 4.1: the reference hero against the foe it was solved for
# =============================================================================

func _reference_ttk() -> void:
	for t in [1.0, 4.0, 8.0]:
		var n = 10.0 * (t - 1.0)
		var turns = []
		var total = 0.0
		for s in range(8):
			var B = RpgBattle.start({"hero": RpgHero.reference_hero(t), "waves": [wave(["ref_dummy"], n)], "seed": 77 + s * 131, "custom": custom()})
			var f = B.foes[0]
			f["hp_max"] = int(round(RpgDefs.foe_hp(n)))
			f["hp"] = int(f.hp_max)
			var acts = 0
			while not RpgBattle.over(B) and acts < 60:
				RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
				acts += 1
			var took = int(RpgBattle.summary(B).turns) if RpgBattle.won(B) else 99
			turns.append(took)
			total += float(took)
		var mean = total / float(turns.size())
		ok(mean >= RpgDefs.TTK - 1.0 and mean <= RpgDefs.TTK + 1.2, "the reference hero of tier %d beats a lone role-1.0 foe in about %s turns" % [int(t), str(RpgDefs.TTK)], [mean, turns])
