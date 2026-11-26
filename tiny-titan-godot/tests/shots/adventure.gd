extends RefCounted
## Adventure tab walkthrough: the first page, quests (+ claim), trophies
## (+ filters, a trophy sheet), and the first page once in the Ember theme.
## Run with new / week / year; shots are prefixed with the data size.
##
## The first page is the weekly bounty while the campaign is off the screens
## (Campaign.ON_SCREEN false, since 2026-11-25): its sub-tab says "Bounty", it
## shows the big bounty card, the record and the past weeks, no boss, and a tap
## on the card opens the bounty's sheet. With ON_SCREEN true it is the campaign
## again (scrolled, a boss sheet), as before.

var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheet_open() -> bool:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			return true
	return false


## The first page while the campaign is off the screens: the bounty.
func _bounty_page(main: Node, tree: SceneTree, tag: String) -> void:
	await ShotHelper.snap(tree, "adv_%s_bounty_1" % tag)
	var keys = ShotHelper.walk(main).filter(func(n): return n is Button).map(func(n): return str(n.text))
	check(keys.has("Bounty") and not keys.has("Campaign"), "the first page is called Bounty, not Campaign")
	var w = Bounty.of(App.state)
	var mon = Bounty.monster(w.current.monster)
	var name_label = null
	for n in ShotHelper.walk(main):
		if n is Label and n.text == str(mon.name):
			name_label = n
	check(name_label != null, "this week's bounty is on it (%s)" % mon.name)
	check(ShotHelper.find_text(main, "IN A ROW") != null and ShotHelper.find_text(main, "WINS") != null, "with the record: wins, in a row, coins")
	var words = ShotHelper.all_text(main)
	var named = Campaign.bosses().filter(func(b): return words.contains(str(b.name))).map(func(b): return str(b.name))
	var captions = ShotHelper.walk(main).filter(func(n): return n is Label and ["BOSSES", "DAMAGE", "ZONE", "ECHOES"].has(str(n.text))).map(func(n): return str(n.text))
	check(named.is_empty() and not words.to_lower().contains("boss") and captions.is_empty(), "and no campaign boss, and none of the campaign's counts %s %s" % [str(named), str(captions)])
	var views = ShotHelper.walk(main).filter(func(n): return n is BossView)
	check(not views.is_empty() and views.all(func(v): return str(v._boss_id).begins_with("wk_")), "every monster drawn is a bounty's (%d)" % views.size())
	var past = ShotHelper.walk(main).filter(func(n): return n.has_meta("bounty_past"))
	check(past.size() == (1 if w.history.size() > 1 else 0), "the past weeks are listed when there are any (%d weeks so far)" % w.history.size())
	ShotHelper.scroll_main(main, 500)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "adv_%s_bounty_2" % tag)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 3)
	# Tap the big card: the bounty's sheet opens.
	var card = name_label
	while card != null and not (card is Card):
		card = card.get_parent()
	if card != null:
		# (Its own tap, as the bounty walkthrough does: a click in the middle of the
		# card could land on a pill that has a tooltip.)
		card._tap.call()
		await ShotHelper.wait(tree, 0.5)
		check(_sheet_open(), "a tap on the bounty card opens its sheet")
		await ShotHelper.snap(tree, "adv_%s_bounty_sheet" % tag)
		_close_sheets()
		await ShotHelper.wait(tree, 0.3)


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
	if not Campaign.ON_SCREEN:
		await _bounty_page(main, tree, tag)
	else:
		await ShotHelper.snap(tree, "adv_%s_campaign_1" % tag)
		for y in [800, 1700, 2600]:
			ShotHelper.scroll_main(main, y)
			await ShotHelper.frames(tree, 3)
			await ShotHelper.snap(tree, "adv_%s_campaign_%d" % [tag, y])

	# Tap the current boss's portrait tile: its sheet opens (only while the campaign is shown).
	var cur = Campaign.boss_at(int(App.state.campaign.index))
	var tile = _first_card_with_tooltip(main, cur.name) if Campaign.ON_SCREEN else null
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
	if not Campaign.ON_SCREEN:
		# The campaign's own trophies stay in the cabinet (they still unlock from
		# training); one not earned yet says it is a campaign reward, not "Defeat ...".
		var open_ids = Campaign.GOAL_TROPHIES.filter(func(id): return not App.state.achievements.has(id))
		var tips = ShotHelper.walk(main).filter(func(n): return n is Card).map(func(n): return str(n.tooltip_text))
		var resting = tips.filter(func(t): return t.begins_with(Campaign.RESTING)).size()
		var told = open_ids.filter(func(id): return tips.any(func(t): return t.begins_with(Icons.strip_emoji(str(Achievements.by_id(id).desc)))))
		check(resting == open_ids.size() and told.is_empty(), "the %d campaign trophies not earned yet say \"%s\"" % [open_ids.size(), Campaign.RESTING])
		check(ShotHelper.find_text(main, "Bounty Hunter") != null, "the bounty trophies are in the same group")

	# The first page in another theme: nothing may stay blue.
	App.update_settings({"theme": "ember"})
	await ShotHelper.frames(tree, 4)
	App.go("adventure", "campaign")
	await ShotHelper.wait(tree, 0.7)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "adv_%s_%s_ember" % [tag, "campaign" if Campaign.ON_SCREEN else "bounty"])
	App.set_adventure_tab("trophies")
	await ShotHelper.wait(tree, 0.7)
	await ShotHelper.snap(tree, "adv_%s_trophies_ember" % tag)
	App.update_settings({"theme": "arcade"})
	await ShotHelper.frames(tree, 4)
	print("ADVENTURE DONE, failures: %d" % fails)
