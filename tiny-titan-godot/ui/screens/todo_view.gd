class_name TodoView
extends RefCounted
## The to-do list on screen (game/todos.gd): a card on the Hero tab with the
## open items (a tap ticks one off, there and then) and a sheet with the whole
## list, a box to add to it, a cross to take an item off and "Clear done".
## It is a plain list (no mission or plan reads it) with one small reward:
## ticking an item off pays Todos.BONUS_XP the first time, for a few items a
## day. A row says so with a small "+20 XP" chip (bright while it is to be
## had, quiet once earned), and the XP rises from the row when it is paid.
##
## Nothing may move under the finger: a ticked item stays where it is (on the
## card until tomorrow, in the sheet until it is cleared), the sheet's status
## line is always there, and the box to type in is at the bottom, where the
## sheet (which grows upward) keeps it still; once the sheet scrolls,
## `_keep_form` scrolls by what was added. Taking an item off does move the
## rows above it, so taps are ignored for a moment afterwards (QUIET_MS).

const QUIET_MS = 400
static var _quiet_until: int = 0


static func _busy() -> bool:
	return Time.get_ticks_msec() < _quiet_until


## A tick box: empty while to do, ticked once done.
static func _box(done: bool) -> Control:
	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.GOOD, 0.2) if done else Pal.PANEL2, 4, Pal.GOOD if done else Pal.LINE, 2, 2, 2))
	var mid = CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		mid.add_child(Icons.rect("check", 16))
	box.add_child(mid)
	box.set_meta("todo_box", done)
	return box


## One item: its box and its words; a tap anywhere on it ticks or unticks it.
## With `on_remove`, a cross at the end takes it off the list; `wrap` lets long
## words run over several lines (the sheet) in place of being cut off (the card).
static func _row(t: Dictionary, on_toggle: Callable, on_remove: Callable = Callable(), wrap: bool = false) -> Control:
	var done = bool(t.done)
	var c = Kit.card(0, Callable(), 6)
	# The row itself goes to the tap: what a tick pays rises from it. (Bound
	# on top of what `on_toggle` already carries, it arrives FIRST.)
	c.on_tap(on_toggle.bind(c))
	c.set_meta("todo_row", str(t.id))
	c.tooltip_text = "Untick it" if done else "Tick it off"
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_box(done))
	var l = Kit.para(str(t.text), 14, Pal.MUTED if done else Pal.TEXT, not done) if wrap else Kit.clip(str(t.text), 14, Pal.MUTED if done else Pal.TEXT, not done)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	# The small bonus a tick pays (Todos.bonus_for): bright while it is to be
	# had, quiet once earned. The slot is always there (unseen when there is
	# nothing to say), so a row is as wide ticked as not and no words reflow.
	var claims = App.saved.claims
	var bonus = 0 if done else Todos.bonus_for(claims, str(t.id), App.today)
	var earned = done and Todos.paid(claims, str(t.id))
	var chip = Kit.tag("+%d XP" % Todos.BONUS_XP, Pal.ACCENT if bonus > 0 else Pal.PANEL2, bonus > 0, 10)
	chip.set_meta("todo_bonus", "open" if bonus > 0 else ("earned" if earned else "none"))
	if bonus <= 0 and not earned:
		chip.modulate.a = 0.0
	h.add_child(Kit.vcenter(chip))
	if on_remove.is_valid():
		var x = Kit.icon_button("close", on_remove, "Take it off the list", 30)
		x.set_meta("todo_remove", str(t.id))
		h.add_child(Kit.vcenter(x))
	c.add(h)
	return c


## The sound of a tap on an item and, when the tick pays, the bonus rising
## from its row. Called BEFORE the list changes: the row is rebuilt after it.
static func _tap_fx(row, id: String, done: bool) -> void:
	var xp = Todos.bonus_for(App.saved.claims, id, App.today) if done else 0
	if xp <= 0:
		Sfx.tick()
		return
	Sfx.claim()
	if row is Control and is_instance_valid(row):
		Kit.floater(row, "+%d XP" % xp, Pal.ACCENT)


static func _toggle(row, id: String, done: bool) -> void:
	if _busy():
		return
	_tap_fx(row, id, done)
	App.set_todo_done(id, done)


## The Hero tab's card: the open items (and the ones ticked today), a key to add.
static func card() -> Control:
	var list = App.todos()
	var shown = Todos.shown(list, App.today)
	var c = Kit.card(6, TodoView.open, 10)
	c.tooltip_text = "Your list of things to do. Ticking one off pays a small bonus."
	c.set_meta("todo_card", true)
	var head = Kit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Kit.vcenter(Icons.rect("check", 20)))
	var title = PixelFont.rect("TO DO", 2, Pal.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var n = Todos.open_count(list)
	if n > 0:
		head.add_child(Kit.vcenter(Kit.tag("%d open" % n, Pal.ACCENT, true, 11)))
	var add = Kit.icon_button("plus", TodoView.open, "Add to your list", 32)
	add.set_meta("todo_plus", true)
	head.add_child(Kit.vcenter(add))
	c.add(head)
	if list.is_empty():
		c.add(Kit.clip("Nothing on your list. Tap to add something.", 12, Pal.MUTED))
	elif shown.is_empty():
		c.add(Kit.clip("All ticked off.", 12, Pal.MUTED))
	else:
		for t in shown.slice(0, Todos.CARD_ROWS):
			c.add(_row(t, _toggle.bind(str(t.id), not bool(t.done))))
		if shown.size() > Todos.CARD_ROWS:
			c.add(Kit.clip("+%d more" % (shown.size() - Todos.CARD_ROWS), 11, Pal.MUTED))
	return c


## The sheet: the whole list, and the box to add to it.
static func open() -> void:
	Sfx.tap()
	var sh = Kit.sheet("To do")
	_fill(sh, {"text": ""})
	sh.open()


## (Re)build the sheet. `form` keeps what is being typed across a rebuild; the
## box to type in stays where it was on the screen.
static func _fill(sh, form: Dictionary, focus: bool = false) -> void:
	var before = null
	var old = sh.get_meta("form_row") if sh.has_meta("form_row") else null
	if old != null and is_instance_valid(old) and old.is_inside_tree():
		before = old.global_position.y
	for ch in sh.box.get_children():
		sh.box.remove_child(ch)
		ch.queue_free()
	var list = App.todos()
	if list.is_empty():
		sh.box.add_child(Kit.muted_para("A plain list for anything you need to do. It does not touch your training. Ticking one off pays a small bonus.", 13))
	for t in list:
		sh.box.add_child(_row(t, _toggle_in.bind(sh, form, str(t.id), not bool(t.done)), _remove_in.bind(sh, form, str(t.id)), true))
	# Always there, so ticking a first item does not push the rows about.
	var done_n = Todos.done_count(list)
	var status = Kit.hbox(8)
	var said = Kit.label("%d open · %d done" % [Todos.open_count(list), done_n], 12, Pal.MUTED, true)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(Kit.vcenter(said))
	var clear = Kit.link("Clear done", _clear_in.bind(sh, form))
	clear.disabled = done_n == 0
	clear.modulate.a = 1.0 if done_n > 0 else 0.35
	clear.set_meta("todo_clear", true)
	status.add_child(Kit.vcenter(clear))
	sh.box.add_child(status)
	# What a tick pays and how many are left today (always there, one line).
	var left = Todos.left_on(App.saved.claims, App.today)
	var pays = Kit.clip("+%d XP for each one ticked off · %s" % [Todos.BONUS_XP, ("%d of %d left today" % [left, Todos.BONUS_A_DAY]) if left > 0 else ("all %d used today" % Todos.BONUS_A_DAY)], 11, Pal.MUTED)
	pays.set_meta("todo_pays", true)
	sh.box.add_child(pays)
	# The box to type in, at the bottom: the sheet grows upward, so it stays put.
	var row = Kit.hbox(8)
	var input = Kit.input(str(form.text), "Something to do...")
	input.max_length = Todos.MAX_TEXT
	input.select_all_on_focus = false
	input.text_changed.connect(func(t): form.text = t)
	input.text_submitted.connect(func(_t): _add_in(sh, form))
	input.set_meta("todo_input", true)
	row.add_child(input)
	var add = Kit.button("Add", "primary", _add_in.bind(sh, form), "md")
	add.set_meta("todo_add", true)
	row.add_child(add)
	sh.set_meta("form_row", row)
	sh.box.add_child(row)
	var ok = Kit.button("Close", "ghost", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	if before != null:
		_keep_form(sh, row, float(before))
	# With a keyboard, go on typing the next one (a phone opens its keyboard only for a tap).
	if focus and not TouchScroll.active and not Kit.fingers:
		input.grab_focus.call_deferred()


## Once the sheet scrolls, an item added above the box would push it down:
## scroll by as much, so it stays under the finger.
static func _keep_form(sh, row: Control, before: float) -> void:
	await sh.get_tree().process_frame
	await sh.get_tree().process_frame
	if not is_instance_valid(sh) or sh._closing or not is_instance_valid(row):
		return
	var moved = row.global_position.y - before
	if absf(moved) >= 1.0:
		sh._scroll.scroll_vertical += int(round(moved))


static func _add_in(sh, form: Dictionary) -> void:
	if Todos.clean(str(form.text)) == "":
		return
	if App.add_todo(str(form.text)) == null:
		return
	Sfx.tick()
	form.text = ""
	_fill(sh, form, true)


static func _toggle_in(row, sh, form: Dictionary, id: String, done: bool) -> void:
	if _busy():
		return
	_tap_fx(row, id, done)
	App.set_todo_done(id, done)
	_fill(sh, form)


static func _remove_in(sh, form: Dictionary, id: String) -> void:
	if _busy():
		return
	Sfx.tick()
	App.remove_todo(id)
	_quiet_until = Time.get_ticks_msec() + QUIET_MS
	_fill(sh, form)


static func _clear_in(sh, form: Dictionary) -> void:
	if _busy():
		return
	var n = App.clear_done_todos()
	if n > 0:
		Sfx.tick()
		App.toast("%d done item%s cleared" % [n, "" if n == 1 else "s"], "info", "check")
		_quiet_until = Time.get_ticks_msec() + QUIET_MS
	_fill(sh, form)
