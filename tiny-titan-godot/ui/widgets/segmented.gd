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
		add_theme_stylebox_override("panel", PixBox.material("track", {"pad_h": 4, "pad_v": 4}))
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
		col = Pal.ACCENT2
	for i in range(_buttons.size()):
		var b = _buttons[i]
		var on = _options[i].value == value
		if on or _pills:
			# The chosen one a key in its colour; sub-tabs not chosen are tan keys.
			var face = col if on else "tan"
			var looks = PixBox.block_set(face, 10, 5, 1)
			for k in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(k, looks["normal"] if on else looks[k])
			Kit.key_words(b, face, 13)
		else:
			# Flat inside the dark track, as tall as the raised option; light tan words.
			var flat = StyleBoxEmpty.new()
			flat.content_margin_left = 10
			flat.content_margin_right = 10
			flat.content_margin_top = 5
			flat.content_margin_bottom = 5 + 2 * PixBox.S
			b.add_theme_stylebox_override("normal", flat)
			b.add_theme_stylebox_override("hover", flat)
			b.add_theme_stylebox_override("pressed", flat)
			var fg = Pal.CREAM.darkened(0.12)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(k, fg)
			b.add_theme_constant_override("outline_size", 0)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_font_override("font", Kit.font_bold())