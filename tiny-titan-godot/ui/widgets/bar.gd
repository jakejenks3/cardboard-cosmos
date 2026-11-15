class_name Bar
extends Control
## A chunky pixel progress bar. `value` is 0..1. It fills from empty when a
## screen first appears, and animates whenever the value changes.

var value: float = 0.0
var color: Color = Pal.ACCENT
var _shown: float = 0.0
var _tween = null


func _init(v: float = 0.0, c = null, h: int = 10) -> void:
	value = clampf(v, 0.0, 1.0)
	_shown = value
	color = Pal.ACCENT if c == null else c
	# Room for the outline on both sides of the fill.
	custom_minimum_size = Vector2(24, maxi(h + 2, 10))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if Kit.intro() and value > 0.0:
		var target = value
		_shown = 0.0
		_tween = create_tween()
		_tween.tween_interval(Kit.intro_delay() + 0.08)
		_tween.tween_method(_set_shown, 0.0, target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
	var s = float(PixBox.S)
	var w = floor(size.x / s) * s
	var h = floor(size.y / s) * s
	# Outline with the corners nipped off, then the sunken track.
	draw_rect(Rect2(s, 0, w - 2.0 * s, h), Pal.OUTLINE)
	draw_rect(Rect2(0, s, w, h - 2.0 * s), Pal.OUTLINE)
	var inner = Rect2(s, s, w - 2.0 * s, h - 2.0 * s)
	draw_rect(inner, Pal.WELL)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, s)), Pal.WELL.darkened(0.35))
	if _shown <= 0.001:
		return
	var fw = clampf(floor(inner.size.x * _shown / s) * s, s, inner.size.x)
	draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), color)
	if inner.size.y >= 3.0 * s:
		draw_rect(Rect2(inner.position, Vector2(fw, s)), color.lightened(0.38))
		draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - s), Vector2(fw, s)), color.darkened(0.22))
	# A bright leading edge, like a gauge needle.
	if fw < inner.size.x and fw > 2.0 * s:
		draw_rect(Rect2(inner.position + Vector2(fw - s, 0), Vector2(s, inner.size.y)), color.lightened(0.5))
