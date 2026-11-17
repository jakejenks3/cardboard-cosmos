class_name Achievements
extends RefCounted
## The trophy catalog (port of achievements.ts).
##
## Achievement: {id, name, desc, icon, xp, group, secret: bool,
##               check: Callable(state) -> bool,
##               progress?: Callable(state) -> {cur, target, unit}}
## `progress` is missing on custom-condition trophies (no progress bar):
## test with `a.has("progress")` and call with `a.progress.call(state)`.
## `secret` hides the description until unlocked.
## `group` is a discipline or "general" / "campaign" / "body" / "collection".

const ACH_GROUPS = [
	{"id": "general", "name": "General", "icon": "⭐"},
	{"id": "lift", "name": "Lifting", "icon": "🏋️"},
	{"id": "climb", "name": "Climbing", "icon": "🧗"},
	{"id": "run", "name": "Running", "icon": "👟"},
	{"id": "ride", "name": "Cycling", "icon": "🚴"},
	{"id": "campaign", "name": "Adventure", "icon": "⚔️"},
	{"id": "body", "name": "Body", "icon": "📸"},
	{"id": "collection", "name": "Collection", "icon": "🎒"},
]
## Groups added after the port (ACH_GROUPS is checked against the original).
const MORE_GROUPS = [
	{"id": "read", "name": "Reading", "icon": "📖"},
]

const TIER_COLOR = {"bronze": "#c98a5a", "silver": "#c9d1d9", "gold": "#ffc83d", "platinum": "#7fe7ff"}

static var _all = null
static var _by_id = null
## When set (an Array of ids), `all()` returns only those trophies, in catalog
## order. The parity tests use it to replay with the catalog the TypeScript
## engine had, so trophies added since the port (the card hands) do not change
## the fixtures' XP, chronicle or unlock lists.
static var _only = null


static func restrict_to(ids) -> void:
	_only = ids
	_all = null
	_by_id = null


## Every trophy group, in the order the trophy screen shows them.
static func groups() -> Array:
	return ACH_GROUPS + MORE_GROUPS


## "bronze" | "silver" | "gold" | "platinum", from the trophy's XP.
static func tier_of(a: Dictionary) -> String:
	if a.xp <= 150:
		return "bronze"
	if a.xp <= 400:
		return "silver"
	if a.xp <= 800:
		return "gold"
	return "platinum"


# Threshold achievement with a progress bar.
static func _g(id: String, ach_name: String, desc: String, icon: String, xp: int, group: String, getter: Callable, target, unit: String = "count", secret: bool = false) -> Dictionary:
	var a = {"id": id, "name": ach_name, "desc": desc, "icon": icon, "xp": xp, "group": group, "secret": secret}
	a.merge(Goals.at_least(getter, target, unit))
	return a


# Custom-condition achievement (no progress bar).
static func _c(id: String, ach_name: String, desc: String, icon: String, xp: int, group: String, check: Callable, secret: bool = false) -> Dictionary:
	return {"id": id, "name": ach_name, "desc": desc, "icon": icon, "xp": xp, "group": group, "secret": secret, "check": check}


static func _disciplines_used(s: Dictionary) -> int:
	var n: int = 0
	for d in TT.DISCIPLINES:
		if s.totals.byDiscipline[d] > 0:
			n += 1
	return n


static func _min_disc_level(s: Dictionary) -> int:
	var lowest: int = s.levels[TT.DISCIPLINES[0]].level
	for d in TT.DISCIPLINES:
		lowest = mini(lowest, s.levels[d].level)
	return lowest


# -2 = nothing sent yet (VB is -1), so grade progress bars start empty.
static func _max_send(s: Dictionary):
	return s.prs.climbMaxSend if s.prs.climbMaxSend != null else -2


static func _max_flash(s: Dictionary):
	return s.prs.climbMaxFlash if s.prs.climbMaxFlash != null else -2


# Hangboard records: the best added kg on an edge (0 before any), and whether any
# edge of at most `mm` has a record.
static func _hang_kg(s: Dictionary, table: String, edge: String) -> float:
	var t = s.prs.get(table)
	if t == null:
		return 0.0
	return float(t.get(edge, 0.0))


static func _hang_edge_at_most(s: Dictionary, table: String, mm: int) -> int:
	var t = s.prs.get(table)
	if t == null:
		return 0
	for k in t:
		if int(k) > 0 and int(k) <= mm:
			return 1
	return 0


# A body counter that is null until first used.
static func _body_n(s: Dictionary, key: String) -> int:
	return int(TTUtil.get_or(s.body, key, 0))


# Card hands (s.hands, see Derive._deal_hands): a grade, or -2 before the hand was ever dealt.
static func _hand(s: Dictionary, key: String):
	var v = s.get("hands", {}).get(key)
	return v if v != null else -2


static func _hand_n(s: Dictionary, key: String) -> int:
	var v = s.get("hands", {}).get(key)
	return int(v) if v != null else 0


static func _hand_flag(s: Dictionary, key: String) -> bool:
	return bool(s.get("hands", {}).get(key, false))


# Chase feats outside climbing (s.quirks, see Derive._deal_quirks): a number, or 0 before it happened.
static func _quirk(s: Dictionary, key: String):
	var v = s.get("quirks", {}).get(key)
	return v if v != null else 0


static func _quirk_flag(s: Dictionary, key: String) -> bool:
	return bool(s.get("quirks", {}).get(key, false))


## Every trophy, in catalog order (do not mutate).
static func all() -> Array:
	if _all == null:
		var built: Array = _build()
		if _only != null:
			var keep = {}
			for id in _only:
				keep[id] = true
			built = built.filter(func(a): return keep.has(a.id))
		_all = built
	return _all


## Trophy by id, or null.
static func by_id(id):
	if _by_id == null:
		var map = {}
		for a in all():
			map[a.id] = a
		_by_id = map
	return _by_id.get(id)


## Sum of the XP of every unlocked trophy.
static func trophy_points(s: Dictionary) -> int:
	var total: int = 0
	for a in all():
		if s.achievements.has(a.id):
			total += a.xp
	return total


static func _build() -> Array:
	return [
			# --- first steps -------------------------------------------------------
			_g("first_session", "First Step", "Log your very first session.", "🥾", 100, "general", func(s): return s.totals.sessions, 1),
			_g("first_lift", "Iron Curious", "Log a lifting session.", "🏋️", 100, "lift", func(s): return s.totals.byDiscipline.lift, 1),
			_g("first_climb", "Chalk Up", "Log a climbing session.", "🧗", 100, "climb", func(s): return s.totals.byDiscipline.climb, 1),
			_g("first_run", "Lace Up", "Log a run.", "👟", 100, "run", func(s): return s.totals.byDiscipline.run, 1),
			_g("first_ride", "Clip In", "Log a ride.", "🚴", 100, "ride", func(s): return s.totals.byDiscipline.ride, 1),
			_g("all_four", "Jack of All Trades", "Log a session in all four disciplines.", "🃏", 300, "general", func(s): return Achievements._disciplines_used(s), 4),

			# --- consistency -------------------------------------------------------
			_g("sessions_10", "Regular", "Log 10 sessions.", "📅", 200, "general", func(s): return s.totals.sessions, 10),
			_g("sessions_50", "Dedicated", "Log 50 sessions.", "🗓️", 300, "general", func(s): return s.totals.sessions, 50),
			_g("sessions_100", "Centurion", "Log 100 sessions.", "💯", 500, "general", func(s): return s.totals.sessions, 100),
			_g("sessions_365", "Year of Sweat", "Log 365 sessions.", "🏆", 1000, "general", func(s): return s.totals.sessions, 365),
			_g("active_days_100", "Hundred Days", "Train on 100 different days.", "🌅", 500, "general", func(s): return s.totals.activeDays, 100),
			_g("hours_100", "Hundred Hours", "Train for 100 hours in total.", "⌛", 600, "general", func(s): return s.totals.durationSec / 60.0, 6000, "min"),
			_g("double_day", "Two-a-Day", "Log two sessions on the same day.", "🔁", 150, "general", func(s): return s.bests.daySessions, 2),
			_g("weekend_warrior", "Weekend Warrior", "Train on both Saturday and Sunday of the same week.", "🛡️", 150, "general", func(s): return s.bests.weekendWarrior, 1),
			_g("week_3_disc", "Triple Threat", "Train three different disciplines in one week.", "🔱", 200, "general", func(s): return s.bests.weekDisciplines, 3),
			_g("week_4_disc", "Full House", "Train all four disciplines in one week.", "🎰", 400, "general", func(s): return s.bests.weekDisciplines, 4),
			_g("month_12", "Monthly Regular", "Log 12 sessions in one calendar month.", "🗓️", 300, "general", func(s): return s.bests.monthSessions, 12),
			_g("month_20", "Machine", "Log 20 sessions in one calendar month.", "🤖", 600, "general", func(s): return s.bests.monthSessions, 20),
			_g("streak_4", "On a Roll", "Hit your weekly goal 4 weeks in a row.", "🔥", 200, "general", func(s): return s.streak.best, 4, "weeks"),
			_g("streak_12", "Unbreakable", "Hit your weekly goal 12 weeks in a row.", "🔥", 500, "general", func(s): return s.streak.best, 12, "weeks"),
			_g("streak_26", "Half-Year Hero", "Hit your weekly goal 26 weeks in a row.", "🔥", 800, "general", func(s): return s.streak.best, 26, "weeks"),
			_g("streak_52", "Iron Will", "Hit your weekly goal 52 weeks in a row.", "🔥", 1500, "general", func(s): return s.streak.best, 52, "weeks"),
			_g("big_day", "Big Day", "Earn 3,000 XP in a single day.", "☀️", 200, "general", func(s): return s.bests.dayXp, 3000, "xp"),
			_g("long_session", "Marathon Session", "Log a session lasting 2 hours or more.", "⏳", 150, "general", func(s): return s.bests.sessionDurationSec / 60.0, 120, "min"),
			_g("hat_trick", "Hat Trick", "Set three personal records in a single session.", "🎩", 300, "general", func(s): return s.bests.sessionPrs, 3),
			_g("comeback", "Comeback Kid", "Come back and log a session after two weeks away. The door is always open.", "🚪", 200, "general", func(s): return s.bests.gapDays, 14, "count", true),
			_c("quirk_double_header", "Double Header", "Two different disciplines on the same day.", "🔁", 150, "general", func(s): return Achievements._quirk_flag(s, "doubleHeader")),
			_c("quirk_friday_13", "Unlucky for Some", "Train on a Friday the 13th.", "🐉", 100, "general", func(s): return Achievements._quirk_flag(s, "friday13"), true),
			_c("quirk_leap_day", "Leap of Faith", "Train on the 29th of February.", "🗓️", 200, "general", func(s): return Achievements._quirk_flag(s, "leapDay"), true),
			_c("quirk_new_year", "Resolution", "Train on the 1st of January.", "🌅", 100, "general", func(s): return Achievements._quirk_flag(s, "newYear"), true),

			# --- lifting -----------------------------------------------------------
			_g("lift_60", "One Plate", "Lift 60 kg in a set.", "🍽️", 100, "lift", func(s): return s.bests.maxSetKg, 60, "kg"),
			_g("lift_100", "Two Plates", "Lift 100 kg in a set.", "🍽️", 200, "lift", func(s): return s.bests.maxSetKg, 100, "kg"),
			_g("lift_140", "Three Plates", "Lift 140 kg in a set.", "🍽️", 300, "lift", func(s): return s.bests.maxSetKg, 140, "kg"),
			_g("lift_180", "Four Plates", "Lift 180 kg in a set.", "🍽️", 400, "lift", func(s): return s.bests.maxSetKg, 180, "kg"),
			_g("lift_220", "Five Plates", "Lift 220 kg in a set.", "🍽️", 600, "lift", func(s): return s.bests.maxSetKg, 220, "kg"),
			_g("lift_session_10t", "Ten Tonnes", "Move 10,000 kg in one session.", "🐘", 200, "lift", func(s): return s.bests.sessionVolumeKg, 10000, "kg"),
			_g("lift_session_20t", "Twenty Tonnes", "Move 20,000 kg in one session.", "🐘", 350, "lift", func(s): return s.bests.sessionVolumeKg, 20000, "kg"),
			_g("lift_total_100k", "100 Tonne Club", "Lift 100,000 kg lifetime.", "⚙️", 300, "lift", func(s): return s.totals.liftVolumeKg, 100000, "kg"),
			_g("lift_total_500k", "Half-Million Club", "Lift 500,000 kg lifetime.", "⚙️", 600, "lift", func(s): return s.totals.liftVolumeKg, 500000, "kg"),
			_g("lift_total_1m", "Million Kilo Club", "Lift 1,000,000 kg lifetime.", "⚙️", 1200, "lift", func(s): return s.totals.liftVolumeKg, 1000000, "kg"),
			_g("lift_reps_1000", "Thousand Reps", "1,000 weighted reps lifetime.", "🔢", 200, "lift", func(s): return s.totals.liftReps, 1000),
			_g("lift_reps_10000", "Ten Thousand Reps", "10,000 weighted reps lifetime.", "🔢", 700, "lift", func(s): return s.totals.liftReps, 10000),
			_g("lift_variety", "Variety Pack", "Log 10 different exercises.", "🎒", 150, "lift", func(s): return s.totals.liftExercises.size(), 10),
			_g("lift_bw_100", "Calisthenics Curious", "100 bodyweight reps in a session.", "🤸", 150, "lift", func(s): return s.bests.sessionBwReps, 100),
			_g("rel_bench_1", "Bodyweight Bench", "Bench press your own bodyweight. Needs a logged body weight.", "⚖️", 300, "lift", func(s): return s.bests.benchRatio, 1, "ratio"),
			_g("rel_squat_15", "Squat Rack Citizen", "Squat 1.5× your bodyweight.", "⚖️", 400, "lift", func(s): return s.bests.squatRatio, 1.5, "ratio"),
			_g("rel_deadlift_2", "Double Bodyweight Pull", "Deadlift 2× your bodyweight.", "⚖️", 500, "lift", func(s): return s.bests.deadliftRatio, 2, "ratio"),
			_g("rel_bench_15", "Bench Boss", "Bench press 1.5× your bodyweight.", "⚖️", 800, "lift", func(s): return s.bests.benchRatio, 1.5, "ratio"),
			_g("rel_squat_2", "Double Bodyweight Squat", "Squat 2× your bodyweight.", "⚖️", 900, "lift", func(s): return s.bests.squatRatio, 2, "ratio"),
			_g("rel_deadlift_25", "Gravity Is Optional", "Deadlift 2.5× your bodyweight.", "⚖️", 1000, "lift", func(s): return s.bests.deadliftRatio, 2.5, "ratio"),
			# --- chase feats: shapes of a session worth going out of your way for ------------
			_c("quirk_five_by_five", "Five by Five", "One exercise, exactly five sets of exactly five reps, all at the same weight.", "🎯", 200, "lift", func(s): return Achievements._quirk_flag(s, "fiveByFive")),
			_g("quirk_ladder", "Ladder", "Five sets of one exercise, every set heavier than the last.", "📈", 250, "lift", func(s): return Achievements._quirk(s, "ladderSets"), 5),
			_c("quirk_pyramid", "Pyramid", "One exercise: climb the weight for three sets or more, then bring it back down for two.", "⛰️", 300, "lift", func(s): return Achievements._quirk_flag(s, "pyramid")),
			_g("quirk_ton_set", "Ton Up", "Move 1,000 kg in a single set (reps × weight).", "🐘", 300, "lift", func(s): return Achievements._quirk(s, "maxSetVolumeKg"), 1000, "kg"),
			_g("quirk_century_set", "Century Set", "100 reps in one bodyweight set. No putting it down.", "💯", 250, "lift", func(s): return Achievements._quirk(s, "maxSetReps"), 100),
			_c("quirk_big_three", "The Big Three", "Squat, bench press and deadlift, all in one session.", "🏋️", 250, "lift", func(s): return Achievements._quirk_flag(s, "bigThree")),
			_c("quirk_bakers_dozen", "Baker's Dozen", "A set of exactly 13 reps.", "🍽️", 100, "lift", func(s): return Achievements._quirk_flag(s, "bakersDozen"), true),
			_c("quirk_seven_by_seven", "Sevens", "One exercise, seven sets of seven reps.", "🃏", 150, "lift", func(s): return Achievements._quirk_flag(s, "sevenBySeven"), true),

			# --- climbing ----------------------------------------------------------
			_g("climb_v2", "Getting Grippy", "Send a V2.", "🪨", 100, "climb", func(s): return Achievements._max_send(s), 2, "grade"),
			_g("climb_v4", "Crimp Master", "Send a V4.", "🪨", 200, "climb", func(s): return Achievements._max_send(s), 4, "grade"),
			_g("climb_v6", "Project Crusher", "Send a V6.", "🪨", 350, "climb", func(s): return Achievements._max_send(s), 6, "grade"),
			_g("climb_v8", "Stone Cold", "Send a V8.", "🪨", 600, "climb", func(s): return Achievements._max_send(s), 8, "grade"),
			_g("climb_v10", "Double Digits", "Send a V10.", "💎", 1000, "climb", func(s): return Achievements._max_send(s), 10, "grade"),
			_g("climb_v12", "Mythic", "Send a V12.", "💎", 1500, "climb", func(s): return Achievements._max_send(s), 12, "grade"),
			_g("climb_flash_v4", "Flash Bang", "Flash a V4.", "⚡", 250, "climb", func(s): return Achievements._max_flash(s), 4, "grade"),
			_g("climb_flash_v6", "Lightning Hands", "Flash a V6.", "⚡", 500, "climb", func(s): return Achievements._max_flash(s), 6, "grade"),
			_g("climb_sends_100", "Hundred Sends", "100 sends lifetime.", "🧮", 300, "climb", func(s): return s.totals.climbSends, 100),
			_g("climb_sends_500", "Five Hundred Sends", "500 sends lifetime.", "🧮", 500, "climb", func(s): return s.totals.climbSends, 500),
			_g("climb_sends_1000", "Thousand Sends", "1,000 sends lifetime.", "🧮", 1000, "climb", func(s): return s.totals.climbSends, 1000),
			_g("climb_flashes_100", "Lightning Rod", "100 flashes lifetime.", "🌩️", 400, "climb", func(s): return s.totals.climbFlashes, 100),
			_g("climb_pump", "Pump City", "20 sends in one session.", "💪", 200, "climb", func(s): return s.bests.sessionSends, 20),
			_g("climb_flash_flood", "Flash Flood", "10 flashes in one session.", "🌊", 250, "climb", func(s): return s.bests.sessionFlashes, 10),
			_g("climb_vpoints_50", "V-Point Hoarder", "Send 50 V-points in one session (a V4 is 4 points).", "🧺", 300, "climb", func(s): return s.bests.sessionVPoints, 50),
			_g("climb_project", "Project Mode", "10 attempts in one session. Respect the process.", "🧠", 100, "climb", func(s): return s.bests.sessionAttempts, 10),
			# --- card hands: the sends of one boulder session, read like a poker hand ---------
			_g("hand_pair", "Pair", "Send two of the same grade, V3 or harder, in one session.", "🃏", 150, "climb", func(s): return Achievements._hand(s, "pair"), 3, "grade"),
			_g("hand_pocket_fives", "Pocket Fives", "A pair of V5s in one session.", "🃏", 300, "climb", func(s): return Achievements._hand(s, "pair"), 5, "grade"),
			_g("hand_pocket_sevens", "Pocket Sevens", "A pair of V7s in one session.", "💎", 600, "climb", func(s): return Achievements._hand(s, "pair"), 7, "grade"),
			_g("hand_two_pair", "Two Pair", "Two different grades sent twice each, both V3 or harder, in one session.", "🃏", 250, "climb", func(s): return Achievements._hand(s, "twoPair"), 3, "grade"),
			_g("hand_three", "Three of a Kind", "Three sends of one grade, V4 or harder, in one session.", "🃏", 300, "climb", func(s): return Achievements._hand(s, "three"), 4, "grade"),
			_g("hand_full_house", "Full House", "Three of one grade and two of another, all V3 or harder, in one session.", "🏆", 450, "climb", func(s): return Achievements._hand(s, "fullHouse"), 3, "grade"),
			_g("hand_four", "Four of a Kind", "Four sends of one grade, V5 or harder, in one session.", "💎", 700, "climb", func(s): return Achievements._hand(s, "four"), 5, "grade"),
			_g("hand_straight", "Straight", "Five grades in a row, V1 to V5 or higher, all sent in one session.", "⭐", 400, "climb", func(s): return Achievements._hand(s, "straight"), 5, "grade"),
			_g("hand_broadway", "Broadway", "A straight to the top: V4, V5, V6, V7 and V8 in one session.", "👑", 900, "climb", func(s): return Achievements._hand(s, "straight"), 8, "grade"),
			_g("hand_flush", "Flush", "Five flashes, all V3 or harder, in one session.", "⚡", 350, "climb", func(s): return Achievements._hand_n(s, "flush"), 5),
			_g("hand_straight_flush", "Straight Flush", "Flash five grades in a row, V1 to V5 or higher, in one session.", "⚡", 800, "climb", func(s): return Achievements._hand(s, "straightFlush"), 5, "grade"),
			_g("hand_royal_flush", "Royal Flush", "Flash V6, V7, V8, V9 and V10 in one session.", "👑", 2000, "climb", func(s): return Achievements._hand(s, "straightFlush"), 10, "grade"),
			_c("hand_blackjack", "Blackjack", "Exactly 21 sends in one session. Not 20. Not 22.", "🧮", 300, "climb", func(s): return Achievements._hand_flag(s, "blackjack"), true),
			_c("hand_snake_eyes", "Snake Eyes", "A session where you send exactly two V1s and nothing else.", "🃏", 100, "climb", func(s): return Achievements._hand_flag(s, "snakeEyes"), true),
			_c("hand_lucky_sevens", "Lucky Sevens", "Seven V7 sends in one session.", "💎", 777, "climb", func(s): return Achievements._hand_flag(s, "luckySevens"), true),

			# --- running -----------------------------------------------------------
			_g("run_5k", "Parkrun", "Run 5 km in one go.", "🏃", 100, "run", func(s): return s.prs.longestRunM, 5000, "m"),
			_g("run_10k", "Ten K", "Run 10 km in one go.", "🏃", 200, "run", func(s): return s.prs.longestRunM, 10000, "m"),
			_g("run_half", "Half Marathon", "Run 21.1 km in one go.", "🎽", 500, "run", func(s): return s.prs.longestRunM, 21097, "m"),
			_g("run_marathon", "Marathon", "Run 42.2 km in one go.", "🏅", 1200, "run", func(s): return s.prs.longestRunM, 42195, "m"),
			_g("run_total_100", "Century", "Run 100 km lifetime.", "🛣️", 300, "run", func(s): return s.totals.runDistanceM, 100000, "m"),
			_g("run_total_500", "Road Warrior", "Run 500 km lifetime.", "🛣️", 600, "run", func(s): return s.totals.runDistanceM, 500000, "m"),
			_g("run_total_1000", "Thousand K", "Run 1,000 km lifetime.", "🛣️", 1200, "run", func(s): return s.totals.runDistanceM, 1000000, "m"),
			_g("run_sessions_50", "Fifty Runs", "Log 50 runs.", "👟", 400, "run", func(s): return s.totals.byDiscipline.run, 50),
			_c("run_pace_5", "Speed Demon", "Average 5:00 /km or faster over 5 km+.", "💨", 250, "run", func(s): return s.prs.bestPaceSecPerKm != null and s.prs.bestPaceSecPerKm <= 300),
			_c("run_pace_4", "Rocket Legs", "Average 4:00 /km or faster over 5 km+.", "🚀", 500, "run", func(s): return s.prs.bestPaceSecPerKm != null and s.prs.bestPaceSecPerKm <= 240),
			_g("run_elev_500", "Hill Hunter", "Climb 500 m of elevation in one run.", "⛰️", 200, "run", func(s): return s.prs.bestRunElevM, 500, "elev"),
			_g("run_elev_total_5000", "Vert Collector", "Climb 5,000 m of elevation lifetime on foot.", "🗻", 500, "run", func(s): return s.totals.runElevationM, 5000, "elev"),
			_g("quirk_run_streak", "Streak Week", "Run seven days in a row.", "🔥", 400, "run", func(s): return Achievements._quirk(s, "runDayStreakBest"), 7),
			_g("quirk_run_month", "Marathon Month", "Run 42.2 km within one calendar month.", "🏅", 300, "run", func(s): return Achievements._quirk(s, "bestMonthRunM"), 42195, "m"),
			_c("quirk_run_exact_5", "On the Nose", "A run of exactly 5.00 km. Not a step more.", "🎯", 150, "run", func(s): return Achievements._quirk_flag(s, "runExact5"), true),
			_c("quirk_run_metronome", "Metronome", "A run of 3 km or more at an average pace of exactly 5:00 /km.", "⏱️", 200, "run", func(s): return Achievements._quirk_flag(s, "metronome"), true),

			# --- cycling -----------------------------------------------------------
			_g("ride_25", "Quarter Century", "Ride 25 km in one go.", "🚲", 100, "ride", func(s): return s.prs.longestRideM, 25000, "m"),
			_g("ride_50", "Half Century", "Ride 50 km in one go.", "🚲", 200, "ride", func(s): return s.prs.longestRideM, 50000, "m"),
			_g("ride_100", "Century Ride", "Ride 100 km in one go.", "🚲", 500, "ride", func(s): return s.prs.longestRideM, 100000, "m"),
			_g("ride_160", "Imperial Century", "Ride 160 km (100 miles) in one go.", "👑", 800, "ride", func(s): return s.prs.longestRideM, 160934, "m"),
			_g("ride_total_500", "Rolling", "Ride 500 km lifetime.", "🛞", 300, "ride", func(s): return s.totals.rideDistanceM, 500000, "m"),
			_g("ride_total_2000", "Touring", "Ride 2,000 km lifetime.", "🛞", 600, "ride", func(s): return s.totals.rideDistanceM, 2000000, "m"),
			_g("ride_total_5000", "Grand Tour", "Ride 5,000 km lifetime.", "🛞", 1200, "ride", func(s): return s.totals.rideDistanceM, 5000000, "m"),
			_g("ride_sessions_50", "Fifty Rides", "Log 50 rides.", "🚴", 400, "ride", func(s): return s.totals.byDiscipline.ride, 50),
			_g("ride_elev_1000", "Mountain Goat", "Climb 1,000 m of elevation in one ride.", "🐐", 300, "ride", func(s): return s.prs.bestRideElevM, 1000, "elev"),
			_g("ride_everest", "Everested", "Climb 8,848 m of elevation lifetime on the bike.", "🏔️", 500, "ride", func(s): return s.totals.rideElevationM, 8848, "elev"),
			_c("ride_speed_30", "Fast Wheels", "Average 30 km/h over a 20 km+ ride.", "💨", 300, "ride", func(s): return s.prs.bestRideSpeedKmh != null and s.prs.bestRideSpeedKmh >= 30),
			_g("quirk_ride_commuter", "Commuter", "Ride on five different days of one week.", "🚲", 300, "ride", func(s): return Achievements._quirk(s, "bestRideWeekDays"), 5),
			_g("quirk_ride_month", "Big Month", "Ride 300 km within one calendar month.", "🛞", 300, "ride", func(s): return Achievements._quirk(s, "bestMonthRideM"), 300000, "m"),
			_c("quirk_ride_exact_50", "Round Trip", "A ride of exactly 50.0 km.", "🎯", 150, "ride", func(s): return Achievements._quirk_flag(s, "rideExact50"), true),

			# --- hero --------------------------------------------------------------
			_g("hero_10", "Rising Hero", "Reach hero level 10.", "⭐", 200, "general", func(s): return s.levels.hero.level, 10, "level"),
			_g("hero_25", "Seasoned Hero", "Reach hero level 25.", "🌟", 500, "general", func(s): return s.levels.hero.level, 25, "level"),
			_g("hero_50", "Titan", "Reach hero level 50.", "💫", 1500, "general", func(s): return s.levels.hero.level, 50, "level"),
			_g("hero_75", "Beyond", "Reach hero level 75.", "🌌", 2500, "general", func(s): return s.levels.hero.level, 75, "level"),
			_g("balanced_10", "Well Rounded", "Reach level 10 in all four disciplines.", "⚖️", 600, "general", func(s): return Achievements._min_disc_level(s), 10, "level"),
			_g("rank_journeyman", "Journeyman", "Reach the Journeyman rank in any discipline.", "🎖️", 250, "general", func(s): return s.bests.maxRank, 2),
			_g("rank_expert", "Expert", "Reach the Expert rank in any discipline.", "🎖️", 600, "general", func(s): return s.bests.maxRank, 4),
			_g("rank_master", "Mastery", "Reach the Master rank in any discipline.", "🏵️", 1200, "general", func(s): return s.bests.maxRank, 5),

			# --- adventure ---------------------------------------------------------
			_g("boss_first", "First Blood", "Defeat your first boss.", "⚔️", 100, "campaign", func(s): return PlayerState.defeated_count(s), 1),
			_g("zone_1", "Off the Couch", "Clear the Couch Kingdom.", "🛋️", 300, "campaign", func(s): return PlayerState.defeated_count(s), 4),
			_g("zone_2", "Golem Breaker", "Clear the Iron Foothills.", "🗿", 500, "campaign", func(s): return PlayerState.defeated_count(s), 8),
			_g("zone_3", "Dragonslayer", "Clear Chalk Canyon.", "🐉", 700, "campaign", func(s): return PlayerState.defeated_count(s), 12),
			_g("zone_4", "Through the Wall", "Clear the Windswept Steppe.", "🧱", 900, "campaign", func(s): return PlayerState.defeated_count(s), 16),
			_g("zone_5", "King of the Col", "Clear the Spoke Highlands.", "⛰️", 1200, "campaign", func(s): return PlayerState.defeated_count(s), 20),
			_g("zone_6", "Titan Ascendant", "Defeat The Old You and clear Titan's Summit.", "👑", 2500, "campaign", func(s): return PlayerState.defeated_count(s), 24),
			_g("damage_100k", "Heavy Hitter", "Deal 100,000 total damage.", "💥", 500, "campaign", func(s): return s.campaign.totalDamage, 100000),
			# Weekly bounties (s.weekly, see Bounty): outside the parity fixtures.
			_g("bounty_1", "Bounty Hunter", "Win a weekly bounty.", "🪙", 100, "campaign", func(s): return Bounty.wins(s), 1),
			_g("bounty_5", "Monster of the Week", "Win 5 weekly bounties.", "🪙", 250, "campaign", func(s): return Bounty.wins(s), 5),
			_g("bounty_15", "Pest Control", "Win 15 weekly bounties.", "🪙", 500, "campaign", func(s): return Bounty.wins(s), 15),
			_g("bounty_30", "Scourge of Mondays", "Win 30 weekly bounties.", "👑", 1000, "campaign", func(s): return Bounty.wins(s), 30),
			_g("bounty_streak_4", "On a Roll", "Win 4 weekly bounties in a row.", "🔥", 300, "campaign", func(s): return Bounty.best_streak(s), 4, "weeks"),
			_g("bounty_streak_10", "Unshakeable", "Win 10 weekly bounties in a row.", "🔥", 800, "campaign", func(s): return Bounty.best_streak(s), 10, "weeks"),
			_g("bounty_crush_1", "Overkill", "Crush a weekly bounty: deal 150% of its HP.", "💥", 150, "campaign", func(s): return Bounty.crushes(s), 1),
			_g("bounty_crush_10", "No Survivors", "Crush 10 weekly bounties.", "💥", 600, "campaign", func(s): return Bounty.crushes(s), 10),

			# --- body --------------------------------------------------------------
			_g("body_first", "Baseline", "Log your body weight for the first time.", "⚖️", 100, "body", func(s): return s.body.weightEntries, 1),
			_g("body_bf", "Know Thyself", "Log a body fat percentage.", "📏", 100, "body", func(s): return s.body.bfEntries, 1),
			_g("body_photos", "Say Cheese", "Take a full set of progress photos: front, side and back.", "📸", 200, "body", func(s): return s.body.fullSets, 1),
			_g("body_album_5", "Photo Album", "Five check-ins with progress photos.", "🖼️", 300, "body", func(s): return s.body.photoEntries, 5),
			_g("body_album_20", "Time-Lapse", "Twenty check-ins with progress photos.", "🎞️", 800, "body", func(s): return s.body.photoEntries, 20),
			_g("body_streak_4", "Checking In", "Check in four weeks in a row.", "🗓️", 200, "body", func(s): return s.body.bestStreak, 4, "weeks"),
			_g("body_streak_12", "Accountable", "Check in twelve weeks in a row.", "🗓️", 500, "body", func(s): return s.body.bestStreak, 12, "weeks"),
			_g("body_streak_26", "Half a Year in Frames", "Check in twenty-six weeks in a row.", "🗓️", 900, "body", func(s): return s.body.bestStreak, 26, "weeks"),
			# Photo milestones (s.body.photoSpanDays / photoMonths, see Derive._apply_body).
			_g("body_month_on", "One Month On", "Progress photos four weeks apart.", "📸", 200, "body", func(s): return Achievements._body_n(s, "photoSpanDays"), 28, "days"),
			_g("body_season_on", "Three Months On", "Progress photos three months apart.", "📸", 400, "body", func(s): return Achievements._body_n(s, "photoSpanDays"), 90, "days"),
			_g("body_year_on", "A Year in Frames", "Progress photos a year apart.", "📸", 1000, "body", func(s): return Achievements._body_n(s, "photoSpanDays"), 365, "days"),
			_g("body_months_6", "Half a Year of Snaps", "Progress photos in six different months.", "🖼️", 400, "body", func(s): return Achievements._body_n(s, "photoMonths"), 6),
			_g("body_months_12", "Calendar Body", "Progress photos in twelve different months.", "🖼️", 900, "body", func(s): return Achievements._body_n(s, "photoMonths"), 12),
			# Hangboard records by edge (s.prs.hangEdge / hangOneArm / longestHangSec).
			_g("hang_edge_10", "Micro Edge", "Hang five seconds or more on a 10 mm edge or smaller.", "🧗", 200, "climb", func(s): return Achievements._hang_edge_at_most(s, "hangEdge", 10), 1),
			_g("hang_plus_20", "Weighted Hang", "Hang +20 kg on a 20 mm edge.", "🧗", 300, "climb", func(s): return Achievements._hang_kg(s, "hangEdge", "20"), 20, "kg"),
			_g("hang_plus_40", "Iron Fingers", "Hang +40 kg on a 20 mm edge.", "🧗", 600, "climb", func(s): return Achievements._hang_kg(s, "hangEdge", "20"), 40, "kg"),
			_g("hang_one_arm", "One Arm Bandit", "A one-arm hang of five seconds or more.", "🧗", 300, "climb", func(s): return 1 if s.prs.get("hangOneArm") != null and not s.prs.hangOneArm.is_empty() else 0, 1),
			_g("hang_one_arm_15", "Half the Hands", "A one-arm hang on a 15 mm edge or smaller.", "🧗", 600, "climb", func(s): return Achievements._hang_edge_at_most(s, "hangOneArm", 15), 1),
			_g("hang_30s", "Hang Time", "One hang of thirty seconds.", "⏱️", 200, "climb", func(s): return int(TTUtil.get_or(s.prs, "longestHangSec", 0)), 30, "sec"),
			_g("hang_hour", "Hour of Power", "An hour of hanging in all.", "⏱️", 500, "climb", func(s): return int(int(TTUtil.get_or(s.totals, "hangSec", 0)) / 60.0), 60, "min"),

			# --- collection --------------------------------------------------------
			_g("items_10", "Collector", "Own 10 pieces of gear.", "🎒", 150, "collection", func(s): return PlayerState.owned_item_count(s), 10),
			_g("items_25", "Hoarder", "Own 25 pieces of gear.", "🧳", 400, "collection", func(s): return PlayerState.owned_item_count(s), 25),
			_g("items_45", "Walking Wardrobe", "Own 45 pieces of gear.", "🏬", 900, "collection", func(s): return PlayerState.owned_item_count(s), 45),
			_g("pets_5", "Animal Friend", "Befriend 5 companions.", "🐾", 200, "collection", func(s): return PlayerState.owned_pet_count(s), 5),
			_g("pets_10", "Zookeeper", "Befriend 10 companions.", "🦁", 700, "collection", func(s): return PlayerState.owned_pet_count(s), 10),
			# The shop (see Wallet): outside the parity fixtures.
			_g("shop_1", "Retail Therapy", "Buy something in the shop.", "🪙", 100, "collection", func(s): return Wallet.bought_count(s), 1),
			_g("shop_10", "Fashion Victim", "Buy 10 things in the shop.", "🪙", 400, "collection", func(s): return Wallet.bought_count(s), 10),
			_g("items_80", "Museum Piece", "Own 80 pieces of gear.", "🏬", 1500, "collection", func(s): return PlayerState.owned_item_count(s), 80),

			# --- reading (see game/reading.gd): outside the parity fixtures -----------
			_g("read_first", "First Chapter", "Log the first pages you read.", "📖", 50, "read", func(s): return Reading.days(s), 1),
			_g("read_100", "Page Turner", "Read 100 pages.", "📖", 100, "read", func(s): return Reading.pages(s), 100, "pages"),
			_g("read_500", "Bookworm", "Read 500 pages.", "📖", 200, "read", func(s): return Reading.pages(s), 500, "pages"),
			_g("read_1000", "Well Read", "Read 1,000 pages.", "📖", 300, "read", func(s): return Reading.pages(s), 1000, "pages"),
			_g("read_2500", "Bibliophile", "Read 2,500 pages.", "📖", 500, "read", func(s): return Reading.pages(s), 2500, "pages"),
			_g("read_5000", "Walking Library", "Read 5,000 pages.", "📖", 800, "read", func(s): return Reading.pages(s), 5000, "pages"),
			_g("read_10000", "Ten Thousand Pages", "Read 10,000 pages.", "📖", 1200, "read", func(s): return Reading.pages(s), 10000, "pages"),
			_g("read_streak_3", "Three in a Row", "Read three days in a row.", "🔥", 80, "read", func(s): return Reading.best_streak(s), 3, "days"),
			_g("read_streak_7", "A Week of Words", "Read seven days in a row.", "🔥", 150, "read", func(s): return Reading.best_streak(s), 7, "days"),
			_g("read_streak_30", "Thirty Nights", "Read thirty days in a row.", "🔥", 500, "read", func(s): return Reading.best_streak(s), 30, "days"),
			_g("read_streak_100", "A Hundred Nights", "Read a hundred days in a row.", "🔥", 1000, "read", func(s): return Reading.best_streak(s), 100, "days"),
			_g("read_day_50", "Could Not Put It Down", "Read 50 pages in one day.", "⭐", 150, "read", func(s): return Reading.best_day(s), 50, "pages"),
			_g("read_day_100", "Cover to Cover", "Read 100 pages in one day.", "⭐", 300, "read", func(s): return Reading.best_day(s), 100, "pages"),
			_g("read_days_50", "Library Regular", "Read on 50 different days.", "🗓️", 300, "read", func(s): return Reading.days(s), 50, "days"),
			_g("read_both_1", "Brains and Brawn", "Read and train on the same day.", "💪", 100, "read", func(s): return Reading.both_days(s), 1),
			_g("read_both_30", "Scholar Athlete", "Read and train on the same day, thirty times.", "💪", 500, "read", func(s): return Reading.both_days(s), 30, "days"),
	]
