extends SceneTree
## Unit test for the Realm's art (RPG_PLAN.md 12): the foes (FoeSprites), the
## view that shows one (FoeView) and the battle backdrops (RealmScenes).
##
## Every foe id of the plan's table (8.3) must have a look; both frames of
## every look must draw inside their buffer with a free pixel all round for
## the outline, must not be empty and must differ; a palette must define every
## letter its shape uses; sizes must be inside the limits (regular 14 to 22
## wide, elite 20 to 26, boss 24 to 32); silhouettes draw; textures are cached;
## every scene draws, is full and is not flat; FoeView builds, draws and plays
## its hit and its faint for every id.
##
## It also saves CONTACT SHEETS as PNG for a person to look at (the pictures
## are the real check of whether a rat reads as a rat): into the folder named
## by RPG_ART_SHEETS, else into <TINY_TITAN_DATA>/rpg_art_sheets; never into
## the project. Without either, no sheet is written and nothing fails.
##   godot --headless --path . --script res://tests/rpg_art_test.gd
## Prints RPG ART: X/Y passed and exits with 1 when anything fails.

## The plan's table: region -> [five regular foes, the elite, the boss].
const TABLE = {
	"rustyard": ["dust_bunny", "rust_rat", "squeaky_plate", "loose_collar", "moldy_towel", "bent_bar", "old_iron_jaw"],
	"greenmile": ["burr", "briar_fox", "mud_slinger", "stag_beetle", "mile_marker", "the_hill", "the_pacer"],
	"chalk": ["pebbling", "cliff_bat", "scree_golem", "chalk_wisp", "rope_snake", "overhang", "skyhook"],
	"stacks": ["bookworm", "ink_blot", "dust_jacket", "paper_knight", "overdue_notice", "the_index", "the_unread"],
	"ironworks": ["rivet_mite", "slag_imp", "anvil_back", "bellows", "molten_barbell", "press_golem", "foreman_slag"],
	"marsh": ["leech", "bog_hopper", "reed_wraith", "mud_mender", "mirror_shade", "knotroot", "the_knot"],
	"stormspine": ["static_mote", "gale_hawk", "rime_goat", "thunder_drum", "storm_eye", "cairn_giant", "thunderhead"],
	"titans_rest": ["stone_acolyte", "echo_knight", "relic_guard", "void_moth", "titan_shard", "the_gatekeeper", "the_hollow_titan"],
}
const REGIONS = ["rustyard", "greenmile", "chalk", "stacks", "ironworks", "marsh", "stormspine", "titans_rest"]
const SCENES = ["rustyard", "greenmile", "chalk", "stacks", "ironworks", "marsh", "stormspine", "titans_rest", "spire", "hunt", "rival"]
## Rows a sprite may have, by kind.
const HEIGHT_REGULAR = [9, 20]
const HEIGHT_ELITE = [14, 26]
const HEIGHT_BOSS = [16, 32]
const SHEET_BG = "#2a3a6a"

var passed = 0
var total = 0
var sheet_dir = ""
var sheets = []


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func kind_of(index: int) -> String:
	return "boss" if index == 6 else ("elite" if index == 5 else "regular")


func filled(p: Pix) -> int:
	var n = 0
	for v in p.data:
		if v != 0:
			n += 1
	return n


func colours(p: Pix) -> Dictionary:
	var seen = {}
	for v in p.data:
		if v != 0:
			seen[v] = true
	return seen


## Filled pixels on the outermost ring of a buffer.
func on_edge(p: Pix) -> int:
	var n = 0
	for x in range(p.w):
		if p.get_raw(x, 0) != 0:
			n += 1
		if p.get_raw(x, p.h - 1) != 0:
			n += 1
	for y in range(1, p.h - 1):
		if p.get_raw(0, y) != 0:
			n += 1
		if p.get_raw(p.w - 1, y) != 0:
			n += 1
	return n


func is_hex(c) -> bool:
	if not (c is String) or c.length() != 7 or c[0] != "#":
		return false
	return c.substr(1).is_valid_hex_number()


func luma(raw: int) -> float:
	var rgb = Pix.hex_to_rgb(Pix.raw_to_hex(raw))
	return 0.2126 * float(rgb[0]) + 0.7152 * float(rgb[1]) + 0.0722 * float(rgb[2])


# --- contact sheets -----------------------------------------------------------

func save_sheet(canvas: Pix, file_name: String, scale: int) -> void:
	if sheet_dir == "":
		return
	var img = canvas.to_image()
	img.resize(canvas.w * scale, canvas.h * scale, Image.INTERPOLATE_NEAREST)
	var path = sheet_dir.path_join(file_name)
	if img.save_png(path) == OK:
		sheets.append(path)


## A foe standing on row `gy` of a sheet, its middle at column `cx`, with the
## shadow FoeView draws.
func stand(canvas: Pix, id: String, frame: int, cx: int, gy: int, silhouette: bool = false, dim: bool = false) -> void:
	var buf = FoeSprites.buffer(id, frame, silhouette)
	if dim:
		buf = buf.dimmed(FoeSprites.DIM_BRIGHTNESS)
	var up = (FoeView.HOVER_GAP + 1) if FoeSprites.hovers(id) else 0
	var left = cx - int(buf.w / 2.0)
	for x in range(left + 2, left + buf.w - 2):
		var under = canvas.get_px(x, gy)
		if under != null:
			canvas.set_px(x, gy, Pix.shade(str(under), 0.72))
	canvas.blit(buf, left, gy - (buf.h - 1) - up)


func region_sheet(region: String) -> void:
	var ids = TABLE[region]
	var scene = RealmScenes.pix(region)
	var gy = RealmScenes.ground_y(region)
	var canvas = Pix.new(220, 180)
	for band in range(3):
		canvas.blit(scene, 0, band * 60)
		canvas.blit(scene, 110, band * 60)
	for frame in range(2):
		var x = 6
		for i in range(6):
			var w = FoeSprites.size(ids[i]).x
			stand(canvas, ids[i], frame, x + int(w / 2.0), frame * 60 + gy)
			x += w + 9
	var boss = ids[6]
	stand(canvas, boss, 0, 30, 120 + gy)
	stand(canvas, boss, 1, 78, 120 + gy)
	stand(canvas, boss, 0, 132, 120 + gy, true)
	stand(canvas, ids[5], 0, 170, 120 + gy, false, true)
	stand(canvas, ids[0], 0, 198, 120 + gy, true)
	save_sheet(canvas, "region_%s.png" % region, 4)


## The seven foes of a region, both frames, big, on a flat panel colour.
func zoom_sheet(region: String) -> void:
	var ids = TABLE[region]
	var canvas = Pix.new(196, 76)
	canvas.rect(0, 0, 196, 76, SHEET_BG)
	canvas.rect(0, 38, 196, 38, Pix.shade(SHEET_BG, 1.5))
	for frame in range(2):
		var x = 3
		for i in range(7):
			var w = FoeSprites.size(ids[i]).x
			stand(canvas, ids[i], frame, x + int(w / 2.0), frame * 38 + 35)
			x += w + 3
	save_sheet(canvas, "zoom_%s.png" % region, 5)


func boss_sheet() -> void:
	var canvas = Pix.new(220, 240)
	for i in range(8):
		var region = REGIONS[i]
		var ox = (i % 2) * 110
		var oy = int(i / 2.0) * 60
		canvas.blit(RealmScenes.pix(region), ox, oy)
		var gy = oy + RealmScenes.ground_y(region)
		stand(canvas, TABLE[region][6], 0, ox + 30, gy)
		stand(canvas, TABLE[region][6], 1, ox + 80, gy)
	save_sheet(canvas, "bosses.png", 4)


func scene_sheet() -> void:
	var canvas = Pix.new(330, 240)
	canvas.rect(0, 0, 330, 240, SHEET_BG)
	for i in range(SCENES.size()):
		canvas.blit(RealmScenes.pix(SCENES[i]), (i % 3) * 110, int(i / 3.0) * 60)
	# the rival and an unknown foe, where a scene is left over
	stand(canvas, "wk_mimic", 0, 250, 180 + 52)
	stand(canvas, "nobody_drew_this", 0, 290, 180 + 52)
	save_sheet(canvas, "scenes.png", 3)
	for id in SCENES:
		save_sheet(RealmScenes.pix(id), "scene_%s.png" % id, 6)


# --- the test -----------------------------------------------------------------

func _init() -> void:
	_run()


func _run() -> void:
	sheet_dir = OS.get_environment("RPG_ART_SHEETS")
	if sheet_dir == "" and OS.get_environment("TINY_TITAN_DATA") != "":
		sheet_dir = OS.get_environment("TINY_TITAN_DATA").path_join("rpg_art_sheets")
	if sheet_dir != "":
		DirAccess.make_dir_recursive_absolute(sheet_dir)

	# --- Every foe of the plan has a look --------------------------------------
	var all_ids = []
	var regular_shapes = {}
	for region in REGIONS:
		for i in range(7):
			var id = str(TABLE[region][i])
			all_ids.append(id)
			ok(FoeSprites.LOOKS.has(id) and FoeSprites.has(id), "%s has a look" % id)
			if FoeSprites.LOOKS.has(id) and i < 5:
				var sp = str(FoeSprites.LOOKS[id].sprite)
				regular_shapes[sp] = regular_shapes.get(sp, []) + [id]
	ok(all_ids.size() == 56 and FoeSprites.LOOKS.size() == 56, "56 foes, and no look without a foe", [all_ids.size(), FoeSprites.LOOKS.size()])
	var strays = FoeSprites.LOOKS.keys().filter(func(k): return not all_ids.has(k))
	ok(strays.is_empty(), "every look belongs to a foe of the table", strays)
	ok(regular_shapes.size() >= 22, "the 40 regular foes have 22 or more shapes between them", regular_shapes.size())
	var crowded = []
	for sp in regular_shapes:
		var users = regular_shapes[sp]
		if users.size() > 2:
			crowded.append(sp)
		elif users.size() == 2 and FoeSprites.LOOKS[users[0]].palette == FoeSprites.LOOKS[users[1]].palette:
			crowded.append(sp)
	ok(crowded.is_empty(), "a shape is shared by two foes at most, in other colours", crowded)
	ok(RpgDefs.REGIONS == REGIONS, "the table has the regions of RpgDefs", RpgDefs.REGIONS)

	# --- Every look is well made -----------------------------------------------
	for region in REGIONS:
		for i in range(7):
			var id = str(TABLE[region][i])
			if not FoeSprites.LOOKS.has(id):
				continue
			var lk = FoeSprites.LOOKS[id]
			var kind = kind_of(i)
			ok(lk.has("sprite") and lk.has("palette") and lk.has("hover") and lk.hover is bool and FoeSprites.SHAPES.has(str(lk.sprite)), "%s: a look is {sprite, palette, hover}" % id, lk.keys())
			var two = FoeSprites.frames(str(lk.sprite))
			var f0 = two[0]
			var f1 = two[1]
			var w = str(f0[0]).length()
			var ragged = []
			for f in two:
				for r in range(f.size()):
					if str(f[r]).length() != w:
						ragged.append([r, str(f[r]).length()])
			ok(two.size() == 2 and f0.size() == f1.size() and ragged.is_empty(), "%s: two frames of one size, every row %d wide" % [id, w], [f0.size(), f1.size(), ragged])
			# what a shape was written as: the rows it gives must all be the same width before padding
			var shape = FoeSprites.SHAPES[str(lk.sprite)]
			var written = shape.get("half", shape.get("rows", []))
			var uneven = []
			for r in range(written.size()):
				if str(written[r]).length() != str(written[0]).length():
					uneven.append([r, str(written[r]).length()])
			for r in range(shape.get("two", []).size()):
				if str(shape.two[r]).length() != w:
					uneven.append(["two", r, str(shape.two[r]).length()])
			if shape.has("two") and shape.two.size() != f0.size():
				uneven.append(["two has", shape.two.size(), "rows, not", f0.size()])
			for key in shape.get("alt", {}):
				var n_ch = str(shape.alt[key]).length()
				if n_ch != w and not (shape.has("half") and n_ch * 2 == w):
					uneven.append(["alt", key, n_ch])
				if int(key) < 0 or int(key) >= f0.size():
					uneven.append(["alt row", key])
			for m in shape.get("over", []) + shape.get("alt_over", []):
				if int(m[0]) < 0 or int(m[0]) >= f0.size() or int(m[1]) < 0 or int(m[1]) + str(m[2]).length() > w:
					uneven.append(["over", m])
			ok(uneven.is_empty(), "%s: its shape is written in rows of one width (%d)" % [id, str(written[0]).length() if written.size() > 0 else 0], uneven)
			var unknown = {}
			for f in two:
				for row in f:
					for ch in str(row):
						if ch != "." and not lk.palette.has(ch):
							unknown[ch] = true
			ok(unknown.is_empty(), "%s: the palette has every letter its shape uses" % id, unknown.keys())
			var bad_hex = []
			var unused = []
			for key in lk.palette:
				if not is_hex(lk.palette[key]):
					bad_hex.append(key)
				var used = false
				for f in two:
					for row in f:
						if str(row).contains(str(key)):
							used = true
				if not used:
					unused.append(key)
			ok(bad_hex.is_empty() and unused.is_empty(), "%s: every palette entry is a colour that is used" % id, [bad_hex, unused])
			var wide = FoeSprites.WIDTH_BOSS if kind == "boss" else (FoeSprites.WIDTH_ELITE if kind == "elite" else FoeSprites.WIDTH_REGULAR)
			var tall = HEIGHT_BOSS if kind == "boss" else (HEIGHT_ELITE if kind == "elite" else HEIGHT_REGULAR)
			ok(w >= int(wide[0]) and w <= int(wide[1]) and f0.size() >= int(tall[0]) and f0.size() <= int(tall[1]), "%s: %d x %d is a %s's size" % [id, w, f0.size(), kind], [wide, tall])
			ok(FoeSprites.size(id) == Vector2i(w + 2, f0.size() + 2) and FoeSprites.hovers(id) == lk.hover, "%s: size() is the sprite and its outline, hovers() the look's" % id, FoeSprites.size(id))
			var plain0 = FoeSprites.plain(id, 0)
			var plain1 = FoeSprites.plain(id, 1)
			var buf0 = FoeSprites.buffer(id, 0)
			var buf1 = FoeSprites.buffer(id, 1)
			ok(on_edge(plain0) == 0 and on_edge(plain1) == 0 and plain0.w == w + 2 and plain0.h == f0.size() + 2, "%s: both frames leave a free pixel all round for the outline" % id, [on_edge(plain0), on_edge(plain1)])
			var cells = w * f0.size()
			ok(filled(plain0) * 4 >= cells and filled(plain1) * 4 >= cells, "%s: neither frame is empty (a quarter of its box or more)" % id, [filled(plain0), filled(plain1), cells])
			ok(plain0.data != plain1.data and buf0.data != buf1.data, "%s: the two frames differ" % id)
			ok(filled(buf0) > filled(plain0) and filled(buf1) > filled(plain1) and buf0.w == plain0.w and buf0.h == plain0.h, "%s: the outline is added round the sprite, inside the buffer" % id)
			ok(colours(buf0).size() >= 4, "%s: more than a flat shape (4 colours or more with its shading)" % id, colours(buf0).size())
			# the first and last row and column of the sprite itself are used: the box is tight
			var touches = [false, false, false, false]
			for f in two:
				for r in range(f.size()):
					var row = str(f[r])
					if row[0] != ".":
						touches[0] = true
					if row[w - 1] != ".":
						touches[1] = true
					if r == 0 and row.replace(".", "") != "":
						touches[2] = true
					if r == f.size() - 1 and row.replace(".", "") != "":
						touches[3] = true
			ok(not touches.has(false), "%s: its box is tight (no empty row or column at an edge in both frames)" % id, touches)
			var sil = FoeSprites.buffer(id, 0, true)
			var same_mask = true
			for k in range(sil.data.size()):
				if (sil.data[k] == 0) != (buf0.data[k] == 0):
					same_mask = false
			ok(same_mask and colours(sil).size() == 2, "%s: its silhouette is the same shape in two dark colours" % id, colours(sil).size())
			var t0 = FoeSprites.texture(id, 0)
			ok(t0 != null and FoeSprites.texture(id, 0) == t0 and FoeSprites.texture(id, 2) == t0 and FoeSprites.texture(id, 1) != t0 and FoeSprites.texture(id, 0, true) != t0 and FoeSprites.texture(id, 0, false, true) != t0, "%s: textures are cached, one per frame and state" % id)

	# --- An id nobody drew, and the weekly rival ---------------------------------
	ok(not FoeSprites.has("nobody_drew_this") and FoeSprites.look("nobody_drew_this") == FoeSprites.DEFAULT_LOOK, "an unknown id has no look of its own")
	var blob = FoeSprites.buffer("nobody_drew_this", 0)
	ok(filled(blob) > 40 and blob.data != FoeSprites.buffer("nobody_drew_this", 1).data and FoeSprites.size("nobody_drew_this") == Vector2i(blob.w, blob.h) and FoeSprites.texture("nobody_drew_this") != null, "... it is drawn as a plain blob, two frames", filled(blob))
	ok(FoeSprites.has("wk_mimic") and FoeSprites.is_rival("wk_mimic") and not FoeSprites.is_rival("dust_bunny") and not FoeSprites.has("wk_no_such_monster"), "the weekly rival's monsters are known by their bounty ids")
	ok(FoeSprites.size("wk_mimic") == Art.boss_size("wk_mimic") and FoeSprites.hovers("wk_bat") and not FoeSprites.hovers("wk_mimic"), "... sized and hovering as the main game has them", FoeSprites.size("wk_mimic"))
	ok(FoeSprites.texture("wk_mimic") == Art.boss_texture("wk_mimic") and FoeSprites.texture("wk_mimic", 1) == Art.boss_texture("wk_mimic") and FoeSprites.buffer("wk_bat").data == BossSprites.boss_buffer("wk_bat").data, "... and drawn through Art / BossSprites")
	ok(FoeSprites.texture("wk_mimic", 0, true) == Art.boss_texture("wk_mimic", true) and FoeSprites.texture("wk_mimic", 0, false, true) == Art.boss_texture("wk_mimic", false, true), "... silhouette and dimmed too")

	# --- The foes the battles know (RpgFoes is another file: read only when it loads) ---
	var foes_path = "res://game/rpg/rpg_foes.gd"
	var foes_script = load(foes_path) if ResourceLoader.exists(foes_path) else null
	var listed = null
	if foes_script != null and foes_script.can_instantiate():
		var names = foes_script.get_script_method_list().map(func(m): return str(m.name))
		if names.has("all"):
			listed = foes_script.call("all")
	if listed is Array and not listed.is_empty():
		var blobs = []
		var homeless = []
		for row in listed:
			var id = str(row.get("id", "")) if row is Dictionary else str(row)
			if not FoeSprites.has(id):
				blobs.append(id)
			elif row is Dictionary and FoeSprites.LOOKS.has(id) and str(row.get("region", "")) != "" and not TABLE.get(str(row.region), []).has(id):
				homeless.append([id, row.region])
		ok(blobs.is_empty(), "every foe RpgFoes lists (%d) has a look of its own, none is the plain blob" % listed.size(), blobs)
		ok(homeless.is_empty(), "... and lives in the region whose colours it was drawn in", homeless)
	else:
		print("note  RpgFoes lists no foes yet: its ids were not checked against the looks")

	# --- The backdrops -----------------------------------------------------------
	ok(RealmScenes.all() == SCENES, "a scene per region, then spire, hunt and rival", RealmScenes.all())
	var tints = {}
	for id in SCENES:
		var p = RealmScenes.pix(id)
		ok(p.w == 110 and p.h == 60 and RealmScenes.W == 110 and RealmScenes.H == 60, "%s: 110 x 60" % id, [p.w, p.h])
		ok(filled(p) == 110 * 60, "%s: every pixel is painted" % id, 110 * 60 - filled(p))
		ok(colours(p).size() >= 14, "%s: not flat (14 colours or more)" % id, colours(p).size())
		var gy = RealmScenes.ground_y(id)
		ok(gy >= RealmScenes.HORIZON + 6 and gy <= 56, "%s: the foes stand in the ground band (row %d)" % [id, gy])
		# the sky is not the ground, and the ground row is calm enough for sprites to read on it
		var sky = {}
		var floor_cols = {}
		var lo = 255.0
		var hi = 0.0
		for x in range(22, 90):
			sky[p.get_raw(x, 2)] = true
			var v = p.get_raw(x, gy)
			floor_cols[v] = true
			lo = minf(lo, luma(v))
			hi = maxf(hi, luma(v))
		var shared = sky.keys().filter(func(c): return floor_cols.has(c))
		ok(shared.is_empty(), "%s: the top of the picture and the ground are different things" % id)
		ok(floor_cols.size() <= 8 and hi - lo <= 70.0, "%s: the row the foes stand on is calm (%d colours, luma spread %d)" % [id, floor_cols.size(), int(hi - lo)])
		# the band the foes are drawn over: no hard light-and-dark detail in the middle of the picture
		var jumps = 0
		for y in range(24, gy + 1):
			for x in range(26, 86):
				if absf(luma(p.get_raw(x, y)) - luma(p.get_raw(x + 1, y))) > 70.0:
					jumps += 1
		ok(jumps <= 60, "%s: the middle band is calm (%d hard edges in it)" % [id, jumps])
		ok(is_hex(RealmScenes.tint(id)), "%s: its tint is a colour" % id, RealmScenes.tint(id))
		tints[RealmScenes.tint(id)] = true
		var tex = RealmScenes.texture(id)
		ok(tex != null and RealmScenes.texture(id) == tex and RealmScenes.has(id), "%s: its texture is cached" % id)
		var again = RealmScenes.pix(id)
		ok(again.data == p.data, "%s: the same picture every time" % id)
	ok(tints.size() == SCENES.size(), "every scene has a tint of its own", tints.size())
	ok(not RealmScenes.has("nowhere") and RealmScenes.pix("nowhere").data == RealmScenes.pix(RealmScenes.FALLBACK).data and RealmScenes.texture("nowhere") == RealmScenes.texture(RealmScenes.FALLBACK) and is_hex(RealmScenes.tint("nowhere")), "an unknown scene is drawn as the hunt's clearing")
	ok(RealmScenes.scene_for("stage", "marsh") == "marsh" and RealmScenes.scene_for("echo", "chalk") == "chalk" and RealmScenes.scene_for("hunt", "marsh") == "hunt" and RealmScenes.scene_for("rival") == "rival" and RealmScenes.scene_for("spire", "stacks") == "spire" and RealmScenes.scene_for("stage", "nowhere") == RealmScenes.FALLBACK, "a stage and its echo are fought in the region's scene; the hunt, the rival and the Spire in their own")
	var into = Pix.new(110, 60)
	RealmScenes.draw(into, "chalk")
	ok(into.data == RealmScenes.pix("chalk").data, "draw(p, id) paints the buffer it is given")
	var pics = {}
	for id in SCENES:
		pics[hash(RealmScenes.pix(id).data)] = true
	ok(pics.size() == SCENES.size(), "no two scenes are the same picture", pics.size())

	# --- The view ----------------------------------------------------------------
	await process_frame
	var box = Control.new()
	box.size = Vector2(440, 400)
	root.add_child(box)
	var views = []
	var shown = all_ids + ["nobody_drew_this", "wk_mimic", "wk_bat"]
	for id in shown:
		var v = FoeView.new()
		v.setup(id, 64.0)
		box.add_child(v)
		v.size = Vector2(64, 64)
		views.append(v)
	await process_frame
	await process_frame
	var fits = []
	var filters = []
	for i in range(views.size()):
		var v = views[i]
		var id = str(shown[i])
		var k = v.art_scale()
		var sz = FoeSprites.size(id)
		if k < 1 or float(sz.x * k) > 64.0 or float(FoeView.rows_needed(id) * k) > 64.0 or v.custom_minimum_size != Vector2(64, 64):
			fits.append([id, k])
		if v.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST or v.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			filters.append(id)
		if v.foe_id() != id:
			fits.append([id, "id"])
	ok(fits.is_empty(), "a view of every foe fits its 64 px square at a whole-number scale", fits)
	# what a view paints (layout()) stays inside it, at the top of a float too, and stands on feet_y()
	var spills = []
	var top_float = int(FoeView.FLOAT_PATH.max())
	for i in range(views.size()):
		var v = views[i]
		var id = str(shown[i])
		for lift in [0, top_float if FoeSprites.hovers(id) else (FoeView.HOP if FoeSprites.is_rival(id) else 0)]:
			var at = v.layout(lift)
			var k = float(at.k)
			var spr: Rect2 = at.sprite
			var parts = [spr, at.shadow[0], at.shadow[1], Rect2(at.marker.x - 2.0 * k, at.marker.y, 5.0 * k, 2.0 * k)]
			for r in parts:
				if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > v.size.x or r.end.y > v.size.y:
					spills.append([id, lift, r])
			var gap = float(lift + (FoeView.HOVER_GAP if FoeSprites.hovers(id) else 0))
			if spr.end.y != v.feet_y() + k - gap * k or at.ground != v.feet_y() or at.shadow[1].position.y != v.feet_y() or fmod(spr.position.x, 1.0) != 0.0 or spr.size != Vector2(FoeSprites.size(id)) * k:
				spills.append([id, lift, "feet", spr])
	ok(spills.is_empty(), "the sprite, its shadow and the target marker are painted inside the view, the feet on its ground line", spills.slice(0, 4))
	ok(top_float + FoeView.HOVER_GAP <= FoeView.PAD, "the headroom of a foe that hovers covers its whole float", [top_float, FoeView.HOVER_GAP, FoeView.PAD])
	ok(filters.is_empty(), "... with nearest-neighbour pixels, and it takes no clicks", filters)
	var bunny = views[0]
	ok(bunny.art_scale() == 3 and bunny.feet_y() == 64.0 - 3.0 * float(FoeView.FOOT), "a 16 x 15 dust bunny is shown x3, its feet FOOT rows above the bottom", [bunny.art_scale(), bunny.feet_y()])
	ok(bunny.is_processing(), "an animated view runs while it is on screen")
	bunny.visible = false
	ok(not bunny.is_processing(), "... and stops when it is hidden")
	bunny.visible = true
	ok(bunny.is_processing(), "... and runs again when it is shown")
	box.visible = false
	ok(not bunny.is_processing() and not views[5].is_processing(), "... a hidden parent stops it too")
	box.visible = true
	var still = FoeView.new()
	still.setup("rust_rat", 64.0, false)
	box.add_child(still)
	await process_frame
	ok(not still.is_processing(), "a view that is not animated does not run")
	still.hit()
	ok(still.is_processing(), "... until it is hit")
	still._process(0.2)
	ok(still.is_processing() and still._hit_ms > 0.0, "... the flash plays")
	still._process(0.4)
	ok(not still.is_processing() and still._hit_ms < 0.0, "... and is over after 0.45 s")
	# every view takes a hit, is marked, dimmed, drawn as a shape, faints and comes back
	for v in views:
		v.hit()
		v.set_marked(true)
		v.set_dim(true)
	await process_frame
	for v in views:
		v.set_dim(false)
		v.set_silhouette(true)
	await process_frame
	var down = []
	for v in views:
		v.set_silhouette(false)
		v.faint()
		if not v.fainted():
			down.append(v.foe_id())
	await process_frame
	for v in views:
		v._process(0.3)
	await process_frame
	var early = views.filter(func(x): return x._gone).size()
	for v in views:
		v._process(0.4)
	var gone = views.filter(func(x): return x._gone and x.fainted() and not x.is_processing()).size()
	ok(down.is_empty() and early == 0 and gone == views.size(), "a foe that faints sinks and fades for 0.6 s, then stays hidden and still", [down, early, gone])
	await process_frame
	views[0].hit()
	ok(views[0]._hit_ms < 0.0, "a foe that is down takes no hit")
	for v in views:
		v.revive()
	ok(views.all(func(x): return not x.fainted() and x.is_processing()), "revive() brings it back")
	views[1].faint()
	views[1].setup("rust_rat", 64.0)
	ok(not views[1].fainted(), "... and so does setup()")
	await process_frame
	# one size of pixel for a whole pack
	var pack = FoeView.new()
	pack.setup("the_pacer", 64.0)
	ok(pack.art_scale() == 1, "the 34 x 19 Pacer only fits a 64 px square at x1")
	pack.set_art_scale(3)
	ok(pack.art_scale() == 3 and pack.custom_minimum_size == FoeView.needed("the_pacer", 3) and FoeView.needed("the_pacer", 3) == Vector2(102, float((19 + FoeView.FOOT) * 3)), "set_art_scale(3) draws it x3 and asks for the room", pack.custom_minimum_size)
	ok(FoeView.rows_needed("cliff_bat") == FoeSprites.size("cliff_bat").y + FoeView.PAD + FoeView.FOOT and FoeView.rows_needed("rust_rat") == FoeSprites.size("rust_rat").y + FoeView.FOOT, "a foe that hovers has headroom to float in, one on the ground has none")
	ok(FoeView.rows_needed("wk_mimic") == FoeSprites.size("wk_mimic").y + FoeView.HOP + FoeView.FOOT and FoeView.rows_needed("wk_bat") == FoeSprites.size("wk_bat").y + FoeView.PAD + FoeView.FOOT, "the rival has one frame: on the ground it has room for a hop instead")
	pack.set_art_scale(0)
	ok(pack.art_scale() == 1 and pack.custom_minimum_size == Vector2(64, 64), "set_art_scale(0) fits the square again")
	pack.free()
	var empty = FoeView.new()
	box.add_child(empty)
	await process_frame
	ok(empty.art_scale() == 1 and not empty.is_processing() and empty.foe_id() == "", "a view with no foe draws nothing and does not run")
	# the two frames: wings beat evenly, a foe on the ground only dips into its second frame
	var cycle = int(FoeView.CYCLE_MS)
	var beat = int(FoeView.BEAT_MS)
	ok(FoeView.frame_at(0, true) == 0 and FoeView.frame_at(int(FoeView.FRAME_MS) - 1, true) == 0 and FoeView.frame_at(int(FoeView.FRAME_MS), true) == 1 and FoeView.frame_at(cycle - 1, true) == 1 and FoeView.frame_at(cycle, true) == 0, "a foe that hovers gives each frame half a round")
	ok(FoeView.frame_at(0, false) == 0 and FoeView.frame_at(cycle - beat - 1, false) == 0 and FoeView.frame_at(cycle - beat, false) == 1 and FoeView.frame_at(cycle - 1, false) == 1 and FoeView.frame_at(cycle, false) == 0 and beat * 2 < cycle, "a foe on the ground is in its second frame for a short beat of every round")
	# a finger scrolling the page stops the idle: read from the game's TouchScroll without naming it
	ok(not FoeView.page_scrolling(), "no page is being scrolled in a test")
	var kept = FoeView._scroll
	var fake = GDScript.new()
	fake.source_code = "extends RefCounted\nstatic var scrolling: bool = true\n"
	ok(fake.reload() == OK, "(a stand-in for the script that knows about scrolling)")
	FoeView._scroll = fake
	var idle = FoeView.new()
	idle.setup("dust_bunny", 64.0)
	box.add_child(idle)
	await process_frame
	idle._frame = 7
	idle._process(0.016)
	ok(FoeView.page_scrolling() and idle._frame == 7, "while a finger scrolls the page the idle stands still", idle._frame)
	idle.hit()
	idle._process(0.2)
	ok(idle._hit_ms > 0.0 and idle._frame == 7, "... a hit still plays out")
	fake.set("scrolling", false)
	idle._process(0.016)
	ok(not FoeView.page_scrolling() and idle._frame != 7, "... and it goes on when the finger lifts", idle._frame)
	FoeView._scroll = kept
	var by_name = FileAccess.get_file_as_string("res://avatar/foe_view.gd")
	var named = []
	for word in ["TouchScroll.", "Kit.", "Sfx.", "App."]:
		for line in by_name.split("\n"):
			if line.contains(word) and not line.strip_edges().begins_with("#"):
				named.append(line.strip_edges())
	ok(by_name != "" and named.is_empty(), "FoeView names no autoload, no Kit and no TouchScroll (a headless test can build it)", named)
	box.queue_free()

	# --- Contact sheets ----------------------------------------------------------
	for region in REGIONS:
		region_sheet(region)
		zoom_sheet(region)
	boss_sheet()
	scene_sheet()
	if sheet_dir != "":
		ok(sheets.size() == 8 + 8 + 1 + 1 + SCENES.size(), "the contact sheets were saved", [sheets.size(), sheet_dir])
		print("sheets: %s" % sheet_dir)

	print("RPG ART: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
