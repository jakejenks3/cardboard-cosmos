class_name DoseView
extends RefCounted
## The training focus on screen (game/dose.gd): a row on the Today card with
## the sets the day's muscles got in the last seven days against their weekly
## target, and a sheet with every muscle, what counted, the rest days and the
## run. Colours say the state: orange short, green on target, blue plenty.

static func state_color(state: String) -> Color:
	match state:
		"short":
			return Pal.ACCENT2
		"plenty":
			return Pal.SECOND
		"ok":
			return Pal.GOOD
	return Pal.MUTED


static func state_word(state: String) -> String:
	return {"short": "SHORT", "ok": "ON TARGET", "plenty": "PLENTY"}.get(state, "")


static func _window() -> Dictionary:
	return Dose.window(App.sessions(), App.pt(), App.settings(), App.today)


## The muscles the Today card's row shows: the day's own (those with a target),
## else the ones being built that are short, else the first being built.
static func row_parts(plan: Dictionary, w: Dictionary) -> Array:
	var parts = Dose.parts_today(str(plan.get("kind", "")), str(plan.get("group", ""))).filter(func(p): return str(w.parts[p].mode) != "")
	if parts.is_empty():
		var build = Dose.build_parts(App.settings())
		parts = build.filter(func(p): return str(w.parts[p].state) == "short")
		if parts.is_empty():
			parts = build
	return parts.slice(0, 4)


## "short" / "ok" / "plenty" for a muscle's sets against its target.
static func state_of(total: float, least: float, most: float) -> String:
	return "short" if total < least - 0.01 else ("plenty" if total > most + 0.01 else "ok")


## One muscle in a row of small bars: its name, a bar of `now` against the
## least it needs, and "now / least", or "now → after / least" when a plan
## will take it further. The colour says where `after` leaves it.
static func cell(part: String, now: float, after: float, least: float, most: float) -> Control:
	var col = state_color(state_of(maxf(now, after), least, most))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(Dose.part_name(part), 11, Pal.TEXT, true))
	v.add_child(Kit.bar(clampf(now / maxf(1.0, least), 0.0, 1.0), col, 6))
	var said = "%s / %s" % [Dosage._n(now), Dosage._n(least)]
	if after > now + 0.01:
		said = "%s → %s / %s" % [Dosage._n(now), Dosage._n(after), Dosage._n(least)]
	v.add_child(Kit.clip(said, 11, col, true))
	return v


## The Today card's row: a small bar per muscle of the day. On a lift day it
## is the PLAN's sum: the sets of the last seven days now, and where today's
## plan takes each muscle ("3 → 10 / 10"), against the least it needs in a
## week. Otherwise the last seven days as they stand.
static func row(plan: Dictionary) -> Control:
	var w = _window()
	var today = plan.get("doseToday", [])
	var c = Kit.card(4, DoseView.open, 8)
	c.tooltip_text = "Your weekly sets per muscle, and what counts"
	c.set_meta("dose_row", true)
	var head = Kit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t = Kit.label("SETS THIS WEEK · NOW → AFTER TODAY'S PLAN" if not today.is_empty() else "LAST 7 DAYS · SETS", 10, Pal.LIFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(head)
	var cells = Kit.hbox(10)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if today.is_empty():
		for p in row_parts(plan, w):
			var r = w.parts[p]
			cells.add_child(cell(str(p), float(r.total), float(r.total), float(r.min), float(r.max)))
	else:
		for d in today.slice(0, 4):
			# What is really logged, and what the plan makes of the week (never less than that).
			var now = float(w.parts[str(d.part)].total)
			cells.add_child(cell(str(d.part), now, maxf(now, float(d.after)), float(d.min), float(d.max)))
	c.add(cells)
	return c


static func _part_row(p: String, r: Dictionary) -> Control:
	var col = state_color(str(r.state))
	var v = Kit.vbox(1)
	var row = Kit.hbox(8)
	var n = Kit.label(Dose.part_name(p), 14, null, true)
	n.custom_minimum_size = Vector2(92, 0)
	row.add_child(Kit.vcenter(n))
	row.add_child(Kit.bar(clampf(float(r.total) / maxf(1.0, float(r.min)), 0.0, 1.0), col, 10))
	var num = Kit.label("%s / %s-%s" % [Dosage._n(float(r.total)), Dosage._n(float(r.min)), Dosage._n(float(r.max))], 12, Pal.TEXT, true)
	num.custom_minimum_size = Vector2(82, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(Kit.vcenter(num))
	var tag = Kit.tag(state_word(str(r.state)), col, true, 9)
	tag.custom_minimum_size = Vector2(72, 0)
	row.add_child(Kit.vcenter(tag))
	v.add_child(row)
	var bits = []
	if float(r.direct) > 0.0:
		bits.append("%s direct" % Dosage._n(float(r.direct)))
	if float(r.indirect) > 0.0:
		bits.append("%s from other lifts" % Dosage._n(float(r.indirect)))
	if float(r.climb) > 0.0:
		bits.append("%s from climbing" % Dosage._n(float(r.climb)))
	v.add_child(Kit.clip(" · ".join(PackedStringArray(bits)) if not bits.is_empty() else "Nothing in the last 7 days", 11, Pal.MUTED))
	return v


## The sheet: every muscle against its target, rest, the run, how it is counted.
static func open() -> void:
	Sfx.tick()
	var st = App.settings()
	var plan = Dose.plan_of(st)
	if plan == null:
		return
	var w = _window()
	var sh = Kit.sheet("Weekly sets")
	sh.box.add_child(Kit.label(str(plan.name), 16, Pal.LIFT, true))
	sh.box.add_child(Kit.para(str(plan.blurb) + " Sets of the last 7 days against what each muscle needs in a week.", 12, Pal.MUTED))
	for mode in ["build", "keep"]:
		var parts = Dose.PARTS.filter(func(p): return str(w.parts[p].mode) == mode)
		if parts.is_empty():
			continue
		sh.box.add_child(Kit.section_title("Build" if mode == "build" else "Keep as it is"))
		if mode == "keep":
			sh.box.add_child(Kit.para("No sets are added for these. Their lifts still have goals to beat.", 11, Pal.MUTED))
		for p in parts:
			sh.box.add_child(_part_row(str(p), w.parts[p]))
	# Rest and the run.
	sh.box.add_child(Kit.section_title("Rest and running"))
	var rest = Dose.rest(App.sessions(), App.pt(), App.today)
	var rest_text = "%d lifting day%s in a row. A rest day from lifting is due after %d: a run, a climb, PT and a walk are fine on one. The Rest chip on the Today card makes any day one." % [int(rest.run), "" if int(rest.run) == 1 else "s", Dose.REST_AFTER]
	var today_plan = App.plan()
	if bool(today_plan.get("off", false)):
		rest_text = "Today is a rest day from lifting (%s). %s." % ["your call" if str(today_plan.rest.call) == "rest" else "%d lifting days in a row" % int(today_plan.rest.run), Missions.off_moves(today_plan)]
	sh.box.add_child(_line("moon", rest_text))
	if Dose.run_on(st):
		var tomorrow = Dates.add_days(App.today, 1)
		var g = Dose.run_goal(App.sessions(), tomorrow, App.distance_unit())
		var rd = Dose.run_day(App.sessions(), st, tomorrow)
		var day_words = ("Run day: %s. " % str(Dose.WEEKDAYS[rd])) if rd >= 0 else "Pick your run day in Settings. "
		if g == null:
			sh.box.add_child(_line("run", day_words + "Log a run and the next one gets goals. They show on that day only."))
		else:
			var quicker = (", or quicker than %s" % Fmt.fmt_pace(float(g.paceSec), App.distance_unit())) if float(g.paceSec) > 0.0 else ""
			sh.box.add_child(_line("run", "%sNext run: %s%s. %s. Run goals show on that day only." % [day_words, Fmt.fmt_distance(float(g.targetM), App.distance_unit()), quicker, Dose.run_why(g, App.distance_unit())]))
	sh.box.add_child(Kit.para("A set of a lift counts 1 for its main muscle and a half for the muscles it also works. A climbing session counts %s sets for the forearms and nothing for the back: climbing is fingers far more than pulling. Physical therapy and stretches count for nothing here. Change the focus in Settings, under Training focus." % Dosage._n(float(Dose.CLIMB_SETS.forearms)), 11, Pal.MUTED))
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()


static func _line(icon: String, text: String) -> Control:
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect(icon, 20)))
	var l = Kit.para(text, 13, Pal.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h
