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
	var news = _one("realm_news")
	check(news != null and _one("realm_news_ok") != null, "what is new is said once on the front page")
	await ShotHelper.snap(tree, "realm_4b_news")
	if _one("realm_news_ok") != null:
		await _click(_one("realm_news_ok"))
		await ShotHelper.wait(tree, 0.5)
		check(_one("realm_news") == null and bool(App.rpg().hints.get(RealmScreen.NEWS_ID, false)), "\"Got it\" puts it away for good")
	var onward = _one("realm_next")
	check(onward != null and str(onward.get_meta("realm_next")) == "r1s1" and _one("realm_next_go") != null, "the front page names the next place of the road, with a key to it")
	if _one("realm_next_go") != null:
		await _click(_one("realm_next_go"))
		check(_sheet() != null and ShotHelper.all_text(_sheet()).contains("The Back Door"), "its key opens that stage's prep sheet")
		await _close_sheets()
	var grew = _one("realm_gains")
	check(grew != null and _all("realm_gain", grew).size() >= 1, "the day's training shows as what it raised (%s: %d stats)" % [str(grew.get_meta("realm_gains")) if grew != null else "none", _all("realm_gain", grew).size() if grew != null else 0])
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
	# --- a stat reaches a new whole point between two visits ---------------------------------------
	var seen_rpg = App.rpg().duplicate(true)
	check(seen_rpg.get("statsSeen") is Dictionary and seen_rpg.statsSeen.size() == 12, "the Realm remembers the stats as it last showed them (%d)" % seen_rpg.get("statsSeen", {}).size())
	if seen_rpg.get("statsSeen") is Dictionary and int(seen_rpg.statsSeen.get("back", 0)) > 1:
		seen_rpg.statsSeen["back"] = int(seen_rpg.statsSeen.back) - 1
		App.set_rpg(seen_rpg)
		await ShotHelper.wait(tree, 1.6)
		var strong = _one("loot_pop", "Stronger")
		check(strong != null and _all("loot_line", strong).size() >= 2, "a stat that grew a point since the last visit gets its moment")
		await ShotHelper.snap(tree, "realm_6b_stronger")
		await _pops_off()
		check(int(App.rpg().statsSeen.back) == int(RpgUi.sheet().stats.back.v), "and is remembered at its new value")
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
		if page == "hero":
			var fs = _one("section", "realm_feats")
			var claim = _one("feat_claim")
			check(fs != null and _all("feat", fs).size() == RpgFeats.LADDERS.size() and claim != null, "the Hero page has the feats: a row per ladder, one that can be claimed")
			if fs != null and claim != null:
				ShotHelper.reveal(fs)
				await ShotHelper.frames(tree, 4)
				await ShotHelper.snap(tree, "realm_8c_feats")
				var ore_f = int(App.rpg().ore)
				var fid = str(claim.get_meta("feat_claim"))
				ShotHelper.reveal(claim)
				await ShotHelper.wait(tree, 0.5)
				await ShotHelper.click(tree, claim)
				await ShotHelper.wait(tree, 0.8)
				check(int(App.rpg().ore) > ore_f and int(App.rpg().feats.get(fid, 0)) == 1, "a tap claims a step: its ore is paid, once")
				var row_now = _one("feat", fid)
				check(row_now != null and str(row_now.get_meta("feat_state")) != "", "and its row goes on to the next step (%s)" % (str(row_now.get_meta("feat_state")) if row_now != null else "?"))
				ShotHelper.scroll_main(main, 0)
				await ShotHelper.frames(tree, 3)
			var jr = _one("section", "realm_journey")
			check(jr != null and _all("journey_num", jr).size() == 6, "the Hero page ends in the journey so far: six counts")
			if jr != null:
				ShotHelper.reveal(jr)
				await ShotHelper.frames(tree, 4)
				await ShotHelper.snap(tree, "realm_8b_journey")
				ShotHelper.scroll_main(main, 0)
				await ShotHelper.frames(tree, 3)
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
	# --- how fights work -----------------------------------------------------------------------
	var help = _one("realm_help")
	check(help != null, "the Map ends in a link to how fights work")
	if help != null:
		RealmHelp.open()
		await ShotHelper.wait(tree, 0.6)
		var hs = _sheet()
		check(hs != null and _all("help_point", hs).size() == RealmHelp.POINTS.size() and not ShotHelper.all_text(hs).contains("{"), "its sheet has every point, with the game's own numbers filled in")
		await ShotHelper.snap(tree, "realm_19_help")
		await _close_sheets()
	# --- the bestiary ------------------------------------------------------------------------
	var beast = _one("map_bestiary")
	check(beast != null and int(beast.get_meta("map_bestiary")) >= 3, "the Map ends in the bestiary: the foes met so far (%s)" % (str(beast.get_meta("map_bestiary")) if beast != null else "none"))
	if beast != null:
		ShotHelper.reveal(beast)
		await ShotHelper.frames(tree, 3)
		RealmBestiary.open()
		await ShotHelper.wait(tree, 0.6)
		var bs = _sheet()
		var tiles = _all("bestiary_foe", bs) if bs != null else []
		check(bs != null and tiles.size() == RpgFoes.all().size() and tiles.any(func(t): return bool(t.get_meta("bestiary_met"))) and tiles.any(func(t): return not bool(t.get_meta("bestiary_met"))),
			"its sheet has a tile for every foe: the ones met as they are, the rest as dark shapes (%d)" % tiles.size())
		await ShotHelper.snap(tree, "realm_18_bestiary")
		await _close_sheets()
	if hunt != null and is_instance_valid(_one("map_hunt")):
		await _click(_one("map_hunt"))
		check(_sheet() != null and _one("prep_rule", null, _sheet()) != null, "the hunt's prep sheet names the day's rule")
		await ShotHelper.snap(tree, "realm_17_hunt_prep")
		await _close_sheets()

	App.go("home")
	await ShotHelper.wait(tree, 0.4)
	print("REALM %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
