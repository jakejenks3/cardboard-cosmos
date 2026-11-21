extends Node
## Scripted walkthrough runner (development tool, not part of the game).
##
##   TINY_TITAN_DATA=<empty temp dir> TINY_TITAN_SHOTS=<dir> xvfb-run -a -s "-screen 0 1280x1024x24" \
##     godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- res://tests/shots/home.gd year
##
## Arguments after "--": the scenario script, then the demo data kind
## (fresh | new | week | year; default year). A scenario is a script that
## `extends RefCounted` with `func run(main: Node, tree: SceneTree) -> void`
## (may use await); screenshots go through ShotHelper.snap.

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	var scenario_path = args[0] if args.size() > 0 else ""
	var kind = args[1] if args.size() > 1 else "year"
	if kind == "fresh":
		App.replace_all(App.empty_saved())
	else:
		App.replace_all(ShotHelper.demo_saved(kind))
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await ShotHelper.frames(get_tree(), 4)
	if scenario_path == "" or not ResourceLoader.exists(scenario_path):
		await ShotHelper.snap(get_tree(), "main")
	else:
		var scenario = load(scenario_path).new()
		await scenario.run(main, get_tree())
	print("SHOTS DONE")
	get_tree().quit()
