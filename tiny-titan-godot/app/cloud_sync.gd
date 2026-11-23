class_name CloudSync
extends Node
## The save, shared by the PC and the phone app through the note's script
## (app/doc_script.js, version 4: GET ?save=get, POST {save: "put"}), so both
## have the same log. App adds this node; it does nothing until it is switched
## on (Settings -> Phone app) or the phone opens a connect link (#c=...).
##
## Files next to the save (never synced themselves):
##   sync.json       {on, url, token, rev, at, by}: the script's link and token
##                   (on the PC they come from the phone note's settings), the
##                   copy we last agreed on (rev) and when
##   sync_base.json  that copy itself: the base of a three-way merge
##
## A sync: fetch the script's copy. When it moved on since our rev, merge it
## with ours (SaveMerge: base, ours, theirs; nothing logged on either side is
## lost) and take on the result here (_app().apply_synced, after a backup). Then,
## when ours differs from the script's, send it, naming the rev it was made
## from; when the script's copy moved on meanwhile, the whole thing runs again.
## When: a moment after start, a few seconds after every change, every few
## minutes while open, and when the app comes back to the front.

signal status_changed

## Where the web build is published (tools/publish_web.py: the tiny-titan repo's
## GitHub Pages). The PC's "Send to phone" link is APP_URL + "#c=" + connect_code().
const APP_URL = "https://jakejenks3.github.io/tiny-titan/"
const POLL_SEC = 180.0
const DEBOUNCE_SEC = 4.0
const MIN_SCRIPT = 4
const KEEP_SYNC_BACKUPS = 12
## A sync that would take away more sessions than this at once is not made
## (deleting a few is normal, even quickly; a copy missing many is a mistake).
const MAX_GONE = 10

## "off", "idle", "busy", "ok", "error", "old" (the script needs updating).
var status = "off"
var error = ""
## What is in the way of the progress photos ("" = nothing): the save can sync
## while the photos cannot (a script before version 5, Drive not allowed yet).
var photo_note = ""
var _cfg = {}
var _busy = false
var _again = false
var _applying = false
var _debounce: Timer
var _poll: Timer


## App (this node's parent): named through the tree, so the class compiles
## before the autoloads exist (tests run with --script).
func _app():
	return get_parent()


func _ready() -> void:
	_cfg = _load_json(_cfg_path(), {})
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = DEBOUNCE_SEC
	_debounce.timeout.connect(func(): sync_now("change"))
	add_child(_debounce)
	_poll = Timer.new()
	_poll.wait_time = POLL_SEC
	_poll.timeout.connect(func(): sync_now("poll"))
	add_child(_poll)
	_poll.start()
	# The phone opened a connect link: take the script's link and token from it.
	var code = _link_code()
	if code != "" and connect_with(code, false, true):
		return
	status = "idle" if is_on() else "off"
	if is_on():
		get_tree().create_timer(1.5).timeout.connect(func(): sync_now("start"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_on():
		if Time.get_unix_time_from_system() - float(_cfg.get("at", 0)) / 1000.0 > 20.0:
			sync_now("focus")
	elif (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST) and is_on():
		# Leaving: what is waiting to go goes now.
		if _debounce != null and not _debounce.is_stopped():
			_debounce.stop()
			sync_now("leave")


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func is_on() -> bool:
	return bool(_cfg.get("on", false)) and _endpoint().url != ""


## Switched on and off from Settings (the PC uses the phone note's script link).
func set_on(on: bool) -> void:
	_cfg["on"] = on
	_save_cfg()
	status = "idle" if is_on() else "off"
	error = ""
	status_changed.emit()
	if is_on():
		sync_now("switched on")


## The script's link and token: our own (from a connect link) or the phone note's.
func _endpoint() -> Dictionary:
	var u = str(_cfg.get("url", ""))
	var t = str(_cfg.get("token", ""))
	if u == "" and _app().saved is Dictionary:
		var cl = _app().saved.get("inbox", {}).get("clear", {})
		if cl is Dictionary:
			u = str(cl.get("url", ""))
			t = str(cl.get("token", ""))
	return {"url": u.strip_edges(), "token": t.strip_edges()}


## The code a phone connects with: the script's link and token, in a link-safe form.
func connect_code() -> String:
	var ep = _endpoint()
	if ep.url == "" or ep.token == "":
		return ""
	var raw = JSON.stringify({"u": ep.url, "t": ep.token})
	return Marshalls.utf8_to_base64(raw).replace("+", "-").replace("/", "_").replace("=", "")


## The link the PC sends to the phone ("" until the web app is published).
func app_link() -> String:
	var code = connect_code()
	if APP_URL == "" or code == "":
		return ""
	return APP_URL + "#c=" + code


static func parse_code(text: String) -> Dictionary:
	var s = text.strip_edges()
	var at = s.find("#c=")
	if at >= 0:
		s = s.substr(at + 3)
	s = s.split("&")[0].strip_edges()
	if s == "":
		return {}
	for i in range(s.length()):
		var ch = s[i]
		if not (ch.to_lower() != ch.to_upper() or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_" or ch == "+" or ch == "/" or ch == "="):
			return {}
	s = s.trim_suffix("=").trim_suffix("=")
	if s.length() < 8 or s.length() % 4 == 1:
		return {}
	s = s.replace("-", "+").replace("_", "/")
	while s.length() % 4 != 0:
		s += "="
	var raw = Marshalls.base64_to_utf8(s)
	var d = JSON.parse_string(raw) if raw != "" else null
	if not (d is Dictionary) or str(d.get("u", "")) == "" or str(d.get("t", "")) == "":
		return {}
	if not str(d.u).begins_with("http"):
		return {}
	return {"url": str(d.u), "token": str(d.t)}


## Connect with a code or a link that holds one; false when it is not one.
## `from_link`: the page was opened with it (every launch from the Home Screen):
## the same connection as before keeps its switch as the player left it.
func connect_with(text: String, toast: bool = true, from_link: bool = false) -> bool:
	var ep = parse_code(text)
	if ep.is_empty():
		if toast:
			_app().toast("That is not a Tiny Titan link or code", "bad", "warning")
		return false
	var same = str(_cfg.get("url", "")) == ep.url and str(_cfg.get("token", "")) == ep.token
	if same and from_link:
		status = "idle" if is_on() else "off"
		if is_on():
			get_tree().create_timer(1.5).timeout.connect(func(): sync_now("start"))
		return true
	_cfg["url"] = ep.url
	_cfg["token"] = ep.token
	_cfg["on"] = true
	if not same:
		# Another script: what we agreed with before means nothing there.
		_cfg["rev"] = 0
		_remove(_base_path())
	_save_cfg()
	status = "idle"
	sync_now("connect")
	return true


## The #c=... of the page's link (web build only).
func _link_code() -> String:
	if not OS.has_feature("web"):
		return ""
	var app = JavaScriptBridge.get_interface("ttApp")
	if app == null:
		return ""
	var h = str(app.hash())
	return h if h.contains("c=") else ""


func status_text() -> String:
	match status:
		"off":
			return "Off"
		"busy":
			return "Syncing..."
		"old":
			return "The note's script needs the new version"
		"error":
			return "Could not sync: %s" % error
	var at = float(_cfg.get("at", 0))
	if at <= 0.0:
		return "Not synced yet"
	var mins = int((Time.get_unix_time_from_system() - at / 1000.0) / 60.0)
	if mins < 1:
		return "Synced just now"
	if mins < 60:
		return "Synced %d min ago" % mins
	if mins < 60 * 24:
		return "Synced %d h ago" % int(mins / 60.0)
	return "Synced %d days ago" % int(mins / 1440.0)


## The save changed here (App._write): send it a little later.
func local_changed() -> void:
	if _applying or not is_on() or _debounce == null:
		return
	_debounce.start()


# ---------------------------------------------------------------------------
# Syncing
# ---------------------------------------------------------------------------

func sync_now(_why: String = "") -> void:
	if not is_on():
		return
	if _busy:
		_again = true
		return
	_busy = true
	status = "busy"
	status_changed.emit()
	var ok = await _run()
	if ok:
		await _sync_photos()
	_busy = false
	if ok:
		status = "ok"
		error = ""
	status_changed.emit()
	if _again:
		_again = false
		call_deferred("sync_now", "again")


func _run() -> bool:
	var ep = _endpoint()
	var q = ep.url + ("&" if ep.url.contains("?") else "?") + "token=" + ep.token.uri_encode()
	for attempt in range(3):
		var got = await _json(HTTPClient.METHOD_GET, q + "&save=get", "")
		if not bool(got.get("ok", false)):
			return _fail(str(got.get("error", "no answer")))
		if not got.has("rev"):
			# A script from before version 4 answers without one.
			status = "old"
			error = "update the note's script"
			return false
		var remote_rev = int(got.rev)
		var local = SaveMerge.plain(_app().saved)
		var base = _load_json(_base_path(), null)
		var merged = local
		var moved = remote_rev > 0 and remote_rev != int(_cfg.get("rev", 0))
		if remote_rev > 0 and (moved or fresh(local)):
			var theirs = decode(str(got.get("data", "")))
			if theirs == null:
				return _fail("the copy in the script could not be read")
			if fresh(local):
				# A new phone (or a save just reset): the copy as it is, never
				# an empty save over a full one.
				merged = theirs
			else:
				merged = SaveMerge.merge(base if base is Dictionary else {}, local, theirs)
			var gone = maxi(_gone(local, merged), _gone(theirs, merged))
			if gone > MAX_GONE:
				return _fail("%d sessions would be removed at once, so nothing was synced (your data is untouched)" % gone)
			if not SaveMerge.same(merged, local):
				if not _apply(merged):
					return _fail("the merged copy could not be used")
				merged = SaveMerge.plain(_app().saved)
			_cfg["rev"] = remote_rev
			_save_json(_base_path(), theirs)
			_save_cfg()
			if SaveMerge.same(merged, theirs):
				return _done()
		elif remote_rev > 0 and base is Dictionary and SaveMerge.same(local, base):
			return _done()
		elif remote_rev > 0 and base is Dictionary and _gone(base, merged) > MAX_GONE:
			return _fail("%d sessions would be removed at once, so nothing was synced (your data is untouched)" % _gone(base, merged))
		if remote_rev > 0 and fresh(merged):
			return _fail("this save is empty and the script's is not")
		var res = await _json(HTTPClient.METHOD_POST, ep.url, JSON.stringify({
			"token": ep.token, "save": "put", "base": remote_rev, "data": encode(merged),
			"by": "phone" if OS.has_feature("web") else "PC"}))
		if bool(res.get("ok", false)) and res.has("rev"):
			_cfg["rev"] = int(res.rev)
			_save_json(_base_path(), merged)
			return _done()
		if bool(res.get("conflict", false)):
			continue
		if str(res.get("error", "")) == "nothing to do":
			status = "old"
			error = "update the note's script"
			return false
		return _fail(str(res.get("error", "no answer")))
	return _fail("the copy kept changing; try again")


## Progress photos (files next to the save; a check-in only holds their ids):
## the ones the save names that are not on this device are fetched from the
## script's Drive folder, the ones that are here and not there are sent. One
## listing first, and only when there is something to do. A photo is never
## deleted anywhere by this.
func _sync_photos() -> void:
	var app = _app()
	var known = _cfg.get("photos", {})
	if not (known is Dictionary):
		known = {}
	var down = []
	var up = []
	for raw in app.referenced_photo_ids():
		var id = str(raw)
		if down.has(id) or up.has(id):
			continue
		if not app.has_photo(id):
			down.append(id)
		elif not known.has(id):
			up.append(id)
	if down.is_empty() and up.is_empty():
		photo_note = ""
		return
	var ep = _endpoint()
	var q = ep.url + ("&" if ep.url.contains("?") else "?") + "token=" + ep.token.uri_encode()
	var listed = await _json(HTTPClient.METHOD_GET, q + "&photo=list", "")
	if not bool(listed.get("ok", false)) or not (listed.get("photos") is Array):
		# A script before version 5 answers something else; Drive not allowed answers an error page.
		photo_note = "Photos need the note's newer script (version 5): Phone inbox, Options, Copy the script" if bool(listed.get("ok", false)) else "Photos could not sync: %s" % str(listed.get("error", "no answer"))
		return
	var remote = {}
	for id in listed.photos:
		remote[str(id)] = true
	var arrived = 0
	var trouble = ""
	for id in down:
		if not remote.has(id):
			continue
		var got = await _json(HTTPClient.METHOD_GET, q + "&photo=get&id=" + str(id).uri_encode(), "")
		var bytes = Marshalls.base64_to_raw(str(got.get("data", ""))) if bool(got.get("ok", false)) else PackedByteArray()
		var img = Image.new()
		if bytes.is_empty() or img.load_jpg_from_buffer(bytes) != OK:
			trouble = "a photo could not be fetched"
			continue
		DirAccess.make_dir_recursive_absolute(app.PHOTO_DIR)
		var f = FileAccess.open(app.photo_path(id), FileAccess.WRITE)
		if f == null:
			trouble = "a photo could not be saved here"
			continue
		f.store_buffer(bytes)
		f.close()
		arrived += 1
	for id in up:
		if remote.has(id):
			continue
		var bytes = FileAccess.get_file_as_bytes(app.photo_path(id))
		if bytes.is_empty():
			continue
		var res = await _json(HTTPClient.METHOD_POST, ep.url, JSON.stringify({"token": ep.token, "photo": "put", "id": id, "data": Marshalls.raw_to_base64(bytes)}))
		if bool(res.get("ok", false)):
			remote[id] = true
		else:
			trouble = "a photo could not be sent (%s)" % str(res.get("error", "no answer"))
			break
	_cfg["photos"] = remote
	_save_cfg()
	var waiting = 0
	for id in down:
		if not app.has_photo(id):
			waiting += 1
	if trouble != "":
		photo_note = "Photos: " + trouble
	elif waiting > 0:
		photo_note = "%d photo%s not sent by the other device yet" % [waiting, "" if waiting == 1 else "s"]
	else:
		photo_note = ""
	if arrived > 0:
		app.photos_arrived()


func _done() -> bool:
	_cfg["at"] = int(Time.get_unix_time_from_system() * 1000.0)
	_save_cfg()
	return true


func _fail(why: String) -> bool:
	status = "error"
	error = why
	return false


## Take on the merged save here, after keeping a copy of the one it replaces.
func _apply(data: Dictionary) -> bool:
	_backup()
	_applying = true
	var ok = _app().apply_synced(data)
	_applying = false
	return ok


func _backup() -> void:
	if not FileAccess.file_exists(_app().SAVE_PATH):
		return
	DirAccess.make_dir_recursive_absolute(_app().BACKUP_DIR)
	var stamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	DirAccess.copy_absolute(_app().SAVE_PATH, "%s/sync-%s.json" % [_app().BACKUP_DIR, stamp])
	var d = DirAccess.open(_app().BACKUP_DIR)
	if d == null:
		return
	var mine = Array(d.get_files()).filter(func(f): return str(f).begins_with("sync-"))
	mine.sort()
	while mine.size() > KEEP_SYNC_BACKUPS:
		d.remove(mine.pop_front())


## How many sessions of `before` are not in `after`.
static func _gone(before: Dictionary, after: Dictionary) -> int:
	var have = {}
	for s in after.get("sessions", []):
		if s is Dictionary:
			have[str(s.get("id", ""))] = true
	var n = 0
	for s in before.get("sessions", []):
		if s is Dictionary and not have.has(str(s.get("id", ""))):
			n += 1
	return n


## A save with nothing in it yet (a phone before it connects).
static func fresh(d: Dictionary) -> bool:
	if d.get("profile") != null:
		return false
	for k in ["sessions", "body", "reading", "claims", "purchases"]:
		var v = d.get(k, [])
		if v is Array and not v.is_empty():
			return false
	return true


static func encode(d: Dictionary) -> String:
	var bytes = JSON.stringify(d).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return Marshalls.raw_to_base64(bytes)


static func decode(s: String):
	if s == "":
		return null
	var raw = Marshalls.base64_to_raw(s)
	if raw.is_empty():
		return null
	var text = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var d = JSON.parse_string(text)
	return d if d is Dictionary else null


# ---------------------------------------------------------------------------
# HTTP: a GET follows Google's redirect by itself. A POST is answered with a
# redirect to where the answer can be fetched: the browser follows it, the PC
# fetches it (GET) itself.
# ---------------------------------------------------------------------------

func _json(method: int, url: String, body: String) -> Dictionary:
	var r = await _http(method, url, body)
	if method == HTTPClient.METHOD_POST and int(r.get("code", 0)) in [301, 302, 303, 307, 308]:
		var loc = ""
		for h in r.get("headers", PackedStringArray()):
			if str(h).to_lower().begins_with("location:"):
				loc = str(h).substr(9).strip_edges()
		if loc == "":
			return {"ok": false, "error": "no answer"}
		r = await _http(HTTPClient.METHOD_GET, loc, "")
	if not bool(r.get("sent", false)):
		return {"ok": false, "error": str(r.get("error", "no connection"))}
	if int(r.code) != 200:
		return {"ok": false, "error": "the script answered %d" % int(r.code)}
	var d = JSON.parse_string(PackedByteArray(r.body).get_string_from_utf8())
	if not (d is Dictionary):
		# Google's own error page: no doPost (a script before version 4), or not deployed.
		return {"ok": false, "error": "nothing to do" if method == HTTPClient.METHOD_POST else "the link did not answer with Tiny Titan data"}
	return d


func _http(method: int, url: String, body: String) -> Dictionary:
	var req = HTTPRequest.new()
	req.timeout = 30.0
	if method == HTTPClient.METHOD_POST and not OS.has_feature("web"):
		req.max_redirects = 0
	add_child(req)
	var headers = PackedStringArray(["Content-Type: text/plain;charset=utf-8"]) if method == HTTPClient.METHOD_POST else PackedStringArray()
	var err = req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"sent": false, "error": "could not start (%d)" % err}
	var r = await req.request_completed
	req.queue_free()
	var result = int(r[0])
	if result != HTTPRequest.RESULT_SUCCESS and not (result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED):
		return {"sent": false, "error": "no connection" if result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_TIMEOUT] else "request failed (%d)" % result}
	return {"sent": true, "code": int(r[1]), "headers": r[2], "body": r[3]}


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

func _cfg_path() -> String:
	return _app().DATA_DIR + "sync.json"


func _base_path() -> String:
	return _app().DATA_DIR + "sync_base.json"


func _save_cfg() -> void:
	_save_json(_cfg_path(), _cfg)


static func _load_json(path: String, fallback):
	if not FileAccess.file_exists(path):
		return fallback
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else fallback


static func _save_json(path: String, d: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
