extends SceneTree
## Unit test for game/projects.gd: climbing projects.
##   godot --headless --path . --script res://tests/projects_test.gd
## Prints PROJECTS: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _climb(id: String, date: String, climbs: Array) -> Dictionary:
	return {"id": id, "date": date, "discipline": "climb", "climbs": climbs}


func _init() -> void:
	var p = Projects.new_project(5, "", "  Blue overhang ", "2026-11-01")
	ok(p.grade == 5 and p.name == "Blue overhang" and p.since == "2026-11-01" and Projects.is_open(p) and Projects.title(p) == "V5 · Blue overhang", "a new boulder project", p)
	var r = Projects.new_project(4, "5.11a", "", "2026-11-01")
	ok(Projects.grade_text(r) == "5.11a" and Projects.title(r) == "5.11a" and Projects.is_route(r), "a route project", r)
	var parsed = Projects.parse([p, {"id": 3}, "x", {"id": "a", "grade": 2.0}])
	ok(parsed.size() == 2 and parsed[0].name == "Blue overhang" and parsed[1].grade == 2 and parsed[1].sent == "", "parse keeps projects, drops the rest", parsed)

	ok(Projects.matches(p, {"grade": 5, "result": "send", "count": 1}) and not Projects.matches(p, {"grade": 6, "result": "send", "count": 1})
		and not Projects.matches(p, {"grade": 5, "result": "send", "count": 1, "style": "rope", "yds": "5.11a"}), "a boulder project matches boulders of its grade")
	ok(Projects.matches(r, {"grade": 4, "result": "send", "count": 1, "style": "rope", "yds": "5.11a"}) and not Projects.matches(r, {"grade": 4, "result": "send", "count": 1}), "a route project matches its route grade")

	var sessions = [
		_climb("s0", "2026-10-28", [{"grade": 5, "result": "attempt", "count": 4}]),   # before it was picked
		_climb("s1", "2026-11-02", [{"grade": 5, "result": "attempt", "count": 3}, {"grade": 3, "result": "send", "count": 2}]),
		_climb("s2", "2026-11-05", [{"grade": 4, "result": "send", "count": 3}]),       # not on it
		_climb("s3", "2026-11-09", [{"grade": 5, "result": "attempt", "count": 2}, {"grade": 5, "result": "send", "count": 1}]),
		{"id": "l1", "date": "2026-11-10", "discipline": "lift", "exercises": []},
	]
	var st = Projects.status(p, sessions, "2026-11-12")
	ok(st.sessions == 2 and st.tries == 5 and st.days == 11 and st.last == "2026-11-09", "progress: sessions with its grade since it was picked", st)
	ok(Projects.progress_text(st) == "2 sessions · 5 tries · 11 days", "in words", Projects.progress_text(st))
	ok(Projects.sent_in([p], sessions[3]).size() == 1 and Projects.sent_in([p], sessions[1]).is_empty() and Projects.sent_in([p], sessions[0]).is_empty(), "a send of its grade asks; a try or an old session does not")
	ok(Projects.tried_in([p], sessions[1]).size() == 1 and Projects.tried_in([p], sessions[3]).is_empty() and Projects.tried_in([p], sessions[2]).is_empty(), "a session that only tried it")
	var ls = Projects.last_send(p, sessions)
	ok(ls != null and ls.id == "s3", "the last session that sent its grade", ls)

	var sent = p.duplicate()
	sent.sent = "2026-11-09"
	sessions.append(_climb("s4", "2026-11-11", [{"grade": 5, "result": "attempt", "count": 6}]))
	var st2 = Projects.status(sent, sessions, "2026-11-20")
	ok(not Projects.is_open(sent) and st2.sessions == 2 and st2.tries == 5 and st2.days == 8, "a sent project stops counting at the send", st2)
	ok(Projects.sent_in([sent], sessions[3]).is_empty() and Projects.tried_in([sent], sessions[5]).is_empty(), "and is not asked about again")
	var aside = p.duplicate()
	aside.aside = "2026-11-10"
	ok(not Projects.is_open(aside), "a project set aside is not open")
	ok(Projects.progress_text({"sessions": 1, "tries": 1, "days": 1}) == "1 session · 1 try · 1 day" and Projects.progress_text({"sessions": 0, "tries": 0, "days": 0}) == "0 sessions · 0 days", "singular and no tries")
	print("PROJECTS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
