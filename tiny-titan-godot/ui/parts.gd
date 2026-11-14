class_name Parts
extends RefCounted
## Building blocks shared by several screens: quest rows, goal rows, session
## rows, the appearance picker. Kit knows nothing about the game; these do.

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
		"sends":
			return "%s / %s sends" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
		"days":
			return "%s / %s days" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
		"disciplines":
			return "%s / %s disciplines" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]
	return "%s / %s" % [TTUtil.num_str(p), TTUtil.num_str(q.target)]


## A list of quest cards with progress bars and Claim buttons.
## `compact` hides the description (Home screen).
static func quest_list(quests: Array, compact: bool = false) -> Control:
	var list = Kit.vbox(8)
	var settings = App.settings()
	for q in quests:
		var color = Pal.disc(q.discipline) if q.get("discipline") != null else Pal.ACCENT
		var card = Kit.card(6, Callable(), 12)
		if q.claimed:
			card.tint(Pal.with_alpha(Pal.PANEL, 0.55), Pal.with_alpha(Pal.LINE, 0.6))
			card.modulate.a = 0.75
		elif q.done:
			card.tint(Pal.PANEL2, Pal.GOOD)
		var row = Kit.hbox(10)
		var icon_name = "check" if q.claimed else Icons.for_emoji(q.icon)
		row.add_child(Kit.vcenter(Icons.rect(icon_name, 28)))
		var main = Kit.vbox(4)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head = Kit.hbox(6)
		head.add_child(Kit.clip(Icons.strip_emoji(q.title), 14, null, true))
		head.add_child(Kit.label("+%s XP" % Xp.fmt_int(q.xp), 12, Pal.ACCENT, true))
		main.add_child(head)
		if not compact:
			main.add_child(Kit.muted_para(Icons.strip_emoji(q.desc), 12))
		var ratio = 0.0
		if float(q.target) > 0.0:
			ratio = float(q.progress) / float(q.target)
		main.add_child(Kit.bar(ratio, color, 7))
		main.add_child(Kit.muted(quest_progress_text(q, settings), 11))
		row.add_child(main)
		if q.claimed:
			row.add_child(Kit.vcenter(Kit.muted("Claimed", 12)))
		elif q.done:
			var claim = Kit.button("Claim", "good", App.claim_quest.bind(q), "sm")
			row.add_child(Kit.vcenter(claim))
		card.add(row)
		list.add_child(card)
	return list


## One "next goal" row (from App.next_goals): icon, title + kind, what you get,
## a progress bar and the percentage.
static func goal_row(goal: Dictionary) -> Control:
	var color = Pal.disc(goal.discipline) if goal.get("discipline") != null else Pal.ACCENT
	var card = Kit.card(6, Callable(), 12)
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Icons.rect(Icons.for_emoji(goal.icon), 28)))
	var main = Kit.vbox(3)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head = Kit.hbox(6)
	head.add_child(Kit.clip(Icons.strip_emoji(goal.title), 14, null, true))
	head.add_child(Kit.tag(KIND_LABEL.get(goal.kind, ""), Pal.PANEL2, false, 10))
	main.add_child(head)
	main.add_child(Kit.muted_para(Icons.strip_emoji(goal.sub), 11))
	main.add_child(Kit.bar(goal.ratio, color, 7))
	main.add_child(Kit.muted(Fmt.fmt_progress(goal.progress, App.settings()), 11))
	row.add_child(main)
	row.add_child(Kit.vcenter(Kit.label("%d%%" % int(floor(float(goal.ratio) * 100.0)), 14, Pal.ACCENT, true)))
	card.add(row)
	return card


## A compact progress bar + "cur / target" for locked things. progress = {cur, target, unit}.
static func progress_line(progress: Dictionary, color = null) -> Control:
	var v = Kit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.bar(Goals.progress_ratio(progress), Pal.ACCENT if color == null else color, 6))
	v.add_child(Kit.muted(Fmt.fmt_progress(progress, App.settings()), 11))
	return v


## A coloured rounded square with a discipline's pixel icon.
static func disc_badge(d: String, px: int = 38) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.disc(d), 0.28), 10, Pal.disc(d), 1, 0, 0))
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic = Icons.rect(d, px - 14)
	p.add_child(ic)
	return p


## One logged session: discipline badge, title, summary, XP and day. Tap to edit it.
static func session_row(session: Dictionary, xp) -> Control:
	var d = session.discipline
	var card = Kit.card(4, App.open_log.bind(d, session.id), 10)
	var row = Kit.hbox(10)
	row.add_child(disc_badge(d))
	var main = Kit.vbox(1)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = session.get("title")
	if title == null or str(title) == "":
		title = TT.DISCIPLINE_META[d].name
	main.add_child(Kit.clip(Icons.strip_emoji(title), 14, null, true))
	var sub = Summary.summarize_session(session, App.settings())
	if sub != "":
		main.add_child(Kit.clip(sub, 12, Pal.MUTED))
	row.add_child(main)
	var right = Kit.vbox(1)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xp_label = Kit.label("+%s" % Xp.fmt_int(xp), 14, Pal.ACCENT, true)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(xp_label)
	var day = Kit.muted(Dates.relative_day(session.date, App.today), 11)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(day)
	row.add_child(right)
	card.add(row)
	return card


## Skin tone, hair style and hair colour pickers.
## `on_change.call({"skin": i})` / `{"hairStyle": i}` / `{"hairColor": i}`.
static func appearance_editor(skin: int, hair_style: int, hair_color: int, on_change: Callable) -> Control:
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
	return v


static func _swatch(color: Color, active: bool, on_press: Callable) -> Button:
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(34, 34)
	var border = Pal.ACCENT if active else Pal.LINE
	var bw = 3 if active else 1
	var sb = Kit.sbox(color, 99, border, bw, 0, 0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", Kit.sbox(color.lightened(0.1), 99, border, bw, 0, 0))
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(on_press)
	return b
