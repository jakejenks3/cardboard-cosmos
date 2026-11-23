class_name Dosage
extends RefCounted
## The training dose as plain text, to paste into a chat with a coach or an AI:
## how often each activity is done, hard sets and weight moved per muscle group
## per week, every lift with its first and latest day, climbing, running, the
## rest, a day-by-day list, what the log does not know, and what to analyse.
## Pure: `text(saved, today)` reads a save's dictionary (sessions, body, pt,
## settings). Journey -> Stats has the key that copies it (JourneyScreen).
##
## Weekly figures are the last WINDOW_DAYS days (or the whole log when it is
## shorter, never fewer than 7 days) scaled to 7. Physical therapy and
## stretches are listed apart and not counted as muscle-building sets. A
## muscle's "direct" sets are those of lifts whose main part it is; "with
## indirect" adds half a set for each set of a lift that also works it (the
## library's "also works", as the muscle map counts it: Recovery.also_parts).
## Nothing here is an estimate of strength: weights are sets really logged.
##
## A lift logged as BOTH SIDES ADDED UP (Sides: a single arm cable raise typed
## as 25 for a 12 and a 13) is marked "L+R" and its reps are given a side as
## well: reps a set and the rep ranges count ONE side of it, so a reader does
## not take 25 for a set of 25 (the user, 2026-11-23). The weight moved is the
## total as logged, which is right.

const WINDOW_DAYS = 28
## Days listed one by one at the end.
const DAYS_LISTED = 28
const REP_BANDS = [[1, 5, "1-5 reps"], [6, 10, "6-10"], [11, 15, "11-15"], [16, 9999, "16+"]]
const OTHER_NAMES = {"climb": "Climbing", "run": "Running", "ride": "Cycling"}


static func _n(v: float, digits: int = 1) -> String:
	return Fmt.fmt_num(v, 0 if is_equal_approx(v, roundf(v)) else digits)


static func _day(key: String, weekday: bool = false) -> String:
	if weekday:
		return Dates.format_date(key, {"weekday": "short", "month": "short", "day": "numeric"})
	return Dates.format_date(key, {"month": "short", "day": "numeric"})


## A lift's body part: the library's, and for a lift of the player's own that
## the library cannot place, "core" when its name says so.
static func part(lift_name: String) -> String:
	var p = Missions.part_of(lift_name)
	if p == "other":
		var low = lift_name.to_lower()
		for w in ["core", "abs", "sit-up", "leg lift", "leg raise"]:
			if low.contains(w):
				return "core"
	return p


## A lift's sets in words. A band has no weight to log: it is not "bodyweight".
## `sides` 2: the reps are both sides added up, and what that is a side is said.
static func sets_words(lift_name: String, sets: Array, fmt_w: Callable, sides: int = 1) -> String:
	var t = LiftHistory.describe_sets(sets, fmt_w)
	if str(LiftNames.split(lift_name).variation).to_lower().contains("band"):
		t = t.replace(" bodyweight", " (a band, no weight)")
	if sides > 1 and Sides.side_words(sets) != "":
		t += " (both sides added up: %s)" % Sides.side_words(sets)
	return t


## Is this exercise mobility work and not a muscle-building lift: marked
## physical therapy, called a stretch, or made of holds only?
static func is_mobility(ex: Dictionary, marks: Dictionary) -> bool:
	var n = str(ex.get("name", ""))
	if Pt.is_pt(marks, n) or n.to_lower().contains("stretch"):
		return true
	var sets = LiftTrend.real_sets(ex.get("sets", []))
	return not sets.is_empty() and sets.all(func(one): return LiftTrend.is_hold(one))


## The numbers behind the text (also what the tests read):
## {from, to, days, weeks, first, count: {discipline: n in the window},
##  days_trained, parts: {part: {direct, indirect, last7, reps, vol}},
##  bands: [n per REP_BANDS], sets, lifts: [..], mobility: [..],
##  both: [names of the lifts logged as both sides added up]}.
## A part's "reps" and the bands count ONE side of a lift logged as both
## sides added up (Sides); "vol" is the weight as logged, both sides.
static func figures(saved: Dictionary, today: String) -> Dictionary:
	var sessions = saved.get("sessions", []).filter(func(s): return str(s.get("date", "")) <= today and str(s.get("date", "")) != "")
	var marks = saved.get("pt", {})
	var settings = saved.get("settings") if saved.get("settings") is Dictionary else {}
	var first = today
	for s in sessions:
		if str(s.date) < first:
			first = str(s.date)
	var span = Dates.days_between(first, today) + 1
	var days = clampi(span, 7, WINDOW_DAYS)
	var from = Dates.add_days(today, -(days - 1))
	var week_from = Dates.add_days(today, -6)
	var out = {"from": from, "to": today, "first": first, "span": span, "days": days, "weeks": days / 7.0, "count": {}, "count7": {},
		"trained": {}, "parts": {}, "bands": [0, 0, 0, 0], "sets": 0, "lifts": {}, "mobility": {}, "sessions": sessions, "both": []}
	for s in sessions:
		var d = str(s.date)
		var disc = str(s.get("discipline", ""))
		if d >= from:
			out.count[disc] = int(out.count.get(disc, 0)) + 1
			out.trained[d] = true
		if d >= week_from:
			out.count7[disc] = int(out.count7.get(disc, 0)) + 1
		if disc != "lift":
			continue
		for ex in s.get("exercises", []):
			var sets = LiftTrend.real_sets(ex.get("sets", []))
			if sets.is_empty():
				continue
			var name = str(ex.get("name", ""))
			var mob = is_mobility(ex, marks)
			var book = out.mobility if mob else out.lifts
			var key = Xp.normalize_exercise(name)
			var sides = Sides.n(settings, name)
			if not book.has(key):
				book[key] = {"name": name, "part": part(name), "days": {}, "sets": 0, "inWindow": 0, "first": null, "last": null, "best": null, "sides": sides}
				if sides > 1:
					out.both.append(name)
			var row = book[key]
			row.days[d] = true
			row.sets = int(row.sets) + sets.size()
			if row.first == null or d < str(row.first.date):
				row.first = {"date": d, "sets": sets}
			if row.last == null or d >= str(row.last.date):
				row.last = {"date": d, "sets": sets}
			for one in sets:
				var kg = float(one.get("weightKg", 0.0))
				var reps = int(one.get("reps", 0))
				if row.best == null or kg > float(row.best.weightKg) or (is_equal_approx(kg, float(row.best.weightKg)) and reps > int(row.best.reps)):
					row.best = {"weightKg": kg, "reps": reps, "date": d}
			if d < from:
				continue
			row.inWindow = int(row.inWindow) + 1
			if mob:
				continue
			var main = str(row.part)
			if not out.parts.has(main):
				out.parts[main] = {"direct": 0.0, "indirect": 0.0, "last7": 0, "reps": 0, "vol": 0.0, "days": {}}
			var p = out.parts[main]
			p.days[d] = true
			p.direct = float(p.direct) + sets.size()
			if d >= week_from:
				p.last7 = int(p.last7) + sets.size()
			for one in sets:
				var reps = int(one.get("reps", 0))
				# (both sides added up: one side did half of it; 25 is a 12 and a 13)
				p.reps = float(p.reps) + Sides.a_side(reps, sides)
				p.vol = float(p.vol) + reps * float(one.get("weightKg", 0.0))
				out.sets = int(out.sets) + 1
				var side_reps = int(ceil(Sides.a_side(reps, sides)))
				for i in range(REP_BANDS.size()):
					if side_reps >= int(REP_BANDS[i][0]) and side_reps <= int(REP_BANDS[i][1]):
						out.bands[i] = int(out.bands[i]) + 1
			for a in Recovery.also_parts(name):
				if a == main:
					continue
				if not out.parts.has(a):
					out.parts[a] = {"direct": 0.0, "indirect": 0.0, "last7": 0, "reps": 0, "vol": 0.0, "days": {}}
				out.parts[a].indirect = float(out.parts[a].indirect) + sets.size() * 0.5
	return out


static func text(saved: Dictionary, today: String) -> String:
	var f = figures(saved, today)
	var settings = saved.get("settings", {})
	var wu = str(settings.get("weightUnit", "kg"))
	var du = str(settings.get("distanceUnit", "km"))
	var marks = saved.get("pt", {})
	var weeks = float(f.weeks)
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var per_week = func(n): return _n(float(n) / weeks)
	var L = []
	L.append("MY TRAINING, FROM MY WORKOUT LOG (Tiny Titan)")
	L.append("Goal: improve my physique: build muscle and lose body fat.")
	if f.sessions.is_empty():
		L.append("Nothing is logged yet.")
		return "\n".join(PackedStringArray(L))
	L.append("Log runs %s to %s (%d days). Weekly figures below are the last %d days scaled to 7%s." % [
		Dates.format_date(str(f.first), {"month": "short", "day": "numeric", "year": "numeric"}), Dates.format_date(today, {"month": "short", "day": "numeric", "year": "numeric"}),
		int(f.span), int(f.days), " (a short log: treat them as rough)" if int(f.span) < 21 else ""])
	L.append("Units: %s, %s." % [wu, du])

	# --- body ---
	L.append("")
	L.append("BODY")
	var body = saved.get("body", []).filter(func(b): return str(b.get("date", "")) <= today)
	body.sort_custom(func(a, b): return str(a.get("date", "")) < str(b.get("date", "")))
	var weighed = body.filter(func(b): return float(b.get("weightKg", 0.0)) > 0.0)
	if weighed.is_empty():
		L.append("- No body weight logged.")
	else:
		var last = weighed[weighed.size() - 1]
		var line = "- Body weight %s on %s" % [fmt_w.call(last.weightKg), _day(str(last.date))]
		if weighed.size() > 1:
			var w0 = weighed[0]
			var diff = Fmt.kg_to_unit(float(last.weightKg) - float(w0.weightKg), wu)
			line += "; %s on %s (%s%s %s over %d days, %d weigh-ins)" % [fmt_w.call(w0.weightKg), _day(str(w0.date)), "+" if diff > 0.0 else "", _n(diff), wu,
				Dates.days_between(str(w0.date), str(last.date)), weighed.size()]
		L.append(line + ".")
	var fats = body.filter(func(b): return float(b.get("bodyFatPct", 0.0)) > 0.0)
	if fats.is_empty():
		L.append("- No body fat logged.")
	else:
		var fl = fats[fats.size() - 1]
		var line = "- Body fat %s%% on %s" % [_n(float(fl.bodyFatPct)), _day(str(fl.date))]
		if fats.size() > 1:
			line += "; %s%% on %s" % [_n(float(fats[0].bodyFatPct)), _day(str(fats[0].date))]
		L.append(line + " (a home scale's reading).")

	# --- the week ---
	L.append("")
	L.append("A TYPICAL WEEK (the average, and the last 7 days as they really were)")
	var days7 = {}
	for s in f.sessions:
		if str(s.date) >= Dates.add_days(today, -6):
			days7[str(s.date)] = true
	L.append("- Days with any training: %s of 7 (%d in the last 7 days)." % [per_week.call(f.trained.size()), days7.size()])
	var split = str(settings.get("split", "auto"))
	var cycle = Missions.split_cycle(split)
	var lift_line = "- Lifting: %s sessions a week (%d in the last 7 days)" % [per_week.call(f.count.get("lift", 0)), int(f.count7.get("lift", 0))]
	var lift_secs = 0
	var lift_timed = 0
	for s in f.sessions:
		if str(s.get("discipline", "")) == "lift" and str(s.date) >= str(f.from) and int(s.get("durationSec", 0)) > 0:
			lift_secs += int(s.durationSec)
			lift_timed += 1
	# A time is only said when most sessions have one (it is rarely logged).
	var untimed = lift_timed * 2 < int(f.count.get("lift", 0))
	if lift_timed > 0 and not untimed:
		lift_line += ", about %s each" % Fmt.fmt_duration_short(lift_secs / float(lift_timed))
	if not cycle.is_empty():
		lift_line += ", as a %s rotation" % " / ".join(PackedStringArray(cycle))
	L.append(lift_line + ".")
	for disc in ["climb", "run", "ride"]:
		if int(f.count.get(disc, 0)) > 0 or int(f.count7.get(disc, 0)) > 0:
			L.append("- %s: %s a week (%d in the last 7 days)." % [str(OTHER_NAMES[disc]), per_week.call(f.count.get(disc, 0)), int(f.count7.get(disc, 0))])
	if int(f.count.get("misc", 0)) > 0:
		L.append("- Weighted vest walks and the like: %s a week (%d in the last 7 days)." % [per_week.call(f.count.get("misc", 0)), int(f.count7.get("misc", 0))])

	# --- sets per muscle ---
	if int(f.sets) > 0:
		L.append("")
		L.append("LIFTING: SETS PER MUSCLE GROUP PER WEEK")
		L.append("(Direct = sets of lifts that mainly train it. With indirect = plus half a set for each set of a lift that also works it. Warm-ups are not logged, so these are working sets; how close to failure is not logged. Physical therapy and stretches are apart, below.)")
		var order = Recovery.PARTS.duplicate()
		for p in f.parts:
			if not order.has(p):
				order.append(p)
		for p in order:
			if not f.parts.has(p):
				L.append("- %s: 0 sets." % str(Recovery.NAMES.get(p, str(p).capitalize())))
				continue
			var r = f.parts[p]
			var line = "- %s: %s direct, %s with indirect (last 7 days: %d direct)" % [str(Recovery.NAMES.get(p, str(p).capitalize())), per_week.call(r.direct), per_week.call(float(r.direct) + float(r.indirect)), int(r.last7)]
			if float(r.direct) > 0.0:
				line += "; on %s days a week" % per_week.call(r.days.size())
				line += "; about %s reps a set" % _n(float(r.reps) / float(r.direct), 0)
				if float(r.vol) > 0.0:
					line += "; %s moved a week" % Fmt.fmt_big_kg(float(r.vol) / weeks, wu)
			L.append(line + ".")
		var bands = []
		for i in range(REP_BANDS.size()):
			if int(f.bands[i]) > 0:
				bands.append("%s %d%%" % [str(REP_BANDS[i][2]), int(round(100.0 * int(f.bands[i]) / float(f.sets)))])
		L.append("- All working sets by reps: %s. Total %s sets a week." % [", ".join(PackedStringArray(bands)), per_week.call(f.sets)])
		L.append("- Weight moved counts weighted sets only (bodyweight sets add none).")
		if not f.both.is_empty():
			L.append("- Some lifts are single arm or single leg work that I log as ONE number for both sides added up (marked L+R below). The reps a set and the rep ranges above count ONE side of those. A set of them is still one set for the muscle.")

	# --- every lift ---
	var lifts = f.lifts.values()
	if not lifts.is_empty():
		lifts.sort_custom(func(a, b):
			if str(a.part) != str(b.part):
				return str(a.part) < str(b.part)
			return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
		L.append("")
		L.append("EVERY LIFT (whole log: days done, latest day, first day when it differs, heaviest set)")
		if lifts.any(func(r): return int(r.get("sides", 1)) > 1):
			L.append("(L+R = a single arm or single leg lift whose reps are written as left and right ADDED TOGETHER: 25 is a 12 and a 13, not a set of 25. Go by the reps a side given beside them.)")
		for r in lifts:
			var sides = int(r.get("sides", 1))
			var line = "- %s [%s%s]: %d day%s; latest %s: %s" % [str(r.name), str(r.part), ", L+R" if sides > 1 else "", r.days.size(), "" if r.days.size() == 1 else "s", _day(str(r.last.date)), sets_words(str(r.name), r.last.sets, fmt_w, sides)]
			if str(r.first.date) != str(r.last.date):
				line += "; first %s: %s" % [_day(str(r.first.date)), sets_words(str(r.name), r.first.sets, fmt_w, sides)]
			if r.best != null and float(r.best.weightKg) > 0.0:
				line += "; heaviest %s × %d" % [fmt_w.call(r.best.weightKg), int(r.best.reps)]
				if sides > 1:
					line += " (%s)" % Sides.side_words([r.best])
			L.append(line + ".")
	var mob = f.mobility.values()
	if not mob.is_empty():
		mob.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
		L.append("")
		L.append("PHYSICAL THERAPY AND STRETCHES (not counted as muscle-building sets)")
		for r in mob:
			L.append("- %s: %d day%s, %s a week; latest %s: %s." % [str(r.name), r.days.size(), "" if r.days.size() == 1 else "s", per_week.call(r.inWindow), _day(str(r.last.date)), sets_words(str(r.name), r.last.sets, fmt_w, int(r.get("sides", 1)))])

	# --- climbing ---
	var climbs = f.sessions.filter(func(s): return str(s.get("discipline", "")) == "climb")
	if not climbs.is_empty():
		L.append("")
		L.append("CLIMBING (whole log)")
		var tally = {"flash": 0, "send": 0, "attempt": 0}
		var by_grade = {}
		var hard = -99
		var routes = 0
		var hangs = 0
		var hang_sec = 0
		var secs = 0
		var timed = 0
		for s in climbs:
			if int(s.get("durationSec", 0)) > 0:
				secs += int(s.durationSec)
				timed += 1
			for c in s.get("climbs", []):
				var n = maxi(1, int(c.get("count", 1)))
				var res = str(c.get("result", "attempt"))
				tally[res if tally.has(res) else "attempt"] = int(tally[res if tally.has(res) else "attempt"]) + n
				var rope = str(c.get("style", "")) == "rope"
				if rope:
					routes += n
				var label = str(c.get("yds", "")) if rope and str(c.get("yds", "")) != "" else Xp.grade_label(int(c.get("grade", 0)))
				if not by_grade.has(label):
					by_grade[label] = {"label": label, "grade": int(c.get("grade", 0)), "sent": 0, "tries": 0, "rope": rope}
				by_grade[label].tries = int(by_grade[label].tries) + n
				if res != "attempt":
					by_grade[label].sent = int(by_grade[label].sent) + n
					if not rope:
						hard = maxi(hard, int(c.get("grade", 0)))
			for h in s.get("hangs", []):
				var n = maxi(1, int(h.get("count", 1)))
				hangs += n
				hang_sec += n * int(h.get("sec", 0))
		var tries = int(tally.flash) + int(tally.send) + int(tally.attempt)
		var line = "- %d sessions, %s a week" % [climbs.size(), per_week.call(f.count.get("climb", 0))]
		if timed > 0 and timed * 2 >= climbs.size():
			line += ", about %s each" % Fmt.fmt_duration_short(secs / float(timed))
		else:
			untimed = true
		L.append(line + ".")
		if tries > 0:
			L.append("- A session is about %s climbs tried: %s sent first go, %s sent after tries, %s not sent." % [_n(tries / float(climbs.size())), _n(int(tally.flash) / float(climbs.size())), _n(int(tally.send) / float(climbs.size())), _n(int(tally.attempt) / float(climbs.size()))])
			var grades = by_grade.values()
			grades.sort_custom(func(a, b): return int(a.grade) > int(b.grade) if int(a.grade) != int(b.grade) else str(a.label) > str(b.label))
			for rope in [false, true]:
				var some = grades.filter(func(g): return bool(g.rope) == rope)
				if not some.is_empty():
					L.append("- %s by grade (sent / tried): %s." % ["Roped routes" if rope else "Boulders", ", ".join(PackedStringArray(some.map(func(g): return "%s %d/%d" % [str(g.label), int(g.sent), int(g.tries)])))])
			if hard > -99:
				L.append("- Hardest boulder sent: %s.%s" % [Xp.grade_label(hard), (" %d of the climbs were roped routes." % routes) if routes > 0 else ""])
		if hangs > 0:
			L.append("- Hangboard: %d hangs, %d seconds in all." % [hangs, hang_sec])

	# --- runs, rides, the rest ---
	for disc in ["run", "ride"]:
		var list = f.sessions.filter(func(s): return str(s.get("discipline", "")) == disc)
		if list.is_empty():
			continue
		list.sort_custom(func(a, b): return str(a.date) > str(b.date))
		L.append("")
		L.append("%s (whole log)" % str(OTHER_NAMES[disc]).to_upper())
		var in_window = list.filter(func(s): return str(s.date) >= str(f.from))
		var dist = 0.0
		var secs = 0.0
		for s in in_window:
			dist += float(s.get("distanceM", 0.0))
			secs += float(s.get("durationSec", 0))
		L.append("- %s a week: %s and %s a week." % [per_week.call(in_window.size()), Fmt.fmt_distance(dist / weeks, du), Fmt.fmt_duration_short(secs / weeks)])
		for s in list.slice(0, 6):
			var line = "- %s: %s" % [_day(str(s.date)), Fmt.fmt_distance(float(s.get("distanceM", 0.0)), du, 2)]
			if float(s.get("durationSec", 0)) > 0.0:
				line += " in %s" % Fmt.fmt_duration(float(s.durationSec))
				if float(s.get("distanceM", 0.0)) > 0.0:
					var per_km = float(s.durationSec) / (float(s.distanceM) / 1000.0)
					line += " (%s)" % (Fmt.fmt_pace(per_km, du) if disc == "run" else Fmt.fmt_speed(3600.0 / per_km, du))
			if float(s.get("elevationM", 0.0)) > 0.0:
				line += ", %s climbed" % Fmt.fmt_elevation(float(s.elevationM), du)
			L.append(line + ".")
	var misc = f.sessions.filter(func(s): return str(s.get("discipline", "")) == "misc")
	if not misc.is_empty():
		misc.sort_custom(func(a, b): return str(a.date) > str(b.date))
		L.append("")
		L.append("OTHER ACTIVITY (whole log)")
		for s in misc.slice(0, 8):
			var kind = Misc.KINDS.get(str(s.get("kind", "")), {})
			var line = "- %s: %s" % [_day(str(s.date)), str(kind.get("name", "Activity"))]
			if float(s.get("distanceM", 0.0)) > 0.0:
				line += ", %s" % Fmt.fmt_distance(float(s.distanceM), du, 2)
			if float(s.get("loadKg", 0.0)) > 0.0:
				line += " carrying %s" % fmt_w.call(s.loadKg)
			if float(s.get("durationSec", 0)) > 0.0:
				line += " in %s" % Fmt.fmt_duration(float(s.durationSec))
			L.append(line + ".")

	# --- day by day ---
	L.append("")
	L.append("DAY BY DAY (newest first; days not listed were rest days)")
	var by_day = {}
	for s in f.sessions:
		if str(s.date) < Dates.add_days(today, -(DAYS_LISTED - 1)):
			continue
		if not by_day.has(str(s.date)):
			by_day[str(s.date)] = []
		by_day[str(s.date)].append(_session_words(s, marks, wu, du))
	var keys = by_day.keys()
	keys.sort()
	keys.reverse()
	for d in keys:
		L.append("- %s: %s" % [_day(str(d), true), "; ".join(PackedStringArray(by_day[d]))])

	L.append("")
	L.append("NOT IN THE LOG")
	L.append("Calories, protein, sleep, steps, age, height, how long I have trained, %sand how hard each set was. Ask me for whichever you need before you answer." % ("how long most sessions took, " if untimed else ""))
	L.append("")
	L.append("WHAT I WANT FROM YOU")
	L.append("1. Which muscle groups get too little, enough or too much work a week for building muscle?")
	L.append("2. With the climbing, running and other activity on top, does recovery look sound? For me climbing is fingers and forearms far more than back, so do not count it as back work; running and walks load the legs.")
	L.append("3. What rate of muscle gain and fat loss is realistic on this training, and what does it depend on most?")
	L.append("4. The three changes you would make first, in order.")
	return "\n".join(PackedStringArray(L))


## One session in a few words, for the day-by-day list.
static func _session_words(s: Dictionary, marks: Dictionary, wu: String, du: String) -> String:
	var disc = str(s.get("discipline", ""))
	var words = ""
	if disc == "lift":
		var parts = {}
		var order = []
		var mob = 0
		for ex in s.get("exercises", []):
			var n = LiftTrend.real_sets(ex.get("sets", [])).size()
			if n == 0:
				continue
			if is_mobility(ex, marks):
				mob += 1
				continue
			var p = part(str(ex.get("name", "")))
			if not parts.has(p):
				parts[p] = 0
				order.append(p)
			parts[p] = int(parts[p]) + n
		order.sort_custom(func(a, b): return int(parts[a]) > int(parts[b]))
		var bits = order.map(func(p): return "%s %d" % [str(p), int(parts[p])])
		words = "lift (sets: %s)" % ", ".join(PackedStringArray(bits)) if not bits.is_empty() else "PT / stretches only"
		if mob > 0 and not bits.is_empty():
			words += " + %d PT / stretch exercise%s" % [mob, "" if mob == 1 else "s"]
		return words
	if disc == "climb":
		var sent = 0
		var tries = 0
		var hard = -99
		for c in s.get("climbs", []):
			var n = maxi(1, int(c.get("count", 1)))
			tries += n
			if str(c.get("result", "attempt")) != "attempt":
				sent += n
				hard = maxi(hard, int(c.get("grade", 0)))
		words = "climb (%d tried, %d sent%s)" % [tries, sent, (", up to %s" % Xp.grade_label(hard)) if hard > -99 else ""]
		if not s.get("hangs", []).is_empty():
			words += " + hangboard"
		return words
	if disc == "misc":
		var kind = Misc.KINDS.get(str(s.get("kind", "")), {})
		words = str(kind.get("name", "activity")).to_lower()
		if float(s.get("distanceM", 0.0)) > 0.0:
			words += " %s" % Fmt.fmt_distance(float(s.distanceM), du)
		if float(s.get("loadKg", 0.0)) > 0.0:
			words += " with %s" % Fmt.fmt_weight(float(s.loadKg), wu)
		return words
	words = "%s %s" % [disc, Fmt.fmt_distance(float(s.get("distanceM", 0.0)), du)]
	if float(s.get("durationSec", 0)) > 0.0:
		words += " in %s" % Fmt.fmt_duration(float(s.durationSec))
	return words
