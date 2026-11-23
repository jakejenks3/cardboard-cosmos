class_name AheadView
extends RefCounted
## The days ahead (Missions.ahead via App.ahead()): a card under the Today card
## with the next few days in a word each ("Tue Push", "Thu Rest"), and a sheet
## with every day as it will probably go: its kind, the lifts with what to aim
## for and the other ways to do them, the lift a training focus adds, the
## movement to try, the PT, the likely climb or run, a rest day when one is
## due. It is a look, to plan and look forward: nothing in it is logged,
## ticked or stored, and it moves with what is really done.

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


## The Hero tab's card, or null when there is no pattern to look ahead from.
static func card():
	var days = App.ahead()
	if not _any(days):
		return null
	var c = Kit.card(6, AheadView.open, 10)
	c.tooltip_text = "The next days, if each goes as planned"
	c.set_meta("ahead_card", true)
	var head = Kit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Kit.vcenter(Icons.rect("calendar", 20)))
	var t = PixelFont.rect("COMING UP", 2, Pal.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	head.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(head)
	var cells = Kit.hbox(6)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a in days.slice(0, STRIP_DAYS):
		var w = Missions.ahead_word(a)
		var v = Kit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wd = Kit.label(Dates.format_date(str(a.date), {"weekday": "short"}).to_upper(), 10, Pal.MUTED, true)
		wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wd)
		var tag = Kit.tag(str(w.text), _color(str(w.what)), true, 12)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tag)
		cells.add_child(v)
	c.add(cells)
	return c


## What to aim for on a planned lift, in a few words.
static func _aim(l: Dictionary, wu: String) -> String:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
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
static func _day_card(a: Dictionary, wu: String, du: String) -> Control:
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
	c.add(head)
	# What the day's plan gives each of its muscles, and where the week then
	# stands against its target (a training focus).
	var dose = plan.get("doseToday", [])
	if bool(a.lift) and not dose.is_empty():
		var tags = Kit.flow(4)
		tags.set_meta("ahead_dose", str(a.date))
		for d in dose:
			var after = float(a.get("week", {}).get(str(d.part), float(d.after)))
			var text = "%s +%s → %s/%s" % [Dose.part_name(str(d.part)), Dosage._n(float(d.today)), Dosage._n(after), Dosage._n(float(d.min))]
			if str(d.mode) == "build":
				tags.add_child(Kit.tag(text, DoseView.state_color(DoseView.state_of(after, float(d.min), float(d.max))), true, 10))
			else:
				tags.add_child(Kit.tag(text, Pal.PANEL2, false, 10))
		c.add(tags)
	if bool(a.rest):
		c.add(_line("moon", "%d hard days in a row by then" % int(plan.rest.run), Pal.SECOND))
		c.add(Kit.clip("A walk, PT and stretches are fine. The lifts move to the day after.", 11, Pal.MUTED))
	elif bool(a.lift):
		for l in plan.lifts:
			if not bool(l.pt):
				c.add(_lift_row(l, wu))
		if plan.new != null:
			c.add(_line("sparkle", "Try: %s" % Missions.new_words(plan.new)))
	elif a.others.is_empty():
		c.add(Kit.clip("Nothing likely: you rarely train on a %s" % Dates.format_date(str(a.date), {"weekday": "long"}), 12, Pal.MUTED))
	else:
		c.add(Kit.clip("No lifting likely on a %s" % Dates.format_date(str(a.date), {"weekday": "long"}), 11, Pal.MUTED))
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
	return c


## The sheet: every day of the look-ahead.
static func open() -> void:
	Sfx.tick()
	var days = App.ahead()
	var sh = Kit.sheet("Coming up")
	if not _any(days):
		sh.box.add_child(Kit.para("Not enough workouts yet to look ahead. After a few weeks this shows what the next days will probably be.", 13, Pal.MUTED))
	else:
		sh.box.add_child(Kit.para("The next days if each one goes as planned. Nothing here is logged, and it moves with what you really do.", 12, Pal.MUTED))
		var week = _week_card(days)
		if week != null:
			sh.box.add_child(week)
		for a in days:
			sh.box.add_child(_day_card(a, App.weight_unit(), App.distance_unit()))
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()
