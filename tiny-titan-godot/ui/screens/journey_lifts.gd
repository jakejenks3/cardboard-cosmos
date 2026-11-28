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
		"shoulders", "front_delts", "side_delts", "rear_delts":
			return Pal.ACCENT2
		"triceps":
			return Pal.ACCENT
		"back", "traps":
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
			said.append(str(d.variation) if str(d.variation) != "" else "Standard")
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
		# The last few times of the variation done most recently, as small bars.
		var latest = e.get("done", [])
		if not latest.is_empty() and latest[0].st != null and latest[0].st.history.size() >= 2:
			# (by LiftProgress: one more rep at the same weight is a taller bar; 2026-11-27)
			var prows = LiftProgress.days(latest[0].st.history)
			var vals = LiftProgress.ranks(prows.slice(maxi(0, prows.size() - 8)))
			var sb = SparkBars.new()
			sb.setup(vals, Pal.LIFT)
			sb.tooltip_text = "The last %d times" % vals.size()
			h.add_child(Kit.vcenter(sb))
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


## "100 kg × 5", "Blue band × 12" for a lift done with a band, or "15 reps" for
## a lift only done with bodyweight.
static func best_text(st: Dictionary, wu: String) -> String:
	if float(st.bestKg) > 0.0:
		return "%s × %d" % [Fmt.fmt_weight(float(st.bestKg), wu), int(st.bestReps)]
	if LiftTrend.held(st.history):
		return "%d s hold" % longest_hold(st.history)
	var hb = heaviest_band(st.history)
	if not hb.is_empty():
		return "%s band × %d" % [Bands.name_of(hb.band), int(hb.reps)]
	return "%d reps" % int(st.bwReps)


## The heaviest band in a lift's history, with the most reps done with it:
## {"band", "reps", "level"}, {} when it was never done with a band.
static func heaviest_band(history: Array) -> Dictionary:
	var out = {}
	for h in history:
		var d = LiftTrend.day(h.get("sets", []))
		var lv = int(d.get("band", 0))
		if lv <= 0:
			continue
		if out.is_empty() or lv > int(out.level) or (lv == int(out.level) and int(d.bandReps) > int(out.reps)):
			out = {"band": str(d.bandId), "reps": int(d.bandReps), "level": lv}
	return out


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


## The physical therapy card of a lift: a switch, and when it is on, this
## week's sets (a day counts up to Pt.SETS_A_DAY of them) and how many days a
## week to aim for. Rebuilt in place.
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
		var mine = Pt.row_of(App.sessions(), marks, lift, App.today)
		if mine != null:
			var week = Kit.hbox(8)
			var dots = WeekBars.Dots.new()
			dots.setup(mine.weekShare, Dates.weekday_index(App.today), Pal.PT, 12)
			week.add_child(dots)
			week.add_child(Kit.vcenter(Kit.clip("%d of %d sets this week" % [int(mine.sets), int(mine.setsGoal)], 13, null, true)))
			week.add_child(Kit.vcenter(PtView.state_tag(mine)))
			c.add(week)
			var goal = Kit.hbox(6)
			goal.add_child(Kit.vcenter(Kit.clip("Aim for", 13, Pal.MUTED)))
			goal.add_child(Kit.vcenter(Kit.icon_button("minus", JourneyLifts._set_goal.bind(holder, lift, int(mine.perWeek) - 1), "One day fewer", 28)))
			goal.add_child(Kit.vcenter(PixelFont.rect(str(int(mine.perWeek)), 2, Pal.PT)))
			goal.add_child(Kit.vcenter(Kit.icon_button("plus", JourneyLifts._set_goal.bind(holder, lift, int(mine.perWeek) + 1), "One day more", 28)))
			goal.add_child(Kit.vcenter(Kit.clip(PtView.aim_words(int(mine.perWeek)), 13, Pal.MUTED)))
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


## The both-sides card of a lift: a switch for a single arm or single leg lift
## whose reps are typed as left and right added up (Sides). Rebuilt in place;
## the views above it are drawn again (`ctx`: LiftViews' own, or null for a
## lift never done), since the aim, the estimate and the ladder go by it.
## `tag_slot`: where the page's "L+R" tag goes.
static func _sides_block(holder: Control, lift: String, ctx, tag_slot) -> void:
	if not is_instance_valid(holder):
		return
	Kit.clear(holder)
	var on = Sides.both(App.settings(), lift)
	var c = Kit.card(6, Callable(), 10)
	c.set_meta("sides_card", on)
	if on:
		c.accent(Pal.LIFT)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("repeat", 16)))
	row.add_child(Kit.vcenter(Kit.clip("Reps are both sides added up", 14, null, true)))
	var sw = Kit.switch(on, JourneyLifts._set_sides.bind(holder, lift, ctx, tag_slot), "A single arm or single leg lift logged as left + right in one number")
	sw.set_meta("sides_switch", on)
	row.add_child(sw)
	c.add(row)
	if on:
		c.add(Kit.para("You log left + right as one number: 25 is a 12 and a 13. The aim, the estimate and the rep ladder go by one side.", 12, Pal.MUTED))
	else:
		c.add(Kit.para("For a single arm or single leg lift you log as left + right in one number, so 25 is not read as 25 reps.", 12, Pal.MUTED))
	holder.add_child(c)
	if is_instance_valid(tag_slot):
		Kit.clear(tag_slot)
		if on:
			var t = Kit.tag(Sides.SHORT, Pal.LIFT, true, 12)
			t.tooltip_text = "Reps are both sides added up"
			t.set_meta("sides_tag", true)
			tag_slot.add_child(t)


static func _set_sides(on, holder: Control, lift: String, ctx, tag_slot) -> void:
	Sfx.tick()
	var before = holder.global_position.y
	App.set_both_sides(lift, bool(on))
	_sides_block(holder, lift, ctx, tag_slot)
	# The views above go by it: tag the history anew and draw the view again.
	if ctx is Dictionary and is_instance_valid(ctx.get("holder")):
		var n = Sides.n(App.settings(), lift)
		var at = ctx.history.find(ctx.cur)
		ctx["history"] = Sides.tagged(ctx.history, n)
		if not ctx.history.is_empty():
			ctx["cur"] = ctx.history[maxi(0, at)]
		ctx["sides"] = n
		LiftViews.show_view(str(ctx.view), ctx)
		_keep_in_place(ctx.get("sheet"), holder, before)


## The views above a card were drawn again and are a little taller or
## shorter: scroll the sheet by as much, so the card (and the switch that
## was just tapped) stays where it was.
static func _keep_in_place(sh, c: Control, before: float) -> void:
	if not is_instance_valid(sh):
		return
	await sh.get_tree().process_frame
	await sh.get_tree().process_frame
	if not is_instance_valid(sh) or sh._closing or not is_instance_valid(c):
		return
	var moved = c.global_position.y - before
	if absf(moved) >= 1.0:
		sh._scroll.scroll_vertical += int(round(moved))


## The lift's bests, from the log: three tiles and one line of totals.
## `side_e1rm` (0 or more): the lift's reps are both sides added up (Sides),
## and this is its estimate going by one side.
static func _records(box: Control, st: Dictionary, wu: String, side_e1rm: float = -1.0) -> void:
	box.add_child(Kit.section_title("Records"))
	var vals
	var caps
	if float(st.bestKg) > 0.0:
		var both = side_e1rm >= 0.0
		var bw = JourneyScreen.split_unit(Fmt.fmt_weight(float(st.bestKg), wu))
		var e1 = JourneyScreen.split_unit(Fmt.fmt_weight(side_e1rm if both else float(st.e1rm), wu, 0))
		vals = [bw[0], e1[0], str(int(st.count))]
		caps = ["%s × %d %sbest" % [bw[1], int(st.bestReps), (Sides.SHORT + " ") if both else ""], "%s est. 1RM%s" % [e1[1], " a side" if both else ""], "Sessions"]
	elif LiftTrend.held(st.history):
		# A stretch or other hold: seconds are what counts.
		vals = [str(longest_hold(st.history)), Xp.fmt_int(st.reps), str(int(st.count))]
		caps = ["s longest hold", "Holds in all", "Sessions"]
	elif not heaviest_band(st.history).is_empty():
		# Done with a resistance band: the heaviest band, the most reps with it.
		var hb = heaviest_band(st.history)
		vals = [Bands.name_of(hb.band), str(int(hb.reps)), str(int(st.count))]
		caps = ["Heaviest band", "Reps with it", "Sessions"]
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
		if i == 0 and caps[0] == "Heaviest band":
			t.set_meta("band_record", heaviest_band(st.history).band)
		g.add_child(t)
	box.add_child(g)
	# (The heaviest set for each number of reps is the ladder under it: LiftViews.progress.)
	var facts = "Last done %s" % Dates.relative_day(st.last, App.today)
	if float(st.volumeKg) > 0.0:
		facts += " · %s lifted in all" % Fmt.fmt_big_kg(float(st.volumeKg), wu)
	box.add_child(Kit.muted(facts, 12))


## The page of one lift, top to bottom: its variations, three keys for three
## views of it (LiftViews: Compare, Progress, Logbook), the physical therapy
## switch and the notes. opts:
##   "pending": {"date", "sets"}  sets from the phone note that are not in the
##                                log yet: they are the newest session, and a
##                                point on the chart
##   "skip_id": a session to leave out of the history (the one such a note replaces)
##   "session_id": the logged session the page is about (else the newest)
##   "view": "compare" | "progress" | "logbook" (else the last one picked)
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
	if pending is Dictionary:
		history.append({"date": str(pending.date), "id": "", "sets": pending.sets, "note": true})
		TTUtil.stable_sort(history, func(a, b):
			if str(a.date) != str(b.date):
				return str(a.date) > str(b.date)
			return bool(a.get("note", false)) and not bool(b.get("note", false)))
	# A lift whose reps are both sides added up: its sets say so (Sides), and the
	# aim, the estimate and the rep ladder below go by one side.
	var sides = Sides.n(App.settings(), lift)
	if sides > 1:
		history = Sides.tagged(history, sides)
	var cur = null
	if pending is Dictionary:
		for hh in history:
			if bool(hh.get("note", false)):
				cur = hh
	elif opts.get("session_id") != null:
		# Opened from a logged session: the page is about that day.
		for hh in history:
			if hh.id == opts.session_id:
				cur = hh
	if cur == null and not history.is_empty():
		cur = history[0]

	var tags = Kit.flow(6)
	tags.add_child(Kit.tag(LiftLibrary.part_name(e.part), part_color(e.part), true, 12))
	if e.own:
		tags.add_child(Kit.tag("Your own", Pal.PANEL2, false, 12))
	if Pt.is_pt(App.pt(), lift) or (pending is Dictionary and bool(pending.get("pt", false))):
		tags.add_child(SessionView.pt_tag(12))
	# (filled by the both-sides card below, which can change it)
	var sides_tag = Kit.hbox(0)
	tags.add_child(sides_tag)
	box.add_child(tags)

	# The variations: done ones lit, the rest to try. One tap switches the page.
	if choices.size() > 1 or str(pick.variation) != "":
		var vf = Kit.vbox(4)
		box.add_child(vf)
		_variation_chips(vf, sheet, e, rows, choices, pick, false)

	var ctx = null
	if cur == null:
		var nc = Kit.card(4, Callable(), 10)
		nc.accent(Pal.SECOND)
		var nr = Kit.hbox(8)
		nr.add_child(Kit.vcenter(Icons.rect("bolt", 22)))
		nr.add_child(Kit.para("New to you. Add it to a workout and it starts a history here.", 13, null, true))
		nc.add(nr)
		box.add_child(nc)
	else:
		# Three ways to look at it: Compare, Progress, Logbook (LiftViews). From a
		# list of exercises (the note's review, a session) it opens on Compare.
		var view = str(opts.get("view", LiftViews.last_view))
		ctx = {"sheet": sheet, "lift": lift, "history": history, "cur": cur, "st": st, "wu": wu,
			"goal": Pt.per_week(App.pt(), lift) if Pt.is_pt(App.pt(), lift) else 0, "view": view, "sides": sides,
			# Not done today and not opened from a session or the note: the page is about the LATEST time, and
			# says so (it used to say "THIS TIME... better than last time" of a day a week ago).
			"past": not (pending is Dictionary) and opts.get("session_id") == null and str(cur.date) != App.today}
		LiftViews.build(box, ctx)

	var pt_holder = Kit.vbox(0)
	pt_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(pt_holder)
	_pt_block(pt_holder, lift)
	var sides_holder = Kit.vbox(0)
	sides_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(sides_holder)
	_sides_block(sides_holder, lift, ctx, sides_tag)

	# A goal with a date for this lift (LiftGoals): redrawn in place when one is set or taken off.
	var goal_holder = Kit.vbox(0)
	goal_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(goal_holder)
	var fill_goal = func(me):
		Kit.clear(goal_holder)
		goal_holder.add_child(TrackingViews.goal_block(lift, func(): me.call(me)))
	fill_goal.call(fill_goal)

	if not e.own:
		box.add_child(Kit.section_title("How to do it"))
		box.add_child(Kit.para(e.tip, 14))
		if str(e.also) != "":
			box.add_child(Kit.muted_para("Also works: " + str(e.also), 12))

	var add = Kit.button("Add to today's workout", "primary", JourneyLifts._add.bind(sheet, lift), "lg", "plus")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(add)
	if App.lift_sessions(lift) > 0:
		# Filed under the wrong name? Rename it, or move it under another movement.
		var ren = Kit.button("Rename or move this lift", "ghost", JourneyLifts.open_rename.bind(sheet, lift), "sm", "edit")
		ren.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ren.set_meta("rename_lift", true)
		box.add_child(ren)
	sheet.open()


## Rename a lift, or move it under another movement: the movement and the
## variation as two boxes, the nearest movements as keys, and what will happen
## said before it does (how many workouts; joined with a lift that is there
## already). App.rename_lift does it everywhere and keeps a copy of the save.
static func open_rename(from_sheet, lift: String) -> void:
	Sfx.tap()
	var sp = LiftNames.split(lift)
	var n = App.lift_sessions(lift)
	var sheet = Kit.sheet("Rename lift")
	var box = sheet.box
	box.add_child(Kit.muted_para("%s is in %d workout%s. A new name goes into all of them; its sets, dates and records come along." % [lift, n, "" if n == 1 else "s"], 13))
	box.add_child(Kit.label("MOVEMENT", 10, Pal.MUTED, true))
	var move = Kit.input(str(sp.move), "Bench Press")
	move.select_all_on_focus = false
	move.set_meta("rename_move", true)
	box.add_child(move)
	var near = Kit.flow(6)
	box.add_child(near)
	box.add_child(Kit.label("VARIATION (position or equipment)", 10, Pal.MUTED, true))
	var vari = Kit.input(str(sp.variation), "none")
	vari.select_all_on_focus = false
	vari.set_meta("rename_variation", true)
	box.add_child(vari)
	var said = Kit.para("", 14, null, true)
	said.set_meta("rename_said", true)
	box.add_child(said)
	var go = Kit.button("Rename", "primary", Callable(), "lg")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(go)
	var moves = []
	for r in LiftLibrary.rows(App.sessions()):
		moves.append(str(r.name))
	var refresh = func():
		var name_now = LiftNames.join(move.text.strip_edges(), vari.text.strip_edges())
		var same = name_now == lift
		var there = 0 if Xp.normalize_exercise(name_now) == Xp.normalize_exercise(lift) else App.lift_sessions(name_now)
		if move.text.strip_edges() == "":
			said.text = "Give it a movement name."
		elif same:
			said.text = "Change the movement or the variation."
		elif there > 0:
			said.text = "You already have %s (%d workout%s): the two become one lift." % [name_now, there, "" if there == 1 else "s"]
		else:
			said.text = "It will be: %s" % name_now
		said.add_theme_color_override("font_color", Pal.SECOND if there > 0 else (Pal.MUTED if same else Pal.TEXT))
		go.disabled = same or move.text.strip_edges() == ""
		go.text = "Join the two" if there > 0 else "Rename"
	var fill_near = func():
		Kit.clear(near)
		var typed = move.text.strip_edges()
		if typed == "" or typed == str(sp.move):
			return
		for hit in LiftMatch.find(typed, moves, 4):
			if str(hit.name) == typed:
				continue
			var chip = LogWidgets.mini_chip(str(hit.name), false, Callable(), Pal.LIFT)
			chip.pressed.connect(func():
				Sfx.tick()
				move.text = str(hit.name)
				Kit.clear(near)
				refresh.call())
			near.add_child(chip)
	move.text_changed.connect(func(_t):
		fill_near.call()
		refresh.call())
	vari.text_changed.connect(func(_t): refresh.call())
	go.pressed.connect(func():
		var res = App.rename_lift(lift, LiftNames.join(move.text.strip_edges(), vari.text.strip_edges()))
		if not bool(res.ok):
			App.toast("Nothing to rename", "info", "info")
			return
		Sfx.claim()
		App.toast(("Joined with %s: %d workout%s moved" if bool(res.joined) else "Now %s, in %d workout%s") % [str(res.name), int(res.sessions), "" if int(res.sessions) == 1 else "s"], "good", "check")
		sheet.close()
		if from_sheet != null and is_instance_valid(from_sheet):
			from_sheet.close()
		JourneyLifts.open_named(str(res.name)))
	refresh.call()
	sheet.open()


## The variation chips at the top of a lift's page. With many variations only
## the ones done (and the one shown) are there, and "+N more" shows the rest.
static func _variation_chips(vf: Control, sheet: Sheet, e: Dictionary, rows: Array, choices: Array, pick: Dictionary, all: bool) -> void:
	if not is_instance_valid(vf):
		return
	Kit.clear(vf)
	var wu = App.weight_unit()
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	# The variations done, each a row: its name, how often, when last and what was done last (2026-11-27:
	# the chips alone did not say which variation a history was about). The page's own one is lit.
	var done = choices.filter(func(d): return d.st != null)
	if not done.is_empty():
		vf.add_child(Kit.label("YOUR VARIATIONS" if done.size() > 1 else "YOUR VARIATION", 10, Pal.MUTED, true))
	for d in done:
		var here = d.name == pick.name
		var r = Kit.row(Callable() if here else JourneyLifts._switch.bind(sheet, e, rows, str(d.variation)), Pal.LIFT if here else Pal.LINE, Pal.LIFT if here else null, 6, 1, 0.14 if here else 0.0)
		r.set_meta("variation_row", str(d.variation))
		r.set_meta("variation_here", here)
		r.tooltip_text = "This page" if here else "Open this variation"
		var h = Kit.hbox(6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var said = str(d.variation) if str(d.variation) != "" else "No variation"
		var nl = Kit.clip(said, 14, null, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(Kit.vcenter(nl))
		var n = int(d.st.count)
		h.add_child(Kit.vcenter(Kit.label("%d time%s · %s" % [n, "" if n == 1 else "s", Missions.when_text(str(d.st.last), App.today)], 11, Pal.MUTED, true)))
		r.add(h)
		if not d.st.history.is_empty():
			r.add(Kit.clip("Last: " + LiftHistory.describe_sets(d.st.history[0].sets, fmt_w), 12, Pal.TEXT if here else Pal.MUTED))
		vf.add_child(r)
	# The ones not done yet, to try: chips (a few, then "+N more").
	var fresh = choices.filter(func(d): return d.st == null)
	if fresh.is_empty():
		return
	var flow = Kit.flow(5)
	flow.add_child(Kit.vcenter(Kit.label("NOT TRIED" if not done.is_empty() else "VARIATIONS", 10, Pal.MUTED, true)))
	var hidden = 0
	for d in fresh:
		if not all and fresh.size() > 6 and d.name != pick.name and flow.get_child_count() > 5:
			hidden += 1
			continue
		var said2 = str(d.variation) if str(d.variation) != "" else "No variation"
		var chip = LogWidgets.mini_chip(said2, d.name == pick.name, JourneyLifts._switch.bind(sheet, e, rows, str(d.variation)), Pal.SECOND if d.name == pick.name else Pal.MUTED)
		chip.tooltip_text = "Not done yet"
		if d.name != pick.name:
			chip.modulate.a = 0.75
		flow.add_child(chip)
	if hidden > 0:
		var more = LogWidgets.mini_chip("+%d more" % hidden, false, JourneyLifts._more_variations.bind(vf, sheet, e, rows, choices, pick), Pal.MUTED)
		more.tooltip_text = "Show every variation"
		flow.add_child(more)
	vf.add_child(flow)


static func _more_variations(vf: Control, sheet: Sheet, e: Dictionary, rows: Array, choices: Array, pick: Dictionary) -> void:
	Sfx.tick()
	_variation_chips(vf, sheet, e, rows, choices, pick, true)


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
