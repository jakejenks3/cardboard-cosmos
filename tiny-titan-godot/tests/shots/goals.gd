extends RefCounted
## Goals from the challenges and the prep into the workout (2026-11-28; run with "year" data, also --fingers).
## The user: "be able to pick and choose each a mission ahead of time that gets put into my prep and then into
## my workout once I start it... click on chest fly dumbbell for today because that's the equipment I have, and
## then click on the heavier challenge". The whole flow through the real UI:
##   1. the day's plan is this walkthrough's own (this weekday's demo sessions out, a bench habit in, done with
##      a barbell and once with dumbbells, in weights that are whole pounds);
##   2. the Hero tab: TODAY lists the day's lifts first, each once, then Prep today and Start workout, then the
##      muscle map; three challenges or fewer, each a MISSION strip inside its lift's row (no CHALLENGES section
##      since 2026-11-28); Coming up has a Prep today key too;
##   3. another way of the bench row (dumbbells): today is prepped with it, the challenge names it;
##   4. a record on that challenge's strip (heavier): it is the goal, in today's prep as set 1, picked on the
##      strip, shown in gold on the Today row; a second tap takes it off, a third puts it back;
##   5. Prep today opens today's prep with the goal record lit and set 1 marked (Coming up's key too);
##   6. Start workout: the Log tab's card has the MISSION banner and the goal set with the goal's numbers; its
##      reps changed with the stepper stay changed and marked;
##   7. Finish: the saved session holds no goal marks, and the challenge is done;
##   8. Coming up's Prep tomorrow: a record picked as a goal (and toggled), saved, kept for tomorrow.
## Real clicks are used where a key must stay under the pointer (the challenge's way and record keys); the rest
## is pressed as a tap would. Prints CHECK lines and "GOALS DONE, failures: N".

const BENCH = "Bench Press - Barbell"
const DUMBBELL = "Bench Press - Dumbbell"
const MOVE = "Bench Press"

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _done() -> void:
	App.draft_store("lift", null)
	print("GOALS DONE, failures: %d" % fails)


# ---------------------------------------------------------------------------
# Finding things
# ---------------------------------------------------------------------------

func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _section(id: String):
	for n in ShotHelper.walk(main):
		if n.has_meta("section") and str(n.get_meta("section")) == id and n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _form():
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n.form()
	return null


func _field(key: String):
	for n in ShotHelper.walk(main):
		if n is LineEdit and n.has_meta(LogWidgets.FKEY) and str(n.get_meta(LogWidgets.FKEY)) == key:
			return n
	return null


## The day's challenge missions.
func _challenges() -> Array:
	return App.quests().daily.filter(func(m): return bool(m.get("challenge", false)))


## The challenge of a movement ("Bench Press"), or null.
func _mission_of(move: String):
	for m in _challenges():
		if str(LiftNames.split(str(m.lift)).move) == move:
			return m
	return null


## The challenge whose lift is `lift_name` (any case), or null.
func _mission_named(lift_name: String):
	var k = Xp.normalize_exercise(lift_name)
	for m in _challenges():
		if Xp.normalize_exercise(str(m.lift)) == k:
			return m
	return null


## A record's key on a challenge's strip (in its lift's row of the Today card).
func _option_key(mission_id: String, type: String):
	var card = _one("challenge", mission_id, _section("today"))
	if card == null:
		return null
	return _one("challenge_option", type, card)


## The type of a goal dictionary ("" when it is none).
func _type(x) -> String:
	if x is Dictionary:
		return str(x.get("type", ""))
	return ""


## The muscle map on the Today card: its tile (a training focus), the weekly sets beside it, or its row.
func _muscle_map(sec):
	if sec == null:
		return null
	for meta in ["muscle_tile", "dose_row"]:
		var n = _one(meta, null, sec)
		if n != null:
			return n
	return ShotHelper.find_text(sec, "MUSCLE MAP")


# ---------------------------------------------------------------------------
# Tapping
# ---------------------------------------------------------------------------

## Press a control as a tap would: a key's pressed, a card's own tap, else a real click in its middle.
func _activate(c) -> void:
	if c == null:
		return
	if c is BaseButton:
		if not c.disabled:
			c.pressed.emit()
	elif c is Card and c._tap.is_valid():
		c._tap.call()
	else:
		await ShotHelper.click(tree, c)


func _press(c) -> void:
	if c == null:
		return
	ShotHelper.reveal(c)
	await ShotHelper.wait(tree, 0.3)
	await _activate(c)
	# (the Log tab drops presses for 350 ms after a rebuild that moved the tapped key: wait past it)
	await ShotHelper.wait(tree, 0.6)


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


## A real click on a key with the pointer left where it is (scrolled first so the key is at `at_y` of the
## window: room for the page to follow). The key, found again by `find` on every frame after, must stay under
## the pointer (`strict_x` false: only its height is checked, a row of chips may reflow sideways).
func _click_tap(find: Callable, what: String, at_y: float, strict_x: bool = true) -> bool:
	var b = find.call()
	check(b != null, "found the key of %s" % what)
	if b == null:
		return false
	main._scroll.scroll_vertical += int(b.get_global_rect().get_center().y - at_y)
	await ShotHelper.frames(tree, 4)
	b = find.call()
	if b == null:
		check(false, "the key of %s is still there after scrolling to it" % what)
		return false
	var pos = b.get_global_rect().get_center()
	await _move_to(pos)
	await _click_at(pos)
	var missed = 0
	var worst = 0.0
	for f in range(12):
		var nb = find.call()
		var on = false
		if nb != null:
			var r = nb.get_global_rect()
			on = r.has_point(pos) if strict_x else (pos.y >= r.position.y and pos.y <= r.end.y)
		if not on:
			missed += 1
		else:
			worst = maxf(worst, absf(nb.get_global_rect().get_center().y - pos.y))
		await tree.process_frame
	check(missed == 0 and worst <= 2.0, "the key of %s stayed under the pointer (%d frames off, %.1f px)" % [what, missed, worst])
	await ShotHelper.wait(tree, 0.5)
	return true


func _dismiss_reels() -> void:
	for k in range(8):
		var b = null
		for i in range(30):
			await ShotHelper.wait(tree, 0.3)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.4)


# ---------------------------------------------------------------------------
# The walk
# ---------------------------------------------------------------------------

func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.draft_store("lift", null)

	# --- 1. today's plan is this walkthrough's own ---------------------------------------------------------
	# The demo player trains by the weekday: take out this weekday's sessions (today's too), then a bench habit
	# on this weekday the last three weeks, and the bench once with dumbbells on another day (a second way).
	# Weights are whole pounds (the player logs in pounds), so a record set typed back reads as that record.
	var clean = App.saved.duplicate(true)
	var this_wd = Dates.weekday_index(App.today)
	clean.sessions = clean.sessions.filter(func(s): return Dates.weekday_index(str(s.date)) != this_wd)
	var bar = Fmt.unit_to_kg(135.0, "lb")
	for pair in [[21, 8], [14, 9], [7, 10]]:
		var wk = int(pair[0])
		clean.sessions.append({"id": "goals%d" % wk, "discipline": "lift", "date": Dates.add_days(App.today, -wk), "createdAt": App.now_ms() - wk * 86400000, "source": "manual",
			"exercises": [{"name": BENCH, "sets": [{"reps": int(pair[1]), "weightKg": bar}, {"reps": 8, "weightKg": bar}, {"reps": 7, "weightKg": bar}]}]})
	var db = Fmt.unit_to_kg(50.0, "lb")
	clean.sessions.append({"id": "goals_db", "discipline": "lift", "date": Dates.add_days(App.today, -10), "createdAt": App.now_ms() - 10 * 86400000, "source": "manual",
		"exercises": [{"name": DUMBBELL, "sets": [{"reps": 10, "weightKg": db}, {"reps": 10, "weightKg": db}]}]})
	clean.settings["weightUnit"] = "lb"
	for k in [Prep.KEY, "dayCalls", "dayPick", Missions.REROLLS]:
		clean.settings.erase(k)
	App.replace_all(clean)
	await ShotHelper.wait(tree, 0.8)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var plan = App.plan()
	print("GOALS plan: ", plan.lifts.map(func(l): return str(l.name)))

	# --- 2. the Hero tab: the day's lifts first, Prep today, three challenges or fewer ------------------------
	var today_sec = _section("today")
	check(today_sec != null and not bool(plan.get("off", false)), "the Hero tab has its TODAY card, a lift day")
	var rows = _all("today_lift", today_sec) if today_sec != null else []
	var mmap = _muscle_map(today_sec)
	check(not rows.is_empty() and mmap != null and rows[0].global_position.y < mmap.global_position.y, "TODAY lists the day's lifts before the muscle map (%d lifts)" % rows.size())
	var prep_key = _one("prep_today", null, today_sec) if today_sec != null else null
	var start_key = _one("start_workout", null, today_sec) if today_sec != null else null
	check(prep_key != null and start_key != null, "with a Prep today key and Start workout")
	if prep_key != null and mmap != null and not rows.is_empty():
		check(prep_key.global_position.y > rows[rows.size() - 1].global_position.y and prep_key.global_position.y < mmap.global_position.y, "the keys sit under the lifts, above the muscle map")
	check(_section("challenges") == null, "no CHALLENGES section of its own")
	var ch_sec = today_sec
	var daily = _challenges()
	var cards = _all("challenge", ch_sec) if ch_sec != null else []
	check(not daily.is_empty() and daily.size() <= 3 and cards.size() == daily.size(), "three challenges or fewer, a MISSION strip each in the Today card (%d missions, %d strips: %s)" % [daily.size(), cards.size(), str(daily.map(func(x): return str(x.title)))])
	var keys_seen = rows.map(func(r): return Xp.normalize_exercise(str(r.get_meta("today_lift"))))
	var dup = keys_seen.filter(func(k): return keys_seen.count(k) > 1)
	check(rows.size() == plan.lifts.size() and dup.is_empty(), "each lift once (%d rows, %d planned)" % [rows.size(), plan.lifts.size()])
	check(_one("ahead_prep_today") != null, "Coming up has a Prep today key too")
	main._scroll.scroll_vertical = 0
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "goals_1_today")
	var m = _mission_of(MOVE)
	check(m != null, "the bench press is one of the challenges")
	if m == null:
		_done()
		return

	# --- 3. another way to do it, picked on its row --------------------------------------------------------------
	# (the row of the bench: its ways are keys under its name)
	var card = _one("today_lift", str(m.lift), ch_sec)
	var ways = _all("challenge_way", card) if card != null else []
	print("GOALS ways: ", ways.map(func(w): return str(w.get_meta("challenge_way"))))
	var way = DUMBBELL if _one("challenge_way", DUMBBELL, card) != null else ""
	if way == "":
		for w in ways:
			var nm = str(w.get_meta("challenge_way"))
			if Xp.normalize_exercise(nm) != Xp.normalize_exercise(str(m.lift)) and not Missions._history_before(App.sessions(), nm, App.today).is_empty():
				way = nm
				break
	check(way != "", "the bench's row offers another way it has been done (%s)" % way)
	if way == "":
		_done()
		return
	var planned_lift = str(m.lift)
	await _click_tap(func(): return _one("challenge_way", way, _section("today")), "the %s way on the bench's row" % way, 300.0, false)
	var plan2 = App.plan()
	check(bool(plan2.get("prepped", false)) and Prep.lift_on(App.settings(), App.today, way) != null and Prep.lift_on(App.settings(), App.today, planned_lift) == null, "a tap preps today with %s in place of %s" % [way, planned_lift])
	var m2 = _mission_named(way)
	check(m2 != null and str(m2.id) != str(m.id), "the challenge now names that way (%s)" % (str(m2.lift) if m2 != null else "none"))
	var card2 = _one("challenge", str(m2.id), _section("today")) if m2 != null else null
	check(card2 != null and m2 != null and not (m2.get("options", []) as Array).is_empty() and not _all("challenge_option", card2).is_empty(), "its strip has that way's records")
	var way_row = _one("today_lift", way, _section("today"))
	var lit_way = _one("challenge_way_on", null, way_row) if way_row != null else null
	check(lit_way != null and str(lit_way.get_meta("challenge_way")) == way, "the %s key is lit as today's way" % way)
	if card2 != null:
		ShotHelper.reveal(card2)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "goals_2_way")
	if m2 == null or (m2.get("options", []) as Array).is_empty():
		_done()
		return

	# --- 4. a record picked as the goal ----------------------------------------------------------------------
	var opt = m2.options[0]
	for o in m2.options:
		if str(o.type) == "heavier":
			opt = o
	var otype = str(opt.type)
	var mid = str(m2.id)
	var find_opt = func(): return _option_key(mid, otype)
	await _click_tap(find_opt, "the %s record" % otype, 320.0, true)
	var goal = App.goal_on(way)
	print("GOALS goal: ", goal)
	check(_type(goal) == otype and Challenges.same_option(goal, opt), "a tap makes it the goal: %s, %s" % [str(opt.get("title", "")), str(opt.get("words", ""))])
	var px = Prep.lift_on(App.settings(), App.today, way)
	var gs = px.sets[0] if px != null and not (px.get("sets", []) as Array).is_empty() else {}
	check(px != null and _type(Prep.goal_of(px)) == otype and (otype == "day_reps" or (bool(gs.get("goal", false)) and int(gs.get("reps", 0)) == int(opt.reps))), "it is in today's prep, set 1 being the record")
	var picked = _option_key(mid, otype)
	check(picked != null and bool(picked.get_meta("challenge_picked", false)), "the record is marked as picked on its strip")
	var lit = _all("challenge_picked", _section("today")).filter(func(n): return bool(n.get_meta("challenge_picked")))
	check(lit.size() == 1, "and only that one (%d)" % lit.size())
	var gcard = _one("challenge", mid, _section("today"))
	check(gcard != null and ShotHelper.all_text(gcard).contains("YOUR GOAL") and not ShotHelper.all_text(gcard).contains("PICK ONE"), "the strip says YOUR GOAL")
	var mg = _mission_named(way)
	check(mg != null and _type(mg.get("goal")) == otype and Challenges.same_option(mg.options[0], goal), "the mission carries the goal, first of its records")
	var trow = _one("today_lift", way, _section("today"))
	var tg = _one("today_goal", null, trow) if trow != null else _one("today_goal", null, _section("today"))
	check(trow != null and tg != null and str(tg.get_meta("today_goal")) == otype, "the Today row of the %s shows the goal (its gold block)" % way)
	if gcard != null:
		ShotHelper.reveal(gcard)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "goals_3_goal")
	# A tap on the picked one takes it off; one more puts it back.
	await _click_tap(find_opt, "the picked record, again", 320.0, true)
	var off_key = _option_key(mid, otype)
	check(App.goal_on(way).is_empty() and (off_key == null or not bool(off_key.get_meta("challenge_picked", false))), "a tap on the picked one takes the goal off")
	check(Prep.lift_on(App.settings(), App.today, way) != null, "the way stays prepped")
	await _click_tap(find_opt, "the record, once more", 320.0, true)
	goal = App.goal_on(way)
	check(_type(goal) == otype, "and one more puts it back")

	# --- 5. Prep today: the prep sheet for today with the goal -----------------------------------------------
	await _close_sheets()
	var pk = _one("prep_today", null, _section("today"))
	await _press(pk)
	var sh = _sheet()
	check(sh != null and str(sh.get_meta("prep_sheet", "")) == App.today, "Prep today opens today's prep")
	check(sh != null and str(sh._title).to_lower().contains("today"), "its head says it is today (%s)" % (str(sh._title) if sh != null else "-"))
	var pcard = _one("prep_lift", way, sh) if sh != null else null
	check(pcard != null, "with the %s in it" % way)
	var pg = _one("prep_goal", null, pcard) if pcard != null else null
	check(pg != null and str(pg.get_meta("prep_goal")) == otype, "its goal record is lit")
	check(pcard != null and (otype == "day_reps" or _one("prep_goal_set", null, pcard) != null), "set 1 is marked as the goal set")
	check(pcard != null and _one("prep_goal_line", null, pcard) != null, "a GOAL line under the lift's name")
	if pcard != null:
		ShotHelper.reveal(pcard)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "goals_4_prep_today")
	await _close_sheets()
	var apk = _one("ahead_prep_today")
	if apk != null:
		await _press(apk)
		var sh2 = _sheet()
		check(sh2 != null and str(sh2.get_meta("prep_sheet", "")) == App.today and _one("prep_goal", null, sh2) != null, "Coming up's Prep today opens the same prep")
		await _close_sheets()
	check(_type(App.goal_on(way)) == otype, "closing the sheet keeps the goal")

	# --- 6. Start workout: the goal in the Log tab -----------------------------------------------------------
	App.draft_store("lift", null)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var sk = _one("start_workout", null, _section("today"))
	check(sk != null, "the Today card has Start workout")
	await _press(sk)
	await ShotHelper.wait(tree, 1.0)
	var f = _form()
	var names = f.lift.exercises.map(func(x): return str(x.name)) if f != null and f.get("lift") != null else []
	var idx = names.find(way)
	check(App.tab == "log" and idx >= 0, "Start workout opens the Log tab with the %s in it (%s)" % [way, str(names)])
	if idx < 0:
		_done()
		return
	var e = f.lift.exercises[idx]
	var ecard = _one("exercise_card", idx)
	var banner = _one("goal_banner", null, ecard) if ecard != null else null
	check(banner != null and str(banner.get_meta("goal_banner")) == otype, "its card has the MISSION banner")
	check(otype == "day_reps" or _one("goal_set", "%d:0" % idx) != null, "and the goal set marked")
	var wu = App.weight_unit()
	var want_w = Fmt.kg_to_unit(float(goal.get("kg", 0.0)), wu)
	var reps0 = int(LogWidgets.num(str(e.sets[0].reps)))
	var w0 = LogWidgets.num(str(e.sets[0].get("weight", "")))
	check(otype == "day_reps" or (reps0 == int(goal.get("reps", 0)) and (float(goal.get("kg", 0.0)) <= 0.0 or absf(w0 - want_w) < 0.06)), "set 1 is the goal: %d reps at %s %s (the goal: %s)" % [reps0, TTUtil.num_str(w0), wu, str(goal.get("words", ""))])
	check(_type(e.get("goal")) == otype and (otype == "day_reps" or bool(e.sets[0].get("goal", false))), "the exercise carries the goal, set 1 its mark")
	check(_one("plan_goal") != null, "From today's plan tags the lift with its goal")
	var try_row = _one("try_row", idx)
	var trk = _one("try_key", otype, try_row) if try_row != null else null
	check(trk != null, "the TRY row has the same record")
	if ecard != null:
		ShotHelper.reveal(ecard)
		await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "goals_5_log")
	# Not reached, or better: the goal set is edited like any set, and stays marked.
	var want_reps = reps0
	if otype != "day_reps":
		var fe = _field("ex%d.s0.reps" % idx)
		var st = fe.get_parent() if fe != null else null
		check(st is Stepper, "the goal set's reps have a stepper")
		if st is Stepper:
			ShotHelper.reveal(st)
			await ShotHelper.wait(tree, 0.5)
			st._plus.button_down.emit()
			st._plus.button_up.emit()
			await ShotHelper.wait(tree, 0.6)
			want_reps = reps0 + 1
			f = _form()
			e = f.lift.exercises[idx]
			check(int(LogWidgets.num(str(e.sets[0].reps))) == want_reps, "its + key changes the reps (%d -> %s)" % [reps0, str(e.sets[0].reps)])
			# (and they are never forced back)
			await ShotHelper.wait(tree, 0.8)
			f = _form()
			e = f.lift.exercises[idx]
			var fe2 = _field("ex%d.s0.reps" % idx)
			check(int(LogWidgets.num(str(e.sets[0].reps))) == want_reps and fe2 != null and int(LogWidgets.num(fe2.text)) == want_reps, "the change stays (%s)" % str(e.sets[0].reps))
			check(bool(e.sets[0].get("goal", false)) and _one("goal_set", "%d:0" % idx) != null and _type(e.get("goal")) == otype, "the set is still the goal set, still marked")
			await ShotHelper.snap(tree, "goals_5b_edited")

	# --- 7. saved: no goal in the session, the challenge done ------------------------------------------------
	var fin = ShotHelper.find_button(main, "Finish session")
	check(fin != null and not fin.disabled, "the workout can be finished")
	if fin != null:
		ShotHelper.reveal(fin)
		await ShotHelper.wait(tree, 0.5)
		ShotHelper.press(fin)
	await ShotHelper.wait(tree, 0.8)
	# ("Done as shown?" for the lifts never touched; "Sets not ticked" would say "Yes, save them too")
	for k in range(3):
		var yes = ShotHelper.find_button(Kit.overlay_root, "Yes, save")
		if yes == null:
			break
		ShotHelper.press(yes)
		await ShotHelper.wait(tree, 0.8)
	await _dismiss_reels()
	var saved_today = App.sessions().filter(func(s): return str(s.date) == App.today and str(s.discipline) == "lift")
	check(saved_today.size() == 1, "the workout is saved (%d)" % saved_today.size())
	var sx = null
	var marked = false
	for s in saved_today:
		for ex in s.get("exercises", []):
			if ex.has("goal"):
				marked = true
			for one in ex.get("sets", []):
				if (one as Dictionary).has("goal"):
					marked = true
			if Xp.normalize_exercise(str(ex.get("name", ""))) == Xp.normalize_exercise(way):
				sx = ex
	check(sx != null and not (sx.sets as Array).is_empty() and int(sx.sets[0].reps) == want_reps, "the %s is in it, set 1 as edited (%s reps)" % [way, str(sx.sets[0].reps) if sx != null and not (sx.sets as Array).is_empty() else "-"])
	check(not saved_today.is_empty() and not marked, "the goal and the set marks are not stored in the session")
	var md = _mission_named(way)
	check(md != null and bool(md.done) and (md.get("hit", []) as Array).has(otype), "the challenge is done by the goal (%s)" % (str(md.get("hit", [])) if md != null else "none"))
	await ShotHelper.snap(tree, "goals_6_saved")

	# --- 8. Coming up: Prep tomorrow with a goal -----------------------------------------------------------------
	await _close_sheets()
	# (a training split: tomorrow is a lift day of its own kind, whatever weekday this runs on)
	App.update_settings({"split": "pull_push_legs"})
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var tomorrow = Dates.add_days(App.today, 1)
	var tk = _one("prep_tomorrow")
	check(tk != null and not bool(tk.get_meta("prep_tomorrow")), "Coming up has Prep tomorrow")
	await _press(tk)
	sh = _sheet()
	check(sh != null and str(sh.get_meta("prep_sheet", "")) == tomorrow, "it opens tomorrow's prep")
	if sh == null:
		_done()
		return
	# A lift of tomorrow's with records to beat (none: one of the same muscles is added first).
	var rec_card = null
	for c in _all("prep_lift", sh):
		if _one("prep_record", null, c) != null:
			rec_card = c
			break
	if rec_card == null:
		var sug = _one("prep_suggest", null, sh)
		if sug != null:
			await _press(sug)
			sh = _sheet()
			for c in _all("prep_lift", sh):
				if _one("prep_record", null, c) != null:
					rec_card = c
					break
	check(rec_card != null, "a lift of tomorrow's shows its records to beat")
	if rec_card == null:
		_done()
		return
	var rn = str(rec_card.get_meta("prep_lift"))
	var recs = _all("prep_record", rec_card)
	var rt = str(recs[0].get_meta("prep_record"))
	await _press(recs[0])
	sh = _sheet()
	var rc = _one("prep_lift", rn, sh)
	var pgk = _one("prep_goal", null, rc) if rc != null else null
	check(pgk != null and str(pgk.get_meta("prep_goal")) == rt, "a tap on a record makes it %s's goal (%s)" % [rn, rt])
	check(rc != null and (rt == "day_reps" or _one("prep_goal_set", null, rc) != null) and _one("prep_goal_line", null, rc) != null, "set 1 marked, a GOAL line under the name")
	# A tap on the goal takes it off, one more on the record puts it back.
	await _press(pgk)
	sh = _sheet()
	rc = _one("prep_lift", rn, sh)
	check(rc != null and _one("prep_goal", null, rc) == null and _one("prep_goal_line", null, rc) == null, "a tap on the goal takes it off")
	var again = _all("prep_record", rc) if rc != null else []
	if not again.is_empty():
		await _press(again[0])
	sh = _sheet()
	rc = _one("prep_lift", rn, sh)
	pgk = _one("prep_goal", null, rc) if rc != null else null
	check(pgk != null and str(pgk.get_meta("prep_goal")) == rt, "and a tap on the record puts it back")
	if rc != null:
		ShotHelper.reveal(rc)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "goals_7_prep_tomorrow")
	await _press(_one("prep_save", null, sh))
	await ShotHelper.wait(tree, 0.6)
	var tg2 = App.goal_on(rn, tomorrow)
	var tx = Prep.lift_on(App.settings(), tomorrow, rn)
	check(_type(tg2) == rt, "Save keeps it as tomorrow's goal (%s: %s)" % [rn, str(tg2.get("words", ""))])
	check(tx != null and (rt == "day_reps" or (not (tx.get("sets", []) as Array).is_empty() and bool(tx.sets[0].get("goal", false)))), "and set 1 of tomorrow's prep is the goal set")
	check(_type(App.goal_on(way)) == otype, "today's prep keeps its own goal")
	App.go("home")
	await ShotHelper.wait(tree, 1.0)
	var tk2 = _one("prep_tomorrow")
	check(tk2 != null and bool(tk2.get_meta("prep_tomorrow")), "Coming up says tomorrow is prepped")
	_done()
