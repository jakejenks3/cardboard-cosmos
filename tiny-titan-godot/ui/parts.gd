class_name Parts
extends RefCounted
## Building blocks shared by several screens: quest rows, goal rows and tiles,
## session rows, discipline tiles, the appearance picker. Kit knows nothing
## about the game; these do. They are colour-coded by what they show and keep
## words to a minimum: an icon, a title, a bar, a number.
##
## Inside a Hero tab section (2026-11-24) rows are FLAT (Kit.row: a darker
## fill, a stripe down the left), never raised boxes in a box: `quest_list`,
## `goal_tile` and `session_row` take `flat = true` for that, and
## `mission_grid` lays the open missions out as small flat tiles two across.
## Without it they look as before (the Adventure and Journey tabs).

const KIND_LABEL = {"achievement": "Trophy", "item": "Gear", "pet": "Companion", "stage": "Evolution", "rank": "Rank"}


## "12 / 20 sends", "4.2 km / 10 km" … for a quest.
static func quest_progress_text(q: Dictionary, settings: Dictionary) -> String:
	var p = min(q.progress, q.target)
	match q.unit:
		"kg":
			return "%s / %s" % [Fmt.fmt_weight(p, settings.weightUnit, 0), Fmt.fmt_weight(q.target, settings.weightUnit, 0)]
		"m":
			return "%s / %s" % [Fmt.fmt_distance(p, settings.distanceUnit), Fmt.fmt_distance(q.target, settings.distanceUnit)]
		"xp":
			return "%s / %s XP" % [Xp.fmt_int(p), Xp.fmt_int(q.target)]
		"min":
			return "%s / %s min" % [Xp.fmt_int(p), TTUtil.num_str(q.target)]
		"sec":
			return "%s / %s s" % [Xp.fmt_int(p), TTUtil.num_str(q.target)]
		"sends":
			return "%s / %s sends" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
		"days":
			return "%s / %s days" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
		"disciplines":
			return "%s / %s disciplines" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
	return "%s / %s" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]


## A small "+150" reward chip in gold.
static func xp_chip(xp, size: int = 12) -> Control:
	return Kit.tag("+%s" % Xp.fmt_int(xp), Pal.ACCENT, true, size)


static func _claim(q: Dictionary, from: Control) -> void:
	Kit.burst(from, Pal.ACCENT, 22)
	App.claim_quest(q)


## A list of quest rows: icon, title, bar and the reward. A finished quest turns
## green with a Claim button; `compact` hides the description and progress text.
## `flat`: rows for a section (Kit.row, striped in the mission's colour, green
## once done), each as tall with its Claim key as with "Done", so nothing under
## a row moves when one is claimed.
static func quest_list(quests: Array, compact: bool = false, flat: bool = false) -> Control:
	var list = Kit.vbox(6 if flat else 8)
	var settings = App.settings()
	for q in quests:
		var color = Pal.disc(q.discipline) if q.get("discipline") != null else Pal.ACCENT
		# A mission about one lift opens that lift's page (last time, what to beat).
		var tap = JourneyLifts.open_named.bind(str(q.lift), {"view": "compare"}) if q.has("lift") else Callable()
		var card
		if flat:
			card = Kit.row(tap, Pal.GOOD if q.done else color, Pal.GOOD if (q.done and not q.claimed) else null, 8, 4)
			if q.claimed:
				card.modulate.a = 0.6
		else:
			card = Kit.card(5, tap, 10)
			if q.claimed:
				card.modulate.a = 0.6
			elif q.done:
				card.accent(Pal.GOOD)
		var row = Kit.hbox(10)
		if flat:
			row.custom_minimum_size.y = 44 if Kit.fingers else 40
		row.add_child(Kit.vcenter(Icons.rect("check" if q.claimed else Icons.for_emoji(q.icon), 28 if flat else 30)))
		var main = Kit.vbox(4)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main.add_child(Kit.clip(Icons.strip_emoji(q.title), 14 if flat else 15, null, true))
		if not compact:
			main.add_child(Kit.muted_para(Icons.strip_emoji(q.desc), 12))
		var ratio = 0.0
		if float(q.target) > 0.0:
			ratio = float(q.progress) / float(q.target)
		main.add_child(Kit.bar(ratio, color, 6 if flat else 8))
		if not compact:
			main.add_child(Kit.muted(quest_progress_text(q, settings), 11))
		row.add_child(main)
		if q.claimed:
			row.add_child(Kit.vcenter(Kit.muted("Done", 12)))
		elif q.done:
			var claim = Kit.button("Claim +%s" % Xp.fmt_int(q.xp), "good", Callable(), "sm")
			# (its own name: after a claim it is gone, and no other key of the same
			# text is put under the finger in its place)
			claim.set_meta("anchor_id", "claim:" + str(q.id))
			claim.pressed.connect(_claim.bind(q, claim))
			Fx.shine(claim, 2.6, 0.5, 0.45)
			row.add_child(Kit.vcenter(claim))
		else:
			row.add_child(Kit.vcenter(xp_chip(q.xp)))
		card.add(row)
		list.add_child(card)
	return list


## The missions still open as small flat tiles, two across: the icon and the
## mission's own title (two lines at most), a thin bar and the reward. A
## mission about one lift opens that lift's page, any other the Missions list.
static func mission_grid(quests: Array) -> GridContainer:
	var g = Kit.grid(2, 6)
	for q in quests:
		var color = Pal.disc(q.discipline) if q.get("discipline") != null else Pal.ACCENT
		var tap = JourneyLifts.open_named.bind(str(q.lift), {"view": "compare"}) if q.has("lift") else App.go.bind("adventure", "quests")
		var t = Kit.row(tap, color, null, 8, 3)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.tooltip_text = Icons.strip_emoji(str(q.get("desc", "")))
		var line = Kit.hbox(6)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(Kit.vcenter(Icons.rect(Icons.for_emoji(q.icon), 20)))
		var title = Kit.para(Icons.strip_emoji(q.title), 12, Pal.TEXT, true)
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(title)
		t.add(line)
		var foot = Kit.hbox(6)
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ratio = 0.0
		if float(q.target) > 0.0:
			ratio = float(q.progress) / float(q.target)
		foot.add_child(Kit.vcenter(Kit.bar(ratio, color, 4)))
		foot.add_child(Kit.vcenter(xp_chip(q.xp, 11)))
		t.add(foot)
		g.add_child(t)
	return g


## One "next goal" row (from App.next_goals): icon, title, a bar and the percentage.
static func goal_row(goal: Dictionary) -> Control:
	var color = Pal.disc(goal.discipline) if goal.get("discipline") != null else Pal.ACCENT
	var card = Kit.card(5, Callable(), 10)
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Icons.rect(Icons.for_emoji(goal.icon), 30)))
	var main = Kit.vbox(4)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head = Kit.hbox(6)
	head.add_child(Kit.clip(Icons.strip_emoji(goal.title), 15, null, true))
	head.add_child(Kit.tag(KIND_LABEL.get(goal.kind, ""), Pal.PANEL2, false, 10))
	main.add_child(head)
	main.add_child(Kit.bar(goal.ratio, color, 8))
	main.add_child(Kit.clip("%s  ·  %s" % [Fmt.fmt_progress(goal.progress, App.settings()), Units.text(Icons.strip_emoji(goal.sub), App.settings())], 11, Pal.MUTED))
	row.add_child(main)
	row.add_child(Kit.vcenter(PixelFont.rect("%d%%" % int(floor(float(goal.ratio) * 100.0)), 2, color)))
	card.add(row)
	return card


## A goal as a small tile: a progress ring around its icon, the percentage and
## a short name. The details are in the tooltip. `flat`: a flat row for a section.
static func goal_tile(goal: Dictionary, flat: bool = false) -> Control:
	var color = Pal.disc(goal.discipline) if goal.get("discipline") != null else Pal.ACCENT
	var card = Kit.row(Callable(), Pal.LINE, null, 8, 4) if flat else Kit.card(4, Callable(), 8)
	card.tooltip_text = "%s\n%s\n%s" % [Icons.strip_emoji(goal.title), Units.text(Icons.strip_emoji(goal.sub), App.settings()), Fmt.fmt_progress(goal.progress, App.settings())]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var ring = Ring.new()
	ring.setup(goal.ratio, color, 58.0, Icons.rect(Icons.for_emoji(goal.icon), 30))
	card.add(ring)
	var pct = PixelFont.rect("%d%%" % int(floor(float(goal.ratio) * 100.0)), 2, color)
	pct.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(pct)
	var name_label = Kit.clip(Icons.strip_emoji(goal.title), 11, Pal.MUTED, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(name_label)
	return card


## A compact progress bar + "cur / target" for locked things. progress = {cur, target, unit}.
static func progress_line(progress: Dictionary, color = null) -> Control:
	var v = Kit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.bar(Goals.progress_ratio(progress), Pal.ACCENT if color == null else color, 6))
	v.add_child(Kit.muted(Fmt.fmt_progress(progress, App.settings()), 11))
	return v


## A raised square in a discipline's colour with its pixel icon (or `icon`,
## e.g. the vest of a misc activity on the misc colour).
static func disc_badge(d: String, px: int = 40, icon: String = "") -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.disc(d), {"lip": 1, "lip_color": Pal.disc(d).darkened(0.45), "pad_h": 0, "pad_v": 0}))
	p.custom_minimum_size = Vector2(px, px + 2)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(Icons.rect(icon if icon != "" else d, px - 16))
	p.add_child(c)
	return p


## The badge of a session: its discipline's, or for a misc activity its kind's icon on the misc colour.
static func session_badge(session: Dictionary, px: int = 40) -> Control:
	if Misc.is_misc(session):
		return disc_badge(TT.MISC, px, str(Misc.meta(Misc.kind_of(session)).icon))
	return disc_badge(str(session.discipline), px)


## A discipline as a bright tile: icon, level in big pixel digits, and how far
## through the level you are. Tap to log that discipline, or, with `tap`, to do
## that instead (the Hero tab: the discipline's sheet). Meta "stat_tile" = d.
static func stat_tile(d: String, level: Dictionary, tap: Callable = Callable()) -> Control:
	var col = Pal.disc(d)
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(60, 98)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = "%s · level %d\n%s XP to the next level" % [TT.DISCIPLINE_META[d].name, int(level.level), Xp.fmt_int(level.toNext - level.into)]
	var looks = PixBox.button_set(col, col.darkened(0.45), 6, 6, 2, col.lightened(0.3))
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var drop = 3 * PixBox.S
	var v = Kit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8 - drop
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = Icons.rect(d, 30)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var num = PixelFont.rect(str(int(level.level)), 3, Color.WHITE)
	num.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(num)
	v.add_child(Kit.bar(level.progress, Color.WHITE, 4))
	b.add_child(v)
	b.button_down.connect(func():
		v.offset_top = 8 + drop
		v.offset_bottom = -8)
	b.button_up.connect(func():
		v.offset_top = 8
		v.offset_bottom = -8 - drop)
	b.pressed.connect(tap if tap.is_valid() else App.open_log.bind(d))
	b.set_meta("stat_tile", d)
	Kit.juice(b)
	return b


## One logged session: discipline badge, title, summary, XP. A tap opens
## everything that was done in it (SessionView.open), with an Edit key there.
## `flat`: a flat row for a section, striped in the discipline's colour.
static func session_row(session: Dictionary, xp, flat: bool = false) -> Control:
	var d = session.discipline
	var card = Kit.row(SessionView.open.bind(session), Pal.disc(d), null, 8, 4) if flat else Kit.card(4, SessionView.open.bind(session), 8)
	card.tooltip_text = "Everything you did"
	var row = Kit.hbox(10)
	row.add_child(session_badge(session, 32 if flat else 38))
	var main = Kit.vbox(1)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.set_meta("session_row", str(session.get("id", "")))
	var title = session.get("title")
	if title == null or str(title) == "":
		title = Misc.title(session) if Misc.is_misc(session) else TT.DISCIPLINE_META[d].name
	# (2026-11-27, "look more clean and crisp": the day's kind and its records as tags in the title line, a
	# lift's movements named on a line of their own instead of "3 exercises", the numbers under them)
	var head = Kit.hbox(6)
	head.add_child(Kit.clip(Icons.strip_emoji(title), 15 if flat else 14, null, true))
	var kind = day_kind_word(session)
	if kind != "":
		var kt = Kit.tag(kind, Pal.disc(d), true, 10)
		kt.set_meta("session_kind", kind)
		head.add_child(Kit.vcenter(kt))
	var prs = pr_count(session)
	if prs > 0:
		var pt = Kit.tag("%d PR" % prs if prs > 1 else "PR", Pal.ACCENT, true, 10)
		pt.set_meta("session_prs", prs)
		head.add_child(Kit.vcenter(pt))
	var bc = beat_of(session)
	if int(bc.beat) > 0:
		var bt = Kit.tag("▲ %d/%d" % [int(bc.beat), int(bc.of)], Pal.GOOD, true, 10)
		bt.tooltip_text = "Beat last time on %d of %d lifts" % [int(bc.beat), int(bc.of)]
		bt.set_meta("session_beat", int(bc.beat))
		head.add_child(Kit.vcenter(bt))
	head.add_child(Kit.vcenter(Kit.muted(Dates.relative_day(session.date, App.today), 11)))
	main.add_child(head)
	if d == "lift":
		var moves = lift_moves(session)
		if moves != "":
			var ml = Kit.clip(moves, 12, Pal.TEXT)
			ml.set_meta("session_moves", moves)
			main.add_child(ml)
	var sub = session_numbers(session)
	if sub != "":
		main.add_child(Kit.clip(sub, 12, Pal.MUTED))
	row.add_child(main)
	row.add_child(Kit.vcenter(xp_chip(xp, 12)))
	card.add(row)
	return card


## A lift session's movements in the order done ("Deadlift · Overhead Press · Row"), each once, without
## their variations (the session's sheet has those).
static func lift_moves(session: Dictionary) -> String:
	var out = []
	for e in session.get("exercises", []):
		if LiftTrend.real_sets(e.get("sets", [])).is_empty():
			continue
		var mv = str(LiftNames.split(str(e.get("name", ""))).move).strip_edges()
		if mv != "" and not out.has(mv):
			out.append(mv)
	return " · ".join(PackedStringArray(out))


## The numbers of a session in one short line. A lift: sets, the weight moved, bodyweight reps, the time
## (its movements are named above it); anything else as Summary says it.
static func session_numbers(session: Dictionary) -> String:
	if str(session.get("discipline", "")) != "lift":
		return Summary.summarize_session(session, App.settings())
	var st = Xp.session_stats(session)
	var parts = []
	parts.append("%s set%s" % [TTUtil.num_str(st.sets), "" if int(st.sets) == 1 else "s"])
	if float(st.volumeKg) != 0.0:
		parts.append(Fmt.fmt_big_kg(float(st.volumeKg), App.weight_unit()))
	if int(st.bwReps) != 0:
		parts.append("%s BW reps" % TTUtil.num_str(st.bwReps))
	var dur = int(TTUtil.get_or(session, "durationSec", 0))
	if dur > 0:
		parts.append(Fmt.fmt_duration_short(dur))
	return " · ".join(PackedStringArray(parts))


## "PULL", "PUSH", "LEGS"... for a lift session when the player has a training split; else "".
static func day_kind_word(session: Dictionary) -> String:
	if str(session.get("discipline", "")) != "lift":
		return ""
	var cycle = Missions.split_cycle(str(App.settings().get("split", "auto")))
	if cycle.is_empty():
		return ""
	var k = Missions.kind_of_day(session.get("exercises", []), cycle, App.pt())
	match k:
		"pull", "push", "legs", "upper", "lower":
			return k.to_upper()
	return ""


static var _beat_key: String = ""
static var _beats: Dictionary = {}

## How many of a lift session's exercises beat the time before ({"beat", "of"}; LiftProgress.beat_counts,
## worked out once per change of the log).
static func beat_of(session: Dictionary) -> Dictionary:
	if str(session.get("discipline", "")) != "lift":
		return {"beat": 0, "of": 0}
	var key = "%s:%d" % [str(App.saved.get("updatedAt", "")), App.sessions().size()]
	if key != _beat_key:
		_beat_key = key
		_beats = LiftProgress.beat_counts(App.sessions())
	return _beats.get(str(session.get("id", "")), {"beat": 0, "of": 0})


static var _pr_key: String = ""
static var _pr_days: Dictionary = {}

## How many records the replay noted on this session's day for its discipline (the Story page's "pr"
## moments, which carry no session id: two sessions of one kind on one day share them).
static func pr_count(session: Dictionary) -> int:
	var chron = App.state.get("chronicle", [])
	var key = "%s:%d" % [str(App.saved.get("updatedAt", "")), chron.size()]
	if key != _pr_key:
		_pr_key = key
		_pr_days = {}
		for c in chron:
			if str(c.get("kind", "")) == "pr":
				var k = "%s|%s" % [str(c.get("date", "")), str(c.get("discipline", ""))]
				_pr_days[k] = int(_pr_days.get(k, 0)) + 1
	return int(_pr_days.get("%s|%s" % [str(session.get("date", "")), str(session.get("discipline", ""))], 0))


## Skin tone, hair style and hair colour pickers, and facial hair when
## `facial` is 0 or more. `on_change.call({"skin": i})` / `{"hairStyle": i}` /
## `{"hairColor": i}` / `{"facialHair": i}`.
static func appearance_editor(skin: int, hair_style: int, hair_color: int, on_change: Callable, facial: int = -1) -> Control:
	var v = Kit.vbox(8)
	v.add_child(Kit.label("Skin", 12, Pal.MUTED, true))
	var skins = Kit.flow(8)
	for i in range(HeroBody.SKIN_TONES.size()):
		skins.add_child(_swatch(Pal.hex(HeroBody.SKIN_TONES[i]), i == skin, on_change.bind({"skin": i})))
	v.add_child(skins)
	v.add_child(Kit.label("Hair", 12, Pal.MUTED, true))
	var styles = Kit.flow(6)
	for i in range(HeroBody.HAIR_STYLES.size()):
		styles.add_child(Kit.chip(HeroBody.HAIR_STYLES[i], i == hair_style, on_change.bind({"hairStyle": i})))
	v.add_child(styles)
	var colors = Kit.flow(8)
	for i in range(HeroBody.HAIR_COLORS.size()):
		colors.add_child(_swatch(Pal.hex(HeroBody.HAIR_COLORS[i]), i == hair_color, on_change.bind({"hairColor": i})))
	v.add_child(colors)
	if facial >= 0:
		v.add_child(Kit.label("Face", 12, Pal.MUTED, true))
		var face = Kit.flow(6)
		for i in range(HeroBody.FACIAL_HAIR.size()):
			face.add_child(Kit.chip(HeroBody.FACIAL_HAIR[i], i == facial, on_change.bind({"facialHair": i})))
		v.add_child(face)
	return v


## A raised colour swatch; the chosen one has a gold edge.
static func _swatch(color: Color, active: bool, on_press: Callable) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(36, 38)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var looks = PixBox.button_set(color, color.darkened(0.45), 0, 0, 1, Pal.ACCENT if active else null)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(on_press)
	Kit.juice(b)
	return b
