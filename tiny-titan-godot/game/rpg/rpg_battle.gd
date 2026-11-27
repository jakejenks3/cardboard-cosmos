class_name RpgBattle
extends RefCounted
## The Realm's battle engine (RPG_PLAN.md 4, 5, 6, 8.3, 11.3, 11.4). All static,
## pure, no autoload, no screen. A battle is ONE JSON-safe Dictionary, `B`;
## every function takes it. The numbers and formulas are RpgDefs'; nothing is
## typed in here.
##
##   start(setup) -> B                  setup = {"hero": unit (RpgHero.build), "pet": unit or null (RpgHero.pet_unit),
##                                               "waves": [[{"foe": id, "n": index, ...}, ...], ...], "seed": int,
##                                               "what": {...}, "rules": [ids of RULES], "known": {key: [schools]}, "day": date,
##                                               "custom": {"moves", "foes", "foe_moves", "pets", "items": {id: row}}}
##                                      a wave entry may carry "weak", "resist" (set by the setup: shown, never learned),
##                                      "start": [{"id", "turns", "stacks", "amount"}] (statuses), "mult" (its share of hp
##                                      and attack, instead of the pack's), "guard_add", and "row": a whole foe row for a
##                                      foe that is not in RpgFoes (the rival). At most three foes a wave.
##   opening(B) -> Array                the events before the hero's first choice (kept in B until the first act)
##   options(B) -> Dictionary           what the hero may do now (its shape is at the function)
##   illegal(B, action) -> String       "" or why not: over, wait, unknown, cooldown, energy, gauge, item, rule, pet
##   preview(B, action, truth = false)  what an attack would do to its target, as far as the player may know
##   act(B, action) -> Array            the hero's action, then foes / companion / ticks until the hero must choose
##                                      again or the battle ends; the events in order ([{"t": "no", "why"}] = not allowed)
##   timeline(B, count) -> Array        the ids of who acts next, assuming rank 1
##   unit(B, id), foes(B) (living), over(B), won(B), summary(B)
##   known(B, foe unit id) -> {"weak", "resist", "all"}   what may be shown of a foe's schools
##   next_intent(B, foe unit id)        the intent after the shown one (for Insight)
##   check_move / check_mod / check_fx / check_passive / check_foe / check_foe_move / check_pet / check_item -> String
##                                      "" = fine, else what is wrong. They accept exactly what the engine implements.
##   fx_words(effect, attack = true) / mod_words(mod) / passive_words(passive effect) -> String
##                                      a short phrase for the screens ("Exposed for 2 turns (70%)", "+30% against
##                                      Exposed foes", "Push moves +10%"); "" for a kind nobody knows
##   aggregate(fx) -> Dictionary        the sums of a list of passive effects (RpgHero and RpgFoes bake numbers from it)
##   json_safe(B) -> String             "" when B is exactly what a JSON round trip gives back
##
## Actions: {"t": "move", "id", "target"} · {"t": "strike", "target"} · {"t": "guard"} · {"t": "item", "id"} ·
##   {"t": "ult", "target"} · {"t": "pet", "target"} (free: the turn goes on) · {"t": "flee"}.
##   A missing or dead target is the first living foe.
##
## ---------------------------------------------------------------------------
## THE VOCABULARY (content is written against this; the validators are the last word)
##
## A hero move's damage, per hit (`power` is the power of ALL its hits together):
##   max(1, floor(power / hits * offence * mitigation(target def) * mult * (0.92 + 0.16 rand) + rand))
##   offence = RpgDefs.offence(the scale's stats by weight, hero.w[school], level)
##   mult    = (1 + every "+N%" below, added up) * weak 1.25 or resist 0.7 * Broken 1.4
##             * Pumped / Weakened of the attacker * Braced / Exposed of the target * crit 1.5
##
## MODS on a move, {"m": kind, ...}; every pct is a fraction and they ADD UP:
##   vs_status {id, pct}        the target has that status
##   vs_debuff {pct}            the target has any debuff
##   per_debuff {pct, max}      per debuff on the target, up to max
##   vs_broken {pct}            the target is Broken
##   vs_full_hp {pct}           the target is at full HP
##   execute {below, pct}       the target's HP share is under `below`
##   ignore_def {pct}           that share of the target's defence is ignored (1 = all)
##   crit {add}                 crit chance added, for this move (on top of the hero's own chance, which RpgDefs caps)
##   sure_crit                  every hit is a crit
##   ramp_use {pct, max}        per earlier use of this move this battle
##   ramp_turn {pct, max}       per hero turn of the battle already gone (turn 1: nothing)
##   streak {pct, max}          per attacking hero turn in a row before this one (Strike counts; Guard, an item, a
##                              support move or a lost turn ends it)
##   smart                      chips 1 guard pip even when the school is not weak (never when resisted)
##   missing_hp {pct}           times the share of HP the hero has LOST (at 1 HP: nearly all of pct)
##
## EFFECTS, {"k": kind, ...}; applied after the damage, in the order written. `to`:
## "target" | "self" | "all_foes" | "allies" | "ally". Where `to` is left out:
##   a status lands on the target of an attack and on the user of a support move, an item, a passive;
##   heal, shield and cleanse land on the user; delay, dispel, interrupt and chip on the target;
##   in a foe move everything lands on the move's own target ("hero", "self", "ally" = the most hurt foe, "allies"
##   = every foe), but heal / shield / cleanse of a move aimed at the hero land on the foe itself.
##   A companion's "self" is the hero. An effect on an attack's target needs the attack to have landed.
##   status {id, turns, chance, stacks, amount, to}   a status of RpgDefs.STATUS (never "shield": that is the effect
##                              below). turns: needed, except for focus / evade / marked / stun; 0 = until used up or
##                              for the whole wave. chance left out = it lands (Stun always rolls, at most 95%); a
##                              chance against the other side is moved by tec against res. stacks for bleed / focus /
##                              evade / marked; amount = a Counter's power.
##   heal {pct, to}             a share of max HP (the hero's side: * RpgDefs.heal_mult)
##   shield {pct, to}           a Shield of that share of max HP, same multiplier (the larger of old and new is kept)
##   energy {n}                 the HERO's energy, whoever acts (negative drains; 99 = full)
##   gauge {n}                  the hero's gauge, as written (no multiplier; negative drains)
##   delay {pct, to}            pushes the next action back by that share of a rank-1 delay (half on a boss)
##   cleanse {n} / {ids}        removes n debuffs, oldest first (0 = all), or the statuses named
##   dispel {n, to}             removes n buffs, oldest first (0 = all)
##   interrupt {to}             cancels a wind-up or a countdown: the foe chooses again
##   cd_cut {n}                 the hero's other cooldowns go down by n
##   hp_cost {pct}              the user pays that share of its CURRENT HP (never the last one)
##   lifesteal {pct}            the user heals that share of the damage this action dealt
##   refund {n}                 +n energy when the action killed
##   extra_turn                 the hero acts again at once
##   chip {n, to}               chips n guard pips whatever the school
##   when {hp_below, do}        `do` (one effect, not another when) only if the user's HP share is under hp_below
##   self_ko                    the user falls (a foe's bomb)
##   flee                       the foe that uses it leaves the fight: gone, not felled (event flee {dst})
##
## PASSIVE EFFECTS, {"p": kind, ...}: board passives, gear, runes, sets, relics, pets, boosts, foe traits.
##   baked into the hero's numbers by RpgHero.build (a foe's hp, hp_pct, armor, def_pct, spd_pct, res_add, crit_add
##   and dodge_add by RpgFoes.make):
##     stat_pct {stat, pct} ("all", "body" allowed) · hp_pct / def_pct / spd_pct {pct} · crit_add / dodge_add /
##     res_add {v} · atk {school, v} ("all" allowed) · armor {v} · hp {v} · en_max {n}
##   read by the engine from unit.fx (unit.agg holds their sums):
##     stat_dmg {stat, pct}       moves scaled by that stat: +pct times the stat's weight in the move
##     school_pct {school, pct}   moves of that school ("all": everything, Strike too; "plain": Strike alone)
##     heal_pct {pct} · gauge_rate {pct} · en_start {n} · gauge_start {n} · guard_pct {v} (Guard blocks that much
##     more) · guard_en {n} · lifesteal {pct} (of the damage of its attacks)
##     start_status {id, turns, stacks, amount} · start_shield {pct}     at the start of EVERY wave
##     on {ev, do, every, once}   ev: "break" | "kill" | "crit" | "weak" (once an action) | "guard" | "hit_taken" |
##                                "turn" (the start of its turn) | "wave" (the start of every wave). `do` is one
##                                effect: "self" = the owner, "target" = the other unit of the event. every: only
##                                each Nth time; once: once a battle.
##     low_hp {below, do}         once a battle, when a hit or a tick takes its HP share under `below`
##     survive {pct}              once a battle: a lethal blow leaves it standing at that share of max HP (0 = 1 HP)
##     cost / cd {school, add}    its moves of that school ("all" allowed) cost / rest that much more (negative =
##                                less; never under 0; a move that rests never rests less than 1)
##     next_cost {school, add}    after a move of that school, the next one of it costs that much more
##     chip {on, add}             on "crit": a crit chips that many pips (once a move a target, not through a
##                                resistance, not with Strike); on a school: its weak hits chip that many more
##     status_turns {on, add}     "debuff": debuffs it gives to enemies; "buff": buffs it gives itself;
##                                "self_debuff": debuffs ON it (never under 1 turn)
##     status_chance {add} · vs_broken {pct} · vs_status {id, pct} · first_hit {pct} (the first hit on each foe)
##     combo_same {pct, max}      per move of the same school in a row before this one
##     combo_alt {pct}            a move of another school than the last move
##     ramp {pct, max}            per turn of its own already gone
##     first_turn                 it acts first · bounce: the first debuff of the battle bounces off
##     reward {what, pct}         "ore" | "xp" | "luck": not the engine's; summary(B).reward adds them up
##     adapt                      (foes) resists the attack school that last hit it, and that one only
##     quicken {pct, max}         (foes) that much faster after each of its actions
##   On a FOE (traits) these do something: the baked ones above, school_pct "all" (its hits), vs_status (the
##   hero has it), ramp, heal_pct, status_turns, status_chance, start_status, start_shield, on, low_hp, survive,
##   bounce, adapt, quicken. Of `on` a foe has hit_taken, turn and wave.
##
## ---------------------------------------------------------------------------
## THE ROWS (every key always there in what all() / by_id() give; a table may leave defaults out)
##
## A HERO MOVE (rpg_moves.gd, check_move):
##   {"id" (RpgDefs.id_of(name)), "name", "school": "push"|"pull"|"legs"|"speed"|"grip"|"mind"|"flow"|"grit",
##    "kind": "attack"|"support",
##    "scale": {stat id: weight}   weights above 0 that sum to 1 (an attack needs one)
##    "power": 0 for a support move, above 0 (at most 12) for an attack: ALL its hits together
##    "hits": 1..8 (a support move: 1) · "target": "foe"|"all"|"random"|"self" (an attack never "self", a support
##    move "self" or "foe") · "splash": 0..1 (an attack on one "foe": every other foe takes that share of each hit)
##    "cost": 0..9 energy · "cd": 0..9 hero turns of rest · "rank": 0.3..2.0 · "chip": 0..4 pips a weak hit takes
##    "mods": [mod] (attacks only) · "fx": [effect] · "tags": [String] · "text" · "ult": bool · "tier": int}
##   An ultimate costs 0 and acts at RpgDefs.ULT_RANK. Never self_ko; a support move has no lifesteal / refund,
##   and with target "self" nothing that needs a foe (delay, dispel, interrupt, chip, anything "to": "target").
## A BOARD PASSIVE (rpg_passives.gd): {"id", "name", "board", "tier", "text", "fx": [passive effects]}; relics,
##   gear lines, boosts and a companion's "passive" are lists of the same passive effects (check_passive each).
## A FOE (rpg_foes.gd, check_foe):
##   {"id", "name", "region", "role" (a key of RpgDefs.ROLES; "boss" / "elite" exactly when the flag is set),
##    "weak": [2 different attack schools], "resist": [0 or 1 attack school, not a weak one],
##    "guard": null (the role's pips) or 0..12, "moves": [foe move ids] (every move its pattern, rules and phases use),
##    "pattern": [move ids, round and round],
##    "rules": [{"if": "hp_below"|"ally_hurt"|"turn_mod"|"alone"|"hero_has"|"self_lacks", "v", "use": move id, "once": bool}]
##        looked at before the pattern, the first that holds and can be used: hp_below / ally_hurt v = an HP share ·
##        turn_mod v = N or [N, r] (its first turn is 1) · hero_has / self_lacks v = a status id
##    "traits": [passive effects],
##    "phases": [{"at": HP share (going down, between 1 and 0), "say", "pattern", "weak" (2, or none: as before),
##                "resist", "summon": [foe ids], "fx": [effects on itself]}],
##    "boss": bool, "elite": bool, "text"}
## A FOE MOVE (rpg_foes.gd MOVES, check_foe_move):
##   {"id", "name", "kind": "attack"|"multi"|"heavy"|"debuff"|"buff"|"heal"|"shield"|"summon"|"drain"|"bomb" (what
##    the intent shows; a "bomb" and only a bomb has a count, a "summon" and only a summon brings foes),
##    "power": 0..6, ALL hits together, in units of the foe's attack (only with target "hero"), "hits": 1..8,
##    "windup": 0|1 (it spends one turn charging first), "count": 0..9 (its turns until a bomb goes off),
##    "rank": 0.3..2.0, "target": "hero"|"self"|"ally"|"allies", "fx": [effects] (not cd_cut, refund, extra_turn,
##    interrupt, chip), "foes": [ids a summon brings], "icon" ("" = the kind's), "text"}. It must do something.
##   A move that only heals (kind "heal", no power) is passed over while no foe is hurt; a summon while three stand.
## A COMPANION'S KIT (rpg_pets.gd, check_pet):
##   {"id" (a pet id of Pets), "auto": {"name", "kind": "attack"|"support", "power": 0..4 (an attack: above 0),
##    "school", "fx": [effects], "every": 1.. (only each Nth of its turns), "target" (optional)},
##    "command": {"name", "charge": 1..6, "power", "target": "foe"|"all"|"self", "school", "fx", "text" (optional)},
##    "passive": [passive effects]}. Never self_ko, hp_cost, cd_cut. Its hits are never weak, never crit, never chip.
## A BELT ITEM (rpg_items.gd, check_item): {"id", "name", "icon", "text", "fx": [effects, at least one; not
##   lifesteal, refund, self_ko], "price": ore}. Its effects land on the hero unless one says "to".
##
## ---------------------------------------------------------------------------
## RULINGS (where the plan leaves room; the tests hold the engine to these)
##   - A pair of statuses cancels: the new one is not put on and the old one goes (both are gone).
##   - The same status again keeps the longer time; Bleed, Focus and Evade add stacks; Marked is set back to 2.
##   - Durations tick at the end of the unit's own turn; a status put on a unit DURING its own turn does not lose
##     that turn. The wait after a turn is set by the speed the unit had in it.
##   - Burn and Bleed are not hits: no Shield, Guard, Braced or dodge against them, no Counter.
##   - A foe that is Broken and stunned at once loses one action for the two.
##   - A wind-up: the intent shows it, the foe's next turn is the charging (rank 1), the turn after is the hit.
##   - An intent's number is the middle of the roll, all hits, no crit, before a Shield or a dodge, as things stand;
##     it is brought up to date after everything that happens.
##   - The ultimate fills no gauge (not by its hits, a break, or what strikes back during it).
##   - Counter strikes back once per action of the attacker (a foe's: once per hero move), and never crits.
##   - A win is checked first; then the next wave; then a loss.
##
## EVENTS (act's result; every one has "t"; numbers are JSON-normalized, so cast before use):
##   turn {who, n} · act {who, kind, id, name, school, target} (kind: move, strike, guard, item, ult, flee, lost,
##   auto, command, charge, count, or a foe move's kind) · dmg {src, dst, amount, crit, weak, resist, chip, hp,
##   guard, school, absorbed, counter?} (amount = what got past the Shield) · miss {src, dst} · heal {dst, amount,
##   hp} · status {dst, id, on, turns, stacks, resisted, cancel?, bounced?, amount? (a Shield)} · tick {dst, id
##   (burn, bleed, hp_cost), amount, hp} · break {dst} · recover {dst, guard} · ko {dst} · energy {v} · gauge {v} ·
##   intent {who, intent} · learn {key, school} · phase {who, say, phase} · summon {units, by} · wave {n, of,
##   units} · say {text} · end {win}
##   and, beyond the plan's list: no {why} · survive {dst, hp} · chip {dst, chip, guard} · interrupt {dst} ·
##   delay {dst, stun?} · adapt {dst, school} · charge {v} · perfect {src, chip, guard} (a perfect guard: the
##   hero's Guard took the charged blow or the bomb of `src`, which lost `chip` pips; a break may follow)
##
## A UNIT in B (RPG_PLAN.md 11.3) also carries what the engine keeps: "agg" (aggregate of its fx), "turns", "flags",
##   and a foe "n" (its difficulty index), "slot" (its place, 0..2), "moves", "pattern", "rules", "phases".
##   An intent: {"move", "name", "kind" ("stunned" = it will lose its action), "dmg", "hits", "windup", "charged",
##   "count", "icon", "text", "target"}.
##
## JSON-SAFETY. After `start` and after every `act`, B is in "settled" form: every
## float is rounded to six decimals and a whole one is an int, exactly what
## TTUtil.normalize_json(JSON.parse_string(JSON.stringify(B))) gives back. So a
## battle stored and loaded goes on as the very same battle. Inside the engine
## that means: float() on both sides of every division, int() on every index,
## no dictionary is iterated where the order could matter, randomness only
## through `_rand` (the state is the int B.rng).

## Rules a setup may switch on (RpgWorld's hunt and echoes pick from these ids).
const RULES = {
	"foes_hasted": "The foes start Hasted.",
	"guard_up": "Every foe has 2 more guard.",
	"no_items": "The belt stays shut.",
	"foes_braced": "The foes start Braced.",
	"low_energy": "You start with 1 energy.",
	"extra_wave": "One more wave.",
}
## How long the statuses a rule gives last.
const RULE_TURNS = 3
const ON_EVENTS = ["break", "kill", "crit", "weak", "guard", "hit_taken", "turn", "wave"]
const FX_TO = ["target", "self", "all_foes", "allies", "ally"]
const FOE_MOVE_KINDS = ["attack", "multi", "heavy", "debuff", "buff", "heal", "shield", "summon", "drain", "bomb"]
const FOE_RULES = ["hp_below", "ally_hurt", "turn_mod", "alone", "hero_has", "self_lacks"]
## Statuses an effect may give without saying for how long.
const NO_TURNS = ["shield", "focus", "evade", "marked", "stun"]

## What a foe does when its table gives it nothing it can use.
const BASIC = {"id": "basic", "name": "Hit", "kind": "attack", "power": 1.0, "hits": 1, "windup": 0, "count": 0, "rank": 1.0,
	"target": "hero", "fx": [], "foes": [], "icon": "in_attack", "text": ""}

static var _strike_row = null


# =============================================================================
# The public face
# =============================================================================

## A new battle. The hero is whole, the first wave stands, and everything that
## happens before the hero's first choice has happened (see `opening`).
static func start(setup: Dictionary) -> Dictionary:
	var hero = setup.get("hero", {}).duplicate(true)
	var rules = []
	for r in setup.get("rules", []):
		rules.append(str(r))
	var B = {
		"v": RpgDefs.VERSION,
		"rng": int(setup.get("seed", 1)) & 0xFFFFFFFF,
		"hero": hero, "pet": null, "foes": [],
		"waves": setup.get("waves").duplicate(true) if setup.get("waves") is Array else [],
		"wave": -1, "next_id": 0, "now": 0.0, "n": 0,
		"over": false, "win": false, "fled": false, "wait": false, "ulting": false,
		"acting": "", "target": "",
		"what": setup.get("what").duplicate(true) if setup.get("what") is Dictionary else {},
		"rules": rules, "day": str(setup.get("day", "")),
		"known": {}, "resist_seen": {}, "learned": {},
		"custom": {"moves": {}, "foes": {}, "foe_moves": {}, "pets": {}, "items": {}},
		"sum": {"turns": 0, "dealt": 0, "taken": 0, "breaks": 0, "items": 0, "guards": 0, "schools": [], "worst": 0.0, "kos": 0, "waves": 0, "used": {}},
		"opening": [],
	}
	var seen = setup.get("known")
	if seen is Dictionary:
		for k in seen:
			if seen[k] is Array:
				B.known[str(k)] = seen[k].duplicate()
	var custom = setup.get("custom")
	if custom is Dictionary:
		for part in CUSTOM_PARTS:
			if custom.get(part) is Dictionary:
				for id in custom[part]:
					if custom[part][id] is Dictionary:
						B.custom[part][str(id)] = _custom_row(part, str(id), custom[part][id])
	if rules.has("extra_wave") and not B.waves.is_empty() and B.waves[0] is Array:
		# one more wave: the first one's regular foes stand in front of it
		var again = []
		for en in B.waves[0]:
			if not (en is Dictionary):
				continue
			var row = en.get("row") if en.get("row") is Dictionary else foe_row(B, str(en.get("foe", "")))
			if row != null and not bool(row.get("boss", false)) and not bool(row.get("elite", false)):
				again.append(en.duplicate(true))
		if not again.is_empty():
			B.waves.insert(0, again)

	# the hero, made ready
	hero["id"] = "hero"
	hero["side"] = "hero"
	hero["alive"] = true
	if not hero.has("name"):
		hero["name"] = "Hero"
	if not (hero.get("fx") is Array):
		hero["fx"] = []
	for key in ["s", "w"]:
		if not (hero.get(key) is Dictionary):
			hero[key] = {}
	if not (hero.get("moves") is Array):
		hero["moves"] = []
	hero["ult"] = str(hero.get("ult", ""))
	hero["lvl"] = maxi(1, _i(hero, "lvl", 1))
	hero["agg"] = aggregate(hero.fx)
	hero["hp_max"] = maxi(1, int(round(_f(hero, "hp_max", 1.0))))
	hero["hp"] = hero.hp_max
	hero["en_max"] = maxi(1, _i(hero, "en_max", RpgDefs.EN_BASE))
	var en0 = (1 if rules.has("low_energy") else RpgDefs.EN_START) + int(round(_f(hero.agg, "en_start")))
	hero["en"] = clampi(en0, 0, int(hero.en_max))
	hero["gauge"] = clampf(_f(hero.agg, "gauge_start"), 0.0, RpgDefs.GAUGE_MAX)
	hero["statuses"] = []
	hero["stun_guard"] = 0
	hero["cds"] = {}
	hero["guarding"] = false
	hero["turns"] = 0
	hero["flags"] = {"streak": 0, "last": "", "same": 0, "uses": {}, "nc": {}, "once": {}, "cnt": {}}
	var belt = []
	if hero.get("belt") is Array:
		for b in hero.belt:
			if b is Dictionary and str(b.get("id", "")) != "":
				belt.append({"id": str(b.id), "n": maxi(0, _i(b, "n")), "used": 0})
	hero["belt"] = belt

	# the companion
	var pet = setup.get("pet")
	if pet is Dictionary:
		pet = pet.duplicate(true)
		pet["id"] = "pet"
		pet["side"] = "hero"
		pet["alive"] = true
		pet["statuses"] = []
		pet["turns"] = 0
		pet["charge"] = 0
		var kit0 = pet_kit(B, str(pet.get("pet", "")))
		pet["charge_max"] = maxi(1, _i(pet, "charge_max", int(kit0.get("command", {}).get("charge", 3)) if kit0 != null else 3))
		pet["lvl"] = int(hero.lvl)
		pet["atk"] = RpgDefs.offence(float(best_body(hero).v) * 0.5, 0.0, int(hero.lvl)) * float(RpgDefs.PET_RARITY.get(str(pet.get("rarity", "common")), 1.0))
		pet["tec"] = _f(hero.s, "mind", 1.0)
		pet["flags"] = {}
		if not pet.has("spd"):
			pet["spd"] = RpgDefs.PET_SPD + 2.0 * float(RpgDefs.tier_of_level(int(hero.lvl)))
		B["pet"] = pet

	_norm(B)
	hero["at"] = 0.0 if _f(hero.agg, "first_turn") > 0.0 else _first_at(B, hero)
	if B.pet != null:
		B.pet["at"] = _first_at(B, B.pet)

	var ev = []
	if B.waves.is_empty():
		_end(B, ev, true)
	else:
		_start_wave(B, ev, 0)
		_after(B, ev)
		_run(B, ev)
	B["opening"] = _norm(ev)
	_settle(B)
	return B


## What happened before the hero's first choice: the first wave, the intents,
## any foe quicker than the hero. Kept in B until the first `act`.
static func opening(B: Dictionary) -> Array:
	return B.get("opening", [])


## What the hero may do now:
##   {"moves": [{"id", "ok", "why" ("" | "cooldown" | "energy" | "wait"), "cost", "cd"}], "strike", "guard", "flee",
##    "ult": {"id", "ok", "gauge"}, "items": [{"id", "n" (left in the stack), "ok", "used"}],
##    "pet": {"ok", "name", "charge", "max"}, "targets": [ids of the living foes]}
static func options(B: Dictionary) -> Dictionary:
	var h = B.hero
	var live = (not bool(B.over)) and bool(B.wait)
	var out = {"moves": [], "strike": live, "guard": live, "flee": live,
		"ult": {"id": str(h.get("ult", "")), "ok": false, "gauge": _f(h, "gauge")},
		"items": [], "pet": {"ok": false, "name": "", "charge": 0, "max": 0}, "targets": []}
	for id in h.get("moves", []):
		var row = move_row(B, str(id))
		if row == null:
			continue
		var cost = cost_of(B, row)
		var cd = _i(h.cds, str(id))
		var why = ""
		if not live:
			why = "wait"
		elif cd > 0:
			why = "cooldown"
		elif cost > int(h.en):
			why = "energy"
		out.moves.append({"id": str(id), "ok": why == "", "why": why, "cost": cost, "cd": cd})
	var ult = move_row(B, str(h.get("ult", ""))) if str(h.get("ult", "")) != "" else null
	out.ult.ok = live and ult != null and _f(h, "gauge") >= RpgDefs.GAUGE_MAX
	var shut = B.rules.has("no_items")
	for b in h.get("belt", []):
		var left = _i(b, "n") - _i(b, "used")
		out.items.append({"id": str(b.id), "n": maxi(0, left), "used": _i(b, "used"),
			"ok": live and not shut and left > 0 and _i(b, "used") < RpgDefs.BELT_USES and item_row(B, str(b.id)) != null})
	if B.pet != null:
		var kit = pet_kit(B, str(B.pet.get("pet", "")))
		var charge = _i(B.pet, "charge")
		var need = _i(B.pet, "charge_max", 3)
		out.pet = {"ok": live and kit != null and charge >= need, "name": str(kit.command.get("name", "")) if kit != null else "",
			"charge": charge, "max": need}
	if not bool(B.over):
		for f in B.foes:
			if f.alive:
				out.targets.append(str(f.id))
	return out


## Why an action is not allowed now ("" = it is): "over", "wait", "unknown",
## "cooldown", "energy", "gauge", "item", "rule", "pet".
static func illegal(B: Dictionary, action: Dictionary) -> String:
	if bool(B.over):
		return "over"
	if not bool(B.wait):
		return "wait"
	var h = B.hero
	match str(action.get("t", "")):
		"strike", "guard", "flee":
			return ""
		"move":
			var id = str(action.get("id", ""))
			var row = move_row(B, id)
			if row == null or not h.moves.has(id) or bool(row.get("ult", false)):
				return "unknown"
			if _i(h.cds, id) > 0:
				return "cooldown"
			if cost_of(B, row) > int(h.en):
				return "energy"
			return ""
		"ult":
			if str(h.get("ult", "")) == "" or move_row(B, str(h.ult)) == null:
				return "unknown"
			return "" if _f(h, "gauge") >= RpgDefs.GAUGE_MAX else "gauge"
		"item":
			if B.rules.has("no_items"):
				return "rule"
			var b = _belt(h, str(action.get("id", "")))
			if b == null or item_row(B, str(b.id)) == null:
				return "unknown"
			if _i(b, "n") - _i(b, "used") <= 0 or _i(b, "used") >= RpgDefs.BELT_USES:
				return "item"
			return ""
		"pet":
			if B.pet == null or pet_kit(B, str(B.pet.get("pet", ""))) == null:
				return "unknown"
			return "" if _i(B.pet, "charge") >= _i(B.pet, "charge_max", 3) else "pet"
	return "unknown"


## The hero's action, then everything until the hero must choose again or the
## battle is over. Actions: {"t": "move", "id", "target"}, {"t": "strike",
## "target"}, {"t": "guard"}, {"t": "item", "id"}, {"t": "ult", "target"},
## {"t": "pet", "target"} (free: the turn goes on), {"t": "flee"}.
static func act(B: Dictionary, action: Dictionary) -> Array:
	var why = illegal(B, action)
	if why != "":
		return [{"t": "no", "why": why}]
	var ev = []
	B["opening"] = []
	B["n"] = int(B.n) + 1
	B["acting"] = "hero"
	match str(action.get("t", "")):
		"flee":
			B["fled"] = true
			ev.append({"t": "act", "who": "hero", "kind": "flee", "id": "", "name": "Flee", "school": "", "target": ""})
			_end(B, ev, false)
		"pet":
			_pet_do(B, ev, pet_kit(B, str(B.pet.pet)).command, "command", str(action.get("target", B.target)))
			B.pet["charge"] = 0
			ev.append({"t": "charge", "v": 0})
			_after(B, ev)
		_:
			var rank = _hero_act(B, ev, action)
			_after(B, ev)        # a win is checked before the hero's own turn ends
			if not bool(B.over):
				_hero_turn_end(B, ev, rank, false)
				_after(B, ev)
				_run(B, ev)
	_settle(B)
	return _norm(ev)


## The ids of the next `count` to act, assuming every action is of rank 1.
static func timeline(B: Dictionary, count: int = 7) -> Array:
	var out = []
	if bool(B.over):
		return out
	var list = [["hero", _f(B.hero, "at"), RpgDefs.delay(1.0, speed_of(B.hero))]]
	if B.pet != null:
		list.append(["pet", _f(B.pet, "at"), RpgDefs.delay(1.0, speed_of(B.pet))])
	for f in B.foes:
		if f.alive:
			list.append([str(f.id), _f(f, "at"), RpgDefs.delay(1.0, speed_of(f))])
	for i in range(count):
		var best = 0
		for j in range(1, list.size()):
			if float(list[j][1]) < float(list[best][1]):
				best = j
		out.append(list[best][0])
		list[best][1] = float(list[best][1]) + float(list[best][2])
	return out


## A unit by id ("hero", "pet", "f0"...), or null.
static func unit(B: Dictionary, id: String) -> Variant:
	if id == "hero":
		return B.hero
	if id == "pet":
		return B.pet
	for f in B.foes:
		if str(f.id) == id:
			return f
	return null


## The living foes, in their order.
static func foes(B: Dictionary) -> Array:
	var out = []
	for f in B.foes:
		if f.alive:
			out.append(f)
	return out


static func over(B: Dictionary) -> bool:
	return bool(B.over)


static func won(B: Dictionary) -> bool:
	return bool(B.over) and bool(B.win)


## How it went (RPG_PLAN.md 11.4): for the stars, the rewards and the save.
## `turns` = hero turns over all waves, lost ones too; `schools` = the schools
## of the moves used (no Strike, no items, no companion); `worst_share` = the
## biggest single hit as a share of max HP; `learned` = the weaknesses found
## in this battle; `used` = belt items used (taken from the save on a win).
## Beyond the plan: "fled", "kos", "waves" (cleared) and "reward" (the hero's
## `reward` passives added up: {"ore", "xp", "luck"}).
static func summary(B: Dictionary) -> Dictionary:
	var s = B.sum
	var h = B.hero
	var learned = {}
	for k in B.learned:
		learned[k] = B.learned[k].duplicate()
	return _norm({"win": won(B), "turns": _i(s, "turns"), "dealt": _i(s, "dealt"), "taken": _i(s, "taken"),
		"breaks": _i(s, "breaks"), "items": _i(s, "items"), "guards": _i(s, "guards"), "perfect": _i(s, "perfect"),
		"moves": h.get("flags", {}).get("uses", {}).duplicate(), "unguarded": _i(s, "unguarded"), "treasure": _i(s, "treasure"),
		"best_hit": _i(s, "best_hit"), "by_move": s.get("by_move", {}).duplicate() if s.get("by_move") is Dictionary else {},
		"schools": s.schools.duplicate(),
		"worst_share": _f(s, "worst"), "hp_share": _share(h), "learned": learned, "used": s.used.duplicate(),
		"fled": bool(B.fled), "kos": _i(s, "kos"), "waves": _i(s, "waves"),
		"reward": {"ore": _f(h.agg, "reward:ore"), "xp": _f(h.agg, "reward:xp"), "luck": _f(h.agg, "reward:luck")}})


## What may be shown of a foe's schools: everything when the setup set them or
## the hero has Insight, else the weaknesses learned (before or in this battle)
## and the resistances met in this battle.
static func known(B: Dictionary, id: String) -> Dictionary:
	var f = unit(B, id)
	if f == null or str(f.get("side", "")) != "foe":
		return {"weak": [], "resist": [], "all": false}
	if bool(f.get("shown", false)) or has_status(B.hero, "insight"):
		return {"weak": f.weak.duplicate(), "resist": f.resist.duplicate(), "all": true}
	var key = seen_key(f)
	var kw = B.known.get(key, [])
	var kr = B.resist_seen.get(key, [])
	var weak = []
	for sc in f.weak:
		if kw.has(sc) and not f.resist.has(sc):
			weak.append(sc)
	var resist = []
	for sc in f.resist:
		if kr.has(sc):
			resist.append(sc)
	return {"weak": weak, "resist": resist, "all": false}


## The key a foe's weaknesses are remembered under: its id, or "id#2" in a
## boss's second phase.
static func seen_key(f: Dictionary) -> String:
	var phase = _i(f, "phase")
	return str(f.get("foe", "")) if phase <= 0 else "%s#%d" % [str(f.get("foe", "")), phase + 1]


## The intent a foe will show after the one it shows now (Insight), as things stand.
static func next_intent(B: Dictionary, id: String) -> Dictionary:
	var f = unit(B, id)
	if f == null or not f.get("alive", false) or str(f.get("side", "")) != "foe":
		return {}
	return intent_for(B, f, str(RpgAi.choose(B, f, 1).move))


## What an attack would do to its target, total over its hits, without a crit:
##   {"lo", "hi", "weak", "resist", "chip", "kills" (even the low roll does it), "crit" (chance), "hits"}
## It tells only what the player may know: a weakness or resistance not yet
## seen counts as neither (`truth` = true: the real numbers, for tests).
static func preview(B: Dictionary, action: Dictionary, truth: bool = false) -> Dictionary:
	var out = {"lo": 0, "hi": 0, "weak": false, "resist": false, "chip": 0, "kills": false, "crit": 0.0, "hits": 0}
	if bool(B.over):
		return out
	var h = B.hero
	var foe = _target(B, str(action.get("target", "")))
	if foe == null:
		return out
	var t = str(action.get("t", ""))
	if t == "pet":
		if B.pet == null or pet_kit(B, str(B.pet.get("pet", ""))) == null:
			return out
		var cmd = pet_kit(B, str(B.pet.pet)).command
		var pw = float(cmd.get("power", 0.0))
		if pw <= 0.0:
			return out
		var pbase = pw * _f(B.pet, "atk") * RpgDefs.mitigation(_f(foe, "def")) * _taken_mult(foe)
		out.lo = maxi(1, int(floor(pbase * RpgDefs.ROLL_LO)))
		out.hi = maxi(1, int(ceil(pbase * (RpgDefs.ROLL_LO + RpgDefs.ROLL_SPAN))))
		out.hits = 1
		out.kills = out.lo >= int(foe.hp) + _shield(foe)
		return out
	var move = null
	if t == "move":
		move = move_row(B, str(action.get("id", "")))
	elif t == "strike":
		move = strike_row()
	elif t == "ult":
		move = move_row(B, str(h.get("ult", "")))
	if move == null or str(move.get("kind", "attack")) != "attack":
		return out
	var school = str(move.get("school", "plain"))
	var run = _new_run(B, move, t != "strike")
	var vs = _versus(foe, school, t != "strike")
	if not truth:
		var kn = known(B, str(foe.id))
		if vs.weak and not bool(vs.marked) and not kn.weak.has(school):
			vs.weak = false
		if vs.resist and not kn.resist.has(school):
			vs.resist = false
	var hits = maxi(1, int(move.get("hits", 1)))
	var per = float(move.get("power", 0.0)) / float(hits)
	var def = _f(foe, "def") * (1.0 - float(run.ignore))
	var lo = 0
	var hi = 0
	var focus_st = status_of(h, "focus")
	var focus = 0 if focus_st == null else _i(focus_st, "stacks", 1)
	for i in range(hits):
		# a first-hit bonus is only on the first hit; a Focus stack makes one hit a crit
		var mult = maxf(0.1, 1.0 + _hero_bonus(B, h, foe, run, i == 0)) * _status_mult(h, foe)
		if vs.weak:
			mult *= RpgDefs.WEAK_MULT
		elif vs.resist:
			mult *= RpgDefs.RESIST_MULT
		if bool(foe.get("broken", false)):
			mult *= RpgDefs.BROKEN_MULT
		if bool(run.sure) or i < focus:
			mult *= RpgDefs.CRIT_MULT
		var base = per * float(run.off) * RpgDefs.mitigation(def) * mult
		lo += maxi(1, int(floor(base * RpgDefs.ROLL_LO)))
		hi += maxi(1, int(ceil(base * (RpgDefs.ROLL_LO + RpgDefs.ROLL_SPAN))))
	if str(move.get("target", "foe")) == "random" and foes(B).size() > 1:
		lo = int(floor(float(lo) / float(hits)))      # the other hits may land elsewhere
	var chip = 0
	if vs.weak:
		chip = maxi(0, int(move.get("chip", 1))) + int(round(_f(h.agg, "chip:" + school)))
	elif not vs.resist and bool(run.smart):
		chip = 1
	if bool(foe.get("broken", false)) or bool(foe.flags.get("armored", false)):
		chip = 0
	out.lo = lo
	out.hi = hi
	out.weak = bool(vs.weak)
	out.resist = bool(vs.resist)
	out.chip = mini(chip, _i(foe, "guard"))
	out.hits = hits
	out.crit = 1.0 if (bool(run.sure) or focus > 0) else float(run.chance)
	out.kills = lo >= int(foe.hp) + _shield(foe)
	return out


# =============================================================================
# Readers
# =============================================================================

## B is settled (see the top): a whole number may be an int. Read through these.
static func _f(d: Dictionary, key: String, fallback: float = 0.0) -> float:
	var v = d.get(key)
	return float(v) if (v is int or v is float) else fallback


static func _i(d: Dictionary, key: String, fallback: int = 0) -> int:
	var v = d.get(key)
	return int(v) if (v is int or v is float) else fallback


static func _share(u: Dictionary) -> float:
	return clampf(float(u.get("hp", 0)) / maxf(1.0, float(u.get("hp_max", 1))), 0.0, 1.0)


static func status_of(u: Dictionary, id: String) -> Variant:
	for st in u.get("statuses", []):
		if str(st.id) == id:
			return st
	return null


static func has_status(u: Dictionary, id: String) -> bool:
	return status_of(u, id) != null


## What is left of a unit's Shield.
static func _shield(u: Dictionary) -> int:
	var sh = status_of(u, "shield")
	return 0 if sh == null else _i(sh, "amount")


## How many debuffs a unit carries (a stacked one counts once).
static func debuffs(u: Dictionary) -> int:
	var n = 0
	for st in u.get("statuses", []):
		if str(RpgDefs.STATUS.get(str(st.id), {}).get("kind", "")) == "debuff":
			n += 1
	return n


## A unit's speed as things stand: Hasted, Slowed, a foe's quickening.
static func speed_of(u: Dictionary) -> float:
	var spd = _f(u, "spd")
	if has_status(u, "hasted"):
		spd *= RpgDefs.HASTE
	if has_status(u, "slowed"):
		spd *= RpgDefs.SLOW
	var quick = _f(u.get("flags", {}), "quick")
	if quick > 0.0:
		spd *= 1.0 + quick
	return spd


## The hero's best body stat: {"id", "v"} (the first of RpgDefs.BODY on a tie).
static func best_body(h: Dictionary) -> Dictionary:
	var s = h.get("s", {})
	var best = "chest"
	var top = -1.0
	for id in RpgDefs.BODY:
		var v = _f(s, id, 1.0)
		if v > top:
			top = v
			best = id
	return {"id": best, "v": maxf(top, 0.0)}


## What a hero's move hits with: its scale's stats by weight, the gear attack
## of its school, the level. Strike ("plain") uses the best body stat and the
## gear attack of that stat's school.
static func offence_of(h: Dictionary, move: Dictionary) -> float:
	var school = str(move.get("school", "plain"))
	var s = h.get("s", {})
	var w = h.get("w", {})
	var scale = move.get("scale", {})
	var stat = 0.0
	var gear = _f(w, school)
	if school == "plain" or scale.is_empty():
		var best = best_body(h)
		stat = float(best.v)
		if school == "plain":
			gear = _f(w, str(RpgDefs.STAT_SCHOOL.get(str(best.id), "push")))
	else:
		for id in RpgDefs.STATS:      # a fixed order: the sum must not depend on the dictionary's
			if scale.has(id):
				stat += float(scale[id]) * _f(s, id, 1.0)
	return RpgDefs.offence(stat, gear, _i(h, "lvl", 1))


## The energy a move costs the hero now (its passives and a waiting discount counted).
static func cost_of(B: Dictionary, move: Dictionary) -> int:
	var h = B.hero
	var school = str(move.get("school", ""))
	var add = _f(h.agg, "cost:" + school) + _f(h.agg, "cost:all") + _f(h.flags.get("nc", {}), school)
	return maxi(0, int(move.get("cost", 0)) + int(round(add)))


## The turns a move rests after use (a move that rests at all never rests less than one).
static func cd_of(B: Dictionary, move: Dictionary) -> int:
	var h = B.hero
	var school = str(move.get("school", ""))
	var base = int(move.get("cd", 0))
	var add = int(round(_f(h.agg, "cd:" + school) + _f(h.agg, "cd:all")))
	return maxi(mini(base, 1), base + add)


## The free basic attack: power and rank from RpgDefs, never weak, never resisted, never chips.
static func strike_row() -> Dictionary:
	if _strike_row == null:
		_strike_row = {"id": "strike", "name": "Strike", "school": "plain", "kind": "attack", "scale": {},
			"power": RpgDefs.STRIKE_POWER, "hits": 1, "target": "foe", "splash": 0.0, "cost": 0, "cd": 0,
			"rank": RpgDefs.STRIKE_RANK, "chip": 0, "mods": [], "fx": [], "tags": [],
			"text": "A plain hit with your best muscle. Free, and gives 1 energy.", "ult": false, "tier": 0}
	return _strike_row


## Catalog rows, the setup's own first (tests, the rival).
static func move_row(B: Dictionary, id: String) -> Variant:
	var c = B.custom.moves.get(id)
	return c if c != null else RpgMoves.by_id(id)


static func foe_row(B: Dictionary, id: String) -> Variant:
	var c = B.custom.foes.get(id)
	return c if c != null else RpgFoes.by_id(id)


static func foe_move(B: Dictionary, id: String) -> Variant:
	var c = B.custom.foe_moves.get(id)
	if c != null:
		return c
	var m = RpgFoes.move(id)
	return m if m != null else (BASIC if id == "basic" else null)


static func pet_kit(B: Dictionary, id: String) -> Variant:
	var c = B.custom.pets.get(id)
	return c if c != null else RpgPets.by_id(id)


static func item_row(B: Dictionary, id: String) -> Variant:
	var c = B.custom.items.get(id)
	return c if c != null else RpgItems.by_id(id)


## A row a setup brings along ("custom"), made whole: the catalog's defaults
## under what the row says, and its id (the key it came under).
static func _custom_row(part: String, id: String, row: Dictionary) -> Dictionary:
	var out = {}
	match part:
		"moves":
			out = RpgMoves.DEFAULTS.duplicate(true)
			out["name"] = id
			out["school"] = "plain"
		"foe_moves":
			return RpgFoes.full_move(id, row)
		"foes":
			out = RpgFoes.full(row)
			out["id"] = id
			return out
		"items":
			out = {"name": id, "icon": "", "text": "", "fx": [], "price": 0}
	for k in row:
		out[k] = row[k].duplicate(true) if (row[k] is Dictionary or row[k] is Array) else row[k]
	out["id"] = id
	return out


static func _belt(h: Dictionary, id: String) -> Variant:
	for b in h.get("belt", []):
		if str(b.id) == id:
			return b
	return null


## The foe an action is aimed at: the one named if it lives, else the first
## living one (null only when none lives).
static func _target(B: Dictionary, id: String) -> Variant:
	var first = null
	for f in B.foes:
		if not f.alive:
			continue
		if str(f.id) == id:
			return f
		if first == null:
			first = f
	return first


# =============================================================================
# Randomness and the settled form
# =============================================================================

## The next random number in [0, 1). The stream's state is the int B.rng and
## nothing else, so a stored battle draws the same numbers.
static func _rand(B: Dictionary) -> float:
	var st = Rng.Stream.new(int(B.rng))
	var r = st.next()
	B["rng"] = st._s
	return r


## A hit's size from its base: the roll of 4.1, never under 1.
static func _roll(B: Dictionary, base: float) -> int:
	var r1 = _rand(B)
	var r2 = _rand(B)
	return maxi(1, int(floor(base * (RpgDefs.ROLL_LO + RpgDefs.ROLL_SPAN * r1) + r2)))


## A number as it is kept in B: six decimals, a whole one as an int.
static func _num(v: float) -> Variant:
	var q = round(v * 1000000.0) / 1000000.0
	if q == floor(q) and absf(q) < 9.0e15:
		return int(q)
	return q


## Everything under `v` in settled form, in place (never give it catalog data).
static func _norm(v) -> Variant:
	if v is float:
		return _num(v)
	if v is Dictionary:
		for k in v.keys():
			var x = v[k]
			if x is float or x is Dictionary or x is Array:
				v[k] = _norm(x)
		return v
	if v is Array:
		for i in range(v.size()):
			var x = v[i]
			if x is float or x is Dictionary or x is Array:
				v[i] = _norm(x)
		return v
	return v


## The kinds of rows a setup may bring along in "custom" (tests, the rival).
const CUSTOM_PARTS = ["moves", "foes", "foe_moves", "pets", "items"]
## The parts of a unit that never change after it enters (settled once).
const UNIT_FIXED = ["fx", "agg", "s", "w", "moves", "pattern", "rules", "phases", "weak", "resist"]
## The parts of B an action cannot unsettle (units are walked on their own).
const B_FIXED = ["hero", "pet", "foes", "waves", "custom", "what", "rules", "known", "resist_seen", "learned", "opening"]


static func _settle_unit(u: Dictionary) -> void:
	for k in u.keys():
		if UNIT_FIXED.has(k):
			continue
		var x = u[k]
		if x is float or x is Dictionary or x is Array:
			u[k] = _norm(x)


## B back in settled form after an action (only what an action can change is walked).
static func _settle(B: Dictionary) -> void:
	for k in B.keys():
		if B_FIXED.has(k):
			continue
		var x = B[k]
		if x is float or x is Dictionary or x is Array:
			B[k] = _norm(x)
	_settle_unit(B.hero)
	if B.pet != null:
		_settle_unit(B.pet)
	for f in B.foes:
		_settle_unit(f)


## "" when `v` is exactly what a JSON round trip gives back, else the path of
## the first value that is not (tests call it on B after every action).
static func json_safe(v, path: String = "B") -> String:
	if v == null or v is bool or v is String or v is int:
		return ""
	if v is float:
		if not is_finite(v):
			return path + " is not finite"
		var n = _num(v)
		return "" if (n is float and n == v) else path + " is not settled (%s)" % str(v)
	if v is Dictionary:
		for k in v:
			if not (k is String):
				return path + " has a key that is not a String"
			var why = json_safe(v[k], path + "." + k)
			if why != "":
				return why
		return ""
	if v is Array:
		for i in range(v.size()):
			var why = json_safe(v[i], "%s[%d]" % [path, i])
			if why != "":
				return why
		return ""
	return path + " is not JSON (%s)" % type_string(typeof(v))


# =============================================================================
# The turn loop (4.2)
# =============================================================================

## The time of a unit's first action (4.2): half to a whole rank-1 delay from now.
static func _first_at(B: Dictionary, u: Dictionary) -> float:
	return _f(B, "now") + RpgDefs.delay(1.0, speed_of(u)) * (0.5 + 0.5 * _rand(B))


## Who acts next: the lowest `at`; on a tie the hero, the companion, then the
## foes in their order (a strict "<" over that order).
static func _next(B: Dictionary) -> Dictionary:
	var best = B.hero
	var at = _f(best, "at")
	if B.pet != null and _f(B.pet, "at") < at:
		best = B.pet
		at = _f(best, "at")
	for f in B.foes:
		if f.alive and _f(f, "at") < at:
			best = f
			at = _f(f, "at")
	return best


## Turns pass until the hero must choose (B.wait) or the battle is over.
static func _run(B: Dictionary, ev: Array) -> void:
	var spins = 0
	while not bool(B.over) and not bool(B.wait):
		spins += 1
		if spins > 500:
			# Cannot happen with a sound catalog; a broken one must not hang the game.
			ev.append({"t": "say", "text": "The fight breaks off."})
			_end(B, ev, false)
			break
		var u = _next(B)
		B["now"] = _f(u, "at")
		B["acting"] = str(u.id)
		if str(u.id) == "hero":
			if _hero_turn_start(B, ev):
				B["wait"] = true
		elif str(u.id) == "pet":
			_pet_turn(B, ev)
		else:
			_foe_turn(B, ev, u)
		_after(B, ev)
	B["acting"] = "hero" if bool(B.wait) else ""


## After anything that happened: boss phases, then a WIN FIRST (the last foe
## down wins even if the hero fell in the same action), the next wave, a loss,
## and the intents' numbers brought up to date (an intent never lies).
static func _after(B: Dictionary, ev: Array) -> void:
	if bool(B.over):
		return
	_check_phases(B, ev)
	while not bool(B.over) and foes(B).is_empty():
		if int(B.wave) >= B.waves.size() - 1:
			B.sum["waves"] = B.waves.size()
			_end(B, ev, true)
			return
		if int(B.hero.hp) <= 0:
			break
		_next_wave(B, ev)
	if int(B.hero.hp) <= 0:
		_end(B, ev, false)
		return
	_refresh_intents(B, ev)


static func _end(B: Dictionary, ev: Array, win: bool) -> void:
	B["over"] = true
	B["win"] = win
	B["wait"] = false
	B["acting"] = ""
	ev.append({"t": "end", "win": win})


## What every unit's turn starts with: Regen, then its "turn" passives.
static func _turn_start(B: Dictionary, ev: Array, u: Dictionary) -> void:
	if has_status(u, "regen"):
		_heal(B, ev, u, int(round(RpgDefs.REGEN_PCT * float(u.hp_max))))
	_fire(B, ev, u, "turn", null)


## What every unit's turn ends with: Burn and Bleed bite, durations run down
## (a status put on the unit during this very turn does not lose a turn yet),
## the time it cannot be stunned again runs down.
static func _turn_end(B: Dictionary, ev: Array, u: Dictionary) -> void:
	for st in u.statuses.duplicate():
		if int(u.hp) <= 0:
			break
		var id = str(st.id)
		if id != "burn" and id != "bleed":
			continue
		var stacks = float(maxi(1, _i(st, "stacks", 1))) if id == "bleed" else 1.0
		var amount = 0
		if str(u.side) == "foe":
			# on a foe: a share of the applier's offence, after the foe's defence
			amount = maxi(1, int(floor(_f(st, "amount") * stacks * RpgDefs.mitigation(_f(u, "def")))))
			if id == "burn" and bool(u.get("boss", false)):
				amount = mini(amount, maxi(1, int(floor(RpgDefs.BOSS_DOT_CAP * float(u.hp_max)))))
		else:
			var pct = RpgDefs.BURN_PCT if id == "burn" else RpgDefs.BLEED_PCT * stacks
			amount = maxi(1, int(round(pct * float(u.hp_max))))
		_tick(B, ev, u, id, amount)
	if int(u.hp) <= 0:
		return
	var keep = []
	for st in u.statuses:
		if bool(st.get("fresh", false)):
			st.erase("fresh")
			keep.append(st)
			continue
		var turns = _i(st, "turns")
		if turns > 0:
			turns -= 1
			if turns == 0:
				ev.append({"t": "status", "dst": str(u.id), "id": str(st.id), "on": false, "turns": 0, "stacks": 0, "resisted": false})
				continue
			st["turns"] = turns
		keep.append(st)
	u["statuses"] = keep
	if _i(u, "stun_guard") > 0:
		u["stun_guard"] = _i(u, "stun_guard") - 1


## Damage over time: past a Shield, no gauge for the dealer, no "on kill".
static func _tick(B: Dictionary, ev: Array, u: Dictionary, id: String, amount: int) -> void:
	var hp = int(u.hp)
	var lost = mini(amount, hp)
	var saved = 0
	if lost >= hp:
		saved = _survive(u)
		if saved > 0:
			lost = maxi(0, hp - saved)
	u["hp"] = saved if saved > 0 else hp - lost      # survived: it STANDS at that share, even if it had less
	ev.append({"t": "tick", "dst": str(u.id), "id": id, "amount": lost, "hp": int(u.hp)})
	if saved > 0:
		ev.append({"t": "survive", "dst": str(u.id), "hp": int(u.hp)})
	if str(u.side) == "foe":
		B.sum["dealt"] = _i(B.sum, "dealt") + lost
	else:
		_took(B, ev, lost, false)
	if int(u.hp) <= 0:
		_ko(B, ev, u)
	else:
		_check_low(B, ev, u)


# =============================================================================
# The hero's turn (4.3)
# =============================================================================

## The start of a hero turn: +1 energy, Regen, passives. False when the turn is
## lost to a Stun (it was still a turn: everything ran).
static func _hero_turn_start(B: Dictionary, ev: Array) -> bool:
	var h = B.hero
	h["turns"] = _i(h, "turns") + 1
	B.sum["turns"] = _i(B.sum, "turns") + 1
	ev.append({"t": "turn", "who": "hero", "n": int(h.turns)})
	h["guarding"] = false           # Guard lasts until the hero's next turn
	_energy(B, ev, RpgDefs.EN_TURN)
	_turn_start(B, ev, h)
	if has_status(h, "stun"):
		_drop_status(B, ev, h, "stun")
		ev.append({"t": "act", "who": "hero", "kind": "lost", "id": "", "name": "Stunned", "school": "", "target": ""})
		h.flags["streak"] = 0
		_hero_turn_end(B, ev, 1.0, true)
		return false
	return true


## The end of a hero turn: ticks, cooldowns, and the wait until the next one.
static func _hero_turn_end(B: Dictionary, ev: Array, rank: float, lost: bool) -> void:
	var h = B.hero
	B["wait"] = false
	# The wait until the next turn is set by the speed the hero HAD in this turn:
	# a Haste or a Slow in its last turn still counts for the wait it ends with.
	var spd = speed_of(h)
	_turn_end(B, ev, h)
	if lost:
		h["stun_guard"] = RpgDefs.STUN_IMMUNE
	for id in h.cds.keys():
		var left = _i(h.cds, id) - 1
		if left <= 0:
			h.cds.erase(id)
		else:
			h.cds[id] = left
	if bool(h.flags.get("extra", false)) and not lost:
		h.flags.erase("extra")      # an extra turn: `at` stays where it is, the hero is next again
	else:
		h.flags.erase("extra")
		h["at"] = _f(h, "at") + RpgDefs.delay(rank, spd)


## One hero action (not the free companion command). Returns its rank.
static func _hero_act(B: Dictionary, ev: Array, action: Dictionary) -> float:
	var h = B.hero
	match str(action.get("t", "")):
		"guard":
			h["guarding"] = true
			h.flags["streak"] = 0
			B.sum["guards"] = _i(B.sum, "guards") + 1
			ev.append({"t": "act", "who": "hero", "kind": "guard", "id": "guard", "name": "Guard", "school": "", "target": ""})
			_energy(B, ev, RpgDefs.EN_GUARD + int(round(_f(h.agg, "guard_en"))))
			_fire(B, ev, h, "guard", null)
			return RpgDefs.GUARD_RANK
		"item":
			var b = _belt(h, str(action.get("id", "")))
			var item = item_row(B, str(b.id))
			b["used"] = _i(b, "used") + 1
			h.flags["streak"] = 0
			B.sum["items"] = _i(B.sum, "items") + 1
			B.sum.used[str(b.id)] = _i(B.sum.used, str(b.id)) + 1
			ev.append({"t": "act", "who": "hero", "kind": "item", "id": str(b.id), "name": str(item.get("name", "")), "school": "", "target": ""})
			var tgt = _target(B, str(B.target))
			var ctx = {"src": h, "targets": [tgt] if tgt != null else [], "status_to": "self", "help_to": "self", "off": 0.0, "dealt": 0, "killed": false, "move_id": ""}
			for e in item.get("fx", []):
				_apply_fx(B, ev, e, ctx)
			return RpgDefs.ITEM_RANK
		"strike":
			return _do_move(B, ev, strike_row(), str(action.get("target", "")), "strike")
		"ult":
			return _do_move(B, ev, move_row(B, str(h.ult)), str(action.get("target", "")), "ult")
	return _do_move(B, ev, move_row(B, str(action.get("id", ""))), str(action.get("target", "")), "move")


## What one use of a move carries along: its numbers read once, and what has
## happened so far ("once per move per target" lives here).
static func _new_run(B: Dictionary, move: Dictionary, is_move: bool) -> Dictionary:
	var h = B.hero
	var run = {"move": move, "school": str(move.get("school", "plain")), "is_move": is_move,
		"off": offence_of(h, move), "chance": _f(h, "crit"), "sure": false, "ignore": 0.0, "smart": false,
		"vs": {}, "hit": {}, "order": [], "critc": {}, "counters": {},
		"dealt": 0, "kills": 0, "crit": "", "weak": ""}
	for mod in move.get("mods", []):
		match str(mod.get("m", "")):
			"crit":
				run.chance = float(run.chance) + float(mod.get("add", 0.0))
			"sure_crit":
				run.sure = true
			"ignore_def":
				run.ignore = clampf(float(run.ignore) + float(mod.get("pct", 0.0)), 0.0, 1.0)
			"smart":
				run.smart = true
	run.chance = clampf(float(run.chance), 0.0, 1.0)
	return run


## A move, Strike or the ultimate: the hits, then the effects in order, then
## the gauge, the passives and the bookkeeping. Returns the rank.
static func _do_move(B: Dictionary, ev: Array, move: Dictionary, target_id: String, how: String) -> float:
	var h = B.hero
	var id = str(move.id)
	var school = str(move.get("school", "plain"))
	var attack = str(move.get("kind", "attack")) == "attack"
	var is_move = how != "strike"
	var tgt = _target(B, target_id)         # a missing or dead target becomes the first living foe
	if tgt != null:
		B["target"] = str(tgt.id)
	if how == "move":
		_energy(B, ev, -cost_of(B, move))
		if h.flags.nc.has(school):
			h.flags.nc.erase(school)        # the waiting discount is used
	elif how == "ult":
		B["ulting"] = true                  # the ultimate uses the whole gauge and fills none of it
		h["gauge"] = 0
		ev.append({"t": "gauge", "v": 0})
	elif how == "strike":
		_energy(B, ev, RpgDefs.EN_STRIKE)
	ev.append({"t": "act", "who": "hero", "kind": how, "id": id, "name": str(move.get("name", "")), "school": school,
		"target": str(tgt.id) if tgt != null else ""})

	var run = _new_run(B, move, is_move)
	if attack:
		var hits = maxi(1, int(move.get("hits", 1)))
		var per = float(move.get("power", 0.0)) / float(hits)
		var mode = str(move.get("target", "foe"))
		var splash = float(move.get("splash", 0.0))
		for i in range(hits):
			var living = foes(B)
			if living.is_empty():
				break
			if mode == "all":
				for f in living:
					_hero_hit(B, ev, run, f, per)
			elif mode == "random":
				_hero_hit(B, ev, run, living[int(floor(_rand(B) * float(living.size()))) % living.size()], per)
			else:
				if tgt == null or not tgt.alive:
					tgt = living[0]
				_hero_hit(B, ev, run, tgt, per)
				if splash > 0.0:
					for f in living:
						if f.alive and str(f.id) != str(tgt.id):
							_hero_hit(B, ev, run, f, per * splash)

	# the effects, in the order written
	var touched = []
	if attack:
		for fid in run.order:
			var f = unit(B, str(fid))
			if f != null:
				touched.append(f)
	elif tgt != null and str(move.get("target", "foe")) != "self":
		touched.append(tgt)
	var ctx = {"src": h, "targets": touched, "status_to": "target" if attack else "self", "help_to": "self",
		"off": float(run.off), "dealt": int(run.dealt), "killed": int(run.kills) > 0, "move_id": id}
	for e in move.get("fx", []):
		_apply_fx(B, ev, e, ctx)

	if attack:
		var steal = _f(h.agg, "lifesteal")
		if steal > 0.0 and int(run.dealt) > 0:
			_heal(B, ev, h, int(round(steal * float(run.dealt))))
		# foes with Counter strike back, once each
		for f in B.foes:
			if run.counters.has(str(f.id)) and f.alive and int(h.hp) > 0 and has_status(f, "counter"):
				_foe_hit(B, ev, f, _f(status_of(f, "counter"), "amount", 1.0), {"hit": false, "dealt": 0}, true)
		# a foe that adapts now resists what just hit it
		if RpgDefs.ATTACK_SCHOOLS.has(school):
			for f in touched:
				if f.alive and _f(f.get("agg", {}), "adapt") > 0.0 and not (f.resist.size() == 1 and f.resist[0] == school):
					f["resist"] = [school]
					_note(B.resist_seen, seen_key(f), school)
					ev.append({"t": "adapt", "dst": str(f.id), "school": school})
		_gauge(B, ev, RpgDefs.GAUGE_ACT + (RpgDefs.GAUGE_WEAK if str(run.weak) != "" else 0.0), false)
		if str(run.crit) != "":
			_fire(B, ev, h, "crit", unit(B, str(run.crit)))
		if str(run.weak) != "":
			_fire(B, ev, h, "weak", unit(B, str(run.weak)))

	# bookkeeping
	if int(run.dealt) > 0:
		# what each move did over the fight (the result names the one that did the most)
		if not (B.sum.get("by_move") is Dictionary):
			B.sum["by_move"] = {}
		var by_key = id if is_move else "strike"
		B.sum.by_move[by_key] = _i(B.sum.by_move, by_key) + int(run.dealt)
	if is_move:
		h.flags.uses[id] = _i(h.flags.uses, id) + 1
		if how == "move":
			h.cds[id] = cd_of(B, move) + 1     # the end of this turn takes the one off again
		if RpgDefs.SCHOOLS.has(school):
			h.flags["same"] = (_i(h.flags, "same") + 1) if str(h.flags.get("last", "")) == school else 1
			h.flags["last"] = school
			var later = int(round(_f(h.agg, "next_cost:" + school) + _f(h.agg, "next_cost:all")))
			if later != 0:
				h.flags.nc[school] = later
			if not B.sum.schools.has(school):
				B.sum.schools.append(school)
	h.flags["streak"] = (_i(h.flags, "streak") + 1) if attack else 0
	B["ulting"] = false
	if how == "ult":
		return RpgDefs.ULT_RANK             # whatever its row says (4.3)
	return float(move.get("rank", 1.0))


# =============================================================================
# Hits (4.1, 4.4)
# =============================================================================

## How a school meets a foe: {"weak", "resist", "marked"}. Strike ("plain") is
## never either. A resistance wins over a weakness (a foe that adapted). A
## Marked foe takes any MOVE as weak.
static func _versus(foe: Dictionary, school: String, is_move: bool) -> Dictionary:
	var vs = {"weak": false, "resist": false, "marked": false}
	if school == "plain":
		return vs
	vs.resist = foe.get("resist", []).has(school)
	vs.weak = foe.get("weak", []).has(school) and not vs.resist
	if is_move and has_status(foe, "marked"):
		vs.weak = true
		vs.resist = false
		vs.marked = true
	return vs


## Pumped / Weakened of the one who hits, Braced / Exposed of the one hit.
static func _status_mult(a: Dictionary, d: Dictionary) -> float:
	var m = _taken_mult(d)
	if has_status(a, "pumped"):
		m *= 1.0 + RpgDefs.PUMP
	if has_status(a, "weakened"):
		m *= 1.0 - RpgDefs.PUMP
	return m


## What a unit takes more or less of: Braced, Exposed, and Broken for a companion's hit.
static func _taken_mult(d: Dictionary) -> float:
	var m = 1.0
	if has_status(d, "braced"):
		m *= 1.0 - RpgDefs.BRACE
	if has_status(d, "exposed"):
		m *= 1.0 + RpgDefs.BRACE
	return m


## Every "+N%" of a hero hit, added up: the move's mods and the hero's passives.
static func _hero_bonus(B: Dictionary, h: Dictionary, foe: Dictionary, run: Dictionary, first: bool) -> float:
	var move = run.move
	var school = str(run.school)
	var agg = h.agg
	var b = 0.0
	for mod in move.get("mods", []):
		var pct = float(mod.get("pct", 0.0))
		match str(mod.get("m", "")):
			"vs_status":
				if has_status(foe, str(mod.get("id", ""))):
					b += pct
			"vs_debuff":
				if debuffs(foe) > 0:
					b += pct
			"per_debuff":
				b += minf(float(mod.get("max", pct)), pct * float(debuffs(foe)))
			"vs_broken":
				if bool(foe.get("broken", false)):
					b += pct
			"vs_full_hp":
				if int(foe.hp) >= int(foe.hp_max):
					b += pct
			"execute":
				if _share(foe) < float(mod.get("below", 0.0)):
					b += pct
			"ramp_use":
				b += minf(float(mod.get("max", pct)), pct * float(_i(h.flags.uses, str(move.id))))
			"ramp_turn":
				b += minf(float(mod.get("max", pct)), pct * float(maxi(0, _i(h, "turns") - 1)))
			"streak":
				b += minf(float(mod.get("max", pct)), pct * float(_i(h.flags, "streak")))
			"missing_hp":
				b += pct * (1.0 - _share(h))
	b += _f(agg, "school_pct:" + school) + _f(agg, "school_pct:all")
	var scale = move.get("scale", {})
	for id in RpgDefs.STATS:
		if scale.has(id) and agg.has("stat_dmg:" + id):
			b += _f(agg, "stat_dmg:" + id) * float(scale[id])
	if bool(foe.get("broken", false)):
		b += _f(agg, "vs_broken")
	for st in foe.get("statuses", []):
		b += _f(agg, "vs_status:" + str(st.id))
	if first and not bool(foe.flags.get("touched", false)):
		b += _f(agg, "first_hit")
	if bool(run.is_move) and RpgDefs.SCHOOLS.has(school):
		var last = str(h.flags.get("last", ""))
		if last == school:
			b += minf(_f(agg, "combo_same_max"), _f(agg, "combo_same") * float(_i(h.flags, "same")))
		elif last != "":
			b += _f(agg, "combo_alt")
	b += minf(_f(agg, "ramp_max"), _f(agg, "ramp") * float(maxi(0, _i(h, "turns") - 1)))
	return b


## Does the unit slip the hit: an Evade stack first, then its dodge chance.
static func _slips(B: Dictionary, ev: Array, u: Dictionary) -> bool:
	if _take_stack(B, ev, u, "evade"):
		return true
	var d = _f(u, "dodge")
	return d > 0.0 and _rand(B) < d


## One hit of the hero's move on one foe.
static func _hero_hit(B: Dictionary, ev: Array, run: Dictionary, foe: Dictionary, power: float) -> void:
	if not foe.alive:
		return
	var h = B.hero
	var fid = str(foe.id)
	if _slips(B, ev, foe):
		ev.append({"t": "miss", "src": "hero", "dst": fid})
		return
	var school = str(run.school)
	if not run.vs.has(fid):
		run.vs[fid] = _versus(foe, school, bool(run.is_move))     # judged once per move per target
	var vs = run.vs[fid]
	var first = not run.hit.has(fid)

	var crit = bool(run.sure)
	if not crit and _take_stack(B, ev, h, "focus"):
		crit = true                                               # Focus: this hit is a sure crit
	if not crit:
		crit = _rand(B) < float(run.chance)

	var mult = maxf(0.1, 1.0 + _hero_bonus(B, h, foe, run, first)) * _status_mult(h, foe)
	if vs.weak:
		mult *= RpgDefs.WEAK_MULT
	elif vs.resist:
		mult *= RpgDefs.RESIST_MULT
	if bool(foe.broken):
		mult *= RpgDefs.BROKEN_MULT
	if crit:
		mult *= RpgDefs.CRIT_MULT
	var def = _f(foe, "def") * (1.0 - float(run.ignore))
	var amount = _roll(B, power * float(run.off) * RpgDefs.mitigation(def) * mult)

	# the guard: chipped ONCE per move per target, however many hits
	var chip = 0
	if first:
		if vs.weak:
			chip = maxi(0, int(run.move.get("chip", 1)))
		elif not vs.resist and bool(run.smart):
			chip = 1
		if chip > 0:
			chip += int(round(_f(h.agg, "chip:" + school)))
	if crit and not run.critc.has(fid) and school != "plain" and not vs.resist:
		var more = int(round(_f(h.agg, "chip:crit")))
		if more > 0:
			run.critc[fid] = true
			chip += more
	var took = _chip(foe, chip)

	var lost = _hurt(B, ev, foe, amount, {"src": "hero", "crit": crit, "weak": bool(vs.weak), "resist": bool(vs.resist), "chip": took, "school": school})
	run.dealt = int(run.dealt) + lost
	if first:
		run.hit[fid] = true
		run.order.append(fid)
		if vs.marked:
			_take_stack(B, ev, foe, "marked")
		if vs.resist:
			_note(B.resist_seen, seen_key(foe), school)
		elif foe.weak.has(school):
			_learn(B, ev, foe, school)
	foe.flags["touched"] = true
	if crit and str(run.crit) == "":
		run.crit = fid
	if vs.weak and str(run.weak) == "":
		run.weak = fid
	if has_status(foe, "counter"):
		run.counters[fid] = true
	if int(foe.hp) <= 0:
		_ko(B, ev, foe)
		run.kills = int(run.kills) + 1
		_fire(B, ev, h, "kill", foe)
	else:
		if took > 0 and _i(foe, "guard") <= 0:
			_break(B, ev, foe)
		_fire(B, ev, foe, "hit_taken", h)


## One hit of a foe on the hero (`power` in units of the foe's attack).
## `counter`: a strike back, which never crits.
static func _foe_hit(B: Dictionary, ev: Array, f: Dictionary, power: float, run: Dictionary, counter: bool = false) -> void:
	var h = B.hero
	if int(h.hp) <= 0:
		return
	if _slips(B, ev, h):
		ev.append({"t": "miss", "src": str(f.id), "dst": "hero"})
		return
	var crit = false
	if not counter:
		if _take_stack(B, ev, f, "focus"):
			crit = true
		elif _f(f, "crit") > 0.0:
			crit = _rand(B) < _f(f, "crit")
	var mult = _foe_mult(B, f)
	if crit:
		mult *= RpgDefs.FOE_CRIT_MULT
	var amount = _roll(B, power * _f(f, "atk") * RpgDefs.mitigation(_f(h, "def")) * mult)
	var info = {"src": str(f.id), "crit": crit, "weak": false, "resist": false, "chip": 0, "school": ""}
	if counter:
		info["counter"] = true
	var lost = _hurt(B, ev, h, amount, info)
	run["hit"] = true
	run["dealt"] = int(run.get("dealt", 0)) + lost
	if int(h.hp) <= 0:
		_ko(B, ev, h)
	else:
		_fire(B, ev, h, "hit_taken", f)


## What a foe's hit on the hero is multiplied by as things stand: its own
## bonuses, the statuses on both, and the hero's Guard.
static func _foe_mult(B: Dictionary, f: Dictionary, ahead: int = 0) -> float:
	var h = B.hero
	var agg = f.get("agg", {})
	var b = _f(agg, "school_pct:all")
	for st in h.get("statuses", []):
		b += _f(agg, "vs_status:" + str(st.id))
	# `ahead`: how many of its turns from now the hit comes (0 = it is hitting now), for a `ramp` trait
	b += minf(_f(agg, "ramp_max"), _f(agg, "ramp") * float(maxi(0, _i(f, "turns") - 1 + ahead)))
	var mult = maxf(0.1, 1.0 + b) * _status_mult(f, h)
	if bool(h.get("guarding", false)):
		mult *= RpgDefs.guard_mult(_f(h.s, "core", 1.0), _f(h.agg, "guard_pct"))
	return mult


## A hit lands: the Shield soaks first, a lethal blow may be survived once.
## The `dmg` event's amount is what got past the Shield. Returns the HP lost.
static func _hurt(B: Dictionary, ev: Array, dst: Dictionary, amount: int, info: Dictionary) -> int:
	var absorbed = 0
	var sh = status_of(dst, "shield")
	if sh != null:
		absorbed = mini(_i(sh, "amount"), amount)
		sh["amount"] = _i(sh, "amount") - absorbed
	var hit = amount - absorbed
	var hp = int(dst.hp)
	var lost = mini(hit, hp)
	var saved = 0
	if lost >= hp and hp > 0:
		saved = _survive(dst)
		if saved > 0:
			lost = maxi(0, hp - saved)
	dst["hp"] = saved if saved > 0 else hp - lost    # survived: it STANDS at that share, even if it had less
	var e = {"t": "dmg", "src": str(info.get("src", "")), "dst": str(dst.id), "amount": hit, "crit": bool(info.get("crit", false)),
		"weak": bool(info.get("weak", false)), "resist": bool(info.get("resist", false)), "chip": int(info.get("chip", 0)),
		"hp": int(dst.hp), "guard": _i(dst, "guard"), "school": str(info.get("school", "")), "absorbed": absorbed}
	if bool(info.get("counter", false)):
		e["counter"] = true
	ev.append(e)
	if sh != null and _i(sh, "amount") <= 0:
		_drop_status(B, ev, dst, "shield")
	if saved > 0:
		ev.append({"t": "survive", "dst": str(dst.id), "hp": int(dst.hp)})
	if str(dst.side) == "foe":
		B.sum["dealt"] = _i(B.sum, "dealt") + lost
		# the hardest single hit of the fight, as its number read on screen
		B.sum["best_hit"] = maxi(_i(B.sum, "best_hit"), hit)
	else:
		_took(B, ev, lost, true)
	if int(dst.hp) > 0:
		_check_low(B, ev, dst)          # "low_hp" passives, the hero's and a foe's
	return lost


## The hero lost HP: the summary, and the gauge fills with the share lost.
static func _took(B: Dictionary, ev: Array, lost: int, hit: bool) -> void:
	if lost <= 0:
		return
	var share = float(lost) / maxf(1.0, float(B.hero.hp_max))
	B.sum["taken"] = _i(B.sum, "taken") + lost
	if hit and share > _f(B.sum, "worst"):
		B.sum["worst"] = share
	_gauge(B, ev, RpgDefs.GAUGE_HURT * share, false)


## An unused `survive` passive keeps the unit standing: the HP it is left with (0 = there is none).
static func _survive(u: Dictionary) -> int:
	var fx = u.get("fx", [])
	if _f(u.get("agg", {}), "has_survive") <= 0.0:
		return 0
	for i in range(fx.size()):
		var e = fx[i]
		if str(e.get("p", "")) != "survive" or u.flags.once.has("s" + str(i)):
			continue
		u.flags.once["s" + str(i)] = true
		return maxi(1, int(round(float(e.get("pct", 0.0)) * float(u.hp_max))))
	return 0


static func _ko(B: Dictionary, ev: Array, u: Dictionary) -> void:
	u["alive"] = false
	u["hp"] = 0
	u["statuses"] = []
	if str(u.side) == "foe":
		u["broken"] = false
		u["intent"] = {}
		B.sum["kos"] = _i(B.sum, "kos") + 1
		if str(u.get("foe", "")) == RpgDefs.TREASURE_FOE:
			B.sum["treasure"] = _i(B.sum, "treasure") + 1
	ev.append({"t": "ko", "dst": str(u.id)})


## Takes guard pips off a foe; returns how many went. Nothing while it is
## Broken, and nothing after its pips came back until it has acted once.
static func _chip(foe: Dictionary, n: int) -> int:
	if n <= 0 or not foe.alive or bool(foe.get("broken", false)) or bool(foe.flags.get("armored", false)):
		return 0
	var g = _i(foe, "guard")
	var took = mini(g, n)
	if took > 0:
		foe["guard"] = g - took
	return took


## Guard at 0: Broken. Its intent is cancelled, it loses its next action and
## takes more until that lost action has passed.
static func _break(B: Dictionary, ev: Array, foe: Dictionary) -> void:
	foe["broken"] = true
	foe["guard"] = 0
	B.sum["breaks"] = _i(B.sum, "breaks") + 1
	ev.append({"t": "break", "dst": str(foe.id)})
	foe["intent"] = _lost_intent("Broken")
	ev.append({"t": "intent", "who": str(foe.id), "intent": foe.intent.duplicate(true)})
	_gauge(B, ev, RpgDefs.GAUGE_BREAK, false)
	_fire(B, ev, B.hero, "break", foe)


## A weak hit teaches that school for good, unless the setup set the weaknesses.
static func _learn(B: Dictionary, ev: Array, foe: Dictionary, school: String) -> void:
	if bool(foe.get("shown", false)):
		return
	var key = seen_key(foe)
	if B.known.get(key, []).has(school):
		return
	_note(B.known, key, school)
	_note(B.learned, key, school)
	ev.append({"t": "learn", "key": key, "school": school})


static func _note(book: Dictionary, key: String, school: String) -> void:
	if not book.has(key):
		book[key] = []
	if not book[key].has(school):
		book[key].append(school)


# =============================================================================
# Energy, gauge, healing
# =============================================================================

static func _energy(B: Dictionary, ev: Array, n: int) -> void:
	var h = B.hero
	var v = clampi(int(h.en) + n, 0, int(h.en_max))
	if v != int(h.en):
		h["en"] = v
		ev.append({"t": "energy", "v": v})


## The gauge: natural gains (raw false) are multiplied by Grit and passives and
## are not had during the ultimate; an effect's (raw true) is as written.
static func _gauge(B: Dictionary, ev: Array, n: float, raw: bool) -> void:
	var h = B.hero
	if not raw and bool(B.ulting):
		return
	var add = n if raw else n * RpgDefs.gauge_mult(_f(h.s, "grit", 1.0), _f(h.agg, "gauge_rate"))
	var before = _f(h, "gauge")
	var v = round(clampf(before + add, 0.0, RpgDefs.GAUGE_MAX) * 100.0) / 100.0
	if v != before:
		h["gauge"] = v
		ev.append({"t": "gauge", "v": v})


static func _heal(B: Dictionary, ev: Array, u: Dictionary, amount: int) -> int:
	if not u.get("alive", false) or int(u.hp) <= 0:
		return 0
	var got = clampi(amount, 0, int(u.hp_max) - int(u.hp))
	if got > 0:
		u["hp"] = int(u.hp) + got
		ev.append({"t": "heal", "dst": str(u.id), "amount": got, "hp": int(u.hp)})
	return got


## What a healer's heals and shields are multiplied by (the hero: Flow and its passives).
static func _heal_mult(B: Dictionary, src: Dictionary) -> float:
	if str(src.side) == "hero":
		return RpgDefs.heal_mult(_f(B.hero.s, "flow", 1.0), _f(B.hero.agg, "heal_pct"))
	return 1.0 + _f(src.get("agg", {}), "heal_pct")


# =============================================================================
# Statuses (4.6)
# =============================================================================

static func _drop_status(B: Dictionary, ev: Array, u: Dictionary, id: String) -> bool:
	for i in range(u.statuses.size()):
		if str(u.statuses[i].id) == id:
			u.statuses.remove_at(i)
			ev.append({"t": "status", "dst": str(u.id), "id": id, "on": false, "turns": 0, "stacks": 0, "resisted": false})
			return true
	return false


## Uses up one stack of Focus, Evade or Marked. False when the unit has none.
static func _take_stack(B: Dictionary, ev: Array, u: Dictionary, id: String) -> bool:
	var st = status_of(u, id)
	if st == null:
		return false
	var left = _i(st, "stacks", 1) - 1
	if left <= 0:
		_drop_status(B, ev, u, id)
	else:
		st["stacks"] = left
		ev.append({"t": "status", "dst": str(u.id), "id": id, "on": true, "turns": _i(st, "turns"), "stacks": left, "resisted": false})
	return true


## Puts a status on a unit, by the rules of 4.6, without asking whether it
## lands: a pair cancels (both are gone); the same again refreshes the
## duration; Bleed, Focus and Evade add a stack; a Shield keeps the larger.
## Returns {"on": bool, "cancel": the status it cancelled or ""}.
static func _put_status(u: Dictionary, id: String, turns: int, stacks: int, amount: float, by: String, fresh: bool) -> Dictionary:
	var def = RpgDefs.STATUS.get(id)
	if def == null or not u.get("alive", false):
		return {"on": false, "cancel": ""}
	var opp = str(def.opposite)
	if opp != "" and has_status(u, opp):
		for i in range(u.statuses.size()):
			if str(u.statuses[i].id) == opp:
				u.statuses.remove_at(i)
				break
		return {"on": false, "cancel": opp}
	var cap = maxi(1, int(def.stacks))
	var st = status_of(u, id)
	if st == null:
		st = {"id": id, "turns": maxi(0, turns), "stacks": clampi(stacks, 1, cap), "amount": amount, "by": by}
		u.statuses.append(st)
	else:
		# the same status again: the longer time counts, and one that lasts (0) keeps lasting
		if turns <= 0 or _i(st, "turns") <= 0:
			st["turns"] = 0
		else:
			st["turns"] = maxi(turns, _i(st, "turns"))
		if cap > 1 and id != "marked":
			st["stacks"] = mini(cap, _i(st, "stacks", 1) + maxi(1, stacks))
		else:
			st["stacks"] = clampi(maxi(_i(st, "stacks", 1), stacks), 1, cap)
		st["amount"] = maxf(_f(st, "amount"), amount)
	if fresh and _i(st, "turns") > 0:
		st["fresh"] = true      # put on during its own turn: this turn's end does not count
	return {"on": true, "cancel": ""}


## The damage of one Burn tick or one Bleed stack on a foe, before its defence:
## a share of the applier's offence (Burn: the hero's Mind offence).
static func _dot_amount(B: Dictionary, id: String, ctx: Dictionary) -> float:
	var src = ctx.src
	var share = RpgDefs.BURN_FOE if id == "burn" else RpgDefs.BLEED_FOE
	if str(src.id) == "pet":
		return share * _f(src, "atk")
	var h = B.hero
	if id == "burn":
		return share * RpgDefs.offence(_f(h.s, "mind", 1.0), _f(h.w, "mind"), _i(h, "lvl", 1))
	var off = float(ctx.get("off", 0.0))
	return share * (off if off > 0.0 else offence_of(h, strike_row()))


## The effect {"k": "status"} on one unit: does it land (chance, tec against
## res, immunities, a bounce), for how long (passives), and the events.
static func _add_status(B: Dictionary, ev: Array, u: Dictionary, e: Dictionary, ctx: Dictionary) -> bool:
	var id = str(e.get("id", ""))
	var def = RpgDefs.STATUS.get(id)
	if def == null or not u.get("alive", false) or id == "shield":
		return false
	var src = ctx.src
	var hostile = str(src.side) != str(u.side)
	var debuff = str(def.kind) == "debuff"
	var agg = src.get("agg", {})
	var uagg = u.get("agg", {})
	var no = {"t": "status", "dst": str(u.id), "id": id, "on": false, "turns": 0, "stacks": 0, "resisted": true}
	if e.has("chance") or (id == "stun" and hostile):
		var p = float(e.get("chance", 1.0))
		if hostile:
			p = RpgDefs.status_chance(p + _f(agg, "status_chance"), _f(src, "tec"), _f(u, "res"))
		if _rand(B) >= p:
			ev.append(no)
			return false
	if id == "stun":
		if has_status(u, "steady") or _i(u, "stun_guard") > 0:
			ev.append(no)
			return false
		if bool(u.get("boss", false)):
			# a boss is not stunned: it is pushed back, and cannot be again for a while
			u["at"] = _f(u, "at") + RpgDefs.BOSS_STUN_DELAY * RpgDefs.delay(1.0, speed_of(u))
			u["stun_guard"] = RpgDefs.STUN_IMMUNE
			ev.append({"t": "delay", "dst": str(u.id), "stun": true})
			return true
	if debuff and hostile and _f(uagg, "bounce") > 0.0 and not bool(u.flags.get("bounced", false)):
		u.flags["bounced"] = true
		no["bounced"] = true
		ev.append(no)
		return false
	var turns = int(e.get("turns", 0))
	if id == "stun":
		turns = 0               # it lasts until the action it takes
	elif turns > 0:
		if debuff:
			if hostile:
				turns += int(round(_f(agg, "status_turns:debuff")))
			turns += int(round(_f(uagg, "status_turns:self_debuff")))
		elif not hostile:
			turns += int(round(_f(agg, "status_turns:buff")))
		turns = maxi(1, turns)
	var stacks = int(e.get("stacks", RpgDefs.MARKED_STACKS if id == "marked" else 1))
	var amount = float(e.get("amount", 0.0))
	if id == "counter" and amount <= 0.0:
		amount = 1.0            # a Counter with no power given strikes back with power 1
	if str(u.side) == "foe" and (id == "burn" or id == "bleed"):
		amount = _dot_amount(B, id, ctx)
	var res = _put_status(u, id, turns, stacks, amount, str(src.id), str(B.acting) == str(u.id))
	if str(res.cancel) != "":
		ev.append({"t": "status", "dst": str(u.id), "id": str(res.cancel), "on": false, "turns": 0, "stacks": 0, "resisted": false})
		ev.append({"t": "status", "dst": str(u.id), "id": id, "on": false, "turns": 0, "stacks": 0, "resisted": false, "cancel": str(res.cancel)})
		return false
	var st = status_of(u, id)
	ev.append({"t": "status", "dst": str(u.id), "id": id, "on": true, "turns": _i(st, "turns"), "stacks": _i(st, "stacks", 1), "resisted": false})
	if id == "stun" and str(u.side) == "foe":
		# a stun cancels whatever the foe was about to do (a wind-up, a countdown)
		u["intent"] = _lost_intent("Stunned")
		ev.append({"t": "intent", "who": str(u.id), "intent": u.intent.duplicate(true)})
	return true


## A Shield of `amount` on a unit (the larger of the old and the new is kept).
static func _give_shield(B: Dictionary, ev: Array, u: Dictionary, amount: int, by: String) -> void:
	if amount <= 0 or not u.get("alive", false):
		return
	_put_status(u, "shield", 0, 1, float(amount), by, false)
	var st = status_of(u, "shield")
	st["amount"] = int(round(_f(st, "amount")))
	ev.append({"t": "status", "dst": str(u.id), "id": "shield", "on": true, "turns": 0, "stacks": 1, "resisted": false, "amount": int(st.amount)})


# =============================================================================
# Effects (the `k` kinds)
# =============================================================================

## The units an effect lands on. `fallback` is where it goes when it has no "to".
static func _fx_units(B: Dictionary, e: Dictionary, ctx: Dictionary, fallback: String) -> Array:
	var src = ctx.src
	var ours = str(src.side) == "hero"       # the hero or the companion acts
	match str(e.get("to", fallback)):
		"self":
			return [B.hero] if ours else [src]      # a companion's "self" is the hero
		"target":
			var out = []
			for u in ctx.get("targets", []):
				if u != null and u.get("alive", false):
					out.append(u)
			return out
		"all_foes":
			return foes(B) if ours else [B.hero]
		"allies":
			return [B.hero] if ours else foes(B)
		"ally":
			if ours:
				return [B.hero]
			var hurt = _most_hurt(B)
			return [hurt] if hurt != null else []
	return []


## The living foe with the smallest share of its HP (the first on a tie).
static func _most_hurt(B: Dictionary) -> Variant:
	var best = null
	var low = 2.0
	for f in B.foes:
		if f.alive and _share(f) < low:
			low = _share(f)
			best = f
	return best


## One effect. `ctx` = {"src": the acting unit, "targets": the units its action
## touched, "status_to" / "help_to": where a status / a heal goes when it does
## not say, "off": the action's offence (a Bleed's size), "dealt": the damage
## the action did, "killed": it killed, "move_id"}.
static func _apply_fx(B: Dictionary, ev: Array, e: Dictionary, ctx: Dictionary) -> void:
	var src = ctx.src
	var user = B.hero if str(src.side) == "hero" else src     # who pays and who is healed by "self" effects
	if not user.get("alive", false):
		return
	match str(e.get("k", "")):
		"status":
			for u in _fx_units(B, e, ctx, str(ctx.get("status_to", "target"))):
				_add_status(B, ev, u, e, ctx)
		"heal":
			for u in _fx_units(B, e, ctx, str(ctx.get("help_to", "self"))):
				_heal(B, ev, u, int(round(float(e.get("pct", 0.0)) * float(u.hp_max) * _heal_mult(B, src))))
		"shield":
			for u in _fx_units(B, e, ctx, str(ctx.get("help_to", "self"))):
				_give_shield(B, ev, u, int(round(float(e.get("pct", 0.0)) * float(u.hp_max) * _heal_mult(B, src))), str(src.id))
		"energy":
			_energy(B, ev, int(e.get("n", 0)))
		"gauge":
			_gauge(B, ev, float(e.get("n", 0.0)), true)
		"delay":
			for u in _fx_units(B, e, ctx, "target"):
				var share = float(e.get("pct", 0.0)) * (0.5 if bool(u.get("boss", false)) else 1.0)
				u["at"] = _f(u, "at") + share * RpgDefs.delay(1.0, speed_of(u))
				ev.append({"t": "delay", "dst": str(u.id)})
		"cleanse":
			for u in _fx_units(B, e, ctx, str(ctx.get("help_to", "self"))):
				var stunned = has_status(u, "stun")
				if e.get("ids") is Array:
					for id in e.ids:
						_drop_status(B, ev, u, str(id))
				else:
					_strip(B, ev, u, "debuff", int(e.get("n", 0)))
				if stunned and not has_status(u, "stun") and str(u.side) == "foe" and not bool(u.get("broken", false)) and str(B.acting) != str(u.id):
					_set_intent(B, ev, u)       # it will act after all: its intent must say what (4.5)
		"dispel":
			for u in _fx_units(B, e, ctx, "target"):
				_strip(B, ev, u, "buff", int(e.get("n", 0)))
		"interrupt":
			for u in _fx_units(B, e, ctx, "target"):
				var it = u.get("intent", {})
				if str(u.side) == "foe" and (bool(it.get("windup", false)) or bool(it.get("charged", false)) or _i(it, "count") > 0):
					ev.append({"t": "interrupt", "dst": str(u.id)})
					_set_intent(B, ev, u)
		"cd_cut":
			var h = B.hero
			for id in h.cds.keys():
				if str(id) == str(ctx.get("move_id", "")):
					continue
				var left = _i(h.cds, id) - int(e.get("n", 1))
				if left <= 0:
					h.cds.erase(id)
				else:
					h.cds[id] = left
		"hp_cost":
			var pay = mini(int(floor(float(e.get("pct", 0.0)) * float(user.hp))), int(user.hp) - 1)     # never the last HP
			if pay > 0:
				user["hp"] = int(user.hp) - pay
				ev.append({"t": "tick", "dst": str(user.id), "id": "hp_cost", "amount": pay, "hp": int(user.hp)})
		"lifesteal":
			_heal(B, ev, user, int(round(float(e.get("pct", 0.0)) * float(ctx.get("dealt", 0)))))
		"refund":
			if bool(ctx.get("killed", false)):
				_energy(B, ev, int(e.get("n", 0)))
		"extra_turn":
			B.hero.flags["extra"] = true
		"chip":
			for u in _fx_units(B, e, ctx, "target"):
				if str(u.side) != "foe":
					continue
				var took = _chip(u, int(e.get("n", 1)))
				if took > 0:
					ev.append({"t": "chip", "dst": str(u.id), "chip": took, "guard": _i(u, "guard")})
					if _i(u, "guard") <= 0:
						_break(B, ev, u)
		"when":
			if _share(user) < float(e.get("hp_below", 0.0)) and e.get("do") is Dictionary:
				_apply_fx(B, ev, e.do, ctx)
		"self_ko":
			if str(src.side) == "foe" and src.alive:
				_ko(B, ev, src)
		"flee":
			# the foe leaves the fight: gone, but not felled (no kill is counted, nothing is paid for it)
			if str(src.side) == "foe" and src.alive:
				src["alive"] = false
				src["fled"] = true
				src["statuses"] = []
				src["broken"] = false
				src["intent"] = {}
				ev.append({"t": "flee", "dst": str(src.id)})


## Removes up to `n` statuses of a kind from a unit, oldest first (0 = all).
static func _strip(B: Dictionary, ev: Array, u: Dictionary, kind: String, n: int) -> void:
	var gone = 0
	for st in u.statuses.duplicate():
		if n > 0 and gone >= n:
			break
		if str(RpgDefs.STATUS.get(str(st.id), {}).get("kind", "")) == kind:
			_drop_status(B, ev, u, str(st.id))
			gone += 1


# =============================================================================
# Passives that wait for something (the `p` kinds "on", "low_hp")
# =============================================================================

static func _passive_ctx(u: Dictionary, other) -> Dictionary:
	return {"src": u, "targets": [other] if other != null else [], "status_to": "self", "help_to": "self",
		"off": 0.0, "dealt": 0, "killed": false, "move_id": ""}


## The unit's "on" passives for one happening. `other` = the other unit of it.
static func _fire(B: Dictionary, ev: Array, u: Dictionary, what: String, other) -> void:
	if _f(u.get("agg", {}), "has_on") <= 0.0 or not u.get("alive", false):
		return
	var fx = u.fx
	for i in range(fx.size()):
		var e = fx[i]
		if str(e.get("p", "")) != "on" or str(e.get("ev", "")) != what:
			continue
		var key = "o" + str(i)
		var once = bool(e.get("once", false))
		if once and u.flags.once.has(key):
			continue
		var every = int(e.get("every", 1))
		if every > 1:
			var c = _i(u.flags.cnt, key) + 1
			u.flags.cnt[key] = c
			if c % every != 0:
				continue
		if once:
			u.flags.once[key] = true
		if e.get("do") is Dictionary:
			_apply_fx(B, ev, e.do, _passive_ctx(u, other))


## "low_hp" passives: once a battle, when the HP share falls under the mark.
static func _check_low(B: Dictionary, ev: Array, u: Dictionary) -> void:
	if _f(u.get("agg", {}), "has_low_hp") <= 0.0 or not u.get("alive", false):
		return
	var fx = u.fx
	for i in range(fx.size()):
		var e = fx[i]
		if str(e.get("p", "")) != "low_hp" or u.flags.once.has("l" + str(i)):
			continue
		if _share(u) < float(e.get("below", 0.0)) and e.get("do") is Dictionary:
			u.flags.once["l" + str(i)] = true
			_apply_fx(B, ev, e.do, _passive_ctx(u, null))


## What a unit starts every wave with: its start_status and start_shield
## passives, then its "wave" passives.
static func _wave_passives(B: Dictionary, ev: Array, u: Dictionary) -> void:
	var agg = u.get("agg", {})
	if _f(agg, "has_start_status") > 0.0 or _f(agg, "has_start_shield") > 0.0:
		for e in u.fx:
			var p = str(e.get("p", ""))
			if p == "start_status":
				var id = str(e.get("id", ""))
				# a wave that stands up in the middle of the hero's own turn (its kill): that turn's end does not count
				var res = _put_status(u, id, int(e.get("turns", 0)), int(e.get("stacks", RpgDefs.MARKED_STACKS if id == "marked" else 1)), float(e.get("amount", 0.0)), str(u.id), str(B.acting) == str(u.id))
				if bool(res.on):
					var st = status_of(u, id)
					ev.append({"t": "status", "dst": str(u.id), "id": id, "on": true, "turns": _i(st, "turns"), "stacks": _i(st, "stacks", 1), "resisted": false})
			elif p == "start_shield":
				_give_shield(B, ev, u, int(round(float(e.get("pct", 0.0)) * float(u.hp_max))), str(u.id))
	_fire(B, ev, u, "wave", null)


# =============================================================================
# Foes: entering, turns, intents, phases (4.4, 4.5, 8.3)
# =============================================================================

## A new foe unit takes its place: an id that is never reused, the lowest free
## place of the three, its first `at`, what the rules and the setup start it with.
static func _enter(B: Dictionary, u: Dictionary, start_with: Array) -> void:
	u["id"] = "f" + str(int(B.next_id))
	B["next_id"] = int(B.next_id) + 1
	var taken = []
	for f in B.foes:
		if f.alive:
			taken.append(_i(f, "slot"))
	var slot = 0
	while taken.has(slot):
		slot += 1
	u["slot"] = slot
	u["agg"] = aggregate(u.get("fx", []))
	u["flags"] = {"once": {}, "cnt": {}, "rules": {}}
	if B.rules.has("guard_up"):
		u["guard_max"] = _i(u, "guard_max") + 2
		u["guard"] = u.guard_max
	if B.rules.has("foes_hasted"):
		_put_status(u, "hasted", RULE_TURNS, 1, 0.0, str(u.id), false)
	if B.rules.has("foes_braced"):
		_put_status(u, "braced", RULE_TURNS, 1, 0.0, str(u.id), false)
	for st in start_with:
		if st is Dictionary:
			var id = str(st.get("id", ""))
			if id == "shield":
				_put_status(u, "shield", 0, 1, float(int(round(float(st.get("amount", 0.0))))), str(u.id), false)
			else:
				_put_status(u, id, int(st.get("turns", 0)), int(st.get("stacks", RpgDefs.MARKED_STACKS if id == "marked" else 1)), float(st.get("amount", 0.0)), str(u.id), false)
	u["at"] = _first_at(B, u)
	_norm(u)
	B.foes.append(u)


## Copies of units for an event (a screen must not hold B's own).
static func _snap(list: Array) -> Array:
	var out = []
	for u in list:
		out.append(u.duplicate(true))
	return out


## The wave `idx` stands up. A wave of regular foes shares hp and attack (the
## pack rule); next to an elite or a boss the others are adds.
static func _start_wave(B: Dictionary, ev: Array, idx: int) -> void:
	B["wave"] = idx
	B["foes"] = []
	var entries = B.waves[idx] if idx < B.waves.size() else []
	var rows = []
	var big = false
	var regular = 0
	for en in entries:
		var row = null
		if en is Dictionary:
			row = en.get("row") if en.get("row") is Dictionary else foe_row(B, str(en.get("foe", "")))
		rows.append(row)
		if row != null:
			if bool(row.get("boss", false)) or bool(row.get("elite", false)):
				big = true
			else:
				regular += 1
	var fresh = []
	for i in range(entries.size()):
		var row = rows[i]
		if row == null or fresh.size() >= RpgDefs.FOES_MAX:
			continue
		var en = entries[i]
		var opts = {}
		if en.get("weak") is Array:
			opts["weak"] = en.weak
		if en.get("resist") is Array:
			opts["resist"] = en.resist
		if en.has("guard_add"):
			opts["guard_add"] = int(en.guard_add)
		if en.has("mult"):
			opts["mult"] = float(en.mult)
		elif big and not (bool(row.get("boss", false)) or bool(row.get("elite", false))):
			opts["mult"] = RpgDefs.ADD_MULT
		var u = RpgFoes.make_from(row, float(en.get("n", 0)), regular, opts)
		_enter(B, u, en.get("start") if en.get("start") is Array else [])
		fresh.append(u)
	ev.append({"t": "wave", "n": idx + 1, "of": B.waves.size(), "units": _snap(fresh)})
	_wave_passives(B, ev, B.hero)
	for u in fresh:
		_wave_passives(B, ev, u)
		_set_intent(B, ev, u)


## Between two waves (4.8): statuses are cleared, the hero heals a little; HP,
## energy, gauge and cooldowns carry over.
static func _next_wave(B: Dictionary, ev: Array) -> void:
	var h = B.hero
	h["statuses"] = []
	h["guarding"] = false
	h["stun_guard"] = 0
	B.sum["waves"] = int(B.wave) + 1
	var heal = int(round(RpgDefs.wave_heal(_f(h.s, "flow", 1.0)) * float(h.hp_max)))
	_start_wave(B, ev, int(B.wave) + 1)
	_heal(B, ev, h, heal)


## A summoned foe: an add at the summoner's difficulty, if a place is free.
static func _summon(B: Dictionary, ev: Array, by: Dictionary, foe_id: String) -> void:
	if foes(B).size() >= RpgDefs.FOES_MAX:
		return
	var row = foe_row(B, foe_id)
	if row == null:
		return
	var u = RpgFoes.make_from(row, _f(by, "n"), 1, {"mult": RpgDefs.ADD_MULT})
	_enter(B, u, [])
	ev.append({"t": "summon", "units": _snap([u]), "by": str(by.id)})
	_wave_passives(B, ev, u)
	_set_intent(B, ev, u)


## The intent of a foe that will lose its action.
static func _lost_intent(why: String) -> Dictionary:
	return {"move": "", "name": why, "kind": "stunned", "dmg": 0, "hits": 0, "windup": false, "charged": false, "count": 0,
		"icon": "in_stunned", "text": why, "target": ""}


## The damage a foe's move will do to the hero as things stand: the middle of
## the roll, every hit, no crit, before a Shield or a dodge. `ahead` = in how
## many of the foe's turns the hit comes (1 = its next turn; a wind-up still to
## charge 2; a countdown its count).
static func _intent_dmg(B: Dictionary, f: Dictionary, mv: Dictionary, ahead: int = 1) -> int:
	var power = float(mv.get("power", 0.0))
	if power <= 0.0 or str(mv.get("target", "hero")) != "hero":
		return 0
	var hits = maxi(1, int(mv.get("hits", 1)))
	var base = power / float(hits) * _f(f, "atk") * RpgDefs.mitigation(_f(B.hero, "def")) * _foe_mult(B, f, maxi(1, ahead))
	return hits * maxi(1, int(floor(base + 0.5)))


## The intent a foe shows for a move (4.5): {"move", "name", "kind", "dmg",
## "hits", "windup" (it will spend its next turn charging), "charged" (it has:
## the hit comes next), "count" (a bomb's turns to go), "icon", "text", "target"}.
static func intent_for(B: Dictionary, f: Dictionary, move_id: String) -> Dictionary:
	var mv = foe_move(B, move_id)
	if mv == null:
		mv = BASIC
	var windup = int(mv.get("windup", 0)) > 0
	var power = float(mv.get("power", 0.0))
	var count = maxi(0, int(mv.get("count", 0)))
	return {"move": str(mv.id), "name": str(mv.get("name", "")), "kind": str(mv.get("kind", "attack")),
		"dmg": _intent_dmg(B, f, mv, 2 if windup else maxi(1, count)), "hits": maxi(1, int(mv.get("hits", 1))) if power > 0.0 else 0,
		"windup": windup, "charged": false, "count": maxi(0, int(mv.get("count", 0))),
		"icon": "in_charge" if windup else str(mv.get("icon", "in_attack")), "text": str(mv.get("text", "")),
		"target": str(mv.get("target", "hero"))}


## The foe's next move is chosen (RpgAi.choose: its rules, then its pattern)
## and shown. A foe that will lose its action shows that instead.
static func _set_intent(B: Dictionary, ev: Array, f: Dictionary) -> void:
	if not f.alive:
		return
	if bool(f.get("broken", false)) or has_status(f, "stun"):
		f["intent"] = _lost_intent("Broken" if bool(f.get("broken", false)) else "Stunned")
	else:
		var pick = RpgAi.choose(B, f)
		f["pi"] = int(pick.pi)
		if int(pick.rule) >= 0:
			f.flags.rules["r" + str(int(pick.rule))] = true
		f["intent"] = intent_for(B, f, str(pick.move))
	ev.append({"t": "intent", "who": str(f.id), "intent": f.intent.duplicate(true)})


## The numbers of the shown intents, as things stand now (the hero guards, is
## Braced, the foe is Weakened...): an intent never lies.
static func _refresh_intents(B: Dictionary, ev: Array) -> void:
	for f in B.foes:
		if not f.alive:
			continue
		var it = f.get("intent", {})
		var id = str(it.get("move", ""))
		if id == "":
			continue
		var mv = foe_move(B, id)
		if mv == null:
			continue
		var dmg = _intent_dmg(B, f, mv, 2 if bool(it.get("windup", false)) else maxi(1, _i(it, "count")))
		if dmg != _i(it, "dmg"):
			it["dmg"] = dmg
			ev.append({"t": "intent", "who": str(f.id), "intent": it.duplicate(true)})


## One foe turn. A Broken or Stunned foe loses it (the turn still runs: Regen,
## Burn, durations); a wind-up or a countdown uses it up; else its intent happens.
static func _foe_turn(B: Dictionary, ev: Array, f: Dictionary) -> void:
	f["turns"] = _i(f, "turns") + 1
	ev.append({"t": "turn", "who": str(f.id), "n": int(f.turns)})
	_turn_start(B, ev, f)
	var broken = bool(f.get("broken", false))
	var stunned = has_status(f, "stun")
	var rank = 1.0
	var choose = true
	if broken or stunned:
		if stunned:
			_drop_status(B, ev, f, "stun")
		ev.append({"t": "act", "who": str(f.id), "kind": "lost", "id": "", "name": "Broken" if broken else "Stunned", "school": "", "target": ""})
	else:
		var res = _foe_act(B, ev, f)
		rank = float(res.rank)
		choose = bool(res.done)
	var spd = speed_of(f)       # the speed it had in this turn sets the wait (see _hero_turn_end)
	if f.alive:
		_turn_end(B, ev, f)
	if not f.alive:
		return
	if broken or stunned:
		if broken:
			# the lost action has passed: the pips are back, and safe until it has acted once
			f["broken"] = false
			f["guard"] = _i(f, "guard_max")
			f.flags["armored"] = true
			ev.append({"t": "recover", "dst": str(f.id), "guard": int(f.guard)})
		if stunned:
			f["stun_guard"] = RpgDefs.STUN_IMMUNE
	else:
		f.flags.erase("armored")
		var agg = f.get("agg", {})
		if _f(agg, "quicken") > 0.0:
			f.flags["quick"] = minf(_f(agg, "quicken_max"), _f(f.flags, "quick") + _f(agg, "quicken"))
	if choose:
		_set_intent(B, ev, f)
	f["at"] = _f(f, "at") + RpgDefs.delay(rank, spd)


## What the foe's intent says happens now: {"rank", "done" (false: it charged
## or counted down, the same intent stays)}.
static func _foe_act(B: Dictionary, ev: Array, f: Dictionary) -> Dictionary:
	var it = f.get("intent", {})
	var mv = foe_move(B, str(it.get("move", "")))
	if mv == null:
		mv = BASIC
	var id = str(mv.id)
	var mname = str(mv.get("name", ""))
	if bool(it.get("windup", false)):
		# the turn of charging: the hit comes on its next turn, unless it is interrupted, stunned or broken
		it["windup"] = false
		it["charged"] = true
		it["icon"] = str(mv.get("icon", "in_heavy"))
		ev.append({"t": "act", "who": str(f.id), "kind": "charge", "id": id, "name": mname, "school": "", "target": "hero"})
		ev.append({"t": "intent", "who": str(f.id), "intent": it.duplicate(true)})
		return {"rank": 1.0, "done": false}
	if _i(it, "count") > 1:
		it["count"] = _i(it, "count") - 1
		ev.append({"t": "act", "who": str(f.id), "kind": "count", "id": id, "name": mname, "school": "", "target": "hero"})
		ev.append({"t": "intent", "who": str(f.id), "intent": it.duplicate(true)})
		return {"rank": 1.0, "done": false}

	var aim = str(mv.get("target", "hero"))
	var touched = []
	match aim:
		"self":
			touched = [f]
		"allies":
			touched = foes(B)
		"ally":
			var hurt = _most_hurt(B)
			touched = [hurt] if hurt != null else [f]
		_:
			touched = [B.hero]
	ev.append({"t": "act", "who": str(f.id), "kind": str(mv.get("kind", "attack")), "id": id, "name": mname, "school": "",
		"target": str(touched[0].id) if not touched.is_empty() else ""})
	var run = {"hit": false, "dealt": 0}
	var power = float(mv.get("power", 0.0))
	if power > 0.0 and aim == "hero":
		var hits = maxi(1, int(mv.get("hits", 1)))
		for i in range(hits):
			if int(B.hero.hp) <= 0:
				break
			_foe_hit(B, ev, f, power / float(hits), run)
		if not bool(run.hit):
			touched = []            # nothing landed: what rides on the hit does not either
		# A PERFECT GUARD: the hero's Guard took a blow this foe had charged (or its bomb going off). The foe is
		# thrown off: a pip of its guard goes, which can break it, and the gauge fills a little.
		var told = bool(it.get("charged", false)) or int(mv.get("count", 0)) > 0
		if told and bool(run.hit) and bool(B.hero.get("guarding", false)) and f.alive and int(B.hero.hp) > 0:
			B.sum["perfect"] = _i(B.sum, "perfect") + 1
			var off = _chip(f, RpgDefs.PERFECT_CHIP)
			ev.append({"t": "perfect", "src": str(f.id), "chip": off, "guard": _i(f, "guard")})
			_gauge(B, ev, RpgDefs.GAUGE_PERFECT, false)
			# ... and the hero sees his opening: Focus, so his next hit is a sure crit (the riposte).
			_add_status(B, ev, B.hero, {"id": "focus", "stacks": RpgDefs.PERFECT_FOCUS}, {"src": B.hero, "targets": [B.hero]})
			if off > 0 and _i(f, "guard") <= 0:
				_break(B, ev, f)
		elif told and bool(run.hit) and not bool(B.hero.get("guarding", false)):
			# (a blow that was announced and landed on an open hero: counted, for the tips after a lost fight)
			B.sum["unguarded"] = _i(B.sum, "unguarded") + 1
	var ctx = {"src": f, "targets": touched, "status_to": "target", "help_to": "self" if aim == "hero" else "target",
		"off": 0.0, "dealt": int(run.dealt), "killed": false, "move_id": id}
	for e in mv.get("fx", []):
		if not f.alive:
			break
		_apply_fx(B, ev, e, ctx)
	for fid in mv.get("foes", []):
		_summon(B, ev, f, str(fid))
	# the hero strikes back
	var h = B.hero
	if bool(run.hit) and f.alive and int(h.hp) > 0 and has_status(h, "counter"):
		var base = _f(status_of(h, "counter"), "amount", 1.0) * offence_of(h, strike_row()) * RpgDefs.mitigation(_f(f, "def")) * _status_mult(h, f)
		if bool(f.get("broken", false)):
			base *= RpgDefs.BROKEN_MULT
		_hurt(B, ev, f, _roll(B, base), {"src": "hero", "school": "plain", "counter": true})
		if int(f.hp) <= 0:
			_ko(B, ev, f)
	return {"rank": float(mv.get("rank", 1.0)), "done": true}


## Boss phases: entered, in order, once the HP share is at or under a phase's
## mark. A phase may bring a new pattern, new weaknesses (kept under their own
## key), effects on the boss and adds. The guard is whole again.
static func _check_phases(B: Dictionary, ev: Array) -> void:
	for f in B.foes.duplicate():
		if not f.alive:
			continue
		var phases = f.get("phases", [])
		while f.alive and _i(f, "phase") < phases.size() and _share(f) <= float(phases[_i(f, "phase")].get("at", 0.0)):
			var ph = phases[_i(f, "phase")]
			f["phase"] = _i(f, "phase") + 1
			ev.append({"t": "phase", "who": str(f.id), "say": str(ph.get("say", "")), "phase": int(f.phase) + 1})
			if ph.get("pattern") is Array and not ph.pattern.is_empty():
				f["pattern"] = ph.pattern.duplicate()
				f["pi"] = 0
			if not bool(f.get("shown", false)):
				if ph.get("weak") is Array and not ph.weak.is_empty():
					f["weak"] = ph.weak.duplicate()
				if ph.get("resist") is Array:
					f["resist"] = ph.resist.duplicate()
			if not bool(f.get("broken", false)):
				f["guard"] = _i(f, "guard_max")
			var ctx = {"src": f, "targets": [f], "status_to": "self", "help_to": "self", "off": 0.0, "dealt": 0, "killed": false, "move_id": ""}
			for e in ph.get("fx", []):
				_apply_fx(B, ev, e, ctx)
			for fid in ph.get("summon", []):
				_summon(B, ev, f, str(fid))
			_set_intent(B, ev, f)


# =============================================================================
# The companion (4.7)
# =============================================================================

## The companion's turn: its own action (every Nth turn if its kit says so),
## and one charge towards its command.
static func _pet_turn(B: Dictionary, ev: Array) -> void:
	var p = B.pet
	p["turns"] = _i(p, "turns") + 1
	ev.append({"t": "turn", "who": "pet", "n": int(p.turns)})
	var kit = pet_kit(B, str(p.get("pet", "")))
	if kit != null:
		var auto = kit.get("auto", {})
		if int(p.turns) % maxi(1, int(auto.get("every", 1))) == 0:
			_pet_do(B, ev, auto, "auto", str(B.target))
	if _i(p, "charge") < _i(p, "charge_max", 3):
		p["charge"] = _i(p, "charge") + 1
		ev.append({"t": "charge", "v": int(p.charge)})
	p["at"] = _f(p, "at") + RpgDefs.delay(1.0, speed_of(p))        # a companion carries no statuses: its speed is its speed


## The companion's own action or its command. Its hits are never weak or
## resisted, never crit and never chip (an effect may).
static func _pet_do(B: Dictionary, ev: Array, part: Dictionary, how: String, target_id: String) -> void:
	var p = B.pet
	var power = float(part.get("power", 0.0))
	var aim = str(part.get("target", "foe"))
	var tgt = _target(B, target_id)
	ev.append({"t": "act", "who": "pet", "kind": how, "id": str(p.get("pet", "")), "name": str(part.get("name", "")),
		"school": str(part.get("school", "")), "target": str(tgt.id) if tgt != null else ""})
	var touched = []
	var dealt = 0
	var kills = 0
	if power > 0.0:
		var list = foes(B) if aim == "all" else ([tgt] if tgt != null else [])
		for f in list:
			if _slips(B, ev, f):
				ev.append({"t": "miss", "src": "pet", "dst": str(f.id)})
				continue
			var mult = _taken_mult(f) * (RpgDefs.BROKEN_MULT if bool(f.get("broken", false)) else 1.0)
			var amount = _roll(B, power * _f(p, "atk") * RpgDefs.mitigation(_f(f, "def")) * mult)
			dealt += _hurt(B, ev, f, amount, {"src": "pet", "school": str(part.get("school", ""))})
			touched.append(f)
			if int(f.hp) <= 0:
				_ko(B, ev, f)
				kills += 1
	elif tgt != null and aim != "self":
		touched = foes(B) if aim == "all" else [tgt]
	var to_self = aim == "self" or (how == "auto" and str(part.get("kind", "attack")) == "support")
	var ctx = {"src": p, "targets": touched, "status_to": "self" if to_self else "target", "help_to": "self",
		"off": _f(p, "atk"), "dealt": dealt, "killed": kills > 0, "move_id": ""}
	for e in part.get("fx", []):
		_apply_fx(B, ev, e, ctx)


# =============================================================================
# Passive effects, added up
# =============================================================================

static func _sum(a: Dictionary, key: String, v) -> void:
	if v is int or v is float:
		a[key] = float(a.get(key, 0.0)) + float(v)


## The sums of a list of passive effects, by kind (and by what a kind is
## about): "hp_pct", "atk:push", "school_pct:legs", "stat_dmg:chest",
## "vs_status:exposed", "status_turns:debuff", "chip:crit", "cost:push",
## "reward:ore"... {pct, max} kinds give "<kind>" and "<kind>_max"; kinds
## without a number give 1; "has_on", "has_low_hp", "has_survive",
## "has_start_status", "has_start_shield" say whether to look for those.
static func aggregate(fx: Array) -> Dictionary:
	var a = {}
	for e in fx:
		if not (e is Dictionary):
			continue
		var p = str(e.get("p", ""))
		match p:
			"stat_pct", "stat_dmg":
				_sum(a, p + ":" + str(e.get("stat", "")), e.get("pct"))
			"school_pct":
				_sum(a, p + ":" + str(e.get("school", "")), e.get("pct"))
			"hp_pct", "def_pct", "spd_pct", "heal_pct", "gauge_rate", "lifesteal", "vs_broken", "first_hit", "combo_alt":
				_sum(a, p, e.get("pct"))
			"crit_add", "dodge_add", "res_add", "armor", "hp", "guard_pct":
				_sum(a, p, e.get("v"))
			"atk":
				_sum(a, p + ":" + str(e.get("school", "")), e.get("v"))
			"en_max", "en_start", "gauge_start", "guard_en":
				_sum(a, p, e.get("n"))
			"cost", "cd", "next_cost":
				_sum(a, p + ":" + str(e.get("school", "")), e.get("add"))
			"chip", "status_turns":
				_sum(a, p + ":" + str(e.get("on", "")), e.get("add"))
			"status_chance":
				_sum(a, p, e.get("add"))
			"vs_status":
				_sum(a, p + ":" + str(e.get("id", "")), e.get("pct"))
			"combo_same", "ramp", "quicken":
				_sum(a, p, e.get("pct"))
				_sum(a, p + "_max", e.get("max"))
			"reward":
				_sum(a, p + ":" + str(e.get("what", "")), e.get("pct"))
			"first_turn", "bounce", "adapt":
				a[p] = 1.0
			"on", "low_hp", "survive", "start_status", "start_shield":
				a["has_" + p] = 1.0
	return a


# =============================================================================
# The validators: the last word on the vocabulary
# =============================================================================

## The keys each kind may carry (beside "k" / "m" / "p"). `need` = must be there.
const FX_KEYS = {
	"status": {"need": ["id"], "may": ["turns", "chance", "stacks", "amount", "to"]},
	"heal": {"need": ["pct"], "may": ["to"]},
	"shield": {"need": ["pct"], "may": ["to"]},
	"energy": {"need": ["n"], "may": []},
	"gauge": {"need": ["n"], "may": []},
	"delay": {"need": ["pct"], "may": ["to"]},
	"cleanse": {"need": [], "may": ["n", "ids", "to"]},
	"dispel": {"need": ["n"], "may": ["to"]},
	"interrupt": {"need": [], "may": ["to"]},
	"cd_cut": {"need": ["n"], "may": []},
	"hp_cost": {"need": ["pct"], "may": []},
	"lifesteal": {"need": ["pct"], "may": []},
	"refund": {"need": ["n"], "may": []},
	"extra_turn": {"need": [], "may": []},
	"chip": {"need": ["n"], "may": ["to"]},
	"when": {"need": ["hp_below", "do"], "may": []},
	"self_ko": {"need": [], "may": []},
	"flee": {"need": [], "may": []},
}
const MOD_KEYS = {
	"vs_status": ["id", "pct"], "vs_debuff": ["pct"], "per_debuff": ["pct", "max"], "vs_broken": ["pct"], "vs_full_hp": ["pct"],
	"execute": ["below", "pct"], "ignore_def": ["pct"], "crit": ["add"], "sure_crit": [], "ramp_use": ["pct", "max"],
	"ramp_turn": ["pct", "max"], "streak": ["pct", "max"], "smart": [], "missing_hp": ["pct"],
}
const PASSIVE_KEYS = {
	"stat_pct": {"need": ["stat", "pct"], "may": []}, "stat_dmg": {"need": ["stat", "pct"], "may": []},
	"school_pct": {"need": ["school", "pct"], "may": []},
	"hp_pct": {"need": ["pct"], "may": []}, "def_pct": {"need": ["pct"], "may": []}, "spd_pct": {"need": ["pct"], "may": []},
	"heal_pct": {"need": ["pct"], "may": []}, "gauge_rate": {"need": ["pct"], "may": []},
	"crit_add": {"need": ["v"], "may": []}, "dodge_add": {"need": ["v"], "may": []}, "res_add": {"need": ["v"], "may": []},
	"atk": {"need": ["school", "v"], "may": []}, "armor": {"need": ["v"], "may": []}, "hp": {"need": ["v"], "may": []},
	"en_max": {"need": ["n"], "may": []}, "en_start": {"need": ["n"], "may": []}, "gauge_start": {"need": ["n"], "may": []},
	"guard_pct": {"need": ["v"], "may": []}, "guard_en": {"need": ["n"], "may": []},
	"lifesteal": {"need": ["pct"], "may": []},
	"start_status": {"need": ["id"], "may": ["turns", "stacks", "amount"]}, "start_shield": {"need": ["pct"], "may": []},
	"on": {"need": ["ev", "do"], "may": ["every", "once"]}, "low_hp": {"need": ["below", "do"], "may": []},
	"survive": {"need": ["pct"], "may": []},
	"cost": {"need": ["school", "add"], "may": []}, "cd": {"need": ["school", "add"], "may": []},
	"next_cost": {"need": ["school", "add"], "may": []},
	"chip": {"need": ["on", "add"], "may": []}, "status_turns": {"need": ["on", "add"], "may": []},
	"status_chance": {"need": ["add"], "may": []},
	"vs_broken": {"need": ["pct"], "may": []}, "vs_status": {"need": ["id", "pct"], "may": []},
	"first_hit": {"need": ["pct"], "may": []}, "combo_same": {"need": ["pct", "max"], "may": []},
	"combo_alt": {"need": ["pct"], "may": []}, "ramp": {"need": ["pct", "max"], "may": []},
	"first_turn": {"need": [], "may": []}, "bounce": {"need": [], "may": []},
	"reward": {"need": ["what", "pct"], "may": []},
	"adapt": {"need": [], "may": []}, "quicken": {"need": ["pct", "max"], "may": []},
}
const STATUS_TURNS_ON = ["debuff", "buff", "self_debuff"]
const REWARD_WHAT = ["ore", "xp", "luck"]
const MOVE_KEYS = ["id", "name", "school", "kind", "scale", "power", "hits", "target", "splash", "cost", "cd", "rank", "chip",
	"mods", "fx", "tags", "text", "ult", "tier"]
const MOVE_TARGETS = ["foe", "all", "random", "self"]
const FOE_KEYS = ["id", "name", "region", "role", "weak", "resist", "guard", "moves", "pattern", "rules", "traits", "phases",
	"boss", "elite", "text"]
const FOE_MOVE_KEYS = ["id", "name", "kind", "power", "hits", "windup", "count", "rank", "target", "fx", "foes", "icon", "text"]
const FOE_MOVE_TARGETS = ["hero", "self", "ally", "allies"]
const PHASE_KEYS = ["at", "say", "pattern", "weak", "resist", "summon", "fx"]


static func _is_num(v) -> bool:
	return (v is int or v is float) and is_finite(float(v))


static func _is_int(v) -> bool:
	return v is int or (v is float and is_finite(v) and v == floor(v))


## "" when the dictionary has every key of `need` and nothing outside need + may + [tag].
static func _keys(d: Dictionary, tag: String, need: Array, may: Array) -> String:
	for k in need:
		if not d.has(k):
			return "\"%s\" is missing" % str(k)
	for k in d:
		if str(k) != tag and not need.has(k) and not may.has(k):
			return "\"%s\" is not a key of this kind" % str(k)
	return ""


static func _frac(d: Dictionary, key: String, lo: float, hi: float, lo_open: bool = true) -> String:
	var v = d.get(key)
	if not _is_num(v):
		return "\"%s\" must be a number" % key
	var f = float(v)
	if f > hi or f < lo or (lo_open and f <= lo):
		return "\"%s\" is out of range (%s)" % [key, TTUtil.num_str(f)]
	return ""


## An effect ({"k": ...}): "" when the engine knows what to do with every part of it.
static func check_fx(e, nested: bool = false) -> String:
	if not (e is Dictionary):
		return "an effect must be a dictionary"
	var k = str(e.get("k", ""))
	if not FX_KEYS.has(k):
		return "unknown effect kind \"%s\"" % k
	var why = _keys(e, "k", FX_KEYS[k].need, FX_KEYS[k].may)
	if why != "":
		return "%s: %s" % [k, why]
	if e.has("to") and not FX_TO.has(e.to):
		return "%s: \"to\" must be one of %s" % [k, ", ".join(FX_TO)]
	match k:
		"status":
			var id = str(e.id)
			if not RpgDefs.STATUS.has(id):
				return "status: unknown status \"%s\"" % id
			if id == "shield":
				return "status: a Shield is given by the shield effect"
			if e.has("turns") and (not _is_int(e.turns) or int(e.turns) < 0):
				return "status: \"turns\" must be a whole number, 0 or more"
			if not e.has("turns") and not NO_TURNS.has(id):
				return "status: %s needs \"turns\" (0 = the whole wave)" % id
			if e.has("chance"):
				why = _frac(e, "chance", 0.0, 1.0)
				if why != "":
					return "status: " + why
			if e.has("stacks") and (not _is_int(e.stacks) or int(e.stacks) < 1 or int(e.stacks) > int(RpgDefs.STATUS[id].stacks)):
				return "status: \"stacks\" must be 1 to %d for %s" % [int(RpgDefs.STATUS[id].stacks), id]
			if e.has("amount") and (id != "counter" or not _is_num(e.amount) or float(e.amount) <= 0.0):
				return "status: \"amount\" is the power of a Counter, above 0"
		"heal", "shield", "lifesteal", "delay":
			why = _frac(e, "pct", 0.0, 2.0)
			if why != "":
				return "%s: %s" % [k, why]
		"hp_cost":
			why = _frac(e, "pct", 0.0, 0.95)
			if why != "":
				return "hp_cost: " + why
		"energy":
			if not _is_int(e.n) or int(e.n) == 0:
				return "energy: \"n\" must be a whole number, not 0 (99 = full)"
		"gauge":
			if not _is_num(e.n) or float(e.n) == 0.0 or absf(float(e.n)) > RpgDefs.GAUGE_MAX:
				return "gauge: \"n\" must be a number between -100 and 100, not 0"
		"cleanse":
			if e.has("n") == e.has("ids"):
				return "cleanse: give \"n\" (0 = all) or \"ids\", one of them"
			if e.has("n") and (not _is_int(e.n) or int(e.n) < 0):
				return "cleanse: \"n\" must be a whole number, 0 or more"
			if e.has("ids"):
				if not (e.ids is Array) or e.ids.is_empty():
					return "cleanse: \"ids\" must be a list of status ids"
				for id in e.ids:
					if not RpgDefs.STATUS.has(str(id)):
						return "cleanse: unknown status \"%s\"" % str(id)
		"dispel":
			if not _is_int(e.n) or int(e.n) < 0:
				return "dispel: \"n\" must be a whole number, 0 or more (0 = all)"
		"cd_cut", "refund", "chip":
			if not _is_int(e.n) or int(e.n) < 1:
				return "%s: \"n\" must be a whole number, 1 or more" % k
		"when":
			if nested:
				return "when: cannot sit inside another condition"
			why = _frac(e, "hp_below", 0.0, 1.0)
			if why != "":
				return "when: " + why
			why = check_fx(e.do, true)
			if why != "":
				return "when: " + why
	return ""


## A move's mod ({"m": ...}).
static func check_mod(mod) -> String:
	if not (mod is Dictionary):
		return "a mod must be a dictionary"
	var m = str(mod.get("m", ""))
	if not MOD_KEYS.has(m):
		return "unknown mod kind \"%s\"" % m
	var why = _keys(mod, "m", MOD_KEYS[m], [])
	if why != "":
		return "%s: %s" % [m, why]
	if mod.has("id") and (not RpgDefs.STATUS.has(str(mod.id))):
		return "%s: unknown status \"%s\"" % [m, str(mod.id)]
	for key in ["pct", "max", "add"]:
		if mod.has(key):
			why = _frac(mod, key, 0.0, 1.0 if (m == "ignore_def" or m == "crit") else 5.0)
			if why != "":
				return "%s: %s" % [m, why]
	if mod.has("below"):
		why = _frac(mod, "below", 0.0, 1.0)
		if why != "":
			return "%s: %s" % [m, why]
	if mod.has("max") and float(mod.max) < float(mod.pct):
		return "%s: \"max\" is under one step" % m
	return ""


## A passive effect ({"p": ...}).
static func check_passive(fx) -> String:
	if not (fx is Dictionary):
		return "a passive effect must be a dictionary"
	var p = str(fx.get("p", ""))
	if not PASSIVE_KEYS.has(p):
		return "unknown passive kind \"%s\"" % p
	var why = _keys(fx, "p", PASSIVE_KEYS[p].need, PASSIVE_KEYS[p].may)
	if why != "":
		return "%s: %s" % [p, why]
	for key in ["pct", "v", "max"]:
		if fx.has(key) and not _is_num(fx[key]):
			return "%s: \"%s\" must be a number" % [p, key]
	for key in ["n", "add"]:
		if fx.has(key) and p != "status_chance" and p != "gauge_start" and not _is_int(fx[key]):
			return "%s: \"%s\" must be a whole number" % [p, key]
	match p:
		"stat_pct":
			if not RpgDefs.STATS.has(fx.stat) and fx.stat != "all" and fx.stat != "body":
				return "stat_pct: unknown stat \"%s\"" % str(fx.stat)
		"stat_dmg":
			if not RpgDefs.STATS.has(fx.stat):
				return "stat_dmg: unknown stat \"%s\"" % str(fx.stat)
		"school_pct":
			if not RpgDefs.SCHOOLS.has(fx.school) and fx.school != "all" and fx.school != "plain":
				return "school_pct: unknown school \"%s\"" % str(fx.school)
		"atk", "cost", "cd", "next_cost":
			if not RpgDefs.SCHOOLS.has(fx.school) and fx.school != "all":
				return "%s: unknown school \"%s\"" % [p, str(fx.school)]
			if p != "atk" and int(fx.add) == 0:
				return "%s: \"add\" is 0" % p
		"gauge_start":
			why = _frac(fx, "n", 0.0, RpgDefs.GAUGE_MAX)
			if why != "":
				return "gauge_start: " + why
		"status_chance":
			why = _frac(fx, "add", -1.0, 1.0)
			if why != "":
				return "status_chance: " + why
		"start_status":
			var id = str(fx.id)
			if not RpgDefs.STATUS.has(id) or id == "shield" or id == "stun":
				return "start_status: \"%s\" cannot be started with" % id
			if fx.has("turns") and (not _is_int(fx.turns) or int(fx.turns) < 0):
				return "start_status: \"turns\" must be a whole number, 0 or more (0 = the whole wave)"
			if not fx.has("turns") and not NO_TURNS.has(id):
				return "start_status: %s needs \"turns\" (0 = the whole wave)" % id
			if fx.has("stacks") and (not _is_int(fx.stacks) or int(fx.stacks) < 1 or int(fx.stacks) > int(RpgDefs.STATUS[id].stacks)):
				return "start_status: \"stacks\" is out of range"
		"start_shield":
			why = _frac(fx, "pct", 0.0, 2.0)
			if why != "":
				return "start_shield: " + why
		"on":
			if not ON_EVENTS.has(fx.ev):
				return "on: unknown event \"%s\"" % str(fx.ev)
			if fx.has("every") and (not _is_int(fx.every) or int(fx.every) < 1):
				return "on: \"every\" must be a whole number, 1 or more"
			if fx.has("once") and not (fx.once is bool):
				return "on: \"once\" must be true or false"
			why = check_fx(fx.do)
			if why != "":
				return "on: " + why
		"low_hp":
			why = _frac(fx, "below", 0.0, 1.0)
			if why != "":
				return "low_hp: " + why
			why = check_fx(fx.do)
			if why != "":
				return "low_hp: " + why
		"survive":
			why = _frac(fx, "pct", 0.0, 0.9, false)
			if why != "":
				return "survive: " + why
		"chip":
			if fx.on != "crit" and not RpgDefs.SCHOOLS.has(fx.on):
				return "chip: \"on\" must be \"crit\" or a school"
			if int(fx.add) < 1:
				return "chip: \"add\" must be 1 or more"
		"status_turns":
			if not STATUS_TURNS_ON.has(fx.on):
				return "status_turns: \"on\" must be one of %s" % ", ".join(STATUS_TURNS_ON)
			if int(fx.add) == 0:
				return "status_turns: \"add\" is 0"
		"vs_status":
			if not RpgDefs.STATUS.has(str(fx.id)):
				return "vs_status: unknown status \"%s\"" % str(fx.id)
		"reward":
			if not REWARD_WHAT.has(fx.what):
				return "reward: \"what\" must be one of %s" % ", ".join(REWARD_WHAT)
		"combo_same", "ramp", "quicken":
			if float(fx.pct) <= 0.0 or float(fx.max) < float(fx.pct):
				return "%s: needs a step above 0 and a \"max\" of at least one step" % p
	return ""


## A hero move (a full row, as RpgMoves.all() gives it).
static func check_move(move) -> String:
	if not (move is Dictionary):
		return "a move must be a dictionary"
	var why = _keys(move, "", MOVE_KEYS, [])
	if why != "":
		return why
	var id = str(move.id)
	if not (move.id is String) or id == "" or id != RpgDefs.id_of(id):
		return "\"id\" must be a lower_case id"
	if not (move.name is String) or str(move.name) == "":
		return id + ": no name"
	var school = str(move.school)
	if not RpgDefs.SCHOOLS.has(school) and school != "plain":
		return "%s: unknown school \"%s\"" % [id, school]
	var kind = str(move.kind)
	if kind != "attack" and kind != "support":
		return "%s: \"kind\" must be attack or support" % id
	var attack = kind == "attack"
	if not (move.scale is Dictionary):
		return id + ": \"scale\" must be a dictionary"
	var total = 0.0
	for st in RpgDefs.STATS:
		if move.scale.has(st):
			if not _is_num(move.scale[st]) or float(move.scale[st]) <= 0.0:
				return "%s: the weight of %s must be above 0" % [id, st]
			total += float(move.scale[st])
	for st in move.scale:
		if not RpgDefs.STATS.has(st):
			return "%s: unknown stat \"%s\" in its scale" % [id, str(st)]
	if move.scale.is_empty():
		if attack and school != "plain":
			return id + ": an attack needs a scale"
	elif absf(total - 1.0) > 0.001:
		return id + ": the weights of its scale must sum to 1"
	if not _is_num(move.power) or float(move.power) < 0.0 or float(move.power) > 12.0:
		return id + ": \"power\" is out of range"
	if attack and float(move.power) <= 0.0:
		return id + ": an attack needs power"
	if not attack and float(move.power) != 0.0:
		return id + ": a support move has no power"
	if not _is_int(move.hits) or int(move.hits) < 1 or int(move.hits) > 8:
		return id + ": \"hits\" must be 1 to 8"
	if not MOVE_TARGETS.has(move.target):
		return "%s: \"target\" must be one of %s" % [id, ", ".join(MOVE_TARGETS)]
	if attack and str(move.target) == "self":
		return id + ": an attack cannot aim at the hero"
	if not attack and (str(move.target) == "all" or str(move.target) == "random"):
		return id + ": a support move aims at \"self\" or at one \"foe\""
	if not attack and int(move.hits) != 1:
		return id + ": a support move does not hit"
	if not _is_num(move.splash) or float(move.splash) < 0.0 or float(move.splash) > 1.0:
		return id + ": \"splash\" must be 0 to 1"
	if float(move.splash) > 0.0 and (not attack or str(move.target) != "foe"):
		return id + ": only an attack on one foe splashes"
	if not _is_int(move.cost) or int(move.cost) < 0 or int(move.cost) > 9:
		return id + ": \"cost\" must be 0 to 9"
	if not _is_int(move.cd) or int(move.cd) < 0 or int(move.cd) > 9:
		return id + ": \"cd\" must be 0 to 9"
	if not _is_num(move.rank) or float(move.rank) < 0.3 or float(move.rank) > 2.0:
		return id + ": \"rank\" must be 0.3 to 2"
	if not _is_int(move.chip) or int(move.chip) < 0 or int(move.chip) > 4:
		return id + ": \"chip\" must be 0 to 4"
	if not (move.mods is Array) or not (move.fx is Array) or not (move.tags is Array):
		return id + ": \"mods\", \"fx\" and \"tags\" must be lists"
	if not attack and not move.mods.is_empty():
		return id + ": a support move has no mods"
	for mod in move.mods:
		why = check_mod(mod)
		if why != "":
			return "%s: %s" % [id, why]
	for e in move.fx:
		why = check_fx(e)
		if why != "":
			return "%s: %s" % [id, why]
		var k = str(e.k)
		if not attack and (k == "lifesteal" or k == "refund"):
			return "%s: %s needs an attack" % [id, k]
		if k == "self_ko" or k == "flee":
			return id + ": %s is for foes" % k
		if str(move.target) == "self" and (str(e.get("to", "")) == "target" or (not e.has("to") and ["delay", "dispel", "interrupt", "chip"].has(k))):
			return "%s: %s needs a foe, and the move aims at the hero" % [id, k]
	for tag in move.tags:
		if not (tag is String):
			return id + ": a tag must be a word"
	if not (move.text is String) or not (move.ult is bool) or not _is_int(move.tier):
		return id + ": \"text\", \"ult\" or \"tier\" is of the wrong kind"
	if bool(move.ult) and int(move.cost) != 0:
		return id + ": an ultimate costs no energy (it uses the gauge)"
	return ""


## A foe move (a full row, as RpgFoes.move() gives it).
static func check_foe_move(mv) -> String:
	if not (mv is Dictionary):
		return "a foe move must be a dictionary"
	var why = _keys(mv, "", FOE_MOVE_KEYS, [])
	if why != "":
		return why
	var id = str(mv.id)
	if not (mv.id is String) or id == "":
		return "a foe move needs an id"
	if not (mv.name is String) or str(mv.name) == "":
		return id + ": no name"
	if not FOE_MOVE_KINDS.has(mv.kind):
		return "%s: unknown kind \"%s\"" % [id, str(mv.kind)]
	if not FOE_MOVE_TARGETS.has(mv.target):
		return "%s: \"target\" must be one of %s" % [id, ", ".join(FOE_MOVE_TARGETS)]
	if not _is_num(mv.power) or float(mv.power) < 0.0 or float(mv.power) > 6.0:
		return id + ": \"power\" is out of range"
	if float(mv.power) > 0.0 and str(mv.target) != "hero":
		return id + ": only a move aimed at the hero has power"
	if not _is_int(mv.hits) or int(mv.hits) < 1 or int(mv.hits) > 8:
		return id + ": \"hits\" must be 1 to 8"
	if not _is_int(mv.windup) or int(mv.windup) < 0 or int(mv.windup) > 1:
		return id + ": \"windup\" must be 0 or 1"
	if not _is_int(mv.count) or int(mv.count) < 0 or int(mv.count) > 9:
		return id + ": \"count\" must be 0 to 9"
	if int(mv.count) > 0 and int(mv.windup) > 0:
		return id + ": a countdown does not wind up as well"
	if (str(mv.kind) == "bomb") != (int(mv.count) > 0):
		return id + ": a bomb, and only a bomb, has a \"count\""
	if not _is_num(mv.rank) or float(mv.rank) < 0.3 or float(mv.rank) > 2.0:
		return id + ": \"rank\" must be 0.3 to 2"
	if not (mv.fx is Array) or not (mv.foes is Array):
		return id + ": \"fx\" and \"foes\" must be lists"
	for e in mv.fx:
		why = check_fx(e)
		if why != "":
			return "%s: %s" % [id, why]
		var k = str(e.k)
		if ["cd_cut", "refund", "extra_turn", "interrupt", "chip"].has(k):
			return "%s: %s is for the hero's side" % [id, k]
	if (str(mv.kind) == "summon") != (not mv.foes.is_empty()):
		return id + ": a summon, and only a summon, brings \"foes\""
	for fid in mv.foes:
		if not (fid is String) or str(fid) == "":
			return id + ": a summoned foe needs an id"
	if float(mv.power) <= 0.0 and mv.fx.is_empty() and mv.foes.is_empty():
		return id + ": it does nothing"
	if not (mv.icon is String) or not (mv.text is String):
		return id + ": \"icon\" and \"text\" must be words"
	return ""


static func _schools_ok(list, least: int, most: int) -> bool:
	if not (list is Array) or list.size() < least or list.size() > most:
		return false
	var seen = []
	for sc in list:
		if not RpgDefs.ATTACK_SCHOOLS.has(sc) or seen.has(sc):
			return false
		seen.append(sc)
	return true


## A foe (a full row, as RpgFoes.all() gives it). `moves` = {id: full foe move}
## for moves that are not in RpgFoes (a test, the rival); `foes` = the ids of
## foes that are not in RpgFoes and may be summoned.
static func check_foe(foe, moves: Dictionary = {}, foes_known: Array = []) -> String:
	if not (foe is Dictionary):
		return "a foe must be a dictionary"
	var why = _keys(foe, "", FOE_KEYS, [])
	if why != "":
		return why
	var id = str(foe.id)
	if not (foe.id is String) or id == "":
		return "a foe needs an id"
	if not (foe.name is String) or str(foe.name) == "":
		return id + ": no name"
	if not RpgDefs.ROLES.has(foe.role):
		return "%s: unknown role \"%s\"" % [id, str(foe.role)]
	if not (foe.boss is bool) or not (foe.elite is bool) or (bool(foe.boss) and bool(foe.elite)):
		return id + ": \"boss\" and \"elite\" are true or false, and not both"
	if (str(foe.role) == "boss") != bool(foe.boss) or (str(foe.role) == "elite") != bool(foe.elite):
		return id + ": the role and the boss / elite flag do not agree"
	if not _schools_ok(foe.weak, 2, 2):
		return id + ": \"weak\" must be two different attack schools"
	if not _schools_ok(foe.resist, 0, 1):
		return id + ": \"resist\" must be at most one attack school"
	for sc in foe.resist:
		if foe.weak.has(sc):
			return id + ": it cannot resist a school it is weak to"
	if foe.guard != null and (not _is_int(foe.guard) or int(foe.guard) < 0 or int(foe.guard) > 12):
		return id + ": \"guard\" must be null (the role's) or 0 to 12"
	if not (foe.moves is Array) or foe.moves.is_empty():
		return id + ": it needs moves"
	for mid in foe.moves:
		var mv = moves.get(str(mid)) if moves.has(str(mid)) else RpgFoes.move(str(mid))
		if mv == null:
			return "%s: unknown move \"%s\"" % [id, str(mid)]
		why = check_foe_move(mv)
		if why != "":
			return "%s: %s" % [id, why]
		for fid in mv.foes:
			if RpgFoes.by_id(str(fid)) == null and not foes_known.has(fid) and str(fid) != id:
				return "%s: %s summons an unknown foe \"%s\"" % [id, str(mid), str(fid)]
	if not (foe.pattern is Array) or foe.pattern.is_empty():
		return id + ": it needs a pattern"
	for mid in foe.pattern:
		if not foe.moves.has(mid):
			return "%s: its pattern uses \"%s\", which is not one of its moves" % [id, str(mid)]
	if not (foe.rules is Array) or not (foe.traits is Array) or not (foe.phases is Array):
		return id + ": \"rules\", \"traits\" and \"phases\" must be lists"
	for r in foe.rules:
		if not (r is Dictionary):
			return id + ": a rule must be a dictionary"
		why = _keys(r, "", ["if", "use"], ["v", "once"])
		if why != "":
			return "%s: a rule: %s" % [id, why]
		if not FOE_RULES.has(r["if"]):
			return "%s: unknown rule \"%s\"" % [id, str(r["if"])]
		if not foe.moves.has(r.use):
			return "%s: a rule uses \"%s\", which is not one of its moves" % [id, str(r.use)]
		if r.has("once") and not (r.once is bool):
			return id + ": a rule's \"once\" must be true or false"
		match str(r["if"]):
			"hp_below", "ally_hurt":
				why = _frac(r, "v", 0.0, 1.0)
				if why != "":
					return "%s: rule %s: %s" % [id, str(r["if"]), why]
			"turn_mod":
				var v = r.get("v")
				var okv = _is_int(v) and int(v) >= 1
				if v is Array:
					okv = v.size() == 2 and _is_int(v[0]) and _is_int(v[1]) and int(v[0]) >= 1 and int(v[1]) >= 0 and int(v[1]) < int(v[0])
				if not okv:
					return id + ": rule turn_mod: \"v\" must be N or [N, r]"
			"hero_has", "self_lacks":
				if not RpgDefs.STATUS.has(str(r.get("v", ""))):
					return "%s: rule %s: \"v\" must be a status id" % [id, str(r["if"])]
	for t in foe.traits:
		why = check_passive(t)
		if why != "":
			return "%s: a trait: %s" % [id, why]
	var last = 1.0
	for ph in foe.phases:
		if not (ph is Dictionary):
			return id + ": a phase must be a dictionary"
		why = _keys(ph, "", ["at"], PHASE_KEYS)
		if why != "":
			return "%s: a phase: %s" % [id, why]
		if not _is_num(ph.at) or float(ph.at) <= 0.0 or float(ph.at) >= last:
			return id + ": the phases' \"at\" must go down from under 1 to above 0"
		last = float(ph.at)
		if ph.has("say") and not (ph.say is String):
			return id + ": a phase's \"say\" must be words"
		if ph.has("pattern"):
			if not (ph.pattern is Array):
				return id + ": a phase's \"pattern\" must be a list"
			for mid in ph.pattern:
				if not foe.moves.has(mid):
					return "%s: a phase uses \"%s\", which is not one of its moves" % [id, str(mid)]
		if ph.has("weak") and not _schools_ok(ph.weak, 0, 2):
			return id + ": a phase's \"weak\" must be two attack schools (or none: as before)"
		if ph.has("weak") and ph.weak.size() == 1:
			return id + ": a phase's \"weak\" must be two attack schools (or none: as before)"
		if ph.has("resist") and not _schools_ok(ph.resist, 0, 1):
			return id + ": a phase's \"resist\" must be at most one attack school"
		if ph.has("summon"):
			if not (ph.summon is Array):
				return id + ": a phase's \"summon\" must be a list"
			for fid in ph.summon:
				if RpgFoes.by_id(str(fid)) == null and not foes_known.has(fid) and str(fid) != id:
					return "%s: a phase summons an unknown foe \"%s\"" % [id, str(fid)]
		if ph.has("fx"):
			if not (ph.fx is Array):
				return id + ": a phase's \"fx\" must be a list"
			for e in ph.fx:
				why = check_fx(e)
				if why != "":
					return "%s: a phase: %s" % [id, why]
	if not (foe.text is String) or not (foe.region is String):
		return id + ": \"text\" and \"region\" must be words"
	return ""


## A belt item (a row of RpgItems).
static func check_item(item) -> String:
	if not (item is Dictionary):
		return "an item must be a dictionary"
	var why = _keys(item, "", ["id", "name", "icon", "text", "fx", "price"], [])
	if why != "":
		return why
	var id = str(item.id)
	if id == "" or not (item.name is String) or str(item.name) == "" or not (item.icon is String) or not (item.text is String):
		return id + ": \"id\", \"name\", \"icon\" and \"text\" must be words"
	if not _is_int(item.price) or int(item.price) < 0:
		return id + ": \"price\" must be a whole number of ore"
	if not (item.fx is Array) or item.fx.is_empty():
		return id + ": it needs effects"
	for e in item.fx:
		why = check_fx(e)
		if why != "":
			return "%s: %s" % [id, why]
		if ["lifesteal", "refund", "self_ko"].has(str(e.k)):
			return "%s: %s is not for an item" % [id, str(e.k)]
	return ""


## A companion's kit (a row of RpgPets).
static func check_pet(kit) -> String:
	if not (kit is Dictionary):
		return "a kit must be a dictionary"
	var why = _keys(kit, "", ["id", "auto", "command", "passive"], [])
	if why != "":
		return why
	var id = str(kit.id)
	if id == "" or not (kit.auto is Dictionary) or not (kit.command is Dictionary) or not (kit.passive is Array):
		return id + ": it needs \"auto\", \"command\" and \"passive\""
	why = _keys(kit.auto, "", ["name", "kind", "power", "school", "fx", "every"], ["target"])
	if why != "":
		return "%s: auto: %s" % [id, why]
	why = _keys(kit.command, "", ["name", "charge", "power", "target", "school", "fx"], ["text"])
	if why != "":
		return "%s: command: %s" % [id, why]
	for part in [kit.auto, kit.command]:
		if not (part.name is String) or str(part.name) == "":
			return id + ": an action needs a name"
		if not _is_num(part.power) or float(part.power) < 0.0 or float(part.power) > 4.0:
			return id + ": \"power\" is out of range"
		if not RpgDefs.SCHOOLS.has(part.school) and part.school != "plain":
			return "%s: unknown school \"%s\"" % [id, str(part.school)]
		if not (part.fx is Array):
			return id + ": \"fx\" must be a list"
		if float(part.power) <= 0.0 and part.fx.is_empty():
			return "%s: %s does nothing" % [id, str(part.name)]
		if part.has("target") and not ["foe", "all", "self"].has(part.target):
			return id + ": \"target\" must be foe, all or self"
		for e in part.fx:
			why = check_fx(e)
			if why != "":
				return "%s: %s: %s" % [id, str(part.name), why]
			if ["self_ko", "hp_cost", "cd_cut"].has(str(e.k)):
				return "%s: %s is not for a companion" % [id, str(e.k)]
	if kit.auto.kind != "attack" and kit.auto.kind != "support":
		return id + ": auto \"kind\" must be attack or support"
	if (str(kit.auto.kind) == "attack") != (float(kit.auto.power) > 0.0):
		return id + ": an attacking auto action has power, a support one has none"
	if not _is_int(kit.auto.every) or int(kit.auto.every) < 1:
		return id + ": \"every\" must be 1 or more"
	if not _is_int(kit.command.charge) or int(kit.command.charge) < 1 or int(kit.command.charge) > 6:
		return id + ": \"charge\" must be 1 to 6"
	for e in kit.passive:
		why = check_passive(e)
		if why != "":
			return "%s: passive: %s" % [id, why]
	return ""


# =============================================================================
# Words for the screens
# =============================================================================

static func _pct(v) -> String:
	return str(int(round(float(v) * 100.0))) + "%"


static func _signed(n: int) -> String:
	return ("+" if n >= 0 else "") + str(n)


static func _turns(n: int) -> String:
	return "%d turn%s" % [n, "" if n == 1 else "s"]


## A phrase that follows "...: " inside another: its first letter goes small,
## unless it begins with a status (those are names: "Exposed", "Shield").
static func _inner(w: String) -> String:
	if w == "":
		return w
	var head = w.get_slice(" ", 0)
	if head == "Stunned" or head == "Shield":
		return w
	for id in RpgDefs.STATUS:
		if head == str(RpgDefs.STATUS[id].name):
			return w
	return w.left(1).to_lower() + w.substr(1)


static func _nth(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "%dth" % n
	return "%d%s" % [n, ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]]


static func _status_name(id: String) -> String:
	return "Stun" if id == "stun" else str(RpgDefs.STATUS.get(id, {}).get("name", id))


## Statuses that read as "is X" (the others as "has X").
const STATUS_ADJ = ["pumped", "weakened", "braced", "exposed", "hasted", "slowed", "stun", "marked", "steady"]


## The words of a status effect without who gets it: "Exposed for 2 turns (70%)".
static func _status_words(e: Dictionary) -> String:
	var id = str(e.get("id", ""))
	var w = "Stunned" if id == "stun" else _status_name(id)
	var stacks = int(e.get("stacks", 1))
	if stacks > 1:
		w += " x%d" % stacks
	elif id == "marked":
		w += " (the next %d moves count as weak)" % RpgDefs.MARKED_STACKS
	if id == "counter" and e.has("amount") and float(e.amount) != 1.0:
		w += " (power %s)" % TTUtil.num_str(float(e.amount))
	var turns = int(e.get("turns", 0))
	if turns > 0:
		w += " for " + _turns(turns)
	if e.has("chance") and float(e.chance) < 1.0:
		w += " (%s)" % _pct(e.chance)
	return w


## What an effect does, in a few words. `attack`: it rides on an attack (so a
## status with no "to" lands on the target); false for a support move, an item
## or a passive (it lands on the hero).
static func fx_words(e: Dictionary, attack: bool = true) -> String:
	var k = str(e.get("k", ""))
	var to = str(e.get("to", ""))
	match k:
		"status":
			var w = _status_words(e)
			var who = to if to != "" else ("target" if attack else "self")
			match who:
				"self":
					return ("You are %s" if STATUS_ADJ.has(str(e.get("id", ""))) else "You gain %s") % w if attack else w
				"all_foes":
					return "Every foe: " + w
				"allies":
					return "Its allies: " + w
				"ally":
					return "An ally: " + w
			return w if attack else w + " on the target"
		"heal":
			var hw = "Heals %s of max HP" % _pct(e.get("pct", 0.0))
			return hw + (" (an ally)" if to == "ally" else (" (every ally)" if to == "allies" else ""))
		"shield":
			var sw = "Shield of %s of max HP" % _pct(e.get("pct", 0.0))
			return sw + (" (an ally)" if to == "ally" else (" (every ally)" if to == "allies" else ""))
		"energy":
			var n = int(e.get("n", 0))
			return "Energy full" if n >= 99 else "%s energy" % _signed(n)
		"gauge":
			return "%s gauge" % _signed(int(round(float(e.get("n", 0.0)))))
		"delay":
			return "Pushes the target's turn back %s" % _pct(e.get("pct", 0.0))
		"cleanse":
			if e.get("ids") is Array:
				var names = []
				for id in e.ids:
					names.append(_status_name(str(id)))
				return "Removes " + " and ".join(names)
			var cn = int(e.get("n", 0))
			return "Removes every debuff" if cn <= 0 else ("Removes %d debuff%s" % [cn, "" if cn == 1 else "s"])
		"dispel":
			var dn = int(e.get("n", 0))
			return "Strips every buff from the target" if dn <= 0 else ("Strips %d buff%s from the target" % [dn, "" if dn == 1 else "s"])
		"interrupt":
			return "Interrupts a charge or a countdown"
		"cd_cut":
			return "Other cooldowns -%d" % int(e.get("n", 1))
		"hp_cost":
			return "Costs %s of current HP" % _pct(e.get("pct", 0.0))
		"lifesteal":
			return "Heals for %s of the damage" % _pct(e.get("pct", 0.0))
		"refund":
			return "+%d energy on a kill" % int(e.get("n", 0))
		"extra_turn":
			return "Act again at once"
		"chip":
			return "Chips %d guard, whatever the school" % int(e.get("n", 1))
		"when":
			var inner = fx_words(e.get("do", {}), attack) if e.get("do") is Dictionary else ""
			return "Under %s HP: %s" % [_pct(e.get("hp_below", 0.0)), _inner(inner)]
		"self_ko":
			return "It falls"
		"flee":
			return "It leaves the fight"
	return ""


## What a move's mod does, in a few words: "+30% against Exposed foes".
static func mod_words(mod: Dictionary) -> String:
	var pct = "+" + _pct(mod.get("pct", 0.0))
	var up = " (up to +%s)" % _pct(mod.get("max", 0.0))
	match str(mod.get("m", "")):
		"vs_status":
			var id = str(mod.get("id", ""))
			return "%s against %s foes" % [pct, "Stunned" if id == "stun" else _status_name(id)] if STATUS_ADJ.has(id) else "%s against foes with %s" % [pct, _status_name(id)]
		"vs_debuff":
			return "%s against a foe with a debuff" % pct
		"per_debuff":
			return "%s per debuff on the target%s" % [pct, up]
		"vs_broken":
			return "%s against Broken foes" % pct
		"vs_full_hp":
			return "%s against a foe at full HP" % pct
		"execute":
			return "%s against a foe under %s HP" % [pct, _pct(mod.get("below", 0.0))]
		"ignore_def":
			return "Ignores the defence" if float(mod.get("pct", 0.0)) >= 1.0 else "Ignores %s of the defence" % _pct(mod.get("pct", 0.0))
		"crit":
			return "Crit chance +%s" % _pct(mod.get("add", 0.0))
		"sure_crit":
			return "Always a crit"
		"ramp_use":
			return "%s per use this battle%s" % [pct, up]
		"ramp_turn":
			return "%s per turn of the battle%s" % [pct, up]
		"streak":
			return "%s per attacking turn in a row%s" % [pct, up]
		"smart":
			return "Chips 1 guard even when the foe is not weak to it"
		"missing_hp":
			return "Up to %s the more HP you have lost" % pct
	return ""


static func _school_word(id: String) -> String:
	return "All" if id == "all" else str(RpgDefs.SCHOOL_NAMES.get(id, id))


static func _on_words(ev: String, every: int) -> String:
	if ev == "turn":
		return "Each turn" if every <= 1 else "Every %d turns" % every
	var w = {"break": "On a break", "kill": "On a kill", "crit": "On a crit", "weak": "On a weakness hit", "guard": "On Guard",
		"hit_taken": "When hit", "wave": "At the start of a wave"}
	if every <= 1:
		return str(w.get(ev, ev))
	var each = {"break": "break", "kill": "kill", "crit": "crit", "weak": "weakness hit", "guard": "Guard", "hit_taken": "hit taken", "wave": "wave"}
	return "Every %s %s" % [_nth(every), str(each.get(ev, ev))]


## What a passive effect does, in a few words: "Push moves +10%".
static func passive_words(fx: Dictionary) -> String:
	var p = str(fx.get("p", ""))
	var pct = _pct(fx.get("pct", 0.0))
	var v = fx.get("v", 0)
	var n = int(fx.get("n", 0)) if (fx.get("n") is int or fx.get("n") is float) else 0
	var add = int(fx.get("add", 0)) if (fx.get("add") is int or fx.get("add") is float) else 0
	match p:
		"stat_pct":
			var st = str(fx.get("stat", ""))
			return "%s +%s" % ["Every stat" if st == "all" else ("Body stats" if st == "body" else str(RpgDefs.STAT_NAMES.get(st, st))), pct]
		"stat_dmg":
			return "%s moves +%s" % [str(RpgDefs.STAT_NAMES.get(str(fx.get("stat", "")), "")), pct]
		"school_pct":
			var psc = str(fx.get("school", ""))
			if psc == "all":
				return "All damage +%s" % pct
			return "Strike +%s" % pct if psc == "plain" else "%s moves +%s" % [_school_word(psc), pct]
		"hp_pct":
			return "Max HP +%s" % pct
		"def_pct":
			return "Defence +%s" % pct
		"spd_pct":
			return "Speed +%s" % pct
		"heal_pct":
			return "Healing +%s" % pct
		"gauge_rate":
			return "The gauge fills %s faster" % pct
		"crit_add":
			return "Crit chance +%s" % _pct(v)
		"dodge_add":
			return "Dodge +%s" % _pct(v)
		"res_add":
			return "Status resist +%s" % TTUtil.num_str(v)
		"atk":
			return "%s attack +%s" % [_school_word(str(fx.get("school", ""))), TTUtil.num_str(v)]
		"armor":
			return "Armor +%s" % TTUtil.num_str(v)
		"hp":
			return "Max HP +%s" % TTUtil.num_str(v)
		"en_max":
			return "Max energy %s" % _signed(n)
		"en_start":
			return "Starts with %d %s energy" % [absi(n), "less" if n < 0 else "more"]
		"gauge_start":
			return "The gauge starts at %s" % TTUtil.num_str(fx.get("n", 0))
		"guard_pct":
			return "Guard blocks %s more" % _pct(v)
		"guard_en":
			return "Guard gives %d more energy" % n
		"lifesteal":
			return "Heals for %s of the damage dealt" % pct
		"start_status":
			var turns = int(fx.get("turns", 0))
			var sw = _status_name(str(fx.get("id", "")))
			if int(fx.get("stacks", 1)) > 1:
				sw += " x%d" % int(fx.stacks)
			return "%s all battle" % sw if (turns <= 0 and not NO_TURNS.has(str(fx.get("id", "")))) else ("Starts each wave with %s" % sw + (" for " + _turns(turns) if turns > 0 else ""))
		"start_shield":
			return "Starts each wave with a Shield of %s of max HP" % pct
		"on":
			var inner = fx_words(fx.get("do", {}), false) if fx.get("do") is Dictionary else ""
			var head = _on_words(str(fx.get("ev", "")), int(fx.get("every", 1)))
			if bool(fx.get("once", false)):
				head = "Once a battle, " + head.left(1).to_lower() + head.substr(1)
			return "%s: %s" % [head, _inner(inner)]
		"low_hp":
			var lw = fx_words(fx.get("do", {}), false) if fx.get("do") is Dictionary else ""
			return "Once a battle, under %s HP: %s" % [_pct(fx.get("below", 0.0)), _inner(lw)]
		"survive":
			return "Once a battle, survives a lethal hit %s" % ("at 1 HP" if float(fx.get("pct", 0.0)) <= 0.0 else "at %s HP" % pct)
		"cost":
			return "%s moves cost %d %s" % [_school_word(str(fx.get("school", ""))), absi(add), "less" if add < 0 else "more"]
		"cd":
			return "%s moves rest %s %s" % [_school_word(str(fx.get("school", ""))), _turns(absi(add)), "less" if add < 0 else "more"]
		"next_cost":
			var sc = _school_word(str(fx.get("school", "")))
			return "After a %s move the next %s move costs %d %s" % [sc, sc, absi(add), "less" if add < 0 else "more"]
		"chip":
			return "A crit chips %d guard" % add if str(fx.get("on", "")) == "crit" else "Weak %s hits chip %d more guard" % [_school_word(str(fx.get("on", ""))), add]
		"status_turns":
			var which = {"debuff": "Debuffs you give last", "buff": "Buffs you give yourself last", "self_debuff": "Debuffs on you last"}
			return "%s %s %s" % [str(which.get(str(fx.get("on", "")), "")), _turns(absi(add)), "less" if add < 0 else "longer"]
		"status_chance":
			return "Status chance +%s" % _pct(fx.get("add", 0.0))
		"vs_broken":
			return "+%s against Broken foes" % pct
		"vs_status":
			var id = str(fx.get("id", ""))
			return "+%s against %s foes" % [pct, "Stunned" if id == "stun" else _status_name(id)] if STATUS_ADJ.has(id) else "+%s against foes with %s" % [pct, _status_name(id)]
		"first_hit":
			return "The first hit on each foe +%s" % pct
		"combo_same":
			return "+%s per move of the same school in a row (up to +%s)" % [pct, _pct(fx.get("max", 0.0))]
		"combo_alt":
			return "+%s when the school changes from the last move" % pct
		"ramp":
			return "+%s damage per turn (up to +%s)" % [pct, _pct(fx.get("max", 0.0))]
		"first_turn":
			return "Acts first"
		"bounce":
			return "The first debuff of a battle bounces off"
		"reward":
			var what = {"ore": "Ore from battles", "xp": "Fighter XP from battles", "luck": "Luck"}
			return "%s +%s" % [str(what.get(str(fx.get("what", "")), "")), pct]
		"adapt":
			return "Resists the school that last hit it"
		"quicken":
			return "%s faster after each of its actions (up to %s)" % [pct, _pct(fx.get("max", 0.0))]
	return ""
