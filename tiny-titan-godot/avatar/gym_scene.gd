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
