class_name PrepView
extends RefCounted
## Prep a day's workout ahead (game/prep.gd; 2026-11-27, the user: "plan my workout based on variation and
## equipment for the next day so I can look ahead at weights, reps, and equipment... know what exactly I'm going
## to work on and superset based on what I have and look at what I want to beat for goals based on that").
##
##   open(date)   the sheet: the day's lifts (the prep, else the day's plan as it stands), each a card: the WAY
##                to do it (the variations and equipment the player has used, other places and gear, the family's
##                stand-ins), the sets to aim for (reps and weight steppers), what it was last time and its best,
##                the RECORDS TO BEAT that way (Challenges: a tap puts one in the first set), up / down / remove,
##                and "Superset with next". Under them: add a lift (the same muscles first, Prep.area_lifts, or a
##                search). Save prep makes it the day's plan (Missions.day_plan); "Use the game's plan" drops it.
## Opened from Coming up (AheadView: the card's "Prep tomorrow" key and each day's "Prep" key).

const MAX_WAYS = 8

static var _date: String = ""
static var _lifts: Array = []  # [{name, sets: [{reps: int, w: float (the player's unit; 0 = none)[, band][, holdSec]}], ss: int}]
static var _kind: String = ""
static var _label: String = ""
static var _query: String = ""
static var _sheet = null
static var _results = null
static var _hist: Dictionary = {}
static var _dirty: bool = false


## The day's plan: today's (App.plan) or one of the look-ahead (App.ahead); null when the day is not in them.
static func plan_on(date: String):
	if date == App.today:
		return App.plan()
	for a in App.ahead():
		if str(a.date) == date:
			return a.plan
	return null


static func open(date: String) -> void:
	Sfx.tap()
	_date = date
	_query = ""
	_dirty = false
	var wu = App.weight_unit()
	var plan = plan_on(date)
	_kind = str(plan.get("kind", "")) if plan != null else ""
	_label = str(plan.get("label", "")) if plan != null else ""
	var src = Prep.lifts_of(Prep.of(App.settings(), date))
	if src.is_empty() and plan != null:
		src = Prep.from_plan(plan.get("lifts", []), Missions._step_kg(wu))
	_lifts = []
	for x in src:
		_lifts.append(_to_edit(x, wu))
	_hist = LiftLibrary.stats(App.sessions().filter(func(s): return str(s.get("date", "")) < date))
	_sheet = Kit.sheet("Prep · %s" % Dates.format_date(date, {"weekday": "long", "month": "short", "day": "numeric"}))
	_sheet.set_meta("prep_sheet", date)
	_fill()
	_sheet.open()


static func _to_edit(x: Dictionary, wu: String) -> Dictionary:
	var sets = []
	for one in x.get("sets", []):
		var s = {"reps": int(one.get("reps", 0)), "w": snappedf(Fmt.kg_to_unit(float(one.get("weightKg", 0.0)), wu), 0.01)}
		if str(one.get("band", "")) != "":
			s["band"] = str(one.band)
		if int(one.get("holdSec", 0)) > 0:
			s["holdSec"] = int(one.holdSec)
		sets.append(s)
	return {"name": str(x.name), "sets": sets, "ss": int(x.get("ss", 0))}


static func _to_store(wu: String) -> Array:
	var out = []
	for x in _lifts:
		var sets = []
		for s in x.sets:
			var one = {"reps": int(s.reps), "weightKg": Fmt.unit_to_kg(float(s.w), wu) if float(s.w) > 0.0 else 0.0}
			if s.has("band"):
				one["band"] = s.band
			if s.has("holdSec"):
				one["holdSec"] = s.holdSec
			sets.append(one)
		out.append({"name": x.name, "sets": sets, "ss": int(x.ss)})
	return out


static func _fmt_w() -> Callable:
	var wu = App.weight_unit()
	return func(kg): return Fmt.fmt_weight(float(kg), wu)


# ---------------------------------------------------------------------------
# The sheet
# ---------------------------------------------------------------------------

static func _fill() -> void:
	var sh = _sheet
	if sh == null or not is_instance_valid(sh):
		return
	if sh.box.is_inside_tree():
		sh.box.custom_minimum_size.y = maxf(sh.box.custom_minimum_size.y, sh.box.size.y)
	for ch in sh.box.get_children():
		sh.box.remove_child(ch)
		ch.queue_free()
	var head = Kit.hbox(8)
	var intro = Kit.para("Pick how you'll do each lift with what you'll have, the weights and reps to aim for, and what to superset. This becomes the day's plan; you can still change anything when you log it.", 12, Pal.MUTED)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intro)
	if _label != "":
		head.add_child(Kit.vcenter(Kit.tag(_label, Pal.LIFT, true, 12)))
	sh.box.add_child(head)
	var labels = _group_labels()
	for i in range(_lifts.size()):
		if i > 0 and _linked(i - 1):
			var ln = Kit.hbox(6)
			ln.add_child(Kit.vcenter(Icons.rect("repeat", 16, Pal.SECOND)))
			ln.add_child(Kit.vcenter(Kit.label("SUPERSET %s: done in turn" % str(labels[i]).substr(0, 1), 11, Pal.SECOND, true)))
			ln.set_meta("prep_superset_line", i - 1)
			sh.box.add_child(ln)
		sh.box.add_child(_lift_card(i, str(labels[i])))
	if _lifts.is_empty():
		sh.box.add_child(Kit.para("No lifts yet. Add the ones you'll do below.", 13, Pal.MUTED))
	sh.box.add_child(_add_card())
	var keys = Kit.hbox(8)
	var save = Kit.button("Save prep", "primary", _save, "lg", "check")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.set_meta("prep_save", true)
	keys.add_child(save)
	if Prep.of(App.settings(), _date) != null:
		var clear = Kit.button("Use the game's plan", "ghost", _clear, "lg")
		clear.set_meta("prep_clear", true)
		keys.add_child(clear)
	sh.box.add_child(keys)


## "A1", "A2", "B1"... for lifts done in turn (next to each other with the same group), "" for the others.
static func _group_labels() -> Array:
	var out = []
	var letter = -1
	var n = 0
	for i in range(_lifts.size()):
		var linked_prev = i > 0 and _linked(i - 1)
		var linked_next = _linked(i)
		if linked_prev:
			n += 1
			out.append("%s%d" % [char(65 + letter), n])
		elif linked_next:
			letter += 1
			n = 1
			out.append("%s%d" % [char(65 + letter), n])
		else:
			out.append("")
	return out


static func _linked(i: int) -> bool:
	return i >= 0 and i + 1 < _lifts.size() and int(_lifts[i].ss) > 0 and int(_lifts[i].ss) == int(_lifts[i + 1].ss)


static func _lift_card(i: int, glabel: String) -> Control:
	var x = _lifts[i]
	var wu = App.weight_unit()
	var fmt_w = _fmt_w()
	var sp = LiftNames.split(str(x.name))
	var part = Missions.part_of(str(x.name))
	var c = Kit.card(6, Callable(), 10)
	c.accent(JourneyLifts.part_color(part) if part != "" else Pal.LIFT)
	c.set_meta("prep_lift", str(x.name))
	# The movement, its way as a tag, the superset label; up, down, remove.
	var head = Kit.hbox(6)
	if glabel != "":
		head.add_child(Kit.vcenter(Kit.tag(glabel, Pal.SECOND, true, 11)))
	var nm = Kit.squeeze(6)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(Kit.soft_name(str(sp.move), 17, null, true, 220.0))
	if str(sp.variation) != "":
		nm.add_child(SessionView.variation_tag(str(sp.variation), 11, true))
	head.add_child(nm)
	var up = Kit.icon_button("arrow_up", PrepView._move.bind(i, -1), "Move %s up" % str(x.name), 30)
	up.disabled = i == 0
	head.add_child(Kit.vcenter(up))
	var down = Kit.icon_button("arrow_down", PrepView._move.bind(i, 1), "Move %s down" % str(x.name), 30)
	down.disabled = i == _lifts.size() - 1
	head.add_child(Kit.vcenter(down))
	head.add_child(Kit.vcenter(LogWidgets.quiet_icon("close", PrepView._remove.bind(i), "Take %s out" % str(x.name), 28)))
	c.add(head)
	# The way to do it: variation and equipment.
	var ways = _ways(str(x.name))
	if ways.size() > 1:
		var wr = Kit.flow(5)
		var cap = Kit.label("WAY", 9, Pal.MUTED, true)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wr.add_child(cap)
		for w in ways:
			var on = Xp.normalize_exercise(str(w)) == Xp.normalize_exercise(str(x.name))
			var k = Kit.chip(_way_word(str(w), str(sp.move)), on, PrepView._set_way.bind(i, str(w)), Pal.LIFT, 11)
			k.tooltip_text = "%s: do it as %s" % [str(sp.move), str(w)]
			k.set_meta("prep_way", str(w))
			wr.add_child(k)
		c.add(wr)
	# Last time and the best, that way.
	var st = _hist.get(Xp.normalize_exercise(str(x.name)))
	var info = ""
	if st != null and not (st.history as Array).is_empty():
		info = "LAST %s: %s" % [Dates.format_date(str(st.history[0].date), {"month": "short", "day": "numeric"}).to_upper(), LiftHistory.describe_sets(st.history[0].sets, fmt_w)]
		var best = 0.0
		for h in st.history:
			for one in LiftTrend.real_sets(h.get("sets", [])):
				best = maxf(best, float(one.get("weightKg", 0)))
		if best > 0.0:
			info += " · BEST %s" % Fmt.fmt_weight(best, wu)
	else:
		info = "NEW TO YOU: find a weight for good, hard reps"
	var il = Kit.clip(info, 11, Pal.MUTED, true)
	il.set_meta("prep_last", info)
	c.add(il)
	# The records to beat that way (Challenges): a tap puts one in the first set.
	var recs = []
	if st != null:
		recs = Challenges.options(str(x.name), st.history, _date, Missions._step_kg(wu), fmt_w)
	if not recs.is_empty():
		var rr = Kit.flow(5)
		var rcap = Kit.label("RECORDS TO BEAT", 9, Pal.ACCENT, true)
		rcap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.add_child(rcap)
		for o in recs:
			var lk = ChallengeView.look(str(o.type))
			var rk = LogWidgets.mini_chip(ChallengeView.chip_text(o), false, PrepView._use_record.bind(i, o), lk[1], 7)
			rk.tooltip_text = "%s: %s, %s (%s). Tap to aim for it in the first set." % [str(x.name), str(o.title), str(o.words), str(o.sub)]
			rk.set_meta("prep_record", str(o.type))
			rr.add_child(rk)
		c.add(rr)
	# The sets to aim for.
	for j in range(x.sets.size()):
		c.add(_set_row(i, j))
	var foot = Kit.hbox(6)
	var add = LogWidgets.mini_chip("+ Set", true, PrepView._add_set.bind(i), Pal.LIFT)
	add.tooltip_text = "%s: one more set (a copy of the last)" % str(x.name)
	foot.add_child(add)
	if i < _lifts.size() - 1:
		var linked = _linked(i)
		var ss = LogWidgets.mini_chip("Superset with next", linked, PrepView._toggle_superset.bind(i), Pal.SECOND)
		ss.tooltip_text = "%s and the lift under it done in turn" % str(x.name)
		ss.set_meta("prep_ss", linked)
		foot.add_child(ss)
	c.add(foot)
	return c


static func _set_row(i: int, j: int) -> Control:
	var x = _lifts[i]
	var s = x.sets[j]
	var wu = App.weight_unit()
	var row = Kit.hbox(4)
	var n = Kit.label("%d" % (j + 1), 13, Pal.MUTED, true)
	n.custom_minimum_size = Vector2(16, 0)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	var rs = Kit.stepper(str(int(s.reps)), 1.0, PrepView._on_reps.bind(i, j), {"min": 0, "width": 34, "compact": true, "placeholder": "–"})
	rs.tooltip_text = "%s: reps of set %d" % [str(x.name), j + 1]
	rs.set_meta("prep_reps", "%d:%d" % [i, j])
	row.add_child(rs)
	if s.has("holdSec"):
		row.add_child(Kit.vcenter(Kit.label("× %d s" % int(s.holdSec), 12, Pal.MUTED, true)))
	elif s.has("band"):
		row.add_child(Kit.vcenter(Kit.label("× %s" % Bands.words(str(s.band)), 12, Pal.MUTED, true)))
	else:
		row.add_child(Kit.vcenter(Kit.label("×", 13, Pal.MUTED)))
		var ws = Kit.stepper(LogWidgets.trim_num(float(s.w)) if float(s.w) > 0.0 else "", Missions._step_kg(wu) if wu == "kg" else 5.0, PrepView._on_weight.bind(i, j), {"min": 0, "width": 54, "compact": true, "snap": true, "placeholder": wu})
		ws.tooltip_text = "%s: weight of set %d" % [str(x.name), j + 1]
		ws.set_meta("prep_weight", "%d:%d" % [i, j])
		row.add_child(ws)
		row.add_child(Kit.vcenter(Kit.label(wu, 11, Pal.MUTED)))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(LogWidgets.quiet_icon("close", PrepView._remove_set.bind(i, j), "%s: take set %d out" % [str(x.name), j + 1], 26))
	return row


## Add a lift: the same muscles as the day (Prep.area_lifts) or, typed, a search of everything.
static func _add_card() -> Control:
	var c = Kit.card(6, Callable(), 10)
	c.set_meta("prep_add", true)
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Icons.rect("plus", 16)))
	head.add_child(Kit.vcenter(Kit.label("Add a lift", 14, Pal.TEXT, true)))
	c.add(head)
	var search = Kit.input(_query, "Search lifts")
	search.set_meta(LogWidgets.FKEY, "prep_search")
	search.set_meta("type_top", true)
	search.custom_minimum_size = Vector2(48, LogWidgets.ROW_H)
	LogWidgets._slim_edit(search, 10)
	search.text_changed.connect(PrepView._on_query)
	c.add(search)
	_results = Kit.flow(5)
	c.add(_results)
	_fill_results()
	return c


static func _fill_results() -> void:
	if _results == null or not is_instance_valid(_results):
		return
	Kit.clear(_results)
	var taken = _lifts.map(func(x): return str(x.name))
	var names = []
	var cap = ""
	if Xp.normalize_exercise(_query) != "":
		var mine = _hist.values().map(func(st): return str(st.name))
		for nm in LiftLibrary.search(_query, mine, 10):
			if not taken.any(func(t): return Xp.normalize_exercise(str(t)) == Xp.normalize_exercise(nm)):
				names.append({"name": nm, "own": _hist.has(Xp.normalize_exercise(nm))})
	else:
		var parts = Prep.area_parts(taken, _kind)
		names = Prep.area_lifts(parts, App.sessions(), taken, App.pt(), 8)
		if not parts.is_empty():
			cap = "SAME MUSCLES: " + ", ".join(PackedStringArray(parts.map(func(p): return LiftLibrary.part_name(str(p)).to_lower())))
	if cap != "":
		var cl = Kit.label(cap, 9, Pal.MUTED, true)
		cl.set_meta("prep_area", cap)
		_results.add_child(cl)
	for e in names:
		var sp = LiftNames.split(str(e.name))
		var text = str(sp.move) + ("  " + str(sp.variation) if str(sp.variation) != "" else "")
		var k = LogWidgets.mini_chip(text, false, PrepView._add_lift.bind(str(e.name)), Pal.LIFT if bool(e.get("own", false)) else Pal.SECOND, 8)
		k.tooltip_text = "Add %s" % str(e.name)
		k.set_meta("prep_suggest", str(e.name))
		_results.add_child(k)


## The ways to do a lift: itself, the player's other variations of it, other places and gear, the family's
## stand-ins (Missions.options_for), then the library's other variations of the movement.
static func _ways(lift_name: String) -> Array:
	var out = [lift_name]
	var seen = {Xp.normalize_exercise(lift_name): true}
	for o in Missions.options_for({"name": lift_name}, _hist, [], App.pt()):
		var k = Xp.normalize_exercise(str(o.name))
		if not seen.has(k) and out.size() < MAX_WAYS:
			seen[k] = true
			out.append(str(o.name))
	var e = LiftNames.movement(Missions.move_of(lift_name))
	if e != null:
		var vars = ([""] if str(e.get("usual", "")) == "" else [str(e.usual)]) + Array(e.get("vars", []))
		for v in vars:
			var nm = LiftNames.join(str(e.name), str(v))
			var k2 = Xp.normalize_exercise(nm)
			if not seen.has(k2) and out.size() < MAX_WAYS:
				seen[k2] = true
				out.append(nm)
	return out


## A way said short beside its movement: its variation ("Dumbbell"), "Plain", or another movement's name.
static func _way_word(way: String, main_move: String) -> String:
	var sp = LiftNames.split(way)
	if str(sp.move) == main_move or Missions.move_of(way) == Missions.move_of(main_move):
		return str(sp.variation) if str(sp.variation) != "" else "Plain"
	return Missions.short_name(way)


# ---------------------------------------------------------------------------
# Changes
# ---------------------------------------------------------------------------

static func _changed(rebuild: bool = true) -> void:
	_dirty = true
	if rebuild:
		_fill()


static func _on_reps(text: String, i: int, j: int) -> void:
	if i < _lifts.size() and j < _lifts[i].sets.size():
		_lifts[i].sets[j].reps = int(LogWidgets.num(text))
		_dirty = true


static func _on_weight(text: String, i: int, j: int) -> void:
	if i < _lifts.size() and j < _lifts[i].sets.size():
		_lifts[i].sets[j].w = LogWidgets.num(text)
		_dirty = true


static func _add_set(i: int) -> void:
	Sfx.pop()
	var sets = _lifts[i].sets
	sets.append(sets[sets.size() - 1].duplicate() if not sets.is_empty() else {"reps": Prep.START_REPS, "w": 0.0})
	_changed()


static func _remove_set(i: int, j: int) -> void:
	Sfx.unpop()
	_lifts[i].sets.remove_at(j)
	_changed()


static func _move(i: int, d: int) -> void:
	var k = i + d
	if k < 0 or k >= _lifts.size():
		return
	Sfx.tick()
	var a = _lifts[i]
	_lifts[i] = _lifts[k]
	_lifts[k] = a
	_changed()


static func _remove(i: int) -> void:
	Sfx.unpop()
	_lifts.remove_at(i)
	_changed()


## Another way: the sets become that way's aim (its last time + a step), or a plain start when never done.
static func _set_way(i: int, way: String) -> void:
	if Xp.normalize_exercise(way) == Xp.normalize_exercise(str(_lifts[i].name)):
		return
	Sfx.tick()
	var st = _hist.get(Xp.normalize_exercise(way))
	var last = st.history[0].sets if (st != null and not (st.history as Array).is_empty()) else []
	var x = _to_edit({"name": way, "sets": Prep.aim_of(last, Missions._step_kg(App.weight_unit()))}, App.weight_unit())
	x["ss"] = int(_lifts[i].ss)
	_lifts[i] = x
	_changed()


## A record to beat, into the first set (its reps and weight; a band or a hold its own).
static func _use_record(i: int, o: Dictionary) -> void:
	Sfx.pop()
	var sets = _lifts[i].sets
	if sets.is_empty():
		sets.append({"reps": 0, "w": 0.0})
	var s = sets[0]
	match str(o.type):
		"hold":
			s["holdSec"] = int(o.sec)
		"day_reps":
			pass
		_:
			s.reps = int(o.reps)
			if str(o.get("band", "")) != "":
				s["band"] = str(o.band)
			elif float(o.get("kg", 0.0)) > 0.0:
				s.w = snappedf(Fmt.kg_to_unit(float(o.kg), App.weight_unit()), 0.01)
	App.toast("%s: set 1 aims for %s" % [Missions.short_name(str(_lifts[i].name)), str(o.words)], "info", "target")
	_changed()


static func _toggle_superset(i: int) -> void:
	Sfx.tick()
	if _linked(i):
		var g = int(_lifts[i].ss)
		_lifts[i + 1].ss = 0
		# (a lift left alone in its group is in none)
		if not (i > 0 and int(_lifts[i - 1].ss) == g):
			_lifts[i].ss = 0
	else:
		var g2 = int(_lifts[i].ss)
		if g2 <= 0:
			for x in _lifts:
				g2 = maxi(g2, int(x.ss))
			g2 += 1
		_lifts[i].ss = g2
		_lifts[i + 1].ss = g2
	_changed()


static func _on_query(text: String) -> void:
	_query = text
	_fill_results()


static func _add_lift(lift_name: String) -> void:
	Sfx.pop()
	var st = _hist.get(Xp.normalize_exercise(lift_name))
	var last = st.history[0].sets if (st != null and not (st.history as Array).is_empty()) else []
	_lifts.append(_to_edit({"name": lift_name, "sets": Prep.aim_of(last, Missions._step_kg(App.weight_unit()))}, App.weight_unit()))
	_query = ""
	_changed()


static func _save() -> void:
	Sfx.claim()
	App.set_prep(_date, _to_store(App.weight_unit()))
	_dirty = false
	App.toast("%s is prepped: %d lift%s" % [Dates.format_date(_date, {"weekday": "long"}), _lifts.size(), "" if _lifts.size() == 1 else "s"], "good", "check")
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()


static func _clear() -> void:
	Sfx.unpop()
	App.set_prep(_date, [])
	App.toast("Back to the game's plan for %s" % Dates.format_date(_date, {"weekday": "long"}), "info", "repeat")
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()
