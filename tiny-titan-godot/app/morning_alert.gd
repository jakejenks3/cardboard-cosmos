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
##   settings(saved_settings)   {"on", "topic", "time" ("07:00"), "server"}
##   new_topic()                 "tinytitan-" and 12 random letters and digits
##   message(saved, today)       {"title", "text"} for the day
##   send(node, title, text, topic, server) -> await: {"ok", "code", "error"}
##   schedule(on, time)          create / remove the Windows task: {"ok", "output"}

const TASK = "Tiny Titan morning goals"
const SERVER = "https://ntfy.sh"
const DEFAULT_TIME = "07:00"


static func settings(saved_settings: Dictionary) -> Dictionary:
	var m = saved_settings.get("morning", {})
	if not (m is Dictionary):
		m = {}
	return {"on": bool(m.get("on", false)), "topic": str(m.get("topic", "")), "time": str(m.get("time", DEFAULT_TIME)), "server": str(m.get("server", SERVER))}


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
	var plan = Missions.day_plan(data.sessions, today, marks)
	var daily = Missions.daily(today, data, state, saved.get("claims", []))
	var title = "Tiny Titan - %s" % Dates.format_date(today, {"weekday": "short", "month": "short", "day": "numeric"})
	return {"title": title, "text": Missions.morning_text(plan, daily, str(settings.get("weightUnit", "kg")))}


## Post a notification to the ntfy topic. Awaitable: {"ok", "code", "error"}.
## `node`: anything in the scene tree (the request is a child of it while it runs).
static func send(node: Node, title: String, text: String, topic: String, server: String = SERVER) -> Dictionary:
	if topic.strip_edges() == "":
		return {"ok": false, "code": 0, "error": "No topic"}
	var http = HTTPRequest.new()
	http.timeout = 20.0
	node.add_child(http)
	# Header values must be plain ASCII: the title is kept to letters, digits and dashes.
	var headers = ["Title: %s" % title.to_ascii_buffer().get_string_from_ascii(), "Tags: muscle", "Content-Type: text/plain; charset=utf-8"]
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


## Create (on) or remove (off) the Windows task that runs tools/morning.gd every
## day at `time` ("07:00"). It wakes a sleeping computer and catches up after a
## missed run. {"ok", "output"}. Windows only.
static func schedule(on: bool, time: String) -> Dictionary:
	if OS.get_name() != "Windows":
		return {"ok": false, "output": "Only on Windows"}
	var out = []
	var code = OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", schedule_command(on, time)], out, true)
	var said = "\n".join(PackedStringArray(out)).strip_edges()
	return {"ok": code == 0 and said.ends_with("ok"), "output": said}


## The PowerShell that creates (on) or removes (off) the task; it prints "ok".
static func schedule_command(on: bool, time: String) -> String:
	var ps = ""
	if on:
		var exe = OS.get_executable_path().replace("'", "''")
		var proj = ProjectSettings.globalize_path("res://").trim_suffix("/").replace("'", "''")
		var args = "--headless --path \"%s\" --script res://tools/morning.gd" % proj
		ps = "$a = New-ScheduledTaskAction -Execute '%s' -Argument '%s'; " % [exe, args.replace("'", "''")]
		ps += "$t = New-ScheduledTaskTrigger -Daily -At '%s'; " % time
		ps += "$s = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5); "
		ps += "Register-ScheduledTask -TaskName '%s' -Action $a -Trigger $t -Settings $s -Force | Out-Null; 'ok'" % TASK
	else:
		ps = "Unregister-ScheduledTask -TaskName '%s' -Confirm:$false -ErrorAction SilentlyContinue; 'ok'" % TASK
	return ps
