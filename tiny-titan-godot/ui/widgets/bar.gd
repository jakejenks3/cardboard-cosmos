class_name Bar
extends Control
## A chunky pixel progress bar. `value` is 0..1. It fills from empty when a
## screen first appears, and animates whenever the value changes.

var value: float = 0.0
var color: Color = Pal.ACCENT
## 0..1 more drawn faded after the fill (today's plan on top of what is done).
var extra: float = 0.0
## A target line across the bar at 0..1 (-1 = none).
var mark: float = -1.0
var _shown: float = 0.0
var _tween = null
## Every few seconds a glint runs along the filled part (set by Kit.bar on thick bars).
var glint: bool = false
var _glint_wait: float = 2.0
var _glint_age: float = -1.0
const GLINT_EVERY = 4.2
const GLINT_TIME = 0.5


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
	# Only a bar with a glint has anything to do between redraws.
	set_process(glint)
	if Kit.intro() and value > 0.0:
		var target = value
		_shown = 0.0
		_tween = create_tween()
		_tween.tween_interval(Kit.intro_delay() + 0.08)
		_tween.tween_method(_set_shown, 0.0, target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not glint or not is_visible_in_tree() or _shown < 0.08 or TouchScroll.scrolling:
		return
	if _glint_age < 0.0:
		_glint_wait -= delta
		if _glint_wait <= 0.0:
			_glint_wait = GLINT_EVERY
			_glint_age = 0.0
		return
	_glint_age += delta
	if _glint_age >= GLINT_TIME:
		_glint_age = -1.0
	queue_redraw()


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
	var fw = 0.0
	if _shown > 0.001:
		fw = clampf(floor(inner.size.x * _shown / s) * s, s, inner.size.x)
		draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), color)
		if inner.size.y >= 3.0 * s:
			draw_rect(Rect2(inner.position, Vector2(fw, s)), color.lightened(0.38))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - s), Vector2(fw, s)), color.darkened(0.22))
	if extra > 0.001 and fw < inner.size.x:
		# What today's plan adds, faded, after what is done.
		var ew = minf(floor(inner.size.x * clampf(extra, 0.0, 1.0) / s) * s, inner.size.x - fw)
		if ew > 0.0:
			draw_rect(Rect2(inner.position + Vector2(fw, 0), Vector2(ew, inner.size.y)), Pal.with_alpha(color, 0.42))
	if mark >= 0.0:
		var mx = clampf(floor(inner.size.x * mark / s) * s, 0.0, inner.size.x - s)
		draw_rect(Rect2(inner.position.x + mx, 0, s, h), Pal.TEXT)
	if fw <= 0.0:
		return
	# A bright leading edge, like a gauge needle.
	if fw < inner.size.x and fw > 2.0 * s:
		draw_rect(Rect2(inner.position + Vector2(fw - s, 0), Vector2(s, inner.size.y)), color.lightened(0.5))
	if _glint_age >= 0.0:
		# A slanted glint crossing the filled part.
		var gw = s * 3.0
		var gx = floor((-gw + (fw + gw) * (_glint_age / GLINT_TIME)) / s) * s
		var row = 0.0
		while row < inner.size.y:
			var x0 = clampf(gx + (inner.size.y - row), 0.0, fw)
			var x1 = clampf(gx + (inner.size.y - row) + gw, 0.0, fw)
			if x1 > x0:
				draw_rect(Rect2(inner.position + Vector2(x0, row), Vector2(x1 - x0, s)), Color(1, 1, 1, 0.38))
			row += s
