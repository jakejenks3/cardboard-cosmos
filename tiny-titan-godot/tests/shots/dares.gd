extends RefCounted
## A dare on screen (run with the "year" data): a stage that is won offers its
## dare on its sheet; the dare has a sheet of its own (its rule, its foes at
## the player's level, its prize); it is fought and won; the prize is paid
## once, the stage keeps a flame on the road, and the sheet says the dare is
## won. Prints CHECK lines.

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


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	for s in range(1, 6):
		rpg.stages["r1s%d" % s] = {"stars": [true, true, false], "wins": 1, "best": 3}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)

	# --- a won stage offers its dare; one not won does not ---------------------------------------------
	RealmMap.open_prep({"kind": "stage", "id": "r1s2"})
	await ShotHelper.wait(tree, 0.7)
	var sh = _sheet()
	var row = _one("prep_dare", "r1s2", sh) if sh != null else null
	check(row != null and not bool(row.get_meta("prep_dare_won")), "the sheet of a won stage offers its dare")
	await ShotHelper.snap(tree, "dares_1_offer")
	_tap(row)
	await ShotHelper.wait(tree, 0.9)
	sh = _sheet()
	var dare = RpgWorld.dare("r1s2", App.rpg())
	check(sh != null and str(sh.box.get_meta("prep_sheet", "")) == "dare:r1s2" and _one("prep_rule", dare.rule, sh) != null and _one("prep_dare", null, sh) == null,
		"its tap opens the dare's own sheet, with its rule")
	var first_chips = _one("prep_first", null, sh)
	check(first_chips != null and bool(first_chips.get_meta("prep_first")), "and its prize for the first win")
	await ShotHelper.snap(tree, "dares_2_sheet")
	var ore0 = int(App.rpg().ore)
	_tap(_one("prep_fight", "dare:r1s2", sh))
	await ShotHelper.wait(tree, 1.5)
	var bv = _battle()
	check(bv != null and bv.B.what == {"kind": "dare", "id": "dare:r1s2"} and bv.B.rules == dare.rules and absf(float(bv.B.foes[0].n) - float(dare.n)) < 0.001, "the dare is fought: its rule, its foes at the dare's level")
	if bv == null:
		print("DARES 1 FAILED")
		return
	bv.skip()
	bv.B.hero["hp_max"] = 99999
	bv.B.hero["hp"] = 99999
	bv._sync()
	await ShotHelper.snap(tree, "dares_3_fight")
	var t0 = Time.get_ticks_msec()
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < 90000:
		if not bv.busy() and not RpgBattle.over(bv.B):
			for f in bv.B.foes:
				if bool(f.get("alive", false)):
					f["hp"] = 1
			bv._do(RpgAi.hero_action(bv.B, "heuristic"))
		elif bv.busy():
			bv.skip()
		await ShotHelper.wait(tree, 0.06)
	check(is_instance_valid(bv) and bv.result() != null and RpgBattle.won(bv.B), "it is won")
	if is_instance_valid(bv) and bv.result() != null:
		bv.result().skip()
		await ShotHelper.wait(tree, 0.4)
		check(_one("br_key", "next", bv.result()) == null and _one("br_key", "again", bv.result()) != null, "its result offers Again, and no next stage")
		await ShotHelper.snap(tree, "dares_4_result")
		_tap(_one("br_key", "back", bv.result()))
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.4)
	var now = App.rpg()
	check(RpgWorld.dared(now, "r1s2") and int(now.ore) >= ore0 + int(dare.first.ore) and int(now.stages.r1s2.wins) == 1, "the dare is kept on its stage and its prize is paid (%d -> %d ore)" % [ore0, int(now.ore)])
	var place = _one("map_stage", "r1s2")
	check(place != null and bool(place.get_meta("map_stage_dare", false)) and not bool(_one("map_stage", "r1s3").get_meta("map_stage_dare", false)), "the road shows a flame on that stage, and on no other")
	if place != null:
		ShotHelper.reveal(place)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "dares_5_road")
	RealmMap.open_prep({"kind": "stage", "id": "r1s2"})
	await ShotHelper.wait(tree, 0.7)
	sh = _sheet()
	row = _one("prep_dare", "r1s2", sh) if sh != null else null
	check(row != null and bool(row.get_meta("prep_dare_won")), "and the stage's sheet says its dare is won")
	if sh != null:
		sh.close()
	await ShotHelper.wait(tree, 0.5)
	RealmMap.open_prep({"kind": "stage", "id": "r1s7"})
	await ShotHelper.wait(tree, 0.7)
	sh = _sheet()
	check(sh != null and _one("prep_dare", null, sh) == null, "a stage that is not won has no dare")
	if sh != null:
		sh.close()
	await ShotHelper.wait(tree, 0.5)
	print("DARES %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
