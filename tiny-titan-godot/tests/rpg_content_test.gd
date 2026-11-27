extends SceneTree
## The net under the Realm's whole content (RPG_PLAN.md 13): every catalog
## against every other. Each catalog has a test of its own for what it is;
## this one checks that they FIT: every id one of them names is an id another
## one has, every row passes the engine's validator for its kind, every icon
## and sprite and backdrop exists, no two things share an id where that would
## be a clash, and the things made on the fly (hunts, Spire floors, rivals,
## rune rolls, caches, chests) are well formed over a wide sweep.
## Reads only the game's own tables; no save, no log.
##   godot --headless --path . --script res://tests/rpg_content_test.gd
## Prints RPG CONTENT: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_validators()
	_references()
	_names_and_icons()
	_clashes()
	_made_on_the_fly()
	print("RPG CONTENT: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


func ids_of(rows: Array) -> Array:
	return rows.map(func(r): return str(r.id))


func doubles(list: Array) -> Array:
	var seen = {}
	var out = []
	for id in list:
		if seen.has(id):
			out.append(id)
		seen[id] = true
	return out


## Every passive effect of a list, checked: the problems.
func bad_passives(tag: String, fx) -> Array:
	var out = []
	if not (fx is Array):
		return [tag + ": no list of effects"]
	for e in fx:
		var why = RpgBattle.check_passive(e)
		if why != "":
			out.append("%s: %s" % [tag, why])
	return out


# --- every row passes its validator --------------------------------------------------

func _validators() -> void:
	var bad = []
	for m in RpgMoves.all():
		var why = RpgBattle.check_move(m)
		if why != "":
			bad.append(why)
	ok(bad.is_empty() and RpgMoves.all().size() >= 80, "every hero move passes check_move", bad)
	bad = []
	for p in RpgPassives.all():
		bad.append_array(bad_passives("passive " + str(p.id), p.fx))
		if p.fx.is_empty():
			bad.append(str(p.id) + ": does nothing")
	ok(bad.is_empty() and RpgPassives.all().size() == 24, "every board passive is made of valid passive effects", bad)
	bad = []
	var uniques = 0
	for g in RpgGear.all():
		for line in g.lines:
			if not RpgGear.LINE_KINDS.has(str(line.k)) or RpgBattle.check_passive(RpgGear.line_fx(line)) != "":
				bad.append("%s: line %s" % [g.id, str(line)])
		if g.unique != null:
			uniques += 1
			bad.append_array(bad_passives("unique of " + str(g.id), g.unique.get("fx")))
			if str(g.unique.get("name", "")) == "" or str(g.unique.get("text", "")) == "":
				bad.append("%s: a unique without a name or words" % g.id)
		for plus in [1, RpgDefs.PLUS_MAX]:
			if RpgGear.of(str(g.id), plus) == null or RpgGear.of(str(g.id), plus).lines.size() != g.lines.size():
				bad.append("%s at +%d" % [g.id, plus])
	ok(bad.is_empty() and uniques >= 30, "every gear row: valid lines at +0, +1 and +10, and a valid unique where it has one", bad)
	bad = []
	for sid in RpgGear.SETS:
		var set_row = RpgGear.SETS[sid]
		for part in ["two", "four"]:
			bad.append_array(bad_passives("set %s %s" % [sid, part], set_row[part].get("fx")))
			if str(set_row[part].get("text", "")) == "":
				bad.append("set %s %s: no words" % [sid, part])
	ok(bad.is_empty() and RpgGear.SETS.size() == 7 and RpgGear.SET_ORDER.size() == 7 and RpgGear.SET_ORDER.all(func(s): return RpgGear.SETS.has(s)), "every set bonus is made of valid passive effects", bad)
	bad = []
	for r in RpgRelics.all():
		bad.append_array(bad_passives("relic " + str(r.id), r.fx))
		if r.fx.is_empty() or not RpgDefs.RARITIES.has(str(r.rarity)) or str(r.text) == "" or str(r.name) == "" or RpgDefs.id_of(str(r.name)) != str(r.id):
			bad.append("relic %s: its row" % r.id)
	ok(bad.is_empty() and RpgRelics.all().size() == 24, "every relic: valid effects, a rarity, words, an id made from its name", bad)
	bad = []
	for it in RpgItems.all():
		if RpgBattle.check_item(it) != "":
			bad.append(RpgBattle.check_item(it))
	ok(bad.is_empty() and RpgItems.all().size() == 8, "every belt item passes check_item", bad)
	bad = []
	for kit in RpgPets.all():
		if RpgBattle.check_pet(kit) != "":
			bad.append(RpgBattle.check_pet(kit))
	ok(bad.is_empty() and RpgPets.all().size() == 16, "every companion's kit passes check_pet", bad)
	bad = []
	for f in RpgFoes.all():
		if RpgBattle.check_foe(f) != "":
			bad.append(RpgBattle.check_foe(f))
	ok(bad.is_empty() and RpgFoes.all().size() == 56, "every foe passes check_foe", bad)
	bad = []
	for mv in RpgFoes.moves():
		if RpgBattle.check_foe_move(mv) != "":
			bad.append(RpgBattle.check_foe_move(mv))
	ok(bad.is_empty(), "every foe move passes check_foe_move", bad)
	bad = []
	for a in RpgHero.ARCHETYPES:
		for t in [1.0, 2.0, 4.0, 6.0, 8.0]:
			var hero = RpgHero.reference_hero(t, a)
			if hero.moves.is_empty() or hero.moves.any(func(id): return RpgMoves.by_id(str(id)) == null) or (str(hero.ult) != "" and RpgMoves.by_id(str(hero.ult)) == null) or RpgHero.power(hero) <= 0.0:
				bad.append("%s at tier %s" % [a, str(t)])
			bad.append_array(bad_passives("%s at tier %s" % [a, str(t)], hero.fx))
	ok(bad.is_empty(), "every reference hero is built of moves and passives that exist", bad)


# --- every id named anywhere is an id somebody has ---------------------------------------

func _references() -> void:
	# skill nodes -> moves and passives
	var bad = []
	var refs = {}
	for n in RpgSkills.all():
		var ref = str(n.ref)
		refs[ref] = true
		var row = RpgPassives.by_id(ref) if str(n.kind) == "passive" else RpgMoves.by_id(ref)
		if row == null or str(n.id) != "%s:%s" % [n.board, ref] or not RpgDefs.SCHOOLS.has(str(n.board)) or not RpgDefs.STATS.has(str(n.stat)) or RpgSkills.by_id(str(n.id)) != n:
			bad.append(n.id)
		elif str(n.kind) == "passive" and (str(row.board) != str(n.board) or int(row.tier) != int(n.tier)):
			bad.append(str(n.id) + " board or tier")
		elif str(n.kind) != "passive" and (str(row.school) != str(n.board) or int(row.tier) != int(n.tier) or bool(row.ult) != (str(n.kind) == "ult")):
			bad.append(str(n.id) + " school, tier or kind")
	ok(bad.is_empty() and RpgSkills.all().size() == 90, "every skill node points at a move or a passive of its own board and tier", bad)
	# every move can be had: a starter, a node, or a scroll
	bad = []
	var scroll_ids = ids_of(RpgMoves.scrolls())
	for m in RpgMoves.all():
		var id = str(m.id)
		var ways = (1 if RpgMoves.STARTERS.has(id) else 0) + (1 if refs.has(id) else 0) + (1 if scroll_ids.has(id) else 0)
		if ways != 1:
			bad.append("%s: %d ways" % [id, ways])
	for p in RpgPassives.all():
		if not refs.has(str(p.id)):
			bad.append("passive %s has no node" % p.id)
	for id in RpgMoves.STARTERS + RpgMoves.FIRST_BUILD + RpgSave.START_MOVES.filter(func(x): return x != ""):
		if RpgMoves.by_id(str(id)) == null or not RpgMoves.STARTERS.has(id):
			bad.append("starter " + str(id))
	ok(bad.is_empty(), "every move is a starter, a node or a scroll (one of the three), every passive has a node, the first build is starters", bad)
	# the scrolls: all 16 are handed out by the road, each once
	var given = []
	for st in RpgWorld.all_stages():
		if str(st.first.scroll) != "":
			given.append(str(st.first.scroll))
	for reg in RpgWorld.regions():
		for at in RpgDefs.STAR_CHESTS:
			var chest = RpgLoot.star_chest(str(reg.id), int(at), 1)
			if str(chest.scroll) != "":
				given.append(str(chest.scroll))
			for it in chest.items:
				if RpgItems.by_id(str(it.id)) == null:
					bad.append("star chest item " + str(it.id))
	var sorted_given = given.duplicate()
	sorted_given.sort()
	var sorted_scrolls = scroll_ids.duplicate()
	sorted_scrolls.sort()
	ok(sorted_given == sorted_scrolls and scroll_ids.size() == 16 and bad.is_empty(), "the road hands out each of the 16 scroll moves exactly once (elites and 16-star chests)", [given, bad])
	var order = []
	for reg in RpgWorld.regions():
		order.append(str(reg.stages[4].first.scroll))
		order.append(str(RpgLoot.star_chest(str(reg.id), 16, 1).scroll))
	ok(order == scroll_ids, "in the order of RpgMoves.scrolls(), region by region", order)
	# stages -> foes, items, relics
	bad = []
	var stages = RpgWorld.all_stages() + RpgWorld.echo_stages()
	for st in stages:
		for wave in st.waves:
			for en in wave:
				if RpgFoes.by_id(str(en.foe)) == null:
					bad.append("%s: foe %s" % [st.id, en.foe])
		for it in st.first.items:
			if RpgItems.by_id(str(it.id)) == null:
				bad.append("%s: item %s" % [st.id, it.id])
		if str(st.first.relic) != "" and RpgRelics.by_id(str(st.first.relic)) == null:
			bad.append("%s: relic %s" % [st.id, st.first.relic])
		if str(st.first.scroll) != "" and RpgMoves.by_id(str(st.first.scroll)) == null:
			bad.append("%s: scroll %s" % [st.id, st.first.scroll])
		for rule in st.rules:
			if not RpgBattle.RULES.has(rule):
				bad.append("%s: rule %s" % [st.id, rule])
		for obj in st.stars:
			if RpgWorld.objective_words(obj) == "":
				bad.append("%s: objective %s" % [st.id, str(obj)])
		if not RealmScenes.has(str(st.scene)):
			bad.append("%s: scene %s" % [st.id, st.scene])
	ok(bad.is_empty() and stages.size() == 160, "every stage of the road and the echoes: its foes, first rewards, rule, objectives and backdrop exist", bad)
	bad = []
	for id in RpgWorld.BOSS_RELICS + RpgWorld.REGION_ITEMS:
		if RpgRelics.by_id(str(id)) == null and RpgItems.by_id(str(id)) == null:
			bad.append(id)
	for row in RpgLoot.DROPS:
		if RpgItems.by_id(str(row[0])) == null:
			bad.append(row[0])
	for row in RpgBoosts.CHEST_ITEMS:
		if RpgItems.by_id(str(row[0])) == null:
			bad.append(row[0])
	for id in RpgItems.SHOP:
		if RpgItems.by_id(str(id)) == null or RpgItems.price(str(id)) < 25 or RpgItems.price(str(id)) > 70:
			bad.append("shop " + str(id))
	ok(bad.is_empty() and RpgItems.SHOP.size() == RpgItems.all().size(), "the boss relics, the regions' items, the drops, the chest items and the camp shop name things that exist; prices 25 to 70", bad)
	# foes -> their region, their moves, what they summon
	bad = []
	for f in RpgFoes.all():
		if not RpgDefs.REGIONS.has(str(f.region)):
			bad.append("%s: region %s" % [f.id, f.region])
		for mid in f.moves + f.pattern:
			if RpgFoes.move(str(mid)) == null:
				bad.append("%s: move %s" % [f.id, mid])
		var called = []
		for mid in f.moves:
			called.append_array(RpgFoes.move(str(mid)).foes)
		for ph in f.phases:
			called.append_array(ph.get("summon", []))
		for fid in called:
			var add = RpgFoes.by_id(str(fid))
			if add == null or bool(add.boss) or bool(add.elite) or str(add.region) != str(f.region):
				bad.append("%s summons %s" % [f.id, fid])
		for ph in range(f.phases.size() + 1):
			if not RpgFoes.all_known().has(RpgFoes.key_of(str(f.id), ph)) or RpgFoes.weak_of(str(f.id), ph).size() != 2:
				bad.append("%s: phase %d" % [f.id, ph])
	for r in RpgDefs.REGIONS:
		var cat = RpgFoes.of_region(r)
		if cat.regular.size() != 5 or RpgFoes.by_id(str(cat.elite)) == null or RpgFoes.by_id(str(cat.boss)) == null:
			bad.append("region " + r)
	ok(bad.is_empty(), "every foe: a region of the road, moves that exist, adds that are regular foes of its own region; five regulars, an elite and a boss a region", bad)
	# gear against the game's own items, companions against the game's own pets
	bad = []
	var item_ids = {}
	for it in Items.all():
		item_ids[str(it.id)] = it
	for g in RpgGear.all():
		var it = item_ids.get(str(g.id))
		if it == null or str(it.slot) != str(g.slot) or str(it.rarity) != str(g.rarity) or not TT.SLOTS.has(str(g.slot)):
			bad.append("gear " + str(g.id))
		if str(g.set) != "" and (not RpgGear.SETS.has(str(g.set)) or not RpgGear.SETS[str(g.set)].items.has(str(g.id))):
			bad.append("gear %s: set %s" % [g.id, g.set])
		if g.unique != null and not ["epic", "legendary"].has(str(g.rarity)):
			bad.append("gear %s: a unique on a %s item" % [g.id, g.rarity])
	for id in item_ids:
		if RpgGear.of(id) == null:
			bad.append("item %s has no battle stats" % id)
		elif ["epic", "legendary"].has(str(item_ids[id].rarity)) and RpgGear.of(id).unique == null:
			bad.append("item %s: epic or legendary without a unique" % id)
	var in_sets = []
	for sid in RpgGear.SETS:
		for id in RpgGear.SETS[sid].items:
			in_sets.append(id)
			if not item_ids.has(str(id)) or RpgGear.set_of(str(id)) != sid:
				bad.append("set %s: %s" % [sid, id])
		if RpgGear.SETS[sid].items.size() < 4:
			bad.append("set %s is too small for its four-piece bonus" % sid)
	for id in RpgGear.UNIQUES:
		if not item_ids.has(str(id)):
			bad.append("unique on " + str(id))
	ok(bad.is_empty() and doubles(in_sets).is_empty() and RpgGear.all().size() == Items.all().size(), "gear: every one of the game's items has battle stats on its own slot and rarity; set members and uniques are items; an item is in one set at most", [bad, doubles(in_sets)])
	bad = []
	var pet_ids = Pets.all().map(func(p): return str(p.id))
	for kit in RpgPets.all():
		if not pet_ids.has(str(kit.id)):
			bad.append(kit.id)
	for id in pet_ids:
		if RpgPets.by_id(id) == null:
			bad.append("no kit for " + id)
	ok(bad.is_empty() and pet_ids.size() == 16, "companions: a kit for every pet of the game, and for no other", bad)


# --- names, words, icons, sprites -----------------------------------------------------------

func _names_and_icons() -> void:
	var bad = []
	for icon in RpgDefs.ICONS:
		if not Icons.has_icon(icon):
			bad.append(icon)
	for table in [RpgDefs.STAT_ICONS, RpgDefs.SCHOOL_ICONS, RpgBoosts.CHEST_ICONS, RpgFoes.KIND_ICONS]:
		for k in table:
			if not Icons.has_icon(table[k]):
				bad.append("%s: %s" % [k, table[k]])
	for id in RpgDefs.STATUS:
		if not Icons.has_icon(RpgDefs.STATUS[id].icon):
			bad.append("status " + id)
	for it in RpgItems.all():
		if not Icons.has_icon(it.icon):
			bad.append("item %s: %s" % [it.id, it.icon])
	for r in RpgRelics.all():
		if not Icons.has_icon(r.icon):
			bad.append("relic %s: %s" % [r.id, r.icon])
	for mv in RpgFoes.moves():
		if not Icons.has_icon(mv.icon):
			bad.append("foe move %s: %s" % [mv.id, mv.icon])
	ok(bad.is_empty(), "every icon a catalog names is one the game draws", bad)
	bad = []
	for f in RpgFoes.all():
		if not FoeSprites.has(str(f.id)):
			bad.append(f.id)
	for m in Bounty.MONSTERS:
		if not str(m.id).begins_with("wk_") or not FoeSprites.has(str(m.id)):
			bad.append(m.id)
	for sc in RpgDefs.REGIONS + ["hunt", "rival", "spire"]:
		if not RealmScenes.has(sc):
			bad.append("scene " + sc)
	ok(bad.is_empty(), "every foe and every bounty monster has a sprite, every region and side stage a backdrop", bad)
	# ids are made from names; names and words are there
	bad = []
	for m in RpgMoves.all():
		if RpgDefs.id_of(str(m.name)) != str(m.id) or str(m.text) == "" and RpgMoves.words(m).is_empty():
			bad.append("move " + str(m.id))
	for p in RpgPassives.all():
		if RpgDefs.id_of(str(p.name)) != str(p.id) or str(p.text) == "":
			bad.append("passive " + str(p.id))
	for f in RpgFoes.all():
		if RpgDefs.id_of(str(f.name)) != str(f.id) or str(f.text) == "":
			bad.append("foe " + str(f.id))
	for it in RpgItems.all():
		if RpgDefs.id_of(str(it.name)) != str(it.id) or str(it.text) == "":
			bad.append("item " + str(it.id))
	for reg in RpgWorld.regions():
		if RpgDefs.id_of(str(reg.id)) != str(reg.id):
			bad.append("region " + str(reg.id))
	ok(bad.is_empty(), "ids follow the names (plan 11.0), and everything has words", bad)
	# the words on screen hold no emoji and nothing a non-gamer would not read
	bad = []
	var texts = []
	for st in RpgWorld.all_stages() + RpgWorld.echo_stages():
		texts.append(str(st.name))
		texts.append(str(st.text))
	for reg in RpgWorld.regions():
		texts.append(str(reg.blurb))
		texts.append(str(reg.teaches))
	for id in RpgWorld.RULES:
		texts.append(str(RpgWorld.RULES[id].name) + " " + str(RpgWorld.RULES[id].text))
	for t in texts:
		for i in range(t.length()):
			if t.unicode_at(i) > 0x24F:
				bad.append(t)
				break
	ok(bad.is_empty(), "the world's words are plain letters: no emoji, no symbols", bad)


# --- ids that must not clash ----------------------------------------------------------------------

func _clashes() -> void:
	ok(doubles(ids_of(RpgMoves.all())).is_empty() and doubles(ids_of(RpgPassives.all())).is_empty() and doubles(ids_of(RpgFoes.all())).is_empty()
		and doubles(ids_of(RpgFoes.moves())).is_empty() and doubles(ids_of(RpgRelics.all())).is_empty() and doubles(ids_of(RpgItems.all())).is_empty()
		and doubles(ids_of(RpgPets.all())).is_empty() and doubles(ids_of(RpgSkills.all())).is_empty() and doubles(ids_of(RpgGear.all())).is_empty(), "no catalog has an id twice")
	# a node is "<board>:<ref>": a move and a passive of one id would be one node
	var moves = ids_of(RpgMoves.all())
	var both = ids_of(RpgPassives.all()).filter(func(id): return moves.has(id))
	ok(both.is_empty(), "no passive shares an id with a move (they would be the same skill node)", both)
	# a foe unit's "foe" id picks its sprite: a foe, a pet and a bounty monster must not share one
	var foes = ids_of(RpgFoes.all())
	var clash = ids_of(RpgPets.all()).filter(func(id): return foes.has(id))
	clash.append_array(foes.filter(func(id): return str(id).begins_with("wk_")))
	ok(clash.is_empty(), "no foe has a companion's id or a bounty monster's \"wk_\" id", clash)
	# rpg.items holds belt items; gear, relics and belt items are handed out by id in one reward
	var gear = ids_of(RpgGear.all())
	var mixed = ids_of(RpgItems.all()).filter(func(id): return gear.has(id) or RpgRelics.by_id(id) != null)
	mixed.append_array(ids_of(RpgRelics.all()).filter(func(id): return gear.has(id)))
	ok(mixed.is_empty(), "no belt item, relic and piece of gear share an id", mixed)
	# a gear unique and a set bonus are shown as named passives next to the board passives
	var named = ids_of(RpgPassives.all())
	var uniq = []
	for id in RpgGear.UNIQUES:
		uniq.append(str(RpgGear.UNIQUES[id].get("id", "")))
	# (a unique may share an id with a MOVE, and a foe move with a hero move: those are looked up in
	# tables of their own and never side by side. Today: the uniques "negative_split" and "rally", the foe move "grind".)
	ok(doubles(uniq).is_empty() and uniq.filter(func(id): return id == "" or named.has(id)).is_empty(), "every gear unique has an id of its own, and not a board passive's", [doubles(uniq), uniq.filter(func(id): return id == "" or named.has(id))])
	# stage ids, and the marks that share the save's "caches" with them
	var stage_ids = ids_of(RpgWorld.all_stages() + RpgWorld.echo_stages())
	ok(doubles(stage_ids).is_empty() and stage_ids.all(func(id): return not str(id).begins_with("hunt:") and not str(id).begins_with("spire:") and not str(id).begins_with("rival:")), "stage ids are all different, and none looks like a hunt, a rival or a Spire floor")
	ok(RpgWorld.RULES.keys() == RpgBattle.RULES.keys(), "the world's rules are the engine's rules")
	var regions = RpgDefs.REGIONS
	ok(not regions.has("hunt") and not regions.has("spire") and not regions.has("rival") and RpgDefs.REGION_NAMES.size() == regions.size(), "no region is called like a side stage's backdrop")


# --- what is made on the fly ------------------------------------------------------------------------

func _made_on_the_fly() -> void:
	# hunts: forty days at five points of the road
	var bad = []
	var rules = {}
	for step in range(5):
		var rpg = RpgSave.empty()
		var upto = [0, 10, 30, 55, 80][step]
		var all = RpgWorld.all_stages()
		for i in range(upto):
			if str(all[i].kind) == "cache":
				rpg.caches[all[i].id] = true
			else:
				rpg.stages[all[i].id] = {"stars": [true, false, false], "wins": 1, "best": 9}
		for d in range(40):
			var date = Dates.add_days("2031-01-01", d)
			var h = RpgWorld.hunt(date, rpg, [])
			rules[str(h.rule)] = true
			var fine = h.waves.size() == 1 and h.waves[0].size() == 3 and h.weak.size() == 2 and RpgDefs.ATTACK_SCHOOLS.has(h.weak[0]) and RpgDefs.ATTACK_SCHOOLS.has(h.weak[1]) and h.weak[0] != h.weak[1] \
				and RpgBattle.RULES.has(str(h.rule)) and h.prizes.size() == 3 and float(h.n) == RpgWorld.best_n(rpg) + 2.0 and float(h.rec) > 0.0
			var roles = {}
			for en in h.waves[0]:
				var row = RpgFoes.by_id(str(en.foe))
				if row == null or bool(row.boss) or bool(row.elite) or (roles.has(str(row.role)) and ["healer", "bomb", "tank"].has(str(row.role))):
					fine = false
				else:
					roles[str(row.role)] = true
					var region_no = RpgDefs.REGIONS.find(str(row.region)) + 1
					if region_no > mini(8, int(floor((RpgWorld.best_n(rpg) + 1.0) / 10.0)) + 1):
						fine = false
			for p in h.prizes:
				if RpgSave._option_pack(p) == null:
					fine = false
			if not fine:
				bad.append("%s after %d" % [date, upto])
	ok(bad.is_empty() and rules.size() == 6, "200 hunts: three different regular foes of the regions reached, two weak schools, a rule, three real prizes; every rule comes up", bad.slice(0, 6))
	# the Spire: 200 floors
	bad = []
	for f in range(1, 201):
		var sp = RpgWorld.spire(f)
		var fine = sp.waves.size() == 1 and sp.waves[0].size() >= 1 and sp.waves[0].size() <= 3 and float(sp.rec) > 0.0 and float(sp.n) >= 12.0
		var big = 0
		for en in sp.waves[0]:
			var row = RpgFoes.by_id(str(en.foe))
			if row == null:
				fine = false
			elif bool(row.boss) or bool(row.elite):
				big += 1
		if big > 1 or (f % 5 != 0 and big != 0) or (f % 5 == 0 and big != 1) or (f > 1 and float(sp.n) <= RpgWorld.spire_n(f - 1)):
			fine = false
		if not fine:
			bad.append(f)
	ok(bad.is_empty(), "200 Spire floors: foes that exist, one big one on every fifth floor and never else, harder floor by floor", bad)
	# rivals: every monster, every weak part
	bad = []
	for m in Bounty.MONSTERS:
		for part in Bounty.MUSCLE_GROUPS:
			var rv = RpgWorld.rival({"weekly": {"current": {"week": "2031-01-06", "monster": m.id, "weakPart": part}}}, RpgSave.empty())
			if rv == null or RpgBattle.check_foe(rv.waves[0][0].row) != "" or not RpgWorld.PART_SCHOOLS.has(part) or not RpgWorld.PART_SCHOOLS[part].all(func(sc): return rv.weak.has(sc)):
				bad.append("%s %s" % [m.id, part])
	ok(bad.is_empty(), "every bounty monster with every weak muscle group makes a well formed rival, weak to that group's schools", bad)
	# rune rolls
	bad = []
	var kinds = {}
	var rarities = {}
	var holder = RpgSave.empty()
	for i in range(600):
		var rn = RpgLoot.rune(float(i % 130), holder, "sweep%d" % i, i % 3)
		kinds[str(rn.k)] = true
		rarities[str(rn.rarity)] = true
		if not str(rn.id).begins_with("rn") or not RpgGear.LINE_KINDS.has(str(rn.k)) or float(rn.v) <= 0.0 or not RpgDefs.RARITIES.has(str(rn.rarity)) or RpgBattle.check_passive(RpgGear.line_fx(rn)) != "" or RpgGear.rune_words(rn) == "":
			bad.append(rn)
		if i % 7 == 0:
			holder.runes.append(rn)
	ok(bad.is_empty() and kinds.size() >= 8 and rarities.size() == 5 and doubles(ids_of(holder.runes)).is_empty(), "600 rune rolls: a valid line each, every rarity comes up, no id twice in a save", [bad.slice(0, 3), kinds.size(), rarities.keys()])
	# caches and star chests of every region, drops at every depth
	bad = []
	for reg in RpgWorld.regions():
		for sid in ["r%ds6" % int(reg.r), "e%ds6" % int(reg.r)]:
			var opts = RpgLoot.cache(sid, RpgSave.empty(), 3)
			if opts.size() != 3 or opts.any(func(o): return RpgSave._option_pack(o) == null):
				bad.append(sid)
		for at in RpgDefs.STAR_CHESTS:
			var chest = RpgLoot.star_chest(str(reg.id), int(at), 3, RpgSave.empty())
			if chest.is_empty() or int(chest.ore) <= 0 or (str(chest.relic) != "" and RpgRelics.by_id(str(chest.relic)) == null) or (str(chest.scroll) != "" and RpgMoves.by_id(str(chest.scroll)) == null):
				bad.append("%s:%d" % [reg.id, at])
	for n in range(0, 120, 7):
		for s in range(12):
			if RpgItems.by_id(str(RpgLoot.item_drop(s, float(n)).id)) == null:
				bad.append("drop at %d" % n)
	ok(bad.is_empty(), "every cache has three real finds, every star chest real contents, every drop is a belt item", bad)
	# a full walk: win every stage once, take every cache, open every chest; the save holds only real things
	var rpg = RpgSave.empty()
	var why = []
	var sum = {"win": true, "turns": 3, "breaks": 1, "items": 0, "guards": 0, "schools": ["push", "pull", "legs"], "worst_share": 0.1, "hp_share": 0.9, "learned": {}, "used": {}}
	for st in RpgWorld.all_stages():
		var res
		if str(st.kind) == "cache":
			res = RpgSave.take_cache(rpg, str(st.id), RpgLoot.cache(str(st.id), rpg, 1)[0])
		else:
			res = RpgSave.finish(rpg, {"kind": "stage", "id": st.id}, st, RpgLoot.rewards(st, sum, rpg, RpgSave.level_of(rpg), [], int(st.n)), sum, "2031-01-01")
		if not bool(res.ok):
			why.append("%s: %s" % [st.id, res.why])
		rpg = res.rpg
	for reg in RpgWorld.regions():
		for at in RpgDefs.STAR_CHESTS:
			var res = RpgSave.open_star_chest(rpg, str(reg.id), int(at), RpgLoot.star_chest(str(reg.id), int(at), 1, rpg))
			if not bool(res.ok):
				why.append("%s:%d: %s" % [reg.id, at, res.why])
			rpg = res.rpg
	var real = rpg.relics.keys().all(func(id): return RpgRelics.by_id(id) != null) and rpg.scrolls.keys().all(func(id): return scroll_known(id)) and rpg.items.keys().all(func(id): return RpgItems.by_id(id) != null)
	ok(why.is_empty() and real and rpg.scrolls.size() == 16 and rpg.relics.size() >= 20 and doubles(ids_of(rpg.runes)).is_empty() and rpg.runes.size() >= 16 and RpgWorld.echoes_open(rpg),
		"the whole road walked through the save: nothing refused, all 16 scrolls, 20 relics or more, runes with ids of their own", [why.slice(0, 4), rpg.scrolls.size(), rpg.relics.size(), rpg.runes.size()])
	var pts = RpgSkills.points(rpg, 0)
	ok(RpgSkills.known_moves(rpg).size() == RpgMoves.STARTERS.size() + 16 and int(pts.from.bosses) == 16 and int(pts.from.stars) == int(floor(72 * 3 / 12.0)) and same_keys(rpg), "that save knows every scroll move and is paid its skill points for 8 bosses and 216 stars", pts)


func scroll_known(id: String) -> bool:
	var m = RpgMoves.by_id(id)
	return m != null and int(m.tier) == RpgMoves.TIER_SCROLL


## A save written by the transitions has the keys of an empty one, and parse keeps it.
func same_keys(rpg: Dictionary) -> bool:
	return rpg.keys() == RpgSave.empty().keys() and JSON.stringify(RpgSave.parse(rpg), "", true) == JSON.stringify(rpg, "", true)
