extends RefCounted
## Walkthrough: the Hero tab (and onboarding when started with the "fresh" data).
## Since 2026-11-24 it also checks the page's sections (Kit.section, meta
## "section"): their order, the gap between them, and that nothing in MISSIONS
## repeats a Today done box. Since 2026-11-26: a level tile of YOUR WEEK opens
## the discipline's sheet (ui/screens/discipline_sheet.gd), not the log form.

var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func run(main: Node, tree: SceneTree) -> void:
	if not App.has_profile():
		await ShotHelper.snap(tree, "onboarding_1")
		var name_box = null
		for n in ShotHelper.walk(main):
			if n is LineEdit:
				name_box = n
		ShotHelper.type_into(name_box, "Jake")
		await ShotHelper.frames(tree, 2)
		ShotHelper.press(ShotHelper.find_button(main, "Next"))
		await ShotHelper.frames(tree, 3)
		ShotHelper.press(ShotHelper.find_button(main, "Curly"))
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "onboarding_2")
		ShotHelper.press(ShotHelper.find_button(main, "Next"))
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "onboarding_3")
		ShotHelper.press(ShotHelper.find_button(main, "Start my journey"))
		await ShotHelper.frames(tree, 6)
		print("profile: ", App.profile())
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "home_1")
	_sections(main)
	ShotHelper.scroll_main(main, 560)
	await ShotHelper.snap(tree, "home_2")
	ShotHelper.scroll_main(main, 1200)
	await ShotHelper.snap(tree, "home_3")
	ShotHelper.scroll_main(main, 1900)
	await ShotHelper.snap(tree, "home_4")
	ShotHelper.scroll_main(main, 2600)
	await ShotHelper.snap(tree, "home_5")
	ShotHelper.scroll_main(main, 99999)
	await ShotHelper.snap(tree, "home_6")
	await _tiles(main, tree)
	print("level ", App.state.levels.hero.level, " sessions ", App.sessions().size(), " bounty ", Bounty.monster(Bounty.of(App.state).current.monster).name, " (campaign boss, %s: " % ("shown" if Campaign.ON_SCREEN else "not shown"), Campaign.boss_at(App.state.campaign.index).name, ")")
	print("home checks failed: ", fails)


## The discipline sheets that are open (not on their way out).
func _disc_sheets() -> Array:
	return Kit.overlay_root.get_children().filter(func(c): return c.has_meta("disc_sheet") and not c._closing)


func _with_meta(n: Node, key: String) -> Array:
	return ShotHelper.walk(n).filter(func(c): return c.has_meta(key))


## The level tiles of YOUR WEEK: a tap opens the discipline's sheet with its
## level, headline tiles, the Journey card, five weeks, the last sessions and
## the two keys; "Log one" opens that discipline's log form.
func _tiles(main: Node, tree: SceneTree) -> void:
	for d in Misc.MAIN:
		App.go("home")
		await ShotHelper.frames(tree, 4)
		var tile = _with_meta(main, "stat_tile").filter(func(t): return str(t.get_meta("stat_tile")) == d)
		check(tile.size() == 1, "%s: its level tile is on the Hero tab" % d)
		if tile.size() != 1:
			continue
		ShotHelper.reveal(tile[0])
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, tile[0])
		await ShotHelper.wait(tree, 0.5)
		var open = _disc_sheets()
		check(open.size() == 1 and str(open[0].get_meta("disc_sheet")) == d and App.tab == "home", "%s: a tap on the tile opens its sheet, not the log form" % d)
		if open.size() != 1:
			continue
		var sh = open[0]
		var n = App.sessions().filter(func(x): return str(x.discipline) == d).size()
		var level = _with_meta(sh, "disc_level")
		check(level.size() == 1 and int(level[0].get_meta("disc_level")) == int(App.state.levels[d].level), "%s: the sheet shows the level" % d)
		if n == 0:
			check(_with_meta(sh, "disc_empty").size() == 1 and _with_meta(sh, "disc_log").size() == 1, "%s: nothing logged: it says so and offers \"Log one\"" % d)
		else:
			check(_with_meta(sh, "disc_tile").size() == 4, "%s: four headline tiles" % d)
			check(_with_meta(sh, "disc_card").size() == 1 and _with_meta(sh, "disc_card")[0].get_child_count() == 1, "%s: the Journey card" % d)
			check(_with_meta(sh, "disc_weeks").size() == 1, "%s: this week and the last four" % d)
			check(_with_meta(sh, "disc_recent").filter(func(r): return r.get_meta("disc_recent") is String).size() == mini(5, n), "%s: its last %d sessions" % [d, mini(5, n)])
			check(_with_meta(sh, "disc_log").size() == 1 and _with_meta(sh, "disc_all").size() == 1, "%s: the keys \"Log one\" and \"All stats\"" % d)
		check(sh.box.get_combined_minimum_size().x <= sh._scroll.size.x + 0.5, "%s: nothing in the sheet is wider than it (%d of %d)" % [d, int(sh.box.get_combined_minimum_size().x), int(sh._scroll.size.x)])
		await ShotHelper.snap(tree, "home_sheet_%s" % d)
		sh._scroll.scroll_vertical = 99999
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "home_sheet_%s_end" % d)
		var key = _with_meta(sh, "disc_log")
		if key.size() == 1:
			ShotHelper.press(key[0])
			await ShotHelper.wait(tree, 0.5)
			check(App.tab == "log" and str(App.log_discipline) == d and _disc_sheets().is_empty(), "%s: \"Log one\" closes the sheet and opens the %s log form" % [d, d])
	App.open_log(null)
	App.go("home")
	await ShotHelper.frames(tree, 4)


## The sections of the Hero tab, in the order they are on screen.
func _sections(main: Node) -> void:
	var screen = null
	for n in ShotHelper.walk(main):
		if n is HomeScreen:
			screen = n
			break
	check(screen != null, "the Hero tab is open")
	if screen == null:
		return
	var order = []
	var nodes = {}
	for n in ShotHelper.walk(screen):
		if n.has_meta("section"):
			order.append(str(n.get_meta("section")))
			nodes[str(n.get_meta("section"))] = n
	print("sections: ", order)
	var want = ["today", "ahead", "todo", "reading", "missions", "adventure", "week", "goals", "recent"]
	var last = -1
	var in_order = true
	for id in want:
		var at = order.find(id)
		if at < 0:
			continue
		if at < last:
			in_order = false
		last = at
	check(in_order, "the sections come in order: today, coming up, to do, reading, missions, adventure, your week, almost there, recent")
	check(order.size() > 0 and order[0] == "today", "Today is the first section")
	for id in ["today", "todo", "reading", "missions", "adventure", "week"]:
		check(order.has(id), "the %s section is there" % id)
	check(screen.get_theme_constant("separation") == HomeScreen.SECTION_GAP, "sections are %d apart" % HomeScreen.SECTION_GAP)
	var perfect = App.quests().daily.filter(func(m): return bool(m.get("perfect", false)))
	if nodes.has("missions") and not perfect.is_empty():
		check(ShotHelper.find_text(nodes.missions, str(perfect[0].title)) == null, "MISSIONS does not list the perfect day (it is the Today card's chest)")
	check(ShotHelper.find_text(main, "Feeling") == null, "the Feeling question is gone")
	# ADVENTURE: the weekly bounty; the campaign boss above it only while the
	# campaign is on the screens (Campaign.ON_SCREEN, off since 2026-11-25).
	if nodes.has("adventure"):
		var adv = nodes.adventure
		var views = ShotHelper.walk(adv).filter(func(n): return n is BossView)
		var boss_row = ShotHelper.find_text(adv, "CAMPAIGN BOSS") != null
		check(boss_row == Campaign.ON_SCREEN, "the Adventure section %s the campaign boss" % ("shows" if Campaign.ON_SCREEN else "does not show"))
		check(views.filter(func(v): return str(v._boss_id).begins_with("wk_")).size() == 1 and views.size() == (2 if Campaign.ON_SCREEN else 1), "it shows this week's bounty monster (%d monsters drawn)" % views.size())
		if not Campaign.ON_SCREEN:
			var words = ShotHelper.all_text(screen)
			var named = Campaign.bosses().filter(func(b): return words.contains(str(b.name))).map(func(b): return str(b.name))
			check(named.is_empty() and not words.to_lower().contains("boss"), "no word of the Hero tab names a campaign boss %s" % str(named))
			var goal_keys = App.next_goals(3).map(func(g): return str(g.key))
			check(goal_keys.filter(func(k): return Campaign.is_goal_key(k)).is_empty(), "Almost there has no campaign goal (%s)" % ", ".join(PackedStringArray(goal_keys)))
