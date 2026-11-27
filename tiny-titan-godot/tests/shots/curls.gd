extends RefCounted
## A lift done today for the FIRST time, by another variation of a planned movement (run with "new" data;
## the user, 2026-11-27: "today I did Bayesian curls for the first time... it says I beat my lift for that
## day, even though it was my first one, and underneath it has the last time I did reclined curls").
## Reclined curls are done on this weekday for three weeks, so curls are planned today; today Bayesian
## curls are logged for the first time. The Today card must say FIRST TIME (not beat it); the lift's page
## must be about the Bayesian curl alone and say first time; the reclined curl's page (not done today)
## must say its latest time was days ago, not "this time". Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0

const RECLINED = "Bicep Curl - Reclined"
const BAYES = "Bicep Curl - Bayesian cable"


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and not n.is_queued_for_deletion() and n is Control and n.is_visible_in_tree():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _close() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _three(reps: int, kg: float) -> Array:
	return [{"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}, {"reps": reps, "weightKg": kg}]


func _lift(back: int, exercises: Dictionary) -> Dictionary:
	var exs = []
	for name in exercises:
		exs.append({"name": name, "sets": exercises[name]})
	return App.build_session({"discipline": "lift", "date": Dates.add_days(App.today, -back), "exercises": exs})


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	var data = ShotHelper.demo_saved("new")
	data.sessions = [
		_lift(21, {RECLINED: _three(8, 11.0), "Bent Over Row - Dumbbell": _three(8, 22.0)}),
		_lift(14, {RECLINED: _three(9, 11.0), "Bent Over Row - Dumbbell": _three(8, 24.0)}),
		_lift(7, {RECLINED: _three(10, 11.0), "Bent Over Row - Dumbbell": _three(9, 24.0)}),
		_lift(0, {BAYES: _three(10, 9.0)}),
	]
	App.replace_all(data)
	await ShotHelper.wait(tree, 0.8)
	App.go("home")
	await ShotHelper.wait(tree, 1.0)

	# --- the Today card -------------------------------------------------------------------------------
	var plan = App.plan()
	var curl = null
	for l in plan.lifts:
		if str(LiftNames.split(str(l.name)).move) == "Bicep Curl":
			curl = l
	check(curl != null, "curls are planned today (done on this weekday for three weeks)")
	var dw = TodayView.done_words(BAYES, App.sessions(), App.today)
	check(str(dw.kind) == "first" and str(dw.cap) == "DONE · FIRST TIME" and (dw.last as Array).is_empty(), "a first Bayesian curl is a FIRST TIME, never 'beat it', and is compared with nothing (%s)" % str(dw.cap))
	var mark = _one("today_done", "first")
	check(mark != null, "the Today card's curl row says FIRST TIME")
	var row = null
	for n in _all("today_lift"):
		if str(LiftNames.split(str(n.get_meta("today_lift"))).move) == "Bicep Curl":
			row = n
	check(row != null and not ShotHelper.all_text(row).contains("BEAT") and ShotHelper.all_text(row).contains("Bayesian") and ShotHelper.all_text(row).contains("Planned"),
		"the row names the Bayesian curl, says the reclined curl was the plan, and says nothing of beating it")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "curls_1_today")

	# --- its page: the Bayesian curl alone ---------------------------------------------------------------
	if row != null and row.get("_tap") is Callable:
		row._tap.call()
	await ShotHelper.wait(tree, 0.8)
	var sh = _sheet()
	check(sh != null and ShotHelper.find_text(sh, "First time: this is the mark to beat.") != null and ShotHelper.find_text(sh, "Not done today") == null,
		"its page is the Bayesian curl's: a first time, the mark to beat")
	var here = _one("variation_row", "Bayesian cable", sh)
	var other = _one("variation_row", "Reclined", sh)
	check(here != null and bool(here.get_meta("variation_here")) and other != null and not bool(other.get_meta("variation_here")) and ShotHelper.all_text(other).contains("3 times"),
		"its variations are listed: Bayesian cable (this page) and Reclined, 3 times, with its last sets")
	await ShotHelper.snap(tree, "curls_2_bayesian_page")

	# --- the reclined curl's page: not done today, about its latest time --------------------------------
	if other != null and other.get("_tap") is Callable:
		other._tap.call()
	await ShotHelper.wait(tree, 0.9)
	sh = _sheet()
	var past = _one("lift_past", null, sh)
	check(sh != null and past != null and str(past.get_meta("lift_past")) == Dates.add_days(App.today, -7) and ShotHelper.find_text(sh, "THIS TIME") == null and ShotHelper.find_text(sh, "LATEST") != null,
		"the reclined curl's page says it was not done today and its latest time was a week ago (no 'this time')")
	await ShotHelper.snap(tree, "curls_3_reclined_page")
	await _close()
	print("CURLS %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
