class_name InboxSheet
extends RefCounted
## "From your phone": the review sheet for what the phone inbox found
## (app/inbox.gd). One compact card per new entry with a toggle to leave it out
## and, for guessed dates, a day nudge; then the lines it could not read and
## the Import button. Also the "Paste text" sheet and the shared
## check-then-review flow used by Settings and the Log picker.

## `result` as emitted by PhoneInbox.checked. `before_import` runs right before importing.
static func open(result: Dictionary) -> void:
	var sheet = Kit.sheet("From your phone")
	var fresh = result.get("fresh", [])
	var ui = {"button": null, "fresh": fresh, "sheet": sheet}
	if fresh.is_empty():
		var none = Kit.vbox(8)
		var ic = Icons.rect("speech", 36)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		none.add_child(ic)
		none.add_child(JourneyScreen.caption("Nothing new in your phone note", 15, Pal.TEXT))
		sheet.box.add_child(none)
	for e in fresh:
		sheet.box.add_child(_entry_card(e, ui))

	var problems = result.get("problems", [])
	var already = int(result.get("already", 0))
	if not problems.is_empty() or already > 0:
		var info = Kit.flow(6)
		if already > 0:
			info.add_child(_chip("check", "%d already imported" % already, Pal.PANEL2, ""))
		for pr in problems:
			info.add_child(_chip("warning", "\"%s\"" % str(pr.line), Pal.deep(Pal.DANGER), "Could not read: %s" % str(pr.why)))
		sheet.box.add_child(info)

	var row = Kit.hbox(8)
	if not fresh.is_empty():
		var imp = Kit.button("Import", "good", InboxSheet._import.bind(ui), "lg")
		imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		imp.custom_minimum_size.y = 56
		ui.button = imp
		row.add_child(imp)
		_update_button(ui)
	var cancel = Kit.button("Cancel" if not fresh.is_empty() else "Close", "ghost", sheet.close, "lg")
	if fresh.is_empty():
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		cancel.custom_minimum_size.y = 56
	row.add_child(cancel)
	sheet.box.add_child(row)
	sheet.open()


## A small tag with an icon; the full text, if any, in the tooltip.
static func _chip(icon: String, text: String, color: Color, tip: String) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(color, 5, Pal.LINE if color == Pal.PANEL2 else null, 1 if color == Pal.PANEL2 else 0, 7, 3))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	var h = Kit.hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect(icon, 14)))
	var shown = text if text.length() <= 40 else text.substr(0, 38) + "…"
	h.add_child(Kit.label(shown, 12, Pal.TEXT, true))
	p.add_child(h)
	return p


## One found entry: its discipline badge, the date (with a nudge for guessed
## dates), the summary as its one line, warnings as chips, and a tick box.
static func _entry_card(e: Dictionary, ui: Dictionary) -> Card:
	var c = Kit.card(6, Callable(), 10)
	var disc = "body" if e.kind == "body" else str(e.data.discipline)
	c.accent(Pal.disc(disc) if disc != "body" else Pal.SECOND)
	var row = Kit.hbox(10)
	if disc == "body":
		var bb = PanelContainer.new()
		bb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bb.add_theme_stylebox_override("panel", PixBox.make(Pal.SECOND, {"lip": 1, "lip_color": Pal.SECOND_DARK, "pad_h": 0, "pad_v": 0}))
		bb.custom_minimum_size = Vector2(40, 42)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bb.add_child(Kit.center(Icons.rect("scale", 24)))
		row.add_child(bb)
	else:
		row.add_child(Parts.disc_badge(disc, 40))
	var main = Kit.vbox(4)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top = Kit.hbox(6)
	var date_label = Kit.label(_date_text(e.date), 14, null, true)
	if str(e.get("date_note", "")) != "":
		date_label.tooltip_text = str(e.date_note)
		date_label.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(Kit.vcenter(date_label))
	if str(e.get("date_note", "")) != "":
		top.add_child(Kit.vcenter(Kit.icon_button("chevron_left", InboxSheet._nudge.bind(e, -1, date_label), "Day before", 28)))
		top.add_child(Kit.vcenter(Kit.icon_button("chevron_right", InboxSheet._nudge.bind(e, 1, date_label), "Day after", 28)))
	main.add_child(top)
	main.add_child(Kit.para(str(e.summary), 13, Pal.TEXT))
	if e.kind == "body" and not e.data.get("photoRefs", []).is_empty():
		main.add_child(_thumbs(e.data.photoRefs))
	var warns = e.get("warnings", [])
	if not warns.is_empty():
		var wf = Kit.flow(4)
		for w in warns:
			if str(w) == PhoneInbox.UPDATES:
				wf.add_child(_chip("edit", "Updates the one already imported", Pal.deep(Pal.ACCENT2), "This day changed in your note after it was imported: importing replaces that entry with this one"))
			else:
				wf.add_child(_chip("warning", _short(str(w)), Pal.deep(Pal.ACCENT), str(w)))
		main.add_child(wf)
	row.add_child(main)
	var toggle = Button.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.custom_minimum_size = Vector2(40, 42)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle.pressed.connect(InboxSheet._toggle.bind(e, toggle, c, ui))
	Kit.juice(toggle)
	row.add_child(toggle)
	c.add(row)
	_style_toggle(e, toggle, c)
	return c


## The pictures found under this day, small, in the order they are kept (front, side, back).
static func _thumbs(refs: Array) -> Control:
	var row = Kit.hbox(8)
	for i in range(refs.size()):
		var tex = App.inbox.image_texture(str(refs[i]))
		if tex == null or i >= TT.PHOTO_ANGLES.size():
			continue
		var col = Kit.vbox(2)
		var tile = PanelContainer.new()
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile.add_theme_stylebox_override("panel", PixBox.well(2, 2, Pal.BORDER))
		var img = TextureRect.new()
		img.texture = tex
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(56, 72)
		tile.add_child(img)
		col.add_child(tile)
		var name = Kit.label(TT.PHOTO_ANGLE_NAMES[TT.PHOTO_ANGLES[i]], 11, Pal.MUTED, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name)
		row.add_child(col)
	return row


## The first clause of a warning, for its chip.
static func _short(w: String) -> String:
	var t = w.split(";")[0].split("(")[0].strip_edges()
	return t if t != "" else w


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


## The tick box: raised and green with a tick when the entry is in, sunken and
## empty when it is left out (the card fades too).
static func _style_toggle(e: Dictionary, toggle: Button, c: Card) -> void:
	var on = not bool(e.get("skip", false))
	toggle.tooltip_text = "Included: tap to leave it out" if on else "Left out: tap to include it"
	var looks
	if on:
		looks = PixBox.button_set(Pal.GOOD, Pal.GOOD_DARK, 4, 4, 1, null)
	else:
		looks = {"normal": PixBox.well(4, 4, Pal.BORDER), "hover": PixBox.well(4, 4, Pal.ACCENT), "pressed": PixBox.well(4, 4, Pal.BORDER)}
	for k in ["normal", "hover", "pressed"]:
		toggle.add_theme_stylebox_override(k, looks[k])
	toggle.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	toggle.icon = Icons.tex("check") if on else null
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
	var te = TextEdit.new()
	te.custom_minimum_size = Vector2(0, 220)
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.placeholder_text = QuickLog.CHEAT_SHEET
	te.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	te.tooltip_text = "One thing per line"
	te.add_theme_stylebox_override("normal", PixBox.well(12, 10))
	te.add_theme_stylebox_override("focus", PixBox.well(12, 10, Pal.ACCENT))
	te.add_theme_color_override("font_color", Pal.TEXT)
	te.add_theme_color_override("font_placeholder_color", Pal.MUTED)
	sheet.box.add_child(te)
	var read = Kit.button("Read it", "primary", InboxSheet._read_pasted.bind(te, sheet, before_open), "lg", "check")
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
