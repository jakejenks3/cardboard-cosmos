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
	var d3 = Dates.add_days(today, -1)

	# --- a first day: a lift of the player's own, and their own name for a library lift ----
	var r1 = await _review("%s\nseated row - cable, 1UE 3x10 @ 40\nchest fly - cable 3x12 @ 20\nsquat 3x5 @ 185" % d1)
	var said = ShotHelper.all_text(_sheet())
	check(r1.fresh.size() == 1 and r1.fresh[0].get("names", []).size() == 2, "day 1: two names to ask about, squat is exact (%s)" % str(r1.fresh[0].get("names")))
	check(said.contains("\"seated row cable, 1ue\" · new lift") and said.contains("Same as Seated Cable Row?") and said.contains("= Cable Fly?"), "the review asks: a new lift with its closest, and the library lift with the same words")
	check(_keys("Yes, it is").size() == 2 and _keys("No, it is a lift of its own").size() == 2 and _keys("Pick another lift").size() == 2, "each has yes, no and another")
	ShotHelper.press(_keys("No, it is a lift of its own")[0])
	await ShotHelper.frames(tree, 4)
	ShotHelper.press(_keys("No, it is a lift of its own")[0])
	await ShotHelper.frames(tree, 4)
	said = ShotHelper.all_text(_sheet())
	check(said.contains("= Seated Row Cable, 1UE") and said.contains("= Chest Fly Cable") and not said.contains("?") and _keys("Yes, it is").is_empty() and _keys("Pick another lift").size() == 2, "'no' twice: both are lifts of the player's own, the rows show it and keep 'another'")
	await _import()
	check(_lift_names(d1) == ["Seated Row Cable, 1UE", "Chest Fly Cable", "Squat"], "imported under those names (%s)" % str(_lift_names(d1)))
	check(App.inbox.names_count() == 2, "both answers are remembered (%d)" % App.inbox.names_count())

	# --- another day, the same lifts in other words, and two new ones ----------------------
	var note2 = "%s\nseated row single arm, home pulley 3x10 @ 45\ncable fly 3x12 @ 25\nincline dumbbell hammer curl 3x10 @ 20\nneck 4 way - 3x20@10\nsquat 3x5 @ 190"
	var r2 = await _review(note2 % d2)
	var key2 = str(r2.fresh[0].key) if r2.fresh.size() == 1 else ""
	said = ShotHelper.all_text(_sheet())
	check(r2.fresh.size() == 1 and r2.fresh[0].get("names", []).size() == 4, "day 2: four names to ask about (%s)" % str(r2.fresh[0].get("names")))
	check(said.contains("= Seated Row Cable, 1UE?") and said.contains("= Chest Fly Cable?"), "other words for their own lifts are taken as those lifts")
	check(said.contains("Same as Incline Dumbbell Curl?") and said.contains("\"neck 4 way\" · new lift") and said.contains("= Neck 4 Way"), "one more word is a new lift with its closest; nothing like it is just new")
	check(_keys("Yes, it is").size() == 3 and _keys("Pick another lift").size() == 4, "three questions, and 'another' on all four")
	await ShotHelper.snap(tree, "names_1_review")
	# Yes on the first: the next key must not move.
	var next_y = _keys("Yes, it is")[1].get_global_rect().position.y
	ShotHelper.press(_keys("Yes, it is")[0])
	await ShotHelper.frames(tree, 5)
	check(_keys("Yes, it is").size() == 2 and absf(_keys("Yes, it is")[0].get_global_rect().position.y - next_y) <= 1.0, "answering one row leaves the next key where it was (%s -> %s)" % [str(next_y), str(_keys("Yes, it is")[0].get_global_rect().position.y if not _keys("Yes, it is").is_empty() else -1.0)])
	# The second stays as shown (its own lift for the library's Cable Fly); no on the third.
	ShotHelper.press(_keys("No, it is a lift of its own")[1])
	await ShotHelper.frames(tree, 5)
	said = ShotHelper.all_text(_sheet())
	check(said.contains("= Incline Dumbbell Hammer Curl") and not said.contains("Same as Incline Dumbbell Curl?"), "'no' keeps the new lift under its own name")
	# Another on the last: the picker.
	ShotHelper.press(_keys("Pick another lift")[3])
	await ShotHelper.wait(tree, 0.6)
	var picker = _sheet()
	check(picker != null and ShotHelper.all_text(picker).contains("You wrote \"neck 4 way\".") and ShotHelper.all_text(picker).contains("A lift of its own") and ShotHelper.all_text(picker).contains("Chest Fly Cable"), "the picker says what was written, lists their lifts and offers a lift of its own")
	await ShotHelper.snap(tree, "names_2_picker")
	var field = null
	for n in ShotHelper.walk(picker):
		if n is LineEdit:
			field = n
	ShotHelper.type_into(field, "curl")
	await ShotHelper.frames(tree, 4)
	var listed = ShotHelper.all_text(picker)
	check(listed.contains("Bicep Curl") and listed.contains("Name it \"curl\""), "typing searches the lifts, and offers the typed name")
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
	check(App.inbox.last_result().fresh.size() == 1 and str(App.inbox.last_result().fresh[0].key) == key2, "the entry keeps its key whatever is decided")
	await ShotHelper.snap(tree, "names_3_answered")
	await _import()
	check(_lift_names(d2) == ["Seated Row Cable, 1UE", "Chest Fly Cable", "Incline Dumbbell Hammer Curl", "Neck Circles", "Squat"], "day 2 is in under the decided names (%s)" % str(_lift_names(d2)))
	check(App.inbox.names_count() == 6 and App.inbox.settings().names.get(LiftMatch.key("cable fly")) == "Chest Fly Cable", "the row that was imported as shown is remembered too (%d)" % App.inbox.names_count())

	# --- the same words again: nothing to ask ----------------------------------------------
	var r3 = await _review(note2 % d3)
	check(r3.fresh.size() == 1 and _keys("Pick another lift").is_empty() and not ShotHelper.all_text(_sheet()).contains("new lift"), "the same words on another day: no questions")
	await ShotHelper.snap(tree, "names_4_no_questions")
	await _import()
	check(_lift_names(d3) == _lift_names(d2), "and the same lifts (%s)" % str(_lift_names(d3)))
	var seen = {}
	for s in App.sessions():
		if s.discipline == "lift":
			for ex in s.exercises:
				seen[str(ex.name)] = true
	check(seen.size() == 5, "three days, five lifts in the log, none split by its spelling (%s)" % str(seen.keys()))

	# --- Settings: the remembered names can be forgotten -------------------------------------
	await _close_sheets()
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.6)
	var line = ShotHelper.find_text(_sheet(), "6 lift names remembered")
	check(line != null, "Settings says how many names are remembered")
	if line != null:
		ShotHelper.reveal(line)
		await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "names_5_settings")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Forget"))
	await ShotHelper.wait(tree, 0.5)
	check(App.inbox.names_count() == 0 and ShotHelper.find_text(_sheet(), "lift names remembered") == null, "Forget clears them, and the line goes")
	var r4 = await _review("%s\ncable fly 3x12 @ 25" % today)
	check(r4.fresh.size() == 1 and ShotHelper.all_text(_sheet()).contains("= Chest Fly Cable?"), "after that the review asks again")
	await _close_sheets()
	print("NAMES DONE, failures: %d" % fails)
