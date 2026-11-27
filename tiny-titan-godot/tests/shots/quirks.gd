extends RefCounted
## Chase trophies on the Trophies tab: add a five-by-five + big-three lift and an
## exact 5 km run to the demo data, open Adventure → Trophies, filter to
## Lifting and save screenshots. Run with "week" data.

var main: Node
var tree: SceneTree


func exact_button(text: String):
	for n in ShotHelper.walk(main):
		if n is Button and n.text == text:
			return n
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	var data = App.saved.duplicate(true)
	var sets = []
	for i in range(5):
		sets.append({"reps": 5, "weightKg": 100.0})
	data.sessions.append({"id": "quirks_lift", "discipline": "lift", "date": App.today, "createdAt": App.now_ms(), "source": "manual", "exercises": [
		{"name": "Squat", "sets": sets},
		{"name": "Bench Press", "sets": [{"reps": 5, "weightKg": 60.0}, {"reps": 5, "weightKg": 70.0}, {"reps": 5, "weightKg": 80.0}, {"reps": 5, "weightKg": 70.0}, {"reps": 8, "weightKg": 60.0}]},
		{"name": "Deadlift", "sets": [{"reps": 13, "weightKg": 100.0}]},
	]})
	data.sessions.append({"id": "quirks_run", "discipline": "run", "date": App.today, "createdAt": App.now_ms() + 1, "source": "manual", "distanceM": 5000.0, "elevationM": 0, "durationSec": 1500})
	App.replace_all(data)
	await ShotHelper.frames(tree, 4)
	print("quirks: ", JSON.stringify(App.state.quirks))
	App.go("adventure", "trophies")
	await ShotHelper.wait(tree, 1.2)
	var chip = exact_button("Lifting")
	if chip != null:
		ShotHelper.press(chip)
	await ShotHelper.wait(tree, 1.0)
	ShotHelper.scroll_main(main, 300)
	await ShotHelper.snap(tree, "quirks_01_lifting")
	ShotHelper.scroll_main(main, 1000)
	await ShotHelper.snap(tree, "quirks_02_lifting_b")
	var chip2 = exact_button("General")
	if chip2 != null:
		ShotHelper.press(chip2)
	await ShotHelper.wait(tree, 1.0)
	ShotHelper.scroll_main(main, 300)
	await ShotHelper.snap(tree, "quirks_03_general")
