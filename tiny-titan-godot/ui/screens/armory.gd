class_name ArmoryScreen
extends UiScreen
## Armory tab: dress the hero in unlocked gear, pick a companion, change the
## look, and spend coins in the shop.
## Port of tiny-titan/src/screens/Armory.tsx (the shop was added after the port).
##
## Tapping an owned item puts it on at once (sparks, and the preview hero
## updates); tapping what the hero already wears, or a locked item, opens its
## detail sheet. The small "i" on a tile (or a right-click) opens the details.
## Companions work the same way. Shop items show the hero trying them on, with
## the price; tapping one opens its sheet, where it can be bought.

const TILE_COLS = 3

## "shop" | "head" … "aura" | "pets" | "look"
var tab: String = "head"
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
	var coins = Kit.coin_pill(App.coins(), "Coins to spend in the shop. Tap to open it.", 13)
	coins.gui_input.connect(_coins_input)
	coins.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head.add_child(coins)
	head.add_child(Kit.pill("chest", "%d/%d" % [state.items.size(), Items.all().size()], Pal.PANEL2, "Gear collected", Pal.TEXT))
	head.add_child(Kit.pill("paw", "%d/%d" % [state.pets.size(), Pets.all().size()], Pal.PANEL2, "Companions found", Pal.TEXT))
	add_child(head)

	add_child(_hero_card())
	add_child(_tabs())

	if tab == "look":
		var card = Kit.card(8)
		var p = App.profile()
		card.add(Parts.appearance_editor(int(p.get("skin", 0)), int(p.get("hairStyle", 0)), int(p.get("hairColor", 0)), _on_look))
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
# Hero + active bonuses
# ---------------------------------------------------------------------------

## The hero, big and in the middle, with the companion at its feet and the
## active bonuses as chips underneath.
func _hero_card() -> Control:
	var card = Kit.card(10, Callable(), 12)
	var stage = Kit.hbox(6)
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	var hero = HeroView.new()
	hero.min_scale = 3
	hero.setup(App.state, App.profile(), App.loadout(), null, false)
	hero.size_flags_vertical = Control.SIZE_SHRINK_END
	hero.tooltip_text = "Tap to flex"
	stage.add_child(hero)
	var pet = Pets.by_id(App.active_pet()) if App.active_pet() != null else null
	if pet != null and App.state.pets.has(pet.id):
		var pv = PetView.new()
		pv.setup(pet.id, 64.0, true)
		pv.size_flags_vertical = Control.SIZE_SHRINK_END
		pv.tooltip_text = "%s the %s" % [pet.name, pet.species]
		pv.mouse_filter = Control.MOUSE_FILTER_STOP
		stage.add_child(pv)
	var well = PanelContainer.new()
	well.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_theme_stylebox_override("panel", PixBox.well(10, 8, null))
	well.add_child(stage)
	card.add(well)

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
# Shop / slot / pets / look chips
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
	purse.tooltip_text = "You earn 1 coin for every 10 XP you log.\nWeekly bounties, bosses, trophies and quests pay extra."
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
		g.add_child(_shop_tile(it, wk, loadout))
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


## A shop tile: the hero trying the item on, its name and its price.
func _shop_tile(it: Dictionary, wk: String, loadout: Dictionary) -> Control:
	var state = App.state
	var owned = state.items.has(it.id)
	var rc = Pal.rarity(it.rarity)
	var tex = Art.item_tryon_texture(it.id, state, App.profile(), loadout)
	var check = Wallet.can_buy(state, it, wk)
	var tip = "%s · %s" % [str(it.rarity).capitalize(), TT.SLOT_NAMES[it.slot]]
	var perks = Items.perk_summary(it.get("perk"))
	if not perks.is_empty():
		tip += " · " + ", ".join(PackedStringArray(perks))
	var card = _tile(PixelRect.make(tex, 2.0), it.name, rc, false, false, ArmoryDetail.open_item.bind(it), Callable(), tip, null, false)
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


func _item_grid() -> Control:
	var g = Kit.grid(TILE_COLS, 8)
	var loadout = App.loadout()
	var wk = Dates.week_key(App.today)
	if tab == "body":
		var bare = loadout.duplicate()
		bare["body"] = null
		var tex = Art.hero_texture(App.state, App.profile(), bare)
		var shirtless = loadout.get("body") == null
		g.add_child(_tile(PixelRect.make(tex, 2.0), "Shirtless", Pal.LINE, shirtless, false, Callable() if shirtless else _equip_now.bind("body", null), Callable(), "Show off the gains", null, true))
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
		var tip = Items.unlock_hint(it)
		if owned:
			var perks = Items.perk_summary(it.get("perk"))
			tip = "%s · %s" % [str(it.rarity).capitalize(), ", ".join(PackedStringArray(perks))] if not perks.is_empty() else str(it.rarity).capitalize()
		var prog = null if owned else Items.unlock_progress(it, App.state)
		g.add_child(_tile(PixelRect.make(tex, 2.0), it.name if owned else "???", Pal.rarity(it.rarity), equipped, not owned, tap, ArmoryDetail.open_item.bind(it), tip, prog, owned and not equipped))
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
func _tile(pic: Control, title: String, rc: Color, active: bool, locked: bool, on_tap: Callable, on_info: Callable, tip: String = "", progress = null, burst: bool = false) -> Card:
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
	card.tooltip_text = tip

	var holder = MarginContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if locked:
		pic.modulate = Color(1, 1, 1, 0.45)
	holder.add_child(Kit.center(pic))
	var top = Kit.hbox(0)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if on_info.is_valid():
		var info = Kit.icon_button("info", on_info, "Details", 26)
		info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(info)
	top.add_child(Kit.spacer())
	if active:
		top.add_child(Kit.pill("", "ON", Pal.ACCENT, "", null, 11))
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
		pv.setup(p.id, 64.0, is_active)
		pv.set_locked(not owned)
		var holder = Kit.pad(pv, 0, 16, 0, 6)
		var tap = Callable()
		if owned and not is_active:
			tap = _follow_now.bind(p)
		else:
			tap = ArmoryDetail.open_pet.bind(p)
		var tip = "%s · %s" % [p.species, ", ".join(PackedStringArray(Items.perk_summary(p.get("perk"))))] if owned else p.hint
		var prog = null
		if not owned and p.has("progress"):
			prog = p.progress.call(App.state)
		g.add_child(_tile(holder, p.name if owned else "???", Pal.rarity(p.rarity), is_active, not owned, tap, ArmoryDetail.open_pet.bind(p), tip, prog, owned and not is_active))
	return g


func _follow_now(p: Dictionary) -> void:
	if not App.state.pets.has(p.id):
		return
	Sfx.pet()
	App.set_active_pet(p.id)
	App.toast("%s is now following you" % p.name, "good", "paw")
