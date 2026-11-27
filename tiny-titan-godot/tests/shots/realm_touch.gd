extends RefCounted
## The Realm under FINGERS (ui/touch_scroll.gd), driven with real touch events
## as a phone sends them (run with the "year" data): a tap on a tab, on the
## road's Go key, on the prep sheet's Fight key, on a move in the fight, on a
## foe, on AUTO, on the message line (its log), on the result's key, on the
## chest (its full-screen moment takes a tap to show all and one to close).
## Every one of them must do what a click does. Prints CHECK lines.

var fails = 0
var main: Node
var tree: SceneTree
var _finger = 40


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _win(p: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * p


func _down(p: Vector2) -> void:
	_finger += 1
	var ev = InputEventScreenTouch.new()
	ev.index = _finger
	ev.pressed = true
	ev.position = _win(p)
	Input.parse_input_event(ev)


func _up(p: Vector2) -> void:
	var ev = InputEventScreenTouch.new()
	ev.index = _finger
	ev.pressed = false
	ev.position = _win(p)
	Input.parse_input_event(ev)


func _tap(c) -> void:
	if c == null or not is_instance_valid(c):
		return
	ShotHelper.reveal(c)
	await ShotHelper.frames(tree, 3)
	var p = c.get_global_rect().get_center()
	_down(p)
	await ShotHelper.wait(tree, 0.07)
	_up(p)
	await ShotHelper.wait(tree, 0.45)


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


func _battle():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion() and not c._closed:
			top = c
	return top


func _wait_idle(bv) -> void:
	var n = 0
	while is_instance_valid(bv) and bv.busy() and n < 300:
		await ShotHelper.wait(tree, 0.05)
		n += 1


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	Engine.max_fps = 120
	var ts = TouchScroll.new()
	main.add_child(ts)
	await ShotHelper.wait(tree, 0.8)
	# A lift today, so a training chest is sure to be there.
	var saved = App.saved.duplicate(true)
	var sets = []
	for i in range(4):
		sets.append({"reps": 6, "weightKg": 70.0})
	saved.sessions.append({"id": "realm_touch", "discipline": "lift", "date": App.today, "createdAt": 1900000000000, "source": "manual", "durationSec": 3000,
		"exercises": [{"name": "Bench Press - Barbell", "sets": sets}, {"name": "Squat - Barbell", "sets": sets}]})
	saved.rpg = RpgSave.empty()
	App.replace_all(saved)
	App.draft_store("battle", null)
	await ShotHelper.wait(tree, 0.5)
	App.set_rpg(RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true))
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()

	# --- the front page: what is new, a tab, the chest ---------------------------------------------
	await _tap(_one("realm_news_ok"))
	check(_one("realm_news") == null, "a tap on \"Got it\" puts the news away")
	await _tap(_one("realm_tab", "hero"))
	check(str(RpgUi.page) == "hero", "a tap on a tab shows its page")
	await _tap(_one("realm_tab", "map"))
	check(str(RpgUi.page) == "map", "and back")
	var ore0 = int(App.rpg().ore)
	await _tap(_one("realm_chest_open", App.today))
	await ShotHelper.wait(tree, 0.4)
	var pop = _one("loot_pop", null, Kit.overlay_root)
	check(int(App.rpg().ore) > ore0 and pop != null, "a tap opens the training chest: its moment takes the screen")
	if pop != null:
		await _tap(pop)
		check(is_instance_valid(pop) and pop.done, "a tap on it shows everything at once")
		await _tap(pop)
		await ShotHelper.wait(tree, 0.4)
		check(_one("loot_pop", null, Kit.overlay_root) == null, "the next tap closes it")
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.5)
	LootPop.close_all()

	# --- the way on: Go, the prep sheet, Fight ---------------------------------------------------------
	await _tap(_one("realm_next_go"))
	var prep = _sheet()
	check(prep != null, "a tap on Go opens the next stage's sheet")
	var fight = null
	if prep != null:
		for b in ShotHelper.walk(prep):
			if b is Button and b.is_visible_in_tree() and str(b.text).strip_edges() == "Fight":
				fight = b
	check(fight != null, "the sheet has its Fight key")
	await _tap(fight)
	await ShotHelper.wait(tree, 1.2)
	var bv = _battle()
	check(bv != null, "a tap on Fight opens the fight")
	if bv == null:
		print("REALM TOUCH %d FAILED" % (fails + 1))
		return
	await _wait_idle(bv)

	# --- in the fight -----------------------------------------------------------------------------------
	var turns0 = int(bv.B.sum.turns)
	var mk = null
	var okay = RpgBattle.options(bv.B).moves.filter(func(mv): return bool(mv.ok)).map(func(mv): return str(mv.id))
	for k in _all("bv_move", bv):
		if okay.has(str(k.get_meta("bv_move"))) and mk == null:
			mk = k
	await _tap(mk)
	check(int(bv.B.sum.turns) > turns0 or RpgBattle.over(bv.B) or bv.busy(), "a tap on a move does it")
	await _wait_idle(bv)
	if not RpgBattle.over(bv.B):
		await _tap(_one("bv_log_key", null, bv))
		var log_sheet = _sheet()
		check(log_sheet != null and _all("bv_log_line", log_sheet).size() >= 1, "a tap on the message line opens what was said")
		if log_sheet != null:
			log_sheet.close()
			await ShotHelper.wait(tree, 0.5)
		var auto_key = _one("bv_key", "auto", bv)
		# (the taught first fight has no AUTO: there the key says so and stays off)
		await _tap(auto_key)
		check(bv.auto != bool(bv._opts.get("tutorial", false)), "a tap on AUTO turns it on (not in the taught fight)")
		var music_key = _one("bv_key", "music", bv)
		var was_on = RpgSfx.music_on()
		await _tap(music_key)
		check(RpgSfx.music_on() != was_on, "a tap on the note switches the music")
		await _tap(music_key)
		check(RpgSfx.music_on() == was_on, "and back")
	# play it out (by AUTO where it is on, else by taps on the first usable key)
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < 90000:
		if not bv.auto and not bv.busy() and not RpgBattle.over(bv.B):
			var ids = RpgBattle.options(bv.B).moves.filter(func(mv): return bool(mv.ok)).map(func(mv): return str(mv.id))
			var key = null
			for k in _all("bv_move", bv):
				if ids.has(str(k.get_meta("bv_move"))) and key == null:
					key = k
			if key == null:
				key = _one("bv_key", "strike", bv)
			await _tap(key)
		else:
			await ShotHelper.wait(tree, 0.2)
	check(is_instance_valid(bv) and bv.result() != null and RpgBattle.won(bv.B), "the fight is won by taps")
	await ShotHelper.wait(tree, 2.5)
	if is_instance_valid(bv) and bv.result() != null:
		await _tap(bv.result())
		await _tap(_one("br_key", "back", bv.result()))
	await ShotHelper.wait(tree, 1.0)
	check(_battle() == null and _one("realm_continue") == null, "a tap on Back leaves the result; nothing is offered to be continued")
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)

	# --- the road's places, the bestiary ----------------------------------------------------------------
	var place = _one("map_stage", "r1s2")
	await _tap(place)
	check(_sheet() != null, "a tap on a place of the road opens its sheet")
	if _sheet() != null:
		_sheet().close()
		await ShotHelper.wait(tree, 0.5)
	await _tap(_one("map_bestiary"))
	check(_sheet() != null and _all("bestiary_foe", _sheet()).size() > 10, "a tap on the bestiary opens it")
	if _sheet() != null:
		_sheet().close()
	await ShotHelper.wait(tree, 0.5)
	BattleView.auto_kept = false
	BattleView.speed_kept = 1
	print("REALM TOUCH %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
