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
	return t <= Dates.today_key()


## "← [icon] Title  [trash]".
static func topbar(icon: String, title: String, on_back: Callable, on_delete: Callable = Callable()) -> HBoxContainer:
	var h = Kit.hbox(10)
	h.add_child(Kit.icon_button("arrow_left", on_back, "Back", 40))
	h.add_child(Kit.vcenter(Icons.rect(icon, 26)))
	var t = Kit.clip(title, 21, null, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	if on_delete.is_valid():
		h.add_child(Kit.icon_button("trash", on_delete, "Delete", 40))
	return h


## A one-tap "start from this" row: date · what it contains · Use →.
static func template(date_key: String, text: String, on_tap: Callable) -> Card:
	var c = Kit.card(0, on_tap, 12)
	c.tint(Pal.PANEL, Pal.with_alpha(Pal.ACCENT, 0.45))
	var h = Kit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d = Kit.label(Dates.relative_day(date_key, App.today), 12, Pal.ACCENT, true)
	d.custom_minimum_size = Vector2(66, 0)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	var names = Kit.para(Icons.strip_emoji(text), 14)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(names)
	var go = Kit.label("Use →", 13, Pal.ACCENT, true)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(go)
	c.add(h)
	return c


## Date entry: a YYYY-MM-DD box with ‹ / › day buttons and the day spelled out
## underneath. `on_change.call(key)` only fires with a valid date.
static func date_field(value: String, on_change: Callable) -> VBoxContainer:
	var row = Kit.hbox(4)
	var e = Kit.input(value, "YYYY-MM-DD", true)
	e.set_meta(FKEY, "date")
	e.custom_minimum_size = Vector2(0, 42)
	e.max_length = 10
	_slim_edit(e)
	var hint = Kit.label(_date_hint(value), 11, Pal.MUTED)
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
	prev.pressed.connect(func(): shift.call(-1))
	var nxt_btn = _day_btn("›")
	nxt_btn.pressed.connect(func(): shift.call(1))
	e.text_changed.connect(func(t): apply.call(t.strip_edges()))
	row.add_child(prev)
	row.add_child(e)
	row.add_child(nxt_btn)
	var f = Kit.field("Date", row)
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


static func _day_btn(text: String) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(30, 42)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Kit.sbox(Pal.PANEL2, 10, Pal.LINE, 1, 2, 2))
	b.add_theme_stylebox_override("hover", Kit.sbox(Pal.PANEL2.lightened(0.08), 10, Pal.LINE, 1, 2, 2))
	b.add_theme_stylebox_override("pressed", Kit.sbox(Pal.ACCENT, 10, Pal.ACCENT, 1, 2, 2))
	return b


## A square − / + button (climb counts).
static func round_btn(text: String, on_press: Callable, tip: String = "") -> Button:
	var b = _day_btn(text)
	b.custom_minimum_size = Vector2(38, 38)
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


## Narrow inner padding so short numbers fit small boxes.
static func _slim_edit(e: LineEdit, pad_h: int = 4) -> void:
	e.add_theme_stylebox_override("normal", Kit.sbox(Pal.WELL, 10, Pal.LINE, 1, pad_h, 9))
	e.add_theme_stylebox_override("focus", Kit.sbox(Pal.WELL, 10, Pal.ACCENT, 2, pad_h, 9))


## A small number box (duration parts, distance …) with a focus key.
static func num_input(value: String, placeholder: String, fkey: String, width: int = 0) -> LineEdit:
	var e = Kit.input(value, placeholder, true)
	e.set_meta(FKEY, fkey)
	if width > 0:
		e.custom_minimum_size = Vector2(width, 42)
	_slim_edit(e, 6)
	return e


## Slim down a Kit.stepper for a tight row and tag its text box for focus restore.
static func slim_stepper(st: Stepper, fkey: String, btn_w: int = 34) -> LineEdit:
	var edit = null
	for c in st.get_children():
		if c is Button:
			c.custom_minimum_size = Vector2(btn_w, 40)
		elif c is LineEdit:
			edit = c
	if edit != null:
		edit.set_meta(FKEY, fkey)
		_slim_edit(edit)
	return edit


## Fill `holder` with the XP preview: "+240 XP" in pixel type, a side note and a sub line.
static func fill_xp_preview(holder: Container, amount: int, color: Color, side: String, sub: String) -> void:
	Kit.clear(holder)
	var main_row = Kit.hbox(10)
	main_row.add_child(Kit.vcenter(PixelFont.rect("+%s XP" % Xp.fmt_int(amount), 3, color)))
	if side != "":
		main_row.add_child(Kit.vcenter(Kit.muted_para(side, 12)))
	holder.add_child(main_row)
	if sub != "":
		holder.add_child(Kit.muted_para(sub, 12))


## Cancel + the big save button. Returns [row, save_button].
static func actions(save_label: String, on_cancel: Callable, on_save: Callable) -> Array:
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Kit.button("Cancel", "ghost", on_cancel)))
	var save = Kit.button(save_label, "good", on_save, "lg")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	return [row, save]


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
