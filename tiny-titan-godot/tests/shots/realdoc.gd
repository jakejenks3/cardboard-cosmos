extends RefCounted
## Phone inbox against a real shared link (development tool): set
## TINY_TITAN_INBOX_URL to a Google Doc / Sheet / file link, run with "fresh" data.
## Prints the raw text the game received, what it understood, and saves a
## screenshot of the review sheet.

func run(main: Node, tree: SceneTree) -> void:
	var url = OS.get_environment("TINY_TITAN_INBOX_URL")
	if url == "":
		print("REALDOC: TINY_TITAN_INBOX_URL not set")
		return
	App.inbox.set_source(url)
	print("REALDOC fetch url: ", PhoneInbox.fetch_url(url))
	var box = {"r": null}
	App.inbox.checked.connect(func(r): box.r = r, CONNECT_ONE_SHOT)
	App.inbox.check(false)
	for i in range(200):
		if box.r != null:
			break
		await ShotHelper.wait(tree, 0.1)
	var r = box.r
	if r == null:
		print("REALDOC: no answer after 20 s")
		return
	print("REALDOC ok=%s error=%s already=%d" % [str(r.ok), str(r.get("error")), int(r.get("already", 0))])
	print("REALDOC raw text ----")
	print(App.inbox.last_checked_text())
	print("REALDOC raw text end ----")
	for e in r.get("fresh", []):
		print("REALDOC fresh: ", JSON.stringify(e))
	for p in r.get("problems", []):
		print("REALDOC problem: ", JSON.stringify(p))
	await ShotHelper.frames(tree, 10)
	await ShotHelper.snap(tree, "realdoc_review")
