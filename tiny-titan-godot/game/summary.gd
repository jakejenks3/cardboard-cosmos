class_name Summary
extends RefCounted
## One-line session descriptions for lists (port of summary.ts).

## Exercise names offered before the player has a history of their own.
## Read-only: `.duplicate()` it before changing it.
const DEFAULT_EXERCISES = [
	"Squat",
	"Bench Press",
	"Deadlift",
	"Overhead Press",
	"Barbell Row",
	"Pull-up",
	"Chin-up",
	"Dip",
	"Push-up",
	"Front Squat",
	"Romanian Deadlift",
	"Hip Thrust",
	"Lunge",
	"Leg Press",
	"Lat Pulldown",
	"Dumbbell Press",
	"Incline Bench Press",
	"Bicep Curl",
	"Tricep Pushdown",
	"Lateral Raise",
	"Face Pull",
	"Plank",
	"Weighted Pull-up",
	"Clean",
	"Snatch",
	"Kettlebell Swing",
]


## One-line description of a session for lists, in the player's units:
## "3 exercises · 9 sets · 4,500 kg", "12 sends · max V4 · 2 flashes",
## "5.2 km · 27:30 · 5:17 /km · 80 m ↑".
static func summarize_session(s: Dictionary, settings: Dictionary) -> String:
	var st: Dictionary = Xp.session_stats(s)
	var parts: Array = []
	var dur = TTUtil.get_or(s, "durationSec", 0)
	if s.discipline == "lift":
		var n: int = 0
		for e in s.exercises:
			if not e.sets.is_empty():
				n += 1
		parts.append("%s exercise%s" % [str(n), "" if n == 1 else "s"])
		parts.append("%s sets" % TTUtil.num_str(st.sets))
		if st.volumeKg != 0:
			parts.append(Fmt.fmt_big_kg(st.volumeKg, settings.weightUnit))
		if st.bwReps != 0:
			parts.append("%s BW reps" % TTUtil.num_str(st.bwReps))
	elif s.discipline == "climb":
		parts.append("%s send%s" % [TTUtil.num_str(st.sends), "" if st.sends == 1 else "s"])
		if st.maxGradeSent != null:
			parts.append("max %s" % Xp.grade_label(st.maxGradeSent))
		if st.flashes != 0:
			parts.append("%s flash%s" % [TTUtil.num_str(st.flashes), "" if st.flashes == 1 else "es"])
		if st.attempts != 0:
			parts.append("%s attempts" % TTUtil.num_str(st.attempts))
	else:
		parts.append(Fmt.fmt_distance(st.distanceM, settings.distanceUnit))
		if dur != 0:
			parts.append(Fmt.fmt_duration(dur))
		if st.paceSecPerKm != null and s.discipline == "run":
			parts.append(Fmt.fmt_pace(st.paceSecPerKm, settings.distanceUnit))
		if st.speedKmh != null and s.discipline == "ride":
			parts.append(Fmt.fmt_speed(st.speedKmh, settings.distanceUnit))
		if st.elevationM != 0:
			parts.append("%s ↑" % Fmt.fmt_elevation(st.elevationM, settings.distanceUnit))
	if parts.is_empty() and dur != 0:
		parts.append(Fmt.fmt_duration(dur))
	return " · ".join(PackedStringArray(parts))
