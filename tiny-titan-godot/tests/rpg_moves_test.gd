extends SceneTree
## Unit test for the Realm's moves, board passives and skill boards
## (RPG_PLAN.md 5 and 6): game/rpg/rpg_moves.gd (RpgMoves), rpg_passives.gd
## (RpgPassives), rpg_skills.gd (RpgSkills). The catalogs pass the engine's
## validators, every attack's power is what the budget rule gives (the rule is
## `rule` below), the boards have the plan's shape and cost, skill points and
## every reason a node cannot be learned are checked on made-up saves, and
## every move is used in a real battle through RpgBattle.
## Made-up saves and foes only; nothing here reads a save.
##   godot --headless --path . --script res://tests/rpg_moves_test.gd
## Prints RPG MOVES: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0

const ATTACK = ["push", "pull", "legs", "speed", "grip", "mind"]
const TAGS = ["starter", "scroll", "ult", "multi", "all", "breaker", "debuff", "buff", "control", "tempo", "heal", "shield",
	"cleanse", "energy", "gauge", "combo", "ramp", "crit", "pierce", "finisher", "risky", "quick", "heavy"]
## The one move the plan scales by a stat of another school (a deadlift is back and legs).
const CROSS = {"deadlift_slam": ["legs"]}

# --- the budget rule (RPG_PLAN.md 5) -----------------------------------------
# P = ((budget - what else it does) * 0.6 for "all" * 1.05 for several hits) / (what its mods are worth)

## What a status is worth before its chance and its turns (the plan: 0.3 to 0.6 a status).
const STATUS_WORTH = {"exposed": 0.6, "weakened": 0.55, "slowed": 0.55, "burn": 0.45, "bleed": 0.4, "stun": 1.2, "marked": 0.5,
	"pumped": 0.45, "braced": 0.4, "hasted": 0.5, "regen": 0.5, "focus": 0.4, "evade": 0.4, "counter": 0.4, "steady": 0.3, "insight": 0.3}
const ALL_FOES = 1.6          # an effect that lands on every foe
const EXTRA_PIP = 0.25        # each guard pip past the first
const ULT_MULT = 1.6          # an ultimate: this much of a cost-5 cd-4 rank-1 move


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a: float, b: float, tol: float = 0.0001) -> bool:
	return absf(a - b) <= tol


## What one effect of an attack costs in power (negative: it is a price the hero pays).
func fx_cost(e: Dictionary) -> float:
	var wide = ALL_FOES if str(e.get("to", "")) == "all_foes" else 1.0
	match str(e.get("k", "")):
		"status":
			var id = str(e.id)
			var turns = int(e.get("turns", 2))
			var long = 1.0 if not e.has("turns") else (0.75 if turns == 1 else (1.0 if turns == 2 else (1.1 if turns >= 3 else 1.3)))
			var c = clampf(float(STATUS_WORTH.get(id, 0.4)) * long * float(e.get("chance", 1.0)) * float(e.get("stacks", 1)), 0.3, 0.6)
			if str(e.get("to", "target")) == "self" and str(RpgDefs.STATUS[id].kind) == "debuff":
				return -c
			return c * wide
		"energy":
			return 0.25 * float(clampi(int(e.n), -3, 4))
		"gauge":
			return 0.01 * float(e.n)
		"delay":
			return float(e.pct) * wide
		"interrupt":
			return 0.2
		"lifesteal":
			return 0.7 * float(e.pct)
		"refund":
			return 0.1 * float(e.n)
		"extra_turn":
			return 1.0
		"heal":
			return 3.0 * float(e.pct)
		"shield":
			return 2.5 * float(e.pct)
		"cleanse":
			return 0.4 if int(e.get("n", 0)) <= 0 else 0.2 * float(e.n)
		"dispel":
			return (0.5 if int(e.n) <= 0 else 0.25 * float(e.n)) * wide
		"cd_cut":
			return 0.4 * float(e.n)
		"hp_cost":
			return -1.5 * float(e.pct)
		"chip":
			return 0.3 * float(e.n) * wide
		"when":
			return 0.5 * fx_cost(e.do)
	return 0.0


## What a mod multiplies the move's damage by, on average over a fight.
func mod_worth(mod: Dictionary) -> float:
	var pct = float(mod.get("pct", 0.0))
	var most = float(mod.get("max", 99.0))
	match str(mod.m):
		"vs_status":
			return 1.0 + 0.3 * pct
		"vs_debuff":
			return 1.0 + 0.33 * pct
		"per_debuff":
			return 1.0 + minf(most, 0.9 * pct)
		"vs_broken", "vs_full_hp":
			return 1.0 + 0.25 * pct
		"execute":
			return 1.0 + 0.6 * float(mod.below) * pct
		"ignore_def":
			return 1.0 + 0.27 * pct
		"crit":
			return 1.0 + 0.5 * float(mod.add)
		"sure_crit":
			return 1.36
		"ramp_use":
			return 1.0 + minf(most, 1.85 * pct)
		"ramp_turn":
			return 1.0 + minf(most, 4.6 * pct)
		"streak":
			return 1.0 + minf(most, 1.67 * pct)
		"missing_hp":
			return 1.0 + 0.35 * pct
	return 1.0


## The power the budget rule gives an attack.
func rule(m: Dictionary) -> float:
	var p = RpgDefs.move_budget(float(m.rank), int(m.cost), int(m.cd))
	if bool(m.ult):
		p = ULT_MULT * RpgDefs.move_budget(1.0, 5, 4)
	p -= EXTRA_PIP * float(maxi(0, int(m.chip) - 1))
	var div = 1.0 + 0.4 * float(m.splash)
	for mod in m.mods:
		if str(mod.m) == "smart":
			p -= 0.3
		else:
			div *= mod_worth(mod)
	for e in m.fx:
		p -= fx_cost(e)
	if str(m.target) == "all":
		p *= 0.6
	if int(m.hits) > 1:
		p *= 1.05
	return p / div


## What kind of thing a move does, without its numbers: two moves with the same
## answer do the same thing.
func signature(m: Dictionary) -> String:
	var parts = [str(m.kind), str(m.target) if str(m.target) != "foe" else "", "multi" if int(m.hits) > 1 else "", "chip" if int(m.chip) > 1 else ""]
	var rest = []
	for mod in m.mods:
		rest.append(str(mod.m) + ":" + str(mod.get("id", "")))
	for e in m.fx:
		var inner = e.do if str(e.k) == "when" else e
		rest.append("%s:%s:%s" % [str(inner.k), str(inner.get("id", "")), str(inner.get("to", ""))])
	rest.sort()
	return "|".join(parts) + "|" + ",".join(rest)


func plain(s: String) -> bool:
	for i in range(s.length()):
		if s.unicode_at(i) > 126 or s.unicode_at(i) < 32:
			return false
	return true


# --- made-up saves -------------------------------------------------------------

func sheet_of(v: float, over: Dictionary = {}) -> Dictionary:
	var stats = {}
	for id in RpgDefs.STATS:
		stats[id] = {"v": float(over.get(id, v))}
	return {"stats": stats}


func xp_for(level: int) -> int:
	var xp = 0
	for l in range(1, level):
		xp += RpgDefs.xp_to_next(l)
	return xp


func save_of(level: int, nodes: Array, stages: Dictionary = {}, scrolls: Array = []) -> Dictionary:
	var rpg = RpgSave.empty()
	rpg["xp"] = xp_for(level)
	for id in nodes:
		rpg.nodes[id] = true
	rpg["stages"] = stages
	for id in scrolls:
		rpg.scrolls[id] = true
	return rpg


func why(rpg: Dictionary, node: String, sheet: Dictionary, level: int, days: int = 0) -> String:
	var r = RpgSkills.can_learn(rpg, node, sheet, level, days)
	return "ok" if bool(r.ok) else str(r.why)


func _init() -> void:
	catalog()
	budget()
	boards()
	points()
	learning()
	fights()
	print("RPG MOVES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# =============================================================================

func catalog() -> void:
	var moves = RpgMoves.all()
	var bad = []
	var ids = {}
	for m in moves:
		var w = RpgBattle.check_move(m)
		if w != "":
			bad.append(w)
		if str(m.id) != RpgDefs.id_of(str(m.name)) or ids.has(m.id):
			bad.append("id " + str(m.id))
		ids[m.id] = true
	ok(bad.is_empty() and moves.size() == 90, "90 moves, each passes check_move, ids from the names, no id twice", [bad, moves.size()])

	bad = []
	var pids = {}
	for p in RpgPassives.all():
		for e in p.fx:
			var w = RpgBattle.check_passive(e)
			if w != "":
				bad.append("%s: %s" % [p.id, w])
		if str(p.id) != RpgDefs.id_of(str(p.name)) or pids.has(p.id) or ids.has(p.id):
			bad.append("id " + str(p.id))
		if p.fx.is_empty() or str(p.text) == "" or not str(p.text).ends_with(".") or not plain(str(p.text)) or str(p.board) != str(p.school):
			bad.append("row " + str(p.id))
		pids[p.id] = true
	ok(bad.is_empty() and RpgPassives.all().size() == 24, "24 passives, each effect passes check_passive, ids from the names, none shared with a move", bad)
	bad = []
	for school in RpgDefs.SCHOOLS:
		var tiers = []
		for p in RpgPassives.of_board(school):
			tiers.append(int(p.tier))
		if tiers != [1, 3, 4]:
			bad.append([school, tiers])
	ok(bad.is_empty(), "three passives a board, at tiers 1, 3 and 4", bad)

	# starters, ultimates, scrolls
	bad = []
	for school in RpgDefs.SCHOOLS:
		var list = RpgMoves.by_school(school)
		var starters = list.filter(func(m): return int(m.tier) == 0)
		var ults = list.filter(func(m): return bool(m.ult))
		var scrolls = list.filter(func(m): return int(m.tier) == 9)
		if starters.size() != 1 or not RpgMoves.STARTERS.has(starters[0].id):
			bad.append(school + " starter")
		if ults.size() != 1 or int(ults[0].tier) != 5 or int(ults[0].cost) != 0 or not near(float(ults[0].rank), RpgDefs.ULT_RANK):
			bad.append(school + " ult")
		if scrolls.size() != 2:
			bad.append(school + " scrolls")
		var order = []
		for m in list:
			order.append(int(m.tier))
		var sorted = order.duplicate()
		sorted.sort()
		if order != sorted or list.size() != (12 if ATTACK.has(school) else 9):
			bad.append([school, order])
	ok(bad.is_empty() and RpgMoves.STARTERS.size() == 8 and RpgMoves.scrolls().size() == 16,
		"each school: its starter, one ultimate (tier 5, no cost), two scrolls; by_school in tier order", bad)
	ok(RpgMoves.STARTERS == ["shove", "yank", "stomp", "dash_strike", "pinch", "burning_page", "deep_breath", "grind"]
		and RpgMoves.by_id("no_such_move") == null and RpgMoves.by_id("runners_high").name == "Runner's High"
		and RpgMoves.by_school("nowhere").is_empty(), "the starters of the plan; by_id; an unknown id or school gives nothing")

	bad = []
	for m in moves:
		var attack = str(m.kind) == "attack"
		if int(m.tier) != 0 and not bool(m.ult) and int(m.cd) < 1:
			bad.append("rest " + str(m.id))
		if not [0, 1, 2, 3, 4, 5, 9].has(int(m.tier)) or bool(m.ult) != (int(m.tier) == 5):
			bad.append("tier " + str(m.id))
		var sum = 0.0
		var allowed = RpgDefs.SCHOOL_STATS[str(m.school)] + CROSS.get(str(m.id), [])
		for st in m.scale:
			sum += float(m.scale[st])
			if not allowed.has(st):
				bad.append("stat %s of %s" % [st, m.id])
		if not near(sum, 1.0) or m.scale.size() > 2 or (m.scale.size() == 2 and m.scale.values() != [0.6, 0.4]):
			bad.append("scale " + str(m.id))
		if attack and float(m.rank) < 0.8 and float(m.power) > 0.85:
			bad.append("quick and strong: " + str(m.id))
		if attack != (float(m.power) > 0.0):
			bad.append("power " + str(m.id))
		if str(m.text) == "" or not str(m.text).ends_with(".") or not plain(str(m.text)) or not plain(str(m.name)):
			bad.append("text " + str(m.id))
		var w = RpgMoves.words(m)
		if not (w is Array) or ((not m.mods.is_empty() or not m.fx.is_empty()) and str(m.text) != ". ".join(w) + "."):
			bad.append("words " + str(m.id))
		for t in m.tags:
			if not TAGS.has(t):
				bad.append("tag %s of %s" % [t, m.id])
		var want = RpgDefs.BOARD_STAT[str(m.school)] if not attack else str(m.scale.keys()[0])
		if RpgMoves.stat_of(m) != want:
			bad.append("stat_of " + str(m.id))
	ok(bad.is_empty(), "every move: it rests, its scale, a quick move is not strong, its text says its words, known tags, stat_of", bad)
	ok(RpgMoves.stat_of(RpgMoves.by_id("lockout")) == "arms" and RpgMoves.stat_of(RpgMoves.by_id("titan_press")) == "chest"
		and RpgMoves.stat_of(RpgMoves.by_id("lat_spread")) == "back" and RpgMoves.stat_of(RpgMoves.by_id("earthshaker")) == "legs"
		and RpgMoves.stat_of({"kind": "attack", "school": "push", "scale": {"arms": 0.5, "chest": 0.5}}) == "arms",
		"stat_of: the biggest weight, the first on a tie, the board's stat for a support move")
	ok(RpgMoves.words(RpgMoves.by_id("haymaker")).is_empty() and RpgMoves.words(RpgMoves.by_id("burnout_set")) == ["4 hits", "You are Weakened for 1 turn"]
		and RpgMoves.words(RpgMoves.by_id("heave_ho")) == ["Hits every foe", "Pushes every foe's turn back 25%"]
		and RpgMoves.words(RpgMoves.by_id("plate_toss"))[1] == "Chips 1 guard on every foe, whatever the school"
		and RpgMoves.words(RpgMoves.by_id("empty_the_tank")) == ["8 hits on random foes", "Uses up all the energy you have left"],
		"words: short phrases, and an effect on every foe says every foe", [RpgMoves.words(RpgMoves.by_id("heave_ho")), RpgMoves.words(RpgMoves.by_id("empty_the_tank"))])
	ok(RpgMoves.by_id("overhead_smash").tags.has("breaker") and RpgMoves.by_id("overhead_smash").tags.has("heavy")
		and RpgMoves.by_id("one_rep_max").tags.has("risky") and RpgMoves.by_id("one_rep_max").tags.has("scroll")
		and RpgMoves.by_id("flurry").tags == ["multi"] and RpgMoves.by_id("shove").tags == ["starter", "control"]
		and RpgMoves.by_id("second_life").tags.has("ult") and RpgMoves.by_id("second_life").tags.has("heal") and RpgMoves.by_id("clinch").tags == ["control"]
		and RpgMoves.by_id("barn_door").tags.has("risky") and not RpgMoves.by_id("barn_door").tags.has("debuff"),
		"tags are worked out from the row", [RpgMoves.by_id("shove").tags, RpgMoves.by_id("barn_door").tags])

	# a scroll does something no board move does, and no other scroll
	var seen = {}
	for m in moves:
		if int(m.tier) != 9:
			seen[signature(m)] = str(m.id)
	bad = []
	for m in RpgMoves.scrolls():
		var sig = signature(m)
		if seen.has(sig):
			bad.append("%s does what %s does" % [m.id, seen[sig]])
		seen[sig] = str(m.id)
		if RpgSkills.node_of_ref(str(m.id)) != null:
			bad.append(str(m.id) + " has a node")
	ok(bad.is_empty(), "every scroll does something no other move does, and has no node", bad)


func budget() -> void:
	var rows = []
	for m in RpgMoves.all():
		if str(m.kind) != "attack":
			continue
		var want = rule(m)
		rows.append([absf(float(m.power) - want) / want, str(m.id), float(m.power), snappedf(want, 0.01)])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var off = rows.filter(func(r): return r[0] > 0.15)
	print("budget: the five furthest from the rule (share off, id, power, rule): ", rows.slice(0, 5))
	ok(off.is_empty() and rows.size() == 66, "every attack's power is within 15% of the budget rule", off)
	var ult = ULT_MULT * RpgDefs.move_budget(1.0, 5, 4)
	ok(near(RpgDefs.move_budget(1.0, 2, 1), 1.75) and near(ult, 4.96) and near(rule(RpgMoves.by_id("haymaker")), RpgDefs.move_budget(1.3, 3, 2))
		and near(rule(RpgMoves.by_id("bulldoze")), 0.6 * RpgDefs.move_budget(1.1, 3, 2)) and near(rule(RpgMoves.by_id("one_two")), 1.05 * 1.75)
		and near(rule(RpgMoves.by_id("yank")), 1.3 - 0.25) and near(rule(RpgMoves.by_id("grind")), 1.3 - 0.12),
		"the rule: the plain budget, all x0.6, several hits x1.05, energy 0.25 a point, gauge 0.1 per 10, an ultimate x1.6")
	var supports = RpgMoves.all().filter(func(m): return str(m.kind) == "support")
	ok(supports.size() == 24 and supports.all(func(m): return float(m.power) == 0.0 and not m.fx.is_empty() and m.mods.is_empty()),
		"a support move has no power and does something", supports.size())


func boards() -> void:
	var bs = RpgSkills.boards()
	var names = []
	for b in bs:
		names.append(str(b.id))
	ok(names == RpgDefs.SCHOOLS and bs[0].name == "Push" and bs[7].name == "Grit", "eight boards in the schools' order", names)
	var bad = []
	var cost = 0
	var refs = {}
	for b in bs:
		var attack = ATTACK.has(str(b.id))
		var want = {1: ["move", "move", "passive"], 2: ["move", "move", "move"], 3: ["move", "move", "passive"], 4: ["move", "passive"], 5: ["ult"]} if attack \
			else {1: ["move", "passive"], 2: ["move", "move"], 3: ["move", "passive"], 4: ["move", "passive"], 5: ["ult"]}
		var got = {1: [], 2: [], 3: [], 4: [], 5: []}
		var places = {}
		for n in b.nodes:
			got[int(n.tier)].append(str(n.kind))
			cost += int(n.cost)
			var row = RpgPassives.by_id(str(n.ref)) if str(n.kind) == "passive" else RpgMoves.by_id(str(n.ref))
			if row == null or refs.has(n.ref):
				bad.append("ref " + str(n.id))
				continue
			refs[n.ref] = true
			if str(n.id) != str(b.id) + ":" + str(n.ref) or str(n.board) != str(b.id) or int(row.tier) != int(n.tier) or str(row.school) != str(b.id):
				bad.append("id " + str(n.id))
			if int(n.cost) != [0, 1, 1, 2, 3, 4][int(n.tier)] or int(n.row) != int(n.tier) or int(n.col) < 0 or int(n.col) > 2:
				bad.append("cost or place " + str(n.id))
			if places.has([int(n.row), int(n.col)]):
				bad.append("two nodes in one place: " + str(n.id))
			places[[int(n.row), int(n.col)]] = true
			if str(n.kind) == "ult" and not bool(row.ult):
				bad.append("ult " + str(n.id))
			var stat = str(RpgDefs.BOARD_STAT[str(b.id)]) if str(n.kind) == "passive" else RpgMoves.stat_of(row)
			if str(n.stat) != stat or not RpgDefs.STATS.has(str(n.stat)):
				bad.append("stat " + str(n.id))
			if RpgSkills.by_id(str(n.id)) != n or RpgSkills.node_of_ref(str(n.ref)) != n:
				bad.append("lookup " + str(n.id))
		if got != want or b.nodes.size() != (12 if attack else 9) or RpgSkills.nodes_of(str(b.id)) != b.nodes:
			bad.append([b.id, got])
	ok(bad.is_empty(), "every board: the plan's nodes by tier, ids, costs, places, stats, refs that resolve", bad)
	ok(cost == 168 and RpgSkills.all().size() == 90, "90 nodes; all the boards cost 168 points", [cost, RpgSkills.all().size()])
	bad = []
	for m in RpgMoves.all():
		var on = int(m.tier) >= 1 and int(m.tier) <= 5
		if on != refs.has(m.id) or (not on and RpgSkills.node_of_ref(str(m.id)) != null):
			bad.append(str(m.id))
	for p in RpgPassives.all():
		if not refs.has(p.id):
			bad.append(str(p.id))
	ok(bad.is_empty(), "every tier 1 to 5 move and every passive is on exactly one node; starters and scrolls on none", bad)
	var n = RpgSkills.by_id("legs:earthshaker")
	ok(n != null and n.kind == "move" and int(n.tier) == 3 and int(n.cost) == 2 and n.stat == "legs" and RpgSkills.by_id("push:titan_press").kind == "ult"
		and RpgSkills.by_id("push:titan_press").col == 1 and RpgSkills.by_id("grit:last_stand").stat == "grit" and RpgSkills.by_id("grit:last_stand").col == 2
		and RpgSkills.by_id("pull:lat_spread").stat == "back" and RpgSkills.by_id("pull:deadlift_slam").stat == "back"
		and RpgSkills.by_id("push:shove") == null and RpgSkills.by_id("") == null and RpgSkills.nodes_of("nowhere").is_empty(),
		"single nodes; a starter has no node; an unknown id or board gives nothing")
	var rpg = save_of(1, ["push:haymaker", "push:lockout_strength"])
	ok(RpgHero.knows_move(rpg, RpgMoves.by_id("haymaker")) and RpgHero.knows_passive(rpg, RpgPassives.by_id("lockout_strength"))
		and not RpgHero.knows_move(rpg, RpgMoves.by_id("one_two")), "the node ids are the ones RpgHero looks for")


func points() -> void:
	var p = RpgSkills.points(RpgSave.empty(), 0)
	ok(p == {"earned": 3, "spent": 0, "left": 3, "from": {"start": 3, "level": 0, "bosses": 0, "stars": 0, "days": 0}}, "an empty save: the three points it starts with", p)
	ok(RpgSkills.points({}, 7).earned == 3 and RpgSkills.points({}, -5).earned == 3 and RpgSkills.points({}, 8)["from"].days == 1 and RpgSkills.points({}, 17)["from"].days == 2,
		"a point per 8 active days; a save with nothing in it is an empty one")

	# a mid save: level 7, the first region's boss, 29 stars, 50 days, three nodes
	var stages = {}
	for i in range(1, 10):
		stages["r1s%d" % i] = {"stars": [true, true, true], "wins": 2, "best": 0}
	stages["r1s10"] = {"stars": [true, true, false], "wins": 1, "best": 0}
	stages["r2s10"] = {"stars": [false, false, false], "wins": 0, "best": 0}
	var mid = save_of(7, ["push:one_two", "push:lockout_strength", "push:haymaker", "push:no_such_node"], stages)
	p = RpgSkills.points(mid, 50)
	ok(p == {"earned": 19, "spent": 3, "left": 16, "from": {"start": 3, "level": 6, "bosses": 2, "stars": 2, "days": 6}} and RpgSkills.level_of(mid) == 7,
		"a mid save: 3 + 6 levels + 2 a boss beaten + a point per 12 stars + a point per 8 days; a node nobody knows costs nothing", p)

	# a rich one: level 60, every boss, every star, every node
	stages = {}
	for r in range(1, 9):
		for i in range(1, 11):
			stages["r%ds%d" % [r, i]] = {"stars": [true, true, true], "wins": 1, "best": 0}
	var every = []
	for n in RpgSkills.all():
		every.append(str(n.id))
	var rich = save_of(60, every, stages)
	p = RpgSkills.points(rich, 400)
	ok(p == {"earned": 148, "spent": 168, "left": -20, "from": {"start": 3, "level": 59, "bosses": 16, "stars": 20, "days": 50}}, "a rich save: the top level, 8 bosses, 240 stars, 400 days; all 90 nodes cost 168", p)
	ok(RpgSkills.known_moves(rich).size() == 8 + 58 and RpgSkills.known_ults(rich).size() == 8 and RpgSkills.known_passives(rich).size() == 24
		and RpgSkills.learnable(rich, sheet_of(99.0), 60, 400).is_empty(), "with every node: every board move, 8 ultimates, 24 passives, nothing left to learn",
		[RpgSkills.known_moves(rich).size(), RpgSkills.known_ults(rich).size()])


func learning() -> void:
	var low = sheet_of(5.0)
	var empty = RpgSave.empty()
	ok(why(empty, "push:one_two", low, 1) == "ok" and why(empty, "flow:supple", low, 1) == "ok", "an empty save may learn a tier 1 node")
	ok(why(empty, "push:nothing", low, 1) == "No such skill", "an unknown node", why(empty, "push:nothing", low, 1))
	ok(why(empty, "push:haymaker", sheet_of(99.0), 60) == "Learn a tier 1 Push skill first" and why(empty, "grit:titan_form", sheet_of(99.0), 60) == "Learn a tier 4 Grit skill first",
		"the tier below first, on the same board", why(empty, "push:haymaker", sheet_of(99.0), 60))
	var rpg = save_of(1, ["push:one_two"])
	ok(why(rpg, "push:one_two", low, 1) == "Already learned", "already learned", why(rpg, "push:one_two", low, 1))
	ok(why(rpg, "pull:reel_in", sheet_of(99.0), 60) == "Learn a tier 1 Pull skill first", "a node of another board does not open this one")

	# the fighter level: 1 / 1 / 4 / 10 / 18
	rpg = save_of(30, ["push:one_two", "push:haymaker", "push:bulldoze", "push:overhead_smash"])
	var top = sheet_of(99.0)
	ok(why(save_of(30, ["push:one_two", "push:haymaker"]), "push:bulldoze", top, 3) == "Needs fighter level 4" and why(save_of(30, ["push:one_two", "push:haymaker"]), "push:bulldoze", top, 4) == "ok"
		and why(rpg, "push:spotter", top, 9) == "Needs fighter level 10" and why(rpg, "push:spotter", top, 10) == "ok"
		and why(rpg, "push:titan_press", top, 17) == "Needs fighter level 18" and why(rpg, "push:titan_press", top, 18) == "ok",
		"the fighter level a tier asks for", why(rpg, "push:spotter", top, 9))

	# the stat: 1 / 12 / 24 / 36 / 46 of the node's own stat, never rounded up
	rpg = save_of(30, ["legs:lunge_strike", "legs:knee_crush", "legs:earthshaker", "legs:leg_day"])
	ok(why(rpg, "legs:root_stance", sheet_of(99.0, {"legs": 21.7}), 30) == "Needs Legs 24 (you have 21)" and why(rpg, "legs:root_stance", sheet_of(1.0, {"legs": 24.0}), 30) == "ok"
		and why(rpg, "legs:dropkick", sheet_of(99.0, {"legs": 11.99}), 30) == "Needs Legs 12 (you have 11)"
		and why(rpg, "legs:tree_trunks", sheet_of(99.0, {"legs": 35.0}), 30) == "Needs Legs 36 (you have 35)"
		and why(rpg, "legs:quake_drop", sheet_of(99.0, {"legs": 45.9}), 30) == "Needs Legs 46 (you have 45)" and why(rpg, "legs:quake_drop", sheet_of(1.0, {"legs": 46.0}), 30) == "ok",
		"the stat a tier asks for, with both numbers", why(rpg, "legs:root_stance", sheet_of(99.0, {"legs": 21.7}), 30))
	rpg = save_of(30, ["push:one_two", "pull:row_rip"])
	ok(why(rpg, "push:press_through", sheet_of(99.0, {"shoulders": 8.0}), 30) == "Needs Shoulders 12 (you have 8)" and why(rpg, "push:lockout", sheet_of(99.0, {"arms": 8.0}), 30) == "Needs Arms 12 (you have 8)"
		and why(rpg, "push:lockout", sheet_of(99.0, {"chest": 1.0}), 30) == "ok" and why(rpg, "pull:lat_spread", sheet_of(99.0, {"back": 3.0}), 30) == "Needs Back 12 (you have 3)"
		and why(rpg, "pull:chin_check", sheet_of(99.0, {"back": 3.0}), 30) == "ok" and why(rpg, "push:one_two", {}, 30) == "Already learned"
		and why(rpg, "push:bench_blast", {}, 30) == "Needs Chest 1 (you have 0)",
		"a move asks for its own biggest stat, a support move and a passive for the board's; a sheet with nothing in it has 0", why(rpg, "push:bench_blast", {}, 30))

	# the points
	rpg = save_of(1, ["push:one_two", "push:bench_blast", "push:haymaker"])
	ok(why(rpg, "push:lockout", top, 30) == "Not enough skill points (needs 1, you have 0)" and why(rpg, "push:lockout", top, 30, 8) == "ok", "no points left; a point from 8 active days",
		why(rpg, "push:lockout", top, 30))
	rpg = save_of(10, ["push:one_two", "push:bench_blast", "push:lockout_strength", "push:lockout", "push:haymaker", "push:press_through", "push:bulldoze", "push:burnout_set", "pull:row_rip"])
	ok(RpgSkills.points(rpg, 0).left == 1 and why(rpg, "push:overhead_smash", top, 10) == "Not enough skill points (needs 3, you have 1)"
		and why(rpg, "pull:arm_drag", top, 10) == "ok" and RpgSkills.learnable(rpg, top, 10, 0) == ["pull:arm_drag", "pull:grip_and_rip", "pull:reel_in", "pull:chin_check", "pull:lat_spread",
			"legs:lunge_strike", "legs:squat_launch", "legs:leg_drive", "speed:flurry", "speed:tempo_run", "speed:light_feet", "grip:crimp_strike", "grip:chalk_up", "grip:chalk_hands",
			"mind:read_the_room", "mind:hex_of_doubt", "mind:marginalia", "flow:counterstretch", "flow:supple", "grit:rally", "grit:stubborn"],
		"needs 3, has 1; learnable lists what one point buys", [why(rpg, "push:overhead_smash", top, 10), RpgSkills.learnable(rpg, top, 10, 0)])
	# the order: learned, the tier below, the level, the stat, the points
	rpg = save_of(1, ["push:one_two", "push:bench_blast", "push:lockout_strength", "push:haymaker"])
	ok(why(rpg, "push:bulldoze", low, 1) == "Needs fighter level 4" and why(rpg, "push:bulldoze", low, 4) == "Needs Chest 24 (you have 5)"
		and why(rpg, "push:bulldoze", top, 4) == "Not enough skill points (needs 2, you have 0)", "one reason at a time: the level, then the stat, then the points")
	ok(RpgSkills.learnable(empty, low, 1, 0).size() == 22 and RpgSkills.learnable(empty, sheet_of(0.5), 1, 0).is_empty()
		and RpgSkills.learnable(save_of(1, ["push:one_two", "pull:row_rip", "legs:lunge_strike"]), top, 60, 0).is_empty(),
		"learnable: every tier 1 node for a new fighter, nothing without the stat, nothing without points", RpgSkills.learnable(empty, low, 1, 0).size())

	# what the save knows; a learned node stays learned when the stat drops
	rpg = save_of(12, ["push:one_two", "push:haymaker", "push:bulldoze", "push:overhead_smash", "push:lockout_strength", "push:titan_press", "flow:supple", "push:gone"],
		{}, ["pain_cave", "no_such_scroll", "haymaker"])
	var weak = sheet_of(1.0)
	ok(RpgSkills.known_moves(rpg) == RpgMoves.STARTERS + ["one_two", "haymaker", "bulldoze", "overhead_smash", "pain_cave"] and RpgSkills.known_ults(rpg) == ["titan_press"]
		and RpgSkills.known_passives(rpg) == ["lockout_strength", "supple"], "known moves: starters, learned nodes, scrolls found; ultimates and passives apart",
		[RpgSkills.known_moves(rpg), RpgSkills.known_ults(rpg), RpgSkills.known_passives(rpg)])
	ok(why(rpg, "push:overhead_smash", weak, 1) == "Already learned" and RpgSkills.known_moves(rpg).has("overhead_smash") and RpgSkills.points(rpg, 0).spent == 13
		and RpgHero.knows_move(rpg, RpgMoves.by_id("overhead_smash")) and RpgSkills.has_node(rpg, "push:overhead_smash") and not RpgSkills.has_node(rpg, "push:spotter")
		and why(rpg, "push:spotter", weak, 12) == "Needs Chest 36 (you have 1)", "a learned node stays learned when the stat drops; the next one still asks for it")
	ok(RpgSkills.known_moves(RpgSave.empty()) == RpgMoves.STARTERS and RpgSkills.known_ults({}).is_empty() and RpgSkills.known_passives({}).is_empty(), "a new save knows the starters")


# =============================================================================
# Real fights

const CUSTOM = {
	"foe_moves": {"jab": {"name": "Jab", "power": 1.0}, "puff": {"name": "Puff Up", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "pumped", "turns": 2}]}},
	"foes": {"sandbag": {"name": "Sandbag", "role": "brute", "weak": ["push", "speed"], "resist": ["mind"], "moves": ["jab", "puff"], "pattern": ["jab", "jab", "puff"]},
		"wall": {"name": "Wall", "role": "tank", "weak": ["grip", "legs"], "moves": ["jab"], "pattern": ["jab"]}},
}


## A hero of tier 6 with these moves and this ultimate, full of energy and gauge when asked.
func fighter(school: String, moves: Array, ult: String, full: bool) -> Dictionary:
	var h = RpgHero.reference_hero(6.0, school if ATTACK.has(school) else "balanced")
	h["moves"] = moves
	h["ult"] = ult
	if full:
		h.fx.append({"p": "en_start", "n": 9})
		h.fx.append({"p": "gauge_start", "n": 100})
		h.fx.append({"p": "first_turn"})
	return h


func fights() -> void:
	# every move, once, by hand: it is allowed, it does something, the battle stays whole
	var bad = []
	for m in RpgMoves.all():
		var h = fighter(str(m.school), ["shove"] if bool(m.ult) else [str(m.id)], str(m.id) if bool(m.ult) else "", true)
		var B = RpgBattle.start({"hero": h, "pet": null, "waves": [[{"foe": "sandbag", "n": 40.0}, {"foe": "wall", "n": 40.0}]], "seed": 11, "custom": CUSTOM})
		var action = {"t": "ult", "target": str(RpgBattle.foes(B)[0].id)} if bool(m.ult) else {"t": "move", "id": str(m.id), "target": str(RpgBattle.foes(B)[0].id)}
		var no = RpgBattle.illegal(B, action)
		var ev = RpgBattle.act(B, action)
		var acted = ev.any(func(e): return str(e.t) == "act" and str(e.get("id", "")) == str(m.id))
		var hit = ev.any(func(e): return str(e.t) == "dmg" and str(e.get("src", "")) == str(B.hero.id))
		if no != "" or not acted or RpgBattle.json_safe(B) != "" or (str(m.kind) == "attack" and not hit):
			bad.append([m.id, no, acted, hit, RpgBattle.json_safe(B)])
	ok(bad.is_empty(), "each of the 90 moves is used in a battle: allowed, done, an attack lands, the battle stays JSON-safe", bad)

	# a build of four moves and the ultimate fights to the end, for every school (every move in some build)
	bad = []
	var used = {}
	var count = 0
	for school in RpgDefs.SCHOOLS:
		var list = RpgMoves.by_school(school).filter(func(m): return not bool(m.ult))
		var ult = str(RpgMoves.by_school(school).filter(func(m): return bool(m.ult))[0].id)
		var at = 0
		while at < list.size():
			var kit = []
			for i in range(4):
				kit.append(str(list[(at + i) % list.size()].id))
			at += 4
			count += 1
			var B = RpgBattle.start({"hero": fighter(school, kit, ult, false), "pet": null, "seed": 100 + count, "custom": CUSTOM,
				"waves": [[{"foe": "sandbag", "n": 30.0}, {"foe": "sandbag", "n": 30.0}], [{"foe": "wall", "n": 30.0}, {"foe": "sandbag", "n": 30.0}]]})
			var acts = 0
			var refused = 0
			var unsafe = ""
			while not RpgBattle.over(B) and acts < 500:
				var ev = RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
				acts += 1
				if ev.size() == 1 and str(ev[0].t) == "no":
					refused += 1
				if unsafe == "":
					unsafe = RpgBattle.json_safe(B)
				for e in ev:
					if str(e.t) == "act" and (str(e.get("kind", "")) == "move" or str(e.get("kind", "")) == "ult"):
						used[str(e.get("id", ""))] = true
			if not RpgBattle.over(B) or refused > 0 or unsafe != "" or B.hero.moves != kit or str(B.hero.ult) != ult:
				bad.append([school, kit, acts, refused, unsafe])
	ok(bad.is_empty() and count == 22, "a build of four moves and its school's ultimate fights to the end, for every school", [bad, count])
	var mine = 0
	for id in used:
		if RpgMoves.by_id(str(id)) != null:
			mine += 1
	print("fights: %d builds; the hero's own play used %d of the 90 moves" % [count, mine])
	ok(mine >= 45, "left to itself the hero uses most of what it has equipped", mine)
