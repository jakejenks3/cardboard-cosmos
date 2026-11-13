class_name LogSessionForm
extends RefCounted
## The session form of the Log tab (new or editing): date, duration with quick
## chips, the discipline's own part (lift editor / climbing grades / run & ride
## distance), title & notes, the live XP preview and Save / Delete.
##
## The draft lives here, so the screen can rebuild its controls at any time
## without losing what was typed.

const DURATION_CHIPS = [30, 45, 60, 90]
const FLASH_COLOR = Color("c98500")
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
var _chip_row: HFlowContainer = null


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
		var hc = Kit.card(6, Callable(), 12)
		hc.add(Kit.muted_para("Imported with duration only. Add your %s below to earn full XP for it." % ("sets" if discipline == "lift" else "climbs"), 13))
		parent.add_child(hc)

	# Date + duration
	var top = Kit.hbox(12)
	var df = LogWidgets.date_field(date, _set_date)
	df.size_flags_stretch_ratio = 1.15
	top.add_child(df)
	var dur_row = Kit.hbox(4)
	var eh = LogWidgets.num_input(dh, "0", "dur.h")
	var em = LogWidgets.num_input(dm, "45", "dur.m")
	var es = LogWidgets.num_input(ds, "00", "dur.s")
	eh.tooltip_text = "Hours"
	em.tooltip_text = "Minutes"
	es.tooltip_text = "Seconds"
	eh.text_changed.connect(func(t): _set_dur("h", t))
	em.text_changed.connect(func(t): _set_dur("m", t))
	es.text_changed.connect(func(t): _set_dur("s", t))
	Kit.add(dur_row, [eh, em, es])
	top.add_child(Kit.field("Duration (h : m : s)", dur_row))
	parent.add_child(top)

	# Quick duration picks for gym-style sessions (cardio durations are exact, so typed).
	_chip_row = null
	if discipline == "lift" or discipline == "climb":
		_chip_row = Kit.flow(6)
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
	var fold = Kit.link(("▾ " if show_extra else "▸ ") + "Title & notes", _toggle_extra, 14)
	fold.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(fold)
	if show_extra:
		var te = Kit.input(title, "Optional")
		te.set_meta(LogWidgets.FKEY, "title")
		te.text_changed.connect(func(t): title = t)
		parent.add_child(Kit.field("Title", te))
		parent.add_child(Kit.field("Notes", LogWidgets.text_area(notes, "How did it go?", "notes", func(t): notes = t)))

	# XP preview
	var xc = Kit.card(6, Callable(), 12)
	_xp_box = Kit.vbox(4)
	xc.add(_xp_box)
	parent.add_child(xc)

	var acts = LogWidgets.actions("Save changes" if editing != null else "Finish session ✓", close, save)
	_save_btn = acts[1]
	parent.add_child(acts[0])
	parent.add_child(Kit.gap(8))
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
	var side = "incl. +%d%% gear bonus" % TTUtil.jsround(bonus * 100.0) if bonus > 0.0 else ""
	var sub = ""
	match discipline:
		"lift":
			sub = "%s · %d reps · %d sets" % [Fmt.fmt_big_kg(float(st.volumeKg), wu), int(st.reps) + int(st.bwReps), int(st.sets)]
		"climb":
			sub = "%d sends · %d flashes · %d attempts" % [int(st.sends), int(st.flashes), int(st.attempts)]
			if st.maxGradeSent != null:
				sub += " · max " + Xp.grade_label(st.maxGradeSent)
		"run":
			sub = "Pace " + Fmt.fmt_pace(float(st.paceSecPerKm), du) if st.paceSecPerKm != null else "Add a duration for pace"
		"ride":
			sub = "Avg " + Fmt.fmt_speed(float(st.speedKmh), du) if st.speedKmh != null else "Add a duration for speed"
	if not valid:
		sub = _invalid_hint()
	LogWidgets.fill_xp_preview(_xp_box, est, Pal.disc(discipline), side, sub)


func _invalid_hint() -> String:
	match discipline:
		"lift":
			return "Add an exercise with at least one set with reps to save."
		"climb":
			return "Tap a grade to add a climb to save."
	return "Enter a distance to save."


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
	_chip_row.add_child(Kit.vcenter(Kit.muted("Quick:", 12)))
	for m in mins:
		var label = Fmt.fmt_duration_short(m * 60)
		if m == last_min:
			label += " · last"
		_chip_row.add_child(Kit.chip(label, m == cur_min, _quick_duration.bind(m), Pal.disc(discipline), 12))


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

static func grade_hue(g: int) -> Color:
	var t = clampf((g + 1) / 14.0, 0.0, 1.0)
	return _hsl((150.0 - t * 150.0) / 360.0, 0.6, 0.38)


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
		var text = "Same as last session: %d sends" % int(st.sends)
		if st.maxGradeSent != null:
			text += ", max " + Xp.grade_label(st.maxGradeSent)
		if int(st.attempts) > 0:
			text += ", %d attempts" % int(st.attempts)
		parent.add_child(LogWidgets.template(lc.date, text, _repeat_climb.bind(lc)))
	var col = FLASH_COLOR if climb_result == "flash" else (Pal.CLIMB if climb_result == "send" else Pal.LINE)
	parent.add_child(Kit.segmented([
		{"value": "flash", "label": "Flash"},
		{"value": "send", "label": "Send"},
		{"value": "attempt", "label": "Attempt"},
	], climb_result, _set_result, col))
	parent.add_child(Kit.muted("Tap a grade to add one %s." % climb_result, 13))
	var grid = Kit.grid(6, 6)
	var top = Xp.MAX_V_GRADE if more_grades else 10
	for g in range(-1, top + 1):
		var b = Button.new()
		b.text = Xp.grade_label(g)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		var hue = grade_hue(g)
		b.add_theme_stylebox_override("normal", Kit.sbox(hue, 10, hue.lightened(0.25), 1, 4, 6))
		b.add_theme_stylebox_override("hover", Kit.sbox(hue.lightened(0.1), 10, hue.lightened(0.35), 1, 4, 6))
		b.add_theme_stylebox_override("pressed", Kit.sbox(hue.darkened(0.15), 10, Pal.ACCENT, 2, 4, 6))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(add_climb.bind(g))
		grid.add_child(b)
	var more = Kit.button("Less" if more_grades else "More…", "ghost", _toggle_more, "sm")
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(more)
	parent.add_child(grid)

	if not climbs.is_empty():
		var idx = []
		for k in range(climbs.size()):
			idx.append(k)
		TTUtil.stable_sort(idx, func(a, b): return _climb_before(climbs[a], climbs[b]))
		var c = Kit.card(6, Callable(), 12)
		for k in idx:
			var cl = climbs[k]
			var row = Kit.hbox(10)
			var gt = Kit.tag(Xp.grade_label(cl.grade), grade_hue(int(cl.grade)), false, 14)
			gt.custom_minimum_size = Vector2(48, 0)
			row.add_child(gt)
			var rcol = FLASH_COLOR if cl.result == "flash" else (Pal.CLIMB if cl.result == "send" else Pal.MUTED)
			row.add_child(Kit.vcenter(Icons.rect(result_icon(cl.result), 18, rcol)))
			row.add_child(Kit.vcenter(Kit.expand(Kit.label(result_label(cl.result), 15))))
			row.add_child(LogWidgets.round_btn("−", bump_climb.bind(k, -1), "Minus one"))
			var n = Kit.label(str(int(cl.count)), 17, null, true)
			n.custom_minimum_size = Vector2(26, 0)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(Kit.vcenter(n))
			row.add_child(LogWidgets.round_btn("+", bump_climb.bind(k, 1), "Plus one"))
			c.add(row)
		parent.add_child(c)


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
		var text = "Same as last %s: %s" % [discipline, Fmt.fmt_distance(float(lc.distanceM), du)]
		if lc.get("durationSec") != null and int(lc.durationSec) > 0:
			text += " · " + Fmt.fmt_duration(float(lc.durationSec))
		_cardio_template = LogWidgets.template(lc.date, text, _use_last_cardio.bind(lc))
		_cardio_template.visible = distance.strip_edges() == ""
		parent.add_child(_cardio_template)
	var row = Kit.hbox(12)
	var ph = LogWidgets.trim_num(Fmt.m_to_unit(float(lc.distanceM), du)) if lc != null else "0.0"
	var de = LogWidgets.num_input(distance, ph, "distance")
	de.text_changed.connect(func(t):
		distance = t
		refresh())
	row.add_child(Kit.field("Distance (%s)" % du, de))
	var ee = LogWidgets.num_input(elev, "0", "elev")
	ee.text_changed.connect(func(t):
		elev = t
		refresh())
	row.add_child(Kit.field("Elevation gain (%s)" % ("m" if du == "km" else "ft"), ee))
	parent.add_child(row)
	# Keyboard order: distance → h → m → s → elevation.
	var link_focus = func():
		if not (is_instance_valid(de) and de.is_inside_tree()):
			return
		de.focus_next = de.get_path_to(first_dur)
		first_dur.focus_previous = first_dur.get_path_to(de)
		last_dur.focus_next = last_dur.get_path_to(ee)
		ee.focus_previous = ee.get_path_to(last_dur)
		if editing == null and distance == "" and screen.focus_key == "":
			de.grab_focus()
	link_focus.call_deferred()


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
