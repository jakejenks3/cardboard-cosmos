class_name PlayerState
extends RefCounted
## The derived player state (port of state.ts). It is a plain Dictionary with
## the same nested shape as the TypeScript `PlayerState`:
##
## xp:      {hero, lift, climb, run, ride}                  total XP per track
## levels:  {hero, lift, climb, run, ride} -> LevelInfo     {level, into, toNext, total, progress}
## ranks:   {lift, climb, run, ride}                        index into Xp.RANKS
## totals:  {sessions, byDiscipline: {lift, climb, run, ride}, durationSec, activeDays,
##           liftVolumeKg, liftReps, liftSets, liftExercises: {normalized name: true},
##           climbSends, climbFlashes, climbAttempts,
##           runDistanceM, runElevationM, rideDistanceM, rideElevationM}
## prs:     {lifts: {normalized name: {weightKg, reps, e1rm, date}},
##           climbMaxSend (null until a send), climbMaxFlash (null until a flash),
##           longestRunM, longestRideM, bestRunElevM, bestRideElevM,
##           bestPaceSecPerKm (null; best average pace over a run of at least 5 km),
##           bestRideSpeedKmh (null; best average speed over a ride of at least 20 km)}
## bests:   "best ever" single-session / single-period feats, used by goals:
##          {maxSetKg, sessionVolumeKg, sessionBwReps, sessionSends, sessionFlashes,
##           sessionAttempts, sessionVPoints (sum of V-grades sent in one session),
##           sessionDurationSec, sessionPrs, daySessions, dayXp, weekDisciplines,
##           monthSessions, gapDays (longest break that was followed by a session),
##           weekendWarrior (0/1), maxRank,
##           benchRatio, squatRatio, deadliftRatio (best lift / bodyweight)}
## achievements: {id: {at: date key, sessionId}}            sessionId = id of the session / check-in / claim
## items:        {id: {at, sessionId?, how: "start"|"drop"|"unlock"}}   (starter kit: at = "", no sessionId)
## pets:         {id: {at, sessionId}}
## campaign: {index (boss currently being fought), damage (dealt to it), totalDamage,
##            defeated: {boss id: {at, sessionId}}}
## body:    {entries, weightEntries, bfEntries, photoEntries (check-ins with at least one photo),
##           fullSets (check-ins with all three angles), firstWeightKg, firstWeightDate,
##           latestWeightKg, latestWeightDate, latestBodyFat, latestBodyFatDate (null until logged),
##           weekFlags: {monday key: bitmask of Derive.BODY_BITS already rewarded},
##           streak (consecutive weeks with a check-in), bestStreak}
## streak:  {current, best, thisWeek, goal}
## chronicle: [{date, kind, icon, title, detail?, val?: {n, unit}, discipline?, ref?}]
##           kind: "start"|"level"|"stage"|"rank"|"achievement"|"item"|"pet"|"boss"|"pr"|"body"
##           ref = catalog id for achievements / items / pets / bosses
## weekCounts: {monday key: sessions}      weekDays: {monday key: weekday bitmask, bit 0 = Monday}
## weekDisc:   {monday key: discipline bitmask}   monthCounts: {"YYYY-MM": n}   dateCounts: {date: n}
## xpByDate: {date: hero XP}   sessionXp: {session id: XP credited}   sessionDamage: {session id: damage}
## bodyXp: {check-in id: XP}   sessionsSinceDrop: int   lastSessionDate: date key or null
## stage: index into Xp.STAGES   title: String   dominant: discipline or null
## seen: {heroLevel, stage, started}       bookkeeping for chronicle entries


## A fresh, fully mutable state. `goal` is the weekly session goal.
static func initial_state(goal) -> Dictionary:
	return {
		"xp": {"hero": 0, "lift": 0, "climb": 0, "run": 0, "ride": 0},
		"levels": {
			"hero": Xp.hero_level(0),
			"lift": Xp.disc_level(0),
			"climb": Xp.disc_level(0),
			"run": Xp.disc_level(0),
			"ride": Xp.disc_level(0),
		},
		"ranks": {"lift": 0, "climb": 0, "run": 0, "ride": 0},
		"totals": {
			"sessions": 0,
			"byDiscipline": {"lift": 0, "climb": 0, "run": 0, "ride": 0},
			"durationSec": 0,
			"activeDays": 0,
			"liftVolumeKg": 0,
			"liftReps": 0,
			"liftSets": 0,
			"liftExercises": {},
			"climbSends": 0,
			"climbFlashes": 0,
			"climbAttempts": 0,
			"runDistanceM": 0,
			"runElevationM": 0,
			"rideDistanceM": 0,
			"rideElevationM": 0,
		},
		"prs": {
			"lifts": {},
			"climbMaxSend": null,
			"climbMaxFlash": null,
			"longestRunM": 0,
			"longestRideM": 0,
			"bestRunElevM": 0,
			"bestRideElevM": 0,
			"bestPaceSecPerKm": null,
			"bestRideSpeedKmh": null,
		},
		"bests": {
			"maxSetKg": 0,
			"sessionVolumeKg": 0,
			"sessionBwReps": 0,
			"sessionSends": 0,
			"sessionFlashes": 0,
			"sessionAttempts": 0,
			"sessionVPoints": 0,
			"sessionDurationSec": 0,
			"sessionPrs": 0,
			"daySessions": 0,
			"dayXp": 0,
			"weekDisciplines": 0,
			"monthSessions": 0,
			"gapDays": 0,
			"weekendWarrior": 0,
			"maxRank": 0,
			"benchRatio": 0,
			"squatRatio": 0,
			"deadliftRatio": 0,
		},
		"achievements": {},
		"items": {},
		"pets": {},
		"campaign": {"index": 0, "damage": 0, "totalDamage": 0, "defeated": {}},
		"body": {
			"entries": 0,
			"weightEntries": 0,
			"bfEntries": 0,
			"photoEntries": 0,
			"fullSets": 0,
			"firstWeightKg": null,
			"firstWeightDate": null,
			"latestWeightKg": null,
			"latestWeightDate": null,
			"latestBodyFat": null,
			"latestBodyFatDate": null,
			"weekFlags": {},
			"streak": 0,
			"bestStreak": 0,
		},
		"streak": {"current": 0, "best": 0, "thisWeek": 0, "goal": goal},
		"chronicle": [],
		"weekCounts": {},
		"weekDays": {},
		"weekDisc": {},
		"monthCounts": {},
		"dateCounts": {},
		"xpByDate": {},
		"sessionXp": {},
		"sessionDamage": {},
		"bodyXp": {},
		"sessionsSinceDrop": 0,
		"lastSessionDate": null,
		"stage": 0,
		"title": "Scrawny Newcomer",
		"dominant": null,
		"seen": {"heroLevel": 1, "stage": 0, "started": false},
	}


static func has_ach(s: Dictionary, id) -> bool:
	return s.achievements.has(id)


static func owned_item_count(s: Dictionary) -> int:
	return s.items.size()


static func owned_pet_count(s: Dictionary) -> int:
	return s.pets.size()


static func defeated_count(s: Dictionary) -> int:
	return s.campaign.defeated.size()
