extends SceneTree
## Unit test for what a Realm hero wears and carries (RPG_PLAN.md 7):
## game/rpg/rpg_gear.gd (RpgGear: the 124 items' battle stats, uniques, sets,
## runes), rpg_relics.gd (RpgRelics), rpg_items.gd (RpgItems: the belt and the
## camp shop) and rpg_pets.gd (RpgPets: the 16 companions). Every effect is
## held to the engine's validators, the budget to RpgDefs' reference hero, and
## fights with full kits are played to their end through RpgBattle.
## Made-up heroes and foes only; nothing here reads a save.
##   godot --headless --path . --script res://tests/rpg_gear_test.gd
## Prints RPG GEAR: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a: float, b: float, tol: float = 0.012) -> bool:
	return absf(a - b) <= tol * maxf(1.0, absf(b))


func _init() -> void:
	_table()
	_uniques()
	_sets()
	_budget()
	_plus()
	_kit_fx()
	_runes()
	_relics()
	_items()
	_pets()
	_fights()
	print("RPG GEAR: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# --- helpers -----------------------------------------------------------------

func line_of(it: Dictionary, k: String) -> float:
	for line in it.lines:
		if str(line.k) == k:
			return float(line.v)
	return 0.0


## The kit that gives the most of `score` (a Callable on an item at +0), from
## the items of those rarities; a slot with none of them stays empty.
func best_kit(rarities: Array, score: Callable) -> Dictionary:
	var gear = {}
	var best = {}
	for it in RpgGear.all():
		if not rarities.has(it.rarity):
			continue
		var sc = float(score.call(it))
		if not gear.has(it.slot) or sc > float(best[it.slot]):
			gear[it.slot] = it.id
			best[it.slot] = sc
	return gear


func all_plus(gear: Dictionary, n: int) -> Dictionary:
	var plus = {}
	for slot in gear:
		plus[gear[slot]] = n
	return plus


## What a kit gives one school: its attack for it and for all.
func atk_of(gear: Dictionary, n: int, school: String) -> float:
	var agg = RpgBattle.aggregate(RpgGear.fx(gear, all_plus(gear, n)))
	return float(agg.get("atk:" + school, 0.0)) + float(agg.get("atk:all", 0.0))


func armor_of(gear: Dictionary, n: int) -> float:
	return float(RpgBattle.aggregate(RpgGear.fx(gear, all_plus(gear, n))).get("armor", 0.0))


func bad_passives(fx: Array, tag: String) -> Array:
	var bad = []
	for e in fx:
		var why = RpgBattle.check_passive(e)
		if why != "":
			bad.append(tag + ": " + why)
	return bad


func sentence(text) -> bool:
	return text is String and text.length() > 8 and text.ends_with(".") and text.left(1) == text.left(1).to_upper()


# --- the table ---------------------------------------------------------------

func _table() -> void:
	var items = Items.all()
	var missing = []
	var off = []
	for it in items:
		var row = RpgGear.of(str(it.id))
		if row == null:
			missing.append(it.id)
		elif str(row.slot) != str(it.slot) or str(row.rarity) != str(it.rarity):
			off.append([it.id, row.slot, row.rarity])
	ok(items.size() == 124 and missing.is_empty(), "all 124 items of the game have a row", missing)
	ok(off.is_empty(), "a row's slot and rarity are the item's own", off)
	ok(RpgGear.ids().size() == items.size() and RpgGear.all().size() == 124, "and there is no row for an item the game does not have", RpgGear.ids().size())

	# the table does not hang on Items.all()
	Items.restrict_to(["tee_grey", "shorts_navy"])
	var crown = RpgGear.of("iron_crown")
	var kit = RpgGear.fx({"head": "iron_crown", "back": "barbell_back"})
	Items.restrict_to(null)
	ok(crown != null and crown.rarity == "legendary" and crown.unique != null and not kit.is_empty() and Items.all().size() == 124,
		"the table still answers when the game's catalog is restricted", crown)

	var bad = []
	var thin = []
	for row in RpgGear.all():
		var seen = []
		for line in row.lines:
			if not RpgGear.LINE_KINDS.has(line.k) or seen.has(line.k) or float(line.v) <= 0.0:
				bad.append([row.id, line])
			seen.append(line.k)
			if RpgBattle.check_passive(RpgGear.line_fx(line)) != "" or RpgGear.line_words(line) == "":
				bad.append([row.id, line, RpgBattle.check_passive(RpgGear.line_fx(line))])
		var rare_up = RpgDefs.RARITIES.find(str(row.rarity)) >= 2
		if row.lines.is_empty() or (rare_up and row.lines.size() < 2):
			thin.append(row.id)
		if not TT.SLOTS.has(row.slot) or not RpgDefs.RARITIES.has(row.rarity) or row.id != RpgGear.by_id(row.id).id:
			bad.append(row.id)
	ok(bad.is_empty(), "every line is one of the plan's kinds, once an item, above 0, and an effect the engine knows", bad)
	ok(thin.is_empty(), "every item has a line; rare and up have a second one", thin)
	ok(RpgGear.of("nothing") == null and RpgGear.by_id("") == null and RpgGear.plus_cost("nothing", 0) == 0, "an id nobody knows: null")

	# main line by slot (7.1)
	var heads = RpgGear.all().filter(func(r): return r.slot == "head" and line_of(r, "armor") > 0.0).size()
	var feet = RpgGear.all().filter(func(r): return r.slot == "feet" and line_of(r, "spd") > 0.0).size()
	var bodies = RpgGear.all().filter(func(r): return r.slot == "body" and line_of(r, "hp") + line_of(r, "armor") > 0.0).size()
	ok(heads >= 15 and feet == 14 and bodies == 16, "heads are armor, feet are speed, bodies are HP and armor", [heads, feet, bodies])
	var weapon = RpgGear.of("shop_greatsword")
	var glove = RpgGear.of("shop_boxing_gloves")
	ok(line_of(weapon, "atk_push") > line_of(glove, "atk_push") and line_of(RpgGear.of("shop_wizard_hat"), "atk_mind") > 0.0
		and line_of(RpgGear.of("read_glasses"), "atk_mind") > 0.0 and line_of(RpgGear.of("crimp_gauntlets"), "atk_grip") > 0.0
		and line_of(RpgGear.of("carbon_racers"), "atk_speed") > 0.0, "the back is the weapon; schools follow the theme")
	var lege = RpgGear.of("iron_crown")
	var epic = RpgGear.of("wallbreaker_visor")
	ok(line_of(lege, "armor") > line_of(epic, "armor") and line_of(epic, "armor") > line_of(RpgGear.of("aero_helmet"), "armor")
		and line_of(RpgGear.of("aero_helmet"), "armor") > line_of(RpgGear.of("beanie_sunset"), "armor")
		and line_of(RpgGear.of("beanie_sunset"), "armor") > line_of(RpgGear.of("bandana_red"), "armor"), "a rarer item has the bigger line")
	for slot in TT.SLOTS:
		if RpgGear.slot_main(slot) == "":
			bad.append(slot)
	ok(bad.is_empty() and RpgGear.slot_main("nope") == "", "every slot says what it is for")
	ok(RpgGear.line_words({"k": "atk_push", "v": 6.0}) == "Push attack +6" and RpgGear.line_words({"k": "spd", "v": 0.06}) == "Speed +6%"
		and RpgGear.line_words({"k": "crit", "v": 0.025}) == "Crit chance +2.5%" and RpgGear.line_words({"k": "en_max", "v": 2}) == "Max energy +2"
		and RpgGear.line_words({"k": "gauge_rate", "v": 0.05}) == "The gauge fills 5% faster" and RpgGear.line_words({"k": "hp", "v": 12.0}) == "Max HP +12"
		and RpgGear.line_words({"k": "nope", "v": 1}) == "", "a line in words", RpgGear.line_words({"k": "crit", "v": 0.025}))


# --- uniques -----------------------------------------------------------------

func _uniques() -> void:
	var with = []
	var wrong = []
	var bad = []
	var names = {}
	var ids = {}
	var sigs = {}
	for row in RpgGear.all():
		var high = row.rarity == "epic" or row.rarity == "legendary"
		if (row.unique != null) != high:
			wrong.append(row.id)
		if row.unique == null:
			continue
		var u = row.unique
		with.append(row.id)
		if str(u.id) != RpgDefs.id_of(str(u.name)) or not sentence(u.text) or not (u.fx is Array) or u.fx.is_empty():
			bad.append(row.id)
		bad.append_array(bad_passives(u.fx, str(row.id)))
		names[u.name] = true
		ids[u.id] = true
		sigs[JSON.stringify(u.fx)] = true
		# none is simply "+damage"
		if u.fx.size() == 1 and ["school_pct", "stat_pct", "stat_dmg", "atk"].has(str(u.fx[0].p)):
			bad.append(str(row.id) + " is only more damage")
	ok(with.size() == 30 and wrong.is_empty(), "exactly the 30 epic and legendary items have a unique", [with.size(), wrong])
	ok(bad.is_empty(), "every unique has a name, its id, words and effects the engine knows", bad)
	ok(names.size() == 30 and ids.size() == 30 and sigs.size() == 30, "and they are all different", [names.size(), ids.size(), sigs.size()])
	ok(RpgGear.UNIQUES.size() == 30 and RpgGear.UNIQUES.keys().all(func(id): return RpgGear.of(id) != null), "no unique without its item")


# --- sets --------------------------------------------------------------------

func _sets() -> void:
	var bad = []
	var owner = {}
	var twice = []
	for sid in RpgGear.SETS:
		var s = RpgGear.SETS[sid]
		var slots = {}
		for id in s.items:
			var row = RpgGear.of(str(id))
			if row == null:
				bad.append([sid, id])
				continue
			slots[row.slot] = true
			if owner.has(id):
				twice.append(id)
			owner[id] = sid
			if RpgGear.set_of(id) != sid or row["set"] != sid:
				bad.append([sid, id, "set_of"])
		if s.items.size() < 6 or slots.size() < 4:
			bad.append([sid, s.items.size(), slots.size()])
		for part in ["two", "four"]:
			if not sentence(s[part].text) or s[part].fx.is_empty():
				bad.append([sid, part])
			bad.append_array(bad_passives(s[part].fx, sid + " " + part))
		if str(s.name) == "" or not RpgGear.SET_ORDER.has(sid):
			bad.append(sid)
	ok(RpgGear.SETS.size() == 7 and RpgGear.SET_ORDER.size() == 7 and RpgGear.SETS.has_all(["iron", "crag", "road", "wheel", "hunter", "scholar", "showtime"]),
		"the seven sets", RpgGear.SETS.keys())
	ok(bad.is_empty(), "a set has 6 members or more over 4 slots or more, known items, words and effects the engine knows", bad)
	ok(twice.is_empty(), "an item is in one set at most", twice)
	ok(RpgGear.set_of("tee_grey") == "" and RpgGear.set_of("nothing") == "" and RpgGear.of("tee_grey")["set"] == "", "an item outside every set says so")
	# by theme
	var themed = true
	for it in Items.all():
		var want = {"lift": "iron", "climb": "crag", "run": "road", "ride": "wheel"}.get(str(it.get("discipline", "")), "")
		if want != "" and RpgGear.set_of(str(it.id)) != want:
			themed = false
		if str(it.id).begins_with("bounty_") and RpgGear.set_of(str(it.id)) != "hunter":
			themed = false
		if str(it.id).begins_with("read_") and RpgGear.set_of(str(it.id)) != "scholar":
			themed = false
	ok(themed and RpgGear.set_of("shop_wizard_hat") == "scholar" and RpgGear.set_of("shop_party_hat") == "showtime",
		"lifting gear is Iron, climbing Crag, running Road, cycling Wheel, bounty gear Hunter, reading Scholar")

	var gear = {"head": "bandana_red", "hands": "gym_gloves", "body": "stringer_black"}
	ok(RpgGear.set_count(gear, "iron") == 3 and RpgGear.set_count(gear, "crag") == 0 and RpgGear.set_count(gear, "iron", {"gym_gloves": 1}) == 1,
		"set_count: the pieces worn (and owned)")
	var fx = RpgGear.fx(gear)
	ok(fx.has(RpgGear.SETS.iron.two.fx[0]) and not fx.has(RpgGear.SETS.iron.four.fx[0]), "two pieces: the first bonus", fx)
	gear["legs"] = "knee_sleeves"
	fx = RpgGear.fx(gear)
	var in_force = RpgGear.sets_in_force(gear)
	ok(fx.has(RpgGear.SETS.iron.two.fx[0]) and fx.has(RpgGear.SETS.iron.four.fx[0]) and in_force.size() == 1 and in_force[0].id == "iron"
		and int(in_force[0].count) == 4 and in_force[0].four, "four pieces: both", in_force)
	gear["feet"] = "trail_shoes"
	gear["accessory"] = "race_bib"
	ok(RpgGear.sets_in_force(gear).size() == 2 and RpgGear.fx(gear).has(RpgGear.SETS.road.two.fx[0]), "two sets at once")


# --- the budget --------------------------------------------------------------

func _budget() -> void:
	# nine commons that all favour one school: the slots' main lines
	var u = RpgGear.UNIT
	var back = float(RpgGear.SLOT_MULT.back)
	var aura = float(RpgGear.SLOT_MULT.aura)
	var atk = float(u.atk_push) * (1.0 + back) + float(u.atk_all) * aura
	var armor = 2.0 * float(u.armor)
	var hp = 2.0 * float(u.hp)
	ok(atk >= 3.4 and atk <= 6.0 and armor >= 2.0 and armor <= 3.6 and hp >= 14.0 and hp <= 26.0,
		"nine commons at +0: attack 4 to 5, armor 2 to 3, HP about 20", [atk, armor, hp])
	ok(near(atk, RpgDefs.ref_w(1.0), 0.35) and near(armor, RpgDefs.ref_armor(1.0), 0.35), "which is the reference of tier 1", [atk, RpgDefs.ref_w(1.0)])

	# the same kit as rares at +t against the reference of tier t
	var out = []
	for t in range(3, 9):
		var m = float(RpgDefs.RARITY_MULT.rare) * RpgDefs.plus_mult(t)
		if not near(atk * m, RpgDefs.ref_w(float(t)), 0.35) or not near(armor * m, RpgDefs.ref_armor(float(t)), 0.35):
			out.append([t, atk * m, RpgDefs.ref_w(float(t)), armor * m, RpgDefs.ref_armor(float(t))])
	ok(out.is_empty(), "a kit of rares at +t: the reference of tier t within 35% (tiers 3 to 8)", out)

	# the real items: the best kit of rares for each school, second lines and all
	out = []
	var seen = []
	for school in RpgDefs.ATTACK_SCHOOLS:
		var k = "atk_" + school
		var gear = best_kit(["rare"], func(it): return line_of(it, k) + line_of(it, "atk_all"))
		for t in [4, 6, 8]:
			var have = atk_of(gear, t, school)
			seen.append("%s+%d %.1f/%.1f" % [school, t, have, RpgDefs.ref_w(float(t))])
			if have < 0.65 * RpgDefs.ref_w(float(t)) or have > 1.5 * RpgDefs.ref_w(float(t)):
				out.append([school, t, have, RpgDefs.ref_w(float(t))])
		if gear.size() != 9:
			out.append([school, gear.size()])
	ok(out.is_empty(), "the best real kit of rares for each school at +t: 65% to 150% of the reference", [out, seen])
	var tank = best_kit(["rare"], func(it): return line_of(it, "armor"))
	out = []
	for t in [4, 6, 8]:
		var have = armor_of(tank, t)
		if have < 0.65 * RpgDefs.ref_armor(float(t)) or have > 1.6 * RpgDefs.ref_armor(float(t)):
			out.append([t, have, RpgDefs.ref_armor(float(t))])
	ok(out.is_empty(), "and the most armor a kit of rares gives", out)

	# what a new player really wears: commons and uncommons at +0
	out = []
	for school in RpgDefs.ATTACK_SCHOOLS:
		var k = "atk_" + school
		var gear = best_kit(["common", "uncommon"], func(it): return line_of(it, k) + line_of(it, "atk_all"))
		var have = atk_of(gear, 0, school)
		if have < 1.0 or have > 1.35 * RpgDefs.ref_w(1.0):
			out.append([school, have])
	ok(out.is_empty(), "commons and uncommons at +0: something for every school, never past tier 1's reference by much", out)

	# the end of the road: the best there is at +10
	out = []
	for school in RpgDefs.ATTACK_SCHOOLS:
		var k = "atk_" + school
		var gear = best_kit(["rare", "epic", "legendary"], func(it): return (line_of(it, k) + line_of(it, "atk_all")) * 100.0 + float(RpgDefs.RARITIES.find(it.rarity)))
		var have = atk_of(gear, 10, school)
		if have < RpgDefs.ref_w(8.0) or have > 2.0 * RpgDefs.ref_w(8.0):
			out.append([school, have, RpgDefs.ref_w(8.0)])
	ok(out.is_empty(), "the best kit at +10 beats tier 8's reference, by less than double", out)
	var top = best_kit(["legendary", "epic"], func(it): return float(RpgDefs.RARITIES.find(it.rarity)))
	var agg = RpgBattle.aggregate(RpgGear.fx(top, all_plus(top, 10)))
	ok(float(agg.get("crit_add", 0.0)) <= RpgDefs.CRIT_CAP and float(agg.get("spd_pct", 0.0)) <= 0.6 and float(agg.get("gauge_rate", 0.0)) <= 0.8,
		"a legendary kit at +10 breaks no cap by itself", agg)


# --- upgrades ----------------------------------------------------------------

func _plus() -> void:
	var out = []
	for row in RpgGear.all():
		var top = RpgGear.of(row.id, 10)
		var mid = RpgGear.of(row.id, 4)
		for i in range(row.lines.size()):
			var k = str(row.lines[i].k)
			var v0 = float(row.lines[i].v)
			var v10 = float(top.lines[i].v)
			if k == "en_max":
				if int(v0) != 1 or int(v10) != 3 or int(mid.lines[i].v) != 1 or int(RpgGear.of(row.id, 5).lines[i].v) != 2:
					out.append([row.id, k, v0, v10])
			elif RpgGear.PCT_KINDS.has(k):
				# a fraction grows to three times and stops there (+4)
				if not near(v10, v0 * RpgDefs.PLUS_PCT_CAP, 0.06) or v10 != float(mid.lines[i].v) or v10 <= v0:
					out.append([row.id, k, v0, v10])
			elif absf(v10 - v0 * RpgDefs.plus_mult(10)) > (3.5 if k == "hp" else 0.35) or float(mid.lines[i].v) <= v0 or v10 <= float(mid.lines[i].v):
				out.append([row.id, k, v0, v10])
	ok(out.is_empty(), "+10 is six times a line, three times a fraction (reached at +4); max energy goes 1, 2, 3", out)
	ok(RpgGear.of("iron_crown", 99).lines == RpgGear.of("iron_crown", 10).lines and RpgGear.of("iron_crown", -3).lines == RpgGear.of("iron_crown", 0).lines,
		"a plus outside 0..10 is brought back in")
	ok(RpgGear.plus_cost("tee_grey", 0) == RpgDefs.plus_cost("common", 0) and RpgGear.plus_cost("iron_crown", 3) == RpgDefs.plus_cost("legendary", 3)
		and RpgGear.plus_cost("iron_crown", 10) == 0 and RpgGear.plus_cost("iron_crown", 3) > RpgGear.plus_cost("aero_helmet", 3),
		"plus_cost: RpgDefs' price for the item's rarity, nothing past +10")


# --- a kit as effects --------------------------------------------------------

func _kit_fx() -> void:
	var gear = {"head": "iron_crown", "hands": "gym_gloves", "back": "shop_greatsword", "feet": "trainers_worn"}
	var fx = RpgGear.fx(gear)
	var agg = RpgBattle.aggregate(fx)
	var want = line_of(RpgGear.of("iron_crown"), "atk_push") + line_of(RpgGear.of("gym_gloves"), "atk_push") + line_of(RpgGear.of("shop_greatsword"), "atk_push")
	ok(near(float(agg.get("atk:push", 0.0)), want) and near(float(agg.get("armor", 0.0)), line_of(RpgGear.of("iron_crown"), "armor"))
		and near(float(agg.get("spd_pct", 0.0)), line_of(RpgGear.of("trainers_worn"), "spd")), "fx: the lines of every worn item, added up", agg)
	ok(fx.has(RpgGear.UNIQUES.iron_crown.fx[0]) and bad_passives(fx, "kit").is_empty(), "and the unique of what is worn", fx)
	var kinds = fx.filter(func(e): return e.p == "atk" and e.school == "push")
	ok(kinds.size() == 1, "one effect a line kind", kinds)

	# skipped: unknown, in the wrong slot, not owned
	var odd = {"head": "iron_crown", "hands": "no_such_item", "back": "gym_gloves", "face": null, "feet": 7, "zzz": "tee_grey"}
	ok(RpgGear.worn(odd) == ["iron_crown"] and RpgGear.fx(odd) == RpgGear.fx({"head": "iron_crown"}), "an unknown id and an item in the wrong slot are skipped", RpgGear.worn(odd))
	ok(RpgGear.worn(gear, {"gym_gloves": {"at": "x"}, "trainers_worn": {}}) == ["gym_gloves", "trainers_worn"]
		and RpgGear.fx(gear, {}, [], {}, {}).is_empty() and RpgGear.fx({}).is_empty(), "with owned_items: only what is owned", RpgGear.worn(gear, {"gym_gloves": 1}))
	ok(RpgGear.worn({"aura": "titan_aura", "head": "iron_crown", "body": "tee_grey"}) == ["iron_crown", "tee_grey", "titan_aura"], "worn: in the game's slot order")

	# upgrades and runes
	var up = RpgBattle.aggregate(RpgGear.fx(gear, {"gym_gloves": 2, "nothing": 5, "iron_crown": "x"}))
	ok(near(float(up.get("atk:push", 0.0)), want + line_of(RpgGear.of("gym_gloves", 2), "atk_push") - line_of(RpgGear.of("gym_gloves"), "atk_push")),
		"plus: the item's own, others untouched", up)
	var runes = [{"id": "rn1", "k": "atk_push", "v": 1.5, "rarity": "rare"}, {"id": "rn2", "k": "crit", "v": 0.01, "rarity": "common"},
		{"id": "rn3", "k": "nope", "v": 3.0, "rarity": "common"}, {"id": "rn4", "k": "hp", "v": 9.0, "rarity": "epic"}, "junk"]
	var socket = {"gym_gloves": "rn1", "iron_crown": "rn2", "trainers_worn": "rn3", "shop_greatsword": "gone", "tee_grey": "rn4"}
	var with = RpgBattle.aggregate(RpgGear.fx(gear, {}, runes, socket))
	ok(near(float(with.get("atk:push", 0.0)), want + 1.5) and near(float(with.get("crit_add", 0.0)), 0.01) and not with.has("hp"),
		"runes: the line of each rune in a worn item's socket; an unknown rune, kind or item counts for nothing", with)
	socket = {"gym_gloves": "rn1", "iron_crown": "rn1"}
	with = RpgBattle.aggregate(RpgGear.fx(gear, {}, runes, socket))
	ok(near(float(with.get("atk:push", 0.0)), want + 1.5), "a rune counts once", with)
	var sums = RpgGear.totals(gear, {}, runes, {"gym_gloves": "rn1"})
	ok(near(float(sums.get("atk_push", 0.0)), want + 1.5) and sums.has("armor") and sums.has("spd"), "totals: the sums by line kind", sums)

	# every item's effects, alone, are ones the engine knows
	var bad = []
	for row in RpgGear.all():
		bad.append_array(bad_passives(RpgGear.fx({row.slot: row.id}, {row.id: 10}), str(row.id)))
	ok(bad.is_empty(), "every item alone, at +10, gives only effects the engine knows", bad)

	# RpgHero puts a kit into the hero's numbers
	var rpg = RpgSave.empty()
	rpg.builds[0]["gear"] = gear.duplicate()
	var owned = {"items": {"iron_crown": {}, "gym_gloves": {}, "shop_greatsword": {}}, "pets": {}}
	var bare = RpgHero.build(sheet_of(30.0), [], RpgSave.empty(), owned)
	var hero = RpgHero.build(sheet_of(30.0), [], rpg, owned)
	# the crown and the gloves are two pieces of Iron: defence +8%
	ok(near(float(hero.w.push), want) and near(float(hero.def), (float(bare.def) + line_of(RpgGear.of("iron_crown"), "armor")) * 1.08) and near(float(hero.spd), float(bare.spd)),
		"RpgHero.build: the worn, owned kit is in the hero's attack and defence", [hero.w, hero.def, bare.def])


# --- runes -------------------------------------------------------------------

func _runes() -> void:
	var a = RpgGear.roll_rune(4, 12345)
	var b = RpgGear.roll_rune(4, 12345)
	ok(a == b and str(a.id).begins_with("rn") and RpgGear.RUNE_LINES.has(a.k) and float(a.v) > 0.0 and RpgDefs.RARITIES.has(a.rarity) and a.size() == 4,
		"roll_rune: the same seed, the same rune", a)
	var ids = {}
	var kinds = {}
	var rarities = {}
	var bad = []
	for i in range(400):
		var r = RpgGear.roll_rune(1 + i % 12, 1000 + i * 7)
		ids[r.id] = true
		kinds[r.k] = true
		rarities[r.rarity] = true
		var size = RpgGear.rune_size(r.k, 1 + i % 12) * float(RpgDefs.RARITY_MULT[r.rarity])
		if float(r.v) < size * 0.85 - 0.06 or float(r.v) > size * 1.15 + 0.06 or RpgGear.rune_words(r) == "" or RpgBattle.check_passive(RpgGear.line_fx(r)) != "":
			bad.append(r)
	ok(ids.size() == 400 and kinds.size() == RpgGear.RUNE_LINES.size() and rarities.size() >= 4 and bad.is_empty(),
		"other seeds, other runes: every id its own, every kind and rarity comes up, each within its size", [ids.size(), kinds.size(), rarities.keys(), bad])
	ok(not RpgGear.RUNE_LINES.has("en_max") and RpgGear.RUNE_LINES.keys().all(func(k): return RpgGear.LINE_KINDS.has(k)), "a rune carries a gear line (never max energy)")
	var grows = true
	for k in RpgGear.RUNE_LINES:
		for t in range(1, 12):
			if RpgGear.rune_size(k, t + 1) <= RpgGear.rune_size(k, t):
				grows = false
	var low = 0.0
	var high = 0.0
	var gold_low = 0
	var gold_high = 0
	for i in range(300):
		var r1 = RpgGear.roll_rune(2, i)
		var r9 = RpgGear.roll_rune(9, i)
		low += float(r1.v) / RpgGear.rune_size(r1.k, 1)
		high += float(r9.v) / RpgGear.rune_size(r9.k, 1)
		gold_low += 1 if RpgDefs.RARITIES.find(r1.rarity) >= 3 else 0
		gold_high += 1 if RpgDefs.RARITIES.find(r9.rarity) >= 3 else 0
	ok(grows and high > low * 1.8 and gold_high > gold_low, "a higher tier: bigger lines, better odds", [low / 300.0, high / 300.0, gold_low, gold_high])
	ok(RpgGear.rune_size("atk_push", 0) == RpgGear.rune_size("atk_push", 1) and RpgGear.rune_size("atk_push", 40) == RpgGear.rune_size("atk_push", 12)
		and RpgGear.rune_size("nope", 3) == 0.0 and RpgGear.roll_rune(-5, 1).k != "", "tiers outside 1..12 are brought back in")
	# nine runes of one kind against what a kit of that tier gives: a third or so
	var nine = 9.0 * RpgGear.rune_size("atk_push", 8) * float(RpgDefs.RARITY_MULT.rare)
	ok(nine > 0.2 * RpgDefs.ref_w(8.0) and nine < 0.6 * RpgDefs.ref_w(8.0), "nine rare attack runes at tier 8: a good part of a kit, never a second one", [nine, RpgDefs.ref_w(8.0)])
	ok(RpgGear.rune_words({"id": "rn1", "k": "atk_grip", "v": 1.2, "rarity": "rare"}) == "Grip attack +1.2", "a rune in words")


# --- relics ------------------------------------------------------------------

func _relics() -> void:
	var all = RpgRelics.all()
	var count = {"rare": 0, "epic": 0, "legendary": 0}
	var bad = []
	var ids = {}
	var sigs = {}
	for r in all:
		count[r.rarity] = int(count.get(r.rarity, 0)) + 1
		ids[r.id] = true
		sigs[JSON.stringify(r.fx)] = true
		if (str(r.id) != RpgDefs.id_of(str(r.name)) or not sentence(r.text) or not Icons.has_icon(r.icon) or r.fx.is_empty() or RpgRelics.by_id(r.id) != r
				or r.keys().size() != 6):
			bad.append(r.id)
		bad.append_array(bad_passives(r.fx, str(r.id)))
	ok(all.size() == 24 and count == {"rare": 8, "epic": 10, "legendary": 6}, "24 relics: 8 rare, 10 epic, 6 legendary", count)
	ok(bad.is_empty() and ids.size() == 24 and sigs.size() == 24, "each with its id, words, an icon that exists and effects the engine knows; no two alike", bad)
	ok(RpgRelics.by_id("nope") == null and RpgRelics.ids_of("legendary").size() == 6 and RpgRelics.dup_ore("cowbell") == int(RpgDefs.DUP_ORE.rare)
		and RpgRelics.dup_ore("nope") == 0, "by_id, ids_of, dup_ore")
	# the companion charging faster is not something the engine does: no relic says so
	ok(all.filter(func(r): return str(r.text).to_lower().contains("companion") or str(r.text).to_lower().contains("charge")).is_empty(), "no relic promises what the engine cannot do")

	# RpgHero wears them
	var rpg = RpgSave.empty()
	rpg["xp"] = xp_for(30)
	rpg.builds[0]["relics"] = ["rest_timer", "glass_barbell", "coachs_whistle"]
	rpg["relics"] = {"rest_timer": true, "glass_barbell": true}
	var hero = RpgHero.build(sheet_of(30.0), [], rpg, {"items": {}, "pets": {}})
	var bare = RpgHero.build(sheet_of(30.0), [], RpgSave.empty(), {"items": {}, "pets": {}})
	var agg = RpgBattle.aggregate(hero.fx)
	ok(near(float(agg.get("cd:all", 0.0)), -1.0) and near(float(agg.get("school_pct:all", 0.0)), 0.2) and not agg.has("first_turn") and int(hero.hp_max) < int(bare.hp_max) + 8 * 29,
		"RpgHero.build: the relics found and worn are in force", agg)


# --- the belt and the camp shop ---------------------------------------------

func _items() -> void:
	var bad = []
	for it in RpgItems.all():
		if RpgBattle.check_item(it) != "":
			bad.append(RpgBattle.check_item(it))
		for e in it.fx:
			if RpgBattle.check_fx(e) != "":
				bad.append([it.id, RpgBattle.check_fx(e)])
		if (int(it.price) < 25 or int(it.price) > 70 or not Icons.has_icon(it.icon) or RpgItems.words(it) != str(it.text) or RpgItems.words(str(it.id)) != str(it.text)
				or not sentence(it.text) or RpgItems.price(str(it.id)) != int(it.price)):
			bad.append(it.id)
	ok(RpgItems.all().size() == 8 and bad.is_empty(), "the eight belt items: effects the engine knows, 25 to 70 ore, words", bad)
	var ids = RpgItems.all().map(func(it): return it.id)
	ok(RpgItems.SHOP.size() == 8 and ids.all(func(id): return RpgItems.SHOP.has(id)) and RpgItems.SHOP.all(func(id): return RpgItems.by_id(id) != null),
		"the camp sells all eight", RpgItems.SHOP)
	ok(RpgItems.by_id("protein_shake") != null and RpgItems.by_id("mega_shake").fx == [{"k": "heal", "pct": 0.7}] and RpgItems.by_id("nope") == null
		and RpgItems.words("nope") == "" and RpgItems.price("nope") == 0 and RpgItems.words("protein_shake") == "Heals 35% of max HP.",
		"by_id, words, price", RpgItems.words("protein_shake"))


# --- companions --------------------------------------------------------------

func _pets() -> void:
	var bad = []
	var names = {}
	for pet in Pets.all():
		var id = str(pet.id)
		var kit = RpgPets.by_id(id)
		if kit == null:
			bad.append(id + ": no kit")
			continue
		if RpgBattle.check_pet(kit) != "":
			bad.append(RpgBattle.check_pet(kit))
		for e in kit.auto.fx + kit.command.fx:
			if RpgBattle.check_fx(e) != "":
				bad.append([id, RpgBattle.check_fx(e)])
		bad.append_array(bad_passives(kit.passive, id))
		if int(kit.command.charge) < 2 or int(kit.command.charge) > 4:
			bad.append(id + ": charge")
		var w = RpgPets.words(id)
		if w == null or not sentence(w.auto) or not sentence(w.command) or (kit.passive.is_empty() != (w.passive == "")):
			bad.append([id, w])
		names[kit.auto.name] = true
		names[kit.command.name] = true
		var rpg = RpgSave.empty()
		rpg.builds[0]["pet"] = id
		var unit = RpgHero.pet_unit(rpg, {"pets": {id: {"at": "2026-01-01"}}}, 12)
		if unit == null or str(unit.pet) != id or int(unit.charge_max) != int(kit.command.charge) or str(unit.rarity) != str(pet.rarity) or str(unit.name) != str(pet.name):
			bad.append([id, unit])
	ok(Pets.all().size() == 16 and RpgPets.all().size() == 16 and bad.is_empty(), "all 16 companions have a kit the engine accepts, words, and a unit", bad)
	ok(names.size() == 32, "every action has its own name", names.size())
	ok(RpgPets.by_id("phoenix").passive.has({"p": "survive", "pct": 0.3}) and RpgPets.by_id("nope") == null and RpgPets.words("nope") == null,
		"Ember keeps the hero standing once, at 30%")
	# the themes of the plan
	var themes = {"slime": "slowed", "bulldog": "exposed", "gecko": "chip", "pigeon": "hasted", "hamster": "gauge", "sprout": "cleanse", "ox": "delay",
		"goat": "stun", "greyhound": "extra_turn", "falcon": "exposed", "golemling": "shield", "tortoise": "braced", "cat": "dispel", "phoenix": "burn",
		"dragon": "burn", "owl": "marked"}
	var off = []
	for id in themes:
		var kit = RpgPets.by_id(id)
		if not JSON.stringify(kit.auto.fx + kit.command.fx).contains("\"" + str(themes[id]) + "\""):
			off.append(id)
	ok(off.is_empty() and RpgPets.by_id("ox").command.target == "all" and RpgPets.by_id("dragon").command.target == "all"
		and RpgPets.by_id("falcon").command.target == "all", "each does what the plan says it does", off)


# --- fights ------------------------------------------------------------------

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


## Made-up foes: a brute, a caster that burns, a tank, and a boss with a second phase.
func custom() -> Dictionary:
	return {
		"foe_moves": {
			"g_hit": {"name": "Hit", "power": 1.0},
			"g_big": {"name": "Big Hit", "kind": "heavy", "power": 1.8, "windup": 1},
			"g_burn": {"name": "Scorch", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "burn", "turns": 2}]},
			"g_slow": {"name": "Tangle", "kind": "debuff", "power": 0.4, "fx": [{"k": "status", "id": "slowed", "turns": 2}]},
			"g_up": {"name": "Flex", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "pumped", "turns": 2}]},
		},
		"foes": {
			"g_brute": {"name": "Gear Brute", "role": "brute", "weak": ["push", "legs"], "moves": ["g_hit", "g_big"], "pattern": ["g_hit", "g_hit", "g_big"]},
			"g_caster": {"name": "Gear Caster", "role": "caster", "weak": ["pull", "mind"], "resist": ["push"], "moves": ["g_burn", "g_slow"], "pattern": ["g_burn", "g_slow"]},
			"g_tank": {"name": "Gear Tank", "role": "tank", "weak": ["speed", "grip"], "moves": ["g_hit", "g_up"], "pattern": ["g_up", "g_hit"]},
			"g_boss": {"name": "Gear Boss", "role": "boss", "boss": true, "weak": ["push", "pull"], "moves": ["g_hit", "g_big", "g_burn"],
				"pattern": ["g_hit", "g_burn", "g_big"], "phases": [{"at": 0.5, "say": "Again!", "pattern": ["g_big", "g_hit"], "weak": ["legs", "grip"]}]},
		},
	}


## A saved Realm at that level wearing the kit, relics, companion and belt given.
func save_with(level: int, gear: Dictionary, relics: Array, pet: String, belt: Array, plus_n: int = 0) -> Dictionary:
	var rpg = RpgSave.empty()
	rpg["xp"] = xp_for(level)
	rpg.builds[0]["gear"] = gear.duplicate()
	rpg.builds[0]["relics"] = relics.duplicate()
	rpg.builds[0]["pet"] = pet
	rpg.builds[0]["belt"] = belt.duplicate()
	for id in relics:
		rpg.relics[id] = true
	for id in belt:
		rpg.items[id] = 3
	for slot in gear:
		rpg.plus[gear[slot]] = plus_n
	return rpg


func owned_of(gear: Dictionary, pet: String) -> Dictionary:
	var items = {}
	for slot in gear:
		items[gear[slot]] = {"at": "2026-01-01"}
	return {"items": items, "pets": {pet: {"at": "2026-01-01"}} if pet != "" else {}}


## Plays a fight to its end: {"B", "ev", "acts", "unsafe", "refused"}.
func play(setup: Dictionary, policy: String = "heuristic", most: int = 500) -> Dictionary:
	var B = RpgBattle.start(setup)
	var out = {"B": B, "ev": RpgBattle.opening(B).duplicate(true), "acts": 0, "unsafe": RpgBattle.json_safe(B), "refused": 0}
	while not RpgBattle.over(B) and int(out.acts) < most:
		var ev = RpgBattle.act(B, RpgAi.hero_action(B, policy))
		out.acts += 1
		if ev.size() == 1 and str(ev[0].t) == "no":
			out.refused += 1
		out.ev.append_array(ev)
		if str(out.unsafe) == "":
			out.unsafe = RpgBattle.json_safe(B)
	return out


func fight(rpg: Dictionary, owned: Dictionary, waves: Array, n: float, fight_seed: int, policy: String = "heuristic") -> Dictionary:
	var lvl = int(RpgDefs.level_of(int(rpg.xp)).lvl)
	var sheet = sheet_of(RpgDefs.ref_stat(RpgDefs.tier_of_n(n)), {})
	var hero = RpgHero.build(sheet, [], rpg, owned)
	var list = []
	for names in waves:
		var w = []
		for id in names:
			w.append({"foe": id, "n": n})
		list.append(w)
	var out = play({"hero": hero, "pet": RpgHero.pet_unit(rpg, owned, lvl), "waves": list, "seed": fight_seed, "custom": custom(), "day": "2026-01-05"}, policy)
	out["hero"] = hero
	return out


func _fights() -> void:
	# the full kit: nine pieces, three relics, a companion, a belt
	var gear = {"head": "granite_crown", "face": "aviators", "body": "yellow_jersey", "hands": "stone_fist_wraps", "legs": "shop_kilt",
		"feet": "winged_sandals", "back": "shop_dragon_wings", "accessory": "wyvern_chalk_bag", "aura": "rainbow_aura"}
	var relics = ["pocket_anvil", "chalk_brick", "titans_knuckle"]
	var rpg = save_with(30, gear, relics, "falcon", ["protein_shake", "chalk_ball", "pre_workout"], 6)
	rpg["runes"] = [RpgGear.roll_rune(6, 1), RpgGear.roll_rune(6, 2), RpgGear.roll_rune(6, 3)]
	rpg["socket"] = {"granite_crown": rpg.runes[0].id, "stone_fist_wraps": rpg.runes[1].id, "shop_dragon_wings": rpg.runes[2].id}
	var owned = owned_of(gear, "falcon")
	var res = fight(rpg, owned, [["g_brute", "g_caster"], ["g_tank", "g_brute"], ["g_boss"]], 50.0, 77)
	var hero = res.hero
	var B = res.B
	var agg = RpgBattle.aggregate(hero.fx)
	ok(float(hero.w.grip) > 20.0 and int(hero.belt.size()) == 3 and hero.pet == "falcon" and float(agg.get("chip:crit", 0.0)) == 1.0 and float(agg.get("chip:grip", 0.0)) == 1.0 and float(agg.get("chip:push", 0.0)) == 1.0
		and float(agg.get("combo_alt", 0.0)) > 0.0 and agg.has("first_turn"), "the full kit is on the hero: lines, runes, uniques, relics", [hero.w, agg])
	ok(RpgBattle.over(B) and str(res.unsafe) == "" and int(res.refused) == 0 and int(res.acts) > 3, "a fight with full gear, three relics, a companion and a belt runs to its end",
		[RpgBattle.over(B), res.unsafe, res.refused, res.acts])
	var kinds = {}
	for e in res.ev:
		if str(e.t) == "act":
			kinds[str(e.who) + ":" + str(e.kind)] = true
	ok(RpgBattle.won(B) and kinds.has("pet:auto") and kinds.has("pet:command"), "it is won, and the companion did its part", kinds.keys())
	var sum = RpgBattle.summary(B)
	ok(sum.has("reward") and float(sum.reward.luck) >= 0.0, "the summary carries the kit's reward lines", sum.get("reward"))

	# a kit with reward lines pays more
	var lucky = {"head": "bounty_crown", "hands": "bounty_crushers", "feet": "bounty_boots", "aura": "bounty_mark", "accessory": "bounty_tooth", "back": "bounty_cloak"}
	rpg = save_with(20, lucky, ["prospectors_pan"], "cat", ["protein_shake"], 3)
	res = fight(rpg, owned_of(lucky, "cat"), [["g_brute", "g_brute"]], 30.0, 5)
	sum = RpgBattle.summary(res.B)
	ok(RpgBattle.over(res.B) and float(sum.reward.ore) > 0.4 and float(sum.reward.luck) > 0.25, "the Hunter kit, the pan and the cat: more ore, better luck", sum.get("reward"))

	# every companion fights a fight to its end
	var stuck = []
	var called = 0
	var i = 0
	for kit in RpgPets.all():
		i += 1
		var some = {"hands": "gym_gloves", "back": "shop_greatsword", "body": "tee_grey", "head": "running_cap"}
		rpg = save_with(12, some, ["cowbell"], str(kit.id), ["protein_shake", "electrolytes"], 2)
		res = fight(rpg, owned_of(some, str(kit.id)), [["g_brute", "g_caster"], ["g_tank"]], 20.0, 300 + i)
		if not RpgBattle.over(res.B) or str(res.unsafe) != "" or int(res.refused) > 0:
			stuck.append([kit.id, res.unsafe, res.refused, res.acts])
		if not res.ev.filter(func(e): return str(e.t) == "act" and str(e.who) == "pet" and str(e.kind) == "command").is_empty():
			called += 1
	ok(stuck.is_empty() and called >= 12, "each of the 16 companions plays a fight to its end, and their commands get used", [stuck, called])

	# every unique, every relic and every set bonus goes through a fight
	stuck = []
	i = 0
	for row in RpgGear.all():
		if row.unique == null:
			continue
		i += 1
		var one = {"hands": "gym_gloves", "back": "hero_cape", "body": "tee_grey", "legs": "shorts_navy"}
		one[row.slot] = row.id
		rpg = save_with(15, one, [RpgRelics.all()[i % 24].id], "", ["protein_shake"], 3)
		res = fight(rpg, owned_of(one, ""), [["g_brute", "g_caster"], ["g_boss"]], 25.0, 900 + i, "random" if i % 3 == 0 else "heuristic")
		if not RpgBattle.over(res.B) or str(res.unsafe) != "":
			stuck.append([row.id, res.unsafe, res.acts])
	for r in RpgRelics.all():
		i += 1
		var two = {"hands": "crimp_gauntlets", "back": "crash_pad", "head": "beanie_green", "feet": "climbing_shoes"}
		rpg = save_with(30, two, [str(r.id), RpgRelics.all()[(i + 5) % 24].id, RpgRelics.all()[(i + 11) % 24].id], "gecko", ["chalk_ball"], 4)
		res = fight(rpg, owned_of(two, "gecko"), [["g_tank", "g_caster", "g_brute"], ["g_boss"]], 35.0, 2000 + i, "random" if i % 2 == 0 else "heuristic")
		if not RpgBattle.over(res.B) or str(res.unsafe) != "":
			stuck.append([r.id, res.unsafe, res.acts])
	for sid in RpgGear.SET_ORDER:
		i += 1
		var four = {}
		for id in RpgGear.SETS[sid].items:
			var row = RpgGear.of(id)
			if not four.has(row.slot):
				four[row.slot] = id
		if RpgGear.set_count(four, sid) < 4:
			stuck.append([sid, "no four pieces"])
		rpg = save_with(18, four, ["resistance_band"], "bulldog", ["protein_shake"], 4)
		res = fight(rpg, owned_of(four, "bulldog"), [["g_brute", "g_caster"], ["g_tank", "g_brute"]], 28.0, 4000 + i)
		if not RpgBattle.over(res.B) or str(res.unsafe) != "":
			stuck.append([sid, res.unsafe, res.acts])
	ok(stuck.is_empty(), "every unique, relic and set bonus goes through a fight without breaking it", stuck)
