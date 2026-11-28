class_name Challenges
extends RefCounted
## The day's lift CHALLENGES (2026-11-27, the user: "Make sure those [weight and rep records] get built into
## daily challenges. The whole goal is to give me variation to either increase weight or try to put up more
## reps at a weight I've done before. Daily challenges are boring right now... make them give me some variance
## and things to think about trying when I go to gym"). Pure.
##
## For a lift, a short menu of concrete targets, each a RECORD to set, picked from its history and rotated
## by the date so the days differ:
##   heavier   heavier than ever: the heaviest weight + a step, for a few reps
##   reps      a rep record at a weight done before: one rep more in a set than ever there (that weight or
##             heavier, as LiftProgress.rep_records counts it); the weight rotates over the working weights
##   ladder    the best for N reps: the heaviest weight done for N reps or more, + a step, for N reps; N
##             rotates over 1, 3, 5, 8, 10, 12 (the ones that tell something new)
##   set_reps  bodyweight: one more rep in a set than ever
##   day_reps  bodyweight: more reps in a day than ever
##   band      a band: the next band up, or one more rep with the heaviest band
##   hold      a hold: five seconds longer
## Each option: {"type", "kind" ("weight" | "reps"), "kg", "reps", "band", "sec", "title", "words", "sub",
## "chip" (short, for a key), "tip" (something to try for it)}.
## Real numbers only: every target is a weight and reps, never an estimate.

const LADDER_NS = [1, 3, 5, 8, 10, 12]
const MAX_OPTIONS = 3

const TIPS = {
	"heavier": ["Warm up in three jumps, then one top set before your usual sets.", "Do it first, right after warm-ups, while you're fresh.",
		"Set the safeties or get a spotter, then commit to it.", "Small jump, big win: the lightest plates you have count."],
	"reps": ["Rest a full 2 to 3 minutes before that set.", "Make it your first working set, while you're fresh.",
		"The last two reps are the set: slow down, don't stop.", "Count the target out loud before you start."],
	"ladder": ["Work up in small jumps, a few reps at a time, then go for it.", "Try it as a top set, then drop back to your usual weight.",
		"Pick the number before you start, and stop there.", "A heavier set for fewer reps: it builds the strength your usual sets use."],
	"set_reps": ["Rest a full 3 minutes before the big set.", "Do it as your first set."],
	"day_reps": ["Add a set, or shave the rest between sets.", "Spread them over more sets: every rep counts."],
	"band": ["Try the heavier band on your first set only.", "Slow the way back: it makes every rep count."],
	"hold": ["Breathe slow and count it out.", "Do the long one first."],
}


## The menu for `lift_name` from its `history` (the days BEFORE today, newest first: [{date, sets}]).
## `step_kg`: the weight step (2.5 kg, or 5 lb in kg). `fmt_w`: Callable(kg) -> "62.5 kg". Empty for a lift
## never done.
static func options(lift_name: String, history: Array, today: String, step_kg: float, fmt_w: Callable) -> Array:
	var days = []
	for h in history:
		if not LiftTrend.real_sets(h.get("sets", [])).is_empty():
			days.append(h)
	if days.is_empty():
		return []
	var seed = absi(("%s|%s" % [today, Xp.normalize_exercise(lift_name)]).hash())
	var mode = LiftProgress.mode_of_sets(days[0].get("sets", []))
	match mode:
		"kg":
			return _weighted(days, seed, step_kg, fmt_w)
		"bw":
			return _bodyweight(days, seed)
		"band":
			return _banded(days, seed)
		"sec":
			return _held(days, seed)
	return []


static func _tip(type: String, seed: int) -> String:
	var list = TIPS.get(type, [])
	return str(list[seed % list.size()]) if not list.is_empty() else ""


static func _weighted(days: Array, seed: int, step_kg: float, fmt_w: Callable) -> Array:
	var best = LiftProgress.best_reps(days)  # heaviest first: {rung, reps, date}
	if best.is_empty():
		return []
	var top_kg = float(best[0].rung)
	var reps_at_top = int(best[0].reps)
	var out = []
	# Heavier than ever.
	var hk = top_kg + step_kg
	var hr = clampi(reps_at_top - 2, 1, 8) if reps_at_top >= 3 else maxi(1, reps_at_top)
	out.append({"type": "heavier", "kind": "weight", "kg": hk, "reps": hr, "title": "Heavier than ever",
		"words": "%s × %d" % [str(fmt_w.call(hk)), hr], "sub": "Your heaviest: %s × %d" % [str(fmt_w.call(top_kg)), reps_at_top],
		"chip": "%s × %d" % [_num(fmt_w, hk), hr], "tip": _tip("heavier", seed)})
	# A rep record at a working weight (the newest day's top weight, or one of the heaviest few, by the date).
	var newest_top = LiftProgress.key(days[0].get("sets", [])).rung
	var picks = best.filter(func(b): return int(b.reps) >= 3 and int(b.reps) < 30 and float(b.rung) >= top_kg * 0.7 - 1e-6)
	if picks.is_empty():
		picks = best.slice(0, 1)
	picks = picks.slice(0, 3)
	var pi = seed % picks.size()
	# Every other day the weight of the last workout, if it is among them.
	if (seed / 7) % 2 == 0:
		for i in range(picks.size()):
			if absf(float(picks[i].rung) - float(newest_top)) <= 1e-6:
				pi = i
	var rp = picks[pi]
	var rr = int(rp.reps) + 1
	out.append({"type": "reps", "kind": "reps", "kg": float(rp.rung), "reps": rr, "title": "Rep record",
		"words": "%d reps at %s" % [rr, str(fmt_w.call(rp.rung))], "sub": "Most there: %d" % int(rp.reps),
		"chip": "%s × %d" % [_num(fmt_w, float(rp.rung)), rr], "tip": _tip("reps", seed)})
	# The best for N reps: an N the other two do not already ask about.
	var ns = []
	for n in LADDER_NS:
		var kg_n = _ladder_kg(best, n)
		# (only below the heaviest weight: at it or past it, "heavier than ever" already asks)
		if kg_n <= 0.0 or kg_n >= top_kg - 1e-6:
			continue
		var target = kg_n + step_kg
		if absf(target - float(rp.rung)) <= 1e-6 and n <= rr:
			continue
		ns.append({"n": n, "kg": kg_n})
	if not ns.is_empty():
		var pick = ns[(seed / 3) % ns.size()]
		var tk = float(pick.kg) + step_kg
		var n2 = int(pick.n)
		out.append({"type": "ladder", "kind": "weight", "kg": tk, "reps": n2, "title": "Best for %d rep%s" % [n2, "" if n2 == 1 else "s"],
			"words": "%s × %d" % [str(fmt_w.call(tk)), n2], "sub": "Heaviest for %d so far: %s" % [n2, str(fmt_w.call(pick.kg))],
			"chip": "%s × %d" % [_num(fmt_w, tk), n2], "tip": _tip("ladder", seed)})
	elif picks.size() > 1:
		# No ladder rung left to ask about: a rep record at another weight.
		var rp2 = picks[(pi + 1) % picks.size()]
		var rr2 = int(rp2.reps) + 1
		out.append({"type": "reps", "kind": "reps", "kg": float(rp2.rung), "reps": rr2, "title": "Rep record",
			"words": "%d reps at %s" % [rr2, str(fmt_w.call(rp2.rung))], "sub": "Most there: %d" % int(rp2.reps),
			"chip": "%s × %d" % [_num(fmt_w, float(rp2.rung)), rr2], "tip": _tip("reps", seed + 1)})
	return out.slice(0, MAX_OPTIONS)


## The heaviest weight done for n reps or more (0 when never).
static func _ladder_kg(best: Array, n: int) -> float:
	var kg = 0.0
	for b in best:
		if int(b.reps) >= n:
			kg = maxf(kg, float(b.rung))
	return kg


## "62.5" / "135": the number of a weight without its unit (for a short key).
static func _num(fmt_w: Callable, kg: float) -> String:
	return str(fmt_w.call(kg)).get_slice(" ", 0)


static func _bodyweight(days: Array, seed: int) -> Array:
	var best_set = 0
	var best_day = 0
	for h in days:
		var k = LiftProgress.key(h.get("sets", []))
		best_day = maxi(best_day, int(k.reps))
		for one in LiftTrend.real_sets(h.get("sets", [])):
			best_set = maxi(best_set, int(one.reps))
	return [
		{"type": "set_reps", "kind": "reps", "kg": 0.0, "reps": best_set + 1, "title": "Most in one set", "words": "%d reps in a set" % (best_set + 1),
			"sub": "Most so far: %d" % best_set, "chip": "%d in a set" % (best_set + 1), "tip": _tip("set_reps", seed)},
		{"type": "day_reps", "kind": "reps", "kg": 0.0, "reps": best_day + 2, "title": "Most in a day", "words": "%d reps in all" % (best_day + 2),
			"sub": "Most so far: %d" % best_day, "chip": "%d in all" % (best_day + 2), "tip": _tip("day_reps", seed)},
	]


static func _banded(days: Array, seed: int) -> Array:
	var top = 0
	var reps = 0
	for h in days:
		for one in LiftTrend.real_sets(h.get("sets", [])):
			if not Bands.is_band(one):
				continue
			var lv = Bands.level(one.band)
			if lv > top:
				top = lv
				reps = int(one.reps)
			elif lv == top:
				reps = maxi(reps, int(one.reps))
	if top <= 0:
		return []
	var cur = Bands.LADDER[top - 1]
	var out = [{"type": "reps", "kind": "reps", "kg": 0.0, "band": cur, "reps": reps + 1, "title": "Rep record",
		"words": "%d reps with the %s" % [reps + 1, Bands.words(cur)], "sub": "Most with it: %d" % reps, "chip": "%s × %d" % [Bands.name_of(cur), reps + 1], "tip": _tip("reps", seed)}]
	if top < Bands.LADDER.size():
		var nxt = Bands.LADDER[top]
		var nr = maxi(5, reps - 4)
		out.push_front({"type": "band", "kind": "weight", "kg": 0.0, "band": nxt, "reps": nr, "title": "Heavier band",
			"words": "%d reps with the %s" % [nr, Bands.words(nxt)], "sub": "Heaviest so far: %s" % Bands.words(cur), "chip": "%s × %d" % [Bands.name_of(nxt), nr], "tip": _tip("band", seed)})
	return out


static func _held(days: Array, seed: int) -> Array:
	var longest = 0
	for h in days:
		for one in LiftTrend.real_sets(h.get("sets", [])):
			longest = maxi(longest, int(one.get("holdSec", 0)))
	if longest <= 0:
		return []
	return [{"type": "hold", "kind": "weight", "kg": 0.0, "sec": longest + 5, "reps": 1, "title": "Hold longer",
		"words": "Hold %d s" % (longest + 5), "sub": "Longest so far: %d s" % longest, "chip": "%d s" % (longest + 5), "tip": _tip("hold", seed)}]


## Do `sets` (one day's sets of the lift) meet the option?
static func hit(opt: Dictionary, sets: Array) -> bool:
	var real = LiftTrend.real_sets(sets)
	match str(opt.type):
		"heavier", "ladder", "reps":
			if str(opt.get("band", "")) != "":
				var lv = Bands.level(opt.band)
				return real.any(func(one): return Bands.is_band(one) and Bands.level(one.band) >= lv and int(one.reps) >= int(opt.reps))
			return real.any(func(one): return float(one.get("weightKg", 0)) >= float(opt.kg) - 1e-6 and int(one.reps) >= int(opt.reps))
		"band":
			var lv2 = Bands.level(opt.band)
			return real.any(func(one): return Bands.is_band(one) and Bands.level(one.band) >= lv2 and int(one.reps) >= int(opt.reps))
		"set_reps":
			return real.any(func(one): return int(one.reps) >= int(opt.reps))
		"day_reps":
			var total = 0
			for one in real:
				total += int(one.reps)
			return total >= int(opt.reps)
		"hold":
			return real.any(func(one): return int(one.get("holdSec", 0)) >= int(opt.sec))
	return false


## The options met by `sets`, by type.
static func hits(opts: Array, sets: Array) -> Array:
	var out = []
	for o in opts:
		if hit(o, sets):
			out.append(str(o.type))
	return out


## Did `sets` set any record against `before` ([{sets}], the days before): a weight never lifted for reps
## (a heavier top set than ever) or a rep record (LiftProgress.rep_records)?
static func any_record(sets: Array, before: Array) -> bool:
	var real = LiftTrend.real_sets(sets)
	if real.is_empty() or before.is_empty():
		return false
	if not LiftProgress.rep_records(real, before).is_empty():
		return true
	var top = 0.0
	for h in before:
		for one in LiftTrend.real_sets(h.get("sets", [])):
			top = maxf(top, float(one.get("weightKg", 0)))
	return real.any(func(one): return float(one.get("weightKg", 0)) > top + 1e-6) and top > 0.0
