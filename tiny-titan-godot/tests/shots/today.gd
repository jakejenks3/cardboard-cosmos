extends RefCounted
## The day's plan and the missions (run with the "year" data): the Hero tab's
## Today card (likely lifts with what to aim for, the day's body area,
## something new, PT), the missions made from the log (no minutes), a lift
## mission opening its page, beating a lift and claiming it, yesterday's
## missions, and the Morning goals card in Settings (nothing is sent).
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


func _home() -> void:
	App.go("home")
	await ShotHelper.wait(tree, 0.8)


func run(m: Node, t: SceneTree) -> void:
	main = m
	tree = t
	App.update_settings({"weightUnit": "lb"})
	# A lift done on this weekday the last two weeks, so today has a likely lift
	# whatever day the walkthrough runs on (the demo player lifts Mondays and Fridays).
	var habit = []
	for wk in [14, 7]:
		habit.append({"id": "habit%d" % wk, "discipline": "lift", "date": Dates.add_days(App.today, -wk), "createdAt": App.now_ms() - wk * 86400000, "source": "manual",
			"exercises": [{"name": "Bench Press - Barbell", "sets": [{"reps": 5, "weightKg": 60.0}, {"reps": 5, "weightKg": 60.0}]}]})
	habit.append({"id": "habit10", "discipline": "lift", "date": Dates.add_days(App.today, -10), "createdAt": App.now_ms() - 10 * 86400000, "source": "manual",
		"exercises": [{"name": "Bench Press - Dumbbell", "sets": [{"reps": 10, "weightKg": 22.0}, {"reps": 10, "weightKg": 22.0}]}]})
	App.commit_sessions(habit, "Workout logged!")
	await _dismiss_reels()
	# A physical therapy lift done twice this week, so the plan has PT in it.
	var monday = Dates.week_key(App.today)
	if monday != App.today:
		App.set_pt("Neck 4 Way", true)
		App.commit_sessions([{"id": "pt1", "discipline": "lift", "date": monday, "createdAt": App.now_ms() - 7200000, "source": "manual",
			"exercises": [{"name": "Neck 4 Way", "sets": [{"reps": 20, "weightKg": 4.5}]}]}], "Workout logged!")
		await _dismiss_reels()
	await _home()
	var plan = App.plan()
	print("PLAN ", plan.label, " | ", plan.lifts.map(func(l): return "%s (%s)" % [l.name, l.why]), " | new ", plan.new.name if plan.new != null else "-")
	var said = ShotHelper.all_text(main)
	check(said.contains("TODAY") or ShotHelper.find_text(main, "PROBABLY TODAY") != null, "the Hero tab starts with Today")
	check(not plan.lifts.is_empty() and ShotHelper.find_text(main, "PROBABLY TODAY") != null and said.contains("AIM"), "the likely lifts, each with what to aim for (%d)" % plan.lifts.size())
	var q = App.quests()
	var beats = q.daily.filter(func(x): return str(x.id).contains(":beat:"))
	check(not beats.is_empty() and q.daily.all(func(x): return str(x.unit) != "min") and q.weekly.all(func(x): return str(x.unit) != "min"), "missions to beat a lift, and none about minutes (%s)" % str(q.daily.map(func(x): return x.title)))
	check(said.contains("Beat it: "), "the missions are on the Hero tab")
	await ShotHelper.snap(tree, "today_1_hero")

	# The bench was done two ways (barbell, and dumbbells ten days ago): one row,
	# the other way as a chip that opens it.
	await _home()
	var bp = App.plan().lifts.filter(func(l): return str(LiftNames.split(str(l.name)).move) == "Bench Press")
	check(bp.size() == 1 and bp[0].options.map(func(o): return str(o.name)).has("Bench Press - Dumbbell"), "one bench row, its dumbbell way among the options (%s)" % str(bp[0].options.map(func(o): return o.name) if not bp.is_empty() else []))
	var db_chip = ShotHelper.find_button(main, "Dumbbell")
	check(db_chip != null and ShotHelper.find_text(main, "OR") != null, "the other way is a chip under the row")
	check(ShotHelper.find_button(main, "Home") == null and ShotHelper.find_button(main, "Gym") == null, "no Gym / Home keys")
	if db_chip != null:
		ShotHelper.reveal(db_chip)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "today_7_ways")
		await ShotHelper.click(tree, db_chip)
		await ShotHelper.wait(tree, 0.7)
		check(_sheet() != null and ShotHelper.all_text(_sheet()).contains("Dumbbell"), "the chip opens that way's page")
		await _close_sheets()


	# A likely lift opens its page on Compare.
	var row = null
	for n in ShotHelper.walk(main):
		if n is Card and n.tooltip_text == "Last time, and what to beat":
			row = n
			break
	check(row != null, "a likely lift is a row you can tap")
	if row != null:
		ShotHelper.reveal(row)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, row)
		await ShotHelper.wait(tree, 0.7)
		check(_sheet() != null and ShotHelper.all_text(_sheet()).contains("THIS TIME"), "it opens the lift on Compare")
		await _close_sheets()

	# The Adventure tab lists them with what to aim for.
	App.go("adventure", "quests")
	await ShotHelper.wait(tree, 0.8)
	check(ShotHelper.all_text(main).contains("Aim for") and ShotHelper.all_text(main).contains("Set a record"), "Adventure: the missions say what to aim for; the week has a record to set")
	await ShotHelper.snap(tree, "today_2_adventure")

	# Beat the likeliest lift today: the mission is done and can be claimed.
	var target = beats[0]
	var aim = target.aim
	App.commit_sessions([{"id": "today1", "discipline": "lift", "date": App.today, "createdAt": App.now_ms(), "source": "manual",
		"exercises": [{"name": str(target.lift), "sets": aim}]}], "Workout logged!")
	await _dismiss_reels()
	var after = App.quests().daily.filter(func(x): return x.id == target.id)
	check(after.size() == 1 and after[0].done, "doing what it aimed for beats it (%s)" % str(target.lift))
	await _home()
	var claim = null
	for n in ShotHelper.walk(main):
		if n is Button and str(n.text).begins_with("Claim"):
			claim = n
	check(claim != null, "a Claim key")
	var claims_before = App.saved.claims.size()
	if claim != null:
		ShotHelper.reveal(claim)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.snap(tree, "today_3_claim")
		ShotHelper.press(claim)
		await ShotHelper.wait(tree, 0.6)
	check(App.saved.claims.size() == claims_before + 1, "claimed")

	# Yesterday's missions done but not claimed are still there today.
	var yday = Dates.add_days(App.today, -1)
	App.commit_sessions([{"id": "yday1", "discipline": "run", "date": yday, "createdAt": App.now_ms() + 10, "source": "manual", "distanceM": 5000.0, "durationSec": 1800}], "Workout logged!")
	await _dismiss_reels()
	await _home()
	var y = App.quests().yesterday
	var claims_shown = 0
	for n in ShotHelper.walk(main):
		if n is Button and str(n.text).begins_with("Claim"):
			claims_shown += 1
	check(not y.is_empty() and claims_shown >= y.size(), "yesterday's finished missions wait to be claimed (%d, %d Claim keys)" % [y.size(), claims_shown])
	await ShotHelper.snap(tree, "today_4_yesterday")

	# Settings: pick a training split; the Today card then names the split's day.
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.6)
	var sc = null
	for n in ShotHelper.walk(_sheet()):
		if n.has_meta("split_section"):
			sc = n
	var ppl = ShotHelper.find_button(_sheet(), "Pull, push, legs")
	check(sc != null and ppl != null and str(App.settings().get("split", "auto")) == "auto", "Settings has Training split, from the log to start with")
	if ppl != null:
		ShotHelper.reveal(ppl)
		await ShotHelper.frames(tree, 3)
		await ShotHelper.click(tree, ppl)
		await ShotHelper.wait(tree, 0.6)
	check(str(App.settings().get("split", "")) == "pull_push_legs" and ShotHelper.all_text(_sheet()).contains("Pull day > Push day > Leg day > again"), "picked: pull, push, legs")
	# (the card was rebuilt by the pick: `sc` is gone, find it again)
	if _sheet() != null:
		for n in ShotHelper.walk(_sheet()):
			if n.has_meta("split_section"):
				ShotHelper.reveal(n)
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "today_5_split_settings")
	await _close_sheets()
	await _home()
	var sp = App.plan()
	print("SPLIT PLAN ", sp.label, " (", Missions.kind_why(sp), ") | ", sp.lifts.map(func(l): return "%s (%s)" % [l.name, l.why]))
	check(sp.kind in ["pull", "push", "legs"] and sp.label == Missions.KIND_NAMES[sp.kind] and ShotHelper.all_text(main).contains(Missions.kind_why(sp)), "the Today card: %s, %s" % [sp.label, Missions.kind_why(sp)])
	check(sp.lifts.all(func(l): return bool(l.pt) or str(l.kind) == "" or str(l.kind) == sp.kind), "only that day's lifts (and any-day ones)")
	var other = "legs" if sp.kind != "legs" else "pull"
	var chip = ShotHelper.find_button(main, str(Missions.KIND_SHORT[other]))
	check(chip != null, "a chip per day of the split")
	if chip != null:
		ShotHelper.reveal(chip)
		await ShotHelper.frames(tree, 3)
		var y0 = chip.get_global_rect().position.y
		await ShotHelper.click(tree, chip)
		await ShotHelper.wait(tree, 0.8)
		var pk = App.plan()
		check(pk.kind == other and pk.picked and ShotHelper.all_text(main).contains("Your pick for today"), "tapping %s plans today as a %s" % [Missions.KIND_SHORT[other], pk.label])
		var chip2 = ShotHelper.find_button(main, str(Missions.KIND_SHORT[other]))
		check(chip2 != null and absf(chip2.get_global_rect().position.y - y0) < 1.0, "the chip stays under the cursor")
		await ShotHelper.snap(tree, "today_6_split_pick")
		var back = ShotHelper.find_button(main, str(Missions.KIND_SHORT[sp.kind]))
		if back != null:
			await ShotHelper.click(tree, back)
			await ShotHelper.wait(tree, 0.8)
		check(App.plan().kind == sp.kind and not App.plan().picked and (App.settings().get("dayPick", {}) as Dictionary).is_empty(), "tapping the split's own day drops the pick")

	# Settings: the morning goals card (nothing is sent here).
	SettingsSheet.open()
	await ShotHelper.wait(tree, 0.6)
	var mc = null
	for n in ShotHelper.walk(_sheet()):
		if n.has_meta("morning_section"):
			mc = n
	check(mc != null and ShotHelper.find_button(_sheet(), "Send a test") != null and not MorningAlert.settings(App.settings()).on, "Settings has Morning goals, off")
	if mc != null:
		ShotHelper.reveal(mc)
		await ShotHelper.frames(tree, 4)
		await ShotHelper.snap(tree, "today_5_settings")
	var msg = MorningAlert.message(App.saved, App.today)
	print("MESSAGE ", msg.title, "\n", msg.text)
	check(str(msg.title).begins_with("Tiny Titan - ") and str(msg.text).length() > 10 and str(msg.title).to_ascii_buffer().size() == str(msg.title).length(), "the morning message: a plain title and the plan")
	await _close_sheets()
	print("TODAY DONE, failures: %d" % fails)
