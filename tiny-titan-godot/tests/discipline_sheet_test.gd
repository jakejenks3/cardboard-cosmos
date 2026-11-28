extends SceneTree
## Unit test for a discipline's sheet (ui/screens/discipline_sheet.gd): what a
## level tile of the Hero tab's YOUR WEEK section opens.
##   - the three tiles (Lifting, Climbing, Running) open the sheet, not the log form;
##   - the sheet has the level, four headline tiles, the Journey card, five
##     weeks of counts, the last five sessions and the keys "Log one" / "All stats";
##   - "Log one" opens the log form of that discipline, "All stats" Journey -> Stats;
##   - nothing in it is wider than the sheet (412), at normal and at finger sizes;
##   - with nothing logged it says so and offers "Log one";
##   - Parts.stat_tile without a tap still opens the log form; Journey -> Stats still builds.
## It builds the real shell (main.tscn) headless. Made-up data (ShotHelper.demo_saved).
## The screens' classes name the App autoload, which is only there a frame after
## the start: they are loaded by path once App is up (`_S`).
##   godot --headless --path . --script res://tests/discipline_sheet_test.gd
## TINY_TITAN_DATA must point at a throwaway folder: the test replaces the
## whole save, so it refuses to run without it.
## Prints DISC SHEET: X/Y passed and exits with 1 when anything fails.

const SHEET = "res://ui/screens/discipline_sheet.gd"
const DISCS = ["lift", "climb", "run"]
## The widest a sheet's content may be: the 440 column less the sheet's frame.
const MAX_W = 412.0

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _S(path: String):
	return load(path)


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _with_meta(n: Node, key: String) -> Array:
	return _all(n).filter(func(c): return c.has_meta(key))


## Everything a player could read under `n`.
func _words(n: Node) -> Array:
	var out = []
	for c in _all(n):
		if c is Label or c is Button:
			if str(c.text) != "":
				out.append(str(c.text))
	return out


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


## The discipline sheets that are open (not on their way out).
func _sheets(kit) -> Array:
	var out = []
	for c in kit.overlay_root.get_children():
		if c.has_meta("disc_sheet") and not c._closing:
			out.append(c)
	return out


## What is too wide in a sheet ("" = it fits).
func _too_wide(sh) -> String:
	var need = sh.box.get_combined_minimum_size().x
	if need > MAX_W + 0.5:
		return "the content needs %d of %d" % [int(need), int(MAX_W)]
	var inner = sh._scroll.get_child(0)
	if inner.get_combined_minimum_size().x > sh._scroll.size.x + 0.5:
		return "the page needs %d of %d" % [int(inner.get_combined_minimum_size().x), int(sh._scroll.size.x)]
	var right = sh._panel.get_global_rect().end.x
	if right > 440.5:
		return "the sheet ends at %d" % int(right)
	for c in _all(sh.box):
		if c is Control and c.is_visible_in_tree() and c.get_global_rect().end.x > right + 0.5:
			return "%s ends at %d of %d" % [str(c), int(c.get_global_rect().end.x), int(right)]
	return ""


func _close_all(kit) -> void:
	for sh in _sheets(kit):
		sh.close()
	await _wait(0.35)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		print("FAIL  no App autoload")
		print("DISC SHEET: 0/1 passed")
		quit(1)
		return
	if not app.is_test_data():
		print("REFUSED: set TINY_TITAN_DATA to a throwaway folder first.")
		print("DISC SHEET: 0/1 passed")
		quit(1)
		return
	var kit = _S("res://ui/kit.gd")
	var parts = _S("res://ui/parts.gd")
	var shots = _S("res://tests/shot_helper.gd")
	var sheet_cls = _S(SHEET)
	ok(sheet_cls != null and str(sheet_cls.get_global_name()) == "", "the sheet's script loads and has no class_name")

	var year = shots.demo_saved("year")
	year.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	app.replace_all(year)
	var today = str(app.today)

	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)
	if absf(main.size.x - 440.0) > 0.5:
		main.set_anchors_preset(Control.PRESET_TOP_LEFT)
		main.size = Vector2(440, 900)
		await _frames(4)
	if kit.overlay_root == null:
		var over = Control.new()
		over.size = Vector2(440, 900)
		root.add_child(over)
		kit.overlay_root = over
	app.go("home")
	await _frames(4)

	# --- the Hero tab's level tiles ---------------------------------------------------------
	var tiles = _with_meta(main._screen, "stat_tile")
	ok(tiles.map(func(t): return str(t.get_meta("stat_tile"))) == DISCS, "the Hero tab has the three level tiles: lifting, climbing, running", tiles.map(func(t): return str(t.get_meta("stat_tile"))))
	var reading = _with_meta(main._screen, "section").filter(func(n): return str(n.get_meta("section")) == "reading")
	ok(reading.size() == 1 and reading[0]._tap.is_valid(), "the whole READING section is a key (it opens the reading sheet)")

	for d in DISCS:
		app.go("home")
		await _frames(4)
		var tile = _with_meta(main._screen, "stat_tile").filter(func(t): return str(t.get_meta("stat_tile")) == d)
		if tile.is_empty():
			ok(false, "%s: its tile is on the Hero tab" % d)
			continue
		tile[0].pressed.emit()
		await _frames(4)
		var open = _sheets(kit)
		ok(open.size() == 1 and str(open[0].get_meta("disc_sheet")) == d and str(app.tab) == "home", "%s: a tap on the tile opens its sheet and stays on the Hero tab (not the log form)" % d, [open.size(), app.tab])
		if open.size() != 1:
			continue
		var sh = open[0]
		var mine = app.sessions().filter(func(x): return str(x.discipline) == d)
		mine.sort_custom(func(a, b): return str(a.date) > str(b.date) or (str(a.date) == str(b.date) and int(a.createdAt) > int(b.createdAt)))
		ok(str(sh._title) == str(TT.DISCIPLINE_META[d].name), "%s: the sheet is titled with the discipline's name" % d, sh._title)
		# The level.
		var lv = app.state.levels[d]
		var level = _with_meta(sh, "disc_level")
		ok(level.size() == 1 and int(level[0].get_meta("disc_level")) == int(lv.level), "%s: the level card says level %d" % [d, int(lv.level)])
		var left = "%s XP to level %d" % [Xp.fmt_int(int(lv.toNext) - int(lv.into)), int(lv.level) + 1]
		ok(level.size() == 1 and _words(level[0]).has(left), "%s: and what is left (\"%s\")" % [d, left], _words(level[0]) if level.size() == 1 else [])
		# The headline tiles.
		var heads = _with_meta(sh, "disc_tile").map(func(n): return str(n.get_meta("disc_tile")))
		var want = {"lift": ["sessions", "sets", "moved", "week"], "climb": ["sessions", "sends", "flashes", "hardest"], "run": ["runs", "distance", "longest", "pace"]}
		ok(heads == want[d], "%s: four headline tiles" % d, heads)
		# The Journey card.
		var card = _with_meta(sh, "disc_card")
		ok(card.size() == 1 and card[0].get_child_count() == 1 and card[0].get_child(0) is PanelContainer, "%s: the Journey card is in it" % d)
		# Five weeks of counts.
		var weeks = _with_meta(sh, "disc_weeks").filter(func(n): return n.get_meta("disc_weeks") is Array)
		var counted = [0, 0, 0, 0, 0]
		var this_week = Dates.week_key(today)
		for x in mine:
			for i in range(5):
				if Dates.week_key(str(x.date)) == Dates.add_weeks(this_week, -(4 - i)):
					counted[i] += 1
		ok(weeks.size() == 1 and weeks[0].get_meta("disc_weeks") == counted, "%s: this week and the last four, counted from the log %s" % [d, str(counted)], weeks[0].get_meta("disc_weeks") if weeks.size() == 1 else null)
		# The last five sessions.
		var rows = _with_meta(sh, "disc_recent").filter(func(n): return n.get_meta("disc_recent") is String and str(n.get_meta("disc_recent")) != "")
		var ids = rows.map(func(n): return str(n.get_meta("disc_recent")))
		var newest = mine.slice(0, 5).map(func(x): return str(x.id))
		ok(ids == newest and ids.size() == mini(5, mine.size()) and ids.size() > 0, "%s: its last %d sessions, the newest first" % [d, newest.size()], [ids, newest])
		ok(rows.all(func(r): return r._tap.is_valid()), "%s: each opens its session" % d)
		# The keys.
		var log_key = _with_meta(sh, "disc_log")
		var all_key = _with_meta(sh, "disc_all")
		ok(log_key.size() == 1 and all_key.size() == 1 and log_key[0] is Button and all_key[0] is Button and log_key[0].get_parent() == all_key[0].get_parent(), "%s: \"Log one\" and \"All stats\" in one row" % d)
		ok(_with_meta(sh, "disc_empty").is_empty(), "%s: no \"nothing here\" card when there are sessions" % d)
		await _wait(0.4)
		ok(_too_wide(sh) == "", "%s: nothing is wider than the sheet" % d, _too_wide(sh))
		if d == "lift" and card.size() == 1:
			# Another exercise on the chart: only the card is built again.
			var chips = _all(card[0]).filter(func(n): return n is Button)
			if chips.size() >= 2:
				chips[1].pressed.emit()
				await _frames(3)
				ok(card[0].get_child_count() == 1 and sheet_cls.exercise != null and _sheets(kit).size() == 1, "lift: picking another exercise rebuilds the card in place", [card[0].get_child_count(), sheet_cls.exercise])
				ok(_too_wide(sh) == "", "lift: and it still fits", _too_wide(sh))
			else:
				ok(false, "lift: the card has exercise chips", chips.size())
		# All stats.
		if all_key.size() == 1:
			all_key[0].pressed.emit()
			await _wait(0.35)
			ok(str(app.tab) == "journey" and str(app.journey_tab) == "stats" and _sheets(kit).is_empty(), "%s: \"All stats\" closes it and opens Journey -> Stats" % d, [app.tab, app.journey_tab])
		# Log one (the sheet opened again, by the script itself).
		app.go("home")
		await _frames(3)
		sheet_cls.open(d)
		await _frames(3)
		var again = _sheets(kit)
		ok(again.size() == 1, "%s: open(\"%s\") opens one sheet" % [d, d], again.size())
		if again.size() == 1:
			_with_meta(again[0], "disc_log")[0].pressed.emit()
			await _wait(0.35)
			ok(str(app.tab) == "log" and str(app.log_discipline) == d and app.editing_session_id == null, "%s: \"Log one\" opens the log form of %s" % [d, d], [app.tab, app.log_discipline])
			ok(_sheets(kit).is_empty() and kit.overlay_root.get_children().filter(func(c): return c.has_meta("disc_sheet")).is_empty(), "%s: and the sheet is gone" % d)

	# --- leaving for another tab takes the sheet along -------------------------------------
	app.go("home")
	await _frames(3)
	sheet_cls.open("run")
	await _frames(3)
	app.open_log("run", app.sessions().filter(func(x): return str(x.discipline) == "run")[0].id)
	await _wait(0.35)
	ok(_sheets(kit).is_empty(), "a session's Edit key (another tab) closes the sheet under it")

	# --- an id it does not know opens nothing ----------------------------------------------
	app.go("home")
	await _frames(3)
	sheet_cls.open("ride")
	sheet_cls.open("misc")
	sheet_cls.open("")
	await _frames(3)
	ok(_sheets(kit).is_empty(), "open() of anything but lift, climb, run opens nothing")

	# --- pounds and miles --------------------------------------------------------------------
	var wu_was = str(app.saved.settings.weightUnit)
	var du_was = str(app.saved.settings.distanceUnit)
	app.saved.settings.weightUnit = "lb"
	app.saved.settings.distanceUnit = "mi"
	sheet_cls.open("lift")
	await _frames(3)
	var lb = _sheets(kit)
	ok(lb.size() == 1 and _words(lb[0]).has("lb moved") and not _words(lb[0]).has("kg moved"), "pounds: the weight moved is in lb", _words(lb[0]).filter(func(w): return w.contains("moved")) if lb.size() == 1 else [])
	await _close_all(kit)
	sheet_cls.open("run")
	await _frames(3)
	var mi = _sheets(kit)
	ok(mi.size() == 1 and _words(mi[0]).has("mi in all") and _words(mi[0]).has("mi longest run") and _words(mi[0]).has("best pace /mi"), "miles: the distances and the pace are in miles", _words(mi[0]).filter(func(w): return w.contains("mi") or w.contains("km")) if mi.size() == 1 else [])
	await _wait(0.3)
	ok(mi.size() == 1 and _too_wide(mi[0]) == "", "and it fits", _too_wide(mi[0]) if mi.size() == 1 else "")
	await _close_all(kit)
	app.saved.settings.weightUnit = wu_was
	app.saved.settings.distanceUnit = du_was

	# --- at finger sizes -----------------------------------------------------------------------
	kit.fingers = true
	app.go("home")
	await _frames(4)
	var hero_wide = main._scroll.get_children().filter(func(c): return c is Control and not (c is ScrollBar) and c.get_combined_minimum_size().x > main._scroll.size.x + 0.5)
	ok(hero_wide.is_empty() and _with_meta(main._screen, "stat_tile").size() == 3, "finger sizes: the Hero tab fits with its three tiles")
	for d in DISCS:
		sheet_cls.open(d)
		await _wait(0.4)
		var f = _sheets(kit)
		ok(f.size() == 1 and _too_wide(f[0]) == "", "finger sizes, %s: nothing is wider than the sheet" % d, _too_wide(f[0]) if f.size() == 1 else "no sheet")
		await _close_all(kit)
	kit.fingers = false

	# --- the tile elsewhere, and Journey -> Stats ------------------------------------------
	var plain = parts.stat_tile("run", app.state.levels.run)
	root.add_child(plain)
	app.go("home")
	await _frames(2)
	plain.pressed.emit()
	await _frames(2)
	ok(str(app.tab) == "log" and str(app.log_discipline) == "run" and _sheets(kit).is_empty(), "a level tile made without a tap still opens the log form", [app.tab, app.log_discipline])
	plain.queue_free()
	app.go("journey", "stats")
	await _frames(5)
	var stats_wide = main._scroll.get_children().filter(func(c): return c is Control and not (c is ScrollBar) and c.get_combined_minimum_size().x > main._scroll.size.x + 0.5)
	var j_words = _words(main._screen)
	ok(stats_wide.is_empty() and _with_meta(main._screen, "copy_dosage").size() == 1 and j_words.has("Reps at each session's top weight. A heavier weight starts a new step.") and j_words.has("Best pace") and j_words.has("Reps"), "Journey -> Stats still builds its lifting and running cards, and fits", j_words.size())
	ok(not j_words.is_empty(), "the Journey page has words")

	# --- nothing logged -------------------------------------------------------------------------
	var none = app.empty_saved()
	none.settings["focus"] = ""
	none.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	app.replace_all(none)
	app.go("home")
	await _frames(4)
	for d in DISCS:
		sheet_cls.open(d)
		await _wait(0.4)
		var e = _sheets(kit)
		if e.size() != 1:
			ok(false, "empty save, %s: the sheet opens" % d, e.size())
			continue
		var esh = e[0]
		var said = _with_meta(esh, "disc_empty")
		ok(said.size() == 1 and _words(said[0]).has("Nothing here yet"), "empty save, %s: it says nothing is logged yet" % d, _words(esh))
		ok(_with_meta(esh, "disc_level").size() == 1 and int(_with_meta(esh, "disc_level")[0].get_meta("disc_level")) == 1 and _with_meta(esh, "disc_tile").is_empty() and _with_meta(esh, "disc_card").is_empty() and _with_meta(esh, "disc_all").is_empty(), "empty save, %s: level 1 and no numbers, card or \"All stats\"" % d)
		ok(_too_wide(esh) == "", "empty save, %s: it fits" % d, _too_wide(esh))
		var key = _with_meta(esh, "disc_log")
		ok(key.size() == 1, "empty save, %s: it offers \"Log one\"" % d)
		if key.size() == 1:
			key[0].pressed.emit()
			await _wait(0.35)
			ok(str(app.tab) == "log" and str(app.log_discipline) == d and _sheets(kit).is_empty(), "empty save, %s: which opens its log form" % d, [app.tab, app.log_discipline])
		app.go("home")
		await _frames(3)

	print("DISC SHEET: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
