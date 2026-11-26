extends RefCounted
## The Realm's battle simulator (RPG_PLAN.md 13): many battles of one hero unit
## against a road stage or a made-up encounter, played by a policy of RpgAi.
## A library with no class_name: load it by path,
##     var Sim = load("res://tests/rpg_sim.gd")
## and call its static functions. Pure: no autoload, no file, no screen.
##
##   fight(hero, waves, seed, policy = "heuristic", opts = {}) -> one battle:
##       {"over", "win", "turns" (hero turns), "hp" (share left, 0 after a loss), "breaks", "worst" (the largest
##        single hit as a share of max HP), "guards", "acts": {key: count} ("strike", "guard", "ult", "item" or a
##        move id; the companion's command is free and is not counted), "refused"}
##       opts: "known" (default true: every weakness known, RpgFoes.all_known()), "pet": unit or null,
##             "rules": [ids], "custom": {...}
##   run(hero, waves, seeds, policy = "heuristic", opts = {}) -> the same fights added up:
##       {"n", "wins", "win" (0..1), "turns" (median hero turns of the wins, else of all), "hp" (median share left,
##        over all fights), "hp_win" (median over the wins), "breaks" (mean a fight), "worst" (the largest hit of
##        any fight), "worst_med" (the median fight's largest hit), "guards" (mean a fight), "share": {key: share of
##        all actions}, "top" (the key with the largest share), "top_share", "bad" (not finished, or an action refused)}
##       opts also: "seed" (the first seed; fight i uses seed + i * 7919)
##   stage_waves(stage id) -> the waves of a road stage ([] for a cache or an unknown id)
##   scaled(hero, factor) -> a copy with its offence and its HP both times `factor` (so RpgHero.power times
##       `factor`): every hit through a school_pct "all" passive, max HP directly
##   boosted(hero, school, pct) -> a copy with "+pct on that school's moves" (a day's boost)
##   made(spec) -> a hero unit from raw stats (RpgHero._assemble): spec = {"name", "raw": {stat: v}, "lvl",
##       "moves", "ult", "passives": [ids], "fx": [more passive effects], "belt"}
##   flat(v) -> raw stats with every stat at v
##   cell(r) -> "100% 5t 82%" (win rate, median turns, median HP left)
##   median(list) -> float

const ACTS_MOST = 600
const SEED_STEP = 7919


static func median(list: Array) -> float:
	if list.is_empty():
		return 0.0
	var a = list.duplicate()
	a.sort()
	return float(a[int(floor(float(a.size()) / 2.0))])


static func stage_waves(stage_id: String) -> Array:
	var st = RpgWorld.stage(stage_id)
	if not (st is Dictionary):
		return []
	return st.get("waves", []).duplicate(true)


static func flat(v: float) -> Dictionary:
	var raw = {}
	for id in RpgDefs.STATS:
		raw[id] = v
	return raw


static func made(spec: Dictionary) -> Dictionary:
	var fx = []
	for e in spec.get("fx", []):
		fx.append(e)
	for id in spec.get("passives", []):
		var row = RpgPassives.by_id(str(id))
		if row != null:
			fx.append_array(RpgHero._fx_of(row))
	var moves = []
	for id in spec.get("moves", RpgMoves.FIRST_BUILD):
		if RpgMoves.by_id(str(id)) != null:
			moves.append(str(id))
	return RpgHero._assemble({"name": str(spec.get("name", "Hero")), "raw": spec.get("raw", {}), "lvl": int(spec.get("lvl", 1)),
		"fx": fx, "moves": moves, "ult": str(spec.get("ult", "")), "belt": spec.get("belt", []), "pet": ""})


static func scaled(hero: Dictionary, factor: float) -> Dictionary:
	var h = hero.duplicate(true)
	h["hp_max"] = maxi(1, int(round(float(h.hp_max) * factor)))
	h["hp"] = h.hp_max
	h.fx.append({"p": "school_pct", "school": "all", "pct": factor - 1.0})
	return h


static func boosted(hero: Dictionary, school: String, pct: float) -> Dictionary:
	var h = hero.duplicate(true)
	h.fx.append({"p": "school_pct", "school": school, "pct": pct})
	return h


static func _key(a: Dictionary) -> String:
	var t = str(a.get("t", ""))
	return str(a.get("id", "")) if t == "move" else t


static func fight(hero: Dictionary, waves: Array, fight_seed: int, policy: String = "heuristic", opts: Dictionary = {}) -> Dictionary:
	var setup = {"hero": hero.duplicate(true), "pet": opts.get("pet"), "waves": waves.duplicate(true), "seed": fight_seed,
		"what": {"kind": "sim"}, "rules": opts.get("rules", []), "custom": opts.get("custom", {})}
	if bool(opts.get("known", true)):
		setup["known"] = RpgFoes.all_known()
	var B = RpgBattle.start(setup)
	var acts = {}
	var count = 0
	var refused = 0
	while not RpgBattle.over(B) and count < ACTS_MOST:
		var a = RpgAi.hero_action(B, policy)
		var ev = RpgBattle.act(B, a)
		count += 1
		if ev.size() == 1 and str(ev[0].get("t", "")) == "no":
			refused += 1
			continue
		var k = _key(a)
		if k != "pet":
			acts[k] = int(acts.get(k, 0)) + 1
	var s = RpgBattle.summary(B)
	var win = RpgBattle.won(B)
	return {"over": RpgBattle.over(B), "win": win, "turns": int(s.turns), "breaks": int(s.breaks), "guards": int(s.guards),
		"worst": float(s.worst_share), "acts": acts, "refused": refused,
		"hp": clampf(float(B.hero.hp) / maxf(1.0, float(B.hero.hp_max)), 0.0, 1.0) if win else 0.0}


static func run(hero: Dictionary, waves: Array, seeds: int, policy: String = "heuristic", opts: Dictionary = {}) -> Dictionary:
	var base = int(opts.get("seed", 1000))
	var wins = 0
	var bad = 0
	var turns_won = []
	var turns_all = []
	var hps = []
	var hps_won = []
	var worsts = []
	var breaks = 0
	var guards = 0
	var worst = 0.0
	var acts = {}
	var total = 0
	for i in range(seeds):
		var r = fight(hero, waves, base + i * SEED_STEP, policy, opts)
		if not bool(r.over) or int(r.refused) > 0:
			bad += 1
		turns_all.append(int(r.turns))
		hps.append(float(r.hp))
		worsts.append(float(r.worst))
		breaks += int(r.breaks)
		guards += int(r.guards)
		worst = maxf(worst, float(r.worst))
		if bool(r.win):
			wins += 1
			turns_won.append(int(r.turns))
			hps_won.append(float(r.hp))
		for k in r.acts:
			acts[k] = int(acts.get(k, 0)) + int(r.acts[k])
			total += int(r.acts[k])
	var share = {}
	var top = ""
	var top_share = 0.0
	for k in acts:
		share[k] = float(acts[k]) / float(maxi(1, total))
		if float(share[k]) > top_share:
			top_share = float(share[k])
			top = str(k)
	var n = maxi(1, seeds)
	return {"n": seeds, "wins": wins, "win": float(wins) / float(n),
		"turns": int(median(turns_won if not turns_won.is_empty() else turns_all)),
		"hp": median(hps), "hp_win": median(hps_won), "breaks": float(breaks) / float(n), "guards": float(guards) / float(n),
		"worst": worst, "worst_med": median(worsts), "share": share, "top": top, "top_share": top_share, "bad": bad}


static func cell(r: Dictionary) -> String:
	return "%3d%% %2dt %3d%%" % [int(round(float(r.win) * 100.0)), int(r.turns), int(round(float(r.hp) * 100.0))]
