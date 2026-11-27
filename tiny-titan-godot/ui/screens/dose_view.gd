class_name DoseView
extends RefCounted
## The training focus on screen (game/dose.gd): a flat row in the Today section
## with the sets the day's muscles got in the last seven days against their
## weekly target (a bar each: solid = done, faded = today's plan, a white tick =
## the least a week), and a sheet with every muscle, what counted, the rest
## days and the run. Colours say the state: orange short, green on target,
## blue plenty.

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
	var parts = Dose.parts_today(str(plan.get("kind", "")), str(plan.get("group", "")), plan.get("lifts", []), App.pt()).filter(func(p): return str(w.parts[p].mode) != "")
	if parts.is_empty():
		var build = Dose.build_parts(App.settings())
		parts = build.filter(func(p): return str(w.parts[p].state) == "short")
		if parts.is_empty():
			parts = build
	# (the muscles being built first, as on a lift day)
	var built = parts.filter(func(p): return str(w.parts[p].mode) == "build")
	built.append_array(parts.filter(func(p): return str(w.parts[p].mode) != "build" and float(w.parts[p].min) > 0.0))
	return built.slice(0, 4)


## "short" / "ok" / "plenty" for a muscle's sets against its target.
static func state_of(total: float, least: float, most: float) -> String:
	return "short" if total < least - 0.01 else ("plenty" if total > most + 0.01 else "ok")


## One muscle in a row of small bars: its name, a bar, and "now / least", or
## "now → after / least" when a plan will take it further. The bar: solid =
## `now`, faded after it = what the plan adds, a white tick = the least a week,
## all on a scale of the most of them. The colour says where `after` leaves it.
static func cell(part: String, now: float, after: float, least: float, most: float) -> Control:
	var col = state_color(state_of(maxf(now, after), least, most))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(Dose.part_name(part), 12, Pal.TEXT, true))
	# (a muscle that needs no sets of its own, least 0: against the most it should get)
	var scale = maxf(1.0, maxf(after, most if most > 0.0 else least))
	var b = Kit.bar(clampf(now / scale, 0.0, 1.0), col, 8)
	b.extra = maxf(0.0, after - now) / scale
	b.mark = least / scale if least > 0.0 else -1.0
	v.add_child(b)
	var said = "%s / %s" % [Dosage._n(now), Dosage._n(least)] if least > 0.0 else "%s · max %s" % [Dosage._n(now), Dosage._n(most)]
	if after > now + 0.01:
		said = "%s → %s / %s" % [Dosage._n(now), Dosage._n(after), Dosage._n(least)] if least > 0.0 else "%s → %s" % [Dosage._n(now), Dosage._n(after)]
	v.add_child(Kit.clip(said, 12, col, true))
	return v


## The Today section's row: a small bar per muscle of the day. On a lift day
## it is the PLAN's sum: the sets of the last seven days now, and where today's
## plan takes each muscle ("3 → 10 / 10"), against the least it needs in a
## week. Otherwise the last seven days as they stand. `compact`: two muscles
## to a line, for beside the muscle map.
static func row(plan: Dictionary, compact: bool = false) -> Control:
	var w = _window()
	var today = plan.get("doseToday", [])
	var c = Kit.row(DoseView.open, Pal.LINE, null, 8, 4)
	c.tooltip_text = "Your weekly sets per muscle, and what counts"
	c.set_meta("dose_row", true)
	var head = Kit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t = Kit.label("SETS THIS WEEK" if not today.is_empty() else "LAST 7 DAYS · SETS", 11, Pal.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(head)
	if not today.is_empty():
		c.add(Kit.clip("now → after today's plan" if compact else "now → after today's plan, of the least a week", 11, Pal.MUTED))
	var cells = Kit.grid(2, 10) if compact else Kit.hbox(10)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if today.is_empty():
		for p in row_parts(plan, w):
			var r = w.parts[p]
			cells.add_child(cell(str(p), float(r.total), float(r.total), float(r.min), float(r.max)))
	else:
		# The muscles being built first; one that needs no sets of its own (the
		# front delts, the traps: least 0) only when there is room.
		var shown = today.filter(func(d): return str(d.mode) == "build")
		shown.append_array(today.filter(func(d): return str(d.mode) != "build" and float(d.min) > 0.0))
		if shown.size() < 4:
			shown.append_array(today.filter(func(d): return str(d.mode) != "build" and float(d.min) <= 0.0))
		for d in shown.slice(0, 4):
			# What is really logged, and what the plan makes of the week (never less than that).
			var now = float(w.parts[str(d.part)].total)
			cells.add_child(cell(str(d.part), now, maxf(now, float(d.after)), float(d.min), float(d.max)))
	c.add(cells)
	return c


## "Lateral Raise 9, Overhead Press 6": the lifts behind a muscle's sets.
static func _lifts(rows: Array, field: String) -> String:
	var bits = []
	for x in rows:
		if float(x[field]) > 0.0:
			bits.append("%s %s" % [str(x.move), Dosage._n(float(x[field]))])
	return ", ".join(PackedStringArray(bits))


static func _part_row(p: String, r: Dictionary, src: Array = []) -> Control:
	var col = state_color(str(r.state))
	var v = Kit.vbox(1)
	var row = Kit.hbox(8)
	var n = Kit.label(Dose.part_name(p), 14, null, true)
	n.custom_minimum_size = Vector2(92, 0)
	row.add_child(Kit.vcenter(n))
	row.add_child(Kit.bar(clampf(float(r.total) / maxf(1.0, float(r.min) if float(r.min) > 0.0 else float(r.max)), 0.0, 1.0), col, 10))
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
	if Dose.NOTES.has(p):
		var note = Kit.para(str(Dose.NOTES[p]), 11, Pal.with_alpha(Pal.MUTED, 0.85))
		note.set_meta("dose_note", p)
		v.add_child(note)
	# Lift by lift: what was done for it, and what only brushed it.
	var direct = _lifts(src, "direct")
	var half = _lifts(src, "half")
	if direct != "":
		var dl = Kit.para("Direct: %s" % direct, 11, Pal.TEXT)
		dl.set_meta("dose_direct", p)
		v.add_child(dl)
	if half != "":
		var hl = Kit.para("Half sets from: %s" % half, 11, Pal.MUTED)
		hl.set_meta("dose_half", p)
		v.add_child(hl)
	return v


## The sheet: every muscle against its target, rest, the run, how it is counted.
static func open() -> void:
	Sfx.tick()
	var st = App.settings()
	var plan = Dose.plan_of(st)
	if plan == null:
		return
	var w = _window()
	var src = Dose.sources(App.sessions(), App.pt(), App.today)
	var sh = Kit.sheet("Weekly sets")
	sh.box.add_child(Kit.label(str(plan.name), 16, Pal.LIFT, true))
	sh.box.add_child(Kit.para(str(plan.blurb) + " Sets of the last 7 days against what each muscle needs in a week, and the lifts they came from.", 12, Pal.MUTED))
	for mode in ["build", "keep"]:
		var parts = Dose.PARTS.filter(func(p): return str(w.parts[p].mode) == mode)
		if parts.is_empty():
			continue
		sh.box.add_child(Kit.section_title("Build" if mode == "build" else "Keep as it is"))
		if mode == "keep":
			sh.box.add_child(Kit.para("No sets are added for these. Their lifts still have goals to beat.", 11, Pal.MUTED))
		for p in parts:
			sh.box.add_child(_part_row(str(p), w.parts[p], src.get(p, [])))
	# Rest and the run.
	sh.box.add_child(Kit.section_title("Rest and running"))
	var rest = Dose.rest(App.sessions(), App.pt(), App.today)
	var rest_text = "%d lifting day%s in a row. Every day is planned as a lift day: when you need a rest day, tap Rest on the Today card (or on a day in Coming up). No lifting that day, your run, a climb and PT stay, and the split carries on a day later." % [int(rest.run), "" if int(rest.run) == 1 else "s"]
	var today_plan = App.plan()
	if bool(today_plan.get("off", false)):
		rest_text = "Today is a rest day from lifting (your call). %s." % Missions.off_moves(today_plan)
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
	sh.box.add_child(Kit.para("A set of a lift counts 1 for its main muscle and a half for the muscles it also works (a quarter for the front delts from a fly). The shoulders are counted as three: front, side and rear delts, and shrugs count for the traps, not the back. A climbing session counts %s sets for the forearms and nothing for the back: climbing is fingers far more than pulling. Physical therapy and stretches count for nothing here. Change the focus in Settings, under Training focus." % Dosage._n(float(Dose.CLIMB_SETS.forearms)), 11, Pal.MUTED))
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
