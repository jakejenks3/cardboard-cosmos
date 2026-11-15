class_name JourneyLifts
extends RefCounted
## Journey → Lifts: the lift library (game/lift_library.gd). Search box, body
## part and equipment chips, a sort row, then one compact row per lift with
## your best on the right (or NEW). Tapping a row opens a sheet with the notes,
## your bests, rep records, trend, history and the variations to try.
## State lives in the screen: `st` = {q, part, equip, show, sort}.


## One colour per body part, all mixed from the palette so they follow the theme:
## push muscles warm, pull muscles cool, legs red to pink, core and the rest pale.
static func part_color(id: String) -> Color:
	match id:
		"chest":
			return Pal.LIFT
		"shoulders":
			return Pal.ACCENT2
		"triceps":
			return Pal.ACCENT
		"back":
			return Pal.SECOND
		"biceps":
			return Pal.CLIMB
		"forearms":
			return Pal.GOOD
		"quads":
			return Pal.DANGER
		"hamstrings":
			return Pal.DANGER.lerp(Pal.SECOND, 0.5)
		"glutes":
			return Pal.DANGER.lerp(Pal.TEXT, 0.45)
		"calves":
			return Pal.CLIMB.lerp(Pal.SECOND, 0.5)
		"core":
			return Pal.MUTED
		"full":
			return Pal.TEXT
	return Pal.LINE.lightened(0.25)


static func _ig(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fill `parent` (the screen's VBox). `rebuild` re-renders the screen after a filter change.
static func build(parent: Control, st: Dictionary, rebuild: Callable) -> void:
	var rows = LiftLibrary.rows(App.sessions())
	var n_done = rows.filter(func(e): return e.st != null).size()

	var search = Kit.input(st.q, "Search lifts, muscles, equipment")
	search.clear_button_enabled = true
	search.select_all_on_focus = false
	search.tooltip_text = "Try \"cable\", \"curl\", \"glutes\" or part of a name"
	parent.add_child(search)

	parent.add_child(Kit.segmented([
		{"value": "all", "label": "All %d" % rows.size()},
		{"value": "mine", "label": "Done %d" % n_done},
		{"value": "new", "label": "New to me"},
	], st.show, JourneyLifts._set_st.bind(st, "show", rebuild), Pal.LIFT))

	var parts = Kit.flow(5)
	for p in LiftLibrary.PARTS:
		if p.id == "other" and not rows.any(func(e): return e.part == "other"):
			continue
		parts.add_child(LogWidgets.mini_chip(p.name, st.part == p.id, JourneyLifts._pick.bind(st, "part", p.id, rebuild), part_color(p.id)))
	parent.add_child(parts)

	var equips = Kit.flow(5)
	for q in LiftLibrary.EQUIPMENT:
		equips.add_child(LogWidgets.mini_chip(q.name, st.equip == q.id, JourneyLifts._pick.bind(st, "equip", q.id, rebuild), Pal.TEXT))
	parent.add_child(equips)

	var sorts = Kit.hbox(5)
	sorts.add_child(Kit.vcenter(Kit.muted("Sort", 12)))
	for o in LiftLibrary.SORTS:
		sorts.add_child(LogWidgets.mini_chip(o.label, st.sort == o.value, JourneyLifts._set_st.bind(o.value, st, "sort", rebuild), Pal.ACCENT, 7))
	parent.add_child(sorts)

	var list = Kit.vbox(6)
	parent.add_child(list)
	search.text_changed.connect(JourneyLifts._on_search.bind(st, list, rows))
	_fill(list, rows, st)


static func _set_st(v, st: Dictionary, key: String, rebuild: Callable) -> void:
	Sfx.tick()
	st[key] = v
	rebuild.call()


## Chips toggle: tapping the active one clears the filter.
static func _pick(st: Dictionary, key: String, id: String, rebuild: Callable) -> void:
	Sfx.tick()
	st[key] = "" if st[key] == id else id
	rebuild.call()


## Typing only refills the list, so the search box keeps the keyboard.
static func _on_search(text: String, st: Dictionary, list: Control, rows: Array) -> void:
	st.q = text
	if is_instance_valid(list):
		_fill(list, rows, st)


static func _fill(list: Control, rows: Array, st: Dictionary) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var found = LiftLibrary.query(rows, st)
	if found.is_empty():
		list.add_child(Kit.empty("info", "No lifts match", "Try fewer filters or a shorter search."))
		return
	list.add_child(JourneyScreen.caption("%d lift%s" % [found.size(), "" if found.size() == 1 else "s"], 11))
	var grouped = str(st.sort) == "part"
	var part = ""
	for e in found:
		if grouped and e.part != part:
			part = e.part
			var n = found.filter(func(x): return x.part == part).size()
			var head = Kit.hbox(8)
			head.add_child(Kit.tag(LiftLibrary.part_name(part), part_color(part), true, 13))
			head.add_child(Kit.vcenter(Kit.muted(str(n), 12)))
			list.add_child(Kit.pad(head, 0, 6, 0, 0))
		list.add_child(_row(e, rows))


## One lift: a bar in its body-part colour, name and equipment, your best on the right.
static func _row(e: Dictionary, rows: Array) -> Card:
	var wu = App.weight_unit()
	var c = Kit.card(0, JourneyLifts.open_detail.bind(e, rows), 8)
	var h = _ig(Kit.hbox(10))
	var bar = Panel.new()
	bar.add_theme_stylebox_override("panel", Kit.sbox(part_color(e.part), 3, null, 0, 0, 0))
	bar.custom_minimum_size = Vector2(6, 34)
	h.add_child(_ig(bar))
	var v = _ig(Kit.vbox(0))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.clip(e.name, 14, null, true))
	var sub = LiftLibrary.equip_name(e.equip) if not e.own else "Your own"
	if str(e.also) != "":
		sub += " · " + str(e.also)
	v.add_child(Kit.clip(sub, 11, Pal.MUTED))
	h.add_child(v)
	var st = e.st
	if st == null:
		h.add_child(Kit.vcenter(Kit.tag("NEW", Pal.SECOND, false, 10)))
	else:
		var r = _ig(Kit.vbox(0))
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var best = Kit.label(best_text(st, wu), 13, Pal.ACCENT, true)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(best)
		var when = Kit.label("%d× · %s" % [int(st.count), Dates.relative_day(st.last, App.today)], 11, Pal.MUTED)
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(when)
		h.add_child(r)
	c.add(h)
	return c


## "100 kg × 5", or "15 reps" for a lift only done with bodyweight.
static func best_text(st: Dictionary, wu: String) -> String:
	if float(st.bestKg) > 0.0:
		return "%s × %d" % [Fmt.fmt_weight(float(st.bestKg), wu), int(st.bestReps)]
	return "%d reps" % int(st.bwReps)


## The detail sheet of one lift.
static func open_detail(e: Dictionary, rows: Array) -> void:
	Sfx.tap()
	var wu = App.weight_unit()
	var sheet = Kit.sheet(e.name)
	var box = sheet.box
	var tags = Kit.flow(6)
	tags.add_child(Kit.tag(LiftLibrary.part_name(e.part), part_color(e.part), true, 12))
	if not e.own:
		tags.add_child(Kit.tag(LiftLibrary.equip_name(e.equip), Pal.PANEL2, false, 12))
		tags.add_child(Kit.tag(str(e.family), Pal.PANEL2, false, 12))
	box.add_child(tags)
	box.add_child(Kit.para(e.tip, 14))
	if str(e.also) != "":
		box.add_child(Kit.muted_para("Also works: " + str(e.also), 12))

	var st = e.st
	if st == null:
		var nc = Kit.card(4, Callable(), 10)
		nc.accent(Pal.SECOND)
		var nr = Kit.hbox(8)
		nr.add_child(Kit.vcenter(Icons.rect("bolt", 22)))
		nr.add_child(Kit.para("New to you. Add it to a workout and it starts a history here.", 13, null, true))
		nc.add(nr)
		box.add_child(nc)
	else:
		var vals
		var caps
		if float(st.bestKg) > 0.0:
			var bw = JourneyScreen.split_unit(Fmt.fmt_weight(float(st.bestKg), wu))
			var e1 = JourneyScreen.split_unit(Fmt.fmt_weight(float(st.e1rm), wu, 0))
			vals = [bw[0], e1[0], str(int(st.count))]
			caps = ["%s × %d best" % [bw[1], int(st.bestReps)], "%s est. 1RM" % e1[1], "Sessions"]
		else:
			vals = [str(int(st.bwReps)), Xp.fmt_int(st.reps), str(int(st.count))]
			caps = ["Best set", "Reps in all", "Sessions"]
		var sc = JourneyScreen.fit_scale(vals, 96, 3)
		var g = Kit.grid(3, 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cols = [Pal.ACCENT, Pal.LIFT, Pal.TEXT]
		for i in range(3):
			var t = JourneyScreen.well_tile(vals[i], caps[i], cols[i], sc)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(t)
		box.add_child(g)

		var marks = LiftLibrary.rep_bests(st)
		if not marks.is_empty():
			var mf = Kit.flow(6)
			for m in marks:
				mf.add_child(JourneyScreen.value_chip("1 rep" if int(m.reps) == 1 else "%d+ reps" % int(m.reps), Fmt.fmt_weight(float(m.kg), wu), Pal.LIFT, "Heaviest set of at least %d rep%s" % [int(m.reps), "" if int(m.reps) == 1 else "s"]))
			box.add_child(mf)

		var facts = "Last done %s" % Dates.relative_day(st.last, App.today)
		if float(st.volumeKg) > 0.0:
			facts += " · %s lifted in all" % Fmt.fmt_big_kg(float(st.volumeKg), wu)
		box.add_child(Kit.muted(facts, 12))

		var series = []
		for i in range(st.history.size() - 1, -1, -1):
			var hbest = 0.0
			for one in st.history[i].sets:
				if float(one.weightKg) > 0.0:
					hbest = maxf(hbest, Xp.e1rm(one.weightKg, one.reps))
			if hbest > 0.0:
				series.append({"x": st.history[i].date, "y": Fmt.kg_to_unit(hbest, wu)})
		if series.size() >= 2:
			var ln = Charts.line(series, Pal.LIFT, func(val): return "%d %s" % [TTUtil.jsround(val), wu])
			ln.tooltip_text = "Estimated one-rep max, session by session"
			box.add_child(ln)

		box.add_child(Kit.section_title("History"))
		var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
		var shown = mini(8, st.history.size())
		for i in range(shown):
			var hs = st.history[i]
			var hc = Kit.card(0, JourneyLifts._edit.bind(sheet, hs.id), 8)
			hc.tooltip_text = "Open this session"
			var hr = _ig(Kit.hbox(8))
			var d = Kit.label(Dates.format_date(hs.date, {"month": "short", "day": "numeric", "year": "numeric"}), 12, Pal.MUTED, true)
			d.custom_minimum_size.x = 96
			hr.add_child(Kit.vcenter(d))
			var what = Kit.clip(LiftHistory.describe_sets(hs.sets, fmt_w), 13, null, true)
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hr.add_child(Kit.vcenter(what))
			hc.add(hr)
			box.add_child(hc)
		if st.history.size() > shown:
			box.add_child(Kit.muted("and %d earlier session%s" % [st.history.size() - shown, "" if st.history.size() - shown == 1 else "s"], 11))

	var vars = LiftLibrary.variations(e, rows)
	if not vars.is_empty():
		box.add_child(Kit.section_title("Variations to try"))
		var vf = Kit.flow(5)
		for o in vars:
			var chip = LogWidgets.mini_chip(o.name, o.st != null, JourneyLifts._jump.bind(sheet, o, rows), part_color(o.part))
			chip.tooltip_text = ("You have done this: " + best_text(o.st, wu)) if o.st != null else "New to you"
			vf.add_child(chip)
		box.add_child(vf)

	var add = Kit.button("Add to today's workout", "primary", JourneyLifts._add.bind(sheet, str(st.name) if st != null else str(e.name)), "lg", "plus")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(add)
	sheet.open()


static func _edit(sheet: Sheet, session_id) -> void:
	Sfx.tap()
	sheet.close()
	App.open_log("lift", session_id)


static func _jump(sheet: Sheet, o: Dictionary, rows: Array) -> void:
	sheet.close()
	open_detail(o, rows)


## Open the lifting form with this exercise on it (see LogLiftEditor.build).
static func _add(sheet: Sheet, lift_name: String) -> void:
	Sfx.tap()
	sheet.close()
	App.pending_exercise = lift_name
	App.open_log("lift")
	App.toast("%s added to your workout" % lift_name, "good", "check")
