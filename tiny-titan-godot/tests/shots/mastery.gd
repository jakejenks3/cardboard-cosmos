extends RefCounted
## Move mastery on screen (run with the "year" data): the Moves page shows a
## move's stars, what they give and how far the next is; a fight counts the
## uses; the use that earns a star is said in the result, and the page shows
## the new star afterwards. Prints CHECK lines.

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


func _mastery_of(id: String) -> int:
	for n in _all("move_mastery_of"):
		if str(n.get_meta("move_mastery_of")) == id and n is Control and n.is_visible_in_tree():
			return int(n.get_meta("move_mastery"))
	return -1


func _page(id: String) -> void:
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.wait(tree, 0.5)
	var tab = _one("realm_tab", id)
	if tab != null:
		await ShotHelper.click(tree, tab)
	await ShotHelper.wait(tree, 0.7)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	rpg.stages["r1s1"] = {"stars": [true, true, true], "wins": 1, "best": 2}
	# Stomp is one use short of its second star, Yank is mastered, Shove has a few uses, Deep Breath none.
	rpg["mastery"] = {"stomp": RpgDefs.MASTERY_AT[1] - 1, "yank": RpgDefs.MASTERY_AT[2], "shove": 3}
	# (a hardest hit of 1 on record: the fight's first hit beats it)
	rpg["tally"] = {"best_hit": 1}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()
	await _page("moves")
	check(_mastery_of("stomp") == 1 and _mastery_of("yank") == 3 and _mastery_of("shove") == 0 and _mastery_of("deep_breath") == 0,
		"the Moves page shows every equipped move's mastery (stomp %d, yank %d, shove %d, deep breath %d)" % [_mastery_of("stomp"), _mastery_of("yank"), _mastery_of("shove"), _mastery_of("deep_breath")])
	var texts = ShotHelper.all_text(main)
	check(texts.contains("Practiced") and texts.contains("+3% damage") and texts.contains("Mastered") and texts.contains("+9% damage") and texts.contains("Mastery: 3 of %d uses" % RpgDefs.MASTERY_AT[0]),
		"with its name, what it gives and the uses to the next star")
	var pw = null
	for n in _all("move_power"):
		if n is Control and n.is_visible_in_tree() and pw == null and str(n.get_parent().get_parent().get_child(1).get_meta("move_mastery_of", "")) == "yank":
			pw = n
	var base = float(RpgMoves.by_id("yank").power)
	check(pw != null and absf(float(pw.get_meta("move_power")) - base * (1.0 + 3.0 * RpgDefs.MASTERY_PCT)) < 0.001, "a mastered move's Power is the power it is played at (%s, plain %s)" % [str(pw.get_meta("move_power")) if pw != null else "?", str(base)])
	await ShotHelper.snap(tree, "mastery_1_moves")

	# --- a fight: one Stomp is the use that earns the second star ----------------------------------------
	RpgUi.fight({"kind": "stage", "id": "r1s2"})
	await ShotHelper.wait(tree, 1.5)
	var bv = _battle()
	check(bv != null, "a fight opens")
	if bv == null:
		print("MASTERY 1 FAILED")
		return
	bv.skip()
	bv.B.hero["hp_max"] = 99999
	bv.B.hero["hp"] = 99999
	bv._sync()
	var plain_row = RpgMoves.by_id("stomp")
	var played = RpgBattle.move_row(bv.B, "stomp")
	check(absf(float(played.power) - float(plain_row.power) * (1.0 + RpgDefs.MASTERY_PCT)) < 0.001, "the fight plays Stomp at its first star (power %s, plain %s)" % [str(played.power), str(plain_row.power)])
	var k_stomp = null
	var k_yank = null
	var k_breath = null
	for n in ShotHelper.walk(bv):
		if n.has_meta("bv_move"):
			match str(n.get_meta("bv_move")):
				"stomp":
					k_stomp = n
				"yank":
					k_yank = n
				"deep_breath":
					k_breath = n
	check(k_stomp != null and int(k_stomp.get_meta("bv_mastery")) == 1 and k_stomp._stars.visible and int(k_yank.get_meta("bv_mastery")) == 3 and int(k_breath.get_meta("bv_mastery")) == 0 and not k_breath._stars.visible
		and k_stomp.get_global_rect().encloses(k_stomp._stars.get_global_rect()), "the fight's move keys show their stars (stomp 1, yank 3, deep breath none)")
	await ShotHelper.snap(tree, "mastery_1b_keys")
	var foes = RpgBattle.foes(bv.B)
	bv._do({"t": "move", "id": "stomp", "target": str(foes[0].id)})
	var t0 = Time.get_ticks_msec()
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
		var row = _one("br_mastery", "stomp", bv.result())
		check(row != null and ShotHelper.all_text(bv.result()).contains("Stomp: Seasoned") and ShotHelper.all_text(bv.result()).contains("+6% damage"), "the result says Stomp reached its second star, and what that gives")
		var rec = _one("br_record", null, bv.result())
		check(rec != null and int(rec.get_meta("br_record")) == int(App.rpg().tally.best_hit) and int(App.rpg().tally.best_hit) > 1 and ShotHelper.all_text(bv.result()).contains("Your hardest hit ever"),
			"the result says the hardest hit ever was beaten (%d)" % int(App.rpg().tally.get("best_hit", 0)))
		await ShotHelper.snap(tree, "mastery_2_result")
		var back = _one("br_key", "back", bv.result())
		if back != null:
			back.pressed.emit()
	await ShotHelper.wait(tree, 1.0)
	check(int(App.rpg().mastery.get("stomp", 0)) == RpgDefs.MASTERY_AT[1], "the use is kept (%d)" % int(App.rpg().mastery.get("stomp", 0)))
	LootPop.close_all()
	await _page("moves")
	check(_mastery_of("stomp") == 2, "and the Moves page shows the new star (%d)" % _mastery_of("stomp"))
	await ShotHelper.snap(tree, "mastery_3_after")
	print("MASTERY %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
