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
		"chests": {}, "hunt": {"date": "", "won": false}, "rival": {"week": "", "won": false},
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
	var chests = raw.get("chests")
	if chests is Dictionary:
		for k in chests:
			if str(k) != "" and _int(chests[k]) > 0:
				out.chests[str(k)] = _int(chests[k])
	var hunt = raw.get("hunt")
	if hunt is Dictionary:
		out.hunt = {"date": str(hunt.get("date", "")) if hunt.get("date") is String else "", "won": hunt.get("won") is bool and hunt.won}
	var rival = raw.get("rival")
	if rival is Dictionary:
		out.rival = {"week": str(rival.get("week", "")) if rival.get("week") is String else "", "won": rival.get("won") is bool and rival.won}
	var spire = raw.get("spire")
	if spire is Dictionary:
		out.spire = {"best": maxi(0, _int(spire.get("best")))}
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
