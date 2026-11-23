class_name TodayView
extends RefCounted
## The Hero tab's "Today" card, to read before the workout: what the player
## will probably do today, worked out from their log (Missions.day_plan via
## App.plan()): the body area of the day, the likely lifts with what to aim for
## (one tap opens a lift on Compare), a movement of that area never done, the
## physical therapy still to do this week and the likely run, climb or ride.
## Each lift is shown as it was done last, with the other ways the player has
## done it under it (their variations, another movement: Missions.options_for);
## any of them, or any variation, completes its mission.
## The morning message on the phone says the same (MorningAlert).
## Every row ends in a box: empty while it is still to do, ticked once it was
## done today (any way of a lift, the new movement, the PT, the run...), the
## same for every colour.

static func card() -> Control:
	var plan = App.plan()
	var wu = App.weight_unit()
	var c = Kit.card(8, Callable(), 12)
	c.accent(Pal.ACCENT)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("sun", 24)))
	var words = Kit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t = PixelFont.rect("TODAY", 2, Pal.ACCENT)
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	words.add_child(t)
	words.add_child(Kit.clip(Dates.format_date(App.today, {"weekday": "long", "month": "short", "day": "numeric"}), 12, Pal.MUTED, true))
	head.add_child(words)
	# A rest day (a rest from lifting: the player's call, or enough lifting days
	# in a row) says so where the day's kind would be.
	var off = bool(plan.get("off", false))
	if off:
		head.add_child(Kit.vcenter(Kit.tag("Rest day", Pal.SECOND, true, 13)))
	elif str(plan.label) != "":
		head.add_child(Kit.vcenter(Kit.tag(str(plan.label), Pal.LIFT, true, 13)))
	c.add(head)
	if not plan.cycle.is_empty():
		c.add(Kit.clip(Missions.kind_why(plan), 12, Pal.MUTED, true))
	# What today is, one tap to change it: the split's kinds and Rest.
	if not plan.cycle.is_empty() or off or plan.lifts.any(func(l): return not bool(l.pt)):
		c.add(_day_row(plan))
	if off:
		c.add(_rest_row(plan))
	# A training focus (game/dose.gd): the sets the day's muscles got this week.
	var focus = str(plan.get("focus", "")) != ""
	c.add(_feel_row())
	if App.sessions().any(func(s): return str(s.get("discipline", "")) == "lift"):
		c.add(RecoveryView.row())
	if focus:
		c.add(DoseView.row(plan))
	var nothing = plan.lifts.is_empty() and plan.others.is_empty() and plan.pt.is_empty() and plan.new == null
	if nothing:
		if not off:
			c.add(Kit.para("No pattern for today yet. After a few weeks of workouts this card guesses what is next and what to aim for.", 13, Pal.MUTED))
		return c
	# What the focus adds (a muscle that is short this week) goes first: the
	# heavy lift before the usual ones.
	var extra = plan.lifts.filter(func(l): return l.has("dose"))
	var usual = plan.lifts.filter(func(l): return not l.has("dose"))
	if not extra.is_empty():
		c.add(_kicker("YOUR FOCUS ADDS", "What a muscle still needs this week, from your training focus"))
		for l in extra:
			c.add(_lift_row(l, wu, Missions.same_of(str(l.name), plan)))
	if not usual.is_empty():
		c.add(_kicker("PROBABLY TODAY", "From the days and gaps of your last six weeks"))
		for l in usual:
			c.add(_lift_row(l, wu, {} if bool(l.pt) else Missions.same_of(str(l.name), plan)))
	if plan.new != null:
		c.add(_new_row(plan.new))
	if not plan.pt.is_empty():
		c.add(_pt_row(plan.pt))
	var start = _start_row(plan)
	if start != null:
		c.add(start)
	for o in plan.others.slice(0, 2):
		c.add(_other_row(o))
	var perfect = App.quests().daily.filter(func(m): return m.get("perfect", false))
	if not perfect.is_empty():
		c.add(_perfect_row(perfect[0]))
	return c


## What a planned lift was done as today (any way of it), or "".
static func _done_name(l: Dictionary, plan: Dictionary) -> String:
	return Missions.lift_done(l, plan, App.sessions(), App.today)


## The lifts "Start workout" sends to the Log tab: the day's lifts and PT
## still to do, each as it would be done first (the way it was done last).
static func workout_names(plan: Dictionary) -> Array:
	var names = []
	var seen = {}
	for l in plan.lifts:
		if _done_name(l, plan) != "":
			continue
		var opts = l.get("options", [])
		var nm = str(opts[0].name) if not opts.is_empty() else str(l.name)
		var k = Xp.normalize_exercise(nm)
		if not seen.has(k):
			seen[k] = true
			names.append(nm)
	for r in plan.pt:
		var k2 = Xp.normalize_exercise(str(r.name))
		if not seen.has(k2) and Missions.sets_on(App.sessions(), str(r.name), App.today).is_empty():
			seen[k2] = true
			names.append(str(r.name))
	return names


## One key from the plan to the Log tab: the day's lifts are there with last
## time's sets, so only what is different needs a tap. A workout under way
## (kept as it is typed, or saved once today) is picked up again.
static func _start_row(plan: Dictionary):
	var names = workout_names(plan)
	var draft = App.draft_load("lift") != null
	var going = App.lift_today()
	if names.is_empty() and not draft:
		return null
	var b = Kit.button("Continue workout" if (draft or going != null) else "Start workout", "primary", _start.bind(names), "lg", "lift")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "The Log tab with %s and last time's sets" % ("your workout as you left it" if draft else ("%d lift%s" % [names.size(), "" if names.size() == 1 else "s"]))
	b.set_meta("start_workout", true)
	return b


static func _start(names: Array) -> void:
	Sfx.tap()
	if App.draft_load("lift") != null:
		# Under way: as it was left (nothing is added to it again).
		App.open_log("lift")
		return
	var going = App.lift_today()
	App.pending_workout = names.duplicate()
	App.open_log("lift", going.id if going != null else null)


## Perfect day: a chest that fills as the boxes tick; once all are ticked it
## glows and opens with a burst.
static func _perfect_row(m: Dictionary) -> Control:
	var c = Kit.card(0, Callable(), 8)
	c.accent(Pal.ACCENT if bool(m.done) else Pal.LINE)
	var row = Kit.hbox(10)
	var chest = Icons.rect("chest" if not bool(m.claimed) else "gift", 32)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(chest))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label("PERFECT DAY", 10, Pal.ACCENT, true))
	var said = "Opened: +%s XP" % Xp.fmt_int(int(m.xp)) if bool(m.claimed) else ("Every box ticked!" if bool(m.done) else "%d of %d boxes ticked" % [int(m.progress), int(m.target)])
	v.add_child(Kit.clip(said, 13, Pal.TEXT, true))
	row.add_child(v)
	if bool(m.done) and not bool(m.claimed):
		var b = Kit.button("Open the chest", "good", Callable(), "sm", "gift")
		b.pressed.connect(_open_chest.bind(m, chest, c))
		Fx.shine(b, 2.0, 0.3, 0.5)
		Fx.twinkle(chest, Pal.ACCENT, 3)
		row.add_child(Kit.vcenter(b))
	elif not bool(m.claimed):
		row.add_child(Kit.vcenter(Kit.tag("+%s XP" % Xp.fmt_int(int(m.xp)), Pal.ACCENT, true, 11)))
	else:
		row.add_child(_tick(true))
	c.add(row)
	return c


static func _open_chest(m: Dictionary, chest: Control, card: Control) -> void:
	Kit.burst(chest, Pal.ACCENT, 48)
	Kit.burst(card, Pal.GOOD, 24)
	Kit.floater(card, "PERFECT DAY", Pal.ACCENT, 0.0, 2)
	Kit.floater(card, "+%s XP" % Xp.fmt_int(int(m.xp)), Pal.GOOD, 0.35, 2)
	Sfx.level_up()
	App.claim_quest(m)


## How do you feel today? A mark for the day and nothing else: no goal changes
## with it (Missions.feel_of).
static func _feel_row() -> Control:
	var h = Kit.hbox(6)
	var f = Missions.feel_of(App.settings(), App.today)
	var l = Kit.label("Feeling", 12, Pal.MUTED, true)
	l.custom_minimum_size = Vector2(64, 0)
	h.add_child(Kit.vcenter(l))
	for pair in [[1, "Tired", Pal.SECOND], [2, "Okay", Pal.PANEL2], [3, "Strong", Pal.GOOD]]:
		var b = Kit.chip(str(pair[1]), f == int(pair[0]), _set_feel.bind(int(pair[0])), pair[2], 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h


static func _set_feel(v: int) -> void:
	Sfx.tick()
	var feels = App.settings().get("feels", {})
	var m = feels.duplicate() if feels is Dictionary else {}
	m[App.today] = v
	App.update_settings({"feels": m})
	App.toast("Marked: %s. Your goals stay as they are." % ["", "tired", "okay", "strong"][v], "info", "muscle")


## A rest day, a rest from lifting (only ever the player's call): what waits
## for tomorrow, what is still fine today, and a key to lift after all.
static func _rest_row(plan: Dictionary) -> Control:
	var c = Kit.card(0, Callable(), 8)
	c.accent(Pal.SECOND)
	c.set_meta("rest_row", true)
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("moon", 24)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label("REST DAY · YOUR CALL", 10, Pal.SECOND, true))
	v.add_child(Kit.clip(Missions.off_moves(plan), 13, Pal.TEXT, true))
	v.add_child(Kit.clip("Your run, PT and a walk are still fine", 11, Pal.MUTED))
	h.add_child(v)
	var b = Kit.button("Lift today", "secondary", _call_day.bind("lift"), "sm", "lift")
	b.tooltip_text = "Make today a lift day after all"
	b.set_meta("lift_today", true)
	h.add_child(Kit.vcenter(b))
	c.add(h)
	return c


## What today is, one tap to change it: a chip per kind of the training split
## (today's lit; another one plans today as that kind, the split's own goes
## back to it) and one for a rest day. Without a split: Lift and Rest.
## Rest = no lifting today (Missions.call_of): the day's lifts are tomorrow's
## and the split follows, a day later. Tapping Rest again, a kind, or "Lift
## today" on the banner makes it a lift day again.
static func _day_row(plan: Dictionary) -> Control:
	var v = Kit.vbox(4)
	var chips = Kit.hbox(6)
	var off = bool(plan.get("off", false))
	if plan.cycle.is_empty():
		var lb = Kit.chip("Lift", not off, _call_day.bind("lift"), Pal.LIFT, 13)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.tooltip_text = "Lift today"
		chips.add_child(lb)
	for k in plan.cycle:
		var b = Kit.chip(str(Missions.KIND_SHORT[k]), not off and str(k) == str(plan.kind), _pick_kind.bind(str(k)), Pal.LIFT, 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Plan today as a %s" % str(Missions.KIND_NAMES[k]).to_lower()
		chips.add_child(b)
	var rb = Kit.chip("Rest", off, _call_day.bind("rest"), Pal.SECOND, 13)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.tooltip_text = "No lifting today: the day's lifts move to tomorrow, and the days after follow"
	rb.set_meta("rest_chip", true)
	chips.add_child(rb)
	# The split combo: lift days this week in the split's order.
	var cb = Missions.combo(App.sessions(), App.today, plan.cycle, App.pt())
	if int(cb.now) >= 2:
		var pill = Kit.pill("flame", "×%d" % int(cb.now), Pal.ACCENT2, "Combo: %d lift days in a row in your split's order this week" % int(cb.now), Color.WHITE, 13)
		Fx.embers(pill, Pal.ACCENT2, 2)
		chips.add_child(Kit.vcenter(pill))
	v.add_child(chips)
	return v


static func _pick_kind(kind: String) -> void:
	Sfx.tick()
	var st = App.settings()
	var plan = App.plan()
	var off = bool(plan.get("off", false))
	if kind == str(plan.kind) and not bool(plan.picked) and not off:
		return
	var patch = {}
	if off:
		# A kind tapped on a rest day: a lift day after all.
		patch["dayCalls"] = Missions.with_call(st, App.today, false, App.today)
	if kind != str(plan.kind) or bool(plan.picked):
		# The kind the split itself gives today: the pick is dropped.
		var own = Missions.day_kind(App.sessions(), App.today, plan.cycle, App.pt()).kind
		patch["dayPick"] = {} if kind == own else {"date": App.today, "kind": kind}
	App.update_settings(patch)
	App.toast("Today: %s" % str(Missions.KIND_NAMES[kind]).to_lower(), "info", "lift")


## Call today a rest day (a rest from lifting) or a lift day. Rest tapped on
## a rest day goes back to lifting.
static func _call_day(want: String) -> void:
	var plan = App.plan()
	var off = bool(plan.get("off", false))
	if want == "lift" and not off:
		return
	if want == "rest" and off:
		want = "lift"
	if want == "rest" and Dose.hard_on(App.sessions(), App.pt(), App.today):
		Sfx.tick()
		App.toast("You have lifted today: it stays a lift day", "info", "lift")
		return
	Sfx.tick()
	App.update_settings({"dayCalls": Missions.with_call(App.settings(), App.today, want == "rest", App.today)})
	var now = App.plan()
	if want == "rest":
		App.toast("Rest day. %s." % Missions.off_moves(now), "info", "moon")
	else:
		App.toast("Lifting today%s" % ((": " + str(now.label).to_lower()) if str(now.label) != "" else ""), "info", "lift")


static func _kicker(text: String, tip: String) -> Control:
	var l = Kit.label(text, 10, Pal.MUTED, true)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


static func _step_kg(wu: String) -> float:
	return 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)


## A likely lift as done last (its first option): name and variation, why it
## is likely, what to aim for; the other ways the player has done it under it
## as chips. Done today (any way): what was done.
static func _lift_row(l: Dictionary, wu: String, same: Dictionary = {}) -> Card:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var opts = l.get("options", [])
	var main = opts[0] if not opts.is_empty() else {"name": str(l.name), "new": false, "last": l.last.sets}
	var planned_move = str(LiftNames.split(str(l.name)).move)
	var ways = []
	for o in opts:
		if not ways.has(str(o.name)):
			ways.append(str(o.name))
	# An extra lift of the training focus ("dose").
	var dose = l.get("dose")
	var done_name = Missions.lift_done(l, App.plan(), App.sessions(), App.today)
	var shown = done_name if done_name != "" else str(main.name)
	var c = Kit.card(0, JourneyLifts.open_named.bind(shown, {"view": "compare"}), 8)
	c.tooltip_text = "Last time, and what to beat"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left = Kit.vbox(1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.squeeze(6)
	var sp = LiftNames.split(shown)
	top.add_child(Kit.soft_name(str(sp.move), 13, null, true, 170.0))
	if str(sp.variation) != "":
		top.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	if dose != null and done_name == "":
		var ft = Kit.tag("FOR " + Dose.part_name(str(dose.part)).to_upper(), JourneyLifts.part_color(str(dose.part)), true, 10)
		ft.tooltip_text = "Added by your training focus"
		top.add_child(Kit.vcenter(ft))
	if bool(l.pt):
		top.add_child(Kit.vcenter(SessionView.pt_tag()))
	elif LiftTrend.plateau(_history_of(shown)) != null:
		var st_tag = Kit.tag("STUCK", Pal.DANGER, true, 10)
		st_tag.tooltip_text = "No new best for three sessions: its page has ways out"
		top.add_child(Kit.vcenter(st_tag))
	left.add_child(top)
	# (an extra lift once done: what it was for, its count is out of date)
	left.add_child(Kit.clip("Added for your %s" % Dose.part_name(str(dose.part)).to_lower() if (dose != null and done_name != "") else str(l.why), 11, Pal.MUTED))
	# A barbell lift: the warm-up and what goes on the bar.
	if done_name == "" and not bool(l.pt) and not bool(main.new) and Plates.is_barbell(shown):
		var top_kg = 0.0
		for one in LiftTrend.next_target(main.last, _step_kg(wu)).sets:
			top_kg = maxf(top_kg, float(one.get("weightKg", 0.0)))
		var wt = snappedf(Fmt.kg_to_unit(top_kg, wu), 0.5)
		var bits = []
		if Plates.warmup_text(wt, wu) != "":
			bits.append("Warm-up " + Plates.warmup_text(wt, wu))
		if Plates.text(wt, wu) != "":
			bits.append(Plates.text(wt, wu))
		if not bits.is_empty():
			var wl = Kit.clip(" · ".join(PackedStringArray(bits)), 11, Pal.with_alpha(Pal.MUTED, 0.85))
			wl.tooltip_text = "Warm-up sets, then the plates on each side of the bar"
			left.add_child(wl)
	row.add_child(left)
	var right = Kit.vbox(1)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var said = ""
	var cap = ""
	var col = Pal.PT if bool(l.pt) else Pal.ACCENT
	if done_name != "":
		# Already done today (any way): what was done, green when it beat last
		# time or was a first.
		var beat = Missions.beat_any(App.sessions(), ways if not ways.is_empty() else [str(l.name)], "" if bool(l.pt) else planned_move, App.today, same)
		said = LiftHistory.describe_sets(Missions.sets_on(App.sessions(), done_name, App.today), fmt_w)
		cap = "DONE · BEAT IT" if beat else "DONE TODAY"
		col = Pal.GOOD if beat else Pal.TEXT
	elif bool(l.pt):
		said = LiftHistory.describe_sets(l.last.sets, fmt_w)
		cap = "AS LAST TIME"
	elif dose != null:
		var got = int(Dose.extra_done(l, App.sessions(), App.today, same).sets)
		cap = ("%d OF %d SETS" % [got, int(dose.sets)]) if got > 0 else ("ADD · %d SETS" % int(dose.sets))
		if bool(main.new):
			said = "6 to 12 reps, hard"
			col = Pal.SECOND
		else:
			said = LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w)
	elif bool(main.new):
		said = "Find your weight"
		cap = "FIRST TIME"
		col = Pal.SECOND
	else:
		said = LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w)
		cap = "AIM"
	var cl = Kit.label(cap, 9, Pal.GOOD if col == Pal.GOOD else Pal.MUTED, true)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cl)
	var al = Kit.label(said, 12, col, true)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(al)
	row.add_child(right)
	row.add_child(_tick(done_name != ""))
	c.add(row)
	# The other ways to do it here, each opening its own page.
	if done_name == "" and opts.size() > 1:
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orl = Kit.label("OR", 10, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		# Each other way: a variation of the same movement by its own words, another
		# movement by its name; one never done yet in the "new" colour.
		var main_move = str(main.get("move", LiftNames.split(str(main.name)).move))
		for o in opts.slice(1):
			var same_move = str(o.move) == main_move
			var text = str(o.variation) if same_move and str(o.variation) != "" else Missions.way_word(o, main_move)
			var b = Kit.chip(text, false, JourneyLifts.open_named.bind(str(o.name), {"view": "compare"}), Pal.SECOND if bool(o.new) else Pal.LIFT, 11)
			b.tooltip_text = ("New to you: " if bool(o.new) else "") + Missions.short_name(str(o.name))
			b.set_meta("lift_option", str(o.name))
			more.add_child(b)
		c.add(more)
	return c


## A lift's history (newest first), as LiftLibrary.stats keeps it.
static func _history_of(lift_name: String) -> Array:
	var st = LiftLibrary.stats(App.sessions()).get(Xp.normalize_exercise(lift_name))
	return st.history if st != null else []


## A done box: empty while still to do, a tick once done today.
static func _tick(done: bool) -> Control:
	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.GOOD, 0.2) if done else Pal.PANEL2, 4, Pal.GOOD if done else Pal.LINE, 2, 2, 2))
	box.tooltip_text = "Done today" if done else "Still to do today"
	var mid = CenterContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		mid.add_child(Icons.rect("check", 16))
	box.add_child(mid)
	box.set_meta("done_tick", done)
	return box


## Was a session of this kind logged today?
static func _did_today(discipline: String) -> bool:
	return App.sessions().any(func(s): return str(s.get("date", "")) == App.today and str(s.get("discipline", "")) == discipline)


static func _new_row(nw: Dictionary) -> Card:
	var c = Kit.card(0, JourneyLifts.open_named.bind(str(nw.name), {"view": "compare"}), 8)
	c.accent(Pal.SECOND)
	c.tooltip_text = "How to do it"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect("sparkle", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Done as the mission counts it: this movement logged today, or another one
	# never done before. Then the row names the lift that did it, so a tick never
	# stands beside a movement that was not done.
	var by = ""
	for m in App.quests().daily:
		if str(m.id).ends_with(":new") and bool(m.done):
			by = str(m.get("by", ""))
	var other = by != "" and Xp.normalize_exercise(str(LiftNames.split(by).move)) != Xp.normalize_exercise(str(nw.move))
	v.add_child(Kit.label("SOMETHING NEW · DONE" if other else "TRY SOMETHING NEW", 10, Pal.SECOND, true))
	var top = Kit.squeeze(6)
	if other:
		var sp = LiftNames.split(by)
		top.add_child(Kit.soft_name(str(sp.move), 13, null, true, 170.0))
		if str(sp.variation) != "":
			top.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
		top.add_child(Kit.vcenter(Kit.tag("First time", Pal.SECOND, true, 10)))
	else:
		top.add_child(Kit.soft_name(str(nw.move), 13, null, true, 170.0))
		if str(nw.variation) != "":
			top.add_child(SessionView.variation_tag(str(nw.variation), 10, true))
		top.add_child(Kit.vcenter(Kit.tag(str(nw.partName), JourneyLifts.part_color(str(nw.part)), true, 10)))
	v.add_child(top)
	row.add_child(v)
	row.add_child(_tick(by != ""))
	c.add(row)
	# Others that count just the same, for when the equipment is not there.
	var alts = nw.get("alts", [])
	if by == "" and not alts.is_empty():
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orl = Kit.label("OR", 10, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		for a in alts:
			var b = Kit.chip(Missions.short_name(str(a.name)), false, JourneyLifts.open_named.bind(str(a.name), {"view": "compare"}), Pal.SECOND, 11)
			b.tooltip_text = "New to you: a %s movement" % str(a.partName).to_lower()
			b.set_meta("new_alt", str(a.name))
			more.add_child(b)
		c.add(more)
	return c


static func _pt_row(rows: Array) -> Control:
	var c = Kit.card(0, PtView.open, 8)
	c.accent(Pal.PT)
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect("pt", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("PHYSICAL THERAPY TODAY", 10, Pal.PT, true))
	var names = []
	var done = 0
	for r in rows:
		names.append(str(r.name))
		if not Missions.sets_on(App.sessions(), str(r.name), App.today).is_empty():
			done += 1
	v.add_child(Kit.clip(", ".join(PackedStringArray(names)), 13, Pal.TEXT, true))
	row.add_child(v)
	var count = Kit.tag("%d/%d" % [done, rows.size()], Pal.PT, true, 11)
	count.tooltip_text = "Done today, of the ones still needed this week (the week is on the PT page)"
	row.add_child(Kit.vcenter(count))
	row.add_child(_tick(done >= rows.size()))
	c.add(row)
	return c


static func _other_row(o: Dictionary) -> Control:
	var d = str(o.discipline)
	var c = Kit.card(0, Callable(), 8)
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect(d if d != "misc" else "vest", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(TT.DISCIPLINE_META[d].name, 13, Pal.disc(d), true))
	v.add_child(Kit.clip(str(o.why), 11, Pal.MUTED))
	if d == "climb":
		var pj = App.open_projects()
		if not pj.is_empty():
			var st = Projects.status(pj[0], App.sessions(), App.today)
			v.add_child(Kit.clip("Project: %s · %d session%s so far" % [Projects.title(pj[0]), int(st.sessions), "" if int(st.sessions) == 1 else "s"], 11, Pal.CLIMB, true))
	row.add_child(v)
	var usual = ""
	if d == "climb":
		usual = "%d sends" % TTUtil.jsround(float(o.avg))
	else:
		usual = Fmt.fmt_distance(float(o.avg), App.distance_unit())
	var said = "usually %s" % usual
	var run_goal = App.plan().get("run")
	if d == "run" and run_goal != null:
		# The weekly run on its day (training focus): further, or quicker.
		said = "aim %s" % Fmt.fmt_distance(float(run_goal.targetM), App.distance_unit())
		if float(run_goal.paceSec) > 0.0:
			v.add_child(Kit.clip("or quicker than %s over %s" % [Fmt.fmt_pace(float(run_goal.paceSec), App.distance_unit()), Fmt.fmt_distance(float(run_goal.paceM), App.distance_unit())], 11, Pal.MUTED))
	elif d == "run" and bool(App.plan().get("runToday", false)):
		said = "log a run"
	var u = Kit.label(said, 12, Pal.TEXT, true)
	row.add_child(Kit.vcenter(u))
	row.add_child(_tick(_did_today(d)))
	c.add(row)
	return c
