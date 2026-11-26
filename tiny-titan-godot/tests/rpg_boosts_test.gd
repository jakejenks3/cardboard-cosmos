extends SceneTree
## Unit test for the Realm's boosts and training chests (game/rpg/rpg_boosts.gd,
## RPG_PLAN.md 3): every boost at every tier, in force on the day it is earned
## and the day after and gone on the third, the stronger of two days, the
## well-rested rule, the chest's kinds, tiers, ore and items, what opening it
## pays when the day grew, and the tab dot's cheap check. Made-up logs.
##   godot --headless --path . --script res://tests/rpg_boosts_test.gd
## Prints RPG BOOSTS: n/m passed and exits with 1 when anything fails.

## A Wednesday.
const D = "2026-11-18"
const KNOWN_ICONS = ["moon", "trophy", "flame"]
const PASSIVES = ["stat_dmg", "school_pct", "spd_pct", "crit_add", "en_start", "hp_pct", "heal_pct", "gauge_start", "status_turns", "bounce", "reward"]

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a: float, b: float) -> bool:
	return absf(a - b) <= 1e-9


func day(n: int) -> String:
	return Dates.add_days(D, n)


func _stamp(date: String) -> int:
	_n += 1
	return int(Dates.parse_date_key(date).unix) * 1000 + _n


func sets_of(rows: Array) -> Array:
	var out = []
	for r in rows:
		var one = {"reps": r[0], "weightKg": float(r[1])}
		if r.size() > 2:
			one["holdSec"] = r[2]
		out.append(one)
	return out


func many(count: int, reps: int, kg: float) -> Array:
	var out = []
	for i in range(count):
		out.append([reps, kg])
	return out


func lift(date: String, exercises: Dictionary) -> Dictionary:
	var exs = []
	for lift_name in exercises:
		exs.append({"name": lift_name, "sets": sets_of(exercises[lift_name])})
	var at = _stamp(date)
	return {"id": "l%d" % _n, "discipline": "lift", "date": date, "createdAt": at, "source": "manual", "exercises": exs}


func run(date: String, m: float, sec: int = 0) -> Dictionary:
	var at = _stamp(date)
	var s = {"id": "r%d" % _n, "discipline": "run", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0}
	if sec > 0:
		s["durationSec"] = sec
	return s


func climb(date: String, rows: Array) -> Dictionary:
	var climbs = []
	for r in rows:
		climbs.append({"grade": r[0], "result": r[1], "count": r[2]})
	var at = _stamp(date)
	return {"id": "c%d" % _n, "discipline": "climb", "date": date, "createdAt": at, "source": "manual", "climbs": climbs}


func ride(date: String, m: float) -> Dictionary:
	var at = _stamp(date)
	return {"id": "b%d" % _n, "discipline": "ride", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0}


func walk(date: String, m: float) -> Dictionary:
	var at = _stamp(date)
	return {"id": "w%d" % _n, "discipline": "misc", "kind": "vest_walk", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0, "loadKg": 9.0}


func read(date: String, pages: int) -> Dictionary:
	var at = _stamp(date)
	return {"id": "p%d" % _n, "date": date, "pages": pages, "createdAt": at}


func perfect(date: String) -> Dictionary:
	var at = _stamp(date)
	return {"id": "q%d" % _n, "questId": "t:%s:perfect" % date, "xp": 300, "claimedAt": at, "date": date}


func blank_save(du: String = "km") -> Dictionary:
	return {"sessions": [], "reading": [], "books": [], "body": [], "claims": [],
		"pt": {"clamshell - band": {"name": "Clamshell - Band", "perWeek": 3}},
		"settings": {"weightUnit": "kg", "distanceUnit": du, "weeklyGoal": 3, "sound": true}}


func save_of(sessions: Array, reading: Array = [], claims: Array = []) -> Dictionary:
	var save = blank_save()
	save.sessions = sessions
	save.reading = reading
	save.claims = claims
	return save


func state_of(save: Dictionary, today: String) -> Dictionary:
	return Derive.derive({"sessions": save.sessions, "claims": save.claims, "body": save.body, "purchases": [], "reading": save.reading,
		"weeklyGoal": int(save.settings.weeklyGoal), "today": today})


func inp(save: Dictionary, today: String, with_state: bool = false) -> Dictionary:
	return {"sessions": save.sessions, "state": state_of(save, today) if with_state else {}, "reading": save.reading, "books": save.books,
		"body": save.body, "claims": save.claims, "settings": save.settings, "marks": save.pt, "today": today}


func find(boosts: Array, id: String):
	for b in boosts:
		if str(b.id) == id:
			return b
	return null


## A boost of a save on the day it was earned, the day after, and the day after that.
func three_days(save: Dictionary, id: String, earned: String = D) -> Array:
	var out = []
	for k in range(3):
		out.append(find(RpgBoosts.active(inp(save, Dates.add_days(earned, k))), id))
	return out


## Is this boost earned on `earned`, in force then and the day after, and gone on the third?
func holds_two_days(save: Dictionary, id: String, tier: int, earned: String = D) -> bool:
	var b = three_days(save, id, earned)
	return b[0] != null and b[1] != null and b[2] == null and int(b[0].tier) == tier and int(b[1].tier) == tier \
		and str(b[0].from) == earned and str(b[0].until) == Dates.add_days(earned, 1) and str(b[1].from) == earned and str(b[1].until) == Dates.add_days(earned, 1) \
		and str(b[0].why).contains("today") and str(b[1].why).contains("yesterday") and b[0].fx == b[1].fx


func effect(b, p: String):
	if b == null:
		return null
	for e in b.fx:
		if str(e.p) == p:
			return e
	return null


func ids(boosts: Array) -> Array:
	return boosts.map(func(b): return str(b.id))


func _init() -> void:
	# --- an empty log ------------------------------------------------------------
	var none = blank_save()
	ok(RpgBoosts.active(inp(none, D)).is_empty() and RpgBoosts.active({}).is_empty(), "an empty log has no boosts", RpgBoosts.active(inp(none, D)))
	ok(RpgBoosts.chest(inp(none, D), D) == null and RpgBoosts.waiting(inp(none, D), RpgSave.empty()).is_empty() and not RpgBoosts.chest_waiting({}, [], RpgSave.empty(), D)
		and RpgBoosts.schools([]).is_empty() and RpgBoosts.fx([]).is_empty(), "and no chest, no dot, no favoured school")

	# --- pumps: every body stat, every tier ----------------------------------------
	# (lifts that work little else: the stat's own pump is what is looked at)
	var only = {"chest": "Chest Fly - Cable", "shoulders": "Lateral Raise - Dumbbell", "arms": "Tricep Kickback - Dumbbell", "back": "Straight-Arm Pulldown - Rope",
		"core": "Crunch", "legs": "Leg Extension"}
	var bad = []
	for stat in RpgDefs.BODY:
		var under = save_of([lift(D, {only[stat]: many(2, 10, 10)})])
		if find(RpgBoosts.active(inp(under, D)), "pump_" + stat) != null:
			bad.append("%s: 2 sets gave a pump" % stat)
		for t in range(3):
			var count = int(RpgDefs.PUMP_SETS[t])
			var save = save_of([lift(D, {only[stat]: many(count, 10, 10)})])
			var b = find(RpgBoosts.active(inp(save, D)), "pump_" + stat)
			var e = effect(b, "stat_dmg")
			if b == null or e == null or str(e.stat) != stat or not near(float(e.pct), float(RpgDefs.PUMP_PCT[t])) or b.fx.size() != 1 or not holds_two_days(save, "pump_" + stat, t + 1):
				bad.append("%s at %d sets: %s" % [stat, count, str(b)])
			elif str(b.name) != "%s Pump" % str(RpgDefs.STAT_NAMES[stat]) or str(b.icon) != str(RpgDefs.STAT_ICONS[stat]) or str(b.school) != str(RpgDefs.STAT_SCHOOL[stat]) \
				or str(b.text) != "%s moves +%d%% damage" % [str(RpgDefs.STAT_NAMES[stat]), int(round(float(RpgDefs.PUMP_PCT[t]) * 100.0))] or not str(b.why).begins_with("%d " % count):
				bad.append("%s at %d sets, its words: %s" % [stat, count, str(b)])
	ok(bad.is_empty(), "a pump for each body stat: 3 sets +10%, 6 sets +15%, 9 sets +20%, on the day and the day after, gone on the third", bad)
	ok(RpgDefs.PUMP_SETS == [3.0, 6.0, 9.0] and RpgDefs.PUMP_PCT == [0.10, 0.15, 0.20], "(the plan's tiers)")
	var chest9 = find(RpgBoosts.active(inp(save_of([lift(D, {"Chest Fly - Cable": many(9, 12, 10)})]), D)), "pump_chest")
	ok(chest9 != null and str(chest9.name) == "Chest Pump" and str(chest9.text) == "Chest moves +20% damage" and str(chest9.why) == "9 chest sets today" and str(chest9.icon) == "st_chest" and str(chest9.school) == "push"
		and chest9.fx == [{"p": "stat_dmg", "stat": "chest", "pct": 0.20}] and str(chest9.from) == D and str(chest9.until) == day(1) and str(chest9.id) == "pump_chest", "the Chest Pump, in full", chest9)
	var bench = save_of([lift(D, {"Bench Press - Barbell": many(6, 5, 60)})])
	var from_bench = RpgBoosts.active(inp(bench, D))
	ok(ids(from_bench) == ["pump_chest", "pump_shoulders", "pump_arms"] and int(find(from_bench, "pump_chest").tier) == 2 and int(find(from_bench, "pump_arms").tier) == 1 and str(find(from_bench, "pump_arms").why) == "3 arm sets today",
		"six sets of bench press: a chest pump, and smaller ones for what it also works", from_bench.map(func(b): return [b.id, b.tier, b.why]))
	var pt_only = save_of([lift(D, {"Clamshell - Band": many(9, 15, 0), "Hamstring Stretch": [[1, 0, 30], [1, 0, 30], [1, 0, 30]]})])
	ok(ids(RpgBoosts.active(inp(pt_only, D))) == ["limber"], "physical therapy and stretches pump nothing", ids(RpgBoosts.active(inp(pt_only, D))))
	var climb_only = save_of([climb(D, [[3, "send", 6]])])
	ok(find(RpgBoosts.active(inp(climb_only, D)), "pump_arms") == null, "a climbing session is no arm pump (it is Chalked Up)")
	var two_sessions = save_of([lift(D, {"Leg Extension": many(4, 10, 40)}), lift(D, {"Leg Curl": many(5, 10, 30)})])
	ok(int(find(RpgBoosts.active(inp(two_sessions, D)), "pump_legs").tier) == 3, "two sessions of a day add up")

	# --- the stronger of two days ---------------------------------------------------
	var big_then_small = save_of([lift(day(-1), {"Chest Fly - Cable": many(9, 12, 10)}), lift(D, {"Chest Fly - Cable": many(3, 12, 10)})])
	var b1 = find(RpgBoosts.active(inp(big_then_small, D)), "pump_chest")
	ok(int(b1.tier) == 3 and str(b1.from) == day(-1) and str(b1.until) == D and str(b1.why) == "9 chest sets yesterday", "yesterday's bigger pump counts today, and ends today", b1)
	ok(int(find(RpgBoosts.active(inp(big_then_small, day(1))), "pump_chest").tier) == 1 and find(RpgBoosts.active(inp(big_then_small, day(2))), "pump_chest") == null, "tomorrow today's smaller one is left; then none")
	var small_then_big = save_of([lift(day(-1), {"Chest Fly - Cable": many(3, 12, 10)}), lift(D, {"Chest Fly - Cable": many(6, 12, 10)})])
	var b2 = find(RpgBoosts.active(inp(small_then_big, D)), "pump_chest")
	ok(int(b2.tier) == 2 and str(b2.from) == D and str(b2.until) == day(1), "today's bigger pump counts", b2)
	var same_twice = save_of([lift(day(-1), {"Chest Fly - Cable": many(6, 12, 10)}), lift(D, {"Chest Fly - Cable": many(6, 12, 10)})])
	var b3 = find(RpgBoosts.active(inp(same_twice, D)), "pump_chest")
	ok(int(b3.tier) == 2 and str(b3.from) == D and str(b3.until) == day(1) and RpgBoosts.active(inp(same_twice, D)).filter(func(b): return str(b.id) == "pump_chest").size() == 1,
		"as strong on both days: once, and today's (it lasts until tomorrow)", b3)

	# --- second wind ----------------------------------------------------------------
	var short_run = save_of([run(D, 3000.0, 1000)])
	var sw1 = find(RpgBoosts.active(inp(short_run, D)), "second_wind")
	ok(sw1 != null and sw1.fx == [{"p": "school_pct", "school": "speed", "pct": 0.10}, {"p": "spd_pct", "pct": 0.05}] and str(sw1.text) == "Speed moves +10%, speed +5%"
		and str(sw1.why) == "A 3 km run today" and str(sw1.school) == "speed" and str(sw1.name) == "Second Wind" and holds_two_days(short_run, "second_wind", 1), "a run: Speed moves +10%, speed +5%", sw1)
	var long_run = save_of([run(D, 2000.0), run(D, 5000.0, 1600)])
	var sw2 = find(RpgBoosts.active(inp(long_run, D)), "second_wind")
	ok(sw2 != null and sw2.fx == [{"p": "school_pct", "school": "speed", "pct": 0.15}, {"p": "spd_pct", "pct": 0.08}, {"p": "en_start", "n": 1}]
		and str(sw2.text) == "Speed moves +15%, speed +8%, +1 energy at the start" and holds_two_days(long_run, "second_wind", 2), "5 km or more: +15%, +8% and 1 energy at the start", sw2)
	ok(int(find(RpgBoosts.active(inp(save_of([run(D, 4900.0)]), D)), "second_wind").tier) == 1 and int(find(RpgBoosts.active(inp(save_of([run(D, 3.1 * 1609.344)]), D)), "second_wind").tier) == 2,
		"4,900 m is not 5 km; a run typed as 3.1 miles is")
	var miles = save_of([run(D, 5.0 * 1609.344)])
	miles.settings.distanceUnit = "mi"
	ok(str(find(RpgBoosts.active(inp(miles, D)), "second_wind").why) == "A 5 mi run today", "said in miles to a player who counts in miles", find(RpgBoosts.active(inp(miles, D)), "second_wind").why)
	ok(find(RpgBoosts.active(inp(save_of([ride(D, 40000.0), walk(D, 5000.0)]), D)), "second_wind") == null, "a ride or a vest walk is no run")

	# --- chalked up -----------------------------------------------------------------
	var no_flash = save_of([climb(D, [[3, "send", 4], [4, "attempt", 3], [2, "flash", 0]])])
	var cu1 = find(RpgBoosts.active(inp(no_flash, D)), "chalked_up")
	ok(cu1 != null and cu1.fx == [{"p": "school_pct", "school": "grip", "pct": 0.10}, {"p": "crit_add", "v": 0.04}] and str(cu1.text) == "Grip moves +10%, crit +4%" and str(cu1.school) == "grip" and holds_two_days(no_flash, "chalked_up", 1),
		"a climbing session: Grip moves +10%, crit +4%", cu1)
	var flashed = save_of([climb(D, [[3, "send", 4]]), climb(D, [[2, "flash", 1]])])
	var cu2 = find(RpgBoosts.active(inp(flashed, D)), "chalked_up")
	ok(cu2 != null and cu2.fx == [{"p": "school_pct", "school": "grip", "pct": 0.15}, {"p": "crit_add", "v": 0.06}] and str(cu2.why) == "A climbing session today, with a flash" and holds_two_days(flashed, "chalked_up", 2),
		"with a flash that day: +15%, +6%", cu2)

	# --- sharp mind -----------------------------------------------------------------
	ok(find(RpgBoosts.active(inp(save_of([], [read(D, 9)]), D)), "sharp_mind") == null, "nine pages: nothing yet")
	bad = []
	for t in range(3):
		var pages = int(RpgDefs.READ_PAGES[t])
		var save = save_of([], [read(D, pages - 4), read(D, 4)])
		var b = find(RpgBoosts.active(inp(save, D)), "sharp_mind")
		var e = effect(b, "school_pct")
		if b == null or e == null or str(e.school) != "mind" or not near(float(e.pct), float(RpgDefs.READ_PCT[t])) or not holds_two_days(save, "sharp_mind", t + 1) or (effect(b, "status_turns") != null) != (t == 2):
			bad.append("%d pages: %s" % [pages, str(b)])
	ok(bad.is_empty() and RpgDefs.READ_PAGES == [10, 30, 50] and RpgDefs.READ_PCT == [0.08, 0.12, 0.15], "10 pages: Mind moves +8%; 30: +12%; 50: +15%", bad)
	var sm3 = find(RpgBoosts.active(inp(save_of([], [read(D, 64)]), D)), "sharp_mind")
	ok(sm3.fx == [{"p": "school_pct", "school": "mind", "pct": 0.15}, {"p": "status_turns", "on": "debuff", "add": 1}] and str(sm3.text) == "Mind moves +15%, your debuffs last 1 turn longer" and str(sm3.why) == "64 pages read today",
		"at 50 pages the hero's debuffs last a turn longer too", sm3)

	# --- limber ---------------------------------------------------------------------
	ok(find(RpgBoosts.active(inp(save_of([lift(D, {"Clamshell - Band": many(2, 15, 0)})]), D)), "limber") == null, "two mobility sets: nothing yet")
	var some_pt = save_of([lift(D, {"Clamshell - Band": many(2, 15, 0), "Calf Stretch - Wall": [[1, 0, 30]], "Squat - Barbell": many(2, 5, 60)})])
	var lb1 = find(RpgBoosts.active(inp(some_pt, D)), "limber")
	ok(lb1 != null and lb1.fx == [{"p": "bounce"}] and str(lb1.text) == "The first debuff of a battle bounces off" and str(lb1.school) == "flow" and holds_two_days(some_pt, "limber", 1), "three mobility sets: the first debuff bounces off", lb1)
	var much_pt = save_of([lift(D, {"Clamshell - Band": many(6, 15, 0)}), lift(D, {"Hamstring Stretch": [[1, 0, 30], [1, 0, 30], [1, 0, 30]]})])
	var lb2 = find(RpgBoosts.active(inp(much_pt, D)), "limber")
	ok(lb2 != null and lb2.fx == [{"p": "bounce"}, {"p": "heal_pct", "pct": 0.20}] and str(lb2.text) == "The first debuff of a battle bounces off, healing +20%" and holds_two_days(much_pt, "limber", 2), "nine: healing +20% too", lb2)

	# --- well rested ----------------------------------------------------------------
	var worked = [lift(day(-5), {"Squat - Barbell": many(3, 5, 60)}), lift(day(-3), {"Bench Press - Barbell": many(3, 5, 60)})]
	var rested = save_of(worked.duplicate())
	var wr = find(RpgBoosts.active(inp(rested, D)), "well_rested")
	ok(wr != null and wr.fx == [{"p": "hp_pct", "pct": 0.10}, {"p": "en_start", "n": 2}] and str(wr.text) == "Max HP +10%, +2 energy at the start" and str(wr.school) == "" and str(wr.icon) == "moon"
		and str(wr.from) == D and str(wr.until) == D and str(wr.why) == "No lifting yesterday, after 2 training days in the 6 before it", "no lifting yesterday after two training days: max HP +10%, 2 energy; today only", wr)
	var lifted_yday = save_of(worked + [lift(day(-1), {"Squat - Barbell": many(3, 5, 60)})])
	ok(find(RpgBoosts.active(inp(lifted_yday, D)), "well_rested") == null, "strength work yesterday: not rested")
	var soft_yday = save_of(worked + [run(day(-1), 4000.0), climb(day(-1), [[2, "send", 3]]), lift(day(-1), {"Clamshell - Band": many(3, 15, 0)})])
	ok(find(RpgBoosts.active(inp(soft_yday, D)), "well_rested") != null, "a run, a climb and PT yesterday are still a rest from lifting")
	var one_before = save_of([lift(day(-3), {"Squat - Barbell": many(3, 5, 60)})])
	ok(find(RpgBoosts.active(inp(one_before, D)), "well_rested") == null, "one training day in the six before: no boost for doing nothing")
	var too_old = save_of([lift(day(-9), {"Squat - Barbell": many(3, 5, 60)}), lift(day(-8), {"Squat - Barbell": many(3, 5, 60)}), lift(day(-2), {"Squat - Barbell": many(3, 5, 60)})])
	ok(find(RpgBoosts.active(inp(too_old, D)), "well_rested") == null and find(RpgBoosts.active(inp(too_old, day(-1))), "well_rested") == null, "the six days before yesterday, no further back; and the day after a lift is no rest day")
	var lifting_today = save_of(worked + [lift(D, {"Squat - Barbell": many(3, 5, 60)})])
	ok(find(RpgBoosts.active(inp(lifting_today, D)), "well_rested") != null and find(RpgBoosts.active(inp(lifting_today, day(1))), "well_rested") == null, "lifting today does not take it away; tomorrow it is gone")
	var two_rest_days = find(RpgBoosts.active(inp(rested, day(1))), "well_rested")
	ok(two_rest_days != null and str(two_rest_days.from) == day(1) and find(RpgBoosts.active(inp(rested, day(4))), "well_rested") == null, "a second rest day is rested too; after the training days have slid out of the six, no more")

	# --- record rush ----------------------------------------------------------------
	var record = save_of([lift(day(-9), {"Bench Press - Barbell": many(3, 5, 60)}), lift(D, {"Bench Press - Barbell": many(3, 5, 65)})])
	var st_record = state_of(record, D)
	ok(st_record.chronicle.any(func(e): return str(e.kind) == "pr" and str(e.date) == D), "(a heavier bench press is a record in the chronicle)")
	var rr = find(RpgBoosts.active(inp(record, D, true)), "record_rush")
	ok(rr != null and rr.fx == [{"p": "gauge_start", "n": 50}] and str(rr.text) == "The ultimate gauge starts at 50" and str(rr.why).begins_with("A record today: ") and str(rr.from) == D and str(rr.until) == day(1), "a record: the gauge starts at 50", rr)
	var rr2 = find(RpgBoosts.active(inp(record, day(1), true)), "record_rush")
	ok(rr2 != null and str(rr2.from) == D and str(rr2.until) == day(1) and str(rr2.why).begins_with("A record yesterday: ") and find(RpgBoosts.active(inp(record, day(2), true)), "record_rush") == null, "and the day after; gone on the third")
	var made_up = inp(none, D)
	made_up.state = {"chronicle": [{"date": day(-1), "kind": "pr", "title": "Longest run"}, {"date": D, "kind": "level", "title": "Level 4"}, {"date": day(-2), "kind": "pr", "title": "Old"}]}
	var rr3 = find(RpgBoosts.active(made_up), "record_rush")
	ok(rr3 != null and str(rr3.why) == "A record yesterday: Longest run" and RpgBoosts.active(made_up).size() == 1, "only entries of kind pr, of today and yesterday", RpgBoosts.active(made_up))
	ok(find(RpgBoosts.active(inp(record, D)), "record_rush") == null, "no state, no record known")

	# --- golden day, on a roll ------------------------------------------------------
	var golden = save_of([lift(D, {"Squat - Barbell": many(3, 5, 60)})], [], [perfect(D), {"id": "x", "questId": "t:%s:show" % D, "xp": 50, "claimedAt": 3, "date": D}])
	var gd = find(RpgBoosts.active(inp(golden, D)), "golden_day")
	ok(gd != null and gd.fx == [{"p": "reward", "what": "ore", "pct": 0.25}] and str(gd.text) == "Ore from battles +25%" and str(gd.icon) == "chest_gold" and holds_two_days(golden, "golden_day", 1), "the perfect-day chest claimed: ore +25%", gd)
	ok(find(RpgBoosts.active(inp(save_of([lift(D, {"Squat - Barbell": many(3, 5, 60)})], [], [{"id": "x", "questId": "t:%s:show" % D, "xp": 50, "claimedAt": 3, "date": D}]), D)), "golden_day") == null, "another claim is no golden day")
	var late_claim = save_of([], [], [{"id": "q", "questId": "t:%s:perfect" % day(-1), "xp": 300, "claimedAt": 9, "date": D}])
	var gd2 = find(RpgBoosts.active(inp(late_claim, D)), "golden_day")
	ok(gd2 != null and str(gd2.from) == day(-1) and str(gd2.until) == D, "yesterday's chest opened today is yesterday's golden day", gd2)
	var three_of_seven = save_of([run(day(-6), 2000.0), ride(day(-4), 9000.0), walk(day(-2), 3000.0)])
	ok(find(RpgBoosts.active(inp(three_of_seven, D)), "on_a_roll") == null, "three training days of the last seven: not yet")
	var four_of_seven = save_of([run(day(-6), 2000.0), ride(day(-4), 9000.0), walk(day(-2), 3000.0), lift(D, {"Clamshell - Band": many(1, 15, 0)})])
	var roll = find(RpgBoosts.active(inp(four_of_seven, D)), "on_a_roll")
	ok(roll != null and roll.fx == [{"p": "reward", "what": "ore", "pct": 0.10}] and str(roll.text) == "Ore from battles +10%" and str(roll.why) == "Trained on 4 of the 7 days up to today" and str(roll.from) == D and str(roll.until) == day(1),
		"four of the last seven (any kind of session): ore +10%", roll)
	var roll_next = find(RpgBoosts.active(inp(four_of_seven, day(1))), "on_a_roll")
	ok(roll_next != null and str(roll_next.from) == D and str(roll_next.until) == day(1) and find(RpgBoosts.active(inp(four_of_seven, day(2))), "on_a_roll") == null, "in force the day after as well, gone on the third")
	var seven_ago = save_of([run(day(-7), 2000.0), ride(day(-6), 9000.0), walk(day(-4), 3000.0), run(day(-2), 3000.0)])
	var roll_y = find(RpgBoosts.active(inp(seven_ago, D)), "on_a_roll")
	ok(roll_y != null and str(roll_y.from) == day(-1) and str(roll_y.until) == D, "earned yesterday (four of the seven days up to yesterday), still on today", roll_y)

	# --- a day with everything: D, D+1, D+2 ------------------------------------------
	var full = save_of([lift(day(-6), {"Squat - Barbell": many(3, 5, 50)}), run(day(-4), 3000.0), lift(day(-2), {"Squat - Barbell": many(3, 5, 55)}),
		lift(D, {"Squat - Barbell": many(9, 5, 60), "Bench Press - Barbell": many(9, 5, 60), "Lat Pulldown": many(9, 10, 40), "Lateral Raise - Dumbbell": many(9, 12, 6), "Crunch": many(9, 15, 0),
			"Clamshell - Band": many(9, 15, 0)}), run(D, 6000.0, 2000), climb(D, [[3, "flash", 2]])], [read(D, 55)], [perfect(D)])
	var on_d = RpgBoosts.active(inp(full, D, true))
	ok(ids(on_d) == ["pump_chest", "pump_shoulders", "pump_arms", "pump_back", "pump_core", "pump_legs", "second_wind", "chalked_up", "sharp_mind", "limber", "well_rested", "record_rush", "golden_day", "on_a_roll"],
		"a day with everything, after a rest day: all fourteen, in the plan's order", ids(on_d))
	var on_d1 = RpgBoosts.active(inp(full, day(1), true))
	ok(ids(on_d1) == ["pump_chest", "pump_shoulders", "pump_arms", "pump_back", "pump_core", "pump_legs", "second_wind", "chalked_up", "sharp_mind", "limber", "record_rush", "golden_day", "on_a_roll"]
		and on_d1.all(func(b): return str(b.from) == D and str(b.until) == day(1)), "the day after: all but well rested (yesterday was a lifting day), each until today", ids(on_d1))
	var on_d2 = RpgBoosts.active(inp(full, day(2), true))
	ok(ids(on_d2) == ["well_rested"], "the third day: every one of them gone (and a rest day's own boost instead)", ids(on_d2))
	bad = []
	for b in on_d:
		for key in ["id", "name", "icon", "school", "text", "why", "from", "until", "fx", "tier"]:
			if not b.has(key):
				bad.append("%s has no %s" % [b.id, key])
		if str(b.name) == "" or str(b.text) == "" or str(b.why) == "" or b.fx.is_empty() or not (RpgDefs.ICONS.has(str(b.icon)) or KNOWN_ICONS.has(str(b.icon))) or not (str(b.school) == "" or RpgDefs.SCHOOLS.has(str(b.school))):
			bad.append("%s is not whole: %s" % [b.id, str(b)])
		for e in b.fx:
			if not PASSIVES.has(str(e.get("p", ""))):
				bad.append("%s: an effect outside the vocabulary: %s" % [b.id, str(e)])
			if e.has("pct") and not (float(e.pct) > 0.0 and float(e.pct) < 1.0):
				bad.append("%s: a percentage that is not a fraction: %s" % [b.id, str(e)])
			if e.has("stat") and not RpgDefs.STATS.has(str(e.stat)):
				bad.append("%s: an unknown stat" % b.id)
			if e.has("school") and not RpgDefs.SCHOOLS.has(str(e.school)):
				bad.append("%s: an unknown school" % b.id)
	ok(bad.is_empty(), "every boost is whole: its words, an icon that exists, effects of the plan's vocabulary, fractions", bad)
	var all_fx = RpgBoosts.fx(on_d)
	var kinds_used = {}
	for e in all_fx:
		kinds_used[str(e.p)] = true
	ok(PASSIVES.all(func(p): return kinds_used.has(p)) and all_fx.size() == 20, "together they use every effect kind the plan names for boosts", [kinds_used.keys(), all_fx.size()])
	ok(TTUtil.normalize_json(JSON.parse_string(JSON.stringify(all_fx))) == all_fx, "the effects survive a trip through JSON as they are")
	var again = RpgBoosts.active(inp(full, D, true))
	ok(JSON.stringify(again) == JSON.stringify(on_d), "asked twice, the same answer; and the input is left as it was")

	# --- the schools the boosts favour ------------------------------------------------
	ok(RpgBoosts.schools(on_d) == ["push", "pull", "legs", "speed", "grip", "mind"], "a day with everything favours all six attack schools", RpgBoosts.schools(on_d))
	var mapping = {"pump_chest": ["push"], "pump_shoulders": ["push"], "pump_arms": ["push", "pull"], "pump_back": ["pull"], "pump_core": ["legs"], "pump_legs": ["legs"],
		"second_wind": ["speed"], "chalked_up": ["grip"], "sharp_mind": ["mind"], "limber": [], "well_rested": [], "record_rush": [], "golden_day": [], "on_a_roll": []}
	bad = []
	for b in on_d:
		if RpgBoosts.schools([b]) != mapping[str(b.id)]:
			bad.append("%s -> %s" % [b.id, str(RpgBoosts.schools([b]))])
	ok(bad.is_empty(), "each boost's schools: chest and shoulders push, back pull, arms push and pull, legs and core legs, a run speed, a climb grip, pages mind; the rest none", bad)
	var back_day = save_of([lift(D, {"Straight-Arm Pulldown - Rope": many(9, 12, 20), "Chest Fly - Cable": many(3, 12, 10)}), run(D, 3000.0)])
	ok(RpgBoosts.schools(RpgBoosts.active(inp(back_day, D))) == ["pull", "push", "speed"], "the most favoured school first, then the schools' own order", RpgBoosts.schools(RpgBoosts.active(inp(back_day, D))))

	# --- the training chest ---------------------------------------------------------
	var c_lift = RpgBoosts.chest(inp(save_of([lift(D, {"Squat - Barbell": many(3, 5, 60)})]), D), D)
	ok(c_lift != null and c_lift.kinds == ["lift"] and str(c_lift.tier) == "wood" and int(c_lift.ore) == 55 and c_lift.items.size() == 1 and int(c_lift.items[0].n) == 1 and not bool(c_lift.rune) and str(c_lift.date) == D,
		"a lifting day: a wooden chest, 30 + 25 ore, one item", c_lift)
	var kinds = {
		"run": save_of([run(D, 3000.0)]), "climb": save_of([climb(D, [[2, "attempt", 3]])]), "read": save_of([], [read(D, 10)]),
		"mobility": save_of([lift(D, {"Clamshell - Band": many(1, 15, 0)})]), "other": save_of([ride(D, 9000.0)]),
	}
	bad = []
	for k in kinds:
		var c = RpgBoosts.chest(inp(kinds[k], D), D)
		if c == null or c.kinds != [k] or int(c.ore) != 55 or str(c.tier) != "wood":
			bad.append("%s: %s" % [k, str(c)])
	ok(bad.is_empty() and RpgBoosts.chest(inp(save_of([walk(D, 3000.0)]), D), D).kinds == ["other"], "each kind of day on its own: a run, a climb, 10 pages, a mobility set, a ride or a vest walk", bad)
	ok(RpgBoosts.chest(inp(save_of([], [read(D, 9)]), D), D) == null and RpgBoosts.chest(inp(save_of([lift(D, {"Squat - Barbell": [[0, 60]]})]), D), D).kinds == ["other"],
		"nine pages are no chest; a session with nothing done in it is still a session")
	var two = RpgBoosts.chest(inp(save_of([lift(D, {"Squat - Barbell": many(3, 5, 60), "Clamshell - Band": many(3, 15, 0)})]), D), D)
	ok(two.kinds == ["lift", "mobility"] and int(two.ore) == 80 and str(two.tier) == "wood" and two.items.size() == 1, "lifting with PT in it: two kinds, 80 ore, still wood", two)
	var three = RpgBoosts.chest(inp(save_of([lift(D, {"Squat - Barbell": many(3, 5, 60)}), run(D, 3000.0)], [read(D, 12)]), D), D)
	var n_items = 0
	for it in three.items:
		n_items += int(it.n)
	ok(three.kinds == ["lift", "run", "read"] and int(three.ore) == 105 and str(three.tier) == "iron" and n_items == 2 and not bool(three.rune), "three kinds: an iron chest, 105 ore, two items", three)
	var all_six = save_of([lift(D, {"Squat - Barbell": many(3, 5, 60), "Clamshell - Band": many(3, 15, 0)}), run(D, 3000.0), climb(D, [[2, "send", 3]]), ride(D, 9000.0)], [read(D, 30)])
	var six = RpgBoosts.chest(inp(all_six, D), D)
	ok(six.kinds == RpgBoosts.KINDS and int(six.ore) == 30 + 25 * 6 and str(six.tier) == "iron", "all six kinds, in the chest's order: 180 ore", six)
	var gold_save = save_of([lift(D, {"Squat - Barbell": many(3, 5, 60)})], [], [perfect(D)])
	var gold = RpgBoosts.chest(inp(gold_save, D), D)
	n_items = 0
	for it in gold.items:
		n_items += int(it.n)
	ok(gold.kinds == ["lift"] and str(gold.tier) == "gold" and int(gold.ore) == 55 and n_items == 3 and bool(gold.rune), "a perfect day: a gold chest, three items and a rune", gold)
	var pool = RpgBoosts.CHEST_ITEMS.map(func(r): return str(r[0]))
	var plan_items = ["Protein Shake", "Mega Shake", "Electrolytes", "Smelling Salts", "Chalk Ball", "Energy Gel", "Ice Pack", "Pre-Workout"]
	ok(gold.items.all(func(it): return pool.has(str(it.id)) and int(it.n) >= 1) and pool.size() == 8 and plan_items.all(func(n): return pool.has(RpgDefs.id_of(n)))
		and RpgBoosts.CHEST_ITEMS.all(func(r): return float(r[1]) > 0.0), "its items are the plan's eight belt items (ids as the catalog makes them from the names)", gold.items)
	ok(JSON.stringify(RpgBoosts.chest(inp(gold_save, D), D)) == JSON.stringify(gold) and RpgBoosts.chest_items(D, 3) == RpgBoosts.chest_items(D, 3), "seeded by the date: the same chest every time it is asked for")
	var seen = {}
	var grew = true
	for k in range(40):
		var date = day(k * 3)
		var a = RpgBoosts.chest_items(date, 1)
		var b = RpgBoosts.chest_items(date, 3)
		seen[str(a[0].id)] = true
		var kept = false
		for it in b:
			if str(it.id) == str(a[0].id):
				kept = true
		grew = grew and kept
	ok(seen.size() >= 4 and grew, "other dates hold other items; a chest that grows keeps what it had", seen.keys())
	var day_before = save_of([lift(day(-1), {"Squat - Barbell": many(3, 5, 60)}), run(day(-2), 3000.0)])
	ok(RpgBoosts.chest(inp(day_before, D), day(-1)) != null and RpgBoosts.chest(inp(day_before, D), day(-1)).kinds == ["lift"] and RpgBoosts.chest(inp(day_before, D), day(-2)) == null
		and RpgBoosts.chest(inp(day_before, D), day(1)) == null and RpgBoosts.chest(inp(day_before, D), D) == null,
		"yesterday's chest can still be opened; the day before's cannot, nor tomorrow's; a day with nothing has none")

	# --- what opening it pays (the difference rule) ---------------------------------
	var rpg = RpgSave.empty()
	var pay = RpgBoosts.chest_pay(three, rpg)
	ok(bool(pay.first) and int(pay.ore) == 105 and int(pay.kinds) == 3 and pay.items == three.items and not bool(pay.rune) and str(pay.date) == D and RpgBoosts.pays(three, rpg), "never opened: all of it", pay)
	rpg.chests[D] = 1
	var grown = RpgBoosts.chest_pay(three, rpg)
	ok(not bool(grown.first) and int(grown.ore) == 50 and grown.items.is_empty() and not bool(grown.rune) and int(grown.kinds) == 3 and RpgBoosts.pays(three, rpg), "opened at one kind, the day grew to three: the ore of the two that came since, nothing else", grown)
	rpg.chests[D] = 3
	var done = RpgBoosts.chest_pay(three, rpg)
	ok(not bool(done.first) and int(done.ore) == 0 and done.items.is_empty() and not RpgBoosts.pays(three, rpg), "paid in full: nothing more", done)
	rpg.chests[D] = 5
	ok(int(RpgBoosts.chest_pay(three, rpg).ore) == 0 and int(RpgBoosts.chest_pay(three, rpg).kinds) == 5, "paid for more than the day now holds (something was deleted): nothing, and nothing is forgotten")
	rpg.chests[D] = 1
	ok(int(RpgBoosts.chest_pay(gold, rpg).ore) == 0 and not bool(RpgBoosts.chest_pay(gold, rpg).rune), "a chest opened before the day turned perfect pays no second time")
	var both_days = save_of([lift(day(-1), {"Squat - Barbell": many(3, 5, 60)}), run(D, 3000.0), lift(D, {"Squat - Barbell": many(3, 5, 60)})])
	var fresh = RpgSave.empty()
	var w = RpgBoosts.waiting(inp(both_days, D), fresh)
	ok(w.size() == 2 and str(w[0].chest.date) == D and str(w[1].chest.date) == day(-1) and int(w[0].pay.ore) == 80 and int(w[1].pay.ore) == 55, "two chests waiting: today's first", w)
	fresh.chests[day(-1)] = 1
	fresh.chests[D] = 1
	w = RpgBoosts.waiting(inp(both_days, D), fresh)
	ok(w.size() == 1 and str(w[0].chest.date) == D and int(w[0].pay.ore) == 25 and not bool(w[0].pay.first), "yesterday's opened, today's opened before the run: only today's difference waits", w)
	fresh.chests[D] = 2
	ok(RpgBoosts.waiting(inp(both_days, D), fresh).is_empty() and RpgSave.parse(fresh).chests == fresh.chests, "all paid: nothing waits; the save keeps the counts")

	# --- the tab dot's cheap check ---------------------------------------------------
	var st = state_of(both_days, D)
	var book_rpg = RpgSave.empty()
	ok(RpgBoosts.chest_waiting(st, [], book_rpg, D), "a session today, never opened: the dot")
	book_rpg.chests[D] = 2
	ok(RpgBoosts.chest_waiting(st, [], book_rpg, D) and not RpgBoosts.chest_waiting(st, [], book_rpg, day(1)), "today's opened, yesterday's not: still the dot; a day later yesterday's is too old")
	book_rpg.chests[day(-1)] = 1
	ok(not RpgBoosts.chest_waiting(st, [], book_rpg, D), "both opened: no dot")
	ok(RpgBoosts.chest_waiting(st, [read(day(-1), 6), read(day(-1), 5)], book_rpg, D) and not RpgBoosts.chest_waiting(st, [read(day(-1), 9), read(day(-3), 80)], book_rpg, D),
		"yesterday's pages came after its chest was opened: the dot again (ten pages, not nine, and not another day's)")
	ok(RpgBoosts.chest_waiting({}, [read(D, 10)], RpgSave.empty(), D) and not RpgBoosts.chest_waiting({}, [read(D, 9)], RpgSave.empty(), D) and not RpgBoosts.chest_waiting({"dateCounts": {day(-2): 3}}, [], RpgSave.empty(), D),
		"pages alone can be a chest; nothing today or yesterday is none")
	ok(not RpgBoosts.chest_waiting(st, [], RpgSave.empty(), "") and not RpgBoosts.chest_waiting({"dateCounts": null}, [], {}, D), "no day, or a state with nothing in it: no dot")
	var t0 = Time.get_ticks_usec()
	for i in range(2000):
		RpgBoosts.chest_waiting(st, both_days.reading, book_rpg, D)
	var each = float(Time.get_ticks_usec() - t0) / 2000.0
	ok(each < 500.0, "the check is cheap: %.1f microseconds" % each)

	print("RPG BOOSTS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
