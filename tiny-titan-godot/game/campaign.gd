class_name Campaign
extends RefCounted
## The campaign (port of campaign.ts): a road of bosses that your training
## damages. Every point of session XP is a point of damage (x1.5 when the
## session's discipline is the boss's weakness), overkill carries over, and
## there is no way to lose: the only question is how fast you get there.
##
## Zone: {name, blurb, color}
## Boss: {id, name, epithet, zone (index into zones()), hp, xp (hero XP granted
##        on defeat), zoneBoss: bool, weak? (discipline), rewardItem? (item id
##        awarded on defeat, zone bosses only)}
## `weak` and `rewardItem` are optional: read them with `boss.get("weak")`.

const WEAK_MULT = 1.5

const ZONES = [
	{"name": "The Couch Kingdom", "blurb": "Where every journey starts: the gravitational pull of soft furniture.", "color": "#b98a5a"},
	{"name": "Iron Foothills", "blurb": "Rusty racks, heavy things, and people who never re-rack them.", "color": "#d95926"},
	{"name": "Chalk Canyon", "blurb": "Tall walls. Small holds. Big feelings.", "color": "#199e70"},
	{"name": "Windswept Steppe", "blurb": "An endless road and a headwind in every direction.", "color": "#3987e5"},
	{"name": "Spoke Highlands", "blurb": "It's uphill. Both ways.", "color": "#c98500"},
	{"name": "Titan's Summit", "blurb": "The last climb is the one inside.", "color": "#c77dff"},
]

const ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

static var _bosses = null
static var _by_id = null


## The six zones, in order (read-only).
static func zones() -> Array:
	return ZONES


static func _b(id: String, boss_name: String, epithet: String, zone: int, hp: int, weak = null, zone_boss: bool = false, reward_item = null) -> Dictionary:
	var boss = {
		"id": id,
		"name": boss_name,
		"epithet": epithet,
		"zone": zone,
		"hp": hp,
		"xp": TTUtil.jsround((hp * (0.15 if zone_boss else 0.1)) / 10.0) * 10,
		"zoneBoss": zone_boss,
	}
	if weak != null:
		boss["weak"] = weak
	if reward_item != null:
		boss["rewardItem"] = reward_item
	return boss


## The 24 story bosses, in campaign order (do not mutate).
static func bosses() -> Array:
	if _bosses == null:
		_bosses = [
			# --- The Couch Kingdom ---------------------------------------------------
			_b("snooze_button", "Snooze Button", "“Five more minutes.”", 0, 400),
			_b("couch_potato", "Couch Potato", "Has not moved since the pilot episode.", 0, 900, "run"),
			_b("elevator_imp", "Elevator Imp", "Whispers “take the lift” at every staircase.", 0, 1500, "climb"),
			_b("sunday_scaries", "The Sunday Scaries", "Lord of “I’ll start Monday.”", 0, 2500, "lift", true, "comfy_slippers"),
			# --- Iron Foothills ------------------------------------------------------
			_b("rust_mite", "Rust Mite", "Eats neglected barbells.", 1, 3000, "lift"),
			_b("ego_imp", "Ego Imp", "Adds plates you did not ask for.", 1, 3500, "climb"),
			_b("doms_demon", "DOMS Demon", "Arrives two days late. Stays for three.", 1, 4000, "ride"),
			_b("iron_golem", "Iron Golem", "Never skipped a day. Never stretched either.", 1, 6000, "lift", true, "golem_bracers"),
			# --- Chalk Canyon --------------------------------------------------------
			_b("greasy_sloper", "Greasy Sloper", "Nobody has ever held it. Nobody.", 2, 6000, "climb"),
			_b("pump_wraith", "Pump Wraith", "Fills forearms with concrete.", 2, 7000, "run"),
			_b("gravity_gremlin", "Gravity Gremlin", "Turns it up when you are on the crux.", 2, 8000, "climb"),
			_b("crux_wyvern", "The Crux Wyvern", "Guards the last move of every project.", 2, 11000, "climb", true, "wyvern_chalk_bag"),
			# --- Windswept Steppe ----------------------------------------------------
			_b("side_stitch", "Side Stitch", "Small. Sharp. Punctual.", 3, 10000, "run"),
			_b("blister_blob", "Blister Blob", "Loves new shoes.", 3, 11000, "ride"),
			_b("headwind_wraith", "Headwind Wraith", "Somehow blowing from all four directions.", 3, 12000, "run"),
			_b("the_wall", "The Wall", "Lives at kilometre thirty-two.", 3, 16000, "run", true, "wallbreaker_visor"),
			# --- Spoke Highlands -----------------------------------------------------
			_b("pothole_pixie", "Pothole Pixie", "Hides in every shadow on the descent.", 4, 14000, "ride"),
			_b("flat_tire_fiend", "Flat Tire Fiend", "Strikes furthest from home.", 4, 15000, "ride"),
			_b("bonk_beast", "Bonk Beast", "You should have eaten something.", 4, 17000, "lift"),
			_b("col_du_doom", "Col du Doom", "Twenty-one hairpins. Averages eleven percent.", 4, 22000, "ride", true, "chainring_shield"),
			# --- Titan's Summit ------------------------------------------------------
			_b("plateau_giant", "Plateau Giant", "Flat on top. Goes on forever.", 5, 20000, "climb"),
			_b("excuse_hydra", "Excuse Hydra", "Cut one off; two more grow back.", 5, 22000, "run"),
			_b("comparison_specter", "Comparison Specter", "Shows you everyone else’s highlight reel.", 5, 25000, "lift"),
			_b("old_you", "The Old You", "Scrawny. Stubborn. Knows all your moves.", 5, 40000, null, true, "titans_laurel"),
		]
	return _bosses


## Story boss by id, or null (echo bosses are not in this table: use `boss_at`).
static func boss_by_id(id):
	if _by_id == null:
		var map = {}
		for boss in bosses():
			map[boss.id] = boss
		_by_id = map
	return _by_id.get(id)


## The boss at a campaign position. Past the final boss the trials go on forever.
static func boss_at(index) -> Dictionary:
	var list: Array = bosses()
	var i: int = int(index)
	if i < list.size():
		return list[i]
	var n: int = i - list.size()
	var numeral: String = ROMAN[n] if n < ROMAN.size() else str(n + 1)
	return {
		"id": "echo_" + str(n + 1),
		"name": "Echo of Doubt " + numeral,
		"epithet": "The summit is behind you. The echoes never stop.",
		"zone": ZONES.size() - 1,
		"hp": 30000 + 4000 * n,
		"weak": TT.DISCIPLINES[n % 4],
		"xp": 2500 + 250 * n,
		"zoneBoss": false,
	}


static func is_echo(index) -> bool:
	return index >= bosses().size()


## The story bosses of one zone: [{boss, index}] (index = campaign position).
static func bosses_in_zone(zone) -> Array:
	var out: Array = []
	var list: Array = bosses()
	for i in range(list.size()):
		if list[i].zone == zone:
			out.append({"boss": list[i], "index": i})
	return out
