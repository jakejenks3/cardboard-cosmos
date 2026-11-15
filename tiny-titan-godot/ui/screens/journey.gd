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
	return Kit.empty("map", "Your story starts here",
		"Log a session to fill this page.",
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


# ---------------------------------------------------------------------------
# Building blocks (static: JourneyBody uses them too)
# ---------------------------------------------------------------------------

## The largest pixel-font scale (at most `top`) at which every text fits `max_w` px.
static func fit_scale(texts: Array, max_w: float, top: int = 3) -> int:
	var sc = top
	for t in texts:
		while sc > 1 and PixelFont.measure(str(t)).x * sc > max_w:
			sc -= 1
	return sc


## "11.9 km" -> ["11.9", "km"]; text without a unit -> [text, ""].
static func split_unit(text: String) -> Array:
	var i = text.rfind(" ")
	if i <= 0:
		return [text, ""]
	return [text.substr(0, i), text.substr(i + 1)]


## A pixel-font number, centred in its column.
static func big_num(text: String, scale: int, color: Color) -> Control:
	var r = PixelFont.rect(text, scale, color)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


## A centred one-line caption.
static func caption(text: String, size: int = 11, color = null) -> Label:
	var l = Kit.clip(text, size, Pal.MUTED if color == null else color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A tile: icon, big pixel number, one-word caption.
static func num_tile(icon: String, value: String, cap: String, color: Color, scale: int, tip: String = "") -> Card:
	var c = Kit.card(4, Callable(), 10)
	if tip != "":
		c.tooltip_text = tip
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic = Icons.rect(icon, 26)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add(ic)
	c.add(big_num(value, scale, color))
	c.add(caption(cap))
	return c


## A sunken mini tile inside a card: big pixel number over a short caption.
static func well_tile(value: String, cap: String, color: Color, scale: int, tip: String = "") -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.well(6, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tip != "":
		p.tooltip_text = tip
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = Kit.vbox(5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(big_num(value, scale, color))
	v.add_child(caption(cap))
	p.add_child(v)
	return p


## A small raised chip with a caption over a value ("Deadlift" / "150 kg × 3").
static func value_chip(cap: String, value: String, color: Color, tip: String = "") -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL2, {"ring": color, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 10, "pad_v": 6}))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tip != "":
		p.tooltip_text = tip
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(cap, 11, Pal.MUTED, true))
	v.add_child(Kit.clip(value, 15, color, true))
	p.add_child(v)
	return p


## The coloured heading row of a discipline card: badge + name in the pixel font.
static func disc_head(d: String) -> Control:
	var h = Kit.hbox(10)
	h.add_child(Parts.disc_badge(d, 34))
	h.add_child(Kit.vcenter(PixelFont.rect(TT.DISCIPLINE_META[d].name, 2, Pal.disc(d))))
	return h


func _tiles(items: Array, cols: int = 3) -> GridContainer:
	var g = Kit.grid(cols, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		g.add_child(it)
	return g


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


func _hero_fig(tex: Texture2D, title: String, lv: int, now: bool, tip: String) -> Control:
	var v = Kit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.tooltip_text = tip
	var art = PixelRect.make(tex, 3.0)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	v.add_child(big_num(title, 2, Pal.TEXT if now else Pal.MUTED))
	var lvt = Kit.tag("LV %d" % lv, Pal.ACCENT if now else Pal.PANEL2, now, 12)
	lvt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(lvt)
	return v


## Then vs now: the hero on day one and today, the day count between them and
## the biggest improvements as bright "then → now" chips.
func _then_now() -> void:
	var s = App.state
	if s.chronicle.is_empty():
		return
	var start = s.chronicle[0].date
	var days = Dates.days_between(start, App.today)
	var profile = App.profile()
	var card = Kit.card(12, Callable(), 10)
	card.accent(Pal.tab_accent())
	var heroes = Kit.hbox(0)
	var then_tex = Art.hero_texture(Art.state_with_levels(s, LEVEL_ONE), profile, THEN_LOADOUT)
	heroes.add_child(_hero_fig(then_tex, "DAY 1", 1, false, "Day 1: " + Dates.format_date(start, {"month": "short", "day": "numeric", "year": "numeric"})))
	var mid = Kit.vbox(6)
	mid.custom_minimum_size = Vector2(76, 0)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(big_num(str(days), fit_scale([str(days)], 76, 4), Pal.ACCENT))
	mid.add_child(big_num("DAY" if days == 1 else "DAYS", 2, Pal.MUTED))
	mid.add_child(big_num("→", 3, Pal.ACCENT))
	heroes.add_child(mid)
	var now_tex = Art.hero_texture(s, profile, App.loadout())
	heroes.add_child(_hero_fig(now_tex, "TODAY", int(s.levels.hero.level), true, "Today"))
	card.add(heroes)
	var facts = _then_now_facts(App.sessions(), s, App.weight_unit(), App.distance_unit())
	var chips = Kit.grid(2, 8)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for f in facts.slice(0, 4):
		chips.add_child(_then_now_chip(f.label, f.then, f.now))
	if chips.get_child_count() > 0:
		card.add(chips)
	add_child(card)


func _then_now_chip(label_text: String, then_text: String, now_text: String) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(Pal.GOOD), {"ring": Pal.GOOD, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 10, "pad_v": 6}))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = Kit.vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(label_text, 11, Pal.MUTED, true))
	v.add_child(Kit.rich("[color=%s]%s →[/color] [b]%s[/b]" % [Kit.hex_of(Pal.MUTED), Kit.esc(then_text), Kit.esc(now_text)], 15, Pal.GOOD))
	p.add_child(v)
	return p


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
	var du = App.distance_unit()

	_then_now()

	# --- totals as big-number tiles ---------------------------------------------
	var hours = float(t.durationSec) / 3600.0
	var time_text = ("%dH" % int(floor(hours))) if hours >= 1.0 else ("%dM" % TTUtil.jsround(float(t.durationSec) / 60.0))
	var xp_text = Charts.fmt_k(float(s.xp.hero)) if int(s.xp.hero) >= 10000 else Xp.fmt_int(s.xp.hero)
	var totals = [
		["log", Xp.fmt_int(t.sessions), "Sessions", Pal.TEXT, ""],
		["calendar", Xp.fmt_int(t.activeDays), "Days", Pal.TEXT, "Days you trained"],
		["star", xp_text, "XP", Pal.ACCENT, Xp.fmt_int(s.xp.hero) + " XP in all"],
		["flame", "%dW" % int(s.streak.best), "Best streak", Pal.ACCENT2, "Longest streak of weeks hitting your goal"],
		["trophy", str(s.achievements.size()), "Trophies", Pal.TEXT, ""],
		["clock", time_text, "Trained", Pal.TEXT, Fmt.fmt_duration_short(t.durationSec) + " of training"],
	]
	var sc = fit_scale(totals.map(func(x): return x[1]), 100, 3)
	var tiles = []
	for x in totals:
		tiles.append(num_tile(x[0], x[1], x[2], x[3], sc, x[4]))
	add_child(_tiles(tiles))

	# --- charts ---------------------------------------------------------------------
	add_child(Kit.section_title("Weekly XP"))
	var wcard = Kit.card()
	wcard.add(Charts.weekly_xp(_weekly_points(sessions, s)))
	add_child(wcard)

	add_child(Kit.section_title("Consistency"))
	var hcard = Kit.card()
	hcard.add(Charts.heatmap(s.xpByDate, App.today))
	add_child(hcard)

	# --- in perspective: one tile per fact -----------------------------------------
	var facts = FunFacts.fun_facts(s)
	if not facts.is_empty():
		add_child(Kit.section_title("In perspective"))
		var nums = []
		for f in facts:
			nums.append(split_first(Icons.strip_emoji(f.headline))[0])
		var fsc = fit_scale(nums, 132, 3)
		var g = Kit.grid(2, 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(facts.size()):
			g.add_child(_fact_tile(facts[i], fsc))
		add_child(g)

	# --- one card per discipline ------------------------------------------------------
	var by = t.byDiscipline
	if int(by.lift) > 0:
		_lift_section(s, sessions, App.weight_unit())
	if int(by.climb) > 0:
		var cc = Kit.card(10)
		cc.accent(Pal.CLIMB)
		cc.add(disc_head("climb"))
		var max_send = s.prs.climbMaxSend
		var max_flash = s.prs.climbMaxFlash
		var vals = [Xp.fmt_int(t.climbSends), Xp.fmt_int(t.climbFlashes), Xp.grade_label(max_send) if max_send != null else "-"]
		var csc = fit_scale(vals, 96, 3)
		cc.add(_tiles([
			well_tile(vals[0], "Sends", Pal.CLIMB, csc),
			well_tile(vals[1], "Flashes", Charts.flash(), csc),
			well_tile(vals[2], "Top grade", Pal.TEXT, csc, ("Hardest flash: " + Xp.grade_label(max_flash)) if max_flash != null else ""),
		]))
		cc.add(Charts.pyramid(_grade_counts(sessions), int(max_send) if max_send != null else 3))
		cc.add(Charts.legend([{"name": "Sends", "color": Pal.CLIMB}, {"name": "Flashes", "color": Charts.flash()}]))
		# Routes and hangboard, when there are any.
		var extras = []
		if s.prs.get("climbMaxRoute") != null:
			extras.append(value_chip("Hardest route", Xp.yds_label(s.prs.climbMaxRoute), Pal.CLIMB))
		if int(TTUtil.get_or(t, "hangs", 0)) > 0:
			var hsec: int = int(TTUtil.get_or(t, "hangSec", 0))
			extras.append(value_chip("Hangs", "%s · %s" % [Xp.fmt_int(t.hangs), ("%d s" % hsec) if hsec < 120 else Fmt.fmt_duration_short(float(hsec))], Pal.CLIMB))
		if float(TTUtil.get_or(s.prs, "bestHangKg", 0.0)) > 0.0:
			extras.append(value_chip("Heaviest hang", "+" + Fmt.fmt_weight(float(s.prs.bestHangKg), App.weight_unit()), Pal.CLIMB))
		for table in ["hangEdge", "hangOneArm"]:
			if s.prs.get(table) == null:
				continue
			var edges = s.prs[table].keys()
			edges.sort_custom(func(a, b): return int(a) < int(b))
			for ek in edges:
				var cap = Xp.edge_label(int(ek)) + (" one arm" if table == "hangOneArm" else "")
				var kg = float(s.prs[table][ek])
				extras.append(value_chip(cap, ("+" + Fmt.fmt_weight(kg, App.weight_unit())) if kg > 0.0 else "5 s+", Pal.CLIMB, "Best 5 s+ hang on this edge"))
		if not extras.is_empty():
			var ef = Kit.flow(6)
			for x in extras:
				ef.add_child(x)
			cc.add(ef)
		add_child(cc)
	if int(by.run) > 0:
		var pace = s.prs.bestPaceSecPerKm
		var best = []
		if pace != null and float(pace) > 0.0:
			best.append(value_chip("Best pace", Fmt.fmt_pace(pace, du), Pal.RUN))
		add_child(_distance_card("run", t.runDistanceM, t.runElevationM, s.prs.longestRunM, du, best))
	if int(by.ride) > 0:
		var spd = s.prs.bestRideSpeedKmh
		var best2 = []
		if spd != null and float(spd) > 0.0:
			best2.append(value_chip("Top speed", Fmt.fmt_speed(spd, du), Pal.RIDE))
		add_child(_distance_card("ride", t.rideDistanceM, t.rideElevationM, s.prs.longestRideM, du, best2))


## "1.2 blue whales" -> ["1.2", "blue whales"].
static func split_first(text: String) -> Array:
	var i = text.find(" ")
	if i <= 0:
		return [text, ""]
	return [text.substr(0, i), text.substr(i + 1)]


## The colour a fun fact is about, read from its detail line.
static func _fact_color(detail: String) -> Color:
	if detail.contains("lifted"):
		return Pal.LIFT
	if detail.contains("rock"):
		return Pal.CLIMB
	if detail.contains("foot"):
		return Pal.RUN
	if detail.contains("ridden"):
		return Pal.RIDE
	if detail.contains("bosses"):
		return Pal.HP
	return Pal.ACCENT


func _fact_tile(f: Dictionary, sc: int) -> Card:
	var head = Icons.strip_emoji(f.headline)
	var parts = split_first(head)
	var c = Kit.card(4, Callable(), 10)
	c.tooltip_text = "%s %s" % [head, Icons.strip_emoji(f.detail)]
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect(Icons.for_emoji(f.icon), 28)))
	row.add_child(Kit.vcenter(PixelFont.rect(parts[0], sc, _fact_color(str(f.detail)))))
	c.add(row)
	c.add(Kit.clip(parts[1], 13, null, true))
	return c


func _distance_card(d: String, dist: float, elev: float, longest: float, du: String, best: Array) -> Card:
	var c = Kit.card(10)
	c.accent(Pal.disc(d))
	c.add(disc_head(d))
	var a = split_unit(Fmt.fmt_distance(dist, du, 0))
	var b = split_unit(Fmt.fmt_elevation(elev, du))
	var l = split_unit(Fmt.fmt_distance(longest, du))
	var sc = fit_scale([a[0], b[0], l[0]], 96, 3)
	c.add(_tiles([
		well_tile(a[0], a[1] + " total", Pal.disc(d), sc),
		well_tile(b[0], b[1] + " up", Pal.TEXT, sc),
		well_tile(l[0], l[1] + " longest", Pal.TEXT, sc),
	]))
	if not best.is_empty():
		c.add(_tiles(best, 2))
	return c


func _grade_counts(sessions: Array) -> Dictionary:
	var c = {}
	for x in sessions:
		if x.discipline != "climb":
			continue
		for cl in x.get("climbs", []):
			if cl.result == "attempt" or Xp.is_route(cl):
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
	var card = Kit.card(10)
	card.accent(Pal.LIFT)
	card.add(disc_head("lift"))
	var vol = split_unit(Fmt.fmt_big_kg(t.liftVolumeKg, wu))
	var vals = [vol[0], Xp.fmt_int(t.liftReps), Xp.fmt_int(t.liftSets)]
	var sc = fit_scale(vals, 96, 3)
	card.add(_tiles([
		well_tile(vals[0], vol[1] + " lifted", Pal.LIFT, sc),
		well_tile(vals[1], "Reps", Pal.TEXT, sc),
		well_tile(vals[2], "Sets", Pal.TEXT, sc),
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
			var ln = Charts.line(series, Pal.LIFT, func(v): return "%d %s" % [TTUtil.jsround(v), wu])
			ln.tooltip_text = "Estimated one-rep max"
			card.add(ln)
		else:
			card.add(caption("Log it again to see a trend", 12))

	var lifts = []
	for nm in s.prs.lifts:
		lifts.append({"name": nm, "pr": s.prs.lifts[nm]})
	TTUtil.stable_sort(lifts, func(a, b): return float(a.pr.e1rm) > float(b.pr.e1rm))
	lifts = lifts.slice(0, 4)
	if not lifts.is_empty():
		var g = Kit.grid(2, 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for l in lifts:
			g.add_child(value_chip(title_case(l.name), "%s × %d" % [Fmt.fmt_weight(l.pr.weightKg, wu), int(l.pr.reps)], Pal.LIFT, "≈ %s one-rep max" % Fmt.fmt_weight(l.pr.e1rm, wu, 0)))
		card.add(g)
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
			return Pal.HP
		"stage", "level", "start":
			return Pal.ACCENT
		"rank":
			return Pal.rarity("epic")
		"pr":
			return Pal.GOOD
		"achievement":
			return Pal.ACCENT2
		"item", "pet":
			return Pal.SECOND
		"body":
			return Pal.RUN
	return Pal.BORDER


func _build_chronicle() -> void:
	var s = App.state
	var chron = s.chronicle
	if chron.is_empty():
		add_child(Kit.empty("book", "An empty page", "Levels, bosses, trophies and records land here."))
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
	var head = Kit.card(6, Callable(), 12)
	head.accent(Pal.tab_accent())
	head.tooltip_text = "Started " + Dates.format_date(start, {"month": "long", "day": "numeric", "year": "numeric"})
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	var hrow = Kit.hbox(12)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(Kit.vcenter(Icons.rect("book", 34)))
	hrow.add_child(Kit.vcenter(PixelFont.rect("DAY %d" % (Dates.days_between(start, App.today) + 1), 3, Pal.ACCENT)))
	hrow.add_child(Kit.spacer())
	hrow.add_child(Kit.vcenter(Kit.tag("%d moments" % chron.size(), Pal.PANEL2, false, 12)))
	head.add(hrow)
	add_child(head)

	var chips = Kit.flow(6)
	for f in CHRONICLE_FILTERS:
		chips.add_child(Kit.chip(f.label, f.id == _chron_filter, _set_chron_filter.bind(f.id)))
	add_child(chips)

	if events.is_empty():
		var c = Kit.card()
		c.add(caption("Nothing here yet", 13))
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
			add_child(Kit.section_title(m))
			line = TimelineBox.new()
			line.add_theme_constant_override("separation", 6)
			add_child(line)
		line.add_child(_moment(e, settings))


## One moment on one line: an icon tile in the moment's colour, the title (with
## its value) and the date as a muted chip. The detail sentence is the tooltip.
func _moment(e: Dictionary, settings: Dictionary) -> Control:
	var col = _moment_color(e.kind)
	var row = Kit.hbox(8)
	var detail = e.get("detail")
	if detail != null and str(detail) != "":
		row.tooltip_text = Icons.strip_emoji(detail)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic = PanelContainer.new()
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(col), {"ring": col, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 0, "pad_v": 0}))
	ic.custom_minimum_size = Vector2(38, 40)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icc = Kit.center(Icons.rect(Icons.for_emoji(e.get("icon", "")), 22))
	icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(icc)
	row.add_child(Kit.pad(ic, 4, 0, 0, 0))
	var t = Kit.clip(Icons.strip_emoji(e.title), 14, null, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	var val = e.get("val")
	if val != null:
		var vl = Kit.label(Fmt.fmt_goal_value(val.n, val.unit, settings), 14, col if e.kind == "pr" else Pal.ACCENT, true)
		row.add_child(Kit.vcenter(vl))
	row.add_child(Kit.vcenter(Kit.tag(Dates.format_date(e.date), Pal.PANEL2, false, 11)))
	return row


## A column of moments with the timeline's vertical rule behind the icons.
class TimelineBox extends VBoxContainer:
	func _init() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.y > 16.0:
			draw_rect(Rect2(21.0, 8.0, 4.0, size.y - 16.0), Pal.OUTLINE)
			draw_rect(Rect2(22.0, 8.0, 2.0, size.y - 16.0), Pal.LINE)


# ---------------------------------------------------------------------------
# History: every session, newest first
# ---------------------------------------------------------------------------

func _build_history() -> void:
	var sorted = App.sessions().duplicate()
	TTUtil.stable_sort(sorted, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	var xp_of = App.state.sessionXp
	var day = ""
	var list = null
	for x in sorted:
		if x.date != day:
			day = x.date
			var g = Kit.vbox(6)
			var dl = PixelFont.rect(Dates.format_date(day, {"weekday": "short", "month": "short", "day": "numeric"}), 2, Pal.MUTED)
			g.add_child(Kit.pad(dl, 2, 4, 0, 0))
			list = Kit.vbox(6)
			g.add_child(list)
			add_child(g)
		list.add_child(Parts.session_row(x, int(xp_of.get(x.id, 0))))
