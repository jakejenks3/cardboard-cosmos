extends SceneTree
## Unit test for every change to the Realm's stored progress (RPG_PLAN.md
## 11.2, 8.2, 9): game/rpg/rpg_save.gd (RpgSave). Every transition goes
## through, every refusal says why in words, nothing ever changes the
## dictionary it was given, what a transition writes survives a JSON round
## trip through `parse`, and a small campaign is played with the real engine:
## r1s1 to r1s5, the cache, a skill, an upgrade, a rune, the shop, a training
## chest. With the App autoload: a save holding that block survives
## App.parse_saved. Made-up saves, sheets and chests only.
##   godot --headless --path . --script res://tests/rpg_save_test.gd
## Prints RPG SAVE: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
## Transitions that changed what they were given, or answered in a wrong shape.
var broke = []

const DAY = "2031-03-04"


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


func same(a, b) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


## Runs one transition and holds it to the contract: {"ok", "why", "rpg"};
## the dictionary given is never changed; a refusal hands it back as it is,
## with words; a change comes back as another dictionary, with no words.
func run(label: String, rpg: Dictionary, fn: Callable) -> Dictionary:
	var before = JSON.stringify(rpg, "", true)
	var res = fn.call(rpg)
	if not (res is Dictionary and res.get("ok") is bool and res.get("why") is String and res.get("rpg") is Dictionary):
		broke.append(label + ": shape")
		return {"ok": false, "why": "", "rpg": rpg}
	if JSON.stringify(rpg, "", true) != before:
		broke.append(label + ": changed what it was given")
	if bool(res.ok) and (is_same(res.rpg, rpg) or str(res.why) != ""):
		broke.append(label + ": a change must be a copy, without a why")
	if not bool(res.ok) and (not is_same(res.rpg, rpg) or str(res.why).length() < 8):
		broke.append(label + ": a refusal hands back the same dictionary and says why")
	if not same(RpgSave.parse(TTUtil.normalize_json(JSON.parse_string(JSON.stringify(res.rpg)))), res.rpg):
		broke.append(label + ": lost in a JSON round trip")
	return res


func xp_for(level: int) -> int:
	var xp = 0
	for l in range(1, level):
		xp += RpgDefs.xp_to_next(l)
	return xp


func at_level(level: int) -> Dictionary:
	var rpg = RpgSave.empty()
	rpg.xp = xp_for(level)
	return rpg


func sheet_of(v: float) -> Dictionary:
	var st = {}
	for id in RpgDefs.STATS:
		st[id] = {"raw": v, "v": v}
	return {"stats": st, "might": v}


func summary(over: Dictionary = {}) -> Dictionary:
	var s = {"win": true, "turns": 5, "breaks": 1, "items": 0, "guards": 0, "schools": ["push"], "worst_share": 0.1, "hp_share": 0.9,
		"learned": {}, "used": {}, "reward": {"ore": 0.0, "xp": 0.0, "luck": 0.0}}
	for k in over:
		s[k] = over[k]
	return s


## The nth common piece of gear of a slot (the cheapest to upgrade).
func gear_of(slot: String, nth: int = 0) -> String:
	var found = 0
	for g in RpgGear.all():
		if str(g.slot) == slot and str(g.rarity) == "common":
			if found == nth:
				return str(g.id)
			found += 1
	return ""


func node_of(kind: String, tier: int, board: String = "") -> Dictionary:
	for n in RpgSkills.all():
		if str(n.kind) == kind and int(n.tier) == tier and (board == "" or str(n.board) == board):
			return n
	return {}


func _run() -> void:
	_finish()
	_finds()
	_skills_and_builds()
	_gear()
	_campaign()
	ok(broke.is_empty(), "no transition changes what it is given; a refusal hands it back with words; all of it survives JSON", broke)
	await _app()
	# --- the stats as the Realm last showed them --------------------------------------------------
	var n0 = RpgSave.note_stats(RpgSave.empty(), {"back": 39, "legs": 36, "core": 7})
	ok(bool(n0.changed) and n0.rose.is_empty() and n0.rpg.statsSeen == {"back": 39, "legs": 36, "core": 7}, "the first note of the stats: kept, nothing to announce", [n0.rose, n0.rpg.statsSeen])
	var n1 = RpgSave.note_stats(n0.rpg, {"back": 40, "legs": 36, "core": 9})
	ok(bool(n1.changed) and n1.rose == [{"id": "back", "from": 39, "to": 40}, {"id": "core", "from": 7, "to": 9}] and int(n1.rpg.statsSeen.back) == 40, "a stat that reached a new whole point is named once", n1.rose)
	var n2 = RpgSave.note_stats(n1.rpg, {"back": 40, "legs": 30, "core": 9})
	ok(not bool(n2.changed) and n2.rose.is_empty() and int(n2.rpg.statsSeen.legs) == 36, "nothing new: nothing changes, and what is remembered never falls", n2.rpg.statsSeen)
	ok(RpgSave.parse(JSON.parse_string(JSON.stringify(n1.rpg))).statsSeen == {"back": 40, "legs": 36, "core": 9} and RpgSave.parse({"statsSeen": {"nope": 5, "back": "x", "legs": 250}}).statsSeen == {"legs": 99}, "it survives the save file; junk in it does not", RpgSave.parse({"statsSeen": {"nope": 5, "back": "x", "legs": 250}}).statsSeen)
	# --- the hints a fight has given ---------------------------------------------------------------
	var h1 = RpgSave.note_hint(RpgSave.empty(), "charge")
	var h2 = RpgSave.note_hint(h1.rpg, "charge")
	ok(bool(h1.changed) and h1.rpg.hints == {"charge": true} and not bool(h2.changed) and h2.rpg.hints == {"charge": true} and not bool(RpgSave.note_hint(h1.rpg, "").changed), "a hint given is kept, once", [h1.rpg.hints, h2.changed])
	ok(RpgSave.parse(JSON.parse_string(JSON.stringify(h1.rpg))).hints == {"charge": true} and RpgSave.parse({"hints": {"a": true, "b": false, "c": 3}}).hints == {"a": true}, "and survives the save file", RpgSave.parse({"hints": {"a": true, "b": false, "c": 3}}).hints)
	# --- how the player likes a fight ---------------------------------------------------------------
	var p1 = RpgSave.set_pref(RpgSave.empty(), "light", true)
	var p2 = RpgSave.set_pref(p1.rpg, "light", true)
	var p3 = RpgSave.set_pref(p1.rpg, "light", false)
	ok(bool(p1.ok) and bool(p1.changed) and p1.rpg.prefs == {"light": true} and not bool(p2.changed) and bool(p3.changed) and p3.rpg.prefs == {} and not bool(RpgSave.set_pref(RpgSave.empty(), "nope", true).ok), "a preference is kept while it is on, and gone when it is off", [p1.rpg.prefs, p3.rpg.prefs])
	ok(RpgSave.parse({"prefs": {"auto": true, "fast": false, "light": 1, "x": true}}).prefs == {"auto": true}, "only the known ones survive the save file, and only as true", RpgSave.parse({"prefs": {"auto": true, "fast": false, "light": 1, "x": true}}).prefs)
	# --- deeds counted over every fight ----------------------------------------------------------------
	var t0 = RpgSave.first_open(RpgSave.empty(), {}, "")
	var st1 = RpgWorld.stage("r1s1")
	var lost = RpgSave.finish(t0, {"kind": "stage", "id": "r1s1"}, st1, {}, {"win": false, "perfect": 2, "breaks": 1}, "2026-01-05")
	var won2 = RpgSave.finish(lost.rpg, {"kind": "stage", "id": "r1s1"}, st1, {"xp": 5, "ore": 1}, {"win": true, "turns": 3, "perfect": 1, "breaks": 0}, "2026-01-05")
	ok(bool(lost.ok) and lost.rpg.tally == {"perfect": 2, "breaks": 1} and bool(won2.ok) and won2.rpg.tally == {"perfect": 3, "breaks": 1} and not t0.tally.has("perfect"), "perfect guards and breaks are counted over every fight, won or lost", [lost.rpg.get("tally"), won2.rpg.get("tally")])
	ok(RpgSave.parse({"tally": {"perfect": 4, "breaks": -2, "x": 9}}).tally == {"perfect": 4}, "only the known counts above nothing survive the save file", RpgSave.parse({"tally": {"perfect": 4, "breaks": -2, "x": 9}}).tally)
	# --- move mastery: uses are counted over every fight ---------------------------------------------------
	var m0 = RpgSave.first_open(RpgSave.empty(), {}, "")
	var ms1 = RpgWorld.stage("r1s1")
	var m1 = RpgSave.finish(m0, {"kind": "stage", "id": "r1s1"}, ms1, {}, {"win": false, "moves": {"stomp": 3, "nope": 5, "yank": 0}}, "2026-01-05")
	var m2 = RpgSave.finish(m1.rpg, {"kind": "stage", "id": "r1s1"}, ms1, {"xp": 5, "ore": 1}, {"win": true, "turns": 3, "moves": {"stomp": 6, "shove": 500}}, "2026-01-05")
	ok(m1.rpg.mastery == {"stomp": 3} and m2.rpg.mastery == {"stomp": 9, "shove": 99}, "the uses of a move add up over fights, won or lost; only real moves, at most 99 a fight", [m1.rpg.get("mastery"), m2.rpg.get("mastery")])
	ok(RpgSave.parse({"mastery": {"stomp": 12, "nope": 3, "yank": -1}}).mastery == {"stomp": 12}, "only real moves with a count survive the save file", RpgSave.parse({"mastery": {"stomp": 12, "nope": 3, "yank": -1}}).mastery)
	# --- the hardest hit is a record, not a sum ---------------------------------------------------------
	var b0 = RpgSave.first_open(RpgSave.empty(), {}, "")
	var bst = RpgWorld.stage("r1s1")
	var b1 = RpgSave.finish(b0, {"kind": "stage", "id": "r1s1"}, bst, {}, {"win": false, "best_hit": 40}, "2026-01-05")
	var b2 = RpgSave.finish(b1.rpg, {"kind": "stage", "id": "r1s1"}, bst, {}, {"win": false, "best_hit": 25}, "2026-01-05")
	var b3 = RpgSave.finish(b2.rpg, {"kind": "stage", "id": "r1s1"}, bst, {}, {"win": false, "best_hit": 90}, "2026-01-05")
	ok(int(b1.rpg.tally.best_hit) == 40 and int(b2.rpg.tally.best_hit) == 40 and int(b3.rpg.tally.best_hit) == 90 and int(RpgSave.parse(b3.rpg).tally.best_hit) == 90, "the hardest hit ever is kept as the most, never added up", [b1.rpg.tally, b2.rpg.tally, b3.rpg.tally])
	# --- an ultimate's uses are not counted for mastery ------------------------------------------------
	var ult_id = ""
	for um in RpgMoves.all():
		if bool(um.get("ult", false)) and ult_id == "":
			ult_id = str(um.id)
	var u1 = RpgSave.finish(RpgSave.first_open(RpgSave.empty(), {}, ""), {"kind": "stage", "id": "r1s1"}, RpgWorld.stage("r1s1"), {}, {"win": false, "moves": {ult_id: 4, "stomp": 2}}, "2026-01-05")
	ok(ult_id != "" and u1.rpg.mastery == {"stomp": 2}, "an ultimate has no mastery: only the moves are counted", u1.rpg.get("mastery"))
	print("RPG SAVE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# --- finish ----------------------------------------------------------------------

func _finish() -> void:
	var s1 = RpgWorld.stage("r1s1")
	var what = {"kind": "stage", "id": "r1s1"}
	var fresh = RpgSave.empty()
	fresh.items = {"protein_shake": 3, "chalk_ball": 1}
	var rw = RpgLoot.rewards(s1, summary(), fresh, 1, [], 4)
	var res = run("finish win", fresh, func(r): return RpgSave.finish(r, what, s1, rw, summary({"turns": 3, "learned": {"dust_bunny": ["push"]}, "used": {"protein_shake": 2, "chalk_ball": 1}}), DAY))
	var a = res.rpg
	ok(bool(res.ok) and a.stages["r1s1"] == {"stars": [true, true, true], "wins": 1, "best": 3} and int(a.xp) == int(rw.xp) and int(a.ore) == int(rw.ore), "a win: stars, one win, the turns as its best, XP and ore", a.stages)
	ok(a.seen == {"dust_bunny": ["push"]} and int(a.items.get("protein_shake", 0)) >= 1 and int(a.items.get("chalk_ball", 0)) == int(rw.items.any(func(it): return it.id == "chalk_ball")), "what was learned is kept; what the belt used is taken from the stock", [a.seen, a.items, rw.items])
	# again: stars are OR-ed, the best is the fewest turns
	var rw2 = RpgLoot.rewards(s1, summary(), a, 1, [], 5)
	var b = run("finish again", a, func(r): return RpgSave.finish(r, what, s1, rw2, summary({"turns": 9, "breaks": 0, "learned": {"dust_bunny": ["legs", "push"]}}), DAY)).rpg
	ok(b.stages["r1s1"] == {"stars": [true, true, true], "wins": 2, "best": 3} and b.seen["dust_bunny"] == ["push", "legs"] and int(b.xp) == int(a.xp) + int(rw2.xp), "a worse win: no star is lost, the best stays, one more win", b.stages)
	var c = run("finish better", b, func(r): return RpgSave.finish(r, what, s1, {}, summary({"turns": 3}), DAY)).rpg
	ok(int(c.stages["r1s1"].best) == 3 and int(c.stages["r1s1"].wins) == 3, "fewer turns: a new best")
	# a loss
	var lost = run("finish loss", fresh, func(r): return RpgSave.finish(r, what, s1, {"xp": 50, "ore": 50}, summary({"win": false, "learned": {"dust_bunny": ["legs"]}, "used": {"protein_shake": 3}}), DAY))
	ok(bool(lost.ok) and lost.rpg.seen == {"dust_bunny": ["legs"]} and lost.rpg.stages.is_empty() and int(lost.rpg.xp) == 0 and int(lost.rpg.ore) == 0 and int(lost.rpg.items.protein_shake) == 3, "a loss only keeps what was learned: no item is used up, nothing is paid", lost.rpg)
	# refusals
	ok(not bool(run("finish shut", fresh, func(r): return RpgSave.finish(r, {"kind": "stage", "id": "r1s3"}, RpgWorld.stage("r1s3"), {}, summary(), DAY)).ok), "a stage that is not open cannot be won")
	ok(not bool(run("finish cache", fresh, func(r): return RpgSave.finish(r, {"kind": "stage", "id": "r1s6"}, RpgWorld.stage("r1s6"), {}, summary(), DAY)).ok)
		and not bool(run("finish other", fresh, func(r): return RpgSave.finish(r, {"kind": "stage", "id": "r1s2"}, s1, {}, summary(), DAY)).ok)
		and not bool(run("finish none", fresh, func(r): return RpgSave.finish(r, {}, {}, {}, summary(), DAY)).ok), "nor a cache, a stage that is not the battle's, or nothing at all")
	# the loot goes in: relic, duplicate, scroll, runes, items
	var pack = {"xp": 10, "ore": 5, "items": [{"id": "ice_pack", "n": 2}, {"id": "not_an_item", "n": 9}], "runes": [{"id": "rn9", "k": "hp", "v": 12.0, "rarity": "rare"}, {"id": "rn9", "k": "armor", "v": 1.0, "rarity": "epic"}],
		"relic": "cowbell", "scroll": "deadpoint"}
	var d = run("finish loot", fresh, func(r): return RpgSave.finish(r, what, s1, pack, summary(), DAY)).rpg
	ok(d.relics == {"cowbell": true} and d.scrolls == {"deadpoint": true} and int(d.items.ice_pack) == 2 and not d.items.has("not_an_item") and d.runes.size() == 2 and d.runes[0].id != d.runes[1].id, "a relic, a scroll, items and runes go in; an unknown item does not; two runes never share an id", d.runes)
	var e = run("finish dup", d, func(r): return RpgSave.finish(r, what, s1, {"relic": "cowbell", "scroll": "deadpoint"}, summary(), DAY)).rpg
	ok(int(e.ore) == int(d.ore) + int(RpgDefs.DUP_ORE["rare"]) and e.relics.size() == 1, "a relic found twice becomes ore", [d.ore, e.ore])
	# the hunt
	var hunt = RpgWorld.hunt(DAY, fresh, [])
	var hw = {"kind": "hunt", "id": str(hunt.id)}
	var hr = RpgLoot.rewards(hunt, summary(), fresh, 1, [], 2)
	var h1 = run("hunt win", fresh, func(r): return RpgSave.finish(r, hw, hunt, hr, summary(), DAY)).rpg
	ok(h1.hunt == {"date": DAY, "won": true, "streak": 1, "best": 1} and RpgLoot.hunt_prize_left(h1, DAY) and hr.prizes.size() == 3, "a hunt won: marked for the day, the prize still to pick")
	ok(not bool(run("prize early", fresh, func(r): return RpgSave.take_hunt_prize(r, DAY, hunt.prizes[0])).ok) and not bool(run("prize bad", h1, func(r): return RpgSave.take_hunt_prize(r, DAY, {"kind": "nothing"})).ok), "no prize before a win, or for a pick that is none")
	var h2 = run("prize", h1, func(r): return RpgSave.take_hunt_prize(r, DAY, hunt.prizes[0])).rpg
	ok(int(h2.ore) == int(h1.ore) + int(hunt.prizes[0].ore) and not RpgLoot.hunt_prize_left(h2, DAY) and not bool(run("prize twice", h2, func(r): return RpgSave.take_hunt_prize(r, DAY, hunt.prizes[1])).ok), "one prize a day")
	var with_prize = hr.duplicate(true)
	with_prize["prize"] = hunt.prizes[2]
	var h3 = run("hunt win with prize", fresh, func(r): return RpgSave.finish(r, hw, hunt, with_prize, summary(), DAY)).rpg
	ok(h3.runes.size() == 1 and not RpgLoot.hunt_prize_left(h3, DAY), "or the prize is picked with the win")
	var next_day = run("hunt next day", h2, func(r): return RpgSave.finish(r, {"kind": "hunt", "id": "hunt:2031-03-05"}, RpgWorld.hunt("2031-03-05", h2, []), {}, summary(), "2031-03-05")).rpg
	ok(next_day.hunt.date == "2031-03-05" and RpgLoot.hunt_prize_left(next_day, "2031-03-05"), "a new day, a new prize")
	next_day = RpgSave.take_hunt_prize(next_day, "2031-03-05", {"kind": "ore", "ore": 5}).rpg
	ok(next_day.caches.keys() == ["hunt:2031-03-05"], "only the newest day's mark is kept", next_day.caches)
	# the rival and the Spire
	var rival = RpgWorld.rival({"weekly": {"current": {"week": "2031-03-03", "monster": "wk_imp", "weakPart": "core"}}}, fresh)
	var r1 = run("rival win", fresh, func(r): return RpgSave.finish(r, {"kind": "rival", "id": str(rival.id)}, rival, RpgLoot.rewards(rival, summary(), r, 1, [], 2), summary(), DAY)).rpg
	ok(r1.rival == {"week": "2031-03-03", "won": true} and (r1.relics.size() == 1 or r1.runes.size() >= 1), "the rival won: marked for the week, its prize in the save", r1.rival)
	var sp = RpgWorld.spire(1)
	ok(not bool(run("spire shut", fresh, func(r): return RpgSave.finish(r, {"kind": "spire", "id": "spire:1"}, sp, {}, summary(), DAY)).ok), "the Spire is shut before region 2 is done")
	var open = RpgSave.empty()
	open.stages["r2s10"] = {"stars": [true, false, false], "wins": 1, "best": 20}
	var up = run("spire 1", open, func(r): return RpgSave.finish(r, {"kind": "spire", "id": "spire:1"}, sp, RpgLoot.rewards(sp, summary(), r, 11, [], 2), summary(), DAY)).rpg
	ok(int(up.spire.best) == 1 and int(up.xp) > 0 and not bool(run("spire 3", up, func(r): return RpgSave.finish(r, {"kind": "spire", "id": "spire:3"}, RpgWorld.spire(3), {}, summary(), DAY)).ok), "a floor climbed is the best; floors are not skipped")
	var same_floor = run("spire 1 again", up, func(r): return RpgSave.finish(r, {"kind": "spire", "id": "spire:1"}, sp, RpgLoot.rewards(sp, summary(), r, 11, [], 2), summary(), DAY)).rpg
	ok(int(same_floor.spire.best) == 1 and int(same_floor.xp) == int(up.xp), "a floor climbed again pays nothing more")
	# an echo
	var late = RpgSave.empty()
	late.stages["r8s10"] = {"stars": [true, false, false], "wins": 1, "best": 20}
	var ec = RpgWorld.stage("e1s1")
	var e1 = run("echo", late, func(r): return RpgSave.finish(r, {"kind": "echo", "id": "e1s1"}, ec, RpgLoot.rewards(ec, summary(), r, 40, [], 2), summary({"turns": 4}), DAY)).rpg
	ok(int(e1.stages["e1s1"].wins) == 1 and bool(e1.stages["e1s1"].stars[0]) and not bool(run("echo shut", fresh, func(r): return RpgSave.finish(r, {"kind": "echo", "id": "e1s1"}, ec, {}, summary(), DAY)).ok), "an echo stage is kept like a road stage, once the echoes are open")


# --- caches, star chests, training chests -----------------------------------------------

func _finds() -> void:
	var fresh = RpgSave.empty()
	var at5 = RpgSave.empty()
	for id in ["r1s1", "r1s2", "r1s3", "r1s4", "r1s5"]:
		at5.stages[id] = {"stars": [true, true, false], "wins": 1, "best": 6}
	var opts = RpgLoot.cache("r1s6", at5, 1)
	ok(not bool(run("cache early", fresh, func(r): return RpgSave.take_cache(r, "r1s6", opts[0])).ok) and not bool(run("cache not one", at5, func(r): return RpgSave.take_cache(r, "r1s5", opts[0])).ok)
		and not bool(run("cache bad pick", at5, func(r): return RpgSave.take_cache(r, "r1s6", {"kind": "relic", "relic": "nope"})).ok) and not bool(run("cache no pick", at5, func(r): return RpgSave.take_cache(r, "r1s6", null)).ok),
		"a cache: not before it is reached, not on a stage that is none, not without a real pick")
	var got = [run("cache relic", at5, func(r): return RpgSave.take_cache(r, "r1s6", opts[0])).rpg, run("cache rune", at5, func(r): return RpgSave.take_cache(r, "r1s6", opts[1])).rpg,
		run("cache items", at5, func(r): return RpgSave.take_cache(r, "r1s6", opts[2])).rpg, run("cache ore", at5, func(r): return RpgSave.take_cache(r, "r1s6", {"kind": "ore", "ore": 70})).rpg]
	ok(got[0].relics.has(str(opts[0].relic)) and got[1].runes.size() == 1 and got[1].runes[0].id == opts[1].rune.id and int(got[2].items.protein_shake) == 5 and int(got[3].ore) == 70
		and got.all(func(g): return bool(g.caches.get("r1s6", false)) and RpgWorld.is_open(g, "r1s7")), "each of the finds goes in, the cache is marked and the road goes on", got[2].items)
	ok(not bool(run("cache twice", got[0], func(r): return RpgSave.take_cache(r, "r1s6", opts[1])).ok), "a cache is taken once")
	# star chests
	var c8 = RpgLoot.star_chest("rustyard", 8, 1, at5)
	ok(not bool(run("stars short", fresh, func(r): return RpgSave.open_star_chest(r, "rustyard", 8, c8)).ok) and not bool(run("stars none", at5, func(r): return RpgSave.open_star_chest(r, "rustyard", 9, c8)).ok)
		and not bool(run("stars nowhere", at5, func(r): return RpgSave.open_star_chest(r, "nope", 8, c8)).ok) and not bool(run("stars 16", at5, func(r): return RpgSave.open_star_chest(r, "rustyard", 16, c8)).ok),
		"a star chest needs its stars, and has to be one")
	ok(str(RpgSave.open_star_chest(at5, "rustyard", 16, c8).why) == "Needs 16 stars here (you have 10).", "and says how many are missing", RpgSave.open_star_chest(at5, "rustyard", 16, c8).why)
	var s8 = run("stars 8", at5, func(r): return RpgSave.open_star_chest(r, "rustyard", 8, c8)).rpg
	ok(int(s8.ore) == int(c8.ore) and bool(s8.starChests.get("rustyard:8", false)) and not s8.items.is_empty() and not bool(run("stars again", s8, func(r): return RpgSave.open_star_chest(r, "rustyard", 8, c8)).ok), "opened once: its ore and items")
	var full = RpgSave.copy(at5)
	for id in ["r1s7", "r1s8", "r1s9", "r1s10"]:
		full.stages[id] = {"stars": [true, true, true], "wins": 1, "best": 6}
	full.caches["r1s6"] = true
	var c16 = RpgLoot.star_chest("rustyard", 16, 1, full)
	var s16 = run("stars 16 open", full, func(r): return RpgSave.open_star_chest(r, "rustyard", 16, c16)).rpg
	ok(s16.scrolls == {str(c16.scroll): true} and RpgSkills.known_moves(s16).has(str(c16.scroll)), "the 16-star chest's scroll is a move the hero now knows", c16)
	# the training chest
	var chest = {"date": DAY, "kinds": ["lift", "run"], "tier": "gold", "ore": 80, "items": [{"id": "protein_shake", "n": 2}, {"id": "ice_pack", "n": 1}], "rune": true}
	var old = RpgSave.empty()
	old.chests = {"2031-01-01": 2, "2031-03-03": 1}
	var t1 = run("chest", old, func(r): return RpgSave.claim_chest(r, chest)).rpg
	ok(int(t1.ore) == 80 and int(t1.items.protein_shake) == 2 and int(t1.items.ice_pack) == 1 and t1.runes.size() == 1 and t1.chests == {"2031-03-03": 1, DAY: 2}, "a training chest: ore, items, a gold one's rune; the day is marked and marks of long ago are dropped", t1.chests)
	ok(not bool(run("chest twice", t1, func(r): return RpgSave.claim_chest(r, chest)).ok) and not bool(run("chest none", t1, func(r): return RpgSave.claim_chest(r, null)).ok), "a chest is opened once")
	var grown = chest.duplicate(true)
	grown.kinds = ["lift", "run", "read", "mobility"]
	grown.ore = 130
	var t2 = run("chest grown", t1, func(r): return RpgSave.claim_chest(r, grown)).rpg
	ok(int(t2.ore) == 80 + 2 * RpgDefs.CHEST_ORE_KIND and int(t2.items.protein_shake) == 2 and t2.runes.size() == 1 and int(t2.chests[DAY]) == 4, "a day that grew pays the difference in ore, and only that", t2.ore)


# --- skills and builds ----------------------------------------------------------------------

func _skills_and_builds() -> void:
	var strong = sheet_of(60.0)
	var weak = sheet_of(5.0)
	var fresh = RpgSave.empty()
	var n1 = node_of("move", 1, "push")
	var n2 = node_of("move", 2, "push")
	var p1 = node_of("passive", 1, "push")
	ok(not bool(run("learn nothing", fresh, func(r): return RpgSave.learn(r, "push:nope", strong, 0)).ok) and not bool(run("learn tier 2", fresh, func(r): return RpgSave.learn(r, str(n2.id), strong, 0)).ok), "a skill that is none, or one whose tier below is missing, is not learned")
	var a = run("learn", fresh, func(r): return RpgSave.learn(r, str(n1.id), strong, 0)).rpg
	ok(a.nodes == {str(n1.id): true} and RpgSkills.known_moves(a).has(str(n1.ref)) and int(RpgSkills.points(a, 0).left) == 2, "a skill learned: the node, the move, a point spent")
	ok(not bool(run("learn twice", a, func(r): return RpgSave.learn(r, str(n1.id), strong, 0)).ok) and str(RpgSave.learn(a, str(n2.id), weak, 0).why).begins_with("Needs "), "not twice; a stat too low says which", RpgSave.learn(a, str(n2.id), weak, 0).why)
	var b = RpgSave.learn(RpgSave.learn(a, str(n2.id), strong, 0).rpg, str(p1.id), strong, 0).rpg
	ok(b.nodes.size() == 3 and int(RpgSkills.points(b, 0).left) == 0 and str(RpgSave.learn(b, str(node_of("move", 1, "pull").id), strong, 0).why).begins_with("Not enough skill points"), "three points, three skills, then no more")
	ok(bool(RpgSave.learn(b, str(node_of("move", 1, "pull").id), strong, 8).ok), "training days earn points too")
	var wiped = run("reset", b, func(r): return RpgSave.reset_nodes(r)).rpg
	ok(wiped.nodes.is_empty() and int(RpgSkills.points(wiped, 0).left) == 3 and wiped.builds == b.builds, "reset: every point back, the builds untouched")

	# builds
	ok(not bool(run("build 3", fresh, func(r): return RpgSave.set_build(r, 3)).ok) and not bool(run("build -1", fresh, func(r): return RpgSave.set_build(r, -1)).ok), "there are three builds")
	var two = run("build 2", fresh, func(r): return RpgSave.set_build(r, 2)).rpg
	ok(int(two.build) == 2 and is_same(RpgSave.build_of(two), two.builds[2]), "set_build picks the build in use")
	var named = run("rename", fresh, func(r): return RpgSave.rename_build(r, 1, "  Leg day, the long version of it  ")).rpg
	ok(str(named.builds[1].name) == "Leg day, the long versio" and not bool(run("rename empty", fresh, func(r): return RpgSave.rename_build(r, 1, "   ")).ok) and not bool(run("rename none", fresh, func(r): return RpgSave.rename_build(r, 5, "x")).ok), "a build's name: trimmed, 24 letters, never empty", named.builds[1].name)

	# moves
	ok(RpgSave.build_of(fresh).moves == ["shove", "yank", "stomp", "deep_breath", ""], "a new save starts with the first build's moves")
	var m1 = run("move", two, func(r): return RpgSave.equip_move(r, 0, "pinch")).rpg
	ok(m1.builds[2].moves[0] == "pinch" and m1.builds[0].moves[0] == "shove", "a move goes into the build in use, and no other")
	var m2 = run("move swap", fresh, func(r): return RpgSave.equip_move(r, 0, "stomp")).rpg
	ok(RpgSave.build_of(m2).moves == ["stomp", "yank", "shove", "deep_breath", ""], "a move sits in one slot: put elsewhere, the two change places", RpgSave.build_of(m2).moves)
	var m3 = run("move clear", fresh, func(r): return RpgSave.equip_move(r, 1, "")).rpg
	ok(RpgSave.build_of(m3).moves == ["shove", "", "stomp", "deep_breath", ""], "an empty id empties the slot")
	var ult = node_of("ult", 5)
	ok(not bool(run("move unknown", fresh, func(r): return RpgSave.equip_move(r, 0, "nope")).ok) and not bool(run("move unlearned", fresh, func(r): return RpgSave.equip_move(r, 0, str(n2.ref))).ok)
		and not bool(run("move scroll", fresh, func(r): return RpgSave.equip_move(r, 0, "deadpoint")).ok) and not bool(run("move ult", fresh, func(r): return RpgSave.equip_move(r, 0, str(ult.ref))).ok)
		and not bool(run("move slot 9", fresh, func(r): return RpgSave.equip_move(r, 9, "shove")).ok), "not a move nobody knows, one not learned, a scroll not found, an ultimate, or a slot that is none")
	ok(str(RpgSave.equip_move(fresh, 4, "pinch").why) == "The fifth move slot opens at fighter level 20." and bool(run("move slot 5", at_level(20), func(r): return RpgSave.equip_move(r, 4, "pinch")).ok), "the fifth slot opens at fighter level 20")
	ok(bool(run("move learned", a, func(r): return RpgSave.equip_move(r, 3, str(n1.ref))).ok), "a learned move can be equipped")
	var scrolled = RpgSave.empty()
	scrolled.scrolls["deadpoint"] = true
	ok(bool(run("move scroll found", scrolled, func(r): return RpgSave.equip_move(r, 2, "deadpoint")).ok), "and so can a scroll that was found")
	# the ultimate
	var knows = at_level(20)
	knows.nodes[str(ult.id)] = true
	var u1 = run("ult", knows, func(r): return RpgSave.equip_ult(r, str(ult.ref))).rpg
	ok(str(RpgSave.build_of(u1).ult) == str(ult.ref) and str(run("ult off", u1, func(r): return RpgSave.equip_ult(r, "")).rpg.builds[0].ult) == ""
		and not bool(run("ult unlearned", fresh, func(r): return RpgSave.equip_ult(r, str(ult.ref))).ok) and not bool(run("ult a move", fresh, func(r): return RpgSave.equip_ult(r, "shove")).ok), "the ultimate: a learned one, and only an ultimate")
	# passives
	var pa = at_level(10)
	pa.nodes[str(p1.id)] = true
	var p_pull = node_of("passive", 1, "pull")
	pa.nodes[str(p_pull.id)] = true
	var q1 = run("passive", pa, func(r): return RpgSave.equip_passive(r, 0, str(p1.ref))).rpg
	var q2 = RpgSave.equip_passive(q1, 1, str(p_pull.ref)).rpg
	var q3 = run("passive swap", q2, func(r): return RpgSave.equip_passive(r, 1, str(p1.ref))).rpg
	ok(RpgSave.build_of(q2).passives == [str(p1.ref), str(p_pull.ref), ""] and RpgSave.build_of(q3).passives == [str(p_pull.ref), str(p1.ref), ""], "passives: one slot each, swapped when moved", RpgSave.build_of(q3).passives)
	ok(str(RpgSave.equip_passive(pa, 2, str(p1.ref)).why) == "This passive slot opens at fighter level 20." and str(RpgSave.equip_passive(fresh, 0, "lockout_strength").why).contains("level 3")
		and not bool(run("passive unlearned", at_level(10), func(r): return RpgSave.equip_passive(r, 0, str(p1.ref))).ok) and not bool(run("passive none", pa, func(r): return RpgSave.equip_passive(r, 0, "nope")).ok), "passive slots open at 3, 10 and 20; a passive has to be learned")


# --- gear, relics, companion, belt, upgrades, runes, the shop -------------------------------------

func _gear() -> void:
	var fresh = RpgSave.empty()
	var head = gear_of("head")
	var head2 = gear_of("head", 1)
	var body = gear_of("body")
	var g1 = run("gear", fresh, func(r): return RpgSave.equip_gear(r, "head", head)).rpg
	ok(RpgSave.build_of(g1).gear == {"head": head} and RpgSave.build_of(run("gear off", g1, func(r): return RpgSave.equip_gear(r, "head", "")).rpg).gear.is_empty(), "gear goes onto its slot and comes off")
	ok(not bool(run("gear wrong slot", fresh, func(r): return RpgSave.equip_gear(r, "head", body)).ok) and not bool(run("gear none", fresh, func(r): return RpgSave.equip_gear(r, "head", "nope")).ok)
		and not bool(run("gear no slot", fresh, func(r): return RpgSave.equip_gear(r, "tail", head)).ok) and not bool(run("gear not owned", fresh, func(r): return RpgSave.equip_gear(r, "head", head, {head2: {}})).ok)
		and bool(run("gear owned", fresh, func(r): return RpgSave.equip_gear(r, "head", head, {head: {}})).ok), "not onto another slot, not something that is no gear, and (when asked) only what is owned")
	# relics
	var rl = at_level(8)
	rl.relics = {"cowbell": true, "chipped_tooth": true}
	var r1 = RpgSave.equip_relic(RpgSave.equip_relic(rl, 0, "cowbell").rpg, 1, "chipped_tooth").rpg
	var r2 = run("relic swap", r1, func(r): return RpgSave.equip_relic(r, 0, "chipped_tooth")).rpg
	ok(RpgSave.build_of(r1).relics == ["cowbell", "chipped_tooth", ""] and RpgSave.build_of(r2).relics == ["chipped_tooth", "cowbell", ""], "relics: one slot each, swapped when moved")
	ok(str(RpgSave.equip_relic(rl, 2, "cowbell").why) == "This relic slot opens at fighter level 30." and not bool(run("relic slot 2", fresh, func(r): return RpgSave.equip_relic(r, 1, "")).ok)
		and not bool(run("relic not found", rl, func(r): return RpgSave.equip_relic(r, 0, "flywheel")).ok) and not bool(run("relic none", rl, func(r): return RpgSave.equip_relic(r, 0, "nope")).ok), "relic slots open at 8 and 30; a relic has to be found")
	# the companion
	ok(str(RpgSave.build_of(run("pet", fresh, func(r): return RpgSave.equip_pet(r, "owl")).rpg).pet) == "owl" and not bool(run("pet none", fresh, func(r): return RpgSave.equip_pet(r, "unicorn")).ok)
		and not bool(run("pet not owned", fresh, func(r): return RpgSave.equip_pet(r, "owl", {"slime": {}})).ok) and bool(run("pet off", fresh, func(r): return RpgSave.equip_pet(r, "")).ok), "the companion: a real one, and (when asked) one that is owned")
	# the belt
	var b1 = RpgSave.set_belt(RpgSave.set_belt(fresh, 0, "protein_shake").rpg, 1, "chalk_ball").rpg
	var b2 = run("belt swap", b1, func(r): return RpgSave.set_belt(r, 0, "chalk_ball")).rpg
	ok(RpgSave.build_of(b2).belt == ["chalk_ball", "protein_shake", ""] and str(RpgSave.set_belt(fresh, 2, "ice_pack").why) == "The third belt slot opens at fighter level 6."
		and bool(run("belt 3", at_level(6), func(r): return RpgSave.set_belt(r, 2, "ice_pack")).ok) and not bool(run("belt none", fresh, func(r): return RpgSave.set_belt(r, 0, "nope")).ok), "the belt: two slots, a third at level 6, an item in one slot only")
	# upgrades
	var rich = RpgSave.empty()
	rich.ore = 100000
	var rarity = str(RpgGear.of(head).rarity)
	var u = run("upgrade", rich, func(r): return RpgSave.upgrade(r, head)).rpg
	ok(int(u.plus[head]) == 1 and int(u.ore) == 100000 - RpgDefs.plus_cost(rarity, 0) and RpgDefs.plus_cost(rarity, 0) == RpgGear.plus_cost(head, 0), "an upgrade: one plus, the ore taken")
	var dear = RpgSave.upgrade(rich, head, "legendary").rpg
	ok(int(dear.ore) == 100000 - RpgDefs.plus_cost("legendary", 0), "the rarity the caller names sets the price")
	var top = rich
	var spent = 0
	for i in range(RpgDefs.PLUS_MAX):
		spent += RpgDefs.plus_cost(rarity, i)
		top = RpgSave.upgrade(top, head).rpg
	ok(int(top.plus[head]) == RpgDefs.PLUS_MAX and int(top.ore) == 100000 - spent and not bool(run("upgrade cap", top, func(r): return RpgSave.upgrade(r, head)).ok), "ten times, each dearer, then no further")
	var poor = RpgSave.empty()
	poor.ore = 12
	ok(str(run("upgrade poor", poor, func(r): return RpgSave.upgrade(r, head)).why) == "Not enough ore (needs %d, you have 12)." % RpgDefs.plus_cost(rarity, 0) and not bool(run("upgrade none", rich, func(r): return RpgSave.upgrade(r, "nope")).ok)
		and not bool(run("upgrade not owned", rich, func(r): return RpgSave.upgrade(r, head, "", {})).ok), "not without the ore, not for something that is no gear")
	# runes
	var rn = RpgSave.empty()
	rn.runes = [{"id": "rna", "k": "hp", "v": 10.0, "rarity": "common"}, {"id": "rnb", "k": "armor", "v": 1.5, "rarity": "epic"}]
	var s1 = run("socket", rn, func(r): return RpgSave.socket(r, head, "rna")).rpg
	var s2 = run("socket move", s1, func(r): return RpgSave.socket(r, body, "rna")).rpg
	var s3 = run("socket replace", s2, func(r): return RpgSave.socket(r, body, "rnb")).rpg
	ok(s1.socket == {head: "rna"} and s2.socket == {body: "rna"} and s3.socket == {body: "rnb"}, "a rune sits in one item and an item holds one rune", [s1.socket, s2.socket, s3.socket])
	ok(run("socket out", s3, func(r): return RpgSave.socket(r, body, "")).rpg.socket.is_empty() and not bool(run("socket no rune", rn, func(r): return RpgSave.socket(r, head, "rnz")).ok) and not bool(run("socket no gear", rn, func(r): return RpgSave.socket(r, "nope", "rna")).ok), "a rune comes out again; a rune and an item have to be there")
	var sc = run("scrap", s3, func(r): return RpgSave.scrap_rune(r, "rnb")).rpg
	ok(sc.runes.size() == 1 and sc.runes[0].id == "rna" and sc.socket.is_empty() and int(sc.ore) == RpgLoot.scrap_ore({"rarity": "epic"}) and not bool(run("scrap none", sc, func(r): return RpgSave.scrap_rune(r, "rnb")).ok), "a rune scrapped: out of its item, gone, ore by its rarity", sc)
	# the shop
	var buyer = RpgSave.empty()
	buyer.ore = 100
	var price = RpgItems.price("protein_shake")
	var bought = run("buy", buyer, func(r): return RpgSave.buy_item(r, "protein_shake", 3)).rpg
	ok(int(bought.items.protein_shake) == 3 and int(bought.ore) == 100 - 3 * price, "the camp shop: items for ore")
	ok(str(run("buy poor", buyer, func(r): return RpgSave.buy_item(r, "pre_workout", 2)).why) == "Not enough ore (needs %d, you have 100)." % (2 * RpgItems.price("pre_workout")) and not bool(run("buy none", buyer, func(r): return RpgSave.buy_item(r, "nope", 1)).ok)
		and not bool(run("buy zero", buyer, func(r): return RpgSave.buy_item(r, "protein_shake", 0)).ok), "not without the ore, not what the shop does not sell, not none")


# --- a little campaign with the real engine ---------------------------------------------------------

## Fights a stage until it is won (other seeds on a loss); the battle, or null.
func fight(rpg: Dictionary, stage_id: String, sheet: Dictionary) -> Variant:
	for attempt in range(6):
		var hero = RpgHero.build(sheet, [], rpg, {"items": {}, "pets": {}})
		var B = RpgBattle.start(RpgWorld.setup({"kind": "stage", "id": stage_id}, rpg, hero, null, 40 + attempt * 13, DAY))
		for i in range(500):
			if RpgBattle.over(B):
				break
			RpgBattle.act(B, RpgAi.hero_action(B, "heuristic"))
		if RpgBattle.won(B):
			return B
	return null


func _campaign() -> void:
	var sheet = sheet_of(30.0)
	var rpg = RpgSave.first_open(RpgSave.empty(), {}, null)
	rpg.items = {"protein_shake": 2}
	rpg = RpgSave.set_belt(rpg, 0, "protein_shake").rpg
	var won_all = true
	var paid_xp = 0
	for id in ["r1s1", "r1s2", "r1s3", "r1s4", "r1s5"]:
		var B = fight(rpg, id, sheet)
		if B == null:
			won_all = false
			break
		var st = RpgWorld.stage(id)
		var sum = RpgBattle.summary(B)
		var rw = RpgLoot.rewards(st, sum, rpg, RpgSave.level_of(rpg), [], int(B.rng))
		paid_xp += int(rw.xp)
		var res = run("campaign " + id, rpg, func(r): return RpgSave.finish(r, B.what, st, rw, sum, DAY))
		if not bool(res.ok):
			won_all = false
			break
		rpg = res.rpg
	ok(won_all and int(rpg.xp) == paid_xp and ["r1s1", "r1s2", "r1s3", "r1s4", "r1s5"].all(func(id): return int(rpg.stages.get(id, {}).get("wins", 0)) == 1), "r1s1 to r1s5 fought with the real engine and kept", rpg.stages.keys())
	ok(not rpg.seen.is_empty() and rpg.scrolls.has(str(RpgWorld.stage("r1s5").first.scroll)) and int(rpg.items.get("protein_shake", 0)) >= 1 and RpgSave.level_of(rpg) >= 2, "weaknesses were learned, the elite's scroll and items are there, the fighter has levelled", [rpg.seen, rpg.scrolls, rpg.items])
	var opts = RpgLoot.cache("r1s6", rpg, int(rpg.xp))
	rpg = run("campaign cache", rpg, func(r): return RpgSave.take_cache(r, "r1s6", opts[1])).rpg
	ok(rpg.runes.size() == 1 and RpgWorld.is_open(rpg, "r1s7"), "the cache: its rune taken, the road open")
	var node = node_of("move", 1, "legs")
	rpg = run("campaign learn", rpg, func(r): return RpgSave.learn(r, str(node.id), sheet, 12)).rpg
	rpg = run("campaign equip", rpg, func(r): return RpgSave.equip_move(r, 3, str(node.ref))).rpg
	var head = gear_of("head")
	rpg = run("campaign gear", rpg, func(r): return RpgSave.equip_gear(r, "head", head)).rpg
	var ore0 = int(rpg.ore)
	rpg = run("campaign upgrade", rpg, func(r): return RpgSave.upgrade(r, head)).rpg
	rpg = run("campaign socket", rpg, func(r): return RpgSave.socket(r, head, str(r.runes[0].id))).rpg
	rpg = run("campaign buy", rpg, func(r): return RpgSave.buy_item(r, "electrolytes", 1)).rpg
	ok(bool(rpg.nodes.get(str(node.id), false)) and RpgSave.build_of(rpg).moves[3] == str(node.ref) and int(rpg.plus.get(head, 0)) == 1 and rpg.socket.get(head) == rpg.runes[0].id and int(rpg.items.get("electrolytes", 0)) == 1
		and int(rpg.ore) == ore0 - RpgGear.plus_cost(head, 0) - RpgItems.price("electrolytes"), "a skill learned and equipped, gear upgraded and socketed, an item bought", [ore0, rpg.ore])
	var chest = {"date": DAY, "kinds": ["lift"], "tier": "wood", "ore": 55, "items": [{"id": "chalk_ball", "n": 1}], "rune": false}
	var before = int(rpg.ore)
	rpg = run("campaign chest", rpg, func(r): return RpgSave.claim_chest(r, chest)).rpg
	ok(int(rpg.ore) == before + 55 and int(rpg.items.get("chalk_ball", 0)) >= 1 and int(rpg.chests[DAY]) == 1, "a training chest claimed")
	# the hero built from that save fights with what was won
	var hero = RpgHero.build(sheet, [], rpg, {"items": {head: {}}, "pets": {}})
	ok(hero.moves.has(str(node.ref)) and float(hero.hp_max) > 0.0 and hero.belt.any(func(b): return str(b.id) == "protein_shake" and int(b.n) >= 1), "the hero of that save has the new move and a stocked belt", hero.moves)
	var round_trip = RpgSave.parse(TTUtil.normalize_json(JSON.parse_string(JSON.stringify(rpg))))
	ok(same(round_trip, rpg) and same(RpgSave.parse(rpg), rpg), "parse keeps everything the campaign wrote, through JSON too")
	_campaign_save = rpg


var _campaign_save = {}


# --- the save file -----------------------------------------------------------------------------------

func _app() -> void:
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		ok(false, "the App autoload is there")
		return
	var rpg = _campaign_save
	var saved = app.empty_saved()
	saved["rpg"] = RpgSave.copy(rpg)
	var back = app.parse_saved(JSON.parse_string(JSON.stringify(saved)))
	ok(back != null and same(back.rpg, rpg) and not rpg.stages.is_empty(), "a save with the campaign's Realm survives App.parse_saved, through JSON", back.rpg.keys() if back != null else null)
	ok(same(app.parse_saved({"sessions": []}).rpg, RpgSave.empty()) and RpgSave.empty().keys() == ["v", "opened", "xp", "ore", "nodes", "builds", "build", "plus", "runes", "socket", "relics", "scrolls", "items", "stages", "starChests", "caches", "seen", "statsSeen", "feats", "hints", "prefs", "tally", "mastery", "chests", "hunt", "rival", "spire"],
		"a save without one gets the empty Realm, whose keys are the plan's and no more", RpgSave.empty().keys())
