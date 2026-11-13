class_name JourneyScreen
extends UiScreen
## Journey: "how far you've come" (port of screens/Journey.tsx). Four sub-tabs:
## Stats (then vs now, charts, records, fun facts), Body (JourneyBody), Story
## (the dated chronicle) and Log (every session, tap to edit).

const LEVEL_ONE = {"hero": 1, "lift": 1, "climb": 1, "run": 1, "ride": 1}
const THEN_LOADOUT = {"body": "tee_grey", "legs": "shorts_navy", "feet": "trainers_worn"}

const CHRONICLE_FILTERS = [
	{"id": "all", "label": "Everything", "kinds": null},
	{"id": "level", "label": "Levels", "kinds": ["start", "level", "stage", "rank"]},
	{"id": "boss", "label": "Bosses", "kinds": ["boss"]},
	{"id": "achievement", "label": "Trophies", "kinds": ["achievement"]},
	{"id": "loot", "label": "Loot", "kinds": ["item", "pet"]},
	{"id": "pr", "label": "Records", "kinds": ["pr"]},
	{"id": "body", "label": "Body", "kinds": ["body"]},
]

var _exercise = null
var _chron_filter = "all"
## Body sub-tab state (shared with JourneyBody): photo angle, chosen then / now check-ins.
var _body_state = {"angle": "front", "then": null, "now": null}


func build() -> void:
	add_child(Kit.h1("Journey"))
	add_child(Kit.sub_tabs([
		{"value": "stats", "label": "Stats"},
		{"value": "body", "label": "Body"},
		{"value": "chronicle", "label": "Story"},
		{"value": "history", "label": "Log"},
	], App.journey_tab, App.set_journey_tab))
	var no_sessions = App.sessions().is_empty()
	match App.journey_tab:
		"body":
			JourneyBody.build(self, _body_state, rebuild)
		"chronicle":
			_build_chronicle()
		"history":
			if no_sessions:
				add_child(_no_sessions())
			else:
				_build_history()
		_:
			if no_sessions:
				add_child(_no_sessions())
			else:
				_build_stats()


func _no_sessions() -> Control:
	return Kit.empty("map", "Your story starts with one session",
		"Charts, records and history appear here once you log something.",
		Kit.button("Log a workout", "primary", func(): App.open_log()))


static func title_case(s: String) -> String:
	var out = ""
	var prev_word = false
	for i in range(s.length()):
		var ch = s[i]
		var is_word = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_"
		out += ch.to_upper() if is_word and not prev_word else ch
		prev_word = is_word
	return out


static func _by_date_asc(a, b) -> bool:
	return a.date < b.date or (a.date == b.date and a.createdAt < b.createdAt)


func _section(text: String, icon: String = "") -> Control:
	var h = Kit.hbox(6)
	h.custom_minimum_size = Vector2(0, 26)
	if icon != "":
		var ic = Icons.rect(icon, 16)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l = Kit.h3(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _tiles(items: Array, cols: int = 3) -> GridContainer:
	var g = Kit.grid(cols, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		g.add_child(it)
	return g


func _small_head(text: String) -> Label:
	return Kit.label(text.to_upper(), 11, Pal.MUTED, true)


# ---------------------------------------------------------------------------
# Then vs now
# ---------------------------------------------------------------------------

func _then_now_facts(sessions: Array, s: Dictionary, wu: String, du: String) -> Array:
	var out = []
	var by_date = sessions.duplicate()
	TTUtil.stable_sort(by_date, _by_date_asc)
	var first_lift = {}
	var first_send = null
	var first_run = 0.0
	var first_ride = 0.0
	for x in by_date:
		if x.discipline == "lift":
			for ex in x.exercises:
				var nm = Xp.normalize_exercise(ex.name)
				var w = 0.0
				for st in ex.sets:
					w = maxf(w, float(st.weightKg))
				if nm != "" and w > 0.0 and not first_lift.has(nm):
					first_lift[nm] = w
		elif x.discipline == "climb":
			var stats = Xp.session_stats(x)
			if first_send == null and stats.get("maxGradeSent") != null:
				first_send = stats.maxGradeSent
		elif x.discipline == "run":
			if first_run == 0.0 and float(x.get("distanceM", 0)) > 0.0:
				first_run = float(x.distanceM)
		elif first_ride == 0.0 and float(x.get("distanceM", 0)) > 0.0:
			first_ride = float(x.distanceM)

	var lifts = []
	for nm in s.prs.lifts:
		var pr = s.prs.lifts[nm]
		if first_lift.has(nm) and float(pr.weightKg) > first_lift[nm]:
			lifts.append({"name": nm, "pr": pr, "ratio": float(pr.weightKg) / first_lift[nm]})
	TTUtil.stable_sort(lifts, func(a, b): return a.ratio > b.ratio)
	for l in lifts.slice(0, 2):
		out.append({"label": title_case(l.name), "then": Fmt.fmt_weight(first_lift[l.name], wu), "now": Fmt.fmt_weight(l.pr.weightKg, wu)})
	var max_send = s.prs.climbMaxSend
	if first_send != null and max_send != null and max_send > first_send:
		out.append({"label": "Hardest send", "then": Xp.grade_label(first_send), "now": Xp.grade_label(max_send)})
	if first_run > 0.0 and float(s.prs.longestRunM) > first_run:
		out.append({"label": "Longest run", "then": Fmt.fmt_distance(first_run, du), "now": Fmt.fmt_distance(s.prs.longestRunM, du)})
	if first_ride > 0.0 and float(s.prs.longestRideM) > first_ride:
		out.append({"label": "Longest ride", "then": Fmt.fmt_distance(first_ride, du), "now": Fmt.fmt_distance(s.prs.longestRideM, du)})
	var b = s.body
	if b.firstWeightKg != null and b.latestWeightKg != null and b.firstWeightDate != b.latestWeightDate:
		out.append({"label": "Body weight", "then": Fmt.fmt_weight(b.firstWeightKg, wu), "now": Fmt.fmt_weight(b.latestWeightKg, wu)})
	return out.slice(0, 5)


func _hero_fig(tex: Texture2D, title: String, sub: String) -> Control:
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art = PixelRect.make(tex, 2.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var t = Kit.label(title, 14, null, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sl = Kit.muted(sub, 11)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	return v


func _then_now() -> void:
	var s = App.state
	if s.chronicle.is_empty():
		return
	var start = s.chronicle[0].date
	var days = Dates.days_between(start, App.today)
	var profile = App.profile()
	var card = Kit.card(10)
	card.tint(Color("2a2350"), Pal.ACCENT)
	var heroes = Kit.hbox(6)
	var then_tex = Art.hero_texture(Art.state_with_levels(s, LEVEL_ONE), profile, THEN_LOADOUT)
	heroes.add_child(_hero_fig(then_tex, "Day 1", Dates.format_date(start, {"month": "short", "day": "numeric", "year": "numeric"})))
	var mid = Kit.vbox(2)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var num = PixelFont.rect(str(days), 3, Pal.ACCENT)
	num.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(num)
	var dl = Kit.muted("day" if days == 1 else "days", 11)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(dl)
	var arrow = Kit.label("→", 26, Pal.ACCENT, true)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(arrow)
	heroes.add_child(mid)
	var now_tex = Art.hero_texture(s, profile, App.loadout())
	heroes.add_child(_hero_fig(now_tex, "Today", "Lv %d" % s.levels.hero.level))
	card.add(heroes)
	var facts = Kit.vbox(0)
	facts.add_child(_then_now_row("Hero level", "Lv 1", "Lv %d" % s.levels.hero.level))
	for f in _then_now_facts(App.sessions(), s, App.weight_unit(), App.distance_unit()):
		facts.add_child(_then_now_row(f.label, f.then, f.now))
	card.add(facts)
	add_child(card)


func _then_now_row(label_text: String, then_text: String, now_text: String) -> Control:
	var v = Kit.vbox(0)
	v.add_child(Kit.divider())
	var row = Kit.hbox(8)
	var a = Kit.clip(label_text, 13)
	a.size_flags_stretch_ratio = 1.3
	var b = Kit.clip(then_text, 13, Pal.MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var c = Kit.clip(now_text, 13, Pal.GOOD, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Kit.add(row, [a, b, c])
	v.add_child(Kit.pad(row, 0, 5, 0, 5))
	return v


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

func _pick_exercise(nm: String) -> void:
	_exercise = nm
	rebuild()


func _weekly_points(sessions: Array, s: Dictionary) -> Array:
	var this_week = Dates.week_key(App.today)
	var out = []
	var idx = {}
	for i in range(11, -1, -1):
		var wk = Dates.add_weeks(this_week, -i)
		idx[wk] = out.size()
		out.append({"week": wk, "byDiscipline": {"lift": 0, "climb": 0, "run": 0, "ride": 0}, "total": 0})
	for x in sessions:
		var wk = Dates.week_key(x.date)
		if not idx.has(wk):
			continue
		var xp = int(s.sessionXp.get(x.id, 0))
		out[idx[wk]].byDiscipline[x.discipline] += xp
		out[idx[wk]].total += xp
	return out


func _build_stats() -> void:
	var s = App.state
	var sessions = App.sessions()
	var t = s.totals
	var wu = App.weight_unit()
	var du = App.distance_unit()

	_then_now()

	add_child(_tiles([
		Kit.stat("Sessions", Xp.fmt_int(t.sessions)),
		Kit.stat("Active days", Xp.fmt_int(t.activeDays)),
		Kit.stat("Total XP", Xp.fmt_int(s.xp.hero), "", Pal.ACCENT),
		Kit.stat("Best streak", "%dw" % int(s.streak.best)),
		Kit.stat("Trophies", str(s.achievements.size())),
		Kit.stat("Time trained", Fmt.fmt_duration_short(t.durationSec)),
	]))

	add_child(_section("Weekly XP"))
	var wcard = Kit.card()
	wcard.add(Charts.weekly_xp(_weekly_points(sessions, s)))
	add_child(wcard)

	add_child(_section("Consistency"))
	var hcard = Kit.card()
	hcard.add(Charts.heatmap(s.xpByDate, App.today))
	add_child(hcard)

	var facts = FunFacts.fun_facts(s)
	if not facts.is_empty():
		add_child(_section("In perspective"))
		var fv = Kit.vbox(6)
		for f in facts:
			var fc = Kit.card(0, Callable(), 10)
			var row = Kit.hbox(12)
			var ic = Icons.rect(Icons.for_emoji(f.icon), 26)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ic)
			var txt = Kit.rich("[b]%s[/b] [color=%s]%s[/color]" % [Kit.esc(Icons.strip_emoji(f.headline)), Kit.hex_of(Pal.MUTED), Kit.esc(Icons.strip_emoji(f.detail))], 14)
			txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(txt)
			fc.add(row)
			fv.add_child(fc)
		add_child(fv)

	var by = t.byDiscipline
	if int(by.lift) > 0:
		_lift_section(s, sessions, wu)
	if int(by.climb) > 0:
		add_child(_section("Climbing", "climb"))
		var cc = Kit.card()
		var max_send = s.prs.climbMaxSend
		var max_flash = s.prs.climbMaxFlash
		cc.add(_tiles([
			Kit.stat("Sends", Xp.fmt_int(t.climbSends), "", Pal.CLIMB),
			Kit.stat("Flashes", Xp.fmt_int(t.climbFlashes)),
			Kit.stat("Max grade", Xp.grade_label(max_send) if max_send != null else "—", ("flash " + Xp.grade_label(max_flash)) if max_flash != null else ""),
		]))
		cc.add(_small_head("Send pyramid"))
		cc.add(Charts.pyramid(_grade_counts(sessions), int(max_send) if max_send != null else 3))
		cc.add(Kit.muted("Lighter segment = flashes", 11))
		add_child(cc)
	if int(by.run) > 0:
		add_child(_section("Running", "run"))
		var rc = Kit.card()
		var pace = s.prs.bestPaceSecPerKm
		rc.add(_tiles([
			Kit.stat("Distance", Fmt.fmt_distance(t.runDistanceM, du, 0), "", Pal.RUN),
			Kit.stat("Elevation", Fmt.fmt_elevation(t.runElevationM, du)),
			Kit.stat("Longest", Fmt.fmt_distance(s.prs.longestRunM, du), ("best " + Fmt.fmt_pace(pace, du)) if pace != null and float(pace) > 0.0 else ""),
		]))
		add_child(rc)
	if int(by.ride) > 0:
		add_child(_section("Cycling", "ride"))
		var bc = Kit.card()
		var spd = s.prs.bestRideSpeedKmh
		bc.add(_tiles([
			Kit.stat("Distance", Fmt.fmt_distance(t.rideDistanceM, du, 0), "", Pal.RIDE),
			Kit.stat("Elevation", Fmt.fmt_elevation(t.rideElevationM, du)),
			Kit.stat("Longest", Fmt.fmt_distance(s.prs.longestRideM, du), ("best " + Fmt.fmt_speed(spd, du)) if spd != null and float(spd) > 0.0 else ""),
		]))
		add_child(bc)


func _grade_counts(sessions: Array) -> Dictionary:
	var c = {}
	for x in sessions:
		if x.discipline != "climb":
			continue
		for cl in x.climbs:
			if cl.result == "attempt":
				continue
			var g = int(cl.grade)
			if not c.has(g):
				c[g] = {"sends": 0, "flashes": 0}
			if cl.result == "flash":
				c[g].flashes += int(cl.get("count", 1))
			else:
				c[g].sends += int(cl.get("count", 1))
	return c


func _lift_section(s: Dictionary, sessions: Array, wu: String) -> void:
	var t = s.totals
	add_child(_section("Lifting", "lift"))
	var card = Kit.card()
	card.add(_tiles([
		Kit.stat("Lifetime volume", Fmt.fmt_big_kg(t.liftVolumeKg, wu), "", Pal.LIFT),
		Kit.stat("Reps", Xp.fmt_int(t.liftReps)),
		Kit.stat("Sets", Xp.fmt_int(t.liftSets)),
	]))

	var lift_sessions = sessions.filter(func(x): return x.discipline == "lift")
	TTUtil.stable_sort(lift_sessions, _by_date_asc)
	var counts = {}
	for x in lift_sessions:
		for ex in x.exercises:
			if ex.sets.any(func(st): return float(st.weightKg) > 0.0):
				var nm = Xp.normalize_exercise(ex.name)
				counts[nm] = int(counts.get(nm, 0)) + 1
	var top = []
	for nm in counts:
		top.append({"name": nm, "n": counts[nm]})
	TTUtil.stable_sort(top, func(a, b): return a.n > b.n)
	top = top.slice(0, 6)
	var selected = null
	for e in top:
		if e.name == _exercise:
			selected = _exercise
	if selected == null and not top.is_empty():
		selected = top[0].name

	if not top.is_empty():
		card.add(_small_head("Strength progression (est. 1RM)"))
		var chips = Kit.flow(6)
		for e in top:
			chips.add_child(Kit.chip(title_case(e.name), e.name == selected, _pick_exercise.bind(e.name), Pal.LIFT))
		card.add(chips)
		var series = []
		for x in lift_sessions:
			var best = 0.0
			for ex in x.exercises:
				if Xp.normalize_exercise(ex.name) != selected:
					continue
				for st in ex.sets:
					if float(st.weightKg) > 0.0 and int(st.reps) > 0:
						best = maxf(best, Xp.e1rm(st.weightKg, st.reps))
			if best > 0.0:
				series.append({"x": x.date, "y": Fmt.kg_to_unit(best, wu)})
		if series.size() >= 2:
			card.add(Charts.line(series, Pal.LIFT, func(v): return "%d %s" % [TTUtil.jsround(v), wu]))
		else:
			card.add(Kit.muted_para("Log this lift in another session to see a trend line.", 12))

	var lifts = []
	for nm in s.prs.lifts:
		lifts.append({"name": nm, "pr": s.prs.lifts[nm]})
	TTUtil.stable_sort(lifts, func(a, b): return float(a.pr.e1rm) > float(b.pr.e1rm))
	lifts = lifts.slice(0, 5)
	if not lifts.is_empty():
		card.add(_small_head("Best lifts"))
		var tbl = Kit.vbox(0)
		for i in range(lifts.size()):
			var l = lifts[i]
			var row = Kit.hbox(8)
			row.add_child(Kit.clip(title_case(l.name), 14, null, true))
			row.add_child(Kit.label("%s × %d" % [Fmt.fmt_weight(l.pr.weightKg, wu), int(l.pr.reps)], 14, null, true))
			var e = Kit.muted("≈ " + Fmt.fmt_weight(l.pr.e1rm, wu, 0), 12)
			e.custom_minimum_size = Vector2(64, 0)
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(e)
			tbl.add_child(Kit.pad(row, 0, 4, 0, 4))
			if i < lifts.size() - 1:
				tbl.add_child(Kit.divider())
		card.add(tbl)
	add_child(card)


# ---------------------------------------------------------------------------
# Chronicle: the story so far
# ---------------------------------------------------------------------------

func _set_chron_filter(id: String) -> void:
	_chron_filter = id
	rebuild()


static func _month_label(key: String) -> String:
	var d = Dates.parse_date_key(key)
	return "%s %d" % [Dates.MONTHS_LONG[int(d.month) - 1], int(d.year)]


static func _moment_color(kind: String) -> Color:
	match kind:
		"boss":
			return Color("d7263d")
		"stage", "level", "start":
			return Pal.ACCENT
		"rank":
			return Color("c77dff")
		"pr":
			return Pal.GOOD
	return Pal.LINE


func _build_chronicle() -> void:
	var s = App.state
	var chron = s.chronicle
	if chron.is_empty():
		add_child(Kit.empty("book", "An empty page", "Your story writes itself as you train: every level, boss, trophy, record and piece of loot lands here with its date."))
		return
	var kinds = null
	for f in CHRONICLE_FILTERS:
		if f.id == _chron_filter:
			kinds = f.kinds
	var events = []
	for i in range(chron.size()):
		var e = chron[i]
		if kinds == null or kinds.has(e.kind):
			events.append({"e": e, "i": i})
	TTUtil.stable_sort(events, func(a, b): return a.e.date > b.e.date or (a.e.date == b.e.date and a.i > b.i))

	var start = chron[0].date
	var head = Kit.card(4)
	head.tint(Color("2a2350"))
	head.add(PixelFont.rect("DAY %d" % (Dates.days_between(start, App.today) + 1), 2, Pal.ACCENT))
	head.add(Kit.muted_para("Started %s · %d moments so far" % [Dates.format_date(start, {"month": "long", "day": "numeric", "year": "numeric"}), chron.size()], 13))
	add_child(head)

	var chips = Kit.flow(6)
	for f in CHRONICLE_FILTERS:
		chips.add_child(Kit.chip(f.label, f.id == _chron_filter, _set_chron_filter.bind(f.id)))
	add_child(chips)

	if events.is_empty():
		var c = Kit.card()
		var l = Kit.muted_para("Nothing here yet.", 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add(l)
		add_child(c)
		return

	var settings = App.settings()
	var month = ""
	var line = null
	for ev in events:
		var e = ev.e
		var m = _month_label(e.date)
		if m != month:
			month = m
			var ml = Kit.label(m.to_upper(), 13, Pal.MUTED, true)
			add_child(Kit.pad(ml, 0, 6, 0, 0))
			line = TimelineBox.new()
			line.add_theme_constant_override("separation", 6)
			add_child(line)
		line.add_child(_moment(e, settings))


func _moment(e: Dictionary, settings: Dictionary) -> Control:
	var row = Kit.hbox(10)
	var ic = PanelContainer.new()
	ic.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 18, _moment_color(e.kind), 2, 0, 0))
	ic.custom_minimum_size = Vector2(36, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_child(Kit.center(Icons.rect(Icons.for_emoji(e.get("icon", "")), 18)))
	row.add_child(Kit.pad(ic, 6, 0, 0, 0))
	var main = PanelContainer.new()
	main.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL, 10, Pal.LINE, 1, 10, 7))
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mv = Kit.vbox(2)
	var title = "[b]%s[/b]" % Kit.esc(Icons.strip_emoji(e.title))
	var val = e.get("val")
	if val != null:
		title += " [b][color=%s]%s[/color][/b]" % [Kit.hex_of(Pal.ACCENT), Kit.esc(Fmt.fmt_goal_value(val.n, val.unit, settings))]
	mv.add_child(Kit.rich(title, 14))
	var detail = e.get("detail")
	if detail != null and str(detail) != "":
		mv.add_child(Kit.muted_para(Icons.strip_emoji(detail), 12))
	main.add_child(mv)
	row.add_child(main)
	var d = Kit.muted(Dates.format_date(e.date), 11)
	d.custom_minimum_size = Vector2(46, 0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(d)
	return row


## A column of moments with the timeline's vertical rule behind the icons.
class TimelineBox extends VBoxContainer:
	func _init() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.y > 16.0:
			draw_rect(Rect2(23.0, 8.0, 2.0, size.y - 16.0), Pal.LINE)


# ---------------------------------------------------------------------------
# History: every session, newest first
# ---------------------------------------------------------------------------

func _build_history() -> void:
	var sorted = App.sessions().duplicate()
	TTUtil.stable_sort(sorted, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	var xp_of = App.state.sessionXp
	add_child(Kit.muted_para("Tap a session to edit it. Everything recalculates.", 13))
	var day = ""
	var list = null
	for x in sorted:
		if x.date != day:
			day = x.date
			var g = Kit.vbox(6)
			g.add_child(Kit.label(Dates.format_date_long(day), 13, Pal.MUTED, true))
			list = Kit.vbox(6)
			g.add_child(list)
			add_child(g)
		list.add_child(Parts.session_row(x, int(xp_of.get(x.id, 0))))
