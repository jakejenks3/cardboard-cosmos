extends RefCounted
## The Realm tab's first version (run with the "year" data): the twelve stats
## worked out from the log, a stat's sheet, the day's boosts. Prints CHECK lines.

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
		if n.has_meta(meta):
			out.append(n)
	return out


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.go("realm")
	await ShotHelper.wait(tree, 0.8)
	var rows = _all("realm_stat")
	var ids = rows.map(func(r): return str(r.get_meta("realm_stat")))
	check(ids == RpgDefs.STATS, "the Realm tab lists the twelve stats in order (%s)" % str(ids))
	var values = _all("realm_value").map(func(v): return int(v.get_meta("realm_value")))
	check(values.size() == 12 and values.all(func(v): return v >= 1 and v <= 99) and values.any(func(v): return v > 10), "each has a value from 1 to 99, and a year of training shows (%s)" % str(values))
	check(_all("realm_soon").size() == 1 and _all("realm_boost").size() >= 1, "it says the fights are coming, and lists today's boosts (%d)" % _all("realm_boost").size())
	var dots = _all("tab_dot")
	check(dots.is_empty(), "no chest dot on the tab before the hub can open one")
	await ShotHelper.snap(tree, "realm_1_stats")
	ShotHelper.scroll_main(main, 520)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "realm_2_traits")
	ShotHelper.scroll_main(main, 1400)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "realm_3_boosts")
	# A stat's sheet: what it is made of and what raises it.
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.wait(tree, 0.3)
	rows = _all("realm_stat")
	var legs = rows.filter(func(r): return str(r.get_meta("realm_stat")) == "legs")
	if not legs.is_empty():
		ShotHelper.reveal(legs[0])
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, legs[0])
	await ShotHelper.wait(tree, 0.7)
	var sh = _sheet()
	var words = ShotHelper.all_text(sh) if sh != null else ""
	check(sh != null and words.contains("In a fight") and words.contains("Legs"), "a tap on Legs opens its sheet: what it does, what it is made of, what raises it")
	await ShotHelper.snap(tree, "realm_4_stat_sheet")
	if sh != null:
		sh.close()
	await ShotHelper.wait(tree, 0.4)
	App.go("home")
	await ShotHelper.wait(tree, 0.4)
	print("REALM %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
