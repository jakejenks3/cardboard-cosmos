class_name LogBodyForm
extends RefCounted
## Body check-in form (new or editing): weight stepper that starts from your
## last weigh-in, body fat, front / side / back photos, note, date.
##
## Photos are copied into the game as soon as they are picked
## (App.import_photo); files nobody refers to are pruned by App on the next
## body update / delete.

const ANGLE_HINT = {"front": "Facing the camera", "side": "Turned 90°", "back": "Facing away"}

var screen = null  # LogScreen
var editing = null
var wu: String = "kg"
var date: String = ""
var weight: String = ""
var bf: String = ""
var note: String = ""
var photos: Dictionary = {}  # angle -> photo id
var last_weight = null  # in the display unit, or null

# Live controls of the current build.
var _weight_hint: Label = null
var _bf_hint: Label = null
var _xp_box: VBoxContainer = null
var _xp_card: Card = null
var _save_btn: Button = null
var _dialog = null


func _init(owner_screen, entry = null) -> void:
	screen = owner_screen
	editing = entry
	wu = App.weight_unit()
	var lw = App.state.body.latestWeightKg
	if lw != null:
		last_weight = TTUtil.jsround(Fmt.kg_to_unit(float(lw), wu) * 10.0) / 10.0
	date = str(entry.date) if entry != null else App.today
	if entry != null:
		var w = float(TTUtil.get_or(entry, "weightKg", 0))
		weight = LogWidgets.trim_num(Fmt.kg_to_unit(w, wu), 1) if w > 0.0 else ""
		var f = float(TTUtil.get_or(entry, "bodyFatPct", 0))
		bf = TTUtil.num_str(f) if f > 0.0 else ""
		note = str(TTUtil.get_or(entry, "note", ""))
		var ph = entry.get("photos")
		if ph is Dictionary:
			for a in TT.PHOTO_ANGLES:
				if ph.get(a) != null and str(ph[a]) != "":
					photos[a] = str(ph[a])


# ---------------------------------------------------------------------------
# Draft
# ---------------------------------------------------------------------------

func weight_kg():
	var w = LogWidgets.num(weight)
	return TTUtil.jsround(Fmt.unit_to_kg(w, wu) * 100.0) / 100.0 if w > 0.0 else null


func body_fat():
	var f = LogWidgets.num(bf)
	return TTUtil.jsround(f * 10.0) / 10.0 if f > 0.0 else null


func weight_bad() -> bool:
	var w = weight_kg()
	return w != null and (w < 20.0 or w > 400.0)


func fat_bad() -> bool:
	var f = body_fat()
	return f != null and (f < 2.0 or f > 75.0)


func is_valid() -> bool:
	return not weight_bad() and not fat_bad() and (weight_kg() != null or body_fat() != null or not photos.is_empty())


func entry() -> Dictionary:
	var e = {
		"id": editing.id if editing != null else Rng.uid("b"),
		"date": date,
		"createdAt": editing.createdAt if editing != null else App.now_ms(),
	}
	if weight_kg() != null:
		e["weightKg"] = weight_kg()
	if body_fat() != null:
		e["bodyFatPct"] = body_fat()
	if not photos.is_empty():
		e["photos"] = photos.duplicate()
	if note.strip_edges() != "":
		e["note"] = note.strip_edges()
	return e


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build(parent: Control) -> void:
	parent.add_child(LogWidgets.topbar("camera", "Edit check-in" if editing != null else "Body check-in", close, remove if editing != null else Callable()))
	parent.add_child(LogWidgets.date_field(date, _set_date))

	var row = Kit.hbox(12)
	var w_opts = {"placeholder": TTUtil.num_str(last_weight) if last_weight != null else "0.0", "width": 76, "min": 0}
	if last_weight != null:
		w_opts["base"] = last_weight
	var ws = Kit.stepper(weight, 0.1 if wu == "kg" else 0.2, Callable(), w_opts)
	LogWidgets.slim_stepper(ws, "weight", 40).tooltip_text = "Body weight"
	ws.changed.connect(func(t):
		weight = t
		refresh())
	var wf = Kit.field("Weight (%s)" % wu, ws)
	_weight_hint = Kit.muted_para("", 11)
	wf.add_child(_weight_hint)
	wf.size_flags_stretch_ratio = 1.4
	row.add_child(wf)
	var be = LogWidgets.num_input(bf, "—", "bodyfat")
	be.text_changed.connect(func(t):
		bf = t
		refresh())
	var bfield = Kit.field("Body fat (%)", be)
	_bf_hint = Kit.muted_para("", 11)
	bfield.add_child(_bf_hint)
	row.add_child(bfield)
	parent.add_child(row)

	parent.add_child(Kit.section_title("Progress photos", Kit.muted("%d/3" % photos.size(), 13)))
	var slots = Kit.hbox(8)
	for a in TT.PHOTO_ANGLES:
		slots.add_child(_photo_slot(a))
	parent.add_child(slots)
	parent.add_child(Kit.muted_para("Tip: same spot, same light, same time of day. Photos are stored on this computer — nowhere else.", 11))

	parent.add_child(Kit.field("Note", LogWidgets.text_area(note, "How are you feeling?", "note", func(t): note = t, 2)))

	_xp_card = null
	_xp_box = null
	if editing == null:
		_xp_card = Kit.card(6, Callable(), 12)
		_xp_box = Kit.vbox(4)
		_xp_card.add(_xp_box)
		parent.add_child(_xp_card)

	var acts = LogWidgets.actions("Save changes" if editing != null else "Check in ✓", close, save)
	_save_btn = acts[1]
	parent.add_child(acts[0])
	parent.add_child(Kit.gap(8))
	refresh()


func _photo_slot(angle: String) -> Control:
	var v = Kit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var id = photos.get(angle)
	var tex = App.photo_texture(id) if id != null else null
	var c = Kit.card(4, pick_photo.bind(angle), 0)
	c.custom_minimum_size = Vector2(0, 150)
	c.tooltip_text = "Add a %s photo" % TT.PHOTO_ANGLE_NAMES[angle].to_lower()
	if tex != null:
		c.tint(Pal.WELL, Pal.with_alpha(Pal.ACCENT, 0.6))
		var img = TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.custom_minimum_size = Vector2(0, 148)
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.clip_contents = true
		c.add(img)
		c.clip_contents = true
	else:
		c.tint(Pal.WELL, Pal.LINE)
		var inner = Kit.vbox(6)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plus = Icons.rect("plus", 26, Pal.MUTED)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(plus)
		var h = Kit.para(ANGLE_HINT[angle], 11, Pal.MUTED)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(h)
		c.add(Kit.pad(inner, 6, 6, 6, 6))
		c.box.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.box.get_child(0).size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(c)
	var foot = Kit.hbox(4)
	foot.add_child(Kit.expand(Kit.label(TT.PHOTO_ANGLE_NAMES[angle], 13, null, true)))
	if tex != null:
		foot.add_child(Kit.link("Remove", clear_photo.bind(angle), 12))
	v.add_child(foot)
	return v


## Re-draw what depends on the typed values without rebuilding (keeps focus).
func refresh() -> void:
	if is_instance_valid(_weight_hint):
		var t = ""
		if weight_bad():
			t = "That does not look right."
		elif last_weight != null and weight.strip_edges() == "":
			t = "Last: %s %s — tap + to start there" % [TTUtil.num_str(last_weight), wu]
		_weight_hint.text = t
		_weight_hint.add_theme_color_override("font_color", Pal.DANGER if weight_bad() else Pal.MUTED)
		_weight_hint.visible = t != ""
	if is_instance_valid(_bf_hint):
		_bf_hint.text = "Between 2 and 75." if fat_bad() else "Optional"
		_bf_hint.add_theme_color_override("font_color", Pal.DANGER if fat_bad() else Pal.MUTED)
	if is_instance_valid(_save_btn):
		_save_btn.disabled = not is_valid()
	if is_instance_valid(_xp_box):
		var flags = int(TTUtil.get_or(App.state.body.weekFlags, Dates.week_key(date), 0))
		var ph = {}
		for a in photos:
			ph[a] = "x"
		var probe = {"photos": ph}
		if weight_kg() != null:
			probe["weightKg"] = weight_kg()
		if body_fat() != null:
			probe["bodyFatPct"] = body_fat()
		var xp = int(Derive.body_entry_reward(flags, probe).xp)
		var sub = "Weight 60 · body fat 20 · 15 per photo — each paid once per week." if xp > 0 else "This week’s bonus is already earned. Still worth logging for the trend."
		LogWidgets.fill_xp_preview(_xp_box, xp, Pal.ACCENT, "weekly check-in bonus", sub)


func _set_date(key: String) -> void:
	date = key
	refresh()


# ---------------------------------------------------------------------------
# Photos
# ---------------------------------------------------------------------------

func pick_photo(angle: String) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.title = "%s photo" % TT.PHOTO_ANGLE_NAMES[angle]
	fd.filters = PackedStringArray(["*.jpg, *.jpeg, *.png, *.webp ; Images"])
	fd.file_selected.connect(_dialog_picked.bind(angle))
	fd.canceled.connect(_dialog_done)
	_dialog = fd
	screen.get_tree().root.add_child(fd)
	fd.popup_centered_ratio(0.8)


func _dialog_picked(path: String, angle: String) -> void:
	_dialog_done()
	photo_from_file(angle, path)


func _dialog_done() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


## Store the picture at `path` as this check-in's `angle` photo.
func photo_from_file(angle: String, path: String) -> bool:
	var id = App.import_photo(path)
	if id == "":
		Sfx.error()
		App.toast("Could not read that image", "bad", "warning")
		return false
	photos[angle] = id
	Sfx.shutter()
	if is_instance_valid(screen):
		screen.rebuild()
	return true


func clear_photo(angle: String) -> void:
	photos.erase(angle)
	screen.rebuild()


# ---------------------------------------------------------------------------
# Save / delete / leave
# ---------------------------------------------------------------------------

func close() -> void:
	App.open_log(null)
	App.go("journey", "body")


func save() -> void:
	if not is_valid():
		Sfx.error()
		return
	var e = entry()
	if editing != null:
		App.update_body(e)
		App.toast("Check-in updated", "good", "edit")
	else:
		App.commit_body(e)
	close()


func remove() -> void:
	if editing == null:
		return
	var id = editing.id
	Kit.confirm("Delete this check-in?", "Its photos are deleted too.", "Delete", func():
		App.delete_body(id)
		App.toast("Check-in deleted", "info", "trash")
		close())
