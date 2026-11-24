extends RefCounted
## "From today's plan" in the Log tab's lift form (run with the "year" data,
## also with --fingers): the day's planned lifts as keys in the form. One tap
## puts a lift into the workout with last time's sets, a second takes it back
## while it is untouched; a lift with the player's own numbers stays; the other
## way to do a lift is a chip; a key never moves from under the pointer; the
## card folds away; a lift saved today shows as done; a workout of another day
## has no card. And the up / down keys of an exercise card: one tap moves the
## exercise one place, the key stays under the pointer so a second tap moves
## the same exercise again, and where the page cannot follow (a move to the
## top) a second tap in that moment does nothing. Prints CHECK lines.

const BENCH = "Bench Press - Barbell"
const DUMBBELL = "Bench Press - Dumbbell"
const PRESS = "Overhead Press - Barbell"
const STRETCH = "Hamstring Stretch"

var main: Node
var tree: SceneTree
var fails = 0
var _finger = 60


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


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


func _with_meta(meta: String, value = null):
	for n in ShotHelper.walk(main):
		if n.has_meta(meta) and (value == null or str(n.get_meta(meta)) == str(value)):
			return n
	return null


func _pick(lift: String):
	return _with_meta("plan_pick", lift)


func _way(lift: String):
	return _with_meta("plan_way", lift)


func _state(b) -> String:
	return str(b.get_meta("plan_state")) if b != null else "-"


func _names() -> Array:
	var f = _form()
	return f.lift.exercises.map(func(e): return str(e.name)) if f != null else []


## The up / down key of an exercise of the workout.
func _move(lift: String, dir: String):
	var at = _names().find(lift)
	for n in ShotHelper.walk(main):
		if n is Button and n.has_meta("move_key") and str(n.get_meta("move_key")) == dir and int(n.get_meta("move_of")) == at:
			return n
	return null


func _field(key: String):
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.has_meta(LogWidgets.FKEY) and str(n.get_meta(LogWidgets.FKEY)) == key:
			return n
	return null


## A finger's tap (real touch events, for TouchScroll): down, up a moment later.
func _finger_tap(p: Vector2) -> void:
	_finger += 1
	for down in [true, false]:
		var ev = InputEventScreenTouch.new()
		ev.index = _finger
		ev.pressed = down
		ev.position = main.get_viewport().get_final_transform() * p
		Input.parse_input_event(ev)
		await ShotHelper.wait(tree, 0.07 if down else 0.3)


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


## A real click on a key, with the pointer left where it is: the key has to be
## under it on every frame after. `at_y`: scroll first so the key is at this
## height of the window (room for the page to follow a card that goes up).
func tap(find: Callable, what: String, at_y: float = -1.0) -> void:
	var b = find.call()
	check(b != null, "found the key of %s" % what)
	if b == null:
		return
	if at_y >= 0.0:
		main._scroll.scroll_vertical += int(b.get_global_rect().get_center().y - at_y)
	else:
		ShotHelper.reveal(b)
	await ShotHelper.frames(tree, 4)
	b = find.call()
	var pos = b.get_global_rect().get_center()
	await _move_to(pos)
	await _click_at(pos)
	var missed = 0
	var worst = 0.0
	for f in range(12):
		var nb = find.call()
		if nb == null or not nb.get_global_rect().has_point(pos):
			missed += 1
		else:
			worst = maxf(worst, absf(nb.get_global_rect().get_center().y - pos.y))
		await tree.process_frame
	check(missed == 0 and worst <= 1.5, "the key of %s stayed under the pointer (%d frames off, %.1f px)" % [what, missed, worst])
	await ShotHelper.wait(tree, 0.45)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	# The demo player trains by the weekday: take out what it did on this
	# weekday, today included, so the day's plan is this walkthrough's own.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	App.replace_all(clean)
	await ShotHelper.wait(tree, 0.6)
	App.update_settings({"weightUnit": "lb"})
	# Lifts done on this weekday the last two weeks, and the bench once with
	# dumbbells on another day: a second way to do it.
	var habit = []
	for wk in [14, 7]:
		habit.append({"id": "habit%d" % wk, "discipline": "lift", "date": Dates.add_days(App.today, -wk), "createdAt": App.now_ms() - wk * 86400000, "source": "manual",
			"exercises": [{"name": BENCH, "sets": [{"reps": 5, "weightKg": 60.0}, {"reps": 5, "weightKg": 60.0}]},
				{"name": PRESS, "sets": [{"reps": 8, "weightKg": 40.0}, {"reps": 8, "weightKg": 40.0}]},
				{"name": STRETCH, "sets": [{"reps": 3, "weightKg": 0.0, "holdSec": 30}]}]})
	habit.append({"id": "other_way", "discipline": "lift", "date": Dates.add_days(App.today, -10), "createdAt": App.now_ms() - 10 * 86400000, "source": "manual",
		"exercises": [{"name": DUMBBELL, "sets": [{"reps": 8, "weightKg": 22.0}, {"reps": 8, "weightKg": 22.0}]}]})
	App.commit_sessions(habit, "Workout logged!")
	await _dismiss_reels()
	App.set_pt(STRETCH, true)
	await ShotHelper.wait(tree, 0.4)

	# --- an empty workout: the plan first ---------------------------------------------------------
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	var form = _form()
	check(App.tab == "log" and form != null and form.discipline == "lift" and form.editing == null and form.lift.exercises.is_empty(), "a new, empty lift in the Log tab")
	var rows = Missions.picks(App.plan(), App.sessions(), App.today)
	print("PICKS ", rows.map(func(r): return "%s [%s] %s" % [r.name, r.kind, str(r.ways.map(func(w): return str(w.word)))]))
	var card = _with_meta("plan_card")
	check(card != null and ShotHelper.find_text(card, "From today's plan") != null, "the form has a From today's plan card")
	check(_pick(BENCH) != null and _pick(PRESS) != null and _pick(STRETCH) != null, "with a key for each planned lift")
	check(rows.all(func(r): return _pick(str(r.name)) != null and _state(_pick(str(r.name))) == "add"), "every row of the plan has its key, none in the workout yet (%d rows)" % rows.size())
	var dumb = _way(DUMBBELL)
	check(dumb != null and str(dumb.text) == "Dumbbell" and _state(dumb) == "add", "the bench has its other way as a chip (%s)" % (str(dumb.text) if dumb != null else "-"))
	var said = ShotHelper.all_text(card) if card != null else ""
	check(said.contains("AIM") and said.contains("AS LAST TIME") and said.contains("PROBABLY TODAY"), "a row says what to aim for; the stretch is PT, as last time")
	var picker = ShotHelper.find_text(main, "Add exercise")
	check(card != null and picker != null and card.global_position.y < picker.global_position.y, "it comes before Add exercise")
	await ShotHelper.snap(tree, "picks_1_empty")

	# --- one tap adds, with last time's sets ----------------------------------------------------------
	await tap(func(): return _pick(BENCH), "the bench")
	form = _form()
	check(_names() == [BENCH] and bool(form.lift.exercises[0].get("planned", false)) and form.lift.exercises[0].sets.size() == 2 and str(form.lift.exercises[0].sets[0].reps) == "5" and str(form.lift.exercises[0].sets[0].weight) != "", "one tap: the bench is in the workout with last time's two sets (%s)" % str(_names()))
	check(_state(_pick(BENCH)) == "in" and _state(_pick(PRESS)) == "add", "its key is ticked, the others are not")
	card = _with_meta("plan_card")
	var ex_card = _with_meta("exercise_card", 0)
	check(card != null and ex_card != null and ex_card.global_position.y < card.global_position.y, "the exercise is above the plan, the plan above Add exercise")
	await tap(func(): return _pick(PRESS), "the press")
	check(_names() == [BENCH, PRESS], "a second lift, without leaving the form (%s)" % str(_names()))
	await tap(func(): return _pick(STRETCH), "the stretch")
	form = _form()
	check(_names() == [BENCH, PRESS, STRETCH] and bool(form.lift.exercises[2].get("timed", false)) and str(form.lift.exercises[2].sets[0].get("hold", "")) == "30", "the stretch comes with its 30 seconds")
	check(int(_with_meta("plan_count").get_meta("plan_count")) == 3, "the card counts what is seen to (%s)" % str(_with_meta("plan_count").get_meta("plan_count")))
	ShotHelper.reveal(_with_meta("plan_card"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "picks_2_three_in")

	# --- a second tap takes an untouched lift back ----------------------------------------------------
	await tap(func(): return _pick(BENCH), "the bench again")
	check(_names() == [PRESS, STRETCH] and _state(_pick(BENCH)) == "add", "a second tap takes an untouched lift back out (%s)" % str(_names()))

	# --- the other way to do it -----------------------------------------------------------------------
	await tap(func(): return _way(DUMBBELL), "the dumbbell way")
	check(_names() == [PRESS, STRETCH, DUMBBELL] and _state(_way(DUMBBELL)) == "in" and _state(_pick(BENCH)) == "add", "the chip adds that way of the lift, not the planned one (%s)" % str(_names()))
	form = _form()
	check(str(form.lift.exercises[2].sets[0].reps) == "8", "with its own last sets")
	await tap(func(): return _way(DUMBBELL), "the dumbbell way again")
	check(_names() == [PRESS, STRETCH] and _state(_way(DUMBBELL)) == "add", "and takes it back")

	# --- a lift with the player's own numbers stays ----------------------------------------------------
	var rf = _field("ex0.s0.reps")
	if rf != null:
		ShotHelper.type_into(rf, "9")
	await ShotHelper.wait(tree, 0.4)
	form = _form()
	check(not bool(form.lift.exercises[0].get("planned", false)), "typing a number makes the press mine")
	await tap(func(): return _pick(PRESS), "a lift with my numbers")
	form = _form()
	check(_names() == [PRESS, STRETCH] and str(form.lift.exercises[0].sets[0].reps) == "9", "its key does not take it out (%s)" % str(_names()))
	check(ShotHelper.find_text(main, "has your sets") != null, "and says where to take it out instead")
	await ShotHelper.snap(tree, "picks_3_kept")
	await ShotHelper.wait(tree, 2.5)

	# --- up and down in the workout's order (two lifts done in turn) ---------------------------------
	check(_move(PRESS, "up") != null and _move(PRESS, "up").disabled and not _move(PRESS, "down").disabled and _move(STRETCH, "down").disabled and not _move(STRETCH, "up").disabled, "every exercise has an up and a down key: the first cannot go up, the last cannot go down")
	var fly = str(App.plan().new.name) if App.plan().new != null else ""
	check(fly != "", "the plan has a movement to try (%s)" % fly)
	await tap(func(): return _pick(BENCH), "the bench, back in", 300.0)
	await tap(func(): return _way(DUMBBELL), "the dumbbell way, in as well", 300.0)
	await tap(func(): return _pick(fly), "the movement to try", 300.0)
	check(_names() == [PRESS, STRETCH, BENCH, DUMBBELL, fly], "five exercises (%s)" % str(_names()))
	var press_before = JSON.stringify(_form().lift.exercises.filter(func(e): return str(e.name) == PRESS))
	await tap(func(): return _move(fly, "up"), "the last exercise, one up", 300.0)
	check(_names() == [PRESS, STRETCH, BENCH, fly, DUMBBELL], "one tap on its up key moves it one place up (%s)" % str(_names()))
	await tap(func(): return _move(fly, "up"), "the same exercise, up again", 300.0)
	check(_names() == [PRESS, STRETCH, fly, BENCH, DUMBBELL], "its key stayed under the pointer: a second tap moves the same exercise again (%s)" % str(_names()))
	await tap(func(): return _move(PRESS, "down"), "the first exercise, one down")
	check(_names() == [STRETCH, PRESS, fly, BENCH, DUMBBELL] and _move(STRETCH, "up").disabled and not _move(PRESS, "up").disabled, "the down key moves one place down (%s)" % str(_names()))
	form = _form()
	check(JSON.stringify(form.lift.exercises.filter(func(e): return str(e.name) == PRESS)) == press_before and str(form.lift.exercises[1].sets[0].reps) == "9" and bool(form.lift.exercises[3].get("planned", false)) and not bool(form.lift.exercises[1].get("planned", false)), "an exercise takes its sets with it, and stays planned or mine as it was")
	ShotHelper.reveal(_with_meta("exercise_card", 1))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "picks_3b_moved")
	# Up to the first place with the page at its top: the page cannot follow, so
	# the key is no longer under the pointer. The other exercise's up key is
	# there now: a second tap in that moment must not move it back.
	main._scroll.scroll_vertical = 0
	await ShotHelper.frames(tree, 4)
	var up_key = _move(PRESS, "up")
	var at_pos = up_key.get_global_rect().get_center()
	await _move_to(at_pos)
	await _click_at(at_pos)
	await ShotHelper.frames(tree, 3)
	check(_names() == [PRESS, STRETCH, fly, BENCH, DUMBBELL] and _move(PRESS, "up").disabled, "up to the first place (%s)" % str(_names()))
	check(not _move(PRESS, "up").get_global_rect().has_point(at_pos), "the page was at its top: the key could not stay under the pointer")
	var as_it_is = JSON.stringify(_form().lift.exercises)
	await _click_at(at_pos)
	await ShotHelper.frames(tree, 3)
	check(JSON.stringify(_form().lift.exercises) == as_it_is, "a second tap in that moment, on whatever is there now, changes nothing (%s)" % str(_names()))
	await ShotHelper.wait(tree, 0.5)
	await _click_at(at_pos)
	await ShotHelper.frames(tree, 3)
	check(JSON.stringify(_form().lift.exercises) != as_it_is, "a moment later a tap counts again (%s)" % str(_names()))
	await ShotHelper.wait(tree, 0.5)
	# Back to the two lifts, in the order they had.
	form = _form()
	form.lift.exercises = form.lift.exercises.filter(func(e): return [PRESS, STRETCH].has(str(e.name)))
	form.lift.exercises.sort_custom(func(a, b): return str(a.name) == PRESS and str(b.name) != PRESS)
	form.lift._changed(true)
	await ShotHelper.wait(tree, 0.6)
	check(_names() == [PRESS, STRETCH], "back to the two lifts (%s)" % str(_names()))

	# --- folded away, and back ------------------------------------------------------------------------
	var fold = _with_meta("plan_fold")
	check(fold != null and str(fold.text) == "Hide", "the card has a Hide key")
	if fold != null:
		ShotHelper.press(fold)
	await ShotHelper.wait(tree, 0.5)
	check(_with_meta("plan_card") != null and _pick(BENCH) == null and str(_with_meta("plan_fold").text) == "Show", "Hide folds it to its header")
	await ShotHelper.snap(tree, "picks_4_folded")
	ShotHelper.press(_with_meta("plan_fold"))
	await ShotHelper.wait(tree, 0.5)
	check(_pick(BENCH) != null, "Show brings the keys back")

	# --- saved: done today ----------------------------------------------------------------------------
	# (the stretch is still as it was filled in: the form asks about it once)
	var save = ShotHelper.find_button(main, "Finish session")
	check(save != null and not save.disabled, "the workout can be finished")
	if save != null:
		ShotHelper.press(save)
	await ShotHelper.wait(tree, 0.6)
	var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
	check(yes != null, "the stretch, still as it was filled in, is asked about before saving")
	if yes != null:
		ShotHelper.press(yes)
	await ShotHelper.wait(tree, 0.6)
	await _dismiss_reels()
	var saved_today = App.sessions().filter(func(s): return str(s.date) == App.today and str(s.discipline) == "lift")
	check(saved_today.size() == 1 and saved_today[0].exercises.size() == 2, "the workout is saved (%d session, %s)" % [saved_today.size(), str(saved_today[0].exercises.map(func(e): return str(e.name)) if not saved_today.is_empty() else [])])
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	check(_names().is_empty() and _state(_pick(PRESS)) == "done" and _state(_pick(STRETCH)) == "done" and _state(_pick(BENCH)) == "add", "a new lift today: what was saved is done, the bench is still to add")
	card = _with_meta("plan_card")
	check(card != null and ShotHelper.all_text(card).contains("DONE TODAY"), "and says so")
	await ShotHelper.snap(tree, "picks_5_done")
	# The saved workout opened again: its lifts are in the form, not "done".
	if not saved_today.is_empty():
		App.open_log("lift", saved_today[0].id)
		await ShotHelper.wait(tree, 0.9)
		check(_names() == [PRESS, STRETCH] and _state(_pick(PRESS)) == "in" and _state(_pick(BENCH)) == "add", "the saved workout opened again: its lifts are in it (%s)" % str(_names()))
		await tap(func(): return _pick(BENCH), "the bench, into the saved workout")
		check(_names() == [PRESS, STRETCH, BENCH], "and the bench can be added to it")

	# --- another day's workout has no plan --------------------------------------------------------------
	var older = null
	for s in App.sessions():
		if str(s.discipline) == "lift" and str(s.date) < App.today and (older == null or str(s.date) > str(older.date)):
			older = s
	if older != null:
		App.open_log("lift", older.id)
		await ShotHelper.wait(tree, 0.9)
		check(_form() != null and _form().editing != null and _with_meta("plan_card") == null, "a workout of another day has no plan card")
	# --- the date of the workout: the plan is for today only -------------------------------------------
	App.open_log(null)
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	check(_form() != null and _form().editing == null and _with_meta("plan_card") != null, "a new lift dated today has the plan card")
	_form()._set_date(Dates.add_days(App.today, -1))
	await ShotHelper.wait(tree, 0.5)
	check(_with_meta("plan_card") == null and str(_form().date) == Dates.add_days(App.today, -1), "dated yesterday: the card goes at once")
	_form()._set_date(App.today)
	await ShotHelper.wait(tree, 0.5)
	check(_with_meta("plan_card") != null, "dated today again: it is back")

	# --- with a finger (TouchScroll, real touch events) ---------------------------------------------------
	Engine.max_fps = 120
	var ts = TouchScroll.new()
	main.add_child(ts)
	App.open_log(null)
	App.open_log("lift")
	await ShotHelper.wait(tree, 0.9)
	check(_form() != null and _form().editing == null and _names().is_empty() and _state(_pick(BENCH)) == "add", "a new lift, the bench still to add")
	var bk = _pick(BENCH)
	if bk != null:
		ShotHelper.reveal(bk)
		await ShotHelper.frames(tree, 4)
		var fp = _pick(BENCH).get_global_rect().get_center()
		await _finger_tap(fp)
		check(_names() == [BENCH] and _state(_pick(BENCH)) == "in" and _pick(BENCH).get_global_rect().has_point(fp), "a finger's tap adds the bench, and its key is still under the finger (%s)" % str(_names()))
		await ShotHelper.wait(tree, 0.5)
		await _finger_tap(fp)
		check(_names().is_empty() and _state(_pick(BENCH)) == "add" and _pick(BENCH).get_global_rect().has_point(fp), "a second tap takes it back, the key still there (%s)" % str(_names()))
		await ShotHelper.wait(tree, 0.5)
		check(main.get_viewport().gui_get_hovered_control() == null, "and nothing is left hovered")
	ts.queue_free()
	App.draft_store("lift", null)
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("PICKS WALK: %d failed" % fails)
