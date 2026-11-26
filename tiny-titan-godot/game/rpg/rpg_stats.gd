class_name RpgStats
extends RefCounted
## The Realm's stat sheet (RPG_PLAN.md 2): twelve stats worked out from the
## real log, never stored. Six body stats (chest, shoulders, arms, back, core,
## legs) from the lifts and six traits (speed, endurance, grip, mind, flow,
## grit) from runs, climbs, pages read, physical therapy and showing up.
## Pure: no autoload, no screen, nothing is written.
##
##   sheet(input)                               the whole sheet (plan 2.3)
##   part_of(lift)                              the body stat a lift trains
##   is_mobility(exercise, marks)               the RPG's rule for PT and stretches
##   sets_by_part(sessions, marks, settings, date)   a day's sets per body stat
##   mobility_sets_on(sessions, marks, date)    a day's PT and stretch sets
##   lift_sets(session, marks)                  one lift session, for the boosts
##   scan(input, cutoff) / raws_of(facts)       the two halves of the sheet
##   scan_pair(input, early, late)              two days' facts for one pass
##
## A stat NEVER GOES DOWN while the log only grows: every part of every curve
## is a best ever, a count or a sum of what is logged up to a day, and nothing
## reads a CURRENT streak. That is also why a weighted bodyweight lift is
## measured against the bodyweight as its day began (the newest check-in
## before it), not the latest one: a weigh-in must not lower a stat.
##
## A day's facts are ONE pass over the sessions (scan). The sheet needs two
## days, today and seven days ago for "was", and gets both from one pass and
## the last week's sessions (scan_pair). What a lift is (its part, its anchor,
## what else it works) is looked up once per lift name and kept (_info_cache).
##
## Every number of the curves is a const below, to be tuned by the balance
## step against a real log (tools/rpg_sheet.gd prints a save's sheet).

# --- body stats (plan 2.1) ---------------------------------------------------

## Points a part's strength score can give (at a score of 1, the elite anchor).
const PEAK = 64.0
const PEAK_POW = 0.85
## The blended strength score counts up to this.
const SS_MAX = 1.2
## The best three movements of a part, blended.
const BLEND = [0.6, 0.25, 0.15]
## Days (runs, climbing sessions) it takes for a peak to count in full: the
## share is 1 - exp(-n / RAMP).
const RAMP = 3.0
## Points for the sets done: WORK_PTS at WORK_AT sets, on a log curve.
const WORK_PTS = 30.0
const WORK_K = 40.0
const WORK_AT = 4000.0

## The estimated one-rep max of a set: kg * (1 + min(reps, E1RM_REPS) / E1RM_DIV).
const E1RM_REPS = 12.0
const E1RM_DIV = 30.0
## The bodyweight used when no check-in says it.
const BW_UNKNOWN = 75.0
## A weightless set of a movement with no rep standard.
const WEIGHTLESS_CAP = 0.25
const WEIGHTLESS_REPS = 80.0
## A set with the heaviest band of the ladder.
const BAND_SS = 0.45
## A hold: HOLD_CAP at HOLD_SEC seconds.
const HOLD_CAP = 0.5
const HOLD_SEC = 240.0
## A movement with no anchor of its own (the part's default) counts up to this.
const DEFAULT_CAP = 0.7
## An assisted bodyweight set (the weight typed is the help, not a load).
const ASSISTED = 0.5

## What a weight on other equipment is worth against a barbell's.
const GEAR_FACTOR = {"barbell": 1.0, "smith": 1.0, "machine": 1.1, "cable": 0.65, "dumbbell": 0.48, "kettlebell": 0.4}
## A machine against a cable (both are a pin in a stack).
const CABLE_TO_MACHINE = 1.1
## The anchor of a movement with no row in ANCHORS, by part (a barbell's).
const PART_ANCHOR = {"chest": 140.0, "back": 140.0, "shoulders": 85.0, "arms": 70.0, "legs": 190.0, "core": 90.0, "full": 150.0}

## Elite one-rep maxes in kg: movement (its LiftLibrary name) -> [kg, the
## equipment that number is for]. Another equipment's anchor is this times
## GEAR_FACTOR[its] / GEAR_FACTOR[this one's] (anchor_of): a dumbbell number is
## a hand's, so "Lateral Raise 25 a hand" is 25 for a dumbbell and 34 a cable.
const ANCHORS = {
	# chest
	"Bench Press": [150.0, "barbell"], "Chest Fly": [45.0, "dumbbell"], "Pullover": [60.0, "dumbbell"],
	# back
	"Deadlift": [240.0, "barbell"], "Rack Pull": [280.0, "barbell"], "Bent Over Row": [140.0, "barbell"], "Seated Row": [130.0, "cable"],
	"Chest-Supported Row": [125.0, "barbell"], "T-Bar Row": [140.0, "barbell"], "Lat Pulldown": [130.0, "cable"],
	"Straight-Arm Pulldown": [65.0, "cable"], "Shrug": [220.0, "barbell"],
	# shoulders
	"Overhead Press": [95.0, "barbell"], "Push Press": [120.0, "barbell"], "Arnold Press": [42.0, "dumbbell"], "Lateral Raise": [25.0, "dumbbell"],
	"Front Raise": [28.0, "dumbbell"], "Rear Delt Fly": [25.0, "dumbbell"], "Face Pull": [60.0, "cable"], "Upright Row": [90.0, "barbell"],
	# arms
	"Bicep Curl": [75.0, "barbell"], "Hammer Curl": [38.0, "dumbbell"], "Reverse Curl": [55.0, "barbell"], "Zottman Curl": [28.0, "dumbbell"],
	"Tricep Pushdown": [90.0, "cable"], "Tricep Extension": [70.0, "barbell"], "Tricep Kickback": [24.0, "dumbbell"], "Wrist Curl": [70.0, "barbell"],
	"Farmer Carry": [110.0, "dumbbell"],
	# legs
	"Squat": [200.0, "barbell"], "Hack Squat": [280.0, "machine"], "Leg Press": [400.0, "machine"], "Leg Extension": [130.0, "machine"],
	"Bulgarian Split Squat": [50.0, "dumbbell"], "Split Squat": [50.0, "dumbbell"], "Lunge": [50.0, "dumbbell"], "Step-up": [40.0, "dumbbell"],
	"Romanian Deadlift": [190.0, "barbell"], "Stiff-Leg Deadlift": [180.0, "barbell"], "Good Morning": [140.0, "barbell"], "Leg Curl": [100.0, "machine"],
	"Swing": [80.0, "kettlebell"], "Hip Thrust": [230.0, "barbell"], "Glute Bridge": [200.0, "barbell"], "Pull-Through": [90.0, "cable"],
	"Glute Kickback": [55.0, "cable"], "Hip Abduction": [130.0, "machine"], "Hip Adduction": [130.0, "machine"], "Calf Raise": [200.0, "machine"],
	# core
	"Woodchop": [45.0, "cable"], "Pallof Press": [35.0, "cable"],
	# full body
	"Clean": [140.0, "barbell"], "Clean and Jerk": [150.0, "barbell"], "Snatch": [115.0, "barbell"], "Thruster": [110.0, "barbell"],
	"Turkish Get-up": [48.0, "kettlebell"],
}
## Elite reps in one set of a bodyweight movement.
const BW_ANCHORS = {"Pull-up": 25.0, "Chin-up": 25.0, "Push-up": 60.0, "Dip": 35.0, "Inverted Row": 30.0, "Leg Raise": 30.0,
	"Toes-to-Bar": 20.0, "Nordic Curl": 12.0, "Pistol Squat": 15.0, "Handstand Push-up": 15.0, "Muscle-up": 10.0}

## A library body part as a body stat.
const FOLD = {"chest": "chest", "back": "back", "shoulders": "shoulders", "biceps": "arms", "triceps": "arms", "forearms": "arms",
	"quads": "legs", "hamstrings": "legs", "glutes": "legs", "calves": "legs", "core": "core"}
## A full-body lift (a clean, a thruster): its strength score counts for these
## parts, and each of its sets is this much of a set for these.
const FULL_PEAK = ["legs", "back"]
const FULL_SHARES = {"legs": 0.5, "back": 0.5, "core": 0.5}

# --- traits (plan 2.2) -------------------------------------------------------

const SPEED_PACE_PTS = 40.0
## The pace part: clamp((SPEED_PACE_REF / pace - SPEED_PACE_OFF) / SPEED_PACE_SPAN, 0, SPEED_PACE_TOP), pace in seconds a km.
const SPEED_PACE_REF = 180.0
const SPEED_PACE_OFF = 0.2
const SPEED_PACE_SPAN = 0.65
const SPEED_PACE_TOP = 1.1
## A run this long or longer with a time has a pace that counts.
const PACE_MIN_M = 1500.0
## A pace quicker than this (seconds a km; the fastest kilometre ever run took
## 132 s) is a typing slip and counts for nothing.
const PACE_FASTEST = 120.0
const SPEED_RUNS_PTS = 25.0
const SPEED_RUNS_K = 4.0
const SPEED_RUNS_AT = 150.0
const SPEED_KM_PTS = 15.0
const SPEED_KM_K = 20.0
const SPEED_KM_AT = 1500.0

const END_LONG_PTS = 60.0
const END_LONG_K = 2.0
const END_LONG_AT = 42.2
const END_KM_PTS = 20.0
const END_KM_K = 30.0
const END_KM_AT = 5000.0
## A km ridden and a km walked with a vest against a km run.
const END_RIDE = 0.3
const END_WALK = 0.5
const END_SESS_PTS = 12.0
const END_SESS_K = 20.0
const END_SESS_AT = 2000.0

## The hardest send: GRADE_V0 for a V0, GRADE_STEP a grade (VB is one under V0).
const GRADE_V0 = 14.0
const GRADE_STEP = 5.0
## The hardest flash within FLASH_WITHIN grades of the hardest send.
const FLASH_BONUS = 2.0
const FLASH_WITHIN = 1
const HANG_KG_PTS = 0.2
const HANG_KG_MAX = 10.0
const HANG_SEC_DIV = 20.0
const HANG_SEC_MAX = 6.0
const SENDS_PTS = 20.0
const SENDS_K = 30.0
const SENDS_AT = 3000.0
const FOREARM_PTS = 6.0
const FOREARM_K = 100.0
const FOREARM_AT = 3000.0

const PAGES_PTS = 45.0
const PAGES_K = 150.0
const PAGES_AT = 30000.0
## A finished book: BOOK_PTS for the first BOOKS_FULL, BOOK_PTS_LATER after;
## one never read through the game (an empty log) BOOK_UNLOGGED of that.
const BOOK_PTS = 2.0
const BOOK_PTS_LATER = 1.0
const BOOKS_FULL = 5
const BOOK_UNLOGGED = 0.5
const BOOKS_MAX = 20.0
const READ_STREAK_DIV = 2.0
const READ_STREAK_MAX = 15.0
const READ_DAYS_DIV = 25.0
const READ_DAYS_MAX = 8.0

const MOB_PTS = 60.0
const MOB_K = 30.0
const MOB_AT = 10000.0
const HOLD_MIN_DIV = 10.0
const HOLD_MIN_MAX = 12.0
## A week with this many mobility sets is a week of keeping it up.
const MOB_WEEK_SETS = 9
const MOB_WEEKS_DIV = 4.0
const MOB_WEEKS_MAX = 8.0

const GRIT_DAYS_PTS = 40.0
const GRIT_DAYS_K = 20.0
const GRIT_DAYS_AT = 1500.0
const GRIT_STREAK_PTS = 2.0
const GRIT_STREAK_MAX = 20.0
const GRIT_PERFECT_PTS = 0.5
const GRIT_PERFECT_MAX = 15.0
## For having had a week on the goal at all.
const GRIT_STREAK_START = 3.0

# --- the sheet ----------------------------------------------------------------

## "was" is the sheet of this many days ago.
const WAS_DAYS = 7
## The sets a day of a part is taken to hold, for "one more day" in `next`.
const DAY_SETS = 4.0
## The short run "one more run" is taken to be, in km, for `next`.
const NEXT_RUN_KM = 1.0
const PART_WORDS = {"chest": "chest", "shoulders": "shoulder", "arms": "arm", "back": "back", "core": "core", "legs": "leg"}
const PART_START = {"chest": "a chest lift (a press, a fly, push-ups)", "shoulders": "a shoulder lift (a press, a lateral raise)",
	"arms": "an arm lift (curls, pushdowns)", "back": "a back lift (a row, a pulldown, pull-ups)",
	"core": "a core lift (a plank, sit-ups, leg raises)", "legs": "a leg lift (a squat, a leg press, a deadlift)"}

## What a lift is, by its name as logged (see _info).
static var _info_cache = {}
## The Monday of a date's week, by date (the two passes of a sheet share it).
static var _week_cache = {}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

static func _arr(v) -> Array:
	return v if v is Array else []


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func _num(v) -> float:
	return float(v) if (v is int or v is float) else 0.0


## log(1 + x / k) / log(1 + at / k): 0 at nothing, 1 at `at`, slower and slower.
static func _logc(x: float, k: float, at: float) -> float:
	return log(1.0 + maxf(0.0, x) / k) / log(1.0 + at / k)


static func _clamp(raw: float) -> float:
	return clampf(raw, RpgDefs.STAT_MIN, RpgDefs.STAT_MAX)


## The share of a peak that counts after n days (runs, sessions).
static func ramp(n: float) -> float:
	return 1.0 - exp(-maxf(0.0, n) / RAMP)


## The smallest n in 1..hi that `reaches` says yes to (it must stay yes for
## every larger n), 0 when not even hi does.
static func _least(hi: int, reaches: Callable) -> int:
	if not reaches.call(hi):
		return 0
	var lo = 1
	var top = hi
	while lo < top:
		var mid = (lo + top) >> 1
		if reaches.call(mid):
			top = mid
		else:
			lo = mid + 1
	return lo


## The smallest x in (lo, hi] that `reaches` says yes to, -1 when hi does not.
static func _least_f(lo: float, hi: float, reaches: Callable) -> float:
	if not reaches.call(hi):
		return -1.0
	var a = lo
	var b = hi
	for i in range(40):
		var mid = (a + b) * 0.5
		if reaches.call(mid):
			b = mid
		else:
			a = mid
	return b


# ---------------------------------------------------------------------------
# What a lift is
# ---------------------------------------------------------------------------

## A part of the weekly-sets count (Dose) or of the library as a body stat, "" none.
static func _fold(part: String) -> String:
	return str(FOLD.get(str(Dose.AREA.get(part, part)), ""))


## The equipment a lift's name says: a GEAR_FACTOR key when it has one.
static func _gear(lift_name: String) -> String:
	if str(LiftNames.split(lift_name).variation).to_lower().contains("smith"):
		return "smith"
	var g = Missions.gear_of_lift(lift_name)
	return str(g[0]) if not g.is_empty() else ""


## What a weight on `gear` is worth against the same lift on `base` (the
## equipment an anchor is said for). Equipment with no factor (a plate, a
## vest) is taken as the anchor's own.
static func gear_rel(gear: String, base: String) -> float:
	if gear == base or not GEAR_FACTOR.has(gear) or not GEAR_FACTOR.has(base):
		return 1.0
	if base == "cable" and gear == "machine":
		return CABLE_TO_MACHINE
	return float(GEAR_FACTOR[gear]) / float(GEAR_FACTOR[base])


## The anchor of a lift in kg (the elite one-rep max a weighted set is measured
## against): {"kg", "own" (false: the part's default, capped at DEFAULT_CAP)}.
## 0 kg for a lift of no body part.
static func anchor_of(lift_name: String) -> Dictionary:
	var i = _info(lift_name)
	return {"kg": float(i.anchor), "own": not bool(i.capped)}


## Everything the pass needs to know about a lift, by its name as logged:
## {"key" (normalized name, for PT and L+R marks), "lib_mob" (the library or
##  its name says mobility), "part" (body stat, "full", or ""), "shares"
##  ({body stat: sets a set of it counts for}), "own" ([body stats its
##  strength score and its days count for]), "forearm", "move" (the movement
##  as shown), "mkey", "anchor" (kg), "capped", "bw_only", "bw_anchor",
##  "assisted", "usual_both"}.
static func _info(lift_name: String) -> Dictionary:
	var hit = _info_cache.get(lift_name)
	if hit != null:
		return hit
	var sp = LiftNames.split(lift_name)
	var mv = Missions.move_of(lift_name)
	var entry = LiftNames.movement(mv)
	var move = str(entry.name) if entry != null else mv.strip_edges()
	var lib_part = Dosage.part(lift_name)
	var part = "full" if lib_part == "full" else str(FOLD.get(lib_part, ""))
	var out = {
		"key": Xp.normalize_exercise(lift_name),
		"lib_mob": lib_part == "mobility" or lift_name.to_lower().contains("stretch"),
		"part": part, "shares": {}, "own": [], "forearm": lib_part == "forearms",
		"move": move, "mkey": Xp.normalize_exercise(move),
		"anchor": 0.0, "capped": false,
		"bw_only": entry != null and Array(entry.get("only", [])).has("Bodyweight"),
		"bw_anchor": float(BW_ANCHORS.get(move, 0.0)),
		"assisted": str(sp.variation).to_lower().contains("assist"),
		"usual_both": Sides.usual(lift_name),
	}
	if part != "" and not out.lib_mob:
		if part == "full":
			out.own = FULL_PEAK.duplicate()
			out.shares = FULL_SHARES.duplicate()
		else:
			out.own = [part]
			out.shares[part] = 1.0
		var also = Dose.also_of(lift_name)
		for a in also:
			var p = _fold(str(a))
			# (the lift's own part is dropped; of two muscles of one part the larger share counts)
			if p == "" or p == part:
				continue
			out.shares[p] = maxf(float(out.shares.get(p, 0.0)), float(also[a]))
		var gear = _gear(lift_name)
		var row = ANCHORS.get(move)
		if row != null:
			out.anchor = float(row[0]) * gear_rel(gear, str(row[1]))
		else:
			out.anchor = float(PART_ANCHOR[part]) * gear_rel(gear, "barbell")
			out.capped = true
	if _info_cache.size() > 4000:
		_info_cache.clear()
	_info_cache[lift_name] = out
	return out


## The body stat a lift trains: "chest", "shoulders", "arms", "back", "core",
## "legs"; "full" for a full-body lift (its strength score counts for legs and
## back, its sets half a set each for legs, back and core); "" for none
## (mobility, a lift of the player's own that no part can be told for).
static func part_of(lift_name: String) -> String:
	var i = _info(lift_name)
	return "" if bool(i.lib_mob) else str(i.part)


## Is this exercise mobility work for the Realm: marked physical therapy, a
## library movement of the mobility part, or "stretch" in its name? Its sets
## go to Flow and to nothing else. (Not Dosage.is_mobility: a hold that is not
## mobility, a plank or a dead hang, scores for its own part here.)
static func is_mobility(ex: Dictionary, marks: Dictionary) -> bool:
	var i = _info(str(ex.get("name", "")))
	return bool(i.lib_mob) or (str(i.key) != "" and marks.has(i.key))


static func _real(one) -> bool:
	return one is Dictionary and int(_num(one.get("reps"))) > 0


## The place on the ladder of the band a set was done with (1 the lightest),
## 0 when it was done with none (Bands.is_band and Bands.level in one look).
static func _band_level(one: Dictionary) -> int:
	var b = one.get("band")
	return Bands.level(b) if (b is String and b != "") else 0


## What a set with `reps` reps and no weight scores.
static func _reps_ss(info: Dictionary, reps: float) -> float:
	if float(info.bw_anchor) > 0.0:
		return reps / float(info.bw_anchor)
	return minf(WEIGHTLESS_CAP, reps / WEIGHTLESS_REPS)


## The strength score of one real set of a lift (plan 2.1). `sides`: 2 when
## its reps are both sides added up; `bw`: the bodyweight of that day in kg.
## A weighted set never scores under the same reps without the weight.
static func set_ss(info: Dictionary, one: Dictionary, sides: int, bw: float) -> float:
	var reps = _num(one.get("reps")) / float(maxi(1, sides))
	var sec = _num(one.get("holdSec"))
	# (an assisted set: its weight or its band is the help, so neither is a load)
	if bool(info.assisted) and sec <= 0.0:
		return _reps_ss(info, reps) * ASSISTED
	var band = _band_level(one)
	if band > 0:
		return BAND_SS * float(band) / float(Bands.LADDER.size())
	if sec > 0.0:
		return minf(HOLD_CAP, sec / HOLD_SEC)
	var kg = _num(one.get("weightKg"))
	if kg <= 0.0:
		return _reps_ss(info, reps)
	if bool(info.bw_only):
		return _reps_ss(info, reps) * (1.0 + kg / maxf(1.0, bw))
	if float(info.anchor) <= 0.0:
		return _reps_ss(info, reps)
	var ss = kg * (1.0 + minf(reps, E1RM_REPS) / E1RM_DIV) / float(info.anchor)
	if bool(info.capped):
		ss = minf(ss, DEFAULT_CAP)
	return maxf(ss, _reps_ss(info, reps))


## How a set was scored: "band", "hold", "reps" (no weight), "bw" (a bodyweight
## movement with weight added) or "kg".
static func _set_kind(info: Dictionary, one: Dictionary) -> String:
	var held = _num(one.get("holdSec")) > 0.0
	if bool(info.assisted) and not held:
		return "reps"
	if _band_level(one) > 0:
		return "band"
	if held:
		return "hold"
	if _num(one.get("weightKg")) <= 0.0 or (float(info.anchor) <= 0.0 and not bool(info.bw_only)):
		return "reps"
	return "bw" if bool(info.bw_only) else "kg"


## The strength score of a set of a named lift, for tests and tuning.
static func ss_of(lift_name: String, one: Dictionary, settings: Dictionary = {}, bw: float = BW_UNKNOWN) -> float:
	return set_ss(_info(lift_name), one, Sides.n(settings, lift_name), bw)


## Check-ins with a weight, oldest first: [[date, kg]].
static func _bodyweights(body: Array) -> Array:
	var out = []
	for b in body:
		if b is Dictionary and _num(b.get("weightKg")) > 0.0 and str(b.get("date", "")) != "":
			out.append([str(b.date), _num(b.weightKg)])
	out.sort_custom(func(a, c): return str(a[0]) < str(c[0]))
	return out


## The bodyweight a day's sets are measured against: the newest check-in
## BEFORE that day (Standards.bodyweight of the body log as the day began),
## BW_UNKNOWN when there was none yet. Not the day's own check-in, and not the
## latest one: whatever is logged from a day on can then never lower what a
## set of that day scored.
static func _bw_on(weights: Array, date: String) -> float:
	var kg = BW_UNKNOWN
	for w in weights:
		if str(w[0]) >= date:
			break
		kg = float(w[1])
	return kg


# ---------------------------------------------------------------------------
# A day's sets (shared with the boosts)
# ---------------------------------------------------------------------------

## One lift session's sets: {"sets": {body stat: sets (direct 1, also-works at
## its share)}, "mobility": PT and stretch sets, "strength": it holds a real
## set that is not mobility}. Anything but a lift session: nothing.
static func lift_sets(s: Dictionary, marks: Dictionary) -> Dictionary:
	var out = {"sets": {}, "mobility": 0, "strength": false}
	if str(s.get("discipline", "")) != "lift":
		return out
	for ex in _arr(s.get("exercises")):
		if not (ex is Dictionary):
			continue
		var n = 0
		for one in _arr(ex.get("sets")):
			if _real(one):
				n += 1
		if n == 0:
			continue
		var i = _info(str(ex.get("name", "")))
		if bool(i.lib_mob) or (str(i.key) != "" and marks.has(i.key)):
			out.mobility = int(out.mobility) + n
			continue
		out.strength = true
		for p in i.shares:
			out.sets[p] = float(out.sets.get(p, 0.0)) + float(n) * float(i.shares[p])
	return out


## The sets each body stat got on a day: {stat: sets} for all six (a set of a
## lift whose part it is counts 1, of a lift that also works it its share;
## mobility is left out, and so is climbing: a pump comes from lifting).
## `_settings` is not needed for a count of sets; it is in the plan's signature.
static func sets_by_part(sessions: Array, marks: Dictionary, _settings: Dictionary, date: String) -> Dictionary:
	var out = {}
	for p in RpgDefs.BODY:
		out[p] = 0.0
	for s in sessions:
		if not (s is Dictionary) or str(s.get("date", "")) != date or str(s.get("discipline", "")) != "lift":
			continue
		var got = lift_sets(s, marks).sets
		for p in got:
			out[p] = float(out.get(p, 0.0)) + float(got[p])
	return out


## The physical therapy and stretch sets of a day.
static func mobility_sets_on(sessions: Array, marks: Dictionary, date: String) -> int:
	var n = 0
	for s in sessions:
		if s is Dictionary and str(s.get("date", "")) == date and str(s.get("discipline", "")) == "lift":
			n += int(lift_sets(s, marks).mobility)
	return n


# ---------------------------------------------------------------------------
# The pass over the log
# ---------------------------------------------------------------------------

static func _blank(cutoff: String) -> Dictionary:
	var f = {
		"cutoff": cutoff, "sessions": 0, "dates": {}, "week_counts": {},
		"work": {}, "direct": {}, "days": {}, "moves": {}, "climb_work": {},
		"mob_sets": 0, "mob_hold_sec": 0.0, "mob_weeks": {},
		"runs": 0, "run_m": 0.0, "longest_run_m": 0.0, "pace": 0.0, "pace_from": {},
		"ride_m": 0.0, "walk_m": 0.0,
		"climb_sessions": 0, "sends": 0, "max_send": null, "max_flash": null, "best_hang_kg": null, "longest_hang_sec": 0,
		"forearm_sets": 0,
		"pages": 0, "read_days": 0, "best_read_streak": 0, "books": 0, "books_logged": 0,
		"active_days": 0, "best_week_streak": 0, "perfect_days": 0, "goal": 3,
		"top": {}, "move_count": {},
	}
	for p in RpgDefs.BODY:
		f.work[p] = 0.0
		f.direct[p] = 0
		f.days[p] = {}
		f.climb_work[p] = 0.0
	return f


static func _take_lift(f: Dictionary, s: Dictionary, date: String, wk: String, marks: Dictionary, both: Dictionary, weights: Array) -> void:
	var bw = -1.0
	for ex in _arr(s.get("exercises")):
		if not (ex is Dictionary):
			continue
		var sets = _arr(ex.get("sets"))
		if sets.is_empty():
			continue
		var lift_name = str(ex.get("name", ""))
		var i = _info(lift_name)
		if str(i.key) == "":
			continue
		if bool(i.lib_mob) or marks.has(i.key):
			# Mobility: its sets (and the time held in them) are Flow's, nothing else's.
			var done = 0
			for one in sets:
				if not _real(one):
					continue
				done += 1
				var held = _num(one.get("holdSec"))
				if held > 0.0:
					f.mob_hold_sec = float(f.mob_hold_sec) + held * _num(one.reps)
			if done > 0:
				f.mob_sets = int(f.mob_sets) + done
				f.mob_weeks[wk] = int(f.mob_weeks.get(wk, 0)) + done
			continue
		if str(i.part) == "":
			continue
		var mark = both.get(i.key)
		var sides = 2 if (bool(mark.on) if (mark is Dictionary and mark.has("on")) else bool(i.usual_both)) else 1
		if bw < 0.0:
			bw = _bw_on(weights, date)
		var n = 0
		var best = null
		var best_ss = -1.0
		for one in sets:
			if not _real(one):
				continue
			n += 1
			var ss = set_ss(i, one, sides, bw)
			if ss > best_ss:
				best_ss = ss
				best = one
		if n == 0:
			continue
		for p in i.shares:
			f.work[p] = float(f.work[p]) + float(n) * float(i.shares[p])
		for p in i.own:
			f.days[p][date] = true
		if str(i.part) != "full":
			f.direct[i.part] = int(f.direct[i.part]) + n
		if bool(i.forearm):
			f.forearm_sets = int(f.forearm_sets) + n
		var cur = f.moves.get(i.mkey)
		# (the best ever; of two as good the earlier day, so the order the
		# sessions are stored in changes nothing)
		if best != null and (cur == null or best_ss > float(cur.ss) or (best_ss == float(cur.ss) and date < str(cur.date))):
			f.moves[i.mkey] = {"ss": best_ss, "mkey": str(i.mkey), "move": str(i.move), "name": lift_name, "kind": _set_kind(i, best),
				"kg": _num(best.get("weightKg")), "reps": int(_num(best.get("reps"))), "sec": int(_num(best.get("holdSec"))),
				"band": str(best.get("band", "")), "sides": sides, "date": date, "parts": i.own,
				"anchor": float(i.anchor), "capped": bool(i.capped), "bw_anchor": float(i.bw_anchor), "bw": bw}


static func _take_climb(f: Dictionary, s: Dictionary, climb_work: Dictionary) -> void:
	f.climb_sessions = int(f.climb_sessions) + 1
	for p in climb_work:
		f.work[p] = float(f.work[p]) + float(climb_work[p])
		f.climb_work[p] = float(f.climb_work[p]) + float(climb_work[p])
	for c in _arr(s.get("climbs")):
		if not (c is Dictionary):
			continue
		var n = int(_num(c.get("count")))
		var result = str(c.get("result", ""))
		if n <= 0 or result == "attempt":
			continue
		# (a route counts as the boulder grade it is worth)
		var g = int(_num(c.get("grade")))
		if Xp.is_route(c) and Xp.yds_index(c.get("yds")) >= 0:
			g = Xp.yds_to_v(Xp.yds_index(c.get("yds")))
		f.sends = int(f.sends) + n
		if f.max_send == null or g > int(f.max_send):
			f.max_send = g
		if result == "flash" and (f.max_flash == null or g > int(f.max_flash)):
			f.max_flash = g
	for h in _arr(s.get("hangs")):
		if not (h is Dictionary):
			continue
		var sec = int(_num(h.get("sec")))
		if sec <= 0 or int(_num(h.get("count", 1))) <= 0:
			continue
		f.longest_hang_sec = maxi(int(f.longest_hang_sec), sec)
		# (the heaviest two-arm hang of 5 s or more, as the rules' record)
		if int(_num(h.get("arms", 2))) == 2 and sec >= 5:
			var add = _num(h.get("addKg"))
			if f.best_hang_kg == null or add > float(f.best_hang_kg):
				f.best_hang_kg = add


static func _take_run(f: Dictionary, s: Dictionary, date: String) -> void:
	var m = maxf(0.0, _num(s.get("distanceM")))
	var dur = _num(s.get("durationSec"))
	f.runs = int(f.runs) + 1
	f.run_m = float(f.run_m) + m
	f.longest_run_m = maxf(float(f.longest_run_m), m)
	if dur > 0.0 and m >= PACE_MIN_M:
		_take_pace(f, dur / (m / 1000.0), {"what": "run", "m": m, "sec": dur, "date": date})
	var splits = RunSplits.of_session(s)
	for d in RunSplits.DISTS:
		var id = str(d.id)
		if splits.has(id):
			_take_pace(f, RunSplits.pace(id, float(splits[id])), {"what": "split", "id": id, "sec": float(splits[id]), "date": date})


## Keep a pace (seconds a km) when it is the best so far; of two as quick the
## earlier day's, so the order the sessions are stored in changes nothing.
static func _take_pace(f: Dictionary, p: float, from: Dictionary) -> void:
	if p < PACE_FASTEST:
		return
	var best = float(f.pace)
	if best <= 0.0 or p < best or (p == best and str(from.date) < str(f.pace_from.get("date", ""))):
		f.pace = p
		f.pace_from = from


static func _take_reading(f: Dictionary, reading: Array, cutoff: String) -> void:
	var by_date = {}
	for e in reading:
		if not (e is Dictionary):
			continue
		var d = str(e.get("date", ""))
		var pages = int(_num(e.get("pages")))
		if d == "" or d > cutoff or pages <= 0:
			continue
		by_date[d] = int(by_date.get(d, 0)) + pages
	var days = by_date.keys()
	days.sort()
	var run = 0
	var prev = ""
	for d in days:
		f.pages = int(f.pages) + int(by_date[d])
		run = run + 1 if (prev != "" and Dates.add_days(prev, 1) == str(d)) else 1
		f.best_read_streak = maxi(int(f.best_read_streak), run)
		prev = str(d)
	f.read_days = days.size()


static func _take_books(f: Dictionary, books: Array, cutoff: String) -> void:
	for b in books:
		if not (b is Dictionary) or str(b.get("status", "")) != "finished":
			continue
		# (a book with no day it was finished on was read before the game)
		var done = str(b.get("finished", ""))
		if done != "" and done > cutoff:
			continue
		f.books = int(f.books) + 1
		if not _dict(b.get("log")).is_empty():
			f.books_logged = int(f.books_logged) + 1


static func _take_claims(f: Dictionary, claims: Array, cutoff: String) -> void:
	var seen = {}
	for c in claims:
		if not (c is Dictionary):
			continue
		var day = perfect_day_of(c)
		if day != "" and day <= cutoff:
			seen[day] = true
	f.perfect_days = seen.size()


## The day a claim is the perfect-day chest of ("t:<date>:perfect"), "" when it
## is another claim.
static func perfect_day_of(claim: Dictionary) -> String:
	var q = str(claim.get("questId", ""))
	if not q.ends_with(":perfect"):
		return ""
	var parts = q.split(":")
	if parts.size() == 3 and str(parts[1]).length() == 10:
		return str(parts[1])
	return str(claim.get("date", ""))


## What a finished-books count is worth: the ones read through the game first
## (full points), then the ones only put on the shelf.
static func book_pts(books: int, logged: int) -> float:
	var pts = 0.0
	for i in range(maxi(0, books)):
		var base = BOOK_PTS if i < BOOKS_FULL else BOOK_PTS_LATER
		pts += base if i < logged else base * BOOK_UNLOGGED
	return pts


## What a pass needs beside the sessions: {"settings", "marks" (PT), "both"
## (the L+R switches), "weights" (check-ins, oldest first), "climb_work" (what
## a climbing session gives each body stat: the arms four sets, the back none)}.
static func _ctx(input: Dictionary) -> Dictionary:
	var settings = _dict(input.get("settings"))
	var climb_work = {}
	for p in Dose.CLIMB_SETS:
		var part = _fold(str(p))
		if part != "":
			climb_work[part] = float(climb_work.get(part, 0.0)) + float(Dose.CLIMB_SETS[p])
	return {"settings": settings, "marks": _dict(input.get("marks")), "both": Sides.marks(settings),
		"weights": _bodyweights(_arr(input.get("body"))), "climb_work": climb_work}


## One session of a day into the facts.
static func _take_session(f: Dictionary, s: Dictionary, date: String, ctx: Dictionary) -> void:
	f.sessions = int(f.sessions) + 1
	f.dates[date] = true
	var wk = _week_cache.get(date)
	if wk == null:
		if _week_cache.size() > 6000:
			_week_cache.clear()
		wk = Dates.week_key(date)
		_week_cache[date] = wk
	f.week_counts[wk] = int(f.week_counts.get(wk, 0)) + 1
	var disc = str(s.get("discipline", ""))
	if disc == "lift":
		_take_lift(f, s, date, str(wk), ctx.marks, ctx.both, ctx.weights)
	elif disc == "climb":
		_take_climb(f, s, ctx.climb_work)
	elif disc == "run":
		_take_run(f, s, date)
	elif disc == "ride":
		f.ride_m = float(f.ride_m) + maxf(0.0, _num(s.get("distanceM")))
	else:
		# (a vest walk, or any other activity with a distance)
		f.walk_m = float(f.walk_m) + maxf(0.0, _num(s.get("distanceM")))


## What is not in the sessions (pages, books, perfect days), and what is
## worked out once they are all in (the streak, each stat's best movements).
static func _finish(f: Dictionary, input: Dictionary, ctx: Dictionary) -> Dictionary:
	var cutoff = str(f.cutoff)
	_take_reading(f, _arr(input.get("reading")), cutoff)
	_take_books(f, _arr(input.get("books")), cutoff)
	_take_claims(f, _arr(input.get("claims")), cutoff)
	# Days trained and the best run of weeks on the weekly goal, as the rules
	# count them (state.totals.activeDays, state.streak.best), up to the cutoff.
	var goal = _dict(_dict(input.get("state")).get("streak")).get("goal")
	if not (goal is int or goal is float):
		goal = ctx.settings.get("weeklyGoal", 3)
	f.goal = maxi(1, int(_num(goal)))
	f.active_days = f.dates.size()
	f.best_week_streak = int(Derive.compute_streak(f.week_counts, int(f.goal), Dates.week_key(cutoff)).best) if not f.week_counts.is_empty() else 0
	# Each body stat's movements, the strongest first.
	for p in RpgDefs.BODY:
		var list = []
		for mk in f.moves:
			if f.moves[mk].parts.has(p):
				list.append(f.moves[mk])
		list.sort_custom(func(a, b):
			if float(a.ss) != float(b.ss):
				return float(a.ss) > float(b.ss)
			return str(a.mkey) < str(b.mkey))
		f.move_count[p] = list.size()
		f.top[p] = list.slice(0, BLEND.size())
	return f


## Everything the twelve stats are made of, from the log up to `cutoff` (a
## date key, that day included): one pass over the sessions. `input` is the
## sheet's (see sheet). The facts hold the numbers the curves take (raws_of)
## and what the lines say; "top" is each body stat's best three movements.
static func scan(input: Dictionary, cutoff: String) -> Dictionary:
	var ctx = _ctx(input)
	var f = _blank(cutoff)
	for s in _arr(input.get("sessions")):
		if not (s is Dictionary):
			continue
		var date = str(s.get("date", ""))
		if date == "" or date > cutoff:
			continue
		_take_session(f, s, date, ctx)
	return _finish(f, input, ctx)


## The facts of two days at once, [as of `early`, as of `late`] (early before
## late), each the same as its own `scan`: the sessions up to `early` are gone
## through ONCE, that state is copied, and only the sessions after it are added
## to the copy. The sheet's "now" and "was" cost one pass and a few days.
static func scan_pair(input: Dictionary, early: String, late: String) -> Array:
	if early >= late:
		return [scan(input, early), scan(input, late)]
	var ctx = _ctx(input)
	var a = _blank(early)
	var after = []
	for s in _arr(input.get("sessions")):
		if not (s is Dictionary):
			continue
		var date = str(s.get("date", ""))
		if date == "" or date > late:
			continue
		if date > early:
			after.append(s)
		else:
			_take_session(a, s, date, ctx)
	var b = a.duplicate(true)
	b.cutoff = late
	for s in after:
		_take_session(b, s, str(s.date), ctx)
	return [_finish(a, input, ctx), _finish(b, input, ctx)]


# ---------------------------------------------------------------------------
# The curves
# ---------------------------------------------------------------------------

## A part's strength score from its movements' scores, the best first.
static func peak_ss(scores: Array) -> float:
	var out = 0.0
	for i in range(mini(scores.size(), BLEND.size())):
		out += float(BLEND[i]) * float(scores[i])
	return out


## A body stat from its best movements' strength scores (best first), the days
## it was trained on and the sets it got.
static func body_raw(scores: Array, days: float, work: float) -> float:
	var peak_pts = PEAK * pow(clampf(peak_ss(scores), 0.0, SS_MAX), PEAK_POW) * ramp(days)
	var work_pts = WORK_PTS * _logc(work, WORK_K, WORK_AT)
	return _clamp(1.0 + peak_pts + work_pts)


## `pace`: the best seconds a km, 0 when no run was timed.
static func speed_raw(pace: float, runs: float, run_km: float) -> float:
	var pace_part = clampf((SPEED_PACE_REF / pace - SPEED_PACE_OFF) / SPEED_PACE_SPAN, 0.0, SPEED_PACE_TOP) if pace > 0.0 else 0.0
	return _clamp(1.0 + SPEED_PACE_PTS * pace_part * ramp(runs) + SPEED_RUNS_PTS * _logc(runs, SPEED_RUNS_K, SPEED_RUNS_AT)
		+ SPEED_KM_PTS * _logc(run_km, SPEED_KM_K, SPEED_KM_AT))


## `km`: runs + END_RIDE of the rides + END_WALK of the vest walks.
static func endurance_raw(longest_run_km: float, runs: float, km: float, sessions: float) -> float:
	return _clamp(1.0 + END_LONG_PTS * _logc(longest_run_km, END_LONG_K, END_LONG_AT) * ramp(runs)
		+ END_KM_PTS * _logc(km, END_KM_K, END_KM_AT) + END_SESS_PTS * _logc(sessions, END_SESS_K, END_SESS_AT))


## The points of the hardest send (a V grade, -1 = VB; null = none sent yet).
static func grade_pts(max_send, max_flash) -> float:
	if max_send == null:
		return 0.0
	var pts = GRADE_V0 + GRADE_STEP * float(int(max_send))
	if max_flash != null and int(max_flash) >= int(max_send) - FLASH_WITHIN:
		pts += FLASH_BONUS
	return maxf(0.0, pts)


static func grip_raw(grade: float, best_hang_kg: float, longest_hang_sec: float, climb_sessions: float, sends: float, forearm_sets: float) -> float:
	var peak = grade + minf(HANG_KG_MAX, HANG_KG_PTS * maxf(0.0, best_hang_kg)) + minf(HANG_SEC_MAX, longest_hang_sec / HANG_SEC_DIV)
	return _clamp(1.0 + peak * ramp(climb_sessions) + SENDS_PTS * _logc(sends, SENDS_K, SENDS_AT)
		+ FOREARM_PTS * _logc(forearm_sets, FOREARM_K, FOREARM_AT))


static func mind_raw(pages: float, books_pts: float, best_streak: float, read_days: float) -> float:
	return _clamp(1.0 + PAGES_PTS * _logc(pages, PAGES_K, PAGES_AT) + minf(BOOKS_MAX, books_pts)
		+ minf(READ_STREAK_MAX, best_streak / READ_STREAK_DIV) + minf(READ_DAYS_MAX, read_days / READ_DAYS_DIV))


static func flow_raw(mobility_sets: float, hold_minutes: float, good_weeks: float) -> float:
	return _clamp(1.0 + MOB_PTS * _logc(mobility_sets, MOB_K, MOB_AT) + minf(HOLD_MIN_MAX, hold_minutes / HOLD_MIN_DIV)
		+ minf(MOB_WEEKS_MAX, good_weeks / MOB_WEEKS_DIV))


static func grit_raw(active_days: float, best_week_streak: float, perfect_days: float) -> float:
	return _clamp(1.0 + GRIT_DAYS_PTS * _logc(active_days, GRIT_DAYS_K, GRIT_DAYS_AT) + minf(GRIT_STREAK_MAX, GRIT_STREAK_PTS * best_week_streak)
		+ minf(GRIT_PERFECT_MAX, GRIT_PERFECT_PTS * perfect_days) + (GRIT_STREAK_START if best_week_streak >= 1.0 else 0.0))


static func _scores(f: Dictionary, part: String) -> Array:
	var out = []
	for m in f.top[part]:
		out.append(float(m.ss))
	return out


static func _good_weeks(f: Dictionary) -> int:
	var n = 0
	for wk in f.mob_weeks:
		if int(f.mob_weeks[wk]) >= MOB_WEEK_SETS:
			n += 1
	return n


static func _km(f: Dictionary) -> float:
	return (float(f.run_m) + END_RIDE * float(f.ride_m) + END_WALK * float(f.walk_m)) / 1000.0


## The twelve stats of some facts: {stat id: raw (1..99.99)}.
static func raws_of(f: Dictionary) -> Dictionary:
	var out = {}
	for p in RpgDefs.BODY:
		out[p] = body_raw(_scores(f, p), float(f.days[p].size()), float(f.work[p]))
	out["speed"] = speed_raw(float(f.pace), float(f.runs), float(f.run_m) / 1000.0)
	out["endurance"] = endurance_raw(float(f.longest_run_m) / 1000.0, float(f.runs), _km(f), float(f.sessions))
	out["grip"] = grip_raw(grade_pts(f.max_send, f.max_flash), float(f.best_hang_kg) if f.best_hang_kg != null else 0.0,
		float(f.longest_hang_sec), float(f.climb_sessions), float(f.sends), float(f.forearm_sets))
	out["mind"] = mind_raw(float(f.pages), book_pts(int(f.books), int(f.books_logged)), float(f.best_read_streak), float(f.read_days))
	out["flow"] = flow_raw(float(f.mob_sets), float(f.mob_hold_sec) / 60.0, float(_good_weeks(f)))
	out["grit"] = grit_raw(float(f.active_days), float(f.best_week_streak), float(f.perfect_days))
	return out


# ---------------------------------------------------------------------------
# The sheet
# ---------------------------------------------------------------------------

## The stat sheet (plan 2.3). `input` = {"sessions", "state" (App.state),
## "reading" (saved.reading), "books", "body", "claims", "settings", "marks"
## (App.pt()), "today"}, all plain data, every key optional. Returns
## {"stats": {id: {"id", "name", "v" (floor of raw), "raw" (1..99.99), "was"
##   (raw seven days ago), "lines" (what it is made of, in the player's
##   units), "next" (the nearest way to the next point)}},
##  "body": [ids], "traits": [ids], "might" (mean raw of the body stats),
##  "days" (days trained), "sessions", "today", "facts" (scan of today, for
##  tools and tests)}.
## Sessions, pages and claims dated after `today` are not counted.
static func sheet(input: Dictionary) -> Dictionary:
	var today = str(input.get("today", ""))
	if today == "":
		today = Dates.today_key()
	var settings = _dict(input.get("settings"))
	var pair = scan_pair(input, Dates.add_days(today, -WAS_DAYS), today)
	var now: Dictionary = pair[1]
	var raws = raws_of(now)
	var was = raws_of(pair[0])
	var stats = {}
	var might = 0.0
	for id in RpgDefs.STATS:
		var raw = float(raws[id])
		stats[id] = {"id": id, "name": str(RpgDefs.STAT_NAMES[id]), "v": int(floor(raw)), "raw": raw, "was": minf(float(was[id]), raw),
			"lines": _lines(id, now, settings), "next": _next(id, now, raw, settings)}
		if RpgDefs.BODY.has(id):
			might += raw
	return {"stats": stats, "body": RpgDefs.BODY.duplicate(), "traits": RpgDefs.TRAITS.duplicate(),
		"might": might / float(RpgDefs.BODY.size()), "days": int(now.active_days), "sessions": int(now.sessions),
		"today": today, "facts": now}


# ---------------------------------------------------------------------------
# What a stat is made of, in words
# ---------------------------------------------------------------------------

static func _wu(settings: Dictionary) -> String:
	return "lb" if str(settings.get("weightUnit", "kg")) == "lb" else "kg"


static func _du(settings: Dictionary) -> String:
	return "mi" if str(settings.get("distanceUnit", "km")) == "mi" else "km"


static func _count(n: float) -> String:
	return Fmt.fmt_num(floor(n + 0.5), 0)


static func _plural(n: int, one: String, many: String) -> String:
	return "%s %s" % [Fmt.fmt_num(float(n), 0), one if n == 1 else many]


## A lift as a few words: the movement, and its variation when it is not the
## movement's usual one ("Bench Press", "Bench Press (incline dumbbell)").
static func _lift_words(lift_name: String) -> String:
	var sp = LiftNames.split(lift_name)
	var entry = LiftNames.movement(str(sp.move))
	var v = str(sp.variation)
	if v == "" or (entry != null and v == str(entry.get("usual", ""))):
		return str(sp.move)
	return "%s (%s)" % [str(sp.move), v.to_lower()]


## A movement's best set as it was really done: "Squat 230 lb x 5", "Pull-up
## +45 lb x 8", "Push-up x 30", "Plank 90 s hold", "Face Pull x 15, green band".
static func _set_words(m: Dictionary, wu: String, reps = null, kg = null) -> String:
	var n = int(m.reps) if reps == null else int(reps)
	var w = float(m.kg) if kg == null else float(kg)
	var who = _lift_words(str(m.name))
	var both = " %s" % Sides.SHORT if int(m.sides) > 1 else ""
	match str(m.kind):
		"band":
			return "%s x %d%s, %s" % [who, n, both, Bands.words(m.band)]
		"hold":
			return "%s %d s hold" % [who, int(m.sec)]
		"reps":
			return "%s x %d%s" % [who, n, both]
		"bw":
			return "%s +%s x %d%s" % [who, Fmt.fmt_weight(w, wu), n, both]
	return "%s %s x %d%s" % [who, Fmt.fmt_weight(w, wu), n, both]


static func _body_lines(part: String, f: Dictionary, settings: Dictionary) -> Array:
	var wu = _wu(settings)
	var top: Array = f.top[part]
	var work = float(f.work[part])
	if top.is_empty() and work <= 0.0:
		return ["Nothing logged for it yet."]
	var lines = []
	if top.is_empty():
		lines.append("No lift of its own yet.")
	else:
		lines.append("Best: %s" % _set_words(top[0], wu))
		if top.size() > 1:
			var rest = []
			for i in range(1, top.size()):
				rest.append(_set_words(top[i], wu))
			lines.append("Then: %s" % " · ".join(PackedStringArray(rest)))
	var made = []
	if int(f.direct[part]) > 0:
		made.append("%s direct" % _count(float(f.direct[part])))
	var climb = float(f.climb_work[part])
	if climb > 0.0:
		made.append("%s from climbing" % _count(climb))
	var other = work - float(f.direct[part]) - climb
	if other >= 0.5:
		made.append("%s from lifts that also work it" % _count(other))
	var line = "%s so far" % _plural(int(floor(work + 0.5)), "set", "sets")
	if made.size() > 1 or (made.size() == 1 and int(f.direct[part]) == 0):
		line += ": %s" % ", ".join(PackedStringArray(made))
	lines.append(line)
	if not f.days[part].is_empty():
		lines.append("Trained on %s" % _plural(f.days[part].size(), "day", "days"))
	return lines


static func _pace_words(f: Dictionary, du: String) -> String:
	var from = f.pace_from
	if str(from.get("what", "")) == "split":
		var d = RunSplits.by_id(str(from.id))
		return "your best %s, %s" % [str(d.name).to_lower() if d != null else "split", RunSplits.fmt_time(float(from.sec))]
	return "a %s run in %s" % [Fmt.fmt_distance(float(from.get("m", 0.0)), du), Fmt.fmt_duration(float(from.get("sec", 0.0)))]


static func _lines(id: String, f: Dictionary, settings: Dictionary) -> Array:
	if RpgDefs.BODY.has(id):
		return _body_lines(id, f, settings)
	var wu = _wu(settings)
	var du = _du(settings)
	var lines = []
	match id:
		"speed":
			if int(f.runs) == 0:
				return ["No run logged yet."]
			if float(f.pace) > 0.0:
				lines.append("Best pace: %s (%s)" % [Fmt.fmt_pace(float(f.pace), du), _pace_words(f, du)])
			else:
				lines.append("No run with a time yet: pace is the biggest part.")
			lines.append("%s, %s in all" % [_plural(int(f.runs), "run", "runs"), Fmt.fmt_distance(float(f.run_m), du)])
		"endurance":
			if int(f.sessions) == 0:
				return ["Nothing logged yet."]
			if int(f.runs) > 0:
				lines.append("Longest run: %s" % Fmt.fmt_distance(float(f.longest_run_m), du))
			else:
				lines.append("No run logged yet: the longest run is the biggest part.")
			var far = []
			if float(f.run_m) > 0.0:
				far.append("%s run" % Fmt.fmt_distance(float(f.run_m), du))
			if float(f.ride_m) > 0.0:
				far.append("%s ridden" % Fmt.fmt_distance(float(f.ride_m), du))
			if float(f.walk_m) > 0.0:
				far.append("%s walked with a vest" % Fmt.fmt_distance(float(f.walk_m), du))
			if not far.is_empty():
				lines.append("Distance: %s" % ", ".join(PackedStringArray(far)))
			lines.append("%s of every kind" % _plural(int(f.sessions), "session", "sessions"))
		"grip":
			if int(f.climb_sessions) == 0 and int(f.forearm_sets) == 0:
				return ["No climbing logged yet."]
			if f.max_send != null:
				var send = "Hardest send: %s" % Xp.grade_label(int(f.max_send))
				if f.max_flash != null:
					send += " (hardest flash: %s)" % Xp.grade_label(int(f.max_flash))
				lines.append(send)
			elif int(f.climb_sessions) > 0:
				lines.append("No send logged yet.")
			var hang = []
			if f.best_hang_kg != null and float(f.best_hang_kg) > 0.0:
				hang.append("heaviest hang +%s" % Fmt.fmt_weight(float(f.best_hang_kg), wu))
			if int(f.longest_hang_sec) > 0:
				hang.append("longest hang %d s" % int(f.longest_hang_sec))
			if not hang.is_empty():
				var words = ", ".join(PackedStringArray(hang))
				lines.append(words.substr(0, 1).to_upper() + words.substr(1))
			if int(f.climb_sessions) > 0:
				lines.append("%s in %s" % [_plural(int(f.sends), "send", "sends"), _plural(int(f.climb_sessions), "climbing session", "climbing sessions")])
			if int(f.forearm_sets) > 0:
				lines.append(_plural(int(f.forearm_sets), "forearm set", "forearm sets"))
		"mind":
			if int(f.pages) == 0 and int(f.books) == 0:
				return ["No pages logged yet."]
			lines.append("%s read" % _plural(int(f.pages), "page", "pages"))
			if int(f.books) > 0:
				lines.append("%s finished" % _plural(int(f.books), "book", "books"))
			if int(f.read_days) > 0:
				lines.append("Longest reading streak: %s · %s read on" % [_plural(int(f.best_read_streak), "day", "days"), _plural(int(f.read_days), "day", "days")])
		"flow":
			if int(f.mob_sets) == 0:
				return ["No physical therapy or stretches logged yet."]
			lines.append("%s of physical therapy and stretches" % _plural(int(f.mob_sets), "set", "sets"))
			if float(f.mob_hold_sec) >= 30.0:
				lines.append("%s min held in them" % _count(float(f.mob_hold_sec) / 60.0))
			if _good_weeks(f) > 0:
				lines.append("%s with %d sets or more" % [_plural(_good_weeks(f), "week", "weeks"), MOB_WEEK_SETS])
		"grit":
			if int(f.active_days) == 0:
				return ["Nothing logged yet."]
			lines.append("%s trained" % _plural(int(f.active_days), "day", "days"))
			if int(f.best_week_streak) > 0:
				lines.append("Best streak: %s on your weekly goal" % _plural(int(f.best_week_streak), "week", "weeks"))
			if int(f.perfect_days) > 0:
				lines.append(_plural(int(f.perfect_days), "perfect day", "perfect days"))
	return lines


# ---------------------------------------------------------------------------
# The nearest way to the next point
# ---------------------------------------------------------------------------

static func _ways(ways: Array, fallback: String) -> String:
	if ways.is_empty():
		return fallback
	var said = ways.slice(0, 2)
	var text = ", or ".join(PackedStringArray(said))
	return "Next point: %s." % text


## A heavier set on the part's best movement that gets the next point, in
## words ("Squat 235 lb x 5"), "" when none is near. A goal, never said as done.
static func _heavier(top: Array, scores: Array, days: float, work: float, target: float, settings: Dictionary) -> String:
	var m: Dictionary = top[0]
	var kind = str(m.kind)
	if kind != "kg" and kind != "bw" and kind != "reps":
		return ""
	var rest = scores.slice(1)
	var need = _least_f(float(m.ss), SS_MAX * 2.0, func(x): return body_raw([x] + rest, days, work) >= target)
	if need < 0.0:
		return ""
	var sides = float(maxi(1, int(m.sides)))
	var reps = float(m.reps) / sides
	if kind == "reps":
		if float(m.bw_anchor) <= 0.0:
			return ""
		var want = int(ceil(need * float(m.bw_anchor) * sides - 1e-6))
		want = maxi(want, int(m.reps) + 1)
		return _set_words(m, _wu(settings), want) if want <= int(m.reps) + 6 else ""
	var kg_need = 0.0
	if kind == "bw":
		var base = reps / float(m.bw_anchor) if float(m.bw_anchor) > 0.0 else minf(WEIGHTLESS_CAP, reps / WEIGHTLESS_REPS)
		if base <= 0.0:
			return ""
		kg_need = (need / base - 1.0) * maxf(1.0, float(m.bw))
	else:
		if bool(m.capped) and need > DEFAULT_CAP:
			return ""
		kg_need = need * float(m.anchor) / (1.0 + minf(reps, E1RM_REPS) / E1RM_DIV)
	var wu = _wu(settings)
	var step = float(TT.weight_step_of({"weightUnit": wu, "weightStep": settings.get("weightStep")}))
	var have = Fmt.kg_to_unit(float(m.kg), wu)
	var want_u = ceil(Fmt.kg_to_unit(kg_need, wu) / step - 1e-6) * step
	if want_u <= have + 1e-6:
		want_u = have + step
	if want_u > have * 1.12 + step:
		return ""
	return _set_words(m, wu, null, Fmt.unit_to_kg(want_u, wu))


static func _body_next(part: String, f: Dictionary, raw: float, settings: Dictionary) -> String:
	var top: Array = f.top[part]
	var work = float(f.work[part])
	var days = float(f.days[part].size())
	if top.is_empty() and work <= 0.0:
		return "Log %s to start it." % str(PART_START[part])
	var target = floor(raw) + 1.0
	var scores = _scores(f, part)
	var ways = []
	if top.is_empty():
		ways.append("%s of its own" % str(PART_START[part]))
	else:
		if days < 12.0 and body_raw(scores, days + 1.0, work + DAY_SETS) >= target:
			ways.append("one more %s day" % str(PART_WORDS[part]))
		var heavier = _heavier(top, scores, days, work, target, settings)
		if heavier != "":
			ways.append(heavier)
		if ways.is_empty() and scores.size() < BLEND.size() and body_raw(scores + [float(scores[scores.size() - 1]) * 0.5], days, work) >= target:
			ways.append("another %s movement" % str(PART_WORDS[part]))
	var n = _least(6000, func(k): return body_raw(scores, days, work + float(k)) >= target)
	if n > 0:
		ways.append("%s for it" % _plural(n, "more set", "more sets"))
	return _ways(ways, "Lift heavier on its best movement, or add another %s movement." % str(PART_WORDS[part]))


static func _next(id: String, f: Dictionary, raw: float, settings: Dictionary) -> String:
	if raw >= RpgDefs.STAT_MAX - 0.5:
		return "As high as it goes."
	if RpgDefs.BODY.has(id):
		return _body_next(id, f, raw, settings)
	var du = _du(settings)
	var target = floor(raw) + 1.0
	var ways = []
	match id:
		"speed":
			var runs = float(f.runs)
			var km = float(f.run_m) / 1000.0
			var pace = float(f.pace)
			if runs <= 0.0:
				return "Log a run to start it."
			var each = km / runs
			var n = _least(600, func(k): return speed_raw(pace, runs + float(k), km + float(k) * each) >= target)
			if pace <= 0.0:
				ways.append("a run of %s or more with its time" % Fmt.fmt_distance(PACE_MIN_M, du))
			else:
				# (the slowest pace that is enough: searched as seconds gained)
				var gain = _least_f(0.0, pace * 0.08, func(x): return speed_raw(pace - x, runs, km) >= target)
				if gain >= 0.0 and (n == 0 or n > 1):
					ways.append("a run at %s or faster" % Fmt.fmt_pace(pace - gain - 0.6, du))
			if n > 0:
				ways.insert(0 if n <= 2 else ways.size(), _plural(n, "more run", "more runs"))
			return _ways(ways, "Run faster, further or more often.")
		"endurance":
			var runs = float(f.runs)
			var km = _km(f)
			var longest = float(f.longest_run_m) / 1000.0
			var sessions = float(f.sessions)
			# (a short run may be enough: it is one more run, its distance and a session)
			if endurance_raw(maxf(longest, NEXT_RUN_KM), runs + 1.0, km + NEXT_RUN_KM, sessions + 1.0) >= target:
				ways.append("a run" if runs <= 0.0 else "one more run")
			else:
				var far = _least_f(longest, maxf(longest * 1.6, longest + 8.0),
					func(x): return endurance_raw(x, runs + 1.0, km + x, sessions + 1.0) >= target)
				if far > 0.0:
					var unit = Fmt.m_to_unit(far * 1000.0, du)
					ways.append("a run of %s %s" % [Fmt.fmt_num(ceil(unit * 10.0 - 1e-6) / 10.0, 1), du])
			var n = _least(4000, func(k): return endurance_raw(longest, runs, km, sessions + float(k)) >= target)
			if n > 0:
				ways.append("%s of any kind" % _plural(n, "more session", "more sessions"))
			return _ways(ways, "Run further than your longest run.")
		"grip":
			var sessions = float(f.climb_sessions)
			var hang_kg = float(f.best_hang_kg) if f.best_hang_kg != null else 0.0
			var hang_sec = float(f.longest_hang_sec)
			var sends = float(f.sends)
			var fore = float(f.forearm_sets)
			if sessions <= 0.0:
				if fore <= 0.0:
					return "Log a climbing session to start it."
				ways.append("a climbing session")
			else:
				var harder = -1 if f.max_send == null else int(f.max_send) + 1
				if harder <= Xp.MAX_V_GRADE and grip_raw(grade_pts(harder, f.max_flash), hang_kg, hang_sec, sessions, sends, fore) >= target:
					ways.append("send a %s" % Xp.grade_label(harder))
				var grade = grade_pts(f.max_send, f.max_flash)
				if sessions < 12.0 and grip_raw(grade, hang_kg, hang_sec, sessions + 1.0, sends, fore) >= target:
					ways.append("one more climbing session")
				var n = _least(6000, func(k): return grip_raw(grade, hang_kg, hang_sec, sessions, sends + float(k), fore) >= target)
				if n > 0:
					ways.append(_plural(n, "more send", "more sends"))
			return _ways(ways, "Send a harder grade.")
		"mind":
			var pages = float(f.pages)
			var streak = float(f.best_read_streak)
			var days = float(f.read_days)
			var books = book_pts(int(f.books), int(f.books_logged))
			if pages <= 0.0 and int(f.books) == 0:
				return "Log the pages you read to start it."
			var n = _least(40000, func(k): return mind_raw(pages + float(k), books, streak, days) >= target)
			if n > 0:
				ways.append(_plural(n, "more page", "more pages"))
			if mind_raw(pages, book_pts(int(f.books) + 1, int(f.books_logged) + 1), streak, days) >= target:
				ways.append("finish a book")
			return _ways(ways, "Read more pages.")
		"flow":
			var sets = float(f.mob_sets)
			var mins = float(f.mob_hold_sec) / 60.0
			var weeks = float(_good_weeks(f))
			if sets <= 0.0:
				return "Log physical therapy or a stretch to start it."
			var n = _least(20000, func(k): return flow_raw(sets + float(k), mins, weeks) >= target)
			if n > 0:
				ways.append("%s of physical therapy or stretches" % _plural(n, "more set", "more sets"))
			if flow_raw(sets, mins, weeks + 1.0) >= target:
				ways.append("a week with %d sets of it" % MOB_WEEK_SETS)
			return _ways(ways, "Keep up the physical therapy and the stretches.")
		"grit":
			var days = float(f.active_days)
			var streak = float(f.best_week_streak)
			var perfect = float(f.perfect_days)
			if days <= 0.0:
				return "Log a workout to start it."
			if grit_raw(days, streak, perfect + 1.0) >= target:
				ways.append("a perfect day")
			var n = _least(4000, func(k): return grit_raw(days + float(k), streak, perfect) >= target)
			if n > 0:
				ways.append(_plural(n, "more day trained", "more days trained"))
			if grit_raw(days, streak + 1.0, perfect) >= target:
				ways.append("a longer best streak of weeks on your goal")
			return _ways(ways, "Keep showing up.")
	return ""
