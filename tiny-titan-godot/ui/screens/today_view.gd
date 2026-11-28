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
##   - the day's lifts as one list, a row per lift (see ONE LIST below: its ways
##     and its challenge are in the row);
##   - Prep today and Start workout, side by side;
##   - the body: the muscle map as a small tile beside the weekly sets of the
##     day's muscles (a training focus), the recovering parts in one line;
##   - the movement to try (its others after an "OR" as small tan keys, each
##     with "new to you" under it: `_way_key`), the physical therapy still
##     needed (one row, pips), the likely climb or run, the perfect-day chest.
## One tap on a lift opens its page on Compare; a way done instead counts for
## its mission. Every row ends in the same box: an empty
## well while still to do, solid green with a tick once done today. A row's
## stripe only says a state: green done, the muscle's colour for a lift the
## focus adds, blue for something new, the PT and discipline colours.
## Coming up (AheadView) is its own section under this one (home.gd).
## The morning message on the phone says the same (MorningAlert).
##
## (2026-11-28, the user: "I want it to show the exercises I might do that day at the top, and be able to prep
## my day from there or from the coming up section. Now it's day of my workout and I can't prep one for TODAY")
## The order is now: the date, the day's track (or the rest banner), THE LIFTS OF THE DAY right under them,
## then one row of two keys, "Prep today" (PrepView for today; "Edit prep" once it is prepped, meta
## `prep_today` = prepped) and Start / Continue workout, then the body row, the movement to try, the PT, the
## run or climb and the perfect-day chest.
##
## ONE LIST (2026-11-28, later: "It like almost works but is too muddled for some reason"). The CHALLENGES
## section under this card is gone; each lift appears once, in one list ("TODAY'S WORKOUT", or "YOUR PREP FOR
## TODAY" once prepped; the focus's extra lifts first, with their FOR <MUSCLE> tag), and its row holds:
##   - the head as before: the part's icon, the lift, how it stands, and the block on the right (the orange
##     AIM, the GOLD goal block with a star that twinkles when a record is the lift's goal (meta `today_goal`
##     = its type), the green DONE);
##   - "TODAY'S WAY": the lift's ways as keys (ChallengeView.way_key: today's lit orange, one never done light
##     blue, the others tan; metas `lift_option` and `challenge_way` = the way's name). A tap makes it today's
##     way in today's prep (App.prep_way), for the equipment there is; the row then shows that way. The keys
##     keep the order they were first shown in today (`_stable_ways`), whatever the prep puts first;
##   - for the day's three challenge missions, the MISSION strip (ChallengeView.strip, meta `challenge` = the
##     mission's id): PICK ONE / YOUR GOAL, the reward or the Claim key, and the records as tiles; a tap makes
##     one the lift's goal in today's prep (App.prep_goal), a tap on the goal takes it off.
## A tap anywhere else on the row opens the lift's page, as before.

## The challenge missions the last card drew in its rows (their ids): home.gd's MISSIONS leaves those out.
static var shown_challenges = {}
## The ways of each lift row in the order first shown today (`_stable_ways`): [{"ref": the movement the ways
## are named against, "names": the ways}]. Kept while the game runs; a new day starts again.
static var _ways_day = ""
static var _ways_groups = []


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
	var nothing = plan.lifts.is_empty() and plan.others.is_empty() and plan.pt.is_empty() and plan.new == null
	## (2026-11-28) The lifts of the day first, right under the date: what the user opens the card to see.
	if nothing and not off:
		c.add(Kit.para("No pattern for today yet. After a few weeks of workouts this card guesses what is next and what to aim for. Prep today to pick your own lifts.", 13, Pal.MUTED))
	# One list: what the focus adds (a muscle that is short this week) first, the heavy lift before the usual
	# ones; each row with its ways and, for the day's challenges, its MISSION strip.
	shown_challenges = {}
	var lifts = plan.lifts.filter(func(l): return l.has("dose")) + plan.lifts.filter(func(l): return not l.has("dose"))
	if not lifts.is_empty():
		var usual = lifts.filter(func(l): return not l.has("dose"))
		var shared = _shared_why(usual)
		_lifts_head(c, plan, lifts, shared)
		var missions = App.quests().get("daily", []).filter(func(m): return bool(m.get("challenge", false)))
		var slots = _stable_ways(lifts.map(func(l): return _ways_of(l)))
		# (what the player has ever logged: a way never done is a light blue key, a way done has its aim)
		var known = LiftLibrary.stats(App.sessions())
		for i in range(lifts.size()):
			var l = lifts[i]
			var m = _mission_of(l, missions)
			if m != null:
				shown_challenges[str(m.id)] = true
			c.add(_lift_row(l, wu, {} if bool(l.pt) else Missions.same_of(str(l.name), plan), shared, slots[i], known, m))
	# The two keys of the day: prep it, then start it.
	var keys = _keys_row(plan)
	if keys != null:
		c.add(keys)
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
	if nothing:
		return c
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


## The list's head: "TODAY'S WORKOUT" ("YOUR PREP FOR TODAY" once the day is prepped) with how many are done,
## then ONE line under it, always there so prepping the day moves nothing: the reason most of the lifts share
## (the rows then leave it out), else what a tap on a way does.
static func _lifts_head(c: Card, plan: Dictionary, lifts: Array, shared: String) -> void:
	var prepped = bool(plan.get("prepped", false))
	var n_done = lifts.filter(func(l): return _done_name(l, plan) != "").size()
	var count = Kit.label("%d of %d done" % [n_done, lifts.size()], 11, Pal.GOOD if n_done > 0 else Pal.MUTED, true)
	if prepped:
		c.add(Kit.sub_head("YOUR PREP FOR TODAY", Pal.LIFT, count, "The lifts, ways and sets you prepped for today"))
	else:
		c.add(Kit.sub_head("TODAY'S WORKOUT", Pal.LIFT, count, "From the days and gaps of your last six weeks"))
	var line = ""
	if prepped:
		line = "Your prep. Tap a way or a record to change it."
	elif shared != "":
		line = shared
	else:
		line = "Tap a way for the equipment you have today."
	var l = Kit.clip(line, 12, Pal.MUTED)
	l.tooltip_text = line
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.set_meta("today_list_line", line)
	c.add(l)


## A row's ways: the lift as the day does it first, then its other ways (Missions.options_for), each once.
static func _ways_of(l: Dictionary) -> Array:
	var names = []
	var seen = {}
	var list = l.get("options", [])
	if list.is_empty():
		list = [{"name": str(l.name)}]
	for o in list:
		var k = Xp.normalize_exercise(str(o.name))
		if k == "" or seen.has(k):
			continue
		seen[k] = true
		names.append(str(o.name))
	return names


## The ways of every row in the order first shown today, so a way key never moves when the prep puts another
## way first: [{"gi": the row's place, "names", "ref"}] for `lists` (a list of names per row, the row's lift
## first). A row is the row shown before when its lift was one of that row's ways (the first pass), else when
## they share any way; else it is new. Its ways are ALL the ways shown for it before today, in that order (a
## way picked offers other ways than the one before it: none of the keys already there goes away, so none
## moves), then any new one at the end.
static func _stable_ways(lists: Array) -> Array:
	if _ways_day != App.today:
		_ways_day = App.today
		_ways_groups = []
	var keys = lists.map(func(names): return (names as Array).map(func(n): return Xp.normalize_exercise(str(n))))
	var at = []
	at.resize(lists.size())
	at.fill(-1)
	var used = {}
	for pass_n in [0, 1]:
		for j in range(lists.size()):
			if int(at[j]) >= 0 or (keys[j] as Array).is_empty():
				continue
			for i in range(_ways_groups.size()):
				if used.has(i):
					continue
				var gk = (_ways_groups[i].names as Array).map(func(n): return Xp.normalize_exercise(str(n)))
				var hit = gk.has(keys[j][0]) if pass_n == 0 else (keys[j] as Array).any(func(k): return gk.has(k))
				if hit:
					at[j] = i
					used[i] = true
					break
	var out = []
	for j in range(lists.size()):
		var names = lists[j]
		var gi = int(at[j])
		if gi < 0:
			var first = str(names[0]) if not (names as Array).is_empty() else ""
			_ways_groups.append({"ref": str(LiftNames.split(first).move), "names": (names as Array).duplicate()})
			gi = _ways_groups.size() - 1
		else:
			var kept = (_ways_groups[gi].names as Array).duplicate()
			var kept_keys = kept.map(func(n): return Xp.normalize_exercise(str(n)))
			for q in range((names as Array).size()):
				if not kept_keys.has(keys[j][q]):
					kept.append(names[q])
					kept_keys.append(keys[j][q])
			_ways_groups[gi]["names"] = kept
		out.append({"gi": gi, "names": _ways_groups[gi].names, "ref": str(_ways_groups[gi].ref)})
	return out


## The day's challenge mission of a planned lift: the one whose lift is the row's (the way it is done today),
## else the one planned for it; null when it has none.
static func _mission_of(l: Dictionary, missions: Array):
	var opts = l.get("options", [])
	var lk = Xp.normalize_exercise(str(opts[0].name) if not opts.is_empty() else str(l.name))
	for m in missions:
		if Xp.normalize_exercise(str(m.get("lift", ""))) == lk:
			return m
	var pk = Xp.normalize_exercise(str(l.name))
	for m in missions:
		if Xp.normalize_exercise(str(m.get("planned", ""))) == pk:
			return m
	return null


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


## The row under the day's lifts (2026-11-28): "Prep today" (a wooden key: PrepView for today, where each
## lift's way, sets, supersets and a record to go for are picked; "Edit prep" once today is prepped;
## meta `prep_today` = prepped) and Start / Continue workout (green, meta `start_workout`). Side by side when
## they fit, else one under the other (a flow: never wider than the card). A rest day has no Prep key; null
## when there is neither key.
static func _keys_row(plan: Dictionary):
	var start = _start_row(plan)
	var prep = null
	if not bool(plan.get("off", false)):
		var prepped = Prep.of(App.settings(), App.today) != null
		# ("Edit prep", not "Edit today's prep": short enough to stay beside Start workout, so the two keys never
		# fall to two lines when the day gets prepped from a way or a record above them)
		prep = Kit.button("Edit prep" if prepped else "Prep today", "secondary", PrepView.open.bind(App.today), "lg", "edit")
		prep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prep.tooltip_text = "Pick today's lifts the way you'll do them, with what you have: their sets, supersets and a record to go for"
		prep.set_meta("prep_today", prepped)
	if prep == null:
		return start
	if start == null:
		return prep
	var row = Kit.flow(8)
	row.add_child(prep)
	row.add_child(start)
	return row


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
## on the right: an ORANGE AIM block (the numbers to beat, big) while it is still to do, a GOLD block when a
## record is its goal today, a GREEN DONE block (what was done) once it is. Not done: the part and why it is
## likely, LAST (and when); then (2026-11-28) "TODAY'S WAY", its ways as keys (`_ways_row`), the warm-up for a
## barbell, and the MISSION strip of its challenge (ChallengeView.strip). Done: how it went against THAT lift
## before (first time, beat last time, same, lighter), the last time it is compared with, and the mission strip
## (its Claim key). `slot`: the row's ways in a stable order ({"gi", "names", "ref"}, `_stable_ways`);
## `known`: LiftLibrary.stats of the log (a way never done, a way's aim); `m`: its challenge mission or null.
static func _lift_row(l: Dictionary, wu: String, same: Dictionary = {}, shared_why: String = "", slot: Dictionary = {}, known: Dictionary = {}, m = null) -> Card:
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
	var gi = int(slot.get("gi", 0))
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
		# (2026-11-28) the record picked as today's goal, met by today's sets of that lift
		var g_done = _goal_of(l, main)
		if not g_done.is_empty() and Challenges.hit(g_done, Missions.sets_on(App.sessions(), str(l.name), App.today)):
			var gm = _gold_tag("GOAL MET", 11, 90.0)
			gm.set_meta("today_goal", str(g_done.get("type", "")))
			gm.tooltip_text = "Today's goal: %s" % goal_words(g_done, wu)
			line2.add_child(Kit.vcenter(gm))
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
		# (its challenge: done, with its Claim key, or still open: a record can still be set today)
		if m != null:
			c.add(ChallengeView.strip(m, gi))
		return c
	# Line 2: the body part in its colour, and why it is likely (unless the heading said it).
	var why = str(l.why)
	if dose != null:
		why = ""
	if why == shared_why:
		why = ""
	# A record picked as today's goal (Prep.with_goal): the block on the right says it, in gold.
	var goal = _goal_of(l, main)
	var kick = Kit.hbox(6)
	kick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dose != null:
		# An extra lift of the focus: the muscle it is for, on a tag (the line under the name, so the name keeps
		# its room), and who put it there.
		var ft = Kit.tag("FOR " + Dose.part_name(str(dose.part)).to_upper(), JourneyLifts.part_color(str(dose.part)), true, 11)
		ft.tooltip_text = "Added by your training focus"
		kick.add_child(Kit.vcenter(ft))
		var fl = Kit.clip("YOUR FOCUS ADDS IT", 11, Pal.MUTED, true)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.tooltip_text = "What a muscle still needs this week, from your training focus"
		fl.mouse_filter = Control.MOUSE_FILTER_PASS
		kick.add_child(Kit.vcenter(fl))
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
	if not goal.is_empty():
		main_row.add_child(_goal_block(goal, wu))
	else:
		var aim = aim_words(l, main, wu, int(Dose.extra_done(l, App.sessions(), App.today, same).sets) if dose != null else 0)
		main_row.add_child(_aim_block(aim))
	c.add(main_row)
	# Today's way: the lift's ways as keys, today's lit (the equipment there is).
	var names = slot.get("names", [])
	if (names as Array).size() > 1:
		c.add(_ways_row(l, main, names, str(slot.get("ref", sp.move)), gi, known, wu))
	# A barbell lift: the warm-up and what goes on the bar.
	if not bool(l.pt) and not bool(main.new) and Plates.is_barbell(shown):
		var top_kg = 0.0
		for one in LiftTrend.next_target(main.last, _step_kg(wu)).sets:
			top_kg = maxf(top_kg, float(one.get("weightKg", 0.0)))
		# (a goal's top set is what to warm up for)
		if not goal.is_empty() and str(goal.get("band", "")) == "":
			top_kg = maxf(top_kg, float(goal.get("kg", 0.0)))
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
	# Its challenge: records to pick one from as today's goal.
	if m != null:
		c.add(ChallengeView.strip(m, gi))
	return c


## "TODAY'S WAY" and a key per way of a lift (ChallengeView.way_key), in the order first shown today: the one
## the day uses lit orange, one never done light blue, the others tan; a tap makes it today's way in today's
## prep. A way's own aim (or "new to you") is in its tooltip; a way offered as a change after many times the
## same way (Missions._mark_rotation) says so there too (meta `rotate_option`).
static func _ways_row(l: Dictionary, main: Dictionary, names: Array, ref: String, gi: int, known: Dictionary, wu: String) -> Control:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var flow = Kit.flow(4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.set_meta("today_ways", str(main.name))
	var cap = Kit.label("TODAY'S WAY", 11, Pal.MUTED, true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.tooltip_text = "Pick the way you'll do it today, with the equipment you have: it goes into today's prep"
	cap.mouse_filter = Control.MOUSE_FILTER_PASS
	flow.add_child(cap)
	var cur = Xp.normalize_exercise(str(main.name))
	for n in names:
		var k = Xp.normalize_exercise(str(n))
		var st = known.get(k)
		var on = k == cur
		var fresh = not on and st == null
		var tip = ""
		if not on and st != null and not (st.history as Array).is_empty():
			tip = "aim " + LiftHistory.describe_sets(LiftTrend.next_target(st.history[0].sets, _step_kg(wu)).sets, fmt_w)
		var rot = str(l.get("rotate", "")) == str(n)
		if rot:
			tip = "try a change" + (" · " + tip if tip != "" else "")
		var b = ChallengeView.way_key(str(n), ChallengeView.way_word(str(n), ref), on, fresh, str(l.name), str(main.name), "tway:%d:%s" % [gi, k], tip)
		if rot:
			b.set_meta("rotate_option", str(n))
		flow.add_child(b)
	return flow


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


## The goal picked for a planned lift (its prep's "goal", Prep.with_goal), or {}: only when the lift is
## done the way it was prepped (`main`, its first way), since a goal belongs to one way.
static func _goal_of(l: Dictionary, main: Dictionary) -> Dictionary:
	var g = l.get("goal")
	if not (g is Dictionary) or (g as Dictionary).is_empty():
		return {}
	if Xp.normalize_exercise(str(main.get("name", l.name))) != Xp.normalize_exercise(str(l.name)):
		return {}
	return g


## A goal (a record of Challenges, kept in a prep) in words, in the player's unit now (the words stored with
## it were made in the unit of the day it was picked): "52.5 kg × 6", "10 reps at 60 kg", "12 reps with the
## green band", "15 reps in a set", "Hold 35 s".
static func goal_words(g: Dictionary, wu: String) -> String:
	var type = str(g.get("type", ""))
	var reps = int(g.get("reps", 0))
	var band = str(g.get("band", ""))
	var kg = float(g.get("kg", 0.0))
	match type:
		"set_reps":
			return "%d reps in a set" % reps
		"day_reps":
			return "%d reps in all" % reps
		"hold":
			return "Hold %d s" % int(g.get("sec", 0))
	if band != "":
		return "%d reps with the %s" % [reps, Bands.words(band)]
	if kg > 0.0:
		if type == "reps":
			return "%d reps at %s" % [reps, Fmt.fmt_weight(kg, wu)]
		return "%s × %d" % [Fmt.fmt_weight(kg, wu), reps]
	return str(g.get("words", ""))


## A goal's numbers for a block: {"big", "small"}: "1×6" over "GOAL @ 52.5 kg" (one top set), "15 reps" over
## "GOAL · ONE SET", "35 s" over "GOAL · HOLD".
static func _goal_parts(g: Dictionary, wu: String) -> Dictionary:
	var reps = int(g.get("reps", 0))
	var band = str(g.get("band", ""))
	var kg = float(g.get("kg", 0.0))
	match str(g.get("type", "")):
		"set_reps":
			return {"big": "%d reps" % reps, "small": "GOAL · ONE SET"}
		"day_reps":
			return {"big": "%d reps" % reps, "small": "GOAL · IN A DAY"}
		"hold":
			return {"big": "%d s" % int(g.get("sec", 0)), "small": "GOAL · HOLD"}
	if band != "":
		return {"big": "1×%d" % reps, "small": "GOAL · " + Bands.words(band)}
	if kg > 0.0:
		return {"big": "1×%d" % reps, "small": "GOAL @ " + Fmt.fmt_weight(kg, wu)}
	return {"big": goal_words(g, wu), "small": "GOAL"}


## The GOLD block of a lift with a goal (2026-11-28): the goal's numbers in dark ink on gold, a star, a twinkle
## (gold is a goal or a reward). Metas as the aim block's: "done_tick" false, "today_aim" the goal's words; and
## "today_goal" = the goal's type (the one place on the row that says the goal: the mission strip under it lights
## the same record).
static func _goal_block(g: Dictionary, wu: String) -> Control:
	var gp = _goal_parts(g, wu)
	var b = _block("gold", str(gp.big), str(gp.small), "star")
	b.set_meta("done_tick", false)
	b.set_meta("today_aim", goal_words(g, wu))
	b.set_meta("today_goal", str(g.get("type", "")))
	b.tooltip_text = "Your goal today: %s, %s (set 1 of your prep)" % [str(g.get("title", "a record")).to_lower(), goal_words(g, wu)]
	Fx.twinkle(b, Pal.CREAM, 3)
	return b


## A small gold tag whose words end in "…" past `max_w` (so it never widens its row).
static func _gold_tag(text: String, px: int, max_w: float) -> PanelContainer:
	var p = PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_theme_stylebox_override("panel", Kit.tag_box(Pal.ACCENT))
	p.add_child(Kit.clip_fit(text, px, Kit.on_color(Pal.ACCENT), true, max_w))
	return p


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
