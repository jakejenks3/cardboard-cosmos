class_name Dose
extends RefCounted
## Training focus: how many hard sets a week each muscle group should get, and
## what the last seven days really gave it. Pure logic; the day's plan and the
## missions lean on it (game/missions.gd), the Today card and its sheet show it
## (ui/screens/dose_view.gd). Off unless the player picks a focus
## (settings.focus = a PLANS id; Settings -> Training focus), and with it off
## nothing here changes the plan or a mission.
##
## A week is always the LAST SEVEN DAYS (window), not Monday to Sunday: a dose
## is how much a muscle got lately, and a count that starts again at nothing
## every Monday would call every Monday "short".
##
## What counts as a set for a muscle (the same way the training summary counts
## it, game/dosage.gd):
##   - a set of a lift whose main muscle it is: 1 ("direct");
##   - a set of a lift that also works it (the library's "also works"): half;
##   - a climbing session: CLIMB_SETS, for the forearms ONLY. Climbing is
##     fingers and forearms far more than back (the user, 2026-11-22: "climbing
##     really doesn't work that way, it's way more fingers and much less back"),
##     so it never counts towards the back or the biceps;
##   - physical therapy, stretches and holds-only exercises: nothing.
## A target is [least, most, mode]: "build" (grow it: sets are added when it is
## short) or "keep" (no sets are ever added for it; its number is only shown).
## A kept muscle's lifts still have goals to beat like any other (the user:
## "leg stuff can still have goals to beat, I just don't plan on adding more
## volume").
##
## THE DAY'S PLAN IS MADE FROM THESE TARGETS (the user, 2026-11-22: "You
## planned out sets of volume for those areas based on my priorities and was
## that ignored for this?... the plan should go based off that"). Each muscle
## being built has a SHARE to get on a day that trains it (day_target): its
## weekly least divided by how many days a week it is trained (freq_of), more
## when the week is behind, never past its weekly most. The day's usual lifts
## are counted against that share (day_dose says what the day gives each
## muscle and where the week then stands), and what is missing is ADDED
## (extras): on a day whose kind trains a muscle being built that the day's
## usual lifts leave short of its share, one more movement for it, with several to pick from for whatever equipment is there.
## A muscle with an ANCHOR (the chest's press) gets that first when no lift of
## that sort was done in ANCHOR_DAYS: flyes alone never load the chest much.

const DAYS = 7
## Sets a climbing session is worth: the forearms (fingers) only, see the top.
const CLIMB_SETS = {"forearms": 4.0}
## A rest day (a rest from lifting) is due after this many lifting days in a row.
const REST_AFTER = 5
const ANCHOR_DAYS = 14
## The days looked at for how often a muscle is trained, and the most sets a
## day is asked to give one muscle.
const FREQ_LOOK = 14
const DAY_CAP = 8.0
## Extra lifts a day's plan may get, and the sets one asks for.
const EXTRA_LIFTS = 2
const EXTRA_MIN = 3
const EXTRA_MAX = 5
## The weekly run grows by this much when the last one was RUN_SAME_AFTER days
## ago or less; after a longer gap it is the same distance again, and after
## RUN_BACK_AFTER days RUN_BACK of it (coming back from a break or an injury).
const RUN_UP = 1.1
const RUN_SAME_AFTER = 10
const RUN_BACK_AFTER = 21
const RUN_BACK = 0.8
## The pace goal counts over at least this share of the last run's distance.
const RUN_PACE_SHARE = 0.75
## How far back runs are looked at to find the run day.
const RUN_DAY_LOOK = 56

const PARTS = ["chest", "back", "shoulders", "biceps", "triceps", "forearms", "core", "quads", "hamstrings", "glutes", "calves"]
const PLANS = {
	"upper": {"name": "Upper body first", "blurb": "Build chest, back, shoulders and arms. Legs keep the volume they have: no sets are added, their lifts still have goals to beat.",
		"targets": {"chest": [10, 16, "build"], "back": [10, 20, "build"], "shoulders": [8, 16, "build"], "biceps": [8, 16, "build"], "triceps": [8, 16, "build"],
			"forearms": [4, 16, "keep"], "core": [3, 10, "keep"], "quads": [4, 10, "keep"], "hamstrings": [3, 10, "keep"], "glutes": [2, 10, "keep"], "calves": [3, 10, "keep"]}},
	"balanced": {"name": "Whole body", "blurb": "Build everything evenly, legs as much as the upper body.",
		"targets": {"chest": [10, 16, "build"], "back": [10, 20, "build"], "shoulders": [8, 16, "build"], "biceps": [8, 16, "build"], "triceps": [8, 16, "build"],
			"forearms": [0, 16, "keep"], "core": [4, 12, "keep"], "quads": [8, 16, "build"], "hamstrings": [6, 14, "build"], "glutes": [4, 14, "build"], "calves": [6, 14, "build"]}},
}
const ORDER = ["upper", "balanced"]

## The lift a muscle should not go without, and what to offer for it (one per
## sort of equipment, the heaviest to load first).
const ANCHORS = {
	"chest": {"what": "a press", "word": "press", "why": "A press loads the chest far heavier than flyes can.",
		"moves": ["Bench Press", "Push-up", "Dip"],
		"offer": ["Bench Press - Barbell", "Bench Press - Incline dumbbell", "Bench Press - Machine", "Push-up - Weighted", "Dip"]},
}


static func plan_id(settings: Dictionary) -> String:
	var id = str(settings.get("focus", ""))
	return id if PLANS.has(id) else ""


## The focus the player picked ({"name", "blurb", "targets"}), or null.
static func plan_of(settings: Dictionary):
	return PLANS.get(plan_id(settings))


## Is the weekly run being built up? On with a focus unless switched off.
static func run_on(settings: Dictionary) -> bool:
	return plan_id(settings) != "" and bool(settings.get("runGoal", true))


## "build", "keep" or "" (no focus, or a lift no target covers) for a lift.
static func mode_of(settings: Dictionary, lift_name: String) -> String:
	var plan = plan_of(settings)
	if plan == null:
		return ""
	var t = plan.targets.get(Dosage.part(lift_name))
	return str(t[2]) if t != null else ""


static func part_name(part: String) -> String:
	return str(Recovery.NAMES.get(part, part.capitalize()))


static func _mk(lift_name: String) -> String:
	return Xp.normalize_exercise(str(LiftNames.split(lift_name).move))


## Add what `n` sets of a lift give each muscle to `into` ({part: sets}).
static func add_lift(into: Dictionary, lift_name: String, n: float, also_into = null) -> void:
	var p = Dosage.part(lift_name)
	if PARTS.has(p):
		into[p] = float(into.get(p, 0.0)) + n
	var side = into if also_into == null else also_into
	for a in Recovery.also_parts(lift_name):
		if a != p and PARTS.has(a):
			side[a] = float(side.get(a, 0.0)) + n * 0.5


## What the `days` days ending on `today` gave each muscle:
## {"from", "to", "focus", "parts": {part: {"direct", "indirect", "climb",
##  "total", "min", "max", "mode" ("" without a target), "state"}}}.
## state: "short" (under the least), "ok", "plenty" (over the most), "" (no target).
static func window(sessions: Array, marks: Dictionary, settings: Dictionary, today: String, days: int = DAYS) -> Dictionary:
	var from = Dates.add_days(today, -(days - 1))
	var direct = {}
	var indirect = {}
	var climb = {}
	for s in sessions:
		var d = str(s.get("date", ""))
		if d < from or d > today:
			continue
		var disc = str(s.get("discipline", ""))
		if disc == "lift":
			for ex in s.get("exercises", []):
				var n = LiftTrend.real_sets(ex.get("sets", [])).size()
				if n == 0 or Dosage.is_mobility(ex, marks):
					continue
				add_lift(direct, str(ex.get("name", "")), float(n), indirect)
		elif disc == "climb":
			for p in CLIMB_SETS:
				climb[p] = float(climb.get(p, 0.0)) + float(CLIMB_SETS[p])
	var plan = plan_of(settings)
	var parts = {}
	for p in PARTS:
		var r = {"direct": float(direct.get(p, 0.0)), "indirect": float(indirect.get(p, 0.0)), "climb": float(climb.get(p, 0.0)), "min": 0.0, "max": 0.0, "mode": "", "state": ""}
		r["total"] = float(r.direct) + float(r.indirect) + float(r.climb)
		var t = plan.targets.get(p) if plan != null else null
		if t != null:
			r.min = float(t[0])
			r.max = float(t[1])
			r.mode = str(t[2])
			r.state = "short" if float(r.total) < float(r.min) - 0.01 else ("plenty" if float(r.total) > float(r.max) + 0.01 else "ok")
		parts[p] = r
	return {"from": from, "to": today, "focus": plan_id(settings), "parts": parts}


## The muscles the focus builds.
static func build_parts(settings: Dictionary) -> Array:
	var plan = plan_of(settings)
	if plan == null:
		return []
	return PARTS.filter(func(p): return plan.targets.has(p) and str(plan.targets[p][2]) == "build")


## How many of the muscles being built have their sets in the seven days ending on `day`.
static func on_target(sessions: Array, marks: Dictionary, settings: Dictionary, day: String) -> int:
	var w = window(sessions, marks, settings, day)
	return build_parts(settings).filter(func(p): return str(w.parts[p].state) != "short").size()


## The muscles a day of this kind (a split's), or of this body area, trains.
static func parts_today(kind: String, group: String) -> Array:
	var out = []
	if kind != "":
		for k in Missions.KIND_PARTS:
			if Missions.fits(str(k), kind):
				out.append_array(Missions.KIND_PARTS[k])
	elif group != "":
		for p in PARTS:
			if str(Missions.GROUP.get(p, "")) == group:
				out.append(p)
	return out


## Was a lift of one of these movements done from `from` up to (not on) `before`?
static func moves_done(sessions: Array, moves: Array, from: String, before: String) -> bool:
	var keys = moves.map(func(m): return Xp.normalize_exercise(str(m)))
	for s in sessions:
		var d = str(s.get("date", ""))
		if str(s.get("discipline", "")) != "lift" or d < from or d >= before:
			continue
		for ex in s.get("exercises", []):
			if keys.has(_mk(str(ex.get("name", "")))) and not LiftTrend.real_sets(ex.get("sets", [])).is_empty():
				return true
	return false


static func _option(st) -> Dictionary:
	var sp = LiftNames.split(str(st.name))
	return {"name": str(st.name), "move": str(sp.move), "variation": str(sp.variation), "new": false, "last": st.history[0].sets, "lastDate": str(st.last)}


static func _new_option(lift_name: String) -> Dictionary:
	var sp = LiftNames.split(lift_name)
	return {"name": lift_name, "move": str(sp.move), "variation": str(sp.variation), "new": true, "last": [], "lastDate": ""}


static func _latest_first(list: Array) -> void:
	TTUtil.stable_sort(list, func(a, b):
		if str(a.last) != str(b.last):
			return str(a.last) > str(b.last)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)


## The ways to do a muscle's anchor: the player's own lifts of that sort (the
## latest first), then the library's, one per sort of equipment.
static func anchor_options(anchor: Dictionary, hist: Dictionary, taken: Array) -> Array:
	var keys = anchor.moves.map(func(m): return Xp.normalize_exercise(str(m)))
	var own = []
	for k in hist:
		var mk = _mk(str(hist[k].name))
		if keys.has(mk) and not taken.has(mk):
			own.append(hist[k])
	_latest_first(own)
	var out = []
	for st in own.slice(0, 3):
		out.append(_option(st))
	for n in anchor.offer:
		if out.size() >= 5:
			break
		if taken.has(_mk(str(n))) or out.any(func(o): return Xp.normalize_exercise(str(o.name)) == Xp.normalize_exercise(str(n))):
			continue
		out.append(_new_option(str(n)))
	return out


## Other movements for a muscle, not in the day's plan: the player's own of the
## day's kind (one per movement, the latest first), then the library's staples
## never done.
static func more_options(part: String, hist: Dictionary, taken: Array, kind: String, marks: Dictionary) -> Array:
	var fit = func(n: String): return kind == "" or Missions.fits(Missions.kind_of(n), kind)
	var by_move = {}
	for k in hist:
		var n = str(hist[k].name)
		var mk = _mk(n)
		if Dosage.part(n) != part or taken.has(mk) or Pt.is_pt(marks, n) or n.to_lower().contains("stretch") or not fit.call(n):
			continue
		if not by_move.has(mk) or str(hist[k].last) > str(by_move[mk].last):
			by_move[mk] = hist[k]
	var own = by_move.values()
	_latest_first(own)
	var out = []
	for st in own.slice(0, 3):
		out.append(_option(st))
	var done = {}
	for k in hist:
		done[_mk(str(hist[k].name))] = true
	for name in Missions.STAPLES.get(str(Missions.GROUP.get(part, "")), []):
		if out.size() >= 4:
			break
		var e = LiftNames.movement(str(name))
		if e == null or str(e.part) != part:
			continue
		var mk = Xp.normalize_exercise(str(e.name))
		if done.has(mk) or taken.has(mk) or not fit.call(str(e.name)):
			continue
		out.append(_new_option(LiftNames.join(str(e.name), Missions.variation_for(e))))
	return out


## How many days a week the muscle gets direct work: the FREQ_LOOK days before
## `today` (or as many as the log has, a week at least), 1 to 3.
static func freq_of(before: Array, today: String, part: String, marks: Dictionary) -> float:
	var from = Dates.add_days(today, -FREQ_LOOK)
	var first = today
	var days = {}
	for s in before:
		var d = str(s.get("date", ""))
		if d == "" or d >= today:
			continue
		if d < first:
			first = d
		if d < from or str(s.get("discipline", "")) != "lift":
			continue
		for ex in s.get("exercises", []):
			if LiftTrend.real_sets(ex.get("sets", [])).is_empty() or Dosage.is_mobility(ex, marks):
				continue
			if Dosage.part(str(ex.get("name", ""))) == part:
				days[d] = true
	var span = float(clampi(Dates.days_between(first if first > from else from, today), 7, FREQ_LOOK))
	return clampf(days.size() / (span / 7.0), 1.0, 3.0)


## The sets a muscle should get today: its share of the weekly least (`t` =
## [least, most, mode]) for a muscle trained `freq` days a week, or what the
## week still lacks when that is more; never more than keeps the week within
## its most, and never more than DAY_CAP. `have`: its sets in the six days before.
static func day_target(t: Array, have: float, freq: float) -> float:
	var share = ceilf(float(t[0]) / maxf(1.0, freq))
	var want = maxf(share, float(t[0]) - have)
	return clampf(want, 0.0, maxf(0.0, minf(float(t[1]) - have, DAY_CAP)))


## The sets a planned lift counts for today: an extra lift what it asks for,
## any other what it was done for last time. 0 for physical therapy and stretches.
static func planned_sets(l: Dictionary, marks: Dictionary) -> int:
	if bool(l.get("pt", false)):
		return 0
	if l.has("dose"):
		return int(l.dose.sets)
	if Dosage.is_mobility({"name": str(l.name), "sets": l.last.sets}, marks):
		return 0
	return LiftTrend.real_sets(l.last.sets).size()


## What a day's plan gives each muscle of the day, and where the week then
## stands: [{"part", "have" (its sets in the six days before), "today" (the
## sets the plan gives it: a lift's sets for its main muscle, half for one it
## also works), "share" (day_target; 0 for a kept muscle), "after" (have +
## today), "min", "max", "mode", "state" (of "after")}], in PARTS order.
## `lifts`: the whole plan (the extras among them).
static func day_dose(lifts: Array, before: Array, today: String, marks: Dictionary, settings: Dictionary, kind: String, group: String) -> Array:
	var plan = plan_of(settings)
	if plan == null:
		return []
	var w = window(before, marks, settings, Dates.add_days(today, -1), DAYS - 1)
	var cover = {}
	for l in lifts:
		var n = planned_sets(l, marks)
		if n > 0:
			add_lift(cover, str(l.name), float(n))
	var out = []
	for p in parts_today(kind, group):
		var t = plan.targets.get(p)
		if t == null:
			continue
		var have = float(w.parts[p].total)
		var gives = float(cover.get(p, 0.0))
		var after = have + gives
		out.append({"part": p, "have": have, "today": gives, "after": after, "min": float(t[0]), "max": float(t[1]), "mode": str(t[2]),
			"share": day_target(t, have, freq_of(before, today, p, marks)) if str(t[2]) == "build" else 0.0,
			"state": "short" if after < float(t[0]) - 0.01 else ("plenty" if after > float(t[1]) + 0.01 else "ok")})
	return out


## The extra lifts of a day (see the top), shaped like Missions.likely_lifts
## rows with "options" and "dose": {"part", "sets", "have" (the six days
## before), "cover" (what the day's own lifts will add), "share" (day_target),
## "need" (what of the share is still missing after those), "min", "mode",
## "anchor" (bool), "moves" (an anchor's movements, normalized)}.
## `lifts`: the day's likely lifts; `hist`: LiftLibrary.stats of the log before
## the day; `taken`: normalized movements already in the plan.
static func extras(lifts: Array, before: Array, today: String, marks: Dictionary, settings: Dictionary, kind: String, group: String, hist: Dictionary, taken_in: Array) -> Array:
	var plan = plan_of(settings)
	var todays = parts_today(kind, group)
	if plan == null or todays.is_empty():
		return []
	var w = window(before, marks, settings, Dates.add_days(today, -1), DAYS - 1)
	var cover = {}
	var planned = {}
	for l in lifts:
		if bool(l.pt) or Dosage.is_mobility({"name": str(l.name), "sets": l.last.sets}, marks):
			continue
		add_lift(cover, str(l.name), float(LiftTrend.real_sets(l.last.sets).size()))
		planned[_mk(str(l.name))] = true
	var taken = taken_in.duplicate()
	var out = []
	for p in PARTS:
		if out.size() >= EXTRA_LIFTS:
			break
		var t = plan.targets.get(p)
		# Only a muscle being built gets more: a kept one is left as it is.
		if t == null or not todays.has(p) or str(t[2]) != "build":
			continue
		var have = float(w.parts[p].total)
		var share = day_target(t, have, freq_of(before, today, p, marks))
		var need = share - float(cover.get(p, 0.0))
		var anchor = ANCHORS.get(p)
		var missing = false
		if anchor != null:
			var keys = anchor.moves.map(func(m): return Xp.normalize_exercise(str(m)))
			missing = not keys.any(func(k): return planned.has(k)) and not moves_done(before, anchor.moves, Dates.add_days(today, -ANCHOR_DAYS), today)
		if need < 1.0 and not missing:
			continue
		# (never a lift that would take the week past the muscle's most)
		if not missing and have + float(cover.get(p, 0.0)) + EXTRA_MIN > float(t[1]) + 0.01:
			continue
		var opts = anchor_options(anchor, hist, taken) if missing else more_options(p, hist, taken, kind, marks)
		if opts.is_empty():
			continue
		var n = clampi(int(ceil(need)), EXTRA_MIN, EXTRA_MAX)
		var first = opts[0]
		# The row's line (its tag names the muscle); the mission says more.
		var why = "%s of %s sets in 7 days" % [Dosage._n(have), Dosage._n(float(t[0]))]
		if have >= float(t[0]):
			why = "To stay at %s sets a week" % Dosage._n(float(t[0]))
		if missing:
			why = "No %s in two weeks" % str(anchor.word) if need < 1.0 else why + ", no %s" % str(anchor.word)
		out.append({"name": str(first.name), "score": 0.0, "why": why, "part": p, "pt": false, "kind": Missions.kind_of(str(first.name)), "variations": [str(first.name)],
			"last": {"date": str(first.lastDate), "sets": first.last}, "since": -1, "gap": 0.0, "same": 0, "options": opts,
			"dose": {"part": p, "sets": n, "have": have, "cover": float(cover.get(p, 0.0)), "share": share, "need": need, "min": float(t[0]), "mode": str(t[2]), "anchor": missing,
				"moves": anchor.moves.map(func(m): return Xp.normalize_exercise(str(m))) if missing else []}})
		add_lift(cover, str(first.name), float(n))
		for o in opts:
			if not taken.has(_mk(str(o.name))):
				taken.append(_mk(str(o.name)))
	return out


## What was done on `date` that counts for an extra lift `l`: {"sets", "name"
## (the first lift that counted, or "")}. For an anchor, any lift of its sort;
## otherwise one of its options, another variation of the first one's
## movement, or (`same`) a movement standing in for it.
static func extra_done(l: Dictionary, sessions: Array, date: String, same: Dictionary = {}) -> Dictionary:
	var d = l.get("dose", {})
	var keys = l.get("options", []).map(func(o): return Xp.normalize_exercise(str(o.name)))
	var mk = _mk(str(l.name))
	var n = 0
	var first = ""
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != date:
			continue
		for ex in s.get("exercises", []):
			var name = str(ex.get("name", ""))
			var sets = LiftTrend.real_sets(ex.get("sets", [])).size()
			if sets == 0:
				continue
			var counts = d.moves.has(_mk(name)) if bool(d.get("anchor", false)) else (keys.has(Xp.normalize_exercise(name)) or _mk(name) == mk or Missions.stands_in(name, same))
			if counts:
				n += sets
				if first == "":
					first = name
	return {"sets": n, "name": first}


# ---------------------------------------------------------------------------
# Rest and the weekly run
# ---------------------------------------------------------------------------

## Is a session strength work: a lift with more in it than physical therapy
## and stretches. A REST DAY IS A REST FROM LIFTING (the user, 2026-11-23:
## "use today as rest day from strength, so I'll still run and do PT"): a run,
## a ride, a climb, a walk, PT and stretches are all fine on one, and a day
## with only those is a day off in the count of lifting days in a row. (Until
## then any climb, run or ride counted as a hard day too.)
static func is_hard(s: Dictionary, marks: Dictionary) -> bool:
	if str(s.get("discipline", "")) != "lift":
		return false
	for ex in s.get("exercises", []):
		if not LiftTrend.real_sets(ex.get("sets", [])).is_empty() and not Dosage.is_mobility(ex, marks):
			return true
	return false


## Was there strength work on `date`?
static func hard_on(sessions: Array, marks: Dictionary, date: String) -> bool:
	return sessions.any(func(s): return str(s.get("date", "")) == date and is_hard(s, marks))


## {"run": lifting days in a row up to `today` (today's own counts once it has
## one), "today": strength work is logged today, "due": a rest day is due
## today by the count (REST_AFTER in a row before it, and no lifting yet)}.
## The player's own call for a day comes on top (Missions.day_plan: `off`).
static func rest(sessions: Array, marks: Dictionary, today: String) -> Dictionary:
	var days = {}
	for s in sessions:
		var d = str(s.get("date", ""))
		if d <= today and d >= Dates.add_days(today, -60) and is_hard(s, marks):
			days[d] = true
	var trained = days.has(today)
	var day = today if trained else Dates.add_days(today, -1)
	var run = 0
	while days.has(day):
		run += 1
		day = Dates.add_days(day, -1)
	return {"run": run, "today": trained, "due": run >= REST_AFTER and not trained}


## What the next run should be, from the last one before `ref`:
## {"targetM", "lastM", "lastDate", "gap" (days), "step": "up" | "same" | "back"},
## or null without a run to go by. Rounded to a tenth of the player's unit.
static func run_goal(sessions: Array, ref: String, du: String):
	var last = null
	for s in sessions:
		if str(s.get("discipline", "")) != "run" or str(s.get("date", "")) >= ref or float(s.get("distanceM", 0.0)) <= 0.0:
			continue
		if last == null or str(s.date) > str(last.date) or (str(s.date) == str(last.date) and float(s.distanceM) > float(last.distanceM)):
			last = s
	if last == null:
		return null
	var gap = Dates.days_between(str(last.date), ref)
	var step = "up" if gap <= RUN_SAME_AFTER else ("same" if gap <= RUN_BACK_AFTER else "back")
	var factor = RUN_UP if step == "up" else (1.0 if step == "same" else RUN_BACK)
	var unit_m = 1609.344 if du == "mi" else 1000.0
	var target = roundf(float(last.distanceM) * factor / unit_m * 10.0) / 10.0 * unit_m
	# The other goal, speed: last time's pace (seconds a km; 0 when its time was
	# not logged) over at least RUN_PACE_SHARE of its distance.
	var secs = float(last.get("durationSec", 0))
	var pace = secs / (float(last.distanceM) / 1000.0) if secs > 0.0 else 0.0
	var least = maxf(unit_m, roundf(float(last.distanceM) * RUN_PACE_SHARE / unit_m * 10.0) / 10.0 * unit_m)
	return {"targetM": target, "lastM": float(last.distanceM), "lastDate": str(last.date), "gap": gap, "step": step, "paceSec": pace, "paceM": least}


## Does a run beat the pace goal of `g` (run_goal): far enough, timed, quicker?
static func run_quick(s: Dictionary, g: Dictionary) -> bool:
	var m = float(s.get("distanceM", 0.0))
	var secs = float(s.get("durationSec", 0))
	if float(g.get("paceSec", 0.0)) <= 0.0 or secs <= 0.0 or m < float(g.paceM) - 1.0:
		return false
	return secs / (m / 1000.0) < float(g.paceSec)


## The weekday of the weekly run (0 = Monday ... 6 = Sunday): the one the
## player picked (settings.runDay, 0 to 6), else the weekday most of their runs
## of the RUN_DAY_LOOK days before `today` were on (the latest on a tie), else
## -1. Run goals show on that day ONLY (the user, 2026-11-22: "make sure run
## goals only show up on Monday... I specially will only run Mondays").
static func run_day(sessions: Array, settings: Dictionary, today: String) -> int:
	var picked = settings.get("runDay")
	if (picked is int or picked is float) and int(picked) >= 0 and int(picked) <= 6:
		return int(picked)
	var count = {}
	var last_of = {}
	var from = Dates.add_days(today, -RUN_DAY_LOOK)
	for s in sessions:
		var d = str(s.get("date", ""))
		if str(s.get("discipline", "")) != "run" or d >= today or d < from:
			continue
		var w = Dates.weekday_index(d)
		count[w] = int(count.get(w, 0)) + 1
		if not last_of.has(w) or d > str(last_of[w]):
			last_of[w] = d
	var best = -1
	for w in count:
		if best < 0 or int(count[w]) > int(count[best]) or (int(count[w]) == int(count[best]) and str(last_of[w]) > str(last_of[best])):
			best = w
	return best


const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


## A run goal in a few words: "10% further than Nov 16 (3.3 mi)".
static func run_why(g: Dictionary, du: String) -> String:
	var was = "%s (%s)" % [Dates.format_date(str(g.lastDate), {"month": "short", "day": "numeric"}), Fmt.fmt_distance(float(g.lastM), du)]
	match str(g.step):
		"up":
			return "10%% further than %s" % was
		"same":
			return "The same as %s: it has been a while" % was
	return "Shorter than %s: easing back in" % was
