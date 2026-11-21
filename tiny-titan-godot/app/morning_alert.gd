class_name MorningAlert
extends RefCounted
## Today's plan on the phone in the morning, before the workout.
##
## The computer sends it: Windows Task Scheduler runs tools/morning.gd every
## morning (Settings -> Morning goals turns it on and off), which reads the
## save without changing it, works out the day's plan and missions
## (Missions.day_plan / daily / morning_text) and posts them to ntfy
## (https://ntfy.sh), a free notification relay. The phone runs the ntfy app,
## subscribed to the same topic: a long random name only this player knows.
## Nothing leaves the computer until the player turns it on. The computer has
## to be on or asleep (a sleeping one is woken), not shut down.
##
##   settings(saved_settings)   {"on", "topic", "time" ("00:00": midnight, the start of the day), "server"}
##   new_topic()                 "tinytitan-" and 12 random letters and digits
##   message(saved, today)       {"title", "text"} for the day
##   send(node, title, text, topic, server) -> await: {"ok", "code", "error"}
##   schedule(on, time)          create / remove the Windows task: {"ok", "output"}
## A tap on a push opens the phone note (`click`: the Google Doc link). The
## EVENING check (settings.morning.evening, at eveningTime; its own task,
## tools/morning.gd -- --evening) reads the note too (note_sessions: what is
## typed there today, imported or not) and sends what is still open today
## (Missions.evening_text), or nothing when there is nothing to say.

const TASK = "Tiny Titan morning goals"
const TASK_EVENING = "Tiny Titan evening check"
const DEFAULT_EVENING = "19:00"
const SERVER = "https://ntfy.sh"
const DEFAULT_TIME = "00:00"


static func settings(saved_settings: Dictionary) -> Dictionary:
	var m = saved_settings.get("morning", {})
	if not (m is Dictionary):
		m = {}
	return {"on": bool(m.get("on", false)), "topic": str(m.get("topic", "")), "time": str(m.get("time", DEFAULT_TIME)), "server": str(m.get("server", SERVER)),
		"evening": bool(m.get("evening", false)), "eveningTime": str(m.get("eveningTime", DEFAULT_EVENING)), "recap": bool(m.get("recap", true))}


## The phone note's link to open on a tap: the Google Doc's own link, or "".
static func note_link(saved: Dictionary) -> String:
	var src = str(saved.get("inbox", {}).get("source", "")).strip_edges() if saved.get("inbox") is Dictionary else ""
	return src if src.begins_with("https://docs.google.com/") else ""


## The workouts typed in the phone note for `today` (read like the game reads
## it, imported or not), as sessions. Awaitable; [] without a Google Doc.
static func note_sessions(node: Node, saved: Dictionary, today: String) -> Array:
	var src = note_link(saved)
	if src == "":
		return []
	var http = HTTPRequest.new()
	http.timeout = 30.0
	http.max_redirects = 8
	node.add_child(http)
	if http.request(PhoneInbox.fetch_url(src)) != OK:
		http.queue_free()
		return []
	var res = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return []
	var path = OS.get_temp_dir().path_join("tiny_titan_evening.zip")
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return []
	f.store_buffer(res[3])
	f.close()
	var z = ZIPReader.new()
	var html = ""
	if z.open(path) == OK:
		for name in z.get_files():
			if str(name).to_lower().ends_with(".html"):
				html = z.read_file(name).get_string_from_utf8()
				break
		z.close()
	DirAccess.remove_absolute(path)
	if html == "":
		return []
	var sessions: Array = saved.get("sessions", [])
	var names = []
	var own = []
	for x in LiftHistory.exercise_suggestions(sessions, LiftNames.defaults()):
		names.append(x.name)
		if int(x.get("count", 0)) > 0:
			own.append(x.name)
	var st = saved.get("settings", {})
	var parsed = QuickLog.parse_any(PhoneInbox.html_to_text(html), {"today": today, "weightUnit": str(st.get("weightUnit", "kg")),
		"distanceUnit": str(st.get("distanceUnit", "km")), "exercises": names, "own": own,
		"names": saved.get("inbox", {}).get("names", {}), "pt": saved.get("pt", {}) if saved.get("pt") is Dictionary else {}})
	var out = []
	for e in parsed.entries:
		if str(e.kind) == "session" and str(e.date) == today:
			var s = e.data.duplicate(true)
			s["id"] = "note-" + str(e.key)
			out.append(s)
	return out


## The evening message for `today`: {"title", "text"} ("" text: nothing to send).
static func evening_message(saved: Dictionary, today: String, from_note: Array) -> Dictionary:
	var settings = saved.get("settings", {})
	var marks = saved.get("pt", {}) if saved.get("pt") is Dictionary else {}
	var sessions = saved.get("sessions", []) + from_note
	var plan = Missions.day_plan(saved.get("sessions", []), today, marks, settings)
	var claimed = saved.get("claims", []).any(func(c): return str(c.get("questId", "")) == "t:%s:perfect" % today)
	return {"title": "Tiny Titan - this evening", "text": Missions.evening_text(plan, sessions, today, claimed)}


static func new_topic() -> String:
	var letters = "abcdefghijkmnpqrstuvwxyz23456789"
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var out = "tinytitan-"
	for i in range(12):
		out += letters[rng.randi_range(0, letters.length() - 1)]
	return out


## The state the game would show (Derive.derive of the save), without App.
static func derive(saved: Dictionary, today: String) -> Dictionary:
	var settings = saved.get("settings", {})
	return Derive.derive({
		"sessions": saved.get("sessions", []),
		"claims": saved.get("claims", []),
		"body": saved.get("body", []),
		"purchases": saved.get("purchases", []),
		"reading": saved.get("reading", []) if saved.get("reading") is Array else [],
		"weeklyGoal": int(settings.get("weeklyGoal", 3)),
		"today": today,
	})


## The morning message for `today` from a save: {"title", "text"}.
static func message(saved: Dictionary, today: String) -> Dictionary:
	var settings = saved.get("settings", {})
	var marks = saved.get("pt", {}) if saved.get("pt") is Dictionary else {}
	var data = {"sessions": saved.get("sessions", []), "pt": marks, "settings": settings,
		"reading": saved.get("reading", []) if saved.get("reading") is Array else []}
	var state = derive(saved, today)
	var plan = Missions.day_plan(data.sessions, today, marks, settings)
	var daily = Missions.daily(today, data, state, saved.get("claims", []))
	var title = "Tiny Titan - %s" % Dates.format_date(today, {"weekday": "short", "month": "short", "day": "numeric"})
	return {"title": title, "text": Missions.morning_text(plan, daily, str(settings.get("weightUnit", "kg")))}


## Post a notification to the ntfy topic. Awaitable: {"ok", "code", "error"}.
## `node`: anything in the scene tree (the request is a child of it while it runs).
static func send(node: Node, title: String, text: String, topic: String, server: String = SERVER, click: String = "") -> Dictionary:
	if topic.strip_edges() == "":
		return {"ok": false, "code": 0, "error": "No topic"}
	var http = HTTPRequest.new()
	http.timeout = 20.0
	node.add_child(http)
	# Header values must be plain ASCII: the title is kept to letters, digits and dashes.
	var headers = ["Title: %s" % title.to_ascii_buffer().get_string_from_ascii(), "Tags: muscle", "Content-Type: text/plain; charset=utf-8"]
	if click.begins_with("https://"):
		# A tap opens the phone note; a button says so.
		headers.append("Click: %s" % click)
		headers.append("Actions: view, Open note, %s" % click)
	var err = http.request("%s/%s" % [server.trim_suffix("/"), topic.strip_edges()], PackedStringArray(headers), HTTPClient.METHOD_POST, text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "error": "Could not start the request (%d)" % err}
	var res = await http.request_completed
	http.queue_free()
	var code = int(res[1])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": "No connection"}
	return {"ok": code >= 200 and code < 300, "code": code, "error": "" if code >= 200 and code < 300 else "The server said %d" % code}


## Send a picture (a PNG file) to the ntfy topic as an attachment, with a
## short message (plain ASCII: it goes in a header). Awaitable, as send.
static func send_picture(node: Node, title: String, words: String, topic: String, server: String, png_path: String, click: String = "") -> Dictionary:
	if topic.strip_edges() == "":
		return {"ok": false, "code": 0, "error": "No topic"}
	var bytes = FileAccess.get_file_as_bytes(png_path)
	if bytes.is_empty():
		return {"ok": false, "code": 0, "error": "No picture"}
	var http = HTTPRequest.new()
	http.timeout = 30.0
	node.add_child(http)
	var ascii = func(t: String) -> String: return t.to_ascii_buffer().get_string_from_ascii()
	var headers = ["Title: %s" % ascii.call(title), "Message: %s" % ascii.call(words), "Filename: tiny-titan-week.png", "Tags: trophy"]
	if click.begins_with("https://"):
		headers.append("Click: %s" % click)
	var err = http.request_raw("%s/%s" % [server.trim_suffix("/"), topic.strip_edges()], PackedStringArray(headers), HTTPClient.METHOD_PUT, bytes)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "error": "Could not start the request (%d)" % err}
	var res = await http.request_completed
	http.queue_free()
	var code = int(res[1])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": "No connection"}
	return {"ok": code >= 200 and code < 300, "code": code, "error": "" if code >= 200 and code < 300 else "The server said %d" % code}


## Create (on) or remove (off) the Windows task that runs tools/morning.gd every
## day at `time` ("07:00"). It wakes a sleeping computer and catches up after a
## missed run. {"ok", "output"}. Windows only.
static func schedule(on: bool, time: String, task: String = TASK, extra: String = "") -> Dictionary:
	if OS.get_name() != "Windows":
		return {"ok": false, "output": "Only on Windows"}
	var out = []
	var code = OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", schedule_command(on, time, task, extra)], out, true)
	var said = "\n".join(PackedStringArray(out)).strip_edges()
	return {"ok": code == 0 and said.ends_with("ok"), "output": said}


## The PowerShell that creates (on) or removes (off) the task; it prints "ok".
static func schedule_command(on: bool, time: String, task: String = TASK, extra: String = "") -> String:
	var ps = ""
	if on:
		var exe = OS.get_executable_path().replace("'", "''")
		var proj = ProjectSettings.globalize_path("res://").trim_suffix("/").replace("'", "''")
		var args = "--headless --path \"%s\" --script res://tools/morning.gd" % proj
		if extra != "":
			args += " -- " + extra
		ps = "$a = New-ScheduledTaskAction -Execute '%s' -Argument '%s'; " % [exe, args.replace("'", "''")]
		ps += "$t = New-ScheduledTaskTrigger -Daily -At '%s'; " % time
		ps += "$s = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5); "
		ps += "Register-ScheduledTask -TaskName '%s' -Action $a -Trigger $t -Settings $s -Force | Out-Null; 'ok'" % task
	else:
		ps = "Unregister-ScheduledTask -TaskName '%s' -Confirm:$false -ErrorAction SilentlyContinue; 'ok'" % task
	return ps
