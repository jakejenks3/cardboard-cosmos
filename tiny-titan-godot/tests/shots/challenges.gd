extends RefCounted
## The day's lift challenges (Challenges, ChallengeView; run with "year" data, also --fingers): the Hero tab's
## CHALLENGES section (a card a lift, records to pick from: heavier than ever, a rep record at a weight done
## before, the best for N reps), the Log tab's TRY keys on the lift's card (a tap fills the next set, the key
## lights when a set does it), and the challenge done and claimed once the workout is saved.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _section(id: String):
	for n in ShotHelper.walk(main):
		if n.has_meta("section") and str(n.get_meta("section")) == id and n is Control and n.is_visible_in_tree():
			return n
	return null


func _press(b) -> void:
	if b == null:
		return
	ShotHelper.reveal(b)
	await ShotHelper.wait(tree, 0.3)
	if b is BaseButton:
		b.pressed.emit()
	await ShotHelper.wait(tree, 0.6)


func _ed():
	var f = main._screen._form if main._screen != null and main._screen.get("_form") != null else null
	return f


func _dismiss_reels() -> void:
	for k in range(8):
		var b = null
		for i in range(30):
			await ShotHelper.wait(tree, 0.3)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.4)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# The demo player trains by the weekday: take out this weekday's sessions, then give today a bench habit.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	for wk in [21, 14, 7]:
		clean.sessions.append({"id": "chal%d" % wk, "discipline": "lift", "date": Dates.add_days(App.today, -wk), "createdAt": App.now_ms() - wk * 86400000, "source": "manual",
			"exercises": [{"name": "Bench Press - Barbell", "sets": [{"reps": 8 + (21 - wk) / 7, "weightKg": 60.0}, {"reps": 8, "weightKg": 60.0}, {"reps": 7, "weightKg": 60.0}]}]})
	App.replace_all(clean)
	await ShotHelper.wait(tree, 0.8)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)

	var sec = _section("challenges")
	check(sec != null, "the Hero tab has a CHALLENGES section")
	var daily = App.quests().daily.filter(func(m): return bool(m.get("challenge", false)))
	check(not daily.is_empty() and daily.all(func(m): return str(m.title).ends_with(" challenge")), "today's lifts have challenges (%s)" % str(daily.map(func(m): return m.title)))
	var cards = _all("challenge", sec) if sec != null else []
	check(cards.size() == daily.size() and cards.all(func(c): return _all("challenge_option", c).size() >= 2), "a card each, with records to pick from")
	var bench = daily.filter(func(m): return str(m.lift).begins_with("Bench Press"))
	check(not bench.is_empty(), "bench press is one of them")
	if not bench.is_empty():
		var types = bench[0].options.map(func(o): return str(o.type))
		check(types.has("heavier") and types.has("reps"), "its picks: heavier than ever and a rep record at a weight done before (%s)" % str(types))
		print("BENCH options: ", bench[0].options.map(func(o): return "%s %s (%s)" % [o.title, o.words, o.sub]))
	if sec != null:
		ShotHelper.reveal(sec)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "challenges_1_hero")
	if bench.is_empty():
		print("CHALLENGES %d FAILED" % fails)
		return

	# --- the Log tab: the TRY keys ---------------------------------------------------------------------------
	var m = bench[0]
	App.draft_store("lift", null)
	App.pending_workout = [str(m.lift)]
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var f = _ed()
	check(f != null and f.lift.exercises.size() >= 1, "the workout is open with the bench")
	var row = _one("try_row", 0)
	check(row != null and _all("try_key", row).size() == m.options.size(), "its card has a TRY key for each record (%d)" % (_all("try_key", row).size() if row != null else 0))
	await ShotHelper.snap(tree, "challenges_2_log")
	var rep_opt = null
	for o in m.options:
		if str(o.type) == "reps":
			rep_opt = o
	var key = _one("try_key", "reps")
	await _press(key)
	f = _ed()
	var e = f.lift.exercises[0]
	check(int(str(e.sets[0].reps)) == int(rep_opt.reps) and is_equal_approx(float(e.sets[0].weight), Fmt.kg_to_unit(float(rep_opt.kg), App.weight_unit())), "a tap puts it into the first set: %s" % str(rep_opt.words))
	var lit = _one("try_key", "reps")
	check(lit != null and bool(lit.get_meta("try_hit")), "and its key lights up: the set does it")
	await ShotHelper.snap(tree, "challenges_3_hit")

	# --- saved: the challenge is done, claimed from its card ---------------------------------------------------
	for s in f.lift.exercises[0].sets:
		s["done"] = true
	f._ticks_ok = true
	f.save()
	await ShotHelper.wait(tree, 1.0)
	var yes = ShotHelper.find_button(main, "Done as shown")
	if yes != null:
		ShotHelper.press(yes)
	await _dismiss_reels()
	var after = App.quests().daily.filter(func(x): return str(x.id) == str(m.id))
	check(not after.is_empty() and bool(after[0].done) and (after[0].hit as Array).has("reps"), "the challenge is done by the rep record")
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var claim = _one("challenge_claim", str(m.id))
	check(claim != null, "its card has a Claim key")
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "challenges_4_done")
	await _press(claim)
	var claimed = App.quests().daily.filter(func(x): return str(x.id) == str(m.id))
	check(not claimed.is_empty() and bool(claimed[0].claimed), "claimed")
	print("CHALLENGES %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
