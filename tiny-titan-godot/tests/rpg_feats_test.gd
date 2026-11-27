extends SceneTree
## Unit test for the Realm's feats (game/rpg/rpg_feats.gd and RpgSave.claim_feat):
## the ladders are well formed, every count is read from the save or the sheet,
## a step can be claimed exactly when its count is reached and pays once.
##   godot --headless --path . --script res://tests/rpg_feats_test.gd
## Prints RPG FEATS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


func _row(rows: Array, id: String):
	for r in rows:
		if str(r.id) == id:
			return r
	return null


func _run() -> void:
	# --- the catalog ---------------------------------------------------------------------------
	var bad = []
	var seen = {}
	var steps_all = 0
	for l in RpgFeats.LADDERS:
		var id = str(l[0])
		if seen.has(id) or l.size() != 5 or str(l[1]) == "" or not str(l[3]).contains("%d") or l[4].is_empty() or l[4].size() > RpgFeats.ROMAN.size():
			bad.append(id)
		seen[id] = true
		var last = 0
		var last_ore = 0
		for st in l[4]:
			steps_all += 1
			if int(st[0]) <= last or int(st[1]) <= last_ore:
				bad.append("%s: steps must rise (%s)" % [id, str(st)])
			last = int(st[0])
			last_ore = int(st[1])
	ok(bad.is_empty() and RpgFeats.LADDERS.size() >= 10, "ten ladders or more, each with a name, words with its number, and steps that rise in count and in ore", bad)
	ok(int(RpgFeats.tally(RpgSave.empty()).of) == steps_all and int(RpgFeats.tally(RpgSave.empty()).claimed) == 0, "the tally counts every step; none is claimed in a new Realm", RpgFeats.tally(RpgSave.empty()))

	# --- an empty Realm: nothing to claim ----------------------------------------------------------
	var rpg = RpgSave.empty()
	var c0 = RpgFeats.counts(rpg, null)
	ok(c0.keys() == RpgFeats.ids() and c0.values().all(func(v): return int(v) == 0 or v == c0.level) and int(c0.level) == 1, "an empty Realm counts nothing (the fighter is level 1)", c0)
	ok(RpgFeats.ready(rpg, null) == 0 and RpgFeats.rows(rpg, null).size() == RpgFeats.LADDERS.size(), "a row per ladder, none ready")
	var no = RpgSave.claim_feat(rpg, "stars", null)
	ok(not bool(no.ok) and str(no.why).contains("0 of 10") and int(no.rpg.ore) == 0, "a step that is not reached cannot be claimed, and it says how far it is", no.why)
	ok(not bool(RpgSave.claim_feat(rpg, "no_such", null).ok), "an unknown feat is refused")

	# --- the log's counts come from the sheet ---------------------------------------------------------
	var sheet = {"days": 31, "might": 30.4}
	var c1 = RpgFeats.counts(rpg, sheet)
	ok(int(c1.days) == 31 and int(c1.might) == 30, "days trained and Might come from the stat sheet", [c1.days, c1.might])
	var rows1 = RpgFeats.rows(rpg, sheet)
	ok(bool(rows1[0].ready) and bool(rows1[1].ready) and not bool(rows1[2].ready) and [str(rows1[0].id), str(rows1[1].id)] == ["days", "might"], "the rows that can be claimed come first", rows1.slice(0, 3).map(func(r): return [r.id, r.ready]))
	var days_row = _row(rows1, "days")
	ok(str(days_row.name) == "Regular I" and str(days_row.words) == "Train on 10 days" and int(days_row.need) == 10 and int(days_row.have) == 10 and int(days_row.ore) == 50, "a row says its step: Regular I, train on 10 days, 50 ore", days_row)

	# --- claiming: once a step, the next one follows ---------------------------------------------------
	var a = RpgSave.claim_feat(rpg, "days", sheet)
	ok(bool(a.ok) and int(a.rpg.ore) == 50 and int(a.ore) == 50 and str(a.name) == "Regular I" and int(a.rpg.feats.days) == 1, "the first step pays its ore and is marked", [a.get("why"), a.rpg.ore])
	var b = RpgSave.claim_feat(a.rpg, "days", sheet)
	ok(bool(b.ok) and int(b.rpg.ore) == 150 and str(b.name) == "Regular II" and int(b.rpg.feats.days) == 2, "31 days: the second step (30) is there too", [b.get("why"), b.rpg.ore])
	var c = RpgSave.claim_feat(b.rpg, "days", sheet)
	ok(not bool(c.ok) and int(c.rpg.ore) == 150 and str(c.why).contains("31 of 60"), "the third (60) is not: nothing is paid", c.why)
	ok(int(rpg.ore) == 0 and not rpg.feats.has("days"), "the save handed in is never changed")
	var after = _row(RpgFeats.rows(b.rpg, sheet), "days")
	ok(str(after.name) == "Regular III" and int(after.need) == 60 and int(after.have) == 31 and not bool(after.ready), "its row moves on to the next step", after)

	# --- every step of a ladder -------------------------------------------------------------------
	var big = {"days": 999, "might": 99.0}
	var r2 = RpgSave.empty()
	var paid = 0
	var n = 0
	while n < 10:
		var res = RpgSave.claim_feat(r2, "might", big)
		if not bool(res.ok):
			break
		r2 = res.rpg
		paid += int(res.ore)
		n += 1
	var might_l = RpgFeats.ladder("might")
	var want = 0
	for st in might_l[4]:
		want += int(st[1])
	var last_row = _row(RpgFeats.rows(r2, big), "might")
	ok(n == might_l[4].size() and paid == want and int(r2.ore) == want and bool(last_row.done) and not bool(last_row.ready), "a whole ladder is claimed step by step, then it is done", [n, paid, want])
	ok(str(RpgSave.claim_feat(r2, "might", big).why).contains("Every step"), "and says so when asked again")
	ok(RpgFeats.rows(r2, big)[RpgFeats.LADDERS.size() - 1].id == "might", "a ladder that is done goes last")

	# --- the save file ---------------------------------------------------------------------------------
	var back = RpgSave.parse(JSON.parse_string(JSON.stringify(b.rpg)))
	ok(back.feats == {"days": 2} and int(back.ore) == 150, "the claimed steps survive the save file", back.feats)
	var junk = RpgSave.parse({"feats": {"days": 99, "nope": 2, "stars": -1, "might": "x"}})
	ok(junk.feats == {"days": RpgFeats.ladder("days")[4].size()}, "junk in it does not: unknown ladders go, a count is kept within its ladder", junk.feats)

	# --- the counts from the Realm's own save ---------------------------------------------------------
	var world = RpgSave.empty()
	world.xp = 100000
	world.nodes = {"a": true, "b": true, "c": true}
	world.plus = {"x": 3, "y": 4}
	world.relics = {"r1": true}
	world.spire = {"best": 7}
	world.seen = {"dust_bunny": ["push", "legs"], "rust_rat": ["pull"]}
	var cw = RpgFeats.counts(world, null)
	ok(int(cw.skills) == 3 and int(cw.plus) == 7 and int(cw.relics) == 1 and int(cw.spire) == 7 and int(cw.weak) == 3 and int(cw.foes) == 2 and int(cw.level) > 1, "skills, upgrades, relics, the Spire, weaknesses, foes met and the level are read from the save", cw)
	var first = RpgWorld.all_stages()[0]
	world.stages[str(first.id)] = {"stars": [true, true, false], "wins": 1, "best": 3}
	var cs = RpgFeats.counts(world, null)
	ok(int(cs.stages) == 1 and int(cs.stars) == 2 and int(cs.foes) >= 2, "a stage won counts, with its stars and the foes that stood in it", [cs.stages, cs.stars, cs.foes])

	print("RPG FEATS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
