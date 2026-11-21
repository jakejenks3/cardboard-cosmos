extends SceneTree
## Unit test for app/doc_clear.gd: which rows of the phone note's table are
## emptied after an import, and (when Node.js is installed) the doc script
## itself, run by tests/doc_clear_stub.js against a pretend doc. Made-up data.
##   godot --headless --path . --script res://tests/doc_clear_test.gd
## Prints DOCCLEAR: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-21"
const HEAD = ["Exercise", "Variation", "Weight", "Set 1", "Set 2", "Notes"]

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## The pretend doc: one table, as Google Docs holds its cells.
func doc_rows() -> Array:
	return [
		HEAD,
		["11/18", "", "", "", "", ""],
		["goblet squat", "", "20", "10", "10", ""],
		["", "", "24", "8", "", ""],
		["hammer curl", "", "12", "10", "10", "don’t swing – slow"],
		["", "", "", "", "", ""],
		["11/19", "", "", "", "", ""],
		["calf raise", "", "40", "15", "15", ""],
		["11/21", "", "", "", "", ""],
		["lateral raise", "dumbbell", "8", "12", "", ""],
		["face pull", "", "", "", "", ""],
		["", "", "", "", "", ""],
	]


## Google's export of a doc: the table as HTML, characters as codes, a typed line after it.
func export_html(rows: Array) -> String:
	var codes = {"&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", "’": "&rsquo;", "–": "&ndash;", "”": "&rdquo;"}
	var h = "<html><head><style>p{}</style></head><body><p><span># one exercise per row</span></p><table><tbody>"
	for r in rows:
		h += "<tr>"
		for c in r:
			var t = str(c)
			for k in codes:
				t = t.replace(k, codes[k]) if k != "&" else t
			h += "<td class=\"c1\"><p class=\"c2\"><span class=\"c3\">%s</span></p></td>" % t
		h += "</tr>"
	return h + "</tbody></table><p><span>read 10 pages</span></p></body></html>"


func parse(html: String) -> Dictionary:
	return QuickLog.parse_any(PhoneInbox.html_to_text(html), {"today": TODAY, "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES})


## Imported: the lift entries of these days.
func imported_on(entries: Array, days: Array) -> Dictionary:
	var out = {}
	for e in entries:
		if str(e.kind) == "session" and days.has(str(e.date)):
			out[e.key] = int(out.get(e.key, 0)) + 1
	return out


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var rows = doc_rows()
	var html = export_html(rows)
	var tables = DocClear.table_rows(html)
	ok(tables.size() == 1 and tables[0].size() == rows.size() and tables[0][4][5] == "don’t swing – slow", "the export's table read back cell by cell, codes decoded", tables[0][4] if not tables.is_empty() else null)
	ok(DocClear.row_text(rows[4]) == "hammer curl | 12 | 10 | 10 | don’t swing – slow" and DocClear.row_text(["", " a  b ", "x|y", "---"]) == "a b | x/y", "a row's text: filled cells, lower case, spaces collapsed")
	var parsed = parse(html)
	var by_day = {}
	for e in parsed.entries:
		by_day[str(e.date)] = str(e.kind)
	ok(by_day.has("2026-11-18") and by_day.has("2026-11-19") and by_day.has("2026-11-21"), "three days in the note", by_day)
	var imported = imported_on(parsed.entries, ["2026-11-18", TODAY])
	var plan = DocClear.plan(tables, parsed.entries, imported, TODAY)
	var going = plan.map(func(p): return int(p.r))
	ok(going == [1, 2, 3, 4, 9], "imported rows go (with the 11/18 date row, all done); 11/19 not imported stays; today's date row stays; a row not read stays; the header stays", going)
	ok(plan.all(func(p): return int(p.t) == 0 and str(p.h).length() == 10 and str(p.h) == DocClear.row_hash(rows[int(p.r)])), "each row sent with its table, row and hash")

	# The same text in a row that is in and one that is not: neither goes.
	var twice = doc_rows()
	twice.insert(8, ["", "", "24", "8", "", ""])
	var tparsed = parse(export_html(twice))
	var tplan = DocClear.plan(DocClear.table_rows(export_html(twice)), tparsed.entries, imported_on(tparsed.entries, ["2026-11-18", TODAY]), TODAY)
	ok(not tplan.any(func(p): return str(p.text) == "24 | 8") and not tplan.any(func(p): return int(p.r) == 1), "a row also in an entry not imported stays (and so does its date row)", tplan.map(func(p): return [p.r, p.text]))
	ok(DocClear.plan(tables, parsed.entries, {}, TODAY).is_empty(), "nothing imported: nothing goes")

	var url = DocClear.request_url("https://script.google.com/macros/s/X/exec", "tok", plan)
	ok(url.begins_with("https://script.google.com/macros/s/X/exec?token=tok&rows=0.1.") and url.contains("%2C0.2."), "the request: token and rows", url)
	ok(DocClear.looks_right("https://script.google.com/macros/s/AKf/exec") and not DocClear.looks_right("https://docs.google.com/document/d/x/edit") and not DocClear.looks_right(""), "only a web app link is taken")
	var token = DocClear.new_token()
	ok(token.length() == 24 and DocClear.script_for(token).contains("const TOKEN = '%s';" % token) and not DocClear.script_for(token).contains("%TOKEN%"), "the script carries the token")
	ok(DocClear.script_for(token).begins_with("/** @OnlyCurrentDoc */"), "the script asks Google for this doc only")

	await _with_stub(rows, plan, token)
	print("DOCCLEAR: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# ---------------------------------------------------------------------------
# The doc script itself, against a pretend doc (needs Node.js)
# ---------------------------------------------------------------------------

func _fetch(host: Node, url: String):
	var http = HTTPRequest.new()
	host.add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return null
	var res = await http.request_completed
	http.queue_free()
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if int(res[1]) == 200 else null


func _with_stub(rows: Array, plan: Array, token: String) -> void:
	var out = []
	if OS.execute("node", ["--version"], out) != 0:
		print("SKIP  the doc script: Node.js is not installed")
		return
	var dir = OS.get_temp_dir().path_join("tt_doc_clear_%d" % (Time.get_ticks_usec() % 100000))
	DirAccess.make_dir_recursive_absolute(dir)
	var f = FileAccess.open(dir.path_join("script.js"), FileAccess.WRITE)
	f.store_string(DocClear.script_for(token))
	f.close()
	f = FileAccess.open(dir.path_join("doc.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify([rows]))
	f.close()
	var port = 18000 + randi() % 2000
	var pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/doc_clear_stub.js"), dir.path_join("script.js"), dir.path_join("doc.json"), str(port)])
	var host = Node.new()
	root.add_child(host)
	var base = "http://127.0.0.1:%d" % port
	var ping = {"ok": false}
	for i in range(60):
		ping = await DocClear.send(host, base + "/exec", token, [], true)
		if ping.ok:
			break
		await create_timer(0.1).timeout
	ok(ping.ok and int(ping.tables) == 1, "the script answers a ping: one table", ping)
	var wrong = await DocClear.send(host, base + "/exec", "nope", plan)
	ok(not wrong.ok and str(wrong.error).contains("wrong token"), "a wrong token clears nothing", wrong)
	# The player changes the lateral raise row before the clear arrives.
	await _fetch(host, base + "/set?t=0&r=9&c=3&v=14")
	var res = await DocClear.send(host, base + "/exec", token, plan)
	ok(res.ok and int(res.cleared) == 4 and int(res.skipped) == 1, "4 rows emptied; the row changed since it was read is left", res)
	var state = await _fetch(host, base + "/state")
	var doc = state[0] if state is Array else []
	var empty = func(r): return doc[r].all(func(c): return str(c) == "")
	ok(doc.size() == rows.size() and empty.call(1) and empty.call(2) and empty.call(3) and empty.call(4), "the 11/18 rows are empty now, the rows kept", doc.slice(0, 5) if not doc.is_empty() else state)
	ok(not doc.is_empty() and doc[0] == HEAD and doc[6] == rows[6] and doc[7] == rows[7] and doc[8] == rows[8] and doc[10] == rows[10] and str(doc[9][3]) == "14", "the header, 11/19, today's date, the row not read and the changed row are untouched", doc.slice(6, 11) if not doc.is_empty() else null)
	var again = await DocClear.send(host, base + "/exec", token, plan)
	ok(again.ok and int(again.cleared) == 0, "sending it again clears nothing more", again)

	# The day's plan written into the table (script version 2), read and cleared.
	ok(int(ping.get("version", 0)) == 2, "the script says it writes plans (version 2)", ping)
	var day_plan = {"date": "2026-11-22", "lifts": [
		{"name": "Chest Fly - Gym cable", "pt": false, "last": {"sets": [{"reps": 12, "weightKg": 15.0}, {"reps": 12, "weightKg": 15.0}]}},
		{"name": "Calf Stretch - Slant board", "pt": true, "last": {"sets": [{"reps": 3, "weightKg": 0.0, "holdSec": 30}]}}],
		"new": {"move": "Push-up", "variation": "", "name": "Push-up"}}
	var prow = DocClear.plan_rows(day_plan, "kg")
	ok(prow.size() == 3 and prow[0][0] == "Chest Fly" and prow[0][1] == "Gym cable" and str(prow[0][2]).is_valid_float() and prow[1] == ["(PT) Calf Stretch", "Slant board", ""] and prow[2] == ["Push-up", "", ""] and DocClear.date_text("2026-11-22") == "11/22",
		"the plan as rows: movement, variation, the weight to aim for; PT marked; the new movement", prow)
	var wrote = await DocClear.send_plan(host, base + "/exec", token, day_plan, "kg")
	var st2 = await _fetch(host, base + "/state")
	var d3 = st2[0] if st2 is Array else []
	var mk = QuickLog.PLAN_MARK + " "
	ok(wrote.ok and int(wrote.planned) == 3 and d3.size() == 15 and d3[11][0] == mk + "11/22" and d3[12][0] == mk + "Chest Fly" and d3[12][1] == "Gym cable" and d3[13][0] == mk + "(PT) Calf Stretch" and d3[14][0] == mk + "Push-up" and d3.all(func(r): return r.size() == 6),
		"written under the last filled row (rows added when short): a marked date row and a row per lift", [wrote, d3.slice(10) if not d3.is_empty() else st2])
	var twice2 = await DocClear.send_plan(host, base + "/exec", token, day_plan, "kg")
	ok(twice2.ok and int(twice2.planned) == 0 and twice2.already, "never twice for one day", twice2)
	var unfilled = QuickLog.parse_any(PhoneInbox.html_to_text(export_html(d3)), {"today": "2026-11-22", "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES})
	ok(not unfilled.entries.any(func(e): return str(e.date) == "2026-11-22" and str(e.kind) == "session") and not unfilled.problems.any(func(p): return str(p.line).contains("Chest Fly") or str(p.line).contains("Push-up")), "the plan not filled in yet: nothing to import, no problems", unfilled.problems)
	await _fetch(host, base + "/set?t=0&r=12&c=3&v=12")
	var st3 = await _fetch(host, base + "/state")
	var d4 = st3[0] if st3 is Array else []
	var filled_in = QuickLog.parse_any(PhoneInbox.html_to_text(export_html(d4)), {"today": "2026-11-22", "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES})
	var e22 = filled_in.entries.filter(func(e): return str(e.date) == "2026-11-22" and str(e.kind) == "session")
	ok(e22.size() == 1 and e22[0].data.exercises.size() == 1 and str(e22[0].data.exercises[0].name) == "Chest Fly - Gym cable" and not str(e22[0].raw).contains(QuickLog.PLAN_MARK), "a plan row with its reps typed is read like any row, without the mark", e22)
	var t4 = DocClear.table_rows(export_html(d4))
	var next_day = DocClear.plan(t4, filled_in.entries, {}, "2026-11-23").map(func(p): return int(p.r))
	ok(next_day == [13, 14], "the day after: the plan rows never filled in go; the filled one (not imported yet) and its date stay", next_day)
	ok(DocClear.plan(t4, filled_in.entries, {}, "2026-11-22").is_empty(), "on the day itself nothing of the plan goes")
	var in_e = {}
	for e in e22:
		in_e[e.key] = 1
	var after_import = DocClear.plan(t4, filled_in.entries, in_e, "2026-11-23").map(func(p): return int(p.r))
	ok(after_import == [11, 12, 13, 14], "once the filled row is imported, the whole day goes (its date row too)", after_import)
	await _fetch(host, base + "/quit")
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)

	# Through the game's inbox (App.inbox): the note as last read, what is
	# imported, the script link; "Clear now" empties the same rows.
	var app = root.get_node_or_null("App")
	if app == null:
		print("SKIP  through the inbox: no App")
	else:
		var html = export_html(rows)
		f = FileAccess.open(dir.path_join("doc.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify([rows]))
		f.close()
		port += 1
		pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/doc_clear_stub.js"), dir.path_join("script.js"), dir.path_join("doc.json"), str(port)])
		base = "http://127.0.0.1:%d" % port
		var inbox = app.inbox
		ok(not inbox.can_clear() and inbox.clear_rows().is_empty(), "the inbox: not set up, nothing read yet")
		inbox._tables = DocClear.table_rows(html)
		inbox.last_text = PhoneInbox.html_to_text(html)
		var t_saved = app.today
		app.today = TODAY
		var entries = QuickLog.parse_any(inbox.last_text, inbox.parse_opts()).entries
		app.update_inbox({"imported": imported_on(entries, ["2026-11-18", TODAY]), "clear": {"url": base + "/exec", "token": token, "on": true}})
		ok(inbox.can_clear() and inbox.clear_rows().map(func(p): return int(p.r)) == [1, 2, 3, 4, 9], "the inbox works out the same rows", inbox.clear_rows().map(func(p): return int(p.r)))
		var through = {"ok": false}
		for i in range(60):
			through = await DocClear.send(host, base + "/exec", token, [], true)
			if through.ok:
				break
			await create_timer(0.1).timeout
		through = await inbox.clear_imported()
		var after = await _fetch(host, base + "/state")
		var d2 = after[0] if after is Array else []
		ok(through.ok and int(through.cleared) == 5 and not d2.is_empty() and d2[9].all(func(c): return str(c) == "") and d2[7] == rows[7] and str(inbox.status).begins_with("Cleared 5 rows"), "Clear now through the inbox: 5 rows emptied, the rest kept", [through, inbox.status])
		app.today = t_saved
		await _fetch(host, base + "/quit")
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	for n in ["script.js", "doc.json"]:
		DirAccess.remove_absolute(dir.path_join(n))
	DirAccess.remove_absolute(dir)
