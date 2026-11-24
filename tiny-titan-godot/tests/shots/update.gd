extends RefCounted
## The phone app's "new version ready" (run with the "year" data, also with
## --fingers). A newer build fetched behind the one on screen is pretended
## here (WebUpdate.pretend; the real thing is the page's service worker, tried
## in a browser): the Hero tab then has a card with a Restart key, and
## Settings -> Phone app a row with one. Without it there is no card.
## Prints CHECK lines.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _with_meta(meta: String, root = null):
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			top = c
	return top


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	await ShotHelper.wait(tree, 0.8)
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	check(not WebUpdate.ready() and _with_meta("update_card") == null, "nothing newer: the Hero tab has no update card")
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.7)
	check(_with_meta("update_row", Kit.overlay_root) == null and PhoneAppCard.update_row() == null, "and on a PC Settings says nothing about updates")
	_sheet().close()
	await ShotHelper.wait(tree, 0.6)

	# The phone app, nothing newer yet: Settings offers to look now.
	WebUpdate.pretend = "idle"
	var idle = PhoneAppCard.update_row()
	var idle_key = _with_meta("update_key", idle) if idle != null else null
	check(idle != null and ShotHelper.find_text(idle, "Updates come by themselves") != null and idle_key != null and str(idle_key.text) == "Check now" and not WebUpdate.ready(), "the phone app, nothing newer: Settings has a Check now key")
	main._ask_update()
	await ShotHelper.frames(tree, 4)
	check(not WebUpdate.announced and _with_meta("update_card") == null, "and the Hero tab still has no card")
	if idle != null:
		idle.free()

	# A newer build has been fetched and has taken over (as the page would say).
	WebUpdate.pretend = "ready"
	main._ask_update()
	await ShotHelper.wait(tree, 0.8)
	check(WebUpdate.announced, "the game says so once")
	var card = _with_meta("update_card")
	var key = _with_meta("update_restart")
	check(card != null and ShotHelper.find_text(card, "New version ready") != null and key != null and str(key.text) == "Restart", "the Hero tab has a New version ready card with a Restart key")
	var today = ShotHelper.find_text(main, "Feeling")
	check(card != null and today != null and card.global_position.y < today.global_position.y, "above the day's plan")
	await ShotHelper.snap(tree, "update_1_hero")
	if key != null:
		ShotHelper.press(key)
	await ShotHelper.wait(tree, 0.5)
	check(_with_meta("update_card") != null, "on a PC the key has nothing to restart: the card stays")
	await ShotHelper.wait(tree, 2.5)

	# Settings -> Phone app shows the same (its row; on a PC the card itself
	# only says how to set the phone app up).
	var row = PhoneAppCard.update_row()
	var row_key = _with_meta("update_key", row) if row != null else null
	check(row != null and ShotHelper.find_text(row, "A new version is ready") != null and row_key != null and str(row_key.get_meta("update_key")) == "restart" and str(row_key.text) == "Restart", "Settings, Phone app: the same, with its Restart key")
	if row != null:
		row.free()

	WebUpdate.pretend = ""
	check(not WebUpdate.can() and not WebUpdate.ready(), "the PC build itself never updates this way")
	App.go("home")
	await ShotHelper.wait(tree, 0.5)
	print("UPDATE WALK: %d failed" % fails)
