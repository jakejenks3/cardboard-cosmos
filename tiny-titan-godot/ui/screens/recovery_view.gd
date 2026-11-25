class_name RecoveryView
extends RefCounted
## The muscle map: the hero with every body part tinted by how recently it was
## worked (game/recovery.gd). On the Today section: a flat row (small map, the
## parts still recovering), or with a training focus a narrow tile beside the
## weekly sets (`tile`, the parts by name in `warm_words` under both). A sheet
## with the big map and every part.

## Heat colours, for the chips and the legend (amber = some, red = worked hard today).
const WARM = Color("ffb21f")
const HOT = Color("ff3a1c")


static func heat_color(h: float) -> Color:
	return WARM.lerp(HOT, clampf(h, 0.0, 1.0))


## The Today section's row: the small map and the parts still recovering.
static func row() -> Control:
	var h = Recovery.heat(App.sessions(), App.today)
	var warm = Recovery.warm(h, 0.15)
	var c = Kit.row(RecoveryView.open, Pal.LINE, null, 8, 0)
	c.tooltip_text = "Muscle map: what is still recovering"
	var r = Kit.hbox(10)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic = PixelRect.make(Art.muscle_texture(App.state, App.profile(), h), 1.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(pic)
	var v = Kit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("MUSCLE MAP", 11, WARM, true))
	if warm.is_empty():
		v.add_child(Kit.clip("Everything is fresh", 13, Pal.TEXT, true))
	else:
		var chips = Kit.flow(4)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for w in warm.slice(0, 5):
			chips.add_child(Kit.tag(str(w.name), heat_color(float(w.heat)), true, 11))
		v.add_child(chips)
		v.add_child(Kit.clip("Recovering; the rest is fresh", 11, Pal.MUTED))
	r.add_child(v)
	r.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(r)
	return c


## The narrow tile beside the weekly sets (a training focus): the small map and
## how many parts are still recovering. A tap opens the sheet.
static func tile() -> Control:
	var h = Recovery.heat(App.sessions(), App.today)
	var warm = Recovery.warm(h, 0.15)
	var c = Kit.row(RecoveryView.open, Pal.LINE, null, 8, 4)
	var pic = PixelRect.make(Art.muscle_texture(App.state, App.profile(), h), 1.0)
	c.size_flags_horizontal = Control.SIZE_FILL
	c.custom_minimum_size.x = maxf(92.0, pic.custom_minimum_size.x + 20.0)
	c.tooltip_text = "Muscle map: " + (warm_words() if not warm.is_empty() else "everything is fresh")
	c.set_meta("muscle_tile", true)
	# (as tall as the sets beside it: the map in the middle)
	c.box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t = Kit.label("MUSCLE MAP", 11, WARM, true)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add(t)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add(pic)
	var n = Kit.label("%d recovering" % warm.size() if not warm.is_empty() else "All fresh", 11, WARM if not warm.is_empty() else Pal.GOOD, true)
	n.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add(n)
	return c


## The parts still recovering by name, the warmest first ("back, shoulders,
## biceps"), or "" when everything is fresh.
static func warm_words() -> String:
	var warm = Recovery.warm(Recovery.heat(App.sessions(), App.today), 0.15)
	var names = []
	for w in warm:
		names.append(str(w.name).to_lower())
	return ", ".join(PackedStringArray(names))


## The sheet: the big map, the legend, every part with when it was worked.
static func open() -> void:
	Sfx.tick()
	var h = Recovery.heat(App.sessions(), App.today)
	var sh = Kit.sheet("Muscle map")
	var top = Kit.hbox(14)
	var pic = PixelRect.make(Art.muscle_texture(App.state, App.profile(), h), 3.0)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pic)
	var key = Kit.vbox(6)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.add_child(Kit.para("Muscles glow while they recover: red is worked hard today, amber is nearly ready. Big muscles (chest, back, legs) take about three days, small ones two.", 13, Pal.TEXT))
	for pair in [[1.0, "Worked hard today"], [0.5, "Recovering"], [0.15, "Nearly ready"]]:
		var lr = Kit.hbox(6)
		lr.add_child(Kit.vcenter(Kit.tag("  ", heat_color(float(pair[0])), true, 11)))
		lr.add_child(Kit.vcenter(Kit.label(str(pair[1]), 12, Pal.MUTED, true)))
		key.add_child(lr)
	top.add_child(key)
	sh.box.add_child(top)
	for p in Recovery.PARTS:
		var e = h[p]
		var row = Kit.hbox(8)
		var n = Kit.label(str(Recovery.NAMES[p]), 14, null, true)
		n.custom_minimum_size = Vector2(110, 0)
		row.add_child(Kit.vcenter(n))
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = float(e.heat)
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill = StyleBoxFlat.new()
		fill.bg_color = heat_color(float(e.heat))
		bar.add_theme_stylebox_override("fill", fill)
		var bg = StyleBoxFlat.new()
		bg.bg_color = Pal.PANEL2
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		var said = "fresh"
		if int(e.days) >= 0 and float(e.heat) > 0.02:
			var left = int(ceil(Recovery.days_to_recover(p) - int(e.days)))
			said = "%s, ready %s" % [Recovery.when(int(e.days)), "tomorrow" if left <= 1 else "in %d days" % left]
		elif int(e.days) >= 0:
			said = "fresh (%s)" % Recovery.when(int(e.days))
		var s = Kit.label(said, 12, Pal.MUTED)
		s.custom_minimum_size = Vector2(150, 0)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(Kit.vcenter(s))
		sh.box.add_child(row)
	var ok = Kit.button("Got it", "primary", sh.close, "lg")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.box.add_child(ok)
	sh.open()
