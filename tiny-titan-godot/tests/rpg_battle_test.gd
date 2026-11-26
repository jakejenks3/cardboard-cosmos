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
		"t_ult": mv({"power": 2.0, "ult": true}),
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
		"moves": ["t_push", "t_pull", "t_mind", "t_multi", "t_break", "t_cost"], "ult": "",
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
	ok(near(float(with_boss.foes[0].hp_max), RpgDefs.foe_hp(30.0) * 5.0, 0.01) and near(float(with_boss.foes[1].hp_max), float(lone.hp_max) * RpgDefs.ADD_MULT, 0.01)
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
	ok(not shown.is_empty() and near(float(shown[0].intent.dmg), float(d_open) * gm, 0.03), "the foe's intent shows the guarded number at once", [d_open, shown[0].intent.dmg if not shown.is_empty() else null])
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
		and not first(ev, "dmg").is_empty(), "the ultimate uses the whole gauge and fills none of it; rank 1.0", [h.gauge, ev.map(func(e): return e.t)])

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
