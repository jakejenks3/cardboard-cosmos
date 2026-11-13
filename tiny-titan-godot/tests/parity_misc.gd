extends SceneTree
## Parity test for the "second ring" of the engine: Quests, Diff, NextUp,
## Chatter, FunFacts, Fmt, Summary and LiftHistory.
##
##   godot --headless --path <project> --script res://tests/parity_misc.gd
##
## Replays the inputs recorded by tests/parity/gen_misc.ts (run against the
## TypeScript engine) through the GDScript port and compares the results with
## the recorded TypeScript outputs. Prints up to 15 mismatches per group, one
## "PARITY <group>: X/Y passed" line per group, and exits with 1 on any failure.
##
## Global classes must be registered first (once per checkout, and again after
## adding a class_name file): godot --headless --path <project> --import
##
## One caveat when reading a failure: Godot's JSON parser is not exact for
## numbers that need 16-17 significant digits ("118.99999999999999" is read as
## 119.0). The PlayerStates in the fixture carry such numbers (e1RMs, paces),
## so a text built from one of them can differ at a rounding knife-edge
## ("119 kg" for "119.0 kg") although the port is right; states derived inside
## Godot do not have the problem. No case of the committed fixture is affected.

const FIXTURE = "res://tests/parity/misc_cases.json"
const MAX_REPORTED = 15
const TOLERANCE = 1e-6

var _data: Dictionary = {}
var _failed_groups: int = 0


func _init() -> void:
	var text: String = FileAccess.get_file_as_string(FIXTURE)
	if text == "":
		print("PARITY misc: cannot read %s (run tests/parity/gen_misc.ts first)" % FIXTURE)
		quit(1)
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		print("PARITY misc: %s is not valid JSON" % FIXTURE)
		quit(1)
		return
	_data = TTUtil.normalize_json(parsed)

	_run_group("quests", _data.quests, _quests_case)
	_run_group("diff", _data.diff, _diff_case)
	_run_group("totals", _data.totals, _totals_case)
	_run_group("nextup", _data.nextup, _nextup_case)
	_run_group("chatter", _data.chatter, _chatter_case)
	_run_group("funfacts", _data.funfacts, _funfacts_case)
	_run_group("fmt", _data.fmt, _fmt_case)
	_run_group("summary", _data.summary, _summary_case)
	_run_group("lift", _data.lift, _lift_case)

	quit(1 if _failed_groups > 0 else 0)


## Runs every case of a group. `runner.call(case, index)` returns
## [label, expected, actual].
func _run_group(group: String, cases: Array, runner: Callable) -> void:
	var passed: int = 0
	var reported: int = 0
	for i in range(cases.size()):
		var res: Array = runner.call(cases[i], i)
		var mismatches: Array = []
		_compare(res[1], res[2], "", mismatches)
		if mismatches.is_empty():
			passed += 1
			continue
		for m in mismatches:
			if reported >= MAX_REPORTED:
				break
			print("  MISMATCH %s[%d] %s %s" % [group, i, res[0], m])
			reported += 1
	print("PARITY %s: %d/%d passed" % [group, passed, cases.size()])
	if passed != cases.size():
		_failed_groups += 1


# --- comparison -----------------------------------------------------------------

func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _show(v) -> String:
	var text: String = JSON.stringify(v)
	if text.length() > 160:
		text = text.substr(0, 160) + "…"
	return text


## Deep comparison of the recorded TS value (`want`) with the GDScript value
## (`got`). Numbers are equal within TOLERANCE whether int or float; a key that
## is missing on one side and null on the other counts as equal (JSON drops
## `undefined`); Arrays are compared by index; everything else must be equal.
func _compare(want, got, path: String, out: Array) -> void:
	if out.size() >= MAX_REPORTED:
		return
	if want == null and got == null:
		return
	if _is_num(want) and _is_num(got):
		if absf(float(want) - float(got)) > TOLERANCE:
			out.append("%s: expected %s, got %s" % [path, _show(want), _show(got)])
		return
	if typeof(want) == TYPE_DICTIONARY and typeof(got) == TYPE_DICTIONARY:
		for k in want:
			if got.has(k):
				_compare(want[k], got[k], "%s.%s" % [path, str(k)], out)
			elif want[k] != null:
				out.append("%s.%s: missing, expected %s" % [path, str(k), _show(want[k])])
		for k in got:
			if not want.has(k) and got[k] != null:
				out.append("%s.%s: unexpected %s" % [path, str(k), _show(got[k])])
		return
	if typeof(want) == TYPE_ARRAY and typeof(got) == TYPE_ARRAY:
		if want.size() != got.size():
			out.append("%s: expected %d elements, got %d" % [path, want.size(), got.size()])
		for i in range(mini(want.size(), got.size())):
			_compare(want[i], got[i], "%s[%d]" % [path, i], out)
		return
	if typeof(want) == TYPE_STRING and typeof(got) == TYPE_STRING:
		if want != got:
			out.append("%s: expected %s, got %s" % [path, _show(want), _show(got)])
		return
	if typeof(want) == TYPE_BOOL and typeof(got) == TYPE_BOOL:
		if want != got:
			out.append("%s: expected %s, got %s" % [path, _show(want), _show(got)])
		return
	out.append("%s: expected %s, got %s" % [path, _show(want), _show(got)])


# --- case runners -----------------------------------------------------------------

func _state(key: String) -> Dictionary:
	return _data.states[key]


func _log(key: String) -> Dictionary:
	return _data.logs[key]


func _quests_case(c: Dictionary, _i: int) -> Array:
	var lg: Dictionary = _log(c.log)
	var label: String = "%s %s" % [c.fn, c.key]
	if c.fn == "daily":
		return [label, c.out, Quests.daily_quests(c.key, _state(c.state), lg.sessions, lg.claims)]
	return [label, c.out, Quests.weekly_quests(c.key, _state(c.state), lg.sessions, lg.claims, c.settings)]


func _diff_case(c: Dictionary, _i: int) -> Array:
	var before: Dictionary = _state(c.before)
	var after: Dictionary = _state(c.after)
	var label: String = "%s %s -> %s" % [c.fn, c.before, c.after]
	match c.fn:
		"states":
			return [label, c.out, Diff.diff_states(before, after, c.session)]
		"bulk":
			return [label, c.out, Diff.diff_bulk(before, after, c.sessions)]
	return [label, c.out, Diff.diff_body(before, after, c.entry)]


func _totals_case(c: Dictionary, _i: int) -> Array:
	return ["totalDisciplineXp %s" % c.state, c.out, Diff.total_discipline_xp(_state(c.state))]


func _nextup_case(c: Dictionary, _i: int) -> Array:
	var s: Dictionary = _state(c.state)
	var want: Dictionary = {"next3": c.next3, "next4": c.next4, "next9": c.next9, "open": c.open}
	var got: Dictionary = {
		"next3": NextUp.next_goals(s, 3),
		"next4": NextUp.next_goals(s),
		"next9": NextUp.next_goals(s, 9),
		"open": NextUp.all_open_goals(s),
	}
	return [c.state, want, got]


func _chatter_case(c: Dictionary, _i: int) -> Array:
	var ctx: Dictionary = c.ctx.duplicate()
	ctx["s"] = _state(c.ctx.s)
	return ["%s %s" % [c.ctx.s, c.ctx.today], c.out, Chatter.pet_line(ctx)]


func _funfacts_case(c: Dictionary, _i: int) -> Array:
	return [c.state, c.out, FunFacts.fun_facts(_state(c.state))]


func _fmt_case(c: Dictionary, _i: int) -> Array:
	var a: Array = c.args
	var label: String = "%s%s" % [c.fn, _show(a)]
	var got = null
	match c.fn:
		"kgToUnit":
			got = Fmt.kg_to_unit(a[0], a[1])
		"unitToKg":
			got = Fmt.unit_to_kg(a[0], a[1])
		"mToUnit":
			got = Fmt.m_to_unit(a[0], a[1])
		"unitToM":
			got = Fmt.unit_to_m(a[0], a[1])
		"fmtNum":
			got = Fmt.fmt_num(a[0]) if a.size() == 1 else Fmt.fmt_num(a[0], a[1])
		"fmtWeight":
			got = Fmt.fmt_weight(a[0], a[1]) if a.size() == 2 else Fmt.fmt_weight(a[0], a[1], a[2])
		"fmtDistance":
			got = Fmt.fmt_distance(a[0], a[1]) if a.size() == 2 else Fmt.fmt_distance(a[0], a[1], a[2])
		"fmtElevation":
			got = Fmt.fmt_elevation(a[0], a[1])
		"fmtDuration":
			got = Fmt.fmt_duration(a[0])
		"fmtDurationShort":
			got = Fmt.fmt_duration_short(a[0])
		"fmtPace":
			got = Fmt.fmt_pace(a[0], a[1])
		"fmtSpeed":
			got = Fmt.fmt_speed(a[0], a[1])
		"fmtBigKg":
			got = Fmt.fmt_big_kg(a[0], a[1])
		"parseDurationInput":
			got = Fmt.parse_duration_input(a[0], a[1], a[2])
		"fmtGoalValue":
			got = Fmt.fmt_goal_value(a[0], a[1], a[2])
		"fmtProgress":
			got = Fmt.fmt_progress(a[0], a[1])
		"pct":
			got = Fmt.pct(a[0])
		_:
			got = "<parity_misc.gd does not know %s>" % c.fn
	return [label, c.out, got]


func _summary_case(c: Dictionary, _i: int) -> Array:
	return ["%s %s" % [c.session.id, c.settings.weightUnit], c.out, Summary.summarize_session(c.session, c.settings)]


func _lift_case(c: Dictionary, _i: int) -> Array:
	var got = null
	var label: String = c.fn
	match c.fn:
		"lastPerformances":
			label = "%s %s exclude=%s" % [c.fn, c.log, str(c.exclude)]
			got = LiftHistory.last_performances(_log(c.log).sessions, c.exclude)
		"exerciseSuggestions":
			label = "%s %s %s exclude=%s" % [c.fn, c.log, c.defaults, str(c.exclude)]
			var defaults: Array = Summary.DEFAULT_EXERCISES if c.defaults == "default" else ["Squat", "Overhead Press", "Deadlift"]
			got = LiftHistory.exercise_suggestions(_log(c.log).sessions, defaults, c.exclude)
		"recentWorkouts":
			label = "%s %s n=%s exclude=%s" % [c.fn, c.log, str(c.n), str(c.exclude)]
			if c.n == null:
				got = LiftHistory.recent_workouts(_log(c.log).sessions)
			else:
				got = LiftHistory.recent_workouts(_log(c.log).sessions, c.n, c.exclude)
		"compareSet":
			label = "%s %s" % [c.fn, _show([c.cur, c.prev, c.hadHistory, c.best])]
			got = LiftHistory.compare_set(c.cur, c.prev, c.hadHistory, c.best)
		"stepValue":
			label = "%s%s" % [c.fn, _show(c.args)]
			var a: Array = c.args
			got = LiftHistory.step_value(a[0], a[1], a[2]) if a.size() == 3 else LiftHistory.step_value(a[0], a[1], a[2], a[3])
		"volumeKg":
			label = "%s %s" % [c.fn, _show(c.sets)]
			got = LiftHistory.volume_kg(c.sets)
		"describeSets":
			label = "%s %s %s" % [c.fn, c.unit, _show(c.sets)]
			var unit: String = c.unit
			got = LiftHistory.describe_sets(c.sets, func(kg): return Fmt.fmt_weight(kg, unit))
		"topSetLabel":
			label = "%s %s %s" % [c.fn, c.unit, _show(c.sets)]
			var unit: String = c.unit
			got = LiftHistory.top_set_label(c.sets, func(kg): return Fmt.kg_to_unit(kg, unit))
		_:
			got = "<parity_misc.gd does not know %s>" % c.fn
	return [label, c.out, got]
