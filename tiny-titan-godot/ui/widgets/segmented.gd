class_name Segmented
extends PanelContainer
## One-of-many switch (also used as sub-tabs). Emits `selected(value)`.

signal selected(value)

var value = null
var _options: Array = []
var _color = null
var _pills = false
var _row: HBoxContainer
var _buttons: Array = []


## options = [{"value": v, "label": "Text"}]. `pills` = looser sub-tab style.
func setup(options: Array, current, color = null, pills: bool = false) -> void:
	_options = options
	value = current
	_color = color
	_pills = pills
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pills:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		add_theme_stylebox_override("panel", Kit.sbox(Pal.WELL, 12, Pal.LINE, 1, 3, 3))
	if _row != null:
		remove_child(_row)
		_row.queue_free()
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6 if pills else 3)
	add_child(_row)
	_buttons = []
	for o in options:
		var b = Button.new()
		b.text = str(o.label)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(_pick.bind(o.value))
		_row.add_child(b)
		_buttons.append(b)
	_restyle()


## Change the selection without emitting.
func set_value(v) -> void:
	value = v
	_restyle()


func _pick(v) -> void:
	if v == value:
		return
	value = v
	_restyle()
	selected.emit(v)


func _restyle() -> void:
	var col = Pal.ACCENT if _color == null else _color
	for i in range(_buttons.size()):
		var b = _buttons[i]
		var on = _options[i].value == value
		var radius = 99 if _pills else 9
		var normal
		var hover
		var fg
		if on:
			normal = Kit.sbox(col, radius, col, 1, 10, 7)
			hover = normal
			fg = Pal.INK
		elif _pills:
			normal = Kit.sbox(Pal.PANEL, radius, Pal.LINE, 1, 10, 7)
			hover = Kit.sbox(Pal.PANEL2, radius, Pal.LINE, 1, 10, 7)
			fg = Pal.MUTED
		else:
			normal = Kit.sbox(Color(0, 0, 0, 0), radius, Color(0, 0, 0, 0), 1, 10, 7)
			hover = Kit.sbox(Pal.with_alpha(Pal.PANEL2, 0.7), radius, Color(0, 0, 0, 0), 1, 10, 7)
			fg = Pal.MUTED
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, fg)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_font_override("font", Kit.font_bold())
