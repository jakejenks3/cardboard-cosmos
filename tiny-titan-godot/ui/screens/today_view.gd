class_name TodayView
extends RefCounted
## The Hero tab's TODAY section, to read before the workout: what the player
## will probably do today, worked out from their log (Missions.day_plan via
## App.plan()). Since 2026-11-24 it is a framed section (Kit.section) with a
## band in the lifting colour (blue on a rest day) and the day's kind as a tag
## in the band. Inside it, top to bottom:
##   - the date (and, with a training split, why the day is what it is);
##   - the day's kind as a pick-one track (the split's kinds, or Lift, and
##     Rest), the combo pill beside it; on a rest day a banner with "Lift today";
##   - the body: the muscle map as a small tile beside the weekly sets of the
##     day's muscles (a training focus), the recovering parts in one line;
##   - "YOUR FOCUS ADDS" and "PROBABLY TODAY", a flat row per lift: the movement
##     as it was done last with its variation and tags, what to aim for on a
##     line of its own (white; gold is kept for rewards), why it is likely
##     (unless it is the reason the heading already gives), the warm-up for a
##     barbell, the other ways to do it as outlined OR chips (blue: never done);
##   - the movement to try, the physical therapy still needed (one row, pips),
##     the Start workout key, the likely climb or run, the perfect-day chest.
## One tap on a lift opens its page on Compare; any way of a lift, or any
## variation, completes its mission. Every row ends in the same box: an empty
## well while still to do, solid green with a tick once done today. A row's
## stripe only says a state: green done, the muscle's colour for a lift the
## focus adds, blue for something new, the PT and discipline colours.
## Coming up (AheadView) is its own section under this one (home.gd).
## The morning message on the phone says the same (MorningAlert).

static func card() -> Control:
	var plan = App.plan()
	var wu = App.weight_unit()
	# A rest day (a rest from lifting: only ever the player's call) says so in
	# the band, where the day's kind would be.
	var off = bool(plan.get("off", false))
	var col = Pal.SECOND if off else Pal.LIFT
	var band_tag = null
	if off:
		band_tag = Kit.tag("Rest day", Pal.SECOND, true, 13)
	elif str(plan.label) != "":
		band_tag = Kit.tag(str(plan.label), Pal.LIFT, true, 13)
	var c = Kit.section("today", "TODAY", "sun", col, band_tag, Callable(), 8, 10)
	# One line, always one, so the day's track under it never moves.
	var when = Dates.format_date(App.today, {"weekday": "long", "month": "short", "day": "numeric"})
	var kind_why = Missions.kind_why(plan) if not plan.cycle.is_empty() else ""
	c.add(Kit.clip(when if kind_why == "" else "%s · %s" % [when, kind_why], 12, Pal.MUTED, true))
	# What today is, one tap to change it: the split's kinds and Rest.
	if not plan.cycle.is_empty() or off or plan.lifts.any(func(l): return not bool(l.pt)):
		c.add(_day_row(plan))
	if off:
		c.add(_rest_row(plan))
	# The body: what is recovering, and (a training focus, game/dose.gd) the
	# sets the day's muscles got this week.
	var lifted = App.sessions().any(func(s): return str(s.get("discipline", "")) == "lift")
	var focus = str(plan.get("focus", "")) != ""
	if lifted and focus:
		c.add(_body_row(plan))
	elif lifted:
		c.add(RecoveryView.row())
	elif focus:
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
		c.add(Kit.sub_head("YOUR FOCUS ADDS", JourneyLifts.part_color(str(extra[0].dose.part)), null, "What a muscle still needs this week, from your training focus"))
		for l in extra:
			c.add(_lift_row(l, wu, Missions.same_of(str(l.name), plan)))
	if not usual.is_empty():
		var shared = _shared_why(usual)
		var n_done = usual.filter(func(l): return _done_name(l, plan) != "").size()
		# How many are done in the heading; the reason most of them share said
		# once, in full, on its own line under it (the rows then leave it out).
		var count = Kit.label("%d of %d done" % [n_done, usual.size()], 11, Pal.GOOD if n_done > 0 else Pal.MUTED, true)
		c.add(Kit.sub_head("PROBABLY TODAY", Pal.LIFT, count, "From the days and gaps of your last six weeks"))
		if shared != "":
			c.add(Kit.para(shared, 12, Pal.MUTED))
		for l in usual:
			c.add(_lift_row(l, wu, {} if bool(l.pt) else Missions.same_of(str(l.name), plan), shared))
	if plan.new != null:
		c.add(_new_row(plan.new))
	if not plan.pt.is_empty():
		c.add(_pt_row(plan))
	var start = _start_row(plan)
	if start != null:
		c.add(start)
	for o in plan.others.slice(0, 2):
		c.add(_other_row(o))
	var perfect = App.quests().daily.filter(func(m): return m.get("perfect", false))
	if not perfect.is_empty():
		c.add(_perfect_row(perfect[0]))
	return c


## The reason two or more of the usual lifts share (the most common one), or "".
static func _shared_why(usual: Array) -> String:
	var counts = {}
	var best = ""
	var most = 0
	for l in usual:
		var w = str(l.get("why", ""))
		if w == "":
			continue
		counts[w] = int(counts.get(w, 0)) + 1
		if int(counts[w]) > most:
			most = int(counts[w])
			best = w
	return best if most >= 2 else ""


## The body on a lifting player's day with a training focus: the muscle map as
## a small tile beside the weekly sets of the day's muscles, then the parts
## still recovering by name (the tile has no room for them).
static func _body_row(plan: Dictionary) -> Control:
	var v = Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = Kit.hbox(8)
	var tile = RecoveryView.tile()
	tile.size_flags_vertical = Control.SIZE_FILL
	h.add_child(tile)
	var dose = DoseView.row(plan, true)
	dose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dose.size_flags_vertical = Control.SIZE_FILL
	h.add_child(dose)
	v.add_child(h)
	var words = RecoveryView.warm_words()
	if words != "":
		var l = Kit.clip("Recovering: " + words, 11, Pal.MUTED)
		l.set_meta("recovering_line", true)
		v.add_child(l)
	return v


## What a planned lift was done as today (any way of it), or "".
static func _done_name(l: Dictionary, plan: Dictionary) -> String:
	return Missions.lift_done(l, plan, App.sessions(), App.today)


## The lifts "Start workout" sends to the Log tab: the day's lifts still to
## do, each as it would be done first (the way it was done last). Physical
## therapy is not sent: it is its own goal, not one of the day's lifts.
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
## glows and opens with a burst. The boxes are pips on a line of their own, so
## a day with many never widens the row.
static func _perfect_row(m: Dictionary) -> Control:
	var c = Kit.row(Callable(), Pal.GOOD if bool(m.claimed) else Pal.ACCENT, Pal.ACCENT, 8, 4, 0.1)
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chest = Icons.rect("chest" if not bool(m.claimed) else "gift", 28)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(chest))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("PERFECT DAY", 11, Pal.ACCENT, true))
	var said = "Opened: +%s XP" % Xp.fmt_int(int(m.xp)) if bool(m.claimed) else ("Every box ticked!" if bool(m.done) else "%d of %d boxes ticked" % [int(m.progress), int(m.target)])
	v.add_child(Kit.clip(said, 12, Pal.TEXT if bool(m.done) else Pal.MUTED, true))
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
	c.add(Kit.pips(int(m.progress), int(m.target), Pal.GOOD if bool(m.done) else Pal.ACCENT, 10))
	return c


static func _open_chest(m: Dictionary, chest: Control, card: Control) -> void:
	Kit.burst(chest, Pal.ACCENT, 48)
	Kit.burst(card, Pal.GOOD, 24)
	Kit.floater(card, "PERFECT DAY", Pal.ACCENT, 0.0, 2)
	Kit.floater(card, "+%s XP" % Xp.fmt_int(int(m.xp)), Pal.GOOD, 0.35, 2)
	Sfx.level_up()
	App.claim_quest(m)


## A rest day, a rest from lifting (only ever the player's call): what waits
## for tomorrow, what is still fine today, and a key to lift after all.
static func _rest_row(plan: Dictionary) -> Control:
	var c = Kit.row(Callable(), Pal.SECOND, Pal.SECOND, 8, 2)
	c.set_meta("rest_row", true)
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("moon", 24)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("REST DAY · YOUR CALL", 11, Pal.SECOND, true))
	v.add_child(Kit.clip(Missions.off_moves(plan), 14, Pal.TEXT, true))
	v.add_child(Kit.clip("Your run, PT and a walk are still fine", 12, Pal.MUTED))
	h.add_child(v)
	var b = Kit.button("Lift today", "secondary", _call_day.bind("lift"), "sm", "lift")
	b.tooltip_text = "Make today a lift day after all"
	b.set_meta("lift_today", true)
	h.add_child(Kit.vcenter(b))
	c.add(h)
	return c


## What today is, one tap to change it: a key per kind of the training split
## (today's raised; another one plans today as that kind, the split's own goes
## back to it) and one for a rest day, all on one sunken track. Without a
## split: Lift and Rest. Rest = no lifting today (Missions.call_of): the day's
## lifts are tomorrow's and the split follows, a day later. Tapping Rest again,
## a kind, or "Lift today" on the banner makes it a lift day again.
static func _day_row(plan: Dictionary) -> Control:
	var h = Kit.hbox(8)
	var off = bool(plan.get("off", false))
	var keys = []
	if plan.cycle.is_empty():
		var lb = Kit.choice("Lift", not off, _call_day.bind("lift"), Pal.LIFT, 13)
		lb.tooltip_text = "Lift today"
		keys.append(lb)
	for k in plan.cycle:
		var b = Kit.choice(str(Missions.KIND_SHORT[k]), not off and str(k) == str(plan.kind), _pick_kind.bind(str(k)), Pal.LIFT, 13)
		b.tooltip_text = "Plan today as a %s" % str(Missions.KIND_NAMES[k]).to_lower()
		keys.append(b)
	var rb = Kit.choice("Rest", off, _call_day.bind("rest"), Pal.SECOND, 13)
	rb.tooltip_text = "No lifting today: the day's lifts move to tomorrow, and the days after follow"
	rb.set_meta("rest_chip", true)
	keys.append(rb)
	var track = Kit.choice_track(keys)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(track)
	# The split combo: lift days this week in the split's order.
	var cb = Missions.combo(App.sessions(), App.today, plan.cycle, App.pt())
	if int(cb.now) >= 2:
		var pill = Kit.pill("flame", "×%d" % int(cb.now), Pal.ACCENT2, "Combo: %d lift days in a row in your split's order this week" % int(cb.now), Color.WHITE, 13)
		Fx.embers(pill, Pal.ACCENT2, 2)
		h.add_child(Kit.vcenter(pill))
	return h


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


static func _step_kg(wu: String) -> float:
	return 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)


## What to aim for in a planned lift that is not done yet, as its row says it:
## {"cap", "said", "col"}. `main`: the way it would be done first ({"new",
## "last" (sets), "sides"}); `got`: the sets an extra lift of the focus
## already has today. The Log tab's "From today's plan" says the same.
static func aim_words(l: Dictionary, main: Dictionary, wu: String, got: int = 0) -> Dictionary:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var dose = l.get("dose")
	if bool(l.pt):
		return {"cap": "AS LAST TIME", "said": LiftHistory.describe_sets(l.last.sets, fmt_w), "col": Pal.PT}
	if dose != null:
		var cap = ("%d OF %d SETS" % [got, int(dose.sets)]) if got > 0 else ("ADD · %d SETS" % int(dose.sets))
		if bool(main.new):
			return {"cap": cap, "said": "6 to 12 reps, hard", "col": Pal.SECOND}
		return {"cap": cap, "said": LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w), "col": Pal.ACCENT}
	if bool(main.new):
		return {"cap": "FIRST TIME", "said": "Find your weight", "col": Pal.SECOND}
	# (reps logged as both sides added up: the aim is that total too)
	return {"cap": "AIM · %s" % Sides.SHORT if int(main.get("sides", 1)) > 1 else "AIM",
		"said": LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w), "col": Pal.ACCENT}


## A likely lift as done last (its first option), as a flat row: the name and
## variation with the box at the end of that line, what to aim for on a line
## of its own, why it is likely (unless the heading said it: `shared_why`), the
## warm-up for a barbell; the other ways the player has done it under it as
## outlined chips. Done today (any way): what was done.
static func _lift_row(l: Dictionary, wu: String, same: Dictionary = {}, shared_why: String = "") -> Card:
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
	# The stripe only says a state: done, or the muscle a lift of the focus is for.
	var stripe = Pal.LINE
	if done_name != "":
		stripe = Pal.GOOD
	elif dose != null:
		stripe = JourneyLifts.part_color(str(dose.part))
	var c = Kit.row(JourneyLifts.open_named.bind(shown, {"view": "compare"}), stripe, Pal.GOOD if done_name != "" else null, 8, 4)
	c.tooltip_text = "Last time, and what to beat"
	var left = Kit.vbox(2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Line 1: the movement, its variation and tags, the box at the end.
	var line1 = Kit.hbox(8)
	line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.squeeze(6)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp = LiftNames.split(shown)
	top.add_child(Kit.soft_name(str(sp.move), 15, null, true, 200.0))
	if str(sp.variation) != "":
		top.add_child(SessionView.variation_tag(str(sp.variation), 11, true))
	if dose != null and done_name == "":
		var ft = Kit.tag("FOR " + Dose.part_name(str(dose.part)).to_upper(), JourneyLifts.part_color(str(dose.part)), true, 11)
		ft.tooltip_text = "Added by your training focus"
		top.add_child(Kit.vcenter(ft))
	if bool(l.pt):
		top.add_child(Kit.vcenter(SessionView.pt_tag(11)))
	elif LiftTrend.plateau(_history_of(shown)) != null:
		var st_tag = Kit.tag("STUCK", Pal.DANGER, true, 11)
		st_tag.tooltip_text = "No new best for three sessions: its page has ways out"
		top.add_child(Kit.vcenter(st_tag))
	line1.add_child(top)
	line1.add_child(_tick(done_name != ""))
	left.add_child(line1)
	# Line 2: what to aim for (or what was done), white; gold is for rewards.
	var said = ""
	var cap = ""
	var col = Pal.PT if bool(l.pt) else Pal.TEXT
	var beat = false
	if done_name != "":
		# Already done today (any way): what was done, green when it beat last
		# time or was a first.
		beat = Missions.beat_any(App.sessions(), ways if not ways.is_empty() else [str(l.name)], "" if bool(l.pt) else planned_move, App.today, same)
		said = LiftHistory.describe_sets(Missions.sets_on(App.sessions(), done_name, App.today), fmt_w)
		cap = "DONE · BEAT IT" if beat else "DONE TODAY"
		col = Pal.GOOD if beat else Pal.TEXT
	else:
		var aim = aim_words(l, main, wu, int(Dose.extra_done(l, App.sessions(), App.today, same).sets) if dose != null else 0)
		said = str(aim.said)
		cap = str(aim.cap)
		col = Pal.TEXT if aim.col == Pal.ACCENT else aim.col
	var line2 = Kit.hbox(6)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(Kit.vcenter(Kit.label(cap, 11, Pal.GOOD if beat else Pal.MUTED, true)))
	line2.add_child(Kit.vcenter(Kit.clip(said, 14, col, true)))
	left.add_child(line2)
	# Line 3: why it is likely (an extra lift once done: what it was for, its
	# count is out of date), unless the heading already says it.
	var why = "Added for your %s" % Dose.part_name(str(dose.part)).to_lower() if (dose != null and done_name != "") else str(l.why)
	if why != "" and not (dose == null and why == shared_why):
		left.add_child(Kit.clip(why, 12, Pal.MUTED))
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
			var wl = Kit.para(" · ".join(PackedStringArray(bits)), 11, Pal.MUTED)
			wl.tooltip_text = "Warm-up sets, then the plates on each side of the bar"
			left.add_child(wl)
	c.add(left)
	# The other ways to do it here, each opening its own page.
	if done_name == "" and opts.size() > 1:
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orl = Kit.label("OR", 11, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		# Each other way: a variation of the same movement by its own words, another
		# movement by its name; one never done yet in the "new" colour.
		var main_move = str(main.get("move", LiftNames.split(str(main.name)).move))
		for o in opts.slice(1):
			var same_move = str(o.move) == main_move
			var text = str(o.variation) if same_move and str(o.variation) != "" else Missions.way_word(o, main_move)
			var b = Kit.option_chip(text, Pal.SECOND if bool(o.new) else null, JourneyLifts.open_named.bind(str(o.name), {"view": "compare"}), 12)
			b.tooltip_text = ("New to you: " if bool(o.new) else "") + Missions.short_name(str(o.name))
			b.set_meta("lift_option", str(o.name))
			more.add_child(b)
		c.add(more)
	return c


## A lift's history (newest first), as LiftLibrary.stats keeps it.
static func _history_of(lift_name: String) -> Array:
	var st = LiftLibrary.stats(App.sessions()).get(Xp.normalize_exercise(lift_name))
	if st == null:
		return []
	# (reps logged as both sides added up are judged by one side, as on its page)
	var sides = Sides.n(App.settings(), lift_name)
	return Sides.tagged(st.history, sides) if sides > 1 else st.history


## A done box (Kit.tick_box, the same everywhere): an empty well while still to
## do, solid green with a tick once done today.
static func _tick(done: bool) -> Control:
	var box = Kit.tick_box(done, 26)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = "Done today" if done else "Still to do today"
	box.set_meta("done_tick", done)
	return box


## Was a session of this kind logged today?
static func _did_today(discipline: String) -> bool:
	return App.sessions().any(func(s): return str(s.get("date", "")) == App.today and str(s.get("discipline", "")) == discipline)


## The movement to try: blue until done (any movement never done before, with
## the same goal, counts), then green and named as the lift that did it.
static func _new_row(nw: Dictionary) -> Card:
	# Done as the mission counts it: this movement logged today, or another one
	# never done before. Then the row names the lift that did it, so a tick never
	# stands beside a movement that was not done.
	var by = ""
	for m in App.quests().daily:
		if str(m.id).ends_with(":new") and bool(m.done):
			by = str(m.get("by", ""))
	var done = by != ""
	var c = Kit.row(JourneyLifts.open_named.bind(str(nw.name), {"view": "compare"}), Pal.GOOD if done else Pal.SECOND, Pal.GOOD if done else null, 8, 4)
	c.tooltip_text = "How to do it"
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var other = done and Xp.normalize_exercise(str(LiftNames.split(by).move)) != Xp.normalize_exercise(str(nw.move))
	var head = Kit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Kit.vcenter(Icons.rect("sparkle", 16)))
	head.add_child(Kit.vcenter(Kit.label("SOMETHING NEW · DONE" if done else "TRY SOMETHING NEW", 11, Pal.GOOD if done else Pal.SECOND, true)))
	v.add_child(head)
	var line = Kit.hbox(8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.squeeze(6)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if other:
		var sp = LiftNames.split(by)
		top.add_child(Kit.soft_name(str(sp.move), 15, null, true, 200.0))
		if str(sp.variation) != "":
			top.add_child(SessionView.variation_tag(str(sp.variation), 11, true))
		top.add_child(Kit.vcenter(Kit.tag("First time", Pal.SECOND, true, 11)))
	else:
		top.add_child(Kit.soft_name(str(nw.move), 15, null, true, 200.0))
		if str(nw.variation) != "":
			top.add_child(SessionView.variation_tag(str(nw.variation), 11, true))
		top.add_child(Kit.vcenter(Kit.tag(str(nw.partName), JourneyLifts.part_color(str(nw.part)), true, 11)))
	line.add_child(top)
	line.add_child(_tick(done))
	v.add_child(line)
	c.add(v)
	# Others that count just the same, for when the equipment is not there.
	var alts = nw.get("alts", [])
	if not done and not alts.is_empty():
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orl = Kit.label("OR", 11, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		for a in alts:
			var b = Kit.option_chip(Missions.short_name(str(a.name)), Pal.SECOND, JourneyLifts.open_named.bind(str(a.name), {"view": "compare"}), 12)
			b.tooltip_text = "New to you: a %s movement" % str(a.partName).to_lower()
			b.set_meta("new_alt", str(a.name))
			more.add_child(b)
		c.add(more)
	return c


## Physical therapy as ONE row: the day's goal (Missions.pt_goal: 3 a day, or
## fewer when fewer are still needed this week) as pips, done today of it, and
## the ones still needed this week, the furthest behind first, to pick from.
## (The week itself is the PT THIS WEEK section.)
static func _pt_row(plan: Dictionary) -> Control:
	var goal = Missions.pt_goal(plan)
	var done = Missions.pt_today(plan, App.sessions(), App.today)
	var left = Missions.pt_left(plan, App.sessions(), App.today)
	var all_done = done >= goal
	var c = Kit.row(PtView.open, Pal.GOOD if all_done else Pal.PT, Pal.GOOD if all_done else null, 8, 4)
	# (not the PT section's "Physical therapy: are you keeping up?": tests count that one)
	c.tooltip_text = "Today: any %d of your PT exercises, the ones furthest behind first (the week is on the PT page)" % goal
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line1 = Kit.hbox(6)
	line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line1.add_child(Kit.vcenter(Icons.rect("pt", 16)))
	line1.add_child(Kit.vcenter(Kit.clip("Physical therapy today", 15, null, true)))
	line1.add_child(_tick(all_done))
	v.add_child(line1)
	var line2 = Kit.hbox(8)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(Kit.pips(mini(done, goal), goal, Pal.GOOD if all_done else Pal.PT, 10))
	var count = ("%d of %d done" % [done, goal]) if done <= goal else ("%d done, %d was the goal" % [done, goal])
	line2.add_child(Kit.vcenter(Kit.label(count, 12, Pal.GOOD if all_done else Pal.MUTED, true)))
	v.add_child(line2)
	var said = ""
	if all_done:
		said = "That is today's PT. More is a bonus."
	elif not left.is_empty():
		said = "Any %d of: %s" % [goal - done, ", ".join(PackedStringArray(left))]
	if said != "":
		v.add_child(Kit.clip(said, 12, Pal.MUTED))
	c.add(v)
	return c


## The likely climb or run: its name in its colour, what it usually is (or on
## the run day what to aim for), why, the open project, a quicker pace.
static func _other_row(o: Dictionary) -> Control:
	var d = str(o.discipline)
	var did = _did_today(d)
	var dcol = Pal.disc(d)
	var c = Kit.row(Callable(), Pal.GOOD if did else dcol, Pal.GOOD if did else null, 8, 4)
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line1 = Kit.hbox(6)
	line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line1.add_child(Kit.vcenter(Icons.rect(d if d != "misc" else "vest", 16)))
	line1.add_child(Kit.vcenter(Kit.clip(TT.DISCIPLINE_META[d].name, 15, dcol, true)))
	line1.add_child(_tick(did))
	v.add_child(line1)
	var cap = "USUALLY"
	var said = ""
	if d == "climb":
		said = "%d sends" % TTUtil.jsround(float(o.avg))
	else:
		said = Fmt.fmt_distance(float(o.avg), App.distance_unit())
	var pace = ""
	var run_goal = App.plan().get("run")
	if d == "run" and run_goal != null:
		# The weekly run on its day (training focus): further, or quicker.
		cap = "RUN DAY"
		said = "aim %s" % Fmt.fmt_distance(float(run_goal.targetM), App.distance_unit())
		if float(run_goal.paceSec) > 0.0:
			pace = "or quicker than %s over %s" % [Fmt.fmt_pace(float(run_goal.paceSec), App.distance_unit()), Fmt.fmt_distance(float(run_goal.paceM), App.distance_unit())]
	elif d == "run" and bool(App.plan().get("runToday", false)):
		cap = "RUN DAY"
		said = "log a run"
	var line2 = Kit.hbox(6)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(Kit.vcenter(Kit.label(cap, 11, dcol, true)))
	line2.add_child(Kit.vcenter(Kit.clip(said, 14, Pal.TEXT, true)))
	v.add_child(line2)
	if str(o.why) != "":
		v.add_child(Kit.clip(str(o.why), 12, Pal.MUTED))
	if d == "climb":
		var pj = App.open_projects()
		if not pj.is_empty():
			var st = Projects.status(pj[0], App.sessions(), App.today)
			v.add_child(Kit.clip("Project: %s · %d session%s so far" % [Projects.title(pj[0]), int(st.sessions), "" if int(st.sessions) == 1 else "s"], 12, Pal.CLIMB, true))
	if pace != "":
		v.add_child(Kit.clip(pace, 12, Pal.MUTED))
	c.add(v)
	return c
