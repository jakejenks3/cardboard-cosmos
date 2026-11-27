class_name Pt
extends RefCounted
## Physical therapy exercises: lifts the player marked with "(PT)", and how
## well they are keeping up with them.
##
## Which lifts are PT is stored, not derived: `saved.pt` = {normalized lift
## name: {"name": as shown, "perWeek": days a week to aim for}}. A lift gets
## there when a "(PT) ..." line is imported from the phone note or typed in the
## Log tab (App.absorb_pt strips the tag from the name), or by the switch on
## the lift's page. Being PT changes no XP and no rule: it is a way of looking
## at the log.
##
##   untag(text)                        "(PT) wrist curls" -> {pt: true, name: "wrist curls"}
##   status(sessions, marks, today)     one row per PT lift: this week, the weeks before, the run
##   summary(rows)                      the totals of this week, in sets
##
## A week runs Monday to Sunday, like the game's other weeks. PT is counted in
## SETS (the user, 2026-11-25: "Sometimes I'll just do a set and want to make
## sure that doesn't get counted as much as if I did 3 sets of the same
## thing"): a day of a PT lift counts up to SETS_A_DAY of its real sets (sets
## with reps), so one set is a third of a day and a fifth set adds nothing.
## The goal is still stored as DAYS a week (`perWeek`, the Aim for stepper);
## the week's target is perWeek x SETS_A_DAY sets. Pure logic:
## tests/lift_trend_test.gd.

const DEFAULT_PER_WEEK = 3
const MAX_PER_WEEK = 7
## One exercise's full dose on a day: sets past this on one day do not count.
const SETS_A_DAY = 3

static var _rx_cache = {}


static func _rx(pattern: String) -> RegEx:
	if not _rx_cache.has(pattern):
		var r = RegEx.new()
		r.compile(pattern)
		_rx_cache[pattern] = r
	return _rx_cache[pattern]


## Take the PT tag off a lift name or a note line: "(PT) x", "[pt] x",
## "pt: x", "x (PT)". Returns {"pt": was it there, "name": the text without it}.
static func untag(text: String) -> Dictionary:
	var t = text.strip_edges()
	var m = _rx("^(?i)(?:(?:\\(\\s*pt\\s*\\)|\\[\\s*pt\\s*\\])\\s*[:\\-]?|pt\\s*:)\\s*").search(t)
	if m != null and m.get_end() > 0:
		return {"pt": true, "name": t.substr(m.get_end()).strip_edges()}
	m = _rx("(?i)\\s(?:\\(\\s*pt\\s*\\)|\\[\\s*pt\\s*\\])(?=\\s|$|[:,\\-])").search(t)
	if m != null:
		return {"pt": true, "name": (t.substr(0, m.get_start()) + t.substr(m.get_end())).strip_edges()}
	return {"pt": false, "name": t}


static func key(lift_name: String) -> String:
	return Xp.normalize_exercise(lift_name)


## The key a lift is marked under, "" when it is not PT. A mark is on one lift,
## movement and variation together ("Romanian Deadlift - Single leg"): the other
## variations of the movement are not PT.
static func mark_of(marks: Dictionary, lift_name: String) -> String:
	var k = key(lift_name)
	return k if marks.has(k) else ""


static func is_pt(marks: Dictionary, lift_name: String) -> bool:
	return mark_of(marks, lift_name) != ""


## Days a week the player aims for with this lift.
static func per_week(marks: Dictionary, lift_name: String) -> int:
	var m = marks.get(mark_of(marks, lift_name))
	if not (m is Dictionary):
		return DEFAULT_PER_WEEK
	return clampi(int(m.get("perWeek", DEFAULT_PER_WEEK)), 1, MAX_PER_WEEK)


## How the player is doing with every PT lift, the one most in need first:
## [{key, name, perWeek (days a week aimed for), count (sessions ever), last
##   (date or ""), daysSince (-1 = never), week: [7 x bool, Monday first: a set
##   that day], weekShare: [7 floats, Monday first: the day's credit / SETS_A_DAY],
##   thisWeek (days with a set), daySets: {date: real sets that day}, sets (this
##   week's credit: each day's sets up to SETS_A_DAY), setsGoal (perWeek x
##   SETS_A_DAY), left (SETS still to do this week), state, weeks: [{week, n
##   (that week's set credit), hit}] oldest first (the current week last), run
##   (weeks on target in a row), days: {date: true}, history (newest first)}]
## state: "done" (this week's sets are in), "on" (they still fit in what is
##        left of the week: today's room and SETS_A_DAY a day after it),
##        "behind" (they do not).
static func status(sessions: Array, marks: Dictionary, today: String, weeks: int = 8) -> Array:
	var out = []
	if marks.is_empty():
		return out
	var all = LiftLibrary.stats(sessions)
	for k in marks:
		var st = all.get(str(k))
		var shown = str(st.name) if st != null else str(marks[k].get("name", k))
		out.append(_row(str(k), shown, st.history if st != null else [], per_week(marks, str(k)), today, weeks))
	var rank = {"behind": 0, "on": 1, "done": 2}
	TTUtil.stable_sort(out, func(a, b):
		if rank[a.state] != rank[b.state]:
			return rank[a.state] < rank[b.state]
		if int(a.left) != int(b.left):
			return int(a.left) > int(b.left)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


## The status row (as in `status`) of the PT mark a lift is under, null when
## the lift is not PT. For a lift's own page: its PT card, the Logbook's bars.
static func row_of(sessions: Array, marks: Dictionary, lift_name: String, today: String, weeks: int = 8):
	var k = mark_of(marks, lift_name)
	if k == "":
		return null
	for r in status(sessions, marks, today, weeks):
		if str(r.key) == k:
			return r
	return null


## What one day of a lift counts for: its real sets, at most SETS_A_DAY.
static func credit(day_sets: Dictionary, date: String) -> int:
	return mini(int(day_sets.get(date, 0)), SETS_A_DAY)


## A Monday-week's set credit: each day's sets up to SETS_A_DAY, added up.
static func week_credit(day_sets: Dictionary, monday: String) -> int:
	var n = 0
	for d in range(7):
		n += credit(day_sets, Dates.add_days(monday, d))
	return n


static func _row(k: String, shown: String, history: Array, goal: int, today: String, n_weeks: int) -> Dictionary:
	# Real sets per day (two sessions on a day are one day of the lift).
	var day_sets = {}
	var days = {}
	for row in LiftTrend.by_day(history):
		day_sets[str(row.date)] = int(row.sets)
		days[str(row.date)] = true
	var monday = Dates.week_key(today)
	var week = []
	var share = []
	var this_week = 0
	var sets = 0
	for d in range(7):
		var date = Dates.add_days(monday, d)
		var on = days.has(date)
		week.append(on)
		if on:
			this_week += 1
		var got = credit(day_sets, date)
		sets += got
		share.append(got / float(SETS_A_DAY))
	var last = ""
	for d in days:
		if str(d) > last and str(d) <= today:
			last = str(d)
	var sets_goal = goal * SETS_A_DAY
	var left = maxi(0, sets_goal - sets)
	# Sets that can still count: what today has room for, then a full day's
	# worth for each day after it through Sunday.
	var room = (SETS_A_DAY - credit(day_sets, today)) + SETS_A_DAY * (6 - Dates.weekday_index(today))
	var state = "done" if left == 0 else ("on" if left <= room else "behind")
	var per = []
	for i in range(n_weeks - 1, -1, -1):
		var wk = Dates.add_weeks(monday, -i)
		var n = week_credit(day_sets, wk)
		per.append({"week": wk, "n": n, "hit": n >= sets_goal})
	var run = 1 if state == "done" else 0
	for i in range(per.size() - 2, -1, -1):
		if not per[i].hit:
			break
		run += 1
	return {"key": k, "name": shown, "perWeek": goal, "count": history.size(), "last": last,
		"daysSince": Dates.days_between(last, today) if last != "" else -1,
		"week": week, "weekShare": share, "thisWeek": this_week, "daySets": day_sets,
		"sets": sets, "setsGoal": sets_goal, "left": left, "state": state,
		"weeks": per, "run": run, "days": days, "history": history}


## This week in all, in SETS: {"lifts", "done" (sets done, none counted past
## its lift's goal), "goal" (sets aimed for), "behind" (lifts that cannot make
## it), "left"}.
static func summary(rows: Array) -> Dictionary:
	var done = 0
	var goal = 0
	var behind = 0
	for r in rows:
		done += mini(int(r.sets), int(r.setsGoal))
		goal += int(r.setsGoal)
		if r.state == "behind":
			behind += 1
	return {"lifts": rows.size(), "done": done, "goal": goal, "behind": behind, "left": maxi(0, goal - done)}
