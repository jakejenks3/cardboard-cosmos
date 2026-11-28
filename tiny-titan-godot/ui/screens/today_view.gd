class_name TodayView
extends RefCounted
## The Hero tab's TODAY section, to read before the workout: what the player
## will probably do today, worked out from their log (Missions.day_plan via
## App.plan()). Since 2026-11-24 it is a framed section (Kit.section) with a
## band in the lifting colour (blue on a rest day) and the day's kind as a tag
## in the band. Inside it, top to bottom:
##   - the date (and, with a training split, why the day is what it is);
##   - the day's kind as a pick-one track (the split's kinds, or Lift, and
##     Rest), the combo pill beside it; on a rest day a banner with "Lift today";
##   - the body: the muscle map as a small tile beside the weekly sets of the
##     day's muscles (a training focus), the recovering parts in one line;
##   - "YOUR FOCUS ADDS" and "PROBABLY TODAY", a flat row per lift: the movement
##     as it was done last with its variation and tags, what to aim for on a
##     line of its own (white; gold is kept for rewards), why it is likely
##     (unless it is the reason the heading already gives), the warm-up for a
##     barbell, the other ways to do it after an "OR" as small tan keys, each
##     with its own aim under it (light blue: never done; `_way_key`);
##   - the movement to try, the physical therapy still needed (one row, pips),
##     the Start workout key, the likely climb or run, the perfect-day chest.
## One tap on a lift opens its page on Compare; any way of a lift, or any
## variation, completes its mission. Every row ends in the same box: an empty
## well while still to do, solid green with a tick once done today. A row's
## stripe only says a state: green done, the muscle's colour for a lift the
## focus adds, blue for something new, the PT and discipline colours.
## Coming up (AheadView) is its own section under this one (home.gd).
## The morning message on the phone says the same (MorningAlert).

static func card() -> Control:
	var plan = App.plan()
	var wu = App.weight_unit()
	# A rest day (a rest from lifting: only ever the player's call) says so in
	# the band, where the day's kind would be.
	var off = bool(plan.get("off", false))
	var col = Pal.SECOND if off else Pal.LIFT
	var band_tag = null
	if off:
		band_tag = Kit.tag("Rest day", Pal.SECOND, true, 13)
	elif str(plan.label) != "":
		band_tag = Kit.tag(str(plan.label), Pal.LIFT, true, 13)
	var c = Kit.section("today", "TODAY", "sun", col, band_tag, Callable(), 8, 10)
	# The day: a calendar in a slot, the date big, what kind of day it is under it (always two lines, so
	# the day's track under them never moves).
	var when = Dates.format_date(App.today, {"weekday": "long", "month": "short", "day": "numeric"})
	var kind_why = Missions.kind_why(plan) if not plan.cycle.is_empty() else ""
	c.add(_day_head(when, plan, kind_why, col))
	# What today is, one tap to change it: the split's kinds and Rest.
	if not plan.cycle.is_empty() or off or plan.lifts.any(func(l): return not bool(l.pt)):
		c.add(_day_row(plan))
	if off:
		c.add(_rest_row(plan))
	# The body: what is recovering, and (a training focus, game/dose.gd) the
	# sets the day's muscles got this week.
	var lifted = App.sessions().any(func(s): return str(s.get("discipline", "")) == "lift")
	var focus = str(plan.get("focus", "")) != ""
	if lifted and focus:
		c.add(_body_row(plan))
	elif lifted:
		c.add(RecoveryView.row())
	elif focus:
		c.add(DoseView.row(plan))
	# The main key of the day, first, as in the mock-up the user picked.
	var start = _start_row(plan)
	if start != null:
		c.add(start)
	var nothing = plan.lifts.is_empty() and plan.others.is_empty() and plan.pt.is_empty() and plan.new == null
	if nothing:
		if not off:
			c.add(Kit.para("No pattern for today yet. After a few weeks of workouts this card guesses what is next and what to aim for.", 13, Pal.MUTED))
		return c
	# What the focus adds (a muscle that is short this week) goes first: the
	# heavy lift before the usual ones.
	var extra = plan.lifts.filter(func(l): return l.has("dose"))
	var usual = plan.lifts.filter(func(l): return not l.has("dose"))
	if not extra.is_empty():
		c.add(Kit.sub_head("YOUR FOCUS ADDS", JourneyLifts.part_color(str(extra[0].dose.part)), null, "What a muscle still needs this week, from your training focus"))
		for l in extra:
			c.add(_lift_row(l, wu, Missions.same_of(str(l.name), plan)))
	if not usual.is_empty():
		var shared = _shared_why(usual)
		var n_done = usual.filter(func(l): return _done_name(l, plan) != "").size()
		# How many are done in the heading; the reason most of them share said
		# once, in full, on its own line under it (the rows then leave it out).
		var count = Kit.label("%d of %d done" % [n_done, usual.size()], 11, Pal.GOOD if n_done > 0 else Pal.MUTED, true)
		c.add(Kit.sub_head("PROBABLY TODAY", Pal.LIFT, count, "From the days and gaps of your last six weeks"))
		if shared != "":
			c.add(Kit.para(shared, 12, Pal.MUTED))
		for l in usual:
			c.add(_lift_row(l, wu, {} if bool(l.pt) else Missions.same_of(str(l.name), plan), shared))
	if plan.new != null:
		c.add(_new_row(plan.new))
	if not plan.pt.is_empty():
		c.add(_pt_row(plan))
	for o in plan.others.slice(0, 2):
		c.add(_other_row(o))
	var perfect = App.quests().daily.filter(func(m): return m.get("perfect", false))
	if not perfect.is_empty():
		c.add(_perfect_row(perfect[0]))
	return c


## The head of the day: a calendar in a slot, the date, and the kind of day (or why) under it.
static func _day_head(when: String, plan: Dictionary, kind_why: String, col: Color) -> Control:
	var h = Kit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Kit.badge("calendar", col, 24)))
	var v = Kit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.clip(when, 19, null, true))
	var kind = str(plan.get("label", ""))
	var said = ""
	if bool(plan.get("off", false)):
		said = "REST DAY · " + (kind_why if kind_why != "" else "your call")
	elif kind != "" and kind_why != "":
		said = "%s · %s" % [kind.to_upper(), kind_why]
	elif kind != "":
		said = kind.to_upper()
	elif kind_why != "":
		said = kind_why
	else:
		said = "What is likely today, from your last weeks"
	v.add_child(Kit.clip(said, 12, Pal.ACCENT2, true))
	h.add_child(v)
	return h


## The reason two or more of the usual lifts share (the most common one), or "".
static func _shared_why(usual: Array) -> String:
	var counts = {}
	var best = ""
	var most = 0
	for l in usual:
		var w = str(l.get("why", ""))
		if w == "":
			continue
		counts[w] = int(counts.get(w, 0)) + 1
		if int(counts[w]) > most:
			most = int(counts[w])
			best = w
	return best if most >= 2 else ""


## The body on a lifting player's day with a training focus: the muscle map as
## a small tile beside the weekly sets of the day's muscles, then the parts
## still recovering by name (the tile has no room for them).
static func _body_row(plan: Dictionary) -> Control:
	var v = Kit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = Kit.hbox(8)
	var tile = RecoveryView.tile()
	tile.size_flags_vertical = Control.SIZE_FILL
	h.add_child(tile)
	var dose = DoseView.row(plan, true)
	dose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dose.size_flags_vertical = Control.SIZE_FILL
	h.add_child(dose)
	v.add_child(h)
	var words = RecoveryView.warm_words()
	if words != "":
		var l = Kit.clip("Recovering: " + words, 11, Pal.MUTED)
		l.set_meta("recovering_line", true)
		v.add_child(l)
	return v


## What a planned lift was done as today (any way of it), or "".
static func _done_name(l: Dictionary, plan: Dictionary) -> String:
	return Missions.lift_done(l, plan, App.sessions(), App.today)


## The lifts "Start workout" sends to the Log tab: the day's lifts still to
## do, each as it would be done first (the way it was done last). Physical
## therapy is not sent: it is its own goal, not one of the day's lifts.
static func workout_names(plan: Dictionary) -> Array:
	var names = []
	var seen = {}
	for l in plan.lifts:
		if _done_name(l, plan) != "":
			continue
		var opts = l.get("options", [])
		var nm = str(opts[0].name) if not opts.is_empty() else str(l.name)
		var k = Xp.normalize_exercise(nm)
		if not seen.has(k):
			seen[k] = true
			names.append(nm)
	return names


## One key from the plan to the Log tab: the day's lifts are there with last
## time's sets, so only what is different needs a tap. A workout under way
## (kept as it is typed, or saved once today) is picked up again.
static func _start_row(plan: Dictionary):
	var names = workout_names(plan)
	var draft = App.draft_load("lift") != null
	var going = App.lift_today()
	if names.is_empty() and not draft:
		return null
	var b = Kit.button("Continue workout" if (draft or going != null) else "Start workout", "good", _start.bind(names), "lg", "lift")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "The Log tab with %s and last time's sets" % ("your workout as you left it" if draft else ("%d lift%s" % [names.size(), "" if names.size() == 1 else "s"]))
	b.set_meta("start_workout", true)
	return b


static func _start(names: Array) -> void:
	Sfx.tap()
	if App.draft_load("lift") != null:
		# Under way: as it was left (nothing is added to it again).
		App.open_log("lift")
		return
	var going = App.lift_today()
	App.pending_workout = names.duplicate()
	App.open_log("lift", going.id if going != null else null)


## Perfect day: a chest that fills as the boxes tick; once all are ticked it
## glows and opens with a burst. The boxes are pips on a line of their own, so
## a day with many never widens the row.
static func _perfect_row(m: Dictionary) -> Control:
	var c = Kit.row(Callable(), Pal.GOOD if bool(m.claimed) else Pal.ACCENT, Pal.ACCENT, 8, 4, 0.1)
	var row = Kit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chest = Icons.rect("chest" if not bool(m.claimed) else "gift", 28)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(chest))
	var v = Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## (2026-11-27 review: 11 px gold caps on cream were faint) the chest's name on a gold tag.
	v.add_child(Kit.tag("PERFECT DAY", Pal.ACCENT, true, 11))
	var said = "Opened: +%s XP" % Xp.fmt_int(int(m.xp)) if bool(m.claimed) else ("Every box ticked!" if bool(m.done) else "%d of %d boxes ticked" % [int(m.progress), int(m.target)])
	v.add_child(Kit.clip(said, 12, Pal.TEXT if bool(m.done) else Pal.MUTED, true))
	row.add_child(v)
	if bool(m.done) and not bool(m.claimed):
		var b = Kit.button("Open the chest", "good", Callable(), "sm", "gift")
		b.pressed.connect(_open_chest.bind(m, chest, c))
		Fx.shine(b, 2.0, 0.3, 0.5)
		Fx.twinkle(chest, Pal.ACCENT, 3)
		row.add_child(Kit.vcenter(b))
	elif not bool(m.claimed):
		row.add_child(Kit.vcenter(Kit.tag("+%s XP" % Xp.fmt_int(int(m.xp)), Pal.ACCENT, true, 11)))
	else:
		row.add_child(_tick(true))
	c.add(row)
	c.add(Kit.pips(int(m.progress), int(m.target), Pal.GOOD if bool(m.done) else Pal.ACCENT, 10))
	return c


static func _open_chest(m: Dictionary, chest: Control, card: Control) -> void:
	Kit.burst(chest, Pal.ACCENT, 48)
	Kit.burst(card, Pal.GOOD, 24)
	Kit.floater(card, "PERFECT DAY", Pal.ACCENT, 0.0, 2)
	Kit.floater(card, "+%s XP" % Xp.fmt_int(int(m.xp)), Pal.GOOD, 0.35, 2)
	Sfx.level_up()
	App.claim_quest(m)


## A rest day, a rest from lifting (only ever the player's call): what waits
## for tomorrow, what is still fine today, and a key to lift after all.
static func _rest_row(plan: Dictionary) -> Control:
	var c = Kit.row(Callable(), Pal.SECOND, Pal.SECOND, 8, 2)
	c.set_meta("rest_row", true)
	var h = Kit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.vcenter(Icons.rect("moon", 24)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Kit.label("REST DAY · YOUR CALL", 11, Pal.SECOND, true))
	v.add_child(Kit.clip(Missions.off_moves(plan), 14, Pal.TEXT, true))
	v.add_child(Kit.clip("Your run, PT and a walk are still fine", 12, Pal.MUTED))
	h.add_child(v)
	var b = Kit.button("Lift today", "secondary", _call_day.bind("lift"), "sm", "lift")
	b.tooltip_text = "Make today a lift day after all"
	b.set_meta("lift_today", true)
	h.add_child(Kit.vcenter(b))
	c.add(h)
	return c


## What today is, one tap to change it: a key per kind of the training split
## (today's raised; another one plans today as that kind, the split's own goes
## back to it) and one for a rest day, all on one sunken track. Without a
## split: Lift and Rest. Rest = no lifting today (Missions.call_of): the day's
## lifts are tomorrow's and the split follows, a day later. Tapping Rest again,
## a kind, or "Lift today" on the banner makes it a lift day again.
static func _day_row(plan: Dictionary) -> Control:
	var h = Kit.hbox(8)
	var off = bool(plan.get("off", false))
	var keys = []
	if plan.cycle.is_empty():
		var lb = Kit.choice("Lift", not off, _call_day.bind("lift"), Pal.LIFT, 13)
		lb.tooltip_text = "Lift today"
		keys.append(lb)
	for k in plan.cycle:
		var b = Kit.choice(str(Missions.KIND_SHORT[k]), not off and str(k) == str(plan.kind), _pick_kind.bind(str(k)), Pal.LIFT, 13)
		b.tooltip_text = "Plan today as a %s" % str(Missions.KIND_NAMES[k]).to_lower()
		keys.append(b)
	var rb = Kit.choice("Rest", off, _call_day.bind("rest"), Pal.SECOND, 13)
	rb.tooltip_text = "No lifting today: the day's lifts move to tomorrow, and the days after follow"
	rb.set_meta("rest_chip", true)
	keys.append(rb)
	var track = Kit.choice_track(keys)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(track)
	# The split combo: lift days this week in the split's order.
	var cb = Missions.combo(App.sessions(), App.today, plan.cycle, App.pt())
	if int(cb.now) >= 2:
		var pill = Kit.pill("flame", "×%d" % int(cb.now), Pal.ACCENT2, "Combo: %d lift days in a row in your split's order this week" % int(cb.now), Color.WHITE, 13)
		Fx.embers(pill, Pal.ACCENT2, 2)
		h.add_child(Kit.vcenter(pill))
	return h


static func _pick_kind(kind: String) -> void:
	Sfx.tick()
	var st = App.settings()
	var plan = App.plan()
	var off = bool(plan.get("off", false))
	if kind == str(plan.kind) and not bool(plan.picked) and not off:
		return
	var patch = {}
	if off:
		# A kind tapped on a rest day: a lift day after all.
		patch["dayCalls"] = Missions.with_call(st, App.today, false, App.today)
	if kind != str(plan.kind) or bool(plan.picked):
		# The kind the split itself gives today: the pick is dropped.
		var own = Missions.day_kind(App.sessions(), App.today, plan.cycle, App.pt()).kind
		patch["dayPick"] = {} if kind == own else {"date": App.today, "kind": kind}
	App.update_settings(patch)
	App.toast("Today: %s" % str(Missions.KIND_NAMES[kind]).to_lower(), "info", "lift")


## Call today a rest day (a rest from lifting) or a lift day. Rest tapped on
## a rest day goes back to lifting.
static func _call_day(want: String) -> void:
	var plan = App.plan()
	var off = bool(plan.get("off", false))
	if want == "lift" and not off:
		return
	if want == "rest" and off:
		want = "lift"
	if want == "rest" and Dose.hard_on(App.sessions(), App.pt(), App.today):
		Sfx.tick()
		App.toast("You have lifted today: it stays a lift day", "info", "lift")
		return
	Sfx.tick()
	App.update_settings({"dayCalls": Missions.with_call(App.settings(), App.today, want == "rest", App.today)})
	var now = App.plan()
	if want == "rest":
		App.toast("Rest day. %s." % Missions.off_moves(now), "info", "moon")
	else:
		App.toast("Lifting today%s" % ((": " + str(now.label).to_lower()) if str(now.label) != "" else ""), "info", "lift")


static func _step_kg(wu: String) -> float:
	return 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)


## What to aim for in a planned lift that is not done yet, as its row says it:
## {"cap", "said", "col"}. `main`: the way it would be done first ({"new",
## "last" (sets), "sides"}); `got`: the sets an extra lift of the focus
## already has today. The Log tab's "From today's plan" says the same.
static func aim_words(l: Dictionary, main: Dictionary, wu: String, got: int = 0) -> Dictionary:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var dose = l.get("dose")
	if bool(l.pt):
		return {"cap": "AS LAST TIME", "said": LiftHistory.describe_sets(l.last.sets, fmt_w), "col": Pal.PT}
	if l.has("aimSets") and str(main.get("name", "")) == str(l.name):
		# A prepped day (game/prep.gd): the sets the player prepped.
		return {"cap": "YOUR PREP", "said": Prep.describe(l.aimSets, str(l.name), fmt_w), "col": Pal.ACCENT}
	if dose != null:
		var cap = ("%d OF %d SETS" % [got, int(dose.sets)]) if got > 0 else ("ADD · %d SETS" % int(dose.sets))
		if bool(main.new):
			return {"cap": cap, "said": "6 to 12 reps, hard", "col": Pal.SECOND}
		return {"cap": cap, "said": LiftHistory.describe_sets(LiftTrend.next_target(main.last, _step_kg(wu)).sets, fmt_w), "col": Pal.ACCENT}
	if bool(main.new):
		return {"cap": "FIRST TIME", "said": "Find your weight", "col": Pal.SECOND}
	# (reps logged as both sides added up: the aim is that total too)
	var t = LiftTrend.next_target(main.last, _step_kg(wu))
	return {"cap": LiftTrend.aim_cap(t), "said": LiftHistory.describe_sets(t.sets, fmt_w), "col": Pal.ACCENT}


## How a lift done TODAY went, against the same lift (movement AND variation) before today:
## {"cap", "col", "kind" (first | up | same | down), "last" (sets before), "lastDate"}.
## A lift done for the first time is FIRST TIME, never "beat it" (2026-11-27: a first Bayesian
## curl said "beat it", and named the reclined curl it was never compared with).
static func done_words(done_name: String, sessions: Array, today: String) -> Dictionary:
	var sets = Missions.sets_on(sessions, done_name, today)
	var hist = Missions._history_before(sessions, done_name, today)
	if hist.is_empty():
		return {"cap": "DONE · FIRST TIME", "col": Pal.SECOND, "kind": "first", "last": [], "lastDate": ""}
	var cmp = LiftTrend.compare(sets, hist)
	var rec = not LiftTrend.records(sets, hist).is_empty()
	var out = {"last": hist[0].sets, "lastDate": str(hist[0].date)}
	if str(cmp.kind) == "up" or rec:
		out["cap"] = "DONE · RECORD" if rec else "DONE · BEAT LAST TIME"
		out["col"] = Pal.GOOD
		out["kind"] = "up"
	elif str(cmp.kind) == "down":
		out["cap"] = "DONE · LIGHTER THAN LAST TIME"
		out["col"] = Pal.TEXT
		out["kind"] = "down"
	else:
		out["cap"] = "DONE · SAME AS LAST TIME"
		out["col"] = Pal.TEXT
		out["kind"] = "same"
	return out


## "Nov 21", "yesterday": when a lift was last done, short.
static func _when(date: String) -> String:
	if date == "":
		return ""
	return Missions.when_text(date, App.today)


## A likely lift (the Workshop look, 2026-11-27, as in the mock-up the user picked): a paper slip with the body
## part's icon in a framed slot ringed in its colour, the lift and how it stands in the middle, and a solid block
## on the right: an ORANGE AIM block (the numbers to beat, big) while it is still to do, a GREEN DONE block (what
## was done) once it is. Not done: the part and why it is likely, LAST (and when), the warm-up for a barbell,
## then the other ways, each with its own aim. Done: how it went against THAT lift before (first time, beat last
## time, same, lighter) and the last time it is compared with.
static func _lift_row(l: Dictionary, wu: String, same: Dictionary = {}, shared_why: String = "") -> Card:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var opts = l.get("options", [])
	var main = opts[0] if not opts.is_empty() else {"name": str(l.name), "new": false, "last": l.last.sets, "lastDate": str(l.last.get("date", ""))}
	# An extra lift of the training focus ("dose").
	var dose = l.get("dose")
	var done_name = Missions.lift_done(l, App.plan(), App.sessions(), App.today)
	var shown = done_name if done_name != "" else str(main.name)
	var part = str(l.get("part", ""))
	if part == "":
		part = str(Missions.part_of(shown))
	var part_col = JourneyLifts.part_color(part)
	var ring = JourneyLifts.part_color(str(dose.part)) if dose != null else part_col
	var c = Kit.row(JourneyLifts.open_named.bind(shown, {"view": "compare"}), ring, Pal.GOOD if done_name != "" else null, 6, 6)
	c.tooltip_text = "Last time, and what to beat"
	c.set_meta("today_lift", str(main.name))
	var main_row = Kit.hbox(8)
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(Kit.vcenter(Kit.badge(part_icon(part), ring, 24)))
	var left = Kit.vbox(2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Line 1: the movement, its variation and tags.
	var top = Kit.squeeze(6)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp = LiftNames.split(shown)
	top.add_child(Kit.soft_name(str(sp.move), 16, null, true, 200.0))
	if str(sp.variation) != "":
		top.add_child(_var_tag(str(sp.variation), 11))
	if bool(l.pt):
		top.add_child(Kit.vcenter(SessionView.pt_tag(11)))
	elif done_name == "" and LiftTrend.plateau(_history_of(shown)) != null:
		var st_tag = Kit.tag("STUCK", Pal.DANGER, true, 11)
		st_tag.tooltip_text = "No new best for three sessions: its page has ways out"
		top.add_child(Kit.vcenter(st_tag))
	left.add_child(top)
	if done_name != "":
		# How it went against THAT lift (this movement AND variation) before today, and that last time.
		var dw = done_words(done_name, App.sessions(), App.today)
		var line2 = Kit.hbox(6)
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var word = str(dw.cap).replace("DONE · ", "")
		var tag_col = Pal.GOOD if str(dw.kind) == "up" else (Pal.SECOND if str(dw.kind) == "first" else Pal.LINE.darkened(0.2))
		var st = Kit.tag(word, tag_col, true, 11)
		st.set_meta("today_done", str(dw.kind))
		line2.add_child(Kit.vcenter(st))
		if not (dw.last as Array).is_empty():
			var was = Kit.clip("last %s · %s" % [LiftHistory.describe_sets(dw.last, fmt_w), _when(str(dw.lastDate))], 12, Pal.MUTED)
			was.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line2.add_child(Kit.vcenter(was))
		left.add_child(line2)
		var planned_key = Xp.normalize_exercise(str(main.name))
		if Xp.normalize_exercise(done_name) != planned_key and not bool(l.pt):
			## (2026-11-27 review: cut off mid-word it said nothing) wrapped, so the one line that explains the
			## row can be read whole.
			var pl_words = Kit.para("Planned: %s. Done another way, so it counts." % Missions.short_name(str(main.name)), 11, Pal.MUTED)
			pl_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
			left.add_child(pl_words)
		main_row.add_child(left)
		main_row.add_child(_done_block(LiftHistory.describe_sets(Missions.sets_on(App.sessions(), done_name, App.today), fmt_w)))
		c.add(main_row)
		return c
	# Line 2: the body part in its colour, and why it is likely (unless the heading said it).
	var why = str(l.why)
	if dose != null:
		why = "Added by your training focus"
	if why == shared_why:
		why = ""
	var kick = Kit.hbox(6)
	kick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dose != null:
		# An extra lift of the focus: the muscle it is for, on a tag (the line under the name, so the name keeps
		# its room).
		var ft = Kit.tag("FOR " + Dose.part_name(str(dose.part)).to_upper(), JourneyLifts.part_color(str(dose.part)), true, 11)
		ft.tooltip_text = "Added by your training focus"
		kick.add_child(Kit.vcenter(ft))
	elif part != "":
		var pl = Kit.label(LiftLibrary.part_name(part).to_upper(), 11, part_col, true)
		pl.set_meta("today_part", part)
		kick.add_child(Kit.vcenter(pl))
	if why != "":
		var wl = Kit.clip(why, 12, Pal.MUTED)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kick.add_child(Kit.vcenter(wl))
	if kick.get_child_count() > 0:
		left.add_child(kick)
	# LAST, and when.
	var main_last = main.get("last", [])
	if not bool(main.get("new", false)) and main_last is Array and not main_last.is_empty() and not bool(l.pt):
		var ll = Kit.clip("Last %s · %s" % [LiftHistory.describe_sets(main_last, fmt_w), _when(str(main.get("lastDate", "")))], 12, Pal.MUTED)
		ll.set_meta("today_last", str(main.get("lastDate", "")))
		left.add_child(ll)
	main_row.add_child(left)
	var aim = aim_words(l, main, wu, int(Dose.extra_done(l, App.sessions(), App.today, same).sets) if dose != null else 0)
	main_row.add_child(_aim_block(aim))
	c.add(main_row)
	# A barbell lift: the warm-up and what goes on the bar.
	if not bool(l.pt) and not bool(main.new) and Plates.is_barbell(shown):
		var top_kg = 0.0
		for one in LiftTrend.next_target(main.last, _step_kg(wu)).sets:
			top_kg = maxf(top_kg, float(one.get("weightKg", 0.0)))
		var wt = snappedf(Fmt.kg_to_unit(top_kg, wu), 0.5)
		var bits = []
		if Plates.warmup_text(wt, wu) != "":
			bits.append("Warm-up " + Plates.warmup_text(wt, wu))
		if Plates.text(wt, wu) != "":
			bits.append(Plates.text(wt, wu))
		if not bits.is_empty():
			var wl2 = Kit.para(" · ".join(PackedStringArray(bits)), 11, Pal.MUTED)
			wl2.tooltip_text = "Warm-up sets, then the plates on each side of the bar"
			c.add(wl2)
	# The other ways, each with ITS OWN aim (a way never done: new to you), each opening its own page.
	## (2026-11-27 review: one long outlined box a line, taller than the lift itself) "OR" and small tan keys
	## that wrap a few to a line, as in the mock-up: the way on top, its aim (or "new to you") small under it.
	if opts.size() > 1:
		var flow = Kit.flow(6)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(_or_word())
		var main_move = str(main.get("move", LiftNames.split(str(main.name)).move))
		for o in opts.slice(1):
			var same_move = str(o.move) == main_move
			var word2 = str(o.variation) if same_move and str(o.variation) != "" else Missions.way_word(o, main_move)
			var o_last = o.get("last", [])
			var tail = "new to you"
			if not bool(o.new) and o_last is Array and not o_last.is_empty():
				tail = "aim " + LiftHistory.describe_sets(LiftTrend.next_target(o_last, _step_kg(wu)).sets, fmt_w)
			# Done the same way many times in a row: this way is offered as a change (Missions._mark_rotation).
			var rot = str(l.get("rotate", "")) == str(o.name)
			var b = _way_key(word2, ("try a change · " if rot else "") + tail, Pal.ACCENT2 if rot else (Pal.SECOND if bool(o.new) else null), JourneyLifts.open_named.bind(str(o.name), {"view": "compare"}))
			b.tooltip_text = ("Try a change: " if rot else ("New to you: " if bool(o.new) else "")) + Missions.short_name(str(o.name)) + ("" if bool(o.new) else " · " + tail)
			b.set_meta("lift_option", str(o.name))
			b.set_meta("anchor_id", "way:%s:%s" % [str(main.name), str(o.name)])
			if rot:
				b.set_meta("rotate_option", str(o.name))
			flow.add_child(b)
		c.add(flow)
	return c


## The "OR" before the other ways (in the flow, so the keys start on its line).
static func _or_word() -> Control:
	var orl = Kit.label("OR", 11, Pal.MUTED, true)
	orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return orl


## The widest the words of a way key get before they end in "…".
const WAY_W = 190.0


## Another way to do a lift (the Workshop look, 2026-11-27 review): a small tan key (Kit.option_chip; `tint`
## null plain, blue new to you, orange a change) with the way in bold on top and `sub` (its own aim, "new to
## you") small under it. The words are laid over the key, which takes their size; they sink with its face.
static func _way_key(word: String, sub: String, tint, on_press: Callable) -> Button:
	# The key's own text is the way (unseen: the words are drawn by the labels on it), so a test or a screen
	# reader finds it by its words.
	var b = Kit.option_chip(word, tint, on_press, 12)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	b.clip_text = true
	# (option_chip's key: one art row of lip and a row of rim under it; pressed, the face sinks by as much)
	var drop = 2 * PixBox.S
	var v = Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_bottom = -drop
	var w = Kit.clip_fit(word, 12, Pal.INK, true, WAY_W)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(w)
	if sub != "":
		var sub_col = Pal.MUTED
		if tint is Color:
			sub_col = Pal.SECOND_DARK if tint == Pal.SECOND else Pal.ACCENT2.darkened(0.35)
		var s = Kit.clip_fit(sub, 10, sub_col, true, WAY_W)
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	b.add_child(v)
	var fit = func():
		var m = v.get_combined_minimum_size()
		b.custom_minimum_size = Vector2(m.x + 16.0, maxf(38.0 if Kit.fingers else 0.0, m.y + 8.0 + drop))
	fit.call()
	v.minimum_size_changed.connect(fit)
	b.button_down.connect(func():
		v.offset_top = drop
		v.offset_bottom = 0)
	b.button_up.connect(func():
		v.offset_top = 0
		v.offset_bottom = -drop)
	return b


## A lift's variation beside its movement in a squeeze row: never cut under about a word and its "…"
## (2026-11-27 review: at the shared 40 px a tag read "Dum", "Over", like broken words).
const VAR_LEAST = 64.0


static func _var_tag(variation: String, px: int) -> Control:
	var t = SessionView.variation_tag(variation, px, true)
	SqueezeRow.soften(t, float(t.get_meta("soft_w", VAR_LEAST)), VAR_LEAST)
	return t


## The icon of a body part (the Realm's stat icons), for a lift's slot.
static func part_icon(part: String) -> String:
	match part:
		"chest":
			return "st_chest"
		"shoulders", "front_delts", "side_delts", "rear_delts":
			return "st_shoulders"
		"biceps", "triceps", "forearms":
			return "st_arms"
		"back", "traps":
			return "st_back"
		"core":
			return "st_core"
		"quads", "hamstrings", "glutes", "calves", "legs":
			return "st_legs"
	return "lift"


## Width of the block at the right end of a lift's row.
## (2026-11-27 review: at 100 the caption under the numbers lost its range or its weight, "HEAVY DAY · 6-…")
const BLOCK_W = 120


## The orange block of a lift still to do: the numbers to aim for, big ("3×5"), and what they are under them
## ("AIM @ 85 kg"). Meta "done_tick" false (the row's box), "today_aim" the words.
static func _aim_block(aim: Dictionary) -> Control:
	var said = str(aim.said)
	var cap = str(aim.cap)
	# (the block's caption is short: "HEAVY DAY · 6-8" is "HEAVY 6-8"; the tooltip says it in full)
	var cap_short = cap.replace(" DAY · ", " ")
	var big = said
	var small = cap_short
	var at = said.find(" @ ")
	if at > 0:
		big = said.substr(0, at)
		small = "%s @ %s" % [cap_short, said.substr(at + 3)]
	elif said.ends_with(" bodyweight"):
		# "11, 10 bodyweight": the reps big, the bodyweight under them.
		big = said.trim_suffix(" bodyweight")
		small = "%s · BW" % cap_short
	elif said.contains(" · ") and not said.contains("sets"):
		# "3×15 · green band": the sets big, the band under them.
		var dot = said.find(" · ")
		big = said.substr(0, dot)
		small = "%s · %s" % [cap_short, said.substr(dot + 3)]
	var face = "orange" if cap.begins_with("AIM") or cap.begins_with("ADD") or cap.contains("SETS") or cap == "YOUR PREP" or cap.contains("DAY") else ("blue" if cap == "FIRST TIME" else "tan")
	if bool(aim.get("col") == Pal.PT):
		face = Pal.PT
	var b = _block(face, big, small)
	b.set_meta("done_tick", false)
	b.set_meta("today_aim", said)
	b.tooltip_text = "%s: %s" % [cap, said]
	return b


## The green block of a lift done today: DONE with a tick, and the sets done under it.
static func _done_block(sets_words: String) -> Control:
	# ("3 sets, top 77.5 kg × 5" is "top 77.5 kg × 5" in the block: the weight reached is what was cut off)
	var short = sets_words
	var top_at = short.find(" sets, top ")
	if top_at > 0:
		short = "top " + short.substr(top_at + " sets, top ".length())
	var b = _block("green", "DONE", short, "check")
	b.set_meta("done_tick", true)
	b.tooltip_text = "Done today: %s" % sets_words
	return b


## The caption under a block's numbers, fitted to `avail` px (2026-11-27 review: it was cut off with "…"):
## {"text", "px"}: as it is at 11 px, or at 10, or else on two lines, split before the weight ("HEAVY 6-8" /
## "@ 32.5 kg"), the top set or the band.
static func _fit_caption(text: String, avail: float) -> Dictionary:
	var f = Kit.font_bold()
	for px in [11, 10]:
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= avail:
			return {"text": text, "px": px}
	for cut in [" @ ", ", top ", " · "]:
		var at = text.find(cut)
		if at > 0:
			var rest = text.substr(at + cut.length())
			if cut == " @ ":
				rest = "@ " + rest
			elif cut == ", top ":
				rest = "top " + rest
			return {"text": text.substr(0, at) + "\n" + rest, "px": 10}
	return {"text": text, "px": 10}


static func _block(face, big: String, small: String, icon: String = "") -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", PixBox.block_set(face, 4, 3, 1)["normal"])
	p.custom_minimum_size = Vector2(BLOCK_W, 48)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v = Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var dark = PixBox.dark_words(face)
	var fg = Pal.INK if dark else Pal.CREAM
	var top = Kit.hbox(2)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		top.add_child(Kit.vcenter(Icons.rect(icon, 16, fg)))
	var long_words = big.length() > 9
	var bl = Kit.label(big, 17 if big.length() <= 8 else (14 if not long_words else 12), fg, true)
	bl.clip_text = true
	bl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if long_words:
		# Words, not numbers ("6 to 12 reps, hard", "11, 10 bodyweight"): two lines at most. (Not clipped: a
		# label that wraps AND clips asks for no height and shows nothing.)
		bl.clip_text = false
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.max_lines_visible = 2
	# (a clipped label asks for no width: it is given the block's)
	bl.custom_minimum_size = Vector2(BLOCK_W - (34 if icon != "" else 12), 0)
	if not dark:
		bl.add_theme_constant_override("outline_size", Kit.outline_for(16))
		bl.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	top.add_child(bl)
	v.add_child(top)
	if small != "":
		# (fitted: at 11 or 10 px, or on two lines; clipped only as a last resort. A label with line breaks and
		# clip_text still asks for the height of its lines: it is wrapping that it must not do as well.)
		var fit = _fit_caption(small, float(BLOCK_W - 14))
		var sl = Kit.label(str(fit.text), int(fit.px), fg, true)
		sl.clip_text = true
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.custom_minimum_size = Vector2(BLOCK_W - 10, 0)
		if not dark:
			sl.add_theme_constant_override("outline_size", Kit.outline_for(10))
			sl.add_theme_color_override("font_outline_color", Pal.OUTLINE)
		v.add_child(sl)
	p.add_child(v)
	return p


## A lift's history (newest first), as LiftLibrary.stats keeps it.
static func _history_of(lift_name: String) -> Array:
	var st = LiftLibrary.stats(App.sessions()).get(Xp.normalize_exercise(lift_name))
	if st == null:
		return []
	# (reps logged as both sides added up are judged by one side, as on its page)
	var sides = Sides.n(App.settings(), lift_name)
	return Sides.tagged(st.history, sides) if sides > 1 else st.history


## A done box (Kit.tick_box, the same everywhere): an empty well while still to
## do, solid green with a tick once done today.
static func _tick(done: bool) -> Control:
	var box = Kit.tick_box(done, 26)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = "Done today" if done else "Still to do today"
	box.set_meta("done_tick", done)
	return box


## Was a session of this kind logged today?
static func _did_today(discipline: String) -> bool:
	return App.sessions().any(func(s): return str(s.get("date", "")) == App.today and str(s.get("discipline", "")) == discipline)


## The movement to try: blue until done (any movement never done before, with
## the same goal, counts), then green and named as the lift that did it.
static func _new_row(nw: Dictionary) -> Card:
	# Done as the mission counts it: this movement logged today, or another one
	# never done before. Then the row names the lift that did it, so a tick never
	# stands beside a movement that was not done.
	var by = ""
	for m in App.quests().daily:
		if str(m.id).ends_with(":new") and bool(m.done):
			by = str(m.get("by", ""))
	var done = by != ""
	var c = Kit.row(JourneyLifts.open_named.bind(str(nw.name), {"view": "compare"}), Pal.GOOD if done else Pal.SECOND, Pal.GOOD if done else null, 6, 6)
	c.tooltip_text = "How to do it"
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Kit.badge("sparkle", Pal.SECOND, 24)))
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var other = done and Xp.normalize_exercise(str(LiftNames.split(by).move)) != Xp.normalize_exercise(str(nw.move))
	## (2026-11-27 review: the body part's tag beside the name squeezed the variation to "Dum") The body part
	## goes on the caption line, in its colour, as a lift row's does; the name line keeps its room.
	var kick = Kit.hbox(4)
	kick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kick.add_child(Kit.clip("SOMETHING NEW · DONE" if done else "TRY SOMETHING NEW", 11, Pal.GOOD if done else Pal.SECOND, true))
	if not other and str(nw.get("partName", "")) != "":
		var part_l = Kit.clip("· " + str(nw.partName).to_upper(), 11, JourneyLifts.part_color(str(nw.get("part", ""))), true)
		part_l.set_meta("new_part", str(nw.get("part", "")))
		kick.add_child(part_l)
	v.add_child(kick)
	var line = Kit.hbox(8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top = Kit.squeeze(6)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if other:
		var sp = LiftNames.split(by)
		top.add_child(Kit.soft_name(str(sp.move), 15, null, true, 200.0))
		if str(sp.variation) != "":
			top.add_child(_var_tag(str(sp.variation), 11))
		# (no "First time" tag here: the green block at the row's end says it, and the row had no room for both)
	else:
		top.add_child(Kit.soft_name(str(nw.move), 15, null, true, 200.0))
		if str(nw.variation) != "":
			top.add_child(_var_tag(str(nw.variation), 11))
	line.add_child(top)
	v.add_child(line)
	row.add_child(v)
	if done:
		row.add_child(_done_block("first time"))
	else:
		var nb = _block("blue", "NEW", "find your weight")
		nb.set_meta("done_tick", false)
		nb.tooltip_text = "A movement you have never done: find a weight you can do 8 to 12 times"
		row.add_child(nb)
	c.add(row)
	# Others that count just the same, for when the equipment is not there.
	var alts = nw.get("alts", [])
	if not done and not alts.is_empty():
		# (like a planned lift's other ways: "OR" and small keys, each new to you)
		var more = Kit.flow(6)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more.add_child(_or_word())
		for a in alts:
			var b = _way_key(Missions.short_name(str(a.name)), "new to you", Pal.SECOND, JourneyLifts.open_named.bind(str(a.name), {"view": "compare"}))
			b.tooltip_text = "New to you: a %s movement" % str(a.partName).to_lower()
			b.set_meta("new_alt", str(a.name))
			b.set_meta("anchor_id", "new_alt:" + str(a.name))
			more.add_child(b)
		c.add(more)
	return c


## Physical therapy as ONE row: the day's goal in SETS (Missions.pt_goal: 9 a
## day, up to Pt.SETS_A_DAY of each exercise, or fewer when fewer are still
## needed this week) as pips, the sets done today of it, and the exercises
## still needed this week, the furthest behind first, to pick from.
## (The week itself is the PT THIS WEEK section.)
static func _pt_row(plan: Dictionary) -> Control:
	var goal = Missions.pt_goal(plan)
	var done = Missions.pt_today(plan, App.sessions(), App.today)
	var left = Missions.pt_left(plan, App.sessions(), App.today)
	var all_done = done >= goal
	var c = Kit.row(PtView.open, Pal.GOOD if all_done else Pal.PT, Pal.GOOD if all_done else null, 6, 6)
	# (not the PT section's "Physical therapy: are you keeping up?": tests count that one)
	c.tooltip_text = "Today: %d %s of your PT exercises, up to %d of each, the ones furthest behind first (the week is on the PT page)" % [goal, Missions._sets_word(goal), Pt.SETS_A_DAY]
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Kit.badge("pt", Pal.PT, 24)))
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.clip("Physical therapy today", 15, null, true))
	var line2 = Kit.hbox(8)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (the goal is 9 sets at most: Kit.pips draws up to 10 squares)
	line2.add_child(Kit.pips(mini(done, goal), goal, Pal.GOOD if all_done else Pal.PT, 10))
	var count = ("%d of %d %s" % [done, goal, Missions._sets_word(goal)]) if done <= goal else ("%d sets, %d was the goal" % [done, goal])
	# (cut off rather than widen the row: the block at the right end leaves less room)
	var count_l = Kit.clip(count, 12, Pal.GOOD if all_done else Pal.MUTED, true)
	count_l.tooltip_text = count
	line2.add_child(Kit.vcenter(count_l))
	v.add_child(line2)
	var said = ""
	if all_done:
		said = "That is today's PT. More is a bonus."
	elif not left.is_empty():
		said = "Up to %d sets of each count. Any of: %s" % [Pt.SETS_A_DAY, ", ".join(PackedStringArray(left))]
	if said != "":
		# (wrapped, not cut off: the names are what to pick from)
		var said_l = Kit.para(said, 12, Pal.MUTED)
		said_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(said_l)
	row.add_child(v)
	if all_done:
		row.add_child(_done_block("%d %s" % [done, Missions._sets_word(done)]))
	else:
		var pb = _block(Pal.PT, "%d / %d" % [done, goal], "SETS TODAY")
		pb.set_meta("done_tick", false)
		pb.tooltip_text = "PT sets done today, of today's goal"
		row.add_child(pb)
	c.add(row)
	return c


## The likely climb or run: its name in its colour, what it usually is (or on
## the run day what to aim for), why, the open project, a quicker pace.
static func _other_row(o: Dictionary) -> Control:
	var d = str(o.discipline)
	var did = _did_today(d)
	var dcol = Pal.disc(d)
	var c = Kit.row(Callable(), Pal.GOOD if did else dcol, Pal.GOOD if did else null, 6, 6)
	var row = Kit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Kit.vcenter(Kit.badge(d if d != "misc" else "vest", dcol, 24)))
	var v = Kit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Kit.clip(TT.DISCIPLINE_META[d].name, 15, dcol, true))
	var cap = "USUALLY"
	var said = ""
	if d == "climb":
		said = "%d sends" % TTUtil.jsround(float(o.avg))
	else:
		said = Fmt.fmt_distance(float(o.avg), App.distance_unit())
	var pace = ""
	var run_goal = App.plan().get("run")
	if d == "run" and run_goal != null:
		# The weekly run on its day (training focus): further, or quicker.
		cap = "RUN DAY"
		said = "aim %s" % Fmt.fmt_distance(float(run_goal.targetM), App.distance_unit())
		if float(run_goal.paceSec) > 0.0:
			pace = "or quicker than %s over %s" % [Fmt.fmt_pace(float(run_goal.paceSec), App.distance_unit()), Fmt.fmt_distance(float(run_goal.paceM), App.distance_unit())]
	elif d == "run" and bool(App.plan().get("runToday", false)):
		cap = "RUN DAY"
		said = "log a run"
	var line2 = Kit.hbox(6)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line2.add_child(Kit.vcenter(Kit.label(cap, 11, dcol, true)))
	line2.add_child(Kit.vcenter(Kit.clip(said, 14, Pal.TEXT, true)))
	v.add_child(line2)
	if str(o.why) != "":
		v.add_child(Kit.clip(str(o.why), 12, Pal.MUTED))
	if d == "climb":
		var pj = App.open_projects()
		if not pj.is_empty():
			var st = Projects.status(pj[0], App.sessions(), App.today)
			v.add_child(Kit.clip("Project: %s · %d session%s so far" % [Projects.title(pj[0]), int(st.sessions), "" if int(st.sessions) == 1 else "s"], 12, Pal.CLIMB, true))
	if pace != "":
		v.add_child(Kit.clip(pace, 12, Pal.MUTED))
	row.add_child(v)
	if did:
		row.add_child(_done_block("logged today"))
	else:
		var big = said.replace("aim ", "")
		var ob = _block(dcol, big, cap)
		ob.set_meta("done_tick", false)
		ob.tooltip_text = "%s: %s" % [cap.capitalize(), said]
		row.add_child(ob)
	c.add(row)
	return c
