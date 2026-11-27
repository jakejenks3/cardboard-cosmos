extends RefCounted
## The practice yard on screen (run with the "year" data): its row at the foot
## of the Map opens a fight against the sparring post; the post winds up, a
## Guard on the turn its blow lands is a perfect guard; fleeing leaves it;
## nothing of it is kept (no XP, ore, mastery, count, nor a fight to continue).
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _one(meta: String, value = null, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and not n.is_queued_for_deletion() and (value == null or str(n.get_meta(meta)) == str(value)):
			return n
	return null


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


func _idle(bv, most: float = 12.0) -> void:
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.busy() and Time.get_ticks_msec() - t0 < int(most * 1000.0):
		await ShotHelper.wait(tree, 0.05)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	rpg.stages["r1s1"] = {"stars": [true, false, false], "wins": 1, "best": 3}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)
	var before = App.rpg().duplicate(true)

	var row = _one("realm_practice")
	check(row != null, "the Map has the practice yard's row")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.wait(tree, 0.5)
		await ShotHelper.snap(tree, "yard_1_row")
	_tap(_one("realm_practice"))
	await ShotHelper.wait(tree, 1.6)
	var bv = _battle()
	check(bv != null and str(bv.B.what.get("kind", "")) == "practice" and bv.B.foes.size() == 1 and str(bv.B.foes[0].foe) == RpgWorld.PRACTICE_FOE, "its tap opens the fight against the sparring post")
	if bv == null:
		print("YARD 1 FAILED")
		return
	await _idle(bv)
	var opened = false
	for l in bv._log:
		if str(l).begins_with("Practice:"):
			opened = true
	check(opened, "the fight begins with what the yard is for")
	await ShotHelper.snap(tree, "yard_2_fight")
	var perfect = false
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and not RpgBattle.over(bv.B) and not perfect and Time.get_ticks_msec() - t0 < 90000:
		await _idle(bv)
		var charged = bool(bv.B.foes[0].get("intent", {}).get("charged", false))
		bv._do({"t": "guard"} if charged else {"t": "strike", "target": str(bv.B.foes[0].id)})
		var t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 8000 and (bv.busy() or Time.get_ticks_msec() - t1 < 200):
			await ShotHelper.wait(tree, 0.04)
			if str(bv._line.text).begins_with("Perfect guard!") and not perfect:
				perfect = true
				await ShotHelper.wait(tree, 0.12)
				await ShotHelper.snap(tree, "yard_3_perfect")
	await _idle(bv)
	check(perfect and int(RpgBattle.summary(bv.B).perfect) >= 1, "a Guard on the turn the post's blow lands is a perfect guard")
	var flee = _one("bv_key", "flee", bv)
	check(flee != null, "the fight has its Flee key")
	_tap(flee)
	await ShotHelper.wait(tree, 1.0)
	# (a flee may ask first: the sheet's own key says yes)
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			for b in ShotHelper.walk(c):
				if b is Button and b.is_visible_in_tree() and str(b.text).to_lower().contains("flee"):
					b.pressed.emit()
	await ShotHelper.wait(tree, 1.5)
	if _battle() != null and _battle().result() != null:
		_tap(_one("br_key", "back", _battle().result()))
		await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.5)
	var after = App.rpg()
	check(_battle() == null and _one("realm_continue") == null, "leaving it leaves nothing to continue")
	check(int(after.xp) == int(before.xp) and int(after.ore) == int(before.ore) and after.get("mastery", {}) == before.get("mastery", {}) and after.get("tally", {}) == before.get("tally", {})
		and after.stages == before.stages and after.get("seen", {}) == before.get("seen", {}), "and nothing of it is kept: no XP, ore, mastery, counts or weaknesses")
	check(Engine.time_scale == 1.0, "the clock runs as it should afterwards")
	print("YARD %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
