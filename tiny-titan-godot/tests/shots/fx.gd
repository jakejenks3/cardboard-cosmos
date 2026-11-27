extends RefCounted
## What a fight of the Realm looks like WHILE things happen (run with the
## "year" data): a move of every school, a heal, a shield, a guard break, a
## foe going down, a boss stepping out. It does not snap whole screens: it
## cuts the arena out of a frame every few hundredths of a second and lays
## the cuts side by side in sheets (fx_sheet_1.png ...), so the effects can be
## looked at as they play. Prints CHECK lines.

const COLS = 3
const ROWS = 4

var main: Node
var tree: SceneTree
var fails = 0
var cuts: Array = []
var sheets = 0


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


func _open(stage_id: String, seed: int, moves: Array = [], scene: String = ""):
	var input = RealmScreen.sheet_input()
	var rpg = App.rpg()
	var owned = {"items": App.state.items, "pets": App.state.pets}
	var hero = RpgHero.build(RpgStats.sheet(input), RpgBoosts.active(input), rpg, owned)
	if not moves.is_empty():
		hero["moves"] = moves
	var pet = RpgHero.pet_unit(rpg, owned, int(RpgDefs.level_of(int(rpg.xp)).lvl))
	var st = RpgWorld.stage(stage_id)
	var setup = RpgWorld.setup({"kind": "stage", "id": stage_id}, rpg, hero, pet, seed, App.today)
	return BattleView.open(setup, {"title": str(st.name), "scene": scene if scene != "" else str(RpgWorld.region_of(stage_id)),
		"hero": {"state": App.state, "profile": App.saved.profile, "loadout": App.loadout(), "pet": App.active_pet()}})


func _wait_idle(bv) -> void:
	var n = 0
	# By the clock, not by frames: with no vsync a PC draws a thousand frames a second.
	while is_instance_valid(bv) and bv.busy() and n < 400:
		await ShotHelper.wait(tree, 0.05)
		n += 1


## The arena of the frame on screen, cut out, with a label in its corner.
func _cut(bv, label: String) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(bv):
		return
	await RenderingServer.frame_post_draw
	var img = tree.root.get_texture().get_image()
	var r = bv._fx_layer.get_global_rect()
	var part = img.get_region(Rect2i(int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)))
	var tag = PixelFont.tex(label, Color(1, 1, 0.6), true).get_image()
	tag.convert(part.get_format())
	part.blend_rect(tag, Rect2i(0, 0, tag.get_width(), tag.get_height()), Vector2i(3, 3))
	cuts.append(part)
	if cuts.size() >= COLS * ROWS:
		_flush()


func _flush() -> void:
	if cuts.is_empty():
		return
	var w = cuts[0].get_width()
	var h = cuts[0].get_height()
	var sheet = Image.create(w * COLS + (COLS - 1) * 4, h * ROWS + (ROWS - 1) * 4, false, cuts[0].get_format())
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in range(cuts.size()):
		var c = cuts[i]
		if c.get_width() != w or c.get_height() != h:
			c.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(c, Rect2i(0, 0, w, h), Vector2i((i % COLS) * (w + 4), int(i / float(COLS)) * (h + 4)))
	sheets += 1
	var dir = OS.get_environment("TINY_TITAN_SHOTS")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var path = dir.path_join("fx_sheet_%d.png" % sheets)
	sheet.save_png(path)
	print("SHOT ", path)
	cuts = []


## A move of `school` that strikes one foe ("" when there is none).
func _attack_of(school: String) -> String:
	for m in RpgMoves.by_school(school):
		if str(m.get("target", "foe")) == "foe" and float(m.get("power", 0.0)) > 0.0 and int(m.get("tier", 0)) <= 2:
			return str(m.id)
	return ""


func _self_of(school: String) -> String:
	for m in RpgMoves.by_school(school):
		if str(m.get("target", "foe")) == "self":
			return str(m.id)
	return ""


## Fill the hero up and keep the foes standing, so every key can be pressed.
func _top_up(bv, foe_hp: int = 9000) -> void:
	bv.B.hero["en"] = int(bv.B.hero.en_max)
	bv.B.hero["cds"] = {}
	bv.B.hero["hp"] = int(bv.B.hero.hp_max)
	for f in bv.B.foes:
		if bool(f.alive) and foe_hp > 0:
			f["hp_max"] = foe_hp
			f["hp"] = foe_hp
	bv._sync()


func _press(bv, meta: String, value: String) -> bool:
	for k in _all(meta, bv):
		if str(k.get_meta(meta)) == value and k is BaseButton:
			k.pressed.emit()
			return true
	return false


## Press a key and cut the arena at these moments after it.
func _film(bv, meta: String, value: String, label: String, at: Array, hp_share: float = 1.0) -> void:
	_top_up(bv)
	if hp_share < 1.0:
		bv.B.hero["hp"] = maxi(1, int(float(bv.B.hero.hp_max) * hp_share))
		bv._sync()
	await ShotHelper.frames(tree, 2)
	var pressed = _press(bv, meta, value)
	check(pressed, "%s: its key is there" % label)
	print("FILM %s %s busy=%s line=%s" % [label, value, str(bv.busy()), bv.line_text()])
	var t = 0.0
	for i in range(at.size()):
		await ShotHelper.wait(tree, maxf(0.01, float(at[i]) - t))
		t = float(at[i])
		await _cut(bv, "%s %d" % [label, i + 1])
	await _wait_idle(bv)


## Every effect of BattleFx at three moments, on a dark board: fx_catalogue.png.
func _catalogue() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var board = ColorRect.new()
	board.color = Color(0.13, 0.15, 0.22)
	Kit.overlay_root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var kinds = BattleFx.KINDS
	var cell = 108.0
	var colors = [Color("#ff8e7c"), Color("#939bff"), Color("#f0e63c"), Color("#57e389"), Color("#36d6f2"), Color("#ff60f6")]
	var page = 0
	var i = 0
	while i < kinds.size():
		for c in board.get_children():
			c.queue_free()
		var shown = 0
		while i < kinds.size() and shown < 8:
			var kind = str(kinds[i])
			for j in range(3):
				var x = 4.0 + float(j) * (cell + 2.0)
				var y = 4.0 + float(shown) * (cell + 2.0)
				var s = BattleFx.at(board, kind, Vector2(x + cell / 2.0, y + cell / 2.0), colors[i % colors.size()], 1.0, {"half": 18.0})
				s.set_process(false)
				s.t = [0.2, 0.5, 0.8][j]
				s.queue_redraw()
			var tag = PixelFont.rect(kind.to_upper(), 1, Color(1, 1, 1))
			board.add_child(tag)
			tag.position = Vector2(3.0 * (cell + 2.0) + 8.0, 4.0 + float(shown) * (cell + 2.0) + cell / 2.0)
			shown += 1
			i += 1
		page += 1
		await ShotHelper.frames(tree, 3)
		await RenderingServer.frame_post_draw
		var img = tree.root.get_texture().get_image()
		var dir = OS.get_environment("TINY_TITAN_SHOTS")
		if dir != "":
			img.save_png(dir.path_join("fx_catalogue_%d.png" % page))
			print("SHOT fx_catalogue_%d" % page)
	board.queue_free()


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.set_rpg(RpgSave.first_open(App.rpg(), App.loadout(), App.active_pet()).duplicate(true))
	App.go("realm")
	await ShotHelper.wait(tree, 0.5)
	var first = [_attack_of("push"), _attack_of("pull"), _attack_of("legs"), _attack_of("speed")]
	var second = [_attack_of("grip"), _attack_of("mind"), _self_of("flow"), _self_of("grit")]
	check(not first.has("") and not second.has(""), "a move to film for every school (%s, %s)" % [str(first), str(second)])
	# --- the opening, then one move of each of four schools ----------------------------------
	var bv = _open("r1s2", 3, first)
	await ShotHelper.wait(tree, 0.12)
	await _cut(bv, "OPEN 1")
	await ShotHelper.wait(tree, 0.22)
	await _cut(bv, "OPEN 2")
	await ShotHelper.wait(tree, 0.4)
	await _cut(bv, "OPEN 3")
	await _wait_idle(bv)
	check(_all("bv_ambient", bv).size() == 1, "the scene has its air (motes behind the fighters)")
	var names = ["PUSH", "PULL", "LEGS", "SPEED"]
	for i in range(first.size()):
		await _film(bv, "bv_move", str(first[i]), names[i], [0.16, 0.34, 0.5])
	# An ultimate: the cut-in, the dark, the storm.
	var ult_id = ""
	for m in RpgMoves.all():
		if bool(m.get("ult", false)) and ult_id == "":
			ult_id = str(m.id)
	_top_up(bv)
	bv.B.hero["ult"] = ult_id
	bv.B.hero["gauge"] = 100
	bv._sync()
	await ShotHelper.frames(tree, 2)
	check(_press(bv, "bv_key", "ult"), "the ultimate's key can be pressed with a full gauge")
	await ShotHelper.wait(tree, 0.3)
	await _cut(bv, "ULT 1")
	await ShotHelper.wait(tree, 0.4)
	await _cut(bv, "ULT 2")
	await ShotHelper.wait(tree, 0.25)
	await _cut(bv, "ULT 3")
	await _wait_idle(bv)
	bv.close()
	await ShotHelper.wait(tree, 0.5)
	# --- the other schools, in another scene ---------------------------------------------------
	bv = _open("r1s2", 4, second, "ironworks")
	await ShotHelper.wait(tree, 1.0)
	await _wait_idle(bv)
	names = ["GRIP", "MIND", "FLOW", "GRIT"]
	for i in range(second.size()):
		await _film(bv, "bv_move", str(second[i]), names[i], [0.16, 0.34, 0.5], 0.5 if i == 2 else 1.0)
	await _film(bv, "bv_key", "guard", "GUARD", [0.12, 0.7, 0.9])
	# What lasts is seen: a burning foe, a stunned one, a shielded hero.
	bv.B.foes[0]["statuses"] = [{"id": "burn", "turns": 3, "stacks": 1, "amount": 5.0}]
	if bv.B.foes.size() > 1:
		bv.B.foes[1]["statuses"] = [{"id": "stun", "turns": 1, "stacks": 1, "amount": 0.0}]
	bv.B.hero["statuses"] = [{"id": "shield", "turns": 2, "stacks": 1, "amount": 20.0}, {"id": "regen", "turns": 2, "stacks": 1, "amount": 5.0}]
	bv._sync()
	await ShotHelper.wait(tree, 0.45)
	check(_all("bv_status_fx", bv).size() >= 3, "lasting statuses stay drawn on the fighters (%d)" % _all("bv_status_fx", bv).size())
	await _cut(bv, "STATUS 1")
	await ShotHelper.wait(tree, 0.3)
	await _cut(bv, "STATUS 2")
	bv.B.hero["statuses"] = []
	for f in bv.B.foes:
		f["statuses"] = []
	bv._sync()
	await ShotHelper.frames(tree, 3)
	check(_all("bv_status_fx", bv).is_empty(), "and go when the status goes")
	# The hero nearly down: the red edge.
	bv.B.hero["hp"] = maxi(1, int(float(bv.B.hero.hp_max) * 0.2))
	bv._sync()
	await ShotHelper.wait(tree, 0.6)
	await _cut(bv, "LOW HP")
	bv.close()
	await ShotHelper.wait(tree, 0.5)
	# --- a guard break and a foe going down ---------------------------------------------------
	bv = _open("r1s2", 5, first, "marsh")
	await ShotHelper.wait(tree, 1.0)
	await _wait_idle(bv)
	var foe = bv.B.foes[0]
	var weak = foe.get("weak", [])
	var pick = ""
	for id in first:
		var row = RpgMoves.by_id(str(id))
		if row != null and weak.has(str(row.school)):
			pick = str(id)
	if pick == "":
		pick = str(first[0])
	_top_up(bv)
	foe["guard"] = 1
	bv._sync()
	_press(bv, "bv_move", pick)
	await ShotHelper.wait(tree, 0.4)
	await _cut(bv, "BREAK 1")
	await ShotHelper.wait(tree, 0.14)
	await _cut(bv, "BREAK 2")
	await ShotHelper.wait(tree, 0.2)
	await _cut(bv, "BREAK 3")
	await _wait_idle(bv)
	# The break itself, as it is drawn (whatever the blow above did).
	bv._show_break(str(foe.id))
	await ShotHelper.wait(tree, 0.1)
	await _cut(bv, "BREAK FX 1")
	await ShotHelper.wait(tree, 0.2)
	await _cut(bv, "BREAK FX 2")
	await ShotHelper.wait(tree, 0.6)
	bv._sync()
	if not RpgBattle.over(bv.B):
		for f in bv.B.foes:
			f["hp"] = 1
		bv.B.hero["en"] = int(bv.B.hero.en_max)
		bv.B.hero["cds"] = {}
		bv._sync()
		_press(bv, "bv_key", "strike")
		await ShotHelper.wait(tree, 0.5)
		await _cut(bv, "KO 1")
		await ShotHelper.wait(tree, 0.2)
		await _cut(bv, "KO 2")
		await ShotHelper.wait(tree, 0.5)
		await _cut(bv, "END")
	await ShotHelper.wait(tree, 1.5)
	if is_instance_valid(bv):
		bv.close()
	await ShotHelper.wait(tree, 0.5)
	# --- a boss steps out, in the storm ---------------------------------------------------------
	bv = _open("r1s10", 6, first, "stormspine")
	await ShotHelper.wait(tree, 0.55)
	await _cut(bv, "BOSS 1")
	await ShotHelper.wait(tree, 0.35)
	await _cut(bv, "BOSS 2")
	await ShotHelper.wait(tree, 0.5)
	await _cut(bv, "BOSS 3")
	await _wait_idle(bv)
	check(is_instance_valid(bv) and not bv.busy(), "after the boss has stepped out the keys are the player's")
	bv.close()
	await ShotHelper.wait(tree, 0.4)
	# --- an elite is named as it comes ----------------------------------------------------------
	bv = _open("r1s5", 6, first)
	await ShotHelper.wait(tree, 0.75)
	await _cut(bv, "ELITE 1")
	check(_all("bv_cutin", bv).size() == 1, "an elite gets its name across the arena")
	await ShotHelper.wait(tree, 0.5)
	await _cut(bv, "ELITE 2")
	await _wait_idle(bv)
	bv.close()
	await ShotHelper.wait(tree, 0.4)
	_flush()
	# --- the result of a win, as it plays --------------------------------------------------
	var r = BattleResult.new()
	Kit.overlay_root.add_child(r)
	r.setup({"win": true, "turns": 6, "dealt": 412, "taken": 57}, {"win": true, "title": "The Back Door",
		"stars": [true, true, true], "objectives": ["Win the fight", "Break a guard", "Win in 8 turns or fewer"],
		"rewards": {"xp": 120, "ore": 45, "items": [{"id": "protein_shake", "n": 2}], "runes": ["A rune of might"], "relic": "frayed_bookmark", "scroll": "stomp", "first": true},
		"level_before": {"lvl": 1, "into": 40, "need": 100}, "level_after": {"lvl": 2, "into": 60, "need": 130},
		"learned": ["Dust Bunny is weak to Push"], "next": true, "scene": "greenmile", "points": 1,
		"hero": {"state": App.state, "profile": App.saved.profile, "loadout": App.loadout()}, "hero_fit": {"top": 7, "low": 68, "mid": 32.0}})
	await ShotHelper.wait(tree, 0.75)
	await ShotHelper.snap(tree, "fx_result_1")
	var t0 = Time.get_ticks_msec()
	while not r.done and Time.get_ticks_msec() - t0 < 12000:
		await ShotHelper.wait(tree, 0.1)
	check(r.done, "the result plays to its end")
	check(_all("br_points", r).size() == 1, "a win that brought a skill point says so")
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "fx_result_2")
	r.queue_free()
	r = BattleResult.new()
	Kit.overlay_root.add_child(r)
	r.setup({"win": false, "turns": 9, "dealt": 300, "taken": 284}, {"win": false, "title": "Old Iron-Jaw", "learned": ["Old Iron-Jaw is weak to Pull"],
		"scene": "stormspine", "hero": {"state": App.state, "profile": App.saved.profile, "loadout": App.loadout()}, "hero_fit": {"top": 7, "low": 68, "mid": 32.0}})
	await ShotHelper.wait(tree, 1.6)
	await ShotHelper.snap(tree, "fx_result_3_loss")
	r.queue_free()
	await ShotHelper.frames(tree, 3)
	await _catalogue()
	print("FX %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
