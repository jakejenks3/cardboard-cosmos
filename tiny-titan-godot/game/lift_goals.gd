class_name LiftGoals
extends RefCounted
## A goal with a date for one lift (2026-11-27, the user's "build all"): "Bench 185 x 5 by Feb 1".
## STORED: `saved.goals` = [{id, lift, kg, reps, by, at (the day it was set), start (the lift's estimated
## one-rep max that day), done (the day it was reached, or "")}], kept by App.parse_saved and merged record by
## record (SaveMerge.RECORD_LISTS). Reaching it is read from the log: a set of the lift with at least that
## weight for at least those reps, on or after the day it was set. Nothing in the rules reads it.
## The forecast is an ESTIMATE and says so: the trend of the lift's estimated one-rep max (the best set of
## each day, the last TREND_DAYS) carried forward to the goal's. Pure (tests/tracking_test.gd).

const TREND_DAYS = 56
## At least this many days of the lift in TREND_DAYS for a forecast.
const TREND_MIN = 3
## Goals open at once.
const MAX_OPEN = 8


static func parse(v) -> Array:
	var out = []
	if not (v is Array):
		return out
	for g in v:
		if g is Dictionary and str(g.get("id", "")) != "" and str(g.get("lift", "")) != "" and float(g.get("kg", 0)) > 0.0:
			out.append({"id": str(g.id), "lift": str(g.lift), "kg": float(g.kg), "reps": maxi(1, int(g.get("reps", 1))),
				"by": str(g.get("by", "")), "at": str(g.get("at", "")), "start": float(g.get("start", 0.0)), "done": str(g.get("done", ""))})
	return out


static func target_e1rm(g: Dictionary) -> float:
	return Xp.e1rm(float(g.kg), int(g.reps))


## The lift's sessions, newest first: [{date, sets}] (exact name).
static func history_of(sessions: Array, lift_name: String) -> Array:
	var k = Xp.normalize_exercise(lift_name)
	var out = []
	for s in sessions:
		if str(s.get("discipline", "")) != "lift":
			continue
		for ex in s.get("exercises", []):
			if Xp.normalize_exercise(str(ex.get("name", ""))) == k:
				out.append({"date": str(s.date), "sets": ex.get("sets", [])})
	out.sort_custom(func(a, b): return str(a.date) > str(b.date))
	return out


## The best estimated one-rep max of a day's sets (one side for both sides added up is not known here:
## the reps as logged).
static func day_e1rm(sets: Array) -> float:
	var best = 0.0
	for one in sets:
		if int(one.get("reps", 0)) > 0 and float(one.get("weightKg", 0)) > 0.0:
			best = maxf(best, Xp.e1rm(float(one.weightKg), int(one.reps)))
	return best


## The first day on or after the goal was set with a set of at least its weight for at least its reps; "".
static func reached_on(g: Dictionary, sessions: Array) -> String:
	var first = ""
	for h in history_of(sessions, str(g.lift)):
		if str(h.date) < str(g.at):
			continue
		for one in h.sets:
			if float(one.get("weightKg", 0)) >= float(g.kg) - 0.01 and int(one.get("reps", 0)) >= int(g.reps):
				if first == "" or str(h.date) < first:
					first = str(h.date)
	return first


## A straight line through (day number, estimated 1RM) of the last TREND_DAYS: {"slope" a day, "now" (the
## line's value today), "n"}, or null with too few days.
static func trend(sessions: Array, lift_name: String, today: String) -> Variant:
	var from = Dates.add_days(today, -TREND_DAYS)
	var xs = []
	var ys = []
	for h in history_of(sessions, lift_name):
		if str(h.date) < from or str(h.date) > today:
			continue
		var e = day_e1rm(h.sets)
		if e > 0.0:
			xs.append(float(Dates.days_between(from, str(h.date))))
			ys.append(e)
	if xs.size() < TREND_MIN:
		return null
	var n = float(xs.size())
	var mx = 0.0
	var my = 0.0
	for i in range(xs.size()):
		mx += xs[i] / n
		my += ys[i] / n
	var sxx = 0.0
	var sxy = 0.0
	for i in range(xs.size()):
		sxx += (xs[i] - mx) * (xs[i] - mx)
		sxy += (xs[i] - mx) * (ys[i] - my)
	if sxx <= 0.0:
		return null
	var slope = sxy / sxx
	var now = my + slope * (float(Dates.days_between(from, today)) - mx)
	return {"slope": slope, "now": now, "n": xs.size()}


## Where a goal stands: {"state" ("done" | "on" | "behind" | "slow" | "unknown"), "pct" (0..1, from the
## start to the goal's estimated one-rep max), "best" (the best estimated 1RM since it was set), "eta" (the
## day the trend gets there, "" when it does not go up), "daysLeft", "done"}.
static func status(g: Dictionary, sessions: Array, today: String) -> Dictionary:
	var target = target_e1rm(g)
	var done = str(g.get("done", ""))
	if done == "":
		done = reached_on(g, sessions)
	var best = 0.0
	for h in history_of(sessions, str(g.lift)):
		if str(h.date) >= str(g.at):
			best = maxf(best, day_e1rm(h.sets))
	var start = float(g.get("start", 0.0))
	var pct = 1.0 if done != "" else (clampf((best - start) / (target - start), 0.0, 1.0) if target > start + 0.01 else (1.0 if best >= target else 0.0))
	var out = {"state": "unknown", "pct": pct, "best": best, "eta": "", "daysLeft": Dates.days_between(today, str(g.by)) if str(g.by) != "" else 0, "done": done, "target": target}
	if done != "":
		out.state = "done"
		return out
	var t = trend(sessions, str(g.lift), today)
	if t == null:
		return out
	if float(t.now) >= target:
		out.eta = today
	elif float(t.slope) > 0.0001:
		out.eta = Dates.add_days(today, int(ceil((target - float(t.now)) / float(t.slope))))
	if str(out.eta) == "":
		out.state = "slow"
	elif str(g.by) == "" or str(out.eta) <= str(g.by):
		out.state = "on"
	else:
		out.state = "behind"
	return out


## A new goal (not stored here): set today, with the lift's best estimated 1RM of the last TREND_DAYS as its start.
static func make(lift_name: String, kg: float, reps: int, by: String, sessions: Array, today: String, id: String) -> Dictionary:
	var start = 0.0
	var from = Dates.add_days(today, -TREND_DAYS)
	for h in history_of(sessions, lift_name):
		if str(h.date) >= from:
			start = maxf(start, day_e1rm(h.sets))
	return {"id": id, "lift": lift_name.strip_edges(), "kg": kg, "reps": maxi(1, reps), "by": by, "at": today, "start": start, "done": ""}


## The goals of a lift that are still open.
static func open_of(goals: Array, lift_name: String) -> Array:
	var k = Xp.normalize_exercise(lift_name)
	return goals.filter(func(g): return Xp.normalize_exercise(str(g.lift)) == k and str(g.get("done", "")) == "")


## Goals reached in the log but not marked yet: [[index, day]].
static func newly_done(goals: Array, sessions: Array) -> Array:
	var out = []
	for i in range(goals.size()):
		if str(goals[i].get("done", "")) == "":
			var d = reached_on(goals[i], sessions)
			if d != "":
				out.append([i, d])
	return out
