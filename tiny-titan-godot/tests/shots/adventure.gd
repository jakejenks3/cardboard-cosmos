extends RefCounted
## Adventure tab walkthrough: campaign (scrolled, a boss sheet), quests (+ claim),
## trophies (+ filters, a trophy sheet), and the campaign once in the Ember theme.
## Run with new / week / year; shots are prefixed with the data size.


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()


func _first_card_with_tooltip(root: Node, tip: String):
	for n in ShotHelper.walk(root):
		if n is Card and n.tooltip_text.begins_with(tip):
			return n
	return null


func run(main: Node, tree: SceneTree) -> void:
	var n = App.sessions().size()
	var tag = "new" if n == 0 else ("week" if n < 20 else "year")

	App.go("adventure", "campaign")
	await ShotHelper.wait(tree, 0.7)
	await ShotHelper.snap(tree, "adv_%s_campaign_1" % tag)
	for y in [800, 1700, 2600]:
		ShotHelper.scroll_main(main, y)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "adv_%s_campaign_%d" % [tag, y])

	# Tap the current boss's portrait tile: its sheet opens.
	var cur = Campaign.boss_at(int(App.state.campaign.index))
	var tile = _first_card_with_tooltip(main, cur.name)
	if tile != null and not Campaign.is_echo(int(App.state.campaign.index)):
		ShotHelper.reveal(tile)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, tile)
		await ShotHelper.wait(tree, 0.4)
		var sheet_open = false
		for c in Kit.overlay_root.get_children():
			if c is Sheet:
				sheet_open = true
		print("CHECK boss sheet: open=%s" % sheet_open)
		await ShotHelper.snap(tree, "adv_%s_boss_sheet" % tag)
		_close_sheets()
		await ShotHelper.wait(tree, 0.3)

	App.set_adventure_tab("quests")
	await ShotHelper.wait(tree, 0.7)
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
	await ShotHelper.wait(tree, 0.7)
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
	# Tap a trophy tile: its sheet opens.
	var tt = ShotHelper.find_text(main, "Iron Curious")
	while tt != null and not (tt is Card):
		tt = tt.get_parent()
	if tt != null:
		ShotHelper.reveal(tt)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, tt)
		await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, "adv_%s_trophy_sheet" % tag)
		_close_sheets()
		await ShotHelper.wait(tree, 0.3)
	ShotHelper.press(ShotHelper.find_button(main, "Adventure"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "adv_%s_trophies_campaign_group" % tag)

	# The campaign in another theme: nothing may stay blue.
	App.update_settings({"theme": "ember"})
	await ShotHelper.frames(tree, 4)
	App.go("adventure", "campaign")
	await ShotHelper.wait(tree, 0.7)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "adv_%s_campaign_ember" % tag)
	App.set_adventure_tab("trophies")
	await ShotHelper.wait(tree, 0.7)
	await ShotHelper.snap(tree, "adv_%s_trophies_ember" % tag)
	App.update_settings({"theme": "arcade"})
	await ShotHelper.frames(tree, 4)
