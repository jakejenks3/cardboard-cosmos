class_name LogPlanCard
extends RefCounted
## "From today's plan" in the Log tab (the user, 2026-11-23: "it's annoying to
## have to click on it, press add to workout, then go back to hero page, then
## repeat. When going to log, have it maybe have an area that says from
## suggested workouts based on the goals and volume we have planned and
## easily be able to add/remove from workout as I go").
##
## The Today card's lifts as keys: what the training focus adds, the likely
## lifts, the movement to try, the physical therapy (Missions.picks). In two
## places:
##
##   build(editor)   in the lift form, under the workout's exercises and above
##                   "Add exercise" (first of all while the workout is empty).
##                   One tap puts a lift into the workout with last time's
##                   sets, marked planned; a second tap takes it out again
##                   while it is untouched (LogLiftEditor.plan_toggle). Only
##                   for a workout dated today.
##   picker()        on the Log tab's first screen, under its keys: the lifts
##                   still to do today. A tap opens the lift form with that
##                   lift in the workout (the user, the same evening, looking
##                   for it there: "shouldn't it pop up as suggested like I
##                   asked earlier when going to log a workout?").
##
## The other ways to do a lift are chips under it, each a key of its own, for
## the day the equipment is not there.
##
## Nothing moves under the finger: a key keeps its place, its size and its
## (unseen) name whatever its state, so the screen's rebuild finds it again and
## keeps it where it was (UiScreen) while the exercise cards above come and go.

const KICKERS = {
	"extra": "YOUR FOCUS ADDS",
	"lift": "PROBABLY TODAY",
	"new": "TRY SOMETHING NEW",
	"pt": "PHYSICAL THERAPY",
	"done": "DONE TODAY",
}

## Folded away to its header (until the game is closed).
static var folded: bool = false


## The saved sessions that count as done: not the one in the form.
static func _others(ed: LogLiftEditor) -> Array:
	var sessions = App.sessions()
	if ed.editing_id == null:
		return sessions
	return sessions.filter(func(s): return s.id != ed.editing_id)


## The card's first line: the sun, its name, the day's label, a count, and
## whatever key goes at its end.
static func _head(plan: Dictionary, count: Control, last = null) -> Control:
	var head = Kit.hbox(6)
	head.add_child(Kit.vcenter(Icons.rect("sun", 16)))
	var title = Kit.clip("From today's plan", 14, null, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(Kit.vcenter(title))
	if bool(plan.get("off", false)):
		head.add_child(Kit.vcenter(Kit.tag("Rest day", Pal.SECOND, true, 11)))
	elif str(plan.get("label", "")) != "":
		head.add_child(Kit.vcenter(Kit.tag(str(plan.label), Pal.LIFT, true, 11)))
	head.add_child(Kit.vcenter(count))
	if last != null:
		head.add_child(last)
	return head


## The rows, under their kickers.
## Rows done today (and not in this workout) go last, short, under "DONE TODAY" (2026-11-27: they took as
## much room as the lifts still to do, OR chips and all). A row only becomes done when a workout is saved,
## so nothing moves while this one is being logged.
static func _fill(c: Card, ctx: Dictionary, rows: Array, here: Dictionary) -> void:
	var todo = []
	var done = []
	for r in rows:
		if _state(r, here) == "done":
			done.append(r)
		else:
			todo.append(r)
	var group = ""
	for r in todo + done:
		var g = "done" if _state(r, here) == "done" else _group(r)
		if g != group:
			group = g
			var k = Kit.label(str(KICKERS[g]), 10, Pal.GOOD if g == "done" else Pal.MUTED, true)
			if g == "done":
				k.set_meta("plan_done_head", done.size())
			c.add(k)
		c.add(_done_row(ctx, r) if g == "done" else _row(ctx, r, here))


static func _state(r: Dictionary, here: Dictionary) -> String:
	if here.has(Xp.normalize_exercise(str(r.name))):
		return "in"
	return "done" if str(r.done) != "" else "add"


## A lift of the plan done today: one quiet line, a tick, the lift that did it and its sets. Still a key
## (it adds the lift to this workout, for a second go), with the same unseen name as before.
static func _done_row(ctx: Dictionary, r: Dictionary) -> Control:
	var sp = LiftNames.split(str(r.done))
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Kit.tick_box(true, 18)))
	var top = Kit.squeeze(6)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(Kit.soft_name(str(sp.move), 12, null, true, 150.0))
	if str(sp.variation) != "":
		top.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	h.add_child(top)
	var words = _words(ctx, r, "done")
	var said = Kit.clip_fit(str(words.said), 11, Pal.MUTED, true, 130.0)
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	said.set_meta("plan_done_sets", str(words.said))
	h.add_child(said)
	Kit.passthrough(h)
	var tap: Callable = ctx.tap
	var b = LogWidgets.key("Plan: %s" % str(r.name), Pal.PANEL2.lerp(Pal.GOOD, 0.12), h, tap.bind(str(r.name)), 8, 4, 2, Pal.with_alpha(Pal.GOOD, 0.6))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "Done today. Tap to add it to this workout again"
	b.set_meta("plan_pick", str(r.name))
	b.set_meta("plan_state", "done")
	return b


## The card of the lift form, or null when there is nothing to offer (another
## day, no plan).
static func build(ed: LogLiftEditor):
	var f = ed._form()
	if f == null or str(f.discipline) != "lift" or str(f.date) != App.today:
		return null
	var plan = App.plan()
	var others = _others(ed)
	var rows = Missions.picks(plan, others, App.today)
	if rows.is_empty():
		return null
	var here = {}
	for i in range(ed.exercises.size()):
		here[Xp.normalize_exercise(str(ed.exercises[i].name))] = i
	# Rows that are seen to: done today, or in this workout one way or another.
	var seen_to = 0
	for r in rows:
		if str(r.done) != "" or here.has(Xp.normalize_exercise(str(r.name))) or r.ways.any(func(w): return here.has(Xp.normalize_exercise(str(w.name)))):
			seen_to += 1

	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.ACCENT)
	c.set_meta("plan_card", true)
	var count = Kit.tag("%d/%d" % [seen_to, rows.size()], Pal.PANEL2, false, 11)
	count.set_meta("plan_count", seen_to)
	var fold = LogWidgets.mini_chip("Show" if folded else "Hide", false, _toggle_fold.bind(ed))
	fold.tooltip_text = "Show the day's plan" if folded else "Fold the day's plan away"
	fold.set_meta("plan_fold", folded)
	c.add(_head(plan, count, fold))
	if folded:
		return c
	c.add(Kit.para("Tap a lift to add it with last time's sets. Tap it again to take it back.", 11, Pal.MUTED))
	_fill(c, {"wu": ed.wu, "sessions": others, "last": ed._last, "tap": ed.plan_toggle}, rows, here)
	return c


## The card of the Log tab's first screen, or null: what of the day's plan is
## still to do. A row's key (and each of its ways) opens the lift form with
## that lift in the workout; one that the workout kept from earlier already
## holds is ticked.
static func picker():
	var plan = App.plan()
	var sessions = App.sessions()
	var rows = Missions.picks(plan, sessions, App.today).filter(func(r): return str(r.done) == "")
	if rows.is_empty():
		return null
	var here = {}
	var draft = App.draft_load("lift")
	if draft is Dictionary and draft.get("exercises") is Array:
		for i in range(draft.exercises.size()):
			if draft.exercises[i] is Dictionary:
				here[Xp.normalize_exercise(str(draft.exercises[i].get("name", "")))] = i
	var c = Kit.card(6, Callable(), 10)
	c.accent(Pal.ACCENT)
	c.set_meta("plan_picker", true)
	var count = Kit.tag("%d to go" % rows.size(), Pal.PANEL2, false, 11)
	count.set_meta("plan_left", rows.size())
	c.add(_head(plan, count))
	c.add(Kit.para("Tap a lift to open your workout with it, last time's sets filled in.", 11, Pal.MUTED))
	_fill(c, {"wu": App.weight_unit(), "sessions": sessions, "last": LiftHistory.last_performances(sessions, null), "tap": _open_with}, rows, here)
	return c


## A key of the first screen's card: the lift form, with this lift in the
## workout (LogLiftEditor.build takes it from App.pending_workout, marked
## planned; one that is there already is left alone).
static func _open_with(lift: String) -> void:
	Sfx.tap()
	App.pending_workout = [lift]
	App.open_log("lift")


static func _group(r: Dictionary) -> String:
	if str(r.kind) == "extra" or str(r.kind) == "new":
		return str(r.kind)
	return "pt" if (str(r.kind) == "pt" and r.get("lift") == null) else "lift"


static func _toggle_fold(ed: LogLiftEditor) -> void:
	Sfx.tick()
	folded = not folded
	ed._changed(true)


## The box at the front of a row: a plus while the lift can be added, a tick
## once it is in the workout (the lift colour) or was done today (green).
static func _box(state: String) -> Control:
	var box = PanelContainer.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var col = Pal.LIFT if state == "in" else (Pal.GOOD if state == "done" else Pal.LINE)
	box.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL if state == "add" else Pal.with_alpha(col, 0.25), 4, col, 2, 2, 2))
	var mid = CenterContainer.new()
	mid.add_child(Icons.rect("plus" if state == "add" else "check", 16))
	box.add_child(mid)
	return box


## What a row says under its name: what to aim for, or what was done.
## `ctx`: {"wu", "sessions" (the saved ones that count as done), "last"
## (LiftHistory.last_performances), "tap" (Callable(lift name))}.
static func _words(ctx: Dictionary, r: Dictionary, state: String) -> Dictionary:
	var wu = str(ctx.wu)
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	if state == "done":
		return {"cap": "DONE TODAY", "said": LiftHistory.describe_sets(Missions.sets_on(ctx.sessions, str(r.done), App.today), fmt_w), "col": Pal.TEXT}
	var l = r.get("lift")
	if l != null:
		var got = 0
		if l.has("dose"):
			got = int(Dose.extra_done(l, ctx.sessions, App.today, Missions.same_of(str(l.name), App.plan())).sets)
		return TodayView.aim_words(l, {"name": str(r.name), "new": bool(r.new), "last": r.last, "sides": int(r.sides)}, wu, got)
	if bool(r.new):
		return {"cap": "FIRST TIME", "said": "Find your weight", "col": Pal.SECOND}
	# Physical therapy that is not one of the plan's lifts: as it was done last.
	var lp = ctx.last.get(Xp.normalize_exercise(str(r.name)))
	return {"cap": "AS LAST TIME", "said": LiftHistory.describe_sets(lp.sets, fmt_w) if lp != null else "", "col": Pal.PT}


## One planned lift: a key as wide as the card (box, name, variation, what to
## aim for) and, under it, the other ways to do it as chips.
static func _row(ctx: Dictionary, r: Dictionary, here: Dictionary) -> Control:
	var state = "add"
	if here.has(Xp.normalize_exercise(str(r.name))):
		state = "in"
	elif str(r.done) != "":
		state = "done"
	# Done another way: the row names the lift that did it.
	var sp = LiftNames.split(str(r.done) if state == "done" else str(r.name))
	var h = Kit.hbox(8)
	h.add_child(_box(state))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top = Kit.squeeze(6)
	top.add_child(Kit.soft_name(str(sp.move), 13, null, true, 170.0))
	if str(sp.variation) != "":
		top.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	if state != "done" and str(r.kind) == "extra":
		top.add_child(Kit.vcenter(Kit.tag("FOR " + Dose.part_name(str(r.part)).to_upper(), JourneyLifts.part_color(str(r.part)), true, 10)))
	elif state != "done" and str(r.kind) == "new":
		top.add_child(Kit.vcenter(Kit.tag("NEW", Pal.SECOND, true, 10)))
	if bool(r.pt):
		top.add_child(Kit.vcenter(SessionView.pt_tag()))
	v.add_child(top)
	# What to aim for on a line of its own, so the name never cuts it short.
	var words = _words(ctx, r, state)
	var line = Kit.hbox(6)
	var cap = Kit.label(str(words.cap), 9, Pal.GOOD if state == "done" else Pal.MUTED, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cap)
	var said = Kit.clip(str(words.said), 12, words.col, true)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(said)
	v.add_child(line)
	h.add_child(v)
	Kit.passthrough(h)
	var tint = Pal.LIFT if state == "in" else (Pal.GOOD if state == "done" else null)
	var face = Pal.PANEL2 if tint == null else Pal.PANEL2.lerp(tint, 0.3 if state == "done" else 0.2)
	var tap: Callable = ctx.tap
	# The key's own (unseen) text never changes, so a rebuild finds it again.
	var b = LogWidgets.key("Plan: %s" % str(r.name), face, h, tap.bind(str(r.name)), 8, 6, 2, Pal.LINE if tint == null else tint)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "In this workout. Tap to take it back (while its sets are untouched)." if state == "in" else "Add it to this workout, with last time's sets"
	b.set_meta("plan_pick", str(r.name))
	b.set_meta("plan_state", state)
	var out = Kit.vbox(4)
	out.add_child(b)
	if not r.ways.is_empty():
		var more = Kit.flow(6)
		var orl = Kit.label("OR", 10, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		for w in r.ways:
			var on = here.has(Xp.normalize_exercise(str(w.name)))
			var chip = Kit.chip(str(w.word), on, tap.bind(str(w.name)), Pal.SECOND if bool(w.new) else Pal.LIFT, 11)
			chip.tooltip_text = ("New to you: " if bool(w.new) else "") + Missions.short_name(str(w.name))
			chip.set_meta("plan_way", str(w.name))
			chip.set_meta("plan_state", "in" if on else "add")
			more.add_child(chip)
		out.add_child(Kit.pad(more, 32, 0, 0, 2))
	return out
