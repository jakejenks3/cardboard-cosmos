class_name Plates
extends RefCounted
## Warm-ups and what to put on the bar, for a barbell lift's working weight.
## In the player's unit: a 45 lb bar with 45 / 35 / 25 / 10 / 5 / 2.5 lb plates,
## or a 20 kg bar with 25 / 20 / 15 / 10 / 5 / 2.5 / 1.25 kg plates. Pure logic
## (tests/plates_test.gd); the Today card and the phone logger show it.

const BAR = {"lb": 45.0, "kg": 20.0}
const PLATES = {"lb": [45.0, 35.0, 25.0, 10.0, 5.0, 2.5], "kg": [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25]}
## Warm-up steps: a share of the working weight and the reps.
const RAMP = [[0.4, 5], [0.6, 3], [0.8, 2]]


## Is the lift done with a barbell ("Squat - Barbell", "Bench Press", "Squat - Front")?
static func is_barbell(lift_name: String) -> bool:
	var sp = LiftNames.split(lift_name)
	var gear = LiftNames.gear_of(str(sp.variation))
	if not gear.is_empty():
		return gear.has("barbell") and not str(sp.variation).to_lower().contains("smith")
	var m = LiftNames.movement(str(sp.move))
	return m != null and str(m.usual) != "" and LiftNames.gear_of(str(m.usual)).has("barbell")


## The plates on each side for `weight` (in `unit`), heaviest first; [] when it
## is the bar alone or less; what cannot be made is left off.
static func per_side(weight: float, unit: String) -> Array:
	var bar = float(BAR.get(unit, 45.0))
	var left = (weight - bar) / 2.0
	var out = []
	for p in PLATES.get(unit, PLATES.lb):
		while left >= float(p) - 1e-6:
			out.append(float(p))
			left -= float(p)
	return out


## "185 = 45 + 25 each side", "45 = the bar", "" (not a barbell weight).
static func text(weight: float, unit: String) -> String:
	if weight <= 0.0:
		return ""
	var bar = float(BAR.get(unit, 45.0))
	if weight <= bar + 1e-6:
		return "%s = the bar" % TTUtil.num_str(weight)
	var ps = per_side(weight, unit)
	if ps.is_empty():
		return ""
	return "%s = %s each side" % [TTUtil.num_str(weight), " + ".join(PackedStringArray(ps.map(func(p): return TTUtil.num_str(p))))]


## The warm-up sets before a working weight: the empty bar for 10, then 40%,
## 60% and 80% of it, rounded to what the plates make; steps that land on the
## bar or on each other are dropped. [[weight, reps], ...]; [] for a light lift.
static func warmups(weight: float, unit: String) -> Array:
	var bar = float(BAR.get(unit, 45.0))
	if weight < bar * 2.0:
		return []
	var step = 5.0 if unit != "kg" else 2.5
	var out = [[bar, 10]]
	for r in RAMP:
		var w = maxf(bar, roundf(weight * float(r[0]) / step) * step)
		if w > float(out[out.size() - 1][0]) + 1e-6 and w < weight - 1e-6:
			out.append([w, int(r[1])])
	return out


## "45×10, 95×5, 135×3, 185×2" (the warm-ups in words).
static func warmup_text(weight: float, unit: String) -> String:
	return ", ".join(PackedStringArray(warmups(weight, unit).map(func(s): return "%s×%d" % [TTUtil.num_str(float(s[0])), int(s[1])])))
