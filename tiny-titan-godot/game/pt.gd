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
##   summary(rows)                      the totals of this week
##
## A week runs Monday to Sunday, like the game's other weeks. A day counts once
## however many sets were done. Pure logic: tests/pt_test.gd.

const DEFAULT_PER_WEEK = 3
const MAX_PER_WEEK = 7

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


static var _lib_keys = null


## The key a lift is marked under, "" when it is not PT. A mark on another name
## of the same library lift ("heel raise" for Calf Raise) covers it.
static func mark_of(marks: Dictionary, lift_name: String) -> String:
	var k = key(lift_name)
	if marks.has(k):
		return k
	if marks.is_empty() or k == "":
		return ""
	if _lib_keys == null:
		_lib_keys = []
		for e in LiftLibrary.catalog():
			_lib_keys.append(e.keys)
	for keys in _lib_keys:
		if keys.has(k):
			for other in keys:
				if marks.has(str(other)):
					return str(other)
			return ""
	return ""


static func is_pt(marks: Dictionary, lift_name: String) -> bool:
	return mark_of(marks, lift_name) != ""


## Days a week the player aims for with this lift.
static func per_week(marks: Dictionary, lift_name: String) -> int:
	var m = marks.get(mark_of(marks, lift_name))
	if not (m is Dictionary):
		return DEFAULT_PER_WEEK
	return clampi(int(m.get("perWeek", DEFAULT_PER_WEEK)), 1, MAX_PER_WEEK)


## How the player is doing with every PT lift, the one most in need first:
## [{key, name, perWeek, count (sessions ever), last (date or ""), daysSince
##   (-1 = never), week: [7 x bool, Monday first], thisWeek (days done), left
##   (days still to do this week), state, weeks: [{week, n, hit}] oldest first
##   (the current week last), run (weeks on target in a row), days: {date: true},
##   history (newest first)}]
## state: "done" (this week's days are in), "on" (still on track for them),
##        "behind" (not enough days left in the week).
static func status(sessions: Array, marks: Dictionary, today: String, weeks: int = 8) -> Array:
	var out = []
	if marks.is_empty():
		return out
	var claimed = {}
	for row in LiftLibrary.rows(sessions):
		var mine = ""
		for k in row.keys:
			if marks.has(str(k)):
				mine = str(k)
				break
		if mine == "":
			continue
		for k in row.keys:
			claimed[str(k)] = true
		var shown = str(row.st.name) if row.st != null else str(marks[mine].get("name", row.name))
		out.append(_row(mine, shown, row.st.history if row.st != null else [], per_week(marks, mine), today, weeks))
	# Marked, never done, and not a library lift: it still has a row.
	for k in marks:
		if not claimed.has(str(k)):
			out.append(_row(str(k), str(marks[k].get("name", k)), [], per_week(marks, str(k)), today, weeks))
	var rank = {"behind": 0, "on": 1, "done": 2}
	TTUtil.stable_sort(out, func(a, b):
		if rank[a.state] != rank[b.state]:
			return rank[a.state] < rank[b.state]
		if int(a.left) != int(b.left):
			return int(a.left) > int(b.left)
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return out


static func _row(k: String, shown: String, history: Array, goal: int, today: String, n_weeks: int) -> Dictionary:
	var days = LiftTrend.days_done(history)
	var monday = Dates.week_key(today)
	var week = []
	var this_week = 0
	for d in range(7):
		var on = days.has(Dates.add_days(monday, d))
		week.append(on)
		if on:
			this_week += 1
	var last = ""
	for d in days:
		if str(d) > last and str(d) <= today:
			last = str(d)
	var left = maxi(0, goal - this_week)
	# Days that can still count: today (unless it is done) through Sunday.
	var open_days = 7 - Dates.weekday_index(today) - (1 if days.has(today) else 0)
	var state = "done" if left == 0 else ("on" if left <= open_days else "behind")
	var per = []
	for w in LiftTrend.per_week(history, today, n_weeks):
		per.append({"week": w.week, "n": int(w.n), "hit": int(w.n) >= goal})
	var run = 1 if state == "done" else 0
	for i in range(per.size() - 2, -1, -1):
		if not per[i].hit:
			break
		run += 1
	return {"key": k, "name": shown, "perWeek": goal, "count": history.size(), "last": last,
		"daysSince": Dates.days_between(last, today) if last != "" else -1,
		"week": week, "thisWeek": this_week, "left": left, "state": state,
		"weeks": per, "run": run, "days": days, "history": history}


## This week in all: {"lifts", "done" (days done, none counted past its goal),
## "goal" (days aimed for), "behind" (lifts that cannot make it), "left"}.
static func summary(rows: Array) -> Dictionary:
	var done = 0
	var goal = 0
	var behind = 0
	for r in rows:
		done += mini(int(r.thisWeek), int(r.perWeek))
		goal += int(r.perWeek)
		if r.state == "behind":
			behind += 1
	return {"lifts": rows.size(), "done": done, "goal": goal, "behind": behind, "left": maxi(0, goal - done)}
