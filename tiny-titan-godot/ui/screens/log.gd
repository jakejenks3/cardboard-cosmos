class_name LogScreen
extends UiScreen
## Log tab: the discipline picker, the session form (lift / climb / run / ride,
## or a misc activity such as the weighted vest walk) and the body check-in.
## What is shown follows App.log_discipline ("lift"..., "body", or "misc:<kind>"),
## App.editing_session_id and App.editing_body_id.
##
## The half-filled form lives in `_form` (a LogSessionForm or LogBodyForm), not
## in the controls, so a rebuild never loses what was typed; the screen only
## swaps forms when the navigation target really changes.

const PICKER_TIP = {"lift": "Sets of reps × weight", "climb": "Boulders by V-grade", "run": "Distance & time", "ride": "Distance & time"}

## Field to give keyboard focus after the next rebuild (a LogWidgets.FKEY value).
var focus_key: String = ""

var _key: String = ""
var _form = null


func _init() -> void:
	auto_rebuild = false
	# A tap that lands on a stepper or a key by mistake changes the workout.
	guard_shifts = true


func on_nav() -> void:
	if App.tab != "log":
		return
	if _target_key() != _key:
		_sync_form()
		rebuild()
	elif App.pending_exercise != "" or not App.pending_workout.is_empty():
		rebuild()


func _target_key() -> String:
	if App.editing_body_id != null and App.body_by_id(App.editing_body_id) != null:
		return "body:" + str(App.editing_body_id)
	if App.editing_session_id != null and App.session_by_id(App.editing_session_id) != null:
		return "edit:" + str(App.editing_session_id)
	var d = App.log_discipline
	if d != null and str(d) == "body":
		return "body:new"
	if d != null and Xp.is_discipline(d):
		return "new:" + str(d)
	if d != null and str(d).begins_with(TT.MISC + ":") and Misc.KINDS.has(str(d).substr(TT.MISC.length() + 1)):
		return "new:" + str(d)
	return "picker"


func _sync_form() -> void:
	_key = _target_key()
	focus_key = ""
	if _key == "picker":
		_form = null
	elif _key == "body:new":
		_form = LogBodyForm.new(self, null)
	elif _key.begins_with("body:"):
		_form = LogBodyForm.new(self, App.body_by_id(App.editing_body_id))
	elif _key.begins_with("edit:"):
		var s = App.session_by_id(App.editing_session_id)
		_form = LogSessionForm.new(self, str(s.discipline), s)
	elif str(App.log_discipline).begins_with(TT.MISC + ":"):
		_form = LogSessionForm.new(self, TT.MISC, null, str(App.log_discipline).substr(TT.MISC.length() + 1))
	else:
		_form = LogSessionForm.new(self, str(App.log_discipline), null)


## The form being shown (LogSessionForm / LogBodyForm), or null on the picker.
func form():
	return _form


## Rebuild, then put the keyboard focus back where it was (or on `focus_key`).
func rebuild_now() -> void:
	var want = focus_key
	focus_key = ""
	if want == "" and is_inside_tree():
		var f = get_viewport().gui_get_focus_owner()
		if f != null and is_ancestor_of(f) and f.has_meta(LogWidgets.FKEY):
			want = str(f.get_meta(LogWidgets.FKEY))
	focus_key = want
	super.rebuild_now()
	focus_key = ""
	if want != "":
		var target = _find_fkey(self, want)
		if target != null:
			target.grab_focus()
			if target is LineEdit:
				target.caret_column = target.text.length()


func _find_fkey(node: Node, key: String):
	for c in node.get_children():
		if c is Control and c.has_meta(LogWidgets.FKEY) and str(c.get_meta(LogWidgets.FKEY)) == key and c.is_visible_in_tree():
			return c
		var hit = _find_fkey(c, key)
		if hit != null:
			return hit
	return null


func build() -> void:
	if _key == "":
		_sync_form()
	if _form != null:
		_form.build(self)
		return
	_build_picker()


func _build_picker() -> void:
	add_child(Kit.section_title("Log a workout"))
	var grid = Kit.grid(Misc.MAIN.size(), 10)
	for d in Misc.MAIN:
		grid.add_child(_picker_tile(d))
	add_child(grid)
	add_child(_body_tile())
	# Reading is not a workout: its key opens the reading sheet (game/reading.gd).
	add_child(_reading_tile())
	# Miscellaneous: what is done now and then, in small keys at the end.
	# Cycling (Misc.SIDE) and the activities outside the four disciplines
	# (game/misc.gd: a weighted vest walk).
	var mhead = Kit.section_title("Miscellaneous")
	mhead.set_meta("misc_section", true)
	add_child(mhead)
	var misc = Kit.grid(2, 10)
	for d in Misc.SIDE:
		var st = _small_tile(str(TT.DISCIPLINE_META[d].name), d, Pal.disc(d), d, str(PICKER_TIP[d]))
		st.set_meta("side_tile", d)
		misc.add_child(st)
	for k in Misc.ORDER:
		misc.add_child(_misc_tile(k))
	add_child(misc)
	# Workouts jotted in the phone note (app/inbox.gd): the PC reads the note (a
	# browser cannot fetch a Google Doc), so the phone app has no such key.
	if not OS.has_feature("web"):
		var imp = Kit.button("Import from phone", "ghost", InboxSheet.check_and_review.bind(Callable()), "sm", "speech")
		imp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(imp)


## A big bright key in the discipline's colour: its icon and name.
func _picker_tile(d: String) -> Button:
	var col = Pal.disc(d)
	var v = Kit.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic = Icons.rect(d, 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t = LogWidgets.on_face(Kit.label(TT.DISCIPLINE_META[d].name, 18, null, true))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b = LogWidgets.key(TT.DISCIPLINE_META[d].name, col, v, _pick.bind(d), 10, 10, 3, col.lightened(0.3))
	b.custom_minimum_size.y = 116
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = PICKER_TIP[d]
	return b


## The body check-in key: camera, name, and the XP this week's check-in still pays.
func _body_tile() -> Button:
	var h = Kit.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(Icons.rect("camera", 34))
	var t = Kit.label("Body check-in", 18, Pal.TEXT, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var flags = int(TTUtil.get_or(App.state.body.weekFlags, Dates.week_key(App.today), 0))
	var full = {"weightKg": 80.0, "bodyFatPct": 20.0, "photos": {"front": "x", "side": "x", "back": "x"}}
	var avail = int(Derive.body_entry_reward(flags, full).xp)
	if avail > 0:
		h.add_child(Kit.vcenter(Parts.xp_chip(avail, 12)))
	var b = LogWidgets.key("Body check-in", Pal.PANEL2, h, _pick.bind("body"), 12, 10, 2, Pal.ACCENT)
	b.custom_minimum_size.y = 64
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "Weight, body fat and progress photos"
	return b


## A misc activity's key, in the misc colour: its icon and its short name.
func _misc_tile(kind: String) -> Button:
	var m = Misc.meta(kind)
	var b = _small_tile(str(m.short), str(m.icon), Pal.MISC, "%s:%s" % [TT.MISC, kind], "%s: %s" % [str(m.name), str(m.tip).to_lower()])
	b.set_meta("misc_tile", kind)
	return b


## A small key of the Miscellaneous section: an activity done now and then.
func _small_tile(title: String, icon: String, col: Color, target: String, tip: String) -> Button:
	var h = Kit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(Icons.rect(icon, 32))
	var t = LogWidgets.on_face(Kit.label(title, 15, null, true))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var b = LogWidgets.key(title, col, h, _pick.bind(target), 10, 8, 2, col.lightened(0.3))
	b.custom_minimum_size.y = 52
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = tip
	return b


## The reading key, in the colour of a page: the book, and today's pages.
func _reading_tile() -> Button:
	var h = Kit.hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(Icons.rect("book", 32))
	var t = Kit.label("Reading", 18, Pal.INK, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var n = Reading.pages_on(App.state, App.today)
	h.add_child(Kit.vcenter(Kit.tag("%d page%s today" % [n, "" if n == 1 else "s"], Pal.READ_DARK, false, 12)))
	var b = LogWidgets.key("Reading", Pal.READ, h, ReadingView.open, 12, 10, 2, Pal.READ.lightened(0.3))
	b.custom_minimum_size.y = 64
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "Pages read: a little XP, a level of its own and a streak"
	return b


func _pick(d: String) -> void:
	Sfx.tap()
	App.open_log(d)
