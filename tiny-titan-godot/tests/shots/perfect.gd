extends RefCounted
## A perfect guard on screen (run with the "year" data): the first boss charges
## its Door Slam, the hero guards the blow, and the fight says so: the word,
## the foe's guard a pip lower, the line, the gauge. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _battle():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion() and not c._closed:
			top = c
	return top


func _idle(bv, most: float = 12.0) -> void:
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.busy() and Time.get_ticks_msec() - t0 < int(most * 1000.0):
		await ShotHelper.wait(tree, 0.05)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	for s in range(1, 10):
		var id = "r1s%d" % s
		var st = RpgWorld.stage(id)
		if st is Dictionary and str(st.get("kind", "")) == "cache":
			rpg.caches[id] = true
		else:
			rpg.stages[id] = {"stars": [true, false, false], "wins": 1, "best": 5}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	RpgUi.fight({"kind": "stage", "id": "r1s10"})
	await ShotHelper.wait(tree, 1.5)
	var bv = _battle()
	check(bv != null, "the first boss's fight opens")
	if bv == null:
		print("PERFECT 1 FAILED")
		return
	bv.B.hero["hp_max"] = 99999
	bv.B.hero["hp"] = 99999
	bv._sync()
	var seen = false
	var pips = -1
	var gauge0 = 0.0
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and not RpgBattle.over(bv.B) and Time.get_ticks_msec() - t0 < 100000 and not seen:
		await _idle(bv)
		var foe = null
		for f in RpgBattle.foes(bv.B):
			if bool(f.get("intent", {}).get("charged", false)):
				foe = f
		if foe == null:
			# (a gentle Strike: the boss must live to charge its blow)
			for f in RpgBattle.foes(bv.B):
				f["hp"] = int(f.hp_max)
			bv._do({"t": "strike", "target": str(RpgBattle.foes(bv.B)[0].id)})
			await ShotHelper.wait(tree, 0.2)
			continue
		pips = int(foe.guard)
		gauge0 = float(bv.B.hero.gauge)
		await ShotHelper.snap(tree, "perfect_1_charged")
		bv._do({"t": "guard"})
		var t1 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 8000:
			await ShotHelper.wait(tree, 0.03)
			if str(bv._line.text).begins_with("Perfect guard!"):
				seen = true
				break
		if seen:
			await ShotHelper.wait(tree, 0.14)
			await ShotHelper.snap(tree, "perfect_2_perfect")
			await _idle(bv)
			var now = RpgBattle.unit(bv.B, str(foe.id))
			check(int(RpgBattle.summary(bv.B).perfect) == 1, "the guard that took the charged blow is counted as a perfect guard")
			check(now != null and (int(now.guard) == pips - RpgDefs.PERFECT_CHIP or bool(now.get("broken", false))), "the boss lost a guard pip (%d -> %s)" % [pips, str(now.guard) if now != null else "?"])
			check(float(bv.B.hero.gauge) > gauge0, "the gauge filled (%s -> %s)" % [str(gauge0), str(bv.B.hero.gauge)])
			var said = false
			for l in bv._log:
				if str(l).begins_with("Perfect guard!"):
					said = true
			check(said, "the fight's log keeps the line that said so")
			await ShotHelper.snap(tree, "perfect_3_after")
	check(seen, "a Guard against the boss's charged Door Slam shows a perfect guard")
	check(Engine.time_scale == 1.0, "the clock runs as it should afterwards")
	if is_instance_valid(bv):
		bv.close()
	await ShotHelper.wait(tree, 0.5)
	print("PERFECT %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
