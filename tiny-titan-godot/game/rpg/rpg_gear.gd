class_name RpgGear
extends RefCounted
## Battle stats of the game's own 124 items (RPG_PLAN.md 7.1), runes and sets.
## Nothing in game/items.gd changes: this is a table BY ITEM ID, so it answers
## whatever `Items.restrict_to` does in a test. Pure data and its readers.
##
##   of(item_id, plus = 0) -> {"id", "slot", "rarity", "lines": [{"k", "v"}], "unique": passive dict or null,
##                             "set": set id or ""}, or null for an id nobody knows (read it as row["set"]:
##                             `row.set` is Dictionary's own method)
##   all() / by_id(id)                    every item at +0 / one of them
##   fx(gear, plus, runes, socket, owned_items = null) -> [passive effects]
##                                        a worn kit as the engine's passive effects: the lines added up (one effect
##                                        a kind), each unique's fx, the set bonuses in force
##   totals(gear, plus, runes, socket, owned_items = null) -> {line kind: sum}
##   worn(gear, owned_items = null) -> [item ids]   what of a kit counts, in TT.SLOTS order
##   set_of(item_id) / set_count(gear, set_id, owned_items = null) / sets_in_force(gear, owned_items = null)
##   roll_rune(tier, seed) -> {"id", "k", "v", "rarity"} · rune_size(k, tier) · rune_words(rune)
##   line_words(line) · line_fx(line) · plus_cost(item_id, plus) · slot_main(slot)
##
## A LINE is {"k": one of LINE_KINDS, "v": number}. `spd`, `crit`, `gauge_rate`,
## `heal_pct` and `luck` are fractions (0.06 = 6%); `en_max` is a whole number.
##
## How a row becomes lines:
##   v = UNIT[kind] * the row's own weight * SLOT_MULT[slot] (a main line) or SECOND (a second line)
##       * RpgDefs.RARITY_MULT[rarity] * RpgDefs.plus_mult(plus, a fraction line?)
##   `en_max` does not follow that: it is 1, one more at +5 and at +10 (a pool of
##   energy six times as large would be no rule at all).
## The budget (tests/rpg_gear_test.gd holds it): nine commons at +0 that all
## favour one school give about attack 4 (hands, back, aura), armor 2.4 (head,
## body) and HP 18 (body, legs): the reference of tier 1; a kit of rares at +t
## gives about RpgDefs.ref_w(t) and ref_armor(t) from tier 3 on. Second lines
## and the schools with a slot of their own (Legs: the legs; Mind: the face)
## come on top, so the best real kit of a school sits a little above that.
##
## To add an item: one more row in ROWS (and in a set's "items" if it belongs
## to one); an epic or a legendary also needs its row in UNIQUES.

const LINE_KINDS = ["atk_push", "atk_pull", "atk_legs", "atk_speed", "atk_grip", "atk_mind", "atk_all",
	"armor", "hp", "spd", "crit", "res", "en_max", "gauge_rate", "heal_pct", "luck"]
## The lines that are fractions: they grow to RpgDefs.PLUS_PCT_CAP times at most.
const PCT_KINDS = ["spd", "crit", "gauge_rate", "heal_pct", "luck"]
## A full line of each kind on a common item at +0.
const UNIT = {"atk_push": 1.3, "atk_pull": 1.3, "atk_legs": 1.3, "atk_speed": 1.3, "atk_grip": 1.3, "atk_mind": 1.3, "atk_all": 0.9,
	"armor": 1.2, "hp": 9.0, "spd": 0.06, "crit": 0.02, "res": 5.0, "en_max": 1.0, "gauge_rate": 0.05, "heal_pct": 0.06, "luck": 0.03}
## The back is the weapon slot (the biggest number); an aura carries two lines.
const SLOT_MULT = {"back": 1.45, "aura": 0.75}
## A second line (rare and up) against a main one.
const SECOND = 0.4
## `en_max` grows by one every that many pluses.
const EN_MAX_STEP = 5

## What each slot is for, in a few words (the gear screen).
const SLOT_MAIN = {"head": "Armor", "face": "Crit chance or Mind attack", "body": "Max HP and armor", "hands": "Attack for one school",
	"legs": "Legs attack or max HP", "feet": "Speed", "back": "The weapon: the most attack", "accessory": "Crit, status resist or the gauge",
	"aura": "The gauge and a little of every attack"}

## id -> [slot, rarity, main lines, second line]. A main line is "kind" or
## "kind*weight", several with commas; the second line ("" = none) comes with
## rare and up. Slot and rarity are the item's own in game/items.gd (the test
## compares them).
const ROWS = {
	# --- head: armor ---
	"bandana_red": ["head", "common", "armor", ""],
	"beanie_green": ["head", "common", "armor", ""],
	"sweatband": ["head", "common", "res", ""],
	"running_cap": ["head", "common", "armor", ""],
	"visor": ["head", "common", "armor", ""],
	"bike_helmet": ["head", "common", "armor", ""],
	"cycling_cap": ["head", "common", "hp", ""],
	"shop_party_hat": ["head", "common", "gauge_rate", ""],
	"headlamp": ["head", "uncommon", "crit", ""],
	"beanie_sunset": ["head", "uncommon", "armor", ""],
	"ninja_headband": ["head", "uncommon", "crit", ""],
	"shop_headphones": ["head", "uncommon", "res", ""],
	"shop_cat_ears": ["head", "uncommon", "luck", ""],
	"bounty_cap": ["head", "uncommon", "armor", ""],
	"dealer_visor": ["head", "uncommon", "luck", ""],
	"aero_helmet": ["head", "rare", "armor", "spd"],
	"champion_headband": ["head", "rare", "armor", "atk_all"],
	"shop_wizard_hat": ["head", "rare", "atk_mind*0.7,armor*0.5", "luck"],
	"wallbreaker_visor": ["head", "epic", "armor", "atk_speed"],
	"shop_viking_helm": ["head", "epic", "armor", "atk_pull"],
	"iron_crown": ["head", "legendary", "armor", "atk_push"],
	"granite_crown": ["head", "legendary", "armor", "atk_grip"],
	"titans_laurel": ["head", "legendary", "armor", "atk_all"],
	"shop_halo": ["head", "legendary", "armor", "heal_pct"],
	"bounty_crown": ["head", "legendary", "armor", "luck"],
	# --- face: crit or Mind attack ---
	"sunglasses_black": ["face", "common", "crit", ""],
	"shop_3d_glasses": ["face", "common", "atk_mind", ""],
	"sport_shades": ["face", "uncommon", "crit", ""],
	"shop_neon_shades": ["face", "uncommon", "crit", ""],
	"shop_beard": ["face", "uncommon", "res", ""],
	"read_glasses": ["face", "uncommon", "atk_mind", ""],
	"aviators": ["face", "rare", "crit", "spd"],
	"shop_luchador": ["face", "rare", "crit", "atk_pull"],
	"hockey_mask": ["face", "rare", "crit", "armor"],
	# --- body: HP and armor ---
	"tee_grey": ["body", "common", "hp,armor", ""],
	"stringer_black": ["body", "common", "hp,atk_pull*0.5", ""],
	"reflective_vest": ["body", "common", "armor,spd*0.5", ""],
	"hoodie_grey": ["body", "common", "hp,armor", ""],
	"shop_tux_tee": ["body", "common", "hp,gauge_rate*0.6", ""],
	"tank_suns_out": ["body", "uncommon", "hp,atk_push*0.5", ""],
	"sendy_tank": ["body", "uncommon", "hp,atk_grip*0.5", ""],
	"wool_jersey": ["body", "uncommon", "hp*1.4,armor*0.6", ""],
	"team_jersey": ["body", "uncommon", "hp,en_max", ""],
	"shop_aloha": ["body", "uncommon", "hp,luck", ""],
	"variety_tank": ["body", "uncommon", "hp,atk_legs*0.5", ""],
	"singlet_red": ["body", "rare", "hp,armor", "atk_legs"],
	"shop_gi": ["body", "rare", "hp,armor", "crit"],
	"polka_jersey": ["body", "epic", "hp,armor", "en_max"],
	"shop_knight_plate": ["body", "epic", "hp,armor*1.5", "res"],
	"yellow_jersey": ["body", "legendary", "hp,armor", "spd"],
	# --- hands: attack for one school ---
	"chalk_dust": ["hands", "common", "atk_pull", ""],
	"gym_gloves": ["hands", "common", "atk_push", ""],
	"fingerless_gloves": ["hands", "common", "hp", ""],
	"shop_neon_wraps": ["hands", "common", "atk_all", ""],
	"wrist_wraps": ["hands", "uncommon", "atk_push", ""],
	"lifting_straps": ["hands", "uncommon", "atk_pull", ""],
	"arm_sleeves": ["hands", "uncommon", "atk_speed", ""],
	"hang_tape": ["hands", "uncommon", "atk_grip", ""],
	"crimp_gauntlets": ["hands", "rare", "atk_grip", "crit"],
	"golden_mitts": ["hands", "rare", "atk_all", "luck"],
	"shop_boxing_gloves": ["hands", "rare", "atk_push", "spd"],
	"bounty_gauntlets": ["hands", "rare", "atk_all", "armor"],
	"bounty_crushers": ["hands", "rare", "atk_push", "crit"],
	"stone_fist_wraps": ["hands", "epic", "atk_grip", "armor"],
	"golem_bracers": ["hands", "epic", "atk_pull", "armor"],
	# --- legs: Legs attack or HP ---
	"shorts_navy": ["legs", "common", "atk_legs", ""],
	"split_shorts": ["legs", "common", "atk_speed", ""],
	"joggers_black": ["legs", "common", "hp", ""],
	"shop_camo_shorts": ["legs", "common", "atk_legs", ""],
	"knee_sleeves": ["legs", "uncommon", "atk_legs", ""],
	"harness": ["legs", "uncommon", "hp", ""],
	"bib_shorts": ["legs", "uncommon", "hp", ""],
	"shop_disco_tights": ["legs", "uncommon", "atk_legs*0.6,gauge_rate*0.6", ""],
	"galaxy_tights": ["legs", "rare", "hp", "atk_mind"],
	"shop_kilt": ["legs", "rare", "atk_legs", "atk_push"],
	# --- feet: speed ---
	"trainers_worn": ["feet", "common", "spd", ""],
	"approach_shoes": ["feet", "common", "spd*0.6,atk_grip*0.5", ""],
	"lucky_socks": ["feet", "uncommon", "luck,spd*0.5", ""],
	"retro_kicks": ["feet", "uncommon", "spd", ""],
	"climbing_shoes": ["feet", "uncommon", "spd*0.5,atk_grip*0.7", ""],
	"trail_shoes": ["feet", "uncommon", "spd", ""],
	"clipless_shoes": ["feet", "uncommon", "spd*0.6,hp*0.6", ""],
	"shop_cowboy_boots": ["feet", "uncommon", "spd*0.6,armor*0.6", ""],
	"carbon_racers": ["feet", "rare", "spd", "atk_speed"],
	"comfy_slippers": ["feet", "rare", "spd", "heal_pct"],
	"shop_gold_kicks": ["feet", "rare", "spd", "luck"],
	"shop_rocket_boots": ["feet", "epic", "spd", "atk_legs"],
	"bounty_boots": ["feet", "epic", "spd", "luck"],
	"winged_sandals": ["feet", "legendary", "spd", "atk_speed"],
	# --- back: the weapon ---
	"saddle_bag": ["back", "common", "hp", ""],
	"crash_pad": ["back", "rare", "atk_grip", "hp"],
	"hydration_vest": ["back", "rare", "atk_speed", "heal_pct"],
	"midnight_cape": ["back", "rare", "atk_mind", "crit"],
	"hero_cape": ["back", "rare", "atk_all", "hp"],
	"shop_greatsword": ["back", "rare", "atk_push", "atk_pull"],
	"bounty_cloak": ["back", "rare", "atk_all", "luck"],
	"read_satchel": ["back", "rare", "atk_mind", "res"],
	"golden_cape": ["back", "epic", "atk_all", "gauge_rate"],
	"barbell_back": ["back", "epic", "atk_pull", "atk_legs"],
	"chainring_shield": ["back", "epic", "armor", "hp"],
	"shop_feather_wings": ["back", "epic", "atk_speed", "spd"],
	"shop_war_banner": ["back", "epic", "atk_all", "armor"],
	"shop_dragon_wings": ["back", "legendary", "atk_all", "atk_mind"],
	# --- accessory: crit, status resist or the gauge ---
	"chalk_bag": ["accessory", "common", "crit", ""],
	"shop_bowtie": ["accessory", "common", "gauge_rate", ""],
	"race_bib": ["accessory", "uncommon", "gauge_rate", ""],
	"shop_scarf": ["accessory", "uncommon", "res", ""],
	"press_lanyard": ["accessory", "uncommon", "crit", ""],
	"leather_belt": ["accessory", "rare", "res", "atk_legs"],
	"plate_pendant": ["accessory", "rare", "crit", "atk_push"],
	"rope_coil": ["accessory", "rare", "res", "atk_grip"],
	"marathon_medal": ["accessory", "epic", "gauge_rate", "hp"],
	"wyvern_chalk_bag": ["accessory", "epic", "crit", "atk_grip"],
	"shop_champ_belt": ["accessory", "epic", "gauge_rate", "atk_all"],
	"bounty_tooth": ["accessory", "epic", "crit", "luck"],
	# --- aura: the gauge and every attack ---
	"shop_heart_aura": ["aura", "uncommon", "heal_pct,atk_all", ""],
	"frost_aura": ["aura", "rare", "gauge_rate,atk_all", "res"],
	"shop_spark_aura": ["aura", "rare", "gauge_rate,atk_mind*0.7", "spd"],
	"shop_leaf_aura": ["aura", "rare", "gauge_rate,atk_all", "heal_pct"],
	"flame_aura": ["aura", "epic", "gauge_rate,atk_all", "crit"],
	"shop_shadow_aura": ["aura", "epic", "gauge_rate,atk_all", "spd"],
	"bounty_mark": ["aura", "epic", "gauge_rate,atk_all", "luck"],
	"titan_aura": ["aura", "legendary", "gauge_rate,atk_all", "hp"],
	"rainbow_aura": ["aura", "legendary", "gauge_rate,atk_all", "luck"],
}

## The named passive of each epic and legendary item: a small build-around.
## {"id" (RpgDefs.id_of(name)), "name", "text", "fx": [passive effects]}.
const UNIQUES = {
	"iron_crown": {"id": "progressive_overload", "name": "Progressive Overload",
		"text": "Each move of the same school as the one before it hits 8% harder, up to 24%.",
		"fx": [{"p": "combo_same", "pct": 0.08, "max": 0.24}]},
	"barbell_back": {"id": "time_under_tension", "name": "Time Under Tension",
		"text": "Your damage grows 4% with every turn you have taken, up to 24%.",
		"fx": [{"p": "ramp", "pct": 0.04, "max": 0.24}]},
	"stone_fist_wraps": {"id": "geological_feature", "name": "Geological Feature",
		"text": "Grip hits on a weakness chip 1 more guard. +15% against Broken foes.",
		"fx": [{"p": "chip", "on": "grip", "add": 1}, {"p": "vs_broken", "pct": 0.15}]},
	"granite_crown": {"id": "crowned_by_the_stone", "name": "Crowned by the Stone",
		"text": "You cannot be stunned. Breaking a foe's guard gives you a Shield of 12% of max HP.",
		"fx": [{"p": "start_status", "id": "steady", "turns": 0}, {"p": "on", "ev": "break", "do": {"k": "shield", "pct": 0.12}}]},
	"marathon_medal": {"id": "negative_split", "name": "Negative Split",
		"text": "Every third turn you get 1 more energy.",
		"fx": [{"p": "on", "ev": "turn", "every": 3, "do": {"k": "energy", "n": 1}}]},
	"winged_sandals": {"id": "hermes_wants_tips", "name": "Hermes Wants Tips",
		"text": "You act first. A kill leaves you Hasted for 2 turns.",
		"fx": [{"p": "first_turn"}, {"p": "on", "ev": "kill", "do": {"k": "status", "id": "hasted", "turns": 2}}]},
	"polka_jersey": {"id": "king_of_the_mountains", "name": "King of the Mountains",
		"text": "Every third hit you take gives you 1 energy.",
		"fx": [{"p": "on", "ev": "hit_taken", "every": 3, "do": {"k": "energy", "n": 1}}]},
	"yellow_jersey": {"id": "race_leader", "name": "Race Leader",
		"text": "You start every wave Braced for 2 turns and with 2 more energy.",
		"fx": [{"p": "start_status", "id": "braced", "turns": 2}, {"p": "on", "ev": "wave", "do": {"k": "energy", "n": 2}}]},
	"golden_cape": {"id": "showstopper", "name": "Showstopper",
		"text": "A crit adds 6 to the gauge.",
		"fx": [{"p": "on", "ev": "crit", "do": {"k": "gauge", "n": 6}}]},
	"flame_aura": {"id": "kept_burning", "name": "Kept Burning",
		"text": "A hit on a weakness sets the foe on fire for 2 turns. +20% against Burning foes.",
		"fx": [{"p": "on", "ev": "weak", "do": {"k": "status", "id": "burn", "turns": 2, "to": "target"}}, {"p": "vs_status", "id": "burn", "pct": 0.2}]},
	"titan_aura": {"id": "grand_entrance", "name": "Grand Entrance",
		"text": "The gauge starts at 30, and every wave adds 10 more.",
		"fx": [{"p": "gauge_start", "n": 30}, {"p": "on", "ev": "wave", "do": {"k": "gauge", "n": 10}}]},
	"rainbow_aura": {"id": "all_four_paths", "name": "All Four Paths",
		"text": "A move of a different school than your last one hits 15% harder.",
		"fx": [{"p": "combo_alt", "pct": 0.15}]},
	"golem_bracers": {"id": "golems_stance", "name": "Golem's Stance",
		"text": "When you Guard you get a Shield of 10% of max HP and cannot be stunned for 2 turns.",
		"fx": [{"p": "on", "ev": "guard", "do": {"k": "shield", "pct": 0.1}}, {"p": "on", "ev": "guard", "do": {"k": "status", "id": "steady", "turns": 2}}]},
	"wyvern_chalk_bag": {"id": "never_slips", "name": "Never Slips",
		"text": "The first debuff of a battle bounces off you. Your statuses land 10% more often.",
		"fx": [{"p": "bounce"}, {"p": "status_chance", "add": 0.1}]},
	"wallbreaker_visor": {"id": "through_the_wall", "name": "Through the Wall",
		"text": "Once a battle, when you drop under 35% HP, your energy is filled.",
		"fx": [{"p": "low_hp", "below": 0.35, "do": {"k": "energy", "n": 99}}]},
	"chainring_shield": {"id": "fifty_three_teeth", "name": "Fifty-Three Teeth",
		"text": "You start every wave with a Shield of 12% of max HP, and for 2 turns you strike back when hit.",
		"fx": [{"p": "start_shield", "pct": 0.12}, {"p": "start_status", "id": "counter", "turns": 2, "amount": 0.6}]},
	"titans_laurel": {"id": "not_who_you_were", "name": "Not Who You Were",
		"text": "Once a battle, under 30% HP, you heal 25% of max HP. Every new wave heals 6%.",
		"fx": [{"p": "low_hp", "below": 0.3, "do": {"k": "heal", "pct": 0.25}}, {"p": "on", "ev": "wave", "do": {"k": "heal", "pct": 0.06}}]},
	"shop_viking_helm": {"id": "pillager", "name": "Pillager",
		"text": "A kill heals 6% of max HP. Wins pay 10% more ore.",
		"fx": [{"p": "on", "ev": "kill", "do": {"k": "heal", "pct": 0.06}}, {"p": "reward", "what": "ore", "pct": 0.1}]},
	"shop_feather_wings": {"id": "light_on_your_feet", "name": "Light on Your Feet",
		"text": "You start every wave with Evade: the next hit misses you. Dodge +4%.",
		"fx": [{"p": "start_status", "id": "evade", "stacks": 1}, {"p": "dodge_add", "v": 0.04}]},
	"shop_knight_plate": {"id": "heavy_shiny_worth_it", "name": "Heavy, Shiny, Worth It",
		"text": "Defence +12%. Debuffs on you last 1 turn less.",
		"fx": [{"p": "def_pct", "pct": 0.12}, {"p": "status_turns", "on": "self_debuff", "add": -1}]},
	"shop_rocket_boots": {"id": "lift_off", "name": "Lift-Off",
		"text": "You start every wave Hasted for 2 turns.",
		"fx": [{"p": "start_status", "id": "hasted", "turns": 2}]},
	"shop_champ_belt": {"id": "opening_bell", "name": "Opening Bell",
		"text": "Your first hit on each foe does 25% more.",
		"fx": [{"p": "first_hit", "pct": 0.25}]},
	"shop_war_banner": {"id": "rally", "name": "Rally",
		"text": "You start every wave Pumped for 2 turns.",
		"fx": [{"p": "start_status", "id": "pumped", "turns": 2}]},
	"shop_shadow_aura": {"id": "before_sunrise", "name": "Before Sunrise",
		"text": "You act first, and start every wave with Focus: your next hit is a sure crit.",
		"fx": [{"p": "first_turn"}, {"p": "start_status", "id": "focus", "stacks": 1}]},
	"shop_halo": {"id": "never_skipped_a_warm_up", "name": "Never Skipped a Warm-Up",
		"text": "You start every wave with Regen for 3 turns. Healing +15%.",
		"fx": [{"p": "start_status", "id": "regen", "turns": 3}, {"p": "heal_pct", "pct": 0.15}]},
	"shop_dragon_wings": {"id": "dragons_breath", "name": "Dragon's Breath",
		"text": "A crit sets the foe on fire for 2 turns. +10% against Burning foes.",
		"fx": [{"p": "on", "ev": "crit", "do": {"k": "status", "id": "burn", "turns": 2, "to": "target"}}, {"p": "vs_status", "id": "burn", "pct": 0.1}]},
	"bounty_tooth": {"id": "still_bites", "name": "Still Bites",
		"text": "You heal for 6% of the damage you deal.",
		"fx": [{"p": "lifesteal", "pct": 0.06}]},
	"bounty_boots": {"id": "tracker", "name": "Tracker",
		"text": "You start every wave with Insight for 2 turns. A hit on a weakness adds 4 to the gauge.",
		"fx": [{"p": "start_status", "id": "insight", "turns": 2}, {"p": "on", "ev": "weak", "do": {"k": "gauge", "n": 4}}]},
	"bounty_crown": {"id": "the_kings_cut", "name": "The King's Cut",
		"text": "A kill gives you 1 energy. Wins pay 15% more ore.",
		"fx": [{"p": "on", "ev": "kill", "do": {"k": "energy", "n": 1}}, {"p": "reward", "what": "ore", "pct": 0.15}]},
	"bounty_mark": {"id": "marked_for_collection", "name": "Marked for Collection",
		"text": "A kill Marks every foe still standing: the next 2 moves on each count as hitting a weakness.",
		"fx": [{"p": "on", "ev": "kill", "do": {"k": "status", "id": "marked", "to": "all_foes"}}]},
}

## The seven sets. Two pieces worn: "two"; four: "four" as well. An item is in
## one set at most.
const SETS = {
	"iron": {"name": "Iron", "from": "Lifting gear",
		"items": ["chalk_dust", "gym_gloves", "bandana_red", "stringer_black", "wrist_wraps", "tank_suns_out", "knee_sleeves", "lifting_straps",
			"leather_belt", "plate_pendant", "singlet_red", "barbell_back", "iron_crown", "golem_bracers", "variety_tank"],
		"two": {"text": "Defence +8% and max HP +5%.", "fx": [{"p": "def_pct", "pct": 0.08}, {"p": "hp_pct", "pct": 0.05}]},
		"four": {"text": "Breaking a foe's guard leaves you Pumped for 2 turns.",
			"fx": [{"p": "on", "ev": "break", "do": {"k": "status", "id": "pumped", "turns": 2}}]}},
	"crag": {"name": "Crag", "from": "Climbing gear",
		"items": ["chalk_bag", "beanie_green", "approach_shoes", "headlamp", "beanie_sunset", "climbing_shoes", "sendy_tank", "harness", "crash_pad",
			"crimp_gauntlets", "stone_fist_wraps", "granite_crown", "wyvern_chalk_bag", "hang_tape", "rope_coil", "dealer_visor"],
		"two": {"text": "Crit chance +3%.", "fx": [{"p": "crit_add", "v": 0.03}]},
		"four": {"text": "Every second hit on a weakness gives you Evade: the next hit misses you.",
			"fx": [{"p": "on", "ev": "weak", "every": 2, "do": {"k": "status", "id": "evade"}}]}},
	"road": {"name": "Road", "from": "Running gear",
		"items": ["sweatband", "running_cap", "visor", "reflective_vest", "split_shorts", "arm_sleeves", "race_bib", "trail_shoes", "carbon_racers",
			"hydration_vest", "marathon_medal", "winged_sandals", "wallbreaker_visor"],
		"two": {"text": "Speed +8%.", "fx": [{"p": "spd_pct", "pct": 0.08}]},
		"four": {"text": "Speed moves rest 1 turn less. Dodge +3%.", "fx": [{"p": "cd", "school": "speed", "add": -1}, {"p": "dodge_add", "v": 0.03}]}},
	"wheel": {"name": "Wheel", "from": "Cycling gear",
		"items": ["bike_helmet", "cycling_cap", "fingerless_gloves", "saddle_bag", "sport_shades", "wool_jersey", "team_jersey", "clipless_shoes",
			"bib_shorts", "aero_helmet", "polka_jersey", "yellow_jersey", "chainring_shield"],
		"two": {"text": "Max HP +8% and max energy +1.", "fx": [{"p": "hp_pct", "pct": 0.08}, {"p": "en_max", "n": 1}]},
		"four": {"text": "Guard blocks 8% more and gives 1 more energy.", "fx": [{"p": "guard_pct", "v": 0.08}, {"p": "guard_en", "n": 1}]}},
	"hunter": {"name": "Hunter", "from": "Bounty rewards",
		"items": ["bounty_cap", "bounty_cloak", "bounty_gauntlets", "bounty_tooth", "bounty_boots", "bounty_crown", "bounty_mark", "bounty_crushers"],
		"two": {"text": "Wins pay 8% more ore and loot luck is 8% better.", "fx": [{"p": "reward", "what": "ore", "pct": 0.08}, {"p": "reward", "what": "luck", "pct": 0.08}]},
		"four": {"text": "A kill adds 8 to the gauge.", "fx": [{"p": "on", "ev": "kill", "do": {"k": "gauge", "n": 8}}]}},
	"scholar": {"name": "Scholar", "from": "Reading and wizardry",
		"items": ["shop_wizard_hat", "shop_headphones", "read_glasses", "shop_3d_glasses", "read_satchel", "midnight_cape", "galaxy_tights",
			"press_lanyard", "shop_spark_aura"],
		"two": {"text": "Mind +6%. Your statuses land 5% more often.", "fx": [{"p": "stat_pct", "stat": "mind", "pct": 0.06}, {"p": "status_chance", "add": 0.05}]},
		"four": {"text": "Debuffs you give last 1 turn longer.", "fx": [{"p": "status_turns", "on": "debuff", "add": 1}]}},
	"showtime": {"name": "Showtime", "from": "The shop's costumes",
		"items": ["shop_party_hat", "shop_tux_tee", "shop_neon_wraps", "shop_camo_shorts", "shop_bowtie", "shop_neon_shades", "shop_cat_ears",
			"shop_beard", "shop_aloha", "shop_disco_tights", "shop_cowboy_boots", "shop_scarf", "shop_heart_aura", "shop_boxing_gloves",
			"shop_gold_kicks", "shop_luchador", "shop_gi", "shop_kilt", "shop_greatsword", "shop_leaf_aura", "shop_viking_helm",
			"shop_feather_wings", "shop_knight_plate", "shop_rocket_boots", "shop_champ_belt", "shop_war_banner", "shop_shadow_aura",
			"shop_halo", "shop_dragon_wings"],
		"two": {"text": "The gauge fills 10% faster.", "fx": [{"p": "gauge_rate", "pct": 0.1}]},
		"four": {"text": "The gauge starts at 20.", "fx": [{"p": "gauge_start", "n": 20}]}},
}
const SET_ORDER = ["iron", "crag", "road", "wheel", "hunter", "scholar", "showtime"]

## What a rune can carry: kind -> [its size at tier 1, what each tier adds]
## (rune_size; tiers 1 to 12). Nine runes of one kind are about a third of what
## a kit of that tier gives. No `en_max`: energy comes in whole numbers.
const RUNE_LINES = {
	"atk_push": [0.3, 0.12], "atk_pull": [0.3, 0.12], "atk_legs": [0.3, 0.12], "atk_speed": [0.3, 0.12], "atk_grip": [0.3, 0.12],
	"atk_mind": [0.3, 0.12], "atk_all": [0.2, 0.07],
	"armor": [0.2, 0.07], "hp": [2.0, 1.0], "spd": [0.008, 0.0015], "crit": [0.004, 0.0008], "res": [1.0, 0.4],
	"gauge_rate": [0.01, 0.002], "heal_pct": [0.012, 0.003], "luck": [0.01, 0.002],
}
## How often each kind is rolled (the six school attacks share one weight each).
const RUNE_WEIGHT = {"atk_push": 1.0, "atk_pull": 1.0, "atk_legs": 1.0, "atk_speed": 1.0, "atk_grip": 1.0, "atk_mind": 1.0, "atk_all": 0.8,
	"armor": 1.5, "hp": 1.5, "spd": 0.8, "crit": 0.8, "res": 0.8, "gauge_rate": 0.6, "heal_pct": 0.6, "luck": 0.6}
const RUNE_TIERS = 12
## A roll lands between these shares of the size.
const RUNE_ROLL_LO = 0.9
const RUNE_ROLL_HI = 1.1

const LINE_NAMES = {"atk_push": "Push attack", "atk_pull": "Pull attack", "atk_legs": "Legs attack", "atk_speed": "Speed attack",
	"atk_grip": "Grip attack", "atk_mind": "Mind attack", "atk_all": "All attack", "armor": "Armor", "hp": "Max HP", "spd": "Speed",
	"crit": "Crit chance", "res": "Status resist", "en_max": "Max energy", "gauge_rate": "Gauge speed", "heal_pct": "Healing",
	"luck": "Loot luck"}

static var _base = null
static var _set_of = null
static var _all = null


# =============================================================================
# The table
# =============================================================================

## id -> {"slot", "rarity", "base": [{"k", "v"}]}: every row's lines on a
## common item at +0 (the rarity and the plus come on top in `of`).
static func _table() -> Dictionary:
	if _base == null:
		var map = {}
		for id in ROWS:
			var row = ROWS[id]
			var slot = str(row[0])
			var rarity = str(row[1])
			var base = []
			for part in str(row[2]).split(",", false):
				var bits = part.split("*")
				var k = str(bits[0]).strip_edges()
				var weight = float(bits[1]) if bits.size() > 1 else 1.0
				_add_line(base, k, float(UNIT.get(k, 0.0)) * weight * float(SLOT_MULT.get(slot, 1.0)))
			var second = str(row[3])
			if second != "" and RpgDefs.RARITIES.find(rarity) >= 2:
				_add_line(base, second, float(UNIT.get(second, 0.0)) * SECOND)
			map[id] = {"slot": slot, "rarity": rarity, "base": base}
		_base = map
	return _base


static func _add_line(lines: Array, k: String, v: float) -> void:
	if not UNIT.has(k):
		return
	for line in lines:
		if str(line.k) == k:
			line["v"] = float(line.v) + v
			return
	lines.append({"k": k, "v": v})


## A line's number as it is shown and used: a fraction to three decimals, HP
## and energy whole, the rest to one decimal.
static func _snap(k: String, v: float) -> Variant:
	if k == "en_max":
		return int(round(v))
	if PCT_KINDS.has(k):
		return snappedf(v, 0.001)
	if k == "hp":
		return float(round(v))
	return snappedf(v, 0.1)


## Every item id of the table, in its own order.
static func ids() -> Array:
	return ROWS.keys()


## The battle stats of one item at +plus, or null for an id nobody knows.
static func of(item_id: String, plus: int = 0) -> Variant:
	var row = _table().get(item_id)
	if row == null:
		return null
	var p = clampi(plus, 0, RpgDefs.PLUS_MAX)
	var rar = float(RpgDefs.RARITY_MULT.get(str(row.rarity), 1.0))
	var lines = []
	for b in row.base:
		var k = str(b.k)
		var v = 0.0
		if k == "en_max":
			v = 1.0 + floor(float(p) / float(EN_MAX_STEP))
		else:
			v = float(b.v) * rar * RpgDefs.plus_mult(p, PCT_KINDS.has(k))
		lines.append({"k": k, "v": _snap(k, v)})
	var unique = UNIQUES.get(item_id)
	return {"id": item_id, "slot": str(row.slot), "rarity": str(row.rarity), "lines": lines,
		"unique": unique.duplicate(true) if unique != null else null, "set": set_of(item_id)}


## Every item at +0, in the table's order.
static func all() -> Array:
	if _all == null:
		var list = []
		for id in ROWS:
			list.append(of(str(id), 0))
		_all = list
	return _all


## One item at +0, or null.
static func by_id(id: String) -> Variant:
	return of(id, 0)


## Ore for the next plus of an item (0: unknown, or already at the top).
static func plus_cost(item_id: String, plus: int) -> int:
	var row = _table().get(item_id)
	if row == null or plus >= RpgDefs.PLUS_MAX:
		return 0
	return RpgDefs.plus_cost(str(row.rarity), maxi(0, plus))


## What a slot is for, in a few words.
static func slot_main(slot: String) -> String:
	return str(SLOT_MAIN.get(slot, ""))


# =============================================================================
# Sets
# =============================================================================

## The set an item belongs to, or "".
static func set_of(item_id: String) -> String:
	if _set_of == null:
		var map = {}
		for sid in SET_ORDER:
			for id in SETS[sid].items:
				map[id] = sid
		_set_of = map
	return str(_set_of.get(item_id, ""))


## The items of a kit that count, in TT.SLOTS order: known to the table, worn
## in their own slot, and owned when `owned_items` ({id: anything}) is given.
static func worn(gear: Dictionary, owned_items = null) -> Array:
	var out = []
	var table = _table()
	for slot in TT.SLOTS:
		var id = gear.get(slot)
		if not (id is String) or id == "" or out.has(id):
			continue
		var row = table.get(id)
		if row == null or str(row.slot) != slot:
			continue
		if owned_items is Dictionary and not owned_items.has(id):
			continue
		out.append(id)
	return out


## How many pieces of a set a kit wears.
static func set_count(gear: Dictionary, set_id: String, owned_items = null) -> int:
	var n = 0
	for id in worn(gear, owned_items):
		if set_of(id) == set_id:
			n += 1
	return n


## The set bonuses a kit has: [{"id", "name", "count", "two": bool, "four": bool}],
## for every set with a piece worn, in SET_ORDER.
static func sets_in_force(gear: Dictionary, owned_items = null) -> Array:
	var out = []
	for sid in SET_ORDER:
		var n = set_count(gear, sid, owned_items)
		if n > 0:
			out.append({"id": sid, "name": str(SETS[sid].name), "count": n, "two": n >= 2, "four": n >= 4})
	return out


# =============================================================================
# A kit as passive effects
# =============================================================================

## The line sums of a worn kit: {line kind: number}. `plus` = {item id: n},
## `runes` = the saved runes, `socket` = {item id: rune id} (a rune counts once,
## in a worn item).
static func totals(gear: Dictionary, plus: Dictionary = {}, runes: Array = [], socket: Dictionary = {}, owned_items = null) -> Dictionary:
	var sums = {}
	var used = []
	for id in worn(gear, owned_items):
		var p = plus.get(id, 0)
		var it = of(id, int(p) if (p is int or p is float) else 0)
		for line in it.lines:
			sums[line.k] = float(sums.get(line.k, 0.0)) + float(line.v)
		var rid = socket.get(id)
		if rid is String and rid != "" and not used.has(rid):
			var rune = _rune(runes, rid)
			if rune != null:
				used.append(rid)
				sums[rune.k] = float(sums.get(rune.k, 0.0)) + float(rune.v)
	for k in sums.keys():
		sums[k] = _snap(k, float(sums[k])) if k == "en_max" else snappedf(float(sums[k]), 0.001)
	return sums


## A saved rune by id, when it is one a socket can use.
static func _rune(runes: Array, rid: String) -> Variant:
	for r in runes:
		if r is Dictionary and str(r.get("id", "")) == rid and RUNE_LINES.has(str(r.get("k", ""))) and (r.get("v") is int or r.get("v") is float):
			return r
	return null


## A line as the engine's passive effect.
static func line_fx(line: Dictionary) -> Dictionary:
	var k = str(line.get("k", ""))
	var v = line.get("v", 0.0)
	match k:
		"armor":
			return {"p": "armor", "v": float(v)}
		"hp":
			return {"p": "hp", "v": float(v)}
		"spd":
			return {"p": "spd_pct", "pct": float(v)}
		"crit":
			return {"p": "crit_add", "v": float(v)}
		"res":
			return {"p": "res_add", "v": float(v)}
		"en_max":
			return {"p": "en_max", "n": int(round(float(v)))}
		"gauge_rate":
			return {"p": "gauge_rate", "pct": float(v)}
		"heal_pct":
			return {"p": "heal_pct", "pct": float(v)}
		"luck":
			return {"p": "reward", "what": "luck", "pct": float(v)}
	if k.begins_with("atk_"):
		return {"p": "atk", "school": k.substr(4), "v": float(v)}
	return {}


## The passive effects of a worn kit: `gear` = {slot: item id}. The lines of
## every item and socketed rune, added up (one effect a kind, in LINE_KINDS
## order), then each unique's effects, then the set bonuses in force. An id
## the table does not know, one in the wrong slot, or one not in `owned_items`
## when that is given, is skipped.
static func fx(gear: Dictionary, plus: Dictionary = {}, runes: Array = [], socket: Dictionary = {}, owned_items = null) -> Array:
	var out = []
	var sums = totals(gear, plus, runes, socket, owned_items)
	for k in LINE_KINDS:
		if sums.has(k) and float(sums[k]) != 0.0:
			out.append(line_fx({"k": k, "v": sums[k]}))
	for id in worn(gear, owned_items):
		var unique = UNIQUES.get(id)
		if unique != null:
			out.append_array(unique.fx.duplicate(true))
	for s in sets_in_force(gear, owned_items):
		if s.two:
			out.append_array(SETS[s.id].two.fx.duplicate(true))
		if s.four:
			out.append_array(SETS[s.id].four.fx.duplicate(true))
	return out


# =============================================================================
# Runes
# =============================================================================

## The size of a rune line of that kind at a tier (1 to 12), before its rarity.
static func rune_size(k: String, tier: int) -> float:
	var row = RUNE_LINES.get(k)
	if row == null:
		return 0.0
	return float(row[0]) + float(row[1]) * float(clampi(tier, 1, RUNE_TIERS) - 1)


## One of a list of [thing, weight] by a roll in 0..1.
static func _pick(pairs: Array, roll: float):
	var sum = 0.0
	for p in pairs:
		sum += float(p[1])
	var at = roll * sum
	for p in pairs:
		at -= float(p[1])
		if at < 0.0:
			return p[0]
	return pairs[pairs.size() - 1][0]


## A rune of that tier: {"id", "k", "v", "rarity"}. The same tier and seed give
## the same rune; the id is made from the seed alone, so the caller hands out
## a seed once.
static func roll_rune(tier: int, rune_seed: int) -> Dictionary:
	var t = clampi(tier, 1, RUNE_TIERS)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("rune:%d:%d" % [t, rune_seed])
	var kinds = []
	for k in LINE_KINDS:
		if RUNE_LINES.has(k):
			kinds.append([k, float(RUNE_WEIGHT.get(k, 1.0))])
	var kind = str(_pick(kinds, rng.randf()))
	# better odds the deeper the road goes
	var rarity = str(_pick([["common", maxf(10.0, 60.0 - 4.0 * float(t))], ["uncommon", 30.0], ["rare", 8.0 + 2.0 * float(t)],
		["epic", 2.0 + 1.5 * float(t)], ["legendary", maxf(0.0, 0.75 * float(t - 4))]], rng.randf()))
	var v = rune_size(kind, t) * float(RpgDefs.RARITY_MULT.get(rarity, 1.0)) * rng.randf_range(RUNE_ROLL_LO, RUNE_ROLL_HI)
	var shown = snappedf(v, 0.001) if PCT_KINDS.has(kind) else (maxf(1.0, float(round(v))) if kind == "hp" else maxf(0.1, snappedf(v, 0.1)))
	return {"id": "rn%x" % (rune_seed & 0x7fffffffffffffff), "k": kind, "v": shown, "rarity": rarity}


## A rune in words: "Push attack +1.2".
static func rune_words(rune: Dictionary) -> String:
	return line_words(rune)


# =============================================================================
# Words
# =============================================================================

static func _pct(x) -> String:
	return TTUtil.num_str(snappedf(float(x) * 100.0, 0.1)) + "%"


## A line in words: "Push attack +6", "Speed +6%", "The gauge fills 5% faster".
static func line_words(line: Dictionary) -> String:
	var k = str(line.get("k", ""))
	if not LINE_NAMES.has(k):
		return ""
	var v = line.get("v", 0.0)
	if k == "gauge_rate":
		return "The gauge fills %s faster" % _pct(v)
	if PCT_KINDS.has(k):
		return "%s +%s" % [str(LINE_NAMES[k]), _pct(v)]
	if k == "en_max":
		return "Max energy +%d" % int(round(float(v)))
	return "%s +%s" % [str(LINE_NAMES[k]), TTUtil.num_str(snappedf(float(v), 0.1))]
