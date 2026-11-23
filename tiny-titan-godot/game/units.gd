class_name Units
extends RefCounted
## The player's units for text the ported rules make in kg and km (the user,
## 2026-11-23, about record cards that said kg: "Yeah always lbs").
##
## The rules were ported from an app that counts in kilograms and kilometres,
## and what they write says so: the results reel's record cards ("104.3 kg
## (was 102 kg)", "Longest run! 21.1 km"), the XP labels ("12,340 kg volume",
## "5.2 km"), the trophies ("Lift 100 kg in a set."), what unlocks gear ("Run
## 100 km lifetime"). The rules and their texts stay as they are: the parity
## tests compare them. The SCREENS show them through here:
##
##   text(s, settings)       a text of the rules with its kg, km, km/h, /km and
##                           metres of elevation in the player's units
##   records(events, before_prs, after_prs, settings)
##                           the reel's record cards, written again from the
##                           real numbers (no rounding twice)
##   xp_label(session, label, settings)
##                           one XP label of a session, from its real numbers
##
## With kg and km as the player's units everything comes back unchanged.
## A text that says "exactly" (a run of exactly 5.00 km) is about that very
## number and is left alone. Pure logic: tests/units_test.gd.

## Texts that read better written out than converted.
const WHOLE = {
	"mi": {"Ride 160 km (100 miles) in one go.": "Ride 100 mi in one go."},
}

static var _rx_cache = {}


static func _rx(pattern: String) -> RegEx:
	if not _rx_cache.has(pattern):
		var r = RegEx.new()
		r.compile(pattern)
		_rx_cache[pattern] = r
	return _rx_cache[pattern]


static func weight_unit(settings) -> String:
	return str(settings.get("weightUnit", "kg")) if settings is Dictionary else "kg"


static func distance_unit(settings) -> String:
	return str(settings.get("distanceUnit", "km")) if settings is Dictionary else "km"


static func _num(t: String) -> float:
	return float(t.replace(",", ""))


## Replace every match of `pattern` in `s` by what `make` says for it.
static func _swap(s: String, pattern: String, make: Callable) -> String:
	var out = ""
	var at = 0
	for m in _rx(pattern).search_all(s):
		out += s.substr(at, m.get_start() - at) + str(make.call(m))
		at = m.get_end()
	return out + s.substr(at)


## A number with at most `digits` decimals and no zeros at its end: "132.3", "22".
static func _short(v: float, digits: int) -> String:
	var t = Fmt.to_fixed(v, digits)
	if t.contains("."):
		t = t.rstrip("0").rstrip(".")
	return t


## A weight of the rules (kg) in the player's unit: "132.3 lb", "22,046 lb".
static func weight(kg: float, wu: String) -> String:
	var v = Fmt.kg_to_unit(kg, wu)
	if v >= 1000.0:
		return "%s %s" % [Fmt.fmt_num(roundf(v)), wu]
	return "%s %s" % [_short(v, 1), wu]


## A distance of the rules (metres) in the player's unit, as exact as a
## threshold needs: "3.11 mi", "310.7 mi", "3,107 mi".
static func distance(m: float, du: String) -> String:
	var v = Fmt.m_to_unit(m, du)
	if v >= 1000.0:
		return "%s %s" % [Fmt.fmt_num(roundf(v)), du]
	if v >= 100.0:
		return "%s %s" % [_short(v, 1), du]
	return "%s %s" % [_short(v, 2), du]


## A text of the rules in the player's units.
static func text(s: String, settings) -> String:
	var wu = weight_unit(settings)
	var du = distance_unit(settings)
	if s == "" or (wu == "kg" and du == "km") or s.contains("exactly"):
		return s
	if du != "km" and WHOLE.get(du, {}).has(s):
		s = str(WHOLE[du][s])
	var out = s
	if wu != "kg":
		out = _swap(out, "(\\d[\\d,]*(?:\\.\\d+)?) ?kg\\b", func(m): return weight(_num(m.get_string(1)), wu))
	if du != "km":
		# Speed and pace first: what is left that says km is a distance.
		out = _swap(out, "(\\d[\\d,]*(?:\\.\\d+)?) ?km/h", func(m): return Fmt.fmt_speed(_num(m.get_string(1)), du))
		out = _swap(out, "(\\d+):(\\d\\d) ?/km", func(m): return Fmt.fmt_pace(float(int(m.get_string(1)) * 60 + int(m.get_string(2))), du))
		out = _swap(out, "(\\d[\\d,]*(?:\\.\\d+)?) ?km\\b", func(m): return distance(_num(m.get_string(1)) * 1000.0, du))
		out = _swap(out, "(\\d[\\d,]*(?:\\.\\d+)?) m(?= of elevation| climbed| ↑)", func(m): return Fmt.fmt_elevation(_num(m.get_string(1)), du))
	return out


static func _was(now: String, before: String) -> String:
	return "%s (was %s)" % [now, before]


## The results reel's record cards in the player's units, written again from
## the records themselves (`before_prs` / `after_prs`: state.prs before and
## after the sessions), so 230 lb does not come out as 229.9 from a rounded
## kg. Cards it does not know, and all of them for a player who counts in kg
## and km, come back as they are. Returns a new array.
static func records(events: Array, before_prs, after_prs, settings) -> Array:
	var wu = weight_unit(settings)
	var du = distance_unit(settings)
	if (wu == "kg" and du == "km") or not (before_prs is Dictionary) or not (after_prs is Dictionary):
		return events.duplicate()
	var bp = before_prs
	var ap = after_prs
	# title -> {"detail", "title" (when it changes too)}
	var fix = {}
	if wu != "kg":
		var before_lifts = bp.get("lifts", {})
		for lift_name in ap.get("lifts", {}):
			var pr = ap.lifts[lift_name]
			var prev = before_lifts.get(lift_name)
			if prev == null:
				continue
			if float(pr.weightKg) > float(prev.weightKg) + 1e-9:
				fix["%s PR" % Diff._title_case(str(lift_name))] = {"detail": _was(Fmt.fmt_weight(float(pr.weightKg), wu), Fmt.fmt_weight(float(prev.weightKg), wu))}
			elif float(pr.e1rm) > float(prev.e1rm) + 1e-6:
				fix["%s est. 1RM PR" % Diff._title_case(str(lift_name))] = {"detail": _was(Fmt.fmt_weight(float(pr.e1rm), wu), Fmt.fmt_weight(float(prev.e1rm), wu))}
		var hang = ap.get("bestHangKg")
		if (hang is int or hang is float) and float(hang) > 0.0:
			var hang_before = bp.get("bestHangKg")
			var first = not (hang_before is int or hang_before is float) or float(hang_before) <= 0.0
			fix["Heaviest hang!"] = {"detail": "+%s" % Fmt.fmt_weight(float(hang), wu) if first else "+%s (was +%s)" % [Fmt.fmt_weight(float(hang), wu), Fmt.fmt_weight(float(hang_before), wu)]}
	if du != "km":
		if float(bp.get("longestRunM", 0)) > 0.0 and float(ap.get("longestRunM", 0)) > float(bp.longestRunM):
			fix["Longest run!"] = {"detail": _was(distance(float(ap.longestRunM), du), distance(float(bp.longestRunM), du))}
		if float(bp.get("longestRideM", 0)) > 0.0 and float(ap.get("longestRideM", 0)) > float(bp.longestRideM):
			fix["Longest ride!"] = {"detail": _was(distance(float(ap.longestRideM), du), distance(float(bp.longestRideM), du))}
		var pace = ap.get("bestPaceSecPerKm")
		var pace_before = bp.get("bestPaceSecPerKm")
		if (pace is int or pace is float) and (pace_before is int or pace_before is float):
			fix["Fastest pace (5 km+)!"] = {"title": text("Fastest pace (5 km+)!", settings),
				"detail": _was(Fmt.fmt_pace(float(pace), du), Fmt.fmt_pace(float(pace_before), du).replace(" /" + du, ""))}
		var speed = ap.get("bestRideSpeedKmh")
		var speed_before = bp.get("bestRideSpeedKmh")
		if (speed is int or speed is float) and (speed_before is int or speed_before is float):
			fix["Fastest ride (20 km+)!"] = {"title": text("Fastest ride (20 km+)!", settings),
				"detail": _was(Fmt.fmt_speed(float(speed), du), Fmt.fmt_speed(float(speed_before), du).replace(" mph", ""))}
	var out = []
	for ev in events:
		var title = str(ev.get("title", "")) if ev is Dictionary else ""
		if ev is Dictionary and str(ev.get("type", "")) == "pr" and fix.has(title):
			var c = ev.duplicate()
			c["detail"] = str(fix[title].detail)
			if fix[title].has("title"):
				c["title"] = str(fix[title].title)
			out.append(c)
		else:
			out.append(ev)
	return out


## One label of a session's XP ("12,340 kg volume", "5.2 km", "80 m climbed",
## "3.0 km carrying 10 kg") in the player's units, from the session's own
## numbers where it has them; any other label through `text`.
static func xp_label(session: Dictionary, label: String, settings) -> String:
	var wu = weight_unit(settings)
	var du = distance_unit(settings)
	if wu == "kg" and du == "km":
		return label
	var st = Xp.session_stats(session)
	var disc = str(session.get("discipline", ""))
	if wu != "kg" and disc == "lift" and label.ends_with(" kg volume"):
		return "%s volume" % Fmt.fmt_big_kg(float(st.get("volumeKg", 0.0)), wu)
	var dist = float(st.get("distanceM", 0.0)) if st.get("distanceM") != null else 0.0
	var starts_km = _rx("^\\d[\\d,]*(?:\\.\\d+)? km\\b").search(label) != null
	# A walk with a load: "3.0 km carrying 10 kg".
	var load = session.get("loadKg")
	var at = label.find(" carrying ")
	if at >= 0 and (load is int or load is float) and float(load) > 0.0:
		var head = distance(dist, du) if (du != "km" and dist > 0.0 and starts_km) else label.substr(0, at)
		var tail = Fmt.fmt_weight(float(load), wu) if wu != "kg" else label.substr(at + 10)
		return "%s carrying %s" % [head, tail]
	var elev = session.get("elevationM")
	if du != "km" and label.ends_with(" m climbed") and (elev is int or elev is float) and float(elev) > 0.0:
		return "%s climbed" % Fmt.fmt_elevation(float(elev), du)
	if du != "km" and dist > 0.0 and starts_km:
		return distance(dist, du) + text(label.substr(label.find(" km") + 3), settings)
	return text(label, settings)
