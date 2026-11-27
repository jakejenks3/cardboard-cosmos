extends SceneTree
## Unit test for the Realm's foes (RPG_PLAN.md 8.3, with 4.4 to 4.6 and 8.1):
## game/rpg/rpg_foes.gd (RpgFoes). The catalog is exactly the plan's 56 foes
## with their roles; every foe and foe move passes the engine's validators;
## the weakness rules hold in every region; no hit passes 35% of the reference
## hero's HP; a stun never lands at more than 30% nor twice running; and the
## reference hero, played by the heuristic, fights every foe of every region
## (alone, in packs of three, the elite, the boss) on ten seeds each.
## It prints who is weak to what and a table of win rates and turns.
## Made-up heroes only (RpgHero.reference_hero); nothing here reads a save.
##   godot --headless --path . --script res://tests/rpg_foes_test.gd
## Prints RPG FOES: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0

## The plan's table: region, its five regular foes with their roles, its elite, its boss.
const TABLE = [
	["rustyard", [["dust_bunny", "swarm"], ["rust_rat", "skirmisher"], ["squeaky_plate", "tank"], ["loose_collar", "caster"], ["moldy_towel", "healer"]],
		"bent_bar", "old_iron_jaw"],
	["greenmile", [["burr", "swarm"], ["briar_fox", "skirmisher"], ["mud_slinger", "caster"], ["stag_beetle", "brute"], ["mile_marker", "bomb"]],
		"the_hill", "the_pacer"],
	["chalk", [["pebbling", "swarm"], ["cliff_bat", "skirmisher"], ["scree_golem", "tank"], ["chalk_wisp", "caster"], ["rope_snake", "brute"]],
		"overhang", "skyhook"],
	["stacks", [["bookworm", "swarm"], ["ink_blot", "caster"], ["dust_jacket", "healer"], ["paper_knight", "tank"], ["overdue_notice", "bomb"]],
		"the_index", "the_unread"],
	["ironworks", [["rivet_mite", "swarm"], ["slag_imp", "skirmisher"], ["anvil_back", "tank"], ["bellows", "caster"], ["molten_barbell", "brute"]],
		"press_golem", "foreman_slag"],
	["marsh", [["leech", "skirmisher"], ["bog_hopper", "swarm"], ["reed_wraith", "caster"], ["mud_mender", "healer"], ["mirror_shade", "brute"]],
		"knotroot", "the_knot"],
	["stormspine", [["static_mote", "swarm"], ["gale_hawk", "skirmisher"], ["rime_goat", "brute"], ["thunder_drum", "caster"], ["storm_eye", "caster"]],
		"cairn_giant", "thunderhead"],
	["titans_rest", [["stone_acolyte", "healer"], ["echo_knight", "tank"], ["relic_guard", "brute"], ["void_moth", "skirmisher"], ["titan_shard", "bomb"]],
		"the_gatekeeper", "the_hollow_titan"],
]
## The two schools a region leans on ([] = spread evenly).
const LEAN = {"rustyard": ["push", "legs"], "greenmile": ["speed", "pull"], "chalk": ["grip", "pull"], "stacks": ["mind", "speed"],
	"ironworks": ["legs", "push"], "marsh": ["mind", "grip"], "stormspine": [], "titans_rest": []}
## The archetype of RpgHero.reference_hero that suits each region (its leaning school; the last two regions lean on none).
const MATCHED = {"rustyard": "push", "greenmile": "speed", "chalk": "grip", "stacks": "mind", "ironworks": "legs", "marsh": "mind",
	"stormspine": "speed", "titans_rest": "pull"}
## No hit takes more of the reference hero's HP than this (4.1) ...
const CAP = 0.35
## ... and not more than this on the worst day: a crit, and Pumped / Exposed from a foe beside it.
const CAP_WORST = 0.45
const STUN_MOST = 0.30
const SEEDS = 10
## An action count no fight should reach.
const ACTS_MOST = 400


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_catalog()
	_weaknesses()
	_shapes()
	_numbers()
	_fights()
	print("RPG FOES: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


## The index of a region (0..7).
func region_at(region: String) -> int:
	return RpgDefs.REGIONS.find(region)


# =============================================================================
# The catalog is the plan's
# =============================================================================

func _catalog() -> void:
	var want = []
	var roles = {}
	var regions = {}
	for row in TABLE:
		for pair in row[1]:
			want.append(pair[0])
			roles[pair[0]] = pair[1]
			regions[pair[0]] = row[0]
		want.append(row[2])
		roles[row[2]] = "elite"
		regions[row[2]] = row[0]
		want.append(row[3])
		roles[row[3]] = "boss"
		regions[row[3]] = row[0]
	var have = []
	for f in RpgFoes.all():
		have.append(str(f.id))
	ok(want.size() == 56 and have == want, "exactly the plan's 56 foes, in the plan's order", [have.size(), have])
	var bad = []
	var names = {}
	for f in RpgFoes.all():
		var id = str(f.id)
		if str(f.role) != str(roles.get(id, "")) or str(f.region) != str(regions.get(id, "")):
			bad.append(id + ": role or region")
		if bool(f.boss) != (str(f.role) == "boss") or bool(f.elite) != (str(f.role) == "elite"):
			bad.append(id + ": flags")
		if RpgDefs.id_of(str(f.name)) != id:
			bad.append(id + ": its id is not its name's")
		if names.has(str(f.name)):
			bad.append(id + ": a name used twice")
		names[str(f.name)] = true
		if str(f.text).length() < 12:
			bad.append(id + ": no line for its sheet")
		if RpgFoes.by_id(id) != f:
			bad.append(id + ": by_id")
	ok(bad.is_empty(), "every foe has the plan's role and region, an id made from its name, a line of text", bad)

	bad = []
	for f in RpgFoes.all():
		var why = RpgBattle.check_foe(f)
		if why != "":
			bad.append(why)
	ok(bad.is_empty(), "every foe passes RpgBattle.check_foe", bad)
	bad = []
	var used = {}
	for f in RpgFoes.all():
		for id in f.moves:
			used[str(id)] = true
	var move_names = {}
	for mv in RpgFoes.moves():
		var why = RpgBattle.check_foe_move(mv)
		if why != "":
			bad.append(why)
		if not used.has(str(mv.id)):
			bad.append(str(mv.id) + ": no foe uses it")
		if RpgFoes.move(str(mv.id)) != mv:
			bad.append(str(mv.id) + ": move()")
		if not RpgDefs.ICONS.has(str(mv.icon)):
			bad.append(str(mv.id) + ": unknown icon " + str(mv.icon))
		if move_names.has(str(mv.name)):
			bad.append(str(mv.id) + ": a move name used twice")
		move_names[str(mv.name)] = true
		if (int(mv.windup) > 0 or int(mv.count) > 0 or not mv.fx.is_empty() or not mv.foes.is_empty()) and str(mv.text) == "":
			bad.append(str(mv.id) + ": a move that is more than a hit needs a line for its intent")
	ok(bad.is_empty() and RpgFoes.moves().size() >= 120, "every foe move passes check_foe_move, is used, has a known icon and its words", [RpgFoes.moves().size(), bad])

	bad = []
	for f in RpgFoes.all():
		var listed = {}
		for id in f.moves:
			listed[str(id)] = 0
		if f.moves.size() < 1 or f.moves.size() > 7:
			bad.append(str(f.id) + ": moves")
		for id in f.pattern:
			listed[str(id)] = int(listed.get(str(id), 0)) + 1
		for r in f.rules:
			listed[str(r.use)] = int(listed.get(str(r.use), 0)) + 1
		for ph in f.phases:
			for id in ph.get("pattern", []):
				listed[str(id)] = int(listed.get(str(id), 0)) + 1
		for id in listed:
			if int(listed[id]) == 0:
				bad.append("%s never uses %s" % [str(f.id), str(id)])
			if RpgFoes.move(str(id)) == null:
				bad.append("%s: unknown move %s" % [str(f.id), str(id)])
	ok(bad.is_empty(), "pattern, rule and phase moves resolve, and a foe uses every move it lists", bad)

	bad = []
	for row in TABLE:
		var got = RpgFoes.of_region(str(row[0]))
		var regular = []
		for pair in row[1]:
			regular.append(pair[0])
		if got.regular != regular or got.elite != row[2] or got.boss != row[3]:
			bad.append(row[0])
	ok(bad.is_empty() and RpgFoes.of_region("nowhere") == {"regular": [], "elite": "", "boss": ""}, "of_region: five regulars, the elite, the boss", bad)
	ok(RpgFoes.key_of("old_iron_jaw") == "old_iron_jaw" and RpgFoes.key_of("old_iron_jaw", 1) == "old_iron_jaw#2" and RpgFoes.key_of("the_hollow_titan", 2) == "the_hollow_titan#3",
		"key_of: the id, then id#2, id#3 as a boss changes")
	ok(RpgFoes.weak_of("the_hollow_titan", 0) == ["push", "pull"] and RpgFoes.weak_of("the_hollow_titan", 1) == ["legs", "speed"]
		and RpgFoes.weak_of("the_hollow_titan", 2) == ["grip", "mind"] and RpgFoes.weak_of("nobody") == [] and RpgFoes.resist_of("skyhook", 1) == ["legs"]
		and RpgFoes.resist_of("skyhook", 0) == [], "weak_of / resist_of follow a boss through its phases")
	ok(RpgFoes.all_known().size() == 56 + 9 and RpgFoes.all_known().get("the_pacer#2") == ["pull", "mind"], "all_known: a key for every foe and every boss phase", RpgFoes.all_known().size())


# =============================================================================
# Who is weak to what
# =============================================================================

func _weaknesses() -> void:
	print("--- weak to (regular foes; elite and boss after the bar) ---")
	var bad = []
	for row in TABLE:
		var region = str(row[0])
		var counts = {}
		var who = {}
		for sc in RpgDefs.ATTACK_SCHOOLS:
			counts[sc] = 0
			who[sc] = []
		for pair in row[1]:
			var f = RpgFoes.by_id(str(pair[0]))
			for sc in f.weak:
				counts[sc] = int(counts[sc]) + 1
				who[sc].append(str(f.id))
		var line = "%-11s" % region
		for sc in RpgDefs.ATTACK_SCHOOLS:
			line += " %s: %s;" % [sc, ", ".join(who[sc])]
			if int(counts[sc]) < 1:
				bad.append("%s: no regular foe is weak to %s" % [region, sc])
		var big = []
		for id in [row[2], row[3]]:
			var f = RpgFoes.by_id(str(id))
			var parts = ["/".join(f.weak)]
			for ph in range(f.phases.size()):
				parts.append("/".join(RpgFoes.weak_of(str(id), ph + 1)))
			big.append("%s %s" % [str(id), " then ".join(parts)])
		print(line + " | " + "; ".join(big))
		var lean = LEAN[region]
		if lean.is_empty():
			for sc in counts:
				if int(counts[sc]) > 2:
					bad.append("%s is meant to be spread evenly: %s has %d" % [region, sc, int(counts[sc])])
		else:
			var least = 99
			var most_other = 0
			for sc in counts:
				if lean.has(sc):
					least = mini(least, int(counts[sc]))
				else:
					most_other = maxi(most_other, int(counts[sc]))
			if least <= most_other:
				bad.append("%s should lean on %s: %s" % [region, str(lean), str(counts)])
			# the elite and the boss open on the region's schools
			for id in [row[2], row[3]]:
				var f = RpgFoes.by_id(str(id))
				if not (lean.has(f.weak[0]) or lean.has(f.weak[1])):
					bad.append("%s: weak to neither of its region's schools" % str(id))
	ok(bad.is_empty(), "every school is some regular foe's weakness in every region, and the region's two lead", bad)

	bad = []
	for f in RpgFoes.all():
		if f.weak.size() != 2 or f.resist.size() > 1:
			bad.append(str(f.id))
		var last = f.weak
		for ph in range(f.phases.size()):
			var now = RpgFoes.weak_of(str(f.id), ph + 1)
			if now == last or now.size() != 2:
				bad.append("%s: phase %d has the weaknesses it had" % [str(f.id), ph + 2])
			var res = RpgFoes.resist_of(str(f.id), ph + 1)
			if res.size() > 1 or (res.size() == 1 and now.has(res[0])):
				bad.append("%s: phase %d resists what it is weak to" % [str(f.id), ph + 2])
			last = now
	ok(bad.is_empty(), "two weaknesses, at most one resist; a boss's phases are each weak to something new", bad)


# =============================================================================
# What each kind of foe must have
# =============================================================================

func _shapes() -> void:
	var bad = []
	for f in RpgFoes.all():
		var id = str(f.id)
		var guard = RpgFoes.guard_of(f)
		if bool(f.boss):
			var want = 2 if id == "the_hollow_titan" else 1
			if f.phases.size() != want:
				bad.append("%s: %d phases" % [id, f.phases.size()])
			for ph in f.phases:
				if str(ph.get("say", "")).length() < 8 or ph.get("pattern", []).size() < 3:
					bad.append(id + ": a phase needs a line to say and a pattern of its own")
			if guard < 4 or guard > 6:
				bad.append(id + ": a boss's guard is 4 to 6")
		elif bool(f.elite):
			if guard < 4 or not f.phases.is_empty():
				bad.append(id + ": an elite has a real guard and no phases")
		else:
			if not f.phases.is_empty():
				bad.append(id + ": only a boss has phases")
			if guard < 1 or guard > 4:
				bad.append("%s: a regular foe's guard is 1 to 4 (a break must be within reach): %d" % [id, guard])
		if f.moves.size() < 2 and str(f.role) != "bomb":
			bad.append(id + ": two moves or more")
		if f.pattern.size() < 2 and str(f.role) != "bomb":
			bad.append(id + ": a pattern is a rhythm, not one note")
		for w in RpgFoes.words(f):
			if not (w is String) or str(w) == "":
				bad.append(id + ": words()")
		if RpgFoes.words(f).size() < 2:
			bad.append(id + ": words() says too little")
		for t in f.traits:
			if RpgBattle.check_passive(t) != "":
				bad.append(id + ": " + RpgBattle.check_passive(t))
	ok(bad.is_empty(), "bosses have their phases (the Hollow Titan three in all), guards are within reach, every foe has a rhythm and words", bad)

	# the roles do what the plan says of them
	bad = []
	for f in RpgFoes.all():
		var id = str(f.id)
		var kinds = {}
		for mid in f.moves:
			kinds[str(RpgFoes.move(str(mid)).kind)] = true
		match str(f.role):
			"healer":
				if not (kinds.has("heal") or kinds.has("shield")):
					bad.append(id + ": a healer heals or shields")
			"bomb":
				if not kinds.has("bomb"):
					bad.append(id + ": a bomb counts down")
			"caster":
				if not (kinds.has("debuff") or kinds.has("buff")):
					bad.append(id + ": a caster hexes or cheers")
			"boss":
				if not kinds.has("heavy") and not kinds.has("bomb"):
					bad.append(id + ": a boss has a hit to see coming")
	for pair in [["mirror_shade", "adapt"], ["the_pacer", "quicken"], ["the_hill", "ramp"], ["the_unread", "ramp"]]:
		var has = false
		for t in RpgFoes.by_id(pair[0]).traits:
			if str(t.p) == pair[1]:
				has = true
		if not has:
			bad.append("%s: no %s" % pair)
	for pair in [["old_iron_jaw", "dust_bunny"], ["the_knot", "leech"], ["foreman_slag", "rivet_mite"], ["the_hollow_titan", "titan_shard"]]:
		if not _brings(RpgFoes.by_id(pair[0])).has(pair[1]):
			bad.append("%s does not bring %s" % pair)
	for pair in [["anvil_back", "counter"], ["the_gatekeeper", "counter"], ["briar_fox", "hasted"], ["bellows", "pumped"], ["thunder_drum", "hasted"]]:
		if not _gives(RpgFoes.by_id(pair[0]), pair[1], false):
			bad.append("%s never gives its side %s" % pair)
	for pair in [["loose_collar", "weakened"], ["mud_slinger", "slowed"], ["chalk_wisp", "exposed"], ["rope_snake", "bleed"], ["ink_blot", "burn"],
			["slag_imp", "burn"], ["reed_wraith", "bleed"], ["static_mote", "stun"], ["rime_goat", "slowed"], ["thunderhead", "stun"]]:
		if not _gives(RpgFoes.by_id(pair[0]), pair[1], true):
			bad.append("%s never leaves the hero %s" % pair)
	ok(bad.is_empty(), "healers heal, bombs count down, casters hex, and each foe has the trick the plan names", bad)


## The foe ids a foe can bring (its summon moves and its phases).
func _brings(f: Dictionary) -> Array:
	var out = []
	for mid in f.moves:
		out.append_array(RpgFoes.move(str(mid)).foes)
	for ph in f.phases:
		out.append_array(ph.get("summon", []))
	return out


## Does some move of the foe give that status: to the hero (`on_hero`), or to itself / its side?
func _gives(f: Dictionary, status: String, on_hero: bool) -> bool:
	for mid in f.moves:
		var mv = RpgFoes.move(str(mid))
		for e in mv.fx:
			if str(e.get("k", "")) != "status" or str(e.id) != status:
				continue
			var hero = str(mv.target) == "hero" and not ["self", "allies", "ally"].has(str(e.get("to", "")))
			if hero == on_hero:
				return true
	if not on_hero:
		for ph in f.phases:
			for e in ph.get("fx", []):
				if str(e.get("k", "")) == "status" and str(e.id) == status:
					return true
	return false


# =============================================================================
# The numbers: the cap on a hit, stuns, the weight of a pattern
# =============================================================================

## The turns a move takes and the power it lands in them.
func _turns_of(mv: Dictionary) -> int:
	if int(mv.count) > 0:
		return int(mv.count)
	return 1 + int(mv.windup)


## The power a pattern lands per turn of the foe.
func _mean_power(pattern: Array) -> float:
	var power = 0.0
	var turns = 0
	for mid in pattern:
		var mv = RpgFoes.move(str(mid))
		power += float(mv.power)
		turns += _turns_of(mv)
	return power / float(maxi(1, turns))


func _stuns(mv: Dictionary) -> float:
	for e in mv.fx:
		if str(e.get("k", "")) == "status" and str(e.id) == "stun" and str(mv.target) == "hero":
			return float(e.get("chance", 1.0))
	return 0.0


func _numbers() -> void:
	# what a foe can stack on a hit by itself: its traits, Pumped, Exposed
	var over = []
	var over_worst = []
	var top = 0.0
	var top_who = ""
	for row in TABLE:
		var region = str(row[0])
		var ids = []
		for pair in row[1]:
			ids.append(pair[0])
		var mate_pump = false
		var mate_expose = false
		for id in ids:
			var g = RpgFoes.by_id(str(id))
			for mid in g.moves:
				var mv = RpgFoes.move(str(mid))
				for e in mv.fx:
					if str(e.get("k", "")) == "status" and str(e.id) == "pumped" and ["allies", "ally"].has(str(mv.target)):
						mate_pump = true
			if _gives(g, "exposed", true):
				mate_expose = true
		ids.append(row[2])
		ids.append(row[3])
		var base_n = 10.0 * float(region_at(region))
		for id in ids:
			var f = RpgFoes.by_id(str(id))
			var n = base_n + (9.0 if bool(f.boss) else (4.0 if bool(f.elite) else 2.0))
			var t = RpgDefs.tier_of_n(n)
			var agg = RpgBattle.aggregate(f.traits)
			var trait_up = 1.0
			for tr in f.traits:
				match str(tr.p):
					"ramp":
						trait_up += float(tr.max)
					"vs_status":
						trait_up += float(tr.pct)
					"school_pct":
						trait_up += float(tr.pct)
			var own = trait_up
			if _gives(f, "pumped", false):
				own *= 1.0 + RpgDefs.PUMP
			if _gives(f, "exposed", true):
				own *= 1.0 + RpgDefs.BRACE
			var worst = trait_up * (1.0 + RpgDefs.PUMP if (mate_pump or _gives(f, "pumped", false)) else 1.0) \
				* (1.0 + RpgDefs.BRACE if (mate_expose or _gives(f, "exposed", true)) else 1.0) * (1.0 if bool(f.boss) else RpgDefs.FOE_CRIT_MULT)
			for pack in [1, 3]:
				var u = RpgFoes.make(str(id), n, pack)
				if u == null or int(u.hp_max) < 1 or float(u.atk) <= 0.0 or float(u.spd) <= 0.0 or int(u.guard) != RpgFoes.guard_of(f) or agg == null:
					over.append(str(id) + ": make()")
					continue
				for mid in f.moves:
					var mv = RpgFoes.move(str(mid))
					var share = float(u.atk) * float(mv.power) * RpgDefs.mitigation(RpgDefs.ref_def(t)) / RpgDefs.ref_hp(t)
					if share * own > top:
						top = share * own
						top_who = "%s %s" % [str(id), str(mid)]
					if share * own > CAP:
						over.append("%s %s (pack %d): %.3f" % [str(id), str(mid), pack, share * own])
					if share * worst > CAP_WORST:
						over_worst.append("%s %s (pack %d): %.3f" % [str(id), str(mid), pack, share * worst])
	ok(over.is_empty(), "no move of any foe takes more than 35% of the reference hero's HP, alone or in a pack of three, with all it can stack itself", over)
	ok(over_worst.is_empty(), "nor more than 45% on the worst day (a crit, Pumped and Exposed by a foe beside it)", over_worst)
	print("the biggest hit of the catalog: %s, %.1f%% of the reference hero's HP" % [top_who, top * 100.0])

	# a pack shares: three regulars have half each; an elite, a boss never
	var one = RpgFoes.make("stag_beetle", 12.0, 1)
	var three = RpgFoes.make("stag_beetle", 12.0, 3)
	var boss1 = RpgFoes.make("the_pacer", 19.0, 1)
	var boss3 = RpgFoes.make("the_pacer", 19.0, 3)
	ok(absf(float(three.hp_max) / float(one.hp_max) - 0.5) < 0.01 and absf(float(three.atk) / float(one.atk) - 0.5) < 0.001 and int(boss1.hp_max) == int(boss3.hp_max)
		and RpgFoes.make("nobody", 0.0) == null, "make: a pack of three has half each, a boss is never scaled, an unknown id is null")
	var set_up = RpgFoes.make("dust_bunny", 0.0, 1, {"weak": ["mind", "grip"], "guard_add": 2})
	ok(set_up.weak == ["mind", "grip"] and bool(set_up.shown) and int(set_up.guard) == 3, "make: opts set the weaknesses (shown) and add guard", [set_up.weak, set_up.guard])

	# stuns: at most 30% as they land on the reference hero at the end of the region, never twice running
	var bad = []
	for f in RpgFoes.all():
		var n = 10.0 * float(region_at(str(f.region))) + 9.0
		var t = RpgDefs.tier_of_n(n)
		var add = float(RpgBattle.aggregate(f.traits).get("status_chance", 0.0))
		for mid in f.moves:
			var base = _stuns(RpgFoes.move(str(mid)))
			if base <= 0.0:
				continue
			var lands = RpgDefs.status_chance(base + add, RpgDefs.foe_tec(n, bool(f.elite), bool(f.boss)), RpgDefs.ref_side(t))
			if lands > STUN_MOST + 0.0001:
				bad.append("%s %s lands at %.2f" % [str(f.id), str(mid), lands])
		var patterns = [f.pattern]
		for ph in f.phases:
			patterns.append(ph.get("pattern", []))
		for p in patterns:
			for i in range(p.size()):
				if _stuns(RpgFoes.move(str(p[i]))) > 0.0 and _stuns(RpgFoes.move(str(p[(i + 1) % p.size()]))) > 0.0:
					bad.append("%s: two stuns running in a pattern" % str(f.id))
		for r in f.rules:
			if _stuns(RpgFoes.move(str(r.use))) > 0.0:
				bad.append("%s: a stun on a rule could come twice running" % str(f.id))
	ok(bad.is_empty(), "a stun lands at 30% at most and never twice running from one foe", bad)

	# the weight of a pattern: about power 1 a turn times the role's attack; the Rustyard is gentler
	bad = []
	print("--- pressure (mean power a turn x the role's attack; a boss per phase) ---")
	for row in TABLE:
		var line = "%-11s" % str(row[0])
		var ids = []
		for pair in row[1]:
			ids.append(pair[0])
		ids.append(row[2])
		ids.append(row[3])
		for id in ids:
			var f = RpgFoes.by_id(str(id))
			var atk = float(RpgDefs.role(str(f.role))[1])
			var patterns = [f.pattern]
			for ph in f.phases:
				patterns.append(ph.get("pattern", []))
			var parts = []
			for p in patterns:
				var mean = _mean_power(p)
				parts.append("%.2f" % (mean * atk))
				var big = bool(f.boss) or bool(f.elite)
				var lo = 0.2 if str(f.role) == "healer" else 0.3
				# a regular foe's role attack is about 1; an elite's and a boss's are higher since the balance step
				# (bosses had been won every time), and a bomb's whole weight is its one blast
				var hi = 1.4
				if bool(f.boss):
					hi = 2.5
				elif bool(f.elite):
					hi = 1.9
				elif str(f.role) == "bomb":
					hi = 2.1
				elif str(f.region) == "rustyard":
					hi = 1.15
				if mean * atk < lo or mean * atk > hi or mean > (2.6 if str(f.role) == "bomb" else 1.25) or (big and mean < 0.75):
					bad.append("%s: %.2f a turn (x %.2f)" % [str(id), mean, atk])
			line += " %s %s;" % [str(id), "/".join(parts)]
		print(line)
	ok(bad.is_empty(), "a pattern lands about power 1 a turn (0.75 to 1.25 for an elite or a boss)", bad)
	bad = []
	for mv in RpgFoes.moves():
		var p = float(mv.power)
		if int(mv.windup) > 0 and p > 0.0 and (p < 1.7 or p > 2.6):
			bad.append(str(mv.id) + ": a wind-up hit is 1.7 to 2.6")
		if int(mv.windup) == 0 and int(mv.count) == 0 and p > 1.35:
			bad.append(str(mv.id) + ": a hit this big must be seen coming")
		if str(mv.kind) == "debuff" and str(mv.target) == "hero" and (p < 0.4 or p > 1.0):
			bad.append(str(mv.id) + ": a debuff move hits for 0.4 to 1.0")
	ok(bad.is_empty(), "a hit above 1.35 is always a wind-up or a countdown; a hex hits lightly", bad)


# =============================================================================
# The reference hero fights them all
# =============================================================================

## One fight of the reference hero of the foes' tier, played by the heuristic:
## {"over", "win", "turns", "hp" (the share of HP left), "refused"}.
func fight(names: Array, n: float, fight_seed: int, known: bool, arch: String = "balanced") -> Dictionary:
	var wave = []
	for id in names:
		wave.append({"foe": str(id), "n": n})
	var setup = {"hero": RpgHero.reference_hero(RpgDefs.tier_of_n(n), arch), "pet": null, "waves": [wave], "seed": fight_seed, "what": {"kind": "test"}}
	if known:
		setup["known"] = RpgFoes.all_known()
	var B = RpgBattle.start(setup)
	var acts = 0
	var refused = 0
	while not RpgBattle.over(B) and acts < ACTS_MOST:
		var ev = RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
		acts += 1
		if ev.size() == 1 and str(ev[0].t) == "no":
			refused += 1
	var s = RpgBattle.summary(B)
	return {"over": RpgBattle.over(B), "win": RpgBattle.won(B), "turns": int(s.turns), "refused": refused,
		"hp": clampf(float(B.hero.hp) / maxf(1.0, float(B.hero.hp_max)), 0.0, 1.0)}


## Ten seeds of one fight: {"wins", "turns" (the median of the wins, else of all), "hp" (the median share left), "bad" (unfinished or refused)}.
func series(names: Array, n: float, seed_base: int, known: bool = true, arch: String = "balanced") -> Dictionary:
	var wins = 0
	var bad = 0
	var turns_won = []
	var turns_all = []
	var hps = []
	for i in range(SEEDS):
		var r = fight(names, n, seed_base + i * 7919, known, arch)
		if not bool(r.over) or int(r.refused) > 0:
			bad += 1
		turns_all.append(int(r.turns))
		hps.append(float(r.hp))
		if bool(r.win):
			wins += 1
			turns_won.append(int(r.turns))
	var turns = turns_won if not turns_won.is_empty() else turns_all
	turns.sort()
	hps.sort()
	var mid = int(floor(float(SEEDS) / 2.0))
	return {"wins": wins, "turns": int(turns[mini(mid, turns.size() - 1)]), "hp": float(hps[mid]), "bad": bad}


func cell(label: String, r: Dictionary) -> String:
	return "%s %d/%d %dt %d%%" % [label, int(r.wins), SEEDS, int(r.turns), int(round(float(r.hp) * 100.0))]


func _fights() -> void:
	print("--- the reference hero (balanced, weaknesses known) against each: wins/10, median hero turns, median HP left ---")
	var broken = []
	var slow = []
	var lost = []
	var boss_lines = []
	var matched = []
	var seed_at = 4000
	for row in TABLE:
		var region = str(row[0])
		var base_n = 10.0 * float(region_at(region))
		var ids = []
		for pair in row[1]:
			ids.append(str(pair[0]))
		var cells = []
		for id in ids:
			seed_at += 101
			var r = series([id], base_n + 2.0, seed_at)
			cells.append(cell(id, r))
			if int(r.bad) > 0:
				broken.append(id)
			if int(r.turns) >= 12:
				slow.append("%s: %d turns" % [id, int(r.turns)])
			if int(r.wins) < 8:
				lost.append("%s alone: %d/10" % [id, int(r.wins)])
		print("%-11s %s" % [region, " | ".join(cells)])
		cells = []
		var packs = [[ids[0], ids[1], ids[2]], [ids[2], ids[3], ids[4]]]
		for pi in range(packs.size()):
			seed_at += 101
			var r = series(packs[pi], base_n + 6.0, seed_at)
			cells.append(cell("pack %s" % "+".join(packs[pi]), r))
			if int(r.bad) > 0:
				broken.append("%s pack %d" % [region, pi])
			if int(r.turns) >= 14:
				slow.append("%s pack %d: %d turns" % [region, pi, int(r.turns)])
			if int(r.wins) < 6:
				lost.append("%s pack %d: %d/10" % [region, pi, int(r.wins)])
		seed_at += 101
		var e = series([row[2]], base_n + 4.0, seed_at)
		cells.append(cell(str(row[2]), e))
		if int(e.bad) > 0:
			broken.append(str(row[2]))
		if int(e.wins) < 5:
			lost.append("%s: %d/10" % [str(row[2]), int(e.wins)])
		seed_at += 101
		var b = series([row[3]], base_n + 9.0, seed_at)
		var blind = series([row[3]], base_n + 9.0, seed_at, false)
		cells.append(cell(str(row[3]), b))
		cells.append(cell("(first meeting)", blind))
		# a hero built for the region (its first school): what a player who reads the weaknesses gets
		var arch = str(MATCHED[region])
		var em = series([row[2]], base_n + 4.0, seed_at + 13, true, arch)
		var bm = series([row[3]], base_n + 9.0, seed_at + 17, true, arch)
		matched.append("%s: %s | %s" % [arch, cell(str(row[2]), em), cell(str(row[3]), bm)])
		if int(em.bad) > 0 or int(bm.bad) > 0:
			broken.append("%s with the %s hero" % [region, arch])
		if int(bm.wins) < 2:
			lost.append("%s with the %s hero: %d/10" % [str(row[3]), arch, int(bm.wins)])
		boss_lines.append([str(row[3]), int(b.wins), int(blind.wins), int(b.turns)])
		if int(b.bad) > 0 or int(blind.bad) > 0:
			broken.append(str(row[3]))
		if int(b.wins) < 2:
			lost.append("%s: %d/10" % [str(row[3]), int(b.wins)])
		print("%-11s %s" % ["", " | ".join(cells)])
	print("--- the same elites and bosses against a hero built for the region ---")
	for line in matched:
		print("            " + line)
	ok(broken.is_empty(), "every fight ends, and the heuristic never asks for something the engine turns down", broken)
	ok(slow.is_empty(), "a regular foe alone is beaten in under 12 hero turns, a pack of three in under 14", slow)
	ok(lost.is_empty(), "the reference hero beats regular foes (8 of 10 alone, 6 of 10 a pack), most elites, and no boss is unbeatable", lost)
	var first = boss_lines[0]
	# the balance step put every boss at 55 to 85% for a reference hero who knows the weaknesses; a first meeting is harder
	ok(int(first[1]) >= 7 and int(first[2]) >= 4, "Old Iron-Jaw falls to the tier-1 reference hero most of the time once its weaknesses are known, and about half the time at a first meeting", first)
