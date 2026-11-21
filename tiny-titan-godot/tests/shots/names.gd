extends RefCounted
## Lift names in the phone note (run with the "new" data): a name that is not
## exactly one of the player's lifts is matched by its words, and the review
## asks about it: yes, no, or pick another. What is answered, or imported as
## shown, is remembered, so the same words are not asked about twice.
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


## The small keys of the open review whose tooltip starts with `tip`, top to bottom.
func _keys(tip: String) -> Array:
	var out = []
	if _sheet() == null:
		return out
	for n in ShotHelper.walk(_sheet()):
		if n is Button and n.tooltip_text.begins_with(tip):
			out.append(n)
	return out


func _lift_names(date: String) -> Array:
	var out = []
	for s in App.sessions():
		if s.discipline == "lift" and s.date == date:
			for ex in s.exercises:
				out.append(str(ex.name))
	return out


## Open the review for a pasted note and return its result.
func _review(text: String) -> Dictionary:
	await _close_sheets()
	var r = App.inbox.check_text(text)
	InboxSheet.open(r)
	await ShotHelper.wait(tree, 0.6)
	return r


func _import() -> void:
	var imp = ShotHelper.find_button(_sheet(), "Import")
	ShotHelper.press(imp)
	await ShotHelper.frames(tree, 4)
	await _dismiss_reels()


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	var today = App.today
	var d1 = Dates.add_days(today, -6)
	var d2 = Dates.add_days(today, -2)

	# --- a first day: names that are sure, two to confirm, one new with its closest, one new -----
	# A lift is its movement and a variation ("Shrug - Barbell"); the review asks only about
	# what it cannot be sure of.
	var note1 = "%s
cable fly 3x12 @ 20
bayesian curl 3x10 @ 15
jefferson curl 3x10 @ 20
neck 4 way - 3x20@10
barbell shrug 3x10 @ 135
squat 3x5 @ 185"
	var r1 = await _review(note1 % d1)
	var key1 = str(r1.fresh[0].key) if r1.fresh.size() == 1 else ""
	var said = ShotHelper.all_text(_sheet())
	check(r1.fresh.size() == 1 and r1.fresh[0].get("names", []).size() == 4, "day 1: four names to ask about; shrug and squat are sure (%s)" % str(r1.fresh[0].get("names")))
	check(said.contains("= Chest Fly - Cable?") and said.contains("= Bicep Curl - Bayesian?"), "a name some movements share is taken as the likeliest, and asked")
	check(said.contains("New lift · \"jefferson curl\"") and said.contains("Same as Bicep Curl?") and said.contains("New lift · \"neck 4 way\"") and said.contains("= Neck 4 Way"), "a new lift with its closest, and one with nothing like it")
	check(_keys("Yes, it is").size() == 3 and _keys("No, it is a lift of its own").size() == 3 and _keys("Pick another lift").size() == 4, "three questions, and 'another' on all four")
	await ShotHelper.snap(tree, "names_1_review")
	# Yes on the first: the next key must not move.
	var next_y = _keys("Yes, it is")[1].get_global_rect().position.y
	ShotHelper.press(_keys("Yes, it is")[0])
	await ShotHelper.frames(tree, 5)
	check(_keys("Yes, it is").size() == 2 and absf(_keys("Yes, it is")[0].get_global_rect().position.y - next_y) <= 1.0, "answering one row leaves the next key where it was (%s -> %s)" % [str(next_y), str(_keys("Yes, it is")[0].get_global_rect().position.y) if not _keys("Yes, it is").is_empty() else "-"])
	# No on the second: a movement of its own, under the words written.
	ShotHelper.press(_keys("No, it is a lift of its own")[0])
	await ShotHelper.frames(tree, 5)
	said = ShotHelper.all_text(_sheet())
	check(said.contains("= Bayesian Curl") and not said.contains("Bicep Curl - Bayesian?"), "'no' keeps it as a movement of its own")
	# The third stays as shown (Jefferson Curl, a lift of its own). Another on the last: the picker.
	ShotHelper.press(_keys("Pick another lift")[3])
	await ShotHelper.wait(tree, 0.6)
	var picker = _sheet()
	check(picker != null and ShotHelper.all_text(picker).contains("You wrote \"neck 4 way\".") and ShotHelper.all_text(picker).contains("A lift of its own"), "the picker says what was written, and offers a lift of its own")
	await ShotHelper.snap(tree, "names_2_picker")
	var field = null
	for n in ShotHelper.walk(picker):
		if n is LineEdit:
			field = n
	ShotHelper.type_into(field, "shrug")
	await ShotHelper.frames(tree, 4)
	var listed = ShotHelper.all_text(picker)
	check(listed.contains("Shrug") and listed.contains("Dumbbell") and listed.contains("Barbell"), "typing searches every movement, with its variations")
	ShotHelper.type_into(field, "Neck Circles")
	await ShotHelper.frames(tree, 4)
	var own_row = null
	for n in ShotHelper.walk(picker):
		if n is Card and ShotHelper.all_text(n).begins_with("Name it \"Neck Circles\""):
			own_row = n
	check(own_row != null, "a name nobody has can be given")
	if own_row != null:
		ShotHelper.reveal(own_row)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, own_row)
	await ShotHelper.wait(tree, 0.6)
	said = ShotHelper.all_text(_sheet())
	check(_sheet() != picker and said.contains("= Neck Circles") and _keys("Yes, it is").size() == 1, "picked: the picker closes and the row shows the name")
	check(App.inbox.last_result().fresh.size() == 1 and str(App.inbox.last_result().fresh[0].key) == key1, "the entry keeps its key whatever is decided")
	await ShotHelper.snap(tree, "names_3_answered")
	await _import()
	var want = ["Chest Fly - Cable", "Bayesian Curl", "Jefferson Curl", "Neck Circles", "Shrug - Barbell", "Squat - Barbell"]
	check(_lift_names(d1) == want, "imported under those names (%s)" % str(_lift_names(d1)))
	check(App.inbox.names_count() == 4 and App.inbox.settings().names.get(LiftMatch.key("jefferson curl")) == "", "three answers and the row imported as shown are remembered (%d)" % App.inbox.names_count())

	# --- another day, the same lifts in other words: nothing to ask ------------------------
	var note2 = "%s
chest fly - cable 3x12 @ 25
bayesian curls 3x10 @ 15
jefferson curl 3x10 @ 25
neck 4 way - 3x20@10
shrugs - barbell 3x10 @ 155
back squat 3x5 @ 190"
	var r2 = await _review(note2 % d2)
	check(r2.fresh.size() == 1 and _keys("Pick another lift").is_empty() and not ShotHelper.all_text(_sheet()).contains("New lift"), "the same lifts in other words on another day: no questions")
	await ShotHelper.snap(tree, "names_4_no_questions")
	await _import()
	check(_lift_names(d2) == want, "and the same lifts (%s)" % str(_lift_names(d2)))
	var seen = {}
	for s in App.sessions():
		if s.discipline == "lift" and (s.date == d1 or s.date == d2):
			for ex in s.exercises:
				seen[str(ex.name)] = true
	check(seen.size() == 6, "two days, six lifts, none split by its spelling (%s)" % str(seen.keys()))

	# --- Settings: the remembered names can be forgotten -------------------------------------
	await _close_sheets()
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.6)
	var line = ShotHelper.find_text(_sheet(), "4 lift names remembered")
	check(line != null, "Settings says how many names are remembered")
	if line != null:
		ShotHelper.reveal(line)
		await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "names_5_settings")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Forget"))
	await ShotHelper.wait(tree, 0.5)
	check(App.inbox.names_count() == 0 and ShotHelper.find_text(_sheet(), "lift names remembered") == null, "Forget clears them, and the line goes")
	var r4 = await _review("%s\ncable fly 3x12 @ 25" % today)
	check(r4.fresh.size() == 1 and ShotHelper.all_text(_sheet()).contains("= Chest Fly - Cable?"), "after that the review asks again")
	await _close_sheets()
	print("NAMES DONE, failures: %d" % fails)
