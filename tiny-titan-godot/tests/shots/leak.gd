extends RefCounted
## Opens one screen (named by the TT_LEAK environment variable) and returns, so
## the run can be checked for objects still alive at exit.

func run(main: Node, tree: SceneTree) -> void:
	var what = OS.get_environment("TT_LEAK")
	if what.begins_with("res://"):
		var scr = load(what)
		print("loaded ", scr)
		scr = null
	match what:
		"home":
			pass
		"picker":
			App.open_log(null)
		"lift", "climb", "run", "ride", "body":
			App.open_log(what)
		"edit":
			App.open_log("lift", App.sessions()[0].id)
		"campaign", "quests", "trophies":
			App.go("adventure", what)
		"stats", "chronicle", "history":
			App.go("journey", what)
		"jbody":
			App.go("journey", "body")
		"armory":
			App.go("armory")
		"settings":
			load("res://ui/screens/settings.gd").open()
		"reel":
			App.commit_sessions([App.build_session({"discipline": "run", "date": App.today, "distanceM": 5000, "elevationM": 20, "durationSec": 1500})], "Run logged!")
	await ShotHelper.wait(tree, 1.5)
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
