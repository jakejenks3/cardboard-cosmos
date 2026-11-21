class_name Stage
extends Control
## The little stage the hero stands on in the Armory (and wherever a figure is
## shown on its own): a soft spotlight, a floor with the figure's shadow, and a
## few sparkles that come and go. Drawn in chunky pixels on the same grid as
## the art in front of it (`px` screen pixels per art pixel).
##
##   var st = Stage.new()
##   st.setup(Pal.tab("armory"), 4)

## Screen pixels per art pixel.
var px: int = 4
var _glow: Color = Color.WHITE
## The colour of the floor (null = the panel colour, tinted by the glow).
var floor_color = null
var _t: float = 0.0
var _tick: int = 0
var _stars: Array = []
## Height of the floor strip, in art pixels.
var floor_px: int = 6
## Width of the figure's shadow, in art pixels (0 = none).
var shadow_px: int = 22


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func setup(glow: Color, art_px: int = 4) -> void:
	_glow = glow
	px = maxi(1, art_px)
	queue_redraw()


func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 7411
	for i in range(9):
		_stars.append({"x": rng.randf(), "y": rng.randf() * 0.7, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.7, 1.6), "big": i % 3 == 0})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	# Ten redraws a second is plenty for a twinkle.
	var tick = int(_t * 10.0)
	if tick != _tick:
		_tick = tick
		queue_redraw()


func _cell(cx: int, cy: int, w: int, h: int, c: Color) -> void:
	draw_rect(Rect2(cx * px, cy * px, w * px, h * px), c)


func _draw() -> void:
	var cols = int(ceil(size.x / float(px)))
	var rows = int(ceil(size.y / float(px)))
	if cols < 4 or rows < 4:
		return
	var mid = cols / 2.0
	var floor_y = rows - floor_px
	# --- the spotlight: a few stacked ovals, brightest in the middle ---------------
	var steps = [[0.50, 0.05], [0.40, 0.06], [0.30, 0.07], [0.20, 0.08]]
	for st in steps:
		var rx = float(cols) * float(st[0])
		var ry = float(floor_y) * (0.55 + float(st[0]))
		var cy = float(floor_y) * 0.62
		var col = Pal.with_alpha(_glow, float(st[1]))
		for y in range(floor_y):
			var dy = (float(y) + 0.5 - cy) / ry
			if absf(dy) >= 1.0:
				continue
			var half = rx * sqrt(1.0 - dy * dy)
			var x0 = int(round(mid - half))
			var x1 = int(round(mid + half))
			if x1 > x0:
				_cell(x0, y, x1 - x0, 1, col)
	# --- sparkles --------------------------------------------------------------------
	for s in _stars:
		var a = 0.5 + 0.5 * sin(_t * float(s.speed) + float(s.phase))
		if a < 0.35:
			continue
		var sx = int(float(s.x) * float(cols - 2)) + 1
		var sy = int(float(s.y) * float(floor_y - 2)) + 1
		var c = Pal.with_alpha(_glow.lightened(0.5), (a - 0.35) * 0.9)
		_cell(sx, sy, 1, 1, c)
		if s.big and a > 0.75:
			var c2 = Pal.with_alpha(_glow.lightened(0.5), (a - 0.75) * 1.6)
			_cell(sx - 1, sy, 1, 1, c2)
			_cell(sx + 1, sy, 1, 1, c2)
			_cell(sx, sy - 1, 1, 1, c2)
			_cell(sx, sy + 1, 1, 1, c2)
	# --- the floor: a lit top edge, two tones, a dark front lip ----------------------
	var base: Color = floor_color if floor_color is Color else Pal.PANEL.lerp(_glow, 0.12)
	_cell(0, floor_y, cols, floor_px, base.darkened(0.25))
	_cell(0, floor_y, cols, 1, base.lightened(0.18))
	_cell(0, floor_y + 1, cols, 1, base)
	# Floorboard seams, every eighth art pixel, offset on the second row.
	var seam = base.darkened(0.42)
	for x in range(0, cols, 8):
		_cell(x + 3, floor_y + 2, 1, floor_px - 2, seam)
	_cell(0, rows - 1, cols, 1, Pal.OUTLINE)
	# --- the figure's shadow ----------------------------------------------------------
	if shadow_px > 0:
		var half_w = shadow_px / 2.0
		var sh = Pal.with_alpha(Pal.OUTLINE, 0.5)
		_cell(int(round(mid - half_w)) + 1, floor_y + 1, shadow_px - 2, 1, sh)
		_cell(int(round(mid - half_w)), floor_y + 2, shadow_px, 1, sh)
		_cell(int(round(mid - half_w)) + 2, floor_y + 3, shadow_px - 4, 1, sh)
