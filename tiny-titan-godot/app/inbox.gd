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
## The note is never cleared by the game, so what was imported is remembered as
## {key: count} in saved.inbox.imported: for each key the first `count`
## occurrences in the text are already in the log, any further ones are new.

## result = {"ok", "error", "fresh": [entry...], "already": int, "problems": [...]}
signal checked(result)

const TIMEOUT_SEC = 30.0
const NOT_SHARED = "That link is not shared. In Google Docs: Share → General access → Anyone with the link."
const CHANGED_DAY = "this day changed after you imported it; importing adds it again (left out unless you tick it)"

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


func _app():
	return get_parent()


func _ready() -> void:
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
	for x in LiftHistory.exercise_suggestions(app.sessions(), Summary.DEFAULT_EXERCISES):
		names.append(x.name)
	var loaded = {}
	for s in app.sessions():
		if s.discipline == "lift":
			for ex in s.get("exercises", []):
				for st in ex.sets:
					if float(st.get("weightKg", 0)) > 0.0:
						loaded[Xp.normalize_exercise(ex.name)] = true
	return {"today": app.today, "weightUnit": app.weight_unit(), "distanceUnit": app.distance_unit(),
		"exercises": names, "loaded": loaded.keys()}


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
		elif str(name).begins_with("images/"):
			images[str(name)] = z.read_file(name)
	z.close()
	DirAccess.remove_absolute(path)
	_images = images
	_image_tex = {}
	_got_text(html_to_text(html), silent, true)


## Google's HTML export -> plain lines. Each picture becomes its own line,
## "photo images/image1.jpg", which the parser turns into a progress photo.
static func html_to_text(html: String) -> String:
	var h = html
	for tag in ["head", "style", "script"]:
		h = RegEx.create_from_string("(?is)<%s\\b.*?</%s>" % [tag, tag]).sub(h, "", true)
	h = RegEx.create_from_string("(?is)<img\\b[^>]*\\bsrc=\"([^\"]+)\"[^>]*>").sub(h, "\nphoto $1\n", true)
	h = RegEx.create_from_string("(?is)<br\\s*/?>|</(?:p|div|li|tr|h[1-6]|table)>").sub(h, "\n", true)
	h = RegEx.create_from_string("(?is)</t[dh]>").sub(h, " ", true)
	h = RegEx.create_from_string("(?s)<[^>]+>").sub(h, "", true)
	h = h.replace("&nbsp;", " ").replace("&quot;", "\"").replace("&#39;", "'").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
	var m = RegEx.create_from_string("&#(\\d+);")
	for hit in m.search_all(h):
		h = h.replace(hit.get_string(0), char(int(hit.get_string(1))))
	return h


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
	_got_text(text, false, false)
	return _last


func _got_text(text: String, silent: bool, from_source: bool) -> void:
	var head = text.substr(0, 800).strip_edges().to_lower()
	if head.begins_with("<!doctype") or head.begins_with("<html") or head.contains("<html"):
		_finish({"ok": false, "error": NOT_SHARED}, silent)
		return
	last_text = text
	var parsed = QuickLog.parse_any(text, parse_opts())
	var imported = settings().get("imported", {})
	var split = PhoneInbox.split_entries(parsed.entries, imported)
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
	# date line: the player edited a day after importing it.
	var gone = {}
	for k in imported:
		if not seen.has(k):
			gone[QuickLog.key_prefix(str(k))] = true
	for e in fresh:
		if gone.has(QuickLog.key_prefix(e.key)):
			e.warnings.append(CHANGED_DAY)
			e["skip"] = true
	return {"fresh": fresh, "already": already, "counts": seen}


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
	var i = 0
	for e in entries:
		var d = e.data.duplicate(true)
		d["date"] = e.date
		d["createdAt"] = now + i
		i += 1
		if e.kind == "session":
			d["source"] = "manual"
			sessions.append(app.build_session(d))
		else:
			d["id"] = Rng.uid("b")
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
			bodies.append(d)
		imported[e.key] = int(imported.get(e.key, 0)) + 1
	app.update_inbox({"imported": imported})
	# Reviewed: anything left out comes back on the next check.
	_last.fresh = []
	if not sessions.is_empty():
		app.commit_sessions(sessions, "Imported from your phone")
	for b in bodies:
		app.commit_body(b)
	status = "Imported %d entr%s." % [entries.size(), "y" if entries.size() == 1 else "ies"]


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
