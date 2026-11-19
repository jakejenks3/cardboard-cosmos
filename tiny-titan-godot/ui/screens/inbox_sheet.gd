class_name InboxSheet
extends RefCounted
## "From your phone": the review sheet for what the phone inbox found
## (app/inbox.gd). One compact card per new entry with a toggle to leave it out
## and, for guessed dates, a day nudge; then the lines it could not read and
## the Import button. An entry read from a screenshot shows that picture and
## everything else found on it; a picture it could not use gets its own card
## saying why. A lift name that was not exactly one of the player's lifts gets
## a row under its entry: what it was taken as, and yes / no / another (see
## `_name_row`). Also the "Paste text" sheet and the shared check-then-review
## flow used by Settings and the Log picker.

## `result` as emitted by PhoneInbox.checked.
## ui: {sheet, button, fresh, answered: {name key: true} (lift names decided in
## this review: their rows stay, as answered), rows: {name key: its row}}.
static func open(result: Dictionary) -> void:
	var sheet = Kit.sheet("From your phone")
	var ui = {"button": null, "fresh": [], "sheet": sheet, "answered": {}, "rows": {}}
	_fill(ui, result)
	sheet.open()


## Everything inside the sheet. Runs again when a lift name is decided: the
## note is read again and the same cards come back with the new name.
static func _fill(ui: Dictionary, result: Dictionary) -> void:
	var sheet: Sheet = ui.sheet
	for old in sheet.box.get_children():
		sheet.box.remove_child(old)
		old.queue_free()
	var fresh = result.get("fresh", [])
	ui.fresh = fresh
	ui.button = null
	ui.rows = {}
	if fresh.is_empty():
		var none = Kit.vbox(8)
		var ic = Icons.rect("speech", 36)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		none.add_child(ic)
		none.add_child(JourneyScreen.caption("Nothing new in your phone note", 15, Pal.TEXT))
		sheet.box.add_child(none)
	for e in fresh:
		sheet.box.add_child(_entry_card(e, ui))

	var problems = []
	for pr in result.get("problems", []):
		if pr.has("picture"):
			sheet.box.add_child(_picture_card(pr))
		else:
			problems.append(pr)
	if not problems.is_empty():
		sheet.box.add_child(_unread_card(problems))
	var already = int(result.get("already", 0))
	if already > 0:
		var info = Kit.flow(6)
		info.add_child(_chip("check", "%d already imported" % already, Pal.PANEL2, ""))
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


## A small tag with an icon; the full text, if any, in the tooltip.
static func _chip(icon: String, text: String, color: Color, tip: String) -> PanelContainer:
	var shown = text if text.length() <= 40 else text.substr(0, 38) + "…"
	return Kit.icon_chip(icon, shown, color, tip, Pal.TEXT)


## One found entry: its discipline badge, the date (with a nudge for guessed
## dates), the summary as its one line, warnings as chips, and a tick box.
static func _entry_card(e: Dictionary, ui: Dictionary) -> Card:
	var c = Kit.card(6, Callable(), 10)
	var disc = "body" if e.kind == "body" else ("read" if e.kind == "reading" else str(e.data.discipline))
	if disc == "read":
		c.accent(Pal.READ)
	else:
		c.accent(Pal.disc(disc) if disc != "body" else Pal.SECOND)
	var row = Kit.hbox(10)
	if disc == "read":
		var rb = PanelContainer.new()
		rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rb.add_theme_stylebox_override("panel", PixBox.make(Pal.READ, {"lip": 1, "lip_color": Pal.READ_DARK, "pad_h": 0, "pad_v": 0}))
		rb.custom_minimum_size = Vector2(40, 42)
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rb.add_child(Kit.center(Icons.rect("book", 32)))
		row.add_child(rb)
	elif disc == "body":
		var bb = PanelContainer.new()
		bb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bb.add_theme_stylebox_override("panel", PixBox.make(Pal.SECOND, {"lip": 1, "lip_color": Pal.SECOND_DARK, "pad_h": 0, "pad_v": 0}))
		bb.custom_minimum_size = Vector2(40, 42)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bb.add_child(Kit.center(Icons.rect("scale", 24)))
		row.add_child(bb)
	else:
		row.add_child(Parts.session_badge(e.data, 40))
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
	var is_lift = e.kind == "session" and disc == "lift"
	if is_lift:
		# Its exercises are rows of their own, under this header.
		var n_ex = 0
		var n_sets = 0
		for ex in e.data.get("exercises", []):
			var done = SessionView.done_sets(ex).size()
			if done > 0:
				n_ex += 1
				n_sets += done
		main.add_child(Kit.clip("%d exercise%s · %d set%s" % [n_ex, "" if n_ex == 1 else "s", n_sets, "" if n_sets == 1 else "s"], 13, Pal.MUTED))
	else:
		main.add_child(Kit.para(str(e.summary), 13, Pal.TEXT))
	if e.kind == "body" and not e.data.get("photoRefs", []).is_empty():
		main.add_child(_thumbs(e.data.photoRefs))
	if not e.get("shots", []).is_empty():
		main.add_child(_from_picture(e, Pal.SECOND if disc == "body" else (Pal.READ if disc == "read" else Pal.disc(disc))))
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
	if is_lift:
		c.add(SessionView.lift_rows(e.data, {"pending": true, "skip_id": e.get("replaces")}))
	# Lift names that were not exactly a lift the player has.
	for pk in e.get("names", []):
		if str(pk.kind) != "exact" or ui.answered.has(str(pk.key)):
			c.add(_name_row(pk, ui))
	_style_toggle(e, toggle, c)
	return c


## One typed lift name the game was not sure about: what was written, what it
## is taken as, and up to three small keys: yes (it is that lift), no (it is a
## lift of its own), another (pick the lift). Once answered it shows the answer
## and keeps the "another" key. The row is the same height in every state, so
## answering one never moves the next one under the cursor.
static func _name_row(pk: Dictionary, ui: Dictionary) -> Control:
	var key = str(pk.key)
	var kind = str(pk.kind)
	var settled = ui.answered.has(key)
	var closest = str(pk.get("closest", ""))
	var asks = not settled and (kind == "match" or closest != "")
	var tone: Color = Pal.GOOD if settled else (Pal.disc("lift") if kind == "match" else Pal.ACCENT)
	var box = PanelContainer.new()
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_theme_stylebox_override("panel", PixBox.well(8, 5, tone))
	ui.rows[key] = box
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("check" if settled else ("repeat" if kind == "match" else "sparkle"), 16)))
	var words = Kit.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wrote = "\"%s\"" % str(pk.typed)
	var says = "= %s" % str(pk.name)
	if not settled:
		if kind == "match":
			says = "= %s?" % str(pk.name)
		else:
			wrote = "New lift · " + wrote
			if closest != "":
				says = "Same as %s?" % closest
	words.add_child(Kit.clip(wrote, 12, Pal.MUTED))
	var line = Kit.clip(says, 13, tone if settled or kind == "match" else Pal.TEXT, true)
	line.tooltip_text = says
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	words.add_child(line)
	row.add_child(words)
	if asks:
		var yes_lift = str(pk.name) if kind == "match" else closest
		row.add_child(Kit.vcenter(Kit.icon_button("check", InboxSheet._answer.bind(ui, pk, yes_lift), "Yes, it is %s" % yes_lift, 28)))
		row.add_child(Kit.vcenter(Kit.icon_button("close", InboxSheet._answer.bind(ui, pk, ""), "No, it is a lift of its own", 28)))
	row.add_child(Kit.vcenter(Kit.icon_button("edit", InboxSheet._pick_other.bind(ui, pk), "Pick another lift", 28)))
	box.add_child(row)
	return box


## The player said what a typed name is (`lift`; "" = a lift of its own): it is
## remembered, the note is read again, and the row shows the answer.
static func _answer(ui: Dictionary, pk: Dictionary, lift: String) -> void:
	Sfx.tick()
	ui.answered[str(pk.key)] = true
	App.inbox.name_lift(str(pk.key), lift)
	_refill(ui, str(pk.key))


## Where a name row is on screen (null when it is not there).
static func _row_top(ui: Dictionary, key: String):
	var c = ui.rows.get(key)
	if key == "" or c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return null
	return c.get_global_rect().position.y


## Read the note again and rebuild the cards in place. Ticks and moved dates
## stay as they were, and the row that was answered stays where it is.
static func _refill(ui: Dictionary, anchor: String = "") -> void:
	var sheet: Sheet = ui.sheet
	if not is_instance_valid(sheet) or sheet._closing:
		return
	var kept = {}
	for e in ui.fresh:
		kept[str(e.key)] = {"skip": bool(e.get("skip", false)), "date": str(e.date)}
	var before = _row_top(ui, anchor)
	var result = App.inbox.reparse()
	for e in result.get("fresh", []):
		var k = kept.get(str(e.key))
		if k == null:
			continue
		if k.skip:
			e["skip"] = true
		else:
			e.erase("skip")
		if str(k.date) != str(e.date):
			e.date = k.date
			e.data["date"] = k.date
	_fill(ui, result)
	if before == null:
		return
	await sheet.get_tree().process_frame
	await sheet.get_tree().process_frame
	if not is_instance_valid(sheet) or sheet._closing:
		return
	var after = _row_top(ui, anchor)
	if after != null:
		sheet._scroll.scroll_vertical += int(round(float(after) - float(before)))


## "Which lift is it?": the nearest lifts first, a search over the player's
## lifts and the library, a lift of its own, or any name typed into the box.
static func _pick_other(ui: Dictionary, pk: Dictionary) -> void:
	Sfx.tap()
	var s = Kit.sheet("Which lift is it?")
	s.box.add_child(Kit.para("You wrote \"%s\"." % str(pk.typed), 13, Pal.MUTED))
	var field = Kit.input("", "Search, or type a new name")
	field.select_all_on_focus = false
	s.box.add_child(field)
	var list = Kit.vbox(6)
	s.box.add_child(list)
	var opts = App.inbox.parse_opts()
	var state = {"rows": LiftLibrary.rows(App.sessions()), "known": opts.exercises, "own": opts.own}
	field.text_changed.connect(InboxSheet._pick_list.bind(list, ui, pk, s, state))
	_pick_list("", list, ui, pk, s, state)
	s.open()


## How many lifts the picker lists at once.
const PICK_SHOWN = 7


## The picker's list for what is in its search box (only the list is rebuilt,
## so typing keeps the box and its cursor).
static func _pick_list(text: String, list: VBoxContainer, ui: Dictionary, pk: Dictionary, s: Sheet, state: Dictionary) -> void:
	if not is_instance_valid(list):
		return
	for old in list.get_children():
		list.remove_child(old)
		old.queue_free()
	var by_name = {}
	for r in state.rows:
		for k in r.keys:
			by_name[str(k)] = r
	var q = text.strip_edges()
	var names = []
	for c in LiftMatch.find(q if q != "" else str(pk.typed), state.known, PICK_SHOWN if q != "" else 5):
		if float(c.score) >= 0.3:
			names.append(str(c.name))
	if q == "":
		# Nothing typed yet: after the nearest ones, the lifts done most recently.
		for n in state.own:
			if names.size() >= 5:
				break
			if not names.has(str(n)):
				names.append(str(n))
	else:
		for r in LiftLibrary.query(state.rows, {"q": q, "sort": "count"}):
			if names.size() >= PICK_SHOWN:
				break
			if not names.has(str(r.name)):
				names.append(str(r.name))
	var exact = false
	for n in names:
		if Xp.normalize_exercise(n) == Xp.normalize_exercise(q):
			exact = true
		list.add_child(_pick_row(n, by_name.get(Xp.normalize_exercise(n)), "", InboxSheet._picked.bind(ui, pk, s, n)))
	if q == "":
		list.add_child(_pick_row("Save as \"%s\"" % QuickLog.plain_name(str(pk.typed)), null, "A lift of its own", InboxSheet._picked.bind(ui, pk, s, "")))
	elif not exact:
		list.add_child(_pick_row("Name it \"%s\"" % q, null, "A lift of its own, under this name", InboxSheet._picked.bind(ui, pk, s, q)))


## One lift in the picker: its name, and what it is (body part and equipment
## for a library lift, how often it was done for one of the player's).
static func _pick_row(lift: String, lib, detail: String, on_tap: Callable) -> Card:
	var c = Kit.card(1, on_tap, 9)
	c.add(Kit.clip(lift, 14, null, true))
	var bits = []
	if detail != "":
		bits.append(detail)
	elif lib != null:
		if bool(lib.get("own", false)):
			bits.append("Your lift")
		else:
			bits.append(LiftLibrary.part_name(str(lib.part)))
			bits.append(LiftLibrary.equip_name(str(lib.equip)))
		if lib.get("st") != null:
			bits.append("done %d time%s" % [int(lib.st.count), "" if int(lib.st.count) == 1 else "s"])
	if not bits.is_empty():
		c.add(Kit.clip(" · ".join(PackedStringArray(bits)), 12, Pal.MUTED))
	return c


static func _picked(ui: Dictionary, pk: Dictionary, s: Sheet, lift: String) -> void:
	s.close()
	_answer(ui, pk, lift)


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


## A screenshot, small and phone-shaped.
static func _shot_thumb(tex: Texture2D) -> Control:
	var tile = PanelContainer.new()
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile.add_theme_stylebox_override("panel", PixBox.well(2, 2, Pal.BORDER))
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.tooltip_text = "The picture from your note"
	var img = TextureRect.new()
	img.texture = tex
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(40, 72)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(img)
	return tile


## For an entry read from a screenshot: the picture, a tag saying so, and the
## other numbers found on it (they are kept as the entry's note).
static func _from_picture(e: Dictionary, color: Color) -> Control:
	var row = Kit.hbox(8)
	for ref in e.shots:
		var tex = App.inbox.image_texture(str(ref))
		if tex != null:
			row.add_child(_shot_thumb(tex))
	var chips = Kit.flow(4)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_child(Kit.icon_chip("camera", "Read from a picture", color, "Everything here was read from the screenshot in your note"))
	for x in e.get("extras", []):
		chips.add_child(Kit.icon_chip("", str(x), Pal.PANEL2, "Also on the picture: kept as a note"))
	row.add_child(chips)
	return row


## A picture the game could not use, with the reason in words.
static func _picture_card(pr: Dictionary) -> Card:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.DANGER)
	var row = Kit.hbox(10)
	var tex = App.inbox.image_texture(str(pr.get("picture", "")))
	if tex != null:
		row.add_child(_shot_thumb(tex))
	else:
		row.add_child(Kit.vcenter(Icons.rect("warning", 24)))
	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(Kit.label("Picture left out" if tex != null else "Pictures not read", 14, null, true))
	var why = str(pr.get("why", ""))
	main.add_child(Kit.para(why.substr(0, 1).to_upper() + why.substr(1) + ".", 13, Pal.MUTED))
	row.add_child(main)
	c.add(row)
	return c


## How many unread lines the review shows before it says "and N more".
const UNREAD_SHOWN = 6


## The typed lines the game could not read, each with the reason in words and
## how to write it (the reason used to sit in a tooltip, so a line was just
## "not read" with no way to tell why).
static func _unread_card(problems: Array) -> Card:
	var c = Kit.card(8, Callable(), 10)
	c.accent(Pal.DANGER)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("warning", 16)))
	head.add_child(Kit.label("1 line not read" if problems.size() == 1 else "%d lines not read" % problems.size(), 14, null, true))
	c.add(head)
	for i in range(mini(problems.size(), UNREAD_SHOWN)):
		var pr: Dictionary = problems[i]
		var why = str(pr.get("why", "")).strip_edges()
		var one = Kit.vbox(1)
		one.add_child(Kit.clip("\"%s\"" % str(pr.get("line", "")), 13, Pal.TEXT, true))
		if why != "":
			one.add_child(Kit.para(why.substr(0, 1).to_upper() + why.substr(1) + ".", 12, Pal.MUTED))
		c.add(one)
	if problems.size() > UNREAD_SHOWN:
		c.add(Kit.label("and %d more" % (problems.size() - UNREAD_SHOWN), 12, Pal.MUTED))
	return c


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
