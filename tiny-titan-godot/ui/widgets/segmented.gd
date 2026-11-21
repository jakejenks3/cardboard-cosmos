class_name Segmented
extends PanelContainer
## One-of-many switch (also used as sub-tabs). Emits `selected(value)`.
## As a switch it is a sunken track with the chosen option raised; as sub-tabs
## it is a row of raised buttons with the chosen one in the tab's colour.

signal selected(value)

var value = null
var _options: Array = []
var _color = null
var _pills = false
var _row: HBoxContainer
var _buttons: Array = []


## options = [{"value": v, "label": "Text"}]. `pills` = sub-tab style.
func setup(options: Array, current, color = null, pills: bool = false) -> void:
	_options = options
	value = current
	_color = color
	_pills = pills
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pills:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		add_theme_stylebox_override("panel", PixBox.well(4, 4, null))
	if _row != null:
		remove_child(_row)
		_row.queue_free()
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6 if pills else 2)
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
		Kit.juice(b)
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
	var col = _color
	if col == null:
		col = Pal.tab_accent() if _pills else Pal.ACCENT
	for i in range(_buttons.size()):
		var b = _buttons[i]
		var on = _options[i].value == value
		var fg = Pal.INK if on else Pal.TEXT
		if on:
			var looks = PixBox.button_set(col, col.darkened(0.42), 10, 5, 1, null)
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, looks["normal"])
		elif _pills:
			var looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 10, 5, 1, Pal.LINE)
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, looks[k])
		else:
			# Flat inside the track, with the same height as the raised option.
			var flat = StyleBoxEmpty.new()
			flat.content_margin_left = 10
			flat.content_margin_right = 10
			flat.content_margin_top = 5
			flat.content_margin_bottom = 5 + 2 * PixBox.S
			b.add_theme_stylebox_override("normal", flat)
			b.add_theme_stylebox_override("hover", flat)
			b.add_theme_stylebox_override("pressed", flat)
			fg = Pal.MUTED
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, fg)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_font_override("font", Kit.font_bold())
