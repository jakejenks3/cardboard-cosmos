class_name PhoneInbox
extends Node
## The phone inbox: the player jots workouts in a note on their phone (a shared
## Google Doc, a Form's responses sheet, a file in a synced folder), and the game
## reads that text, shows what it understood and imports it.
##
## Created by App._ready() as `App.inbox` (a child of App). It talks to App
## through get_parent() rather than the autoload name, so this script also loads
## in `--script` unit tests (tests/quick_log_test.gd uses fetch_url).
##
## The game does not clear the note by itself (it only reads it). With a
## Google Doc it can empty the TABLE rows it imported through a script the
## player adds to the doc (app/doc_clear.gd; saved.inbox.clear = {url, token,
## on}): after an import, or with "Clear now". Lines outside a table, rows
## not imported and rows changed since the note was read stay. So what was
## imported is still remembered as
## {key: count} in saved.inbox.imported: for each key the first `count`
## occurrences in the text are already in the log, any further ones are new.
##
## Pictures in a Google Doc are read too (app/ocr.gd, Windows only): a workout
## screenshot becomes a run or ride and a scale screenshot a weigh-in
## (game/shot_reader.gd); a picture with no text on it stays a progress photo.
## What was found on each picture is kept in inbox_pictures.json beside the
## save, so a picture is read once and "Today" printed on it keeps meaning the
## day the game first saw it.

## result = {"ok", "error", "fresh": [entry...], "already": int, "problems": [...]}
signal checked(result)

const TIMEOUT_SEC = 30.0
const NOT_SHARED = "That link is not shared. In Google Docs: Share → General access → Anyone with the link."
const CHANGED_DAY = "this day changed after you imported it; importing adds it again (left out unless you tick it)"
const UPDATES = "this day changed after you imported it; importing updates that entry"
const SECOND_LIFT = "A second lift on this day (the one already in your log stays; check the date if it should be another day)"
const PAGES_FILE = "inbox_pictures.json"
const COULD_NOT_READ = "the Windows text reader did not answer, so the pictures are kept as photos"

var _http: HTTPRequest = null
var _busy = false
var _silent = false
var _last = {"ok": true, "error": "", "fresh": [], "already": 0, "problems": []}
## Occurrences of each key in the last text read from the source (null before the first read).
var _source_keys = null
## One line for Settings about the last check this session ("" before the first).
var status = ""
## The note's text as last read (a Google Doc's pictures appear as "photo images/imageN.jpg" lines).
var last_text = ""
## Pictures found in the note on the last check: {"images/image1.jpg": bytes}. They
## are only written to disk (as progress photos) when their check-in is imported.
var _images = {}
var _image_tex = {}
## md5 of each picture in the note, by its name.
var _hash = {}
## What the text reader found on pictures seen before:
## {md5: {"seen": "YYYY-MM-DD", "page": {...}}} (null until loaded from PAGES_FILE).
var _pages = null
## What each picture in the note says, by its lower-case name (ShotReader.read plus "seen").
var _readings = {}
## The text reader at work: {"job", "text", "silent", "todo": {name: md5}}.
var _reading = null
## Why the pictures could not be read on this check ("" when they were).
var _unread = ""
## The note's tables as last read from the Google Doc (DocClear.table_rows);
## [] for a file or pasted text.
var _tables = []
## A clear in progress.
var _clearing = false


func _app():
	return get_parent()


func _ready() -> void:
	set_process(false)
	var st = settings()
	if str(st.get("source", "")).strip_edges() != "" and bool(st.get("auto", true)):
		# In the background a moment after start; failures stay quiet on launch.
		get_tree().create_timer(1.5).timeout.connect(check.bind(true))


func settings() -> Dictionary:
	return _app().saved.inbox


func busy() -> bool:
	return _busy


## Fresh entries from the last check, waiting for review.
func pending() -> Array:
	return _last.fresh


## The whole last result (fresh, already, problems) for the review sheet.
func last_result() -> Dictionary:
	return _last


func set_source(src: String) -> void:
	if src.strip_edges() == str(settings().get("source", "")):
		return
	# A different note: what was imported from the old one says nothing about it.
	_source_keys = null
	_app().update_inbox({"source": src.strip_edges()})


func set_auto(on: bool) -> void:
	_app().update_inbox({"auto": on})


## A share link -> the address of its contents. A Google Doc comes as a zip
## (its text as HTML plus the pictures in it); everything else as plain text.
static func fetch_url(source: String) -> String:
	var s = source.strip_edges()
	var m = RegEx.create_from_string("^https?://docs\\.google\\.com/document/(?:u/\\d+/)?d/([A-Za-z0-9_-]+)").search(s)
	if m != null:
		return "https://docs.google.com/document/d/%s/export?format=zip" % m.get_string(1)
	m = RegEx.create_from_string("^https?://docs\\.google\\.com/spreadsheets/(?:u/\\d+/)?d/([A-Za-z0-9_-]+)").search(s)
	if m != null:
		var out = "https://docs.google.com/spreadsheets/d/%s/export?format=csv" % m.get_string(1)
		var g = RegEx.create_from_string("[#&?]gid=(\\d+)").search(s)
		if g != null:
			out += "&gid=" + g.get_string(1)
		return out
	if s.contains("dropbox.com/") and s.contains("dl=0"):
		return s.replace("dl=0", "dl=1")
	if RegEx.create_from_string("^https?://gist\\.github\\.com/[^/]+/[0-9a-f]+/?$").search(s) != null:
		return s.trim_suffix("/") + "/raw"
	return s


func parse_opts() -> Dictionary:
	var app = _app()
	var names = []
	var own = []
	for x in LiftHistory.exercise_suggestions(app.sessions(), LiftNames.defaults()):
		names.append(x.name)
		if int(x.get("count", 0)) > 0:
			own.append(x.name)
	var loaded = {}
	for s in app.sessions():
		if s.discipline == "lift":
			for ex in s.get("exercises", []):
				for st in ex.sets:
					if float(st.get("weightKg", 0)) > 0.0:
						loaded[Xp.normalize_exercise(ex.name)] = true
	# The weight carried in the last misc session of each kind (the vest of the last vest walk).
	var last_load = {}
	for k in Misc.ORDER:
		last_load[k] = Misc.last_load_kg(app.sessions(), k)
	return {"today": app.today, "weightUnit": app.weight_unit(), "distanceUnit": app.distance_unit(),
		"exercises": names, "own": own, "names": settings().get("names", {}), "pt": app.pt(),
		"loaded": loaded.keys(), "shots": _readings, "lastLoadKg": last_load}


## What the player said a typed lift name means (the review's yes / no / other):
## `lift` is the lift it is, "" for a lift of its own under the typed name.
## Filed under LiftMatch.key(typed), so the same words are not asked about again.
func name_lift(key: String, lift: String) -> void:
	var names = settings().get("names", {}).duplicate()
	names[key] = lift
	_app().update_inbox({"names": names})


func names_count() -> int:
	return settings().get("names", {}).size()


## Forget every such decision: the game works the names out again, and asks.
func forget_names() -> void:
	_app().update_inbox({"names": {}})


## Read the note text of the last check again, after a lift name was decided:
## the same entries, with the new names. Nothing is fetched, and the pictures
## and their readings stay as they were.
func reparse() -> Dictionary:
	if not bool(_last.get("ok", false)) or last_text == "":
		return _last
	var parsed = QuickLog.parse_any(last_text, parse_opts())
	# A note about pictures that were not read is said once, by the check itself.
	for pr in _last.get("problems", []):
		if str(pr.get("line", "")) == "pictures" and str(pr.get("picture", "x")) == "":
			parsed.problems.append(pr)
	var split = PhoneInbox.split_entries(parsed.entries, settings().get("imported", {}))
	_resolve_updates(split.fresh)
	_last = {"ok": true, "error": "", "fresh": split.fresh, "already": split.already, "problems": parsed.problems}
	return _last


## Fetch (link) or read (file path) the note, then emit `checked`. A file is read
## at once (the signal fires before this returns); a link answers later.
func check(silent: bool = false) -> void:
	if _busy:
		return
	var src = str(settings().get("source", "")).strip_edges()
	if src == "":
		_finish({"ok": false, "error": "No link or file set yet: add one in Settings → Phone inbox."}, silent)
		return
	if not src.begins_with("http"):
		var path = src
		if path.begins_with("~"):
			path = OS.get_environment("HOME") + path.substr(1)
		if not FileAccess.file_exists(path):
			_finish({"ok": false, "error": "Could not find the file %s." % path}, silent)
			return
		_readings = {}
		_tables = []
		_got_text(FileAccess.get_file_as_string(path), silent, true)
		return
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT_SEC
		_http.max_redirects = 8
		add_child(_http)
		_http.request_completed.connect(_on_http)
	_busy = true
	_silent = silent
	var err = _http.request(fetch_url(src), PackedStringArray(["Accept: application/zip, text/plain, text/csv, */*"]))
	if err != OK:
		_busy = false
		_finish({"ok": false, "error": "Could not reach that link."}, silent)


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		var why = "it took too long" if result == HTTPRequest.RESULT_TIMEOUT else "check the link and your internet"
		_finish({"ok": false, "error": "Could not reach that link (%s)." % why}, _silent)
		return
	if code < 200 or code >= 300:
		var msg = "The link answered with HTTP %d." % code
		if code == 401 or code == 403:
			msg += " " + NOT_SHARED
		_finish({"ok": false, "error": msg}, _silent)
		return
	if body.size() > 4 and body[0] == 0x50 and body[1] == 0x4B:
		_got_zip(body, _silent)
		return
	_readings = {}
	_got_text(body.get_string_from_utf8(), _silent, true)


## A Google Doc exported as a zip: its HTML becomes the note's text and the
## pictures wait in memory until their check-in is imported.
func _got_zip(bytes: PackedByteArray, silent: bool) -> void:
	var path = _app().DATA_DIR + "inbox_note.zip"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_finish({"ok": false, "error": "Could not save the note's pictures to read them."}, silent)
		return
	f.store_buffer(bytes)
	f.close()
	var z = ZIPReader.new()
	if z.open(path) != OK:
		DirAccess.remove_absolute(path)
		_finish({"ok": false, "error": "Could not read the note (the download was not what Google normally sends)."}, silent)
		return
	var html = ""
	var images = {}
	for name in z.get_files():
		if str(name).to_lower().ends_with(".html") and html == "":
			html = z.read_file(name).get_string_from_utf8()
		elif str(name).begins_with("images/") and not str(name).ends_with("/"):
			var data = z.read_file(name)
			if not data.is_empty():
				images[str(name)] = data
	z.close()
	DirAccess.remove_absolute(path)
	_images = images
	_image_tex = {}
	_tables = DocClear.table_rows(html)
	_read_pictures(html_to_text(html), silent)


static func _md5(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "empty"
	var hc = HashingContext.new()
	hc.start(HashingContext.HASH_MD5)
	hc.update(bytes)
	return hc.finish().hex_encode()


## What the text reader found on the pictures seen before (inbox_pictures.json).
func _load_pages() -> Dictionary:
	if _pages == null:
		_pages = {}
		var path = _app().DATA_DIR + PAGES_FILE
		if FileAccess.file_exists(path):
			var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
			if raw is Dictionary:
				for k in raw:
					if raw[k] is Dictionary and raw[k].get("page") is Dictionary:
						_pages[str(k)] = raw[k]
	return _pages


func _save_pages() -> void:
	var f = FileAccess.open(_app().DATA_DIR + PAGES_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_pages))
		f.close()


static func _page_ok(entry) -> bool:
	return entry is Dictionary and entry.get("page") is Dictionary and int(entry.page.get("v", 0)) == ShotReader.VERSION


## Have the pictures of the note read (only the ones not seen before), then
## carry on with its text. Without a text reader they all stay photos.
func _read_pictures(text: String, silent: bool) -> void:
	_hash = {}
	_unread = ""
	var pages = _load_pages()
	var todo = {}
	var files = {}
	var queued = {}
	for name in _images:
		var h = PhoneInbox._md5(_images[name])
		_hash[name] = h
		if not PhoneInbox._page_ok(pages.get(h)) and not queued.has(h):
			queued[h] = true
			todo[name] = h
			files[name] = _images[name]
	if todo.is_empty() or not Ocr.available():
		_pictures_done(text, silent)
		return
	var job = Ocr.start(files, _app().DATA_DIR + "reading")
	if job.is_empty():
		_unread = COULD_NOT_READ
		_pictures_done(text, silent)
		return
	_busy = true
	_reading = {"job": job, "text": text, "silent": silent, "todo": todo}
	set_process(true)


## While the text reader works: ask it whether it is done.
func _process(_delta: float) -> void:
	if _reading == null:
		set_process(false)
		return
	var r = Ocr.poll(_reading.job)
	if r == null:
		return
	var was = _reading
	_reading = null
	set_process(false)
	_busy = false
	if r.ok:
		var pages = _load_pages()
		for name in r.pages:
			var h = str(was.todo.get(name, ""))
			if h == "":
				continue
			var old = pages.get(h)
			var seen = str(old.get("seen", _app().today)) if old is Dictionary else str(_app().today)
			pages[h] = {"seen": seen, "page": r.pages[name]}
		for name in was.todo:
			if not r.pages.has(name):
				pages[str(was.todo[name])] = {"seen": str(_app().today), "page": ShotReader.page({})}
		_save_pages()
	else:
		_unread = COULD_NOT_READ
	_pictures_done(was.text, was.silent)


## The pictures are read (or cannot be): forget the ones no longer in the note,
## work out what each one says and read the note's text.
func _pictures_done(text: String, silent: bool) -> void:
	var pages = _load_pages()
	var here = {}
	for name in _hash:
		here[_hash[name]] = true
	var dropped = false
	for h in pages.keys():
		if not here.has(h):
			pages.erase(h)
			dropped = true
	if dropped:
		_save_pages()
	_readings = {}
	for name in _images:
		var entry = pages.get(_hash.get(name, ""))
		if not PhoneInbox._page_ok(entry):
			continue
		var r = ShotReader.read(entry.page)
		r["seen"] = str(entry.get("seen", _app().today))
		r["id"] = str(_hash.get(name, name))
		_readings[str(name).to_lower()] = r
	_got_text(text, silent, true)


func _exit_tree() -> void:
	if _reading != null:
		Ocr.cancel(_reading.job)
		_reading = null


## Google's HTML export -> plain lines. Each picture becomes its own line,
## "photo images/image1.jpg", which the parser turns into a progress photo.
static func html_to_text(html: String) -> String:
	var h = html
	for tag in ["head", "style", "script"]:
		h = RegEx.create_from_string("(?is)<%s\\b.*?</%s>" % [tag, tag]).sub(h, "", true)
	h = _tables_to_rows(h)
	h = RegEx.create_from_string("(?is)<img\\b[^>]*\\bsrc=\"([^\"]+)\"[^>]*>").sub(h, "\nphoto $1\n", true)
	h = RegEx.create_from_string("(?is)<br\\s*/?>|</(?:p|div|li|tr|h[1-6]|table)>").sub(h, "\n", true)
	h = RegEx.create_from_string("(?is)</t[dh]>").sub(h, " ", true)
	h = RegEx.create_from_string("(?s)<[^>]+>").sub(h, "", true)
	return decode_entities(h)


## What Google's export writes in place of some characters, and the character.
## The curly quotes matter most: 30" (thirty seconds held) arrives as 30&rdquo;.
const ENTITIES = {
	"nbsp": " ", "quot": "\"", "apos": "'", "lt": "<", "gt": ">",
	"ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’", "sbquo": "‚", "bdquo": "„",
	"prime": "′", "Prime": "″", "ndash": "–", "mdash": "—", "minus": "−", "times": "×", "divide": "÷",
	"deg": "°", "hellip": "…", "middot": "·", "bull": "•", "frac12": "½", "frac14": "¼", "frac34": "¾",
	"plusmn": "±", "laquo": "«", "raquo": "»", "ensp": " ", "emsp": " ", "thinsp": " ", "shy": "",
}


## "&rdquo;" -> ”, "&#8221;" -> ”, "&#x201d;" -> ”. "&amp;" goes last, so the
## text "&amp;quot;" stays the text "&quot;".
static func decode_entities(text: String) -> String:
	var out = text
	if not out.contains("&"):
		return out
	for hit in RegEx.create_from_string("&([A-Za-z][A-Za-z0-9]{1,7});").search_all(out):
		var word = hit.get_string(1)
		if ENTITIES.has(word):
			out = out.replace(hit.get_string(0), str(ENTITIES[word]))
	for hit in RegEx.create_from_string("&#(\\d{1,7});").search_all(out):
		out = out.replace(hit.get_string(0), char(int(hit.get_string(1))))
	for hit in RegEx.create_from_string("&#[xX]([0-9A-Fa-f]{1,6});").search_all(out):
		out = out.replace(hit.get_string(0), char(hit.get_string(1).hex_to_int()))
	return out.replace("&amp;", "&")


## Every table of the HTML as lines of text, one per row, the cells between
## bars: "| Exercise | Variation | Weight | Reps |". The parser reads those as a
## table (QuickLog._table_line). A bar typed inside a cell becomes a slash.
static func _tables_to_rows(html: String) -> String:
	var table_rx = RegEx.create_from_string("(?is)<table\\b.*?</table>")
	var row_rx = RegEx.create_from_string("(?is)<tr\\b.*?</tr>")
	var cell_rx = RegEx.create_from_string("(?is)<t[dh]\\b[^>]*>(.*?)</t[dh]>")
	var tag_rx = RegEx.create_from_string("(?s)<[^>]+>")
	var space_rx = RegEx.create_from_string("\\s+")
	var out = ""
	var pos = 0
	for tm in table_rx.search_all(html):
		out += html.substr(pos, tm.get_start() - pos) + "\n"
		for rm in row_rx.search_all(tm.get_string(0)):
			var cells = PackedStringArray()
			for cm in cell_rx.search_all(rm.get_string(0)):
				var txt = tag_rx.sub(cm.get_string(1).replace("|", "/"), " ", true).replace("&nbsp;", " ")
				cells.append(space_rx.sub(txt, " ", true).strip_edges())
			if not cells.is_empty():
				out += "| " + " | ".join(cells) + " |\n"
		pos = tm.get_end()
	return out + html.substr(pos)


## A picture found in the note, small, for the review sheet (null when unknown).
func image_texture(ref: String):
	if _image_tex.has(ref):
		return _image_tex[ref]
	if not _images.has(ref):
		return null
	var img = _app().decode_image(_images[ref], ref)
	if img == null:
		return null
	var longest = max(img.get_width(), img.get_height())
	if longest > 320:
		var k = 320.0 / float(longest)
		img.resize(maxi(1, int(round(img.get_width() * k))), maxi(1, int(round(img.get_height() * k))), Image.INTERPOLATE_BILINEAR)
	var tex = ImageTexture.create_from_image(img)
	_image_tex[ref] = tex
	return tex


## Read pasted text the same way (nothing is fetched). Returns the result.
func check_text(text: String) -> Dictionary:
	_readings = {}
	_tables = []
	_got_text(text, false, false)
	return _last


func _got_text(text: String, silent: bool, from_source: bool) -> void:
	var head = text.substr(0, 800).strip_edges().to_lower()
	if head.begins_with("<!doctype") or head.begins_with("<html") or head.contains("<html"):
		_finish({"ok": false, "error": NOT_SHARED}, silent)
		return
	last_text = text
	var parsed = QuickLog.parse_any(text, parse_opts())
	if from_source and _unread != "":
		parsed.problems.append({"line": "pictures", "why": _unread, "picture": ""})
		_unread = ""
	var imported = settings().get("imported", {})
	var split = PhoneInbox.split_entries(parsed.entries, imported)
	_resolve_updates(split.fresh)
	if from_source:
		_source_keys = split.counts
		var patch = {"lastChecked": _app().now_ms()}
		# A cleared note starts clean.
		if parsed.entries.is_empty() and not imported.is_empty():
			patch["imported"] = {}
		_app().update_inbox(patch)
	_finish({"ok": true, "error": "", "fresh": split.fresh, "already": split.already, "problems": parsed.problems}, silent)


## Multiset rule: per key, the first imported[key] occurrences are already imported.
## Returns {"fresh", "already", "counts": {key: occurrences}}.
static func split_entries(entries: Array, imported: Dictionary) -> Dictionary:
	var seen = {}
	var fresh = []
	var already = 0
	for e in entries:
		var n = int(seen.get(e.key, 0)) + 1
		seen[e.key] = n
		if n <= int(imported.get(e.key, 0)):
			already += 1
		else:
			fresh.append(e)
	# An imported entry whose text is gone while a new one sits under the same
	# date line: the player edited a day after importing it. The new entry
	# remembers the old key (`replaces_key`); `_resolve_updates` then finds the
	# session it came from so importing updates it instead of adding a copy.
	var gone = {}
	for k in imported:
		if not seen.has(k):
			var pf = QuickLog.key_prefix(str(k))
			if not gone.has(pf):
				gone[pf] = []
			gone[pf].append(str(k))
	for e in fresh:
		var pf = QuickLog.key_prefix(e.key)
		if gone.has(pf) and not gone[pf].is_empty():
			e["replaces_key"] = gone[pf].pop_front()
			e.warnings.append(CHANGED_DAY)
			e["skip"] = true
	return {"fresh": fresh, "already": already, "counts": seen}


## Entries that replace an edited day: find the session / check-in that was
## imported from the old text (it carries `inboxKey`) and mark the update.
func _resolve_updates(fresh: Array) -> void:
	var app = _app()
	for e in fresh:
		if not e.has("replaces_key"):
			continue
		var found = null
		if e.kind == "reading":
			# A reading line edited after it was imported: the day changes by the difference.
			found = Reading.entry_with_key(app.reading(), str(e.replaces_key))
		else:
			var pool = app.sessions() if e.kind == "session" else app.body()
			for x in pool:
				if str(x.get("inboxKey", "")) == str(e.replaces_key):
					found = x
		if found == null:
			continue
		if str(found.get("date", "")) != str(e.date):
			# The same words under an undated (or "today") line on another day: a
			# new entry, not an edit of the old one.
			e.erase("replaces_key")
			e.warnings.erase(CHANGED_DAY)
			e.erase("skip")
			continue
		# Another workout of that day, written under the same date after the note
		# was cleared, is a second session: never an edit that replaces the first.
		if e.kind == "session" and str(e.data.get("discipline", "")) == "lift" and str(found.get("discipline", "")) == "lift" and not PhoneInbox.same_workout(found, e.data):
			e.erase("replaces_key")
			e.warnings.erase(CHANGED_DAY)
			e.erase("skip")
			continue
		e["replaces"] = found.id
		e.warnings.erase(CHANGED_DAY)
		e.warnings.append(UPDATES)
		e.erase("skip")
	# A new lift on a day that already has one in the log: said, so a wrong date shows.
	for e in fresh:
		if e.kind != "session" or str(e.data.get("discipline", "")) != "lift" or e.has("replaces"):
			continue
		for x in app.sessions():
			if str(x.get("discipline", "")) == "lift" and str(x.get("date", "")) == str(e.date):
				e.warnings.append(SECOND_LIFT)
				break


## Is a lift entry a change to the session imported earlier for the same day,
## or another workout of that day? The note is often cleared between visits and
## the same date written again for the next workout: that must be a new
## session, never an edit that would replace the first. An edit keeps the
## exercises, adds to them or drops some; another workout shares few (a daily
## PT exercise at most). Names are compared by LiftMatch.key.
static func same_workout(old: Dictionary, new_data: Dictionary) -> bool:
	var a = {}
	for ex in old.get("exercises", []):
		a[LiftMatch.key(str(ex.get("name", "")))] = true
	var b = {}
	for ex in new_data.get("exercises", []):
		b[LiftMatch.key(str(ex.get("name", "")))] = true
	if a.is_empty() or b.is_empty():
		return true
	var shared = 0
	for k in b:
		if a.has(k):
			shared += 1
	return shared == a.size() or shared == b.size() or shared * 2 >= maxi(a.size(), b.size())


## How many entries the note holds when everything in it is already imported
## (0 while anything is new, unread or unset): the Home card then says it is
## safe to clear the note.
func note_all_in() -> int:
	if not bool(_last.get("ok", false)) or not _last.fresh.is_empty():
		return 0
	if str(settings().get("source", "")).strip_edges() == "":
		return 0
	return int(_last.already)


func _finish(result: Dictionary, silent: bool) -> void:
	var t = Time.get_time_dict_from_system()
	var at = "%02d:%02d" % [int(t.hour), int(t.minute)]
	if result.ok:
		_last = result
		var bits = ["%d new" % result.fresh.size()]
		if result.already > 0:
			bits.append("%d already imported" % result.already)
		if not result.problems.is_empty():
			bits.append("%d line%s not understood" % [result.problems.size(), "" if result.problems.size() == 1 else "s"])
		status = "Checked at %s: %s." % [at, ", ".join(PackedStringArray(bits))]
	elif not silent:
		status = "Checked at %s: %s" % [at, result.error]
	checked.emit(result)
	if result.ok and not result.fresh.is_empty():
		_app().changed.emit()  # the Home card appears


## Turn entries into sessions / check-ins, add them to the log and remember their keys.
func import_entries(entries: Array) -> void:
	if entries.is_empty():
		return
	var app = _app()
	var now = app.now_ms()
	var sessions = []
	var bodies = []
	var imported = settings().get("imported", {}).duplicate()
	# Keys no longer in the note are forgotten (only known after reading the note itself).
	if _source_keys != null:
		for k in imported.keys():
			if not _source_keys.has(k):
				imported.erase(k)
	# A lift name the review showed (taken as one of the player's lifts, or as
	# a new one) and that was imported like that is what was meant: remember it.
	var names = settings().get("names", {}).duplicate()
	var learned = false
	for e in entries:
		for pk in e.get("names", []):
			if not names.has(str(pk.key)):
				names[str(pk.key)] = str(pk.name) if str(pk.kind) == "match" else ""
				learned = true
	if learned:
		app.update_inbox({"names": names})
	var updates = []
	var body_updates = []
	var read_new = 0
	var read_up = 0
	var i = 0
	for e in entries:
		if e.kind == "reading":
			# Pages read: no session and no reel, they join that day's reading.
			var same_day = e.has("replaces")
			app.import_reading(str(e.date), int(e.data.get("pages", 0)), str(e.key), str(e.replaces_key) if same_day else "")
			if e.has("replaces_key"):
				imported.erase(e.replaces_key)
			imported[e.key] = int(imported.get(e.key, 0)) + 1
			if same_day:
				read_up += 1
			else:
				read_new += 1
			continue
		var d = e.data.duplicate(true)
		d["date"] = e.date
		d["createdAt"] = now + i
		d["inboxKey"] = e.key
		i += 1
		if e.has("replaces_key"):
			imported.erase(e.replaces_key)
		if e.kind == "session":
			d["source"] = "manual"
			var old = app.session_by_id(e.replaces) if e.has("replaces") else null
			if old != null:
				var ns = app.build_session(d)
				ns["id"] = old.id
				ns["createdAt"] = old.createdAt
				updates.append(ns)
			else:
				sessions.append(app.build_session(d))
		else:
			var oldb = app.body_by_id(e.replaces) if e.has("replaces") else null
			d["id"] = oldb.id if oldb != null else Rng.uid("b")
			if oldb != null:
				d["createdAt"] = oldb.createdAt
			# Pictures from the note become this check-in's photos: front, side, back in order.
			var refs = d.get("photoRefs", [])
			d.erase("photoRefs")
			var photos = {}
			for j in range(mini(refs.size(), TT.PHOTO_ANGLES.size())):
				var ref = str(refs[j])
				if _images.has(ref):
					var pid = app.import_photo_bytes(_images[ref], ref)
					if pid != "":
						photos[TT.PHOTO_ANGLES[j]] = pid
			if not photos.is_empty():
				d["photos"] = photos
			elif oldb != null and oldb.get("photos") is Dictionary:
				d["photos"] = oldb.photos.duplicate()
			if oldb != null:
				body_updates.append(d)
			else:
				bodies.append(d)
		imported[e.key] = int(imported.get(e.key, 0)) + 1
	app.update_inbox({"imported": imported})
	# Reviewed: anything left out comes back on the next check.
	_last.fresh = []
	for u in updates:
		app.update_session(u)
	for b in body_updates:
		app.update_body(b)
	if not sessions.is_empty():
		app.commit_sessions(sessions, "Imported from your phone")
	for b in bodies:
		app.commit_body(b)
	var n_up = updates.size() + body_updates.size() + read_up
	var n_new = entries.size() - n_up
	# Pages have no results reel: say that they arrived (an update has its own line below).
	if read_new > 0 and sessions.is_empty() and bodies.is_empty():
		app.toast("Reading from your phone is in", "good", "book")
	var bits = []
	if n_new > 0:
		bits.append("imported %d entr%s" % [n_new, "y" if n_new == 1 else "ies"])
	if n_up > 0:
		bits.append("updated %d" % n_up)
	status = ", ".join(PackedStringArray(bits)).capitalize() + "."
	if n_up > 0 and sessions.is_empty() and bodies.is_empty():
		app.toast("Updated %d entr%s from your phone" % [n_up, "y" if n_up == 1 else "ies"], "good", "check")
	_clear_after_import.call_deferred()


# ---------------------------------------------------------------------------
# Emptying the table (DocClear)
# ---------------------------------------------------------------------------

## {"url", "token", "on" (clear after an import), "plan" (write the day's plan
## at midnight)}.
func clear_settings() -> Dictionary:
	var c = settings().get("clear")
	if not c is Dictionary:
		return {"url": "", "token": "", "on": false, "plan": true}
	return {"url": str(c.get("url", "")), "token": str(c.get("token", "")), "on": bool(c.get("on", false)), "plan": bool(c.get("plan", true))}


func set_clear(patch: Dictionary) -> void:
	var c = clear_settings()
	c.merge(patch, true)
	_app().update_inbox({"clear": c})


## The token the script carries (made the first time it is asked for).
func clear_token() -> String:
	var c = clear_settings()
	if str(c.token) == "":
		c.token = DocClear.new_token()
		set_clear({"token": c.token})
	return str(c.token)


## Can the table be emptied (a script link set)?
func can_clear() -> bool:
	var c = clear_settings()
	return DocClear.looks_right(str(c.url)) and str(c.token) != ""


func clearing() -> bool:
	return _clearing


## The table rows to empty now: rows of imported entries in the note as it
## was last read (DocClear.plan).
func clear_rows() -> Array:
	if _tables.is_empty() or last_text == "":
		return []
	var parsed = QuickLog.parse_any(last_text, parse_opts())
	return DocClear.plan(_tables, parsed.entries, settings().get("imported", {}), _app().today)


## Empty the imported rows of the note's table. Awaitable: DocClear.send's
## result, or {"ok": true, "cleared": 0} when there is nothing to clear. The
## note is read again afterwards (quietly).
func clear_imported() -> Dictionary:
	if _clearing or not can_clear():
		return {"ok": false, "error": "Clearing is not set up yet." if not can_clear() else "Already clearing."}
	var rows = clear_rows()
	if rows.is_empty():
		return {"ok": true, "cleared": 0, "skipped": 0}
	_clearing = true
	var c = clear_settings()
	var res = await DocClear.send(self, str(c.url), str(c.token), rows)
	_clearing = false
	if res.ok:
		var bits = ["cleared %d row%s of the note's table" % [res.cleared, "" if int(res.cleared) == 1 else "s"]]
		if int(res.skipped) > 0:
			bits.append("%d left: changed since it was read" % res.skipped)
		var said = ", ".join(PackedStringArray(bits))
		status = said.left(1).to_upper() + said.substr(1) + "."
		check(true)
	return res


## Write today's plan into the note's table now (the midnight run does it by
## itself). Awaitable: DocClear.send's result.
func write_plan_now() -> Dictionary:
	if not can_clear():
		return {"ok": false, "error": "Clearing is not set up yet."}
	var c = clear_settings()
	var res = await DocClear.send_plan(self, str(c.url), str(c.token), _app().plan(), _app().weight_unit())
	if res.ok:
		check(true)
	return res


## After an import: empty what came in, when switched on.
func _clear_after_import() -> void:
	if not clear_settings().on or not can_clear():
		return
	var res = await clear_imported()
	if not res.ok:
		_app().toast("Could not clear the note's table: %s" % str(res.error), "bad", "warning")
	elif int(res.get("cleared", 0)) > 0:
		_app().toast("Cleared %d row%s of the note's table" % [res.cleared, "" if int(res.cleared) == 1 else "s"], "good", "check")


## "Last checked Nov 14, 18:32" from the saved time (local), or "" when never.
func last_checked_text() -> String:
	var ms = int(settings().get("lastChecked", 0))
	if ms <= 0:
		return ""
	var bias = int(Time.get_time_zone_from_system().get("bias", 0))
	var local = int(ms / 1000.0) + bias * 60
	var dt = Time.get_datetime_dict_from_unix_time(local)
	var key = "%04d-%02d-%02d" % [int(dt.year), int(dt.month), int(dt.day)]
	return "Last checked %s, %02d:%02d" % [Dates.format_date(key), int(dt.hour), int(dt.minute)]
