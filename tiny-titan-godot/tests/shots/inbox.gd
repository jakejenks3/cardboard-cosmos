extends RefCounted
## Phone inbox walkthrough (run with the "week" data): a note in a local file →
## check → review sheet → import → the multiset rule on re-checks → a cleared
## note → Settings section, paste sheet, Home card, Log picker link. When
## TINY_TITAN_INBOX_URL points at a throwaway local HTTP server (see the
## report / README), the HTTP path is exercised too. Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0
var reels = []


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


func _write(path: String, text: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Press Continue on every results reel that is showing.
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


func _check_and_wait() -> Dictionary:
	var box = {"r": null}
	var cb = func(r): box.r = r
	App.inbox.checked.connect(cb, CONNECT_ONE_SHOT)
	App.inbox.check(false)
	for i in range(100):
		if box.r != null:
			break
		await ShotHelper.wait(tree, 0.1)
	return box.r if box.r != null else {"ok": false, "error": "no answer", "fresh": [], "already": 0, "problems": []}


func _lift_on(date: String):
	for s in App.sessions():
		if s.discipline == "lift" and s.date == date and s.get("source") == "manual" and str(s.id).begins_with("s"):
			for ex in s.exercises:
				if ex.name == "Bench Press" and ex.sets.size() == 3 and is_equal_approx(float(ex.sets[0].weightKg), 80.0):
					return s
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "kg", "distanceUnit": "km"})
	App.result_ready.connect(func(r): reels.append(r))
	var today = App.today
	var y = Dates.add_days(today, -1)
	var two = Dates.add_days(today, -2)
	var note = OS.get_environment("TINY_TITAN_DATA").path_join("phone-note.txt")
	var text = "%s\nride 40km 1h35\n\nyesterday\nbench 3x5 @ 80\nsquat 5,5,4 @ 100\npull-up 3x8\nnote: felt strong\nv4 flash x2, v5 send\nrun 5.2km 27:30 +80m\nweight 82.4  bf 18\nfeeling great!!\n" % two
	_write(note, text)

	# --- no source yet ------------------------------------------------------------
	var r0 = await _check_and_wait()
	check(not r0.ok and str(r0.error).contains("No link"), "no source: friendly error (%s)" % r0.error)

	# --- first check + review sheet ------------------------------------------------
	App.inbox.set_source(note)
	var n_sessions = App.sessions().size()
	var n_body = App.body().size()
	var r1 = await _check_and_wait()
	check(r1.ok and r1.fresh.size() == 5 and r1.already == 0, "first check: 5 fresh (got %d, %s)" % [r1.fresh.size(), r1.error])
	check(r1.problems.size() == 1 and r1.problems[0].line == "feeling great!!", "the unreadable line is listed: %s" % str(r1.problems))
	check(int(App.inbox.settings().lastChecked) > 0, "lastChecked stored")
	InboxSheet.open(r1)
	await ShotHelper.wait(tree, 0.5)
	var said = ShotHelper.all_text(_sheet())
	check(said.contains("1 line not read") and said.contains("feeling great!!") and said.contains("Not a date, workout or check-in I know."), "the review says which line was not read, and why")
	await ShotHelper.snap(tree, "inbox_review")
	_sheet()._scroll.scroll_vertical = 4000
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "inbox_review_2")
	check(ShotHelper.find_text(_sheet(), "already imported") == null, "no 'already imported' line on the first check")
	# Nudge the ride (explicit date: no arrows) is not possible; nudge the "yesterday" lift back a day and forward again.
	var back = null
	for n in ShotHelper.walk(_sheet()):
		if n is Button and n.tooltip_text == "Day before":
			back = n
			break
	check(back != null, "guessed dates have a day nudge")
	ShotHelper.press(back)
	await ShotHelper.frames(tree, 2)
	check(r1.fresh[1].date == Dates.add_days(y, -1), "nudge moved the date back a day")
	for n in ShotHelper.walk(_sheet()):
		if n is Button and n.tooltip_text == "Day after":
			ShotHelper.press(n)
			break
	await ShotHelper.frames(tree, 2)
	check(r1.fresh[1].date == y, "and forward again")
	var imp = ShotHelper.find_button(_sheet(), "Import 5 entries")
	check(imp != null, "Import 5 entries button")
	ShotHelper.press(imp)
	await ShotHelper.wait(tree, 0.6)
	check(App.sessions().size() == n_sessions + 4, "4 sessions imported (%d -> %d)" % [n_sessions, App.sessions().size()])
	check(App.body().size() == n_body + 1, "1 check-in imported")
	var lift = _lift_on(y)
	check(lift != null and lift.exercises.size() == 3 and lift.get("notes") == "felt strong", "lift session: bench 3x5 @ 80, squat, pull-up, note")
	if lift != null:
		var sq = lift.exercises[1]
		check(sq.name == "Squat" and sq.sets.size() == 3 and int(sq.sets[2].reps) == 4 and is_equal_approx(float(sq.sets[2].weightKg), 100.0), "squat 5,5,4 @ 100")
		check(lift.exercises[2].name == "Pull-up" and float(lift.exercises[2].sets[0].weightKg) == 0.0, "pull-up bodyweight")
	var found = {"run": false, "ride": false, "climb": false, "body": false}
	for s in App.sessions():
		if s.discipline == "run" and s.date == y and int(s.distanceM) == 5200 and int(s.get("durationSec", 0)) == 1650 and int(s.elevationM) == 80:
			found.run = true
		if s.discipline == "ride" and s.date == two and int(s.distanceM) == 40000 and int(s.get("durationSec", 0)) == 5700:
			found.ride = true
		if s.discipline == "climb" and s.date == y and s.climbs.size() == 2 and int(s.climbs[0].grade) == 4 and s.climbs[0].result == "flash" and int(s.climbs[0].count) == 2:
			found.climb = true
	for b in App.body():
		if b.date == y and is_equal_approx(float(b.get("weightKg", 0)), 82.4) and is_equal_approx(float(b.get("bodyFatPct", 0)), 18.0):
			found.body = true
	check(found.run and found.ride and found.climb and found.body, "run / ride / climb / check-in have the right numbers: %s" % str(found))
	var bulk = false
	for r in reels:
		if r.title == "Imported from your phone":
			bulk = true
	check(bulk and reels.size() >= 2, "results reel requested (%d reels: bulk + check-in)" % reels.size())
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "inbox_reel")
	await _dismiss_reels()
	var saved = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
	check(saved != null and saved.inbox.source == note and saved.inbox.imported.size() == 5, "inbox settings survive in save.json (%s)" % str(saved.inbox if saved != null else null))

	# --- check again: nothing new ---------------------------------------------------
	var r2 = await _check_and_wait()
	check(r2.ok and r2.fresh.is_empty() and r2.already == 5, "second check: nothing fresh, 5 already (%d, %d)" % [r2.fresh.size(), r2.already])
	check(App.inbox.pending().is_empty(), "nothing pending")

	# --- append a repeat and a new line: exactly the new occurrences are fresh ----------
	_write(note, text + "run 5.2km 27:30 +80m\nride 12km 40min\n")
	var r3 = await _check_and_wait()
	var kinds = []
	for e in r3.fresh:
		kinds.append(e.data.discipline)
	check(r3.ok and r3.fresh.size() == 2 and r3.already == 5 and kinds.has("run") and kinds.has("ride"), "appended lines: 2 fresh (%s), 5 already" % str(kinds))
	App.go("home")
	await ShotHelper.wait(tree, 0.4)
	check(ShotHelper.find_text(main, "2 new entries from your phone") != null, "Home card shows the pending entries")
	await ShotHelper.snap(tree, "inbox_home_card")
	var card = ShotHelper.find_text(main, "new entries from your phone")
	while card != null and not (card is Card):
		card = card.get_parent()
	# The card's own tap (a synthetic click can land on a child control).
	card._tap.call()
	await ShotHelper.wait(tree, 0.5)
	check(_sheet() != null and ShotHelper.find_button(_sheet(), "Import 2 entries") != null, "tapping the card opens the review")
	check(ShotHelper.find_text(_sheet(), "5 already imported") != null, "review says 5 already imported")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Import 2 entries"))
	await ShotHelper.wait(tree, 0.5)
	await _dismiss_reels()
	check(App.sessions().size() == n_sessions + 6, "6 imported sessions in all")
	var r4 = await _check_and_wait()
	check(r4.fresh.is_empty() and r4.already == 7, "re-check after that: 0 fresh, 7 already")
	App.go("home")
	await ShotHelper.wait(tree, 0.4)
	check(ShotHelper.find_text(main, "safe to clear") != null, "Home says the note is all imported")
	await ShotHelper.snap(tree, "inbox_home_all_in")

	# --- clear the note, then write a new one ---------------------------------------
	_write(note, "")
	var r5 = await _check_and_wait()
	check(r5.ok and r5.fresh.is_empty() and App.inbox.settings().imported.is_empty(), "cleared note: imported keys forgotten")
	_write(note, "today\nbench 1x5 @ 90\n")
	var r6 = await _check_and_wait()
	check(r6.ok and r6.fresh.size() == 1 and r6.fresh[0].date_note != "", "rewritten note: 1 fresh")
	App.inbox.import_entries(r6.fresh)
	await ShotHelper.wait(tree, 0.4)
	await _dismiss_reels()
	var got90 = false
	for s in App.sessions():
		if s.discipline == "lift" and s.date == today and s.exercises.size() == 1 and is_equal_approx(float(s.exercises[0].sets[0].weightKg), 90.0):
			got90 = true
	check(got90, "bench 1x5 @ 90 imported for today")
	# Editing an already imported day: the changed entry updates the session it came from.
	_write(note, "today\nbench 1x5 @ 90\nsquat 1x5 @ 100\n")
	var r7 = await _check_and_wait()
	check(r7.fresh.size() == 1 and r7.fresh[0].has("replaces") and not bool(r7.fresh[0].get("skip", false)), "edited imported day updates the session it came from")
	InboxSheet.open(r7)
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "inbox_review_changed")
	check(ShotHelper.find_text(_sheet(), "Updates the one") != null, "review says it updates the imported one")
	var n_before = App.sessions().size()
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Import 1 entry"))
	await ShotHelper.wait(tree, 0.5)
	await _dismiss_reels()
	var merged = null
	for s in App.sessions():
		if s.discipline == "lift" and s.date == today and s.exercises.size() == 2:
			merged = s
	check(App.sessions().size() == n_before and merged != null, "same number of sessions; the day now has bench and squat")
	var r8 = await _check_and_wait()
	check(r8.fresh.is_empty() and r8.already == 1, "after the update: nothing fresh, 1 already")

	# --- Settings section --------------------------------------------------------------
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.5)
	var head = null
	for n in ShotHelper.walk(_sheet()):
		if n is Control and n.has_meta("inbox_section"):
			head = n
			break
	check(head != null, "Settings has a Phone inbox section")
	_sheet()._scroll.scroll_vertical = int(head.get_global_rect().position.y - _sheet()._scroll.get_global_rect().position.y) - 8
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "inbox_settings")
	_sheet()._scroll.scroll_vertical += 420
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "inbox_settings_2")
	check(ShotHelper.find_text(_sheet(), "Checked at") != null, "status line shows the last check")
	var fld = null
	for n in ShotHelper.walk(_sheet()):
		if n is LineEdit and n.text == note:
			fld = n
	check(fld != null, "the link field shows the source")

	# --- paste sheet ---------------------------------------------------------------------
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Paste text"))
	await ShotHelper.wait(tree, 0.5)
	var te = null
	for n in ShotHelper.walk(_sheet()):
		if n is TextEdit:
			te = n
	check(te != null, "paste sheet has a text box")
	await ShotHelper.snap(tree, "inbox_paste_empty")
	te.text = "sat\nv3 x4, v5 att\nrun 10k 52:10"
	await ShotHelper.frames(tree, 2)
	await ShotHelper.snap(tree, "inbox_paste")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Read it"))
	await ShotHelper.wait(tree, 0.6)
	check(_sheet() != null and ShotHelper.find_button(_sheet(), "Import 2 entries") != null, "pasted text opens the review with 2 entries")
	await ShotHelper.snap(tree, "inbox_paste_review")
	await _close_sheets()

	# --- Log picker link ---------------------------------------------------------------------
	_write(note, "today
bench 1x5 @ 90
squat 1x5 @ 100
run 3km 15:00
")  # something new to find
	App.open_log(null)
	await ShotHelper.wait(tree, 0.4)
	var link = ShotHelper.find_button(main, "Import from phone")
	check(link != null, "Log picker has 'Import from phone'")
	await ShotHelper.snap(tree, "inbox_log_picker")
	ShotHelper.press(link)
	await ShotHelper.wait(tree, 0.6)
	check(_sheet() != null and ShotHelper.find_text(_sheet(), "From your phone") != null, "the link checks and opens the review")
	await _close_sheets()

	# --- HTTP path against a local throwaway server (optional) ----------------------------------
	var url = OS.get_environment("TINY_TITAN_INBOX_URL")
	if url == "":
		print("SKIP  HTTP path: TINY_TITAN_INBOX_URL not set")
	else:
		App.inbox.set_source(url.path_join("redirect"))
		var h1 = await _check_and_wait()
		check(h1.ok and h1.fresh.size() == 2, "HTTP (via a redirect): 2 fresh (%s)" % str(h1.get("error")))
		App.inbox.set_source(url.path_join("private"))
		var h2 = await _check_and_wait()
		check(not h2.ok and h2.error == PhoneInbox.NOT_SHARED, "HTML page: 'not shared' message")
		App.inbox.set_source(url.path_join("missing"))
		var h3 = await _check_and_wait()
		check(not h3.ok and str(h3.error).contains("404"), "HTTP 404: %s" % h3.error)
		App.inbox.set_source("http://127.0.0.1:1/nothing")
		var h4 = await _check_and_wait()
		check(not h4.ok and str(h4.error).contains("Could not reach"), "unreachable: %s" % h4.error)
	print("INBOX DONE, failures: %d" % fails)
