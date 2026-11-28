class_name TrophyRoom
extends RefCounted
## The trophy room: the player's newest trophies on wooden shelves (glowing in
## their tier's colour), their records as framed plaques (the strongest lifts,
## the longest run, ride and hang, the hardest climb) and their companions
## wandering on the floor. Opened from Adventure -> Trophies.

const PER_SHELF = 7
const SHELVES = 4


static func open() -> void:
	Sfx.tap()
	var sh = Kit.sheet("Trophy room")
	sh.box.add_child(_title())
	sh.box.add_child(_shelves())
	sh.box.add_child(Kit.section_title("Record plaques"))
	sh.box.add_child(_plaques())
	var pets = _pets_floor()
	if pets != null:
		sh.box.add_child(Kit.section_title("Companions"))
		sh.box.add_child(pets)
	var ok = Kit.button("Close", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()


## Under the sheet's own title (it says "Trophy room" already: the big gold pixel copy of it on cream was
## dropped in the 2026-11-27 Workshop review): the trophy and how many are earned.
static func _title() -> Control:
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("trophy", 32)))
	var n = App.state.achievements.size()
	h.add_child(Kit.vcenter(Kit.tag("%d earned" % n, Pal.ACCENT, true, 13)))
	h.add_child(Kit.vcenter(Kit.clip("of %d trophies" % Achievements.all().size(), 13, Pal.MUTED, true)))
	return h


## The dark wall behind the shelves and the companions' floor: one sunken well (Pal.MATERIALS, no colour
## typed here).
static func _wall_box(pad: int) -> StyleBox:
	return PixBox.material("well", {"pad_h": pad, "pad_v": pad})


## A wooden plank: a lit top edge, the board, a shaded bottom edge, in the browns of the Workshop's wood.
static func _plank(h: int = 5) -> Control:
	var v = Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in [[Pal.LINE.darkened(0.25), 2], [Pal.BORDER, h], [Pal.BORDER.darkened(0.45), 2]]:
		var r = ColorRect.new()
		r.color = part[0]
		r.custom_minimum_size = Vector2(0, part[1])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
	return v


## Shelves of the newest trophies: a row of framed slots on a wooden plank.
static func _shelves() -> Control:
	var ids = App.state.achievements.keys()
	ids.sort_custom(func(a, b): return str(App.state.achievements[a].get("at", "")) > str(App.state.achievements[b].get("at", "")))
	var wall = PanelContainer.new()
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.add_theme_stylebox_override("panel", _wall_box(10))
	var v = Kit.vbox(4)
	if ids.is_empty():
		v.add_child(Kit.para("No trophies yet: your first workout earns one.", 13, Pal.LINE))
	for s in range(SHELVES):
		var row_ids = ids.slice(s * PER_SHELF, (s + 1) * PER_SHELF)
		if row_ids.is_empty():
			break
		var row = Kit.hbox(4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in row_ids:
			row.add_child(_trophy(str(id)))
		v.add_child(row)
		v.add_child(_plank(5))
		v.add_child(Kit.gap(4))
	if ids.size() > SHELVES * PER_SHELF:
		v.add_child(Kit.label("and %d more in Adventure -> Trophies" % (ids.size() - SHELVES * PER_SHELF), 11, Pal.LINE))
	wall.add_child(v)
	return wall


static func _trophy(id: String) -> Control:
	var a = Achievements.by_id(id)
	var slot = PanelContainer.new()
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.custom_minimum_size = Vector2(44, 44)
	var tc = Pal.hex(Achievements.TIER_COLOR[Achievements.tier_of(a)]) if a != null else Pal.ACCENT
	# (a framed icon slot ringed in the tier's colour, as every icon of the Workshop look)
	slot.add_theme_stylebox_override("panel", PixBox.slot(tc, true, 2))
	var mid = CenterContainer.new()
	mid.add_child(Icons.rect(Icons.for_emoji(a.icon) if a != null else "trophy", 32))
	slot.add_child(mid)
	slot.tooltip_text = Icons.strip_emoji(str(a.name)) if a != null else id
	if a != null and ["gold", "platinum"].has(str(Achievements.tier_of(a))):
		Fx.twinkle(slot, tc, 1)
	return slot


## The records, framed: the heaviest lifts as they were really done (the weight
## of the heaviest set and its reps, never an estimated one-rep max: a plaque
## is for something that happened), then the longest run, ride and hang and
## the hardest climb that has been sent.
static func _plaques() -> Control:
	var wu = App.weight_unit()
	var du = App.distance_unit()
	var items = []
	var rows = LiftLibrary.stats(App.sessions()).values().filter(func(r): return float(r.bestKg) > 0.0)
	rows.sort_custom(func(a, b):
		if absf(float(a.bestKg) - float(b.bestKg)) > 1e-9:
			return float(a.bestKg) > float(b.bestKg)
		return int(a.bestReps) > int(b.bestReps))
	for r in rows.slice(0, 4):
		var sp = LiftNames.split(str(r.name))
		items.append(["lift", str(sp.move), "%s × %d" % [Fmt.fmt_weight(float(r.bestKg), wu), int(r.bestReps)], Pal.LIFT])
	var prs = App.state.get("prs", {})
	if float(prs.get("longestRunM", 0.0)) > 0.0:
		items.append(["run", "Longest run", Fmt.fmt_distance(float(prs.longestRunM), du), Pal.RUN])
	if prs.get("climbMaxSend") != null:
		items.append(["climb", "Hardest send", Xp.grade_label(int(prs.climbMaxSend)), Pal.CLIMB])
	if prs.get("longestHangSec") != null and float(prs.longestHangSec) > 0.0:
		items.append(["climb", "Longest hang", "%d s" % int(prs.longestHangSec), Pal.CLIMB])
	var grid = Kit.grid(2, 8)
	if items.is_empty():
		var empty = Kit.para("Records appear here as you set them.", 13, Pal.MUTED)
		return empty
	for it in items:
		var c = Kit.card(2, Callable(), 8)
		c.accent(Pal.ACCENT)
		var h = Kit.hbox(8)
		h.add_child(Kit.vcenter(Icons.rect(str(it[0]), 24)))
		var v = Kit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Kit.clip(str(it[1]).to_upper(), 10, it[3], true))
		v.add_child(Kit.clip(str(it[2]), 15, null, true))
		h.add_child(v)
		c.add(h)
		grid.add_child(c)
	return grid


## The floor: every companion the player has, walking to and fro. (2026-11-27 Workshop review: it was a
## navy strip in typed colours, the old look; now the shelves' dark wall with a wooden plank to walk on.)
static func _pets_floor():
	var owned = App.state.get("pets", {}).keys()
	if owned.is_empty():
		return null
	var floor = Control.new()
	floor.custom_minimum_size = Vector2(0, 76)
	floor.clip_contents = true
	var bg = Panel.new()
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _wall_box(0))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor.add_child(bg)
	# (inside the well's rim, which is 2 art pixels: 4 screen pixels)
	var boards = _plank(6)
	boards.anchor_right = 1.0
	boards.offset_left = 4
	boards.offset_right = -4
	boards.offset_top = 62
	boards.offset_bottom = 72
	floor.add_child(boards)
	var i = 0
	for id in owned.slice(0, 6):
		var pv = PetView.new()
		pv.setup(str(id), 44.0, true)
		pv.position = Vector2(10 + i * 58, 18)
		floor.add_child(pv)
		# a stroll: across and back, at its own pace
		var tw = pv.create_tween().set_loops()
		var span = 40.0 + 12.0 * (i % 3)
		tw.tween_property(pv, "position:x", pv.position.x + span, 2.2 + 0.4 * i).set_trans(Tween.TRANS_SINE)
		tw.tween_property(pv, "position:x", pv.position.x, 2.2 + 0.4 * i).set_trans(Tween.TRANS_SINE)
		i += 1
	return floor
