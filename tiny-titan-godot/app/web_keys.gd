class_name WebKeys
extends Node
## Typing on a phone, in the web build (main.gd adds this on a touch screen).
##
## A Godot text box is drawn inside the page's canvas, and a phone's keyboard
## only opens for a real text field. So when a LineEdit or TextEdit is TAPPED,
## the page shows a real field at the top of the screen (web/tt.js: ttKb.want);
## the phone's keyboard types into it, every change is copied into the game's
## box as it happens (text_changed fires as if typed), and Done or return hands
## it in (text_submitted, then the box lets go of the focus).
##
## The keyboard belongs to a tap on a text box and to nothing else:
##   - a box the game gives the cursor to by itself (a form that starts with the
##     cursor in its first box, the cursor put back after a screen is rebuilt)
##     lets go of it again. On a phone that cursor can type nothing, and a box
##     left "active" made every later tap on the screen bring the keyboard up;
##   - a tap on anything else ends the typing (ui/touch_scroll.gd calls
##     `tap_away`): the field goes, the keyboard closes, the tap does its job;
##   - a box rebuilt under the typing (the screen redrew) takes the typing over
##     without the keyboard closing (`GRACE_SEC`);
##   - the phone putting its keyboard away ends it too (ttKb.onClose).

## A text box that takes the focus this soon after a finger landed on one was tapped.
const FINGER_MS = 800
## How long a box may be without the focus before the typing ends (a rebuild
## frees the box and gives the focus to its successor a frame or two later).
const GRACE_SEC = 0.3

static var instance = null
## When a finger last landed on a text box (Time.get_ticks_msec).
static var finger_msec: int = -100000

var _kb = null
var _field: Control = null
## Seconds the field has been without the focus; negative while it has it.
var _gone: float = -1.0
## JavaScriptBridge callbacks must stay referenced, or they stop working.
var _cb_change = null
var _cb_submit = null
var _cb_close = null


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	var app = JavaScriptBridge.get_interface("ttApp")
	return app != null and bool(app.touch)


## A finger landed on text box `c` (ui/touch_scroll.gd, before it presses it).
static func finger_on(c: Control) -> void:
	finger_msec = Time.get_ticks_msec()
	if instance != null and instance._field == c and instance._kb != null:
		instance._kb.arm()


## A tap or a press on something that is not the box being typed in: typing is over.
static func tap_away() -> void:
	if instance != null:
		instance.close()


## Is a box being typed in (the page's field is up)?
static func typing() -> bool:
	return instance != null and instance._field != null


func _ready() -> void:
	instance = self
	set_process(false)
	_kb = JavaScriptBridge.get_interface("ttKb")
	if _kb == null:
		return
	_cb_change = JavaScriptBridge.create_callback(_on_change)
	_cb_submit = JavaScriptBridge.create_callback(_on_submit)
	_cb_close = JavaScriptBridge.create_callback(_on_close)
	_kb.onChange = _cb_change
	_kb.onSubmit = _cb_submit
	_kb.onClose = _cb_close
	get_viewport().gui_focus_changed.connect(_on_focus)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _on_focus(c: Control) -> void:
	if c == _field:
		_gone = -1.0
		return
	if c is LineEdit or c is TextEdit:
		if c is LineEdit and not c.editable:
			return
		if Time.get_ticks_msec() - finger_msec < FINGER_MS:
			_hold(c, false)
		elif _field != null:
			# The box was rebuilt under the typing: carry on in the new one.
			_hold(c, true)
		else:
			# The game put the cursor here by itself. No keyboard opens without a
			# tap, so the box lets go again instead of sitting there half active.
			c.release_focus.call_deferred()
	elif _field != null:
		_let_go()


func _hold(c: Control, keep: bool) -> void:
	_unhook()
	_field = c
	_gone = -1.0
	if not c.focus_exited.is_connected(_on_exit):
		c.focus_exited.connect(_on_exit)
	var kind = "text"
	if c is LineEdit and (c.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER or c.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL):
		kind = "number"
	_kb.want(str(c.text), kind, str(c.placeholder_text), keep)


func _unhook() -> void:
	if _field != null and is_instance_valid(_field) and _field.focus_exited.is_connected(_on_exit):
		_field.focus_exited.disconnect(_on_exit)


func _let_go() -> void:
	_unhook()
	_field = null
	_gone = -1.0
	set_process(false)
	if _kb != null:
		_kb.release()


## End the typing now: the page's field goes and the box lets go of the cursor.
func close() -> void:
	var f = _field
	if f == null:
		return
	_let_go()
	if is_instance_valid(f) and f.has_focus():
		f.release_focus()


func _on_exit() -> void:
	# Not at once: the focus may be on its way to the box that replaces this one.
	_gone = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _field == null or _gone < 0.0:
		set_process(false)
		return
	if is_instance_valid(_field) and _field.has_focus():
		_gone = -1.0
		set_process(false)
		return
	_gone += delta
	if _gone >= GRACE_SEC:
		_let_go()


func _on_change(args: Array) -> void:
	if _field == null or not is_instance_valid(_field):
		return
	var t = str(args[0]) if not args.is_empty() else ""
	if _field.text == t:
		return
	_field.text = t
	if _field is LineEdit:
		_field.caret_column = t.length()
		_field.text_changed.emit(t)
	else:
		_field.text_changed.emit()


func _on_submit(args: Array) -> void:
	if _field == null or not is_instance_valid(_field):
		return
	var f = _field
	_on_change(args)
	_let_go()
	if f is LineEdit:
		f.text_submitted.emit(f.text)
	if is_instance_valid(f):
		f.release_focus()


## The phone put its keyboard away: the typing ends with what was typed
## (nothing is handed in, as when tapping somewhere else).
func _on_close(args: Array) -> void:
	if _field == null:
		return
	_on_change(args)
	close()
