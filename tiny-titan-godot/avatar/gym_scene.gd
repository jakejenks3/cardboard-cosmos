class_name GymScene
extends RefCounted
## The hero's home gym (port of avatar/scene.ts). It fills up with equipment
## as disciplines level up.
##
## SceneInput: stage, liftLevel, climbLevel, runLevel, rideLevel,
##             achievements (count), sessions (count),
##             hour (0-23 local hour for the window), frame

const SCENE_W = 96
const SCENE_H = 72
## Where the hero buffer is blitted. Hero baseline lands on FLOOR_Y - 1.
const HERO_X = 24
const HERO_Y = 10
const FLOOR_Y = 67

const WALLS = ["#3a3350", "#3d3a5e", "#43406c", "#494578", "#4f4a82", "#58508f"]
const FLOORS = ["#2b2540", "#2e2a48", "#332e52", "#36305a", "#3a3460", "#3f3868"]

## The climbing holds, [x, y, width] in draw order. The TS draws them from
## `makeRng('holds')` (per hold: hx = 28 + rng.int(40), hy = 7 + rng.int(28),
## width = 2 + rng.int(2)); the seed never changes, so the sequence is fixed
## and baked in here (generated from the TS, checked by tests/parity_art.gd).
const HOLDS = [[67, 19, 3], [59, 11, 3], [36, 8, 3], [66, 19, 2], [57, 11, 3], [63, 7, 2], [47, 34, 2], [58, 22, 3], [59, 30, 3], [42, 8, 2], [29, 8, 3], [40, 30, 3], [50, 29, 2], [28, 9, 3], [57, 19, 2], [31, 27, 3]]


## Window colours for a local hour: {sky, sky2, night, dawn}.
static func sky_colors(hour: int) -> Dictionary:
	if hour >= 6 and hour < 8:
		return {"sky": "#ffb27a", "sky2": "#ffd9a0", "night": false, "dawn": true}
	if hour >= 8 and hour < 18:
		return {"sky": "#6fc3ff", "sky2": "#bfe6ff", "night": false, "dawn": false}
	if hour >= 18 and hour < 20:
		return {"sky": "#ff7f6e", "sky2": "#8e5aa8", "night": false, "dawn": true}
	return {"sky": "#1b1f4b", "sky2": "#2a2f6b", "night": true, "dawn": false}


static func draw_scene(p: Pix, s: Dictionary) -> void:
	if not Pix.classic:
		_draw_scene_lit(p, s)
		return
	var stage: int = int(s.stage)
	var frame: int = int(s.frame)
	var lift_level: int = int(s.liftLevel)
	var climb_level: int = int(s.climbLevel)
	var run_level: int = int(s.runLevel)
	var ride_level: int = int(s.rideLevel)
	var achievements: int = int(s.achievements)
	var sessions: int = int(s.sessions)

	var wall: String = WALLS[mini(5, stage)]
	var floor_c: String = FLOORS[mini(5, stage)]
	p.rect(0, 0, SCENE_W, FLOOR_Y, wall)
	p.rect(0, FLOOR_Y, SCENE_W, SCENE_H - FLOOR_Y, floor_c)
	# floor mats
	for x in range(0, SCENE_W, 12):
		p.vline(x, FLOOR_Y, SCENE_H - FLOOR_Y, Pix.shade(floor_c, 0.85))
	p.hline(0, FLOOR_Y, SCENE_W, Pix.shade(floor_c, 1.25))
	# wainscot
	if stage >= 2:
		p.rect(0, 56, SCENE_W, FLOOR_Y - 56, Pix.shade(wall, 0.9))
		p.hline(0, 56, SCENE_W, Pix.shade(wall, 1.25))
	# baseboard
	p.hline(0, FLOOR_Y - 1, SCENE_W, Pix.shade(wall, 0.75))

	_draw_window(p, int(s.hour))
	_draw_poster(p, stage)

	# --- trophy shelf -------------------------------------------------------
	if achievements >= 3:
		var x: int = 2
		var y: int = 8
		p.hline(x, y, 22, "#8d6e4c")
		p.hline(x, y + 1, 22, "#6b4f36")
		var n: int = mini(5, int(floor(achievements / 6.0)) + 1)
		for i in range(n):
			var tx: int = x + 1 + i * 4
			var gold: String = "#ffd54f" if i % 3 == 0 else ("#cfd8dc" if i % 3 == 1 else "#ffab91")
			p.rect(tx, y - 4, 3, 3, gold)
			p.set_px(tx + 1, y - 1, Pix.shade(gold, 0.7))
			p.set_px(tx, y - 5, gold)
			p.set_px(tx + 2, y - 5, gold)

	# --- string lights ------------------------------------------------------
	if stage >= 3:
		p.hline(0, 2, SCENE_W, "#2a2340")
		var cols: Array = ["#ff5252", "#ffd740", "#69f0ae", "#40c4ff", "#ff4081"]
		for x in range(3, SCENE_W, 6):
			var i: int = int(x / 6.0)
			var on: bool = (i + frame) % 5 != 0
			var c: String = cols[i % cols.size()]
			p.set_px(x, 3, c if on else Pix.shade(c, 0.5))
			if on and frame % 2 == 0:
				p.set_px(x, 4, Pix.shade(c, 1.4))

	# --- climbing wall (center, behind the hero) ----------------------------
	if climb_level >= 1:
		var n: int = mini(16, 3 + climb_level)
		var cols: Array = ["#ff5252", "#ffd740", "#69f0ae", "#40c4ff", "#ff4081", "#ffab40"]
		for i in range(n):
			var hold: Array = HOLDS[i]
			var hx: int = hold[0]
			var hy: int = hold[1]
			var c: String = cols[i % cols.size()]
			var shape_w: int = hold[2]
			p.rect(hx, hy, shape_w, 2, c)
			p.set_px(hx, hy, Pix.shade(c, 1.3))
		if climb_level >= 8:
			# hangboard
			p.rect(36, 4, 24, 4, "#a9825a")
			p.hline(36, 4, 24, "#c9a27a")
			for k in range(4):
				p.rect(38 + k * 6, 6, 3, 1, "#4e3a28")

	# --- squat rack + dumbbells (left) --------------------------------------
	if lift_level >= 10:
		p.rect(3, 24, 2, 43, "#5c6673")
		p.rect(19, 24, 2, 43, "#5c6673")
		p.hline(3, 24, 18, "#5c6673")
		for y in range(30, 60, 6):
			p.set_px(5, y, "#8a97a6")
			p.set_px(18, y, "#8a97a6")
		# loaded bar on the rack
		p.hline(0, 34, 24, "#aab2bd")
		p.rect(0, 31, 2, 7, "#d64545")
		p.rect(22, 31, 2, 7, "#d64545")
	if lift_level >= 3:
		var x: int = 2
		var shelves: int = 2 if lift_level >= 6 else 1
		for sh in range(shelves):
			var y: int = FLOOR_Y - 2 - sh * 6
			p.hline(x, y, 18, "#4a3a2c")
			p.hline(x, y + 1, 18, "#2e2419")
			for d in range(3):
				var dx: int = x + 1 + d * 6
				var c: String = ["#9e9e9e", "#78909c", "#546e7a"][(d + sh) % 3]
				p.rect(dx, y - 3, 1, 3, c)
				p.rect(dx + 3, y - 3, 1, 3, c)
				p.hline(dx + 1, y - 2, 2, "#bdbdbd")
		p.vline(x, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, "#4a3a2c")
		p.vline(x + 17, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, "#4a3a2c")

	# --- bike on the wall (right) --------------------------------------------
	if ride_level >= 5:
		var bx: int = 66
		var by: int = 30
		var tire: String = "#263238"
		var rim: String = "#90a4ae"
		var frame_c: String = "#ffeb3b" if ride_level >= 20 else "#e53935"
		for cx in [bx + 5, bx + 20]:
			p.ellipse(cx, by + 10, 5, 5, tire)
			p.ellipse(cx, by + 10, 3.5, 3.5, wall)
			p.set_px(cx, by + 10, rim)
			p.set_px(cx - 2, by + 10, rim)
			p.set_px(cx + 2, by + 10, rim)
			p.set_px(cx, by + 8, rim)
			p.set_px(cx, by + 12, rim)
		p.limb(bx + 5, by + 10, bx + 11, by + 3, 1, frame_c)
		p.limb(bx + 11, by + 3, bx + 18, by + 3, 1, frame_c)
		p.limb(bx + 18, by + 3, bx + 20, by + 10, 1, frame_c)
		p.limb(bx + 11, by + 3, bx + 12, by + 10, 1, frame_c)
		p.limb(bx + 12, by + 10, bx + 5, by + 10, 1, frame_c)
		p.limb(bx + 12, by + 10, bx + 18, by + 3, 1, frame_c)
		p.rect(bx + 10, by + 1, 3, 1, "#263238") # saddle
		p.rect(bx + 18, by + 1, 2, 1, "#263238") # bars
		# wall hook
		p.vline(bx + 12, by - 4, 5, "#5c6673")

	# --- treadmill (right, behind the pet) ----------------------------------
	if run_level >= 5:
		var x: int = 62
		p.rect(x, FLOOR_Y - 4, 29, 4, "#37474f")
		p.rect(x + 1, FLOOR_Y - 3, 27, 2, "#546e7a")
		for k in range(0, 27, 3):
			p.set_px(x + 1 + ((k + frame) % 27), FLOOR_Y - 2, "#90a4ae")
		p.rect(x + 25, FLOOR_Y - 16, 2, 12, "#546e7a")
		p.rect(x + 20, FLOOR_Y - 19, 10, 4, "#37474f")
		p.rect(x + 21, FLOOR_Y - 18, 5, 2, "#69f0ae" if frame % 6 < 3 else "#40c4ff")

	# --- plant --------------------------------------------------------------
	if sessions >= 5:
		var x: int = 86
		p.rect(x, FLOOR_Y - 6, 6, 6, "#b5651d")
		p.hline(x - 1, FLOOR_Y - 6, 8, "#d2843b")
		var g: String = "#43a047"
		var g2: String = "#66bb6a"
		p.rect(x + 1, FLOOR_Y - 12, 4, 6, g)
		p.set_px(x, FLOOR_Y - 10, g2)
		p.set_px(x + 5, FLOOR_Y - 11, g2)
		p.set_px(x - 1, FLOOR_Y - 9, g)
		p.set_px(x + 6, FLOOR_Y - 10, g)
		p.set_px(x + 2, FLOOR_Y - 14, g2)
		p.set_px(x + 3, FLOOR_Y - 13, g)
		p.set_px(x + 1, FLOOR_Y - 13, g)

	# --- rug ----------------------------------------------------------------
	if stage >= 2:
		p.rect(28, FLOOR_Y + 1, 40, 3, "#8e2a3a")
		p.hline(28, FLOOR_Y + 1, 40, "#c9a24c")
		p.hline(28, FLOOR_Y + 3, 40, "#c9a24c")


static func _draw_window(p: Pix, hour: int) -> void:
	var x: int = 6
	var y: int = 12
	var ww: int = 16
	var wh: int = 14
	var sky: Dictionary = sky_colors(hour)
	p.rect(x - 1, y - 1, ww + 2, wh + 2, "#d9c8a9")
	p.rect(x, y, ww, wh, sky.sky)
	p.rect(x, y, ww, 5, sky.sky2)
	if sky.night:
		p.set_px(x + 3, y + 2, "#ffffff")
		p.set_px(x + 9, y + 4, "#ffffff")
		p.set_px(x + 12, y + 1, "#ffffff")
		p.rect(x + 10, y + 6, 3, 3, "#fff3b0")
		p.set_px(x + 11, y + 7, sky.sky)
	elif not sky.dawn:
		p.rect(x + 11, y + 2, 3, 3, "#fff176")
	else:
		p.rect(x + 2, y + 8, 4, 2, "#ffe0b2")
	# hills
	var hill: String = "#15213a" if sky.night else "#4f8f5a"
	p.rect(x, y + wh - 4, ww, 4, hill)
	p.hline(x + 2, y + wh - 5, 5, hill)
	p.hline(x + 9, y + wh - 6, 6, hill)
	# cross bars
	p.vline(x + int(floor(ww / 2.0)), y, wh, "#d9c8a9")
	p.hline(x, y + int(floor(wh / 2.0)), ww, "#d9c8a9")


static func _draw_poster(p: Pix, stage: int) -> void:
	var x: int = 74
	var y: int = 14
	p.rect(x, y, 10, 12, "#f4ecd8")
	p.rect(x + 1, y + 1, 8, 6, ["#ff7a59", "#8ad46a", "#5ad1e6", "#c792ea"][stage % 4])
	p.hline(x + 2, y + 8, 6, "#555555")
	p.hline(x + 2, y + 10, 4, "#777777")
	p.set_px(x + 1, y + 2, "#fff3b0")

# ---------------------------------------------------------------------------
# The game's own look of the gym (Pix.classic == false). Same room, same
# equipment at the same levels and in the same places as the port above, with
# more to look at: striped wallpaper under a shaded ceiling, a plank floor, a
# window with a sill and weather in it, a plywood panel that makes the holds a
# climbing wall, lights on a sagging wire, shadows under what stands.
# ---------------------------------------------------------------------------

## What moves in the lit scene besides the hero, as a short text: Art puts it in
## the cache key of a rendered frame.
static func lit_motion(stage: int, hour: int, frame: int) -> String:
	var sky: Dictionary = sky_colors(hour)
	var drift: int = int(frame / 9.0) % 26
	var twinkle: int = int(frame / 5.0) % 3 if sky.night else 0
	return "%d.%d" % [drift, twinkle]


static func _clip_px(p: Pix, x: int, y: int, x0: int, x1: int, c: String) -> void:
	if x >= x0 and x < x1:
		p.set_px(x, y, c)


static func _draw_window_lit(p: Pix, hour: int, frame: int) -> void:
	var x: int = 6
	var y: int = 12
	var ww: int = 16
	var wh: int = 14
	var sky: Dictionary = sky_colors(hour)
	var frame_c: String = "#e8d9bb"
	var frame_d: String = "#b3a283"
	p.rect(x - 2, y - 2, ww + 4, wh + 4, frame_c)
	p.hline(x - 2, y - 2, ww + 4, "#f6ecd4")
	p.vline(x + ww + 1, y - 1, wh + 3, frame_d)
	# glass: three bands of sky
	p.rect(x, y, ww, wh, sky.sky)
	p.rect(x, y, ww, 4, sky.sky2)
	p.rect(x, y + 4, ww, 2, Pix.mix(sky.sky2, sky.sky, 0.5))
	var drift: int = int(frame / 9.0) % 26
	if sky.night:
		# stars that take turns to twinkle, and a crescent moon
		var tw: int = int(frame / 5.0) % 3
		var stars: Array = [[2, 1], [6, 3], [13, 2], [9, 6], [4, 6], [14, 7]]
		for i in range(stars.size()):
			var bright: bool = (i + tw) % 3 != 0
			p.set_px(x + stars[i][0], y + stars[i][1], "#ffffff" if bright else "#7f86c9")
		p.rect(x + 10, y + 2, 3, 3, "#fff3b0")
		p.set_px(x + 10, y + 2, sky.sky2)
		p.set_px(x + 11, y + 3, "#e9d98a")
	elif sky.dawn:
		# a low sun in a band of light
		p.rect(x, y + 7, ww, 2, Pix.mix(sky.sky, "#fff1c4", 0.45))
		p.rect(x + 3, y + 6, 4, 3, "#fff1c4")
		p.hline(x + 4, y + 5, 2, "#fff1c4")
	else:
		# a sun with a soft ring, and clouds drifting across
		p.rect(x + 10, y + 1, 4, 4, Pix.mix(sky.sky2, "#fff59d", 0.55))
		p.rect(x + 11, y + 2, 2, 2, "#fffbe0")
		for cl in [[drift - 5, 2, 4], [drift - 16, 5, 5]]:
			var cx: int = x + int(cl[0])
			var cy: int = y + int(cl[1])
			for k in range(int(cl[2])):
				_clip_px(p, cx + k, cy + 1, x, x + ww, "#ffffff")
			for k in range(1, int(cl[2]) - 1):
				_clip_px(p, cx + k, cy, x, x + ww, "#ffffff")
	# hills, a nearer one in front
	var far: String = "#1c2b4d" if sky.night else ("#6f8f7a" if sky.dawn else "#74b47a")
	var near: String = "#121c36" if sky.night else ("#3f6f55" if sky.dawn else "#4f8f5a")
	p.rect(x, y + wh - 4, ww, 4, far)
	p.hline(x + 8, y + wh - 6, 6, far)
	p.hline(x + 9, y + wh - 7, 3, far)
	p.rect(x, y + wh - 2, ww, 2, near)
	p.hline(x + 1, y + wh - 3, 6, near)
	p.hline(x + 2, y + wh - 4, 3, near)
	# a glint on the glass
	var glint: String = Pix.mix(sky.sky2, "#ffffff", 0.55)
	p.set_px(x + 1, y + 1, glint)
	p.set_px(x + 2, y + 1, glint)
	p.set_px(x + 1, y + 2, glint)
	# cross bars
	p.vline(x + int(floor(ww / 2.0)), y, wh, frame_c)
	p.hline(x, y + int(floor(wh / 2.0)), ww, frame_c)
	p.hline(x, y, ww, Pix.mix(sky.sky2, "#000000", 0.25))
	# sill
	p.hline(x - 3, y + wh + 2, ww + 6, "#f6ecd4")
	p.hline(x - 3, y + wh + 3, ww + 6, frame_d)


static func _draw_scene_lit(p: Pix, s: Dictionary) -> void:
	var stage: int = int(s.stage)
	var frame: int = int(s.frame)
	var lift_level: int = int(s.liftLevel)
	var climb_level: int = int(s.climbLevel)
	var run_level: int = int(s.runLevel)
	var ride_level: int = int(s.rideLevel)
	var achievements: int = int(s.achievements)
	var sessions: int = int(s.sessions)

	var wall: String = WALLS[mini(5, stage)]
	var floor_c: String = FLOORS[mini(5, stage)]
	# --- the room: wallpaper, ceiling shade, wainscot, plank floor ------------
	p.rect(0, 0, SCENE_W, FLOOR_Y, wall)
	var stripe: String = Pix.shade(wall, 0.94)
	for x in range(8, SCENE_W, 16):
		p.rect(x, 0, 8, FLOOR_Y, stripe)
	p.hline(0, 0, SCENE_W, Pix.shade(wall, 0.7))
	p.hline(0, 1, SCENE_W, Pix.shade(wall, 0.84))
	if stage >= 2:
		var board: String = Pix.shade(wall, 0.86)
		p.rect(0, 56, SCENE_W, FLOOR_Y - 56, board)
		p.hline(0, 55, SCENE_W, Pix.shade(wall, 1.32))
		p.hline(0, 56, SCENE_W, Pix.shade(wall, 1.1))
		for x in range(5, SCENE_W, 8):
			p.vline(x, 58, FLOOR_Y - 60, Pix.shade(board, 0.88))
	p.hline(0, FLOOR_Y - 2, SCENE_W, Pix.shade(wall, 1.22))
	p.hline(0, FLOOR_Y - 1, SCENE_W, Pix.shade(wall, 0.66))
	p.rect(0, FLOOR_Y, SCENE_W, SCENE_H - FLOOR_Y, floor_c)
	p.hline(0, FLOOR_Y, SCENE_W, Pix.shade(floor_c, 1.38))
	p.hline(0, FLOOR_Y + 2, SCENE_W, Pix.shade(floor_c, 0.8))
	var seam: String = Pix.shade(floor_c, 0.8)
	for x in range(5, SCENE_W, 16):
		p.set_px(x, FLOOR_Y + 1, seam)
	for x in range(13, SCENE_W, 16):
		p.vline(x, FLOOR_Y + 3, SCENE_H - FLOOR_Y - 3, seam)
	p.hline(0, SCENE_H - 1, SCENE_W, Pix.shade(floor_c, 0.7))

	_draw_window_lit(p, int(s.hour), frame)

	# --- poster: pinned, with a peak on it ---------------------------------------
	var px0: int = 74
	var py0: int = 14
	p.rect(px0 + 1, py0 + 1, 10, 12, Pix.shade(wall, 0.72))
	p.rect(px0, py0, 10, 12, "#f4ecd8")
	var ink: String = ["#ff7a59", "#8ad46a", "#5ad1e6", "#c792ea"][stage % 4]
	p.rect(px0 + 1, py0 + 1, 8, 6, ink)
	p.hline(px0 + 3, py0 + 5, 4, Pix.shade(ink, 0.62))
	p.hline(px0 + 4, py0 + 4, 2, Pix.shade(ink, 0.62))
	p.set_px(px0 + 4, py0 + 3, "#ffffff")
	p.set_px(px0 + 7, py0 + 2, "#fff3b0")
	p.hline(px0 + 2, py0 + 8, 6, "#555555")
	p.hline(px0 + 2, py0 + 10, 4, "#888888")
	p.set_px(px0 + 5, py0, "#d64545")

	# --- trophy shelf -------------------------------------------------------
	if achievements >= 3:
		var x: int = 2
		var y: int = 8
		p.hline(x, y, 22, "#a8825a")
		p.hline(x, y + 1, 22, "#6b4f36")
		p.set_px(x + 2, y + 2, "#4b3524")
		p.set_px(x + 19, y + 2, "#4b3524")
		var n: int = mini(5, int(floor(achievements / 6.0)) + 1)
		for i in range(n):
			var tx: int = x + 1 + i * 4
			var gold: String = "#ffd54f" if i % 3 == 0 else ("#cfd8dc" if i % 3 == 1 else "#ffab91")
			p.rect(tx, y - 4, 3, 2, gold)
			p.set_px(tx + 1, y - 2, gold)
			p.hline(tx, y - 1, 3, Pix.shade(gold, 0.7))
			p.set_px(tx, y - 5, gold)
			p.set_px(tx + 2, y - 5, gold)
			p.set_px(tx, y - 4, Pix.shade(gold, 1.5))

	# --- climbing wall (center, behind the hero): holds on a plywood panel ---
	if climb_level >= 1:
		var ply: String = Pix.mix(wall, "#c49a63", 0.46)
		p.rect(26, 5, 38, 39, ply)
		p.hline(26, 5, 38, Pix.shade(ply, 1.18))
		p.vline(26, 5, 39, Pix.shade(ply, 1.1))
		p.vline(63, 5, 39, Pix.shade(ply, 0.78))
		p.hline(26, 43, 38, Pix.shade(ply, 0.72))
		p.hline(27, 24, 36, Pix.shade(ply, 0.9))
		for bolt in [[28, 7], [61, 7], [28, 41], [61, 41]]:
			p.set_px(bolt[0], bolt[1], Pix.shade(ply, 0.6))
		var n: int = mini(16, 3 + climb_level)
		var cols: Array = ["#ff5252", "#ffd740", "#69f0ae", "#40c4ff", "#ff4081", "#ffab40"]
		for i in range(n):
			var hold: Array = HOLDS[i]
			var hx: int = hold[0]
			var hy: int = hold[1]
			var shape_w: int = hold[2]
			if hx + shape_w > 62 or hy < 7:
				continue
			var c: String = cols[i % cols.size()]
			p.hline(hx, hy + 2, shape_w, Pix.shade(ply, 0.7))
			p.rect(hx, hy, shape_w, 2, c)
			p.set_px(hx, hy, Pix.shade(c, 1.4))
			p.set_px(hx + shape_w - 1, hy + 1, Pix.shade(c, 0.7))
		if climb_level >= 8:
			# hangboard
			p.rect(33, 8, 24, 5, "#a9825a")
			p.hline(33, 8, 24, "#d2ad84")
			p.hline(33, 12, 24, "#7a5b3c")
			for k in range(4):
				p.rect(35 + k * 6, 10, 3, 1, "#4e3a28")

	# --- string lights on a sagging wire ---------------------------------------
	if stage >= 3:
		var cols2: Array = ["#ff5252", "#ffd740", "#69f0ae", "#40c4ff", "#ff4081"]
		for x in range(SCENE_W):
			var sag: int = 2 + int(round(1.4 * sin(float(x % 24) / 24.0 * PI)))
			p.set_px(x, sag, "#241d38")
		for x in range(3, SCENE_W, 6):
			var i: int = int(x / 6.0)
			var on: bool = (i + frame) % 5 != 0
			var c: String = cols2[i % cols2.size()]
			var sag: int = 3 + int(round(1.4 * sin(float(x % 24) / 24.0 * PI)))
			p.set_px(x, sag, c if on else Pix.shade(c, 0.45))
			if on:
				p.set_px(x, sag + 1, Pix.shade(c, 1.45) if frame % 2 == 0 else c)

	# --- squat rack + dumbbells (left) --------------------------------------
	if lift_level >= 10:
		var steel: String = "#66717f"
		p.rect(3, 24, 2, 43, steel)
		p.rect(19, 24, 2, 43, steel)
		p.vline(3, 24, 43, "#8a97a6")
		p.vline(19, 24, 43, "#8a97a6")
		p.hline(3, 24, 18, "#8a97a6")
		p.hline(3, 25, 18, steel)
		for y in range(30, 60, 6):
			p.set_px(4, y, "#3a4350")
			p.set_px(20, y, "#3a4350")
		# loaded bar on the rack
		p.hline(0, 34, 24, "#c3ccd6")
		p.hline(0, 35, 24, "#7d8792")
		p.rect(0, 31, 2, 8, "#d64545")
		p.rect(22, 31, 2, 8, "#d64545")
		p.vline(0, 31, 8, "#f07070")
		p.vline(22, 31, 8, "#f07070")
	if lift_level >= 3:
		var x: int = 2
		var shelves: int = 2 if lift_level >= 6 else 1
		for sh in range(shelves):
			var y: int = FLOOR_Y - 2 - sh * 6
			p.hline(x, y, 18, "#5a4634")
			p.hline(x, y + 1, 18, "#2e2419")
			for d in range(3):
				var dx: int = x + 1 + d * 6
				var c: String = ["#9e9e9e", "#78909c", "#546e7a"][(d + sh) % 3]
				p.rect(dx, y - 3, 1, 3, c)
				p.rect(dx + 3, y - 3, 1, 3, c)
				p.set_px(dx, y - 3, Pix.shade(c, 1.4))
				p.set_px(dx + 3, y - 3, Pix.shade(c, 1.4))
				p.hline(dx + 1, y - 2, 2, "#cfd8dc")
		p.vline(x, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, "#5a4634")
		p.vline(x + 17, FLOOR_Y - 2 - (shelves - 1) * 6, (shelves - 1) * 6 + 2, "#3a2c20")

	# --- bike on the wall (right) --------------------------------------------
	if ride_level >= 5:
		var bx: int = 66
		var by: int = 30
		var tire: String = "#263238"
		var rim: String = "#90a4ae"
		var frame_c: String = "#ffeb3b" if ride_level >= 20 else "#e53935"
		var under: String = stripe if ((bx + 5 - 8) % 16) < 8 else wall
		for cx in [bx + 5, bx + 20]:
			p.ellipse(cx, by + 10, 5, 5, tire)
			# what shows through the wheel is the wallpaper behind it
			for yy in range(by + 6, by + 15):
				for xx in range(cx - 4, cx + 5):
					var dx: float = (xx + 0.5 - cx) / 4.0
					var dy: float = (yy + 0.5 - (by + 10)) / 4.0
					if dx * dx + dy * dy <= 1.0:
						p.set_px(xx, yy, stripe if (xx >= 8 and ((xx - 8) % 16) < 8) else wall)
			p.set_px(cx, by + 10, rim)
			p.set_px(cx - 2, by + 10, rim)
			p.set_px(cx + 2, by + 10, rim)
			p.set_px(cx, by + 8, rim)
			p.set_px(cx, by + 12, rim)
			p.set_px(cx - 3, by + 6, "#455a64")
		p.limb(bx + 5, by + 10, bx + 11, by + 3, 1, frame_c)
		p.limb(bx + 11, by + 3, bx + 18, by + 3, 1, frame_c)
		p.limb(bx + 18, by + 3, bx + 20, by + 10, 1, frame_c)
		p.limb(bx + 11, by + 3, bx + 12, by + 10, 1, frame_c)
		p.limb(bx + 12, by + 10, bx + 5, by + 10, 1, frame_c)
		p.limb(bx + 12, by + 10, bx + 18, by + 3, 1, frame_c)
		p.set_px(bx + 11, by + 3, Pix.shade(frame_c, 1.5))
		p.rect(bx + 10, by + 1, 3, 1, "#263238") # saddle
		p.rect(bx + 18, by + 1, 2, 1, "#263238") # bars
		# wall hook
		p.vline(bx + 12, by - 4, 5, "#5c6673")
		p.set_px(bx + 12, by - 5, "#8a97a6")

	# --- treadmill (right, behind the pet) ----------------------------------
	if run_level >= 5:
		var x: int = 62
		p.rect(x, FLOOR_Y - 4, 29, 4, "#37474f")
		p.hline(x, FLOOR_Y - 4, 29, "#56666f")
		p.rect(x + 1, FLOOR_Y - 3, 27, 2, "#546e7a")
		for k in range(0, 27, 3):
			p.set_px(x + 1 + ((k + frame) % 27), FLOOR_Y - 2, "#90a4ae")
		p.rect(x + 25, FLOOR_Y - 16, 2, 12, "#546e7a")
		p.vline(x + 25, FLOOR_Y - 16, 12, "#78909c")
		p.rect(x + 20, FLOOR_Y - 19, 10, 4, "#37474f")
		p.hline(x + 20, FLOOR_Y - 19, 10, "#56666f")
		p.rect(x + 21, FLOOR_Y - 18, 5, 2, "#69f0ae" if frame % 6 < 3 else "#40c4ff")
		p.set_px(x + 28, FLOOR_Y - 17, "#ff5252" if frame % 4 < 2 else "#7f2a2a")
		p.hline(x, FLOOR_Y, 29, Pix.shade(floor_c, 0.7))

	# --- plant: its leaves sway --------------------------------------------------
	if sessions >= 5:
		var x: int = 86
		var sway: int = 1 if int(frame / 6.0) % 4 == 1 else (-1 if int(frame / 6.0) % 4 == 3 else 0)
		p.rect(x, FLOOR_Y - 6, 6, 6, "#b5651d")
		p.vline(x + 5, FLOOR_Y - 6, 6, "#8c4d16")
		p.hline(x - 1, FLOOR_Y - 6, 8, "#d2843b")
		p.hline(x - 1, FLOOR_Y, 8, Pix.shade(floor_c, 0.7))
		var g: String = "#43a047"
		var g2: String = "#66bb6a"
		var g3: String = "#2e7d32"
		p.rect(x + 1, FLOOR_Y - 12, 4, 6, g)
		p.vline(x + 4, FLOOR_Y - 12, 6, g3)
		p.set_px(x + sway, FLOOR_Y - 10, g2)
		p.set_px(x + 5 + sway, FLOOR_Y - 11, g2)
		p.set_px(x - 1 + sway, FLOOR_Y - 9, g)
		p.set_px(x + 6 + sway, FLOOR_Y - 10, g)
		p.set_px(x + 2 + sway, FLOOR_Y - 14, g2)
		p.set_px(x + 3 + sway, FLOOR_Y - 13, g)
		p.set_px(x + 1 + sway, FLOOR_Y - 13, g)
		p.set_px(x + 2, FLOOR_Y - 11, g2)

	# --- rug: a border, a fringe at each end ---------------------------------------
	if stage >= 2:
		p.rect(28, FLOOR_Y + 1, 40, 3, "#8e2a3a")
		p.hline(28, FLOOR_Y + 1, 40, "#d6b25a")
		p.hline(28, FLOOR_Y + 3, 40, "#a3823a")
		p.hline(30, FLOOR_Y + 2, 36, "#a83448")
		for x in range(32, 66, 6):
			p.set_px(x, FLOOR_Y + 2, "#d6b25a")
		p.set_px(27, FLOOR_Y + 2, "#d6b25a")
		p.set_px(68, FLOOR_Y + 2, "#d6b25a")


## Darken the floor under something that stands at columns x0..x1 (its feet on
## the floor line): the shadow it throws.
static func shadow_under(p: Pix, x0: int, x1: int) -> void:
	for row in range(2):
		var y: int = FLOOR_Y + row
		for x in range(x0 - 1 + row * 2, x1 + 2 - row * 2):
			if x < 0 or x >= p.w or y >= p.h:
				continue
			var i: int = y * p.w + x
			if p.data[i] != 0:
				p.data[i] = Pix.shade_raw(p.data[i], 0.66)
