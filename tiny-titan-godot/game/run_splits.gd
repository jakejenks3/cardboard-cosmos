class_name RunSplits
extends RefCounted
## Best splits inside a run: the fastest mile, 5K, 10K... run somewhere within
## a longer run (the user, 2026-11-23: "if I run 13.1 miles, game will
## automatically know to add a field to input my best mile, 5k, 10k split etc.
## Normal distances within that distance I ran").
##
## STORED on the run session: session.splits = {id: seconds}, only what was
## typed, absent when there is none. Nothing in the rules reads it (no XP, no
## level, no trophy), so the parity tests are untouched. A run that IS one of
## the distances (13.1 miles is a half marathon, 3.1 miles a 5K: SHORT, NEAR)
## has that distance's time by itself, from its own duration, with nothing to
## type.
##
## The RULES go by the same reading of a distance (`counted`): the race
## trophies and gear and the fastest pace over a 5K. The user, 2026-11-23,
## asked whether runs typed as 3.1, 6.2, 13.1 and 26.2 miles should earn them
## though each is a few metres short of the metric distance: "Yes".
##
## Pure logic. The Log tab's run form offers the fields (LogSessionForm), a
## session's sheet lists them (SessionView), Journey -> Stats has the best of
## each (the running card) and the results reel celebrates a new best (App).

## The distances, shortest first. "units": who is asked for it (a player who
## counts in km the kilometre, one who counts in miles the mile and the ten
## miles); a split stored under any id is shown to everyone.
const DISTS = [
	{"id": "1k", "m": 1000.0, "name": "1 km", "ask": "Best km", "best": "Fastest km", "units": ["km"]},
	{"id": "mile", "m": 1609.344, "name": "Mile", "ask": "Best mile", "best": "Fastest mile", "units": ["mi"]},
	{"id": "5k", "m": 5000.0, "name": "5K", "ask": "Best 5K", "best": "Fastest 5K", "units": ["km", "mi"]},
	{"id": "10k", "m": 10000.0, "name": "10K", "ask": "Best 10K", "best": "Fastest 10K", "units": ["km", "mi"]},
	{"id": "10mi", "m": 16093.44, "name": "10 mile", "ask": "Best 10 mile", "best": "Fastest 10 mile", "units": ["mi"]},
	{"id": "half", "m": 21097.5, "name": "Half marathon", "ask": "Best half", "best": "Fastest half marathon", "units": ["km", "mi"]},
	{"id": "full", "m": 42195.0, "name": "Marathon", "ask": "Best marathon", "best": "Fastest marathon", "units": ["km", "mi"]},
]
## A run this little SHORT of a distance still counts as it. The miles a race
## is written as are a few metres under the metric distance: 3.1 miles are
## 4,989 m of a 5K's 5,000 (0.22% short), 6.2 miles 9,978 of 10,000, 13.1 miles
## 21,082 of the half marathon's 21,097.5 (0.07%), 26.2 miles 42,165 of 42,195.
## A tenth of a mile less (3.0, 6.1, 13.0, 26.1) is not the race.
const SHORT = 0.0025
## A run up to this much PAST a distance is still that distance (its time is
## the distance's own); one further past has the distance inside it.
const NEAR = 0.01


static func by_id(id: String):
	for d in DISTS:
		if str(d.id) == id:
			return d
	return null


## The distance a run of `distance_m` is (from SHORT under it to NEAR past
## it), or "".
static func whole(distance_m: float) -> String:
	for d in DISTS:
		var m = float(d.m)
		if distance_m >= m * (1.0 - SHORT) and distance_m <= m * (1.0 + NEAR):
			return str(d.id)
	return ""


## What a run of `distance_m` counts as for a rule that asks for a distance
## (the trophy for a half marathon, the gear for a 10K, the fastest pace over
## a 5K): a run SHORT of one of the distances counts as that distance, any
## other run as what it is (the very value passed in, so a whole number stays
## one). The records themselves (the longest run) stay as they were typed.
static func counted(distance_m):
	if not (distance_m is int or distance_m is float):
		return distance_m
	var v = float(distance_m)
	for d in DISTS:
		var m = float(d.m)
		if v < m and v >= m * (1.0 - SHORT):
			return m
	return distance_m


## Is this distance clearly inside a run of `distance_m` (so it has a best
## split of its own, apart from the run's time)?
static func fits(id: String, distance_m: float) -> bool:
	var d = by_id(id)
	return d != null and distance_m > float(d.m) * (1.0 + NEAR)


## The distances to ask a best split for in a run of `distance_m`, shortest
## first: the ones inside it that a player counting in `du` ("km" | "mi") is
## asked for, and any of `also` (ids that already have a time) that fit.
static func offered(distance_m: float, du: String, also: Array = []) -> Array:
	var out = []
	for d in DISTS:
		if fits(str(d.id), distance_m) and (d.units.has(du) or also.has(str(d.id))):
			out.append(str(d.id))
	return out


## Seconds from what was typed, 0 when it is no time. A phone's number pad has
## a dot and no colon, so every way of writing a time works:
##   "7:45", "7.45", "7 45"      7 min 45 s
##   "1:02:03", "1.02.03"         1 h 2 min 3 s
##   "745", "2610", "10203"       the last two digits are seconds, the two
##                                before them minutes, the rest hours
##   "8", "45"                    one or two digits alone are minutes
static func parse_time(text: String) -> int:
	var t = text.strip_edges()
	if t == "":
		return 0
	var parts = []
	var cur = ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			cur += ch
		elif ch == ":" or ch == "." or ch == "," or ch == " " or ch == ";":
			if cur != "":
				parts.append(cur)
			cur = ""
		else:
			return 0
	if cur != "":
		parts.append(cur)
	if parts.is_empty() or parts.size() > 3:
		return 0
	var h = 0
	var m = 0
	var s = 0
	if parts.size() == 1:
		var d = str(parts[0])
		if d.length() > 6:
			return 0
		if d.length() <= 2:
			m = int(d)
		else:
			s = int(d.right(2))
			var rest = d.left(d.length() - 2)
			m = int(rest.right(2))
			h = int(rest.left(rest.length() - 2)) if rest.length() > 2 else 0
			if h > 0 and m >= 60:
				return 0
	elif parts.size() == 2:
		m = int(str(parts[0]))
		s = int(str(parts[1]))
	else:
		h = int(str(parts[0]))
		m = int(str(parts[1]))
		s = int(str(parts[2]))
		if m >= 60:
			return 0
	if s >= 60:
		return 0
	return h * 3600 + m * 60 + s


## "7:45", "26:10", "1:02:03".
static func fmt_time(sec) -> String:
	return Fmt.fmt_duration(float(sec))


## The splits of a run session, {id: seconds}: what was typed (a known
## distance, a time above zero) and, for a run that is one of the distances,
## that distance from the run's own time. {} for anything but a run.
static func of_session(s: Dictionary) -> Dictionary:
	var out = {}
	if str(s.get("discipline", "")) != "run":
		return out
	var sp = s.get("splits")
	if sp is Dictionary:
		for id in sp:
			var v = sp[id]
			if by_id(str(id)) != null and (v is int or v is float) and float(v) > 0.0:
				out[str(id)] = int(round(float(v)))
	var w = whole(float(s.get("distanceM", 0.0)) if (s.get("distanceM") is int or s.get("distanceM") is float) else 0.0)
	var dur = s.get("durationSec")
	if w != "" and not out.has(w) and (dur is int or dur is float) and float(dur) > 0.0:
		out[w] = int(round(float(dur)))
	return out


## A split's pace, seconds per km.
static func pace(id: String, sec: float) -> float:
	var d = by_id(id)
	return sec / (float(d.m) / 1000.0) if d != null else 0.0


## Is a split slower than the whole run's average pace? A BEST split cannot
## be, so it is a typing slip. False when it cannot be told.
static func slower_than_run(id: String, sec: float, distance_m: float, duration_sec: float) -> bool:
	var d = by_id(id)
	if d == null or sec <= 0.0 or distance_m <= 0.0 or duration_sec <= 0.0:
		return false
	return sec / float(d.m) > duration_sec / distance_m * 1.005


## The splits of a session to show, shortest first: [{"id", "name", "sec",
## "pace" (seconds per km), "whole" (it is the run itself)}].
static func rows(s: Dictionary) -> Array:
	var sp = of_session(s)
	var w = whole(float(s.get("distanceM", 0.0)) if (s.get("distanceM") is int or s.get("distanceM") is float) else 0.0)
	var typed = s.get("splits") if s.get("splits") is Dictionary else {}
	var out = []
	for d in DISTS:
		var id = str(d.id)
		if sp.has(id):
			out.append({"id": id, "name": str(d.name), "sec": int(sp[id]), "pace": pace(id, float(sp[id])), "whole": id == w and not typed.has(id)})
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("date", "")) != str(b.get("date", "")):
		return str(a.get("date", "")) < str(b.get("date", ""))
	return float(a.get("createdAt", 0)) < float(b.get("createdAt", 0))


## The best time over each distance in the log: {id: {"sec", "date",
## "sessionId"}} (of equal times the earliest).
static func bests(sessions: Array) -> Dictionary:
	var runs = sessions.filter(func(s): return str(s.get("discipline", "")) == "run")
	TTUtil.stable_sort(runs, RunSplits._before)
	var out = {}
	for s in runs:
		var sp = of_session(s)
		for id in sp:
			if not out.has(id) or int(sp[id]) < int(out[id].sec):
				out[id] = {"sec": int(sp[id]), "date": str(s.get("date", "")), "sessionId": str(s.get("id", ""))}
	return out


## The bests `fresh` sessions set against the log `before` them, shortest
## distance first: [{"id", "sec", "was"}]. Only where there was a time to
## beat: a first time over a distance is no record yet.
static func records(before: Array, fresh: Array) -> Array:
	var old = bests(before)
	var got = bests(fresh)
	var out = []
	for d in DISTS:
		var id = str(d.id)
		if old.has(id) and got.has(id) and int(got[id].sec) < int(old[id].sec):
			out.append({"id": id, "sec": int(got[id].sec), "was": int(old[id].sec)})
	return out
