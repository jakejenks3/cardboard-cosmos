extends RefCounted
## Adventure tab walkthrough: campaign (scrolled), quests (+ claim), trophies (+ filters).
## Run with new / week / year; shots are prefixed with the data size.


func run(main: Node, tree: SceneTree) -> void:
	var n = App.sessions().size()
	var tag = "new" if n == 0 else ("week" if n < 20 else "year")

	App.go("adventure", "campaign")
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "adv_%s_campaign_1" % tag)
	for y in [800, 1700, 2600]:
		ShotHelper.scroll_main(main, y)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "adv_%s_campaign_%d" % [tag, y])

	App.set_adventure_tab("quests")
	await ShotHelper.frames(tree, 4)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "adv_%s_quests" % tag)
	var claim = ShotHelper.find_button(main, "Claim")
	if claim != null:
		var claims_before = App.claims().size()
		var xp_before = int(App.state.levels.hero.total)
		ShotHelper.press(claim)
		await ShotHelper.frames(tree, 6)
		print("CHECK claim: claims %d -> %d, hero xp %d -> %d" % [claims_before, App.claims().size(), xp_before, int(App.state.levels.hero.total)])
		await ShotHelper.snap(tree, "adv_%s_quests_claimed" % tag)
	else:
		print("no claimable quest with this data")
	ShotHelper.scroll_main(main, 600)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "adv_%s_quests_2" % tag)

	App.set_adventure_tab("trophies")
	await ShotHelper.frames(tree, 4)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "adv_%s_trophies" % tag)
	ShotHelper.scroll_main(main, 1500)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "adv_%s_trophies_scrolled" % tag)
	ShotHelper.scroll_main(main, 0)
	ShotHelper.press(ShotHelper.find_button(main, "Lifting"))
	await ShotHelper.frames(tree, 4)
	var txt = ShotHelper.all_text(main)
	print("CHECK filter lift: has 'Iron Curious'=%s has 'First Step'=%s" % [txt.contains("Iron Curious"), txt.contains("First Step")])
	await ShotHelper.snap(tree, "adv_%s_trophies_lift" % tag)
	ShotHelper.press(ShotHelper.find_button(main, "Adventure"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "adv_%s_trophies_campaign_group" % tag)
