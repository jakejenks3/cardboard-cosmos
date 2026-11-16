class_name RecapSheet
extends RefCounted
## A week or a month in review as one poster (numbers from game/recap.gd):
## the hero, the XP in big pixels, a chip per discipline, three or four number
## tiles, the highlights and, when there are photos, a then / now pair.
##
##   RecapSheet.open("week", Dates.week_key(App.today))
##
## The sheet has arrows to walk back through earlier weeks or months, a
## Week / Month switch, and "Save picture", which renders the poster to a PNG
## in the Pictures folder ("Tiny Titan" inside it) to keep or share.

const POSTER_W = 392


static func _build(kind: String, key: String) -> Dictionary:
	return Recap.build(kind, key, App.state, App.sessions(), App.body(), App.today)


static func open(kind: String, key: String) -> void:
	var sh = Kit.sheet("Recap")
	_fill(sh, kind, key)
	sh.open()


## Open the recap of the period before the current one (last week / last month).
static func open_last(kind: String) -> void:
	open(kind, Recap.shift(kind, Recap.key_of(kind, App.today), -1))


static func _fill(sh: Sheet, kind: String, key: String) -> void:
	if not is_instance_valid(sh):
		return
	Kit.clear(sh.box)
	var r = _build(kind, key)
	var now_key = Recap.key_of(kind, App.today)
	var first_key = Recap.first_key(kind, App.sessions(), App.body(), App.today)

	sh.box.add_child(Kit.segmented([
		{"value": "week", "label": "Week"},
		{"value": "month", "label": "Month"},
	], kind, func(v): RecapSheet._switch_kind(sh, str(v), r), Pal.tab("journey")))

	var nav = Kit.hbox(8)
	var prev = Kit.icon_button("chevron_left", func(): RecapSheet._fill(sh, kind, Recap.shift(kind, key, -1)), "Earlier", 40)
	prev.disabled = key <= first_key
	nav.add_child(prev)
	var mid = Kit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl = Kit.clip(r.title, 16, null, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(tl)
	var sub = Kit.clip(("so far · " if r.running else "") + r.range, 11, Pal.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(sub)
	nav.add_child(mid)
	var next = Kit.icon_button("chevron_right", func(): RecapSheet._fill(sh, kind, Recap.shift(kind, key, 1)), "Later", 40)
	next.disabled = key >= now_key
	nav.add_child(next)
	sh.box.add_child(nav)

	sh.box.add_child(Kit.center(poster(r)))

	var save = Kit.button("Save picture", "secondary", Callable(), "lg", "camera")
	save.pressed.connect(func(): RecapSheet._on_save(r, save))
	sh.box.add_child(Kit.expand(save))


static func _switch_kind(sh: Sheet, kind: String, r: Dictionary) -> void:
	# Keep looking at the same stretch of time: the month of this week, or the
	# last week of this month (the current week when the month is running).
	var key = Recap.key_of(kind, r.from)
	if kind == "week" and r.kind == "month":
		key = Dates.week_key(App.today if r.running else r.to)
	_fill(sh, kind, key)


static func _on_save(r: Dictionary, button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.disabled = true
	var path = await save_picture(r)
	if is_instance_valid(button):
		button.disabled = false
	if path == "":
		Sfx.error()
		App.toast("Could not save the picture.", "bad", "warning")
		return
	Sfx.shutter()
	App.toast("Saved to %s" % path.get_base_dir().get_file().path_join(path.get_file()), "good", "camera")
	if not App.is_test_data():
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------------------
# The poster
# ---------------------------------------------------------------------------

static func _well(child: Control, ring = null, pad: int = 6) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", PixBox.well(pad, pad, ring))
	p.add_child(child)
	return p


static func _tile(value: String, cap: String, color: Color, max_w: float = 104.0) -> Control:
	return JourneyScreen.well_tile(value, cap, color, JourneyScreen.fit_scale([value], max_w, 3))


static func _line(icon: String, color: Color, text: String, detail: String = "") -> Control:
	var row = Kit.hbox(8)
	var ic = PanelContainer.new()
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.add_theme_stylebox_override("panel", PixBox.make(Pal.deep(color), {"ring": color, "lip": 0, "pad_h": 3, "pad_v": 3}))
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.add_child(Icons.rect(icon, 18))
	row.add_child(ic)
	var col = Kit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(Kit.para(text, 13, null, true))
	if detail != "":
		col.add_child(Kit.para(detail, 11, Pal.MUTED))
	row.add_child(col)
	return row


static func _names(list: Array, limit: int = 3) -> String:
	var shown = list.slice(0, limit)
	var out = ", ".join(PackedStringArray(shown))
	if list.size() > limit:
		out += " and %d more" % (list.size() - limit)
	return out


static func _photo(id: String, caption: String) -> Control:
	var box = Kit.vbox(3)
	var tr = TextureRect.new()
	tr.texture = App.photo_texture(id)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(132, 176)
	tr.clip_contents = true
	box.add_child(_well(tr, Pal.LINE, 3))
	var cap = Kit.clip(caption, 11, Pal.MUTED, true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	return box


## The poster for a recap: a fixed-width card that also renders well off screen.
static func poster(r: Dictionary) -> Control:
	var s = App.state
	var settings = App.settings()
	var wu = App.weight_unit()
	var du = App.distance_unit()
	var week = r.kind == "week"
	var card = Kit.card(10, Callable(), 14)
	card.accent(Pal.tab("journey"))
	card.custom_minimum_size = Vector2(POSTER_W, 0)

	# --- masthead --------------------------------------------------------------
	var top = Kit.hbox(6)
	top.add_child(Kit.tag("TINY TITAN", Pal.ACCENT, true, 10))
	top.add_child(Kit.tag(("WEEK" if week else "MONTH") + " IN REVIEW", Pal.tab("journey"), true, 10))
	top.add_child(Kit.spacer())
	top.add_child(Kit.vcenter(Kit.label(r.range, 11, Pal.MUTED, true)))
	card.add(top)
	card.add(Kit.clip(r.title, 22, null, true))
	card.add(Kit.clip(r.headline + ("  (so far)" if r.running else ""), 14, Pal.ACCENT, true))

	if r.empty:
		var rest = Kit.muted_para("Nothing logged in this stretch. Rest counts too." if not r.running else "Nothing logged yet. The first session starts the story.", 13)
		card.add(rest)
		card.add(Kit.center(PixelRect.make(Art.hero_texture(s, App.profile(), App.loadout()), 3.0)))
		return card

	# --- the hero and the XP ------------------------------------------------------
	var hero_row = Kit.hbox(12)
	var hero = PixelRect.make(Art.hero_texture(s, App.profile(), App.loadout(), "flex" if not r.bosses.is_empty() or r.prs.size() >= 3 else "idle", 0, true), 3.0)
	hero_row.add_child(_well(hero, Pal.tab("journey")))
	var xcol = Kit.vbox(6)
	xcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xrow = Kit.hbox(6)
	xrow.add_child(Kit.vcenter(Kit.big_number(Xp.fmt_int(r.xp), Pal.ACCENT, 170, 4)))
	xrow.add_child(Kit.vcenter(Kit.label("XP", 13, Pal.MUTED, true)))
	xcol.add_child(xrow)
	if int(r.prev.xp) > 0 and int(r.xp) != int(r.prev.xp) and not r.running:
		var up = int(r.xp) > int(r.prev.xp)
		xcol.add_child(Kit.tag(("▲ " if up else "▼ ") + Xp.fmt_int(absi(int(r.xp) - int(r.prev.xp))) + (" on last week" if week else " on last month"), Pal.GOOD if up else Pal.PANEL2, up, 11))
	var lv = Kit.hbox(6)
	if int(r.levelTo) > int(r.levelFrom):
		lv.add_child(Kit.pill("star", "LV %d → %d" % [int(r.levelFrom), int(r.levelTo)], Pal.ACCENT))
	else:
		lv.add_child(Kit.pill("star", "LV %d" % int(r.levelTo), Pal.PANEL2, "", Pal.TEXT))
	if int(r.coins) > 0:
		lv.add_child(Kit.pill("coin", "+" + Xp.fmt_int(r.coins), Pal.ACCENT))
	xcol.add_child(lv)
	var chips = Kit.flow(5)
	for d in TT.SESSION_KINDS:
		var n = int(r.by.get(d, 0))
		if n > 0:
			chips.add_child(Kit.icon_chip(d, str(n), Pal.disc(d), "", Color.WHITE))
	xcol.add_child(chips)
	hero_row.add_child(xcol)
	card.add(hero_row)

	# --- number tiles -----------------------------------------------------------------
	var hours = float(r.durationSec) / 3600.0
	var time_text = ("%dH" % int(floor(hours))) if hours >= 1.0 else ("%dM" % TTUtil.jsround(float(r.durationSec) / 60.0))
	var tiles = Kit.grid(3, 6)
	tiles.add_child(_tile(str(int(r.sessions)), "SESSIONS", Pal.TEXT))
	tiles.add_child(_tile(str(int(r.activeDays)), "DAYS", Pal.TEXT))
	tiles.add_child(_tile(time_text, "TRAINED", Pal.TEXT))
	var extra = []
	if float(r.liftKg) > 0.0:
		var big = JourneyScreen.split_unit(Fmt.fmt_big_kg(r.liftKg, wu))
		extra.append([big[0], ("%s LIFTED" % big[1]).to_upper(), Pal.LIFT])
	if int(r.sends) > 0:
		extra.append([str(int(r.sends)), "SENDS", Pal.CLIMB])
	if float(r.runM) > 0.0:
		var run = JourneyScreen.split_unit(Fmt.fmt_distance(r.runM, du))
		extra.append([run[0], ("%s RUN" % run[1]).to_upper(), Pal.RUN])
	if float(r.rideM) > 0.0:
		var ride = JourneyScreen.split_unit(Fmt.fmt_distance(r.rideM, du, 0))
		extra.append([ride[0], ("%s RIDDEN" % ride[1]).to_upper(), Pal.RIDE])
	if float(r.get("miscM", 0.0)) > 0.0 and extra.size() < 4:
		var walked = JourneyScreen.split_unit(Fmt.fmt_distance(r.miscM, du))
		extra.append([walked[0], ("%s WALKED" % walked[1]).to_upper(), Pal.MISC])
	card.add(tiles)
	# One tile per discipline trained, in its colour (up to four across).
	if not extra.is_empty():
		if extra.size() <= 3 and r.topGrade != null:
			for x in extra:
				if x[1] == "SENDS":
					x[1] = "SENDS, TOP %s" % Xp.grade_label(r.topGrade)
		var dtiles = Kit.grid(extra.size(), 6)
		for x in extra:
			dtiles.add_child(_tile(x[0], x[1], x[2], 104.0 if extra.size() <= 3 else 70.0))
		card.add(dtiles)

	# --- highlights ---------------------------------------------------------------------
	var lines = Kit.vbox(7)
	for id in r.bosses:
		var boss = Campaign.boss_by_id(id)
		lines.add_child(_line("skull", Pal.HP, "Defeated %s" % (boss.name if boss != null else "an Echo of Doubt"), boss.epithet if boss != null else ""))
	if not r.bounties.weeks.is_empty():
		if week:
			var rec = r.bounties.weeks[0]
			var mon = Bounty.monster(rec.monster)
			if rec.defeated:
				lines.add_child(_line("coin", Pal.BOUNTY, ("Crushed the %s" if rec.crushed else "Beat the %s") % mon.name, "Weekly bounty, +%d coins" % int(rec.coins)))
			elif not r.running:
				lines.add_child(_line("coin", Pal.PANEL2, "The %s got away" % mon.name, "%s of %s damage" % [Xp.fmt_int(rec.damage), Xp.fmt_int(rec.hp)]))
		elif int(r.bounties.won) > 0:
			lines.add_child(_line("coin", Pal.BOUNTY, "%d of %d weekly bounties won" % [int(r.bounties.won), r.bounties.weeks.size()], "%d crushed" % int(r.bounties.crushed) if int(r.bounties.crushed) > 0 else ""))
	if not r.prs.is_empty():
		var pr_names = []
		for c in r.prs:
			var t = Icons.strip_emoji(str(c.title))
			var val = c.get("val")
			if val != null:
				t += " " + Fmt.fmt_goal_value(val.n, val.unit, settings)
			pr_names.append(t)
		lines.add_child(_line("medal", Pal.GOOD, "%d record%s" % [r.prs.size(), "" if r.prs.size() == 1 else "s"], _names(pr_names, 3)))
	if not r.trophies.is_empty():
		var tn = []
		for id in r.trophies:
			var a = Achievements.by_id(id)
			if a != null:
				tn.append(Icons.strip_emoji(a.name))
		lines.add_child(_line("trophy", Pal.ACCENT2, "%d troph%s" % [r.trophies.size(), "y" if r.trophies.size() == 1 else "ies"], _names(tn, 4)))
	var loot = []
	for id in r.items:
		var it = Items.by_id(id)
		if it != null:
			loot.append(it.name)
	for id in r.pets:
		var pet = Pets.by_id(id)
		if pet != null:
			loot.append("%s the %s" % [pet.name, pet.species])
	if not loot.is_empty():
		lines.add_child(_line("chest", Pal.SECOND, "%d new for the Armory" % loot.size(), _names(loot, 3)))
	if r.best != null and int(r.sessions) >= 2:
		lines.add_child(_line(r.best.discipline, Pal.disc(r.best.discipline), "Best session: %s XP" % Xp.fmt_int(r.best.xp), "%s on %s" % [TT.DISCIPLINE_META[r.best.discipline].name, Dates.format_date(r.best.date, {"weekday": "short", "month": "short", "day": "numeric"})]))
	if r.weight != null and absf(float(r.weight.to) - float(r.weight.from)) >= 0.05:
		var diff = float(r.weight.to) - float(r.weight.from)
		lines.add_child(_line("scale", Pal.RUN, "Weight %s%s" % ["+" if diff > 0.0 else "−", Fmt.fmt_weight(absf(diff), wu)], "%s to %s" % [Fmt.fmt_weight(r.weight.from, wu), Fmt.fmt_weight(r.weight.to, wu)]))
	if lines.get_child_count() > 0:
		card.add(lines)

	# --- then / now -------------------------------------------------------------------------
	if r.photos != null and r.photos.then != null:
		var pair = Kit.hbox(10)
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_child(_photo(r.photos.then.id, Dates.format_date(r.photos.then.date)))
		pair.add_child(Kit.vcenter(Icons.rect("arrow_right", 22)))
		pair.add_child(_photo(r.photos.now.id, Dates.format_date(r.photos.now.date)))
		card.add(pair)
	elif r.photos != null:
		card.add(Kit.center(_photo(r.photos.now.id, Dates.format_date(r.photos.now.date))))

	var foot = Kit.hbox(6)
	foot.add_child(Kit.label(str(App.profile().name), 11, Pal.MUTED, true))
	foot.add_child(Kit.spacer())
	foot.add_child(Kit.label(s.title, 11, Pal.MUTED, true))
	card.add(foot)
	Kit.passthrough(card.box)
	return card


# ---------------------------------------------------------------------------
# Saving the poster as a picture
# ---------------------------------------------------------------------------

## Render the poster of `r` off screen and save it as a PNG. Returns the path,
## or "" when it could not be written.
static func save_picture(r: Dictionary) -> String:
	var host = Kit.overlay_root
	if host == null or not host.is_inside_tree():
		return ""
	var tree = host.get_tree()
	var vp = SubViewport.new()
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(POSTER_W + 32, 600)
	var root = Control.new()
	root.theme = Kit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var p = poster(r)
	p.position = Vector2(16, 16)
	root.add_child(p)
	vp.add_child(root)
	host.add_child(vp)
	await tree.process_frame
	await tree.process_frame
	var need = p.get_combined_minimum_size()
	p.size = Vector2(maxf(need.x, POSTER_W), need.y)
	vp.size = Vector2i(int(p.size.x) + 32, int(p.size.y) + 32)
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return ""
	var dir = App.recap_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path = dir.path_join("recap-%s-%s.png" % [r.kind, r.key])
	if img.save_png(path) != OK:
		return ""
	return path
