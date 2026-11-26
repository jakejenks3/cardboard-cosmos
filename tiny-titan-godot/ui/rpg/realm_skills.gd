class_name RealmSkills
extends RefCounted
## The Skills page of the Realm (RPG_PLAN.md 6 and 10.1): eight boards, one a
## school, of moves, passives and an ultimate to learn with skill points.
##
##   SKILL POINTS  the points left, big; where the earned ones came from; "Reset
##                 all (free)" (asks once). After a skill is learned: a notice
##                 with "Equip it now".
##   <SCHOOL> BOARD  board chips (one picked, kept in `board`; the first time: the
##                 board of the hero's highest stat), what feeds the board, then
##                 its five tiers top to bottom: a band saying what the tier
##                 asks (green when met, amber with what is missing) and its
##                 nodes as tiles of one size in three states:
##                   learned  filled in the board's colour, a tick
##                   can      a gold edge and a "Learn · N" key
##                   blocked  dim, the reason in a few words
##                 A tap on a node opens its sheet: the move or passive in full,
##                 each requirement ticked or crossed, and "Learn for N points"
##                 or why not.
##
## Metas for tests: sections "skills_head" ("skills_left" on the big number,
## "skills_reset" on the key), "skills_board" ("board" = the board shown);
## "board_pick" = board on a chip; "tier_band" = tier with "tier_met"; "node" =
## node id with "node_state" = learned | can | blocked; "node_learn" = node id
## on a Learn key (a tile's, and the sheet's); "node_equip" = node id on "Equip
## it now"; the node sheet's box "node_sheet" = node id, its requirement rows
## "node_req" = bool, the reason "node_why".

## The board in view ("" = not picked yet: the hero's best).
static var board = ""
## The node learned last, while its "Equip it now" notice is up.
static var fresh = ""

## A node tile: its least height (the head, two lines of name, the foot) and the
## height of its foot (a Learn key, "Learned", or the reason), so every tile of
## every state is one size.
const TILE_H = 116
const TILE_H_FINGERS = 128
const FOOT_H = 36
const FOOT_H_FINGERS = 46


static func fill(box: VBoxContainer, screen) -> void:
	var rpg = RpgUi.save()
	var sheet = RpgUi.sheet()
	if not RpgDefs.SCHOOLS.has(board):
		board = best_board(sheet)
	box.add_child(_head(rpg))
	box.add_child(_board(rpg, sheet, screen))


static func _stat_v(sheet: Dictionary, stat: String) -> int:
	var st = sheet.get("stats", {}).get(stat)
	return int(st.get("v", 0)) if st is Dictionary else 0


## The board of the hero's highest stat (the first of equals).
static func best_board(sheet: Dictionary) -> String:
	var best = str(RpgDefs.SCHOOLS[0])
	var top = -1.0
	for s in RpgDefs.SCHOOLS:
		var st = sheet.get("stats", {}).get(str(RpgDefs.BOARD_STAT.get(s, "")))
		var raw = float(st.get("raw", 0.0)) if st is Dictionary else 0.0
		if raw > top + 0.000001:
			top = raw
			best = str(s)
	return best


static func _plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]


## The move or the passive a node teaches.
static func _ref_row(node: Dictionary):
	if str(node.kind) == "passive":
		return RpgPassives.by_id(str(node.ref))
	return RpgMoves.by_id(str(node.ref))


static func _ref_name(node: Dictionary) -> String:
	var row = _ref_row(node)
	return str(row.get("name", node.ref)) if row is Dictionary else str(node.ref)


# ---------------------------------------------------------------------------
# SKILL POINTS
# ---------------------------------------------------------------------------

static func _head(rpg: Dictionary) -> Control:
	var pts = RpgUi.points()
	var from = pts.get("from", {})
	var left = int(pts.get("left", 0))
	var col = RpgUi.color("realm")
	var sec = Kit.section("skills_head", "SKILL POINTS", "sp", col, null, Callable(), 8, 10)
	var h = Kit.hbox(10)
	var big = Kit.hbox(4)
	big.add_child(Kit.vcenter(Icons.rect("sp", 32)))
	var num = Kit.label(str(maxi(0, left)), 32, Pal.ACCENT, true)
	num.set_meta("skills_left", left)
	big.add_child(Kit.vcenter(num))
	h.add_child(Kit.vcenter(big))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label("to spend" if left != 1 else "point to spend", 14, null, true))
	var earned = Kit.muted_para("Earned %d: %d to start, %d from fighter levels, %d from bosses, %d from stars, %d from training days." % [
		int(pts.get("earned", 0)), int(from.get("start", 0)), int(from.get("level", 0)), int(from.get("bosses", 0)), int(from.get("stars", 0)), int(from.get("days", 0))], 12)
	earned.set_meta("skills_earned", int(pts.get("earned", 0)))
	v.add_child(earned)
	h.add_child(v)
	sec.add(h)
	var foot = Kit.hbox(8)
	var spent = int(pts.get("spent", 0))
	foot.add_child(Kit.vcenter(Kit.clip("%s spent" % _plural(spent, "point") if spent > 0 else "Nothing learned yet: pick a skill below.", 12, Pal.MUTED)))
	var reset = RpgUi.page_key("Reset all (free)", "ghost", _ask_reset, "skills_reset")
	reset.set_meta("skills_reset", true)
	reset.disabled = spent == 0
	foot.add_child(reset)
	sec.add(foot)
	if fresh != "" and RpgSkills.has_node(rpg, fresh):
		var node = RpgSkills.by_id(fresh)
		if node != null:
			var key = RpgUi.page_key("Equip it now", "primary", _equip_fresh.bind(str(node.ref)), "node_equip")
			key.set_meta("node_equip", fresh)
			var note = Kit.notice("check", "Learned %s" % _ref_name(node), "Put it in your build to use it.", Pal.GOOD, key)
			note.set_meta("skills_fresh", fresh)
			sec.add(note)
	return sec


static func _equip_fresh(ref: String) -> void:
	fresh = ""
	RealmMoves.open_equip(ref)


static func _ask_reset() -> void:
	var go = func():
		RealmSkills.fresh = ""
		RpgUi.apply(RpgSave.reset_nodes(RpgUi.save()), "Every skill point is back")
	Kit.confirm("Reset every skill?", "Every point comes back. It is free, any time. Your builds stay as they are: a move you no longer know sits out until you learn it again.",
		"Reset all", go, false)


# ---------------------------------------------------------------------------
# The board
# ---------------------------------------------------------------------------

static func _pick_board(id: String, screen) -> void:
	if board == id:
		return
	board = id
	fresh = ""
	if screen != null:
		screen.rebuild()


static func _board(rpg: Dictionary, sheet: Dictionary, screen) -> Control:
	var level = RpgUi.level()
	var days = RpgUi.days()
	var col = RpgUi.color(board)
	var nodes = RpgSkills.nodes_of(board)
	var owned = nodes.filter(func(n): return RpgSkills.has_node(rpg, str(n.id))).size()
	var sec = Kit.section("skills_board", "%s BOARD" % str(RpgDefs.SCHOOL_NAMES.get(board, board)).to_upper(), RpgUi.school_icon(board), col,
		Kit.label("%d of %d learned" % [owned, nodes.size()], 12, Pal.TEXT, true), Callable(), 8, 10)
	sec.set_meta("board", board)
	var chips = Kit.flow(6)
	for s in RpgDefs.SCHOOLS:
		var ch = Kit.chip(str(RpgDefs.SCHOOL_NAMES.get(s, s)), s == board, _pick_board.bind(s, screen), RpgUi.color(s))
		ch.icon = Icons.tex(RpgUi.school_icon(s))
		ch.add_theme_constant_override("h_separation", 4)
		ch.set_meta("board_pick", s)
		ch.set_meta("board_on", s == board)
		ch.set_meta("anchor_id", "board_pick:" + str(s))
		RpgUi.finger(ch)
		chips.add_child(ch)
	sec.add(chips)
	var stat = str(RpgDefs.BOARD_STAT.get(board, ""))
	var feeds = Kit.hbox(8)
	var fed = Kit.muted_para("Fed by: %s." % str(RpgDefs.SCHOOL_FROM.get(board, "your training")).to_lower(), 12)
	fed.set_meta("board_fed", board)
	feeds.add_child(Kit.vcenter(fed))
	feeds.add_child(RpgUi.stat_chip(stat, _stat_v(sheet, stat)))
	sec.add(feeds)
	for tier in range(1, 6):
		var of_tier = nodes.filter(func(n): return int(n.tier) == tier)
		if of_tier.is_empty():
			continue
		of_tier.sort_custom(func(a, b): return int(a.get("col", 0)) < int(b.get("col", 0)))
		sec.add(_band(tier, of_tier, sheet, level, col))
		var row = Kit.hbox(6)
		for n in of_tier:
			row.add_child(_node_tile(n, rpg, sheet, level, days, col))
		sec.add(row)
	return sec


## A tier's band: its number and what it asks, each part green when met and
## amber with what is missing when not.
static func _band(tier: int, nodes: Array, sheet: Dictionary, level: int, col: Color) -> Control:
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb = Kit.sbox(Pal.with_alpha(col, 0.2), 3, null, 0, 8, 4)
	sb.border_width_left = 4
	sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)
	var f = Kit.flow(8)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(Kit.label("TIER %d" % tier, 12, Pal.TEXT, true))
	var need = int(RpgDefs.REQ[tier])
	var met = true
	var stats = []
	for n in nodes:
		if not stats.has(str(n.stat)):
			stats.append(str(n.stat))
	for stat in stats:
		var have = _stat_v(sheet, stat)
		var ok = have >= need
		met = met and ok
		var words = "needs %s %d · you have %d" % [str(RpgDefs.STAT_NAMES.get(stat, stat.capitalize())), need, have]
		if not ok:
			words += " · %d short" % (need - have)
		var l = Kit.label(words, 11, Pal.GOOD if ok else Pal.ACCENT2, true)
		l.set_meta("tier_need", ok)
		f.add_child(l)
	var need_level = int(RpgDefs.NODE_LEVEL[tier])
	if need_level > 1:
		var ok = level >= need_level
		met = met and ok
		var l = Kit.label("fighter level %d" % need_level + ("" if ok else " · you are %d" % level), 11, Pal.GOOD if ok else Pal.ACCENT2, true)
		l.set_meta("tier_need", ok)
		f.add_child(l)
	p.add_child(f)
	p.set_meta("tier_band", tier)
	p.set_meta("tier_met", met)
	return p


## A label of two lines at most, as high as two lines whatever it says: tiles
## stay one size.
static func _two_lines(text: String, size: int, color, bold: bool) -> Label:
	var l = Kit.para(text, size, color, bold)
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(40, 2 * ceili(float(size) * 1.5) + 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Why a node cannot be learned, in a few words.
static func short_why(node: Dictionary, why: String) -> String:
	var tier = int(node.tier)
	if why.begins_with("Learn a tier"):
		return "Tier %d skill first" % (tier - 1)
	if why.begins_with("Not enough"):
		return "Needs %s" % _plural(int(node.cost), "point")
	return why


static func node_state(rpg: Dictionary, node: Dictionary, can: Dictionary) -> String:
	if RpgSkills.has_node(rpg, str(node.id)):
		return "learned"
	return "can" if bool(can.get("ok", false)) else "blocked"


static func _node_tile(node: Dictionary, rpg: Dictionary, sheet: Dictionary, level: int, days: int, col: Color) -> Control:
	var id = str(node.id)
	var kind = str(node.kind)
	var can = RpgSkills.can_learn(rpg, id, sheet, level, days)
	var state = node_state(rpg, node, can)
	var gold = kind == "ult"
	var t
	match state:
		"learned":
			t = Kit.row(open_node.bind(id), Pal.ACCENT if gold else col, col, 6, 3, 0.36)
		"can":
			t = Kit.row(open_node.bind(id), Pal.ACCENT, Pal.ACCENT, 6, 3, 0.14)
		_:
			t = Kit.row(open_node.bind(id), Pal.ACCENT.darkened(0.35) if gold else Pal.LINE, null, 6, 3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(0, TILE_H_FINGERS if Kit.fingers else TILE_H)
	t.set_meta("node", id)
	t.set_meta("node_state", state)
	t.set_meta("anchor_id", "node:" + id)

	var head = Kit.hbox(4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(0, 18)
	var icon_name = RpgUi.school_icon(str(node.board))
	var kind_word = "Move"
	if gold:
		icon_name = "crown"
		kind_word = "Ultimate"
	elif kind == "passive":
		icon_name = "star"
		kind_word = "Passive"
	head.add_child(Kit.vcenter(Icons.rect(icon_name, 16)))
	head.add_child(Kit.vcenter(Kit.clip(kind_word, 10, Pal.ACCENT if gold else Pal.MUTED, true)))
	if state == "learned":
		head.add_child(Kit.vcenter(Icons.rect("check", 16, Pal.GOOD)))
	else:
		head.add_child(Kit.vcenter(Icons.rect("sp", 16)))
		head.add_child(Kit.vcenter(Kit.label(str(int(node.cost)), 12, Pal.TEXT, true)))
	t.add(head)
	var title = _two_lines(_ref_name(node), 13, null, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add(title)

	var foot_h = FOOT_H_FINGERS if Kit.fingers else FOOT_H
	match state:
		"learned":
			var done = Kit.label("Learned", 12, Pal.GOOD, true)
			done.custom_minimum_size = Vector2(0, foot_h)
			done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t.add(done)
		"can":
			var key = RpgUi.page_key("Learn · %d" % int(node.cost), "primary", Callable(), "node_learn:" + id)
			key.custom_minimum_size.y = foot_h
			key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			key.set_meta("node_learn", id)
			key.pressed.connect(_learn.bind(id, key))
			t.add(key)
		_:
			var why = _two_lines(short_why(node, str(can.get("why", ""))), 11, Pal.ACCENT2, false)
			why.custom_minimum_size.y = foot_h
			why.set_meta("node_blocked", str(can.get("why", "")))
			why.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add(why)
			head.modulate = Color(1, 1, 1, 0.55)
			title.modulate = Color(1, 1, 1, 0.55)
	return t


## Learn a node: the save, a burst from `at`, the fanfare. True when it went through.
static func _learn(id: String, at) -> bool:
	var node = RpgSkills.by_id(id)
	if node == null:
		return false
	var res = RpgSave.learn(RpgUi.save(), id, RpgUi.sheet(), RpgUi.days())
	var ok = bool(res.get("ok", false))
	if ok and at is Control and is_instance_valid(at):
		Kit.burst(at, RpgUi.color(str(node.board)), 18)
		Kit.floater(at, "LEARNED", Pal.ACCENT)
	var before = fresh
	if ok:
		fresh = id
	if RpgUi.apply(res, "Learned %s" % _ref_name(node)):
		Sfx.level_up()
		return true
	fresh = before
	return false


# ---------------------------------------------------------------------------
# A node in full
# ---------------------------------------------------------------------------

static func open_node(id: String) -> void:
	var node = RpgSkills.by_id(id)
	if node == null:
		return
	var sh = Kit.sheet(_ref_name(node))
	_fill_node(sh, id)
	sh.open()


## What a node asks, each with whether it is met: [{"ok", "text"}].
static func reqs(node: Dictionary, rpg: Dictionary, sheet: Dictionary, level: int, days: int) -> Array:
	var out = []
	var tier = int(node.tier)
	var learned = RpgSkills.has_node(rpg, str(node.id))
	var board_name = str(RpgDefs.SCHOOL_NAMES.get(str(node.board), str(node.board)))
	if tier > 1:
		var below = false
		for o in RpgSkills.nodes_of(str(node.board)):
			if int(o.tier) == tier - 1 and RpgSkills.has_node(rpg, str(o.id)):
				below = true
		out.append({"ok": below or learned, "text": "A tier %d %s skill learned" % [tier - 1, board_name]})
	var need_level = int(RpgDefs.NODE_LEVEL[tier])
	if need_level > 1:
		out.append({"ok": level >= need_level or learned, "text": "Fighter level %d (you are %d)" % [need_level, level]})
	var need = int(RpgDefs.REQ[tier])
	var have = _stat_v(sheet, str(node.stat))
	out.append({"ok": have >= need or learned, "text": "%s %d (you have %d)" % [str(RpgDefs.STAT_NAMES.get(str(node.stat), str(node.stat))), need, have]})
	var left = int(RpgSkills.points(rpg, days).left)
	if learned:
		out.append({"ok": true, "text": "%s spent" % _plural(int(node.cost), "skill point")})
	else:
		out.append({"ok": left >= int(node.cost), "text": "%s (you have %d)" % [_plural(int(node.cost), "skill point"), maxi(0, left)]})
	return out


static func _req_mark(ok: bool) -> Control:
	var b = Kit.tick_box(ok, 20)
	if not ok:
		b.get_child(0).add_child(Icons.rect("close", 16, Pal.DANGER))
	return b


static func _fill_node(sh, id: String) -> void:
	Kit.clear(sh.box)
	var node = RpgSkills.by_id(id)
	var rpg = RpgUi.save()
	var sheet = RpgUi.sheet()
	var level = RpgUi.level()
	var days = RpgUi.days()
	var col = RpgUi.color(str(node.board))
	sh.box.set_meta("node_sheet", id)
	var row = _ref_row(node)
	if row is Dictionary:
		if str(node.kind) == "passive":
			sh.box.add_child(RealmMoves.passive_card(row))
			sh.box.add_child(Kit.muted_para("A passive is always on once it sits in a passive slot (the first opens at fighter level %d)." % int(RpgDefs.PASSIVE_SLOTS_AT[0]), 12))
		else:
			var card = RpgUi.move_card(row, {})
			card.add(RealmMoves.facts(row))
			sh.box.add_child(card)
			if str(node.kind) == "ult":
				sh.box.add_child(Kit.muted_para("An ultimate needs a full gauge: it fills as you act, hit weaknesses and break guards.", 12))
	var learned = RpgSkills.has_node(rpg, id)
	sh.box.add_child(Kit.sub_head("LEARNED WITH" if learned else "TO LEARN IT", col))
	for r in reqs(node, rpg, sheet, level, days):
		var line = Kit.hbox(8)
		line.set_meta("node_req", bool(r.ok))
		line.add_child(_req_mark(bool(r.ok)))
		line.add_child(Kit.vcenter(Kit.para(str(r.text), 13, Pal.TEXT if bool(r.ok) else Pal.ACCENT2)))
		sh.box.add_child(line)
	if learned:
		var done = Kit.hbox(8)
		done.add_child(Kit.tag("LEARNED", Pal.GOOD))
		done.add_child(Kit.spacer())
		sh.box.add_child(done)
		var equip = func():
			RealmSkills.fresh = ""
			sh.close()
			RealmMoves.open_equip(str(node.ref))
		var eq = RpgUi.page_key("Equip it now", "primary", equip, "node_equip", "lg")
		eq.set_meta("node_equip", id)
		sh.box.add_child(eq)
		return
	var can = RpgSkills.can_learn(rpg, id, sheet, level, days)
	if bool(can.get("ok", false)):
		var key = RpgUi.page_key("Learn for %s" % _plural(int(node.cost), "point"), "primary", Callable(), "node_learn_sheet", "lg")
		key.set_meta("node_learn", id)
		var learn = func():
			if RealmSkills._learn(id, key) and is_instance_valid(sh):
				RealmSkills._fill_node(sh, id)
		key.pressed.connect(learn)
		sh.box.add_child(key)
	else:
		var why = Kit.para("%s." % str(can.get("why", "")), 14, Pal.ACCENT2, true)
		why.set_meta("node_why", str(can.get("why", "")))
		sh.box.add_child(why)
