extends SceneTree
## Today's plan as a notification on the phone (see app/morning_alert.gd).
## Windows Task Scheduler runs it every morning once Settings -> Morning goals
## is on; by hand:
##   godot --headless --path <project> --script res://tools/morning.gd [-- --dry-run] [-- --test]
## It reads the save (TINY_TITAN_DATA, else the game's own data folder) and
## never writes it. --dry-run prints the message instead of sending it; --test
## sends even when Morning goals is off. A run after noon sends nothing (the
## computer was off in the morning: the day has started without it).
## When the note's table can be cleared (Settings -> Phone inbox, script
## version 2) and "Write the day's plan" is on, the day's plan goes into the
## table first (DocClear.send_plan) and the message says so.
## When the save is shared with the phone app (Settings -> Phone app), what the
## phone logged counts too: the copy in the note's script is merged with the
## save in memory (app/cloud_sync.gd, SaveMerge), still without writing it.

func _initialize() -> void:
	_run()


func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var dry = args.has("--dry-run")
	if args.has("--evening"):
		await _evening(args, dry)
		return
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
	# The request needs the tree running: wait for the first frame.
	await process_frame
	saved = await _with_phone(saved, dir)
	var today = Dates.today_key()
	var m = MorningAlert.settings(saved.get("settings", {}))
	var msg = MorningAlert.message(saved, today)
	var c = saved.get("inbox", {}).get("clear", {}) if saved.get("inbox") is Dictionary else {}
	var write_plan = c is Dictionary and DocClear.looks_right(str(c.get("url", ""))) and str(c.get("token", "")) != "" and bool(c.get("plan", true))
	var plan = {}
	if write_plan:
		var st = saved.get("settings", {})
		plan = Missions.day_plan(saved.get("sessions", []), today, saved.get("pt", {}) if saved.get("pt") is Dictionary else {}, st)
	print("MORNING %s\n%s" % [msg.title, msg.text])
	if dry:
		if write_plan:
			print("PLAN ROWS %s" % JSON.stringify(DocClear.plan_rows(plan, str(saved.get("settings", {}).get("weightUnit", "kg")))))
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
	if write_plan:
		var wrote = await DocClear.send_plan(root, str(c.url), str(c.token), plan, str(saved.get("settings", {}).get("weightUnit", "kg")),
			DocClear.plan_info(plan, saved.get("sessions", []), saved.get("settings", {})))
		print("MORNING plan in the note: %s" % JSON.stringify(wrote))
		if wrote.ok and int(wrote.get("planned", 0)) > 0:
			msg.text += "\nToday's plan is in your note: type the reps."
	# (no "How do you feel?" buttons any more, 2026-11-24: the player asked for
	# the question to go; a feeling already kept stays where it is)
	var res = await MorningAlert.send(root, msg.title, msg.text, m.topic, m.server, MorningAlert.note_link(saved), MorningAlert.logger_link(saved), "")
	print("MORNING sent: %s" % JSON.stringify(res))
	quit(0 if res.ok else 1)


## The evening check (-- --evening): what is still open today, from the save
## and what is typed in the note; nothing when there is nothing to say, when
## it is off, or before noon.
func _evening(args: Array, dry: bool) -> void:
	var dir = OS.get_environment("TINY_TITAN_DATA")
	var path = (dir.trim_suffix("/").trim_suffix("\\") + "/save.json") if dir != "" else "user://save.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("EVENING: no save at %s" % path)
		quit(1)
		return
	var saved = JSON.parse_string(f.get_as_text())
	f.close()
	if not (saved is Dictionary):
		quit(1)
		return
	await process_frame
	saved = await _with_phone(saved, dir)
	var today = Dates.today_key()
	var m = MorningAlert.settings(saved.get("settings", {}))
	var from_note = await MorningAlert.note_sessions(root, saved, today)
	var msg = MorningAlert.evening_message(saved, today, from_note)
	print("EVENING %s (%d from the note)\n%s" % [msg.title, from_note.size(), msg.text if msg.text != "" else "(nothing to send)"])
	if dry or msg.text == "":
		quit(0)
		return
	if not m.evening and not args.has("--test"):
		print("EVENING: off in Settings, nothing sent")
		quit(0)
		return
	if Time.get_datetime_dict_from_system().hour < 12 and not args.has("--test"):
		print("EVENING: before noon, nothing sent")
		quit(0)
		return
	var res = await MorningAlert.send(root, msg.title, msg.text, m.topic, m.server, MorningAlert.note_link(saved), MorningAlert.logger_link(saved))
	print("EVENING sent: %s" % JSON.stringify(res))
	quit(0 if res.ok else 1)


## The save with the phone app's changes merged in, when the save is shared
## (sync.json next to it says so). In memory only; on any trouble, the save as it is.
func _with_phone(saved: Dictionary, dir: String) -> Dictionary:
	var folder = (dir.trim_suffix("/").trim_suffix("\\") + "/") if dir != "" else "user://"
	var cfg = _read_json(folder + "sync.json")
	if not (cfg is Dictionary) or not bool(cfg.get("on", false)):
		return saved
	var url = str(cfg.get("url", ""))
	var token = str(cfg.get("token", ""))
	if url == "":
		var cl = saved.get("inbox", {}).get("clear", {}) if saved.get("inbox") is Dictionary else {}
		if cl is Dictionary:
			url = str(cl.get("url", ""))
			token = str(cl.get("token", ""))
	if url == "" or token == "":
		return saved
	var req = HTTPRequest.new()
	req.timeout = 25.0
	root.add_child(req)
	if req.request(url + ("&" if url.contains("?") else "?") + "token=" + token.uri_encode() + "&save=get") != OK:
		req.queue_free()
		return saved
	var r = await req.request_completed
	req.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS or int(r[1]) != 200:
		return saved
	var got = JSON.parse_string(PackedByteArray(r[3]).get_string_from_utf8())
	if not (got is Dictionary) or int(got.get("rev", 0)) <= 0 or int(got.rev) == int(cfg.get("rev", 0)):
		return saved
	var theirs = CloudSync.decode(str(got.get("data", "")))
	if not (theirs is Dictionary):
		return saved
	var base = _read_json(folder + "sync_base.json")
	print("MORNING: with the phone app's changes (copy %d)" % int(got.rev))
	return SaveMerge.merge(base if base is Dictionary else {}, saved, theirs)


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
