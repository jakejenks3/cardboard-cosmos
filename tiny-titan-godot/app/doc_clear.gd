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

## The script the player pastes into the doc (Extensions -> Apps Script).
## %TOKEN% is replaced by the player's token. "@OnlyCurrentDoc" makes Google
## ask for this one doc only, not every doc of the account.
const SCRIPT = """/** @OnlyCurrentDoc */
// Tiny Titan: empties the table rows the game has imported.
// Paste into this doc: Extensions > Apps Script. Then Deploy > New deployment >
// Web app, Execute as: Me, Who has access: Anyone. Copy the web app link into
// Tiny Titan: Settings > Phone inbox > Clear the table.
// It only empties a row whose text is still exactly what the game imported.
// It also writes the day's plan (rows marked \\u25b8) into empty rows at the bottom.
const TOKEN = '%TOKEN%';
const VERSION = 2;
const MARK = '\\u25b8';

function doGet(e) {
  const p = (e && e.parameter) || {};
  if (p.token !== TOKEN) return reply({ok: false, error: 'wrong token'});
  const tables = DocumentApp.getActiveDocument().getBody().getTables();
  if (p.ping) return reply({ok: true, tables: tables.length, version: VERSION});
  if (p.plan) return reply(writePlan(tables, String(p.date || ''), JSON.parse(p.plan)));
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  let cleared = 0, skipped = 0;
  try {
    String(p.rows || '').split(',').filter(String).forEach(function (item) {
      const bits = item.split('.');
      const table = tables[Number(bits[0])];
      const r = Number(bits[1]);
      if (!table || r >= table.getNumRows()) { skipped++; return; }
      const row = table.getRow(r);
      if (rowHash(row) !== bits[2]) { skipped++; return; }
      for (let c = 0; c < row.getNumCells(); c++) row.getCell(c).setText('');
      cleared++;
    });
  } finally {
    lock.releaseLock();
  }
  return reply({ok: true, cleared: cleared, skipped: skipped});
}

// A date row and a row per lift ([exercise, variation, weight]) under their
// columns, in the empty rows after the last row with anything in it (rows are
// added when there are too few). Never twice for one date, never over a filled row.
function writePlan(tables, date, rows) {
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  try {
    let table = null, head = -1;
    for (let t = 0; t < tables.length && !table; t++) {
      for (let r = 0; r < tables[t].getNumRows(); r++) {
        if (texts(tables[t].getRow(r)).some(function (c) { return /^(exercise|exercises|lift|movement|name)$/i.test(c); })) {
          table = tables[t]; head = r; break;
        }
      }
    }
    if (!table) return {ok: false, error: 'no table with an Exercise column'};
    if (!date || !rows.length) return {ok: true, planned: 0};
    const names = texts(table.getRow(head)).map(function (c) { return c.toLowerCase(); });
    const col = function (words) { for (let i = 0; i < names.length; i++) if (words.indexOf(names[i]) >= 0) return i; return -1; };
    const cEx = col(['exercise', 'exercises', 'lift', 'movement', 'name']);
    const cVar = col(['variation', 'variant', 'equipment', 'type', 'version', 'kind', 'style', 'how']);
    const cW = col(['weight', 'load', 'lb', 'lbs', 'kg', 'resistance']);
    let last = head;
    for (let r = head + 1; r < table.getNumRows(); r++) {
      const cells = texts(table.getRow(r));
      if (cells[cEx] === MARK + ' ' + date) return {ok: true, planned: 0, already: true};
      if (cells.some(function (c) { return c !== ''; })) last = r;
    }
    const width = table.getRow(head).getNumCells();
    while (table.getNumRows() - (last + 1) < rows.length + 1) {
      const nr = table.appendTableRow();
      for (let c = 0; c < width; c++) nr.appendTableCell('');
    }
    const put = function (r, c, v) { if (c >= 0 && c < table.getRow(r).getNumCells()) table.getRow(r).getCell(c).setText(String(v)); };
    put(last + 1, cEx, MARK + ' ' + date);
    rows.forEach(function (x, i) {
      put(last + 2 + i, cEx, MARK + ' ' + x[0]);
      if (x[1]) put(last + 2 + i, cVar, x[1]);
      if (x[2]) put(last + 2 + i, cW, x[2]);
    });
    return {ok: true, planned: rows.length};
  } finally {
    lock.releaseLock();
  }
}

function texts(row) {
  const out = [];
  for (let c = 0; c < row.getNumCells(); c++) out.push(row.getCell(c).getText().trim());
  return out;
}

function rowHash(row) {
  const cells = [];
  for (let c = 0; c < row.getNumCells(); c++) {
    const t = row.getCell(c).getText().replace(/[\\u200b\\ufeff]/g, '').replace(/^\\s*\\u25b8\\s*/, '').replace(/\\|/g, '/')
      .replace(/[\\s\\u00a0]+/g, ' ').trim();
    if (t !== '' && !/^:?-{2,}:?$/.test(t)) cells.push(t.toLowerCase());
  }
  const bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, cells.join(' | '), Utilities.Charset.UTF_8);
  return bytes.map(function (b) { return ('0' + (b & 255).toString(16)).slice(-2); }).join('').slice(0, 10);
}

function reply(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
"""

const TIMEOUT_SEC = 30.0
## The script's VERSION (what a ping of the newest one says).
const SCRIPT_VERSION = 2


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
	return SCRIPT.replace("%TOKEN%", token)


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


## "11/22": a date the parser reads as a date row.
static func date_text(date: String) -> String:
	var p = date.split("-")
	return "%d/%d" % [int(p[1]), int(p[2])] if p.size() == 3 else date


## The web app link with what to clear ("ping" only checks the link).
static func request_url(url: String, token: String, rows: Array, ping: bool = false, plan_date: String = "") -> String:
	var u = url.strip_edges()
	var q = "token=" + token.uri_encode()
	if ping:
		q += "&ping=1"
	elif plan_date != "":
		q += "&date=" + plan_date.uri_encode() + "&plan=" + JSON.stringify(rows).uri_encode()
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
static func send(node: Node, url: String, token: String, rows: Array, ping: bool = false, plan_date: String = "") -> Dictionary:
	if not looks_right(url):
		return {"ok": false, "error": "That is not a web app link (it starts with https://script.google.com/ and ends in /exec)."}
	var http = HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	http.max_redirects = 8
	node.add_child(http)
	await node.get_tree().process_frame
	var err = http.request(request_url(url, token, rows, ping, plan_date))
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
static func send_plan(node: Node, url: String, token: String, plan: Dictionary, wu: String) -> Dictionary:
	var rows = plan_rows(plan, wu)
	if rows.is_empty():
		return {"ok": true, "planned": 0, "error": ""}
	return await send(node, url, token, rows, false, date_text(str(plan.date)))
