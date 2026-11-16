class_name ArmoryDetail
extends RefCounted
## The Armory's detail sheets: one item, one companion. The picture is the
## biggest thing; rarity, slot and perks are chips; one line of flavour.
## A shop item that is not bought yet shows the hero trying it on, its price
## and a button to buy it.


## Rarity, where it goes and its perks as a row of chips.
static func _chips(rarity: String, extra: Array, perk) -> Control:
	var f = Kit.flow(6)
	f.add_child(Kit.pill("", str(rarity).to_upper(), Pal.rarity(rarity), "", null, 11))
	for e in extra:
		f.add_child(Kit.pill(e[0], e[1], Pal.PANEL2, "", Pal.TEXT, 11))
	for line in Items.perk_summary(perk):
		f.add_child(Kit.pill("bolt", line, Pal.GOOD, "", null, 11))
	return f


static func open_item(it: Dictionary) -> void:
	var state = App.state
	var owned = state.items.get(it.id)
	# Something in the shop that is not bought yet: shown on the hero, with a price.
	var for_sale = owned == null and Wallet.is_shop(it)
	var loadout = App.loadout()
	var rc = Pal.rarity(it.rarity)
	var sheet = Kit.sheet(it.name if (owned != null or for_sale) else "Locked item")
	var row = Kit.hbox(14)

	var preview_loadout = loadout.duplicate()
	if owned != null or for_sale:
		preview_loadout[it.slot] = it.id
	var hero = HeroView.new()
	hero.setup(Art.tryon_state(state, it.id) if for_sale else state, App.profile(), preview_loadout, null, false)
	hero.custom_minimum_size = Vector2(120, 150)
	if owned == null and not for_sale:
		hero.modulate = Color(0.55, 0.55, 0.6, 1.0)
	var stage = PanelContainer.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": rc, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stage.add_child(hero)
	row.add_child(stage)

	var info = Kit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var extra = [["armory", TT.SLOT_NAMES[it.slot]]]
	if it.get("discipline") != null:
		extra.append([it.discipline, TT.DISCIPLINE_META[it.discipline].name])
	info.add_child(_chips(it.rarity, extra, it.get("perk")))
	var desc = ""
	if owned != null or for_sale:
		desc = it.get("flavor", "")
	elif it.unlock.kind == "drop":
		desc = "%s. Drops after sessions; loot luck helps." % Items.unlock_hint(it)
	else:
		desc = "Unlock: %s" % Items.unlock_hint(it)
	info.add_child(Kit.muted_para(Icons.strip_emoji(desc), 14))
	if for_sale:
		info.add_child(Kit.muted("Tap the hero to see it flex", 11))
	elif owned == null:
		var prog = Items.unlock_progress(it, state)
		if prog != null:
			info.add_child(Parts.progress_line(prog, rc))
	else:
		var how = str(owned.get("how", ""))
		var at = str(owned.get("at", ""))
		if how == "start":
			info.add_child(Kit.muted("Starter gear", 11))
		elif at != "":
			var verb = "Found " if how == "drop" else ("Bought " if how == "shop" else "Earned ")
			info.add_child(Kit.muted(verb + Dates.format_date(at, {"month": "short", "day": "numeric", "year": "numeric"}), 11))
	row.add_child(info)
	sheet.box.add_child(row)

	if for_sale:
		sheet.box.add_child(_buy_box(it, sheet))
	elif owned != null:
		var wearing = loadout.get(it.slot) == it.id
		var b = Kit.button("Unequip" if wearing else "Equip", "ghost" if wearing else "primary", Callable(), "lg")
		b.pressed.connect(ArmoryDetail._toggle_item.bind(it, sheet, b))
		sheet.box.add_child(Kit.expand(b))
	sheet.open()


## The price of a shop item, what the player has, and the button that buys it
## (or says what is missing).
static func _buy_box(it: Dictionary, sheet) -> Control:
	var wk = Dates.week_key(App.today)
	var check = Wallet.can_buy(App.state, it, wk)
	var have = App.coins()
	var box = Kit.vbox(8)
	var line = Kit.hbox(8)
	line.add_child(Kit.coin_pill(check.price, "", 15))
	if int(check.price) < Wallet.base_price(it):
		line.add_child(Kit.tag("DEAL -%d%%" % TTUtil.jsround(Wallet.DEAL_OFF * 100.0), Pal.GOOD, true, 10))
		line.add_child(Kit.vcenter(Kit.muted("was %s" % Xp.fmt_int(Wallet.base_price(it)), 12)))
	line.add_child(Kit.spacer())
	line.add_child(Kit.vcenter(Kit.muted("You have %s" % Xp.fmt_int(have), 12)))
	box.add_child(line)
	if check.ok:
		var b = Kit.button("Buy and wear", "primary", Callable(), "lg", "coin")
		b.pressed.connect(ArmoryDetail._buy.bind(it, sheet, b))
		box.add_child(Kit.expand(b))
	else:
		var why = "%s more coins to go" % Xp.fmt_int(int(check.price) - have)
		if check.why == "level":
			why = "Reach hero level %d to buy this" % Wallet.min_level(it)
		var b = Kit.button(why, "ghost", Callable(), "lg", "lock")
		b.disabled = true
		box.add_child(Kit.expand(b))
		if check.why == "coins":
			box.add_child(Kit.bar(float(have) / maxf(1.0, float(check.price)), Pal.ACCENT, 8))
	return box


static func _buy(it: Dictionary, sheet, from = null) -> void:
	var why = App.buy_item(it.id)
	if why != "":
		Sfx.error()
		App.toast("Could not buy %s" % it.name, "bad", "warning")
		return
	App.equip(it.slot, it.id)
	Sfx.drop(it.rarity)
	if from is Control and is_instance_valid(from):
		Kit.burst(from, Pal.rarity(it.rarity), 30)
	App.toast("Bought %s. It suits you." % it.name, "good", "bag")
	if sheet != null and is_instance_valid(sheet):
		sheet.close()


static func _toggle_item(it: Dictionary, sheet, from = null) -> void:
	# Only owned items can be worn.
	if not App.state.items.has(it.id):
		return
	var already = App.loadout().get(it.slot) == it.id
	if not already and from is Control:
		Kit.burst(from, Pal.rarity(it.rarity), 22)
	App.equip(it.slot, null if already else it.id)
	Sfx.tap()
	App.toast(("Unequipped %s" if already else "Equipped %s") % it.name, "good", "chest")
	if sheet != null and is_instance_valid(sheet):
		sheet.close()


static func open_pet(p: Dictionary) -> void:
	var state = App.state
	var owned = state.pets.has(p.id)
	var rc = Pal.rarity(p.rarity)
	var sheet = Kit.sheet("%s the %s" % [p.name, p.species] if owned else "Unknown companion")
	var row = Kit.hbox(14)
	var pv = PetView.new()
	pv.setup(p.id, 104.0, owned)
	pv.set_locked(not owned)
	var stage = PanelContainer.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": rc, "lip": 0, "inset": true, "pad_h": 10, "pad_v": 10}))
	stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stage.add_child(pv)
	row.add_child(stage)

	var info = Kit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(_chips(p.rarity, [["paw", p.species if owned else "???"]], p.get("perk")))
	info.add_child(Kit.muted_para(Icons.strip_emoji(p.flavor if owned else "Unlock: %s" % p.hint), 14))
	if not owned and p.has("progress"):
		info.add_child(Parts.progress_line(p.progress.call(state), rc))
	row.add_child(info)
	sheet.box.add_child(row)

	if owned:
		var active = App.active_pet() == p.id
		var b = Kit.button("Send home" if active else "Follow me", "ghost" if active else "primary", Callable(), "lg")
		b.pressed.connect(ArmoryDetail._toggle_pet.bind(p, sheet, b))
		sheet.box.add_child(Kit.expand(b))
	sheet.open()


static func _toggle_pet(p: Dictionary, sheet, from = null) -> void:
	# Only owned pets can follow the hero.
	if not App.state.pets.has(p.id):
		return
	var already = App.active_pet() == p.id
	if not already and from is Control:
		Kit.burst(from, Pal.rarity(p.rarity), 22)
	App.set_active_pet(null if already else p.id)
	if already:
		Sfx.tap()
	else:
		Sfx.pet()
	App.toast(("%s stays home" if already else "%s is now following you") % p.name, "good", "paw")
	if sheet != null and is_instance_valid(sheet):
		sheet.close()
