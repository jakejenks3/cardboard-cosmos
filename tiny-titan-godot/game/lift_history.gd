class_name LiftHistory
extends RefCounted
## What you did last time (port of liftHistory.ts). Powers the lifting form's
## prefill, exercise picker and the "you beat last time" badges, so logging is
## mostly tapping + / -.
##
## LiftSet: {reps: int, weightKg: number (0 = bodyweight)}
## LastPerformance: {name: String (display name as last typed), date: String,
##                   sets: [LiftSet] (only the ones with reps > 0), sessionId: String}
## ExerciseSuggestion: {key: String (normalized name), name: String,
##                      count: int (sessions that included it; 0 = never done, from the default list),
##                      last: LastPerformance}   ("last" is missing on never-done defaults: use .get("last"))
## SetTrend: {kind: "pr"} | {kind: "weight", deltaKg} | {kind: "reps", delta} | {kind: "extra"} | null


static func _newer_first(a: Dictionary, b: Dictionary) -> bool:
	if a.date != b.date:
		return a.date > b.date
	return a.createdAt > b.createdAt


static func _lift_sessions_newest_first(sessions: Array, exclude_id = null) -> Array:
	var out: Array = []
	for s in sessions:
		if s.discipline == "lift" and s.id != exclude_id:
			out.append(s)
	TTUtil.stable_sort(out, func(a, b): return LiftHistory._newer_first(a, b))
	return out


static func _done_sets(sets: Array) -> Array:
	var out: Array = []
	for x in sets:
		if x.reps > 0:
			out.append(x)
	return out


static func _has_done_set(sets: Array) -> bool:
	for x in sets:
		if x.reps > 0:
			return true
	return false


## The most recent logged sets for every exercise, keyed by normalized name
## (`Xp.normalize_exercise`). `exclude_id` leaves out the session being edited.
static func last_performances(sessions: Array, exclude_id = null) -> Dictionary:
	var out: Dictionary = {}
	for s in _lift_sessions_newest_first(sessions, exclude_id):
		for ex in s.exercises:
			var key: String = Xp.normalize_exercise(ex.name)
			var sets: Array = _done_sets(ex.sets)
			if key == "" or sets.is_empty() or out.has(key):
				continue
			out[key] = {"name": ex.name.strip_edges(), "date": s.date, "sets": sets, "sessionId": s.id}
	return out


static func _suggestion_before(a: Dictionary, b: Dictionary) -> bool:
	if a.last.date != b.last.date:
		return a.last.date > b.last.date
	if a.count != b.count:
		return a.count > b.count
	return a.name.to_lower() < b.name.to_lower()


## Exercises to offer: yours first (most recent first, then most often done,
## then by name), then the common `defaults` you have not done yet.
static func exercise_suggestions(sessions: Array, defaults: Array, exclude_id = null) -> Array:
	var last: Dictionary = last_performances(sessions, exclude_id)
	var counts: Dictionary = {}
	for s in _lift_sessions_newest_first(sessions, exclude_id):
		var seen: Dictionary = {}
		for ex in s.exercises:
			var key: String = Xp.normalize_exercise(ex.name)
			if key == "" or seen.has(key) or not _has_done_set(ex.sets):
				continue
			seen[key] = true
			counts[key] = counts.get(key, 0) + 1
	var mine: Array = []
	for lp in last.values():
		var key: String = Xp.normalize_exercise(lp.name)
		mine.append({"key": key, "name": lp.name, "count": counts.get(key, 1), "last": lp})
	TTUtil.stable_sort(mine, func(a, b): return LiftHistory._suggestion_before(a, b))
	var have: Dictionary = {}
	for m in mine:
		have[m.key] = true
	var out: Array = mine
	for d in defaults:
		var key: String = Xp.normalize_exercise(d)
		if not have.has(key):
			out.append({"key": key, "name": d, "count": 0})
	return out


## Recent workouts (whole lift sessions, newest first) with different exercise
## line-ups, so A/B splits each show up once.
static func recent_workouts(sessions: Array, n: int = 3, exclude_id = null) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for s in _lift_sessions_newest_first(sessions, exclude_id):
		var names: Array = []
		for e in s.exercises:
			if _has_done_set(e.sets):
				names.append(Xp.normalize_exercise(e.name))
		if names.is_empty():
			continue
		names.sort()
		var sig: String = "|".join(PackedStringArray(names))
		if seen.has(sig):
			continue
		seen[sig] = true
		out.append(s)
		if out.size() >= n:
			break
	return out


## How a set compares with the same set last time.
## `prev`: the set at the same position last time, or null if there was none.
## `had_history`: whether this exercise has been logged before at all.
## `best_weight_kg`: heaviest weight ever lifted for this exercise (0 if none).
## Returns a SetTrend Dictionary, or null when there is nothing to celebrate.
static func compare_set(cur: Dictionary, prev, had_history: bool, best_weight_kg: float):
	var eps: float = 1e-6
	if cur.reps <= 0:
		return null
	if cur.weightKg > 0 and best_weight_kg > 0 and cur.weightKg > best_weight_kg + eps:
		return {"kind": "pr"}
	if prev == null:
		return {"kind": "extra"} if had_history else null
	if cur.weightKg > prev.weightKg + eps:
		return {"kind": "weight", "deltaKg": cur.weightKg - prev.weightKg}
	if absf(cur.weightKg - prev.weightKg) <= eps and cur.reps > prev.reps:
		return {"kind": "reps", "delta": cur.reps - prev.reps}
	return null


## Step a value to the next / previous multiple of `step_size`
## (61 -> 62.5 -> 65 with step 2.5). `direction` is 1 or -1.
static func step_value(value: float, step_size: float, direction: int, min_value: float = 0.0) -> float:
	var eps: float = 1e-6
	var q: float = value / step_size
	var next: float = (floor(q + eps) + 1.0) if direction > 0 else (ceil(q - eps) - 1.0)
	return maxf(min_value, TTUtil.jsround(next * step_size * 10000.0) / 10000.0)


static func volume_kg(sets: Array) -> float:
	var total: float = 0.0
	for s in sets:
		total += max(0, s.reps) * max(0, s.weightKg)
	return total


static func _top_set(valid: Array) -> Dictionary:
	var top: Dictionary = valid[0]
	for s in valid:
		if s.weightKg > top.weightKg:
			top = s
	return top


## "3×5 @ 100 kg", "5, 5, 4 @ 62.5 kg", "3 sets, top 100 kg × 5", "3×8 bodyweight".
## `fmt_w` is a Callable(kg) -> String that formats a weight in display units.
static func describe_sets(sets: Array, fmt_w: Callable) -> String:
	var valid: Array = _done_sets(sets)
	if valid.is_empty():
		return ""
	var w0 = valid[0].weightKg
	var r0 = valid[0].reps
	var same_w: bool = true
	var same_r: bool = true
	var reps: Array = []
	for s in valid:
		if not (absf(s.weightKg - w0) < 1e-6):
			same_w = false
		if s.reps != r0:
			same_r = false
		reps.append(TTUtil.num_str(s.reps))
	var w_label: String = (" @ %s" % fmt_w.call(w0)) if w0 > 0 else " bodyweight"
	if same_w and same_r:
		return "%s×%s%s" % [str(valid.size()), TTUtil.num_str(r0), w_label]
	if same_w:
		return "%s%s" % [", ".join(PackedStringArray(reps)), w_label]
	var top: Dictionary = _top_set(valid)
	return "%s sets, top %s × %s" % [str(valid.size()), fmt_w.call(top.weightKg), TTUtil.num_str(top.reps)]


## Short label for a chip: the heaviest set, e.g. "105×5". `to_unit` is a
## Callable(kg) -> number that converts to display units (shown to one decimal).
static func top_set_label(sets: Array, to_unit: Callable) -> String:
	var valid: Array = _done_sets(sets)
	if valid.is_empty():
		return ""
	var top: Dictionary = _top_set(valid)
	if top.weightKg <= 0:
		return "%s×%s" % [str(valid.size()), TTUtil.num_str(top.reps)]
	return "%s×%s" % [_tenths_str(TTUtil.jsround(to_unit.call(top.weightKg) * 10.0)), TTUtil.num_str(top.reps)]


## Text of `tenths / 10` the way JS prints it: 1405 -> "140.5", 1400 -> "140".
static func _tenths_str(tenths: int) -> String:
	var a: int = absi(tenths)
	var whole: String = str(int(floor(a / 10.0)))
	var out: String = whole if a % 10 == 0 else "%s.%s" % [whole, str(a % 10)]
	return ("-" + out) if tenths < 0 else out
