extends RefCounted
## Things made for the phone app, tried on the PC (run with the "year" data
## and "--phone-push-test" after the data kind; tests/push_stub.js must be
## listening on the port in TINY_TITAN_PUSH_PORT, default 8799):
## renaming a lift and joining two, the small backup (the log alone) and
## taking only the photos out of an older one, and the morning message the
## app leaves with ntfy by itself (one per morning, nothing sent twice).
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func _dismiss_reels() -> void:
	for k in range(6):
		var b = null
		for i in range(40):
			await ShotHelper.wait(tree, 0.4)
			b = ShotHelper.find_button(main, "Continue")
			if b != null and not b.disabled:
				break
		if b == null:
			return
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.5)


func _meta(root: Node, key: String):
	for n in ShotHelper.walk(root):
		if n.has_meta(key):
			return n
	return null


func _stub_log(port: int) -> Array:
	var http = HTTPRequest.new()
	main.add_child(http)
	http.request("http://127.0.0.1:%d/log" % port)
	var res = await http.request_completed
	http.queue_free()
	var parsed = JSON.parse_string(res[3].get_string_from_utf8())
	return parsed if parsed is Array else []


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb"})

	# ------------------------------------------------------------------ rename
	var stats = LiftLibrary.stats(App.sessions())
	var names = []
	for k in stats:
		names.append(str(stats[k].name))
	names.sort()
	var a = "Bench Press - Barbell" if names.has("Bench Press - Barbell") else names[0]
	var n_a = App.lift_sessions(a)
	var levels_before = JSON.stringify(App.state.levels)
	var total_before = App.sessions().size()
	JourneyLifts.open_named(a)
	await ShotHelper.wait(tree, 0.8)
	var key = _meta(_sheet(), "rename_lift")
	check(key != null, "a lift's page has a Rename or move key")
	if key != null:
		ShotHelper.reveal(key)
		await ShotHelper.frames(tree, 3)
		ShotHelper.press(key)
	await ShotHelper.wait(tree, 0.7)
	var sh = _sheet()
	var mv = _meta(sh, "rename_move")
	var vr = _meta(sh, "rename_variation")
	var said = _meta(sh, "rename_said")
	check(mv != null and vr != null and mv.text == str(LiftNames.split(a).move) and vr.text == str(LiftNames.split(a).variation), "the sheet starts from its movement and variation")
	var go = ShotHelper.find_button(sh, "Rename")
	check(go != null and go.disabled, "nothing to do until something is changed")
	ShotHelper.type_into(vr, "Paused barbell")
	await ShotHelper.frames(tree, 3)
	var new_a = LiftNames.join(str(LiftNames.split(a).move), "Paused barbell")
	check(said != null and said.text.contains(new_a) and not go.disabled, "it says what it will be (%s)" % (said.text if said != null else ""))
	await ShotHelper.snap(tree, "phone_1_rename")
	ShotHelper.press(go)
	await ShotHelper.wait(tree, 0.9)
	check(App.lift_sessions(a) == 0 and App.lift_sessions(new_a) == n_a and n_a > 0, "renamed in all %d workouts" % n_a)
	check(JSON.stringify(App.state.levels) == levels_before and App.sessions().size() == total_before, "levels and the number of sessions are untouched")
	check(_sheet() != null and ShotHelper.all_text(_sheet()).contains("Paused barbell"), "and its page opens under the new name")
	var kept = Array(DirAccess.open(App.BACKUP_DIR).get_files()).filter(func(f): return str(f).contains("before-rename"))
	check(kept.size() == 1, "a copy of the save was kept first (%s)" % str(kept))
	await _close_sheets()

	# Join two lifts: the new name is one the player has.
	var b = ""
	for nm in names:
		if nm != a and str(LiftNames.split(nm).move) != str(LiftNames.split(a).move):
			b = nm
			break
	var either = 0
	for s in App.sessions():
		if s.get("exercises", []).any(func(e): return str(e.name) == new_a or str(e.name) == b):
			either += 1
	JourneyLifts.open_rename(null, new_a)
	await ShotHelper.wait(tree, 0.7)
	sh = _sheet()
	ShotHelper.type_into(_meta(sh, "rename_move"), str(LiftNames.split(b).move))
	ShotHelper.type_into(_meta(sh, "rename_variation"), str(LiftNames.split(b).variation))
	await ShotHelper.frames(tree, 3)
	said = _meta(sh, "rename_said")
	check(said.text.contains("become one"), "a name the player already has: the two become one (%s)" % said.text)
	await ShotHelper.snap(tree, "phone_2_join")
	var res = App.rename_lift(new_a, b)
	check(bool(res.ok) and bool(res.joined) and App.lift_sessions(new_a) == 0 and App.lift_sessions(b) == either, "joined: every workout of either is under %s (%d)" % [b, either])
	check(App.sessions().size() == total_before, "no session was added or lost")
	await _close_sheets()

	# ------------------------------------------------------------------ backups
	var img = Image.create(40, 60, false, Image.FORMAT_RGB8)
	img.fill(Color(0.8, 0.5, 0.3))
	var pid = App.import_photo_bytes(img.save_png_to_buffer(), "front.png")
	check(pid != "", "a progress photo to back up")
	App.commit_body({"id": "body-photo-test", "date": App.today, "createdAt": App.now_ms(), "weightKg": 80.0, "photos": {"front": pid}})
	await _dismiss_reels()
	check(App.photos_here().has(pid) and App.photos_unsaved().has(pid), "a new photo is in no backup yet")
	var full = App.DATA_DIR + "t-full.json"
	var small = App.DATA_DIR + "t-small.json"
	check(App.export_backup(full, true) == "" and App.export_backup(small, false) == "", "a backup with photos, and the log alone")
	var size_full = FileAccess.get_file_as_bytes(full).size()
	var size_small = FileAccess.get_file_as_bytes(small).size()
	check(JSON.parse_string(FileAccess.get_file_as_string(full)).photos.has(pid) and not JSON.parse_string(FileAccess.get_file_as_string(small)).has("photos") and size_small < size_full, "the small one has no photos in it (%d against %d bytes)" % [size_small, size_full])
	App.note_backup(true)
	check(App.photos_unsaved().is_empty() and str(App.backup_info().get("photosDay", "")) == App.today, "once in a backup, the next one can be small")
	# A new phone: the log from the small file, then the photos from the older one.
	App.update_settings({"haptics": true})
	var back_small = App.DATA_DIR + "t-small-2.json"
	App.export_backup(back_small, false)
	DirAccess.remove_absolute(App.photo_path(pid))
	App._photo_cache.clear()
	var r_small = App.read_backup(back_small)
	App.apply_backup(r_small)
	await ShotHelper.wait(tree, 0.5)
	check(App.photos_missing().has(pid), "the log alone restored where the photo is gone: the photo is missing")
	var r_full = App.read_backup(full)
	check(App.photos_to_take(r_full) == 1 and float(r_full.data.get("updatedAt", 0)) < float(App.saved.get("updatedAt", 0)), "the older backup holds it")
	SettingsPanel.confirm_import(full)
	await ShotHelper.wait(tree, 0.6)
	var add = ShotHelper.find_button(Kit.overlay_root, "Add photos")
	check(add != null, "restoring the older one offers to add only its photos")
	await ShotHelper.snap(tree, "phone_3_add_photos")
	var sessions_now = App.sessions().size()
	ShotHelper.press(add)
	await ShotHelper.wait(tree, 0.6)
	check(App.photos_missing().is_empty() and FileAccess.file_exists(App.photo_path(pid)) and App.sessions().size() == sessions_now, "the photo is back, the log untouched")
	for f in [full, small, back_small]:
		DirAccess.remove_absolute(f)

	# ------------------------------------------------------------------ the morning message
	var port = int(OS.get_environment("TINY_TITAN_PUSH_PORT")) if OS.get_environment("TINY_TITAN_PUSH_PORT") != "" else 8799
	check(PhonePush.wanted() and App.push != null, "the phone's morning message is on for this run")
	App.update_settings({"morning": {"phone": false, "topic": "tinytitan-madeuptopic", "time": "07:00", "server": "http://127.0.0.1:%d" % port}})
	await ShotHelper.wait(tree, 10.0)
	var log0 = await _stub_log(port)
	check(log0.is_empty(), "nothing is sent while the switch is off (%d)" % log0.size())
	var mm = App.settings().morning.duplicate()
	mm["phone"] = true
	App.update_settings({"morning": mm})
	await App.push.run()
	await ShotHelper.wait(tree, 1.0)
	var log1 = await _stub_log(port)
	var want = PhonePush.jobs(App.saved, App.today, int(Time.get_unix_time_from_system()), App.push.bias_min())
	check(log1.size() == want.size() and want.size() >= 2, "switched on: the coming mornings are left with ntfy (%d sent, %d ahead)" % [log1.size(), want.size()])
	if not log1.is_empty():
		var first = JSON.parse_string(str(log1[0].body))
		check(str(log1[0].method) == "POST" and str(log1[0].url) == "/" and first is Dictionary and str(first.topic) == "tinytitan-madeuptopic" and str(first.delay) == str(int(want[0].at)) and str(first.message) != "" and str(first.sequence_id) == "tt-" + str(want[0].day), "each held until its morning (%s)" % str(log1[0].body).left(160))
		print("MORNING ", str(first.title), " | ", str(first.message).replace("\n", " / "))
	check(App.push.waiting().size() == want.size() and App.push.status_text().begins_with("Waiting to be sent"), "and remembered (%s)" % App.push.status_text())
	await App.push.run()
	App.update_settings({"readingGoal": 21})
	await ShotHelper.wait(tree, 10.0)
	var log2 = await _stub_log(port)
	check(log2.size() == log1.size(), "nothing is sent twice (%d)" % log2.size())
	# The card in Settings.
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.9)
	var card = _meta(Kit.overlay_root, "morning_phone")
	check(card != null, "Settings has the phone's Morning goals card")
	if card != null:
		ShotHelper.reveal(card)
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "phone_4_morning_card")
	print("PHONE DONE fails=%d" % fails)
