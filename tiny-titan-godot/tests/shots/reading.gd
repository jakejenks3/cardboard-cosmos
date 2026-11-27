extends RefCounted
## Reading walkthrough: the card on the Hero tab (one tap adds pages and the
## key does not move), the sheet (another day, the exact number, the goal),
## the save file, and what a few weeks of pages unlock. Run with `year` data.

var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _sheet():
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			return c
	return null


func _close_sheets(tree: SceneTree) -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet:
			c.close()
	await ShotHelper.wait(tree, 0.4)


func _card(main: Node):
	var l = ShotHelper.find_text(main, "of 10 pages today")
	var p = l
	while p != null and not (p is Card):
		p = p.get_parent()
	return p


func run(main: Node, tree: SceneTree) -> void:
	var today = App.today
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	check(Reading.pages(App.state) == 0 and not App.state.has("reading"), "nothing read yet")
	var card = _card(main)
	check(card != null, "the Hero tab has a Reading card")
	if card == null:
		return
	ShotHelper.reveal(card)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "reading_01_card_empty")

	# --- one tap adds pages; the key stays where it is --------------------------------
	var xp_before = int(App.state.xp.hero)
	var key = ShotHelper.find_button(card, "+10")
	var y0 = key.global_position.y
	var x0 = key.global_position.x
	# The mouse is over the key, as it is when a person clicks it.
	var mv = InputEventMouseMotion.new()
	mv.position = key.get_global_rect().get_center()
	mv.global_position = mv.position
	tree.root.push_input(mv)
	await ShotHelper.frames(tree, 2)
	for i in range(3):
		key = ShotHelper.find_button(_card(main), "+10")
		ShotHelper.press(key)
		await ShotHelper.frames(tree, 12)
		key = ShotHelper.find_button(_card(main), "+10")
		check(absf(key.global_position.y - y0) < 1.0 and absf(key.global_position.x - x0) < 1.0, "tap %d: the +10 key has not moved (%.0f, was %.0f)" % [i + 1, key.global_position.y, y0])
	check(Reading.pages_on(App.state, today) == 30, "three taps: 30 pages today (%d)" % Reading.pages_on(App.state, today))
	check(App.reading().size() == 1 and int(App.reading()[0].pages) == 30, "one entry for the day in the save")
	# 60 XP for the pages, 50 for First Chapter, and 100 more (Brains and Brawn) when today also has a workout.
	var want_xp = 60 + 50 + (100 if int(App.state.dateCounts.get(today, 0)) > 0 else 0)
	check(int(App.state.xp.hero) == xp_before + want_xp, "the pages and their trophies paid %d XP (%d)" % [want_xp, int(App.state.xp.hero) - xp_before])
	check(int(App.state.totals.sessions) == App.sessions().size(), "no session was added")
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "reading_02_card_30_pages")

	# --- the sheet: the shelf, the day, the last two weeks ----------------------------------
	ReadingView.open()
	await ShotHelper.wait(tree, 0.6)
	var sh = _sheet()
	check(sh != null and ShotHelper.find_text(sh, "Bookshelf") != null, "the Reading sheet opens")
	await ShotHelper.snap(tree, "reading_03_sheet")
	# yesterday: 25 pages with a key, then the exact number
	ReadingView._pick_day(Dates.add_days(today, -1))
	await ShotHelper.frames(tree, 6)
	ShotHelper.press(ShotHelper.find_button(_sheet(), "+25"))
	await ShotHelper.frames(tree, 8)
	check(Reading.pages_on(App.state, Dates.add_days(today, -1)) == 25, "25 pages on the day before")
	check(Reading.streak(App.state) == 2, "two days in a row (%d)" % Reading.streak(App.state))
	ReadingView._set_exact("40", Dates.add_days(today, -1))
	await ShotHelper.frames(tree, 8)
	check(Reading.pages_on(App.state, Dates.add_days(today, -1)) == 40 and App.reading().size() == 2, "typing 40 sets that day to 40")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "-1"))
	await ShotHelper.frames(tree, 8)
	check(Reading.pages_on(App.state, Dates.add_days(today, -1)) == 39, "-1 takes a page back")
	ReadingView._set_exact("0", Dates.add_days(today, -3))
	ReadingView._set_exact("abc", Dates.add_days(today, -1))
	check(App.reading().size() == 2 and Reading.pages_on(App.state, Dates.add_days(today, -1)) == 39, "0 on an empty day and a word change nothing")
	ReadingView._set_goal(20)
	await ShotHelper.frames(tree, 8)
	check(Reading.goal(App.settings()) == 20 and ShotHelper.find_text(main, "of 20 pages today") != null, "the daily goal is 20 now, on the card too")
	await ShotHelper.snap(tree, "reading_04_sheet_yesterday")
	ReadingView._set_goal(10)
	await _close_sheets(tree)
	check(not App.changed.is_connected(ReadingView._refresh), "the closed sheet no longer listens")

	# --- the save file keeps it, and an older save still loads ---------------------------------
	var on_disk = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
	check(on_disk != null and on_disk.reading.size() == 2 and int(Reading.entry_on(on_disk.reading, today).pages) == 30, "the save file holds both days")
	var older = App.parse_saved({"sessions": [], "profile": {"name": "x"}})
	check(older != null and older.reading is Array and older.reading.is_empty(), "a save from before reading loads with an empty log")

	# --- five weeks of pages: the shelf fills, things unlock ------------------------------------
	for i in range(2, 36):
		App.set_reading(Dates.add_days(today, -i), 28 + (i * 7) % 23)
	await ShotHelper.wait(tree, 0.4)
	var st = App.state
	print("AFTER 36 DAYS: pages=%d days=%d streak=%d best=%d level=%d books=%d both=%d" % [Reading.pages(st), Reading.days(st), Reading.streak(st), Reading.best_streak(st), int(Reading.level_of(st).level), Reading.books(st), Reading.both_days(st)])
	check(Reading.days(st) == 36 and Reading.streak(st) == 36, "36 days in a row")
	check(st.pets.has("owl") and st.items.has("read_glasses") and st.items.has("read_satchel"), "the owl, the glasses and the satchel are unlocked")
	check(st.achievements.has("read_1000") and st.achievements.has("read_streak_30") and st.achievements.has("read_both_1"), "the trophies that go with it")
	check(Reading.both_days(st) > 5, "days with reading and training are counted (%d)" % Reading.both_days(st))
	check(int(st.coins.by.reading) > 0, "reading paid coins (%d)" % int(st.coins.by.reading))
	App.go("home")
	await ShotHelper.wait(tree, 4.2)
	ShotHelper.reveal(_card(main))
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "reading_05_card_after_weeks")
	ReadingView.open()
	await ShotHelper.wait(tree, 0.6)
	await ShotHelper.snap(tree, "reading_06_sheet_shelf")
	var box = _sheet().box
	var sc = box.get_parent()
	while sc != null and not (sc is ScrollContainer):
		sc = sc.get_parent()
	if sc != null:
		sc.scroll_vertical = 400
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "reading_07_sheet_two_weeks")
	await _close_sheets(tree)

	# --- pages written in the phone note ---------------------------------------------------------
	var nd = Dates.add_days(today, -40)
	var head = "%d/%d" % [int(nd.substr(5, 2)), int(nd.substr(8, 2))]
	var pages_before = Reading.pages(App.state)
	# The review is the point here: nothing is imported on its own.
	App.update_inbox({"autoImport": false})
	var r1 = App.inbox.check_text(head + "
read 20 pages
bench 3x5 @ 60")
	var note_read = null
	for e in r1.fresh:
		if e.kind == "reading":
			note_read = e
	check(r1.ok and r1.fresh.size() == 2 and note_read != null and note_read.date == nd and note_read.summary == "Read 20 pages", "the note's 'read 20 pages' is found, dated %s" % nd)
	InboxSheet.open(r1)
	await ShotHelper.wait(tree, 0.7)
	await ShotHelper.snap(tree, "reading_10_note_review")
	await _close_sheets(tree)
	if note_read != null:
		App.inbox.import_entries([note_read])
		await ShotHelper.frames(tree, 6)
		check(Reading.pages_on(App.state, nd) == 20 and Reading.pages(App.state) == pages_before + 20, "importing it adds 20 pages on that day")
		check(int(App.inbox.settings().imported.get(note_read.key, 0)) == 1, "its key is remembered")
		var r2 = App.inbox.check_text(head + "
read 20 pages")
		check(r2.fresh.is_empty() and int(r2.already) == 1, "the same note again: nothing new")
		# The line is edited in the note after the import: the day changes by the difference.
		var r3 = App.inbox.check_text(head + "
read 35 pages")
		check(r3.fresh.size() == 1 and r3.fresh[0].has("replaces") and not r3.fresh[0].get("skip", false), "an edited line is an update of that day, ticked")
		App.inbox.import_entries(r3.fresh)
		await ShotHelper.frames(tree, 6)
		check(Reading.pages_on(App.state, nd) == 35 and Reading.pages(App.state) == pages_before + 35, "after the update the day has 35 pages, not 55 (%d)" % Reading.pages_on(App.state, nd))
		# Pages added by hand on the same day stay.
		App.add_reading(5, nd)
		var r4 = App.inbox.check_text(head + "
read 40 pages")
		App.inbox.import_entries(r4.fresh)
		await ShotHelper.frames(tree, 6)
		check(Reading.pages_on(App.state, nd) == 45, "pages added by hand that day are kept through an update (%d)" % Reading.pages_on(App.state, nd))
		var disk = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
		var kept = Reading.entry_on(disk.reading, nd)
		check(kept != null and kept.get("inbox") is Dictionary and kept.inbox.size() == 1 and int(kept.inbox.values()[0]) == 40, "the save remembers which note line brought which pages")
	await _close_sheets(tree)

	# --- the Log tab has a Reading key; the trophies have a Reading group -------------------------
	App.open_log(null)
	await ShotHelper.wait(tree, 0.6)
	var rk = ShotHelper.find_text(main, "pages today")
	check(rk != null, "the Log tab has a Reading key")
	ShotHelper.scroll_main(main, 300)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "reading_08_log_key")
	App.go("adventure", "trophies")
	await ShotHelper.wait(tree, 0.7)
	check(ShotHelper.find_button(main, "Reading") != null or ShotHelper.find_text(main, "Reading") != null, "the trophies have a Reading group")
	await ShotHelper.snap(tree, "reading_09_trophies")
	print("READING WALK DONE: %d failed" % fails)
