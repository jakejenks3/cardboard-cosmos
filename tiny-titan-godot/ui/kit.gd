class_name Kit
extends RefCounted
## The UI toolkit: every screen is built in code from these helpers, so the
## whole game shares one look. Nothing here knows about game rules.
##
## Four kinds of thing, each with one look (2026-11-24, kept in the Workshop look of 2026-11-27):
##   - a solid bevelled key (button, chip): it DOES something;
##   - a dark sunken track with one key raised (choice_track + choice): PICK ONE;
##   - a paper chip with a coloured rim (option_chip): ANOTHER WAY, opens a page;
##   - a small flat tag (tag, pill): it only SAYS something.
## One wooden window per subject (section: a sign with its title on the frame's top edge, coloured by what it
## is about), rows inside it on cream paper slips (row), groups inside it under a sub_head, done boxes as
## tick_box, counts as pips, icons in framed slots (badge). The materials are in ui/pix_box.gd and their
## colours in ui/pal.gd; ui/ink.gd keeps every word readable on what it sits on.

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
	t.set_color("font_outline_color", "Label", Pal.OUTLINE)
	t.set_constant("line_spacing", "Label", 2)

	t.set_color("default_color", "RichTextLabel", Pal.TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("panel", "PanelContainer", PixBox.material("card", {"pad_h": 14, "pad_v": 14}))

	# Plain buttons: a tan key with dark words; Kit.button restyles them.
	var plain = PixBox.block_set("tan", 14, 7, 1)
	for k in plain:
		t.set_stylebox(k, "Button", plain[k])
	t.set_stylebox("hover_pressed", "Button", plain["pressed"])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", Pal.TEXT)
	t.set_color("font_disabled_color", "Button", Pal.with_alpha(Pal.TEXT, 0.45))
	t.set_color("font_outline_color", "Button", Pal.OUTLINE)
	t.set_font("font", "Button", font_bold())
	t.set_constant("h_separation", "Button", 6)

	# Words being typed sit in a dark well, in cream.
	var le = PixBox.well(12, 8, null)
	var le_focus = PixBox.well(12, 8, Pal.ACCENT)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", PixBox.well(12, 8, null))
	t.set_color("font_color", "LineEdit", Pal.CREAM)
	t.set_color("font_uneditable_color", "LineEdit", Pal.with_alpha(Pal.CREAM, 0.6))
	t.set_color("font_placeholder_color", "LineEdit", Pal.with_alpha(Pal.CREAM, 0.42))
	t.set_color("caret_color", "LineEdit", Pal.GOLD_TEXT)
	t.set_color("selection_color", "LineEdit", Pal.with_alpha(Pal.ACCENT, 0.4))
	t.set_font_size("font_size", "LineEdit", 16)

	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", le_focus)
	t.set_color("font_color", "TextEdit", Pal.CREAM)
	t.set_color("font_placeholder_color", "TextEdit", Pal.with_alpha(Pal.CREAM, 0.42))
	t.set_color("caret_color", "TextEdit", Pal.GOLD_TEXT)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))

	# Slim, quiet scrollbar.
	var grab = StyleBoxFlat.new()
	grab.bg_color = Pal.with_alpha(Pal.BORDER, 0.55)
	grab.set_corner_radius_all(2)
	var grab_hi = grab.duplicate()
	grab_hi.bg_color = Pal.with_alpha(Pal.BORDER, 0.85)
	var track = StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("scroll_focus", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_hi)
		t.set_stylebox("grabber_pressed", sb, grab_hi)

	t.set_stylebox("panel", "TooltipPanel", PixBox.material("note", {"pad_h": 8, "pad_v": 6}))
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


## A page's title on the planks (Adventure, Journey, Armory): cream with a dark outline, like a game's.
static func h1(text) -> Label:
	return outlined(text, 24)


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
## Each key variant: its face (a Pal.BLOCKS name) and how deep its lip is.
## primary gold (THE main action, a reward), good green, danger red, ghost tan (quiet), blue, and the
## default (secondary) wood.
static func _variant(variant: String) -> Dictionary:
	match variant:
		"primary":
			return {"face": "gold", "depth": 2}
		"good":
			return {"face": "green", "depth": 2}
		"danger":
			return {"face": "red", "depth": 2}
		"ghost":
			return {"face": "tan", "depth": 1}
		"blue":
			return {"face": "blue", "depth": 2}
		"orange":
			return {"face": "orange", "depth": 2}
		"purple":
			return {"face": "purple", "depth": 2}
	return {"face": "wood", "depth": 2}


## The words on a key: dark ink on a light face (gold, tan), cream with a dark outline on the others (the
## Workshop's keys). Leaves "tt_fg" and "tt_outline" on the button for _button_icon.
static func key_words(b: Button, face, px: int) -> void:
	var dark = PixBox.dark_words(face)
	var fg = Pal.INK if dark else Pal.CREAM
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	var face_c: Color = PixBox.block_colors(face)[3]
	b.add_theme_color_override("font_disabled_color", fg.lerp(face_c.lerp(Pal.PANEL, 0.55), 0.4))
	var ol = 0 if dark else outline_for(px)
	b.add_theme_constant_override("outline_size", ol)
	b.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	b.set_meta("tt_fg", fg)
	b.set_meta("tt_outline", ol)


## How thick the dark outline round cream words is at a font size.
static func outline_for(px: int) -> int:
	return 6 if px >= 17 else (5 if px >= 14 else 4)


## A label in cream with a dark outline (words on wood, on a key, on the page).
static func outlined(text, size: int = 15, color = null, bold: bool = true) -> Label:
	var l = label(text, size, Pal.CREAM if color == null else color, bold)
	l.add_theme_constant_override("outline_size", outline_for(size))
	l.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	return l


## Dark ink or cream, whichever reads better on `c` (words on a tag, a pill, a chip).
static func on_color(c: Color) -> Color:
	return Pal.INK if Ink.contrast(Pal.INK, c) >= Ink.contrast(Pal.CREAM, c) else Pal.CREAM


## Restyle any Button as a chunky raised pixel button that sinks when pressed.
## Variants: primary (gold), good (green), secondary (blue), ghost (quiet), danger (red).
static func style_button(b: Button, variant: String = "primary", size: String = "md") -> void:
	var sz = _BTN_SIZES.get(size, _BTN_SIZES["md"])
	var v = _variant(variant)
	# A small button is too low for a finger: taller on a phone.
	var looks = PixBox.block_set(v.face, sz.pad_h, sz.pad_v + (4 if fingers and size == "sm" else 0), v.depth)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	key_words(b, v.face, sz.font)
	b.add_theme_font_size_override("font_size", sz.font)
	b.add_theme_font_override("font", font_bold())
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.set_meta("tt_drop", (v.depth + 1) * PixBox.S)


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
	# (its outline too: else the hidden words' dark outline shows as a ghost under the icon)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	var row = HBoxContainer.new()
	# (outlined words reach a little further out: a wider gap keeps them off the icon)
	row.add_theme_constant_override("separation", 8 + int(int(b.get_meta("tt_outline", 0)) / 2.0))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -drop
	row.add_child(Icons.rect(icon, 16))
	var words = label(b.text, sz.font, fg, true)
	var ol = int(b.get_meta("tt_outline", 0))
	if ol > 0:
		words.add_theme_constant_override("outline_size", ol)
		words.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	row.add_child(words)
	b.add_child(row)
	# The label can only be measured properly once it is on screen, so the width
	# is set now and again whenever the row's size is known or changes.
	var fit = func():
		b.custom_minimum_size.x = row.get_combined_minimum_size().x + sz.pad_h * 2
	fit.call()
	row.minimum_size_changed.connect(fit)
	b.ready.connect(fit)
	b.draw.connect(func(): row.modulate.a = 0.62 if b.disabled else 1.0)
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
	# A small wooden key with the icon on it.
	var looks = PixBox.block_set("wood", pad_px, pad_px, 1)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
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
	# Orange ink on paper (ui/ink.gd darkens it there), bright orange on the dark page.
	var col = Pal.ACCENT2 if color == null else color
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
	var pv = 8 if fingers else 4
	var face = col if active else "tan"
	var looks = PixBox.block_set(face, 11, pv, 1)
	# Each chip gets its own copies: callers are free to adjust a chip's padding.
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k].duplicate())
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"].duplicate())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	key_words(b, face, size)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font_bold())
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## A small non-interactive coloured tag ("RARE", "weak: lift").
static func tag(text, color: Color, _dark_text: bool = true, size: int = 11) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", tag_box(color))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(tag_words(text, size, color))
	return p


## The words of a tag or a chip on `face`: dark ink on a light face, cream with a dark shadow on a darker
## one (as the mock-up's tags; ui/ink.gd leaves words with a shadow alone).
static func tag_words(text, size: int, face: Color) -> Label:
	var dark = Ink.luminance(face) > 0.42
	var l = label(text, size, Pal.INK if dark else Pal.CREAM, true)
	if not dark:
		l.add_theme_color_override("font_shadow_color", Pal.OUTLINE)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.add_theme_constant_override("shadow_outline_size", 1)
	return l


## The box of a tag: a dark rim, a lit top and a shaded bottom, the colour.
static func tag_box(color: Color, pad_h: int = 6, pad_v: int = 1) -> StyleBoxTexture:
	return PixBox.nine([Pal.OUTLINE, PixBox.bev(color.lightened(0.3), color.darkened(0.22))], color, {"cut": 0, "pad_h": pad_h, "pad_v": pad_v})


# ---------------------------------------------------------------------------
# Sections and rows (the Hero tab's look; see the top of this file)
# ---------------------------------------------------------------------------

## A framed section: one Card with a band across its top in `color` (an icon,
## the title in pixel letters, `right` at the end: a count, a link, a key) and
## a frame in the same colour. `add()` fills the body under the band. Tests find
## a section by its meta "section" = `id` (pixel letters are not Label text).
static func section(id: String, title: String, icon: String, color: Color, right: Control = null, tap: Callable = Callable(), sep: int = 8, pad_px: int = 10) -> Card:
	var c = card(sep, tap, pad_px)
	c.section_look(color)
	# The head (SignRow): the sign centred on the frame's top edge, the note at the right end.
	var head = SignRow.new()
	# The sign: a small plate in a deep shade of the section's colour, its title in cream pixel letters.
	var sign = PanelContainer.new()
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_stylebox_override("panel", sign_box(color))
	var sh = hbox(6)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		sh.add_child(vcenter(Icons.rect(icon, 16)))
	var t = PixelFont.rect(title, 2, Pal.CREAM)
	sh.add_child(vcenter(t))
	sign.add_child(sh)
	head.add_child(sign)
	if right != null:
		# What sits at the end of the head (a count, a link, a key) is pinned on a paper note.
		var note = PanelContainer.new()
		note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note.add_theme_stylebox_override("panel", PixBox.material("note", {"pad_h": 6, "pad_v": 2}))
		note.add_child(right)
		head.add_child(note)
	c.with_head(head, pad_px, sep)
	c.set_meta("section", id)
	return c


## The sign of a section in `color`: a deep shade of it, bevelled, with a dark rim.
static func sign_box(color: Color) -> StyleBoxTexture:
	# (2026-11-27 review: a deep shade of a blue tab came out navy, the old look; the plate stays wood and
	# the colour is a ring inside its rim)
	var face = Color(Pal.MATERIALS["plate"].fill).lerp(Pal.deep(color), 0.18)
	return PixBox.nine([Pal.OUTLINE, PixBox.bev(color.lightened(0.15), color.darkened(0.35)), PixBox.bev(face.lightened(0.22), face.darkened(0.3))], face, {"cut": 1, "pad_h": 10, "pad_v": 7})


## An icon in a framed slot: a dark rim, a ring in `color`, a dark brown well (the Workshop's icon slots).
static func badge(icon: String, color: Color, px: int = 20) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", PixBox.slot(color, true, 4))
	p.add_child(center(Icons.rect(icon, px)))
	return p


## A row inside a section: a cream paper slip, tinted `amount` towards `tint` (a done row green). `stripe` is
## kept for the callers (it was a stripe down the left edge, 2026-11-24 to 27): the slip no longer shows it.
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
	# A small square in the group's colour, the words in brown ink, a dotted rule to the end.
	var pip = PanelContainer.new()
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.custom_minimum_size = Vector2(10, 10)
	pip.add_theme_stylebox_override("panel", PixBox.nine([Pal.OUTLINE], color, {"cut": 0, "pad_h": 0, "pad_v": 0}))
	h.add_child(vcenter(pip))
	var l = label(text, 12, Pal.MUTED, true)
	if tip != "":
		l.tooltip_text = tip
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(vcenter(l))
	if right is Label:
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(vcenter(right))
	else:
		h.add_child(vcenter(dotted_rule()))
		if right != null:
			h.add_child(vcenter(right))
	return h


## A dotted line that fills the row (between a heading and what is at its end).
static func dotted_rule() -> Control:
	var r = DottedRule.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(8, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


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
	# A raised key's lip: 1 art pixel of side plus the rim row under it.
	var lip = 2 * PixBox.S
	if on:
		var looks = PixBox.block_set(color, 10, pv, 1)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, looks[k].duplicate())
		b.add_theme_stylebox_override("hover_pressed", looks["pressed"].duplicate())
		key_words(b, color, size)
	else:
		var off = StyleBoxEmpty.new()
		off.content_margin_left = 10
		off.content_margin_right = 10
		off.content_margin_top = pv
		off.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("normal", off)
		var hov = sbox(Pal.with_alpha(Pal.CREAM, 0.08), 3, null, 0, 10, pv)
		hov.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("hover", hov)
		var prs = sbox(Pal.with_alpha(color, 0.3), 3, null, 0, 10, pv)
		prs.content_margin_bottom = pv + lip
		b.add_theme_stylebox_override("pressed", prs)
		b.add_theme_stylebox_override("hover_pressed", prs.duplicate())
		# Words on the dark track: a light tan.
		var fg = Pal.CREAM.darkened(0.12)
		for k in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, fg)
		b.add_theme_color_override("font_disabled_color", Pal.with_alpha(fg, 0.45))
		b.add_theme_color_override("font_hover_color", Pal.CREAM)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	p.add_theme_stylebox_override("panel", PixBox.material("track", {"pad_h": 3, "pad_v": 3}))
	var h = hbox(2)
	for b in buttons:
		h.add_child(b)
	p.add_child(h)
	return p


## Another way to do something (the OR options of a lift): a small tan key that opens a page. `color` null =
## plain; a colour tints its face (blue: new to you, orange: try a change).
static func option_chip(text, color = null, on_press: Callable = Callable(), size: int = 12) -> Button:
	var b = Button.new()
	b.text = str(text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pv = 8 if fingers else 3
	# (2026-11-27 review: outlined paper read as the old style) A small tan key; a colour tints its face
	# light (blue: new to you), so the words stay dark ink.
	var face = "tan" if color == null else (color as Color).lerp(Pal.CREAM, 0.55)
	var looks = PixBox.block_set(face, 8, pv, 1)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Pal.INK)
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
		var g = PixBox.block_colors("green")
		box.add_theme_stylebox_override("panel", PixBox.nine([g[0], PixBox.bev(g[1], g[2])], g[3], {"cut": 0, "pad_h": 0, "pad_v": 0}))
	else:
		box.add_theme_stylebox_override("panel", empty_box())
	var mid = CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		mid.add_child(Icons.rect("check", 16, Pal.CREAM))
	box.add_child(mid)
	return box


## An empty box to tick: pale paper sunk into a brown rim.
static func empty_box() -> StyleBoxTexture:
	return PixBox.nine([Pal.BORDER.darkened(0.15), PixBox.bev(Pal.LINE, Pal.PANEL2.lightened(0.6))], Pal.PANEL2.lightened(0.5), {"cut": 0, "pad_h": 0, "pad_v": 0})


## A count as small squares: `done` filled in `color`, the rest empty (ten at
## most, then "done/total").
static func pips(done: int, total: int, color: Color, px: int = 10) -> HBoxContainer:
	var h = hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(mini(total, 10)):
		var p = Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.custom_minimum_size = Vector2(px, px)
		var on = i < done
		p.add_theme_stylebox_override("panel", PixBox.nine([Pal.OUTLINE], color, {"cut": 0, "pad_h": 0, "pad_v": 0}) if on else empty_box())
		h.add_child(vcenter(p))
	if total > 10:
		h.add_child(vcenter(label("%d/%d" % [done, total], 11, Pal.MUTED, true)))
	return h


## A slim notice above the page (a backup is due, a new version, the phone
## note): a row striped and tinted in `color`, an icon, a line or two, an
## optional key at the end.
static func notice(icon: String, title: String, sub: String, color: Color, action: Control = null, tap: Callable = Callable()) -> Card:
	var c = row(tap, color, null, 6, 0)
	var h = hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vcenter(badge(icon, color, 24)))
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
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col = Pal.disc(d)
	p.add_theme_stylebox_override("panel", tag_box(col, 6, 1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h = hbox(4)
	h.add_child(Icons.rect(d, 14))
	h.add_child(tag_words(TT.DISCIPLINE_META[d].name, 12, col))
	p.add_child(h)
	return p


## A raised coloured pill: optional icon + bold text. With `tip` it shows a tooltip.
static func pill(icon: String, text: String, color: Color, tip: String = "", fg = null, font_px: int = 12) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(color, {"lip": 1, "pad_h": 7, "pad_v": 3}))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = tip
	var h = hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(vcenter(Icons.rect(icon, 16)))
	if text != "":
		h.add_child(vcenter(tag_words(text, font_px, color) if fg == null else label(text, font_px, fg, true)))
	p.add_child(h)
	return p


## A small flat chip: an icon and a few words on a colour. `fg` defaults to
## dark ink on a bright colour and light text on a dark one. With `tip` it
## shows a tooltip.
static func icon_chip(icon: String, text: String, color: Color, tip: String = "", fg = null) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", tag_box(color, 7, 2))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = tip
	var h = hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		h.add_child(vcenter(Icons.rect(icon, 14)))
	if fg == null:
		h.add_child(vcenter(tag_words(text, 12, color)))
	else:
		h.add_child(vcenter(label(text, 12, fg, true)))
	p.add_child(h)
	return p


## A coin amount as a gold pill ("[coin] 1,240").
static func coin_pill(amount, tip: String = "", font_px: int = 12) -> PanelContainer:
	# Gold numbers in a dark cap, the coin hanging off its left edge.
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.material("cap", {"pad_h": 7, "pad_v": 3}))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = tip
	var h = hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vcenter(Icons.rect("coin", 16)))
	h.add_child(vcenter(label(Xp.fmt_int(amount), font_px, Pal.GOLD_TEXT, true)))
	p.add_child(h)
	return p


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
	var cap = PixelFont.rect("%s / %s" % [Xp.fmt_int(TTUtil.jsround(hp_left)), Xp.fmt_int(TTUtil.jsround(hp_max))], 2 if height >= 18 else 1, Pal.CREAM)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cream with a dark shadow reads on the bar's fill and on its dark track alike.
	cap.set_meta("ink_keep", true)
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


## A heading between windows (on the page): a small sign plate in the current tab's colour with the title
## in cream pixel letters, a dotted rule to the right and an optional control (usually a Kit.link) at the end.
static func section_title(text: String, right: Control = null) -> HBoxContainer:
	var h = hbox(8)
	h.custom_minimum_size = Vector2(0, 30)
	var clean = Icons.strip_emoji(text)
	var sign = PanelContainer.new()
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = sign_box(Pal.tab_accent()).duplicate()
	sb.set_content_margin(SIDE_TOP, 5)
	sb.set_content_margin(SIDE_BOTTOM, 5)
	sign.add_theme_stylebox_override("panel", sb)
	if clean.length() <= 22:
		sign.add_child(PixelFont.rect(clean, 2, Pal.CREAM))
	else:
		sign.add_child(outlined(clean.to_upper(), 13))
	h.add_child(vcenter(sign))
	h.add_child(vcenter(dotted_rule()))
	if right != null:
		h.add_child(vcenter(right))
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
