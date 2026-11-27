extends RefCounted
## The Ore Mole on screen (run with the "year" data): a fight opened with a
## seed that brings the mole. Left alone it counts down and digs away (the
## fight says so and goes on). Felled first, it spills its ore and the result
## lists what it paid. Prints CHECK lines.

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


func _idle(bv, most: float = 12.0) -> void:
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.busy() and Time.get_ticks_msec() - t0 < int(most * 1000.0):
		await ShotHelper.wait(tree, 0.05)


func _open(battle_seed: int):
	var what = {"kind": "stage", "id": "r1s2"}
	var st = RpgWorld.stage("r1s2")
	var setup = RpgWorld.setup(what, App.rpg(), RpgUi.hero(), RpgUi.pet(), battle_seed, str(App.today))
	var bv = BattleView.open(setup, {"title": str(st.name), "scene": str(st.get("scene", "rustyard")), "hero": RpgUi.hero_look(),
		"result": func(B, summary): return RpgUi.finish(B, what, summary)})
	await ShotHelper.wait(tree, 1.6)
	return bv


func _mole(bv) -> Variant:
	for f in bv.B.foes:
		if str(f.get("foe", "")) == RpgDefs.TREASURE_FOE:
			return f
	return null


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
	var mole_seed = 0
	for sd in range(1, 400):
		if mole_seed == 0 and not RpgWorld.treasure_entry(RpgWorld.stage("r1s2"), "stage", sd).is_empty():
			mole_seed = sd
	check(mole_seed > 0, "a seed that brings the mole is found (%d)" % mole_seed)

	# --- left alone, it digs away ------------------------------------------------------------------------
	var bv = await _open(mole_seed)
	var m = _mole(bv)
	check(m != null and bv._foes.has(str(m.id)) and bv._foes[str(m.id)].view.is_visible_in_tree(), "the mole stands with the pack")
	bv.B.hero["hp_max"] = 99999
	bv.B.hero["hp"] = 99999
	bv._sync()
	await _idle(bv)
	await ShotHelper.snap(tree, "mole_1_stands")
	var gone = false
	var dug = false
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and not RpgBattle.over(bv.B) and not gone and Time.get_ticks_msec() - t0 < 60000:
		await _idle(bv)
		bv._do({"t": "guard"})
		var t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 6000 and (bv.busy() or Time.get_ticks_msec() - t1 < 200):
			await ShotHelper.wait(tree, 0.04)
			if str(bv._line.text).contains("digs deeper") and not dug:
				dug = true
				await ShotHelper.snap(tree, "mole_2_digs")
			if str(bv._line.text).contains("digs away"):
				gone = true
	await _idle(bv)
	check(dug, "it digs while its count runs down, and the fight says so")
	check(gone and not bool(m.alive) and bool(m.get("fled", false)) and not RpgBattle.over(bv.B), "left alone it digs away, and the fight goes on")
	var said = false
	for l in bv._log:
		if str(l).contains("digs away, ore and all"):
			said = true
	check(said and bool(bv._foes[str(m.id)].view.fainted()), "the log keeps the line, and the mole is gone from the arena")
	await ShotHelper.snap(tree, "mole_3_gone")
	bv.close()
	await ShotHelper.wait(tree, 0.6)

	# --- felled first: its ore ----------------------------------------------------------------------------
	var ore0 = int(App.rpg().ore)
	bv = await _open(mole_seed)
	m = _mole(bv)
	bv.B.hero["hp_max"] = 99999
	bv.B.hero["hp"] = 99999
	bv._sync()
	await _idle(bv)
	m["hp"] = 1
	bv._do({"t": "strike", "target": str(m.id)})
	await ShotHelper.wait(tree, 0.45)
	await ShotHelper.snap(tree, "mole_4_caught")
	await _idle(bv)
	check(not bool(m.alive) and int(RpgBattle.summary(bv.B).treasure) == 1, "felled before its count ran out, the mole is caught")
	t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < 60000:
		if not bv.busy() and not RpgBattle.over(bv.B):
			for f in bv.B.foes:
				if bool(f.get("alive", false)):
					f["hp"] = 1
			bv._do({"t": "strike", "target": str(RpgBattle.foes(bv.B)[0].id)})
		elif bv.busy():
			bv.skip()
		await ShotHelper.wait(tree, 0.06)
	check(is_instance_valid(bv) and bv.result() != null and RpgBattle.won(bv.B), "the fight is won")
	if is_instance_valid(bv) and bv.result() != null:
		bv.result().skip()
		await ShotHelper.wait(tree, 0.4)
		var row = _one("br_treasure", null, bv.result())
		var want = RpgDefs.treasure_ore(float(RpgWorld.stage("r1s2").n))
		check(row != null and int(row.get_meta("br_treasure")) == want and int(App.rpg().ore) >= ore0 + want, "the result lists the mole's ore (%d), and it is paid (%d -> %d)" % [want, ore0, int(App.rpg().ore)])
		await ShotHelper.snap(tree, "mole_5_result")
		var back = _one("br_key", "back", bv.result())
		if back != null:
			back.pressed.emit()
	await ShotHelper.wait(tree, 0.8)
	LootPop.close_all()
	check(Engine.time_scale == 1.0, "the clock runs as it should afterwards")
	print("MOLE %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
