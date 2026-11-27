extends RefCounted
## The Realm with a log of the player's own (not the demo's): the save or
## backup file named by the environment variable REALM_OWN_SAVE is loaded into
## THIS RUN'S throwaway data folder (TINY_TITAN_DATA; the walkthrough runner
## has already put demo data there, which is replaced), and the Realm is
## walked through with it: the first visit, the hub, the Hero page, the first
## fight on AUTO, the first boss on AUTO. The file is only read. Nothing of it
## is in this script, and its pictures stay in the run's own shots folder.
## Prints CHECK lines and the numbers that matter (stats, power, how the
## fights went).

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
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion():
			return c
	return null


## A stage's fight as it would be now, opened straight (nothing is paid for it).
func _open(stage_id: String, seed: int):
	var rpg = App.rpg()
	var st = RpgWorld.stage(stage_id)
	var setup = RpgWorld.setup({"kind": "stage", "id": stage_id}, rpg, RpgUi.hero(), RpgUi.pet(), seed, App.today)
	return BattleView.open(setup, {"title": str(st.name), "scene": str(RpgWorld.region_of(stage_id)), "hero": RpgUi.hero_look()})


## Let a fight play itself out on AUTO; returns its view (the result is up) or null.
func _auto_fight(label: String, limit_ms: int = 150000):
	var bv = _battle()
	if bv == null:
		check(false, "%s: the fight opens" % label)
		return null
	await ShotHelper.wait(tree, 1.6)
	for k in _all("bv_key", bv):
		if str(k.get_meta("bv_key")) == "auto" and not bv.auto:
			k.pressed.emit()
	if not bv.auto:
		# (the taught first fight has no AUTO: play it by its first usable key)
		pass
	var t0 = Time.get_ticks_msec()
	var snapped = false
	while is_instance_valid(bv) and bv.result() == null and Time.get_ticks_msec() - t0 < limit_ms:
		if not bv.auto and not bv.busy() and not RpgBattle.over(bv.B):
			var a = RpgAi.hero_action(bv.B, "heuristic")
			bv._do(a)
		await ShotHelper.wait(tree, 0.25)
		if not snapped and Time.get_ticks_msec() - t0 > 4000:
			snapped = true
			await ShotHelper.snap(tree, "own_%s_fight" % label)
	if not is_instance_valid(bv) or bv.result() == null:
		check(false, "%s: the fight comes to its result" % label)
		return bv
	var s = RpgBattle.summary(bv.B)
	print("OWN %s: %s in %d turns, dealt %d, taken %d of %d HP" % [label, "WON" if RpgBattle.won(bv.B) else "lost", int(s.get("turns", 0)), int(s.get("dealt", 0)), int(s.get("taken", 0)), int(bv.B.hero.hp_max)])
	await ShotHelper.wait(tree, 3.0)
	await ShotHelper.snap(tree, "own_%s_result" % label)
	return bv


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	var path = OS.get_environment("REALM_OWN_SAVE")
	if path == "" or not FileAccess.file_exists(path):
		print("OWN: set REALM_OWN_SAVE to a save or backup file kept outside the project")
		return
	if OS.get_environment("TINY_TITAN_DATA") == "":
		print("OWN: no throwaway data folder, nothing is done")
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw is Dictionary and raw.get("save") is Dictionary:
		raw = raw.save
	var parsed = App.parse_saved(raw)
	check(parsed != null, "the file is a save")
	if parsed == null:
		return
	var today = OS.get_environment("REALM_OWN_TODAY")
	App.replace_all(parsed)
	if today != "":
		App.today = today
		App.changed.emit()
	await ShotHelper.wait(tree, 1.0)
	print("OWN sessions %d, today %s, realm opened %s" % [App.sessions().size(), str(App.today), str(App.rpg().get("opened", false))])
	App.go("realm")
	await ShotHelper.wait(tree, 4.5)
	await ShotHelper.snap(tree, "own_1_first")
	var sheet = RpgUi.sheet()
	var words = []
	for id in RpgDefs.STATS:
		words.append("%s %d" % [str(id), int(sheet.stats[id].v)])
	print("OWN stats: %s" % ", ".join(words))
	print("OWN boosts: %s" % str(RpgUi.boosts().map(func(b): return str(b.name))))
	print("OWN gains: %s" % str(RpgUi.gains()))
	print("OWN points: %s, power %d" % [str(RpgUi.points()), int(round(RpgHero.power(RpgUi.hero())))])
	# In: the taught first fight, played by the heuristic.
	var enter = _one("first_enter")
	if enter != null:
		enter.pressed.emit()
		await ShotHelper.wait(tree, 1.0)
		var bv = await _auto_fight("first")
		if bv != null and is_instance_valid(bv) and bv.result() != null:
			var back = _one("br_key", "back", bv.result())
			if back != null:
				back.pressed.emit()
		await ShotHelper.wait(tree, 1.2)
	LootPop.close_all()
	await ShotHelper.wait(tree, 0.5)
	check(_one("section", "realm_banner") != null, "the hub is shown")
	check(_one("realm_continue") == null and RpgUi.kept_battle() == null, "a fight that is over and left is not offered to be continued")
	await ShotHelper.snap(tree, "own_2_hub")
	var tab = _one("realm_tab", "hero")
	if tab != null:
		tab.pressed.emit()
		await ShotHelper.wait(tree, 0.8)
		await ShotHelper.snap(tree, "own_3_hero")
		_one("realm_tab", "map").pressed.emit()
		await ShotHelper.wait(tree, 0.8)
	# The first boss with nothing learned and nothing upgraded: how hard is the wall?
	for stage in ["r1s2", "r1s10"]:
		_open(stage, 7)
		await ShotHelper.wait(tree, 0.8)
		var bv2 = await _auto_fight(stage)
		if bv2 != null and is_instance_valid(bv2):
			bv2.close()
		await ShotHelper.wait(tree, 1.0)
		LootPop.close_all()
	BattleView.auto_kept = false
	print("OWN %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
