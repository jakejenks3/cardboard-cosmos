class_name LiftViews
extends RefCounted
## Three ways to look at one lift on its page (JourneyLifts.open_detail),
## picked with the three keys under the variations:
##
##   Compare   this time against last time (or the best day), like a versus
##             screen: both top sets big, a verdict, the sets side by side with
##             a change on each, the totals, the records it set and a target
##             for next time (LiftTrend.pairs / records / next_target)
##   Progress  a chart over time: the line is the number the lift is about,
##             bars along the bottom are each day's work, gold marks every new
##             best and a crown the best ever; a range (1M, 3M, 1Y, All); then
##             the records and the heaviest weight for each number of reps
##   Logbook   a calendar of the days it was done (bigger days brighter, new
##             bests ringed) and every session as a row of blocks, one per set,
##             month by month
##
## `ctx` (built by open_detail): sheet, lift (its full name), history (newest
## first, the phone note's sets among them), cur (the session the page is
## about), st (the lift's stats from the log), wu (weight unit), goal (PT days a
## week, 0 = not PT), view. Picking a view rebuilds only what is under the keys.

const VIEWS = [
	{"id": "compare", "label": "Compare", "icon": "sword"},
	{"id": "progress", "label": "Progress", "icon": "rocket"},
	{"id": "logbook", "label": "Logbook", "icon": "calendar"},
]
## Sessions the logbook lists before "Show all".
const LOGBOOK_SHOWN = 10
## The calendar shows this many weeks at most, and at least MIN_WEEKS: a lift
## started recently gets a smaller calendar that grows with its history.
const CAL_WEEKS = 16
const MIN_WEEKS = 8

## The view a lift's page opens on from the library: the last one picked.
static var last_view = "compare"


static func build(box: Control, ctx: Dictionary) -> void:
	var keys = Kit.hbox(6)
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(keys)
	var holder = Kit.vbox(10)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(holder)
	ctx["keys"] = keys
	ctx["holder"] = holder
	show_view(str(ctx.get("view", last_view)), ctx)


static func show_view(view: String, ctx: Dictionary) -> void:
	var holder = ctx.holder
	if not is_instance_valid(holder):
		return
	ctx["view"] = view
	Kit.clear(ctx.keys)
	for v in VIEWS:
		var b = LogWidgets.toggle(v.label, v.icon, v.id == view, Pal.LIFT, LiftViews._pick.bind(v.id, ctx))
		b.tooltip_text = {"compare": "This time against last time, set by set", "progress": "A chart over time, and your records", "logbook": "Every day you did it"}[v.id]
		ctx.keys.add_child(b)
	Kit.clear(holder)
	match view:
		"progress":
			progress(holder, ctx)
		"logbook":
			logbook(holder, ctx)
		_:
			compare(holder, ctx)


static func _pick(view: String, ctx: Dictionary) -> void:
	if view == str(ctx.get("view", "")):
		return
	Sfx.tick()
	last_view = view
	show_view(view, ctx)


# ---------------------------------------------------------------------------
# Small shared pieces
# ---------------------------------------------------------------------------

## What a lift is judged by: "sec" (a hold), "kg" (it carries weight), "band"
## (done with a resistance band, Bands) or "reps".
static func mode_of(history: Array) -> String:
	if LiftTrend.held(history):
		return "sec"
	if LiftTrend.weighted(history):
		return "kg"
	return "band" if LiftTrend.banded(history) else "reps"


static func _fmt_w(wu: String) -> Callable:
	return func(kg): return Fmt.fmt_weight(float(kg), wu)


## One set in words: "60 kg × 10", "12 reps", "3 × 30 s", "15 × green band".
static func set_text(one, wu: String) -> String:
	if one == null:
		return "-"
	if LiftTrend.is_hold(one):
		return "%d s" % int(one.holdSec) if int(one.reps) == 1 else "%d × %d s" % [int(one.reps), int(one.holdSec)]
	if Bands.is_band(one):
		return "%d × %s" % [int(one.reps), Bands.words(one.band)]
	if float(one.get("weightKg", 0)) > 0.0:
		return "%s × %d" % [Fmt.fmt_weight(float(one.weightKg), wu), int(one.reps)]
	return "%d rep%s" % [int(one.reps), "" if int(one.reps) == 1 else "s"]


## The big number of a session and what it is: ["135", "lb · top set"].
static func main_text(d: Dictionary, mode: String, wu: String) -> Array:
	if mode == "sec":
		return [str(int(d.holdSec)), "s · longest hold"]
	if mode == "kg" and float(d.topKg) > 0.0:
		var parts = JourneyScreen.split_unit(Fmt.fmt_weight(float(d.topKg), wu))
		return [str(parts[0]), "%s · top set" % str(parts[1])]
	if mode == "band" and int(d.get("band", 0)) > 0:
		return [Bands.name_of(d.bandId), "band · × %d" % int(d.get("bandReps", 0))]
	return [str(int(d.bestReps)), "reps · best set"]


static func _day_text(date: String) -> String:
	return Dates.format_date(date, {"weekday": "short", "month": "short", "day": "numeric"})


## A raised strip in one colour with an icon and a line of bold text.
static func banner(icon: String, text: String, color: Color, dark_text: bool = true) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(color, {"lip": 2, "pad_h": 10, "pad_v": 7}))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect(icon, 16, Pal.INK if dark_text else null)))
	var l = Kit.para(text, 14, Pal.INK if dark_text else Pal.TEXT, true)
	h.add_child(l)
	p.add_child(h)
	return p


## A change as a small coloured pill with an arrow: "+2.5 lb", "-1 rep".
static func delta_pill(text: String, up: bool) -> Control:
	return Kit.pill("arrow_up" if up else "arrow_down", text, Pal.GOOD if up else Pal.ACCENT2, "", Pal.INK, 11)


# ---------------------------------------------------------------------------
# Compare
# ---------------------------------------------------------------------------

static func compare(holder: Control, ctx: Dictionary) -> void:
	var wu = str(ctx.wu)
	var history = ctx.history
	var cur = ctx.cur
	var before = history.slice(history.find(cur) + 1)
	var mode = mode_of(history)
	var last = before[0] if not before.is_empty() else null
	# (judged as a band lift when any day of it has a band, the days before
	# bands could be logged among them: LiftTrend.main_value)
	var in_band = LiftTrend.banded(history)
	var best = LiftTrend.best_row(before, in_band)
	var against = str(ctx.get("against", "last"))
	if best == null or best == last:
		against = "last"
	var other = best if against == "best" else last
	var past = bool(ctx.get("past", false))
	if past:
		# Not done today: what follows is about the latest time, against the time before it.
		var pl = Kit.para("Not done today. Your latest time was %s%s." % [_day_text(str(cur.date)), ", against the time before it" if last != null else ""], 12, Pal.MUTED)
		pl.set_meta("lift_past", str(cur.date))
		holder.add_child(pl)
	if last != null and best != null and best != last:
		var ch = Kit.hbox(6)
		ch.add_child(Kit.vcenter(Kit.label("Against", 12, Pal.MUTED, true)))
		ch.add_child(LogWidgets.mini_chip("Last time", against == "last", LiftViews._against.bind("last", ctx), Pal.LIFT))
		ch.add_child(LogWidgets.mini_chip("Best day", against == "best", LiftViews._against.bind("best", ctx), Pal.ACCENT))
		holder.add_child(ch)
	holder.add_child(_versus(cur, other, against == "best", mode, wu, past))
	var cmp = LiftTrend.compare(cur.sets, [other] if other != null else [])
	var recs = LiftTrend.records(cur.sets, before)
	holder.add_child(_verdict(cmp, recs, other, against, wu, str(cur.date) if past else ""))
	if other != null:
		holder.add_child(_set_table(cur, other, against, wu, past))
	holder.add_child(_totals(cur, other, mode, wu))
	if not recs.is_empty():
		holder.add_child(_records_card(recs, wu, str(cur.date) if past else ""))
	elif best != null and LiftTrend.main_value(LiftTrend.day(best.sets), in_band) > LiftTrend.main_value(LiftTrend.day(cur.sets), in_band) + 1e-6 \
			and (mode != "band" or (int(LiftTrend.day(best.sets).get("band", 0)) > 0 and int(LiftTrend.day(cur.sets).get("band", 0)) > 0)):
		# (a band lift: only a band day against a band day; a day logged before
		# bands could be has nothing to say about one)
		holder.add_child(_best_card(cur, best, mode, wu))
	var g = LiftTrend.ghost(history, cur)
	if g != null:
		holder.add_child(_ghost_card(g, mode, wu))
	# (no strength level for a band: a band-assisted pull-up is not a pull-up's reps)
	var std = _standard_card(history, str(ctx.get("lift", "")), wu) if mode != "band" else null
	if std != null:
		holder.add_child(std)
	var stuck = LiftTrend.plateau(history)
	if stuck != null and int(ctx.get("goal", 0)) == 0:
		holder.add_child(_stuck_card(stuck, history, str(ctx.get("lift", "")), wu))
	# A target for next time, except for physical therapy: that follows its plan.
	if int(ctx.get("goal", 0)) == 0:
		var nxt = _next_card(cur, mode, wu)
		if nxt != null:
			holder.add_child(nxt)


static func _against(which: String, ctx: Dictionary) -> void:
	if str(ctx.get("against", "last")) == which:
		return
	Sfx.tick()
	ctx["against"] = which
	show_view("compare", ctx)


## Both sessions side by side, their top sets big, "VS" between them.
static func _versus(cur: Dictionary, other, is_best: bool, mode: String, wu: String, past: bool = false) -> Card:
	var note = bool(cur.get("note", false))
	var c = Kit.card(6, Callable(), 12)
	c.accent(Pal.GOOD if note else Pal.LIFT)
	var row = Kit.hbox(8)
	if other != null:
		row.add_child(_side(other, "BEST DAY" if is_best else ("TIME BEFORE" if past else "LAST TIME"), false, mode, wu))
	else:
		var none = Kit.vbox(4)
		none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		none.add_child(Kit.label("TIME BEFORE" if past else "LAST TIME", 10, Pal.MUTED, true))
		none.add_child(Kit.vcenter(PixelFont.rect("--", 3, Pal.with_alpha(Pal.MUTED, 0.6))))
		none.add_child(Kit.label("Nothing yet", 11, Pal.MUTED, true))
		row.add_child(none)
	var vs = PanelContainer.new()
	vs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vs.add_theme_stylebox_override("panel", PixBox.make(Pal.INK, {"ring": Pal.ACCENT, "lip": 1, "pad_h": 6, "pad_v": 5}))
	vs.add_child(PixelFont.rect("VS", 2, Pal.ACCENT))
	row.add_child(Kit.vcenter(vs))
	row.add_child(_side(cur, "IN YOUR NOTE" if note else ("LATEST" if past else "THIS TIME"), true, mode, wu))
	c.add(row)
	return c


static func _side(h: Dictionary, kicker: String, lit: bool, mode: String, wu: String) -> VBoxContainer:
	var note = bool(h.get("note", false))
	var v = Kit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var align = HORIZONTAL_ALIGNMENT_RIGHT if lit else HORIZONTAL_ALIGNMENT_LEFT
	var k = Kit.label(kicker, 10, Pal.GOOD if note else (Pal.ACCENT if lit else Pal.MUTED), true)
	k.horizontal_alignment = align
	v.add_child(k)
	var when = Kit.clip(_day_text(str(h.date)), 11, Pal.MUTED, true)
	when.horizontal_alignment = align
	v.add_child(when)
	var d = LiftTrend.day(h.sets)
	var mt = main_text(d, mode, wu)
	var big = PixelFont.rect(str(mt[0]), 4 if lit and str(mt[0]).length() <= 4 else 3, (Pal.GOOD if note else Pal.ACCENT) if lit else Pal.MUTED)
	big.size_flags_horizontal = Control.SIZE_SHRINK_END if lit else Control.SIZE_SHRINK_BEGIN
	v.add_child(big)
	if mode == "band" and int(d.get("band", 0)) > 0:
		# The band's own colour under its name.
		var sw = BandPicker.swatch(d.bandId, 10)
		sw.custom_minimum_size = Vector2(44, 10)
		sw.size_flags_horizontal = Control.SIZE_SHRINK_END if lit else Control.SIZE_SHRINK_BEGIN
		v.add_child(sw)
	var unit = Kit.label(str(mt[1]), 10, Pal.MUTED, true)
	unit.horizontal_alignment = align
	v.add_child(unit)
	var sets = Kit.clip(LiftHistory.describe_sets(h.sets, _fmt_w(wu)), 12, Pal.TEXT if lit else Pal.MUTED, lit)
	sets.horizontal_alignment = align
	v.add_child(sets)
	return v


## One line that says how it went, in the colour of the news.
## `past`: the date of the latest time when it is not today (the words then say which day they are about).
static func _verdict(cmp: Dictionary, recs: Array, other, against: String, wu: String, past: String = "") -> Control:
	var on = "%s: " % _day_text(past) if past != "" else ""
	if other == null:
		return banner("sparkle", ("%sthe first time, the mark to beat." % on) if past != "" else "First time: this is the mark to beat.", Pal.SECOND)
	if not recs.is_empty():
		var b = banner("crown", "%sa new record! %s." % [on, str(recs[0].label)] if past != "" else "New record! %s." % str(recs[0].label), Pal.ACCENT)
		Fx.shine(b, 3.5, 0.4)
		return b
	var said = SessionView.delta_text(cmp, wu)
	var where = "in all"
	if absf(float(cmp.get("kg", 0.0))) > 1e-6:
		where = "on your top set"
	elif int(cmp.get("sec", 0)) != 0:
		where = "on your longest hold"
	var who = "your best day" if against == "best" else ("the time before" if past != "" else "last time")
	if int(cmp.get("band", 0)) != 0:
		# A band: "+1 band: a heavier band than last time."
		var heavier = int(cmp.band) > 0
		return banner("arrow_up" if heavier else "arrow_down", "%s%s: a %s band than %s." % [on, said, "heavier" if heavier else "lighter", who], Pal.GOOD if heavier else Pal.ACCENT2)
	match str(cmp.kind):
		"up":
			return banner("arrow_up", "%s%s %s. Better than %s." % [on, said, where, who], Pal.GOOD)
		"down":
			return banner("arrow_down", "%s%s %s. A lighter day than %s." % [on, said, where, who], Pal.ACCENT2)
	return banner("repeat", "%sSame as %s." % [on, who], Pal.PANEL2, false)


## Set by set: last time on the left, this time on the right, the change between.
static func _set_table(cur: Dictionary, other: Dictionary, against: String, wu: String, past: bool = false) -> Card:
	var c = Kit.card(4, Callable(), 10)
	var head = Kit.hbox(6)
	head.add_child(_col(Kit.label("SET", 10, Pal.MUTED, true), 26))
	var l = Kit.label("BEST DAY" if against == "best" else ("TIME BEFORE" if past else "LAST TIME"), 10, Pal.MUTED, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(_col(Control.new(), 84))
	var r = Kit.label("LATEST" if past else "THIS TIME", 10, Pal.MUTED, true)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(r)
	c.add(head)
	for p in LiftTrend.pairs(cur.sets, other.sets):
		c.add(_pair_row(p, wu))
	return c


static func _col(ctl: Control, w: float) -> Control:
	ctl.custom_minimum_size.x = w
	ctl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return ctl


static func _pair_row(p: Dictionary, wu: String) -> Control:
	var tint = {"up": Pal.GOOD, "down": Pal.ACCENT2, "added": Pal.SECOND}.get(str(p.kind), Pal.PANEL2)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(tint, 0.13), 4, null, 0, 4, 3))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = Kit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num = PanelContainer.new()
	num.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	num.add_theme_stylebox_override("panel", PixBox.well(0, 2))
	var nl = Kit.label(str(int(p.i)), 12, Pal.TEXT, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_child(nl)
	row.add_child(Kit.vcenter(_col(num, 26)))
	var prev = Kit.clip(set_text(p.prev, wu), 13, Pal.MUTED, false)
	row.add_child(_with_swatch(prev, p.prev, false))
	var mid = CenterContainer.new()
	mid.custom_minimum_size = Vector2(84, 24)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_pair_chip(p, wu))
	row.add_child(mid)
	var now = Kit.clip(set_text(p.cur, wu), 13, Pal.TEXT, true)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_with_swatch(now, p.cur, true))
	panel.add_child(row)
	return panel


## A set's words, with a square of its band's colour beside them when it was
## done with a band (on the outer side: left of last time's, right of this time's).
static func _with_swatch(words: Label, one, right: bool) -> Control:
	if not (one is Dictionary and Bands.is_band(one)):
		return Kit.vcenter(words)
	var h = Kit.hbox(5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sw = BandPicker.swatch(one.band, 10)
	if right:
		h.add_child(words)
		h.add_child(sw)
	else:
		h.add_child(sw)
		h.add_child(words)
	return h


static func _pair_chip(p: Dictionary, wu: String) -> Control:
	match str(p.kind):
		"added":
			return Kit.tag("NEW SET", Pal.SECOND, false, 10)
		"dropped":
			return Kit.tag("NOT DONE", Pal.PANEL2, false, 10)
		"same":
			return Kit.tag("same", Pal.PANEL2, false, 10)
	var up = str(p.kind) == "up"
	var text = ""
	if absf(float(p.dkg)) > 1e-6:
		text = "%s%s" % ["+" if p.dkg > 0.0 else "-", Fmt.fmt_weight(absf(float(p.dkg)), wu)]
	elif int(p.get("dband", 0)) != 0:
		text = SessionView.band_change(int(p.dband))
	elif int(p.dsec) != 0:
		text = "%s%d s" % ["+" if p.dsec > 0 else "-", absi(int(p.dsec))]
	else:
		text = "%s%d rep%s" % ["+" if p.dreps > 0 else "-", absi(int(p.dreps)), "" if absi(int(p.dreps)) == 1 else "s"]
	return delta_pill(text, up)


## Sets, reps and weight moved (or seconds held), with the change against the other session.
static func _totals(cur: Dictionary, other, mode: String, wu: String) -> Control:
	var d = LiftTrend.day(cur.sets)
	var o = LiftTrend.day(other.sets) if other != null else null
	var tiles = [["Sets", float(d.sets), float(o.sets) if o != null else -1.0, "n"], ["Reps", float(d.reps), float(o.reps) if o != null else -1.0, "n"]]
	if mode == "kg":
		tiles.append(["Moved", float(d.volumeKg), float(o.volumeKg) if o != null else -1.0, "kg"])
	elif mode == "sec":
		tiles.append(["Seconds held", float(d.holdTotal), float(o.holdTotal) if o != null else -1.0, "n"])
	else:
		tiles.append(["Best set", float(d.bestReps), float(o.bestReps) if o != null else -1.0, "n"])
	var g = Kit.grid(3, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in tiles:
		g.add_child(_total_tile(str(t[0]), float(t[1]), float(t[2]), str(t[3]), wu))
	return g


static func _total_tile(cap: String, v: float, was: float, kind: String, wu: String) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.well(8, 7))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v_box = Kit.vbox(3)
	v_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown = Xp.fmt_int(v)
	var unit = ""
	if kind == "kg":
		var parts = JourneyScreen.split_unit(Fmt.fmt_big_kg(v, wu))
		shown = str(parts[0])
		unit = " " + str(parts[1])
	var top = Kit.hbox(3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(PixelFont.rect(shown, 2 if shown.length() <= 6 else 1, Pal.TEXT))
	if unit != "":
		top.add_child(Kit.vcenter(Kit.label(unit.strip_edges(), 10, Pal.MUTED, true)))
	v_box.add_child(top)
	v_box.add_child(Kit.clip(cap, 11, Pal.MUTED, true))
	if was >= 0.0:
		var dv = v - was
		if absf(dv) < 1e-6:
			v_box.add_child(Kit.tag("same", Pal.PANEL2, false, 10))
		else:
			var said = Xp.fmt_int(absf(dv)) if kind != "kg" else Fmt.fmt_big_kg(absf(dv), wu)
			v_box.add_child(Kit.tag("%s%s" % ["+" if dv > 0.0 else "-", said], Pal.GOOD if dv > 0.0 else Pal.ACCENT2, true, 10))
	p.add_child(v_box)
	return p


static func record_value(r: Dictionary, wu: String) -> String:
	match str(r.unit):
		"kg":
			return Fmt.fmt_weight(float(r.value), wu, 0) if str(r.id) == "volume" or str(r.id) == "strength" else Fmt.fmt_weight(float(r.value), wu)
		"sec":
			return "%d s" % int(r.value)
		"band":
			return "%s band" % Bands.name_of(r.get("band", ""))
	return "%d reps" % int(r.value)


static func _records_card(recs: Array, wu: String, past: String = "") -> Card:
	var c = Kit.card(6, Callable(), 12)
	c.accent(Pal.ACCENT)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("trophy", 20)))
	head.add_child(Kit.vcenter(PixelFont.rect("RECORDS", 2, Pal.ACCENT)))
	head.add_child(Kit.vcenter(Kit.clip("beaten on %s" % _day_text(past) if past != "" else "beaten this time", 12, Pal.MUTED, true)))
	c.add(head)
	for r in recs:
		var row = Kit.hbox(8)
		row.add_child(Kit.vcenter(Icons.rect("star", 16)))
		var l = Kit.clip(str(r.label), 13, Pal.TEXT, true)
		row.add_child(Kit.vcenter(l))
		row.add_child(Kit.vcenter(Kit.tag(record_value(r, wu), Pal.ACCENT, true, 12)))
		c.add(row)
	return c


## The best day, when this session is not it: what is still to beat.
static func _best_card(cur: Dictionary, best: Dictionary, mode: String, wu: String) -> Card:
	var c = Kit.card(4, Callable(), 10)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(Icons.rect("trophy", 18)))
	var words = Kit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d = LiftTrend.day(best.sets)
	var top_set = main_text(d, mode, wu)
	words.add_child(Kit.clip("Your best: %s %s on %s" % [str(top_set[0]), str(top_set[1]).get_slice(" · ", 0), Dates.format_date(str(best.date))], 13, Pal.TEXT, true))
	var gap = LiftTrend.main_value(d) - LiftTrend.main_value(LiftTrend.day(cur.sets))
	var gap_text = "%d s more than this time" % int(gap) if mode == "sec" else ("%s more than this time" % Fmt.fmt_weight(gap, wu) if mode == "kg" else "%d more reps in a set than this time" % int(gap))
	if mode == "band":
		# A heavier band, or more reps with the same band.
		var cd = LiftTrend.day(cur.sets)
		var steps = int(d.get("band", 0)) - int(cd.get("band", 0))
		if steps > 0:
			gap_text = "%s heavier than this time" % SessionView.band_change(steps).substr(1)
		else:
			gap_text = "%d more reps with the %s than this time" % [maxi(0, int(d.get("bandReps", 0)) - int(cd.get("bandReps", 0))), Bands.words(d.get("bandId", ""))]
	words.add_child(Kit.clip(gap_text, 12, Pal.MUTED))
	row.add_child(words)
	c.add(row)
	return c


## The ghost duel: the hero against a see-through copy of themselves about
## four weeks earlier, a bar each, who won (a burst when it is the player).
static func _ghost_card(g: Dictionary, mode: String, wu: String) -> Card:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.SECOND)
	var weeks = maxi(1, int(round(float(g.days) / 7.0)))
	c.add(Kit.label("GHOST DUEL · YOU vs YOU, %d WEEK%s AGO" % [weeks, "" if weeks == 1 else "S"], 10, Pal.SECOND, true))
	var row = Kit.hbox(10)
	var tex = Art.hero_texture(App.state, App.profile(), App.loadout())
	var me = PixelRect.make(tex, 1.0)
	me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(me)
	var mid = Kit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top = maxf(float(g.you), float(g.them))
	for side in [["YOU", float(g.you), Pal.ACCENT], ["GHOST", float(g.them), Pal.SECOND]]:
		var line = Kit.hbox(6)
		var name = Kit.label(str(side[0]), 10, side[2], true)
		name.custom_minimum_size = Vector2(46, 0)
		line.add_child(Kit.vcenter(name))
		var bar = Kit.bar(float(side[1]) / maxf(top, 1e-6), side[2], 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(Kit.vcenter(bar))
		mid.add_child(line)
		mid.add_child(Kit.label(_ghost_value(float(side[1]), mode, wu), 11, Pal.MUTED, true))
	row.add_child(mid)
	var ghost_pic = PixelRect.make(tex, 1.0)
	ghost_pic.flip_h = true
	ghost_pic.modulate = Color(0.55, 0.78, 1.0, 0.55)
	ghost_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ghost_pic)
	c.add(row)
	var said = ""
	var col = Pal.MUTED
	if bool(g.tie):
		said = "Dead heat with your ghost"
	elif bool(g.won):
		said = "You beat your ghost by %d%%" % int(round(float(g.pct)))
		col = Pal.GOOD
	else:
		said = "Your ghost is %d%% ahead: catch it" % int(round(-float(g.pct)))
		col = Pal.ACCENT2
	var v = banner("sword", said, col)
	c.add(v)
	if bool(g.won):
		# A little burst once it is on screen.
		# (a weak reference: the page may be rebuilt before the timer is up)
		var wr = weakref(me)
		me.ready.connect(func():
			var n = wr.get_ref()
			if n != null and n.is_inside_tree():
				n.get_tree().create_timer(0.35).timeout.connect(func():
					var m = wr.get_ref()
					if m != null and m.is_inside_tree():
						Kit.burst(m, Pal.ACCENT, 18)))
	c.tooltip_text = "Your session about four weeks before this one: %s" % _day_text(str(g.ghost.date))
	return c


## How strong the lift is for the player's bodyweight (Standards): the level,
## a bar of five steps, what the next level needs.
static func _standard_card(history: Array, lift_name: String, wu: String):
	var e1 = 0.0
	var reps = 0
	for h in history:
		var d = LiftTrend.day(h.get("sets", []))
		e1 = maxf(e1, float(d.e1rm))
		reps = maxi(reps, int(d.bestReps))
	var bw = Standards.bodyweight(App.body())
	var r = Standards.rate(lift_name, e1, reps, bw)
	if r == null:
		return null
	var col = Color(Standards.COLORS[int(r.level)])
	var c = Kit.card(6, Callable(), 10)
	c.accent(col)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("medal", 24)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip("STRENGTH LEVEL · FROM YOUR ESTIMATED 1-REP MAX" if r.kind == "ratio" else "STRENGTH LEVEL", 10, Pal.MUTED, true))
	var said = "%.2f× bodyweight" % float(r.value) if r.kind == "ratio" else "%d reps in a set" % int(r.value)
	v.add_child(Kit.clip("%s · %s" % [r.name, said], 15, col, true))
	head.add_child(v)
	c.add(head)
	var bars = Kit.hbox(4)
	for i in range(Standards.LEVELS.size()):
		var seg = Kit.bar(1.0 if i < int(r.level) else (float(r.progress) if i == int(r.level) + 1 else (1.0 if i == int(r.level) else 0.0)), Color(Standards.COLORS[i]), 8)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.tooltip_text = Standards.LEVELS[i]
		bars.add_child(seg)
	c.add(bars)
	if float(r.next) > 0.0:
		var need = ""
		if r.kind == "ratio":
			need = "%s at %.2f× (%s one-rep max)" % [Standards.LEVELS[int(r.level) + 1], float(r.next), Fmt.fmt_weight(float(r.next) * bw, wu)]
		else:
			need = "%s at %d reps in a set" % [Standards.LEVELS[int(r.level) + 1], int(r.next)]
		c.add(Kit.label(need, 12, Pal.MUTED))
	c.tooltip_text = "General standards for men, from your best estimated one-rep max and your latest weigh-in"
	return c


## A lift stuck for its last sessions: how long, and three ways out.
static func _stuck_card(stuck: Dictionary, history: Array, lift_name: String, wu: String) -> Card:
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.DANGER)
	c.add(Kit.label("STUCK? · %d SESSIONS WITHOUT A NEW BEST" % int(stuck.days), 10, Pal.DANGER, true))
	c.add(Kit.para("Your best was on %s. Plateaus are normal; one of these usually gets it moving:" % _day_text(str(stuck.best_date)), 12, Pal.MUTED))
	for f in LiftTrend.plateau_fixes(history, lift_name, wu):
		var r = Kit.hbox(8)
		r.add_child(Kit.vcenter(Icons.rect("target", 16)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.label(str(f.title), 13, null, true))
		v.add_child(Kit.para(str(f.text), 12, Pal.MUTED))
		r.add_child(v)
		c.add(r)
	return c


static func _ghost_value(v: float, mode: String, wu: String) -> String:
	if mode == "sec":
		return "%d s hold" % int(v)
	if mode == "kg":
		return "%s strength (1-rep estimate)" % Fmt.fmt_weight(v, wu)
	return "%d reps in a set" % int(v)


## Something to aim for next time, as a quest.
static func _next_card(cur: Dictionary, mode: String, wu: String):
	var step = 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)
	var t = LiftTrend.next_target(cur.sets, step)
	if str(t.kind) == "none":
		return null
	var c = Kit.card(6, Callable(), 12)
	c.accent(Pal.SECOND)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("target", 18)))
	head.add_child(Kit.vcenter(PixelFont.rect("NEXT TIME", 2, Pal.SECOND)))
	c.add(head)
	c.add(Kit.para(LiftHistory.describe_sets(t.sets, _fmt_w(wu)), 16, Pal.TEXT, true))
	if Bands.top(t.sets) != "":
		# The band to use, in its own colour.
		var bp = BandPicker.pill(Bands.top(t.sets), 12)
		bp.set_meta("next_band", Bands.top(t.sets))
		c.add(bp)
	# Reps logged as both sides added up (Sides): what that is for one side.
	var both = int(t.get("sides", 1)) > 1
	if both and Sides.side_words(LiftTrend.real_sets(t.sets)) != "":
		var sw = Kit.para("Both sides added up: %s." % Sides.side_words(LiftTrend.real_sets(t.sets)), 12, Pal.LIFT, true)
		sw.set_meta("sides_words", true)
		c.add(sw)
	var why = ""
	match str(t.kind):
		"weight":
			if bool(t.get("heavier", false)) and both:
				why = "Every set at %s went past %d reps a side: too light to build much. Add %s and come down to %d reps, %d a side." % [Fmt.fmt_weight(float(t.kg), wu), LiftTrend.HIGH_REPS, Fmt.fmt_weight(float(t.addKg), wu), int(t.reps), LiftTrend.DOWN_TO]
			elif bool(t.get("heavier", false)):
				why = "Every set at %s went past %d reps: too light to build much. Add %s and come down to %d reps." % [Fmt.fmt_weight(float(t.kg), wu), LiftTrend.HIGH_REPS, Fmt.fmt_weight(float(t.addKg), wu), int(t.reps)]
			else:
				why = "Every set at %s got %d reps: add %s." % [Fmt.fmt_weight(float(t.kg), wu), int(t.reps), Fmt.fmt_weight(float(t.addKg), wu)]
		"reps":
			if float(t.kg) > 0.0:
				why = "One more rep on set %d: %d reps at %s." % [int(t.set), int(t.reps), Fmt.fmt_weight(float(t.kg), wu)]
			elif str(t.get("band", "")) != "":
				why = "One more rep on set %d: %d reps with the %s." % [int(t.set), int(t.reps), Bands.words(t.band)]
			else:
				why = "One more rep on set %d: %d reps." % [int(t.set), int(t.reps)]
		"hold":
			why = "Hold each one %d seconds longer." % int(t.addSec)
		"band":
			# Every set with the band got its reps: the next band up, fewer reps.
			var each = " a side" if both else ""
			why = "Every set with the %s got %d reps%s: move up to the %s and come back to %d reps%s." % [Bands.words(t.band), LiftTrend.BAND_HIGH_REPS, each, Bands.words(t.toBand), LiftTrend.BAND_DOWN_TO, each]
	c.add(Kit.para(why, 12, Pal.MUTED))
	return c


# ---------------------------------------------------------------------------
# Progress
# ---------------------------------------------------------------------------

static func metric_options(mode: String) -> Array:
	match mode:
		"kg":
			return [{"value": "weight", "label": "Top set"}, {"value": "e1rm", "label": "Est. 1RM"}, {"value": "reps", "label": "Reps"}, {"value": "volume", "label": "Moved"}]
		"sec":
			return [{"value": "hold", "label": "Hold"}, {"value": "reps", "label": "Reps"}]
		"band":
			return [{"value": "band", "label": "Band"}, {"value": "reps", "label": "Reps"}]
	return [{"value": "best", "label": "Best set"}, {"value": "reps", "label": "Reps in all"}]


## A number of the chart with its unit: "52.5 lb", "3.4k lb", "30 s", "68",
## "Green" (a band's level on the ladder).
static func metric_text(metric: String, v: float, wu: String) -> String:
	match metric:
		"weight", "e1rm":
			return "%s %s" % [TTUtil.num_str(snappedf(v, 0.1)), wu]
		"volume":
			return "%s %s" % [Charts.fmt_k(v), wu]
		"hold":
			return "%d s" % TTUtil.jsround(v)
		"band":
			var lv = TTUtil.jsround(v)
			return Bands.name_of(Bands.LADDER[lv - 1]) if lv >= 1 and lv <= Bands.LADDER.size() else ""
	return str(TTUtil.jsround(v))


const RANGES = [{"id": "1m", "label": "1M", "days": 31}, {"id": "3m", "label": "3M", "days": 92}, {"id": "1y", "label": "1Y", "days": 366}, {"id": "all", "label": "All", "days": 0}]
const METRIC_WORDS = {"weight": "Heaviest set of each day", "e1rm": "Estimated strength: the one-rep max worked out from your best set",
	"reps": "Every rep of each day", "volume": "Weight × reps of each day", "hold": "Longest hold of each day", "best": "Most reps in one set of each day",
	"band": "Heaviest band of each day"}


static func progress(holder: Control, ctx: Dictionary) -> void:
	var wu = str(ctx.wu)
	var history = ctx.history
	var mode = mode_of(history)
	var options = metric_options(mode)
	var metric = str(ctx.get("metric", options[0].value))
	if not options.any(func(o): return o.value == metric):
		metric = str(options[0].value)
	var picker = Kit.segmented(options, metric, LiftViews._set_metric.bind(ctx), Pal.LIFT)
	holder.add_child(picker)
	# Every day of the lift as a point, its sets in the tooltip and its work as a bar.
	var sets_of = {}
	var note_day = ""
	for h in history:
		var d = str(h.date)
		if not sets_of.has(d):
			sets_of[d] = []
		sets_of[d].append_array(h.get("sets", []))
		if bool(h.get("note", false)):
			note_day = d
	var points = []
	for row in LiftTrend.by_day(history):
		var y = 0.0
		match metric:
			"weight":
				y = Fmt.kg_to_unit(float(row.topKg), wu)
			"e1rm":
				y = Fmt.kg_to_unit(float(row.e1rm), wu)
			"volume":
				y = Fmt.kg_to_unit(float(row.volumeKg), wu)
			"hold":
				y = float(row.holdSec)
			"best":
				y = float(row.bestReps)
			"band":
				y = float(row.get("band", 0))
			_:
				y = float(row.reps)
		if y <= 0.0 and metric != "reps":
			continue
		var bar = Fmt.kg_to_unit(float(row.volumeKg), wu) if mode == "kg" else (float(row.holdTotal) if mode == "sec" else float(row.reps))
		var pt = {"x": row.date, "y": y, "bar": bar, "tip": LiftHistory.describe_sets(sets_of.get(row.date, []), _fmt_w(wu)), "note": row.date == note_day}
		if metric == "band":
			# Each day's point in the colour of its band.
			pt["dot"] = Bands.color_of(row.get("bandId", ""))
		points.append(pt)
	if points.is_empty():
		holder.add_child(Kit.para("Nothing to chart here yet.", 12, Pal.MUTED))
		return
	# The range: only the choices that show less than everything.
	var span = Dates.days_between(str(points[0].x), App.today)
	var range_id = str(ctx.get("range", "all"))
	var chips = Kit.hbox(6)
	for r in RANGES:
		if int(r.days) > 0 and int(r.days) >= span:
			continue
		chips.add_child(LogWidgets.mini_chip(str(r.label), str(r.id) == range_id, LiftViews._set_range.bind(str(r.id), ctx), Pal.LIFT))
	var days = 0
	for r in RANGES:
		if str(r.id) == range_id:
			days = int(r.days)
	var all_records = LiftTrend.record_points(points)
	var record_days = {}
	for i in all_records:
		record_days[str(points[i].x)] = true
	var shown = LiftTrend.since(points, App.today, days)
	if shown.is_empty():
		shown = points
	var marks = []
	for i in range(shown.size()):
		if record_days.has(str(shown[i].x)):
			marks.append(i)

	# The headline: how much it moved in the range.
	var head = Kit.hbox(10)
	var ch = LiftTrend.change(shown)
	if ch.is_empty():
		head.add_child(Kit.vcenter(Kit.tag("First day", Pal.SECOND, false, 12)))
		head.add_child(Kit.vcenter(Kit.clip("The line starts with the next one.", 12, Pal.MUTED)))
	else:
		var delta = float(ch.delta)
		var up = delta > 0.0
		var flat = absf(delta) < 0.05
		var said = metric_text(metric, absf(delta), wu)
		if metric == "band":
			# A change of band is counted in bands: "2 bands".
			said = SessionView.band_change(maxi(1, absi(TTUtil.jsround(delta)))).substr(1)
		var parts = JourneyScreen.split_unit(said)
		var col = Pal.GOOD if up else Pal.ACCENT2
		var num = Kit.hbox(4)
		if flat:
			num.add_child(Kit.vcenter(Kit.tag("Level", Pal.PANEL2, false, 13)))
		else:
			num.add_child(Kit.vcenter(Icons.rect("arrow_up" if up else "arrow_down", 16, col)))
			num.add_child(Kit.vcenter(PixelFont.rect(("+" if up else "-") + str(parts[0]), 3, col)))
			if str(parts[1]) != "" and str(parts[1]) != str(parts[0]):
				num.add_child(Kit.vcenter(Kit.label(str(parts[1]), 12, Pal.MUTED, true)))
		head.add_child(num)
		var words = Kit.vbox(1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Kit.clip("since %s" % Dates.format_date(str(shown[0].x)), 12, Pal.TEXT, true))
		var sub = "%d sessions" % int(ch.n)
		if int(ch.days) >= 28 and not flat and (metric == "weight" or metric == "e1rm" or metric == "hold"):
			var per_month = delta / (float(ch.days) / 30.0)
			sub += " · about %s%s a month" % ["+" if per_month > 0.0 else "-", metric_text(metric, absf(per_month), wu)]
		words.add_child(Kit.clip(sub, 11, Pal.MUTED))
		head.add_child(words)
	holder.add_child(head)

	var c = Kit.card(6, Callable(), 10)
	if chips.get_child_count() > 1:
		var top = Kit.hbox(6)
		top.add_child(Kit.vcenter(Kit.label("Show", 12, Pal.MUTED, true)))
		top.add_child(chips)
		c.add(top)
	else:
		chips.queue_free()
	var chart = ProgressChart.new()
	var bar_word = "moved" if mode == "kg" else ("held in all" if mode == "sec" else "reps in all")
	var chart_opts = {"color": Pal.LIFT, "records": marks,
		"fmt": func(val): return LiftViews.metric_text(metric, float(val), wu),
		"bar_fmt": func(val): return ("%s %s" % [Fmt.fmt_big_kg(Fmt.unit_to_kg(float(val), wu), wu), bar_word]) if mode == "kg" else ("%d %s" % [TTUtil.jsround(float(val)), "s held" if mode == "sec" else "reps"])}
	if metric == "band":
		# The axis says the bands the line goes through, by name.
		var levels = []
		for p in shown:
			if not levels.has(int(p.y)):
				levels.append(int(p.y))
		levels.sort()
		if levels.size() > 4:
			levels = [levels[0], levels[int(levels.size() / 2.0)], levels[levels.size() - 1]]
		chart_opts["ticks"] = levels.map(func(lv): return float(lv))
	chart.setup(shown, chart_opts)
	chart.tooltip_text = METRIC_WORDS.get(metric, "")
	c.add(chart)
	var legend = [{"name": {"weight": "Top set", "e1rm": "Estimated 1-rep max", "volume": "Moved", "hold": "Longest hold", "best": "Best set", "band": "Heaviest band"}.get(metric, "Reps"), "color": Pal.LIFT},
		{"name": "Work that day", "color": Pal.with_alpha(Pal.MUTED, 0.6)}, {"name": "New best", "color": Pal.ACCENT}]
	if note_day != "":
		legend.append({"name": "Your note", "color": Pal.GOOD})
	c.add(Charts.legend(legend))
	# Said in words, not only in a tooltip (a phone shows none): this line is worked
	# out, it is not weight that was on the bar.
	# Reps logged as both sides added up (Sides): estimates and the ladder go
	# by one side.
	var both = int(ctx.get("sides", 1)) > 1
	if metric == "e1rm":
		c.add(Kit.para("An estimate: the single rep your best set of each day works out to%s. Not a lift you did; Top set shows those." % (", going by the reps of one side" if both else ""), 11, Pal.MUTED))
	elif both and (metric == "reps" or metric == "best"):
		c.add(Kit.para("Reps as you log them: both sides added up.", 11, Pal.MUTED))
	holder.add_child(c)

	if ctx.st != null:
		var side_e1rm = -1.0
		if both:
			side_e1rm = 0.0
			for h in history:
				if not bool(h.get("note", false)):
					side_e1rm = maxf(side_e1rm, float(LiftTrend.day(h.get("sets", [])).e1rm))
		JourneyLifts._records(holder, ctx.st, wu, side_e1rm)
	if mode == "kg":
		var steps = LiftTrend.rep_ladder(history)
		if steps.size() >= 2:
			var lt = Kit.section_title("Best for reps a side" if both else "Best for reps")
			lt.set_meta("ladder_title", "side" if both else "set")
			holder.add_child(lt)
			var lad = RepLadder.new()
			lad.setup(steps, _fmt_w(wu), Pal.LIFT)
			lad.tooltip_text = "The heaviest weight you did for at least that many reps"
			holder.add_child(lad)


static func _set_metric(metric, ctx: Dictionary) -> void:
	ctx["metric"] = str(metric)
	show_view("progress", ctx)


static func _set_range(range_id: String, ctx: Dictionary) -> void:
	if str(ctx.get("range", "all")) == range_id:
		return
	Sfx.tick()
	ctx["range"] = range_id
	show_view("progress", ctx)


# ---------------------------------------------------------------------------
# Logbook
# ---------------------------------------------------------------------------

static func logbook(holder: Control, ctx: Dictionary) -> void:
	var wu = str(ctx.wu)
	var history = ctx.history
	var mode = mode_of(history)
	var first_day = str(history[history.size() - 1].date) if not history.is_empty() else App.today
	var n_weeks = clampi(int(ceil(Dates.days_between(Dates.week_key(first_day), App.today) / 7.0)) + 3, MIN_WEEKS, CAL_WEEKS)
	var cells = LiftTrend.calendar(history, App.today, n_weeks)
	var done = 0
	for cell in cells:
		if int(cell.level) > 0:
			done += 1
	var weeks = LiftTrend.per_week(history, App.today, n_weeks)
	var last_day = str(history[0].date) if not history.is_empty() else ""
	var c = Kit.card(6, Callable(), 10)
	var head = Kit.hbox(10)
	head.add_child(Kit.vcenter(PixelFont.rect(str(done), 3, Pal.LIFT)))
	var words = Kit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Kit.clip("day%s in the last %d weeks" % ["" if done == 1 else "s", n_weeks], 13, Pal.TEXT, true))
	var last_text = Dates.relative_day(last_day, App.today) if last_day != "" else "never"
	if last_day != "" and Dates.days_between(last_day, App.today) <= 1:
		last_text = last_text.to_lower()
	words.add_child(Kit.clip("last %s" % last_text, 11, Pal.MUTED))
	head.add_child(words)
	head.add_child(Kit.vcenter(Kit.tag("%s a week" % Fmt.to_fixed(LiftTrend.weekly_rate(weeks), 1), Pal.LIFT, true, 12)))
	c.add(head)
	var cal = LiftCalendar.new()
	cal.setup(cells, n_weeks, Pal.LIFT, App.today)
	c.add(cal)
	var key = Kit.hbox(4)
	key.add_child(Kit.vcenter(Kit.label("Less", 10, Pal.MUTED, true)))
	for lv in range(1, 5):
		key.add_child(Kit.vcenter(_swatch(cal._shade(lv))))
	key.add_child(Kit.vcenter(Kit.label("More", 10, Pal.MUTED, true)))
	key.add_child(Kit.spacer())
	var ring = PanelContainer.new()
	ring.add_theme_stylebox_override("panel", Kit.sbox(Pal.WELL, 0, Pal.ACCENT, 2, 0, 0))
	ring.custom_minimum_size = Vector2(12, 12)
	key.add_child(Kit.vcenter(ring))
	key.add_child(Kit.vcenter(Kit.label("New best", 10, Pal.MUTED, true)))
	c.add(key)
	holder.add_child(c)
	if int(ctx.get("goal", 0)) > 0:
		var g = Kit.card(6, Callable(), 10)
		g.accent(Pal.PT)
		g.add(Kit.clip("Physical therapy: %d sets a week" % (int(ctx.goal) * Pt.SETS_A_DAY), 13, Pal.TEXT, true))
		var bars = WeekBars.new()
		# (in sets, as the PT sheet counts them: a day counts up to Pt.SETS_A_DAY)
		var pt_row = Pt.row_of(App.sessions(), App.pt(), str(ctx.lift), App.today)
		if pt_row != null:
			bars.setup(pt_row.weeks, Pal.PT, int(pt_row.setsGoal), "set")
		else:
			bars.setup(LiftTrend.per_week(history, App.today, 8), Pal.PT, int(ctx.goal))
		g.add(bars)
		holder.add_child(g)

	# Every session, newest first, month by month.
	var top = 0.0
	for h in history:
		for one in LiftTrend.real_sets(h.get("sets", [])):
			if mode == "band":
				# A band: the block is as tall as its band against the heaviest one.
				top = maxf(top, float(Bands.level(one.get("band", ""))))
				continue
			top = maxf(top, float(one.get("holdSec", 0)) if mode == "sec" else (float(one.get("weightKg", 0)) if mode == "kg" else float(one.reps)))
	var shown = history.size() if bool(ctx.get("all", false)) else mini(LOGBOOK_SHOWN, history.size())
	var month = ""
	for i in range(shown):
		var h = history[i]
		var m = str(h.date).substr(0, 7)
		if m != month:
			month = m
			var n = history.filter(func(x): return str(x.date).substr(0, 7) == m).size()
			holder.add_child(Kit.section_title(Dates.format_date(str(h.date), {"month": "long", "year": "numeric"}), Kit.label("%d session%s" % [n, "" if n == 1 else "s"], 11, Pal.MUTED, true)))
		holder.add_child(_log_row(h, history.slice(i + 1), top, mode, wu, ctx))
	if history.size() > shown:
		var more = Kit.button("Show all %d sessions" % history.size(), "ghost", LiftViews._show_all.bind(ctx), "md", "chevron_down")
		more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(more)


static func _swatch(col: Color) -> Control:
	var r = ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(12, 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _show_all(ctx: Dictionary) -> void:
	Sfx.tap()
	ctx["all"] = true
	show_view("logbook", ctx)


## One session in the logbook: the day, its sets as blocks, and how it went.
static func _log_row(h: Dictionary, older: Array, top: float, mode: String, wu: String, ctx: Dictionary) -> Card:
	var note = bool(h.get("note", false))
	var c = Kit.card(0, Callable() if note else JourneyLifts._open_session.bind(ctx.sheet, h.id), 8)
	if note:
		c.accent(Pal.GOOD)
	else:
		c.tooltip_text = "Everything you did that day"
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var date = Kit.vbox(0)
	date.custom_minimum_size.x = 38
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dn = PixelFont.rect(str(int(str(h.date).substr(8, 2))), 2, Pal.GOOD if note else Pal.TEXT)
	dn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	date.add_child(dn)
	var wd = Kit.label(Dates.format_date(str(h.date), {"weekday": "short"}).to_upper(), 10, Pal.MUTED, true)
	wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date.add_child(wd)
	row.add_child(Kit.vcenter(date))
	var blocks = SetBlocks.new()
	blocks.setup(h.sets, top, Pal.GOOD if note else Pal.LIFT, mode, _fmt_w(wu))
	row.add_child(Kit.vcenter(blocks))
	row.add_child(Kit.spacer())
	var right = Kit.vbox(3)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tag = SessionView.compare_tag(LiftTrend.compare(h.sets, older), wu)
	if tag != null:
		tag.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(tag)
	var mt = main_text(LiftTrend.day(h.sets), mode, wu)
	var top_l = Kit.label("%s %s" % [str(mt[0]), str(mt[1]).get_slice(" · ", 0)], 12, Pal.TEXT, true)
	top_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(top_l)
	if note:
		var nl = Kit.label("In your note", 10, Pal.GOOD, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(nl)
	row.add_child(right)
	c.add(row)
	return c
