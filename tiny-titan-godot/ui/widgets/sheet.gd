class_name Sheet
extends Control
## A modal sheet that slides up from the bottom of the app column.
## Usage: var s = Kit.sheet("Title"); s.box.add_child(...); s.open()

signal closed

var box: VBoxContainer
var _panel: PanelContainer
var _backdrop: ColorRect
var _scroll: ScrollContainer
var _title = ""
var _closing = false


func setup(title: String = "") -> void:
	_title = title
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.05, 0.74)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_backdrop_input)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	var sb = Kit.sbox(Pal.BG2, 20, Pal.LINE, 1, 16, 14)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_bottom = 0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var outer = Kit.vbox(10)
	_panel.add_child(outer)
	var head = Kit.hbox(8)
	var t = Kit.clip(title, 18, null, true)
	head.add_child(t)
	head.add_child(Kit.icon_button("close", close, "Close", 34))
	outer.add_child(head)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	box = Kit.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(Kit.pad(box, 0, 0, 6, 8))
	_scroll.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func open() -> void:
	if Kit.overlay_root == null:
		push_warning("Sheet.open(): Kit.overlay_root is not set")
		return
	Kit.overlay_root.add_child(self)
	_layout()
	resized.connect(_layout)
	box.minimum_size_changed.connect(_layout)
	_backdrop.modulate.a = 0.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.18)
	var target_y = _panel.position.y
	_panel.position.y = size.y
	tw.tween_property(_panel, "position:y", target_y, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.15)
	tw.tween_property(_panel, "position:y", size.y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _layout() -> void:
	if _closing or not is_inside_tree():
		return
	# As tall as the content needs, but never more than 88% of the screen.
	var max_h = size.y * 0.88
	var chrome = 14 + 14 + 34 + 10 + 8
	var want = box.get_combined_minimum_size().y + chrome + 8
	var h = clampf(want, 120.0, max_h)
	_panel.size = Vector2(size.x, h)
	_panel.position = Vector2(0, size.y - h)


func _backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
