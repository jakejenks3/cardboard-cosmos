class_name Wallet
extends RefCounted
## Coins and the shop (added after the port).
##
## Coins are never stored: like everything else they are counted from the log
## after the replay (`tally` fills `state.coins`). What the player has bought
## IS stored, as `saved.purchases` = [{id, itemId, cost, at (epoch ms), date}];
## each purchase is replayed in time order (Derive._apply_purchase) and puts the
## item into `state.items` with how = "shop".
##
## state.coins: {earned, spent, balance,
##               by: {sessions, checkins, quests, bosses, bounties, trophies}}
## Earning: 1 coin per 10 XP of a session, check-in or claimed quest; a campaign
## boss 40 (zone boss 150, endless echo 60); a weekly bounty 100+ (see Bounty);
## a trophy 10 / 25 / 50 / 100 by tier.
##
## Shop items are catalog items with `unlock = {"kind": "shop", "price": int,
## "minHeroLevel"?: int}`. One of them is 30% off each Monday-week (`deal_id`).
## The parity tests drop `coins` before comparing.

const XP_PER_COIN = 10
const BOSS_COINS = 40
const ZONE_BOSS_COINS = 150
const ECHO_COINS = 60
const TROPHY_COINS = {"bronze": 10, "silver": 25, "gold": 50, "platinum": 100}
const DEAL_OFF = 0.3

static var _shop = null


static func xp_coins(xp) -> int:
	if xp == null or int(xp) <= 0:
		return 0
	return maxi(1, TTUtil.jsround(float(xp) / float(XP_PER_COIN)))


static func boss_coins(boss_id: String) -> int:
	var boss = Campaign.boss_by_id(boss_id)
	if boss == null:
		return ECHO_COINS
	return ZONE_BOSS_COINS if boss.zoneBoss else BOSS_COINS


static func trophy_coins(ach: Dictionary) -> int:
	return int(TROPHY_COINS.get(Achievements.tier_of(ach), 10))


## Count the coins of a replayed state. `input` is what Derive.derive was given.
static func tally(s: Dictionary, input: Dictionary) -> void:
	var by = {"sessions": 0, "checkins": 0, "quests": 0, "bosses": 0, "bounties": 0, "trophies": 0}
	for id in s.sessionXp:
		by.sessions += xp_coins(s.sessionXp[id])
	for id in s.bodyXp:
		by.checkins += xp_coins(s.bodyXp[id])
	for c in TTUtil.get_or(input, "claims", []):
		by.quests += xp_coins(c.get("xp"))
	for id in s.campaign.defeated:
		by.bosses += boss_coins(str(id))
	by.bounties = int(s.weekly.coins) if s.get("weekly") is Dictionary else 0
	for id in s.achievements:
		var a = Achievements.by_id(id)
		if a != null:
			by.trophies += trophy_coins(a)
	var earned: int = 0
	for k in by:
		earned += int(by[k])
	var spent: int = 0
	var seen: Dictionary = {}
	for p in TTUtil.get_or(input, "purchases", []):
		var item_id = p.get("itemId")
		if item_id == null or seen.has(item_id):
			continue
		var owned = s.items.get(item_id)
		if owned is Dictionary and owned.get("how") == "shop":
			seen[item_id] = true
			spent += int(p.get("cost", 0))
	s["coins"] = {"earned": earned, "spent": spent, "balance": earned - spent, "by": by}


# --- reading (safe on a state without coins) ----------------------------------------

static func balance(s: Dictionary) -> int:
	var c = s.get("coins")
	return maxi(0, int(c.balance)) if c is Dictionary else 0


static func earned(s: Dictionary) -> int:
	var c = s.get("coins")
	return int(c.earned) if c is Dictionary else 0


## How many things bought in the shop the state owns.
static func bought_count(s: Dictionary) -> int:
	var n: int = 0
	for id in s.items:
		var o = s.items[id]
		if o is Dictionary and o.get("how") == "shop":
			n += 1
	return n


# --- the shop ---------------------------------------------------------------------

static func is_shop(it: Dictionary) -> bool:
	return it.unlock.kind == "shop"


## Every item sold in the shop, cheapest first (catalog order within a price).
static func shop_items() -> Array:
	if _shop == null:
		var list: Array = Items.all().filter(func(i): return i.unlock.kind == "shop")
		TTUtil.stable_sort(list, func(a, b): return int(a.unlock.price) < int(b.unlock.price))
		_shop = list
	return _shop


static func reset_cache() -> void:
	_shop = null


## The item on offer in a Monday-week ("" when the shop is empty).
static func deal_id(wk: String) -> String:
	var list: Array = shop_items()
	if list.is_empty():
		return ""
	return list[Rng.hash_string("deal:" + wk) % list.size()].id


static func base_price(it: Dictionary) -> int:
	return int(it.unlock.get("price", 0))


## What the item costs in the week `wk` (the week's deal is 30% off).
static func price(it: Dictionary, wk: String) -> int:
	var p: int = base_price(it)
	if it.id == deal_id(wk):
		return maxi(10, TTUtil.jsround(float(p) * (1.0 - DEAL_OFF) / 10.0) * 10)
	return p


static func min_level(it: Dictionary) -> int:
	return int(it.unlock.get("minHeroLevel", 0))


## Can the state buy the item this week? {"ok": bool, "why": String, "price": int}
## `why` is "" when ok, else "owned" | "level" | "coins".
static func can_buy(s: Dictionary, it: Dictionary, wk: String) -> Dictionary:
	var cost: int = price(it, wk)
	if not is_shop(it):
		return {"ok": false, "why": "owned", "price": cost}
	if s.items.has(it.id):
		return {"ok": false, "why": "owned", "price": cost}
	if int(s.levels.hero.level) < min_level(it):
		return {"ok": false, "why": "level", "price": cost}
	if balance(s) < cost:
		return {"ok": false, "why": "coins", "price": cost}
	return {"ok": true, "why": "", "price": cost}
