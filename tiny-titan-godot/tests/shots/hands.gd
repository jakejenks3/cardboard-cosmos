extends RefCounted
## Card-hand trophies on the Trophies tab: add one big boulder session to the
## demo data (a straight flush V1-V5, a pair of V5s), open Adventure → Trophies,
## filter to Climbing, and save screenshots. Run with "week" data.

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
	var cs = []
	for g in range(1, 6):
		cs.append({"grade": g, "result": "flash", "count": 2 if g == 5 else 1})
	cs.append({"grade": 3, "result": "send", "count": 2})
	data.sessions.append({"id": "hands_demo", "discipline": "climb", "date": App.today, "createdAt": App.now_ms(), "source": "manual", "durationSec": 3600, "climbs": cs})
	App.replace_all(data)
	await ShotHelper.frames(tree, 4)
	print("hands: ", JSON.stringify(App.state.hands))
	App.go("adventure", "trophies")
	await ShotHelper.wait(tree, 1.2)
	var chip = exact_button("Climbing")
	if chip != null:
		ShotHelper.press(chip)
	await ShotHelper.wait(tree, 1.0)
	ShotHelper.scroll_main(main, 300)
	await ShotHelper.snap(tree, "hands_01_trophies")
	ShotHelper.scroll_main(main, 1000)
	await ShotHelper.snap(tree, "hands_02_trophies_b")
	ShotHelper.scroll_main(main, 1700)
	await ShotHelper.snap(tree, "hands_03_trophies_c")
