extends SceneTree
## Unit test for the Realm's world and its rewards (RPG_PLAN.md 8.1, 8.2, 8.4):
## game/rpg/rpg_world.gd (RpgWorld) and game/rpg/rpg_loot.gd (RpgLoot). The 80
## road stages and their layout rules, the stars, what is open, the daily
## hunt, the weekly rival, the Spire, the echoes, a setup of every kind taken
## by the engine and fought to its end, and what a win pays.
## Made-up saves, dates and weekly records only; nothing here reads a save.
##   godot --headless --path . --script res://tests/rpg_world_test.gd
## Prints RPG WORLD: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0

const THIRDS = ["break", "no_items", "hp_half", "no_guard", "schools3", "no_big_hit"]
const DAY = "2031-03-04"


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_road()
	_stars()
	_opening()
	_beyond()
	_battles()
	_loot()
	# --- move mastery goes into a fight as rows of the battle ---------------------------------------------
	var mh = RpgHero.reference_hero(1.0)
	var mrpg = RpgSave.first_open(RpgSave.empty(), {}, "")
	var mid = str(mh.moves[0])
	mrpg["mastery"] = {mid: RpgDefs.MASTERY_AT[1]}
	var with_m = RpgWorld.setup({"kind": "stage", "id": "r1s1"}, mrpg, mh, null, 5, "2026-01-05")
	var none_m = RpgWorld.setup({"kind": "stage", "id": "r1s1"}, RpgSave.first_open(RpgSave.empty(), {}, ""), mh, null, 5, "2026-01-05")
	var row_m = with_m.get("custom", {}).get("moves", {}).get(mid)
	ok(row_m is Dictionary and none_m.get("custom", {}).get("moves", {}).get(mid) == null, "a move with mastery is brought to the fight as a row of its own; one without is not", with_m.get("custom", {}).keys())
	if row_m is Dictionary:
		var Bm = RpgBattle.start(with_m)
		var B0 = RpgBattle.start(none_m)
		var kind_m = RpgMoves.mastery_kind(mid)
		var got_p = float(RpgBattle.move_row(Bm, mid).get("power", 0.0))
		var base_p = float(RpgBattle.move_row(B0, mid).get("power", 0.0))
		ok(kind_m != "power" or absf(got_p - base_p * (1.0 + 2.0 * RpgDefs.MASTERY_PCT)) < 0.0001, "and the battle plays it at its level (%s: %s against %s)" % [mid, str(got_p), str(base_p)])
		RpgBattle.act(Bm, {"t": "move", "id": mid, "target": str(RpgBattle.foes(Bm)[0].id)})
		ok(int(RpgBattle.summary(Bm).moves.get(mid, 0)) == 1, "the summary of a fight says how often each move was used", RpgBattle.summary(Bm).moves)
	# --- a dare: a won stage again, at the reach of the player, with a rule -----------------------------
	var drpg = RpgSave.first_open(RpgSave.empty(), {}, "")
	ok(RpgWorld.dare("r1s1", drpg) == null and RpgWorld.stage_of({"kind": "dare", "id": "dare:r1s1"}, drpg) == null and not RpgWorld.is_open(drpg, "dare:r1s1"), "a stage not won has no dare")
	for ds in ["r1s1", "r1s2", "r1s3", "r1s4", "r1s5"]:
		drpg.stages[ds] = {"stars": [true, false, false], "wins": 1, "best": 3}
	drpg.caches["r1s6"] = true
	var d1 = RpgWorld.dare("r1s1", drpg)
	var src1 = RpgWorld.stage("r1s1")
	ok(d1 is Dictionary and d1.id == "dare:r1s1" and d1.kind == "dare" and d1.of == "r1s1" and absf(float(d1.n) - (RpgWorld.best_n(drpg) + RpgWorld.DARE_OVER)) < 0.001 and float(d1.n) > float(src1.n)
		and d1.rules.size() == 1 and RpgWorld.RULES.has(d1.rules[0]) and d1.stars.is_empty() and int(d1.first.ore) > 0 and d1.waves.size() == src1.waves.size() and float(d1.waves[0][0].n) == float(d1.n)
		and str(d1.waves[0][0].foe) == str(src1.waves[0][0].foe), "a dare is the stage's own foes at the highest index won + DARE_OVER, with one rule and a first prize", [d1.n if d1 is Dictionary else null, RpgWorld.best_n(drpg)])
	ok(RpgWorld.dare("r1s6", drpg) == null and RpgWorld.dare("e1s1", drpg) == null and RpgWorld.dare("nope", drpg) == null and RpgWorld.is_open(drpg, "dare:r1s1")
		and RpgWorld.stage_of({"kind": "dare", "id": "dare:r1s5"}, drpg).of_kind == "elite" and bool(RpgWorld.stage_of({"kind": "dare", "id": "dare:r1s5"}, drpg).first.rune), "no dare for a cache, an echo or nothing; an elite's dare also pays a rune")
	var dset = RpgWorld.setup({"kind": "dare", "id": "dare:r1s1"}, drpg, RpgHero.reference_hero(2.0), null, 9, "2026-01-05")
	ok(not dset.is_empty() and dset.what == {"kind": "dare", "id": "dare:r1s1"} and dset.rules == d1.rules, "it goes to the engine like any stage", dset.get("what"))
	ok(RpgLoot.is_first(d1, drpg) and not RpgWorld.dared(drpg, "r1s1") and RpgWorld.dare_count(drpg) == 0, "its first win is still to come")
	var dwin = RpgSave.finish(drpg, {"kind": "dare", "id": "dare:r1s1"}, d1, RpgLoot.rewards(d1, {"win": true, "turns": 4}, drpg, 1, [], 3), {"win": true, "turns": 4}, "2026-01-05")
	ok(bool(dwin.ok) and RpgWorld.dared(dwin.rpg, "r1s1") and RpgWorld.dare_count(dwin.rpg) == 1 and int(dwin.rpg.ore) >= int(drpg.ore) + int(d1.first.ore) and not RpgLoot.is_first(RpgWorld.dare("r1s1", dwin.rpg), dwin.rpg)
		and int(dwin.rpg.stages.r1s1.wins) == 1 and dwin.rpg.stages.r1s1.stars == [true, false, false], "a dare won is a seal on its stage and pays its prize once; the stage's own record is not touched", dwin.rpg.stages.get("r1s1"))
	var again = RpgSave.finish(dwin.rpg, {"kind": "stage", "id": "r1s1"}, src1, {}, {"win": true, "turns": 2}, "2026-01-05")
	ok(bool(again.ok) and RpgWorld.dared(again.rpg, "r1s1") and int(again.rpg.stages.r1s1.wins) == 2 and RpgWorld.dared(RpgSave.parse(again.rpg), "r1s1"), "the seal stays when the stage is won again, and in the save file")
	ok(not bool(RpgSave.finish(RpgSave.first_open(RpgSave.empty(), {}, ""), {"kind": "dare", "id": "dare:r1s1"}, d1, {}, {"win": true, "turns": 4}, "2026-01-05").ok), "a dare of a stage not won cannot be paid")
	ok(int(RpgFeats.counts(dwin.rpg).dares) == 1, "the feats count the dares won")
	print("RPG WORLD: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


## A save that has won these stages (and taken these caches).
func won(ids: Array, caches: Array = []) -> Dictionary:
	var rpg = RpgSave.empty()
	for id in ids:
		rpg.stages[id] = {"stars": [true, false, false], "wins": 1, "best": 9}
	for id in caches:
		rpg.caches[id] = true
	return rpg


## A save that has cleared the road up to and with region `r`.
func cleared(r: int) -> Dictionary:
	var ids = []
	var caches = []
	for st in RpgWorld.all_stages():
		if int(st.r) <= r:
			if str(st.kind) == "cache":
				caches.append(st.id)
			else:
				ids.append(st.id)
	return won(ids, caches)


func summary(over: Dictionary = {}) -> Dictionary:
	var s = {"win": true, "turns": 5, "dealt": 100, "taken": 10, "breaks": 0, "items": 0, "guards": 0, "schools": ["push"],
		"worst_share": 0.1, "hp_share": 0.9, "learned": {}, "used": {}, "reward": {"ore": 0.0, "xp": 0.0, "luck": 0.0}}
	for k in over:
		s[k] = over[k]
	return s


func has_big_hit(foe_id: String) -> bool:
	for m in RpgFoes.by_id(foe_id).moves:
		var mv = RpgFoes.move(str(m))
		if int(mv.windup) == 1 or int(mv.count) > 0:
			return true
	return false


func summons(boss_id: String) -> Array:
	var out = []
	var f = RpgFoes.by_id(boss_id)
	for m in f.moves:
		out.append_array(RpgFoes.move(str(m)).foes)
	for ph in f.phases:
		out.append_array(ph.get("summon", []))
	return out


# --- the road ------------------------------------------------------------------

func _road() -> void:
	var regions = RpgWorld.regions()
	ok(regions.size() == 8 and regions.map(func(r): return r.id) == RpgDefs.REGIONS, "eight regions in the plan's order")
	var all = RpgWorld.all_stages()
	ok(all.size() == 80, "80 road stages", all.size())
	var bad = []
	var shape = []
	var unknown = []
	var early = []
	var star_bad = []
	var first_bad = []
	var scrolls = RpgMoves.scrolls()
	var got_scrolls = []
	var relics = []
	for reg in regions:
		var r = int(reg.r)
		if str(reg.name) != str(RpgDefs.REGION_NAMES[reg.id]) or str(reg.scene) != str(reg.id) or str(reg.teaches) == "" \
				or str(reg.blurb).split(". ").size() != 2 or reg.stages.size() != 10 or RpgWorld.region(str(reg.id)) != reg:
			bad.append(reg.id)
		var cat = RpgFoes.of_region(str(reg.id))
		var met = {}
		var used = {}
		var thirds = {}
		for st in reg.stages:
			var s = int(st.s)
			var id = "r%ds%d" % [r, s]
			var kind = "elite" if s == 5 else ("cache" if s == 6 else ("boss" if s == 10 else "battle"))
			if str(st.id) != id or int(st.n) != 10 * (r - 1) + (s - 1) or str(st.kind) != kind or str(st.region) != str(reg.id) \
					or str(st.name) == "" or str(st.text) == "" or str(st.scene) != str(reg.id) or bool(st.echo) or not st.rules.is_empty() \
					or RpgWorld.stage(id) != st or RpgWorld.region_of(id) != str(reg.id):
				bad.append(id)
			var sizes = st.waves.map(func(w): return w.size())
			var fine = true
			match s:
				1:
					fine = sizes.size() == 1 and sizes[0] >= 1 and sizes[0] <= 2
				2, 3, 4:
					fine = sizes.size() == 1 and sizes[0] >= 2 and sizes[0] <= 3
				5:
					fine = sizes.size() == 1 and sizes[0] <= 2 and str(st.waves[0][0].foe) == str(cat.elite)
				6:
					fine = sizes.is_empty() and st.stars.is_empty() and int(st.par) == 0
				7, 9:
					fine = sizes == [3]
				8:
					fine = sizes.size() == 2 and sizes[1] == 3
				10:
					fine = sizes.size() == 1 and str(st.waves[0][0].foe) == str(cat.boss)
					for i in range(1, st.waves[0].size()):
						if not summons(str(cat.boss)).has(str(st.waves[0][i].foe)):
							fine = false
			if not fine:
				shape.append(id)
			for wave in st.waves:
				if wave.size() > RpgDefs.FOES_MAX:
					shape.append(id + " too many")
				for en in wave:
					var fid = str(en.foe)
					var row = RpgFoes.by_id(fid)
					if row == null or str(row.region) != str(reg.id) or float(en.n) != float(st.n):
						unknown.append("%s %s" % [id, fid])
						continue
					if (bool(row.boss) and s != 10) or (bool(row.elite) and s != 5):
						shape.append(id + " a big one out of place")
					# a foe new to the region: alone or in a pair first
					if not met.has(fid) and wave.size() > 2:
						early.append("%s %s" % [id, fid])
					used[fid] = true
				for en in wave:
					met[str(en.foe)] = true
			if kind == "cache":
				continue
			# stars: win, turns at par, one of the rest that fits the stage
			var third = str(st.stars[2].k) if st.stars.size() == 3 else ""
			thirds[third] = true
			var foes = []
			for wave in st.waves:
				for en in wave:
					if not foes.has(str(en.foe)):
						foes.append(str(en.foe))
			# the balance step's own par for the stage (RpgWorld.PAR): at least 2 turns a wave, at most 30
			var par = int(RpgWorld.PAR.get(str(st.id), -1))
			if par < 2 * st.waves.size() or par > 30:
				star_bad.append("%s: par %d" % [str(st.id), par])
			if st.stars.size() != 3 or str(st.stars[0].k) != "win" or str(st.stars[1].k) != "turns" or int(st.stars[1].v) != par \
					or int(st.par) != par or not THIRDS.has(third):
				star_bad.append(id)
			elif third == "no_big_hit" and not foes.any(func(f): return has_big_hit(f)):
				star_bad.append(id + " no wind-up here")
			elif third == "schools3" and foes.size() < 2:
				star_bad.append(id + " no mixed pack")
			if absf(float(st.rec) - RpgHero.power(RpgHero.reference_hero(RpgDefs.tier_of_n(float(st.n))))) > 0.06:
				bad.append(id + " rec")
			# the first win
			var f = st.first
			for it in f.items:
				if RpgItems.by_id(str(it.id)) == null or int(it.n) < 1:
					first_bad.append(id + " item")
			if kind == "elite":
				got_scrolls.append(str(f.scroll))
				if str(f.scroll) != str(scrolls[2 * (r - 1)].id) or f.items.is_empty():
					first_bad.append(id + " scroll")
			elif str(f.scroll) != "":
				first_bad.append(id + " a scroll off an elite")
			if kind == "boss":
				relics.append(str(f.relic))
				if RpgRelics.by_id(str(f.relic)) == null or not bool(f.rune):
					first_bad.append(id + " relic")
			elif str(f.relic) != "" or bool(f.rune):
				first_bad.append(id + " a relic off a boss")
		for fid in cat.regular + [cat.elite, cat.boss]:
			if not used.has(fid):
				unknown.append("%s never met: %s" % [reg.id, fid])
		if thirds.size() < 4:
			star_bad.append("%s: only %d kinds of third star" % [reg.id, thirds.size()])
		got_scrolls.append(str(RpgLoot.star_chest(str(reg.id), 16, 1).scroll))
	ok(bad.is_empty(), "ids, n, kind, name, story, scene and rec of every stage", bad)
	ok(shape.is_empty(), "the layout: 1-2 foes, packs, the elite at 5, a cache at 6, threes at 7 and 9, two waves at 8, the boss at 10", shape)
	ok(unknown.is_empty(), "every foe is the region's own, and every one of the region's foes is met", unknown)
	ok(early.is_empty(), "a foe new to a region is met alone or in a pair before a pack of three", early)
	ok(star_bad.is_empty(), "stars: win, turns at the stage's measured par (RpgWorld.PAR), a third that fits; four kinds of third or more a region", star_bad)
	ok(first_bad.is_empty(), "first rewards: an elite a scroll and items, a boss a relic and a rune", first_bad)
	var want = scrolls.map(func(m): return str(m.id))
	got_scrolls.sort()
	want.sort()
	ok(got_scrolls == want and want.size() == 16, "the 16 scroll moves: one from each elite, one from each region's 16-star chest", got_scrolls)
	var uniq = {}
	for id in relics:
		uniq[id] = true
	ok(uniq.size() == 8 and relics == RpgWorld.BOSS_RELICS, "eight bosses, eight different relics", relics)
	var one = RpgWorld.stage("r1s1")
	ok(one.waves == [[{"foe": "dust_bunny", "n": 0.0}]] and str(one.stars[2].k) == "break", "r1s1 is one Dust Bunny, and its star is the guard break", one.waves)
	ok(RpgWorld.stage("nope") == null and RpgWorld.stage("r9s1") == null and RpgWorld.region("nope") == null and RpgWorld.region_of("hunt:x") == "", "an id nobody knows: null")
	# the chain of stages
	var chain = ["r1s1"]
	while RpgWorld.next_stage(chain[chain.size() - 1]) != "" and chain.size() < 200:
		chain.append(RpgWorld.next_stage(chain[chain.size() - 1]))
	ok(chain == all.map(func(st): return st.id) and RpgWorld.next_stage("r8s10") == "" and RpgWorld.next_stage("spire:3") == "", "next_stage walks the 80 in order and stops")
	var rules_ok = RpgWorld.RULES.keys() == RpgBattle.RULES.keys() and RpgWorld.RULE_IDS == RpgBattle.RULES.keys()
	for id in RpgWorld.RULES:
		if str(RpgWorld.RULES[id].name) == "" or str(RpgWorld.RULES[id].text) != str(RpgBattle.RULES.get(id, "")):
			rules_ok = false
	ok(rules_ok, "RULES are exactly the engine's, each with a name and the engine's words", RpgWorld.RULES.keys())


# --- stars ---------------------------------------------------------------------

func _stars() -> void:
	var st = {"stars": [RpgWorld.objective("win"), RpgWorld.objective("turns", 12), RpgWorld.objective("break")]}
	ok(RpgWorld.stars(st, summary({"turns": 12, "breaks": 1})) == [true, true, true], "win, 12 turns of 12, one break: three stars")
	ok(RpgWorld.stars(st, summary({"turns": 13})) == [true, false, false], "13 turns of 12 and no break: one star")
	ok(RpgWorld.stars(st, summary({"win": false, "turns": 3, "breaks": 4})) == [false, false, false], "a loss: none, whatever else went well")
	ok(RpgWorld.stars(RpgWorld.stage("r1s6"), summary()) == [false, false, false], "a cache has no stars")
	var cases = [
		["no_items", {"items": 0}, {"items": 1}], ["hp_half", {"hp_share": 0.5}, {"hp_share": 0.49}],
		["no_guard", {"guards": 0}, {"guards": 2}], ["schools3", {"schools": ["push", "pull", "mind"]}, {"schools": ["push", "pull"]}],
		["no_big_hit", {"worst_share": 0.25}, {"worst_share": 0.31}], ["break", {"breaks": 2}, {"breaks": 0}],
		["turns", {"turns": 6}, {"turns": 7}],
	]
	var wrong = []
	for c in cases:
		var obj = RpgWorld.objective(str(c[0]))
		if not RpgWorld.met(obj, summary(c[1])) or RpgWorld.met(obj, summary(c[2])) or RpgWorld.objective_words(obj) == "":
			wrong.append(c[0])
	ok(wrong.is_empty(), "every kind of objective: met by a summary that does it, not by one that does not", wrong)
	ok(RpgWorld.objective_words(RpgWorld.objective("turns", 12)) == "Win in 12 turns or fewer" and RpgWorld.objective_words(RpgWorld.objective("win")) == "Win the fight"
		and RpgWorld.objective_words(RpgWorld.objective("break", 2)) == "Break 2 guards" and RpgWorld.objective_words({"k": "nope"}) == "", "objectives in plain words",
		RpgWorld.objective_words(RpgWorld.objective("no_big_hit")))
	var rpg = RpgSave.empty()
	rpg.stages["r1s1"] = {"stars": [true, true, false], "wins": 2, "best": 4}
	rpg.stages["r1s2"] = {"stars": [true, false, true], "wins": 1, "best": 7}
	rpg.stages["r2s1"] = {"stars": [true, true, true], "wins": 1, "best": 5}
	rpg.stages["e1s1"] = {"stars": [true, true, true], "wins": 1, "best": 5}
	ok(RpgWorld.star_count(rpg, "rustyard") == 4 and RpgWorld.star_count(rpg, "greenmile") == 3 and RpgWorld.star_count(rpg, "chalk") == 0
		and RpgWorld.star_count(rpg, "nope") == 0, "star_count: a region's road stars (an echo's are not the region's)")


# --- what is open -----------------------------------------------------------------

func _opening() -> void:
	var fresh = RpgSave.empty()
	ok(RpgWorld.is_open(fresh, "r1s1") and not RpgWorld.is_open(fresh, "r1s2") and not RpgWorld.is_open(fresh, "r2s1") and not RpgWorld.is_open(fresh, "nope"), "a new save: only r1s1 is open")
	ok(RpgWorld.best_n(fresh) == 0.0 and not RpgWorld.spire_open(fresh) and not RpgWorld.echoes_open(fresh), "and nothing beyond the road")
	var a = won(["r1s1", "r1s2", "r1s3", "r1s4"])
	ok(RpgWorld.is_open(a, "r1s5") and not RpgWorld.is_open(a, "r1s6") and RpgWorld.best_n(a) == 3.0, "a stage opens when the one before it is won")
	var b = won(["r1s1", "r1s2", "r1s3", "r1s4", "r1s5"])
	ok(RpgWorld.is_open(b, "r1s6") and not RpgWorld.is_open(b, "r1s7") and not RpgWorld.done(b, "r1s6"), "the cache opens after the elite; the stage after it waits for the cache")
	b.caches["r1s6"] = true
	ok(RpgWorld.is_open(b, "r1s7") and RpgWorld.done(b, "r1s6"), "a cache taken opens the next stage")
	var c = cleared(1)
	ok(RpgWorld.is_open(c, "r2s1") and not RpgWorld.is_open(c, "r3s1") and RpgWorld.best_n(c) == 9.0 and not RpgWorld.spire_open(c), "a region opens when the boss before it falls")
	var d = cleared(2)
	ok(RpgWorld.spire_open(d) and RpgWorld.is_open(d, "spire:1") and not RpgWorld.is_open(d, "spire:2") and not RpgWorld.is_open(c, "spire:1"), "the Spire opens after region 2, one floor at a time")
	d.spire.best = 4
	ok(RpgWorld.is_open(d, "spire:5") and RpgWorld.is_open(d, "spire:2") and not RpgWorld.is_open(d, "spire:6"), "floors up to the next one after the best")
	var e = cleared(8)
	ok(RpgWorld.echoes_open(e) and RpgWorld.is_open(e, "e1s1") and not RpgWorld.is_open(e, "e1s2") and not RpgWorld.is_open(e, "e2s1") and not RpgWorld.is_open(cleared(7), "e1s1"),
		"the echoes open after the Hollow Titan, and go on like the road")
	e.stages["e1s1"] = {"stars": [true, false, false], "wins": 1, "best": 9}
	ok(RpgWorld.is_open(e, "e1s2") and RpgWorld.best_n(e) == 80.0, "an echo won opens the next; best_n counts it")
	ok(RpgWorld.is_open(fresh, "hunt:" + DAY) and RpgWorld.is_open(fresh, "rival:2031-03-03"), "a hunt and a rival are never shut")


# --- beyond the road ----------------------------------------------------------------

func _beyond() -> void:
	# the daily hunt
	var rpg = cleared(2)
	var h = RpgWorld.hunt(DAY, rpg, [])
	ok(JSON.stringify(h) == JSON.stringify(RpgWorld.hunt(DAY, rpg, [])), "the hunt: the same date gives the same hunt")
	var differs = 0
	for i in range(1, 9):
		var other = RpgWorld.hunt("2031-03-%02d" % (4 + i), rpg, [])
		if JSON.stringify(other.waves) != JSON.stringify(h.waves) or str(other.rule) != str(h.rule):
			differs += 1
	ok(differs >= 6, "another date, another hunt", differs)
	ok(str(h.id) == "hunt:" + DAY and str(h.kind) == "hunt" and str(h.scene) == "hunt" and float(h.n) == 19.0 + 2.0 and h.waves.size() == 1
		and h.waves[0].size() == 3 and RpgWorld.RULES.has(str(h.rule)) and h.rules == [h.rule] and str(h.date) == DAY and float(h.rec) > 0.0, "its shape: one pack at the best n + 2, one rule", h)
	var pool = RpgFoes.of_region("rustyard").regular + RpgFoes.of_region("greenmile").regular + RpgFoes.of_region("chalk").regular
	var hunt_bad = []
	for en in h.waves[0]:
		if not pool.has(str(en.foe)) or en.weak != h.weak or float(en.n) != float(h.n):
			hunt_bad.append(en)
	ok(hunt_bad.is_empty() and h.weak.size() == 2 and h.weak[0] != h.weak[1], "its foes are regulars of the regions reached, all weak to the day's two schools", hunt_bad)
	ok(h.prizes.size() == 3 and h.prizes.map(func(p): return p.kind) == ["ore", "items", "rune"], "three prizes to pick from: ore, items, a rune", h.prizes)
	var boosts = [{"id": "pump_legs", "fx": [{"p": "stat_dmg", "stat": "legs", "pct": 0.2}]}, {"id": "second_wind", "fx": [{"p": "school_pct", "school": "speed", "pct": 0.1}]}]
	ok(RpgBoosts.schools(boosts) == ["legs", "speed"] and RpgWorld.hunt(DAY, rpg, boosts).weak == ["legs", "speed"], "the hunt follows the boosts: its foes are weak to their schools", RpgWorld.hunt(DAY, rpg, boosts).weak)
	var one = RpgWorld.hunt(DAY, rpg, [{"id": "sharp_mind", "fx": [{"p": "school_pct", "school": "mind", "pct": 0.08}]}]).weak
	ok(one[0] == "mind" and one.size() == 2 and one[1] != "mind", "one school from the boosts: the other by the date", one)
	var first = RpgWorld.hunt(DAY, RpgSave.empty(), [])
	ok(float(first.n) == 2.0 and first.waves[0].all(func(en): return RpgFoes.of_region("rustyard").regular.has(str(en.foe))), "before any win: the Rustyard's own, at n 2")

	# the weekly rival
	ok(RpgWorld.rival({}, rpg) == null and RpgWorld.rival({"weekly": {"current": null}}, rpg) == null and RpgWorld.rival({"weekly": {"current": {"week": "", "monster": ""}}}, rpg) == null, "no bounty this week: no rival")
	var parts = {"legs": ["legs"], "chest": ["push"], "shoulders": ["push"], "back": ["pull"], "arms": ["push", "pull"], "core": ["legs"]}
	var rival_bad = []
	for part in parts:
		var rv = RpgWorld.rival({"weekly": {"current": {"week": "2031-03-03", "monster": "wk_ogre", "weakPart": part, "hp": 900}}}, rpg)
		var row = rv.waves[0][0].row if rv != null else {}
		var why = RpgBattle.check_foe(row) if rv != null else "null"
		if (rv == null or why != "" or str(rv.id) != "rival:2031-03-03" or str(rv.kind) != "rival" or str(rv.scene) != "rival" or float(rv.n) != 24.0
				or str(row.id) != "wk_ogre" or str(row.name) != str(Bounty.monster("wk_ogre").name) or not bool(row.boss) or str(row.role) != "boss"
				or rv.weak.size() != 2 or rv.weak[0] == rv.weak[1] or not parts[part].all(func(sc): return rv.weak.has(sc)) or rv.waves[0][0].weak != rv.weak
				or not rv.custom.foes.has("wk_ogre") or str(rv.name) != str(row.name)):
			rival_bad.append([part, why, rv.weak if rv != null else null])
	ok(rival_bad.is_empty(), "the rival: the week's monster as a boss at the best n + 5, weak to the schools of its weak part, a well formed foe", rival_bad)
	var every = []
	for m in Bounty.MONSTERS:
		var rv = RpgWorld.rival({"weekly": {"current": {"week": "2031-03-03", "monster": m.id, "weakPart": "back"}}}, RpgSave.empty())
		if rv == null or RpgBattle.check_foe(rv.waves[0][0].row) != "" or str(rv.monster) != str(m.id):
			every.append(m.id)
	ok(every.is_empty() and Bounty.MONSTERS.size() >= 18, "every bounty monster makes a rival", every)

	# the Spire
	ok(RpgWorld.spire_n(1) == 12.0 and RpgWorld.spire_n(35) == 80.0 and RpgWorld.spire_n(36) == 80.5 and RpgWorld.spire_n(45) == 85.0, "Spire floors: 10 + 2 a floor to 35, then half a point")
	var spire_bad = []
	for f in range(1, 61):
		var sp = RpgWorld.spire(f)
		var wave = sp.waves[0] if sp.waves.size() == 1 else []
		var rows = wave.map(func(en): return RpgFoes.by_id(str(en.foe)))
		var fine = str(sp.id) == "spire:%d" % f and str(sp.kind) == "spire" and str(sp.scene) == "spire" and int(sp.floor) == f and float(sp.n) == RpgWorld.spire_n(f) \
			and not rows.has(null) and wave.size() >= 1 and wave.size() <= 3 and JSON.stringify(sp) == JSON.stringify(RpgWorld.spire(f)) and JSON.stringify(RpgWorld.stage("spire:%d" % f)) == JSON.stringify(sp)
		if fine:
			if f % 10 == 0:
				fine = bool(rows[0].boss) and wave.size() == 1 and bool(sp.first.rune)
			elif f % 5 == 0:
				fine = bool(rows[0].elite) and wave.size() <= 2 and rows.filter(func(r): return bool(r.elite) or bool(r.boss)).size() == 1 and bool(sp.first.rune)
			else:
				fine = wave.size() == 3 and not rows.any(func(r): return bool(r.elite) or bool(r.boss)) and not bool(sp.first.rune)
		if not fine:
			spire_bad.append(f)
	ok(spire_bad.is_empty(), "sixty floors: a fixed pack each, an elite every fifth, a boss every tenth", spire_bad)
	ok(RpgWorld.spire(10).waves[0][0].foe == "old_iron_jaw" and RpgWorld.spire(80).waves[0][0].foe == "the_hollow_titan" and RpgWorld.spire(90).waves[0][0].foe == "old_iron_jaw", "the road's bosses in turn, round and round")

	# the echoes
	var echoes = RpgWorld.echo_stages()
	var echo_bad = []
	var rules_used = {}
	for i in range(echoes.size()):
		var ec = echoes[i]
		var src = RpgWorld.all_stages()[i]
		var r = int(ec.r)
		var s = int(ec.s)
		var fine = str(ec.id) == "e%ds%d" % [r, s] and absf(float(ec.n) - (80.0 + 3.0 * (r - 1) + 0.3 * (s - 1))) < 0.0001 and str(ec.kind) == str(src.kind) and bool(ec.echo) \
			and str(ec.region) == str(src.region) and ec.waves.size() == src.waves.size() and RpgWorld.stage(str(ec.id)) == ec and str(ec.text) != ""
		if fine and str(ec.kind) == "cache":
			fine = ec.rules.is_empty() and ec.stars.is_empty()
		elif fine:
			fine = ec.rules.size() == 1 and RpgWorld.RULES.has(str(ec.rules[0])) and ec.stars.size() == 3 and int(ec.par) >= RpgWorld.par_of(ec) and int(ec.stars[1].v) == int(ec.par) and int(ec.par) >= int(src.par) and float(ec.rec) > float(src.rec)
			rules_used[str(ec.rules[0])] = true
			for w in range(ec.waves.size()):
				for j in range(ec.waves[w].size()):
					if str(ec.waves[w][j].foe) != str(src.waves[w][j].foe) or float(ec.waves[w][j].n) != float(ec.n):
						fine = false
			if ec.rules == ["extra_wave"] and RpgWorld.waves_fought(ec).size() != ec.waves.size() + 1:
				fine = false
		if not fine:
			echo_bad.append(ec.id)
	ok(echoes.size() == 80 and echo_bad.is_empty(), "80 echo stages: the road again at n 80 + 3 a region + 0.3 a stage, one rule each", echo_bad)
	ok(rules_used.size() == 6, "every rule turns up somewhere in the echoes", rules_used.keys())
	ok(RpgWorld.next_stage("e1s10") == "e2s1" and RpgWorld.next_stage("e8s10") == "" and RpgWorld.region_of("e4s3") == "stacks", "the echoes chain like the road")
	var two = {"waves": [[{"foe": "bent_bar", "n": 4}, {"foe": "dust_bunny", "n": 4}]], "rules": ["extra_wave"]}
	ok(RpgWorld.waves_fought(two).size() == 2 and RpgWorld.waves_fought(two)[0] == [{"foe": "dust_bunny", "n": 4}] and RpgWorld.waves_fought({"waves": [[{"foe": "bent_bar", "n": 4}]], "rules": ["extra_wave"]}).size() == 1,
		"one more wave: the first wave's regular foes once more, as the engine does it")
	ok(RpgWorld.par_of(two) == 6 + 11 and RpgWorld.par_of({"waves": [[{"foe": "burr"}], [{"foe": "skyhook"}, {"foe": "burr"}]]}) == 6 + 22 and RpgWorld.par_of({"waves": []}) == 0
		and RpgWorld.spire(3).par == 6 and RpgWorld.spire(5).par == 11 and RpgWorld.spire(10).par == 22, "par: 6 for a wave of regular foes, 11 with an elite, 22 with a boss, the extra wave too")
	ok(RpgWorld.foe_kind({"foe": "bent_bar"}) == "elite" and RpgWorld.foe_kind({"foe": "skyhook"}) == "boss" and RpgWorld.foe_kind({"foe": "burr"}) == "regular"
		and RpgWorld.foe_kind({"foe": "x", "row": {"boss": true}}) == "boss", "foe_kind reads the catalog, or the row an entry brings")


# --- setups and whole fights -----------------------------------------------------------

## Plays a setup to its end with the heuristic policy: the battle, or null when it would not end.
func play(setup: Dictionary) -> Variant:
	var B = RpgBattle.start(setup)
	for i in range(700):
		if RpgBattle.over(B):
			return B
		RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
	return B if RpgBattle.over(B) else null


func _battles() -> void:
	var rpg = cleared(8)
	rpg.seen["dust_bunny"] = ["push"]
	var state = {"weekly": {"current": {"week": "2031-03-03", "monster": "wk_slime", "weakPart": "arms"}}}
	var echo_extra = ""
	for ec in RpgWorld.echo_stages():
		if ec.rules == ["extra_wave"] and echo_extra == "":
			echo_extra = str(ec.id)
	var whats = [{"kind": "stage", "id": "r1s1"}, {"kind": "stage", "id": "r3s8"}, {"kind": "stage", "id": "r5s10"}, {"kind": "stage", "id": "r8s10"},
		{"kind": "echo", "id": echo_extra}, {"kind": "echo", "id": "e2s5"}, {"kind": "hunt", "id": "hunt:" + DAY, "boosts": []},
		{"kind": "rival", "id": "rival:2031-03-03", "state": state}, {"kind": "spire", "id": "spire:3"}, {"kind": "spire", "id": "spire:5"}, {"kind": "spire", "id": "spire:20"}]
	var seed = 11
	for what in whats:
		seed += 7
		var st = RpgWorld.stage_of(what, rpg)
		var tag = "%s %s" % [what.kind, what.id]
		if st == null:
			ok(false, tag + ": the stage is found")
			continue
		var hero = RpgHero.reference_hero(RpgDefs.tier_of_n(float(st.n)) + 1.0)
		var setup = RpgWorld.setup(what, rpg, hero, null, seed, DAY)
		var B = RpgBattle.start(setup)
		var fought = RpgWorld.waves_fought(st)
		var living = RpgBattle.foes(B)
		ok(not setup.is_empty() and int(setup.seed) == seed and RpgBattle.json_safe(B) == "" and B.waves.size() == fought.size() and living.size() >= fought[0].size()
			and B.what == {"kind": what.kind, "id": st.id} and str(B.day) == DAY and B.rules == st.rules and B.known.get("dust_bunny") == ["push"],
			tag + ": the setup is taken by the engine as it is meant", [B.waves.size(), fought.size(), living.size(), B.what])
		if str(what.kind) == "hunt":
			ok(living.all(func(f): return RpgBattle.known(B, str(f.id)).all and f.weak == st.weak), tag + ": the hunt's weaknesses are set, and shown from the start")
		if str(what.kind) == "rival":
			ok(living.size() == 1 and str(living[0].foe) == "wk_slime" and bool(living[0].boss) and str(living[0].name) == str(Bounty.monster("wk_slime").name)
				and living[0].weak == st.weak and RpgBattle.known(B, str(living[0].id)).all, tag + ": the rival stands there as a boss with the monster's id and name", living[0].foe)
		if what.id == "r5s10":
			ok(living.size() >= 2 and bool(living[0].boss) and float(living[1].hp_max) < float(RpgFoes.make("rivet_mite", float(st.n), 1).hp_max) * 0.6, tag + ": the boss's add is at half strength")
		if what.id == "r3s8":
			ok(living.size() == 2 and absf(float(living[1].hp_max) - float(RpgFoes.make("pebbling", float(st.n), 2).hp_max)) <= 1.0, tag + ": a pair is sized as a pair")
		var done = play(setup)
		ok(done != null and RpgBattle.over(done), tag + ": a fight played to its end with the heuristic policy")
		if done != null:
			var sum = RpgBattle.summary(done)
			ok(RpgWorld.stars(st, sum).size() == 3 and (not bool(sum.win) or int(sum.waves) == fought.size()), tag + ": its summary gives stars; a win cleared every wave", [sum.win, sum.waves])
	ok(RpgWorld.setup({"kind": "stage", "id": "r1s6"}, rpg, {}, null, 1, DAY).is_empty() and RpgWorld.setup({"kind": "stage", "id": "nope"}, rpg, {}, null, 1, DAY).is_empty()
		and RpgWorld.setup({"kind": "rival", "id": "rival:x"}, rpg, {}, null, 1, DAY).is_empty() and RpgWorld.stage_of({"kind": "spire", "id": "spire:0"}, rpg) == null, "a cache, an unknown stage, a rival without a bounty: nothing to fight")
	var brought = RpgWorld.setup({"kind": "hunt", "id": "hunt:" + DAY, "stage": RpgWorld.hunt(DAY, rpg, [])}, rpg, RpgHero.reference_hero(9.0), null, 3, DAY)
	ok(not brought.is_empty() and not brought.what.has("stage") and brought.waves == RpgWorld.hunt(DAY, rpg, []).waves, "a `what` may bring its stage; the battle keeps only kind and id")
	# the new player's first fight is winnable
	var wins = 0
	for i in range(20):
		var first = play(RpgWorld.setup({"kind": "stage", "id": "r1s1"}, RpgSave.empty(), RpgHero.reference_hero(1.0), null, 100 + i, DAY))
		if first != null and RpgBattle.won(first):
			wins += 1
	ok(wins >= 19, "the reference hero of tier 1 wins r1s1", wins)


# --- loot ---------------------------------------------------------------------------

func _loot() -> void:
	var fresh = RpgSave.empty()
	var s3 = RpgWorld.stage("r1s3")
	var rw = RpgLoot.rewards(s3, summary(), fresh, 1, [], 5)
	ok(int(rw.xp) == 2 * RpgDefs.foe_xp(2.0) and int(rw.ore) == 2 * RpgDefs.foe_ore(2.0) and bool(rw.first) and str(rw.relic) == "" and str(rw.scroll) == "" and rw.prizes.is_empty(),
		"a win: fighter XP and ore for every foe, by the plan's formula", rw)
	ok(JSON.stringify(rw) == JSON.stringify(RpgLoot.rewards(s3, summary(), fresh, 1, [], 5)), "the same call, the same loot")
	var lost = RpgLoot.rewards(s3, summary({"win": false}), fresh, 1, [], 5)
	ok(int(lost.xp) == 0 and int(lost.ore) == 0 and lost.items.is_empty() and not bool(lost.first), "a loss pays nothing")
	# kinds and waves
	var s8 = RpgWorld.stage("r1s8")
	ok(int(RpgLoot.rewards(s8, summary(), fresh, 1, [], 5).xp) == 5 * RpgDefs.foe_xp(7.0), "two waves: every foe of both")
	var elite = RpgWorld.stage("r3s5")
	var boss = RpgWorld.stage("r5s10")
	var re = RpgLoot.rewards(elite, summary(), fresh, 11, [], 5)
	var rb = RpgLoot.rewards(boss, summary(), fresh, 21, [], 5)
	ok(int(re.xp) == RpgDefs.foe_xp(24.0, "elite") + RpgDefs.foe_xp(24.0) and int(rb.xp) == RpgDefs.foe_xp(49.0, "boss") + RpgDefs.foe_xp(49.0), "an elite pays three foes' worth, a boss ten; an add as a foe", [re.xp, rb.xp])
	# the first win and the repeat
	ok(str(re.scroll) == str(elite.first.scroll) and re.items.any(func(it): return str(it.id) == "chalk_ball" and int(it.n) >= 3), "an elite's first win: its scroll and its stack of items", re)
	ok(str(rb.relic) == "pocket_anvil" and rb.runes.size() == 1 and int(rb.ore) == RpgDefs.foe_ore(49.0, "boss") + RpgDefs.foe_ore(49.0) + int(boss.first.ore) and not bool(rb.relic_dup), "a boss's first win: its relic, a rune, more ore", rb)
	var had = won(["r5s10", "r3s5"])
	var again = RpgLoot.rewards(boss, summary(), had, 21, [], 5)
	ok(not bool(again.first) and str(again.relic) == "" and int(again.xp) == int(rb.xp) and int(again.ore) == int(rb.ore) - int(boss.first.ore), "a repeat win: the same XP and ore, never the first reward", again)
	ok(str(RpgLoot.rewards(elite, summary(), had, 11, [], 5).scroll) == "", "no second scroll")
	var owns = RpgSave.empty()
	owns.relics["pocket_anvil"] = true
	ok(bool(RpgLoot.rewards(boss, summary(), owns, 21, [], 5).relic_dup), "a relic the player has is flagged: the save turns it into ore")
	# over-level, and the reward passives
	ok(int(RpgLoot.rewards(s3, summary(), fresh, 16, [], 5).xp) == int(round(2 * RpgDefs.foe_xp(2.0) * 0.6)) and int(RpgLoot.rewards(s3, summary(), fresh, 60, [], 5).xp) == int(round(2 * RpgDefs.foe_xp(2.0) * 0.2))
		and int(RpgLoot.rewards(s3, summary(), fresh, 16, [], 5).ore) == int(rw.ore), "far above a stage's tier the XP shrinks to a fifth at least; the ore does not")
	var rich = RpgLoot.rewards(s3, summary({"reward": {"ore": 0.35, "xp": 0.5, "luck": 0.0}}), fresh, 1, [], 5)
	ok(int(rich.ore) == int(round(2 * RpgDefs.foe_ore(2.0) * 1.35)) and int(rich.xp) == int(round(2 * RpgDefs.foe_xp(2.0) * 1.5)), "the hero's reward passives (the summary's) lift ore and XP", rich)
	var no_sum = summary()
	no_sum.erase("reward")
	ok(int(RpgLoot.rewards(s3, no_sum, fresh, 1, [{"id": "golden_day", "fx": [{"p": "reward", "what": "ore", "pct": 0.25}]}], 5).ore) == int(round(2 * RpgDefs.foe_ore(2.0) * 1.25)), "without them in the summary, the boosts' own are read")
	# item odds
	var s9 = RpgWorld.stage("r2s9")
	var drops = 0
	var lucky = 0
	var elite_drops = 0
	var boss_drops = 0
	var known = true
	for i in range(400):
		var r1 = RpgLoot.rewards(s9, summary(), had, 6, [], i)
		drops += 1 if not r1.items.is_empty() else 0
		for it in r1.items:
			if RpgItems.by_id(str(it.id)) == null:
				known = false
		lucky += 1 if not RpgLoot.rewards(s9, summary({"reward": {"ore": 0.0, "xp": 0.0, "luck": 1.0}}), had, 6, [], i).items.is_empty() else 0
		elite_drops += 1 if not RpgLoot.rewards(elite, summary(), had, 11, [], i).items.is_empty() else 0
		boss_drops += 1 if not RpgLoot.rewards(boss, summary(), had, 21, [], i).items.is_empty() else 0
	ok(drops > 50 and drops < 115 and elite_drops > 260 and elite_drops < 340 and boss_drops == 400 and known, "an item on about 20% of regular wins, 75% of an elite's, every boss win", [drops, elite_drops, boss_drops])
	ok(lucky > drops + 40, "luck lifts the odds", [drops, lucky])
	ok(RpgLoot.item_drop(3, 0.0) == RpgLoot.item_drop(3, 0.0) and ["protein_shake", "electrolytes", "chalk_ball"].has(str(RpgLoot.item_drop(3, 0.0).id)), "item_drop: seeded; the dearer items come later on the road")
	# runes: fresh ids
	var ids = {}
	var holder = RpgSave.empty()
	for i in range(60):
		var rn = RpgLoot.rune(float(i), holder, "any", 0)
		ids[rn.id] = true
		holder.runes.append(rn)
	var pair = [RpgLoot.rune(30.0, holder, "a", 0), RpgLoot.rune(30.0, holder, "a", 1)]
	ok(ids.size() == 60 and pair[0].id != pair[1].id and not ids.has(pair[0].id), "every rune handed out has an id no rune of the save has")
	ok(RpgLoot.rune_tier(0.0) == 1 and RpgLoot.rune_tier(49.0) == 5 and RpgLoot.rune_tier(79.0) == 8 and RpgLoot.rune_tier(500.0) == RpgGear.RUNE_TIERS, "a rune's tier comes from the stage's index")
	ok(RpgLoot.scrap_ore({"rarity": "common"}) < RpgLoot.scrap_ore({"rarity": "legendary"}) and RpgLoot.scrap_ore({}) > 0, "scrap ore by rarity")
	# caches
	var c1 = RpgLoot.cache("r1s6", fresh, 1)
	ok(c1.size() == 3 and c1.map(func(o): return o.kind) == ["relic", "rune", "items"] and RpgRelics.by_id(str(c1[0].relic)) != null and JSON.stringify(c1) == JSON.stringify(RpgLoot.cache("r1s6", fresh, 1)), "a cache: a relic, a rune or items, the same every look", c1)
	var all_relics = RpgSave.empty()
	for r in RpgRelics.all():
		all_relics.relics[r.id] = true
	all_relics.relics.erase("flywheel")
	ok(str(RpgLoot.cache("r1s6", all_relics, 1)[0].relic) == "flywheel", "the relic is one the player does not have, while one is left")
	all_relics.relics["flywheel"] = true
	ok(str(RpgLoot.cache("r1s6", all_relics, 1)[0].kind) == "ore" and RpgLoot.pick_relic(all_relics, 5.0, "x") == "" and RpgLoot.cache("nope", fresh, 1).is_empty(), "none left: ore in its place")
	ok(str(RpgLoot.cache("e2s6", fresh, 1)[0].kind) == "relic" and str(RpgRelics.by_id(str(RpgLoot.cache("e2s6", fresh, 1)[0].relic)).rarity) != "rare", "an echo's cache digs deeper")
	# star chests
	var c8 = RpgLoot.star_chest("chalk", 8, 1, fresh)
	var c24 = RpgLoot.star_chest("chalk", 24, 1, fresh)
	ok(int(c8.ore) > 0 and not c8.items.is_empty() and str(c8.relic) == "" and RpgRelics.by_id(str(c24.relic)) != null and c24.runes.size() == 1 and int(c24.ore) > int(c8.ore)
		and RpgLoot.star_chest("chalk", 9, 1).is_empty() and RpgLoot.star_chest("nope", 8, 1).is_empty(), "star chests: ore and items at 8, a scroll at 16, a relic and a rune at 24", [c8, c24])
	# the hunt, the rival, the Spire
	var hunter = cleared(1)
	var h = RpgWorld.hunt(DAY, hunter, [])
	var rh = RpgLoot.rewards(h, summary(), hunter, 5, [], 3)
	ok(rh.prizes.size() == 3 and bool(rh.first) and int(rh.xp) == RpgWorld.waves_fought(h).reduce(func(acc, w): return acc + w.size(), 0) * RpgDefs.foe_xp(11.0), "a hunt won: XP for the pack (the extra wave too) and the three prizes to pick from", rh)
	hunter.hunt = {"date": DAY, "won": true}
	hunter.caches["hunt:" + DAY] = true
	var rh2 = RpgLoot.rewards(h, summary(), hunter, 5, [], 3)
	ok(rh2.prizes.is_empty() and not bool(rh2.first) and int(rh2.xp) == int(rh.xp), "the prize is picked once a day; the hunt itself pays again")
	var rv = RpgWorld.rival({"weekly": {"current": {"week": "2031-03-03", "monster": "wk_bat", "weakPart": "legs"}}}, hunter)
	var rr = RpgLoot.rewards(rv, summary(), hunter, 5, [], 3)
	ok(bool(rr.first) and (str(rr.relic) != "" or rr.runes.size() >= 1) and int(rr.ore) == 2 * RpgDefs.foe_ore(14.0, "boss") and int(rr.xp) == RpgDefs.foe_xp(14.0, "boss"), "the rival's first win of the week: a relic or a rune, and ore twice over", rr)
	hunter.rival = {"week": "2031-03-03", "won": true}
	var rr2 = RpgLoot.rewards(rv, summary(), hunter, 5, [], 3)
	ok(not bool(rr2.first) and str(rr2.relic) == "" and int(rr2.ore) == RpgDefs.foe_ore(14.0, "boss"), "once a week")
	var climber = cleared(2)
	var f5 = RpgLoot.rewards(RpgWorld.spire(5), summary(), climber, 11, [], 3)
	var f10 = RpgLoot.rewards(RpgWorld.spire(10), summary(), climber, 11, [], 3)
	ok(int(f5.xp) > 0 and f5.runes.size() == 1 and RpgRelics.by_id(str(f10.relic)) != null and f10.runes.size() == 1, "the Spire: a rune from every fifth floor, a relic too from every tenth", [f5, f10])
	climber.spire.best = 5
	var f5b = RpgLoot.rewards(RpgWorld.spire(5), summary(), climber, 11, [], 3)
	ok(int(f5b.xp) == 0 and int(f5b.ore) == 0 and f5b.runes.is_empty() and f5b.items.is_empty(), "a floor pays once")
	ok(RpgLoot.chest_rune(climber, DAY).id != "" and RpgLoot.rune_tier(RpgWorld.best_n(climber)) == 2, "a gold training chest's rune is of the tier the player has reached")
	# the whole road, once
	var xp = 0
	var ore = 0
	for st in RpgWorld.all_stages():
		if str(st.kind) != "cache":
			var pay = RpgLoot.rewards(st, summary(), fresh, int(RpgDefs.level_of(xp).lvl), [], 7)
			xp += int(pay.xp)
			ore += int(pay.ore)
	var lvl = int(RpgDefs.level_of(xp).lvl)
	ok(lvl >= 30 and lvl <= 41 and ore > 3000, "winning every road stage once brings a fighter near the level the last region expects", [xp, ore, lvl])
