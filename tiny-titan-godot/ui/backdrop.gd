class_name Backdrop
extends TextureRect
## The scene behind the app: a pixel-art sky over two mountain ridges, drawn in
## code and matched to the time of day (the same hours as the gym window).
## It fills the whole window, so a wide or maximised window shows a landscape
## on both sides of the app column instead of a flat colour.
##
## The sky is alive: a few clouds drift across by day, stars twinkle at night
## and now and then one falls. All of it moves in whole steps of the picture's
## own pixels (see SkyFx below), and stays faint enough to sit behind text.

## One art pixel is at least this many screen pixels; wide windows use bigger
## pixels so the picture never costs more than about 30,000 pixels to draw.
const MIN_PX = 4
const MAX_ART_W = 230
const BANDS = 9
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _hour = -1
var _pending = false
var _fx = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_queue)
	var t = Timer.new()
	t.wait_time = 60.0
	t.timeout.connect(_tick)
	add_child(t)
	t.start()
	_fx = SkyFx.new()
	add_child(_fx)
	_render()


## The hour that picks the sky. TINY_TITAN_HOUR (0-23) overrides the clock, for screenshots.
static func current_hour() -> int:
	var forced = OS.get_environment("TINY_TITAN_HOUR")
	if forced != "" and forced.is_valid_int():
		return clampi(forced.to_int(), 0, 23)
	return Time.get_datetime_dict_from_system().hour


func _tick() -> void:
	if current_hour() != _hour:
		_render()


func _queue() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	get_tree().create_timer(0.12).timeout.connect(_render)


## Colours for an hour of the day: night, dawn, day or dusk.
static func palette(hour: int) -> Dictionary:
	if hour >= 6 and hour <= 7:
		return {"top": Color("12233d"), "low": Color("d9895a"), "far": Color("3d4a66"), "near": Color("16202f"), "stars": 0.35, "orb": Color("ffd9a0"), "orb_at": Vector2(0.24, 0.62), "moon": false}
	if hour >= 8 and hour <= 17:
		return {"top": Color("12365a"), "low": Color("4f93c4"), "far": Color("2a587a"), "near": Color("14283a"), "stars": 0.0, "orb": Color("fff1b8"), "orb_at": Vector2(0.78, 0.2), "moon": false}
	if hour >= 18 and hour <= 19:
		return {"top": Color("13233f"), "low": Color("e07a4a"), "far": Color("3a4460"), "near": Color("141c2b"), "stars": 0.5, "orb": Color("ffc27a"), "orb_at": Vector2(0.74, 0.64), "moon": false}
	return {"top": Color("060a13"), "low": Color("17263f"), "far": Color("111c2e"), "near": Color("0b111b"), "stars": 1.0, "orb": Color("e8edf7"), "orb_at": Vector2(0.8, 0.16), "moon": true}


static func _ridge(x: int, scale_x: float, seed_shift: float) -> float:
	var fx = float(x) * scale_x
	return 0.5 * sin(fx * 0.045 + 1.3 + seed_shift) + 0.3 * sin(fx * 0.11 + 4.1 + seed_shift * 2.0) + 0.2 * sin(fx * 0.23 + 0.7 + seed_shift * 3.0)


func _render() -> void:
	_pending = false
	if not is_inside_tree() or size.x < 8.0 or size.y < 8.0:
		return
	var px = maxi(MIN_PX, int(ceil(size.x / float(MAX_ART_W))))
	var w = maxi(8, int(ceil(size.x / float(px))))
	var h = maxi(8, int(ceil(size.y / float(px))))
	_hour = current_hour()
	var pal = palette(_hour)
	var ground = Pal.BG
	# In a wide window the landscape fills the sides, with the horizon low. When the
	# app column covers the whole window only the top strip shows, so the whole
	# scene is squeezed into it: sky and sun or moon behind the screen title, the
	# ridges just below.
	var narrow = size.x <= 560.0
	var horizon = int(float(h) * 0.72)
	if narrow:
		horizon = mini(horizon, int(230.0 / float(px)))

	# Sky bands, dark at the top for longer so text over it stays readable.
	var band_rgb = []
	for i in range(BANDS + 1):
		var t = pow(float(i) / float(BANDS), 1.7)
		band_rgb.append(pal.top.lerp(pal.low, t))

	# Ridge lines, one height per column. The art keeps its shape whatever the pixel size.
	var far_y = PackedInt32Array()
	var near_y = PackedInt32Array()
	far_y.resize(w)
	near_y.resize(w)
	var sx = 230.0 / float(maxi(w, 60))
	for x in range(w):
		if narrow:
			# No ridges behind the cards: the sky simply runs down into the background.
			far_y[x] = horizon
			near_y[x] = horizon
		else:
			far_y[x] = horizon - int(float(h) * 0.07) - int(round(_ridge(x, sx * 0.9, 0.0) * float(h) * 0.05))
			near_y[x] = horizon + int(float(h) * 0.05) - int(round(_ridge(x, sx * 1.7, 2.4) * float(h) * 0.035))

	var orb = Vector2(pal.orb_at.x * float(w), pal.orb_at.y * float(horizon))
	if narrow:
		# Mid-way across: clear of the screen title on the left and of whatever sits on
		# the right of a header (the settings button, the Armory's counts).
		orb = Vector2(float(w) * 0.52, maxf(float(horizon) * 0.2, 6.0))
	var orb_r = clampf(float(w) * 0.035, 3.0, 7.0)
	var bytes = PackedByteArray()
	bytes.resize(w * h * 4)
	var i = 0
	for y in range(h):
		var f = clampf(float(y) / float(maxi(horizon, 1)), 0.0, 1.0) * float(BANDS)
		var band = mini(int(f), BANDS - 1)
		var frac = f - float(band)
		for x in range(w):
			var c: Color
			if y >= near_y[x]:
				# Foreground ridge, fading into the app's background colour.
				var g = clampf(float(y - near_y[x]) / float(maxi(h - near_y[x], 1)), 0.0, 1.0)
				c = ground if narrow else pal.near.lerp(ground, clampf(g * 2.2, 0.0, 1.0))
			elif y >= far_y[x]:
				c = pal.far
			else:
				var pick = band
				if frac * 16.0 > float(BAYER[(y % 4) * 4 + (x % 4)]):
					pick = band + 1
				c = band_rgb[pick]
				var d = Vector2(float(x), float(y)).distance_to(orb)
				if d <= orb_r:
					# A crescent for the moon, a full disc for the sun.
					if not pal.moon or Vector2(float(x), float(y)).distance_to(orb + Vector2(-orb_r * 0.45, -orb_r * 0.25)) > orb_r * 0.95:
						c = pal.orb
						# the lower right of the disc is a shade deeper
						if not pal.moon and (float(x) - orb.x) + (float(y) - orb.y) > orb_r * 0.75:
							c = pal.orb.darkened(0.12)
				elif d <= orb_r + 2.5:
					# A soft ring round it: every other pixel, fading out.
					if (x + y) % 2 == 0:
						c = c.lerp(pal.orb, 0.34 if d <= orb_r + 1.5 else 0.16)
				elif not pal.moon and d <= orb_r + 5.5 and d >= orb_r + 3.5 and (absi(x - int(round(orb.x))) <= 0 or absi(y - int(round(orb.y))) <= 0 or absi(absi(x - int(round(orb.x))) - absi(y - int(round(orb.y)))) <= 0):
					# Eight short rays.
					c = c.lerp(pal.orb, 0.3)
				elif pal.stars > 0.0 and y < horizon - 6:
					var hsh = (x * 73856093) ^ (y * 19349663)
					if posmod(hsh, 173) == 0:
						var bright = 0.45 + 0.55 * float(posmod(hsh >> 8, 100)) / 100.0
						c = c.lerp(Color("eef3ff"), bright * pal.stars * (1.0 - float(y) / float(horizon)))
			bytes[i] = int(c.r * 255.0)
			bytes[i + 1] = int(c.g * 255.0)
			bytes[i + 2] = int(c.b * 255.0)
			bytes[i + 3] = 255
			i += 4
	texture = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes))
	if _fx != null:
		_fx.setup(px, w, horizon, pal, narrow)


## What moves in the sky. Drawn over the still picture, on its pixel grid.
class SkyFx:
	extends Control

	var _px: int = 4
	var _w: int = 100
	var _horizon: int = 50
	var _pal: Dictionary = {}
	var _narrow: bool = true
	var _t: float = 0.0
	var _step: int = -1
	var _clouds: Array = []
	var _stars: Array = []
	var _fall_at: float = 9.0
	var _fall = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func setup(px: int, w: int, horizon: int, pal: Dictionary, narrow: bool) -> void:
		_px = px
		_w = w
		_horizon = horizon
		_pal = pal
		_narrow = narrow
		var rng = RandomNumberGenerator.new()
		rng.seed = 4242
		_clouds = []
		var n_clouds = 0 if float(pal.stars) >= 1.0 else (3 if narrow else 6)
		for i in range(n_clouds):
			_clouds.append({"x": rng.randf() * float(w + 30), "y": 3 + rng.randi_range(0, maxi(2, int(horizon * 0.45))), "w": rng.randi_range(9, 16), "speed": rng.randf_range(0.5, 1.4)})
		_stars = []
		if float(pal.stars) > 0.0:
			for i in range(10 if narrow else 22):
				_stars.append({"x": rng.randi_range(1, maxi(2, w - 2)), "y": rng.randi_range(1, maxi(2, horizon - 8)), "phase": rng.randf() * TAU, "speed": rng.randf_range(0.8, 2.2)})
		queue_redraw()

	func _process(delta: float) -> void:
		if _pal.is_empty() or not is_visible_in_tree() or TouchScroll.scrolling:
			return
		_t += delta
		if _fall == null and float(_pal.stars) >= 1.0:
			_fall_at -= delta
			if _fall_at <= 0.0:
				_fall_at = 14.0 + fmod(_t * 7.0, 20.0)
				_fall = {"x": float(_w) * (0.2 + fmod(_t, 0.6)), "y": 2.0, "age": 0.0}
		if _fall != null:
			_fall.age += delta
			_fall.x += delta * 34.0
			_fall.y += delta * 16.0
			if _fall.age > 0.9:
				_fall = null
		# Eight steps a second are enough: nothing here moves faster than a pixel a step.
		var step = int(_t * 8.0)
		if step != _step:
			_step = step
			queue_redraw()

	func _cell(x: int, y: int, cw: int, ch: int, c: Color) -> void:
		draw_rect(Rect2(x * _px, y * _px, cw * _px, ch * _px), c)

	func _draw() -> void:
		if _pal.is_empty():
			return
		# clouds: a low, wide shape a little lighter than the sky behind it
		var tint: Color = _pal.low.lerp(Color.WHITE, 0.5)
		for c in _clouds:
			var span = float(_w + 40)
			var x = int(fposmod(float(c.x) + _t * float(c.speed), span)) - 20
			var y = int(c.y)
			var cw = int(c.w)
			var a = 0.16 if _narrow else 0.3
			_cell(x + 2, y, cw - 5, 1, Pal.with_alpha(tint, a))
			_cell(x + 1, y + 1, cw - 2, 1, Pal.with_alpha(tint, a))
			_cell(x, y + 2, cw, 1, Pal.with_alpha(tint, a * 0.8))
		# stars that brighten and fade
		for s in _stars:
			var k = 0.5 + 0.5 * sin(_t * float(s.speed) + float(s.phase))
			if k > 0.55:
				_cell(int(s.x), int(s.y), 1, 1, Color(0.93, 0.95, 1.0, (k - 0.55) * 1.6 * float(_pal.stars)))
		# a falling star: a bright head and a tail that thins out
		if _fall != null:
			var fa = clampf(1.0 - float(_fall.age) / 0.9, 0.0, 1.0)
			for i in range(5):
				_cell(int(float(_fall.x) - float(i) * 2.0), int(float(_fall.y) - float(i)), 1, 1, Color(1.0, 1.0, 0.92, fa * (1.0 - float(i) * 0.2)))
