extends RefCounted
## Results reel walkthrough. Branches on the demo data:
##   new  – the very first session (first trophies + a companion), skipped early
##   week – a big lift session watched to the end, then a run skipped with a click,
##          then a body check-in closed with the keyboard
##   year – a huge session (several bosses, many trophies): long-reel layout

var _done = {"n": 0}


func run(main: Node, tree: SceneTree) -> void:
	var n = App.sessions().size()
	if n == 0:
		await _new(main, tree)
	elif n < 20:
		await _week(main, tree)
	else:
		await _year(main, tree)


func _overlay(main: Node):
	for c in ShotHelper.walk(main):
		if c is ResultsOverlay:
			return c
	return null


func _attach(main: Node, tree: SceneTree):
	await ShotHelper.frames(tree, 2)
	var ov = _overlay(main)
	if ov == null:
		print("CHECK FAIL: no results overlay")
		return null
	var counter = _done
	ov.finished.connect(func(): counter.n += 1)
	var types = []
	for e in ov._events:
		types.append(e.type)
	print("REEL events: ", ", ".join(PackedStringArray(types)))
	return ov


func _wait_done(ov, tree: SceneTree, limit: float = 40.0) -> void:
	var t = 0.0
	while is_instance_valid(ov) and ov._phase != "done" and t < limit:
		await ShotHelper.wait(tree, 0.25)
		t += 0.25
	print("REEL done after ~%.1fs" % t)


func _close_and_check(main: Node, tree: SceneTree, ov, expect: int, tag: String) -> void:
	ShotHelper.press(ShotHelper.find_button(ov, "Continue"))
	await ShotHelper.frames(tree, 4)
	var nav_ok = ShotHelper.find_button(main, "Adventure") != null
	print("CHECK %s: finished=%d (expect %d) overlay_gone=%s nav_visible=%s" % [tag, _done.n, expect, _overlay(main) == null, nav_ok])


func _lift(sets_per: int, kg: float, names: Array) -> Dictionary:
	var ex = []
	for nm in names:
		var sets = []
		for i in range(sets_per):
			sets.append({"reps": 5, "weightKg": kg})
		ex.append({"name": nm, "sets": sets})
	return App.build_session({"discipline": "lift", "date": App.today, "exercises": ex, "durationSec": 4200})


func _week(main: Node, tree: SceneTree) -> void:
	var hero_before = App.state.levels.hero.level
	App.commit_sessions([_lift(5, 140.0, ["Deadlift", "Squat", "Bench Press", "Barbell Row"])], "Workout logged!")
	var ov = await _attach(main, tree)
	await ShotHelper.wait(tree, 0.35)
	await ShotHelper.snap(tree, "res_week_1_start")
	await ShotHelper.wait(tree, 1.1)
	await ShotHelper.snap(tree, "res_week_2_discbar")
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "res_week_3_herobar")
	await ShotHelper.wait(tree, 1.6)
	await ShotHelper.snap(tree, "res_week_4_boss")
	await ShotHelper.wait(tree, 2.0)
	await ShotHelper.snap(tree, "res_week_5_cards")
	await _wait_done(ov, tree)
	await ShotHelper.snap(tree, "res_week_6_end")
	print("hero level %d -> %d" % [hero_before, App.state.levels.hero.level])
	await _close_and_check(main, tree, ov, 1, "week-full")
	await ShotHelper.snap(tree, "res_week_7_after")

	# A run, skipped early by clicking the reel.
	App.commit_sessions([App.build_session({"discipline": "run", "date": App.today, "distanceM": 12000, "elevationM": 120, "durationSec": 3600})], "Run logged!")
	ov = await _attach(main, tree)
	await ShotHelper.wait(tree, 1.3)
	await ShotHelper.click(tree, ov._scroll)
	await ShotHelper.frames(tree, 3)
	print("after click phase=", ov._phase)
	await ShotHelper.snap(tree, "res_week_8_skipped")
	await ShotHelper.wait(tree, 3.0)
	print("finished count still %d (expect 1)" % _done.n)
	await _close_and_check(main, tree, ov, 2, "week-skip")

	# Body check-in, skipped and closed with Enter.
	App.commit_body({"id": Rng.uid("b"), "date": App.today, "createdAt": App.now_ms(), "weightKg": 81.2, "bodyFatPct": 19.5})
	ov = await _attach(main, tree)
	await ShotHelper.wait(tree, 2.2)
	await ShotHelper.snap(tree, "res_week_9_body")
	for i in range(2):
		var ev = InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.pressed = true
		tree.root.push_input(ev)
		await ShotHelper.frames(tree, 3)
		var up = InputEventKey.new()
		up.keycode = KEY_ENTER
		up.pressed = false
		tree.root.push_input(up)
		await ShotHelper.frames(tree, 3)
	await ShotHelper.frames(tree, 4)
	print("CHECK body-enter: finished=%d (expect 3) overlay_gone=%s" % [_done.n, _overlay(main) == null])
	await ShotHelper.snap(tree, "res_week_10_after_body")


func _new(main: Node, tree: SceneTree) -> void:
	App.commit_sessions([_lift(3, 40.0, ["Squat", "Bench Press"])], "Workout logged!")
	var ov = await _attach(main, tree)
	await ShotHelper.wait(tree, 4.5)
	await ShotHelper.snap(tree, "res_new_1_mid")
	await _wait_done(ov, tree)
	await ShotHelper.snap(tree, "res_new_2_end")
	ShotHelper.scroll_main(ov, 2000)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "res_new_3_end_scrolled")
	# Follow the new companion from the reel.
	var follow = ShotHelper.find_button(ov, "Follow me")
	print("follow button: ", follow != null)
	ShotHelper.press(follow)
	await ShotHelper.frames(tree, 3)
	print("active pet now: ", App.active_pet())
	await ShotHelper.snap(tree, "res_new_4_followed")
	await _close_and_check(main, tree, ov, 1, "new")


func _year(main: Node, tree: SceneTree) -> void:
	var s = _lift(10, 220.0, ["Deadlift", "Squat", "Bench Press", "Barbell Row", "Overhead Press", "Front Squat", "Romanian Deadlift", "Hip Thrust"])
	App.commit_sessions([s], "Workout logged!")
	var ov = await _attach(main, tree)
	await ShotHelper.wait(tree, 6.0)
	await ShotHelper.snap(tree, "res_year_1_mid")
	await ShotHelper.wait(tree, 5.0)
	await ShotHelper.snap(tree, "res_year_2_later")
	await _wait_done(ov, tree, 60.0)
	await ShotHelper.snap(tree, "res_year_3_end")
	ShotHelper.scroll_main(ov, 0)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "res_year_4_top")
	print("overlay size ", ov.size, " content width ", ov._scroll.get_child(0).size.x)
	await _close_and_check(main, tree, ov, 1, "year")
