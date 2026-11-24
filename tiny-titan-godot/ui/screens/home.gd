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
	var purse = Kit.purse_pill(App.coins(), "Coins. Tap to open the shop.", 13)
	purse.gui_input.connect(_purse_input)
	purse.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	top.add_child(Kit.vcenter(purse))
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
	elif App.inbox != null and App.inbox.note_all_in() > 0:
		# Everything in the note is in the game: the player can clear it.
		var n_in = App.inbox.note_all_in()
		var dc = Kit.card(4, InboxSheet.open_pending, 8)
		var drow = Kit.hbox(8)
		drow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drow.add_child(Kit.vcenter(Icons.rect("check", 18)))
		drow.add_child(Kit.para("Phone note all imported (%d entr%s): safe to clear it" % [n_in, "y" if n_in == 1 else "ies"], 12, Pal.MUTED))
		dc.add(drow)
		add_child(dc)

	# --- the phone app: a newer version is on the phone, one restart away --------
	if WebUpdate.ready():
		add_child(PhoneAppCard.update_card())

	# --- the phone app: time to make a backup file (the only copy elsewhere) ------
	if OS.has_feature("web") and App.backup_due():
		var bc = Kit.card(6, Callable(), 10)
		bc.accent(Pal.ACCENT)
		var brow = Kit.hbox(10)
		brow.add_child(Kit.vcenter(Icons.rect("chest", 26)))
		var bv = Kit.vbox(0)
		bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bv.add_child(Kit.clip("Back up your log", 15, null, true))
		bv.add_child(Kit.clip("Last backup: %s" % App.backup_age_text(), 12, Pal.MUTED))
		brow.add_child(bv)
		brow.add_child(Kit.vcenter(Kit.button("Back up", "primary", SettingsPanel.pick_export, "sm")))
		bc.add(brow)
		add_child(bc)

	# --- a finished week or month has a recap waiting ---------------------------
	var ready = _recap_ready()
	if ready != null:
		var rc = Kit.card(4, _open_recap.bind(ready[0], ready[1]), 10)
		rc.accent(Pal.tab("journey"), true)
		var rrow = Kit.hbox(10)
		rrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rrow.add_child(Kit.vcenter(Icons.rect("calendar", 26)))
		var what = "Last week's recap is ready" if ready[0] == "week" else "Your %s recap is ready" % Recap.MONTHS[int(str(ready[1]).substr(5, 2)) - 1]
		var rl = Kit.para(what, 15, null, true)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(rl)
		rrow.add_child(Kit.vcenter(Kit.tag("Open", Pal.tab("journey"), true, 12)))
		rc.add(rrow)
		add_child(rc)

	# --- today: what is probably next, and the day's missions ------------------
	# First on the page, to read before the workout (also sent to the phone in
	# the morning: MorningAlert).
	add_child(TodayView.card())
	# The days after it, to look ahead (nothing in it is logged).
	var coming = AheadView.card()
	if coming != null:
		add_child(coming)
	# A plain to-do list, apart from the game (game/todos.gd).
	add_child(TodoView.card())
	var yesterday = App.quests().get("yesterday", [])
	if not yesterday.is_empty():
		add_child(Kit.section_title("From yesterday"))
		add_child(Parts.quest_list(yesterday, true))
	add_child(Kit.section_title("Missions", Kit.link("All →", App.go.bind("adventure", "quests"))))
	add_child(Parts.quest_list(App.quests().daily, true))

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
	Fx.shine(badge, 5.0, 1.4)
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
		pv.setup(pet.id, 40.0, true)
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
	bv.setup(boss.id, 72.0, true)
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

	# --- this week's bounty ----------------------------------------------------
	add_child(BountyView.card(false))
	# Physical therapy (game/pt.gd): only when a lift is marked, and high up,
	# because keeping up with it is the point.
	var pt_card = PtView.card()
	if pt_card != null:
		add_child(pt_card)
	# Climbing projects (game/projects.gd): for a player who climbs.
	var pj_card = ProjectsView.card()
	if pj_card != null:
		add_child(pj_card)

	# --- the main disciplines: one bright tile each (cycling is kept in the
	# Miscellaneous area: Misc.MAIN) -------------------------------------------
	var tiles = Kit.grid(Misc.MAIN.size(), 8)
	for d in Misc.MAIN:
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
	var flame = Icons.rect("flame" if int(streak.current) > 0 else "ember", 34)
	if int(streak.current) > 0:
		Fx.flicker(flame)
		Fx.embers(flame, Pal.ACCENT2, 3)
	strow.add_child(Kit.vcenter(flame))
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

	# --- reading: today's pages, one tap to add more ---------------------------
	add_child(ReadingView.card())

	# --- this week in numbers, against last week -----------------------------
	add_child(_week_card(s))

	# --- almost there: the closest goals as rings -----------------------------
	if goals.size() > 0:
		add_child(Kit.section_title("Almost there", Kit.link("All →", App.go.bind("adventure", "trophies"))))
		var grow = Kit.grid(goals.size(), 8)
		for g in goals:
			grow.add_child(Parts.goal_tile(g))
		add_child(grow)

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


## XP, sessions per discipline and PRs of one Monday-week.
func _week_numbers(s: Dictionary, wk: String) -> Dictionary:
	var out = {"xp": 0, "sessions": 0, "by": {}, "prs": 0}
	for i in range(7):
		out.xp += int(s.xpByDate.get(Dates.add_days(wk, i), 0))
	for sess in App.sessions():
		if Dates.week_key(str(sess.date)) == wk:
			out.sessions += 1
			out.by[sess.discipline] = int(out.by.get(sess.discipline, 0)) + 1
	for c in s.chronicle:
		if str(c.get("kind", "")) == "pr" and Dates.week_key(str(c.date)) == wk:
			out.prs += 1
	return out


## "This week": XP in big pixels with the change against last week, then a
## chip per discipline trained and one for the records set.
func _week_card(s: Dictionary) -> Control:
	var wk = Dates.week_key(App.today)
	var now = _week_numbers(s, wk)
	var last = _week_numbers(s, Dates.add_weeks(wk, -1))
	var c = Kit.card(6, RecapSheet.open.bind("week", wk), 10)
	c.accent(Pal.SECOND)
	c.tooltip_text = "Monday to Sunday. Tap for this week's recap."
	var head = Kit.hbox(8)
	var ttl = Kit.clip("This week", 14, null, true)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ttl)
	if last.sessions > 0:
		head.add_child(Kit.vcenter(Kit.muted("last week %s XP · %d session%s" % [Xp.fmt_int(last.xp), last.sessions, "" if last.sessions == 1 else "s"], 11)))
	c.add(head)
	var row = Kit.hbox(8)
	row.add_child(Kit.vcenter(PixelFont.rect(Xp.fmt_int(now.xp), 3, Pal.ACCENT if now.xp > 0 else Pal.MUTED)))
	row.add_child(Kit.vcenter(Kit.label("XP", 12, Pal.MUTED, true)))
	if last.xp > 0 and now.xp != last.xp:
		var up = now.xp > last.xp
		var delta = Kit.tag(("▲ " if up else "▼ ") + Xp.fmt_int(absi(now.xp - last.xp)), Pal.GOOD if up else Pal.DANGER, false, 11)
		delta.tooltip_text = "Against last week's total"
		delta.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(Kit.vcenter(delta))
	row.add_child(Kit.spacer())
	c.add(row)
	var chips = Kit.flow(6)
	for d in TT.SESSION_KINDS:
		var n = int(now.by.get(d, 0))
		if n > 0:
			chips.add_child(Kit.icon_chip(d, str(n), Pal.disc(d), "%d %s session%s" % [n, TT.DISCIPLINE_META[d].name.to_lower(), "" if n == 1 else "s"], Color.WHITE))
	if now.prs > 0:
		chips.add_child(Kit.icon_chip("medal", "%d PR%s" % [now.prs, "" if now.prs == 1 else "s"], Pal.ACCENT, "Records set this week", Color.WHITE))
	var read_pages = Reading.pages_between(s, wk, Dates.add_days(wk, 6))
	if read_pages > 0:
		chips.add_child(Kit.icon_chip("book", "%s page%s" % [Xp.fmt_int(read_pages), "" if read_pages == 1 else "s"], Pal.READ, "Pages read this week"))
	if now.sessions == 0:
		chips.add_child(Kit.vcenter(Kit.muted("nothing logged yet: the week is young", 12)))
	c.add(chips)
	return c


## The recap to offer: last month's in the first week of a month, else last
## week's from Monday to Wednesday; only when something was logged in it and
## it was not opened yet. [kind, key] or null.
func _recap_ready():
	var today = App.today
	var seen = App.recap_seen()
	var options = []
	if int(today.substr(8, 2)) <= 7:
		options.append(["month", Recap.shift("month", today.substr(0, 7), -1)])
	if Dates.weekday_index(today) <= 2:
		options.append(["week", Dates.add_weeks(Dates.week_key(today), -1)])
	for o in options:
		if str(seen.get(o[0], "")) == o[1]:
			continue
		var b = Recap.bounds(o[0], o[1])
		for x in App.sessions():
			if str(x.date) >= b[0] and str(x.date) <= b[1]:
				return o
	return null


func _open_recap(kind: String, key: String) -> void:
	App.mark_recap_seen(kind, key)
	RecapSheet.open(kind, key)


func _purse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		App.open_shop()


func _open_settings() -> void:
	if ResourceLoader.exists(SETTINGS):
		load(SETTINGS).open()
	else:
		App.toast("Settings are not available yet.", "info")
