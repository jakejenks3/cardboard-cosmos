class_name Kit
extends RefCounted
## The UI toolkit: every screen is built in code from these helpers, so the
## whole game shares one look. Nothing here knows about game rules.

## Where modal sheets and overlays are added. Set by main.gd.
static var overlay_root: Control = null

static var _theme = null
static var _bold = null


# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------

static func font_bold() -> Font:
	if _bold == null:
		var fv = FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.65
		_bold = fv
	return _bold


## A flat box with slightly rounded corners: tags, badges and small custom surfaces.
## (Cards, buttons and inputs use the pixel-art boxes from PixBox instead.)
static func sbox(bg: Color, radius: int = 12, border = null, bw: int = 1, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	# Kept blocky so flat boxes sit comfortably next to the pixel-art ones.
	s.set_corner_radius_all(mini(radius, 5))
	if border != null:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = false
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t = Theme.new()
	t.default_font_size = 15

	t.set_color("font_color", "Label", Pal.TEXT)
	t.set_constant("line_spacing", "Label", 2)

	t.set_color("default_color", "RichTextLabel", Pal.TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PanelContainer", PixBox.panel())

	# Plain buttons get the quiet raised look; Kit.button restyles them.
	var plain = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 14, 7, 1, Pal.BORDER)
	for k in plain:
		t.set_stylebox(k, "Button", plain[k])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Pal.TEXT)
	t.set_color("font_hover_color", "Button", Pal.TEXT)
	t.set_color("font_pressed_color", "Button", Pal.TEXT)
	t.set_color("font_focus_color", "Button", Pal.TEXT)
	t.set_color("font_disabled_color", "Button", Pal.with_alpha(Pal.TEXT, 0.45))
	t.set_font("font", "Button", font_bold())
	t.set_constant("h_separation", "Button", 6)

	var le = PixBox.well(12, 8, Pal.LINE)
	var le_focus = PixBox.well(12, 8, Pal.ACCENT)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", PixBox.well(12, 8, null))
	t.set_color("font_color", "LineEdit", Pal.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Pal.with_alpha(Pal.MUTED, 0.6))
	t.set_color("caret_color", "LineEdit", Pal.ACCENT)
	t.set_color("selection_color", "LineEdit", Pal.with_alpha(Pal.ACCENT, 0.35))
	t.set_font_size("font_size", "LineEdit", 16)

	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", le_focus)
	t.set_color("font_color", "TextEdit", Pal.TEXT)
	t.set_color("font_placeholder_color", "TextEdit", Pal.with_alpha(Pal.MUTED, 0.6))
	t.set_color("caret_color", "TextEdit", Pal.ACCENT)

	# Slim, quiet scrollbar.
	var grab = StyleBoxFlat.new()
	grab.bg_color = Pal.with_alpha(Pal.MUTED, 0.35)
	grab.set_corner_radius_all(2)
	var grab_hi = grab.duplicate()
	grab_hi.bg_color = Pal.with_alpha(Pal.MUTED, 0.6)
	var track = StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("scroll_focus", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)

	t.set_stylebox("panel", "TooltipPanel", PixBox.make(Pal.OUTLINE.lightened(0.05), {"ring": Pal.BORDER, "lip": 0, "pad_h": 8, "pad_v": 5}))
	t.set_color("font_color", "TooltipLabel", Pal.TEXT)

	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	_theme = t
	return t


## Forget cached styles (after a theme change); the caller rebuilds the UI.
static func reset_style() -> void:
	_theme = null
	PixBox.clear_cache()


# --- motion ------------------------------------------------------------------

static var _intro_until: int = 0
static var _intro_n: int = 0


## Call when a screen appears: for the next moment, new cards rise in one after
## another and new bars fill from empty. Later rebuilds (after a click) do not animate.
static func intro_begin() -> void:
	_intro_until = Time.get_ticks_msec() + 400
	_intro_n = 0


static func intro() -> bool:
	return Time.get_ticks_msec() < _intro_until


## The stagger delay for the next thing that animates in.
static func intro_delay() -> float:
	_intro_n += 1
	return minf(float(_intro_n) * 0.03, 0.36)


## Click feedback for any button: a tick as it goes down, a little pop as it comes back up.
static func juice(b: BaseButton) -> void:
	b.button_down.connect(Sfx.tick)
	b.button_up.connect(pop.bind(b, 1.05, 0.16))


## A burst of pixel sparks from the middle of a control (claiming a reward, a new record).
static func burst(at: Control, color = null, count: int = 16) -> void:
	if overlay_root == null or not is_instance_valid(at) or not at.is_inside_tree():
		return
	var b = Burst.new()
	overlay_root.add_child(b)
	b.start(at.get_global_rect().get_center() - overlay_root.global_position, Pal.ACCENT if color == null else color, count)


# ---------------------------------------------------------------------------
# Text
# ---------------------------------------------------------------------------

## A single-line label. `color` is a Color or null (default text colour).
static func label(text, size: int = 15, color = null, bold: bool = false) -> Label:
	var l = Label.new()
	l.text = str(text)
	l.add_theme_font_size_override("font_size", size)
	if color != null:
		l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A label that wraps onto several lines and fills the available width.
static func para(text, size: int = 15, color = null, bold: bool = false) -> Label:
	var l = label(text, size, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(40, 0)
	return l


## A single-line label that fills the width and ends in "…" when too long.
static func clip(text, size: int = 15, color = null, bold: bool = false) -> Label:
	var l = label(text, size, color, bold)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(20, 0)
	return l


static func h1(text) -> Label:
	return label(text, 22, null, true)


static func h2(text) -> Label:
	return label(text, 17, null, true)


## Small caps heading (in the current tab's accent colour) used above groups of cards.
static func h3(text) -> Label:
	return label(str(text).to_upper(), 13, Pal.tab_accent(), true)


static func muted(text, size: int = 13) -> Label:
	return label(text, size, Pal.MUTED)


static func muted_para(text, size: int = 13) -> Label:
	return para(text, size, Pal.MUTED)


## Rich text for lines that mix bold / colours: "[b]Rex[/b] says hi [color=#ffc83d]+20 XP[/color]".
static func rich(bbcode: String, size: int = 15, color = null) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(40, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	if color != null:
		r.add_theme_color_override("default_color", color)
	r.text = bbcode
	return r


## Escape text that goes inside Kit.rich so "[" in a name cannot break the markup.
static func esc(text) -> String:
	return str(text).replace("[", "[lb]")


static func hex_of(c: Color) -> String:
	return "#" + c.to_html(false)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

static func vbox(sep: int = 8) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## A row that wraps its children onto more lines when they do not fit (chips, tags).
static func flow(sep: int = 6) -> HFlowContainer:
	var f = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


static func grid(cols: int, sep: int = 8) -> GridContainer:
	var g = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


## Make a control take all spare horizontal room in its row. Returns the control.
static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Vertically centre a control inside its row. Returns the control.
static func vcenter(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


## Invisible filler that pushes the following children to the right edge.
static func spacer() -> Control:
	var c = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func gap(px: int) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func pad(child: Control, left: int = 0, top: int = 0, right: int = 0, bottom: int = 0) -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(child)
	return m


static func center(child: Control) -> CenterContainer:
	var c = CenterContainer.new()
	c.add_child(child)
	return c


## Remove and free every child (safe to add new children straight after).
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Add several children at once; null entries are skipped. Returns the parent.
static func add(parent: Node, children: Array) -> Node:
	for c in children:
		if c != null:
			parent.add_child(c)
	return parent


## A thin horizontal divider line.
static func divider() -> Control:
	var c = ColorRect.new()
	c.color = Pal.LINE
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------------------
# Surfaces & controls
# ---------------------------------------------------------------------------

## A panel with a vertical stack inside: `card.add(node)` / `card.box`.
## Pass `tap` to make the whole card clickable.
static func card(sep: int = 8, tap: Callable = Callable(), pad_px: int = 14) -> Card:
	var c = Card.new(sep, pad_px)
	if tap.is_valid():
		c.on_tap(tap)
	return c


const _BTN_SIZES = {
	"sm": {"font": 13, "pad_h": 11, "pad_v": 5},
	"md": {"font": 15, "pad_h": 15, "pad_v": 8},
	"lg": {"font": 17, "pad_h": 20, "pad_v": 11},
}


## Face, lip and text colour of each button variant; "depth" is how far it stands up.
static func _variant(variant: String) -> Dictionary:
	match variant:
		"primary":
			return {"face": Pal.ACCENT, "lip": Pal.ACCENT_DARK, "fg": Pal.INK, "ring": null, "depth": 2}
		"good":
			return {"face": Pal.GOOD, "lip": Pal.GOOD_DARK, "fg": Color("0d2a17"), "ring": null, "depth": 2}
		"danger":
			return {"face": Pal.DANGER, "lip": Pal.DANGER_DARK, "fg": Color.WHITE, "ring": null, "depth": 2}
		"ghost":
			return {"face": Pal.PANEL2, "lip": Pal.OUTLINE.lightened(0.1), "fg": Pal.TEXT, "ring": Pal.BORDER, "depth": 1}
	return {"face": Pal.SECOND, "lip": Pal.SECOND_DARK, "fg": Color.WHITE, "ring": null, "depth": 2}


## Restyle any Button as a chunky raised pixel button that sinks when pressed.
## Variants: primary (gold), good (green), secondary (blue), ghost (quiet), danger (red).
static func style_button(b: Button, variant: String = "primary", size: String = "md") -> void:
	var sz = _BTN_SIZES.get(size, _BTN_SIZES["md"])
	var v = _variant(variant)
	var looks = PixBox.button_set(v.face, v.lip, sz.pad_h, sz.pad_v, v.depth, v.ring)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, v.fg)
	b.add_theme_color_override("font_disabled_color", Pal.with_alpha(v.fg, 0.45))
	b.add_theme_font_size_override("font_size", sz.font)
	b.add_theme_font_override("font", font_bold())
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.set_meta("tt_drop", (v.depth + 1) * PixBox.S)
	b.set_meta("tt_fg", v.fg)


## A button. `icon` is an Icons name shown before the text ("" for none).
static func button(text, variant: String = "primary", on_press: Callable = Callable(), size: String = "md", icon: String = "") -> Button:
	var b = Button.new()
	b.text = str(text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_button(b, variant, size)
	if icon != "":
		_button_icon(b, icon, variant, size)
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Godot pins a Button's icon to the button's edge, away from centred text.
## To keep icon and text together, the Button's own text is made invisible
## (it still gives the button its size) and an icon + label row is laid on top,
## which sinks with the face when the button is pressed.
static func _button_icon(b: Button, icon: String, _variant_name: String, size: String) -> void:
	var sz = _BTN_SIZES.get(size, _BTN_SIZES["md"])
	var fg = b.get_meta("tt_fg", Pal.TEXT)
	var drop = int(b.get_meta("tt_drop", 0))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -drop
	row.add_child(Icons.rect(icon, 16))
	row.add_child(label(b.text, sz.font, fg, true))
	b.add_child(row)
	# The label can only be measured properly once it is on screen, so the width
	# is set now and again whenever the row's size is known or changes.
	var fit = func():
		b.custom_minimum_size.x = row.get_combined_minimum_size().x + sz.pad_h * 2
	fit.call()
	row.minimum_size_changed.connect(fit)
	b.ready.connect(fit)
	b.draw.connect(func(): row.modulate.a = 0.5 if b.disabled else 1.0)
	b.button_down.connect(func():
		row.offset_top = drop
		row.offset_bottom = 0)
	b.button_up.connect(func():
		row.offset_top = 0
		row.offset_bottom = -drop)


## A square icon-only button (settings cog, close, edit, delete …).
static func icon_button(icon: String, on_press: Callable = Callable(), tip: String = "", px: int = 40) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(px, px)
	b.tooltip_text = tip
	b.icon = Icons.tex(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pad_px = int(max(4, (px - 26) / 2.0))
	var looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), pad_px, pad_px - 1, 1, Pal.BORDER)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A text link ("All trophies →").
static func link(text, on_press: Callable = Callable(), size: int = 13) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.add_theme_color_override("font_color", Pal.ACCENT)
	b.add_theme_color_override("font_hover_color", Pal.ACCENT.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", Pal.ACCENT.darkened(0.15))
	b.add_theme_color_override("font_focus_color", Pal.ACCENT)
	b.add_theme_font_size_override("font_size", size)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A small raised chip. Active chips are filled with `color` (default gold).
static func chip(text, active: bool = false, on_press: Callable = Callable(), color = null, size: int = 13) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	style_chip(b, active, color, size)
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


static func style_chip(b: Button, active: bool, color = null, size: int = 13) -> void:
	var col = Pal.ACCENT if color == null else color
	var looks
	var fg
	if active:
		looks = PixBox.button_set(col, col.darkened(0.42), 11, 4, 1, null)
		fg = Pal.INK
	else:
		looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 11, 4, 1, Pal.LINE)
		fg = Pal.TEXT
	# Each chip gets its own copies: callers are free to adjust a chip's padding.
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k].duplicate())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## A small non-interactive coloured tag ("RARE", "weak: lift").
static func tag(text, color: Color, dark_text: bool = true, size: int = 11) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(color, 99, null, 0, 8, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(label(text, size, Pal.INK if dark_text else Pal.TEXT, true))
	return p


static func rarity_badge(rarity: String) -> PanelContainer:
	return tag(rarity.to_upper(), Pal.rarity(rarity), true, 10)


## Discipline pill with its pixel icon: "[icon] Lifting".
static func disc_tag(d: String) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Pal.with_alpha(Pal.disc(d), 0.22), 99, Pal.disc(d), 1, 8, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h = hbox(4)
	h.add_child(Icons.rect(d, 14))
	h.add_child(label(TT.DISCIPLINE_META[d].name, 12, Pal.TEXT, true))
	p.add_child(h)
	return p


## A text field. `numeric` centres the text and suits number entry.
static func input(value = "", placeholder: String = "", numeric: bool = false) -> LineEdit:
	var e = LineEdit.new()
	e.text = str(value)
	e.placeholder_text = placeholder
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(48, 42)
	e.select_all_on_focus = true
	e.caret_blink = true
	if numeric:
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	return e


## A labelled form field: small muted label, the control, optional hint line.
static func field(label_text: String, control: Control, hint: String = "") -> VBoxContainer:
	var v = vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(label(label_text, 12, Pal.MUTED, true))
	v.add_child(control)
	if hint != "":
		v.add_child(muted_para(hint, 11))
	return v


## A progress bar, value 0..1. Call `bar.set_value(v)` to animate it later.
static func bar(value: float, color = null, height: int = 10) -> Bar:
	return Bar.new(value, color, height)


## A section heading in the pixel font and the current tab's colour, with a rule
## running to the right and an optional control (usually a Kit.link) at the end.
static func section_title(text: String, right: Control = null) -> HBoxContainer:
	var h = hbox(8)
	h.custom_minimum_size = Vector2(0, 26)
	var clean = Icons.strip_emoji(text)
	if clean.length() <= 22:
		h.add_child(vcenter(PixelFont.rect(clean, 2, Pal.tab_accent())))
	else:
		h.add_child(h3(clean))
	var rule = ColorRect.new()
	rule.color = Pal.with_alpha(Pal.tab_accent(), 0.3)
	rule.custom_minimum_size = Vector2(8, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rule)
	if right != null:
		h.add_child(right)
	return h


## A small tile: muted label, big value, optional sub-line.
static func stat(label_text: String, value, sub: String = "", color = null) -> Card:
	var c = Card.new(2, 11)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add(clip(label_text, 11, Pal.MUTED, true))
	c.add(clip(str(value), 18, color, true))
	if sub != "":
		c.add(clip(sub, 11, Pal.MUTED))
	return c


## Friendly placeholder for an empty list.
static func empty(icon: String, title: String, body: String = "", action: Control = null) -> Card:
	var c = Card.new(8, 20)
	var ic = Icons.rect(icon, 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add(ic)
	var t = para(title, 16, null, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add(t)
	if body != "":
		var b = muted_para(body, 13)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add(b)
	if action != null:
		action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add(action)
	return c


## One-of-many switch. `options` = [{"value": v, "label": "Text"}]. `on_change.call(value)`.
static func segmented(options: Array, value, on_change: Callable = Callable(), color = null) -> Segmented:
	var s = Segmented.new()
	s.setup(options, value, color, false)
	if on_change.is_valid():
		s.selected.connect(on_change)
	return s


## Sub-navigation pills under a screen title. Same arguments as `segmented`.
static func sub_tabs(options: Array, value, on_change: Callable = Callable()) -> Segmented:
	var s = Segmented.new()
	s.setup(options, value, null, true)
	if on_change.is_valid():
		s.selected.connect(on_change)
	return s


## − [number] + field. `opts`: min, max, snap (bool), base (start value when empty),
## placeholder, width. Read `stepper.text` / `stepper.number()`; `on_change.call(text)`.
static func stepper(value, step: float = 1.0, on_change: Callable = Callable(), opts: Dictionary = {}) -> Stepper:
	var s = Stepper.new()
	s.setup(str(value), step, opts)
	if on_change.is_valid():
		s.changed.connect(on_change)
	return s


## A modal bottom sheet. Add content to `sheet.box`, then `sheet.open()`.
static func sheet(title: String = "") -> Sheet:
	var s = Sheet.new()
	s.setup(title)
	return s


## "Are you sure?" sheet with a confirm and a cancel button.
static func confirm(title: String, body: String, confirm_label: String, on_confirm: Callable, danger: bool = true) -> void:
	var s = sheet(title)
	if body != "":
		s.box.add_child(muted_para(body, 14))
	var row = hbox(10)
	var cancel = button("Cancel", "ghost", s.close)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var ok = button(confirm_label, "danger" if danger else "primary", func():
		s.close()
		on_confirm.call())
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	s.box.add_child(row)
	s.open()


## Play a quick "pop" on a control (used when something is earned or tapped).
static func pop(c: Control, amount: float = 1.12, dur: float = 0.22) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw = c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), dur * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Fade + slide a freshly built control in.
static func fade_in(c: CanvasItem, dur: float = 0.2, delay: float = 0.0) -> void:
	c.modulate.a = 0.0
	var tw = c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur)
