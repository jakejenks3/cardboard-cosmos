class_name TrainingReport
extends RefCounted
## How the training is going over weeks (2026-11-27, the user's "build all"). Pure, read from the log
## (tests/tracking_test.gd):
##   weekly_sets(...)   every muscle with a target: its sets in the 7 days ending each of the last N weeks,
##                      against the target's least and most (the Weekly sets sheet, Journey -> Stats)
##   streak(...)        Monday-weeks in a row where every muscle being built got its least, and badges
##   lift_report(...)   each lift's last 4 weeks against the 4 before: up, flat, down, stuck
##   body_trend(...)    bodyweight: a 7-day average, the change a week, and whether the main lifts hold

const WEEKS = 8
## Streak badges: weeks in a row on target.
const BADGES = [[3, "Bronze"], [6, "Silver"], [12, "Gold"], [26, "Platinum"]]
## How far back a streak is looked for.
const STREAK_LOOK = 52
## The lift report's window, and what counts as a change of the best estimated 1RM (or reps).
const REPORT_DAYS = 28
const REPORT_SLACK = 0.02
## The bodyweight trend's look back.
const BODY_DAYS = 28


## {"parts": [part ids with a target, the ones being built first], "weeks": [{"to", "parts": {part: sets}}]
## oldest first, "targets": {part: [least, most, mode]}}.
static func weekly_sets(sessions: Array, marks: Dictionary, settings: Dictionary, today: String, n: int = WEEKS) -> Dictionary:
	var plan = Dose.plan_of(settings)
	var targets = plan.targets if plan != null else {}
	var parts = []
	for mode in ["build", "keep"]:
		for p in Dose.PARTS:
			if targets.has(p) and str(targets[p][2]) == mode and float(targets[p][0]) > 0.0:
				parts.append(p)
	var weeks = []
	for k in range(n - 1, -1, -1):
		var end = Dates.add_days(today, -7 * k)
		var w = Dose.window(sessions, marks, settings, end)
		var got = {}
		for p in Dose.PARTS:
			got[p] = float(w.parts[p].total)
		weeks.append({"to": end, "parts": got})
	return {"parts": parts, "weeks": weeks, "targets": targets}


## The last week (Monday to Sunday) before `today`'s week, as its Sunday.
static func _last_sunday(today: String) -> String:
	return Dates.add_days(today, -(Dates.weekday_index(today) + 1))


## Was every muscle being built at its least in the Monday-week ending on `sunday`?
static func week_on_target(sessions: Array, marks: Dictionary, settings: Dictionary, sunday: String) -> bool:
	var build = Dose.build_parts(settings)
	if build.is_empty():
		return false
	var w = Dose.window(sessions, marks, settings, sunday)
	for p in build:
		if str(w.parts[p].state) == "short":
			return false
	return true


## {"now" (weeks in a row up to last week), "best", "badge" (the badge of `now`, "" under the first),
## "next" (weeks to the next badge, 0 past the last), "nextBadge", "thisWeek" (this week so far is on
## target)}. Weeks before the first lift session do not count.
static func streak(sessions: Array, marks: Dictionary, settings: Dictionary, today: String) -> Dictionary:
	var first = ""
	for s in sessions:
		if str(s.get("discipline", "")) == "lift" and (first == "" or str(s.date) < first):
			first = str(s.date)
	var out = {"now": 0, "best": 0, "badge": "", "next": int(BADGES[0][0]), "nextBadge": str(BADGES[0][1]), "thisWeek": false}
	if first == "" or Dose.build_parts(settings).is_empty():
		return out
	out.thisWeek = week_on_target(sessions, marks, settings, today)
	var run = 0
	var best = 0
	var counting_now = true
	var sunday = _last_sunday(today)
	for k in range(STREAK_LOOK):
		var sun = Dates.add_days(sunday, -7 * k)
		if sun < first:
			break
		if week_on_target(sessions, marks, settings, sun):
			run += 1
			best = maxi(best, run)
		else:
			if counting_now:
				out.now = run
				counting_now = false
			run = 0
	if counting_now:
		out.now = run
	out.best = maxi(best, int(out.now))
	for b in BADGES:
		if int(out.now) >= int(b[0]):
			out.badge = str(b[1])
	out.next = 0
	out.nextBadge = ""
	for b2 in BADGES:
		if int(out.now) < int(b2[0]):
			out.next = int(b2[0]) - int(out.now)
			out.nextBadge = str(b2[1])
			break
	return out


## A lift's best of a span: the best estimated 1RM, else the longest hold, else the most reps in a set
## (LiftTrend.ghost_score of each day), and how many days.
static func _best_in(hist: Array, from: String, to: String) -> Dictionary:
	var best = 0.0
	var n = 0
	for h in hist:
		if str(h.date) < from or str(h.date) > to:
			continue
		n += 1
		best = maxf(best, LiftTrend.ghost_score(LiftTrend.day(h.sets)))
	return {"best": best, "n": n}


## Every lift done in the last REPORT_DAYS and before them: {"up": [...], "flat": [...], "down": [...],
## "stuck": [...], "new": [...]}, each row {"name", "now", "before", "change" (a share), "days"}. A lift that
## went down is "down"; else one LiftTrend.plateau calls stuck is "stuck". Physical therapy and stretches are left out.
static func lift_report(sessions: Array, marks: Dictionary, today: String) -> Dictionary:
	var from = Dates.add_days(today, -(REPORT_DAYS - 1))
	var prev_from = Dates.add_days(from, -REPORT_DAYS)
	var prev_to = Dates.add_days(from, -1)
	var stats = LiftLibrary.stats(sessions)
	var out = {"up": [], "flat": [], "down": [], "stuck": [], "new": [], "from": from, "to": today}
	for k in stats:
		var st = stats[k]
		var nm = str(st.name)
		if Pt.is_pt(marks, nm) or Dosage.is_mobility({"name": nm, "sets": st.history[0].sets if not st.history.is_empty() else []}, marks):
			continue
		var now = _best_in(st.history, from, today)
		if int(now.n) == 0:
			continue
		var before = _best_in(st.history, prev_from, prev_to)
		var earlier = _best_in(st.history, "0000-00-00", prev_to)
		var row = {"name": nm, "now": float(now.best), "before": float(before.best), "change": 0.0, "days": int(now.n)}
		if int(earlier.n) == 0:
			out.new.append(row)
			continue
		var base = float(before.best) if int(before.n) > 0 else float(earlier.best)
		row.before = base
		row.change = (float(now.best) - base) / base if base > 0.0 else 0.0
		if float(row.change) < -REPORT_SLACK:
			out.down.append(row)
		elif LiftTrend.plateau(st.history) != null:
			out.stuck.append(row)
		elif float(row.change) > REPORT_SLACK:
			out.up.append(row)
		else:
			out.flat.append(row)
	for key in ["up", "flat", "down", "stuck", "new"]:
		out[key].sort_custom(func(a, b):
			if not is_equal_approx(float(a.change), float(b.change)):
				return float(a.change) > float(b.change)
			return int(a.days) > int(b.days))
	return out


## Bodyweight over the last BODY_DAYS: {"n" (check-ins with a weight), "avg" (the average of the last 7
## days of check-ins, kg), "avgDate", "weekly" (kg a week, from a straight line through the check-ins; 0
## with fewer than 2), "points" [{"date", "kg", "avg"}] oldest first, "first", "last", "lifts" (the
## lift report's main lifts: [{name, state}] for the lifts done most in the window)}.
static func body_trend(body: Array, sessions: Array, marks: Dictionary, today: String) -> Dictionary:
	var from = Dates.add_days(today, -(BODY_DAYS - 1))
	var pts = []
	for b in body:
		var d = str(b.get("date", ""))
		if d >= from and d <= today and float(b.get("weightKg", 0.0)) > 0.0:
			pts.append({"date": d, "kg": float(b.weightKg)})
	pts.sort_custom(func(a, b): return str(a.date) < str(b.date))
	# (one a day: the last of a day)
	var by_day = {}
	for p in pts:
		by_day[str(p.date)] = p
	pts = by_day.values()
	pts.sort_custom(func(a, b): return str(a.date) < str(b.date))
	for p in pts:
		var lo = Dates.add_days(str(p.date), -6)
		var sum = 0.0
		var n = 0
		for q in pts:
			if str(q.date) >= lo and str(q.date) <= str(p.date):
				sum += float(q.kg)
				n += 1
		p["avg"] = sum / float(maxi(1, n))
	var out = {"n": pts.size(), "avg": 0.0, "avgDate": "", "weekly": 0.0, "points": pts, "first": 0.0, "last": 0.0, "lifts": []}
	if pts.is_empty():
		return out
	out.avg = float(pts[pts.size() - 1].avg)
	out.avgDate = str(pts[pts.size() - 1].date)
	out.first = float(pts[0].kg)
	out.last = float(pts[pts.size() - 1].kg)
	if pts.size() >= 2:
		var xs = []
		var ys = []
		for p in pts:
			xs.append(float(Dates.days_between(from, str(p.date))))
			ys.append(float(p.kg))
		var mx = 0.0
		var my = 0.0
		for i in range(xs.size()):
			mx += xs[i] / float(xs.size())
			my += ys[i] / float(xs.size())
		var sxx = 0.0
		var sxy = 0.0
		for i in range(xs.size()):
			sxx += (xs[i] - mx) * (xs[i] - mx)
			sxy += (xs[i] - mx) * (ys[i] - my)
		if sxx > 0.0:
			out.weekly = sxy / sxx * 7.0
	# The lifts done most in the window, and how they went (lift_report).
	var rep = lift_report(sessions, marks, today)
	var rows = []
	for state in ["up", "flat", "down", "stuck"]:
		for r in rep[state]:
			rows.append({"name": str(r.name), "state": state, "days": int(r.days), "change": float(r.change)})
	rows.sort_custom(func(a, b): return int(a.days) > int(b.days))
	out.lifts = rows.slice(0, 4)
	return out
