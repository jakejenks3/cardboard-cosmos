class_name Missions
extends RefCounted
## Daily and weekly missions made from the player's own log. They replace the
## ported Quests in the game (game/quests.gd stays, pinned by the parity test).
##
## A day starts with a PLAN, worked out from the log before that day only, so
## it does not move while the day is logged:
##   likely_lifts(sessions, today, marks)   the lifts probably done today: the ones
##                                           done on this weekday before, or due by
##                                           their usual gap
##   day_plan(sessions, today, marks, split, pick)
##                                           those lifts, the body area of the day
##                                           ("Back day"), a movement of that area
##                                           never done, the PT still to do this week
##                                           and the other activities likely today
## With a training SPLIT (settings.split: "pull_push_legs", "push_pull_legs",
## "upper_lower"; "auto" = none) the day's kind comes from the split: the one
## after the kind of the last lift day ("Push day" after a pull day), or the
## player's pick for today (settings.dayPick = {date, kind}). Only that kind's
## lifts are planned (forearms, core and stretches go with any day). Without a
## split the day is named after its likeliest lifts. Either way a lift done
## recently for its rhythm (under half its usual gap, and no weekday habit) is
## left to rest: one Saturday squat does not make a squat due two days after the
## last one.
## A planned lift is a MOVEMENT (likely_lifts joins its variations; a PT lift
## stays on its own). Its ways (options_for) are how the player has done it:
## each variation they logged, the latest first, each with its own aim ("Home
## cable" and "Gym cable" are different lifts), and one other movement of the
## same part they have done. Its "Beat it" mission is done by any of them, or
## by any variation of the movement, beaten or done for the first time
## (beat_any): a variation written the first time counts.

## How far back a pattern is looked for.
const LOOKBACK = 42
## Lifts in a day's plan.
const PLAN_LIFTS = 5
## "Beat last time" missions a day.
const BEAT_MISSIONS = 2

## The body areas a day is named after.
const GROUP = {"back": "back", "chest": "chest", "shoulders": "shoulders", "biceps": "arms", "triceps": "arms",
	"forearms": "arms", "quads": "legs", "hamstrings": "legs", "glutes": "legs", "calves": "legs", "core": "core", "full": "full"}
const GROUP_NAMES = {"back": "Back day", "chest": "Chest day", "shoulders": "Shoulder day", "arms": "Arm day",
	"legs": "Leg day", "core": "Core day", "full": "Full body day"}
const OTHER = ["climb", "run", "ride", "misc"]

## The kinds of day in a split and the body parts that make each one. Forearms,
## core, mobility and full-body work belong to none: they go with any day.
const KIND_PARTS = {"pull": ["back", "biceps"], "push": ["chest", "shoulders", "triceps"],
	"legs": ["quads", "hamstrings", "glutes", "calves"]}
## Shoulder movements that pull (a pull day's).
const PULL_SHOULDERS = ["Rear Delt Fly", "Face Pull", "Upright Row", "Pull-Apart"]
## A split's kinds may also be "upper" (pull and push) and "lower" (legs).
const KIND_NAMES = {"pull": "Pull day", "push": "Push day", "legs": "Leg day", "upper": "Upper body day", "lower": "Leg day"}
const KIND_SHORT = {"pull": "Pull", "push": "Push", "legs": "Legs", "upper": "Upper", "lower": "Lower"}
## The body areas a "try something new" of that kind comes from (STAPLES keys).
const KIND_GROUPS = {"pull": ["back", "arms"], "push": ["chest", "shoulders", "arms"], "legs": ["legs"],
	"upper": ["back", "chest", "shoulders", "arms"], "lower": ["legs"]}
## The splits a player can pick (Settings -> Training split). "auto": none.
const SPLITS = [
	{"id": "auto", "name": "From my log", "cycle": []},
	{"id": "pull_push_legs", "name": "Pull, push, legs", "cycle": ["pull", "push", "legs"]},
	{"id": "push_pull_legs", "name": "Push, pull, legs", "cycle": ["push", "pull", "legs"]},
	{"id": "upper_lower", "name": "Upper, lower", "cycle": ["upper", "lower"]},
]
## A lift done under this share of its usual gap ago rests (see the top).
const REST = 0.5
## How the player feels (settings.feels = {date: 1 tired, 2 okay, 3 strong};
## from the morning push's buttons, the phone logger or the Today card).
## A tired day, or a day of a lighter week (settings.deloadUntil), makes the
## Beat it missions easy days: about EASY_SHARE of last time's weight, and
## any way of the lift done counts. A strong day aims one step further.
const EASY_SHARE = 0.9


static func feel_of(settings: Dictionary, date: String) -> int:
	var f = settings.get("feels", {})
	return int(f.get(date, 0)) if f is Dictionary else 0


## Is `date` an easy day (tired, or in a lighter week)?
static func easy_day(settings: Dictionary, date: String) -> bool:
	return feel_of(settings, date) == 1 or str(settings.get("deloadUntil", "")) >= date


## Tired on two of the last three days (up to `date`): offer a lighter week.
static func lighter_week_due(settings: Dictionary, date: String) -> bool:
	if str(settings.get("deloadUntil", "")) >= date:
		return false
	var n = 0
	for k in range(3):
		if feel_of(settings, Dates.add_days(date, -k)) == 1:
			n += 1
	return n >= 2


## Last time's sets about EASY_SHARE lighter (rounded to the step); a set
## without weight keeps its reps.
static func easy_sets(sets: Array, step_kg: float) -> Array:
	var out = []
	for one in LiftTrend.real_sets(sets):
		var s = one.duplicate()
		var w = float(one.get("weightKg", 0.0))
		if w > 0.0:
			s["weightKg"] = maxf(step_kg, roundf(w * EASY_SHARE / step_kg) * step_kg)
		out.append(s)
	return out


## Split combos: lift days this week in the split's order. {"now" (the chain
## ending at the latest lift day), "best" (the longest this week), "kinds"
## (the week's lift days' kinds, in order)}. The week runs Monday to `today`.
static func combo(sessions: Array, today: String, cycle: Array, marks: Dictionary = {}) -> Dictionary:
	var out = {"now": 0, "best": 0, "kinds": []}
	if cycle.is_empty():
		return out
	var wk = Dates.week_key(today)
	var by_day = {}
	for s in sessions:
		var d = str(s.get("date", ""))
		if str(s.get("discipline", "")) == "lift" and d <= today and Dates.week_key(d) == wk:
			if not by_day.has(d):
				by_day[d] = []
			by_day[d].append_array(s.get("exercises", []))
	var days = by_day.keys()
	days.sort()
	var prev = ""
	var run = 0
	for d in days:
		var k = kind_of_day(by_day[d], cycle, marks)
		if k == "":
			continue
		out.kinds.append(k)
		run = run + 1 if prev != "" and cycle[(cycle.find(prev) + 1) % cycle.size()] == k else 1
		prev = k
		out.best = maxi(int(out.best), run)
	out.now = run
	return out


## What a perfect day pays (every box of the Today card ticked).
const PERFECT_XP = 300
## Ways shown to do one planned lift (its variations and one other movement).
const OPTIONS = 4
## Other movements offered beside the one to try (other equipment first).
const NEW_ALTS = 2
## Good first picks for "try something new", most useful first. Movements not
## listed (or not in the library) come after these, in library order.
const STAPLES = {
	"back": ["Lat Pulldown", "Seated Row", "Pull-up", "Chin-up", "Chest-Supported Row", "T-Bar Row", "Bent Over Row", "Straight-Arm Pulldown", "Back Extension", "Inverted Row"],
	"chest": ["Bench Press", "Push-up", "Chest Fly", "Dip"],
	"shoulders": ["Overhead Press", "Lateral Raise", "Rear Delt Fly", "Face Pull", "Arnold Press", "Upright Row"],
	"arms": ["Bicep Curl", "Hammer Curl", "Tricep Pushdown", "Tricep Extension", "Preacher Curl", "Tricep Kickback"],
	"legs": ["Squat", "Romanian Deadlift", "Leg Press", "Lunge", "Hip Thrust", "Leg Curl", "Leg Extension", "Bulgarian Split Squat", "Calf Raise"],
	"core": ["Plank", "Hanging Leg Raise", "Cable Crunch", "Ab Wheel", "Pallof Press", "Dead Bug"],
}


# ---------------------------------------------------------------------------
# The plan
# ---------------------------------------------------------------------------

## The body part of a lift ("back"), from the library or guessed from its name.
static func part_of(lift_name: String) -> String:
	var mv = str(LiftNames.split(lift_name).move)
	var m = LiftNames.movement(mv)
	if m != null:
		return str(m.part)
	return LiftLibrary.guess_part(Xp.normalize_exercise(mv))


## The kind of day a lift belongs to: "pull", "push", "legs", or "" (any day).
static func kind_of(lift_name: String) -> String:
	var part = part_of(lift_name)
	if part == "shoulders" and PULL_SHOULDERS.has(str(LiftNames.split(lift_name).move)):
		return "pull"
	for k in KIND_PARTS:
		if KIND_PARTS[k].has(part):
			return k
	return ""


## The hero's pose for a lift in the workout replay: "press" (push), "curl"
## (biceps, forearms), "pull", "squat" (legs) or "flex" (anything else).
static func pose_of(lift_name: String) -> String:
	var part = part_of(lift_name)
	if part == "biceps" or part == "forearms":
		return "curl"
	match kind_of(lift_name):
		"push":
			return "press"
		"pull":
			return "pull"
		"legs":
			return "squat"
	return "flex"


## Does a lift of kind `lift_kind` belong on a day of kind `day_kind`?
static func fits(lift_kind: String, day_kind: String) -> bool:
	if day_kind == "upper":
		return lift_kind == "pull" or lift_kind == "push"
	if day_kind == "lower":
		return lift_kind == "legs"
	return lift_kind == day_kind


## The kinds of a split, in order ([] for "auto" or an unknown id).
static func split_cycle(split: String) -> Array:
	for s in SPLITS:
		if str(s.id) == split:
			return s.cycle
	return []


static func split_name(split: String) -> String:
	for s in SPLITS:
		if str(s.id) == split:
			return str(s.name)
	return str(SPLITS[0].name)


## The kind of one day's lifting in a split: the kind most of its working
## exercises belong to (PT aside), or "" when none does.
static func kind_of_day(exercises: Array, cycle: Array, marks: Dictionary = {}) -> String:
	var count = {}
	var order = []
	for ex in exercises:
		var n = str(ex.get("name", ""))
		if Pt.is_pt(marks, n) or LiftTrend.real_sets(ex.get("sets", [])).is_empty():
			continue
		var lk = kind_of(n)
		for k in cycle:
			if fits(lk, str(k)):
				count[k] = int(count.get(k, 0)) + 1
				if not order.has(k):
					order.append(k)
	var best = ""
	for k in order:
		if best == "" or int(count[k]) > int(count[best]):
			best = k
	return best


## Today's kind in a split: {"kind", "after" (the last lift day's kind, or ""),
## "afterDate", "picked" (the player chose it for today)}. `pick` is
## settings.dayPick; it counts on its own date only.
static func day_kind(sessions: Array, today: String, cycle: Array, marks: Dictionary = {}, pick = null) -> Dictionary:
	var out = {"kind": "", "after": "", "afterDate": "", "picked": false}
	if cycle.is_empty():
		return out
	var by_day = {}
	for s in sessions:
		var d = str(s.get("date", ""))
		if str(s.get("discipline", "")) == "lift" and d < today and d >= Dates.add_days(today, -LOOKBACK):
			if not by_day.has(d):
				by_day[d] = []
			by_day[d].append_array(s.get("exercises", []))
	var days = by_day.keys()
	days.sort()
	days.reverse()
	for d in days:
		var k = kind_of_day(by_day[d], cycle, marks)
		if k != "":
			out.after = k
			out.afterDate = d
			break
	out.kind = str(cycle[(cycle.find(out.after) + 1) % cycle.size()]) if out.after != "" else str(cycle[0])
	if pick is Dictionary and str(pick.get("date", "")) == today and cycle.has(str(pick.get("kind", ""))):
		out.kind = str(pick.kind)
		out.picked = true
	return out


# ---------------------------------------------------------------------------
# The ways to do a lift
# ---------------------------------------------------------------------------

## The variation to suggest for a library movement: its usual one, none when
## its equipment goes without saying (a lat pulldown is a cable), else the
## plainest that names equipment.
static func variation_for(e: Dictionary) -> String:
	if str(e.usual) != "":
		return str(e.usual)
	for o in e.only:
		if not LiftNames.gear_of(str(o)).is_empty():
			return ""
	var rest = []
	for v in e.vars:
		rest.append(str(v))
	TTUtil.stable_sort(rest, func(a, b):
		var ga = 0 if not LiftNames.gear_of(a).is_empty() else 1
		var gb = 0 if not LiftNames.gear_of(b).is_empty() else 1
		if ga != gb:
			return ga < gb
		return a.split(" ").size() < b.split(" ").size())
	return str(rest[0]) if not rest.is_empty() else ""


## "Lateral Raise (dumbbell)": a lift name in a sentence.
static func short_name(lift_name: String) -> String:
	var sp = LiftNames.split(lift_name)
	return str(sp.move) + (" (%s)" % str(sp.variation).to_lower() if str(sp.variation) != "" else "")


## The ways to do a planned lift `l` (likely_lifts), as the player has done
## it, at most OPTIONS: the lift itself, the other variations of its movement
## they logged (the latest first; "Chest Fly - Home cable" and "Chest Fly - Gym
## cable" are two), then one other movement of the same part and kind they
## have done ("Bench Press - Dumbbell" next to a chest fly), not one already in
## the day's plan (`avoid`: normalized movements). `hist`: LiftLibrary.stats of
## the log before the day. Each with its own last sets, for its own aim.
## [{"name", "move", "variation", "new": false, "last", "lastDate"}]
static func options_for(l: Dictionary, hist: Dictionary, avoid: Array = [], marks: Dictionary = {}) -> Array:
	var move_of = func(n: String): return Xp.normalize_exercise(str(LiftNames.split(n).move))
	var name = str(l.name)
	var mk = move_of.call(name)
	var part = part_of(name)
	var kind = kind_of(name)
	var vars = []
	var swaps = []
	for k in hist:
		var n = str(hist[k].name)
		if k == Xp.normalize_exercise(name):
			continue
		var nk = move_of.call(n)
		if nk == mk:
			vars.append(hist[k])
		elif not avoid.has(nk) and part_of(n) == part and kind_of(n) == kind and not Pt.is_pt(marks, n):
			swaps.append(hist[k])
	var latest = func(a, b):
		if str(a.last) != str(b.last):
			return str(a.last) > str(b.last)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
	TTUtil.stable_sort(vars, latest)
	TTUtil.stable_sort(swaps, latest)
	var picked = [name]
	for st in vars:
		if picked.size() >= OPTIONS - (1 if not swaps.is_empty() else 0):
			break
		picked.append(str(st.name))
	if not swaps.is_empty():
		picked.append(str(swaps[0].name))
	var out = []
	for n in picked:
		var sp = LiftNames.split(str(n))
		var st = hist.get(Xp.normalize_exercise(str(n)))
		out.append({"name": str(n), "move": str(sp.move), "variation": str(sp.variation), "new": st == null,
			"last": st.history[0].sets if st != null else l.last.sets, "lastDate": str(st.last) if st != null else str(l.last.date)})
	return out


## A movement to try, from its library row.
static func _new_entry(e: Dictionary) -> Dictionary:
	var v = variation_for(e)
	return {"name": LiftNames.join(str(e.name), v), "move": str(e.name), "variation": v, "part": str(e.part),
		"partName": LiftLibrary.part_name(str(e.part)), "tip": str(e.tip)}


## "Hip Thrust (barbell)", or with the others offered: "... (or Glute Bridge, Step-up)".
static func new_words(nw: Dictionary) -> String:
	var alts = nw.get("alts", []).map(func(a): return short_name(str(a.name)))
	if alts.is_empty():
		return short_name(str(nw.name))
	return "%s (or %s)" % [short_name(str(nw.name)), ", ".join(PackedStringArray(alts))]


## Is `lift_name` another movement standing in for a planned one: the same
## body part and kind, and not itself in the day's plan? `same` = {"part",
## "kind", "moves": normalized movements of the day's plan} (see same_of).
static func stands_in(lift_name: String, same: Dictionary) -> bool:
	if same.is_empty() or str(same.get("part", "")) == "" or str(same.part) == "other":
		return false
	if same.get("moves", []).has(Xp.normalize_exercise(str(LiftNames.split(lift_name).move))):
		return false
	return part_of(lift_name) == str(same.part) and kind_of(lift_name) == str(same.kind)


## What stands in for a planned lift (stands_in).
static func same_of(lift_name: String, plan: Dictionary) -> Dictionary:
	return {"part": part_of(lift_name), "kind": kind_of(lift_name), "moves": plan.get("moves", [])}


## Did any of these lifts, any variation of the movement `move`, or (with
## `same`) another movement standing in for it beat its last time on `date`,
## or get done for the first time?
static func beat_any(sessions: Array, names: Array, move: String, date: String, same: Dictionary = {}) -> bool:
	var keys = names.map(func(n): return Xp.normalize_exercise(str(n)))
	var mk = Xp.normalize_exercise(move)
	var seen = {}
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != date:
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			var k = Xp.normalize_exercise(n)
			if seen.has(k) or LiftTrend.real_sets(ex.get("sets", [])).is_empty():
				continue
			if keys.has(k) or (mk != "" and Xp.normalize_exercise(str(LiftNames.split(n).move)) == mk) or stands_in(n, same):
				seen[k] = n
	for k in seen:
		if _history_before(sessions, str(seen[k]), date).is_empty() or beat_on(sessions, str(seen[k]), date):
			return true
	return false


## Was a movement to try done on `today`? (new_by)
static func new_done(sessions: Array, today: String, plan: Dictionary) -> bool:
	return new_by(sessions, today, plan) != ""


## The lift that did "try something new" on `today`, or "": one of the
## movements offered (`plan.new` and its `alts`, any variation), else another
## movement never done before WITH THE SAME GOAL (same_goal). Only sets really
## logged count: a lift added to the workout and left empty does not.
static func new_by(sessions: Array, today: String, plan: Dictionary) -> String:
	var nw = plan.get("new")
	if nw == null:
		return ""
	var known = {}
	for s in sessions:
		if str(s.get("discipline", "")) == "lift" and str(s.get("date", "")) < today:
			for ex in s.get("exercises", []):
				if not LiftTrend.real_sets(ex.get("sets", [])).is_empty():
					known[Xp.normalize_exercise(str(LiftNames.split(str(ex.get("name", ""))).move))] = true
	var wants = [Xp.normalize_exercise(str(nw.move))]
	for a in nw.get("alts", []):
		wants.append(Xp.normalize_exercise(str(a.move)))
	var other = ""
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != today:
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			if LiftTrend.real_sets(ex.get("sets", [])).is_empty():
				continue
			var mk = Xp.normalize_exercise(str(LiftNames.split(n).move))
			if known.has(mk):
				continue
			if wants.has(mk):
				return n
			if other == "" and same_goal(n, plan):
				other = n
	return other


## Does a movement serve the goal of the day's "try something new": strength
## for the body area the day is about (the split's kind, else the day's area)?
## A stretch does not, nor a physical therapy exercise (the PT row's business),
## nor a movement of another area: a new toe stretch on a leg day used to tick
## the box under the name of a lift that was never done.
static func same_goal(lift_name: String, plan: Dictionary) -> bool:
	if Pt.is_pt(plan.get("marks", {}), lift_name) or lift_name.to_lower().contains("stretch"):
		return false
	var kind = str(plan.get("kind", ""))
	if kind != "":
		var k = kind_of(lift_name)
		return k != "" and fits(k, kind)
	var group = str(plan.get("group", ""))
	return group != "" and str(GROUP.get(part_of(lift_name), "")) == group


## What a planned lift `l` was done as on `today`, or "": physical therapy by
## itself; an extra lift of the focus (`dose`) once its sets are in (Dose.
## extra_done: an anchor only by a lift of its sort); any other lift by one of
## its ways, a variation of its movement or a movement standing in for it.
static func lift_done(l: Dictionary, plan: Dictionary, sessions: Array, today: String) -> String:
	var ways = []
	for o in l.get("options", []):
		if not ways.has(str(o.name)):
			ways.append(str(o.name))
	if ways.is_empty():
		ways = [str(l.name)]
	if bool(l.pt):
		return done_of(sessions, ways, today)
	var same = same_of(str(l.name), plan)
	if l.has("dose"):
		var got = Dose.extra_done(l, sessions, today, same)
		return str(got.name) if int(got.sets) >= int(l.dose.sets) else ""
	return done_of(sessions, ways, today, str(LiftNames.split(str(l.name)).move), same)


## The boxes of the Today card, ticked as TodayView ticks them: a row per
## planned lift (done any way), the movement to try, the PT (all of it), the
## first two other activities (logged). [{"what", "done"}].
static func day_boxes(plan: Dictionary, sessions: Array, today: String) -> Array:
	var out = []
	for l in plan.get("lifts", []):
		out.append({"what": str(l.name), "done": lift_done(l, plan, sessions, today) != ""})
	if plan.get("new") != null:
		out.append({"what": "new", "done": new_done(sessions, today, plan)})
	if not plan.get("pt", []).is_empty():
		out.append({"what": "pt", "done": plan.pt.all(func(r): return not sets_on(sessions, str(r.name), today).is_empty())})
	for o in plan.get("others", []).slice(0, 2):
		var d = str(o.discipline)
		out.append({"what": d, "done": sessions.any(func(s): return str(s.get("date", "")) == today and str(s.get("discipline", "")) == d)})
	return out


## The one of these, of any variation of `move`, or (with `same`) of a
## movement standing in for it, done on `date` (its name as logged), or "".
static func done_of(sessions: Array, names: Array, date: String, move: String = "", same: Dictionary = {}) -> String:
	var keys = names.map(func(n): return Xp.normalize_exercise(str(n)))
	var mk = Xp.normalize_exercise(move)
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != date:
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			if LiftTrend.real_sets(ex.get("sets", [])).is_empty():
				continue
			if keys.has(Xp.normalize_exercise(n)) or (mk != "" and Xp.normalize_exercise(str(LiftNames.split(n).move)) == mk) or stands_in(n, same):
				return n
	return ""


## "yesterday", "Thursday", "Nov 10": when a lift was last done.
static func when_text(last: String, today: String) -> String:
	var rel = Dates.relative_day(last, today)
	return rel.to_lower() if rel == "Yesterday" or rel == "Today" else rel


## Is there a weekday it is nearly always done on (2 or more times, two thirds
## of them on that day)? Then "it has been a while" alone does not make it due
## on another day: a Saturday climber is not due on Friday.
static func weekday_habit(dates: Array) -> bool:
	if dates.size() < 2:
		return false
	var by = {}
	for d in dates:
		var w = Dates.weekday_index(str(d))
		by[w] = int(by.get(w, 0)) + 1
	for w in by:
		if int(by[w]) >= 2 and float(by[w]) >= dates.size() * 2.0 / 3.0:
			return true
	return false


## "Almost every day", "Every other day", "About every 4 days".
static func every_text(gap: float) -> String:
	if gap <= 1.0:
		return "Almost every day"
	if gap <= 2.0:
		return "Every other day"
	return "About every %d days" % int(round(gap))


## Days between the dates (sorted), the middle one: a lift's usual gap.
static func usual_gap(dates: Array) -> float:
	var gaps = []
	for i in range(1, dates.size()):
		gaps.append(Dates.days_between(str(dates[i - 1]), str(dates[i])))
	if gaps.is_empty():
		return 7.0
	gaps.sort()
	return float(gaps[int(gaps.size() / 2.0)])


## The lifts the player will probably do on `today`, judged from the log
## before it (the last LOOKBACK days): [{"name", "score", "why", "part", "pt",
## "kind", "variations", "last": {"date", "sets"}, "since", "gap", "same"}],
## likeliest first. A lift is a MOVEMENT, all its variations together (the
## dates of any of them count); "name" is the variation done last, "variations"
## all of them, the latest first. A PT lift stays on its own.
## A lift counts when it was done on this weekday before, or when as many days
## have passed as usually pass between two of its sessions (three quarters of
## them). On a day of a split (`kind`) every lift of that kind counts and the
## lifts of the other kinds do not. A lift that is resting (REST) never counts.
static func likely_lifts(sessions: Array, today: String, marks: Dictionary = {}, kind: String = "") -> Array:
	var from = Dates.add_days(today, -LOOKBACK)
	var days_of = {}
	for s in sessions:
		if str(s.get("discipline", "")) != "lift":
			continue
		var d = str(s.get("date", ""))
		if d >= today or d < from:
			continue
		for ex in s.get("exercises", []):
			var sets = LiftTrend.real_sets(ex.get("sets", []))
			if sets.is_empty():
				continue
			var n = str(ex.get("name", ""))
			if not days_of.has(n):
				days_of[n] = {}
			if not days_of[n].has(d):
				days_of[n][d] = []
			days_of[n][d].append_array(sets)
	var wd = Dates.weekday_index(today)
	var day_name = Dates.format_date(today, {"weekday": "long"})
	var groups = {}
	var last_of = {}
	for n in days_of:
		var ds = days_of[n].keys()
		ds.sort()
		last_of[n] = str(ds[ds.size() - 1])
		var gk = n if Pt.is_pt(marks, n) else "m:" + Xp.normalize_exercise(str(LiftNames.split(n).move))
		if not groups.has(gk):
			groups[gk] = {"names": [], "days": {}}
		groups[gk].names.append(n)
		for d in ds:
			groups[gk].days[d] = true
	var out = []
	for gk in groups:
		var names: Array = groups[gk].names
		TTUtil.stable_sort(names, func(a, b):
			if str(last_of[a]) != str(last_of[b]):
				return str(last_of[a]) > str(last_of[b])
			return str(a).naturalnocasecmp_to(str(b)) < 0)
		var n = str(names[0])
		var dates = groups[gk].days.keys()
		dates.sort()
		var last = str(dates[dates.size() - 1])
		var since = Dates.days_between(last, today)
		var gap = usual_gap(dates)
		var same = 0
		for d in dates:
			if Dates.weekday_index(str(d)) == wd:
				same += 1
		var due = clampf(float(since) / maxf(gap, 1.0), 0.0, 1.5)
		var pt = Pt.is_pt(marks, n)
		var lk = kind_of(n)
		var on_day = kind != "" and fits(lk, kind)
		if kind != "" and lk != "" and not on_day and not pt:
			continue
		if not pt and same < 2 and due < REST:
			continue
		if not on_day and same == 0 and (due < 0.75 or weekday_habit(dates)):
			continue
		var score = same * 1.5 + due + (0.25 if pt else 0.0) + (1.0 if on_day else 0.0)
		var why = ""
		if on_day and same < 2:
			why = "On your %ss; last done %s" % [str(KIND_NAMES.get(kind, kind)).to_lower(), when_text(last, today)]
		elif same >= 2:
			why = "You often do it on %ss" % day_name
		elif same == 1:
			why = "You did it on a %s" % day_name
		else:
			why = "%s; last done %s" % [every_text(gap), when_text(last, today)]
		out.append({"name": n, "score": score, "why": why, "part": part_of(n), "pt": pt, "kind": lk, "variations": names.duplicate(),
			"last": {"date": last, "sets": days_of[n][last]}, "since": since, "gap": gap, "same": same})
	TTUtil.stable_sort(out, func(a, b):
		if absf(float(a.score) - float(b.score)) > 1e-9:
			return float(a.score) > float(b.score)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


## The other activities (climb, run, ride, misc) probably done today, the same
## way: [{"discipline", "why", "avg" (sends, or metres), "kind" (misc)}].
static func likely_others(sessions: Array, today: String) -> Array:
	var from = Dates.add_days(today, -LOOKBACK)
	var wd = Dates.weekday_index(today)
	var day_name = Dates.format_date(today, {"weekday": "long"})
	var out = []
	for disc in OTHER:
		var dates = {}
		var total = 0.0
		var n = 0
		for s in sessions:
			if str(s.get("discipline", "")) != disc:
				continue
			var d = str(s.get("date", ""))
			if d >= today or d < from:
				continue
			dates[d] = true
			var st = Xp.session_stats(s) if disc != "misc" else {"sends": 0, "distanceM": float(s.get("distanceM", 0.0))}
			total += float(st.sends) if disc == "climb" else float(st.distanceM)
			n += 1
		if dates.is_empty():
			continue
		var keys = dates.keys()
		keys.sort()
		var last = str(keys[keys.size() - 1])
		var gap = usual_gap(keys)
		var same = 0
		for d in keys:
			if Dates.weekday_index(str(d)) == wd:
				same += 1
		var due = float(Dates.days_between(last, today)) / maxf(gap, 1.0)
		if same == 0 and (due < 0.75 or weekday_habit(keys)):
			continue
		var why = "You often %s on %ss" % [{"climb": "climb", "run": "run", "ride": "ride", "misc": "train"}[disc], day_name] if same >= 2 else ("Last on a %s" % day_name if same == 1 else every_text(gap))
		out.append({"discipline": disc, "why": why, "avg": total / float(maxi(1, n)), "score": same * 1.5 + clampf(due, 0.0, 1.5)})
	TTUtil.stable_sort(out, func(a, b): return float(a.score) > float(b.score))
	return out


## The plan of a day, from the log before it:
## {"date", "lifts" (the likeliest PLAN_LIFTS), "group" ("back", or ""),
##  "label" ("Back day", or ""), "new": a movement of that area never done
##  ({"name", "move", "variation", "part", "partName", "tip"}) or null,
##  "pt": PT rows (Pt.status) not done this week, "others": likely_others,
##  "split", "cycle", "kind" (the split's kind of today, or ""), "after",
##  "afterDate", "picked" (see day_kind)}. With a split, `group` is the kind.
## Each lift also has "options" (options_for; never empty, itself first).
## `settings`: split, dayPick.
static func day_plan(sessions: Array, today: String, marks: Dictionary = {}, settings: Dictionary = {}) -> Dictionary:
	var before = sessions.filter(func(s): return str(s.get("date", "")) < today)
	var split = str(settings.get("split", "auto"))
	var cycle = split_cycle(split)
	var dk = day_kind(before, today, cycle, marks, settings.get("dayPick"))
	var kind = str(dk.kind)
	var lifts = likely_lifts(before, today, marks, kind).slice(0, PLAN_LIFTS)
	var group = kind
	if kind == "":
		# The body area most of the likely lifts work (PT and stretches aside).
		var count = {}
		var first_seen = []
		for l in lifts:
			var g = str(GROUP.get(str(l.part), ""))
			if g == "" or bool(l.pt):
				continue
			count[g] = int(count.get(g, 0)) + 1
			if not first_seen.has(g):
				first_seen.append(g)
		for g in first_seen:
			if group == "" or int(count[g]) > int(count[group]):
				group = g
	# A training focus (game/dose.gd): the extra lifts the day's muscles still
	# need, and what each lift is for ("build" or "keep"). The extras go first
	# (the heavy press before the flyes), and nothing else in the plan offers
	# their movements.
	var hist = LiftLibrary.stats(before)
	var avoid = lifts.map(func(l): return Xp.normalize_exercise(str(LiftNames.split(str(l.name)).move)))
	var extra = []
	if Dose.plan_id(settings) != "":
		extra = Dose.extras(lifts, before, today, marks, settings, kind, group, hist, avoid)
		for x in extra:
			x["mode"] = str(x.dose.mode)
			for o in x.options:
				var omk = Xp.normalize_exercise(str(o.move))
				if not avoid.has(omk):
					avoid.append(omk)
		for l in lifts:
			l["mode"] = "" if bool(l.pt) else Dose.mode_of(settings, str(l.name))
	var new = null
	if group != "":
		# Never done before today (what is done today keeps the day's pick).
		var done = {}
		for s in before:
			if str(s.get("discipline", "")) == "lift":
				for ex in s.get("exercises", []):
					done[Xp.normalize_exercise(str(LiftNames.split(str(ex.get("name", ""))).move))] = true
		# A movement of the area (or of the day's kind) not done: the staples of
		# its areas taken in turn, then the rest of the library.
		var fit = func(e): return fits(kind_of(str(e.name)), kind) if kind != "" else str(GROUP.get(str(e.part), "")) == group
		var lists = []
		for g in (KIND_GROUPS.get(kind, []) if kind != "" else [group]):
			lists.append(STAPLES.get(g, []))
		var pool = []
		var longest = 0
		for l in lists:
			longest = maxi(longest, l.size())
		for i in range(longest):
			for l in lists:
				if i >= l.size():
					continue
				var e = LiftNames.movement(str(l[i]))
				if e != null and fit.call(e) and not done.has(Xp.normalize_exercise(str(e.name))) and not avoid.has(Xp.normalize_exercise(str(e.name))) and not pool.any(func(x): return x.name == e.name):
					pool.append(e)
		for e in LiftLibrary.catalog():
			if fit.call(e) and not done.has(Xp.normalize_exercise(str(e.name))) and not avoid.has(Xp.normalize_exercise(str(e.name))) and not pool.any(func(x): return x.name == e.name):
				pool.append(e)
		if not pool.is_empty():
			# The day picks one of the three most useful ones not done yet.
			var every = pool
			pool = pool.slice(0, mini(3, pool.size()))
			var e = pool[int(Rng.make_rng("try:" + today).next() * pool.size()) % pool.size()]
			new = _new_entry(e)
			# And a couple of others to pick from, for the day its equipment is taken
			# or not there: the same body part first, and other equipment first.
			var rest = every.filter(func(x): return str(x.name) != str(e.name))
			var near = func(x): return (2 if str(x.part) == str(e.part) else 0) + (1 if str(x.equip) != str(e.equip) else 0)
			TTUtil.stable_sort(rest, func(a, b): return int(near.call(a)) > int(near.call(b)))
			var alts = []
			var gear = [str(e.equip)]
			for turn in range(2):
				for x in rest:
					if alts.size() >= NEW_ALTS:
						break
					if alts.any(func(a): return str(a.move) == str(x.name)):
						continue
					if turn == 0 and gear.has(str(x.equip)):
						continue
					gear.append(str(x.equip))
					alts.append(_new_entry(x))
			new["alts"] = alts
	var pt = []
	for r in Pt.status(before, marks, today):
		if str(r.state) != "done":
			pt.append(r)
	# The ways to do each lift: how the player has done it (PT as it is).
	if new != null:
		avoid.append(Xp.normalize_exercise(str(new.move)))
	for l in lifts:
		if bool(l.pt):
			l["options"] = [{"name": str(l.name), "move": str(LiftNames.split(str(l.name)).move), "variation": str(LiftNames.split(str(l.name)).variation),
				"new": false, "last": l.last.sets, "lastDate": str(l.last.date)}]
		else:
			l["options"] = options_for(l, hist, avoid, marks)
	var label = str(KIND_NAMES.get(kind, "")) if kind != "" else str(GROUP_NAMES.get(group, ""))
	var focus = Dose.plan_id(settings)
	return {"date": today, "lifts": extra + lifts, "group": group, "label": label, "new": new,
		"pt": pt, "others": likely_others(before, today), "split": split if not cycle.is_empty() else "auto",
		"cycle": cycle, "kind": kind, "after": dk.after, "afterDate": dk.afterDate, "picked": dk.picked, "moves": avoid, "marks": marks,
		"focus": focus, "rest": Dose.rest(before, marks, today) if focus != "" else {"run": 0, "today": false, "due": false},
		"run": Dose.run_goal(before, today, str(settings.get("distanceUnit", "km"))) if Dose.run_on(settings) else null}


## One line on why today is that kind of day: "Yesterday was a pull day",
## "Your pick for today", "" without a split.
static func kind_why(plan: Dictionary) -> String:
	if str(plan.get("kind", "")) == "":
		return ""
	if bool(plan.get("picked", false)):
		return "Your pick for today"
	if str(plan.get("after", "")) == "":
		return "The first day of your split"
	var d = str(plan.afterDate)
	var n = Dates.days_between(d, str(plan.date))
	var day = "Yesterday" if n == 1 else (Dates.format_date(d, {"weekday": "long"}) if n < 7 else "Your last lift")
	return "%s was a %s" % [day, str(KIND_NAMES.get(str(plan.after), "")).to_lower()]


# ---------------------------------------------------------------------------
# Missions
# ---------------------------------------------------------------------------

static func _mission(id: String, kind: String, period: String, title: String, desc: String, icon: String, discipline, target, progress, unit: String, xp: int, claims: Array, extra: Dictionary = {}) -> Dictionary:
	var claimed = false
	for c in claims:
		if str(c.get("questId", "")) == id:
			claimed = true
			break
	var out = {"id": id, "kind": kind, "periodKey": period, "title": title, "desc": desc, "icon": icon,
		"discipline": discipline, "target": target, "progress": progress, "unit": unit, "xp": xp,
		"done": float(progress) >= float(target), "claimed": claimed}
	out.merge(extra)
	return out


## All sets of a lift done on `date` (every session of that day).
static func sets_on(sessions: Array, lift_name: String, date: String) -> Array:
	var k = Xp.normalize_exercise(lift_name)
	var out = []
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != date:
			continue
		for ex in s.get("exercises", []):
			if Xp.normalize_exercise(str(ex.get("name", ""))) == k:
				out.append_array(LiftTrend.real_sets(ex.get("sets", [])))
	return out


## A lift's history before `date` (newest first), as LiftLibrary.stats keeps it.
static func _history_before(sessions: Array, lift_name: String, date: String) -> Array:
	var before = sessions.filter(func(s): return str(s.get("date", "")) < date)
	var st = LiftLibrary.stats(before).get(Xp.normalize_exercise(lift_name))
	return st.history if st != null else []


## Did the lift beat its last time on `date` (more weight, more reps, a record)?
static func beat_on(sessions: Array, lift_name: String, date: String) -> bool:
	var sets = sets_on(sessions, lift_name, date)
	if sets.is_empty():
		return false
	var hist = _history_before(sessions, lift_name, date)
	if hist.is_empty():
		return false
	return str(LiftTrend.compare(sets, hist).kind) == "up" or not LiftTrend.records(sets, hist).is_empty()


static func _step_kg(wu: String) -> float:
	return 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)


static func daily(today: String, data: Dictionary, state: Dictionary, claims: Array) -> Array:
	var sessions = data.get("sessions", [])
	var marks = data.get("pt", {})
	var settings = data.get("settings", {})
	var wu = str(settings.get("weightUnit", "kg"))
	var du = str(settings.get("distanceUnit", "km"))
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var plan = day_plan(sessions, today, marks, settings)
	var todays = sessions.filter(func(s): return str(s.get("date", "")) == today)
	var out = []
	var focus = str(plan.get("focus", "")) != ""
	if focus and bool(plan.rest.due):
		# Enough days in a row: the day's first mission is to rest. It counts once
		# the day is over (`data.now` is the real today), from "From yesterday".
		var over = str(data.get("now", today)) > today
		out.append(_mission("t:%s:rest" % today, "daily", today, "Rest day", "%d days in a row. No hard workout today: a walk, physical therapy and stretches are fine. It counts once the day is over." % int(plan.rest.run), "moon", null,
			1, 1 if (over and not Dose.hard_on(sessions, marks, today)) else 0, "", 150, claims, {"rest": true}))
	else:
		out.append(_mission("t:%s:show" % today, "daily", today, "Show up", "Log any workout today.", "flame", null, 1, todays.size(), "sessions", 150, claims))

	# What the focus adds today: an extra lift for a muscle that is short.
	for l in plan.lifts:
		if not l.has("dose"):
			continue
		var d = l.dose
		var first = l.options[0]
		var pn = Dose.part_name(str(d.part))
		var anchor = Dose.ANCHORS.get(str(d.part)) if bool(d.anchor) else null
		var title = ("%s: add %s" % [pn, str(anchor.what)]) if anchor != null else ("More for your %s" % pn.to_lower())
		var words = "%s: " % pn
		if float(d.need) >= 1.0:
			words += "%s of %s weekly sets" % [Dosage._n(float(d.have)), Dosage._n(float(d.min))]
			if anchor != null:
				words += ", no %s in two weeks" % str(anchor.word)
		else:
			words += "no %s in two weeks" % str(anchor.word)
		words += ". "
		if anchor != null:
			words += str(anchor.why) + " "
		words += "Do %d sets of %s" % [int(d.sets), short_name(str(first.name))]
		if bool(first.new):
			words += ": 6 to 12 reps, the last ones hard."
		else:
			words += ": last time %s." % LiftHistory.describe_sets(first.last, fmt_w)
		# The other ways: a variation of the same movement by its own word.
		var others = l.options.slice(1).map(func(o): return str(o.variation).to_lower() if str(o.move) == str(first.move) and str(o.variation) != "" else short_name(str(o.name)))
		if not others.is_empty():
			words += " Or: %s." % ", ".join(PackedStringArray(others))
		var got = Dose.extra_done(l, sessions, today, same_of(str(l.name), plan))
		out.append(_mission("t:%s:dose:%s" % [today, str(d.part)], "daily", today, title, words, "muscle", "lift",
			int(d.sets), mini(int(d.sets), int(got.sets)), "", 250, claims,
			{"lift": str(first.name), "why": str(l.why), "ways": l.options.map(func(o): return str(o.name)), "dose": str(d.part)}))

	# Beat last time: the likeliest lifts that are not physical therapy. With a
	# training focus the lifts of the muscles being built come first; a kept
	# muscle's lifts are beaten like any other when it is their day.
	var beats = 0
	var ranked = plan.lifts.duplicate()
	if focus:
		var rank = func(l): return {"build": 0, "keep": 1}.get(str(l.get("mode", "")), 2)
		TTUtil.stable_sort(ranked, func(a, b): return int(rank.call(a)) < int(rank.call(b)))
	for l in ranked:
		if beats >= BEAT_MISSIONS or bool(l.pt) or l.has("dose"):
			continue
		# The lift as done last, the other ways after "Or"; done by any of them or
		# any variation of the movement (the id stays the planned lift's).
		var main = l.options[0]
		var aim = LiftTrend.next_target(main.last, _step_kg(wu))
		var easy = easy_day(settings, today)
		var strong = feel_of(settings, today) == 3
		if easy:
			aim = {"sets": easy_sets(main.last, _step_kg(wu))}
		elif strong:
			aim = LiftTrend.next_target(aim.sets, _step_kg(wu))
		var desc = ""
		if bool(main.new):
			desc = "New: %s. Find a weight you can do for 8 to 12 good reps." % short_name(str(main.name))
		elif easy:
			desc = "Easy day: %s (about 10%% lighter). Doing it any way counts." % LiftHistory.describe_sets(aim.sets, fmt_w)
		else:
			desc = "Last time %s. Aim for %s%s." % [LiftHistory.describe_sets(main.last, fmt_w), LiftHistory.describe_sets(aim.sets, fmt_w), " (feeling strong: one step more)" if strong else ""]
			if bool(aim.get("heavier", false)):
				desc += " Past %d reps a set the weight is too light to build much: heavier, fewer reps." % LiftTrend.HIGH_REPS
		var alts = []
		for o in l.options.slice(1):
			alts.append(short_name(str(o.name)))
		if not alts.is_empty():
			desc += " Or: %s." % ", ".join(PackedStringArray(alts))
		var ways = l.options.map(func(o): return str(o.name))
		var did = done_of(sessions, ways, today, str(LiftNames.split(str(l.name)).move), same_of(str(l.name), plan)) != "" if easy else beat_any(sessions, ways, str(LiftNames.split(str(l.name)).move), today, same_of(str(l.name), plan))
		out.append(_mission("t:%s:beat:%s" % [today, Xp.normalize_exercise(str(l.name))], "daily", today, ("Easy day: %s" if easy else "Beat it: %s") % str(main.move), desc, "sword", "lift",
			1, 1 if did else 0, "", 200, claims,
			{"lift": str(main.name), "why": str(l.why), "aim": aim.sets, "ways": ways, "planned": str(l.name)}))
		beats += 1

	if plan.new != null:
		# Done by the movement suggested, or by any movement never done before.
		var nw = plan.new
		var by = new_by(sessions, today, plan)
		var desc = "%s: a %s movement you haven't done yet." % [str(nw.name), str(nw.partName).to_lower()]
		var others = nw.get("alts", []).map(func(a): return short_name(str(a.name)))
		var fit_words = str(plan.get("label", "")).to_lower()
		others.append("any other movement new to you" + ((" that fits a %s" % fit_words) if fit_words != "" else ""))
		desc += " Or: %s." % ", ".join(PackedStringArray(others))
		out.append(_mission("t:%s:new" % today, "daily", today, "Try something new", desc, "sparkle", "lift",
			1, 1 if by != "" else 0, "", 200, claims, {"lift": str(nw.name), "by": by}))

	if not plan.pt.is_empty():
		var names = []
		var done = 0
		for r in plan.pt:
			names.append(str(r.name))
			if not sets_on(sessions, str(r.name), today).is_empty():
				done += 1
		out.append(_mission("t:%s:pt" % today, "daily", today, "Physical therapy", "Do today: %s." % ", ".join(PackedStringArray(names)), "pt", null,
			names.size(), done, "", 150, claims))

	if not plan.others.is_empty():
		var o = plan.others[0]
		var disc = str(o.discipline)
		var progress = 0.0
		for s in todays:
			if str(s.get("discipline", "")) == disc:
				if disc == "climb":
					progress += float(Xp.session_stats(s).sends)
				elif disc == "misc":
					progress += float(s.get("distanceM", 0.0))
				else:
					progress += float(Xp.session_stats(s).distanceM)
		if disc == "climb":
			var sends = maxi(3, TTUtil.jsround(float(o.avg)))
			out.append(_mission("t:%s:%s" % [today, disc], "daily", today, "Send it", "%s. Send %d problems (about what you usually do)." % [str(o.why), sends], "climb", "climb", sends, progress, "sends", 200, claims))
		else:
			# A round distance in the player's unit, about their usual one.
			var unit_m = 1609.344 if du == "mi" else 1000.0
			var dist_m = maxf(unit_m, roundf(float(o.avg) / unit_m * 2.0) / 2.0 * unit_m)
			var title = {"run": "Get the miles in", "ride": "Spin the wheels", "misc": "Walk it"}[disc]
			var go = "%s. Go %s." % [str(o.why), Fmt.fmt_distance(dist_m, du)]
			if disc == "run" and plan.get("run") != null:
				# The weekly run is being built up: a little further than the last one.
				dist_m = float(plan.run.targetM)
				title = "Run a little further"
				go = "Go %s. %s. Easy pace, and stop short if anything hurts." % [Fmt.fmt_distance(dist_m, du), Dose.run_why(plan.run, du)]
			out.append(_mission("t:%s:%s" % [today, disc], "daily", today, title, go, disc if disc != "misc" else "vest",
				disc if disc != "misc" else null, dist_m, progress, "m", 200, claims))

	if not data.get("reading", []).is_empty():
		var goal = Reading.goal(settings)
		var pages = 0
		for r in data.get("reading", []):
			if str(r.get("date", "")) == today:
				pages += int(r.get("pages", 0))
		out.append(_mission("t:%s:read" % today, "daily", today, "Read", "Read %d pages today." % goal, "book", null, goal, pages, "pages", 100, claims))

	# Perfect day: every box of the Today card ticked (a chest on the card).
	var boxes = day_boxes(plan, sessions, today)
	if boxes.size() >= 2:
		out.append(_mission("t:%s:perfect" % today, "daily", today, "Perfect day", "Tick every box on today's card.", "chest", null,
			boxes.size(), boxes.filter(func(b): return bool(b.done)).size(), "", PERFECT_XP, claims, {"perfect": true}))

	# A quiet day in the plan: one goal for everything.
	if out.size() < 3:
		var target = maxi(50, TTUtil.jsround((300 + 60 * int(state.levels.hero.level)) / 50.0) * 50)
		var xp = 0
		for s in todays:
			xp += int(state.get("sessionXp", {}).get(s.id, 0))
		out.append(_mission("t:%s:xp" % today, "daily", today, "XP hunter", "Earn %s XP from workouts today." % Xp.fmt_int(target), "bolt", null, target, xp, "xp", 150, claims))
	return out


static func weekly(wk: String, today: String, data: Dictionary, state: Dictionary, claims: Array) -> Array:
	var sessions = data.get("sessions", [])
	var marks = data.get("pt", {})
	var settings = data.get("settings", {})
	var week = sessions.filter(func(s): return Dates.week_key(str(s.get("date", ""))) == wk)
	var out = []
	var days = {}
	for s in week:
		days[str(s.date)] = true
	var goal = maxi(1, int(settings.get("weeklyGoal", 3)))
	out.append(_mission("tw:%s:days" % wk, "weekly", wk, "Consistency", "Train on %d different days this week." % goal, "calendar", null, goal, days.size(), "days", 400, claims))

	# A record: any lift that beat everything before it, on any day of the week.
	var record_days = {}
	var new_moves = {}
	var seen_before = {}
	for s in sessions:
		if str(s.get("discipline", "")) == "lift" and str(s.get("date", "")) < wk:
			for ex in s.get("exercises", []):
				seen_before[Xp.normalize_exercise(str(LiftNames.split(str(ex.get("name", ""))).move))] = true
	for s in week:
		if str(s.get("discipline", "")) != "lift":
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			var mv = Xp.normalize_exercise(str(LiftNames.split(n).move))
			if not seen_before.has(mv):
				new_moves[mv] = true
			var hist = _history_before(sessions, n, str(s.date))
			if not LiftTrend.records(LiftTrend.real_sets(ex.get("sets", [])), hist).is_empty():
				record_days[str(s.date)] = true
	out.append(_mission("tw:%s:record" % wk, "weekly", wk, "Set a record", "Beat a best on any lift this week: weight, reps or estimated strength.", "trophy", "lift", 1, record_days.size(), "", 400, claims))
	out.append(_mission("tw:%s:new" % wk, "weekly", wk, "Explore", "Try a movement you have never done this week.", "sparkle", "lift", 1, new_moves.size(), "", 300, claims))

	if not marks.is_empty():
		var rows = Pt.status(sessions, marks, today)
		var on = rows.filter(func(r): return str(r.state) == "done").size()
		out.append(_mission("tw:%s:pt" % wk, "weekly", wk, "PT on target", "Reach the days a week of every physical therapy exercise.", "pt", null, rows.size(), on, "", 400, claims))

	# The main other activity of the last four weeks, about as often as usual.
	var counts = {}
	var four = Dates.add_days(wk, -28)
	for s in sessions:
		var d = str(s.get("discipline", ""))
		if OTHER.has(d) and str(s.get("date", "")) >= four and str(s.get("date", "")) < wk:
			counts[d] = int(counts.get(d, 0)) + 1
	var main = ""
	for d in counts:
		if int(counts[d]) >= 2 and (main == "" or int(counts[d]) > int(counts[main])):
			main = d
	if main != "":
		var times = maxi(1, TTUtil.jsround(int(counts[main]) / 4.0))
		var did = week.filter(func(s): return str(s.get("discipline", "")) == main).size()
		var word = {"climb": "Climb", "run": "Run", "ride": "Ride", "misc": "Walk with the vest"}[main]
		out.append(_mission("tw:%s:%s" % [wk, main], "weekly", wk, "%s %s" % [word, "once" if times == 1 else "%d times" % times], "Keep up your usual %s." % TT.DISCIPLINE_META[main].name.to_lower(), main if main != "misc" else "vest",
			main if main != "misc" else null, times, did, "sessions", 300, claims))

	var target = maxi(100, TTUtil.jsround((2000 + 300 * int(state.levels.hero.level)) / 100.0) * 100)
	var xp = 0
	for s in week:
		xp += int(state.get("sessionXp", {}).get(s.id, 0))
	out.append(_mission("tw:%s:xp" % wk, "weekly", wk, "Grind", "Earn %s XP from workouts this week." % Xp.fmt_int(target), "bolt", null, target, xp, "xp", 500, claims))

	# Split combo: three lift days in the split's order this week.
	var cycle = split_cycle(str(settings.get("split", "auto")))
	if not cycle.is_empty():
		var cb = combo(sessions, Dates.add_days(wk, 6), cycle, marks)
		out.append(_mission("tw:%s:combo" % wk, "weekly", wk, "Combo week", "Three lift days in your split's order (%s)." % ", ".join(PackedStringArray(cycle.map(func(k): return str(KIND_SHORT[k]).to_lower()))), "flame", "lift",
			3, mini(3, int(cb.best)), "", 300, claims))

	# A training focus: every muscle being built at its weekly sets at once (the
	# last seven days, as the Today card counts them), on any day of the week.
	var build = Dose.build_parts(settings)
	if not build.is_empty():
		var best = 0
		for i in range(7):
			var day = Dates.add_days(wk, i)
			if day > today:
				break
			best = maxi(best, Dose.on_target(sessions, marks, settings, day))
		out.append(_mission("tw:%s:dose" % wk, "weekly", wk, "Dosed right", "Have %s all at their weekly sets at once (the last 7 days), on any day this week." % ", ".join(PackedStringArray(build.map(func(p): return Dose.part_name(str(p)).to_lower()))), "muscle", "lift",
			build.size(), best, "", 500, claims))
	# The weekly run, a little further than the last one before this week.
	var rg = Dose.run_goal(sessions, wk, str(settings.get("distanceUnit", "km"))) if Dose.run_on(settings) else null
	if rg != null:
		var far = 0.0
		for s in week:
			if str(s.get("discipline", "")) == "run":
				far = maxf(far, float(s.get("distanceM", 0.0)))
		out.append(_mission("tw:%s:longrun" % wk, "weekly", wk, "Long run", "One run of %s this week. %s." % [Fmt.fmt_distance(float(rg.targetM), str(settings.get("distanceUnit", "km"))), Dose.run_why(rg, str(settings.get("distanceUnit", "km")))], "run", "run",
			float(rg.targetM), far, "m", 300, claims))

	if int(state.get("body", {}).get("entries", 0)) > 0:
		var checked = 1 if int(state.body.get("weekFlags", {}).get(wk, 0)) > 0 else 0
		out.append(_mission("tw:%s:body" % wk, "weekly", wk, "Check in", "Log your weight or progress photos this week.", "camera", null, 1, checked, "sessions", 150, claims))
	return out


# ---------------------------------------------------------------------------
# For the phone
# ---------------------------------------------------------------------------

## The evening check: what of today's card is still open, in a few lines, or
## "" when there is nothing to say (no plan, or every box ticked and the chest
## already opened). `perfect_open`: every box is ticked but the chest is not
## opened yet.
static func evening_text(plan: Dictionary, sessions: Array, today: String, perfect_claimed: bool) -> String:
	var boxes = day_boxes(plan, sessions, today)
	if boxes.is_empty():
		return ""
	var open = boxes.filter(func(b): return not bool(b.done))
	if open.is_empty():
		return "" if perfect_claimed else "Every box ticked today. Open your chest in the game!"
	var lines = ["Still open today:"]
	for b in open:
		match str(b.what):
			"new":
				lines.append("- Try: %s" % new_words(plan.new))
			"pt":
				var left = plan.pt.filter(func(r): return sets_on(sessions, str(r.name), today).is_empty()).map(func(r): return str(r.name))
				lines.append("- PT: %s" % ", ".join(PackedStringArray(left)))
			"climb", "run", "ride", "misc":
				lines.append("- %s" % TT.DISCIPLINE_META[str(b.what)].name)
			_:
				lines.append("- %s" % short_name(str(b.what)))
	lines.append("%d of %d boxes ticked." % [boxes.size() - open.size(), boxes.size()])
	return "\n".join(PackedStringArray(lines))


## The plan and the day's missions in a few short lines (a phone notification).
static func morning_text(plan: Dictionary, daily_missions: Array, wu: String, du: String = "km") -> String:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var lines = []
	if bool(plan.get("rest", {}).get("due", false)):
		lines.append("Rest day: %d days in a row. A walk, PT and stretches are fine." % int(plan.rest.run))
	if str(plan.get("kind", "")) != "":
		lines.append("%s. %s." % [str(plan.label), kind_why(plan)])
	elif str(plan.label) != "":
		lines.append("Probably a %s." % str(plan.label).to_lower())
	# Every planned lift (PT aside) and every way the player has done it, each
	# with its own aim.
	var way = func(o: Dictionary) -> String:
		var tags = []
		if str(o.variation) != "":
			tags.append(str(o.variation).to_lower())
		if bool(o.new):
			tags.append("new")
		var t = str(o.move) + (" (%s)" % ", ".join(PackedStringArray(tags)) if not tags.is_empty() else "")
		var aim = "" if bool(o.new) else LiftHistory.describe_sets(LiftTrend.next_target(o.last, _step_kg(wu)).sets, fmt_w)
		return t + (": " + aim if aim != "" else "")
	for l in plan.lifts:
		if bool(l.pt) or not l.has("options") or l.options.is_empty():
			continue
		var lead = ""
		if l.has("dose"):
			# An extra lift of the focus: say what it is for.
			lead = "For your %s, %d sets: " % [Dose.part_name(str(l.dose.part)).to_lower(), int(l.dose.sets)]
		lines.append(lead + str(way.call(l.options[0])))
		for o in l.options.slice(1):
			lines.append("  or " + str(way.call(o)))
	if plan.new != null:
		lines.append("Try: %s" % new_words(plan.new))
	if not plan.pt.is_empty():
		var names = []
		for r in plan.pt:
			names.append(str(r.name))
		lines.append("PT: %s" % ", ".join(PackedStringArray(names)))
	for o in plan.others.slice(0, 1):
		var why = str(o.why)
		if str(o.discipline) == "run" and plan.get("run") != null:
			lines.append("Running: aim for %s" % Fmt.fmt_distance(float(plan.run.targetM), du))
			continue
		lines.append("%s: %s" % [TT.DISCIPLINE_META[o.discipline].name, why.left(1).to_lower() + why.substr(1)])
	if lines.is_empty():
		lines.append("No pattern for today yet: anything counts.")
	return "\n".join(PackedStringArray(lines))
