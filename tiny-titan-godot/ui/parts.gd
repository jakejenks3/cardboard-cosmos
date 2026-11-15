class_name Parts
extends RefCounted
## Building blocks shared by several screens: quest rows, goal rows and tiles,
## session rows, discipline tiles, the appearance picker. Kit knows nothing
## about the game; these do. They are colour-coded by what they show and keep
## words to a minimum: an icon, a title, a bar, a number.

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


## A small "+150" reward chip in gold.
static func xp_chip(xp, size: int = 12) -> Control:
	return Kit.tag("+%s" % Xp.fmt_int(xp), Pal.ACCENT, true, size)


static func _claim(q: Dictionary, from: Control) -> void:
	Kit.burst(from, Pal.ACCENT, 22)
	App.claim_quest(q)


## A list of quest rows: icon, title, bar and the reward. A finished quest turns
## green with a Claim button; `compact` hides the description and progress text.
static func quest_list(quests: Array, compact: bool = false) -> Control:
	var list = Kit.vbox(8)
	var settings = App.settings()
	for q in quests:
		var color = Pal.disc(q.discipline) if q.get("discipline") != null else Pal.ACCENT
		var card = Kit.card(5, Callable(), 10)
		if q.claimed:
			card.modulate.a = 0.6
		elif q.done:
			card.accent(Pal.GOOD)
		var row = Kit.hbox(10)
		row.add_child(Kit.vcenter(Icons.rect("check" if q.claimed else Icons.for_emoji(q.icon), 30)))
		var main = Kit.vbox(4)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main.add_child(Kit.clip(Icons.strip_emoji(q.title), 15, null, true))
		if not compact:
			main.add_child(Kit.muted_para(Icons.strip_emoji(q.desc), 12))
		var ratio = 0.0
		if float(q.target) > 0.0:
			ratio = float(q.progress) / float(q.target)
		main.add_child(Kit.bar(ratio, color, 8))
		if not compact:
			main.add_child(Kit.muted(quest_progress_text(q, settings), 11))
		row.add_child(main)
		if q.claimed:
			row.add_child(Kit.vcenter(Kit.muted("Done", 12)))
		elif q.done:
			var claim = Kit.button("Claim +%s" % Xp.fmt_int(q.xp), "good", Callable(), "sm")
			claim.pressed.connect(_claim.bind(q, claim))
			row.add_child(Kit.vcenter(claim))
		else:
			row.add_child(Kit.vcenter(xp_chip(q.xp)))
		card.add(row)
		list.add_child(card)
	return list


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
	main.add_child(Kit.clip("%s  ·  %s" % [Fmt.fmt_progress(goal.progress, App.settings()), Icons.strip_emoji(goal.sub)], 11, Pal.MUTED))
	row.add_child(main)
	row.add_child(Kit.vcenter(PixelFont.rect("%d%%" % int(floor(float(goal.ratio) * 100.0)), 2, color)))
	card.add(row)
	return card


## A goal as a small tile: a progress ring around its icon, the percentage and
## a short name. The details are in the tooltip.
static func goal_tile(goal: Dictionary) -> Control:
	var color = Pal.disc(goal.discipline) if goal.get("discipline") != null else Pal.ACCENT
	var card = Kit.card(4, Callable(), 8)
	card.tooltip_text = "%s\n%s\n%s" % [Icons.strip_emoji(goal.title), Icons.strip_emoji(goal.sub), Fmt.fmt_progress(goal.progress, App.settings())]
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


## A raised square in a discipline's colour with its pixel icon.
static func disc_badge(d: String, px: int = 40) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.disc(d), {"lip": 1, "lip_color": Pal.disc(d).darkened(0.45), "pad_h": 0, "pad_v": 0}))
	p.custom_minimum_size = Vector2(px, px + 2)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(Icons.rect(d, px - 16))
	p.add_child(c)
	return p


## A discipline as a bright tile: icon, level in big pixel digits, and how far
## through the level you are. Tap to log that discipline.
static func stat_tile(d: String, level: Dictionary) -> Control:
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
	b.pressed.connect(App.open_log.bind(d))
	Kit.juice(b)
	return b


## One logged session: discipline badge, title, summary, XP. Tap to edit it.
static func session_row(session: Dictionary, xp) -> Control:
	var d = session.discipline
	var card = Kit.card(4, App.open_log.bind(d, session.id), 8)
	var row = Kit.hbox(10)
	row.add_child(disc_badge(d, 38))
	var main = Kit.vbox(1)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title = session.get("title")
	if title == null or str(title) == "":
		title = TT.DISCIPLINE_META[d].name
	var head = Kit.hbox(6)
	head.add_child(Kit.clip(Icons.strip_emoji(title), 14, null, true))
	head.add_child(Kit.muted(Dates.relative_day(session.date, App.today), 11))
	main.add_child(head)
	var sub = Summary.summarize_session(session, App.settings())
	if sub != "":
		main.add_child(Kit.clip(sub, 12, Pal.MUTED))
	row.add_child(main)
	row.add_child(Kit.vcenter(xp_chip(xp, 12)))
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
