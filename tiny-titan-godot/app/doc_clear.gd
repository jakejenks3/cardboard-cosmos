class_name DocClear
extends RefCounted
## Emptying the phone note's table after an import. The game only READS the
## Google Doc (its export link), so the clearing is done by a small Google Apps
## Script the player adds to the doc once (SCRIPT, with a token the game
## makes) and deploys as a web app; its link goes in Settings -> Phone inbox.
##
## What is cleared: table rows whose entries are imported, nothing else. Each
## row is sent as its position and a hash of its text as the game read it
## (`table.row.hash`); the script empties a row only when its text there is
## still exactly that. So a row typed or changed since the note was read, a
## row not imported (unticked, or a line that was not read), a header row and
## every line outside a table are left alone. A date row goes too when its
## day is over and every row under it is empty or cleared.
## The hash: the row's filled cells, lower case, spaces collapsed, " | "
## between (row_text), md5, first 10 hex digits; the script computes the same.
##
## The script also WRITES the day's plan (plan_rows, sent by tools/morning.gd at
## midnight or "Write today's plan" in Settings): a date row and a row per
## lift (exercise, variation, weight) at the bottom of the table, each marked
## QuickLog.PLAN_MARK. The player types the reps; a marked row left without
## sets is skipped by the parser, and goes in the next clear once its day is
## over. Marks are left out of a row's text, so a filled plan row clears like
## any other. Script VERSION 2 has plans (a ping says which).
## Pure but for `send`. Tests: tests/doc_clear_test.gd.

## The script the player pastes into the doc (Extensions -> Apps Script): the
## code in SCRIPT_FILE with the phone logger page (PAGE_FILE) inside it and the
## player's token. "@OnlyCurrentDoc" makes Google ask for this one doc only.
const SCRIPT_FILE = "res://app/doc_script.js"
const PAGE_FILE = "res://app/doc_logger.html"

const TIMEOUT_SEC = 30.0
## The script's VERSION (what a ping of the newest one says).
const SCRIPT_VERSION = 3
## The longest the logger's info may be in a link (encoded characters).
const INFO_MAX = 2600


## A new token (the script and the game share it).
static func new_token() -> String:
	var letters = "abcdefghijkmnpqrstuvwxyz23456789"
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var out = ""
	for i in range(24):
		out += letters[rng.randi_range(0, letters.length() - 1)]
	return out


## The script with the player's token in it.
static func script_for(token: String) -> String:
	var js = FileAccess.get_file_as_string(SCRIPT_FILE)
	var page = FileAccess.get_file_as_string(PAGE_FILE)
	return js.replace("%PAGE%", JSON.stringify(page)).replace("%TOKEN%", token)


## The phone logger page's link (bookmark it on the phone's home screen).
static func logger_url(url: String, token: String) -> String:
	var u = url.strip_edges()
	return u + ("&" if u.contains("?") else "?") + "page=log&token=" + token.uri_encode()


## Every table of the export's HTML: [table][row] = [cell texts], read the way
## PhoneInbox._tables_to_rows reads them (codes decoded).
static func table_rows(html: String) -> Array:
	var table_rx = RegEx.create_from_string("(?is)<table\\b.*?</table>")
	var row_rx = RegEx.create_from_string("(?is)<tr\\b.*?</tr>")
	var cell_rx = RegEx.create_from_string("(?is)<t[dh]\\b[^>]*>(.*?)</t[dh]>")
	var tag_rx = RegEx.create_from_string("(?s)<[^>]+>")
	var space_rx = RegEx.create_from_string("\\s+")
	var out = []
	for tm in table_rx.search_all(html):
		var rows = []
		for rm in row_rx.search_all(tm.get_string(0)):
			var cells = []
			for cm in cell_rx.search_all(rm.get_string(0)):
				var txt = tag_rx.sub(cm.get_string(1), " ", true).replace("&nbsp;", " ")
				cells.append(PhoneInbox.decode_entities(space_rx.sub(txt, " ", true).strip_edges()).strip_edges())
			rows.append(cells)
		out.append(rows)
	return out


## The filled cells of a row as one line: what the parser shows for it
## ("bent over row | barbell | 60 | 8"), separators and empty cells left out.
static func row_line(cells: Array) -> String:
	var filled = PackedStringArray()
	var space = RegEx.create_from_string("\\s+")
	var dashes = RegEx.create_from_string("^:?-{2,}:?$")
	for c in cells:
		var t = str(c).replace("​", "").replace("﻿", "").strip_edges().trim_prefix(QuickLog.PLAN_MARK).replace("|", "/").replace(" ", " ")
		t = space.sub(t, " ", true).strip_edges()
		if t != "" and dashes.search(t) == null:
			filled.append(t)
	return " | ".join(filled)


## row_line in lower case: what is compared and hashed.
static func row_text(cells: Array) -> String:
	return row_line(cells).to_lower()


static func row_hash(cells: Array) -> String:
	return row_text(cells).md5_text().substr(0, 10)


static func _norm(line: String) -> String:
	var t = line.replace("​", "").replace("﻿", "").replace(" ", " ")
	return RegEx.create_from_string("\\s+").sub(t, " ", true).strip_edges().to_lower()


## The rows to empty: [{"t", "r", "h", "text"}]. `tables` from table_rows,
## `entries` the note's entries (QuickLog), `imported` saved.inbox.imported.
## A row goes when it is a line of an imported entry and of no entry that is
## not imported (the same text twice, one in and one not: neither goes). A
## header row never goes. A date row before `today` goes when every row under
## it (to the next date row) is empty or going.
static func plan(tables: Array, entries: Array, imported: Dictionary, today: String) -> Array:
	var done_lines = {}
	var open_lines = {}
	# Entries of one key: the first imported[key] are in (split_entries' rule).
	var seen = {}
	for e in entries:
		var n = int(seen.get(e.key, 0)) + 1
		seen[e.key] = n
		var is_in = n <= int(imported.get(e.key, 0))
		for ln in e.get("raw", []):
			var k = _norm(str(ln))
			if is_in:
				done_lines[k] = int(done_lines.get(k, 0)) + 1
			else:
				open_lines[k] = true
	var out = []
	for ti in range(tables.size()):
		var rows: Array = tables[ti]
		var header = false
		var roles = []
		var going = {}
		var dates = []
		var day = ""
		for ri in range(rows.size()):
			var cells: Array = rows[ri]
			var text = row_text(cells)
			if text == "":
				continue
			var filled = text.split(" | ")
			# A header row: it names its columns (Exercise, Weight, Set 1...).
			var named = 0
			var has_ex = false
			for c in cells:
				var role = QuickLog.table_role(str(c))
				if role != "":
					named += 1
				if role == "exercise":
					has_ex = true
			if has_ex and named >= 2 and named >= filled.size() - 1:
				header = true
				roles = cells.map(func(c): return QuickLog.table_role(str(c)))
				continue
			if filled.size() == 1:
				var d = QuickLog.date_line(QuickLog.normalize_line(row_line(cells)), today)
				if not d.is_empty():
					dates.append({"r": ri, "date": str(d.date)})
					day = str(d.date)
					continue
			if int(done_lines.get(text, 0)) > 0 and not open_lines.has(text):
				done_lines[text] = int(done_lines[text]) - 1
				going[ri] = true
				out.append({"t": ti, "r": ri, "h": row_hash(cells), "text": text})
			elif day != "" and day < today and not open_lines.has(text) and _unfilled_plan(cells, roles):
				# The plan of a day that is over, never filled in: only what the game wrote.
				going[ri] = true
				out.append({"t": ti, "r": ri, "h": row_hash(cells), "text": text})
		# Date rows whose day is over and has nothing left under it.
		for i in range(dates.size()):
			var d = dates[i]
			if str(d.date) >= today:
				continue
			var stop = int(dates[i + 1].r) if i + 1 < dates.size() else rows.size()
			var left = false
			for ri in range(int(d.r) + 1, stop):
				if row_text(rows[ri]) != "" and not going.has(ri):
					left = true
					break
			if not left:
				out.append({"t": ti, "r": int(d.r), "h": row_hash(rows[int(d.r)]), "text": row_text(rows[int(d.r)])})
	out.sort_custom(func(a, b): return int(a.t) < int(b.t) or (int(a.t) == int(b.t) and int(a.r) < int(b.r)))
	return out


## A row the game wrote (marked) with nothing typed in it since: only its
## Exercise, Variation and Weight cells hold anything.
static func _unfilled_plan(cells: Array, roles: Array) -> bool:
	if roles.is_empty() or not cells.any(func(c): return str(c).strip_edges().begins_with(QuickLog.PLAN_MARK)):
		return false
	for i in range(cells.size()):
		var role = str(roles[i]) if i < roles.size() else ""
		if str(cells[i]).strip_edges() != "" and not ["exercise", "variation", "weight"].has(role):
			return false
	return true


## The rows of a day's plan for the note's table: [exercise, variation,
## weight] per lift (the weight to aim for, in the player's unit, as a bare
## number; nothing for a lift without weight), then the movement to try, then
## the physical therapy still to do this week ("(PT) " in front).
static func plan_rows(plan: Dictionary, wu: String) -> Array:
	var out = []
	var step = 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)
	for l in plan.get("lifts", []):
		var sp = LiftNames.split(str(l.name))
		var aim = LiftTrend.next_target(l.last.sets, step).sets if not bool(l.pt) else l.last.sets
		var kg = 0.0
		for one in aim:
			kg = maxf(kg, float(one.get("weightKg", 0.0)))
		var w = ""
		if kg > 0.0:
			w = TTUtil.num_str(snappedf(Fmt.kg_to_unit(kg, wu), 0.5))
		out.append([("(PT) " if bool(l.pt) else "") + str(sp.move), str(sp.variation), w])
	if plan.get("new") != null:
		out.append([str(plan.new.move), str(plan.new.variation), ""])
	# The physical therapy still to do this week (not already a lift above).
	var named = out.map(func(r): return Xp.normalize_exercise(Pt.untag(str(r[0])).name))
	for r in plan.get("pt", []):
		var sp = LiftNames.split(str(r.name))
		if not named.has(Xp.normalize_exercise(str(sp.move))):
			out.append(["(PT) " + str(sp.move), str(sp.variation), ""])
	return out


## What the phone logger needs from the game (sent with the plan): {"unit",
## "dunit", "step" (one tap of weight), "kind" ("Push day"), "lifts" ([{n
## (name), w (last top weight)}], the latest first: the add list), "aims"
## ({lower-case name: {sets, reps, weight, text, last, hold}})}.
static func plan_info(plan: Dictionary, sessions: Array, settings: Dictionary) -> Dictionary:
	var wu = str(settings.get("weightUnit", "kg"))
	var fmt_w = func(kg): return Fmt.fmt_weight(float(kg), wu)
	var to_u = func(kg: float) -> float: return snappedf(Fmt.kg_to_unit(kg, wu), 0.5)
	var step = 2.5 if wu == "kg" else Fmt.unit_to_kg(5.0, wu)
	var lifts = []
	var st = LiftLibrary.stats(sessions)
	var rows = st.values()
	rows.sort_custom(func(a, b): return str(a.last) > str(b.last))
	for r in rows.slice(0, 30):
		var top = LiftTrend.day(r.history[0].sets)
		var one = {"n": str(r.name)}
		if float(top.topKg) > 0.0:
			one["w"] = TTUtil.num_str(to_u.call(float(top.topKg)))
		lifts.append(one)
	var aims = {}
	for l in plan.get("lifts", []):
		var name = Pt.untag(str(l.name)).name
		var aim = l.last.sets if bool(l.pt) else LiftTrend.next_target(l.last.sets, step).sets
		var d = LiftTrend.day(aim)
		var a = {"sets": aim.size(), "reps": int(aim[0].get("reps", 10)) if not aim.is_empty() else 10,
			"text": LiftHistory.describe_sets(aim, fmt_w), "last": LiftHistory.describe_sets(l.last.sets, fmt_w)}
		if float(d.topKg) > 0.0:
			a["weight"] = to_u.call(float(d.topKg))
			if Plates.is_barbell(str(l.name)):
				var wt = float(a.weight)
				if Plates.warmup_text(wt, wu) != "":
					a["warm"] = Plates.warmup_text(wt, wu)
				if Plates.text(wt, wu) != "":
					a["plates"] = Plates.text(wt, wu)
		if int(d.holdSec) > 0:
			a["hold"] = int(d.holdSec)
		aims[str(name).to_lower()] = a
	# Physical therapy still to do this week: as last time (a hold: its seconds).
	for r in plan.get("pt", []):
		var h = r.get("history", [])
		if h.is_empty():
			continue
		var sets = h[0].get("sets", [])
		var d = LiftTrend.day(sets)
		var a = {"sets": sets.size(), "reps": int(sets[0].get("reps", 10)) if not sets.is_empty() else 10,
			"text": LiftHistory.describe_sets(sets, fmt_w), "last": LiftHistory.describe_sets(sets, fmt_w)}
		if float(d.topKg) > 0.0:
			a["weight"] = to_u.call(float(d.topKg))
		if int(d.holdSec) > 0:
			a["hold"] = int(d.holdSec)
		aims[str(r.name).to_lower()] = a
	var out = {"unit": wu, "dunit": str(settings.get("distanceUnit", "km")), "step": TTUtil.num_str(float(TT.weight_step_of(settings))),
		"kind": str(plan.get("label", "")), "lifts": lifts, "aims": aims}
	# It travels in a link: kept short (the add list loses its oldest lifts first).
	while JSON.stringify(out).uri_encode().length() > INFO_MAX and lifts.size() > 8:
		lifts.pop_back()
	return out


## "11/22": a date the parser reads as a date row.
static func date_text(date: String) -> String:
	var p = date.split("-")
	return "%d/%d" % [int(p[1]), int(p[2])] if p.size() == 3 else date


## The web app link with what to clear ("ping" only checks the link).
static func request_url(url: String, token: String, rows: Array, ping: bool = false, plan_date: String = "", info = null) -> String:
	var u = url.strip_edges()
	var q = "token=" + token.uri_encode()
	if ping:
		q += "&ping=1"
	elif plan_date != "":
		q += "&date=" + plan_date.uri_encode() + "&plan=" + JSON.stringify(rows).uri_encode()
		if info is Dictionary:
			q += "&info=" + JSON.stringify(info).uri_encode()
	else:
		var items = PackedStringArray()
		for r in rows:
			items.append("%d.%d.%s" % [int(r.t), int(r.r), str(r.h)])
		q += "&rows=" + ",".join(items).uri_encode()
	return u + ("&" if u.contains("?") else "?") + q


## Is it a web app link of Google Apps Script? (A stand-in on this computer
## counts too: tests/doc_clear_stub.js.)
static func looks_right(url: String) -> bool:
	var u = url.strip_edges()
	return (u.begins_with("https://script.google.com/") or u.begins_with("http://127.0.0.1:")) and u.contains("/exec")


## Call the script. Awaitable: {"ok", "cleared", "skipped", "tables", "error"}.
## `node`: anything in the scene tree (the request is a child of it while it runs).
static func send(node: Node, url: String, token: String, rows: Array, ping: bool = false, plan_date: String = "", info = null) -> Dictionary:
	if not looks_right(url):
		return {"ok": false, "error": "That is not a web app link (it starts with https://script.google.com/ and ends in /exec)."}
	var http = HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	http.max_redirects = 8
	node.add_child(http)
	await node.get_tree().process_frame
	var err = http.request(request_url(url, token, rows, ping, plan_date, info))
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Could not reach the script."}
	var res = await http.request_completed
	http.queue_free()
	var code = int(res[1])
	var body: PackedByteArray = res[3]
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {"ok": false, "error": "The script did not answer (code %d)." % code}
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return {"ok": false, "error": "The script answered with a page, not a result: check it is deployed with access for Anyone."}
	if not bool(data.get("ok", false)):
		return {"ok": false, "error": "The script said: %s" % str(data.get("error", "no"))}
	return {"ok": true, "cleared": int(data.get("cleared", 0)), "skipped": int(data.get("skipped", 0)), "tables": int(data.get("tables", 0)),
		"version": int(data.get("version", 1)), "planned": int(data.get("planned", 0)), "already": bool(data.get("already", false)), "error": ""}


## Write a day's plan into the note's table (plan_rows). Awaitable, as send.
static func send_plan(node: Node, url: String, token: String, plan: Dictionary, wu: String, info = null) -> Dictionary:
	var rows = plan_rows(plan, wu)
	return await send(node, url, token, rows, false, date_text(str(plan.date)), info)
