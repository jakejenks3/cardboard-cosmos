extends RefCounted
## Walkthrough of the Journey tab: checks of the charts (hover tooltips), the body
## journey with photos, units, the story and the history list.

var main: Node
var tree: SceneTree


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	var args = OS.get_cmdline_user_args()
	var kind = args[1] if args.size() > 1 else "year"
	if kind != "year":
		for tab in ["stats", "body", "chronicle", "history"]:
			App.go("journey", tab)
			await ShotHelper.frames(tree, 4)
			await ShotHelper.snap(tree, "j_%s_%s" % [kind, tab])
			ShotHelper.scroll_main(main, 700)
			await ShotHelper.snap(tree, "j_%s_%s_2" % [kind, tab])
		return

	# --- Stats -------------------------------------------------------------
	App.go("journey", "stats")
	await ShotHelper.frames(tree, 4)
	for i in range(5):
		ShotHelper.scroll_main(main, i * 760)
		await ShotHelper.snap(tree, "j_stats_%d" % i)

	# Weekly chart: print the last week's stack and hover it.
	var wk = _find(func(n): return n is WeeklyXpChart)
	var last = wk.data[wk.data.size() - 1]
	var sum = 0
	for d in TT.DISCIPLINES:
		sum += int(last.byDiscipline[d])
	print("WEEKLY last week ", last.week, " total ", last.total, " stack sum ", sum, " nice_max ", wk.nice_max, " by ", last.byDiscipline)
	var check_total = 0
	for s in App.sessions():
		if Dates.week_key(s.date) == last.week:
			check_total += int(App.state.sessionXp.get(s.id, 0))
	print("WEEKLY recomputed from sessionXp ", check_total)
	var w9 = wk.data[9]
	print("WEEKLY bar 9 ", w9.week, " total ", w9.total)
	ShotHelper.reveal(wk)
	await ShotHelper.frames(tree, 2)
	_hover(wk, Vector2(wk.PAD_L + wk._slot() * 9.5, 60))
	await ShotHelper.snap(tree, "j_stats_weekly_hover")

	var hm = _find(func(n): return n is HeatmapChart)
	print("HEATMAP last day of grid ", hm.days[hm.days.size() - 1], " today ", App.today, " today in grid ", hm.days.has(App.today), " xp today ", hm.xp.get(App.today, 0))
	var ti = hm.days.find(App.today)
	_hover(hm, hm._cell_rect(ti - 1).get_center())
	print("HEATMAP hovered ", hm.days[ti - 1], " xp ", hm.xp.get(hm.days[ti - 1], 0))
	await ShotHelper.snap(tree, "j_stats_heat_hover")

	var ln = _find(func(n): return n is LineChart)
	ShotHelper.reveal(ln)
	await ShotHelper.frames(tree, 2)
	print("LINE e1rm first ", ln.points[0], " last ", ln.points[ln.points.size() - 1], " ticks ", ln.ticks)
	_hover(ln, Vector2(ln.size.x * 0.5, 60))
	print("LINE hovered ", ln.points[ln.hover])
	await ShotHelper.snap(tree, "j_stats_line_hover")
	var chip = ShotHelper.find_button(main, "Bench")
	print("chip Bench ", chip != null)
	ShotHelper.press(chip)
	await ShotHelper.frames(tree, 3)
	var ln2 = _find(func(n): return n is LineChart)
	ShotHelper.reveal(ln2)
	await ShotHelper.snap(tree, "j_stats_bench")

	# --- Units --------------------------------------------------------------
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	await ShotHelper.frames(tree, 4)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "j_stats_lb_0")
	var ln3 = _find(func(n): return n is LineChart)
	ShotHelper.reveal(ln3)
	print("LINE lb last ", ln3.points[ln3.points.size() - 1], " label ", ln3.fmt.call(ln3.points[ln3.points.size() - 1].y))
	await ShotHelper.snap(tree, "j_stats_lb_lift")
	ShotHelper.scroll_main(main, 2400)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "j_stats_lb_run")
	App.update_settings({"weightUnit": "kg", "distanceUnit": "km"})

	# --- Body with photos ---------------------------------------------------
	var dir = OS.get_environment("TINY_TITAN_SHOTS").get_base_dir()
	var specs = [
		{"days": -180, "color": Color("7a4a3a"), "w": 82.0, "bf": 22.5},
		{"days": -90, "color": Color("3a6a8a"), "w": 79.6, "bf": null},
		{"days": -2, "color": Color("4a8a4a"), "w": 77.4, "bf": 18.2},
	]
	for i in range(specs.size()):
		var sp = specs[i]
		var photos = {}
		for a in ["front", "side"]:
			if a == "side" and i == 1:
				continue
			var img = Image.create(300, 400, false, Image.FORMAT_RGB8)
			img.fill(sp.color)
			img.fill_rect(Rect2i(110, 60, 80, 80), Color("f0d0b0"))
			img.fill_rect(Rect2i(90 if a == "front" else 120, 150, 120 if a == "front" else 60, 200), sp.color.lightened(0.4))
			var path = "%s/test_%d_%s.png" % [dir, i, a]
			img.save_png(path)
			photos[a] = App.import_photo(path)
		var entry = {"id": Rng.uid("b"), "date": Dates.add_days(App.today, sp.days), "createdAt": App.now_ms() + i, "weightKg": sp.w, "photos": photos}
		if sp.bf != null:
			entry["bodyFatPct"] = sp.bf
		App.commit_body(entry)
		await ShotHelper.frames(tree, 2)
		_dismiss_results()
	print("BODY entries ", App.body().size(), " with photos ", App.body().filter(func(e): return e.has("photos")).size())
	App.go("journey", "body")
	await ShotHelper.frames(tree, 4)
	for i in range(5):
		ShotHelper.scroll_main(main, i * 760)
		await ShotHelper.snap(tree, "j_body_%d" % i)
	var wl = _find(func(n): return n is LineChart)
	print("BODY weight chart first ", wl.points[0], " last ", wl.points[wl.points.size() - 1], " ticks ", wl.ticks, " trend pts ", wl.trend.size())
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	_hover(wl, Vector2(wl.size.x - 20, 60))
	print("BODY hovered ", wl.points[wl.hover])
	await ShotHelper.snap(tree, "j_body_weight_hover")
	# Pick an earlier "then" date and switch angle.
	var sel = _find(func(n): return n is OptionButton)
	ShotHelper.reveal(sel)
	print("COMPARE options ", sel.item_count, " selected ", sel.get_item_text(sel.selected))
	sel.select(1)
	sel.item_selected.emit(1)
	await ShotHelper.frames(tree, 3)
	sel = _find(func(n): return n is OptionButton)
	ShotHelper.reveal(sel)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "j_body_compare_then1")
	ShotHelper.press(ShotHelper.find_button(main, "Side"))
	await ShotHelper.frames(tree, 3)
	sel = _find(func(n): return n is OptionButton)
	ShotHelper.reveal(sel)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "j_body_compare_side")
	ShotHelper.press(ShotHelper.find_button(main, "Back"))
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "j_body_compare_back")
	# Open a photo in the viewer.
	ShotHelper.press(ShotHelper.find_button(main, "Front"))
	await ShotHelper.frames(tree, 3)
	var thumb = _find(func(n): return n.get_script() != null and n.get("photo_id") != null and n.get("tex") != null)
	ShotHelper.reveal(thumb)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.click(tree, thumb)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "j_body_viewer")
	for n in ShotHelper.walk(tree.root):
		if n is Sheet:
			n.close()
	await ShotHelper.wait(tree, 0.3)
	# Tap a check-in row.
	var rowc = ShotHelper.find_text(main, "photos")
	print("BODY row text ", rowc.text if rowc != null else "none")

	# --- Story --------------------------------------------------------------
	App.go("journey", "chronicle")
	await ShotHelper.frames(tree, 4)
	for i in range(3):
		ShotHelper.scroll_main(main, i * 760)
		await ShotHelper.snap(tree, "j_story_%d" % i)
	print("STORY moments ", App.state.chronicle.size(), " first ", App.state.chronicle[0].date, " last ", App.state.chronicle[App.state.chronicle.size() - 1].date)
	ShotHelper.scroll_main(main, 0)
	ShotHelper.press(ShotHelper.find_button(main, "Bosses"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "j_story_bosses")

	# --- History ------------------------------------------------------------
	App.go("journey", "history")
	await ShotHelper.frames(tree, 4)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "j_history_0")
	ShotHelper.scroll_main(main, 760)
	await ShotHelper.snap(tree, "j_history_1")
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	var row = _find(func(n): return n is Card)
	await ShotHelper.click(tree, row)
	await ShotHelper.frames(tree, 3)
	var newest = App.sessions().duplicate()
	TTUtil.stable_sort(newest, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	print("HISTORY tap -> tab ", App.tab, " editing ", App.editing_session_id, " newest ", newest[0].id)
	await ShotHelper.snap(tree, "j_history_tap")
	# Body check-in row tap.
	App.go("journey", "body")
	await ShotHelper.frames(tree, 4)
	var brow = null
	for n in ShotHelper.walk(main):
		if n is Card and n.get("_tap") != null and n._tap.is_valid() and ShotHelper.all_text(n).contains("photo"):
			brow = n
	if brow != null:
		ShotHelper.reveal(brow)
		await ShotHelper.frames(tree, 2)
		await ShotHelper.click(tree, brow)
		await ShotHelper.frames(tree, 3)
	print("BODY tap -> tab ", App.tab, " log ", App.log_discipline, " editing body ", App.editing_body_id)


func _find(pred: Callable):
	for n in ShotHelper.walk(main):
		if pred.call(n):
			return n
	return null


func _hover(c: Control, local: Vector2) -> void:
	var ev = InputEventMouseMotion.new()
	ev.position = c.get_global_rect().position + local
	ev.global_position = ev.position
	tree.root.push_input(ev)


func _dismiss_results() -> void:
	if main.get("_results") != null:
		main._result_queue.clear()
		main._result_done()
