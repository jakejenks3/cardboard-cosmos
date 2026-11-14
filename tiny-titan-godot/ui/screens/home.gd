class_name HomeScreen
extends UiScreen
## The Hero tab: your hero in the home gym, level, the boss you are fighting,
## the four discipline stats, streak, what you are closest to, today's quests
## and your latest sessions.

const SETTINGS = "res://ui/screens/settings.gd"

var _taps = 0
var _hint: Label = null


func build() -> void:
	var s = App.state
	var profile = App.profile()
	if profile == null:
		return
	var settings = App.settings()

	# --- name, title, settings ------------------------------------------------
	var top = Kit.hbox(10)
	var who = Kit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(Kit.clip(profile.name, 20, null, true))
	who.add_child(Kit.clip(s.title, 13, Pal.ACCENT, true))
	top.add_child(who)
	top.add_child(Kit.vcenter(Kit.icon_button("settings", _open_settings, "Settings")))
	add_child(top)

	# --- the hero in the gym --------------------------------------------------
	var stage_card = Kit.card(4, Callable(), 6)
	var hero = HeroView.new()
	hero.setup(s, profile, App.loadout(), App.active_pet(), true)
	hero.custom_minimum_size = Vector2(Art.SCENE_W * 4, Art.SCENE_H * 4)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.tapped.connect(_on_hero_tapped)
	stage_card.add(hero)
	_hint = Kit.muted(_hint_text(), 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_card.add(_hint)
	add_child(stage_card)

	# --- the companion (or coach) says one thing ----------------------------
	var boss = Campaign.boss_at(s.campaign.index)
	var hp_left = boss.hp - s.campaign.damage
	var goals = App.next_goals(3)
	var claimable = App.claimable_quests()
	var pet = null
	if App.active_pet() != null and s.pets.has(App.active_pet()):
		pet = Pets.by_id(App.active_pet())
	var line = Chatter.pet_line({
		"s": s,
		"today": App.today,
		"daysSinceLast": Dates.days_between(s.lastSessionDate, App.today) if s.lastSessionDate != null else null,
		"trainedToday": int(s.dateCounts.get(App.today, 0)) > 0,
		"claimable": claimable,
		"boss": boss,
		"bossHpLeft": hp_left,
		"nearest": goals[0] if goals.size() > 0 else null,
	})
	var speech = Kit.card(4, Callable(), 10)
	speech.tint(Pal.BG2, Pal.LINE)
	var srow = Kit.hbox(10)
	if pet != null:
		var pv = PetView.new()
		pv.setup(pet.id, 30.0)
		srow.add_child(Kit.vcenter(pv))
	else:
		srow.add_child(Kit.vcenter(Icons.rect("speech", 26)))
	var speaker = pet.name if pet != null else "Coach"
	srow.add_child(Kit.rich("[b]%s[/b]  %s" % [Kit.esc(speaker), Kit.esc(Icons.strip_emoji(line))], 14))
	speech.add(srow)
	add_child(speech)

	# --- hero level -----------------------------------------------------------
	var lv = s.levels.hero
	var stage = Xp.STAGES[s.stage]
	var next_stage = Xp.STAGES[s.stage + 1] if s.stage + 1 < Xp.STAGES.size() else null
	var level_card = Kit.card(8)
	var lrow = Kit.hbox(10)
	lrow.add_child(PixelFont.rect("LV %d" % int(lv.level), 3, Pal.ACCENT))
	lrow.add_child(Kit.vcenter(Kit.label(stage.name, 16, null, true)))
	lrow.add_child(Kit.spacer())
	lrow.add_child(Kit.vcenter(Kit.muted("%s at Lv %d" % [next_stage.name, int(next_stage.minLevel)] if next_stage != null else "Max stage", 12)))
	level_card.add(lrow)
	level_card.add(Kit.bar(lv.progress, Pal.ACCENT, 14))
	var xrow = Kit.hbox(8)
	xrow.add_child(Kit.muted("%s / %s XP" % [Xp.fmt_int(lv.into), Xp.fmt_int(lv.toNext)], 12))
	xrow.add_child(Kit.spacer())
	xrow.add_child(Kit.muted("%s total" % Xp.fmt_int(s.xp.hero), 12))
	level_card.add(xrow)
	add_child(level_card)

	# --- the boss you are fighting -------------------------------------------
	var boss_card = Kit.card(6, App.go.bind("adventure", "campaign"), 12)
	var brow = Kit.hbox(12)
	var bv = BossView.new()
	bv.setup(boss.id, 58.0, true)
	brow.add_child(Kit.vcenter(bv))
	var bmain = Kit.vbox(5)
	bmain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btop = Kit.hbox(8)
	btop.add_child(Kit.clip(boss.name, 15, null, true))
	if boss.get("weak") != null:
		var weak = PanelContainer.new()
		weak.add_theme_stylebox_override("panel", Kit.sbox(Pal.disc(boss.weak), 99, null, 0, 8, 2))
		weak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		weak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wrow = Kit.hbox(4)
		wrow.add_child(Kit.label("weak", 11, Pal.TEXT, true))
		wrow.add_child(Icons.rect(boss.weak, 14))
		weak.add_child(wrow)
		btop.add_child(weak)
	bmain.add_child(btop)
	bmain.add_child(Kit.bar(float(hp_left) / float(boss.hp), Pal.HP, 10))
	var zone_name = "Endless Trials" if Campaign.is_echo(s.campaign.index) else Campaign.ZONES[boss.zone].name
	var hp_row = Kit.hbox(4)
	hp_row.add_child(Icons.rect("heart", 12))
	hp_row.add_child(Kit.clip("%s / %s HP · %s" % [Xp.fmt_int(hp_left), Xp.fmt_int(boss.hp), zone_name], 11, Pal.MUTED))
	bmain.add_child(hp_row)
	brow.add_child(bmain)
	brow.add_child(Kit.vcenter(Icons.rect("chevron_right", 16, Pal.MUTED)))
	boss_card.add(brow)
	add_child(boss_card)

	# --- the four disciplines -------------------------------------------------
	var grid = Kit.grid(2, 10)
	for d in TT.DISCIPLINES:
		var l = s.levels[d]
		var meta = TT.DISCIPLINE_META[d]
		var rank = Xp.RANKS[s.ranks[d]]
		var c = Kit.card(6, App.open_log.bind(d), 12)
		var head = Kit.hbox(8)
		head.add_child(Icons.rect(d, 22))
		head.add_child(Kit.vcenter(Kit.label(meta.stat, 13, Pal.MUTED, true)))
		head.add_child(Kit.spacer())
		head.add_child(PixelFont.rect(str(int(l.level)), 2, Pal.TEXT))
		c.add(head)
		c.add(Kit.bar(l.progress, Pal.disc(d), 7))
		var foot = Kit.hbox(4)
		foot.add_child(Kit.label(rank.name, 11, Pal.hex(rank.color), true))
		foot.add_child(Kit.clip("· %s XP to next" % Xp.fmt_int(l.toNext - l.into), 11, Pal.MUTED))
		c.add(foot)
		grid.add_child(c)
	add_child(grid)

	# --- weekly streak --------------------------------------------------------
	var streak = s.streak
	var sc = Kit.card(6, Callable(), 12)
	var strow = Kit.hbox(12)
	strow.add_child(Kit.vcenter(Icons.rect("flame" if streak.current > 0 else "ember", 34)))
	var st = Kit.vbox(1)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(Kit.label("%d week%s streak" % [int(streak.current), "" if int(streak.current) == 1 else "s"], 16, null, true))
	st.add_child(Kit.muted("Best %d · %d/%d sessions this week" % [int(streak.best), int(streak.thisWeek), int(streak.goal)], 12))
	strow.add_child(st)
	var dots = Kit.hbox(5)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(int(streak.goal)):
		var dot = Panel.new()
		var on = i < int(streak.thisWeek)
		dot.add_theme_stylebox_override("panel", Kit.sbox(Pal.ACCENT if on else Pal.WELL, 99, Pal.ACCENT if on else Pal.LINE, 1, 0, 0))
		dot.custom_minimum_size = Vector2(13, 13)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	strow.add_child(dots)
	sc.add(strow)
	add_child(sc)

	# --- gear bonus -----------------------------------------------------------
	var bits = []
	for d in TT.DISCIPLINES:
		if float(App.perks.xp[d]) > 0.0:
			bits.append("+%d%% %s" % [TTUtil.jsround(float(App.perks.xp[d]) * 100.0), TT.DISCIPLINE_META[d].name.to_lower()])
	if float(App.perks.luck) > 0.0:
		bits.append("+%d%% luck" % TTUtil.jsround(float(App.perks.luck) * 100.0))
	if bits.size() > 0:
		var prow = Kit.hbox(6)
		prow.add_child(Icons.rect("sparkle", 16))
		prow.add_child(Kit.para("Gear bonus: " + ", ".join(PackedStringArray(bits)), 12, Pal.MUTED))
		add_child(prow)

	# --- almost there ---------------------------------------------------------
	if goals.size() > 0:
		add_child(Kit.section_title("Almost there", Kit.link("All trophies →", App.go.bind("adventure", "trophies"))))
		var gl = Kit.vbox(8)
		for g in goals:
			gl.add_child(Parts.goal_row(g))
		add_child(gl)

	# --- today's quests -------------------------------------------------------
	add_child(Kit.section_title("Today's quests", Kit.link("All quests →", App.go.bind("adventure", "quests"))))
	add_child(Parts.quest_list(App.quests().daily, true))

	# --- recent sessions ------------------------------------------------------
	var sessions = App.sessions()
	var right = null
	if sessions.size() > 0:
		right = Kit.link("History →", App.go.bind("journey", "history"))
	add_child(Kit.section_title("Recent", right))
	if sessions.is_empty():
		var none = Kit.card()
		var msg = Kit.muted_para("No sessions yet. Your first one earns XP, your first trophies and a companion.", 13)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add(msg)
		add_child(none)
	else:
		var recent = sessions.duplicate()
		TTUtil.stable_sort(recent, func(a, b): return a.createdAt > b.createdAt)
		var list = Kit.vbox(8)
		for i in range(mini(3, recent.size())):
			var sess = recent[i]
			list.add_child(Parts.session_row(sess, s.sessionXp.get(sess.id, 0)))
		add_child(list)

	var log_btn = Kit.button("Log a workout", "primary", App.open_log.bind(null), "lg", "plus")
	log_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(log_btn)


func _hint_text() -> String:
	if _taps == 0:
		return "Tap your hero to flex"
	if _taps < 3:
		return "Looking strong."
	return "Okay, okay, we get it."


func _on_hero_tapped() -> void:
	_taps += 1
	if is_instance_valid(_hint):
		_hint.text = _hint_text()


func _open_settings() -> void:
	Sfx.tap()
	if ResourceLoader.exists(SETTINGS):
		load(SETTINGS).open()
	else:
		App.toast("Settings are not available yet.", "info")
