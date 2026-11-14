class_name Bar
extends Control
## A rounded progress bar. `value` is 0..1.

var value: float = 0.0
var color: Color = Pal.ACCENT
var _shown: float = 0.0
var _tween = null
var _track: StyleBoxFlat
var _fill: StyleBoxFlat
var _shine: StyleBoxFlat


func _init(v: float = 0.0, c = null, h: int = 10) -> void:
	value = clampf(v, 0.0, 1.0)
	_shown = value
	if c != null:
		color = c
	custom_minimum_size = Vector2(24, h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track = StyleBoxFlat.new()
	_track.bg_color = Pal.WELL
	_track.border_color = Pal.WELL_LINE
	_track.set_border_width_all(1)
	_track.set_corner_radius_all(99)
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(99)
	_shine = StyleBoxFlat.new()
	_shine.bg_color = Color(1, 1, 1, 0.22)
	_shine.set_corner_radius_all(99)


## Change the value; animates by default.
func set_value(v: float, animate: bool = true, dur: float = 0.6) -> void:
	value = clampf(v, 0.0, 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_shown, _shown, value, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_shown(value)


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


## What is drawn right now (differs from `value` while animating).
func shown() -> float:
	return _shown


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	draw_style_box(_track, r)
	if _shown <= 0.001:
		return
	var inner = r.grow(-1.0)
	var w = maxf(inner.size.y, inner.size.x * _shown)
	w = minf(w, inner.size.x)
	_fill.bg_color = color
	draw_style_box(_fill, Rect2(inner.position, Vector2(w, inner.size.y)))
	if inner.size.y >= 6.0:
		draw_style_box(_shine, Rect2(inner.position + Vector2(2, 1), Vector2(maxf(0.0, w - 4.0), inner.size.y * 0.42)))
