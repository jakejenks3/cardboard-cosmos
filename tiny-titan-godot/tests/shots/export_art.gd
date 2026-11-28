extends RefCounted
## Saves the game's own art as PNG files for design mock-ups (run with "year" data): the hero (and the hero in
## the gym), a few companions, and the pixel icons, at whole-number scales, into $TINY_TITAN_SHOTS/art/.
## Nothing on screen is checked.

var main: Node
var tree: SceneTree


func _save(tex: Texture2D, path: String, scale: int) -> void:
	if tex == null:
		return
	var img = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(path)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var dir = OS.get_environment("TINY_TITAN_SHOTS").path_join("art")
	DirAccess.make_dir_recursive_absolute(dir)
	_save(Art.hero_texture(App.state, App.profile(), App.loadout()), dir.path_join("hero.png"), 4)
	_save(Art.hero_texture(App.state, App.profile(), App.loadout(), "idle", 0, true), dir.path_join("hero_happy.png"), 4)
	_save(Art.scene_texture(App.state, App.profile(), App.loadout(), App.active_pet()), dir.path_join("hero_gym.png"), 3)
	for pid in ["owl", "cat", "dog", "fox", "slime", "dragon"]:
		if Pets.by_id(pid) != null:
			_save(Art.pet_texture(pid), dir.path_join("pet_%s.png" % pid), 4)
	for nm in Icons.names():
		_save(Icons.tex(str(nm)), dir.path_join("icon_%s.png" % str(nm)), 4)
	print("ART saved to ", dir)
