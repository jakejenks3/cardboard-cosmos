extends SceneTree
## Unit test for the shell of the Realm (RPG_PLAN.md 11.6 and 11.2): the only
## changes the RPG makes to the main game.
##   - the campaign is off the screens (Campaign.ON_SCREEN false) while its
##     rules still run: no boss row, no boss card, no boss words; the campaign's
##     own goals are left out of "Almost there" and worded as a campaign reward;
##   - the Realm's colours (Pal.PUSH, PULL, LEGS, GRIT, REALM);
##   - App keeps `saved.rpg` (a save, a backup, set_rpg without `changed`, the
##     battle draft cleared with the others);
##   - the sixth tab, with the Log key exactly where five tabs had it.
## It builds the real shell (main.tscn) headless. Made-up data.
## The screens' classes name the App autoload, which is only there a frame after
## the start, so this script never names one of them (HomeScreen, ShotHelper...):
## naming one would compile it with this script, before App exists. They are
## loaded by path once App is up (`_S`) and told apart by `_is`.
##   godot --headless --path . --script res://tests/rpg_shell_test.gd
## TINY_TITAN_DATA must point at a throwaway folder: the test replaces the
## whole save, so it refuses to run without it.
## Prints RPG SHELL: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## Every node under `n` (itself too), shown or not.
func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


## Everything a player could read under `n`: the text of labels, keys and text
## boxes, and every tooltip.
func _words(n: Node) -> Array:
	var out = []
	for c in _all(n):
		if c is Label or c is Button or c is LineEdit:
			if str(c.text) != "":
				out.append(str(c.text))
		elif c is RichTextLabel:
			out.append(c.get_parsed_text())
		if c is Control and str(c.tooltip_text) != "":
			out.append(str(c.tooltip_text))
	return out


## The words under `n` that name a campaign boss (or say "boss" at all).
func _boss_words(n: Node) -> Array:
	var names = ["Echo of Doubt", "CAMPAIGN BOSS"]
	for b in Campaign.bosses():
		names.append(str(b.name))
	var hits = []
	for w in _words(n):
		for nm in names:
			if w.contains(nm):
				hits.append(w)
		if w.to_lower().contains("boss"):
			hits.append(w)
	return hits


## The script of a screen class, by path (see the top of this file).
func _S(path: String):
	return load(path)


## Is `n` an instance of the script class called `class_id` (or of one that extends it)?
func _is(n, class_id: String) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var sc = n.get_script()
	while sc != null:
		if str(sc.get_global_name()) == class_id:
			return true
		sc = sc.get_base_script()
	return false


## What is wrong with the width of the page `main` shows ("" = it fits): the
## walkthroughs' own layout check (ShotHelper.snap), on the shell's column.
func _too_wide(main: Node) -> String:
	var sc = main._scroll
	if sc.get_global_rect().end.x > 440.5:
		return "the column ends at %d" % int(sc.get_global_rect().end.x)
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar) and c.get_combined_minimum_size().x > sc.size.x + 0.5:
			return "the page needs %d of %d" % [int(c.get_combined_minimum_size().x), int(sc.size.x)]
	return ""


func _with_meta(n: Node, key: String) -> Array:
	return _all(n).filter(func(c): return c.has_meta(key))


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


## WCAG contrast of two colours.
func _contrast(a: Color, b: Color) -> float:
	var la = a.srgb_to_linear().get_luminance()
	var lb = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## A made-up lift session on `date`.
func _lift(id: String, date: String, kg: float, at: int) -> Dictionary:
	var sets = []
	for i in range(4):
		sets.append({"reps": 6, "weightKg": kg})
	return {"id": id, "discipline": "lift", "date": date, "createdAt": at, "source": "manual", "durationSec": 3000,
		"exercises": [{"name": "Bench Press - Barbell", "sets": sets}, {"name": "Squat - Barbell", "sets": sets}]}


## A made-up Realm save that differs from the empty one in every part.
func _rpg() -> Dictionary:
	var r = RpgSave.empty()
	r.opened = true
	r.xp = 345
	r.ore = 120
	r.nodes = {"push:one_two": true, "legs:leg_drive": true}
	r.builds[1].name = "Leg day"
	r.builds[1].moves = ["stomp", "lunge_strike", "", "deep_breath", ""]
	r.builds[1].ult = "quake_drop"
	r.builds[1].passives = ["leg_drive", "", ""]
	r.builds[1].gear = {"body": "tee_grey", "feet": "trainers_worn"}
	r.builds[1].pet = "slime"
	r.builds[1].belt = ["protein_shake", "", ""]
	r.build = 1
	r.plus = {"tee_grey": 2}
	r.runes = [{"id": "rn1", "k": "atk_push", "v": 1.5, "rarity": "rare"}]
	r.socket = {"tee_grey": "rn1"}
	r.relics = {"rl_made_up": true}
	r.scrolls = {"made_up_move": true}
	r.items = {"protein_shake": 2}
	r.stages = {"r1s1": {"stars": [true, false, true], "wins": 2, "best": 4}}
	r.starChests = {"rustyard:8": true}
	r.caches = {"r1s6": true}
	r.seen = {"dust_bunny": ["push", "legs"]}
	r.chests = {"2026-11-24": 2}
	r.hunt = {"date": "2026-11-24", "won": true}
	r.rival = {"week": "2026-11-23", "won": false}
	r.spire = {"best": 3}
	return r


func _same(a, b) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _init() -> void:
	_run()


func _run() -> void:
	# --- the campaign's switch and its goal keys (pure) -----------------------------------------
	ok(Campaign.ON_SCREEN == false, "the campaign is off the screens")
	var trophy_keys = ["a:boss_first", "a:zone_1", "a:zone_2", "a:zone_3", "a:zone_4", "a:zone_5", "a:zone_6", "a:damage_100k"]
	var item_keys = ["i:comfy_slippers", "i:golem_bracers", "i:wyvern_chalk_bag", "i:wallbreaker_visor", "i:chainring_shield", "i:titans_laurel"]
	ok(trophy_keys.all(func(k): return Campaign.is_goal_key(k)), "the eight campaign trophies are campaign goals", trophy_keys.filter(func(k): return not Campaign.is_goal_key(k)))
	ok(item_keys.all(func(k): return Campaign.is_goal_key(k)), "the six pieces of boss gear are campaign goals", item_keys.filter(func(k): return not Campaign.is_goal_key(k)))
	ok(Campaign.is_goal_key("p:golemling"), "Pebble the golemling is a campaign goal")
	var others = ["a:bounty_1", "a:bounty_crush_10", "a:hero_75", "i:tee_grey", "i:flame_aura", "i:bounty_cape", "p:slime", "p:owl", "stage", "r:lift",
		"boss_first", "golemling", "x:boss_first", "a:", "", "i:golemling", "p:boss_first", "a:golem_bracers"]
	ok(others.all(func(k): return not Campaign.is_goal_key(k)) and not Campaign.is_goal_key(null) and not Campaign.is_goal_key(5) and not Campaign.is_goal_key({"key": "a:boss_first"}),
		"nothing else is: bounty trophies, other gear and pets, a stage, a rank, a bare id, a key of the wrong kind, not a string", others.filter(func(k): return Campaign.is_goal_key(k)))
	# The lists agree with the catalogs they speak of.
	var group = Achievements.all().filter(func(a): return str(a.group) == "campaign" and not str(a.id).begins_with("bounty_")).map(func(a): return "a:%s" % str(a.id))
	group.sort()
	var want_trophies = trophy_keys.duplicate()
	want_trophies.sort()
	ok(group == want_trophies, "every trophy of the campaign's group that is not a bounty's is on the list", group)
	var boss_gear = Items.all().filter(func(it): return str(it.unlock.kind) == "unlock" and str(Items.unlock_hint(it)).begins_with("Defeat ")).map(func(it): return "i:%s" % str(it.id))
	boss_gear.sort()
	var want_gear = item_keys.duplicate()
	want_gear.sort()
	ok(boss_gear == want_gear, "every item whose hint is \"Defeat ...\" is one of the six", boss_gear)
	var boss_pets = Pets.all().filter(func(p): return str(p.hint).to_lower().contains("boss")).map(func(p): return "p:%s" % str(p.id))
	ok(boss_pets == ["p:golemling"], "the only companion whose hint names bosses is the golemling", boss_pets)
	ok(Campaign.hint_on_screen("Defeat Iron Golem", "i:golem_bracers") == Campaign.RESTING and Campaign.RESTING == "A campaign reward (the campaign is resting)", "an unearned campaign reward says it is one", Campaign.hint_on_screen("Defeat Iron Golem", "i:golem_bracers"))
	ok(Campaign.hint_on_screen("Keep an 8-week streak", "i:flame_aura") == "Keep an 8-week streak" and Campaign.hint_on_screen("Win a weekly bounty.", "a:bounty_1") == "Win a weekly bounty.", "any other hint keeps its words")
	ok(Campaign.bosses().size() == 24 and Campaign.boss_at(0).id == "snooze_button" and Campaign.boss_at(24).id == "echo_1" and Campaign.WEAK_MULT == 1.5, "the catalog itself is as it was")

	# --- the Realm's colours (pure) ----------------------------------------------------------------
	var fresh = {"PUSH": Pal.PUSH, "PULL": Pal.PULL, "LEGS": Pal.LEGS, "GRIT": Pal.GRIT, "REALM": Pal.REALM}
	var fixed = {"LIFT": Pal.LIFT, "CLIMB": Pal.CLIMB, "RUN": Pal.RUN, "RIDE": Pal.RIDE, "MISC": Pal.MISC, "READ": Pal.READ, "PT": Pal.PT, "BOUNTY": Pal.BOUNTY, "GOOD": Pal.GOOD, "DANGER": Pal.DANGER}
	var low = []
	for id in Pal.THEME_ORDER:
		for key in ["panel", "panel2"]:
			for n in fresh:
				var c = _contrast(fresh[n], Color(Pal.THEMES[id][key]))
				if c < 3.0:
					low.append("%s on %s.%s %.2f" % [n, id, key, c])
	ok(low.is_empty(), "each of the five is 3:1 or more against the panel and the lighter panel of all four themes", low)
	# Far apart in plain RGB too (a coarse check; the careful one was made when they were picked).
	var close = []
	var every = fixed.duplicate()
	every.merge(fresh)
	for a in fresh:
		for b in every:
			if a != b:
				var d = Vector3(fresh[a].r - every[b].r, fresh[a].g - every[b].g, fresh[a].b - every[b].b).length()
				if d < 0.18:
					close.append("%s-%s %.2f" % [a, b, d])
	ok(close.is_empty(), "none of the five sits on another colour or on one of the ten fixed ones", close)
	var before_theme = Pal.theme_id
	Pal.apply("ember")
	ok(Pal.PUSH == fresh.PUSH and Pal.PULL == fresh.PULL and Pal.LEGS == fresh.LEGS and Pal.GRIT == fresh.GRIT and Pal.REALM == fresh.REALM, "they are the same in every theme")
	Pal.apply(before_theme)
	ok(Pal.TAB_ACCENT.has("realm") and Pal.tab("realm") == Pal.REALM and Pal.TAB_ACCENT.size() == 6, "the Realm tab's accent is the Realm's colour; six tabs have one", Pal.TAB_ACCENT.keys())

	# --- the Realm's save (pure) -----------------------------------------------------------------------
	var rpg = _rpg()
	ok(_same(RpgSave.parse(rpg), rpg) and not _same(rpg, RpgSave.empty()), "the made-up Realm save is a clean one, and not the empty one")

	# Everything below needs the App autoload: it is there a frame after the start.
	await process_frame
	var app = root.get_node_or_null("App")
	if app == null:
		print("FAIL  no App autoload")
		print("RPG SHELL: %d/%d passed" % [passed, total + 1])
		quit(1)
		return
	if not app.is_test_data():
		# The test replaces the whole save: never against the player's own.
		print("REFUSED: set TINY_TITAN_DATA to a throwaway folder first.")
		print("RPG SHELL: %d/%d passed" % [passed, total + 1])
		quit(1)
		return

	# --- a save keeps the Realm's progress ---------------------------------------------------------
	ok(_same(app.empty_saved().rpg, RpgSave.empty()), "a new save starts with an empty Realm")
	var old = app.parse_saved({"sessions": [], "todos": []})
	ok(old != null and _same(old.rpg, RpgSave.empty()), "a save from before the Realm gets an empty one", old.rpg if old != null else null)
	ok(_same(app.parse_saved({"sessions": [], "rpg": "nonsense"}).rpg, RpgSave.empty()) and _same(app.parse_saved({"sessions": [], "rpg": [1, 2]}).rpg, RpgSave.empty()), "and so does one whose rpg block is not a dictionary")
	var as_file = JSON.parse_string(JSON.stringify({"sessions": [_lift("s1", "2026-11-20", 60.0, 1000)], "rpg": rpg}))
	var kept = app.parse_saved(as_file)
	ok(kept != null and _same(kept.rpg, rpg), "a save with a Realm block keeps it through parse_saved", kept.rpg if kept != null else null)
	ok(kept != null and kept.rpg.xp is int and int(kept.rpg.xp) == 345 and int(kept.rpg.ore) == 120 and kept.rpg.opened == true and int(kept.rpg.build) == 1 and str(kept.rpg.builds[1].name) == "Leg day" and kept.rpg.stages.r1s1.stars == [true, false, true]
		and kept.rpg.seen.dust_bunny == ["push", "legs"] and int(kept.rpg.chests["2026-11-24"]) == 2 and int(kept.rpg.spire.best) == 3 and str(kept.rpg.socket.tee_grey) == "rn1", "its numbers come back as whole numbers and its lists as they were")
	ok(kept != null and kept.rpg.xp is int and kept.rpg.stages.r1s1.wins is int and kept.rpg.plus.tee_grey is int and kept.rpg.runes[0].v is float, "ints stay ints after the trip through JSON")
	var clean = app.parse_saved(JSON.parse_string(JSON.stringify(kept)))
	ok(clean != null and _same(clean.rpg, rpg), "and a second trip changes nothing")

	# --- the commands ----------------------------------------------------------------------------------
	var today = str(app.today)
	var start = app.empty_saved()
	start.settings["focus"] = ""
	start.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	start.sessions = [_lift("s1", Dates.add_days(today, -3), 60.0, 1000), _lift("s2", Dates.add_days(today, -1), 62.5, 2000)]
	app.replace_all(start)
	ok(_same(app.rpg(), RpgSave.empty()), "App.rpg() of a save without progress is the empty one")
	var counts = {"changed": 0, "rpg": 0}
	var on_changed = func(): counts.changed += 1
	var on_rpg = func(): counts.rpg += 1
	app.changed.connect(on_changed)
	app.rpg_changed.connect(on_rpg)
	var state_before = app.state
	var plan_before = app.plan()
	var xp_before = int(app.state.xp.hero)
	var stamp_before = int(app.saved.updatedAt)
	app.saved.updatedAt = 5
	app.set_rpg(RpgSave.copy(rpg))
	ok(counts.rpg == 1 and counts.changed == 0, "set_rpg says rpg_changed once and never `changed`", counts)
	ok(_same(app.rpg(), rpg) and _same(app.saved.rpg, rpg), "it stores what it was given")
	ok(int(app.saved.updatedAt) > 5 and int(app.saved.updatedAt) >= stamp_before, "it stamps the save", app.saved.updatedAt)
	ok(is_same(app.state, state_before) and is_same(app.plan(), plan_before) and int(app.state.xp.hero) == xp_before, "the hero was not worked out again: the state and the day's plan are the very same objects")
	var on_disk = app.parse_saved(JSON.parse_string(FileAccess.get_file_as_string(app.SAVE_PATH)))
	ok(on_disk != null and _same(on_disk.rpg, rpg) and on_disk.sessions.size() == 2, "it is written to the save file at once", on_disk.rpg if on_disk != null else null)
	# The rules are given nothing of it: the hero of a save with a Realm block is the hero without.
	var with_block = Derive.derive({"sessions": app.saved.sessions, "claims": [], "body": [], "purchases": [], "reading": [], "weeklyGoal": app.saved.settings.weeklyGoal, "today": today})
	ok(int(with_block.xp.hero) == xp_before and not app.state.has("rpg"), "no rule reads it: the same hero XP, and the derived state has no rpg")

	# A backup file carries it, and a restore brings it back.
	var path = str(app.DATA_DIR) + "rpg-shell-backup.json"
	ok(app.export_backup(path, false) == "" and FileAccess.file_exists(path), "a backup file is written into the test's own folder", path)
	var back = app.read_backup(path)
	ok(back.ok and _same(back.data.rpg, rpg) and int(back.sessions) == 2, "read_backup finds the Realm's progress in it", back.get("error", ""))
	app.set_rpg(RpgSave.empty())
	app.draft_store("battle", {"day": today, "v": RpgDefs.VERSION, "what": {"kind": "stage", "id": "r1s1"}, "B": {"rng": 7}})
	ok(app.draft_load("battle") != null and FileAccess.file_exists(str(app.DATA_DIR) + "draft-battle.json"), "a battle left half way is kept like a workout's draft")
	if back.ok:
		app.apply_backup(back)
	ok(_same(app.rpg(), rpg) and app.sessions().size() == 2, "restoring the backup brings the Realm's progress back", app.rpg())
	ok(app.draft_load("battle") == null and not FileAccess.file_exists(str(app.DATA_DIR) + "draft-battle.json"), "and drops the kept battle (it belonged to the save that was replaced)")
	DirAccess.remove_absolute(path)

	# Reset: the battle draft goes with the workout drafts, the Realm starts over.
	app.draft_store("battle", {"day": today, "v": RpgDefs.VERSION, "B": {}})
	app.draft_store("lift", {"day": today, "exercises": []})
	app.reset_all()
	ok(app.draft_load("battle") == null and app.draft_load("lift") == null and not FileAccess.file_exists(str(app.DATA_DIR) + "draft-battle.json"), "reset_all clears the battle draft with the others")
	ok(_same(app.rpg(), RpgSave.empty()) and app.sessions().is_empty() and app.tab == "home", "and the Realm is empty again")
	counts.changed = 0
	counts.rpg = 0

	# --- Almost there skips the campaign's goals -------------------------------------------------
	var few = app.empty_saved()
	few.settings["focus"] = ""
	few.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	few.sessions = [_lift("s1", Dates.add_days(today, -9), 60.0, 1000), _lift("s2", Dates.add_days(today, -6), 62.5, 2000), _lift("s3", Dates.add_days(today, -2), 65.0, 3000)]
	app.replace_all(few)
	var raw = NextUp.next_goals(app.state, 100000)
	var raw_campaign = raw.filter(func(g): return Campaign.is_goal_key(g.key)).map(func(g): return str(g.key))
	ok(not raw_campaign.is_empty() and int(app.state.campaign.totalDamage) > 0, "the rules still run the campaign: damage is dealt and its goals are among the nearest (%d of them)" % raw_campaign.size(), raw.map(func(g): return str(g.key)))
	var shown = app.next_goals(100000)
	ok(shown.filter(func(g): return Campaign.is_goal_key(g.key)).is_empty(), "App.next_goals leaves every campaign goal out", shown.map(func(g): return str(g.key)))
	var want_keys = raw.filter(func(g): return not Campaign.is_goal_key(g.key) and not (g.get("discipline") != null and Misc.SIDE.has(str(g.discipline)))).map(func(g): return str(g.key))
	ok(shown.map(func(g): return str(g.key)) == want_keys and not want_keys.is_empty(), "and keeps the others, in the rules' order", [shown.map(func(g): return str(g.key)), want_keys])
	ok(app.next_goals(2).size() == mini(2, want_keys.size()) and app.next_goals(2).map(func(g): return str(g.key)) == want_keys.slice(0, 2), "the limit counts what is shown, not what was skipped")

	# --- the hint of an unearned campaign reward, where the screens say it ------------------------
	var armory_detail = _S("res://ui/screens/armory_detail.gd")
	var adventure_cls = _S("res://ui/screens/adventure.gd")
	var journey_cls = _S("res://ui/screens/journey.gd")
	var recap_sheet = _S("res://ui/screens/recap_sheet.gd")
	var results_cls = _S("res://ui/screens/results.gd")
	var shots = _S("res://tests/shot_helper.gd")
	var golem = Items.by_id("golem_bracers")
	var aura = Items.by_id("flame_aura")
	var pebble = Pets.by_id("golemling")
	var owl = Pets.by_id("owl")
	ok(armory_detail.item_hint(golem) == Campaign.RESTING and armory_detail.item_hint(aura) == Items.unlock_hint(aura), "the Armory: boss gear not owned is a campaign reward, other gear keeps its hint", [armory_detail.item_hint(golem), armory_detail.item_hint(aura)])
	ok(armory_detail.pet_hint(pebble) == Campaign.RESTING and armory_detail.pet_hint(owl) == str(owl.hint), "the Armory: so is Pebble; another companion keeps its hint")
	var last_trophy = Achievements.by_id("zone_6")
	var bounty_trophy = Achievements.by_id("bounty_1")
	ok(adventure_cls.trophy_words(last_trophy, false) == Campaign.RESTING and adventure_cls.trophy_words(last_trophy, true).contains("The Old You"), "the cabinet: a campaign trophy not earned is a campaign reward, an earned one keeps its words", adventure_cls.trophy_words(last_trophy, false))
	ok(adventure_cls.trophy_words(bounty_trophy, false) == "Win a weekly bounty.", "the cabinet: a bounty trophy keeps its words", adventure_cls.trophy_words(bounty_trophy, false))

	# --- the Story page and the recap (a year of made-up training) ------------------------------------
	var year = shots.demo_saved("year")
	year.profile = {"name": "Robin", "skin": 1, "hairStyle": 1, "hairColor": 0, "createdAt": 1}
	app.replace_all(year)
	var st = app.state
	var boss_moments = st.chronicle.filter(func(e): return str(e.kind) == "boss")
	ok(boss_moments.size() >= 3 and st.campaign.defeated.size() == boss_moments.size(), "a year of training: the rules have beaten bosses (%d)" % boss_moments.size())
	var story = journey_cls.story(st)
	ok(story.filter(func(e): return str(e.kind) == "boss").is_empty() and story.size() == st.chronicle.size() - boss_moments.size() + Bounty.chronicle(st).size(), "the Story leaves the boss moments out and keeps every other one, bounty wins among them", [story.size(), st.chronicle.size(), boss_moments.size()])
	ok(str(story[0].kind) == str(st.chronicle[0].kind) and str(story[0].date) == str(st.chronicle[0].date), "it still begins where the log began")
	var chips = journey_cls.chronicle_filters()
	var chip = chips.filter(func(f): return str(f.id) == "boss")
	ok(chips.size() == journey_cls.CHRONICLE_FILTERS.size() and chip.size() == 1 and str(chip[0].label) == "Bounties" and chip[0].kinds == ["bounty"] and chips.filter(func(f): return str(f.label) == "Bosses").is_empty(), "its \"Bosses\" chip is \"Bounties\", bounty wins only", chips.map(func(f): return str(f.label)))
	var facts = FunFacts.fun_facts(st)
	ok(facts.filter(func(f): return str(f.detail).contains("bosses")).size() == 1, "the rules still have the damage fact (the Stats page leaves it out)")
	var boss_day = str(st.campaign.defeated[st.campaign.defeated.keys()[0]].at)
	var r = Recap.build("week", Dates.week_key(boss_day), st, app.sessions(), app.body(), today)
	ok(not r.bosses.is_empty() and str(r.headline) != "Boss slayer" and str(r.headline) != "", "a week in which a boss fell: the recap still counts it and its headline is not \"Boss slayer\"", [r.bosses, r.headline])
	var poster = recap_sheet.poster(r)
	root.add_child(poster)
	await _frames(2)
	ok(_boss_words(poster).is_empty() and _words(poster).filter(func(w): return w.begins_with("Defeated ")).is_empty() and _words(poster).has("SESSIONS"), "its poster has no \"Defeated ...\" line and no boss word", _boss_words(poster))
	poster.queue_free()

	# --- the shell: six tabs, the Log key where it was ------------------------------------------------
	var main_script = load("res://main.gd")
	var tabs = main_script.TABS
	ok(tabs.size() == 6 and tabs.map(func(t): return str(t.id)) == ["home", "adventure", "log", "journey", "armory", "realm"], "six tabs: Hero, Adventure, Log, Journey, Armory, Realm", tabs.map(func(t): return str(t.id)))
	ok(str(tabs[2].id) == "log" and str(tabs[5].label) == "Realm" and str(tabs[5].icon) == "realm", "Log is the third, Realm the last")
	ok(tabs.all(func(t): return main_script.SCREENS.has(t.id) and ResourceLoader.exists(main_script.SCREENS[t.id]) and Pal.TAB_ACCENT.has(t.id) and main_script.TAB_STRETCH.has(t.id)) and str(main_script.SCREENS.realm) == "res://ui/rpg/realm.gd", "every tab has a screen, an accent and a share of the bar")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)
	if absf(main.size.x - 440.0) > 0.5:
		# The test's window is not the phone's width: lay the shell out at 440 by hand.
		main.set_anchors_preset(Control.PRESET_TOP_LEFT)
		main.size = Vector2(440, 900)
		await _frames(4)
	ok(is_equal_approx(main.size.x, 440.0) and is_equal_approx(main._column.size.x, 440.0), "the shell is 440 wide, a phone's width", [main.size, root.size])
	var keys = _with_meta(main._nav_row, "tab")
	ok(keys.size() == 6 and keys.map(func(k): return str(k.get_meta("tab"))) == ["home", "adventure", "log", "journey", "armory", "realm"], "the bar has the six keys in order", keys.map(func(k): return str(k.get_meta("tab"))))
	# What five equal tabs gave: the same row laid out by the engine with five keys.
	var bar_w = main._nav_row.size.x
	var five = HBoxContainer.new()
	five.add_theme_constant_override("separation", 0)
	for i in range(5):
		var b = Button.new()
		b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(56, 64)
		five.add_child(b)
	root.add_child(five)
	five.size = Vector2(bar_w, 64)
	await _frames(3)
	var was = five.get_child(2)
	var log_key = keys[2] if keys.size() == 6 else null
	ok(log_key != null and is_equal_approx(bar_w, 432.0), "the bar is 432 wide inside its frame", bar_w)
	if log_key != null:
		print("  the Log key: x %s, %s wide, of a bar of %s (five equal tabs: x %s, %s wide); window %s" % [str(log_key.position.x), str(log_key.size.x), str(bar_w), str(was.position.x), str(was.size.x), str(root.size)])
		ok(absf(log_key.position.x - was.position.x) <= 1.0 and absf(log_key.size.x - was.size.x) <= 1.0, "the Log key is where five equal tabs had it, to the pixel (x %s w %s; five tabs: x %s w %s)" % [str(log_key.position.x), str(log_key.size.x), str(was.position.x), str(was.size.x)])
		ok(absf(log_key.position.x - bar_w * 2.0 / 5.0) <= 1.0 and absf(log_key.size.x - bar_w / 5.0) <= 1.0, "that is two fifths in and a fifth wide", [log_key.position.x, log_key.size.x])
		ok(absf(keys[0].size.x - was.size.x) <= 1.0 and absf(keys[1].position.x - five.get_child(1).position.x) <= 1.0, "Hero and Adventure did not move either")
		ok(absf(log_key.get_global_rect().get_center().x - 220.0) <= 1.0, "its middle is the middle of the screen", log_key.get_global_rect().get_center().x)
		var narrow = [keys[3].size.x, keys[4].size.x, keys[5].size.x]
		ok(narrow.all(func(w): return w >= 57.0 and w <= 58.0) and is_equal_approx(keys[5].position.x + keys[5].size.x, bar_w) and keys[5].custom_minimum_size.x == 48.0 and keys[0].custom_minimum_size.x == 56.0, "Journey, Armory and Realm share the rest (57 or 58 each, least 48) and the bar is full", narrow)
	five.queue_free()
	# The dot: on the bar only while the chest check says a chest waits (it is turned
	# on and off for real at the end of this test); a key asked for one has it.
	ok(_with_meta(main._nav_row, "tab_dot").is_empty() == (not RpgBoosts.chest_waiting(app.state, app.reading(), app.rpg(), today)), "the Realm tab shows its dot only while a chest waits")
	var with_dot = main._nav_button(tabs[5], false, 0, true)
	var without = main._nav_button(tabs[5], false, 0, false)
	var with_count = main._nav_button(tabs[1], false, 3, false)
	ok(_with_meta(with_dot, "tab_dot").size() == 1 and str(_with_meta(with_dot, "tab_dot")[0].get_meta("tab_dot")) == "realm" and _words(with_dot).filter(func(w): return w.is_valid_int()).is_empty(), "a tab key with a dot: one dot and no number")
	ok(_with_meta(without, "tab_dot").is_empty() and _with_meta(with_count, "tab_dot").is_empty() and _words(with_count).has("3"), "without one: none; the Adventure tab's count is a number as before")
	with_dot.free()
	without.free()
	with_count.free()

	# --- the Hero tab: no boss ----------------------------------------------------------------------------
	app.go("home")
	await _frames(4)
	var hero = main._screen
	ok(_is(hero, "HomeScreen"), "the Hero tab is up")
	var sections = _with_meta(hero, "section").map(func(n): return str(n.get_meta("section")))
	ok(sections.has("adventure") and sections.has("today") and sections.has("missions"), "it has its sections, Adventure among them", sections)
	ok(_boss_words(hero).is_empty(), "no word on it names a campaign boss or says \"boss\"", _boss_words(hero))
	ok(_too_wide(main) == "", "the Hero tab fits the column", _too_wide(main))
	var adv = _with_meta(hero, "section").filter(func(n): return str(n.get_meta("section")) == "adventure")
	if not adv.is_empty():
		var views = _all(adv[0]).filter(func(n): return _is(n, "BossView"))
		ok(views.size() == 1 and str(views[0]._boss_id).begins_with("wk_") and str(views[0]._boss_id) == str(Bounty.of(app.state).current.monster), "the Adventure section holds the week's bounty monster and nothing else", views.map(func(v): return str(v._boss_id)))
		ok(_words(adv[0]).has(str(Bounty.monster(Bounty.of(app.state).current.monster).name)), "with its name")
	var goal_titles = app.next_goals(3).map(func(g): return Icons.strip_emoji(str(g.title)))
	ok(not sections.has("goals") or goal_titles.all(func(t): return _words(hero).has(t)), "Almost there shows the goals App.next_goals gives", goal_titles)

	# --- the Adventure tab: Bounty in the campaign's place ------------------------------------------
	app.go("adventure", "campaign")
	await _frames(4)
	var adventure = main._screen
	ok(_is(adventure, "AdventureScreen") and app.adventure_tab == "campaign", "the Adventure tab is up on its first page")
	var labels = _all(adventure).filter(func(n): return n is Button).map(func(n): return str(n.text))
	ok(labels.has("Bounty") and not labels.has("Campaign") and labels.has("Trophies") and labels.filter(func(t): return t.begins_with("Missions")).size() == 1, "its pages are Bounty, Missions, Trophies", labels)
	ok(_boss_words(adventure).is_empty(), "no word on it names a campaign boss or says \"boss\"", _boss_words(adventure))
	ok(_too_wide(main) == "", "the Bounty page fits the column", _too_wide(main))
	var monsters = _all(adventure).filter(func(n): return _is(n, "BossView")).map(func(n): return str(n._boss_id))
	ok(not monsters.is_empty() and monsters.all(func(id): return id.begins_with("wk_")) and monsters[0] == str(Bounty.of(app.state).current.monster), "every monster on it is a bounty's, this week's first", monsters)
	ok(_with_meta(adventure, "bounty_record").size() == 1 and _with_meta(adventure, "bounty_past").size() == 1 and _with_meta(adventure, "bounty_how").size() == 1, "the bounty's record and its past weeks are on the page")
	var caps = _words(adventure)
	ok(caps.has("WINS") and caps.has("IN A ROW") and caps.has("COINS") and not caps.has("BOSSES") and not caps.has("DAMAGE") and not caps.has("ZONE"), "the three numbers are the bounty's, not the campaign's")
	ok(_with_meta(adventure, "bounty_past")[0].get_child_count() == mini(adventure_cls.BOUNTY_WEEKS, Bounty.of(app.state).history.size() - 1), "the past weeks: the newest twelve at most", _with_meta(adventure, "bounty_past")[0].get_child_count())
	# A state that was never derived has no bounty: the page says so and is not left empty.
	var bare = adventure_cls.new()
	bare._bounty({})
	ok(bare.get_child_count() == 1 and _words(bare).has("No bounty yet") and _boss_words(bare).is_empty(), "with no bounty at all the page still says something", _words(bare))
	bare.free()
	app.go("adventure", "trophies")
	await _frames(4)
	var cabinet = _words(main._screen)
	var unearned = Campaign.GOAL_TROPHIES.filter(func(id): return not app.state.achievements.has(id))
	var earned = Campaign.GOAL_TROPHIES.filter(func(id): return app.state.achievements.has(id))
	var leaked = unearned.filter(func(id): return cabinet.any(func(w): return w.contains(Icons.strip_emoji(str(Achievements.by_id(id).desc)))))
	ok(not unearned.is_empty() and leaked.is_empty() and cabinet.any(func(w): return w.contains(Campaign.RESTING)), "the cabinet: a campaign trophy not earned (%d of them) says it is a campaign reward" % unearned.size(), leaked)
	var resting_tiles = _all(main._screen).filter(func(n): return _is(n, "Card") and str(n.tooltip_text).begins_with(Campaign.RESTING)).size()
	ok(resting_tiles == unearned.size(), "each of them on its tile (the tile's tooltip begins with it)", [resting_tiles, unearned.size()])
	ok(earned.is_empty() or cabinet.any(func(w): return w.contains(Icons.strip_emoji(str(Achievements.by_id(earned[0]).desc)))), "an earned one keeps its words")
	ok(_too_wide(main) == "", "the cabinet fits the column", _too_wide(main))
	app.go("adventure", "quests")
	await _frames(4)
	ok(_boss_words(main._screen).is_empty(), "the Missions page has no boss word either", _boss_words(main._screen))

	# --- the Journey and the Armory -------------------------------------------------------------------
	app.go("journey", "chronicle")
	await _frames(4)
	var story_labels = _all(main._screen).filter(func(n): return n is Button).map(func(n): return str(n.text))
	ok(story_labels.has("Bounties") and not story_labels.has("Bosses"), "the Story page's chip is Bounties", story_labels)
	ok(_words(main._screen).filter(func(w): return w.begins_with("Defeated ")).is_empty(), "no \"Defeated ...\" moment is on it")
	app.go("journey", "stats")
	await _frames(4)
	ok(_words(main._screen).filter(func(w): return w.contains("defeated bosses")).is_empty(), "the Stats page leaves the damage fact out")
	app.go("armory")
	await _frames(4)
	ok(_is(main._screen, "ArmoryScreen") and _boss_words(main._screen).filter(func(w): return not w.contains("the campaign is resting")).is_empty(), "the Armory's first page has no boss word", _boss_words(main._screen))

	# --- the Realm tab ------------------------------------------------------------------------------------
	app.go("realm")
	await _frames(4)
	var realm = main._screen
	ok(_is(realm, "RealmScreen") and _is(realm, "UiScreen") and app.tab == "realm", "the Realm tab opens its screen")
	# A Realm never opened: the first visit (RPG_PLAN.md 10.0) stands in for the hub.
	var realm_sections = _with_meta(realm, "section").map(func(n): return str(n.get_meta("section")))
	ok(realm_sections == ["realm_first"] and not bool(app.rpg().opened), "a Realm never opened shows the first visit, one section", realm_sections)
	var said = " ".join(PackedStringArray(_words(realm)))
	ok(said.contains("Enter the Ironwild") and said.contains("already earned") and _with_meta(realm, "first_stat").map(func(n): return str(n.get_meta("first_stat"))) == RpgDefs.STATS, "it lists the twelve stats, says what the training has earned, and has the key into the Ironwild", said)
	ok(_too_wide(main) == "", "the Realm's page fits the column", _too_wide(main))
	# With keys sized for fingers (a phone): the two new pages still fit.
	var kit = _S("res://ui/kit.gd")
	kit.fingers = true
	app.go("adventure", "campaign")
	await _frames(4)
	var wide_a = _too_wide(main)
	app.go("realm")
	await _frames(4)
	ok(wide_a == "" and _too_wide(main) == "", "at finger sizes too", [wide_a, _too_wide(main)])
	kit.fingers = false
	app.go("realm")
	app.changed.emit()
	await _frames(4)
	realm = main._screen
	var active = _with_meta(main._nav_row, "tab").filter(func(k): return str(k.get_meta("tab")) == "realm")
	ok(active.size() == 1 and _all(active[0]).filter(func(n): return n is ColorRect and n.color == Pal.REALM).size() == 1, "its key in the bar is marked in the Realm's colour")
	# A change of the Realm's save: the Realm's screen is drawn again, nothing else hears `changed`.
	var realm_first = realm.get_child(0)
	counts.changed = 0
	counts.rpg = 0
	app.set_rpg(RpgSave.copy(rpg))
	await _frames(3)
	# (The made-up save is an opened one: the hub takes the first visit's place.)
	var hub_sections = _with_meta(realm, "section").map(func(n): return str(n.get_meta("section"))).filter(func(id): return id.begins_with("realm_") and id != "realm_notices")
	ok(counts.rpg == 1 and counts.changed == 0 and not is_instance_valid(realm_first) and is_instance_valid(realm) and hub_sections == ["realm_tabs", "realm_banner", "realm_boosts", "realm_map"], "set_rpg draws the Realm's screen again: the hub (sub-tabs, banner, boosts, the Map)", hub_sections)
	ok(_too_wide(main) == "" and _with_meta(realm, "realm_tab").map(func(n): return str(n.get_meta("realm_tab"))) == ["map", "hero", "moves", "skills", "gear"] and _with_meta(realm, "map_stage").size() == 10, "the hub fits the column, with its five sub-tabs and the Map's ten stage nodes", _too_wide(main))
	app.go("home")
	await _frames(4)
	var home_first = main._screen.get_child(0)
	var home_screen = main._screen
	counts.changed = 0
	app.set_rpg(RpgSave.empty())
	await _frames(3)
	ok(counts.changed == 0 and is_instance_valid(home_first) and main._screen == home_screen and home_screen.get_child(0) == home_first, "and leaves the Hero tab exactly as it is: nothing there is built again")

	# --- the reel: the boss fight is no card ---------------------------------------------------------
	var session = app.build_session({"discipline": "lift", "date": today, "durationSec": 3600, "exercises": [{"name": "Deadlift - Barbell", "sets": [{"reps": 5, "weightKg": 150.0}, {"reps": 5, "weightKg": 150.0}, {"reps": 5, "weightKg": 150.0}]}]})
	app.commit_sessions([session], "Workout logged!")
	await _frames(3)
	var reel = main._results
	ok(reel != null and _is(reel, "ResultsOverlay"), "logging a workout opens the results reel")
	if reel != null:
		var types = reel._events.map(func(e): return str(e.type))
		var cards = reel._cards.map(func(e): return str(e.type))
		ok(types.has("boss"), "the rules still send the boss fight (%s)" % ", ".join(PackedStringArray(types)))
		ok(not cards.has("boss") and cards.size() == types.filter(func(t): return t != "boss" and not results_cls.HEADER_TYPES.has(t)).size(), "the reel makes no card of it and keeps every other one", cards)
		reel._skip()
		await _frames(3)
		# (An earned trophy or piece of gear keeps its own words, so only the fight's
		# card is looked for: its kicker, and a title that is a boss's name.)
		var fight = _words(reel).filter(func(w): return w == "BOSS FIGHT" or w == "BOSS DEFEATED" or Campaign.bosses().any(func(b): return str(b.name) == w))
		ok(fight.is_empty() and _words(reel).has("Continue"), "the finished reel shows no boss fight", fight)
		main._result_done()
		await _frames(2)

	# --- the tab's dot follows the Realm's save by itself -------------------------------------------
	# A workout was just logged today, so a training chest waits until the Realm's
	# save says it was paid (saved.rpg.chests[date] = the kinds paid, RPG_PLAN.md 3).
	# The save changes through set_rpg alone: rpg_changed, never `changed`.
	app.go("home")
	await _frames(4)
	var home_now = main._screen
	var first_now = home_now.get_child(0)
	counts.changed = 0
	counts.rpg = 0
	# (The dot is held back until the Realm's hub can open a chest: turn it on here.)
	load("res://ui/rpg/realm.gd").hub_ready = true
	app.set_rpg(RpgSave.empty())
	await _frames(3)
	var waits_open = RpgBoosts.chest_waiting(app.state, app.reading(), app.rpg(), today)
	var dot_open = _with_meta(main._nav_row, "tab_dot").size()
	var paid = RpgSave.empty()
	paid.chests = {today: 9, Dates.add_days(today, -1): 9}
	app.set_rpg(paid)
	await _frames(3)
	var waits_paid = RpgBoosts.chest_waiting(app.state, app.reading(), app.rpg(), today)
	var dot_paid = _with_meta(main._nav_row, "tab_dot").size()
	ok(waits_open and not waits_paid, "RpgBoosts.chest_waiting: a chest waits after today's workout, and none once both days are paid", [waits_open, waits_paid])
	ok(dot_open == (1 if waits_open else 0) and dot_paid == (1 if waits_paid else 0), "the Realm tab shows its dot exactly while a chest waits (nothing paid: %d dot, paid: %d)" % [dot_open, dot_paid])
	var dot_keys = _with_meta(main._nav_row, "tab")
	app.set_rpg(RpgSave.empty())
	await _frames(3)
	var dots_back = _with_meta(main._nav_row, "tab_dot")
	ok(dots_back.size() == (1 if waits_open else 0) and (dots_back.is_empty() or str(dots_back[0].get_meta("tab_dot")) == "realm"), "and the dot comes back on the Realm's key when the save says unpaid again")
	ok(counts.changed == 0 and counts.rpg == 3 and _with_meta(main._nav_row, "tab").size() == 6 and (not waits_open or waits_paid or not is_instance_valid(dot_keys[0])), "all of it through rpg_changed alone: the bar was built again, `changed` never went out", counts)
	ok(is_instance_valid(first_now) and main._screen == home_now and home_now.get_child(0) == first_now, "and the Hero tab under it was not built again")

	app.changed.disconnect(on_changed)
	app.rpg_changed.disconnect(on_rpg)
	print("RPG SHELL: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
