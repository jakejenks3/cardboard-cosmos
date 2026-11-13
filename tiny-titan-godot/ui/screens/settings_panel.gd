class_name SettingsPanel
extends VBoxContainer
## Contents of the Settings sheet (see settings.gd). Rebuilds itself after a
## picker changes; the name field is left alone while typing.

var sheet: Sheet = null


var _pending_name = null

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func fill() -> void:
	Kit.clear(self)
	var p = App.profile()
	var st = App.settings()

	# --- hero -------------------------------------------------------------------
	add_child(Kit.h3("Hero"))
	if p != null:
		var row = Kit.hbox(14)
		var pic = PixelRect.make(Art.hero_texture(App.state, p, App.loadout()), 1.0)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		var name_edit = Kit.input(p.get("name", ""), "Hero name")
		name_edit.max_length = 20
		name_edit.text_changed.connect(_on_name)
		row.add_child(Kit.field("Name", name_edit))
		add_child(row)
		add_child(Parts.appearance_editor(int(p.get("skin", 0)), int(p.get("hairStyle", 0)), int(p.get("hairColor", 0)), _on_look))

	# --- units --------------------------------------------------------------------
	add_child(Kit.h3("Units & training"))
	var units = Kit.hbox(12)
	units.add_child(Kit.field("Weight", Kit.segmented([{"value": "kg", "label": "kg"}, {"value": "lb", "label": "lb"}], st.get("weightUnit", "kg"), _on_weight_unit)))
	units.add_child(Kit.field("Distance", Kit.segmented([{"value": "km", "label": "km"}, {"value": "mi", "label": "mi"}], st.get("distanceUnit", "km"), _on_setting.bind("distanceUnit"))))
	add_child(units)

	var unit = str(st.get("weightUnit", "kg"))
	var step_opts = []
	for s in TT.WEIGHT_STEPS[unit]:
		step_opts.append({"value": float(s), "label": "%s %s" % [TTUtil.num_str(s), unit]})
	add_child(Kit.field("Weight step (one − / + tap)", Kit.segmented(step_opts, float(TT.weight_step_of(st)), _on_setting.bind("weightStep"))))

	var goal_opts = []
	for n in range(2, 7):
		goal_opts.append({"value": n, "label": str(n)})
	add_child(Kit.field("Weekly goal (sessions per week for streaks)", Kit.segmented(goal_opts, int(st.get("weeklyGoal", 3)), _on_setting.bind("weeklyGoal"))))

	var sound_opts = [{"value": true, "label": "On"}, {"value": false, "label": "Off"}]
	add_child(Kit.field("Sound effects", Kit.segmented(sound_opts, bool(st.get("sound", true)), _on_sound)))

	# --- data ---------------------------------------------------------------------
	add_child(Kit.h3("Data"))
	var photos = App.referenced_photo_ids().size()
	var what = "your sessions, check-ins and all %d progress photos" % photos if photos > 0 else "your sessions and check-ins"
	add_child(Kit.muted_para("Backups include %s. Photos never leave this computer." % what, 13))
	var btns = Kit.flow(8)
	btns.add_child(Kit.button("Export backup", "secondary", SettingsPanel.pick_export))
	btns.add_child(Kit.button("Import backup", "secondary", SettingsPanel.pick_import.bind(sheet)))
	btns.add_child(Kit.button("Reset", "danger", SettingsPanel.ask_reset.bind(sheet)))
	add_child(btns)
	add_child(Kit.expand(Kit.button("Open data folder", "ghost", _open_folder, "md", "book")))
	add_child(Kit.muted_para("Your save lives in %s. A dated copy is kept there automatically each day." % ProjectSettings.globalize_path(App.DATA_DIR), 11))


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


func _on_look(patch: Dictionary) -> void:
	Sfx.tap()
	App.update_profile(patch)
	call_deferred("_refill")


func _on_setting(value, key: String) -> void:
	Sfx.tick()
	App.update_settings({key: value})
	call_deferred("_refill")


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
