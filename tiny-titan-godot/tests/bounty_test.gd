extends SceneTree
## Unit test for the weekly bounty (game/bounty.gd), coins and the shop
## (game/wallet.gd, purchases in Derive) and the new gear's pixel art.
##   godot --headless --path . --script res://tests/bounty_test.gd
## Prints BOUNTY: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## A run of `km` kilometres.
func run(date: String, km: float) -> Dictionary:
	_n += 1
	return {"id": "r%d" % _n, "discipline": "run", "date": date, "createdAt": 1700000000000 + _n * 3600000, "source": "manual", "distanceM": km * 1000.0, "elevationM": 0, "durationSec": int(km * 330.0)}


func lift(date: String) -> Dictionary:
	_n += 1
	var sets = []
	for i in range(4):
		sets.append({"reps": 5, "weightKg": 60.0})
	return {"id": "l%d" % _n, "discipline": "lift", "date": date, "createdAt": 1700000000000 + _n * 3600000, "source": "manual", "exercises": [{"name": "Squat", "sets": sets}], "durationSec": 2400}


func derive(sessions: Array, today: String, purchases: Array = [], claims: Array = []) -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": claims, "body": [], "purchases": purchases, "weeklyGoal": 3, "today": today})


func week_xp(s: Dictionary, sessions: Array, wk: String) -> int:
	var n = 0
	for x in sessions:
		if Dates.week_key(x.date) == wk:
			n += int(s.sessionXp[x.id])
	return n


func _init() -> void:
	# 2026-11-02 is a Monday.
	ok(Dates.weekday_index("2026-11-02") == 0, "2026-11-02 is a Monday")

	# --- nothing logged -------------------------------------------------------------
	var s0 = derive([], "2026-11-04")
	ok(s0.weekly.current != null and s0.weekly.current.week == "2026-11-02" and int(s0.weekly.current.hp) == Bounty.FLOOR_HP and s0.weekly.current.weak == null and int(s0.weekly.wins) == 0, "an empty log has a first bounty at the floor, no weakness yet", s0.weekly.current)
	ok(int(s0.coins.earned) == 0 and Wallet.balance(s0) == 0, "an empty log has no coins")
	ok(Bounty.wins({}) == 0 and Wallet.balance({}) == 0 and Bounty.of({}) == null, "the readers are safe on a state that was never settled")
	ok(Bounty.days_left("2026-11-02") == 7 and Bounty.days_left("2026-11-08") == 1, "7 days left on Monday, 1 on Sunday")

	# --- the first week ---------------------------------------------------------------
	var a = [run("2026-11-03", 5.0)]
	var s1 = derive(a, "2026-11-04")
	var xp_a = int(s1.sessionXp[a[0].id])
	var cur = s1.weekly.current
	ok(cur.weak == "run" and int(cur.damage) == TTUtil.jsround(xp_a * 1.5), "first week: weak to what you trained first, x1.5 damage", [xp_a, cur])
	ok(cur.defeated == (int(cur.damage) >= Bounty.FLOOR_HP), "defeated exactly when damage reaches the HP")
	ok(Bounty.monster(cur.monster).id == cur.monster and Bounty.monster_for("2026-11-02").id == cur.monster, "the week's monster is the seeded one")

	# --- HP follows the weeks before ------------------------------------------------------
	var b = [run("2026-10-06", 8.0), run("2026-10-08", 8.0), run("2026-10-13", 8.0), run("2026-10-15", 8.0), run("2026-10-20", 8.0), run("2026-10-27", 8.0), run("2026-10-29", 8.0), run("2026-11-03", 8.0)]
	var s2 = derive(b, "2026-11-04")
	var w1 = week_xp(s2, b, "2026-10-05")
	var w2 = week_xp(s2, b, "2026-10-12")
	var w3 = week_xp(s2, b, "2026-10-19")
	var w4 = week_xp(s2, b, "2026-10-26")
	var want2 = maxi(Bounty.FLOOR_HP, maxi(50, TTUtil.jsround(w1 * 0.9 / 50.0) * 50))
	var want5 = maxi(Bounty.FLOOR_HP, maxi(50, TTUtil.jsround((w1 + w2 + w3 + w4) / 4.0 * 0.9 / 50.0) * 50))
	ok(int(Bounty.record(s2, "2026-10-05").hp) == Bounty.FLOOR_HP, "week 1 is the floor")
	ok(int(Bounty.record(s2, "2026-10-12").hp) == want2, "week 2 is 90% of week 1, rounded to 50", [Bounty.record(s2, "2026-10-12").hp, want2])
	ok(int(s2.weekly.current.hp) == want5 and s2.weekly.current.week == "2026-11-02", "this week is 90% of the last four weeks' average", [s2.weekly.current.hp, want5])
	ok(s2.weekly.history.size() == 5 and s2.weekly.history[0].week == "2026-10-05", "one record per week since the first session")
	var twice = derive(b, "2026-11-04")
	ok(str(twice.weekly) == str(s2.weekly), "the same log always gives the same bounties")

	# --- wins, streaks, crushes, coins --------------------------------------------------------
	# Two runs a week win; week 3 (one short run after two big weeks) gets away.
	var c = [run("2026-10-06", 10.0), run("2026-10-08", 10.0), run("2026-10-13", 10.0), run("2026-10-15", 10.0), run("2026-10-20", 1.0), run("2026-10-27", 10.0), run("2026-10-29", 10.0)]
	var s3 = derive(c, "2026-11-04")
	var h = s3.weekly.history
	ok(h[0].defeated and h[1].defeated and not h[2].defeated and h[3].defeated, "weeks 1, 2 and 4 won, week 3 got away", h.map(func(r): return [r.week, r.hp, r.damage, r.defeated]))
	ok(int(h[0].streak) == 1 and int(h[1].streak) == 2 and int(h[3].streak) == 1 and int(s3.weekly.bestStreak) == 2 and int(s3.weekly.wins) == 3, "streak 1, 2, then back to 1 after the miss; best 2; 3 wins")
	ok(int(s3.weekly.streak) == 1 and not s3.weekly.current.defeated and s3.weekly.current.week == "2026-11-02", "the week in progress does not break the streak")
	ok(int(h[0].coins) == Bounty.coins_for(1, h[0].crushed) and int(h[1].coins) == Bounty.coins_for(2, h[1].crushed) and int(h[2].coins) == 0, "coins per win: 100, +10 per win in a row, +50 for a crush", h.map(func(r): return r.coins))
	ok(h[0].crushed and int(s3.weekly.crushes) >= 1, "a week at 150% of the HP is crushed", h[0])
	ok(h[0].at == "2026-10-06" and h[0].sessionId == c[0].id, "the win is dated by the session that finished it")
	ok(Bounty.coins_for(1, false) == 100 and Bounty.coins_for(3, false) == 120 and Bounty.coins_for(9, true) == 200, "coins_for: 100, 120 at three in a row, capped at 150 + 50")
	var past = derive(c, "2026-12-01")
	ok(int(past.weekly.streak) == 0 and int(past.weekly.wins) == 3, "weeks that pass untrained end the streak, wins stay")

	# --- bounty gear and trophies unlock on the day of the win --------------------------------
	ok(s3.items.has("bounty_cap") and s3.items.bounty_cap.at == "2026-10-06" and s3.items.has("bounty_cloak") and not s3.items.has("bounty_gauntlets"), "the cap at the first win, the cloak at the third", s3.items.keys())
	ok(s3.achievements.has("bounty_1") and s3.achievements.has("bounty_crush_1") and not s3.achievements.has("bounty_5"), "Bounty Hunter and Overkill earned, Monster of the Week not yet")
	var story = Bounty.chronicle(s3)
	ok(story.size() == 3 and story[0].kind == "bounty" and story[0].date == "2026-10-06", "three wins for the Story page")

	# --- coins ---------------------------------------------------------------------------------
	var by = s3.coins.by
	var want_sessions = 0
	for x in c:
		want_sessions += Wallet.xp_coins(s3.sessionXp[x.id])
	var want_trophies = 0
	for id in s3.achievements:
		want_trophies += Wallet.trophy_coins(Achievements.by_id(id))
	var want_bosses = 0
	for id in s3.campaign.defeated:
		want_bosses += Wallet.boss_coins(id)
	ok(int(by.sessions) == want_sessions and int(by.bounties) == int(s3.weekly.coins) and int(by.trophies) == want_trophies and int(by.bosses) == want_bosses, "coins: 1 per 10 session XP, the bounty coins, trophies by tier, bosses", by)
	ok(int(s3.coins.earned) == want_sessions + want_trophies + want_bosses + int(s3.weekly.coins) and int(s3.coins.spent) == 0 and Wallet.balance(s3) == int(s3.coins.earned), "earned is the sum, nothing spent")
	ok(Wallet.xp_coins(0) == 0 and Wallet.xp_coins(4) == 1 and Wallet.xp_coins(1234) == 123 and Wallet.boss_coins("iron_golem") == 150 and Wallet.boss_coins("rust_mite") == 40 and Wallet.boss_coins("echo_3") == 60, "coin amounts")
	var claimed = derive(c, "2026-11-04", [], [{"id": "q1", "questId": "d:2026-10-06:0", "xp": 150, "claimedAt": 1700000000000 + 999 * 3600000, "date": "2026-10-06"}])
	ok(int(claimed.coins.by.quests) == 15, "a claimed 150 XP quest pays 15 coins")

	# --- the shop -------------------------------------------------------------------------------
	var shop = Wallet.shop_items()
	var bad = []
	var seen = {}
	for it in shop:
		if Wallet.base_price(it) < 50 or seen.has(it.id) or not TT.SLOTS.has(it.slot) or not TT.RARITY_ORDER.has(it.rarity):
			bad.append(it.id)
		seen[it.id] = true
	ok(shop.size() >= 30 and bad.is_empty(), "at least 30 shop items, each with a price, slot and rarity", [shop.size(), bad])
	var slots = {}
	for it in shop:
		slots[it.slot] = true
	ok(slots.size() == TT.SLOTS.size(), "the shop sells something for every slot", slots.keys())
	var sorted_ok = true
	for i in range(1, shop.size()):
		if Wallet.base_price(shop[i]) < Wallet.base_price(shop[i - 1]):
			sorted_ok = false
	ok(sorted_ok, "the shop is listed cheapest first")
	var wk = "2026-11-02"
	var deal = Items.by_id(Wallet.deal_id(wk))
	ok(deal != null and Wallet.is_shop(deal) and Wallet.price(deal, wk) == maxi(10, TTUtil.jsround(Wallet.base_price(deal) * 0.7 / 10.0) * 10) and Wallet.price(deal, wk) < Wallet.base_price(deal), "this week's deal is 30% off", [deal.id if deal != null else null])
	var hat = Items.by_id("shop_party_hat")
	var halo = Items.by_id("shop_halo")
	ok(Wallet.can_buy(s0, hat, wk).why == "coins" and Wallet.can_buy(s3, halo, wk).why == "level", "cannot buy without coins, or under the hero level", [Wallet.can_buy(s0, hat, wk), Wallet.can_buy(s3, halo, wk)])
	ok(not s3.items.has("shop_party_hat") and Wallet.balance(s3) >= Wallet.price(hat, wk) and Wallet.can_buy(s3, hat, wk).ok, "three weeks of running affords a party hat", Wallet.balance(s3))
	var cost = Wallet.price(hat, wk)
	var buys = [{"id": "b1", "itemId": "shop_party_hat", "cost": cost, "at": 1700000000000 + 500 * 3600000, "date": "2026-11-04"}]
	var s4 = derive(c, "2026-11-04", buys)
	ok(s4.items.has("shop_party_hat") and s4.items.shop_party_hat.how == "shop" and s4.items.shop_party_hat.at == "2026-11-04", "a purchase puts the item in the collection", s4.items.get("shop_party_hat"))
	ok(int(s4.coins.spent) == cost and Wallet.balance(s4) == int(s4.coins.earned) - cost and s4.achievements.has("shop_1") and Wallet.bought_count(s4) == 1, "the price is spent once and Retail Therapy is earned", s4.coins)
	ok(Wallet.can_buy(s4, hat, wk).why == "owned", "an owned item cannot be bought again")
	var dup = derive(c, "2026-11-04", buys + [{"id": "b2", "itemId": "shop_party_hat", "cost": cost, "at": 1700000000000 + 501 * 3600000, "date": "2026-11-04"}, {"id": "b3", "itemId": "no_such_item", "cost": 999, "at": 1700000000000 + 502 * 3600000, "date": "2026-11-04"}])
	ok(int(dup.coins.spent) == cost, "a repeated or unknown purchase line is never charged")
	ok(Items.unlock_hint(hat) == "Shop: 150 coins" and Items.unlock_hint(halo) == "Shop: 4,500 coins (hero Lv 20+)", "shop hints", [Items.unlock_hint(hat), Items.unlock_hint(halo)])
	ok(Perks.compute_perks(s4, {"head": "shop_party_hat"}, null).luck == 0.0 and Perks.sanitize_loadout(s4, {"head": "shop_party_hat", "back": "shop_halo"}, null).loadout.keys() == ["head"], "a bought item can be worn; one not owned is dropped from the loadout")

	# --- the reel events --------------------------------------------------------------------------
	# Short runs in one week (none longer than the first, so no PR bonus): the first chips at the monster, the second
	# beats it, the third crushes it.
	var d = [run("2026-10-06", 2.0), run("2026-10-07", 1.5), run("2026-10-08", 1.5), run("2026-10-09", 1.0)]
	var st0 = derive([], "2026-10-09")
	var st1 = derive(d.slice(0, 1), "2026-10-09")
	var st2 = derive(d.slice(0, 2), "2026-10-09")
	var st3 = derive(d.slice(0, 3), "2026-10-09")
	var st4 = derive(d, "2026-10-09")
	var r1 = st1.weekly.current
	var r2 = st2.weekly.current
	var r3 = st3.weekly.current
	ok(not r1.defeated and r2.defeated and not r2.crushed and r3.crushed, "2 km chips, +1.5 km beats, +1.5 km crushes", [r1, r2, r3])
	var e1 = Diff.diff_extras(st0, st1, "run").filter(func(e): return e.type == "bounty")
	ok(e1.size() == 1 and e1[0].week == "2026-10-05" and int(e1[0].damage) == int(r1.damage) and not e1[0].defeated and e1[0].weak and int(e1[0].hpBefore) == int(r1.hp) and int(e1[0].hpAfter) == int(r1.hp) - int(r1.damage), "a hit: one bounty event with the damage and the HP left", e1)
	var e2 = Diff.diff_extras(st1, st2, "run").filter(func(e): return e.type == "bounty")
	ok(e2.size() == 1 and e2[0].defeated and not e2[0].crushed and int(e2[0].coins) == Bounty.coins_for(1, false) and int(e2[0].hpAfter) == 0, "the session that wins it: defeated, with the coins", e2)
	var e3 = Diff.diff_extras(st2, st3, "run").filter(func(e): return e.type == "bounty")
	ok(e3.size() == 1 and not e3[0].defeated and e3[0].crushed and int(e3[0].coins) == Bounty.COINS_CRUSH, "the session that crushes it later: crushed, +50 coins", e3)
	ok(Diff.diff_extras(st3, st4, "run").filter(func(e): return e.type == "bounty").is_empty(), "more damage to a crushed monster: no bounty event")
	var cev = Diff.diff_extras(st1, st2, "run").filter(func(e): return e.type == "coins")
	ok(cev.size() == 1 and int(cev[0].amount) == int(st2.coins.earned) - int(st1.coins.earned) and int(cev[0].balance) == Wallet.balance(st2), "and one coins event with what was earned", cev)
	ok(Diff.diff_extras(st4, st4).is_empty(), "nothing changed, no events")

	# --- catalog and art ----------------------------------------------------------------------------
	var ids = {}
	var dupes = []
	for it in Items.all():
		if ids.has(it.id):
			dupes.append(it.id)
		ids[it.id] = true
	ok(Items.all().size() == 124 and dupes.is_empty(), "124 items, no id twice", [Items.all().size(), dupes])
	# Every item added after the port draws something on the mannequin.
	var blank = []
	for it in Items.all():
		if not (str(it.id).begins_with("shop_") or str(it.id).begins_with("bounty_") or ["hang_tape", "rope_coil", "press_lanyard", "variety_tank", "dealer_visor", "hockey_mask"].has(it.id)):
			continue
		var bare_loadout = Art.STARTER_LOADOUT.duplicate()
		bare_loadout[it.slot] = null
		var owned = {}
		for slot in Art.STARTER_LOADOUT:
			owned[Art.STARTER_LOADOUT[slot]] = {"at": "", "how": "start"}
		var levels = {}
		for track in Art.MANNEQUIN_LEVELS:
			levels[track] = {"level": Art.MANNEQUIN_LEVELS[track]}
		var bare = Art.hero_pix({"levels": levels, "items": owned}, Art.PREVIEW_PROFILE, bare_loadout)
		var worn = Art.item_pix(it.id)
		var flexed_ok = true
		var with_item = Art.STARTER_LOADOUT.duplicate()
		with_item[it.slot] = it.id
		var owned2 = owned.duplicate()
		owned2[it.id] = {"at": "", "how": "shop"}
		for frame in [0, 1, 2, 3, 5]:
			for pose in ["idle", "flex"]:
				if Art.hero_pix({"levels": levels, "items": owned2}, Art.PREVIEW_PROFILE, with_item, pose, frame) == null:
					flexed_ok = false
		if worn.data == bare.data or not flexed_ok:
			blank.append(it.id)
	ok(blank.is_empty(), "every new item draws on the hero, in both poses", blank)
	var looks = BossSprites.boss_looks()
	var no_look = []
	for m in Bounty.MONSTERS:
		if not looks.has(m.id) or not BossSprites.BASE.has(looks[m.id].sprite) or BossSprites.boss_buffer(m.id) == null:
			no_look.append(m.id)
	ok(no_look.is_empty(), "every bounty monster has a sprite", no_look)
	ok(Achievements.all().size() == 187, "187 trophies in the catalog", Achievements.all().size())

	# --- the parity pin ---------------------------------------------------------------------------
	Items.restrict_to(["tee_grey", "shorts_navy", "trainers_worn"])
	ok(Items.all().size() == 3 and Items.by_id("shop_halo") == null and Wallet.shop_items().is_empty() and Wallet.deal_id(wk) == "", "restrict_to pins the catalog (and empties the shop)")
	Items.restrict_to(null)
	ok(Items.all().size() == 124 and Wallet.shop_items().size() == shop.size(), "and null restores it")

	# --- weak muscles: a session with 3 sets or more of the week's group hits for x1.5 ---------------
	var bwk = "2026-11-16"
	var bpart = Bounty.weak_part_for(bwk)
	ok(Bounty.MUSCLE_GROUPS.has(bpart) and Bounty.weak_part_for(bwk) == bpart, "each week's monster is weak to a muscle group (the same every time)", bpart)
	var mus = Bounty.muscles_of({"discipline": "lift", "exercises": [{"name": "Squat - Barbell", "sets": [{"reps": 5, "weightKg": 100.0}, {"reps": 5, "weightKg": 100.0}]}, {"name": "Calf Raise", "sets": [{"reps": 12, "weightKg": 40.0}]}, {"name": "Bench Press - Barbell", "sets": [{"reps": 5, "weightKg": 80.0}]}]})
	ok(int(mus.get("legs", 0)) == 3 and int(mus.get("chest", 0)) == 1, "working sets per muscle group", mus)
	var bweeks = {"2026-11-09": {"xp": 1000, "discs": {"climb": true}, "list": [{"date": "2026-11-10", "t": 1, "id": "c0", "disc": "climb", "xp": 1000, "muscles": {}}]},
		bwk: {"xp": 2000, "discs": {"lift": true}, "list": [
			{"date": "2026-11-17", "t": 2, "id": "a", "disc": "lift", "xp": 1000, "muscles": {bpart: 3}},
			{"date": "2026-11-18", "t": 3, "id": "b", "disc": "lift", "xp": 1000, "muscles": {bpart: 2}}]}}
	var brec = Bounty._record(bwk, "2026-11-09", bweeks)
	ok(str(brec.weakPart) == bpart and (brec.weak == "lift" or int(brec.damage) == 2500), "3 sets of the weak muscles: x1.5; 2 sets: x1 (%s, damage %d)" % [str(brec.weak), int(brec.damage)])
	# --- cycling is no weakness from 2026-11-23 on (it is kept in the Miscellaneous area) -------
	var rides = {}
	for wk0 in ["2026-10-26", "2026-11-02", "2026-11-09", "2026-11-16", "2026-11-23", "2026-11-30"]:
		rides[wk0] = {"xp": 100, "discs": {"ride": true}, "list": [{"date": wk0, "t": 0, "id": "x" + wk0, "disc": "ride", "xp": 100}]}
	ok(Bounty.weak_for("2026-11-16", rides) == "ride" and Bounty.weak_for("2026-11-23", rides) == null and Bounty.weak_for("2026-12-07", rides) == null, "a rider: the weeks before keep their weakness to cycling, from Nov 23 on no monster has it", [Bounty.weak_for("2026-11-16", rides), Bounty.weak_for("2026-11-23", rides)])
	var mixed = rides.duplicate(true)
	mixed["2026-11-16"].discs["lift"] = true
	ok(Bounty.weak_for("2026-11-23", mixed) == "lift", "with a lift in the weeks before, the weakness is lifting", Bounty.weak_for("2026-11-23", mixed))
	print("BOUNTY: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
