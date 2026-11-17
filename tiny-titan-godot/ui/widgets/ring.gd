class_name Ring
extends Control
## A progress ring with something in the middle (an icon): shows "how close"
## at a glance, without a sentence.

var value: float = 0.0
var color: Color = Pal.ACCENT
var _shown: float = 0.0
var _px: float = 56.0
var _thick: float = 6.0
var _center: Control = null


## `center` is any Control (usually Icons.rect) placed in the middle.
func setup(v: float, c: Color, px: float = 56.0, center: Control = null) -> Ring:
	value = clampf(v, 0.0, 1.0)
	color = c
	_px = px
	_thick = maxf(4.0, round(px / 9.0))
	_shown = value
	custom_minimum_size = Vector2(px, px)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center != null:
		_center = center
		add_child(center)
		resized.connect(_place_center)
		_place_center()
	return self


func _place_center() -> void:
	if _center == null:
		return
	var ms = _center.custom_minimum_size
	_center.size = ms
	_center.position = ((size if size.x > 0.0 else Vector2(_px, _px)) - ms) / 2.0


func _ready() -> void:
	if Kit.intro() and value > 0.0:
		_shown = 0.0
		var tw = create_tween()
		tw.tween_interval(Kit.intro_delay() + 0.08)
		tw.tween_method(_set_shown, 0.0, value, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


## The ring is built from the same chunky pixels as the boxes: an outlined
## band, filled clockwise from the top as far as the value goes, lit along its
## outer edge.
func _draw() -> void:
	var s = float(PixBox.S)
	var n = int(floor(_px / s))
	var mid = Vector2(n, n) / 2.0
	var r_out = float(n) / 2.0 - 1.0
	var r_in = r_out - maxf(2.0, round(_thick / s))
	var origin = ((size - Vector2(n, n) * s) / 2.0).floor()
	for cy in range(n):
		var run_from = -1
		var run_col = Color(0, 0, 0, 0)
		for cx in range(n + 1):
			var col = Color(0, 0, 0, 0)
			if cx < n:
				var p = Vector2(float(cx) + 0.5, float(cy) + 0.5) - mid
				var d = p.length()
				if d <= r_out + 1.0 and d >= r_in - 1.0:
					if d > r_out or d < r_in:
						col = Pal.OUTLINE
					else:
						var turn = fposmod(atan2(p.y, p.x) + PI / 2.0, TAU) / TAU
						if _shown > 0.001 and (turn <= _shown or _shown >= 0.999):
							col = color.lightened(0.3) if d > r_out - 1.0 else (color.darkened(0.18) if d < r_in + 1.0 else color)
						else:
							col = Pal.WELL.darkened(0.3) if d > r_out - 1.0 else Pal.WELL
			# Pixels of one colour in a row are drawn as one rectangle.
			if col != run_col:
				if run_from >= 0 and run_col.a > 0.0:
					draw_rect(Rect2(origin + Vector2(run_from, cy) * s, Vector2(float(cx - run_from) * s, s)), run_col)
				run_from = cx
				run_col = col
