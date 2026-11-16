class_name PixSwitch
extends Button
## An on / off switch: a sunken track with a raised knob, green with a tick
## when on. Make one with `Kit.switch(on, on_change, tip)`.

var on = false


func setup(value: bool, tip: String) -> void:
	on = value
	tooltip_text = tip
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(72, 38)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var none = StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(k, none)


func _draw() -> void:
	var track = Pal.deep(Pal.GOOD) if on else Pal.WELL
	draw_style_box(PixBox.make(track, {"lip": 0, "inset": true, "pad_h": 0, "pad_v": 0}), Rect2(Vector2.ZERO, size))
	var kw = 34.0
	var kr = Rect2(size.x - kw - 4.0 if on else 4.0, 4.0, kw, size.y - 8.0)
	var face = Pal.GOOD if on else Pal.PANEL2
	draw_style_box(PixBox.make(face, {"lip": 1, "lip_color": face.darkened(0.45), "pad_h": 0, "pad_v": 0}), kr)
	if on:
		var ic = Icons.tex("check")
		draw_texture_rect(ic, Rect2(kr.position + Vector2((kw - 16.0) / 2.0, (kr.size.y - 22.0) / 2.0), Vector2(16, 16)), false)
