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

const TIER_COLOR = {"bronze": "#c98a5a", "silver": "#c9d1d9", "gold": "#ffc83d", "platinum": "#7fe7ff"}

static var _all = null
static var _by_id = null


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


## Every trophy, in catalog order (do not mutate).
static func all() -> Array:
	if _all == null:
		_all = _build()
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

			# --- body --------------------------------------------------------------
			_g("body_first", "Baseline", "Log your body weight for the first time.", "⚖️", 100, "body", func(s): return s.body.weightEntries, 1),
			_g("body_bf", "Know Thyself", "Log a body fat percentage.", "📏", 100, "body", func(s): return s.body.bfEntries, 1),
			_g("body_photos", "Say Cheese", "Take a full set of progress photos: front, side and back.", "📸", 200, "body", func(s): return s.body.fullSets, 1),
			_g("body_album_5", "Photo Album", "Five check-ins with progress photos.", "🖼️", 300, "body", func(s): return s.body.photoEntries, 5),
			_g("body_album_20", "Time-Lapse", "Twenty check-ins with progress photos.", "🎞️", 800, "body", func(s): return s.body.photoEntries, 20),
			_g("body_streak_4", "Checking In", "Check in four weeks in a row.", "🗓️", 200, "body", func(s): return s.body.bestStreak, 4, "weeks"),
			_g("body_streak_12", "Accountable", "Check in twelve weeks in a row.", "🗓️", 500, "body", func(s): return s.body.bestStreak, 12, "weeks"),
			_g("body_streak_26", "Half a Year in Frames", "Check in twenty-six weeks in a row.", "🗓️", 900, "body", func(s): return s.body.bestStreak, 26, "weeks"),

			# --- collection --------------------------------------------------------
			_g("items_10", "Collector", "Own 10 pieces of gear.", "🎒", 150, "collection", func(s): return PlayerState.owned_item_count(s), 10),
			_g("items_25", "Hoarder", "Own 25 pieces of gear.", "🧳", 400, "collection", func(s): return PlayerState.owned_item_count(s), 25),
			_g("items_45", "Walking Wardrobe", "Own 45 pieces of gear.", "🏬", 900, "collection", func(s): return PlayerState.owned_item_count(s), 45),
			_g("pets_5", "Animal Friend", "Befriend 5 companions.", "🐾", 200, "collection", func(s): return PlayerState.owned_pet_count(s), 5),
			_g("pets_10", "Zookeeper", "Befriend 10 companions.", "🦁", 700, "collection", func(s): return PlayerState.owned_pet_count(s), 10),
	]
