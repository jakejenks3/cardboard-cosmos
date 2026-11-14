extends RefCounted
## Walkthrough: the Hero tab (and onboarding when started with the "fresh" data).

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
	ShotHelper.scroll_main(main, 560)
	await ShotHelper.snap(tree, "home_2")
	ShotHelper.scroll_main(main, 1200)
	await ShotHelper.snap(tree, "home_3")
	ShotHelper.scroll_main(main, 99999)
	await ShotHelper.snap(tree, "home_4")
	print("level ", App.state.levels.hero.level, " sessions ", App.sessions().size(), " boss ", Campaign.boss_at(App.state.campaign.index).name)
