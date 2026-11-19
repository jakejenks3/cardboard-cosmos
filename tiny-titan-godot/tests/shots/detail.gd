extends RefCounted
## What you did, trends, and physical therapy (run with the "year" data):
## a logged session opens a detail sheet that lists every exercise; an exercise
## opens the lift's page with its trends (weight, reps, volume, how often); the
## lift can be marked as physical therapy there, by "(PT)" in the phone note,
## or by "(PT)" typed in the Log tab; the Hero tab then shows whether the
## player is keeping up. Prints CHECK lines.

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


## Controls of the top sheet (or of `root`) whose tooltip starts with `tip`, top to bottom.
func _by_tip(tip: String, root = null) -> Array:
	var out = []
	var from = root if root != null else _sheet()
	if from == null:
		return out
	for n in ShotHelper.walk(from):
		if n is Control and n.tooltip_text.begins_with(tip):
			out.append(n)
	return out


func _count(kind, root = null) -> int:
	var n = 0
	var from = root if root != null else _sheet()
	if from == null:
		return 0
	for c in ShotHelper.walk(from):
		if is_instance_of(c, kind):
			n += 1
	return n


## How many "PT" badges the top sheet shows.
func _pt_tags(root = null) -> int:
	var n = 0
	var from = root if root != null else _sheet()
	if from == null:
		return 0
	for c in ShotHelper.walk(from):
		if c is Label and c.text == "PT":
			n += 1
	return n


func _newest_lift():
	var best = null
	for s in App.sessions():
		if s.discipline == "lift" and (best == null or s.date > best.date or (s.date == best.date and s.createdAt > best.createdAt)):
			best = s
	return best


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	var today = App.today

	# --- a session in the log opens everything that was done in it --------------------------
	App.go("journey", "history")
	await ShotHelper.wait(tree, 0.8)
	var first_row = _by_tip("Everything you did", main)
	check(not first_row.is_empty(), "the log's rows say they open the details")
	if not first_row.is_empty():
		await ShotHelper.click(tree, first_row[0])
		await ShotHelper.wait(tree, 0.6)
	check(_sheet() != null and ShotHelper.find_button(_sheet(), "Edit") != null, "a tap on a session opens its detail sheet, with an Edit key")
	await _close_sheets()
	var lift = _newest_lift()
	SessionView.open(lift)
	await ShotHelper.wait(tree, 0.6)
	var said = ShotHelper.all_text(_sheet())
	var all_named = true
	var with_sets = 0
	for ex in lift.exercises:
		if not SessionView.done_sets(ex).is_empty():
			with_sets += 1
			if not said.contains(str(ex.name)):
				all_named = false
	var rows = _by_tip("Trends and history of")
	check(all_named and rows.size() == with_sets and with_sets > 0, "the detail lists every exercise as a row of its own (%d of %d)" % [rows.size(), with_sets])
	await ShotHelper.snap(tree, "detail_1_session")

	# --- an exercise opens the lift's page -----------------------------------------------
	var lift_name = str(rows[0].tooltip_text).trim_prefix("Trends and history of ")
	await ShotHelper.click(tree, rows[0])
	await ShotHelper.wait(tree, 0.7)
	var page = _sheet()
	check(page != null and ShotHelper.find_text(page, lift_name) != null and ShotHelper.find_button(page, "How often") != null and ShotHelper.find_button(page, "Reps") != null, "a click on an exercise opens its page, with the trend picker (%s)" % lift_name)
	check(_count(LineChart) == 1 and ShotHelper.find_text(page, "since ") != null, "a line of the trend, and how much it changed")
	var trends_at = ShotHelper.find_button(page, "How often")
	ShotHelper.reveal(trends_at)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "detail_2_lift_trend")
	ShotHelper.press(ShotHelper.find_button(page, "Reps"))
	await ShotHelper.frames(tree, 4)
	check(_count(LineChart) == 1 and ShotHelper.find_text(page, "Every rep of each day") != null, "Reps: the reps of each day")
	ShotHelper.press(ShotHelper.find_button(page, "How often"))
	await ShotHelper.frames(tree, 4)
	check(_count(WeekBars) == 1 and _count(LineChart) == 0 and ShotHelper.find_text(page, "Days done in each of the last 8 weeks") != null, "How often: a bar per week")
	await ShotHelper.snap(tree, "detail_3_lift_how_often")
	var history_rows = _by_tip("Everything you did that day")
	check(not history_rows.is_empty(), "the history's days open that day's session")

	# --- physical therapy: the switch on the lift's page ----------------------------------
	var sw = _by_tip("Keep track of how often you do it")
	check(sw.size() == 1 and not Pt.is_pt(App.pt(), lift_name), "the page has a physical therapy switch, off")
	ShotHelper.reveal(sw[0])
	await ShotHelper.frames(tree, 3)
	ShotHelper.press(sw[0])
	await ShotHelper.frames(tree, 5)
	check(Pt.is_pt(App.pt(), lift_name) and ShotHelper.find_text(page, "of 3 this week") != null and _by_tip("One day more").size() == 1, "switched on: it is a PT lift, aiming for 3 days a week")
	var plus = _by_tip("One day more")[0]
	var plus_at = plus.get_global_rect().position
	ShotHelper.press(plus)
	await ShotHelper.frames(tree, 5)
	var plus2 = _by_tip("One day more")
	check(Pt.per_week(App.pt(), lift_name) == 4 and plus2.size() == 1 and plus2[0].get_global_rect().position.distance_to(plus_at) <= 1.0, "one day more: 4 a week, and the key did not move")
	await ShotHelper.snap(tree, "detail_4_lift_pt")
	ShotHelper.press(_by_tip("One day fewer")[0])
	await ShotHelper.frames(tree, 5)
	check(Pt.per_week(App.pt(), lift_name) == 3, "and back to 3")
	await _close_sheets()

	# --- the Hero tab's card, and the sheet behind it ------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var card = _by_tip("Physical therapy: are you keeping up?", main)
	check(card.size() == 1 and ShotHelper.find_text(card[0], lift_name) != null, "the Hero tab has a physical therapy card with the lift on it")
	if card.size() == 1:
		ShotHelper.reveal(card[0])
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "detail_5_hero_pt_card")
		await ShotHelper.click(tree, card[0])
		await ShotHelper.wait(tree, 0.7)
	var pts = _sheet()
	check(pts != null and ShotHelper.find_text(pts, lift_name) != null and ShotHelper.find_text(pts, "this week") != null and _count(WeekBars) == 1, "the card opens the sheet: the week, and eight weeks of bars")
	var more = _by_tip("One day more")
	var more_at = more[0].get_global_rect().position if not more.is_empty() else Vector2.ZERO
	for i in range(3):
		ShotHelper.press(_by_tip("One day more")[0])
		await ShotHelper.frames(tree, 4)
	var more2 = _by_tip("One day more")
	check(Pt.per_week(App.pt(), lift_name) == 6 and more2.size() == 1 and more2[0].get_global_rect().position.distance_to(more_at) <= 1.0, "three presses on +: 6 a week, and the key stayed under the cursor")
	await ShotHelper.snap(tree, "detail_6_pt_sheet")
	App.set_pt_goal(lift_name, 3)
	await _close_sheets()

	# --- "(PT)" in the phone note ---------------------------------------------------------
	var other = ""
	for ex in lift.exercises:
		if str(ex.name) != lift_name and not SessionView.done_sets(ex).is_empty():
			other = str(ex.name)
	var note = "%s\n(PT) neck 4 way - 3x20@10\n(PT) %s 3x10 @ 45\n%s 3x5 @ 95" % [today, other.to_lower(), lift_name.to_lower()]
	var r = App.inbox.check_text(note)
	InboxSheet.open(r)
	await ShotHelper.wait(tree, 0.7)
	said = ShotHelper.all_text(_sheet())
	check(r.fresh.size() == 1 and r.problems.is_empty() and _by_tip("Trends and history of").size() == 3, "the note's lift entry lists its three exercises")
	check(_pt_tags() == 3, "all three wear the PT badge: two by the tag, one because the lift already is (%d)" % _pt_tags())
	check(said.contains("New lift · \"(PT) neck 4 way\"") and said.contains("= %s?" % other), "the review asks about the new PT lift and about the lift tagged PT for the first time")
	await ShotHelper.snap(tree, "detail_7_review_pt")
	var pend = _by_tip("Trends and history of %s" % other)
	if not pend.is_empty():
		await ShotHelper.click(tree, pend[0])
		await ShotHelper.wait(tree, 0.7)
		check(ShotHelper.find_text(_sheet(), "In your note") != null and ShotHelper.find_text(_sheet(), "Last time") != null, "an exercise of the note opens its page with the note's sets on top, against the last time")
		await ShotHelper.snap(tree, "detail_8_lift_from_note")
		_sheet().close()
		await ShotHelper.wait(tree, 0.5)
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Import"))
	await ShotHelper.frames(tree, 4)
	await _dismiss_reels()
	var added = _newest_lift()
	var clean = true
	for ex in added.exercises:
		if ex.has("pt") or str(ex.name).to_lower().contains("(pt)"):
			clean = false
	check(clean and Pt.is_pt(App.pt(), "Neck 4 Way") and Pt.is_pt(App.pt(), other) and App.pt().size() == 3, "imported: the names carry no tag, and both lifts are PT lifts now (%s)" % str(App.pt().keys()))

	# --- "(PT)" typed in the Log tab ---------------------------------------------------------
	var by_hand = App.build_session({"discipline": "lift", "date": today, "exercises": [{"name": "(PT) Wall Slide", "sets": [{"reps": 15, "weightKg": 0}, {"reps": 15, "weightKg": 0}]}]})
	App.commit_sessions([by_hand], "Session logged!")
	await _dismiss_reels()
	var saved_name = str(App.session_by_id(by_hand.id).exercises[0].name)
	check(saved_name == "Wall Slide" and Pt.is_pt(App.pt(), "wall slide"), "typed by hand with (PT): saved as '%s', and a PT lift" % saved_name)
	var status = Pt.status(App.sessions(), App.pt(), today)
	var wall = null
	for row in status:
		if row.name == "Wall Slide":
			wall = row
	check(status.size() == 4 and wall != null and wall.thisWeek == 1 and wall.daysSince == 0, "four PT lifts, and today's counts for its week")

	# --- the library marks them, and the mark comes off again --------------------------------
	App.go("journey", "lifts")
	await ShotHelper.wait(tree, 0.8)
	check(_pt_tags(main) >= 1, "the lift library shows the PT badge")
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var card2 = _by_tip("Physical therapy: are you keeping up?", main)
	if card2.size() == 1:
		ShotHelper.reveal(card2[0])
		await ShotHelper.frames(tree, 4)
	await ShotHelper.snap(tree, "detail_9_hero_four_pt")
	App.set_pt(other, false)
	await ShotHelper.frames(tree, 4)
	check(not Pt.is_pt(App.pt(), other) and App.pt().size() == 3, "switched off again: no longer a PT lift, its sessions untouched")
	# --- a table in the note, and a stretch held for seconds -------------------------------
	var yesterday = Dates.add_days(today, -1)
	var table = "| Date | Exercise | Variation | Weight | Reps |
| %s | (PT) Calf stretch | wall | 30\" | 3 |
| | Goblet squat | kettlebell | 35 | 12, 12, 10 |
| | | | | |" % yesterday
	var rt = App.inbox.check_text(table)
	InboxSheet.open(rt)
	await ShotHelper.wait(tree, 0.7)
	said = ShotHelper.all_text(_sheet())
	check(rt.problems.is_empty() and rt.fresh.size() == 1 and str(rt.fresh[0].date) == yesterday and _by_tip("Trends and history of").size() == 2, "a table in the note reads as one lift entry with a row per exercise (%s)" % str(rt.problems))
	check(said.contains("3 × 30 s hold") and said.contains("12, 12, 10 @ 35 lb"), "30\" in the weight column is a hold of 30 seconds, not a weight")
	await ShotHelper.snap(tree, "detail_10_table_and_hold")
	ShotHelper.press(ShotHelper.find_button(_sheet(), "Import"))
	await ShotHelper.frames(tree, 4)
	await _dismiss_reels()
	var stretch = null
	for s in App.sessions():
		if s.discipline == "lift" and s.date == yesterday:
			for ex in s.exercises:
				if str(ex.name).to_lower().contains("calf stretch"):
					stretch = ex
	check(stretch != null and stretch.sets.size() == 1 and int(stretch.sets[0].reps) == 3 and int(stretch.sets[0].get("holdSec", 0)) == 30 and float(stretch.sets[0].weightKg) == 0.0 and Pt.is_pt(App.pt(), str(stretch.name)), "imported: three holds of 30 seconds, no weight, and a PT lift")
	if stretch != null:
		JourneyLifts.open_named(str(stretch.name))
		await ShotHelper.wait(tree, 0.7)
		check(ShotHelper.find_button(_sheet(), "Hold") != null and ShotHelper.find_button(_sheet(), "Weight") == null and ShotHelper.find_text(_sheet(), "s longest hold") != null and ShotHelper.find_text(_sheet(), "3 × 30 s hold") != null, "its page counts seconds: the longest hold, a Hold trend, no Weight")
		await ShotHelper.snap(tree, "detail_11_hold_page")
		await _close_sheets()
		var draft = LogLiftEditor.draft_from_sets("x", stretch.sets, "lb")
		var round_trip = LogLiftEditor.sets_from_draft(draft, "lb")
		check(round_trip.size() == 1 and int(round_trip[0].get("holdSec", 0)) == 30 and int(round_trip[0].reps) == 3, "editing the session in the Log tab keeps the seconds")
	var text = FileAccess.get_file_as_string(App.SAVE_PATH)
	var back = App.parse_saved(JSON.parse_string(text))
	check(back != null and back.pt.size() == 4 and int(back.pt[Pt.key(lift_name)].perWeek) == 3, "the PT lifts are in the save file and read back")
	print("DETAIL DONE, failures: %d" % fails)
