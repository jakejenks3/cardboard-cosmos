class_name RealmBestiary
extends RefCounted
## The bestiary of the Realm: every foe the player has met, with what has been
## learned of its weaknesses, and a dark shape for each one still out there.
## A card at the foot of the Map opens it as a sheet, region by region.
##
## Nothing new is stored. A foe counts as MET when one of its weaknesses was
## learned (saved.rpg.seen) or it stands in a stage that was won; the foes of
## hunts and of the Spire are the regions' own, so they are covered by that.
##
## Metas: map_bestiary (the card; its value is how many are met), bestiary_sheet,
## bestiary_foe (a foe's id) with bestiary_met (bool).

const COLS = 3
const TILE_W = 122


## The ids of the foes met: {id: true} (RpgFeats.met: the same count as the Field Guide feat's).
static func met(rpg: Dictionary) -> Dictionary:
	return RpgFeats.met(rpg)


## The catalog in the order of the road: [{"region": id, "name", "foes": [rows]}], then what belongs to none.
static func groups() -> Array:
	var out = []
	var placed = {}
	for reg in RpgWorld.regions():
		var rows = []
		var of = RpgFoes.of_region(str(reg.id))
		var ids = of.regular.duplicate()
		if str(of.elite) != "":
			ids.append(str(of.elite))
		if str(of.boss) != "":
			ids.append(str(of.boss))
		for id in ids:
			var row = RpgFoes.by_id(str(id))
			if row != null:
				rows.append(row)
				placed[str(id)] = true
		if not rows.is_empty():
			out.append({"region": str(reg.id), "name": str(reg.name), "foes": rows})
	var rest = []
	for f in RpgFoes.all():
		if not placed.has(str(f.id)):
			rest.append(f)
	if not rest.is_empty():
		out.append({"region": "", "name": "Elsewhere", "foes": rest})
	return out


static func total() -> int:
	return RpgFoes.all().size()


## The card on the Map: how many are met, the latest few as they look.
static func card(rpg: Dictionary) -> Control:
	var have = met(rpg)
	var count = Kit.label("%d / %d" % [have.size(), total()], 12, Pal.TEXT, true)
	var sec = Kit.section("map_bestiary", "BESTIARY", "skull", Pal.BOUNTY, count, RealmBestiary.open, 6, 10)
	sec.set_meta("map_bestiary", have.size())
	sec.set_meta("anchor_id", "map_bestiary")
	var row = Kit.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shown = 0
	for g in groups():
		for f in g.foes:
			if shown >= 7:
				break
			var fv = FoeView.new()
			fv.setup(str(f.id), 40.0, false)
			fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fv.set_silhouette(not have.has(str(f.id)))
			row.add_child(fv)
			shown += 1
	sec.add(row)
	sec.add(Kit.clip("Every foe you have met and what it is weak to. Tap to open.", 12, Pal.MUTED))
	return sec


static func open() -> void:
	var rpg = RpgUi.save()
	var have = met(rpg)
	RpgSfx.play("select")
	var sh = Kit.sheet("Bestiary")
	sh.box.set_meta("bestiary_sheet", have.size())
	sh.box.add_child(Kit.muted_para("%d of %d met. A dark shape is a foe you have not met yet; its weaknesses show once you find them in a fight." % [have.size(), total()], 12))
	for g in groups():
		var n = 0
		for f in g.foes:
			if have.has(str(f.id)):
				n += 1
		var head = Kit.hbox(6)
		head.add_child(Kit.sub_head(str(g.name).to_upper(), RpgUi.color("realm")))
		var gap = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gap)
		head.add_child(Kit.vcenter(Kit.label("%d of %d" % [n, g.foes.size()], 11, Pal.MUTED, true)))
		sh.box.add_child(head)
		var grid = Kit.grid(COLS, 6)
		for f in g.foes:
			grid.add_child(_tile(f, rpg, have.has(str(f.id))))
		sh.box.add_child(grid)
	var close = Kit.button("Close", "ghost", sh.close, "lg")
	if Kit.fingers:
		close.custom_minimum_size.y = 44
	sh.box.add_child(close)
	sh.open()


static func _tile(foe: Dictionary, rpg: Dictionary, is_met: bool) -> Control:
	var id = str(foe.id)
	var entry = {"foe": id}
	var marks = RealmMap.weak_marks(entry, rpg) if is_met else {"known": [], "unknown": 0}
	var col = Pal.LINE
	if is_met and not marks.known.is_empty():
		col = RpgUi.color(str(marks.known[0]))
	var tile = Kit.row(RealmMap.open_foe.bind(entry) if is_met else RealmBestiary._unmet.bind(foe), col, null, 6, 2)
	tile.custom_minimum_size = Vector2(TILE_W, 0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.set_meta("bestiary_foe", id)
	tile.set_meta("bestiary_met", is_met)
	var fv = FoeView.new()
	fv.setup(id, 48.0, false)
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.set_silhouette(not is_met)
	var cc = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(fv)
	tile.add(cc)
	var name_l = Kit.clip(str(foe.name) if is_met else "???", 12, null if is_met else Pal.MUTED, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add(name_l)
	var role_l = Kit.clip(RealmMap.role_word(foe), 11, Pal.MUTED)
	role_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add(role_l)
	if is_met:
		tile.add(RealmMap._weak_icons(marks))
	else:
		var q = Kit.clip("not met yet", 10, Pal.MUTED)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.custom_minimum_size.y = 16
		tile.add(q)
	return tile


static func _unmet(foe: Dictionary) -> void:
	var reg = RpgWorld.region(str(foe.get("region", "")))
	RpgUi.say("Not met yet. It lives in %s." % (str(reg.name) if reg is Dictionary else "the Ironwild"))
