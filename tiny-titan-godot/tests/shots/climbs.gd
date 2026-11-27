extends RefCounted
## Journey -> Stats, the climbing card: flashes, sends and tries that did not
## go agree with the rules engine's totals (a flash is a send), hovering a
## grade shows its numbers, clicking one shows its detail without moving the
## chart, and the Routes chip switches the card to roped routes. Run with
## `year` data (it logs one route session first, so both kinds exist).

var fails = 0
var main: Node
var tree: SceneTree


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _find(pred: Callable):
	for n in ShotHelper.walk(main):
		if pred.call(n):
			return n
	return null


func _ladder():
	return _find(func(n): return n is GradeLadder and n.is_visible_in_tree())


func _mouse(c: Control, local: Vector2, click: bool) -> void:
	var pos = c.get_global_rect().position + local
	var mv = InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	tree.root.push_input(mv)
	await tree.process_frame
	if not click:
		return
	for down in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		tree.root.push_input(ev)
		await tree.process_frame


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.commit_sessions([App.build_session({"discipline": "climb", "date": App.today, "durationSec": 3600, "climbs": [
		{"grade": 3, "style": "rope", "yds": "5.10d", "result": "flash", "count": 1},
		{"grade": 4, "style": "rope", "yds": "5.11a", "result": "attempt", "count": 2},
		{"grade": 4, "style": "rope", "yds": "5.11a", "result": "send", "count": 1},
		{"grade": 5, "style": "rope", "yds": "5.11c", "result": "attempt", "count": 3},
	]})], "Climb logged!")
	await ShotHelper.wait(tree, 0.5)
	if main.get("_results") != null:
		main._result_queue.clear()
		main._result_done()
	await ShotHelper.wait(tree, 0.4)
	ClimbCard.mode = "boulder"
	ClimbCard.picks = {}
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.8)

	# --- the numbers -------------------------------------------------------------
	var b = ClimbLadder.ladder(App.sessions(), false)
	var r = ClimbLadder.ladder(App.sessions(), true)
	var tt = App.state.totals
	check(int(b.total.sent) + int(r.total.sent) == int(tt.climbSends), "sent (flashes + sends) matches the game's send count (%d)" % int(tt.climbSends))
	check(int(b.total.flash) + int(r.total.flash) == int(tt.climbFlashes) and int(b.total.attempt) + int(r.total.attempt) == int(tt.climbAttempts), "flashes and tries that did not go match too")
	check(int(b.total.sent) == int(b.total.flash) + int(b.total.send) and int(b.total.tries) == int(b.total.sent) + int(b.total.attempt), "a flash is a send: sent = flashes + sends")
	print("CLIMBS boulders: ", JSON.stringify(b.total), " routes: ", JSON.stringify(r.total))
	var lad = _ladder()
	check(lad != null and lad.rows.size() == b.rows.size() and str(lad.rows[0].label) == str(b.rows[0].label), "the card shows a bar per boulder grade, hardest first (%s)" % (str(lad.rows[0].label) if lad != null else "none"))
	if lad == null:
		return
	var cap = ShotHelper.find_text(main, "sent first go")
	check(cap != null and ShotHelper.find_text(main, "sent after tries") != null and ShotHelper.find_text(main, "tries that failed") != null, "three tiles: flashes, sends, didn't go")
	check(lad.sel == ClimbLadder.default_pick(b.rows), "it opens on the hardest grade sent (%s)" % str(b.rows[lad.sel].label))
	await _top(lad)
	await ShotHelper.snap(tree, "climbs_01_card")

	# --- hover and click a grade ------------------------------------------------
	var target = -1
	for i in range(b.rows.size()):
		if i != lad.sel and int(b.rows[i].attempt) > 0 and int(b.rows[i].sent) > 0:
			target = i
			break
	if target < 0:
		target = (lad.sel + 1) % b.rows.size()
	await _top(lad)
	var y0 = lad.global_position.y
	await _mouse(lad, Vector2(lad.size.x * 0.5, (target + 0.5) * GradeLadder.ROW), false)
	check(lad.hover == target, "hovering a grade lights it (%s)" % str(b.rows[target].label))
	await ShotHelper.snap(tree, "climbs_02_hover")
	await _mouse(lad, Vector2(lad.size.x * 0.5, (target + 0.5) * GradeLadder.ROW), true)
	await ShotHelper.frames(tree, 3)
	check(lad.sel == target and is_instance_valid(lad) and absf(lad.global_position.y - y0) < 1.0, "clicking it picks it, and the chart does not move")
	var want = "%d %s over" % [int(b.rows[target].tries), "try" if int(b.rows[target].tries) == 1 else "tries"]
	check(ShotHelper.find_text(main, want) != null and ShotHelper.find_text(main, "%d didn't go" % int(b.rows[target].attempt)) != null, "the detail under it shows that grade: %s..." % want)
	await _mouse(lad, Vector2(-40, -40), false)
	await ShotHelper.snap(tree, "climbs_03_picked")

	# --- routes ------------------------------------------------------------------------
	var rb = ShotHelper.find_button(main, "Routes")
	check(rb != null, "a Routes chip, since routes were logged")
	if rb == null:
		return
	var ry = rb.global_position.y
	ShotHelper.press(rb)
	await ShotHelper.frames(tree, 4)
	var rl = _ladder()
	var labels = []
	for x in rl.rows:
		labels.append(str(x.label))
	check(labels == ["5.11c", "5.11b", "5.11a", "5.10d"], "Routes: by YDS grade (%s)" % ", ".join(PackedStringArray(labels)))
	rb = ShotHelper.find_button(main, "Routes")
	check(rb != null and absf(rb.global_position.y - ry) < 1.0, "the chips stay where they were")
	check(ShotHelper.find_text(main, "Hardest route") != null, "the records say hardest route")
	await _top(_ladder())
	await ShotHelper.snap(tree, "climbs_04_routes")
	# A rebuild of the screen keeps the mode.
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.6)
	check(ClimbCard.mode == "route" and _ladder() != null and str(_ladder().rows[0].label) == "5.11c", "a rebuild keeps Routes")
	ClimbCard.mode = "boulder"
	print("CLIMBS walkthrough: %d failed" % fails)


## Scroll the main screen so the card holding `c` starts near the top.
func _top(c: Control) -> void:
	var card = c
	while card != null and not (card is Card):
		card = card.get_parent()
	for n in ShotHelper.walk(main):
		if n is ScrollContainer:
			n.scroll_vertical += int(card.global_position.y - n.global_position.y - 8.0)
			break
	await ShotHelper.frames(tree, 4)
