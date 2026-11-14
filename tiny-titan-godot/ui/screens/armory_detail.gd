class_name ArmoryDetail
extends RefCounted
## The Armory's detail sheets: one item, one companion.


static func open_item(it: Dictionary) -> void:
	var state = App.state
	var owned = state.items.get(it.id)
	var loadout = App.loadout()
	var sheet = Kit.sheet(it.name if owned != null else "Locked item")
	var row = Kit.hbox(16)

	var preview_loadout = loadout.duplicate()
	if owned != null:
		preview_loadout[it.slot] = it.id
	var hero = HeroView.new()
	hero.setup(state, App.profile(), preview_loadout, null, false)
	hero.custom_minimum_size = Vector2(110, 138)
	hero.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if owned == null:
		hero.modulate = Color(0.55, 0.55, 0.6, 1.0)
	row.add_child(hero)

	var info = Kit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tags = Kit.flow(6)
	tags.add_child(Kit.rarity_badge(it.rarity))
	var where = TT.SLOT_NAMES[it.slot]
	if it.get("discipline") != null:
		where += " · " + str(TT.DISCIPLINE_META[it.discipline].name)
	tags.add_child(Kit.muted(where, 12))
	info.add_child(tags)
	info.add_child(Kit.para(it.name if owned != null else "Locked item", 20, null, true))
	var desc = ""
	if owned != null:
		desc = it.get("flavor", "")
	elif it.unlock.kind == "drop":
		desc = "%s. Drops after sessions; loot luck helps." % Items.unlock_hint(it)
	else:
		desc = "Unlock: %s" % Items.unlock_hint(it)
	info.add_child(Kit.muted_para(Icons.strip_emoji(desc), 14))
	if owned == null:
		var prog = Items.unlock_progress(it, state)
		if prog != null:
			info.add_child(Parts.progress_line(prog, Pal.rarity(it.rarity)))
	for line in Items.perk_summary(it.get("perk")):
		info.add_child(Kit.para(line, 14, Pal.GOOD, true))
	if owned != null:
		var how = str(owned.get("how", ""))
		var at = str(owned.get("at", ""))
		if how == "start":
			info.add_child(Kit.muted("Starter gear", 11))
		elif at != "":
			info.add_child(Kit.muted(("Found " if how == "drop" else "Earned ") + Dates.format_date(at, {"month": "short", "day": "numeric", "year": "numeric"}), 11))
	row.add_child(info)
	sheet.box.add_child(row)

	if owned != null:
		var wearing = loadout.get(it.slot) == it.id
		var b = Kit.button("Unequip" if wearing else "Equip", "secondary" if wearing else "primary", ArmoryDetail._toggle_item.bind(it, sheet), "lg")
		sheet.box.add_child(Kit.expand(b))
	sheet.open()


static func _toggle_item(it: Dictionary, sheet: Sheet) -> void:
	# Only owned items can be worn.
	if not App.state.items.has(it.id):
		return
	var already = App.loadout().get(it.slot) == it.id
	App.equip(it.slot, null if already else it.id)
	Sfx.tap()
	App.toast(("Unequipped %s" if already else "Equipped %s") % it.name, "good", "chest")
	if is_instance_valid(sheet):
		sheet.close()


static func open_pet(p: Dictionary) -> void:
	var state = App.state
	var owned = state.pets.has(p.id)
	var sheet = Kit.sheet("%s the %s" % [p.name, p.species] if owned else "Unknown companion")
	var row = Kit.hbox(16)
	var pv = PetView.new()
	pv.setup(p.id, 96.0, owned)
	pv.set_locked(not owned)
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pv)

	var info = Kit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Kit.rarity_badge(p.rarity))
	info.add_child(Kit.para("%s the %s" % [p.name, p.species] if owned else "Unknown companion", 20, null, true))
	info.add_child(Kit.muted_para(Icons.strip_emoji(p.flavor if owned else "Unlock: %s" % p.hint), 14))
	if not owned and p.has("progress"):
		info.add_child(Parts.progress_line(p.progress.call(state), Pal.rarity(p.rarity)))
	for line in Items.perk_summary(p.get("perk")):
		info.add_child(Kit.para(line, 14, Pal.GOOD, true))
	row.add_child(info)
	sheet.box.add_child(row)

	if owned:
		var active = App.active_pet() == p.id
		var b = Kit.button("Send home" if active else "Follow me", "secondary" if active else "primary", ArmoryDetail._toggle_pet.bind(p, sheet), "lg")
		sheet.box.add_child(Kit.expand(b))
	sheet.open()


static func _toggle_pet(p: Dictionary, sheet: Sheet) -> void:
	# Only owned pets can follow the hero.
	if not App.state.pets.has(p.id):
		return
	var already = App.active_pet() == p.id
	App.set_active_pet(null if already else p.id)
	Sfx.tap()
	App.toast(("%s stays home" if already else "%s is now following you") % p.name, "good", "paw")
	if is_instance_valid(sheet):
		sheet.close()
