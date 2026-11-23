extends RefCounted
## Starting the day's workout from the Today card (run with the "year" data):
## "Start workout" opens the Log tab with the planned lifts and last time's
## sets; the workout is kept as it is typed and comes back after the app was
## closed; a hold's seconds can be typed; lifts never touched are asked about
## before saving; and every tab at finger sizes (Kit.fingers) still fits.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


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


func _home() -> void:
	App.go("home")
	await ShotHelper.wait(tree, 0.8)


func _start_key():
	for n in ShotHelper.walk(main):
		if n is Button and n.has_meta("start_workout"):
			return n
	return null


func _log_screen():
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n
	return null


func _field(key: String):
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.has_meta(LogWidgets.FKEY) and str(n.get_meta(LogWidgets.FKEY)) == key:
			return n
	return null


func _index_of(form, part: String) -> int:
	for i in range(form.lift.exercises.size()):
		if str(form.lift.exercises[i].name).contains(part):
			return i
	return -1


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	# The demo player trains by the weekday (lifts on Mondays and Fridays, a run
	# on Tuesdays...): take out what it did on this weekday, today included, so
	# the day's plan is this walkthrough's own whatever day it runs on.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	App.replace_all(clean)
	await ShotHelper.wait(tree, 0.6)
	App.update_settings({"weightUnit": "lb"})
	# Lifts done on this weekday the last two weeks (a bench, and a stretch that
	# is held), so today has likely lifts whatever day this runs on.
	var habit = []
	for wk in [14, 7]:
		habit.append({"id": "habit%d" % wk, "discipline": "lift", "date": Dates.add_days(App.today, -wk), "createdAt": App.now_ms() - wk * 86400000, "source": "manual",
			"exercises": [{"name": "Bench Press - Barbell", "sets": [{"reps": 5, "weightKg": 60.0}, {"reps": 5, "weightKg": 60.0}]},
				{"name": "Overhead Press - Barbell", "sets": [{"reps": 8, "weightKg": 40.0}, {"reps": 8, "weightKg": 40.0}]},
				{"name": "Hamstring Stretch", "sets": [{"reps": 3, "weightKg": 0.0, "holdSec": 30}]}]})
	App.commit_sessions(habit, "Workout logged!")
	await _dismiss_reels()
	await _home()
	var plan = App.plan()
	var names = TodayView.workout_names(plan)
	print("PLAN ", plan.lifts.map(func(l): return str(l.name)), " -> ", names)
	var key = _start_key()
	check(key != null and key.text == "Start workout", "the Today card has a Start workout key")
	check(names.size() >= 2 and names.has("Bench Press - Barbell") and names.has("Hamstring Stretch"), "it will send the day's lifts (%s)" % str(names))
	if key != null:
		ShotHelper.reveal(key)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "workout_1_today")
		ShotHelper.press(key)
	await ShotHelper.wait(tree, 0.9)
	var ls = _log_screen()
	var form = ls.form() if ls != null else null
	check(App.tab == "log" and form != null and form.discipline == "lift" and form.editing == null, "it opens the Log tab on a new lift")
	if form == null:
		return
	check(form.lift.exercises.size() == names.size() and form.lift.exercises.all(func(e): return bool(e.get("planned", false))), "with every planned lift on it (%d)" % form.lift.exercises.size())
	var bi = _index_of(form, "Bench Press")
	var hi = _index_of(form, "Hamstring")
	check(bi >= 0 and form.lift.exercises[bi].sets.size() == 2 and str(form.lift.exercises[bi].sets[0].reps) == "5" and str(form.lift.exercises[bi].sets[0].weight) != "", "the bench has last time's two sets filled in (%s)" % str(form.lift.exercises[bi].sets if bi >= 0 else []))
	check(hi >= 0 and bool(form.lift.exercises[hi].get("timed", false)) and str(form.lift.exercises[hi].sets[0].get("hold", "")) == "30", "the stretch is a hold with its 30 seconds")
	var hf = _field("ex%d.s0.hold" % hi)
	check(hf != null and hf.text == "30", "its seconds are a field of their own")
	check(_field("ex%d.s0.weight" % hi) == null and _field("ex%d.s0.weight" % bi) != null, "a hold has no weight field, the bench has")
	await ShotHelper.snap(tree, "workout_2_started")

	# Touch the bench: one more rep. It is no longer "planned".
	var rf = _field("ex%d.s0.reps" % bi)
	if rf != null:
		ShotHelper.type_into(rf, "6")
	await ShotHelper.wait(tree, 0.4)
	check(not bool(form.lift.exercises[bi].get("planned", false)) and bool(form.lift.exercises[hi].get("planned", false)), "a touched lift is no longer planned, the others still are")
	# Hold the stretch longer.
	hf = _field("ex%d.s0.hold" % hi)
	if hf != null:
		ShotHelper.type_into(hf, "45")
	await ShotHelper.wait(tree, 0.4)

	# The workout is kept as it is typed: the app closed and opened again.
	check(FileAccess.file_exists(App.DATA_DIR + "draft-lift.json"), "the workout is kept in a file as it is typed")
	App.open_log(null)
	await ShotHelper.wait(tree, 0.5)
	await _home()
	key = _start_key()
	check(key != null and key.text == "Continue workout", "the Today card now says Continue workout")
	if key != null:
		ShotHelper.press(key)
	await ShotHelper.wait(tree, 0.9)
	ls = _log_screen()
	form = ls.form() if ls != null else null
	check(form != null and form.restored and form.lift.exercises.size() == names.size(), "it comes back as it was left (%d lifts)" % (form.lift.exercises.size() if form != null else -1))
	bi = _index_of(form, "Bench Press")
	hi = _index_of(form, "Hamstring")
	check(str(form.lift.exercises[bi].sets[0].reps) == "6" and str(form.lift.exercises[hi].sets[0].hold) == "45", "with the 6 reps and the 45 seconds")
	check(ShotHelper.find_text(main, "Picked up where you left off") != null and ShotHelper.find_button(main, "Start over") != null, "and says so, with Start over")
	await ShotHelper.snap(tree, "workout_3_restored")

	# Finish: the lifts never touched are asked about first.
	var others = form.lift.planned_names()
	var fin = ShotHelper.find_button(main, "Finish session")
	ShotHelper.press(fin)
	await ShotHelper.wait(tree, 0.6)
	var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
	check(not others.is_empty() and yes != null, "untouched planned lifts are asked about before saving (%s)" % str(others))
	check(App.lift_today() == null, "nothing is saved until the answer")
	if yes != null:
		await ShotHelper.snap(tree, "workout_4_asked")
		ShotHelper.press(yes)
	await ShotHelper.wait(tree, 0.6)
	await _dismiss_reels()
	var done = App.lift_today()
	check(done != null and done.exercises.size() == names.size(), "the workout is saved with all its lifts")
	if done != null:
		var st = done.exercises.filter(func(e): return str(e.name).contains("Hamstring"))
		var bn = done.exercises.filter(func(e): return str(e.name).contains("Bench Press"))
		check(st.size() == 1 and int(st[0].sets[0].get("holdSec", 0)) == 45 and float(st[0].sets[0].weightKg) == 0.0, "the hold is saved with its 45 seconds (%s)" % str(st[0].sets if not st.is_empty() else []))
		check(bn.size() == 1 and int(bn[0].sets[0].reps) == 6 and int(bn[0].sets[1].reps) == 5, "the bench with 6 and 5 reps")
	check(not FileAccess.file_exists(App.DATA_DIR + "draft-lift.json"), "the kept draft is gone once saved")
	await _home()
	check(_start_key() == null or TodayView.workout_names(App.plan()).is_empty() == (_start_key() == null), "no Start key once the day's lifts are done (%s left)" % str(TodayView.workout_names(App.plan())))

	# A hold switched on by hand: a new exercise becomes seconds.
	App.open_log("lift", done.id if done != null else null)
	await ShotHelper.wait(tree, 0.8)
	ls = _log_screen()
	form = ls.form()
	bi = _index_of(form, "Bench Press")
	form.lift._toggle_timed(bi)
	await ShotHelper.wait(tree, 0.5)
	check(_field("ex%d.s0.hold" % bi) != null and _field("ex%d.s0.weight" % bi) == null, "the Hold key swaps the weight for seconds")
	form.lift._toggle_timed(bi)
	await ShotHelper.wait(tree, 0.5)
	check(_field("ex%d.s0.weight" % bi) != null and _field("ex%d.s0.weight" % bi).text != "", "and back, the weight still there")

	# Finger sizes: every tab still fits its column (snap checks the widths).
	Kit.fingers = true
	App.open_log(null)
	App.open_log("lift", done.id if done != null else null)
	await ShotHelper.wait(tree, 0.8)
	var keys_ok = true
	var n_keys = 0
	for n in ShotHelper.walk(main):
		if n is Stepper:
			for ch in n.get_children():
				if ch is Button:
					n_keys += 1
					if ch.custom_minimum_size.x < 40.0 or ch.custom_minimum_size.y < 40.0:
						keys_ok = false
	check(n_keys > 0 and keys_ok, "at finger size every − / + key is at least 40 wide and tall (%d keys)" % n_keys)
	await ShotHelper.snap(tree, "workout_5_fingers_lift")
	App.open_log("climb")
	await ShotHelper.wait(tree, 0.8)
	await ShotHelper.snap(tree, "workout_6_fingers_climb")
	App.open_log("run")
	await ShotHelper.wait(tree, 0.8)
	await ShotHelper.snap(tree, "workout_7_fingers_run")
	App.open_log("body")
	await ShotHelper.wait(tree, 0.8)
	await ShotHelper.snap(tree, "workout_8_fingers_body")
	App.open_log(null)
	for tab in ["home", "adventure", "journey", "armory", "log"]:
		App.go(tab)
		await ShotHelper.wait(tree, 0.9)
		await ShotHelper.snap(tree, "workout_9_fingers_%s" % tab)
	Kit.fingers = false
	print("WORKOUT DONE fails=%d" % fails)
