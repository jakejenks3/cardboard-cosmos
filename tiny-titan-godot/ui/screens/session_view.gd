class_name SessionView
extends RefCounted
## "What you did": a session shown piece by piece instead of as one line.
##
##   SessionView.lift_rows(data, opts)   one row per exercise: its name, its sets
##                                       and how they compare with the time before;
##                                       a click opens the lift's page (trends, history)
##   SessionView.open(session)           the detail sheet of a logged session
##                                       (Journey -> Log and the Hero tab's recent list)
##
## The phone note's review sheet uses `lift_rows` too, for a lift entry that is
## not in the log yet (`opts.pending`): the lift's page then shows those sets
## on top of the history they will join.

## A physical therapy lift's small badge.
static func pt_tag(size: int = 10) -> Control:
	return Kit.tag("PT", Pal.PT, true, size)


## A lift's variation beside its movement: "Barbell", "Single arm". `soft`: for a
## Kit.squeeze row, where a long one ("Single leg balance pad") is cut off with
## "…" when the row has no room for it.
static func variation_tag(variation: String, size: int = 10, soft: bool = false) -> Control:
	var t = Kit.tag(variation, Pal.PANEL2, false, size)
	t.tooltip_text = variation
	if soft:
		var l = t.get_child(0) as Label
		var want = ceilf(Kit.font_bold().get_string_size(variation, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) + 1.0 + 16.0
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		SqueezeRow.soften(t, want, 40.0)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## The sessions a session is compared with: everything logged before it.
## `skip_id`: a session it replaces (an edited day of the phone note).
static func _before(data: Dictionary, skip_id = null) -> Array:
	var date = str(data.get("date", ""))
	var made = data.get("createdAt")
	var own_id = data.get("id")
	var out = []
	for s in App.sessions():
		if (skip_id != null and s.id == skip_id) or (own_id != null and s.id == own_id):
			continue
		if str(s.date) < date or (str(s.date) == date and (made == null or int(s.createdAt) < int(made))):
			out.append(s)
	return out


## "+2.5 lb", "-4 reps", "+1 band": a change with its sign.
static func delta_text(cmp: Dictionary, wu: String) -> String:
	if absf(float(cmp.get("kg", 0.0))) > 1e-6:
		return "%s%s" % ["+" if float(cmp.kg) > 0.0 else "-", Fmt.fmt_weight(absf(float(cmp.kg)), wu)]
	if int(cmp.get("sec", 0)) != 0:
		return "%s%d s" % ["+" if int(cmp.sec) > 0 else "-", absi(int(cmp.sec))]
	if int(cmp.get("band", 0)) != 0:
		return band_change(int(cmp.band))
	var r = int(cmp.get("reps", 0))
	if r != 0:
		return "%s%d rep%s" % ["+" if r > 0 else "-", absi(r), "" if absi(r) == 1 else "s"]
	return ""


## A change of resistance band in steps of the ladder: "+1 band", "-2 bands".
static func band_change(d: int) -> String:
	return "%s%d band%s" % ["+" if d > 0 else "-", absi(d), "" if absi(d) == 1 else "s"]


## How a session's sets compare with the time before (LiftTrend.compare), as a
## small coloured tag: NEW, PR, +2.5 lb, -4 reps, same. Null when there is
## nothing to say. `size`: the font size (the top of a lift's page uses 12).
static func compare_tag(cmp: Dictionary, wu: String, size: int = 10):
	var change = delta_text(cmp, wu)
	match str(cmp.get("kind", "none")):
		"first":
			return Kit.tag("NEW", Pal.SECOND, false, size)
		"up":
			if bool(cmp.get("pr", false)):
				return Kit.tag(("PR " + change).strip_edges(), Pal.ACCENT, true, size)
			return Kit.tag(change, Pal.GOOD, true, size)
		"down":
			if bool(cmp.get("pr", false)):
				return Kit.tag("PR", Pal.ACCENT, true, size)
			return Kit.tag(change, Pal.ACCENT2, true, size)
		"same":
			return Kit.tag("same as last time" if size > 10 else "same", Pal.PANEL2, false, size)
	return null


## The real sets of an exercise as {reps, weightKg}.
static func done_sets(ex: Dictionary) -> Array:
	var out = []
	for one in ex.get("sets", []):
		if int(one.get("reps", 0)) > 0:
			var kept = {"reps": int(one.reps), "weightKg": float(one.get("weightKg", 0))}
			if int(one.get("holdSec", 0)) > 0:
				kept["holdSec"] = int(one.holdSec)
			if Bands.is_band(one):
				kept["band"] = str(one.band).strip_edges().to_lower()
			out.append(kept)
	return out


## One row per exercise of a lift session. opts: "pending" (true: the session
## is not in the log yet), "skip_id" (a session it replaces).
static func lift_rows(data: Dictionary, opts: Dictionary = {}) -> Control:
	var wu = App.weight_unit()
	# Each lift is compared with the same movement AND variation done before.
	var history_of = {}
	var all = LiftLibrary.stats(_before(data, opts.get("skip_id")))
	for k in all:
		history_of[str(k)] = all[k].history
	var marks = App.pt()
	var box = Kit.vbox(4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for ex in data.get("exercises", []):
		var sets = done_sets(ex)
		if sets.is_empty():
			continue
		var lift = str(ex.get("name", ""))
		var hist = history_of.get(Xp.normalize_exercise(lift), [])
		var cmp = LiftTrend.compare(sets, hist)
		var page = {"skip_id": opts.get("skip_id"), "view": "compare"}
		if bool(opts.get("pending", false)):
			page["pending"] = {"date": str(data.get("date", "")), "sets": sets, "pt": bool(ex.get("pt", false))}
		elif data.get("id") != null:
			page["session_id"] = data.id
		# The last few times it was done, and this time, as small bars.
		var spark = []
		if not hist.is_empty():
			var days = LiftTrend.by_day(hist)
			# (a band lift: its days from before bands below its band days)
			var in_band = LiftTrend.banded(hist) or LiftTrend.banded([{"sets": sets}])
			for d in days.slice(maxi(0, days.size() - 7)):
				spark.append(LiftTrend.main_value(d, in_band))
			spark.append(LiftTrend.main_value(LiftTrend.day(sets), in_band))
		box.add_child(_lift_row(lift, sets, cmp, bool(ex.get("pt", false)) or Pt.is_pt(marks, lift), wu, page, spark))
	return box


static func _lift_row(lift: String, sets: Array, cmp: Dictionary, pt: bool, wu: String, page: Dictionary, spark: Array = []) -> Card:
	var c = Kit.card(0, JourneyLifts.open_named.bind(lift, page), 7)
	c.tooltip_text = "Trends and history of %s" % lift
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words = Kit.vbox(0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top = Kit.squeeze(6)
	var sp = LiftNames.split(lift)
	top.add_child(Kit.soft_name(str(sp.move), 13, null, true, 210.0))
	if str(sp.variation) != "":
		top.add_child(variation_tag(str(sp.variation), 10, true))
	if pt:
		top.add_child(Kit.vcenter(pt_tag()))
	words.add_child(top)
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var said = Kit.clip(LiftHistory.describe_sets(sets, fmt_w), 12, Pal.MUTED)
	if Bands.top(sets) != "":
		# Done with a band: a square of its colour before the sets.
		var line = Kit.hbox(5)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(BandPicker.swatch(Bands.top(sets), 10))
		line.add_child(said)
		line.set_meta("band_sets", Bands.top(sets))
		words.add_child(line)
	else:
		words.add_child(said)
	row.add_child(words)
	if spark.size() >= 2:
		var bars = SparkBars.new()
		var lit = Pal.ACCENT if bool(cmp.get("pr", false)) else (Pal.GOOD if page.has("pending") else Pal.LIFT)
		bars.setup(spark, lit)
		row.add_child(Kit.vcenter(bars))
	var tag = compare_tag(cmp, wu)
	if tag != null:
		row.add_child(Kit.vcenter(tag))
	var go = Icons.rect("chevron_right", 16)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(go))
	c.add(row)
	return c


## The detail sheet of a logged session: everything in it, the XP it earned,
## and an Edit key. A lift session lists its exercises (`lift_rows`).
static func open(session: Dictionary) -> void:
	Sfx.tap()
	var d = str(session.discipline)
	var wu = App.weight_unit()
	var du = App.distance_unit()
	var title = session.get("title")
	if title == null or str(title) == "":
		title = Misc.title(session) if Misc.is_misc(session) else TT.DISCIPLINE_META[d].name
	var sheet = Kit.sheet(Icons.strip_emoji(title))
	var box = sheet.box

	var head = Kit.hbox(10)
	head.add_child(Parts.session_badge(session, 38))
	var when = Kit.vbox(1)
	when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	when.add_child(Kit.clip(Dates.format_date(session.date, {"weekday": "long", "month": "short", "day": "numeric"}), 15, null, true))
	var sub = Summary.summarize_session(session, App.settings())
	if sub != "":
		when.add_child(Kit.clip(sub, 12, Pal.MUTED))
	head.add_child(when)
	head.add_child(Kit.vcenter(Parts.xp_chip(int(App.state.sessionXp.get(session.id, 0)), 13)))
	box.add_child(head)

	if d == "lift":
		box.add_child(lift_rows(session))
	else:
		# Every piece of the session as its own chip: "V4 flash x2", "5.2 km", "27:30".
		var bits = Kit.flow(6)
		for piece in QuickLog.summary("session", session, wu, du).split(" · ", false):
			bits.add_child(Kit.icon_chip("", str(piece), Pal.PANEL2, "", Pal.TEXT))
		if bits.get_child_count() > 0:
			box.add_child(bits)
		else:
			bits.queue_free()
		# A run's best splits (game/run_splits.gd).
		var split_list = RunSplits.rows(session)
		if not split_list.is_empty():
			box.add_child(split_rows(split_list, session, du))

	var notes = str(session.get("notes", "")).strip_edges() if session.get("notes") != null else ""
	if notes != "":
		var nc = PanelContainer.new()
		nc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		nc.add_theme_stylebox_override("panel", PixBox.well(10, 8))
		nc.add_child(Kit.para(Icons.strip_emoji(notes), 13, Pal.TEXT))
		box.add_child(nc)

	# Where the XP came from.
	var earned = Xp.base_session_xp(session)
	var parts = Kit.flow(6)
	for p in earned.get("parts", []):
		# The rules count in kg and km; the player may think in pounds and miles.
		var label = Units.xp_label(session, Icons.strip_emoji(str(p.label)), App.settings())
		parts.add_child(Kit.icon_chip("", "%s  +%s" % [label, Xp.fmt_int(p.xp)], Pal.deep(Pal.ACCENT), "", Pal.TEXT))
	if parts.get_child_count() > 0:
		box.add_child(parts)
	else:
		parts.queue_free()

	var keys = Kit.hbox(8)
	var edit = Kit.button("Edit", "primary", SessionView._edit.bind(sheet, session), "lg", "edit")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_child(edit)
	keys.add_child(Kit.button("Close", "ghost", sheet.close, "lg"))
	box.add_child(keys)
	sheet.open()


## A run's best splits: a line each (the distance, its time, its pace), the
## run itself among them when it is one of the distances, and a gold tag on
## the ones that are the player's best over that distance.
static func split_rows(list: Array, session: Dictionary, du: String) -> Control:
	var bests = RunSplits.bests(App.sessions())
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.well(10, 8))
	p.set_meta("split_rows", true)
	var v = Kit.vbox(4)
	v.add_child(Kit.label("BEST SPLITS IN THIS RUN", 10, Pal.RUN, true))
	for r in list:
		var h = Kit.hbox(8)
		var nm = Kit.clip(str(r.name) + (" (the run)" if bool(r.whole) else ""), 13, Pal.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var best = bests.get(str(r.id))
		if best != null and str(best.sessionId) == str(session.get("id", "")):
			h.add_child(Kit.vcenter(Kit.tag("BEST", Pal.ACCENT, true, 10)))
		h.add_child(Kit.vcenter(Kit.label(RunSplits.fmt_time(int(r.sec)), 14, Pal.RUN, true)))
		var pc = Kit.label(Fmt.fmt_pace(float(r.pace), du), 11, Pal.MUTED)
		pc.custom_minimum_size = Vector2(74, 0)
		pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(Kit.vcenter(pc))
		v.add_child(h)
	p.add_child(v)
	return p


static func _edit(sheet: Sheet, session: Dictionary) -> void:
	Sfx.tap()
	sheet.close()
	App.open_log(session.discipline, session.id)
