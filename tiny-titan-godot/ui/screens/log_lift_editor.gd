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
var _built_names: Array = []
var _chips: HFlowContainer = null
var _no_match: Label = null
var _add_btn: Button = null
var _building: bool = false


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
	var rows = []
	for s in sets:
		var row = {"reps": str(int(s.reps)), "weight": LogWidgets.trim_num(Fmt.kg_to_unit(float(s.weightKg), unit)) if float(s.weightKg) > 0.0 else ""}
		# A hold (a stretch, written 30" in the phone note): its seconds ride along.
		if int(s.get("holdSec", 0)) > 0:
			row["hold"] = int(s.holdSec)
		rows.append(row)
	if rows.is_empty():
		rows.append({"reps": "", "weight": ""})
	return {"name": ex_name, "bodyweight": bw, "sets": rows}


## Empty or zero-rep sets are dropped (as the web app does).
static func sets_from_draft(e: Dictionary, unit: String) -> Array:
	var out = []
	for s in e.sets:
		var reps = maxi(0, TTUtil.jsround(LogWidgets.num(s.reps)))
		var kg = 0.0 if e.bodyweight else maxf(0.0, Fmt.unit_to_kg(LogWidgets.num(s.weight), unit))
		if reps > 0:
			var one = {"reps": reps, "weightKg": kg}
			if int(s.get("hold", 0)) > 0:
				one["holdSec"] = int(s.hold)
			out.append(one)
	return out


## The exercises as they will be saved: named, with at least one real set.
func session_exercises() -> Array:
	var out = []
	for e in exercises:
		var nm = str(e.name).strip_edges()
		var sets = sets_from_draft(e, wu)
		if nm != "" and not sets.is_empty():
			out.append({"name": nm, "sets": sets})
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
	_suggestions = LiftHistory.exercise_suggestions(sessions, Summary.DEFAULT_EXERCISES, editing_id)
	_bests = App.state.prs.lifts
	_badges = []
	_wsteps = []
	_deltas = []
	_built_names = []

	# An exercise sent over from the lift library: add it with last time's sets.
	if App.pending_exercise != "":
		var pend = App.pending_exercise
		App.pending_exercise = ""
		var pk = Xp.normalize_exercise(pend)
		var have = false
		for e in exercises:
			if Xp.normalize_exercise(e.name) == pk:
				have = true
		if not have and pk != "":
			var plp = _last.get(pk)
			if plp != null:
				exercises.append(draft_from_sets(str(plp.name), plp.sets, wu))
			else:
				exercises.append({"name": pend, "bodyweight": false, "sets": [{"reps": "", "weight": ""}]})

	if exercises.is_empty():
		var templates = LiftHistory.recent_workouts(sessions, 3, editing_id)
		if not templates.is_empty():
			var tv = Kit.vbox(6)
			tv.add_child(Kit.section_title("Repeat a workout"))
			for t in templates:
				var names = []
				for e in t.exercises:
					if _has_reps(e.sets):
						names.append(str(e.name).strip_edges())
				var tile = LogWidgets.template(t.date, " · ".join(PackedStringArray(names)), apply_template.bind(t), "lift", "%d exercises · " % names.size())
				tile.tooltip_text = "Start from this workout, with your latest numbers"
				tv.add_child(tile)
			parent.add_child(tv)

	for i in range(exercises.size()):
		parent.add_child(_exercise_card(i))

	parent.add_child(_picker_card())
	_building = false


static func _has_reps(sets: Array) -> bool:
	for s in sets:
		if int(s.reps) > 0:
			return true
	return false


## Collapsed picker: about two rows of chips.
const CHIPS_COLLAPSED = 6

## One exercise: a title line (name · BW · remove), one muted "Last … · Best …"
## line, one tight row per set (n · reps × weight unit · trend · remove) and a
## footer of small chips with the volume note on the right.
func _exercise_card(i: int) -> Card:
	var e = exercises[i]
	var key = Xp.normalize_exercise(e.name)
	var lp = _last.get(key)
	var best = _bests.get(key)
	_built_names.append(str(e.name).strip_edges())
	var c = Kit.card(4, Callable(), 10)
	c.accent(Pal.LIFT)

	# Name · BW · remove
	var head = Kit.hbox(4)
	var name_edit = LogWidgets.title_edit(e.name, "Exercise name", 17)
	name_edit.set_meta(LogWidgets.FKEY, "ex%d.name" % i)
	name_edit.text_changed.connect(_on_name_typed.bind(i))
	name_edit.focus_exited.connect(_on_name_done.bind(i))
	name_edit.text_submitted.connect(func(_t): _on_name_done(i))
	head.add_child(name_edit)
	var bw = LogWidgets.mini_chip("BW", e.bodyweight, _toggle_bw.bind(i), Pal.LIFT, 8)
	bw.tooltip_text = "Bodyweight exercise (no weight)"
	head.add_child(bw)
	head.add_child(LogWidgets.quiet_icon("close", remove_exercise.bind(i), "Remove exercise", 28))
	c.add(head)

	# Last time · best, one line (the date is in the tooltip)
	var has_best = best != null and float(best.weightKg) > 0.0
	if lp != null or has_best:
		var ref = Kit.hbox(10)
		ref.mouse_filter = Control.MOUSE_FILTER_PASS
		if lp != null:
			ref.add_child(Kit.clip("Last " + LiftHistory.describe_sets(lp.sets, _fmt_w), 12, Pal.MUTED))
			ref.tooltip_text = "Last time: %s" % Dates.relative_day(lp.date, App.today)
		else:
			ref.add_child(Kit.spacer())
		if has_best:
			ref.add_child(Kit.label("Best " + _fmt_w(best.weightKg), 12, Pal.ACCENT, true))
		c.add(Kit.pad(ref, 6, 0, 4, 1))

	# Sets
	var slots = []
	var wsteps = []
	var label_name = str(e.name).strip_edges()
	if label_name == "":
		label_name = "Exercise %d" % (i + 1)
	for j in range(e.sets.size()):
		var s = e.sets[j]
		var ref_set = _ref_set(lp, j)
		var row = Kit.hbox(4)
		var n = PixelFont.rect(str(j + 1), 2, Pal.MUTED)
		n.custom_minimum_size.x = 16
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(n)
		var reps_opts = {"placeholder": "–", "width": 32, "min": 0, "compact": true}
		if ref_set != null:
			reps_opts["base"] = int(ref_set.reps)
		var rs = Kit.stepper(s.reps, 1.0, Callable(), reps_opts)
		LogWidgets.slim_stepper(rs, "ex%d.s%d.reps" % [i, j]).tooltip_text = "%s reps for set %d" % [label_name, j + 1]
		rs.changed.connect(_on_set_text.bind(i, j, "reps"))
		row.add_child(rs)
		var ws = null
		if not e.bodyweight:
			row.add_child(Kit.vcenter(Kit.label("×", 13, Pal.MUTED)))
			var w_opts = {"placeholder": wu, "width": 54, "snap": true, "min": 0, "compact": true}
			if ref_set != null and float(ref_set.weightKg) > 0.0:
				w_opts["base"] = TTUtil.jsround(Fmt.kg_to_unit(float(ref_set.weightKg), wu) * 100.0) / 100.0
			ws = Kit.stepper(s.weight, _step(), Callable(), w_opts)
			LogWidgets.slim_stepper(ws, "ex%d.s%d.weight" % [i, j]).tooltip_text = "%s weight for set %d" % [label_name, j + 1]
			ws.changed.connect(_on_set_text.bind(i, j, "weight"))
			row.add_child(ws)
			row.add_child(Kit.vcenter(Kit.label(wu, 11, Pal.MUTED)))
		else:
			row.add_child(Kit.vcenter(Kit.label("reps", 11, Pal.MUTED)))
		var slot = Kit.hbox(0)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.alignment = BoxContainer.ALIGNMENT_BEGIN
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(Kit.pad(slot, 2, 0, 0, 0))
		row.get_child(row.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.append(slot)
		wsteps.append(ws if ws != null else rs)
		row.add_child(LogWidgets.quiet_icon("close", remove_set.bind(i, j), "Remove set %d" % (j + 1), 26))
		c.add(row)
	_badges.append(slots)
	_wsteps.append(wsteps)

	# + Set · +1 rep · +step (every set) … volume note on the right
	var acts = Kit.hbox(5)
	var add_btn = LogWidgets.mini_chip("+ Set", true, add_set.bind(i), Pal.LIFT)
	add_btn.tooltip_text = "Add a set (copies the last one)"
	acts.add_child(add_btn)
	var rep_btn = LogWidgets.mini_chip("+1 rep", false, bump_all.bind(i, "reps"))
	rep_btn.tooltip_text = "Add one rep to every set"
	acts.add_child(rep_btn)
	if not e.bodyweight:
		var w_btn = LogWidgets.mini_chip("+%s %s" % [TTUtil.num_str(_step()), wu], false, bump_all.bind(i, "weight"))
		w_btn.tooltip_text = "Add one weight step to every set"
		acts.add_child(w_btn)
	var delta = Kit.vbox(0)
	delta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acts.add_child(delta)
	c.add(Kit.pad(acts, 0, 2, 0, 0))
	_deltas.append(delta)
	_refresh_exercise(i)
	return c


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
	var slots = _badges[i]
	for j in range(mini(slots.size(), e.sets.size())):
		var slot = slots[j]
		if not is_instance_valid(slot):
			continue
		Kit.clear(slot)
		var s = e.sets[j]
		var cur = {"reps": TTUtil.jsround(LogWidgets.num(s.reps)), "weightKg": 0.0 if e.bodyweight else Fmt.unit_to_kg(LogWidgets.num(s.weight), wu)}
		var prev = null
		if lp != null and j < lp.sets.size():
			prev = lp.sets[j]
		var trend = LiftHistory.compare_set(cur, prev, lp != null, best_kg)
		var badge = _trend_badge(trend)
		if badge != null:
			slot.add_child(badge)
		if trend != null and str(trend.kind) == "pr":
			_celebrate_pr(i, j)
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
	if e.bodyweight or last_vol == 0.0:
		if reps > last_reps:
			text = "▲ %d reps" % (reps - last_reps)
			good = true
		elif reps == last_reps:
			text = "= last reps"
		else:
			text = "%d reps to match" % (last_reps - reps)
	elif vol > last_vol + 1e-6:
		text = "▲ %s volume" % _fmt_w(vol - last_vol)
		good = true
	elif absf(vol - last_vol) <= 1e-6:
		text = "= last volume"
	else:
		text = "%s to match" % _fmt_w(last_vol - vol)
	var note = Kit.clip(text, 12, Pal.GOOD if good else Pal.MUTED, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.tooltip_text = "Volume (reps × weight) compared with last time"
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
			t.tooltip_text = "Heavier than you have ever lifted on this exercise"
		"weight":
			t = LogWidgets.badge("+%s %s" % [LogWidgets.trim_num(Fmt.kg_to_unit(float(trend.deltaKg), wu)), wu], Pal.GOOD, 11)
			t.tooltip_text = "Heavier than last time"
		"reps":
			t = LogWidgets.badge("+%d rep%s" % [int(trend.delta), "" if int(trend.delta) == 1 else "s"], Pal.GOOD, 11)
			t.tooltip_text = "More reps than last time"
		"extra":
			t = LogWidgets.badge("+set", Pal.GOOD, 11)
			t.tooltip_text = "An extra set compared with last time"
	return t


# ---------------------------------------------------------------------------
# The "add an exercise" card: search, your exercises first, weight step chip
# ---------------------------------------------------------------------------

func _picker_card() -> Card:
	var c = Kit.card(6, Callable(), 10)
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Icons.rect("plus", 16)))
	head.add_child(Kit.vcenter(Kit.clip("Add exercise", 14, null, true)))
	var step_chip = LogWidgets.mini_chip("± %s %s" % [TTUtil.num_str(_step()), wu], false, cycle_step)
	step_chip.tooltip_text = "Weight step: how much one tap of + or − changes a weight (tap to change)"
	head.add_child(step_chip)
	c.add(head)

	var row = Kit.hbox(6)
	var search = Kit.input(query, "Search or new exercise")
	search.set_meta(LogWidgets.FKEY, "search")
	search.select_all_on_focus = false
	search.custom_minimum_size = Vector2(48, LogWidgets.ROW_H)
	search.tooltip_text = "Your exercises come first. Tapping one brings back everything you did last time."
	LogWidgets._slim_edit(search, 10)
	search.text_changed.connect(_on_query)
	search.text_submitted.connect(func(_t): add_from_search())
	row.add_child(search)
	_add_btn = Kit.button("Add", "secondary", add_from_search, "sm")
	_add_btn.custom_minimum_size = Vector2(56, LogWidgets.ROW_H)
	_add_btn.disabled = Xp.normalize_exercise(query) == ""
	row.add_child(_add_btn)
	c.add(row)

	_chips = Kit.flow(5)
	c.add(_chips)
	_no_match = Kit.label("", 11, Pal.MUTED)
	c.add(_no_match)
	_fill_chips()
	return c


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
	for s in _suggestions:
		if in_form.has(s.key):
			continue
		if q != "" and not str(s.key).contains(q):
			continue
		if shown.size() >= limit:
			more_left = true
			break
		shown.append(s)
	for s in shown:
		_chips.add_child(_ex_chip(s))
	if q == "" and (more_left or show_all_chips):
		var more = LogWidgets.mini_chip("Less" if show_all_chips else "More…", false, _toggle_more_chips)
		more.tooltip_text = "Show fewer exercises" if show_all_chips else "Show more exercises"
		_chips.add_child(more)
	if is_instance_valid(_no_match):
		_no_match.text = "New exercise: tap Add" if q != "" and shown.is_empty() else ""
		_no_match.visible = _no_match.text != ""
	if is_instance_valid(_add_btn):
		_add_btn.disabled = q == ""


## One tappable exercise key: "Bench Press  85×5" (your own ones have a lift-coloured edge).
func _ex_chip(s: Dictionary) -> Button:
	var lp = s.get("last")
	var h = Kit.hbox(5)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm = Kit.label(str(s.name), 12, Pal.TEXT, true)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	if lp != null:
		var top = LiftHistory.top_set_label(lp.sets, func(kg): return Fmt.kg_to_unit(float(kg), wu))
		if top != "":
			var tl = Kit.label(top, 11, Pal.ACCENT, true)
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(tl)
	var b = LogWidgets.key(str(s.name), Pal.PANEL2, h, add_exercise.bind(str(s.name)), 9, 4, 1, Pal.LIFT if lp != null else Pal.LINE)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if lp != null:
		b.tooltip_text = "Last top set: %s" % LiftHistory.top_set_label(lp.sets, func(kg): return Fmt.kg_to_unit(float(kg), wu))
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
		exercises.append({"name": ex_name.strip_edges(), "bodyweight": false, "sets": [{"reps": "", "weight": ""}]})
	query = ""
	var i = exercises.size() - 1
	if lp == null:
		_set_focus_after("ex%d.s0.reps" % i)
	elif from_search:
		_set_focus_after("search")
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
	Sfx.tick()
	var sets = exercises[i].sets
	var copy = sets[sets.size() - 1].duplicate() if not sets.is_empty() else {"reps": "", "weight": ""}
	sets.append(copy)
	_changed(true)


func remove_set(i: int, j: int) -> void:
	exercises[i].sets.remove_at(j)
	_changed(true)


func remove_exercise(i: int) -> void:
	exercises.remove_at(i)
	_changed(true)


func bump_all(i: int, field: String) -> void:
	Sfx.tick()
	for s in exercises[i].sets:
		if field == "reps":
			s.reps = TTUtil.num_str(LogWidgets.num(s.reps) + 1.0)
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
	exercises[i].bodyweight = not exercises[i].bodyweight
	_changed(true)


func _on_set_text(text: String, i: int, j: int, field: String) -> void:
	if i >= exercises.size() or j >= exercises[i].sets.size():
		return
	exercises[i].sets[j][field] = text
	_refresh_exercise(i)
	_changed(false)


func _on_name_typed(text: String, i: int) -> void:
	if i < exercises.size():
		exercises[i].name = text
		_changed(false)


## Left the name box: a known exercise typed into a still-empty card brings up last time's sets.
func _on_name_done(i: int) -> void:
	if _building or i >= exercises.size():
		return
	var e = exercises[i]
	var lp = _last.get(Xp.normalize_exercise(e.name))
	var pristine = true
	for s in e.sets:
		if str(s.reps) != "" or str(s.weight) != "":
			pristine = false
	if lp != null and pristine:
		exercises[i] = draft_from_sets(str(e.name).strip_edges(), lp.sets, wu)
		_changed(true)
	elif i < _built_names.size() and str(e.name).strip_edges() != _built_names[i]:
		_changed(true)


func _on_query(text: String) -> void:
	query = text
	_fill_chips()
