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
##   pairs(sets, prev_sets)        set by set against another session
##   records(sets, before)         the records a session sets
##   next_target(sets, step_kg)    something to aim for next time
##   best_row(history)             the best day
##   record_points(points)         the points of a chart that set a new best
##   since(points, today, days)    a chart's last days
##   calendar(history, today, n)   the days it was done, week by week
##   rep_ladder(history)           the heaviest weight for each number of reps
##
## The lift's page (JourneyLifts.open_detail, LiftViews) draws these, and every
## list of exercises (SessionView) shows `compare` beside each one.
## Pure logic, no scene and no autoload: tests/lift_trend_test.gd.

## What can be charted. "often" is per_week, the rest are `series`.
const METRICS = ["weight", "hold", "reps", "volume", "often"]


## A stretch or any other hold: a set with "holdSec" (seconds each rep is held)
## instead of a weight. `30"` in the phone note.
static func is_hold(one: Dictionary) -> bool:
	return int(one.get("holdSec", 0)) > 0


## Sets that are holds, in words: "3 x 30 s hold", "30 s, 45 s hold". "" when
## no set is a hold (then LiftHistory.describe_sets says it the usual way).
static func hold_text(sets: Array) -> String:
	var secs = []
	for one in sets:
		if is_hold(one) and int(one.get("reps", 0)) > 0:
			for k in range(int(one.reps)):
				secs.append(int(one.holdSec))
	if secs.is_empty():
		return ""
	var same = true
	for v in secs:
		if v != secs[0]:
			same = false
	if same:
		return "%d s hold" % secs[0] if secs.size() == 1 else "%d × %d s hold" % [secs.size(), secs[0]]
	if secs.size() > 6:
		return "%d holds, longest %d s" % [secs.size(), secs.max()]
	var words = []
	for v in secs:
		words.append("%d s" % v)
	return ", ".join(PackedStringArray(words)) + " hold"


## Is any of it a hold?
static func held(history: Array) -> bool:
	for h in history:
		for one in h.get("sets", []):
			if is_hold(one) and int(one.get("reps", 0)) > 0:
				return true
	return false


## One session of a lift in numbers:
## {sets, reps (all of them), topKg (the heaviest set), topReps (its reps),
##  bestReps (most reps in one set), volumeKg, e1rm, holdSec (the longest hold),
##  holdTotal (seconds held in all)}.
## A set without reps does not count. With no weight anywhere topKg is 0 and
## topReps is the most reps in a set. Reps are as they were logged; only the
## estimate (e1rm) goes by one side for a lift logged as both sides added up
## (sets tagged by Sides.tag_sets).
static func day(sets: Array) -> Dictionary:
	var out = {"sets": 0, "reps": 0, "topKg": 0.0, "topReps": 0, "bestReps": 0, "volumeKg": 0.0, "e1rm": 0.0, "holdSec": 0, "holdTotal": 0}
	for one in sets:
		var r = int(one.get("reps", 0))
		var w = maxf(0.0, float(one.get("weightKg", 0)))
		if r <= 0:
			continue
		out.sets += 1
		out.reps += r
		if is_hold(one):
			out.holdSec = maxi(int(out.holdSec), int(one.holdSec))
			out.holdTotal += r * int(one.holdSec)
		out.bestReps = maxi(int(out.bestReps), r)
		out.volumeKg += r * w
		if w > float(out.topKg) + 1e-9 or (absf(w - float(out.topKg)) <= 1e-9 and r > int(out.topReps)):
			out.topKg = w
			out.topReps = r
		if w > 0.0:
			var sides = maxi(1, int(one.get("sides", 1)))
			out.e1rm = maxf(float(out.e1rm), Xp.e1rm(w, r) if sides == 1 else Xp.e1rm(w, r / float(sides)))
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
##   "best":   the most reps in one set of the day
##   "hold":   the longest hold of the day, in seconds
static func series(history: Array, metric: String) -> Array:
	var out = []
	for row in by_day(history):
		var y = 0.0
		match metric:
			"weight":
				y = float(row.topKg)
			"hold":
				y = float(row.holdSec)
			"volume":
				y = float(row.volumeKg)
			"e1rm":
				y = float(row.e1rm)
			"best":
				y = float(row.bestReps)
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
##  weight is the same, "sec": change of the longest hold (holds are compared
##  by that), "pr": heavier than ever before (without weight: more reps in a
##  set than ever; a hold: longer than ever), "last": date of the session before}
static func compare(sets: Array, before: Array) -> Dictionary:
	var cur = day(sets)
	if int(cur.sets) == 0:
		return {"kind": "none", "kg": 0.0, "reps": 0, "sec": 0, "pr": false, "last": ""}
	if before.is_empty():
		return {"kind": "first", "kg": 0.0, "reps": 0, "sec": 0, "pr": false, "last": ""}
	var prev = day(before[0].get("sets", []))
	if int(cur.holdSec) > 0 or int(prev.holdSec) > 0:
		var longest = 0
		for h in before:
			longest = maxi(longest, int(day(h.get("sets", [])).holdSec))
		var dsec = int(cur.holdSec) - int(prev.holdSec)
		var more = int(cur.reps) - int(prev.reps)
		var how = "same"
		if dsec != 0:
			how = "up" if dsec > 0 else "down"
			more = 0
		elif more != 0:
			how = "up" if more > 0 else "down"
		return {"kind": how, "kg": 0.0, "reps": more, "sec": dsec, "pr": int(cur.holdSec) > longest, "last": str(before[0].get("date", ""))}
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
	return {"kind": kind, "kg": dkg if absf(dkg) > 1e-6 else 0.0, "reps": dreps, "sec": 0, "pr": pr, "last": str(before[0].get("date", ""))}


## First against last of a series: {"from", "to", "delta", "days", "n"}, or {}
## with fewer than two points.
static func change(points: Array) -> Dictionary:
	if points.size() < 2:
		return {}
	var a = points[0]
	var b = points[points.size() - 1]
	return {"from": float(a.y), "to": float(b.y), "delta": float(b.y) - float(a.y), "days": Dates.days_between(str(a.x), str(b.x)), "n": points.size()}


# ---------------------------------------------------------------------------
# The lift page's three views (ui/screens/lift_views.gd): Compare, Progress,
# Logbook.
# ---------------------------------------------------------------------------

## The sets that were really done (reps > 0), in the order they were done.
static func real_sets(sets: Array) -> Array:
	return sets.filter(func(one): return int(one.get("reps", 0)) > 0)


## Set by set, this session against another one (the "previous" column of a
## gym log): [{"i" (1-based), "cur", "prev" (a set, or null), "kind", "dkg",
## "dreps", "dsec"}]. kind: "up" | "down" | "same" | "added" (no set at that
## place before) | "dropped" (that set was not done this time). A hold is
## compared by its seconds, then reps; a weighted set by its weight, then reps.
static func pairs(sets: Array, prev_sets: Array) -> Array:
	var cur = real_sets(sets)
	var prev = real_sets(prev_sets)
	var out = []
	for i in range(maxi(cur.size(), prev.size())):
		var c = cur[i] if i < cur.size() else null
		var p = prev[i] if i < prev.size() else null
		var row = {"i": i + 1, "cur": c, "prev": p, "kind": "same", "dkg": 0.0, "dreps": 0, "dsec": 0}
		if c == null:
			row.kind = "dropped"
		elif p == null:
			row.kind = "added"
		else:
			row.dreps = int(c.reps) - int(p.reps)
			if is_hold(c) or is_hold(p):
				row.dsec = int(c.get("holdSec", 0)) - int(p.get("holdSec", 0))
				if row.dsec != 0:
					row.kind = "up" if row.dsec > 0 else "down"
				elif row.dreps != 0:
					row.kind = "up" if row.dreps > 0 else "down"
			else:
				var dkg = float(c.get("weightKg", 0)) - float(p.get("weightKg", 0))
				if absf(dkg) > 1e-6:
					row.dkg = dkg
					row.kind = "up" if dkg > 0.0 else "down"
				elif row.dreps != 0:
					row.kind = "up" if row.dreps > 0 else "down"
		out.append(row)
	return out


## The day the lift went best: the history row with the heaviest top set (a
## hold: the longest; bodyweight: the most reps in a set), the newest of equal
## days. Null for an empty history.
static func best_row(history: Array):
	var best = null
	var best_v = -1.0
	for h in history:
		var v = main_value(day(h.get("sets", [])))
		if v > best_v + 1e-9:
			best_v = v
			best = h
	return best


## The ghost: the player about GHOST_DAYS before the session `cur` (one of
## `history`, newest first), the session closest to that day between 3 and 6
## weeks before; null when there is none. {"ghost" (the history row), "days",
## "you", "them" (ghost_score), "pct" (how far ahead, in %), "won", "tie"}.
const GHOST_DAYS = 28


static func ghost(history: Array, cur: Dictionary):
	var at = str(cur.get("date", ""))
	var best = null
	var best_gap = 99999
	for h in history:
		var days = Dates.days_between(str(h.get("date", "")), at)
		if days < 21 or days > 42:
			continue
		var gap = absi(days - GHOST_DAYS)
		if gap < best_gap:
			best_gap = gap
			best = h
	if best == null:
		return null
	var you = ghost_score(day(cur.get("sets", [])))
	var them = ghost_score(day(best.get("sets", [])))
	if them <= 0.0:
		return null
	var pct = (you / them - 1.0) * 100.0
	return {"ghost": best, "days": Dates.days_between(str(best.date), at), "you": you, "them": them, "pct": pct,
		"won": pct >= 0.5, "tie": absf(pct) < 0.5}


## Sessions in a row without beating the best before them that make a lift "stuck".
const STUCK_AFTER = 3


## Is a lift stuck: its last STUCK_AFTER days (of at least 5) no better than
## its best before them (ghost_score, 1% of slack)? {"stuck", "days", "best",
## "best_date", "since"} or null when not stuck. `history`: newest first.
static func plateau(history: Array):
	var days = by_day(history)
	if days.size() < STUCK_AFTER + 2:
		return null
	var recent = days.slice(days.size() - STUCK_AFTER)
	var before = days.slice(0, days.size() - STUCK_AFTER)
	var best = 0.0
	var best_date = ""
	for d in before:
		if ghost_score(d) > best:
			best = ghost_score(d)
			best_date = str(d.date)
	if best <= 0.0:
		return null
	for d in recent:
		if ghost_score(d) > best * 1.01:
			return null
	return {"stuck": true, "days": STUCK_AFTER, "best": best, "best_date": best_date, "since": str(recent[0].date)}


## Ways out of a plateau, for this lift (the weight in kg, its top working weight):
## [{"title", "text"}]: a reset week, a variation swap, another rep range (of
## one side, for a lift logged as both sides added up).
static func plateau_fixes(history: Array, lift_name: String, wu: String) -> Array:
	var d = day(history[0].sets) if not history.is_empty() else day([])
	var top = float(d.topKg)
	var sides = Sides.of_sets(history[0].sets) if not history.is_empty() else 1
	var reps = int(round(int(d.topReps) / float(sides)))
	var out = []
	if top > 0.0:
		var step = 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)
		var reset = maxf(step, roundf(top * 0.9 / step) * step)
		out.append({"title": "Reset week", "text": "Three sessions at %s, then build back up a step a week: it usually breaks through." % Fmt.fmt_weight(reset, wu)})
	var sp = LiftNames.split(lift_name)
	var swap = "dumbbells" if not str(sp.variation).to_lower().contains("dumbbell") else "a barbell or cable"
	out.append({"title": "Swap the variation", "text": "Three weeks of %s with %s, then come back to it fresh." % [str(sp.move), swap]})
	if reps > 0:
		var to = "8 to 10" if reps <= 6 else ("4 to 6" if reps >= 10 else "10 to 12")
		var each = " a side" if sides > 1 else ""
		out.append({"title": "Change the reps", "text": "You do sets of about %d%s: try %d weeks of %s reps%s." % [reps, each, 3, to, each]})
	return out


## What a ghost duel compares: the estimated one-rep max of the best set, the
## longest hold, or the most reps in a set (no weight).
static func ghost_score(d: Dictionary) -> float:
	if int(d.holdSec) > 0:
		return float(d.holdSec)
	if float(d.e1rm) > 0.0:
		return float(d.e1rm)
	return float(d.bestReps)


## The number a session of this lift is judged by: the longest hold, else the
## heaviest set, else the most reps in a set.
static func main_value(d: Dictionary) -> float:
	if int(d.holdSec) > 0:
		return float(d.holdSec)
	if float(d.topKg) > 0.0:
		return float(d.topKg)
	return float(d.bestReps)


## The records a session sets against everything before it, best news first:
## [{"id", "label", "value" (kg, reps or seconds), "unit": "kg" | "reps" | "sec"}].
## Empty for a first session (nothing to beat yet) or one that beat nothing.
##   top       heaviest set ever
##   reps_at   most reps ever at this weight or more (when the weight is not new)
##   strength  best estimated strength (one-rep max worked out from a set)
##   volume    most weight moved in one day of it
##   reps      most reps in one set (no weight)
##   day_reps  most reps in one day (no weight)
##   hold      longest hold
static func records(sets: Array, before: Array) -> Array:
	var cur = day(sets)
	if int(cur.sets) == 0 or before.is_empty():
		return []
	var b = {"top": 0.0, "strength": 0.0, "volume": 0.0, "reps": 0, "day_reps": 0, "hold": 0}
	var reps_at = 0
	for h in before:
		var d = day(h.get("sets", []))
		b.top = maxf(b.top, float(d.topKg))
		b.strength = maxf(b.strength, float(d.e1rm))
		b.volume = maxf(b.volume, float(d.volumeKg))
		b.reps = maxi(b.reps, int(d.bestReps))
		b.day_reps = maxi(b.day_reps, int(d.reps))
		b.hold = maxi(b.hold, int(d.holdSec))
		for one in real_sets(h.get("sets", [])):
			if float(cur.topKg) > 0.0 and float(one.get("weightKg", 0)) >= float(cur.topKg) - 1e-6:
				reps_at = maxi(reps_at, int(one.reps))
	var out = []
	if int(cur.holdSec) > 0:
		if int(cur.holdSec) > int(b.hold):
			out.append({"id": "hold", "label": "Longest hold", "value": int(cur.holdSec), "unit": "sec"})
		return out
	if float(cur.topKg) > 0.0:
		if float(cur.topKg) > float(b.top) + 1e-6:
			out.append({"id": "top", "label": "Heaviest set", "value": float(cur.topKg), "unit": "kg"})
		elif int(cur.topReps) > reps_at:
			out.append({"id": "reps_at", "label": "Most reps at this weight", "value": int(cur.topReps), "unit": "reps"})
		if float(cur.e1rm) > float(b.strength) + 1e-6:
			out.append({"id": "strength", "label": "Best estimated strength", "value": float(cur.e1rm), "unit": "kg"})
		if float(cur.volumeKg) > float(b.volume) + 1e-6:
			out.append({"id": "volume", "label": "Most weight moved in a day", "value": float(cur.volumeKg), "unit": "kg"})
		return out
	if int(cur.bestReps) > int(b.reps):
		out.append({"id": "reps", "label": "Most reps in a set", "value": int(cur.bestReps), "unit": "reps"})
	if int(cur.reps) > int(b.day_reps):
		out.append({"id": "day_reps", "label": "Most reps in a day", "value": int(cur.reps), "unit": "reps"})
	return out


## Past this many reps on every working set a weight is too light to build much.
const HIGH_REPS = 15
## The reps to come back down to at the heavier weight.
const DOWN_TO = 10

## Something to aim for next time, from a session's sets (double progression:
## more reps at the same weight until every set gets there, then more weight).
## A weighted lift whose every working set is at HIGH_REPS or more goes a step
## heavier and back down to DOWN_TO reps ("heavier": true), instead of adding
## a 25th rep to a weight that is too light.
## A lift logged as BOTH SIDES ADDED UP (sets tagged by Sides.tag_sets:
## "sides": 2) is judged by one side: 25 reps are a 12 and a 13, so it only
## goes heavier past HIGH_REPS a side (30), down to DOWN_TO a side (20).
## {"kind": "weight" | "reps" | "hold" | "none", "sets": the sets to aim for,
##  "set": the set that changes (1-based, 0 = all), "reps": its reps, "addKg",
##  "addSec", "kg": the working weight, "sides": 1, or 2 when the reps are
##  both sides added up}. `step_kg`: the weight to add (2.5 kg, or 5 lb in kg).
static func next_target(sets: Array, step_kg: float) -> Dictionary:
	var real = real_sets(sets)
	var out = {"kind": "none", "sets": [], "set": 0, "reps": 0, "addKg": 0.0, "addSec": 0, "kg": 0.0, "sides": 1}
	if real.is_empty():
		return out
	var sides = Sides.of_sets(real)
	out.sides = sides
	var aim = []
	for one in real:
		aim.append(one.duplicate())
	var holds = real.filter(func(one): return is_hold(one))
	if not holds.is_empty():
		for one in aim:
			if is_hold(one):
				one.holdSec = int(one.holdSec) + 5
		out.kind = "hold"
		out.sets = aim
		out.addSec = 5
		return out
	var top = 0.0
	for one in real:
		top = maxf(top, float(one.get("weightKg", 0)))
	out.kg = top
	# The working sets: the ones at the top weight (warm-ups stay as they were).
	var work = []
	for i in range(real.size()):
		if absf(float(real[i].get("weightKg", 0)) - top) <= 1e-6:
			work.append(i)
	var most = 0
	var least_i = work[0]
	for i in work:
		most = maxi(most, int(real[i].reps))
		if int(real[i].reps) < int(real[least_i].reps):
			least_i = i
	if top > 0.0 and int(real[least_i].reps) >= HIGH_REPS * sides:
		for i in work:
			aim[i].weightKg = top + step_kg
			aim[i].reps = DOWN_TO * sides
		out.kind = "weight"
		out.addKg = step_kg
		out.reps = DOWN_TO * sides
		out.sets = aim
		out["heavier"] = true
		return out
	if top > 0.0 and int(real[least_i].reps) >= most:
		for i in work:
			aim[i].weightKg = top + step_kg
		out.kind = "weight"
		out.addKg = step_kg
		out.reps = most
		out.sets = aim
		return out
	aim[least_i].reps = int(aim[least_i].reps) + 1
	out.kind = "reps"
	out.set = least_i + 1
	out.reps = int(aim[least_i].reps)
	out.sets = aim
	return out


## The points of a chart that set a new best: indexes into `points` (oldest
## first) whose y beats every point before it. The first point is not one.
static func record_points(points: Array) -> Array:
	var out = []
	var best = -INF
	for i in range(points.size()):
		var y = float(points[i].y)
		if i > 0 and y > best + 1e-9:
			out.append(i)
		best = maxf(best, y)
	return out


## The points of the last `days` days up to `today` (days <= 0: all of them).
static func since(points: Array, today: String, days: int) -> Array:
	if days <= 0:
		return points
	var from = Dates.add_days(today, -days)
	return points.filter(func(p): return str(p.x) >= from)


## The lift's calendar: the last `weeks` Monday-weeks up to the week of
## `today`, day by day, Monday first. [{"date", "sets", "level" (0 = not done,
## 1..4 how big a day it was against its biggest), "pr" (a new best that day),
## "future" (after today)}]. A day's size is its weight moved, or its reps
## (holds: seconds held) for a lift without weight.
static func calendar(history: Array, today: String, weeks: int) -> Array:
	var rows = by_day(history)
	var size_of = {}
	var biggest = 0.0
	var loaded = weighted(history)
	var pr_days = {}
	var best = -1.0
	for i in range(rows.size()):
		var r = rows[i]
		var v = float(r.volumeKg) if loaded else float(r.reps + r.holdTotal)
		size_of[r.date] = {"v": v, "sets": int(r.sets)}
		biggest = maxf(biggest, v)
		var m = main_value(r)
		if i > 0 and m > best + 1e-9:
			pr_days[r.date] = true
		best = maxf(best, m)
	var start = Dates.add_weeks(Dates.week_key(today), -(weeks - 1))
	var out = []
	for w in range(weeks):
		for d in range(7):
			var date = Dates.add_days(Dates.add_weeks(start, w), d)
			var cell = {"date": date, "sets": 0, "level": 0, "pr": pr_days.has(date), "future": date > today}
			if size_of.has(date):
				cell.sets = size_of[date].sets
				cell.level = clampi(int(ceil(4.0 * float(size_of[date].v) / maxf(biggest, 1e-9))), 1, 4)
			out.append(cell)
	return out


## The heaviest weight lifted for at least n reps, as steps: consecutive rep
## counts with the same best are one step. [{"from", "to" (reps), "kg", "date"}],
## fewest reps first. Only sets with weight count; rep counts past `max_reps`
## are left out. A lift logged as both sides added up (tagged sets) is counted
## by one side: 25 reps are 12 on each for sure.
static func rep_ladder(history: Array, max_reps: int = 12) -> Array:
	var best = {}
	for h in history:
		for one in real_sets(h.get("sets", [])):
			var w = float(one.get("weightKg", 0))
			if w <= 0.0 or is_hold(one):
				continue
			var side_reps = int(floor(int(one.reps) / float(maxi(1, int(one.get("sides", 1))))))
			for n in range(1, mini(side_reps, max_reps) + 1):
				if not best.has(n) or w > float(best[n].kg) + 1e-9:
					best[n] = {"kg": w, "date": str(h.get("date", ""))}
	var out = []
	for n in range(1, max_reps + 1):
		if not best.has(n):
			continue
		var last = out[out.size() - 1] if not out.is_empty() else null
		if last != null and int(last.to) == n - 1 and absf(float(last.kg) - float(best[n].kg)) <= 1e-9:
			last.to = n
		else:
			out.append({"from": n, "to": n, "kg": float(best[n].kg), "date": best[n].date})
	return out
