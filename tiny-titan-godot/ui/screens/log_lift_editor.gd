class_name LogLiftEditor
extends RefCounted
## The lifting part of the log form. Built so a normal session is mostly taps:
## pick an exercise and last time's sets are already filled in, then nudge reps
## / weight with + and − (or bump every set at once).
##
## Holds the draft (`exercises`) across rebuilds; `form` (LogSessionForm) owns it
## and is told about every change so the XP preview / save button stay live.

## The owning LogSessionForm, held weakly (it holds this editor: no reference cycle).
var _form_ref: WeakRef = null
var editing_id = null
## [{name: String, bodyweight: bool, sets: [{reps: String, weight: String}]}]
## `timed: true` = a hold (a stretch): its sets have `hold` (seconds, a String)
## where the weight would be. `planned: true` = filled in from the day's plan
## and not touched yet (the form asks about those before it saves). `both`
## (true / false, only once the "L+R" key was touched) = the reps are both
## sides added up, or are not (Sides): stored for the lift when the workout
## is saved. `band: true` = done with a resistance band (the "Band" key): its
## sets have `band` (a Bands id) where the weight would be, and are saved with
## weight 0 and that band. Band, Hold and BW are one at a time.
var exercises: Array = []
var query: String = ""
var wu: String = "kg"
## The exercise picker shows two rows of chips until "More" is tapped.
var show_all_chips: bool = false

# Rebuilt on every build (never used across rebuilds).
var _last: Dictionary = {}
var _bests: Dictionary = {}
var _suggestions: Array = []
## Sets ("i:j") that already celebrated becoming a PR: the burst plays once per set.
var _pr_done: Dictionary = {}
var _badges: Array = []  # [exercise][set] -> HBoxContainer slot for the trend badge
var _wsteps: Array = []  # [exercise][set] -> the weight stepper (where a PR bursts from)
var _deltas: Array = []  # [exercise] -> VBoxContainer slot for the volume note
var _cards: Array = []  # [exercise] -> its Card (the edge lights up at the first touch)
var _filed: Array = []  # [exercise] -> VBoxContainer slot: how a new name will be filed
## The heaviest band (Bands.level) ever done on each lift (normalized name), and
## the band the player used last on any lift: for the badges and for filling in
## a band when the "Band" key is tapped.
var _band_best: Dictionary = {}
var _band_last: String = ""
## The player's lifts (App.lift_names) and their keys, and whether a name typed
## here is filed when the workout is saved (App.absorb_pt: not for a session
## that came from the phone note, whose names stay as they are).
var _own: Array = []
var _have: Dictionary = {}
var _files_names: bool = true
var _built_names: Array = []
var _chips: HFlowContainer = null
var _no_match: Label = null
var _area = null
var _shown_names: Array = []
var _add_btn: Button = null
var _building: bool = false
## When the first set of this workout was ticked (unix seconds; 0 = none yet): the workout's time is taken from
## it when no time is typed (LogSessionForm.auto_duration). Kept in the draft.
var started: float = 0.0
var _plates: Array = []  # [exercise] -> Label: what goes on the bar (barbell lifts)
## The superset label of each exercise ("A1", "A2", "B1"... or ""), worked out on every build.
var _labels: Array = []
## [exercise] -> HFlowContainer of the records to try (or null): refilled as sets change (_refresh_try)
var _try: Array = []
## "<lift>|<type>": a record to try already hit and cheered while this form is open
var _hit_seen: Dictionary = {}
## [exercise] -> built with its name as a title (_named), not a box
var _titled: Array = []
## [exercise] -> the plate with its name on the card's top edge (its ring is the card's edge colour)
var _signs: Array = []


func _init(owner_form, edit_id = null) -> void:
	_form_ref = weakref(owner_form) if owner_form != null else null
	editing_id = edit_id
	wu = App.weight_unit()


# ---------------------------------------------------------------------------
# Draft <-> sets
# ---------------------------------------------------------------------------

static func draft_from_sets(ex_name: String, sets: Array, unit: String) -> Dictionary:
	var bw = sets.size() > 0
	for s in sets:
		if float(s.weightKg) != 0.0:
			bw = false
	# Done with a resistance band: its sets say which (Bands). An older lift
	# named for its band ("Face Pull - Green band", weight 0 everywhere) opens
	# as sets with that band.
	var top_band = Bands.top(sets)
	var banded = top_band != ""
	for s in sets:
		if Bands.is_band(s):
			banded = true
	if not banded and bw and Bands.of_name(ex_name) != "" and not sets.any(func(s): return int(s.get("holdSec", 0)) > 0):
		banded = true
		top_band = Bands.of_name(ex_name)
	var rows = []
	var timed = false
	for s in sets:
		var row = {"reps": str(int(s.reps)), "weight": LogWidgets.trim_num(Fmt.kg_to_unit(float(s.weightKg), unit)) if float(s.weightKg) > 0.0 else ""}
		# A hold (a stretch, written 30" in the phone note): seconds, not weight.
		if int(s.get("holdSec", 0)) > 0:
			row["hold"] = str(int(s.holdSec))
			timed = true
		if banded:
			row["band"] = str(s.band).strip_edges().to_lower() if Bands.is_band(s) else (top_band if top_band != "" else Bands.DEFAULT)
		rows.append(row)
	if rows.is_empty():
		rows.append({"reps": "", "weight": ""})
	var out = {"name": ex_name, "bodyweight": bw and not (banded and not timed), "timed": timed, "sets": rows}
	if banded and not timed:
		out["band"] = true
	return out


## Empty or zero-rep sets are dropped (as the web app does). A set done with a
## band is saved with weight 0 and its band (Bands.DEFAULT when it has none).
static func sets_from_draft(e: Dictionary, unit: String) -> Array:
	var out = []
	var timed = bool(e.get("timed", false))
	var banded = bool(e.get("band", false)) and not timed
	for s in e.sets:
		var reps = maxi(0, TTUtil.jsround(LogWidgets.num(s.reps)))
		var kg = 0.0 if (e.bodyweight or timed or banded) else maxf(0.0, Fmt.unit_to_kg(LogWidgets.num(s.weight), unit))
		if reps > 0:
			var one = {"reps": reps, "weightKg": kg}
			var sec = maxi(0, TTUtil.jsround(LogWidgets.num(s.get("hold", "")))) if timed else 0
			if sec > 0:
				one["holdSec"] = sec
			if banded:
				var b = str(s.get("band", "")).strip_edges().to_lower()
				one["band"] = b if b != "" else Bands.DEFAULT
			out.append(one)
	return out


## The exercises filled in from the day's plan and never touched (names).
func planned_names() -> Array:
	var out = []
	for e in exercises:
		if bool(e.get("planned", false)) and not sets_from_draft(e, wu).is_empty():
			out.append(str(e.name).strip_edges())
	return out


func _touched(i: int) -> void:
	if i < exercises.size():
		exercises[i].erase("planned")


## The exercises as they will be saved: named, with at least one real set.
func session_exercises() -> Array:
	var out = []
	var labels = _group_labels()
	for ei in range(exercises.size()):
		var e = exercises[ei]
		var nm = str(e.name).strip_edges()
		var sets = sets_from_draft(e, wu)
		if nm != "" and not sets.is_empty():
			var one = {"name": nm, "sets": sets}
			# The "L+R" key was touched: App.absorb_pt stores what it says for the
			# lift and takes the flag off again.
			if e.has("both"):
				one["bothSides"] = bool(e.both)
			# How hard it was (LogLiftMenu) and the superset it was in ("A", "B"...): shown only.
			if str(e.get("effort", "")) != "":
				one["effort"] = str(e.effort)
			var gl = str(labels[ei])
			if gl != "":
				one["superset"] = gl.substr(0, 1)
			# The PT key was touched: App.absorb_pt marks the lift, or takes its
			# mark off, and drops the flag. Off also takes a typed "(PT)" off.
			if e.get("pt") is bool:
				one["pt"] = bool(e.pt)
				if not bool(e.pt):
					one.name = str(Pt.untag(nm).name).strip_edges()
			out.append(one)
	return out


func _step() -> float:
	return TT.weight_step_of(App.settings())


func _fmt_w(kg) -> String:
	return Fmt.fmt_weight(float(kg), wu)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build(parent: Control) -> void:
	_building = true
	var sessions = App.sessions()
	_last = LiftHistory.last_performances(sessions, editing_id)
	_suggestions = LiftHistory.exercise_suggestions(sessions, LiftNames.defaults(), editing_id)
	_bests = App.state.prs.lifts
	_read_bands(sessions)
	var owner_form = _form()
	_files_names = owner_form == null or owner_form.editing == null or str(owner_form.editing.get("inboxKey", "")) == ""
	_own = App.lift_names() if _files_names else []
	_have = {}
	for known in _own:
		_have[Xp.normalize_exercise(str(known))] = true
	_filed = []
	_titled = []
	_signs = []
	_try = []
	_badges = []
	_wsteps = []
	_deltas = []
	_cards = []
	_built_names = []

	# Exercises sent over: the day's plan from the Today card ("Start workout",
	# marked planned until touched) or one from the lift library. Each comes
	# with last time's sets.
	var pends = []
	for nm in App.pending_workout:
		pends.append([str(nm), true])
	App.pending_workout = []
	if App.pending_exercise != "":
		pends.append([App.pending_exercise, false])
		App.pending_exercise = ""
	for pair in pends:
		var pend = str(pair[0])
		var pk = Xp.normalize_exercise(pend)
		var have = false
		for e in exercises:
			if Xp.normalize_exercise(e.name) == pk:
				have = true
		if have or pk == "":
			continue
		# A prepped day (game/prep.gd): the lift comes with the sets prepped and its superset.
		var pd = _prepped_draft(pend)
		if pd != null:
			if bool(pair[1]):
				pd["planned"] = true
			exercises.append(pd)
			continue
		var plp = _last.get(pk)
		if plp != null:
			var one = draft_from_sets(str(plp.name), plp.sets, wu)
			if bool(pair[1]):
				one["planned"] = true
			exercises.append(one)
		else:
			# (never done: an empty set; from the plan it is "planned" like the
			# others, so its key in "From today's plan" takes it back again)
			var blank = _blank(pend)
			if bool(pair[1]):
				blank["planned"] = true
			exercises.append(blank)

	# The day's plan as keys (LogPlanCard): first of all while the workout is
	# empty, else under the exercises, where the next lift is added.
	var plan_card = LogPlanCard.build(self)
	if exercises.is_empty():
		if plan_card != null:
			parent.add_child(plan_card)
		var templates = LiftHistory.recent_workouts(sessions, 3, editing_id)
		if not templates.is_empty():
			# (2026-11-27 review: the rows sat on the bare planks, their stored names, dashes and all, ran
			# into each other and were cut off; "1 exercises") A window under a sign; each workout as its
			# movements, once each.
			var tv = Kit.section("repeat", "REPEAT A WORKOUT", "repeat", Pal.LIFT, null, Callable(), 6, 10)
			for t in templates:
				var names = []
				for e in t.exercises:
					if _has_reps(e.sets):
						names.append(str(e.name).strip_edges())
				var tile = LogWidgets.template(t.date, _template_words(names), apply_template.bind(t), "lift", "%d exercise%s · " % [names.size(), "" if names.size() == 1 else "s"])
				tile.tooltip_text = "Start from this workout, with your latest numbers"
				tv.add(tile)
			parent.add_child(tv)

	_labels = _group_labels()
	_plates = []
	for i in range(exercises.size()):
		if i > 0 and linked_next(i - 1):
			parent.add_child(_superset_line(i - 1))
		parent.add_child(_exercise_card(i))

	if plan_card != null and not exercises.is_empty():
		parent.add_child(plan_card)
	parent.add_child(_picker_card())
	_building = false


## A past workout in a few words: its movements, each once ("Deadlift · Overhead Press · Bench Press"); one
## exercise alone with its variation ("Bench Press (dumbbell)"), so it never reads as just a lift's name.
static func _template_words(names: Array) -> String:
	var moves = []
	var seen = {}
	for nm in names:
		var mv = str(LiftNames.split(str(nm)).move)
		var k = Xp.normalize_exercise(mv)
		if k != "" and not seen.has(k):
			seen[k] = true
			moves.append(mv)
	if moves.is_empty():
		return ""
	if moves.size() == 1:
		return Missions.short_name(str(names[0])) if names.size() == 1 else "%s, %d ways" % [str(moves[0]), names.size()]
	return " · ".join(PackedStringArray(moves))


static func _has_reps(sets: Array) -> bool:
	for s in sets:
		if int(s.reps) > 0:
			return true
	return false


## The heaviest band done on each lift, and the band of the newest lift done
## with one (the session being edited left out).
func _read_bands(sessions: Array) -> void:
	_band_best = {}
	_band_last = ""
	var newest = ""
	var newest_at = -1.0
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or (editing_id != null and s.get("id") == editing_id):
			continue
		for ex in s.get("exercises", []):
			var top = Bands.top(ex.get("sets", []))
			if top == "":
				continue
			var k = Xp.normalize_exercise(str(ex.get("name", "")))
			_band_best[k] = maxi(int(_band_best.get(k, 0)), Bands.level(top))
			var d = str(s.get("date", ""))
			var at = float(s.get("createdAt", 0))
			if d > newest or (d == newest and at > newest_at):
				newest = d
				newest_at = at
				_band_last = top


## A band to start a lift's sets with: the band it was done with last time,
## else a band its name says, else the band used last on any lift, else
## Bands.DEFAULT.
func _band_fill(e: Dictionary) -> String:
	var nm = str(e.get("name", "")).strip_edges()
	var lp = _last.get(Xp.normalize_exercise(nm))
	if lp != null and Bands.top(lp.sets) != "":
		return Bands.top(lp.sets)
	if Bands.of_name(nm) != "":
		return Bands.of_name(nm)
	if _band_last != "":
		return _band_last
	return Bands.DEFAULT


## A new exercise, never done: one empty set. A name that says it is done with
## a band ("Pull-Apart", "March - Band") starts with a band instead of a weight.
func _blank(ex_name: String) -> Dictionary:
	var one = {"name": ex_name.strip_edges(), "bodyweight": false, "sets": [{"reps": "", "weight": ""}]}
	if Bands.says_band(ex_name):
		one["band"] = true
		one.sets[0]["band"] = _band_fill(one)
	return one


## Collapsed picker: about two rows of chips.
const CHIPS_COLLAPSED = 6
## The widest a movement and a variation are written on an exercise key.
const CHIP_MOVE_W = 150.0
const CHIP_VARIATION_W = 120.0

## One exercise: a title line (name · BW · remove), one muted "Last … · Best …"
## line, one tight row per set (n · reps × weight unit · trend · remove) and a
## footer of small chips with the volume note on the right.
func _exercise_card(i: int) -> Card:
	var e = exercises[i]
	var key = Xp.normalize_exercise(e.name)
	var lp = _last.get(key)
	var best = _bests.get(key)
	_built_names.append(str(e.name).strip_edges())
	var timed = bool(e.get("timed", false))
	var c = Kit.card(4, Callable(), 10)
	c.set_meta("exercise_card", i)
	c.set_meta("card_part", str(Missions.part_of(str(e.name))))
	_cards.append(c)

	# The lift's name on a plate on the window's top edge, as the mock-up's "BENCH PRESS" (2026-11-27
	# review: the card's title was a plain line inside the frame, the only one on the page without a sign).
	# A tap on it renames (a new name: the box to type it is in the first row, the plate says so). The plate's
	# ring is the card's edge: quiet while as the plan filled it in, else the colour of the muscle it works
	# (as on the Today card), green once every set is ticked (_edge_color, _paint_edge).
	_titled.append(_named(i))
	var plate = _name_title(i) if _titled[i] else _plain_plate(i)
	var sign_row = SignRow.new()
	sign_row.add_child(plate)
	c.section_look(_edge_color(i))
	c.with_head(sign_row, 10, 4)

	# Under the plate: the muscle's icon, the superset tag, how many sets are ticked (or the box to type a
	# new name in), how hard it was, More and the red cross (the user, 2026-11-24, asking for a PT key:
	# five keys beside the name left it too little room on a phone).
	var head = Kit.hbox(6)
	var part = str(Missions.part_of(str(e.name)))
	head.add_child(Kit.vcenter(Kit.badge(TodayView.part_icon(part), JourneyLifts.part_color(part) if part != "" else Pal.LIFT, 16)))
	var glabel = str(_labels[i]) if i < _labels.size() else ""
	if glabel != "":
		var gt = Kit.tag(glabel, Pal.SECOND, true, 12)
		gt.set_meta("superset_tag", glabel)
		gt.tooltip_text = "Superset: done in turn with the lift next to it"
		head.add_child(Kit.vcenter(gt))
	if _titled[i]:
		var ticked = 0
		for s in e.sets:
			if bool(s.get("done", false)):
				ticked += 1
		var plural = "" if e.sets.size() == 1 else "s"
		# (a saved workout opened again has no ticks: its sets are simply counted)
		var said = ("%d set%s" % [e.sets.size(), plural]) if editing_id != null else ("%d of %d set%s ticked" % [ticked, e.sets.size(), plural])
		var tl = Kit.clip(said, 12, Pal.GOOD_DARK if ticked > 0 and ticked == e.sets.size() else Pal.MUTED, true)
		tl.set_meta("ticked_line", ticked)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tl)
	else:
		var name_edit = LogWidgets.title_edit(e.name, "Exercise name", 17)
		name_edit.set_meta(LogWidgets.FKEY, "ex%d.name" % i)
		name_edit.set_meta("type_top", true)
		name_edit.text_changed.connect(_on_name_typed.bind(i))
		name_edit.focus_exited.connect(_on_name_done.bind(i))
		name_edit.text_submitted.connect(func(_t): _on_name_done(i))
		head.add_child(name_edit)
	var eff = str(e.get("effort", ""))
	if eff != "":
		var et = Kit.tag(LogLiftMenu.effort_word(eff).to_upper(), LogLiftMenu.effort_color(eff), true, 11)
		et.set_meta("effort_tag", eff)
		head.add_child(Kit.vcenter(et))
	var more = LogWidgets.mini_chip("More", false, LogLiftMenu.open.bind(self, i), Pal.LIFT, 8)
	# (the text and tooltip never change: the screen finds this lift's key again after a rebuild)
	more.tooltip_text = "More for %s: swap, superset, note, how hard" % (str(e.name).strip_edges() if str(e.name).strip_edges() != "" else "this exercise")
	more.set_meta("more_key", i)
	head.add_child(Kit.vcenter(more))
	head.add_child(LogWidgets.quiet_icon("close", remove_exercise.bind(i), "Remove exercise", 28))
	c.add(head)
	# What goes beside the reps, one of four (a pick-one track: every key is always
	# there, so none moves when one is tapped): a weight, nothing (bodyweight), a
	# resistance band (Bands) or seconds held (a stretch). Then two switches:
	# L+R (reps are both sides added up) and PT (a physical therapy exercise).
	var banded = bool(e.get("band", false)) and not timed
	var mode = _mode_of(e)
	var modes = Kit.hbox(6)
	var keys = []
	for m in MODES:
		var k = Kit.choice(m[1], mode == m[0], _set_mode.bind(i, m[0]), Pal.LIFT, 12)
		k.tooltip_text = m[2]
		k.set_meta("mode_key", m[0])
		# (the tooltip and the text never change with the state, so the screen
		# finds the same key again after the rebuild and keeps it under the finger)
		if m[0] == "band":
			k.set_meta("band_chip", banded)
		keys.append(k)
	modes.add_child(Kit.choice_track(keys))
	var both = not timed and _both(e)
	var lr = LogWidgets.mini_chip(Sides.SHORT, both, _toggle_both.bind(i), Pal.LIFT, 8)
	lr.tooltip_text = "Reps are both sides added up (left + right)"
	lr.set_meta("both_chip", both)
	# (a hold has no reps to add up; the key stays in its place, switched off)
	lr.disabled = timed
	modes.add_child(Kit.vcenter(lr))
	var pt_on = _pt_on(e)
	var ptk = LogWidgets.mini_chip("PT", pt_on, _toggle_pt.bind(i), Pal.PT, 8)
	ptk.tooltip_text = "Physical therapy: counts toward the day's PT once the workout is saved"
	ptk.set_meta("pt_chip", pt_on)
	modes.add_child(Kit.vcenter(ptk))
	c.add(modes)
	# How a name that is new to the log will be filed, said while it is typed:
	# the movement, and its variation as a tag (_refresh_filed).
	var filed = Kit.vbox(1)
	var filed_wrap = Kit.pad(filed, 6, 0, 4, 0)
	filed_wrap.visible = false
	c.add(filed_wrap)
	_filed.append(filed)
	if both:
		# Said in words: a phone shows no tooltip.
		var hint = Kit.clip("%s · reps are both sides added up" % Sides.SHORT, 11, Pal.LIFT)
		hint.set_meta("both_hint", true)
		c.add(Kit.pad(hint, 6, 0, 4, 0))
	# The PT key changed in this workout: what saving it will do, in words.
	var pt_words = _pt_words(e)
	if pt_words != "":
		var pth = Kit.clip(pt_words, 11, Pal.PT)
		pth.set_meta("pt_hint", true)
		c.add(Kit.pad(pth, 6, 0, 4, 0))

	# Last time, the best and the aim in one sunken box: two columns, LAST and AIM, with Fill at the end
	# (2026-11-27, "clean and crisp": they were three loose lines of different sizes).
	var ref_box = _ref_block(i, lp, best, banded, both)
	if ref_box != null:
		c.add(ref_box)
	# Records to try today (Challenges): a key each, lit once a set does it; a tap puts it in the next set.
	var opts = _try_options(i)
	if opts.is_empty():
		_try.append(null)
	else:
		var tr = Kit.hbox(6)
		# (2026-11-27 review: a 9 px caption) 12 px, bold.
		var cap = Kit.label("TRY", 12, Pal.ACCENT2, true)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.add_child(cap)
		var flow = Kit.flow(5)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.set_meta("try_row", i)
		tr.add_child(flow)
		c.add(Kit.pad(tr, 6, 0, 4, 0))
		_try.append(flow)
	var note = App.lift_note(str(e.name)) if str(e.name).strip_edges() != "" else ""
	if note != "":
		var nb = Kit.link("Note: " + note, LogLiftMenu.open.bind(self, i), 12, Pal.ACCENT2)
		nb.clip_text = true
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nb.set_meta("lift_note", note)
		nb.tooltip_text = "Your note for %s (tap to change it)" % str(e.name).strip_edges()
		c.add(Kit.pad(nb, 6, 0, 4, 0))
	# Sets
	var slots = []
	var wsteps = []
	var label_name = str(e.name).strip_edges()
	if label_name == "":
		label_name = "Exercise %d" % (i + 1)
	var fill = _band_fill(e) if banded else ""
	for j in range(e.sets.size()):
		var s = e.sets[j]
		var ref_set = _ref_set(lp, j)
		var row = Kit.hbox(3 if Kit.fingers else 4)
		var row_bg = _set_bg(bool(s.get("done", false)))
		row_bg.add_child(row)
		row.add_child(_tick_key(i, j, label_name))
		var reps_opts = {"placeholder": "–", "width": 32, "min": 0, "compact": true}
		if ref_set != null:
			reps_opts["base"] = int(ref_set.reps)
		var rs = Kit.stepper(s.reps, 1.0, Callable(), reps_opts)
		LogWidgets.slim_stepper(rs, "ex%d.s%d.reps" % [i, j]).tooltip_text = "%s reps for set %d" % [label_name, j + 1]
		rs.changed.connect(_on_set_text.bind(i, j, "reps"))
		row.add_child(rs)
		var ws = null
		if timed:
			# A hold: how many times, and the seconds each one is held.
			row.add_child(Kit.vcenter(Kit.label("×", 13, Pal.MUTED)))
			var h_opts = {"placeholder": "sec", "width": 44, "min": 0, "compact": true, "base": 30}
			if ref_set != null and int(ref_set.get("holdSec", 0)) > 0:
				h_opts["base"] = int(ref_set.holdSec)
			ws = Kit.stepper(str(s.get("hold", "")), 5.0, Callable(), h_opts)
			LogWidgets.slim_stepper(ws, "ex%d.s%d.hold" % [i, j]).tooltip_text = "%s: seconds held in set %d" % [label_name, j + 1]
			ws.changed.connect(_on_set_text.bind(i, j, "hold"))
			row.add_child(ws)
			row.add_child(Kit.vcenter(Kit.label("s", 11, Pal.MUTED)))
		elif banded:
			# A resistance band where the weight would be: lighter / the band /
			# heavier (BandPicker). A tap changes it in place (_on_band). (No "×"
			# on a phone: its keys take the room.)
			if not Kit.fingers:
				row.add_child(Kit.vcenter(Kit.label("×", 13, Pal.MUTED)))
			if str(s.get("band", "")).strip_edges() == "":
				s["band"] = fill
			var bp = BandPicker.new()
			bp.setup(str(s.band), "%s set %d" % [label_name, j + 1])
			bp.set_meta("band_of", "%d:%d" % [i, j])
			bp.changed.connect(_on_band.bind(i, j))
			ws = bp
			row.add_child(bp)
		elif not e.bodyweight:
			row.add_child(Kit.vcenter(Kit.label("×", 13, Pal.MUTED)))
			var w_opts = {"placeholder": wu, "width": 54, "snap": true, "min": 0, "compact": true}
			if ref_set != null and float(ref_set.weightKg) > 0.0:
				w_opts["base"] = TTUtil.jsround(Fmt.kg_to_unit(float(ref_set.weightKg), wu) * 100.0) / 100.0
			ws = Kit.stepper(s.weight, _step(), Callable(), w_opts)
			LogWidgets.slim_stepper(ws, "ex%d.s%d.weight" % [i, j]).tooltip_text = "%s weight for set %d" % [label_name, j + 1]
			ws.changed.connect(_on_set_text.bind(i, j, "weight"))
			row.add_child(ws)
			# On a phone the keys take the room: the unit is in the chips below.
			if not Kit.fingers:
				row.add_child(Kit.vcenter(Kit.label(wu, 11, Pal.MUTED)))
		else:
			row.add_child(Kit.vcenter(Kit.label("reps", 11, Pal.MUTED)))
		var slot = Kit.hbox(0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.alignment = BoxContainer.ALIGNMENT_BEGIN
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# (in a clipping box that asks for no width: a long badge is cut, it never widens the row and so the
		# page; a phone's row has little room once its keys are finger-sized)
		var clipper = Control.new()
		clipper.clip_contents = true
		clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clipper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.offset_left = 2
		clipper.add_child(slot)
		row.add_child(clipper)
		slots.append(slot)
		wsteps.append(ws if ws != null else rs)
		row.add_child(LogWidgets.quiet_icon("close", remove_set.bind(i, j), "Remove set %d" % (j + 1), 26))
		c.add(row_bg)
	_badges.append(slots)
	_wsteps.append(wsteps)

	# + Set · +1 rep · +step (every set), then the up / down keys.
	# (2026-11-27 review: the card's most used keys were 28 px chips, "+ Set" a small orange one) As the
	# mock-up: a big green "+ Set" and wooden keys for the bumps, sharing the row in equal widths. The row
	# is as wide as the card, so no key moves when another changes; the volume note is on the line under it.
	var acts = Kit.hbox(6)
	var add_btn = Kit.button("+ Set", "good", add_set.bind(i), "md")
	add_btn.tooltip_text = "Add a set (copies the last one)"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(add_btn)
	var rep_btn = Kit.button("+1 rep", "secondary", bump_all.bind(i, "reps"), "sm")
	rep_btn.tooltip_text = "Add one rep to every set"
	rep_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acts.add_child(rep_btn)
	var bump = null
	if timed:
		bump = Kit.button("+5 s", "secondary", bump_all.bind(i, "hold"), "sm")
		bump.tooltip_text = "Hold every set five seconds longer"
	elif banded:
		bump = Kit.button("+1 band", "secondary", bump_all.bind(i, "band"), "sm")
		# (the tooltip names the lift: after the rebuild the screen finds this
		# lift's key again and keeps it under the finger, UiScreen)
		bump.tooltip_text = "%s: every set one band heavier" % label_name
		bump.set_meta("band_bump", true)
	elif not e.bodyweight:
		bump = Kit.button("+%s %s" % [TTUtil.num_str(_step()), wu], "secondary", bump_all.bind(i, "weight"), "sm")
		bump.tooltip_text = "Add one weight step to every set"
	if bump != null:
		bump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acts.add_child(bump)
	# Up and down in the workout's order: two lifts done in turn (a superset)
	# go next to each other, and there is no scrolling between them. With the
	# other keys, not at the row's right end: that is under the column of the
	# set rows' crosses, and this row slides there when the last set is taken
	# off, so a second tap meant for a cross would move the exercise.
	if exercises.size() > 1:
		acts.add_child(_move_key(i, true))
		acts.add_child(_move_key(i, false))
	c.add(Kit.pad(acts, 0, 2, 0, 0))
	# Under the keys: what goes on the bar (left) and the volume against last time (right).
	var foot = Kit.hbox(8)
	var pl = Kit.clip("", 11, Pal.MUTED)
	pl.set_meta("plates_line", "")
	pl.visible = false
	pl.size_flags_stretch_ratio = 3.0
	_plates.append(pl)
	foot.add_child(pl)
	var delta = Kit.vbox(0)
	delta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(delta)
	_deltas.append(delta)
	c.add(Kit.pad(foot, 6, 0, 4, 0))
	_refresh_exercise(i)
	_refresh_filed(i)
	return c


## What a name typed here will be saved as when the workout is finished:
## {"name", "move", "variation", "kind", "closest", "pt"}, or null for an empty
## name, for a lift that is in the log already (it keeps its name) and where
## names are not filed (a session from the phone note). The same steps as
## App.absorb_pt, which does the filing.
func filed_as(typed: String):
	if not _files_names:
		return null
	var tag = Pt.untag(typed)
	var n = str(tag.name).strip_edges()
	if n == "" or _have.has(Xp.normalize_exercise(n)):
		return null
	var r = LiftNames.resolve(n, _own)
	r["pt"] = bool(tag.pt)
	return r


## "March, variation Band" / "High Knee March, no variation".
static func filed_words(r: Dictionary) -> String:
	if str(r.variation) == "":
		return "%s, no variation" % str(r.move)
	return "%s, variation %s" % [str(r.move), str(r.variation)]


## For a movement of the player's own typed without a variation: how to write one.
static func filed_tip(r: Dictionary) -> String:
	if str(r.variation) != "" or str(r.kind) != "new":
		return ""
	return "A variation goes after a dash: %s - banded" % str(r.move)


## The line under an exercise's name, for a name that is new to the log: what
## it will be saved as (the user, 2026-11-23: "I don't just type in March -
## banded right because it takes that as the full name and not the exercise
## plus the variation modifier?" It is filed as the movement March with the
## variation Band, but only when the workout is saved, and nothing said so).
func _refresh_filed(i: int) -> void:
	if i >= _filed.size() or i >= exercises.size() or not is_instance_valid(_filed[i]):
		return
	var slot = _filed[i]
	Kit.clear(slot)
	# (a settled name is the card's title already: the movement and its variation)
	var r = null if (i < _titled.size() and bool(_titled[i])) else filed_as(str(exercises[i].name))
	slot.get_parent().visible = r != null
	slot.set_meta("filed_as", str(r.name) if r != null else "")
	if r == null:
		return
	var line = Kit.hbox(6)
	var cap = Kit.label("SAVED AS", 9, Pal.MUTED, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cap)
	var row = Kit.squeeze(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.soft_name(str(r.move), 12, null, true, 200.0))
	if str(r.variation) != "":
		row.add_child(SessionView.variation_tag(str(r.variation), 10, true))
	if bool(r.pt):
		row.add_child(Kit.vcenter(SessionView.pt_tag()))
	line.add_child(row)
	slot.add_child(line)
	var tip = filed_tip(r)
	slot.set_meta("filed_tip", tip != "")
	if tip != "":
		slot.add_child(Kit.para(tip, 11, Pal.MUTED))


## A key that moves an exercise one place up or down in the workout (the user,
## 2026-11-23: "Add a way to bump exercises up and down in order too, helps to
## decrease scrolling while super setting"). Its tooltip names the exercise:
## that is how the screen finds the key of the SAME exercise again after the
## move (UiScreen), so it stays under the finger and a second tap moves the
## same exercise once more. At the top (or the bottom) it is there, switched
## off, so nothing in the row changes place.
func _move_key(i: int, up: bool) -> Button:
	var nm = str(exercises[i].name).strip_edges()
	if nm == "":
		nm = "this exercise"
	var b = Kit.icon_button("arrow_up" if up else "arrow_down", move_exercise.bind(i, -1 if up else 1), "Move %s %s" % [nm, "up" if up else "down"], 28)
	b.disabled = (i == 0) if up else (i == exercises.size() - 1)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("move_key", "up" if up else "down")
	b.set_meta("move_of", i)
	return b


func _ref_set(lp, j: int):
	if lp == null or lp.sets.is_empty():
		return null
	return lp.sets[j] if j < lp.sets.size() else lp.sets[lp.sets.size() - 1]


## Re-draw the live parts of one exercise card: trend badges and the volume line.
func _refresh_exercise(i: int) -> void:
	if i >= _badges.size() or i >= exercises.size():
		return
	var e = exercises[i]
	var key = Xp.normalize_exercise(e.name)
	var lp = _last.get(key)
	var best = _bests.get(key)
	var best_kg = float(best.weightKg) if best != null else 0.0
	var banded = bool(e.get("band", false)) and not bool(e.get("timed", false))
	var slots = _badges[i]
	for j in range(mini(slots.size(), e.sets.size())):
		var slot = slots[j]
		if not is_instance_valid(slot):
			continue
		Kit.clear(slot)
		var s = e.sets[j]
		var cur = {"reps": TTUtil.jsround(LogWidgets.num(s.reps)), "weightKg": 0.0 if (e.bodyweight or bool(e.get("timed", false)) or banded) else Fmt.unit_to_kg(LogWidgets.num(s.weight), wu)}
		var prev = null
		if lp != null and j < lp.sets.size():
			prev = lp.sets[j]
		var trend = null
		if banded:
			# A band: a heavier or lighter one than that set last time, else the reps.
			cur["band"] = str(s.get("band", ""))
			trend = LiftHistory.compare_band_set(cur, prev, lp != null, int(_band_best.get(key, 0)))
		else:
			trend = LiftHistory.compare_set(cur, prev, lp != null, best_kg)
		var badge = _trend_badge(trend)
		if badge != null:
			slot.add_child(badge)
		if trend != null and str(trend.kind) == "pr":
			_celebrate_pr(i, j)
	_refresh_plates(i)
	_refresh_try(i)
	var dslot = _deltas[i] if i < _deltas.size() else null
	if dslot == null or not is_instance_valid(dslot):
		return
	Kit.clear(dslot)
	var cur_sets = sets_from_draft(e, wu)
	if lp == null or cur_sets.is_empty():
		return
	var vol = LiftHistory.volume_kg(cur_sets)
	var last_vol = LiftHistory.volume_kg(lp.sets)
	var reps = 0
	for s in cur_sets:
		reps += int(s.reps)
	var last_reps = 0
	for s in lp.sets:
		last_reps += int(s.reps)
	var text = ""
	var good = false
	var tip = "Volume (reps × weight) compared with last time"
	var now_band = Bands.level(Bands.top(cur_sets))
	var last_band = Bands.level(Bands.top(lp.sets))
	var held = 0
	for s in cur_sets:
		held += int(s.reps) * int(s.get("holdSec", 0))
	var last_held = 0
	for s in lp.sets:
		last_held += int(s.reps) * int(s.get("holdSec", 0))
	if bool(e.get("timed", false)) and (held > 0 or last_held > 0):
		# A hold: the seconds held in all.
		if held > last_held:
			text = "▲ %d s held" % (held - last_held)
			good = true
		elif held == last_held:
			text = "= last hold"
		else:
			text = "%d s to match" % (last_held - held)
	elif banded and now_band > 0 and last_band > 0 and now_band != last_band:
		# A band: the heaviest one against last time's (the reps say the rest).
		tip = "Your heaviest band compared with last time"
		if now_band > last_band:
			text = "▲ %s" % SessionView.band_change(now_band - last_band).substr(1)
			good = true
		else:
			text = "lighter band"
	elif e.bodyweight or last_vol == 0.0:
		if reps > last_reps:
			text = "▲ %d reps" % (reps - last_reps)
			good = true
		elif reps == last_reps:
			text = "= last reps"
		else:
			text = "%d reps to match" % (last_reps - reps)
	elif absf(vol - last_vol) <= maxf(0.3, last_vol * 0.0005):
		text = "= last volume"
	elif vol > last_vol:
		text = "▲ %s volume" % _fmt_w(vol - last_vol)
		good = true
	else:
		text = "%s to match" % _fmt_w(last_vol - vol)
	# (as wide as its words: it shares its line with the plates, which give way)
	var note = Kit.label(text, 12, Pal.GOOD_DARK if good else Pal.MUTED, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.tooltip_text = tip
	note.mouse_filter = Control.MOUSE_FILTER_PASS
	dslot.add_child(note)


## A set just became a PR: gold sparks and the PR sound, once per set. Sets that
## are already a PR when the card is built (an edit, a copied set) stay quiet.
func _celebrate_pr(i: int, j: int) -> void:
	var k = "%d:%d" % [i, j]
	if _pr_done.has(k):
		return
	_pr_done[k] = true
	if _building or i >= _wsteps.size() or j >= _wsteps[i].size():
		return
	var at = _wsteps[i][j]
	if is_instance_valid(at):
		Kit.burst(at, Pal.ACCENT, 18)
		Sfx.pr()


func _trend_badge(trend):
	if trend == null:
		return null
	var t = null
	match str(trend.kind):
		"pr":
			t = LogWidgets.badge("PR!", Pal.ACCENT, 12)
			t.tooltip_text = "A heavier band than ever on this exercise" if bool(trend.get("band", false)) else "Heavier than you have ever lifted on this exercise"
		"band":
			# "+1 band" / "-2 bands" (on a phone without the plural: the row's room).
			var dl = int(trend.delta)
			var said = SessionView.band_change(dl)
			if Kit.fingers and absi(dl) > 1:
				said = said.trim_suffix("s")
			t = LogWidgets.badge(said, Pal.GOOD if dl > 0 else Pal.ACCENT2, 11)
			t.tooltip_text = "A heavier band than last time" if dl > 0 else "A lighter band than last time"
		"weight":
			if absf(Fmt.kg_to_unit(float(trend.deltaKg), wu)) < 0.05:
				return null
			# (2026-11-27 review: "+5.12" lb, a kilogram difference turned into pounds, did not match the weights
			# shown, 187 against 181.9) In pounds to a tenth, as they are shown; kilograms keep 1.25 steps.
			var more = "+" + LogWidgets.trim_num(Fmt.kg_to_unit(float(trend.deltaKg), wu), 2 if wu == "kg" else 1)
			t = LogWidgets.badge(more if Kit.fingers else more + " " + wu, Pal.GOOD, 11)
			t.tooltip_text = "Heavier than last time"
		"reps":
			t = LogWidgets.badge("+%d rep%s" % [int(trend.delta), "" if int(trend.delta) == 1 or Kit.fingers else "s"], Pal.GOOD, 11)
			t.tooltip_text = "More reps than last time"
		"extra":
			t = LogWidgets.badge("+set", Pal.GOOD, 11)
			t.tooltip_text = "An extra set compared with last time"
	return t


# ---------------------------------------------------------------------------
# The "add an exercise" card: search, your exercises first, weight step chip
# ---------------------------------------------------------------------------

## (2026-11-27 review: its title was a line of text inside the parchment, unlike the signed windows around
## it) A window with ADD EXERCISE on its sign; on the sign's note how many are in the workout (an exercise
## added goes in above, out of sight, and this count says so) and the weight step key.
func _picker_card() -> Card:
	var in_count = exercises.size()
	var note = Kit.hbox(6)
	var ht = Kit.label("%d in workout" % in_count, 12, Pal.TEXT, true)
	ht.set_meta("picker_count", in_count)
	ht.visible = in_count > 0
	note.add_child(Kit.vcenter(ht))
	var step_chip = LogWidgets.mini_chip("± %s %s" % [TTUtil.num_str(_step()), wu], false, cycle_step, null, 8)
	step_chip.tooltip_text = "Weight step: how much one tap of + or − changes a weight (tap to change)"
	note.add_child(Kit.vcenter(step_chip))
	var c = Kit.section("log_add", "ADD EXERCISE", "plus", Pal.LIFT, note, Callable(), 6, 10)

	var row = Kit.hbox(6)
	var search = Kit.input(query, "Search or new exercise")
	search.set_meta(LogWidgets.FKEY, "search")
	# (typed in on a phone: right under the typing bar, with what it finds under it; and the box the page
	# keeps in place when an exercise is added from it)
	search.set_meta("type_top", true)
	search.set_meta("anchor_id", "log_search")
	search.select_all_on_focus = false
	search.custom_minimum_size = Vector2(48, LogWidgets.ROW_H)
	search.tooltip_text = "Your exercises come first. Tapping one brings back everything you did last time."
	LogWidgets._slim_edit(search, 10)
	search.text_changed.connect(_on_query)
	search.text_submitted.connect(func(_t): add_from_search())
	row.add_child(search)
	# (a green key that says what it does; the words are the heading the sign has in pixel letters)
	_add_btn = Kit.button("Add exercise", "good", add_from_search, "sm", "plus")
	_add_btn.custom_minimum_size.y = LogWidgets.ROW_H
	_add_btn.disabled = Xp.normalize_exercise(query) == ""
	row.add_child(_add_btn)
	c.add(row)

	_chips = Kit.flow(5)
	c.add(_chips)
	_no_match = Kit.para("", 11, Pal.MUTED)
	c.add(_no_match)
	# The same muscles as this workout (Prep.area_lifts): a key a lift, so a bench press on a push day is one
	# tap, not typed (the user, 2026-11-27).
	_area = Kit.vbox(4)
	_area.set_meta("area_box", true)
	c.add(_area)
	_fill_chips()
	return c


## The lifts that work the same muscles as the workout (its lifts', and the day's kind when it is today's):
## the player's own first, then the library's staples. Hidden while a search is typed.
func _fill_area() -> void:
	if _area == null or not is_instance_valid(_area):
		return
	Kit.clear(_area)
	if Xp.normalize_exercise(query) != "":
		return
	var f = _form()
	var kind = str(App.plan().get("kind", "")) if (f != null and str(f.date) == App.today) else ""
	var names = exercises.map(func(e): return str(e.name))
	var parts = Prep.area_parts(names.filter(func(n): return str(n).strip_edges() != ""), kind)
	# (not the keys the list above already shows)
	var list = Prep.area_lifts(parts, App.sessions(), names + _shown_names, App.pt(), 8)
	if list.is_empty():
		return
	# (11 px, cut off with "…" rather than widen the card when the day has many muscles)
	var cap = Kit.clip("SAME MUSCLES · " + ", ".join(PackedStringArray(parts.map(func(p): return LiftLibrary.part_name(str(p)).to_lower()))).to_upper(), 11, Pal.MUTED, true)
	cap.set_meta("area_caption", parts.size())
	_area.add_child(cap)
	var flow = Kit.flow(5)
	for e in list:
		var k = Xp.normalize_exercise(str(e.name))
		var chip = _ex_chip({"key": k, "name": str(e.name), "last": _last.get(k)})
		chip.set_meta("area_lift", str(e.name))
		flow.add_child(chip)
	_area.add_child(flow)


func _suggestions_have_history() -> bool:
	for s in _suggestions:
		if s.get("last") != null:
			return true
	return false


func _fill_chips() -> void:
	if _chips == null or not is_instance_valid(_chips):
		return
	Kit.clear(_chips)
	var in_form = {}
	for e in exercises:
		in_form[Xp.normalize_exercise(e.name)] = true
	var q = Xp.normalize_exercise(query)
	var shown = []
	var limit = 12 if q != "" or show_all_chips else CHIPS_COLLAPSED
	var more_left = false
	if q != "":
		# Every typed word in the name, at the start of a word, inside one or one typo away: "bay curl",
		# "baysian". Your own lifts first, then every movement and variation of the lift library
		# (2026-11-27: a lift never done, a Bayesian curl, could not be found by its name).
		var by_key = {}
		var mine = []
		for s in _suggestions:
			if not in_form.has(s.key):
				by_key[s.key] = s
				if s.get("last") != null or int(s.get("count", 0)) > 0:
					mine.append(str(s.name))
		for nm in LiftLibrary.search(query, mine, limit + in_form.size()):
			var k = Xp.normalize_exercise(nm)
			if in_form.has(k) or shown.size() >= limit:
				continue
			shown.append(by_key.get(k, {"key": k, "name": nm, "count": 0}))
	else:
		for s in _suggestions:
			if in_form.has(s.key):
				continue
			if shown.size() >= limit:
				more_left = true
				break
			shown.append(s)
	_shown_names = shown.map(func(x): return str(x.name))
	for s in shown:
		_chips.add_child(_ex_chip(s))
	if q == "" and (more_left or show_all_chips):
		var more = LogWidgets.mini_chip("Less" if show_all_chips else "More…", false, _toggle_more_chips)
		more.tooltip_text = "Show fewer exercises" if show_all_chips else "Show more exercises"
		_chips.add_child(more)
	if is_instance_valid(_no_match):
		# A new exercise: how Add will file it (the movement, and its variation).
		var said = ""
		var filing = filed_as(query) if (q != "" and shown.is_empty()) else null
		if filing != null:
			var tip = filed_tip(filing)
			said = "New exercise: tap Add. It is saved as %s.%s" % [filed_words(filing), (" %s." % tip) if tip != "" else ""]
		elif q != "" and shown.is_empty():
			said = "New exercise: tap Add"
		_no_match.text = said
		_no_match.visible = said != ""
		_no_match.set_meta("filed_as", str(filing.name) if filing != null else "")
	if is_instance_valid(_add_btn):
		_add_btn.disabled = q == ""
	_fill_area()


## One tappable exercise key: "Bench Press  Barbell  85×5" (the movement, its
## variation quieter, the last top set; your own ones have a lift-coloured edge).
func _ex_chip(s: Dictionary) -> Button:
	var lp = s.get("last")
	var h = Kit.hbox(5)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var sp = LiftNames.split(str(s.name))
	# The movement and the variation are cut off with "…" past a width: a key
	# with a long variation ("Single arm incline home cable") was wider than
	# the card, and one key too wide widens the whole page.
	var nm = Kit.clip_fit(str(sp.move), 12, Pal.TEXT, true, CHIP_MOVE_W)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	if str(sp.variation) != "":
		var vl = Kit.clip_fit(str(sp.variation), 11, Pal.MUTED, false, CHIP_VARIATION_W)
		vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(vl)
	if lp != null:
		var top = LiftHistory.top_set_label(lp.sets, func(kg): return Fmt.kg_to_unit(float(kg), wu))
		if top != "":
			var tl = Kit.label(top, 11, Pal.ACCENT, true)
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(tl)
	var b = LogWidgets.key(str(s.name), Pal.PANEL2, h, add_exercise.bind(str(s.name)), 9, 4, 1, Pal.LIFT if lp != null else Pal.LINE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.tooltip_text = str(s.name)
	if lp != null:
		b.tooltip_text = "%s\nLast top set: %s" % [str(s.name), LiftHistory.top_set_label(lp.sets, func(kg): return Fmt.kg_to_unit(float(kg), wu))]
	return b


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _form():
	return _form_ref.get_ref() if _form_ref != null else null


func _set_focus_after(fkey: String) -> void:
	var f = _form()
	if f != null and is_instance_valid(f.screen):
		f.screen.focus_key = fkey


func _changed(rebuild_all: bool) -> void:
	var f = _form()
	if f != null:
		f.on_draft_changed(rebuild_all)


func add_exercise(ex_name: String, from_search: bool = false) -> void:
	var key = Xp.normalize_exercise(ex_name)
	if key == "":
		return
	Sfx.tick()
	var lp = _last.get(key)
	if lp != null:
		exercises.append(draft_from_sets(str(lp.name), lp.sets, wu))
	else:
		exercises.append(_blank(ex_name))
	query = ""
	var i = exercises.size() - 1
	if lp == null:
		_set_focus_after("ex%d.s0.reps" % i)
	elif from_search:
		_set_focus_after("search")
	# The new card goes in above the search: the search (and its list) stays where it was, so the next one is
	# picked without looking for it again (the key that was tapped is gone, and the page had nothing to hold).
	var f = _form()
	if f != null and is_instance_valid(f.screen):
		f.screen.hold_anchor_id = "log_search"
	_changed(true)


## A key of "From today's plan" (LogPlanCard): the lift goes into the workout
## with last time's sets, marked planned until it is touched, and comes out
## again at a second tap while it still is. One that has the player's own
## numbers is not taken out by a tap here: its card has the cross for that.
func plan_toggle(ex_name: String) -> void:
	var key = Xp.normalize_exercise(ex_name)
	if key == "":
		return
	for i in range(exercises.size()):
		if Xp.normalize_exercise(str(exercises[i].name)) != key:
			continue
		if bool(exercises[i].get("planned", false)):
			Sfx.unpop()
			exercises.remove_at(i)
			_changed(true)
		else:
			Sfx.tick()
			App.toast("%s has your sets. Take it out with the cross on its card." % Missions.short_name(ex_name), "info", "lift")
		return
	Sfx.pop()
	var one = _prepped_draft(ex_name)
	if one == null:
		var lp = _last.get(key)
		one = draft_from_sets(str(lp.name), lp.sets, wu) if lp != null else _blank(ex_name)
	one["planned"] = true
	exercises.append(one)
	_changed(true)


func add_from_search() -> void:
	var q = Xp.normalize_exercise(query)
	if q == "":
		return
	var nm = query
	for s in _suggestions:
		if s.key == q:
			nm = str(s.name)
	add_exercise(nm, true)


func apply_template(t: Dictionary) -> void:
	Sfx.tap()
	# Same line-up, but each exercise starts from its most recent numbers.
	exercises = []
	for e in t.exercises:
		if not _has_reps(e.sets):
			continue
		var lp = _last.get(Xp.normalize_exercise(e.name))
		exercises.append(draft_from_sets(str(e.name).strip_edges(), lp.sets if lp != null else e.sets, wu))
	_changed(true)


func add_set(i: int) -> void:
	Sfx.pop()
	Sfx.buzz(1)
	_touched(i)
	var sets = exercises[i].sets
	var copy = sets[sets.size() - 1].duplicate() if not sets.is_empty() else {"reps": "", "weight": ""}
	sets.append(copy)
	_changed(true)


func remove_set(i: int, j: int) -> void:
	Sfx.unpop()
	_touched(i)
	exercises[i].sets.remove_at(j)
	_changed(true)


## Move an exercise one place up (-1) or down (+1) in the workout. Its sets,
## and whether it is still as the plan filled it in, go with it.
func move_exercise(i: int, d: int) -> void:
	var j = i + d
	if i < 0 or j < 0 or i >= exercises.size() or j >= exercises.size():
		return
	Sfx.tick()
	var e = exercises[i]
	exercises[i] = exercises[j]
	exercises[j] = e
	# The sets that already celebrated a record go with their exercise.
	var done = {}
	for k in _pr_done:
		var parts = str(k).split(":")
		var a = int(parts[0])
		if a == i:
			a = j
		elif a == j:
			a = i
		done["%d:%s" % [a, parts[1]]] = true
	_pr_done = done
	# And so does the typing cursor.
	var f = _form()
	if f != null and is_instance_valid(f.screen) and f.screen.is_inside_tree():
		var own = f.screen.get_viewport().gui_get_focus_owner()
		if own != null and own.has_meta(LogWidgets.FKEY):
			var fk = str(own.get_meta(LogWidgets.FKEY))
			for pair in [[i, j], [j, i]]:
				var head = "ex%d." % int(pair[0])
				if fk.begins_with(head):
					f.screen.focus_key = "ex%d." % int(pair[1]) + fk.substr(head.length())
					break
	_changed(true)


func remove_exercise(i: int) -> void:
	Sfx.unpop()
	exercises.remove_at(i)
	_changed(true)


func bump_all(i: int, field: String) -> void:
	if field == "band":
		# Every set one band heavier; at the heaviest band already, nothing moves.
		var any = false
		for s in exercises[i].sets:
			var was = str(s.get("band", "")).strip_edges()
			if was == "":
				was = _band_fill(exercises[i])
			s["band"] = Bands.step(was, 1)
			if s.band != was:
				any = true
		if not any:
			Sfx.error()
			return
		Sfx.step(1)
		_touched(i)
		_changed(true)
		return
	Sfx.tick()
	_touched(i)
	for s in exercises[i].sets:
		if field == "reps":
			s.reps = TTUtil.num_str(LogWidgets.num(s.reps) + 1.0)
		elif field == "hold":
			s["hold"] = TTUtil.num_str(LogWidgets.num(s.get("hold", "")) + 5.0)
		else:
			s.weight = LogWidgets.trim_num(LiftHistory.step_value(LogWidgets.num(s.weight), _step(), 1))
	_changed(true)


func _toggle_more_chips() -> void:
	Sfx.tick()
	show_all_chips = not show_all_chips
	_fill_chips()


func cycle_step() -> void:
	var opts = TT.WEIGHT_STEPS[wu]
	var cur = _step()
	var idx = 0
	for k in range(opts.size()):
		if is_equal_approx(float(opts[k]), cur):
			idx = k
	App.update_settings({"weightStep": opts[(idx + 1) % opts.size()]})
	Sfx.tick()
	_changed(true)


func _toggle_bw(i: int) -> void:
	_set_mode(i, "bw")


## A hold (a stretch): seconds where the weight would be.
func _toggle_timed(i: int) -> void:
	_set_mode(i, "hold")


## A resistance band where the weight would be (Bands), or back to a weight.
func _toggle_band(i: int) -> void:
	_set_mode(i, "band")


## A set's band was changed on its picker: in place, nothing is rebuilt (the
## picker has already redrawn itself), as a number typed into a set.
func _on_band(id: String, i: int, j: int) -> void:
	if i >= exercises.size() or j >= exercises[i].sets.size():
		return
	exercises[i].sets[j]["band"] = str(id)
	if bool(exercises[i].get("planned", false)):
		_touched(i)
		_paint_edge(i)
	_refresh_exercise(i)
	_changed(false)


## What goes beside the reps: [mode, the key's text, its tooltip], in the track's order.
const MODES = [
	["weight", "Weight", "A weight on the bar, the dumbbells or the stack"],
	["bw", "BW", "Bodyweight exercise (no weight)"],
	["band", "Band", "Done with a resistance band: a band instead of a weight"],
	["hold", "Hold", "A stretch or a hold: seconds instead of weight"],
]


static func _mode_of(e: Dictionary) -> String:
	if bool(e.get("timed", false)):
		return "hold"
	if bool(e.get("band", false)):
		return "band"
	if bool(e.get("bodyweight", false)):
		return "bw"
	return "weight"


## A key of the track: that is what goes beside the reps now. The key that is
## on, tapped again, goes back to a weight (as BW and Hold always did). Into a
## band: every set gets the band this lift was done with last time, else the
## one its name says, else the one used last on any lift, else Bands.DEFAULT
## (_band_fill).
func _set_mode(i: int, m: String) -> void:
	if i >= exercises.size():
		return
	var e = exercises[i]
	var was = _mode_of(e)
	if m == was:
		if m == "weight":
			return
		m = "weight"
	Sfx.tick()
	_touched(i)
	e["bodyweight"] = m == "bw"
	e["timed"] = m == "hold"
	if m == "band":
		e["band"] = true
		var fill = _band_fill(e)
		for s in e.sets:
			s["band"] = fill
	else:
		e.erase("band")
	_changed(true)


## Is this exercise a physical therapy one: what the PT key says once it was
## touched in this workout, else "(PT)" typed in front of its name, else the
## lift's mark (Pt). Saved by App.absorb_pt (session_exercises passes it on).
func _pt_on(e: Dictionary) -> bool:
	if e.get("pt") is bool:
		return bool(e.pt)
	var tag = Pt.untag(str(e.get("name", "")))
	return bool(tag.pt) or Pt.is_pt(App.pt(), str(tag.name).strip_edges())


## What saving will do about PT, when the key says something the lift is not yet:
## "" when it says what the lift already is.
func _pt_words(e: Dictionary) -> String:
	if not (e.get("pt") is bool):
		return ""
	var tag = Pt.untag(str(e.get("name", "")))
	var was = Pt.is_pt(App.pt(), str(tag.name).strip_edges())
	if bool(e.pt) and not was:
		return "PT · saved as physical therapy: counts toward today's PT"
	if not bool(e.pt) and was:
		return "Not PT · no longer physical therapy once saved"
	return ""


## The PT key: this exercise is physical therapy, or is not.
func _toggle_pt(i: int) -> void:
	if i >= exercises.size():
		return
	Sfx.tick()
	exercises[i]["pt"] = not _pt_on(exercises[i])
	_changed(true)


## Are this exercise's reps both sides added up: what the "L+R" key says once
## it was touched in this workout, else what is known of the lift (Sides).
func _both(e: Dictionary) -> bool:
	if e.has("both"):
		return bool(e.both)
	return Sides.both(App.settings(), str(e.get("name", "")).strip_edges())


## A single arm or single leg lift typed as one number for both sides, or not.
## It goes with the workout: stored for the lift when the workout is saved.
func _toggle_both(i: int) -> void:
	if i >= exercises.size():
		return
	Sfx.tick()
	exercises[i]["both"] = not _both(exercises[i])
	_changed(true)


func _on_set_text(text: String, i: int, j: int, field: String) -> void:
	if i >= exercises.size() or j >= exercises[i].sets.size():
		return
	exercises[i].sets[j][field] = text
	if bool(exercises[i].get("planned", false)):
		# The first touch of a planned exercise: it is this workout's now. Its
		# edge (its plate's ring) lights up in place (a rebuild would take the keyboard away).
		_touched(i)
		_paint_edge(i)
	_refresh_exercise(i)
	_changed(false)


func _on_name_typed(text: String, i: int) -> void:
	if i < exercises.size():
		exercises[i].name = text
		_refresh_filed(i)
		_changed(false)


## Left the name box: a known exercise typed into a still-empty card brings up last time's sets.
func _on_name_done(i: int) -> void:
	if _building or i >= exercises.size():
		return
	var e = exercises[i]
	var renamed = bool(e.get("_rename", false))
	e.erase("_rename")
	var lp = _last.get(Xp.normalize_exercise(e.name))
	var pristine = true
	for s in e.sets:
		if str(s.reps) != "" or str(s.weight) != "" or str(s.get("hold", "")) != "":
			pristine = false
	if lp != null and pristine:
		exercises[i] = draft_from_sets(str(e.name).strip_edges(), lp.sets, wu)
		_changed(true)
	elif renamed or (i < _built_names.size() and str(e.name).strip_edges() != _built_names[i]):
		_changed(true)


func _on_query(text: String) -> void:
	query = text
	_fill_chips()


# ---------------------------------------------------------------------------
# Ticking sets off, the aim, plates, supersets, swapping, how hard (2026-11-27)
# ---------------------------------------------------------------------------

func label_name_of(i: int) -> String:
	var nm = str(exercises[i].name).strip_edges() if i < exercises.size() else ""
	return nm if nm != "" else "Exercise %d" % (i + 1)


## The card's edge: quiet while as the plan filled it in, green once every set with reps is ticked, else the
## colour of the muscle it works.
func _edge_color(i: int) -> Color:
	var e = exercises[i]
	if bool(e.get("planned", false)):
		return Pal.LINE
	if all_ticked(i):
		return Pal.GOOD
	var part = str(Missions.part_of(str(e.name)))
	return JourneyLifts.part_color(part) if part != "" else Pal.LIFT


func all_ticked(i: int) -> bool:
	var any = false
	for s in exercises[i].sets:
		if LogWidgets.num(s.reps) > 0.0:
			if not bool(s.get("done", false)):
				return false
			any = true
	return any


## The tick at the start of a set's row: its number in an empty box, a green tick once done (Kit.tick_box).
## Its tooltip names the lift and the set and never changes, so the screen keeps it under the finger.
func _tick_key(i: int, j: int, label_name: String) -> Button:
	var done = bool(exercises[i].sets[j].get("done", false))
	var b = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "%s: set %d done" % [label_name, j + 1]
	b.set_meta("set_tick", "%d:%d" % [i, j])
	b.set_meta("set_done", done)
	# (at finger sizes Kit.tick_box adds 4: the row has no room for more than the number had)
	var box = Kit.tick_box(done, 18 if Kit.fingers else 20)
	if not done:
		# A set still to do: its number in dark ink on a tan key, the mock-up's set key. (2026-11-27 review:
		# a 14 px pixel digit in a 20 px box lost its top and bottom rows under the rim, pale on white)
		var tc = PixBox.block_colors("tan")
		box.add_theme_stylebox_override("panel", PixBox.nine([tc[0], PixBox.bev(tc[1], tc[2])], tc[3], {"cut": 0, "pad_h": 0, "pad_v": 0}))
		var num = Kit.label(str(j + 1), 13, Pal.INK, true)
		num.add_theme_constant_override("line_spacing", 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.get_child(0).add_child(num)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.custom_minimum_size = box.custom_minimum_size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_child(box)
	b.pressed.connect(toggle_set_done.bind(i, j))
	return b


## Tick a set off (or take the tick back). An empty set is filled in from last time first; a set with no
## reps and nothing to fill it from cannot be ticked. In a superset, says which set is next.
func toggle_set_done(i: int, j: int) -> void:
	if i >= exercises.size() or j >= exercises[i].sets.size():
		return
	var e = exercises[i]
	var s = e.sets[j]
	if bool(s.get("done", false)):
		s.erase("done")
		Sfx.unpop()
		_changed(true)
		return
	if LogWidgets.num(s.reps) <= 0.0:
		var ref = _ref_set(_last.get(Xp.normalize_exercise(str(e.name))), j)
		if ref == null or int(ref.reps) <= 0:
			Sfx.error()
			App.toast("Put in the reps first, then tick it", "info", "lift")
			return
		s.reps = str(int(ref.reps))
		if not e.bodyweight and not bool(e.get("timed", false)) and not bool(e.get("band", false)) and str(s.weight).strip_edges() == "" and float(ref.get("weightKg", 0)) > 0.0:
			s.weight = LogWidgets.trim_num(Fmt.kg_to_unit(float(ref.weightKg), wu))
	s["done"] = true
	_touched(i)
	if started <= 0.0:
		started = Time.get_unix_time_from_system()
	Sfx.pop()
	Sfx.buzz(1)
	var nxt = _superset_next(i)
	if nxt != "":
		App.toast(nxt, "info", "repeat")
	elif all_ticked(i):
		App.toast("%s: every set done" % Missions.short_name(label_name_of(i)), "good", "check")
	_changed(true)


## In a superset: "Next: Lateral Raise, set 2", the next lift of the pair with a set still to do.
func _superset_next(i: int) -> String:
	var g = exercises[i].get("ss")
	if g == null:
		return ""
	var n = exercises.size()
	for step in range(1, n):
		var k = (i + step) % n
		if exercises[k].get("ss") != g:
			continue
		for j in range(exercises[k].sets.size()):
			if not bool(exercises[k].sets[j].get("done", false)):
				return "Next: %s, set %d" % [Missions.short_name(label_name_of(k)), j + 1]
	return ""


## Sets with reps that are not ticked, in exercises where something IS ticked (the player is ticking as
## they go: an unticked set there may not have been done).
func unticked_count() -> int:
	var n = 0
	for e in exercises:
		if not e.sets.any(func(x): return bool(x.get("done", false))):
			continue
		for x in e.sets:
			if LogWidgets.num(x.reps) > 0.0 and not bool(x.get("done", false)):
				n += 1
	return n


func drop_unticked() -> void:
	for e in exercises:
		if not e.sets.any(func(x): return bool(x.get("done", false))):
			continue
		e.sets = e.sets.filter(func(x): return bool(x.get("done", false)) or LogWidgets.num(x.reps) <= 0.0)


## What to aim for on this exercise: the day's plan's aim when it is planned today (App.aim_for), else one
## more step past last time. {"cap", "words", "sets"} or null.
func _aim_of(i: int):
	var e = exercises[i]
	var nm = str(e.name).strip_edges()
	if nm == "" or editing_id != null:
		return null
	var a = App.aim_for(nm, _both(e))
	if a == null or (a.sets as Array).is_empty():
		return null
	return {"cap": str(a.get("cap", "AIM")), "words": LiftHistory.describe_sets(a.sets, _fmt_w), "sets": a.sets}


## Every set as the aim says (the sets past the aim's stay as they are).
func fill_aim(i: int) -> void:
	var a = _aim_of(i)
	if a == null:
		return
	Sfx.pop()
	_touched(i)
	var e = exercises[i]
	var rows = draft_from_sets(str(e.name), a.sets, wu).sets
	for j in range(rows.size()):
		var row = rows[j]
		if j < e.sets.size():
			var keep_done = bool(e.sets[j].get("done", false))
			e.sets[j] = row
			if keep_done:
				row["done"] = true
		else:
			e.sets.append(row)
	_changed(true)


func _refresh_plates(i: int) -> void:
	if i >= _plates.size() or not is_instance_valid(_plates[i]):
		return
	var e = exercises[i]
	var lab = _plates[i]
	var t = ""
	if not e.bodyweight and not bool(e.get("timed", false)) and not bool(e.get("band", false)) and Plates.is_barbell(str(e.name)):
		var top = 0.0
		for s in e.sets:
			top = maxf(top, LogWidgets.num(s.weight))
		if top > 0.0:
			t = Plates.text(top, wu)
	lab.text = ("Plates: " + t) if t != "" else ""
	lab.visible = t != ""
	lab.set_meta("plates_line", t)


# --- supersets: exercises next to each other with the same "ss" are done in turn ---------------------------

func linked_next(i: int) -> bool:
	if i < 0 or i + 1 >= exercises.size():
		return false
	var g = exercises[i].get("ss")
	return g != null and exercises[i + 1].get("ss") == g


## "A1", "A2", "B1"... for every exercise in a superset (a run of linked exercises), "" for the others.
func _group_labels() -> Array:
	var out = []
	var letter = -1
	var pos = 0
	for i in range(exercises.size()):
		var with_prev = i > 0 and linked_next(i - 1)
		var with_next = linked_next(i)
		if with_prev:
			pos += 1
			out.append("%s%d" % [char(65 + letter), pos])
		elif with_next:
			letter += 1
			pos = 1
			out.append("%s%d" % [char(65 + letter), pos])
		else:
			out.append("")
	return out


func group_label(i: int) -> String:
	if i < 0:
		return ""
	var labels = _group_labels()
	return str(labels[i]) if i < labels.size() else ""


func _new_group() -> int:
	var most = 0
	for e in exercises:
		if e.get("ss") != null:
			most = maxi(most, int(e.ss))
	return most + 1


## Link this exercise with the next one (a superset), or, when they are linked, part them.
func link_next(i: int) -> void:
	if i < 0 or i + 1 >= exercises.size():
		return
	if linked_next(i):
		var g = exercises[i].ss
		var fresh = _new_group()
		for k in range(i + 1, exercises.size()):
			if exercises[k].get("ss") != g:
				break
			exercises[k]["ss"] = fresh
		Sfx.unpop()
	else:
		var g2 = exercises[i].get("ss")
		if g2 == null:
			g2 = exercises[i + 1].get("ss") if exercises[i + 1].get("ss") != null else _new_group()
		var old = exercises[i + 1].get("ss")
		exercises[i]["ss"] = g2
		for e in exercises:
			if old != null and e.get("ss") == old:
				e["ss"] = g2
		exercises[i + 1]["ss"] = g2
		Sfx.pop()
		App.toast("Superset: %s and %s, done in turn" % [Missions.short_name(label_name_of(i)), Missions.short_name(label_name_of(i + 1))], "info", "repeat")
	_tidy_groups()
	_changed(true)


## Take one exercise out of its superset (the others stay together).
func unlink(i: int) -> void:
	if i < 0 or i >= exercises.size():
		return
	exercises[i].erase("ss")
	var fresh = _new_group()
	for k in range(i + 1, exercises.size()):
		if k > i + 1 and not linked_next(k - 1):
			break
		if exercises[k].get("ss") != null:
			exercises[k]["ss"] = fresh
	Sfx.unpop()
	_tidy_groups()
	_changed(true)


## A group of one is no group.
func _tidy_groups() -> void:
	for i in range(exercises.size()):
		if exercises[i].get("ss") != null and not linked_next(i) and not (i > 0 and linked_next(i - 1)):
			exercises[i].erase("ss")


## The line between two linked cards: a blue tag in the middle and two blue rails that run from the card
## above into the card below. (2026-11-27 review: 10 px blue words straight on the dark planks, hard to
## read, and nothing joined the two cards)
func _superset_line(i: int) -> Control:
	var rail = SupersetRail.new()
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.set_meta("superset_line", i)
	var tag = PanelContainer.new()
	tag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", Kit.tag_box(Pal.SECOND, 9, 3))
	var h = Kit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("repeat", 16, Pal.CREAM)))
	h.add_child(Kit.vcenter(Kit.tag_words("SUPERSET · ONE SET EACH IN TURN", 12, Pal.SECOND)))
	tag.add_child(h)
	rail.add_child(tag)
	return rail


## The superset line's ground: two blue rails (a dark edge, a lit side) at its two ends, reaching past its
## own top and bottom into the wooden frames of the two cards (drawn over them), so the pair reads as one.
## At the very edges: the plate with a card's name is in the middle, never under them.
class SupersetRail extends CenterContainer:
	## How far the rails reach past the line: the screen's gap is 12 on each side, the card above ends in
	## its shadow, the card below's frame starts half way down its name plate.
	const REACH_UP = 20.0
	const REACH_DOWN = 34.0
	const INSET = 4.0
	const W = 6.0

	func _init() -> void:
		z_index = 1

	func _draw() -> void:
		for x in [INSET, size.x - INSET - W]:
			var r = Rect2(x, -REACH_UP, W, size.y + REACH_UP + REACH_DOWN)
			draw_rect(r.grow(2.0), Pal.OUTLINE)
			draw_rect(r, Pal.SECOND)
			draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), Pal.SECOND.lightened(0.35))
			draw_rect(Rect2(Vector2(r.end.x - 2.0, r.position.y), Vector2(2.0, r.size.y)), Pal.SECOND_DARK)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Swap an exercise for another way of doing it: in its place, with as many sets, filled in from that lift's
## last time (none: its first set empty, then copies). The superset and "planned" stay.
func swap_exercise(i: int, new_name: String) -> void:
	if i < 0 or i >= exercises.size() or new_name.strip_edges() == "":
		return
	var old = exercises[i]
	var n = maxi(1, old.sets.size())
	var lp = _last.get(Xp.normalize_exercise(new_name))
	var one = draft_from_sets(str(lp.name), lp.sets, wu) if lp != null else _blank(new_name)
	while one.sets.size() < n:
		one.sets.append(one.sets[one.sets.size() - 1].duplicate())
	while one.sets.size() > n:
		one.sets.remove_at(one.sets.size() - 1)
	for s in one.sets:
		s.erase("done")
	for k in ["ss", "planned"]:
		if old.get(k) != null:
			one[k] = old[k]
	exercises[i] = one
	Sfx.pop()
	App.toast("Swapped for %s" % Missions.short_name(new_name), "good", "repeat")
	_changed(true)


func set_effort(i: int, id: String) -> void:
	if i < 0 or i >= exercises.size():
		return
	Sfx.tick()
	if id == "":
		exercises[i].erase("effort")
	else:
		exercises[i]["effort"] = id
	_changed(true)


# ---------------------------------------------------------------------------
# The card's title, its reference box and its done sets (2026-11-27)
# ---------------------------------------------------------------------------

## Is the exercise's name settled: a lift that will be saved under the name shown (one of the player's, or
## a lift of the library written as the library writes it), and not being renamed? Then the card's title
## is the movement with its variation as a tag, like everywhere else, and a tap on it renames.
func _named(i: int) -> bool:
	var e = exercises[i]
	var nm = str(e.name).strip_edges()
	if nm == "" or bool(e.get("_rename", false)) or not _files_names:
		return false
	if _have.has(Xp.normalize_exercise(nm)):
		return true
	var r = filed_as(nm)
	return r != null and str(r.name) == nm and str(r.kind) == "exact" and not bool(r.get("pt", false))


## The card's title: the movement in cream on a plate (Kit.sign_box, ringed in the card's edge colour) with
## its variation as a tag, on the card's top edge. A key: a tap renames.
func _name_title(i: int) -> Button:
	var nm = str(exercises[i].name).strip_edges()
	var sp = LiftNames.split(nm)
	var b = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var none = StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, none)
	# (the tooltip names the lift and never changes: a rebuild finds the same key again)
	b.tooltip_text = "Rename %s" % nm
	b.set_meta("name_title", nm)
	var h = Kit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (as wide as the words, up to a width: a long name is cut off with "…", never wider than the card)
	var mv = Kit.clip_fit(str(sp.move), 16, Pal.CREAM, true, 200.0)
	mv.add_theme_constant_override("outline_size", Kit.outline_for(16))
	mv.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mv)
	if str(sp.variation) != "":
		var vt = SessionView.variation_tag(str(sp.variation), 11, false)
		var vl = vt.get_child(0) as Label
		var vw = Kit.font_bold().get_string_size(str(sp.variation), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if vw > 118.0:
			vl.clip_text = true
			vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			vl.custom_minimum_size.x = 118.0
		h.add_child(Kit.vcenter(vt))
	var plate = _plate(i, h)
	b.add_child(plate)
	_fit_plate(b, plate)
	b.pressed.connect(_rename.bind(i))
	return b


## The plate of a name not settled yet (a new name being typed, a rename, a lift from the phone note): what
## it is, in the sign's pixel letters; the name's box is in the first row under it.
func _plain_plate(i: int) -> Control:
	var e = exercises[i]
	var nm = str(e.name).strip_edges()
	var words = "NEW EXERCISE"
	if bool(e.get("_rename", false)):
		words = "RENAME"
	elif nm != "" and not _files_names:
		words = "EXERCISE %d" % (i + 1)
	var plate = _plate(i, PixelFont.rect(words, 2, Pal.CREAM))
	plate.set_meta("plain_plate", words)
	return plate


## A plate in the card's edge colour holding `content` (kept in _signs, so _paint_edge can recolour it).
func _plate(i: int, content: Control) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Kit.sign_box(_edge_color(i)))
	p.add_child(content)
	while _signs.size() <= i:
		_signs.append(null)
	_signs[i] = p
	return p


## A Button holding a plate is as big as the plate (and grows with it once its words are measured).
static func _fit_plate(b: Button, plate: Control) -> void:
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fit = func():
		if is_instance_valid(b) and is_instance_valid(plate):
			b.custom_minimum_size = plate.get_combined_minimum_size()
	fit.call()
	plate.minimum_size_changed.connect(fit)
	b.ready.connect(fit)


## The card's edge colour changed (the first touch of a lift the plan filled in): its plate's ring follows,
## in place (a rebuild would take the keyboard away).
func _paint_edge(i: int) -> void:
	if i < _signs.size() and _signs[i] != null and is_instance_valid(_signs[i]):
		(_signs[i] as PanelContainer).add_theme_stylebox_override("panel", Kit.sign_box(_edge_color(i)))


## The title tapped: the name box comes back for typing (a phone opens its keyboard on the next tap).
func _rename(i: int) -> void:
	if i >= exercises.size():
		return
	Sfx.tap()
	exercises[i]["_rename"] = true
	_set_focus_after("ex%d.name" % i)
	_changed(true)


## LAST (sets, when, the best as a gold word) and AIM (with Fill) side by side on a paper slip; either
## alone when there is only one. Null when there is neither.
## (2026-11-27 review: 9 px captions in orange and gold on a dark well, a wall of small text in the most used
## card) As the mock-up: a cream slip (a dark well is for numbers being typed), 11 px captions, the sets in
## 13 px dark ink, and a green Fill key.
func _ref_block(i: int, lp, best, banded: bool, both: bool):
	var has_best = best != null and float(best.weightKg) > 0.0
	var aim = _aim_of(i)
	if lp == null and aim == null and not has_best:
		return null
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", PixBox.material("slip", {"pad_h": 9, "pad_v": 6}))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.set_meta("ref_block", true)
	var h = Kit.hbox(10)
	if lp != null or has_best:
		var lv = Kit.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap = Kit.hbox(6)
		var when = ("LAST · " + Dates.relative_day(lp.date, App.today).to_upper()) if lp != null else "BEST"
		cap.add_child(Kit.clip(when, 11, Pal.MUTED, true))
		if has_best and lp != null:
			var bt = Kit.label("BEST " + _fmt_w(best.weightKg), 11, Pal.ACCENT_DARK, true)
			bt.set_meta("best_tag", true)
			cap.add_child(bt)
		lv.add_child(cap)
		var words = ""
		if lp != null:
			words = LiftHistory.describe_sets(lp.sets, _fmt_w)
			# (done with a band before bands could be logged: it was no bodyweight lift)
			if banded and Bands.top(lp.sets) == "":
				words = words.replace(" bodyweight", "")
			if both and Sides.side_words(lp.sets) != "":
				words += " · " + Sides.side_words(lp.sets)
		else:
			words = _fmt_w(best.weightKg)
		var ll = Kit.clip(words, 13, Pal.TEXT, true)
		ll.set_meta("last_line", words)
		lv.add_child(ll)
		lv.tooltip_text = ("Last time: %s" % Dates.relative_day(lp.date, App.today)) if lp != null else "Your best"
		lv.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(lv)
	if aim != null:
		if h.get_child_count() > 0:
			var line = ColorRect.new()
			line.color = Pal.LINE
			line.custom_minimum_size = Vector2(2, 0)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(line)
		var av = Kit.vbox(0)
		av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		av.add_child(Kit.clip(str(aim.cap), 11, Pal.ACCENT2, true))
		av.add_child(Kit.clip(str(aim.words), 13, Pal.TEXT, true))
		av.set_meta("aim_line", str(aim.words))
		h.add_child(av)
		var fk = Kit.button("Fill", "good", fill_aim.bind(i), "sm")
		fk.tooltip_text = "%s: fill in the aim" % label_name_of(i)
		fk.set_meta("fill_aim", i)
		h.add_child(Kit.vcenter(fk))
	p.add_child(h)
	return p


## The ground under a set's row: a green wash once the set is ticked, nothing before (no margins either
## way, so a tick never changes the row's size).
static func _set_bg(done: bool) -> PanelContainer:
	var p = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb = StyleBoxFlat.new()
	sb.bg_color = Pal.with_alpha(Pal.GOOD, 0.16) if done else Color(0, 0, 0, 0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.set_meta("set_row_done", done)
	return p


# ---------------------------------------------------------------------------
# Records to try (Challenges, 2026-11-27): on a workout of today, each lift with a history shows the day's
# records to go for (heavier than ever, a rep record at a weight done before, the best for N reps). A key
# lights up the moment the sets do it (a cheer, once); a tap puts it into the next set not ticked.
# ---------------------------------------------------------------------------

func _try_options(i: int) -> Array:
	var f = _form()
	if editing_id != null or f == null or str(f.date) != App.today or i >= exercises.size():
		return []
	var nm = str(exercises[i].name).strip_edges()
	if nm == "" or not _have.has(Xp.normalize_exercise(nm)):
		return []
	return App.challenge_options(nm)


func _refresh_try(i: int) -> void:
	if i >= _try.size() or _try[i] == null or not is_instance_valid(_try[i]):
		return
	var flow = _try[i]
	Kit.clear(flow)
	var e = exercises[i]
	var sets = sets_from_draft(e, wu)
	var nm = label_name_of(i)
	for o in _try_options(i):
		var lk = ChallengeView.look(str(o.type))
		var hit = Challenges.hit(o, sets)
		# (the text and tooltip never change with the state: the screen finds the key again after a rebuild)
		var k = LogWidgets.mini_chip(ChallengeView.chip_text(o), hit, _use_try.bind(i, o), lk[1], 7)
		k.tooltip_text = "%s: %s, %s (%s)" % [nm, str(o.title), str(o.words), str(o.sub)]
		k.set_meta("try_key", str(o.type))
		k.set_meta("try_hit", hit)
		flow.add_child(k)
		var seen = "%s|%s|%s" % [Xp.normalize_exercise(nm), str(o.type), str(o.chip)]
		if hit and not _hit_seen.has(seen):
			_hit_seen[seen] = true
			if not _building:
				Kit.burst(k, Pal.ACCENT, 22)
				Sfx.pr()
				Sfx.buzz(2)
				App.toast("%s: %s!" % [str(o.title), str(o.words)], "good", "trophy")
		elif not hit:
			_hit_seen.erase(seen)


## A record to try, put into the next set not ticked (a set more when all are): its reps and its weight
## (band, seconds).
func _use_try(i: int, o: Dictionary) -> void:
	if i >= exercises.size():
		return
	var e = exercises[i]
	var j = -1
	for k in range(e.sets.size()):
		if not bool(e.sets[k].get("done", false)):
			j = k
			break
	if j < 0:
		var last = e.sets[e.sets.size() - 1] if not e.sets.is_empty() else {"reps": "", "weight": ""}
		var fresh = last.duplicate()
		fresh.erase("done")
		e.sets.append(fresh)
		j = e.sets.size() - 1
	var s = e.sets[j]
	match str(o.type):
		"hold":
			s["hold"] = str(int(o.sec))
		"day_reps":
			pass
		_:
			s.reps = str(int(o.reps))
			if str(o.get("band", "")) != "":
				s["band"] = str(o.band)
			elif float(o.get("kg", 0.0)) > 0.0:
				s.weight = LogWidgets.trim_num(Fmt.kg_to_unit(float(o.kg), wu))
	Sfx.pop()
	_touched(i)
	App.toast("Set %d: %s. Go for it." % [j + 1, str(o.words)], "info", "target")
	_changed(true)


## A lift prepped for the form's day (game/prep.gd): its draft with the prepped sets and its superset group
## (prep groups are numbered from 100, so they never meet the form's own); null when not prepped.
func _prepped_draft(ex_name: String):
	var f = _form()
	var day = str(f.date) if f != null else App.today
	if editing_id != null:
		return null
	var x = Prep.lift_on(App.settings(), day, ex_name)
	if x == null or (x.get("sets", []) as Array).is_empty():
		return null
	var one = draft_from_sets(str(x.name), x.sets, wu)
	if int(x.get("ss", 0)) > 0:
		one["ss"] = 100 + int(x.ss)
	return one
