class_name RpgLoot
extends RefCounted
## What the Realm pays (RPG_PLAN.md 8.2, 8.4, 7.1): the rewards of a won
## battle, what a cache holds, the star chests, the hunt's prizes and every
## rune that is rolled. Pure and seeded: the same call gives the same loot.
## Nothing here changes the save: RpgSave.finish / take_cache /
## open_star_chest / take_hunt_prize / claim_chest put it in.
##
##   rewards(stage, summary, rpg, level, boosts, seed) ->
##       {"xp", "ore", "items": [{id, n}], "runes": [rune], "relic": id or "", "scroll": id or "", "first": bool,
##        "relic_dup": bool (the relic is one the player has: RpgSave turns it into ore), "prizes": [options]
##        (a hunt whose prize of the day is not taken yet: pick one, RpgSave.take_hunt_prize)}
##       Fighter XP and ore from every foe of every wave by its kind (RpgDefs.foe_xp / foe_ore), the XP by the
##       over-level share, both by the hero's "reward" passives (summary.reward, which holds the day's boosts
##       too; without it the boosts given here are read). A belt item on ITEM_CHANCE of wins, a rune on
##       RUNE_CHANCE of elite and boss wins. A first win adds the stage's "first". A repeat win pays the same
##       XP and ore again; there are no daily limits. A Spire floor pays once: a floor already climbed pays nothing.
##   cache(stage_id, rpg, seed) -> three options, each {"kind": "relic"|"rune"|"items"|"ore", and "relic": id /
##       "rune": rune / "items": [{id, n}] / "ore": n}: a relic the player does not have (ore when none is left),
##       a rune, a stack of belt items.
##   star_chest(region_id, threshold, seed, rpg = {}) -> {"ore", "items", "runes", "relic", "scroll"}
##       8 stars: ore and belt items; 16: the region's second scroll move and ore; 24: a relic, a rune and ore.
##   hunt_prizes(date, n, rpg) -> three options (ore, an item stack, a rune)
##   item_drop(seed, n) -> {"id", "n"}; rune(n, rpg, salt, k = 0, lift = 0) -> rune; chest_rune(rpg, date) -> rune
##   pick_relic(rpg, n, salt, skip = []) -> id or ""; scrap_ore(rune) -> ore
##
## Runes: RpgGear.roll_rune makes a rune's id from its seed alone, so every
## seed handed out here is one no rune of the save has (`rune_seed`): the
## number after the highest one in the save, with a few bits of the salt
## under it so that two players do not find the same runes in the same order.

## The chance of a belt item from a win, by the stage's biggest foe.
const ITEM_CHANCE = {"regular": 0.2, "elite": 0.75, "boss": 1.0}
## The chance of a rune from a win that is not the first.
const RUNE_CHANCE = {"regular": 0.0, "elite": 0.2, "boss": 0.4}
## Belt items a battle may drop: [id, weight, from which difficulty index].
const DROPS = [["protein_shake", 5.0, 0], ["electrolytes", 4.0, 0], ["chalk_ball", 3.0, 0], ["energy_gel", 3.0, 10],
	["ice_pack", 3.0, 20], ["smelling_salts", 3.0, 20], ["mega_shake", 2.0, 30], ["pre_workout", 1.5, 40]]
## Ore for a rune that is scrapped.
const SCRAP_ORE = {"common": 8, "uncommon": 14, "rare": 25, "epic": 45, "legendary": 80}
## Ore in place of a relic when the player has them all.
const NO_RELIC_ORE = 150
const SEED_BITS = 12


# =============================================================================
# Small things
# =============================================================================

static func _add_item(items: Array, id: String, n: int) -> void:
	if id == "" or n <= 0:
		return
	for it in items:
		if str(it.id) == id:
			it["n"] = int(it.n) + n
			return
	items.append({"id": id, "n": n})


## The rune tier of a difficulty index (1 in the Rustyard, 8 at Titan's Rest, to 12 beyond).
static func rune_tier(n: float) -> int:
	return clampi(1 + int(floor(n / 10.0)), 1, RpgGear.RUNE_TIERS)


## A seed no rune of the save was made from. `k` = the how-manyth rune of the same hand-out.
static func rune_seed(rpg: Dictionary, salt: String, k: int = 0) -> int:
	var top = 0
	var have = rpg.get("runes", [])
	if have is Array:
		for r in have:
			var id = str(r.get("id", "")) if r is Dictionary else ""
			if id.begins_with("rn") and id.substr(2).is_valid_hex_number():
				top = maxi(top, id.substr(2).hex_to_int() >> SEED_BITS)
	return ((top + 1 + maxi(0, k)) << SEED_BITS) | (Rng.hash_string("rune:" + salt) & ((1 << SEED_BITS) - 1))


## A rune for a difficulty index (`lift` = tiers above what the index gives).
static func rune(n: float, rpg: Dictionary, salt: String, k: int = 0, lift: int = 0) -> Dictionary:
	return RpgGear.roll_rune(clampi(rune_tier(n) + lift, 1, RpgGear.RUNE_TIERS), rune_seed(rpg, salt, k))


## The rune of a gold training chest (RpgBoosts.chest): of the tier the player has reached.
static func chest_rune(rpg: Dictionary, date: String) -> Dictionary:
	return rune(RpgWorld.best_n(rpg), rpg, "chest:" + date)


## Ore for a rune that is scrapped.
static func scrap_ore(a_rune: Dictionary) -> int:
	return int(SCRAP_ORE.get(str(a_rune.get("rarity", "common")), 8))


## One belt item a battle of that index drops: {"id", "n": 1}.
static func item_drop(drop_seed: int, n: float) -> Dictionary:
	var st = Rng.make_rng("drop:%d:%d" % [drop_seed, int(floor(n))])
	var pool = DROPS.filter(func(row): return n >= float(row[2]))
	var row = st.weighted(pool, func(r): return float(r[1]))
	return {"id": str(row[0]) if row != null else "protein_shake", "n": 1}


## A relic the player does not have, or "" when they have them all. The
## rarer ones come deeper in: rare to index 30, rare and epic to 60, then
## epic and legendary; a pool that is used up widens to any relic left.
static func pick_relic(rpg: Dictionary, n: float, salt: String, skip: Array = []) -> String:
	var have = rpg.get("relics", {})
	var want = ["rare"] if n < 30.0 else (["epic", "rare"] if n < 60.0 else ["legendary", "epic"])
	var st = Rng.make_rng("relic:" + salt)
	var pool = []
	var rest = []
	for r in RpgRelics.all():
		var id = str(r.id)
		if bool(have.get(id, false)) or skip.has(id):
			continue
		if want.has(str(r.rarity)):
			pool.append(id)
		else:
			rest.append(id)
	if pool.is_empty():
		pool = rest
	if pool.is_empty():
		return ""
	return str(pool[st.next_int(pool.size())])


## Has this stage paid its "first" yet? A road or echo stage: never won; the
## hunt: not won on its date; the rival: not won in its week; a Spire floor:
## above the best one climbed.
static func is_first(stage: Dictionary, rpg: Dictionary) -> bool:
	match str(stage.get("kind", "")):
		"hunt":
			var h = rpg.get("hunt", {})
			return not (str(h.get("date", "")) == str(stage.get("date", "")) and bool(h.get("won", false)))
		"rival":
			var rv = rpg.get("rival", {})
			return not (str(rv.get("week", "")) == str(stage.get("week", "")) and bool(rv.get("won", false)))
		"spire":
			return int(stage.get("floor", 0)) > int(rpg.get("spire", {}).get("best", 0))
		"dare":
			return not RpgWorld.dared(rpg, str(stage.get("of", "")))
	var rec = rpg.get("stages", {}).get(str(stage.get("id", "")))
	return not (rec is Dictionary and int(rec.get("wins", 0)) > 0)


## Is the day's hunt prize still to be picked? (It is marked in rpg.caches under the hunt's id.)
static func hunt_prize_left(rpg: Dictionary, date: String) -> bool:
	return not bool(rpg.get("caches", {}).get("hunt:" + date, false))


# =============================================================================
# A won battle
# =============================================================================

static func _reward_pct(summary: Dictionary, boosts: Array, what: String) -> float:
	var rw = summary.get("reward")
	if rw is Dictionary:
		return maxf(0.0, float(rw.get(what, 0.0)))
	var sum = 0.0
	for e in RpgBoosts.fx(boosts):
		if e is Dictionary and str(e.get("p", "")) == "reward" and str(e.get("what", "")) == what:
			sum += float(e.get("pct", 0.0))
	return maxf(0.0, sum)


## What a battle pays (see the top). `summary` = RpgBattle.summary; `level` =
## the fighter level before the battle; `loot_seed` = any number (the
## battle's own seed does well).
static func rewards(stage: Dictionary, summary: Dictionary, rpg: Dictionary, level: int, boosts: Array, loot_seed: int) -> Dictionary:
	var out = {"xp": 0, "ore": 0, "items": [], "runes": [], "relic": "", "scroll": "", "first": false, "relic_dup": false, "prizes": []}
	if not bool(summary.get("win", false)):
		return out
	var kind = str(stage.get("kind", ""))
	if kind == "practice":
		return out          # the practice yard pays nothing
	var id = str(stage.get("id", ""))
	var n = float(stage.get("n", 0))
	var first = is_first(stage, rpg)
	if kind == "spire" and not first:
		return out
	var st = Rng.make_rng("loot:%s:%d" % [id, loot_seed])

	# fighter XP and ore: every foe of every wave, by its kind
	var xp = 0.0
	var ore = 0.0
	var top = "regular"
	for wave in RpgWorld.waves_fought(stage):
		for en in wave:
			var fk = RpgWorld.foe_kind(en)
			var fn = float(en.get("n", n))
			xp += float(RpgDefs.foe_xp(fn, fk))
			ore += float(RpgDefs.foe_ore(fn, fk))
			if fk == "boss" or (fk == "elite" and top == "regular"):
				top = fk
	out["xp"] = int(round(xp * RpgDefs.xp_share(level, n) * (1.0 + _reward_pct(summary, boosts, "xp"))))
	out["ore"] = int(round(ore * (1.0 + _reward_pct(summary, boosts, "ore"))))

	# a belt item, and from the big ones sometimes a rune
	var luck = 1.0 + _reward_pct(summary, boosts, "luck")
	var runes = 0
	if st.next() < minf(1.0, float(ITEM_CHANCE[top]) * luck):
		var drop = item_drop(st.next_int(1 << 30), n)
		_add_item(out.items, str(drop.id), int(drop.n))
	var rune_roll = st.next()
	var owed = stage.get("first") if (first and stage.get("first") is Dictionary) else {}
	if not bool(owed.get("rune", false)) and rune_roll < minf(1.0, float(RUNE_CHANCE[top]) * luck):
		out.runes.append(rune(n, rpg, "%s:%d" % [id, loot_seed], runes))
		runes += 1

	# the first win
	if first:
		out["first"] = true
		out["ore"] = int(out.ore) + int(owed.get("ore", 0))
		for it in owed.get("items", []):
			_add_item(out.items, str(it.id), int(it.n))
		out["scroll"] = str(owed.get("scroll", ""))
		var relic = str(owed.get("relic", ""))
		var want_rune = bool(owed.get("rune", false))
		if relic == "any":
			relic = pick_relic(rpg, n, id)
			if relic == "":
				want_rune = true
		out["relic"] = relic
		out["relic_dup"] = relic != "" and bool(rpg.get("relics", {}).get(relic, false))
		if want_rune:
			out.runes.append(rune(n, rpg, "%s:first" % id, runes))
			runes += 1
	# an Ore Mole felled before it dug away: its ore
	var moles = int(summary.get("treasure", 0))
	if moles > 0:
		out["treasure"] = moles * RpgDefs.treasure_ore(n)
		out["ore"] = int(out.ore) + int(out.treasure)
	if kind == "hunt" and first:
		# the hunt streak: days in a row add ore to the day's first win
		var streak = RpgWorld.hunt_streak_next(rpg, str(stage.get("date", "")))
		out["streak"] = streak
		out["ore"] = int(out.ore) + RpgWorld.hunt_streak_ore(streak)
	if kind == "hunt" and hunt_prize_left(rpg, str(stage.get("date", ""))):
		out["prizes"] = stage.get("prizes", []).duplicate(true)
	return out


# =============================================================================
# Caches, star chests, the hunt
# =============================================================================

## The three finds of a cache (stage 6 of a region, on the road or in an
## echo) to pick one from. The same stage, save and seed give the same three.
static func cache(stage_id: String, rpg: Dictionary, cache_seed: int) -> Array:
	var stage = RpgWorld.stage(stage_id)
	if not (stage is Dictionary):
		return []
	var n = float(stage.n)
	var r = clampi(int(stage.get("r", 1)), 1, RpgWorld.REGION_ITEMS.size())
	var salt = "cache:%s:%d" % [stage_id, cache_seed]
	var relic = pick_relic(rpg, n, salt)
	var one = {"kind": "relic", "relic": relic} if relic != "" else {"kind": "ore", "ore": NO_RELIC_ORE + 10 * r}
	var two = {"kind": "rune", "rune": rune(n, rpg, salt, 0, 1)}
	var items = []
	_add_item(items, str(RpgWorld.REGION_ITEMS[r - 1]), 3)
	_add_item(items, "protein_shake" if n < 40.0 else "mega_shake", 2)
	return [one, two, {"kind": "items", "items": items}]


## What a region's star chest holds at 8, 16 or 24 stars: {"ore", "items",
## "runes", "relic", "scroll"} ({} for an unknown region or number). `rpg` is
## read for a relic the player does not have and for a fresh rune.
static func star_chest(region_id: String, threshold: int, chest_seed: int, rpg: Dictionary = {}) -> Dictionary:
	var reg = RpgWorld.region(region_id)
	if reg == null or not RpgDefs.STAR_CHESTS.has(threshold):
		return {}
	var r = int(reg.r)
	var n = 10.0 * float(r - 1) + 5.0
	var salt = "stars:%s:%d:%d" % [region_id, threshold, chest_seed]
	var out = {"ore": 0, "items": [], "runes": [], "relic": "", "scroll": ""}
	if threshold == int(RpgDefs.STAR_CHESTS[0]):
		out["ore"] = 40 + 20 * r
		_add_item(out.items, str(RpgWorld.REGION_ITEMS[r - 1]), 2)
		_add_item(out.items, "protein_shake", 1)
	elif threshold == int(RpgDefs.STAR_CHESTS[1]):
		var scrolls = RpgMoves.scrolls()
		var at = 2 * (r - 1) + 1
		out["scroll"] = str(scrolls[at].id) if at < scrolls.size() else ""
		out["ore"] = 60 + 25 * r
	else:
		out["ore"] = 100 + 40 * r
		out["relic"] = pick_relic(rpg, n + 30.0, salt)
		out.runes.append(rune(n, rpg, salt, 0, 1))
		if str(out.relic) == "":
			out["ore"] = int(out.ore) + NO_RELIC_ORE
	return out


## What a region's dare chest holds (every dare of the region won): ore, a rune a step above the region's own,
## and a stack of the region's belt item.
static func dare_chest(region_id: String, chest_seed: int, rpg: Dictionary = {}) -> Dictionary:
	var reg = RpgWorld.region(region_id)
	if reg == null:
		return {}
	var r = int(reg.r)
	var n = 10.0 * float(r - 1) + 15.0
	var salt = "dares:%s:%d" % [region_id, chest_seed]
	var out = {"ore": 150 + 50 * r, "items": [], "runes": [], "relic": "", "scroll": ""}
	_add_item(out.items, str(RpgWorld.REGION_ITEMS[r - 1]), 3)
	out.runes.append(rune(n, rpg, salt, 0, 1))
	return out


## The three prizes of a day's hunt (pick one after the first win): ore, a
## stack of one belt item, a rune.
static func hunt_prizes(date: String, n: float, rpg: Dictionary) -> Array:
	var st = Rng.make_rng("hunt-prize:" + date)
	var drop = item_drop(st.next_int(1 << 30), n)
	return [{"kind": "ore", "ore": RpgDefs.foe_ore(n, "boss")},
		{"kind": "items", "items": [{"id": str(drop.id), "n": 3}]},
		{"kind": "rune", "rune": rune(n, rpg, "hunt:" + date)}]
