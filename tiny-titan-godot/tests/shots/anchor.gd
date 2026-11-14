extends RefCounted
## Pressing a button that changes the form must not move that button away from
## the mouse: click "+ Set" (and "Add") several times at one fixed mouse position.

var main: Node
var tree: SceneTree
var fails = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if ok else "FAIL", what])


func move_to(pos: Vector2) -> void:
	var mv = InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	tree.root.push_input(mv)
	await tree.process_frame


func click_at(pos: Vector2) -> void:
	for down in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		tree.root.push_input(ev)
		await tree.process_frame


func button(text: String):
	return ShotHelper.find_button(main, text)


## Click `times` times at the centre of the button and watch it every frame.
func hammer(text: String, times: int, before_each: Callable = Callable()) -> void:
	var b = button(text)
	check(b != null, "found '%s'" % text)
	if b == null:
		return
	ShotHelper.reveal(b)
	await ShotHelper.frames(tree, 4)
	b = button(text)
	var pos = b.get_global_rect().get_center()
	await move_to(pos)
	var worst = 0.0
	var missed = 0
	for i in range(times):
		if before_each.is_valid():
			before_each.call(i)
			await tree.process_frame
		await click_at(pos)
		for f in range(10):
			var nb = button(text)
			if nb == null or not nb.get_global_rect().has_point(pos):
				missed += 1
			elif nb != null:
				worst = maxf(worst, absf(nb.get_global_rect().get_center().y - pos.y))
			await tree.process_frame
	check(missed == 0, "'%s' stayed under the mouse on every frame (%d frames off)" % [text, missed])
	check(worst <= 1.5, "'%s' did not drift (max %.1f px)" % [text, worst])


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.open_log("lift")
	await ShotHelper.frames(tree, 6)
	# Bring up Bench Press (pre-filled from history), then add sets with repeated clicks.
	var l = ShotHelper.find_text(main, "Bench Press")
	var n = l
	while n != null and not (n is Card):
		n = n.get_parent()
	await ShotHelper.click(tree, n)
	await ShotHelper.frames(tree, 6)
	var form = main.find_children("*", "LogScreen", true, false)[0].form()
	var sets_before = form.lift.exercises[0].sets.size() if "lift" in form else -1
	await hammer("+ Set", 4)
	await ShotHelper.snap(tree, "anchor_sets")
	var sets_after = form.lift.exercises[0].sets.size() if "lift" in form else -1
	print("sets %s -> %s" % [sets_before, sets_after])
	check(sets_before < 0 or sets_after == sets_before + 4, "four clicks added four sets")
	await hammer("+1 rep", 3)
	# Add three new exercises in a row with the Add button.
	var names = ["Cable Fly", "Hammer Curl", "Face Pull"]
	var type_name = func(i):
		for e in ShotHelper.walk(main):
			if e is LineEdit and e.placeholder_text.to_lower().contains("exercise"):
				ShotHelper.type_into(e, names[i])
	await hammer("Add", 3, type_name)
	await ShotHelper.snap(tree, "anchor_add")
	print("ANCHOR DONE, failures: %d" % fails)
