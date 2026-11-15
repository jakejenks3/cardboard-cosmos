class_name LogWidgets
extends RefCounted
## Small pieces shared by the Log tab's forms (session form, lift editor, body
## check-in): the top bar, "same as last time" tiles, the date field, raised
## pixel keys and chips, the XP preview with the Finish button, number parsing.
## Every colour comes from Pal, so a theme change only needs a rebuild.

## Fields that should get keyboard focus back after a rebuild carry this meta key.
const FKEY = "fkey"


## Typed number -> float. Accepts "82,5" as well as "82.5"; empty or junk is 0 (JS `Number(x) || 0`).
static func num(text) -> float:
	var t = str(text).strip_edges().replace(",", ".")
	if t == "" or not t.is_valid_float():
		return 0.0
	var v = t.to_float()
	return v if is_finite(v) else 0.0


## JS `String(Math.round(n * 10^places) / 10^places)`: 82.5 -> "82.5", 100.0 -> "100".
static func trim_num(n: float, places: int = 2) -> String:
	var k = pow(10.0, places)
	return TTUtil.num_str(TTUtil.jsround(n * k) / k)


## A well-formed date key for a real calendar day, not in the future.
static func is_date_key(t: String) -> bool:
	var re = RegEx.new()
	re.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if re.search(t) == null:
		return false
	if Dates.to_date_key(Dates.parse_date_key(t)) != t:
		return false
	return t <= App.today


## "← [icon] Title  [trash]".
static func topbar(icon: String, title: String, on_back: Callable, on_delete: Callable = Callable()) -> HBoxContainer:
	var h = Kit.hbox(8)
	h.add_child(Kit.icon_button("arrow_left", on_back, "Back", 34))
	h.add_child(Kit.vcenter(Parts.disc_badge(icon, 30) if Xp.is_discipline(icon) else Icons.rect(icon, 24)))
	var t = Kit.clip(title, 19, null, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	if on_delete.is_valid():
		h.add_child(Kit.icon_button("trash", on_delete, "Delete", 34))
	return h


# ---------------------------------------------------------------------------
# Raised keys, chips and badges
# ---------------------------------------------------------------------------

## Make a label read on a bright face: white with a dark pixel outline.
static func on_face(l: Label) -> Label:
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


## A raised pixel key in `face` colour with any `content` laid on top; the face
## and the content sink together while it is held, with a tick and a pop.
## `text` stays the Button's own (invisible) text, so it can be found by name.
static func key(text: String, face: Color, content: Control, on_press: Callable = Callable(), pad_h: int = 8, pad_v: int = 6, lip: int = 2, ring = null) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var looks = PixBox.button_set(face, face.darkened(0.45), pad_h, pad_v, lip, ring)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 8)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	var drop = (lip + 1) * PixBox.S
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = pad_h
	content.offset_right = -pad_h
	content.offset_top = pad_v
	content.offset_bottom = -pad_v - drop
	b.add_child(content)
	b.custom_minimum_size = content.get_combined_minimum_size() + Vector2(pad_h * 2, pad_v * 2 + drop)
	b.button_down.connect(func():
		content.offset_top = pad_v + drop
		content.offset_bottom = -pad_v)
	b.button_up.connect(func():
		content.offset_top = pad_v
		content.offset_bottom = -pad_v - drop)
	b.draw.connect(func(): content.modulate.a = 0.45 if b.disabled else 1.0)
	Kit.juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A centred [icon] Text row for a key.
static func key_row(icon: String, text: String, size: int, fg: Color, icon_px: int = 16, outline: bool = false) -> HBoxContainer:
	var row = Kit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != "":
		row.add_child(Icons.rect(icon, icon_px))
	var l = Kit.label(text, size, fg, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if outline:
		on_face(l)
	row.add_child(l)
	return row


## A toggle chip: filled with `color` when on, a quiet raised chip when off.
static func toggle(text: String, icon: String, on: bool, color: Color, on_press: Callable) -> Button:
	var face = color if on else Pal.PANEL2
	var fg = Pal.INK if on else Pal.TEXT
	var b = key(text, face, key_row(icon, text, 14, fg, 16), on_press, 10, 6, 2 if on else 1, null if on else Pal.LINE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## A small bright pixel badge ("PR!", "+2.5 kg").
static func badge(text: String, color: Color, size: int = 11) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(color, {"lip": 1, "lip_color": color.darkened(0.45), "pad_h": 6, "pad_v": 1}))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(Kit.label(text, size, Pal.INK, true))
	return p


## A unit chip beside a number field ("km", "kg", "%").
static func unit_chip(text: String) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL2, {"ring": Pal.LINE, "lip": 1, "pad_h": 7, "pad_v": 2}))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(Kit.label(text, 12, Pal.MUTED, true))
	return p


## A one-tap "start from this" tile: discipline badge, what it holds, when, Use →.
static func template(date_key: String, text: String, on_tap: Callable, icon: String = "lift", sub_prefix: String = "") -> Card:
	var c = Kit.card(0, on_tap, 8)
	var h = Kit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Parts.disc_badge(icon, 30))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clean = Icons.strip_emoji(text)
	v.add_child(Kit.clip(clean, 14, null, true))
	var when = Dates.relative_day(date_key, App.today)
	v.add_child(Kit.label(sub_prefix + when if sub_prefix != "" else when, 11, Pal.MUTED))
	h.add_child(v)
	c.tooltip_text = clean
	var go = Kit.label("Use →", 13, Pal.ACCENT, true)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(go)
	c.add(Kit.pad(h, 2, 0, 4, 0))
	c.box.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------------------
# Fields
# ---------------------------------------------------------------------------

## Height of the compact top-row boxes (date, duration, distance …).
const ROW_H = 32


## Date entry: ‹ [YYYY-MM-DD] ›. The day spelled out is in the tooltip; a line
## under it appears only when the date is not valid.
## `on_change.call(key)` only fires with a valid date.
static func date_field(value: String, on_change: Callable) -> VBoxContainer:
	var row = Kit.hbox(3)
	var e = Kit.input(value, "YYYY-MM-DD", true)
	e.set_meta(FKEY, "date")
	e.tooltip_text = _date_hint(value)
	e.custom_minimum_size = Vector2(100, ROW_H)
	e.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	e.max_length = 10
	_slim_edit(e)
	var hint = Kit.label("", 10, Pal.DANGER)
	hint.visible = false
	var apply = func(t: String) -> void:
		if is_date_key(t):
			hint.visible = false
			e.tooltip_text = _date_hint(t)
			on_change.call(t)
		else:
			hint.text = "YYYY-MM-DD, not in the future"
			hint.visible = true
	var shift = func(n: int) -> void:
		var cur = e.text.strip_edges()
		if not is_date_key(cur):
			cur = App.today
		var nxt = Dates.add_days(cur, n)
		if nxt > App.today:
			return
		e.text = nxt
		apply.call(nxt)
	var prev = small_key("‹", func(): shift.call(-1), "Day before", 24, ROW_H)
	var nxt_btn = small_key("›", func(): shift.call(1), "Day after", 24, ROW_H)
	e.text_changed.connect(func(t): apply.call(t.strip_edges()))
	row.add_child(prev)
	row.add_child(e)
	row.add_child(nxt_btn)
	var f = Kit.vbox(2)
	f.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	f.add_child(row)
	f.add_child(hint)
	return f


static func _date_hint(t: String) -> String:
	if not is_date_key(t):
		return "Date (YYYY-MM-DD)"
	var days = Dates.days_between(t, App.today)
	var long = Dates.format_date(t, {"weekday": "short", "month": "short", "day": "numeric"})
	if days == 0:
		return "Today · " + long
	if days == 1:
		return "Yesterday · " + long
	return long


## A small raised pixel key with a glyph (‹ ›, − +): ticks, sinks and pops.
static func small_key(text: String, on_press: Callable, tip: String = "", w: int = 26, h: int = 26) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tip
	var looks = PixBox.button_set(Pal.PANEL2, Pal.OUTLINE.lightened(0.1), 0, 0, 1, Pal.BORDER)
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", Kit.font_bold())
	b.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, Pal.TEXT)
	b.add_theme_color_override("font_pressed_color", Pal.ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", Pal.ACCENT)
	Kit.juice(b)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A small − / + key (climb counts).
static func round_btn(text: String, on_press: Callable, tip: String = "") -> Button:
	return small_key(text, on_press, tip, 24, 24)


## A sunken pixel well with narrow inner padding, so short numbers fit small boxes.
static func _slim_edit(e: LineEdit, pad_h: int = 4, pad_v: int = 5, font_px: int = 14) -> void:
	# LineEdit reserves room for 4 "M"s by default: far too wide for a 3-digit box.
	e.add_theme_constant_override("minimum_character_width", 0)
	e.add_theme_font_size_override("font_size", font_px)
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	e.add_theme_stylebox_override("normal", PixBox.well(pad_h, pad_v, Pal.LINE))
	e.add_theme_stylebox_override("focus", PixBox.well(pad_h, pad_v, Pal.ACCENT))


## A small number box (duration parts, distance …) with a focus key.
static func num_input(value: String, placeholder: String, fkey: String, width: int = 0) -> LineEdit:
	var e = Kit.input(value, placeholder, true)
	e.set_meta(FKEY, fkey)
	e.custom_minimum_size = Vector2(width if width > 0 else 48, ROW_H)
	_slim_edit(e, 4)
	e.add_theme_font_override("font", Kit.font_bold())
	return e


## A big number box (distance, weight): bold pixel-well number.
static func big_input(value: String, placeholder: String, fkey: String, width: int = 0, font_px: int = 26) -> LineEdit:
	var e = Kit.input(value, placeholder, true)
	e.set_meta(FKEY, fkey)
	e.custom_minimum_size = Vector2(width if width > 0 else 64, 50)
	_slim_edit(e, 6, 4, font_px)
	e.add_theme_font_override("font", Kit.font_bold())
	return e


## Tag a Kit.stepper's text box for focus restore. Returns the text box.
static func slim_stepper(st: Stepper, fkey: String, _btn_w: int = 34) -> LineEdit:
	var edit = null
	for c in st.get_children():
		if c is LineEdit:
			edit = c
	if edit != null:
		edit.set_meta(FKEY, fkey)
	return edit


## A small raised chip (quick picks, "+ Set", "More"): 12 px text, 28 px tall.
static func mini_chip(text: String, active: bool = false, on_press: Callable = Callable(), color = null, pad_h: int = 9) -> Button:
	var b = Kit.chip(text, active, on_press, color, 12)
	for k in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb = b.get_theme_stylebox(k)
		if sb != null and b.has_theme_stylebox_override(k):
			sb.content_margin_left = pad_h
			sb.content_margin_right = pad_h
	b.custom_minimum_size = Vector2(0, 28)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Width a mini_chip with this text will take.
static func mini_chip_width(text: String, pad_h: int = 9) -> float:
	return Kit.font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + pad_h * 2 + 2


## An icon button with no box of its own (remove set / exercise): muted icon,
## a pixel key appears under it on hover and goes red when pressed.
static func quiet_icon(icon: String, on_press: Callable, tip: String, px: int = 28) -> Button:
	var b = Kit.icon_button(icon, on_press, tip, px)
	var pad_px = int(maxf(5.0, (px - 16) / 2.0))
	var empty = StyleBoxEmpty.new()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		empty.set_content_margin(side, pad_px)
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", PixBox.make(Pal.PANEL2, {"ring": Pal.LINE, "lip": 0, "pad_h": pad_px, "pad_v": pad_px}))
	b.add_theme_stylebox_override("pressed", PixBox.make(Pal.deep(Pal.DANGER), {"ring": Pal.DANGER, "lip": 0, "pad_h": pad_px, "pad_v": pad_px}))
	b.add_theme_color_override("icon_normal_color", Pal.with_alpha(Pal.MUTED, 0.7))
	b.add_theme_color_override("icon_hover_color", Pal.TEXT)
	b.add_theme_color_override("icon_pressed_color", Pal.TEXT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## A text field that reads as a bold title: no box until hovered or focused.
static func title_edit(value: String, placeholder: String, px: int = 16) -> LineEdit:
	var e = Kit.input(value, placeholder)
	e.custom_minimum_size = Vector2(48, 30)
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	e.add_theme_font_override("font", Kit.font_bold())
	e.add_theme_font_size_override("font_size", px)
	var plain = StyleBoxEmpty.new()
	plain.set_content_margin(SIDE_LEFT, 6)
	plain.set_content_margin(SIDE_RIGHT, 6)
	plain.set_content_margin(SIDE_TOP, 3)
	plain.set_content_margin(SIDE_BOTTOM, 3)
	var hover = PixBox.well(6, 3, Pal.LINE)
	e.add_theme_stylebox_override("normal", plain)
	e.add_theme_stylebox_override("focus", PixBox.well(6, 3, Pal.ACCENT))
	e.mouse_entered.connect(func(): e.add_theme_stylebox_override("normal", hover))
	e.mouse_exited.connect(func(): e.add_theme_stylebox_override("normal", plain))
	return e


# ---------------------------------------------------------------------------
# The finish block
# ---------------------------------------------------------------------------

## Fill `holder` with the XP preview: "+240" as a big gold pixel number, "XP"
## beside it, and at most one short muted line. `tip` goes in the tooltip.
static func fill_xp_preview(holder: Container, amount: int, _color: Color, tip: String, sub: String) -> void:
	Kit.clear(holder)
	var main_row = Kit.hbox(6)
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(PixelFont.rect("+%s" % Xp.fmt_int(amount), 4 if amount < 10000 else 3, Pal.ACCENT))
	var xp = PixelFont.rect("XP", 2, Pal.ACCENT)
	xp.size_flags_vertical = Control.SIZE_SHRINK_END
	main_row.add_child(xp)
	holder.add_child(main_row)
	holder.tooltip_text = tip
	if sub != "":
		holder.add_child(Kit.clip(sub, 11, Pal.MUTED))


## The bottom block: the XP preview (big gold number) beside a big green button.
## Without an XP preview (editing a check-in) the left side holds Cancel.
## Returns {"card", "save", "xp"} (xp is null when `with_xp` is false).
static func finish_block(save_label: String, on_cancel: Callable, on_save: Callable, with_xp: bool = true) -> Dictionary:
	var c = Kit.card(0, Callable(), 10)
	c.accent(Pal.ACCENT)
	var row = Kit.hbox(10)
	var xp = null
	if with_xp:
		xp = Kit.vbox(0)
		xp.mouse_filter = Control.MOUSE_FILTER_PASS
		xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(xp)
	else:
		var cancel = Kit.button("Cancel", "ghost", on_cancel, "md")
		cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cancel)
		row.add_child(Kit.spacer())
	var save = Kit.button(save_label, "good", on_save, "lg", "check")
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(save)
	c.add(row)
	return {"card": c, "save": save, "xp": xp}


## The reward moment when a valid form is saved: sparks from the button and the XP.
static func celebrate(save, xp = null) -> void:
	if save is Control:
		Kit.burst(save, Pal.GOOD, 22)
	if xp is Control:
		Kit.burst(xp, Pal.ACCENT, 26)


## A text area for notes (wraps, grows a little).
static func text_area(value: String, placeholder: String, fkey: String, on_change: Callable, rows: int = 3) -> TextEdit:
	var t = TextEdit.new()
	t.text = value
	t.placeholder_text = placeholder
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(0, 26 * rows + 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.set_meta(FKEY, fkey)
	t.text_changed.connect(func(): on_change.call(t.text))
	return t
