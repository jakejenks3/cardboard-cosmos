class_name RealmGear
extends RefCounted
## The Gear page of the Realm (RPG_PLAN.md 7 and 10.1): what the build in use
## wears and carries. The Realm has its own gear choice per build; only gear
## and companions owned in the main game can be picked.
##
##   WORN       a paper doll like the Armory's: the hero on a stage in the
##              build's gear, the nine slots around it (the item, its plus,
##              empty ones dim) and the companion; then what the kit adds up to
##              and the sets in force. A slot opens the SLOT SHEET: every owned
##              item of the slot with its lines, set, unique and rune, and the
##              keys Wear / Upgrade / Rune.
##   RELICS     the relic slots (locked ones say the level); a slot opens the
##              relics found.
##   COMPANION  the build's companion in full, and the owned ones to pick from.
##   BELT       the belt slots with what is in stock; a slot opens the items.
##   RUNES      every rune, where it sits, "Scrap for N ore" (asks once).
##   CAMP SHOP  the eight belt items with their price keys.
##
## Every change goes through RpgSave and RpgUi.apply; a sheet that stays open
## after one is filled again in place (the key stays under the finger).
##
## Metas for tests: sections "gear_worn", "gear_relics", "gear_pet",
## "gear_belt", "gear_runes", "gear_shop"; "gear_slot" = slot (or "pet") with
## "gear_holds" and "gear_plus"; "gear_total" = line kind; "gear_set" = set id;
## "relic_slot" / "belt_slot" = index with "slot_holds"; "pet_pick" = pet id
## ("" = none) with "pet_on"; "rune_row" = rune id, "rune_scrap" = rune id;
## "shop_buy" = item id. Sheets: the slot sheet's box "slot_sheet" = slot, its
## cards "gear_item" = id (with "gear_worn"), keys "gear_wear" / "gear_upgrade"
## / "gear_rune" = id, the reason "gear_upgrade_why"; the rune sheet's box
## "rune_sheet" = item id, keys "rune_socket" = rune id and "rune_remove";
## pick sheets "pick_relic" / "pick_item" = id ("" = the Empty key).

const LEFT = ["head", "face", "body", "hands", "legs"]
const RIGHT = ["aura", "back", "accessory", "feet"]
const SHORT = {"head": "HEAD", "face": "FACE", "body": "BODY", "hands": "HANDS", "legs": "LEGS", "feet": "FEET", "back": "BACK",
	"accessory": "EXTRA", "aura": "AURA", "pet": "PET"}
const TILE_BOX = Vector2(46, 34)


## A piece was put on a moment ago: the doll of the next drawing says so.
static var just_wore = false


static func fill(box: VBoxContainer, _screen) -> void:
	var rpg = RpgUi.save()
	var have = RpgUi.owned()
	var level = RpgUi.level()
	box.add_child(_worn(rpg, have))
	box.add_child(_relics(rpg, level))
	box.add_child(_companion(rpg, have))
	box.add_child(_belt(rpg, level))
	box.add_child(_runes(rpg, have))
	box.add_child(_shop(rpg))


static func item_name(id: String) -> String:
	var it = Items.by_id(id)
	return str(it.get("name", id)) if it is Dictionary else id.capitalize()


static func _rune_of(rpg: Dictionary, rune_id) -> Variant:
	if not (rune_id is String) or rune_id == "":
		return null
	for r in rpg.get("runes", []):
		if r is Dictionary and str(r.get("id", "")) == rune_id:
			return r
	return null


## The item a rune sits in ("" = none).
static func _socket_of(rpg: Dictionary, rune_id: String) -> String:
	var socket = rpg.get("socket", {})
	for k in socket:
		if str(socket[k]) == rune_id:
			return str(k)
	return ""


static func _plus_of(rpg: Dictionary, id: String) -> int:
	var p = rpg.get("plus", {}).get(id, 0)
	return clampi(int(p) if (p is int or p is float) else 0, 0, RpgDefs.PLUS_MAX)


## What a build wears in a slot: an owned item the Realm knows, or "".
static func _worn_id(b: Dictionary, have: Dictionary, slot: String) -> String:
	var id = b.get("gear", {}).get(slot)
	if id is String and id != "" and have.items.has(id) and RpgGear.of(id) != null:
		return id
	return ""


static func _ore(rpg: Dictionary) -> int:
	return int(rpg.get("ore", 0))


# ---------------------------------------------------------------------------
# WORN: the paper doll
# ---------------------------------------------------------------------------

static func _worn(rpg: Dictionary, have: Dictionary) -> Control:
	var b = RpgSave.build_of(rpg)
	var col = RpgUi.color("realm")
	var sec = Kit.section("gear_worn", "WORN", "shield", col, RpgUi.ore_pill(_ore(rpg)), Callable(), 8, 10)
	var row = Kit.hbox(6)
	var left = Kit.vbox(4)
	for s in LEFT:
		left.add_child(_slot_tile(s, rpg, b, have))
	row.add_child(left)

	var well = PanelContainer.new()
	well.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	well.add_theme_stylebox_override("panel", PixBox.make(Pal.WELL, {"ring": null, "lip": 0, "inset": true, "pad_h": 4, "pad_v": 4}))
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.set_meta("gear_doll", true)
	var stage = Stage.new()
	stage.setup(col, 3)
	well.add_child(stage)
	var doll = RealmHero.hero_view(3)
	well.add_child(doll)
	row.add_child(well)
	if just_wore:
		# Something was just put on: he hops, and it glints.
		just_wore = false
		var cheer = func():
			doll.hop()
			BattleFx.at(well, "sparkle", well.size / 2.0, Color(1, 1, 1), 0.8, {"n": 10, "half": 24.0})
		doll.ready.connect(cheer, CONNECT_DEFERRED | CONNECT_ONE_SHOT)

	var right = Kit.vbox(4)
	for s in RIGHT:
		right.add_child(_slot_tile(s, rpg, b, have))
	right.add_child(_pet_tile(b, have))
	row.add_child(right)
	sec.add(row)

	var worn = RpgGear.worn(b.get("gear", {}), have.items)
	sec.add(Kit.sub_head("WHAT THE KIT GIVES", col, Kit.label("%d of 9 slots worn" % worn.size(), 12, Pal.MUTED)))
	var totals = RpgGear.totals(b.get("gear", {}), rpg.get("plus", {}), rpg.get("runes", []), rpg.get("socket", {}), have.items)
	if totals.is_empty():
		sec.add(RpgUi.page_note("gear_none", "Nothing worn yet. Tap a slot to put on gear you own: each piece adds attack, armor or HP."))
	else:
		var chips = Kit.flow(6)
		for k in RpgGear.LINE_KINDS:
			if not totals.has(k):
				continue
			var words = RpgGear.line_words({"k": k, "v": totals[k]})
			if words == "":
				continue
			var tag = Kit.tag(words, _line_color(str(k)), true, 12)
			tag.set_meta("gear_total", str(k))
			chips.add_child(tag)
		sec.add(chips)

	var sets = RpgGear.sets_in_force(b.get("gear", {}), have.items)
	sec.add(Kit.sub_head("SETS", col))
	if sets.is_empty():
		sec.add(RpgUi.page_note("sets_none", "No set pieces worn. Two pieces of one set give a bonus, four a bigger one."))
	for s in sets:
		sec.add(_set_row(s))
	return sec


## The colour of a line kind: its school's for an attack line, else by what it protects.
static func _line_color(k: String) -> Color:
	if k.begins_with("atk_"):
		var school = k.trim_prefix("atk_")
		return RpgUi.color(school) if RpgDefs.SCHOOLS.has(school) else Pal.ACCENT
	match k:
		"hp", "heal_pct":
			return Pal.DANGER.lightened(0.25)
		"armor", "res":
			return RpgUi.color("legs")
		"spd":
			return RpgUi.color("speed")
		"crit":
			return RpgUi.color("grip")
	return RpgUi.color("realm")


## One slot of the doll: the item with its plus, or a dim plus sign.
static func _slot_tile(slot: String, rpg: Dictionary, b: Dictionary, have: Dictionary) -> Control:
	var id = _worn_id(b, have, slot)
	var g = RpgGear.of(id) if id != "" else null
	var rc = Pal.rarity(str(g.rarity)) if g != null else Pal.LINE
	var card = Kit.card(1, open_slot.bind(slot), 3)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pic: Control
	var plus = 0
	if g != null:
		card.tint(Pal.PANEL2.lightened(0.06), rc)
		pic = PixFit.make(Art.item_icon_texture(id), TILE_BOX, 3)
		plus = _plus_of(rpg, id)
		if plus > 0:
			var pl = PixelFont.rect("+%d" % plus, 1, Pal.ACCENT)
			pl.position = Vector2(TILE_BOX.x - pl.custom_minimum_size.x, 0)
			pl.size = pl.custom_minimum_size
			pic.add_child(pl)
	else:
		card.accent(rc)
		pic = PixFit.make(Icons.tex("plus", Pal.LINE), TILE_BOX, 1)
		card.modulate = Color(1, 1, 1, 0.8)
	card.add(pic)
	var cap = PixelFont.rect(str(SHORT.get(slot, slot.to_upper())), 1, Pal.TEXT if g != null else Pal.LINE, false)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(cap)
	Kit.passthrough(card.box)
	card.set_meta("gear_slot", slot)
	card.set_meta("gear_holds", id)
	card.set_meta("gear_plus", plus)
	card.set_meta("anchor_id", "gear_slot:" + slot)
	return card


static func _pet_tile(b: Dictionary, have: Dictionary) -> Control:
	var id = _pet_id(b, have)
	var p = Pets.by_id(id) if id != "" else null
	var card = Kit.card(1, open_pets, 3)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pic: Control
	if p != null:
		card.tint(Pal.PANEL2.lightened(0.06), Pal.rarity(str(p.get("rarity", "common"))))
		pic = PixFit.make(Art.pet_texture(id, 0, false), TILE_BOX, 2)
	else:
		card.accent(Pal.LINE)
		pic = PixFit.make(Icons.tex("plus", Pal.LINE), TILE_BOX, 1)
		card.modulate = Color(1, 1, 1, 0.8)
	card.add(pic)
	var cap = PixelFont.rect("PET", 1, Pal.TEXT if p != null else Pal.LINE, false)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add(cap)
	Kit.passthrough(card.box)
	card.set_meta("gear_slot", "pet")
	card.set_meta("gear_holds", id)
	card.set_meta("anchor_id", "gear_slot:pet")
	return card


static func _set_row(s: Dictionary) -> Control:
	var info = RpgGear.SETS.get(str(s.id), {})
	var on = bool(s.get("two", false))
	var r = Kit.row(Callable(), Pal.GOOD if on else Pal.LINE, Pal.GOOD if on else null, 8, 4, 0.1)
	r.set_meta("gear_set", str(s.id))
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Kit.clip("%s set" % str(s.get("name", "")), 14, null, true)))
	head.add_child(Kit.pips(int(s.get("count", 0)), 4, Pal.GOOD, 10))
	head.add_child(Kit.vcenter(Kit.label("%d worn" % int(s.get("count", 0)), 12, Pal.MUTED, true)))
	r.add(head)
	for pair in [["two", "2 pieces"], ["four", "4 pieces"]]:
		var bonus = info.get(pair[0], {})
		var met = bool(s.get(pair[0], false))
		var line = Kit.hbox(8)
		line.add_child(Kit.tick_box(met, 18))
		line.add_child(Kit.vcenter(Kit.para("%s: %s" % [pair[1], str(bonus.get("text", ""))], 12, Pal.TEXT if met else Pal.MUTED)))
		r.add(line)
	return r


# ---------------------------------------------------------------------------
# The slot sheet
# ---------------------------------------------------------------------------

static func open_slot(slot: String) -> void:
	var sh = Kit.sheet("%s gear" % str(TT.SLOT_NAMES.get(slot, slot.capitalize())))
	_fill_slot(sh, slot)
	sh.open()


static func _rarity_rank(id: String) -> int:
	var g = RpgGear.of(id)
	return RpgDefs.RARITIES.find(str(g.rarity)) if g != null else -1


static func _fill_slot(sh, slot: String) -> void:
	Kit.clear(sh.box)
	sh.box.set_meta("slot_sheet", slot)
	var rpg = RpgUi.save()
	var have = RpgUi.owned()
	var b = RpgSave.build_of(rpg)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Kit.muted_para("This slot is for: %s." % RpgGear.slot_main(slot).to_lower(), 12)))
	head.add_child(RpgUi.ore_pill(_ore(rpg)))
	sh.box.add_child(head)
	var ids = []
	for id in have.items:
		var g = RpgGear.of(str(id))
		if g != null and str(g.slot) == slot:
			ids.append(str(id))
	# A fixed order (the best first, then by name): a card never moves when its key is tapped.
	var best_first = func(a, c):
		var ra = RealmGear._rarity_rank(a)
		var rc = RealmGear._rarity_rank(c)
		if ra != rc:
			return ra > rc
		return RealmGear.item_name(a) < RealmGear.item_name(c)
	ids.sort_custom(best_first)
	if ids.is_empty():
		sh.box.add_child(RpgUi.page_note("slot_none", "You own no %s gear yet. Gear comes from the main game: trophies, loot and the Armory's shop." % str(TT.SLOT_NAMES.get(slot, slot)).to_lower()))
	for id in ids:
		sh.box.add_child(_item_card(sh, slot, id, rpg, b, have))


## An owned item in full, with its keys.
static func _item_card(sh, slot: String, id: String, rpg: Dictionary, b: Dictionary, have: Dictionary) -> Control:
	var plus = _plus_of(rpg, id)
	var g = RpgGear.of(id, plus)
	var rc = Pal.rarity(str(g.rarity))
	var worn = _worn_id(b, have, slot) == id
	var c = Kit.row(Callable(), rc, rc if worn else null, 8, 4, 0.2)
	c.set_meta("gear_item", id)
	c.set_meta("gear_worn", worn)
	c.set_meta("gear_plus", plus)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(PixFit.make(Art.item_icon_texture(id), Vector2(40, 34), 2)))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip(item_name(id), 15, null, true))
	var tags = Kit.hbox(4)
	tags.add_child(Kit.rarity_badge(str(g.rarity)))
	if plus > 0:
		tags.add_child(Kit.tag("+%d" % plus, Pal.ACCENT, true, 10))
	if worn:
		tags.add_child(Kit.tag("WORN", Pal.GOOD, true, 10))
	v.add_child(tags)
	head.add_child(v)
	c.add(head)
	for line in g.lines:
		var words = RpgGear.line_words(line)
		if words != "":
			c.add(Kit.para(words, 13, Pal.TEXT, true))
	var unique = g.get("unique")
	if unique is Dictionary:
		c.add(Kit.para("%s: %s" % [str(unique.get("name", "")), str(unique.get("text", ""))], 12, rc))
	var set_id = str(g["set"])
	if set_id != "" and RpgGear.SETS.has(set_id):
		var info = RpgGear.SETS[set_id]
		c.add(Kit.muted_para("%s set · 2 pieces: %s 4 pieces: %s" % [str(info.get("name", "")), str(info.get("two", {}).get("text", "")), str(info.get("four", {}).get("text", ""))], 12))
	var rune = _rune_of(rpg, rpg.get("socket", {}).get(id))
	var rune_line = Kit.hbox(6)
	rune_line.add_child(Kit.vcenter(Icons.rect("rune", 16)))
	if rune != null:
		rune_line.add_child(Kit.vcenter(Kit.clip("Rune: %s" % RpgGear.rune_words(rune), 12, Pal.rarity(str(rune.get("rarity", "common"))), true)))
	else:
		rune_line.add_child(Kit.vcenter(Kit.clip("No rune in it", 12, Pal.MUTED)))
	c.add(rune_line)

	var ore = _ore(rpg)
	var cost = RpgGear.plus_cost(id, plus)
	var top = plus >= RpgDefs.PLUS_MAX
	if not top:
		var nxt = RpgGear.of(id, plus + 1)
		var grown = []
		for line in nxt.lines:
			var words = RpgGear.line_words(line)
			if words != "":
				grown.append(words)
		var grow = Kit.muted_para("At +%d: %s" % [plus + 1, " · ".join(grown)], 12)
		grow.set_meta("gear_next", plus + 1)
		c.add(grow)
	var keys = Kit.hbox(6)
	var wear = RpgUi.page_key("Take off" if worn else "Wear", "ghost" if worn else "good", _wear.bind(sh, slot, "" if worn else id), "gear_wear:" + id)
	wear.set_meta("gear_wear", id)
	keys.add_child(wear)
	var up = RpgUi.page_key("At +%d" % RpgDefs.PLUS_MAX if top else "Upgrade to +%d · %s ore" % [plus + 1, Xp.fmt_int(cost)], "primary", Callable(), "gear_upgrade:" + id)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.clip_text = true
	up.set_meta("gear_upgrade", id)
	up.set_meta("gear_cost", cost)
	up.disabled = top or ore < cost
	up.pressed.connect(_upgrade.bind(sh, slot, id, up))
	keys.add_child(up)
	var rk = RpgUi.page_key("Rune", "ghost", open_runes.bind(id, sh, slot), "gear_rune:" + id)
	rk.set_meta("gear_rune", id)
	keys.add_child(rk)
	c.add(keys)
	if up.disabled:
		var why = "+%d is as far as it goes." % RpgDefs.PLUS_MAX if top else "Needs %s ore, you have %s. Fights in the Ironwild pay ore." % [Xp.fmt_int(cost), Xp.fmt_int(ore)]
		var l = Kit.para(why, 12, Pal.MUTED if top else Pal.ACCENT2)
		l.set_meta("gear_upgrade_why", id)
		c.add(l)
	return c


static func _wear(sh, slot: String, id: String) -> void:
	if RpgUi.apply(RpgSave.equip_gear(RpgUi.save(), slot, id, RpgUi.owned().items)) and is_instance_valid(sh):
		RpgSfx.play("equip")
		just_wore = true
		_fill_slot(sh, slot)


static func _upgrade(sh, slot: String, id: String, at) -> void:
	var res = RpgSave.upgrade(RpgUi.save(), id, "", RpgUi.owned().items)
	if bool(res.get("ok", false)) and at is Control and is_instance_valid(at):
		Kit.burst(at, Pal.ACCENT, 18)
		Kit.pop(at, 1.15, 0.26)
		Kit.floater(at, "+%d" % (_plus_of(RpgUi.save(), id) + 1), Pal.ACCENT)
		RpgSfx.buzz(2)
	if RpgUi.apply(res) and is_instance_valid(sh):
		RpgSfx.play("upgrade")
		_fill_slot(sh, slot)


# ---------------------------------------------------------------------------
# The rune sheet of one item
# ---------------------------------------------------------------------------

static func open_runes(item_id: String, parent, slot: String) -> void:
	var rpg = RpgUi.save()
	var sh = Kit.sheet("A rune for %s" % item_name(item_id))
	sh.box.set_meta("rune_sheet", item_id)
	var in_it = str(rpg.get("socket", {}).get(item_id, ""))
	var done = func(rune_id: String):
		if RpgUi.apply(RpgSave.socket(RpgUi.save(), item_id, rune_id)):
			RpgSfx.play("socket")
			sh.close()
			if parent != null and is_instance_valid(parent):
				RealmGear._fill_slot(parent, slot)
	var runes = rpg.get("runes", [])
	if runes.is_empty():
		sh.box.add_child(RpgUi.page_note("runes_none_pick", "No runes yet. Bosses, elites and gold chests drop them: a rune adds one more line to the gear it sits in."))
	else:
		sh.box.add_child(Kit.muted_para("One rune a piece of gear. A rune can be moved freely: it leaves the gear it was in.", 12))
	for r in runes:
		var rid = str(r.get("id", ""))
		var rc = Pal.rarity(str(r.get("rarity", "common")))
		var row = Kit.row(Callable(), rc, rc if rid == in_it else null, 8, 4)
		var h = Kit.hbox(8)
		h.add_child(Kit.vcenter(Icons.rect("rune", 16)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.clip(RpgGear.rune_words(r), 14, rc, true))
		var at = _socket_of(rpg, rid)
		v.add_child(Kit.clip("In this one" if rid == in_it else ("In %s" % item_name(at) if at != "" else "Free"), 12, Pal.MUTED))
		h.add_child(v)
		var key = RpgUi.page_key("In it" if rid == in_it else "Socket", "primary", done.bind(rid), "rune_socket:" + rid)
		key.set_meta("rune_socket", rid)
		key.disabled = rid == in_it
		h.add_child(Kit.vcenter(key))
		row.add(h)
		sh.box.add_child(row)
	if in_it != "":
		var out = RpgUi.page_key("Take the rune out", "ghost", done.bind(""), "rune_remove", "md")
		out.set_meta("rune_remove", item_id)
		sh.box.add_child(out)
	sh.open()


# ---------------------------------------------------------------------------
# RELICS
# ---------------------------------------------------------------------------

static func _found_relics(rpg: Dictionary) -> Array:
	var found = rpg.get("relics", {})
	return RpgRelics.all().filter(func(r): return bool(found.get(str(r.id), false)))


static func _relic_card(r: Dictionary, tap: Callable, tag: String = "") -> Card:
	var rc = Pal.rarity(str(r.get("rarity", "rare")))
	var c = Kit.row(tap, rc, rc, 8, 4)
	var head = Kit.hbox(8)
	var icon_name = str(r.get("icon", "relic"))
	head.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "relic", 32)))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip(str(r.get("name", "")), 15, null, true))
	var tags = Kit.hbox(4)
	tags.add_child(Kit.rarity_badge(str(r.get("rarity", "rare"))))
	if tag != "":
		tags.add_child(Kit.tag(tag, Pal.GOOD, true, 10))
	v.add_child(tags)
	head.add_child(v)
	c.add(head)
	c.add(Kit.muted_para(str(r.get("text", "")), 12))
	Kit.passthrough(c.box)
	return c


## An empty slot that opens a picker: a plus, what it is, what a tap does.
static func _empty_slot(tap: Callable, title: String, sub: String) -> Card:
	var c = Kit.row(tap, Pal.LINE, null, 8, 2)
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("plus", 16)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.clip(title, 14, null, true))
	v.add_child(Kit.clip(sub, 12, Pal.MUTED))
	h.add_child(v)
	c.add(h)
	Kit.passthrough(c.box)
	return c


static func _relics(rpg: Dictionary, level: int) -> Control:
	var b = RpgSave.build_of(rpg)
	var col = Pal.rarity("epic")
	var found = _found_relics(rpg)
	var sec = Kit.section("gear_relics", "RELICS", "relic", col, Kit.label("%d found" % found.size(), 12, Pal.TEXT, true), Callable(), 6, 10)
	if found.is_empty():
		sec.add(RpgUi.page_note("relics_none", "No relics yet. Elites, bosses and star chests in the Ironwild drop them: each one changes how a build plays."))
	var open_n = RpgDefs.relic_slots(level)
	var held = b.get("relics", [])
	for i in range(RpgSave.RELIC_SLOTS):
		var c
		var id = ""
		if i >= open_n:
			c = RpgUi.lock_row("Relic slot %d · opens at fighter level %d" % [i + 1, int(RpgDefs.RELIC_SLOTS_AT[i])])
		else:
			id = str(held[i]) if i < held.size() else ""
			var r = RpgRelics.by_id(id) if (id != "" and bool(rpg.get("relics", {}).get(id, false))) else null
			if r != null:
				c = _relic_card(r, open_relics.bind(i))
			else:
				id = ""
				c = _empty_slot(open_relics.bind(i), "Relic slot %d is empty" % (i + 1), "Tap to pick a relic." if not found.is_empty() else "Nothing to put here yet.")
			c.set_meta("anchor_id", "relic_slot:%d" % i)
		c.set_meta("relic_slot", i)
		c.set_meta("slot_holds", id)
		sec.add(c)
	return sec


static func open_relics(slot: int) -> void:
	var rpg = RpgUi.save()
	var b = RpgSave.build_of(rpg)
	var held = b.get("relics", [])
	var here = str(held[slot]) if slot < held.size() else ""
	var sh = Kit.sheet("Relic slot %d" % (slot + 1))
	sh.box.set_meta("relic_sheet", slot)
	var done = func(id: String):
		if RpgUi.apply(RpgSave.equip_relic(RpgUi.save(), slot, id)):
			RpgSfx.play("equip")
			sh.close()
	var found = _found_relics(rpg)
	if found.is_empty():
		sh.box.add_child(RpgUi.page_note("relics_none_pick", "No relics found yet. Elites, bosses and star chests in the Ironwild drop them."))
	for r in found:
		var id = str(r.id)
		var tag = ""
		if id == here:
			tag = "HERE"
		elif held.has(id):
			tag = "SLOT %d" % (held.find(id) + 1)
		var c = _relic_card(r, done.bind(id), tag)
		c.set_meta("pick_relic", id)
		c.set_meta("anchor_id", "pick_relic:" + id)
		sh.box.add_child(c)
	var empty = RpgUi.page_key("Empty this slot", "ghost", done.bind(""), "pick_relic_empty", "md")
	empty.set_meta("pick_relic", "")
	empty.disabled = here == ""
	sh.box.add_child(empty)
	sh.open()


# ---------------------------------------------------------------------------
# COMPANION
# ---------------------------------------------------------------------------

## The build's companion: an owned pet the Realm has a kit for, or "".
static func _pet_id(b: Dictionary, have: Dictionary) -> String:
	var id = str(b.get("pet", ""))
	return id if (id != "" and have.pets.has(id) and RpgPets.by_id(id) != null) else ""


static func _owned_pets(have: Dictionary) -> Array:
	return Pets.all().filter(func(p): return have.pets.has(p.id) and RpgPets.by_id(str(p.id)) != null)


static func _companion(rpg: Dictionary, have: Dictionary) -> Control:
	var b = RpgSave.build_of(rpg)
	var col = Pal.tab("armory")
	var mine = _owned_pets(have)
	var sec = Kit.section("gear_pet", "COMPANION", "paw", col, Kit.label("%d yours" % mine.size(), 12, Pal.TEXT, true), Callable(), 8, 10)
	var id = _pet_id(b, have)
	if id != "":
		sec.add(_pet_card(id))
	elif mine.is_empty():
		sec.add(RpgUi.page_note("pet_none", "No companion yet. They join you in the main game (log sessions, earn trophies); then one fights beside you here."))
	else:
		sec.add(RpgUi.page_note("pet_unpicked", "No companion in this build. Pick one: it acts by itself in a fight and has a command you call."))
	if not mine.is_empty():
		sec.add(Kit.sub_head("YOURS", col))
		sec.add(_pet_tiles(mine, id, Callable()))
	return sec


## The companion in full: what it does by itself, on command, and always.
static func _pet_card(id: String) -> Control:
	var p = Pets.by_id(id)
	var words = RpgPets.words(id)
	var rc = Pal.rarity(str(p.get("rarity", "common")))
	var c = Kit.row(Callable(), rc, rc, 8, 6)
	c.set_meta("pet_card", id)
	var head = Kit.hbox(10)
	var pv = PetView.new()
	pv.setup(id, 56.0, true)
	head.add_child(Kit.vcenter(pv))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.clip(str(p.get("name", id)), 16, null, true))
	v.add_child(Kit.clip(str(p.get("species", "")), 12, Pal.MUTED))
	var tags = Kit.hbox(4)
	tags.add_child(Kit.rarity_badge(str(p.get("rarity", "common"))))
	v.add_child(tags)
	head.add_child(v)
	c.add(head)
	if words is Dictionary:
		for pair in [["By itself", "auto"], ["On command", "command"], ["Always", "passive"]]:
			var text = str(words.get(pair[1], ""))
			if text == "":
				continue
			var line = Kit.vbox(0)
			line.set_meta("pet_words", pair[1])
			line.add_child(Kit.label(str(pair[0]).to_upper(), 10, rc, true))
			line.add_child(Kit.para(text, 13, Pal.TEXT))
			c.add(line)
	return c


## The owned companions as tiles; `after` runs once one is picked (a sheet closes).
static func _pet_tiles(mine: Array, picked: String, after: Callable) -> Control:
	var f = Kit.flow(6)
	for p in mine:
		var id = str(p.id)
		var on = id == picked
		var t = Kit.card(2, _pick_pet.bind(id, after), 4)
		t.custom_minimum_size = Vector2(84, 0)
		if on:
			t.accent(Pal.ACCENT, true)
		else:
			t.accent(Pal.rarity(str(p.get("rarity", "common"))))
		var pv = PetView.new()
		pv.setup(id, 40.0, false)
		pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		t.add(pv)
		var nm = Kit.clip(str(p.get("name", id)), 11, Pal.ACCENT if on else null, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add(nm)
		Kit.passthrough(t.box)
		t.set_meta("pet_pick", id)
		t.set_meta("pet_on", on)
		t.set_meta("anchor_id", "pet_pick:" + id)
		f.add_child(t)
	if picked != "":
		var none = RpgUi.page_key("No companion", "ghost", _pick_pet.bind("", after), "pet_pick_none")
		none.set_meta("pet_pick", "")
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(none)
	return f


static func _pick_pet(id: String, after: Callable) -> void:
	if RpgUi.apply(RpgSave.equip_pet(RpgUi.save(), id, RpgUi.owned().pets)) and after.is_valid():
		RpgSfx.play("pet")
		after.call()


## The doll's PET tile: the same picker in a sheet.
static func open_pets() -> void:
	var have = RpgUi.owned()
	var b = RpgSave.build_of(RpgUi.save())
	var sh = Kit.sheet("Companion")
	sh.box.set_meta("pet_sheet", true)
	var mine = _owned_pets(have)
	if mine.is_empty():
		sh.box.add_child(RpgUi.page_note("pet_none_pick", "No companion yet. They join you in the main game (log sessions, earn trophies)."))
	else:
		sh.box.add_child(Kit.muted_para("A companion acts by itself in a fight and has a command you call.", 12))
		sh.box.add_child(_pet_tiles(mine, _pet_id(b, have), sh.close))
	sh.open()


# ---------------------------------------------------------------------------
# BELT
# ---------------------------------------------------------------------------

static func _stock(rpg: Dictionary, id: String) -> int:
	return int(rpg.get("items", {}).get(id, 0))


static func _item_row(it: Dictionary, stock: int, tap: Callable, tag: String = "") -> Card:
	var col = RpgUi.color("flow")
	var c = Kit.row(tap, col if stock > 0 else Pal.LINE, col if stock > 0 else null, 8, 2)
	var h = Kit.hbox(8)
	var icon_name = str(it.get("icon", "belt"))
	h.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "belt", 32)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top = Kit.hbox(6)
	top.add_child(Kit.vcenter(Kit.clip(str(it.get("name", "")), 14, null, true)))
	if tag != "":
		top.add_child(Kit.tag(tag, Pal.GOOD, true, 10))
	var count = Kit.tag("x%d" % stock if stock > 0 else "none left", Pal.GOOD if stock > 0 else Pal.ACCENT2, true, 10)
	count.set_meta("item_stock", stock)
	top.add_child(count)
	v.add_child(top)
	v.add_child(Kit.muted_para(RpgItems.words(it), 12))
	h.add_child(v)
	c.add(h)
	Kit.passthrough(c.box)
	return c


static func _belt(rpg: Dictionary, level: int) -> Control:
	var b = RpgSave.build_of(rpg)
	var col = RpgUi.color("flow")
	var sec = Kit.section("gear_belt", "BELT", "belt", col, null, Callable(), 6, 10)
	sec.add(Kit.muted_para("Items to use in a fight in place of a move, up to %d times each a battle. What you use is only taken when you win." % RpgDefs.BELT_USES, 12))
	var open_n = RpgDefs.belt_slots(level)
	var held = b.get("belt", [])
	var any = false
	for id in rpg.get("items", {}):
		if _stock(rpg, str(id)) > 0:
			any = true
	if not any:
		sec.add(RpgUi.page_note("belt_none", "Nothing to carry yet: the camp shop below sells items for ore."))
	for i in range(RpgSave.BELT_SLOTS):
		var c
		var id = ""
		if i >= open_n:
			c = RpgUi.lock_row("Belt slot %d · opens at fighter level %d" % [i + 1, RpgDefs.BELT_SLOT_3_AT])
		else:
			id = str(held[i]) if i < held.size() else ""
			var it = RpgItems.by_id(id) if id != "" else null
			if it != null:
				c = _item_row(it, _stock(rpg, id), open_belt.bind(i))
			else:
				id = ""
				c = _empty_slot(open_belt.bind(i), "Belt slot %d is empty" % (i + 1), "Tap to pick an item.")
			c.set_meta("anchor_id", "belt_slot:%d" % i)
		c.set_meta("belt_slot", i)
		c.set_meta("slot_holds", id)
		sec.add(c)
	return sec


static func open_belt(slot: int) -> void:
	var rpg = RpgUi.save()
	var b = RpgSave.build_of(rpg)
	var held = b.get("belt", [])
	var here = str(held[slot]) if slot < held.size() else ""
	var sh = Kit.sheet("Belt slot %d" % (slot + 1))
	sh.box.set_meta("belt_sheet", slot)
	var done = func(id: String):
		if RpgUi.apply(RpgSave.set_belt(RpgUi.save(), slot, id)):
			RpgSfx.play("equip")
			sh.close()
	var items = RpgItems.all().duplicate()
	var stocked = items.filter(func(it): return RealmGear._stock(rpg, str(it.id)) > 0)
	var out = items.filter(func(it): return RealmGear._stock(rpg, str(it.id)) <= 0)
	if stocked.is_empty():
		sh.box.add_child(RpgUi.page_note("belt_none_pick", "You carry nothing yet: the camp shop on the Gear page sells these for ore. A slot can still be set for later."))
	for it in stocked + out:
		var id = str(it.id)
		var tag = ""
		if id == here:
			tag = "HERE"
		elif held.has(id):
			tag = "SLOT %d" % (held.find(id) + 1)
		var c = _item_row(it, _stock(rpg, id), done.bind(id), tag)
		c.set_meta("pick_item", id)
		c.set_meta("anchor_id", "pick_item:" + id)
		sh.box.add_child(c)
	var empty = RpgUi.page_key("Empty this slot", "ghost", done.bind(""), "pick_item_empty", "md")
	empty.set_meta("pick_item", "")
	empty.disabled = here == ""
	sh.box.add_child(empty)
	sh.open()


# ---------------------------------------------------------------------------
# RUNES
# ---------------------------------------------------------------------------

static func _runes(rpg: Dictionary, _have: Dictionary) -> Control:
	var col = Pal.rarity("rare")
	var runes = rpg.get("runes", [])
	var sec = Kit.section("gear_runes", "RUNES", "rune", col, Kit.label("%d" % runes.size(), 12, Pal.TEXT, true), Callable(), 6, 10)
	if runes.is_empty():
		sec.add(RpgUi.page_note("runes_none", "No runes yet. Bosses, elites and gold chests drop them: a rune goes into one piece of gear and adds a line to it."))
		return sec
	sec.add(Kit.muted_para("To socket one: tap a slot of the doll, then Rune on a piece of gear.", 12))
	for r in runes:
		var rid = str(r.get("id", ""))
		var rc = Pal.rarity(str(r.get("rarity", "common")))
		var row = Kit.row(Callable(), rc, rc, 8, 4)
		row.set_meta("rune_row", rid)
		var h = Kit.hbox(8)
		h.add_child(Kit.vcenter(Icons.rect("rune", 16)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.clip(RpgGear.rune_words(r), 14, rc, true))
		var at = _socket_of(rpg, rid)
		var where = Kit.clip("In %s" % item_name(at) if at != "" else "Not in any gear", 12, Pal.MUTED)
		where.set_meta("rune_in", at)
		v.add_child(where)
		h.add_child(v)
		var pay = RpgLoot.scrap_ore(r)
		var key = RpgUi.page_key("Scrap for %d ore" % pay, "ghost", _ask_scrap.bind(rid), "rune_scrap:" + rid)
		key.set_meta("rune_scrap", rid)
		h.add_child(Kit.vcenter(key))
		row.add(h)
		sec.add(row)
	return sec


static func _ask_scrap(rune_id: String) -> void:
	var rune = _rune_of(RpgUi.save(), rune_id)
	if rune == null:
		return
	var pay = RpgLoot.scrap_ore(rune)
	var go = func():
		if RpgUi.apply(RpgSave.scrap_rune(RpgUi.save(), rune_id), "+%d ore" % pay):
			RpgSfx.play("ore")
	Kit.confirm("Scrap this rune?", "%s. It is gone for good and pays %d ore." % [RpgGear.rune_words(rune), pay], "Scrap it", go, true)


# ---------------------------------------------------------------------------
# CAMP SHOP
# ---------------------------------------------------------------------------

static func _shop(rpg: Dictionary) -> Control:
	var col = RpgUi.color("realm")
	var ore = _ore(rpg)
	var sec = Kit.section("gear_shop", "CAMP SHOP", "bag", col, RpgUi.ore_pill(ore), Callable(), 6, 10)
	if ore <= 0:
		sec.add(RpgUi.page_note("shop_no_ore", "No ore yet: every fight in the Ironwild pays some."))
	for id in RpgItems.SHOP:
		var it = RpgItems.by_id(str(id))
		if it == null:
			continue
		var price = RpgItems.price(str(id))
		var row = Kit.row(Callable(), col if ore >= price else Pal.LINE, null, 8, 2)
		row.set_meta("shop_item", str(id))
		var h = Kit.hbox(8)
		var icon_name = str(it.get("icon", "belt"))
		h.add_child(Kit.vcenter(Icons.rect(icon_name if Icons.has_icon(icon_name) else "belt", 32)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top = Kit.hbox(6)
		top.add_child(Kit.vcenter(Kit.clip(str(it.get("name", "")), 14, null, true)))
		var have_n = Kit.label("you have %d" % _stock(rpg, str(id)), 11, Pal.MUTED, true)
		have_n.set_meta("item_stock", _stock(rpg, str(id)))
		top.add_child(Kit.vcenter(have_n))
		v.add_child(top)
		v.add_child(Kit.muted_para(RpgItems.words(it), 12))
		h.add_child(v)
		var buy = RpgUi.page_key("Buy · %d" % price, "primary", Callable(), "shop_buy:" + str(id), "sm", "ore")
		buy.set_meta("shop_buy", str(id))
		buy.pressed.connect(_buy.bind(str(id), buy))
		h.add_child(Kit.vcenter(buy))
		row.add(h)
		sec.add(row)
	return sec


static func _buy(id: String, at) -> void:
	var res = RpgSave.buy_item(RpgUi.save(), id, 1)
	if bool(res.get("ok", false)) and at is Control and is_instance_valid(at):
		Kit.floater(at, "+1", Pal.GOOD)
		Kit.pop(at, 1.12, 0.2)
		RpgSfx.play("buy")
	RpgUi.apply(res)
