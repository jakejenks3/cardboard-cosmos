class_name TrackingViews
extends RefCounted
## Screens for tracking over weeks (2026-11-27, the user's "build all"): goals with a date (LiftGoals) on the
## Hero tab and a lift's page, the weekly sets of the last 8 weeks and the on-target streak
## (TrainingReport.weekly_sets / streak) in the Weekly sets sheet and Journey -> Stats, the lift report
## (TrainingReport.lift_report) in Journey -> Stats, and the bodyweight trend (TrainingReport.body_trend) in
## Journey -> Body. Every forecast is an estimate and says so on screen.

const GOAL_WEEKS = [4, 8, 12, 16]


static func _wu() -> String:
	return App.weight_unit()


static func _w(kg: float) -> String:
	return Fmt.fmt_weight(kg, _wu())


# ---------------------------------------------------------------------------
# Goals with a date
# ---------------------------------------------------------------------------

## "On track: about Jan 20 (estimate)" and its colour, for a goal's status.
static func goal_words(st: Dictionary) -> Array:
	match str(st.state):
		"done":
			return ["Reached %s" % Dates.format_date(str(st.done)), Pal.GOOD]
		"on":
			if str(st.eta) <= App.today:
				return ["Within reach now: your estimated max is there", Pal.GOOD]
			return ["On track: about %s at your pace (estimate)" % Dates.format_date(str(st.eta)), Pal.GOOD]
		"behind":
			return ["Behind: about %s at your pace (estimate)" % Dates.format_date(str(st.eta)), Pal.ACCENT2]
		"slow":
			return ["Not going up lately: no date at this pace", Pal.ACCENT2]
	return ["Log it a few more times for a forecast", Pal.MUTED]


static func goal_row(g: Dictionary) -> Card:
	var st = LiftGoals.status(g, App.sessions(), App.today)
	var words = goal_words(st)
	var col = words[1]
	var c = Kit.row(JourneyLifts.open_named.bind(str(g.lift), {"view": "progress"}), col, Pal.GOOD if str(st.state) == "done" else null, 8, 3)
	c.set_meta("goal_row", str(g.id))
	c.set_meta("goal_state", str(st.state))
	var top = Kit.hbox(6)
	var nm = Kit.squeeze(6)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp = LiftNames.split(str(g.lift))
	nm.add_child(Kit.soft_name(str(sp.move), 14, null, true, 200.0))
	if str(sp.variation) != "":
		nm.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	top.add_child(nm)
	top.add_child(Kit.vcenter(Kit.label("%s × %d" % [_w(float(g.kg)), int(g.reps)], 13, Pal.ACCENT, true)))
	c.add(top)
	c.add(Kit.bar(float(st.pct), col, 8))
	var line = Kit.hbox(6)
	var wl = Kit.clip(str(words[0]), 11, col, true)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(wl)
	if str(g.by) != "" and str(st.state) != "done":
		var left = int(st.daysLeft)
		line.add_child(Kit.label(("by %s" % Dates.format_date(str(g.by))) + (" · %d days" % left if left >= 0 else " · past"), 11, Pal.MUTED, true))
	c.add(line)
	return c


## GOALS on the Hero tab: the open ones and the ones reached in the last two weeks; null with none.
static func goals_section() -> Control:
	var shown = App.goals().filter(func(g): return str(g.get("done", "")) == "" or Dates.days_between(str(g.done), App.today) <= 14)
	if shown.is_empty():
		return null
	var open_n = shown.filter(func(g): return str(g.get("done", "")) == "").size()
	var sec = Kit.section("lift_goals", "GOALS", "target", Pal.LIFT, Kit.label("%d open" % open_n, 12, Pal.TEXT, true), Callable(), 6, 10)
	for g in shown:
		sec.add(goal_row(g))
	return sec


## A lift's goals on its page, with "Set a goal".
static func goal_block(lift: String, rebuild: Callable) -> Control:
	var v = Kit.vbox(6)
	v.set_meta("goal_block", lift)
	var head = Kit.hbox(6)
	var t = Kit.section_title("Goal")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var add = Kit.button("Set a goal", "secondary", open_goal_sheet.bind(lift, rebuild), "sm", "target")
	add.set_meta("goal_add", lift)
	head.add_child(add)
	v.add_child(head)
	var mine = App.goals().filter(func(g): return Xp.normalize_exercise(str(g.lift)) == Xp.normalize_exercise(lift))
	if mine.is_empty():
		v.add_child(Kit.para("A weight for some reps by a day: the page says whether your pace gets you there.", 12, Pal.MUTED))
	for g in mine:
		var r = Kit.hbox(6)
		var row = goal_row(g)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(row)
		var x = LogWidgets.quiet_icon("close", func():
			App.remove_goal(str(g.id))
			rebuild.call(), "Take this goal off", 28)
		x.set_meta("goal_remove", str(g.id))
		r.add_child(x)
		v.add_child(r)
	return v


## The sheet that sets a goal: the weight (a step past the best set of the last weeks), the reps, and when.
static func open_goal_sheet(lift: String, rebuild: Callable = Callable()) -> void:
	Sfx.tap()
	var wu = _wu()
	var step = TT.weight_step_of(App.settings())
	var best_kg = 0.0
	var best_reps = 5
	for h in LiftGoals.history_of(App.sessions(), lift).slice(0, 8):
		for one in h.sets:
			if float(one.get("weightKg", 0)) > best_kg:
				best_kg = float(one.weightKg)
				best_reps = int(one.reps)
	var start_w = Fmt.kg_to_unit(best_kg, wu) + step * 2.0 if best_kg > 0.0 else step * 4.0
	start_w = snappedf(start_w, step)
	var s = Kit.sheet("Set a goal")
	s.set_meta("goal_sheet", lift)
	s.box.add_child(Kit.label(Missions.short_name(lift), 16, Pal.LIFT, true))
	if best_kg > 0.0:
		s.box.add_child(Kit.para("Your heaviest set lately: %s × %d." % [_w(best_kg), best_reps], 12, Pal.MUTED))
	var st = {"w": LogWidgets.trim_num(start_w), "r": str(maxi(1, best_reps)), "weeks": 8}
	var row = Kit.hbox(10)
	var wv = Kit.vbox(2)
	wv.add_child(Kit.label("WEIGHT (%s)" % wu.to_upper(), 10, Pal.MUTED, true))
	var ws = Kit.stepper(st.w, step, func(t): st.w = t, {"width": 60, "min": 0, "snap": true})
	ws.set_meta("goal_weight", true)
	wv.add_child(ws)
	row.add_child(wv)
	var rv = Kit.vbox(2)
	rv.add_child(Kit.label("REPS", 10, Pal.MUTED, true))
	var rs = Kit.stepper(st.r, 1.0, func(t): st.r = t, {"width": 36, "min": 1})
	rs.set_meta("goal_reps", true)
	rv.add_child(rs)
	row.add_child(rv)
	s.box.add_child(row)
	s.box.add_child(Kit.label("BY", 10, Pal.MUTED, true))
	var when = Kit.hbox(0)
	s.box.add_child(when)
	var fill_when = func(self_ref):
		Kit.clear(when)
		var keys = []
		for wk in GOAL_WEEKS:
			var k = Kit.choice("%d wk" % wk, int(st.weeks) == wk, func():
				st.weeks = wk
				self_ref.call(self_ref), Pal.LIFT, 12)
			k.set_meta("goal_weeks", wk)
			keys.append(k)
		var tr = Kit.choice_track(keys)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		when.add_child(tr)
	fill_when.call(fill_when)
	var date_l = Kit.label("", 12, Pal.TEXT, true)
	s.box.add_child(date_l)
	var upd = func(): date_l.text = Dates.format_date(Dates.add_days(App.today, 7 * int(st.weeks)), {"weekday": "short", "month": "short", "day": "numeric", "year": "numeric"})
	upd.call()
	when.child_entered_tree.connect(func(_n): upd.call())
	s.box.add_child(Kit.para("Reached when a set of this lift has at least that weight for at least those reps. The forecast follows your estimated one-rep max: it is an estimate.", 11, Pal.MUTED))
	var save = Kit.button("Set the goal", "primary", func():
		var kg = Fmt.unit_to_kg(LogWidgets.num(st.w), wu)
		var reps = maxi(1, int(LogWidgets.num(st.r)))
		if kg <= 0.0:
			Sfx.error()
			return
		if not App.add_goal(lift, kg, reps, Dates.add_days(App.today, 7 * int(st.weeks))):
			App.toast("%d goals are open: reach or take one off first" % LiftGoals.MAX_OPEN, "bad", "warning")
			return
		Sfx.pop()
		App.toast("Goal set: %s × %d" % [Fmt.fmt_weight(kg, wu), reps], "good", "target")
		s.close()
		if rebuild.is_valid():
			rebuild.call())
	save.set_meta("goal_save", true)
	s.box.add_child(save)
	s.open()


# ---------------------------------------------------------------------------
# Weekly sets over weeks, and the streak
# ---------------------------------------------------------------------------

## Every muscle with a target: its name, this week's sets against the range, and 8 weeks of bars.
static func weekly_block(n: int = TrainingReport.WEEKS) -> Control:
	var data = TrainingReport.weekly_sets(App.sessions(), App.pt(), App.settings(), App.today, n)
	var v = Kit.vbox(6)
	v.set_meta("weekly_block", data.parts.size())
	if data.parts.is_empty():
		v.add_child(Kit.para("Pick a training focus in Settings to see your weekly sets against targets.", 12, Pal.MUTED))
		return v
	for p in data.parts:
		var t = data.targets[p]
		var vals = data.weeks.map(func(w): return float(w.parts[p]))
		var r = Kit.hbox(8)
		r.set_meta("weekly_part", p)
		var lv = Kit.vbox(0)
		lv.custom_minimum_size.x = 108
		lv.add_child(Kit.clip(Dose.part_name(p), 13, JourneyLifts.part_color(p), true))
		var now = float(vals[vals.size() - 1])
		lv.add_child(Kit.clip("%s / %s-%s" % [TTUtil.num_str(snappedf(now, 0.5)), TTUtil.num_str(float(t[0])), TTUtil.num_str(float(t[1]))], 11, Pal.MUTED, true))
		r.add_child(lv)
		var ch = DoseWeeks.new()
		ch.setup(vals, float(t[0]), float(t[1]), JourneyLifts.part_color(p))
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(ch)
		v.add_child(r)
	v.add_child(Kit.para("Sets in the 7 days ending each week, newest on the right. The shaded band is the target.", 11, Pal.MUTED))
	return v


## The on-target streak and its badge: {row}. null without a focus.
static func streak_row() -> Control:
	if Dose.build_parts(App.settings()).is_empty():
		return null
	var st = TrainingReport.streak(App.sessions(), App.pt(), App.settings(), App.today)
	var on = int(st.now) > 0
	var col = Pal.ACCENT if str(st.badge) != "" else (Pal.GOOD if on else Pal.LINE)
	var c = Kit.row(Callable(), col, null, 8, 2)
	c.set_meta("target_streak", int(st.now))
	var h = Kit.hbox(8)
	h.add_child(Kit.vcenter(Icons.rect("medal" if str(st.badge) != "" else "muscle", 26)))
	var v = Kit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = "%d week%s in a row on target" % [int(st.now), "" if int(st.now) == 1 else "s"] if on else "No week on target yet in a row"
	if str(st.badge) != "":
		title += " · %s" % str(st.badge)
	v.add_child(Kit.clip(title, 14, null, true))
	var sub = ""
	if int(st.next) > 0:
		sub = "%d more for %s" % [int(st.next), str(st.nextBadge)]
	if bool(st.thisWeek):
		sub += ("  ·  " if sub != "" else "") + "this week: on target so far"
	if int(st.best) > int(st.now):
		sub += ("  ·  " if sub != "" else "") + "best %d" % int(st.best)
	if sub != "":
		v.add_child(Kit.clip(sub, 11, Pal.MUTED))
	h.add_child(v)
	c.add(h)
	c.tooltip_text = "A week (Monday to Sunday) is on target when every muscle you are building got its weekly sets."
	return c


## Journey -> Stats: weekly sets over 8 weeks with the streak. null without a focus.
static func weekly_card() -> Control:
	if Dose.plan_of(App.settings()) == null:
		return null
	var sec = Kit.section("weekly_sets", "SETS A WEEK · 8 WEEKS", "muscle", Pal.LIFT, Kit.link("Details →", DoseView.open, 13, Pal.LIFT.lightened(0.45)), Callable(), 8, 10)
	var sr = streak_row()
	if sr != null:
		sec.add(sr)
	sec.add(weekly_block())
	return sec


# ---------------------------------------------------------------------------
# The lift report
# ---------------------------------------------------------------------------

const REPORT_GROUPS = [["up", "GOING UP", "GOOD"], ["stuck", "STUCK", "DANGER"], ["down", "DOWN", "ACCENT2"], ["flat", "HOLDING", "MUTED"], ["new", "NEW THIS MONTH", "SECOND"]]
const REPORT_ROWS = 5


static func _group_color(state: String) -> Color:
	match state:
		"up":
			return Pal.GOOD
		"stuck":
			return Pal.DANGER
		"down":
			return Pal.ACCENT2
		"new":
			return Pal.SECOND
	return Pal.MUTED


static func report_card() -> Control:
	var rep = TrainingReport.lift_report(App.sessions(), App.pt(), App.today)
	var total = 0
	for g in REPORT_GROUPS:
		total += rep[g[0]].size()
	if total == 0:
		return null
	var sec = Kit.section("lift_report", "LIFT REPORT · 4 WEEKS", "trophy", Pal.tab("journey"), null, Callable(), 6, 10)
	sec.add(Kit.para("Each lift's best of the last 4 weeks against the 4 before (estimated one-rep max, or reps, or the hold).", 11, Pal.MUTED))
	for g in REPORT_GROUPS:
		var rows = rep[g[0]]
		if rows.is_empty():
			continue
		var col = _group_color(str(g[0]))
		sec.add(Kit.sub_head("%s · %d" % [str(g[1]), rows.size()], col))
		for r in rows.slice(0, REPORT_ROWS):
			sec.add(_report_row(r, str(g[0]), col))
		if rows.size() > REPORT_ROWS:
			sec.add(Kit.clip("+%d more" % (rows.size() - REPORT_ROWS), 11, Pal.MUTED))
	return sec


static func _report_row(r: Dictionary, state: String, col: Color) -> Card:
	var c = Kit.row(JourneyLifts.open_named.bind(str(r.name), {"view": "progress"}), col, null, 6, 0)
	c.set_meta("report_row", str(r.name))
	c.set_meta("report_state", state)
	var h = Kit.squeeze(6)
	var sp = LiftNames.split(str(r.name))
	h.add_child(Kit.soft_name(str(sp.move), 13, null, true, 180.0))
	if str(sp.variation) != "":
		h.add_child(SessionView.variation_tag(str(sp.variation), 10, true))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	var said = "%d day%s" % [int(r.days), "" if int(r.days) == 1 else "s"]
	if state != "new":
		said = "%s%d%% · %s" % ["+" if float(r.change) >= 0.0 else "", int(round(float(r.change) * 100.0)), said]
	h.add_child(Kit.vcenter(Kit.label(said, 12, col if state != "flat" else Pal.MUTED, true)))
	c.add(h)
	return c


# ---------------------------------------------------------------------------
# The bodyweight trend
# ---------------------------------------------------------------------------

static func body_card() -> Control:
	var bt = TrainingReport.body_trend(App.body(), App.sessions(), App.pt(), App.today)
	if int(bt.n) < 2:
		return null
	var wu = _wu()
	var sec = Kit.section("body_trend", "TREND · 4 WEEKS", "scale", Pal.ACCENT2, null, Callable(), 8, 10)
	var tiles = Kit.grid(2, 8)
	var avg = JourneyScreen.well_tile(Fmt.fmt_weight(float(bt.avg), wu), "7-DAY AVERAGE", Pal.TEXT, 3, "The average of your weigh-ins of the last 7 days")
	avg.set_meta("body_avg", float(bt.avg))
	tiles.add_child(avg)
	var wk = float(bt.weekly)
	var sign = "+" if wk > 0.0 else ("-" if wk < 0.0 else "")
	var rate = JourneyScreen.well_tile("%s%s" % [sign, Fmt.fmt_weight(absf(wk), wu)], "A WEEK", Pal.GOOD if wk < 0.0 else (Pal.ACCENT2 if wk > 0.0 else Pal.MUTED), 3, "The change a week, from a straight line through your weigh-ins of the last 4 weeks")
	rate.set_meta("body_rate", wk)
	tiles.add_child(rate)
	sec.add(tiles)
	var pct = absf(wk) / maxf(1.0, float(bt.avg)) * 100.0
	var words = "Steady."
	if wk < -0.01:
		words = "Losing %s%% of your weight a week." % TTUtil.num_str(snappedf(pct, 0.1))
		if pct > 1.0:
			words += " That is fast: more than 1%% a week can cost muscle."
	elif wk > 0.01:
		words = "Gaining %s%% a week." % TTUtil.num_str(snappedf(pct, 0.1))
	sec.add(Kit.para(words, 12, Pal.MUTED))
	if not (bt.lifts as Array).is_empty():
		sec.add(Kit.sub_head("YOUR MAIN LIFTS MEANWHILE", Pal.LIFT))
		for l in bt.lifts:
			var col = {"up": Pal.GOOD, "flat": Pal.MUTED, "down": Pal.ACCENT2, "stuck": Pal.DANGER}.get(str(l.state), Pal.MUTED)
			sec.add(_report_row({"name": l.name, "days": l.days, "change": l.change}, str(l.state), col))
		var held = bt.lifts.filter(func(l): return str(l.state) == "up" or str(l.state) == "flat").size()
		sec.add(Kit.para("%d of %d holding or going up." % [held, bt.lifts.size()], 12, Pal.GOOD if held == bt.lifts.size() else Pal.TEXT, true))
	return sec
