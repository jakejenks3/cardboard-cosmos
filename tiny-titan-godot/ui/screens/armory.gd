class_name ArmoryScreen
extends UiScreen
## Armory tab: dress the hero in unlocked gear, pick a companion, change the
## look, and spend coins in the shop.
## Port of tiny-titan/src/screens/Armory.tsx (the shop, the paper doll and the
## Equipped list were added after the port).
##
## At the top the hero stands on a stage with a slot on each side for every
## place gear can go (and one for the companion): what is in a slot is drawn
## in it, hovering shows how and when it was obtained and what it does, and a
## click opens that slot's gear. The "Equipped" tab lists the same as rows.
##
## Tapping an owned item puts it on at once (sparks, and the hero updates);
## tapping what the hero already wears, or a locked item, opens its detail
## sheet. The small "i" on a tile (or a right-click) opens the details.
## Companions work the same way. Shop items show the hero trying them on, with
## the price; tapping one opens its sheet, where it can be bought.

const TILE_COLS = 3
## The slots on each side of the hero, top to bottom ("pet" = the companion).
const DOLL_LEFT = ["head", "face", "body", "hands", "legs"]
const DOLL_RIGHT = ["aura", "back", "accessory", "feet", "pet"]
const SLOT_SHORT = {"head": "HEAD", "face": "FACE", "body": "BODY", "hands": "HANDS", "legs": "LEGS", "feet": "FEET", "back": "BACK", "accessory": "EXTRA", "aura": "AURA", "pet": "PET"}

## "equipped" | "shop" | "head" … "aura" | "pets" | "look"
var tab: String = "equipped"
## Shop list: "sale" (not owned yet) | "owned".
var shop_show: String = "sale"


func build() -> void:
	if App.armory_tab_request != "":
		tab = App.armory_tab_request
		App.armory_tab_request = ""
	var state = App.state

	# --- header: the title, the coins and two count chips ------------------------
	var head = Kit.hbox(8)
	var title = Kit.h1("Armory")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var coins = Kit.purse_pill(App.coins(), "Coins to spend in the shop. Tap to open it.", 13)
	coins.gui_input.connect(_coins_input)
	coins.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.add_child(coins)
	head.add_child(Kit.pill("chest", "%d/%d" % [state.items.size(), Items.all().size()], Pal.PANEL2, "Gear collected", Pal.TEXT))
	head.add_child(Kit.pill("paw", "%d/%d" % [state.pets.size(), Pets.all().size()], Pal.PANEL2, "Companions found", Pal.TEXT))
	add_child(head)

	add_child(_hero_card())
	add_child(_tabs())

	if tab == "equipped":
		_equipped()
	elif tab == "look":
		var card = Kit.card(8)
		var p = App.profile()
		card.add(Parts.appearance_editor(int(p.get("skin", 0)), int(p.get("hairStyle", 0)), int(p.get("hairColor", 0)), _on_look, int(p.get("facialHair", 0))))
		add_child(card)
	elif tab == "pets":
		add_child(_pet_grid())
	elif tab == "shop":
		_shop()
	else:
		add_child(_item_grid())


func _coins_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_tab("shop")


# ---------------------------------------------------------------------------
# The paper doll: the hero on a stage with a slot for everything worn
# ---------------------------------------------------------------------------

## The active companion's catalog entry, or null.
func _active_pet():
	var id = App.active_pet()
	if id == null or not App.state.pets.has(id):
		return null
	return Pets.by_id(id)


## The hero, big and in the middle, on a stage; the slots on each side; the
## active bonuses as chips underneath.
func _hero_card() -> Control:
	var card = Kit.card(8, Callable(), 10)
	card.accent(Pal.tab("armory"))
	var row = Kit.hbox(8)

	var left = Kit.vbox(4)
	for s in DOLL_LEFT:
		left.add_child(_slot_tile(s))
	row.add_child(left)

	var well = PanelContainer.new()
	well.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stage = Stage.new()
	stage.setup(Pal.tab("armory"), 4)
	well.add_child(stage)
	var hero = HeroView.new()
	hero.min_scale = 4
	hero.setup(App.state, App.profile(), App.loadout(), null, false)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.size_flags_vertical = Control.SIZE_SHRINK_END
	hero.tooltip_text = "Tap to flex"
	well.add_child(hero)
	var pet = _active_pet()
	if pet != null:
		var pv = PetView.new()
		pv.setup(pet.id, 56.0, true)
		pv.size_flags_horizontal = Control.SIZE_SHRINK_END
		pv.size_flags_vertical = Control.SIZE_SHRINK_END
		# Feet on the same floor line as the hero's.
		var corner = Kit.pad(pv, 0, 0, 2, 8)
		corner.size_flags_horizontal = Control.SIZE_SHRINK_END
		corner.size_flags_vertical = Control.SIZE_SHRINK_END
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(corner)
	row.add_child(well)

	var right = Kit.vbox(4)
	for s in DOLL_RIGHT:
		right.add_child(_slot_tile(s))
	row.add_child(right)
	card.add(row)

	var chips = Kit.flow(6)
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	var perks = App.perks
	for d in TT.DISCIPLINES:
		var v = float(perks.xp.get(d, 0))
		if v > 0.0:
			chips.add_child(Kit.pill(d, "+%d%% XP" % TTUtil.jsround(v * 100.0), Pal.GOOD, "+%d%% %s XP" % [TTUtil.jsround(v * 100.0), str(TT.DISCIPLINE_META[d].name).to_lower()]))
	if float(perks.get("luck", 0)) > 0.0:
		chips.add_child(Kit.pill("dice", "+%d%% luck" % TTUtil.jsround(float(perks.luck) * 100.0), Pal.GOOD, "Better loot drops"))
	if chips.get_child_count() == 0:
		chips.add_child(Kit.pill("bolt", "No bonuses yet", Pal.PANEL2, "Gear and companions with perks add XP bonuses. Perks stack.", Pal.MUTED))
	card.add(chips)
	return card


## One slot of the paper doll: what is in it (or the slot's name when empty).
## Hover: what it is, how it was obtained, what it does. Click: that slot's gear.
func _slot_tile(slot: String) -> Control:
	var is_pet = slot == "pet"
	var item = null
	var pet = null
	var rc = Pal.LINE
	if is_pet:
		pet = _active_pet()
		if pet != null:
			rc = Pal.rarity(pet.rarity)
	else:
		var id = App.loadout().get(slot)
		if id != null and App.state.items.has(id):
			item = Items.by_id(id)
		if item != null:
			rc = Pal.rarity(item.rarity)
	var filled = item != null or pet != null
	var here = tab == ("pets" if is_pet else slot)
	var card = Kit.card(1, _set_tab.bind("pets" if is_pet else slot), 3)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if here:
		card.accent(Pal.ACCENT, true)
	elif filled:
		# A lighter plate, so dark gear (navy shorts, a black tee) stands out.
		card.tint(Pal.PANEL2.lightened(0.06), rc)
	else:
		card.accent(rc)
	var box = Vector2(46, 34)
	var pic: Control
	if item != null:
		pic = PixFit.make(Art.item_icon_texture(item.id), box, 3)
	elif pet != null:
		pic = PixFit.make(Art.pet_texture(pet.id, 0, false), box, 2)
	else:
		pic = PixFit.make(Icons.tex("plus", Pal.LINE), box, 1)
	card.add(pic)
	var cap = PixelFont.rect(SLOT_SHORT[slot], 1, Pal.ACCENT if here else (Pal.TEXT if filled else Pal.LINE), false)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(cap)
	# A small bolt in the corner when what is worn here does something.
	var perk = item.get("perk") if item != null else (pet.get("perk") if pet != null else null)
	if not Items.perk_summary(perk).is_empty():
		var bolt = Icons.rect("bolt", 16)
		bolt.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		bolt.offset_left = -14
		bolt.offset_right = 2
		bolt.offset_top = -4
		bolt.offset_bottom = 12
		pic.add_child(bolt)
	Kit.passthrough(card.box)
	var rarity = str(item.rarity) if item != null else (str(pet.rarity) if pet != null else "")
	if rarity == "legendary" or rarity == "epic":
		Fx.twinkle(card, rc.lightened(0.5), 2 if rarity == "legendary" else 1)
	var hint = "Click to change"
	if item != null:
		HoverCard.attach(card, ArmoryDetail.hover_item.bind(item, hint), rc, true)
	elif pet != null:
		HoverCard.attach(card, ArmoryDetail.hover_pet.bind(pet, hint), rc, true)
	else:
		HoverCard.attach(card, ArmoryDetail.hover_empty.bind("Companion" if is_pet else TT.SLOT_NAMES[slot], "Click to pick one"), null, true)
	return card


# ---------------------------------------------------------------------------
# "Equipped": everything worn, as a list
# ---------------------------------------------------------------------------

## Where each active bonus comes from: [{"icon", "label", "pct", "from": [[name, pct]]}].
static func effect_sources() -> Array:
	var sources = []
	var loadout = App.loadout()
	for slot in TT.SLOTS:
		var id = loadout.get(slot)
		if id != null and App.state.items.has(id):
			var it = Items.by_id(id)
			if it != null and it.get("perk") is Dictionary:
				sources.append([it.name, it.perk])
	var pet_id = App.active_pet()
	if pet_id != null and App.state.pets.has(pet_id):
		var p = Pets.by_id(pet_id)
		if p != null and p.get("perk") is Dictionary:
			sources.append([p.name, p.perk])
	var out = []
	for d in TT.DISCIPLINES:
		var total = 0.0
		var from = []
		for s in sources:
			var xp = s[1].get("xp")
			if xp is Dictionary:
				var v = float(TTUtil.get_or(xp, d, 0)) + float(TTUtil.get_or(xp, "all", 0))
				if v > 0.0:
					total += v
					from.append([s[0], v])
		if total > 0.0:
			out.append({"icon": d, "label": "%s XP" % TT.DISCIPLINE_META[d].name, "pct": total, "from": from})
	var luck = 0.0
	var luck_from = []
	for s in sources:
		var v = float(TTUtil.get_or(s[1], "luck", 0))
		if v > 0.0:
			luck += v
			luck_from.append([s[0], v])
	if luck > 0.0:
		out.append({"icon": "dice", "label": "Loot luck", "pct": luck, "from": luck_from})
	return out


func _equipped() -> void:
	# --- what all of it adds up to --------------------------------------------------
	var fx = ArmoryScreen.effect_sources()
	var ec = Kit.card(6, Callable(), 10)
	ec.accent(Pal.GOOD if not fx.is_empty() else Pal.LINE)
	var eh = Kit.hbox(8)
	eh.add_child(Kit.vcenter(Icons.rect("bolt", 16)))
	eh.add_child(Kit.clip("Active effects", 14, null, true))
	ec.add(eh)
	if fx.is_empty():
		ec.add(Kit.muted_para("Nothing you are wearing gives a bonus yet. Gear and companions with a bolt add XP or loot luck, and they stack.", 12))
	for e in fx:
		var r = Kit.hbox(8)
		r.add_child(Kit.vcenter(Icons.rect(str(e.icon), 16)))
		r.add_child(Kit.vcenter(Kit.label("+%d%%" % TTUtil.jsround(float(e.pct) * 100.0), 14, Pal.GOOD, true)))
		var names = []
		for f in e.from:
			names.append("%s +%d%%" % [f[0], TTUtil.jsround(float(f[1]) * 100.0)])
		var txt = Kit.vbox(0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_child(Kit.clip(str(e.label), 13, null, true))
		txt.add_child(Kit.muted_para(" · ".join(PackedStringArray(names)), 11))
		r.add_child(txt)
		ec.add(r)
	add_child(ec)

	# --- one row per slot ---------------------------------------------------------------
	var list = Kit.vbox(6)
	for slot in TT.SLOTS:
		var id = App.loadout().get(slot)
		var it = Items.by_id(id) if (id != null and App.state.items.has(id)) else null
		if it != null:
			var o = ArmoryDetail.item_origin(it, App.state.items.get(it.id))
			list.add_child(_equipped_row(TT.SLOT_NAMES[slot], PixFit.make(Art.item_icon_texture(it.id), Vector2(40, 40), 3), it.name, Pal.rarity(it.rarity), str(it.rarity), o, it.get("perk"), ArmoryDetail.open_item.bind(it)))
		else:
			list.add_child(_empty_row(TT.SLOT_NAMES[slot], slot))
	var pet = _active_pet()
	if pet != null:
		var pv = PetView.new()
		pv.setup(pet.id, 40.0, false)
		list.add_child(_equipped_row("Companion", pv, "%s the %s" % [pet.name, pet.species], Pal.rarity(pet.rarity), str(pet.rarity), ArmoryDetail.pet_origin(pet, App.state.pets.get(pet.id)), pet.get("perk"), ArmoryDetail.open_pet.bind(pet)))
	else:
		list.add_child(_empty_row("Companion", "pets"))
	add_child(list)


## One worn thing: its picture, its name, how and when it was obtained, and what it does.
func _equipped_row(slot_name: String, pic: Control, title: String, rc: Color, rarity: String, origin: Dictionary, perk, on_tap: Callable) -> Control:
	var card = Kit.card(4, on_tap, 8)
	card.accent(rc)
	var row = Kit.hbox(10)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": rc, "lip": 0, "inset": true, "pad_h": 3, "pad_v": 3}))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_child(pic)
	row.add_child(plate)
	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top = Kit.hbox(6)
	top.add_child(Kit.vcenter(PixelFont.rect(slot_name, 1, Pal.MUTED, false)))
	top.add_child(Kit.vcenter(Kit.tag(rarity.to_upper(), rc, true, 9)))
	main.add_child(top)
	main.add_child(Kit.clip(title, 15, null, true))
	var where = str(origin.title)
	if str(origin.sub) != "":
		where += " · " + str(origin.sub)
	main.add_child(Kit.muted_para(where, 11))
	var lines = Items.perk_summary(perk)
	if lines.is_empty():
		main.add_child(Kit.label("No bonus: worn for the look", 11, Pal.with_alpha(Pal.MUTED, 0.75)))
	else:
		var f = Kit.flow(4)
		for line in lines:
			f.add_child(Kit.pill("bolt", line, Pal.GOOD, "", null, 11))
		main.add_child(f)
	row.add_child(main)
	row.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	card.add(row)
	Kit.passthrough(card.box)
	return card


## A slot with nothing in it: tap to go and pick something.
func _empty_row(slot_name: String, to_tab: String) -> Control:
	var card = Kit.card(4, _set_tab.bind(to_tab), 8)
	var row = Kit.hbox(10)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 3, "pad_v": 3}))
	plate.add_child(PixFit.make(Icons.tex("plus", Pal.LINE), Vector2(40, 40), 1))
	row.add_child(plate)
	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(PixelFont.rect(slot_name, 1, Pal.MUTED, false))
	main.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main.add_child(Kit.label("Nothing here", 14, Pal.MUTED, true))
	row.add_child(main)
	row.add_child(Kit.vcenter(Kit.tag("Pick", Pal.PANEL2, false, 11)))
	card.add(row)
	Kit.passthrough(card.box)
	return card


## Human-readable active bonuses, e.g. ["+3% lifting XP", "+10% loot luck"].
static func perk_bits(perks: Dictionary) -> Array:
	var out = []
	for d in TT.DISCIPLINES:
		var v = float(perks.xp.get(d, 0))
		if v > 0.0:
			out.append("+%d%% %s XP" % [TTUtil.jsround(v * 100.0), str(TT.DISCIPLINE_META[d].name).to_lower()])
	if float(perks.get("luck", 0)) > 0.0:
		out.append("+%d%% loot luck" % TTUtil.jsround(float(perks.luck) * 100.0))
	return out


# ---------------------------------------------------------------------------
# Equipped / shop / slot / pets / look chips
# ---------------------------------------------------------------------------

func _tabs() -> Control:
	var counts = {}
	for it in Items.all():
		if not counts.has(it.slot):
			counts[it.slot] = [0, 0]
		counts[it.slot][1] += 1
		if App.state.items.has(it.id):
			counts[it.slot][0] += 1
	var f = Kit.flow(6)
	var worn_chip = Kit.chip("Equipped", tab == "equipped", _set_tab.bind("equipped"), Pal.tab("armory"))
	worn_chip.icon = Icons.tex("armory")
	f.add_child(worn_chip)
	var shop_chip = Kit.chip("Shop", tab == "shop", _set_tab.bind("shop"), Pal.ACCENT)
	shop_chip.icon = Icons.tex("bag")
	f.add_child(shop_chip)
	for s in TT.SLOTS:
		var c = counts.get(s, [0, 0])
		f.add_child(Kit.chip("%s %d/%d" % [TT.SLOT_NAMES[s], c[0], c[1]], tab == s, _set_tab.bind(s)))
	var pets_chip = Kit.chip("Pets %d/%d" % [App.state.pets.size(), Pets.all().size()], tab == "pets", _set_tab.bind("pets"))
	pets_chip.icon = Icons.tex("paw")
	f.add_child(pets_chip)
	var look_chip = Kit.chip("Look", tab == "look", _set_tab.bind("look"))
	look_chip.icon = Icons.tex("body")
	f.add_child(look_chip)
	return f


func _set_tab(t: String) -> void:
	if tab == t:
		return
	tab = t
	Sfx.tick()
	rebuild()


func _on_look(patch: Dictionary) -> void:
	Sfx.tap()
	App.update_profile(patch)


# ---------------------------------------------------------------------------
# The shop
# ---------------------------------------------------------------------------

func _shop() -> void:
	var state = App.state
	var wk = Dates.week_key(App.today)
	var balance = App.coins()

	# --- the purse ---------------------------------------------------------------
	var purse = Kit.card(6, Callable(), 12)
	purse.accent(Pal.ACCENT)
	purse.mouse_filter = Control.MOUSE_FILTER_STOP
	# (No word of bosses while the campaign is off the screens: Campaign.ON_SCREEN.)
	purse.tooltip_text = "You earn 1 coin for every 10 XP you log.\n%s, trophies and missions pay extra." % ("Weekly bounties, bosses" if Campaign.ON_SCREEN else "Weekly bounties")
	var prow = Kit.hbox(10)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(Kit.vcenter(Icons.rect("coin", 40)))
	prow.add_child(Kit.vcenter(PixelFont.rect(Xp.fmt_int(balance), 4, Pal.ACCENT)))
	var pcap = Kit.vbox(0)
	pcap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pcap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pcap.add_child(Kit.label("coins", 14, null, true))
	var c = state.get("coins")
	if c is Dictionary:
		pcap.add_child(Kit.muted("earned %s · spent %s" % [Xp.fmt_int(c.earned), Xp.fmt_int(c.spent)], 11))
	prow.add_child(pcap)
	purse.add(prow)
	add_child(purse)

	# --- this week's deal -----------------------------------------------------------
	var deal = Items.by_id(Wallet.deal_id(wk))
	if deal != null:
		add_child(_deal_card(deal, wk))

	# --- everything for sale ---------------------------------------------------------
	var all = Wallet.shop_items()
	var n_owned = all.filter(func(i): return state.items.has(i.id)).size()
	add_child(Kit.segmented([
		{"value": "sale", "label": "For sale %d" % (all.size() - n_owned)},
		{"value": "owned", "label": "Bought %d" % n_owned},
	], shop_show, _set_shop_show, Pal.ACCENT))
	var list = all.filter(func(i): return state.items.has(i.id) == (shop_show == "owned"))
	if list.is_empty():
		if shop_show == "owned":
			add_child(Kit.empty("bag", "Nothing bought yet", "Tap anything for sale to try it on."))
		else:
			add_child(Kit.empty("trophy", "You bought the lot", "The shelves are empty. Respect."))
		return
	var g = Kit.grid(TILE_COLS, 8)
	var loadout = App.loadout()
	for it in list:
		g.add_child(_shop_tile(it, wk, loadout, true))
	add_child(g)


func _set_shop_show(v) -> void:
	shop_show = str(v)
	Sfx.tick()
	rebuild()


## The week's 30%-off item, with the hero trying it on.
func _deal_card(it: Dictionary, wk: String) -> Control:
	var state = App.state
	var owned = state.items.has(it.id)
	var rc = Pal.rarity(it.rarity)
	var card = Kit.card(6, ArmoryDetail.open_item.bind(it), 10)
	card.accent(Pal.GOOD, true)
	if not owned:
		Fx.shine(card, 4.0, 1.2, 0.2)
	var row = Kit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic = PixelRect.make(Art.item_tryon_texture(it.id, state, App.profile(), App.loadout()), 2.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": rc, "lip": 0, "inset": true, "pad_h": 2, "pad_v": 2}))
	plate.add_child(pic)
	row.add_child(plate)
	var main = Kit.vbox(5)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kick = Kit.hbox(6)
	kick.add_child(Kit.tag("DEAL OF THE WEEK", Pal.GOOD, true, 10))
	kick.add_child(Kit.tag("-%d%%" % TTUtil.jsround(Wallet.DEAL_OFF * 100.0), Pal.ACCENT, true, 10))
	main.add_child(kick)
	main.add_child(Kit.clip(it.name, 17, null, true))
	var prices = Kit.hbox(8)
	if owned:
		prices.add_child(Kit.pill("check", "Yours already", Pal.PANEL2, "", Pal.TEXT))
	else:
		prices.add_child(Kit.coin_pill(Wallet.price(it, wk), "", 14))
		prices.add_child(Kit.vcenter(Kit.muted("was %s" % Xp.fmt_int(Wallet.base_price(it)), 12)))
	main.add_child(prices)
	var left = Bounty.days_left(App.today)
	main.add_child(Kit.muted("New deal on Monday (%d day%s left)" % [left, "" if left == 1 else "s"], 11))
	row.add_child(main)
	row.add_child(Kit.vcenter(Icons.rect("chevron_right", 18)))
	card.add(row)
	return card


## A shop tile: the hero trying the item on (zoomed in on where it goes), its
## name and its price. `mixed` is for the shop's own list, where every slot is
## side by side: the pictures then get one height, so the rows line up.
func _shop_tile(it: Dictionary, wk: String, loadout: Dictionary, mixed: bool = false) -> Control:
	var state = App.state
	var owned = state.items.has(it.id)
	var rc = Pal.rarity(it.rarity)
	var tex = Art.item_tryon_texture(it.id, state, App.profile(), loadout)
	var check = Wallet.can_buy(state, it, wk)
	var pic = _zoomed(tex, it.slot, 112.0 if mixed else 0.0)
	if mixed:
		var frame = CenterContainer.new()
		frame.custom_minimum_size = Vector2(0, 120)
		frame.add_child(pic)
		pic = frame
	var card = _tile(pic, it.name, rc, false, false, ArmoryDetail.open_item.bind(it), Callable(), null, false)
	if owned:
		card.add(Kit.center(Kit.pill("check", "Owned", Pal.PANEL2, "", Pal.TEXT, 11)))
	elif check.why == "level":
		card.add(Kit.center(Kit.pill("lock", "Lv %d" % Wallet.min_level(it), Pal.PANEL2, "", Pal.MUTED, 11)))
	else:
		var price = Kit.pill("coin", Xp.fmt_int(check.price), Pal.ACCENT if check.ok else Pal.PANEL2, "", null if check.ok else Pal.MUTED, 12)
		card.add(Kit.center(price))
	if it.id == Wallet.deal_id(wk) and not owned:
		card.accent(Pal.GOOD)
	Kit.passthrough(card.box)
	HoverCard.attach(card, ArmoryDetail.hover_item.bind(it, "Click to try it on"), rc)
	return card


# ---------------------------------------------------------------------------
# Item grid
# ---------------------------------------------------------------------------

## Items of a slot: owned first, then by rarity (stable, like the web sort).
static func slot_items(slot: String, state: Dictionary) -> Array:
	var list = Items.all().filter(func(i): return i.slot == slot)
	TTUtil.stable_sort(list, func(a, b): return ArmoryScreen._item_rank(a, state) < ArmoryScreen._item_rank(b, state))
	return list


static func _item_rank(it: Dictionary, state: Dictionary) -> int:
	var owned = 0 if state.items.has(it.id) else 1
	return owned * 10 + TT.RARITY_ORDER.find(it.rarity)


## The part of the hero a slot is about, as [x, y, w, h] in art pixels, and the
## whole-number scale it is shown at: a hat fills its tile instead of being a
## few pixels on a small figure. Back gear and auras need the whole hero.
static func slot_view(slot: String) -> Dictionary:
	var m = HeroBody.body_metrics(Art.body_input(App.state, App.profile(), "idle", 0, false))
	var cx = int(m.cx)
	match slot:
		"head", "face":
			return {"rect": Rect2(cx - 13, int(m.headTop) - 12, 26, 27), "scale": 4}
		"body", "accessory":
			return {"rect": Rect2(cx - 16, int(m.neckTop) - 1, 32, int(m.torsoH) + 9), "scale": 3}
		"hands":
			return {"rect": Rect2(cx - 20, int(m.torsoTop) - 2, 40, int(m.torsoH) + 11), "scale": 3}
		"legs":
			return {"rect": Rect2(cx - 13, int(m.legTop) - 5, 26, int(m.legLen) + 11), "scale": 4}
		"feet":
			return {"rect": Rect2(cx - 13, int(m.feetTop) - 9, 26, 15), "scale": 4}
	return {"rect": Rect2(0, 0, HeroBody.width(), HeroBody.height()), "scale": 2}


## A hero texture zoomed in on what `slot` is about.
## `max_w` (shop's mixed grid): a view wider than that loses a few columns at
## its sides, so three tiles always fit the column (the widest were 124 px).
func _zoomed(tex: Texture2D, slot: String, max_w: float = 0.0) -> Control:
	var v = ArmoryScreen.slot_view(slot)
	var r: Rect2 = v.rect.intersection(Rect2(0, 0, tex.get_width(), tex.get_height()))
	if max_w > 0.0 and r.size.x * float(v.scale) > max_w:
		var keep = floorf(max_w / float(v.scale))
		r.position.x += floorf((r.size.x - keep) / 2.0)
		r.size.x = keep
	var at = AtlasTexture.new()
	at.atlas = tex
	at.region = r
	at.filter_clip = true
	return PixelRect.make(at, float(v.scale))


func _item_grid() -> Control:
	var g = Kit.grid(TILE_COLS, 8)
	var loadout = App.loadout()
	var wk = Dates.week_key(App.today)
	if tab == "body":
		var bare = loadout.duplicate()
		bare["body"] = null
		var tex = Art.hero_texture(App.state, App.profile(), bare)
		var shirtless = loadout.get("body") == null
		var bt = _tile(_zoomed(tex, tab), "Shirtless", Pal.LINE, shirtless, false, Callable() if shirtless else _equip_now.bind("body", null), Callable(), null, true)
		bt.tooltip_text = "Show off the gains"
		g.add_child(bt)
	for it in ArmoryScreen.slot_items(tab, App.state):
		var owned = App.state.items.has(it.id)
		if not owned and Wallet.is_shop(it):
			# For sale: shown on the hero, with its price.
			g.add_child(_shop_tile(it, wk, loadout))
			continue
		var equipped = loadout.get(it.slot) == it.id
		var tex = Art.item_preview_texture(it.id, App.state, App.profile(), loadout, not owned)
		var tap = Callable()
		if owned and not equipped:
			tap = _equip_now.bind(it.slot, it.id)
		else:
			tap = ArmoryDetail.open_item.bind(it)
		var prog = null if owned else Items.unlock_progress(it, App.state)
		var tile = _tile(_zoomed(tex, tab), it.name if owned else "???", Pal.rarity(it.rarity), equipped, not owned, tap, ArmoryDetail.open_item.bind(it), prog, owned and not equipped)
		var hint = "Click for details"
		if owned:
			hint = "Click for details" if equipped else "Click to wear it"
		HoverCard.attach(tile, ArmoryDetail.hover_item.bind(it, hint), Pal.rarity(it.rarity))
		g.add_child(tile)
	return g


func _equip_now(slot: String, id) -> void:
	if id != null and not App.state.items.has(id):
		return
	Sfx.tap()
	App.equip(slot, id)


## A tile tapped to put something on: sparks from the tile, then the action.
func _tap_burst(card: Control, col: Color, cb: Callable) -> void:
	Kit.burst(card, col, 20)
	cb.call()


## One grid tile: the picture on a rarity-coloured edge and the name under it.
## Worn = gold edge and an "ON" chip; locked = dimmed with a lock; the small
## "i" opens the details (as does a right-click).
func _tile(pic: Control, title: String, rc: Color, active: bool, locked: bool, on_tap: Callable, on_info: Callable, progress = null, burst: bool = false) -> Card:
	var card = Kit.card(4, Callable(), 6)
	if on_tap.is_valid():
		card.on_tap(_tap_burst.bind(card, rc, on_tap) if burst else on_tap)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if active:
		card.accent(Pal.ACCENT, true)
	else:
		card.accent(rc)
	if on_info.is_valid():
		card.gui_input.connect(_tile_input.bind(on_info))

	var holder = MarginContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if locked:
		pic.modulate = Color(1, 1, 1, 0.45)
	holder.add_child(Kit.center(pic))
	var top = Kit.hbox(0)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if on_info.is_valid():
		var info = Kit.icon_button("info", on_info, "", 26)
		info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(info)
	top.add_child(Kit.spacer())
	if active:
		top.add_child(Kit.pill("", "ON", Pal.ACCENT, "", null, 11))
		Fx.shine(card, 5.5, 0.8, 0.22)
	elif locked:
		top.add_child(Icons.rect("lock", 20))
	holder.add_child(top)
	card.add(holder)

	var n = Kit.clip(title, 12, Pal.MUTED if locked else (Pal.ACCENT if active else null), true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(n)
	if progress != null:
		card.add(Kit.bar(Goals.progress_ratio(progress), rc, 4))
	Kit.passthrough(card.box)
	return card


func _tile_input(event: InputEvent, on_info: Callable) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		on_info.call()


# ---------------------------------------------------------------------------
# Companions
# ---------------------------------------------------------------------------

func _pet_grid() -> Control:
	var g = Kit.grid(TILE_COLS, 8)
	var active = App.active_pet()
	for p in Pets.all():
		var owned = App.state.pets.has(p.id)
		var is_active = active == p.id
		var pv = PetView.new()
		pv.setup(p.id, 72.0, is_active)
		pv.set_locked(not owned)
		var holder = Kit.pad(pv, 0, 14, 0, 4)
		var tap = Callable()
		if owned and not is_active:
			tap = _follow_now.bind(p)
		else:
			tap = ArmoryDetail.open_pet.bind(p)
		var prog = null
		if not owned and p.has("progress"):
			prog = p.progress.call(App.state)
		var tile = _tile(holder, p.name if owned else "???", Pal.rarity(p.rarity), is_active, not owned, tap, ArmoryDetail.open_pet.bind(p), prog, owned and not is_active)
		var hint = "Click for details"
		if owned and not is_active:
			hint = "Click to bring along"
		HoverCard.attach(tile, ArmoryDetail.hover_pet.bind(p, hint), Pal.rarity(p.rarity))
		g.add_child(tile)
	return g


func _follow_now(p: Dictionary) -> void:
	if not App.state.pets.has(p.id):
		return
	Sfx.pet()
	App.set_active_pet(p.id)
	App.toast("%s is now following you" % p.name, "good", "paw")
