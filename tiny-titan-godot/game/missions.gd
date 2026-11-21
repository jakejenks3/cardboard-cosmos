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
## PLACES: the gym has everything, home has settings.homeGear (dumbbells to
## start with); settings.placePick = {date, place} says where on that date.
## Every planned lift has OPTIONS there (options_for: itself when it fits, a
## variation of it, another movement of the same part), and its "Beat it"
## mission is done by any of them, at either place, beaten or done for the
## first time (beat_any).
## then the MISSIONS of the day and the week, in the Quests format (so the
## quest lists, claims, coins and the replay work as before; a claim stores its
## XP, so changing missions never changes the XP of an old claim):
##   daily(today, data, state, claims)       show up, beat last time (the two likeliest
##                                           lifts), try something new, physical therapy,
##                                           the likely run / climb / ride, read
##   weekly(wk, data, state, claims)         days trained, a record, a new movement,
##                                           PT on target, the main other activity,
##                                           XP, a body check-in
##   morning_text(plan, daily, wu)           the plan as a few lines for a phone
## `data` = {"sessions", "pt" (marks), "settings"}; `state` the derived state.
## No mission is about minutes: workouts are not timed in this game.
## Pure logic: tests/missions_test.gd.

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
## Where the player trains (see the top). Bodyweight work goes anywhere.
const PLACES = [{"id": "gym", "name": "Gym"}, {"id": "home", "name": "Home"}]
const HOME_GEAR = ["dumbbell"]
## The equipment a home gym can have (Settings -> Home gym).
const GEAR_CHOICES = ["dumbbell", "barbell", "kettlebell", "band", "cable", "machine"]
## Ways shown to do one planned lift.
const OPTIONS = 3
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
# Where, and the ways to do a lift there
# ---------------------------------------------------------------------------

## "gym" or "home" on `date` (settings.placePick counts on its own date only).
static func place_of(settings: Dictionary, date: String) -> String:
	var p = settings.get("placePick")
	if p is Dictionary and str(p.get("date", "")) == date and str(p.get("place", "")) == "home":
		return "home"
	return "gym"


## The equipment ids at a place; null = everything (the gym).
static func gear_at(settings: Dictionary, place: String):
	if place != "home":
		return null
	var g = settings.get("homeGear")
	return g.duplicate() if g is Array else HOME_GEAR.duplicate()


## The equipment a lift needs (LiftLibrary.EQUIPMENT ids): what its variation
## names, else its movement's own (a lat pulldown is a cable), else the usual
## one (a squat is a barbell). [] when it cannot be told.
static func needs(lift_name: String) -> Array:
	var sp = LiftNames.split(lift_name)
	var out = LiftNames.gear_of(str(sp.variation))
	var e = LiftNames.movement(str(sp.move))
	if out.is_empty() and e != null:
		for o in e.only:
			for g in LiftNames.gear_of(str(o)):
				if not out.has(g):
					out.append(g)
		if out.is_empty() and str(e.usual) != "":
			out = LiftNames.gear_of(str(e.usual))
	return out


## Can the lift be done with this equipment (null = everything)?
static func can_do(lift_name: String, have) -> bool:
	if have == null:
		return true
	for g in needs(lift_name):
		if g != "bodyweight" and g != "other" and not have.has(g):
			return false
	return true


## The variation of a library movement to do with this equipment: the usual
## one when it fits, else the plainest that names equipment that fits, else
## one that names none; null when nothing fits. "" = the movement alone (its
## equipment goes without saying). `skip`: normalized lift names to pass over;
## `other_than`: equipment to move away from (a band pushdown instead of the
## rope one), tried last.
static func variation_for(e: Dictionary, have, skip: Array = [], other_than: Array = []):
	var cands = []
	if str(e.usual) != "":
		cands.append(str(e.usual))
	else:
		for o in e.only:
			if not LiftNames.gear_of(str(o)).is_empty():
				cands.append("")
				break
	var rest = []
	for v in e.vars:
		if not cands.has(str(v)):
			rest.append(str(v))
	TTUtil.stable_sort(rest, func(a, b):
		var ga = 0 if not LiftNames.gear_of(a).is_empty() else 1
		var gb = 0 if not LiftNames.gear_of(b).is_empty() else 1
		if ga != gb:
			return ga < gb
		return a.split(" ").size() < b.split(" ").size())
	cands.append_array(rest)
	if not other_than.is_empty():
		var same_gear = func(v): return needs(LiftNames.join(str(e.name), str(v))).any(func(g): return other_than.has(g))
		cands = cands.filter(func(v): return not same_gear.call(v)) + cands.filter(func(v): return same_gear.call(v))
	for v in cands:
		var n = LiftNames.join(str(e.name), str(v))
		if skip.has(Xp.normalize_exercise(n)):
			continue
		if can_do(n, have):
			return str(v)
	return null


## "Lateral Raise (dumbbell)": a lift name in a sentence.
static func short_name(lift_name: String) -> String:
	var sp = LiftNames.split(lift_name)
	return str(sp.move) + (" (%s)" % str(sp.variation).to_lower() if str(sp.variation) != "" else "")


## The ways to do a planned lift with this equipment (null = everything), at
## most OPTIONS, the planned one first when it fits: another variation of its
## movement (one the player has done, else one that fits), then another
## movement of the same part and kind ("Bench Press" for a chest fly; two when
## the movement itself cannot be done there), one the player has done first.
## `hist`: LiftLibrary.stats of the log before the day; `avoid`: normalized
## movements not to offer instead (the rest of the day's plan).
## [{"name", "move", "variation", "new" (never done), "last" (its last sets)}]
static func options_for(lift_name: String, hist: Dictionary, have, avoid: Array = []) -> Array:
	var out = []
	var add = func(n: String):
		var k = Xp.normalize_exercise(n)
		if out.size() >= OPTIONS or out.any(func(o): return Xp.normalize_exercise(str(o.name)) == k):
			return
		var sp = LiftNames.split(n)
		var st = hist.get(k)
		out.append({"name": n, "move": str(sp.move), "variation": str(sp.variation), "new": st == null,
			"last": st.history[0].sets if st != null else [], "lastDate": str(st.last) if st != null else ""})
	var mv = str(LiftNames.split(lift_name).move)
	var mk = Xp.normalize_exercise(mv)
	var lk = Xp.normalize_exercise(lift_name)
	var move_of = func(n: String): return Xp.normalize_exercise(str(LiftNames.split(n).move))
	if can_do(lift_name, have):
		add.call(lift_name)
	# Another variation of the movement: one done (the latest), else one that fits.
	var done = []
	for k in hist:
		if k != lk and move_of.call(str(hist[k].name)) == mk and can_do(str(hist[k].name), have):
			done.append(hist[k])
	done.sort_custom(func(a, b): return str(a.last) > str(b.last))
	if not done.is_empty():
		add.call(str(done[0].name))
	else:
		var e = LiftNames.movement(mv)
		if e != null:
			var v = variation_for(e, have, [lk], needs(lift_name))
			if v != null:
				add.call(LiftNames.join(str(e.name), str(v)))
	# Another movement of the same part and kind.
	var part = part_of(lift_name)
	var kind = kind_of(lift_name)
	var swaps = 1 if not out.is_empty() else 2
	var taken = {}
	var try_move = func(e2) -> String:
		if e2 == null or str(e2.part) != part or taken.has(Xp.normalize_exercise(str(e2.name))):
			return ""
		var ek = Xp.normalize_exercise(str(e2.name))
		if ek == mk or avoid.has(ek) or kind_of(LiftNames.join(str(e2.name), str(e2.usual))) != kind:
			return ""
		var v2 = variation_for(e2, have)
		return LiftNames.join(str(e2.name), str(v2)) if v2 != null else ""
	var mine = []
	for k in hist:
		var n = str(hist[k].name)
		var nk = move_of.call(n)
		if nk != mk and not avoid.has(nk) and part_of(n) == part and kind_of(n) == kind:
			mine.append(hist[k])
	mine.sort_custom(func(a, b): return str(a.last) > str(b.last))
	for st in mine:
		if swaps <= 0:
			break
		var n = str(st.name)
		var pick = n if can_do(n, have) else str(try_move.call(LiftNames.movement(str(LiftNames.split(n).move))))
		if pick != "" and not taken.has(move_of.call(pick)):
			taken[move_of.call(pick)] = true
			add.call(pick)
			swaps -= 1
	if swaps > 0:
		var names = Array(STAPLES.get(str(GROUP.get(part, "")), [])).duplicate()
		for e3 in LiftLibrary.catalog():
			if str(e3.part) == part and not names.has(str(e3.name)):
				names.append(str(e3.name))
		for n in names:
			if swaps <= 0:
				break
			var pick = str(try_move.call(LiftNames.movement(str(n))))
			if pick != "":
				taken[move_of.call(pick)] = true
				add.call(pick)
				swaps -= 1
	return out


## Did any of these lifts, or any variation of the movement `move`, beat its
## last time on `date`, or get done for the first time?
static func beat_any(sessions: Array, names: Array, move: String, date: String) -> bool:
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
			if keys.has(k) or Xp.normalize_exercise(str(LiftNames.split(n).move)) == mk:
				seen[k] = n
	for k in seen:
		if _history_before(sessions, str(seen[k]), date).is_empty() or beat_on(sessions, str(seen[k]), date):
			return true
	return false


## The one of these, or of any variation of `move`, done on `date` (its
## name as logged), or "".
static func done_of(sessions: Array, names: Array, date: String, move: String = "") -> String:
	var keys = names.map(func(n): return Xp.normalize_exercise(str(n)))
	var mk = Xp.normalize_exercise(move)
	for s in sessions:
		if str(s.get("discipline", "")) != "lift" or str(s.get("date", "")) != date:
			continue
		for ex in s.get("exercises", []):
			var n = str(ex.get("name", ""))
			if LiftTrend.real_sets(ex.get("sets", [])).is_empty():
				continue
			if keys.has(Xp.normalize_exercise(n)) or (mk != "" and Xp.normalize_exercise(str(LiftNames.split(n).move)) == mk):
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
## "kind", "last": {"date", "sets"}, "since", "gap", "same"}], likeliest first.
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
	var out = []
	for n in days_of:
		var dates = days_of[n].keys()
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
		out.append({"name": n, "score": score, "why": why, "part": part_of(n), "pt": pt, "kind": lk,
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
##  "afterDate", "picked" (see day_kind), "place" ("gym" / "home")}. With a
## split, `group` is the kind. Each lift also has "options" (options_for, at
## today's place; never empty), "gym" and "home" (the same at each place).
## `settings`: split, dayPick, placePick, homeGear.
static func day_plan(sessions: Array, today: String, marks: Dictionary = {}, settings: Dictionary = {}) -> Dictionary:
	var before = sessions.filter(func(s): return str(s.get("date", "")) < today)
	var split = str(settings.get("split", "auto"))
	var cycle = split_cycle(split)
	var dk = day_kind(before, today, cycle, marks, settings.get("dayPick"))
	var place = place_of(settings, today)
	var here = gear_at(settings, place)
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
	var new = null
	var new_at = {"gym": null, "home": null}
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
				if e != null and fit.call(e) and not done.has(Xp.normalize_exercise(str(e.name))) and not pool.any(func(x): return x.name == e.name):
					pool.append(e)
		for e in LiftLibrary.catalog():
			if fit.call(e) and not done.has(Xp.normalize_exercise(str(e.name))) and not pool.any(func(x): return x.name == e.name):
				pool.append(e)
		# One that can be done with this equipment: the day picks one of the
		# three most useful ones not done yet, with its usual variation when it
		# fits (none when its equipment goes without saying), else the plainest.
		var pick = func(gear):
			var p = pool.filter(func(e): return variation_for(e, gear) != null)
			if p.is_empty():
				return null
			p = p.slice(0, mini(3, p.size()))
			var e = p[int(Rng.make_rng("try:" + today).next() * p.size()) % p.size()]
			var v = str(variation_for(e, gear))
			return {"name": LiftNames.join(str(e.name), v), "move": str(e.name), "variation": v, "part": str(e.part),
				"partName": LiftLibrary.part_name(str(e.part)), "tip": str(e.tip)}
		new = pick.call(here)
		new_at = {"gym": pick.call(null), "home": pick.call(gear_at(settings, "home"))}
	var pt = []
	for r in Pt.status(before, marks, today):
		if str(r.state) != "done":
			pt.append(r)
	# The ways to do each lift, here and at either place (PT as it is).
	var hist = LiftLibrary.stats(before)
	var avoid = lifts.map(func(l): return Xp.normalize_exercise(str(LiftNames.split(str(l.name)).move)))
	if new != null:
		avoid.append(Xp.normalize_exercise(str(new.move)))
	var home = gear_at(settings, "home")
	for l in lifts:
		var own = {"name": str(l.name), "move": str(LiftNames.split(str(l.name)).move), "variation": str(LiftNames.split(str(l.name)).variation),
			"new": false, "last": l.last.sets, "lastDate": str(l.last.date)}
		if bool(l.pt):
			l["gym"] = [own]
			l["home"] = [own]
		else:
			l["gym"] = options_for(str(l.name), hist, null, avoid)
			l["home"] = options_for(str(l.name), hist, home, avoid)
			if l.home.is_empty():
				l.home = [own]
		l["options"] = l[place]
	var label = str(KIND_NAMES.get(kind, "")) if kind != "" else str(GROUP_NAMES.get(group, ""))
	return {"date": today, "lifts": lifts, "group": group, "label": label, "new": new,
		"pt": pt, "others": likely_others(before, today), "split": split if not cycle.is_empty() else "auto",
		"cycle": cycle, "kind": kind, "after": dk.after, "afterDate": dk.afterDate, "picked": dk.picked, "place": place,
		"newAt": new_at}


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
	out.append(_mission("t:%s:show" % today, "daily", today, "Show up", "Log any workout today.", "flame", null, 1, todays.size(), "sessions", 150, claims))

	# Beat last time: the likeliest lifts that are not physical therapy.
	var beats = 0
	for l in plan.lifts:
		if beats >= BEAT_MISSIONS or bool(l.pt):
			continue
		# Shown as the first way to do it where the player is; done by any way at
		# either place (the id stays the planned lift's).
		var main = l.options[0]
		var aim = LiftTrend.next_target(main.last, _step_kg(wu))
		var desc = ""
		if bool(main.new):
			desc = "New: %s. Find a weight you can do for 8 to 12 good reps." % short_name(str(main.name))
		else:
			desc = "Last time %s. Aim for %s." % [LiftHistory.describe_sets(main.last, fmt_w), LiftHistory.describe_sets(aim.sets, fmt_w)]
		var alts = []
		for o in l.options.slice(1):
			alts.append(short_name(str(o.name)))
		if not alts.is_empty():
			desc += " Or: %s." % ", ".join(PackedStringArray(alts))
		var ways = []
		for o in l.gym + l.home:
			if not ways.has(str(o.name)):
				ways.append(str(o.name))
		out.append(_mission("t:%s:beat:%s" % [today, Xp.normalize_exercise(str(l.name))], "daily", today, "Beat it: %s" % str(main.move), desc, "sword", "lift",
			1, 1 if beat_any(sessions, ways, str(LiftNames.split(str(l.name)).move), today) else 0, "", 200, claims,
			{"lift": str(main.name), "why": str(l.why), "aim": aim.sets, "ways": ways, "options": l.options.map(func(o): return str(o.name)),
				"homeWays": l.home.map(func(o): return str(o.name)), "planned": str(l.name)}))
		beats += 1

	if plan.new != null:
		# Done by the movement suggested, or by any movement never done before.
		var nw = plan.new
		var known = {}
		for s in sessions:
			if str(s.get("discipline", "")) == "lift" and str(s.get("date", "")) < today:
				for ex in s.get("exercises", []):
					known[Xp.normalize_exercise(str(LiftNames.split(str(ex.get("name", ""))).move))] = true
		var did = false
		for s in todays:
			for ex in s.get("exercises", []):
				var mk = Xp.normalize_exercise(str(LiftNames.split(str(ex.get("name", ""))).move))
				if str(s.get("discipline", "")) == "lift" and (mk == Xp.normalize_exercise(str(nw.move)) or not known.has(mk)):
					did = true
		out.append(_mission("t:%s:new" % today, "daily", today, "Try something new", "%s: a %s movement you haven't done yet." % [str(nw.name), str(nw.partName).to_lower()], "sparkle", "lift",
			1, 1 if did else 0, "", 200, claims, {"lift": str(nw.name)}))

	if not plan.pt.is_empty():
		var names = []
		var done = 0
		for r in plan.pt:
			names.append(str(r.name))
			if not sets_on(sessions, str(r.name), today).is_empty():
				done += 1
		out.append(_mission("t:%s:pt" % today, "daily", today, "Physical therapy", "Still to do this week: %s." % ", ".join(PackedStringArray(names)), "pt", null,
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
			out.append(_mission("t:%s:%s" % [today, disc], "daily", today, title, "%s. Go %s." % [str(o.why), Fmt.fmt_distance(dist_m, du)], disc if disc != "misc" else "vest",
				disc if disc != "misc" else null, dist_m, progress, "m", 200, claims))

	if not data.get("reading", []).is_empty():
		var goal = Reading.goal(settings)
		var pages = 0
		for r in data.get("reading", []):
			if str(r.get("date", "")) == today:
				pages += int(r.get("pages", 0))
		out.append(_mission("t:%s:read" % today, "daily", today, "Read", "Read %d pages today." % goal, "book", null, goal, pages, "pages", 100, claims))

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

	if int(state.get("body", {}).get("entries", 0)) > 0:
		var checked = 1 if int(state.body.get("weekFlags", {}).get(wk, 0)) > 0 else 0
		out.append(_mission("tw:%s:body" % wk, "weekly", wk, "Check in", "Log your weight or progress photos this week.", "camera", null, 1, checked, "sessions", 150, claims))
	return out


# ---------------------------------------------------------------------------
# For the phone
# ---------------------------------------------------------------------------

## The plan and the day's missions in a few short lines (a phone notification).
static func morning_text(plan: Dictionary, daily_missions: Array, wu: String) -> String:
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var lines = []
	if str(plan.get("kind", "")) != "":
		lines.append("%s. %s." % [str(plan.label), kind_why(plan)])
	elif str(plan.label) != "":
		lines.append("Probably a %s." % str(plan.label).to_lower())
	# Every planned lift (PT aside) and every way to do it: at the gym, what to
	# aim for where it was done before, then the ways at home.
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
		if bool(l.pt) or not l.has("gym") or l.gym.is_empty():
			continue
		var gym = l.gym
		var home = l.get("home", [])
		var first = str(way.call(gym[0]))
		lines.append(first if not bool(gym[0].new) else first + ": find your weight")
		if gym.size() > 1:
			lines.append("  or " + " · ".join(PackedStringArray(gym.slice(1).map(func(o): return str(way.call(o))))))
		var same = home.map(func(o): return str(o.name)) == gym.map(func(o): return str(o.name))
		if same:
			lines.append("  home: the same")
		elif not home.is_empty():
			lines.append("  home: " + " · ".join(PackedStringArray(home.map(func(o): return str(way.call(o))))))
	var try_gym = plan.get("newAt", {}).get("gym") if plan.get("newAt", {}).get("gym") != null else plan.new
	if try_gym != null:
		lines.append("Try: %s" % short_name(str(try_gym.name)))
		var try_home = plan.get("newAt", {}).get("home")
		if try_home != null and str(try_home.name) != str(try_gym.name):
			lines.append("  home: %s" % short_name(str(try_home.name)))
	if not plan.pt.is_empty():
		var names = []
		for r in plan.pt:
			names.append(str(r.name))
		lines.append("PT: %s" % ", ".join(PackedStringArray(names)))
	for o in plan.others.slice(0, 1):
		var why = str(o.why)
		lines.append("%s: %s" % [TT.DISCIPLINE_META[o.discipline].name, why.left(1).to_lower() + why.substr(1)])
	if lines.is_empty():
		lines.append("No pattern for today yet: anything counts.")
	return "\n".join(PackedStringArray(lines))
