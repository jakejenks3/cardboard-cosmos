class_name ClimbLadder
extends RefCounted
## Climbing outcomes per grade, for the Journey tab (pure, from the log).
##
## Every climb entry is one of three outcomes, `count` times:
##   "flash"    sent on the first go
##   "send"     sent, but not on the first go
##   "attempt"  a try that did not go
## A flash IS a send: "sent" = flashes + sends. "tries" = all three.
## Boulders and roped routes are counted apart (`routes`): a boulder's grade
## is its V grade (VB = -1), a route's is its YDS index (Xp.YDS_GRADES).
##
##   ladder(sessions, routes) -> {
##     rows: [{grade, label, flash, send, attempt, sent, tries, sessions,
##             firstSent, firstFlash, last}]  hardest first, every grade from
##             the hardest tried down to the easiest tried (empty ones too),
##     total: {flash, send, attempt, sent, tries},
##     hardestSent, hardestFlash  (grade or null)}


static func grade_of(c: Dictionary, routes: bool) -> int:
	if routes:
		return Xp.yds_index(c.get("yds", ""))
	return int(c.get("grade", 0))


static func label(g: int, routes: bool) -> String:
	return Xp.yds_label(g) if routes else Xp.grade_label(g)


static func has_routes(sessions: Array) -> bool:
	for s in sessions:
		if str(s.get("discipline", "")) != "climb":
			continue
		for c in s.get("climbs", []):
			if c is Dictionary and Xp.is_route(c):
				return true
	return false


static func has_boulders(sessions: Array) -> bool:
	for s in sessions:
		if str(s.get("discipline", "")) != "climb":
			continue
		for c in s.get("climbs", []):
			if c is Dictionary and not Xp.is_route(c):
				return true
	return false


## Whole percent, 0 when there is nothing to divide by.
static func pct(n: int, of: int) -> int:
	return int(round(100.0 * float(n) / float(of))) if of > 0 else 0


static func _empty_row(g: int, routes: bool) -> Dictionary:
	return {"grade": g, "label": label(g, routes), "flash": 0, "send": 0, "attempt": 0, "sent": 0,
		"tries": 0, "sessions": 0, "firstSent": "", "firstFlash": "", "last": ""}


static func ladder(sessions: Array, routes: bool) -> Dictionary:
	var by = {}
	var seen = {}
	for s in sessions:
		if str(s.get("discipline", "")) != "climb":
			continue
		var d = str(s.get("date", ""))
		for c in s.get("climbs", []):
			if not (c is Dictionary) or Xp.is_route(c) != routes:
				continue
			var g = grade_of(c, routes)
			if routes and g < 0:
				continue
			var n = maxi(0, int(c.get("count", 1)))
			if n == 0:
				continue
			if not by.has(g):
				by[g] = _empty_row(g, routes)
			var r = by[g]
			var res = str(c.get("result", "attempt"))
			if res == "flash":
				r.flash += n
				if r.firstFlash == "" or d < r.firstFlash:
					r.firstFlash = d
			elif res == "send":
				r.send += n
			else:
				res = "attempt"
				r.attempt += n
			if res != "attempt" and (r.firstSent == "" or d < r.firstSent):
				r.firstSent = d
			if d > r.last:
				r.last = d
			var key = "%d|%s" % [g, str(s.get("id", d))]
			if not seen.has(key):
				seen[key] = true
				r.sessions += 1
	var total = {"flash": 0, "send": 0, "attempt": 0, "sent": 0, "tries": 0}
	var out = {"rows": [], "total": total, "hardestSent": null, "hardestFlash": null}
	if by.is_empty():
		return out
	var keys = by.keys()
	keys.sort()
	for g in range(int(keys[keys.size() - 1]), int(keys[0]) - 1, -1):
		var r = by.get(g, _empty_row(g, routes))
		r.sent = int(r.flash) + int(r.send)
		r.tries = int(r.sent) + int(r.attempt)
		out.rows.append(r)
		for k in ["flash", "send", "attempt", "sent", "tries"]:
			total[k] += int(r[k])
		if out.hardestSent == null and int(r.sent) > 0:
			out.hardestSent = g
		if out.hardestFlash == null and int(r.flash) > 0:
			out.hardestFlash = g
	return out


## The row to show first: the hardest grade sent, else the hardest tried.
static func default_pick(rows: Array) -> int:
	for i in range(rows.size()):
		if int(rows[i].sent) > 0:
			return i
	return 0 if not rows.is_empty() else -1
