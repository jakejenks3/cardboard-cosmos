extends RefCounted
## The weekly bounty and the recaps on screen: the bounty card on the Hero and
## Adventure tabs, its sheet, the reel after a session that beats the monster
## (bounty card, coins card), the Story page, the week and month recap posters
## and saving one as a picture. Run with "year" data.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func results():
	for n in ShotHelper.walk(main):
		if n is ResultsOverlay:
			return n
	return null


func card_of(root: Node, text: String):
	for n in ShotHelper.walk(root):
		if n is Label and n.text == text:
			var p = n
			while p != null and not (p is Card):
				p = p.get_parent()
			if p != null:
				return p
	return null


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	var w = Bounty.of(App.state)
	var cur = w.current
	var mon = Bounty.monster(cur.monster)
	print("BOUNTY this week: %s hp %d damage %d weak %s wins %d streak %d" % [mon.name, int(cur.hp), int(cur.damage), str(cur.weak), int(w.wins), int(w.streak)])
	check(int(w.wins) >= 10 and w.history.size() >= 40, "a year of training has a long bounty history (%d wins of %d weeks)" % [int(w.wins), w.history.size()])

	# --- Hero tab ---------------------------------------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var hc = card_of(main, mon.name)
	check(hc != null, "the Hero tab shows this week's bounty (%s)" % mon.name)
	if hc != null:
		ShotHelper.reveal(hc)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "bounty_01_home")
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "bounty_01b_home_top")

	# --- Adventure tab and the sheet ------------------------------------------------------
	App.go("adventure", "campaign")
	await ShotHelper.wait(tree, 0.8)
	var ac = card_of(main, mon.name)
	check(ac != null, "the Adventure tab shows it too")
	ShotHelper.scroll_main(main, 330)
	await ShotHelper.snap(tree, "bounty_02_adventure")
	ShotHelper.scroll_main(main, 0)
	BountyView.open()
	await ShotHelper.wait(tree, 0.8)
	check(sheet() != null and ShotHelper.find_text(sheet(), "IN A ROW") != null and ShotHelper.find_text(sheet(), mon.epithet) != null, "the bounty sheet shows the monster and your record")
	await ShotHelper.snap(tree, "bounty_03_sheet")
	sheet()._scroll.scroll_vertical = 560
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "bounty_04_sheet_b")
	sheet().close()
	await ShotHelper.wait(tree, 0.5)

	# --- a session that beats the monster: the reel ------------------------------------------
	var coins_before = App.coins()
	var wins_before = int(Bounty.wins(App.state))
	var big = App.build_session({"discipline": "ride", "date": App.today, "distanceM": 120000.0, "elevationM": 1500.0, "durationSec": 16200})
	App.commit_sessions([big], "Ride logged!")
	await ShotHelper.wait(tree, 0.5)
	var after = Bounty.of(App.state).current
	check(after.defeated or cur.defeated, "a 120 km ride beats this week's monster (%d / %d)" % [int(after.damage), int(after.hp)])
	check(App.coins() > coins_before, "and pays coins (%d -> %d)" % [coins_before, App.coins()])
	var res = results()
	check(res != null, "the results reel opened")
	if res != null:
		var types = res._events.map(func(e): return e.type)
		check(types.has("coins"), "the reel has a coins card (%s)" % str(types))
		check(types.has("bounty") == (not cur.defeated or (after.crushed and not cur.crushed)), "and a bounty card when the monster was still up")
		await ShotHelper.wait(tree, 1.2)
		res._skip()
		await ShotHelper.wait(tree, 0.6)
		check(ShotHelper.find_text(res, "for the shop") != null, "the coins card is on screen")
		res._scroll.scroll_vertical = 0
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "bounty_05_reel_top")
		res._scroll.scroll_vertical = 100000
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "bounty_06_reel_end")
		ShotHelper.press(res._footer_btn)
		await ShotHelper.wait(tree, 0.6)
	if not cur.defeated:
		check(int(Bounty.wins(App.state)) == wins_before + 1, "one more bounty win")
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	var done = card_of(main, mon.name)
	if done != null:
		ShotHelper.reveal(done)
	await ShotHelper.frames(tree, 4)
	check(ShotHelper.find_text(main, "BOUNTY CLAIMED") != null or ShotHelper.find_text(main, "CRUSHED") != null, "the Hero tab now shows the bounty as claimed")
	await ShotHelper.snap(tree, "bounty_07_home_claimed")

	# --- the Story page lists the wins ---------------------------------------------------------
	App.go("journey", "chronicle")
	await ShotHelper.wait(tree, 0.8)
	check(ShotHelper.find_text(main, "Bounty: ") != null or ShotHelper.find_text(main, "Crushed ") != null, "bounty wins are in the Story")
	await ShotHelper.snap(tree, "bounty_08_story")

	# --- recaps ----------------------------------------------------------------------------------
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.8)
	check(ShotHelper.find_button(main, "This week") != null and ShotHelper.find_button(main, "This month") != null, "Journey has the recap buttons")
	await ShotHelper.snap(tree, "recap_01_journey")
	ShotHelper.press(ShotHelper.find_button(main, "This week"))
	await ShotHelper.wait(tree, 0.9)
	check(sheet() != null and ShotHelper.find_text(sheet(), "IN REVIEW") != null and ShotHelper.find_text(sheet(), "SESSIONS") != null, "the week recap opens with its poster")
	await ShotHelper.snap(tree, "recap_02_week")
	sheet()._scroll.scroll_vertical = 420
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "recap_03_week_b")
	# Earlier, then the month.
	var prev_btn = null
	for n in ShotHelper.walk(sheet()):
		if n is Button and n.tooltip_text == "Earlier":
			prev_btn = n
	check(prev_btn != null and not prev_btn.disabled, "there is an Earlier arrow")
	ShotHelper.press(prev_btn)
	await ShotHelper.wait(tree, 0.6)
	var last_wk = Dates.add_weeks(Dates.week_key(App.today), -1)
	check(ShotHelper.find_text(sheet(), Recap.title_of("week", last_wk)) != null, "Earlier shows last week")
	sheet()._scroll.scroll_vertical = 0
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "recap_04_last_week")
	sheet().close()
	await ShotHelper.wait(tree, 0.5)
	var last_month = Recap.shift("month", App.today.substr(0, 7), -1)
	RecapSheet.open("month", last_month)
	await ShotHelper.wait(tree, 0.9)
	check(ShotHelper.find_text(sheet(), Recap.title_of("month", last_month)) != null and ShotHelper.find_text(sheet(), "MONTH IN REVIEW") != null, "the month recap opens")
	await ShotHelper.snap(tree, "recap_05_month")
	sheet()._scroll.scroll_vertical = 420
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "recap_06_month_b")

	# --- save the poster as a picture ------------------------------------------------------------
	var r = Recap.build("month", last_month, App.state, App.sessions(), App.body(), App.today)
	var path = await RecapSheet.save_picture(r)
	check(path != "" and FileAccess.file_exists(path) and path.begins_with(App.DATA_DIR), "Save picture writes a PNG into the test data folder (%s)" % path)
	if path != "":
		var img = Image.load_from_file(path)
		check(img != null and img.get_width() >= 400 and img.get_height() >= 400, "the picture is a full poster (%dx%d)" % [img.get_width(), img.get_height()])
		print("RECAP PNG ", path)
	sheet().close()
	await ShotHelper.wait(tree, 0.4)

	# --- the Hero tab offers a finished recap once -------------------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	var offered = ShotHelper.find_text(main, "recap is ready")
	var should = int(App.today.substr(8, 2)) <= 7 or Dates.weekday_index(App.today) <= 2
	check((offered != null) == should, "the Hero tab offers a recap only at the start of a week or month (today %s: %s)" % [App.today, str(should)])

	# Pretend it is the Tuesday after: last week's recap is offered, once.
	var real_today = App.today
	App.today = Dates.add_days(Dates.week_key(real_today), 8)
	# When that Tuesday is in the first week of a month, last month's recap is
	# offered before last week's: take it as opened (the check failed in the
	# last week of November).
	if int(App.today.substr(8, 2)) <= 7:
		App.mark_recap_seen("month", Recap.shift("month", App.today.substr(0, 7), -1))
	App._recompute()
	App.changed.emit()
	await ShotHelper.wait(tree, 0.6)
	var offer = null
	for n in ShotHelper.walk(main):
		if n is Label and n.text == "Last week's recap is ready":
			offer = n
	check(offer != null, "on a Tuesday the Hero tab offers last week's recap")
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.snap(tree, "recap_07_home_offer")
	if offer != null:
		var oc = offer
		while oc != null and not (oc is Card):
			oc = oc.get_parent()
		oc._tap.call()
		await ShotHelper.wait(tree, 0.9)
		check(sheet() != null and ShotHelper.find_text(sheet(), Recap.title_of("week", Dates.week_key(real_today))) != null, "tapping it opens that week's recap")
		await ShotHelper.snap(tree, "recap_08_offered_week")
		sheet().close()
		await ShotHelper.wait(tree, 0.5)
		check(ShotHelper.find_text(main, "recap is ready") == null and str(App.recap_seen().get("week", "")) == Dates.week_key(real_today), "and it is not offered again")
	# The This week card opens the running week.
	var twc = card_of(main, "This week")
	check(twc != null, "the This week card is there")
	if twc != null:
		twc._tap.call()
		await ShotHelper.wait(tree, 0.8)
		check(sheet() != null and ShotHelper.find_text(sheet(), "so far") != null, "tapping This week opens the running week's recap")
		sheet().close()
		await ShotHelper.wait(tree, 0.4)
	print("BOUNTY DONE, failures: %d" % fails)
