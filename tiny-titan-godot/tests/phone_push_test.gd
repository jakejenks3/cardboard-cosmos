extends SceneTree
## Unit test for the pure part of app/phone_push.gd: the morning message the
## phone app leaves with ntfy (when it is due, the plan as if the days before
## go as planned, one message a morning and at most one correction).
##   godot --headless --path . --script res://tests/phone_push_test.gd
## Prints PHONE PUSH: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


const PULL = [["Lat Pulldown", 10, 50.0], ["Row - Barbell", 8, 60.0], ["Bicep Curl - Dumbbell", 12, 12.0]]
const PUSH = [["Bench Press - Barbell", 5, 80.0], ["Overhead Press - Barbell", 8, 40.0], ["Tricep Pushdown", 12, 25.0]]
const LEGS = [["Squat - Barbell", 5, 100.0], ["Leg Press", 10, 150.0], ["Calf Raise", 15, 60.0]]


func _session(day: String, rows: Array, n: int) -> Dictionary:
	var ex = []
	for r in rows:
		ex.append({"name": r[0], "sets": [{"reps": r[1], "weightKg": r[2]}, {"reps": r[1], "weightKg": r[2]}, {"reps": r[1], "weightKg": r[2]}]})
	return {"id": "s%d" % n, "discipline": "lift", "date": day, "createdAt": 1000 * n, "source": "manual", "exercises": ex}


## Six weeks of pull, push, legs on Monday to Saturday (Sunday off), up to the day before `today`.
func _log(today: String) -> Array:
	var out = []
	var kinds = [PULL, PUSH, LEGS]
	var k = 0
	var n = 0
	for back in range(42, 0, -1):
		var day = Dates.add_days(today, -back)
		if Dates.weekday_index(day) == Dates.weekday_index("2026-11-22"):
			continue
		out.append(_session(day, kinds[k % 3], n))
		k += 1
		n += 1
	return out


func _saved(today: String, time: String = "07:00") -> Dictionary:
	return {"sessions": _log(today), "pt": {}, "settings": {"weightUnit": "kg", "split": "pull_push_legs",
		"morning": {"phone": true, "topic": "tinytitan-madeuptopic", "time": time}}}


func _init() -> void:
	# --- when ---------------------------------------------------------------
	var utc7 = int(Time.get_unix_time_from_datetime_string("2026-11-23T07:00:00"))
	ok(PhonePush.when("2026-11-23", "07:00", 0) == utc7, "07:00 where local time is UTC")
	ok(PhonePush.when("2026-11-23", "07:00", -420) == utc7 + 7 * 3600, "07:00 seven hours behind UTC is 14:00 UTC")
	ok(PhonePush.when("2026-11-23", "00:00", 60) == utc7 - 8 * 3600, "midnight one hour ahead of UTC is 23:00 UTC the day before")
	ok(PhonePush.seq_id("2026-11-23") == "tt-2026-11-23", "the id of a morning")

	# --- settings -----------------------------------------------------------
	var st = PhonePush.settings({"morning": {"on": true, "topic": "t", "time": "06:30"}})
	ok(not bool(st.phone) and bool(st.on) and str(st.time) == "06:30", "the PC's switch is not the phone's", st)
	ok(bool(PhonePush.settings({"morning": {"phone": true}}).phone) and not bool(PhonePush.settings({}).phone), "the phone's switch, off to start with")

	# --- a Monday after a Sunday off ----------------------------------------
	var mon = "2026-11-23"
	var sun = "2026-11-22"
	var saved = _saved(mon)
	ok(Dates.weekday_index(mon) != Dates.weekday_index(sun), "the test's days")
	var marks = {}
	var plan_today = Missions.day_plan(saved.sessions, mon, marks, saved.settings)
	var plan_tom_plain = Missions.day_plan(saved.sessions, Dates.add_days(mon, 1), marks, saved.settings)
	var fc = PhonePush.forecast(saved, mon, Dates.add_days(mon, 1))
	var pretend = fc.filter(func(s): return str(s.id).begins_with("pretend-"))
	ok(pretend.size() == 1 and str(pretend[0].date) == mon and not pretend[0].exercises.is_empty(), "tomorrow is planned as if today's lifts were done", pretend.map(func(s): return s.date))
	var plan_tom = Missions.day_plan(fc, Dates.add_days(mon, 1), marks, saved.settings)
	ok(str(plan_today.kind) != "" and str(plan_tom.kind) != str(plan_today.kind) and str(plan_tom_plain.kind) == str(plan_today.kind), "so tomorrow is the next kind of the split, not today's again", [plan_today.kind, plan_tom.kind, plan_tom_plain.kind])
	ok(PhonePush.forecast(saved, mon, mon).size() == saved.sessions.size(), "today's own plan is from the real log alone")
	var fc2 = PhonePush.forecast(saved, mon, Dates.add_days(mon, 2))
	var plan_d2 = Missions.day_plan(fc2, Dates.add_days(mon, 2), marks, saved.settings)
	ok(fc2.filter(func(s): return str(s.id).begins_with("pretend-")).size() == 2 and str(plan_d2.kind) != str(plan_tom.kind) and str(plan_d2.kind) != str(plan_today.kind), "the day after: two days as planned, the third kind", [plan_today.kind, plan_tom.kind, plan_d2.kind])

	# --- jobs ---------------------------------------------------------------
	var six = PhonePush.when(mon, "06:00", 0)
	var j = PhonePush.jobs(saved, mon, six, 0)
	ok(j.size() == 3 and str(j[0].day) == mon and int(j[0].at) == PhonePush.when(mon, "07:00", 0), "before the time: today's, tomorrow's and the day after's", j.map(func(x): return x.day))
	var noon = PhonePush.when(mon, "12:00", 0)
	j = PhonePush.jobs(saved, mon, noon, 0)
	ok(j.size() == 2 and str(j[0].day) == Dates.add_days(mon, 1) and str(j[1].day) == Dates.add_days(mon, 2), "after it: tomorrow's and the day after's", j.map(func(x): return x.day))
	ok(str(j[0].text).contains(str(Missions.KIND_NAMES[plan_tom.kind])) or str(j[0].text).to_lower().contains(str(Missions.KIND_NAMES[plan_tom.kind]).to_lower()), "tomorrow's message names tomorrow's kind of day", j[0].text)
	ok(str(j[0].title).begins_with("Tiny Titan - ") and str(j[0].id) == "tt-" + Dates.add_days(mon, 1), "its title and id", [j[0].title, j[0].id])
	var b = JSON.parse_string(PhonePush.body(j[0], "tinytitan-madeuptopic"))
	ok(b is Dictionary and str(b.topic) == "tinytitan-madeuptopic" and str(b.delay) == str(int(j[0].at)) and str(b.sequence_id) == str(j[0].id) and str(b.message) == str(j[0].text), "the body ntfy gets: topic, delay, id, message", b)
	ok(not JSON.parse_string(PhonePush.body({"title": "t", "text": "x"}, "tt")).has("delay"), "a test message is not held")

	# Doing today's plan for real changes nothing in tomorrow's message.
	var real = saved.duplicate(true)
	var done = pretend[0].duplicate(true)
	done["id"] = "real-today"
	real.sessions.append(done)
	var j_real = PhonePush.jobs(real, mon, noon, 0)
	ok(str(j_real[0].text) == str(j[0].text) and PhonePush.sig_of(j_real[0], "t") == PhonePush.sig_of(j[0], "t"), "the day done as planned: tomorrow's message is the same, nothing is sent again", [j[0].text, j_real[0].text])
	# Another kind of day instead: tomorrow's message differs.
	var other = saved.duplicate(true)
	var kinds = {"pull": PULL, "push": PUSH, "legs": LEGS}
	other.sessions.append(_session(mon, kinds[str(plan_tom.kind)], 900))
	var j_other = PhonePush.jobs(other, mon, noon, 0)
	ok(str(j_other[0].text) != str(j[0].text), "another kind of day done instead: tomorrow's message changes")

	# --- one message, one correction -----------------------------------------
	var tom = Dates.add_days(mon, 1)
	var left = {"sig": PhonePush.sig_of(j[0], "t"), "at": int(j[0].at), "fixed": false}
	ok(PhonePush.action(j[0], null, "a", mon, false) == "first", "a morning not left yet: send it")
	ok(PhonePush.action(j[0], left, str(left.sig), mon, true) == "", "the same text again: nothing")
	ok(PhonePush.action(j_other[0], left, "other", mon, false) == "", "a changed plan while today is still open: wait")
	ok(PhonePush.action(j_other[0], left, "other", mon, true) == "fix", "once today is settled: one correction")
	var fixed = {"sig": "other", "at": 1, "fixed": true}
	ok(PhonePush.action(j[0], fixed, "third", mon, true) == "", "never a second correction")
	ok(PhonePush.action(j[1], left, "other", mon, true) == "", "the day after tomorrow is not corrected yet")
	ok(PhonePush.action({"day": mon}, left, "other", mon, false) == "fix", "today's own message, still ahead: corrected at once")
	ok(tom == "2026-11-24", "the test's tomorrow")

	# --- settled --------------------------------------------------------------
	ok(not PhonePush.settled(saved, mon, 12) and PhonePush.settled(saved, mon, 20), "a lift day is open until the evening")
	ok(PhonePush.settled(real, mon, 12), "or until a lift is logged")
	# Every day is planned as a lift day, a Sunday this player never lifted on too.
	var on_sun = _saved(sun)
	ok(not PhonePush.settled(on_sun, sun, 9) and PhonePush.forecast(on_sun, sun, Dates.add_days(sun, 1)).size() == on_sun.sessions.size() + 1, "a weekday never lifted on is planned like any other")
	# A day the player called a rest day is settled from the start, nothing is
	# pretended on it, and the day after has its lifts.
	var rested = _saved(mon)
	rested.settings["dayCalls"] = {mon: "rest"}
	var fc_rest = PhonePush.forecast(rested, mon, tom)
	ok(PhonePush.settled(rested, mon, 9) and fc_rest.size() == rested.sessions.size(), "a day called rest is settled from the start, and nothing is pretended on it")
	ok(str(Missions.day_plan(fc_rest, tom, marks, rested.settings).kind) == str(plan_today.kind) and str(PhonePush.jobs(rested, mon, noon, 0)[0].text) != str(j[0].text), "tomorrow's message then has today's kind of day")
	print("PHONE PUSH: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
