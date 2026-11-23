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


## The Today card's row: a small bar per muscle of the day, sets of the last
## seven days against the least it needs.
static func row(plan: Dictionary) -> Control:
	var w = _window()
	var c = Kit.card(4, DoseView.open, 8)
	c.tooltip_text = "Your weekly sets per muscle, and what counts"
	c.set_meta("dose_row", true)
	var head = Kit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t = Kit.label("LAST 7 DAYS · SETS", 10, Pal.LIFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(head)
	var cells = Kit.hbox(10)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in row_parts(plan, w):
		var r = w.parts[p]
		var col = state_color(str(r.state))
		var v = Kit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Kit.clip(Dose.part_name(str(p)), 11, Pal.TEXT, true))
		v.add_child(Kit.bar(clampf(float(r.total) / maxf(1.0, float(r.min)), 0.0, 1.0), col, 6))
		v.add_child(Kit.clip("%s / %s" % [Dosage._n(float(r.total)), Dosage._n(float(r.min))], 11, col, true))
		cells.add_child(v)
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
	var rest_text = "%d hard day%s in a row. A rest day is due after %d." % [int(rest.run), "" if int(rest.run) == 1 else "s", Dose.REST_AFTER]
	if bool(rest.due):
		rest_text = "%d hard days in a row: today is a rest day." % int(rest.run)
	sh.box.add_child(_line("moon", rest_text))
	if Dose.run_on(st):
		var g = Dose.run_goal(App.sessions(), Dates.add_days(App.today, 1), App.distance_unit())
		if g == null:
			sh.box.add_child(_line("run", "Log a run and the next one gets a distance to aim for."))
		else:
			sh.box.add_child(_line("run", "Next run: %s. %s." % [Fmt.fmt_distance(float(g.targetM), App.distance_unit()), Dose.run_why(g, App.distance_unit())]))
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
