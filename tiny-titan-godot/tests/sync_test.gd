extends SceneTree
## Test of game/save_merge.gd (three-way merges of the save) and, when Node.js
## is installed, app/cloud_sync.gd against the note's real script (version 4)
## run by tests/doc_clear_stub.js: the PC sends its save, a pretend phone adds a
## session while the PC adds another, both end up with both; a new phone takes
## the copy as it is; a sync that would delete many sessions is not made.
##   godot --headless --path . --script res://tests/sync_test.gd
## Prints SYNC: X/Y passed and exits with 1 when anything fails. Made-up data.

var passed = 0
var total = 0
## The App autoload (a --script test cannot name it).
var app = null


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _s(id: String, date: String, extra: Dictionary = {}) -> Dictionary:
	var s = {"id": id, "date": date, "discipline": "climb", "createdAt": 1, "climbs": [{"grade": 3, "result": "send", "count": 1}]}
	s.merge(extra, true)
	return s


func _ids(d: Dictionary) -> Array:
	var out = []
	for s in d.get("sessions", []):
		out.append(str(s.id))
	out.sort()
	return out


func _initialize() -> void:
	await process_frame
	app = root.get_node_or_null("App")
	_merge_tests()
	await _sync_tests()
	print("SYNC: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)


# ---------------------------------------------------------------------------
# SaveMerge
# ---------------------------------------------------------------------------

func _merge_tests() -> void:
	var base = {"updatedAt": 100, "sessions": [_s("a", "2026-03-01")], "settings": {"theme": "arcade", "weeklyGoal": 3}, "pt": {"x": {"name": "X", "perWeek": 3}}}
	var mine = base.duplicate(true)
	mine.updatedAt = 200
	mine.sessions.append(_s("b", "2026-03-02"))
	mine.settings.theme = "ember"
	var theirs = base.duplicate(true)
	theirs.updatedAt = 150
	theirs.sessions.append(_s("c", "2026-03-03"))
	theirs.settings.weeklyGoal = 4
	theirs.pt.erase("x")
	var m = SaveMerge.merge(base, mine, theirs)
	ok(_ids(m) == ["a", "b", "c"], "a session added on each side: both kept", _ids(m))
	ok(m.settings.theme == "ember" and int(m.settings.weeklyGoal) == 4, "each side's own setting change is kept", m.settings)
	ok(not m.pt.has("x"), "a mark removed on one side, untouched on the other, goes", m.pt)
	ok(int(m.updatedAt) == 200, "updatedAt is the later one")

	# Deleted on one side.
	var del_m = base.duplicate(true)
	del_m.sessions = []
	del_m.updatedAt = 300
	var same_t = base.duplicate(true)
	ok(_ids(SaveMerge.merge(base, del_m, same_t)) == [], "deleted here and untouched there: gone")
	var changed_t = base.duplicate(true)
	changed_t.sessions[0]["note"] = "felt good"
	var kept = SaveMerge.merge(base, del_m, changed_t)
	ok(_ids(kept) == ["a"] and str(kept.sessions[0].get("note", "")) == "felt good", "deleted here but changed there: kept, with the change", kept.sessions)

	# Changed on both sides: the newer save wins that record.
	var cm = base.duplicate(true)
	cm.sessions[0]["note"] = "mine"
	cm.updatedAt = 500
	var ct = base.duplicate(true)
	ct.sessions[0]["note"] = "theirs"
	ct.updatedAt = 400
	ok(str(SaveMerge.merge(base, cm, ct).sessions[0].note) == "mine", "changed on both sides: the newer save's version")
	ct.updatedAt = 600
	ok(str(SaveMerge.merge(base, cm, ct).sessions[0].note) == "theirs", "and the other way round")

	# Numbers: 3 and 3.0 are the same.
	var nb = {"sessions": [], "settings": {"weeklyGoal": 3}}
	var nm = {"sessions": [], "settings": {"weeklyGoal": 3.0}}
	var nt = {"sessions": [], "settings": {"weeklyGoal": 5}}
	ok(int(SaveMerge.merge(nb, nm, nt).settings.weeklyGoal) == 5, "3 and 3.0 count as unchanged")

	# Pages read: what each side added to a day is added up.
	var rb = {"sessions": [], "reading": [{"id": "r1", "date": "2026-03-01", "pages": 10, "createdAt": 1}]}
	var rm = {"sessions": [], "reading": [{"id": "r1", "date": "2026-03-01", "pages": 15, "createdAt": 1}, {"id": "r2", "date": "2026-03-02", "pages": 10, "createdAt": 2}]}
	var rt = {"sessions": [], "reading": [{"id": "r1", "date": "2026-03-01", "pages": 30, "createdAt": 1}, {"id": "r3", "date": "2026-03-02", "pages": 20, "createdAt": 3}]}
	var rr = SaveMerge.merge(rb, rm, rt)
	var pages = {}
	for e in rr.reading:
		pages[str(e.date)] = int(e.pages)
	ok(pages == {"2026-03-01": 35, "2026-03-02": 30}, "pages read: +5 here and +20 there make 35; a new day on both sides adds up", pages)

	# First sync with nothing in common: everything from both sides.
	var u = SaveMerge.merge({}, {"sessions": [_s("p", "2026-03-01")], "updatedAt": 1}, {"sessions": [_s("q", "2026-03-02")], "updatedAt": 2})
	ok(_ids(u) == ["p", "q"], "no common copy: both sides' sessions", _ids(u))
	ok(CloudSync.fresh({"profile": null, "sessions": []}) and not CloudSync.fresh({"profile": {"name": "x"}, "sessions": []}), "an empty save is fresh, a hero is not")
	var code = ""
	var parsed = CloudSync.parse_code("https://example.test/app/#c=" + Marshalls.utf8_to_base64(JSON.stringify({"u": "https://script.example/exec", "t": "tok"})).replace("+", "-").replace("/", "_").replace("=", ""))
	ok(parsed.get("url", "") == "https://script.example/exec" and parsed.get("token", "") == "tok", "a connect link reads back", parsed)
	ok(CloudSync.parse_code("hello").is_empty() and CloudSync.parse_code("").is_empty(), "anything else is not a code")
	var enc = CloudSync.encode({"sessions": [_s("z", "2026-01-01")], "n": 1})
	ok(_ids(CloudSync.decode(enc)) == ["z"] and CloudSync.decode("") == null, "a copy goes through gzip and base64 and back")
	if code != "":
		pass


# ---------------------------------------------------------------------------
# CloudSync against the script (Node.js)
# ---------------------------------------------------------------------------

func _sync_tests() -> void:
	var out = []
	if OS.execute("node", ["--version"], out) != 0:
		print("SYNC: Node.js not found, the script part is skipped")
		return
	if app == null:
		print("SYNC: no App, the script part is skipped")
		return
	var token = "synctesttoken"
	var dir = OS.get_environment("TINY_TITAN_DATA")
	if dir == "":
		print("SYNC: set TINY_TITAN_DATA to a throwaway folder")
		ok(false, "TINY_TITAN_DATA is set")
		return
	var sf = FileAccess.open(dir.path_join("sync_script.js"), FileAccess.WRITE)
	sf.store_string(DocClear.script_for(token))
	sf.close()
	var df = FileAccess.open(dir.path_join("sync_doc.json"), FileAccess.WRITE)
	df.store_string(JSON.stringify([[["Exercise", "Weight", "Set 1"], ["", "", ""]]]))
	df.close()
	var port = 22000 + randi() % 2000
	var pid = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/doc_clear_stub.js"), dir.path_join("sync_script.js"), dir.path_join("sync_doc.json"), str(port), "2026-03-10"])
	var url = "http://127.0.0.1:%d/exec" % port
	var up = false
	for i in range(50):
		var p = await _fetch_json(url + "?token=%s&save=head" % token)
		if p is Dictionary and p.has("rev"):
			up = true
			break
		await create_timer(0.1).timeout
	ok(up, "the script answers")
	if not up:
		OS.kill(pid)
		return

	# --- the PC sends its save ---------------------------------------------------
	var pc = app.empty_saved()
	pc.profile = {"name": "Tester"}
	pc.sessions = [_s("s1", "2026-03-01"), _s("s2", "2026-03-02")]
	app.replace_all(pc)
	var cloud = app.cloud
	cloud._debounce.stop()
	cloud._cfg = {"on": true, "url": url, "token": token}
	cloud._save_cfg()
	await cloud.sync_now("test")
	ok(cloud.status == "ok" and int(cloud._cfg.rev) == 1, "the PC's save goes to the script (rev 1)", [cloud.status, cloud.error, cloud._cfg.get("rev")])
	var copy = await _copy(url, token)
	ok(copy != null and _ids(copy) == ["s1", "s2"], "the script holds it", _ids(copy) if copy != null else null)

	# --- the phone adds a session while the PC adds another -----------------------
	copy.sessions.append(_s("phone1", "2026-03-03"))
	copy.updatedAt = float(copy.get("updatedAt", 0)) + 1000.0
	var put = await _put(url, token, copy, 1)
	ok(put is Dictionary and bool(put.get("ok", false)) and int(put.rev) == 2, "the phone sends its copy (rev 2)", put)
	app.saved.sessions.append(_s("pc1", "2026-03-04"))
	app._commit()
	cloud._debounce.stop()
	await cloud.sync_now("test")
	ok(cloud.status == "ok" and _ids(app.saved) == ["pc1", "phone1", "s1", "s2"], "the PC ends up with both new sessions", [cloud.status, cloud.error, _ids(app.saved)])
	var copy3 = await _copy(url, token)
	ok(copy3 != null and _ids(copy3) == ["pc1", "phone1", "s1", "s2"] and int(cloud._cfg.rev) == 3, "and so does the script (rev 3)", [_ids(copy3) if copy3 != null else null, cloud._cfg.get("rev")])
	await cloud.sync_now("test")
	var head = await _fetch_json(url + "?token=%s&save=head" % token)
	ok(int(head.rev) == 3, "nothing new: nothing sent", head)
	var backups = Array(DirAccess.get_files_at(dir.path_join("backups"))).filter(func(f): return str(f).begins_with("sync-"))
	ok(not backups.is_empty(), "the save was copied to backups before the merge was taken on", backups)

	# --- progress photos go to the script's Drive folder and come back -------------
	var pic = Image.create(64, 96, false, Image.FORMAT_RGB8)
	pic.fill(Color(0.8, 0.5, 0.3))
	DirAccess.make_dir_recursive_absolute(app.PHOTO_DIR)
	pic.save_jpg(app.photo_path("ptestfront"), 0.8)
	var pic_bytes = FileAccess.get_file_as_bytes(app.photo_path("ptestfront"))
	app.saved.body.append({"id": "b1", "date": "2026-03-05", "createdAt": 50, "weightKg": 80.0, "photos": {"front": "ptestfront", "side": "pnobodyhas"}})
	app._commit()
	cloud._debounce.stop()
	await cloud.sync_now("test")
	var dr = await _fetch_json("http://127.0.0.1:%d/drive" % port)
	ok(cloud.status == "ok" and dr is Array and dr.size() == 1 and str(dr[0].name) == "Tiny Titan photos" and dr[0].files.size() == 1 and str(dr[0].files[0][0]) == "ptestfront.jpg" and int(dr[0].files[0][1]) == pic_bytes.size(), "a photo here goes into the Drive folder", [cloud.status, cloud.error, dr])
	ok(str(cloud.photo_note).contains("1 photo not sent by the other device yet"), "a photo nobody has sent is said to be waiting", cloud.photo_note)
	await cloud.sync_now("test")
	dr = await _fetch_json("http://127.0.0.1:%d/drive" % port)
	ok(dr[0].files.size() == 1, "it is not sent twice")
	# The other device: the same save, without the file.
	DirAccess.remove_absolute(app.photo_path("ptestfront"))
	cloud._cfg.erase("photos")
	var seen = [0]
	var on_change = func(): seen[0] += 1
	app.changed.connect(on_change)
	await cloud.sync_now("test")
	app.changed.disconnect(on_change)
	ok(app.has_photo("ptestfront") and FileAccess.get_file_as_bytes(app.photo_path("ptestfront")) == pic_bytes and seen[0] >= 1, "a device without the photo fetches it, byte for byte, and the screens are drawn again", [app.has_photo("ptestfront"), seen[0], cloud.photo_note])
	app.saved.body = []
	app._commit()
	cloud._debounce.stop()
	await cloud.sync_now("test")
	dr = await _fetch_json("http://127.0.0.1:%d/drive" % port)
	ok(dr[0].files.size() == 1, "deleting the check-in deletes nothing in Drive")

	# --- a new phone takes the copy as it is ----------------------------------------
	app.replace_all(app.empty_saved())
	cloud._debounce.stop()
	ok(cloud.connect_with(cloud.connect_code() if cloud.connect_code() != "" else _code(url, token), false), "a connect code is taken")
	while cloud._busy:
		await create_timer(0.1).timeout
	ok(app.has_profile() and _ids(app.saved) == ["pc1", "phone1", "s1", "s2"], "a new phone gets the hero and every session", [app.has_profile(), _ids(app.saved)])

	# --- deleting a few at once goes through; a copy missing many is not taken -----
	for i in range(12):
		app.saved.sessions.append(_s("bulk%d" % i, "2026-02-%02d" % (i + 1)))
	app._commit()
	cloud._debounce.stop()
	await cloud.sync_now("test")
	var few = await _copy(url, token)
	for i in range(4):
		few.sessions = few.sessions.filter(func(x): return str(x.id) != "bulk%d" % i)
	few.updatedAt = float(few.get("updatedAt", 0)) + 3000.0
	await _put(url, token, few, int((await _fetch_json(url + "?token=%s&save=head" % token)).rev))
	await cloud.sync_now("test")
	ok(cloud.status == "ok" and not _ids(app.saved).has("bulk0") and _ids(app.saved).has("bulk4"), "four sessions deleted at once on the phone are deleted here too", [cloud.status, cloud.error])
	var cut = await _copy(url, token)
	cut.sessions = []
	cut.profile = {"name": "Tester"}
	cut.updatedAt = float(cut.get("updatedAt", 0)) + 5000.0
	var rev_now = int((await _fetch_json(url + "?token=%s&save=head" % token)).rev)
	await _put(url, token, cut, rev_now)
	var before = _ids(app.saved)
	await cloud.sync_now("test")
	ok(cloud.status == "error" and _ids(app.saved) == before, "a copy with every session gone is not taken on", [cloud.status, cloud.error, _ids(app.saved)])

	# --- a wrong token ------------------------------------------------------------------
	var bad = await _fetch_json(url + "?token=nope&save=get")
	ok(bad is Dictionary and not bool(bad.get("ok", true)) and not bad.has("data"), "a wrong token gets nothing", bad)
	await _fetch_json("http://127.0.0.1:%d/quit" % port)
	OS.kill(pid)


func _code(url: String, token: String) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify({"u": url, "t": token})).replace("+", "-").replace("/", "_").replace("=", "")


func _copy(url: String, token: String):
	var g = await _fetch_json(url + "?token=%s&save=get" % token)
	if not (g is Dictionary) or not g.has("data"):
		return null
	return CloudSync.decode(str(g.data))


func _put(url: String, token: String, data: Dictionary, base: int):
	var r = await _http(HTTPClient.METHOD_POST, url + "?direct=1", JSON.stringify({"token": token, "save": "put", "base": base, "data": CloudSync.encode(data), "by": "test phone"}))
	return r


func _fetch_json(url: String):
	return await _http(HTTPClient.METHOD_GET, url, "")


func _http(method: int, url: String, body: String):
	var req = HTTPRequest.new()
	req.timeout = 10.0
	root.add_child(req)
	var headers = PackedStringArray(["Content-Type: text/plain;charset=utf-8"]) if method == HTTPClient.METHOD_POST else PackedStringArray()
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return null
	var r = await req.request_completed
	req.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS:
		return null
	return JSON.parse_string(PackedByteArray(r[3]).get_string_from_utf8())
