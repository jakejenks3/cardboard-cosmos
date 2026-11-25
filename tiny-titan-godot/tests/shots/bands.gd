extends RefCounted
## Resistance bands in place of a weight (run with the "year" data; also with
## --fingers after it). A face pull logged with a green band a few days ago;
## then in the Log tab's lift form: a curl switched to Band takes the band used
## last, the band picker's keys change a set's band in place (nothing on the
## card moves), "+ Set" copies the band, "+1 band" makes every set one heavier,
## a lift that says band (Pull-Apart) starts with one, and the face pull shows
## "+1 band" against last time. Saved: weight 0 and the bands. The session's
## sheet and the lift's page (Compare, Progress, Logbook) say the bands.
## Prints CHECK lines.

const CURL = "Bicep Curl - Dumbbell"
const APART = "Pull-Apart"

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			out.append(n)
	return out


func _find(meta: String, root = null, value = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _dismiss_reels() -> void:
	for k in range(6):
		var b = null
		for i in range(40):
			await ShotHelper.wait(tree, 0.4)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.5)


func _form():
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n.form()
	return null


## The index of the exercise whose name holds `part`, or -1.
func _index(form, part: String) -> int:
	for i in range(form.lift.exercises.size()):
		if str(form.lift.exercises[i].name).contains(part):
			return i
	return -1


## The card of exercise i.
func _card(i: int):
	return _find("exercise_card", null, i)


## The key ("lighter" / "heavier") of set j of exercise i's band picker.
func _band_key(i: int, j: int, which: String):
	var picker = _find("band_of", null, "%d:%d" % [i, j])
	if picker == null:
		return null
	return _find("band_key", picker, which)


func _move_to(pos: Vector2) -> void:
	var mv = InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	tree.root.push_input(mv)
	await tree.process_frame


func _click_at(pos: Vector2) -> void:
	for down in [true, false]:
		var ev = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = pos
		ev.global_position = pos
		tree.root.push_input(ev)
		await tree.process_frame


## A real click on a control, the pointer left on it.
func _tap(c: Control) -> void:
	ShotHelper.reveal(c)
	await ShotHelper.frames(tree, 4)
	var pos = c.get_global_rect().get_center()
	await _move_to(pos)
	await _click_at(pos)


func _bands(rows: Array) -> Array:
	var out = []
	for r in rows:
		out.append({"reps": int(r[0]), "weightKg": 0.0, "band": str(r[1])})
	return out


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# The demo player trains by the weekday: take out what it did on this
	# weekday, today included, so today's workout is this walkthrough's.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	App.replace_all(clean)
	App.update_settings({"weightUnit": "lb", "focus": ""})
	await ShotHelper.wait(tree, 0.4)

	# A face pull: a blue band eleven days ago (its heaviest), green four days ago.
	App.commit_sessions([App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -11), "exercises": [{"name": "Face Pull - Rope", "sets": _bands([[12, "blue"], [10, "blue"], [10, "blue"]])}]})], "Workout")
	await _dismiss_reels()
	App.commit_sessions([App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -4), "exercises": [{"name": "Face Pull - Rope", "sets": _bands([[15, "green"], [15, "green"], [12, "green"]])}]})], "Workout")
	await _dismiss_reels()
	var face = ""
	for s in App.sessions():
		for ex in s.get("exercises", []):
			if str(ex.name).begins_with("Face Pull"):
				face = str(ex.name)
	check(face != "" and App.sessions().any(func(s): return s.get("exercises", []).any(func(ex): return str(ex.name) == face and ex.sets.all(func(one): return str(one.get("band", "")) != "" and float(one.weightKg) == 0.0))), "the face pulls are saved with their bands and no weight (%s)" % face)

	# --- the Log tab: a curl switched to Band ---------------------------------------------------
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.7)
	var form = _form()
	check(form != null, "the lift form is open")
	if form == null:
		print("BANDS WALK: %d failed" % (fails + 1))
		return
	form.lift.exercises = []
	form.lift.add_exercise(CURL)
	await ShotHelper.wait(tree, 0.5)
	var ci = _index(form, "Bicep Curl")
	check(ci >= 0 and not bool(form.lift.exercises[ci].get("band", false)), "a new curl starts with a weight")
	var chip = _find("band_chip", _card(ci))
	check(chip != null and not bool(chip.get_meta("band_chip")), "its card has a Band key, off")
	if chip != null:
		var at = chip.get_global_rect().position
		await _tap(chip)
		await ShotHelper.wait(tree, 0.5)
		chip = _find("band_chip", _card(ci))
		check(chip != null and bool(chip.get_meta("band_chip")) and bool(form.lift.exercises[ci].get("band", false)), "tapped: the curl is done with a band")
		check(chip != null and chip.get_global_rect().position.distance_to(at) < 1.0, "the Band key stayed under the finger (%s -> %s)" % [str(at), str(chip.get_global_rect().position) if chip != null else "-"])
	var picker = _find("band_of", null, "%d:0" % ci)
	check(picker != null and picker.band == "green", "a band picker where the weight was, with the band used last: green (%s)" % (picker.band if picker != null else "-"))
	check(_find("band_chip", _card(ci)) != null and ShotHelper.find_button(_card(ci), "BW") != null and ShotHelper.find_button(_card(ci), "Hold") != null and form.lift._mode_of(form.lift.exercises[ci]) == "band", "BW and Hold stay in the track, the band is the one on")
	form.lift._on_set_text("12", ci, 0, "reps")
	await ShotHelper.frames(tree, 3)

	# The heavier key: the band changes in place, nothing on the card moves.
	var plus = _band_key(ci, 0, "heavier")
	check(plus != null, "the heavier key of set 1")
	if plus != null:
		ShotHelper.reveal(plus)
		await ShotHelper.frames(tree, 4)
		plus = _band_key(ci, 0, "heavier")
		var watched = [plus, _band_key(ci, 0, "lighter"), _find("band_chip", _card(ci)), ShotHelper.find_button(_card(ci), "+ Set")]
		var before = watched.map(func(c): return c.get_global_rect().position if c != null else Vector2(-1, -1))
		await _tap(plus)
		await ShotHelper.wait(tree, 0.3)
		picker = _find("band_of", null, "%d:0" % ci)
		check(picker != null and picker.band == "blue" and str(form.lift.exercises[ci].sets[0].band) == "blue", "heavier: green to blue, on the pill and in the workout")
		check(is_instance_valid(plus) and plus == _band_key(ci, 0, "heavier"), "the same key is still there (nothing was rebuilt)")
		var moved = 0
		for k in range(watched.size()):
			if watched[k] != null and is_instance_valid(watched[k]) and watched[k].get_global_rect().position.distance_to(before[k]) >= 1.0:
				moved += 1
		check(moved == 0, "no key on the card moved (%d did)" % moved)
		await ShotHelper.snap(tree, "bands_1_picker")

	# + Set copies the band; +1 band makes every set one heavier.
	var add_set = ShotHelper.find_button(_card(ci), "+ Set")
	if add_set != null:
		await _tap(add_set)
		await ShotHelper.wait(tree, 0.5)
	check(form.lift.exercises[ci].sets.size() == 2 and str(form.lift.exercises[ci].sets[1].get("band", "")) == "blue", "+ Set copies the last set, band and all")
	var bump = _find("band_bump", _card(ci))
	check(bump != null, "+1 band is in the card's keys")
	if bump != null:
		await _tap(bump)
		await ShotHelper.wait(tree, 0.5)
	check(form.lift.exercises[ci].sets.all(func(s): return str(s.get("band", "")) == "black"), "+1 band: every set one band heavier (blue to black)")

	# A lift that says band starts with one; the face pull compares with last time.
	form.lift.add_exercise(APART)
	form.lift.add_exercise(face)
	await ShotHelper.wait(tree, 0.5)
	var ai = _index(form, "Pull-Apart")
	var fi = _index(form, "Face Pull")
	check(ai >= 0 and bool(form.lift.exercises[ai].get("band", false)) and _find("band_of", null, "%d:0" % ai) != null, "Pull-Apart starts with a band")
	check(fi >= 0 and bool(form.lift.exercises[fi].get("band", false)) and str(form.lift.exercises[fi].sets[0].band) == "green" and ShotHelper.all_text(_card(fi)).contains("Last 15, 15, 12 · green band"), "the face pull comes back with last time's bands, said in words")
	if ai >= 0:
		form.lift._on_set_text("20", ai, 0, "reps")
	if fi >= 0:
		var fplus = _band_key(fi, 0, "heavier")
		if fplus != null:
			await _tap(fplus)
			await ShotHelper.wait(tree, 0.3)
		var badge = form.lift._badges[fi][0]
		check(ShotHelper.all_text(badge).contains("+1 band"), "a heavier band than that set last time: +1 band (%s)" % ShotHelper.all_text(badge))
		var card = _card(fi)
		if card != null:
			ShotHelper.reveal(card)
			await ShotHelper.wait(tree, 0.3)
		await ShotHelper.snap(tree, "bands_2_face_pull")

	# --- the PT key: an exercise marked as physical therapy while it is added ----------------
	if ai >= 0:
		var ptk = _find("pt_chip", _card(ai))
		check(ptk != null and not bool(ptk.get_meta("pt_chip")), "the Pull-Apart card has a PT key, off")
		if ptk != null:
			ShotHelper.reveal(ptk)
			await ShotHelper.frames(tree, 4)
			ptk = _find("pt_chip", _card(ai))
			var pat = ptk.get_global_rect().position
			await _tap(ptk)
			await ShotHelper.wait(tree, 0.5)
			ptk = _find("pt_chip", _card(ai))
			check(ptk != null and bool(ptk.get_meta("pt_chip")) and ptk.get_global_rect().position.distance_to(pat) < 1.0, "tapped: PT is on, and the key stayed under the finger")
			check(_find("pt_hint", _card(ai)) != null, "a line says it will be saved as a PT exercise")
			await ShotHelper.snap(tree, "bands_2b_pt_key")

	# --- saved -------------------------------------------------------------------------------
	var fin = ShotHelper.find_button(main, "Finish session")
	if fin != null:
		ShotHelper.press(fin)
	await ShotHelper.wait(tree, 0.6)
	var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
	if yes != null:
		ShotHelper.press(yes)
		await ShotHelper.wait(tree, 0.6)
	await _dismiss_reels()
	var done = App.lift_today()
	check(done != null and done.exercises.size() == 3, "the workout is saved")
	if done == null:
		print("BANDS WALK: %d failed" % fails)
		return
	var curl_ex = done.exercises.filter(func(ex): return str(ex.name).begins_with("Bicep Curl"))
	check(curl_ex.size() == 1 and curl_ex[0].sets.size() == 2 and curl_ex[0].sets.all(func(one): return str(one.get("band", "")) == "black" and float(one.weightKg) == 0.0), "the curl's sets: weight 0 and the black band")
	check(done.exercises.all(func(ex): return ex.sets.all(func(one): return Bands.is_band(one) and float(one.weightKg) == 0.0)), "every set of the workout has its band and no weight")
	var apart_ex = done.exercises.filter(func(ex): return str(ex.name).begins_with("Pull-Apart"))
	check(apart_ex.size() == 1 and Pt.is_pt(App.pt(), str(apart_ex[0].name)) and not apart_ex[0].has("pt"), "the Pull-Apart is a PT exercise now, marked from its card")

	# --- the session's sheet ------------------------------------------------------------------
	SessionView.open(done)
	await ShotHelper.wait(tree, 0.9)
	var sh = _sheet()
	var all = ShotHelper.all_text(sh) if sh != null else ""
	check(all.contains("black band") and all.contains("blue band") and _all("band_sets", sh).size() == 3, "the session's sheet says each lift's bands, with their colour")
	check(all.contains("+1 band"), "and the face pull's tag says a band more than last time")
	await ShotHelper.snap(tree, "bands_3_session")
	await _close_sheets()

	# --- the lift's page ----------------------------------------------------------------------
	JourneyLifts.open_named(face, {"view": "compare"})
	await ShotHelper.wait(tree, 0.9)
	sh = _sheet()
	all = ShotHelper.all_text(sh) if sh != null else ""
	check(all.contains("× green band") and all.contains("× blue band"), "Compare: last time and this time in bands")
	check(_find("next_band", sh) != null, "Next time names a band")
	check(not all.contains("GHOST") and not all.contains("STRENGTH LEVEL"), "no ghost duel and no strength level for a band lift")
	await ShotHelper.snap(tree, "bands_4_compare")
	var prog = ShotHelper.find_button(sh, "Progress")
	if prog != null:
		ShotHelper.reveal(prog)
		await ShotHelper.frames(tree, 3)
		ShotHelper.press(prog)
	await ShotHelper.wait(tree, 0.6)
	all = ShotHelper.all_text(sh)
	var rec = _find("band_record", sh)
	check(rec != null and str(rec.get_meta("band_record")) == "blue", "Progress: the heaviest band is a record (%s)" % (str(rec.get_meta("band_record")) if rec != null else "-"))
	check(all.contains("Heaviest band"), "and the chart is of the heaviest band")
	await ShotHelper.snap(tree, "bands_5_progress")
	var logb = ShotHelper.find_button(sh, "Logbook")
	if logb != null:
		ShotHelper.reveal(logb)
		await ShotHelper.frames(tree, 3)
		ShotHelper.press(logb)
	await ShotHelper.wait(tree, 0.6)
	var blocks = []
	for n in ShotHelper.walk(sh):
		if n is SetBlocks:
			blocks.append(n)
	check(blocks.size() >= 3 and blocks.all(func(b): return b.mode == "band"), "Logbook: every day as band blocks")
	await ShotHelper.snap(tree, "bands_6_logbook")
	await _close_sheets()

	print("BANDS WALK: %d failed" % fails)
