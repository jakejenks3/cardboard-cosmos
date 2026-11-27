class_name RpgHero
extends RefCounted
## The hero as a battle unit (RPG_PLAN.md 4.1, 4.7, 11.3, 11.4). Pure: it reads
## the sheet (RpgStats), the day's boosts (RpgBoosts), the saved Realm
## (`saved.rpg`) and what the player owns, and returns plain dictionaries.
##
##   build(sheet, boosts, rpg, owned) -> unit      the hero as RpgBattle.start wants it
##   pet_unit(rpg, owned, level) -> unit or null   the build's companion
##   reference_hero(t, archetype = "balanced") -> unit
##                                                 the hero the road expects at tier t (foes are solved from it)
##   power(unit) -> float                          one number for "how strong" (a stage's `rec` = power(reference_hero(t)))
##   numbers(unit) -> Dictionary                   the fight numbers for the Hero page
##   knows_move(rpg, move) / knows_passive(rpg, passive) -> bool
##
## NOTE: the plan calls the third one `RpgHero.reference`. A script cannot have
## a static function of that name: `RpgHero.reference(...)` reaches the script
## object's own RefCounted.reference() instead (tried: "Expected 0 arguments").
## So it is `reference_hero`.
##
## What goes into a hero, in this order (anything unknown, not owned, not
## learned or beyond the slots the fighter level opens is skipped, never an
## error):
##   the build in use (RpgSave.build_of): moves, ultimate, passives, gear, relics, companion, belt
##   gear -> RpgGear.fx · relics -> RpgRelics · board passives -> RpgPassives · the companion's passive -> RpgPets
##   the day's boosts (each boost's "fx")
## All of those are PASSIVE EFFECTS (the `p` vocabulary at the top of
## rpg_battle.gd). The ones that are plain numbers are worked out here, once:
##   stat_pct -> unit.s · hp, hp_pct -> hp_max · armor, def_pct -> def · spd_pct -> spd · crit_add -> crit ·
##   dodge_add -> dodge · res_add -> res · atk -> unit.w · en_max -> en_max
## Everything stays in unit.fx; the engine reads the rest from there (it never
## applies the ones above again).
##
## The unit (11.3): {"id": "hero", "side": "hero", "name", "hp", "hp_max", "def", "spd", "res", "tec", "crit",
##   "dodge", "at", "alive", "statuses", "stun_guard", "s": {stat: effective value}, "w": {school: flat attack},
##   "lvl", "en", "en_max", "gauge", "moves": [ids], "ult": id or "", "cds", "fx": [passive effects], "belt":
##   [{"id", "n", "used"}], "guarding", "flags", "might", "pet": the companion's id or ""}

## The reference hero's builds. `main` = the stats it has at RpgDefs.ref_stat(t)
## (every other stat is at ref_side(t)); `kits` = what it has equipped from a
## tier on (the last one whose "from" is not above t counts): tier 1 starters
## only, tier 2 the boards' first two tiers and one passive, tier 4 up to board
## tier 4 and two passives, tier 6 a fifth move, three passives and the
## ultimate: what its level and stats would let it learn (RpgDefs.NODE_LEVEL,
## REQ, PASSIVE_SLOTS_AT, MOVE_SLOT_5_AT).
const ARCHETYPES = {
	"balanced": {"name": "All-rounder", "main": ["chest", "shoulders", "arms", "back", "legs"], "kits": [
		{"from": 1.0, "moves": ["shove", "yank", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["one_two", "row_rip", "stomp", "deep_breath"], "ult": "", "passives": ["lockout_strength"]},
		{"from": 4.0, "moves": ["haymaker", "suplex", "lunge_strike", "deep_breath"], "ult": "", "passives": ["lockout_strength", "grip_and_rip"]},
		{"from": 6.0, "moves": ["overhead_smash", "deadlift_slam", "one_two", "stomp", "deep_breath"], "ult": "titan_press",
			"passives": ["lockout_strength", "grip_and_rip", "leg_drive"]}]},
	"push": {"name": "Presser", "main": ["chest", "shoulders", "arms"], "kits": [
		{"from": 1.0, "moves": ["shove", "yank", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["shove", "one_two", "bench_blast", "deep_breath"], "ult": "", "passives": ["lockout_strength"]},
		{"from": 4.0, "moves": ["shove", "one_two", "haymaker", "deep_breath"], "ult": "", "passives": ["lockout_strength", "pressing_momentum"]},
		{"from": 6.0, "moves": ["shove", "one_two", "haymaker", "overhead_smash", "deep_breath"], "ult": "titan_press",
			"passives": ["lockout_strength", "pressing_momentum", "spotter"]}]},
	"pull": {"name": "Puller", "main": ["back", "arms"], "kits": [
		{"from": 1.0, "moves": ["yank", "shove", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["yank", "row_rip", "arm_drag", "deep_breath"], "ult": "", "passives": ["grip_and_rip"]},
		{"from": 4.0, "moves": ["yank", "row_rip", "suplex", "deep_breath"], "ult": "", "passives": ["grip_and_rip", "hook_grip"]},
		{"from": 6.0, "moves": ["yank", "row_rip", "suplex", "deadlift_slam", "deep_breath"], "ult": "mountain_mover",
			"passives": ["grip_and_rip", "hook_grip", "lats_of_steel"]}]},
	"legs": {"name": "Squatter", "main": ["legs", "core"], "kits": [
		{"from": 1.0, "moves": ["stomp", "shove", "yank", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["stomp", "lunge_strike", "squat_launch", "deep_breath"], "ult": "", "passives": ["leg_drive"]},
		{"from": 4.0, "moves": ["stomp", "lunge_strike", "dropkick", "deep_breath"], "ult": "", "passives": ["leg_drive", "never_skip"]},
		{"from": 6.0, "moves": ["stomp", "lunge_strike", "dropkick", "leg_day", "deep_breath"], "ult": "quake_drop",
			"passives": ["leg_drive", "never_skip", "tree_trunks"]}]},
	"speed": {"name": "Runner", "main": ["speed"], "kits": [
		{"from": 1.0, "moves": ["dash_strike", "shove", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["dash_strike", "flurry", "tempo_run", "deep_breath"], "ult": "", "passives": ["light_feet"]},
		{"from": 4.0, "moves": ["dash_strike", "flurry", "negative_split", "deep_breath"], "ult": "", "passives": ["light_feet", "negative_splits"]},
		{"from": 6.0, "moves": ["dash_strike", "flurry", "negative_split", "lap", "deep_breath"], "ult": "runners_high",
			"passives": ["light_feet", "negative_splits", "off_the_line"]}]},
	"grip": {"name": "Climber", "main": ["grip"], "kits": [
		{"from": 1.0, "moves": ["pinch", "shove", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["pinch", "crimp_strike", "chalk_up", "deep_breath"], "ult": "", "passives": ["chalk_hands"]},
		{"from": 4.0, "moves": ["pinch", "crimp_strike", "campus_rush", "deep_breath"], "ult": "", "passives": ["chalk_hands", "onsight"]},
		{"from": 6.0, "moves": ["pinch", "crimp_strike", "campus_rush", "send_it", "deep_breath"], "ult": "free_solo",
			"passives": ["chalk_hands", "onsight", "precision"]}]},
	"mind": {"name": "Reader", "main": ["mind"], "kits": [
		{"from": 1.0, "moves": ["burning_page", "shove", "stomp", "deep_breath"], "ult": "", "passives": []},
		{"from": 2.0, "moves": ["burning_page", "hex_of_doubt", "read_the_room", "deep_breath"], "ult": "", "passives": ["marginalia"]},
		{"from": 4.0, "moves": ["burning_page", "footnote", "chapter_close", "deep_breath"], "ult": "", "passives": ["marginalia", "thinkers_calm"]},
		{"from": 6.0, "moves": ["burning_page", "footnote", "chapter_close", "thesis", "deep_breath"], "ult": "final_chapter",
			"passives": ["marginalia", "thinkers_calm", "well_read"]}]},
}


# =============================================================================
# What the save lets the hero use
# =============================================================================

## Does the saved Realm know this move (a row of RpgMoves)? Starters always; a
## scroll (tier 9) once found; a board move once its node "<school>:<id>" is owned.
static func knows_move(rpg: Dictionary, move: Dictionary) -> bool:
	var tier = int(move.get("tier", 0))
	if tier <= 0:
		return true
	var id = str(move.get("id", ""))
	if tier >= 9:
		return bool(rpg.get("scrolls", {}).get(id, false))
	return bool(rpg.get("nodes", {}).get(str(move.get("school", "")) + ":" + id, false))


## Does the saved Realm own this passive's node ("<board>:<id>")?
static func knows_passive(rpg: Dictionary, passive: Dictionary) -> bool:
	return bool(rpg.get("nodes", {}).get(str(passive.get("board", "")) + ":" + str(passive.get("id", "")), false))


static func _fx_of(row) -> Array:
	var out = []
	if row is Dictionary and row.get("fx") is Array:
		for e in row.fx:
			if e is Dictionary:
				out.append(e.duplicate(true))
	return out


# =============================================================================
# build
# =============================================================================

## The hero unit of the build in use. `sheet` = RpgStats.sheet (its
## stats[id].raw and might are read); `boosts` = RpgBoosts.active (each one's
## "fx"); `rpg` = saved.rpg; `owned` = {"items": state.items, "pets": state.pets}.
static func build(sheet: Dictionary, boosts: Array, rpg: Dictionary, owned: Dictionary) -> Dictionary:
	var lvl = int(RpgDefs.level_of(int(rpg.get("xp", 0))).lvl)
	var b = RpgSave.build_of(rpg)
	var have_items = owned.get("items") if owned.get("items") is Dictionary else {}
	var have_pets = owned.get("pets") if owned.get("pets") is Dictionary else {}
	var fx = []

	# gear: owned items only, slot by slot in the game's own order
	var gear = {}
	var worn = b.get("gear", {})
	for slot in TT.SLOTS:
		var id = worn.get(slot)
		if id is String and id != "" and have_items.has(id):
			gear[slot] = id
	for e in RpgGear.fx(gear, rpg.get("plus", {}), rpg.get("runes", []), rpg.get("socket", {})):
		if e is Dictionary:
			fx.append(e.duplicate(true))

	# relics: found ones, in the slots the level opens, each once
	var relics = []
	var slots = b.get("relics", [])
	for i in range(mini(RpgDefs.relic_slots(lvl), slots.size())):
		var id = str(slots[i])
		var row = RpgRelics.by_id(id) if id != "" else null
		if row != null and bool(rpg.get("relics", {}).get(id, false)) and not relics.has(id):
			relics.append(id)
			fx.append_array(_fx_of(row))

	# board passives: learned ones, in the slots the level opens, each once
	var passives = []
	slots = b.get("passives", [])
	for i in range(mini(RpgDefs.passive_slots(lvl), slots.size())):
		var id = str(slots[i])
		var row = RpgPassives.by_id(id) if id != "" else null
		if row != null and knows_passive(rpg, row) and not passives.has(id):
			passives.append(id)
			fx.append_array(_fx_of(row))

	# the companion's passive
	var pet = str(b.get("pet", ""))
	var kit = RpgPets.by_id(pet) if (pet != "" and have_pets.has(pet)) else null
	if kit == null:
		pet = ""
	elif kit.get("passive") is Array:
		for e in kit.passive:
			if e is Dictionary:
				fx.append(e.duplicate(true))

	# the day's boosts
	for boost in boosts:
		fx.append_array(_fx_of(boost))

	# moves: known ones, in the slots the level opens, each once
	var moves = []
	slots = b.get("moves", [])
	for i in range(mini(RpgDefs.move_slots(lvl), slots.size())):
		var id = str(slots[i])
		var row = RpgMoves.by_id(id) if id != "" else null
		if row != null and not bool(row.get("ult", false)) and knows_move(rpg, row) and not moves.has(id):
			moves.append(id)
	var ult = str(b.get("ult", ""))
	var urow = RpgMoves.by_id(ult) if ult != "" else null
	if urow == null or not bool(urow.get("ult", false)) or not knows_move(rpg, urow):
		ult = ""

	# the belt: stacks the save holds, in the slots the level opens
	var belt = []
	var seen = []
	slots = b.get("belt", [])
	for i in range(mini(RpgDefs.belt_slots(lvl), slots.size())):
		var id = str(slots[i])
		var n = rpg.get("items", {}).get(id, 0)
		n = int(n) if (n is int or n is float) else 0
		if id != "" and n > 0 and RpgItems.by_id(id) != null and not seen.has(id):
			seen.append(id)
			belt.append({"id": id, "n": n, "used": 0})

	var raw = {}
	var stats = sheet.get("stats", {})
	for id in RpgDefs.STATS:
		var st = stats.get(id)
		var v = st.get("raw") if st is Dictionary else null
		raw[id] = float(v) if (v is int or v is float) else RpgDefs.STAT_MIN
	var spec = {"name": "Hero", "raw": raw, "lvl": lvl, "fx": fx, "moves": moves, "ult": ult, "belt": belt, "pet": pet}
	if sheet.get("might") is int or sheet.get("might") is float:
		spec["might"] = float(sheet.might)
	return _assemble(spec)


## The numbers of a hero from its raw stats, its level and its passive effects.
## spec = {"name", "raw": {stat: value}, "lvl", "fx", "moves", "ult", "belt", "pet",
##         "might" (the sheet's; else the mean of the raw body stats),
##         "hp_base", "def_base" (the reference hero: given, not worked out from the stats)}
static func _assemble(spec: Dictionary) -> Dictionary:
	var lvl = clampi(int(spec.get("lvl", 1)), 1, RpgDefs.LEVEL_MAX)
	var fx = spec.get("fx", [])
	var agg = RpgBattle.aggregate(fx)
	var raw = spec.get("raw", {})

	# the stats in force: the raw value times every stat_pct that names it
	var s = {}
	var raw_body = 0.0
	var eff_body = 0.0
	for id in RpgDefs.STATS:
		var base = maxf(RpgDefs.STAT_MIN, float(raw.get(id, RpgDefs.STAT_MIN)))
		var pct = float(agg.get("stat_pct:" + id, 0.0)) + float(agg.get("stat_pct:all", 0.0))
		if RpgDefs.BODY.has(id):
			pct += float(agg.get("stat_pct:body", 0.0))
		s[id] = maxf(RpgDefs.STAT_MIN, base * (1.0 + pct))
		if RpgDefs.BODY.has(id):
			raw_body += base
			eff_body += float(s[id])
	var body_n = float(RpgDefs.BODY.size())
	# might: the sheet's own number, moved by what the boosts add to the body stats
	var might = float(spec.get("might", raw_body / body_n)) + (eff_body - raw_body) / body_n

	var hp_base = float(spec.hp_base) if spec.has("hp_base") else RpgDefs.hero_hp(float(s.endurance), float(s.legs), float(s.core), lvl)
	var def_base = float(spec.def_base) if spec.has("def_base") else RpgDefs.hero_def(float(s.core), might, 0.0)
	var hp_max = maxi(1, int(round((hp_base + float(agg.get("hp", 0.0))) * (1.0 + float(agg.get("hp_pct", 0.0))))))
	var def = maxf(0.0, (def_base + float(agg.get("armor", 0.0))) * (1.0 + float(agg.get("def_pct", 0.0))))
	var en_max = maxi(1, RpgDefs.en_max(float(s.endurance)) + int(round(float(agg.get("en_max", 0.0)))))
	var w = {}
	for school in RpgDefs.SCHOOLS:
		w[school] = float(agg.get("atk:" + school, 0.0)) + float(agg.get("atk:all", 0.0))

	return {
		"id": "hero", "side": "hero", "name": str(spec.get("name", "Hero")),
		"hp": hp_max, "hp_max": hp_max, "def": def,
		"spd": maxf(1.0, float(s.speed) * (1.0 + float(agg.get("spd_pct", 0.0)))),
		"res": float(s.flow) + float(agg.get("res_add", 0.0)), "tec": float(s.mind),
		"crit": RpgDefs.crit_chance(float(s.grip), float(agg.get("crit_add", 0.0))),
		"dodge": RpgDefs.dodge_chance(float(s.flow), float(agg.get("dodge_add", 0.0))),
		"at": 0.0, "alive": true, "statuses": [], "stun_guard": 0,
		"s": s, "w": w, "lvl": lvl, "might": might,
		"en": clampi(RpgDefs.EN_START + int(round(float(agg.get("en_start", 0.0)))), 0, en_max), "en_max": en_max,
		"gauge": clampf(float(agg.get("gauge_start", 0.0)), 0.0, RpgDefs.GAUGE_MAX),
		"moves": spec.get("moves", []).duplicate(), "ult": str(spec.get("ult", "")), "cds": {},
		"fx": fx, "belt": spec.get("belt", []).duplicate(true), "guarding": false, "flags": {},
		"pet": str(spec.get("pet", "")),
	}


# =============================================================================
# The companion
# =============================================================================

## The battle unit of the build's companion, or null (none chosen, not owned,
## or a pet with no kit yet). `level` = the fighter level (its speed, 4.7).
## Its attack is set by the engine from the hero it stands beside.
static func pet_unit(rpg: Dictionary, owned: Dictionary, level: int) -> Variant:
	var id = str(RpgSave.build_of(rpg).get("pet", ""))
	var have = owned.get("pets") if owned.get("pets") is Dictionary else {}
	if id == "" or not have.has(id):
		return null
	var kit = RpgPets.by_id(id)
	if kit == null:
		return null
	var pet = Pets.by_id(id)
	return {
		"id": "pet", "side": "hero", "pet": id,
		"name": str(pet.get("name", id)) if pet is Dictionary else id,
		"rarity": str(pet.get("rarity", "common")) if pet is Dictionary else "common",
		"spd": RpgDefs.PET_SPD + 2.0 * float(RpgDefs.tier_of_level(level)),
		"charge": 0, "charge_max": clampi(int(kit.get("command", {}).get("charge", 3)), 1, 9),
		"at": 0.0, "alive": true, "statuses": [],
	}


# =============================================================================
# The reference hero
# =============================================================================

## The kit an archetype has equipped at tier t.
static func kit_of(archetype: String, t: float) -> Dictionary:
	var a = ARCHETYPES.get(archetype, ARCHETYPES["balanced"])
	var kit = a.kits[0]
	for k in a.kits:
		if float(k.from) <= t + 0.0001:
			kit = k
	return kit


## The hero the road expects at tier t (a float; RpgDefs.tier_of_n): the stats
## of its archetype at RpgDefs.ref_stat(t), the others at ref_side(t), level
## ref_level(t), gear attack ref_w(t) for every school, armour ref_armor(t),
## and exactly RpgDefs.ref_hp(t) HP and ref_def(t) defence before its own
## passives (whatever its archetype: foes are solved from those two). No
## companion, no belt, no boosts.
static func reference_hero(t: float, archetype: String = "balanced") -> Dictionary:
	var a = ARCHETYPES.get(archetype, ARCHETYPES["balanced"])
	var kit = kit_of(archetype, t)
	var side = RpgDefs.ref_side(t)
	var raw = {}
	for id in RpgDefs.STATS:
		raw[id] = RpgDefs.ref_stat(t) if a.main.has(id) else side
	var fx = [{"p": "atk", "school": "all", "v": RpgDefs.ref_w(t)}, {"p": "armor", "v": RpgDefs.ref_armor(t)}]
	for id in kit.passives:
		fx.append_array(_fx_of(RpgPassives.by_id(str(id))))
	var moves = []
	for id in kit.moves:
		if RpgMoves.by_id(str(id)) != null:
			moves.append(str(id))
	var ult = str(kit.ult) if RpgMoves.by_id(str(kit.ult)) != null else ""
	return _assemble({"name": str(a.name), "raw": raw, "lvl": RpgDefs.ref_level(t), "fx": fx, "moves": moves, "ult": ult,
		"belt": [], "pet": "", "might": side, "hp_base": RpgDefs.ref_hp(t), "def_base": RpgDefs.hero_def(side, side, 0.0)})


# =============================================================================
# Numbers
# =============================================================================

## The hero's attack moves as rows (Strike alone when it has none).
static func _attack_rows(unit: Dictionary) -> Array:
	var out = []
	for id in unit.get("moves", []):
		var row = RpgMoves.by_id(str(id))
		if row != null and str(row.get("kind", "attack")) == "attack":
			out.append(row)
	if out.is_empty():
		out.append(RpgBattle.strike_row())
	return out


## One number for how strong a hero is (4.1): sqrt(DPT * EHP) / 2, with
## DPT = the mean power per rank of its attack moves * its best offence *
## (1 + crit / 2) * (150 + spd) / 190 and EHP = max HP / mitigation(defence).
static func power(unit: Dictionary) -> float:
	var rows = _attack_rows(unit)
	var per_rank = 0.0
	var best = 0.0
	for row in rows:
		per_rank += float(row.get("power", 0.0)) / maxf(0.1, float(row.get("rank", 1.0)))
		best = maxf(best, RpgBattle.offence_of(unit, row))
	per_rank /= float(rows.size())
	var dpt = per_rank * best * (1.0 + float(unit.get("crit", 0.0)) * 0.5) * (RpgDefs.DELAY_OFFSET + float(unit.get("spd", 0.0))) / 190.0
	var ehp = float(unit.get("hp_max", 1)) / RpgDefs.mitigation(float(unit.get("def", 0.0)))
	return sqrt(maxf(0.0, dpt * ehp)) / 2.0


## The fight numbers of a hero for the Hero page:
##   {"hp", "def", "blocks" (the share of a hit its defence takes off), "spd", "crit", "dodge", "en_max", "en_start",
##    "gauge_start", "res", "tec", "guard" (the share of a hit Guard lets through), "heal" (what its heals are
##    multiplied by), "gauge_rate" (what its gauge gains are multiplied by), "lvl", "power",
##    "offence": {school: what a move of that school hits with, by the school's best stat}, "strike": the same for Strike}
static func numbers(unit: Dictionary) -> Dictionary:
	var agg = RpgBattle.aggregate(unit.get("fx", []))
	var s = unit.get("s", {})
	var w = unit.get("w", {})
	var lvl = int(unit.get("lvl", 1))
	var offence = {}
	for school in RpgDefs.SCHOOLS:
		var top = RpgDefs.STAT_MIN
		for id in RpgDefs.SCHOOL_STATS[school]:
			top = maxf(top, float(s.get(id, RpgDefs.STAT_MIN)))
		offence[school] = RpgDefs.offence(top, float(w.get(school, 0.0)), lvl)
	return {
		"hp": int(unit.get("hp_max", 1)), "def": float(unit.get("def", 0.0)),
		"blocks": 1.0 - RpgDefs.mitigation(float(unit.get("def", 0.0))),
		"spd": float(unit.get("spd", 0.0)), "crit": float(unit.get("crit", 0.0)), "dodge": float(unit.get("dodge", 0.0)),
		"en_max": int(unit.get("en_max", RpgDefs.EN_BASE)), "en_start": int(unit.get("en", RpgDefs.EN_START)),
		"gauge_start": float(unit.get("gauge", 0.0)),
		"res": float(unit.get("res", 0.0)), "tec": float(unit.get("tec", 0.0)),
		"guard": RpgDefs.guard_mult(float(s.get("core", RpgDefs.STAT_MIN)), float(agg.get("guard_pct", 0.0))),
		"heal": RpgDefs.heal_mult(float(s.get("flow", RpgDefs.STAT_MIN)), float(agg.get("heal_pct", 0.0))),
		"gauge_rate": RpgDefs.gauge_mult(float(s.get("grit", RpgDefs.STAT_MIN)), float(agg.get("gauge_rate", 0.0))),
		"lvl": lvl, "power": power(unit),
		"offence": offence, "strike": RpgBattle.offence_of(unit, RpgBattle.strike_row()),
	}
