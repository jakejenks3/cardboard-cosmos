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


static func _title() -> Control:
	var h = Kit.hbox(10)
	h.add_child(Kit.vcenter(Icons.rect("trophy", 32)))
	var t = PixelFont.rect("TROPHY ROOM", 3, Pal.ACCENT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var n = App.state.achievements.size()
	h.add_child(Kit.spacer())
	h.add_child(Kit.vcenter(Kit.tag("%d earned" % n, Pal.ACCENT, true, 11)))
	return h


## Shelves of the newest trophies: a row of glowing slots on a wooden plank.
static func _shelves() -> Control:
	var ids = App.state.achievements.keys()
	ids.sort_custom(func(a, b): return str(App.state.achievements[a].get("at", "")) > str(App.state.achievements[b].get("at", "")))
	var wall = PanelContainer.new()
	wall.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(Pal.BG2, 0.9), 5, Pal.LINE, 2, 10, 10))
	var v = Kit.vbox(4)
	if ids.is_empty():
		v.add_child(Kit.para("No trophies yet: your first workout earns one.", 13, Pal.MUTED))
	for s in range(SHELVES):
		var row_ids = ids.slice(s * PER_SHELF, (s + 1) * PER_SHELF)
		if row_ids.is_empty():
			break
		var row = Kit.hbox(4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in row_ids:
			row.add_child(_trophy(str(id)))
		v.add_child(row)
		var plank = ColorRect.new()
		plank.color = Color("7a5232")
		plank.custom_minimum_size = Vector2(0, 5)
		v.add_child(plank)
		var edge = ColorRect.new()
		edge.color = Color("4a301c")
		edge.custom_minimum_size = Vector2(0, 2)
		v.add_child(edge)
		v.add_child(Kit.gap(4))
	if ids.size() > SHELVES * PER_SHELF:
		v.add_child(Kit.label("and %d more in Adventure -> Trophies" % (ids.size() - SHELVES * PER_SHELF), 11, Pal.MUTED))
	wall.add_child(v)
	return wall


static func _trophy(id: String) -> Control:
	var a = Achievements.by_id(id)
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(44, 44)
	var tc = Pal.hex(Achievements.TIER_COLOR[Achievements.tier_of(a)]) if a != null else Pal.ACCENT
	slot.add_theme_stylebox_override("panel", Kit.sbox(Pal.with_alpha(tc, 0.18), 5, Pal.with_alpha(tc, 0.7), 2, 4, 4))
	var mid = CenterContainer.new()
	mid.add_child(Icons.rect(Icons.for_emoji(a.icon) if a != null else "trophy", 32))
	slot.add_child(mid)
	slot.tooltip_text = Icons.strip_emoji(str(a.name)) if a != null else id
	if a != null and ["gold", "platinum"].has(str(Achievements.tier_of(a))):
		Fx.twinkle(slot, tc, 1)
	return slot


## The records, framed: the strongest lifts by estimated one-rep max, then the
## longest run, ride and hang and the hardest climb that has been sent.
static func _plaques() -> Control:
	var wu = App.weight_unit()
	var du = App.distance_unit()
	var items = []
	var rows = LiftLibrary.stats(App.sessions()).values().filter(func(r): return float(r.e1rm) > 0.0)
	rows.sort_custom(func(a, b): return float(a.e1rm) > float(b.e1rm))
	for r in rows.slice(0, 4):
		var sp = LiftNames.split(str(r.name))
		items.append(["lift", str(sp.move), "%s strength" % Fmt.fmt_weight(float(r.e1rm), wu), Pal.LIFT])
	var prs = App.state.get("prs", {})
	if float(prs.get("longestRunM", 0.0)) > 0.0:
		items.append(["run", "Longest run", Fmt.fmt_distance(float(prs.longestRunM), du), Pal.RUN])
	if float(prs.get("longestRideM", 0.0)) > 0.0:
		items.append(["ride", "Longest ride", Fmt.fmt_distance(float(prs.longestRideM), du), Pal.RIDE])
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


## The floor: every companion the player has, walking to and fro.
static func _pets_floor():
	var owned = App.state.get("pets", {}).keys()
	if owned.is_empty():
		return null
	var floor = Control.new()
	floor.custom_minimum_size = Vector2(0, 76)
	floor.clip_contents = true
	var bg = ColorRect.new()
	bg.color = Color("3a3460")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor.add_child(bg)
	var line = ColorRect.new()
	line.color = Color("2b2540")
	line.anchor_right = 1.0
	line.offset_top = 64
	line.offset_bottom = 76
	floor.add_child(line)
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
