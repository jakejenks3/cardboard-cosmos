extends SceneTree
## Unit test for resistance bands in place of a weight (game/bands.gd): the
## ladder, how a lift's name says it is done with a band, the words for band
## sets (LiftHistory), how band sets compare, set records and give an aim
## (LiftTrend), that the Log tab's draft carries the band both ways
## (LogLiftEditor.draft_from_sets / sets_from_draft), that a saved band set
## keeps its band and earns as a bodyweight set, and the band picker's keys.
## Results for sets without a band must be as they were. Made-up data.
##   godot --headless --path . --script res://tests/bands_test.gd
## Prints BANDS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func sets(rows: Array) -> Array:
	var out = []
	for r in rows:
		out.append({"reps": r[0], "weightKg": float(r[1])})
	return out


## Sets done with a band: [[reps, band], ...].
func bands(rows: Array) -> Array:
	var out = []
	for r in rows:
		out.append({"reps": r[0], "weightKg": 0.0, "band": str(r[1])})
	return out


## Every node under `n` (itself too) that `pick` says yes to.
func _find(n: Node, pick: Callable) -> Array:
	var out = []
	if pick.call(n):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find(c, pick))
	return out


func _init() -> void:
	_run()


func _run() -> void:
	# --- The ladder ----------------------------------------------------------
	ok(Bands.LADDER.size() == 9 and Bands.level("yellow") == 1 and Bands.level("red") == 3 and Bands.level("gold") == 9 and Bands.level(" Green ") == 4, "the ladder, light to heavy, any case")
	ok(Bands.level("") == 0 and Bands.level("pink") == 0 and Bands.level(null) == 0, "no band, or one not on the ladder, is level 0")
	ok(Bands.step("yellow", -1) == "yellow" and Bands.step("gold", 1) == "gold", "a step never leaves the ladder")
	ok(Bands.step("red", 1) == "green" and Bands.step("red", -1) == "orange" and Bands.step("green", 3) == "purple" and Bands.step("", 1) == "green", "steps go up and down the ladder (no band: from red)")
	ok(Bands.name_of("blue") == "Blue" and Bands.words("green") == "green band" and Bands.name_of("") == "" and Bands.words("") == "band", "names and words")
	var cols = {}
	for id in Bands.LADDER:
		cols[Bands.color_of(id).to_html()] = true
	ok(cols.size() == Bands.LADDER.size(), "every band has its own colour", cols.keys())
	ok(Bands.text_color("yellow") == Pal.INK and Bands.text_color("silver") == Pal.INK and Bands.text_color("black") == Pal.TEXT and Bands.text_color("purple") == Pal.TEXT, "dark ink on light bands, light text on dark ones")
	ok(Bands.DEFAULT == "red" and Bands.is_band({"reps": 5, "band": "red"}) and not Bands.is_band({"reps": 5, "weightKg": 0.0}) and not Bands.is_band({"reps": 5, "band": ""}), "a band set is one with a band")
	ok(Bands.top(bands([[10, "green"], [8, "blue"], [0, "gold"]])) == "blue" and Bands.top(sets([[5, 60]])) == "", "the heaviest band of sets done (a set without reps does not count)")

	# --- What a lift's name says ---------------------------------------------
	ok(Bands.of_name("Face Pull - Green band") == "green" and Bands.of_name("Face Pull - Rope") == "" and Bands.of_name("Green") == "", "a ladder colour in the variation", [Bands.of_name("Face Pull - Green band")])
	ok(Bands.says_band("Face Pull - Green band") and Bands.says_band("Pull-up - Band") and Bands.says_band("March - banded") and Bands.says_band("Banded March"), "band words in a name or variation")
	ok(Bands.says_band("Pull-Apart") and Bands.says_band("Lateral Walk"), "a library movement whose usual equipment is a band")
	ok(not Bands.says_band("Bench Press - Barbell") and not Bands.says_band("Squat") and not Bands.says_band("Face Pull - Rope") and not Bands.says_band("Bicep Curl") and not Bands.says_band(""), "other lifts are not")

	# --- In words (LiftHistory) ----------------------------------------------
	var fmt = func(kg): return "%s kg" % TTUtil.num_str(float(kg))
	ok(LiftHistory.describe_sets(bands([[15, "green"], [15, "green"], [15, "green"]]), fmt) == "3×15 · green band", "same band, same reps", LiftHistory.describe_sets(bands([[15, "green"], [15, "green"], [15, "green"]]), fmt))
	ok(LiftHistory.describe_sets(bands([[15, "red"], [15, "red"], [12, "red"]]), fmt) == "15, 15, 12 · red band", "same band, reps differ")
	ok(LiftHistory.describe_sets(bands([[12, "blue"], [15, "green"], [10, "green"]]), fmt) == "3 sets, top blue band × 12", "more than one band: the heaviest", LiftHistory.describe_sets(bands([[12, "blue"], [15, "green"], [10, "green"]]), fmt))
	ok(LiftHistory.top_set_label(bands([[15, "green"], [12, "blue"]]), func(kg): return kg) == "blue×12", "the chip: the heaviest band", LiftHistory.top_set_label(bands([[15, "green"], [12, "blue"]]), func(kg): return kg))
	ok(LiftHistory.describe_sets(sets([[5, 100], [5, 100], [5, 100]]), fmt) == "3×5 @ 100 kg" and LiftHistory.describe_sets(sets([[8, 0], [8, 0], [8, 0]]), fmt) == "3×8 bodyweight" and LiftHistory.describe_sets(sets([[5, 60], [3, 80]]), fmt) == "2 sets, top 80 kg × 3", "weights and bodyweight are said as before")
	ok(LiftHistory.describe_sets([{"reps": 3, "weightKg": 0.0, "holdSec": 30}], fmt) == "3 × 30 s hold" and LiftHistory.top_set_label(sets([[5, 100], [3, 80]]), func(kg): return kg) == "100×5" and LiftHistory.top_set_label(sets([[8, 0], [9, 0]]), func(kg): return kg) == "2×8", "holds and chips as before")
	var c_up = LiftHistory.compare_band_set({"reps": 12, "band": "blue"}, {"reps": 12, "weightKg": 0.0, "band": "green"}, true, 0)
	var c_down = LiftHistory.compare_band_set({"reps": 15, "band": "red"}, {"reps": 12, "weightKg": 0.0, "band": "green"}, true, 0)
	var c_reps = LiftHistory.compare_band_set({"reps": 14, "band": "green"}, {"reps": 12, "weightKg": 0.0, "band": "green"}, true, 0)
	ok(c_up != null and c_up.kind == "band" and int(c_up.delta) == 1 and c_down != null and c_down.kind == "band" and int(c_down.delta) == -1, "a set's badge: a heavier or lighter band than that set last time", [c_up, c_down])
	ok(c_reps != null and c_reps.kind == "reps" and int(c_reps.delta) == 2 and LiftHistory.compare_band_set({"reps": 10, "band": "green"}, {"reps": 12, "weightKg": 0.0, "band": "green"}, true, 0) == null, "the same band: more reps, or nothing to say", c_reps)
	var c_pr = LiftHistory.compare_band_set({"reps": 8, "band": "blue"}, {"reps": 12, "weightKg": 0.0, "band": "green"}, true, 4)
	ok(c_pr != null and c_pr.kind == "pr" and bool(c_pr.band) and LiftHistory.compare_band_set({"reps": 8, "band": "blue"}, null, true, 0).kind == "extra" and LiftHistory.compare_band_set({"reps": 8, "band": "blue"}, null, false, 0) == null, "a heavier band than ever is a record; a set more than last time is extra", c_pr)
	ok(LiftHistory.compare_band_set({"reps": 0, "band": "blue"}, null, true, 0) == null and LiftHistory.compare_band_set({"reps": 10, "band": "blue"}, {"reps": 8, "weightKg": 20.0}, true, 0) == null, "no reps, or a weighted set last time: nothing to say")

	# --- A day, compared (LiftTrend) -----------------------------------------
	var d = LiftTrend.day(bands([[15, "green"], [12, "blue"], [10, "blue"]]))
	ok(int(d.band) == 5 and str(d.bandId) == "blue" and int(d.bandReps) == 12 and int(d.reps) == 37 and float(d.topKg) == 0.0 and float(d.volumeKg) == 0.0, "a day done with bands: its heaviest band and the reps with it", d)
	ok(not LiftTrend.day(sets([[5, 60]])).has("band") and not LiftTrend.day(sets([[8, 0]])).has("bandId"), "a day without a band has no band keys (results as before)")
	var before = [{"date": "2026-11-10", "sets": bands([[15, "green"], [15, "green"], [15, "green"]])}, {"date": "2026-11-03", "sets": bands([[12, "red"], [12, "red"]])}]
	var cmp_up = LiftTrend.compare(bands([[12, "blue"], [12, "blue"]]), before)
	ok(cmp_up.kind == "up" and int(cmp_up.band) == 1 and int(cmp_up.reps) == 0 and bool(cmp_up.pr), "a heavier band than last time: up a band, and a record", cmp_up)
	var cmp_reps = LiftTrend.compare(bands([[16, "green"], [16, "green"], [16, "green"]]), before)
	ok(cmp_reps.kind == "up" and int(cmp_reps.band) == 0 and int(cmp_reps.reps) == 3 and not bool(cmp_reps.pr), "the same band: by the reps", cmp_reps)
	var cmp_down = LiftTrend.compare(bands([[15, "red"], [15, "red"], [15, "red"]]), before)
	ok(cmp_down.kind == "down" and int(cmp_down.band) == -1 and not bool(cmp_down.pr), "a lighter band: down a band", cmp_down)
	var old_way = [{"date": "2026-11-10", "sets": sets([[15, 0], [15, 0]])}]
	var cmp_old = LiftTrend.compare(bands([[15, "green"], [15, "green"]]), old_way)
	ok(int(cmp_old.band) == 0 and cmp_old.kind == "same" and not bool(cmp_old.pr), "against days logged before bands were: by the reps, no record", cmp_old)
	ok(not LiftTrend.compare(sets([[5, 60]]), [{"sets": sets([[5, 60]])}]).has("band"), "a weighted lift's comparison is as before")
	var p = LiftTrend.pairs(bands([[12, "blue"], [15, "green"], [10, "green"]]), bands([[15, "green"], [15, "green"]]))
	ok(p.size() == 3 and int(p[0].dband) == 1 and p[0].kind == "up" and int(p[1].dband) == 0 and p[1].kind == "same" and p[2].kind == "added", "set by set: the band first, then the reps", p)
	ok(not LiftTrend.pairs(sets([[5, 60]]), sets([[5, 60]]))[0].has("dband"), "weighted pairs as before")

	# --- Records, the best day, the aim --------------------------------------
	var r_band = LiftTrend.records(bands([[10, "blue"]]), before)
	ok(r_band.size() >= 1 and r_band[0].id == "band" and str(r_band[0].band) == "blue" and str(r_band[0].unit) == "band" and int(r_band[0].value) == 5, "a band never used before, heavier than any: Heaviest band", r_band)
	var r_reps = LiftTrend.records(bands([[18, "green"], [15, "green"]]), before)
	ok(r_reps.size() == 1 and r_reps[0].id == "reps_band" and int(r_reps[0].value) == 18, "the same band, more reps than ever with it", r_reps)
	var r_day = LiftTrend.records(bands([[15, "green"], [15, "green"], [15, "green"], [10, "green"]]), before)
	ok(r_day.size() == 1 and r_day[0].id == "day_reps", "more reps in a day", r_day)
	ok(LiftTrend.records(bands([[10, "blue"]]), old_way).filter(func(r): return r.id == "band" or r.id == "reps_band").is_empty(), "nothing with a band before: no band record")
	var hist = [{"date": "2026-11-12", "sets": bands([[10, "blue"], [8, "blue"]])}, {"date": "2026-11-05", "sets": bands([[12, "blue"]])}, {"date": "2026-11-01", "sets": bands([[20, "green"], [20, "green"]])}]
	var best = LiftTrend.best_row(hist)
	ok(best != null and str(best.date) == "2026-11-05", "the best day: the heaviest band, then the most reps with it", best)
	ok(LiftTrend.main_value(LiftTrend.day(bands([[5, "blue"]]))) > LiftTrend.main_value(LiftTrend.day(bands([[30, "green"]]))) and LiftTrend.main_value(LiftTrend.day(sets([[8, 0]]))) == 8.0 and LiftTrend.main_value(LiftTrend.day(sets([[5, 60]]))) == 60.0, "a heavier band always counts for more; others as before")
	# A lift logged with no weight before bands could be, then with a band: the
	# older days are below every band day (not 15 reps against a band's 4.015).
	var mixed = [{"date": "2026-11-20", "sets": bands([[15, "green"], [15, "green"]])}, {"date": "2026-11-01", "sets": sets([[15, 0], [15, 0], [15, 0]])}]
	ok(LiftTrend.best_row(mixed) == mixed[0] and LiftTrend.best_row(mixed.slice(1), true) == mixed[1] and LiftTrend.main_value(LiftTrend.day(mixed[1].sets), true) < LiftTrend.main_value(LiftTrend.day(bands([[1, "yellow"]])), true), "older days with no band rank below the band days", [LiftTrend.best_row(mixed)])
	ok(LiftTrend.main_value(LiftTrend.day(sets([[8, 0]])), true) < 1.0 and LiftTrend.main_value(LiftTrend.day(sets([[5, 60]])), true) == 60.0 and LiftTrend.main_value(LiftTrend.day([{"reps": 2, "weightKg": 0.0, "holdSec": 30}]), true) == 30.0, "only a no-weight, no-band day is put below; weights and holds as they were")
	var cal = LiftTrend.calendar(mixed, "2026-11-22", 4)
	ok(cal.filter(func(c): return c.pr).map(func(c): return c.date) == ["2026-11-20"], "the calendar rings the first band day, not the day before bands", cal.filter(func(c): return c.pr))
	var t_reps = LiftTrend.next_target(bands([[15, "green"], [15, "green"], [12, "green"]]), 2.5)
	ok(t_reps.kind == "reps" and int(t_reps.set) == 3 and int(t_reps.reps) == 13 and str(t_reps.band) == "green" and str(t_reps.sets[2].band) == "green", "the aim: one more rep on the weakest set, with the same band", t_reps)
	var t_band = LiftTrend.next_target(bands([[20, "green"], [21, "green"], [20, "green"]]), 2.5)
	ok(t_band.kind == "band" and int(t_band.addBand) == 1 and bool(t_band.get("heavier", false)) and str(t_band.toBand) == "blue" and str(t_band.band) == "green" and int(t_band.reps) == LiftTrend.BAND_DOWN_TO and t_band.sets.all(func(one): return str(one.band) == "blue" and int(one.reps) == 12), "every set at 20 reps: the next band up, back to 12", t_band)
	ok(LiftHistory.describe_sets(t_band.sets, fmt) == "3×12 · blue band", "said as the next time card says it", LiftHistory.describe_sets(t_band.sets, fmt))
	var t_warm = LiftTrend.next_target(bands([[20, "red"], [20, "green"], [18, "green"]]), 2.5)
	ok(t_warm.kind == "reps" and int(t_warm.set) == 3 and str(t_warm.sets[0].band) == "red", "a lighter band before the working sets stays as it was", t_warm)
	var t_top = LiftTrend.next_target(bands([[25, "gold"], [25, "gold"]]), 2.5)
	ok(t_top.kind == "reps" and int(t_top.reps) == 26, "at the heaviest band there is no next one: reps go on", t_top)
	var t_side = LiftTrend.next_target(Sides.tag_sets(bands([[30, "green"], [32, "green"]]), 2), 2.5)
	var t_side_up = LiftTrend.next_target(Sides.tag_sets(bands([[40, "green"], [41, "green"]]), 2), 2.5)
	ok(t_side.kind == "reps" and t_side_up.kind == "band" and int(t_side_up.reps) == 24, "both sides added up: 20 a side, then 12 a side", [t_side.kind, t_side_up])
	var t_w = LiftTrend.next_target(sets([[10, 60], [10, 60], [10, 60]]), 2.5)
	ok(t_w.kind == "weight" and not t_w.has("addBand") and not t_w.has("band") and LiftTrend.next_target(sets([[12, 0], [10, 0]]), 2.5).kind == "reps", "weights and bodyweight aim as before")
	ok(LiftTrend.ghost(hist, hist[0]) == null and LiftTrend.plateau(hist + hist) == null, "no ghost duel and no plateau for a band lift")
	var ser = LiftTrend.series(hist, "band")
	ok(ser.size() == 3 and ser.map(func(pt): return int(pt.y)) == [4, 5, 5], "the band chart: the heaviest band of each day, oldest first", ser)
	ok(LiftTrend.banded(hist) and not LiftTrend.banded([{"sets": sets([[5, 60]])}]), "banded: any set with a band")

	# --- Kept by the library and said by the summary -------------------------
	var sess = [{"id": "s1", "discipline": "lift", "date": "2026-11-12", "createdAt": 1, "exercises": [{"name": "Face Pull - Rope", "sets": bands([[15, "green"], [12, "blue"]])}]}]
	var st = LiftLibrary.stats(sess)
	var kept = st.get("face pull - rope", {}).get("history", [{}])[0].get("sets", [])
	ok(kept.size() == 2 and str(kept[0].get("band", "")) == "green" and str(kept[1].get("band", "")) == "blue", "the library's history keeps each set's band", st)
	ok(Dosage.sets_words("Face Pull - Green band", bands([[15, "green"], [15, "green"]]), fmt) == "2×15 · green band" and Dosage.sets_words("Face Pull - Green band", sets([[15, 0], [15, 0]]), fmt) == "2×15 (a band, no weight)", "the training summary says the band, or that an older day had one", [Dosage.sets_words("Face Pull - Green band", bands([[15, "green"], [15, "green"]]), fmt)])

	# --- The parts that need the App autoload (a frame after the start) -------
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		print("SKIP  the Log tab and the save: no App")
	else:
		var editor = load("res://ui/screens/log_lift_editor.gd")
		var draft = editor.draft_from_sets("Face Pull - Rope", bands([[15, "green"], [12, "blue"]]), "lb")
		ok(bool(draft.get("band", false)) and not bool(draft.bodyweight) and not bool(draft.timed) and str(draft.sets[0].band) == "green" and str(draft.sets[1].band) == "blue", "a band lift opens with its bands", draft)
		var back = editor.sets_from_draft(draft, "lb")
		ok(back == [{"reps": 15, "weightKg": 0.0, "band": "green"}, {"reps": 12, "weightKg": 0.0, "band": "blue"}], "and comes back as the sets it was", back)
		var older = editor.draft_from_sets("Face Pull - Green band", sets([[15, 0], [12, 0]]), "lb")
		ok(bool(older.get("band", false)) and not bool(older.bodyweight) and older.sets.all(func(s): return str(s.band) == "green"), "a lift named for its band, logged with no weight: opens as that band", older)
		var bench = editor.draft_from_sets("Bench Press - Barbell", sets([[5, 100]]), "kg")
		ok(bench == {"name": "Bench Press - Barbell", "bodyweight": false, "timed": false, "sets": [{"reps": "5", "weight": "100"}]}, "a weighted lift's draft is as before", bench)
		var pull = editor.draft_from_sets("Pull-up", sets([[8, 0]]), "kg")
		ok(bool(pull.bodyweight) and not pull.has("band") and not pull.sets[0].has("band"), "a bodyweight lift stays bodyweight", pull)
		var stretch = editor.draft_from_sets("Hamstring Stretch - Band", [{"reps": 3, "weightKg": 0.0, "holdSec": 30}], "kg")
		ok(bool(stretch.timed) and not stretch.has("band") and editor.sets_from_draft(stretch, "kg") == [{"reps": 3, "weightKg": 0.0, "holdSec": 30}], "a hold stays a hold, even with a band in its name", stretch)
		var bare = editor.sets_from_draft({"name": "x", "bodyweight": true, "band": true, "sets": [{"reps": "10", "weight": "20"}, {"reps": "", "weight": ""}]}, "kg")
		ok(bare == [{"reps": 10, "weightKg": 0.0, "band": Bands.DEFAULT}], "a band set without a band gets the usual one, never a weight", bare)
		var timed_band = editor.sets_from_draft({"name": "x", "bodyweight": false, "band": true, "timed": true, "sets": [{"reps": "2", "weight": "", "hold": "30", "band": "red"}]}, "kg")
		ok(timed_band == [{"reps": 2, "weightKg": 0.0, "holdSec": 30}], "Hold and Band are one at a time: a hold wins", timed_band)
		ok(editor.sets_from_draft({"name": "x", "bodyweight": false, "sets": [{"reps": "5", "weight": "100", "band": "red"}]}, "kg") == [{"reps": 5, "weightKg": 100.0}], "a band left on a row after switching back to weight is not saved")

		# Saved: the band stays on the set, and it earns as a bodyweight set.
		app.replace_all(app.empty_saved())
		var s1 = app.build_session({"discipline": "lift", "date": app.today, "exercises": [{"name": "Face Pull - Rope", "sets": bands([[15, "green"], [15, "green"], [12, "blue"]])}]})
		app.commit_sessions([s1], "Workout")
		var stored = app.sessions()[0].exercises[0].sets
		ok(stored.size() == 3 and stored.all(func(one): return float(one.weightKg) == 0.0) and str(stored[2].get("band", "")) == "blue", "saved: weight 0 and the band", stored)
		var reread = app.parse_saved(JSON.parse_string(JSON.stringify(app.saved)))
		ok(reread != null and str(reread.sessions[0].exercises[0].sets[0].get("band", "")) == "green", "and read back from the save file", reread.sessions[0].exercises[0].sets if reread != null else null)
		var xp_band = int(app.state.xp.hero)
		app.replace_all(app.empty_saved())
		var s2 = app.build_session({"discipline": "lift", "date": app.today, "exercises": [{"name": "Face Pull - Rope", "sets": sets([[15, 0], [15, 0], [12, 0]])}]})
		s2["createdAt"] = s1.createdAt
		s2["id"] = s1.id
		app.commit_sessions([s2], "Workout")
		ok(xp_band > 0 and int(app.state.xp.hero) == xp_band, "a band set earns what a bodyweight set earns", [xp_band, app.state.xp.hero])
		app.replace_all(app.empty_saved())

		# The screens' words.
		var views = load("res://ui/screens/lift_views.gd")
		ok(views.mode_of([{"sets": bands([[10, "red"]])}]) == "band" and views.mode_of([{"sets": sets([[5, 60]])}]) == "kg" and views.mode_of([{"sets": sets([[5, 0]])}]) == "reps", "a lift's page goes by the band")
		ok(views.set_text({"reps": 15, "weightKg": 0.0, "band": "green"}, "lb") == "15 × green band" and views.set_text({"reps": 5, "weightKg": 0.0}, "lb") == "5 reps", "a set in words")
		ok(views.metric_text("band", 4.0, "lb") == "Green" and views.metric_text("band", 0.0, "lb") == "" and views.record_value({"id": "band", "unit": "band", "value": 5, "band": "blue"}, "lb") == "Blue band", "the chart's axis and the record say the band's name")
		ok(views.metric_options("band").map(func(o): return o.value) == ["band", "reps"], "the band chart: Band and Reps")
		var sv = load("res://ui/screens/session_view.gd")
		ok(sv.delta_text({"kind": "up", "kg": 0.0, "reps": 0, "sec": 0, "band": 1}, "lb") == "+1 band" and sv.band_change(-2) == "-2 bands" and sv.delta_text({"kind": "up", "kg": 0.0, "reps": 2, "sec": 0}, "lb") == "+2 reps", "the change tag")
		var jl = load("res://ui/screens/journey_lifts.gd")
		var st2 = LiftLibrary.stats(sess)["face pull - rope"]
		ok(jl.best_text(st2, "lb") == "Blue band × 12" and jl.heaviest_band(st2.history).band == "blue", "the lift list's best", jl.best_text(st2, "lb"))

		# The band picker: a key changes the band in place; the ends say no.
		var picker_script = load("res://ui/widgets/band_picker.gd")
		var bp = picker_script.new()
		bp.setup("silver", "Face Pull set 1")
		root.add_child(bp)
		var got = []
		bp.changed.connect(func(id): got.append(id))
		var w0 = bp._pill.custom_minimum_size.x
		bp._press(1)
		ok(bp.band == "gold" and got == ["gold"] and bp._name.text == "Gold", "heavier: the next band, said at once", [bp.band, got])
		bp._press(1)
		ok(bp.band == "gold" and got == ["gold"], "at the heaviest band the key does nothing", got)
		bp.set_band("yellow")
		bp._press(-1)
		ok(bp.band == "yellow" and got == ["gold"], "at the lightest band the other key does nothing")
		bp._press(1)
		ok(bp.band == "orange" and bp._pill.custom_minimum_size.x == w0 and w0 >= 54.0, "the pill keeps one width whatever the band", [w0, bp._pill.custom_minimum_size.x])
		ok(bp._minus.get_meta("band_key", "") == "lighter" and bp._plus.get_meta("band_key", "") == "heavier" and bp._plus.tooltip_text == "Face Pull set 1: heavier band", "the keys are named for a walkthrough and in their tooltips")
		bp.queue_free()

		# The Log tab's exercise cards, built for real (no form around them, so
		# nothing is rebuilt: what a tap changes is changed in place).
		app.replace_all(app.empty_saved())
		var s3 = app.build_session({"discipline": "lift", "date": Dates.add_days(app.today, -3), "exercises": [{"name": "Face Pull - Rope", "sets": bands([[15, "green"], [15, "green"], [12, "blue"]])}]})
		app.commit_sessions([s3], "Workout")
		var ed = editor.new(null)
		var filed = str(app.sessions()[0].exercises[0].name)
		ed.exercises = [editor.draft_from_sets(filed, bands([[15, "green"], [15, "green"]]), "lb"), {"name": "Bench Press - Barbell", "bodyweight": false, "sets": [{"reps": "5", "weight": "135"}]}]
		var form_box = VBoxContainer.new()
		form_box.size = Vector2(440, 800)
		root.add_child(form_box)
		ed.build(form_box)
		await process_frame
		var pickers = _find(form_box, func(n): return n.has_meta("band_of"))
		var chips = _find(form_box, func(n): return n.has_meta("band_chip"))
		ok(pickers.size() == 2 and str(pickers[0].get_meta("band_of")) == "0:0" and chips.size() == 2 and bool(chips[0].get_meta("band_chip")) and not bool(chips[1].get_meta("band_chip")), "a band picker per set of the band lift, a Band key on each card (lit on the band lift)", [pickers.size(), chips.size()])
		ok(_find(form_box, func(n): return n is Button and n.text == "+1 band").size() == 1 and _find(form_box, func(n): return n is Button and n.text == "BW").size() == 2 and _find(form_box, func(n): return n is Button and n.text == "Hold").size() == 2, "+1 band on the band lift; Weight, BW, Band and Hold on every card (one track)")
		# The track keeps every key in its place: the Band and L+R keys of a band
		# card are where they are on a weight card, so a tap on Band never moves it.
		var lrs = _find(form_box, func(n): return n is Button and n.text == Sides.SHORT)
		ok(chips.size() == 2 and lrs.size() == 2 and chips[0].global_position.x > 60.0 and absf(chips[0].global_position.x - chips[1].global_position.x) < 0.5 and absf(lrs[0].global_position.x - lrs[1].global_position.x) < 0.5,
			"the Band and L+R keys sit at the same place with a band and with a weight", [chips.map(func(c): return c.global_position.x), lrs.map(func(c): return c.global_position.x)])
		var kit = load("res://ui/kit.gd")
		kit.fingers = true
		var ed_f = editor.new(null)
		ed_f.exercises = [ed.exercises[0].duplicate(true), ed.exercises[1].duplicate(true)]
		var box_f = VBoxContainer.new()
		box_f.size = Vector2(440, 800)
		root.add_child(box_f)
		ed_f.build(box_f)
		await process_frame
		var chips_f = _find(box_f, func(n): return n.has_meta("band_chip"))
		var heads_f = _find(box_f, func(n): return n.has_meta("band_chip")).map(func(c): return c.get_parent().get_combined_minimum_size().x)
		ok(chips_f.size() == 2 and chips_f[0].global_position.x > 60.0 and absf(chips_f[0].global_position.x - chips_f[1].global_position.x) < 0.5 and heads_f.all(func(w): return w <= 440.0 - 24.0),
			"at finger size too, and the head row fits the column", [chips_f.map(func(c): return c.global_position.x), heads_f])
		box_f.queue_free()
		kit.fingers = false
		var plus = pickers[0]._plus
		var at = plus.global_position
		plus.pressed.emit()
		await process_frame
		ok(str(ed.exercises[0].sets[0].band) == "blue" and pickers[0].band == "blue" and plus.global_position == at and is_instance_valid(plus), "heavier on set 1: the draft has the next band, and the key has not moved", [ed.exercises[0].sets[0], at, plus.global_position])
		var badge_words = _find(ed._badges[0][0], func(n): return n is Label).map(func(l): return l.text)
		ok(badge_words == ["+1 band"], "and its badge says it is a band heavier than last time", badge_words)
		plus.pressed.emit()
		plus.pressed.emit()
		await process_frame
		badge_words = _find(ed._badges[0][0], func(n): return n is Label).map(func(l): return l.text)
		ok(str(ed.exercises[0].sets[0].band) == "purple" and badge_words == ["PR!"], "a heavier band than ever on the lift: PR", [ed.exercises[0].sets[0], badge_words])
		ed.add_set(0)
		ok(ed.exercises[0].sets.size() == 3 and str(ed.exercises[0].sets[2].band) == "green", "+ Set copies the last set, band and all", ed.exercises[0].sets)
		ed.bump_all(0, "band")
		ok(ed.exercises[0].sets.map(func(s): return str(s.band)) == ["silver", "blue", "blue"], "+1 band: every set one band heavier", ed.exercises[0].sets)
		ed._toggle_band(1)
		ok(bool(ed.exercises[1].get("band", false)) and not bool(ed.exercises[1].bodyweight) and str(ed.exercises[1].sets[0].band) == "blue", "Band on a weighted lift: every set gets the band used last (no band of its own, none in its name)", ed.exercises[1])
		ok(editor.sets_from_draft(ed.exercises[1], "lb") == [{"reps": 5, "weightKg": 0.0, "band": "blue"}], "and is saved as that band, no weight")
		ed._toggle_band(1)
		ok(not ed.exercises[1].has("band") and editor.sets_from_draft(ed.exercises[1], "lb")[0].weightKg > 60.0, "Band again: back to its weight", ed.exercises[1])
		ok(ed.session_exercises()[0].sets.all(func(one): return Bands.is_band(one) and float(one.weightKg) == 0.0), "the workout as it will be saved: band sets")
		var fresh = ed._blank("Pull-Apart")
		ok(bool(fresh.get("band", false)) and str(fresh.sets[0].band) == "blue" and not ed._blank("Bench Press - Barbell").has("band"), "a new lift that says band starts with a band", fresh)
		form_box.queue_free()
		var rows_box = sv.lift_rows({"date": app.today, "exercises": [{"name": filed, "sets": bands([[15, "purple"], [15, "purple"]])}]})
		root.add_child(rows_box)
		var line = _find(rows_box, func(n): return n.has_meta("band_sets"))
		var row_words = _find(rows_box, func(n): return n is Label).map(func(l): return l.text)
		ok(line.size() == 1 and str(line[0].get_meta("band_sets")) == "purple" and row_words.has("2×15 · purple band") and row_words.has("PR +2 bands"), "a session's exercise row: the bands in words, their colour, and the change", row_words)
		rows_box.queue_free()

		# A lift's page for a band lift: the three views are built (and drawn).
		var history = [{"date": "2026-11-12", "id": "a", "sets": bands([[12, "blue"], [12, "blue"]])}, {"date": "2026-11-05", "id": "b", "sets": bands([[20, "green"], [20, "green"]])}, {"date": "2026-10-29", "id": "c", "sets": bands([[15, "green"], [12, "green"]])}]
		var page = VBoxContainer.new()
		page.size = Vector2(420, 1600)
		root.add_child(page)
		var ctx = {"sheet": null, "lift": "Face Pull - Rope", "history": history, "cur": history[0], "st": {"name": "Face Pull - Rope", "count": 3, "last": "2026-11-12", "bestKg": 0.0, "bestReps": 0, "e1rm": 0.0, "bwReps": 20, "volumeKg": 0.0, "reps": 91, "history": history},
			"wu": "lb", "goal": 0, "view": "compare", "sides": 1}
		views.build(page, ctx)
		await process_frame
		var words = _find(page, func(n): return n is Label).map(func(l): return l.text)
		var nb = _find(page, func(n): return n.has_meta("next_band"))
		ok(words.has("One more rep on set 1: 13 reps with the blue band.") and words.has("13, 12 · blue band") and nb.size() == 1 and str(nb[0].get_meta("next_band")) == "blue", "Compare: next time, the band to use and one more rep", words)
		ok(words.has("12 × blue band") and words.has("20 × green band") and words.has("+1 band") and words.has("New record! Heaviest band."), "Compare: the sets in band words, a band more, a record", words)
		ctx["cur"] = history[1]
		views.show_view("compare", ctx)
		await process_frame
		words = _find(page, func(n): return n is Label).map(func(l): return l.text)
		ok(words.has("Every set with the green band got 20 reps: move up to the blue band and come back to 12 reps.") and words.has("2×12 · blue band"), "Compare: every set at 20 reps, so the next band up", words)
		ctx["cur"] = history[0]
		views.show_view("progress", ctx)
		await process_frame
		var tiles = _find(page, func(n): return n.has_meta("band_record"))
		ok(tiles.size() == 1 and str(tiles[0].get_meta("band_record")) == "blue", "Progress: the heaviest band is a record tile")
		views.show_view("logbook", ctx)
		await process_frame
		var sb_script = load("res://ui/charts/set_blocks.gd")
		var blocks = _find(page, func(n): return n.get_script() == sb_script)
		ok(blocks.size() == 3 and blocks[0].mode == "band" and is_equal_approx(blocks[0].top, 5.0), "Logbook: blocks for band sets, as tall as the band against the heaviest", [blocks.size(), blocks[0].mode if not blocks.is_empty() else ""])
		# A lift named for its band, logged with no weight before bands could be,
		# then with the picker: the older day is no "best" to beat.
		var old_new = [{"date": "2026-11-20", "id": "n", "sets": bands([[15, "green"], [15, "green"], [15, "green"]])}, {"date": "2026-11-01", "id": "o", "sets": sets([[15, 0], [15, 0], [15, 0]])}]
		ctx["history"] = old_new
		ctx["cur"] = old_new[0]
		ctx["lift"] = "Face Pull - Green band"
		views.show_view("compare", ctx)
		await process_frame
		words = _find(page, func(n): return n is Label).map(func(l): return l.text)
		ok(not words.any(func(w): return w.begins_with("Your best") or w.contains("more reps with the")), "Compare: a day from before bands is not shown as the best to beat", words)
		page.queue_free()

		# The PT key on an exercise card (the user, 2026-11-24: "a way to tick an
		# exercise as PT while adding it, instead of having to go back and do it
		# after logging").
		app.replace_all(app.empty_saved())
		var past = app.build_session({"discipline": "lift", "date": Dates.add_days(app.today, -2), "exercises": [{"name": "Wall Slide", "sets": sets([[12, 0]])}, {"name": "Clamshell - Band", "sets": bands([[15, "red"]])}]})
		app.commit_sessions([past], "Workout")
		app.set_pt("Clamshell - Band", true)
		var pe = editor.new(null)
		pe.exercises = [editor.draft_from_sets("Wall Slide", sets([[12, 0], [12, 0]]), "lb"), editor.draft_from_sets("Clamshell - Band", bands([[15, "red"]]), "lb"), {"name": "(PT) Neck Tilt", "bodyweight": true, "sets": [{"reps": "10", "weight": ""}]}]
		var pbox = VBoxContainer.new()
		pbox.size = Vector2(440, 800)
		root.add_child(pbox)
		pe.build(pbox)
		await process_frame
		var pks = _find(pbox, func(n): return n.has_meta("pt_chip"))
		ok(pks.size() == 3 and not bool(pks[0].get_meta("pt_chip")) and bool(pks[1].get_meta("pt_chip")) and bool(pks[2].get_meta("pt_chip")), "a PT key on every card: off for a plain lift, on for a PT lift and for one typed with (PT)", pks.map(func(k): return k.get_meta("pt_chip")))
		var pk_at = pks[0].global_position
		pks[0].pressed.emit()
		# (the form rebuilds the cards after a change: done by hand here, with no form)
		for old in pbox.get_children():
			pbox.remove_child(old)
			old.queue_free()
		pe.build(pbox)
		await process_frame
		pks = _find(pbox, func(n): return n.has_meta("pt_chip"))
		var hints = _find(pbox, func(n): return n.has_meta("pt_hint"))
		ok(bool(pks[0].get_meta("pt_chip")) and pks[0].global_position == pk_at and hints.size() == 1, "tapped: it is lit, it has not moved, and a line says what saving will do", [pks[0].global_position, pk_at, hints.size()])
		pe._toggle_pt(1)
		var out = pe.session_exercises()
		ok(out[0].get("pt") == true and out[1].get("pt") == false and not out[2].has("pt") and str(out[2].name) == "(PT) Neck Tilt", "saved with the key's word: on, off, and untouched (the typed tag still says it)", out.map(func(x): return [x.name, x.get("pt")]))
		var ses = app.build_session({"discipline": "lift", "date": app.today, "exercises": out})
		app.commit_sessions([ses], "Workout")
		ok(Pt.is_pt(app.pt(), "Wall Slide") and not Pt.is_pt(app.pt(), "Clamshell - Band") and Pt.is_pt(app.pt(), "Neck Tilt"), "after saving: Wall Slide is PT now, Clamshell is not any more, Neck Tilt is (its tag)", app.pt().keys())
		var saved_ex = app.sessions().filter(func(x): return str(x.date) == app.today)[0].exercises
		ok(saved_ex.all(func(x): return not x.has("pt")), "no PT flag is left on the saved exercises", saved_ex)
		pe.exercises = [{"name": "(PT) Neck Tilt", "bodyweight": true, "pt": false, "sets": [{"reps": "10", "weight": ""}]}]
		ok(str(pe.session_exercises()[0].name) == "Neck Tilt", "switched off with (PT) typed in front: the tag comes off the name too", pe.session_exercises())
		pbox.queue_free()
		app.replace_all(app.empty_saved())

	print("BANDS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
