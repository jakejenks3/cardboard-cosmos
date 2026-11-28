class_name Card
extends PanelContainer
## A pixel-art panel with a vertical stack inside. Optionally tappable, and
## optionally colour-coded with `accent()` to show what it is about.
##
## Two more shapes (2026-11-24, the Hero tab's clean-up):
##   - `with_head(head)`: a SECTION. The head (a coloured band, Kit.section)
##     sits inside the frame at the top and `add()` fills the body under it.
##   - `flat(stripe, tint)`: a ROW inside a section. No raised frame: a flat
##     fill a little darker than the panel (Pal.slot) with a stripe down its
##     left edge, so rows never look like boxes inside boxes.

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
## From the card's edge to just inside its ring (screen px): where a head band starts.
const FRAME = 4
## A flat row's stripe, down its left edge (screen px).
const STRIPE = 4
var _flat = false
## A section (Kit.section): its frame follows Kit.look, in `_section_color`.
var _section = false
var _section_color = Color()
var _stripe = Color()
var _tint = null
var _tint_amount = 0.16


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


## A flat row (see the top): a stripe of `stripe` down its left edge, its fill
## tinted `amount` towards `tint` (null: the plain row fill).
func flat(stripe: Color, tint = null, amount: float = 0.16) -> Card:
	_flat = true
	_stripe = stripe
	_tint = tint
	_tint_amount = amount
	_restyle()
	return self


## This card is a section in colour `c`: its frame follows Kit.look.
func section_look(c: Color) -> Card:
	_section = true
	_section_color = c
	_restyle()
	return self


## A section: `head` across the top inside the frame, the body under it
## (padded `pad_px` from the frame, `sep` between its rows). From then on
## `add()` and `box` are the body.
func with_head(head: Control, pad_px: int = 10, sep: int = 8) -> Card:
	_pad = FRAME
	_restyle()
	box.add_theme_constant_override("separation", 0)
	box.add_child(head)
	var m = MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", pad_px - FRAME)
	m.add_theme_constant_override("margin_right", pad_px - FRAME)
	m.add_theme_constant_override("margin_top", pad_px - 2)
	m.add_theme_constant_override("margin_bottom", maxi(0, pad_px - FRAME - 2))
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", sep)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(body)
	box.add_child(m)
	box = body
	return self


func _restyle() -> void:
	if _flat:
		add_theme_stylebox_override("panel", _row_box())
		return
	var bg = Pal.PANEL if _bg == null else _bg
	if _hot:
		bg = bg.lightened(0.07)
	if _section and Kit.look != "stripe":
		add_theme_stylebox_override("panel", _section_box(bg))
		return
	add_theme_stylebox_override("panel", PixBox.panel(bg, _border, _pad))


## A section's frame by the look (Kit.look).
func _section_box(bg: Color) -> StyleBox:
	var c = _section_color
	match Kit.look:
		"arcade":
			return PixBox.make(bg, {"ring": c, "lip": 3, "lip_color": c.darkened(0.55), "pad_h": _pad, "pad_v": _pad})
		"clean":
			# A soft card on the page: real rounding, no border, a shadow under it.
			return Kit.soft_box(bg.lerp(Pal.BG2, 0.25), 16, null, 0, _pad, _pad, Pal.with_alpha(Pal.OUTLINE, 0.55), 10, Vector2(0, 4))
		"rpg":
			return PixBox.make(Pal.WELL.lerp(bg, 0.55), {"ring": Pal.ACCENT_DARK, "lip": 2, "lip_color": Pal.OUTLINE, "pad_h": _pad, "pad_v": _pad})
		_:
			return Kit.soft_box(Pal.with_alpha(Pal.WELL, 0.85), 10, c, 2, _pad, _pad, Pal.with_alpha(c, 0.35), 10)


## A row's box by the look (Kit.look): the stripe down the left edge ("stripe"), a raised tile with a lip in
## its colour (arcade), nothing but a line under it (clean), a sunken slot (rpg), an outline (neon).
func _row_box() -> StyleBox:
	var base = Pal.slot()
	var c = _stripe
	match Kit.look:
		"arcade":
			var fill = Pal.PANEL2.lightened(0.04) if _tint == null else Pal.PANEL2.lerp(_tint, _tint_amount + 0.12)
			if _hot:
				fill = fill.lightened(0.06)
			return PixBox.make(fill, {"ring": c.darkened(0.1), "lip": 3, "lip_color": c.darkened(0.4), "pad_h": _pad, "pad_v": _pad})
		"clean":
			# No box: a hairline under the row; a done or chosen row a soft wash.
			var cs = Kit.soft_box(Color(0, 0, 0, 0) if _tint == null else Pal.with_alpha(_tint, _tint_amount * 0.8), 10, null, 0, _pad, _pad)
			if _hot:
				cs.bg_color = Pal.with_alpha(Pal.TEXT, 0.05)
			if _tint == null:
				cs.set_corner_radius_all(0)
				cs.border_width_bottom = 1
				cs.border_color = Pal.with_alpha(Pal.MUTED, 0.18)
			return cs
		"rpg":
			var rf = Pal.WELL.lerp(Pal.PANEL, 0.35) if _tint == null else Pal.WELL.lerp(_tint, _tint_amount + 0.05)
			if _hot:
				rf = rf.lightened(0.06)
			return PixBox.make(rf, {"inset": true, "lip": 0, "ring": Pal.OUTLINE.lerp(c, 0.25), "pad_h": _pad, "pad_v": _pad})
		"neon":
			var nf = Pal.with_alpha(Pal.BG, 0.7) if _tint == null else Pal.with_alpha(Pal.WELL.lerp(_tint, _tint_amount + 0.1), 0.9)
			if _hot:
				nf = nf.lightened(0.06)
			return Kit.soft_box(nf, 8, Pal.with_alpha(c, 0.9), 2, _pad, _pad, Pal.with_alpha(c, 0.3), 5)
	var f = base if _tint == null else base.lerp(_tint, _tint_amount)
	if _hot:
		f = f.lightened(0.06)
	var sb = Kit.sbox(f, 3, null, 0, _pad, _pad)
	sb.border_width_left = STRIPE
	sb.border_color = _stripe
	sb.content_margin_left = _pad + STRIPE
	return sb


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
