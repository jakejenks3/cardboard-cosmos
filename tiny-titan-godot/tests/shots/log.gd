extends RefCounted
## Walkthrough of the Log tab: lifting (prefill, steppers, trends, save, prefill
## again, keyboard entry), templates, climbing, run / ride in km and miles, body
## check-in with a photo, editing and deleting a session. Prints CHECK lines.

var main: Node
var tree: SceneTree
var results_seen: int = 0
var fails: int = 0


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.result_ready.connect(func(_r): results_seen += 1)
	var args = OS.get_cmdline_user_args()
	var kind = args[1] if args.size() > 1 else "year"
	if kind == "new":
		await _new_player()
	else:
		await _year()
	print("CHECKS DONE, failures: ", fails)


# ---------------------------------------------------------------------------

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("CHECK ", "ok   " if ok else "FAIL ", what)


func screen() -> LogScreen:
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n
	return null


func card_of(text: String):
	var l = null
	for n in ShotHelper.walk(main):
		if n is Label and n.text == text:
			l = n
			break
	if l == null:
		l = ShotHelper.find_text(main, text)
	var p = l
	while p != null and not (p is Card):
		p = p.get_parent()
	return p


func tap(text: String) -> void:
	var c = card_of(text)
	if c == null:
		check(false, "tappable '%s' found" % text)
		return
	ShotHelper.reveal(c)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.click(tree, c)
	await ShotHelper.frames(tree, 3)


func field(key: String):
	return screen()._find_fkey(screen(), key)


func stepper_btn(key: String, plus: bool) -> Button:
	var e = field(key)
	var st = e.get_parent()
	return st.get_child(2 if plus else 0)


func click_step(key: String, plus: bool) -> void:
	var b = stepper_btn(key, plus)
	b.button_down.emit()
	b.button_up.emit()


func exact_button(text: String):
	for n in ShotHelper.walk(main):
		if n is Button and n.text == text:
			return n
	return null


func tip_button(tip: String):
	for n in ShotHelper.walk(main):
		if n is Button and n.tooltip_text == tip:
			return n
	return null


func key(code: int, unicode: int = 0) -> void:
	for down in [true, false]:
		var ev = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = down
		tree.root.push_input(ev)
		await tree.process_frame


func type_keys(text: String) -> void:
	for ch in text:
		var code = ch.unicode_at(0)
		await key(code, code)


func dismiss_results() -> void:
	await ShotHelper.frames(tree, 3)
	if main.get("_results") != null:
		main._results.finished.emit()
	await ShotHelper.frames(tree, 3)


## Height of the card holding field `fkey` (an exercise card), or -1.
func card_height(fkey: String) -> float:
	var p = field(fkey)
	while p != null and not (p is Card):
		p = p.get_parent()
	return p.size.y if p != null else -1.0


## Report the size of the lift form: each exercise card, and the whole form.
func measure(what: String) -> void:
	var f = screen().form()
	var parts = []
	var top = -1.0
	var bottom = -1.0
	for i in range(f.lift.exercises.size()):
		parts.append("%d sets: %d px" % [f.lift.exercises[i].sets.size(), int(card_height("ex%d.name" % i))])
		var e = field("ex%d.name" % i)
		var p = e
		while p != null and not (p is Card):
			p = p.get_parent()
		if p != null:
			if top < 0.0:
				top = p.global_position.y
			bottom = p.global_position.y + p.size.y
	var save = ShotHelper.find_button(main, "Save changes")
	if save == null:
		save = ShotHelper.find_button(main, "Finish session")
	print("MEASURE %s: cards [%s]; exercises block %d px; whole form %d px; first card to save button bottom %d px" % [what, ", ".join(PackedStringArray(parts)), int(bottom - top), int(screen().size.y), int(save.get_global_rect().end.y - top) if save != null else -1])


func last_session(d: String):
	var best = null
	for s in App.sessions():
		if s.discipline == d and (best == null or s.createdAt > best.createdAt):
			best = s
	return best


func sets_text(sets: Array) -> String:
	var parts = []
	for s in sets:
		parts.append("%sx%s" % [TTUtil.num_str(s.reps), TTUtil.num_str(s.weightKg)])
	return ", ".join(PackedStringArray(parts))


func draft_text(ex: Dictionary) -> String:
	var parts = []
	for s in ex.sets:
		parts.append("%sx%s" % [s.reps, s.weight])
	return ", ".join(PackedStringArray(parts))


# ---------------------------------------------------------------------------

func _year() -> void:
	App.open_log(null)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_01_picker")

	# --- 1. lifting: pick Bench Press, prefilled from last time -------------
	await tap("Lifting")
	await ShotHelper.snap(tree, "log_02_lift_templates")
	var last_bench = LiftHistory.last_performances(App.sessions())["bench press"]
	print("last bench: ", sets_text(last_bench.sets))
	var lift = screen().form().lift
	await tap("Bench Press")
	check(lift.exercises.size() == 1 and lift.exercises[0].name == "Bench Press", "Bench Press added")
	var expect = LogLiftEditor.draft_from_sets("Bench Press", last_bench.sets, "kg")
	check(draft_text(lift.exercises[0]) == draft_text(expect), "prefilled with last bench: " + draft_text(lift.exercises[0]))
	click_step("ex0.s0.weight", true)
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(ShotHelper.find_button(main, "+ Set"))
	await ShotHelper.frames(tree, 4)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "log_03_lift_trends")
	print("after bump + set: ", draft_text(lift.exercises[0]))
	measure("bench 4 sets")
	print(ShotHelper.all_text(screen()).replace("\n", " | ").substr(0, 900))
	ShotHelper.scroll_main(main, 520)
	await ShotHelper.snap(tree, "log_04_lift_picker")
	var sc = null
	for n in ShotHelper.walk(main):
		if n is ScrollContainer:
			sc = n
			break
	var y0 = sc.scroll_vertical
	ShotHelper.press(ShotHelper.find_button(main, "+1 rep"))
	await ShotHelper.frames(tree, 4)
	check(abs(sc.scroll_vertical - y0) < 2, "scroll position kept across a rebuild (%d -> %d)" % [y0, sc.scroll_vertical])
	for st in lift.exercises[0].sets:
		st.reps = TTUtil.num_str(LogWidgets.num(st.reps) - 1.0)
	screen().rebuild()
	await ShotHelper.frames(tree, 3)

	# Keyboard: type reps, Tab, weight into the new set.
	var reps_edit = field("ex0.s3.reps")
	reps_edit.grab_focus()
	await ShotHelper.frames(tree, 2)
	await type_keys("4")
	await key(KEY_TAB)
	await type_keys("62,5")
	await ShotHelper.frames(tree, 2)
	check(lift.exercises[0].sets[3].reps == "4" and lift.exercises[0].sets[3].weight == "62,5", "keyboard entry reps→Tab→weight: %s" % draft_text(lift.exercises[0]))

	var want = LogLiftEditor.sets_from_draft(lift.exercises[0], "kg")
	var n_before = App.sessions().size()
	results_seen = 0
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_05_lift_saved_reel")
	var s = last_session("lift")
	check(App.sessions().size() == n_before + 1, "one lift session added")
	check(s != null and s.exercises.size() == 1 and sets_text(s.exercises[0].sets) == sets_text(want), "stored sets: " + (sets_text(s.exercises[0].sets) if s != null else "none"))
	check(results_seen == 1, "results reel requested")
	check(App.tab == "home", "back on Home after saving")
	await dismiss_results()

	App.open_log("lift")
	await ShotHelper.frames(tree, 4)
	lift = screen().form().lift
	await tap("Bench Press")
	check(draft_text(lift.exercises[0]) == draft_text(LogLiftEditor.draft_from_sets("Bench Press", want, "kg")), "logging again pre-fills the new numbers: " + draft_text(lift.exercises[0]))
	await ShotHelper.snap(tree, "log_06_lift_prefill_again")

	# --- 2. templates ---------------------------------------------------------
	App.open_log(null)
	await ShotHelper.frames(tree, 3)
	App.open_log("lift")
	await ShotHelper.frames(tree, 4)
	lift = screen().form().lift
	await tap("Use →")
	check(lift.exercises.size() >= 1, "template applied: %d exercises" % lift.exercises.size())
	await ShotHelper.snap(tree, "log_07_lift_template_applied")
	# search box
	var search = field("search")
	ShotHelper.type_into(search, "dead")
	await ShotHelper.frames(tree, 2)
	ShotHelper.reveal(search)
	await ShotHelper.snap(tree, "log_08_lift_search")
	App.open_log(null)
	await ShotHelper.frames(tree, 3)

	# --- 3. climbing ------------------------------------------------------------
	App.open_log("climb")
	await ShotHelper.frames(tree, 4)
	ShotHelper.press(exact_button("Flash"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("V2"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("V2"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("Send"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("V4"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("Attempt"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("V5"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("V5"))
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(exact_button("1h · last") if exact_button("1h · last") != null else exact_button("1h"))
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "log_09_climb")
	ShotHelper.scroll_main(main, 500)
	await ShotHelper.snap(tree, "log_10_climb_2")
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 3)
	var c = last_session("climb")
	print("stored climbs: ", JSON.stringify(c.climbs), " duration ", c.get("durationSec"))
	var ok_c = c.climbs.size() == 3
	for cl in c.climbs:
		if cl.grade == 2:
			ok_c = ok_c and cl.result == "flash" and cl.count == 2
		elif cl.grade == 4:
			ok_c = ok_c and cl.result == "send" and cl.count == 1
		elif cl.grade == 5:
			ok_c = ok_c and cl.result == "attempt" and cl.count == 2
	check(ok_c, "climbs stored")
	await dismiss_results()

	# --- 4. run (km) and ride (mi) ------------------------------------------
	App.open_log("run")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_11a_run_empty")
	var fo = main.get_viewport().gui_get_focus_owner()
	check(fo != null and fo.get_meta("fkey", "") == "distance", "distance has focus on open")
	await type_keys("5,2")
	await key(KEY_TAB)
	await key(KEY_TAB)
	await type_keys("27")
	await key(KEY_TAB)
	await type_keys("30")
	await key(KEY_TAB)
	await type_keys("45")
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "log_11_run")
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 3)
	var r = last_session("run")
	print("run: ", JSON.stringify(r))
	check(is_equal_approx(float(r.distanceM), 5200.0) and int(r.get("durationSec", 0)) == 1650 and is_equal_approx(float(r.elevationM), 45.0), "run stored 5.2 km / 27:30 / 45 m")
	await dismiss_results()

	App.update_settings({"distanceUnit": "mi"})
	App.open_log("ride")
	await ShotHelper.frames(tree, 4)
	ShotHelper.type_into(field("distance"), "10")
	ShotHelper.type_into(field("dur.m"), "40")
	ShotHelper.type_into(field("elev"), "300")
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "log_12_ride_miles")
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 3)
	var rd = last_session("ride")
	print("ride: ", JSON.stringify(rd))
	check(absf(float(rd.distanceM) - 16093.44) < 0.01 and int(rd.durationSec) == 2400 and absf(float(rd.elevationM) - 91.44) < 0.01, "ride stored 10 mi / 40 min / 300 ft")
	App.update_settings({"distanceUnit": "km"})
	await dismiss_results()

	# --- 5. body check-in -------------------------------------------------------
	var img = Image.create(60, 80, false, Image.FORMAT_RGB8)
	img.fill(Color("8a5a9e"))
	img.fill_rect(Rect2i(20, 10, 20, 60), Color("ffc83d"))
	var img_path = OS.get_environment("TINY_TITAN_SHOTS").path_join("test_photo.png")
	img.save_png(img_path)
	var pid = App.import_photo(img_path)
	check(pid != "" and App.photo_texture(pid) != null, "App.import_photo + photo_texture")

	App.open_log("body")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_13_body_empty")
	var bf = screen().form()
	click_step("weight", true)
	await ShotHelper.frames(tree, 1)
	print("weight after + from empty: ", bf.weight, " (last ", bf.last_weight, ")")
	ShotHelper.type_into(field("weight"), "79,4")
	ShotHelper.type_into(field("bodyfat"), "18.5")
	bf.photo_from_file("front", img_path)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_14_body_filled")
	var nb = App.body().size()
	results_seen = 0
	ShotHelper.press(ShotHelper.find_button(main, "Check in"))
	await ShotHelper.frames(tree, 3)
	var be = App.body()[App.body().size() - 1]
	print("body: ", JSON.stringify(be))
	check(App.body().size() == nb + 1 and is_equal_approx(float(be.weightKg), 79.4) and is_equal_approx(float(be.bodyFatPct), 18.5) and be.get("photos", {}).has("front"), "body entry stored")
	check(results_seen == 1, "body results reel requested")
	await dismiss_results()

	# --- 6. edit + delete ---------------------------------------------------------
	var old = null
	for x in App.sessions():
		if x.discipline == "lift" and str(x.id).begins_with("demo"):
			old = x
	App.open_log("lift", old.id)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_15_edit")
	measure("edit 3 exercises")
	var ed = screen().form()
	check(ed.lift.exercises.size() == old.exercises.size() and ed.date == old.date, "edit loads %d exercises, date %s" % [ed.lift.exercises.size(), ed.date])
	ShotHelper.type_into(field("ex0.s0.reps"), "9")
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(ShotHelper.find_button(main, "Save changes"))
	await ShotHelper.frames(tree, 3)
	var upd = App.session_by_id(old.id)
	check(int(upd.exercises[0].sets[0].reps) == 9 and upd.createdAt == old.createdAt and App.tab == "journey", "edit saved in place, back to Journey")
	App.open_log("lift", old.id)
	await ShotHelper.frames(tree, 4)
	ShotHelper.press(tip_button("Delete"))
	await ShotHelper.frames(tree, 12)
	await ShotHelper.snap(tree, "log_16_delete_confirm")
	ShotHelper.press(exact_button("Delete"))
	await ShotHelper.frames(tree, 4)
	check(App.session_by_id(old.id) == null, "session deleted")

	# --- 7. pounds: long numbers and badges must fit a 440 px window -----------
	App.update_settings({"weightUnit": "lb"})
	App.open_log("lift")
	await ShotHelper.frames(tree, 4)
	lift = screen().form().lift
	await tap("Bench Press")
	var w3 = LogWidgets.num(lift.exercises[0].sets[3].weight)
	ShotHelper.type_into(field("ex0.s3.weight"), LogWidgets.trim_num(w3 + 12.5))
	ShotHelper.type_into(field("ex0.s1.weight"), "102.5")
	ShotHelper.type_into(field("ex0.s2.reps"), "12")
	await ShotHelper.frames(tree, 3)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "log_17_lb_badges")
	print("lb draft: ", draft_text(lift.exercises[0]))
	check(ShotHelper.find_text(screen(), "+12.5 lb") != null, "'+12.5 lb' badge shown")
	no_overflow("ex0.name")
	App.update_settings({"weightUnit": "kg"})
	App.open_log(null)
	await ShotHelper.frames(tree, 3)


## Every visible control in the card holding `fkey` stays inside the card (nothing cut off on the right).
func no_overflow(fkey: String) -> void:
	var p = field(fkey)
	while p != null and not (p is Card):
		p = p.get_parent()
	if p == null:
		check(false, "card for %s found" % fkey)
		return
	var right = p.get_global_rect().end.x
	var worst = 0.0
	var who = ""
	for n in ShotHelper.walk(p):
		if n is Control and n.is_visible_in_tree():
			var over = n.get_global_rect().end.x - right
			if over > worst:
				worst = over
				who = "%s '%s'" % [n.get_class(), str(n.get("text"))]
	check(worst < 0.5 and right <= main.get_viewport().get_visible_rect().size.x - 10.0, "card fits the window (card right %d, worst overflow %.1f px %s)" % [int(right), worst, who])


func _new_player() -> void:
	App.open_log("lift")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_n1_lift_empty")
	var lift = screen().form().lift
	# Type a new exercise, Enter, then reps Tab weight with the keyboard.
	var search = field("search")
	search.grab_focus()
	await type_keys("Goblet squat")
	await key(KEY_ENTER)
	await ShotHelper.frames(tree, 4)
	var fo = main.get_viewport().gui_get_focus_owner()
	check(fo != null and fo.get_meta("fkey", "") == "ex0.s0.reps", "focus jumps to the first reps box")
	await type_keys("10")
	await key(KEY_TAB)
	await type_keys("20")
	await ShotHelper.frames(tree, 2)
	ShotHelper.press(ShotHelper.find_button(main, "+ Set"))
	await ShotHelper.frames(tree, 3)
	await tap("Bench Press")
	click_step("ex1.s0.reps", true)
	click_step("ex1.s0.reps", true)
	click_step("ex1.s0.reps", true)
	click_step("ex1.s0.weight", true)
	await ShotHelper.frames(tree, 3)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "log_n2_lift_filled")
	print("drafts: ", draft_text(lift.exercises[0]), " / ", draft_text(lift.exercises[1]))
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.frames(tree, 3)
	var s = last_session("lift")
	print("stored: ", JSON.stringify(s.exercises))
	check(s != null and sets_text(s.exercises[0].sets) == "10x20, 10x20" and sets_text(s.exercises[1].sets) == "3x2.5", "new player's session stored")
	await dismiss_results()
	App.open_log("lift")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_n3_lift_second_time")
	App.open_log("body")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_n4_body")
	App.open_log("run")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "log_n5_run")
