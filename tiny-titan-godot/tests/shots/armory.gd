extends RefCounted
## Armory walkthrough: the paper doll and its hover cards, the Equipped list,
## slots, tiles, item / pet sheets, equip, companions.
## Run with `year` and with `new` data (shot names are prefixed with the kind).

var pre = ""


func _screen(main: Node):
	for n in ShotHelper.walk(main):
		if n is ArmoryScreen:
			return n
	return null


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()


func _tile_of(scr: Node, text: String):
	var l = ShotHelper.find_text(scr, text)
	var p = l
	while p != null and not (p is Card):
		p = p.get_parent()
	return p


func _check(label: String, ok: bool) -> void:
	print(("CHECK OK   " if ok else "CHECK FAIL ") + label)


## Move the mouse over a control, as a person would before clicking it.
func _hover(tree: SceneTree, c: Control) -> void:
	var ev = InputEventMouseMotion.new()
	ev.position = c.get_global_rect().get_center()
	ev.global_position = ev.position
	tree.root.push_input(ev)
	await ShotHelper.wait(tree, 0.3)


func _hover_cards() -> Array:
	var out = []
	for c in Kit.overlay_root.get_children():
		if c is HoverCard:
			out.append(c)
	return out


## The slots on each side of the hero: small Cards stacked in the two columns of the doll.
func _doll_slots(scr: Node) -> Array:
	var out = []
	for n in ShotHelper.walk(scr):
		if n is Card and n.get_parent() is VBoxContainer and n.size.x > 30.0 and n.size.x < 70.0:
			out.append(n)
	return out


func run(main: Node, tree: SceneTree) -> void:
	pre = "new_" if App.sessions().is_empty() else "year_"
	App.go("armory")
	await ShotHelper.wait(tree, 0.7)
	var scr = _screen(main)

	# --- the paper doll, its hover cards and the Equipped list ---------------------
	_check("the Armory opens on Equipped", scr.tab == "equipped")
	await ShotHelper.snap(tree, pre + "armory_equipped")
	var slots = _doll_slots(scr)
	_check("ten slots round the hero (%d)" % slots.size(), slots.size() == 10)
	var worn = 0
	for s in TT.SLOTS:
		var id = App.loadout().get(s)
		if id != null and App.state.items.has(id):
			worn += 1
	var rows = 0
	for n in ShotHelper.walk(scr):
		if n is Label and (n.text.begins_with("Starter kit") or n.text.begins_with("Found as loot") or n.text.begins_with("Earned:") or n.text.begins_with("Bought in the shop")):
			rows += 1
	_check("the list says where each worn piece came from (%d of %d)" % [rows, worn], rows == worn and worn >= 3)
	if slots.size() == 10:
		# body is the third slot on the left: the starter tee, or whatever is worn there
		await _hover(tree, slots[2])
		var cards = _hover_cards()
		_check("hovering a slot shows one card", cards.size() == 1)
		if cards.size() == 1:
			var body_id = App.loadout().get("body")
			var body_item = Items.by_id(body_id) if body_id != null else null
			if body_item != null:
				_check("the card names the piece (%s)" % body_item.name, ShotHelper.find_text(cards[0], body_item.name) != null)
				var origin = ArmoryDetail.item_origin(body_item, App.state.items.get(body_item.id))
				_check("and says how it was obtained (%s)" % origin.title, ShotHelper.find_text(cards[0], str(origin.title)) != null)
				var perks = Items.perk_summary(body_item.get("perk"))
				_check("and what it does", ShotHelper.find_text(cards[0], perks[0] if not perks.is_empty() else "No bonus") != null)
			_check("the card stays inside the window", cards[0].position.x >= 0.0 and cards[0].position.x + cards[0].size.x <= Kit.overlay_root.size.x + 0.5)
		await ShotHelper.snap(tree, pre + "armory_hover_slot")
		await _hover(tree, slots[1])
		_check("moving to another slot leaves one card", _hover_cards().size() == 1)
		await ShotHelper.click(tree, slots[0])
		await ShotHelper.wait(tree, 0.3)
		scr = _screen(main)
		_check("clicking the head slot opens the head gear", scr.tab == "head")
		_check("and the card is gone", _hover_cards().is_empty())
	scr.tab = "equipped"
	scr.rebuild_now()
	ShotHelper.scroll_main(main, 430)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, pre + "armory_equipped_list")
	ShotHelper.scroll_main(main, 0)

	scr.tab = "head"
	scr.rebuild_now()
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, pre + "armory_head")
	ShotHelper.scroll_main(main, 500)
	await ShotHelper.snap(tree, pre + "armory_head_2")
	# a tile of the grid has a card too
	var tiles = []
	for n in ShotHelper.walk(scr):
		if n is Card and n.get_parent() is GridContainer:
			tiles.append(n)
	if tiles.size() > 3:
		await _hover(tree, tiles[3])
		_check("hovering a gear tile shows its card", _hover_cards().size() == 1)
		await ShotHelper.snap(tree, pre + "armory_hover_tile")
	HoverCard.dismiss()
	ShotHelper.scroll_main(main, 0)

	ShotHelper.press(ShotHelper.find_button(scr, "Body "))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, pre + "armory_body")

	# --- equip an owned, unworn item (prefer one with a perk) by clicking its tile
	var pick = null
	for it in Items.all():
		if App.state.items.has(it.id) and App.loadout().get(it.slot) != it.id:
			if pick == null or (pick.get("perk") == null and it.get("perk") != null):
				pick = it
	if pick != null:
		scr.tab = pick.slot
		scr.rebuild_now()
		await ShotHelper.frames(tree, 3)
		var perks_before = App.perks.duplicate(true)
		var tile = _tile_of(scr, pick.name)
		ShotHelper.reveal(tile)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, tile)
		await ShotHelper.frames(tree, 4)
		_check("tile click equips %s" % pick.id, App.loadout().get(pick.slot) == pick.id)
		if pick.get("perk") != null:
			_check("perks changed %s -> %s" % [perks_before, App.perks], str(perks_before) != str(App.perks))
		ShotHelper.scroll_main(main, 0)
		await ShotHelper.snap(tree, pre + "armory_equipped_" + pick.slot)
		# tapping the worn tile opens its sheet
		tile = _tile_of(scr, pick.name)
		ShotHelper.reveal(tile)
		await ShotHelper.frames(tree, 2)
		await ShotHelper.click(tree, tile)
		await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, pre + "armory_owned_sheet")
		ShotHelper.press(ShotHelper.find_button(Kit.overlay_root, "Unequip"))
		await ShotHelper.wait(tree, 0.4)
		_check("unequip via sheet", App.loadout().get(pick.slot) != pick.id)
		ArmoryDetail.open_item(pick)
		await ShotHelper.wait(tree, 0.4)
		ShotHelper.press(ShotHelper.find_button(Kit.overlay_root, "Equip"))
		await ShotHelper.wait(tree, 0.4)
		_check("equip via sheet", App.loadout().get(pick.slot) == pick.id)
	else:
		print("no owned unworn item to equip")

	# --- a locked item with a progress line
	var locked = null
	for it in Items.all():
		if not App.state.items.has(it.id) and Items.unlock_progress(it, App.state) != null:
			locked = it
			break
	if locked != null:
		scr.tab = locked.slot
		scr.rebuild_now()
		await ShotHelper.frames(tree, 3)
		var before = App.loadout().duplicate()
		scr._equip_now(locked.slot, locked.id)
		ArmoryDetail._toggle_item(locked, null)
		# (The hint as the Armory says it: boss gear reads "A campaign reward ..."
		# while the campaign is off the screens, ArmoryDetail.item_hint.)
		var lt = _tile_of(scr, ArmoryDetail.item_hint(locked))
		if lt != null:
			ShotHelper.reveal(lt)
			await ShotHelper.frames(tree, 2)
			await ShotHelper.click(tree, lt)
		else:
			ArmoryDetail.open_item(locked)
		await ShotHelper.wait(tree, 0.4)
		_check("locked item not equipped", str(before) == str(App.loadout()))
		_check("locked sheet has no Equip button", ShotHelper.find_button(Kit.overlay_root, "Equip") == null)
		ShotHelper.scroll_main(main, 0)
		await ShotHelper.snap(tree, pre + "armory_locked_sheet")
		_close_sheets()
		await ShotHelper.wait(tree, 0.3)

	# --- companions
	ShotHelper.scroll_main(main, 0)
	ShotHelper.press(ShotHelper.find_button(scr, "Pets"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, pre + "armory_pets")
	ShotHelper.scroll_main(main, 600)
	await ShotHelper.snap(tree, pre + "armory_pets_2")
	var pet = null
	var lpet = null
	for p in Pets.all():
		if App.state.pets.has(p.id) and App.active_pet() != p.id and pet == null:
			pet = p
		if not App.state.pets.has(p.id) and lpet == null:
			lpet = p
	# Tapping an owned companion's tile makes it follow at once.
	var pet2 = null
	for p in Pets.all():
		if App.state.pets.has(p.id) and App.active_pet() != p.id and p != pet:
			pet2 = p
	if pet2 != null:
		var pt = _tile_of(scr, pet2.name)
		if pt != null:
			ShotHelper.reveal(pt)
			await ShotHelper.frames(tree, 2)
			await ShotHelper.click(tree, pt)
			await ShotHelper.frames(tree, 4)
			_check("pet tile click follows %s" % pet2.id, App.active_pet() == pet2.id)
	if pet != null:
		ArmoryDetail.open_pet(pet)
		await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, pre + "armory_pet_sheet")
		ShotHelper.press(ShotHelper.find_button(Kit.overlay_root, "Follow me"))
		await ShotHelper.wait(tree, 0.4)
		_check("active pet is %s" % pet.id, App.active_pet() == pet.id)
		ShotHelper.scroll_main(main, 0)
		await ShotHelper.snap(tree, pre + "armory_pet_active")
	if lpet != null:
		var ap = App.active_pet()
		ArmoryDetail._toggle_pet(lpet, null)
		_check("locked pet cannot follow", App.active_pet() == ap)
		ArmoryDetail.open_pet(lpet)
		await ShotHelper.wait(tree, 0.4)
		await ShotHelper.snap(tree, pre + "armory_locked_pet_sheet")
		_close_sheets()
		await ShotHelper.wait(tree, 0.3)

	ShotHelper.scroll_main(main, 0)
	ShotHelper.press(ShotHelper.find_button(scr, "Look"))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, pre + "armory_look")

	# Another theme: nothing may stay blue.
	App.update_settings({"theme": "forest"})
	await ShotHelper.frames(tree, 4)
	App.go("armory")
	await ShotHelper.wait(tree, 0.7)
	scr = _screen(main)
	if scr != null:
		ShotHelper.press(ShotHelper.find_button(scr, "Head "))
		await ShotHelper.wait(tree, 0.3)
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, pre + "armory_forest")
	App.update_settings({"theme": "arcade"})
	await ShotHelper.frames(tree, 4)
