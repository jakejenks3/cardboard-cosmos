extends RefCounted
## Misc activities walkthrough (run with the "year" data): the Miscellaneous
## section of the Log picker, logging a weighted vest walk through the form, the
## results reel, the Hero tab's week card, Journey (history, stats, story), the
## recap, editing, "same as last", a record, the phone note, deleting. Every tab
## is opened with vest walks in the log, so a screen that still expects only the
## four disciplines shows up as a script error. Prints CHECK lines.

const LB = 0.45359237
const MI = 1609.344

var main: Node
var tree: SceneTree
var fails = 0
var reels = []


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func screen() -> LogScreen:
	for n in ShotHelper.walk(main):
		if n is LogScreen:
			return n
	return null


func field(key: String):
	var s = screen()
	return s._find_fkey(s, key) if s != null else null


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


func shot(shot_name: String) -> void:
	await ShotHelper.wait(tree, 0.7)
	await ShotHelper.snap(tree, shot_name)


func _dismiss_reels() -> void:
	for i in range(16):
		var b = ShotHelper.find_button(main, "Tap to skip")
		if b == null:
			b = ShotHelper.find_button(main, "Continue")
		if b == null:
			break
		ShotHelper.press(b)
		await ShotHelper.wait(tree, 0.6)


func _walks() -> Array:
	var out = App.sessions().filter(func(s): return s.discipline == "misc")
	TTUtil.stable_sort(out, func(a, b): return a.createdAt < b.createdAt)
	return out


func _near(a, b, eps: float) -> bool:
	return a != null and absf(float(a) - float(b)) <= eps


func _reel_has(kind: String, text: String = "") -> bool:
	if reels.is_empty():
		return false
	for e in reels[reels.size() - 1].events:
		if e.type == kind and (text == "" or str(e.get("title", "")).contains(text)):
			return true
	return false


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb", "distanceUnit": "mi"})
	App.result_ready.connect(func(r): reels.append(r))
	var s0 = App.state
	var hero0 = int(s0.xp.hero)
	var run0 = float(s0.totals.runDistanceM)
	var ride0 = float(s0.totals.rideDistanceM)
	var by0 = s0.totals.byDiscipline.duplicate()
	var prs0 = s0.prs.duplicate(true)
	var n0 = int(s0.totals.sessions)
	check(not s0.has("misc"), "before: no misc in the state")

	# --- the picker ----------------------------------------------------------------------
	App.open_log(null)
	await ShotHelper.wait(tree, 0.6)
	var section = null
	for n in ShotHelper.walk(main):
		if n is Control and n.has_meta("misc_section"):
			section = n
	check(section != null, "the Log picker has a Miscellaneous section")
	var key = ShotHelper.find_button(main, "Weighted vest walk")
	check(key != null, "with the weighted vest walk in it")
	if key != null:
		ShotHelper.reveal(key)
	await shot("misc_picker")
	if key == null:
		print("MISC DONE, failures: %d" % fails)
		return

	# --- the form ----------------------------------------------------------------------------
	ShotHelper.press(key)
	await ShotHelper.wait(tree, 0.6)
	check(App.log_discipline == "misc:vest_walk" and screen() != null and screen().form() != null and screen().form().kind == "vest_walk", "the vest walk form opens")
	check(ShotHelper.find_text(main, "Log vest walk") != null, "it is titled 'Log vest walk'")
	check(field("distance") != null and field("load") != null and field("elev") != null, "it asks for distance, elevation and the vest weight")
	var save = ShotHelper.find_button(main, "Finish session")
	check(save != null and save.disabled, "nothing to save before a distance is typed")
	await shot("misc_form_empty")
	ShotHelper.type_into(field("distance"), "2.1")
	ShotHelper.type_into(field("dur.m"), "40")
	ShotHelper.type_into(field("elev"), "120")
	await ShotHelper.frames(tree, 2)
	# The vest: a quick pick, pressed three times, must not move the screen.
	var pick = null
	for n in ShotHelper.walk(main):
		if n is Button and n.text == "20" and n.tooltip_text.contains("vest"):
			pick = n
	check(pick != null, "quick picks for the vest weight")
	if pick != null:
		var y0 = pick.get_global_rect().position.y
		await ShotHelper.click(tree, pick)
		await ShotHelper.frames(tree, 4)
		var again = null
		for n in ShotHelper.walk(main):
			if n is Button and n.text == "20" and n.tooltip_text.contains("vest"):
				again = n
		check(again != null and absf(again.get_global_rect().position.y - y0) < 1.0, "picking a vest weight does not move the screen")
	check(field("load") != null and field("load").text == "20", "the pick fills the vest weight (%s)" % (field("load").text if field("load") != null else "?"))
	var form = screen().form()
	var d = form.draft()
	check(_near(d.distanceM, 2.1 * MI, 0.01) and int(d.durationSec) == 2400 and _near(d.loadKg, 20.0 * LB, 0.001) and _near(d.elevationM, 120.0 / 3.28084, 0.01) and d.kind == "vest_walk", "the draft holds 2.1 mi, 40 min, 20 lb, 120 ft")
	var want = int(Xp.base_session_xp(d).xp)
	check(want == 365 and ShotHelper.find_text(main, "2.1 mi · 20 lb vest") != null, "the XP preview is for 2.1 mi with a 20 lb vest (%d XP)" % want)
	check(ShotHelper.find_text(main, "19:03 /mi") != null and ShotHelper.find_text(main, "×1.23 XP") != null, "live pace and what the vest adds are shown")
	await shot("misc_form_filled")
	save = ShotHelper.find_button(main, "Finish session")
	check(save != null and not save.disabled, "it can be saved")
	ShotHelper.press(save)
	await ShotHelper.wait(tree, 1.0)
	await ShotHelper.snap(tree, "misc_reel")
	check(reels.size() == 1 and reels[0].events[0].type == "xp" and reels[0].events[0].discipline == "misc" and reels[0].events[0].disc == null, "the reel shows hero XP for a misc session")
	await ShotHelper.wait(tree, 3.5)
	await ShotHelper.snap(tree, "misc_reel_2")
	await _dismiss_reels()

	# --- what it changed ---------------------------------------------------------------------------
	var walks = _walks()
	check(walks.size() == 1, "one vest walk in the log")
	var w = walks[0] if walks.size() == 1 else {}
	var s1 = App.state
	var xp1 = int(s1.sessionXp.get(w.get("id", ""), 0))
	check(xp1 == want and int(s1.xp.hero) >= hero0 + xp1, "it earned its %d XP for the hero" % want)
	check(_near(s1.totals.runDistanceM, run0, 0.001) and _near(s1.totals.rideDistanceM, ride0, 0.001) and s1.totals.byDiscipline == by0 and s1.prs == prs0, "run, ride, lift and climb numbers are untouched")
	check(int(s1.totals.sessions) == n0 + 1 and Misc.sessions(s1) == 1, "it counts as a session")
	check(str(w.get("source", "")) == "manual" and float(w.get("bonusPct", 1.0)) == 0.0, "saved like any session, with no gear bonus")

	# --- every tab with a vest walk in the log ---------------------------------------------------------
	App.go("home")
	await ShotHelper.wait(tree, 0.8)
	var chip = null
	for n in ShotHelper.walk(main):
		if n is Control and n.tooltip_text == "1 misc session":
			chip = n
	check(chip != null, "the Hero tab's week card counts it")
	check(ShotHelper.find_text(main, "Weighted vest walk") != null, "and it is in Recent")
	await shot("misc_home")
	App.go("journey", "history")
	await ShotHelper.wait(tree, 0.8)
	check(ShotHelper.find_text(main, "2.1 mi · 40:00 · 19:03 /mi · 20 lb vest · 120 ft ↑") != null, "Journey, Log: its line reads 2.1 mi, 40:00, the pace, the vest, the climb")
	await shot("misc_history")
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.8)
	var card = null
	for n in ShotHelper.walk(main):
		if n is Control and n.has_meta("misc_card"):
			card = n
	check(card != null, "Journey, Stats has a vest walk card")
	if card != null:
		ShotHelper.reveal(card)
		check(ShotHelper.find_text(card, "20 lb") != null, "with the heaviest vest")
	await shot("misc_stats")
	ShotHelper.scroll_main(main, 0)
	await shot("misc_stats_chart")
	App.go("journey", "chronicle")
	await ShotHelper.wait(tree, 0.6)
	App.go("journey", "body")
	await ShotHelper.wait(tree, 0.4)
	App.go("journey", "lifts")
	await ShotHelper.wait(tree, 0.4)
	App.go("adventure")
	await ShotHelper.wait(tree, 0.6)
	App.set_adventure_tab("quests")
	await ShotHelper.wait(tree, 0.4)
	App.set_adventure_tab("trophies")
	await ShotHelper.wait(tree, 0.4)
	App.go("armory")
	await ShotHelper.wait(tree, 0.6)
	RecapSheet.open("week", Dates.week_key(App.today))
	await ShotHelper.wait(tree, 0.8)
	check(_sheet() != null and ShotHelper.find_text(_sheet(), "WALKED") != null, "the week's recap shows the distance walked")
	await ShotHelper.snap(tree, "misc_recap")
	await _close_sheets()
	RecapSheet.open("month", App.today.substr(0, 7))
	await ShotHelper.wait(tree, 0.6)
	await _close_sheets()
	BountyView.open()
	await ShotHelper.wait(tree, 0.6)
	await _close_sheets()

	# --- editing ------------------------------------------------------------------------------------
	App.open_log("misc", w.get("id"))
	await ShotHelper.wait(tree, 0.6)
	check(ShotHelper.find_text(main, "Edit vest walk") != null and field("distance") != null and field("distance").text == "2.1" and field("load").text == "20" and field("elev").text == "120", "editing shows what was saved")
	await shot("misc_edit")
	ShotHelper.type_into(field("load"), "30")
	ShotHelper.press(ShotHelper.find_button(main, "Save changes"))
	await ShotHelper.wait(tree, 0.8)
	walks = _walks()
	check(walks.size() == 1 and _near(walks[0].loadKg, 30.0 * LB, 0.001) and int(App.state.sessionXp[walks[0].id]) > xp1, "a heavier vest after editing is worth more XP")

	# --- same as last, and a record ----------------------------------------------------------------------
	App.open_log("misc:vest_walk")
	await ShotHelper.wait(tree, 0.6)
	var tmpl = ShotHelper.find_text(main, "2.1 mi · 40:00 · 30 lb vest")
	check(tmpl != null, "a new vest walk offers 'same as last'")
	await shot("misc_form_same")
	if tmpl != null:
		var p = tmpl
		while p != null and not (p is Card):
			p = p.get_parent()
		await ShotHelper.click(tree, p)
		await ShotHelper.frames(tree, 4)
	check(field("distance") != null and field("distance").text == "2.1" and field("load").text == "30", "one tap fills distance, time and vest")
	ShotHelper.type_into(field("distance"), "3")
	ShotHelper.press(ShotHelper.find_button(main, "Finish session"))
	await ShotHelper.wait(tree, 1.0)
	check(reels.size() == 2 and _reel_has("pr", "Longest vest walk"), "a longer walk than ever is a record in the reel")
	await ShotHelper.wait(tree, 4.5)
	await ShotHelper.snap(tree, "misc_reel_record")
	await _dismiss_reels()
	walks = _walks()
	check(walks.size() == 2 and int(App.state.sessionXp[walks[1].id]) == int(Xp.base_session_xp(walks[1]).xp) + 75, "and pays the record bonus")
	App.go("journey", "chronicle")
	await ShotHelper.wait(tree, 0.8)
	check(ShotHelper.find_text(main, "Longest vest walk") != null, "the record is in the Story")
	await shot("misc_story")

	# --- the phone note ----------------------------------------------------------------------------------
	var r = App.inbox.check_text("vest walk 1.5 mi 30:00\nvest walk 2 mi 41:00 25 lb")
	check(r.ok and r.fresh.size() == 2 and r.problems.is_empty() and _near(r.fresh[0].data.get("loadKg"), 30.0 * LB, 0.001) and r.fresh[0].warnings.size() == 1 and _near(r.fresh[1].data.get("loadKg"), 25.0 * LB, 0.001), "phone note: a vest walk without a weight takes the last vest; with one, its own")
	InboxSheet.open(r)
	await ShotHelper.wait(tree, 0.6)
	await ShotHelper.snap(tree, "misc_inbox")
	var imp = ShotHelper.find_button(_sheet(), "Import 2 entries")
	check(imp != null, "both can be imported")
	ShotHelper.press(imp)
	await ShotHelper.wait(tree, 1.0)
	check(reels.size() == 3 and reels[2].events[0].type == "import" and int(reels[2].events[0].byDiscipline.get("misc", 0)) > 0, "the import reel adds them up under misc")
	await ShotHelper.snap(tree, "misc_import_reel")
	await _dismiss_reels()
	check(_walks().size() == 4, "four vest walks in the log")

	# --- deleting ------------------------------------------------------------------------------------------
	for x in _walks():
		App.delete_session(x.id)
	await ShotHelper.wait(tree, 0.5)
	var s9 = App.state
	check(not s9.has("misc") and int(s9.totals.sessions) == n0 and int(s9.xp.hero) == hero0 and s9.prs == prs0, "deleting them all puts everything back as it was")
	App.go("journey", "stats")
	await ShotHelper.wait(tree, 0.6)
	App.go("home")
	await ShotHelper.wait(tree, 0.6)
	print("MISC DONE, failures: %d" % fails)
