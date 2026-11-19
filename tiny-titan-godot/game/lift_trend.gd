class_name LiftTrend
extends RefCounted
## One lift over time, from its history (LiftLibrary.stats(...)[key].history:
## a {date, id, sets: [{reps, weightKg}]} per session, newest first).
##
##   day(sets)                     one session in numbers
##   by_day(history)               one row per day, oldest first
##   series(history, metric)       points for a chart, oldest first
##   per_week(history, today, n)   days it was done in each of the last n weeks
##   compare(sets, before)         this session against the one before it
##   change(points)                first against last of a series
##
## The lift's page (JourneyLifts.open_detail) draws these, and every list of
## exercises (SessionView) shows `compare` beside each one.
## Pure logic, no scene and no autoload: tests/lift_trend_test.gd.

## What can be charted. "often" is per_week, the rest are `series`.
const METRICS = ["weight", "reps", "volume", "often"]


## One session of a lift in numbers:
## {sets, reps (all of them), topKg (the heaviest set), topReps (its reps),
##  bestReps (most reps in one set), volumeKg, e1rm}.
## A set without reps does not count. With no weight anywhere topKg is 0 and
## topReps is the most reps in a set.
static func day(sets: Array) -> Dictionary:
	var out = {"sets": 0, "reps": 0, "topKg": 0.0, "topReps": 0, "bestReps": 0, "volumeKg": 0.0, "e1rm": 0.0}
	for one in sets:
		var r = int(one.get("reps", 0))
		var w = maxf(0.0, float(one.get("weightKg", 0)))
		if r <= 0:
			continue
		out.sets += 1
		out.reps += r
		out.bestReps = maxi(int(out.bestReps), r)
		out.volumeKg += r * w
		if w > float(out.topKg) + 1e-9 or (absf(w - float(out.topKg)) <= 1e-9 and r > int(out.topReps)):
			out.topKg = w
			out.topReps = r
		if w > 0.0:
			out.e1rm = maxf(float(out.e1rm), Xp.e1rm(w, r))
	return out


## The history as one row per DAY, oldest first: `day` of all that day's sets,
## plus "date". Two sessions on a day are one day of that lift.
static func by_day(history: Array) -> Array:
	var sets_of = {}
	var order = []
	for h in history:
		var d = str(h.get("date", ""))
		if not sets_of.has(d):
			sets_of[d] = []
			order.append(d)
		sets_of[d].append_array(h.get("sets", []))
	order.sort()
	var out = []
	for d in order:
		var row = day(sets_of[d])
		if int(row.sets) == 0:
			continue
		row["date"] = d
		out.append(row)
	return out


## Does this lift carry weight at all (false: bodyweight only, so "weight" and
## "volume" have nothing to show)?
static func weighted(history: Array) -> bool:
	for h in history:
		for one in h.get("sets", []):
			if float(one.get("weightKg", 0)) > 0.0 and int(one.get("reps", 0)) > 0:
				return true
	return false


## Points for a chart, oldest first: [{"x": date, "y": number}].
##   "weight": the heaviest set of the day, in kg (days without weight are left out)
##   "reps":   every rep of the day
##   "volume": weight x reps of the day, in kg
##   "e1rm":   the best estimated one-rep max of the day, in kg
static func series(history: Array, metric: String) -> Array:
	var out = []
	for row in by_day(history):
		var y = 0.0
		match metric:
			"weight":
				y = float(row.topKg)
			"volume":
				y = float(row.volumeKg)
			"e1rm":
				y = float(row.e1rm)
			_:
				y = float(row.reps)
		if y <= 0.0 and metric != "reps":
			continue
		out.append({"x": row.date, "y": y})
	return out


## The days it was done: {date: true}.
static func days_done(history: Array) -> Dictionary:
	var out = {}
	for row in by_day(history):
		out[row.date] = true
	return out


## How many days it was done in each of the last `weeks` Monday-weeks, the
## week of `today` last: [{"week": monday, "n": days}].
static func per_week(history: Array, today: String, weeks: int = 8) -> Array:
	var done = days_done(history)
	var this_week = Dates.week_key(today)
	var out = []
	for i in range(weeks - 1, -1, -1):
		var wk = Dates.add_weeks(this_week, -i)
		var n = 0
		for d in range(7):
			if done.has(Dates.add_days(wk, d)):
				n += 1
		out.append({"week": wk, "n": n})
	return out


## Days a week on average over those weeks, counting from the first week it
## was done in (a lift started three weeks ago is not averaged over eight).
static func weekly_rate(weeks: Array) -> float:
	var first = -1
	var total = 0
	for i in range(weeks.size()):
		if int(weeks[i].n) > 0 and first < 0:
			first = i
		total += int(weeks[i].n)
	if first < 0:
		return 0.0
	return total / float(weeks.size() - first)


## This session against the one before it.
## `sets`: the session's sets; `before`: the lift's history before it, newest first.
## {"kind": "none" (no real set) | "first" | "up" | "down" | "same",
##  "kg": change of the heaviest set, "reps": change of all reps when the
##  weight is the same, "pr": heavier than ever before (or, without weight,
##  more reps in a set than ever), "last": date of the session before}
static func compare(sets: Array, before: Array) -> Dictionary:
	var cur = day(sets)
	if int(cur.sets) == 0:
		return {"kind": "none", "kg": 0.0, "reps": 0, "pr": false, "last": ""}
	if before.is_empty():
		return {"kind": "first", "kg": 0.0, "reps": 0, "pr": false, "last": ""}
	var prev = day(before[0].get("sets", []))
	var best_kg = 0.0
	var best_reps = 0
	for h in before:
		var d = day(h.get("sets", []))
		best_kg = maxf(best_kg, float(d.topKg))
		best_reps = maxi(best_reps, int(d.bestReps))
	var pr = float(cur.topKg) > best_kg + 1e-6
	if float(cur.topKg) <= 0.0 and best_kg <= 0.0:
		pr = int(cur.bestReps) > best_reps
	var dkg = float(cur.topKg) - float(prev.topKg)
	var dreps = int(cur.reps) - int(prev.reps)
	var kind = "same"
	if absf(dkg) > 1e-6:
		kind = "up" if dkg > 0.0 else "down"
		dreps = 0
	elif dreps != 0:
		kind = "up" if dreps > 0 else "down"
	return {"kind": kind, "kg": dkg if absf(dkg) > 1e-6 else 0.0, "reps": dreps, "pr": pr, "last": str(before[0].get("date", ""))}


## First against last of a series: {"from", "to", "delta", "days", "n"}, or {}
## with fewer than two points.
static func change(points: Array) -> Dictionary:
	if points.size() < 2:
		return {}
	var a = points[0]
	var b = points[points.size() - 1]
	return {"from": float(a.y), "to": float(b.y), "delta": float(b.y) - float(a.y), "days": Dates.days_between(str(a.x), str(b.x)), "n": points.size()}
