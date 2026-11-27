class_name RpgSave
extends RefCounted
## The Realm's stored progress, `saved.rpg` (RPG_PLAN.md 11.2), and every change
## to it as a pure function: a function takes the dictionary and returns the
## new one (never changing the one it was given), so the screens call
## `RpgUi.commit(RpgSave.something(RpgUi.save(), ...))`.
##
## Stored, not derived: battles are the player's own doing. Nothing in the
## rules engine reads it (Derive.derive is given an explicit input).
##
## Everything here must survive a JSON round trip: after a load whole numbers
## are ints and every key is a String.
##
## THE TRANSITIONS. Each is `static func x(rpg, ...) -> {"ok": bool, "why":
## String, "rpg": Dictionary}`: "rpg" is a changed COPY when it went through
## ("ok"), and the very dictionary that was given, untouched, when it did not
## ("why" then says why not, in plain words for the screen).
##   finish(rpg, what, stage, rewards, summary, today)     a battle is over (a loss only keeps what was learned)
##   take_cache(rpg, stage_id, option) · open_star_chest(rpg, region_id, threshold, contents)
##   take_hunt_prize(rpg, date, option) · claim_chest(rpg, chest)
##   learn(rpg, node_id, sheet, active_days) · reset_nodes(rpg)
##   set_build(rpg, index) · rename_build(rpg, index, name)
##   equip_move(rpg, slot, move_id) · equip_ult(rpg, move_id) · equip_passive(rpg, slot, id)
##   equip_gear(rpg, slot, item_id, owned_items = null) · equip_relic(rpg, slot, id)
##   equip_pet(rpg, pet_id, owned_pets = null) · set_belt(rpg, slot, item_id)
##   upgrade(rpg, item_id, rarity = "", owned_items = null) · socket(rpg, item_id, rune_id) · scrap_rune(rpg, rune_id)
##   buy_item(rpg, item_id, n)
## An id of "" empties a slot. Everything that is equipped goes into the build
## in use. What the player owns of the main game's gear and companions is not
## in `saved.rpg`: the caller hands over state.items / state.pets where a
## function takes them (left out, ownership is not looked at).
##
## No key was added to the stored dictionary for any of this. Two marks sit in
## keys that were there: the day's hunt prize, once picked, is
## caches["hunt:<date>"], and a rune's id is made unique from the runes
## already there (RpgLoot.rune_seed), so no counter is stored.

const BUILD_NAMES = ["Build 1", "Build 2", "Build 3"]
const MOVE_SLOTS = 5
const PASSIVE_SLOTS = 3
const RELIC_SLOTS = 3
const BELT_SLOTS = 3
const START_MOVES = ["shove", "yank", "stomp", "deep_breath", ""]


static func empty_build(build_name: String) -> Dictionary:
	return {"name": build_name, "moves": START_MOVES.duplicate(), "ult": "", "passives": ["", "", ""],
		"gear": {}, "relics": ["", "", ""], "pet": "", "belt": ["", "", ""]}


static func empty() -> Dictionary:
	return {
		"v": 1, "opened": false,
		"xp": 0, "ore": 0,
		"nodes": {},
		"builds": [empty_build(BUILD_NAMES[0]), empty_build(BUILD_NAMES[1]), empty_build(BUILD_NAMES[2])],
		"build": 0,
		"plus": {}, "runes": [], "socket": {},
		"relics": {}, "scrolls": {}, "items": {},
		"stages": {}, "starChests": {}, "caches": {},
		"seen": {},
		"statsSeen": {},
		"feats": {},
		"hints": {},
		"prefs": {},
		"tally": {},
		"mastery": {},
		"chests": {}, "hunt": {"date": "", "won": false}, "rival": {"week": "", "won": false},
		"gauntlet": {"week": "", "won": false},
		"spire": {"best": 0},
	}


static func _int(v, fallback: int = 0) -> int:
	return int(v) if (v is int or v is float) else fallback


static func _num(v, fallback: float = 0.0) -> float:
	return float(v) if (v is int or v is float) else fallback


## A list of exactly `count` ids ("" where there is none).
static func _ids(raw, count: int) -> Array:
	var out = []
	for i in range(count):
		var v = raw[i] if (raw is Array and i < raw.size()) else ""
		out.append(str(v) if v is String else "")
	return out


## {id: true} for every truthy entry.
static func _flags(raw) -> Dictionary:
	var out = {}
	if raw is Dictionary:
		for k in raw:
			if raw[k] is bool and raw[k] and str(k) != "":
				out[str(k)] = true
	return out


static func _build(raw, build_name: String) -> Dictionary:
	var b = empty_build(build_name)
	if not (raw is Dictionary):
		return b
	var n = raw.get("name")
	if n is String and n.strip_edges() != "":
		b.name = n.strip_edges().left(24)
	b.moves = _ids(raw.get("moves"), MOVE_SLOTS)
	b.ult = str(raw.get("ult")) if raw.get("ult") is String else ""
	b.passives = _ids(raw.get("passives"), PASSIVE_SLOTS)
	b.relics = _ids(raw.get("relics"), RELIC_SLOTS)
	b.belt = _ids(raw.get("belt"), BELT_SLOTS)
	b.pet = str(raw.get("pet")) if raw.get("pet") is String else ""
	var gear = raw.get("gear")
	if gear is Dictionary:
		for slot in TT.SLOTS:
			if gear.get(slot) is String and gear[slot] != "":
				b.gear[slot] = gear[slot]
	return b


## The stored dictionary, cleaned: unknown keys dropped, every key present with
## a value of the right kind. Anything that is not a dictionary gives `empty()`.
static func parse(raw) -> Dictionary:
	var out = empty()
	if not (raw is Dictionary):
		return out
	out.opened = bool(raw.get("opened", false)) if raw.get("opened") is bool else false
	out.xp = maxi(0, _int(raw.get("xp")))
	out.ore = maxi(0, _int(raw.get("ore")))
	out.nodes = _flags(raw.get("nodes"))
	var builds = raw.get("builds")
	for i in range(3):
		out.builds[i] = _build(builds[i] if (builds is Array and i < builds.size()) else null, BUILD_NAMES[i])
	out.build = clampi(_int(raw.get("build")), 0, 2)
	var plus = raw.get("plus")
	if plus is Dictionary:
		for k in plus:
			var p = clampi(_int(plus[k]), 0, RpgDefs.PLUS_MAX)
			if p > 0 and str(k) != "":
				out.plus[str(k)] = p
	var runes = raw.get("runes")
	if runes is Array:
		for r in runes:
			if r is Dictionary and r.get("id") is String and r.id != "" and r.get("k") is String:
				out.runes.append({"id": r.id, "k": r.k, "v": _num(r.get("v")),
					"rarity": str(r.get("rarity")) if RpgDefs.RARITIES.has(r.get("rarity")) else "common"})
	var socket = raw.get("socket")
	if socket is Dictionary:
		var have = {}
		for r in out.runes:
			have[r.id] = true
		for k in socket:
			if socket[k] is String and have.has(socket[k]) and str(k) != "":
				out.socket[str(k)] = socket[k]
	out.relics = _flags(raw.get("relics"))
	out.scrolls = _flags(raw.get("scrolls"))
	var items = raw.get("items")
	if items is Dictionary:
		for k in items:
			var c = _int(items[k])
			if c > 0 and str(k) != "":
				out.items[str(k)] = c
	var stages = raw.get("stages")
	if stages is Dictionary:
		for k in stages:
			var s = stages[k]
			if not (s is Dictionary) or str(k) == "":
				continue
			var stars = s.get("stars")
			var three = []
			for i in range(3):
				three.append(bool(stars[i]) if (stars is Array and i < stars.size() and stars[i] is bool) else false)
			out.stages[str(k)] = {"stars": three, "wins": maxi(0, _int(s.get("wins"))), "best": maxi(0, _int(s.get("best")))}
			if _int(s.get("dares")) > 0:
				out.stages[str(k)]["dares"] = _int(s.get("dares"))
	out.starChests = _flags(raw.get("starChests"))
	out.caches = _flags(raw.get("caches"))
	var seen = raw.get("seen")
	if seen is Dictionary:
		for k in seen:
			if seen[k] is Array and str(k) != "":
				var schools = []
				for sc in seen[k]:
					if sc is String and RpgDefs.ATTACK_SCHOOLS.has(sc) and not schools.has(sc):
						schools.append(sc)
				out.seen[str(k)] = schools
	var stats_seen = raw.get("statsSeen")
	if stats_seen is Dictionary:
		for k in stats_seen:
			if RpgDefs.STATS.has(str(k)) and _int(stats_seen[k]) > 0:
				out.statsSeen[str(k)] = clampi(_int(stats_seen[k]), 1, 99)
	out.hints = _flags(raw.get("hints"))
	var tally = raw.get("tally")
	if tally is Dictionary:
		for k in TALLY + TALLY_BEST:
			if _int(tally.get(k)) > 0:
				out.tally[k] = _int(tally.get(k))
	var mastery = raw.get("mastery")
	if mastery is Dictionary:
		for k in mastery:
			if _int(mastery[k]) > 0 and RpgMoves.by_id(str(k)) != null:
				out.mastery[str(k)] = mini(_int(mastery[k]), MASTERY_MOST)
	var prefs = raw.get("prefs")
	if prefs is Dictionary:
		for k in PREFS:
			if prefs.get(k) is bool and prefs[k]:
				out.prefs[k] = true
	var feats = raw.get("feats")
	if feats is Dictionary:
		for k in feats:
			var lad = RpgFeats.ladder(str(k))
			if lad != null and _int(feats[k]) > 0:
				out.feats[str(k)] = clampi(_int(feats[k]), 1, lad[4].size())
	var chests = raw.get("chests")
	if chests is Dictionary:
		for k in chests:
			if str(k) != "" and _int(chests[k]) > 0:
				out.chests[str(k)] = _int(chests[k])
	var hunt = raw.get("hunt")
	if hunt is Dictionary:
		out.hunt = {"date": str(hunt.get("date", "")) if hunt.get("date") is String else "", "won": hunt.get("won") is bool and hunt.won}
		if _int(hunt.get("streak")) > 0:
			out.hunt["streak"] = _int(hunt.get("streak"))
		if _int(hunt.get("best")) > 0:
			out.hunt["best"] = _int(hunt.get("best"))
	var rival = raw.get("rival")
	if rival is Dictionary:
		out.rival = {"week": str(rival.get("week", "")) if rival.get("week") is String else "", "won": rival.get("won") is bool and rival.won}
	var gauntlet = raw.get("gauntlet")
	if gauntlet is Dictionary:
		out.gauntlet = {"week": str(gauntlet.get("week", "")) if gauntlet.get("week") is String else "", "won": gauntlet.get("won") is bool and gauntlet.won}
	var spire = raw.get("spire")
	if spire is Dictionary:
		out.spire = {"best": maxi(0, _int(spire.get("best")))}
		var held = RpgWorld.blessings_held({"spire": spire})
		if not held.is_empty():
			out.spire["bless"] = held
	return out


## A deep copy to change (every transition starts with this).
static func copy(rpg: Dictionary) -> Dictionary:
	return rpg.duplicate(true)


## The build in use.
static func build_of(rpg: Dictionary) -> Dictionary:
	return rpg.builds[clampi(int(rpg.get("build", 0)), 0, 2)]


## The end of the first visit: the Armory's loadout and companion go into the
## three builds (where a build has none of its own yet) and `opened` is set.
## `loadout` = {slot: item id or null}; `active_pet` = a pet id or null.
static func first_open(rpg: Dictionary, loadout: Dictionary, active_pet) -> Dictionary:
	var out = copy(rpg)
	for b in out.builds:
		if b.gear.is_empty():
			for slot in TT.SLOTS:
				var id = loadout.get(slot)
				if id is String and id != "":
					b.gear[slot] = id
		if str(b.pet) == "" and active_pet is String and active_pet != "":
			b.pet = active_pet
	out.opened = true
	return out


# =============================================================================
# The transitions
# =============================================================================

## The stats as the Realm last showed them (whole points: saved.rpg.statsSeen), brought up to `values`
## ({stat id: whole points}). Returns {"ok", "why", "rpg", "changed": bool, "rose": [{"id", "from", "to"}]}:
## `rose` names the stats that have reached a new whole point since then, and is empty the first time (there
## is nothing to compare with yet). A stat never falls, and neither does what is remembered of it.
static func note_stats(rpg: Dictionary, values: Dictionary) -> Dictionary:
	var out = copy(rpg)
	if not (out.get("statsSeen") is Dictionary):
		out["statsSeen"] = {}
	var first = out.statsSeen.is_empty()
	var rose = []
	var changed = false
	for id in RpgDefs.STATS:
		if not values.has(id):
			continue
		var v = clampi(int(values[id]), 1, 99)
		var was = int(out.statsSeen.get(id, 0))
		if v > was:
			if not first and was > 0:
				rose.append({"id": str(id), "from": was, "to": v})
			out.statsSeen[id] = v
			changed = true
	return {"ok": true, "why": "", "rpg": out, "changed": changed, "rose": rose}


## The most of one belt item a save holds.
const ITEM_CAP = 999


static func _yes(out: Dictionary) -> Dictionary:
	return {"ok": true, "why": "", "rpg": out}


static func _no(rpg: Dictionary, why: String) -> Dictionary:
	return {"ok": false, "why": why, "rpg": rpg}


## The fighter level of a saved Realm.
static func level_of(rpg: Dictionary) -> int:
	return int(RpgDefs.level_of(int(rpg.get("xp", 0))).lvl)


static func _give_items(out: Dictionary, items) -> void:
	if not (items is Array):
		return
	for it in items:
		if not (it is Dictionary):
			continue
		var id = str(it.get("id", ""))
		var n = _int(it.get("n"))
		if n > 0 and RpgItems.by_id(id) != null:
			out.items[id] = mini(ITEM_CAP, int(out.items.get(id, 0)) + n)


## A rune goes into the save under an id no other rune there has.
static func _give_rune(out: Dictionary, rune) -> void:
	if not (rune is Dictionary) or not (rune.get("k") is String):
		return
	var id = str(rune.get("id", ""))
	var taken = {}
	for r in out.runes:
		taken[str(r.id)] = true
	if id == "" or taken.has(id):
		var k = 0
		id = "rn%x" % RpgLoot.rune_seed(out, "again", k)
		while taken.has(id):
			k += 1
			id = "rn%x" % RpgLoot.rune_seed(out, "again", k)
	out.runes.append({"id": id, "k": str(rune.k), "v": _num(rune.get("v")),
		"rarity": str(rune.get("rarity")) if RpgDefs.RARITIES.has(rune.get("rarity")) else "common"})


## A relic found: new, it is the player's; one they have becomes ore.
static func _give_relic(out: Dictionary, id: String) -> void:
	if id == "" or RpgRelics.by_id(id) == null:
		return
	if bool(out.relics.get(id, false)):
		out.ore = int(out.ore) + RpgRelics.dup_ore(id)
	else:
		out.relics[id] = true


## Everything a reward holds goes into the save: {"xp", "ore", "items",
## "runes", "relic", "scroll"} (any of them may be missing).
static func _give(out: Dictionary, pack: Dictionary) -> void:
	out.xp = int(out.xp) + maxi(0, _int(pack.get("xp")))
	out.ore = int(out.ore) + maxi(0, _int(pack.get("ore")))
	_give_items(out, pack.get("items"))
	if pack.get("runes") is Array:
		for r in pack.runes:
			_give_rune(out, r)
	if pack.get("relic") is String:
		_give_relic(out, pack.relic)
	var scroll = pack.get("scroll")
	if scroll is String and scroll != "" and RpgMoves.by_id(scroll) != null:
		out.scrolls[scroll] = true


## One find of a cache or one prize of a hunt (RpgLoot's options) as a reward, or null when it is none.
static func _option_pack(option) -> Variant:
	if not (option is Dictionary):
		return null
	match str(option.get("kind", "")):
		"relic":
			return {"relic": str(option.get("relic", ""))} if RpgRelics.by_id(str(option.get("relic", ""))) != null else null
		"rune":
			return {"runes": [option.rune]} if (option.get("rune") is Dictionary and option.rune.get("k") is String) else null
		"items":
			return {"items": option.items} if (option.get("items") is Array and not option.items.is_empty()) else null
		"ore":
			return {"ore": _int(option.get("ore"))} if _int(option.get("ore")) > 0 else null
	return null


static func _merge_seen(out: Dictionary, learned) -> void:
	if not (learned is Dictionary):
		return
	for k in learned:
		if not (learned[k] is Array) or str(k) == "":
			continue
		var have = out.seen.get(str(k), [])
		for sc in learned[k]:
			if sc is String and RpgDefs.ATTACK_SCHOOLS.has(sc) and not have.has(sc):
				have.append(sc)
		out.seen[str(k)] = have


## The mark of the day's hunt prize (older days' marks are dropped).
static func _mark_hunt_prize(out: Dictionary, date: String) -> void:
	for k in out.caches.keys():
		if str(k).begins_with("hunt:"):
			out.caches.erase(k)
	out.caches["hunt:" + date] = true


## A battle is over. `what` = {"kind", "id"} as the battle was started with,
## `stage` = the stage it was (RpgWorld), `rewards` = RpgLoot.rewards for it,
## `summary` = RpgBattle.summary, `today` = the date (a hunt without a date of
## its own is today's).
## A LOSS (or a flight) keeps the weaknesses that were learned and nothing
## else: no item is used up, nothing is marked.
## A WIN: a road or echo stage gets its stars (never taken away again), one
## more win and the fewest hero turns as its best; the hunt, the rival and the
## Spire get their marks; the rewards go in (a relic the player already has
## becomes ore); what was used from the belt is taken from the stock.
## `rewards.prize` may hold the hunt prize picked with the win (else
## take_hunt_prize, later).
static func finish(rpg: Dictionary, what: Dictionary, stage: Dictionary, rewards: Dictionary, summary: Dictionary, today: String) -> Dictionary:
	var kind = str(stage.get("kind", ""))
	var id = str(stage.get("id", ""))
	if id == "" or kind == "" or kind == "cache":
		return _no(rpg, "There was no battle here.")
	if kind == "practice":
		return _no(rpg, "Practice is for nothing: nothing is kept.")
	if str(what.get("id", id)) != id:
		return _no(rpg, "That battle was for another stage.")
	var out = copy(rpg)
	_merge_seen(out, summary.get("learned"))
	# what was done in the fight counts whether it was won or lost (the feats read it)
	if not (out.get("tally") is Dictionary):
		out["tally"] = {}
	for k in TALLY:
		var more = maxi(0, _int(summary.get(k)))
		if more > 0:
			out.tally[k] = _int(out.tally.get(k)) + more
	for k in TALLY_BEST:
		var best_now = maxi(0, _int(summary.get(k)))
		if best_now > _int(out.tally.get(k)):
			out.tally[k] = best_now
	# ... and every use of a move, for its mastery (RpgDefs.MASTERY_AT)
	if not (out.get("mastery") is Dictionary):
		out["mastery"] = {}
	var uses = summary.get("moves")
	if uses is Dictionary:
		for k in uses:
			var n = clampi(_int(uses[k]), 0, 99)
			var used_row = RpgMoves.by_id(str(k))
			# (an ultimate has no mastery: its uses are not counted)
			if n > 0 and used_row != null and not bool(used_row.get("ult", false)):
				out.mastery[str(k)] = mini(_int(out.mastery.get(str(k))) + n, MASTERY_MOST)
	if not bool(summary.get("win", false)):
		return _yes(out)
	match kind:
		"battle", "elite", "boss":
			if not RpgWorld.is_open(rpg, id):
				return _no(rpg, "That stage is not open yet.")
			var rec = out.stages.get(id, {"stars": [false, false, false], "wins": 0, "best": 0})
			var got = RpgWorld.stars(stage, summary)
			var kept = []
			for i in range(3):
				kept.append(bool(got[i]) or (rec.stars is Array and i < rec.stars.size() and bool(rec.stars[i])))
			var turns = maxi(1, _int(summary.get("turns")))
			var best = _int(rec.get("best"))
			out.stages[id] = {"stars": kept, "wins": _int(rec.get("wins")) + 1, "best": turns if best <= 0 else mini(best, turns)}
			if _int(rec.get("dares")) > 0:
				out.stages[id]["dares"] = _int(rec.get("dares"))
		"dare":
			# a dare won: counted on the stage it is a dare of (RpgWorld.dared)
			var of = str(stage.get("of", ""))
			if not RpgWorld.done(rpg, of) or not (out.stages.get(of) is Dictionary):
				return _no(rpg, "A dare is for a stage already won.")
			out.stages[of]["dares"] = _int(out.stages[of].get("dares")) + 1
		"hunt":
			var date = str(stage.get("date", today))
			var streak = RpgWorld.hunt_streak_next(rpg, date)
			var old_hunt = rpg.get("hunt", {})
			out.hunt = {"date": date, "won": true, "streak": streak, "best": maxi(streak, _int(old_hunt.get("best")) if old_hunt is Dictionary else 0)}
			if rewards.get("prize") is Dictionary and RpgLoot.hunt_prize_left(out, date):
				var prize = _option_pack(rewards.prize)
				if prize != null:
					_give(out, prize)
					_mark_hunt_prize(out, date)
		"rival":
			out.rival = {"week": str(stage.get("week", "")), "won": true}
		"gauntlet":
			if not RpgWorld.gauntlet_open(rpg):
				return _no(rpg, "The gauntlet is not open yet.")
			out["gauntlet"] = {"week": str(stage.get("week", "")), "won": true}
		"spire":
			var f = _int(stage.get("floor"))
			var top = _int(out.spire.get("best"))
			if not RpgWorld.spire_open(rpg):
				return _no(rpg, "The Spire is not open yet.")
			if f < 1 or f > top + 1:
				return _no(rpg, "The Spire is climbed one floor at a time.")
			var kept_bless = RpgWorld.blessings_held(rpg)
			out.spire = {"best": maxi(top, f)}
			if not kept_bless.is_empty():
				out.spire["bless"] = kept_bless
		_:
			return _no(rpg, "There was no battle here.")
	_give(out, rewards)
	var used = summary.get("used")
	if used is Dictionary:
		for k in used:
			var left = int(out.items.get(str(k), 0)) - maxi(0, _int(used[k]))
			if left > 0:
				out.items[str(k)] = left
			else:
				out.items.erase(str(k))
	return _yes(out)


## One of a cache's three finds is taken (`option` = one of RpgLoot.cache).
## A cache is taken once, and the stage after it opens.
static func take_cache(rpg: Dictionary, stage_id: String, option) -> Dictionary:
	var stage = RpgWorld.stage(stage_id)
	if not (stage is Dictionary) or str(stage.kind) != "cache":
		return _no(rpg, "There is no cache here.")
	if not RpgWorld.is_open(rpg, stage_id):
		return _no(rpg, "You have not reached this cache yet.")
	if bool(rpg.get("caches", {}).get(stage_id, false)):
		return _no(rpg, "This cache has been taken already.")
	var pack = _option_pack(option)
	if pack == null:
		return _no(rpg, "Pick one of the three finds.")
	var out = copy(rpg)
	_give(out, pack)
	out.caches[stage_id] = true
	return _yes(out)


## A region's star chest is opened (`contents` = RpgLoot.star_chest).
static func open_star_chest(rpg: Dictionary, region_id: String, threshold: int, contents: Dictionary) -> Dictionary:
	if RpgWorld.region(region_id) == null or not RpgDefs.STAR_CHESTS.has(threshold):
		return _no(rpg, "There is no such chest.")
	var key = "%s:%d" % [region_id, threshold]
	if bool(rpg.get("starChests", {}).get(key, false)):
		return _no(rpg, "This chest is open already.")
	var have = RpgWorld.star_count(rpg, region_id)
	if have < threshold:
		return _no(rpg, "Needs %d stars here (you have %d)." % [threshold, have])
	var out = copy(rpg)
	_give(out, contents)
	out.starChests[key] = true
	return _yes(out)


## A blessing of the Spire is taken: one of the three on offer (RpgWorld.blessing_options), while one is owed.
static func take_blessing(rpg: Dictionary, id: String) -> Dictionary:
	if not RpgDefs.BLESSINGS.has(id):
		return _no(rpg, "There is no such blessing.")
	if RpgWorld.blessings_owed(rpg) <= 0:
		return _no(rpg, "Climb %d more floors of the Spire for the next blessing." % RpgDefs.BLESSING_EVERY)
	if not RpgWorld.blessing_options(rpg).has(id):
		return _no(rpg, "That one is not on offer now.")
	var out = copy(rpg)
	var held = RpgWorld.blessings_held(rpg)
	held[id] = int(held.get(id, 0)) + 1
	out.spire["bless"] = held
	return _yes(out)


## A region's dare chest is opened (`contents` = RpgLoot.dare_chest): once, when every dare of the region is
## won. It is kept among the star chests, under "<region>:dare".
static func open_dare_chest(rpg: Dictionary, region_id: String, contents: Dictionary) -> Dictionary:
	if RpgWorld.region(region_id) == null:
		return _no(rpg, "There is no such chest.")
	var key = "%s:dare" % region_id
	if bool(rpg.get("starChests", {}).get(key, false)):
		return _no(rpg, "This chest is open already.")
	var prog = RpgWorld.dare_progress(rpg, region_id)
	if int(prog.of) <= 0 or int(prog.won) < int(prog.of):
		return _no(rpg, "Win every dare here first (%d of %d)." % [int(prog.won), int(prog.of)])
	var out = copy(rpg)
	_give(out, contents)
	out.starChests[key] = true
	return _yes(out)


## The prize of a day's hunt is picked (`option` = one of the hunt's
## "prizes"): once a day, after a win that day.
static func take_hunt_prize(rpg: Dictionary, date: String, option) -> Dictionary:
	var h = rpg.get("hunt", {})
	if date == "" or str(h.get("date", "")) != date or not bool(h.get("won", false)):
		return _no(rpg, "Win today's hunt first.")
	if not RpgLoot.hunt_prize_left(rpg, date):
		return _no(rpg, "Today's prize has been picked already.")
	var pack = _option_pack(option)
	if pack == null:
		return _no(rpg, "Pick one of the three prizes.")
	var out = copy(rpg)
	_give(out, pack)
	_mark_hunt_prize(out, date)
	return _yes(out)


## A training chest is opened (`chest` = RpgBoosts.chest of today or
## yesterday). Never opened: all of it, and a rune from a gold one. Opened
## when the day held less: the ore of what came since (RpgBoosts.chest_pay).
static func claim_chest(rpg: Dictionary, chest) -> Dictionary:
	if not (chest is Dictionary) or str(chest.get("date", "")) == "":
		return _no(rpg, "There is no chest to open.")
	var pay = RpgBoosts.chest_pay(chest, rpg)
	if not bool(pay.first) and int(pay.ore) <= 0:
		return _no(rpg, "This chest is open already.")
	var date = str(pay.date)
	var out = copy(rpg)
	_give(out, {"ore": int(pay.ore), "items": pay.items})
	if bool(pay.rune):
		_give_rune(out, RpgLoot.chest_rune(out, date))
	# only today's and yesterday's can be opened: marks of long ago are of no use
	var old = Dates.add_days(date, -7)
	for k in out.chests.keys():
		if str(k) < old:
			out.chests.erase(k)
	out.chests[date] = int(pay.kinds)
	return _yes(out)


## Move mastery: saved.rpg.mastery = {move id: how often it was used in fights}, at most this.
const MASTERY_MOST = 9999

## Deeds counted over every fight (saved.rpg.tally = {key: how many}; a key is only there once it is above 0):
## perfect guards and guard breaks, from the fight's summary.
const TALLY = ["perfect", "breaks"]
## ... and records kept as the most ever in one fight: the hardest single hit.
const TALLY_BEST = ["best_hit"]

## How the player likes a fight (saved.rpg.prefs; each is kept only while it is on): "auto" (the hero plays by
## himself), "fast" (x2), "light" (no particle effects, no flashes, no shakes: for a phone that stutters).
const PREFS = ["auto", "fast", "light"]

static func set_pref(rpg: Dictionary, key: String, on: bool) -> Dictionary:
	if not PREFS.has(key):
		return _no(rpg, "No such preference.")
	var out = copy(rpg)
	if not (out.get("prefs") is Dictionary):
		out["prefs"] = {}
	var was = bool(out.prefs.get(key, false))
	if on:
		out.prefs[key] = true
	else:
		out.prefs.erase(key)
	var res = _yes(out)
	res["changed"] = was != on
	return res


## A hint of a fight was given (BattleView.HINTS): it is not given again. {"ok", "why", "rpg", "changed"}.
static func note_hint(rpg: Dictionary, id: String) -> Dictionary:
	var out = copy(rpg)
	if not (out.get("hints") is Dictionary):
		out["hints"] = {}
	var fresh = id != "" and not bool(out.hints.get(id, false))
	if fresh:
		out.hints[id] = true
	var res = _yes(out)
	res["changed"] = fresh
	return res


## The next step of a feat's ladder is claimed: its ore is paid, once. `sheet` is the stat sheet (the days
## trained and Might are counted from the log). Returns also "ore" (what was paid) and "name" (the step's).
static func claim_feat(rpg: Dictionary, ladder_id: String, sheet = null) -> Dictionary:
	if RpgFeats.ladder(ladder_id) == null:
		return _no(rpg, "There is no such feat.")
	for r in RpgFeats.rows(rpg, sheet):
		if str(r.id) != ladder_id:
			continue
		if bool(r.done):
			return _no(rpg, "Every step of this feat is claimed.")
		if not bool(r.ready):
			return _no(rpg, "Not yet: %d of %d." % [int(r.have), int(r.need)])
		var out = copy(rpg)
		if not (out.get("feats") is Dictionary):
			out["feats"] = {}
		out.feats[ladder_id] = int(r.step)
		_give(out, {"ore": int(r.ore)})
		var res = _yes(out)
		res["ore"] = int(r.ore)
		res["name"] = str(r.name)
		return res
	return _no(rpg, "There is no such feat.")


## A skill is learned (RpgSkills.can_learn says whether it may be, and why not).
static func learn(rpg: Dictionary, node_id: String, sheet: Dictionary, active_days: int) -> Dictionary:
	var can = RpgSkills.can_learn(rpg, node_id, sheet, level_of(rpg), active_days)
	if not bool(can.ok):
		return _no(rpg, str(can.why))
	var out = copy(rpg)
	out.nodes[node_id] = true
	return _yes(out)


## Every skill is unlearned and every point comes back. Free, any time. The
## builds are left alone: a move no longer known is skipped until it is known again.
static func reset_nodes(rpg: Dictionary) -> Dictionary:
	var out = copy(rpg)
	out.nodes = {}
	return _yes(out)


## The build in use: 0, 1 or 2.
static func set_build(rpg: Dictionary, index: int) -> Dictionary:
	if index < 0 or index > 2:
		return _no(rpg, "There is no such build.")
	var out = copy(rpg)
	out.build = index
	return _yes(out)


## A build's name (at most 24 letters).
static func rename_build(rpg: Dictionary, index: int, build_name: String) -> Dictionary:
	if index < 0 or index > 2:
		return _no(rpg, "There is no such build.")
	var clean = build_name.strip_edges().left(24)
	if clean == "":
		return _no(rpg, "A build needs a name.")
	var out = copy(rpg)
	out.builds[index].name = clean
	return _yes(out)


## Puts an id into a slot of a list where an id sits once at most: when it is
## in another slot already, the two change places.
static func _place(list: Array, slot: int, id: String) -> void:
	var at = list.find(id) if id != "" else -1
	if at >= 0 and at != slot:
		list[at] = list[slot]
	list[slot] = id


## A move into one of the move slots (0..4; the fifth opens at fighter level
## 20). The move must be known: a starter, a learned node, a scroll found.
static func equip_move(rpg: Dictionary, slot: int, move_id: String) -> Dictionary:
	if slot < 0 or slot >= MOVE_SLOTS:
		return _no(rpg, "There is no such slot.")
	if slot >= RpgDefs.move_slots(level_of(rpg)):
		return _no(rpg, "The fifth move slot opens at fighter level %d." % RpgDefs.MOVE_SLOT_5_AT)
	if move_id != "":
		var mv = RpgMoves.by_id(move_id)
		if mv == null:
			return _no(rpg, "There is no such move.")
		if bool(mv.get("ult", false)):
			return _no(rpg, "An ultimate goes in the ultimate slot.")
		if not RpgSkills.known_moves(rpg).has(move_id):
			return _no(rpg, "You have not learned %s yet." % str(mv.name))
	var out = copy(rpg)
	_place(build_of(out).moves, slot, move_id)
	return _yes(out)


## The build's ultimate (one that is learned; "" = none).
static func equip_ult(rpg: Dictionary, move_id: String) -> Dictionary:
	if move_id != "":
		var mv = RpgMoves.by_id(move_id)
		if mv == null or not bool(mv.get("ult", false)):
			return _no(rpg, "That is not an ultimate.")
		if not RpgSkills.known_ults(rpg).has(move_id):
			return _no(rpg, "You have not learned %s yet." % str(mv.name))
	var out = copy(rpg)
	build_of(out).ult = move_id
	return _yes(out)


## A board passive into one of the three passive slots (they open at fighter level 3, 10 and 20).
static func equip_passive(rpg: Dictionary, slot: int, id: String) -> Dictionary:
	if slot < 0 or slot >= PASSIVE_SLOTS:
		return _no(rpg, "There is no such slot.")
	if slot >= RpgDefs.passive_slots(level_of(rpg)):
		return _no(rpg, "This passive slot opens at fighter level %d." % int(RpgDefs.PASSIVE_SLOTS_AT[slot]))
	if id != "":
		var row = RpgPassives.by_id(id)
		if row == null:
			return _no(rpg, "There is no such passive.")
		if not RpgSkills.known_passives(rpg).has(id):
			return _no(rpg, "You have not learned %s yet." % str(row.name))
	var out = copy(rpg)
	_place(build_of(out).passives, slot, id)
	return _yes(out)


## A piece of the game's gear onto its slot in the Realm's own kit.
## `owned_items` = state.items when the caller wants ownership checked.
static func equip_gear(rpg: Dictionary, slot: String, item_id: String, owned_items = null) -> Dictionary:
	if not TT.SLOTS.has(slot):
		return _no(rpg, "There is no such slot.")
	if item_id != "":
		var g = RpgGear.of(item_id)
		if g == null:
			return _no(rpg, "That is not gear.")
		if str(g.slot) != slot:
			return _no(rpg, "That does not go there.")
		if owned_items is Dictionary and not owned_items.has(item_id):
			return _no(rpg, "You do not own that yet.")
	var out = copy(rpg)
	if item_id == "":
		build_of(out).gear.erase(slot)
	else:
		build_of(out).gear[slot] = item_id
	return _yes(out)


## A relic into one of the three relic slots (the second opens at fighter level 8, the third at 30).
static func equip_relic(rpg: Dictionary, slot: int, id: String) -> Dictionary:
	if slot < 0 or slot >= RELIC_SLOTS:
		return _no(rpg, "There is no such slot.")
	if slot >= RpgDefs.relic_slots(level_of(rpg)):
		return _no(rpg, "This relic slot opens at fighter level %d." % int(RpgDefs.RELIC_SLOTS_AT[slot]))
	if id != "":
		if RpgRelics.by_id(id) == null:
			return _no(rpg, "There is no such relic.")
		if not bool(rpg.get("relics", {}).get(id, false)):
			return _no(rpg, "You have not found that relic yet.")
	var out = copy(rpg)
	_place(build_of(out).relics, slot, id)
	return _yes(out)


## The build's companion. `owned_pets` = state.pets when ownership is to be checked.
static func equip_pet(rpg: Dictionary, pet_id: String, owned_pets = null) -> Dictionary:
	if pet_id != "":
		if RpgPets.by_id(pet_id) == null:
			return _no(rpg, "There is no such companion.")
		if owned_pets is Dictionary and not owned_pets.has(pet_id):
			return _no(rpg, "That companion is not yours yet.")
	var out = copy(rpg)
	build_of(out).pet = pet_id
	return _yes(out)


## A belt item into one of the belt's slots (two; a third at fighter level
## 6). It may be one the player has run out of: the slot then shows none.
static func set_belt(rpg: Dictionary, slot: int, item_id: String) -> Dictionary:
	if slot < 0 or slot >= BELT_SLOTS:
		return _no(rpg, "There is no such slot.")
	if slot >= RpgDefs.belt_slots(level_of(rpg)):
		return _no(rpg, "The third belt slot opens at fighter level %d." % RpgDefs.BELT_SLOT_3_AT)
	if item_id != "" and RpgItems.by_id(item_id) == null:
		return _no(rpg, "There is no such item.")
	var out = copy(rpg)
	_place(build_of(out).belt, slot, item_id)
	return _yes(out)


## One more plus on a piece of gear, paid in ore (RpgDefs.plus_cost; to +10).
## `rarity` = the item's rarity when the caller has it at hand ("" = RpgGear's).
static func upgrade(rpg: Dictionary, item_id: String, rarity: String = "", owned_items = null) -> Dictionary:
	var g = RpgGear.of(item_id)
	if g == null:
		return _no(rpg, "That is not gear.")
	if owned_items is Dictionary and not owned_items.has(item_id):
		return _no(rpg, "You do not own that yet.")
	var cur = clampi(_int(rpg.get("plus", {}).get(item_id)), 0, RpgDefs.PLUS_MAX)
	if cur >= RpgDefs.PLUS_MAX:
		return _no(rpg, "It is at +%d already: that is as far as it goes." % RpgDefs.PLUS_MAX)
	var cost = RpgDefs.plus_cost(rarity if RpgDefs.RARITIES.has(rarity) else str(g.rarity), cur)
	var have = int(rpg.get("ore", 0))
	if have < cost:
		return _no(rpg, "Not enough ore (needs %d, you have %d)." % [cost, have])
	var out = copy(rpg)
	out.ore = have - cost
	out.plus[item_id] = cur + 1
	return _yes(out)


## A rune into a piece of gear ("" takes the item's rune out). An item holds
## one rune and a rune sits in one item: it moves, and what was there is free again.
static func socket(rpg: Dictionary, item_id: String, rune_id: String) -> Dictionary:
	if RpgGear.of(item_id) == null:
		return _no(rpg, "That is not gear.")
	if rune_id != "":
		var found = false
		for r in rpg.get("runes", []):
			if str(r.id) == rune_id:
				found = true
		if not found:
			return _no(rpg, "There is no such rune.")
	var out = copy(rpg)
	if rune_id == "":
		out.socket.erase(item_id)
		return _yes(out)
	for k in out.socket.keys():
		if str(out.socket[k]) == rune_id:
			out.socket.erase(k)
	out.socket[item_id] = rune_id
	return _yes(out)


## A rune is broken up for ore (RpgLoot.scrap_ore); it comes out of its item first.
static func scrap_rune(rpg: Dictionary, rune_id: String) -> Dictionary:
	var at = -1
	var runes = rpg.get("runes", [])
	for i in range(runes.size()):
		if str(runes[i].id) == rune_id:
			at = i
	if at < 0 or rune_id == "":
		return _no(rpg, "There is no such rune.")
	var out = copy(rpg)
	out.ore = int(out.ore) + RpgLoot.scrap_ore(out.runes[at])
	out.runes.remove_at(at)
	for k in out.socket.keys():
		if str(out.socket[k]) == rune_id:
			out.socket.erase(k)
	return _yes(out)


## `n` of a belt item from the camp shop, for ore.
static func buy_item(rpg: Dictionary, item_id: String, n: int = 1) -> Dictionary:
	var price = RpgItems.price(item_id)
	if price <= 0:
		return _no(rpg, "The camp shop does not sell that.")
	if n < 1:
		return _no(rpg, "Buy at least one.")
	var have_n = int(rpg.get("items", {}).get(item_id, 0))
	if have_n + n > ITEM_CAP:
		return _no(rpg, "You cannot carry that many.")
	var cost = price * n
	var have = int(rpg.get("ore", 0))
	if have < cost:
		return _no(rpg, "Not enough ore (needs %d, you have %d)." % [cost, have])
	var out = copy(rpg)
	out.ore = have - cost
	out.items[item_id] = have_n + n
	return _yes(out)
