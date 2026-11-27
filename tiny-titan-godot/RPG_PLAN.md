# The Realm: a turn-based RPG inside Tiny Titan

Design and build plan, 2026-11-25 (second version, after four reviews). The user's ask, in their
words: "use this hero in an RPG style game... use lifts and running and reading etc to raise
player stats (strength, agility, intelligence etc)... Even specifically going into leg/arm
strength etc that can affect different types of attacks... turn based combat... really expansive
like unlocking different skills and attack moves and equipping attacks and using our equipment to
give boosts... different [regions] leading to a boss fight... workouts and stuff to give temporary
boosts to help with the next day of fighting while also improving permanent stats... Do not touch
main game besides taking out the campaign for now. This will be a new tab... without impacting
any of my logging stuff."

This file is the contract every builder works from. Where it gives an id, a data shape, a name or
a formula, use exactly that: other files are written against it at the same time. Numbers marked
"(tune)" live in `RpgDefs` and are set by the balance step; everything else is fixed.

--------------------------------------------------------------------------------------------------

## 0. Pillars

1. **Training is the power.** Twelve stats come from the real log (six body parts, six traits) on
   curves with diminishing returns. They never go down. Real stats decide how strong each school
   is and where the road gets hard; play (fighter level, gear upgrades, skills) carries the hero
   from region to region.
2. **What you trained decides how you fight.** Push, Pull and Legs are attack schools fed by the
   muscles they use; Speed is running, Grip is climbing, Mind is reading; Flow (physical therapy)
   and Grit (showing up) are the two support schools. Foes are weak to attack schools; hitting a
   weakness chips their guard.
3. **Yesterday's workout is today's edge.** What was trained today and yesterday gives typed
   boosts ("Chest Pump: Chest moves +15%") that end after tomorrow. Always a bonus on top of
   100%, never a penalty. A rest day earns its own boost.
4. **Builds, not one best button.** Four equipped moves (five later), an ultimate, three passives,
   nine gear slots with stat lines, runes, sets, relics, a companion with a command, a belt of
   items, three saved builds. Respec is free.
5. **Fights are short and readable.** 1 to 3 minutes. A turn timeline, foe intents with their
   numbers, one resource (energy) plus cooldowns, statuses in mirrored pairs.
6. **No meter, no punishment.** Unlimited attempts. Nothing is lost by losing, by resting or by
   not opening the tab. Logging is never gated on anything here.
7. **Separate from the main game.** The Realm READS the log and the derived state. It never
   writes a session and never changes XP, coins, trophies, missions or the plan. Its own progress
   is `saved.rpg`. The rules engine and the parity tests are untouched.

The tab is **Realm**; the world is **the Ironwild**. On screen the stat `endurance` is
"Endurance" and the fight's resource is "Energy" (never both "stamina").

--------------------------------------------------------------------------------------------------

## 1. The loop

Train (logged as always) -> open Realm: stats have grown, a **training chest** waits for today and
for yesterday if there was training, **boosts** from those two days are listed -> pick a stage,
see the foes and their known weaknesses, adjust the build -> fight -> fighter XP, ore, items,
runes, stars -> learn skills, upgrade gear, equip moves -> the next stage, the daily hunt, the
weekly rival or the Spire.

Three clocks: real stats (weeks), fighter level and gear (days), a fight (minutes).

--------------------------------------------------------------------------------------------------

## 2. Stats (derived from the log, never stored)

Ids (`RpgDefs.BODY`, `TRAITS`, `STATS`, in this order):

| id | shown as | from | does |
|---|---|---|---|
| chest | Chest | chest lifts | Push moves that name it |
| shoulders | Shoulders | shoulder lifts | Push moves that name it |
| arms | Arms | biceps, triceps, forearm lifts | Push and Pull moves that name it |
| back | Back | back lifts (traps too) | Pull moves |
| core | Core | core lifts | Defence, what Guard blocks |
| legs | Legs | quads, hamstrings, glutes, calves | Legs moves, part of max HP |
| speed | Speed | running pace, runs done, distance | Turn order, Speed moves |
| endurance | Endurance | longest run, distance, every session | Max HP, energy pool |
| grip | Grip | hardest sends, hangboard, sends | Crit chance, Grip moves |
| mind | Mind | pages read, books finished, reading streak | Mind moves, status chance |
| flow | Flow | physical therapy sets, stretches | Healing, status resist, dodge |
| grit | Grit | days trained, best week streak, perfect days | Ultimate gauge, last stands |

Every stat is a float `raw` in 1..99.99; the shown value is `floor(raw)` (the Hero page shows one
decimal and the change over the last 7 days).

### 2.1 Body stats (`RpgStats`)

One pass over the lift sessions, oldest first, up to a cutoff date. Per exercise with real sets
(reps > 0, `LiftTrend.real_sets`):

- **Mobility** (RPG rule, not `Dosage.is_mobility`): a PT mark (`Pt.is_pt(marks, name)`), a
  library part of "mobility", or "stretch" in the name. Its sets go to flow (2.2), nothing else.
  A hold that is not mobility (a plank, a dead hang) scores for its own part.
- The RPG part: `RpgStats.part_of(name)` = `Dosage.part(name)` folded: chest; back; shoulders;
  biceps / triceps / forearms -> arms; quads / hamstrings / glutes / calves -> legs; core;
  "full" -> its strength score counts for legs and back, its sets are half a set each for legs,
  back and core; other -> none.
- **Work**: `work[part] += sets`. Plus `Dose.also_of(name)` folded to RPG parts (`Dose.AREA`,
  then the fold above), the lift's own part dropped, the largest share kept per part. A climbing
  session adds 4 sets of work to arms and none to back (the user: climbing is fingers, not back).
- **Days**: `days[part]` = the dates with direct sets.
- **Strength score** `SS` of a set, the best ever kept per MOVEMENT (`Missions.move_of`):
  - weighted: `e1rm = kg * (1 + min(reps, 12) / 30.0)` (with `Sides.n(settings, name) == 2`
    halve the reps first), `SS = e1rm / anchor_kg`;
  - a movement whose library `only` is bodyweight, with added weight: `SS = reps / anchor_reps *
    (1 + kg / bodyweight)` (`Standards.bodyweight(body)`, 75 when unknown);
  - weightless, movement in `RpgStats.BW_ANCHORS` (Pull-up 25, Chin-up 25, Push-up 60, Dip 35,
    Inverted Row 30, Leg Raise 30, Toes-to-Bar 20, Nordic Curl 12, Pistol Squat 15, Handstand
    Push-up 15, Muscle-up 10): `SS = reps / anchor`;
  - any other weightless set: `SS = min(0.25, reps / 80.0)`;
  - a band set: `SS = 0.45 * Bands.level(band) / 9.0`;
  - a hold: `SS = min(0.5, sec / 240.0)`.
  `anchor_kg`: `RpgStats.ANCHORS` by movement (elite one-rep maxes, barbell unless said: Bench
  Press 150, Squat 200, Deadlift 240, Overhead Press 95, Bent Over Row 140, Romanian Deadlift 190,
  Hip Thrust 230, Curl 75, Lat Pulldown 130, Seated Row 130, Leg Press 400, Leg Extension 130,
  Leg Curl 100, Calf Raise 200, Lateral Raise 25 a hand, Chest Fly 45 a hand, Face Pull 60, Tricep
  Pushdown 90, Skull Crusher 70, Shrug 220...: the builder reads `LiftLibrary.MOVES` and fills it
  for every movement with a clear standard) times the equipment factor of the variation
  (`Missions.gear_of_lift`: barbell 1, smith 1, machine 1.1, cable 0.65, dumbbell 0.48 a hand,
  kettlebell 0.4). A movement with no row uses the part's default (chest 140, back 140, shoulders
  85, arms 70, legs 190, core 90) times the factor, and its SS is capped at 0.7.
  `peak_ss[part] = 0.6 * best + 0.25 * second + 0.15 * third` over the part's movements (so more
  good movements for a part raise it).

```
ramp      = 1 - exp(-days[part].size() / 3.0)
peak_pts  = PEAK (64, tune) * pow(clamp(peak_ss, 0, 1.2), 0.85) * ramp
work_pts  = 30 * log(1 + work / 40.0) / log(101.0)
raw       = clamp(1 + peak_pts + work_pts, 1, 99.99)
```

### 2.2 Traits

```
speed     = 1 + 40 * clamp((180.0 / pace - 0.2) / 0.65, 0, 1.1) * (1 - exp(-runs / 3.0))
              + 25 * log(1 + runs / 4.0) / log(1 + 150 / 4.0)
              + 15 * log(1 + run_km / 20.0) / log(1 + 1500 / 20.0)
            pace = the best seconds per km of: RunSplits.bests (each as a pace), prs.bestPaceSecPerKm,
            any run of 1.5 km or more with a duration. No timed run: the pace part is 0.
endurance = 1 + 60 * log(1 + longest_run_km / 2.0) / log(1 + 42.2 / 2.0) * (1 - exp(-runs / 3.0))
              + 20 * log(1 + km / 30.0) / log(1 + 5000 / 30.0)     # km = runs + 0.3 rides + 0.5 vest walks
              + 12 * log(1 + sessions / 20.0) / log(1 + 2000 / 20.0)   # every session of any kind
grip      = 1 + (grade_pts + min(10, 0.2 * max(0, best_hang_kg)) + min(6, longest_hang_sec / 20.0))
                  * (1 - exp(-climb_sessions / 3.0))
              + 20 * log(1 + sends / 30.0) / log(1 + 3000 / 30.0)
              + 6 * log(1 + forearm_sets / 100.0) / log(1 + 3000 / 100.0)
            grade_pts: hardest boulder sent: VB 9, V0 14, +5 a grade (V4 34, V10 64); a route counts
            as the V it is worth; +2 when the hardest flash is within one grade of it. Never climbed: 0.
mind      = 1 + 45 * log(1 + pages / 150.0) / log(1 + 30000 / 150.0)
              + min(20, book_pts)          # a finished book 2 (1 after the fifth); one with an empty log half
              + min(15, best_reading_streak / 2.0) + min(8, reading_days / 25.0)
flow      = 1 + 60 * log(1 + mobility_sets / 30.0) / log(1 + 10000 / 30.0)
              + min(12, hold_minutes / 10.0) + min(8, weeks_with_9_mobility_sets / 4.0)
grit      = 1 + 40 * log(1 + active_days / 20.0) / log(1 + 1500 / 20.0)
              + min(20, 2 * best_week_streak) + min(15, 0.5 * perfect_days) + (3 if best_week_streak >= 1)
```
All clamped to 1..99.99. `active_days` = `state.totals.activeDays`, `best_week_streak` =
`state.streak.best`, `perfect_days` = claims whose questId ends in ":perfect". Nothing here reads a
CURRENT streak, so nothing ever falls. An empty log gives every stat 1.

### 2.3 The sheet

`RpgStats.sheet(input) -> Dictionary`; `input` = `{sessions, state, reading, books, body, claims,
settings, marks, today}` (plain data; `state` = `App.state`, `marks` = `App.pt()`):

```
{"stats": {<id>: {"id", "name", "v": int, "raw": float, "was": float (raw 7 days ago),
                  "lines": [String], "next": String}},
 "body": [ids], "traits": [ids], "might": float (mean raw of the six body stats),
 "days": int, "sessions": int}
```
`lines` say what the stat is made of in the player's units (`Fmt` with `settings.weightUnit` /
`distanceUnit`): "Best: Squat 230 lb x 5", "412 sets so far". A number worked out and not lifted
is never shown as lifted. `next` is the nearest way to the next point. `was` comes from the same
pass run with the cutoff 7 days back.

`RpgStats.sets_by_part(sessions, marks, settings, date) -> {part: sets}` (direct 1, also-works at
its share, mobility left out) and `RpgStats.mobility_sets_on(sessions, marks, date) -> int` are
shared with the boosts.

--------------------------------------------------------------------------------------------------

## 3. Boosts (derived from today's and yesterday's log)

`RpgBoosts.active(input) -> Array` of `{"id", "name", "icon", "school" (for the colour; "" =
neutral), "text", "why", "from": date, "until": date, "fx": [passive effects]}`.

A boost earned on day D is in force on D and D+1 and then gone. Earned on both days: the stronger
one counts. All percentages are fractions in `fx`.

| id | earned by (that day) | effect |
|---|---|---|
| pump_<body stat> (six) | 3+ sets for the part | moves scaled by that stat +10% damage (by the stat's weight in the move); 6+ sets +15%; 9+ sets +20% (`stat_dmg`) |
| second_wind | a run | Speed moves +10% and speed +5%; 5 km or more: +15% / +8% and energy start +1 |
| chalked_up | a climbing session | Grip moves +10%, crit +4%; with a flash that day +15% / +6% |
| sharp_mind | 10+ pages | Mind moves +8%; 30+ pages +12%; 50+ pages +15% and the hero's debuffs last 1 turn longer |
| limber | 3+ mobility sets | the first debuff of a battle bounces off; 9+ sets: healing +20% too |
| well_rested | YESTERDAY had no strength work and the 6 days before it had 2+ training days | max HP +10%, energy start +2; today only |
| record_rush | a record (a `state.chronicle` entry of kind "pr" dated that day) | the gauge starts at 50 |
| golden_day | the perfect-day chest claimed for that day | ore from battles +25% |
| on_a_roll | training on 4+ of the last 7 days | ore from battles +10% |

`RpgBoosts.chest(input, date) -> Dictionary or null`: the **training chest** of a day with a
session, 10+ pages or mobility sets: `{"date", "kinds": [..], "tier": "wood"|"iron"|"gold", "ore",
"items": [{id, n}], "rune": bool}`: kinds = which of lift, run, climb, read, mobility, other
happened; ore `30 + 25 * kinds`; tier iron at 3+ kinds, gold on a perfect day; 1 item (2 at iron,
3 and a rune at gold), seeded by the date. Only today's and yesterday's can be claimed.
`saved.rpg.chests[date]` = the number of kinds already paid: a day that grows later pays the
difference in ore. `RpgBoosts.chest_waiting(state, reading, rpg, today) -> bool` is a cheap check
for the tab's dot (it looks at `state.dateCounts` and the reading of the two days only).

--------------------------------------------------------------------------------------------------

## 4. Combat

### 4.1 The numbers (`RpgDefs`: the single home of every constant and formula)

```
K_DEF = 60
level_mult(L)        = 1 + 0.03 * (L - 1)
offence(stat, w, L)  = (20 + stat + w) * level_mult(L)         # w = gear attack for the move's school
hero_hp(s, L)        = 80 + 8 * L + 2 * endurance + legs + core              (then * (1 + hp_pct))
hero_def(s, armor)   = 0.5 * core + 0.2 * might + armor                      (then * (1 + def_pct))
mitigation(def)      = K_DEF / (K_DEF + def)
damage               = max(1, floor(P * offence * mitigation(target def) * mods * (0.92 + 0.16 * rand) + rand))
crit (hero)          = 0.05 + 0.002 * grip + adds, cap 0.40; x1.5.    Foes 0.05, x1.25; bosses never.
dodge (hero)         = min(0.20, 0.002 * flow + adds).                Foes do not dodge.
status chance        = clamp(base + 0.005 * (tec - res), 0.15, 0.95); hero tec = mind, res = flow;
                       a foe's tec = res = ref_stat(t) (elite +10, boss +20). A status with no chance
                       given always lands (Stun excepted).
delay(rank, spd)     = 1000 * rank / (150 + spd)                       hero spd = speed stat * (1 + spd_pct)
energy               = max 6 + floor(endurance / 25); starts at 3 (+ en_start); +1 at the start of
                       every hero turn (the first too); Strike +1; Guard +2. Clamped after every change.
gauge                = 0..100: +6 an attacking action, +4 more when it hit a weakness, +20 a break,
                       + 60 * (damage taken / max HP); all * (1 + grit / 200) * (1 + gauge_rate). Clamped.
heal, shield         = share of max HP * (1 + flow / 100) * (1 + heal_pct)
between waves        the hero heals (10 + flow / 4)% of max HP
```

**The reference hero** of tier t (a float; regions are tiers 1 to 8; `t = 1 + n / 10`):

```
ref_stat(t)   = REF_STAT [12, 22, 31, 39, 46, 52, 57, 61] interpolated; past 8: +3 a tier   (tune)
ref_side(t)   = 0.7 * ref_stat(t)          # its endurance, legs, core, might and speed
ref_level(t)  = clamp(5 t - 4, 1, 60)
ref_w(t)      = 4 + 3.4 (t - 1)            # gear attack: about a kit of rares at +t
ref_armor(t)  = 2.5 + 2 (t - 1)
ref_p(t)      = 1.15 + 0.12 (t - 1), at most 2.0     # the average power of its moves per action
```
Foes are SOLVED from it (never typed in):

```
foe_def(n)        = 8 + 3 (t - 1)
foe_hp(n)         = TTK (3.3) * ref_p(t) * offence(ref_stat, ref_w, ref_level) * mitigation(foe_def(n))
foe_atk(n)        = HIT (0.065) * hero_hp(ref) / mitigation(hero_def(ref))     # a P 1 hit: 6.5% of the reference hero
foe_spd(role, n)  = SPD_RATIO[role] * (150 + ref_side(t)) - 150
```
`RpgDefs.ROLES` (hp, atk, speed ratio, guard pips): swarm 0.55 / 0.7 / 1.15 / 2; skirmisher 0.8 /
0.9 / 1.25 / 2; brute 1.3 / 1.2 / 0.9 / 3; tank 1.5 / 0.8 / 0.9 / 5 (def x1.5); caster 0.75 / 1.0 /
1.05 / 2; healer 0.8 / 0.6 / 1.05 / 3; elite 2.5 / 1.1 / 1.0 / 6; boss 5.0 / 1.25 / 1.0 / 6.
In a pack of c REGULAR foes each one's hp and atk are multiplied by `2 / (c + 1)`; an elite or a
boss is never scaled, its adds are x0.5.

`RpgHero.power(unit)` = `sqrt(DPT * EHP) / 2`, `DPT = mean P/rank of the equipped attack moves *
best offence * (1 + crit * 0.5) * (150 + spd) / 190`, `EHP = hp_max / mitigation(def)`. A stage's
recommended power = `RpgHero.power(RpgHero.reference(t))`.

**Targets** (the one table; the simulator checks them, section 13): a wave of regular foes 3 to 6
hero turns; an elite stage 6 to 11; a boss 11 to 22; the reference hero ends a regular stage with
65%+ HP, an elite with 35%+; no death from full HP inside two foe actions; no single telegraphed
hit over 35% of the reference hero's max HP.

**Where this player should sit (the calibration, done with his real log on a scratch copy):** his
strong schools about even with the reference of region 5 at equal level and gear. Regions 1 and 2
are a fast introduction, 3 to 5 comfortable to even, 6 to 8 need levels, gear, a build that hits
weaknesses and the day's boosts; real growth and the Spire reach past that.

### 4.2 Turn order

Each unit has `at`, the time of its next action; the lowest acts (ties: hero, pet, then foes in
order), then `at += delay(rank of what it did, its spd)`. First `at` = `delay(1, spd) * (0.5 + 0.5
* rand)`. `RpgBattle.timeline(B, 7)` lists who acts next assuming rank 1. Hasted x1.3 speed,
Slowed x0.7. A "delay" effect adds a share of the target's rank-1 delay to its `at` (halved on a
boss). `extra_turn` leaves the hero's `at` where it is.

### 4.3 The hero's turn

Exactly one of:

- **A move** from the equipped set (energy cost, cooldown in hero turns, rank 0.5 quick .. 1.6
  heavy).
- **Strike**: P 0.9, rank 0.9, free, +1 energy, school "plain" (scales with the hero's best body
  stat; never chips, never weak or resisted).
- **Guard**: until the hero's next turn damage taken x `(0.5 - core / 400.0)` (core 40: x0.4), +2
  energy, rank 0.7.
  A **perfect guard**: a Guard that takes a blow the foe had charged (a wind-up) or a bomb going off.
  The foe loses `PERFECT_CHIP` (1) guard pip, which can break it, and the gauge gains
  `GAUGE_PERFECT` (12). Event `perfect {src, chip, guard}`; `summary.perfect` counts them.
- **An item** from the belt (rank 0.6).
- **The ultimate** when the gauge is 100 (uses all of it; rank 1.0).
- **Flee**: the battle ends as a loss; nothing is lost.

Free, before one of those, not ending the turn: the **companion's command** when charged.

### 4.4 Guard break

A foe has guard pips, two weak schools (a boss per phase) and at most one resisted school, all
from the six ATTACK schools (push, pull, legs, speed, grip, mind). A move of a weak school does
x1.25 damage and chips its `chip` (1; "breakers" 2) pips ONCE per move per target, however many
hits. A resisted school does x0.7 and never chips. At 0 pips the foe is **Broken**: its intent is
cancelled, it loses its next action, and it takes x1.4 until that lost action has passed. Then the
pips come back and cannot be chipped until the foe has acted once.

Weaknesses start hidden ("?"). A weak hit teaches that school for good (`saved.rpg.seen[key]`,
key = foe id, or `id#2` for a boss's second phase; kept even after a loss). **Insight** (a status
on the hero side) shows every foe's weak and resisted schools and its intent after next while it
lasts, and writes nothing. Foes whose weaknesses were set by the setup (the hunt, the rival, an
echo rule) are always shown and never written.

### 4.5 Intents

After a foe acts (and at the start) its next move is chosen (pattern and rules, 8.3) and shown:
an icon, the damage it will do to the hero as things stand (always, insight or not), "charging"
for a wind-up, a number for a countdown. An intent never lies. A foe that will lose its action
shows "stunned".

### 4.6 Statuses (`RpgDefs.STATUS`)

| id | name | effect | kind |
|---|---|---|---|
| pumped / weakened | Pumped / Weakened | damage dealt +25% / -25% | buff / debuff |
| braced / exposed | Braced / Exposed | damage taken -25% / +25% | buff / debuff |
| hasted / slowed | Hasted / Slowed | speed x1.3 / x0.7 | buff / debuff |
| burn | Burn | end of its turn: 6% max HP (on a foe: 0.5 x the applier's mind offence after its defence; a boss at most 3% max HP) | debuff |
| bleed | Bleed | stacks to 3; each stack 3% max HP a turn (on a foe: 0.3 x the applier's offence a stack) | debuff |
| stun | Stunned | loses its next action; then immune for 2 of its turns; a boss is delayed 60% instead | debuff |
| regen | Regen | start of its turn: heals 6% max HP | buff |
| shield | Shield | absorbs damage; no duration; a new one keeps the larger amount | buff |
| focus | Focus | its next hit is a sure crit (a stack per hit) | buff |
| evade | Evade | dodges the next hit (a stack per hit) | buff |
| counter | Counter | when hit by an attack, strikes back with P = amount | buff |
| steady | Steady | cannot be stunned | buff |
| marked | Marked | the next 2 moves on it count as weak (2 stacks) | debuff |
| insight | Insight | see 4.4 (on the hero) | buff |

Durations count the affected unit's own turns and tick at the end of its turn; a lost turn is
still a turn (regen, burn, bleed, durations and cooldowns run). The same status again refreshes
the duration (bleed, focus, evade add a stack). Each pair cancels (Pumped removes Weakened and
the reverse). On screen a unit shows at most three status icons, then "+N"; a tap lists them in
words.

### 4.7 The companion

Any owned pet, chosen in the build. Not a target. It has a timeline slot (spd 34 + 2 per tier of
the hero's level), does its auto action on each of its turns and gains 1 charge per turn; at
`charge_max` (2 to 4) the hero may give the command (free). Its attacks use `offence(hero's best
body stat * 0.5, 0, hero level) * rarity mult` (1.0 / 1.1 / 1.2 / 1.35 / 1.5). No companion: no
timeline slot; the key stays in place, switched off.

### 4.8 Waves, winning, losing

A stage is 1 to 3 waves. HP, energy, gauge and cooldowns carry over; statuses are cleared and the
hero heals a little (4.1) between waves. All foes of the last wave down: a win. Hero HP 0: a loss
(unless a "survive" effect is unused). Afterwards the hero is whole again either way.

### 4.9 More rules (so two builders decide the same way)

- A win is checked first: the last foe down wins even if the hero reached 0 in the same action.
  `hp_cost` never takes the last HP.
- A foe killed by its own burn or bleed: events `tick`, `ko`; no refund, gauge or "on kill"; it
  still counts for rewards.
- A missing or dead target becomes the first living foe; `options(B).targets` is never empty while
  the battle runs.
- A summon fills places up to three living foes; none free: the move is not chosen. Unit ids run
  on from `B.next_id` and are never reused.
- Belt: at most 3 uses of a stack in one battle; what was used is taken from the save only on a
  WIN.
- `turns` in the summary = hero turns over all waves, lost ones included; `schools` leaves out
  plain, items and the pet.

### 4.10 Resuming

`B` is JSON-safe. After every hero action the view stores `App.draft_store("battle", {"day":
App.today, "v": RpgDefs.VERSION, "what": {...}, "B": B})`; the Realm offers "Continue the battle"
when `App.draft_load("battle")` returns one of this version (a draft of another day is dropped by
`draft_load` itself; nothing is lost). The battle never re-reads the hero after it starts.

--------------------------------------------------------------------------------------------------

## 5. Moves (`RpgMoves`)

```
{"id", "name", "school": "push"|"pull"|"legs"|"speed"|"grip"|"mind"|"flow"|"grit"|"plain",
 "kind": "attack"|"support",
 "scale": {<stat id>: weight, ...},       # weights sum to 1; two-stat moves 0.6 / 0.4 in the order written
 "power": float, "hits": int, "target": "foe"|"all"|"random"|"self", "splash": float (0 = none),
 "cost": int, "cd": int, "rank": float, "chip": int (default 1),
 "mods": [mod, ...], "fx": [effect, ...], "tags": [String], "text": String,
 "ult": bool, "tier": int (0 starter, 1..5 board, 9 scroll)}
```

**Budget** (so nothing is simply best; the content test checks it within 15%):
`P = 1.05 * rank + 0.25 * cost * min(1, rank) + 0.2 * cd`, then minus what else the move does (a
status 0.3 to 0.6, energy or gauge given 0.25 a point of energy / 0.1 per 10 gauge), "all" x0.6,
a multi-hit move's hits sum to P x1.05, an ultimate x1.6 of a cost-5 cd-4 move. **A move rests:**
every move that is not a starter has cd 1 or more. A buff a move gives the hero never raises that
same move's own damage.

**Mods** (`m`; pct is a fraction): `vs_status {id, pct}`, `vs_debuff {pct}`, `per_debuff {pct,
max}`, `vs_broken {pct}`, `vs_full_hp {pct}`, `execute {below, pct}`, `ignore_def {pct}`, `crit
{add}`, `sure_crit`, `ramp_use {pct, max}` (per use this battle), `ramp_turn {pct, max}` (per hero
turn of the battle), `streak {pct, max}` (attacking turns in a row), `smart` (chips 1 even when
not weak), `missing_hp {pct}`.

**Effects** (`k`; applied after the damage, in order; `to` = "target" (default for an attack) |
"self" | "all_foes" | for foe moves "allies" / "ally"): `status {id, turns, chance, stacks,
amount, to}`, `heal {pct, to}`, `shield {pct, to}`, `energy {n}`, `gauge {n}`, `delay {pct}`,
`cleanse {n}` (0 = all) or `cleanse {ids}`, `dispel {n}`, `interrupt`, `cd_cut {n}`, `hp_cost
{pct}`, `lifesteal {pct}`, `refund {n}` (when the move kills), `extra_turn`, `chip {n}` (chips
whatever the school), `when {hp_below, do: effect}`, `self_ko`.

The engine's validators (`RpgBattle.check_move`, `check_fx`, `check_passive`, `check_foe`) are the
last word on the vocabulary: content that does not pass them is wrong. Nobody adds a kind outside
the engine; a need goes in the builder's report.

**The catalog.** Written `Name [tier] (scaling) cost / cd / rank: what else`. Power comes from the
budget unless given. Tier 0 = starter (known from the start, no node).

Push: Shove [0] (arms) 1/0/1.0: delay 15% · One-Two [1] (arms) 2/1/1.0: 2 hits · Bench Blast [1]
(chest) 2/1/1.0: +30% vs Exposed · Lockout [2] (arms, chest) 2/2/1.0: Exposed 2, 70% · Haymaker
[2] (arms) 3/2/1.3 · Press Through [2] (shoulders) 2/1/1.0: ignores half the defence · Bulldoze
[3] (chest) 3/2/1.1: all · Burnout Set [3] (arms) 4/3/1.2: 4 hits; the hero is Weakened 1 after ·
Overhead Smash [4] (shoulders) 4/3/1.5: chip 2 · ultimate **Titan Press** [5] (chest, shoulders):
chip 3, Exposed 2.

Pull: Yank [0] (back) 1/0/1.0: +1 energy · Row Rip [1] (back) 2/1/1.0: Bleed 3 · Arm Drag [1]
(arms) 2/2/1.0: Slowed 2, 70% · Reel In [2] (back) 2/1/0.7 · Chin Check [2] (arms) 2/1/1.0: crit
+25% · Lat Spread [2] (support) 2/3/0.8: Shield 20% · Suplex [3] (back) 3/2/1.2: +50% vs Broken ·
Clinch [3] (back) 3/4/1.0: Stun 45% · Deadlift Slam [4] (back, legs) 4/3/1.5: chip 2 · ultimate
**Mountain Mover** [5] (back): splash 0.4, chip 2 on all.

Legs: Stomp [0] (legs) 1/0/1.0 · Lunge Strike [1] (legs) 2/1/0.8 · Squat Launch [1] (legs)
2/2/1.0: the hero is Pumped 2 after · Knee Crush [2] (legs) 2/2/1.0: Weakened 2, 70% · Dropkick
[2] (legs) 3/2/1.1: delay 40% · Calf Spring [2] (support) 2/4/0.6: Hasted 3 · Earthshaker [3]
(legs, core) 4/3/1.2: all; Slowed 2, 50% · Root Stance [3] (support) 2/3/0.7: Braced 2, Counter
1.0 for 2 turns · Leg Day [4] (legs) 5/4/1.6: the hero is Slowed 1 after · ultimate **Quake
Drop** [5] (legs): all; Stun 60%.

Speed: Dash Strike [0] (speed) 1/0/0.6 · Flurry [1] (speed) 2/1/1.0: 3 hits · Tempo Run [1]
(speed) 1/1/0.9: +20% per use, to +100% · Hit and Run [2] (speed) 2/2/1.0: Evade 1 · Slipstream
[2] (speed) 2/2/0.9: all; Slowed 1 · Second Wind [2] (support) 0/4/0.7: heal 15%, +2 energy ·
Sprint Start [3] (support) 2/4/0.5: Hasted 3, gauge +10 · Negative Split [3] (speed) 3/2/1.0:
+15% per turn of the battle, to +150% · Lap [4] (speed) 3/3/1.0: extra turn · ultimate **Runner's
High** [5] (speed): 6 hits on random foes; Hasted 3.

Grip: Pinch [0] (grip) 1/0/1.0: crit +15% · Crimp Strike [1] (grip) 2/1/1.0: ignores 60% of the
defence · Chalk Up [1] (support) 1/3/0.5: Focus, +1 energy · Heel Hook [2] (grip) 2/2/1.0: Exposed
2, 75% · Flash [2] (grip) 2/2/1.0: +60% on a target at full HP · Campus Rush [2] (grip) 3/2/1.0:
3 hits; crit +10% · Dyno [3] (grip) 3/2/1.2: refund 2 on a kill · Lock Off [3] (grip) 3/4/1.0:
Stun 50% · Send It [4] (grip) 3/2/1.1: x2 under 35% HP · ultimate **Free Solo** [5] (grip): a
sure crit, ignores the defence.

Mind: Burning Page [0] (mind) 1/0/1.0: Burn 3, 80% · Read the Room [1] (support) 1/2/0.5: Insight
4; Exposed 1 on the target · Hex of Doubt [1] (mind) 2/2/1.0: Weakened 3, 85% · Footnote [2]
(mind) 2/1/1.0: +40% vs any debuff · Annotate [2] (support) 2/3/0.6: Marked · Speed Reading [2]
(support) 2/4/0.6: Hasted 2, cooldowns -1 · Plot Twist [3] (mind) 3/3/0.9: interrupt, delay 60% ·
Chapter Close [3] (mind) 3/2/1.0: +25% per debuff on the target, to +100% · Thesis [4] (mind)
4/3/1.3: smart · ultimate **Final Chapter** [5] (mind): Burn, Weakened and Exposed 3.

Flow (support school; scaling flow): Deep Breath [0] 2/3/0.7: heal 20%, cleanse 1 ·
Counterstretch [1] 1/3/0.6: Braced 3 · Foam Roll [2] 0/3/0.5: cleanse all, +2 energy · Balance
[2] (attack) 2/1/1.0: lifesteal 50% · Loosen Up [3] 2/4/0.7: Regen 3, cleanse all · Flow State
[4] 3/4/0.6: Evade 2 · ultimate **Second Life** [5]: heal 60%, cleanse all, Regen 3, +4 energy.

Grit (support school; scaling grit): Grind [0] (attack) 1/0/1.0: gauge +12 · Rally [1] 2/3/0.6:
Pumped 3 · No Days Off [2] (attack) 2/1/1.0: +10% per attacking turn in a row, to +50% · Unbroken
[2] 2/3/0.7: Braced 2; under 40% HP also heal 15% · Dig Deep [3] 0/3/0.5: costs 20% of current
HP; +4 energy, Pumped 1 · Iron Will [4] 2/4/0.7: Shield 25%, Steady 3 · ultimate **Titan Form**
[5]: Pumped, Braced and Hasted 3; energy full.

**Scrolls**: 16 more moves (two per school, tier 9, no node), found, not learned: one from each
region's elite the first time it falls, one at every fifth Spire floor up to 40. Named and
written by the content builder inside the vocabulary and the budget.

Starters (`RpgMoves.STARTERS`): shove, yank, stomp, dash_strike, pinch, burning_page, deep_breath,
grind. A new build equips shove, yank, stomp, deep_breath.

--------------------------------------------------------------------------------------------------

## 6. Skills (`RpgSkills`, `RpgPassives`)

Eight **boards**, one per school. Node: `{"id": "<board>:<ref>", "board", "tier" (1..5), "kind":
"move"|"passive"|"ult", "ref", "cost", "stat" (the stat it asks for), "col", "row"}`.

- An attack board (12 nodes): tier 1 two moves and a passive; tier 2 three moves; tier 3 two
  moves and a passive; tier 4 one move and a passive; tier 5 the ultimate. Flow and Grit (9
  nodes): tier 1 a move and a passive; tier 2 two moves; tier 3 a move and a passive; tier 4 a
  move and a passive; tier 5 the ultimate. The moves' tiers are in section 5.
- Cost by tier: 1, 1, 2, 3, 4. All boards: 168 points.
- To learn (`RpgSkills.can_learn(rpg, node_id, sheet, level) -> {"ok", "why"}`): enough points;
  an owned node of the tier below on the same board (tier 1: none); fighter level 1 / 1 / 4 / 10
  / 18 by tier; and the **stat requirement**: `RpgDefs.REQ[tier]` = 1 / 12 / 24 / 36 / 46 (tune)
  of the node's `stat` (a move: the stat with the biggest weight in its `scale`, the first on a
  tie; a passive or a support move: `RpgDefs.BOARD_STAT[board]`: push chest, pull back, legs legs,
  speed speed, grip grip, mind mind, flow flow, grit grit), read from `sheet.stats[stat].v`,
  never a boosted value. A learned node stays learned.
- **Skill points** earned (`RpgSkills.points`) = `3 + (fighter level - 1) + 2 * region bosses
  beaten + floor(stars / 12) + floor(active training days / 8)`. Spent = the cost of the owned
  nodes. "Reset all" is free, any time; it does not touch the builds (a move no longer known is
  simply skipped until it is known again).

**Board passives** (three slots, at fighter level 3, 10, 20). `{"id", "name", "text", "fx":
[passive effects]}`, tiers in brackets:
Push: Lockout Strength [1] (Push +10%) · Pressing Momentum [3] (after a Push move the next Push
move costs 1 less) · Spotter [4] (once, under 30% HP: Shield 20%).
Pull: Grip and Rip [1] (Pull +10%) · Hook Grip [3] (a weakness hit gives +1 energy) · Lats of
Steel [4] (defence +12%).
Legs: Leg Drive [1] (Legs +10%) · Never Skip [3] (Guard gives 1 more energy and blocks 10% more)
· Tree Trunks [4] (max HP +12%).
Speed: Light Feet [1] (speed +8%) · Negative Splits [3] (+2% damage per hero turn, to +20%) · Off
the Line [4] (acts first; Hasted 1 at the start).
Grip: Chalk Hands [1] (crit +8%) · Onsight [3] (the first hit on each foe +30%) · Precision [4]
(a crit chips 1 guard).
Mind: Marginalia [1] (the hero's debuffs last 1 turn longer) · Thinker's Calm [3] (+1 energy every
third hero turn) · Well Read [4] (Insight all battle).
Flow: Supple [1] (dodge +8%) · Good Recovery [3] (heals 3% at the start of each hero turn) ·
Mobility Work [4] (debuffs on the hero last 1 turn less).
Grit: Stubborn [1] (status resist +15; Guard heals 3%) · Streak Fire [3] (the gauge fills 25%
faster) · Last Stand [4] (once a battle, survive a lethal hit at 1 HP).

**Passive effects** (`p`; one vocabulary for board passives, gear, runes, sets, relics, pets,
boosts and foe traits; every pct is a fraction): `stat_pct {stat, pct}` (stat may be "all" or
"body"), `stat_dmg {stat, pct}` (damage of moves scaled by the stat, by its weight), `school_pct
{school, pct}` ("all" allowed), `hp_pct`, `def_pct`, `spd_pct`, `heal_pct`, `gauge_rate` `{pct}`,
`crit_add`, `dodge_add`, `res_add` `{v}`, `atk {school, v}` (flat gear attack; "all" allowed),
`armor {v}`, `hp {v}`, `en_max`, `en_start`, `gauge_start` `{n}`, `guard_pct {v}`, `guard_en {n}`,
`lifesteal {pct}`, `start_status {id, turns}`, `start_shield {pct}`, `on {ev:
"break"|"kill"|"crit"|"weak"|"guard"|"hit_taken"|"turn"|"wave", do: effect, every: n, once:
bool}`, `low_hp {below, do: effect}` (once a battle), `survive {pct}` (once: stay at that share
of max HP, 0 = 1 HP), `cost {school, add}`, `cd {school, add}`, `next_cost {school, add}`, `chip
{on: "crit"|<school>, add}`, `status_turns {on: "debuff"|"buff"|"self_debuff", add}`,
`status_chance {add}`, `vs_broken {pct}`, `vs_status {id, pct}`, `first_hit {pct}`, `combo_same
{pct, max}`, `combo_alt {pct}`, `ramp {pct, max}`, `first_turn`, `bounce`, `reward {what:
"ore"|"xp"|"luck", pct}`, and for foes `adapt` (takes on resistance to the school that last hit
it) and `quicken {pct, max}` (faster after each of its actions).

--------------------------------------------------------------------------------------------------

## 7. Gear, runes, relics, items, companions

### 7.1 Gear (`RpgGear`): the game's own 124 items get battle stats

Nothing in `game/items.gd` changes. `RpgGear.of(item_id, plus = 0) -> {"id", "lines": [{"k",
"v"}], "unique": passive dict or null, "set": id or ""}` or null for an unknown id; generated from
the item's slot, rarity, discipline tag, visual kind and id prefix, kept in a table by id (so
`Items.restrict_to` in tests does no harm). `RpgGear.fx(build_gear, plus, runes) -> [passive
effects]` turns a worn kit into effects (lines, uniques, set bonuses, runes).

The Realm has its **own gear choice** per build (`builds[i].gear`, first filled from the Armory's
loadout), so looks in the Armory and stats in the Realm never fight; the hero in the Realm is
drawn in the Realm's gear. Only owned items (`state.items`) can be worn.

- Line kinds (`k`): `atk_push`, `atk_pull`, `atk_legs`, `atk_speed`, `atk_grip`, `atk_mind`,
  `atk_all`, `armor`, `hp`, `spd` (a fraction), `crit` (a fraction), `res`, `en_max`,
  `gauge_rate`, `heal_pct`, `luck`.
- Main line by slot: head `armor`; face `crit` or `atk_mind`; body `hp` and `armor`; hands attack
  of its school; legs `atk_legs` or `hp`; feet `spd`; back attack (the weapon slot: the biggest
  number); accessory `crit` / `res` / `gauge_rate`; aura `gauge_rate` and `atk_all`.
- School by theme: lift -> push / pull / legs by slot and kind (gloves and wraps push or pull, belt
  and sleeves legs); climb -> grip; run -> speed; ride -> hp and `en_max`; `read_*`, wizard hat,
  glasses -> mind; `bounty_*` -> luck and all-round; shop kinds by what they look like.
- Budget: a full kit of commons at +0 gives the favoured school about attack 5, armour 3, HP 20.
  Rarity x1.0 / 1.12 / 1.25 / 1.4 / 1.6. Rare and up have a second line; each of the 30 epic and
  legendary items has a **unique** (a named passive of its own).
- **Upgrades**: +1 to +10, each adds 50% of every line's base (+10 = x6; percentages x3 at most);
  cost in ore `30 * 1.2^k` (k = the current plus) times rarity x1 / 1.2 / 1.5 / 2 / 3. No failure.
  `saved.rpg.plus = {item id: n}`.
- **Runes**: battle loot to socket, one per item. `{"id" (unique), "k", "v", "rarity"}`, rolled
  by tier from bosses, elites, Spire floors and gold chests; `saved.rpg.runes = [rune]`,
  `saved.rpg.socket = {item id: rune id}`. A rune can be moved freely; scrapped for ore.
- **Sets** (2 and 4 pieces): Iron (lift), Crag (climb), Road (run), Wheel (ride), Hunter
  (bounty), Scholar (reading and wizardry), Showtime (the shop's costumes).

### 7.2 Relics (`RpgRelics`)

RPG-only finds: `{"id", "name", "rarity", "icon", "text", "fx": [passive effects]}`, 24 of them.
Slots: 1, a second at fighter level 8, a third at 30. From elites, bosses, caches, star chests,
the rival. A duplicate becomes ore (`RpgDefs.DUP_ORE` by rarity).

### 7.3 Items (`RpgItems`; the belt: 2 slots, 3 at fighter level 6)

Protein Shake (heal 35%) · Mega Shake (heal 70%) · Electrolytes (+4 energy) · Smelling Salts
(cleanse all, Pumped 2) · Chalk Ball (Focus x2) · Energy Gel (Hasted 3) · Ice Pack (Shield 25%,
removes Burn and Bleed) · Pre-Workout (gauge +40). `{"id", "name", "icon", "text", "fx":
[effects], "price"}`; prices 25 to 70 ore at the camp shop.

### 7.4 Companions (`RpgPets`: all 16 pets, ids as in `Pets`)

`{"id", "auto": {"name", "kind": "attack"|"support", "power", "school", "fx", "every"},
"command": {"name", "charge", "power", "target", "school", "fx", "text"}, "passive": [passive
effects]}`. Themes: Gloop the slime (slows) · Rep the bulldog (bites, Exposed) · Crimpy the gecko
(chips guard) · Coach the pigeon (energy, haste) · Pedals the hamster (gauge, energy) · Sprout
(heals, cleanse) · Tonnage the ox (heavy hits, an all-foes stomp) · Cliff the goat (stuns) · Zoom
the greyhound (an extra hero turn) · Draft the falcon (Exposed on all) · Pebble the golemling
(shields) · Steady the tortoise (Braced, a big shield) · Deload the cat (weakens, dispels) ·
Ember the phoenix (burns; `survive` at 30%) · Titan Jr. the dragon (fire on all) · Page the owl
(insight, Marked).

--------------------------------------------------------------------------------------------------

## 8. The world (`RpgWorld`, `RpgFoes`)

### 8.1 Regions

Eight regions of ten stages. Stage s of region r: `n = 10 (r - 1) + (s - 1)`.

| r | id | name | teaches | boss |
|---|---|---|---|---|
| 1 | rustyard | The Rustyard | weaknesses and the guard break | Old Iron-Jaw, a locker that bites |
| 2 | greenmile | The Greenmile | speed, the timeline, slows | The Pacer, faster every turn |
| 3 | chalk | Chalk Cliffs | heavy guards, breakers | Skyhook, the cliff drake |
| 4 | stacks | The Stacks | debuffs, cleansing, interrupts | The Unread, a wraith of dust and ink |
| 5 | ironworks | The Ironworks | wind-up hits, Guard | Foreman Slag |
| 6 | marsh | Mirror Marsh | healers and target order, bleed | The Knot |
| 7 | stormspine | Stormspine Ridge | stuns, countdowns, mixed packs | Thunderhead |
| 8 | titans_rest | Titan's Rest | everything | The Hollow Titan, three phases, each weak to other schools |

A region's stages: 1 one or two foes (r1s1 is one Dust Bunny: the taught fight); 2 to 4 packs of
two or three, each new foe met on its own first; 5 the **elite**; 6 a **cache** (no fight: pick
one of three finds); 7 and 9 packs of three; 8 two waves; 10 the **boss** (with adds). A region
opens when the boss before it falls. Every stage has a line of story (`text`).

### 8.2 A stage

`{"id" ("r3s5"), "region", "s", "n", "name", "text", "kind": "battle"|"elite"|"cache"|"boss",
"waves": [[{"foe", "n"}, ...], ...], "stars": [objective x3], "par": int, "first": {rewards},
"rec": power}`. A wave entry may also carry `"weak"`, `"resist"`, `"start"` (statuses) for the
hunt, the rival and echoes; `setup.rules` (a list of rule ids, 8.4) changes a whole battle.

Stars: objective = `{"k": "win"|"turns"|"break"|"no_items"|"hp_half"|"no_guard"|"schools3"|
"no_big_hit", "v"}`; the first is always win, the second always turns (v = `par`: 6 a wave until
the balance step sets 1.3 x the simulator's median), the third one of the rest.
`RpgWorld.stars(stage, summary) -> [bool, bool, bool]`. A cache has no stars. Star chests per
region at 8, 16 and 24 stars (27 to be had).

Rewards (`RpgLoot.rewards(stage, summary, rpg, level, boosts, seed) -> {"xp", "ore", "items":
[{id, n}], "runes": [rune], "relic": id or "", "scroll": id or "", "first": bool}`): fighter XP
`10 * 1.2^(n/10)` per regular foe (elite x3, boss x10), ore `6 * 1.15^(n/10)` per regular foe
(same factors), an item on 20% of regular wins (elite 75%, boss 100%). The first win adds the
stage's `first`. A repeat win pays the same XP and ore again, never the `first`; XP is scaled by
`clamp(1 - 0.2 * (tier_of_level(level) - stage tier - 1), 0.2, 1)`. No daily limits.
`RpgSave.finish(rpg, what, rewards, summary, today) -> rpg`: stars OR-ed with the old ones,
`wins + 1`, `best` the fewest turns, loot added, `seen` merged.

### 8.3 Foes (`RpgFoes`)

```
{"id", "name", "region", "role", "weak": [2 attack schools], "resist": [0 or 1],
 "guard": int or null (the role's), "moves": [foe move ids], "pattern": [foe move ids in order],
 "rules": [{"if": "hp_below"|"ally_hurt"|"turn_mod"|"alone"|"hero_has"|"self_lacks", "v", "use": move id, "once": bool}],
 "traits": [passive effects],
 "phases": [{"at": hp share, "say", "pattern", "weak", "resist", "summon": [foe ids], "fx": [effects on self]}],
 "boss": bool, "elite": bool, "text"}
```
Foe moves (`RpgFoes.move(id)`): `{"id", "name", "kind": "attack"|"multi"|"heavy"|"debuff"|"buff"|
"heal"|"shield"|"summon"|"drain"|"bomb", "power", "hits", "windup": 0|1, "count": int (a bomb's
countdown), "rank", "target": "hero"|"self"|"ally"|"allies", "fx": [effects], "foes": [ids for a
summon], "icon" (an intent icon), "text"}`. A pattern's mean power is about 1.0 and no telegraphed
hit passes 35% of the reference hero's HP. A `windup` 1 move shows "charging" for one of the
foe's turns, then hits (interrupt, stun and break cancel it).

`RpgFoes.make(id, n, pack_size, opts) -> unit` applies the role and the solved numbers.
`RpgFoes.all()`, `by_id(id)`.

The 56 foes (ids fixed; the look of each is `FoeSprites`' business, keyed by the same id):

| region | regular (role) | elite | boss |
|---|---|---|---|
| rustyard | dust_bunny (swarm), rust_rat (skirmisher), squeaky_plate (tank), loose_collar (caster: Weakened), moldy_towel (healer) | bent_bar | old_iron_jaw |
| greenmile | burr (swarm), briar_fox (skirmisher: hastes itself), mud_slinger (caster: Slowed), stag_beetle (brute), mile_marker (bomb) | the_hill | the_pacer (quicken) |
| chalk | pebbling (swarm), cliff_bat (skirmisher), scree_golem (tank, guard 6), chalk_wisp (caster: Exposed), rope_snake (brute: Bleed) | overhang | skyhook |
| stacks | bookworm (swarm), ink_blot (caster: Burn), dust_jacket (healer: shields others), paper_knight (tank), overdue_notice (bomb) | the_index | the_unread |
| ironworks | rivet_mite (swarm), slag_imp (skirmisher: Burn), anvil_back (tank: Counter), bellows (caster: Pumped on allies), molten_barbell (brute: wind-ups) | press_golem | foreman_slag |
| marsh | leech (skirmisher: drain), bog_hopper (swarm), reed_wraith (caster: Bleed), mud_mender (healer), mirror_shade (brute: adapt) | knotroot | the_knot |
| stormspine | static_mote (swarm: Stun at low odds), gale_hawk (skirmisher), rime_goat (brute: Slowed), thunder_drum (caster: hastes allies), storm_eye (caster: wind-ups) | cairn_giant | thunderhead |
| titans_rest | stone_acolyte (healer), echo_knight (tank), relic_guard (brute), void_moth (skirmisher: drains energy), titan_shard (bomb) | the_gatekeeper | the_hollow_titan |

Weaknesses (the foe builder assigns them): two per foe; in every region each of the six attack
schools is a weakness of at least one regular foe; each region leans on two (rustyard push and
legs, greenmile speed and pull, chalk grip and pull, stacks mind and speed, ironworks legs and
push, marsh mind and grip, stormspine and titans_rest spread evenly); at most one resist.

### 8.4 Beyond the road

- **Daily hunt** (`RpgWorld.hunt(date, rpg, boosts) -> stage`): one pack a day at `best cleared n
  + 2` (best = the highest `n` won; 0 before any), with one rule from `RpgWorld.RULES` (foes
  start Hasted / guard +2 / no items / foes start Braced / the hero starts with 1 energy / an
  extra wave) and weaknesses set to the schools of today's boosts (none: seeded by the date). The
  first win of the day lets the player pick one of three prizes (ore, an item stack, a rune).
  This is where yesterday's workout decides a fight.
- **Weekly rival** (`RpgWorld.rival(state, rpg) -> stage or null`): the main game's bounty
  monster of the week, read only (`state.weekly.current`: its `monster` id gives the sprite and
  name, its `weakPart` the weak school: legs -> legs; chest, shoulders -> push; back -> pull;
  arms -> push and pull; core -> legs), as a boss at `best n + 5`. One win a week pays a relic or
  a rune and ore.
- **The Spire** (opens after region 2): floor f has `n = 10 + 2 f` up to floor 35, then +0.5 a
  floor; a fixed pack seeded by the floor, an elite every fifth floor, a boss every tenth; no
  end. Floors are climbed in order; each pays once; `saved.rpg.spire.best`.
- **Echo regions** (after region 8): each region again at `n = 80 + 3 (r - 1) + 0.3 (s - 1)` with
  one rule from `RULES`; stage ids `e3s5`.

--------------------------------------------------------------------------------------------------

## 9. Progress and economy

- **Fighter level** 1 to 60 from fighter XP: `xp_to_next(L) = round((6 + 0.15 L) * 10 *
  1.2^((L-1)/5))`; `RpgDefs.level_of(xp) -> {"lvl", "into", "need"}`; `tier_of_level(L) =
  clampi(floori((L + 4) / 5.0), 1, 12)`. A level: +8 HP, +3% offence, +1 skill point. Unlocks
  (`RpgDefs.UNLOCKS`): passive slots at 3, 10, 20; belt slot 3 at 6; relic slot 2 at 8, 3 at 30;
  a fifth move slot at 20; the Spire after region 2's boss.
- **Ore** is the only currency: gear upgrades, items at the camp shop. The main game's coins are
  never read or touched.
- **Stars** open star chests. **Skill points** as in section 6.

--------------------------------------------------------------------------------------------------

## 10. Screens (all in `ui/rpg/`; colours from Pal, icons from Icons, no emoji)

### 10.0 The first visit (`saved.rpg.opened` false)

1. The twelve stats count up one after another, each with its line from the log ("Legs 47 ·
   Best: Squat 230 lb x 5").
2. "Your training has already earned N skill points." A key opens Skills on the board of the
   hero's best stat.
3. The first fight is fixed: r1s1, one Dust Bunny with its weakness shown, a short line under the
   keys at each step (hit its weak school, watch the guard, break it). Then the map.

### 10.1 The Realm tab (`RealmScreen`, `ui/rpg/realm.gd`, a UiScreen that rebuilds on
`App.changed` and `App.rpg_changed`)

1. **Banner**: the hero on a `Stage` in Realm gear with the companion; "Fighter Lv 7", an XP bar,
   Power, ore, skill points to spend.
2. **Notices**: "Continue the battle"; a training chest to open; "A skill can be learned".
3. **Boosts today**: a chip per boost (icon, name, the effect, "today" or "until tomorrow"); a
   tap says where it came from. None: what would earn one.
4. **Sub-tabs** (`RpgUi.page`, a static var): Map · Hero · Moves · Skills · Gear. A sub-tab
   shows a dot only when something can be done there.

Each page is `static func fill(box: VBoxContainer, screen) -> void` in its own file.

- **Map** (`realm_map.gd`): the daily hunt and the weekly rival rows; the region (chips for the
  opened ones) as a path of ten stage nodes with stars; the Spire row; star chests. A node opens
  the **prep sheet**: the foes (sprite, role, known weaknesses, "?" otherwise), recommended power
  against the hero's, the stars, the build in short, Fight.
- **Hero** (`realm_hero.gd`): the six body stats around the hero, the six traits as bars, each
  with its value to one decimal, the change this week, progress to the next point; a tap opens
  "what it is made of" and "what raises it"; the fight numbers (HP, defence, speed, crit, dodge,
  energy); the boosts in full.
- **Moves** (`realm_moves.gd`): the build: move slots, ultimate, passives; under it every known
  move by school (colour, cost pips, cooldown, power, effect in words), then the unknown ones with
  what they need; tap to equip into a slot; the three saved builds.
- **Skills** (`realm_skills.gd`): board chips; the board as tiers of nodes (owned / can learn /
  needs points / needs "Legs 24 (you: 21)" / needs fighter level); learn; "Reset all (free)".
- **Gear** (`realm_gear.gd`): a paper doll of the nine slots, the relic slots, the companion, the
  belt; a slot opens its owned items with lines, rune, set and unique; upgrade with ore; runes;
  the camp shop.

### 10.2 The battle (`battle_view.gd`, class BattleView)

A full-column Control on `Kit.overlay_root` (opaque, STOP), not a UiScreen; nothing scrolls and no
key moves between turns:
top bar (stage, wave, turn, speed x1 / x2, flee) · the arena (region backdrop; one to three foes
each with name plate, HP bar, guard pips, up to three statuses, weakness icons and intent; the
hero and companion bottom left) · the timeline strip (next 7) · the hero plate (HP, energy pips,
gauge, statuses) · one line saying what just happened · the keys: moves two across (school colour
and icon, name, cost pips, cooldown, the damage it would do to the picked target, WEAK / RESIST),
then Strike · Guard · Item · Companion · Ultimate.
A tap on a foe picks the target (kept between turns); a tap on a move does it; a tap on a name
plate opens that unit's sheet (statuses in words, known weaknesses, its moves). Animations: the
hero's pose for the move's school (`RpgDefs.SCHOOL_POSE`: push strike, pull pull, legs kick,
speed strike, grip strike, mind / flow / grit cast; guard; hurt; a win flex) with a lunge, the
foe's flash and shake, rising damage numbers, a burst in the school's colour, `Sfx`, a buzz; x2
halves every wait; poses are shown at frame 0 and warmed at battle start.

A battle starts only through `RpgUi.fight(what)` (`what` = `{"kind": "stage"|"hunt"|"rival"|
"spire"|"echo", "id", ...}`) and ends through `RpgUi.finish(B, what)`, the one place that pays
rewards and commits.

**Result** (`battle_result.gd`): stars, the XP bar, level up, loot, "Next stage" / "Again" /
"Back".

Phone rules that bind every screen: keys at least 40 high with `Kit.fingers`; fixed-height
states; a state-independent `anchor_id` meta or text on every key; `Kit.clip` in rows; nothing
said only in a tooltip; metas for tests (pixel-font text is invisible to them); whole-number
sprite scales; looping decoration paused while `TouchScroll.scrolling`; no page wider than 412.

--------------------------------------------------------------------------------------------------

## 11. Architecture

### 11.0 Ids and accessors

An id is the name in lower case, apostrophes dropped, every other run of non-alphanumerics an
underscore: `one_two`, `runners_high`, `old_iron_jaw`, `the_hollow_titan`. Pets keep their `Pets`
ids, items their `Items` ids. A board's id is its school. Every catalog class has `static func
all() -> Array` and `static func by_id(id: String)` (a Dictionary or null); never a static `get`.
Anything that takes an id skips one it does not know (a build may name gear no longer owned, a
pet, a move not learned, a rune that was scrapped): skipped, never deleted, shown as an empty
slot.

### 11.1 Files

Pure logic, `game/rpg/` (static classes, no autoload, usable from `--script` tests):

| file | class | job |
|---|---|---|
| rpg_defs.gd | RpgDefs | ids, names, icon names, every constant and formula |
| rpg_stats.gd | RpgStats | the sheet from the log (2) |
| rpg_boosts.gd | RpgBoosts | boosts and training chests (3) |
| rpg_moves.gd | RpgMoves | the move catalog (5) |
| rpg_passives.gd | RpgPassives | board passives (6) |
| rpg_skills.gd | RpgSkills | boards, nodes, points, `can_learn` |
| rpg_gear.gd | RpgGear | battle stats of the 124 items, sets, upgrades, runes |
| rpg_relics.gd | RpgRelics | relics |
| rpg_items.gd | RpgItems | belt items, the camp shop |
| rpg_pets.gd | RpgPets | companion kits |
| rpg_foes.gd | RpgFoes | foes, foe moves, `make` |
| rpg_world.gd | RpgWorld | regions, stages, stars, hunt, rival, spire, echoes, rules |
| rpg_loot.gd | RpgLoot | rewards, caches, star chests, rune rolls |
| rpg_hero.gd | RpgHero | `build`, `reference`, `power` |
| rpg_battle.gd | RpgBattle | the battle engine and the validators |
| rpg_ai.gd | RpgAi | foe intent choice; hero policies (auto-battle, the simulator) |
| rpg_save.gd | RpgSave | `empty`, `parse`, `first_open`, every change to `saved.rpg` as a pure function |

`tests/rpg_sim.gd` (no class_name; loaded by path) runs many battles; `tools/rpg_balance.gd` is
the full sweep. Screens, `ui/rpg/`: `rpg_ui.gd` (RpgUi), `realm.gd` (RealmScreen), `realm_map.gd`
(RealmMap), `realm_hero.gd` (RealmHero), `realm_moves.gd` (RealmMoves), `realm_skills.gd`
(RealmSkills), `realm_gear.gd` (RealmGear), `battle_view.gd` (BattleView), `battle_widgets.gd`
(BattleWidgets), `battle_result.gd` (BattleResult). Art, `avatar/`: `foe_sprites.gd`
(FoeSprites), `foe_view.gd` (FoeView), `realm_scenes.gd` (RealmScenes); new poses in
`hero_figure.gd` (the game's look only); new icons in `ui/icons.gd`.

Every one of these files exists as a stub with its `class_name` before the builders start, and
the project has been imported: **no builder runs `--import`**.

### 11.2 `saved.rpg` (`RpgSave.parse` rebuilds it key by key with defaults)

```
{"v": 1, "opened": bool,
 "xp": int, "ore": int,
 "nodes": {node id: true},
 "builds": [build, build, build], "build": 0,
    # build = {"name", "moves": [5 move ids, "" = empty], "ult": id or "", "passives": [3 ids or ""],
    #          "gear": {slot: item id}, "relics": [3 ids or ""], "pet": pet id or "", "belt": [3 item ids or ""]}
 "plus": {item id: int}, "runes": [rune], "socket": {item id: rune id},
 "relics": {relic id: true}, "scrolls": {move id: true}, "items": {item id: count},
 "stages": {stage id: {"stars": [bool, bool, bool], "wins": int, "best": int}},
 "starChests": {"<region>:<8|16|24>": true}, "caches": {stage id: true},
 "seen": {key: [schools]},
 "chests": {date: int}, "hunt": {"date", "won": bool}, "rival": {"week", "won": bool},
 "spire": {"best": int}}
```
Slots beyond what the fighter level opens are simply not used. `App` gets: `"rpg":
RpgSave.empty()` in `empty_saved()`; `out.rpg = RpgSave.parse(o.get("rpg"))` in `parse_saved`;
`signal rpg_changed`; `func rpg() -> Dictionary`; `func set_rpg(d: Dictionary) -> void` (stores,
stamps `updatedAt`, `_write()`, emits `rpg_changed` ONLY: no replay, and none of the listeners of
`changed` wake); "battle" in the two draft-clearing loops. `Derive.derive` is given an explicit
input, so `saved.rpg` cannot reach the rules. (`SaveMerge` merges the dictionaries key by key;
numbers and arrays changed on both sides take the newer side whole. Sync is off.)

`RpgSave.first_open(rpg, loadout, active_pet) -> rpg`: copies the Armory's loadout and pet into
the three builds; `RpgUi` calls it once at the end of the first visit and sets `opened`.

### 11.3 A unit (a JSON-safe Dictionary)

```
{"id": "hero"|"pet"|"f0".., "side": "hero"|"foe", "name",
 "hp", "hp_max", "def", "spd", "res", "tec", "crit", "dodge",
 "at": float, "alive": bool, "statuses": [{"id", "turns", "stacks", "amount", "by"}], "stun_guard": int,
 # hero
 "s": {stat id: effective float}, "w": {school: flat attack}, "lvl", "en", "en_max", "gauge",
 "moves": [ids], "ult": id, "cds": {move id: turns}, "fx": [passive effects in force],
 "belt": [{"id", "n", "used"}], "guarding": bool, "flags": {},
 # foe
 "foe": foe id, "role", "atk", "weak", "resist", "shown": bool, "guard", "guard_max", "broken": bool,
 "intent": {"move", "kind", "dmg", "hits", "windup": bool, "count", "icon", "text"}, "pi": int,
 "boss": bool, "elite": bool, "phase": int, "fx": [traits],
 # pet
 "pet": pet id, "charge", "charge_max"}
```

### 11.4 The engine (`RpgBattle`, all static; `B` is a JSON-safe Dictionary)

```
start(setup) -> B          setup = {"hero": unit, "pet": pet unit or null, "waves": [[{"foe", "n", ...}]...],
                                    "seed": int, "what": {...}, "rules": [ids], "known": {key: [schools]}, "day": date}
options(B) -> Dictionary   {"moves": [{"id", "ok", "why", "cost", "cd"}], "strike": bool, "guard": bool,
                            "ult": {"id", "ok"}, "items": [{"id", "n", "ok"}], "pet": {"ok", "name", "charge", "max"},
                            "targets": [unit ids]}
preview(B, action) -> Dictionary   {"lo", "hi", "weak", "resist", "chip", "kills"}
act(B, action) -> Array    applies the hero's action, then runs foes / pet / ticks until the hero must
                           choose again or the battle ends; returns the events in order
timeline(B, count) -> Array of unit ids
unit(B, id) -> Dictionary or null; foes(B) -> Array (living)
over(B) -> bool; won(B) -> bool
summary(B) -> {"win", "turns", "dealt", "taken", "breaks", "items", "guards", "schools": [..],
               "worst_share", "hp_share", "learned": {key: [schools]}, "used": {item id: n}}
```
Actions: `{"t": "move", "id", "target"}`, `{"t": "strike", "target"}`, `{"t": "guard"}`, `{"t":
"item", "id"}`, `{"t": "ult", "target"}`, `{"t": "pet", "target"}` (free), `{"t": "flee"}`.
Events (Dictionaries with `"t"`): `turn {who}`, `act {who, kind, id, name, school, target}`, `dmg
{src, dst, amount, crit, weak, resist, chip, hp, guard, school, absorbed}`, `miss {src, dst}`,
`heal {dst, amount, hp}`, `status {dst, id, on, turns, stacks, resisted}`, `tick {dst, id, amount,
hp}`, `break {dst}`, `recover {dst}`, `ko {dst}`, `energy {v}`, `gauge {v}`, `intent {who,
intent}`, `learn {key, school}`, `phase {who, say}`, `summon {units}`, `wave {n, units}`, `say
{text}`, `end {win}`.

**JSON-safety rules** (the resumed battle must be the same battle): `float()` on both sides of
every division; `int()` on everything used as an index or with `%`; never iterate a Dictionary
where the order matters (gear by `TT.SLOTS`, stats by `RpgDefs.STATS`); no INF / NAN, no Packed
arrays, Vectors or int keys inside `B`; randomness only as `var st = Rng.Stream.new(int(B.rng));
var r = st.next(); B.rng = st._s` (never a kept Stream). `rpg_battle_test` plays each seeded
fight twice, once passing `B` through `TTUtil.normalize_json(JSON.parse_string(JSON.stringify(B)))`
after every `act`: the events must be identical.

`RpgHero.build(sheet, boosts, rpg, owned) -> unit` (`owned` = `{"items": state.items, "pets":
state.pets}`); `RpgHero.pet_unit(rpg, owned, level) -> unit or null`; `RpgHero.reference(t,
archetype = "balanced") -> unit` (archetypes and their four moves in `RpgHero.ARCHETYPES`:
balanced, push, pull, legs, speed, grip, mind); `RpgHero.numbers(unit) -> Dictionary` for the
Hero page.

### 11.5 The facade (`RpgUi`: the only RPG code that touches `App`)

`RpgUi.input()`, `sheet()`, `boosts()`, `hero()`, `level()` (cached; the cache is dropped on
`App.changed` and kept across `App.rpg_changed`; it fills only when a Realm screen asks),
`save()` (= `App.rpg()`), `commit(rpg)` (= `App.set_rpg`), `fight(what)`, `finish(B, what)`, and
the shared widgets: `color(school_or_name) -> Color` (a `match`: push `Pal.PUSH`, pull `Pal.PULL`,
legs `Pal.LEGS`, speed `Pal.RUN`, grip `Pal.CLIMB`, mind `Pal.READ`, flow `Pal.PT`, grit
`Pal.GRIT`, realm `Pal.REALM`, plain `Pal.MUTED`), `school_icon(id)`, `stat_chip`, `move_card`,
`status_icon`, `ore_pill`, `foe_tile`, `rarity_color`.

### 11.6 Changes to the main game (the whole list)

1. **The campaign off the screens.** `game/campaign.gd` gets `const ON_SCREEN = false` and
   `static func is_goal_key(key) -> bool` (the 8 trophy ids `boss_first`, `zone_1`..`zone_6`,
   `damage_100k`; the 6 boss items; `p:golemling`). The rules still run, so nothing earned is
   lost and parity is untouched. With it false:
   - Hero tab: no boss row (the Adventure section keeps the bounty row; its link goes to the same
     sub-tab); the companion's bubble gets a stand-in boss `{"name": "", "hp": 1, "weak": null}`
     with `bossHpLeft` 1.
   - Adventure tab: the sub-tab id stays "campaign", its label is "Bounty", it draws the bounty
     card and its record only.
   - Results reel: no boss cards (filtered inside the overlay only; the events stay); the coin
     tooltip loses "bosses".
   - Recap: no "Defeated ..." lines, no "Boss slayer" headline, no flex for a boss.
   - Journey: Story's "Bosses" chip becomes "Bounties" (kind bounty only), boss moments are left
     out; the damage fact is dropped.
   - Almost there (`App.next_goals`): campaign goal keys are skipped.
   - The trophy cabinet, the Armory and the pets keep the campaign's trophies, gear and Pebble
     (they still unlock from training); an unearned one's hint reads "A campaign reward (the
     campaign is resting)".
2. `main.gd`: a sixth tab, `{"id": "realm", "label": "Realm", "icon": "realm"}`, LAST (Hero,
   Adventure, Log, Journey, Armory, Realm). The Log key does not move: `size_flags_stretch_ratio`
   3 for home, adventure and log, 2 for journey, armory and realm (86.4 and 57.6 px of 432; the
   minimum width of the right three is 48). The Realm tab shows a dot (no number) while a
   training chest waits (`RpgBoosts.chest_waiting`).
3. `ui/pal.gd`: `TAB_ACCENT.realm`, statics `PUSH`, `PULL`, `LEGS`, `GRIT`, `REALM`.
4. `app/app.gd`: the additions of 11.2.
5. `ui/icons.gd`: new icons (`RpgDefs.ICONS`). `avatar/hero_figure.gd`: new poses, the game's
   look only.

--------------------------------------------------------------------------------------------------

## 12. Art (procedural, the game's own look; the classic branch and parity_art stay identical)

- **Foes** (`FoeSprites`): char-row sprites like `BossSprites.BASE` / `PetSprites` with two
  frames, 14 to 22 pixels, about 22 new shapes with palettes for the 40 regular foes; elites and
  bosses reuse the twelve boss shapes (`BossSprites.BASE`) with new palettes, shown bigger.
  `FoeSprites.LOOKS[foe id]`, `buffer(foe_id, frame) -> Pix`, `texture(foe_id, frame)`, `size`,
  `hovers`; an unknown id draws a plain blob; ids starting `wk_` (the rival) go through
  `Art.boss_texture`. `FoeView` (a Control): `setup(foe_id, px)`, bob or hover, `hit()`,
  `faint()`, `set_dim`, `silhouette`.
- **Backdrops** (`RealmScenes.draw(p: Pix, region_id)`, `texture(region_id)`): 110 x 60, shown x4
  = 440 wide; sky, far shapes, ground, two or three props in the region's palette; the Spire and
  the hunt have their own.
- **Hero poses** in `HeroFigure.metrics` (game look only): "strike", "kick", "guard", "cast",
  "hurt". Arms and legs only; wrists within 16 px of the shoulder; both ankles on the floor
  line; lunges and recoil are tweens of the view. `tests/figure_test.gd`'s pose lists gain them.
- **Icons** (`RpgDefs.ICONS`, 16 x 16 like the rest): schools `sch_push sch_pull sch_legs
  sch_speed sch_grip sch_mind sch_flow sch_grit`; stats `st_chest st_shoulders st_arms st_back
  st_core st_legs st_endurance`; statuses `fx_pumped fx_weakened fx_braced fx_exposed fx_hasted
  fx_slowed fx_burn fx_bleed fx_stun fx_regen fx_shield fx_focus fx_evade fx_counter fx_steady
  fx_marked fx_insight fx_broken`; intents `in_attack in_heavy in_multi in_debuff in_buff in_heal
  in_shield in_summon in_bomb in_stunned in_drain in_charge`; keys `realm ore energy gauge
  guard_pip power sp strike guard flee belt relic rune scroll hunt spire rival chest_wood
  chest_iron chest_gold star_on star_off`; items `it_shake it_mega it_electro it_salts it_chalk
  it_gel it_ice it_pre`; relics `rl_ring rl_bookmark rl_chain rl_tooth rl_band rl_whistle rl_tape
  rl_feather rl_bell rl_hourglass rl_horn rl_anvil`. Content may use these and the 86 existing
  names only.

--------------------------------------------------------------------------------------------------

## 13. Tests

Headless suites (`extends SceneTree`, `TINY_TITAN_DATA` = a throwaway folder of the builder's own,
under `timeout` from Bash), each printing `NAME: passed/total passed`:
`rpg_stats_test` · `rpg_boosts_test` · `rpg_battle_test` (rules, every effect, mod and passive
kind, the JSON round trip) · `rpg_content_test` (every move, passive, node, gear row, rune roll,
relic, item, pet, foe, stage, hunt, spire floor is well formed, ids resolve, effects pass the
validators, budgets hold, icons exist) · `rpg_save_test` (parse keeps a save, every transition, a
backup round trip through `App.parse_saved`) · `rpg_sim_test` (20 seeds; stages 1, 5 and 10 of
each region; under 60 s) · `rpg_art_test` (every sprite, scene, pose and icon draws; contact
sheets saved as PNG into the scratch folder for the builder to look at) · `rpg_ui_test` (every
page built headless in a 440 box for an empty, a mid and a late save, with and without
`Kit.fingers`; nothing wider than 412; one whole fight through BattleView's handlers; no ERROR).
The existing 30 suites and the three parity suites keep passing.

Balance bands (`tools/rpg_balance.gd`, 200 seeds, the heuristic policy): the 4.1 targets for the
reference hero in every region; every boss won 55 to 85% at reference power, 92%+ at x1.2, under
25% at x0.7; the random policy under a third of the heuristic's boss win rate; no one-move loop
(X when affordable, else Strike) over 85% of the heuristic's; no move over 60% of all actions for
any archetype; a "new log" hero (every stat 15, starter build, level 1) wins r1s1 to r1s4 at
90%+; an empty-log hero (every stat 1) wins r1s1 to r1s3 at 90%+; a "lopsided" hero (body 45,
speed 30, the rest 25) at reference level and gear sits inside the bands of regions 4 to 6.

Walkthroughs (they open a window: only when the user is off the PC): `realm` (the first visit,
every page) and `battle` (a whole fight by real taps, the result, resuming), both also with
`--fingers`.

--------------------------------------------------------------------------------------------------

## 14. Build order and who owns which file

0. **Ground** (done before the builders): `rpg_defs.gd` complete; `rpg_save.gd` with `empty`,
   `parse`, `first_open`; a stub for every other file; the project imported.
1. **Foundation** (in parallel, disjoint files):
   A. engine: `rpg_battle.gd`, `rpg_ai.gd`, `rpg_hero.gd`, and the first entries of
      `rpg_moves.gd`, `rpg_passives.gd`, `rpg_foes.gd`, `rpg_pets.gd`, `rpg_items.gd` it needs
      for `tests/rpg_battle_test.gd`;
   B. stats and boosts: `rpg_stats.gd`, `rpg_boosts.gd`, their tests;
   C. foe art: `foe_sprites.gd`, `foe_view.gd`, `realm_scenes.gd`, `tests/rpg_art_test.gd`;
   D. icons and poses: `ui/icons.gd`, `avatar/hero_figure.gd`, `tests/figure_test.gd`,
      `tests/rpg_icons_test.gd`;
   E. shell: the campaign off the screens, the sixth tab, Pal, App, a first `ui/rpg/realm.gd`,
      the walkthroughs and tests that looked at the campaign.
2. **Content** (in parallel): moves + passives + skills; gear + runes + relics + items + pets;
   foes + world + loot + the save's transitions. Then `rpg_content_test`.
3. **Balance**: `tests/rpg_sim.gd`, `tools/rpg_balance.gd`, tuning in `RpgDefs` and the catalogs
   until the bands hold; the stat curves calibrated against the real log on a scratch copy.
4. **Screens**: `rpg_ui.gd` first, then the hub and Hero page, Map and prep, Moves and Skills,
   Gear, Battle and Result in parallel; `rpg_ui_test`.
5. **Review, fixes, walkthroughs, the phone build.**

--------------------------------------------------------------------------------------------------

## 15. Rules for every builder

- CLAUDE.md's rules hold: no `:=`; a float operand when dividing; `.get()` for optional keys;
  stored callables through `.call()`; never `str(float)` on screen (`Fmt.*`, `TTUtil.num_str`);
  colours only from `Pal`; no emoji; `texture_filter = NEAREST` on anything pixel-styled.
- NEVER run anything against the real save: every Godot run sets `TINY_TITAN_DATA` to a throwaway
  folder of your own. Never open a window: tests run `--headless`; no walkthroughs, no editor, no
  browser. Never run `--import`. Never kill a Godot process you did not start.
- Only touch the files you own. Need something from another file: say so in your report.
- Nothing may change a rule, a number or a screen of the main game beyond 11.6.
- Tests use made-up names and numbers, never anything from the user's own log.
- No JSON or other data files in the project (the web export drops them and a stray file with
  the user's data must never be packed): catalogs are GDScript.
