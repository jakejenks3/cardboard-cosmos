extends RefCounted
## Fingers (ui/touch_scroll.gd), driven with real touch events: a flick scrolls
## and glides without hovering or pressing anything, a touch on a gliding page
## only stops it, a tap clicks (and leaves nothing hovered), a hold presses while
## the finger is down, a drag that starts on a key or a text box scrolls and
## changes nothing, a text box takes the focus as the finger lands, and no hover
## card opens. Run with `year` data.

var fails = 0
var main: Node
var tree: SceneTree
var _finger = 40


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


## A screen position in window pixels (the window may be scaled: run the walkthrough
## with --resolution 660x1350 to try it the way a phone shows it).
func _win(p: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * p


func _down(p: Vector2) -> void:
	_finger += 1
	var ev = InputEventScreenTouch.new()
	ev.index = _finger
	ev.pressed = true
	ev.position = _win(p)
	Input.parse_input_event(ev)


func _move(from: Vector2, to: Vector2) -> void:
	var ev = InputEventScreenDrag.new()
	ev.index = _finger
	ev.position = _win(to)
	ev.relative = _win(to) - _win(from)
	Input.parse_input_event(ev)


func _up(p: Vector2) -> void:
	var ev = InputEventScreenTouch.new()
	ev.index = _finger
	ev.pressed = false
	ev.position = _win(p)
	Input.parse_input_event(ev)


func _tap(p: Vector2) -> void:
	_down(p)
	await ShotHelper.wait(tree, 0.07)
	_up(p)
	await ShotHelper.wait(tree, 0.25)


## Drag from `a` by `by` in `steps` moves, one a frame; the finger lifts at the end
## unless `keep`.
func _drag(a: Vector2, by: Vector2, steps: int = 8, keep: bool = false) -> void:
	_down(a)
	await tree.process_frame
	var p = a
	for i in range(steps):
		var q = a + by * (float(i + 1) / steps)
		_move(p, q)
		p = q
		await tree.process_frame
	if not keep:
		_up(p)
		await tree.process_frame


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _sheets() -> int:
	var n = 0
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			n += 1
	return n


func _hovered():
	return main.get_viewport().gui_get_hovered_control()


## The first stepper on screen, set to act as it does on a phone (it steps when
## the finger lifts; a PC steps on the press).
func _stepper():
	for n in ShotHelper.walk(main):
		if n is Stepper and n.is_visible_in_tree():
			n._touch = true
			return n
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	# A screen's pace: without it a PC may draw this window a thousand times a second,
	# and a flick's eight moves then fall within the 4 ms a finger's speed is not read from.
	Engine.max_fps = 120
	var ts = TouchScroll.new()
	main.add_child(ts)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var sc = main._scroll
	var claims0 = App.saved.claims.size()

	# --- a flick: scrolls, glides on, stops; nothing hovered, nothing pressed ----------
	await _drag(Vector2(300, 700), Vector2(0, -320), 8)
	var s1 = sc.scroll_vertical
	check(s1 > 250, "a flick scrolls with the finger (%d)" % s1)
	await ShotHelper.wait(tree, 0.25)
	var s2 = sc.scroll_vertical
	check(s2 > s1 + 40, "and glides on after the lift (%d -> %d)" % [s1, s2])
	await ShotHelper.wait(tree, 3.0)
	var s3 = sc.scroll_vertical
	await ShotHelper.wait(tree, 0.3)
	check(sc.scroll_vertical == s3, "the glide comes to a stop (%d)" % s3)
	check(_hovered() == null, "nothing is hovered after it (%s)" % str(_hovered()))
	check(_sheets() == 0 and App.saved.claims.size() == claims0 and App.tab == "home", "and nothing was pressed")
	check(HoverCard._live == null or not is_instance_valid(HoverCard._live), "no hover card")

	# --- a phone has no mouse: mouse events not made for a finger are dropped ----------
	ts.only_fingers = true
	sc.scroll_vertical = 0
	await ShotHelper.frames(tree, 3)
	var stray_on = ShotHelper.find_button(main, "Claim")
	if stray_on != null:
		ShotHelper.reveal(stray_on)
		await ShotHelper.frames(tree, 3)
		var mm = InputEventMouseMotion.new()
		mm.position = _win(_center(stray_on))
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		await ShotHelper.frames(tree, 3)
		check(_hovered() == null, "a stray mouse move (what a real finger also sends a browser) hovers nothing (%s)" % str(_hovered()))
		for down in [true, false]:
			var mb = InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = down
			mb.position = _win(_center(stray_on))
			mb.global_position = mb.position
			Input.parse_input_event(mb)
			await tree.process_frame
		await ShotHelper.frames(tree, 3)
		check(App.saved.claims.size() == claims0, "and a stray mouse click presses nothing")

	# --- the page follows the finger in parts of a unit --------------------------------
	# (Back to the very top through TouchScroll: the glide above may have stopped
	# between two units, and setting scroll_vertical alone leaves that part of a
	# unit in place. It only showed on a day the page was long enough for the
	# glide to stop before its end.)
	ts._scroll_to(sc, 1, 0.0)
	await ShotHelper.frames(tree, 3)
	_down(Vector2(300, 600))
	await tree.process_frame
	_move(Vector2(300, 600), Vector2(300, 580))
	await tree.process_frame
	_move(Vector2(300, 580), Vector2(300, 569.5))
	await ShotHelper.frames(tree, 3)
	check(sc.scroll_vertical == 10 and absf(main._holder.position.y + 10.5) < 0.05, "10.5 units of finger move the page 10.5 units (scroll %d, content at %.2f)" % [sc.scroll_vertical, main._holder.position.y])
	check(TouchScroll.scrolling, "and the game knows it is scrolling (decorations stand still)")
	_move(Vector2(300, 569.5), Vector2(300, 569.5))
	await ShotHelper.wait(tree, 0.2)
	_up(Vector2(300, 569.5))
	await ShotHelper.frames(tree, 3)
	check(not TouchScroll.scrolling, "until the finger lifts")

	# --- the same at 15 frames a second (a slow phone): it still glides ------------------
	sc.scroll_vertical = 0
	var fps_was = Engine.max_fps
	Engine.max_fps = 15
	await ShotHelper.frames(tree, 3)
	await _drag(Vector2(300, 700), Vector2(0, -320), 5)
	var l1 = sc.scroll_vertical
	await ShotHelper.wait(tree, 0.4)
	check(sc.scroll_vertical > l1 + 40, "at 15 frames a second a flick still glides (%d -> %d)" % [l1, sc.scroll_vertical])
	Engine.max_fps = fps_was
	await ShotHelper.wait(tree, 3.0)

	# --- a slow drag with a pause before the lift does not glide ---------------------
	sc.scroll_vertical = 0
	await tree.process_frame
	await _drag(Vector2(300, 600), Vector2(0, -120), 10, true)
	await ShotHelper.wait(tree, 0.2)
	_up(Vector2(300, 480))
	await tree.process_frame
	var d1 = sc.scroll_vertical
	await ShotHelper.wait(tree, 0.4)
	check(d1 > 90 and sc.scroll_vertical == d1, "a finger that stops before lifting leaves the page where it is (%d, %d)" % [d1, sc.scroll_vertical])

	# --- a touch on a gliding page only stops it --------------------------------------
	sc.scroll_vertical = 0
	await tree.process_frame
	await _drag(Vector2(300, 700), Vector2(0, -320), 8)
	await ShotHelper.wait(tree, 0.12)
	check(ts._fling != null, "gliding")
	var claim = null
	for b in ShotHelper.walk(main):
		if b is Button and b.is_visible_in_tree() and b.text.begins_with("Claim") and b.get_global_rect().position.y > 80 and b.get_global_rect().end.y < 760:
			claim = b
	var hit = _center(claim) if claim != null else Vector2(300, 400)
	_down(hit)
	await ShotHelper.wait(tree, 0.07)
	_up(hit)
	await ShotHelper.wait(tree, 0.3)
	var g1 = sc.scroll_vertical
	await ShotHelper.wait(tree, 0.4)
	check(sc.scroll_vertical == g1, "a touch stops the glide")
	check(App.saved.claims.size() == claims0 and _sheets() == 0, "and presses nothing, even on a Claim key (%s)" % ("there was one under it" if claim != null else "none was under it"))

	# --- a tap clicks; a moment later nothing is hovered -----------------------------
	sc.scroll_vertical = 0
	await ShotHelper.wait(tree, 0.4)
	claim = ShotHelper.find_button(main, "Claim")
	check(claim != null, "a Claim key to tap")
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.frames(tree, 3)
		await _tap(_center(claim))
		check(App.saved.claims.size() == claims0 + 1, "a tap on Claim claims it")
	await ShotHelper.wait(tree, 0.6)
	check(_hovered() == null, "a moment after a tap nothing is hovered (%s)" % str(_hovered()))

	# --- a drag that starts on a key scrolls and does not press it ---------------------
	claim = ShotHelper.find_button(main, "Claim")
	var claims1 = App.saved.claims.size()
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.frames(tree, 3)
		var before = sc.scroll_vertical
		var from = _center(claim)
		await _drag(from, Vector2(0, -140), 8, true)
		await ShotHelper.wait(tree, 0.2)
		_up(from + Vector2(0, -140))
		await ShotHelper.wait(tree, 0.3)
		check(sc.scroll_vertical > before + 80 and App.saved.claims.size() == claims1, "a drag from a Claim key scrolls, and claims nothing")
	# The same after resting on it long enough for the press to start.
	sc.scroll_vertical = 0
	await ShotHelper.frames(tree, 3)
	claim = ShotHelper.find_button(main, "Claim")
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.frames(tree, 3)
		var c0 = _center(claim)
		_down(c0)
		await ShotHelper.wait(tree, 0.4)
		check(claim.is_pressed(), "a finger resting on a key presses it in")
		var p = c0
		for i in range(8):
			var q = c0 + Vector2(0, -15.0 * (i + 1))
			_move(p, q)
			p = q
			await tree.process_frame
		_up(p)
		await ShotHelper.wait(tree, 0.3)
		check(App.saved.claims.size() == claims1, "and dragging away calls it off")

	# --- a hold repeats a stepper; a tap steps once ----------------------------------
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.8)
	var chip = ShotHelper.find_button(main, "Deadlift")
	check(chip != null, "the Log tab's Deadlift key")
	if chip != null:
		await _tap(_center(chip))
		await ShotHelper.wait(tree, 0.5)
	var st = _stepper()
	check(st != null, "a stepper to press")
	if st != null:
		var v0 = int(st.number())
		await _tap(_center(st._plus))
		await ShotHelper.wait(tree, 0.4)
		st = _stepper()
		check(int(st.number()) == v0 + 1, "a tap on + adds one (%d -> %d)" % [v0, int(st.number())])
		var v1 = int(st.number())
		await _drag(_center(st._plus), Vector2(0, -120), 8)
		await ShotHelper.wait(tree, 0.5)
		st = _stepper()
		check(int(st.number()) == v1, "a drag that starts on + changes nothing (%d)" % int(st.number()))
		# With the day's plan on it (LogPlanCard) the page is long enough to
		# scroll: the drag above ends in a glide, and a finger on a gliding page
		# only stops it. Let the glide end, then go back to the top.
		for k in range(360):
			if ts._fling == null:
				break
			await tree.process_frame
		await ShotHelper.wait(tree, 0.3)
		ts._scroll_to(main._scroll, 1, 0.0)
		await ShotHelper.frames(tree, 4)
		st = _stepper()
		var pp = _center(st._plus)
		_down(pp)
		await ShotHelper.wait(tree, 1.3)
		_up(pp)
		await ShotHelper.wait(tree, 0.4)
		st = _stepper()
		check(int(st.number()) >= v1 + 3, "holding + repeats (%d -> %d)" % [v1, int(st.number())])

	# --- a text box takes the focus as the finger lands; a drag from it scrolls --------
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	load("res://ui/screens/settings.gd").open()
	await ShotHelper.wait(tree, 0.8)
	var sheet = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			sheet = c
	var box = null
	if sheet != null:
		for n in ShotHelper.walk(sheet):
			if n is LineEdit and n.is_visible_in_tree() and n.editable and box == null:
				box = n
	check(box != null, "the hero name box in Settings")
	if box != null:
		var bp = _center(box)
		_down(bp)
		await ShotHelper.frames(tree, 3)
		check(box.has_focus(), "a text box has the focus while the finger is still down")
		_up(bp)
		await ShotHelper.wait(tree, 0.3)
		box.release_focus()
		await ShotHelper.frames(tree, 2)
		var sb = sheet._scroll.scroll_vertical
		var from2 = _center(box)
		await _drag(from2, Vector2(0, -100), 8, true)
		await ShotHelper.wait(tree, 0.15)
		_up(from2 + Vector2(0, -100))
		await ShotHelper.wait(tree, 0.3)
		check(sheet._scroll.scroll_vertical > sb + 60 and not box.has_focus(), "a drag that starts on it scrolls the sheet and does not leave it focused (%d -> %d)" % [sb, sheet._scroll.scroll_vertical])
		# A sideways swipe is not a tap: the sheet stays, nothing is pressed.
		await _drag(Vector2(120, 500), Vector2(180, 0), 6)
		await ShotHelper.wait(tree, 0.3)
		check(_sheets() == 1, "a sideways swipe presses nothing")
		sheet.close()
		await ShotHelper.wait(tree, 0.5)

	# --- the Armory: a tap on a tile opens no hover card ------------------------------
	App.go("armory")
	await ShotHelper.wait(tree, 0.9)
	await _tap(Vector2(60, 160))
	await ShotHelper.wait(tree, 0.5)
	check(HoverCard._live == null or not is_instance_valid(HoverCard._live), "no hover card in the Armory after a tap")
	await ShotHelper.snap(tree, "touch_end")
	print("TOUCH DONE, failures: %d" % fails)
