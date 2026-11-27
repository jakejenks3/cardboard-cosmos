extends SceneTree
## The Realm's balance, held by simulation (RPG_PLAN.md 4.1 targets and 13):
## 20 seeds of the reference hero (balanced, weaknesses known, the heuristic
## policy) on stages 1, 5 and 10 of every region, with slack for so few seeds.
## The full tables are tools/rpg_balance.gd's (200 seeds).
##
##   TINY_TITAN_DATA=<a throwaway folder>
##   godot --headless --path . --script res://tests/rpg_sim_test.gd
##
## What it holds:
##   stage 1 (regular foes): always won, 10 turns at most, 55%+ HP left
##   stage 5 (the elite): won 9 times in 10, 5 to 13 turns, 30%+ HP left
##   stage 10 (the boss): won 45% to 100% of the time (the band is 55 to 85%), 10 to 23 turns; at power x1.2
##     80%+, at x0.7 25% at most; the random policy a third of the heuristic's at most; no hit over 40% of max HP
##   the turns star can be had: a stage's par is not under the median turns
##   every stat 15 (level 1, the starter build, nothing known): r1s1 to r1s4 90%+; every stat 1: r1s1 to r1s3
##   every fight ends and the heuristic never asks for something the engine turns down

const SEEDS = 20

var Sim = load("res://tests/rpg_sim.gd")
var passed = 0
var total = 0


func ok(cond: bool, what: String, got = null) -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, "" if got == null else str(got)])


func _initialize() -> void:
	var t0 = Time.get_ticks_msec()
	_library()
	_road()
	_first_fights()
	print("(%.1f s)" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	print("RPG SIM: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


func _library() -> void:
	var hero = RpgHero.reference_hero(2.0)
	var up = Sim.scaled(hero, 1.2)
	ok(int(up.hp_max) == int(round(float(hero.hp_max) * 1.2)) and up.fx.size() == hero.fx.size() + 1 and int(hero.hp) == int(hero.hp_max), "scaled: HP and every hit times the factor, the hero given is left alone",
		[hero.hp_max, up.hp_max])
	var one = Sim.fight(hero, Sim.stage_waves("r2s1"), 5)
	var again = Sim.fight(hero, Sim.stage_waves("r2s1"), 5)
	ok(bool(one.over) and one == again and int(one.turns) > 0 and not one.acts.is_empty(), "fight: the same seed is the same fight", one)
	ok(Sim.stage_waves("r1s6").is_empty() and Sim.stage_waves("nope").is_empty() and Sim.median([3, 1, 2]) == 2.0, "stage_waves: a cache and an unknown stage have none")
	var flat = Sim.made({"raw": Sim.flat(15.0), "lvl": 1})
	ok(flat.moves == RpgMoves.FIRST_BUILD and int(flat.lvl) == 1 and float(flat.s.core) == 15.0, "made: a hero from raw stats with the starter build", flat.moves)


func _road() -> void:
	for r in range(1, 9):
		var tag = "region %d" % r
		var first = RpgWorld.stage("r%ds1" % r)
		var hero = RpgHero.reference_hero(RpgDefs.tier_of_n(float(first.n)))
		var a = Sim.run(hero, first.waves, SEEDS)
		ok(int(a.bad) == 0 and float(a.win) >= 1.0 and int(a.turns) <= 10 and float(a.hp) >= 0.55, tag + " stage 1: won, short, most of the HP left", Sim.cell(a))
		ok(int(first.par) >= int(a.turns), tag + " stage 1: the turns star can be had", [first.par, a.turns])

		var elite = RpgWorld.stage("r%ds5" % r)
		hero = RpgHero.reference_hero(RpgDefs.tier_of_n(float(elite.n)))
		var e = Sim.run(hero, elite.waves, SEEDS)
		ok(int(e.bad) == 0 and float(e.win) >= 0.9 and int(e.turns) >= 5 and int(e.turns) <= 13 and float(e.hp) >= 0.3, tag + " elite: won, 5 to 13 turns, 30%+ HP left", Sim.cell(e))
		ok(int(elite.par) >= int(e.turns), tag + " elite: the turns star can be had", [elite.par, e.turns])

		var boss = RpgWorld.stage("r%ds10" % r)
		hero = RpgHero.reference_hero(RpgDefs.tier_of_n(float(boss.n)))
		var b = Sim.run(hero, boss.waves, SEEDS)
		ok(int(b.bad) == 0 and float(b.win) >= 0.45 and int(b.turns) >= 10 and int(b.turns) <= 23, tag + " boss: won about three times in four, in 10 to 23 turns", Sim.cell(b))
		ok(float(b.worst) <= 0.4, tag + " boss: no single hit over 40% of max HP", b.worst)
		ok(int(boss.par) >= int(b.turns), tag + " boss: the turns star can be had", [boss.par, b.turns])
		var up = Sim.run(Sim.scaled(hero, 1.2), boss.waves, SEEDS)
		var down = Sim.run(Sim.scaled(hero, 0.7), boss.waves, SEEDS)
		ok(float(up.win) >= 0.8 and float(down.win) <= 0.25, tag + " boss: power x1.2 wins, x0.7 does not", [up.win, down.win])
		var rnd = Sim.run(hero, boss.waves, SEEDS, "random")
		ok(int(rnd.bad) == 0 and float(rnd.win) <= maxf(0.1, float(b.win) / 3.0), tag + " boss: pressing keys at random does not win it", [rnd.win, b.win])


func _first_fights() -> void:
	for v in [1.0, 15.0]:
		var hero = Sim.made({"raw": Sim.flat(v), "lvl": 1})
		var last = 3 if v <= 1.0 else 4
		var low = []
		for s in range(1, last + 1):
			var res = Sim.run(hero, Sim.stage_waves("r1s%d" % s), SEEDS, "heuristic", {"known": false})
			if float(res.win) < 0.9 or int(res.bad) > 0:
				low.append("r1s%d %s" % [s, Sim.cell(res)])
		ok(low.is_empty(), "every stat %d, level 1, the starter build, nothing known: r1s1 to r1s%d won 9 times in 10" % [int(v), last], low)
