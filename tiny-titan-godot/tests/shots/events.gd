extends RefCounted
## The Realm's fights that are not stages of the road, played through as a
## player would (run with the "year" data): the daily hunt (the fight, its
## prize, what the map says after), the week's rival, a floor of the Spire.
## Each is opened from the map's own row, fought by the heuristic with a hero
## made strong enough to win, and the hub must then say what is true.
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
		if n.has_meta(meta) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _battle():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion() and not c._closed:
			top = c
	return top


func _tap(c) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if c is BaseButton:
		c.pressed.emit()
		return true
	if c.get("_tap") is Callable and c._tap.is_valid():
		c._tap.call()
		return true
	return false


func _fight_key(sheet):
	if sheet == null:
		return null
	for b in ShotHelper.walk(sheet):
		if b is Button and b.is_visible_in_tree() and str(b.text).strip_edges() == "Fight":
			return b
	return null


## Win the fight on screen: the hero is made too strong to lose, the heuristic plays, the result is left by Back.
func _win(label: String) -> bool:
	var bv = _battle()
	if bv == null:
		check(false, "%s: its fight opens" % label)
		return false
	await ShotHelper.wait(tree, 1.0)
	bv.skip()
	bv.B.hero["hp_max"] = 999999
	bv.B.hero["hp"] = 999999
	bv._sync()
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < 90000:
		if not bv.busy() and not RpgBattle.over(bv.B):
			# (every foe standing is one blow from falling: this is about what follows a win, not the fight)
			for f in bv.B.foes:
				if bool(f.get("alive", false)):
					f["hp"] = 1
			bv._do(RpgAi.hero_action(bv.B, "heuristic"))
		elif bv.busy():
			bv.skip()
		await ShotHelper.wait(tree, 0.06)
	var won = is_instance_valid(bv) and bv.result() != null and RpgBattle.won(bv.B)
	check(won, "%s: it is won and its result is up" % label)
	await ShotHelper.wait(tree, 0.3)
	if is_instance_valid(bv) and bv.result() != null:
		bv.result().skip()
		await ShotHelper.frames(tree, 3)
		var shown = bv.result()._fact_labels.map(func(l): return str(l.text))
		var want = [Xp.fmt_int(int(bv.result().summary.turns)), Xp.fmt_int(int(bv.result().summary.dealt)), Xp.fmt_int(int(bv.result().summary.taken))]
		check(shown == want, "%s: a tap on the result shows its numbers at once (%s)" % [label, str(shown)])
		await ShotHelper.snap(tree, "events_%s_result" % label)
		var back = _one("br_key", "back", bv.result())
		if back != null:
			back.pressed.emit()
	await ShotHelper.wait(tree, 1.0)
	check(_battle() == null and _one("realm_continue") == null, "%s: Back leaves it, and it is not offered again" % label)
	return won


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# A Realm two regions in: the Spire opens when the Greenmile's boss has fallen.
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	for r in [1, 2]:
		for s in range(1, 11):
			var id = "r%ds%d" % [r, s]
			var st = RpgWorld.stage(id)
			if st is Dictionary and str(st.get("kind", "")) == "cache":
				rpg.caches[id] = true
			else:
				rpg.stages[id] = {"stars": [true, true, false], "wins": 1, "best": 5}
	# (yesterday's hunt was won, the second day in a row: today's win makes it three)
	rpg["hunt"] = {"date": Dates.add_days(str(App.today), -1), "won": true, "streak": 2, "best": 2}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)
	check(RpgWorld.spire_open(App.rpg()) and str(_all("map_stage")[0].get_meta("map_stage")) == "r3s1", "two regions in: the road is at r3s1 and the Spire is open")

	# --- the daily hunt -------------------------------------------------------------------------------
	var hunt = _one("map_hunt")
	check(hunt != null and str(hunt.get_meta("map_hunt_state")) == "open", "the hunt of the day is open")
	check(hunt != null and int(hunt.get_meta("map_hunt_streak")) == 2 and ShotHelper.all_text(hunt).contains("2 days"), "its row shows the hunt streak that is alive (2 days)")
	var ore0 = int(App.rpg().ore)
	var xp0 = int(App.rpg().xp)
	_tap(hunt)
	await ShotHelper.wait(tree, 0.6)
	var prep = _sheet()
	check(prep != null and _fight_key(prep) != null, "its row opens a sheet with a Fight key")
	await ShotHelper.snap(tree, "events_1_hunt_prep")
	_tap(_fight_key(prep))
	await ShotHelper.wait(tree, 1.0)
	if await _win("hunt"):
		LootPop.close_all()
		await ShotHelper.wait(tree, 0.4)
		hunt = _one("map_hunt")
		check(bool(App.rpg().hunt.won) and str(App.rpg().hunt.date) == str(App.today) and int(App.rpg().xp) > xp0, "the hunt's win is kept for today and paid")
		check(int(App.rpg().hunt.streak) == 3 and int(App.rpg().hunt.best) == 3 and hunt != null and int(hunt.get_meta("map_hunt_streak")) == 3, "and it is the third day of the streak (%s)" % str(App.rpg().hunt))
		check(hunt != null and ["prize", "won"].has(str(hunt.get_meta("map_hunt_state"))), "the map says the hunt is won (%s)" % (str(hunt.get_meta("map_hunt_state")) if hunt != null else "?"))
		var prize_key = _one("map_hunt_prize")
		if prize_key != null:
			_tap(prize_key)
			await ShotHelper.wait(tree, 0.6)
			var ps = _sheet()
			var picks = _all("prize_pick", ps) if ps != null else []
			if picks.is_empty() and ps != null:
				for c in ShotHelper.walk(ps):
					if c.get("_tap") is Callable and c._tap.is_valid():
						picks.append(c)
			check(ps != null and not picks.is_empty(), "the Prize key opens the prizes to pick one from (%d)" % picks.size())
			await ShotHelper.snap(tree, "events_2_prizes")
			if not picks.is_empty():
				_tap(picks[0])
				await ShotHelper.wait(tree, 1.0)
				check(_one("loot_pop", null, Kit.overlay_root) != null, "taking a prize is a moment of its own")
				LootPop.close_all()
				await ShotHelper.wait(tree, 0.5)
				check(_one("map_hunt_prize") == null and str(_one("map_hunt").get_meta("map_hunt_state")) == "won", "and the prize is gone from the map: the hunt is simply won")
		await _close_sheets()

	# --- the week's rival ---------------------------------------------------------------------------
	var rival = _one("map_rival")
	check(rival != null and str(rival.get_meta("map_rival_state")) == "open", "the week's rival waits")
	_tap(rival)
	await ShotHelper.wait(tree, 0.6)
	prep = _sheet()
	check(prep != null and _fight_key(prep) != null, "its row opens a sheet with a Fight key")
	_tap(_fight_key(prep))
	await ShotHelper.wait(tree, 1.0)
	if await _win("rival"):
		LootPop.close_all()
		await ShotHelper.wait(tree, 0.4)
		rival = _one("map_rival")
		check(bool(App.rpg().rival.won) and rival != null and str(rival.get_meta("map_rival_state")) == "won", "the rival is beaten for this week, and the map says so")
	await _close_sheets()

	# --- a floor of the Spire --------------------------------------------------------------------------
	var best0 = int(App.rpg().spire.best)
	var spire_key = _one("map_spire_fight")
	check(spire_key != null, "the Spire has its Fight key")
	if spire_key != null:
		ShotHelper.reveal(spire_key)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "events_3_spire")
		_tap(spire_key)
		await ShotHelper.wait(tree, 1.0)
		if await _win("spire"):
			LootPop.close_all()
			await ShotHelper.wait(tree, 0.4)
			check(int(App.rpg().spire.best) == best0 + 1, "a floor won is the best floor (%d)" % int(App.rpg().spire.best))
			var row = _one("map_spire")
			check(row != null and int(row.get_meta("map_spire")) == best0 + 2, "and the Spire offers the next one")
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)

	# --- the Spire's blessings: five floors climbed, one of three to pick ------------------------------
	var up = App.rpg().duplicate(true)
	up.spire["best"] = 5
	App.set_rpg(up)
	await ShotHelper.wait(tree, 0.8)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)
	var brow = _one("map_bless")
	var pick = _one("bless_pick")
	check(brow != null and int(brow.get_meta("map_bless")) == 0 and int(brow.get_meta("map_bless_owed")) == 1 and pick != null, "five floors of the Spire climbed: a blessing is owed, and its key is there")
	if pick != null:
		ShotHelper.reveal(pick)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "events_4_blessing_owed")
		_tap(pick)
		await ShotHelper.wait(tree, 0.7)
		var bs = _sheet()
		var opts = _all("bless_option", bs) if bs != null else []
		check(bs != null and opts.size() == 3, "its key opens three blessings to pick from (%d)" % opts.size())
		await ShotHelper.snap(tree, "events_5_blessings")
		if not opts.is_empty():
			var took = str(opts[0].get_meta("bless_option"))
			_tap(opts[0])
			await ShotHelper.wait(tree, 1.0)
			check(_one("loot_pop", null, Kit.overlay_root) != null, "taking one is a moment of its own")
			LootPop.close_all()
			await ShotHelper.wait(tree, 0.6)
			brow = _one("map_bless")
			check(RpgWorld.blessings_held(App.rpg()) == {took: 1} and brow != null and int(brow.get_meta("map_bless")) == 1 and int(brow.get_meta("map_bless_owed")) == 0 and _one("bless_pick") == null
				and _one("bless_held", took) != null, "it is held, shown on the Spire's card, and none is owed now (%s)" % took)
			spire_key = _one("map_spire_fight")
			if spire_key != null:
				_tap(spire_key)
				await ShotHelper.wait(tree, 1.2)
				var bv2 = _battle()
				var carried = bv2 != null and bv2.B.hero.fx.size() == RpgUi.hero().fx.size() + RpgDefs.BLESSINGS[took].fx.size()
				check(carried, "the next Spire fight carries it")
				if bv2 != null:
					bv2.close()
				await ShotHelper.wait(tree, 0.6)
	LootPop.close_all()
	BattleView.auto_kept = false
	print("EVENTS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
