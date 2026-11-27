class_name RealmMoves
extends RefCounted
## The Moves page of the Realm (RPG_PLAN.md 10.1): the build in use and every
## move there is.
##
##   YOUR BUILD  the three saved builds as a pick-one track with a Rename key;
##               the move slots as cards (the fifth locked until fighter level
##               20), the ultimate, the three passive slots (locked ones say
##               the level). A tap on a slot opens the PICK SHEET: what can go
##               there (not yet equipped first, equipped ones marked), and
##               "Empty this slot".
##   ALL MOVES   school chips (one picked, kept in `school`), then the school's
##               moves in tier order: known ones as full cards (power, cost,
##               cooldown, quick / normal / heavy, what it does), unknown ones
##               dim with what they need. A tap on a known move opens the EQUIP
##               SHEET: the slots to put it in.
##
## Every change goes through RpgSave and RpgUi.apply (which stores it and makes
## the screen draw itself again).
##
## Metas for tests: sections "moves_build", "moves_all"; "build_pick" = index;
## "build_rename"; "move_slot" = index; "ult_slot"; "passive_slot" = index
## (each with "slot_holds" = the id in it, and "realm_locked" on a locked one);
## "school_pick" = school; "move_known" = bool and "move_needs" on the school's
## cards. Sheets: the pick sheet's box "pick_sheet" = "<kind>:<slot>", its rows
## "pick_move" = id ("" = the Empty key); the equip sheet's box "equip_sheet" =
## id, its keys "equip_slot" = index; the rename sheet's "build_name_box" and
## "build_rename_save".

## The school whose moves ALL MOVES shows (kept while the app runs).
static var school = "push"


static func fill(box: VBoxContainer, screen) -> void:
	if not RpgDefs.SCHOOLS.has(school):
		school = "push"
	box.add_child(_build_section())
	box.add_child(_all_section(screen))


## The move or passive of an id (null for "" and for one nobody knows).
static func _row_of(kind: String, id: String):
	if id == "":
		return null
	return RpgPassives.by_id(id) if kind == "passive" else RpgMoves.by_id(id)


static func _known(kind: String, rpg: Dictionary) -> Array:
	match kind:
		"ult":
			return RpgSkills.known_ults(rpg)
		"passive":
			return RpgSkills.known_passives(rpg)
	return RpgSkills.known_moves(rpg)


## What the build holds of a kind, slot by slot.
static func _held(kind: String, b: Dictionary) -> Array:
	match kind:
		"ult":
			return [str(b.get("ult", ""))]
		"passive":
			return b.get("passives", [])
	return b.get("moves", [])


static func _at(list: Array, i: int) -> String:
	return str(list[i]) if (i >= 0 and i < list.size() and list[i] is String) else ""


## quick / normal / heavy: how long the hero waits after it.
static func rank_word(move: Dictionary) -> String:
	var rank = float(move.get("rank", 1.0))
	if rank < 0.95:
		return "quick"
	if rank > 1.05:
		return "heavy"
	return "normal"


static func tier_word(move: Dictionary) -> String:
	var tier = int(move.get("tier", 0))
	if tier <= 0:
		return "Starter"
	if tier >= RpgMoves.TIER_SCROLL:
		return "Scroll"
	if bool(move.get("ult", false)):
		return "Tier %d" % tier
	return "Tier %d" % tier


## A move's facts under its card: tier, power, rank as a word; `hint` at the end.
static func facts(move: Dictionary, hint: String = "") -> Control:
	var col = RpgUi.color(str(move.get("school", "plain")))
	var h = Kit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.tag(tier_word(move), Pal.PANEL2, false))
	var power = float(move.get("power", 0.0))
	if str(move.get("kind", "attack")) == "attack" and power > 0.0:
		var pw = Kit.tag("Power %s" % TTUtil.num_str(snappedf(power, 0.01)), col)
		pw.set_meta("move_power", power)
		h.add_child(pw)
	else:
		h.add_child(Kit.tag("Support", col))
	h.add_child(Kit.tag(rank_word(move), Pal.PANEL2, false))
	var tail = Kit.clip(hint, 11, Pal.MUTED)
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(Kit.vcenter(tail))
	return h


## A board passive as a card: its school's colour, name, what it does.
static func passive_card(p: Dictionary, tap: Callable = Callable(), tag: String = "", dim: bool = false) -> Card:
	var col = RpgUi.color(str(p.get("board", "plain")))
	var c = Kit.row(tap, col, col, 8, 4)
	c.set_meta("rpg_passive", str(p.get("id", "")))
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("star", 16)))
	head.add_child(Kit.vcenter(Kit.clip(str(p.get("name", "")), 15, Pal.MUTED if dim else null, true)))
	head.add_child(Kit.tag("%s passive" % str(RpgDefs.SCHOOL_NAMES.get(str(p.get("board", "")), "A")), col))
	if tag != "":
		head.add_child(Kit.tag(tag, Pal.GOOD))
	c.add(head)
	c.add(Kit.muted_para(str(p.get("text", "")), 12))
	if dim:
		c.modulate = Color(1, 1, 1, 0.6)
	return c


# ---------------------------------------------------------------------------
# YOUR BUILD
# ---------------------------------------------------------------------------

static func _build_section() -> Control:
	var rpg = RpgUi.save()
	var level = RpgUi.level()
	var b = RpgSave.build_of(rpg)
	var at = clampi(int(rpg.get("build", 0)), 0, 2)
	var col = RpgUi.color("realm")
	var sec = Kit.section("moves_build", "YOUR BUILD", "sword", col, null, Callable(), 8, 10)

	var keys = []
	for i in range(3):
		var k = Kit.choice(str(rpg.builds[i].get("name", RpgSave.BUILD_NAMES[i])), i == at, _pick_build.bind(i), col)
		k.clip_text = true
		k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		k.custom_minimum_size.x = 56
		k.set_meta("build_pick", i)
		k.set_meta("build_on", i == at)
		k.set_meta("anchor_id", "build_pick:%d" % i)
		RpgUi.finger(k)
		keys.append(k)
	var top = Kit.hbox(6)
	top.add_child(Kit.choice_track(keys))
	var ren = RpgUi.page_key("Rename", "ghost", open_rename.bind(at), "build_rename")
	ren.set_meta("build_rename", at)
	top.add_child(Kit.vcenter(ren))
	sec.add(top)
	sec.add(Kit.muted_para("Three builds to switch between: each keeps its own moves, gear, relics, companion and belt.", 12))

	var known = RpgSkills.known_moves(rpg)
	var open_n = RpgDefs.move_slots(level)
	var moves = b.get("moves", [])
	var filled = 0
	for i in range(open_n):
		if _at(moves, i) != "":
			filled += 1
	sec.add(Kit.sub_head("MOVES", col, Kit.label("%d of %d slots filled" % [filled, open_n], 12, Pal.MUTED)))
	for i in range(RpgSave.MOVE_SLOTS):
		if i >= open_n:
			var lock = RpgUi.lock_row("Move slot %d · opens at fighter level %d" % [i + 1, RpgDefs.MOVE_SLOT_5_AT])
			lock.set_meta("move_slot", i)
			sec.add(lock)
		else:
			sec.add(_slot("move", i, _at(moves, i), known))

	sec.add(Kit.sub_head("ULTIMATE", Pal.ACCENT, Kit.label("fills as you fight", 12, Pal.MUTED)))
	sec.add(_slot("ult", 0, str(b.get("ult", "")), RpgSkills.known_ults(rpg)))

	var open_p = RpgDefs.passive_slots(level)
	sec.add(Kit.sub_head("PASSIVES", col, Kit.label("always on", 12, Pal.MUTED)))
	var known_p = RpgSkills.known_passives(rpg)
	for i in range(RpgSave.PASSIVE_SLOTS):
		if i >= open_p:
			var lock = RpgUi.lock_row("Passive slot %d · opens at fighter level %d" % [i + 1, int(RpgDefs.PASSIVE_SLOTS_AT[i])])
			lock.set_meta("passive_slot", i)
			sec.add(lock)
		else:
			sec.add(_slot("passive", i, _at(b.get("passives", []), i), known_p))
	return sec


## One slot of the build: what is in it as a card, or an empty row that says
## what goes there. A tap opens the pick sheet.
static func _slot(kind: String, i: int, id: String, known: Array) -> Control:
	var tap = open_pick.bind(kind, i)
	var row = _row_of(kind, id)
	var c
	if row == null:
		c = Kit.row(tap, Pal.LINE, null, 8, 2)
		var h = Kit.hbox(8)
		h.add_child(Kit.vcenter(Icons.rect("plus", 16)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var what = "move"
		var sub = "Tap to pick a move you know."
		if kind == "ult":
			what = "ultimate"
			sub = "Tap to pick one." if not known.is_empty() else "The fifth tier of a skill board teaches one."
		elif kind == "passive":
			what = "passive"
			sub = "Tap to pick one." if not known.is_empty() else "Skill boards teach passives: tiers 1, 3 and 4."
		var title = Kit.clip("No %s here" % what, 14, null, true)
		title.set_meta("realm_empty", "%s_slot" % kind)
		v.add_child(title)
		v.add_child(Kit.clip(sub, 12, Pal.MUTED))
		h.add_child(v)
		c.add(h)
	elif kind == "passive":
		c = passive_card(row, tap, "", not known.has(id))
	else:
		c = RpgUi.move_card(row, {"tap": tap, "dim": not known.has(id)})
		c.add(facts(row, "Tap to change"))
	if row != null and not known.has(id):
		c.add(Kit.clip("Not learned: it sits out until you learn it again.", 12, Pal.ACCENT2))
	c.set_meta("slot_holds", id if row != null else "")
	match kind:
		"ult":
			c.set_meta("ult_slot", true)
		"passive":
			c.set_meta("passive_slot", i)
		_:
			c.set_meta("move_slot", i)
	c.set_meta("anchor_id", "%s_slot:%d" % [kind, i])
	Kit.passthrough(c.box)
	return c


static func _pick_build(i: int) -> void:
	if i == clampi(int(RpgUi.save().get("build", 0)), 0, 2):
		return
	RpgUi.apply(RpgSave.set_build(RpgUi.save(), i))


## A build's name: a box and Save.
static func open_rename(i: int) -> void:
	var rpg = RpgUi.save()
	var sh = Kit.sheet("Rename the build")
	sh.box.set_meta("rename_sheet", i)
	var box = Kit.input(str(rpg.builds[i].get("name", "")), "Build name")
	box.max_length = 24
	box.set_meta("build_name_box", i)
	sh.box.add_child(Kit.field("Up to 24 letters", box))
	var save = func():
		if RpgUi.apply(RpgSave.rename_build(RpgUi.save(), i, box.text)):
			sh.close()
	box.text_submitted.connect(func(_t): save.call())
	var ok = RpgUi.page_key("Save", "primary", save, "build_rename_save", "lg")
	ok.set_meta("build_rename_save", i)
	sh.box.add_child(ok)
	sh.open()


# ---------------------------------------------------------------------------
# The pick sheet (what goes into a slot)
# ---------------------------------------------------------------------------

static func open_pick(kind: String, slot: int) -> void:
	var rpg = RpgUi.save()
	var b = RpgSave.build_of(rpg)
	var title = "Move slot %d" % (slot + 1)
	if kind == "ult":
		title = "Your ultimate"
	elif kind == "passive":
		title = "Passive slot %d" % (slot + 1)
	var sh = Kit.sheet(title)
	sh.box.set_meta("pick_sheet", "%s:%d" % [kind, slot])
	var known = _known(kind, rpg)
	var held = _held(kind, b)
	var here = _at(held, slot)
	var free = known.filter(func(id): return not held.has(id))
	var used = known.filter(func(id): return held.has(id))
	if known.is_empty():
		var none = "No ultimate learned yet. The fifth tier of a skill board teaches one." if kind == "ult" else "No passive learned yet. Skill boards teach them at tiers 1, 3 and 4."
		sh.box.add_child(RpgUi.page_note("pick_none", none))
	elif free.is_empty() and kind == "move":
		sh.box.add_child(RpgUi.page_note("pick_all_in", "Every move you know is in the build. Picking one moves it here and swaps the two. Learn more on the Skills page."))
	for id in free + used:
		var row = _row_of(kind, str(id))
		if row == null:
			continue
		var tag = ""
		if str(id) == here:
			tag = "HERE"
		elif held.has(id):
			tag = "EQUIPPED" if kind == "ult" else "SLOT %d" % (held.find(id) + 1)
		var cb = _equip.bind(kind, slot, str(id), sh)
		var c
		if kind == "passive":
			c = passive_card(row, cb, tag)
		else:
			c = RpgUi.move_card(row, {"tap": cb, "tag": tag})
			c.add(facts(row))
		c.set_meta("pick_move", str(id))
		c.set_meta("anchor_id", "pick_move:" + str(id))
		Kit.passthrough(c.box)
		sh.box.add_child(c)
	var empty = RpgUi.page_key("Empty this slot", "ghost", _equip.bind(kind, slot, "", sh), "pick_empty", "md")
	empty.set_meta("pick_move", "")
	empty.disabled = here == ""
	sh.box.add_child(empty)
	sh.open()


static func _equip(kind: String, slot: int, id: String, sh) -> void:
	var rpg = RpgUi.save()
	var res
	match kind:
		"ult":
			res = RpgSave.equip_ult(rpg, id)
		"passive":
			res = RpgSave.equip_passive(rpg, slot, id)
		_:
			res = RpgSave.equip_move(rpg, slot, id)
	if RpgUi.apply(res) and sh != null and is_instance_valid(sh):
		RpgSfx.play("equip")
		sh.close()


# ---------------------------------------------------------------------------
# The equip sheet (which slot a move goes into)
# ---------------------------------------------------------------------------

## "Equip": the slots a known move, ultimate or passive can go into.
static func open_equip(id: String) -> void:
	var kind = "move"
	var row = RpgMoves.by_id(id)
	if row == null:
		row = RpgPassives.by_id(id)
		kind = "passive"
	elif bool(row.get("ult", false)):
		kind = "ult"
	if row == null:
		return
	var rpg = RpgUi.save()
	var level = RpgUi.level()
	var b = RpgSave.build_of(rpg)
	var held = _held(kind, b)
	var sh = Kit.sheet("Equip %s" % str(row.get("name", "")))
	sh.box.set_meta("equip_sheet", id)
	if kind == "passive":
		sh.box.add_child(passive_card(row))
	else:
		var card = RpgUi.move_card(row, {})
		card.add(facts(row))
		sh.box.add_child(card)
	if not _known(kind, rpg).has(id):
		sh.box.add_child(RpgUi.page_note("equip_unknown", "You have not learned it yet: the Skills page teaches it."))
		sh.open()
		return
	if kind == "ult":
		var on = str(b.get("ult", "")) == id
		var k = RpgUi.page_key("It is your ultimate" if on else "Make it the ultimate", "primary", _equip.bind("ult", 0, id, sh), "equip_slot:0", "lg")
		k.set_meta("equip_slot", 0)
		k.disabled = on
		sh.box.add_child(k)
		sh.open()
		return
	var open_n = RpgDefs.passive_slots(level) if kind == "passive" else RpgDefs.move_slots(level)
	var total = RpgSave.PASSIVE_SLOTS if kind == "passive" else RpgSave.MOVE_SLOTS
	sh.box.add_child(Kit.sub_head("PUT IT IN", RpgUi.color(str(row.get("board", row.get("school", "plain"))))))
	if open_n == 0:
		sh.box.add_child(RpgUi.page_note("equip_no_slot", "No passive slot is open yet: the first opens at fighter level %d." % int(RpgDefs.PASSIVE_SLOTS_AT[0])))
	for i in range(total):
		if i >= open_n:
			var at_level = int(RpgDefs.PASSIVE_SLOTS_AT[i]) if kind == "passive" else RpgDefs.MOVE_SLOT_5_AT
			sh.box.add_child(RpgUi.lock_row("Slot %d · opens at fighter level %d" % [i + 1, at_level]))
			continue
		var cur = _at(held, i)
		var cur_row = _row_of(kind, cur)
		var words = "empty"
		if cur == id:
			words = "it is here"
		elif cur_row != null:
			words = "swaps with %s" % str(cur_row.get("name", "")) if held.has(id) else "replaces %s" % str(cur_row.get("name", ""))
		var k = RpgUi.page_key("Slot %d · %s" % [i + 1, words], "primary" if cur == "" else "ghost", _equip.bind(kind, i, id, sh), "equip_slot:%d" % i, "md")
		k.clip_text = true
		k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		k.set_meta("equip_slot", i)
		k.disabled = cur == id
		sh.box.add_child(k)
	sh.open()


# ---------------------------------------------------------------------------
# ALL MOVES
# ---------------------------------------------------------------------------

static func _pick_school(id: String, screen) -> void:
	if school == id:
		return
	school = id
	if screen != null:
		screen.rebuild()


static func _all_section(screen) -> Control:
	var rpg = RpgUi.save()
	var b = RpgSave.build_of(rpg)
	var col = RpgUi.color(school)
	var moves = RpgMoves.by_school(school)
	var known = RpgSkills.known_moves(rpg)
	var known_u = RpgSkills.known_ults(rpg)
	var n_known = 0
	for m in moves:
		if known.has(str(m.id)) or known_u.has(str(m.id)):
			n_known += 1
	var sec = Kit.section("moves_all", "ALL MOVES", "scroll", col, Kit.label("%d of %d known" % [n_known, moves.size()], 12, Pal.TEXT, true), Callable(), 8, 10)
	sec.set_meta("school", school)
	var chips = Kit.flow(6)
	for s in RpgDefs.SCHOOLS:
		var ch = Kit.chip(str(RpgDefs.SCHOOL_NAMES.get(s, s)), s == school, _pick_school.bind(s, screen), RpgUi.color(s))
		ch.icon = Icons.tex(RpgUi.school_icon(s))
		ch.add_theme_constant_override("h_separation", 4)
		ch.set_meta("school_pick", s)
		ch.set_meta("school_on", s == school)
		ch.set_meta("anchor_id", "school_pick:" + str(s))
		RpgUi.finger(ch)
		chips.add_child(ch)
	sec.add(chips)
	sec.add(Kit.muted_para("%s moves hit with %s." % [str(RpgDefs.SCHOOL_NAMES.get(school, school)), str(RpgDefs.SCHOOL_FROM.get(school, "your training")).to_lower()], 12))
	var sheet = RpgUi.sheet()
	var level = RpgUi.level()
	var days = RpgUi.days()
	for m in moves:
		var id = str(m.id)
		var ult = bool(m.get("ult", false))
		var is_known = known_u.has(id) if ult else known.has(id)
		var equipped = b.get("moves", []).has(id) or str(b.get("ult", "")) == id
		var c
		if is_known:
			c = RpgUi.move_card(m, {"tap": open_equip.bind(id), "tag": "EQUIPPED" if equipped else ""})
			c.add(facts(m, "Tap to move it" if equipped else "Tap to equip"))
		else:
			c = RpgUi.move_card(m, {"dim": true})
			c.add(facts(m))
			var need = Kit.para(needs(m, rpg, sheet, level, days), 12, Pal.ACCENT2)
			need.set_meta("move_needs", id)
			c.add(need)
		c.set_meta("move_known", is_known)
		c.set_meta("move_equipped", equipped)
		Kit.passthrough(c.box)
		sec.add(c)
	return sec


## What a move that is not known yet needs.
static func needs(move: Dictionary, rpg: Dictionary, sheet: Dictionary, level: int, days: int) -> String:
	if int(move.get("tier", 0)) >= RpgMoves.TIER_SCROLL:
		return "A scroll: found in the Ironwild"
	var node = RpgSkills.node_of_ref(str(move.get("id", "")))
	if node == null:
		return "Not taught anywhere yet"
	var can = RpgSkills.can_learn(rpg, str(node.id), sheet, level, days)
	if bool(can.get("ok", false)):
		return "Ready to learn on the Skills page: %d skill point%s" % [int(node.cost), "" if int(node.cost) == 1 else "s"]
	return "%s (the Skills page teaches it)" % str(can.get("why", ""))
