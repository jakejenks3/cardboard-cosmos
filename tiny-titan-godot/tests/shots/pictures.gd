extends RefCounted
## Screenshots in the phone note (run with the "new" data; Windows only, because
## it uses the text reader that is part of Windows). Fake phone screenshots are
## drawn here, packed into a zip shaped like Google's export of a Doc and handed
## to the inbox. A workout screenshot must come out as a run, a scale screenshot
## as a weigh-in, a walk is left out with the reason, and a picture without
## words stays a progress photo. Then: nothing is offered twice, not the next
## day either, and a new picture is a new entry. Prints CHECK lines.

const W = 720
const H = 1560
const INK = Color(0.96, 0.96, 0.97)
const DIM = Color(0.72, 0.74, 0.78)

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


func _font(bold: bool) -> Font:
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "sans-serif"])
	f.font_weight = 700 if bold else 400
	return f


func _label(text: String, px: int, color: Color, bold: bool) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(bold))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l


## A picture W x H: `items` are [text, x, y, size, bold] or, for a number with a
## small unit after it, [text, x, y, size, bold, unit].
func _picture(bg: Color, items: Array, blocks: Array = []) -> PackedByteArray:
	var vp = SubViewport.new()
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(W, H)
	var root = Control.new()
	root.size = Vector2(W, H)
	var back = ColorRect.new()
	back.color = bg
	back.size = Vector2(W, H)
	root.add_child(back)
	for b in blocks:
		var r = ColorRect.new()
		r.color = b[4]
		r.position = Vector2(b[0], b[1])
		r.size = Vector2(b[2], b[3])
		root.add_child(r)
	for it in items:
		var l = _label(it[0], it[3], INK if it[4] else DIM, it[4])
		if it.size() > 5:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.position = Vector2(it[1], it[2])
			row.add_child(l)
			var u = _label(it[5], int(it[3] * 0.4), DIM, false)
			u.size_flags_vertical = Control.SIZE_SHRINK_END
			row.add_child(u)
			root.add_child(row)
		else:
			l.position = Vector2(it[1], it[2])
			root.add_child(l)
	vp.add_child(root)
	main.add_child(vp)
	await ShotHelper.frames(tree, 3)
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	vp.queue_free()
	return img.save_png_to_buffer()


func _workout(sport: String, title: String, day: String, dist: String, pace: String, time: String, gain: String, steps: String) -> PackedByteArray:
	return await _picture(Color(0.07, 0.07, 0.08), [
		[sport, 330, 120, 26, true],
		[day, 130, 280, 20, false],
		[title, 30, 370, 44, true],
		["Distance", 150, 600, 20, false], [dist, 128, 632, 32, true],
		["Avg Pace", 480, 600, 20, false], [pace, 452, 632, 32, true],
		["Moving Time", 135, 710, 20, false], [time, 148, 742, 32, true],
		["Elevation Gain", 458, 710, 20, false], [gain, 488, 742, 32, true],
		["Max Elevation", 130, 820, 20, false], ["1,240 ft", 132, 852, 32, true],
		["Steps", 500, 820, 20, false], [steps, 484, 852, 32, true],
		["Solid effort at your typical distance.", 70, 1020, 26, false],
	])


func _scale(weight: String) -> PackedByteArray:
	return await _picture(Color(0.05, 0.11, 0.2), [
		["Weigh-in", 300, 130, 28, true],
		["TODAY  6:50 AM  SCALE X PRO", 36, 232, 18, false],
		[weight, 36, 262, 84, true, "lb"],
		["Composition", 36, 470, 28, true],
		["Body fat", 58, 548, 20, false], ["17.2", 58, 582, 30, true],
		["Muscle", 278, 548, 20, false], ["77.1", 278, 582, 30, true],
		["Skeletal muscle", 498, 548, 20, false], ["47.0", 498, 582, 30, true],
		["Bone mass", 58, 712, 20, false], ["9.6", 58, 746, 30, true, "lb"],
		["Visceral fat", 498, 712, 20, false], ["5", 498, 746, 30, true],
	])


## Wrap pictures as Google wraps a Doc: an HTML page plus images/.
func _zip(pictures: Array) -> PackedByteArray:
	var path = OS.get_environment("TINY_TITAN_DATA").path_join("fake-note.zip")
	var html = "<html><head><title>Workouts</title></head><body>"
	for i in range(pictures.size()):
		html += "<p><span><img alt=\"\" src=\"images/image%d.png\" style=\"width: 300px\"></span></p>" % (i + 1)
	html += "</body></html>"
	var zp = ZIPPacker.new()
	zp.open(path)
	zp.start_file("Workouts.html")
	zp.write_file(html.to_utf8_buffer())
	zp.close_file()
	for i in range(pictures.size()):
		zp.start_file("images/image%d.png" % (i + 1))
		zp.write_file(pictures[i])
		zp.close_file()
	zp.close()
	var bytes = FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(path)
	return bytes


func _read_note(zip: PackedByteArray) -> Dictionary:
	var box = {"r": null}
	App.inbox.checked.connect(func(r): box.r = r, CONNECT_ONE_SHOT)
	App.inbox._got_zip(zip, false)
	for i in range(600):
		if box.r != null:
			break
		await ShotHelper.wait(tree, 0.1)
	return box.r if box.r != null else {"ok": false, "error": "no answer", "fresh": [], "already": 0, "problems": []}


func _dismiss_reels() -> void:
	for i in range(14):
		var b = ShotHelper.find_button(main, "Tap to skip")
		if b == null:
			b = ShotHelper.find_button(main, "Continue")
		if b == null:
			break
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.6)


func _near(a, b, eps: float) -> bool:
	return a != null and absf(float(a) - float(b)) <= eps


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	if not Ocr.available():
		print("PICTURES skipped: the text reader is only on Windows")
		return
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	var data_dir = OS.get_environment("TINY_TITAN_DATA")
	var today = App.today

	var run_png = await _workout("Run", "Morning Run", "Today at 6:15 AM  Springfield, Oregon", "4.02 mi", "10:21 /mi", "41:37", "112 ft", "6,480")
	var scale_png = await _scale("180.4")
	var walk_png = await _workout("Walk", "Lunch Walk", "Today at 12:10 PM  Springfield, Oregon", "1.20 mi", "20:08 /mi", "24:10", "12 ft", "2,950")
	var photo_png = await _picture(Color(0.55, 0.6, 0.66), [], [[250, 300, 220, 220, Color(0.86, 0.68, 0.55)], [200, 540, 320, 620, Color(0.2, 0.35, 0.6)], [230, 1160, 110, 330, Color(0.15, 0.15, 0.2)], [380, 1160, 110, 330, Color(0.15, 0.15, 0.2)]])
	var shots_dir = OS.get_environment("TINY_TITAN_SHOTS")
	if shots_dir != "":
		for pair in [["fake_run", run_png], ["fake_scale", scale_png]]:
			var f = FileAccess.open(shots_dir.path_join(pair[0] + ".png"), FileAccess.WRITE)
			f.store_buffer(pair[1])
			f.close()

	# --- first read: the text reader runs ------------------------------------------------
	var zip1 = _zip([scale_png, run_png, walk_png, photo_png])
	var t0 = Time.get_ticks_msec()
	var r1 = await _read_note(zip1)
	print("PICTURES first read took %d ms" % (Time.get_ticks_msec() - t0))
	print("PICTURES readings: ", JSON.stringify(App.inbox._readings))
	check(r1.ok, "the note was read (%s)" % str(r1.get("error")))
	var run_e = null
	var body_e = null
	for e in r1.fresh:
		if e.kind == "session":
			run_e = e
		else:
			body_e = e
	check(r1.fresh.size() == 2 and run_e != null and body_e != null, "a run and a check-in were found (%d entries)" % r1.fresh.size())
	if run_e != null:
		check(run_e.data.discipline == "run" and _near(run_e.data.get("distanceM"), 6469.6, 0.2), "run: 4.02 mi (%s m)" % str(run_e.data.get("distanceM")))
		check(run_e.data.get("durationSec") == 2497, "run: 41:37 (%s s)" % str(run_e.data.get("durationSec")))
		check(_near(run_e.data.get("elevationM"), 34.14, 0.02), "run: 112 ft up (%s m)" % str(run_e.data.get("elevationM")))
		check(run_e.data.get("title") == "Morning Run", "run: title (%s)" % str(run_e.data.get("title")))
		check(str(run_e.data.get("notes", "")).contains("Steps 6,480") and str(run_e.data.get("notes", "")).contains("Max elevation 1,240 ft"), "run: steps and max elevation kept as the note (%s)" % str(run_e.data.get("notes")))
		check(run_e.date == today and str(run_e.date_note) == QuickLog.SHOT_TODAY, "run: dated today, with the reason")
		check(str(run_e.summary) == "Morning Run: Run 4.02 mi · 41:37 · 112 ft up", "run: summary (%s)" % str(run_e.summary))
	if body_e != null:
		check(_near(body_e.data.get("weightKg"), 81.83, 0.011), "weigh-in: 180.4 lb (%s kg)" % str(body_e.data.get("weightKg")))
		check(_near(body_e.data.get("bodyFatPct"), 17.2, 0.001), "weigh-in: body fat 17.2 (%s)" % str(body_e.data.get("bodyFatPct")))
		check(str(body_e.data.get("note", "")).contains("Muscle 77.1%") and str(body_e.data.get("note", "")).contains("Bone mass 9.6"), "weigh-in: the other readings are the note (%s)" % str(body_e.data.get("note")))
		check(body_e.data.get("photoRefs", []).size() == 1, "the picture without words is that day's progress photo")
		check(body_e.get("shots", []).size() == 1, "the check-in remembers its screenshot")
	var walk_pr = null
	for pr in r1.problems:
		if pr.has("picture"):
			walk_pr = pr
	check(r1.problems.size() == 1 and walk_pr != null and str(walk_pr.why).contains("a walk"), "the walk is left out, and says why (%s)" % str(r1.problems))
	check(not DirAccess.dir_exists_absolute(data_dir.path_join("reading")), "the pictures written for the reader are gone again")
	var cache = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join(PhoneInbox.PAGES_FILE)))
	check(cache is Dictionary and cache.size() == 4, "what was read is remembered for all 4 pictures")

	InboxSheet.open(r1)
	await ShotHelper.wait(tree, 0.6)
	await ShotHelper.snap(tree, "pictures_review")
	check(ShotHelper.find_text(_sheet(), "Read from a picture") != null, "the review says the entry was read from a picture")
	check(ShotHelper.find_text(_sheet(), "Picture left out") != null, "the review shows the picture that was left out")
	_sheet()._scroll.scroll_vertical = 4000
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "pictures_review_2")

	# --- import ---------------------------------------------------------------------------
	var imp = ShotHelper.find_button(_sheet(), "Import 2 entries")
	check(imp != null, "Import 2 entries button")
	ShotHelper.press(imp)
	await ShotHelper.wait(tree, 0.8)
	await ShotHelper.snap(tree, "pictures_reel")
	await _dismiss_reels()
	var runs = App.sessions().filter(func(s): return s.discipline == "run")
	check(runs.size() == 1 and runs[0].get("title") == "Morning Run" and runs[0].date == today and str(runs[0].get("inboxKey", "")) != "", "the run is in the log")
	var bodies = App.body()
	check(bodies.size() == 1 and _near(bodies[0].get("weightKg"), 81.83, 0.011) and bodies[0].get("photos", {}).has("front") and App.has_photo(bodies[0].photos.front), "the check-in is in the log with its weight and its photo")
	App.go("journey", "history")
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "pictures_log")

	# --- again: nothing twice, and no second reading ----------------------------------------
	var box = {"r": null}
	App.inbox.checked.connect(func(r): box.r = r, CONNECT_ONE_SHOT)
	App.inbox._got_zip(zip1, false)
	check(box.r != null, "pictures seen before are not read again (the answer is immediate)")
	var r2 = box.r if box.r != null else await _read_note(zip1)
	check(r2.ok and r2.fresh.is_empty() and r2.already == 2 and r2.problems.size() == 1, "second check: nothing new, 2 already imported (%d new, %d already)" % [r2.fresh.size(), r2.already])

	# --- the next day -----------------------------------------------------------------------
	var tomorrow = Dates.add_days(today, 1)
	App.today = tomorrow
	var r3 = await _read_note(zip1)
	check(r3.ok and r3.fresh.is_empty() and r3.already == 2, "the next day: still nothing new")
	var run2_png = await _workout("Run", "Evening Run", "Today at 6:40 PM  Springfield, Oregon", "5.50 mi", "9:48 /mi", "53:54", "140 ft", "8,870")
	var zip2 = _zip([run2_png])
	var r4 = await _read_note(zip2)
	check(r4.ok and r4.fresh.size() == 1 and r4.fresh[0].date == tomorrow, "a new picture the next day is a new run on that day (%d new)" % r4.fresh.size())
	if r4.fresh.size() == 1:
		check(not r4.fresh[0].has("replaces") and not bool(r4.fresh[0].get("skip", false)) and r4.fresh[0].warnings.is_empty(), "and it does not replace yesterday's run")
		App.inbox.import_entries(r4.fresh)
		await ShotHelper.wait(tree, 0.8)
		await _dismiss_reels()
	runs = App.sessions().filter(func(s): return s.discipline == "run")
	check(runs.size() == 2, "both runs are in the log (%d)" % runs.size())

	# --- typed lines without a date: an edit the same day, a new entry another day -----------------
	var a = App.inbox.check_text("ride 20km 55:00")
	App.inbox.import_entries(a.fresh)
	await ShotHelper.wait(tree, 0.8)
	await _dismiss_reels()
	var b = App.inbox.check_text("ride 21km 57:00")
	check(b.fresh.size() == 1 and b.fresh[0].has("replaces"), "an undated line changed the same day updates its entry")
	App.today = Dates.add_days(tomorrow, 1)
	var c = App.inbox.check_text("ride 21km 57:00")
	check(c.fresh.size() == 1 and not c.fresh[0].has("replaces") and not bool(c.fresh[0].get("skip", false)), "the same change on another day is a new entry, not an edit")
	App.today = today

	# --- the help says so ------------------------------------------------------------------------
	SettingsPanel.show_how()
	await ShotHelper.wait(tree, 0.6)
	check(_sheet() != null and ShotHelper.find_text(_sheet(), "Screenshots work too") != null, "'How it works' says screenshots are read")
	if _sheet() != null:
		_sheet()._scroll.scroll_vertical = 4000
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "pictures_how")
	print("PICTURES DONE, failures: %d" % fails)
