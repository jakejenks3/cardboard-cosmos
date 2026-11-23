class_name PhonePush
extends Node
## The morning message without a PC (the phone app). ntfy can hold a message
## and deliver it later ("delay", up to three days). So the app itself,
## whenever it is open, leaves the next mornings' plans with ntfy: tomorrow's
## and the day after's (and today's while it is still before the time).
##
## A waiting message cannot be taken back or replaced (tried on ntfy.sh,
## 2026-11-21: a second one with the same sequence id is delivered as well,
## and a DELETE does not stop it). So each morning gets ONE message, made to
## be right the first time: the plan for a coming day is worked out as if the
## days before it go as planned (`forecast`: today's lifts still to do, and
## tomorrow's, count as done on a day the player usually lifts). When the log
## then says otherwise, ONE correction goes out, a minute after the first, and
## only once the day before is settled (`settled`: a lift is logged, or it is
## evening), so it is not corrected twice.
##
## Off until the player turns it on (settings.morning.phone; the PC's own
## switch is settings.morning.on). The topic and the time are shared with the
## PC (settings.morning.topic / time): the ntfy app on the phone is subscribed
## to the topic. What was left is remembered in <data>/push.json. A child of
## App (App.push); it reaches App as its parent, so the class compiles in
## --script tests.
##
##   settings(saved_settings)                  MorningAlert.settings + "phone"
##   when(day, "07:00", bias_min)              unix time of that local time
##   lift_likely(sessions, day)                does the player usually lift on that weekday
##   forecast(saved, today, day)               the log, plus the days before `day` as planned
##   settled(saved, today, hour)               is today's part of the log final
##   jobs(saved, today, now, bias_min)         [{day, at, id, title, text}] still ahead
##   body(job, topic)                          the JSON ntfy takes at its root URL

signal status_changed

## Mornings after today that are left with ntfy (its longest delay is 3 days).
const DAYS_AHEAD = 2
## After a change, wait this long before looking again (a workout being typed).
const SETTLE_SEC = 8.0
## From this hour on, a day without a lift is taken as a day off.
const EVENING_HOUR = 20
## Same weekdays looked at for "usually lifts on this day".
const HABIT_WEEKS = 6
const FILE = "push.json"

## Why the last try failed, or "".
var error: String = ""

var _wait: float = -1.0
var _busy: bool = false
var _again: bool = false
## {day: {"sig": what was left for that morning, "at": unix time, "fixed": a correction went out}}
var _left: Dictionary = {}


static func wanted() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--phone-push-test")


static func settings(saved_settings: Dictionary) -> Dictionary:
	var m = MorningAlert.settings(saved_settings)
	var raw = saved_settings.get("morning", {})
	m["phone"] = raw is Dictionary and bool(raw.get("phone", false))
	return m


## Unix time of `time` ("07:00") on `day`, where local time is UTC + bias_min.
static func when(day: String, time: String, bias_min: int) -> int:
	return int(Time.get_unix_time_from_datetime_string("%sT%s:00" % [day, time])) - bias_min * 60


static func seq_id(day: String) -> String:
	return "tt-" + day


static func _lifted_on(sessions: Array, day: String) -> bool:
	return sessions.any(func(s): return str(s.get("discipline", "")) == "lift" and str(s.get("date", "")) == day)


## Does the player usually lift on this weekday: on half or more of the last
## HABIT_WEEKS same weekdays since their first workout (true with under two to go by).
static func lift_likely(sessions: Array, day: String) -> bool:
	return Missions.lift_habit(sessions, day)


## The sessions as they will probably be on the morning of `day`: the real
## log, plus, for each day from today up to the day before `day` that has no
## lift logged and is a day the player usually lifts, that day's planned
## lifts and PT done as last time (ids "pretend-<day>").
static func forecast(saved: Dictionary, today: String, day: String) -> Array:
	var st = saved.get("settings", {})
	var marks = saved.get("pt", {}) if saved.get("pt") is Dictionary else {}
	var real: Array = saved.get("sessions", [])
	var out = real.duplicate()
	var x = today
	while x < day:
		if not _lifted_on(out, x) and lift_likely(real, x):
			var pretend = Missions.pretend_lift(out, x, Missions.day_plan(out, x, marks, st))
			if pretend != null:
				out.append(pretend)
		x = Dates.add_days(x, 1)
	return out


## Is today's part of the log final enough to correct tomorrow's message: a
## lift is logged, or it is evening, or it is not a day the player lifts.
static func settled(saved: Dictionary, today: String, hour: int) -> bool:
	var real: Array = saved.get("sessions", [])
	return _lifted_on(real, today) or hour >= EVENING_HOUR or not lift_likely(real, today)


## The mornings to leave with ntfy now, the ones still ahead: today's (before
## its time) and the next DAYS_AHEAD days'.
static func jobs(saved: Dictionary, today: String, now_unix: int, bias_min: int) -> Array:
	var st = saved.get("settings", {})
	var m = settings(st)
	var marks = saved.get("pt", {}) if saved.get("pt") is Dictionary else {}
	var out = []
	for d in range(DAYS_AHEAD + 1):
		var day = Dates.add_days(today, d)
		var at = when(day, str(m.time), bias_min)
		if at < now_unix + 60:
			continue
		var plan = Missions.day_plan(forecast(saved, today, day), day, marks, st)
		out.append({"day": day, "at": at, "id": seq_id(day),
			"title": "Tiny Titan - %s" % Dates.format_date(day, {"weekday": "short", "month": "short", "day": "numeric"}),
			"text": Missions.morning_text(plan, [], str(st.get("weightUnit", "kg")), str(st.get("distanceUnit", "km")))})
	return out


## What ntfy takes at its root URL. With `at`, it is held until then. The
## sequence id lets an ntfy app that knows them show a correction in place of
## the first message.
static func body(job: Dictionary, topic: String) -> String:
	var b = {"topic": topic, "title": str(job.title), "message": str(job.text), "tags": ["muscle"]}
	if str(job.get("id", "")) != "":
		b["sequence_id"] = str(job.id)
	if int(job.get("at", 0)) > 0:
		b["delay"] = str(int(job.at))
	return JSON.stringify(b)


static func sig_of(job: Dictionary, topic: String) -> String:
	return (str(job.text) + "|" + topic).md5_text()


## What to send for `job` given what was left before (`left`: the entry of its
## day, or null): "first", "fix" (one correction, for today or tomorrow, once
## the day before is settled) or "" (nothing).
static func action(job: Dictionary, left, sig: String, today: String, is_settled: bool) -> String:
	if left == null:
		return "first"
	if str(left.get("sig", "")) == sig or bool(left.get("fixed", false)):
		return ""
	if str(job.day) == today or (str(job.day) == Dates.add_days(today, 1) and is_settled):
		return "fix"
	return ""


func _app():
	return get_parent()


func _ready() -> void:
	var raw = null
	if FileAccess.file_exists(_app().DATA_DIR + FILE):
		raw = JSON.parse_string(FileAccess.get_file_as_string(_app().DATA_DIR + FILE))
	if raw is Dictionary:
		for day in raw:
			if raw[day] is Dictionary:
				_left[str(day)] = {"sig": str(raw[day].get("sig", "")), "at": int(raw[day].get("at", 0)), "fixed": bool(raw[day].get("fixed", false))}
	if wanted():
		_app().changed.connect(touch)
		_wait = 4.0
	else:
		set_process(false)


## Something changed: look again in a moment.
func touch() -> void:
	_wait = SETTLE_SEC


func _process(delta: float) -> void:
	if _wait < 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = -1.0
		run()


## Local time is UTC plus this many minutes.
func bias_min() -> int:
	if OS.has_feature("web"):
		# The browser's answer is the other way round (UTC minus local).
		return -int(JavaScriptBridge.eval("new Date().getTimezoneOffset()"))
	return int(Time.get_time_zone_from_system().bias)


func _hour() -> int:
	if OS.has_feature("web"):
		return int(JavaScriptBridge.eval("new Date().getHours()"))
	return int(Time.get_datetime_dict_from_system().hour)


func _store() -> void:
	var f = FileAccess.open(_app().DATA_DIR + FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_left))
		f.close()


## The mornings waiting at ntfy now, soonest first: [{day, at}].
func waiting() -> Array:
	var now = int(Time.get_unix_time_from_system())
	var out = []
	for day in _left:
		if int(_left[day].at) > now:
			out.append({"day": str(day), "at": int(_left[day].at)})
	out.sort_custom(func(a, b): return int(a.at) < int(b.at))
	return out


func waiting_days() -> String:
	var days = []
	for one in waiting():
		days.append(Dates.format_date(str(one.day), {"weekday": "short"}))
	return ", ".join(PackedStringArray(days))


## One line for Settings.
func status_text() -> String:
	var m = settings(_app().saved.get("settings", {}))
	if not bool(m.phone):
		var w = waiting_days()
		return "Off" if w == "" else "Off. Already on their way: %s" % w
	if error != "":
		return "Could not reach ntfy (%s). It tries again when the app is next open." % error
	if waiting().is_empty():
		return "Nothing is waiting yet"
	return "Waiting to be sent: %s" % waiting_days()


## Leave the coming mornings with ntfy: the ones not left yet, and a
## correction where one is due.
func run() -> void:
	if _busy:
		_again = true
		return
	var saved = _app().saved
	var m = settings(saved.get("settings", {}))
	if not bool(m.phone) or str(m.topic) == "":
		return
	_busy = true
	var now = int(Time.get_unix_time_from_system())
	var today = str(_app().today)
	var is_settled = settled(saved, today, _hour())
	var failed = ""
	for j in jobs(saved, today, now, bias_min()):
		var sig = sig_of(j, str(m.topic))
		var what = action(j, _left.get(j.day), sig, today, is_settled)
		if what == "":
			continue
		var send = j.duplicate()
		if what == "fix":
			# After the first one, and said to be the newer of the two.
			send["at"] = maxi(int(_left[j.day].at), int(j.at)) + 60
			send["title"] = str(j.title) + " (updated)"
		var res = await post(str(m.server), "/", body(send, str(m.topic)))
		if not is_inside_tree():
			return
		if not bool(res.ok):
			failed = str(res.error)
			break
		_left[j.day] = {"sig": sig, "at": int(send.at), "fixed": what == "fix"}
	for day in _left.keys():
		if int(_left[day].at) < now - 86400:
			_left.erase(day)
	_store()
	error = failed
	_busy = false
	status_changed.emit()
	if _again:
		_again = false
		touch()


## Today's plan, now (the test key in Settings). Awaitable: {"ok", "code", "error"}.
func send_test() -> Dictionary:
	var saved = _app().saved
	var st = saved.get("settings", {})
	var m = settings(st)
	var marks = saved.get("pt", {}) if saved.get("pt") is Dictionary else {}
	var plan = Missions.day_plan(saved.get("sessions", []), _app().today, marks, st)
	var job = {"title": "Tiny Titan - test", "text": Missions.morning_text(plan, [], str(st.get("weightUnit", "kg")), str(st.get("distanceUnit", "km")))}
	return await post(str(m.server), "/", body(job, str(m.topic)))


## One request to the ntfy server: {"ok", "code", "error"}. No headers of its
## own, so a browser sends it without asking the server first.
func post(server: String, path: String, text: String, method: int = HTTPClient.METHOD_POST) -> Dictionary:
	var http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err = http.request(server.trim_suffix("/") + path, PackedStringArray(), method, text)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "error": "could not start (%d)" % err}
	var res = await http.request_completed
	http.queue_free()
	var code = int(res[1])
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": "no connection"}
	return {"ok": code >= 200 and code < 300, "code": code, "error": "" if code >= 200 and code < 300 else "the server said %d" % code}
