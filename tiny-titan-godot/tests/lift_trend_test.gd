extends SceneTree
## Unit test for game/lift_trend.gd (one lift over time) and game/pt.gd
## (physical therapy lifts and keeping up with them).
##   godot --headless --path . --script res://tests/lift_trend_test.gd
## Prints LIFTTREND: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-18"  # a Wednesday; its week starts Monday 2026-11-16

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a, b, eps: float = 0.01) -> bool:
	return absf(float(a) - float(b)) <= eps


func sets(pairs: Array) -> Array:
	var out = []
	for p in pairs:
		out.append({"reps": int(p[0]), "weightKg": float(p[1])})
	return out


## A history row as LiftLibrary.stats makes them.
func h(date: String, pairs: Array) -> Dictionary:
	return {"date": date, "id": "s" + date, "sets": sets(pairs)}


## A lift session with one exercise.
func lift(date: String, lift_name: String, pairs: Array) -> Dictionary:
	_n += 1
	return {"id": "s%d" % _n, "discipline": "lift", "date": date, "createdAt": 1000 + _n, "exercises": [{"name": lift_name, "sets": sets(pairs)}]}


func row_of(rows: Array, lift_name: String) -> Dictionary:
	for r in rows:
		if r.name == lift_name:
			return r
	return {}


func _init() -> void:
	# --- one session in numbers ---------------------------------------------------------
	var d = LiftTrend.day(sets([[20, 50], [24, 50], [24, 50]]))
	ok(d.sets == 3 and d.reps == 68 and near(d.topKg, 50.0) and d.topReps == 24 and d.bestReps == 24 and near(d.volumeKg, 3400.0), "a day: sets, reps, the heaviest set, volume", d)
	var d2 = LiftTrend.day(sets([[5, 60], [3, 80], [8, 40], [0, 100]]))
	ok(near(d2.topKg, 80.0) and d2.topReps == 3 and d2.bestReps == 8 and d2.sets == 3 and near(d2.e1rm, 80.0 * (1.0 + 3 / 30.0)), "the heaviest set is not the longest; a set without reps does not count", d2)
	var bw = LiftTrend.day(sets([[8, 0], [10, 0]]))
	ok(near(bw.topKg, 0.0) and bw.topReps == 10 and near(bw.volumeKg, 0.0) and near(bw.e1rm, 0.0), "bodyweight: the top set is the one with most reps", bw)

	# --- the history, newest first, as LiftLibrary gives it --------------------------------
	var hist = [h("2026-11-17", [[5, 62.5], [5, 62.5]]), h("2026-11-10", [[5, 60], [5, 60], [5, 60]]), h("2026-11-10", [[8, 40]]), h("2026-11-03", [[5, 55]])]
	var days = LiftTrend.by_day(hist)
	ok(days.size() == 3 and days[0].date == "2026-11-03" and days[1].reps == 23 and near(days[1].topKg, 60.0) and days[2].date == "2026-11-17", "one row per day, oldest first; two sessions on a day are one day", days)
	var w = LiftTrend.series(hist, "weight")
	ok(w.size() == 3 and near(w[0].y, 55.0) and near(w[2].y, 62.5) and w[1].x == "2026-11-10", "weight: the heaviest set of each day", w)
	ok(near(LiftTrend.series(hist, "reps")[1].y, 23.0) and near(LiftTrend.series(hist, "volume")[2].y, 625.0) and LiftTrend.series(hist, "e1rm").size() == 3, "reps and volume of each day")
	var ups = [h("2026-11-17", [[12, 0]]), h("2026-11-12", [[10, 0], [8, 0]])]
	ok(LiftTrend.series(ups, "weight").is_empty() and LiftTrend.series(ups, "volume").is_empty() and LiftTrend.series(ups, "reps").size() == 2 and not LiftTrend.weighted(ups) and LiftTrend.weighted(hist), "a bodyweight lift has reps to chart, no weight")
	var ch = LiftTrend.change(w)
	ok(near(ch.delta, 7.5) and ch.days == 14 and ch.n == 3 and LiftTrend.change([w[0]]).is_empty(), "change: first against last", ch)

	# --- how often -----------------------------------------------------------------------
	var often = [h("2026-11-18", [[10, 0]]), h("2026-11-16", [[10, 0]]), h("2026-11-16", [[10, 0]]), h("2026-11-13", [[10, 0]]), h("2026-11-09", [[10, 0]]), h("2026-10-28", [[10, 0]])]
	var pw = LiftTrend.per_week(often, TODAY, 8)
	ok(pw.size() == 8 and pw[7].week == "2026-11-16" and pw[7].n == 2 and pw[6].n == 2 and pw[5].n == 0 and pw[4].n == 1 and pw[0].n == 0, "days done per Monday-week, this week last; a day counts once", pw)
	ok(near(LiftTrend.weekly_rate(pw), 5 / 4.0) and near(LiftTrend.weekly_rate(LiftTrend.per_week([], TODAY, 8)), 0.0), "the rate counts from the first week it was done", LiftTrend.weekly_rate(pw))
	ok(LiftTrend.days_done(often).size() == 5 and LiftTrend.days_done(often).has("2026-11-16"), "the days it was done")

	# --- this session against the one before ---------------------------------------------
	var before = [h("2026-11-10", [[5, 60], [5, 60], [5, 60]]), h("2026-11-03", [[5, 65]])]
	var c_first = LiftTrend.compare(sets([[5, 60]]), [])
	ok(c_first.kind == "first" and not c_first.pr, "nothing before: first time", c_first)
	var c_up = LiftTrend.compare(sets([[5, 62.5], [5, 62.5]]), before)
	ok(c_up.kind == "up" and near(c_up.kg, 2.5) and c_up.reps == 0 and not c_up.pr and c_up.last == "2026-11-10", "heavier than last time, but not than ever", c_up)
	var c_pr = LiftTrend.compare(sets([[3, 70]]), before)
	ok(c_pr.kind == "up" and near(c_pr.kg, 10.0) and c_pr.pr, "heavier than ever: a record", c_pr)
	var c_reps = LiftTrend.compare(sets([[6, 60], [6, 60], [5, 60]]), before)
	ok(c_reps.kind == "up" and near(c_reps.kg, 0.0) and c_reps.reps == 2, "the same weight for more reps", c_reps)
	var c_down = LiftTrend.compare(sets([[5, 55]]), before)
	ok(c_down.kind == "down" and near(c_down.kg, -5.0), "lighter than last time", c_down)
	ok(LiftTrend.compare(sets([[5, 60], [5, 60], [5, 60]]), before).kind == "same" and LiftTrend.compare(sets([[0, 60]]), before).kind == "none", "the same again; no real set is nothing to compare")
	var bw_before = [h("2026-11-12", [[10, 0], [8, 0]])]
	var c_bw = LiftTrend.compare(sets([[12, 0]]), bw_before)
	ok(c_bw.kind == "down" and c_bw.reps == -6 and c_bw.pr and not LiftTrend.compare(sets([[9, 0], [9, 0]]), bw_before).pr and LiftTrend.compare(sets([[9, 0], [9, 0]]), bw_before).kind == "same", "bodyweight: compared by all reps; a record is more reps in one set than ever", c_bw)

	# --- holds (a stretch: seconds, not weight) -------------------------------------------
	var hold_sets = [{"reps": 1, "weightKg": 0.0, "holdSec": 30}, {"reps": 1, "weightKg": 0.0, "holdSec": 30}, {"reps": 1, "weightKg": 0.0, "holdSec": 30}]
	var hold_day = LiftTrend.day(hold_sets)
	ok(hold_day.holdSec == 30 and hold_day.holdTotal == 90 and hold_day.reps == 3 and near(hold_day.topKg, 0.0), "a day of holds: the longest, and the seconds in all", hold_day)
	ok(LiftTrend.hold_text(hold_sets) == "3 × 30 s hold" and LiftTrend.hold_text([{"reps": 3, "weightKg": 0.0, "holdSec": 30}]) == "3 × 30 s hold" and LiftTrend.hold_text([{"reps": 1, "weightKg": 0.0, "holdSec": 60}]) == "60 s hold", "holds in words", LiftTrend.hold_text(hold_sets))
	ok(LiftTrend.hold_text([{"reps": 1, "weightKg": 0.0, "holdSec": 30}, {"reps": 1, "weightKg": 0.0, "holdSec": 45}]) == "30 s, 45 s hold" and LiftTrend.hold_text(sets([[5, 60]])) == "" and LiftTrend.day(sets([[5, 60]])).holdSec == 0, "different lengths are listed; a plain set is no hold")
	var fmt_kg = func(kg): return "%s kg" % TTUtil.num_str(kg)
	ok(LiftHistory.describe_sets(hold_sets, fmt_kg) == "3 × 30 s hold" and LiftHistory.describe_sets(sets([[5, 60], [5, 60]]), fmt_kg) == "2×5 @ 60 kg", "the usual sets text says a hold as a hold", LiftHistory.describe_sets(hold_sets, fmt_kg))
	var hold_hist = [{"date": "2026-11-17", "id": "h2", "sets": [{"reps": 2, "weightKg": 0.0, "holdSec": 40}]}, {"date": "2026-11-10", "id": "h1", "sets": hold_sets}]
	ok(LiftTrend.held(hold_hist) and not LiftTrend.held(hist) and LiftTrend.series(hold_hist, "hold").size() == 2 and near(LiftTrend.series(hold_hist, "hold")[1].y, 40.0) and LiftTrend.series(hist, "hold").is_empty(), "the longest hold of each day can be charted")
	var c_hold = LiftTrend.compare([{"reps": 3, "weightKg": 0.0, "holdSec": 45}], hold_hist)
	ok(c_hold.kind == "up" and c_hold.sec == 5 and c_hold.pr and near(c_hold.kg, 0.0), "a longer hold than last time, and than ever", c_hold)
	var c_hold2 = LiftTrend.compare([{"reps": 3, "weightKg": 0.0, "holdSec": 40}], hold_hist)
	ok(c_hold2.kind == "up" and c_hold2.sec == 0 and c_hold2.reps == 1 and not c_hold2.pr, "as long, one more of them", c_hold2)
	var held_log = [{"id": "s1", "discipline": "lift", "date": "2026-11-17", "createdAt": 1, "exercises": [{"name": "Calf Stretch", "sets": hold_sets}]}]
	var kept_sets = LiftLibrary.stats(held_log).get("calf stretch", {"history": [{"sets": []}]}).history[0].sets
	ok(kept_sets.size() == 3 and int(kept_sets[0].get("holdSec", 0)) == 30, "the lift library keeps a hold's seconds", kept_sets)

	# --- the PT tag ----------------------------------------------------------------------
	ok(Pt.untag("(PT) wrist curls") == {"pt": true, "name": "wrist curls"} and Pt.untag("(pt)neck 4 way - 3x20@10") == {"pt": true, "name": "neck 4 way - 3x20@10"} and Pt.untag("[PT] bridges") == {"pt": true, "name": "bridges"}, "the tag at the start, any case", [Pt.untag("(PT) wrist curls"), Pt.untag("(pt)neck 4 way - 3x20@10")])
	ok(Pt.untag("PT: band pull apart") == {"pt": true, "name": "band pull apart"} and Pt.untag("(PT) - clamshells") == {"pt": true, "name": "clamshells"} and Pt.untag("calf raise (PT) 3x15") == {"pt": true, "name": "calf raise 3x15"}, "'pt:', a dash after it, and the tag after the name", [Pt.untag("PT: band pull apart"), Pt.untag("calf raise (PT) 3x15")])
	ok(Pt.untag("3 pt row") == {"pt": false, "name": "3 pt row"} and Pt.untag("pt cruiser carry") == {"pt": false, "name": "pt cruiser carry"} and Pt.untag("bench press") == {"pt": false, "name": "bench press"}, "the bare letters are not a tag")

	# --- keeping up, in SETS (2026-11-25): a day counts up to Pt.SETS_A_DAY of its sets ---------
	var three = [[20, 2], [20, 2], [20, 2]]
	var log = [
		lift("2026-11-18", "Neck 4 Way", three), lift("2026-11-16", "Neck 4 Way", [[20, 2]]), lift("2026-11-16", "neck 4 way", [[20, 2], [20, 2]]),
		lift("2026-11-13", "Neck 4 Way", three), lift("2026-11-11", "Neck 4 Way", three), lift("2026-11-09", "Neck 4 Way", three),
		lift("2026-11-06", "Neck 4 Way", three), lift("2026-11-04", "Neck 4 Way", three), lift("2026-11-02", "Neck 4 Way", three),
		lift("2026-10-28", "Neck 4 Way", three),
		lift("2026-11-17", "Clamshell", [[15, 0]]),
		lift("2026-11-10", "Calf Raise", [[15, 0]]), lift("2026-11-17", "Squat", [[5, 100]]),
	]
	var marks = {"neck 4 way": {"name": "Neck 4 Way", "perWeek": 3}, "clamshell": {"name": "Clamshell", "perWeek": 7},
		"calf raise": {"name": "Calf Raise", "perWeek": 2}, "wall slide": {"name": "Wall Slide"}}
	var rows = Pt.status(log, marks, TODAY)
	ok(Pt.SETS_A_DAY == 3 and rows.size() == 4 and Pt.status(log, {}, TODAY).is_empty(), "one row per marked lift, none without marks", rows.size())
	var neck = row_of(rows, "Neck 4 Way")
	ok(not neck.is_empty() and neck.thisWeek == 2 and neck.sets == 6 and neck.setsGoal == 9 and neck.left == 3 and neck.state == "on" and neck.week == [true, false, true, false, false, false, false] and neck.daysSince == 0 and neck.last == "2026-11-18", "this week: Monday and today, 3 sets each, 6 of 9 sets, 3 to go, on track", [neck.get("sets"), neck.get("left"), neck.get("week")])
	ok(not neck.is_empty() and int(neck.daySets["2026-11-16"]) == 3 and near(neck.weekShare[0], 1.0) and near(neck.weekShare[1], 0.0) and near(neck.weekShare[2], 1.0) and neck.weekShare.size() == 7, "two sessions on a day add their sets up (1 + 2 = a full day)", [neck.get("daySets"), neck.get("weekShare")])
	ok(not neck.is_empty() and neck.weeks.size() == 8 and neck.weeks[6].n == 9 and neck.weeks[6].hit and neck.weeks[5].n == 9 and neck.weeks[4].n == 3 and not neck.weeks[4].hit and neck.weeks[7].n == 6 and neck.run == 2, "the weeks before, in sets: two on target in a row, then one that missed", [neck.get("weeks"), neck.get("run")])
	var clam = row_of(rows, "Clamshell")
	ok(not clam.is_empty() and clam.perWeek == 7 and clam.thisWeek == 1 and clam.sets == 1 and clam.setsGoal == 21 and clam.state == "behind" and clam.left == 20, "seven days asked (21 sets), one set by Wednesday: 20 to go cannot fit in 15, behind", [clam.get("state"), clam.get("left")])
	var heel = row_of(rows, "Calf Raise")
	ok(not heel.is_empty() and heel.key == "calf raise" and heel.count == 1 and heel.thisWeek == 0 and heel.sets == 0 and heel.left == 6 and heel.daysSince == 8 and heel.state == "on", "a mark is on one lift, by its name", heel.get("name"))
	var wall = row_of(rows, "Wall Slide")
	ok(not wall.is_empty() and wall.count == 0 and wall.daysSince == -1 and wall.last == "" and wall.perWeek == Pt.DEFAULT_PER_WEEK and wall.setsGoal == 3 * Pt.DEFAULT_PER_WEEK and wall.state == "on", "marked but never done still has a row, with the usual goal", wall.get("state"))
	ok(rows[0].name == "Clamshell" and row_of(rows, "Squat").is_empty(), "the one that is behind comes first; a lift that is not marked is not listed", rows[0].name)
	ok(rows.map(func(r): return str(r.name)) == ["Clamshell", "Wall Slide", "Calf Raise", "Neck 4 Way"], "then the most sets still to do first", rows.map(func(r): return str(r.name)))
	var done_rows = Pt.status(log + [lift("2026-11-17", "Neck 4 Way", three)], marks, TODAY)
	var neck_done = row_of(done_rows, "Neck 4 Way")
	ok(neck_done.state == "done" and neck_done.left == 0 and neck_done.sets == 9 and neck_done.run == 3 and done_rows[done_rows.size() - 1].name == "Neck 4 Way", "three full days in: done for the week, the run counts it, and it sinks to the end", [neck_done.get("state"), neck_done.get("run")])
	var late = row_of(Pt.status(log, marks, "2026-11-22"), "Neck 4 Way")
	ok(late.state == "on" and late.left == 3 and row_of(Pt.status(log, marks, "2026-11-22"), "Calf Raise").state == "behind", "on Sunday one more day's 3 sets can still be made, 6 cannot", late.get("state"))
	var sum = Pt.summary(rows)
	ok(sum.lifts == 4 and sum.done == 6 + 1 and sum.goal == 9 + 21 + 6 + 9 and sum.behind == 1 and sum.left == 38, "the week in all, in sets", sum)
	ok(Pt.is_pt(marks, "Neck 4 way") and not Pt.is_pt(marks, "Squat") and Pt.per_week(marks, "clamshell") == 7 and Pt.per_week(marks, "Squat") == 3 and Pt.per_week({"x": {"perWeek": 40}}, "x") == 7, "is it PT, and for how many days a week")
	# One set is a third of a day; three a full day; five on one day still count three.
	var bmark = {Pt.key("Band Pull Apart"): {"name": "Band Pull Apart", "perWeek": 3}}
	var one_set = row_of(Pt.status([lift("2026-11-16", "Band Pull Apart", [[15, 0]])], bmark, TODAY), "Band Pull Apart")
	ok(one_set.sets == 1 and one_set.thisWeek == 1 and near(one_set.weekShare[0], 1.0 / 3.0) and one_set.left == 8 and int(one_set.daySets["2026-11-16"]) == 1, "one set counts a third of a day", [one_set.get("sets"), one_set.get("weekShare")])
	var full = row_of(Pt.status([lift("2026-11-16", "Band Pull Apart", [[15, 0], [15, 0], [15, 0]])], bmark, TODAY), "Band Pull Apart")
	ok(full.sets == 3 and near(full.weekShare[0], 1.0) and full.left == 6, "three sets: a full day", [full.get("sets"), full.get("weekShare")])
	var five = row_of(Pt.status([lift("2026-11-16", "Band Pull Apart", [[15, 0], [15, 0], [15, 0], [15, 0], [15, 0]])], bmark, TODAY), "Band Pull Apart")
	ok(five.sets == 3 and int(five.daySets["2026-11-16"]) == 5 and near(five.weekShare[0], 1.0) and five.left == 6, "five sets on one day count three for the week", [five.get("sets"), five.get("daySets")])
	var singles = [lift("2026-11-16", "Band Pull Apart", [[15, 0]]), lift("2026-11-17", "Band Pull Apart", [[15, 0]]), lift("2026-11-18", "Band Pull Apart", [[15, 0]])]
	var thin = row_of(Pt.status(singles, bmark, TODAY), "Band Pull Apart")
	ok(thin.thisWeek == 3 and thin.sets == 3 and thin.state != "done" and thin.left == 6, "three days of one set each are a third of a 3-day week, not all of it", [thin.get("sets"), thin.get("state")])
	ok(row_of(Pt.status(singles, {Pt.key("Band Pull Apart"): {"name": "Band Pull Apart", "perWeek": 1}}, TODAY), "Band Pull Apart").state == "done", "and a 1-day goal (3 sets) is met by them")
	ok(row_of(Pt.status([lift("2026-11-16", "Band Pull Apart", [[0, 0], [0, 5]])], bmark, TODAY), "Band Pull Apart").sets == 0, "a set without reps does not count")
	var sat_mark = {Pt.key("Band Pull Apart"): {"name": "Band Pull Apart", "perWeek": 2}}
	var sat_row = row_of(Pt.status([lift("2026-11-21", "Band Pull Apart", [[15, 0]])], sat_mark, "2026-11-21"), "Band Pull Apart")
	ok(sat_row.left == 5 and sat_row.state == "on", "Saturday, one set done: 5 to go fit in today's 2 and Sunday's 3", [sat_row.get("left"), sat_row.get("state")])
	var sat_row2 = row_of(Pt.status([lift("2026-11-20", "Band Pull Apart", [[15, 0]])], sat_mark, "2026-11-21"), "Band Pull Apart")
	ok(sat_row2.left == 5 and sat_row2.state == "on" and row_of(Pt.status([], sat_mark, "2026-11-21"), "Band Pull Apart").state == "on" and row_of(Pt.status([], {Pt.key("Band Pull Apart"): {"name": "Band Pull Apart", "perWeek": 3}}, "2026-11-21"), "Band Pull Apart").state == "behind", "Saturday with nothing today: 6 fit, 9 do not", sat_row2.get("state"))
	var own_row = Pt.row_of(singles, bmark, "Band Pull Apart", TODAY)
	ok(own_row != null and int(own_row.sets) == 3 and int(own_row.setsGoal) == 9 and own_row.weeks.size() == 8 and int(own_row.weeks[7].n) == 3 and not own_row.weeks[7].hit
		and Pt.row_of(singles, bmark, "Bench Press - Barbell", TODAY) == null and Pt.row_of(singles, bmark, "Band Pull Apart", TODAY, 4).weeks.size() == 4,
		"row_of: one lift's row (a lift page's PT card and Logbook bars), null when not PT", own_row.get("weeks") if own_row != null else null)
	_views()
	# --- the ghost: you about four weeks earlier -------------------------------------------------------
	var gh = [{"date": "2026-11-20", "sets": [{"reps": 5, "weightKg": 100.0}]}, {"date": "2026-11-06", "sets": [{"reps": 5, "weightKg": 97.5}]},
		{"date": "2026-10-23", "sets": [{"reps": 5, "weightKg": 90.0}]}, {"date": "2026-10-01", "sets": [{"reps": 5, "weightKg": 80.0}]}]
	var g1 = LiftTrend.ghost(gh, gh[0])
	ok(g1 != null and str(g1.ghost.date) == "2026-10-23" and int(g1.days) == 28 and g1.won and absf(float(g1.pct) - 11.11) < 0.1, "the ghost is the session four weeks back; you beat it by 11%", g1)
	var g2 = LiftTrend.ghost([{"date": "2026-11-20", "sets": [{"reps": 5, "weightKg": 85.0}]}] + gh.slice(1), {"date": "2026-11-20", "sets": [{"reps": 5, "weightKg": 85.0}]})
	ok(g2 != null and not g2.won and not g2.tie and float(g2.pct) < 0.0, "a lighter day: the ghost is ahead", g2)
	ok(LiftTrend.ghost(gh.slice(0, 2), gh[0]) == null and LiftTrend.ghost([gh[0], gh[3]], gh[0]) == null, "no session three to six weeks back: no ghost")
	var gh_hold = LiftTrend.ghost([{"date": "2026-11-20", "sets": [{"reps": 1, "weightKg": 0.0, "holdSec": 40}]}, {"date": "2026-10-23", "sets": [{"reps": 1, "weightKg": 0.0, "holdSec": 40}]}], {"date": "2026-11-20", "sets": [{"reps": 1, "weightKg": 0.0, "holdSec": 40}]})
	ok(gh_hold != null and gh_hold.tie and is_equal_approx(float(gh_hold.you), 40.0), "holds duel on seconds; the same is a dead heat", gh_hold)
	# --- stuck: three sessions without a new best -----------------------------------------------------
	var mk_day = func(d: String, kg: float, reps: int): return {"date": d, "sets": [{"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}]}
	var flat = [mk_day.call("2026-11-20", 100.0, 5), mk_day.call("2026-11-17", 100.0, 5), mk_day.call("2026-11-13", 97.5, 5),
		mk_day.call("2026-11-10", 100.0, 5), mk_day.call("2026-11-06", 95.0, 5), mk_day.call("2026-11-03", 90.0, 5)]
	var stuck = LiftTrend.plateau(flat)
	ok(stuck != null and stuck.stuck and str(stuck.best_date) == "2026-11-10" and str(stuck.since) == "2026-11-13", "three sessions without beating the best before them: stuck", stuck)
	ok(LiftTrend.plateau([mk_day.call("2026-11-24", 102.5, 5)] + flat) == null, "a new best: moving again")
	ok(LiftTrend.plateau(flat.slice(0, 4)) == null, "too few sessions to tell")
	var fixes = LiftTrend.plateau_fixes(flat, "Bench Press - Barbell", "kg")
	ok(fixes.size() == 3 and str(fixes[0].text).contains("90 kg") and str(fixes[1].text).contains("dumbbells") and str(fixes[2].text).contains("8 to 10"), "ways out: a reset at 90%, dumbbells for a while, more reps", fixes)
	print("LIFTTREND: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


## The lift page's three views: set-by-set compare, records, next time, the
## chart's record points, the calendar and the rep ladder.
func _views() -> void:
	# --- set by set ---------------------------------------------------------------------
	var p = LiftTrend.pairs(sets([[10, 60], [10, 60], [8, 60], [6, 65]]), sets([[10, 60], [9, 60], [8, 62.5]]))
	ok(p.size() == 4 and p[0].kind == "same" and p[1].kind == "up" and p[1].dreps == 1 and p[2].kind == "down" and near(p[2].dkg, -2.5) and p[3].kind == "added" and p[3].prev == null, "set by set: same, one more rep, lighter, a set added", p)
	var dropped = LiftTrend.pairs(sets([[5, 100]]), sets([[5, 100], [5, 100]]))
	ok(dropped.size() == 2 and dropped[1].kind == "dropped" and dropped[1].cur == null, "a set not done this time is 'dropped'")
	var holds = LiftTrend.pairs([{"reps": 1, "weightKg": 0.0, "holdSec": 45}], [{"reps": 1, "weightKg": 0.0, "holdSec": 30}])
	ok(holds[0].kind == "up" and holds[0].dsec == 15, "holds compare by their seconds", holds)
	ok(LiftTrend.pairs(sets([[0, 60], [5, 60]]), sets([[5, 60]])).size() == 1, "sets without reps are not counted")

	# --- records --------------------------------------------------------------------------
	var before = [h("2026-11-10", [[5, 100], [5, 100]]), h("2026-11-03", [[8, 90], [8, 90], [8, 90]])]
	var heavier = LiftTrend.records(sets([[3, 105]]), before)
	ok(heavier.size() >= 1 and heavier[0].id == "top" and near(heavier[0].value, 105.0), "a heavier set than ever is the first record", heavier)
	var more = LiftTrend.records(sets([[7, 100]]), before)
	ok(more.size() >= 1 and more[0].id == "reps_at" and int(more[0].value) == 7 and more.any(func(r): return r.id == "strength"), "more reps at the best weight, and a better estimated strength", more)
	var vol = LiftTrend.records(sets([[8, 90], [8, 90], [8, 90], [8, 90]]), before)
	ok(vol.size() == 1 and vol[0].id == "volume", "a fourth set of eight: only the volume is new", vol)
	ok(LiftTrend.records(sets([[5, 100]]), before).is_empty() and LiftTrend.records(sets([[5, 100]]), []).is_empty(), "nothing beaten, or nothing before: no records")
	var bw = LiftTrend.records(sets([[12, 0], [10, 0]]), [h("2026-11-10", [[11, 0], [11, 0]])])
	ok(bw.size() == 1 and bw[0].id == "reps" and int(bw[0].value) == 12, "without weight: most reps in a set (not in a day: 22 = 22)", bw)
	var hold_rec = LiftTrend.records([{"reps": 3, "weightKg": 0.0, "holdSec": 40}], [{"date": "2026-11-10", "id": "x", "sets": [{"reps": 3, "weightKg": 0.0, "holdSec": 30}]}])
	ok(hold_rec.size() == 1 and hold_rec[0].id == "hold" and int(hold_rec[0].value) == 40, "a hold: longest hold", hold_rec)

	# --- next time ------------------------------------------------------------------------
	var all_in = LiftTrend.next_target(sets([[10, 60], [10, 60], [10, 60]]), 2.5)
	ok(all_in.kind == "weight" and near(all_in.addKg, 2.5) and all_in.sets.all(func(s): return near(s.weightKg, 62.5) and int(s.reps) == 10), "every set at 10: add weight, same reps", all_in)
	var short = LiftTrend.next_target(sets([[10, 60], [10, 60], [8, 60]]), 2.5)
	ok(short.kind == "reps" and short.set == 3 and short.reps == 9 and int(short.sets[2].reps) == 9 and near(short.sets[2].weightKg, 60.0), "one set short: one more rep on it", short)
	var warm = LiftTrend.next_target(sets([[10, 40], [5, 80], [5, 80]]), 2.5)
	ok(warm.kind == "weight" and near(warm.sets[0].weightKg, 40.0) and near(warm.sets[1].weightKg, 82.5), "a warm-up set stays as it was", warm)
	var body = LiftTrend.next_target(sets([[12, 0], [10, 0]]), 2.5)
	ok(body.kind == "reps" and body.set == 2 and body.reps == 11, "bodyweight: one more rep on the weakest set", body)
	var hold_next = LiftTrend.next_target([{"reps": 3, "weightKg": 0.0, "holdSec": 30}], 2.5)
	ok(hold_next.kind == "hold" and int(hold_next.sets[0].holdSec) == 35, "a hold: five seconds longer", hold_next)
	ok(LiftTrend.next_target([], 2.5).kind == "none", "nothing done: nothing to aim for")
	var light = LiftTrend.next_target(sets([[24, 8], [24, 8], [26, 8]]), 2.5)
	ok(light.kind == "weight" and bool(light.get("heavier", false)) and light.sets.all(func(one): return int(one.reps) == LiftTrend.DOWN_TO and is_equal_approx(float(one.weightKg), 10.5)), "every set past 15 reps: a step heavier and down to 10 reps", light)
	var nearly = LiftTrend.next_target(sets([[16, 8], [14, 8]]), 2.5)
	ok(nearly.kind == "reps" and not nearly.has("heavier") and int(nearly.reps) == 15, "one set still under 15: one more rep there first", nearly)
	ok(not LiftTrend.next_target(sets([[25, 0], [25, 0]]), 2.5).has("heavier"), "bodyweight has no weight to add: reps go on")

	# --- the chart, the calendar, the ladder ---------------------------------------------------
	var pts = [{"x": "2026-10-01", "y": 50.0}, {"x": "2026-10-08", "y": 55.0}, {"x": "2026-10-15", "y": 52.0}, {"x": "2026-10-22", "y": 55.0}, {"x": "2026-10-29", "y": 60.0}]
	ok(LiftTrend.record_points(pts) == [1, 4], "record points: only a new best, never a tie, never the first", LiftTrend.record_points(pts))
	ok(LiftTrend.since(pts, "2026-10-29", 14).size() == 3 and LiftTrend.since(pts, "2026-10-29", 0).size() == 5, "a range keeps the last days only")
	var hist = [h("2026-11-18", [[5, 100], [5, 100]]), h("2026-11-16", [[5, 95]]), h("2026-11-02", [[5, 100], [5, 100], [5, 100], [5, 100]])]
	var cal = LiftTrend.calendar(hist, TODAY, 4)
	var by = {}
	for c in cal:
		by[c.date] = c
	ok(cal.size() == 28 and cal[0].date == "2026-10-26" and cal[27].date == "2026-11-22", "four weeks of days, Monday first, to the end of this week", [cal[0].date, cal[27].date])
	ok(by["2026-11-02"].level == 4 and by["2026-11-18"].level == 2 and by["2026-11-16"].level == 1 and by["2026-11-10"].level == 0, "the biggest day is level 4, the others by their size", [by["2026-11-18"].level, by["2026-11-16"].level])
	ok(not by["2026-11-02"].pr and not by["2026-11-18"].pr and by["2026-11-22"].future and not by["2026-11-18"].future, "no new best in this history (100 is tied, never beaten); days after today are marked")
	var lad = LiftTrend.rep_ladder([h("2026-11-18", [[3, 110], [5, 100]]), h("2026-11-10", [[8, 90], [1, 120]])])
	ok(lad.size() == 4 and lad[0].from == 1 and lad[0].to == 1 and near(lad[0].kg, 120.0) and lad[1].from == 2 and lad[1].to == 3 and near(lad[1].kg, 110.0) and lad[2].from == 4 and lad[2].to == 5 and lad[3].from == 6 and lad[3].to == 8 and near(lad[3].kg, 90.0), "the rep ladder: 1 rep 120, 2-3 110, 4-5 100, 6-8 90", lad)
	var best = LiftTrend.best_row(hist)
	ok(best != null and best.date == "2026-11-18", "the best day: the heaviest, the newest of equal days", best)
