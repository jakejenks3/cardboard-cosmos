class_name JourneyScreen
extends UiScreen
## Journey: "how far you've come" (port of screens/Journey.tsx). Five sub-tabs:
## Stats (then vs now, charts, records, fun facts), Body (JourneyBody), Lifts
## (JourneyLifts, the lift library), Story (the dated chronicle) and Log (every
## session, tap to edit).

const LEVEL_ONE = {"hero": 1, "lift": 1, "climb": 1, "run": 1, "ride": 1}
const THEN_LOADOUT = {"body": "tee_grey", "legs": "shorts_navy", "feet": "trainers_worn"}

## The Story page's chips. The "boss" chip is "Bosses" (campaign bosses and
## bounties) while the campaign is on the screens and "Bounties" (the weekly
## bounty wins alone) while it is not: `chronicle_filters()` is what the page uses.
const CHRONICLE_FILTERS = [
	{"id": "all", "label": "Everything", "kinds": null},
	{"id": "level", "label": "Levels", "kinds": ["start", "level", "stage", "rank"]},
	{"id": "boss", "label": "Bosses", "kinds": ["boss", "bounty"]},
	{"id": "achievement", "label": "Trophies", "kinds": ["achievement"]},
	{"id": "loot", "label": "Loot", "kinds": ["item", "pet"]},
	{"id": "pr", "label": "Records", "kinds": ["pr"]},
	{"id": "body", "label": "Body", "kinds": ["body"]},
]

var _exercise = null
var _chron_filter = "all"
## Body sub-tab state (shared with JourneyBody): photo angle, chosen then / now check-ins.
var _body_state = {"angle": "front", "then": null, "now": null}
## Lifts sub-tab state (JourneyLifts): search text, body part, equipment, All / Done / New, sort.
var _lifts_state = {"q": "", "part": "", "equip": "", "show": "all", "sort": "part"}


func build() -> void:
	add_child(Kit.h1("Journey"))
	add_child(Kit.sub_tabs([
		{"value": "stats", "label": "Stats"},
		{"value": "body", "label": "Body"},
		{"value": "lifts", "label": "Lifts"},
		{"value": "chronicle", "label": "Story"},
		{"value": "history", "label": "Log"},
	], App.journey_tab, App.set_journey_tab))
	var no_sessions = App.sessions().is_empty()
	match App.journey_tab:
		"body":
			JourneyBody.build(self, _body_state, rebuild)
		"lifts":
			JourneyLifts.build(self, _lifts_state, rebuild)
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


## A colour as ink on paper (2026-11-27, the Workshop look): darkened in its own hue, so a coloured number or
## word reads on cream and sand and keeps its colour (gold becomes a deep gold, not a washed-out yellow).
static func on_paper(c: Color) -> Color:
	return c.darkened(0.45)


## A colour for a number on a dark well (the Workshop's records tiles): dark ink turns cream, brown ink a
## dimmer cream, gold the bright gold of the numbers on wood; any other colour is kept, made lighter only as
## far as it needs to read on the well.
static func on_well(c: Color) -> Color:
	if c == Pal.TEXT or c == Pal.INK:
		return Pal.CREAM
	if c == Pal.MUTED:
		return Pal.CREAM.darkened(0.25)
	if c == Pal.ACCENT:
		return Pal.GOLD_TEXT
	var out = c
	var i = 0
	while Ink.contrast(out, Pal.WELL) < 4.5 and i < 8:
		out = out.lightened(0.1)
		i += 1
	return out


## The words under a number in a dark well.
static func well_words() -> Color:
	return Pal.CREAM.darkened(0.15)


## A small dark cap (the Workshop's coins and timers) round light pixel numbers on parchment.
static func dark_cap(child: Control, pad_v: int = 6) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", PixBox.material("cap", {"pad_h": 10, "pad_v": pad_v}))
	p.add_child(child)
	return p


## A centred one-line caption.
static func caption(text: String, size: int = 11, color = null) -> Label:
	var l = Kit.clip(text, size, Pal.MUTED if color == null else color, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A tile: icon, big pixel number, one-word caption.
## (2026-11-27, the Workshop look: in a dark well with light numbers, as the records tiles. On cream paper a
## gold or orange pixel number read washed out, and its shadow doubled the strokes.)
static func num_tile(icon: String, value: String, cap: String, color: Color, scale: int, tip: String = "") -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.well(6, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tip != "":
		p.tooltip_text = tip
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = Icons.rect(icon, 26)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(big_num(value, scale, on_well(color)))
	v.add_child(caption(cap, 11, well_words()))
	p.add_child(v)
	return p


## A sunken mini tile inside a card: big pixel number over a short caption.
## (2026-11-27: the colours are made for the dark well here, cream and bright gold, not left to be fixed later.)
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
	v.add_child(big_num(value, scale, on_well(color)))
	v.add_child(caption(cap, 11, well_words()))
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
	# (the value in a deep shade of its colour: a bright one on cream paper read pale)
	v.add_child(Kit.clip(value, 15, on_paper(color), true))
	p.add_child(v)
	return p


## The coloured heading row of a discipline card: badge + name in the pixel font.
## (ClimbCard still uses it; Journey's own discipline cards are sections now. The name is a deep shade of the
## discipline's colour: ochre or pink pixel letters on cream read pale.)
static func disc_head(d: String) -> Control:
	var h = Kit.hbox(10)
	h.add_child(Parts.disc_badge(d, 34))
	h.add_child(Kit.vcenter(PixelFont.rect(TT.DISCIPLINE_META[d].name, 2, on_paper(Pal.disc(d)))))
	return h


static func _tiles(items: Array, cols: int = 3) -> GridContainer:
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
		elif x.discipline == "ride" and first_ride == 0.0 and float(x.get("distanceM", 0)) > 0.0:
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
	var b = s.body
	if b.firstWeightKg != null and b.latestWeightKg != null and b.firstWeightDate != b.latestWeightDate:
		out.append({"label": "Body weight", "then": Fmt.fmt_weight(b.firstWeightKg, wu), "now": Fmt.fmt_weight(b.latestWeightKg, wu)})
	return out.slice(0, 5)


func _hero_fig(tex: Texture2D, title: String, lv: int, now: bool, tip: String, scale: float = 3.0) -> Control:
	var v = Kit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.tooltip_text = tip
	var art = PixelRect.make(tex, scale)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	# (dark ink for both: a brown "DAY 1" on the parchment read washed out)
	v.add_child(big_num(title, 2, Pal.TEXT))
	var lvt = Kit.tag("LV %d" % lv, Pal.ACCENT if now else Pal.PANEL2, now, 12)
	lvt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(lvt)
	return v


## Two heroes side by side at x3 when they fit the column, else x2 (the
## redrawn hero is 64 px wide: at x3 the pair made the page wider than the window).
func _hero_scale(tex_w: int) -> float:
	var col = 440.0
	if is_inside_tree():
		col = minf(get_viewport_rect().size.x, 520.0)
	return 3.0 if float(tex_w) * 3.0 * 2.0 + 76.0 + 70.0 <= col else 2.0


## Then vs now: the hero on day one and today, the day count between them and
## the biggest improvements as bright "then → now" chips.
func _then_now() -> void:
	var s = App.state
	if s.chronicle.is_empty():
		return
	var start = s.chronicle[0].date
	var days = Dates.days_between(start, App.today)
	var profile = App.profile()
	# (2026-11-27, the Workshop look: a window under a sign, the day count gold in a dark cap, the
	# improvements cream slips. It was a window with a blue line, gold numbers on parchment and dark green chips.)
	var card = Kit.section("then_now", "THEN & NOW", "journey", Pal.GOOD, null, Callable(), 12, 10)
	var heroes = Kit.hbox(0)
	var then_tex = Art.hero_texture(Art.state_with_levels(s, LEVEL_ONE), profile, THEN_LOADOUT)
	var now_tex = Art.hero_texture(s, profile, App.loadout())
	var sc = _hero_scale(maxi(then_tex.get_width(), now_tex.get_width()))
	heroes.add_child(_hero_fig(then_tex, "DAY 1", 1, false, "Day 1: " + Dates.format_date(start, {"month": "short", "day": "numeric", "year": "numeric"}), sc))
	var mid = Kit.vbox(6)
	mid.custom_minimum_size = Vector2(76, 0)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var count = Kit.vbox(4)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_child(big_num(str(days), fit_scale([str(days)], 52, 4), Pal.GOLD_TEXT))
	count.add_child(big_num("DAY" if days == 1 else "DAYS", 2, Pal.CREAM))
	mid.add_child(dark_cap(count))
	mid.add_child(big_num("→", 3, on_paper(Pal.ACCENT2)))
	heroes.add_child(mid)
	heroes.add_child(_hero_fig(now_tex, "TODAY", int(s.levels.hero.level), true, "Today", sc))
	card.add(heroes)
	var facts = _then_now_facts(App.sessions(), s, App.weight_unit(), App.distance_unit())
	var chips = Kit.grid(2, 8)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for f in facts.slice(0, 4):
		chips.add_child(_then_now_chip(f.label, f.then, f.now))
	if chips.get_child_count() > 0:
		card.add(chips)
	add_child(card)


## One improvement: a cream slip (a hint of green) with the movement in ink and its variation as a tag, then
## the value then in brown ink, an arrow, and the value now on a green tag.
## (2026-11-27: it was a dark green box with the "then" value in brown on it, nearly invisible, and the raw
## "Deadlift - Barbell" as its label.)
func _then_now_chip(label_text: String, then_text: String, now_text: String) -> Control:
	var c = Kit.row(Callable(), Pal.GOOD, Pal.GOOD, 8, 4, 0.05)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.squeeze(5)
	var sp = LiftNames.split(label_text)
	top.add_child(Kit.soft_name(str(sp.move), 12, Pal.TEXT, true, 160.0, 50.0))
	if str(sp.variation) != "":
		top.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	c.add(top)
	var vals = Kit.flow(5)
	vals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vals.add_child(Kit.vcenter(Kit.label(then_text + " →", 13, Pal.MUTED, true)))
	vals.add_child(Kit.vcenter(Kit.tag(now_text, Pal.GOOD, false, 13)))
	c.add(vals)
	return c


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
		out.append({"week": wk, "byDiscipline": {"lift": 0, "climb": 0, "run": 0, "ride": 0, "misc": 0}, "total": 0})
	for x in sessions:
		var wk = Dates.week_key(x.date)
		if not idx.has(wk):
			continue
		var xp = int(s.sessionXp.get(x.id, 0))
		out[idx[wk]].byDiscipline[x.discipline] = int(out[idx[wk]].byDiscipline.get(x.discipline, 0)) + xp
		out[idx[wk]].total += xp
	return out


## The training dose as text on the clipboard (Dosage.text), up to and including today.
func _copy_dosage() -> void:
	Sfx.tick()
	var text = Dosage.text(App.saved, App.today)
	if WebFiles.available():
		# A phone's browser only copies inside a tap: this runs inside one (web/tt.js),
		# and shows a real Copy button when the phone wants another tap.
		# The toast waits until the text really is on the clipboard.
		WebFiles.copy(text, "Copy the summary", func(): App.toast("Training summary copied: paste it into a chat", "good", "check"))
		return
	DisplayServer.clipboard_set(text)
	App.toast("Training summary copied: paste it into a chat", "good", "check")


func _build_stats() -> void:
	var s = App.state
	var sessions = App.sessions()
	var t = s.totals
	var du = App.distance_unit()

	_then_now()

	# --- recaps: a week or a month as one poster --------------------------------------
	# (a wood-brown sign: the Journey tab's sky blue made the sign navy, the old look)
	var rc = Kit.section("recaps", "RECAPS", "calendar", Pal.BORDER, null, Callable(), 6, 10)
	var rrow = Kit.hbox(8)
	var rl = Kit.para("A week or a month as one poster.", 12, Pal.MUTED)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(Kit.vcenter(rl))
	rrow.add_child(Kit.button("This week", "secondary", RecapSheet.open.bind("week", Dates.week_key(App.today)), "sm"))
	rrow.add_child(Kit.button("This month", "secondary", RecapSheet.open.bind("month", App.today.substr(0, 7)), "sm"))
	rc.add(rrow)
	add_child(rc)

	# --- the training dose as text, to paste into a chat (game/dosage.gd) -------------
	var dc = Kit.section("summary", "TRAINING SUMMARY", "log", Pal.LIFT, null, Callable(), 6, 10)
	var drow = Kit.hbox(8)
	var dv = Kit.vbox(1)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_child(Kit.para("Your weekly sets per muscle, lifts, climbs and runs as text, to paste into a chat with a coach or an AI.", 11, Pal.MUTED))
	drow.add_child(dv)
	var dkey = Kit.button("Copy", "secondary", _copy_dosage, "sm")
	dkey.set_meta("copy_dosage", true)
	drow.add_child(Kit.vcenter(dkey))
	dc.add(drow)
	add_child(dc)

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
	# (2026-11-27: in a window of their own; the tiles sat loose on the planks)
	var tsec = Kit.section("totals", "TOTALS", "star", Pal.ACCENT, null, Callable(), 6, 10)
	tsec.add(_tiles(tiles))
	add_child(tsec)

	# --- weekly sets over 8 weeks, the streak on target, the lift report ----------------
	var wsec = TrackingViews.weekly_card()
	if wsec != null:
		add_child(wsec)
	var rsec = TrackingViews.report_card()
	if rsec != null:
		add_child(rsec)

	# --- charts ---------------------------------------------------------------------
	var wcard = Kit.section("weekly_xp", "WEEKLY XP", "star", Pal.ACCENT, null, Callable(), 6, 10)
	wcard.add(Charts.weekly_xp(_weekly_points(sessions, s)))
	add_child(wcard)

	var hcard = Kit.section("consistency", "CONSISTENCY", "calendar", Pal.GOOD, null, Callable(), 6, 10)
	hcard.add(Charts.heatmap(s.xpByDate, App.today))
	add_child(hcard)

	# --- in perspective: one tile per fact -----------------------------------------
	# (Not the distance ridden: cycling is kept in the Miscellaneous area. Not the
	# damage dealt to bosses while the campaign is off the screens: FunFacts is a
	# ported rule, so the fact is left out here.)
	var facts = FunFacts.fun_facts(s).filter(func(f): return not str(f.detail).contains("ridden") and (Campaign.ON_SCREEN or not str(f.detail).contains("bosses")))
	if not facts.is_empty():
		# (a window of its own, 2026-11-27: the tiles sat loose on the planks under a bare heading)
		var psec = Kit.section("perspective", "IN PERSPECTIVE", "globe", Pal.BORDER, null, Callable(), 8, 10)
		var nums = []
		for f in facts:
			nums.append(split_first(Icons.strip_emoji(f.headline))[0])
		# (a little narrower than on the page: the window's frame takes some of the width)
		var fsc = fit_scale(nums, 116, 3)
		var g = Kit.grid(2, 8)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(facts.size()):
			g.add_child(_fact_tile(facts[i], fsc))
		psec.add(g)
		add_child(psec)

	# --- one card per discipline ------------------------------------------------------
	var by = t.byDiscipline
	if int(by.lift) > 0:
		add_child(lift_card(s, sessions, App.weight_unit(), _exercise, _pick_exercise))
	if int(by.climb) > 0:
		add_child(ClimbCard.build(s, sessions))
	if int(by.run) > 0:
		add_child(run_card(s, sessions, du))
	# Reading (game/reading.gd), once any page was logged.
	if Reading.pages(s) > 0:
		add_child(_reading_card(s))
	# Miscellaneous, last and small: cycling and the misc activities (a vest
	# walk), each a line once it was ever logged; a tap opens its numbers.
	var side = []
	if int(by.ride) > 0:
		side.append({"id": "ride", "icon": "ride", "badge": "ride", "name": str(TT.DISCIPLINE_META.ride.name), "color": Pal.RIDE, "n": int(by.ride), "m": float(t.rideDistanceM)})
	for k in Misc.ORDER:
		var mt = Misc.totals(s, k)
		if mt != null and int(mt.sessions) > 0:
			side.append({"id": "%s:%s" % [TT.MISC, k], "icon": str(Misc.meta(k).icon), "badge": TT.MISC, "name": str(Misc.meta(k).name), "color": Pal.MISC, "n": int(mt.sessions), "m": float(mt.distanceM)})
	if not side.is_empty():
		# (a window with its lines as slips, 2026-11-27; it was a bare heading and cards on the planks)
		var mh = Kit.section("misc", "MISCELLANEOUS", "misc", Pal.MISC, null, Callable(), 6, 10)
		mh.set_meta("misc_area", true)
		for x in side:
			mh.add(_side_row(x, du))
		add_child(mh)


## An activity of the Miscellaneous area as one line: its icon, its name, how
## often and how far in all. A tap opens its numbers (_open_side).
func _side_row(x: Dictionary, du: String) -> Card:
	var c = Kit.row(_open_side.bind(str(x.id)), x.color, null, 8, 0)
	c.set_meta("side_row", str(x.id))
	c.tooltip_text = "%s: all its numbers" % str(x.name)
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Parts.disc_badge(str(x.badge), 32, str(x.icon))))
	var nm = Kit.clip(str(x.name), 13, on_paper(x.color), true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(Kit.vcenter(nm))
	h.add_child(Kit.vcenter(Kit.label("%d time%s · %s" % [int(x.n), "" if int(x.n) == 1 else "s", Fmt.fmt_distance(float(x.m), du)], 12, Pal.MUTED, true)))
	h.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(h)
	return c


## The numbers of one activity of the Miscellaneous area, and a key to log it.
func _open_side(id: String) -> void:
	Sfx.tick()
	var s = App.state
	var t = s.totals
	var du = App.distance_unit()
	var sh = null
	if id == "ride":
		sh = Kit.sheet(str(TT.DISCIPLINE_META.ride.name))
		var spd = s.prs.bestRideSpeedKmh
		var best = [value_chip("Level", str(int(s.levels.ride.level)), Pal.RIDE, "Your cycling level")]
		if spd != null and float(spd) > 0.0:
			best.append(value_chip("Top speed", Fmt.fmt_speed(spd, du), Pal.RIDE))
		sh.box.add_child(_distance_card("ride", t.rideDistanceM, t.rideElevationM, s.prs.longestRideM, du, best))
	else:
		var kind = id.substr(TT.MISC.length() + 1)
		sh = Kit.sheet(str(Misc.meta(kind).name))
		sh.box.add_child(_misc_card(kind, Misc.totals(s, kind), du))
	var add = Kit.button("Log one", "secondary", _log_side.bind(sh, id), "lg", "plus")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.set_meta("side_log", id)
	sh.box.add_child(add)
	var ok = Kit.button("Close", "ghost", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()


func _log_side(sh, id: String) -> void:
	sh.close()
	App.open_log(id)


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
	# (a deep shade of the fact's colour, no shadow: a bright one on cream paper read washed out)
	row.add_child(Kit.vcenter(PixelFont.rect(parts[0], sc, on_paper(_fact_color(str(f.detail))), false)))
	c.add(row)
	c.add(Kit.clip(parts[1], 13, null, true))
	return c


## A misc activity: how far in all, how often, the longest, and its marks as chips.
func _misc_card(kind: String, mt: Dictionary, du: String) -> Card:
	var m = Misc.meta(kind)
	# (2026-11-27, the Workshop look: a window with its name on the sign; pink pixel letters on cream read pale)
	var c = Kit.section("misc_" + kind, str(m.short).to_upper(), str(m.icon), Pal.MISC, null, Callable(), 10, 10)
	c.set_meta("misc_card", kind)
	var a = split_unit(Fmt.fmt_distance(float(mt.distanceM), du))
	var l = split_unit(Fmt.fmt_distance(float(mt.longestM), du))
	var n = Xp.fmt_int(int(mt.sessions))
	var sc = fit_scale([a[0], n, l[0]], 96, 3)
	c.add(_tiles([
		well_tile(a[0], a[1] + " total", Pal.MISC, sc),
		well_tile(n, "session" if int(mt.sessions) == 1 else "sessions", Pal.TEXT, sc),
		well_tile(l[0], l[1] + " longest", Pal.TEXT, sc),
	]))
	var chips = []
	if float(mt.heaviestKg) > 0.0:
		chips.append(value_chip("Heaviest %s" % str(m.loadName).to_lower(), Fmt.fmt_weight(float(mt.heaviestKg), App.weight_unit()), Pal.MISC))
	if int(mt.durationSec) > 0:
		chips.append(value_chip("Time", Fmt.fmt_duration_short(float(mt.durationSec)), Pal.MISC))
	if float(mt.elevationM) >= 0.5:
		chips.append(value_chip("Climbed", Fmt.fmt_elevation(float(mt.elevationM), du), Pal.MISC))
	chips.append(value_chip("XP earned", Xp.fmt_int(int(mt.xp)), Pal.MISC, "Hero XP from this activity"))
	c.add(_tiles(chips, 2))
	return c


## Pages read: the totals, and the sheet with the bookshelf behind a tap.
func _reading_card(s: Dictionary) -> Card:
	# (2026-11-27, the Workshop look: a window with READING on its sign and the chevron on its note; the name was
	# ochre pixel letters on cream. A tap anywhere still opens the bookshelf.)
	var c = Kit.section("reading_stats", "READING", "book", Pal.READ, Icons.rect("chevron_right", 16), ReadingView.open, 10, 10)
	c.tooltip_text = "Reading: tap for the bookshelf"
	c.set_meta("reading_card", true)
	var pages = Xp.fmt_int(Reading.pages(s))
	var days = Xp.fmt_int(Reading.days(s))
	var lv = str(int(Reading.level_of(s).level))
	var sc = fit_scale([pages, days, lv], 96, 3)
	c.add(_tiles([
		well_tile(pages, "pages", Pal.READ, sc),
		well_tile(days, "day" if Reading.days(s) == 1 else "days", Pal.TEXT, sc),
		well_tile(lv, "level", Pal.TEXT, sc),
	]))
	c.add(_tiles([
		value_chip("Streak", "%d day%s" % [Reading.streak(s), "" if Reading.streak(s) == 1 else "s"], Pal.READ),
		value_chip("Best streak", "%d day%s" % [Reading.best_streak(s), "" if Reading.best_streak(s) == 1 else "s"], Pal.READ),
		value_chip("Most in a day", "%s pages" % Xp.fmt_int(Reading.best_day(s)), Pal.READ),
		value_chip("XP earned", Xp.fmt_int(int(s.reading.xp)), Pal.READ, "Hero XP from reading"),
	], 2))
	Kit.passthrough(c.box)
	return c


## The running card: distance in all, climbed, the longest run, then the best
## pace and the best time over each distance as chips. Static: the Hero tab's
## discipline sheet shows the same card (ui/screens/discipline_sheet.gd).
static func run_card(s: Dictionary, sessions: Array, du: String) -> Card:
	var t = s.totals
	var pace = s.prs.bestPaceSecPerKm
	var best = []
	if pace != null and float(pace) > 0.0:
		best.append(value_chip("Best pace", Fmt.fmt_pace(pace, du), Pal.RUN))
	# The best time over each distance: a run of that distance, or a best
	# split typed for a longer one (game/run_splits.gd).
	var split_bests = RunSplits.bests(sessions)
	for dist in RunSplits.DISTS:
		var sb = split_bests.get(str(dist.id))
		if sb != null:
			best.append(value_chip(str(dist.best), RunSplits.fmt_time(int(sb.sec)), Pal.RUN, "%s · %s" % [Dates.format_date(str(sb.date), {"month": "short", "day": "numeric", "year": "numeric"}), Fmt.fmt_pace(RunSplits.pace(str(dist.id), float(sb.sec)), du)]))
	return _distance_card("run", t.runDistanceM, t.runElevationM, s.prs.longestRunM, du, best)


static func _distance_card(d: String, dist: float, elev: float, longest: float, du: String, best: Array) -> Card:
	# (2026-11-27, the Workshop look: a window with the discipline on its sign, as THIS WEEK and RECAPS are;
	# it was small coloured pixel letters inside a window with a coloured line)
	var c = Kit.section(d + "_card", str(TT.DISCIPLINE_META[d].name).to_upper(), d, Pal.disc(d), null, Callable(), 10, 10)
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


## The lifting card: weight, reps and sets in all, the heaviest set of each
## session of one exercise as a line (`exercise`: the one picked, null = the
## one done most; a chip calls `pick` with another), the four strongest lifts.
## Static: the Hero tab's discipline sheet shows the same card
## (ui/screens/discipline_sheet.gd).
static func lift_card(s: Dictionary, sessions: Array, wu: String, exercise, pick: Callable) -> Card:
	var t = s.totals
	# (2026-11-27, the Workshop look: a window with LIFTING on its sign, as the other sections of the page)
	var card = Kit.section("lift_card", str(TT.DISCIPLINE_META.lift.name).to_upper(), "lift", Pal.LIFT, null, Callable(), 10, 10)
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
		if exercise != null and e.name == str(exercise):
			selected = str(exercise)
	if selected == null and not top.is_empty():
		selected = top[0].name

	if not top.is_empty():
		var chips = Kit.flow(6)
		for e in top:
			chips.add_child(Kit.chip(title_case(e.name), e.name == selected, pick.bind(e.name), Pal.LIFT))
		card.add(chips)
		# The lift's progress the way it is earned (LiftProgress, 2026-11-27): a bar of the reps at each
		# session's top weight, standing in steps of weight. It was a line of the heaviest set, which stayed
		# flat through every rep added at the same weight.
		var hist = []
		for x in lift_sessions:
			for ex in x.exercises:
				if Xp.normalize_exercise(ex.name) == selected and not LiftTrend.real_sets(ex.sets).is_empty():
					hist.append({"date": str(x.date), "sets": ex.sets})
		var prow = LiftProgress.days(hist)
		if prow.size() >= 2:
			var shown = prow.slice(maxi(0, prow.size() - 16))
			var mode = str(shown[shown.size() - 1].key.mode)
			var sm = LiftProgress.summary(prow)
			var line = Kit.hbox(6)
			line.add_child(Kit.vcenter(Kit.tag("%d of %d beat last time" % [int(sm.beat), int(sm.days) - 1], Pal.GOOD if int(sm.beat) > 0 else Pal.PANEL2, int(sm.beat) > 0, 11)))
			if int(sm.rungs) > 0:
				line.add_child(Kit.vcenter(Kit.tag("%d step%s up" % [int(sm.rungs), "" if int(sm.rungs) == 1 else "s"], Pal.ACCENT, true, 11)))
			card.add(line)
			var rc = RungChart.new()
			rc.setup(shown, {"fmt_rung": LiftViews.rung_fmt(mode, wu)})
			rc.set_meta("stats_rungs", shown.size())
			card.add(rc)
			# (on two lines when it must: cut off with "…" the sentence lost its point)
			var how = Kit.para("Reps at each session's top weight. A heavier weight starts a new step.", 11, Pal.MUTED)
			how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add(how)
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
	return card


# ---------------------------------------------------------------------------
# Chronicle: the story so far
# ---------------------------------------------------------------------------

func _set_chron_filter(id: String) -> void:
	_chron_filter = id
	rebuild()


## The Story page's chips as they are shown: CHRONICLE_FILTERS, with the "boss"
## chip turned into "Bounties" (kind bounty only) while the campaign is off the
## screens (Campaign.ON_SCREEN).
static func chronicle_filters() -> Array:
	if Campaign.ON_SCREEN:
		return CHRONICLE_FILTERS
	var out = []
	for f in CHRONICLE_FILTERS:
		out.append({"id": "boss", "label": "Bounties", "kinds": ["bounty"]} if f.id == "boss" else f)
	return out


## The moments of the Story page, oldest first: the rules' chronicle with the
## weekly bounty wins joined in (they are kept apart from the ported
## chronicle). A campaign boss going down is no moment while the campaign is
## off the screens; the trophies and gear it brought stay, in their own words.
static func story(s: Dictionary) -> Array:
	var chron = s.chronicle + Bounty.chronicle(s)
	if Campaign.ON_SCREEN:
		return chron
	return chron.filter(func(e): return str(e.kind) != "boss")


static func _month_label(key: String) -> String:
	var d = Dates.parse_date_key(key)
	return "%s %d" % [Dates.MONTHS_LONG[int(d.month) - 1], int(d.year)]


static func _moment_color(kind: String) -> Color:
	match kind:
		"boss":
			return Pal.HP
		"bounty":
			return Pal.BOUNTY
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
	var chron = JourneyScreen.story(s)
	if chron.is_empty():
		add_child(Kit.empty("book", "An empty page", "Levels, %s, trophies and records land here." % ("bosses" if Campaign.ON_SCREEN else "bounties")))
		return
	var filters = JourneyScreen.chronicle_filters()
	var kinds = null
	for f in filters:
		if f.id == _chron_filter:
			kinds = f.kinds
	var events = []
	for i in range(chron.size()):
		var e = chron[i]
		if kinds == null or kinds.has(e.kind):
			events.append({"e": e, "i": i})
	TTUtil.stable_sort(events, func(a, b): return a.e.date > b.e.date or (a.e.date == b.e.date and a.i > b.i))

	# (2026-11-27, the Workshop look: the head is a window under a YOUR STORY sign, the day count gold in a dark
	# cap, the filter chips inside it; then a window a month with the moments as paper slips. The page sat loose
	# on the planks, the day count gold on parchment in a box with a blue line.)
	var start = chron[0].date
	var head = Kit.section("story", "YOUR STORY", "book", Pal.BORDER, Kit.label("%d moments" % chron.size(), 12, Pal.TEXT, true), Callable(), 10, 10)
	head.tooltip_text = "Started " + Dates.format_date(start, {"month": "long", "day": "numeric", "year": "numeric"})
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	var hrow = Kit.hbox(12)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(Kit.vcenter(dark_cap(PixelFont.rect("DAY %d" % (Dates.days_between(start, App.today) + 1), 3, Pal.GOLD_TEXT), 8)))
	var since = Kit.vbox(0)
	since.mouse_filter = Control.MOUSE_FILTER_IGNORE
	since.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	since.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	since.add_child(Kit.clip("Started", 11, Pal.MUTED, true))
	since.add_child(Kit.clip(Dates.format_date(start, {"month": "short", "day": "numeric", "year": "numeric"}), 14, Pal.TEXT, true))
	hrow.add_child(since)
	head.add(hrow)

	var chips = Kit.flow(6)
	for f in filters:
		# (the picked one an orange key, as every pick-one of the game)
		chips.add_child(Kit.chip(f.label, f.id == _chron_filter, _set_chron_filter.bind(f.id), Pal.ACCENT2))
	head.add(chips)
	add_child(head)

	if events.is_empty():
		var c = Kit.card()
		c.add(caption("Nothing here yet", 13))
		add_child(c)
		return

	var settings = App.settings()
	# The moments month by month (they are newest first), a window a month.
	var months = []
	for ev in events:
		var key = str(ev.e.date).substr(0, 7)
		if months.is_empty() or str(months[months.size() - 1].key) != key:
			months.append({"key": key, "label": _month_label(ev.e.date), "events": []})
		months[months.size() - 1].events.append(ev.e)
	for mo in months:
		var n = mo.events.size()
		var sec = Kit.section("month_" + str(mo.key), str(mo.label).to_upper(), "calendar", Pal.BORDER, Kit.label("%d moment%s" % [n, "" if n == 1 else "s"], 12, Pal.TEXT, true), Callable(), 6, 10)
		var line = TimelineBox.new()
		line.add_theme_constant_override("separation", 6)
		for e in mo.events:
			line.add_child(_moment(e, settings))
		sec.add(line)
		add_child(sec)


## One moment on one line, a paper slip: its icon in a slot ringed in the moment's colour, the title (with its
## value) and the date. The detail sentence is the tooltip.
func _moment(e: Dictionary, settings: Dictionary) -> Control:
	var col = _moment_color(e.kind)
	var row = Kit.row(Callable(), col, null, TimelineBox.PAD, 0)
	var detail = e.get("detail")
	if detail != null and str(detail) != "":
		row.tooltip_text = Icons.strip_emoji(detail)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = Kit.badge(Icons.for_emoji(e.get("icon", "")), col, 16)
	ic.custom_minimum_size = Vector2(TimelineBox.ICON_W, TimelineBox.ICON_W)
	h.add_child(ic)
	var t = Kit.clip(Icons.strip_emoji(e.title), 14, null, true)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var val = e.get("val")
	if val != null:
		var vl = Kit.label(Fmt.fmt_goal_value(val.n, val.unit, settings), 14, on_paper(col if e.kind == "pr" else Pal.ACCENT), true)
		h.add_child(Kit.vcenter(vl))
	h.add_child(Kit.vcenter(Kit.label(Dates.format_date(e.date), 11, Pal.MUTED, true)))
	row.add(h)
	return row


## A column of moments (paper slips) with the timeline's vertical rule behind them: it shows in the gaps
## between the slips, through the middle of their icon slots.
class TimelineBox extends VBoxContainer:
	## A slip's padding and the width of its icon slot: the rule runs at PAD + ICON_W / 2.
	const PAD = 6
	const ICON_W = 36
	const RULE_X = 24.0

	func _init() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.y > 16.0:
			draw_rect(Rect2(RULE_X - 2.0, 8.0, 4.0, size.y - 16.0), Pal.OUTLINE)
			draw_rect(Rect2(RULE_X - 1.0, 8.0, 2.0, size.y - 16.0), Pal.LINE)


# ---------------------------------------------------------------------------
# History: every session, newest first
# ---------------------------------------------------------------------------

## The Log sub-tab: a filter, then the workouts week by week (newest first), HIST_WEEKS weeks at a time
## (2026-11-27, "look more clean and crisp": it was a date heading over every single workout).
const HIST_WEEKS = 6
const HIST_FILTERS = [["all", "All"], ["lift", "Lifting"], ["climb", "Climbing"], ["run", "Running"], ["other", "Other"]]
static var hist_filter: String = "all"
static var hist_weeks: int = HIST_WEEKS


static func hist_match(x: Dictionary, f: String) -> bool:
	var d = str(x.get("discipline", ""))
	match f:
		"all":
			return true
		"lift", "climb", "run":
			return d == f
	return not ["lift", "climb", "run"].has(d)


## "THIS WEEK", "LAST WEEK", else "NOV 9 - 15" (or "OCT 27 - NOV 2").
static func week_title(wk: String, today: String) -> String:
	var this_wk = Dates.week_key(today)
	if wk == this_wk:
		return "THIS WEEK"
	if wk == Dates.add_days(this_wk, -7):
		return "LAST WEEK"
	var end = Dates.add_days(wk, 6)
	var a = Dates.format_date(wk, {"month": "short", "day": "numeric"})
	var b = Dates.format_date(end, {"day": "numeric"}) if wk.substr(5, 2) == end.substr(5, 2) else Dates.format_date(end, {"month": "short", "day": "numeric"})
	return ("%s - %s" % [a, b]).to_upper()


func _set_hist_filter(id: String) -> void:
	Sfx.tick()
	hist_filter = id
	hist_weeks = HIST_WEEKS
	rebuild()


func _more_weeks() -> void:
	Sfx.tap()
	hist_weeks += HIST_WEEKS
	rebuild()


func _build_history() -> void:
	var sorted = App.sessions().duplicate()
	TTUtil.stable_sort(sorted, func(a, b): return a.date > b.date or (a.date == b.date and a.createdAt > b.createdAt))
	var xp_of = App.state.sessionXp
	var keys = []
	for f in HIST_FILTERS:
		# (the picked key orange, as every pick-one of the game: the tab's sky blue was the old look)
		var k = Kit.choice(str(f[1]), hist_filter == str(f[0]), _set_hist_filter.bind(str(f[0])), Pal.ACCENT2, 12)
		k.tooltip_text = "Show %s" % ("every workout" if f[0] == "all" else str(f[1]).to_lower())
		k.set_meta("hist_filter", str(f[0]))
		keys.append(k)
	add_child(Kit.choice_track(keys))
	var shown = sorted.filter(func(x): return hist_match(x, hist_filter))
	if shown.is_empty():
		add_child(Kit.para("Nothing of this kind logged yet.", 13, Pal.CREAM))  # (on the planks: cream)
		return
	var oldest = Dates.add_days(Dates.week_key(App.today), -7 * (hist_weeks - 1))
	var weeks = []
	var by_week = {}
	var more = false
	for x in shown:
		var wk = Dates.week_key(str(x.date))
		if wk < oldest:
			more = true
			break
		if not by_week.has(wk):
			by_week[wk] = []
			weeks.append(wk)
		by_week[wk].append(x)
	for wk in weeks:
		var list = by_week[wk]
		var xp = 0
		for x in list:
			xp += int(xp_of.get(x.id, 0))
		# (2026-11-27: a wood-brown sign; the Journey tab's sky blue made it navy with a blue line, the old look.
		# The rows inside are colour-coded by their discipline badges. The count in dark ink on its note.)
		var right = Kit.label("%d · +%s XP" % [list.size(), Xp.fmt_int(xp)], 11, Pal.TEXT, true)
		var sec = Kit.section("week_" + wk, week_title(wk, App.today), "calendar", Pal.BORDER, right, Callable(), 6, 8)
		sec.set_meta("hist_week", wk)
		for x in list:
			sec.add(Parts.session_row(x, int(xp_of.get(x.id, 0)), true))
		add_child(sec)
	if weeks.is_empty():
		add_child(Kit.para("Nothing in the last %d weeks." % hist_weeks, 13, Pal.CREAM))  # (on the planks: cream)
	if more:
		var b = Kit.button("Show older weeks", "secondary", _more_weeks, "md")
		b.set_meta("hist_more", true)
		add_child(b)
