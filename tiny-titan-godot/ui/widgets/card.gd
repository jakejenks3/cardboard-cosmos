class_name Card
extends PanelContainer
## A rounded panel with a vertical stack inside. Optionally tappable.

var box: VBoxContainer
var _tap = Callable()
var _press_at = null
var _pad = 14
var _bg = Pal.PANEL
var _border = Pal.LINE


func _init(sep: int = 8, pad_px: int = 14) -> void:
	_pad = pad_px
	_restyle(false)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Add a child to the card's stack. Returns the child.
func add(node: Node) -> Node:
	box.add_child(node)
	return node


## Recolour the card (e.g. a highlighted or "done" state).
func tint(bg: Color, border = null) -> Card:
	_bg = bg
	if border != null:
		_border = border
	_restyle(false)
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
	_restyle(true)


func _hover_off() -> void:
	_restyle(false)
	_press_at = null


func _restyle(hot: bool) -> void:
	var bg = _bg.lightened(0.05) if hot else _bg
	add_theme_stylebox_override("panel", Kit.sbox(bg, 14, _border, 1, _pad, _pad))


func _gui_input(event: InputEvent) -> void:
	if not _tap.is_valid():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.global_position
		elif _press_at != null:
			var moved = event.global_position.distance_to(_press_at)
			_press_at = null
			# A drag (scrolling) is not a tap.
			if moved < 12.0:
				accept_event()
				_tap.call()
