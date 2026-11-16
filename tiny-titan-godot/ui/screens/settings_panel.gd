class_name SettingsPanel
extends VBoxContainer
## Contents of the Settings sheet (see settings.gd). Rebuilds itself after a
## picker changes; the name field is left alone while typing.

var sheet: Sheet = null


var _pending_name = null
var _pending_source = null

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func fill() -> void:
	# A name still being typed is saved first, so the rebuilt field shows it.
	if _pending_name != null:
		_commit_name(_pending_name)
	if _pending_source != null:
		_commit_source(_pending_source)
	Kit.clear(self)
	var p = App.profile()
	var st = App.settings()

	# --- look ---------------------------------------------------------------------
	add_child(Kit.section_title("Theme"))
	var themes = Kit.grid(Pal.THEME_ORDER.size(), 8)
	for id in Pal.THEME_ORDER:
		themes.add_child(_theme_tile(id))
	add_child(themes)

	# --- hero -------------------------------------------------------------------
	if p != null:
		var hero = _card("HERO")
		var row = Kit.hbox(14)
		var pic = PixelRect.make(Art.hero_texture(App.state, p, App.loadout()), 2.0)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		var right = Kit.vbox(10)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_edit = Kit.input(p.get("name", ""), "Hero name")
		name_edit.max_length = 20
		name_edit.tooltip_text = "Hero name"
		name_edit.text_changed.connect(_on_name)
		right.add_child(name_edit)
		right.add_child(Parts.appearance_editor(int(p.get("skin", 0)), int(p.get("hairStyle", 0)), int(p.get("hairColor", 0)), _on_look))
		row.add_child(right)
		hero.add(row)
		add_child(hero)

	# --- units & training ------------------------------------------------------------
	var train = _card("TRAINING")
	train.add(_row("scale", "Weight", Kit.segmented([{"value": "kg", "label": "kg"}, {"value": "lb", "label": "lb"}], st.get("weightUnit", "kg"), _on_weight_unit)))
	train.add(_row("road", "Distance", Kit.segmented([{"value": "km", "label": "km"}, {"value": "mi", "label": "mi"}], st.get("distanceUnit", "km"), _on_setting.bind("distanceUnit"))))
	var unit = str(st.get("weightUnit", "kg"))
	var step_opts = []
	for s in TT.WEIGHT_STEPS[unit]:
		step_opts.append({"value": float(s), "label": "%s %s" % [TTUtil.num_str(s), unit]})
	var step_row = _row("plus", "Step", Kit.segmented(step_opts, float(TT.weight_step_of(st)), _on_setting.bind("weightStep")))
	step_row.tooltip_text = "How much one − / + tap changes a weight"
	train.add(step_row)
	var goal_opts = []
	for n in range(2, 7):
		goal_opts.append({"value": n, "label": str(n)})
	var goal_row = _row("flame", "Weekly goal", Kit.segmented(goal_opts, int(st.get("weeklyGoal", 3)), _on_setting.bind("weeklyGoal")))
	goal_row.tooltip_text = "Sessions per week that keep your streak alive"
	train.add(goal_row)
	var snd = bool(st.get("sound", true))
	train.add(_row("sound_on" if snd else "sound_off", "Sound", Kit.switch(snd, _on_sound, "Sound effects")))
	add_child(train)

	# --- phone inbox ----------------------------------------------------------------
	_build_inbox()

	# --- data ---------------------------------------------------------------------
	var photos = App.referenced_photo_ids().size()
	var what = "your sessions, check-ins and all %d progress photos" % photos if photos > 0 else "your sessions and check-ins"
	var data = _card("DATA", _info_button("About your data", [
		"Backups include %s." % what,
		"Photos never leave this computer.",
		"Your save lives in %s. A dated copy is kept there automatically each day." % ProjectSettings.globalize_path(App.DATA_DIR),
	]))
	var btns = Kit.hbox(8)
	btns.add_child(Kit.expand(Kit.button("Export backup", "secondary", SettingsPanel.pick_export, "md", "chest")))
	btns.add_child(Kit.expand(Kit.button("Import backup", "secondary", SettingsPanel.pick_import.bind(sheet), "md", "arrow_down")))
	data.add(btns)
	var btns2 = Kit.hbox(8)
	btns2.add_child(Kit.expand(Kit.button("Open data folder", "ghost", _open_folder, "md", "book")))
	btns2.add_child(Kit.button("Reset", "danger", SettingsPanel.ask_reset.bind(sheet)))
	data.add(btns2)
	add_child(data)


## A settings card with a pixel-font heading and an optional control on the right.
func _card(title: String, right: Control = null) -> Card:
	var c = Kit.card(12, Callable(), 12)
	var h = Kit.hbox(8)
	h.custom_minimum_size = Vector2(0, 26)
	var t = PixelFont.rect(title, 2, Pal.ACCENT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	h.add_child(Kit.spacer())
	if right != null:
		h.add_child(Kit.vcenter(right))
	c.add(h)
	return c


## icon · label · control, on one line.
func _row(icon: String, label_text: String, control: Control) -> HBoxContainer:
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(Kit.vcenter(Icons.rect(icon, 20)))
	var l = Kit.label(label_text, 14, null, true)
	l.custom_minimum_size = Vector2(92, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if control.size_flags_horizontal != Control.SIZE_SHRINK_END:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		h.add_child(Kit.spacer())
	h.add_child(control)
	return h


## A small "i" button that opens a sheet with the explanation.
func _info_button(title: String, lines: Array) -> Button:
	return Kit.icon_button("info", SettingsPanel.show_info.bind(title, lines), title, 32)


## A sheet with a few short paragraphs (help text kept out of the way).
static func show_info(title: String, lines: Array, extra: Control = null) -> void:
	var sh = Kit.sheet(title)
	for l in lines:
		sh.box.add_child(Kit.para(str(l), 14, Pal.TEXT))
	if extra != null:
		sh.box.add_child(extra)
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()


func _refill() -> void:
	if is_instance_valid(self) and is_inside_tree():
		fill()


func _on_name(t: String) -> void:
	# Save once typing pauses, not on every key: each save re-derives the whole log.
	_pending_name = t
	get_tree().create_timer(0.6).timeout.connect(_commit_name.bind(t))


func _commit_name(t: String) -> void:
	if _pending_name == null or _pending_name != t:
		return
	_pending_name = null
	var clean = t.strip_edges()
	if clean == "" or App.profile() == null or clean == App.profile().name:
		return
	App.update_profile({"name": clean})


func _exit_tree() -> void:
	# The sheet was closed mid-typing: keep what was typed.
	if _pending_name != null:
		_commit_name(_pending_name)
	if _pending_source != null:
		_commit_source(_pending_source)


# ---------------------------------------------------------------------------
# Phone inbox (app/inbox.gd): workouts jotted in a note on the phone
# ---------------------------------------------------------------------------

func _build_inbox() -> void:
	var ib = App.inbox.settings()
	var card = _card("PHONE INBOX", Kit.button("How it works", "ghost", SettingsPanel.show_how, "sm"))
	card.set_meta("inbox_section", true)
	var src = Kit.input(str(ib.get("source", "")), "Google Doc link or a file path")
	src.select_all_on_focus = false
	src.tooltip_text = "Link or file"
	src.text_changed.connect(_on_source)
	card.add(src)
	var check = Kit.button("Check now", "primary", _check_now, "lg", "repeat")
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add(check)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Kit.expand(Kit.button("Paste text", "secondary", InboxSheet.open_paste.bind(_close_sheet), "md", "edit"))))
	row.add_child(Kit.gap(4))
	var auto_label = Kit.label("Auto-check", 14, null, true)
	auto_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(auto_label)
	row.add_child(Kit.switch(bool(ib.get("auto", true)), _on_inbox_auto, "Check when the game starts"))
	card.add(row)
	var line = App.inbox.status
	if line == "":
		line = App.inbox.last_checked_text()
	if line == "":
		line = "Not checked yet"
	var status = Kit.hbox(6)
	status.add_child(Kit.vcenter(Icons.rect("clock", 16)))
	status.add_child(Kit.clip(line, 12, Pal.MUTED))
	card.add(status)
	add_child(card)


## "How it works" for the phone inbox, in its own sheet.
static func show_how() -> void:
	var cheat = PanelContainer.new()
	cheat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cheat.add_theme_stylebox_override("panel", PixBox.well(12, 10))
	cheat.add_child(Kit.para(QuickLog.CHEAT_SHEET, 13, Pal.TEXT))
	var v = Kit.vbox(10)
	v.add_child(cheat)
	v.add_child(Kit.para("4. Press Check now, or just start the game. Nothing is imported until you say so; lines it cannot read are shown, never dropped.", 14, Pal.TEXT))
	if Ocr.available():
		var shots = Kit.hbox(8)
		var cam = Icons.rect("camera", 20)
		cam.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		shots.add_child(cam)
		var words = Kit.para("Screenshots work too. Paste a Strava run, ride or walk, or your scale app's weigh-in screen, into the Doc: the game reads the numbers off the picture. A walk comes in as a weighted vest walk; write \"vest 20\" under it for the weight. Any other picture is kept as a progress photo.", 14, Pal.TEXT)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shots.add_child(words)
		v.add_child(shots)
	v.add_child(Kit.muted_para("A Google Form's responses sheet or a file in a synced folder works too. Anyone with the link can read the note, so keep it to workouts.", 12))
	SettingsPanel.show_info("How it works", [
		"1. Make a Google Doc on your phone.",
		"2. Share → General access → Anyone with the link (Viewer), and paste the link here.",
		"3. Write what you did, one thing per line, a date line to start a day:",
	], v)


func _on_source(t: String) -> void:
	_pending_source = t
	get_tree().create_timer(0.6).timeout.connect(_commit_source.bind(t))


func _commit_source(t: String) -> void:
	if _pending_source == null or _pending_source != t:
		return
	_pending_source = null
	App.inbox.set_source(t)


func _on_inbox_auto(on) -> void:
	Sfx.tick()
	App.inbox.set_auto(bool(on))
	call_deferred("_refill")


func _check_now() -> void:
	Sfx.tap()
	if _pending_source != null:
		_commit_source(_pending_source)
	if str(App.inbox.settings().get("source", "")).strip_edges() == "":
		App.toast("Paste the link to your phone note first", "info")
		return
	App.inbox.checked.connect(_on_checked_here, CONNECT_ONE_SHOT)
	InboxSheet.check_and_review(_close_sheet)


func _on_checked_here(_result) -> void:
	call_deferred("_refill")


## The review sheet and the results reel need the room: close Settings first.
func _close_sheet() -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.close()


func _on_look(patch: Dictionary) -> void:
	Sfx.tap()
	App.update_profile(patch)
	call_deferred("_refill")


func _on_setting(value, key: String) -> void:
	Sfx.tick()
	App.update_settings({key: value})
	call_deferred("_refill")


## A swatch of a theme: its world colour with a panel and the accent on it.
func _theme_tile(id: String) -> Button:
	var th = Pal.THEMES[id]
	var on = id == Pal.theme_id
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(60, 64)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = th.name
	var looks = PixBox.button_set(Color(th.bg), Color(th.outline), 6, 6, 1, Pal.ACCENT if on else Color(th.border))
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v = Kit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -12
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = Kit.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for key in ["panel2", "accent", "second"]:
		var sw = ColorRect.new()
		sw.color = Color(th[key])
		sw.custom_minimum_size = Vector2(12, 12)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
	v.add_child(row)
	var l = Kit.label(th.name, 12, Color(th.text), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(_on_theme.bind(id))
	Kit.juice(b)
	return b


func _on_theme(id: String) -> void:
	if id == Pal.theme_id:
		return
	Sfx.claim()
	# The shell rebuilds itself in the new colours and reopens this sheet.
	App.update_settings({"theme": id})


func _on_sound(on) -> void:
	App.update_settings({"sound": bool(on)})
	Sfx.tick()
	call_deferred("_refill")


## Switching units keeps the weight step when it exists for the new unit,
## otherwise falls back to that unit's default (2.5 kg / 5 lb).
func _on_weight_unit(unit) -> void:
	Sfx.tick()
	App.update_settings(SettingsPanel.unit_patch(App.settings(), str(unit)))
	call_deferred("_refill")


static func unit_patch(st: Dictionary, unit: String) -> Dictionary:
	var patch = {"weightUnit": unit}
	var cur = st.get("weightStep")
	if cur == null or not TTUtil.has_number(TT.WEIGHT_STEPS[unit], cur):
		patch["weightStep"] = 2.5 if unit == "kg" else 5
	return patch


func _open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(App.DATA_DIR))


# ---------------------------------------------------------------------------
# Backups (static: the dialogs can outlive the sheet)
# ---------------------------------------------------------------------------

static func _dialog(mode: int) -> FileDialog:
	var dlg = FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.use_native_dialog = true
	dlg.file_mode = mode
	dlg.filters = PackedStringArray(["*.json ; Tiny Titan backup"])
	dlg.canceled.connect(dlg.queue_free)
	var host = Kit.overlay_root
	if host == null:
		host = (Engine.get_main_loop() as SceneTree).root
	host.add_child(dlg)
	return dlg


static func pick_export() -> void:
	var dlg = SettingsPanel._dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dlg.title = "Export backup"
	dlg.current_file = "tiny-titan-backup-%s.json" % App.today
	dlg.file_selected.connect(SettingsPanel._export_to.bind(dlg))
	dlg.popup_centered_ratio(0.8)


static func _export_to(path: String, dlg: FileDialog) -> void:
	if is_instance_valid(dlg):
		dlg.queue_free()
	var err = App.export_backup(path)
	if err == "":
		App.toast("Backup saved", "good", "chest")
	else:
		App.toast("Export failed: %s" % err, "bad", "warning")


static func pick_import(sh) -> void:
	var dlg = SettingsPanel._dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dlg.title = "Import backup"
	dlg.file_selected.connect(SettingsPanel._import_from.bind(dlg, sh))
	dlg.popup_centered_ratio(0.8)


static func _import_from(path: String, dlg, sh) -> void:
	if is_instance_valid(dlg):
		dlg.queue_free()
	SettingsPanel.confirm_import(path, sh)


## Read a backup and ask before replacing the current data.
static func confirm_import(path: String, sh = null) -> void:
	var result = App.read_backup(path)
	if not result.ok:
		App.toast("Import failed: %s" % result.error, "bad", "warning")
		return
	var body = "Import %d sessions and %d check-ins? This replaces your current data." % [result.sessions, result.body]
	Kit.confirm("Import backup", body, "Import", SettingsPanel.do_import.bind(result, sh))


static func do_import(result: Dictionary, sh = null) -> void:
	var n = App.apply_backup(result)
	App.toast("Backup imported" + (" with %d photos" % n if n > 0 else ""), "good", "chest")
	if sh != null and is_instance_valid(sh):
		sh.close()


static func ask_reset(sh = null) -> void:
	Kit.confirm("Reset everything?", "This deletes all sessions, check-ins, gear and pets.", "Reset", SettingsPanel._ask_reset_again.bind(sh))


static func _ask_reset_again(sh = null) -> void:
	Kit.confirm("Really?", "There is no undo.", "Delete everything", SettingsPanel._do_reset.bind(sh))


static func _do_reset(sh = null) -> void:
	App.reset_all()
	if sh != null and is_instance_valid(sh):
		sh.close()
