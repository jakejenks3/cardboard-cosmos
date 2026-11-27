class_name LogLiftMenu
extends RefCounted
## The "More" sheet of an exercise card in the Log tab (2026-11-27, the user's "build all" of a list of
## ideas): swap it for another way of doing it (equipment taken), make it a superset with the next exercise,
## a note for next time, and how hard it was. Everything here acts on the editor's draft
## (LogLiftEditor), except the note, which is stored for the lift at once (App.set_lift_note).

## How hard it was: [id, word, colour key]. Shown only (history, the training summary); it never changes an aim.
const EFFORTS = [["", "Not said"], ["easy", "Easy"], ["hard", "Hard"], ["fail", "To failure"]]


static func effort_word(id: String) -> String:
	for e in EFFORTS:
		if str(e[0]) == id:
			return str(e[1])
	return ""


static func effort_color(id: String) -> Color:
	match id:
		"easy":
			return Pal.GOOD
		"hard":
			return Pal.ACCENT2
		"fail":
			return Pal.DANGER
	return Pal.MUTED


## Other ways to do a lift, for "Swap": the player's other variations of the movement, the other place,
## movements of its family (Missions.options_for), then more variations of the library. Never itself, never
## one already in the workout. [{"name", "new", "last"}]
static func swap_ways(lift_name: String, in_workout: Array, sessions: Array) -> Array:
	var hist = LiftLibrary.stats(sessions)
	var skip = {}
	for n in in_workout:
		skip[Xp.normalize_exercise(str(n))] = true
	skip[Xp.normalize_exercise(lift_name)] = true
	var out = []
	var add = func(n: String):
		var k = Xp.normalize_exercise(n)
		if n == "" or skip.has(k) or out.size() >= 6:
			return
		skip[k] = true
		var st = hist.get(k)
		out.append({"name": n, "new": st == null, "last": st.history[0].sets if st != null else [], "lastDate": str(st.last) if st != null else ""})
	for o in Missions.options_for({"name": lift_name}, hist, [], App.pt()):
		add.call(str(o.name))
	var e = LiftNames.movement(Missions.move_of(lift_name))
	if e != null:
		for v in e.vars:
			add.call(LiftNames.join(str(e.name), str(v)))
	return out


static func open(ed, i: int) -> void:
	if i < 0 or i >= ed.exercises.size():
		return
	Sfx.tap()
	var e = ed.exercises[i]
	var nm = str(e.name).strip_edges()
	var sp = LiftNames.split(nm)
	var s = Kit.sheet(str(sp.move) if nm != "" else "Exercise")
	s.set_meta("lift_menu", i)
	if str(sp.variation) != "":
		s.box.add_child(Kit.clip(str(sp.variation), 13, Pal.MUTED))

	# --- superset --------------------------------------------------------------------------------------
	var n = ed.exercises.size()
	var linked = ed.linked_next(i)
	var in_group = ed.group_label(i) != ""
	if n > 1:
		s.box.add_child(Kit.sub_head("SUPERSET", Pal.SECOND, null, "Two lifts done in turn: a set of one, then a set of the other"))
		if linked:
			var b = Kit.button("Take %s out of the superset" % Missions.short_name(str(ed.exercises[i + 1].name)), "ghost", func():
				s.close()
				ed.link_next(i))
			b.set_meta("superset_key", "unlink")
			s.box.add_child(b)
		elif i < n - 1:
			var b2 = Kit.button("Superset with %s" % Missions.short_name(str(ed.exercises[i + 1].name)), "primary", func():
				s.close()
				ed.link_next(i))
			b2.set_meta("superset_key", "link")
			s.box.add_child(b2)
		if in_group and i > 0 and ed.linked_next(i - 1):
			var b3 = Kit.button("Take it out of the superset", "ghost", func():
				s.close()
				ed.unlink(i))
			b3.set_meta("superset_key", "leave")
			s.box.add_child(b3)
		if not linked and i == n - 1 and not in_group:
			s.box.add_child(Kit.muted_para("Move it under the lift to pair it with, then link them from that lift's More.", 12))

	# --- note ------------------------------------------------------------------------------------------
	if nm != "":
		s.box.add_child(Kit.sub_head("NOTE FOR NEXT TIME", Pal.ACCENT2, null, "Shown on this lift's card every time: seat, pin, grip..."))
		var box = Kit.input(App.lift_note(nm), "Seat 4, pin 7, close grip...")
		box.max_length = LiftNotes.MAX_LEN
		box.set_meta("lift_note_box", true)
		box.custom_minimum_size = Vector2(48, LogWidgets.ROW_H)
		var row2 = Kit.hbox(8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(box)
		var save_note = func():
			App.set_lift_note(nm, box.text)
			Sfx.pop()
			s.close()
			ed._changed(true)
		box.text_submitted.connect(func(_t): save_note.call())
		var sk = Kit.button("Save", "primary", save_note, "sm")
		sk.set_meta("lift_note_save", true)
		row2.add_child(sk)
		s.box.add_child(row2)

	# --- effort ----------------------------------------------------------------------------------------
	s.box.add_child(Kit.sub_head("HOW HARD WAS IT?", Pal.ACCENT, null, "A mark for your history. It never changes your goals."))
	var holder = Kit.vbox(4)
	s.box.add_child(holder)
	_fill_effort(holder, ed, i)
	s.box.add_child(Kit.muted_para("Just a mark for your history and your training summary. It never changes a goal or an aim.", 11))
	# --- swap ------------------------------------------------------------------------------------------
	if nm != "":
		s.box.add_child(Kit.sub_head("SWAP FOR ANOTHER WAY", Pal.LIFT, null, "Equipment taken? Do it another way: same place in the workout, same number of sets"))
		var names = []
		for x in ed.exercises:
			names.append(str(x.name))
		var ways = swap_ways(nm, names, App.sessions())
		if ways.is_empty():
			s.box.add_child(Kit.muted_para("No other way of doing it is known yet.", 12))
		for w in ways:
			var row = Kit.row(func():
				s.close()
				ed.swap_exercise(i, str(w.name)), Pal.SECOND if bool(w.new) else Pal.LIFT, null, 8, 2)
			row.set_meta("swap_way", str(w.name))
			var wsp = LiftNames.split(str(w.name))
			var line = Kit.squeeze(6)
			line.add_child(Kit.soft_name(str(wsp.move), 14, null, true, 220.0))
			if str(wsp.variation) != "":
				line.add_child(SessionView.variation_tag(str(wsp.variation), 11, true))
			row.add(line)
			var sub = "New to you" if bool(w.new) else "Last " + LiftHistory.describe_sets(w.last, func(kg): return Fmt.fmt_weight(float(kg), ed.wu))
			row.add(Kit.clip(sub, 11, Pal.SECOND if bool(w.new) else Pal.MUTED))
			s.box.add_child(row)

	s.open()


static func _fill_effort(holder: Control, ed, i: int) -> void:
	Kit.clear(holder)
	var cur = str(ed.exercises[i].get("effort", ""))
	var keys = []
	for ef in EFFORTS:
		var id = str(ef[0])
		var k = Kit.choice(str(ef[1]), cur == id, func():
			ed.set_effort(i, id)
			_fill_effort(holder, ed, i), effort_color(id) if id != "" else Pal.LIFT, 12)
		k.set_meta("effort_key", id)
		keys.append(k)
	holder.add_child(Kit.choice_track(keys))
