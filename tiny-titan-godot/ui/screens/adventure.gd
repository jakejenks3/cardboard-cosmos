class_name AdventureScreen
extends UiScreen
## Adventure tab (port of screens/Adventure.tsx): the boss campaign, daily and
## weekly quests, and the trophy cabinet. Sub-tab in App.adventure_tab.

const TIER_ICON = {"bronze": "medal", "silver": "medal", "gold": "medal", "platinum": "gem"}

## Trophy group filter: "all" or an Achievements.ACH_GROUPS id.
var _filter: String = "all"


func build() -> void:
	var state = App.state
	var q = App.quests()
	var claimable = 0
	for x in q.daily + q.weekly:
		if x.done and not x.claimed:
			claimable += 1

	add_child(Kit.h1("Adventure"))
	var quests_label = "Quests" if claimable == 0 else "Quests (%d)" % claimable
	var tabs = Kit.sub_tabs([
		{"value": "campaign", "label": "Campaign"},
		{"value": "quests", "label": quests_label},
		{"value": "trophies", "label": "Trophies"},
	], App.adventure_tab, App.set_adventure_tab)
	add_child(tabs)

	match App.adventure_tab:
		"quests":
			_quests(q)
		"trophies":
			_trophies(state)
		_:
			_campaign(state)


# ---------------------------------------------------------------------------
# Campaign
# ---------------------------------------------------------------------------

func _campaign(state: Dictionary) -> void:
	var c = state.campaign
	var index = int(c.index)
	var boss = Campaign.boss_at(index)
	var hp_left = maxf(0.0, float(boss.hp) - float(c.damage))
	var defeated = c.defeated.size()
	var echo = Campaign.is_echo(index)
	var zones = Campaign.zones()
	var zone = zones[int(boss.zone)]
	var zc = Pal.hex(zone.color)
	var all_bosses = Campaign.bosses()

	# --- the current boss ------------------------------------------------------
	var card = Kit.card(6, Callable(), 16)
	card.tint(Pal.PANEL.lerp(zc, 0.16), zc)
	var zl = Kit.label(("Endless Trials" if echo else "Zone %d · %s" % [int(boss.zone) + 1, zone.name]).to_upper(), 11, zc, true)
	zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add(zl)
	var bv = BossView.new()
	bv.setup(boss.id, 132.0, true)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(bv)
	var name_up = str(boss.name).to_upper()
	if PixelFont.measure(name_up).x * 2 <= 360:
		var t = PixelFont.rect(name_up, 2, Pal.TEXT)
		t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add(Kit.pad(t, 0, 4, 0, 0))
	else:
		var tl = Kit.para(boss.name, 17, null, true)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(tl)
	var ep = Kit.muted_para(boss.epithet, 13)
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(ep)
	card.add(Kit.pad(Kit.bar(hp_left / maxf(1.0, float(boss.hp)), Pal.HP, 14), 0, 4, 0, 2))
	var meta = Kit.hbox(8)
	var hp_row = Kit.hbox(5)
	hp_row.add_child(Icons.rect("heart", 14))
	hp_row.add_child(Kit.label("%s / %s HP" % [Xp.fmt_int(hp_left), Xp.fmt_int(boss.hp)], 13))
	meta.add_child(hp_row)
	meta.add_child(Kit.spacer())
	var weak = boss.get("weak")
	if weak != null:
		meta.add_child(_weak_tag(weak))
	else:
		meta.add_child(Kit.muted("No weakness", 13))
	card.add(meta)
	var reward = Kit.flow(5)
	reward.alignment = FlowContainer.ALIGNMENT_CENTER
	reward.add_child(Kit.muted("Reward:", 13))
	reward.add_child(Kit.label("+%s XP" % Xp.fmt_int(boss.xp), 13, Pal.ACCENT, true))
	if boss.get("rewardItem") != null:
		var it = Items.by_id(boss.rewardItem)
		if it != null:
			reward.add_child(Kit.muted("·", 13))
			reward.add_child(Icons.rect("gift", 14))
			reward.add_child(Kit.label(it.name, 13, Pal.ACCENT, true))
	card.add(reward)
	add_child(card)

	# --- tiles ------------------------------------------------------------------
	var tiles = Kit.hbox(8)
	tiles.add_child(Kit.stat("Bosses down", "%d/%d" % [mini(defeated, all_bosses.size()), all_bosses.size()]))
	tiles.add_child(Kit.stat("Total damage", Xp.fmt_int(c.totalDamage), "", Pal.ACCENT))
	if echo:
		tiles.add_child(Kit.stat("Echoes", str(defeated - all_bosses.size())))
	else:
		tiles.add_child(Kit.stat("Zone", "%d/%d" % [int(boss.zone) + 1, zones.size()]))
	add_child(tiles)
	var note = Kit.muted_para("Every XP you earn from a session deals 1 damage. Train a boss's weakness for ×%s. Overkill carries over." % TTUtil.num_str(Campaign.WEAK_MULT), 12)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)

	# --- zones ------------------------------------------------------------------
	for zi in range(zones.size()):
		add_child(_zone_card(zi, zones[zi], c))


func _weak_tag(d: String) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(Pal.disc(d), 7, null, 0, 7, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h = Kit.hbox(4)
	h.add_child(Kit.label("Weak to", 11, Color.WHITE, true))
	h.add_child(Icons.rect(d, 14))
	h.add_child(Kit.label("%s ×%s" % [TT.DISCIPLINE_META[d].name, TTUtil.num_str(Campaign.WEAK_MULT)], 11, Color.WHITE, true))
	p.add_child(h)
	return p


func _zone_card(zi: int, z: Dictionary, c: Dictionary) -> Control:
	var index = int(c.index)
	var list = Campaign.bosses_in_zone(zi)
	var reached = index >= int(list[0].index)
	var zc = Pal.hex(z.color)

	var panel = PanelContainer.new()
	var st = Kit.sbox(Pal.PANEL, 14, Pal.LINE, 1, 12, 12)
	st.border_width_left = 4
	st.border_color = zc if reached else Pal.LINE
	st.content_margin_left = 14
	panel.add_theme_stylebox_override("panel", st)
	if not reached:
		panel.modulate.a = 0.6
	var v = Kit.vbox(4)
	panel.add_child(v)

	var head = Kit.hbox(10)
	var hl = Kit.vbox(2)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_child(Kit.para("%d. %s" % [zi + 1, z.name], 16, null, true))
	hl.add_child(Kit.muted_para(z.blurb if reached else "Uncharted. Keep going.", 11))
	head.add_child(hl)
	var pips = Kit.hbox(4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for x in list:
		var on = int(x.index) < index
		var pip = Panel.new()
		pip.custom_minimum_size = Vector2(10, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", Kit.sbox(zc if on else Pal.WELL, 3, zc if on else Pal.LINE, 1, 0, 0))
		pips.add_child(pip)
	head.add_child(pips)
	v.add_child(Kit.pad(head, 0, 0, 0, 4))

	for x in list:
		var b = x.boss
		var bi = int(x.index)
		var status = "defeated" if bi < index else ("current" if bi == index else "locked")
		var known = status != "locked"
		var row = Kit.hbox(10)
		var bv = BossView.new()
		bv.setup(b.id, 44.0, false, not known)
		bv.set_dim(status == "defeated")
		row.add_child(bv)
		var main = Kit.vbox(2)
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nrow = Kit.hbox(4)
		if b.zoneBoss:
			var crown = Icons.rect("crown", 14)
			crown.tooltip_text = "Zone boss"
			nrow.add_child(crown)
		nrow.add_child(Kit.clip(b.name if known else "???", 14, Pal.TEXT if known else Pal.MUTED, true))
		main.add_child(nrow)
		if status == "current":
			var hp = maxf(0.0, float(b.hp) - float(c.damage))
			main.add_child(Kit.pad(Kit.bar(hp / maxf(1.0, float(b.hp)), Pal.HP, 9), 0, 2, 0, 1))
			main.add_child(Kit.muted("%s / %s HP" % [Xp.fmt_int(hp), Xp.fmt_int(b.hp)], 11))
		elif status == "defeated":
			var at = ""
			if c.defeated.has(b.id):
				at = Dates.format_date(c.defeated[b.id].get("at", ""))
			main.add_child(Kit.muted("Defeated %s" % at, 11))
		else:
			main.add_child(Kit.muted("%s HP" % Xp.fmt_int(b.hp), 11))
		row.add_child(main)
		var right = Kit.hbox(6)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if known and b.get("weak") != null:
			var wi = Icons.rect(b.weak, 16)
			wi.tooltip_text = "Weak to %s" % TT.DISCIPLINE_META[b.weak].name
			wi.mouse_filter = Control.MOUSE_FILTER_PASS
			right.add_child(wi)
		if b.get("rewardItem") != null:
			var gi = Icons.rect("gift", 16)
			gi.tooltip_text = "Drops unique gear"
			gi.mouse_filter = Control.MOUSE_FILTER_PASS
			right.add_child(gi)
		if status == "defeated":
			right.add_child(Kit.label("✓", 16, Pal.GOOD, true))
		row.add_child(right)
		if status == "current":
			var hi = PanelContainer.new()
			hi.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.ACCENT, 0.07), 10, Pal.with_alpha(Pal.ACCENT, 0.35), 1, 4, 6))
			hi.add_child(row)
			v.add_child(hi)
		else:
			v.add_child(Kit.divider())
			v.add_child(Kit.pad(row, 4, 2, 4, 2))
	return panel


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _quests(q: Dictionary) -> void:
	add_child(Kit.section_title("Daily", Kit.muted("Resets at midnight", 12)))
	add_child(Parts.quest_list(q.daily))
	var week_end = Dates.add_days(Dates.week_key(App.today), 6)
	var days_left = Dates.days_between(App.today, week_end)
	var hint = "Last day!" if days_left == 0 else "%d day%s left" % [days_left, "" if days_left == 1 else "s"]
	add_child(Kit.section_title("Weekly", Kit.muted(hint, 12)))
	add_child(Parts.quest_list(q.weekly))


# ---------------------------------------------------------------------------
# Trophies
# ---------------------------------------------------------------------------

func _trophies(state: Dictionary) -> void:
	var all = Achievements.all()
	var unlocked = state.achievements.size()
	var points = Achievements.trophy_points(state)
	var max_points = 0
	var tiers = {"bronze": [0, 0], "silver": [0, 0], "gold": [0, 0], "platinum": [0, 0]}
	for a in all:
		max_points += int(a.xp)
		var t = Achievements.tier_of(a)
		tiers[t][1] += 1
		if state.achievements.has(a.id):
			tiers[t][0] += 1

	# --- summary --------------------------------------------------------------
	var sum = Kit.card(8)
	sum.tint(Color("2e2616"), Color("7a5a10"))
	var score = Kit.hbox(10)
	score.add_child(PixelFont.rect(Xp.fmt_int(points), 3, Pal.ACCENT))
	var of = Kit.muted("trophy points of %s" % Xp.fmt_int(max_points), 13)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	score.add_child(of)
	sum.add(score)
	var tf = Kit.flow(6)
	for t in tiers:
		var tc = Pal.hex(Achievements.TIER_COLOR[t])
		var p = PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", Kit.sbox(Color(0, 0, 0, 0), 8, tc, 1, 8, 3))
		var h = Kit.hbox(4)
		h.add_child(Icons.rect(TIER_ICON[t], 16, tc))
		h.add_child(Kit.label("%d/%d" % [tiers[t][0], tiers[t][1]], 12, null, true))
		p.add_child(h)
		tf.add_child(p)
	sum.add(tf)
	sum.add(Kit.muted("%d of %d trophies earned" % [unlocked, all.size()], 13))
	add_child(sum)

	# --- filter chips -----------------------------------------------------------
	var chips = Kit.flow(6)
	chips.add_child(Kit.chip("All", _filter == "all", _set_filter.bind("all")))
	for g in Achievements.ACH_GROUPS:
		var ch = Kit.chip(g.name, _filter == g.id, _set_filter.bind(g.id))
		ch.icon = Icons.tex(Icons.for_emoji(g.icon))
		ch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chips.add_child(ch)
	add_child(chips)

	# --- list -------------------------------------------------------------------
	var rows = []
	for a in all:
		if _filter != "all" and a.group != _filter:
			continue
		var u = state.achievements.get(a.id)
		var p = null
		if u == null and a.has("progress"):
			p = a.progress.call(state)
		var ratio = Goals.progress_ratio(p) if p != null else 0.0
		rows.append({"a": a, "u": u, "p": p, "ratio": ratio})
	# In progress first (closest to done on top), then earned (newest first).
	TTUtil.stable_sort(rows, func(x, y): return AdventureScreen._trophy_less(x, y))

	var list = Kit.card(0, Callable(), 10)
	if rows.is_empty():
		list.add(Kit.muted_para("Nothing here yet.", 13))
	for i in range(rows.size()):
		if i > 0:
			list.add(Kit.divider())
		list.add(_trophy_row(rows[i]))
	add_child(list)


static func _trophy_less(x: Dictionary, y: Dictionary) -> bool:
	var xu = x.u != null
	var yu = y.u != null
	if xu != yu:
		return not xu
	if not xu:
		return x.ratio > y.ratio
	return str(x.u.get("at", "")) > str(y.u.get("at", ""))


func _trophy_row(r: Dictionary) -> Control:
	var a = r.a
	var u = r.u
	var p = r.p
	var tier = Achievements.tier_of(a)
	var tc = Pal.hex(Achievements.TIER_COLOR[tier])
	var hidden = u == null and a.get("secret", false)
	var row = Kit.hbox(10)
	if u == null:
		row.modulate.a = 0.72

	var ic = PanelContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.custom_minimum_size = Vector2(38, 38)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_theme_stylebox_override("panel", Kit.sbox(Pal.WELL, 10, tc, 2, 0, 0))
	var icon_name = "question" if hidden else Icons.for_emoji(a.icon)
	ic.add_child(Icons.rect(icon_name, 22))
	row.add_child(ic)

	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(Kit.para("Secret trophy" if hidden else Icons.strip_emoji(a.name), 14, null, true))
	main.add_child(Kit.muted_para("Keep playing to discover it." if hidden else Icons.strip_emoji(a.desc), 12))
	if p != null and not hidden:
		var col = Pal.disc(a.group) if TT.DISCIPLINE_META.has(a.group) else null
		main.add_child(Parts.progress_line(p, col))
	row.add_child(main)

	var right = Kit.vbox(2)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xp = Kit.label("+%s" % Xp.fmt_int(a.xp), 14, Pal.ACCENT, true)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(xp)
	var sub = Kit.label(Dates.format_date(u.get("at", "")) if u != null else tier, 11, tc, u != null)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(sub)
	row.add_child(right)
	return Kit.pad(row, 2, 8, 2, 8)


func _set_filter(f: String) -> void:
	if f == _filter:
		return
	_filter = f
	rebuild()
