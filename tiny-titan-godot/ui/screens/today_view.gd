class_name TodayView
extends RefCounted
## The Hero tab's "Today" card, to read before the workout: what the player
## will probably do today, worked out from their log (Missions.day_plan via
## App.plan()): the body area of the day, the likely lifts with what to aim for
## (one tap opens a lift on Compare), a movement of that area never done, the
## physical therapy still to do this week and the likely run, climb or ride.
## Each lift is shown as it was done last, with the other ways the player has
## done it under it (their variations, another movement: Missions.options_for);
## any of them, or any variation, completes its mission.
## The morning message on the phone says the same (MorningAlert).

static func card() -> Control:
	var plan = App.plan()
	var wu = App.weight_unit()
	var c = Kit.card(8, Callable(), 12)
	c.accent(Pal.ACCENT)
	var head = Kit.hbox(8)
	head.add_child(Kit.vcenter(Icons.rect("sun", 24)))
	var words = Kit.vbox(1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t = PixelFont.rect("TODAY", 2, Pal.ACCENT)
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	words.add_child(t)
	words.add_child(Kit.clip(Dates.format_date(App.today, {"weekday": "long", "month": "short", "day": "numeric"}), 12, Pal.MUTED, true))
	head.add_child(words)
	if str(plan.label) != "":
		head.add_child(Kit.vcenter(Kit.tag(str(plan.label), Pal.LIFT, true, 13)))
	c.add(head)
	if not plan.cycle.is_empty():
		c.add(Kit.clip(Missions.kind_why(plan), 12, Pal.MUTED, true))
		c.add(_split_row(plan))
	var nothing = plan.lifts.is_empty() and plan.others.is_empty() and plan.pt.is_empty() and plan.new == null
	if nothing:
		c.add(Kit.para("No pattern for today yet. After a few weeks of workouts this card guesses what is next and what to aim for.", 13, Pal.MUTED))
		return c
	if not plan.lifts.is_empty():
		c.add(_kicker("PROBABLY TODAY", "From the days and gaps of your last six weeks"))
		for l in plan.lifts:
			c.add(_lift_row(l, wu))
	if plan.new != null:
		c.add(_new_row(plan.new))
	if not plan.pt.is_empty():
		c.add(_pt_row(plan.pt))
	for o in plan.others.slice(0, 2):
		c.add(_other_row(o))
	return c


## The training split: a chip per kind of the cycle (today's lit). Tapping
## another one plans today as that kind; tapping the one the split gave goes
## back to it.
static func _split_row(plan: Dictionary) -> Control:
	var v = Kit.vbox(4)
	var chips = Kit.hbox(6)
	for k in plan.cycle:
		var b = Kit.chip(str(Missions.KIND_SHORT[k]), str(k) == str(plan.kind), _pick_kind.bind(str(k)), Pal.LIFT, 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "Plan today as a %s" % str(Missions.KIND_NAMES[k]).to_lower()
		chips.add_child(b)
	v.add_child(chips)
	return v


static func _pick_kind(kind: String) -> void:
	Sfx.tick()
	var st = App.settings()
	var plan = App.plan()
	if kind == str(plan.kind) and not bool(plan.picked):
		return
	# The kind the split itself gives today: the pick is dropped.
	var own = Missions.day_kind(App.sessions(), App.today, plan.cycle, App.pt()).kind
	App.update_settings({"dayPick": {} if kind == own else {"date": App.today, "kind": kind}})
	App.toast("Today: %s" % str(Missions.KIND_NAMES[kind]).to_lower(), "info", "lift")


static func _kicker(text: String, tip: String) -> Control:
	var l = Kit.label(text, 10, Pal.MUTED, true)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


static func _step_kg(wu: String) -> float:
	return 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)


## A likely lift as done last (its first option): name and variation, why it
## is likely, what to aim for; the other ways the player has done it under it
## as chips. Done today (any way): what was done.
static func _lift_row(l: Dictionary, wu: String) -> Card:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var opts = l.get("options", [])
	var main = opts[0] if not opts.is_empty() else {"name": str(l.name), "new": false, "last": l.last.sets}
	var planned_move = str(LiftNames.split(str(l.name)).move)
	var ways = []
	for o in opts:
		if not ways.has(str(o.name)):
			ways.append(str(o.name))
	var done_name = Missions.done_of(App.sessions(), ways if not ways.is_empty() else [str(l.name)], App.today, "" if bool(l.pt) else planned_move)
	var shown = done_name if done_name != "" else str(main.name)
	var c = Kit.card(0, JourneyLifts.open_named.bind(shown, {"view": "compare"}), 8)
	c.tooltip_text = "Last time, and what to beat"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left = Kit.vbox(1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp = LiftNames.split(shown)
	top.add_child(Kit.clip_fit(str(sp.move), 13, null, true, 170.0))
	if str(sp.variation) != "":
		top.add_child(Kit.vcenter(SessionView.variation_tag(str(sp.variation))))
	if bool(l.pt):
		top.add_child(Kit.vcenter(SessionView.pt_tag()))
	left.add_child(top)
	left.add_child(Kit.clip(str(l.why), 11, Pal.MUTED))
	row.add_child(left)
	var right = Kit.vbox(1)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var said = ""
	var cap = ""
	var col = Pal.PT if bool(l.pt) else Pal.ACCENT
	if done_name != "":
		# Already done today (any way): what was done, green when it beat last
		# time or was a first.
		var beat = Missions.beat_any(App.sessions(), ways if not ways.is_empty() else [str(l.name)], "" if bool(l.pt) else planned_move, App.today)
		said = LiftHistory.describe_sets(Missions.sets_on(App.sessions(), done_name, App.today), fmt_w)
		cap = "DONE · BEAT IT" if beat else "DONE TODAY"
		col = Pal.GOOD if beat else Pal.TEXT
		c.accent(Pal.GOOD if beat else Pal.LINE)
	elif bool(l.pt):
		said = LiftHistory.describe_sets(l.last.sets, fmt_w)
		cap = "AS LAST TIME"
	elif bool(main.new):
		said = "Find your weight"
		cap = "FIRST TIME"
		col = Pal.SECOND
	else:
		said = LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w)
		cap = "AIM"
	var cl = Kit.label(cap, 9, Pal.GOOD if col == Pal.GOOD else Pal.MUTED, true)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cl)
	var al = Kit.label(said, 12, col, true)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(al)
	row.add_child(right)
	c.add(row)
	# The other ways to do it here, each opening its own page.
	if done_name == "" and opts.size() > 1:
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var orl = Kit.label("OR", 10, Pal.MUTED, true)
		orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.add_child(orl)
		for o in opts.slice(1):
			var same = str(o.move) == str(main.get("move", LiftNames.split(str(main.name)).move))
			var text = str(o.variation) if same and str(o.variation) != "" else Missions.short_name(str(o.name))
			var b = Kit.chip(text, false, JourneyLifts.open_named.bind(str(o.name), {"view": "compare"}), Pal.LIFT, 11)
			b.tooltip_text = ("New to you: " if bool(o.new) else "") + Missions.short_name(str(o.name))
			more.add_child(b)
		c.add(more)
	return c


static func _new_row(nw: Dictionary) -> Card:
	var c = Kit.card(0, JourneyLifts.open_named.bind(str(nw.name), {"view": "compare"}), 8)
	c.accent(Pal.SECOND)
	c.tooltip_text = "How to do it"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect("sparkle", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("TRY SOMETHING NEW", 10, Pal.SECOND, true))
	var top = Kit.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(Kit.clip_fit(str(nw.move), 13, null, true, 170.0))
	if str(nw.variation) != "":
		top.add_child(Kit.vcenter(SessionView.variation_tag(str(nw.variation))))
	top.add_child(Kit.vcenter(Kit.tag(str(nw.partName), JourneyLifts.part_color(str(nw.part)), true, 10)))
	v.add_child(top)
	row.add_child(v)
	row.add_child(Kit.vcenter(Icons.rect("chevron_right", 16)))
	c.add(row)
	return c


static func _pt_row(rows: Array) -> Control:
	var c = Kit.card(0, PtView.open, 8)
	c.accent(Pal.PT)
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect("pt", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("PHYSICAL THERAPY THIS WEEK", 10, Pal.PT, true))
	var names = []
	var left = 0
	for r in rows:
		names.append(str(r.name))
		left += int(r.left)
	v.add_child(Kit.clip(", ".join(PackedStringArray(names)), 13, Pal.TEXT, true))
	row.add_child(v)
	row.add_child(Kit.vcenter(Kit.tag("%d to go" % left, Pal.PT, true, 11)))
	c.add(row)
	return c


static func _other_row(o: Dictionary) -> Control:
	var d = str(o.discipline)
	var c = Kit.card(0, Callable(), 8)
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Icons.rect(d if d != "misc" else "vest", 20)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(TT.DISCIPLINE_META[d].name, 13, Pal.disc(d), true))
	v.add_child(Kit.clip(str(o.why), 11, Pal.MUTED))
	row.add_child(v)
	var usual = ""
	if d == "climb":
		usual = "%d sends" % TTUtil.jsround(float(o.avg))
	else:
		usual = Fmt.fmt_distance(float(o.avg), App.distance_unit())
	var u = Kit.label("usually %s" % usual, 12, Pal.TEXT, true)
	row.add_child(Kit.vcenter(u))
	c.add(row)
	return c
