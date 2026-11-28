extends RefCounted
## Editing a workout with a FINGER must not move the page (run with "year" data, --fingers; the user,
## 2026-11-27: "when I change/edit/remove a set and exercise the log page jumps around in a weird way and
## you have to rescroll a bunch"). With real touch events (ui/touch_scroll.gd, a phone's: no mouse is left
## over a key after a tap) a workout of four lifts is scrolled half way, then: "+ Set" three times at one
## point, a set's cross, a weight's + key, an exercise's cross. Each time the key pressed (or, when it is
## gone, the card it was in) must stay where the finger was. Prints CHECK lines and JUMP lines.

var main: Node
var tree: SceneTree
var fails = 0
var _finger = 70


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _win(p: Vector2) -> Vector2:
	return main.get_viewport().get_final_transform() * p


func _tap(p: Vector2) -> void:
	_finger += 1
	var d = InputEventScreenTouch.new()
	d.index = _finger
	d.pressed = true
	d.position = _win(p)
	Input.parse_input_event(d)
	await ShotHelper.wait(tree, 0.07)
	var u = InputEventScreenTouch.new()
	u.index = _finger
	u.pressed = false
	u.position = _win(p)
	Input.parse_input_event(u)
	# (longer than the quiet time after a rebuild that could not keep its key)
	await ShotHelper.wait(tree, 0.6)


func _cards() -> Array:
	var out = []
	for n in ShotHelper.walk(main):
		if n.has_meta("exercise_card") and n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a, b): return int(a.get_meta("exercise_card")) < int(b.get_meta("exercise_card")))
	return out


func _in(card: Control, pred: Callable) -> Array:
	var out = []
	for n in ShotHelper.walk(card):
		if n is Control and n.is_visible_in_tree() and pred.call(n):
			out.append(n)
	return out


func _y(c: Control) -> float:
	return c.get_global_rect().position.y


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	Engine.max_fps = 120
	await ShotHelper.wait(tree, 1.0)
	var ts = TouchScroll.new()
	main.add_child(ts)
	ts.only_fingers = true
	App.pending_workout = ["Bench Press - Barbell", "Bent Over Row - Barbell", "Squat - Barbell", "Overhead Press - Barbell"]
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.5)
	var sc = main._scroll
	var cards = _cards()
	check(cards.size() == 4, "a workout of four lifts is open (%d cards)" % cards.size())
	if cards.size() < 4:
		print("LOGJUMP 1 FAILED")
		return
	# Half way down: the second lift's card a third of the way down the screen.
	sc.scroll_vertical = int(sc.scroll_vertical + _y(cards[1]) - 260.0)
	await ShotHelper.wait(tree, 0.6)
	await ShotHelper.snap(tree, "logjump_0_start")

	# --- "+ Set" three times at one point --------------------------------------------------------
	var plus = _in(_cards()[1], func(n): return n is BaseButton and str(n.text) == "+ Set")[0]
	var at = plus.get_global_rect().get_center()
	var sets0 = App.log_draft_sets(1) if App.has_method("log_draft_sets") else -1
	var head_y = _y(_cards()[1])
	for k in range(3):
		await _tap(at)
	var plus2 = _in(_cards()[1], func(n): return n is BaseButton and str(n.text) == "+ Set")[0]
	print("JUMP +set: key %.0f -> %.0f, card %.0f -> %.0f" % [at.y, plus2.get_global_rect().get_center().y, head_y, _y(_cards()[1])])
	check(absf(plus2.get_global_rect().get_center().y - at.y) < 3.0, "'+ Set' stays under the finger after three taps (%.0f -> %.0f)" % [at.y, plus2.get_global_rect().get_center().y])
	await ShotHelper.snap(tree, "logjump_1_plus_set")

	# --- a set's cross --------------------------------------------------------------------------------
	var crosses = _in(_cards()[1], func(n): return n is BaseButton and str(n.tooltip_text).begins_with("Remove set"))
	var cross = crosses[1]
	var cat = cross.get_global_rect().get_center()
	head_y = _y(_cards()[1])
	var other_y = _y(_cards()[2])
	await _tap(cat)
	print("JUMP cross: card head %.0f -> %.0f, next card %.0f -> %.0f" % [head_y, _y(_cards()[1]), other_y, _y(_cards()[2])])
	check(absf(_y(_cards()[1]) - head_y) < 3.0, "taking a set off does not move its card (%.0f -> %.0f)" % [head_y, _y(_cards()[1])])
	var cross2 = _in(_cards()[1], func(n): return n is BaseButton and str(n.tooltip_text).begins_with("Remove set"))
	check(cross2.size() >= 2 and absf(cross2[1].get_global_rect().get_center().y - cat.y) < 3.0, "the next set's cross is now under the finger, ready for a second tap")
	await ShotHelper.snap(tree, "logjump_2_cross")

	# --- a weight's + key ---------------------------------------------------------------------------
	var steppers = _in(_cards()[2], func(n): return n is Stepper)
	if not steppers.is_empty():
		var st = steppers[1] if steppers.size() > 1 else steppers[0]
		# (the third card can sit under the tab bar: bring its key into view first)
		ShotHelper.reveal(st._plus)
		await ShotHelper.wait(tree, 0.4)
		head_y = _y(_cards()[2])
		var pat = st._plus.get_global_rect().get_center()
		var before = str(st.text)
		await _tap(pat)
		var steppers2 = _in(_cards()[2], func(n): return n is Stepper)
		var st2 = steppers2[1] if steppers2.size() > 1 else steppers2[0]
		print("JUMP step: %s -> %s, card %.0f -> %.0f" % [before, str(st2.text), head_y, _y(_cards()[2])])
		check(str(st2.text) != before and absf(_y(_cards()[2]) - head_y) < 3.0, "a weight's + key changes it and moves nothing (%s -> %s)" % [before, str(st2.text)])

	# --- an exercise's cross -----------------------------------------------------------------------
	var c1 = _cards()[1]
	var xs = _in(c1, func(n): return n is BaseButton and str(n.tooltip_text) == "Remove exercise")
	if not xs.is_empty():
		ShotHelper.reveal(xs[0])
		await ShotHelper.wait(tree, 0.4)
	var c2_y = _y(_cards()[2])
	var c1_y = _y(c1)
	if not xs.is_empty():
		await _tap(xs[0].get_global_rect().get_center())
		# (a confirm sheet, when there is one: its key that says remove)
		for c in Kit.overlay_root.get_children():
			if c is Sheet and not c._closing:
				for b in ShotHelper.walk(c):
					if b is Button and b.is_visible_in_tree() and str(b.text).to_lower().contains("remove"):
						await _tap(b.get_global_rect().get_center())
						break
		await ShotHelper.wait(tree, 0.5)
		var now = _cards()
		print("JUMP remove exercise: cards %d, the next card %.0f -> %.0f (the removed one was at %.0f)" % [now.size(), c2_y, _y(now[1]) if now.size() > 1 else -1.0, c1_y])
		check(now.size() == 3 and absf(_y(now[1]) - c1_y) < 3.0, "taking an exercise off: the next card takes its place, nothing else moves (%.0f -> %.0f)" % [c2_y, _y(now[1]) if now.size() > 1 else -1.0])
	await ShotHelper.snap(tree, "logjump_3_removed")

	# --- the search finds a lift of the library never done, and adding it keeps the search where it is ---
	var search = null
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.is_visible_in_tree() and n.has_meta("anchor_id") and str(n.get_meta("anchor_id")) == "log_search":
			search = n
	check(search != null, "the Log tab has its search box")
	if search != null:
		ShotHelper.reveal(search)
		await ShotHelper.wait(tree, 0.5)
		search = null
		for n in ShotHelper.walk(main):
			if n is LineEdit and n.is_visible_in_tree() and n.has_meta("anchor_id") and str(n.get_meta("anchor_id")) == "log_search":
				search = n
		search.text = "baysian"
		search.text_changed.emit("baysian")
		await ShotHelper.wait(tree, 0.4)
		var chip = null
		for n in ShotHelper.walk(main):
			if n is BaseButton and n.is_visible_in_tree() and str(n.text) == "Bicep Curl - Bayesian cable":
				chip = n
		check(chip != null, "typing 'baysian' (one typo) finds the Bayesian cable curl, though it was never done")
		await ShotHelper.snap(tree, "logjump_4_search")
		if chip != null:
			# (in the middle of the screen, clear of the tab bar)
			main._scroll.scroll_vertical += int(chip.get_global_rect().get_center().y - 420.0)
			await ShotHelper.wait(tree, 0.6)
			var sy = search.get_global_rect().position.y
			var n0 = _cards().size()
			await _tap(chip.get_global_rect().get_center())
			var search2 = null
			for n in ShotHelper.walk(main):
				if n is LineEdit and n.is_visible_in_tree() and n.has_meta("anchor_id") and str(n.get_meta("anchor_id")) == "log_search":
					search2 = n
			print("JUMP add from search: search %.0f -> %.0f, cards %d -> %d" % [sy, search2.get_global_rect().position.y if search2 != null else -1.0, n0, _cards().size()])
			check(_cards().size() == n0 + 1 and search2 != null and absf(search2.get_global_rect().position.y - sy) < 3.0, "adding it puts its card in and the search box stays where it was")
			await ShotHelper.snap(tree, "logjump_5_added")
	print("LOGJUMP %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
