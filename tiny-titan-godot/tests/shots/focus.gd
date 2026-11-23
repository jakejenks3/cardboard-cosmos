extends RefCounted
## The training focus (run with the "new" data: it makes its own log): a chest
## that only gets flyes on a push day gets a press added first, with other ways
## to do it; the weekly sets row and its sheet; the missions; a rest day when
## one is due; a leg day (nothing added, goals to beat as ever); the run that grows; the
## Settings card. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


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
	await ShotHelper.wait(tree, 0.4)


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


func _find(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _three(reps: int, kg: float) -> Array:
	return [{"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}]


func _lift(back: int, exercises: Dictionary) -> Dictionary:
	var exs = []
	for name in exercises:
		exs.append({"name": name, "sets": exercises[name]})
	return App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -back), "exercises": exs})


## Two weeks of pull, push, legs with flyes as the only chest work. `rest_back`:
## the day (days ago) left out as a rest day, or -1 for none in the last week.
func _log(rest_back: int) -> Array:
	var push = {"Chest Fly - Cable": _three(12, 15.0), "Arnold Press - Dumbbell": _three(8, 20.0), "Lateral Raise - Dumbbell": _three(12, 8.0), "Tricep Pushdown": _three(10, 30.0)}
	var pull = {"Bent Over Row - Barbell": _three(8, 60.0), "Lat Pulldown": _three(10, 50.0), "Bicep Curl - Dumbbell": _three(10, 12.0)}
	var legs = {"Squat - Barbell": _three(5, 100.0), "Romanian Deadlift - Barbell": _three(5, 80.0), "Calf Raise": _three(12, 60.0)}
	# Yesterday a pull day, so today is a push day; counting back: pull, legs, push...
	var kinds = [pull, legs, push]
	var out = []
	for back in range(1, 14):
		if back == rest_back:
			continue
		out.append(_lift(back, kinds[(back - 1) % 3]))
	for back in [2, 5, 9]:
		out.append(App.build_session({"discipline": "climb", "date": Dates.add_days(App.today, -back), "climbs": [{"grade": 3, "result": "send", "count": 4}, {"grade": 4, "result": "attempt", "count": 3}]}))
	out.append(App.build_session({"discipline": "run", "date": Dates.add_days(App.today, -7), "distanceM": 5000.0, "durationSec": 1800}))
	return out


func _load(rest_back: int, more: Dictionary = {}) -> void:
	var data = ShotHelper.demo_saved("new")
	data.sessions = _log(rest_back)
	data.settings.merge({"split": "pull_push_legs", "focus": "upper"}, true)
	data.settings.merge(more, true)
	App.replace_all(data)
	await ShotHelper.wait(tree, 0.8)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)

	# --- a push day: the chest is short and has no press ---------------------------------
	await _load(3)
	await _home()
	var plan = App.plan()
	print("PLAN ", plan.label, " | ", plan.lifts.map(func(l): return "%s%s" % ["+ " if l.has("dose") else "", l.name]), " | rest ", plan.rest, " | run ", plan.run)
	var text = ShotHelper.all_text(main)
	check(plan.kind == "push" and plan.lifts[0].has("dose") and str(plan.lifts[0].dose.part) == "chest" and bool(plan.lifts[0].dose.anchor), "a push day: the plan's first lift is a press for the chest")
	check(text.contains("YOUR FOCUS ADDS") and text.contains("FOR CHEST") and text.contains("ADD · %d SETS" % int(plan.lifts[0].dose.sets)) and text.contains("Bench Press"), "the Today card says so, before the usual lifts")
	check(_find("dose_row") != null and text.contains("LAST 7 DAYS · SETS") and text.contains("Chest") and text.contains("Triceps"), "the weekly sets of the day's muscles are on the card")
	check(_find("rest_row") == null and not bool(plan.rest.due), "no rest day yet (a day off three days ago)")
	check(text.contains("aim 5.5 km") and text.contains("Your run day") and text.contains("or quicker than 6:00 /km over 3.8 km"), "the run day: a little further than the last one, or quicker")
	await ShotHelper.snap(tree, "focus_1_home")
	var first = null
	for n in ShotHelper.walk(main):
		if n is Card and n.tooltip_text == "Last time, and what to beat":
			first = n
			break
	if first != null:
		ShotHelper.reveal(first)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "focus_1b_press_row")
	# The run day row, at the end of the card.
	for n in ShotHelper.walk(main):
		if n is Card and ShotHelper.all_text(n).begins_with("Running") and ShotHelper.all_text(n).contains("Your run day"):
			ShotHelper.reveal(n)
			await ShotHelper.frames(tree, 3)
			await ShotHelper.snap(tree, "focus_1c_run_row")
			break

	# The sheet behind the row.
	var row = _find("dose_row")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, row)
		await ShotHelper.wait(tree, 0.7)
		var st = ShotHelper.all_text(_sheet()) if _sheet() != null else ""
		check(st.contains("Upper body first") and st.contains("SHORT") and st.contains("from climbing") and st.contains("Next run: 5.5 km"), "its sheet: every muscle against its target, what counted, the next run")
		await ShotHelper.snap(tree, "focus_2_sheet")
		if _sheet() != null:
			ShotHelper.scroll_main(_sheet(), 600)
			await ShotHelper.wait(tree, 0.3)
			await ShotHelper.snap(tree, "focus_2b_sheet_lower")
		await _close_sheets()

	# The missions.
	App.go("adventure", "quests")
	await ShotHelper.wait(tree, 0.8)
	var at = ShotHelper.all_text(main)
	check(at.contains("Chest: add a press") and at.contains("Run a little further") and at.contains("Run a little faster") and at.contains("Dosed right") and not at.contains("Long run"), "missions: the press, the run's two goals, the week's Dosed right")
	await ShotHelper.snap(tree, "focus_3_missions")

	# Do the press: its box ticks, its mission is done.
	App.commit_sessions([App.build_session({"discipline": "lift", "date": App.today, "exercises": [{"name": "Bench Press - Incline dumbbell", "sets": [{"reps": 10, "weightKg": 22.5}, {"reps": 9, "weightKg": 22.5}, {"reps": 8, "weightKg": 22.5}, {"reps": 8, "weightKg": 22.5}, {"reps": 8, "weightKg": 22.5}]}]})], "Workout logged!")
	await _dismiss_reels()
	await _home()
	var dm = App.quests().daily.filter(func(m): return str(m.id).contains(":dose:chest"))
	check(dm.size() == 1 and bool(dm[0].done), "the press logged: its mission is done")
	check(Missions.lift_done(App.plan().lifts[0], App.plan(), App.sessions(), App.today) == "Bench Press - Incline dumbbell" and ShotHelper.all_text(main).contains("Incline dumbbell"), "its row is ticked, under the name it was done as")
	await ShotHelper.snap(tree, "focus_4_done")

	# --- five hard days in a row: a rest day --------------------------------------------------
	await _load(-1)
	await _home()
	plan = App.plan()
	text = ShotHelper.all_text(main)
	check(bool(plan.rest.due) and _find("rest_row") != null and text.contains("REST DAY"), "trained every day: the card opens with a rest day (%d in a row)" % int(plan.rest.run))
	check(App.quests().daily[0].get("rest", false) and not App.quests().daily.any(func(m): return str(m.id).ends_with(":show")), "and the day's first mission is to rest")
	await ShotHelper.snap(tree, "focus_5_rest")

	# --- a leg day: no sets added, goals to beat as ever ----------------------------------------
	await _load(3, {"dayPick": {"date": App.today, "kind": "legs"}})
	await _home()
	plan = App.plan()
	text = ShotHelper.all_text(main)
	check(plan.kind == "legs" and plan.lifts.all(func(l): return str(l.get("mode", "")) == "keep") and not plan.lifts.any(func(l): return l.has("dose")) and not text.contains("YOUR FOCUS ADDS") and text.contains("AIM"), "a leg day: nothing is added for the legs, and their lifts have an aim")
	check(App.quests().daily.filter(func(m): return str(m.title).begins_with("Beat it: ")).size() == 2, "its missions are Beat it, as for any lift")
	await ShotHelper.snap(tree, "focus_6_legs")

	# --- Settings -------------------------------------------------------------------------------------
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.6)
	var sec = _find("focus_section", _sheet())
	check(sec != null and ShotHelper.find_button(_sheet(), "Upper body first") != null and ShotHelper.find_button(_sheet(), "From my log") != null and ShotHelper.all_text(_sheet()).contains("Build up my weekly run") and ShotHelper.all_text(_sheet()).contains("Run day") and _find("run_days", _sheet()) != null, "Settings has Training focus, with the run switch and the run day")
	if sec != null:
		ShotHelper.reveal(sec)
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "focus_7_settings")
	# (the split's card has a "From my log" too: take the focus card's)
	var off = ShotHelper.find_button(sec, "From my log") if sec != null else null
	if off != null:
		ShotHelper.reveal(off)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, off)
		await ShotHelper.wait(tree, 0.6)
	check(Dose.plan_id(App.settings()) == "", "switched off in Settings")
	await _close_sheets()
	await _home()
	text = ShotHelper.all_text(main)
	check(_find("dose_row") == null and not text.contains("YOUR FOCUS ADDS") and not App.plan().lifts.any(func(l): return l.has("dose") or l.has("mode")), "off: the Today card is as it was")
	print("FOCUS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
