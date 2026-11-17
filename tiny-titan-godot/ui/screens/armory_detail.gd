class_name ArmoryDetail
extends RefCounted
## The Armory's detail sheets: one item, one companion. The picture is the
## biggest thing; rarity, slot and perks are chips; one line of flavour.
## A shop item that is not bought yet shows the hero trying it on, its price
## and a button to buy it.


const DATE_FMT = {"month": "short", "day": "numeric", "year": "numeric"}


# ---------------------------------------------------------------------------
# How and when something was obtained
# ---------------------------------------------------------------------------

## Where an owned item came from: {"icon", "title", "sub"}.
## `owned` is its record in state.items ({at, how, sessionId?}).
static func item_origin(it: Dictionary, owned) -> Dictionary:
	var how = str(owned.get("how", "")) if owned is Dictionary else ""
	var at = str(owned.get("at", "")) if owned is Dictionary else ""
	var day = Dates.format_date(at, DATE_FMT) if at != "" else ""
	match how:
		"start":
			return {"icon": "home", "title": "Starter kit", "sub": "Yours from day one"}
		"drop":
			var sub = day
			var sess = App.session_by_id(owned.get("sessionId"))
			if sess != null:
				var what = Misc.title(sess).to_lower() if Misc.is_misc(sess) else "%s session" % str(TT.DISCIPLINE_META.get(str(sess.discipline), {"name": "training"}).name).to_lower()
				sub = "%s, after a %s" % [day, what]
			return {"icon": "gift", "title": "Found as loot", "sub": sub}
		"shop":
			var cost = 0
			for b in App.purchases():
				if str(b.get("itemId", "")) == str(it.id):
					cost = int(b.get("cost", 0))
			var sub = day
			if cost > 0:
				sub = "%s, for %s coins" % [day, Xp.fmt_int(cost)]
			return {"icon": "coin", "title": "Bought in the shop", "sub": sub}
		"unlock":
			return {"icon": "trophy", "title": "Earned: %s" % Icons.strip_emoji(str(it.unlock.get("hint", "a goal"))), "sub": day}
	return {"icon": "chest", "title": "In your collection", "sub": day}


## Where an owned companion came from: {"icon", "title", "sub"}.
static func pet_origin(p: Dictionary, owned) -> Dictionary:
	var at = str(owned.get("at", "")) if owned is Dictionary else ""
	return {"icon": "paw", "title": "Joined you: %s" % Icons.strip_emoji(str(p.hint)), "sub": Dates.format_date(at, DATE_FMT) if at != "" else ""}


## "[icon] Found as loot / Nov 14, 2026, after a climbing session".
static func origin_row(o: Dictionary) -> Control:
	var row = Kit.hbox(8)
	var ic = Icons.rect(str(o.icon), 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.para(str(o.title), 12, null, true))
	if str(o.sub) != "":
		v.add_child(Kit.muted_para(str(o.sub), 11))
	row.add_child(v)
	return row


## What a perk does as chips, or one quiet line when it does nothing.
static func effect_block(perk, none_text: String = "No bonus: worn for the look") -> Control:
	var lines = Items.perk_summary(perk)
	if lines.is_empty():
		return Kit.muted(none_text, 11)
	var f = Kit.flow(4)
	for line in lines:
		f.add_child(Kit.pill("bolt", line, Pal.GOOD, "", null, 11))
	return f


# ---------------------------------------------------------------------------
# Hover cards (HoverCard.attach(control, ArmoryDetail.hover_item.bind(it)))
# ---------------------------------------------------------------------------

static func _hover_head(pic: Control, title: String, rc: Color, sub: String) -> Control:
	var head = Kit.hbox(10)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": rc, "lip": 0, "inset": true, "pad_h": 3, "pad_v": 3}))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(pic)
	head.add_child(plate)
	var names = Kit.vbox(1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_child(Kit.para(title, 14, rc.lightened(0.15), true))
	names.add_child(Kit.muted(sub, 11))
	head.add_child(names)
	return head


## The hover card of an item: what it is, how and when it was obtained (or how
## to get it), and what it does. `hint` is a last quiet line ("Click to change").
static func hover_item(it: Dictionary, hint: String = "") -> Control:
	var state = App.state
	var owned = state.items.get(it.id)
	var rc = Pal.rarity(it.rarity)
	var known = owned != null or Wallet.is_shop(it)
	var v = Kit.vbox(7)
	var pic = PixFit.make(Art.item_icon_texture(it.id, not known), Vector2(40, 40), 4)
	v.add_child(_hover_head(pic, it.name if known else "Locked item", rc, "%s · %s" % [str(it.rarity).capitalize(), TT.SLOT_NAMES[it.slot]]))
	v.add_child(Kit.divider())
	if owned != null:
		v.add_child(origin_row(item_origin(it, owned)))
	elif Wallet.is_shop(it):
		var wk = Dates.week_key(App.today)
		var check = Wallet.can_buy(state, it, wk)
		var need = "Costs %s coins" % Xp.fmt_int(check.price)
		if check.why == "level":
			need = "Sold from hero level %d" % Wallet.min_level(it)
		elif check.why == "coins":
			need = "%s coins: %s more to go" % [Xp.fmt_int(check.price), Xp.fmt_int(int(check.price) - App.coins())]
		v.add_child(origin_row({"icon": "bag", "title": "For sale in the shop", "sub": need}))
	else:
		v.add_child(origin_row({"icon": "lock", "title": "Not found yet", "sub": Icons.strip_emoji(Items.unlock_hint(it))}))
		var prog = Items.unlock_progress(it, state)
		if prog != null:
			v.add_child(Parts.progress_line(prog, rc))
	v.add_child(effect_block(it.get("perk"), "No bonus: worn for the look" if owned != null else "No bonus: just for the look"))
	if known and str(it.get("flavor", "")) != "":
		v.add_child(Kit.muted_para("\"%s\"" % Icons.strip_emoji(str(it.flavor)), 11))
	if hint != "":
		v.add_child(Kit.label(hint, 10, Pal.with_alpha(Pal.MUTED, 0.7)))
	return v


## The hover card of a companion.
static func hover_pet(p: Dictionary, hint: String = "") -> Control:
	var state = App.state
	var owned = state.pets.has(p.id)
	var rc = Pal.rarity(p.rarity)
	var v = Kit.vbox(7)
	var pv = PetView.new()
	pv.setup(p.id, 40.0, false)
	pv.set_locked(not owned)
	v.add_child(_hover_head(pv, "%s the %s" % [p.name, p.species] if owned else "Unknown companion", rc, "%s · Companion" % str(p.rarity).capitalize()))
	v.add_child(Kit.divider())
	if owned:
		v.add_child(origin_row(pet_origin(p, state.pets.get(p.id))))
	else:
		v.add_child(origin_row({"icon": "lock", "title": "Not met yet", "sub": Icons.strip_emoji(str(p.hint))}))
		if p.has("progress"):
			v.add_child(Parts.progress_line(p.progress.call(state), rc))
	v.add_child(effect_block(p.get("perk"), "No bonus"))
	if owned and str(p.get("flavor", "")) != "":
		v.add_child(Kit.muted_para("\"%s\"" % Icons.strip_emoji(str(p.flavor)), 11))
	if hint != "":
		v.add_child(Kit.label(hint, 10, Pal.with_alpha(Pal.MUTED, 0.7)))
	return v


## An empty slot of the paper doll.
static func hover_empty(slot_name: String, hint: String) -> Control:
	var v = Kit.vbox(4)
	v.add_child(Kit.label(slot_name, 14, null, true))
	v.add_child(Kit.muted_para("Nothing here yet.", 12))
	v.add_child(Kit.label(hint, 10, Pal.with_alpha(Pal.MUTED, 0.7)))
	return v


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
		info.add_child(origin_row(item_origin(it, owned)))
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
	elif owned:
		info.add_child(origin_row(pet_origin(p, state.pets.get(p.id))))
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
