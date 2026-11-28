class_name Prep
extends RefCounted
## A day's workout PREPPED ahead (2026-11-27, the user: "I want to be able to plan my workout based on
## variation and equipment for the next day so I can look ahead at weights, reps, and equipment. I can still
## change once I go to log it, but like tomorrow the plan for me has a bunch of stuff I can't use, so mentally
## I like to know what exactly I'm going to work on and superset based on what I have and look at what I want
## to beat for goals based on that"). Pure.
##
## STORED in settings.preps = {date: {"lifts": [{"name", "sets": [{reps, weightKg[, band][, holdSec]}], "ss"}],
## "at"}}: the lifts in the order they will be done, each the exact way (variation, equipment) with the sets to
## aim for, and "ss" a superset group (0: none; lifts next to each other with the same number are done in turn).
## A prepped day's plan IS the prep (Missions.day_plan, `plan_lifts`): its lifts, its aims ("aimSets"), no
## lift of the game's own guess. The Log tab starts from it; anything can still be changed there.
##
## Also here: the lifts that work the same muscles as a workout (`area_parts`, `area_lifts`), for the Log tab's
## "same muscles" keys and the prep's "add a lift" (the user, the same message: "add a few recommended other lifts
## that cover the same area at the bottom so that I have to type less").

const KEY = "preps"
## Preps of days more than this long ago are dropped when another is saved.
const KEPT_DAYS = 14
## Sets of a lift with no history and no aim, to start from.
const START_SETS = 3
const START_REPS = 8


static func of(settings: Dictionary, date: String):
	var all = settings.get(KEY, {})
	if not (all is Dictionary):
		return null
	var p = all.get(date)
	if p is Dictionary and (p.get("lifts", []) as Array).size() > 0:
		return p
	return null


static func lifts_of(prep) -> Array:
	if not (prep is Dictionary):
		return []
	return (prep.get("lifts", []) as Array).filter(func(x): return x is Dictionary and str(x.get("name", "")).strip_edges() != "")


## The settings' preps with `date` set to `lifts` (empty: the prep taken off), days older than KEPT_DAYS dropped.
static func with_prep(settings: Dictionary, date: String, lifts: Array, today: String, at_ms: int = 0) -> Dictionary:
	var out = {}
	var all = settings.get(KEY, {})
	if all is Dictionary:
		for d in all:
			if str(d) >= Dates.add_days(today, -KEPT_DAYS) and str(d) != date:
				out[d] = all[d]
	var clean = []
	for x in lifts:
		var nm = str(x.get("name", "")).strip_edges()
		if nm == "":
			continue
		var sets = []
		for one in x.get("sets", []):
			var s = {"reps": maxi(0, int(one.get("reps", 0))), "weightKg": maxf(0.0, float(one.get("weightKg", 0.0)))}
			if str(one.get("band", "")) != "":
				s["band"] = str(one.band)
			if int(one.get("holdSec", 0)) > 0:
				s["holdSec"] = int(one.holdSec)
			sets.append(s)
		clean.append({"name": nm, "sets": sets, "ss": int(x.get("ss", 0))})
	if not clean.is_empty():
		out[date] = {"lifts": clean, "at": at_ms}
	return out


## A prep to start from: the day's planned lifts (Missions.day_plan or Missions.ahead's plan), each the way it
## was done last with the aim for next time (LiftTrend.next_target), a never-done one with START_SETS x START_REPS.
static func from_plan(plan_lifts: Array, step_kg: float) -> Array:
	var out = []
	for l in plan_lifts:
		if bool(l.get("pt", false)):
			continue
		var opts = l.get("options", [])
		var o = opts[0] if not opts.is_empty() else {"name": str(l.get("name", "")), "last": l.get("last", {}).get("sets", []), "new": false}
		if l.has("aimSets"):
			out.append({"name": str(l.name), "sets": (l.aimSets as Array).duplicate(true), "ss": int(l.get("ss", 0))})
			continue
		out.append({"name": str(o.name), "sets": aim_of(o.get("last", []), step_kg), "ss": 0})
	return out


## The sets to aim for after `last` (next_target), or a plain start when there is nothing to go by.
static func aim_of(last: Array, step_kg: float) -> Array:
	var real = LiftTrend.real_sets(last)
	if real.is_empty():
		var out = []
		for i in range(START_SETS):
			out.append({"reps": START_REPS, "weightKg": 0.0})
		return out
	var t = LiftTrend.next_target(real, step_kg)
	var sets = t.sets if str(t.kind) != "none" else real
	var clean = []
	for one in sets:
		var s = {"reps": int(one.get("reps", 0)), "weightKg": float(one.get("weightKg", 0.0))}
		if str(one.get("band", "")) != "":
			s["band"] = str(one.band)
		if int(one.get("holdSec", 0)) > 0:
			s["holdSec"] = int(one.holdSec)
		clean.append(s)
	return clean


## The day plan's lifts from a prep, shaped like Missions.likely_lifts' (name, why, part, kind, last, ...),
## each with "prep": true, "aimSets" (the prepped sets) and "ss". `before`: the sessions before the day.
static func plan_lifts(prep, before: Array, today: String, marks: Dictionary) -> Array:
	var hist = LiftLibrary.stats(before)
	var out = []
	var i = 0
	for x in lifts_of(prep):
		var n = str(x.name)
		var st = hist.get(Xp.normalize_exercise(n))
		var last = {"date": "", "sets": []}
		var since = 0
		if st != null and not (st.history as Array).is_empty():
			last = {"date": str(st.history[0].date), "sets": st.history[0].sets}
			since = Dates.days_between(str(st.history[0].date), today)
		out.append({"name": n, "score": 100.0 - i, "why": "Your prep", "part": Missions.part_of(n), "pt": Pt.is_pt(marks, n),
			"kind": Missions.kind_of(n), "variations": [n], "last": last, "since": since, "gap": 0.0, "same": 0,
			"prep": true, "aimSets": (x.get("sets", []) as Array).duplicate(true), "ss": int(x.get("ss", 0))})
		i += 1
	return out


## A prep's sets in words: as LiftHistory says them, but a weighted lift prepped without a weight yet (a way
## never done) reads "3x8, pick the weight", never "bodyweight".
static func describe(sets: Array, lift_name: String, fmt_w: Callable) -> String:
	var real = LiftTrend.real_sets(sets)
	var no_weight = real.all(func(one): return float(one.get("weightKg", 0)) <= 0.0 and str(one.get("band", "")) == "" and int(one.get("holdSec", 0)) <= 0)
	if not real.is_empty() and no_weight and not Missions.gear_of_lift(lift_name).has("bodyweight"):
		var reps = real.map(func(one): return int(one.reps))
		var same = reps.all(func(r): return r == reps[0])
		return ("%d×%d" % [reps.size(), reps[0]] if same else ", ".join(PackedStringArray(reps.map(func(r): return str(r))))) + ", pick the weight"
	return LiftHistory.describe_sets(sets, fmt_w)


## The prepped entry of a lift on `date` ({name, sets, ss}), or null.
static func lift_on(settings: Dictionary, date: String, lift_name: String):
	var k = Xp.normalize_exercise(lift_name)
	for x in lifts_of(of(settings, date)):
		if Xp.normalize_exercise(str(x.name)) == k:
			return x
	return null


# ---------------------------------------------------------------------------
# The same muscles
# ---------------------------------------------------------------------------

## The body parts a workout works: those of its lifts, and those of the day's kind ("push": chest,
## shoulders, triceps) when it has one. Mobility and full-body work name none.
static func area_parts(lift_names: Array, kind: String = "") -> Array:
	var out = []
	for p in Missions.KIND_PARTS.get(kind, []):
		if not out.has(p):
			out.append(p)
	if kind == "upper":
		for k in ["push", "pull"]:
			for p in Missions.KIND_PARTS[k]:
				if not out.has(p):
					out.append(p)
	elif kind == "lower":
		for p in Missions.KIND_PARTS["legs"]:
			if not out.has(p):
				out.append(p)
	for n in lift_names:
		var p = Missions.part_of(str(n))
		if p != "" and p != "mobility" and p != "full" and not out.has(p):
			out.append(p)
	return out


## Lifts for those parts, to add with one tap: the player's own first (the most done first, one variation a
## movement: the one done last), then the library's staples of those areas (Missions.STAPLES). Never a
## movement already in `taken` (lift names), never physical therapy. [{"name", "part", "own": bool}].
static func area_lifts(parts: Array, sessions: Array, taken: Array, marks: Dictionary = {}, limit: int = 8) -> Array:
	if parts.is_empty():
		return []
	var taken_moves = {}
	for n in taken:
		taken_moves[Xp.normalize_exercise(Missions.move_of(str(n)))] = true
	var count = {}
	var last = {}
	for s in sessions:
		if str(s.get("discipline", "")) != "lift":
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			if LiftTrend.real_sets(ex.get("sets", [])).is_empty() or Pt.is_pt(marks, n):
				continue
			count[n] = int(count.get(n, 0)) + 1
			if str(s.get("date", "")) > str(last.get(n, "")):
				last[n] = str(s.get("date", ""))
	var own = count.keys().filter(func(n): return parts.has(Missions.part_of(str(n))))
	# One variation a movement: the one done last; then the movements done most.
	var best_of = {}
	for n in own:
		var mk = Xp.normalize_exercise(Missions.move_of(str(n)))
		if not best_of.has(mk) or str(last[n]) > str(last[best_of[mk]]):
			best_of[mk] = n
	var moves = best_of.keys()
	var total = {}
	for n in own:
		var mk2 = Xp.normalize_exercise(Missions.move_of(str(n)))
		total[mk2] = int(total.get(mk2, 0)) + int(count[n])
	moves.sort_custom(func(a, b): return int(total[a]) > int(total[b]) or (int(total[a]) == int(total[b]) and str(a) < str(b)))
	var out = []
	for mk3 in moves:
		if out.size() >= limit:
			break
		if taken_moves.has(mk3):
			continue
		taken_moves[mk3] = true
		out.append({"name": str(best_of[mk3]), "part": Missions.part_of(str(best_of[mk3])), "own": true})
	# The library's staples of those areas, taken in turn.
	var groups = []
	for p in parts:
		var g = str(Missions.GROUP.get(p, ""))
		if g != "" and not groups.has(g):
			groups.append(g)
	var longest = 0
	for g in groups:
		longest = maxi(longest, (Missions.STAPLES.get(g, []) as Array).size())
	for i in range(longest):
		for g in groups:
			if out.size() >= limit:
				return out
			var staples = Missions.STAPLES.get(g, [])
			if i >= staples.size():
				continue
			var e = LiftNames.movement(str(staples[i]))
			if e == null or not parts.has(str(e.part)):
				continue
			var mk4 = Xp.normalize_exercise(str(e.name))
			if taken_moves.has(mk4):
				continue
			taken_moves[mk4] = true
			out.append({"name": LiftNames.join(str(e.name), Missions.variation_for(e)), "part": str(e.part), "own": false})
	return out
