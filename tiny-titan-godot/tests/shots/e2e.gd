extends RefCounted
## End-to-end walkthrough of a first day, driven through the real controls:
## onboarding → log a lifting session → results reel → every tab → settings →
## body check-in. Run with the "fresh" data. Prints CHECK lines; any FAIL is a bug.

var main: Node
var tree: SceneTree
var fails = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if ok else "FAIL", what])


func card_with(text: String):
	var l = ShotHelper.find_text(main, text)
	var n = l
	while n != null and not (n is Card):
		n = n.get_parent()
	return n


func tap_card(text: String) -> void:
	var c = card_with(text)
	check(c != null, "found card '%s'" % text)
	if c == null:
		return
	ShotHelper.reveal(c)
	await ShotHelper.frames(tree, 3)
	await ShotHelper.click(tree, c)
	await ShotHelper.frames(tree, 5)


func press(text: String) -> void:
	var b = ShotHelper.find_button(main, text)
	check(b != null and not b.disabled, "button '%s' is there and enabled" % text)
	if b != null:
		ShotHelper.reveal(b)
		await ShotHelper.frames(tree, 2)
		ShotHelper.press(b)
	await ShotHelper.frames(tree, 5)


func type_keys(text: String) -> void:
	for i in range(text.length()):
		var ch = text.unicode_at(i)
		for down in [true, false]:
			var ev = InputEventKey.new()
			ev.pressed = down
			if ch == 9:
				ev.keycode = KEY_TAB
				ev.physical_keycode = KEY_TAB
			else:
				ev.unicode = ch if down else 0
				ev.keycode = ch
			tree.root.push_input(ev)
			await tree.process_frame


func finish_reel(shot: String) -> void:
	await ShotHelper.wait(tree, 1.2)
	await ShotHelper.snap(tree, shot + "_start")
	# Let it play, then close it with the Continue button.
	for i in range(60):
		await ShotHelper.wait(tree, 0.5)
		var b = ShotHelper.find_button(main, "Continue")
		if b != null and not b.disabled:
			break
	await ShotHelper.wait(tree, 0.6)
	await ShotHelper.snap(tree, shot + "_end")
	await press("Continue")
	await ShotHelper.wait(tree, 0.4)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	check(not App.has_profile(), "starts with no profile")

	# --- onboarding -----------------------------------------------------------
	for n in ShotHelper.walk(main):
		if n is LineEdit:
			ShotHelper.type_into(n, "Jake")
	await press("Next")
	await press("Next")
	await press("Start my journey")
	check(App.has_profile() and App.profile().name == "Jake", "profile created")
	await ShotHelper.wait(tree, 0.3)

	# --- log a first lifting session through the form -------------------------
	await press("Log a workout")
	check(App.tab == "log" and App.log_discipline == null, "log picker open")
	await ShotHelper.snap(tree, "e2e_picker")
	await tap_card("Lifting")
	check(App.log_discipline == "lift", "lifting form open")
	await tap_card("Bench Press")
	await type_keys("8\t40")
	await ShotHelper.frames(tree, 3)
	await press("+ Set")
	await ShotHelper.snap(tree, "e2e_lift_form")
	var xp_before = App.state.xp.hero
	await press("Finish session")
	check(App.sessions().size() == 1, "one session saved")
	if App.sessions().size() == 1:
		var s = App.sessions()[0]
		print("saved: ", JSON.stringify(s.exercises), " date ", s.date)
		check(s.discipline == "lift" and s.exercises.size() == 1 and s.exercises[0].sets.size() >= 1, "it is the bench session")
		check(int(s.exercises[0].sets[0].reps) == 8 and is_equal_approx(float(s.exercises[0].sets[0].weightKg), 40.0), "first set is 8 x 40 kg")
	check(App.state.xp.hero > xp_before, "hero XP went up (%s -> %s)" % [xp_before, App.state.xp.hero])
	await finish_reel("e2e_reel")
	check(App.tab == "home", "back on the Hero tab after the reel")
	await ShotHelper.snap(tree, "e2e_home_after")

	# --- every tab renders ------------------------------------------------------
	for dest in [["adventure", "campaign"], ["adventure", "quests"], ["adventure", "trophies"], ["journey", "stats"], ["journey", "body"], ["journey", "chronicle"], ["journey", "history"], ["armory", null]]:
		App.go(dest[0], dest[1])
		await ShotHelper.frames(tree, 6)
		await ShotHelper.snap(tree, "e2e_%s_%s" % [dest[0], dest[1]])
	App.go("home")
	await ShotHelper.frames(tree, 5)

	# --- settings sheet -----------------------------------------------------------
	var cog = null
	for n in ShotHelper.walk(main):
		if n is Button and n.tooltip_text == "Settings":
			cog = n
	check(cog != null, "settings cog found")
	ShotHelper.press(cog)
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "e2e_settings")
	check(ShotHelper.find_text(main, "Weekly goal") != null, "settings sheet is open")
	for n in ShotHelper.walk(main):
		if n is Button and n.tooltip_text == "Close":
			ShotHelper.press(n)
	await ShotHelper.wait(tree, 0.5)
	check(ShotHelper.find_text(main, "Weekly goal") == null, "settings sheet closed")

	# --- body check-in through the form ---------------------------------------
	App.open_log(null)
	await ShotHelper.frames(tree, 5)
	await tap_card("Body check-in")
	check(App.log_discipline == "body", "body form open")
	await type_keys("82,4")
	await ShotHelper.frames(tree, 3)
	await ShotHelper.snap(tree, "e2e_body_form")
	await press("Check in")
	check(App.body().size() == 1, "one check-in saved")
	if App.body().size() == 1:
		print("saved body: ", JSON.stringify(App.body()[0]))
		check(is_equal_approx(float(App.body()[0].get("weightKg", 0)), 82.4), "weight is 82.4 kg")
	await finish_reel("e2e_body_reel")

	# --- the save file on disk matches --------------------------------------------
	var on_disk = App.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH)))
	check(on_disk != null and on_disk.sessions.size() == 1 and on_disk.body.size() == 1 and on_disk.profile.name == "Jake", "save.json holds the profile, the session and the check-in")
	print("E2E DONE, failures: %d" % fails)
