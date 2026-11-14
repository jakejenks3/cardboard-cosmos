class_name Items
extends RefCounted
## The gear catalog (port of items.ts).
##
## Item: {id, name, slot, rarity, flavor, unlock, visual, discipline?, perk?}
##   slot: one of TT.SLOTS; rarity: one of TT.RARITY_ORDER
##   discipline / perk are optional: read with `item.get("discipline")` / `item.get("perk")`
## Perk: {xp?: {lift?|climb?|run?|ride?|all?: fraction (0.03 = +3%)}, luck?: fraction}
## unlock (ItemUnlock), by `unlock.kind`:
##   {"kind": "start"}                                  starter kit
##   {"kind": "drop", "minHeroLevel"?: int}             random loot
##   {"kind": "unlock", "hint": String, "check": Callable(state) -> bool,
##    "progress"?: Callable(state) -> {cur, target, unit}}
## visual (ItemVisual): {"kind": String, ...colours / flags}, exactly the TS
## objects; the optional fields of each kind are simply absent when unset:
##   headband{color} beanie{color,accent?} cap{color,accent?,visor?} helmet{color,aero?}
##   crown{color,gem} laurel{color,accent} bandana{color} headlamp{color}
##   sunglasses{color,frame?} shirt{color,accent?,pattern?: stripe|polka|reflective|hood}
##   tank{color,accent?} singlet{color,accent?} shorts{color,accent?,knee?} tights{color,accent?}
##   harness{color,shorts} chalk{} wraps{color,long?} gloves{color,fingerless?}
##   shoes{color,accent,sole?} climbshoes{color} sandals{color,wings?} cape{color,inner}
##   backpack{color,accent?} crashpad{color,accent} barbell{} shield{color,accent}
##   saddlebag{color} belt{color,buckle} chalkbag{color} pendant{color}
##   medal{ribbon,disc} bib{color} aura{style: flame|gold|rainbow|frost}

## Loot weights per rarity (legendaries never drop: they are earned).
const RARITY_WEIGHT = {
	"common": 55,
	"uncommon": 30,
	"rare": 12,
	"epic": 3,
	"legendary": 0,
}

const _PERK_LABEL = {"lift": "lifting", "climb": "climbing", "run": "running", "ride": "cycling"}

static var _all = null
static var _by_id = null


static func _start() -> Dictionary:
	return {"kind": "start"}


static func _drop(min_hero_level = null) -> Dictionary:
	var u = {"kind": "drop"}
	if min_hero_level != null:
		u["minHeroLevel"] = min_hero_level
	return u


# Threshold unlock with a progress bar.
static func _goal(hint: String, getter: Callable, target, unit: String = "count") -> Dictionary:
	var u = {"kind": "unlock", "hint": hint}
	u.merge(Goals.at_least(getter, target, unit))
	return u


# Custom unlock, optionally with its own progress.
static func _cond(hint: String, check: Callable, progress = null) -> Dictionary:
	var u = {"kind": "unlock", "hint": hint, "check": check}
	if progress is Callable:
		u["progress"] = progress
	return u


# Reward for defeating a campaign boss.
static func _boss(boss_id: String) -> Dictionary:
	var list: Array = Campaign.bosses()
	var idx: int = -1
	for i in range(list.size()):
		if list[i].id == boss_id:
			idx = i
			break
	var boss_name: String = list[idx].name if idx >= 0 else "a boss"
	var target: int = idx + 1
	return _cond(
		"Defeat " + boss_name,
		func(s): return s.campaign.defeated.has(boss_id),
		func(s): return {"cur": mini(PlayerState.defeated_count(s), target), "target": target, "unit": "count"},
	)


# -2 = nothing sent yet (VB is -1).
static func _max_send(s: Dictionary):
	return s.prs.climbMaxSend if s.prs.climbMaxSend != null else -2


static func _min_disc_level(s: Dictionary) -> int:
	var lowest: int = s.levels[TT.DISCIPLINES[0]].level
	for d in TT.DISCIPLINES:
		lowest = mini(lowest, s.levels[d].level)
	return lowest


## Every item, in catalog order (do not mutate).
static func all() -> Array:
	if _all == null:
		_all = _build()
	return _all


## Item by id, or null.
static func by_id(id):
	if _by_id == null:
		var map = {}
		for it in all():
			map[it.id] = it
		_by_id = map
	return _by_id.get(id)


## Human-readable perk lines, e.g. ["+3% lifting XP", "+10% loot luck"].
## `p` may be null (no perk) -> [].
static func perk_summary(p = null) -> Array:
	var out: Array = []
	if not (p is Dictionary):
		return out
	var xp = p.get("xp")
	if xp is Dictionary:
		for k in xp:
			var v = xp[k]
			if not TTUtil.truthy(v):
				continue
			var label: String = "all XP" if k == "all" else str(_PERK_LABEL.get(k)) + " XP"
			out.append("+" + str(TTUtil.jsround(v * 100)) + "% " + label)
	var luck = p.get("luck")
	if TTUtil.truthy(luck):
		out.append("+" + str(TTUtil.jsround(luck * 100)) + "% loot luck")
	return out


## How an item is obtained, as text.
static func unlock_hint(it: Dictionary) -> String:
	var kind = it.unlock.kind
	if kind == "drop":
		var min_lv = it.unlock.get("minHeroLevel")
		if TTUtil.truthy(min_lv):
			return "Random drop (hero Lv " + TTUtil.num_str(min_lv) + "+)"
		return "Random drop"
	if kind == "unlock":
		return it.unlock.hint
	return "Starter kit"


## Progress {cur, target, unit} towards an unlockable item, or null when the
## item is not condition-based or has no progress bar.
static func unlock_progress(it: Dictionary, s: Dictionary):
	if it.unlock.kind == "unlock" and it.unlock.has("progress"):
		return it.unlock.progress.call(s)
	return null


static func _build() -> Array:
	return [
			# --- starter kit -------------------------------------------------------
			{"id": "tee_grey", "name": "Hand-Me-Down Tee", "slot": "body", "rarity": "common", "flavor": "It has seen things. Mostly couches.", "unlock": _start(), "visual": {"kind": "shirt", "color": "#8d97a5"}},
			{"id": "shorts_navy", "name": "Gym Shorts", "slot": "legs", "rarity": "common", "flavor": "Standard issue. Pockets: questionable.", "unlock": _start(), "visual": {"kind": "shorts", "color": "#2f3f63"}},
			{"id": "trainers_worn", "name": "Worn Trainers", "slot": "feet", "rarity": "common", "flavor": "The soles remember better days.", "unlock": _start(), "visual": {"kind": "shoes", "color": "#d8dbe0", "accent": "#8d97a5", "sole": "#6b7280"}},

			# --- lifting -----------------------------------------------------------
			{"id": "chalk_dust", "name": "Chalk Dust", "slot": "hands", "rarity": "common", "discipline": "lift", "flavor": "Grip first, questions later.", "unlock": _drop(), "visual": {"kind": "chalk"}},
			{"id": "gym_gloves", "name": "Gym Gloves", "slot": "hands", "rarity": "common", "discipline": "lift", "flavor": "Protects the hands. Not the ego.", "unlock": _drop(), "visual": {"kind": "gloves", "color": "#2b2f3a"}},
			{"id": "bandana_red", "name": "Red Bandana", "slot": "head", "rarity": "common", "discipline": "lift", "flavor": "Instant +10 to intimidation.", "unlock": _drop(), "visual": {"kind": "bandana", "color": "#d93b3b"}},
			{"id": "stringer_black", "name": "Stringer", "slot": "body", "rarity": "common", "discipline": "lift", "flavor": "More strap than shirt.", "unlock": _drop(), "visual": {"kind": "tank", "color": "#22252e", "accent": "#ffc83d"}},
			{"id": "wrist_wraps", "name": "Wrist Wraps", "slot": "hands", "rarity": "uncommon", "discipline": "lift", "flavor": "Wrap it before you tap it.", "unlock": _drop(), "visual": {"kind": "wraps", "color": "#e04f4f"}},
			{"id": "tank_suns_out", "name": "'Sun's Out' Tank", "slot": "body", "rarity": "uncommon", "discipline": "lift", "flavor": "Guns out. Always.", "unlock": _goal("Log 10 lifting sessions", func(s): return s.totals.byDiscipline.lift, 10), "visual": {"kind": "tank", "color": "#ff9a3c", "accent": "#ffd166"}},
			{"id": "knee_sleeves", "name": "Knee Sleeves", "slot": "legs", "rarity": "uncommon", "discipline": "lift", "flavor": "Warm knees, deep squats.", "unlock": _goal("Log 25 lifting sessions", func(s): return s.totals.byDiscipline.lift, 25), "visual": {"kind": "shorts", "color": "#1f2430", "knee": "#3a4a6b"}},
			{"id": "lifting_straps", "name": "Lifting Straps", "slot": "hands", "rarity": "uncommon", "discipline": "lift", "flavor": "Your grip gives out before your back does. Not anymore.", "unlock": _goal("Complete 500 sets lifetime", func(s): return s.totals.liftSets, 500), "visual": {"kind": "wraps", "color": "#4b6cb7", "long": true}},
			{"id": "leather_belt", "name": "Leather Belt", "slot": "accessory", "rarity": "rare", "discipline": "lift", "flavor": "Brace. Breathe. Believe.", "perk": {"xp": {"lift": 0.03}}, "unlock": _goal("Lift 50,000 kg lifetime", func(s): return s.totals.liftVolumeKg, 50000, "kg"), "visual": {"kind": "belt", "color": "#6b3e1e", "buckle": "#d9b04c"}},
			{"id": "plate_pendant", "name": "Iron Plate Pendant", "slot": "accessory", "rarity": "rare", "discipline": "lift", "flavor": "A tiny 2.5 on a chain. Still counts.", "unlock": _goal("Lift 100 kg in a set", func(s): return s.bests.maxSetKg, 100, "kg"), "visual": {"kind": "pendant", "color": "#9aa3ad"}},
			{"id": "singlet_red", "name": "Competition Singlet", "slot": "body", "rarity": "rare", "discipline": "lift", "flavor": "Nowhere to hide. Nothing to hide.", "unlock": _goal("Lift 250,000 kg lifetime", func(s): return s.totals.liftVolumeKg, 250000, "kg"), "visual": {"kind": "singlet", "color": "#c62828", "accent": "#ffcc80"}},
			{"id": "barbell_back", "name": "Barbell of Burden", "slot": "back", "rarity": "epic", "discipline": "lift", "flavor": "You carry it everywhere now. Metaphorically. And literally.", "perk": {"xp": {"lift": 0.05}}, "unlock": _goal("Lift 1,000,000 kg lifetime", func(s): return s.totals.liftVolumeKg, 1000000, "kg"), "visual": {"kind": "barbell"}},
			{"id": "iron_crown", "name": "Crown of Iron", "slot": "head", "rarity": "legendary", "discipline": "lift", "flavor": "Heavy is the head. Heavier is the bar.", "perk": {"xp": {"lift": 0.08}}, "unlock": _goal("Reach lifting level 30", func(s): return s.levels.lift.level, 30, "level"), "visual": {"kind": "crown", "color": "#aab4c0", "gem": "#ff5252"}},

			# --- climbing ----------------------------------------------------------
			{"id": "chalk_bag", "name": "Chalk Bag", "slot": "accessory", "rarity": "common", "discipline": "climb", "flavor": "Dip, clap, send.", "unlock": _goal("Log a climbing session", func(s): return s.totals.byDiscipline.climb, 1), "visual": {"kind": "chalkbag", "color": "#5c6bc0"}},
			{"id": "beanie_green", "name": "Crag Beanie", "slot": "head", "rarity": "common", "discipline": "climb", "flavor": "Worn indoors. Worn in summer. Worn always.", "unlock": _drop(), "visual": {"kind": "beanie", "color": "#3f8f5a", "accent": "#2c6b42"}},
			{"id": "approach_shoes", "name": "Approach Shoes", "slot": "feet", "rarity": "common", "discipline": "climb", "flavor": "For the walk to the wall. The real workout.", "unlock": _drop(), "visual": {"kind": "shoes", "color": "#7a5c3e", "accent": "#c7a27a", "sole": "#3b2a1a"}},
			{"id": "headlamp", "name": "Headlamp", "slot": "head", "rarity": "uncommon", "discipline": "climb", "flavor": "Dawn patrol approved.", "unlock": _drop(), "visual": {"kind": "headlamp", "color": "#90a4ae"}},
			{"id": "beanie_sunset", "name": "Sunset Beanie", "slot": "head", "rarity": "uncommon", "discipline": "climb", "flavor": "Golden hour, all day.", "unlock": _drop(), "visual": {"kind": "beanie", "color": "#ff7043", "accent": "#ffca28"}},
			{"id": "climbing_shoes", "name": "Climbing Shoes", "slot": "feet", "rarity": "uncommon", "discipline": "climb", "flavor": "Two sizes too small. Perfect.", "unlock": _goal("Log 10 climbing sessions", func(s): return s.totals.byDiscipline.climb, 10), "visual": {"kind": "climbshoes", "color": "#e53935"}},
			{"id": "sendy_tank", "name": "Sendy Tank", "slot": "body", "rarity": "uncommon", "discipline": "climb", "flavor": "“Allez!” — someone, always.", "unlock": _goal("Send a V3", func(s): return Items._max_send(s), 3, "grade"), "visual": {"kind": "tank", "color": "#26a69a", "accent": "#80cbc4"}},
			{"id": "harness", "name": "Harness", "slot": "legs", "rarity": "uncommon", "discipline": "climb", "flavor": "Ready for ropes. Looks great over shorts.", "unlock": _goal("Log 25 climbing sessions", func(s): return s.totals.byDiscipline.climb, 25), "visual": {"kind": "harness", "color": "#ff8f00", "shorts": "#37474f"}},
			{"id": "crash_pad", "name": "Crash Pad", "slot": "back", "rarity": "rare", "discipline": "climb", "flavor": "A mattress you carry up a hill. For fun.", "perk": {"xp": {"climb": 0.03}}, "unlock": _goal("100 sends lifetime", func(s): return s.totals.climbSends, 100), "visual": {"kind": "crashpad", "color": "#1e88e5", "accent": "#ffb300"}},
			{"id": "crimp_gauntlets", "name": "Crimp Gauntlets", "slot": "hands", "rarity": "rare", "discipline": "climb", "flavor": "Tape on every finger. Skin is temporary.", "unlock": _goal("Send a V5", func(s): return Items._max_send(s), 5, "grade"), "visual": {"kind": "wraps", "color": "#f5f5f5"}},
			{"id": "stone_fist_wraps", "name": "Stone Fist Wraps", "slot": "hands", "rarity": "epic", "discipline": "climb", "flavor": "Your fingers are now a geological feature.", "perk": {"xp": {"climb": 0.05}}, "unlock": _goal("Send a V8", func(s): return Items._max_send(s), 8, "grade"), "visual": {"kind": "gloves", "color": "#78909c"}},
			{"id": "granite_crown", "name": "Granite Crown", "slot": "head", "rarity": "legendary", "discipline": "climb", "flavor": "Crowned by the stone itself.", "perk": {"xp": {"climb": 0.08}}, "unlock": _cond("Reach climbing level 30 or send a V10", func(s): return s.levels.climb.level >= 30 or Items._max_send(s) >= 10, func(s): return {"cur": s.levels.climb.level, "target": 30, "unit": "level"}), "visual": {"kind": "crown", "color": "#b0bec5", "gem": "#66bb6a"}},

			# --- running -----------------------------------------------------------
			{"id": "sweatband", "name": "Sweatband", "slot": "head", "rarity": "common", "discipline": "run", "flavor": "Retro. Functional. Iconic.", "unlock": _goal("Log a run", func(s): return s.totals.byDiscipline.run, 1), "visual": {"kind": "headband", "color": "#42a5f5"}},
			{"id": "running_cap", "name": "Running Cap", "slot": "head", "rarity": "common", "discipline": "run", "flavor": "Shade for the long haul.", "unlock": _drop(), "visual": {"kind": "cap", "color": "#29b6f6", "accent": "#ffffff"}},
			{"id": "visor", "name": "Race Visor", "slot": "head", "rarity": "common", "discipline": "run", "flavor": "Lets the heat out. Keeps the focus in.", "unlock": _drop(), "visual": {"kind": "cap", "color": "#ffffff", "accent": "#29b6f6", "visor": true}},
			{"id": "reflective_vest", "name": "Reflective Vest", "slot": "body", "rarity": "common", "discipline": "run", "flavor": "Be seen. Be fast.", "unlock": _drop(), "visual": {"kind": "shirt", "color": "#c6ff00", "accent": "#9e9e9e", "pattern": "reflective"}},
			{"id": "split_shorts", "name": "Split Shorts", "slot": "legs", "rarity": "common", "discipline": "run", "flavor": "Maximum freedom. Minimum fabric.", "unlock": _drop(), "visual": {"kind": "shorts", "color": "#e53935", "accent": "#ffffff"}},
			{"id": "arm_sleeves", "name": "Compression Sleeves", "slot": "hands", "rarity": "uncommon", "discipline": "run", "flavor": "Science says maybe. Vibes say yes.", "unlock": _goal("Log 25 runs", func(s): return s.totals.byDiscipline.run, 25), "visual": {"kind": "wraps", "color": "#0288d1", "long": true}},
			{"id": "race_bib", "name": "Race Bib #001", "slot": "accessory", "rarity": "uncommon", "discipline": "run", "flavor": "Pinned on. Slightly crooked. Perfect.", "unlock": _goal("Run 10 km in one go", func(s): return s.prs.longestRunM, 10000, "m"), "visual": {"kind": "bib", "color": "#ffffff"}},
			{"id": "trail_shoes", "name": "Trail Shoes", "slot": "feet", "rarity": "uncommon", "discipline": "run", "flavor": "Lugs for days.", "unlock": _goal("Run 100 km lifetime", func(s): return s.totals.runDistanceM, 100000, "m"), "visual": {"kind": "shoes", "color": "#2e7d32", "accent": "#ff7043", "sole": "#1b1b1b"}},
			{"id": "carbon_racers", "name": "Carbon Racers", "slot": "feet", "rarity": "rare", "discipline": "run", "flavor": "They feel like cheating. They are not cheating.", "perk": {"xp": {"run": 0.03}}, "unlock": _goal("Run a half marathon (21.1 km) in one go", func(s): return s.prs.longestRunM, 21097, "m"), "visual": {"kind": "shoes", "color": "#ff1744", "accent": "#ffffff", "sole": "#ffea00"}},
			{"id": "hydration_vest", "name": "Hydration Vest", "slot": "back", "rarity": "rare", "discipline": "run", "flavor": "Sips on the move.", "unlock": _goal("Run 500 km lifetime", func(s): return s.totals.runDistanceM, 500000, "m"), "visual": {"kind": "backpack", "color": "#00acc1", "accent": "#ff7043"}},
			{"id": "marathon_medal", "name": "Marathon Medal", "slot": "accessory", "rarity": "epic", "discipline": "run", "flavor": "42.195 km. Every one of them earned.", "perk": {"xp": {"run": 0.05}}, "unlock": _goal("Run a marathon (42.2 km) in one go", func(s): return s.prs.longestRunM, 42195, "m"), "visual": {"kind": "medal", "ribbon": "#1565c0", "disc": "#ffd54f"}},
			{"id": "winged_sandals", "name": "Winged Sandals", "slot": "feet", "rarity": "legendary", "discipline": "run", "flavor": "Hermes called. He wants tips.", "perk": {"xp": {"run": 0.08}}, "unlock": _cond("Reach running level 30 or run 1,000 km lifetime", func(s): return s.levels.run.level >= 30 or s.totals.runDistanceM >= 1000000, func(s): return {"cur": s.totals.runDistanceM, "target": 1000000, "unit": "m"}), "visual": {"kind": "sandals", "color": "#ffd54f", "wings": true}},

			# --- cycling -----------------------------------------------------------
			{"id": "bike_helmet", "name": "Bike Helmet", "slot": "head", "rarity": "common", "discipline": "ride", "flavor": "Brain: protected. Hair: compromised.", "unlock": _goal("Log a ride", func(s): return s.totals.byDiscipline.ride, 1), "visual": {"kind": "helmet", "color": "#eceff1"}},
			{"id": "cycling_cap", "name": "Cycling Cap", "slot": "head", "rarity": "common", "discipline": "ride", "flavor": "Brim up. Always brim up.", "unlock": _drop(), "visual": {"kind": "cap", "color": "#ab47bc", "accent": "#ffffff"}},
			{"id": "fingerless_gloves", "name": "Fingerless Gloves", "slot": "hands", "rarity": "common", "discipline": "ride", "flavor": "Tan lines included.", "unlock": _drop(), "visual": {"kind": "gloves", "color": "#263238", "fingerless": true}},
			{"id": "saddle_bag", "name": "Saddle Bag", "slot": "back", "rarity": "common", "discipline": "ride", "flavor": "Two tubes, one lever, zero regrets.", "unlock": _drop(), "visual": {"kind": "saddlebag", "color": "#424242"}},
			{"id": "sport_shades", "name": "Sport Shades", "slot": "face", "rarity": "uncommon", "discipline": "ride", "flavor": "Looking fast is half the battle.", "unlock": _drop(), "visual": {"kind": "sunglasses", "color": "#ff6f00", "frame": "#212121"}},
			{"id": "wool_jersey", "name": "Retro Wool Jersey", "slot": "body", "rarity": "uncommon", "discipline": "ride", "flavor": "Itchy. Heavy. Glorious.", "unlock": _drop(), "visual": {"kind": "shirt", "color": "#1e3a5f", "accent": "#f5e6c8", "pattern": "stripe"}},
			{"id": "team_jersey", "name": "Team Jersey", "slot": "body", "rarity": "uncommon", "discipline": "ride", "flavor": "Sponsored by nobody. Yet.", "unlock": _goal("Log 10 rides", func(s): return s.totals.byDiscipline.ride, 10), "visual": {"kind": "shirt", "color": "#7e57c2", "accent": "#ffffff", "pattern": "stripe"}},
			{"id": "clipless_shoes", "name": "Clipless Shoes", "slot": "feet", "rarity": "uncommon", "discipline": "ride", "flavor": "Click. Clack. Fall over once. Pro.", "unlock": _goal("Ride 200 km lifetime", func(s): return s.totals.rideDistanceM, 200000, "m"), "visual": {"kind": "shoes", "color": "#ffffff", "accent": "#7e57c2", "sole": "#212121"}},
			{"id": "bib_shorts", "name": "Bib Shorts", "slot": "legs", "rarity": "uncommon", "discipline": "ride", "flavor": "Padded. Dignified. Mostly.", "unlock": _goal("Ride 500 km lifetime", func(s): return s.totals.rideDistanceM, 500000, "m"), "visual": {"kind": "tights", "color": "#212121", "accent": "#7e57c2"}},
			{"id": "aero_helmet", "name": "Aero Helmet", "slot": "head", "rarity": "rare", "discipline": "ride", "flavor": "Every watt counts.", "perk": {"xp": {"ride": 0.03}}, "unlock": _goal("Ride 100 km in one go", func(s): return s.prs.longestRideM, 100000, "m"), "visual": {"kind": "helmet", "color": "#212121", "aero": true}},
			{"id": "polka_jersey", "name": "Polka Dot Jersey", "slot": "body", "rarity": "epic", "discipline": "ride", "flavor": "King of the Mountains.", "perk": {"xp": {"ride": 0.05}}, "unlock": _goal("Climb 10,000 m of elevation lifetime on the bike", func(s): return s.totals.rideElevationM, 10000, "elev"), "visual": {"kind": "shirt", "color": "#ffffff", "accent": "#e53935", "pattern": "polka"}},
			{"id": "yellow_jersey", "name": "Yellow Jersey", "slot": "body", "rarity": "legendary", "discipline": "ride", "flavor": "The maillot jaune. You know what it means.", "perk": {"xp": {"ride": 0.08}}, "unlock": _cond("Reach cycling level 30 or ride 5,000 km lifetime", func(s): return s.levels.ride.level >= 30 or s.totals.rideDistanceM >= 5000000, func(s): return {"cur": s.totals.rideDistanceM, "target": 5000000, "unit": "m"}), "visual": {"kind": "shirt", "color": "#ffeb3b", "accent": "#fbc02d"}},

			# --- general -----------------------------------------------------------
			{"id": "sunglasses_black", "name": "Black Shades", "slot": "face", "rarity": "common", "flavor": "Deal with it.", "unlock": _drop(), "visual": {"kind": "sunglasses", "color": "#111111"}},
			{"id": "hoodie_grey", "name": "Training Hoodie", "slot": "body", "rarity": "common", "flavor": "Hood up. Headphones in. Nobody talk to me.", "unlock": _drop(), "visual": {"kind": "shirt", "color": "#607d8b", "accent": "#455a64", "pattern": "hood"}},
			{"id": "joggers_black", "name": "Joggers", "slot": "legs", "rarity": "common", "flavor": "Tapered for aerodynamics. Probably.", "unlock": _drop(), "visual": {"kind": "tights", "color": "#2b2b2b", "accent": "#2b2b2b"}},
			{"id": "lucky_socks", "name": "Lucky Socks", "slot": "feet", "rarity": "uncommon", "flavor": "Unwashed since the last PR. Loot loves them.", "perk": {"luck": 0.1}, "unlock": _drop(), "visual": {"kind": "shoes", "color": "#ffffff", "accent": "#43a047", "sole": "#43a047"}},
			{"id": "ninja_headband", "name": "Ninja Headband", "slot": "head", "rarity": "uncommon", "flavor": "Silent. Deadly. Slightly too tight.", "unlock": _drop(), "visual": {"kind": "headband", "color": "#263238"}},
			{"id": "retro_kicks", "name": "Retro Kicks", "slot": "feet", "rarity": "uncommon", "flavor": "Straight out of 1985.", "unlock": _drop(), "visual": {"kind": "shoes", "color": "#f5f5f5", "accent": "#e53935", "sole": "#1e88e5"}},
			{"id": "aviators", "name": "Aviators", "slot": "face", "rarity": "rare", "flavor": "The danger zone is wherever you train.", "unlock": _drop(10), "visual": {"kind": "sunglasses", "color": "#5d4037", "frame": "#ffc83d"}},
			{"id": "galaxy_tights", "name": "Galaxy Tights", "slot": "legs", "rarity": "rare", "flavor": "Leg day, but make it cosmic.", "unlock": _drop(12), "visual": {"kind": "tights", "color": "#4527a0", "accent": "#ff80ab"}},
			{"id": "midnight_cape", "name": "Midnight Cape", "slot": "back", "rarity": "rare", "flavor": "For dramatic exits from the gym.", "unlock": _drop(18), "visual": {"kind": "cape", "color": "#283593", "inner": "#1a1f5c"}},
			{"id": "golden_mitts", "name": "Golden Mitts", "slot": "hands", "rarity": "rare", "flavor": "Everything you touch turns to gains.", "perk": {"luck": 0.05}, "unlock": _drop(20), "visual": {"kind": "gloves", "color": "#ffc83d"}},
			{"id": "champion_headband", "name": "Champion's Headband", "slot": "head", "rarity": "rare", "flavor": "Fifty sessions. Still showing up.", "perk": {"xp": {"all": 0.02}}, "unlock": _goal("Log 50 sessions", func(s): return s.totals.sessions, 50), "visual": {"kind": "headband", "color": "#ffd54f"}},
			{"id": "hero_cape", "name": "Hero Cape", "slot": "back", "rarity": "rare", "flavor": "Does nothing. Looks incredible.", "unlock": _goal("Reach hero level 10", func(s): return s.levels.hero.level, 10, "level"), "visual": {"kind": "cape", "color": "#d32f2f", "inner": "#8e0000"}},
			{"id": "golden_cape", "name": "Golden Cape", "slot": "back", "rarity": "epic", "flavor": "Flutters even indoors.", "perk": {"xp": {"all": 0.03}}, "unlock": _goal("Reach hero level 25", func(s): return s.levels.hero.level, 25, "level"), "visual": {"kind": "cape", "color": "#ffc107", "inner": "#ff8f00"}},
			{"id": "frost_aura", "name": "Frost Aura", "slot": "aura", "rarity": "rare", "flavor": "Chill under pressure.", "unlock": _drop(15), "visual": {"kind": "aura", "style": "frost"}},
			{"id": "flame_aura", "name": "Streak Flame", "slot": "aura", "rarity": "epic", "flavor": "Eight weeks of fire. Can you feel it?", "perk": {"xp": {"all": 0.03}}, "unlock": _goal("Keep an 8-week streak", func(s): return s.streak.best, 8, "weeks"), "visual": {"kind": "aura", "style": "flame"}},
			{"id": "titan_aura", "name": "Titan Aura", "slot": "aura", "rarity": "legendary", "flavor": "The room gets brighter when you walk in.", "perk": {"xp": {"all": 0.05}}, "unlock": _goal("Reach hero level 50", func(s): return s.levels.hero.level, 50, "level"), "visual": {"kind": "aura", "style": "gold"}},
			{"id": "rainbow_aura", "name": "Prismatic Aura", "slot": "aura", "rarity": "legendary", "flavor": "Master of all four paths.", "perk": {"xp": {"all": 0.05}, "luck": 0.1}, "unlock": _goal("Reach level 20 in all four disciplines", func(s): return Items._min_disc_level(s), 20, "level"), "visual": {"kind": "aura", "style": "rainbow"}},

			# --- boss trophies -----------------------------------------------------
			{"id": "comfy_slippers", "name": "Comfy Slippers", "slot": "feet", "rarity": "rare", "flavor": "Looted from the Sunday Scaries. Dangerously cosy.", "perk": {"xp": {"all": 0.02}}, "unlock": _boss("sunday_scaries"), "visual": {"kind": "shoes", "color": "#f48fb1", "accent": "#ffffff", "sole": "#ad1457"}},
			{"id": "golem_bracers", "name": "Golem's Bracers", "slot": "hands", "rarity": "epic", "discipline": "lift", "flavor": "Still warm from the forge.", "perk": {"xp": {"lift": 0.04}}, "unlock": _boss("iron_golem"), "visual": {"kind": "wraps", "color": "#b0bec5", "long": true}},
			{"id": "wyvern_chalk_bag", "name": "Wyvern-Scale Chalk Bag", "slot": "accessory", "rarity": "epic", "discipline": "climb", "flavor": "The chalk never clumps. The scales never slip.", "perk": {"xp": {"climb": 0.04}}, "unlock": _boss("crux_wyvern"), "visual": {"kind": "chalkbag", "color": "#7e57c2"}},
			{"id": "wallbreaker_visor", "name": "Wallbreaker Visor", "slot": "head", "rarity": "epic", "discipline": "run", "flavor": "Kilometre thirty-two never saw it coming.", "perk": {"xp": {"run": 0.04}}, "unlock": _boss("the_wall"), "visual": {"kind": "cap", "color": "#00bfa5", "accent": "#ffeb3b", "visor": true}},
			{"id": "chainring_shield", "name": "Chainring Shield", "slot": "back", "rarity": "epic", "discipline": "ride", "flavor": "Fifty-three teeth of pure defence.", "perk": {"xp": {"ride": 0.04}}, "unlock": _boss("col_du_doom"), "visual": {"kind": "shield", "color": "#b0bec5", "accent": "#c98500"}},
			{"id": "titans_laurel", "name": "Titan's Laurel", "slot": "head", "rarity": "legendary", "flavor": "You beat the only opponent that ever mattered.", "perk": {"xp": {"all": 0.06}, "luck": 0.1}, "unlock": _boss("old_you"), "visual": {"kind": "laurel", "color": "#ffd54f", "accent": "#7cb342"}},
	]
