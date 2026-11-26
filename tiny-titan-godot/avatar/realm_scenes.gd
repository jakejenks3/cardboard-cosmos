class_name RealmScenes
extends RefCounted
## The backdrops of the Realm's battles (RPG_PLAN.md 12): one picture per
## region of RpgDefs.REGIONS, and one each for the Spire ("spire"), the daily
## hunt ("hunt") and the weekly rival ("rival"). Drawn in code into a 110 x 60
## Pix buffer (shown x4 it is 440 wide), in the game's own look.
##
##   RealmScenes.texture("chalk")     # cached
##   RealmScenes.ground_y("chalk")    # the pixel row the foes stand on
##   RealmScenes.tint("chalk")        # the region's key colour, "#rrggbb"
##
## Every picture is built the same way, so a battle can lay its units out once:
## a sky (or a wall) down to HORIZON, far shapes in front of it, a ground band
## across the lower third, two or three props at the sides. The foes are drawn
## over the middle, so that band is kept calm: big, low-contrast shapes, no
## detail. Lit from the top left: tops and left edges a shade lighter, right
## sides and undersides darker, a shadow to the right of what stands.
##
## Nothing moves in here (one frame, cached): what should move in a battle is
## the units.

const W = 110
const H = 60
## The row where the ground begins.
const HORIZON = 38
## The row the foes' feet are on.
const GROUND_Y = 52
const EXTRA = ["spire", "hunt", "rival"]
## The scene an unknown id is drawn as.
const FALLBACK = "hunt"
## The key colour of each scene (frames, name plates).
const TINTS = {
	"rustyard": "#c86a3a", "greenmile": "#5fae4b", "chalk": "#8fc7e8", "stacks": "#e0a53a",
	"ironworks": "#ff8a2a", "marsh": "#3fa89a", "stormspine": "#8fb8e8", "titans_rest": "#c9a23a",
	"spire": "#8a7fe0", "hunt": "#e0703a", "rival": "#d84a5a",
}
## Ordered dither thresholds, 4 x 4.
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _tex = {} # scene id -> ImageTexture


## Every scene there is, the regions first.
static func all() -> Array:
	var out = RpgDefs.REGIONS.duplicate()
	out.append_array(EXTRA)
	return out


static func has(scene_id: String) -> bool:
	return TINTS.has(scene_id)


## The scene that is drawn for an id (an unknown one: the hunt's clearing).
static func scene_of(scene_id: String) -> String:
	return scene_id if TINTS.has(scene_id) else FALLBACK


## The scene a battle is fought in. `kind` is what the battle is ("stage",
## "echo", "hunt", "rival" or "spire": the kinds of RpgUi.fight), `region` the
## region of its stage: the hunt, the rival and the Spire have their own
## picture, a stage and its echo the region's.
static func scene_for(kind: String, region: String = "") -> String:
	if EXTRA.has(kind):
		return kind
	return scene_of(region)


## The pixel row (of the 110 x 60 picture) the foes stand on.
static func ground_y(_scene_id: String = "") -> int:
	return GROUND_Y


## The scene's key colour, "#rrggbb".
static func tint(scene_id: String) -> String:
	return str(TINTS[scene_of(scene_id)])


## The whole picture as a buffer.
static func pix(scene_id: String) -> Pix:
	var p = Pix.new(W, H)
	draw(p, scene_id)
	return p


static func texture(scene_id: String) -> ImageTexture:
	var key = scene_of(scene_id)
	var tex = _tex.get(key)
	if tex == null:
		tex = pix(key).to_texture()
		_tex[key] = tex
	return tex


static func clear_cache() -> void:
	_tex.clear()


## Paint a scene over the whole of `p` (W x H).
static func draw(p: Pix, scene_id: String) -> void:
	match scene_of(scene_id):
		"rustyard":
			_rustyard(p)
		"greenmile":
			_greenmile(p)
		"chalk":
			_chalk(p)
		"stacks":
			_stacks(p)
		"ironworks":
			_ironworks(p)
		"marsh":
			_marsh(p)
		"stormspine":
			_stormspine(p)
		"titans_rest":
			_titans_rest(p)
		"spire":
			_spire(p)
		"rival":
			_rival(p)
		_:
			_hunt(p)


# --- brushes ------------------------------------------------------------------

static func _bayer(x: int, y: int) -> int:
	return int(BAYER[(y & 3) * 4 + (x & 3)])


## A number 0..n-1 that belongs to a pixel: the same picture every time.
static func _noise(x: int, y: int, salt: int, n: int) -> int:
	var v = ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff
	v = (v * 1103515245 + 12345) & 0x7fffffff
	return int(v >> 8) % maxi(1, n)


## Rows y0 .. y1-1 of columns x0 .. x1-1 from `top` to `low` in `steps` flat
## bands, dithered where two bands meet.
static func _fade(p: Pix, x0: int, x1: int, y0: int, y1: int, top: String, low: String, steps: int = 5) -> void:
	var cols = []
	for i in range(steps):
		cols.append(Pix.mix(top, low, float(i) / float(maxi(1, steps - 1))))
	var span = float(maxi(1, y1 - y0))
	for y in range(y0, y1):
		var f = float(y - y0) / span * float(steps - 1)
		var band = mini(int(floor(f)), steps - 1)
		var frac = f - float(band)
		for x in range(x0, x1):
			var pick = band
			if band < steps - 1 and frac * 16.0 > float(_bayer(x, y)):
				pick = band + 1
			p.set_px(x, y, cols[pick])


## The height of a rolling line at column x (about -1 .. 1).
static func _roll(x: int, stretch: float, seed_shift: float) -> float:
	var fx = float(x) * stretch
	return 0.5 * sin(fx * 0.045 + seed_shift) + 0.3 * sin(fx * 0.11 + seed_shift * 2.3) + 0.2 * sin(fx * 0.23 + seed_shift * 3.7)


## A skyline: every column filled from a rolling height down to `bottom`.
## `step` > 1 makes it blocky (heaps, far cliffs); `lit` colours its top pixel.
static func _ridge(p: Pix, base: int, amp: float, bottom: int, col: String, seed_shift: float, stretch: float = 1.0, step: int = 1, lit: String = "") -> void:
	for x in range(W):
		var qx = x - (x % maxi(1, step))
		var top = base - int(round(_roll(qx, stretch, seed_shift) * amp))
		if top >= bottom:
			continue
		p.rect(x, top, 1, bottom - top, col)
		if lit != "":
			p.set_px(x, top, lit)


## The ground: from `y0` down, lighter along its far edge, darker towards the viewer.
static func _ground(p: Pix, col: String, y0: int = HORIZON) -> void:
	_fade(p, 0, W, y0, H, Pix.shade(col, 1.1), Pix.shade(col, 0.78), 4)
	p.hline(0, y0, W, Pix.shade(col, 1.32))


## Single pixels scattered over rows y0 .. y1-1: about one in `one_in`.
static func _speckle(p: Pix, y0: int, y1: int, col: String, one_in: int, salt: int, x0: int = 0, x1: int = W) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _noise(x, y, salt, one_in) == 0:
				p.set_px(x, y, col)


## A soft light round a point (a lamp, a fire): what is there is mixed towards
## `col`, less with distance, in four dithered steps so it stays pixel art.
static func _glow(p: Pix, cx: int, cy: int, radius: int, col: String, strength: float = 0.6) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var under = p.get_px(x, y)
			if under == null:
				continue
			var d = sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy))) / float(maxi(1, radius))
			if d >= 1.0:
				continue
			var q = floor((1.0 - d) * strength * 4.0 + float(_bayer(x, y)) / 16.0) / 4.0
			if q > 0.0:
				p.set_px(x, y, Pix.mix(str(under), col, minf(1.0, q)))


## A box lit from the top left.
static func _block(p: Pix, x: int, y: int, bw: int, bh: int, col: String) -> void:
	p.rect(x, y, bw, bh, col)
	p.vline(x + bw - 1, y, bh, Pix.shade(col, 0.76))
	p.hline(x, y + bh - 1, bw, Pix.shade(col, 0.7))
	p.vline(x, y, bh, Pix.shade(col, 1.12))
	p.hline(x, y, bw, Pix.shade(col, 1.26))


## What is on row y between x0 and x1-1, a shade darker: the shadow of a prop.
static func _shadow(p: Pix, x0: int, x1: int, y: int, by: float = 0.74) -> void:
	for x in range(x0, x1):
		var under = p.get_px(x, y)
		if under != null:
			p.set_px(x, y, Pix.shade(str(under), by))


## A mountain: a triangle from its peak down to `bottom`, its right side in
## shade, `cap` rows of snow (or light) at the top.
static func _peak(p: Pix, cx: int, top: int, bottom: int, slope: float, col: String, cap: int = 0, cap_col: String = "") -> void:
	for y in range(top, bottom):
		var half = int(floor(float(y - top) * slope))
		p.rect(cx - half, y, half + 1, 1, col)
		p.rect(cx + 1, y, half, 1, Pix.shade(col, 0.84))
		if cap > 0 and y - top < cap + _noise(cx, y, 5, 2):
			p.rect(cx - half, y, half + 1, 1, cap_col)
			p.rect(cx + 1, y, half, 1, Pix.shade(cap_col, 0.86))


## A flame: a small teardrop, hot in the middle.
static func _flame(p: Pix, x: int, y: int, outer: String = "#ff8a2a", inner: String = "#ffe07a") -> void:
	p.set_px(x, y - 3, outer)
	p.rect(x - 1, y - 2, 2, 1, outer)
	p.rect(x - 1, y - 1, 3, 2, outer)
	p.set_px(x, y - 1, inner)
	p.set_px(x, y, inner)


# --- the regions --------------------------------------------------------------

## The Rustyard: a scrapyard of old gym iron under a dusty sky.
static func _rustyard(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#7f9db5", "#ecd2a8", 6)
	p.ellipse(84.5, 10.5, 3.0, 3.0, "#fbf0d2")
	_glow(p, 84, 10, 10, "#fbf0d2", 0.4)
	# far heaps in the haze, with a bar or two sticking out
	_ridge(p, 31, 3.5, HORIZON, "#d0b594", 1.3, 1.0, 3, "#dcc4a4")
	for spot in [[22, 24, 6], [49, 26, 5], [71, 25, 6]]:
		p.vline(spot[0], spot[1], spot[2], "#c2a685")
		p.hline(spot[0] - 1, spot[1], 3, "#c2a685")
	# nearer heaps at the sides only
	for x in range(W):
		var edge = mini(x, W - 1 - x)
		var hgt = 10 - int(floor(float(edge) / 2.6)) + _noise(int(x / 3.0), 1, 3, 3)
		if edge < 26 and hgt > 0:
			p.rect(x, HORIZON - hgt, 1, hgt, "#a98468")
			p.set_px(x, HORIZON - hgt, "#bd9a7c")
	# the yard fence
	for x in range(28, 84, 9):
		p.vline(x, 33, 5, "#b89a7c")
	for x in range(28, 83):
		if x % 2 == 0:
			p.set_px(x, 34, "#b89a7c")
	_ground(p, "#a67c52")
	_speckle(p, HORIZON + 2, H, "#93613a", 27, 11)
	_speckle(p, HORIZON + 2, H, "#c6a274", 33, 12)
	for x in range(0, W, 2):
		p.set_px(x + _noise(x, 0, 9, 2), 56, "#8f6842")
	# left: plates stacked flat (each a rounded slab, lit on top), a kettlebell left on them
	var cols = ["#7a4a36", "#6f7a86", "#8a5236", "#5d6875", "#7a4a36"]
	for i in range(5):
		var py = 45 - i * 3
		var c = str(cols[i])
		var px = 2 + (i % 2) + (1 if i == 4 else 0)
		var pw = 14 - (i % 2) * 2 - (3 if i == 4 else 0)
		p.hline(px + 1, py, pw - 2, Pix.shade(c, 1.3))
		p.hline(px, py + 1, pw, c)
		p.hline(px + 1, py + 2, pw - 2, Pix.shade(c, 0.72))
		p.set_px(px + pw - 1, py + 1, Pix.shade(c, 0.8))
	p.rect(6, 29, 4, 4, "#4a4f5c")
	p.hline(6, 29, 4, "#6f7684")
	p.vline(9, 30, 3, "#363a45")
	p.hline(7, 27, 2, "#6f7684")
	p.set_px(6, 28, "#4a4f5c")
	p.set_px(9, 28, "#4a4f5c")
	_shadow(p, 3, 20, 48)
	_shadow(p, 15, 21, 47)
	# right: a dented locker, a bar leaning on it
	_block(p, 97, 19, 11, 26, "#8793a0")
	p.vline(102, 20, 24, "#66727f")
	for y in [22, 24, 26]:
		p.hline(98, y, 3, "#55606c")
		p.hline(104, y, 3, "#55606c")
	p.rect(99, 34, 2, 5, "#a85a32")
	p.set_px(100, 39, "#a85a32")
	p.set_px(105, 30, "#c9d2dc")
	p.rect(104, 40, 3, 3, "#a85a32")
	for i in range(21):
		p.set_px(91 + int(round(float(i) * 0.3)), 45 - i, "#5d6875")
	p.rect(89, 42, 3, 5, "#6a4a3c")
	p.vline(89, 42, 5, "#86604e")
	_shadow(p, 92, W, 45)
	_shadow(p, 96, W, 46)
	# front: a plate half in the dirt
	p.ellipse(74.0, 60.5, 6.0, 2.5, "#6a4a3c")
	p.hline(70, 58, 8, "#86604e")


## The Greenmile: a trail through rolling green country.
static func _greenmile(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#58a4e0", "#d0ecf7", 6)
	for cl in [[20, 6, 15], [58, 3, 19], [86, 11, 12]]:
		p.hline(cl[0] + 2, cl[1], cl[2] - 5, "#ffffff")
		p.hline(cl[0], cl[1] + 1, cl[2], "#ffffff")
		p.hline(cl[0] + 1, cl[1] + 2, cl[2] - 3, "#e3f1f9")
	_ridge(p, 30, 4.0, HORIZON, "#aadba2", 0.6, 0.8, 1, "#bfe8b6")
	_ridge(p, 35, 2.5, HORIZON, "#82c872", 2.1, 1.4, 1, "#96d886")
	_ground(p, "#5fae4b")
	_speckle(p, HORIZON + 1, 46, "#43883a", 7, 21)
	_speckle(p, HORIZON + 1, 45, "#fff3b0", 41, 22)
	_speckle(p, HORIZON + 1, 45, "#f7a8c0", 53, 23)
	# the trail the fight is on
	_fade(p, 0, W, 46, 57, "#d6b07e", "#b98f5e", 3)
	p.hline(0, 46, W, "#e6c594")
	for x in range(W):
		if _noise(x, 45, 24, 3) == 0:
			p.set_px(x, 46, "#5fae4b")
		if _noise(x, 57, 25, 3) == 0:
			p.set_px(x, 56, "#4c9a3e")
	_speckle(p, 48, 56, "#a07a4e", 29, 26)
	_fade(p, 0, W, 57, H, "#4c9a3e", "#3d7a35", 2)
	_speckle(p, 57, H, "#7cc46a", 6, 27)
	# left: a tree
	p.rect(6, 22, 3, 23, "#7a5a36")
	p.vline(6, 22, 23, "#98764c")
	p.vline(8, 22, 23, "#5c4429")
	p.ellipse(8.0, 15.0, 8.5, 8.0, "#3d8a3a")
	p.ellipse(11.5, 19.5, 5.0, 4.5, "#2f7030")
	p.ellipse(4.5, 11.0, 4.5, 4.0, "#57a84a")
	p.set_px(3, 9, "#8fd46a")
	p.set_px(5, 8, "#8fd46a")
	p.set_px(9, 12, "#57a84a")
	p.set_px(13, 16, "#3d8a3a")
	_shadow(p, 5, 22, 45)
	_shadow(p, 8, 20, 44)
	# right: a mile post
	p.rect(101, 31, 2, 15, "#b08a5a")
	p.vline(102, 31, 15, "#7a5a36")
	_block(p, 96, 28, 12, 6, "#f3ecd8")
	p.rect(99, 30, 1, 2, "#d64545")
	p.rect(101, 30, 3, 2, "#d64545")
	p.set_px(102, 30, "#f3ecd8")
	_shadow(p, 103, W, 46)
	# a fence where the far side of the trail runs off
	for x in [84, 90, 96, 108]:
		p.vline(x, 40, 4, "#9a7a50")
	p.hline(84, 41, 13, "#9a7a50")


## Chalk Cliffs: a pale ledge between two walls of white rock.
static func _chalk(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#4f9ede", "#d6eef9", 6)
	p.set_px(40, 8, "#5a6478")
	p.set_px(41, 9, "#5a6478")
	p.set_px(42, 8, "#5a6478")
	p.set_px(66, 13, "#5a6478")
	p.set_px(67, 14, "#5a6478")
	p.set_px(68, 13, "#5a6478")
	# far cliffs in the haze
	_ridge(p, 32, 2.5, HORIZON, "#c3dcea", 0.9, 0.5, 5, "#d3e8f2")
	# the walls: the left one leans in, the right one catches the light
	for y in range(HORIZON):
		var lw = 20 - int(floor(float(y) / 3.2)) + _noise(0, int(y / 3.0), 31, 2)
		p.rect(0, y, lw, 1, "#e6e1d4")
		p.rect(maxi(0, lw - 2), y, 2, 1, "#b9b2a2")
		if y % 5 == 3:
			p.hline(0, y, maxi(0, lw - 2), "#d2ccbc")
		var rx = 92 + int(floor(float(y) / 4.5)) - _noise(1, int(y / 3.0), 32, 2)
		p.rect(rx, y, W - rx, 1, "#dcd6c8")
		p.rect(rx, y, 2, 1, "#f6f3ea")
		if y % 5 == 1:
			p.hline(rx + 2, y, W - rx - 2, "#c8c1b1")
	# holds and a rope on the left wall
	p.rect(4, 9, 2, 1, "#e05a4a")
	p.rect(10, 15, 2, 1, "#4a9ae0")
	p.rect(3, 22, 2, 1, "#f0c040")
	p.rect(7, 29, 2, 1, "#e05a4a")
	for y in range(0, 27):
		p.set_px(15 - int(floor(float(y) / 9.0)), y, "#c9a66b" if y % 3 != 0 else "#a8854a")
	p.rect(12, 27, 2, 2, "#a8854a")
	_ground(p, "#d6d0c2")
	for crack in [[14, 43, 7], [48, 47, 9], [80, 42, 6], [30, 54, 8], [66, 55, 7], [95, 51, 5]]:
		p.hline(crack[0], crack[1], crack[2], "#b0a999")
		p.set_px(crack[0] + crack[2], crack[1] + 1, "#b0a999")
	_speckle(p, HORIZON + 1, 56, "#f6f3ea", 23, 33)
	# the ledge ends at the front
	p.rect(0, 57, W, 3, "#958e7e")
	p.hline(0, 57, W, "#b9b2a2")
	_speckle(p, 58, H, "#7c7567", 5, 34)
	# left: a boulder; right: a chalk bucket
	p.ellipse(4.0, 44.5, 7.0, 4.0, "#c2bbab")
	p.ellipse(2.5, 43.0, 4.0, 2.0, "#e2ddd0")
	p.hline(0, 48, 10, "#958e7e")
	_shadow(p, 10, 16, 48)
	_block(p, 98, 43, 8, 7, "#4a7ab0")
	p.hline(98, 43, 8, "#ffffff")
	p.hline(99, 42, 6, "#f6f3ea")
	p.hline(98, 45, 8, "#3a6294")
	_shadow(p, 106, W, 49)
	_shadow(p, 100, W, 50)


## The Stacks: shelves to the ceiling by candle light.
static func _stacks(p: Pix) -> void:
	p.rect(0, 0, W, HORIZON, "#2b2230")
	var spines = ["#7a3f46", "#42507a", "#62623c", "#7a5a34", "#56406a", "#3c645a", "#8a6a3a"]
	var boards = [8, 18, 28, 37]
	var from = 0
	for b in boards:
		var x = 1
		var i = 0
		while x < W - 1:
			var bw = 2 + _noise(x, b, 41, 2)
			var gap = _noise(x, b, 42, 9) == 0
			var tall = (b - from - 1) - _noise(x, b, 43, 3)
			if not gap:
				var c = str(spines[_noise(x, b, 44, spines.size())])
				# the middle of the wall stays in the dark: the foes stand in front of it
				c = Pix.shade(c, 0.62 if (b > 8 and x > 22 and x < 92) else 0.86)
				p.rect(x, b - tall, bw, tall, c)
				p.vline(x, b - tall, tall, Pix.shade(c, 1.2))
				if tall > 4 and i % 3 == 0:
					p.hline(x, b - tall + 2, bw, Pix.shade(c, 1.45))
			x += bw + (1 if gap else 0)
			i += 1
		p.hline(0, b, W, "#6f4d38")
		p.hline(0, b + 1, W, "#1d1722")
		from = b + 1
	for x in [0, 37, 73, 109]:
		p.vline(x, 0, HORIZON, "#4f372c")
	_ground(p, "#7a5a40")
	for x in range(7, W, 19):
		p.vline(x, HORIZON + 1, 6, "#5f4530")
	# the runner the fight is on
	_fade(p, 0, W, 45, 57, "#73334e", "#5a2740", 3)
	p.hline(0, 45, W, "#d0a544")
	p.hline(0, 56, W, "#a8842e")
	for x in range(4, W, 8):
		p.set_px(x, 50, "#8a4864")
		p.set_px(x + 4, 52, "#8a4864")
	p.rect(0, 57, W, 3, "#5f4530")
	p.hline(0, 57, W, "#7a5a40")
	# a hanging lamp
	p.vline(62, 0, 4, "#8a7a5a")
	p.rect(60, 4, 5, 2, "#c9a23a")
	p.hline(61, 6, 3, "#ffe08a")
	_glow(p, 62, 7, 9, "#ffd98a", 0.4)
	# left: books in a pile, a candle on top
	_block(p, 2, 43, 12, 3, "#42507a")
	_block(p, 3, 40, 10, 3, "#7a3f46")
	_block(p, 2, 37, 11, 3, "#62623c")
	p.rect(7, 31, 2, 6, "#f1e6c4")
	p.vline(8, 31, 6, "#c2ab7a")
	_flame(p, 7, 30, "#ff9a3a", "#ffe08a")
	_glow(p, 7, 29, 15, "#ffb347", 0.55)
	_shadow(p, 14, 20, 45)
	# right: the ladder
	for y in range(3, 46):
		p.set_px(96, y, "#9a7850")
		p.set_px(104, y, "#75583a")
	for y in range(6, 45, 5):
		p.hline(97, y, 7, "#86663f")
	_shadow(p, 104, W, 45)
	_speckle(p, 2, 30, "#8f7c58", 140, 45)


## The Ironworks: a foundry floor in the glow of the furnace.
static func _ironworks(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#17151d", "#5c2618", 6)
	# the works behind: stacks and sheds, hardly darker than the glow
	_ridge(p, 31, 4.0, HORIZON, "#3a1c1a", 2.2, 1.0, 6, "#4a2620")
	p.rect(31, 13, 4, 25, "#2a191c")
	p.vline(31, 13, 25, "#44272a")
	p.rect(75, 9, 5, 29, "#2a191c")
	p.vline(75, 9, 29, "#44272a")
	p.hline(74, 9, 7, "#44272a")
	p.hline(30, 13, 6, "#44272a")
	# pipes under the roof, a hook on a chain
	p.rect(0, 2, W, 3, "#3a3640")
	p.hline(0, 2, W, "#59545f")
	p.hline(0, 4, W, "#25222b")
	for x in range(5, W, 9):
		p.set_px(x, 3, "#6d6873")
	for y in range(5, 15):
		p.set_px(87, y, "#59545f" if y % 2 == 0 else "#3a3640")
	p.rect(86, 15, 3, 1, "#6d6873")
	p.vline(88, 16, 3, "#6d6873")
	p.hline(86, 18, 2, "#6d6873")
	# left: the furnace
	_block(p, 0, 11, 18, 27, "#35313b")
	p.rect(2, 5, 5, 6, "#2c2932")
	p.rect(4, 23, 10, 13, "#18141a")
	p.rect(5, 24, 8, 12, "#c8400f")
	p.rect(6, 26, 6, 10, "#ff8a2a")
	p.rect(7, 29, 4, 7, "#ffe07a")
	p.hline(5, 23, 8, "#18141a")
	for x in [7, 10]:
		p.vline(x, 24, 12, "#231d22")
	for x in range(2, 17, 4):
		p.set_px(x, 13, "#59545f")
		p.set_px(x, 20, "#59545f")
	_glow(p, 9, 30, 17, "#ff8a2a", 0.5)
	for spark in [[21, 20], [24, 27], [19, 14], [27, 33], [23, 9], [29, 22]]:
		p.set_px(spark[0], spark[1], "#ffb347")
	_ground(p, "#4c4852")
	for y in [44, 51]:
		p.hline(0, y, W, "#3a3640")
		p.hline(0, y + 1, W, "#5a5560")
	for x in range(0, W, 22):
		p.vline(x + 9, HORIZON + 1, 6, "#3a3640")
		p.vline(x, 46, 5, "#3a3640")
		p.vline(x + 13, 53, 4, "#3a3640")
	for x in range(3, W, 11):
		p.set_px(x, 41, "#6d6873")
		p.set_px(x + 5, 48, "#6d6873")
	# the channel of metal at the front
	p.rect(0, 56, W, 3, "#1f1a1e")
	p.hline(0, 57, W, "#ff8a2a")
	for x in range(0, W, 5):
		p.rect(x + _noise(x, 57, 51, 3), 57, 2, 1, "#ffe07a")
	p.hline(0, 59, W, "#35313b")
	for x in range(W):
		if _bayer(x, 55) < 6:
			p.set_px(x, 55, "#7a3a22")
	# right: an anvil on a block of wood, at the back of the floor (the foes stand in front of it):
	# dark iron with a lit face and a warm edge towards the furnace
	p.rect(97, 42, 10, 4, "#5a3a26")
	p.hline(97, 42, 10, "#7d5636")
	p.vline(106, 43, 3, "#3e2618")
	p.set_px(100, 44, "#3e2618")
	p.set_px(103, 44, "#3e2618")
	p.rect(97, 40, 10, 2, "#2b2831")
	p.hline(97, 40, 10, "#55505c")
	p.rect(99, 37, 6, 3, "#24212a")
	p.rect(95, 34, 13, 3, "#2b2831")
	p.hline(95, 34, 13, "#a09aa8")
	p.hline(91, 35, 4, "#2b2831")
	p.hline(92, 35, 3, "#7d7884")
	p.vline(107, 35, 2, "#1b1920")
	p.set_px(95, 36, "#c8602a")
	p.vline(99, 37, 3, "#a84a20")
	p.set_px(97, 41, "#a84a20")
	_shadow(p, 107, W, 45)
	_shadow(p, 101, W, 46)


## Mirror Marsh: still water and a mud bank at dusk.
static func _marsh(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#241f42", "#3f8a84", 6)
	p.ellipse(86.5, 9.5, 4.0, 4.0, "#e8f0d8")
	p.set_px(85, 8, "#c8d8c0")
	p.set_px(88, 11, "#c8d8c0")
	_glow(p, 86, 9, 12, "#bfe6d0", 0.35)
	_speckle(p, 0, 16, "#9fb8d0", 97, 61)
	# far trees and the far bank, sunk in mist
	for tr in [[30, 13], [45, 9], [61, 12], [77, 8]]:
		var tx = int(tr[0])
		var th = int(tr[1])
		p.vline(tx, HORIZON - th - 2, th + 2, "#356668")
		p.set_px(tx - 1, HORIZON - th, "#356668")
		p.set_px(tx - 2, HORIZON - th - 1, "#356668")
		p.set_px(tx + 1, HORIZON - th + 3, "#356668")
		p.set_px(tx + 2, HORIZON - th + 2, "#356668")
	_ridge(p, 36, 1.5, HORIZON, "#2f5c5e", 0.4, 1.0)
	for y in range(28, HORIZON):
		for x in range(W):
			if float(_bayer(x, y)) < float(y - 27) * 1.3:
				var under = p.get_px(x, y)
				p.set_px(x, y, Pix.mix(str(under), "#8fc8b8", 0.4))
	# the water that mirrors the sky
	_fade(p, 0, W, HORIZON, 45, "#5aa59c", "#2f6a68", 3)
	p.hline(0, HORIZON, W, "#9ad6c8")
	for y in range(40, 45):
		for x in range(W):
			if _noise(int(x / 4.0), y, 62, 5) == 0:
				p.set_px(x, y, "#7fc4b6")
	for y in range(39, 45):
		p.hline(84 + (y % 2), y, 4, "#d8f0e0")
	p.rect(15, 41, 4, 1, "#5fb878")
	p.set_px(17, 40, "#f0a8c8")
	p.rect(57, 42, 3, 1, "#5fb878")
	# the mud bank
	_fade(p, 0, W, 45, H, "#55554c", "#34332f", 4)
	for x in range(W):
		p.set_px(x, 45 - _noise(int(x / 3.0), 45, 63, 2), "#73735f")
	_speckle(p, 47, H, "#2a2926", 19, 64)
	_speckle(p, 47, H, "#6a6a5a", 37, 65)
	p.ellipse(31.0, 56.5, 5.0, 1.0, "#3f7f7a")
	p.hline(28, 56, 5, "#7fc4b6")
	p.ellipse(72.0, 57.5, 4.0, 1.0, "#3f7f7a")
	p.hline(70, 57, 3, "#7fc4b6")
	# left: a dead tree hung with moss
	p.limb(6.0, 46.0, 9.0, 20.0, 3, "#2a2a36")
	p.limb(9.0, 21.0, 16.0, 10.0, 2, "#2a2a36")
	p.limb(8.0, 22.0, 2.0, 9.0, 2, "#2a2a36")
	p.limb(12.0, 16.0, 19.0, 17.0, 1, "#2a2a36")
	for y in range(20, 46):
		p.set_px(5 + int(floor(float(46 - y) * 0.115)), y, "#444456")
	for moss in [[15, 11, 6], [18, 18, 5], [3, 10, 7], [12, 14, 4], [1, 12, 4]]:
		for k in range(int(moss[2])):
			if k % 3 != 2:
				p.set_px(moss[0], int(moss[1]) + k, "#3fa89a")
	_shadow(p, 8, 22, 47)
	# right: reeds
	for rd in [[97, 30], [99, 24], [101, 28], [103, 22], [105, 27], [107, 25], [95, 34]]:
		var rx = int(rd[0])
		var ry = int(rd[1])
		p.vline(rx, ry, 47 - ry, "#3f8f80")
		p.rect(rx, ry - 4, 1, 4, "#6a4a3a")
		p.set_px(rx, ry - 4, "#8a6a55")
	p.set_px(94, 40, "#3f8f80")
	p.set_px(93, 39, "#3f8f80")
	p.set_px(108, 36, "#3f8f80")
	for fly in [[24, 30], [40, 22], [68, 27], [52, 14], [90, 32]]:
		p.set_px(fly[0], fly[1], "#e8ff7a")
		_glow(p, fly[0], fly[1], 2, "#e8ff7a", 0.5)
		p.set_px(fly[0], fly[1], "#f6ffb8")


## Stormspine Ridge: bare rock and snow under a storm.
static func _stormspine(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#232a3c", "#74849f", 6)
	# a bolt far off, and the light of it: a white core with a yellow edge, so it is a bolt and not a smudge
	_glow(p, 77, 12, 9, "#dfe6ff", 0.34)
	var bolt = [[80, 5], [79, 6], [79, 7], [78, 8], [77, 9], [76, 10], [77, 11], [78, 11], [79, 11], [78, 12], [77, 13], [76, 14], [75, 15], [76, 16], [77, 16], [76, 17], [75, 18], [74, 19], [74, 20], [73, 21]]
	for seg in bolt:
		p.set_px(int(seg[0]) + 1, seg[1], "#ffe838")
	for seg in bolt:
		p.set_px(seg[0], seg[1], "#ffffff")
	# the clouds
	for cl in [[12, 2, 15, 4], [41, 1, 19, 4], [73, 3, 17, 4], [101, 2, 13, 4]]:
		p.ellipse(float(cl[0]), float(cl[1]) + 1.5, float(cl[2]), float(cl[3]), "#4a546c")
		p.ellipse(float(cl[0]), float(cl[1]), float(cl[2]), float(cl[3]), "#2c3446")
	_fade(p, 0, W, 0, 3, "#1c2130", "#2c3446", 2)
	# far peaks with snow on them
	for pk in [[15, 17, 1.0, 5], [38, 21, 0.9, 4], [60, 15, 1.1, 6], [85, 20, 0.9, 4], [105, 16, 1.0, 5]]:
		_peak(p, int(pk[0]), int(pk[1]), HORIZON, float(pk[2]), "#8795b0", int(pk[3]), "#e8f4ff")
	_ridge(p, 36, 2.0, HORIZON, "#59657c", 3.3, 2.0, 2, "#6a7790")
	_ground(p, "#6a7488")
	for crack in [[20, 44, 6], [52, 42, 8], [78, 47, 7], [38, 55, 9], [88, 56, 6]]:
		p.hline(crack[0], crack[1], crack[2], "#4c5468")
		p.set_px(crack[0] - 1, crack[1] - 1, "#4c5468")
	for sn in [[30, 40, 9], [64, 39, 12], [92, 41, 7], [12, 50, 8], [50, 58, 16], [84, 57, 10], [100, 53, 9]]:
		p.hline(sn[0], sn[1], sn[2], "#dfeefa")
		p.hline(sn[0] + 1, int(sn[1]) + 1, int(sn[2]) - 2, "#b4c6dc")
	# left: a cairn, each stone lit on top and dark underneath, snow on the last
	for st in [[8.0, 45.0, 6.0, 2.2], [8.5, 40.5, 4.6, 2.0], [7.5, 36.5, 3.4, 1.7], [8.0, 33.0, 2.2, 1.4]]:
		p.ellipse(float(st[0]), float(st[1]) + 0.8, float(st[2]), float(st[3]), "#454d60")
		p.ellipse(float(st[0]), float(st[1]), float(st[2]), float(st[3]), "#687288")
		p.hline(int(st[0] - st[2]) + 1, int(st[1] - st[3]) + 1, int(st[2] * 2.0) - 3, "#9aa6bc")
	p.hline(6, 31, 4, "#eef8ff")
	p.hline(7, 32, 3, "#c8d8ea")
	_shadow(p, 13, 21, 47)
	_shadow(p, 10, 19, 46)
	# right: a pole of wind-torn flags
	for y in range(15, 47):
		p.set_px(102 + (1 if y > 34 else 0), y, "#51443c")
	var flags = ["#d84a5a", "#f0c040", "#4a9ae0", "#5fae4b", "#eef8ff"]
	for i in range(5):
		var fx = 98 - i * 4
		var fy = 17 + i * 2 + int(floor(float(i * i) / 5.0))
		p.rect(fx, fy, 3, 2, str(flags[i]))
		p.set_px(fx, fy + 2, str(flags[i]))
		p.set_px(fx + 3, fy - 1, "#51443c")
	_shadow(p, 104, W, 46)
	# sleet on the wind
	for y in range(4, 34):
		for x in range(W):
			if _noise(x, y, 71, 83) == 0:
				p.set_px(x, y, "#a8b8d0")
				p.set_px(x - 1, y + 1, "#8fa0ba")


## Titan's Rest: the ruins of something huge at the end of the day.
static func _titans_rest(p: Pix) -> void:
	_fade(p, 0, W, 0, 18, "#231e3e", "#7a5270", 4)
	_fade(p, 0, W, 18, HORIZON, "#7a5270", "#ecb362", 5)
	_speckle(p, 0, 12, "#d8d0f0", 61, 81)
	# far: a head sunk to its eyes, and a broken gate
	p.ellipse(31.0, 39.0, 11.0, 11.0, "#b48a72")
	p.ellipse(28.5, 36.0, 7.0, 6.0, "#c69c7e")
	p.rect(25, 34, 3, 2, "#9a7262")
	p.rect(33, 34, 3, 2, "#9a7262")
	p.hline(22, 31, 18, "#a47c68")
	_block(p, 68, 22, 3, 16, "#b48a72")
	_block(p, 82, 25, 3, 13, "#b48a72")
	p.rect(67, 20, 11, 2, "#b48a72")
	p.hline(67, 20, 11, "#c69c7e")
	p.set_px(78, 21, "#b48a72")
	p.set_px(79, 22, "#b48a72")
	_ridge(p, 37, 1.2, HORIZON, "#9a7262", 1.7, 1.6, 3)
	_ground(p, "#6a6480")
	for y in [43, 49, 55]:
		p.hline(0, y, W, "#544f6a")
	for x in range(0, W, 14):
		p.vline(x + 6, HORIZON + 1, 5, "#544f6a")
		p.vline(x, 44, 5, "#544f6a")
		p.vline(x + 9, 50, 5, "#544f6a")
		p.vline(x + 3, 56, 4, "#544f6a")
	for x in range(6, W, 8):
		if _noise(x, 46, 82, 3) != 0:
			p.hline(x, 46, 3, "#b89436")
	_speckle(p, HORIZON + 1, H, "#7f7998", 31, 83)
	_speckle(p, 44, H, "#4f8a6a", 67, 84)
	# left: a broken column and a piece of it
	_block(p, 2, 21, 10, 25, "#aaa2bc")
	for x in [4, 6, 8, 10]:
		p.vline(x, 22, 23, "#8a829e")
	p.rect(2, 19, 4, 2, "#aaa2bc")
	p.rect(8, 20, 2, 1, "#aaa2bc")
	p.rect(1, 44, 12, 2, "#beb6ce")
	p.hline(1, 46, 12, "#7a7290")
	p.ellipse(18.0, 45.0, 3.5, 2.0, "#aaa2bc")
	p.hline(16, 44, 3, "#c8c0d8")
	_shadow(p, 12, 16, 46)
	_shadow(p, 21, 26, 46)
	# right: a column that still stands, a fire on it
	_block(p, 98, 15, 8, 31, "#aaa2bc")
	for x in [100, 102, 104]:
		p.vline(x, 16, 29, "#8a829e")
	_block(p, 96, 13, 12, 2, "#beb6ce")
	p.rect(97, 44, 10, 2, "#beb6ce")
	p.hline(97, 46, 10, "#7a7290")
	p.rect(99, 11, 6, 2, "#c9a23a")
	p.hline(99, 11, 6, "#f0d070")
	_flame(p, 101, 10, "#ff9a3a", "#ffe08a")
	_flame(p, 103, 10, "#ffb347", "#fff0b0")
	_glow(p, 102, 8, 9, "#ffd24a", 0.45)
	for mote in [[20, 12], [44, 18], [58, 9], [72, 14], [88, 24], [14, 30], [50, 27], [92, 6]]:
		p.set_px(mote[0], mote[1], "#f0d070")


# --- beyond the road ----------------------------------------------------------

## The Spire: a platform high above the clouds, at night.
static func _spire(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#0c0a20", "#40307a", 6)
	_speckle(p, 0, 28, "#e8e4ff", 53, 91)
	_speckle(p, 0, 24, "#8f88d8", 37, 92)
	p.ellipse(31.0, 12.0, 8.0, 8.0, "#e8e4ff")
	p.ellipse(28.5, 9.5, 2.0, 1.5, "#cbc5f0")
	p.ellipse(34.0, 14.5, 2.5, 2.0, "#cbc5f0")
	p.set_px(30, 16, "#cbc5f0")
	_glow(p, 31, 12, 15, "#b8b0f0", 0.3)
	# other towers standing out of the cloud
	p.rect(64, 19, 3, 19, "#2a2252")
	p.set_px(65, 17, "#2a2252")
	p.set_px(65, 18, "#2a2252")
	p.vline(64, 19, 19, "#3d3470")
	p.set_px(65, 23, "#ffcf6a")
	p.rect(80, 25, 4, 13, "#2a2252")
	p.rect(81, 23, 2, 2, "#2a2252")
	p.vline(80, 25, 13, "#3d3470")
	_ridge(p, 33, 1.6, HORIZON, "#5d4ea0", 0.8, 1.2, 1, "#8273c8")
	_ridge(p, 36, 1.0, HORIZON, "#7f70c0", 2.9, 2.0, 1, "#a99ce6")
	# the rail round the platform
	p.hline(13, 34, 84, "#6a639a")
	p.hline(13, 35, 84, "#4a4474")
	for x in range(15, 97, 6):
		p.vline(x, 35, 3, "#5a548a")
	_ground(p, "#4c4670")
	for y in [44, 51]:
		p.hline(0, y, W, "#3a355a")
	for x in range(0, W, 16):
		p.vline(x + 7, HORIZON + 1, 6, "#3a355a")
		p.vline(x, 45, 6, "#3a355a")
		p.vline(x + 11, 52, 8, "#3a355a")
	# a ring of runes in the floor
	for i in range(120):
		var a = float(i) / 120.0 * TAU
		var rx = 55.0 + cos(a) * 44.0
		var ry = 49.5 + sin(a) * 6.5
		if i % 4 < 2:
			var under = p.get_px(int(round(rx)), int(round(ry)))
			if under != null:
				p.set_px(rx, ry, Pix.mix(str(under), "#7fe0ff", 0.6))
	# left: the tower's wall and a lit window
	_block(p, 0, 0, 13, 47, "#3a3462")
	for y in range(3, 46, 4):
		p.hline(1, y, 11, "#2d2850")
		p.set_px(3 + (y % 8), y - 2, "#2d2850")
	p.rect(4, 18, 5, 9, "#ffcf6a")
	p.set_px(4, 18, "#3a3462")
	p.set_px(8, 18, "#3a3462")
	p.vline(6, 19, 8, "#c89a3a")
	p.hline(4, 22, 5, "#c89a3a")
	_glow(p, 6, 22, 10, "#ffcf6a", 0.4)
	_shadow(p, 13, 20, 46)
	_shadow(p, 13, 17, 45)
	# right: a banner
	p.vline(103, 9, 38, "#8a84b0")
	p.set_px(103, 8, "#f0d070")
	p.rect(96, 11, 7, 14, "#d84aa8")
	p.vline(96, 11, 14, "#f070c4")
	p.hline(96, 11, 7, "#f070c4")
	p.rect(98, 15, 3, 3, "#ffd24a")
	p.set_px(99, 14, "#ffd24a")
	p.set_px(99, 25, "#d84aa8")
	p.set_px(96, 25, "#d84aa8")
	p.set_px(102, 25, "#d84aa8")
	p.set_px(96, 26, "#d84aa8")
	p.set_px(102, 26, "#d84aa8")
	_shadow(p, 104, W, 46)


## The hunt: a clearing among pines with the sun low.
static func _hunt(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#27365a", "#f2a65e", 6)
	p.ellipse(60.0, 35.0, 5.0, 5.0, "#ffe2a0")
	_glow(p, 60, 34, 14, "#ffd890", 0.4)
	# the far tree line against the light, a nearer one under it
	for x in range(W):
		var top = 27 + absi((x + 3) % 8 - 4) + _noise(int(x / 8.0), 0, 101, 3)
		p.rect(x, top, 1, HORIZON - top, "#b47c5c")
	for x in range(W):
		var top2 = 32 + absi((x + 1) % 6 - 3) + _noise(int((x + 1) / 6.0), 1, 102, 2)
		p.rect(x, top2, 1, HORIZON - top2, "#6c5648")
	_ground(p, "#5c6442")
	# the bare patch the fight is on
	for y in range(45, 57):
		for x in range(W):
			var edge = mini(y - 45, 56 - y)
			if edge >= 2 or _bayer(x, y) < 6 + edge * 4:
				p.set_px(x, y, "#84724c" if y < 51 else "#766542")
	_speckle(p, HORIZON + 1, H, "#c8703a", 31, 103)
	_speckle(p, HORIZON + 1, H, "#7a4a2a", 23, 104)
	_speckle(p, HORIZON + 1, 45, "#7f8a55", 9, 105)
	# pines at both sides
	for tree in [[6, 0, 46, 9], [17, 14, 43, 6], [103, 2, 46, 9], [92, 16, 43, 5]]:
		var tx = int(tree[0])
		var top3 = int(tree[1])
		var foot = int(tree[2])
		var reach = int(tree[3])
		p.rect(tx, foot - 6, 2, 6, "#3a2c22")
		var tiers = 4
		for t in range(tiers):
			var y0 = top3 + int(floor(float(t) * float(foot - 8 - top3) / float(tiers)))
			var y1 = top3 + int(floor(float(t + 1) * float(foot - 8 - top3) / float(tiers))) + 3
			for y in range(y0, y1):
				var half = int(floor(float(y - y0 + 1) * float(reach) * (0.5 + 0.5 * float(t + 1) / float(tiers)) / float(y1 - y0)))
				p.rect(tx - half, y, half + 1, 1, "#27483f")
				p.rect(tx + 1, y, half + 1, 1, "#1b352f")
				p.set_px(tx - half, y, "#356052")
		_shadow(p, tx + 2, mini(W, tx + 10), foot)
	# a target on the right pine, a fire in front of it
	p.rect(101, 26, 5, 5, "#f3ecd8")
	p.rect(102, 27, 3, 3, "#d64545")
	p.set_px(103, 28, "#f3ecd8")
	p.limb(93.0, 50.0, 100.0, 48.0, 2, "#4a3324")
	p.limb(93.0, 48.0, 100.0, 50.0, 2, "#5f4530")
	_flame(p, 96, 47)
	_flame(p, 98, 46, "#ff7a2a", "#ffd24a")
	p.set_px(97, 41, "#ffb347")
	p.set_px(95, 39, "#ff8a2a")
	_glow(p, 97, 46, 9, "#ff9a3a", 0.5)


## The rival: an arena, the stands dark, the sand lit.
static func _rival(p: Pix) -> void:
	_fade(p, 0, W, 0, HORIZON, "#1d1126", "#5c2536", 6)
	# the stands: three tiers of heads in the dark
	for tier in range(3):
		var ty = 15 + tier * 8
		p.rect(0, ty, W, 7, Pix.mix("#2c1728", "#4a2034", float(tier) / 2.0))
		p.hline(0, ty + 6, W, "#22121f")
		for x in range(1 + tier, W, 3):
			if _noise(x, tier, 111, 6) != 0:
				var c = "#6c3c4c" if _noise(x, tier, 112, 3) == 0 else "#57303f"
				p.rect(x, ty + 2 - _noise(x, tier, 113, 2), 2, 2, c)
	p.hline(0, 37, W, "#7a3a44")
	# the lights
	for y in range(0, HORIZON):
		for x in range(W):
			var a = absf(float(x) - (8.0 + float(y) * 1.25))
			var b = absf(float(x) - (101.0 - float(y) * 1.25))
			var wide = 2.0 + float(y) * 0.22
			if (a < wide or b < wide) and _bayer(x, y) < 7:
				var under = p.get_px(x, y)
				p.set_px(x, y, Pix.mix(str(under), "#ffe8b0", 0.22))
	# banners
	for bx in [22, 52, 82]:
		p.rect(bx, 0, 7, 12, "#c8324a")
		p.vline(bx, 0, 12, "#e2566a")
		p.vline(bx + 6, 0, 12, "#9a2238")
		p.hline(bx, 3, 7, "#ffc83d")
		p.rect(bx + 2, 6, 3, 3, "#ffc83d")
		p.set_px(bx + 3, 12, "#c8324a")
		p.set_px(bx, 12, "#c8324a")
		p.set_px(bx + 6, 12, "#9a2238")
	_ground(p, "#cba673")
	_speckle(p, HORIZON + 1, H, "#b08a58", 13, 114)
	_speckle(p, HORIZON + 1, H, "#e2c392", 29, 115)
	for i in range(160):
		var ang = float(i) / 160.0 * TAU
		p.set_px(55.0 + cos(ang) * 47.0, 49.5 + sin(ang) * 7.0, "#f3e4c0")
	p.rect(0, 58, W, 2, "#6a3a44")
	p.hline(0, 58, W, "#8a4c58")
	# a fire bowl on a pillar at each side
	for px0 in [1, 103]:
		_block(p, px0, 24, 6, 22, "#75616e")
		p.rect(px0 - 1, 44, 8, 2, "#8f7986")
		p.rect(px0 - 1, 22, 8, 2, "#c9a23a")
		p.hline(px0 - 1, 22, 8, "#f0d070")
		_flame(p, px0 + 2, 21)
		_flame(p, px0 + 4, 21, "#ffb347", "#fff0b0")
		_glow(p, px0 + 3, 19, 9, "#ffb347", 0.45)
		_shadow(p, px0 + 6, px0 + 11, 46)
