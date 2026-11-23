class_name TouchScroll
extends Node
## Fingers on a touch screen (main.gd adds this when there is one).
##
## Godot can treat a finger as a mouse, but a mouse stays where it was left: after
## a flick the page glides under that parked pointer, and whatever slides under it
## is hovered (tooltips, hover cards) and can end up pressed; Godot's own touch
## scrolling also stops at buttons. So that emulation is switched off here, and
## the finger is read directly:
##
##   a tap    (down and up without moving)  -> a click at that spot, made inside
##            the lift: the press and the release together. A phone only opens
##            its file chooser, its share sheet or the clipboard from inside a
##            finger's own event, so what the key does must happen there, not a
##            frame later (web/tt.js: live()). The key is shown pressed for a
##            moment afterwards (`_flash`);
##   a hold   (down and still for HOLD_SEC) -> the press starts while the finger
##            is down (a key held repeats) and ends when it lifts;
##   a drag   (moved more than SLOP)        -> scrolls the nearest ScrollContainer
##            under the finger that can scroll that way; a press already started
##            is called off (a release far away, so nothing fires); letting go
##            glides on with the finger's speed;
##   a finger that lands on a gliding page only stops it; a swipe where nothing
##   can scroll does nothing (it is not a tap).
##
## A text box is pressed as soon as the finger lands (the phone's keyboard must
## open inside the touch: app/web_keys.gd). A tap or a press on anything else
## ends the typing (`_leave_text`). After a click the pointer is moved off the
## screen, so nothing stays hovered. No mouse motion is ever sent for a tap, so
## no tooltip timer starts.
##
## A lift that never arrives (a phone can drop a touchend while its keyboard
## moves the page) must not leave a key held: the page counts the fingers on
## the screen (web/tt.js: ttApp.fingers), and a press whose finger is gone is
## called off, at the next touch or by `_watch` (`_lost_lift`). `holding` says
## whether a finger really holds a press: a Stepper only repeats while it does.
##
## With `only_fingers` (a phone: main.gd sets it when the device cannot hover),
## every mouse event that was not made here is dropped: the screen then has no
## mouse at all but these clicks.
##
## The page follows the finger in steps finer than ScrollContainer's whole
## units (`_fine`): the rest is added to the scrolled content's position after
## the container has placed it. `scrolling` is true while a finger drags or the
## page glides: decorations stand still then (ui/widgets/fx.gd, bar.gd, stage.gd,
## ui/backdrop.gd), so every frame goes to the scroll.

## How far a finger moves before it is a scroll, in screen units.
const SLOP = 9.0
## A finger down and still this long is a press (seconds).
const HOLD_SEC = 0.22
## How long a tapped key is shown pressed (seconds).
const FLASH_SEC = 0.07
## How often a press under way asks the page whether its finger is still there.
const WATCH_SEC = 0.2
## After a click, how long the pointer stays before it is moved away (seconds):
## long enough for a screen rebuilt by the click to keep the key under the finger.
const LINGER_SEC = 0.35
## A glide: the share of its speed kept per second, and the speed it stops at.
const FRICTION = 0.10
const MIN_SPEED = 18.0
## No glide starts faster than this (units a second), whatever the timing says.
const MAX_SPEED = 5000.0
## The finger's speed at the lift is taken over this long (seconds).
const SPEED_WINDOW = 0.09
const AWAY = Vector2(-10000, -10000)
## The device id of the mouse events made here (how `only_fingers` tells them apart).
const MY_DEVICE = 7001

## True once a TouchScroll runs: hover cards stay shut (ui/widgets/hover_card.gd).
static var active: bool = false
## When the last press was called off (Time.get_ticks_msec): a key that acts
## when the finger lifts (Stepper) does nothing for a release that follows it.
static var last_cancel_msec: int = -100000
## Where the last release was made (a finger's lift, or AWAY for a press called off).
static var last_release_pos: Vector2 = Vector2(-10000, -10000)
## A finger is dragging the page, or it is gliding.
static var scrolling: bool = false
## A finger is down and holds a press (a key held repeats only while this is true).
static var holding: bool = false
## The screen has no mouse at all (`only_fingers`): every press is a finger's.
static var no_mouse: bool = false

## Drop every mouse event not made here (a phone has no mouse).
var only_fingers: bool = false:
	set(v):
		only_fingers = v
		no_mouse = v

## The finger being followed, or null.
var _t = null
## The glide after a drag, or null.
var _fling = null
var _fling_end_msec: int = -100000
## The page's ttApp (the phone app), for its count of fingers; null elsewhere.
var _page = null
var _watch: float = 0.0
## Seconds until the pointer is moved away; negative when there is nothing to do.
var _linger = -1.0
## A mouse event not made here was dropped: move the pointer away again.
var _stray = false


func _ready() -> void:
	active = true
	Input.emulate_mouse_from_touch = false
	if OS.has_feature("web"):
		_page = JavaScriptBridge.get_interface("ttApp")


func _exit_tree() -> void:
	active = false
	scrolling = false
	holding = false
	no_mouse = false


## Fingers on the screen as the page counts them, or -1 when there is no page to ask.
func _page_fingers() -> int:
	if _page == null:
		return -1
	return int(_page.fingers())


## The finger being followed is gone and its lift never came: a press it held is
## called off (nothing fires), a drag just ends.
func _lost_lift() -> void:
	if _t == null:
		return
	if _t.pressed:
		# Not a scroll's cancel: the tap that follows counts (a Stepper skips the
		# release right after one).
		var was = last_cancel_msec
		_cancel_press()
		last_cancel_msec = was
	_t = null
	holding = false
	scrolling = _fling != null


func _input(event: InputEvent) -> void:
	# The screen never sees a raw touch: Godot's buttons act on those by themselves
	# (pressed as the finger lands, clicked as it lifts), on top of the clicks made here.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
	elif only_fingers and event is InputEventMouse and event.device != MY_DEVICE:
		# Dropped before anything is pressed; but the screen has already noted where
		# it pointed (hover is worked out before this runs), so the pointer is sent
		# away again on the next frame.
		get_viewport().set_input_as_handled()
		if event.position.x > -5000.0:
			_stray = true
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_finger_down(event)
		elif _t != null and event.index == int(_t.index):
			_finger_up(event)
		return
	if event is InputEventScreenDrag and _t != null and event.index == int(_t.index):
		_finger_moved(event)


func _finger_down(event: InputEventScreenTouch) -> void:
	# While one finger works, another is left alone (a phone numbers fingers as it
	# likes: the first is rarely 0). But when the page says this is the only finger
	# on the screen, the one before lifted without a word: what it held is let go.
	if _t != null and (_t.drag or _t.pressed):
		if _page_fingers() != 1:
			return
		_lost_lift()
	# The pointer a click left behind goes now, not after this touch: the page
	# may be about to slide under it.
	if _linger >= 0.0:
		_linger = -1.0
		_motion(AWAY, Vector2.ZERO, false)
	var stopping = _fling != null or Time.get_ticks_msec() - _fling_end_msec < 200
	_fling = null
	_t = {"index": event.index, "start": event.position, "pos": event.position, "at": _now(), "drag": false,
		"stop": stopping, "pressed": false, "dead": false, "sc": null, "axis": 1, "ref": Vector2.ZERO, "v0": 0.0,
		"trail": [], "focus": get_viewport().gui_get_focus_owner()}
	if stopping:
		return
	# A text box takes the press at once, so the keyboard can open inside the touch.
	var under = _control_at(get_tree().root, event.position)
	if under is LineEdit or under is TextEdit:
		WebKeys.finger_on(under)
		_press(event.position)
		_t.pressed = true
		holding = true


func _finger_up(event: InputEventScreenTouch) -> void:
	var t = _t
	_t = null
	holding = false
	if t.drag:
		var v = _speed(t)
		if absf(v) > MIN_SPEED * 4.0 and is_instance_valid(t.sc):
			_fling = {"sc": t.sc, "axis": t.axis, "v": v, "pos": _pos_of(t.sc, t.axis)}
		scrolling = _fling != null
		return
	if t.stop:
		return
	if t.pressed:
		# The move first: a button only knows whether the finger is still on it from a motion.
		if event.position.distance_to(t.start) > 1.0:
			_motion(event.position, Vector2.ZERO, true)
		_release(event.position)
		_linger = LINGER_SEC
		return
	if t.dead:
		return
	# A tap: the whole click is made now, inside the lift.
	_leave_text(t.start)
	var key = _key_at(t.start)
	_press(t.start)
	_release(t.start)
	_linger = LINGER_SEC
	_flash(key)


func _finger_moved(event: InputEventScreenDrag) -> void:
	_t.pos = event.position
	if _t.dead:
		return
	if not _t.drag:
		var d = event.position - _t.start
		if d.length() < SLOP:
			return
		var axis = 1 if absf(d.y) >= absf(d.x) else 0
		var sc = _scroller_at(_t.start, axis)
		if sc == null:
			# Nothing scrolls that way. A press already under way goes on (a key held
			# with a finger that wanders); otherwise the touch is a swipe over nothing:
			# not a tap, so nothing is clicked when it lifts.
			if not _t.pressed:
				_t.dead = true
			return
		if _t.pressed:
			_cancel_press()
			_t.pressed = false
			holding = false
		_t.drag = true
		scrolling = true
		_t.sc = sc
		_t.axis = axis
		_t.ref = event.position
		_t.v0 = _pos_of(sc, axis)
	if not is_instance_valid(_t.sc):
		_t = null
		return
	_scroll_to(_t.sc, _t.axis, float(_t.v0) - float(event.position[_t.axis] - _t.ref[_t.axis]))
	_t.trail.append([_now(), float(event.position[_t.axis])])
	while _t.trail.size() > 12:
		_t.trail.pop_front()


func _process(delta: float) -> void:
	if _stray:
		_stray = false
		if _linger < 0.0 and (_t == null or not _t.pressed):
			_motion(AWAY, Vector2.ZERO, false)
	# A finger down and still: the press starts (a key held repeats).
	if _t != null and not _t.drag and not _t.pressed and not _t.stop and _now() - float(_t.at) >= HOLD_SEC:
		_leave_text(_t.start)
		_t.pressed = true
		holding = true
		_watch = 0.0
		_press(_t.start)
	# A press under way: is its finger still on the screen? (The page knows.)
	if _t != null and _t.pressed and _page != null:
		_watch += delta
		if _watch >= WATCH_SEC:
			_watch = 0.0
			if _page_fingers() == 0:
				_lost_lift()
	if _linger >= 0.0 and _t == null:
		_linger -= delta
		if _linger < 0.0:
			_motion(AWAY, Vector2.ZERO, false)
	if _fling == null:
		return
	if not is_instance_valid(_fling.sc) or not _fling.sc.is_visible_in_tree():
		_fling = null
		scrolling = _t != null and _t.drag
		return
	var want = float(_fling.pos) + float(_fling.v) * delta
	_fling.pos = _scroll_to(_fling.sc, _fling.axis, want)
	_fling.v = float(_fling.v) * pow(FRICTION, delta)
	# Slow enough to stop, or at an end.
	if absf(float(_fling.v)) < MIN_SPEED or absf(float(_fling.pos) - want) > 0.01:
		_fling = null
		_fling_end_msec = Time.get_ticks_msec()
		scrolling = _t != null and _t.drag


## The finger's speed along its axis at the lift, in units a second (the scroll
## goes the other way): from its last positions, over about SPEED_WINDOW. When
## frames are slow there may be only one position that recent: then the one
## before it counts too. A finger that stopped before lifting (no move for a
## while: a tenth of a second, or a few frames when frames are slower than
## that) does not glide.
func _speed(t: Dictionary) -> float:
	var n = t.trail.size()
	if n < 2:
		return 0.0
	var now = _now()
	var last = t.trail[n - 1]
	var frame = maxf(get_process_delta_time(), 0.001)
	if now - float(last[0]) > maxf(0.1, frame * 2.5):
		return 0.0
	var first = t.trail[n - 2]
	for i in range(n - 2, -1, -1):
		if float(last[0]) - float(t.trail[i][0]) > SPEED_WINDOW:
			break
		first = t.trail[i]
	var dt = float(last[0]) - float(first[0])
	if dt < 0.004 or dt > maxf(0.25, frame * 3.0):
		return 0.0
	return clampf(-(float(last[1]) - float(first[1])) / dt, -MAX_SPEED, MAX_SPEED)


func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


# ---------------------------------------------------------------------------
# The clicks made for a finger
# ---------------------------------------------------------------------------

## Positions here are the screen's own (what a touch event carries once it reaches
## `_input`); an event handed to Input is in window pixels and gets scaled down to
## the screen again on its way in (a phone's window is not 440 wide), so it is
## scaled up first.
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


func _button(pos: Vector2, down: bool) -> void:
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.device = MY_DEVICE
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _press(pos: Vector2) -> void:
	_linger = -1.0
	_button(pos, true)


func _release(pos: Vector2) -> void:
	last_release_pos = pos
	_button(pos, false)


func _motion(pos: Vector2, rel: Vector2, held: bool) -> void:
	var ev = InputEventMouseMotion.new()
	ev.device = MY_DEVICE
	ev.position = _to_window(pos)
	ev.global_position = ev.position
	ev.relative = rel
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(ev)


## A tap or a press at `pos` while a text box has the cursor, and not on that
## box: the typing is over (the phone's keyboard closes; app/web_keys.gd).
func _leave_text(pos: Vector2) -> void:
	if not WebKeys.typing():
		return
	var f = get_viewport().gui_get_focus_owner()
	if f != null and _control_at(get_tree().root, pos) == f:
		return
	WebKeys.tap_away()


## The button a tap at `pos` lands on (the control there, or the button it is part of), or null.
func _key_at(pos: Vector2):
	var c = _control_at(get_tree().root, pos)
	var hops = 0
	while c != null and hops < 4:
		if c is BaseButton:
			return c
		c = c.get_parent() as Control
		hops += 1
	return null


## Show a tapped key pressed for a moment: its click was over within one frame.
## (A Card shows its own: ui/widgets/card.gd.) The key may be gone already, when
## the tap rebuilt the screen.
func _flash(key) -> void:
	if key == null or not is_instance_valid(key) or not key.is_inside_tree() or key.disabled:
		return
	var base: Color = key.get_meta("tt_flash", key.self_modulate)
	key.set_meta("tt_flash", base)
	key.self_modulate = Color(base.r * 0.7, base.g * 0.7, base.b * 0.7, base.a)
	var tw = key.create_tween()
	tw.tween_interval(FLASH_SEC)
	tw.tween_property(key, "self_modulate", base, 0.1)
	tw.tween_callback(func():
		if key.has_meta("tt_flash"):
			key.remove_meta("tt_flash"))


## Call off the press the finger started: a release far from everything, so the
## button (or card) under it sees the finger leave and does not fire. A text box
## the press had just focused lets go again (no keyboard for a scroll).
func _cancel_press() -> void:
	last_cancel_msec = Time.get_ticks_msec()
	# The move first: a button only knows the pointer left it from a motion.
	_motion(AWAY, Vector2.ZERO, true)
	_release(AWAY)
	var f = get_viewport().gui_get_focus_owner()
	if f != null and _t != null and f != _t.focus and (f is LineEdit or f is TextEdit):
		WebKeys.tap_away()
		if f.has_focus():
			f.release_focus()


# ---------------------------------------------------------------------------
# What is under the finger
# ---------------------------------------------------------------------------

func _scroll_of(sc: ScrollContainer, axis: int) -> int:
	return sc.scroll_vertical if axis == 1 else sc.scroll_horizontal


## Where `sc` is scrolled to, with the part of a unit its content is shifted by.
func _pos_of(sc: ScrollContainer, axis: int) -> float:
	var fine: Vector2 = sc.get_meta("tt_fine", Vector2.ZERO)
	return float(_scroll_of(sc, axis)) + float(fine[axis])


## Scroll `sc` to `v` (kept inside its range) and return where it is now. The
## container takes the whole units; the rest of a unit moves the content itself.
func _scroll_to(sc: ScrollContainer, axis: int, v: float) -> float:
	var bar = sc.get_v_scroll_bar() if axis == 1 else sc.get_h_scroll_bar()
	var top = maxf(0.0, bar.max_value - bar.page)
	v = clampf(v, 0.0, top)
	var whole = floorf(v)
	var rest = v - whole
	if not sc.has_meta("tt_fine"):
		sc.set_meta("tt_fine", Vector2.ZERO)
		sc.sort_children.connect(_placed.bind(sc))
	var fine: Vector2 = sc.get_meta("tt_fine")
	fine[axis] = rest
	sc.set_meta("tt_fine", fine)
	var before = _scroll_of(sc, axis)
	if axis == 1:
		sc.scroll_vertical = int(whole)
	else:
		sc.scroll_horizontal = int(whole)
	if _scroll_of(sc, axis) == before:
		# The container has nothing to place again: shift the content now.
		_shift(sc)
	return v


## The container has placed its content (whole units): remember where, and add the rest.
func _placed(sc: ScrollContainer) -> void:
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar):
			c.set_meta("tt_base", c.position)
	_shift(sc)


func _shift(sc: ScrollContainer) -> void:
	var fine: Vector2 = sc.get_meta("tt_fine", Vector2.ZERO)
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar) and c.has_meta("tt_base"):
			c.position = Vector2(c.get_meta("tt_base")) - fine


## The ScrollContainer under `pos` that can scroll along `axis`: from the control
## the finger is on, up through its parents (a sheet's list before the page behind it).
func _scroller_at(pos: Vector2, axis: int):
	var c = _control_at(get_tree().root, pos)
	while c != null:
		if c is ScrollContainer and _can_scroll(c, axis):
			return c
		# A sheet or overlay that cannot scroll keeps the page behind it still.
		if c is Sheet:
			return null
		c = c.get_parent() as Control
	return null


func _can_scroll(sc: ScrollContainer, axis: int) -> bool:
	if axis == 1:
		if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			return false
		var vb = sc.get_v_scroll_bar()
		return vb.max_value - vb.page > 1.0
	if sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var hb = sc.get_h_scroll_bar()
	return hb.max_value - hb.page > 1.0


## The top-most visible control under `pos` that takes the mouse (drawn last wins).
func _control_at(node: Node, pos: Vector2):
	var found = null
	for i in range(node.get_child_count() - 1, -1, -1):
		var ch = node.get_child(i)
		if ch is CanvasItem and not ch.visible:
			continue
		if ch is Window:
			continue
		var hit = _control_at(ch, pos)
		if hit != null:
			return hit
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(pos):
		found = node
	return found
