class_name AdventureScreen
extends UiScreen
## Adventure tab (port of screens/Adventure.tsx): the boss campaign, daily and
## weekly quests, and the trophy cabinet. Sub-tab in App.adventure_tab.
##
## Built to be looked at: the current boss is the star, the zones are grids of
## boss portraits, trophies are a grid of tiles. Explanations live in tooltips
## and details in a sheet opened by tapping a tile.

const TIER_ICON = {"bronze": "medal", "silver": "medal", "gold": "medal", "platinum": "gem"}
const TROPHY_COLS = 3
const BOSS_COLS = 4

## Trophy group filter: "all" or the id of one of Achievements.groups().
var _filter: String = "all"


func build() -> void:
	var state = App.state
	var q = App.quests()
	var claimable = 0
	for x in q.daily + q.weekly + q.get("yesterday", []):
		if x.done and not x.claimed:
			claimable += 1

	add_child(Kit.h1("Adventure"))
	var quests_label = "Missions" if claimable == 0 else "Missions (%d)" % claimable
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
# Small pieces
# ---------------------------------------------------------------------------

static func weak_pill(d: String) -> Control:
	var tip = "Weak to %s: those sessions hit for ×%s" % [str(TT.DISCIPLINE_META[d].name).to_lower(), TTUtil.num_str(Campaign.WEAK_MULT)]
	return Kit.pill(d, "×%s" % TTUtil.num_str(Campaign.WEAK_MULT), Pal.disc(d), tip, Color.WHITE, 13)


## The reward chips of a boss: XP in gold, its unique gear in its rarity colour.
static func reward_pills(boss: Dictionary) -> Array:
	var out = [Kit.pill("star", "+%s" % Xp.fmt_int(boss.xp), Pal.ACCENT, "Hero XP for the knockout", null, 13)]
	if boss.get("rewardItem") != null:
		var it = Items.by_id(boss.rewardItem)
		if it != null:
			out.append(Kit.pill("gift", it.name, Pal.rarity(it.rarity), "Drops unique gear: %s" % it.name, null, 12))
	return out


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
	var all_bosses = Campaign.bosses()

	# --- the current boss: the star of the screen ------------------------------
	var card = Kit.card(8, Callable(), 16)
	card.accent(Pal.HP, true)
	var zl = Kit.label(("Endless Trials" if echo else "Zone %d · %s" % [int(boss.zone) + 1, zones[int(boss.zone)].name]).to_upper(), 11, Pal.with_alpha(Pal.TEXT, 0.7), true)
	zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add(zl)
	# The boss in its arena: a spotlight, a floor to stand on (or float over).
	var arena = PanelContainer.new()
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(Pal.HP).darkened(0.4), {"ring": null, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	var ground = Stage.new()
	ground.setup(Pal.HP, 4)
	ground.shadow_px = 0
	ground.floor_color = Pal.deep(Pal.HP).lightened(0.1)
	arena.add_child(ground)
	var bv = BossView.new()
	bv.setup(boss.id, 150.0, true)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.size_flags_vertical = Control.SIZE_SHRINK_END
	var stand = Kit.pad(bv, 0, 8, 0, 12)
	stand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(stand)
	card.add(arena)
	var name_up = str(boss.name).to_upper()
	if PixelFont.measure(name_up).x * 2 <= 370:
		card.add(Kit.big_number(name_up, Pal.TEXT, 370, 3))
	else:
		var tl = Kit.para(boss.name, 18, null, true)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(tl)
	var ep = Kit.para(boss.epithet, 13, Pal.with_alpha(Pal.TEXT, 0.65))
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(ep)
	var how = "Every XP you earn from a session deals 1 damage.\nTrain its weakness for ×%s. Overkill carries over." % TTUtil.num_str(Campaign.WEAK_MULT)
	card.add(Kit.pad(Kit.hp_bar(hp_left, float(boss.hp), 22, how), 0, 2, 0, 2))
	var chips = Kit.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	var weak = boss.get("weak")
	if weak != null:
		chips.add_child(AdventureScreen.weak_pill(weak))
	for p in AdventureScreen.reward_pills(boss):
		chips.add_child(p)
	card.add(chips)
	add_child(card)

	# --- this week's bounty: a side quest sized from your own recent weeks ------
	add_child(BountyView.card(true))

	# --- three numbers ----------------------------------------------------------
	var tiles = Kit.grid(3, 8)
	tiles.add_child(_stat_tile("%d/%d" % [mini(defeated, all_bosses.size()), all_bosses.size()], "BOSSES", Pal.TEXT, "skull"))
	tiles.add_child(_stat_tile(Xp.fmt_int(c.totalDamage), "DAMAGE", Pal.ACCENT, "sword"))
	if echo:
		tiles.add_child(_stat_tile(str(defeated - all_bosses.size()), "ECHOES", Pal.TEXT, "repeat"))
	else:
		tiles.add_child(_stat_tile("%d/%d" % [int(boss.zone) + 1, zones.size()], "ZONE", Pal.TEXT, "map"))
	add_child(tiles)

	# --- zones ------------------------------------------------------------------
	add_child(Kit.section_title("Zones"))
	for zi in range(zones.size()):
		add_child(_zone_card(zi, zones[zi], c))


## A tile with a small icon, one big pixel number and a tiny caption.
func _stat_tile(value: String, caption: String, color: Color, icon: String) -> Control:
	var t = Kit.card(4, Callable(), 10)
	var top = Kit.hbox(4)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(Kit.vcenter(Icons.rect(icon, 14)))
	top.add_child(Kit.vcenter(Kit.label(caption, 11, Pal.MUTED, true)))
	t.add(top)
	t.add(Kit.big_number(value, color, 104, 3))
	return t


func _zone_card(zi: int, z: Dictionary, c: Dictionary) -> Control:
	var index = int(c.index)
	var list = Campaign.bosses_in_zone(zi)
	var reached = index >= int(list[0].index)
	var zc = Pal.hex(z.color)

	var card = Kit.card(10, Callable(), 12)
	if not reached:
		card.modulate.a = 0.6

	var head = Kit.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.tooltip_text = z.blurb if reached else "Uncharted. Keep going."
	var badge = PanelContainer.new()
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bc = zc if reached else Pal.PANEL2
	badge.add_theme_stylebox_override("panel", PixBox.make(bc, {"lip": 1, "lip_color": bc.darkened(0.45), "pad_h": 7, "pad_v": 4}))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(PixelFont.rect(str(zi + 1), 2, Color.WHITE))
	head.add_child(badge)
	head.add_child(Kit.vcenter(Kit.clip(z.name if reached else "???", 16, null, true)))
	var pips = Kit.hbox(4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for x in list:
		var bi = int(x.index)
		var pip = Panel.new()
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pip.custom_minimum_size = Vector2(14, 16)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bi < index:
			pip.add_theme_stylebox_override("panel", PixBox.make(zc, {"lip": 1, "lip_color": zc.darkened(0.45), "pad_h": 0, "pad_v": 0}))
		elif bi == index:
			pip.add_theme_stylebox_override("panel", PixBox.make(Pal.HP, {"lip": 1, "lip_color": Pal.HP.darkened(0.45), "pad_h": 0, "pad_v": 0}))
		else:
			pip.add_theme_stylebox_override("panel", PixBox.well(0, 0, null))
		pips.add_child(pip)
	head.add_child(pips)
	card.add(head)

	var grid = Kit.grid(BOSS_COLS, 6)
	for x in list:
		var bi = int(x.index)
		var status = "defeated" if bi < index else ("current" if bi == index else "locked")
		grid.add_child(_boss_tile(x.boss, bi, status))
	card.add(grid)
	return card


func _boss_tile(b: Dictionary, bi: int, status: String) -> Control:
	var known = status != "locked"
	var tile = Kit.card(2, AdventureScreen.open_boss.bind(bi), 6)
	if status == "current":
		tile.accent(Pal.HP, true)
	elif status == "defeated":
		tile.tint(Pal.PANEL2)
	var stack = MarginContainer.new()
	var bv = BossView.new()
	bv.setup(b.id, 54.0, status == "current", not known)
	bv.set_dim(status == "defeated")
	stack.add_child(Kit.center(bv))
	var marks = Kit.hbox(0)
	if b.zoneBoss:
		var crown = Icons.rect("crown", 16)
		crown.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		marks.add_child(crown)
	marks.add_child(Kit.spacer())
	if status == "defeated":
		var ck = Icons.rect("check", 18)
		ck.size_flags_vertical = Control.SIZE_SHRINK_END
		marks.add_child(ck)
	stack.add_child(marks)
	tile.add(stack)
	if status == "current":
		var hp = maxf(0.0, float(b.hp) - float(App.state.campaign.damage))
		tile.add(Kit.bar(hp / maxf(1.0, float(b.hp)), Pal.HP, 4))
	else:
		var n = Kit.clip(b.name if known else "???", 11, Pal.TEXT if known else Pal.MUTED, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add(n)
	tile.tooltip_text = b.name if known else "Unknown boss"
	Kit.passthrough(tile.box)
	return tile


## The detail sheet of one boss of the campaign.
static func open_boss(bi: int) -> void:
	var c = App.state.campaign
	var index = int(c.index)
	var b = Campaign.boss_at(bi)
	var status = "defeated" if bi < index else ("current" if bi == index else "locked")
	var known = status != "locked"
	var s = Kit.sheet(b.name if known else "Unknown boss")
	var bv = BossView.new()
	bv.setup(b.id, 120.0, status == "current", not known)
	bv.set_dim(status == "defeated")
	bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.box.add_child(bv)
	if known:
		var ep = Kit.muted_para(b.epithet, 14)
		ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.box.add_child(ep)
	var chips = Kit.flow(8)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	match status:
		"defeated":
			var at = ""
			if c.defeated.has(b.id):
				at = Dates.format_date(c.defeated[b.id].get("at", ""))
			chips.add_child(Kit.pill("check", ("Defeated " + at).strip_edges(), Pal.GOOD))
		"current":
			chips.add_child(Kit.pill("sword", "Fighting now", Pal.HP, "", Color.WHITE))
		_:
			chips.add_child(Kit.pill("lock", "%s HP" % Xp.fmt_int(b.hp), Pal.PANEL2, "", Pal.TEXT))
	if b.get("zoneBoss", false):
		chips.add_child(Kit.pill("crown", "Zone boss", Pal.ACCENT2))
	if known and b.get("weak") != null:
		chips.add_child(AdventureScreen.weak_pill(b.weak))
	for p in AdventureScreen.reward_pills(b):
		chips.add_child(p)
	s.box.add_child(chips)
	if status == "current":
		s.box.add_child(Kit.hp_bar(maxf(0.0, float(b.hp) - float(c.damage)), float(b.hp), 22))
	s.open()


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _quests(q: Dictionary) -> void:
	var week_end = Dates.add_days(Dates.week_key(App.today), 6)
	var days_left = Dates.days_between(App.today, week_end)

	var top = Kit.grid(2, 8)
	top.add_child(_quest_ring("DAILY", q.daily, "sun"))
	top.add_child(_quest_ring("WEEKLY", q.weekly, "calendar"))
	add_child(top)

	if not q.get("yesterday", []).is_empty():
		add_child(Kit.section_title("From yesterday"))
		add_child(_quest_list(q.yesterday))
	add_child(Kit.section_title("Daily", Kit.pill("clock", "Midnight", Pal.PANEL2, "Daily missions reset at midnight", Pal.TEXT, 11)))
	add_child(_quest_list(q.daily))
	var hint = "Last day!" if days_left == 0 else "%dd left" % days_left
	add_child(Kit.section_title("Weekly", Kit.pill("calendar", hint, Pal.HP if days_left == 0 else Pal.PANEL2, "Weekly missions reset on Monday", Color.WHITE if days_left == 0 else Pal.TEXT, 11)))
	add_child(_quest_list(q.weekly))


## How many quests of a kind are done, as a ring with the count under it.
func _quest_ring(caption: String, list: Array, icon: String) -> Control:
	var done = 0
	for x in list:
		if x.done:
			done += 1
	var all_done = done == list.size() and not list.is_empty()
	var t = Kit.card(4, Callable(), 10)
	if all_done:
		t.accent(Pal.GOOD)
	var row = Kit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ring = Ring.new()
	ring.setup(float(done) / float(maxi(1, list.size())), Pal.GOOD if all_done else Pal.ACCENT, 52.0, Icons.rect(icon, 24))
	row.add_child(ring)
	var v = Kit.vbox(2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(PixelFont.rect("%d/%d" % [done, list.size()], 3, Pal.GOOD if all_done else Pal.TEXT))
	v.add_child(Kit.label(caption, 11, Pal.MUTED, true))
	row.add_child(v)
	t.add(row)
	return t


## The shared compact quest rows, with the description and exact progress as a tooltip.
func _quest_list(list: Array) -> Control:
	# With the words under each title: a mission says what to aim for.
	var box = Parts.quest_list(list, false)
	var settings = App.settings()
	var rows = box.get_children()
	for i in range(mini(rows.size(), list.size())):
		var r = rows[i]
		if r is Control:
			r.tooltip_text = "%s\n%s" % [Icons.strip_emoji(list[i].desc), Parts.quest_progress_text(list[i], settings)]
	return box


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

	# --- the score ----------------------------------------------------------------
	var sum = Kit.card(10, Callable(), 14)
	sum.accent(Pal.ACCENT, true)
	var row = Kit.hbox(12)
	row.add_child(Kit.vcenter(Icons.rect("trophy", 40)))
	var score = Kit.vbox(4)
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pts = PixelFont.rect(Xp.fmt_int(points), 4, Pal.ACCENT)
	pts.tooltip_text = "Trophy points: %s of %s" % [Xp.fmt_int(points), Xp.fmt_int(max_points)]
	pts.mouse_filter = Control.MOUSE_FILTER_STOP
	score.add_child(pts)
	score.add_child(Kit.label("TROPHY POINTS", 11, Pal.with_alpha(Pal.TEXT, 0.7), true))
	row.add_child(score)
	var count = Kit.label("%d/%d" % [unlocked, all.size()], 12, null, true)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(50, 18)
	var ring = Ring.new()
	ring.setup(float(unlocked) / float(maxi(1, all.size())), Pal.ACCENT, 66.0, count)
	ring.tooltip_text = "%d of %d trophies earned" % [unlocked, all.size()]
	ring.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(Kit.vcenter(ring))
	sum.add(row)
	var room = Kit.button("Trophy room", "secondary", TrophyRoom.open, "md", "trophy")
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.tooltip_text = "Your trophies on shelves, your records on plaques, your companions"
	sum.add(room)
	var tf = Kit.hbox(6)
	for t in tiers:
		var tc = Pal.hex(Achievements.TIER_COLOR[t])
		var tp = Kit.pill(TIER_ICON[t], "%d/%d" % [tiers[t][0], tiers[t][1]], tc, "%s: %d of %d" % [t.capitalize(), tiers[t][0], tiers[t][1]], null, 13)
		tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tf.add_child(tp)
	sum.add(tf)
	add_child(sum)

	# --- filter chips -----------------------------------------------------------
	var chips = Kit.flow(6)
	chips.add_child(Kit.chip("All", _filter == "all", _set_filter.bind("all")))
	# Cycling's trophies are still there to earn; its chip goes last (Misc.SIDE).
	var groups = Achievements.groups()
	groups = groups.filter(func(g): return not Misc.SIDE.has(str(g.id))) + groups.filter(func(g): return Misc.SIDE.has(str(g.id)))
	for g in groups:
		var ch = Kit.chip(g.name, _filter == g.id, _set_filter.bind(g.id))
		ch.icon = Icons.tex(Icons.for_emoji(g.icon))
		ch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chips.add_child(ch)
	add_child(chips)

	# --- the cabinet ------------------------------------------------------------
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

	if rows.is_empty():
		add_child(Kit.empty("trophy", "Nothing here yet."))
		return
	var todo = rows.filter(func(x): return x.u == null)
	var got = rows.filter(func(x): return x.u != null)
	if not todo.is_empty():
		add_child(Kit.section_title("Next up"))
		add_child(_trophy_grid(todo))
	if not got.is_empty():
		add_child(Kit.section_title("Earned", Kit.pill("check", str(got.size()), Pal.GOOD)))
		add_child(_trophy_grid(got))


func _trophy_grid(rows: Array) -> Control:
	var grid = Kit.grid(TROPHY_COLS, 8)
	for r in rows:
		grid.add_child(_trophy_tile(r))
	return grid


static func _trophy_less(x: Dictionary, y: Dictionary) -> bool:
	var xu = x.u != null
	var yu = y.u != null
	if xu != yu:
		return not xu
	if not xu:
		return x.ratio > y.ratio
	return str(x.u.get("at", "")) > str(y.u.get("at", ""))


## The trophy's icon on a plate: tier-coloured and raised when earned, a dark
## sunken well when not.
static func trophy_plate(r: Dictionary, px: int) -> Control:
	var a = r.a
	var earned = r.u != null
	var tc = Pal.hex(Achievements.TIER_COLOR[Achievements.tier_of(a)])
	var hidden = not earned and a.get("secret", false)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(px, px)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if earned:
		plate.add_theme_stylebox_override("panel", PixBox.make(tc, {"lip": 1, "lip_color": tc.darkened(0.5), "pad_h": 0, "pad_v": 0}))
	else:
		plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": Pal.with_alpha(tc, 0.55), "lip": 0, "inset": true, "pad_h": 0, "pad_v": 0}))
	var icon_name = "question" if hidden else Icons.for_emoji(a.icon)
	var ic = Icons.rect(icon_name, int(px * 0.6), null if earned else Pal.MUTED)
	plate.add_child(Kit.center(ic))
	var stack = MarginContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(plate)
	if earned:
		var marks = Kit.hbox(0)
		marks.add_child(Kit.spacer())
		var ck = Icons.rect("check", 16 if px < 70 else 22)
		ck.size_flags_vertical = Control.SIZE_SHRINK_END
		marks.add_child(ck)
		stack.add_child(Kit.pad(marks, 0, 0, -6, -4))
	return stack


func _trophy_tile(r: Dictionary) -> Control:
	var a = r.a
	var u = r.u
	var p = r.p
	var tc = Pal.hex(Achievements.TIER_COLOR[Achievements.tier_of(a)])
	var hidden = u == null and a.get("secret", false)
	var tile = Kit.card(5, AdventureScreen.open_trophy.bind(r), 8)
	if u != null:
		tile.accent(tc)
		# The rarest ones catch the light.
		if Achievements.tier_of(a) == "platinum":
			Fx.twinkle(tile, tc.lightened(0.5), 1)
	tile.add(Kit.pad(AdventureScreen.trophy_plate(r, 52), 0, 2, 0, 0))
	var n = Kit.clip("Secret trophy" if hidden else Icons.strip_emoji(a.name), 12, tc if u != null else Pal.TEXT, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add(n)
	if u == null:
		if p != null and not hidden:
			var col = Pal.disc(a.group) if TT.DISCIPLINE_META.has(a.group) else (Pal.READ if a.group == "read" else Pal.ACCENT)
			tile.add(Kit.bar(r.ratio, col, 5))
		else:
			tile.add(Kit.bar(0.0, Pal.ACCENT, 5))
	var tip = "Keep playing to discover it." if hidden else Units.text(Icons.strip_emoji(a.desc), App.settings())
	if p != null and not hidden:
		tip += "\n" + Fmt.fmt_progress(p, App.settings())
	tile.tooltip_text = tip
	Kit.passthrough(tile.box)
	return tile


## The detail sheet of one trophy.
static func open_trophy(r: Dictionary) -> void:
	var a = r.a
	var u = r.u
	var tier = Achievements.tier_of(a)
	var tc = Pal.hex(Achievements.TIER_COLOR[tier])
	var hidden = u == null and a.get("secret", false)
	var s = Kit.sheet("Secret trophy" if hidden else Icons.strip_emoji(a.name))
	s.box.add_child(AdventureScreen.trophy_plate(r, 88))
	var d = Kit.muted_para("Keep playing to discover it." if hidden else Units.text(Icons.strip_emoji(a.desc), App.settings()), 15)
	d.set_meta("trophy_desc", str(a.id))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.box.add_child(d)
	var chips = Kit.flow(8)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_child(Kit.pill(TIER_ICON[tier], tier.capitalize(), tc))
	chips.add_child(Kit.pill("star", "+%s" % Xp.fmt_int(a.xp), Pal.ACCENT))
	if u != null:
		chips.add_child(Kit.pill("check", Dates.format_date(u.get("at", "")), Pal.GOOD))
	s.box.add_child(chips)
	if r.p != null and not hidden:
		var col = Pal.disc(a.group) if TT.DISCIPLINE_META.has(a.group) else Pal.ACCENT
		s.box.add_child(Kit.bar(r.ratio, col, 12))
		var pl = Kit.label(Fmt.fmt_progress(r.p, App.settings()), 13, Pal.MUTED, true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.box.add_child(pl)
	s.open()


func _set_filter(f: String) -> void:
	if f == _filter:
		return
	_filter = f
	rebuild()
