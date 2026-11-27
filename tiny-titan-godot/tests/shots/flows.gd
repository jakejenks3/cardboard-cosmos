extends RefCounted
## The Realm's fights as a player goes through them, one after the other (run
## with the "year" data): win and go on to the next stage, leave a fight half
## way (the app closed) and continue it, flee, lose and try again. After each
## the hub must say what is true: no finished fight offered again, the road's
## places in their right states, what was paid paid once. Prints CHECK lines.

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


func _battle():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion() and not c._closed:
			top = c
	return top


func _state(id: String) -> String:
	var n = _one("map_stage", id)
	return str(n.get_meta("map_state")) if n != null else "?"


## Play the fight on screen to its result with the heuristic (through the view's own _do, as a key would).
func _play(bv, limit_ms: int = 120000) -> void:
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < limit_ms:
		if not bv.busy() and not RpgBattle.over(bv.B):
			bv._do(RpgAi.hero_action(bv.B, "heuristic"))
		elif bv.busy():
			bv.skip()
		await ShotHelper.wait(tree, 0.08)
	await ShotHelper.wait(tree, 0.3)
	if is_instance_valid(bv) and bv.result() != null:
		bv.result().skip()
	await ShotHelper.wait(tree, 0.2)


func _press_result(bv, what: String) -> bool:
	if not is_instance_valid(bv) or bv.result() == null:
		return false
	var k = _one("br_key", what, bv.result())
	if k == null:
		return false
	k.pressed.emit()
	return true


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.set_rpg(RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true))
	App.go("realm")
	await ShotHelper.wait(tree, 0.8)
	LootPop.close_all()

	# --- win, and on to the next stage ---------------------------------------------------------
	var xp0 = int(App.rpg().xp)
	RpgUi.fight({"kind": "stage", "id": "r1s1"})
	await ShotHelper.wait(tree, 0.6)
	var bv = _battle()
	check(bv != null, "r1s1 opens")
	await _play(bv)
	check(is_instance_valid(bv) and RpgBattle.won(bv.B) and bv.result() != null, "r1s1 is won and its result is up")
	var xp1 = int(App.rpg().xp)
	check(xp1 > xp0 and RpgWorld.done(App.rpg(), "r1s1"), "the win is paid and kept (%d XP)" % (xp1 - xp0))
	check(_one("br_key", "next", bv.result()) != null, "the result offers the next stage")
	_press_result(bv, "next")
	await ShotHelper.wait(tree, 1.2)
	var bv2 = _battle()
	check(bv2 != null and bv2 != bv and str(bv2.B.what.get("id", "")) == "r1s2", "Next stage opens r1s2's fight straight away")
	check(int(App.rpg().xp) == xp1, "and nothing was paid twice on the way")

	# --- the app is closed in the middle of it; the hub offers to continue ------------------------
	if bv2 != null:
		await ShotHelper.wait(tree, 1.2)
		bv2.skip()
		bv2._do(RpgAi.hero_action(bv2.B, "heuristic"))
		await ShotHelper.wait(tree, 0.2)
		bv2.skip()
		var turns_mid = int(bv2.B.sum.turns)
		check(RpgUi.kept_battle() != null and not RpgBattle.over(bv2.B), "a fight under way is kept as it goes (turn %d)" % turns_mid)
		# (what closing the app does: the view is gone, its draft stays)
		bv2.queue_free()
		await ShotHelper.wait(tree, 0.4)
		App.rpg_changed.emit()
		await ShotHelper.wait(tree, 0.5)
		var go = _one("realm_continue")
		check(go != null, "the hub offers to continue the battle")
		await ShotHelper.snap(tree, "flows_1_continue")
		if go != null:
			go.pressed.emit()
			await ShotHelper.wait(tree, 0.8)
			var bv3 = _battle()
			check(bv3 != null and str(bv3.B.what.get("id", "")) == "r1s2" and int(bv3.B.sum.turns) == turns_mid, "Continue opens the same fight where it was left")
			await _play(bv3)
			check(is_instance_valid(bv3) and bv3.result() != null and RpgBattle.won(bv3.B), "it is fought to its end")
			var xp2 = int(App.rpg().xp)
			_press_result(bv3, "back")
			await ShotHelper.wait(tree, 0.8)
			check(_battle() == null and _one("realm_continue") == null and RpgUi.kept_battle() == null, "Back: the fight is gone and is not offered again")
			check(int(App.rpg().xp) == xp2 and xp2 > xp1 and _state("r1s2") == "done" and _state("r1s3") == "open", "paid once; the road shows r1s2 done and r1s3 open (%s, %s)" % [_state("r1s2"), _state("r1s3")])

	# --- flee ------------------------------------------------------------------------------------
	RpgUi.fight({"kind": "stage", "id": "r1s3"})
	await ShotHelper.wait(tree, 0.6)
	var bv4 = _battle()
	check(bv4 != null, "r1s3 opens")
	if bv4 != null:
		await ShotHelper.wait(tree, 1.0)
		bv4.skip()
		var xp3 = int(App.rpg().xp)
		bv4._do({"t": "flee"})
		await ShotHelper.wait(tree, 1.5)
		check(_battle() == null and RpgUi.kept_battle() == null and _one("realm_continue") == null, "fleeing leaves the fight and nothing of it is kept")
		check(int(App.rpg().xp) == xp3 and _state("r1s3") == "open", "nothing is paid and the stage is still open")

	# --- lose, and try again ------------------------------------------------------------------------
	RpgUi.fight({"kind": "stage", "id": "r1s3"})
	await ShotHelper.wait(tree, 0.6)
	var bv5 = _battle()
	if bv5 != null:
		await ShotHelper.wait(tree, 1.0)
		bv5.skip()
		# (a hero with one hit point and foes that hit like a wall: the next blow fells him)
		bv5.B.hero["hp"] = 1
		for f in bv5.B.foes:
			f["w"] = 9999.0
			f["hp"] = 99999
			f["hp_max"] = 99999
		bv5._sync()
		var t0 = Time.get_ticks_msec()
		while is_instance_valid(bv5) and bv5.result() == null and Time.get_ticks_msec() - t0 < 30000:
			if not bv5.busy() and not RpgBattle.over(bv5.B):
				bv5._do({"t": "strike", "target": bv5.target})
			elif bv5.busy():
				bv5.skip()
			await ShotHelper.wait(tree, 0.08)
		check(is_instance_valid(bv5) and bv5.result() != null and not RpgBattle.won(bv5.B) and str(bv5.result().get_meta("bv_result", "")) == "loss", "a lost fight shows the result of a loss")
		await ShotHelper.wait(tree, 0.6)
		if is_instance_valid(bv5) and bv5.result() != null:
			bv5.result().skip()
		var tips = _one("br_tips", null, bv5.result()) if is_instance_valid(bv5) and bv5.result() != null else null
		check(tips != null and int(tips.get_meta("br_tips")) >= 1, "the loss says what would help (%s lines)" % (str(tips.get_meta("br_tips")) if tips != null else "no"))
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "flows_2_loss")
		check(_state("r1s3") == "open" and not RpgWorld.done(App.rpg(), "r1s3"), "and nothing is lost: the stage is still open")
		_press_result(bv5, "again")
		await ShotHelper.wait(tree, 1.2)
		var bv6 = _battle()
		check(bv6 != null and bv6 != bv5 and str(bv6.B.what.get("id", "")) == "r1s3" and int(bv6.B.hero.hp) == int(bv6.B.hero.hp_max), "Again opens the same stage anew, the hero whole")
		if bv6 != null:
			await _play(bv6)
			_press_result(bv6, "back")
			await ShotHelper.wait(tree, 0.8)
	check(_battle() == null and _one("realm_continue") == null, "at the end no fight is open and none is offered")
	LootPop.close_all()
	BattleView.auto_kept = false
	print("FLOWS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
