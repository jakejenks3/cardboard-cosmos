class_name Goals
extends RefCounted
## A "goal" is any unlock condition that can also report how close you are
## (port of goals.ts). Achievements, gear and pets are all expressed as goals
## so the UI can show progress bars and surface whatever is nearest to
## completion.
##
## Goal: {"check": Callable(state) -> bool, "progress": Callable(state) -> Progress}
##       ("progress" is optional: test with `goal.has("progress")`)
## Progress: {"cur": number, "target": number, "unit": String}
## unit is one of "count", "kg", "m", "elev", "level", "grade", "weeks", "xp", "min", "ratio".


## Goal met when `getter.call(state) >= target`.
static func at_least(getter: Callable, target, unit: String = "count") -> Dictionary:
	return {
		"check": func(s): return getter.call(s) >= target,
		"progress": func(s): return {"cur": getter.call(s), "target": target, "unit": unit},
	}


## 0..1 completion. Grades start at VB (-1), so shift them to be positive.
static func progress_ratio(p: Dictionary) -> float:
	if p.unit == "grade":
		return max(0.0, min(1.0, (p.cur + 2) / float(p.target + 2)))
	if p.target <= 0:
		return 1.0
	return max(0.0, min(1.0, p.cur / float(p.target)))
