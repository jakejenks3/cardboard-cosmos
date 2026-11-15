class_name LogSessionForm
extends RefCounted
## The session form of the Log tab (new or editing): date, duration with quick
## chips, the discipline's own part (lift editor / climbing grades / run & ride
## distance), title & notes, the live XP preview and Save / Delete.
##
## The draft lives here, so the screen can rebuild its controls at any time
## without losing what was typed.

const DURATION_CHIPS = [30, 45, 60, 90]
## Flash is the gold result (a palette colour, so it follows a restyle).
static func flash_color() -> Color:
	return Pal.ACCENT

const FT_PER_M = 3.28084

var screen = null  # LogScreen
var discipline: String = "lift"
var editing = null  # the session being edited, or null
var wu: String = "kg"
var du: String = "km"

var date: String = ""
var dh: String = ""
var dm: String = ""
var ds: String = ""
var title: String = ""
var notes: String = ""
var show_extra: bool = false

var lift = null  # LogLiftEditor
var climbs: Array = []  # [{grade, result, count}]
var climb_result: String = "send"
var more_grades: bool = false
var distance: String = ""
var elev: String = ""

var last_same = null

# Live controls of the current build.
var _xp_box: VBoxContainer = null
var _save_btn: Button = null
var _cardio_template: Control = null
var _chip_row: HBoxContainer = null
var _pace_slot: HBoxContainer = null


func _init(owner_screen, d: String, edit_session = null) -> void:
	screen = owner_screen
	discipline = d
	editing = edit_session
	wu = App.weight_unit()
	du = App.distance_unit()
	date = str(editing.date) if editing != null else App.today
	var dur = int(TTUtil.get_or(editing, "durationSec", 0)) if editing != null else 0
	if dur > 0:
		dh = str(int(floor(dur / 3600.0)))
		dm = str(int(floor((dur % 3600) / 60.0)))
		ds = str(dur % 60)
	if editing != null:
		title = str(TTUtil.get_or(editing, "title", ""))
		notes = str(TTUtil.get_or(editing, "notes", ""))
		show_extra = title != "" or notes != ""
	lift = LogLiftEditor.new(self, editing.id if editing != null else null)
	if editing != null:
		match discipline:
			"lift":
				for e in editing.get("exercises", []):
					lift.exercises.append(LogLiftEditor.draft_from_sets(str(e.name), e.sets, wu))
			"climb":
				for c in editing.get("climbs", []):
					climbs.append(c.duplicate())
			_:
				distance = LogWidgets.trim_num(Fmt.m_to_unit(float(TTUtil.get_or(editing, "distanceM", 0)), du))
				var em = float(TTUtil.get_or(editing, "elevationM", 0))
				if em > 0.0:
					elev = LogWidgets.trim_num(em if du == "km" else em * FT_PER_M)
	# The most recent session of this discipline, for one-tap "same as last time".
	for s in App.sessions():
		if s.discipline != discipline or (editing != null and s.id == editing.id):
			continue
		if last_same == null or s.date > last_same.date or (s.date == last_same.date and s.createdAt > last_same.createdAt):
			last_same = s


# ---------------------------------------------------------------------------
# The draft session
# ---------------------------------------------------------------------------

func duration_sec() -> int:
	return Fmt.parse_duration_input(dh, dm, ds)


func draft() -> Dictionary:
	var s = {"discipline": discipline, "date": date}
	if editing != null:
		s["id"] = editing.id
		s["createdAt"] = editing.createdAt
	s["source"] = str(TTUtil.get_or(editing, "source", "manual")) if editing != null else "manual"
	if editing != null and editing.get("stravaId") != null:
		s["stravaId"] = editing.stravaId
	if title.strip_edges() != "":
		s["title"] = title.strip_edges()
	if notes.strip_edges() != "":
		s["notes"] = notes.strip_edges()
	var sec = duration_sec()
	if sec > 0:
		s["durationSec"] = sec
	if editing != null:
		for k in ["bonusPct", "luckPct"]:
			if editing.get(k) != null:
				s[k] = editing[k]
	match discipline:
		"lift":
			s["exercises"] = lift.session_exercises()
		"climb":
			var cs = []
			for c in climbs:
				if int(c.count) > 0:
					cs.append(c.duplicate())
			s["climbs"] = cs
		_:
			s["distanceM"] = maxf(0.0, Fmt.unit_to_m(LogWidgets.num(distance), du))
			var e = LogWidgets.num(elev)
			s["elevationM"] = maxf(0.0, e if du == "km" else e / FT_PER_M)
	return s


func is_valid(d: Dictionary) -> bool:
	match discipline:
		"lift":
			return not d.exercises.is_empty()
		"climb":
			return not d.climbs.is_empty()
	return float(d.distanceM) > 0.0


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build(parent: Control) -> void:
	var meta = TT.DISCIPLINE_META[discipline]
	var verb = "Edit" if editing != null else "Log"
	parent.add_child(LogWidgets.topbar(discipline, "%s %s" % [verb, str(meta.name).to_lower()], close, remove if editing != null else Callable()))
	if editing != null and str(TTUtil.get_or(editing, "source", "manual")) == "strava" and (discipline == "lift" or discipline == "climb"):
		var hc = Kit.card(6, Callable(), 10)
		hc.accent(Pal.ACCENT)
		var hr = Kit.hbox(8)
		hr.add_child(Icons.rect("info", 20))
		hr.add_child(Kit.clip("Add your %s for full XP" % ("sets" if discipline == "lift" else "climbs"), 14, null, true))
		hc.add(hr)
		hc.tooltip_text = "Imported with duration only."
		parent.add_child(hc)

	# Date + duration on one compact row.
	var top = Kit.hbox(6)
	top.add_child(LogWidgets.date_field(date, _set_date))
	top.add_child(Kit.spacer())
	var dur_col = Kit.vbox(2)
	var dur_row = Kit.hbox(2)
	dur_row.tooltip_text = "Duration h : m : s"
	dur_row.add_child(Kit.vcenter(Icons.rect("stopwatch", 20)))
	dur_row.add_child(Kit.gap(0))
	var eh = LogWidgets.num_input(dh, "0", "dur.h", 34)
	var em = LogWidgets.num_input(dm, "45", "dur.m", 38)
	var es = LogWidgets.num_input(ds, "00", "dur.s", 38)
	eh.tooltip_text = "Hours"
	em.tooltip_text = "Minutes"
	es.tooltip_text = "Seconds"
	eh.text_changed.connect(func(t): _set_dur("h", t))
	em.text_changed.connect(func(t): _set_dur("m", t))
	es.text_changed.connect(func(t): _set_dur("s", t))
	Kit.add(dur_row, [eh, Kit.vcenter(Kit.label(":", 13, Pal.MUTED)), em, Kit.vcenter(Kit.label(":", 13, Pal.MUTED)), es])
	dur_col.add_child(dur_row)
	top.add_child(dur_col)
	parent.add_child(top)

	_pace_slot = null
	# Quick duration picks for gym-style sessions (cardio durations are exact, so typed).
	# One line only: picks that do not fit the width are left out.
	_chip_row = null
	if discipline == "lift" or discipline == "climb":
		_chip_row = Kit.hbox(4)
		parent.add_child(_chip_row)
		_fill_duration_chips()

	match discipline:
		"lift":
			lift.build(parent)
		"climb":
			_build_climb(parent)
		_:
			_build_cardio(parent, eh, es)

	# Title & notes (folded away like the web's <details>)
	var fold = LogWidgets.mini_chip(("▾ " if show_extra else "+ ") + "Title & notes", show_extra, _toggle_extra)
	fold.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(fold)
	if show_extra:
		var te = Kit.input(title, "Title (optional)")
		te.set_meta(LogWidgets.FKEY, "title")
		te.tooltip_text = "Title"
		te.custom_minimum_size = Vector2(48, LogWidgets.ROW_H)
		LogWidgets._slim_edit(te, 10)
		te.text_changed.connect(func(t): title = t)
		parent.add_child(te)
		parent.add_child(LogWidgets.text_area(notes, "Notes: how did it go?", "notes", func(t): notes = t, 2))

	# XP preview + save, one block
	var fb = LogWidgets.finish_block("Save changes" if editing != null else "Finish session", close, save)
	_xp_box = fb.xp
	_save_btn = fb.save
	parent.add_child(fb.card)
	parent.add_child(Kit.gap(4))
	refresh()


## Update everything that depends on the draft without rebuilding (keeps focus while typing).
func refresh() -> void:
	var d = draft()
	var valid = is_valid(d)
	if is_instance_valid(_save_btn):
		_save_btn.disabled = not valid
		_save_btn.tooltip_text = "" if valid else _invalid_hint()
	if is_instance_valid(_cardio_template):
		_cardio_template.visible = distance.strip_edges() == ""
	_fill_duration_chips()
	if not is_instance_valid(_xp_box):
		return
	var st = Xp.session_stats(d)
	var base = Xp.base_session_xp(d)
	var bonus = float(TTUtil.get_or(editing, "bonusPct", 0.0)) if editing != null else float(App.perks.xp[discipline])
	var est = TTUtil.jsround(float(base.xp) * (1.0 + bonus))
	var side = "XP for this session, incl. +%d%% gear bonus" % TTUtil.jsround(bonus * 100.0) if bonus > 0.0 else "XP for this session"
	var sub = ""
	match discipline:
		"lift":
			sub = "%s · %d reps · %d sets" % [Fmt.fmt_big_kg(float(st.volumeKg), wu), int(st.reps) + int(st.bwReps), int(st.sets)]
		"climb":
			sub = "%d sends" % int(st.sends)
			if st.maxGradeSent != null:
				sub += " · max " + Xp.grade_label(st.maxGradeSent)
			side += "\n%d sends · %d flashes · %d attempts" % [int(st.sends), int(st.flashes), int(st.attempts)]
		"run", "ride":
			sub = Fmt.fmt_distance(float(d.distanceM), du)
	if not valid:
		sub = _invalid_hint()
	_fill_pace(st)
	LogWidgets.fill_xp_preview(_xp_box, est, Pal.disc(discipline), side, sub)


func _invalid_hint() -> String:
	match discipline:
		"lift":
			return "Add a set with reps"
		"climb":
			return "Tap a grade to add a climb"
	return "Enter a distance"


func _fill_duration_chips() -> void:
	if _chip_row == null or not is_instance_valid(_chip_row):
		return
	Kit.clear(_chip_row)
	var last_min = 0
	if last_same != null and last_same.get("durationSec") != null and int(last_same.durationSec) > 0:
		last_min = TTUtil.jsround(float(last_same.durationSec) / 60.0)
	var mins = []
	if last_min > 0:
		mins.append(last_min)
	for m in DURATION_CHIPS:
		if not mins.has(m):
			mins.append(m)
	var cur = duration_sec()
	var cur_min = TTUtil.jsround(cur / 60.0) if cur > 0 else -1
	var avail = 400.0
	if is_instance_valid(screen) and screen.size.x > 100.0:
		avail = screen.size.x
	var used = 0.0
	for m in mins:
		var label = Fmt.fmt_duration_short(m * 60)
		if m == last_min:
			label += " · last"
		var w = LogWidgets.mini_chip_width(label, 8) + 4
		if used + w > avail:
			continue
		used += w
		var chip = LogWidgets.mini_chip(label, m == cur_min, _quick_duration.bind(m), Pal.disc(discipline), 8)
		chip.tooltip_text = "Set the duration to %s" % Fmt.fmt_duration_short(m * 60)
		_chip_row.add_child(chip)


func _quick_duration(m: int) -> void:
	Sfx.tick()
	set_duration(m * 60)
	screen.rebuild()


func set_duration(sec: int) -> void:
	dh = str(int(floor(sec / 3600.0))) if sec >= 3600 else ""
	dm = str(int(floor((sec % 3600) / 60.0)))
	ds = str(sec % 60) if sec % 60 != 0 else ""


func _set_dur(part: String, t: String) -> void:
	match part:
		"h":
			dh = t
		"m":
			dm = t
		_:
			ds = t
	refresh()


func _set_date(key: String) -> void:
	date = key
	refresh()


func _toggle_extra() -> void:
	show_extra = not show_extra
	screen.rebuild()


## Called by the lift editor after every change.
func on_draft_changed(rebuild_all: bool) -> void:
	if rebuild_all:
		screen.rebuild()
	else:
		refresh()


# ---------------------------------------------------------------------------
# Climbing
# ---------------------------------------------------------------------------

## The difficulty ramp: green (VB) through yellow and orange to red and purple.
## Fixed art colours, the same in every theme.
static func grade_hue(g: int) -> Color:
	if g > 10:
		# Beyond V10: deepening purples.
		return _hsl((300.0 - (g - 11) * 8.0) / 360.0, 0.5, 0.46 - (g - 11) * 0.025)
	var t = clampf((g + 1) / 11.0, 0.0, 1.0)
	return _hsl((135.0 - t * 135.0) / 360.0, 0.64, 0.44)


static func _hsl(h: float, s: float, l: float) -> Color:
	var v = l + s * minf(l, 1.0 - l)
	var sv = 0.0 if v == 0.0 else 2.0 * (1.0 - l / v)
	return Color.from_hsv(h, sv, v)


static func result_label(r: String) -> String:
	match r:
		"flash":
			return "Flash"
		"send":
			return "Send"
	return "Attempt"


static func result_color(r: String) -> Color:
	match r:
		"flash":
			return flash_color()
		"send":
			return Pal.CLIMB
	return Pal.SECOND


static func result_icon(r: String) -> String:
	match r:
		"flash":
			return "bolt"
		"send":
			return "check"
	return "repeat"


func _last_climb():
	if last_same == null or last_same.discipline != "climb":
		return null
	for c in last_same.get("climbs", []):
		if int(c.count) > 0:
			return last_same
	return null


func _build_climb(parent: Control) -> void:
	var lc = _last_climb()
	if climbs.is_empty() and lc != null:
		var st = Xp.session_stats(lc)
		var text = "%d sends" % int(st.sends)
		if st.maxGradeSent != null:
			text += " · max " + Xp.grade_label(st.maxGradeSent)
		if int(st.attempts) > 0:
			text += " · %d attempts" % int(st.attempts)
		var tile = LogWidgets.template(lc.date, text, _repeat_climb.bind(lc), "climb", "Same as last · ")
		parent.add_child(tile)
	# Flash / send / attempt: three bright toggles.
	var toggles = Kit.hbox(6)
	for r in ["flash", "send", "attempt"]:
		var t = LogWidgets.toggle(result_label(r), result_icon(r), climb_result == r, result_color(r), _set_result.bind(r))
		t.tooltip_text = "Grades you tap now count as a %s" % r
		toggles.add_child(t)
	parent.add_child(toggles)
	# The grade keys, coloured along the difficulty ramp.
	var grid = Kit.grid(6, 5)
	var top = Xp.MAX_V_GRADE if more_grades else 10
	for g in range(-1, top + 1):
		grid.add_child(_grade_key(g))
	var more = Kit.button("Less" if more_grades else "More…", "ghost", _toggle_more, "sm")
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.custom_minimum_size.y = 40
	grid.add_child(more)
	parent.add_child(grid)

	if not climbs.is_empty():
		var idx = []
		for k in range(climbs.size()):
			idx.append(k)
		TTUtil.stable_sort(idx, func(a, b): return _climb_before(climbs[a], climbs[b]))
		var flow = Kit.flow(6)
		for k in idx:
			flow.add_child(_climb_chip(k))
		parent.add_child(flow)


## One grade as a chunky key in its ramp colour.
func _grade_key(g: int) -> Button:
	var hue = grade_hue(g)
	var b = Button.new()
	b.text = Xp.grade_label(g)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 40)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.tooltip_text = "Add one %s %s" % [Xp.grade_label(g), climb_result]
	var looks = PixBox.button_set(hue, hue.darkened(0.45), 2, 4, 2, hue.lightened(0.3))
	for k in looks:
		b.add_theme_stylebox_override(k, looks[k])
	b.add_theme_stylebox_override("hover_pressed", looks["pressed"])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_font_override("font", Kit.font_bold())
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(add_climb.bind(g))
	Kit.juice(b)
	return b


## A logged climb as a chip: grade in its colour, result icon, ×count, − / +.
func _climb_chip(k: int) -> Control:
	var cl = climbs[k]
	var hue = grade_hue(int(cl.grade))
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL, {"ring": hue, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 6, "pad_v": 3}))
	p.tooltip_text = "%s %s × %d" % [Xp.grade_label(cl.grade), result_label(cl.result).to_lower(), int(cl.count)]
	var h = Kit.hbox(5)
	var g = LogWidgets.badge(Xp.grade_label(cl.grade), hue, 13)
	LogWidgets.on_face(g.get_child(0), 3)
	h.add_child(g)
	h.add_child(Kit.vcenter(Icons.rect(result_icon(cl.result), 16, result_color(cl.result))))
	h.add_child(Kit.vcenter(PixelFont.rect("x%d" % int(cl.count), 2, Pal.TEXT)))
	h.add_child(LogWidgets.round_btn("−", bump_climb.bind(k, -1), "Minus one"))
	h.add_child(LogWidgets.round_btn("+", bump_climb.bind(k, 1), "Plus one"))
	p.add_child(h)
	return p


static func _climb_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.grade) != int(b.grade):
		return int(a.grade) > int(b.grade)
	return str(a.result) < str(b.result)


func add_climb(grade: int) -> void:
	Sfx.tick()
	for c in climbs:
		if int(c.grade) == grade and c.result == climb_result:
			c.count = int(c.count) + 1
			screen.rebuild()
			return
	climbs.append({"grade": grade, "result": climb_result, "count": 1})
	screen.rebuild()


func bump_climb(k: int, delta: int) -> void:
	if k >= climbs.size():
		return
	Sfx.tick()
	climbs[k].count = maxi(0, int(climbs[k].count) + delta)
	climbs = climbs.filter(func(c): return int(c.count) > 0)
	screen.rebuild()


func _repeat_climb(lc: Dictionary) -> void:
	Sfx.tap()
	climbs = []
	for c in lc.climbs:
		if int(c.count) > 0:
			climbs.append(c.duplicate())
	screen.rebuild()


func _set_result(v) -> void:
	climb_result = str(v)
	screen.rebuild()


func _toggle_more() -> void:
	more_grades = not more_grades
	screen.rebuild()


# ---------------------------------------------------------------------------
# Run / ride
# ---------------------------------------------------------------------------

func _last_cardio():
	if last_same != null and (last_same.discipline == "run" or last_same.discipline == "ride") and float(TTUtil.get_or(last_same, "distanceM", 0)) > 0.0:
		return last_same
	return null


func _elev_text(m: float) -> String:
	return LogWidgets.trim_num(m if du == "km" else m * FT_PER_M) if m > 0.0 else ""


func _build_cardio(parent: Control, first_dur: LineEdit, last_dur: LineEdit) -> void:
	var lc = _last_cardio()
	_cardio_template = null
	if editing == null and lc != null:
		var text = Fmt.fmt_distance(float(lc.distanceM), du)
		if lc.get("durationSec") != null and int(lc.durationSec) > 0:
			text += " · " + Fmt.fmt_duration(float(lc.durationSec))
		_cardio_template = LogWidgets.template(lc.date, text, _use_last_cardio.bind(lc), discipline, "Same as last · ")
		_cardio_template.visible = distance.strip_edges() == ""
		parent.add_child(_cardio_template)
	var col = Pal.disc(discipline)
	var c = Kit.card(6, Callable(), 12)
	c.accent(col)
	var row = Kit.hbox(10)
	# Distance: the big number.
	var dist = Kit.vbox(4)
	dist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dist.size_flags_stretch_ratio = 1.6
	dist.add_child(Kit.label("Distance", 12, Pal.MUTED, true))
	var drow = Kit.hbox(6)
	var ph = LogWidgets.trim_num(Fmt.m_to_unit(float(lc.distanceM), du)) if lc != null else "0.0"
	var de = LogWidgets.big_input(distance, ph, "distance", 0, 28)
	de.tooltip_text = "Distance (%s)" % du
	de.text_changed.connect(func(t):
		distance = t
		refresh())
	drow.add_child(de)
	drow.add_child(LogWidgets.unit_chip(du))
	dist.add_child(drow)
	row.add_child(dist)
	# Elevation: secondary.
	var ev = Kit.vbox(4)
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.add_child(Kit.label("Elevation", 12, Pal.MUTED, true))
	var erow = Kit.hbox(6)
	var ee = LogWidgets.big_input(elev, "0", "elev", 0, 18)
	ee.tooltip_text = "Elevation gain (%s)" % ("m" if du == "km" else "ft")
	ee.text_changed.connect(func(t):
		elev = t
		refresh())
	erow.add_child(ee)
	erow.add_child(LogWidgets.unit_chip("m" if du == "km" else "ft"))
	ev.add_child(erow)
	row.add_child(ev)
	c.add(row)
	# Live pace / speed.
	_pace_slot = Kit.hbox(6)
	c.add(_pace_slot)
	parent.add_child(c)
	# Keyboard order: distance → h → m → s → elevation.
	var link_focus = func():
		if not (is_instance_valid(de) and de.is_inside_tree()):
			return
		de.focus_next = de.get_path_to(first_dur)
		first_dur.focus_previous = first_dur.get_path_to(de)
		last_dur.focus_next = last_dur.get_path_to(ee)
		ee.focus_previous = ee.get_path_to(last_dur)
		if editing == null and distance == "" and de.get_viewport().gui_get_focus_owner() == null:
			de.grab_focus()
	link_focus.call_deferred()


## The live pace (run) or speed (ride) chip under the distance.
func _fill_pace(st: Dictionary) -> void:
	if _pace_slot == null or not is_instance_valid(_pace_slot):
		return
	Kit.clear(_pace_slot)
	var text = ""
	var tip = ""
	if discipline == "run" and st.get("paceSecPerKm") != null:
		text = Fmt.fmt_pace(float(st.paceSecPerKm), du)
		tip = "Average pace"
	elif discipline == "ride" and st.get("speedKmh") != null:
		text = Fmt.fmt_speed(float(st.speedKmh), du)
		tip = "Average speed"
	if text == "":
		_pace_slot.add_child(Kit.label("Add a time for %s" % ("pace" if discipline == "run" else "speed"), 12, Pal.MUTED))
		return
	var chip = PanelContainer.new()
	chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col = Pal.disc(discipline)
	chip.add_theme_stylebox_override("panel", PixBox.make(col, {"lip": 1, "lip_color": col.darkened(0.45), "pad_h": 8, "pad_v": 2}))
	chip.tooltip_text = tip
	var h = Kit.hbox(6)
	h.add_child(Kit.vcenter(Icons.rect("stopwatch", 16)))
	h.add_child(LogWidgets.on_face(Kit.label(text, 14, null, true)))
	chip.add_child(h)
	_pace_slot.add_child(chip)


func _use_last_cardio(lc: Dictionary) -> void:
	Sfx.tap()
	distance = LogWidgets.trim_num(Fmt.m_to_unit(float(lc.distanceM), du))
	elev = _elev_text(float(TTUtil.get_or(lc, "elevationM", 0)))
	if lc.get("durationSec") != null and int(lc.durationSec) > 0:
		set_duration(int(lc.durationSec))
	screen.rebuild()


# ---------------------------------------------------------------------------
# Save / delete / leave
# ---------------------------------------------------------------------------

func close() -> void:
	App.open_log(null)
	App.go("journey" if editing != null else "home")


func save() -> void:
	var d = draft()
	if not is_valid(d):
		Sfx.error()
		App.toast(_invalid_hint(), "bad", "warning")
		return
	LogWidgets.celebrate(_save_btn, _xp_box if editing == null else null)
	if editing != null:
		App.update_session(d)
		App.toast("Session updated", "good", "edit")
		close()
		return
	d.erase("id")
	d.erase("createdAt")
	d.erase("bonusPct")
	d.erase("luckPct")
	var session = App.build_session(d)
	App.commit_sessions([session], "Session logged!")
	App.open_log(null)
	App.go("home")


func remove() -> void:
	if editing == null:
		return
	var id = editing.id
	Kit.confirm("Delete this session?", "Your levels and unlocks will be recalculated.", "Delete", func():
		App.delete_session(id)
		App.toast("Session deleted", "info", "trash")
		App.open_log(null)
		App.go("journey"))
