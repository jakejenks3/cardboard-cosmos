class_name JourneyBody
extends RefCounted
## Journey → Body (port of `BodyJourney` + `PhotoThumb` in screens/Body.tsx):
## weight / body-fat trends, then-and-now photo comparison, gallery and the
## list of check-ins. State lives in the screen: `st` = {angle, then, now}.


## Fill `parent` (the screen's VBox). `rebuild` re-renders the screen after a local change.
static func build(parent: Control, st: Dictionary, rebuild: Callable) -> void:
	var wu = App.weight_unit()
	var entries = App.body().duplicate()
	TTUtil.stable_sort(entries, func(a, b): return a.date < b.date or (a.date == b.date and a.createdAt < b.createdAt))

	if entries.is_empty():
		parent.add_child(Kit.empty("camera", "See how far you've come",
			"Check in with your weight, body fat or front / side / back photos. A weekly check-in earns XP, and the photos line up into a then-and-now you can actually see.",
			Kit.button("Start a check-in", "primary", func(): App.open_log("body"))))
		return

	var weights = []
	var fats = []
	for e in entries:
		if TTUtil.truthy(e.get("weightKg")):
			weights.append({"x": e.date, "y": Fmt.kg_to_unit(e.weightKg, wu)})
		if TTUtil.truthy(e.get("bodyFatPct")):
			fats.append({"x": e.date, "y": float(e.bodyFatPct)})
	var angle = st.angle
	var with_angle = entries.filter(func(e): return _photo(e, angle) != null)
	var with_photos = entries.filter(func(e): return _photo_count(e) > 0)
	with_photos.reverse()

	var b = App.state.body
	var delta = null
	if b.latestWeightKg != null and b.firstWeightKg != null:
		delta = float(b.latestWeightKg) - float(b.firstWeightKg)
	var lean = null
	if b.latestWeightKg != null and b.latestBodyFat != null:
		lean = float(b.latestWeightKg) * (1.0 - float(b.latestBodyFat) / 100.0)

	# Tiles
	var since = "—"
	if delta != null and b.firstWeightDate != b.latestWeightDate:
		var sgn = "+" if delta > 0.0 else ("−" if delta < 0.0 else "")
		since = sgn + Fmt.fmt_weight(absf(delta), wu)
	var tiles = Kit.grid(3, 8)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.add(tiles, [
		Kit.stat("Weight", Fmt.fmt_weight(b.latestWeightKg, wu) if b.latestWeightKg != null else "—", Dates.format_date(b.latestWeightDate) if b.latestWeightDate != null else ""),
		Kit.stat("Since start", since, ("from " + Dates.format_date(b.firstWeightDate)) if b.firstWeightDate != null else ""),
		Kit.stat("Body fat", (TTUtil.num_str(b.latestBodyFat) + "%") if b.latestBodyFat != null else "—", ("lean " + Fmt.fmt_weight(lean, wu)) if lean != null else ""),
	])
	parent.add_child(tiles)

	var row = Kit.hbox(8)
	var cal = Icons.rect("calendar", 16)
	cal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cal)
	var streak = Kit.muted_para("%d week check-in streak · best %d" % [int(b.streak), int(b.bestStreak)], 13)
	streak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(streak)
	row.add_child(Kit.vcenter(Kit.button("Check in", "primary", func(): App.open_log("body"), "sm", "plus")))
	parent.add_child(row)

	# Trends
	if weights.size() >= 2:
		parent.add_child(Kit.section_title("Weight"))
		var wc = Kit.card()
		var trend = Charts.moving_average(weights, 5) if weights.size() >= 5 else []
		wc.add(Charts.line(weights, Pal.ACCENT, func(v): return "%s %s" % [Fmt.to_fixed(v, 1), wu], trend))
		if weights.size() >= 5:
			wc.add(Kit.muted("Dashed line: smoothed trend (5-entry average)", 11))
		parent.add_child(wc)
	if fats.size() >= 2:
		parent.add_child(Kit.section_title("Body fat"))
		var fc = Kit.card()
		fc.add(Charts.line(fats, Pal.RUN, func(v): return Fmt.to_fixed(v, 1) + "%"))
		parent.add_child(fc)

	# Then & now + gallery
	if not with_photos.is_empty():
		parent.add_child(Kit.section_title("Then & now"))
		parent.add_child(_compare(st, angle, with_angle, wu, rebuild))
		parent.add_child(Kit.section_title("Gallery"))
		var gal = Kit.vbox(8)
		for e in with_photos:
			var gc = Kit.card(8, Callable(), 11)
			var head = Kit.hbox(8)
			head.add_child(Kit.clip(Dates.format_date_long(e.date), 14, null, true))
			head.add_child(Kit.link("Edit", App.open_log.bind("body", e.id)))
			gc.add(head)
			var thumbs = Kit.grid(3, 6)
			thumbs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for a in TT.PHOTO_ANGLES:
				var pid = _photo(e, a)
				thumbs.add_child(PhotoThumb.make(pid, _viewer.bind(pid) if pid != null else Callable()))
			gc.add(thumbs)
			var bits = []
			if TTUtil.truthy(e.get("weightKg")):
				bits.append(Fmt.fmt_weight(e.weightKg, wu))
			if TTUtil.truthy(e.get("bodyFatPct")):
				bits.append(TTUtil.num_str(e.bodyFatPct) + "% body fat")
			if not bits.is_empty():
				gc.add(Kit.muted(" · ".join(PackedStringArray(bits)), 12))
			gal.add_child(gc)
		parent.add_child(gal)

	# Every check-in, newest first
	parent.add_child(Kit.section_title("All check-ins"))
	var list = Kit.vbox(6)
	var body_xp = App.state.bodyXp
	for i in range(entries.size() - 1, -1, -1):
		list.add_child(_entry_row(entries[i], int(body_xp.get(entries[i].id, 0)), wu))
	parent.add_child(list)


static func _photo(e: Dictionary, a: String):
	var ph = e.get("photos")
	if not (ph is Dictionary):
		return null
	var id = ph.get(a)
	return id if TTUtil.truthy(id) else null


static func _photo_count(e: Dictionary) -> int:
	var n = 0
	for a in TT.PHOTO_ANGLES:
		if _photo(e, a) != null:
			n += 1
	return n


static func _caption(e: Dictionary, wu: String) -> String:
	var s = Dates.format_date(e.date, {"month": "short", "day": "numeric", "year": "numeric"})
	if TTUtil.truthy(e.get("weightKg")):
		s += " · " + Fmt.fmt_weight(e.weightKg, wu)
	return s


static func _set_angle(a, st: Dictionary, rebuild: Callable) -> void:
	st.angle = a
	rebuild.call()


static func _pick(index: int, ids: Array, which: String, st: Dictionary, rebuild: Callable) -> void:
	st[which] = ids[index]
	rebuild.call()


static func _compare(st: Dictionary, angle: String, with_angle: Array, wu: String, rebuild: Callable) -> Control:
	var card = Kit.card(10)
	var opts = []
	for a in TT.PHOTO_ANGLES:
		opts.append({"value": a, "label": TT.PHOTO_ANGLE_NAMES[a]})
	card.add(Kit.segmented(opts, angle, _set_angle.bind(st, rebuild)))
	if with_angle.is_empty():
		var l = Kit.muted_para("No %s photos yet." % TT.PHOTO_ANGLE_NAMES[angle].to_lower(), 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(l)
		return card
	var then_e = with_angle[0]
	var now_e = with_angle[with_angle.size() - 1]
	var ids = []
	for e in with_angle:
		ids.append(e.id)
		if e.id == st.then:
			then_e = e
		if e.id == st.now:
			now_e = e
	var grid = Kit.grid(2, 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pair = [then_e, now_e]
	for i in range(2):
		var e = pair[i]
		var cell = Kit.vbox(6)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pid = _photo(e, angle)
		cell.add_child(PhotoThumb.make(pid, _viewer.bind(pid)))
		var tag = Kit.label("THEN" if i == 0 else "NOW", 11, Pal.ACCENT, true)
		cell.add_child(tag)
		var sel = OptionButton.new()
		sel.focus_mode = Control.FOCUS_NONE
		sel.add_theme_font_size_override("font_size", 12)
		sel.clip_text = true
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel.custom_minimum_size = Vector2(0, 36)
		sel.tooltip_text = "Then date" if i == 0 else "Now date"
		for k in range(with_angle.size()):
			sel.add_item(_caption(with_angle[k], wu), k)
		sel.select(ids.find(e.id))
		sel.item_selected.connect(_pick.bind(ids, "then" if i == 0 else "now", st, rebuild))
		cell.add_child(sel)
		grid.add_child(cell)
	card.add(grid)
	if then_e.id != now_e.id:
		var txt = "[b][color=%s]%d days[/color][/b] apart" % [Kit.hex_of(Pal.ACCENT), Dates.days_between(then_e.date, now_e.date)]
		if TTUtil.truthy(then_e.get("weightKg")) and TTUtil.truthy(now_e.get("weightKg")):
			txt += " · %s → %s" % [Fmt.fmt_weight(then_e.weightKg, wu), Fmt.fmt_weight(now_e.weightKg, wu)]
		var r = Kit.rich("[center]%s[/center]" % txt, 13, Pal.MUTED)
		card.add(r)
	else:
		var l2 = Kit.muted_para("Add another check-in with photos to compare.", 13)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add(l2)
	return card


static func _entry_row(e: Dictionary, xp: int, wu: String) -> Control:
	var n = _photo_count(e)
	var card = Kit.card(4, App.open_log.bind("body", e.id), 10)
	var row = Kit.hbox(10)
	var badge = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 10, Pal.LINE, 1, 0, 0))
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(Kit.center(Icons.rect("camera" if n > 0 else "scale", 22)))
	row.add_child(badge)
	var main = Kit.vbox(1)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(Kit.clip(Dates.format_date_long(e.date), 14, null, true))
	var bits = []
	if TTUtil.truthy(e.get("weightKg")):
		bits.append(Fmt.fmt_weight(e.weightKg, wu))
	if TTUtil.truthy(e.get("bodyFatPct")):
		bits.append(TTUtil.num_str(e.bodyFatPct) + "% fat")
	if n > 0:
		bits.append("%d photo%s" % [n, "" if n == 1 else "s"])
	if TTUtil.truthy(e.get("note")):
		bits.append(Icons.strip_emoji(e.note))
	if not bits.is_empty():
		main.add_child(Kit.clip(" · ".join(PackedStringArray(bits)), 12, Pal.MUTED))
	row.add_child(main)
	if xp > 0:
		row.add_child(Kit.vcenter(Kit.label("+%s" % Xp.fmt_int(xp), 14, Pal.ACCENT, true)))
	card.add(row)
	return card


static func _viewer(id) -> void:
	if id == null:
		return
	var sh = Kit.sheet("Progress photo")
	var big = PhotoThumb.make(id, Callable())
	big.contain = true
	big.custom_minimum_size = Vector2(40, 560)
	sh.box.add_child(big)
	sh.open()


## A 3:4 progress photo, cropped to fill; striped placeholder when missing.
class PhotoThumb extends Control:
	var photo_id = null
	var on_click = Callable()
	var tex = null
	## true = show the whole picture (viewer) instead of cropping it to fill.
	var contain = false

	static func make(id, cb: Callable) -> Control:
		var t = PhotoThumb.new()
		t.photo_id = id
		t.on_click = cb
		t.tex = App.photo_texture(id) if id != null else null
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(40, 53)
		t.mouse_filter = Control.MOUSE_FILTER_PASS
		t.clip_contents = true
		if cb.is_valid() and t.tex != null:
			t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		t.resized.connect(t._on_resized)
		return t

	func _on_resized() -> void:
		if contain:
			queue_redraw()
			return
		var h = roundf(size.x * 4.0 / 3.0)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(40, h)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if on_click.is_valid() and tex != null:
				Sfx.tap()
				on_click.call()
				accept_event()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if tex == null:
			draw_rect(Rect2(0, 0, w, h), Pal.WELL)
			var o = -h
			while o < w:
				var x0 = o
				var y0 = 0.0
				if x0 < 0.0:
					y0 = -x0
					x0 = 0.0
				var x1 = o + h
				var y1 = h
				if x1 > w:
					y1 = h - (x1 - w)
					x1 = w
				if y1 > y0:
					draw_line(Vector2(x0, y0), Vector2(x1, y1), Pal.BG2, 6.0)
				o += 12.0
			draw_rect(Rect2(0, 0, w, h), Pal.LINE, false, 1.0)
			return
		var tw = float(tex.get_width())
		var th = float(tex.get_height())
		if contain:
			var kc = minf(w / tw, h / th)
			var dw = tw * kc
			var dh = th * kc
			draw_texture_rect(tex, Rect2((w - dw) / 2.0, (h - dh) / 2.0, dw, dh), false)
			return
		var k = maxf(w / tw, h / th)
		var sw = w / k
		var sh = h / k
		draw_texture_rect_region(tex, Rect2(0, 0, w, h), Rect2((tw - sw) / 2.0, (th - sh) / 2.0, sw, sh))
		draw_rect(Rect2(0, 0, w, h), Pal.LINE, false, 1.0)
