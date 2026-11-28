class_name Card
extends PanelContainer
## A panel with a vertical stack inside. Optionally tappable, and optionally colour-coded with `accent()`.
##
## In the Workshop look (2026-11-27, ui/pal.gd) a card takes its material from where it sits:
##   - on the page (no card or paper round it): a WOODEN WINDOW, sand parchment in a wooden frame, its
##     shadow on the planks;
##   - inside a window, a sheet or another card: CREAM PAPER with a dark rim (`_nested`); on the page but
##     side by side with others (stat tiles in a grid): the same paper with a shadow (`_tile`);
##   - `with_head(head)` (Kit.section): a window whose frame starts half way down its head, so the sign in
##     the head sits on the frame's top edge; `add()` fills the body under it;
##   - `flat(...)` (Kit.row): a ROW, a cream paper slip.
## A section tells ui/ink.gd what its words sit on with meta "ink_bg"; every other box carries meta "bg".

var box: VBoxContainer
var _tap = Callable()
var _press_at = null
var _squash_tw = null
var _down_msec: int = -100000
var _pad = 14
## null = the material's own fill / no colour-coded edge.
var _bg = null
var _border = null
var _hot = false
## The wooden frame (screen px): 7 art pixels of rings.
const FRAME = 14
var _flat = false
var _nested = false
var _nested_known = false
## On the page but side by side with others (in a grid or a row: stat tiles): paper with a shadow, not a
## whole wooden window each.
var _tile = false
## A section (Kit.section): its frame drawn from half way down its head.
var _section = false
var _section_color = Color()
var _head: Control = null
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


func _enter_tree() -> void:
	var was = [_nested, _tile]
	_nested = _inside_paper()
	var par = get_parent()
	_tile = not _nested and (par is GridContainer or par is HBoxContainer or par is HFlowContainer or _in_list(par))
	if not _nested_known or was != [_nested, _tile]:
		_nested_known = true
		_restyle()
	# The first card of a list came in before the others: it joins them.
	if _tile and _in_list(par):
		for k in par.get_children():
			if k is Card and k != self and not k._tile and not k._nested and not k._section:
				k._tile = true
				k._restyle()


## One of a list of cards (two or more cards in a column that is not the screen itself: the lifts of
## Journey -> Lifts, a history): paper slips with a shadow read as a list; a wooden window each is too heavy.
func _in_list(par: Node) -> bool:
	if not (par is VBoxContainer) or par is UiScreen:
		return false
	var n = 0
	for k in par.get_children():
		if k is Card and not k._section:
			n += 1
	return n >= 2


## On paper already: inside another card or a sheet (meta "tt_paper").
func _inside_paper() -> bool:
	var p = get_parent()
	while p != null:
		if p is Card or p.has_meta("tt_paper"):
			return true
		p = p.get_parent()
	return false


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


## Colour-code the card: a line inside its frame (a window) or the inner ring of its rim (paper) takes
## `color`. With `fill`, the whole card is a deep shade of that colour (the boss card is dark red; its words
## turn cream by themselves, ui/ink.gd).
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


## A row (see the top): a cream paper slip tinted `amount` towards `tint` (null: plain). `stripe` is kept
## for the callers (it was a stripe down the left edge, 2026-11-24 to 27); the slip does not show it.
func flat(stripe: Color, tint = null, amount: float = 0.16) -> Card:
	_flat = true
	_stripe = stripe
	_tint = tint
	_tint_amount = amount
	_restyle()
	return self


## This card is a section in colour `c` (Kit.section): a wooden window under a sign; the line inside its
## frame is in `c`.
func section_look(c: Color) -> Card:
	_section = true
	_section_color = c
	_restyle()
	return self


## A section: `head` across the top (the frame's top edge runs through its middle), the body under it
## (padded from the frame, `sep` between its rows). From then on `add()` and `box` are the body.
func with_head(head: Control, pad_px: int = 10, sep: int = 8) -> Card:
	_head = head
	box.add_theme_constant_override("separation", 0)
	box.add_child(head)
	var m = MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side = FRAME + maxi(2, pad_px - 8)
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", side + 2 * PixBox.S)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", sep)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(body)
	box.add_child(m)
	box = body
	head.resized.connect(queue_redraw)
	_restyle()
	return self


func _restyle() -> void:
	if _flat:
		add_theme_stylebox_override("panel", _row_box())
		return
	if _section:
		# The frame is drawn by _draw, from half way down the head.
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		set_meta("ink_bg", _fill(Pal.PANEL))
		queue_redraw()
		return
	if _nested or _tile:
		add_theme_stylebox_override("panel", _paper_box())
	else:
		add_theme_stylebox_override("panel", _window_box())


func _fill(base: Color) -> Color:
	var f = base if _bg == null else _bg
	if _hot:
		f = f.lightened(0.06)
	return f


## The rings of a wooden window, its inner line in `line` (null: the material's own dark line).
func _wood_rings(fill: Color, line = null) -> Array:
	var rings = []
	for r in Pal.MATERIALS["wood"].rings:
		rings.append(PixBox.spec(r))
	if line is Color:
		rings[5] = (line as Color).darkened(0.12)
	if _bg != null:
		rings[6] = PixBox.bev(fill.lightened(0.18), fill.darkened(0.2))
	return rings


## A wooden window on the page.
func _window_box() -> StyleBox:
	var fill = _fill(Color(Pal.MATERIALS["wood"].fill))
	var side = FRAME + maxi(2, int(_pad / 2.0) - 2)
	return PixBox.nine(_wood_rings(fill, null), fill, {"cut": int(Pal.MATERIALS["wood"].cut), "below": [Pal.SHADOW, Pal.SHADOW], "pad_h": side, "pad_v": side})


## Cream paper (inside a window, a sheet or another card), the inner ring of its rim in the card's colour.
func _paper_box() -> StyleBox:
	var fill = Pal.PANEL2 if _bg == null else _bg
	if _hot:
		fill = fill.lightened(0.3) if _bg == null else fill.lightened(0.06)
	var rings = [PixBox.spec(Pal.MATERIALS["card"].rings[0])]
	if _border is Color:
		rings.append((_border as Color).darkened(0.05))
	rings.append(PixBox.bev(fill.lightened(0.5), fill.darkened(0.16)))
	var below = [Pal.SHADOW, Pal.SHADOW] if _tile else []
	return PixBox.nine(rings, fill, {"cut": 1, "below": below, "pad_h": _pad, "pad_v": _pad})


## A row's slip: cream paper (tinted), a brown rim, a faint shadow under it.
func _row_box() -> StyleBox:
	# (a cool tint, blue or cyan, turns the cream paper a cold grey: those get only a hint)
	var f = Pal.PANEL2
	if _tint != null:
		var t: Color = _tint
		var cool = t.h > 0.45 and t.h < 0.75 and t.s > 0.2
		f = Pal.PANEL2.lerp(t, minf(0.12 if cool else 0.32, _tint_amount * (0.6 if cool else 1.6)))
	if _hot:
		f = f.lightened(0.3)
	var rim = PixBox.spec(Pal.MATERIALS["slip"].rings[0])
	return PixBox.nine([rim, PixBox.bev(f.lightened(0.6), f.darkened(0.14))], f, {"cut": 1, "below": [Pal.with_alpha(Pal.BORDER, 0.55)], "pad_h": _pad, "pad_v": _pad})


func _draw() -> void:
	if not _section:
		return
	var top = 0.0
	if _head != null and is_instance_valid(_head):
		top = floor(_head.size.y / 2.0 / PixBox.S) * PixBox.S
	var fill = _fill(Pal.PANEL)
	# (the section's colour is on its sign; the frame keeps the wood's own dark inner line)
	var sb = PixBox.nine(_wood_rings(fill, null), fill, {"cut": int(Pal.MATERIALS["wood"].cut), "below": [Pal.SHADOW, Pal.SHADOW], "pad_h": 0, "pad_v": 0})
	draw_style_box(sb, Rect2(0, top, size.x, size.y - top))


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
