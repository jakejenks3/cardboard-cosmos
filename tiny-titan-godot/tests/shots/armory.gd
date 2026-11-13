extends RefCounted
## Armory walkthrough: slots, tiles, item / pet sheets, equip, companions.
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


func run(main: Node, tree: SceneTree) -> void:
	pre = "new_" if App.sessions().is_empty() else "year_"
	App.go("armory")
	await ShotHelper.frames(tree, 6)
	var scr = _screen(main)
	await ShotHelper.snap(tree, pre + "armory_head")
	ShotHelper.scroll_main(main, 500)
	await ShotHelper.snap(tree, pre + "armory_head_2")
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
		var lt = _tile_of(scr, Items.unlock_hint(locked))
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
