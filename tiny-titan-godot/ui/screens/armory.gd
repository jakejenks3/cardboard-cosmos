class_name ArmoryScreen
extends UiScreen
## Armory tab: dress the hero in unlocked gear, pick a companion, change the look.
## Port of tiny-titan/src/screens/Armory.tsx.
##
## Tapping an owned item puts it on at once (the preview hero updates); tapping
## what the hero already wears, or a locked item, opens its detail sheet.
## Right-click any tile for its details.

const TILE_COLS = 3

## "head" … "aura" | "pets" | "look"
var tab: String = "head"


func build() -> void:
	var state = App.state
	var items_total = Items.all().size()
	var pets_total = Pets.all().size()

	# --- header ---------------------------------------------------------------
	var head = Kit.hbox(8)
	var title = Kit.h1("Armory")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Kit.vcenter(Kit.muted("%d/%d items · %d/%d pets" % [state.items.size(), items_total, state.pets.size(), pets_total], 13)))
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
	else:
		add_child(_item_grid())

	add_child(Kit.muted_para("Tip: perks stack. A full set of discipline gear plus its pet is a serious XP boost.", 13))


# ---------------------------------------------------------------------------
# Hero + active bonuses
# ---------------------------------------------------------------------------

func _hero_card() -> Control:
	var card = Kit.card(0, Callable(), 12)
	var row = Kit.hbox(14)
	var hero = HeroView.new()
	hero.setup(App.state, App.profile(), App.loadout(), null, false)
	hero.custom_minimum_size = Vector2(120, 124)
	hero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hero)

	var info = Kit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(Kit.label("ACTIVE BONUSES", 11, Pal.MUTED, true))
	var bits = ArmoryScreen.perk_bits(App.perks)
	if bits.is_empty():
		info.add_child(Kit.muted_para("None yet — gear with perks shows up as you progress.", 13))
	for b in bits:
		info.add_child(Kit.para(b, 14, Pal.GOOD, true))
	var pet = Pets.by_id(App.active_pet()) if App.active_pet() != null else null
	if pet != null and App.state.pets.has(pet.id):
		var pr = Kit.hbox(6)
		pr.add_child(Kit.vcenter(Icons.rect("paw", 16)))
		var t = Kit.para("%s the %s" % [pet.name, pet.species], 13, Pal.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pr.add_child(t)
		info.add_child(Kit.gap(2))
		info.add_child(pr)
	row.add_child(info)
	card.add(row)
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
# Slot / pets / look chips
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
	if tab == "body":
		var bare = loadout.duplicate()
		bare["body"] = null
		var tex = Art.hero_texture(App.state, App.profile(), bare)
		var shirtless = loadout.get("body") == null
		g.add_child(_tile(tex, "Shirtless", "Show off the gains", Pal.LINE, shirtless, false, _equip_now.bind("body", null), Callable()))
	for it in ArmoryScreen.slot_items(tab, App.state):
		var owned = App.state.items.has(it.id)
		var equipped = loadout.get(it.slot) == it.id
		var tex = Art.item_preview_texture(it.id, App.state, App.profile(), loadout, not owned)
		var sub = it.rarity if owned else Items.unlock_hint(it)
		var tap = Callable()
		if owned and not equipped:
			tap = _equip_now.bind(it.slot, it.id)
		else:
			tap = ArmoryDetail.open_item.bind(it)
		g.add_child(_tile(tex, it.name if owned else "???", sub, Pal.rarity(it.rarity), equipped, not owned, tap, ArmoryDetail.open_item.bind(it)))
	return g


func _equip_now(slot: String, id) -> void:
	if id != null and not App.state.items.has(id):
		return
	Sfx.tap()
	App.equip(slot, id)


## One grid tile: preview, name, sub-line, "Equipped"/"Active" badge.
func _tile(tex: Texture2D, title: String, sub: String, rc: Color, active: bool, locked: bool, on_tap: Callable, on_info: Callable, progress = null, badge: String = "EQUIPPED") -> Control:
	var card = Kit.card(3, on_tap, 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tint(Pal.PANEL, Pal.ACCENT if active else Pal.with_alpha(rc, 0.85))
	if active:
		card.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 14, Pal.ACCENT, 2, 8, 8))
	if locked:
		card.modulate.a = 0.55
	if on_info.is_valid():
		card.gui_input.connect(_tile_input.bind(on_info))
	card.tooltip_text = "Right-click for details" if on_info.is_valid() and not locked else ""

	var holder = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic = PixelRect.make(tex, 2.0) if tex.get_width() > 40 else PixelRect.make(tex, 1.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	if active:
		var top = Kit.hbox(0)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(Kit.spacer())
		top.add_child(Kit.tag(badge, Pal.ACCENT, true, 9))
		holder.add_child(top)
	card.add(holder)

	var n = Kit.clip(title, 12, null, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(n)
	var s = Kit.muted_para(sub, 11)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add(s)
	if progress != null:
		card.add(Kit.bar(Goals.progress_ratio(progress), rc, 4))
	# Rarity stripe along the bottom (the web's inset bottom shadow).
	var stripe = ColorRect.new()
	stripe.color = rc
	stripe.custom_minimum_size = Vector2(0, 3)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add(stripe)
	ArmoryScreen.passthrough(card.box)
	return card


## Let clicks on a tile's contents reach the tappable card.
static func passthrough(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passthrough(c)


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
		var card = Kit.card(3, ArmoryDetail.open_pet.bind(p), 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rc = Pal.rarity(p.rarity)
		var is_active = active == p.id
		if is_active:
			card.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 14, Pal.ACCENT, 2, 8, 8))
		else:
			card.tint(Pal.PANEL, Pal.with_alpha(rc, 0.85))
		if not owned:
			card.modulate.a = 0.55
		var holder = MarginContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pv = PetView.new()
		pv.setup(p.id, 56.0, false)
		pv.set_locked(not owned)
		pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(Kit.pad(Kit.center(pv), 0, 10, 0, 4))
		if is_active:
			var top = Kit.hbox(0)
			top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			top.add_child(Kit.spacer())
			top.add_child(Kit.tag("ACTIVE", Pal.ACCENT, true, 9))
			holder.add_child(top)
		card.add(holder)
		var n = Kit.clip(p.name if owned else "???", 12, null, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(n)
		var s = Kit.muted_para(p.species if owned else p.hint, 11)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(s)
		if not owned and p.has("progress"):
			# Locked: the rarity stripe doubles as the unlock progress.
			card.add(Kit.bar(Goals.progress_ratio(p.progress.call(App.state)), rc, 4))
		else:
			var stripe = ColorRect.new()
			stripe.color = rc
			stripe.custom_minimum_size = Vector2(0, 3)
			card.add(stripe)
		ArmoryScreen.passthrough(card.box)
		g.add_child(card)
	return g
