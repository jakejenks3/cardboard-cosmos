extends RefCounted
## Walkthrough: the Hero tab (and onboarding when started with the "fresh" data).
## Since 2026-11-24 it also checks the page's sections (Kit.section, meta
## "section"): their order, the gap between them, and that nothing in MISSIONS
## repeats a Today done box.

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
	print("level ", App.state.levels.hero.level, " sessions ", App.sessions().size(), " boss ", Campaign.boss_at(App.state.campaign.index).name)
	print("home checks failed: ", fails)


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
