extends SceneTree
## Today's plan as a notification on the phone (see app/morning_alert.gd).
## Windows Task Scheduler runs it every morning once Settings -> Morning goals
## is on; by hand:
##   godot --headless --path <project> --script res://tools/morning.gd [-- --dry-run] [-- --test]
## It reads the save (TINY_TITAN_DATA, else the game's own data folder) and
## never writes it. --dry-run prints the message instead of sending it; --test
## sends even when Morning goals is off. A run after noon sends nothing (the
## computer was off in the morning: the day has started without it).

func _initialize() -> void:
	_run()


func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var dry = args.has("--dry-run")
	var dir = OS.get_environment("TINY_TITAN_DATA")
	var path = (dir.trim_suffix("/").trim_suffix("\\") + "/save.json") if dir != "" else "user://save.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("MORNING: no save at %s" % path)
		quit(1)
		return
	var saved = JSON.parse_string(f.get_as_text())
	f.close()
	if not (saved is Dictionary):
		print("MORNING: the save could not be read")
		quit(1)
		return
	var today = Dates.today_key()
	var m = MorningAlert.settings(saved.get("settings", {}))
	var msg = MorningAlert.message(saved, today)
	print("MORNING %s\n%s" % [msg.title, msg.text])
	if dry:
		quit(0)
		return
	if not m.on and not args.has("--test"):
		print("MORNING: off in Settings, nothing sent")
		quit(0)
		return
	if Time.get_datetime_dict_from_system().hour >= 12 and not args.has("--test"):
		print("MORNING: past noon, nothing sent")
		quit(0)
		return
	# The request needs the tree running: wait for the first frame.
	await process_frame
	var res = await MorningAlert.send(root, msg.title, msg.text, m.topic, m.server)
	print("MORNING sent: %s" % JSON.stringify(res))
	quit(0 if res.ok else 1)
