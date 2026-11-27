extends SceneTree
## Test of the Realm tab's hub and its Map page (RPG_PLAN.md 10.0, 10.1):
## ui/rpg/realm.gd (RealmScreen) and ui/rpg/realm_map.gd (RealmMap).
##   - the first visit: the twelve stats count up (a tap ends it, a rebuild
##     does not start it again), "Skip" and "Enter the Ironwild" open the Realm;
##   - the hub's sections in order; the banner; a training chest of today and
##     of yesterday, opened once, the grown one; the boosts; the five sub-tabs;
##   - the Map: eight regions, ten stage nodes, the prep sheet and its Fight
##     key, wins written into the save open the road, the cache, the star
##     chests, the hunt and its prize, the Spire, the weekly rival;
##   - a kept battle shows "Continue";
##   - nothing wider than the column at normal size and at finger sizes, every
##     key 40 px high or more at finger sizes, a rebuild leaves every key where
##     it was.
## It builds the real shell (main.tscn) headless, with a made-up year of
## training. The screens' classes name the App autoload, which is only there a
## frame after the start, so this script never names one of them: they are
## loaded by path once App is up and told apart by `_is`.
##   godot --headless --path . --script res://tests/rpg_hub_test.gd
## TINY_TITAN_DATA must point at a throwaway folder: the test replaces the
## whole save, so it refuses to run without it.
## Prints RPG HUB: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var app
var main
var kit
var rpg_ui
var realm_cls
var map_cls


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## Every node under `n` (itself too) that is not on its way out.
func _all(n: Node, out: Array = []) -> Array:
	if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
		return out
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _with(n: Node, key: String, value = null) -> Array:
	return _all(n).filter(func(c): return c.has_meta(key) and (value == null or str(c.get_meta(key)) == str(value)))


func _one(n: Node, key: String, value = null):
	var l = _with(n, key, value)
	return l[0] if not l.is_empty() else null


func _metas(n: Node, key: String) -> Array:
	return _with(n, key).map(func(c): return str(c.get_meta(key)))


func _words(n: Node) -> String:
	var out = []
	for c in _all(n):
		if c is Label or c is Button:
			if str(c.text) != "":
				out.append(str(c.text))
	return " | ".join(PackedStringArray(out))


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _is(n, class_id: String) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var sc = n.get_script()
	while sc != null:
		if str(sc.get_global_name()) == class_id:
			return true
		sc = sc.get_base_script()
	return false


func _same(a, b) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


## What is wrong with the width of the page `main` shows ("" = it fits).
func _too_wide() -> String:
	var sc = main._scroll
	if sc.get_global_rect().end.x > 440.5:
		return "the column ends at %d" % int(sc.get_global_rect().end.x)
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar) and c.get_combined_minimum_size().x > sc.size.x + 0.5:
			return "the page needs %d of %d" % [int(c.get_combined_minimum_size().x), int(sc.size.x)]
	var page = main._screen
	if page.size.x > 412.5:
		return "the page is %d wide" % int(page.size.x)
	for c in _all(page):
		if c is Control and c.is_visible_in_tree() and c.get_global_rect().end.x > page.get_global_rect().end.x + 0.5 and not _clipped(c, page):
			return "%s ends at %d, the page at %d" % [str(page.get_path_to(c)).right(60), int(c.get_global_rect().end.x), int(page.get_global_rect().end.x)]
	return ""


## Is `c` inside something that cuts off what runs past it?
func _clipped(c: Node, top: Node) -> bool:
	var p = c.get_parent()
	while p != null and p != top:
		if p is Control and p.clip_contents:
			return true
		p = p.get_parent()
	return false


## The same check for a sheet's own column.
func _sheet_too_wide(sh) -> String:
	for n in _all(sh):
		if n is ScrollContainer:
			for c in n.get_children():
				if c is Control and not (c is ScrollBar) and c.get_combined_minimum_size().x > n.size.x + 0.5:
					return "the sheet needs %d of %d" % [int(c.get_combined_minimum_size().x), int(n.size.x)]
	return ""


func _sheets() -> Array:
	return kit.overlay_root.get_children().filter(func(c): return _is(c, "Sheet") and not c.is_queued_for_deletion() and not c._closing)


func _sheet(meta: String):
	for sh in _sheets():
		if _one(sh, meta) != null:
			return sh
	return null


func _drop_sheets() -> void:
	for c in kit.overlay_root.get_children():
		if _is(c, "Sheet"):
			c.queue_free()
	await _frames(2)


func _battles() -> Array:
	return kit.overlay_root.get_children().filter(func(c): return _is(c, "BattleView") and not c.is_queued_for_deletion())


func _shut_battles() -> void:
	for b in _battles():
		b.close()
	await _frames(3)
	app.draft_store("battle", null)


## Tap a Card (its own callable) or press a key.
func _tap(c) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	if c is BaseButton:
		if c.disabled:
			return false
		c.pressed.emit()
		return true
	if c.get("_tap") is Callable and c._tap.is_valid():
		c._tap.call()
		return true
	return false


func _realm():
	return main._screen


func _show_realm() -> void:
	app.go("home")
	await _frames(3)
	app.go("realm")
	await _frames(12)


## Where every key that names itself is, by its name.
func _key_places() -> Dictionary:
	var out = {}
	for c in _with(_realm(), "anchor_id"):
		if c is Control and c.is_visible_in_tree():
			out[str(c.get_meta("anchor_id"))] = c.global_position.round()
	return out


## A made-up lift session on `date`.
func _lift(id: String, date: String, kg: float, at: int) -> Dictionary:
	var sets = []
	for i in range(4):
		sets.append({"reps": 6, "weightKg": kg})
	return {"id": id, "discipline": "lift", "date": date, "createdAt": at, "source": "manual", "durationSec": 3000,
		"exercises": [{"name": "Bench Press - Barbell", "sets": sets}, {"name": "Squat - Barbell", "sets": sets}]}


## A win of a road stage written into the save, every star earned, one weakness learned.
func _win(stage_id: String, today: String) -> bool:
	var st = RpgWorld.stage(stage_id)
	var rpg = app.rpg()
	if str(st.kind) == "cache":
		var res_c = RpgSave.take_cache(rpg, stage_id, RpgLoot.cache(stage_id, rpg, 1)[2])
		if bool(res_c.ok):
			app.set_rpg(res_c.rpg)
		return bool(res_c.ok)
	var learned = {}
	var first_foe = str(st.waves[0][0].foe)
	learned[first_foe] = [RpgFoes.weak_of(first_foe)[0]]
	var summary = {"win": true, "turns": 2, "breaks": 9, "items": 0, "hp_share": 1.0, "guards": 0, "schools": ["push", "pull", "legs", "speed"], "worst_share": 0.0, "learned": learned}
	var res = RpgSave.finish(rpg, {"kind": "stage", "id": stage_id}, st, {"xp": 20, "ore": 10}, summary, today)
	if bool(res.ok):
		app.set_rpg(res.rpg)
	return bool(res.ok)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	app = root.get_node_or_null("App")
	if app == null:
		print("FAIL  no App autoload")
		print("RPG HUB: 0/1 passed")
		quit(1)
		return
	if not app.is_test_data():
		print("REFUSED: set TINY_TITAN_DATA to a throwaway folder first.")
		print("RPG HUB: 0/1 passed")
		quit(1)
		return
	kit = load("res://ui/kit.gd")
	rpg_ui = load("res://ui/rpg/rpg_ui.gd")
	realm_cls = load("res://ui/rpg/realm.gd")
	map_cls = load("res://ui/rpg/realm_map.gd")
	var shots = load("res://tests/shot_helper.gd")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)
	if absf(main.size.x - 440.0) > 0.5:
		main.set_anchors_preset(Control.PRESET_TOP_LEFT)
		main.size = Vector2(440, 900)
		await _frames(4)
	ok(is_equal_approx(main.size.x, 440.0), "the shell is 440 wide, a phone's width", main.size)
	ok(realm_cls.hub_ready == true, "the hub says it can open a chest (the tab's dot is on)")

	# --- a made-up year of training, with a lift today and yesterday and pages today ----------------
	var today = str(app.today)
	var yday = Dates.add_days(today, -1)
	var year = shots.demo_saved("year")
	year.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	year.sessions.append(_lift("hub_y", yday, 70.0, 1900000000000))
	year.sessions.append(_lift("hub_t", today, 72.5, 1900000100000))
	year.reading = [{"id": "hub_r", "date": today, "pages": 12, "createdAt": 1900000200000}]
	app.replace_all(year)
	await _frames(3)
	ok(not bool(app.rpg().opened) and app.sessions().size() > 100, "a year of training and a Realm never opened")

	# =================================================================================================
	# The first visit
	# =================================================================================================
	realm_cls.first_reset()
	app.go("realm")
	await _frames(4)
	var realm = _realm()
	ok(_is(realm, "RealmScreen") and _is(realm, "UiScreen"), "the Realm tab opens its screen")
	ok(_metas(realm, "section") == ["realm_first"], "the first visit is shown instead of the hub", _metas(realm, "section"))
	ok(_metas(realm, "first_stat") == RpgDefs.STATS, "the twelve stats in order", _metas(realm, "first_stat"))
	var vals = _with(realm, "first_value")
	ok(vals.size() == 12 and vals.all(func(v): return int(v.get_meta("first_value")) >= 1 and int(v.get_meta("first_value")) <= 99) and vals.any(func(v): return int(v.get_meta("first_value")) > 10), "each with its value from the log (%s)" % str(vals.map(func(v): return int(v.get_meta("first_value")))))
	ok(not realm_cls.count_done() and str(vals[11].text) == "" and _one(realm, "first_points").modulate.a == 0.0, "the count-up has begun and has not reached the last stat", [realm_cls.count_done(), vals[11].text])
	var sheet = rpg_ui.sheet()
	var legs_line = str(sheet.stats.legs.lines[0]) if not sheet.stats.legs.lines.is_empty() else ""
	ok(legs_line != "" and _words(realm).contains(legs_line), "a stat's first line from the log is beside it (%s)" % legs_line)
	ok(int(_one(realm, "first_points").get_meta("first_points")) == int(rpg_ui.points().earned) and int(rpg_ui.points().earned) >= RpgDefs.POINTS_START and _words(realm).contains("already earned %d skill points" % int(rpg_ui.points().earned)), "it says how many skill points the training has earned", rpg_ui.points())
	ok(_one(realm, "first_enter") is Button and _one(realm, "first_skip") is Button, "an Enter key and a Skip link")
	var enter_y = _one(realm, "first_enter").global_position.y
	_tap(_one(realm, "section", "realm_first"))
	await _frames(2)
	vals = _with(realm, "first_value")
	ok(realm_cls.count_done() and vals.all(func(v): return str(v.text) == str(int(v.get_meta("first_value")))) and _one(realm, "first_points").modulate.a == 1.0, "a tap ends the count-up: every number is there", vals.map(func(v): return v.text))
	ok(_one(realm, "first_enter").global_position.y == enter_y, "and the Enter key has not moved")
	realm.rebuild_now()
	await _frames(3)
	vals = _with(realm, "first_value")
	ok(realm_cls.count_done() and vals.size() == 12 and vals.all(func(v): return str(v.text) == str(int(v.get_meta("first_value")))), "a rebuild does not start it again")
	ok(_too_wide() == "", "the first visit fits the column", _too_wide())
	kit.fingers = true
	await _show_realm()
	realm = _realm()
	ok(_too_wide() == "" and _one(realm, "first_enter").size.y >= 40.0 and _one(realm, "first_skip").size.y >= 40.0, "at finger sizes too, with keys 40 high or more", [_too_wide(), _one(realm, "first_skip").size])
	kit.fingers = false
	await _show_realm()
	realm = _realm()

	# Skip: the Realm is opened, the Armory's gear goes into the builds, no fight starts.
	_tap(_one(realm, "first_skip"))
	await _frames(12)
	var worn = {}
	for slot in TT.SLOTS:
		var it = app.loadout().get(slot)
		if it is String and it != "":
			worn[slot] = it
	ok(bool(app.rpg().opened) and _same(RpgSave.build_of(app.rpg()).gear, worn) and _battles().is_empty(), "Skip opens the Realm with the Armory's gear and starts no fight", RpgSave.build_of(app.rpg()).gear)
	ok(_metas(_realm(), "section").has("realm_banner") and not _metas(_realm(), "section").has("realm_first"), "and the hub is shown", _metas(_realm(), "section"))

	# Enter: the same, and the first fight starts.
	app.set_rpg(RpgSave.empty())
	await _frames(12)
	realm = _realm()
	ok(_metas(realm, "section") == ["realm_first"] and _with(realm, "first_value").all(func(v): return str(v.text) != ""), "an unopened Realm shows the first visit again, its numbers there at once")
	_tap(_one(realm, "first_enter"))
	await _frames(6)
	var fights = _battles()
	ok(bool(app.rpg().opened) and fights.size() == 1, "Enter opens the Realm and starts a fight", fights.size())
	if fights.size() == 1:
		ok(str(fights[0].B.what.id) == "r1s1" and fights[0].B.foes.size() == 1, "the first fight: r1s1, one foe", fights[0].B.get("what"))
	await _shut_battles()
	await _frames(8)

	# =================================================================================================
	# The hub
	# =================================================================================================
	realm = _realm()
	var rpg = app.rpg()
	var secs = _metas(realm, "section").filter(func(s): return s.begins_with("realm_"))
	ok(secs == ["realm_tabs", "realm_banner", "realm_notices", "realm_boosts", "realm_map"], "the hub's sections in order: sub-tabs, banner, notices, boosts, the page", secs)
	var order = _with(realm, "section").filter(func(c): return str(c.get_meta("section")).begins_with("realm_")).map(func(c): return c.global_position.y)
	var sorted_y = order.duplicate()
	sorted_y.sort()
	ok(order == sorted_y, "and they stand in that order on the page", order)
	ok(int(_one(realm, "realm_level").get_meta("realm_level")) == int(rpg_ui.level()) and int(_one(realm, "realm_power").get_meta("realm_power")) > 0 and _one(realm, "realm_hero") != null, "the banner: the hero, the fighter level, the power", _one(realm, "realm_power").get_meta("realm_power"))
	var banner = _one(realm, "section", "realm_banner")
	ok(int(_one(banner, "rpg_ore").get_meta("rpg_ore")) == int(rpg.ore) and int(_one(realm, "realm_points").get_meta("realm_points")) == int(rpg_ui.points().left) and int(rpg_ui.points().left) > 0, "its ore and the skill points to spend", rpg_ui.points())

	# --- the training chests ------------------------------------------------------------------------
	var input = rpg_ui.input()
	var waiting = RpgBoosts.waiting(input, rpg)
	var open_keys = _with(realm, "realm_chest_open")
	ok(waiting.size() == 2 and open_keys.size() == 2 and _metas(realm, "realm_chest") == [today, yday], "a chest for today and one for yesterday, each with an Open key", [waiting.size(), _metas(realm, "realm_chest")])
	ok(RpgBoosts.chest_waiting(app.state, app.reading(), rpg, today) == (not open_keys.is_empty()) and _with(main._nav_row, "tab_dot").size() == 1, "the tab's dot and the cheap check agree with the rows: a chest waits")
	var chest_t = RpgBoosts.chest(input, today)
	var pay_t = RpgBoosts.chest_pay(chest_t, rpg)
	ok(chest_t.kinds.has("lift") and chest_t.kinds.has("read") and bool(pay_t.first) and _words(_one(realm, "realm_chest", today)).contains("%d ore" % int(pay_t.ore)), "today's holds lifting and reading, and its row says the ore", [chest_t.kinds, _words(_one(realm, "realm_chest", today))])
	var row_y = _one(realm, "realm_chest", today).global_position.y
	var yday_key_y = _one(realm, "realm_chest_open", yday).global_position.y
	var ore0 = int(rpg.ore)
	var items0 = 0
	for k in rpg.items:
		items0 += int(rpg.items[k])
	_tap(_one(realm, "realm_chest_open", today))
	await _frames(12)
	rpg = app.rpg()
	var items1 = 0
	for k in rpg.items:
		items1 += int(rpg.items[k])
	var paid_items = 0
	for it in pay_t.items:
		paid_items += int(it.n)
	ok(int(rpg.ore) == ore0 + int(pay_t.ore) and items1 == items0 + paid_items and paid_items >= 1 and int(rpg.chests[today]) == chest_t.kinds.size(), "opening it pays its ore and items and marks the day", [int(rpg.ore) - ore0, items1 - items0, rpg.chests])
	realm = _realm()
	var row_t = _one(realm, "realm_chest", today)
	ok(row_t != null and str(row_t.get_meta("realm_chest_state")) == "opened" and _one(realm, "realm_chest_open", today) == null and _words(row_t).contains("Opened:"), "its row stays for the visit and says what came out; the key is gone", _words(row_t) if row_t != null else "")
	ok(row_t != null and row_t.global_position.y == row_y and _one(realm, "realm_chest_open", yday).global_position.y == yday_key_y, "nothing moved: the row and yesterday's key are where they were")
	ok(not bool(RpgSave.claim_chest(rpg, chest_t).ok), "it pays once")
	_tap(_one(realm, "realm_chest_open", yday))
	await _frames(12)
	rpg = app.rpg()
	realm = _realm()
	ok(_with(realm, "realm_chest_open").is_empty() and not RpgBoosts.chest_waiting(app.state, app.reading(), rpg, today) and _with(main._nav_row, "tab_dot").is_empty() and RpgBoosts.waiting(rpg_ui.input(), rpg).is_empty(), "both opened: no key, no chest waiting, no dot on the tab")
	# A day that grew after its chest was opened pays the difference.
	var grown = RpgSave.copy(rpg)
	grown.chests[today] = chest_t.kinds.size() - 1
	ore0 = int(grown.ore)
	app.set_rpg(grown)
	await _frames(12)
	realm = _realm()
	var diff_key = _one(realm, "realm_chest_open", today)
	ok(diff_key != null and _words(_one(realm, "realm_chest", today)).contains("+%d ore" % RpgDefs.CHEST_ORE_KIND), "a chest that grew since it was opened offers the difference", _words(_one(realm, "realm_chest", today)) if _one(realm, "realm_chest", today) != null else "")
	_tap(diff_key)
	await _frames(12)
	rpg = app.rpg()
	ok(int(rpg.ore) == ore0 + RpgDefs.CHEST_ORE_KIND and int(rpg.chests[today]) == chest_t.kinds.size(), "and pays only that", int(rpg.ore) - ore0)

	# --- the boosts -------------------------------------------------------------------------------
	realm = _realm()
	var boosts = rpg_ui.boosts()
	ok(not boosts.is_empty() and _metas(realm, "realm_boost") == boosts.map(func(b): return str(b.id)), "a row for every boost of the day (%d)" % boosts.size(), _metas(realm, "realm_boost"))
	var b_row = _with(realm, "realm_boost")[0]
	ok(_words(b_row).contains(str(boosts[0].name)) and _words(b_row).contains(str(boosts[0].text)), "with its name and its effect (how long it lasts is in its sheet)", _words(b_row))
	_tap(b_row)
	await _frames(3)
	var b_sheet = _sheet("realm_boost_sheet")
	ok(b_sheet != null and _words(b_sheet).contains(str(boosts[0].why)) and _sheet_too_wide(b_sheet) == "", "a tap says where it came from", _words(b_sheet) if b_sheet != null else "")
	await _drop_sheets()

	# --- the sub-tabs -----------------------------------------------------------------------------
	var tabs = _with(realm, "realm_tab")
	ok(tabs.map(func(t): return str(t.get_meta("realm_tab"))) == ["map", "hero", "moves", "skills", "gear"] and tabs.map(func(t): return str(t.text)) == ["Map", "Hero", "Moves", "Skills", "Gear"], "five sub-tabs: Map, Hero, Moves, Skills, Gear")
	var can_learn = RpgSkills.learnable(rpg, rpg_ui.sheet(), rpg_ui.level(), rpg_ui.days())
	var dots = _metas(realm, "realm_tab_dot")
	var feats_ready = RpgFeats.ready(rpg, rpg_ui.sheet())
	ok(dots.has("skills") == (not can_learn.is_empty()) and not can_learn.is_empty() and dots.has("hero") == (feats_ready > 0) and not dots.has("moves") and not dots.has("gear"), "a dot on Skills exactly while a node can be learned, on Hero exactly while a feat can be claimed", [dots, can_learn.size(), feats_ready])
	ok((_one(realm, "realm_feat_notice") != null) == (feats_ready > 0), "and a row on the front page says a feat is done", feats_ready)
	ok(dots.has("map") == map_cls.something_waits(rpg) and not dots.has("map"), "none on Map while nothing waits there", dots)
	ok(_one(realm, "realm_skill_notice") != null and int(_one(realm, "realm_skill_notice").get_meta("realm_skill_notice")) == can_learn.size(), "and the notice \"A skill can be learned\"")
	var tab_places = tabs.map(func(t): return t.global_position.round())
	var pages_ok = true
	var pages_said = []
	for page in ["hero", "moves", "skills", "gear", "map"]:
		_tap(_one(_realm(), "realm_tab", page))
		await _frames(12)
		realm = _realm()
		var box = _one(realm, "section", "realm_" + page)
		var missing = _one(realm, "realm_page_missing") != null
		pages_said.append("%s:%s" % [page, "stub" if missing else "built"])
		if str(rpg_ui.page) != page or box == null or box.get_child_count() == 0 or _too_wide() != "":
			pages_ok = false
			pages_said.append("BAD %s %s" % [page, _too_wide()])
		if _with(realm, "realm_tab").map(func(t): return t.global_position.round()) != tab_places:
			pages_ok = false
			pages_said.append("MOVED at %s" % page)
		if page != "map" and missing != (not realm_cls.has_fill(load("res://ui/rpg/realm_%s.gd" % page))):
			pages_ok = false
			pages_said.append("WRONG STUB %s" % page)
	ok(pages_ok, "every sub-tab switches the page, fits the column and leaves the tab keys where they were (%s)" % ", ".join(PackedStringArray(pages_said)), pages_said)
	_tap(_one(realm, "realm_skill_notice").find_children("*", "Button", true, false)[0])
	await _frames(12)
	ok(str(rpg_ui.page) == "skills", "the notice's key goes to the Skills page")
	_tap(_one(_realm(), "realm_tab", "map"))
	await _frames(12)
	realm = _realm()
	# A page's builder is found by its `fill`, and called.
	var made = GDScript.new()
	made.source_code = "extends RefCounted\nstatic func fill(box, _screen) -> void:\n\tvar l = Label.new()\n\tl.text = \"made up\"\n\tbox.add_child(l)\n"
	made.reload()
	var probe = VBoxContainer.new()
	made.call("fill", probe, null)
	ok(realm_cls.has_fill(made) and probe.get_child_count() == 1 and not realm_cls.has_fill(null) and realm_cls.has_fill(map_cls), "a page's `fill` is found and called by name")
	probe.free()

	# =================================================================================================
	# The Map
	# =================================================================================================
	rpg = app.rpg()
	ok(_metas(realm, "section").filter(func(s): return s.begins_with("map_")) == ["map_hunts", "map_road", "map_spire", "map_bestiary"], "the Map: hunts, the road, the Spire, the bestiary", _metas(realm, "section"))
	var regions = _with(realm, "map_region")
	ok(regions.map(func(r): return str(r.get_meta("map_region"))) == RpgDefs.REGIONS and regions.map(func(r): return str(r.get_meta("map_region_state"))) == ["chosen", "locked", "locked", "locked", "locked", "locked", "locked", "locked"], "eight regions, only the first open", regions.map(func(r): return str(r.get_meta("map_region_state"))))
	var nodes = _with(realm, "map_stage")
	var want_ids = []
	for s in range(1, 11):
		want_ids.append("r1s%d" % s)
	ok(nodes.map(func(n): return str(n.get_meta("map_stage"))) == want_ids and str(nodes[0].get_meta("map_state")) == "open" and nodes.slice(1).all(func(n): return str(n.get_meta("map_state")) == "locked"), "ten stage nodes: r1s1 open, the rest locked", nodes.map(func(n): return str(n.get_meta("map_state"))))
	# (2026-11-26: the stages are places on a winding road, three to a row, the boss alone at its end.)
	ok(nodes.slice(0, 9).all(func(n): return n.size == nodes[0].size) and nodes[0].size.y >= 40.0 and nodes[9].size.y >= nodes[0].size.y
		and nodes[1].global_position.x - nodes[0].global_position.x > 100.0 and is_equal_approx(nodes[2].global_position.y, nodes[0].global_position.y)
		and nodes[3].global_position.y > nodes[0].global_position.y and nodes[3].global_position.x > nodes[5].global_position.x
		and nodes[9].global_position.y > nodes[8].global_position.y and _one(realm, "map_road_path") != null,
		"the stages are places of one size on a road that winds, three to a row, the boss alone at the end", nodes.map(func(n): return [n.global_position.round(), n.size]))
	ok(int(_one(realm, "map_stars").get_meta("map_stars")) == 0 and _metas(realm, "star_chest") == ["rustyard:8", "rustyard:16", "rustyard:24"] and _metas(realm, "star_chest_state") == ["locked", "locked", "locked"], "no stars yet; three star chests, locked", _metas(realm, "star_chest_state"))
	ok(_words(_one(realm, "map_region_card")).contains("The Rustyard") and _words(_one(realm, "map_region_card")).contains("Weaknesses and the guard break"), "the region's card: its name and what it teaches")
	ok(str(_one(realm, "map_spire").get_meta("map_spire")) == "locked" and _one(realm, "map_spire_fight") == null and _words(_one(realm, "section", "map_spire")).contains("The Pacer"), "the Spire is locked and says what opens it", _words(_one(realm, "section", "map_spire")))
	ok(_one(realm, "map_hunt") != null and str(_one(realm, "map_hunt").get_meta("map_hunt_state")) == "open" and _one(realm, "map_echo") == null, "the daily hunt is there; no echoes yet")
	# A locked region and a locked node say why and change nothing.
	_tap(regions[3])
	_tap(nodes[4])
	await _frames(4)
	ok(_sheets().is_empty() and _metas(_realm(), "map_stage") == want_ids, "a locked region and a locked node open nothing")

	# --- the prep sheet ---------------------------------------------------------------------------
	realm = _realm()
	_tap(_one(realm, "map_stage", "r1s1"))
	await _frames(4)
	var prep = _sheet("prep_sheet")
	ok(prep != null and str(_one(prep, "prep_sheet").get_meta("prep_sheet")) == "r1s1" and _words(prep).contains(str(RpgWorld.stage("r1s1").text)), "a tap on r1s1 opens its prep sheet with its line of story")
	if prep != null:
		ok(_metas(prep, "prep_foe") == ["dust_bunny"] and int(_one(prep, "prep_foe").get_meta("prep_unknown")) == 2 and _words(_one(prep, "prep_foe")).contains("Dust Bunny") and _words(_one(prep, "prep_foe")).contains("?"), "its foe as a tile: the name, and \"?\" for each weakness not learned", _words(_one(prep, "prep_foe")))
		ok(["comfortable", "even", "hard", "very hard"].has(str(_one(prep, "prep_power").get_meta("prep_power"))) and _words(prep).contains("Recommended") and _words(prep).contains("Your power"), "the recommended power against the hero's, with a word (%s)" % str(_one(prep, "prep_power").get_meta("prep_power")))
		ok(_with(prep, "prep_star").size() == 3 and _with(prep, "prep_star").all(func(s): return not bool(s.get_meta("prep_star_on"))) and _words(prep).contains("Win the fight"), "the three stars in words, none earned")
		ok(_one(prep, "prep_first") == null and _one(prep, "prep_fight") is Button and _one(prep, "prep_fight").size.x > 300.0 and _sheet_too_wide(prep) == "", "a big Fight key (r1s1 has no first-win reward to show); the sheet fits", _sheet_too_wide(prep))
		_tap(_one(prep, "prep_foe"))
		await _frames(3)
		var foe_sheet = _sheet("foe_sheet")
		ok(foe_sheet != null and _words(foe_sheet).contains(str(RpgFoes.words(RpgFoes.by_id("dust_bunny"))[0])) and _sheet_too_wide(foe_sheet) == "", "a tap on the foe says what it does", _words(foe_sheet) if foe_sheet != null else "")
		if foe_sheet != null:
			foe_sheet.queue_free()
		await _frames(2)
		_tap(_one(prep, "prep_fight"))
		await _frames(6)
		fights = _battles()
		ok(fights.size() == 1 and str(fights[0].B.what.id) == "r1s1" and (not is_instance_valid(prep) or prep._closing), "Fight starts the battle and the sheet goes", fights.size())
	await _shut_battles()
	await _drop_sheets()

	# --- wins written into the save -------------------------------------------------------------
	ok(_win("r1s1", today), "a win of r1s1 goes into the save")
	await _frames(12)
	realm = _realm()
	ok(str(_one(realm, "map_stage", "r1s1").get_meta("map_state")) == "done" and int(_one(realm, "map_stage", "r1s1").get_meta("map_stage_stars")) == 3 and str(_one(realm, "map_stage", "r1s2").get_meta("map_state")) == "open" and str(_one(realm, "map_stage", "r1s3").get_meta("map_state")) == "locked", "r1s1 is done with three stars, r1s2 opens, r1s3 stays locked")
	ok(int(_one(realm, "map_stars").get_meta("map_stars")) == 3, "the region counts three stars")
	_tap(_one(realm, "map_stage", "r1s1"))
	await _frames(4)
	prep = _sheet("prep_sheet")
	var learned_school = str(RpgFoes.weak_of("dust_bunny")[0])
	ok(prep != null and _one(prep, "prep_foe").get_meta("prep_weak") == [learned_school] and int(_one(prep, "prep_foe").get_meta("prep_unknown")) == 1 and _with(prep, "prep_star").all(func(s): return bool(s.get_meta("prep_star_on"))), "its prep sheet now shows the weakness learned and the stars earned")
	await _drop_sheets()
	_tap(_one(realm, "map_stage", "r1s2"))
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and _one(prep, "prep_first") != null and bool(_one(prep, "prep_first").get_meta("prep_first")) and int(_one(prep, "rpg_ore").get_meta("rpg_ore")) == int(RpgWorld.stage("r1s2").first.ore) and _with(prep, "prep_foe").size() == 2 and _sheet_too_wide(prep) == "", "r1s2's prep sheet: two foes and the first-win ore", _sheet_too_wide(prep) if prep != null else "none")
	await _drop_sheets()
	_win("r1s2", today)
	await _frames(12)
	_tap(_one(_realm(), "map_stage", "r1s2"))
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and _one(prep, "prep_first") != null and not bool(_one(prep, "prep_first").get_meta("prep_first")) and _words(prep).contains("TAKEN"), "once won, its first-win reward shows as taken")
	await _drop_sheets()
	for s in range(3, 6):
		_win("r1s%d" % s, today)
	await _frames(12)
	realm = _realm()
	rpg = app.rpg()
	ok(str(_one(realm, "map_stage", "r1s5").get_meta("map_state")) == "done" and str(_one(realm, "map_stage", "r1s6").get_meta("map_state")) == "open" and int(_one(realm, "map_stars").get_meta("map_stars")) == 15, "five wins: the cache node is open, fifteen stars")

	# --- the star chests --------------------------------------------------------------------------
	ok(_metas(realm, "star_chest_state") == ["ready", "locked", "locked"] and map_cls.something_waits(rpg) and _metas(realm, "realm_tab_dot").has("map"), "the first star chest is ready, and the Map tab has its dot", _metas(realm, "star_chest_state"))
	var chest_places = _with(realm, "star_chest").map(func(c): return c.global_position.round())
	ore0 = int(rpg.ore)
	_tap(_one(realm, "star_chest", "rustyard:16"))
	await _frames(4)
	ok(int(app.rpg().ore) == ore0 and not app.rpg().starChests.has("rustyard:16"), "a locked star chest pays nothing")
	_tap(_one(realm, "star_chest", "rustyard:8"))
	await _frames(12)
	realm = _realm()
	rpg = app.rpg()
	ok(bool(rpg.starChests.get("rustyard:8", false)) and int(rpg.ore) > ore0 and _metas(realm, "star_chest_state") == ["opened", "locked", "locked"] and not _metas(realm, "realm_tab_dot").has("map"), "the ready one opens: ore, its mark, and the dot goes", [int(rpg.ore) - ore0, _metas(realm, "star_chest_state")])
	ok(_with(realm, "star_chest").map(func(c): return c.global_position.round()) == chest_places, "the three chest keys are where they were")
	ore0 = int(rpg.ore)
	_tap(_one(realm, "star_chest", "rustyard:8"))
	await _frames(4)
	ok(int(app.rpg().ore) == ore0, "and it opens once")

	# --- the cache --------------------------------------------------------------------------------
	_tap(_one(realm, "map_stage", "r1s6"))
	await _frames(4)
	var cache = _sheet("cache_pick")
	ok(cache != null and _metas(cache, "cache_pick") == ["0", "1", "2"] and _sheet_too_wide(cache) == "" and _with(cache, "cache_pick").all(func(c): return c.size.y >= 40.0), "the cache node opens three finds as big pick keys", _metas(cache, "cache_pick") if cache != null else "")
	items0 = 0
	for k in rpg.items:
		items0 += int(rpg.items[k])
	if cache != null:
		_tap(_one(cache, "cache_pick", 2))
	await _frames(12)
	rpg = app.rpg()
	realm = _realm()
	items1 = 0
	for k in rpg.items:
		items1 += int(rpg.items[k])
	ok(bool(rpg.caches.get("r1s6", false)) and items1 > items0 and str(_one(realm, "map_stage", "r1s6").get_meta("map_state")) == "done" and str(_one(realm, "map_stage", "r1s7").get_meta("map_state")) == "open" and _sheet("cache_pick") == null, "a pick goes into the save, the cache is done, the next stage opens, the sheet goes", [items1 - items0])
	_tap(_one(realm, "map_stage", "r1s6"))
	await _frames(4)
	ok(_sheet("cache_pick") == null, "a taken cache opens nothing")

	# --- the next region, and the Spire ----------------------------------------------------------
	for s in range(7, 11):
		_win("r1s%d" % s, today)
	await _frames(12)
	realm = _realm()
	ok(_with(realm, "map_region").map(func(r): return str(r.get_meta("map_region_state"))).slice(0, 3) == ["open", "chosen", "locked"] and str(_with(realm, "map_stage")[0].get_meta("map_stage")) == "r2s1" and str(_with(realm, "map_stage")[0].get_meta("map_state")) == "open", "the boss falls: the Greenmile opens and the map moves on to it", _with(realm, "map_region").map(func(r): return str(r.get_meta("map_region_state"))))
	var region_places = _with(realm, "map_region").map(func(r): return r.global_position.round())
	_tap(_one(realm, "map_region", "rustyard"))
	await _frames(12)
	realm = _realm()
	ok(str(_with(realm, "map_stage")[0].get_meta("map_stage")) == "r1s1" and _with(realm, "map_stage").all(func(n): return str(n.get_meta("map_state")) == "done") and str(_one(realm, "map_region", "rustyard").get_meta("map_region_state")) == "chosen" and _with(realm, "map_region").map(func(r): return r.global_position.round()) == region_places, "a region key shows that region, and the keys stay put")
	_tap(_one(realm, "map_region", "greenmile"))
	await _frames(12)
	ok(str(map_cls.region_id) == "" and str(_with(_realm(), "map_stage")[0].get_meta("map_stage")) == "r2s1", "back on the furthest region the map follows the road again")
	for s in range(1, 11):
		_win("r2s%d" % s, today)
	await _frames(12)
	realm = _realm()
	rpg = app.rpg()
	ok(RpgWorld.spire_open(rpg) and str(_one(realm, "map_spire").get_meta("map_spire")) == "1" and _one(realm, "map_spire_fight") is Button and _words(_one(realm, "section", "map_spire")).contains("Floor 1"), "the second boss falls: the Spire shows Floor 1 with a Fight key", _words(_one(realm, "section", "map_spire")))
	_tap(_one(realm, "map_spire_fight"))
	await _frames(6)
	fights = _battles()
	ok(fights.size() == 1 and str(fights[0].B.what.id) == "spire:1", "its key starts floor 1", fights.size())
	await _shut_battles()
	_tap(_one(_realm(), "map_spire"))
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and str(_one(prep, "prep_sheet").get_meta("prep_sheet")) == "spire:1" and _with(prep, "prep_star").is_empty() and _sheet_too_wide(prep) == "", "and its row opens the floor's prep sheet (no stars there)")
	await _drop_sheets()

	# --- the daily hunt ---------------------------------------------------------------------------
	realm = _realm()
	var hunt = rpg_ui.stage_of({"kind": "hunt", "id": "hunt:" + today})
	var hunt_row = _one(realm, "map_hunt")
	ok(hunt is Dictionary and hunt_row != null and _words(hunt_row).contains("Daily Hunt") and _words(hunt_row).contains(str(RpgWorld.RULES[str(hunt.rule)].name)) and _words(hunt_row).contains(str(RpgDefs.SCHOOL_NAMES[str(hunt.weak[0])])) and _all(hunt_row).filter(func(n): return _is(n, "FoeView")).size() == mini(3, hunt.waves[0].size()), "the hunt's row: the pack's sprites, the rule's name, the weak schools", _words(hunt_row) if hunt_row != null else "")
	var hunt_y = hunt_row.global_position.y
	_tap(hunt_row)
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and str(_one(prep, "prep_sheet").get_meta("prep_sheet")) == "hunt:" + today and _with(prep, "prep_rule").size() == 1 and _with(prep, "prep_foe").all(func(f): return int(f.get_meta("prep_unknown")) == 0 and f.get_meta("prep_weak") == hunt.weak) and _sheet_too_wide(prep) == "", "its prep sheet: the rule, and every foe weak to today's schools")
	await _drop_sheets()
	var res_h = RpgSave.finish(app.rpg(), {"kind": "hunt", "id": str(hunt.id)}, hunt, {"xp": 5, "ore": 5}, {"win": true, "turns": 3}, today)
	ok(bool(res_h.ok), "a hunt win goes into the save", res_h.get("why", ""))
	app.set_rpg(res_h.rpg)
	await _frames(12)
	realm = _realm()
	rpg = app.rpg()
	hunt_row = _one(realm, "map_hunt")
	ok(str(hunt_row.get_meta("map_hunt_state")) == "prize" and _one(realm, "map_hunt_prize") is Button and hunt_row.global_position.y == hunt_y and _metas(realm, "realm_tab_dot").has("map"), "won with the prize to pick: a Prize key in the row, the row where it was, a dot on Map")
	_tap(_one(realm, "map_hunt_prize"))
	await _frames(4)
	var prizes = _sheet("hunt_prize")
	hunt = rpg_ui.stage_of({"kind": "hunt", "id": "hunt:" + today})
	ok(prizes != null and _metas(prizes, "hunt_prize") == ["0", "1", "2"] and _sheet_too_wide(prizes) == "", "three prizes to pick one from")
	ore0 = int(rpg.ore)
	if prizes != null:
		_tap(_one(prizes, "hunt_prize", 0))
	await _frames(12)
	rpg = app.rpg()
	realm = _realm()
	hunt_row = _one(realm, "map_hunt")
	ok(int(rpg.ore) == ore0 + int(hunt.prizes[0].ore) and not RpgLoot.hunt_prize_left(rpg, today) and str(hunt_row.get_meta("map_hunt_state")) == "won" and _one(realm, "map_hunt_prize") == null and _words(hunt_row).contains("WON") and hunt_row.global_position.y == hunt_y and _sheet("hunt_prize") == null, "the ore prize is paid once, the row says WON and has not moved", [int(rpg.ore) - ore0, hunt_row.get_meta("map_hunt_state")])
	ok(not bool(RpgSave.take_hunt_prize(rpg, today, hunt.prizes[1]).ok), "a second prize is refused")

	# --- the weekly rival (a made-up weekly record) -----------------------------------------------
	app.state["weekly"] = {"current": {"monster": "wk_bat", "week": "2026-11-23", "weakPart": "legs"}}
	realm.rebuild_now()
	await _frames(12)
	realm = _realm()
	var rival = RpgWorld.rival(app.state, rpg)
	var rival_row = _one(realm, "map_rival")
	ok(rival is Dictionary and rival_row != null and str(rival_row.get_meta("map_rival")) == "2026-11-23" and str(rival_row.get_meta("map_rival_state")) == "open" and _words(rival_row).contains("Skip-Day Bat") and _words(rival_row).contains("Legs"), "the rival's row: the week's bounty monster and what it is weak to", _words(rival_row) if rival_row != null else "")
	_tap(rival_row)
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and str(_one(prep, "prep_sheet").get_meta("prep_sheet")) == "rival:2026-11-23" and _metas(prep, "prep_foe") == ["wk_bat"] and _words(_one(prep, "prep_foe")).contains("Boss") and _sheet_too_wide(prep) == "", "its prep sheet: the monster as a boss")
	if prep != null:
		_tap(_one(prep, "prep_foe"))
		await _frames(3)
		ok(_sheet("foe_sheet") != null, "and its foe sheet opens (a foe that is not in the catalog)")
	await _drop_sheets()
	var res_r = RpgSave.finish(rpg, {"kind": "rival", "id": str(rival.id)}, rival, {"xp": 5, "ore": 5}, {"win": true, "turns": 9}, today)
	app.set_rpg(res_r.rpg)
	await _frames(12)
	realm = _realm()
	ok(bool(res_r.ok) and str(_one(realm, "map_rival").get_meta("map_rival_state")) == "won" and _words(_one(realm, "map_rival")).contains("WON"), "a rival win: the row says WON")
	app.state.erase("weekly")
	realm.rebuild_now()
	await _frames(12)
	realm = _realm()
	ok(_one(realm, "map_rival") == null and _one(realm, "map_hunt") != null, "no bounty this week: no rival row")

	# --- a kept battle ----------------------------------------------------------------------------
	ok(_one(realm, "realm_continue") == null and rpg_ui.kept_battle() == null, "no kept battle: no Continue")
	rpg = app.rpg()
	var setup = RpgWorld.setup({"kind": "stage", "id": "r1s2"}, rpg, rpg_ui.hero(), rpg_ui.pet(), 77, today)
	var B = TTUtil.normalize_json(JSON.parse_string(JSON.stringify(RpgBattle.start(setup))))
	app.draft_store("battle", {"day": today, "v": RpgDefs.VERSION, "what": {"kind": "stage", "id": "r1s2"}, "B": B})
	realm.rebuild_now()
	await _frames(12)
	realm = _realm()
	var cont = _one(realm, "realm_continue")
	ok(cont is Button and _words(_one(realm, "section", "realm_notices")).contains("Continue the battle") and _words(_one(realm, "section", "realm_notices")).contains(str(RpgWorld.stage("r1s2").name)), "a kept battle: \"Continue the battle\" with the stage's name", _words(_one(realm, "section", "realm_notices")) if _one(realm, "section", "realm_notices") != null else "")
	ok(_with(realm, "section").filter(func(c): return str(c.get_meta("section")).begins_with("realm_"))[1].get_child(0) == cont.get_parent().get_parent().get_parent().get_parent() or _words(_one(realm, "section", "realm_notices").get_child(0)).contains("Continue the battle"), "it is the first notice")
	_tap(cont)
	await _frames(6)
	fights = _battles()
	ok(fights.size() == 1 and str(fights[0].B.what.id) == "r1s2", "Continue goes on with it", fights.size())
	await _shut_battles()
	_realm().rebuild_now()
	await _frames(12)
	realm = _realm()
	ok(_one(realm, "realm_continue") == null, "the battle gone: no Continue")

	# --- the echoes (the Hollow Titan beaten, by hand) --------------------------------------------
	var far = RpgSave.copy(app.rpg())
	for r in range(1, 9):
		for s in range(1, 11):
			var sid = "r%ds%d" % [r, s]
			if s == 6:
				far.caches[sid] = true
			elif not far.stages.has(sid):
				far.stages[sid] = {"stars": [true, false, false], "wins": 1, "best": 9}
	app.set_rpg(far)
	await _frames(12)
	realm = _realm()
	ok(RpgWorld.echoes_open(far) and _one(realm, "map_echo") is Button and _with(realm, "map_region").all(func(r): return str(r.get_meta("map_region_state")) != "locked") and str(_with(realm, "map_stage")[0].get_meta("map_stage")) == "r8s1" and _too_wide() == "", "the whole road won: every region open, the last one in view, an Echoes key", _too_wide())
	_tap(_one(realm, "map_echo"))
	await _frames(12)
	realm = _realm()
	var echo_nodes = _with(realm, "map_stage")
	ok(echo_nodes.size() == 10 and str(echo_nodes[0].get_meta("map_stage")) == "e1s1" and str(echo_nodes[0].get_meta("map_state")) == "open" and str(_with(realm, "map_region")[1].get_meta("map_region_state")) == "locked" and _with(realm, "star_chest").is_empty() and _too_wide() == "", "Echoes shows the first echo region's ten stages, e1s1 open", echo_nodes.map(func(n): return str(n.get_meta("map_stage"))))
	_tap(echo_nodes[0])
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and str(_one(prep, "prep_sheet").get_meta("prep_sheet")) == "e1s1" and _with(prep, "prep_rule").size() == 1 and _sheet_too_wide(prep) == "", "an echo stage's prep sheet names its rule")
	await _drop_sheets()
	map_cls.echo = false
	map_cls.region_id = ""
	_realm().rebuild_now()
	await _frames(12)

	# =================================================================================================
	# Layout: the width, finger sizes, a rebuild
	# =================================================================================================
	realm = _realm()
	ok(_too_wide() == "" and realm.size.x <= 412.5 and realm.size.x >= 400.0, "the hub with the Map fits the column (412, less the scroll bar)", [_too_wide(), realm.size.x])
	var places = _key_places()
	realm.rebuild_now()
	await _frames(14)
	var places_after = _key_places()
	var moved = places.keys().filter(func(k): return not places_after.has(k) or places_after[k] != places[k])
	ok(places.size() >= 25 and places_after.size() == places.size() and moved.is_empty(), "a rebuild leaves every key where it was (%d keys)" % places.size(), moved)
	app.set_rpg(RpgSave.copy(app.rpg()))
	await _frames(14)
	places_after = _key_places()
	moved = places.keys().filter(func(k): return not places_after.has(k) or places_after[k] != places[k])
	ok(moved.is_empty(), "and so does a change of the Realm's save", moved)
	# A long made-up name does not widen the page.
	kit.fingers = true
	await _show_realm()
	realm = _realm()
	var small = []
	for c in _all(realm):
		if not (c is Control) or not c.is_visible_in_tree():
			continue
		var tappable = (c is BaseButton) or (_is(c, "Card") and c._tap.is_valid())
		if tappable and c.size.y < 39.5:
			small.append("%s %d" % [str(c.get_meta("anchor_id", c.get_class())), int(c.size.y)])
	ok(_too_wide() == "" and small.is_empty(), "at finger sizes: it fits, and every key is 40 high or more", [_too_wide(), small])
	for page in ["hero", "moves", "skills", "gear"]:
		_tap(_one(_realm(), "realm_tab", page))
		await _frames(12)
		if _too_wide() != "":
			small.append("%s: %s" % [page, _too_wide()])
	ok(small.is_empty(), "the other pages fit at finger sizes too", small)
	_tap(_one(_realm(), "realm_tab", "map"))
	await _frames(12)
	_tap(_one(_realm(), "map_stage", "r8s10"))
	await _frames(4)
	prep = _sheet("prep_sheet")
	ok(prep != null and _sheet_too_wide(prep) == "" and _one(prep, "prep_fight").size.y >= 40.0 and _with(prep, "prep_foe").size() >= 1, "a boss's prep sheet fits at finger sizes", _sheet_too_wide(prep) if prep != null else "none")
	await _drop_sheets()
	kit.fingers = false
	await _show_realm()

	# A Realm that was never trained for: the hub still stands.
	var bare = app.empty_saved()
	bare.settings["focus"] = ""
	bare.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	bare.rpg = RpgSave.first_open(RpgSave.empty(), {}, null)
	app.replace_all(bare)
	await _frames(4)
	await _show_realm()
	realm = _realm()
	secs = _metas(realm, "section").filter(func(s): return s.begins_with("realm_"))
	ok(secs == ["realm_tabs", "realm_banner", "realm_notices", "realm_boosts", "realm_map"] or secs == ["realm_tabs", "realm_banner", "realm_boosts", "realm_map"], "an empty log: the hub still stands", secs)
	ok(_with(realm, "realm_chest").is_empty() and _one(realm, "realm_no_boost") != null and _with(realm, "realm_boost").is_empty() and _too_wide() == "", "with no chest, and one line on what earns a boost")

	# --- after a lost fight: what would help (the empty log: no boost, nothing learned, a build of starters) ---
	var tip_stage = RpgWorld.stage("r1s10")
	var tip_setup = RpgWorld.setup({"kind": "stage", "id": "r1s10"}, rpg_ui.save(), rpg_ui.hero(), null, 5, str(app.today))
	var tip_b = RpgBattle.start(tip_setup)
	var tips = rpg_ui.tips(tip_b, tip_stage, {"guards": 0, "items": 0, "schools": []})
	ok(tips.size() >= 2 and tips.size() <= rpg_ui.TIPS_MAX and tips.all(func(t): return t is String and t.length() > 20 and not t.contains("%")), "a lost fight gets two to four tips, whole sentences", tips)
	ok(tips.any(func(t): return t.contains("weak to")) and tips.any(func(t): return t.contains("skill point") or t.contains("power") or t.contains("guard")), "among them: its weakness is still to find, and something to do about it", tips)
	var no_guard = rpg_ui.tips(tip_b, tip_stage, {"guards": 0, "items": 1, "schools": []})
	var guarded = rpg_ui.tips(tip_b, tip_stage, {"guards": 3, "items": 1, "schools": []})
	ok(no_guard.any(func(t): return t.contains("never guarded")) or no_guard.size() == rpg_ui.TIPS_MAX, "never guarding is named (when there is room for it)", no_guard)
	ok(not guarded.any(func(t): return t.contains("never guarded")), "and not when the hero did guard", guarded)

	print("RPG HUB: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
