extends RefCounted
## The shop (Armory -> Shop): the purse, the deal of the week, try-on tiles,
## the buy sheet, buying, and what is saved. Run with "year" data (plenty of
## coins) and with "week" data (few coins, low level: the locked buttons).

var main: Node
var tree: SceneTree
var fails = 0
var pre = ""


func check(cond: bool, what: String) -> void:
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func screen():
	for n in ShotHelper.walk(main):
		if n is ArmoryScreen:
			return n
	return null


func sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func card_of(root: Node, text: String):
	for n in ShotHelper.walk(root):
		if n is Label and n.text == text:
			var p = n
			while p != null and not (p is Card):
				p = p.get_parent()
			if p != null:
				return p
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	pre = "week_" if App.sessions().size() < 10 else ""
	var rich = pre == ""
	App.go("armory")
	await ShotHelper.wait(tree, 0.7)
	var scr = screen()
	check(ShotHelper.find_button(scr, "Shop") != null, "the Armory has a Shop chip")
	ShotHelper.press(ShotHelper.find_button(scr, "Shop"))
	await ShotHelper.wait(tree, 0.6)
	var start = App.coins()
	check(scr.tab == "shop" and start > 0, "the shop opens and there are coins to spend (%d)" % start)
	check(ShotHelper.find_text(scr, "DEAL OF THE WEEK") != null, "the deal of the week is shown")
	check(ShotHelper.find_button(scr, "For sale") != null and card_of(scr, "Party Hat") != null, "items for sale are listed, cheapest first")
	await ShotHelper.snap(tree, pre + "shop_01")
	ShotHelper.scroll_main(main, 560)
	await ShotHelper.snap(tree, pre + "shop_02")
	ShotHelper.scroll_main(main, 1300)
	await ShotHelper.snap(tree, pre + "shop_03")
	ShotHelper.scroll_main(main, 0)

	if not rich:
		# Few coins and a low level: the sheet says what is missing.
		var halo = Items.by_id("shop_halo")
		ArmoryDetail.open_item(halo)
		await ShotHelper.wait(tree, 0.7)
		var b = ShotHelper.find_button(sheet(), "Reach hero level 20")
		check(b != null and b.disabled, "a level-locked item says which level it needs")
		await ShotHelper.snap(tree, pre + "shop_04_level_lock")
		sheet().close()
		await ShotHelper.wait(tree, 0.4)
		var dear = null
		for it in Wallet.shop_items():
			if Wallet.can_buy(App.state, it, Dates.week_key(App.today)).why == "coins" and dear == null:
				dear = it
		check(dear != null, "something costs more than the purse holds")
		if dear != null:
			ArmoryDetail.open_item(dear)
			await ShotHelper.wait(tree, 0.7)
			var nb = ShotHelper.find_button(sheet(), "more coins to go")
			check(nb != null and nb.disabled, "an item you cannot afford says how many coins are missing")
			await ShotHelper.snap(tree, pre + "shop_05_need_coins")
			sheet().close()
			await ShotHelper.wait(tree, 0.4)
		check(App.buy_item("shop_halo") == "level" and App.purchases().is_empty(), "buying under the level is refused and nothing is saved")

	# --- buy something affordable ---------------------------------------------------
	var wk = Dates.week_key(App.today)
	var pick = null
	for id in ["shop_wizard_hat", "shop_headphones", "shop_party_hat"]:
		var it = Items.by_id(id)
		if pick == null and Wallet.can_buy(App.state, it, wk).ok:
			pick = it
	check(pick != null, "something is affordable")
	if pick == null:
		print("SHOP DONE, failures: %d" % fails)
		return
	var price = Wallet.price(pick, wk)
	var tile = card_of(scr, pick.name)
	check(tile != null, "%s has a tile" % pick.name)
	tile._tap.call()
	await ShotHelper.wait(tree, 0.8)
	check(sheet() != null and ShotHelper.find_button(sheet(), "Buy and wear") != null and ShotHelper.find_text(sheet(), "You have") != null, "its sheet shows the price and a buy button")
	await ShotHelper.snap(tree, pre + "shop_06_sheet")
	ShotHelper.press(ShotHelper.find_button(sheet(), "Buy and wear"))
	await ShotHelper.wait(tree, 1.0)
	check(App.state.items.has(pick.id) and App.state.items[pick.id].how == "shop", "it is in the collection")
	check(App.loadout().get(pick.slot) == pick.id, "and the hero is wearing it")
	check(App.coins() == start - price + (Wallet.earned(App.state) - (start + int(App.state.coins.spent) - price)) and App.purchases().size() == 1 and int(App.purchases()[0].cost) == price, "the price left the purse once (%d -> %d)" % [start, App.coins()])
	check(App.state.achievements.has("shop_1"), "the first purchase earns Retail Therapy")
	await ShotHelper.snap(tree, pre + "shop_07_bought")
	check(App.buy_item(pick.id) == "owned" and App.purchases().size() == 1, "it cannot be bought twice")

	# --- it is in the save file and survives a reload -------------------------------------
	var parsed = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
	check(parsed != null and parsed.purchases.size() == 1 and parsed.purchases[0].itemId == pick.id, "the purchase is written to the save file")
	var again = Derive.derive({"sessions": parsed.sessions, "claims": parsed.claims, "body": parsed.body, "purchases": parsed.purchases, "weeklyGoal": 3, "today": App.today})
	check(again.items.has(pick.id) and Wallet.balance(again) == App.coins(), "and replaying the save gives the same purse")

	# --- the lists ---------------------------------------------------------------------
	ShotHelper.press(ShotHelper.find_button(scr, "Bought"))
	await ShotHelper.wait(tree, 0.5)
	check(card_of(scr, pick.name) != null and card_of(scr, "Bow Tie") == null, "Bought lists what you own")
	await ShotHelper.snap(tree, pre + "shop_08_bought_list")
	ShotHelper.press(ShotHelper.find_button(scr, "Head "))
	await ShotHelper.wait(tree, 0.5)
	check(scr.tab == "head" and card_of(scr, "Viking Helm") != null, "the Head tab shows shop hats with their price")
	await ShotHelper.snap(tree, pre + "shop_09_head_tab")
	ShotHelper.scroll_main(main, 700)
	await ShotHelper.snap(tree, pre + "shop_10_head_tab_b")
	print("SHOP DONE, failures: %d" % fails)
