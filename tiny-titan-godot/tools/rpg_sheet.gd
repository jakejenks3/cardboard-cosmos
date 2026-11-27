extends SceneTree
## Prints the Realm's stat sheet, boosts and training chests of a save file:
## what the curves of game/rpg/rpg_stats.gd make of a real log, to calibrate
## them (RPG_PLAN.md 2, 3 and 14 step 3). The save is read from a path OUTSIDE
## the project and NOTHING is written, not here and not there.
##
##   RPG_SHEET_SAVE=<a save.json or an exported backup .json>
##   RPG_SHEET_TODAY=<YYYY-MM-DD>      (optional: the day to look from, else today)
##   TINY_TITAN_DATA=<a throwaway folder>
##   godot --headless --path <project> --script res://tools/rpg_sheet.gd
##
## TINY_TITAN_DATA must be set: every --script run starts the App autoload,
## which opens (and copies into its backups) the save of ITS data folder
## whatever this tool does. With a throwaway folder that is an empty save;
## without it it would be the player's real one, so the tool says so and
## stops. It never calls anything of App but parse_saved (which only reads
## what it is given).
##
## The file is parsed with App.parse_saved and the state is derived exactly as
## App._recompute does it; the sheet's input is what RpgUi hands the Realm.
## Printed: every stat (v, raw, was, its lines, next), the facts behind the
## body stats and the traits, the boosts in force, the chests of today and
## yesterday. Exit code 0, or 2 when it was not given what it needs.

func _initialize() -> void:
	_run()


func _fail(why: String) -> void:
	print("RPG SHEET: %s" % why)
	quit(2)


func _run() -> void:
	var path = OS.get_environment("RPG_SHEET_SAVE")
	if path == "":
		_fail("set RPG_SHEET_SAVE to a save or backup file (and RPG_SHEET_TODAY to a day, if not today)")
		return
	if OS.get_environment("TINY_TITAN_DATA") == "":
		_fail("set TINY_TITAN_DATA to a throwaway folder: the game's own save must not be opened by a tool run")
		return
	# (the App autoload is in the tree a frame after the start)
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		_fail("no App autoload")
		return
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail("cannot read %s" % path)
		return
	var raw = JSON.parse_string(f.get_as_text())
	f.close()
	var saved = app.parse_saved(raw)
	if saved == null:
		_fail("%s is not a save (no list of sessions)" % path)
		return
	var today = OS.get_environment("RPG_SHEET_TODAY")
	if today == "":
		today = Dates.today_key()
	var reading = saved.get("reading") if saved.get("reading") is Array else []
	var state = Derive.derive({
		"sessions": saved.sessions,
		"claims": saved.claims,
		"body": saved.body,
		"purchases": saved.get("purchases", []),
		"reading": reading,
		"weeklyGoal": saved.settings.weeklyGoal,
		"today": today,
	})
	var input = {"sessions": saved.sessions, "state": state, "reading": reading, "books": saved.get("books", []), "body": saved.body,
		"claims": saved.claims, "settings": saved.settings, "marks": saved.get("pt", {}), "today": today}
	var t0 = Time.get_ticks_usec()
	var sheet = RpgStats.sheet(input)
	var ms = float(Time.get_ticks_usec() - t0) / 1000.0
	print("RPG SHEET  %s" % path.get_file())
	print("today %s · %d sessions on %d days · units %s, %s · weekly goal %d · worked out in %.1f ms" % [today, int(sheet.sessions), int(sheet.days),
		str(saved.settings.get("weightUnit", "kg")), str(saved.settings.get("distanceUnit", "km")), int(sheet.facts.goal), ms])
	print("might %.2f (the mean of the six body stats)" % float(sheet.might))
	print("")
	print("%-10s %3s  %6s  %6s  %s" % ["STAT", "v", "raw", "was", "this week"])
	for id in RpgDefs.STATS:
		var s = sheet.stats[id]
		print("%-10s %3d  %6.2f  %6.2f  %+.2f" % [str(s.name), int(s.v), float(s.raw), float(s.was), float(s.raw) - float(s.was)])
		for line in s.lines:
			print("      %s" % str(line))
		print("      -> %s" % str(s.next))
	_print_facts(sheet.facts)
	_print_boosts(RpgBoosts.active(input))
	var rpg = saved.get("rpg") if saved.get("rpg") is Dictionary else RpgSave.empty()
	for date in [today, Dates.add_days(today, -1)]:
		_print_chest(date, today, RpgBoosts.chest(input, date), rpg)
	print("the tab's dot (chest_waiting): %s" % str(RpgBoosts.chest_waiting(state, reading, rpg, today)))
	quit(0)


## The numbers under the curves: per body stat its strongest movements with
## their strength scores, its sets and days; then what the traits count.
func _print_facts(f: Dictionary) -> void:
	print("")
	print("FACTS (strength score = the best set against the elite anchor; the blend is %s)" % str(RpgStats.BLEND))
	for p in RpgDefs.BODY:
		var scores = []
		for m in f.top[p]:
			scores.append(float(m.ss))
		print("%-10s score %.3f · ramp %.2f over %d days · %.1f sets (%d direct, %.0f climbing) · %d movements" % [p, RpgStats.peak_ss(scores),
			RpgStats.ramp(float(f.days[p].size())), f.days[p].size(), float(f.work[p]), int(f.direct[p]), float(f.climb_work[p]), int(f.move_count[p])])
	var all = f.moves.values()
	all.sort_custom(func(a, b): return float(a.ss) > float(b.ss))
	print("movements, the strongest first (ss · kind · what it is measured against · the set · the day):")
	for m in all:
		var what = "%s kg x %d" % [TTUtil.num_str(float(m.kg)), int(m.reps)]
		if str(m.kind) == "hold":
			what = "%d s hold" % int(m.sec)
		elif str(m.kind) == "band":
			what = "x %d, %s band" % [int(m.reps), str(m.band)]
		elif str(m.kind) == "reps":
			what = "x %d" % int(m.reps)
		elif str(m.kind) == "bw":
			what = "+%s kg x %d (at %s kg)" % [TTUtil.num_str(float(m.kg)), int(m.reps), TTUtil.num_str(float(m.bw))]
		print("  %.3f  %-5s %-18s %-44s %-28s %s  -> %s" % [float(m.ss), str(m.kind), _against(m), str(m.name),
			what + (" L+R" if int(m.sides) > 1 else ""), str(m.date), ", ".join(PackedStringArray(m.parts))])
	print("  (* = no anchor of its own: the part's default, counted up to %.1f)" % RpgStats.DEFAULT_CAP)
	print("speed      best pace %.1f s/km (from %s) · %d runs · %.1f km" % [float(f.pace), JSON.stringify(f.pace_from) if not f.pace_from.is_empty() else "no timed run", int(f.runs), float(f.run_m) / 1000.0])
	print("endurance  longest run %.2f km · %.1f km run, %.1f ridden, %.1f walked · %d sessions" % [float(f.longest_run_m) / 1000.0, float(f.run_m) / 1000.0,
		float(f.ride_m) / 1000.0, float(f.walk_m) / 1000.0, int(f.sessions)])
	print("grip       hardest send %s, flash %s (%.0f points) · best hang %s, longest %d s · %d climbing sessions, %d sends · %d forearm sets" % [
		Xp.grade_label(int(f.max_send)) if f.max_send != null else "none", Xp.grade_label(int(f.max_flash)) if f.max_flash != null else "none",
		RpgStats.grade_pts(f.max_send, f.max_flash), ("+%.1f kg" % float(f.best_hang_kg)) if f.best_hang_kg != null else "none",
		int(f.longest_hang_sec), int(f.climb_sessions), int(f.sends), int(f.forearm_sets)])
	print("mind       %d pages on %d days, best streak %d · %d books finished (%d read through the game)" % [int(f.pages), int(f.read_days), int(f.best_read_streak),
		int(f.books), int(f.books_logged)])
	print("flow       %d mobility sets · %.1f min held · %d weeks with %d sets or more" % [int(f.mob_sets), float(f.mob_hold_sec) / 60.0, RpgStats._good_weeks(f), RpgStats.MOB_WEEK_SETS])
	print("grit       %d days trained · best streak %d weeks · %d perfect days" % [int(f.active_days), int(f.best_week_streak), int(f.perfect_days)])


## What a movement's best set was measured against, in a few words.
func _against(m: Dictionary) -> String:
	match str(m.kind):
		"kg":
			return "%.1f kg%s" % [float(m.anchor), "*" if bool(m.capped) else ""]
		"hold":
			return "%d s (to %.2f)" % [int(RpgStats.HOLD_SEC), RpgStats.HOLD_CAP]
		"band":
			return "the ladder (to %.2f)" % RpgStats.BAND_SS
	if float(m.bw_anchor) > 0.0:
		return "%d reps" % int(float(m.bw_anchor))
	return "%d reps (to %.2f)" % [int(RpgStats.WEIGHTLESS_REPS), RpgStats.WEIGHTLESS_CAP]


func _print_boosts(boosts: Array) -> void:
	print("")
	print("BOOSTS in force (%d)" % boosts.size())
	for b in boosts:
		print("  %-14s %-15s %s" % [str(b.id), str(b.name), str(b.text)])
		print("      %s · %s to %s · tier %d · school %s · icon %s" % [str(b.why), str(b.from), str(b.until), int(b.tier), str(b.school) if str(b.school) != "" else "-", str(b.icon)])
		print("      fx %s" % JSON.stringify(b.fx))
	print("  favoured schools (the daily hunt): %s" % str(RpgBoosts.schools(boosts)))


func _print_chest(date: String, today: String, chest, rpg: Dictionary) -> void:
	var when = "today" if date == today else "yesterday"
	if chest == null:
		print("CHEST %s (%s): none" % [when, date])
		return
	var pay = RpgBoosts.chest_pay(chest, rpg)
	print("CHEST %s (%s): %s · %s · %d ore · items %s · rune %s" % [when, date, str(chest.tier), ", ".join(PackedStringArray(chest.kinds)), int(chest.ore),
		JSON.stringify(chest.items), str(chest.rune)])
	print("      opening it now pays %d ore, items %s%s" % [int(pay.ore), JSON.stringify(pay.items), "" if bool(pay.first) else " (already opened at %d kinds)" % RpgBoosts.paid_kinds(rpg, date)])
