extends RefCounted
## A stage's sheet says which of the build's moves hit a weakness that is
## known there (run with the "year" data): a move of a school a foe is known
## to be weak to is lit and marked WEAK; with weaknesses known and no move of
## those schools, a line sends the player to the Moves page; with nothing
## known yet, the moves are simply listed. Prints CHECK lines.

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


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _open(id: String):
	var old = _sheet()
	if old != null:
		old.close()
		await ShotHelper.wait(tree, 0.5)
	RealmMap.open_prep({"kind": "stage", "id": id})
	await ShotHelper.wait(tree, 0.7)
	return _sheet()


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var rpg = RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true)
	rpg.stages["r1s1"] = {"stars": [true, false, false], "wins": 1, "best": 3}
	rpg["seen"] = {}
	App.set_rpg(rpg)
	App.go("realm")
	await ShotHelper.wait(tree, 1.0)
	LootPop.close_all()

	# --- nothing known yet: the moves are listed, none marked ------------------------------------------
	var sh = await _open("r1s2")
	var chips = _all("prep_move", sh)
	var marked = chips.filter(func(c): return int(c.get_meta("prep_move_weak")) > 0)
	check(chips.size() == 4 and marked.is_empty() and _all("prep_moves_tip", sh).is_empty(), "with no weakness known the four moves are listed, none marked (%d chips)" % chips.size())

	# --- every weakness of the stage's foes known ------------------------------------------------------
	var st = RpgWorld.stage("r1s2")
	var known = {}
	rpg = App.rpg().duplicate(true)
	for wave in st.waves:
		for en in wave:
			var fid = str(en.foe)
			rpg.seen[RpgFoes.key_of(fid)] = RpgFoes.weak_of(fid).duplicate()
			for sc in RpgFoes.weak_of(fid):
				known[str(sc)] = true
	App.set_rpg(rpg)
	await ShotHelper.wait(tree, 0.5)
	LootPop.close_all()
	sh = await _open("r1s2")
	chips = _all("prep_move", sh)
	var right = true
	var lit = 0
	for c in chips:
		var mv = RpgMoves.by_id(str(c.get_meta("prep_move")))
		var should = known.has(str(mv.school)) and str(mv.get("kind", "attack")) == "attack" and float(mv.get("power", 0.0)) > 0.0
		if (int(c.get_meta("prep_move_weak")) > 0) != should:
			right = false
		if should:
			lit += 1
	check(right and lit >= 1 and ShotHelper.all_text(sh).contains("WEAK") and ShotHelper.all_text(sh).contains("a weakness here"), "with the foes' weaknesses known (%s), exactly the moves of those schools are marked WEAK (%d)" % [str(known.keys()), lit])
	await ShotHelper.snap(tree, "prep_1_weak_moves")

	# --- weaknesses known, and a build with no move of those schools -----------------------------------
	rpg = App.rpg().duplicate(true)
	var b = RpgSave.build_of(rpg)
	var keep = []
	for mid in b.moves:
		var mv2 = RpgMoves.by_id(str(mid))
		if mv2 != null and not known.has(str(mv2.school)):
			keep.append(str(mid))
	check(not keep.is_empty(), "(the test has a move left that hits no weakness here: %s)" % str(keep))
	rpg.builds[int(rpg.build)]["moves"] = keep
	App.set_rpg(rpg)
	await ShotHelper.wait(tree, 0.5)
	LootPop.close_all()
	sh = await _open("r1s2")
	chips = _all("prep_move", sh)
	check(chips.size() == keep.size() and chips.filter(func(c): return int(c.get_meta("prep_move_weak")) > 0).is_empty() and not _all("prep_moves_tip", sh).is_empty()
		and ShotHelper.all_text(sh).contains("none hits a weakness here"), "a build with no move of those schools is told so, with the way to change it")
	await ShotHelper.snap(tree, "prep_2_no_weak_move")
	if sh != null:
		sh.close()
	await ShotHelper.wait(tree, 0.5)
	print("PREP %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
