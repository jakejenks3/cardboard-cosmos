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
## While typing, the box being typed in is moved into the part of the screen the keyboard leaves (2026-11-27:
## "the keyboard gets in the way of what you're trying to see come up if you're searching"). A box with meta
## "type_top" (the exercise search, an exercise's name) goes right under the typing bar, so what comes up
## under it is seen; any other box only when the keyboard would cover it. The keyboard is taken to cover this
## share of the screen when the phone does not say.
const KEYBOARD_SHARE = 0.42
## How long after the field shows the keyboard is fully up (the box is placed again then).
const SETTLE_SEC = 0.45

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
	elif instance != null and instance._kb != null and is_instance_valid(c) and c.has_focus():
		# The box had the focus already (left by a redraw, not let go of): a tap brings no focus change,
		# so the keyboard never came. It is held now, as if the tap had given it the focus.
		instance._hold(c, false)


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
	_reveal.call_deferred(c)
	get_tree().create_timer(SETTLE_SEC).timeout.connect(_reveal.bind(c))


## The part of the screen left to see while typing, in the game's own pixels: [top, bottom].
func room() -> Array:
	var vp_h = get_viewport().get_visible_rect().size.y
	var top = 70.0
	var bottom = vp_h * (1.0 - KEYBOARD_SHARE)
	var raw = _kb.room() if _kb != null else null
	var d = JSON.parse_string(str(raw)) if raw != null else null
	if d is Dictionary and float(d.get("h", 0.0)) > 0.0:
		var k = vp_h / float(d.h)
		if float(d.get("bar", 0.0)) > 0.0:
			top = float(d.bar) * k
		# (the phone saying where the keyboard begins; else the usual share)
		if float(d.get("vis", d.h)) < float(d.h) - 40.0:
			bottom = float(d.vis) * k
	return [top + 6.0, bottom - 6.0]


## Move the page so `c` is where it can be seen while typing (see KEYBOARD_SHARE).
func _reveal(c) -> void:
	if c == null or not is_instance_valid(c) or c != _field or not c.is_inside_tree():
		return
	var sc = _scroller_of(c)
	if sc == null:
		return
	var r = room()
	var rect = c.get_global_rect()
	var target = -1.0
	if c.has_meta("type_top"):
		target = float(r[0])
	elif rect.end.y > float(r[1]) or rect.position.y < float(r[0]):
		target = float(r[0]) + (float(r[1]) - float(r[0])) * 0.3
	if target < 0.0 or absf(rect.position.y - target) < 2.0:
		return
	var want = sc.scroll_vertical + int(round(rect.position.y - target))
	var most = int(sc.get_v_scroll_bar().max_value - sc.size.y)
	if want > most:
		# The page ends too soon for the box to go that high: room is made under it while typing.
		_spacer(c, want - most + 40)
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(sc) or not is_instance_valid(c):
			return
		want = sc.scroll_vertical + int(round(c.get_global_rect().position.y - target))
	sc.scroll_vertical = maxi(0, want)


func _scroller_of(c: Node):
	var p = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## Room under the page while typing (taken away when the typing ends, or by the page's next redraw).
func _spacer(c: Node, h: int) -> void:
	var screen = c.get_parent()
	while screen != null and not (screen is UiScreen):
		screen = screen.get_parent()
	if screen == null:
		return
	for n in screen.get_children():
		if n.has_meta("kb_spacer"):
			n.custom_minimum_size.y = maxf(n.custom_minimum_size.y, float(h))
			return
	var sp = Control.new()
	sp.set_meta("kb_spacer", true)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.custom_minimum_size = Vector2(0, h)
	screen.add_child(sp)


func _drop_spacers() -> void:
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n.has_meta("kb_spacer") and not n.is_queued_for_deletion():
			n.queue_free()


func _unhook() -> void:
	if _field != null and is_instance_valid(_field) and _field.focus_exited.is_connected(_on_exit):
		_field.focus_exited.disconnect(_on_exit)


func _let_go() -> void:
	_unhook()
	_field = null
	_drop_spacers()
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
