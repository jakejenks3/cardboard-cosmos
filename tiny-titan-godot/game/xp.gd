class_name Xp
extends RefCounted
## XP formulas, level curves, body stages and mastery ranks (port of xp.ts).

# ---------------------------------------------------------------------------
# Tuning. Every discipline is balanced to land around ~1,000 XP for a solid
# hour of effort so no sport feels like the "wrong" one to play.
# ---------------------------------------------------------------------------

## XP per climb, indexed by grade + 1 (VB, V0, V1 ... V17).
const CLIMB_GRADE_XP = [12, 20, 30, 42, 58, 78, 105, 140, 185, 240, 310, 400, 500, 620, 760, 920, 1100, 1300, 1550]
const MAX_V_GRADE = 17
const CLIMB_RESULT_MULT = {"flash": 1.3, "send": 1, "attempt": 0.35}

## Roped climbs (top rope / lead) use the Yosemite Decimal System. Each grade is
## worth a boulder grade's XP (YDS_TO_V, the usual conversion) times ROPE_XP_MULT,
## since a route is a boulder problem's crux plus a lot more climbing.
const YDS_GRADES = ["5.5", "5.6", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d", "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b", "5.12c", "5.12d", "5.13a", "5.13b", "5.13c", "5.13d", "5.14a", "5.14b", "5.14c", "5.14d", "5.15a"]
const YDS_TO_V = [-1, -1, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 9, 10, 10, 11, 12, 13, 14]
const ROPE_XP_MULT = 1.5

## Hangboard: XP per second hung on a HANG_REF_EDGE_MM edge with both arms.
## Smaller edges pay more (20 mm / edge, capped), one arm pays HANG_ONE_ARM_MULT
## times as much, and every HANG_KG_PER_DOUBLE kg added doubles it (assistance
## takes it down the same way, never below a quarter).
const HANG_XP_PER_SEC = 1.0
const HANG_REF_EDGE_MM = 20.0
const HANG_EDGE_MULT_MIN = 0.5
const HANG_EDGE_MULT_MAX = 2.5
const HANG_ONE_ARM_MULT = 2.5
const HANG_KG_PER_DOUBLE = 20.0

const LIFT_XP_PER_KG = 0.1
const LIFT_XP_PER_REP = 1
const LIFT_XP_PER_BW_REP = 3
const LIFT_XP_PER_SET = 5

const RUN_XP_PER_KM = 100
const RUN_XP_PER_ELEV_M = 0.8
const RIDE_XP_PER_KM = 32
const RIDE_XP_PER_ELEV_M = 0.8

const DURATION_XP_PER_MIN = 2
const DURATION_XP_MAX_MIN = 180

const PR_BONUS = {
	"liftExercise": 150,
	"climbMaxSend": 200,
	"climbMaxFlash": 100,
	"climbMaxRoute": 200,
	"climbMaxRouteFlash": 100,
	"bestHang": 100,
	"longestRun": 150,
	"longestRide": 150,
}

const MAX_LEVEL = 99

# ---------------------------------------------------------------------------
# Body evolution stages (drives the avatar silhouette + title adjective).
# ---------------------------------------------------------------------------
const STAGES = [
	{"minLevel": 1, "name": "Scrawny", "blurb": "Everyone starts somewhere."},
	{"minLevel": 5, "name": "Budding", "blurb": "Posture: improving. Vibes: immaculate."},
	{"minLevel": 12, "name": "Fit", "blurb": "People are starting to notice."},
	{"minLevel": 22, "name": "Athletic", "blurb": "Built different. Literally."},
	{"minLevel": 35, "name": "Jacked", "blurb": "Doorframes fear you."},
	{"minLevel": 50, "name": "Titanic", "blurb": "A legend walks among mortals."},
]

# ---------------------------------------------------------------------------
# Mastery ranks: named tiers for each discipline level track.
# ---------------------------------------------------------------------------
const RANKS = [
	{"minLevel": 1, "name": "Novice", "color": "#9aa3ad"},
	{"minLevel": 5, "name": "Apprentice", "color": "#b98a5a"},
	{"minLevel": 10, "name": "Journeyman", "color": "#c9d1d9"},
	{"minLevel": 15, "name": "Adept", "color": "#ffd54f"},
	{"minLevel": 20, "name": "Expert", "color": "#4dd0e1"},
	{"minLevel": 30, "name": "Master", "color": "#c77dff"},
	{"minLevel": 40, "name": "Grandmaster", "color": "#ff7043"},
	{"minLevel": 50, "name": "Legend", "color": "#ffeb3b"},
]

# XP needed to finish each level (index = level), built once per curve.
static var _hero_costs = null
static var _disc_costs = null


static func clamp_grade(g) -> int:
	return mini(MAX_V_GRADE, maxi(-1, TTUtil.jsround(g)))


static func climb_grade_xp(grade) -> int:
	return CLIMB_GRADE_XP[clamp_grade(grade) + 1]


static func grade_label(grade) -> String:
	return "VB" if grade < 0 else "V" + TTUtil.num_str(grade)


## Index of a route grade ("5.10a") in YDS_GRADES, or -1. A bare "5.10" is its "a".
static func yds_index(label) -> int:
	var s: String = str(label).strip_edges().to_lower()
	var i: int = YDS_GRADES.find(s)
	if i < 0 and s.length() >= 4 and not s.ends_with("a") and not s.ends_with("b") and not s.ends_with("c") and not s.ends_with("d"):
		i = YDS_GRADES.find(s + "a")
	return i


static func yds_label(i) -> String:
	return YDS_GRADES[clampi(int(i), 0, YDS_GRADES.size() - 1)]


## The boulder grade a route grade is worth.
static func yds_to_v(i) -> int:
	return YDS_TO_V[clampi(int(i), 0, YDS_TO_V.size() - 1)]


static func is_route(c: Dictionary) -> bool:
	return str(c.get("style", "")) == "rope"


## Label of a logged climb: "V4", or "5.10a" for a route.
static func climb_label(c: Dictionary) -> String:
	if is_route(c):
		return str(TTUtil.get_or(c, "yds", yds_label(0)))
	return grade_label(c.grade)


static func route_xp(i) -> float:
	return climb_grade_xp(yds_to_v(i)) * ROPE_XP_MULT


## XP of one hang {edgeMm (0 = jug / bar), sec, arms (1 | 2), addKg (negative = assisted)}.
static func hang_xp(h: Dictionary) -> float:
	var edge: float = float(TTUtil.get_or(h, "edgeMm", HANG_REF_EDGE_MM))
	var edge_mult: float = HANG_EDGE_MULT_MIN if edge <= 0.0 else clampf(HANG_REF_EDGE_MM / edge, HANG_EDGE_MULT_MIN, HANG_EDGE_MULT_MAX)
	var arm_mult: float = HANG_ONE_ARM_MULT if int(TTUtil.get_or(h, "arms", 2)) == 1 else 1.0
	var load_mult: float = maxf(0.25, 1.0 + float(TTUtil.get_or(h, "addKg", 0.0)) / HANG_KG_PER_DOUBLE)
	return maxf(0.0, float(TTUtil.get_or(h, "sec", 0))) * HANG_XP_PER_SEC * edge_mult * arm_mult * load_mult


## "6 × 10 s · 20 mm · one arm · +10 kg"
## "20 mm", or "Jug" for edge 0.
static func edge_label(edge_mm: int) -> String:
	return "Jug" if edge_mm <= 0 else "%d mm" % edge_mm


static func hang_text(h: Dictionary, wu: String) -> String:
	var parts: Array = []
	var n: int = int(TTUtil.get_or(h, "count", 1))
	parts.append("%s%d s" % [("%d × " % n) if n != 1 else "", int(TTUtil.get_or(h, "sec", 0))])
	var edge: int = int(TTUtil.get_or(h, "edgeMm", 0))
	parts.append(("%d mm" % edge) if edge > 0 else "jug")
	if int(TTUtil.get_or(h, "arms", 2)) == 1:
		parts.append("one arm")
	var add: float = float(TTUtil.get_or(h, "addKg", 0.0))
	if add > 0.0:
		parts.append("+" + Fmt.fmt_weight(add, wu))
	elif add < 0.0:
		parts.append("−" + Fmt.fmt_weight(-add, wu))
	return " · ".join(PackedStringArray(parts))


## Epley estimated one-rep max.
static func e1rm(weight_kg, reps) -> float:
	if reps <= 1:
		return weight_kg
	return weight_kg * (1.0 + reps / 30.0)


## Per-session numbers. Returns
## {volumeKg, reps, bwReps, sets, maxSetKg, exerciseNames: [String],   (lifting)
##  sends, flashes, attempts, maxGradeSent, maxGradeFlashed,           (climbing; grades null when nothing was sent)
##  distanceM, elevationM, paceSecPerKm, speedKmh,                      (cardio; pace/speed null without a duration)
##  durationSec}
static func session_stats(s: Dictionary) -> Dictionary:
	var dur = TTUtil.get_or(s, "durationSec", 0)
	var st = {
		"volumeKg": 0,
		"reps": 0,
		"bwReps": 0,
		"sets": 0,
		"maxSetKg": 0,
		"exerciseNames": [],
		"sends": 0,
		"flashes": 0,
		"attempts": 0,
		"maxGradeSent": null,
		"maxGradeFlashed": null,
		"distanceM": 0,
		"elevationM": 0,
		"paceSecPerKm": null,
		"speedKmh": null,
		"durationSec": dur,
		"routes": null,
		"maxRouteSent": null,
		"maxRouteFlashed": null,
		"hangs": null,
		"hangSec": null,
		"bestHangKg": null,
	}
	if s.discipline == "lift":
		for ex in s.exercises:
			if not ex.sets.is_empty():
				st.exerciseNames.append(normalize_exercise(ex.name))
			for one_set in ex.sets:
				var reps = max(0, one_set.reps)
				var w = max(0, one_set.weightKg)
				st.sets += 1
				if w > 0:
					st.reps += reps
					st.volumeKg += reps * w
					st.maxSetKg = max(st.maxSetKg, w)
				else:
					st.bwReps += reps
	elif s.discipline == "climb":
		for c in s.get("climbs", []):
			var n = max(0, c["count"])
			var route: bool = is_route(c)
			if route and n > 0:
				st.routes = int(TTUtil.get_or(st, "routes", 0)) + n
			if c.result == "attempt":
				st.attempts += n
			else:
				st.sends += n
				if n > 0:
					if route:
						st.maxRouteSent = max(TTUtil.get_or(st, "maxRouteSent", -99), yds_index(c.get("yds")))
					else:
						st.maxGradeSent = max(TTUtil.get_or(st, "maxGradeSent", -99), c.grade)
				if c.result == "flash":
					st.flashes += n
					if n > 0:
						if route:
							st.maxRouteFlashed = max(TTUtil.get_or(st, "maxRouteFlashed", -99), yds_index(c.get("yds")))
						else:
							st.maxGradeFlashed = max(TTUtil.get_or(st, "maxGradeFlashed", -99), c.grade)
		for h in s.get("hangs", []):
			var hn: int = max(0, int(TTUtil.get_or(h, "count", 1)))
			if hn <= 0:
				continue
			st.hangs = int(TTUtil.get_or(st, "hangs", 0)) + hn
			st.hangSec = int(TTUtil.get_or(st, "hangSec", 0)) + hn * int(TTUtil.get_or(h, "sec", 0))
			# The heaviest two-arm hang held for at least 5 s is the PR that matters.
			if int(TTUtil.get_or(h, "arms", 2)) == 2 and int(TTUtil.get_or(h, "sec", 0)) >= 5:
				st.bestHangKg = maxf(float(TTUtil.get_or(st, "bestHangKg", -9999.0)), float(TTUtil.get_or(h, "addKg", 0.0)))
	else:
		st.distanceM = max(0, s.distanceM)
		var elev = s.get("elevationM")
		st.elevationM = max(0, elev if TTUtil.truthy(elev) else 0)
		if TTUtil.truthy(s.get("durationSec")) and st.distanceM > 0:
			var d_sec = s.get("durationSec")
			st.paceSecPerKm = d_sec / (st.distanceM / 1000.0)
			st.speedKmh = (st.distanceM / 1000.0) / (d_sec / 3600.0)
	return st


## Trim, lower-case and collapse runs of whitespace to one space
## (JS: `name.trim().toLowerCase().replace(/\s+/g, ' ')`).
static func normalize_exercise(raw) -> String:
	var text: String = _js_lower(str(raw))
	var out: String = ""
	var pending_space: bool = false
	for i in range(text.length()):
		if _is_js_space(text.unicode_at(i)):
			pending_space = true
		else:
			if pending_space and out != "":
				out += " "
			pending_space = false
			out += text[i]
	return out


# The characters JS treats as whitespace in `trim()` and `\s`.
static func _is_js_space(c: int) -> bool:
	if c == 32 or (c >= 9 and c <= 13):
		return true
	if c < 0xA0:
		return false
	return c == 0xA0 or c == 0x1680 or (c >= 0x2000 and c <= 0x200A) or c == 0x2028 or c == 0x2029 or c == 0x202F or c == 0x205F or c == 0x3000 or c == 0xFEFF


# JS `toLowerCase()`. Godot's `to_lower()` maps every single character the
# same way except for the two special cases of the Unicode standard: capital
# I with dot (U+0130) becomes "i" + combining dot, and a capital sigma at the
# end of a word becomes the final sigma. Without them the same exercise could
# get a different key here than in the web app.
static func _js_lower(text: String) -> String:
	if text.find("İ") == -1 and text.find("Σ") == -1:
		return text.to_lower()
	var out: String = ""
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if c == 0x130:
			out += "i̇"
		elif c == 0x3A3:
			out += "ς" if _is_final_sigma(text, i) else "σ"
		else:
			out += text[i].to_lower()
	return out


# Unicode "Final_Sigma": the sigma follows a cased letter and is not followed
# by one, in both directions skipping characters that do not affect casing
# (apostrophes, full stops, accents ...). A character that is both cased and
# ignorable counts as ignorable, as in the JS engines.
static func _is_final_sigma(text: String, at: int) -> bool:
	var before: bool = false
	var i: int = at - 1
	while i >= 0:
		var c: int = text.unicode_at(i)
		if not _in_ranges(c, _CASE_IGNORABLE):
			before = _is_cased(c)
			break
		i -= 1
	if not before:
		return false
	i = at + 1
	while i < text.length():
		var c: int = text.unicode_at(i)
		if not _in_ranges(c, _CASE_IGNORABLE):
			return not _is_cased(c)
		i += 1
	return true


# [first, last] pairs of the Unicode "Cased" property for Latin, Greek and
# Cyrillic (up to U+052F and U+1D00..U+1FFF), and of "Case_Ignorable" for the
# same scripts plus general punctuation and emoji modifiers. Only used to
# place the final sigma; other scripts fall back to Godot's own case tables.
const _CASED = [0x41, 0x5A, 0x61, 0x7A, 0xAA, 0xAA, 0xB5, 0xB5, 0xBA, 0xBA, 0xC0, 0xD6, 0xD8, 0xF6, 0xF8, 0x1BA, 0x1BC, 0x1BF, 0x1C4, 0x293, 0x296, 0x2B8, 0x2C0, 0x2C1, 0x2E0, 0x2E4, 0x345, 0x345, 0x370, 0x373, 0x376, 0x377, 0x37A, 0x37D, 0x37F, 0x37F, 0x386, 0x386, 0x388, 0x38A, 0x38C, 0x38C, 0x38E, 0x3A1, 0x3A3, 0x3F5, 0x3F7, 0x481, 0x48A, 0x52F, 0x1D00, 0x1DBF, 0x1E00, 0x1F15, 0x1F18, 0x1F1D, 0x1F20, 0x1F45, 0x1F48, 0x1F4D, 0x1F50, 0x1F57, 0x1F59, 0x1F59, 0x1F5B, 0x1F5B, 0x1F5D, 0x1F5D, 0x1F5F, 0x1F7D, 0x1F80, 0x1FB4, 0x1FB6, 0x1FBC, 0x1FBE, 0x1FBE, 0x1FC2, 0x1FC4, 0x1FC6, 0x1FCC, 0x1FD0, 0x1FD3, 0x1FD6, 0x1FDB, 0x1FE0, 0x1FEC, 0x1FF2, 0x1FF4, 0x1FF6, 0x1FFC]
const _CASE_IGNORABLE = [0x27, 0x27, 0x2E, 0x2E, 0x3A, 0x3A, 0x5E, 0x5E, 0x60, 0x60, 0xA8, 0xA8, 0xAD, 0xAD, 0xAF, 0xAF, 0xB4, 0xB4, 0xB7, 0xB8, 0x2B0, 0x36F, 0x374, 0x375, 0x37A, 0x37A, 0x384, 0x385, 0x387, 0x387, 0x483, 0x489, 0x1D2C, 0x1D6A, 0x1D78, 0x1D78, 0x1D9B, 0x1DFF, 0x1FBD, 0x1FBD, 0x1FBF, 0x1FC1, 0x1FCD, 0x1FCF, 0x1FDD, 0x1FDF, 0x1FED, 0x1FEF, 0x1FFD, 0x1FFE, 0x200B, 0x200F, 0x2018, 0x2019, 0x2024, 0x2024, 0x2027, 0x2027, 0x202A, 0x202E, 0x2060, 0x2064, 0x2066, 0x206F, 0x2071, 0x2071, 0x207F, 0x207F, 0x2090, 0x209C, 0x20D0, 0x20F0, 0xFE00, 0xFE0F, 0xFE13, 0xFE13, 0xFE20, 0xFE2F, 0xFEFF, 0xFEFF, 0x1F3FB, 0x1F3FF, 0xE0100, 0xE01EF]


static func _in_ranges(c: int, ranges: Array) -> bool:
	for i in range(0, ranges.size(), 2):
		if c < ranges[i]:
			return false
		if c <= ranges[i + 1]:
			return true
	return false


static func _is_cased(c: int) -> bool:
	if c <= 0x52F or (c >= 0x1D00 and c <= 0x1FFF):
		return _in_ranges(c, _CASED)
	if c >= 0x1D400 and c <= 0x1D7CB:
		return true  # mathematical letters: cased, but without case mappings
	var ch: String = String.chr(c)
	return ch.to_upper() != ch or ch.to_lower() != ch


## Base XP for a session (no PR bonuses, no perk multiplier).
## Returns {xp: int, parts: [{label: String, xp: int}]}.
static func base_session_xp(s: Dictionary) -> Dictionary:
	var parts: Array = []
	var st: Dictionary = session_stats(s)
	if s.discipline == "lift":
		var vol = st.volumeKg * LIFT_XP_PER_KG
		if vol != 0:
			parts.append({"label": fmt_int(st.volumeKg) + " kg volume", "xp": vol})
		if st.reps != 0:
			parts.append({"label": TTUtil.num_str(st.reps) + " reps", "xp": st.reps * LIFT_XP_PER_REP})
		if st.bwReps != 0:
			parts.append({"label": TTUtil.num_str(st.bwReps) + " bodyweight reps", "xp": st.bwReps * LIFT_XP_PER_BW_REP})
		if st.sets != 0:
			parts.append({"label": TTUtil.num_str(st.sets) + " sets", "xp": st.sets * LIFT_XP_PER_SET})
	elif s.discipline == "climb":
		var send_xp = 0
		var flash_xp = 0
		var attempt_xp = 0
		for c in s.get("climbs", []):
			var each = (route_xp(yds_index(c.get("yds"))) if is_route(c) else climb_grade_xp(c.grade)) * CLIMB_RESULT_MULT[c.result]
			var total = each * max(0, c["count"])
			if c.result == "flash":
				flash_xp += total
			elif c.result == "send":
				send_xp += total
			else:
				attempt_xp += total
		if st.flashes != 0:
			parts.append({"label": TTUtil.num_str(st.flashes) + " flashes", "xp": flash_xp})
		if st.sends - st.flashes != 0:
			parts.append({"label": TTUtil.num_str(st.sends - st.flashes) + " sends", "xp": send_xp})
		if st.attempts != 0:
			parts.append({"label": TTUtil.num_str(st.attempts) + " attempts", "xp": attempt_xp})
		var hang_total: float = 0.0
		for h in s.get("hangs", []):
			hang_total += hang_xp(h) * max(0, int(TTUtil.get_or(h, "count", 1)))
		var n_hangs: int = int(TTUtil.get_or(st, "hangs", 0))
		if n_hangs != 0:
			parts.append({"label": TTUtil.num_str(n_hangs) + (" hang" if n_hangs == 1 else " hangs"), "xp": hang_total})
	else:
		var km = st.distanceM / 1000.0
		var per_km = RUN_XP_PER_KM if s.discipline == "run" else RIDE_XP_PER_KM
		var per_elev = RUN_XP_PER_ELEV_M if s.discipline == "run" else RIDE_XP_PER_ELEV_M
		if km != 0:
			parts.append({"label": TTUtil.to_fixed1(km) + " km", "xp": km * per_km})
		if st.elevationM != 0:
			parts.append({"label": fmt_int(st.elevationM) + " m climbed", "xp": st.elevationM * per_elev})
	var dur = s.get("durationSec")
	if TTUtil.truthy(dur):
		var minutes = min(DURATION_XP_MAX_MIN, dur / 60.0)
		parts.append({"label": str(TTUtil.jsround(minutes)) + " min", "xp": minutes * DURATION_XP_PER_MIN})
	var total_xp = 0
	for p in parts:
		total_xp += p.xp
	var rounded: Array = []
	for p in parts:
		rounded.append({"label": p.label, "xp": TTUtil.jsround(p.xp)})
	return {"xp": TTUtil.jsround(total_xp), "parts": rounded}


# ---------------------------------------------------------------------------
# Level curves. Fast early levels (first session ~ level 3), then a long tail.
# ---------------------------------------------------------------------------

static func hero_xp_for_level(level) -> int:
	return TTUtil.jsround(400 + 90 * level + 6 * level * level)


static func disc_xp_for_level(level) -> int:
	return TTUtil.jsround(300 + 70 * level + 5 * level * level)


## Level info for an XP total on a curve (`curve.call(level)` = XP needed to
## finish that level). Returns
## {level: int, into: int (XP inside the current level), toNext: int (XP
##  needed to finish it), total: the input, progress: float 0..1}.
static func level_from_xp(total, curve: Callable) -> Dictionary:
	var level: int = 1
	var rem: int = maxi(0, int(floor(total)))
	while level < MAX_LEVEL and rem >= curve.call(level):
		rem -= curve.call(level)
		level += 1
	var to_next = curve.call(level)
	return {"level": level, "into": rem, "toNext": to_next, "total": total, "progress": 1.0 if level >= MAX_LEVEL else float(rem) / to_next}


# Same as `level_from_xp`, on a prebuilt cost table (index = level). The
# replay recomputes levels thousands of times, so the two built-in curves
# skip the Callable.
static func _level_from_costs(total, costs: Array) -> Dictionary:
	var level: int = 1
	var rem: int = maxi(0, int(floor(total)))
	while level < MAX_LEVEL and rem >= costs[level]:
		rem -= costs[level]
		level += 1
	var to_next: int = costs[level]
	return {"level": level, "into": rem, "toNext": to_next, "total": total, "progress": 1.0 if level >= MAX_LEVEL else float(rem) / to_next}


static func hero_level(total) -> Dictionary:
	if _hero_costs == null:
		var costs: Array = [0]
		for l in range(1, MAX_LEVEL + 1):
			costs.append(hero_xp_for_level(l))
		_hero_costs = costs
	return _level_from_costs(total, _hero_costs)


static func disc_level(total) -> Dictionary:
	if _disc_costs == null:
		var costs: Array = [0]
		for l in range(1, MAX_LEVEL + 1):
			costs.append(disc_xp_for_level(l))
		_disc_costs = costs
	return _level_from_costs(total, _disc_costs)


## Total XP required to *reach* a hero level.
static func hero_xp_to_reach(level) -> int:
	var t: int = 0
	for l in range(1, int(level)):
		t += hero_xp_for_level(l)
	return t


## Index into STAGES for a hero level.
static func stage_for_level(level) -> int:
	var st: int = 0
	for i in range(STAGES.size()):
		if level >= STAGES[i].minLevel:
			st = i
	return st


## Total XP required to *reach* a discipline level.
static func disc_xp_to_reach(level) -> int:
	var t: int = 0
	for l in range(1, int(level)):
		t += disc_xp_for_level(l)
	return t


## Index into RANKS for a discipline level.
static func rank_for_level(level) -> int:
	var r: int = 0
	for i in range(RANKS.size()):
		if level >= RANKS[i].minLevel:
			r = i
	return r


## Rounded integer with thousands separators: 12345.6 -> "12,346".
static func fmt_int(n) -> String:
	var v: int = TTUtil.jsround(n)
	if v == 0 and n < 0:
		# JS rounds -0.5..0 to negative zero, which prints as "-0".
		return "-0"
	var digits: String = str(absi(v))
	var count: int = digits.length()
	var out: String = ""
	for i in range(count):
		if i > 0 and (count - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" + out) if v < 0 else out


static func is_discipline(x) -> bool:
	return x == "lift" or x == "climb" or x == "run" or x == "ride"
