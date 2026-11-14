class_name Backdrop
extends TextureRect
## The scene behind the app: a pixel-art sky over two mountain ridges, drawn in
## code and matched to the time of day (the same hours as the gym window).
## It fills the whole window, so a wide or maximised window shows a landscape
## on both sides of the app column instead of a flat colour.

## One art pixel is at least this many screen pixels; wide windows use bigger
## pixels so the picture never costs more than about 30,000 pixels to draw.
const MIN_PX = 4
const MAX_ART_W = 230
const BANDS = 9
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _hour = -1
var _pending = false


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
		horizon = mini(horizon, int(150.0 / float(px)))

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
				c = pal.near.lerp(ground, clampf(g * 2.2, 0.0, 1.0))
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
