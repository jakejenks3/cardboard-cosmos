class_name RpgDefs
extends RefCounted
## The Realm (RPG_PLAN.md): ids, names, icon names and EVERY tuning number and
## formula of the turn-based RPG, in one place. Pure: no autoload, no screen.
##
## Nothing here reads or writes the log. The numbers marked (tune) are set by
## the balance step (tools/rpg_balance.gd); the engine, the catalogs and the
## screens all take them from here, so a number is changed in one place.
##
## Words: the stat `endurance` is shown as "Endurance"; the fight's resource is
## "energy" everywhere (never "stamina" for either).

## Bumped when a stored battle (the draft) could no longer be continued.
const VERSION = 1

# --- stats -------------------------------------------------------------------

const BODY = ["chest", "shoulders", "arms", "back", "core", "legs"]
const TRAITS = ["speed", "endurance", "grip", "mind", "flow", "grit"]
const STATS = ["chest", "shoulders", "arms", "back", "core", "legs", "speed", "endurance", "grip", "mind", "flow", "grit"]
const STAT_NAMES = {"chest": "Chest", "shoulders": "Shoulders", "arms": "Arms", "back": "Back", "core": "Core", "legs": "Legs",
	"speed": "Speed", "endurance": "Endurance", "grip": "Grip", "mind": "Mind", "flow": "Flow", "grit": "Grit"}
const STAT_ICONS = {"chest": "st_chest", "shoulders": "st_shoulders", "arms": "st_arms", "back": "st_back", "core": "st_core", "legs": "st_legs",
	"speed": "sch_speed", "endurance": "st_endurance", "grip": "sch_grip", "mind": "sch_mind", "flow": "sch_flow", "grit": "sch_grit"}
## The school whose colour a stat is shown in (RpgUi.color).
const STAT_SCHOOL = {"chest": "push", "shoulders": "push", "arms": "push", "back": "pull", "core": "legs", "legs": "legs",
	"speed": "speed", "endurance": "speed", "grip": "grip", "mind": "mind", "flow": "flow", "grit": "grit"}
## What a stat does in a fight, in a few words (the Hero page).
const STAT_DOES = {"chest": "Push moves that use the chest", "shoulders": "Push moves that use the shoulders",
	"arms": "Push and Pull moves that use the arms", "back": "Pull moves", "core": "Defence, and what Guard blocks",
	"legs": "Legs moves, and part of max HP", "speed": "Turn order and Speed moves", "endurance": "Max HP and the energy pool",
	"grip": "Crit chance and Grip moves", "mind": "Mind moves and status chance", "flow": "Healing, status resist and dodge",
	"grit": "The ultimate gauge and last stands"}
const STAT_MIN = 1.0
const STAT_MAX = 99.99

# --- schools -----------------------------------------------------------------

const SCHOOLS = ["push", "pull", "legs", "speed", "grip", "mind", "flow", "grit"]
## The schools a foe can be weak to or resist (flow and grit are support schools).
const ATTACK_SCHOOLS = ["push", "pull", "legs", "speed", "grip", "mind"]
const SCHOOL_NAMES = {"push": "Push", "pull": "Pull", "legs": "Legs", "speed": "Speed", "grip": "Grip", "mind": "Mind",
	"flow": "Flow", "grit": "Grit", "plain": "Strike"}
const SCHOOL_ICONS = {"push": "sch_push", "pull": "sch_pull", "legs": "sch_legs", "speed": "sch_speed", "grip": "sch_grip",
	"mind": "sch_mind", "flow": "sch_flow", "grit": "sch_grit", "plain": "strike"}
## Where a school comes from, for the screens.
const SCHOOL_FROM = {"push": "Chest, shoulders and arms", "pull": "Back and arms", "legs": "Legs and core", "speed": "Running",
	"grip": "Climbing", "mind": "Reading", "flow": "Physical therapy and stretches", "grit": "Showing up"}
## The stats a school's moves may scale with.
const SCHOOL_STATS = {"push": ["chest", "shoulders", "arms"], "pull": ["back", "arms"], "legs": ["legs", "core"], "speed": ["speed"],
	"grip": ["grip"], "mind": ["mind"], "flow": ["flow"], "grit": ["grit"]}
## The stat a board's passives and support moves ask for.
const BOARD_STAT = {"push": "chest", "pull": "back", "legs": "legs", "speed": "speed", "grip": "grip", "mind": "mind", "flow": "flow", "grit": "grit"}
## The hero's pose for a move of each school (HeroFigure poses).
const SCHOOL_POSE = {"push": "strike", "pull": "pull", "legs": "kick", "speed": "strike", "grip": "strike", "mind": "cast",
	"flow": "cast", "grit": "cast", "plain": "strike"}

# --- statuses ----------------------------------------------------------------

## id -> {name, kind "buff"|"debuff", icon, text, opposite ("" = none), stacks (the most; 1 = does not stack)}.
const STATUS = {
	"pumped": {"name": "Pumped", "kind": "buff", "icon": "fx_pumped", "text": "Deals 25% more damage.", "opposite": "weakened", "stacks": 1},
	"weakened": {"name": "Weakened", "kind": "debuff", "icon": "fx_weakened", "text": "Deals 25% less damage.", "opposite": "pumped", "stacks": 1},
	"braced": {"name": "Braced", "kind": "buff", "icon": "fx_braced", "text": "Takes 25% less damage.", "opposite": "exposed", "stacks": 1},
	"exposed": {"name": "Exposed", "kind": "debuff", "icon": "fx_exposed", "text": "Takes 25% more damage.", "opposite": "braced", "stacks": 1},
	"hasted": {"name": "Hasted", "kind": "buff", "icon": "fx_hasted", "text": "Acts sooner: speed x1.3.", "opposite": "slowed", "stacks": 1},
	"slowed": {"name": "Slowed", "kind": "debuff", "icon": "fx_slowed", "text": "Acts later: speed x0.7.", "opposite": "hasted", "stacks": 1},
	"burn": {"name": "Burn", "kind": "debuff", "icon": "fx_burn", "text": "Loses health at the end of each of its turns.", "opposite": "", "stacks": 1},
	"bleed": {"name": "Bleed", "kind": "debuff", "icon": "fx_bleed", "text": "Loses health each turn; stacks up to 3.", "opposite": "", "stacks": 3},
	"stun": {"name": "Stunned", "kind": "debuff", "icon": "fx_stun", "text": "Loses its next action.", "opposite": "", "stacks": 1},
	"regen": {"name": "Regen", "kind": "buff", "icon": "fx_regen", "text": "Heals at the start of each of its turns.", "opposite": "", "stacks": 1},
	"shield": {"name": "Shield", "kind": "buff", "icon": "fx_shield", "text": "Absorbs damage until it is used up.", "opposite": "", "stacks": 1},
	"focus": {"name": "Focus", "kind": "buff", "icon": "fx_focus", "text": "The next hit is a sure crit.", "opposite": "", "stacks": 3},
	"evade": {"name": "Evade", "kind": "buff", "icon": "fx_evade", "text": "Dodges the next hit.", "opposite": "", "stacks": 3},
	"counter": {"name": "Counter", "kind": "buff", "icon": "fx_counter", "text": "Strikes back when hit.", "opposite": "", "stacks": 1},
	"steady": {"name": "Steady", "kind": "buff", "icon": "fx_steady", "text": "Cannot be stunned.", "opposite": "", "stacks": 1},
	"marked": {"name": "Marked", "kind": "debuff", "icon": "fx_marked", "text": "The next 2 moves on it count as hitting a weakness.", "opposite": "", "stacks": 2},
	"insight": {"name": "Insight", "kind": "buff", "icon": "fx_insight", "text": "Shows every foe's weaknesses and what it will do after next.", "opposite": "", "stacks": 1},
}
const PUMP = 0.25
const BRACE = 0.25
const HASTE = 1.3
const SLOW = 0.7
const BURN_PCT = 0.06
const BLEED_PCT = 0.03
const REGEN_PCT = 0.06
## On a foe a burn / a bleed stack is a share of the applier's offence (after the foe's defence).
const BURN_FOE = 0.5
const BLEED_FOE = 0.3
## A boss never loses more than this share of its max HP to one burn tick.
const BOSS_DOT_CAP = 0.03
## After a stun: that many of its own turns immune.
const STUN_IMMUNE = 2
## A boss is not stunned: it is pushed back this share of a turn.
const BOSS_STUN_DELAY = 0.6
const MARKED_STACKS = 2

# --- the fight's numbers -----------------------------------------------------

const K_DEF = 60.0
const CORE_FLOOR = 0.6
const LEVEL_STEP = 0.03
const LEVEL_MAX = 60
const HP_BASE = 80.0
const HP_LEVEL = 8.0
const WEAK_MULT = 1.25
const RESIST_MULT = 0.7
const BROKEN_MULT = 1.4
const CRIT_BASE = 0.05
const CRIT_PER_GRIP = 0.002
const CRIT_CAP = 0.40
const CRIT_MULT = 1.5
const FOE_CRIT = 0.05
const FOE_CRIT_MULT = 1.25
const DODGE_PER_FLOW = 0.002
const DODGE_CAP = 0.20
const ROLL_LO = 0.92
const ROLL_SPAN = 0.16
const DELAY_BASE = 1000.0
const DELAY_OFFSET = 150.0
const STRIKE_POWER = 0.9
const STRIKE_RANK = 0.9
const GUARD_RANK = 0.7
const ITEM_RANK = 0.6
const ULT_RANK = 1.0
## Uses of one belt stack in one battle.
const BELT_USES = 3
const EN_BASE = 6
const EN_PER_ENDURANCE = 25.0
const EN_START = 3
const EN_TURN = 1
const EN_STRIKE = 1
const EN_GUARD = 2
const GAUGE_MAX = 100.0
const GAUGE_ACT = 6.0
const GAUGE_WEAK = 4.0
const GAUGE_BREAK = 20.0
const GAUGE_HURT = 60.0
const GRIT_GAUGE = 200.0
const FLOW_HEAL = 100.0
const WAVE_HEAL_BASE = 0.10
const WAVE_HEAL_FLOW = 400.0
## The most living foes at once.
const FOES_MAX = 3
const PET_SPD = 34.0
const PET_RARITY = {"common": 1.0, "uncommon": 1.1, "rare": 1.2, "epic": 1.35, "legendary": 1.5}

# --- the reference hero and the foes solved from it (tune) -------------------

## The stat the road expects of the hero's attack school at tiers 1..8.
const REF_STAT = [12.0, 20.0, 27.0, 33.0, 38.0, 43.0, 48.0, 52.0]
const REF_STAT_PAST = 3.0
const REF_SIDE = 0.55
const TTK = 3.3
const HIT = 0.065
## role -> [hp, atk, speed ratio, guard pips, def multiplier].
const ROLES = {
	"swarm": [0.55, 0.7, 1.15, 2, 1.0],
	"skirmisher": [0.8, 0.9, 1.25, 2, 1.0],
	"brute": [1.3, 1.2, 0.9, 3, 1.0],
	"tank": [1.5, 0.8, 0.9, 5, 1.5],
	"caster": [0.75, 1.0, 1.05, 2, 1.0],
	"healer": [0.8, 0.6, 1.05, 3, 1.0],
	"bomb": [0.9, 0.8, 0.95, 2, 1.0],
	"elite": [2.4, 1.5, 1.0, 6, 1.0],
	"boss": [3.3, 2.0, 1.2, 6, 1.0],
}
## An elite's or a boss's adds.
const ADD_MULT = 0.5

# --- progress ---------------------------------------------------------------

const NODE_COST = [0, 1, 1, 2, 3, 4]
const NODE_LEVEL = [0, 1, 1, 4, 10, 18]
## The real stat a node of each tier asks for (tune).
const REQ = [0, 1, 12, 24, 36, 46]
const POINTS_START = 3
const POINTS_PER_BOSS = 2
const STARS_PER_POINT = 12
const DAYS_PER_POINT = 8
const MOVE_SLOTS = 4
const MOVE_SLOT_5_AT = 20
const PASSIVE_SLOTS_AT = [3, 10, 20]
const RELIC_SLOTS_AT = [1, 8, 30]
const BELT_SLOTS = 2
const BELT_SLOT_3_AT = 6
const STAR_CHESTS = [8, 16, 24]

const RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_MULT = {"common": 1.0, "uncommon": 1.12, "rare": 1.25, "epic": 1.4, "legendary": 1.6}
const RARITY_COST = {"common": 1.0, "uncommon": 1.2, "rare": 1.5, "epic": 2.0, "legendary": 3.0}
const DUP_ORE = {"common": 20, "uncommon": 35, "rare": 60, "epic": 110, "legendary": 200}
const PLUS_MAX = 10
const PLUS_STEP = 0.5
## A percentage line (spd, crit, gauge_rate, heal_pct, luck) grows to this multiple at most.
const PLUS_PCT_CAP = 3.0
const PLUS_COST = 30.0
const PLUS_COST_GROW = 1.2
const XP_FOE = 12.0
const XP_GROW = 1.2
const ORE_FOE = 6.0
const ORE_GROW = 1.15
const ELITE_PAY = 3.0
const BOSS_PAY = 10.0

# --- boosts and chests -------------------------------------------------------

const PUMP_SETS = [3.0, 6.0, 9.0]
const PUMP_PCT = [0.10, 0.15, 0.20]
const READ_PAGES = [10, 30, 50]
const READ_PCT = [0.08, 0.12, 0.15]
const LONG_RUN_M = 5000.0
const MOBILITY_SETS = [3, 9]
const CHEST_ORE = 30
const CHEST_ORE_KIND = 25

# --- the world --------------------------------------------------------------

const REGIONS = ["rustyard", "greenmile", "chalk", "stacks", "ironworks", "marsh", "stormspine", "titans_rest"]
const REGION_NAMES = {"rustyard": "The Rustyard", "greenmile": "The Greenmile", "chalk": "Chalk Cliffs", "stacks": "The Stacks",
	"ironworks": "The Ironworks", "marsh": "Mirror Marsh", "stormspine": "Stormspine Ridge", "titans_rest": "Titan's Rest"}
const STAGES_PER_REGION = 10
const SPIRE_AFTER_REGION = 2

# --- icons the Realm adds (ui/icons.gd draws each; content may use these and the game's own names) ---

const ICONS = [
	"music", "music_off",
	"sch_push", "sch_pull", "sch_legs", "sch_speed", "sch_grip", "sch_mind", "sch_flow", "sch_grit",
	"st_chest", "st_shoulders", "st_arms", "st_back", "st_core", "st_legs", "st_endurance",
	"fx_pumped", "fx_weakened", "fx_braced", "fx_exposed", "fx_hasted", "fx_slowed", "fx_burn", "fx_bleed", "fx_stun", "fx_regen",
	"fx_shield", "fx_focus", "fx_evade", "fx_counter", "fx_steady", "fx_marked", "fx_insight", "fx_broken",
	"in_attack", "in_heavy", "in_multi", "in_debuff", "in_buff", "in_heal", "in_shield", "in_summon", "in_bomb", "in_stunned", "in_drain", "in_charge",
	"realm", "ore", "energy", "gauge", "guard_pip", "power", "sp", "strike", "guard", "flee", "belt", "relic", "rune", "scroll",
	"hunt", "spire", "rival", "chest_wood", "chest_iron", "chest_gold", "star_on", "star_off",
	"it_shake", "it_mega", "it_electro", "it_salts", "it_chalk", "it_gel", "it_ice", "it_pre",
	"rl_ring", "rl_bookmark", "rl_chain", "rl_tooth", "rl_band", "rl_whistle", "rl_tape", "rl_feather", "rl_bell", "rl_hourglass", "rl_horn", "rl_anvil",
]


# --- ids ---------------------------------------------------------------------

## The id of a name: lower case, apostrophes dropped, every other run of
## non-alphanumerics one underscore ("Runner's High" -> "runners_high").
static func id_of(text: String) -> String:
	var out = ""
	var gap = false
	for ch in text.to_lower():
		if ch == "'" or ch == "’":
			continue
		var code = ch.unicode_at(0)
		var alnum = (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if alnum:
			if gap and out != "":
				out += "_"
			gap = false
			out += ch
		else:
			gap = true
	return out


# --- formulas ---------------------------------------------------------------

static func level_mult(level: int) -> float:
	return 1.0 + LEVEL_STEP * float(maxi(1, level) - 1)


## What a move hits with: the scaling stat, the gear attack for its school, the fighter level.
static func offence(stat: float, w: float, level: int) -> float:
	return (20.0 + stat + w) * level_mult(level)


static func hero_hp(endurance: float, legs: float, core: float, level: int) -> float:
	return HP_BASE + HP_LEVEL * float(level) + 2.0 * endurance + legs + core


## The core share has a floor of CORE_FLOOR of might: a hero who lifts but has
## logged little core work still has a trunk (the balance pass, 2026-11-27: a
## Core of 7 beside a might of 28 alone turned an even boss into a lost one).
## More core still pays: above the floor it counts in full, and Guard reads it.
static func hero_def(core: float, might: float, armor: float) -> float:
	return 0.5 * maxf(core, CORE_FLOOR * might) + 0.2 * might + armor


## The share of a hit that gets through a defence.
static func mitigation(def: float) -> float:
	return K_DEF / (K_DEF + maxf(0.0, def))


## Time until a unit acts again after an action of that rank.
static func delay(rank: float, spd: float) -> float:
	return DELAY_BASE * rank / (DELAY_OFFSET + maxf(0.0, spd))


static func crit_chance(grip: float, add: float = 0.0) -> float:
	return clampf(CRIT_BASE + CRIT_PER_GRIP * grip + add, 0.0, CRIT_CAP)


static func dodge_chance(flow: float, add: float = 0.0) -> float:
	return clampf(DODGE_PER_FLOW * flow + add, 0.0, DODGE_CAP)


## The chance a status lands: `base` (a fraction), the applier's tec, the target's res.
static func status_chance(base: float, tec: float, res: float) -> float:
	return clampf(base + 0.005 * (tec - res), 0.15, 0.95)


static func en_max(endurance: float) -> int:
	return EN_BASE + int(floor(endurance / EN_PER_ENDURANCE))


## What Guard lets through (core 40: 0.4).
static func guard_mult(core: float, extra: float = 0.0) -> float:
	return clampf(0.5 - core / 400.0 - extra, 0.2, 0.5)


static func heal_mult(flow: float, heal_pct: float = 0.0) -> float:
	return (1.0 + flow / FLOW_HEAL) * (1.0 + heal_pct)


## The share of max HP the hero gets back between two waves.
static func wave_heal(flow: float) -> float:
	return WAVE_HEAL_BASE + flow / WAVE_HEAL_FLOW


static func gauge_mult(grit: float, gauge_rate: float = 0.0) -> float:
	return (1.0 + grit / GRIT_GAUGE) * (1.0 + gauge_rate)


## The budget of a move's power (RPG_PLAN.md section 5), before what else it does.
static func move_budget(rank: float, cost: int, cd: int) -> float:
	return 1.05 * rank + 0.25 * float(cost) * minf(1.0, rank) + 0.2 * float(cd)


# --- the reference hero -----------------------------------------------------

## The tier (a float) of a difficulty index n.
static func tier_of_n(n: float) -> float:
	return 1.0 + n / 10.0


static func ref_stat(t: float) -> float:
	if t <= 1.0:
		return float(REF_STAT[0])
	var last = REF_STAT.size()
	if t >= float(last):
		return float(REF_STAT[last - 1]) + REF_STAT_PAST * (t - float(last))
	var i = int(floor(t)) - 1
	var f = t - floor(t)
	return float(REF_STAT[i]) + (float(REF_STAT[i + 1]) - float(REF_STAT[i])) * f


## The reference hero's endurance, legs, core, might and speed.
static func ref_side(t: float) -> float:
	return REF_SIDE * ref_stat(t)


static func ref_level(t: float) -> int:
	return clampi(int(round(5.0 * t - 4.0)), 1, LEVEL_MAX)


static func ref_w(t: float) -> float:
	return 4.0 + 3.4 * (t - 1.0)


static func ref_armor(t: float) -> float:
	return 2.5 + 2.0 * (t - 1.0)


## The average power of the reference hero's moves per action.
static func ref_p(t: float) -> float:
	return minf(2.0, 1.15 + 0.12 * (t - 1.0))


static func ref_offence(t: float) -> float:
	return offence(ref_stat(t), ref_w(t), ref_level(t))


static func ref_hp(t: float) -> float:
	var side = ref_side(t)
	return hero_hp(side, side, side, ref_level(t))


static func ref_def(t: float) -> float:
	var side = ref_side(t)
	return hero_def(side, side, ref_armor(t))


# --- foes, solved ------------------------------------------------------------

static func role(id: String) -> Array:
	return ROLES.get(id, ROLES["brute"])


static func foe_def(n: float) -> float:
	return 8.0 + 3.0 * (tier_of_n(n) - 1.0)


## A regular foe's HP before its role (a role-1.0 foe alone lasts TTK reference turns).
static func foe_hp(n: float) -> float:
	var t = tier_of_n(n)
	return TTK * ref_p(t) * ref_offence(t) * mitigation(foe_def(n))


## A foe's attack before its role: a power-1 hit takes HIT of the reference hero's HP.
static func foe_atk(n: float) -> float:
	var t = tier_of_n(n)
	return HIT * ref_hp(t) / mitigation(ref_def(t))


static func foe_spd(role_id: String, n: float) -> float:
	var t = tier_of_n(n)
	return maxf(1.0, float(role(role_id)[2]) * (DELAY_OFFSET + ref_side(t)) - DELAY_OFFSET)


## A foe's tec and res (for status chances).
static func foe_tec(n: float, elite: bool = false, boss: bool = false) -> float:
	return ref_stat(tier_of_n(n)) + (20.0 if boss else (10.0 if elite else 0.0))


## Each of c regular foes in a pack has this share of hp and atk.
static func pack_mult(count: int) -> float:
	return 2.0 / float(maxi(1, count) + 1)


# --- progress ---------------------------------------------------------------

static func xp_to_next(level: int) -> int:
	return int(round((6.0 + 0.15 * float(level)) * 10.0 * pow(1.2, float(level - 1) / 5.0)))


## The fighter level of a fighter-XP total: {"lvl", "into", "need"} (need 0 at the cap).
static func level_of(xp: int) -> Dictionary:
	var lvl = 1
	var left = maxi(0, xp)
	while lvl < LEVEL_MAX:
		var need = xp_to_next(lvl)
		if left < need:
			return {"lvl": lvl, "into": left, "need": need}
		left -= need
		lvl += 1
	return {"lvl": LEVEL_MAX, "into": 0, "need": 0}


## The tier a fighter level belongs to (the over-level rule and the pet's speed).
static func tier_of_level(level: int) -> int:
	return clampi(int(floor(float(level + 4) / 5.0)), 1, 12)


## Fighter XP for one foe of a stage of index n; kind "regular" | "elite" | "boss".
static func foe_xp(n: float, kind: String = "regular") -> int:
	var pay = BOSS_PAY if kind == "boss" else (ELITE_PAY if kind == "elite" else 1.0)
	return int(round(XP_FOE * pow(XP_GROW, n / 10.0) * pay))


static func foe_ore(n: float, kind: String = "regular") -> int:
	var pay = BOSS_PAY if kind == "boss" else (ELITE_PAY if kind == "elite" else 1.0)
	return int(round(ORE_FOE * pow(ORE_GROW, n / 10.0) * pay))


## The share of a win's fighter XP a fighter of that level gets on a stage of index n.
static func xp_share(level: int, n: float) -> float:
	return clampf(1.0 - 0.2 * float(tier_of_level(level) - int(floor(tier_of_n(n))) - 1), 0.2, 1.0)


static func move_slots(level: int) -> int:
	return MOVE_SLOTS + (1 if level >= MOVE_SLOT_5_AT else 0)


static func passive_slots(level: int) -> int:
	return PASSIVE_SLOTS_AT.filter(func(at): return level >= int(at)).size()


static func relic_slots(level: int) -> int:
	return RELIC_SLOTS_AT.filter(func(at): return level >= int(at)).size()


static func belt_slots(level: int) -> int:
	return BELT_SLOTS + (1 if level >= BELT_SLOT_3_AT else 0)


## What a gear line is multiplied by at +plus (`pct_line`: a fraction line, capped).
static func plus_mult(plus: int, pct_line: bool = false) -> float:
	var m = 1.0 + PLUS_STEP * float(clampi(plus, 0, PLUS_MAX))
	return minf(m, PLUS_PCT_CAP) if pct_line else m


## Ore for the step from +plus to +plus+1.
static func plus_cost(rarity: String, plus: int) -> int:
	return int(round(PLUS_COST * pow(PLUS_COST_GROW, float(plus)) * float(RARITY_COST.get(rarity, 1.0))))


## The index of the highest tier a value reaches in an ascending list (-1 = none).
static func tier_index(value: float, steps: Array) -> int:
	var at = -1
	for i in range(steps.size()):
		if value >= float(steps[i]):
			at = i
	return at
