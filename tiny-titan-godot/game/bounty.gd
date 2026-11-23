class_name Bounty
extends RefCounted
## The weekly bounty (added after the port): a small boss every Monday-week,
## sized from the player's own recent training, so there is always something
## to chase between the campaign bosses.
##
## It is a pure function of the log, worked out after the replay:
##   - HP = 90% of the average session XP of the (up to) four weeks before,
##     never under FLOOR_HP. A new player's first week is FLOOR_HP.
##   - Every point of session XP that week is a point of damage, x1.5 for the
##     discipline the monster is weak to (one the player actually trains).
##   - Beat it before Sunday night for coins; 150% of its HP "crushes" it for
##     more. Wins in a row add a streak bonus. Nothing is lost by missing one.
##
## `settle` fills `state.weekly`:
##   {wins, crushes, streak (wins in a row, a week still in progress does not
##    break it), bestStreak, coins (all bounty coins earned),
##    history: [Record] oldest first, current: Record (this week, never null)}
## Record: {week (Monday key), monster (id), hp, damage, weak (discipline or null),
##          defeated, crushed, at (date of the winning session or null),
##          sessionId, coins (paid for this win, 0 otherwise), streak (after it)}
##
## Gear and trophies that ask for bounty wins read `Bounty.wins(s)` etc.; they
## unlock on the day of the win. The parity tests drop `weekly` before comparing.

const FLOOR_HP = 500
const TARGET_FACTOR = 0.9
const LOOKBACK_WEEKS = 4
const WEAK_LOOKBACK_WEEKS = 8
const WEAK_MULT = 1.5
const CRUSH_MULT = 1.5
const COINS_WIN = 100
const COINS_CRUSH = 50
const COINS_STREAK_STEP = 10
const COINS_STREAK_MAX = 50
## Muscle groups a monster can be weak to, and the body parts of each. A
## session with WEAK_SETS working sets or more of the group hits for WEAK_MULT
## (not on top of the weak discipline: the best of the two).
const MUSCLE_GROUPS = {"legs": ["quads", "hamstrings", "glutes", "calves"], "back": ["back"], "chest": ["chest"],
	"shoulders": ["shoulders"], "arms": ["biceps", "triceps", "forearms"], "core": ["core"]}
const MUSCLE_NAMES = {"legs": "Legs", "back": "Back", "chest": "Chest", "shoulders": "Shoulders", "arms": "Arms", "core": "Core"}
const WEAK_SETS = 3


## The muscle group a week's monster is weak to.
static func weak_part_for(wk: String) -> String:
	var keys = MUSCLE_GROUPS.keys()
	return str(keys[Rng.hash_string("bounty-part:" + wk) % keys.size()])


## Working sets per muscle group in a lift session: {group: sets}.
static func muscles_of(session: Dictionary) -> Dictionary:
	var out = {}
	if str(session.get("discipline", "")) != "lift":
		return out
	for ex in session.get("exercises", []):
		var part = Missions.part_of(str(ex.get("name", "")))
		for g in MUSCLE_GROUPS:
			if MUSCLE_GROUPS[g].has(part):
				out[g] = int(out.get(g, 0)) + LiftTrend.real_sets(ex.get("sets", [])).size()
	return out

## The monsters that turn up. Each id has a look in BossSprites.boss_looks().
const MONSTERS = [
	{"id": "wk_mimic", "name": "Monday Mimic", "epithet": "Looks like a rest day. Bites like a deadline."},
	{"id": "wk_bat", "name": "Skip-Day Bat", "epithet": "Hangs around whenever you plan to train."},
	{"id": "wk_eye", "name": "Doom-Scroll Eye", "epithet": "Just five more minutes of staring."},
	{"id": "wk_goblin", "name": "Snack Goblin", "epithet": "Guards the biscuit tin with its life."},
	{"id": "wk_wraith", "name": "Rain-Check Wraith", "epithet": "It will definitely come next week."},
	{"id": "wk_slime", "name": "Sofa Slime", "epithet": "Fills every gap between the cushions."},
	{"id": "wk_clock", "name": "Alarm Gremlin", "epithet": "Sets itself for p.m. on purpose."},
	{"id": "wk_golem", "name": "Stiff-Neck Golem", "epithet": "Slept funny. For a thousand years."},
	{"id": "wk_wyrm", "name": "Traffic Wyrm", "epithet": "Every light is red when it is near."},
	{"id": "wk_laundry", "name": "Laundry Mountain", "epithet": "Grows when you are not looking."},
	{"id": "wk_wheel", "name": "Wobbly Wheel", "epithet": "Never quite true. Never quite flat."},
	{"id": "wk_shade", "name": "Yesterday's You", "epithet": "Did less than you remember."},
	{"id": "wk_ogre", "name": "Overtime Ogre", "epithet": "One more email. Then one more."},
	{"id": "wk_wisp", "name": "Cold-Morning Wisp", "epithet": "Lives under the duvet."},
	{"id": "wk_blob", "name": "Leftover Blob", "epithet": "Third night in the fridge. Still confident."},
	{"id": "wk_imp", "name": "Meeting Imp", "epithet": "This could have been a workout."},
	{"id": "wk_couch_mimic", "name": "Couch Mimic", "epithet": "Ate the remote. And your motivation."},
	{"id": "wk_sock_bat", "name": "Lost-Sock Bat", "epithet": "Takes one. Always one."},
]

static var _by_id = null


## Monster by id (the first one for an unknown id).
static func monster(id) -> Dictionary:
	if _by_id == null:
		var map = {}
		for m in MONSTERS:
			map[m.id] = m
		_by_id = map
	return _by_id.get(id, MONSTERS[0])


static func _raw_pick(wk: String) -> int:
	return Rng.hash_string("bounty:" + wk) % MONSTERS.size()


## The monster of a week: seeded by the week, never the same two weeks running.
static func monster_for(wk: String) -> Dictionary:
	var i: int = _raw_pick(wk)
	if i == _raw_pick(Dates.add_weeks(wk, -1)):
		i = (i + 1) % MONSTERS.size()
	return MONSTERS[i]


## Coins for a win that makes it `streak` in a row.
static func coins_for(streak: int, crushed: bool) -> int:
	var bonus: int = mini(COINS_STREAK_MAX, COINS_STREAK_STEP * maxi(0, streak - 1))
	return COINS_WIN + bonus + (COINS_CRUSH if crushed else 0)


static func _round_to(n: float, step_size: int) -> int:
	return maxi(step_size, TTUtil.jsround(n / float(step_size)) * step_size)


## HP of a week's bounty from the session XP of the weeks before it.
## `weeks` is {monday key: {xp, ...}}, `first` the week of the first session.
static func hp_for(wk: String, first: String, weeks: Dictionary) -> int:
	var total: int = 0
	var n: int = 0
	var w: String = wk
	for k in range(LOOKBACK_WEEKS):
		w = Dates.add_weeks(w, -1)
		if w < first:
			break
		n += 1
		if weeks.has(w):
			total += int(weeks[w].xp)
	if n == 0:
		return FLOOR_HP
	return maxi(FLOOR_HP, _round_to(float(total) / float(n) * TARGET_FACTOR, 50))


## From this Monday on no monster is weak to a discipline kept in the
## Miscellaneous area (cycling: Misc.SIDE). A weakness reads as "do this for
## more damage", and cycling is no goal any more. The weeks before keep the
## weakness they had, so no past bounty changes.
const SIDE_OUT_FROM = "2026-11-23"

## The discipline a week's monster is weak to: one trained in the weeks before
## (else the first one trained that week, else none yet), picked by the week.
static func weak_for(wk: String, weeks: Dictionary):
	var pick_from: Array = TT.DISCIPLINES if wk < SIDE_OUT_FROM else Misc.MAIN
	var used: Dictionary = {}
	var w: String = wk
	for k in range(WEAK_LOOKBACK_WEEKS):
		w = Dates.add_weeks(w, -1)
		if weeks.has(w):
			for d in weeks[w].discs:
				used[d] = true
	var pool: Array = []
	for d in pick_from:
		if used.has(d):
			pool.append(d)
	if pool.is_empty():
		# The first of the disciplines trained that week (a misc activity is never a weakness).
		if weeks.has(wk):
			for x in weeks[wk].list:
				if pick_from.has(x.disc):
					return x.disc
		return null
	return pool[Rng.hash_string("bounty-weak:" + wk) % pool.size()]


static func _record(wk: String, first: String, weeks: Dictionary) -> Dictionary:
	var hp: int = hp_for(wk, first, weeks)
	var weak = weak_for(wk, weeks)
	var part = weak_part_for(wk)
	var rec = {
		"week": wk,
		"monster": monster_for(wk).id,
		"hp": hp,
		"damage": 0,
		"weak": weak,
		"weakPart": part,
		"defeated": false,
		"crushed": false,
		"at": null,
		"sessionId": null,
		"coins": 0,
		"streak": 0,
	}
	if weeks.has(wk):
		for x in weeks[wk].list:
			var hit = x.disc == weak or int(x.get("muscles", {}).get(part, 0)) >= WEAK_SETS
			rec.damage += TTUtil.jsround(float(x.xp) * (WEAK_MULT if hit else 1.0))
			if not rec.defeated and rec.damage >= hp:
				rec.defeated = true
				rec.at = x.date
				rec.sessionId = x.id
	rec.crushed = rec.defeated and float(rec.damage) >= float(hp) * CRUSH_MULT
	return rec


## {monday key: {xp, discs: {discipline: true}, list: [{date, t, id, disc, xp}] in date order}}
static func weeks_of(s: Dictionary, sessions: Array) -> Dictionary:
	var weeks: Dictionary = {}
	for x in sessions:
		if not s.sessionXp.has(x.id):
			continue
		var wk: String = Dates.week_key(str(x.date))
		if not weeks.has(wk):
			weeks[wk] = {"xp": 0, "discs": {}, "list": []}
		var xp: int = int(s.sessionXp[x.id])
		weeks[wk].xp += xp
		weeks[wk].discs[x.discipline] = true
		weeks[wk].list.append({"date": str(x.date), "t": x.createdAt, "id": x.id, "disc": x.discipline, "xp": xp, "muscles": muscles_of(x)})
	for wk in weeks:
		TTUtil.stable_sort(weeks[wk].list, func(a, b): return a.date < b.date or (a.date == b.date and a.t < b.t))
	return weeks


## Work out every week's bounty from the replayed log and store it in
## `s.weekly`. After each win the state is settled, so gear and trophies that
## ask for bounty wins unlock on the day of the win.
static func settle(s: Dictionary, sessions: Array, today: String) -> void:
	var weeks: Dictionary = weeks_of(s, sessions)
	var now_wk: String = Dates.week_key(today)
	var out = {"wins": 0, "crushes": 0, "streak": 0, "bestStreak": 0, "coins": 0, "history": [], "current": null}
	s["weekly"] = out
	var keys: Array = weeks.keys()
	keys.sort()
	var first: String = now_wk if keys.is_empty() else str(keys[0])
	var last: String = now_wk if keys.is_empty() else maxs(now_wk, str(keys[keys.size() - 1]))
	var wk: String = first
	var guard: int = 0
	var streak: int = 0
	while wk <= last and guard < 2000:
		guard += 1
		var rec: Dictionary = _record(wk, first, weeks)
		if rec.defeated:
			streak += 1
			rec.streak = streak
			rec.coins = coins_for(streak, rec.crushed)
			out.wins += 1
			out.coins += rec.coins
			if rec.crushed:
				out.crushes += 1
			out.bestStreak = maxi(out.bestStreak, streak)
			out.streak = streak
			Derive._settle(s, rec.at, rec.sessionId)
		elif wk < now_wk:
			# A finished week that got away ends the run; this week still can be won.
			streak = 0
			out.streak = 0
		out.history.append(rec)
		if wk == now_wk:
			out.current = rec
		wk = Dates.add_weeks(wk, 1)
	if out.current == null:
		out.current = _record(now_wk, first, weeks)


static func maxs(a: String, b: String) -> String:
	return a if a > b else b


# --- reading (safe on a state that has not been settled) -------------------------

static func of(s: Dictionary):
	return s.get("weekly")


static func wins(s: Dictionary) -> int:
	var w = s.get("weekly")
	return int(w.wins) if w is Dictionary else 0


static func crushes(s: Dictionary) -> int:
	var w = s.get("weekly")
	return int(w.crushes) if w is Dictionary else 0


static func best_streak(s: Dictionary) -> int:
	var w = s.get("weekly")
	return int(w.bestStreak) if w is Dictionary else 0


## The record of a week, or null.
static func record(s: Dictionary, wk: String):
	var w = s.get("weekly")
	if not (w is Dictionary):
		return null
	for r in w.history:
		if r.week == wk:
			return r
	if w.current != null and w.current.week == wk:
		return w.current
	return null


## Days left to beat this week's bounty, today included (1 on a Sunday).
static func days_left(today: String) -> int:
	return 7 - Dates.weekday_index(today)


## Bounty wins as story moments for the Journey page (kept out of
## `state.chronicle`, which the parity tests compare).
static func chronicle(s: Dictionary) -> Array:
	var out: Array = []
	var w = s.get("weekly")
	if not (w is Dictionary):
		return out
	for r in w.history:
		if not r.defeated:
			continue
		var m: Dictionary = monster(r.monster)
		out.append({
			"date": r.at,
			"kind": "bounty",
			"icon": "🪙",
			"title": ("Crushed " if r.crushed else "Bounty: ") + m.name,
			"detail": "%s Weekly bounty, +%d coins." % [m.epithet, int(r.coins)],
			"ref": r.week,
		})
	return out
