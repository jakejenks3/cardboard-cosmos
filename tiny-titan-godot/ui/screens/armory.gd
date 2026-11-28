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
## Each gear slot's icon on its key (the grid under the page track).
const SLOT_ICONS = {"head": "crown", "face": "fx_insight", "body": "body", "hands": "strike", "legs": "st_legs", "feet": "run", "back": "bag", "accessory": "gem", "aura": "sparkle"}

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
	# (2026-11-27 review: an empty slot's name was pale tan on cream, nearly invisible, and every name sat on
	# the tile's bottom bevel) Dark ink, brown ink when empty, gold on the picked tile's dark face; a little
	# room under it so it clears the bevel.
	var cap = PixelFont.rect(SLOT_SHORT[slot], 1, Pal.GOLD_TEXT if here else (Pal.TEXT if filled else Pal.MUTED), false)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(cap)
	card.add(Kit.gap(2))
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
	# (2026-11-27 review: the effects and the rows sat loose on the planks with a body-text heading) Two
	# windows with signs, as the rest of the look: ACTIVE EFFECTS, then EQUIPPED with a slip per slot.
	var fx = ArmoryScreen.effect_sources()
	var ec = Kit.section("armory_effects", "ACTIVE EFFECTS", "bolt", Pal.GOOD, null, Callable(), 6, 10)
	if fx.is_empty():
		ec.add(Kit.muted_para("Nothing you are wearing gives a bonus yet. Gear and companions with a bolt add XP or loot luck, and they stack.", 12))
	for e in fx:
		var r = Kit.hbox(8)
		r.add_child(Kit.vcenter(Kit.badge(str(e.icon), Pal.GOOD, 16)))
		r.add_child(Kit.vcenter(Kit.tag("+%d%%" % TTUtil.jsround(float(e.pct) * 100.0), Pal.GOOD, true, 13)))
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
	var worn_n = 0
	for slot in TT.SLOTS:
		var wid = App.loadout().get(slot)
		if wid != null and App.state.items.has(wid):
			worn_n += 1
	var list = Kit.section("armory_equipped", "EQUIPPED", "armory", Pal.tab("armory"), Kit.label("%d of %d worn" % [worn_n, TT.SLOTS.size()], 12, Pal.TEXT, true), Callable(), 6, 10)
	for slot in TT.SLOTS:
		var id = App.loadout().get(slot)
		var it = Items.by_id(id) if (id != null and App.state.items.has(id)) else null
		if it != null:
			var o = ArmoryDetail.item_origin(it, App.state.items.get(it.id))
			list.add(_equipped_row(TT.SLOT_NAMES[slot], PixFit.make(Art.item_icon_texture(it.id), Vector2(40, 40), 3), it.name, Pal.rarity(it.rarity), str(it.rarity), o, it.get("perk"), ArmoryDetail.open_item.bind(it)))
		else:
			list.add(_empty_row(TT.SLOT_NAMES[slot], slot))
	var pet = _active_pet()
	if pet != null:
		var pv = PetView.new()
		pv.setup(pet.id, 40.0, false)
		list.add(_equipped_row("Companion", pv, "%s the %s" % [pet.name, pet.species], Pal.rarity(pet.rarity), str(pet.rarity), ArmoryDetail.pet_origin(pet, App.state.pets.get(pet.id)), pet.get("perk"), ArmoryDetail.open_pet.bind(pet)))
	else:
		list.add(_empty_row("Companion", "pets"))
	add_child(list)


## One worn thing: its picture, its name, how and when it was obtained, and what it does.
func _equipped_row(slot_name: String, pic: Control, title: String, rc: Color, rarity: String, origin: Dictionary, perk, on_tap: Callable) -> Control:
	# A cream slip in the EQUIPPED window (its rarity is the picture's ring and the tag).
	var card = Kit.row(on_tap, rc, null, 8, 4)
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
	# (the slot's name was tiny 1x pixel letters in brown ink)
	top.add_child(Kit.vcenter(Kit.label(slot_name.to_upper(), 11, Pal.TEXT, true)))
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
	# (2026-11-27 review: "Pick" was a tiny flat label and the slot's name tiny pixel letters) A slip with the
	# slot's name as its title, and Pick a real green key.
	var card = Kit.row(_set_tab.bind(to_tab), null, null, 8, 4)
	var row = Kit.hbox(10)
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 3, "pad_v": 3}))
	plate.add_child(PixFit.make(Icons.tex("plus", Pal.LINE), Vector2(40, 40), 1))
	row.add_child(plate)
	var main = Kit.vbox(2)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(Kit.clip(slot_name, 15, Pal.TEXT, true))
	main.add_child(Kit.label("Nothing here yet", 12, Pal.MUTED))
	row.add_child(main)
	var pick = Kit.button("Pick", "good", _set_tab.bind(to_tab), "sm")
	pick.tooltip_text = "Pick something for this slot"
	row.add_child(Kit.vcenter(pick))
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
	# (2026-11-27 review: thirteen tan chips wrapped into four ragged rows, one alone on the last) A pick-one
	# track for the four pages, then the nine gear slots as a 3 x 3 grid of equal keys, each with its icon and
	# how many of its pieces are found: every row full.
	var v = Kit.vbox(8)
	var pages = []
	for p in [["equipped", "Equipped"], ["shop", "Shop"], ["pets", "Pets"], ["look", "Look"]]:
		var k = Kit.choice(str(p[1]), tab == str(p[0]), _set_tab.bind(str(p[0])), Pal.ACCENT2, 13)
		k.set_meta("armory_page", str(p[0]))
		pages.append(k)
	v.add_child(Kit.choice_track(pages))
	var g = Kit.grid(3, 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in TT.SLOTS:
		var c = counts.get(s, [0, 0])
		g.add_child(_slot_key(s, int(c[0]), int(c[1])))
	v.add_child(g)
	return v


## One gear slot's key: its icon and name, and under them how many of its pieces are found. The picked one
## is orange, like the track's. The key's own text ("Head 14/25") is hidden (it still names it for the
## screen's anchoring and the walkthroughs): the row on top draws the words.
func _slot_key(s: String, have: int, total: int) -> Button:
	var on = tab == s
	var b = Kit.chip("%s %d/%d" % [TT.SLOT_NAMES[s], have, total], on, _set_tab.bind(s), Pal.ACCENT2, 13)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s: %d of %d found" % [TT.SLOT_NAMES[s], have, total]
	b.clip_text = true
	var fg: Color = b.get_meta("tt_fg", Pal.INK)
	var ol = int(b.get_meta("tt_outline", 0))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	b.custom_minimum_size.y = 50 if Kit.fingers else 44
	# A chip's lip: 1 art pixel of side and the rim under it; the face sinks by that much when pressed.
	var drop = 2 * PixBox.S
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_bottom = -drop
	var top = Kit.hbox(5)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(Kit.vcenter(Icons.rect(str(SLOT_ICONS.get(s, "armory")), 16)))
	var nm = Kit.label(TT.SLOT_NAMES[s], 13, fg, true)
	top.add_child(Kit.vcenter(nm))
	col.add_child(top)
	var n = Kit.label("%d/%d" % [have, total], 11, fg, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not on:
		n.add_theme_color_override("font_color", Pal.MUTED)
	col.add_child(n)
	for l in [nm, n]:
		if ol > 0:
			l.add_theme_constant_override("outline_size", ol)
			l.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	b.add_child(col)
	var fit = func():
		b.custom_minimum_size.x = col.get_combined_minimum_size().x + 22
	fit.call()
	col.minimum_size_changed.connect(fit)
	b.button_down.connect(func():
		col.offset_top = drop
		col.offset_bottom = 0)
	b.button_up.connect(func():
		col.offset_top = 0
		col.offset_bottom = -drop)
	return b


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
	var prow = Kit.hbox(12)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (2026-11-27 review: the big number was pale gold pixel digits on the sand, the least readable thing on
	# the screen) The coins sit in a dark cap with gold digits, as the top bar's coin pill, only big.
	var cap = PanelContainer.new()
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", PixBox.material("cap", {"pad_h": 10, "pad_v": 6}))
	var ch = Kit.hbox(8)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(Kit.vcenter(Icons.rect("coin", 32)))
	ch.add_child(Kit.vcenter(Kit.big_number(Xp.fmt_int(balance), Pal.GOLD_TEXT, 170, 4)))
	cap.add_child(ch)
	prow.add_child(Kit.vcenter(cap))
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

	# (2026-11-27 review: names were cut off, "Bounty Hunter's C...") The name wraps onto two centred lines;
	# every tile keeps room for two, so the tiles of a row stay alike.
	var n = Kit.label(title, 12, Pal.MUTED if locked else (Pal.GOLD_TEXT if active else Pal.TEXT), true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.max_lines_visible = 2
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.custom_minimum_size = Vector2(20, ceilf(Kit.font_bold().get_height(12)) * 2.0 + 2.0)
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
