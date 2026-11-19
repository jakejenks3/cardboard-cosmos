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
	var name_row = _ig(Kit.hbox(6))
	name_row.add_child(Kit.clip(e.name, 14, null, true))
	if is_pt(e):
		name_row.add_child(Kit.vcenter(SessionView.pt_tag()))
	v.add_child(name_row)
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


## Is this lift one of the player's physical therapy exercises (under any of its names)?
static func is_pt(e: Dictionary) -> bool:
	var marks = App.pt()
	if marks.is_empty():
		return false
	for k in e.keys:
		if marks.has(str(k)):
			return true
	return false


## The page of a lift, by its name: from a list of exercises (a session's
## detail, the phone note's review) rather than from the library. `opts` as
## for `open_detail`.
static func open_named(lift_name: String, opts: Dictionary = {}) -> void:
	var rows = LiftLibrary.rows(App.sessions())
	var k = Xp.normalize_exercise(lift_name)
	var found = null
	for r in rows:
		if r.keys.has(k):
			found = r
			break
	if found == null:
		# Not in the library and not in the log yet (a new lift in the phone note).
		found = {"name": lift_name, "part": LiftLibrary.guess_part(k), "equip": "other", "family": "Your own", "also": "",
			"tip": "One of your own lifts: not in the library, so it has no notes.", "keys": [k], "own": true, "st": null}
	open_detail(found, rows, opts)


## The trend looked at last, kept from one lift to the next.
static var _metric = ""


## The numbers of a lift that can be charted, as the picker's options.
static func trend_options(history: Array) -> Array:
	var out = []
	var loaded = LiftTrend.weighted(history)
	if loaded:
		out.append({"value": "weight", "label": "Weight"})
	out.append({"value": "reps", "label": "Reps"})
	if loaded:
		out.append({"value": "volume", "label": "Volume"})
	out.append({"value": "often", "label": "How often"})
	return out


## A number of a trend with its unit: "52.5 lb", "3.4k lb", "68".
static func trend_text(metric: String, v: float, wu: String) -> String:
	match metric:
		"weight":
			return "%s %s" % [TTUtil.num_str(snappedf(v, 0.1)), wu]
		"volume":
			return "%s %s" % [Charts.fmt_k(v), wu]
	return str(TTUtil.jsround(v))


## "Trends": a picker (weight, reps, volume, how often) and the chart it picks.
## Only the chart is rebuilt when another one is picked.
static func _trend_block(box: Control, st: Dictionary, wu: String, goal: int) -> void:
	box.add_child(Kit.section_title("Trends"))
	var options = trend_options(st.history)
	var current = str(options[0].value)
	for o in options:
		if str(o.value) == _metric:
			current = _metric
	var holder = Kit.vbox(6)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(Kit.segmented(options, current, JourneyLifts._show_trend.bind(holder, st, wu, goal), Pal.LIFT))
	box.add_child(holder)
	_show_trend(current, holder, st, wu, goal)


static func _show_trend(metric, holder: Control, st: Dictionary, wu: String, goal: int) -> void:
	if not is_instance_valid(holder):
		return
	_metric = str(metric)
	for old in holder.get_children():
		holder.remove_child(old)
		old.queue_free()
	if _metric == "often":
		var weeks = LiftTrend.per_week(st.history, App.today, 8)
		var chips = Kit.flow(6)
		chips.add_child(JourneyScreen.value_chip("A week", Fmt.to_fixed(LiftTrend.weekly_rate(weeks), 1), Pal.LIFT, "Days a week on average, counted from the first of these weeks it was done in"))
		chips.add_child(JourneyScreen.value_chip("Last", Dates.relative_day(st.last, App.today), Pal.LIFT, "The last day it was done"))
		chips.add_child(JourneyScreen.value_chip("Days in all", str(LiftTrend.days_done(st.history).size()), Pal.LIFT, "Days it was done on, ever"))
		holder.add_child(chips)
		var bars = WeekBars.new()
		bars.setup(weeks, Pal.PT if goal > 0 else Pal.LIFT, goal)
		holder.add_child(bars)
		holder.add_child(Kit.muted("Days done in each of the last 8 weeks" + (" (the line is your %d a week)" % goal if goal > 0 else ""), 11))
		return
	var points = []
	for p in LiftTrend.series(st.history, _metric):
		points.append({"x": p.x, "y": float(p.y) if _metric == "reps" else Fmt.kg_to_unit(float(p.y), wu)})
	var what = {"weight": "The heaviest set of each day", "reps": "Every rep of each day", "volume": "Weight x reps of each day"}[_metric]
	if points.size() < 2:
		var only = Kit.hbox(8)
		if points.size() == 1:
			only.add_child(JourneyScreen.value_chip(Dates.format_date(points[0].x), trend_text(_metric, float(points[0].y), wu), Pal.LIFT, what))
		only.add_child(Kit.para("One day so far. The next one starts the line.", 12, Pal.MUTED))
		holder.add_child(only)
		return
	var ch = LiftTrend.change(points)
	var delta = float(ch.delta)
	var since = "since %s" % Dates.format_date(points[0].x)
	var head = Kit.hbox(8)
	if absf(delta) < 0.05:
		head.add_child(Kit.vcenter(Kit.tag("Level", Pal.PANEL2, false, 12)))
	else:
		head.add_child(Kit.vcenter(Kit.tag("%s%s" % ["+" if delta > 0.0 else "-", trend_text(_metric, absf(delta), wu)], Pal.GOOD if delta > 0.0 else Pal.ACCENT2, true, 12)))
	head.add_child(Kit.vcenter(Kit.clip("%s · %d sessions" % [since, int(ch.n)], 12, Pal.MUTED)))
	holder.add_child(head)
	var metric_now = _metric
	var ln = Charts.line(points, Pal.LIFT, func(val): return JourneyLifts.trend_text(metric_now, float(val), wu))
	ln.tooltip_text = what
	holder.add_child(ln)
	holder.add_child(Kit.muted(what, 11))


## The physical therapy card of a lift: a switch, and when it is on, this
## week's days and how many days a week to aim for. Rebuilt in place.
static func _pt_block(holder: Control, lift: String) -> void:
	if not is_instance_valid(holder):
		return
	for old in holder.get_children():
		holder.remove_child(old)
		old.queue_free()
	var marks = App.pt()
	var on = Pt.is_pt(marks, lift)
	var c = Kit.card(6, Callable(), 10)
	if on:
		c.accent(Pal.PT)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("pt", 16)))
	var label = Kit.clip("Physical therapy", 14, null, true)
	row.add_child(Kit.vcenter(label))
	row.add_child(Kit.switch(on, JourneyLifts._set_pt.bind(holder, lift), "Keep track of how often you do it"))
	c.add(row)
	if on:
		var mine = null
		for r in Pt.status(App.sessions(), marks, App.today):
			if str(r.key) == Pt.mark_of(marks, lift):
				mine = r
		if mine != null:
			var week = Kit.hbox(8)
			var dots = WeekBars.Dots.new()
			dots.setup(mine.week, Dates.weekday_index(App.today), Pal.PT, 12)
			week.add_child(dots)
			week.add_child(Kit.vcenter(Kit.clip("%d of %d this week" % [int(mine.thisWeek), int(mine.perWeek)], 13, null, true)))
			week.add_child(Kit.vcenter(PtView.state_tag(mine)))
			c.add(week)
			var goal = Kit.hbox(6)
			goal.add_child(Kit.vcenter(Kit.clip("Aim for", 13, Pal.MUTED)))
			goal.add_child(Kit.vcenter(Kit.icon_button("minus", JourneyLifts._set_goal.bind(holder, lift, int(mine.perWeek) - 1), "One day fewer", 28)))
			goal.add_child(Kit.vcenter(PixelFont.rect(str(int(mine.perWeek)), 2, Pal.PT)))
			goal.add_child(Kit.vcenter(Kit.icon_button("plus", JourneyLifts._set_goal.bind(holder, lift, int(mine.perWeek) + 1), "One day more", 28)))
			goal.add_child(Kit.vcenter(Kit.label("day%s a week" % ("" if int(mine.perWeek) == 1 else "s"), 13, Pal.MUTED)))
			c.add(goal)
	holder.add_child(c)


static func _set_pt(on, holder: Control, lift: String) -> void:
	Sfx.tick()
	App.set_pt(lift, bool(on))
	_pt_block(holder, lift)


static func _set_goal(holder: Control, lift: String, per_week: int) -> void:
	if per_week < 1 or per_week > Pt.MAX_PER_WEEK:
		Sfx.error()
		return
	Sfx.tick()
	App.set_pt_goal(lift, per_week)
	_pt_block(holder, lift)


## The detail sheet of one lift. opts:
##   "pending": {"date", "sets"}  sets from the phone note that are not in the
##                                log yet: shown on top, compared with the last time
##   "skip_id": a session to leave out of the history (the one such a note replaces)
static func open_detail(e: Dictionary, rows: Array, opts: Dictionary = {}) -> void:
	Sfx.tap()
	var wu = App.weight_unit()
	var sheet = Kit.sheet(e.name)
	var box = sheet.box
	var st = e.st
	if st != null and opts.get("skip_id") != null:
		# The session being replaced is not part of what it is compared with.
		var kept = st.history.filter(func(hh): return hh.id != opts.skip_id)
		if kept.size() != st.history.size():
			st = st.duplicate()
			st["history"] = kept
			if kept.is_empty():
				st = null
	var lift = str(st.name) if st != null else str(e.name)
	var fmt_sets = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var tags = Kit.flow(6)
	tags.add_child(Kit.tag(LiftLibrary.part_name(e.part), part_color(e.part), true, 12))
	if not e.own:
		tags.add_child(Kit.tag(LiftLibrary.equip_name(e.equip), Pal.PANEL2, false, 12))
		tags.add_child(Kit.tag(str(e.family), Pal.PANEL2, false, 12))
	box.add_child(tags)

	var pending = opts.get("pending")
	if pending is Dictionary:
		var before = []
		if st != null:
			before = st.history.filter(func(hh): return str(hh.date) <= str(pending.date))
		var pc = Kit.card(4, Callable(), 10)
		pc.accent(Pal.GOOD)
		var ptop = Kit.hbox(6)
		ptop.add_child(Kit.vcenter(Icons.rect("speech", 16)))
		ptop.add_child(Kit.vcenter(Kit.clip("In your note · %s" % Dates.format_date(str(pending.date), {"weekday": "short", "month": "short", "day": "numeric"}), 12, Pal.MUTED, true)))
		pc.add(ptop)
		var pline = Kit.hbox(8)
		pline.add_child(Kit.vcenter(Kit.clip(LiftHistory.describe_sets(pending.sets, fmt_sets), 15, null, true)))
		var ptag = SessionView.compare_tag(LiftTrend.compare(pending.sets, before), wu)
		if ptag != null:
			pline.add_child(Kit.vcenter(ptag))
		pc.add(pline)
		if not before.is_empty():
			pc.add(Kit.clip("Last time (%s): %s" % [Dates.relative_day(before[0].date, App.today), LiftHistory.describe_sets(before[0].sets, fmt_sets)], 12, Pal.MUTED))
		box.add_child(pc)

	box.add_child(Kit.para(e.tip, 14))
	if str(e.also) != "":
		box.add_child(Kit.muted_para("Also works: " + str(e.also), 12))
	var pt_holder = Kit.vbox(0)
	pt_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(pt_holder)
	_pt_block(pt_holder, lift)

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

		_trend_block(box, st, wu, Pt.per_week(App.pt(), lift) if Pt.is_pt(App.pt(), lift) else 0)

		box.add_child(Kit.section_title("History"))
		var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
		var shown = mini(8, st.history.size())
		for i in range(shown):
			var hs = st.history[i]
			var hc = Kit.card(0, JourneyLifts._open_session.bind(sheet, hs.id), 8)
			hc.tooltip_text = "Everything you did that day"
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


## From a day in the lift's history to everything done in that session.
static func _open_session(sheet: Sheet, session_id) -> void:
	var s = App.session_by_id(session_id)
	if s == null:
		return
	sheet.close()
	SessionView.open(s)


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
