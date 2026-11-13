class_name LogScreen
extends UiScreen
## Log tab: the discipline picker, the session form (lift / climb / run / ride)
## and the body check-in. What is shown follows App.log_discipline,
## App.editing_session_id and App.editing_body_id.
##
## The half-filled form lives in `_form` (a LogSessionForm or LogBodyForm), not
## in the controls, so a rebuild never loses what was typed; the screen only
## swaps forms when the navigation target really changes.

const PICKER_SUB = {"lift": "Reps × weight", "climb": "V-grades", "run": "Distance & time", "ride": "Distance & time"}

## Field to give keyboard focus after the next rebuild (a LogWidgets.FKEY value).
var focus_key: String = ""

var _key: String = ""
var _form = null


func _init() -> void:
	auto_rebuild = false


func on_nav() -> void:
	if App.tab != "log":
		return
	if _target_key() != _key:
		_sync_form()
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
	add_child(Kit.h1("Log a workout"))
	var grid = Kit.grid(2, 10)
	for d in TT.DISCIPLINES:
		grid.add_child(_picker_tile(d, TT.DISCIPLINE_META[d].name, PICKER_SUB[d], Pal.disc(d), d))
	add_child(grid)

	var wide = Kit.card(0, _pick.bind("body"), 14)
	wide.tint(Pal.with_alpha(Pal.ACCENT, 0.10), Pal.ACCENT)
	var h = Kit.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("camera", 40)))
	var tv = Kit.vbox(2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Kit.label("Body check-in", 17, null, true))
	tv.add_child(Kit.muted_para("Weight · body fat · front / side / back photos", 12))
	h.add_child(tv)
	wide.add(h)
	add_child(wide)


func _picker_tile(d: String, title: String, sub: String, col: Color, icon: String) -> Card:
	var c = Kit.card(6, _pick.bind(d), 14)
	c.tint(Pal.with_alpha(col, 0.14), col)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 128)
	var ic = Icons.rect(icon, 44)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add(ic)
	var t = Kit.label(title, 17, null, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add(t)
	var s = Kit.label(sub, 12, Pal.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add(s)
	return c


func _pick(d: String) -> void:
	Sfx.tap()
	App.open_log(d)
