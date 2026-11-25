class_name LogSessionForm
extends RefCounted
## The session form of the Log tab (new or editing): date, duration with quick
## chips, the discipline's own part (lift editor / climbing grades / run & ride
## distance), title & notes, the live XP preview and Save / Delete. A misc
## activity (game/misc.gd, discipline "misc" plus `kind`) uses the distance part
## and, when its kind carries a weight, a row for it (the vest of a vest walk).
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
var climbs: Array = []  # [{grade, result, count}] (+ style "rope", yds "5.10a" for routes)
var climb_result: String = "send"
var more_grades: bool = false
var scale: String = "v"  # which grade keys show: "v" boulders, "yds" routes (5.xx)
var hangs: Array = []  # [{edgeMm, sec, arms, addKg, count}]
var show_hang: bool = false
var hang_edge: int = 20
var hang_sec: int = 10
var hang_arms: int = 2
var hang_add: String = ""  # added weight in the player's unit ("" = none, "-10" = assisted)
const HANG_EDGES = [10, 15, 20, 25, 30, 0]
const HANG_SECS = [5, 7, 10, 15, 20]
var distance: String = ""
var elev: String = ""
## A run's best splits as typed, {RunSplits id: text} (game/run_splits.gd).
var splits: Dictionary = {}
## Misc activities: which one, and the weight carried in the player's unit ("" = none).
var kind: String = ""
var carried: String = ""
const LOAD_PICKS = {"lb": [10, 20, 30, 40], "kg": [5, 10, 15, 20]}

var last_same = null
## The form came back from the kept draft (the app was closed mid-workout).
var restored: bool = false
var _draft_text: String = ""
## The player said the lifts still as planned were done as shown.
var _planned_ok: bool = false

# Live controls of the current build.
var _xp_box: VBoxContainer = null
var _save_btn: Button = null
var _cardio_template: Control = null
var _chip_row: HBoxContainer = null
var _pace_slot: HBoxContainer = null
var _splits_card = null
var _splits_box: VBoxContainer = null
var _splits_ids: Array = []
var _split_echo: Dictionary = {}
var _whole_line: Label = null
var _split_note: Label = null


func _init(owner_screen, d: String, edit_session = null, misc_kind: String = "") -> void:
	screen = owner_screen
	discipline = d
	editing = edit_session
	if d == TT.MISC:
		kind = Misc.kind_of(editing) if editing != null else misc_kind
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
					if Xp.is_route(c):
						scale = "yds"
				for h in editing.get("hangs", []):
					hangs.append(h.duplicate())
				show_hang = not hangs.is_empty()
			_:
				distance = LogWidgets.trim_num(Fmt.m_to_unit(float(TTUtil.get_or(editing, "distanceM", 0)), du))
				var em = float(TTUtil.get_or(editing, "elevationM", 0))
				if em > 0.0:
					elev = LogWidgets.trim_num(em if du == "km" else em * FT_PER_M)
				var lk = Misc.load_kg(editing) if d == TT.MISC else 0.0
				if lk > 0.0:
					carried = LogWidgets.trim_num(Fmt.kg_to_unit(lk, wu), 1)
				if d == "run" and editing.get("splits") is Dictionary:
					for id in editing.splits:
						var sec = editing.splits[id]
						if RunSplits.by_id(str(id)) != null and (sec is int or sec is float) and float(sec) > 0.0:
							splits[str(id)] = RunSplits.fmt_time(sec)
	_take_draft()
	# The most recent session of this discipline (and kind), for one-tap "same as last time".
	for s in App.sessions():
		if s.discipline != discipline or (editing != null and s.id == editing.id):
			continue
		if discipline == TT.MISC and Misc.kind_of(s) != kind:
			continue
		if last_same == null or s.date > last_same.date or (s.date == last_same.date and s.createdAt > last_same.createdAt):
			last_same = s


# ---------------------------------------------------------------------------
# The kept draft: a new lift or climb is written to a small file as it is
# entered (App.draft_store), so it is still there when a phone closed the app
# between sets. Saving the session, or "Start over", drops it.
# ---------------------------------------------------------------------------

func _keeps_draft() -> bool:
	return editing == null and (discipline == "lift" or discipline == "climb")


func _take_draft() -> void:
	if not _keeps_draft():
		return
	var d = App.draft_load(discipline)
	if d == null:
		return
	var ex = d.get("exercises", [])
	var cl = d.get("climbs", [])
	var hg = d.get("hangs", [])
	if not (ex is Array and cl is Array and hg is Array) or (ex.is_empty() and cl.is_empty() and hg.is_empty()):
		return
	if str(d.get("wu", wu)) != wu:
		# Typed in the other weight unit: the numbers would be read wrong.
		App.draft_store(discipline, null)
		return
	for e in ex:
		if e is Dictionary and e.get("sets") is Array:
			var sets = []
			for s in e.sets:
				if s is Dictionary:
					var row = {"reps": str(s.get("reps", "")), "weight": str(s.get("weight", ""))}
					if str(s.get("hold", "")) != "":
						row["hold"] = str(s.hold)
					if str(s.get("band", "")) != "":
						row["band"] = str(s.band)
					sets.append(row)
			var one = {"name": str(e.get("name", "")), "bodyweight": bool(e.get("bodyweight", false)), "timed": bool(e.get("timed", false)), "sets": sets}
			if bool(e.get("planned", false)):
				one["planned"] = true
			# (a band instead of a weight, and the L+R and PT keys once touched)
			if bool(e.get("band", false)):
				one["band"] = true
			for k in ["both", "pt"]:
				if e.get(k) is bool:
					one[k] = bool(e[k])
			lift.exercises.append(one)
	for c in cl:
		if c is Dictionary and c.has("grade") and c.has("count"):
			climbs.append(c)
	for h in hg:
		if h is Dictionary and h.has("count"):
			hangs.append(h)
	show_hang = not hangs.is_empty()
	scale = "yds" if str(d.get("scale", "v")) == "yds" else "v"
	if LogWidgets.is_date_key(str(d.get("date", ""))):
		date = str(d.date)
	dh = str(d.get("dh", ""))
	dm = str(d.get("dm", ""))
	ds = str(d.get("ds", ""))
	title = str(d.get("title", ""))
	notes = str(d.get("notes", ""))
	show_extra = title != "" or notes != ""
	restored = true
	_draft_text = JSON.stringify(_draft_dict())


func _draft_dict() -> Dictionary:
	return {"day": App.today, "wu": wu, "date": date, "dh": dh, "dm": dm, "ds": ds, "title": title, "notes": notes,
		"exercises": lift.exercises, "climbs": climbs, "hangs": hangs, "scale": scale}


## Write the draft when it changed (called from refresh, so after every change).
func _keep_draft() -> void:
	if not _keeps_draft():
		return
	var empty = lift.exercises.is_empty() and climbs.is_empty() and hangs.is_empty()
	var text = "" if empty else JSON.stringify(_draft_dict())
	if text == _draft_text:
		return
	_draft_text = text
	App.draft_store(discipline, null if empty else _draft_dict())


func _start_over() -> void:
	Sfx.tap()
	lift.exercises = []
	climbs = []
	hangs = []
	dh = ""
	dm = ""
	ds = ""
	title = ""
	notes = ""
	date = App.today
	restored = false
	_draft_text = ""
	App.draft_store(discipline, null)
	screen.rebuild()


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
			var hs = []
			for h in hangs:
				if int(h.count) > 0:
					hs.append(h.duplicate())
			if not hs.is_empty():
				s["hangs"] = hs
		_:
			s["distanceM"] = maxf(0.0, Fmt.unit_to_m(LogWidgets.num(distance), du))
			var e = LogWidgets.num(elev)
			s["elevationM"] = maxf(0.0, e if du == "km" else e / FT_PER_M)
			if discipline == "run":
				# The best splits typed, for the distances that fit in the run.
				var sp = {}
				for id in _split_ids(float(s.distanceM)):
					var split_sec = RunSplits.parse_time(str(splits.get(id, "")))
					if split_sec > 0:
						sp[id] = split_sec
				if not sp.is_empty():
					s["splits"] = sp
			if discipline == TT.MISC:
				s["kind"] = kind
				var lv = maxf(0.0, LogWidgets.num(carried))
				if lv > 0.0 and Misc.has_field(kind, "load"):
					s["loadKg"] = Fmt.unit_to_kg(lv, wu)
	return s


func is_valid(d: Dictionary) -> bool:
	match discipline:
		"lift":
			return not d.exercises.is_empty()
		"climb":
			return not d.climbs.is_empty() or not d.get("hangs", []).is_empty()
		"misc":
			return Misc.is_valid(d)
	return float(d.distanceM) > 0.0


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build(parent: Control) -> void:
	var meta = TT.DISCIPLINE_META[discipline]
	var verb = "Edit" if editing != null else "Log"
	if discipline == TT.MISC:
		var mm = Misc.meta(kind)
		parent.add_child(LogWidgets.topbar(discipline, "%s %s" % [verb, str(mm.short).to_lower()], close, remove if editing != null else Callable(), str(mm.icon)))
	else:
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

	if restored:
		# Back from the kept draft: say so, with a way to drop it.
		var rc = Kit.card(0, Callable(), 8)
		rc.accent(Pal.GOOD)
		var rr = Kit.hbox(8)
		rr.add_child(Kit.vcenter(Icons.rect("check", 16)))
		var rl = Kit.clip("Picked up where you left off", 13, null, true)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(Kit.vcenter(rl))
		rr.add_child(Kit.vcenter(Kit.button("Start over", "ghost", _start_over, "sm")))
		rc.add(rr)
		rc.set_meta("draft_banner", true)
		parent.add_child(rc)

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
	_keep_draft()
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
	var bonus = float(TTUtil.get_or(editing, "bonusPct", 0.0)) if editing != null else float(App.perks.xp.get(discipline, 0.0))
	var est = TTUtil.jsround(float(base.xp) * (1.0 + bonus))
	var side = "XP for this session, incl. +%d%% gear bonus" % TTUtil.jsround(bonus * 100.0) if bonus > 0.0 else "XP for this session"
	var sub = ""
	match discipline:
		"lift":
			sub = "%s · %d reps · %d sets" % [Fmt.fmt_big_kg(float(st.volumeKg), wu), int(st.reps) + int(st.bwReps), int(st.sets)]
		"climb":
			sub = "%d sends" % int(st.sends)
			var tops = []
			if st.maxGradeSent != null:
				tops.append(Xp.grade_label(st.maxGradeSent))
			if st.get("maxRouteSent") != null:
				tops.append(Xp.yds_label(st.maxRouteSent))
			if not tops.is_empty():
				sub += " · max " + " / ".join(PackedStringArray(tops))
			var nh = int(TTUtil.get_or(st, "hangs", 0))
			if nh > 0:
				sub += " · %d hang%s" % [nh, "" if nh == 1 else "s"]
			# st.sends counts flashes too (a flash is a send).
			side += "\n%d flashed · %d sent after tries · %d didn't go" % [int(st.flashes), int(st.sends) - int(st.flashes), int(st.attempts)]
			if nh > 0:
				side += " · %d hangs" % nh
		"run", "ride":
			sub = Fmt.fmt_distance(float(d.distanceM), du)
		"misc":
			sub = Fmt.fmt_distance(float(d.distanceM), du)
			var lkg = Misc.load_kg(d)
			if lkg > 0.0:
				sub += " · " + Misc.load_text(kind, lkg, wu)
				side += "\n%s: ×%s for the walk" % [Misc.load_text(kind, lkg, wu), TTUtil.num_str(snappedf(Misc.load_mult(kind, lkg), 0.01))]
	if not valid:
		sub = _invalid_hint()
	_fill_pace(st)
	_fill_splits(d)
	LogWidgets.fill_xp_preview(_xp_box, est, Pal.disc(discipline), side, sub)


func _invalid_hint() -> String:
	match discipline:
		"lift":
			return "Add a set with reps"
		"climb":
			return "Tap a grade, or add a hang"
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
	var was_today = date == App.today
	date = key
	# The lift form's "From today's plan" (LogPlanCard) is for a workout dated
	# today: it goes, or comes back, as the date leaves or reaches today.
	if discipline == "lift" and was_today != (date == App.today) and is_instance_valid(screen):
		screen.rebuild()
	else:
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
		var nh = int(TTUtil.get_or(st, "hangs", 0))
		if nh > 0:
			text += " · %d hangs" % nh
		var tile = LogWidgets.template(lc.date, text, _repeat_climb.bind(lc), "climb", "Same as last · ")
		parent.add_child(tile)
	# Flash / send / attempt: three bright toggles.
	var toggles = Kit.hbox(6)
	for r in ["flash", "send", "attempt"]:
		var t = LogWidgets.toggle(result_label(r), result_icon(r), climb_result == r, result_color(r), _set_result.bind(r))
		t.tooltip_text = "Grades you tap now count as a %s" % r
		toggles.add_child(t)
	parent.add_child(toggles)
	# Boulder (V) or rope (5.xx) grade keys.
	var sc = Kit.segmented([{"value": "v", "label": "Boulder · V"}, {"value": "yds", "label": "Rope · 5.xx"}], scale, _set_scale, Pal.CLIMB)
	sc.tooltip_text = "Boulder problems take V grades; top rope and lead routes take 5.xx grades"
	parent.add_child(sc)
	# The grade keys, coloured along the difficulty ramp.
	var grid = Kit.grid(6 if scale == "v" else 4, 5)
	if scale == "v":
		var top = Xp.MAX_V_GRADE if more_grades else 10
		for g in range(-1, top + 1):
			grid.add_child(_grade_key(g))
	else:
		# 5.6 … 5.12a to start; "More…" opens up to 5.15a.
		var top_i = Xp.YDS_GRADES.size() - 1 if more_grades else Xp.yds_index("5.12a")
		for i in range(1, top_i + 1):
			grid.add_child(_route_key(i))
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

	# Hangboard: folded away until used.
	var hf = LogWidgets.mini_chip(("▾ " if show_hang else "+ ") + "Hangboard", show_hang, _toggle_hang, Pal.CLIMB)
	hf.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hf.tooltip_text = "Log dead hangs: edge size, seconds, one or both arms, added weight"
	parent.add_child(hf)
	if show_hang:
		_build_hang(parent)


## Edge chips, seconds chips, arms toggles, added weight and a "+ Hang" key,
## then the hangs logged so far as chips with − / +.
func _build_hang(parent: Control) -> void:
	var card = Kit.card(8)
	card.accent(Pal.CLIMB)
	var er = Kit.hbox(4)
	er.add_child(Kit.vcenter(Icons.rect("ruler", 18)))
	for e in HANG_EDGES:
		var ec = LogWidgets.mini_chip(("%d mm" % e) if e > 0 else "Jug", hang_edge == e, _set_hang.bind("edge", e), Pal.CLIMB)
		ec.tooltip_text = ("Edge %d mm deep" % e) if e > 0 else "A jug or a bar"
		er.add_child(ec)
	card.add(er)
	var sr = Kit.hbox(4)
	sr.add_child(Kit.vcenter(Icons.rect("stopwatch", 18)))
	for s in HANG_SECS:
		var scp = LogWidgets.mini_chip("%d s" % s, hang_sec == s, _set_hang.bind("sec", s), Pal.CLIMB)
		scp.tooltip_text = "Hang for %d seconds" % s
		sr.add_child(scp)
	card.add(sr)
	var ar = Kit.hbox(6)
	ar.add_child(LogWidgets.toggle("Both arms", "muscle", hang_arms == 2, Pal.CLIMB, _set_hang.bind("arms", 2)))
	ar.add_child(LogWidgets.toggle("One arm", "bolt", hang_arms == 1, flash_color(), _set_hang.bind("arms", 1)))
	card.add(ar)
	var wr = Kit.hbox(6)
	wr.add_child(Kit.vcenter(Kit.label("Added", 13, Pal.MUTED)))
	var ws = Kit.stepper(hang_add, 2.5 if wu == "kg" else 5.0, _set_hang_add, {"placeholder": "0", "width": 58, "min": -200.0, "snap": true, "compact": true})
	LogWidgets.slim_stepper(ws, "hang.add").tooltip_text = "Weight added to the hang (negative = assisted)"
	wr.add_child(ws)
	wr.add_child(Kit.vcenter(Kit.label(wu, 11, Pal.MUTED)))
	wr.add_child(Kit.spacer())
	var add_btn = Kit.button("+ Hang", "primary", add_hang, "sm")
	add_btn.tooltip_text = "Add one hang with the settings above"
	wr.add_child(add_btn)
	card.add(wr)
	if not hangs.is_empty():
		var flow = Kit.flow(6)
		for k in range(hangs.size()):
			flow.add_child(_hang_chip(k))
		card.add(flow)
	parent.add_child(card)


## A logged hang as a chip: "6 × 10 s · 20 mm · one arm · +10 kg" with − / +.
func _hang_chip(k: int) -> Control:
	var h = hangs[k]
	var hue = Pal.CLIMB if int(h.arms) == 2 else flash_color()
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL, {"ring": hue, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 6, "pad_v": 3}))
	p.tooltip_text = "%s · %d XP" % [Xp.hang_text(h, wu), TTUtil.jsround(Xp.hang_xp(h) * int(h.count))]
	var row = Kit.hbox(5)
	row.add_child(Kit.vcenter(Icons.rect("muscle", 16, hue)))
	row.add_child(Kit.vcenter(Kit.label(Xp.hang_text(h, wu), 13, null, true)))
	row.add_child(LogWidgets.round_btn("−", bump_hang.bind(k, -1), "One hang fewer"))
	row.add_child(LogWidgets.round_btn("+", bump_hang.bind(k, 1), "One hang more"))
	p.add_child(row)
	return p


## One route grade (5.xx) as a chunky key, coloured by the boulder grade it is worth.
func _route_key(i: int) -> Button:
	var b = _grade_key(Xp.yds_to_v(i), add_route.bind(i))
	b.text = Xp.yds_label(i)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = "Add one %s %s" % [Xp.yds_label(i), climb_result]
	return b


## One grade as a chunky key in its ramp colour.
func _grade_key(g: int, on_press: Callable = Callable()) -> Button:
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
	b.pressed.connect(on_press if on_press.is_valid() else add_climb.bind(g))
	Kit.juice(b)
	return b


## A logged climb as a chip: grade in its colour, result icon, ×count, − / +.
func _climb_chip(k: int) -> Control:
	var cl = climbs[k]
	var hue = grade_hue(int(cl.grade))
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.make(Pal.PANEL, {"ring": hue, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": 6, "pad_v": 3}))
	p.tooltip_text = "%s %s%s × %d" % [Xp.climb_label(cl), "route " if Xp.is_route(cl) else "", result_label(cl.result).to_lower(), int(cl.count)]
	var h = Kit.hbox(5)
	if Xp.is_route(cl):
		h.add_child(Kit.vcenter(Icons.rect("mountain", 16, hue)))
	var g = LogWidgets.badge(Xp.climb_label(cl), hue, 13)
	LogWidgets.on_face(g.get_child(0), 3)
	h.add_child(g)
	h.add_child(Kit.vcenter(Icons.rect(result_icon(cl.result), 16, result_color(cl.result))))
	h.add_child(Kit.vcenter(PixelFont.rect("x%d" % int(cl.count), 2, Pal.TEXT)))
	h.add_child(LogWidgets.round_btn("−", bump_climb.bind(k, -1), "Minus one"))
	h.add_child(LogWidgets.round_btn("+", bump_climb.bind(k, 1), "Plus one"))
	p.add_child(h)
	return p


static func _climb_before(a: Dictionary, b: Dictionary) -> bool:
	# Boulders first, then routes; hardest first within each.
	if Xp.is_route(a) != Xp.is_route(b):
		return not Xp.is_route(a)
	if Xp.is_route(a) and str(a.get("yds")) != str(b.get("yds")):
		return Xp.yds_index(a.get("yds")) > Xp.yds_index(b.get("yds"))
	if int(a.grade) != int(b.grade):
		return int(a.grade) > int(b.grade)
	return str(a.result) < str(b.result)


func add_climb(grade: int) -> void:
	Sfx.tick()
	for c in climbs:
		if not Xp.is_route(c) and int(c.grade) == grade and c.result == climb_result:
			c.count = int(c.count) + 1
			screen.rebuild()
			return
	climbs.append({"grade": grade, "result": climb_result, "count": 1})
	screen.rebuild()


func add_route(i: int) -> void:
	Sfx.tick()
	var label = Xp.yds_label(i)
	for c in climbs:
		if Xp.is_route(c) and str(c.get("yds")) == label and c.result == climb_result:
			c.count = int(c.count) + 1
			screen.rebuild()
			return
	climbs.append({"grade": Xp.yds_to_v(i), "result": climb_result, "count": 1, "style": "rope", "yds": label})
	screen.rebuild()


func add_hang() -> void:
	Sfx.tick()
	var add_kg = Fmt.unit_to_kg(LogWidgets.num(hang_add), wu)
	for h in hangs:
		if int(h.edgeMm) == hang_edge and int(h.sec) == hang_sec and int(h.arms) == hang_arms and absf(float(h.addKg) - add_kg) < 0.01:
			h.count = int(h.count) + 1
			screen.rebuild()
			return
	hangs.append({"edgeMm": hang_edge, "sec": hang_sec, "arms": hang_arms, "addKg": add_kg, "count": 1})
	screen.rebuild()


func bump_hang(k: int, delta: int) -> void:
	if k >= hangs.size():
		return
	Sfx.tick()
	hangs[k].count = maxi(0, int(hangs[k].count) + delta)
	hangs = hangs.filter(func(h): return int(h.count) > 0)
	screen.rebuild()


func _set_hang(field: String, v) -> void:
	Sfx.tick()
	match field:
		"edge":
			hang_edge = int(v)
		"sec":
			hang_sec = int(v)
		"arms":
			hang_arms = int(v)
	screen.rebuild()


func _set_hang_add(t: String) -> void:
	hang_add = t


func _toggle_hang() -> void:
	show_hang = not show_hang
	screen.rebuild()


func _set_scale(v) -> void:
	scale = str(v)
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
	for c in lc.get("climbs", []):
		if int(c.count) > 0:
			climbs.append(c.duplicate())
			if Xp.is_route(c):
				scale = "yds"
	hangs = []
	for h in lc.get("hangs", []):
		if int(h.count) > 0:
			hangs.append(h.duplicate())
	show_hang = not hangs.is_empty()
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
	if last_same != null and (last_same.discipline == "run" or last_same.discipline == "ride" or last_same.discipline == TT.MISC) and float(TTUtil.get_or(last_same, "distanceM", 0)) > 0.0:
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
		if discipline == TT.MISC and Misc.load_kg(lc) > 0.0:
			text += " · " + Misc.load_text(kind, Misc.load_kg(lc), wu)
		_cardio_template = LogWidgets.template(lc.date, text, _use_last_cardio.bind(lc), discipline, "Same as last · ", str(Misc.meta(kind).icon) if discipline == TT.MISC else "")
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
	# The weight carried (the vest of a vest walk), with one-tap picks.
	if discipline == TT.MISC and Misc.has_field(kind, "load"):
		c.add(_load_row(col))
	# Live pace / speed.
	_pace_slot = Kit.hbox(6)
	c.add(_pace_slot)
	parent.add_child(c)
	# A run's best splits (game/run_splits.gd): the fields come by themselves
	# once the distance has a mile, a 5K, a 10K... inside it (refresh fills them).
	_splits_card = null
	if discipline == "run":
		_splits_card = Kit.card(6, Callable(), 12)
		_splits_card.accent(col)
		_splits_card.set_meta("splits_card", true)
		var shead = Kit.hbox(6)
		var stitle = Kit.label("BEST SPLITS IN THIS RUN", 10, col, true)
		stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shead.add_child(stitle)
		shead.add_child(Kit.label("optional", 10, Pal.MUTED))
		_splits_card.add(shead)
		_splits_box = Kit.vbox(6)
		_splits_card.add(_splits_box)
		_whole_line = Kit.clip("", 12, Pal.TEXT, true)
		_whole_line.set_meta("split_whole", true)
		_splits_card.add(_whole_line)
		_split_note = Kit.clip("", 11, Pal.ACCENT2)
		_split_note.set_meta("split_note", true)
		_splits_card.add(_split_note)
		_splits_ids = ["(not filled yet)"]
		_split_echo = {}
		_splits_card.visible = false
		parent.add_child(_splits_card)
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


## The distances a best split is asked for in a run of `distance_m`: the ones
## inside it for the player's unit, and any that already has a time.
func _split_ids(distance_m: float) -> Array:
	var has = []
	for id in splits:
		if str(splits[id]).strip_edges() != "":
			has.append(str(id))
	return RunSplits.offered(distance_m, du, has)


## The split fields of a run: a row per distance inside it, and what the run
## itself is ("Half marathon: 1:55:20"). The rows are refilled only when the
## distances change, never while one of them is typed in; the words beside
## each box (the time as read, its pace) are brought up to date every time.
func _fill_splits(d: Dictionary) -> void:
	if _splits_card == null or not is_instance_valid(_splits_card):
		return
	var dist_m = float(d.get("distanceM", 0.0))
	var dur = float(d.get("durationSec", 0))
	var ids = _split_ids(dist_m)
	var whole = RunSplits.whole(dist_m)
	_splits_card.visible = not ids.is_empty() or whole != ""
	if ids != _splits_ids:
		_splits_ids = ids
		Kit.clear(_splits_box)
		_split_echo = {}
		for id in ids:
			_splits_box.add_child(_split_row(str(id)))
	var slow = false
	for id in ids:
		var echo = _split_echo.get(id)
		if echo == null or not is_instance_valid(echo):
			continue
		var typed = str(splits.get(id, "")).strip_edges()
		var sec = RunSplits.parse_time(typed)
		if typed == "":
			# What the run's average pace would make of it, to go by.
			var avg = dur / dist_m * float(RunSplits.by_id(id).m) if (dur > 0.0 and dist_m > 0.0) else 0.0
			echo.text = ("avg %s" % RunSplits.fmt_time(avg)) if avg > 0.0 else ""
			echo.add_theme_color_override("font_color", Pal.MUTED)
		elif sec <= 0:
			echo.text = "? write 7.45"
			echo.add_theme_color_override("font_color", Pal.ACCENT2)
		else:
			var is_slow = RunSplits.slower_than_run(id, float(sec), dist_m, dur)
			slow = slow or is_slow
			echo.text = "%s%s · %s" % [RunSplits.fmt_time(sec), " ?" if is_slow else "", Fmt.fmt_pace(RunSplits.pace(id, float(sec)), du)]
			echo.add_theme_color_override("font_color", Pal.ACCENT2 if is_slow else Pal.disc(discipline))
	if is_instance_valid(_whole_line):
		if whole != "":
			var wn = str(RunSplits.by_id(whole).name)
			_whole_line.text = ("%s: %s, this run's own time" % [wn, RunSplits.fmt_time(dur)]) if dur > 0.0 else ("%s: add the run's time above" % wn)
		_whole_line.visible = whole != ""
	if is_instance_valid(_split_note):
		_split_note.text = "? A best split cannot be slower than the run's average pace"
		_split_note.visible = slow


## One split: what it is, the box to type its time in, and the time as read.
func _split_row(id: String) -> Control:
	var dist = RunSplits.by_id(id)
	var row = Kit.hbox(8)
	row.set_meta("split_row", id)
	var nm = Kit.clip(str(dist.ask), 14, Pal.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	var e = LogWidgets.num_input(str(splits.get(id, "")), "0.00", "split." + id, 84)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.select_all_on_focus = true
	e.tooltip_text = "%s in this run: minutes.seconds (7.45), or 1.02.03 with hours" % str(dist.ask)
	e.text_changed.connect(func(t):
		splits[id] = t
		refresh())
	row.add_child(e)
	var echo = Kit.label("", 12, Pal.MUTED, true)
	echo.custom_minimum_size = Vector2(134, 0)
	echo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	echo.clip_text = true
	echo.set_meta("split_echo", id)
	row.add_child(echo)
	_split_echo[id] = echo
	return row


## The weight row of a misc activity: the number, its unit, and quick picks
## (the one used last time first).
func _load_row(col: Color) -> Control:
	var name = str(Misc.meta(kind).loadName)
	var v = Kit.vbox(4)
	v.add_child(Kit.label("%s weight" % name, 12, Pal.MUTED, true))
	var row = Kit.hbox(6)
	var le = LogWidgets.big_input(carried, "0", "load", 76, 18)
	le.tooltip_text = "%s weight (%s)" % [name, wu]
	le.text_changed.connect(func(t):
		carried = t
		refresh())
	row.add_child(le)
	row.add_child(LogWidgets.unit_chip(wu))
	var picks = []
	var last_kg = Misc.load_kg(last_same) if last_same != null else 0.0
	if last_kg > 0.0:
		picks.append(LogWidgets.trim_num(Fmt.kg_to_unit(last_kg, wu), 1))
	for n in LOAD_PICKS.get(wu, LOAD_PICKS.kg):
		if picks.size() < 4 and not picks.has(str(n)):
			picks.append(str(n))
	for pk in picks:
		var chip = LogWidgets.mini_chip(pk, LogWidgets.num(carried) > 0.0 and is_equal_approx(LogWidgets.num(carried), LogWidgets.num(pk)), _pick_load.bind(pk), col, 8)
		chip.tooltip_text = "%s %s %s" % [pk, wu, name.to_lower()]
		row.add_child(chip)
	v.add_child(row)
	return v


func _pick_load(text: String) -> void:
	Sfx.tick()
	carried = text
	screen.rebuild()


## The live pace (run, walk) or speed (ride) chip under the distance.
func _fill_pace(st: Dictionary) -> void:
	if _pace_slot == null or not is_instance_valid(_pace_slot):
		return
	Kit.clear(_pace_slot)
	var text = ""
	var tip = ""
	if discipline == TT.MISC:
		if st.get("paceSecPerKm") != null:
			_pace_slot.add_child(_pace_chip(Fmt.fmt_pace(float(st.paceSecPerKm), du), "Average pace", "stopwatch"))
		var lkg = float(TTUtil.get_or(st, "loadKg", 0.0))
		if lkg > 0.0:
			_pace_slot.add_child(_pace_chip("×%s XP" % TTUtil.num_str(snappedf(Misc.load_mult(kind, lkg), 0.01)), "What the weight adds to the walk", str(Misc.meta(kind).icon)))
		if _pace_slot.get_child_count() == 0:
			_pace_slot.add_child(Kit.label("Add a time for pace", 12, Pal.MUTED))
		return
	if discipline == "run" and st.get("paceSecPerKm") != null:
		text = Fmt.fmt_pace(float(st.paceSecPerKm), du)
		tip = "Average pace"
	elif discipline == "ride" and st.get("speedKmh") != null:
		text = Fmt.fmt_speed(float(st.speedKmh), du)
		tip = "Average speed"
	if text == "":
		_pace_slot.add_child(Kit.label("Add a time for %s" % ("pace" if discipline == "run" else "speed"), 12, Pal.MUTED))
		return
	_pace_slot.add_child(_pace_chip(text, tip, "stopwatch"))


## A raised chip in the discipline's colour: an icon and a live number.
func _pace_chip(text: String, tip: String, icon: String) -> PanelContainer:
	var chip = PanelContainer.new()
	chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col = Pal.disc(discipline)
	chip.add_theme_stylebox_override("panel", PixBox.make(col, {"lip": 1, "lip_color": col.darkened(0.45), "pad_h": 8, "pad_v": 2}))
	chip.tooltip_text = tip
	var h = Kit.hbox(6)
	h.add_child(Kit.vcenter(Icons.rect(icon, 16)))
	h.add_child(LogWidgets.on_face(Kit.label(text, 14, null, true)))
	chip.add_child(h)
	return chip


func _use_last_cardio(lc: Dictionary) -> void:
	Sfx.tap()
	distance = LogWidgets.trim_num(Fmt.m_to_unit(float(lc.distanceM), du))
	elev = _elev_text(float(TTUtil.get_or(lc, "elevationM", 0)))
	if lc.get("durationSec") != null and int(lc.durationSec) > 0:
		set_duration(int(lc.durationSec))
	if discipline == TT.MISC and Misc.load_kg(lc) > 0.0:
		carried = LogWidgets.trim_num(Fmt.kg_to_unit(Misc.load_kg(lc), wu), 1)
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
	# Lifts filled in from the day's plan and never touched: done as shown, or
	# skipped? Asked once, so a skipped lift is not logged by accident.
	var left = lift.planned_names() if discipline == "lift" and not _planned_ok else []
	if not left.is_empty():
		var shown = []
		for nm in left:
			shown.append(Missions.short_name(str(nm)))
		Kit.confirm("Done as shown?", "Still as they were filled in from your plan: %s. Save them as shown? If you skipped one, go back and take it off with its ×." % ", ".join(PackedStringArray(shown)), "Yes, save", _save_planned, false)
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
	App.draft_store(discipline, null)
	App.commit_sessions([session], "Session logged!")
	App.open_log(null)
	App.go("home")


func _save_planned() -> void:
	_planned_ok = true
	save()


func remove() -> void:
	if editing == null:
		return
	var id = editing.id
	Kit.confirm("Delete this session?", "Your levels and unlocks will be recalculated.", "Delete", func():
		App.delete_session(id)
		App.toast("Session deleted", "info", "trash")
		App.open_log(null)
		App.go("journey"))
