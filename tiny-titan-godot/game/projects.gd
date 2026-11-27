class_name Projects
extends RefCounted
## Climbing projects: a boulder or route the player is working on until they
## send it. The list is STORED (`saved.projects`), the progress is worked out
## from the log: every climb session since the project was picked with that
## grade in it is a session on it, and its attempts are counted.
##
## A project: {id, grade (boulder grade, the V number), yds ("" for a boulder,
## "5.11a" for a route), name ("" or the player's words), since (date picked),
## sent ("" or the date), sessionId (the session it went in), aside ("" or the
## date it was set aside)}. Nothing is ever deleted: a project is sent or set
## aside, and can be brought back.
##
## Sending one pays SEND_XP through a claim (questId "project:<id>"), so XP and
## coins come from the replay like a mission's.

const SEND_XP = 250
## How many open projects at once (more is not a project, it is a list).
const MAX_OPEN = 6


static func new_project(grade: int, yds: String, name: String, today: String) -> Dictionary:
	return {"id": Rng.uid("pj"), "grade": grade, "yds": yds, "name": name.strip_edges(), "since": today,
		"sent": "", "sessionId": "", "aside": ""}


## The saved list, cleaned (anything that is not a project is left out).
static func parse(raw) -> Array:
	var out = []
	if not (raw is Array):
		return out
	for p in raw:
		if not (p is Dictionary) or not (p.get("id") is String) or not (p.get("grade") is int or p.get("grade") is float):
			continue
		out.append({"id": str(p.id), "grade": int(p.grade), "yds": str(p.get("yds", "")), "name": str(p.get("name", "")),
			"since": str(p.get("since", "")), "sent": str(p.get("sent", "")), "sessionId": str(p.get("sessionId", "")),
			"aside": str(p.get("aside", ""))})
	return out


static func is_route(p: Dictionary) -> bool:
	return str(p.get("yds", "")) != ""


## "V5" or "5.11a".
static func grade_text(p: Dictionary) -> String:
	return str(p.yds) if is_route(p) else Xp.grade_label(int(p.grade))


## "V5 · Blue overhang" (or the grade alone).
static func title(p: Dictionary) -> String:
	return grade_text(p) + ((" · " + str(p.name)) if str(p.name) != "" else "")


static func is_open(p: Dictionary) -> bool:
	return str(p.sent) == "" and str(p.aside) == ""


## Is a climb entry ({grade, result, count, style?, yds?}) on this project's grade?
static func matches(p: Dictionary, c: Dictionary) -> bool:
	if is_route(p):
		return Xp.is_route(c) and str(c.get("yds", "")) == str(p.yds)
	return not Xp.is_route(c) and int(c.get("grade", -99)) == int(p.grade)


## What one session did on a project's grade: {tries, sends} (0, 0 when nothing).
static func on_grade(p: Dictionary, session: Dictionary) -> Dictionary:
	var out = {"tries": 0, "sends": 0}
	if str(session.get("discipline", "")) != "climb":
		return out
	for c in session.get("climbs", []):
		if not (c is Dictionary) or not matches(p, c):
			continue
		var n = maxi(0, int(c.get("count", 0)))
		if str(c.get("result", "")) == "attempt":
			out.tries += n
		else:
			out.sends += n
	return out


## A project's progress from the log: {sessions, tries (attempts, not counting
## the send), days (since it was picked, to the send or today), last (date of
## the last session on it or "")}. Sessions after the send do not count.
static func status(p: Dictionary, sessions: Array, today: String) -> Dictionary:
	var end = str(p.sent) if str(p.sent) != "" else today
	var n = 0
	var tries = 0
	var last = ""
	for s in sessions:
		var d = str(s.get("date", ""))
		if d < str(p.since) or d > end:
			continue
		var g = on_grade(p, s)
		if int(g.tries) + int(g.sends) == 0:
			continue
		n += 1
		tries += int(g.tries)
		if d > last:
			last = d
	return {"sessions": n, "tries": tries, "days": maxi(0, Dates.days_between(str(p.since), end)), "last": last}


## Open projects whose grade a session SENT (the reel asks "was it your project?").
static func sent_in(projects: Array, session: Dictionary) -> Array:
	var out = []
	for p in projects:
		if is_open(p) and str(session.get("date", "")) >= str(p.since) and int(on_grade(p, session).sends) > 0:
			out.append(p)
	return out


## Open projects a session TRIED without sending.
static func tried_in(projects: Array, session: Dictionary) -> Array:
	var out = []
	for p in projects:
		if not is_open(p) or str(session.get("date", "")) < str(p.since):
			continue
		var g = on_grade(p, session)
		if int(g.tries) > 0 and int(g.sends) == 0:
			out.append(p)
	return out


## The latest session since a project was picked that sent its grade, or null
## (for "I sent it" on the projects sheet).
static func last_send(p: Dictionary, sessions: Array):
	var best = null
	for s in sessions:
		if str(s.get("date", "")) < str(p.since) or int(on_grade(p, s).sends) == 0:
			continue
		if best == null or str(s.date) > str(best.date):
			best = s
	return best


## "4 sessions · 23 tries · 12 days", the progress in words.
static func progress_text(st: Dictionary) -> String:
	var bits = PackedStringArray()
	bits.append("%d session%s" % [int(st.sessions), "" if int(st.sessions) == 1 else "s"])
	if int(st.tries) > 0:
		bits.append("%d tr%s" % [int(st.tries), "y" if int(st.tries) == 1 else "ies"])
	bits.append("%d day%s" % [int(st.days), "" if int(st.days) == 1 else "s"])
	return " · ".join(bits)
