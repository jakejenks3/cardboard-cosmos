class_name ClimbCard
extends RefCounted
## The Journey tab's climbing card (counts from game/climb_ladder.gd).
##
## Three outcomes, each its own colour everywhere on the card (the Log tab's
## colours): FLASHES (gold, sent first go), SENDS (climbing colour, sent after
## tries) and DIDN'T GO (the attempt colour, tries that failed). A flash is a
## send, so the bar under the tiles brackets the two as "SENT".
##
##   chips      Boulders / Routes, only when both were logged
##   tiles      flashes, sends, didn't go
##   OutcomeBar every try, the sent part bracketed
##   GradeLadder a bar per grade, hardest first; a click picks a grade and
##              only the detail under it is redrawn (nothing above moves)
##   detail     the picked grade: its three numbers, sent %, first send, last try
##   records    hardest send / flash, hangboard bests

## "boulder" or "route": kept while the game runs, so a rebuild keeps it.
static var mode = "boulder"
## mode -> the grade picked in it.
static var picks = {}


static func build(s: Dictionary, sessions: Array) -> Control:
	var cc = Kit.card(10)
	cc.accent(Pal.CLIMB)
	cc.add(JourneyScreen.disc_head("climb"))
	var body = Kit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.add(body)
	_fill(body, s, sessions)
	return cc


static func _clear(box: Control) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


static func _fill(body: Control, s: Dictionary, sessions: Array) -> void:
	_clear(body)
	var has_b = ClimbLadder.has_boulders(sessions)
	var has_r = ClimbLadder.has_routes(sessions)
	if mode == "route" and not has_r:
		mode = "boulder"
	if mode == "boulder" and not has_b and has_r:
		mode = "route"
	var routes = mode == "route"
	if has_b and has_r:
		var chips = Kit.hbox(6)
		for m in [["boulder", "Boulders"], ["route", "Routes"]]:
			chips.add_child(Kit.chip(m[1], mode == m[0], func():
				if mode == m[0]:
					return
				Sfx.tap()
				mode = m[0]
				_fill(body, s, sessions), Pal.CLIMB))
		body.add_child(chips)
	var lad = ClimbLadder.ladder(sessions, routes)
	var t = lad.total
	var tiles = Kit.grid(3, 8)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_child(_tile("bolt", int(t.flash), "Flashes", "sent first go", GradeLadder.flash_col()))
	tiles.add_child(_tile("check", int(t.send), "Sends", "sent after tries", GradeLadder.send_col()))
	tiles.add_child(_tile("repeat", int(t.attempt), "Didn't go", "tries that failed", GradeLadder.miss_col()))
	body.add_child(tiles)
	if int(t.tries) > 0:
		var ob = OutcomeBar.new()
		ob.setup(t)
		body.add_child(ob)
	if lad.rows.is_empty():
		body.add_child(Kit.muted_para("No %s logged yet." % ("routes" if routes else "boulders"), 13))
	else:
		var head = Kit.hbox(8)
		var ht = Kit.clip("By grade", 13, Pal.TEXT, true)
		ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(ht)
		head.add_child(Kit.clip("sent / tries · click a grade", 11, Pal.MUTED))
		body.add_child(head)
		var pick = _pick_index(lad.rows)
		var chart = GradeLadder.new()
		chart.setup(lad.rows, pick)
		body.add_child(chart)
		body.add_child(Charts.legend([
			{"name": "Flash: first go", "color": GradeLadder.flash_col()},
			{"name": "Send: after tries", "color": GradeLadder.send_col()},
			{"name": "Didn't go", "color": GradeLadder.miss_col().lerp(Pal.WELL, 0.35)},
		]))
		var detail = Kit.vbox(6)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(detail)
		_detail(detail, lad.rows[pick], routes)
		chart.picked.connect(func(i):
			Sfx.tap()
			picks[mode] = int(lad.rows[i].grade)
			chart.sel = i
			chart.queue_redraw()
			_detail(detail, lad.rows[i], routes)
			Kit.burst(detail, GradeLadder.send_col() if int(lad.rows[i].sent) > 0 else GradeLadder.miss_col(), 10))
	var recs = _records(s, lad, routes)
	if not recs.is_empty():
		var ef = Kit.flow(6)
		for x in recs:
			ef.add_child(x)
		body.add_child(ef)


## The row picked before in this mode, else the hardest grade sent.
static func _pick_index(rows: Array) -> int:
	if picks.has(mode):
		for i in range(rows.size()):
			if int(rows[i].grade) == int(picks[mode]):
				return i
	return ClimbLadder.default_pick(rows)


## A sunken tile: icon and big number in the outcome's colour, its name, what it means.
static func _tile(icon: String, n: int, cap: String, hint: String, col: Color) -> Control:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.well(6, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v = Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(Kit.vcenter(Icons.rect(icon, 16)))
	var num = Xp.fmt_int(n)
	top.add_child(Kit.vcenter(PixelFont.rect(num, 3 if num.length() <= 3 else 2, col if n > 0 else Pal.MUTED)))
	v.add_child(top)
	v.add_child(JourneyScreen.caption(cap, 12, col))
	v.add_child(JourneyScreen.caption(hint, 11))
	p.add_child(v)
	return p


## The grade, big, on a plate: gold when it was flashed, the climbing colour
## when it was sent, grey when it has not gone yet.
static func _badge(text: String, col: Color) -> Control:
	var plate = PanelContainer.new()
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(56, 44)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(col), {"ring": col, "lip": 1, "lip_color": Pal.OUTLINE, "pad_h": 3, "pad_v": 2}))
	plate.add_child(Kit.center(PixelFont.rect(text, JourneyScreen.fit_scale([text], 50, 2), Color.WHITE)))
	return plate


## The picked grade's numbers.
static func _detail(box: Control, r: Dictionary, routes: bool) -> void:
	_clear(box)
	var col = GradeLadder.flash_col() if int(r.flash) > 0 else (GradeLadder.send_col() if int(r.sent) > 0 else Pal.MUTED)
	var row = Kit.hbox(12)
	row.add_child(_badge(str(r.label), col))
	var v = Kit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if int(r.tries) == 0:
		v.add_child(Kit.clip("Nothing logged at %s yet" % str(r.label), 15, null, true))
		v.add_child(Kit.clip("It sits between grades you have climbed.", 12, Pal.MUTED))
		row.add_child(v)
		box.add_child(row)
		return
	var n_s = int(r.sessions)
	v.add_child(Kit.clip("%d %s over %d session%s" % [int(r.tries), "try" if int(r.tries) == 1 else "tries", n_s, "" if n_s == 1 else "s"], 15, null, true))
	var chips = Kit.flow(6)
	chips.add_child(Kit.icon_chip("bolt", "%d flashed" % int(r.flash), GradeLadder.flash_col() if int(r.flash) > 0 else Pal.PANEL2))
	chips.add_child(Kit.icon_chip("check", "%d sent after tries" % int(r.send), GradeLadder.send_col() if int(r.send) > 0 else Pal.PANEL2))
	chips.add_child(Kit.icon_chip("repeat", "%d didn't go" % int(r.attempt), GradeLadder.miss_col() if int(r.attempt) > 0 else Pal.PANEL2))
	v.add_child(chips)
	var bits = []
	if int(r.sent) > 0:
		bits.append("Sent %d of %d (%d%%)" % [int(r.sent), int(r.tries), ClimbLadder.pct(int(r.sent), int(r.tries))])
		bits.append("first sent %s" % when_text(str(r.firstSent)))
	else:
		bits.append("Not sent yet")
	bits.append("last tried %s" % when_text(str(r.last)))
	v.add_child(Kit.muted_para(" · ".join(PackedStringArray(bits)), 12))
	row.add_child(v)
	box.add_child(row)


## A day inside a sentence: "today", "yesterday", "Saturday", "Nov 16".
static func when_text(d: String) -> String:
	var rd = Dates.relative_day(d, App.today)
	return rd.to_lower() if rd == "Today" or rd == "Yesterday" else rd


## Hardest send and flash in this mode, then the hangboard bests.
static func _records(s: Dictionary, lad: Dictionary, routes: bool) -> Array:
	var out = []
	var what = "route" if routes else "send"
	if lad.hardestSent != null:
		out.append(JourneyScreen.value_chip("Hardest " + what, ClimbLadder.label(int(lad.hardestSent), routes), GradeLadder.send_col()))
	if lad.hardestFlash != null:
		out.append(JourneyScreen.value_chip("Hardest flash", ClimbLadder.label(int(lad.hardestFlash), routes), GradeLadder.flash_col()))
	var t = s.totals
	if int(TTUtil.get_or(t, "hangs", 0)) > 0:
		var hsec: int = int(TTUtil.get_or(t, "hangSec", 0))
		out.append(JourneyScreen.value_chip("Hangs", "%s · %s" % [Xp.fmt_int(t.hangs), ("%d s" % hsec) if hsec < 120 else Fmt.fmt_duration_short(float(hsec))], Pal.CLIMB))
	if float(TTUtil.get_or(s.prs, "bestHangKg", 0.0)) > 0.0:
		out.append(JourneyScreen.value_chip("Heaviest hang", "+" + Fmt.fmt_weight(float(s.prs.bestHangKg), App.weight_unit()), Pal.CLIMB))
	for table in ["hangEdge", "hangOneArm"]:
		if s.prs.get(table) == null:
			continue
		var edges = s.prs[table].keys()
		edges.sort_custom(func(a, b): return int(a) < int(b))
		for ek in edges:
			var cap = Xp.edge_label(int(ek)) + (" one arm" if table == "hangOneArm" else "")
			var kg = float(s.prs[table][ek])
			out.append(JourneyScreen.value_chip(cap, ("+" + Fmt.fmt_weight(kg, App.weight_unit())) if kg > 0.0 else "5 s+", Pal.CLIMB, "Best 5 s+ hang on this edge"))
	return out
