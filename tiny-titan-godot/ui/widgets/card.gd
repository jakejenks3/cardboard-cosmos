class_name Card
extends PanelContainer
## A pixel-art panel with a vertical stack inside. Optionally tappable, and
## optionally colour-coded with `accent()` to show what it is about.

var box: VBoxContainer
var _tap = Callable()
var _press_at = null
var _squash_tw = null
var _down_msec: int = -100000
var _pad = 14
## null = the theme's panel colour / bright edge.
var _bg = null
var _border = null
var _hot = false


func _init(sep: int = 8, pad_px: int = 14) -> void:
	_pad = pad_px
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_restyle()
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	# When a screen first appears its cards rise in one after another.
	if not Kit.intro():
		return
	var p = get_parent()
	while p != null:
		if p is Card:
			return
		p = p.get_parent()
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tw = create_tween()
	tw.tween_interval(Kit.intro_delay())
	tw.tween_callback(_center_pivot)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _center_pivot() -> void:
	pivot_offset = size / 2.0


## Add a child to the card's stack. Returns the child.
func add(node: Node) -> Node:
	box.add_child(node)
	return node


## Recolour the card with explicit colours.
func tint(bg: Color, border = null) -> Card:
	_bg = bg
	if border != null:
		_border = border
	_restyle()
	return self


## Colour-code the card: its bright edge takes `color`. With `fill`, the whole
## card is a deep shade of that colour (the boss card is dark red).
func accent(color: Color, fill: bool = false) -> Card:
	_bg = Pal.deep(color) if fill else null
	_border = color
	_restyle()
	return self


func on_tap(cb: Callable) -> Card:
	_tap = cb
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_hover_on):
		mouse_entered.connect(_hover_on)
		mouse_exited.connect(_hover_off)
	return self


func _hover_on() -> void:
	_hot = true
	_restyle()


func _hover_off() -> void:
	_hot = false
	_restyle()
	if _press_at != null:
		_press_at = null
		_squash(false)


func _restyle() -> void:
	var bg = Pal.PANEL if _bg == null else _bg
	if _hot:
		bg = bg.lightened(0.07)
	add_theme_stylebox_override("panel", PixBox.panel(bg, _border, _pad))


## Pressed in a little while the mouse is down, popping back on release. A
## finger's tap presses and releases in one go (ui/touch_scroll.gd): the card
## still goes in first, then pops back.
func _squash(down: bool) -> void:
	pivot_offset = size / 2.0
	if _squash_tw != null and _squash_tw.is_valid():
		_squash_tw.kill()
	var tw = create_tween()
	_squash_tw = tw
	if down:
		_down_msec = Time.get_ticks_msec()
		tw.tween_property(self, "scale", Vector2(0.975, 0.975), 0.06)
	else:
		if Time.get_ticks_msec() - _down_msec < 50:
			tw.tween_property(self, "scale", Vector2(0.975, 0.975), 0.06)
		tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if not _tap.is_valid():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.global_position
			_squash(true)
			Sfx.click()
		elif _press_at != null:
			var moved = event.global_position.distance_to(_press_at)
			_press_at = null
			_squash(false)
			# A drag (scrolling) is not a tap.
			if moved < 12.0:
				accept_event()
				_tap.call()
