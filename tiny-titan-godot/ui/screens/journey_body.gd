class_name JourneyBody
extends RefCounted
## Journey → Body (port of `BodyJourney` + `PhotoThumb` in screens/Body.tsx):
## the current weight as a big number, the then-and-now photo comparison,
## weight / body-fat trends and a compact list of check-ins with little photos.
## State lives in the screen: `st` = {angle, then, now}.


## Fill `parent` (the screen's VBox). `rebuild` re-renders the screen after a local change.
static func build(parent: Control, st: Dictionary, rebuild: Callable) -> void:
	var wu = App.weight_unit()
	var entries = App.body().duplicate()
	TTUtil.stable_sort(entries, func(a, b): return a.date < b.date or (a.date == b.date and a.createdAt < b.createdAt))

	if entries.is_empty():
		parent.add_child(Kit.empty("camera", "See how far you've come",
			"Weigh in or snap a photo to start your then-and-now.",
			Kit.button("Start a check-in", "primary", func(): App.open_log("body"), "lg", "plus")))
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

	# --- the weight as the big number, the change since the start as a chip ----------
	parent.add_child(_summary(App.state.body, wu))

	# --- then & now photos ----------------------------------------------------------------
	if not with_photos.is_empty():
		parent.add_child(Kit.section_title("Then & now"))
		parent.add_child(_compare(st, angle, with_angle, wu, rebuild))

	# --- trends -----------------------------------------------------------------------
	if weights.size() >= 2:
		parent.add_child(Kit.section_title("Weight"))
		var wc = Kit.card(8)
		var trend = Charts.moving_average(weights, 5) if weights.size() >= 5 else []
		wc.add(Charts.line(weights, Pal.ACCENT, func(v): return "%s %s" % [Fmt.to_fixed(v, 1), wu], trend))
		if not trend.is_empty():
			var lg = Charts.legend([{"name": "Weigh-ins", "color": Pal.ACCENT}, {"name": "Trend", "color": Pal.TEXT}])
			lg.tooltip_text = "Trend: 5-entry moving average"
			wc.add(lg)
		parent.add_child(wc)
	if fats.size() >= 2:
		parent.add_child(Kit.section_title("Body fat"))
		var fc = Kit.card()
		fc.add(Charts.line(fats, Pal.RUN, func(v): return Fmt.to_fixed(v, 1) + "%"))
		parent.add_child(fc)

	# --- every check-in, newest first: date, weight, little photos ---------------------------
	parent.add_child(Kit.section_title("Check-ins"))
	var list = Kit.vbox(6)
	var body_xp = App.state.bodyXp
	for i in range(entries.size() - 1, -1, -1):
		list.add_child(_entry_row(entries[i], int(body_xp.get(entries[i].id, 0)), wu))
	parent.add_child(list)


## Current weight in big pixel digits, with chips for the change, body fat and the
## check-in streak, and the Check in button.
static func _summary(b: Dictionary, wu: String) -> Card:
	var card = Kit.card(10, Callable(), 12)
	card.accent(Pal.ACCENT)
	var row = Kit.hbox(10)
	row.add_child(Kit.vcenter(Icons.rect("scale", 34)))
	var wv = Kit.vbox(4)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var w_text = Fmt.fmt_weight(b.latestWeightKg, wu) if b.latestWeightKg != null else "-"
	wv.add_child(PixelFont.rect(w_text, JourneyScreen.fit_scale([w_text], 200, 4), Pal.TEXT))
	if b.latestWeightDate != null:
		wv.add_child(Kit.muted(Dates.format_date(b.latestWeightDate), 11))
	row.add_child(wv)
	row.add_child(Kit.vcenter(Kit.button("Check in", "primary", func(): App.open_log("body"), "md", "plus")))
	card.add(row)

	var chips = Kit.flow(6)
	if b.latestWeightKg != null and b.firstWeightKg != null and b.firstWeightDate != b.latestWeightDate:
		var delta = float(b.latestWeightKg) - float(b.firstWeightKg)
		var sgn = "+" if delta > 0.0 else ("−" if delta < 0.0 else "±")
		# A change in weight is neither good nor bad by itself: down is green, up is blue.
		var col = Pal.GOOD if delta < 0.0 else Pal.SECOND
		var t = Kit.tag("%s%s since %s" % [sgn, Fmt.fmt_weight(absf(delta), wu), Dates.format_date(b.firstWeightDate)], col, delta < 0.0, 12)
		chips.add_child(t)
	if b.latestBodyFat != null:
		var tip = ""
		if b.latestWeightKg != null:
			tip = "Lean mass %s" % Fmt.fmt_weight(float(b.latestWeightKg) * (1.0 - float(b.latestBodyFat) / 100.0), wu)
		var bf = Kit.tag("%s%% body fat" % TTUtil.num_str(b.latestBodyFat), Pal.RUN, true, 12)
		bf.tooltip_text = tip
		bf.mouse_filter = Control.MOUSE_FILTER_STOP
		chips.add_child(bf)
	var sk = _icon_tag("flame" if int(b.streak) > 0 else "ember", "%d wk streak" % int(b.streak), Pal.ACCENT2 if int(b.streak) > 0 else Pal.PANEL2)
	sk.tooltip_text = "Weekly check-in streak · best %d" % int(b.bestStreak)
	sk.mouse_filter = Control.MOUSE_FILTER_STOP
	chips.add_child(sk)
	card.add(chips)
	return card


## A small tag with a pixel icon in front.
static func _icon_tag(icon: String, text: String, color: Color) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.sbox(color, 5, null, 0, 7, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h = Kit.hbox(4)
	h.add_child(Kit.vcenter(Icons.rect(icon, 14)))
	var dark = color.get_luminance() > 0.5
	h.add_child(Kit.label(text, 12, Pal.INK if dark else Pal.TEXT, true))
	p.add_child(h)
	return p


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


static func _set_angle(a, st: Dictionary, rebuild: Callable) -> void:
	st.angle = a
	rebuild.call()


static func _pick(index: int, ids: Array, which: String, st: Dictionary, rebuild: Callable) -> void:
	st[which] = ids[index]
	rebuild.call()


static func _compare(st: Dictionary, angle: String, with_angle: Array, wu: String, rebuild: Callable) -> Control:
	var card = Kit.card(10)
	var angles = Kit.hbox(6)
	for a in TT.PHOTO_ANGLES:
		var ch = Kit.chip(TT.PHOTO_ANGLE_NAMES[a], a == angle, _set_angle.bind(a, st, rebuild))
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		angles.add_child(ch)
	card.add(angles)
	if with_angle.is_empty():
		card.add(JourneyScreen.caption("No %s photos yet" % TT.PHOTO_ANGLE_NAMES[angle].to_lower(), 13))
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
		var frame = PanelContainer.new()
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var ring = Pal.ACCENT if i == 1 else Pal.BORDER
		frame.add_theme_stylebox_override("panel", PixBox.make(Pal.OUTLINE, {"ring": ring, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 4, "pad_v": 4}))
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pid = _photo(e, angle)
		frame.add_child(PhotoThumb.make(pid, _viewer.bind(pid)))
		cell.add_child(frame)
		var tag_row = Kit.hbox(6)
		tag_row.add_child(Kit.vcenter(PixelFont.rect("THEN" if i == 0 else "NOW", 2, Pal.MUTED if i == 0 else Pal.ACCENT)))
		if TTUtil.truthy(e.get("weightKg")):
			tag_row.add_child(Kit.spacer())
			tag_row.add_child(Kit.vcenter(Kit.label(Fmt.fmt_weight(e.weightKg, wu), 13, Pal.TEXT, true)))
		cell.add_child(tag_row)
		var sel = OptionButton.new()
		sel.focus_mode = Control.FOCUS_NONE
		sel.add_theme_font_size_override("font_size", 12)
		sel.clip_text = true
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel.custom_minimum_size = Vector2(0, 34)
		sel.tooltip_text = "Then date" if i == 0 else "Now date"
		for k in range(with_angle.size()):
			sel.add_item(Dates.format_date(with_angle[k].date, {"month": "short", "day": "numeric", "year": "numeric"}), k)
		sel.select(ids.find(e.id))
		sel.item_selected.connect(_pick.bind(ids, "then" if i == 0 else "now", st, rebuild))
		cell.add_child(sel)
		grid.add_child(cell)
	card.add(grid)
	if then_e.id != now_e.id:
		var chips = Kit.flow(6)
		chips.alignment = FlowContainer.ALIGNMENT_CENTER
		chips.add_child(_icon_tag("calendar", "%d days apart" % Dates.days_between(then_e.date, now_e.date), Pal.ACCENT))
		if TTUtil.truthy(then_e.get("weightKg")) and TTUtil.truthy(now_e.get("weightKg")):
			var d = float(now_e.weightKg) - float(then_e.weightKg)
			chips.add_child(Kit.tag("%s%s" % ["+" if d > 0.0 else ("−" if d < 0.0 else "±"), Fmt.fmt_weight(absf(d), wu)], Pal.GOOD if d < 0.0 else Pal.SECOND, d < 0.0, 12))
		card.add(chips)
	else:
		card.add(JourneyScreen.caption("Add another photo check-in to compare", 12))
	return card


## One check-in on one line: date, weight, little photos, XP. Tap to edit it.
static func _entry_row(e: Dictionary, xp: int, wu: String) -> Control:
	var card = Kit.card(4, App.open_log.bind("body", e.id), 8)
	card.set_meta("checkin", e.id)
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main = Kit.vbox(1)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_child(Kit.clip(Dates.format_date(e.date, {"weekday": "short", "month": "short", "day": "numeric", "year": "numeric"}), 14, null, true))
	var bits = []
	if TTUtil.truthy(e.get("weightKg")):
		bits.append(Fmt.fmt_weight(e.weightKg, wu))
	if TTUtil.truthy(e.get("bodyFatPct")):
		bits.append(TTUtil.num_str(e.bodyFatPct) + "%")
	if not bits.is_empty():
		main.add_child(Kit.clip(" · ".join(PackedStringArray(bits)), 12, Pal.MUTED, true))
	if TTUtil.truthy(e.get("note")):
		card.tooltip_text = Icons.strip_emoji(e.note)
	row.add_child(main)
	for a in TT.PHOTO_ANGLES:
		var pid = _photo(e, a)
		if pid == null:
			continue
		var th = PhotoThumb.make(pid, _viewer.bind(pid))
		th.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		th.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.custom_minimum_size = Vector2(30, 40)
		row.add_child(th)
	if xp > 0:
		row.add_child(Kit.vcenter(Parts.xp_chip(xp, 12)))
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
		# Photos are smooth; only the pixel art around them is drawn crisp.
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
			custom_minimum_size = Vector2(custom_minimum_size.x, h)
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
