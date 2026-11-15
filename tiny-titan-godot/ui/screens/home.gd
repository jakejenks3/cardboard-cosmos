class_name HomeScreen
extends UiScreen
## The Hero tab, built to be looked at rather than read: your hero in the gym
## with the level and XP bar under it, the boss you are fighting, a bright
## tile per discipline, your streak, the goals you are closest to as rings,
## today's quests and your latest sessions.

const SETTINGS = "res://ui/screens/settings.gd"


func build() -> void:
	var s = App.state
	var profile = App.profile()
	if profile == null:
		return

	# --- name, title, settings ------------------------------------------------
	var top = Kit.hbox(10)
	var who = Kit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(Kit.clip(profile.name, 22, null, true))
	who.add_child(Kit.clip(s.title, 13, Pal.ACCENT, true))
	top.add_child(who)
	top.add_child(Kit.vcenter(Kit.icon_button("settings", _open_settings, "Settings")))
	add_child(top)

	# --- new entries from the phone inbox (never opened by itself) -----------
	var pend = App.inbox.pending() if App.inbox != null else []
	if not pend.is_empty():
		var ic = Kit.card(4, InboxSheet.open_pending, 10)
		ic.accent(Pal.GOOD)
		var irow = Kit.hbox(10)
		irow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		irow.add_child(Kit.vcenter(Icons.rect("speech", 26)))
		var n = pend.size()
		irow.add_child(Kit.para("%d new entr%s from your phone" % [n, "y" if n == 1 else "ies"], 15, null, true))
		irow.add_child(Kit.vcenter(Kit.tag("Review", Pal.GOOD, true, 12)))
		ic.add(irow)
		add_child(ic)

	# --- the hero in the gym, with the level right under it -------------------
	var lv = s.levels.hero
	var stage = Xp.STAGES[s.stage]
	var stage_card = Kit.card(8, Callable(), 8)
	stage_card.accent(Pal.ACCENT)
	var hero = HeroView.new()
	hero.setup(s, profile, App.loadout(), App.active_pet(), true)
	hero.custom_minimum_size = Vector2(Art.SCENE_W * 4, Art.SCENE_H * 4)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.tooltip_text = "Tap to flex"
	stage_card.add(hero)
	var lrow = Kit.hbox(10)
	var badge = PanelContainer.new()
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.add_theme_stylebox_override("panel", PixBox.make(Pal.ACCENT, {"lip": 1, "lip_color": Pal.ACCENT_DARK, "pad_h": 9, "pad_v": 6}))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(PixelFont.rect("LV %d" % int(lv.level), 3, Pal.INK, false))
	lrow.add_child(badge)
	var lmain = Kit.vbox(4)
	lmain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lmain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lhead = Kit.hbox(6)
	lhead.add_child(Kit.clip(stage.name, 16, null, true))
	lhead.add_child(Kit.muted("%s / %s" % [Xp.fmt_int(lv.into), Xp.fmt_int(lv.toNext)], 11))
	lmain.add_child(lhead)
	lmain.add_child(Kit.bar(lv.progress, Pal.ACCENT, 12))
	lrow.add_child(lmain)
	stage_card.add(Kit.pad(lrow, 4, 0, 4, 2))
	add_child(stage_card)

	# --- the companion (or coach) says one thing ----------------------------
	var boss = Campaign.boss_at(s.campaign.index)
	var hp_left = boss.hp - s.campaign.damage
	var goals = App.next_goals(3)
	var pet = null
	if App.active_pet() != null and s.pets.has(App.active_pet()):
		pet = Pets.by_id(App.active_pet())
	var line = Chatter.pet_line({
		"s": s,
		"today": App.today,
		"daysSinceLast": Dates.days_between(s.lastSessionDate, App.today) if s.lastSessionDate != null else null,
		"trainedToday": int(s.dateCounts.get(App.today, 0)) > 0,
		"claimable": App.claimable_quests(),
		"boss": boss,
		"bossHpLeft": hp_left,
		"nearest": goals[0] if goals.size() > 0 else null,
	})
	var srow = Kit.hbox(10)
	if pet != null:
		var pv = PetView.new()
		pv.setup(pet.id, 34.0, true)
		srow.add_child(Kit.vcenter(pv))
	else:
		srow.add_child(Kit.vcenter(Icons.rect("speech", 28)))
	var bubble = PanelContainer.new()
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.add_theme_stylebox_override("panel", PixBox.make(Pal.TEXT, {"lip": 1, "lip_color": Pal.MUTED.darkened(0.3), "pad_h": 12, "pad_v": 7}))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_child(Kit.para(Icons.strip_emoji(line), 14, Pal.INK, true))
	srow.add_child(bubble)
	add_child(srow)

	# --- the boss you are fighting -------------------------------------------
	var boss_card = Kit.card(6, App.go.bind("adventure", "campaign"), 10)
	boss_card.accent(Pal.HP, true)
	var brow = Kit.hbox(12)
	var bv = BossView.new()
	bv.setup(boss.id, 64.0, true)
	brow.add_child(Kit.vcenter(bv))
	var bmain = Kit.vbox(5)
	bmain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bmain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var btop = Kit.hbox(8)
	btop.add_child(Kit.clip(boss.name, 16, null, true))
	if boss.get("weak") != null:
		var weak = PanelContainer.new()
		weak.add_theme_stylebox_override("panel", Kit.sbox(Pal.disc(boss.weak), 5, null, 0, 6, 2))
		weak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		weak.mouse_filter = Control.MOUSE_FILTER_STOP
		weak.tooltip_text = "Weak to %s: those sessions hit for ×1.5" % TT.DISCIPLINE_META[boss.weak].name.to_lower()
		var wrow = Kit.hbox(3)
		wrow.add_child(Icons.rect(boss.weak, 16))
		wrow.add_child(Kit.label("×1.5", 11, Color.WHITE, true))
		weak.add_child(wrow)
		btop.add_child(weak)
	bmain.add_child(btop)
	bmain.add_child(Kit.bar(float(hp_left) / float(boss.hp), Pal.HP, 14))
	var hp_row = Kit.hbox(4)
	hp_row.add_child(Icons.rect("heart", 14))
	hp_row.add_child(Kit.clip("%s / %s" % [Xp.fmt_int(hp_left), Xp.fmt_int(boss.hp)], 12, Pal.TEXT, true))
	bmain.add_child(hp_row)
	brow.add_child(bmain)
	brow.add_child(Kit.vcenter(Icons.rect("chevron_right", 18)))
	boss_card.add(brow)
	add_child(boss_card)

	# --- the four disciplines: one bright tile each ---------------------------
	var tiles = Kit.grid(4, 8)
	for d in TT.DISCIPLINES:
		tiles.add_child(Parts.stat_tile(d, s.levels[d]))
	add_child(tiles)

	# --- weekly streak --------------------------------------------------------
	var streak = s.streak
	var sc = Kit.card(6, Callable(), 10)
	if int(streak.current) > 0:
		sc.accent(Pal.ACCENT2)
	sc.tooltip_text = "Hit your weekly goal to keep the streak. Best: %d weeks." % int(streak.best)
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var strow = Kit.hbox(10)
	strow.add_child(Kit.vcenter(Icons.rect("flame" if int(streak.current) > 0 else "ember", 34)))
	strow.add_child(Kit.vcenter(PixelFont.rect(str(int(streak.current)), 4, Pal.ACCENT2 if int(streak.current) > 0 else Pal.MUTED)))
	var st = Kit.label("week streak" if int(streak.current) != 1 else "week streak", 14, null, true)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strow.add_child(Kit.vcenter(st))
	var dots = Kit.hbox(4)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(int(streak.goal)):
		var on = i < int(streak.thisWeek)
		var dot = Panel.new()
		dot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if on:
			dot.add_theme_stylebox_override("panel", PixBox.make(Pal.ACCENT, {"lip": 1, "lip_color": Pal.ACCENT_DARK, "pad_h": 0, "pad_v": 0}))
		else:
			dot.add_theme_stylebox_override("panel", PixBox.well(0, 0, null))
		dot.custom_minimum_size = Vector2(18, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	strow.add_child(dots)
	sc.add(strow)
	add_child(sc)

	# --- almost there: the closest goals as rings -----------------------------
	if goals.size() > 0:
		add_child(Kit.section_title("Almost there", Kit.link("All →", App.go.bind("adventure", "trophies"))))
		var grow = Kit.grid(goals.size(), 8)
		for g in goals:
			grow.add_child(Parts.goal_tile(g))
		add_child(grow)

	# --- today's quests -------------------------------------------------------
	add_child(Kit.section_title("Quests", Kit.link("All →", App.go.bind("adventure", "quests"))))
	add_child(Parts.quest_list(App.quests().daily, true))

	# --- recent sessions ------------------------------------------------------
	var sessions = App.sessions()
	if sessions.is_empty():
		var first = Kit.button("Log your first workout", "primary", App.open_log.bind(null), "lg", "plus")
		first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(first)
	else:
		add_child(Kit.section_title("Recent", Kit.link("All →", App.go.bind("journey", "history"))))
		var recent = sessions.duplicate()
		TTUtil.stable_sort(recent, func(a, b): return a.createdAt > b.createdAt)
		var list = Kit.vbox(8)
		for i in range(mini(3, recent.size())):
			var sess = recent[i]
			list.add_child(Parts.session_row(sess, s.sessionXp.get(sess.id, 0)))
		add_child(list)


func _open_settings() -> void:
	if ResourceLoader.exists(SETTINGS):
		load(SETTINGS).open()
	else:
		App.toast("Settings are not available yet.", "info")
