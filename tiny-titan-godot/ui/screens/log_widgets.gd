class_name LogWidgets
extends RefCounted
## Small pieces shared by the Log tab's forms (session form, lift editor, body
## check-in): the top bar, "same as last time" template rows, the date field,
## the XP preview, the Cancel / Save row, and number parsing.

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
	h.add_child(Kit.vcenter(Icons.rect(icon, 22)))
	var t = Kit.clip(title, 19, null, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	if on_delete.is_valid():
		h.add_child(Kit.icon_button("trash", on_delete, "Delete", 34))
	return h


## A one-tap "start from this" row: date · what it contains · Use →.
## `one_line` clips the text to a single line (full text in the tooltip).
static func template(date_key: String, text: String, on_tap: Callable, one_line: bool = true) -> Card:
	var c = Kit.card(0, on_tap, 8)
	c.tint(Pal.PANEL, Pal.with_alpha(Pal.ACCENT, 0.35))
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d = Kit.label(Dates.relative_day(date_key, App.today), 11, Pal.ACCENT, true)
	d.custom_minimum_size = Vector2(58, 0)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	var clean = Icons.strip_emoji(text)
	var names = Kit.clip(clean, 13) if one_line else Kit.para(clean, 13)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(names)
	c.tooltip_text = clean
	var go = Kit.label("Use →", 12, Pal.ACCENT, true)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(go)
	c.add(Kit.pad(h, 2, 0, 2, 0))
	c.box.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Height of the compact top-row boxes (date, duration, distance …).
const ROW_H = 32


## Date entry: ‹ [YYYY-MM-DD] › with the day spelled out in small type under it.
## `on_change.call(key)` only fires with a valid date.
static func date_field(value: String, on_change: Callable) -> VBoxContainer:
	var row = Kit.hbox(2)
	var e = Kit.input(value, "YYYY-MM-DD", true)
	e.set_meta(FKEY, "date")
	e.tooltip_text = "Date (YYYY-MM-DD)"
	e.custom_minimum_size = Vector2(96, ROW_H)
	e.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	e.max_length = 10
	_slim_edit(e)
	var hint = Kit.label(_date_hint(value), 10, Pal.MUTED)
	var apply = func(t: String) -> void:
		if is_date_key(t):
			hint.text = _date_hint(t)
			hint.add_theme_color_override("font_color", Pal.MUTED)
			on_change.call(t)
		else:
			hint.text = "Use YYYY-MM-DD, not in the future"
			hint.add_theme_color_override("font_color", Pal.DANGER)
	var shift = func(n: int) -> void:
		var cur = e.text.strip_edges()
		if not is_date_key(cur):
			cur = App.today
		var nxt = Dates.add_days(cur, n)
		if nxt > App.today:
			return
		Sfx.tick()
		e.text = nxt
		apply.call(nxt)
	var prev = _day_btn("‹")
	prev.tooltip_text = "Day before"
	prev.pressed.connect(func(): shift.call(-1))
	var nxt_btn = _day_btn("›")
	nxt_btn.tooltip_text = "Day after"
	nxt_btn.pressed.connect(func(): shift.call(1))
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
		return ""
	var days = Dates.days_between(t, App.today)
	var long = Dates.format_date(t, {"weekday": "short", "month": "short", "day": "numeric"})
	if days == 0:
		return "Today · " + long
	if days == 1:
		return "Yesterday · " + long
	return long


static func _day_btn(text: String, h: int = ROW_H) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(28, h)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Pal.MUTED)
	b.add_theme_color_override("font_hover_color", Pal.TEXT)
	b.add_theme_color_override("font_pressed_color", Pal.INK)
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.with_alpha(Pal.PANEL2, 0.0), 8, null, 0, 2, 0))
	b.add_theme_stylebox_override("hover", Kit.sbox(Pal.PANEL2, 8, Pal.LINE, 1, 2, 0))
	b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.ACCENT, 8, Pal.ACCENT, 1, 2, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## A square − / + button (climb counts).
static func round_btn(text: String, on_press: Callable, tip: String = "") -> Button:
	var b = _day_btn(text, 30)
	b.custom_minimum_size = Vector2(30, 30)
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.WELL, 8, Pal.LINE, 1, 2, 0))
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


## Narrow inner padding so short numbers fit small boxes.
static func _slim_edit(e: LineEdit, pad_h: int = 4, pad_v: int = 5) -> void:
	# LineEdit reserves room for 4 "M"s by default: far too wide for a 3-digit box.
	e.add_theme_constant_override("minimum_character_width", 0)
	e.add_theme_font_size_override("font_size", 14)
	e.add_theme_stylebox_override("normal", Kit.sbox(Pal.WELL, 9, Pal.LINE, 1, pad_h, pad_v))
	e.add_theme_stylebox_override("focus", Kit.sbox(Pal.WELL, 9, Pal.ACCENT, 2, pad_h, pad_v))


## A small number box (duration parts, distance …) with a focus key.
static func num_input(value: String, placeholder: String, fkey: String, width: int = 0) -> LineEdit:
	var e = Kit.input(value, placeholder, true)
	e.set_meta(FKEY, fkey)
	e.custom_minimum_size = Vector2(width if width > 0 else 48, ROW_H)
	_slim_edit(e, 6)
	return e


## Tag a Kit.stepper's text box for focus restore (and slim down a classic one).
static func slim_stepper(st: Stepper, fkey: String, btn_w: int = 34) -> LineEdit:
	var edit = null
	for c in st.get_children():
		if c is Button and not st.compact:
			c.custom_minimum_size = Vector2(btn_w, 40)
		elif c is LineEdit:
			edit = c
	if edit != null:
		edit.set_meta(FKEY, fkey)
		if not st.compact:
			_slim_edit(edit, 4, 9)
	return edit


## A small, quiet pill button (quick picks, "+ Set", "More"): 12 px text, 28 px tall.
static func mini_chip(text: String, active: bool = false, on_press: Callable = Callable(), color = null, pad_h: int = 9) -> Button:
	var b = Kit.chip(text, active, on_press, color, 12)
	for k in ["normal", "hover", "pressed", "disabled"]:
		var sb = b.get_theme_stylebox(k)
		if sb != null:
			sb.content_margin_left = pad_h
			sb.content_margin_right = pad_h
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
	b.custom_minimum_size = Vector2(0, 28)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Width a mini_chip with this text will take.
static func mini_chip_width(text: String, pad_h: int = 9) -> float:
	return Kit.font_bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + pad_h * 2 + 2


## An icon button with no box of its own (remove set / exercise): muted icon, faint hover.
static func quiet_icon(icon: String, on_press: Callable, tip: String, px: int = 28) -> Button:
	var b = Kit.icon_button(icon, on_press, tip, px)
	var pad_px = int(maxf(5.0, (px - 16) / 2.0))
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.with_alpha(Pal.PANEL2, 0.0), 8, null, 0, pad_px, pad_px))
	b.add_theme_stylebox_override("hover", Kit.sbox(Pal.PANEL2, 8, null, 0, pad_px, pad_px))
	b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.with_alpha(Pal.DANGER, 0.3), 8, null, 0, pad_px, pad_px))
	b.add_theme_color_override("icon_normal_color", Pal.with_alpha(Pal.MUTED, 0.8))
	b.add_theme_color_override("icon_hover_color", Pal.TEXT)
	b.add_theme_color_override("icon_pressed_color", Pal.TEXT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## A text field that reads as a bold title: no box until hovered or focused.
static func title_edit(value: String, placeholder: String, px: int = 16) -> LineEdit:
	var e = Kit.input(value, placeholder)
	e.custom_minimum_size = Vector2(48, 30)
	e.add_theme_font_override("font", Kit.font_bold())
	e.add_theme_font_size_override("font_size", px)
	var plain = Kit.sbox(Pal.with_alpha(Pal.WELL, 0.0), 8, Pal.with_alpha(Pal.LINE, 0.0), 1, 6, 3)
	var hover = Kit.sbox(Pal.with_alpha(Pal.WELL, 0.6), 8, Pal.LINE, 1, 6, 3)
	e.add_theme_stylebox_override("normal", plain)
	e.add_theme_stylebox_override("focus", Kit.sbox(Pal.WELL, 8, Pal.ACCENT, 2, 6, 3))
	e.mouse_entered.connect(func(): e.add_theme_stylebox_override("normal", hover))
	e.mouse_exited.connect(func(): e.add_theme_stylebox_override("normal", plain))
	return e


## Fill `holder` with the XP preview: "+240 XP" in pixel type, a side note and a sub line.
static func fill_xp_preview(holder: Container, amount: int, color: Color, side: String, sub: String) -> void:
	Kit.clear(holder)
	var main_row = Kit.hbox(8)
	main_row.add_child(Kit.vcenter(PixelFont.rect("+%s XP" % Xp.fmt_int(amount), 2, color)))
	if side != "":
		main_row.add_child(Kit.vcenter(Kit.muted_para(side, 11)))
	holder.add_child(main_row)
	if sub != "":
		holder.add_child(Kit.muted_para(sub, 11))


## The bottom block: the XP preview beside the save button, in one card.
## Without an XP preview (editing a check-in) the left side holds a Cancel link.
## Returns {"card", "save", "xp"} (xp is null when `with_xp` is false).
static func finish_block(save_label: String, on_cancel: Callable, on_save: Callable, with_xp: bool = true) -> Dictionary:
	var c = Kit.card(0, Callable(), 10)
	var row = Kit.hbox(10)
	var xp = null
	if with_xp:
		xp = Kit.vbox(2)
		xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(xp)
	else:
		var cancel = Kit.link("Cancel", on_cancel, 13)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(cancel)
	var save = Kit.button(save_label, "good", on_save, "md")
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(save)
	c.add(row)
	return {"card": c, "save": save, "xp": xp}


## A text area for notes (wraps, grows a little).
static func text_area(value: String, placeholder: String, fkey: String, on_change: Callable, rows: int = 3) -> TextEdit:
	var t = TextEdit.new()
	t.text = value
	t.placeholder_text = placeholder
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.custom_minimum_size = Vector2(0, 26 * rows + 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.set_meta(FKEY, fkey)
	t.text_changed.connect(func(): on_change.call(t.text))
	return t
