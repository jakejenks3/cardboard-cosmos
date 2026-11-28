class_name LiftProgress
extends RefCounted
## How a lift is going, measured the way the game's own aims ask for progress (double progression: more
## reps at the same weight, then a step heavier). Pure: reads sets, never the save.
##
## (2026-11-27, the user: "History still is weird. Same line graph for doing an extra rep at same weight.
## Progress doesn't feel important. Do a deep dive into this". Every screen measured a lift by its heaviest
## set, so eight workouts in a row that each added a rep at 60 kg drew a flat line, flat bars and no "new
## best"; the reel said nothing. Everything here is a REAL number from the log: no estimate.)
##
## A day's KEY is [rung, reps]: the rung is what was lifted (the heaviest weight in kg; for a band its level
## on the ladder; for a hold its longest seconds; 0 for bodyweight) and reps are all the reps done AT that
## rung (sets of the top weight; bodyweight: every rep). One day beats another when its rung is higher, or
## the rung is the same and it has more reps there. So 60 x 9, 8, 8 beats 60 x 8, 8, 8, and 62.5 x 8, 8, 7
## beats 60 x 10, 10, 10 (a rung up).

const EPS = 1e-6


## The kind of number a lift's rung is: "kg", "band", "sec" or "bw".
static func mode_of_sets(sets: Array) -> String:
	var real = LiftTrend.real_sets(sets)
	if real.any(func(one): return LiftTrend.is_hold(one)):
		return "sec"
	if real.any(func(one): return float(one.get("weightKg", 0)) > 0.0):
		return "kg"
	if real.any(func(one): return Bands.is_band(one)):
		return "band"
	return "bw"


## [rung, reps, list (the reps of each set at the rung, in order)] of one day's sets.
static func key(sets: Array) -> Dictionary:
	var real = LiftTrend.real_sets(sets)
	var mode = mode_of_sets(real)
	var rung = 0.0
	for one in real:
		rung = maxf(rung, _rung_of(one, mode))
	var reps = 0
	var list = []
	for one in real:
		if mode == "bw" or absf(_rung_of(one, mode) - rung) <= EPS:
			reps += int(one.reps)
			list.append(int(one.reps))
	return {"mode": mode, "rung": rung, "reps": reps, "list": list, "sets": real.size()}


static func _rung_of(one: Dictionary, mode: String) -> float:
	match mode:
		"kg":
			return maxf(0.0, float(one.get("weightKg", 0)))
		"sec":
			return float(one.get("holdSec", 0)) if LiftTrend.is_hold(one) else 0.0
		"band":
			return float(Bands.level(one.get("band", ""))) if Bands.is_band(one) else 0.0
	return 0.0


## 1 when key a beats key b, -1 when it is behind, 0 when the same.
static func cmp(a: Dictionary, b: Dictionary) -> int:
	if float(a.rung) > float(b.rung) + EPS:
		return 1
	if float(a.rung) < float(b.rung) - EPS:
		return -1
	if int(a.reps) > int(b.reps):
		return 1
	if int(a.reps) < int(b.reps):
		return -1
	return 0


## The history (any order; entries {date, sets}) as one row per day, oldest first:
## {date, key, beat (against the day before: 1 / 0 / -1; 0 for the first), record (beats every day
## before it; never the first), rung_up (a rung never reached before), reps_up (more reps at the same
## rung than the day before), rung_index (0 for the first rung reached, +1 each new rung)}.
static func days(history: Array) -> Array:
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
	var best = null
	var top_rung = -INF
	var rung_index = -1
	var prev = null
	for d in order:
		var k = key(sets_of[d])
		if int(k.reps) <= 0 and float(k.rung) <= 0.0:
			continue
		var row = {"date": d, "key": k, "beat": 0, "record": false, "rung_up": false, "reps_up": false}
		if prev != null:
			row.beat = cmp(k, prev)
			row.reps_up = absf(float(k.rung) - float(prev.rung)) <= EPS and int(k.reps) > int(prev.reps)
		if best != null and cmp(k, best) > 0:
			row.record = true
		if float(k.rung) > top_rung + EPS:
			row.rung_up = best != null
			top_rung = float(k.rung)
			rung_index += 1
		row["rung_index"] = maxi(0, rung_index)
		if best == null or cmp(k, best) > 0:
			best = k
		prev = k
		out.append(row)
	return out


## Bar heights that climb with every gain, for SparkBars and the like: each day's place among all the
## distinct keys (1 = the lowest), so one more rep is one step up and a rung up is a step up too.
static func ranks(rows: Array) -> Array:
	var keys = []
	for r in rows:
		keys.append(r.key)
	var uniq = []
	for k in keys:
		if not uniq.any(func(u): return cmp(u, k) == 0):
			uniq.append(k)
	uniq.sort_custom(func(a, b): return cmp(a, b) < 0)
	var out = []
	for k in keys:
		for i in range(uniq.size()):
			if cmp(uniq[i], k) == 0:
				out.append(float(i + 1))
				break
	return out


## The story of a lift in a few numbers:
## {"days", "beat" (days that beat the one before), "same", "down", "streak" (the days in a row up to the
## last that each beat the one before), "best_streak", "rungs" (new rungs reached after the first),
## "first_rung", "top_rung" (the highest reached), "rung" (the current one: the last day's), "rung_days" (days at it since it was first
## reached), "rung_first_reps", "rung_reps" (reps there the first and the last time), "records"}.
static func summary(rows: Array) -> Dictionary:
	var out = {"days": rows.size(), "beat": 0, "same": 0, "down": 0, "streak": 0, "best_streak": 0, "rungs": 0,
		"first_rung": 0.0, "top_rung": 0.0, "rung": 0.0, "rung_days": 0, "rung_first_reps": 0, "rung_reps": 0, "records": 0, "mode": "kg"}
	if rows.is_empty():
		return out
	out.first_rung = float(rows[0].key.rung)
	out.mode = str(rows[0].key.mode)
	var run = 0
	for i in range(rows.size()):
		var r = rows[i]
		if i > 0:
			match int(r.beat):
				1:
					out.beat += 1
					run += 1
				0:
					out.same += 1
					run = 0
				_:
					out.down += 1
					run = 0
			out.best_streak = maxi(int(out.best_streak), run)
		if bool(r.rung_up):
			out.rungs += 1
		out.top_rung = maxf(float(out.top_rung), float(r.key.rung))
		if bool(r.record):
			out.records += 1
	out.streak = run
	var last = rows[rows.size() - 1]
	out.rung = float(last.key.rung)
	out.rung_reps = int(last.key.reps)
	# Since the current rung was first reached at its weight (a dip below it and back starts it again).
	var first_i = rows.size() - 1
	while first_i > 0 and absf(float(rows[first_i - 1].key.rung) - float(last.key.rung)) <= EPS:
		first_i -= 1
	out.rung_days = rows.size() - first_i
	out.rung_first_reps = int(rows[first_i].key.reps)
	return out


## How one day's sets did against the day before, in a few words for a list or the reel:
## {"kind": "first" | "up" | "same" | "down", "words": "+1 rep at 62.5 kg" | "+2.5 kg" | "New rung: 62.5 kg"
## | "Same as last time" | "2 reps short" ..., "record" (better than any day before), "rung_up"}.
## `before`: the lift's history before these sets, newest first ({date, sets}).
## `fmt_rung`: Callable(rung) -> String ("62.5 kg", "Green band", "30 s").
static func change(sets: Array, before: Array, fmt_rung: Callable) -> Dictionary:
	var k = key(sets)
	if int(k.reps) <= 0:
		return {"kind": "none", "words": "", "record": false, "rung_up": false}
	if before.is_empty():
		return {"kind": "first", "words": "First time", "record": false, "rung_up": false}
	var prev = key(before[0].get("sets", []))
	var best = null
	var top = -INF
	for h in before:
		var bk = key(h.get("sets", []))
		if best == null or cmp(bk, best) > 0:
			best = bk
		top = maxf(top, float(bk.rung))
	var c = cmp(k, prev)
	var out = {"kind": "same", "words": "Same as last time", "record": cmp(k, best) > 0, "rung_up": float(k.rung) > top + EPS and k.mode != "bw"}
	if c > 0:
		out.kind = "up"
		if float(k.rung) > float(prev.rung) + EPS:
			out.words = ("New rung: %s" % str(fmt_rung.call(k.rung))) if bool(out.rung_up) else ("Up to %s" % str(fmt_rung.call(k.rung)))
		else:
			var more = int(k.reps) - int(prev.reps)
			out.words = "+%d rep%s" % [more, "" if more == 1 else "s"] + ("" if k.mode == "bw" else " at %s" % str(fmt_rung.call(k.rung)))
	elif c < 0:
		out.kind = "down"
		if float(k.rung) < float(prev.rung) - EPS:
			out.words = "Lighter: %s" % str(fmt_rung.call(k.rung))
		else:
			var short = int(prev.reps) - int(k.reps)
			out.words = "%d rep%s short of last time" % [short, "" if short == 1 else "s"]
	return out


## For every lift session, how many of its exercises beat the time before (by name, against the last
## day that exercise was done before this session's date): {session id: {"beat", "of"}}. Exercises done
## for the first time count in neither.
static func beat_counts(sessions: Array) -> Dictionary:
	var lifts = sessions.filter(func(s): return str(s.get("discipline", "")) == "lift")
	lifts.sort_custom(func(a, b): return str(a.date) < str(b.date) or (str(a.date) == str(b.date) and float(a.get("createdAt", 0)) < float(b.get("createdAt", 0))))
	var last_of = {}  # lift -> {date, sets}
	var out = {}
	for s in lifts:
		var beat = 0
		var of = 0
		var done_here = {}
		for e in s.get("exercises", []):
			var real = LiftTrend.real_sets(e.get("sets", []))
			if real.is_empty():
				continue
			var nm = Xp.normalize_exercise(str(e.get("name", "")))
			if done_here.has(nm):
				continue
			done_here[nm] = true
			var prev = last_of.get(nm)
			if prev != null and str(prev.date) < str(s.date):
				of += 1
				if cmp(key(real), key(prev.sets)) > 0:
					beat += 1
		for e in s.get("exercises", []):
			var real2 = LiftTrend.real_sets(e.get("sets", []))
			if real2.is_empty():
				continue
			var nm2 = Xp.normalize_exercise(str(e.get("name", "")))
			var p2 = last_of.get(nm2)
			if p2 != null and str(p2.date) == str(s.date):
				# two sessions of one day are one day of that lift
				var both = (p2.sets as Array).duplicate()
				both.append_array(real2)
				last_of[nm2] = {"date": str(s.date), "sets": both}
			else:
				last_of[nm2] = {"date": str(s.date), "sets": real2}
		out[str(s.get("id", ""))] = {"beat": beat, "of": of}
	return out
