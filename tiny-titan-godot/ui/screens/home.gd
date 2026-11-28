class_name HomeScreen
extends UiScreen
## The Hero tab. Since 2026-11-24 (the user: "things kinda blend together and
## are hard to look at") every block is a framed SECTION with a coloured band
## across its top (Kit.section), rows inside a section are flat (Kit.row), and
## sections sit further apart (22) than the rows inside them (6-8), so the page
## reads as groups before a word is read. Top to bottom:
##   the name, title, coins and settings; slim notices when due (the phone
##   note, a new version, a backup, a recap); TODAY (the plan, to read before
##   the workout: the day's lifts with their ways and challenges, Prep today,
##   Start workout); COMING UP; TO DO; READING (its page box is filled daily);
##   MISSIONS (ready ones with their Claim key, the rest as small tiles; the
##   perfect day is the Today card's chest, not listed twice); the hero in the
##   gym with the level and the companion's line; ADVENTURE (the weekly bounty;
##   the campaign boss above it only while Campaign.ON_SCREEN, which is off
##   since 2026-11-25); PT THIS WEEK; PROJECTS; YOUR WEEK (the level tiles, the
##   streak, this week's numbers); ALMOST THERE; RECENT.

const SETTINGS = "res://ui/screens/settings.gd"
## A level tile of YOUR WEEK opens it (no class_name: loaded by path).
const DISCIPLINE_SHEET = "res://ui/screens/discipline_sheet.gd"
## Between two sections (inside one: 6 to 8).
const SECTION_GAP = 22


func build() -> void:
	var s = App.state
	var profile = App.profile()
	if profile == null:
		return
	add_theme_constant_override("separation", SECTION_GAP)

	# --- name, title, coins, settings, the hero's XP: the top bar --------------
	add_child(_top_bar(s, profile))

	# --- slim notices, only when something is due -----------------------------
	var notes = _notices()
	if notes.get_child_count() > 0:
		add_child(notes)
	else:
		notes.free()

	# --- today: the plan, first on the page, to read before the workout ------
	# (also sent to the phone in the morning: MorningAlert / PhonePush)
	# (the day's lift challenges, records to go for, are inside its lift rows since 2026-11-28: the CHALLENGES
	# section that was under it made the page "too muddled", each lift in two places)
	add_child(TodayView.card())
	# The days after it, to look ahead (nothing in it is logged).
	var coming = AheadView.card()
	if coming != null:
		add_child(coming)
	# Goals with a date (LiftGoals), once one is set.
	var lg = TrackingViews.goals_section()
	if lg != null:
		add_child(lg)
	# A plain to-do list, apart from the game (game/todos.gd).
	add_child(TodoView.card())
	# Reading: the page box is filled in every day, so it sits up here.
	add_child(ReadingView.card())
	add_child(_missions())

	# --- the hero in the gym, the level, the companion's line -----------------
	var boss = Campaign.boss_at(s.campaign.index)
	var hp_left = boss.hp - s.campaign.damage
	var goals = App.next_goals(3)
	if Campaign.ON_SCREEN:
		add_child(_hero_card(s, profile, boss, hp_left, goals))
	else:
		# The campaign is off the screens (Campaign.ON_SCREEN): the companion is
		# told of a stand-in boss, whole and with no weakness, so none of its
		# lines names a boss nobody can see (Chatter itself is a ported rule).
		add_child(_hero_card(s, profile, {"name": "", "hp": 1, "weak": null}, 1, goals))

	# --- adventure: this week's bounty (and the campaign boss when it is shown) --
	# The link goes to the Adventure tab's first page: the Bounty page (the
	# campaign, when that is shown).
	var adv_col = Pal.tab("adventure")
	var adv = Kit.section("adventure", "ADVENTURE", "sword", adv_col, Kit.link("All →", App.go.bind("adventure", "campaign"), 13, adv_col.lightened(0.5)), Callable(), 6, 10)
	if Campaign.ON_SCREEN:
		adv.add(_boss_row(boss, hp_left))
	adv.add(BountyView.card(false))
	add_child(adv)
	# Physical therapy (game/pt.gd): only when a lift is marked.
	var pt_card = PtView.card()
	if pt_card != null:
		add_child(pt_card)
	# Climbing projects (game/projects.gd): for a player who climbs.
	var pj_card = ProjectsView.card()
	if pj_card != null:
		add_child(pj_card)

	# --- your week: the level tiles, the streak, this week in numbers ---------
	add_child(_week_section(s))

	# --- almost there: the closest goals as rings -----------------------------
	if goals.size() > 0:
		var g = Kit.section("goals", "ALMOST THERE", "trophy", adv_col, Kit.link("All →", App.go.bind("adventure", "trophies"), 13, adv_col.lightened(0.5)), Callable(), 8, 10)
		var grow = Kit.grid(goals.size(), 8)
		for goal in goals:
			grow.add_child(Parts.goal_tile(goal, true))
		g.add(grow)
		add_child(g)

	# --- recent sessions ------------------------------------------------------
	var sessions = App.sessions()
	if sessions.is_empty():
		var first = Kit.button("Log your first workout", "primary", App.open_log.bind(null), "lg", "plus")
		first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(first)
	else:
		var jcol = Pal.tab("journey")
		var rc = Kit.section("recent", "RECENT", "journey", jcol, Kit.link("All →", App.go.bind("journey", "history"), 13, jcol.lightened(0.5)), Callable(), 6, 10)
		var recent = sessions.duplicate()
		TTUtil.stable_sort(recent, func(a, b): return a.createdAt > b.createdAt)
		for i in range(mini(3, recent.size())):
			var sess = recent[i]
			rc.add(Parts.session_row(sess, s.sessionXp.get(sess.id, 0), true))
		add_child(rc)


## The slim notices above Today, in this order: the phone note, a new version,
## a backup that is due, a recap that is ready. An empty box when none is due.
func _notices() -> VBoxContainer:
	var notes = Kit.vbox(6)
	var pend = App.inbox.pending() if App.inbox != null else []
	if not pend.is_empty():
		var n = pend.size()
		notes.add_child(Kit.notice("speech", "%d new entr%s from your phone" % [n, "y" if n == 1 else "ies"], "", Pal.GOOD, Kit.button("Review", "good", InboxSheet.open_pending, "sm"), InboxSheet.open_pending))
	elif App.inbox != null and App.inbox.note_all_in() > 0:
		# Everything in the note is in the game: the player can clear it.
		var n_in = App.inbox.note_all_in()
		notes.add_child(Kit.notice("check", "Phone note all imported", "%d entr%s: safe to clear it" % [n_in, "y" if n_in == 1 else "ies"], Pal.MUTED, null, InboxSheet.open_pending))
	# The phone app: a newer version is on the phone, one restart away.
	if WebUpdate.ready():
		notes.add_child(PhoneAppCard.update_card())
	# The phone app: time to make a backup file (the only copy elsewhere).
	if OS.has_feature("web") and App.backup_due():
		notes.add_child(Kit.notice("chest", "Back up your log", "Last backup: %s" % App.backup_age_text(), Pal.ACCENT2, Kit.button("Back up", "good", SettingsPanel.pick_export, "sm")))
	# A finished week or month has a recap waiting.
	var ready = _recap_ready()
	if ready != null:
		var what = "Last week's recap is ready" if ready[0] == "week" else "Your %s recap is ready" % Recap.MONTHS[int(str(ready[1]).substr(5, 2)) - 1]
		notes.add_child(Kit.notice("calendar", what, "", Pal.tab("journey"), Kit.button("Open", "blue", _open_recap.bind(ready[0], ready[1]), "sm"), _open_recap.bind(ready[0], ready[1])))
	return notes


## MISSIONS: yesterday's done ones and today's done ones as rows with their
## Claim key, then the ones still open as small tiles two across. The perfect
## day is the Today card's chest, so it is not listed here as well.
func _missions() -> Control:
	var q = App.quests()
	var yesterday = q.get("yesterday", [])
	# (the perfect day is the Today card's chest; a lift challenge is in its lift's row of the Today card, so
	# one is listed here only if no row showed it: TodayView.shown_challenges, filled as the card was drawn)
	var shown = TodayView.shown_challenges
	var daily = q.daily.filter(func(m): return not bool(m.get("perfect", false)) and not (bool(m.get("challenge", false)) and shown.has(str(m.id))))
	var done = daily.filter(func(m): return bool(m.done))
	var still = daily.filter(func(m): return not bool(m.done))
	var right = Kit.hbox(8)
	# One free swap a day, for a mission that cannot be done today (Missions.rerolled).
	# (all of today's, the challenges in the Today rows too: the swap sheet lists them all)
	var swappable = q.daily.filter(func(m): return Missions.can_reroll(m))
	if App.reroll_left() and not swappable.is_empty():
		var sw = Kit.link("Swap one", _open_swap, 13, Pal.ACCENT.lightened(0.45))
		sw.set_meta("mission_swap", swappable.size())
		right.add_child(Kit.vcenter(sw))
	right.add_child(Kit.vcenter(Kit.label("%d / %d" % [done.size(), daily.size()], 12, Pal.TEXT, true)))
	right.add_child(Kit.vcenter(Kit.link("All →", App.go.bind("adventure", "quests"), 13, Pal.ACCENT.lightened(0.45))))
	var c = Kit.section("missions", "MISSIONS", "quest", Pal.ACCENT, right, Callable(), 6, 10)
	if not yesterday.is_empty():
		c.add(Kit.sub_head("FROM YESTERDAY", Pal.GOOD))
		c.add(Parts.quest_list(yesterday, true, true))
	if not done.is_empty():
		c.add(Kit.sub_head("DONE TODAY", Pal.GOOD))
		c.add(Parts.quest_list(done, true, true))
	if not still.is_empty():
		if not yesterday.is_empty() or not done.is_empty():
			c.add(Kit.sub_head("STILL OPEN", Pal.ACCENT))
		c.add(Parts.mission_grid(still))
	return c


## The free swap of the day: pick a mission that cannot be done today; another one takes its place.
func _open_swap() -> void:
	Sfx.tap()
	var s = Kit.sheet("Swap a mission")
	s.set_meta("swap_sheet", true)
	s.box.add_child(Kit.muted_para("One swap a day, for a mission you cannot do today (equipment taken, the gym closed). Another mission takes its place.", 13))
	for m in App.quests().daily.filter(func(x): return Missions.can_reroll(x)):
		var r = Kit.row(func():
			s.close()
			if App.reroll_mission(str(m.id)):
				Sfx.pop()
				App.toast("Swapped: %s" % str(m.title), "good", "repeat"), Pal.ACCENT, null, 8, 2)
		r.set_meta("swap_pick", str(m.id))
		r.add(Kit.clip(str(m.title), 14, null, true))
		r.add(Kit.clip(str(m.desc), 11, Pal.MUTED))
		s.box.add_child(r)
	s.open()


## The top bar (the Workshop look, 2026-11-27): a wooden board with the hero's face in a gold slot and the
## level on a gold key under it, the name and title in cream, the coins in a dark cap, the settings key, and
## the hero's XP bar.
func _top_bar(s: Dictionary, profile) -> Control:
	var lv = s.levels.hero
	var board = PanelContainer.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.add_theme_stylebox_override("panel", PixBox.material("board", {"pad_h": 10, "pad_v": 9, "shadow": 2}))
	board.set_meta("top_bar", true)
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The face: the top of the hero's own picture, in a gold slot.
	var pic_box = Kit.vbox(0)
	pic_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face = PanelContainer.new()
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", PixBox.slot(Pal.ACCENT, false, 6))
	var tex = Art.hero_texture(s, profile, App.loadout())
	var at = AtlasTexture.new()
	at.atlas = tex
	var w = tex.get_width()
	at.region = Rect2(floor(w / 2.0) - 13, 0, 26, 24)
	var pic = TextureRect.new()
	pic.texture = at
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(52, 48)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(pic)
	pic_box.add_child(face)
	var badge = PanelContainer.new()
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", PixBox.block_set("gold", 8, 8, 0)["normal"])
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_child(PixelFont.rect("LV %d" % int(lv.level), 2, Pal.INK, false))
	var lift = Control.new()
	lift.custom_minimum_size = Vector2(0, 4)
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic_box.add_theme_constant_override("separation", -6)
	pic_box.add_child(badge)
	row.add_child(Kit.vcenter(pic_box))
	var right = Kit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line = Kit.hbox(8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who = Kit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l = Kit.outlined(profile.name, 21)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(name_l)
	var title_l = Kit.outlined(s.title, 13, Pal.GOLD_TEXT)
	title_l.clip_text = true
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(title_l)
	line.add_child(who)
	var purse = Kit.purse_pill(App.coins(), "Coins. Tap to open the shop.", 14)
	purse.gui_input.connect(_purse_input)
	purse.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	line.add_child(Kit.vcenter(purse))
	line.add_child(Kit.vcenter(Kit.icon_button("settings", _open_settings, "Settings")))
	right.add_child(line)
	# The XP to the next level, written on the bar.
	var xp = MarginContainer.new()
	xp.mouse_filter = Control.MOUSE_FILTER_STOP
	xp.tooltip_text = "Hero XP to level %d" % (int(lv.level) + 1)
	xp.add_child(Kit.bar(lv.progress, Pal.BOUNTY, 18))
	var cap = Kit.outlined("XP %s / %s" % [Xp.fmt_int(lv.into), Xp.fmt_int(lv.toNext)], 12)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc = Kit.center(cap)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp.add_child(cc)
	right.add_child(xp)
	row.add_child(right)
	board.add_child(row)
	return board


## The hero in the gym (tap to flex) and the companion's line in a bubble inside the same card (the
## companion stands in the gym). The level is in the top bar.
func _hero_card(s: Dictionary, profile, boss: Dictionary, hp_left, goals: Array) -> Control:
	var stage_card = Kit.card(8, Callable(), 8)
	var hero = HeroView.new()
	hero.setup(s, profile, App.loadout(), App.active_pet(), true)
	hero.custom_minimum_size = Vector2(Art.SCENE_W * 4, Art.SCENE_H * 4)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.tooltip_text = "Tap to flex"
	stage_card.add(hero)
	# (The level and its XP are in the top bar since 2026-11-27.)
	# The companion (or coach) says one thing.
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
	var bubble = PanelContainer.new()
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL2, {"ring": Pal.BORDER, "lip": 1, "pad_h": 10, "pad_v": 6}))
	var brow = Kit.hbox(8)
	brow.add_child(Kit.vcenter(Icons.rect("speech", 16)))
	var said = Kit.para(Icons.strip_emoji(line), 13, Pal.TEXT, true)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(said)
	bubble.add_child(brow)
	stage_card.add(Kit.pad(bubble, 4, 0, 4, 2))
	return stage_card


## The campaign boss as a row of the Adventure section: a strong red, so it is
## never confused with the violet bounty under it. Only drawn while the campaign
## is on the screens (Campaign.ON_SCREEN).
func _boss_row(boss: Dictionary, hp_left) -> Control:
	var c = Kit.row(App.go.bind("adventure", "campaign"), Pal.HP, Pal.HP, 8, 4, 0.4)
	var brow = Kit.hbox(10)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv = BossView.new()
	bv.setup(boss.id, 56.0, true)
	brow.add_child(Kit.vcenter(bv))
	var bmain = Kit.vbox(4)
	bmain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bmain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bmain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btop = Kit.hbox(8)
	var kick = Kit.label("CAMPAIGN BOSS", 11, Pal.HP.lightened(0.3), true)
	btop.add_child(Kit.vcenter(kick))
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
	bmain.add_child(Kit.clip(boss.name, 15, null, true))
	bmain.add_child(Kit.bar(float(hp_left) / float(boss.hp), Pal.HP, 12))
	var hp_row = Kit.hbox(4)
	hp_row.add_child(Icons.rect("heart", 14))
	hp_row.add_child(Kit.clip("%s / %s" % [Xp.fmt_int(hp_left), Xp.fmt_int(boss.hp)], 12, Pal.TEXT, true))
	bmain.add_child(hp_row)
	brow.add_child(bmain)
	brow.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(brow)
	return c


## YOUR WEEK: the three level tiles (Misc.MAIN: cycling is kept in the
## Miscellaneous area; a tap opens the discipline's sheet), the week streak,
## and this week against last.
func _week_section(s: Dictionary) -> Control:
	var sec = Kit.section("week", "YOUR WEEK", "calendar", Pal.tab("journey"), null, Callable(), 8, 10)
	var tiles = Kit.grid(Misc.MAIN.size(), 8)
	for d in Misc.MAIN:
		# A tap goes deeper: the discipline's own sheet (level, numbers, the
		# Journey card, recent sessions), with "Log one" in it.
		var tile = Parts.stat_tile(d, s.levels[d], func(): load(DISCIPLINE_SHEET).open(str(d)))
		tile.tooltip_text += "
Tap for your %s numbers" % str(TT.DISCIPLINE_META[d].name).to_lower()
		tiles.add_child(tile)
	sec.add(tiles)
	var streak = s.streak
	var on = int(streak.current) > 0
	var sc = Kit.row(Callable(), Pal.ACCENT2 if on else Pal.LINE, Pal.ACCENT2 if on else null, 8, 0, 0.12)
	sc.tooltip_text = "Hit your weekly goal to keep the streak. Best: %d weeks." % int(streak.best)
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var strow = Kit.hbox(10)
	strow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flame = Icons.rect("flame" if on else "ember", 30)
	if on:
		Fx.flicker(flame)
		Fx.embers(flame, Pal.ACCENT2, 3)
	strow.add_child(Kit.vcenter(flame))
	strow.add_child(Kit.vcenter(PixelFont.rect(str(int(streak.current)), 3, Pal.ACCENT2 if on else Pal.MUTED)))
	var st = Kit.label("week streak", 14, null, true)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strow.add_child(Kit.vcenter(st))
	var dots = Kit.hbox(4)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(int(streak.goal)):
		var dot = Panel.new()
		dot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if i < int(streak.thisWeek):
			dot.add_theme_stylebox_override("panel", PixBox.make(Pal.ACCENT, {"lip": 1, "lip_color": Pal.ACCENT_DARK, "pad_h": 0, "pad_v": 0}))
		else:
			dot.add_theme_stylebox_override("panel", PixBox.well(0, 0, null))
		dot.custom_minimum_size = Vector2(18, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	strow.add_child(dots)
	sc.add(strow)
	sec.add(sc)
	sec.add(_week_card(s))
	return sec


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
	var c = Kit.row(RecapSheet.open.bind("week", wk), Pal.SECOND, null, 8, 6)
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
