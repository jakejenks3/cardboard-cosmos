extends RefCounted
## Phone inbox against a real shared link (development tool): set
## TINY_TITAN_INBOX_URL to a Google Doc / Sheet / file link, run with "new" data
## (a profile, nothing logged). The entries it finds are imported at the end.
## Prints the raw text the game received, what it understood, and saves a
## screenshot of the review sheet.

func run(main: Node, tree: SceneTree) -> void:
	var url = OS.get_environment("TINY_TITAN_INBOX_URL")
	if url == "":
		print("REALDOC: TINY_TITAN_INBOX_URL not set")
		return
	# TINY_TITAN_UNITS=lb,mi shows the review in pounds and miles.
	var units = OS.get_environment("TINY_TITAN_UNITS").split(",", false)
	if units.size() == 2:
		App.update_settings({"weightUnit": units[0], "distanceUnit": units[1]})
	App.inbox.set_source(url)
	print("REALDOC fetch url: ", PhoneInbox.fetch_url(url))
	var box = {"r": null}
	var t0 = Time.get_ticks_msec()
	App.inbox.checked.connect(func(r): box.r = r, CONNECT_ONE_SHOT)
	App.inbox.check(false)
	for i in range(600):
		if box.r != null:
			break
		await ShotHelper.wait(tree, 0.1)
	var r = box.r
	if r == null:
		print("REALDOC: no answer after 60 s")
		return
	print("REALDOC answered in %d ms; pictures read: %s" % [Time.get_ticks_msec() - t0, JSON.stringify(App.inbox._readings)])
	print("REALDOC ok=%s error=%s already=%d" % [str(r.ok), str(r.get("error")), int(r.get("already", 0))])
	print("REALDOC raw text ----")
	print(App.inbox.last_text)
	print("REALDOC raw text end ----")
	for e in r.get("fresh", []):
		print("REALDOC fresh: ", JSON.stringify(e))
	for p in r.get("problems", []):
		print("REALDOC problem: ", JSON.stringify(p))
	InboxSheet.open(r)
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "realdoc_review")
	# Import everything through the sheet's button and show that the pictures
	# landed as progress photos.
	var imp = null
	for n in ShotHelper.walk(main):
		if n is Button and n.text.begins_with("Import"):
			imp = n
	if imp == null:
		print("REALDOC: nothing to import")
		return
	ShotHelper.press(imp)
	await ShotHelper.frames(tree, 4)
	# Through the results reel.
	for i in range(12):
		var b = ShotHelper.find_button(main, "Tap to skip")
		if b == null:
			b = ShotHelper.find_button(main, "Continue")
		if b == null:
			break
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.6)
	for b in App.saved.body:
		var ph = b.get("photos", {})
		var have = []
		for a in TT.PHOTO_ANGLES:
			if ph is Dictionary and ph.has(a):
				have.append("%s=%s" % [a, "ok" if App.has_photo(ph[a]) else "MISSING"])
		print("REALDOC body %s: %s" % [str(b.date), ", ".join(PackedStringArray(have))])
	App.go("journey", "body")
	await ShotHelper.wait(tree, 1.5)
	await ShotHelper.snap(tree, "realdoc_body")
