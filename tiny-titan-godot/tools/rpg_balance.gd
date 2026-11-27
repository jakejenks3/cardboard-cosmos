extends SceneTree
## The Realm's balance sweep (RPG_PLAN.md 13): the simulator (tests/rpg_sim.gd)
## over the whole road, printed as tables. Headless, writes nothing.
##
##   TINY_TITAN_DATA=<a throwaway folder>
##   godot --headless --path <project> --script res://tools/rpg_balance.gd [-- words]
##
## Words after "--" (any of them, in any order; none = everything at 200 seeds):
##   quick      20 seeds instead of 200 (40 for the checks that are a win rate)
##   seeds=N    that many seeds
##   xp         the fighter level after each region, winning every stage once / 1.5 times / twice, against ref_level
##   road       the reference hero (balanced) on every stage: win %, median hero turns, median HP left
##   arch       every archetype on stages 3, 5 and 10 of every region, and its most used action
##   boss       the bosses: reference power x1.0 / x1.2 / x0.7, the random policy, every one-move loop
##   new        the empty-log hero (every stat 1) and the new-log hero (every stat 15) on r1s1 to r1s4, and
##              the lopsided hero (body 45, speed 30, the rest 25) on regions 4 to 6
##   player     the "player" profile's road (PLAYER_RAW, PLAYER_KITS, PLAYER_GEAR below): a pack of three, the
##              elite and the boss of every region at the level the road's first wins give, with and without
##              a +15% boost on his main school, five levels over, and with his Core raised (the Core finding)
##   par        1.3 x the reference hero's median turns for every stage, as the PAR table of rpg_world.gd
##   tune       (only when asked) every boss with its hp_pct trait 0.2 and 0.1 lower and higher than it is, so
##              the one that puts the balanced reference hero in the band can be read off; it changes nothing.
##              only=<boss id or r<region>>[,...] looks at those alone

##   trace=<stage id>:<seed>[:<archetype>[:<hp_pct of its boss or nothing>[:<power factor>]]]   (only when
##              asked) one fight of the reference hero, turn by turn
##
## What it checks is the plan's 4.1 TARGETS and the bands of section 13; a
## line that misses its band ends in "  <-- " and what it missed.

var Sim = load("res://tests/rpg_sim.gd")

var seeds = 200
var words = []
## only=<a boss id or r<region>>[,...]: what `tune` looks at (and, by region, `boss` and `player`).
var only = []

## The made-up player this was tuned for (like the real one): strong back,
## shoulders, arms, legs and grip; a weak chest, core and grit.
const PLAYER_RAW = {"chest": 15.0, "shoulders": 37.0, "arms": 36.0, "back": 39.0, "core": 7.0, "legs": 36.0,
	"speed": 15.0, "endurance": 21.0, "grip": 38.0, "mind": 16.0, "flow": 16.0, "grit": 10.0}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var w = str(a)
		if w == "quick":
			seeds = 20
		elif w.begins_with("seeds="):
			seeds = maxi(1, int(w.substr(6)))
		elif w.begins_with("only="):
			only = Array(w.substr(5).split(","))
		else:
			words.append(w)
	var t0 = Time.get_ticks_msec()
	if _wants("xp"):
		_xp()
	if _wants("road"):
		_road()
	if _wants("boss"):
		_boss()
	if _wants("arch"):
		_arch()
	if _wants("new"):
		_new()
	if _wants("player"):
		_player()
	if _wants("par"):
		_par()
	if words.has("tune"):
		_tune()
	for w in words:
		if str(w).begins_with("trace="):
			_trace(str(w).substr(6))
	print("RPG BALANCE: done in %.1f s (%d seeds)" % [float(Time.get_ticks_msec() - t0) / 1000.0, seeds])
	quit(0)


func _wants(w: String) -> bool:
	return words.is_empty() or words.has(w)


func _ref(n: float, arch: String = "balanced") -> Dictionary:
	return RpgHero.reference_hero(RpgDefs.tier_of_n(n), arch)


func _flag(ok: bool, what: String) -> String:
	return "" if ok else "  <-- " + what


func _road() -> void:
	print("--- the reference hero (balanced, weaknesses known, heuristic): win %, median hero turns, median HP left ---")
	for st in RpgWorld.all_stages():
		if str(st.kind) == "cache":
			continue
		var r = Sim.run(_ref(float(st.n)), st.waves, seeds)
		print("%-5s %-6s n=%2d  %s  breaks %.1f  guards %.1f  worst %2d%%  top %s %d%%" % [str(st.id), str(st.kind), int(st.n), Sim.cell(r),
			float(r.breaks), float(r.guards), int(round(float(r.worst) * 100.0)), str(r.top), int(round(float(r.top_share) * 100.0))])


## The fighter XP of one win of a stage at that level (RpgLoot.rewards' own sum).
func _stage_xp(st: Dictionary, level: int) -> float:
	var xp = 0.0
	for wave in RpgWorld.waves_fought(st):
		for en in wave:
			xp += float(RpgDefs.foe_xp(float(en.get("n", st.n)), RpgWorld.foe_kind(en)))
	return xp * RpgDefs.xp_share(level, float(st.n))


## The fighter level before each stage and after the road, winning every stage `times` times.
func _levels(times: float) -> Dictionary:
	var xp = 0.0
	var before = {}
	for st in RpgWorld.all_stages():
		var lvl = int(RpgDefs.level_of(int(xp)).lvl)
		before[str(st.id)] = lvl
		if str(st.kind) != "cache":
			xp += times * _stage_xp(st, lvl)
	before["end"] = int(RpgDefs.level_of(int(xp)).lvl)
	return before


func _xp() -> void:
	print("--- fighter level when each region's boss is met (wins of every stage: x1 / x1.5 / x2) against the reference level ---")
	var a = _levels(1.0)
	var b = _levels(1.5)
	var c = _levels(2.0)
	for r in range(1, 9):
		var id = "r%ds10" % r
		var n = float(10 * (r - 1) + 9)
		print("region %d: at s1 %2d / %2d / %2d (ref %2d)   at the boss %2d / %2d / %2d (ref %2d)" % [r, int(a["r%ds1" % r]), int(b["r%ds1" % r]), int(c["r%ds1" % r]),
			RpgDefs.ref_level(RpgDefs.tier_of_n(n - 9.0)), int(a[id]), int(b[id]), int(c[id]), RpgDefs.ref_level(RpgDefs.tier_of_n(n))])
	print("after the road: %d / %d / %d" % [int(a.end), int(b.end), int(c.end)])


func _pct(x: float) -> int:
	return int(round(x * 100.0))


## The attacks a hero has equipped (its ultimate too, when it is an attack).
func _attacks(hero: Dictionary) -> Array:
	var out = []
	for id in hero.moves:
		var row = RpgMoves.by_id(str(id))
		if row != null and str(row.kind) == "attack":
			out.append(str(id))
	var u = RpgMoves.by_id(str(hero.get("ult", "")))
	if u != null and str(u.kind) == "attack":
		out.append(str(u.id))
	return out


func _boss() -> void:
	print("--- bosses and elites, the reference hero (balanced): power x1.0, x1.2, x0.7; the random policy; one-move loops ---")
	var win_n = maxi(seeds, 40)
	for r in range(1, 9):
		if not only.is_empty() and not only.has("r%d" % r):
			continue
		var el = RpgWorld.stage("r%ds5" % r)
		var e = Sim.run(_ref(float(el.n)), el.waves, seeds)
		print("r%ds5  elite %-14s %s  worst %d%%%s" % [r, str(RpgWorld.region(str(el.region)).elite), Sim.cell(e), _pct(float(e.worst)),
			_flag(int(e.turns) >= 6 and int(e.turns) <= 11 and float(e.hp) >= 0.35, "an elite: 6 to 11 turns, 35%+ HP left")])
		var st = RpgWorld.stage("r%ds10" % r)
		var hero = _ref(float(st.n))
		var a = Sim.run(hero, st.waves, win_n)
		var up = Sim.run(Sim.scaled(hero, 1.2), st.waves, win_n)
		var down = Sim.run(Sim.scaled(hero, 0.7), st.waves, win_n)
		var rnd = Sim.run(hero, st.waves, win_n, "random")
		var miss = []
		if float(a.win) < 0.55 or float(a.win) > 0.85:
			miss.append("win 55 to 85%")
		if int(a.turns) < 11 or int(a.turns) > 22:
			miss.append("11 to 22 turns")
		if float(up.win) < 0.92:
			miss.append("x1.2 92%+")
		if float(down.win) >= 0.25:
			miss.append("x0.7 under 25%")
		if float(rnd.win) > float(a.win) / 3.0:
			miss.append("random under a third")
		if float(a.worst) > 0.35:
			miss.append("a hit over 35%")
		var loops = []
		for id in _attacks(hero):
			var l = Sim.run(hero, st.waves, win_n, "loop:" + str(id))
			loops.append("%s %d%%" % [str(id), _pct(float(l.win))])
			if float(l.win) > 0.85 * float(a.win):
				miss.append("loop:" + str(id))
		print("r%ds10 boss  %-14s %s  x1.2 %3d%%  x0.7 %3d%%  random %3d%%  worst %d%%  guards %.1f  breaks %.1f%s" % [r, str(RpgWorld.region(str(st.region)).boss), Sim.cell(a),
			_pct(float(up.win)), _pct(float(down.win)), _pct(float(rnd.win)), _pct(float(a.worst)), float(a.guards), float(a.breaks), _flag(miss.is_empty(), ", ".join(miss))])
		print("        loops: %s" % ", ".join(loops))


func _arch() -> void:
	print("--- every archetype on stages 3, 5, 7 and 10 of each region: pack | elite | pack of three | boss; its most used action over the four ---")
	for arch in RpgHero.ARCHETYPES:
		for r in range(1, 9):
			var cells = []
			var acts = {}
			var total = 0.0
			for s in [3, 5, 7, 10]:
				var st = RpgWorld.stage("r%ds%d" % [r, s])
				var res = Sim.run(_ref(float(st.n), str(arch)), st.waves, seeds)
				cells.append(Sim.cell(res))
				for k in res.share:
					acts[k] = float(acts.get(k, 0.0)) + float(res.share[k])
					total += float(res.share[k])
			var top = ""
			for k in acts:
				if top == "" or float(acts[k]) > float(acts[top]):
					top = str(k)
			var share = float(acts.get(top, 0.0)) / maxf(1.0, total)
			print("%-8s r%d  %s  top %s %d%%%s" % [str(arch), r, " | ".join(cells), top, _pct(share), _flag(share <= 0.6, "one action over 60%")])


func _new() -> void:
	print("--- an empty log (every stat 1) and a new log (every stat 15): level 1, the starter build, weaknesses not known ---")
	var win_n = maxi(seeds, 40)
	for v in [1.0, 15.0]:
		var hero = Sim.made({"name": "stat %d" % int(v), "raw": Sim.flat(v), "lvl": 1})
		var cells = []
		var bad = false
		for s in [1, 2, 3, 4, 5]:
			var st = RpgWorld.stage("r1s%d" % s)
			var res = Sim.run(hero, st.waves, win_n, "heuristic", {"known": false})
			cells.append("s%d %s" % [s, Sim.cell(res)])
			if float(res.win) < 0.9 and (s <= 3 or (v > 1.0 and s <= 4)):
				bad = true
		print("every stat %2d (hp %d, power %.1f against %.1f asked): %s%s" % [int(v), int(hero.hp_max), RpgHero.power(hero), float(RpgWorld.stage("r1s1").rec), " | ".join(cells),
			_flag(not bad, "90%%+ on r1s1 to r1s%d" % (3 if v <= 1.0 else 4))])
	print("--- the lopsided hero (body 45, speed 30, the rest 25) at the reference level and gear: regions 4 to 6 ---")
	for r in [4, 5, 6]:
		var cells = []
		for s in [3, 5, 7, 10]:
			var st = RpgWorld.stage("r%ds%d" % [r, s])
			var t = RpgDefs.tier_of_n(float(st.n))
			var raw = Sim.flat(25.0)
			for id in RpgDefs.BODY:
				raw[id] = 45.0
			raw["speed"] = 30.0
			var kit = RpgHero.kit_of("balanced", t)
			var hero = Sim.made({"name": "Lopsided", "raw": raw, "lvl": RpgDefs.ref_level(t), "moves": kit.moves, "ult": kit.ult, "passives": kit.passives,
				"fx": [{"p": "atk", "school": "all", "v": RpgDefs.ref_w(t)}, {"p": "armor", "v": RpgDefs.ref_armor(t)}]})
			cells.append(Sim.cell(Sim.run(hero, st.waves, seeds)))
		print("region %d: %s" % [r, " | ".join(cells)])


## A boss's row with its HP changed by `h` (an hp_pct trait, in place of its own) and its hits by `a`.
func _bent(id: String, h: float, a: float) -> Dictionary:
	var row = RpgFoes.by_id(id).duplicate(true)
	var traits = []
	for t in row.traits:
		if str(t.get("p", "")) != "hp_pct":
			traits.append(t)
	if absf(h) > 0.0001:
		traits.append({"p": "hp_pct", "pct": h})
	if absf(a) > 0.0001:
		traits.append({"p": "school_pct", "school": "all", "pct": a})
	row["traits"] = traits
	return row


func _own_hp(id: String) -> float:
	for t in RpgFoes.by_id(id).traits:
		if str(t.get("p", "")) == "hp_pct":
			return float(t.pct)
	return 0.0


func _tune() -> void:
	print("--- tune: per boss, the balanced reference hero at several hp_pct (100 seeds each): win %, turns, HP left | x1.2 | x0.7 | random ---")
	for r in range(1, 9):
		var st = RpgWorld.stage("r%ds10" % r)
		var id = str(RpgWorld.region(str(st.region)).boss)
		if not only.is_empty() and not only.has(id) and not only.has("r%d" % r):
			continue
		var hero = _ref(float(st.n))
		var now = _own_hp(id)
		var cells = []
		for d in [-0.2, -0.1, 0.0, 0.1, 0.2]:
			var h = now + d
			var opts = {"custom": {"foes": {id: _bent(id, h, 0.0)}}}
			var fin = Sim.run(hero, st.waves, 100, "heuristic", opts)
			cells.append("%+.2f: %s g%.1f" % [h, Sim.cell(fin), float(fin.guards)])
		var a = Sim.run(hero, st.waves, 100)
		var up = Sim.run(Sim.scaled(hero, 1.2), st.waves, 60)
		var down = Sim.run(Sim.scaled(hero, 0.7), st.waves, 60)
		var rnd = Sim.run(hero, st.waves, 60, "random")
		print("%-16s %s | x1.2 %d%% x0.7 %d%% random %d%% worst %d%% top %s %d%%" % [id, "  ".join(cells), _pct(float(up.win)), _pct(float(down.win)), _pct(float(rnd.win)),
			_pct(float(a.worst)), str(a.top), _pct(float(a.top_share))])


func _trace(arg: String) -> void:
	var parts = arg.split(":")
	var st = RpgWorld.stage(str(parts[0]))
	if not (st is Dictionary):
		print("trace: no stage " + arg)
		return
	var hero = _ref(float(st.n), str(parts[2]) if parts.size() > 2 else "balanced")
	if parts.size() > 2 and str(parts[2]).begins_with("player"):
		# "player" or "player+5": the player profile at the road's level (and so many levels over)
		hero = _player_hero(int(_levels(1.0)[str(st.id)]) + int(str(parts[2]).substr(6)), RpgDefs.tier_of_n(float(st.n)), PLAYER_RAW)
	if parts.size() > 4:
		hero = Sim.scaled(hero, float(parts[4]))
	var custom = {}
	if parts.size() > 3 and str(parts[3]) != "":
		var boss = str(RpgWorld.region(str(st.region)).boss)
		custom = {"foes": {boss: _bent(boss, float(parts[3]), 0.0)}}
	var B = RpgBattle.start({"hero": hero, "pet": null, "waves": st.waves.duplicate(true), "seed": int(parts[1]) if parts.size() > 1 else 1,
		"what": {"kind": "sim"}, "known": RpgFoes.all_known(), "custom": custom})
	print("--- trace %s: hero hp %d def %.1f spd %.1f moves %s ult %s ---" % [arg, int(B.hero.hp_max), float(B.hero.def), float(B.hero.spd), str(B.hero.moves), str(B.hero.ult)])
	var turn = 0
	while not RpgBattle.over(B) and turn < 200:
		var a = RpgAi.hero_action(B, "heuristic")
		var foes = []
		for f in RpgBattle.foes(B):
			var it = f.get("intent", {})
			foes.append("%s %d/%d g%d%s -> %s %d%s" % [str(f.foe), int(f.hp), int(f.hp_max), int(f.guard), " BROKEN" if bool(f.get("broken", false)) else "",
				str(it.get("move", it.get("id", "?"))), int(it.get("dmg", 0)), " (charging)" if bool(it.get("windup", false)) else ""])
		var sts = []
		for s in B.hero.statuses:
			sts.append(str(s.id))
		print("%2d  hp %3d en %d g %3d [%s]  %-22s | %s" % [turn, int(B.hero.hp), int(B.hero.en), int(B.hero.gauge), ",".join(sts),
			str(a.get("id", a.get("t", ""))) + ("" if not a.has("target") else " >" + str(a.target)), "  ".join(foes)])
		RpgBattle.act(B, a)
		turn += 1
	print("    %s after %d hero turns, hp %d" % ["WON" if RpgBattle.won(B) else "LOST", int(RpgBattle.summary(B).turns), int(B.hero.hp)])


## What the player has equipped from a fighter level on: moves his stats let him learn (checked against
## RpgSkills' nodes, RpgDefs.REQ and NODE_LEVEL when the sweep runs), mostly Pull, Legs and Grip. No ultimate:
## a tier 5 node asks for a stat of 46.
const PLAYER_KITS = [
	{"lvl": 1, "moves": ["shove", "yank", "stomp", "deep_breath"], "passives": []},
	{"lvl": 4, "moves": ["yank", "row_rip", "lunge_strike", "deep_breath"], "passives": ["grip_and_rip"]},
	{"lvl": 10, "moves": ["yank", "row_rip", "suplex", "deep_breath"], "passives": ["grip_and_rip", "hook_grip"]},
	{"lvl": 20, "moves": ["yank", "row_rip", "suplex", "deadlift_slam", "deep_breath"], "passives": ["grip_and_rip", "hook_grip", "leg_drive"]},
]
## His gear against the reference's (a kit of rares at +tier): commons and uncommons at about +tier, as ore allows.
const PLAYER_GEAR = 0.75
const PLAYER_BOOST = ["pull", 0.15]
## The Core finding: his Core 7 against a Core that never counts for less than this share of his might.
const CORE_FLOOR = 0.6


func _might(raw: Dictionary) -> float:
	var sum = 0.0
	for id in RpgDefs.BODY:
		sum += float(raw.get(id, 1.0))
	return sum / float(RpgDefs.BODY.size())


func _player_kit(level: int) -> Dictionary:
	var kit = PLAYER_KITS[0]
	for k in PLAYER_KITS:
		if int(k.lvl) <= level:
			kit = k
	return kit


## "" or why the player could not have learned it at that level.
func _cannot(ref: String, level: int, raw: Dictionary) -> String:
	var node = RpgSkills.node_of_ref(ref)
	if node == null:
		return "" if RpgMoves.STARTERS.has(ref) else ref + ": no node"
	var tier = int(node.tier)
	if level < int(RpgDefs.NODE_LEVEL[tier]):
		return "%s: level %d" % [ref, int(RpgDefs.NODE_LEVEL[tier])]
	if float(raw.get(str(node.stat), 0.0)) < float(RpgDefs.REQ[tier]):
		return "%s: %s %d" % [ref, str(node.stat), int(RpgDefs.REQ[tier])]
	return ""


func _player_hero(level: int, t: float, raw: Dictionary, gear: float = PLAYER_GEAR) -> Dictionary:
	var kit = _player_kit(level)
	for id in kit.moves + kit.passives:
		var why = _cannot(str(id), level, raw)
		if why != "":
			print("    (not learnable: %s)" % why)
	return Sim.made({"name": "Player", "raw": raw, "lvl": level, "moves": kit.moves, "passives": kit.passives,
		"fx": [{"p": "atk", "school": "all", "v": gear * RpgDefs.ref_w(t)}, {"p": "armor", "v": gear * RpgDefs.ref_armor(t)}]})


func _player() -> void:
	print("--- the player (chest 15, shoulders 37, arms 36, back 39, core 7, legs 36, speed 15, endurance 21, grip 38, mind 16, flow 16, grit 10) ---")
	print("    level = what the road's first wins have given by then; gear x%.2f of the reference's; cells: win %%, turns, HP left" % PLAYER_GEAR)
	var lv = _levels(1.0)
	var win_n = maxi(seeds, 40)
	for r in range(1, 9):
		if not only.is_empty() and not only.has("r%d" % r):
			continue
		var line = "r%d" % r
		for s in [7, 5, 10]:
			var st = RpgWorld.stage("r%ds%d" % [r, s])
			var t = RpgDefs.tier_of_n(float(st.n))
			var level = int(lv[str(st.id)])
			var hero = _player_hero(level, t, PLAYER_RAW)
			var a = Sim.run(hero, st.waves, win_n)
			var b = Sim.run(Sim.boosted(hero, str(PLAYER_BOOST[0]), float(PLAYER_BOOST[1])), st.waves, win_n)
			line += "  %s L%d (ref %d, power %d of %d): %s | boost %s" % [str(st.kind), level, RpgDefs.ref_level(t), int(RpgHero.power(hero)), int(float(st.rec)), Sim.cell(a), Sim.cell(b)]
			if s == 10:
				var over = Sim.run(Sim.boosted(_player_hero(level + 5, t, PLAYER_RAW), str(PLAYER_BOOST[0]), float(PLAYER_BOOST[1])), st.waves, win_n)
				var raw = PLAYER_RAW.duplicate()
				raw["core"] = CORE_FLOOR * _might(PLAYER_RAW)
				var core = Sim.run(_player_hero(level, t, raw), st.waves, win_n)
				var far = Sim.run(Sim.boosted(_player_hero(level + 10, t, PLAYER_RAW, 1.0), str(PLAYER_BOOST[0]), float(PLAYER_BOOST[1])), st.waves, win_n)
				line += " | +5 levels and boost %s | +10 levels, boost, the reference's gear %s | core %d, no boost %s" % [Sim.cell(over), Sim.cell(far), int(float(raw.core)), Sim.cell(core)]
		print(line)


## 1.3 x the reference hero's median turns, rounded up, for every road stage: the PAR table of rpg_world.gd.
func _par() -> void:
	print("--- par: 1.3 x the median hero turns of the balanced reference hero (paste into RpgWorld.PAR) ---")
	var line = "	"
	for st in RpgWorld.all_stages():
		if str(st.kind) == "cache":
			continue
		var res = Sim.run(_ref(float(st.n)), st.waves, seeds)
		var par = int(ceil(1.3 * float(res.turns)))
		line += "\"%s\": %d, " % [str(st.id), par]
		if int(st.s) == 10:
			print(line)
			line = "	"
