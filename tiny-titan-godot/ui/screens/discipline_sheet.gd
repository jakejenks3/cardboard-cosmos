extends RefCounted
## A discipline's own sheet: what a level tile of the Hero tab's YOUR WEEK
## section opens (2026-11-26, "click on the main boxes on hero page to go deeper
## into those modalities and look at stuff"). For "lift", "climb" and "run"
## (Misc.MAIN). Top to bottom:
##   the level, big, in the discipline's colour, with its XP bar and what is
##     left to the next level; four headline tiles (the player's units; a real
##     set or run, never an estimate);
##   the card Journey -> Stats shows for the discipline (the same builders:
##     JourneyScreen.lift_card / run_card, ClimbCard.build);
##   this week and the last four: sessions a week as bars;
##   its last five sessions (a tap opens the session, as everywhere);
##   "Log one" and "All stats" in one row, then Close.
## With nothing logged it says so in one line and offers "Log one".
## No class_name on purpose (nothing needs a re-import): reach it by path,
##   load("res://ui/screens/discipline_sheet.gd").open("run")
## Metas for tests: "disc_sheet" = d on the sheet, "disc_level" = the level,
## "disc_tile" = a tile's id, "disc_card", "disc_weeks" = the five counts
## (oldest first), "disc_recent" = a row's session id, "disc_log" = d,
## "disc_all", "disc_empty".

const WEEKS = 5
const RECENT = 5
## How a discipline is said: [one session, several, the unit of the week bars].
const WORDS = {
	"lift": ["lifting session", "lifting sessions", "session"],
	"climb": ["climbing session", "climbing sessions", "session"],
	"run": ["run", "runs", "run"],
}

## The exercise picked on the lifting card's chart (null: the one done most).
static var exercise = null


static func open(d: String) -> void:
	if not WORDS.has(d):
		return
	var s = App.state
	var col = Pal.disc(d)
	var mine = _sessions(d)
	var sh = Kit.sheet(str(TT.DISCIPLINE_META[d].name))
	sh.set_meta("disc_sheet", d)
	# Leaving for another tab (a session's Edit key, "Log one") takes the sheet along.
	App.nav_changed.connect(sh.close)
	var box = sh.box

	box.add_child(_level_card(d, s, mine, col))

	if mine.is_empty():
		var none = Kit.empty(d, "Nothing here yet", "Log your first %s and its numbers show up here." % str(WORDS[d][0]))
		none.set_meta("disc_empty", d)
		box.add_child(none)
		box.add_child(_log_key(sh, d))
	else:
		var slot = Kit.vbox(0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.set_meta("disc_card", d)
		box.add_child(slot)
		_fill_card(slot, d)
		box.add_child(_weeks_section(d, mine, col))
		box.add_child(_recent_section(d, s, mine, col))
		var keys = Kit.hbox(8)
		keys.add_child(_log_key(sh, d))
		var all = Kit.button("All stats", "secondary", func(): _all_stats(sh), "lg", "journey")
		all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all.tooltip_text = "Journey: every number, the story and the history"
		all.set_meta("disc_all", d)
		keys.add_child(all)
		box.add_child(keys)
	var ok = Kit.button("Close", "ghost", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(ok)
	sh.open()


## The discipline's sessions, the newest first.
static func _sessions(d: String) -> Array:
	var out = App.sessions().filter(func(x): return str(x.discipline) == d)
	TTUtil.stable_sort(out, func(a, b): return str(a.date) > str(b.date) or (str(a.date) == str(b.date) and int(a.createdAt) > int(b.createdAt)))
	return out


static func _log_key(sh, d: String) -> Button:
	var b = Kit.button("Log one", "primary", func(): _log_one(sh, d), "lg", "plus")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("disc_log", d)
	return b


static func _log_one(sh, d: String) -> void:
	sh.close()
	App.open_log(d)


static func _all_stats(sh) -> void:
	sh.close()
	App.go("journey", "stats")


## The level, its bar, what is left, and the headline tiles under them.
static func _level_card(d: String, s: Dictionary, mine: Array, col: Color) -> Card:
	var lv = s.levels[d]
	var c = Kit.card(10, Callable(), 12)
	c.accent(col)
	c.set_meta("disc_level", int(lv.level))
	var top = Kit.hbox(12)
	top.add_child(Parts.disc_badge(d, 44))
	var side = Kit.vbox(5)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# (2026-11-27 review: "LEVEL 23" was thin pixel letters in a lightened colour straight on the cream paper)
	# The level on a raised plate in the discipline's colour, words in whichever of ink or cream reads on it,
	# as the Hero tab's LV plate.
	var num = Kit.hbox(8)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", PixBox.block_set(col, 8, 5, 1)["normal"])
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(PixelFont.rect("LV %d" % int(lv.level), 3, Kit.on_color(col), false))
	num.add_child(plate)
	side.add_child(num)
	side.add_child(Kit.bar(float(lv.progress), col, 12))
	var left = "The highest level"
	if int(lv.level) < Xp.MAX_LEVEL:
		left = "%s XP to level %d" % [Xp.fmt_int(int(lv.toNext) - int(lv.into)), int(lv.level) + 1]
	side.add_child(Kit.clip(left, 12, Pal.MUTED, true))
	top.add_child(side)
	c.add(top)
	if mine.is_empty():
		return c
	var tiles = _headline(d, s, mine)
	var sc = JourneyScreen.fit_scale(tiles.map(func(x): return x[1]), 150, 3)
	var g = Kit.grid(2, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(tiles.size()):
		var x = tiles[i]
		# (the tiles are dark wells: their numbers cream, the first in the discipline's colour)
		var w = JourneyScreen.well_tile(str(x[1]), str(x[2]), col if i == 0 else Pal.CREAM, sc)
		w.set_meta("disc_tile", str(x[0]))
		g.add_child(w)
	c.add(g)
	return c


## The four headline numbers of a discipline: [id, value, caption] each.
static func _headline(d: String, s: Dictionary, mine: Array) -> Array:
	var t = s.totals
	var prs = s.prs
	var n = mine.size()
	if d == "lift":
		var vol = JourneyScreen.split_unit(Fmt.fmt_big_kg(float(t.liftVolumeKg), App.weight_unit()))
		var wk = Dates.week_key(App.today)
		var days = {}
		for x in mine:
			if Dates.week_key(str(x.date)) == wk:
				days[str(x.date)] = true
		return [
			["sessions", Xp.fmt_int(n), "session" if n == 1 else "sessions"],
			["sets", Xp.fmt_int(int(t.liftSets)), "set" if int(t.liftSets) == 1 else "sets"],
			["moved", vol[0], "%s moved" % vol[1]],
			["week", str(days.size()), "day this week" if days.size() == 1 else "days this week"],
		]
	if d == "climb":
		var top = prs.get("climbMaxSend")
		return [
			["sessions", Xp.fmt_int(n), "session" if n == 1 else "sessions"],
			["sends", Xp.fmt_int(int(t.climbSends)), "send" if int(t.climbSends) == 1 else "sends"],
			["flashes", Xp.fmt_int(int(t.climbFlashes)), "flash" if int(t.climbFlashes) == 1 else "flashes"],
			["hardest", Xp.grade_label(top) if top != null else "-", "hardest send"],
		]
	var du = App.distance_unit()
	var dist = JourneyScreen.split_unit(Fmt.fmt_distance(float(t.runDistanceM), du, 0))
	var far = JourneyScreen.split_unit(Fmt.fmt_distance(float(prs.longestRunM), du))
	var pace = prs.get("bestPaceSecPerKm")
	var quick = ["-", ""]
	if pace != null and float(pace) > 0.0:
		quick = JourneyScreen.split_unit(Fmt.fmt_pace(float(pace), du))
	return [
		["runs", Xp.fmt_int(n), "run" if n == 1 else "runs"],
		["distance", dist[0], "%s in all" % dist[1]],
		["longest", far[0], "%s longest run" % far[1]],
		["pace", quick[0], ("best pace %s" % quick[1]).strip_edges()],
	]


## The card Journey -> Stats shows for the discipline, built by the same code.
static func _fill_card(slot: Control, d: String) -> void:
	for ch in slot.get_children():
		slot.remove_child(ch)
		ch.queue_free()
	var s = App.state
	var sessions = App.sessions()
	if d == "lift":
		slot.add_child(JourneyScreen.lift_card(s, sessions, App.weight_unit(), exercise, func(nm): _pick(slot, str(nm))))
	elif d == "climb":
		slot.add_child(ClimbCard.build(s, sessions))
	else:
		slot.add_child(JourneyScreen.run_card(s, sessions, App.distance_unit()))


## Another exercise for the lifting card's chart: only the card is built again.
static func _pick(slot: Control, nm: String) -> void:
	if not is_instance_valid(slot) or exercise == nm:
		return
	exercise = nm
	_fill_card(slot, "lift")


## Sessions in each of the last WEEKS Monday-weeks, the oldest first:
## [{week, n}] (what WeekBars draws).
static func week_counts(mine: Array, today: String) -> Array:
	var this_week = Dates.week_key(today)
	var out = []
	var at = {}
	for i in range(WEEKS - 1, -1, -1):
		var wk = Dates.add_weeks(this_week, -i)
		at[wk] = out.size()
		out.append({"week": wk, "n": 0})
	for x in mine:
		var wk = Dates.week_key(str(x.date))
		if at.has(wk):
			out[at[wk]].n += 1
	return out


static func _weeks_section(d: String, mine: Array, col: Color) -> Card:
	var weeks = week_counts(mine, App.today)
	var now = int(weeks[weeks.size() - 1].n)
	var before = 0
	for i in range(weeks.size() - 1):
		before += int(weeks[i].n)
	var sec = Kit.section("disc_weeks", "THIS WEEK AND THE LAST FOUR", "calendar", col, null, Callable(), 6, 10)
	sec.set_meta("disc_weeks", weeks.map(func(w): return int(w.n)))
	var bars = WeekBars.new()
	bars.setup(weeks, col, 0, str(WORDS[d][2]))
	sec.add(bars)
	sec.add(Kit.clip("%d this week · %d in the four before" % [now, before], 12, Pal.MUTED))
	return sec


static func _recent_section(d: String, s: Dictionary, mine: Array, col: Color) -> Card:
	var n = mine.size()
	var count = Kit.label("%s %s" % [Xp.fmt_int(n), str(WORDS[d][0 if n == 1 else 1])], 11, col.lightened(0.5), true)
	var sec = Kit.section("disc_recent", "RECENT", "log", col, count, Callable(), 6, 10)
	for i in range(mini(RECENT, n)):
		var x = mine[i]
		var r = Parts.session_row(x, s.sessionXp.get(x.id, 0), true)
		r.set_meta("disc_recent", str(x.id))
		sec.add(r)
	return sec
