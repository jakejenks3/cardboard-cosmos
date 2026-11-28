class_name Kit
extends RefCounted
## The UI toolkit: every screen is built in code from these helpers, so the
## whole game shares one look. Nothing here knows about game rules.
##
## Four looks, each with one meaning (2026-11-24, the Hero tab's clean-up):
##   - a raised key with a lip (button, chip): it DOES something;
##   - a sunken track with one key raised (choice_track + choice): PICK ONE;
##   - an outlined chip (option_chip): ANOTHER WAY, opens a page;
##   - a flat tag (tag, pill): it only SAYS something.
## One framed section per subject (section: a band in its colour across the
## top), rows inside it flat (row: a stripe down the left edge), groups inside
## it under a sub_head, done boxes as tick_box, counts as pips.

## THE LOOK of sections, rows and their icons (2026-11-27, the user: "that rectangle with the left edge being a
## color... looks really ugly... experiment with new designs"). "stripe" is how it was; the others are the
## mock-ups shown to the user: "arcade" (chunky raised tiles, solid coloured headers), "clean" (no boxes in
## boxes: rows split by thin lines, colour in rounded icon badges, plain bold headings), "rpg" (gold-trimmed
## windows, sunken item slots), "neon" (dark rows outlined in their colour). Read by section, row (Card.flat),
## badge and sub_head; nothing else changes with it.
const LOOKS = ["stripe", "arcade", "clean", "rpg", "neon"]
static var look: String = "stripe"

## Where modal sheets and overlays are added. Set by main.gd.
static var overlay_root: Control = null
## A phone or tablet (set by main.gd): small keys are made big enough for a finger.
static var fingers: bool = false

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


## Click feedback for any button: a soft pop (and, on a phone, a tick in the
## hand) as it goes down, a little bounce as it comes back up.
static func juice(b: BaseButton) -> void:
	b.button_down.connect(Sfx.click)
	b.button_up.connect(pop.bind(b, 1.05, 0.16))


## A burst of pixel sparks from the middle of a control (claiming a reward, a new record).
static func burst(at: Control, color = null, count: int = 16) -> void:
	if overlay_root == null or not is_instance_valid(at) or not at.is_inside_tree():
		return
	var b = Burst.new()
	overlay_root.add_child(b)
	b.start(at.get_global_rect().get_center() - overlay_root.global_position, Pal.ACCENT if color == null else color, count)


## A short pixel caption that rises from a control and fades ("+20 XP"): what a
## quick action just paid, without a toast to read and wait out.
static func floater(at: Control, text: String, color = null, delay: float = 0.0, px_scale: int = 2) -> void:
	if overlay_root == null or not is_instance_valid(at) or not at.is_inside_tree():
		return
	var r = PixelFont.rect(text, px_scale, Pal.ACCENT if color == null else color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(r)
	var start = (at.get_global_rect().get_center() - overlay_root.global_position - r.custom_minimum_size / 2.0 + Vector2(0, -16)).floor()
	r.position = start
	r.modulate.a = 0.0
	var tw = r.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(r, "modulate:a", 1.0, 0.07)
	tw.parallel().tween_property(r, "position:y", start.y - 38.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.22)
	tw.tween_callback(r.queue_free)


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


## A label as wide as its text, up to `max_w`, cut off with "…" past that: for a
## name with something right beside it (a lift's movement and its variation tag).
static func clip_fit(text, size: int = 15, color = null, bold: bool = false, max_w: float = 220.0) -> Label:
	var l = label(text, size, color, bold)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var f = font_bold() if bold else l.get_theme_font("font")
	var w = f.get_string_size(str(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if f != null else max_w
	l.custom_minimum_size = Vector2(minf(ceilf(w) + 1.0, max_w), 0)
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


## A row whose soft parts are cut off with "…" when there is no room for all of
## them (ui/widgets/squeeze_row.gd): a lift's movement (`soft_name`) and its
## variation (SessionView.variation_tag with soft = true).
static func squeeze(sep: int = 6) -> SqueezeRow:
	var r = SqueezeRow.new()
	r.separation = float(sep)
	return r


## A name for a `squeeze` row: as wide as its text up to `max_w`, giving way down
## to `least` when the row is short of room.
static func soft_name(text, size: int = 15, color = null, bold: bool = false, max_w: float = 220.0, least: float = 60.0) -> Label:
	var l = clip_fit(text, size, color, bold, max_w)
	SqueezeRow.soften(l, l.custom_minimum_size.x, least)
	return l


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
	# A small button is too low for a finger: taller on a phone.
	var looks = PixBox.button_set(v.face, v.lip, sz.pad_h, sz.pad_v + (4 if fingers and size == "sm" else 0), v.depth, v.ring)
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
	if fingers:
		px = maxi(px, 38)
	b.custom_minimum_size = Vector2(px, px)
	b.tooltip_text = tip
	# The icon at a whole-number size (never stretched to the button): twice
	# its size on a big button, its own size on a small one.
	b.icon = Icons.tex(icon, null, 2 if px >= 40 else 1)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pad_px = 2
	var looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), pad_px, pad_px, 1, Pal.BORDER)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A text link ("All trophies →").
static func link(text, on_press: Callable = Callable(), size: int = 13, color = null) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty = StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var col = Pal.ACCENT if color == null else color
	if fingers:
		b.custom_minimum_size.y = 34
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", col.darkened(0.15))
	b.add_theme_color_override("font_focus_color", col)
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
	var pv = 8 if fingers else 4
	if active:
		looks = PixBox.button_set(col, col.darkened(0.42), 11, pv, 1, null)
		fg = Pal.INK
	else:
		looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 11, pv, 1, Pal.LINE)
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


# ---------------------------------------------------------------------------
# Sections and rows (the Hero tab's look; see the top of this file)
# ---------------------------------------------------------------------------

## A framed section: one Card with a band across its top in `color` (an icon,
## the title in pixel letters, `right` at the end: a count, a link, a key) and
## a frame in the same colour. `add()` fills the body under the band. Tests find
## a section by its meta "section" = `id` (pixel letters are not Label text).
static func section(id: String, title: String, icon: String, color: Color, right: Control = null, tap: Callable = Callable(), sep: int = 8, pad_px: int = 10) -> Card:
	var c = card(sep, tap, pad_px)
	c.accent(color)
	c.section_look(color)
	var head = PanelContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(0, 40 if fingers else 34)
	var sb = sbox(Pal.band(color), 0, null, 0, 8, 3)
	sb.border_width_bottom = 2
	sb.border_color = Pal.with_alpha(color, 0.85)
	var title_col = color.lightened(0.25)
	match look:
		"arcade":
			sb = sbox(color, 0, null, 0, 8, 3)
			sb.border_width_bottom = 3
			sb.border_color = color.darkened(0.45)
			title_col = Pal.INK
		"clean":
			sb = sbox(Color(0, 0, 0, 0), 0, null, 0, 12, 8)
		"rpg":
			sb = sbox(Pal.deep(color).lerp(Pal.OUTLINE, 0.35), 0, null, 0, 8, 3)
			sb.border_width_bottom = 2
			sb.border_color = Pal.ACCENT_DARK
			title_col = Pal.ACCENT
		"neon":
			sb = sbox(Color(0, 0, 0, 0), 0, null, 0, 10, 3)
			sb.border_width_bottom = 2
			sb.border_color = color
	head.add_theme_stylebox_override("panel", sb)
	var h = hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(vcenter(badge(icon, color, 16) if look == "clean" else Icons.rect(icon, 16)))
	var t
	if look == "clean":
		t = label(_title_words(title), 18, Pal.TEXT, true)
	else:
		t = PixelFont.rect(title, 2, title_col)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vcenter(t))
	h.add_child(spacer())
	if right != null:
		h.add_child(vcenter(right))
	head.add_child(h)
	c.with_head(head, pad_px, sep)
	c.set_meta("section", id)
	return c


## "NOV 9 - 15" -> "Nov 9 - 15", "LIFT REPORT · 4 WEEKS" -> "Lift report · 4 weeks" (the first word capital).
static func _title_words(t: String) -> String:
	var low = t.to_lower()
	return low.substr(0, 1).to_upper() + low.substr(1) if low != "" else low


## A soft box with real rounding (the clean and neon looks; sbox stays blocky), an optional glow or shadow.
static func soft_box(bg: Color, radius: int, border = null, bw: int = 0, pad_h: int = 12, pad_v: int = 10, glow = null, glow_size: int = 0, offset: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border != null and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	if glow != null and glow_size > 0:
		s.shadow_color = glow
		s.shadow_size = glow_size
		s.shadow_offset = offset
	s.anti_aliasing = true
	s.corner_detail = 8
	return s


## An icon on a small plate in `color`, by the look (Kit.look): solid with a lip (arcade), a soft rounded
## wash (clean), a sunken slot (rpg), an outline (neon); the plain icon in the "stripe" look.
static func badge(icon: String, color: Color, px: int = 20) -> Control:
	var ic = Icons.rect(icon, px)
	if look == "stripe":
		return ic
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pad = maxi(4, int(px / 4.0))
	var sb = null
	match look:
		"arcade":
			sb = PixBox.make(color, {"lip": 1, "lip_color": color.darkened(0.45), "pad_h": pad, "pad_v": pad})
		"clean":
			sb = soft_box(Pal.with_alpha(color, 0.2), int(px / 2.0) + pad, null, 0, pad, pad)
		"rpg":
			sb = PixBox.make(Pal.WELL, {"inset": true, "lip": 0, "ring": color.darkened(0.2), "pad_h": pad, "pad_v": pad})
		_:
			sb = soft_box(Pal.with_alpha(color, 0.1), 6, color, 2, pad, pad, Pal.with_alpha(color, 0.45), 4)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(center(ic))
	return p


## A row inside a section: a flat fill (Pal.slot) with a stripe of `stripe`
## down its left edge (null: a quiet line), tinted `amount` towards `tint`.
## Tappable with `tap`, like any Card.
static func row(tap: Callable = Callable(), stripe = null, tint = null, pad_px: int = 8, sep: int = 4, amount: float = 0.16) -> Card:
	var c = Card.new(sep, pad_px)
	c.flat(Pal.LINE if stripe == null else stripe, tint, amount)
	if tap.is_valid():
		c.on_tap(tap)
	return c


## A group's heading inside a section: a short bar of `color`, the words, and
## `right` at the end (a Label there is cut off with "..." rather than widen the row).
static func sub_head(text: String, color: Color, right: Control = null, tip: String = "") -> HBoxContainer:
	var h = hbox(6)
	h.custom_minimum_size = Vector2(0, 22)
	var l = label(text, 12, Pal.TEXT, true)
	match look:
		"arcade":
			# A tag in its colour.
			l = label(" %s " % text, 11, Pal.INK, true)
			var tp = PanelContainer.new()
			tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tp.add_theme_stylebox_override("panel", sbox(color, 2, null, 0, 4, 1))
			tp.add_child(l)
			h.add_child(vcenter(tp))
		"clean":
			l = label(text, 11, Pal.MUTED, true)
			h.add_child(vcenter(l))
		"rpg":
			h.add_child(vcenter(label("◆", 10, Pal.ACCENT, true)))
			l = label(text, 12, Pal.ACCENT, true)
			h.add_child(vcenter(l))
		"neon":
			l = label(text, 12, color.lightened(0.2), true)
			h.add_child(vcenter(l))
		_:
			var bar = ColorRect.new()
			bar.color = color
			bar.custom_minimum_size = Vector2(4, 14)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(vcenter(bar))
	if look != "stripe":
		if tip != "":
			l.tooltip_text = tip
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		if right is Label:
			right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(vcenter(right))
		else:
			h.add_child(spacer())
			if right != null:
				h.add_child(vcenter(right))
		return h
	if tip != "":
		l.tooltip_text = tip
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(vcenter(l))
	if right is Label:
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(vcenter(right))
	else:
		h.add_child(spacer())
		if right != null:
			h.add_child(vcenter(right))
	return h


## One key of a pick-one track (choice_track): raised in `color` when it is the
## one picked, else just its word on the track. Both are the same height, so
## nothing moves when the pick changes.
static func choice(text, on: bool, on_press: Callable, color: Color, size: int = 13) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv = 8 if fingers else 5
	# A raised key's lip: 1 art pixel of colour plus the outline row under it.
	var lip = 2 * PixBox.S
	var fg = Pal.MUTED
	if on:
		var looks = PixBox.button_set(color, color.darkened(0.42), 10, pv, 1, null)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, looks[k].duplicate())
		b.add_theme_stylebox_override("hover_pressed", looks["pressed"].duplicate())
		fg = Pal.INK
	else:
		var off = StyleBoxEmpty.new()
		off.content_margin_left = 10
		off.content_margin_right = 10
		off.content_margin_top = pv
		off.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("normal", off)
		var hov = sbox(Pal.with_alpha(Pal.TEXT, 0.07), 3, null, 0, 10, pv)
		hov.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("hover", hov)
		var prs = sbox(Pal.with_alpha(color, 0.3), 3, null, 0, 10, pv)
		prs.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("pressed", prs)
		b.add_theme_stylebox_override("hover_pressed", prs.duplicate())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_hover_color", Pal.INK if on else Pal.TEXT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## The sunken track a set of `choice` keys sits in.
static func choice_track(buttons: Array) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", PixBox.well(3, 3, null))
	var h = hbox(2)
	for b in buttons:
		h.add_child(b)
	p.add_child(h)
	return p


## Another way to do something (the OR options of a lift): an outlined chip
## that opens a page. `color` null = neutral; a colour marks it (blue: new to you).
static func option_chip(text, color = null, on_press: Callable = Callable(), size: int = 12) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pv = 8 if fingers else 4
	var edge = Pal.LINE.lightened(0.2) if color == null else Pal.with_alpha(color, 0.75)
	var tint = Pal.BORDER if color == null else color
	b.add_theme_stylebox_override("normal", sbox(Pal.with_alpha(tint, 0.1), 3, edge, 2, 8, pv))
	b.add_theme_stylebox_override("hover", sbox(Pal.with_alpha(tint, 0.2), 3, edge, 2, 8, pv))
	b.add_theme_stylebox_override("pressed", sbox(Pal.with_alpha(tint, 0.32), 3, edge, 2, 8, pv))
	b.add_theme_stylebox_override("hover_pressed", sbox(Pal.with_alpha(tint, 0.32), 3, edge, 2, 8, pv))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Pal.TEXT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	if fingers:
		b.custom_minimum_size.y = 38
	juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A done box, the same everywhere: an empty well while still to do, solid
## green with a tick once done. The same size in both states.
static func tick_box(done: bool, px: int = 26) -> PanelContainer:
	var box = PanelContainer.new()
	var side = px + (4 if fingers else 0)
	box.custom_minimum_size = Vector2(side, side)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if done:
		box.add_theme_stylebox_override("panel", sbox(Pal.GOOD, 4, Pal.GOOD_DARK, 2, 0, 0))
	else:
		box.add_theme_stylebox_override("panel", sbox(Pal.WELL, 4, Pal.LINE.lightened(0.1), 2, 0, 0))
	var mid = CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		mid.add_child(Icons.rect("check", 16, Pal.INK))
	box.add_child(mid)
	return box


## A count as small squares: `done` filled in `color`, the rest empty (ten at
## most, then "done/total").
static func pips(done: int, total: int, color: Color, px: int = 10) -> HBoxContainer:
	var h = hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(mini(total, 10)):
		var p = Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(px, px)
		var on = i < done
		p.add_theme_stylebox_override("panel", sbox(color if on else Pal.WELL, 2, color.darkened(0.4) if on else Pal.LINE, 1, 0, 0))
		h.add_child(vcenter(p))
	if total > 10:
		h.add_child(vcenter(label("%d/%d" % [done, total], 11, Pal.MUTED, true)))
	return h


## A slim notice above the page (a backup is due, a new version, the phone
## note): a row striped and tinted in `color`, an icon, a line or two, an
## optional key at the end.
static func notice(icon: String, title: String, sub: String, color: Color, action: Control = null, tap: Callable = Callable()) -> Card:
	var c = row(tap, color, color, 8, 0, 0.12)
	var h = hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vcenter(Icons.rect(icon, 24)))
	var v = vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(clip(title, 14, null, true))
	if sub != "":
		v.add_child(clip(sub, 12, Pal.MUTED))
	h.add_child(v)
	if action != null:
		h.add_child(vcenter(action))
	c.add(h)
	return c


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


## A raised coloured pill: optional icon + bold text. With `tip` it shows a tooltip.
static func pill(icon: String, text: String, color: Color, tip: String = "", fg = null, font_px: int = 12) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(color, {"lip": 1, "lip_color": color.darkened(0.45), "pad_h": 7, "pad_v": 3}))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = tip
	var h = hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(vcenter(Icons.rect(icon, 16)))
	if text != "":
		h.add_child(vcenter(label(text, font_px, Pal.INK if fg == null else fg, true)))
	p.add_child(h)
	return p


## A small flat chip: an icon and a few words on a colour. `fg` defaults to
## dark ink on a bright colour and light text on a dark one. With `tip` it
## shows a tooltip.
static func icon_chip(icon: String, text: String, color: Color, tip: String = "", fg = null) -> PanelContainer:
	var p = PanelContainer.new()
	var quiet = color == Pal.PANEL2
	p.add_theme_stylebox_override("panel", sbox(color, 5, Pal.LINE if quiet else null, 1 if quiet else 0, 7, 3))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = tip
	var h = hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(vcenter(Icons.rect(icon, 14)))
	if fg == null:
		fg = Pal.INK if color.get_luminance() > 0.5 else Pal.TEXT
	h.add_child(vcenter(label(text, 12, fg, true)))
	p.add_child(h)
	return p


## A coin amount as a gold pill ("[coin] 1,240").
static func coin_pill(amount, tip: String = "", font_px: int = 12) -> PanelContainer:
	return pill("coin", Xp.fmt_int(amount), Pal.ACCENT, tip, null, font_px)


## The coins the player has, as a gold pill that counts up (or down) from what
## it last showed whenever the amount changed, with a little pop.
static var _purse_shown: int = -1


static func purse_pill(amount: int, tip: String = "", font_px: int = 13) -> PanelContainer:
	var p = coin_pill(amount, tip, font_px)
	var from = _purse_shown
	_purse_shown = amount
	if from >= 0 and from != amount and not intro():
		var labels = p.find_children("*", "Label", true, false)
		if not labels.is_empty():
			var l: Label = labels[0]
			l.text = Xp.fmt_int(from)
			var tw = p.create_tween()
			tw.tween_method(func(v): l.text = Xp.fmt_int(int(round(v))), float(from), float(amount), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			p.ready.connect(pop.bind(p, 1.15, 0.3), CONNECT_DEFERRED)
	return p


## A pixel-font caption that is as big as fits in `width` (scale `max_scale` down to 1).
static func big_number(text: String, color: Color, width: int, max_scale: int = 4) -> TextureRect:
	var w = PixelFont.measure(text).x
	var sc = max_scale
	while sc > 1 and w * sc > width:
		sc -= 1
	var r = PixelFont.rect(text, sc, color)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## Let clicks on a tile's contents reach the tappable card around them.
static func passthrough(n: Node) -> void:
	for c in n.get_children():
		if c is Control and not (c is BaseButton):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passthrough(c)


## A thick HP bar with the numbers written on it in the pixel font.
static func hp_bar(hp_left: float, hp_max: float, height: int = 22, tip: String = "") -> Control:
	var holder = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	holder.tooltip_text = tip
	holder.add_child(bar(hp_left / maxf(1.0, hp_max), Pal.HP, height))
	var cap = PixelFont.rect("%s / %s" % [Xp.fmt_int(TTUtil.jsround(hp_left)), Xp.fmt_int(TTUtil.jsround(hp_max))], 2 if height >= 18 else 1, Color.WHITE)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc = center(cap)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cc)
	return holder


## An on / off switch: a sunken track with a raised knob, green with a tick when on.
## `on_change.call(new_value)`.
static func switch(on: bool, on_change: Callable, tip: String = "") -> PixSwitch:
	var sw = PixSwitch.new()
	sw.setup(on, tip)
	# The switch flips at once (a screen that rebuilds after the change draws it
	# again anyway; one that does not, like a sheet, would look stuck).
	sw.pressed.connect(func():
		sw.on = not sw.on
		sw.queue_redraw()
		on_change.call(sw.on))
	juice(sw)
	return sw


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
## A thick bar (12 px and up) gets a glint that runs along it now and then.
static func bar(value: float, color = null, height: int = 10) -> Bar:
	var b = Bar.new(value, color, height)
	b.glint = height >= 12
	b.set_process(b.glint)
	return b


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
