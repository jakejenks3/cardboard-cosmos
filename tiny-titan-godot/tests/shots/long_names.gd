extends RefCounted
## Long lift names (run with the "year" data, best with --fingers and pounds):
## the demo lifts are short ("Bench Press - Barbell"), a real log is not
## ("Romanian Deadlift - Single leg balance pad", marked PT). Every planned lift
## gets a long variation, two are marked PT, and every screen that lists lifts
## is snapped: the snap fails when anything is wider than its column.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0

const LONG = ["Single leg balance pad", "Single arm incline home cable", "Deficit pause gym barbell", "Half kneeling single arm home band"]


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _close_sheets() -> void:
	for n in ShotHelper.walk(main):
		if n is Sheet:
			n.close()
	await ShotHelper.wait(tree, 0.6)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	App.update_settings({"split": "pull_push_legs"})
	await ShotHelper.wait(tree, 0.5)
	var renamed = []
	var i = 0
	for l in App.plan().lifts:
		var move = str(LiftNames.split(str(l.name)).move)
		var to = move + LiftNames.SEP + str(LONG[i % LONG.size()])
		var r = App.rename_lift(str(l.name), to)
		if bool(r.ok):
			renamed.append(to)
			if i < 2:
				App.set_pt(to, true)
		i += 1
	await ShotHelper.wait(tree, 0.8)
	check(renamed.size() >= 2, "the planned lifts got long names (%d)" % renamed.size())
	for tab in ["home", "adventure", "journey", "armory", "log"]:
		App.go(tab)
		await ShotHelper.wait(tree, 0.9)
		await ShotHelper.snap(tree, "long_1_%s" % tab)
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	ShotHelper.scroll_main(main, 500)
	await ShotHelper.wait(tree, 0.4)
	await ShotHelper.snap(tree, "long_2_home_lower")
	App.go("journey", "lifts")
	await ShotHelper.wait(tree, 0.9)
	await ShotHelper.snap(tree, "long_3_lifts")
	App.go("journey", "history")
	await ShotHelper.wait(tree, 0.9)
	await ShotHelper.snap(tree, "long_4_history")
	# A session's detail, the lift's page (three views), the PT sheet.
	var last = null
	for s in App.sessions():
		if str(s.get("discipline", "")) == "lift" and (last == null or str(s.date) > str(last.date)):
			for e in s.get("data", s).get("exercises", []):
				if renamed.has(str(e.get("name", ""))):
					last = s
	if last != null:
		SessionView.open(last)
		await ShotHelper.wait(tree, 0.9)
		await ShotHelper.snap(tree, "long_5_session")
		await _close_sheets()
	if not renamed.is_empty():
		for view in ["compare", "progress", "logbook"]:
			JourneyLifts.open_named(str(renamed[0]), {"view": view})
			await ShotHelper.wait(tree, 0.9)
			await ShotHelper.snap(tree, "long_6_lift_%s" % view)
			await _close_sheets()
	PtView.open()
	await ShotHelper.wait(tree, 0.9)
	await ShotHelper.snap(tree, "long_7_pt")
	await _close_sheets()
	# The trophy room: a plaque is a set that was really done ("82.5 kg × 5"),
	# never an estimated one-rep max.
	TrophyRoom.open()
	await ShotHelper.wait(tree, 0.9)
	var said = ""
	for n in ShotHelper.walk(main):
		if n is Sheet:
			said = ShotHelper.all_text(n)
	check(said.contains(" × ") and not said.contains("strength"), "the trophy room's lift plaques show real sets")
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "long_7b_trophy_room")
	await _close_sheets()
	# Start the day's workout: the editor's cards carry the names too.
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	App.pending_workout = TodayView.workout_names(App.plan())
	App.open_log("lift")
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "long_8_log_lift")
	print("LONG NAMES DONE fails=%d" % fails)
