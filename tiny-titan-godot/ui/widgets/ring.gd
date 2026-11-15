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


func _draw() -> void:
	var c = size / 2.0
	var r = _px / 2.0 - _thick / 2.0 - 1.0
	draw_arc(c, r, 0.0, TAU, 48, Pal.OUTLINE, _thick + 4.0, false)
	draw_arc(c, r, 0.0, TAU, 48, Pal.WELL, _thick, false)
	if _shown > 0.001:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * _shown, 48, color, _thick, false)
