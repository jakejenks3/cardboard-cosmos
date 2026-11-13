class_name TT
extends RefCounted
## Core data model (port of types.ts). Everything the player "owns" (levels,
## items, pets, achievements) is DERIVED by replaying the session log: the log
## itself, quest claims, cosmetic choices and settings are the only source of
## truth.
##
## Data is plain Dictionaries with the TypeScript field names:
##
## Session (all disciplines):
##   id: String, discipline: "lift"|"climb"|"run"|"ride", date: "YYYY-MM-DD"
##   (local calendar date), createdAt: int (epoch ms, replay order),
##   source: "manual"|"strava"
##   optional: durationSec, notes, title, stravaId,
##             bonusPct (XP multiplier from perks snapshotted at log time, 0.08 = +8%),
##             luckPct (loot-luck multiplier snapshotted at log time)
##   lift:   exercises: [{name: String, sets: [{reps: int, weightKg: number (0 = bodyweight)}]}]
##   climb:  climbs: [{grade: int (V-scale, -1 = VB), result: "flash"|"send"|"attempt", count: int}]
##   run/ride: distanceM: number, elevationM: number
##
## QuestClaim: id, questId ("d:2026-01-01:1" / "w:2026-01-05:2"), xp, claimedAt (epoch ms), date
##
## BodyEntry: id, date, createdAt, optional weightKg, bodyFatPct,
##   photos: {front?, side?, back?} (photo ids), note
##
## Loadout: {slot: item id or null} (every slot optional)
## Profile: name, skin, hairStyle, hairColor, createdAt
## Settings: weightUnit "kg"|"lb", distanceUnit "km"|"mi", sound: bool,
##   weeklyGoal: int (sessions per week needed to keep the streak alive),
##   optional weightStep (size of one +/- tap on a weight, in the chosen unit)

const DISCIPLINES = ["lift", "climb", "run", "ride"]

# Colours validated as a categorical set on the app's dark surfaces
# (CVD-safe adjacent pairs, >= 3:1 contrast).
const DISCIPLINE_META = {
	"lift": {"name": "Lifting", "verb": "Lift", "icon": "🏋️", "color": "#d95926", "stat": "STR", "statName": "Strength"},
	"climb": {"name": "Climbing", "verb": "Climb", "icon": "🧗", "color": "#199e70", "stat": "GRIP", "statName": "Grip"},
	"run": {"name": "Running", "verb": "Run", "icon": "👟", "color": "#3987e5", "stat": "STAM", "statName": "Stamina"},
	"ride": {"name": "Cycling", "verb": "Ride", "icon": "🚴", "color": "#c98500", "stat": "PWR", "statName": "Power"},
}

const PHOTO_ANGLES = ["front", "side", "back"]
const PHOTO_ANGLE_NAMES = {"front": "Front", "side": "Side", "back": "Back"}

const SLOTS = ["head", "face", "body", "hands", "legs", "feet", "back", "accessory", "aura"]
const SLOT_NAMES = {
	"head": "Head",
	"face": "Face",
	"body": "Body",
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
	"back": "Back",
	"accessory": "Accessory",
	"aura": "Aura",
}

const RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLOR = {
	"common": "#b8c0cc",
	"uncommon": "#6fd37a",
	"rare": "#5aa9ff",
	"epic": "#c77dff",
	"legendary": "#ffc83d",
}

const WEIGHT_STEPS = {"kg": [1, 2.5, 5, 10], "lb": [2.5, 5, 10]}

## Read-only: use `TT.DEFAULT_SETTINGS.duplicate(true)` to get a mutable copy.
const DEFAULT_SETTINGS = {
	"weightUnit": "kg",
	"distanceUnit": "km",
	"sound": true,
	"weeklyGoal": 3,
}


## Size of one +/- tap on a weight: the chosen `weightStep` when it is one of
## the options for the unit, otherwise 2.5 (kg) / 5 (lb).
static func weight_step_of(settings: Dictionary) -> float:
	var unit = settings.weightUnit
	var opts: Array = WEIGHT_STEPS[unit]
	var step = settings.get("weightStep")
	if (step is int or step is float) and step != 0 and TTUtil.has_number(opts, step):
		return step
	return 2.5 if unit == "kg" else 5.0
