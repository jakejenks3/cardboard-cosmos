class_name InboxSheet
extends RefCounted
## "From your phone": the review sheet for what the phone inbox found
## (app/inbox.gd). One compact card per new entry with a toggle to leave it out
## and, for guessed dates, a day nudge; then the lines it could not read and
## the Import button. Also the "Paste text…" sheet and the shared
## check-then-review flow used by Settings and the Log picker.

const DISC_ICON = {"lift": "lift", "climb": "climb", "run": "run", "ride": "ride"}


## `result` as emitted by PhoneInbox.checked. `before_import` runs right before importing.
static func open(result: Dictionary) -> void:
	var sheet = Kit.sheet("From your phone")
	var fresh = result.get("fresh", [])
	var ui = {"button": null, "fresh": fresh, "sheet": sheet}
	if fresh.is_empty():
		sheet.box.add_child(Kit.muted_para("Nothing new in your phone note.", 14))
	for e in fresh:
		sheet.box.add_child(_entry_card(e, ui))

	var problems = result.get("problems", [])
	if not problems.is_empty():
		sheet.box.add_child(Kit.h3("Could not read"))
		var pl = Kit.vbox(4)
		for pr in problems:
			pl.add_child(Kit.muted_para("\"%s\": %s" % [str(pr.line), str(pr.why)], 12))
		sheet.box.add_child(pl)
	var already = int(result.get("already", 0))
	if already > 0:
		sheet.box.add_child(Kit.muted_para("%d already imported" % already, 12))

	var row = Kit.hbox(8)
	if not fresh.is_empty():
		var imp = Kit.button("Import", "primary", InboxSheet._import.bind(ui), "lg")
		imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.button = imp
		row.add_child(imp)
		_update_button(ui)
	var cancel = Kit.button("Cancel" if not fresh.is_empty() else "Close", "ghost", sheet.close, "lg")
	if fresh.is_empty():
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	sheet.box.add_child(row)
	sheet.open()


static func _entry_card(e: Dictionary, ui: Dictionary) -> Card:
	var c = Kit.card(6, Callable(), 12)
	var top = Kit.hbox(8)
	var disc = "body" if e.kind == "body" else str(e.data.discipline)
	top.add_child(Kit.vcenter(Icons.rect(DISC_ICON.get(disc, "scale"), 22)))
	var date_label = Kit.label(_date_text(e.date), 14, null, true)
	top.add_child(Kit.vcenter(date_label))
	if str(e.get("date_note", "")) != "":
		top.add_child(Kit.vcenter(Kit.icon_button("chevron_left", InboxSheet._nudge.bind(e, -1, date_label), "Day before", 28)))
		top.add_child(Kit.vcenter(Kit.icon_button("chevron_right", InboxSheet._nudge.bind(e, 1, date_label), "Day after", 28)))
	top.add_child(Kit.spacer())
	var toggle = Kit.chip("", false, Callable(), Pal.GOOD, 12)
	toggle.pressed.connect(InboxSheet._toggle.bind(e, toggle, c, ui))
	top.add_child(Kit.vcenter(toggle))
	c.add(top)
	if str(e.get("date_note", "")) != "":
		c.add(Kit.muted_para(str(e.date_note), 11))
	c.add(Kit.para(str(e.summary), 14))
	for w in e.get("warnings", []):
		c.add(Kit.para(str(w), 12, Pal.ACCENT))
	_style_toggle(e, toggle, c)
	return c


static func _date_text(key: String) -> String:
	return Dates.format_date(key, {"weekday": "short", "month": "short", "day": "numeric"})


static func _nudge(e: Dictionary, days: int, label: Label) -> void:
	var d = Dates.add_days(str(e.date), days)
	if d > Dates.today_key():
		Sfx.error()
		return
	Sfx.tick()
	e.date = d
	e.data["date"] = d
	if is_instance_valid(label):
		label.text = _date_text(d)


static func _toggle(e: Dictionary, toggle: Button, c: Card, ui: Dictionary) -> void:
	Sfx.tick()
	e["skip"] = not bool(e.get("skip", false))
	_style_toggle(e, toggle, c)
	_update_button(ui)


static func _style_toggle(e: Dictionary, toggle: Button, c: Card) -> void:
	var on = not bool(e.get("skip", false))
	toggle.text = "Import" if on else "Leave out"
	Kit.style_chip(toggle, on, Pal.GOOD, 12)
	c.modulate.a = 1.0 if on else 0.55


static func _chosen(ui: Dictionary) -> Array:
	return ui.fresh.filter(func(e): return not bool(e.get("skip", false)))


static func _update_button(ui: Dictionary) -> void:
	var n = _chosen(ui).size()
	if ui.button != null and is_instance_valid(ui.button):
		ui.button.text = "Import %d entr%s" % [n, "y" if n == 1 else "ies"]
		ui.button.disabled = n == 0


static func _import(ui: Dictionary) -> void:
	var chosen = _chosen(ui)
	if chosen.is_empty():
		return
	Sfx.tap()
	ui.sheet.close()
	App.inbox.import_entries(chosen)


## Check the note, then open the review (or toast what happened). With no source
## set, Settings opens instead. `before_open` runs before the review sheet opens.
static func check_and_review(before_open: Callable = Callable()) -> void:
	if str(App.inbox.settings().get("source", "")).strip_edges() == "":
		App.toast("Add the link to your phone note first", "info")
		SettingsSheet.open()
		return
	if App.inbox.busy():
		return
	App.toast("Checking your phone note…", "info")
	App.inbox.checked.connect(InboxSheet._after_check.bind(before_open), CONNECT_ONE_SHOT)
	App.inbox.check(false)


static func _after_check(result: Dictionary, before_open: Callable) -> void:
	if not result.ok:
		Sfx.error()
		App.toast(str(result.error), "bad", "warning")
		return
	if result.fresh.is_empty() and result.problems.is_empty():
		App.toast("Nothing new" + ((" (%d already imported)" % result.already) if result.already > 0 else ""), "info")
		return
	if before_open.is_valid():
		before_open.call()
	InboxSheet.open(result)


## Open the review for what the last check found (Home card).
static func open_pending() -> void:
	Sfx.tap()
	InboxSheet.open(App.inbox.last_result())


## A sheet to paste text into (for when there is no shared note).
static func open_paste(before_open: Callable = Callable()) -> void:
	var sheet = Kit.sheet("Paste text")
	sheet.box.add_child(Kit.muted_para("Paste what you jotted down, one thing per line.", 13))
	var te = TextEdit.new()
	te.custom_minimum_size = Vector2(0, 220)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.placeholder_text = QuickLog.CHEAT_SHEET
	te.add_theme_stylebox_override("normal", Kit.sbox(Pal.WELL, 12, Pal.LINE, 1, 12, 10))
	te.add_theme_stylebox_override("focus", Kit.sbox(Pal.WELL, 12, Pal.ACCENT, 1, 12, 10))
	te.add_theme_color_override("font_color", Pal.TEXT)
	te.add_theme_color_override("font_placeholder_color", Pal.MUTED)
	sheet.box.add_child(te)
	var read = Kit.button("Read it", "primary", InboxSheet._read_pasted.bind(te, sheet, before_open), "lg")
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.box.add_child(read)
	sheet.open()


static func _read_pasted(te: TextEdit, sheet: Sheet, before_open: Callable) -> void:
	if te.text.strip_edges() == "":
		Sfx.error()
		return
	Sfx.tap()
	var result = App.inbox.check_text(te.text)
	sheet.close()
	if before_open.is_valid():
		before_open.call()
	InboxSheet.open(result)
