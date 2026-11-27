extends RefCounted
## The Realm tab's hub and its Map page (run with the "year" data): the first
## visit's count-up, the hub (banner, a training chest, boosts, sub-tabs), the
## Map (hunt, the road's ten nodes, the Spire), a stage's prep sheet, a foe's
## sheet, the cache. Prints CHECK lines; every snap is also a width check.

var main: Node
var tree: SceneTree
var fails = 0


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s  %s" % ["ok  " if cond else "FAIL", what])


func _all(meta: String, root = null) -> Array:
	var out = []
	for n in ShotHelper.walk(main if root == null else root):
		if n.has_meta(meta) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _one(meta: String, value = null, root = null):
	for n in _all(meta, root):
		if value == null or str(n.get_meta(meta)) == str(value):
			return n
	return null


func _sheet():
	var top = null
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing and not c.is_queued_for_deletion():
			top = c
	return top


func _close_sheets() -> void:
	for c in Kit.overlay_root.get_children():
		if c is Sheet and not c._closing:
			c.close()
	await ShotHelper.wait(tree, 0.5)


func _battle():
	for c in Kit.overlay_root.get_children():
		if c is BattleView and not c.is_queued_for_deletion():
			return c
	return null


## Bring a control into view and click it for real.
## A loot pop takes every tap while it is up: off with it before the walkthrough goes on.
func _pops_off() -> void:
	LootPop.close_all()
	await ShotHelper.frames(tree, 3)


func _click(c) -> void:
	if c == null or not is_instance_valid(c):
		return
	ShotHelper.reveal(c)
	await ShotHelper.frames(tree, 4)
	await ShotHelper.click(tree, c)
	# (A rebuild that had to move the key drops presses for a moment.)
	await ShotHelper.wait(tree, 0.6)


## A made-up win of a road stage, written into the Realm's save.
func _win(stage_id: String) -> void:
	var st = RpgWorld.stage(stage_id)
	var rpg = App.rpg()
	var foe = str(st.waves[0][0].foe)
	var summary = {"win": true, "turns": 2, "breaks": 9, "items": 0, "hp_share": 1.0, "guards": 0, "schools": ["push", "pull", "legs"], "worst_share": 0.0,
		"learned": {foe: [RpgFoes.weak_of(foe)[0]]}}
	var res = RpgSave.finish(rpg, {"kind": "stage", "id": stage_id}, st, {"xp": 25, "ore": 12}, summary, App.today)
	if bool(res.ok):
		App.set_rpg(res.rpg)


func run(p_main: Node, p_tree: SceneTree) -> void:
	main = p_main
	tree = p_tree
	await ShotHelper.wait(tree, 1.0)
	# A lift today and pages today, so a training chest and a boost are sure to be there.
	var saved = App.saved.duplicate(true)
	var sets = []
	for i in range(4):
		sets.append({"reps": 6, "weightKg": 70.0})
	saved.sessions.append({"id": "realm_shot", "discipline": "lift", "date": App.today, "createdAt": 1900000000000, "source": "manual", "durationSec": 3000,
		"exercises": [{"name": "Bench Press - Barbell", "sets": sets}, {"name": "Squat - Barbell", "sets": sets}]})
	saved.reading = [{"id": "realm_read", "date": App.today, "pages": 12, "createdAt": 1900000100000}]
	saved.rpg = RpgSave.empty()
	App.replace_all(saved)
	App.draft_store("battle", null)
	await ShotHelper.wait(tree, 0.5)

	# --- the first visit ------------------------------------------------------------------------
	RealmScreen.first_reset()
	App.go("realm")
	await ShotHelper.wait(tree, 1.3)
	check(_all("section").map(func(n): return str(n.get_meta("section"))).has("realm_first") and _all("first_stat").size() == 12, "a Realm never opened shows the first visit: twelve stats")
	check(not RealmScreen.count_done(), "the count-up is running")
	await ShotHelper.snap(tree, "realm_1_first_counting")
	await ShotHelper.wait(tree, 4.2)
	var vals = _all("first_value")
	check(RealmScreen.count_done() and vals.all(func(v): return str(v.text) == str(int(v.get_meta("first_value")))), "after about four seconds every number is there")
	check(_one("first_enter") != null and _one("first_skip") != null and _one("first_points") != null, "the skill points line, Enter the Ironwild, Skip")
	await ShotHelper.snap(tree, "realm_2_first_done")
	await _click(_one("first_enter"))
	await ShotHelper.wait(tree, 1.2)
	var bv = _battle()
	check(bool(App.rpg().opened) and bv != null, "Enter opens the Realm and starts the first fight")
	await ShotHelper.snap(tree, "realm_3_first_fight")
	if bv != null:
		bv.close()
	App.draft_store("battle", null)
	await ShotHelper.wait(tree, 0.8)

	# --- the hub --------------------------------------------------------------------------------
	ShotHelper.scroll_main(main, 0)
	await ShotHelper.wait(tree, 0.4)
	var secs = _all("section").map(func(n): return str(n.get_meta("section"))).filter(func(s): return s.begins_with("realm_"))
	check(secs == ["realm_tabs", "realm_banner", "realm_notices", "realm_boosts", "realm_map"], "the hub: sub-tabs, banner, notices, boosts, the Map (%s)" % str(secs))
	check(_one("realm_hero") != null and _one("realm_level") != null and _one("realm_power") != null and _one("realm_points") != null, "the banner: the hero, the level, the power, the skill points")
	check(_all("realm_boost").size() >= 1, "today's boosts (%d)" % _all("realm_boost").size())
	check(_all("tab_dot").size() == 1, "the tab has its dot: a chest waits")
	await ShotHelper.snap(tree, "realm_4_hub")
	var open_key = _one("realm_chest_open", App.today)
	var ore0 = int(App.rpg().ore)
	check(open_key != null, "a training chest for today with an Open key")
	if open_key != null:
		var mid_y = open_key.get_global_rect().get_center().y
		await ShotHelper.click(tree, open_key)
		await ShotHelper.wait(tree, 0.25)
		await ShotHelper.snap(tree, "realm_5_chest_opening")
		await ShotHelper.wait(tree, 1.6)
		check(_all("loot_pop").size() == 1 and _all("loot_line").size() >= 1, "the chest opens over the whole screen and says what was in it")
		await ShotHelper.snap(tree, "realm_5b_chest_open")
		await _pops_off()
		var row = _one("realm_chest", App.today)
		check(int(App.rpg().ore) > ore0 and row != null and str(row.get_meta("realm_chest_state")) == "opened", "opening it pays ore; its row stays and says what came out")
		check(row != null and absf(row.get_global_rect().get_center().y - mid_y) < 12.0, "and its row is where the key was: nothing jumped")
	await ShotHelper.snap(tree, "realm_6_chest_opened")
	var boost = _all("realm_boost")
	if not boost.is_empty():
		await _click(boost[0])
		check(_sheet() != null and ShotHelper.all_text(_sheet()).contains("WHERE IT CAME FROM"), "a tap on a boost says where it came from")
		await ShotHelper.snap(tree, "realm_7_boost_sheet")
		await _close_sheets()

	# --- the sub-tabs ---------------------------------------------------------------------------
	for page in ["hero", "moves", "skills", "gear"]:
		await _click(_one("realm_tab", page))
		check(str(RpgUi.page) == page and _one("section", "realm_" + page) != null, "the %s page opens" % page.capitalize())
		await ShotHelper.snap(tree, "realm_8_page_%s" % page)
	await _click(_one("realm_tab", "map"))

	# --- the Map --------------------------------------------------------------------------------
	var hunt = _one("map_hunt")
	if hunt != null:
		ShotHelper.reveal(hunt)
	await ShotHelper.wait(tree, 0.5)
	check(hunt != null and _all("map_region").size() == 8 and _all("map_stage").size() == 10, "the Map: the daily hunt, eight regions, ten stage nodes")
	check(str(_one("map_stage", "r1s1").get_meta("map_state")) == "open" and str(_one("map_stage", "r1s2").get_meta("map_state")) == "locked", "r1s1 is open, r1s2 locked")
	await ShotHelper.snap(tree, "realm_9_map_top")
	var node = _one("map_stage", "r1s5")
	if node != null:
		ShotHelper.reveal(node)
	await ShotHelper.wait(tree, 0.5)
	await ShotHelper.snap(tree, "realm_10_map_road")
	var spire = _one("map_spire")
	if spire != null:
		ShotHelper.reveal(spire)
	await ShotHelper.wait(tree, 0.5)
	check(spire != null and str(spire.get_meta("map_spire")) == "locked", "the Spire is locked and says what opens it")
	await ShotHelper.snap(tree, "realm_11_map_spire")

	# --- the prep sheet -------------------------------------------------------------------------
	await _click(_one("map_stage", "r1s1"))
	var prep = _sheet()
	check(prep != null and _one("prep_foe", "dust_bunny", prep) != null and _one("prep_fight", null, prep) != null and _one("prep_power", null, prep) != null, "a tap on r1s1 opens its prep sheet: the foe, the power, Fight")
	await ShotHelper.snap(tree, "realm_12_prep")
	if prep != null:
		await ShotHelper.click(tree, _one("prep_foe", "dust_bunny", prep))
		await ShotHelper.wait(tree, 0.7)
		check(_one("foe_sheet", "dust_bunny", Kit.overlay_root) != null, "a tap on the foe says what it does")
		await ShotHelper.snap(tree, "realm_13_foe_sheet")
	await _close_sheets()

	# --- a few wins: stars, a star chest, the cache -----------------------------------------------
	for s in range(1, 6):
		_win("r1s%d" % s)
	await ShotHelper.wait(tree, 0.8)
	node = _one("map_stage", "r1s1")
	if node != null:
		ShotHelper.reveal(node)
	await ShotHelper.wait(tree, 0.5)
	check(str(_one("map_stage", "r1s5").get_meta("map_state")) == "done" and str(_one("map_stage", "r1s6").get_meta("map_state")) == "open" and str(_one("star_chest", "rustyard:8").get_meta("star_chest_state")) == "ready", "five wins: stars on the nodes, the cache open, the first star chest ready")
	await ShotHelper.snap(tree, "realm_14_map_after_wins")
	await _click(_one("star_chest", "rustyard:8"))
	await ShotHelper.wait(tree, 0.8)
	check(bool(App.rpg().starChests.get("rustyard:8", false)), "the star chest opens")
	await _pops_off()
	await _click(_one("map_stage", "r1s6"))
	var cache = _sheet()
	check(cache != null and _all("cache_pick", cache).size() == 3, "the cache node: three finds to pick one from")
	await ShotHelper.snap(tree, "realm_15_cache")
	if cache != null and _one("cache_pick", 2, cache) != null:
		await ShotHelper.click(tree, _one("cache_pick", 2, cache))
		await ShotHelper.wait(tree, 1.0)
		await _pops_off()
	check(bool(App.rpg().caches.get("r1s6", false)) and str(_one("map_stage", "r1s7").get_meta("map_state")) == "open", "a pick is taken and the next stage opens")
	await _close_sheets()
	await _click(_one("map_stage", "r1s2"))
	prep = _sheet()
	check(prep != null and _all("prep_star", prep).all(func(s): return bool(s.get_meta("prep_star_on"))), "a won stage's prep sheet shows its stars earned and what was learned of its foes")
	await ShotHelper.snap(tree, "realm_16_prep_won")
	await _close_sheets()
	if hunt != null and is_instance_valid(_one("map_hunt")):
		await _click(_one("map_hunt"))
		check(_sheet() != null and _one("prep_rule", null, _sheet()) != null, "the hunt's prep sheet names the day's rule")
		await ShotHelper.snap(tree, "realm_17_hunt_prep")
		await _close_sheets()

	App.go("home")
	await ShotHelper.wait(tree, 0.4)
	print("REALM %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
