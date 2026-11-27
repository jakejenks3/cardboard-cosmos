extends RefCounted
## A fight of the Realm on screen (run with the "year" data): a pack in the
## Rustyard played by real key presses to its result, then a boss's opening.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root: Node) -> Array:
	var out = []
	for n in ShotHelper.walk(root):
		if n.has_meta(meta):
			out.append(n)
	return out


func _open(stage_id: String, seed: int):
	var input = RealmScreen.sheet_input()
	var rpg = App.rpg()
	var owned = {"items": App.state.items, "pets": App.state.pets}
	var hero = RpgHero.build(RpgStats.sheet(input), RpgBoosts.active(input), rpg, owned)
	var pet = RpgHero.pet_unit(rpg, owned, int(RpgDefs.level_of(int(rpg.xp)).lvl))
	var st = RpgWorld.stage(stage_id)
	var setup = RpgWorld.setup({"kind": "stage", "id": stage_id}, rpg, hero, pet, seed, App.today)
	return BattleView.open(setup, {"title": str(st.name), "scene": str(RpgWorld.region_of(stage_id)), "tutorial": stage_id == "r1s1",
		"hero": {"state": App.state, "profile": App.saved.profile, "loadout": App.loadout(), "pet": App.active_pet()}})


func _wait_idle(bv) -> void:
	var n = 0
	# By the clock, not by frames: with no vsync a PC draws a thousand frames a second.
	while is_instance_valid(bv) and bv.busy() and n < 400:
		await ShotHelper.wait(tree, 0.05)
		n += 1


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.set_rpg(RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true))
	App.go("realm")
	await ShotHelper.wait(tree, 0.5)
	# --- the taught first fight ---------------------------------------------------------------
	var bv = _open("r1s1", 3)
	await ShotHelper.wait(tree, 1.2)
	await _wait_idle(bv)
	check(is_instance_valid(bv) and _all("bv_move", bv).size() >= 4 and _all("bv_foe", bv).size() >= 1, "the battle opens with its move keys and a foe")
	await ShotHelper.snap(tree, "battle_1_first_fight")
	var turns = 0
	while is_instance_valid(bv) and not RpgBattle.over(bv.B) and turns < 40:
		var keys = _all("bv_move", bv).filter(func(k): return k is BaseButton and not k.disabled)
		var opts = RpgBattle.options(bv.B)
		var ok_ids = opts.moves.filter(func(m): return bool(m.ok)).map(func(m): return str(m.id))
		var pick = null
		for k in keys:
			if ok_ids.has(str(k.get_meta("bv_move"))):
				pick = k
				break
		if pick == null:
			for k in _all("bv_key", bv):
				if str(k.get_meta("bv_key")) == "strike":
					pick = k
		pick.pressed.emit()
		await ShotHelper.wait(tree, 0.5)
		if turns == 0:
			await ShotHelper.snap(tree, "battle_2_mid_action")
		await _wait_idle(bv)
		turns += 1
	check(is_instance_valid(bv) and RpgBattle.over(bv.B) and RpgBattle.won(bv.B), "played by its keys, the first fight is won (%d turns)" % turns)
	await ShotHelper.wait(tree, 2.5)
	await ShotHelper.snap(tree, "battle_3_result")
	if is_instance_valid(bv):
		bv.close()
	await ShotHelper.wait(tree, 0.6)
	# --- a pack of three, a turn in -----------------------------------------------------------
	bv = _open("r1s7", 5)
	await ShotHelper.wait(tree, 1.2)
	await _wait_idle(bv)
	await ShotHelper.snap(tree, "battle_4_pack")
	var foes = _all("bv_foe", bv)
	if foes.size() > 1:
		await ShotHelper.click(tree, foes[1])
		await ShotHelper.wait(tree, 0.4)
	var mk = _all("bv_move", bv)
	if not mk.is_empty():
		mk[0].pressed.emit()
	await ShotHelper.wait(tree, 0.6)
	await _wait_idle(bv)
	await ShotHelper.snap(tree, "battle_5_pack_turn2")
	if is_instance_valid(bv):
		bv.close()
	await ShotHelper.wait(tree, 0.6)
	# --- the first boss ---------------------------------------------------------------------
	bv = _open("r1s10", 9)
	await ShotHelper.wait(tree, 1.2)
	await _wait_idle(bv)
	await ShotHelper.snap(tree, "battle_6_boss")
	if is_instance_valid(bv):
		bv.close()
	await ShotHelper.wait(tree, 0.5)
	print("BATTLE %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
