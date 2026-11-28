extends RefCounted
## Mock-ups of the looks (Kit.LOOKS; run with "year" data): the same screens in every look, each snapped and
## put side by side in one picture a screen (looks_<screen>.png, the looks left to right in Kit.LOOKS' order,
## each with its name on top). Prints CHECK lines (the layout check of every snap).

var main: Node
var tree: SceneTree
var fails = 0
const NAMES = {"stripe": "NOW", "arcade": "A ARCADE", "clean": "B CLEAN", "rpg": "C RPG", "neon": "D NEON"}


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _section(id: String):
	for n in ShotHelper.walk(main):
		if n.has_meta("section") and str(n.get_meta("section")) == id and n is Control and n.is_visible_in_tree():
			return n
	return null


func _grab() -> Image:
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()


func _show(where: String) -> void:
	match where:
		"hero":
			App.go("home")
			await ShotHelper.wait(tree, 0.9)
			ShotHelper.scroll_main(main, 0)
		"challenges", "missions":
			App.go("home")
			await ShotHelper.wait(tree, 0.9)
			var s = _section(where)
			if s != null:
				ShotHelper.reveal(s)
		"history":
			App.set_journey_tab("history")
			App.go("journey")
			await ShotHelper.wait(tree, 0.9)
			ShotHelper.scroll_main(main, 0)
		"stats":
			App.set_journey_tab("stats")
			App.go("journey")
			await ShotHelper.wait(tree, 0.9)
			var w = _section("weekly_sets")
			if w != null:
				ShotHelper.reveal(w)
		"log":
			App.go("log")
			App.open_log(null)
			await ShotHelper.wait(tree, 0.9)
			ShotHelper.scroll_main(main, 0)
	await ShotHelper.wait(tree, 0.6)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var shots = {}
	var screens = ["hero", "challenges", "missions", "history", "stats", "log"]
	for lk in Kit.LOOKS:
		Kit.look = lk
		# The look's name over the top of each picture.
		var tag = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", Kit.sbox(Pal.ACCENT, 4, Pal.OUTLINE, 2, 10, 4))
		tag.add_child(Kit.label(NAMES[lk], 16, Pal.INK, true))
		tag.position = Vector2(150, 6)
		tag.z_index = 100
		Kit.overlay_root.add_child(tag)
		for where in screens:
			await _show(where)
			await ShotHelper.snap(tree, "look_%s_%s" % [lk, where])
			if not shots.has(where):
				shots[where] = []
			shots[where].append(await _grab())
		tag.queue_free()
	Kit.look = "stripe"
	var dir = OS.get_environment("TINY_TITAN_SHOTS")
	for where in screens:
		var imgs = shots[where]
		var w = imgs[0].get_width()
		var h = imgs[0].get_height()
		var gap = 16
		var top = 0
		var out = Image.create(imgs.size() * w + (imgs.size() - 1) * gap, h + top, false, imgs[0].get_format())
		out.fill(Color("0b1126"))
		for i in range(imgs.size()):
			out.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i(i * (w + gap), top))
		out.save_png(dir.path_join("looks_%s.png" % where))
		print("SHOT ", dir.path_join("looks_%s.png" % where))
	print("LOOKS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
