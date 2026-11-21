class_name Standards
extends RefCounted
## How strong a lift is for the player's bodyweight: Beginner to Elite, from
## general strength standards (for men; rough guides, not rules). A barbell lift
## is rated by its estimated one-rep max as a share of bodyweight; a bodyweight
## lift by the most reps in a set. Pure logic (tests/plates_test.gd checks it too).

const LEVELS = ["Beginner", "Novice", "Intermediate", "Advanced", "Elite"]
const COLORS = ["8a94b8", "3d9bff", "3ddc6d", "ffb21f", "ff4d6d"]
## One-rep max / bodyweight at each level (barbell).
const RATIO = {
	"bench press": [0.5, 0.75, 1.0, 1.5, 2.0],
	"squat": [0.75, 1.25, 1.5, 2.25, 2.75],
	"deadlift": [1.0, 1.5, 2.0, 2.5, 3.0],
	"overhead press": [0.35, 0.55, 0.75, 1.0, 1.25],
	"bent over row": [0.5, 0.75, 1.0, 1.5, 1.75],
	"romanian deadlift": [0.75, 1.0, 1.5, 2.0, 2.5],
	"hip thrust": [0.75, 1.25, 1.75, 2.5, 3.0],
}
## Reps in one set at each level (bodyweight).
const REPS = {"pull-up": [1, 5, 10, 15, 20], "chin-up": [1, 6, 12, 18, 24], "push-up": [5, 15, 30, 45, 60], "dip": [2, 8, 15, 25, 35]}


## The player's latest bodyweight in kg (the newest check-in with a weight), or 0.
static func bodyweight(body: Array) -> float:
	var best_date = ""
	var kg = 0.0
	for b in body:
		if float(b.get("weightKg", 0.0)) > 0.0 and str(b.get("date", "")) >= best_date:
			best_date = str(b.get("date", ""))
			kg = float(b.weightKg)
	return kg


## The level of a lift: {"level" (0-4), "name", "value" (ratio or reps), "kind"
## ("ratio" / "reps"), "next" (the value of the next level, or -1 at Elite),
## "progress" (0-1 towards it)} or null when the lift has no standard (or the
## bodyweight is unknown for a barbell lift).
static func rate(lift_name: String, e1rm_kg: float, best_reps: int, bodyweight_kg: float):
	var mv = str(LiftNames.split(lift_name).move).to_lower()
	var steps = []
	var value = 0.0
	var kind = ""
	if RATIO.has(mv) and Plates.is_barbell(lift_name):
		if bodyweight_kg <= 0.0 or e1rm_kg <= 0.0:
			return null
		steps = RATIO[mv]
		value = e1rm_kg / bodyweight_kg
		kind = "ratio"
	elif REPS.has(mv):
		if best_reps <= 0:
			return null
		steps = REPS[mv]
		value = float(best_reps)
		kind = "reps"
	else:
		return null
	var level = -1
	for i in range(steps.size()):
		if value >= float(steps[i]) - 1e-9:
			level = i
	level = maxi(0, level)
	var nxt = float(steps[level + 1]) if level + 1 < steps.size() else -1.0
	var lo = float(steps[level]) if value >= float(steps[0]) else 0.0
	var progress = 1.0 if nxt < 0.0 else clampf((value - lo) / maxf(nxt - lo, 1e-9), 0.0, 1.0)
	return {"level": level, "name": LEVELS[level], "value": value, "kind": kind, "next": nxt, "progress": progress}
