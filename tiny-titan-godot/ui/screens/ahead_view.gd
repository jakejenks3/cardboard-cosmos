class_name AheadView
extends RefCounted
## The days ahead (Missions.ahead via App.ahead()): a section under the Today
## section with the next few days in a word each ("Tue Push", "Thu Legs"), and a sheet
## with every day as it will go: its kind, the lifts with what to aim for and
## the other ways to do them, the lift a training focus adds, the movement to
## try, the PT, the likely climb or run. Every day is a lift day: no rest day
## is planned by the game. It is a look, to plan and look forward: nothing in
## it is logged or ticked, and it moves with what is really done.
## The one thing that can be set here is a REST DAY (Missions.call_of): every
## day has a Rest key (its lifts move to the day after and every day after
## that follows, a day later); a day called rest has a Lift key to undo it.

## After a key was tapped the sheet is rebuilt, and the opposite key now sits
## where the finger is: taps are ignored for this long.
const QUIET_MS = 450
static var _quiet_until = 0
## The width of a day's Rest / Lift key.
const KEY_W = 88

## Days on the Hero tab's card (the sheet has Missions.AHEAD_DAYS).
const STRIP_DAYS = 4


static func _color(what: String) -> Color:
	match what:
		"lift":
			return Pal.LIFT
		"rest":
			return Pal.SECOND
		"":
			return Pal.MUTED
	return Pal.disc(what)


## Is there anything to show: a day with a lift, a rest day or another activity?
static func _any(days: Array) -> bool:
	return days.any(func(a): return bool(a.lift) or bool(a.rest) or not a.others.is_empty())


## The Hero tab's COMING UP section (right under Today), or null when there is
## no pattern to look ahead from. A tap anywhere on it opens the sheet.
static func card():
	var days = App.ahead()
	if not _any(days):
		return null
	var c = Kit.section("ahead", "COMING UP", "calendar", Pal.BORDER, Icons.rect("chevron_right", 16), AheadView.open, 6, 10)
	c.tooltip_text = "The next days, if each goes as planned"
	c.set_meta("ahead_card", true)
	var cells = Kit.hbox(6)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a in days.slice(0, STRIP_DAYS):
		var w = Missions.ahead_word(a)
		var v = Kit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wd = Kit.label(Dates.format_date(str(a.date), {"weekday": "short"}).to_upper(), 11, Pal.MUTED, true)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wd)
		var tag = Kit.tag(str(w.text), _color(str(w.what)), true, 12)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tag)
		cells.add_child(v)
	c.add(cells)
	# Prep tomorrow (PrepView): its lifts the way you'll do them, with what you'll have.
	var tomorrow = Dates.add_days(App.today, 1)
	var t_ahead = days.filter(func(a): return str(a.date) == tomorrow)
	# (any day but one called rest: a day the game sees no lifts for can be prepped from nothing)
	if not t_ahead.is_empty() and (not bool(t_ahead[0].rest) or Prep.of(App.settings(), tomorrow) != null):
		var prepped = Prep.of(App.settings(), tomorrow) != null
		var pk = Kit.button("Tomorrow is prepped · Edit" if prepped else "Prep tomorrow's workout", "secondary" if prepped else "primary", PrepView.open.bind(tomorrow), "md", "check" if prepped else "edit")
		pk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pk.tooltip_text = "Pick each lift's way and equipment, its weights and reps, and supersets for tomorrow"
		pk.set_meta("prep_tomorrow", prepped)
		c.add(pk)
	return c


## What to aim for on a planned lift, in a few words.
static func _aim(l: Dictionary, wu: String) -> String:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	if l.has("aimSets"):
		# (a prepped day: the sets prepped)
		return Prep.describe(l.aimSets, str(l.name), fmt_w)
	var opts = l.get("options", [])
	var first = opts[0] if not opts.is_empty() else {"new": false, "last": l.last.sets}
	var step = 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)
	if int(first.get("planned", 0)) > 0 and not l.has("dose"):
		# Only planned so far (an extra lift of an earlier day in this look-ahead).
		return "%d sets" % int(first.planned)
	if l.has("dose"):
		if bool(first.new):
			return "add %d sets" % int(l.dose.sets)
		return "%d sets · %s" % [int(l.dose.sets), LiftHistory.describe_sets(LiftTrend.next_target(first.last, step).sets, fmt_w)]
	if bool(first.new):
		return "first time"
	return LiftHistory.describe_sets(LiftTrend.next_target(first.last, step).sets, fmt_w)


## A planned lift: its name and variation, what to aim for, the other ways
## under it. A tap opens the lift's page.
static func _lift_row(l: Dictionary, wu: String) -> Control:
	var opts = l.get("options", [])
	var first_name = str(opts[0].name) if not opts.is_empty() else str(l.name)
	var c = Kit.card(0, JourneyLifts.open_named.bind(first_name, {"view": "compare"}), 6)
	c.tooltip_text = "Its page: last time and its history"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left = Kit.vbox(1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The MOVEMENT first, then the ways to do it as tags: the one done last lit,
	# the others after an "or" (one never done yet in the "new" colour).
	var top = Kit.squeeze(6)
	var sp = LiftNames.split(first_name)
	top.add_child(Kit.soft_name(str(sp.move), 14, null, true, 200.0))
	if l.has("dose"):
		top.add_child(Kit.vcenter(Kit.tag("FOR " + Dose.part_name(str(l.dose.part)).to_upper(), JourneyLifts.part_color(str(l.dose.part)), true, 10)))
	left.add_child(top)
	# The way done last in a word: its variation, or the equipment of a plain
	# one ("cable", "bodyweight"); nothing for a lift with neither.
	var main_word = str(sp.variation)
	if main_word == "" and not opts.is_empty():
		main_word = Missions.way_word(opts[0], str(sp.move))
		if main_word == "plain":
			main_word = ""
		else:
			main_word = main_word.capitalize()
	if main_word != "" or opts.size() > 1:
		var ways = Kit.flow(4)
		ways.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ways.set_meta("lift_ways", first_name)
		if main_word != "":
			ways.add_child(Kit.tag(main_word, Pal.LIFT, true, 10))
		if opts.size() > 1:
			var orl = Kit.label("or", 10, Pal.MUTED, true)
			orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ways.add_child(orl)
			for o in opts.slice(1):
				var text = str(o.variation) if (str(o.move) == str(sp.move) and str(o.variation) != "") else Missions.way_word(o, str(sp.move))
				ways.add_child(Kit.tag(text, Pal.with_alpha(Pal.SECOND, 0.85) if bool(o.new) else Pal.PANEL2, bool(o.new), 10))
		left.add_child(ways)
	row.add_child(left)
	var aim = Kit.label(_aim(l, wu), 12, Pal.SECOND if (not opts.is_empty() and bool(opts[0].new)) else Pal.ACCENT, true)
	aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(Kit.vcenter(aim))
	c.add(row)
	return c


static func _line(icon: String, text: String, color = null) -> Control:
	var h = Kit.hbox(6)
	h.add_child(Kit.vcenter(Icons.rect(icon, 16)))
	var l = Kit.clip(text, 12, Pal.TEXT if color == null else color, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


## One day of the look-ahead.
static func _day_card(a: Dictionary, wu: String, du: String, sh = null) -> Control:
	var plan = a.plan
	var w = Missions.ahead_word(a)
	var col = _color(str(w.what))
	var c = Kit.card(6, Callable(), 10)
	c.accent(col)
	c.set_meta("ahead_day", str(a.date))
	var head = Kit.hbox(8)
	var names = Kit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wd = PixelFont.rect(Dates.format_date(str(a.date), {"weekday": "long"}).to_upper(), 2, Pal.TEXT)
	wd.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	names.add_child(wd)
	names.add_child(Kit.clip(Dates.format_date(str(a.date), {"month": "short", "day": "numeric"}), 11, Pal.MUTED, true))
	head.add_child(names)
	var label = "Rest day" if bool(a.rest) else (str(plan.label) if (bool(a.lift) and str(plan.label) != "") else ("Lift" if bool(a.lift) else str(w.text)))
	head.add_child(Kit.vcenter(Kit.tag(label, col, true, 12)))
	# The player's call for the day: Rest on a lift day, Lift on any other.
	if sh != null and (bool(a.lift) or bool(a.get("can_lift", false))):
		var want = "rest" if bool(a.lift) else "lift"
		var key = Kit.button("Rest" if want == "rest" else "Lift", "secondary", _call.bind(sh, a, want), "sm", "moon" if want == "rest" else "lift")
		key.tooltip_text = "No lifting that day: its lifts move to the next lift day, and the days after follow" if want == "rest" else "Lift that day"
		key.set_meta("ahead_call", "%s:%s" % [str(a.date), want])
		# Both keys in a slot of one width (a button with an icon sets its own):
		# after a tap the other key is exactly where this one was.
		var slot = MarginContainer.new()
		slot.custom_minimum_size = Vector2(KEY_W, 0)
		slot.add_child(key)
		head.add_child(Kit.vcenter(slot))
	c.add(head)
	# What the day's plan gives each of its muscles, and where the week then
	# stands against its target (a training focus).
	var dose = plan.get("doseToday", [])
	if bool(a.lift) and not dose.is_empty():
		var tags = Kit.flow(4)
		tags.set_meta("ahead_dose", str(a.date))
		for d in dose:
			var after = float(a.get("week", {}).get(str(d.part), float(d.after)))
			# (the week against its whole range: "30.5/8-16" is over the top, where
			# "30.5/8" read like thirty of eight)
			var text = "%s +%s → %s/%s-%s" % [Dose.part_name(str(d.part)), Dosage._n(float(d.today)), Dosage._n(after), Dosage._n(float(d.min)), Dosage._n(float(d.max))]
			if str(d.mode) == "build":
				tags.add_child(Kit.tag(text, DoseView.state_color(DoseView.state_of(after, float(d.min), float(d.max))), true, 10))
			else:
				tags.add_child(Kit.tag(text, Pal.PANEL2, false, 10))
		# Where those sets come from, lift by lift: the Weekly sets sheet.
		var why = Kit.chip("What counts?", false, DoseView.open, null, 10)
		why.set_meta("ahead_why", str(a.date))
		tags.add_child(why)
		c.add(tags)
	if bool(a.rest):
		c.add(_line("moon", "Your call: a rest from lifting", Pal.SECOND))
		c.add(Kit.clip("%s. A run, PT and a walk are fine." % Missions.off_moves(plan, "the day after"), 11, Pal.MUTED))
	elif bool(a.lift):
		if bool(plan.get("prepped", false)):
			c.add(_line("check", "Prepped: your lifts, ways and sets", Pal.GOOD))
		for l in plan.lifts:
			if not bool(l.pt):
				c.add(_lift_row(l, wu))
		if plan.new != null:
			c.add(_line("sparkle", "Try: %s" % Missions.new_words(plan.new)))
	elif a.others.is_empty():
		c.add(Kit.clip("Nothing to plan for this day yet", 12, Pal.MUTED))
	else:
		c.add(Kit.clip("No lifts to plan yet", 11, Pal.MUTED))
	if sh != null and not bool(a.rest):
		# Prep the day (PrepView): the way of each lift with what you'll have, its sets, supersets; any day not
		# called rest, a day with no lifts planned too (from nothing).
		var prepped = Prep.of(App.settings(), str(a.date)) != null
		var pk = Kit.button("Edit prep" if prepped else "Prep this day", "secondary", func():
			sh.close()
			PrepView.open(str(a.date)), "md", "edit")
		pk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pk.set_meta("ahead_prep", str(a.date))
		c.add(pk)
	if not plan.pt.is_empty():
		c.add(_line("pt", "PT: %s" % ", ".join(PackedStringArray(plan.pt.map(func(r): return str(r.name)))), Pal.PT))
	for o in a.others:
		var d = str(o.discipline)
		var said = ""
		if d == "climb":
			said = "usually %d sends" % TTUtil.jsround(float(o.avg))
		elif d == "run" and plan.get("run") != null:
			said = "aim %s" % Fmt.fmt_distance(float(plan.run.targetM), du)
		else:
			said = "usually %s" % Fmt.fmt_distance(float(o.avg), du)
		c.add(_line(d if d != "misc" else "vest", "%s · %s" % [str(TT.DISCIPLINE_META[d].name), said], Pal.disc(d)))
	return c


## Where the plan leads: the sets a week each muscle being built gets when the
## days go as planned (the average of the seven-day totals of the days shown:
## one day's total alone dips whenever a rest day falls in it), against its
## weekly target. null without a training focus.
static func _week_card(days: Array):
	var st = App.settings()
	var plan = Dose.plan_of(st)
	if plan == null or days.is_empty() or days[days.size() - 1].get("week", {}).is_empty():
		return null
	var last = days[days.size() - 1]
	var c = Kit.card(4, DoseView.open, 10)
	c.accent(Pal.LIFT)
	c.set_meta("ahead_week", true)
	c.tooltip_text = "Your weekly sets per muscle, and what counts"
	c.add(Kit.label("IF IT GOES AS PLANNED · SETS A WEEK", 10, Pal.LIFT, true))
	var cells = Kit.hbox(8)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in Dose.build_parts(st):
		var t = plan.targets[p]
		var sum = 0.0
		for a in days:
			sum += float(a.week.get(p, 0.0))
		var total = snappedf(sum / float(days.size()), 0.5)
		cells.add_child(DoseView.cell(str(p), total, total, float(t[0]), float(t[1])))
	c.add(cells)
	# Planned as if every day is lifted, so some may read over their range.
	c.add(Kit.clip("Counts a lift every day. A rest day you call brings these down.", 11, Pal.MUTED))
	return c


## The sheet: every day of the look-ahead.
static func open() -> void:
	Sfx.tick()
	var sh = Kit.sheet("Coming up")
	_fill(sh)
	sh.open()


## (Re)build the sheet. It never gets shorter while it is open, so a key
## tapped near its end stays under the finger when a day loses its lifts.
static func _fill(sh) -> void:
	if sh.box.is_inside_tree():
		sh.box.custom_minimum_size.y = maxf(sh.box.custom_minimum_size.y, sh.box.size.y)
	for ch in sh.box.get_children():
		sh.box.remove_child(ch)
		ch.queue_free()
	var days = App.ahead()
	if not _any(days):
		sh.box.add_child(Kit.para("Not enough workouts yet to look ahead. After a few weeks this shows what the next days will probably be.", 13, Pal.MUTED))
	else:
		sh.box.add_child(Kit.para("Every day is planned as a lift day. Tap Rest on a day to take it off lifting: its lifts move to the day after and everything after that follows, a day later. Nothing here is logged.", 12, Pal.MUTED))
		var week = _week_card(days)
		if week != null:
			sh.box.add_child(week)
		for a in days:
			sh.box.add_child(_day_card(a, App.weight_unit(), App.distance_unit(), sh))
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)


## Call a day of the look-ahead a rest day or a lift day, and show what that
## does to the days after it.
static func _call(sh, a: Dictionary, want: String) -> void:
	if Time.get_ticks_msec() < _quiet_until:
		return
	_quiet_until = Time.get_ticks_msec() + QUIET_MS
	Sfx.tick()
	App.update_settings({"dayCalls": Missions.with_call(App.settings(), str(a.date), want == "rest", App.today)})
	_fill(sh)
