class_name Recovery
extends RefCounted
## How recently each body part was worked, from the log: a heat per part, 1 =
## worked hard today, fading to 0 as it recovers (big parts in RECOVER_BIG
## days, small ones in RECOVER_SMALL). A lift warms its body part fully and
## the parts the library says it also works by half; four working sets or
## more count as a full day for that part. Climbing warms forearms, back and
## biceps, running calves and legs, riding legs (OTHER). Pure logic, read by
## the muscle map (HeroBody.draw_muscle_map, TodayView) and tests/recovery_test.gd.

const PARTS = ["chest", "back", "shoulders", "biceps", "triceps", "forearms", "core", "quads", "hamstrings", "glutes", "calves"]
const NAMES = {"chest": "Chest", "back": "Back", "shoulders": "Shoulders", "biceps": "Biceps", "triceps": "Triceps",
	"forearms": "Forearms", "core": "Core", "quads": "Quads", "hamstrings": "Hamstrings", "glutes": "Glutes", "calves": "Calves"}
const BIG = ["chest", "back", "quads", "hamstrings", "glutes"]
const RECOVER_BIG = 3.0
const RECOVER_SMALL = 2.0
## Sets of a part that make a full day for it.
const FULL_SETS = 4.0
const OTHER = {
	"climb": {"forearms": 1.0, "back": 0.8, "biceps": 0.6},
	"run": {"calves": 0.8, "quads": 0.6, "hamstrings": 0.5},
	"ride": {"quads": 0.8, "glutes": 0.5, "calves": 0.3},
	"misc": {"calves": 0.5, "quads": 0.5, "core": 0.3},
}
## Words of a movement's "also works" that name a part.
const ALSO_WORDS = [["triceps", "triceps"], ["biceps", "biceps"], ["delt", "shoulders"], ["shoulder", "shoulders"],
	["forearm", "forearms"], ["grip", "forearms"], ["glute", "glutes"], ["hamstring", "hamstrings"], ["quad", "quads"],
	["legs", "quads"], ["core", "core"], ["abs", "core"], ["lat", "back"], ["upper back", "back"], ["trap", "back"],
	["back", "back"], ["chest", "chest"], ["calves", "calves"], ["calf", "calves"]]


static func days_to_recover(part: String) -> float:
	return RECOVER_BIG if BIG.has(part) else RECOVER_SMALL


## The parts a movement also works ("triceps, front delts" -> [triceps, shoulders]).
static func also_parts(lift_name: String) -> Array:
	var m = LiftNames.movement(str(LiftNames.split(lift_name).move))
	if m == null:
		return []
	var text = str(m.get("also", "")).to_lower()
	var out = []
	for pair in ALSO_WORDS:
		if text.contains(str(pair[0])) and not out.has(str(pair[1])):
			out.append(str(pair[1]))
	return out


## {part: {"heat": 0..1, "last": date or "", "days": days since (-1 never)}}
## for every part in PARTS, as of `today` (its sessions count).
static func heat(sessions: Array, today: String) -> Dictionary:
	var out = {}
	for p in PARTS:
		out[p] = {"heat": 0.0, "last": "", "days": -1}
	var from = Dates.add_days(today, -int(RECOVER_BIG) - 1)
	for s in sessions:
		var d = str(s.get("date", ""))
		if d > today or d < from:
			continue
		var days = Dates.days_between(d, today)
		var work = {}
		var disc = str(s.get("discipline", ""))
		if disc == "lift":
			for ex in s.get("exercises", []):
				var n = LiftTrend.real_sets(ex.get("sets", [])).size()
				if n == 0:
					continue
				var name = str(ex.get("name", ""))
				var part = Missions.part_of(name)
				if PARTS.has(part):
					work[part] = float(work.get(part, 0.0)) + n
				for a in also_parts(name):
					if a != part:
						work[a] = float(work.get(a, 0.0)) + n * 0.5
		elif OTHER.has(disc):
			for p in OTHER[disc]:
				work[p] = float(work.get(p, 0.0)) + float(OTHER[disc][p]) * FULL_SETS
		for p in work:
			var h = minf(1.0, float(work[p]) / FULL_SETS) * maxf(0.0, 1.0 - days / days_to_recover(p))
			var cur = out[p]
			if h > float(cur.heat):
				cur.heat = h
			if str(cur.last) == "" or d > str(cur.last):
				cur.last = d
				cur.days = days
	return out


## "Today", "Yesterday", "2 days ago": when a part was last worked.
static func when(days: int) -> String:
	if days == 0:
		return "today"
	if days == 1:
		return "yesterday"
	return "%d days ago" % days


## The parts still warm, hottest first: [{part, name, heat, days}].
static func warm(h: Dictionary, at_least: float = 0.05) -> Array:
	var out = []
	for p in PARTS:
		if float(h[p].heat) >= at_least:
			out.append({"part": p, "name": NAMES[p], "heat": float(h[p].heat), "days": int(h[p].days)})
	out.sort_custom(func(a, b): return float(a.heat) > float(b.heat))
	return out
