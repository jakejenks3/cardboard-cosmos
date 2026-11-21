class_name JourneyLifts
extends RefCounted
## Journey → Lifts: the lift library (game/lift_library.gd). Search box, body
## part and equipment chips, a sort row, then one compact row per MOVEMENT with
## the variations you have done under its name and your best on the right (or
## NEW). Tapping a row opens the movement's page on one variation: chips at the
## top switch between its variations, and under them that variation's newest
## session, trend, history and records.
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
	name_row.add_child(Kit.clip_fit(e.name, 14, null, true, 230.0))
	if is_pt(e):
		name_row.add_child(Kit.vcenter(SessionView.pt_tag()))
	v.add_child(name_row)
	# Under the name: the variations you have done, or what it is done with.
	var sub = ""
	var done = e.get("done", [])
	if not done.is_empty():
		var said = []
		for d in done:
			said.append(str(d.variation) if str(d.variation) != "" else "plain")
		sub = " · ".join(PackedStringArray(said))
	elif e.own:
		sub = "Your own"
	else:
		sub = "%d variation%s" % [e.vars.size(), "" if e.vars.size() == 1 else "s"] if e.vars.size() > 0 else LiftLibrary.equip_name(e.equip)
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
	if LiftTrend.held(st.history):
		return "%d s hold" % longest_hold(st.history)
	return "%d reps" % int(st.bwReps)


## The longest hold in a lift's history, in seconds (0 when it has none).
static func longest_hold(history: Array) -> int:
	var out = 0
	for h in history:
		out = maxi(out, int(LiftTrend.day(h.get("sets", [])).holdSec))
	return out


## Is this lift one of the player's physical therapy exercises (under any of its names)?
static func is_pt(e: Dictionary) -> bool:
	var marks = App.pt()
	if marks.is_empty():
		return false
	for d in e.get("done", []):
		if Pt.is_pt(marks, str(d.name)):
			return true
	return false


## The page of a lift, by its name: from a list of exercises (a session's
## detail, the phone note's review) rather than from the library. `opts` as
## for `open_detail`.
static func open_named(lift_name: String, opts: Dictionary = {}) -> void:
	var rows = LiftLibrary.rows(App.sessions())
	var sp = LiftNames.split(lift_name)
	var k = Xp.normalize_exercise(str(sp.move))
	var found = null
	for r in rows:
		if r.keys.has(k):
			found = r
			break
	if found == null:
		# Not in the library and not in the log yet (a new lift in the phone note).
		found = {"name": str(sp.move), "part": LiftLibrary.guess_part(k), "usual": "", "only": [], "equip": "other", "equips": ["other"],
			"family": str(sp.move), "also": "", "tip": "One of your own: not in the library, so it has no notes.",
			"vars": [], "names": [], "keys": [k], "own": true, "done": [], "st": null}
	var o = opts.duplicate()
	o["variation"] = str(sp.variation)
	open_detail(found, rows, o)


## The numbers of a lift that can be charted, as the picker's options.
static func trend_options(history: Array) -> Array:
	var out = []
	var loaded = LiftTrend.weighted(history)
	if loaded:
		out.append({"value": "weight", "label": "Weight"})
	if LiftTrend.held(history):
		out.append({"value": "hold", "label": "Hold"})
	out.append({"value": "reps", "label": "Reps"})
	if loaded:
		out.append({"value": "volume", "label": "Volume"})
	out.append({"value": "often", "label": "How often"})
	return out


## The number a lift is about: the seconds when it is held, the weight when it
## carries one, else the reps. The page opens on its chart.
static func main_metric(history: Array) -> String:
	if LiftTrend.held(history):
		return "hold"
	return "weight" if LiftTrend.weighted(history) else "reps"


## A number of a trend with its unit: "52.5 lb", "3.4k lb", "30 s", "68".
static func trend_text(metric: String, v: float, wu: String) -> String:
	match metric:
		"weight":
			return "%s %s" % [TTUtil.num_str(snappedf(v, 0.1)), wu]
		"volume":
			return "%s %s" % [Charts.fmt_k(v), wu]
		"hold":
			return "%d s" % TTUtil.jsround(v)
	return str(TTUtil.jsround(v))


## The trend: one chart in a card, with a picker for what it shows. It opens on
## the number the lift is about. `history` is every session of the lift, the
## note's sets among them when the page was opened from the phone note. Only
## the chart is rebuilt when another number is picked.
static func _trend_card(box: Control, history: Array, wu: String, goal: int) -> void:
	var current = main_metric(history)
	var holder = Kit.vbox(6)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c = Kit.card(8, Callable(), 10)
	c.add(Kit.segmented(trend_options(history), current, JourneyLifts._show_trend.bind(holder, history, wu, goal), Pal.LIFT))
	c.add(holder)
	box.add_child(c)
	_show_trend(current, holder, history, wu, goal)


static func _show_trend(metric, holder: Control, history: Array, wu: String, goal: int) -> void:
	if not is_instance_valid(holder):
		return
	var which = str(metric)
	for old in holder.get_children():
		holder.remove_child(old)
		old.queue_free()
	if which == "often":
		var weeks = LiftTrend.per_week(history, App.today, 8)
		var bars = WeekBars.new()
		bars.setup(weeks, Pal.PT if goal > 0 else Pal.LIFT, goal)
		holder.add_child(bars)
		var last_day = ""
		for d in LiftTrend.days_done(history):
			if str(d) > last_day:
				last_day = str(d)
		var said = Kit.hbox(8)
		said.add_child(Kit.vcenter(Kit.tag("%s a week" % Fmt.to_fixed(LiftTrend.weekly_rate(weeks), 1), Pal.LIFT, true, 12)))
		var last_text = Dates.relative_day(last_day, App.today)
		if Dates.days_between(last_day, App.today) <= 1:
			last_text = last_text.to_lower()
		var rest = "%d days in all · last %s" % [LiftTrend.days_done(history).size(), last_text]
		if goal > 0:
			rest += " · the line is your %d a week" % goal
		said.add_child(Kit.vcenter(Kit.clip(rest, 12, Pal.MUTED)))
		holder.add_child(said)
		return
	var points = []
	for p in LiftTrend.series(history, which):
		points.append({"x": p.x, "y": float(p.y) if (which == "reps" or which == "hold") else Fmt.kg_to_unit(float(p.y), wu)})
	var what = {"weight": "The heaviest set of each day", "reps": "Every rep of each day", "volume": "Weight x reps of each day", "hold": "The longest hold of each day"}[which]
	if points.is_empty():
		holder.add_child(Kit.para("Nothing to chart here yet.", 12, Pal.MUTED))
		return
	var ln = Charts.line(points, Pal.LIFT, func(val): return JourneyLifts.trend_text(which, float(val), wu))
	ln.tooltip_text = what
	holder.add_child(ln)
	var said = Kit.hbox(8)
	if points.size() < 2:
		said.add_child(Kit.vcenter(Kit.tag("First day", Pal.SECOND, false, 12)))
		said.add_child(Kit.vcenter(Kit.clip("The line starts with the next one", 12, Pal.MUTED)))
	else:
		var ch = LiftTrend.change(points)
		var delta = float(ch.delta)
		if absf(delta) < 0.05:
			said.add_child(Kit.vcenter(Kit.tag("Level", Pal.PANEL2, false, 12)))
		else:
			said.add_child(Kit.vcenter(Kit.tag("%s%s" % ["+" if delta > 0.0 else "-", trend_text(which, absf(delta), wu)], Pal.GOOD if delta > 0.0 else Pal.ACCENT2, true, 12)))
		said.add_child(Kit.vcenter(Kit.clip("since %s · %d sessions" % [Dates.format_date(points[0].x), int(ch.n)], 12, Pal.MUTED)))
	holder.add_child(said)


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


## The top of a lift's page: its newest session, big. From the phone note that
## is the note's sets, else the last time it was done. The number the lift is
## about on the left; the sets and how they compare with the time before on
## the right. `cur` is a history row, `before` the rows older than it.
static func _now_card(cur: Dictionary, before: Array, wu: String) -> Card:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var from_note = bool(cur.get("note", false))
	var day = LiftTrend.day(cur.sets)
	var c = Kit.card(8, Callable(), 12)
	c.accent(Pal.GOOD if from_note else Pal.LIFT)
	var kicker = Kit.hbox(6)
	kicker.add_child(Kit.vcenter(Icons.rect("speech" if from_note else "calendar", 16)))
	var when = Dates.format_date(str(cur.date), {"weekday": "short", "month": "short", "day": "numeric"})
	kicker.add_child(Kit.vcenter(Kit.clip(("In your note · %s" if from_note else "Last time · %s") % when, 12, Pal.MUTED, true)))
	c.add(kicker)
	var num = str(int(day.bestReps))
	var unit = "reps, best set"
	if int(day.holdSec) > 0:
		num = str(int(day.holdSec))
		unit = "seconds held"
	elif float(day.topKg) > 0.0:
		var parts = JourneyScreen.split_unit(Fmt.fmt_weight(float(day.topKg), wu))
		num = str(parts[0])
		unit = "%s, top set" % str(parts[1])
	var row = Kit.hbox(14)
	var big = Kit.vbox(2)
	big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var digits = PixelFont.rect(num, 4 if num.length() <= 5 else 3, Pal.ACCENT)
	digits.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	big.add_child(digits)
	big.add_child(Kit.label(unit, 11, Pal.MUTED, true))
	row.add_child(big)
	var words = Kit.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(Kit.para(LiftHistory.describe_sets(cur.sets, fmt_w), 15, null, true))
	var tag = SessionView.compare_tag(LiftTrend.compare(cur.sets, before), wu, 12)
	if tag != null:
		words.add_child(tag)
	row.add_child(words)
	c.add(row)
	if not before.is_empty():
		var prev_day = Dates.relative_day(before[0].date, App.today)
		if Dates.days_between(str(before[0].date), App.today) <= 1:
			prev_day = prev_day.to_lower()
		c.add(Kit.clip("Before that (%s): %s" % [prev_day, LiftHistory.describe_sets(before[0].sets, fmt_w)], 12, Pal.MUTED))
	return c


## The history as a list, newest first: the day, what was done, and how it
## compares with the day before it. A day opens its session.
static func _history_list(box: Control, sheet: Sheet, history: Array, wu: String) -> void:
	box.add_child(Kit.section_title("History"))
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var this_year = App.today.substr(0, 4)
	var shown = mini(8, history.size())
	for i in range(shown):
		var hs = history[i]
		var from_note = bool(hs.get("note", false))
		var hc = Kit.card(0, Callable() if from_note else JourneyLifts._open_session.bind(sheet, hs.id), 7)
		if from_note:
			hc.accent(Pal.GOOD)
		else:
			hc.tooltip_text = "Everything you did that day"
		var hr = _ig(Kit.hbox(8))
		var day_text = Dates.format_date(str(hs.date)) if str(hs.date).substr(0, 4) == this_year else Dates.format_date(str(hs.date), {"month": "short", "day": "numeric", "year": "numeric"})
		var d = Kit.label(day_text, 12, Pal.GOOD if from_note else Pal.MUTED, true)
		d.custom_minimum_size.x = 52
		hr.add_child(Kit.vcenter(d))
		var what = Kit.clip(LiftHistory.describe_sets(hs.sets, fmt_w), 13, null, true)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hr.add_child(Kit.vcenter(what))
		var tag = SessionView.compare_tag(LiftTrend.compare(hs.sets, history.slice(i + 1)), wu)
		if tag != null:
			hr.add_child(Kit.vcenter(tag))
		hc.add(hr)
		box.add_child(hc)
	if history.size() > shown:
		box.add_child(Kit.muted("and %d earlier session%s" % [history.size() - shown, "" if history.size() - shown == 1 else "s"], 11))


## The lift's bests, from the log: three tiles, the heaviest set for each rep
## count when they differ, and one line of totals.
static func _records(box: Control, st: Dictionary, wu: String) -> void:
	box.add_child(Kit.section_title("Records"))
	var vals
	var caps
	if float(st.bestKg) > 0.0:
		var bw = JourneyScreen.split_unit(Fmt.fmt_weight(float(st.bestKg), wu))
		var e1 = JourneyScreen.split_unit(Fmt.fmt_weight(float(st.e1rm), wu, 0))
		vals = [bw[0], e1[0], str(int(st.count))]
		caps = ["%s × %d best" % [bw[1], int(st.bestReps)], "%s est. 1RM" % e1[1], "Sessions"]
	elif LiftTrend.held(st.history):
		# A stretch or other hold: seconds are what counts.
		vals = [str(longest_hold(st.history)), Xp.fmt_int(st.reps), str(int(st.count))]
		caps = ["s longest hold", "Holds in all", "Sessions"]
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
	# The heaviest set of at least 1, 3, 5... reps: worth showing only when they differ.
	var marks = LiftLibrary.rep_bests(st)
	var different = {}
	for m in marks:
		different[snappedf(float(m.kg), 0.01)] = true
	if different.size() >= 2:
		var mf = Kit.grid(mini(3, marks.size()), 6)
		mf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for m in marks:
			mf.add_child(JourneyScreen.value_chip("1 rep" if int(m.reps) == 1 else "%d+ reps" % int(m.reps), Fmt.fmt_weight(float(m.kg), wu), Pal.LIFT, "Heaviest set of at least %d rep%s" % [int(m.reps), "" if int(m.reps) == 1 else "s"]))
		box.add_child(mf)
	var facts = "Last done %s" % Dates.relative_day(st.last, App.today)
	if float(st.volumeKg) > 0.0:
		facts += " · %s lifted in all" % Fmt.fmt_big_kg(float(st.volumeKg), wu)
	box.add_child(Kit.muted(facts, 12))


## The page of one lift, top to bottom: its newest session big, the trend
## chart, the history as a list, then the records, the physical therapy switch
## and the notes. opts:
##   "pending": {"date", "sets"}  sets from the phone note that are not in the
##                                log yet: they are the newest session, and a
##                                point on the chart
##   "skip_id": a session to leave out of the history (the one such a note replaces)
static func open_detail(e: Dictionary, rows: Array, opts: Dictionary = {}) -> void:
	Sfx.tap()
	var wu = App.weight_unit()
	var sheet = Kit.sheet(e.name)
	var box = sheet.box
	# Which variation the page is on: the one asked for, else the one done last,
	# else the usual one.
	var choices = LiftLibrary.variation_list(e)
	var pick = null
	if opts.has("variation"):
		for d in choices:
			if Xp.normalize_exercise(str(d.variation)) == Xp.normalize_exercise(str(opts.variation)):
				pick = d
		if pick == null:
			pick = {"variation": str(opts.variation), "name": LiftNames.join(str(e.name), str(opts.variation)), "st": null}
			choices.push_front(pick)
	elif not choices.is_empty():
		pick = choices[0]
	else:
		pick = {"variation": "", "name": str(e.name), "st": null}
		choices.append(pick)
	var st = pick.st
	if st != null and opts.get("skip_id") != null:
		# The session being replaced is not part of what it is compared with.
		var kept = st.history.filter(func(hh): return hh.id != opts.skip_id)
		if kept.size() != st.history.size():
			st = st.duplicate()
			st["history"] = kept
			if kept.is_empty():
				st = null
	var lift = str(pick.name)
	# Every session of the lift, newest first, the note's sets among them.
	var history = []
	if st != null:
		history = st.history.duplicate()
	var pending = opts.get("pending")
	var cur = null
	if pending is Dictionary:
		cur = {"date": str(pending.date), "id": "", "sets": pending.sets, "note": true}
		history.append(cur)
		TTUtil.stable_sort(history, func(a, b):
			if str(a.date) != str(b.date):
				return str(a.date) > str(b.date)
			return bool(a.get("note", false)) and not bool(b.get("note", false)))
	elif not history.is_empty():
		cur = history[0]

	var tags = Kit.flow(6)
	tags.add_child(Kit.tag(LiftLibrary.part_name(e.part), part_color(e.part), true, 12))
	if e.own:
		tags.add_child(Kit.tag("Your own", Pal.PANEL2, false, 12))
	if Pt.is_pt(App.pt(), lift) or (pending is Dictionary and bool(pending.get("pt", false))):
		tags.add_child(SessionView.pt_tag(12))
	box.add_child(tags)

	# The variations: done ones lit, the rest to try. One tap switches the page.
	if choices.size() > 1 or str(pick.variation) != "":
		var vf = Kit.flow(5)
		for d in choices:
			var said = str(d.variation) if str(d.variation) != "" else "No variation"
			var chip = LogWidgets.mini_chip(said, d.name == pick.name, JourneyLifts._switch.bind(sheet, e, rows, str(d.variation)), Pal.LIFT if d.st != null else Pal.MUTED)
			chip.tooltip_text = ("Done %d time%s" % [int(d.st.count), "" if int(d.st.count) == 1 else "s"]) if d.st != null else "Not done yet"
			if d.st == null and d.name != pick.name:
				chip.modulate.a = 0.6
			vf.add_child(chip)
		box.add_child(vf)

	if cur == null:
		var nc = Kit.card(4, Callable(), 10)
		nc.accent(Pal.SECOND)
		var nr = Kit.hbox(8)
		nr.add_child(Kit.vcenter(Icons.rect("bolt", 22)))
		nr.add_child(Kit.para("New to you. Add it to a workout and it starts a history here.", 13, null, true))
		nc.add(nr)
		box.add_child(nc)
	else:
		box.add_child(_now_card(cur, history.slice(history.find(cur) + 1), wu))
		_trend_card(box, history, wu, Pt.per_week(App.pt(), lift) if Pt.is_pt(App.pt(), lift) else 0)
		_history_list(box, sheet, history, wu)
	if st != null:
		_records(box, st, wu)

	var pt_holder = Kit.vbox(0)
	pt_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(pt_holder)
	_pt_block(pt_holder, lift)

	if not e.own:
		box.add_child(Kit.section_title("How to do it"))
		box.add_child(Kit.para(e.tip, 14))
		if str(e.also) != "":
			box.add_child(Kit.muted_para("Also works: " + str(e.also), 12))

	var add = Kit.button("Add to today's workout", "primary", JourneyLifts._add.bind(sheet, lift), "lg", "plus")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(add)
	sheet.open()


## Another variation of the same movement: the page again, on that one.
static func _switch(sheet: Sheet, e: Dictionary, rows: Array, variation: String) -> void:
	if is_instance_valid(sheet):
		sheet.close()
	open_detail(e, rows, {"variation": variation})


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


## Open the lifting form with this exercise on it (see LogLiftEditor.build).
static func _add(sheet: Sheet, lift_name: String) -> void:
	Sfx.tap()
	sheet.close()
	App.pending_exercise = lift_name
	App.open_log("lift")
	App.toast("%s added to your workout" % lift_name, "good", "check")
