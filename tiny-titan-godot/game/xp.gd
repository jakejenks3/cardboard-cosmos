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
		for c in s.climbs:
			var n = max(0, c["count"])
			if c.result == "attempt":
				st.attempts += n
			else:
				st.sends += n
				if n > 0:
					st.maxGradeSent = max(TTUtil.get_or(st, "maxGradeSent", -99), c.grade)
				if c.result == "flash":
					st.flashes += n
					if n > 0:
						st.maxGradeFlashed = max(TTUtil.get_or(st, "maxGradeFlashed", -99), c.grade)
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
	var text: String = str(raw).to_lower()
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
		for c in s.climbs:
			var each = climb_grade_xp(c.grade) * CLIMB_RESULT_MULT[c.result]
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
