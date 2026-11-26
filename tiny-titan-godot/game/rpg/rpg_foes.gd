class_name RpgFoes
extends RefCounted
## Foes and what they do (RPG_PLAN.md 8.3). Pure data: two const tables (the
## foes and their moves), their readers, and `make`, which turns a foe of the
## table into a battle unit with the numbers SOLVED from the reference hero
## (RpgDefs.foe_hp, foe_atk, foe_def, foe_spd): no foe number is typed in.
##
## A foe, as `all()` / `by_id()` give it (every key always there):
##   {"id", "name", "region", "role" (a key of RpgDefs.ROLES),
##    "weak": [2 attack schools], "resist": [0 or 1 attack school],
##    "guard": int or null (null = the role's pips),
##    "moves": [foe move ids] (every move it can use: pattern, rules and phases),
##    "pattern": [foe move ids] (done in this order, round and round),
##    "rules": [{"if": "hp_below"|"ally_hurt"|"turn_mod"|"alone"|"hero_has"|"self_lacks", "v", "use": move id, "once": bool}],
##        looked at before the pattern, in order; the first that holds is used:
##        hp_below v = a share of its HP · ally_hurt v = a share: some foe of its side is under it ·
##        turn_mod v = N (every Nth of its turns) or [N, r] · alone: no other foe lives ·
##        hero_has v = a status id · self_lacks v = a status id
##    "traits": [passive effects] (the vocabulary of rpg_battle.gd; `adapt` and `quicken` are for foes),
##    "phases": [{"at": hp share, "say", "pattern", "weak", "resist", "summon": [foe ids], "fx": [effects on itself]}],
##        entered once its HP is at or under `at` (in order); what a phase leaves out stays as it was
##    "boss": bool, "elite": bool, "text"}
##
## A foe move (`move(id)`):
##   {"id", "name", "kind": "attack"|"multi"|"heavy"|"debuff"|"buff"|"heal"|"shield"|"summon"|"drain"|"bomb",
##    "power": float (ALL its hits together, in units of the foe's attack; 0 = no damage),
##    "hits": int, "windup": 0|1 (1: it spends one turn charging first, and says so),
##    "count": int (a bomb: the number of its turns until it goes off),
##    "rank": float, "target": "hero"|"self"|"ally"|"allies",
##    "fx": [effects] (after the damage, in order; an effect lands on the move's target unless it says "to"),
##    "foes": [foe ids a summon brings], "icon": an intent icon ("" = the kind's), "text"}
##   The kind is what the intent shows; what the move DOES is its power, fx and foes.
##
## To add a foe: a row in ROWS and its moves in MOVES. RpgBattle.check_foe says
## whether a row is well formed.
##
## Readers: all(), by_id(id), move(id), moves(), of_region(region), key_of(foe id, phase),
## weak_of / resist_of(foe id, phase), all_known(), guard_of(foe), words(foe).
##
## How the 56 are balanced (tests/rpg_foes_test.gd holds them to it): over its
## pattern a foe's power is about 1 a turn (a wind-up and a countdown count
## every turn they take; the Rustyard is gentler on purpose), no single hit
## passes 35% of the reference hero's HP even with everything the foe can
## stack on it, a stun never lands at more than 30% and never twice running.
## A foe's "guard" is set here where a break should be reachable in a normal
## fight (the role's pips are for foes that last).

const MOVE_DEFAULTS = {"kind": "attack", "power": 0.0, "hits": 1, "windup": 0, "count": 0, "rank": 1.0,
	"target": "hero", "fx": [], "foes": [], "icon": "", "text": ""}
const FOE_DEFAULTS = {"region": "", "role": "brute", "weak": [], "resist": [], "guard": null, "moves": [], "pattern": [],
	"rules": [], "traits": [], "phases": [], "boss": false, "elite": false, "text": ""}
## The icon an intent shows for each kind of move.
const KIND_ICONS = {"attack": "in_attack", "multi": "in_multi", "heavy": "in_heavy", "debuff": "in_debuff", "buff": "in_buff",
	"heal": "in_heal", "shield": "in_shield", "summon": "in_summon", "drain": "in_drain", "bomb": "in_bomb"}

## What a foe's trait is called on its sheet, where the engine's own phrase
## (RpgBattle.passive_words) would not say it plainly.
const TRAIT_WORDS = {"adapt": "Resists whatever school hit it last", "quicken": "Faster after every action", "ramp": "Hits harder every turn",
	"survive": "Gets back up once", "start_shield": "Starts behind a shield", "status_turns": "Its hexes last a turn longer"}
## What a foe's move can do to the hero, and what a foe gains while the hero has it.
const HEX_WORDS = {"weakened": "Can weaken you", "exposed": "Can leave you exposed", "slowed": "Can slow you", "burn": "Can burn you",
	"bleed": "Can make you bleed", "stun": "Can stun you, now and then"}
const WHILE_WORDS = {"weakened": "Hits harder while you are weakened", "exposed": "Hits harder while you are exposed",
	"slowed": "Hits harder while you are slowed", "burn": "Hits harder while you burn", "bleed": "Hits harder while you bleed"}

## What a role is called on a foe's sheet.
const ROLE_WORDS = {"swarm": "Small, and never alone", "skirmisher": "Quick on its feet", "brute": "Hits hard", "tank": "Heavily guarded",
	"caster": "Hexes from the back", "healer": "Mends its friends", "bomb": "Counts down, then goes off", "elite": "Elite", "boss": "Boss"}

## Traits that only change a foe's numbers (RpgFoes.make bakes them in): not said on its sheet.
const BAKED = ["hp", "hp_pct", "armor", "def_pct", "spd_pct", "res_add", "crit_add", "dodge_add"]

const MOVES = {
	# --- The Rustyard (gentle: the first fights anyone has) ----------------------------------------
	"nibble": {"name": "Nibble", "power": 0.8},
	"pounce": {"name": "Pounce", "power": 1.0},
	"scratch": {"name": "Scratch", "power": 0.8},
	"gnaw": {"name": "Gnaw", "kind": "multi", "power": 1.1, "hits": 2},
	"clank": {"name": "Clank", "power": 0.9},
	"plate_slam": {"name": "Plate Slam", "power": 1.3, "rank": 1.2},
	"plate_up": {"name": "Plate Up", "kind": "shield", "target": "self", "fx": [{"k": "shield", "pct": 0.12}], "text": "It hides behind itself."},
	"collar_snap": {"name": "Collar Snap", "power": 0.9},
	"loosen": {"name": "Loosen", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.75}],
		"text": "Your grip goes slack: you hit softer for a while."},
	"damp_slap": {"name": "Damp Slap", "power": 0.85},
	"wring_out": {"name": "Wring Out", "kind": "heal", "target": "ally", "fx": [{"k": "heal", "pct": 0.18}], "text": "It mops up whoever is hurt worst."},
	"bar_swing": {"name": "Bar Swing", "power": 0.9},
	"double_swing": {"name": "Double Swing", "kind": "multi", "power": 1.2, "hits": 2},
	"big_bend": {"name": "Big Bend", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2, "text": "It winds all the way back. Guard, or break it first."},
	"brace_up": {"name": "Brace Up", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "braced", "turns": 2}], "text": "It stiffens: hits hurt it less."},
	"locker_bite": {"name": "Locker Bite", "power": 1.2},
	"chomp_chomp": {"name": "Chomp Chomp", "kind": "multi", "power": 1.35, "hits": 2},
	"rust_cloud": {"name": "Rust Cloud", "kind": "debuff", "power": 0.7, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.8}],
		"text": "Rust in your eyes: you take more for a while."},
	"door_slam": {"name": "Door Slam", "kind": "heavy", "power": 1.7, "windup": 1, "rank": 1.2, "text": "The door swings wide open first. Guard."},
	"spit_laundry": {"name": "Spit Laundry", "kind": "summon", "target": "self", "foes": ["dust_bunny"], "text": "Something fluffy crawls out."},

	# --- The Greenmile: speed, the timeline, slows -------------------------------------------------
	"prickle": {"name": "Prickle", "kind": "multi", "power": 0.9, "hits": 3},
	"cling": {"name": "Cling", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.5}], "text": "It sticks to your socks."},
	"fox_snap": {"name": "Fox Snap", "power": 0.9, "rank": 0.8},
	"bramble_dash": {"name": "Bramble Dash", "kind": "multi", "power": 1.1, "hits": 2},
	"quick_step": {"name": "Quick Step", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "hasted", "turns": 3}],
		"text": "It speeds itself up. Slow it and it has to do this again."},
	"mud_ball": {"name": "Mud Ball", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.8}], "text": "Heavy shoes: you act later."},
	"sling": {"name": "Sling", "power": 1.0},
	"horn_jab": {"name": "Horn Jab", "power": 1.0},
	"pincer_lift": {"name": "Pincer Lift", "kind": "heavy", "power": 2.2, "windup": 1, "rank": 1.2, "text": "It lowers its horns and digs in."},
	"countdown": {"name": "Countdown", "kind": "bomb", "power": 4.0, "count": 3, "fx": [{"k": "self_ko"}], "text": "Be done before it is."},
	"grind": {"name": "Grind", "power": 0.8},
	"false_summit": {"name": "False Summit", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.7}], "text": "You thought that was the top."},
	"gravity": {"name": "Gravity", "kind": "multi", "power": 1.0, "hits": 3},
	"stride": {"name": "Stride", "power": 0.8, "rank": 0.9},
	"lap_kick": {"name": "Lap Kick", "kind": "multi", "power": 1.1, "hits": 3},
	"surge": {"name": "Surge", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "hasted", "turns": 2}], "text": "You sped up. So does it."},
	"finishing_kick": {"name": "Finishing Kick", "kind": "heavy", "power": 1.7, "windup": 1, "rank": 1.2, "text": "It drops back a step to take a run-up."},

	# --- Chalk Cliffs: heavy guards, breakers ------------------------------------------------------
	"pelt": {"name": "Pelt", "kind": "multi", "power": 0.9, "hits": 2},
	"rock_roll": {"name": "Rock Roll", "power": 1.1},
	"swoop": {"name": "Swoop", "power": 1.1},
	"flit": {"name": "Flit", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "evade", "stacks": 1}], "text": "Your next hit on it misses. A move of many hits gets through."},
	"screech": {"name": "Screech", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.6}], "text": "It rattles you: you hit softer."},
	"boulder_fist": {"name": "Boulder Fist", "power": 1.0},
	"harden": {"name": "Harden", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "braced", "turns": 2}], "text": "It packs itself tighter."},
	"rock_slide": {"name": "Rock Slide", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2, "text": "It leans back, slowly."},
	"chalk_puff": {"name": "Chalk Puff", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.8}], "text": "Chalk in your eyes: you take more."},
	"white_out": {"name": "White Out", "power": 1.0},
	"dust_devil": {"name": "Dust Devil", "kind": "multi", "power": 1.2, "hits": 3},
	"rope_burn": {"name": "Rope Burn", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "bleed", "turns": 3, "chance": 0.7}], "text": "It leaves a mark that keeps hurting."},
	"constrict": {"name": "Constrict", "power": 1.1},
	"whip_crack": {"name": "Whip Crack", "kind": "multi", "power": 0.9, "hits": 2, "fx": [{"k": "status", "id": "bleed", "turns": 3, "chance": 0.4}], "text": "Twice, and it may open a cut."},
	"loose_rock": {"name": "Loose Rock", "kind": "multi", "power": 1.1, "hits": 3},
	"long_shadow": {"name": "Long Shadow", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.8}], "text": "You are standing right under it."},
	"cave_in": {"name": "Cave In", "kind": "heavy", "power": 2.4, "windup": 1, "rank": 1.3, "text": "The whole roof groans. Break its guard and it never falls."},
	"talon_rake": {"name": "Talon Rake", "kind": "multi", "power": 1.35, "hits": 2},
	"wing_buffet": {"name": "Wing Buffet", "kind": "debuff", "power": 1.0, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.6}], "text": "The wind pins you to the wall."},
	"sky_dive": {"name": "Sky Dive", "kind": "heavy", "power": 2.45, "windup": 1, "rank": 1.2, "text": "It climbs out of sight. It is coming back down."},
	"take_wing": {"name": "Take Wing", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "evade", "stacks": 1}],
		"text": "It circles higher: your next hit misses. A move of many hits gets through."},

	# --- The Stacks: debuffs, cleansing, interrupts ------------------------------------------------
	"margin_bite": {"name": "Margin Bite", "kind": "multi", "power": 0.9, "hits": 3},
	"chew_notes": {"name": "Chew Notes", "kind": "debuff", "power": 0.6, "fx": [{"k": "gauge", "n": -8}], "text": "It eats some of your gauge."},
	"ink_spit": {"name": "Ink Spit", "kind": "debuff", "power": 0.4, "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.7}], "text": "The ink stings for a while. Cleanse it or wait it out."},
	"splatter": {"name": "Splatter", "power": 1.0},
	"paper_cut": {"name": "Paper Cut", "power": 0.9},
	"cover_up": {"name": "Cover Up", "kind": "shield", "target": "allies", "fx": [{"k": "shield", "pct": 0.15}], "text": "It wraps every foe in a shield."},
	"paper_lance": {"name": "Paper Lance", "power": 1.1},
	"shield_wall": {"name": "Shield Wall", "kind": "buff", "target": "allies", "fx": [{"k": "status", "id": "braced", "turns": 2}], "text": "Every foe takes less for a while."},
	"full_tilt": {"name": "Full Tilt", "kind": "heavy", "power": 1.9, "windup": 1, "rank": 1.2, "text": "It backs up to the end of the aisle."},
	"final_notice": {"name": "Final Notice", "kind": "bomb", "power": 3.5, "count": 4,
		"fx": [{"k": "status", "id": "weakened", "turns": 3}, {"k": "status", "id": "exposed", "turns": 3}, {"k": "self_ko"}],
		"text": "When it comes due you pay in health, and then in late fees."},
	"cross_reference": {"name": "Cross Reference", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "exposed", "turns": 3, "chance": 0.85}], "text": "It looks up where you are soft."},
	"see_also": {"name": "See Also", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "weakened", "turns": 3, "chance": 0.85}], "text": "It files your strength under W."},
	"footnote_barrage": {"name": "Footnote Barrage", "kind": "multi", "power": 1.2, "hits": 3},
	"ink_lash": {"name": "Ink Lash", "power": 0.9},
	"dust_shroud": {"name": "Dust Shroud", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.8}], "text": "A hundred years of dust settles on you."},
	"smudge": {"name": "Smudge", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.7}], "text": "Wet ink, and it stings."},
	"unwritten": {"name": "Unwritten", "kind": "heavy", "power": 1.7, "windup": 1, "rank": 1.2, "text": "The page goes blank. Something is about to be crossed out."},
	"last_page": {"name": "Last Page", "kind": "multi", "power": 1.2, "hits": 3, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.5}], "text": "Three cuts, and it may leave you open."},

	# --- The Ironworks: wind-up hits, Guard --------------------------------------------------------
	"rivet_pop": {"name": "Rivet Pop", "kind": "multi", "power": 0.9, "hits": 3},
	"pressure_pop": {"name": "Pressure Pop", "kind": "heavy", "power": 1.8, "windup": 1, "text": "It swells up. A pack of them swells up together."},
	"hot_foot": {"name": "Hot Foot", "kind": "multi", "power": 1.0, "hits": 2, "rank": 0.8},
	"ember_flick": {"name": "Ember Flick", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.6}], "text": "It sets your laces on fire."},
	"hammer_fall": {"name": "Hammer Fall", "power": 1.1},
	"anvil_stance": {"name": "Anvil Stance", "kind": "buff", "target": "self",
		"fx": [{"k": "status", "id": "counter", "turns": 1, "amount": 1.0}, {"k": "status", "id": "braced", "turns": 1}],
		"text": "Hit it now and it hits back. A good turn to Guard."},
	"stoke": {"name": "Stoke", "kind": "buff", "target": "allies", "fx": [{"k": "status", "id": "pumped", "turns": 2}], "text": "Every foe hits harder for a while."},
	"hot_air": {"name": "Hot Air", "power": 0.9},
	"hot_press": {"name": "Hot Press", "power": 1.0},
	"meltdown": {"name": "Meltdown", "kind": "heavy", "power": 2.3, "windup": 1, "rank": 1.2, "text": "It glows white before it swings."},
	"piston_jab": {"name": "Piston Jab", "power": 0.9},
	"clamp": {"name": "Clamp", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.8}], "text": "It holds you where the press comes down."},
	"hydraulic_press": {"name": "Hydraulic Press", "kind": "heavy", "power": 2.6, "windup": 1, "rank": 1.3, "fx": [{"k": "status", "id": "exposed", "turns": 2, "to": "self"}],
		"text": "The plate rises. After it comes down the golem is wide open."},
	"ladle_swing": {"name": "Ladle Swing", "power": 1.3},
	"hard_hat": {"name": "Hard Hat", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "braced", "turns": 2}], "text": "He pulls the brim down and takes less."},
	"slag_pour": {"name": "Slag Pour", "kind": "heavy", "power": 1.95, "windup": 1, "rank": 1.2, "fx": [{"k": "status", "id": "burn", "turns": 2, "chance": 0.5}],
		"text": "He tips the ladle, slowly, so you can watch."},
	"crucible_drop": {"name": "Crucible Drop", "kind": "heavy", "power": 1.95, "windup": 1, "rank": 1.3, "text": "The whole crucible swings over your head."},
	"shift_whistle": {"name": "Shift Whistle", "kind": "summon", "target": "self", "foes": ["rivet_mite"], "text": "He calls the next shift in."},

	# --- Mirror Marsh: healers and target order, bleed ---------------------------------------------
	"latch": {"name": "Latch", "kind": "drain", "power": 0.9, "fx": [{"k": "lifesteal", "pct": 1.5}], "text": "It drinks what it takes."},
	"gorge": {"name": "Gorge", "kind": "drain", "power": 1.1, "hits": 2, "fx": [{"k": "lifesteal", "pct": 1.5}], "text": "Two long pulls."},
	"skip_kick": {"name": "Skip Kick", "power": 0.7, "rank": 0.7},
	"belly_flop": {"name": "Belly Flop", "power": 1.2},
	"reed_cut": {"name": "Reed Cut", "kind": "debuff", "power": 0.7, "fx": [{"k": "status", "id": "bleed", "turns": 3, "chance": 0.75}], "text": "A thin cut that will not close."},
	"wail": {"name": "Wail", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.7}], "text": "It takes the fight out of you."},
	"flay": {"name": "Flay", "power": 1.0},
	"mud_sling": {"name": "Mud Sling", "power": 0.8},
	"mud_pack": {"name": "Mud Pack", "kind": "heal", "target": "ally", "fx": [{"k": "heal", "pct": 0.18}], "text": "Cool mud on whoever is hurt worst."},
	"soothing_muck": {"name": "Soothing Muck", "kind": "buff", "target": "allies", "fx": [{"k": "status", "id": "regen", "turns": 2}], "text": "Every foe mends a little each turn."},
	"shade_slash": {"name": "Shade Slash", "power": 1.0},
	"mirror_grasp": {"name": "Mirror Grasp", "kind": "debuff", "power": 0.8, "fx": [{"k": "status", "id": "bleed", "turns": 3, "chance": 0.6}], "text": "Your own hand, from the other side of the water."},
	"root_lash": {"name": "Root Lash", "kind": "drain", "power": 1.0, "fx": [{"k": "lifesteal", "pct": 1.0}], "text": "It feeds on what it takes."},
	"strangle": {"name": "Strangle", "kind": "debuff", "power": 0.7, "fx": [{"k": "status", "id": "bleed", "turns": 3, "chance": 0.7}], "text": "Thorns on the inside."},
	"bog_slam": {"name": "Bog Slam", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2, "text": "It pulls a root as thick as a leg out of the mud."},
	"take_root": {"name": "Take Root", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "regen", "turns": 2}], "text": "It digs in and starts to grow back. Hit hard now, or strip it."},
	"tangle": {"name": "Tangle", "kind": "multi", "power": 0.8, "hits": 2, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.4}], "text": "It may get round your ankles."},
	"cinch": {"name": "Cinch", "kind": "heavy", "power": 2.0, "windup": 1, "rank": 1.2, "text": "Every strand pulls tight at once."},
	"tighten": {"name": "Tighten", "kind": "debuff", "power": 0.5, "fx": [{"k": "status", "id": "bleed", "turns": 2, "chance": 0.7}], "text": "It pulls itself tight around you."},
	"retie": {"name": "Retie", "kind": "heal", "windup": 1, "target": "self", "fx": [{"k": "heal", "pct": 0.07}, {"k": "cleanse", "n": 0}],
		"text": "It starts tying itself back together. Break its guard or interrupt it and it stays undone."},
	"fray": {"name": "Fray", "kind": "summon", "target": "self", "foes": ["leech"], "text": "A strand comes loose and swims off on its own."},
	"lash_out": {"name": "Lash Out", "kind": "multi", "power": 1.0, "hits": 3},

	# --- Stormspine Ridge: stuns, countdowns, mixed packs ------------------------------------------
	"crackle": {"name": "Crackle", "kind": "multi", "power": 0.9, "hits": 2},
	"zap": {"name": "Zap", "kind": "debuff", "power": 0.9, "fx": [{"k": "status", "id": "stun", "chance": 0.15}], "text": "Now and then it locks you up for a turn."},
	"talon": {"name": "Talon", "power": 1.0},
	"gust": {"name": "Gust", "kind": "debuff", "power": 0.6, "fx": [{"k": "delay", "pct": 0.3}], "text": "It blows you back down the line: your next turn comes later."},
	"dive_bomb": {"name": "Dive Bomb", "kind": "heavy", "power": 1.9, "windup": 1, "rank": 0.9, "text": "It folds its wings."},
	"headbutt": {"name": "Headbutt", "power": 1.2},
	"frost_breath": {"name": "Frost Breath", "kind": "debuff", "power": 0.7, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.8}], "text": "Your legs go stiff with cold."},
	"ram": {"name": "Ram", "kind": "heavy", "power": 2.2, "windup": 1, "rank": 1.2, "text": "It paws the ice."},
	"drum_roll": {"name": "Drum Roll", "kind": "buff", "target": "allies", "fx": [{"k": "status", "id": "hasted", "turns": 2}], "text": "Every foe acts sooner for a while."},
	"boom": {"name": "Boom", "power": 1.0},
	"drum_solo": {"name": "Drum Solo", "kind": "multi", "power": 1.3, "hits": 3, "text": "Nobody left to play for."},
	"static_gaze": {"name": "Static Gaze", "kind": "debuff", "power": 0.6, "fx": [{"k": "status", "id": "exposed", "turns": 2, "chance": 0.8}], "text": "Your hair stands up. You take more."},
	"lightning_bolt": {"name": "Lightning Bolt", "kind": "heavy", "power": 2.4, "windup": 1, "rank": 1.2, "fx": [{"k": "status", "id": "stun", "chance": 0.15}],
		"text": "The air hums. Guard this one."},
	"stone_toss": {"name": "Stone Toss", "power": 1.0},
	"stack_stones": {"name": "Stack Stones", "kind": "shield", "target": "self", "fx": [{"k": "shield", "pct": 0.1}], "text": "It piles a few more on."},
	"rockslide": {"name": "Rockslide", "kind": "bomb", "power": 2.9, "count": 3, "text": "The stones above start to shift. Break it or interrupt it before the count runs out."},
	"thunderclap": {"name": "Thunderclap", "kind": "debuff", "power": 0.8, "fx": [{"k": "status", "id": "stun", "chance": 0.08}], "text": "Loud enough to lock you up, now and then."},
	"rain_lash": {"name": "Rain Lash", "kind": "multi", "power": 1.0, "hits": 3},
	"gathering_storm": {"name": "Gathering Storm", "kind": "bomb", "power": 2.1, "count": 3, "text": "The storm builds over three of its turns. Break it, or be Guarding when it lands."},
	"tailwind": {"name": "Tailwind", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "hasted", "turns": 2}], "text": "The wind gets behind it."},
	"the_big_one": {"name": "The Big One", "kind": "bomb", "power": 2.1, "count": 2, "text": "Two of its turns. That is all you get."},

	# --- Titan's Rest: everything ------------------------------------------------------------------
	"censer_swing": {"name": "Censer Swing", "power": 0.9},
	"chant": {"name": "Chant", "kind": "heal", "target": "ally", "fx": [{"k": "heal", "pct": 0.2}], "text": "It sings whoever is hurt worst back together."},
	"stone_blessing": {"name": "Stone Blessing", "kind": "shield", "target": "allies", "fx": [{"k": "shield", "pct": 0.12}], "text": "A skin of stone on every foe."},
	"echo_blade": {"name": "Echo Blade", "kind": "multi", "power": 1.1, "hits": 2, "text": "Once, and then its echo."},
	"resound": {"name": "Resound", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "counter", "turns": 1, "amount": 0.8}], "text": "Whatever hits it now comes straight back."},
	"shield_bash": {"name": "Shield Bash", "kind": "debuff", "power": 0.8, "fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.7}], "text": "It knocks the wind out of you."},
	"halberd_sweep": {"name": "Halberd Sweep", "power": 1.1},
	"ward": {"name": "Ward", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "braced", "turns": 2}, {"k": "status", "id": "steady", "turns": 2}],
		"text": "It plants its feet: it takes less and cannot be stunned."},
	"judgement": {"name": "Judgement", "kind": "heavy", "power": 2.5, "windup": 1, "rank": 1.3, "text": "The halberd goes up, and stays up."},
	"last_stand": {"name": "Last Stand", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "pumped", "turns": 3}], "text": "Nearly done, and angry about it."},
	"dust_wing": {"name": "Dust Wing", "kind": "drain", "power": 0.8, "fx": [{"k": "energy", "n": -1}], "text": "It takes 1 of your energy with it."},
	"moth_flutter": {"name": "Flutter", "kind": "buff", "target": "self", "fx": [{"k": "status", "id": "evade", "stacks": 1}], "text": "Your next hit on it misses."},
	"void_kiss": {"name": "Void Kiss", "kind": "debuff", "power": 0.9, "fx": [{"k": "gauge", "n": -10}], "text": "It eats some of your gauge."},
	"resonate": {"name": "Resonate", "kind": "bomb", "power": 5.0, "count": 2, "fx": [{"k": "self_ko"}], "text": "It hums louder. Two of its turns, then it bursts."},
	"key_strike": {"name": "Key Strike", "power": 1.0},
	"bar_the_way": {"name": "Bar the Way", "kind": "buff", "target": "self",
		"fx": [{"k": "status", "id": "counter", "turns": 1, "amount": 1.2}, {"k": "status", "id": "braced", "turns": 1}],
		"text": "It dares you to swing. Do not: Guard, mend or get ready."},
	"turn_the_lock": {"name": "Turn the Lock", "kind": "debuff", "power": 0.5, "fx": [{"k": "energy", "n": -2}], "text": "It locks away 2 of your energy."},
	"gate_slam": {"name": "Gate Slam", "kind": "heavy", "power": 2.4, "windup": 1, "rank": 1.2, "text": "Both doors swing back as far as they go."},
	"hollow_fist": {"name": "Hollow Fist", "power": 1.1},
	"echoing_roar": {"name": "Echoing Roar", "kind": "debuff", "power": 0.6,
		"fx": [{"k": "status", "id": "weakened", "turns": 2, "chance": 0.7}, {"k": "status", "id": "exposed", "turns": 2, "chance": 0.7}],
		"text": "It goes through you: you hit softer and take more."},
	"titans_grip": {"name": "Titan's Grip", "kind": "heavy", "power": 1.95, "windup": 1, "rank": 1.3, "text": "A hand the size of a door opens over you."},
	"stampede": {"name": "Stampede", "kind": "multi", "power": 1.2, "hits": 3},
	"quake": {"name": "Quake", "kind": "debuff", "power": 0.8, "fx": [{"k": "status", "id": "slowed", "turns": 2, "chance": 0.8}], "text": "The floor will not hold still."},
	"collapse_inward": {"name": "Collapse Inward", "kind": "bomb", "power": 1.95, "count": 3, "text": "It starts to fold in on itself. Be Guarding, or have it Broken, when the count ends."},
	"shed_stone": {"name": "Shed Stone", "kind": "summon", "target": "self", "foes": ["titan_shard"], "text": "A piece of it falls off and starts to hum."},
}

const ROWS = [
	# --- The Rustyard: weaknesses and the guard break (leans on push and legs) --------------------
	{"id": "dust_bunny", "name": "Dust Bunny", "region": "rustyard", "role": "swarm", "weak": ["push", "legs"], "guard": 1,
		"moves": ["nibble", "pounce"], "pattern": ["nibble", "nibble", "pounce"],
		"text": "It lives under the squat rack and it is not afraid of you."},
	{"id": "rust_rat", "name": "Rust Rat", "region": "rustyard", "role": "skirmisher", "weak": ["legs", "speed"], "guard": 2,
		"moves": ["scratch", "gnaw"], "pattern": ["scratch", "gnaw"],
		"text": "Quick, bitey, fond of old iron."},
	{"id": "squeaky_plate", "name": "Squeaky Plate", "region": "rustyard", "role": "tank", "weak": ["push", "grip"], "resist": ["speed"], "guard": 3,
		"moves": ["clank", "plate_slam", "plate_up"], "pattern": ["clank", "plate_slam", "plate_up"],
		"text": "A forty-five that nobody racked. It has opinions about that."},
	{"id": "loose_collar", "name": "Loose Collar", "region": "rustyard", "role": "caster", "weak": ["pull", "push"], "guard": 2,
		"moves": ["collar_snap", "loosen"], "pattern": ["collar_snap", "loosen", "collar_snap"],
		"text": "It slips. It always slips, and then so does your grip."},
	{"id": "moldy_towel", "name": "Moldy Towel", "region": "rustyard", "role": "healer", "weak": ["mind", "legs"], "resist": ["grip"], "guard": 2,
		"moves": ["damp_slap", "wring_out"], "pattern": ["damp_slap", "wring_out"],
		"text": "Left in a locker since spring. It mops up its friends, so deal with it first."},
	{"id": "bent_bar", "name": "Bent Bar", "region": "rustyard", "role": "elite", "elite": true, "weak": ["push", "legs"], "resist": ["pull"], "guard": 4,
		"moves": ["bar_swing", "double_swing", "big_bend", "brace_up"], "pattern": ["bar_swing", "double_swing", "bar_swing", "big_bend"],
		"rules": [{"if": "hp_below", "v": 0.5, "use": "brace_up", "once": true}],
		"text": "Somebody dropped it once. It never forgave anyone. Watch for the big swing."},
	{"id": "old_iron_jaw", "name": "Old Iron-Jaw", "region": "rustyard", "role": "boss", "boss": true, "weak": ["push", "legs"], "resist": ["mind"], "guard": 4,
		"moves": ["locker_bite", "rust_cloud", "door_slam", "chomp_chomp", "spit_laundry"],
		"pattern": ["locker_bite", "rust_cloud", "locker_bite", "door_slam"],
		"rules": [{"if": "alone", "v": 0, "use": "spit_laundry", "once": true}],
		"traits": [{"p": "hp_pct", "pct": -0.07}],
		"phases": [{"at": 0.5, "say": "The door bursts off its hinges!", "pattern": ["chomp_chomp", "locker_bite", "door_slam", "rust_cloud"],
			"weak": ["pull", "grip"], "resist": [], "summon": ["dust_bunny"], "fx": [{"k": "status", "id": "pumped", "turns": 2}]}],
		"text": "A locker that bites. Nobody remembers the combination."},

	# --- The Greenmile: speed, the timeline, slows (leans on speed and pull) ----------------------
	{"id": "burr", "name": "Burr", "region": "greenmile", "role": "swarm", "weak": ["pull", "grip"], "guard": 1,
		"moves": ["prickle", "cling"], "pattern": ["prickle", "prickle", "cling"],
		"text": "A handful of small hooks. They come in handfuls."},
	{"id": "briar_fox", "name": "Briar Fox", "region": "greenmile", "role": "skirmisher", "weak": ["speed", "mind"], "guard": 2,
		"moves": ["fox_snap", "bramble_dash", "quick_step"], "pattern": ["fox_snap", "bramble_dash", "fox_snap"],
		"rules": [{"if": "self_lacks", "v": "hasted", "use": "quick_step"}],
		"text": "It speeds itself up before it does anything else. Slow it down and it has to start over."},
	{"id": "mud_slinger", "name": "Mud Slinger", "region": "greenmile", "role": "caster", "weak": ["speed", "legs"], "guard": 2,
		"moves": ["mud_ball", "sling"], "pattern": ["mud_ball", "sling", "sling"],
		"traits": [{"p": "vs_status", "id": "slowed", "pct": 0.3}],
		"text": "First the mud, then the stones. The stones hurt more when you are stuck."},
	{"id": "stag_beetle", "name": "Stag Beetle", "region": "greenmile", "role": "brute", "weak": ["pull", "push"], "resist": ["grip"], "guard": 2,
		"moves": ["horn_jab", "pincer_lift"], "pattern": ["horn_jab", "horn_jab", "pincer_lift"],
		"text": "Slow, armoured, and it gets under you. Tip it over before the lift."},
	{"id": "mile_marker", "name": "Mile Marker", "region": "greenmile", "role": "bomb", "weak": ["speed", "pull"], "guard": 2,
		"moves": ["countdown"], "pattern": ["countdown"],
		"text": "It counts down. Be done before it is."},
	{"id": "the_hill", "name": "The Hill", "region": "greenmile", "role": "elite", "elite": true, "weak": ["legs", "speed"], "resist": ["push"], "guard": 5,
		"moves": ["grind", "false_summit", "gravity"], "pattern": ["grind", "false_summit", "grind", "gravity"],
		"traits": [{"p": "ramp", "pct": 0.08, "max": 0.64}],
		"text": "It gets steeper every turn. There is no pacing this one: get over it fast."},
	{"id": "the_pacer", "name": "The Pacer", "region": "greenmile", "role": "boss", "boss": true, "weak": ["speed", "pull"], "resist": ["legs"], "guard": 5,
		"moves": ["stride", "lap_kick", "surge", "finishing_kick"], "pattern": ["stride", "stride", "lap_kick", "finishing_kick"],
		"rules": [{"if": "hero_has", "v": "hasted", "use": "surge", "once": true}],
		"traits": [{"p": "hp_pct", "pct": 0.08}, {"p": "quicken", "pct": 0.04, "max": 0.32}],
		"phases": [{"at": 0.5, "say": "The Pacer finds another gear.", "pattern": ["lap_kick", "stride", "finishing_kick"],
			"weak": ["pull", "mind"], "resist": ["legs"], "summon": [], "fx": [{"k": "status", "id": "hasted", "turns": 2}]}],
		"text": "A little faster after every step. Slow it, push its turn back, or end it early."},

	# --- Chalk Cliffs: heavy guards, breakers (leans on grip and pull) ----------------------------
	{"id": "pebbling", "name": "Pebbling", "region": "chalk", "role": "swarm", "weak": ["grip", "legs"], "guard": 1,
		"moves": ["pelt", "rock_roll"], "pattern": ["pelt", "pelt", "rock_roll"],
		"traits": [{"p": "start_shield", "pct": 0.25}],
		"text": "A pebble in a chalk shell. The shell goes first."},
	{"id": "cliff_bat", "name": "Cliff Bat", "region": "chalk", "role": "skirmisher", "weak": ["grip", "speed"], "guard": 2,
		"moves": ["swoop", "flit", "screech"], "pattern": ["swoop", "flit", "swoop", "screech"],
		"text": "It is never where you swing. Catch it with something that hits more than once."},
	{"id": "scree_golem", "name": "Scree Golem", "region": "chalk", "role": "tank", "weak": ["pull", "push"], "resist": ["speed"], "guard": 4,
		"moves": ["boulder_fist", "harden", "rock_slide"], "pattern": ["boulder_fist", "harden", "boulder_fist", "rock_slide"],
		"text": "Loose rock that learned to stand up. A lot of guard: bring a move that breaks."},
	{"id": "chalk_wisp", "name": "Chalk Wisp", "region": "chalk", "role": "caster", "weak": ["pull", "mind"], "guard": 2,
		"moves": ["chalk_puff", "white_out", "dust_devil"], "pattern": ["chalk_puff", "dust_devil", "white_out"],
		"text": "It blinds you first, then lets everything else hit harder."},
	{"id": "rope_snake", "name": "Rope Snake", "region": "chalk", "role": "brute", "weak": ["pull", "grip"], "guard": 2,
		"moves": ["rope_burn", "constrict", "whip_crack"], "pattern": ["rope_burn", "constrict", "whip_crack"],
		"text": "Somebody's old rope. It leaves marks that keep on bleeding."},
	{"id": "overhang", "name": "Overhang", "region": "chalk", "role": "elite", "elite": true, "weak": ["grip", "pull"], "resist": ["legs"], "guard": 8,
		"moves": ["loose_rock", "long_shadow", "cave_in"], "pattern": ["loose_rock", "long_shadow", "cave_in"],
		"text": "More guard than anything on the cliff, and a roof that falls on a schedule. Break it in time and the roof stays up."},
	{"id": "skyhook", "name": "Skyhook", "region": "chalk", "role": "boss", "boss": true, "weak": ["grip", "pull"], "resist": [], "guard": 6,
		"moves": ["talon_rake", "wing_buffet", "sky_dive", "take_wing"], "pattern": ["talon_rake", "wing_buffet", "talon_rake", "sky_dive"],
		"traits": [{"p": "hp_pct", "pct": -0.17}, {"p": "spd_pct", "pct": 0.1}],
		"phases": [{"at": 0.5, "say": "Skyhook takes to the air. Your feet will not reach it now.", "pattern": ["sky_dive", "talon_rake", "wing_buffet", "take_wing"],
			"weak": ["grip", "speed"], "resist": ["legs"], "summon": [], "fx": [{"k": "status", "id": "evade", "stacks": 1}]}],
		"text": "The cliff drake. On the ground it rakes; in the air it dives, and the dive is the one to Guard."},

	# --- The Stacks: debuffs, cleansing, interrupts (leans on mind and speed) ---------------------
	{"id": "bookworm", "name": "Bookworm", "region": "stacks", "role": "swarm", "weak": ["mind", "speed"], "guard": 1,
		"moves": ["margin_bite", "chew_notes"], "pattern": ["margin_bite", "margin_bite", "chew_notes"],
		"text": "It eats books. It will settle for your notes."},
	{"id": "ink_blot", "name": "Ink Blot", "region": "stacks", "role": "caster", "weak": ["speed", "push"], "guard": 2,
		"moves": ["ink_spit", "splatter"], "pattern": ["ink_spit", "splatter", "splatter"],
		"text": "Its ink keeps stinging after it lands. Wash it off or shut it up first."},
	{"id": "dust_jacket", "name": "Dust Jacket", "region": "stacks", "role": "healer", "weak": ["mind", "pull"], "guard": 2,
		"moves": ["paper_cut", "cover_up"], "pattern": ["cover_up", "paper_cut", "paper_cut"],
		"text": "It wraps the others up. While it stands your hits land on paper."},
	{"id": "paper_knight", "name": "Paper Knight", "region": "stacks", "role": "tank", "weak": ["mind", "legs"], "resist": ["pull"], "guard": 3,
		"moves": ["paper_lance", "shield_wall", "full_tilt"], "pattern": ["paper_lance", "shield_wall", "paper_lance", "full_tilt"],
		"text": "Folded very carefully by somebody with time. It burns like anything."},
	{"id": "overdue_notice", "name": "Overdue Notice", "region": "stacks", "role": "bomb", "weak": ["speed", "grip"], "guard": 2,
		"moves": ["final_notice"], "pattern": ["final_notice"],
		"text": "Four turns to settle up. After that: a fine, and late fees on top."},
	{"id": "the_index", "name": "The Index", "region": "stacks", "role": "elite", "elite": true, "weak": ["mind", "speed"], "resist": ["grip"], "guard": 6,
		"moves": ["cross_reference", "see_also", "footnote_barrage"], "pattern": ["cross_reference", "footnote_barrage", "see_also", "footnote_barrage"],
		"traits": [{"p": "hp_pct", "pct": -0.25}, {"p": "status_turns", "on": "debuff", "add": 1}, {"p": "vs_status", "id": "exposed", "pct": 0.2}],
		"text": "It looks up your soft spots and files them. Its hexes last longer than anyone's: cleanse them."},
	{"id": "the_unread", "name": "The Unread", "region": "stacks", "role": "boss", "boss": true, "weak": ["mind", "speed"], "resist": ["legs"], "guard": 6,
		"moves": ["ink_lash", "dust_shroud", "smudge", "unwritten", "last_page"], "pattern": ["ink_lash", "dust_shroud", "ink_lash", "smudge", "unwritten"],
		"traits": [{"p": "hp_pct", "pct": -0.2}, {"p": "ramp", "pct": 0.015, "max": 0.15}],
		"phases": [{"at": 0.5, "say": "The pages turn themselves. Faster now.", "pattern": ["last_page", "smudge", "ink_lash", "unwritten", "dust_shroud"],
			"weak": ["speed", "grip"], "resist": ["legs"], "summon": [], "fx": [{"k": "cleanse", "n": 0}]}],
		"text": "A wraith of dust and ink. It piles hexes on you and hits a little harder every turn: do not let this one run long."},

	# --- The Ironworks: wind-up hits, Guard (leans on legs and push) ------------------------------
	{"id": "rivet_mite", "name": "Rivet Mite", "region": "ironworks", "role": "swarm", "weak": ["legs", "grip"], "guard": 1,
		"moves": ["rivet_pop", "pressure_pop"], "pattern": ["rivet_pop", "pressure_pop"],
		"text": "It pops rivets at you, then swells up for a bigger one. So do its friends, all at once."},
	{"id": "slag_imp", "name": "Slag Imp", "region": "ironworks", "role": "skirmisher", "weak": ["push", "speed"], "guard": 2,
		"moves": ["hot_foot", "ember_flick"], "pattern": ["ember_flick", "hot_foot", "hot_foot"],
		"traits": [{"p": "vs_status", "id": "burn", "pct": 0.25}],
		"text": "It sets you alight and then kicks where it burns."},
	{"id": "anvil_back", "name": "Anvil-Back", "region": "ironworks", "role": "tank", "weak": ["legs", "mind"], "resist": ["grip"], "guard": 3,
		"moves": ["hammer_fall", "anvil_stance"], "pattern": ["anvil_stance", "hammer_fall", "hammer_fall"],
		"text": "Hit an anvil and your hands ring. When it sets its feet, do something else for a turn."},
	{"id": "bellows", "name": "Bellows", "region": "ironworks", "role": "caster", "weak": ["push", "pull"], "guard": 2,
		"moves": ["stoke", "hot_air"], "pattern": ["stoke", "hot_air", "hot_air"],
		"text": "It does not hit hard. It makes everything else hit hard."},
	{"id": "molten_barbell", "name": "Molten Barbell", "region": "ironworks", "role": "brute", "weak": ["legs", "push"], "resist": ["mind"], "guard": 2,
		"moves": ["hot_press", "meltdown"], "pattern": ["hot_press", "meltdown", "hot_press"],
		"text": "It glows before it swings. Guard, or get out of the way."},
	{"id": "press_golem", "name": "Press Golem", "region": "ironworks", "role": "elite", "elite": true, "weak": ["legs", "push"], "resist": ["grip"], "guard": 6,
		"moves": ["piston_jab", "clamp", "hydraulic_press"], "pattern": ["piston_jab", "clamp", "hydraulic_press"],
		"text": "It holds you still and brings the plate down. Guard that, and then it is wide open: that is your turn."},
	{"id": "foreman_slag", "name": "Foreman Slag", "region": "ironworks", "role": "boss", "boss": true, "weak": ["legs", "push"], "resist": ["mind"], "guard": 6,
		"moves": ["ladle_swing", "hard_hat", "slag_pour", "crucible_drop", "shift_whistle"], "pattern": ["ladle_swing", "hard_hat", "slag_pour", "ladle_swing"],
		"rules": [{"if": "alone", "v": 0, "use": "shift_whistle", "once": true}],
		"traits": [{"p": "hp_pct", "pct": -0.22}],
		"phases": [{"at": 0.5, "say": "Slag pulls the big lever. Everything in the works starts to pour.", "pattern": ["crucible_drop", "ladle_swing", "hard_hat", "slag_pour"],
			"weak": ["push", "pull"], "resist": ["mind"], "summon": ["rivet_mite"], "fx": [{"k": "status", "id": "pumped", "turns": 3}]}],
		"text": "Every big hit of his is announced a turn ahead. He is counting on you not listening."},

	# --- Mirror Marsh: healers and target order, bleed (leans on mind and grip) -------------------
	{"id": "leech", "name": "Leech", "region": "marsh", "role": "skirmisher", "weak": ["grip", "pull"], "guard": 2,
		"moves": ["latch", "gorge"], "pattern": ["latch", "latch", "gorge"],
		"text": "What it takes from you it keeps. Pinch it off quickly."},
	{"id": "bog_hopper", "name": "Bog Hopper", "region": "marsh", "role": "swarm", "weak": ["mind", "legs"], "guard": 1,
		"moves": ["skip_kick", "belly_flop"], "pattern": ["skip_kick", "skip_kick", "belly_flop"],
		"text": "Small kicks, very often. Then all of it lands on you at once."},
	{"id": "reed_wraith", "name": "Reed Wraith", "region": "marsh", "role": "caster", "weak": ["mind", "speed"], "guard": 2,
		"moves": ["reed_cut", "wail", "flay"], "pattern": ["reed_cut", "flay", "reed_cut", "wail"],
		"traits": [{"p": "vs_status", "id": "bleed", "pct": 0.3}],
		"text": "Thin cuts that add up, and it hits harder while you bleed."},
	{"id": "mud_mender", "name": "Mud Mender", "region": "marsh", "role": "healer", "weak": ["grip", "push"], "guard": 2,
		"moves": ["mud_sling", "mud_pack", "soothing_muck"], "pattern": ["mud_sling", "soothing_muck", "mud_sling"],
		"rules": [{"if": "ally_hurt", "v": 0.5, "use": "mud_pack"}],
		"text": "Whoever you hurt, it patches. It goes first or nothing else goes at all."},
	{"id": "mirror_shade", "name": "Mirror Shade", "region": "marsh", "role": "brute", "weak": ["mind", "grip"], "guard": 3,
		"moves": ["shade_slash", "mirror_grasp"], "pattern": ["shade_slash", "shade_slash", "mirror_grasp"],
		"traits": [{"p": "hp_pct", "pct": -0.35}, {"p": "adapt"}],
		"text": "It learns whatever hit it last. Never the same school twice."},
	{"id": "knotroot", "name": "Knotroot", "region": "marsh", "role": "elite", "elite": true, "weak": ["mind", "grip"], "resist": ["legs"], "guard": 6,
		"traits": [{"p": "hp_pct", "pct": -0.2}],
		"moves": ["root_lash", "strangle", "bog_slam", "take_root"], "pattern": ["root_lash", "strangle", "root_lash", "bog_slam"],
		"rules": [{"if": "hp_below", "v": 0.5, "use": "take_root", "once": true}],
		"text": "It feeds on every hit it lands, and at half health it digs in to grow back. That is when to spend everything."},
	{"id": "the_knot", "name": "The Knot", "region": "marsh", "role": "boss", "boss": true, "weak": ["mind", "grip"], "resist": ["push"], "guard": 6,
		"moves": ["tangle", "tighten", "cinch", "retie", "fray", "lash_out"], "pattern": ["tangle", "tighten", "tangle", "cinch"],
		"rules": [{"if": "hp_below", "v": 0.85, "use": "retie", "once": true}, {"if": "hp_below", "v": 0.3, "use": "retie", "once": true},
			{"if": "alone", "v": 0, "use": "fray", "once": true}],
		"traits": [{"p": "hp_pct", "pct": -0.27}],
		"phases": [{"at": 0.5, "say": "The Knot comes apart. Now there is more of it.", "pattern": ["lash_out", "tighten", "cinch", "tangle"],
			"weak": ["mind", "pull"], "resist": ["push"], "summon": ["bog_hopper"], "fx": []}],
		"text": "It ties itself back together if you let it, and what you cut off keeps swimming."},

	# --- Stormspine Ridge: stuns, countdowns, mixed packs (spread evenly) -------------------------
	{"id": "static_mote", "name": "Static Mote", "region": "stormspine", "role": "swarm", "weak": ["grip", "mind"], "guard": 1,
		"moves": ["crackle", "zap"], "pattern": ["crackle", "zap", "crackle"],
		"text": "A spark with a grudge. Now and then one of them locks you up for a turn."},
	{"id": "gale_hawk", "name": "Gale Hawk", "region": "stormspine", "role": "skirmisher", "weak": ["speed", "grip"], "guard": 2,
		"moves": ["talon", "gust", "dive_bomb"], "pattern": ["talon", "gust", "dive_bomb"],
		"text": "It blows you back down the line, then dives while you are still getting up."},
	{"id": "rime_goat", "name": "Rime Goat", "region": "stormspine", "role": "brute", "weak": ["push", "legs"], "resist": ["grip"], "guard": 2,
		"moves": ["headbutt", "frost_breath", "ram"], "pattern": ["frost_breath", "headbutt", "ram"],
		"traits": [{"p": "start_status", "id": "steady", "turns": 0}],
		"text": "Sure-footed on ice: it cannot be stunned. It freezes your legs, then takes a run at you."},
	{"id": "thunder_drum", "name": "Thunder Drum", "region": "stormspine", "role": "caster", "weak": ["push", "mind"], "guard": 2,
		"moves": ["drum_roll", "boom", "drum_solo"], "pattern": ["drum_roll", "boom", "boom"],
		"rules": [{"if": "alone", "v": 0, "use": "drum_solo"}],
		"text": "It sets the beat and everything around it keeps up. Silence it first."},
	{"id": "storm_eye", "name": "Storm Eye", "region": "stormspine", "role": "caster", "weak": ["pull", "legs"], "guard": 2,
		"moves": ["static_gaze", "lightning_bolt"], "pattern": ["static_gaze", "lightning_bolt"],
		"text": "It looks at you, then it aims. The bolt is the one to Guard."},
	{"id": "cairn_giant", "name": "Cairn Giant", "region": "stormspine", "role": "elite", "elite": true, "weak": ["push", "legs"], "resist": ["speed"], "guard": 6,
		"moves": ["stone_toss", "stack_stones", "rockslide"], "pattern": ["stone_toss", "stack_stones", "rockslide"],
		"text": "A pile of stones that walks. It starts a rockslide and counts it down out loud: break it before three."},
	{"id": "thunderhead", "name": "Thunderhead", "region": "stormspine", "role": "boss", "boss": true, "weak": ["speed", "mind"], "resist": ["legs"], "guard": 6,
		"moves": ["thunderclap", "rain_lash", "gathering_storm", "tailwind", "the_big_one"], "pattern": ["rain_lash", "thunderclap", "gathering_storm"],
		"traits": [{"p": "hp_pct", "pct": -0.15}],
		"phases": [{"at": 0.5, "say": "The sky goes dark. There is not much time between claps now.", "pattern": ["thunderclap", "rain_lash", "the_big_one", "tailwind"],
			"weak": ["mind", "grip"], "resist": ["legs"], "summon": ["static_mote"], "fx": [{"k": "status", "id": "hasted", "turns": 2}]}],
		"text": "A storm with a face. It builds its worst hit over a count you can see: answer the count."},

	# --- Titan's Rest: everything (spread evenly) ------------------------------------------------
	{"id": "stone_acolyte", "name": "Stone Acolyte", "region": "titans_rest", "role": "healer", "weak": ["mind", "pull"], "guard": 2,
		"moves": ["censer_swing", "chant", "stone_blessing"], "pattern": ["stone_blessing", "censer_swing", "censer_swing"],
		"rules": [{"if": "ally_hurt", "v": 0.5, "use": "chant"}],
		"text": "It sings the others whole again and wraps them in stone. First on the list."},
	{"id": "echo_knight", "name": "Echo Knight", "region": "titans_rest", "role": "tank", "weak": ["push", "grip"], "resist": ["mind"], "guard": 4,
		"moves": ["echo_blade", "resound", "shield_bash"], "pattern": ["echo_blade", "resound", "shield_bash"],
		"traits": [{"p": "hp_pct", "pct": -0.3}, {"p": "survive", "pct": 0.2}],
		"text": "Everything it does happens twice. That includes falling down: the first time does not count."},
	{"id": "relic_guard", "name": "Relic Guard", "region": "titans_rest", "role": "brute", "weak": ["legs", "pull"], "resist": ["push"], "guard": 3,
		"moves": ["halberd_sweep", "ward", "judgement", "last_stand"], "pattern": ["halberd_sweep", "ward", "judgement"],
		"rules": [{"if": "hp_below", "v": 0.3, "use": "last_stand", "once": true}],
		"text": "It has stood here a thousand years and means to stand a thousand more. It gets angry when it is nearly done."},
	{"id": "void_moth", "name": "Void Moth", "region": "titans_rest", "role": "skirmisher", "weak": ["speed", "grip"], "guard": 2,
		"moves": ["dust_wing", "moth_flutter", "void_kiss"], "pattern": ["dust_wing", "moth_flutter", "void_kiss", "dust_wing"],
		"text": "It does not want your health. It wants your energy and your gauge, and it is hard to hit."},
	{"id": "titan_shard", "name": "Titan Shard", "region": "titans_rest", "role": "bomb", "weak": ["legs", "mind"], "guard": 1,
		"moves": ["resonate"], "pattern": ["resonate"],
		"text": "A splinter of the Titan with a very short fuse. Break it and the count starts over."},
	{"id": "the_gatekeeper", "name": "The Gatekeeper", "region": "titans_rest", "role": "elite", "elite": true, "weak": ["speed", "mind"], "resist": ["push"], "guard": 6,
		"traits": [{"p": "hp_pct", "pct": -0.45}],
		"moves": ["key_strike", "bar_the_way", "turn_the_lock", "gate_slam"], "pattern": ["key_strike", "bar_the_way", "turn_the_lock", "gate_slam"],
		"text": "When it bars the way, whatever you swing comes back at you. Wait it out, then go through."},
	{"id": "the_hollow_titan", "name": "The Hollow Titan", "region": "titans_rest", "role": "boss", "boss": true, "weak": ["push", "pull"], "resist": ["mind"], "guard": 6,
		"moves": ["hollow_fist", "echoing_roar", "titans_grip", "stampede", "quake", "collapse_inward", "shed_stone"],
		"pattern": ["hollow_fist", "echoing_roar", "hollow_fist", "titans_grip"],
		"traits": [{"p": "hp_pct", "pct": -0.23}],
		"phases": [
			{"at": 0.66, "say": "The Titan lets its arms fall and starts to run.", "pattern": ["stampede", "quake", "stampede", "hollow_fist"],
				"weak": ["legs", "speed"], "resist": ["push"], "summon": [], "fx": [{"k": "status", "id": "hasted", "turns": 2}]},
			{"at": 0.33, "say": "What is left of it is only will.", "pattern": ["collapse_inward", "hollow_fist", "echoing_roar", "titans_grip"],
				"weak": ["grip", "mind"], "resist": ["legs"], "summon": ["titan_shard"], "fx": [{"k": "cleanse", "n": 0}]}],
		"rules": [{"if": "hp_below", "v": 0.5, "use": "shed_stone", "once": true}],
		"text": "Three fights in one body. Each time it changes, what hurt it before stops working: bring more than one school."},
]

static var _all = null
static var _by_id = null
static var _moves = null


## Every foe, in catalog order (do not change what it returns).
static func all() -> Array:
	if _all == null:
		var list = []
		for row in ROWS:
			list.append(full(row))
		_all = list
	return _all


## A foe by id, or null.
static func by_id(id: String) -> Variant:
	if _by_id == null:
		var map = {}
		for f in all():
			map[f.id] = f
		_by_id = map
	return _by_id.get(id)


## A foe row with every key filled in (a copy).
static func full(row: Dictionary) -> Dictionary:
	var f = FOE_DEFAULTS.duplicate(true)
	for k in row:
		f[k] = row[k] if not (row[k] is Dictionary or row[k] is Array) else row[k].duplicate(true)
	f["id"] = str(row.get("id", RpgDefs.id_of(str(row.get("name", "")))))
	return f


## A foe move row with every key filled in (a copy); `id` is put in.
static func full_move(id: String, row: Dictionary) -> Dictionary:
	var m = MOVE_DEFAULTS.duplicate(true)
	for k in row:
		m[k] = row[k] if not (row[k] is Dictionary or row[k] is Array) else row[k].duplicate(true)
	m["id"] = id
	if str(m.icon) == "":
		m["icon"] = str(KIND_ICONS.get(str(m.kind), "in_attack"))
	return m


## A foe move by id, or null.
static func move(id: String) -> Variant:
	if _moves == null:
		var map = {}
		for k in MOVES:
			map[k] = full_move(k, MOVES[k])
		_moves = map
	return _moves.get(id)


## Every foe move (do not change what it returns).
static func moves() -> Array:
	move("")
	return _moves.values()


## The battle unit of a catalog foe at difficulty index `n` (RPG_PLAN.md 4.1),
## or null for an id nobody knows. `pack_size` = how many regular foes share
## the wave (each has 2 / (c + 1) of the hp and attack). `opts`:
##   "mult": float   the hp and attack share to use instead of the pack's (an elite's or boss's adds: RpgDefs.ADD_MULT)
##   "weak", "resist": [schools]   set by the setup (the hunt, the rival, an echo): shown from the start, never learned
##   "guard_add": int   more guard pips
static func make(id: String, n: float, pack_size: int = 1, opts: Dictionary = {}) -> Variant:
	var row = by_id(id)
	if row == null:
		return null
	return make_from(row, n, pack_size, opts)


## `make` for a foe row that is not in the table (the weekly rival, a test).
static func make_from(row_in: Dictionary, n: float, pack_size: int = 1, opts: Dictionary = {}) -> Dictionary:
	var row = full(row_in)
	var role = RpgDefs.role(str(row.role))
	var big = bool(row.boss) or bool(row.elite)
	var mult = 1.0
	if opts.has("mult"):
		mult = float(opts.mult)
	elif not big:
		mult = RpgDefs.pack_mult(pack_size)
	var agg = RpgBattle.aggregate(row.traits)
	var hp_max = (RpgDefs.foe_hp(n) * float(role[0]) * mult + float(agg.get("hp", 0.0))) * (1.0 + float(agg.get("hp_pct", 0.0)))
	var def = (RpgDefs.foe_def(n) * float(role[4]) + float(agg.get("armor", 0.0))) * (1.0 + float(agg.get("def_pct", 0.0)))
	var tec = RpgDefs.foe_tec(n, bool(row.elite), bool(row.boss))
	var guard = int(role[3]) if row.guard == null else int(row.guard)
	guard = maxi(0, guard + int(opts.get("guard_add", 0)))
	var set_weak = opts.get("weak") is Array and not opts.weak.is_empty()
	var weak = (opts.weak if set_weak else row.weak).duplicate()
	var resist = (opts.resist if opts.get("resist") is Array else row.resist).duplicate()
	if set_weak and not (opts.get("resist") is Array):
		resist = resist.filter(func(sc): return not weak.has(sc))
	return {
		"id": "", "side": "foe", "name": str(row.name), "foe": str(row.id), "role": str(row.role), "n": n,
		"hp": maxi(1, int(round(hp_max))), "hp_max": maxi(1, int(round(hp_max))),
		"atk": RpgDefs.foe_atk(n) * float(role[1]) * mult,
		"def": def,
		"spd": RpgDefs.foe_spd(str(row.role), n) * (1.0 + float(agg.get("spd_pct", 0.0))),
		"res": tec + float(agg.get("res_add", 0.0)), "tec": tec,
		"crit": 0.0 if bool(row.boss) else clampf(RpgDefs.FOE_CRIT + float(agg.get("crit_add", 0.0)), 0.0, 1.0),
		"dodge": clampf(float(agg.get("dodge_add", 0.0)), 0.0, 0.9),
		"at": 0.0, "alive": true, "statuses": [], "stun_guard": 0, "turns": 0,
		"weak": weak, "resist": resist, "shown": set_weak,
		"guard": guard, "guard_max": guard, "broken": false,
		"intent": {}, "pi": 0, "boss": bool(row.boss), "elite": bool(row.elite), "phase": 0, "slot": 0,
		"moves": row.moves.duplicate(), "pattern": row.pattern.duplicate(), "rules": row.rules.duplicate(true),
		"phases": row.phases.duplicate(true), "fx": row.traits.duplicate(true), "flags": {},
	}


# =============================================================================
# Readers for the world, the bestiary and the tests
# =============================================================================

## The foes of a region, by id: {"regular": [five ids, in the order they are
## met], "elite": id, "boss": id} ("" where a region has none; an unknown
## region: all empty).
static func of_region(region: String) -> Dictionary:
	var out = {"regular": [], "elite": "", "boss": ""}
	for f in all():
		if str(f.region) != region:
			continue
		if bool(f.boss):
			out["boss"] = str(f.id)
		elif bool(f.elite):
			out["elite"] = str(f.id)
		else:
			out.regular.append(str(f.id))
	return out


## The key a foe's learned weaknesses are kept under (saved.rpg.seen, a
## setup's "known"): the id, or "id#2", "id#3" once a boss has changed.
## `phase` = how many of its phases it has entered (a unit's "phase": 0 first).
static func key_of(foe_id: String, phase: int = 0) -> String:
	return foe_id if phase <= 0 else "%s#%d" % [foe_id, phase + 1]


## The weak schools of a foe in a phase (0 = as it starts; a phase that names
## none keeps the ones before it). [] for an unknown id.
static func weak_of(foe_id: String, phase: int = 0) -> Array:
	var f = by_id(foe_id)
	if f == null:
		return []
	var weak = f.weak.duplicate()
	for i in range(mini(phase, f.phases.size())):
		var ph = f.phases[i]
		if ph.get("weak") is Array and not ph.weak.is_empty():
			weak = ph.weak.duplicate()
	return weak


## The resisted school of a foe in a phase, as a list of 0 or 1 (see weak_of).
static func resist_of(foe_id: String, phase: int = 0) -> Array:
	var f = by_id(foe_id)
	if f == null:
		return []
	var resist = f.resist.duplicate()
	for i in range(mini(phase, f.phases.size())):
		var ph = f.phases[i]
		if ph.get("resist") is Array:
			resist = ph.resist.duplicate()
	return resist


## Everything there is to learn about the catalog's foes: {key: [weak schools]}
## for every foe and every boss phase. A setup's "known" for a practised hand
## (the simulator, the balance sweep); the game itself passes saved.rpg.seen.
static func all_known() -> Dictionary:
	var out = {}
	for f in all():
		for ph in range(f.phases.size() + 1):
			out[key_of(str(f.id), ph)] = weak_of(str(f.id), ph)
	return out


## The pips of a foe's guard (its own, else its role's).
static func guard_of(foe: Dictionary) -> int:
	return int(RpgDefs.role(str(foe.get("role", "brute")))[3]) if foe.get("guard") == null else int(foe.guard)


## Short phrases for a foe's sheet, in the order to show them: what kind of
## foe it is, its guard, what its moves ask of the player (said once each),
## its traits in words, and how often a boss changes. Its weaknesses are not
## here: those are shown only once learned (RpgBattle.known).
static func words(foe: Dictionary) -> Array:
	var out = []
	var role = str(foe.get("role", ""))
	if ROLE_WORDS.has(role):
		out.append(str(ROLE_WORDS[role]))
	out.append("Guard %d" % guard_of(foe))
	var said = {}
	for id in foe.get("moves", []):
		var mv = move(str(id))
		if mv == null:
			continue
		var w = ""
		if int(mv.windup) > 0 and float(mv.power) > 0.0:
			w = "Winds up big hits"
		elif int(mv.windup) > 0:
			w = "Winds up a heal you can stop"
		elif str(mv.kind) == "bomb":
			w = "Counts down to a blast"
		elif str(mv.kind) == "summon":
			w = "Calls for help"
		elif str(mv.kind) == "heal":
			w = "Heals"
		elif str(mv.kind) == "shield":
			w = "Shields"
		elif str(mv.kind) == "drain":
			w = "Drains"
		if (role == "bomb" and str(mv.kind) == "bomb") or (role == "healer" and str(mv.kind) == "heal"):
			w = ""          # its role already says so
		if w != "" and not said.has(w):
			said[w] = true
			out.append(w)
		for e in mv.fx:
			if str(e.get("k", "")) != "status" or str(mv.target) != "hero" or str(e.get("to", "")) == "self":
				continue
			var sw = str(HEX_WORDS.get(str(e.id), ""))
			if sw != "" and not said.has(sw):
				said[sw] = true
				out.append(sw)
	for t in foe.get("traits", []):
		if BAKED.has(str(t.get("p", ""))):
			continue        # a number already in its HP, defence or speed: nothing to read
		var tw = str(TRAIT_WORDS.get(str(t.get("p", "")), ""))
		if str(t.get("p", "")) == "vs_status":
			tw = str(WHILE_WORDS.get(str(t.get("id", "")), ""))
		elif str(t.get("p", "")) == "start_status" and str(t.get("id", "")) == "steady":
			tw = "Cannot be stunned"
		if tw == "":
			tw = RpgBattle.passive_words(t)
		if tw != "":
			out.append(tw)
	var changes = foe.get("phases", []).size()
	if changes == 1:
		out.append("Changes once as it weakens")
	elif changes > 1:
		out.append("Changes %d times as it weakens" % changes)
	return out
