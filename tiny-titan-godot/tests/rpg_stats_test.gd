extends SceneTree
## Unit test for the Realm's stat sheet (game/rpg/rpg_stats.gd, RPG_PLAN.md 2):
## the strength score of every kind of set, the anchors, the body stats' blend
## and curve, the six traits, mobility going to Flow only, what a day's sets
## are, the sheet's shape and words, "was", and that nothing in a growing log
## ever lowers a stat. Made-up logs built in code.
##   godot --headless --path . --script res://tests/rpg_stats_test.gd
## Prints RPG STATS: n/m passed and exits with 1 when anything fails.
## With RPG_STATS_DUMP set to a folder OUTSIDE the project it also writes its
## three made-up players there as save files (first.json, month.json,
## eight_months.json), for tools/rpg_sheet.gd to print.

const TODAY = "2026-11-25"

var passed = 0
var total = 0
var _n = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func near(a: float, b: float, eps: float = 1e-9) -> bool:
	return absf(a - b) <= eps


# --- builders ------------------------------------------------------------------

func _stamp(date: String) -> int:
	_n += 1
	return int(Dates.parse_date_key(date).unix) * 1000 + _n


## Rows: [reps, kg], [reps, kg, hold seconds] or [reps, "band id"].
func sets_of(rows: Array) -> Array:
	var out = []
	for r in rows:
		if r[1] is String:
			out.append({"reps": r[0], "weightKg": 0.0, "band": r[1]})
		else:
			var one = {"reps": r[0], "weightKg": float(r[1])}
			if r.size() > 2:
				one["holdSec"] = r[2]
			out.append(one)
	return out


func three(reps: int, kg: float) -> Array:
	return [[reps, kg], [reps, kg], [reps, kg]]


func lift(date: String, exercises: Dictionary) -> Dictionary:
	var exs = []
	for lift_name in exercises:
		exs.append({"name": lift_name, "sets": sets_of(exercises[lift_name])})
	var at = _stamp(date)
	return {"id": "l%d" % _n, "discipline": "lift", "date": date, "createdAt": at, "source": "manual", "exercises": exs}


func run(date: String, m: float, sec: int = 0, splits: Dictionary = {}) -> Dictionary:
	var at = _stamp(date)
	var s = {"id": "r%d" % _n, "discipline": "run", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0}
	if sec > 0:
		s["durationSec"] = sec
	if not splits.is_empty():
		s["splits"] = splits
	return s


## Rows: [V grade, result, count], or ["5.10a", result, count] for a route.
func climb(date: String, rows: Array, hangs: Array = []) -> Dictionary:
	var climbs = []
	for r in rows:
		if r[0] is String:
			climbs.append({"grade": Xp.yds_to_v(Xp.yds_index(r[0])), "result": r[1], "count": r[2], "style": "rope", "yds": r[0]})
		else:
			climbs.append({"grade": r[0], "result": r[1], "count": r[2]})
	var at = _stamp(date)
	var s = {"id": "c%d" % _n, "discipline": "climb", "date": date, "createdAt": at, "source": "manual", "climbs": climbs}
	if not hangs.is_empty():
		s["hangs"] = hangs
	return s


func ride(date: String, m: float) -> Dictionary:
	var at = _stamp(date)
	return {"id": "b%d" % _n, "discipline": "ride", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0}


func walk(date: String, m: float, load_kg: float) -> Dictionary:
	var at = _stamp(date)
	return {"id": "w%d" % _n, "discipline": "misc", "kind": "vest_walk", "date": date, "createdAt": at, "source": "manual", "distanceM": m, "elevationM": 0, "loadKg": load_kg}


func read(date: String, pages: int) -> Dictionary:
	var at = _stamp(date)
	return {"id": "p%d" % _n, "date": date, "pages": pages, "createdAt": at}


func weigh(date: String, kg: float) -> Dictionary:
	var at = _stamp(date)
	return {"id": "w%d" % _n, "date": date, "createdAt": at, "weightKg": kg}


func perfect(date: String) -> Dictionary:
	var at = _stamp(date)
	return {"id": "q%d" % _n, "questId": "t:%s:perfect" % date, "xp": 300, "claimedAt": at, "date": date}


func book(title: String, status: String, finished: String = "", log: Dictionary = {}) -> Dictionary:
	_n += 1
	return {"id": "bk%d" % _n, "title": title, "author": "A. Writer", "series": "", "num": 0, "pages": 300, "status": status, "finished": finished,
		"page": 300 if status == "finished" else 40, "log": log, "at": _n}


func blank_save(wu: String = "kg", du: String = "km") -> Dictionary:
	return {"sessions": [], "reading": [], "books": [], "body": [], "claims": [], "pt": {},
		"settings": {"weightUnit": wu, "distanceUnit": du, "weeklyGoal": 3, "sound": true}}


func state_of(save: Dictionary, today: String) -> Dictionary:
	return Derive.derive({"sessions": save.sessions, "claims": save.claims, "body": save.body, "purchases": [], "reading": save.reading,
		"weeklyGoal": int(save.settings.weeklyGoal), "today": today})


## The sheet's input of a save (the state only when asked: the sheet takes
## nothing from it but the weekly goal, which the settings hold too).
func inp(save: Dictionary, today: String = TODAY, with_state: bool = false) -> Dictionary:
	return {"sessions": save.sessions, "state": state_of(save, today) if with_state else {}, "reading": save.reading, "books": save.books,
		"body": save.body, "claims": save.claims, "settings": save.settings, "marks": save.pt, "today": today}


func raws(save: Dictionary, today: String = TODAY) -> Dictionary:
	var sh = RpgStats.sheet(inp(save, today))
	var out = {}
	for id in RpgDefs.STATS:
		out[id] = float(sh.stats[id].raw)
	return out


## The stats that are lower in `after` than in `before`.
func lower(before: Dictionary, after: Dictionary) -> Array:
	var out = []
	for id in RpgDefs.STATS:
		if float(after[id]) < float(before[id]) - 1e-9:
			out.append("%s %.4f -> %.4f" % [id, float(before[id]), float(after[id])])
	return out


## The stats that differ between two sheets' raws.
func changed(before: Dictionary, after: Dictionary) -> Array:
	var out = []
	for id in RpgDefs.STATS:
		if not near(float(after[id]), float(before[id])):
			out.append(id)
	return out


func only_lifts(rows: Dictionary, date: String = TODAY) -> Dictionary:
	var save = blank_save()
	save.sessions.append(lift(date, rows))
	return save


func top_ss(save: Dictionary, part: String) -> float:
	var f = RpgStats.scan(inp(save), TODAY)
	return float(f.top[part][0].ss) if not f.top[part].is_empty() else 0.0


## The whole number in front of `words` in a text ("38 more sets for it"), -1 when it is not there.
func number_before(text: String, words: String) -> int:
	var rx = RegEx.new()
	rx.compile("([0-9][0-9,]*) " + words)
	var m = rx.search(text)
	return int(m.get_string(1).replace(",", "")) if m != null else -1


## A copy of a save with `n` more copies of a set on its first exercise of that name.
func with_sets(save: Dictionary, lift_name: String, n: int, one: Dictionary) -> Dictionary:
	var out = save.duplicate(true)
	for s in out.sessions:
		if str(s.discipline) != "lift":
			continue
		for ex in s.exercises:
			if str(ex.name) == lift_name:
				for k in range(n):
					ex.sets.append(one.duplicate())
				return out
	return out


# --- the three made-up players (also printed for the report) --------------------

func kg_step(v: float) -> float:
	return roundf(v / 2.5) * 2.5


## One lifting session, today: the very first.
func player_first() -> Dictionary:
	var save = blank_save()
	save.sessions.append(lift(TODAY, {"Bench Press - Barbell": three(8, 40), "Squat - Barbell": three(8, 50), "Lat Pulldown": three(10, 35),
		"Plank": [[1, 0, 30], [1, 0, 30]]}))
	return save


## Three lifting days a week for a month (Monday, Wednesday, Friday), a beginner.
func player_month() -> Dictionary:
	var save = blank_save()
	var k = 0
	for i in range(28):
		var date = Dates.add_days(TODAY, -27 + i)
		var wd = Dates.weekday_index(date)
		if wd != 0 and wd != 2 and wd != 4:
			continue
		var up = float(k) * 1.25
		save.sessions.append(lift(date, {
			"Bench Press - Barbell": three(8, kg_step(40 + up)), "Squat - Barbell": three(8, kg_step(50 + up * 1.5)),
			"Bent Over Row - Barbell": three(8, kg_step(35 + up)), "Overhead Press - Dumbbell": three(10, kg_step(12.5 + up * 0.3)),
			"Bicep Curl - Dumbbell": three(10, kg_step(7.5 + up * 0.2)), "Plank": [[1, 0, 40], [1, 0, 40]]}))
		k += 1
	save.body.append(weigh(Dates.add_days(TODAY, -27), 82.0))
	return save


## Eight months of pull / push / legs six days a week, a run every Monday,
## climbing on Saturdays, reading and physical therapy every day; lb and miles.
func player_eight_months() -> Dictionary:
	var save = blank_save("lb", "mi")
	save.pt = {"clamshell - band": {"name": "Clamshell - Band", "perWeek": 7}, "tibialis raise": {"name": "Tibialis Raise", "perWeek": 7}}
	var span = 240
	var turn = 0
	for i in range(span + 1):
		var date = Dates.add_days(TODAY, -span + i)
		var wd = Dates.weekday_index(date)
		var p = float(i) / float(span)
		var week = int(floor(float(i) / 7.0))
		var pt = {"Clamshell - Band": [[15, "red" if p < 0.5 else "green"], [15, "red" if p < 0.5 else "green"], [15, "red" if p < 0.5 else "green"]],
			"Tibialis Raise": three(15, 0), "Hamstring Stretch": [[1, 0, 30], [1, 0, 30], [1, 0, 30]]}
		if wd == 6:
			save.sessions.append(lift(date, pt))
		else:
			var rows = {}
			match turn % 3:
				0:
					rows = {"Bent Over Row - Barbell": three(8, kg_step(50 + 30 * p)), "Lat Pulldown": three(10, kg_step(45 + 25 * p)),
						"Pull-up": [[5 + int(6 * p), 0], [4 + int(6 * p), 0], [4 + int(5 * p), 0]], "Bicep Curl - Dumbbell": three(10, kg_step(10 + 6 * p)),
						"Face Pull": three(15, kg_step(15 + 10 * p)), "Shrug - Dumbbell": three(12, kg_step(20 + 12 * p))}
				1:
					rows = {"Bench Press - Barbell": three(6, kg_step(60 + 35 * p)), "Bench Press - Incline dumbbell": three(8, kg_step(20 + 12 * p)),
						"Overhead Press - Barbell": three(6, kg_step(35 + 20 * p)), "Lateral Raise - Cable": three(24, kg_step(5 + 4 * p)),
						"Tricep Pushdown - Rope": three(12, kg_step(20 + 15 * p)), "Chest Fly - Cable": three(12, kg_step(10 + 8 * p))}
				2:
					rows = {"Squat - Barbell": three(5, kg_step(70 + 40 * p)), "Romanian Deadlift - Barbell": three(8, kg_step(60 + 35 * p)),
						"Leg Press": three(10, kg_step(120 + 80 * p)), "Leg Curl": three(12, kg_step(30 + 20 * p)),
						"Calf Raise - Standing machine": three(12, kg_step(60 + 40 * p)), "Plank": [[1, 0, 45 + int(45 * p)], [1, 0, 45 + int(45 * p)]]}
			turn += 1
			rows.merge(pt)
			save.sessions.append(lift(date, rows))
		if wd == 0:
			var m = 4000.0 + 6000.0 * p
			var pace = 390.0 - 60.0 * p
			var splits = {"mile": int((pace - 25.0) * 1.609344)}
			if m > 5100.0:
				splits["5k"] = int((pace - 8.0) * 5.0)
			save.sessions.append(run(date, m, int(m / 1000.0 * pace), splits))
		if wd == 5:
			var top = 2 + int(3.4 * p)
			var hangs = [{"edgeMm": 20, "sec": 10, "arms": 2, "addKg": 5.0 + 10.0 * p, "count": 4}] if week % 2 == 0 else []
			var rows = [[top - 2, "flash", 4], [top - 1, "flash", 2], [top - 1, "send", 2], [top, "send", 1], [top + 1, "attempt", 4]]
			if week % 4 == 1:
				rows.append(["5.10a", "send", 2])
			save.sessions.append(climb(date, rows, hangs))
		if i % 30 == 12:
			save.sessions.append(walk(date, 4000.0, 9.0))
		if i % 45 == 20:
			save.sessions.append(ride(date, 25000.0))
		save.reading.append(read(date, 20 + (i % 5) * 5))
		if wd == 0:
			save.body.append(weigh(date, 82.0 - 3.0 * p))
		if i % 10 == 9:
			save.claims.append(perfect(date))
	for b in range(4):
		save.books.append(book("An Old Favourite %d" % (b + 1), "finished"))
	for b in range(9):
		var done = Dates.add_days(TODAY, -span + 20 + b * 25)
		save.books.append(book("A Book Read Here %d" % (b + 1), "finished", done, {done: [280, 300]}))
	save.books.append(book("The One In Progress", "reading"))
	return save


## Ten weeks with everything in it: every part, every kind of set, runs with
## and without times and splits, climbs with flashes, routes and hangs, books,
## PT and stretches, vest walks and rides. Pounds and miles.
func mixed_log() -> Dictionary:
	var save = blank_save("lb", "mi")
	save.pt = {"clamshell - band": {"name": "Clamshell - Band", "perWeek": 3}, "tibialis raise": {"name": "Tibialis Raise", "perWeek": 3}}
	for i in range(70):
		var date = Dates.add_days(TODAY, -69 + i)
		var wd = Dates.weekday_index(date)
		var week = int(floor(float(i) / 7.0))
		var pt = {"Clamshell - Band": [[15, "red"], [15, "red"], [15, "green"]], "Tibialis Raise": three(15, 0)}
		match wd:
			0:
				var rows = {"Bent Over Row - Barbell": [[8, 60], [8, 60], [8, 62.5]], "Lat Pulldown": three(10, 50), "Pull-up": [[8, 0], [7, 0], [6, 0]],
					"Pull-up - Weighted": [[5, 10]], "Bicep Curl - Dumbbell": three(10, 12), "Face Pull - Band": [[15, "green"], [15, "green"], [12, "blue"]],
					"Dead Hang": [[1, 0, 40]], "Shrug - Barbell": three(10, 80)}
				rows.merge(pt)
				save.sessions.append(lift(date, rows))
				save.body.append(weigh(date, 80.0 - 0.1 * week))
			1:
				if week % 2 == 0:
					save.sessions.append(run(date, 5200.0, 1700 - week * 10, {"mile": 470 - week}))
				else:
					save.sessions.append(run(date, 3000.0 + 200.0 * week))
			2:
				var rows = {"Bench Press - Barbell": [[5, 80], [5, 80], [5, 82.5]], "Bench Press - Incline dumbbell": three(8, 26),
					"Overhead Press - Barbell": three(6, 45), "Lateral Raise - Cable": [[24, 7.5], [24, 7.5], [22, 7.5]],
					"Tricep Pushdown - Rope": three(12, 27.5), "Tricep Extension - Cable": [[12, 25], [12, 25]], "Push-up": [[25, 0]],
					"Dip - Weighted": [[8, 15]]}
				rows.merge(pt)
				save.sessions.append(lift(date, rows))
			3:
				var hangs = [{"edgeMm": 20, "sec": 10, "arms": 2, "addKg": 10.0, "count": 3}, {"edgeMm": 0, "sec": 35, "arms": 2, "addKg": 0.0, "count": 1}] if week % 2 == 1 else []
				save.sessions.append(climb(date, [[3, "flash", 2], [4, "send", 1], [5, "attempt", 3], ["5.10a", "send", 1]], hangs))
			4:
				var rows = {"Squat - Barbell": three(5, 100), "Romanian Deadlift - Barbell": three(8, 80), "Leg Press": three(10, 160),
					"Calf Raise - Standing machine": three(12, 80), "Plank": [[1, 0, 60], [1, 0, 60]], "Clean - Power": [[3, 60], [3, 60]],
					"Russian Twist - Plate": [[20, 10]], "Swing": [[12, 24]]}
				rows.merge(pt)
				save.sessions.append(lift(date, rows))
				if week % 3 == 2:
					save.claims.append(perfect(date))
			5:
				if week % 3 == 0:
					save.sessions.append(ride(date, 30000.0))
				elif week % 3 == 1:
					save.sessions.append(walk(date, 4000.0, 10.0))
			6:
				save.sessions.append(lift(date, {"Clamshell - Band": [[15, "red"], [15, "red"], [15, "red"]], "Hamstring Stretch": [[1, 0, 30], [1, 0, 30], [1, 0, 30]]}))
		if wd != 5:
			save.reading.append(read(date, 25))
	var d1 = Dates.add_days(TODAY, -40)
	var d2 = Dates.add_days(TODAY, -12)
	save.books = [book("Shelf One", "finished"), book("Shelf Two", "finished"), book("Shelf Three", "finished"),
		book("Read One", "finished", d1, {d1: [250, 300]}), book("Read Two", "finished", d2, {d2: [270, 300]}), book("Reading Now", "reading")]
	return save


func dump(folder: String, file_name: String, save: Dictionary) -> void:
	var f = FileAccess.open(folder.trim_suffix("/").trim_suffix("\\") + "/" + file_name, FileAccess.WRITE)
	if f == null:
		print("DUMP  could not write %s" % file_name)
		return
	f.store_string(JSON.stringify(save))
	f.close()
	print("DUMP  %s" % file_name)


func short(save: Dictionary, today: String = TODAY) -> String:
	var sh = RpgStats.sheet(inp(save, today))
	var parts = []
	for id in RpgDefs.STATS:
		parts.append("%s %d" % [id, int(sh.stats[id].v)])
	return ", ".join(PackedStringArray(parts)) + " | might %.1f" % float(sh.might)


func _init() -> void:
	# --- an empty log ------------------------------------------------------------
	var empty = RpgStats.sheet(inp(blank_save()))
	ok(RpgDefs.STATS.all(func(id): return near(float(empty.stats[id].raw), 1.0) and int(empty.stats[id].v) == 1 and near(float(empty.stats[id].was), 1.0)),
		"an empty log: every stat is 1, and was 1", empty.stats)
	ok(near(float(empty.might), 1.0) and int(empty.days) == 0 and int(empty.sessions) == 0 and empty.body == RpgDefs.BODY and empty.traits == RpgDefs.TRAITS and str(empty.today) == TODAY,
		"an empty log: might 1, no days, no sessions, the ids in order")
	ok(RpgDefs.STATS.all(func(id): return empty.stats[id].lines.size() >= 1 and str(empty.stats[id].next) != "" and str(empty.stats[id].name) == str(RpgDefs.STAT_NAMES[id]) and str(empty.stats[id].id) == id),
		"an empty log: every stat still says what it is made of and how to start it", empty.stats)
	ok(near(float(RpgStats.sheet({}).stats.legs.raw), 1.0) and near(float(RpgStats.sheet({"sessions": null, "reading": 5, "today": TODAY}).stats.mind.raw), 1.0),
		"an input with nothing in it (or the wrong kind of thing) is an empty log")

	# --- the catalog of anchors ------------------------------------------------------
	var bad = []
	for k in RpgStats.ANCHORS:
		var e = LiftNames.movement(k)
		if e == null or str(e.name) != k or not RpgStats.GEAR_FACTOR.has(str(RpgStats.ANCHORS[k][1])) or float(RpgStats.ANCHORS[k][0]) <= 0.0 or Array(e.only).has("Bodyweight"):
			bad.append(k)
	ok(bad.is_empty() and RpgStats.ANCHORS.size() >= 50, "every anchor is a library movement loaded with a weight, on equipment with a factor", bad)
	bad = []
	for k in RpgStats.BW_ANCHORS:
		var e = LiftNames.movement(k)
		if e == null or str(e.name) != k or not Array(e.only).has("Bodyweight"):
			bad.append(k)
	ok(bad.is_empty() and RpgStats.BW_ANCHORS.size() == 11 and float(RpgStats.BW_ANCHORS["Pull-up"]) == 25.0 and float(RpgStats.BW_ANCHORS["Push-up"]) == 60.0 and float(RpgStats.BW_ANCHORS["Muscle-up"]) == 10.0,
		"the rep anchors are the plan's eleven bodyweight movements", bad)
	var plan_rows = {"Bench Press": 150, "Squat": 200, "Deadlift": 240, "Overhead Press": 95, "Bent Over Row": 140, "Romanian Deadlift": 190, "Hip Thrust": 230,
		"Bicep Curl": 75, "Lat Pulldown": 130, "Seated Row": 130, "Leg Press": 400, "Leg Extension": 130, "Leg Curl": 100, "Calf Raise": 200, "Lateral Raise": 25,
		"Chest Fly": 45, "Face Pull": 60, "Tricep Pushdown": 90, "Tricep Extension": 70, "Shrug": 220}
	ok(plan_rows.keys().all(func(k): return RpgStats.ANCHORS.has(k)), "the plan's twenty anchors are all there (Curl is Bicep Curl, the skull crusher Tricep Extension)")
	ok(near(RpgStats.gear_rel("dumbbell", "barbell"), 0.48) and near(RpgStats.gear_rel("machine", "barbell"), 1.1) and near(RpgStats.gear_rel("cable", "barbell"), 0.65)
		and near(RpgStats.gear_rel("kettlebell", "barbell"), 0.4) and near(RpgStats.gear_rel("smith", "barbell"), 1.0) and near(RpgStats.gear_rel("barbell", "barbell"), 1.0),
		"the equipment factors against a barbell")
	ok(near(RpgStats.gear_rel("cable", "dumbbell"), 0.65 / 0.48) and near(RpgStats.gear_rel("machine", "cable"), RpgStats.CABLE_TO_MACHINE) and near(RpgStats.gear_rel("other", "barbell"), 1.0) and near(RpgStats.gear_rel("", "cable"), 1.0),
		"an anchor said for other equipment is scaled from that; equipment with no factor is the anchor's own")
	var a_bench = RpgStats.anchor_of("Bench Press - Barbell")
	ok(near(float(a_bench.kg), float(RpgStats.ANCHORS["Bench Press"][0])) and bool(a_bench.own) and near(float(RpgStats.anchor_of("Bench Press - Incline dumbbell").kg), 150.0 * 0.48)
		and near(float(RpgStats.anchor_of("Bench Press - Smith machine").kg), 150.0) and near(float(RpgStats.anchor_of("Bench Press - Machine").kg), 165.0),
		"a bench press on a barbell, dumbbells, a smith machine and a machine", [a_bench, RpgStats.anchor_of("Bench Press - Incline dumbbell")])
	ok(near(float(RpgStats.anchor_of("Lateral Raise - Dumbbell").kg), 25.0) and near(float(RpgStats.anchor_of("Lateral Raise - Cable").kg), 25.0 * 0.65 / 0.48)
		and near(float(RpgStats.anchor_of("Lat Pulldown").kg), 130.0) and near(float(RpgStats.anchor_of("Lat Pulldown - Machine").kg), 130.0 * 1.1) and near(float(RpgStats.anchor_of("Face Pull").kg), 60.0),
		"25 a hand is a dumbbell's; a pulldown's and a face pull's anchor is the cable's own", [RpgStats.anchor_of("Lateral Raise - Cable"), RpgStats.anchor_of("Lat Pulldown - Machine")])
	ok(near(float(RpgStats.anchor_of("Tricep Extension - Cable").kg), 90.0) and near(float(RpgStats.anchor_of("Tricep Extension - Lying EZ bar").kg), 70.0) and near(float(RpgStats.anchor_of("Curl - Barbell").kg), 75.0),
		"a cable tricep extension is a pushdown; a name the library knows another way finds its row", [RpgStats.anchor_of("Tricep Extension - Cable"), RpgStats.anchor_of("Curl - Barbell")])
	var a_none = RpgStats.anchor_of("Russian Twist - Plate")
	ok(not bool(a_none.own) and near(float(a_none.kg), float(RpgStats.PART_ANCHOR.core)) and near(float(RpgStats.anchor_of("Tibialis Raise - Machine").kg), float(RpgStats.PART_ANCHOR.legs) * 1.1)
		and near(float(RpgStats.anchor_of("Hamstring Stretch").kg), 0.0), "a movement with no row: the part's default times the factor; mobility has none", a_none)

	# --- the strength score of a set --------------------------------------------------
	var s_bench = RpgStats.ss_of("Bench Press - Barbell", {"reps": 5, "weightKg": 100.0})
	ok(near(s_bench, 100.0 * (1.0 + 5.0 / 30.0) / 150.0), "weighted: the estimated max over the anchor", s_bench)
	ok(near(RpgStats.ss_of("Bench Press - Barbell", {"reps": 20, "weightKg": 100.0}), 100.0 * (1.0 + 12.0 / 30.0) / 150.0), "reps past 12 count as 12")
	ok(near(RpgStats.ss_of("Bench Press - Dumbbell", {"reps": 8, "weightKg": 40.0}), 40.0 * (1.0 + 8.0 / 30.0) / (150.0 * 0.48)), "a dumbbell a hand against 0.48 of the barbell's")
	ok(near(RpgStats.ss_of("Swing", {"reps": 12, "weightKg": 32.0}), 32.0 * 1.4 / 80.0) and near(RpgStats.ss_of("Lat Pulldown", {"reps": 10, "weightKg": 80.0}), 80.0 * (1.0 + 10.0 / 30.0) / 130.0), "a kettlebell swing and a cable pulldown")
	var s_raise = RpgStats.ss_of("Lateral Raise - Cable", {"reps": 24, "weightKg": 10.0})
	ok(near(s_raise, 10.0 * (1.0 + 12.0 / 30.0) / (25.0 * 0.65 / 0.48)) and near(RpgStats.ss_of("Lateral Raise - Dumbbell", {"reps": 24, "weightKg": 10.0}), 10.0 * 1.4 / 25.0),
		"both sides added up (a cable lateral raise): the reps are halved first", s_raise)
	var marked = {"bothSides": {"bicep curl - dumbbell": {"name": "Bicep Curl - Dumbbell", "on": true}, "lateral raise - cable": {"name": "Lateral Raise - Cable", "on": false}}}
	ok(near(RpgStats.ss_of("Bicep Curl - Dumbbell", {"reps": 16, "weightKg": 12.0}, marked), 12.0 * (1.0 + 8.0 / 30.0) / 36.0) and near(RpgStats.ss_of("Lateral Raise - Cable", {"reps": 10, "weightKg": 10.0}, marked), 10.0 * (1.0 + 10.0 / 30.0) / (25.0 * 0.65 / 0.48)),
		"the player's own L+R switch, on and off, is followed")
	ok(near(RpgStats.ss_of("Pull-up", {"reps": 10, "weightKg": 0.0}), 10.0 / 25.0) and near(RpgStats.ss_of("Push-up", {"reps": 30, "weightKg": 0.0}), 0.5) and near(RpgStats.ss_of("Dip", {"reps": 7, "weightKg": 0.0}), 0.2),
		"a bodyweight movement with a rep anchor: reps over the anchor")
	ok(near(RpgStats.ss_of("Pull-up - Weighted", {"reps": 10, "weightKg": 20.0}, {}, 80.0), 0.4 * 1.25) and near(RpgStats.ss_of("Pull-up - Weighted", {"reps": 10, "weightKg": 15.0}), 0.4 * (1.0 + 15.0 / 75.0)),
		"with weight added: times (1 + kg / bodyweight), 75 kg when unknown")
	ok(near(RpgStats.ss_of("Squat - Bodyweight", {"reps": 8, "weightKg": 0.0}), 0.1) and near(RpgStats.ss_of("Squat - Bodyweight", {"reps": 40, "weightKg": 0.0}), 0.25) and near(RpgStats.ss_of("Sit-up", {"reps": 20, "weightKg": 0.0}), 0.25),
		"any other weightless set: reps / 80, at most 0.25")
	ok(near(RpgStats.ss_of("Face Pull - Band", {"reps": 15, "weightKg": 0.0, "band": "green"}), 0.45 * 4.0 / 9.0) and near(RpgStats.ss_of("Face Pull - Band", {"reps": 5, "weightKg": 0.0, "band": "gold"}), 0.45)
		and RpgStats.ss_of("Face Pull - Band", {"reps": 15, "weightKg": 0.0, "band": "blue"}) > RpgStats.ss_of("Face Pull - Band", {"reps": 30, "weightKg": 0.0, "band": "green"}),
		"a band set: by the band's place on the ladder, not the reps")
	ok(near(RpgStats.ss_of("Bench Press - Barbell", {"reps": 5, "weightKg": 100.0, "band": null, "holdSec": null}), s_bench) and near(RpgStats.ss_of("Bench Press - Barbell", {"reps": 5.0, "weightKg": 100, "band": ""}), s_bench)
		and near(RpgStats.ss_of("Bench Press - Barbell", {"reps": 5, "weightKg": 100.0, "band": "plaid"}), s_bench) and near(RpgStats.ss_of("Bench Press - Barbell", {"reps": 5}), 5.0 / 80.0),
		"a set with an empty or unknown band, or whole numbers stored as floats, is the weighted set it is; one with no weight is a weightless one")
	ok(near(RpgStats.ss_of("Plank", {"reps": 1, "weightKg": 0.0, "holdSec": 60}), 0.25) and near(RpgStats.ss_of("Plank", {"reps": 1, "weightKg": 0.0, "holdSec": 600}), 0.5) and near(RpgStats.ss_of("Dead Hang", {"reps": 2, "weightKg": 0.0, "holdSec": 48}), 0.2),
		"a hold: seconds / 240, at most 0.5")
	ok(near(RpgStats.ss_of("Russian Twist - Plate", {"reps": 10, "weightKg": 500.0}), RpgStats.DEFAULT_CAP) and near(RpgStats.ss_of("Russian Twist - Plate", {"reps": 12, "weightKg": 20.0}), 20.0 * 1.4 / 90.0),
		"the default anchor counts up to 0.7")
	ok(RpgStats.ss_of("Lunge - Bodyweight", {"reps": 20, "weightKg": 1.0}) >= RpgStats.ss_of("Lunge - Bodyweight", {"reps": 20, "weightKg": 0.0}) and RpgStats.ss_of("Squat - Barbell", {"reps": 30, "weightKg": 5.0}) >= 0.25,
		"a little weight never scores under the same reps without it")
	ok(near(RpgStats.ss_of("Pull-up - Assisted", {"reps": 10, "weightKg": 30.0}), 0.4 * RpgStats.ASSISTED), "an assisted set: the weight typed is help, not load")
	ok(near(RpgStats.ss_of("Pull-up - Band assisted", {"reps": 10, "weightKg": 0.0, "band": "gold"}), 0.4 * RpgStats.ASSISTED)
		and near(RpgStats.ss_of("Pull-up - Band assisted", {"reps": 10, "weightKg": 0.0, "band": "yellow"}), 0.4 * RpgStats.ASSISTED),
		"nor is the band of an assisted set: a heavier one is more help, not more strength")

	# --- which stat a lift is for -----------------------------------------------------
	var parts = {"Bench Press - Barbell": "chest", "Shrug - Barbell": "back", "Lat Pulldown": "back", "Overhead Press - Barbell": "shoulders", "Face Pull": "shoulders",
		"Bicep Curl - Dumbbell": "arms", "Tricep Pushdown - Rope": "arms", "Wrist Curl - Barbell": "arms", "Dead Hang": "arms", "Squat - Barbell": "legs",
		"Romanian Deadlift - Barbell": "legs", "Hip Thrust - Barbell": "legs", "Calf Raise": "legs", "Plank": "core", "Clean - Power": "full", "Thruster": "full",
		"Hamstring Stretch": "", "Cat-Cow": "", "Doorway Stretch": "", "Zzyzx Thing": ""}
	bad = []
	for k in parts:
		if RpgStats.part_of(k) != str(parts[k]):
			bad.append("%s -> %s" % [k, RpgStats.part_of(k)])
	ok(bad.is_empty(), "the library's parts folded into six stats (full-body lifts apart, mobility and unknown lifts none)", bad)
	var pt_marks = {"clamshell - band": {"name": "Clamshell - Band", "perWeek": 3}, "romanian deadlift - single leg": {"name": "Romanian Deadlift - Single leg", "perWeek": 3}}
	ok(RpgStats.is_mobility({"name": "Clamshell - Band"}, pt_marks) and RpgStats.is_mobility({"name": "Romanian Deadlift - Single leg"}, pt_marks) and RpgStats.is_mobility({"name": "Hamstring Stretch"}, {})
		and RpgStats.is_mobility({"name": "Cat-Cow"}, {}) and RpgStats.is_mobility({"name": "Doorway stretch"}, {}),
		"mobility: a PT mark, a library movement of the mobility part, or stretch in the name")
	ok(not RpgStats.is_mobility({"name": "Plank"}, pt_marks) and not RpgStats.is_mobility({"name": "Dead Hang"}, pt_marks) and not RpgStats.is_mobility({"name": "Romanian Deadlift - Barbell"}, pt_marks) and not RpgStats.is_mobility({"name": "Clamshell - Band"}, {}),
		"a plank, a dead hang and another variation of a PT lift are not mobility")

	# --- one exercise at a time: the curve to the letter ------------------------------
	var one_bench = only_lifts({"Bench Press - Barbell": three(8, 40)})
	var sh1 = RpgStats.sheet(inp(one_bench))
	var ss1 = 40.0 * (1.0 + 8.0 / 30.0) / 150.0
	var want1 = 1.0 + RpgStats.PEAK * pow(0.6 * ss1, 0.85) * (1.0 - exp(-1.0 / 3.0)) + 30.0 * log(1.0 + 3.0 / 40.0) / log(101.0)
	ok(near(float(sh1.stats.chest.raw), want1, 1e-9) and int(sh1.stats.chest.v) == int(floor(want1)), "one bench session: 1 + peak * ramp + work, to the letter", [sh1.stats.chest.raw, want1])
	var want_arm = 1.0 + 30.0 * log(1.0 + 1.5 / 40.0) / log(101.0)
	ok(near(float(sh1.stats.arms.raw), want_arm) and near(float(sh1.stats.shoulders.raw), want_arm) and near(float(sh1.stats.back.raw), 1.0) and near(float(sh1.stats.legs.raw), 1.0) and near(float(sh1.stats.core.raw), 1.0),
		"the bench also works triceps and front delts: half a set each of work, no strength score", [sh1.stats.arms.raw, want_arm])
	ok(near(float(sh1.stats.speed.raw), 1.0) and near(float(sh1.stats.grip.raw), 1.0) and near(float(sh1.stats.mind.raw), 1.0) and near(float(sh1.stats.flow.raw), 1.0)
		and float(sh1.stats.endurance.raw) > 1.0 and float(sh1.stats.grit.raw) > 1.0 and int(sh1.days) == 1 and int(sh1.sessions) == 1,
		"one lift: no speed, grip, mind or flow; a little endurance and grit for showing up")
	ok(near(RpgStats.body_raw([0.5, 0.4, 0.3], 9.0, 200.0), 1.0 + RpgStats.PEAK * pow(0.6 * 0.5 + 0.25 * 0.4 + 0.15 * 0.3, 0.85) * (1.0 - exp(-3.0)) + 30.0 * log(6.0) / log(101.0)),
		"the blend of three movements: 0.6, 0.25, 0.15")
	ok(near(RpgStats.body_raw([3.0, 3.0, 3.0], 1000.0, 0.0), 1.0 + RpgStats.PEAK * pow(1.2, 0.85)) and near(RpgStats.body_raw([3.0], 1000.0, 1.0e9), 99.99) and near(RpgStats.body_raw([], 0.0, 0.0), 1.0),
		"the strength score counts up to 1.2 and a stat ends at 99.99")

	# --- the three-movement blend in a log --------------------------------------------
	var one_move = only_lifts({"Bench Press - Barbell": three(5, 100)})
	var two_moves = only_lifts({"Bench Press - Barbell": three(5, 100), "Chest Fly - Dumbbell": three(10, 20)})
	var three_moves = only_lifts({"Bench Press - Barbell": three(5, 100), "Chest Fly - Dumbbell": three(10, 20), "Push-up": [[30, 0]]})
	var four_moves = only_lifts({"Bench Press - Barbell": three(5, 100), "Chest Fly - Dumbbell": three(10, 20), "Push-up": [[30, 0]], "Dip": [[7, 0]]})
	var f3 = RpgStats.scan(inp(three_moves), TODAY)
	var ss_b = 100.0 * (1.0 + 5.0 / 30.0) / 150.0
	var ss_f = 20.0 * (1.0 + 10.0 / 30.0) / 45.0
	ok(f3.top.chest.size() == 3 and near(float(f3.top.chest[0].ss), ss_b) and near(float(f3.top.chest[1].ss), ss_f) and near(float(f3.top.chest[2].ss), 0.5) and int(f3.move_count.chest) == 3,
		"a part's movements, the strongest first", f3.top.chest.map(func(m): return [m.move, m.ss]))
	ok(near(RpgStats.peak_ss(RpgStats._scores(f3, "chest")), 0.6 * ss_b + 0.25 * ss_f + 0.15 * 0.5), "its strength score: 0.6 best + 0.25 second + 0.15 third")
	var r1 = float(raws(one_move).chest)
	var r2 = float(raws(two_moves).chest)
	var r3 = float(raws(three_moves).chest)
	ok(r2 > r1 + 1.0 and r3 > r2 + 0.5, "a second and a third good movement raise the stat", [r1, r2, r3])
	var f4 = RpgStats.scan(inp(four_moves), TODAY)
	ok(f4.top.chest.size() == 3 and int(f4.move_count.chest) == 4 and near(RpgStats.peak_ss(RpgStats._scores(f4, "chest")), RpgStats.peak_ss(RpgStats._scores(f3, "chest"))),
		"a fourth, weaker movement changes no strength score (only its sets count)")
	var same_move = only_lifts({"Tricep Pushdown - Rope": three(12, 30), "Tricep Extension - Cable": three(12, 20)})
	var f_same = RpgStats.scan(inp(same_move), TODAY)
	ok(int(f_same.move_count.arms) == 1 and str(f_same.top.arms[0].move) == "Tricep Pushdown" and near(float(f_same.top.arms[0].ss), 30.0 * 1.4 / 90.0) and near(float(f_same.work.arms), 6.0),
		"a pushdown and a cable extension are one movement: the best of them, both sets counted", f_same.top.arms)
	var best_ever = blank_save()
	best_ever.sessions = [lift("2026-11-01", {"Squat - Barbell": three(5, 120)}), lift("2026-11-10", {"Squat - Barbell": three(5, 100)}), lift("2026-11-20", {"Squat - Front": three(5, 90)})]
	var f_best = RpgStats.scan(inp(best_ever), TODAY)
	ok(near(float(f_best.top.legs[0].ss), 120.0 * (1.0 + 5.0 / 30.0) / 200.0) and str(f_best.top.legs[0].date) == "2026-11-01" and int(f_best.move_count.legs) == 1 and f_best.days.legs.size() == 3,
		"the best set EVER of a movement is kept, whatever came after, over all its variations", f_best.top.legs)

	# --- the default-anchor cap, a plank, a full-body lift, climbing --------------------
	var capped = only_lifts({"Russian Twist - Plate": three(10, 500)})
	var f_cap = RpgStats.scan(inp(capped), TODAY)
	ok(near(float(f_cap.top.core[0].ss), 0.7) and bool(f_cap.top.core[0].capped), "a movement on the default anchor stops at 0.7", f_cap.top.core)
	var plank = only_lifts({"Plank": [[1, 0, 120], [1, 0, 90]]})
	var r_plank = raws(plank)
	var f_plank = RpgStats.scan(inp(plank), TODAY)
	ok(float(r_plank.core) > 1.5 and near(float(r_plank.flow), 1.0) and near(float(f_plank.top.core[0].ss), 0.5) and str(f_plank.top.core[0].kind) == "hold" and int(f_plank.mob_sets) == 0,
		"a plank scores for core (a hold that is not mobility), and nothing for flow", [r_plank.core, r_plank.flow])
	var hang = raws(only_lifts({"Dead Hang": [[1, 0, 60]]}))
	ok(float(hang.arms) > 1.0 and near(float(hang.flow), 1.0) and float(hang.grip) > 1.0, "a dead hang scores for arms, and its forearm set a little for grip", hang)
	var clean = only_lifts({"Clean - Power": [[3, 70], [3, 70]]})
	var f_clean = RpgStats.scan(inp(clean), TODAY)
	var ss_clean = 70.0 * (1.0 + 3.0 / 30.0) / 140.0
	ok(near(float(f_clean.top.legs[0].ss), ss_clean) and near(float(f_clean.top.back[0].ss), ss_clean) and f_clean.top.core.is_empty()
		and near(float(f_clean.work.legs), 1.0) and near(float(f_clean.work.back), 1.0) and near(float(f_clean.work.core), 1.0) and f_clean.days.legs.size() == 1 and f_clean.days.back.size() == 1 and f_clean.days.core.is_empty(),
		"a full-body lift: its strength counts for legs and back, each set half a set for legs, back and core", [f_clean.top.legs, f_clean.work])
	var climbed = blank_save()
	climbed.sessions = [climb(TODAY, [[3, "send", 2]])]
	var f_climb = RpgStats.scan(inp(climbed), TODAY)
	var r_climb = raws(climbed)
	ok(near(float(f_climb.work.arms), 4.0) and near(float(f_climb.work.back), 0.0) and near(float(f_climb.climb_work.arms), 4.0) and f_climb.days.arms.is_empty()
		and float(r_climb.arms) > 1.0 and near(float(r_climb.back), 1.0) and near(float(r_climb.chest), 1.0) and near(float(r_climb.legs), 1.0),
		"a climbing session: four sets of work for the arms, none for the back", [f_climb.work, r_climb])
	ok(near(float(r_climb.arms), 1.0 + 30.0 * log(1.0 + 4.0 / 40.0) / log(101.0)), "(climbing gives the arms work, no strength score)", r_climb.arms)

	# --- mobility goes to flow only ---------------------------------------------------
	var base = blank_save()
	base.pt = {"clamshell - band": {"name": "Clamshell - Band", "perWeek": 3}}
	base.sessions = [lift("2026-11-20", {"Bench Press - Barbell": three(5, 80), "Squat - Barbell": three(5, 100)}), run("2026-11-21", 5000.0, 1500)]
	var with_pt = base.duplicate(true)
	with_pt.sessions[0].exercises.append({"name": "Clamshell - Band", "sets": sets_of([[15, "black"], [15, "black"], [15, "black"]])})
	with_pt.sessions[0].exercises.append({"name": "Hamstring Stretch", "sets": sets_of([[1, 0, 60], [1, 0, 60]])})
	with_pt.sessions[0].exercises.append({"name": "Deep Squat Stretch", "sets": sets_of([[1, 20, 30]])})
	var ch_pt = changed(raws(base), raws(with_pt))
	ok(ch_pt == ["flow"], "PT and stretches added to a session change Flow and nothing else", ch_pt)
	var f_pt = RpgStats.scan(inp(with_pt), TODAY)
	ok(int(f_pt.mob_sets) == 6 and near(float(f_pt.mob_hold_sec), 150.0) and near(float(f_pt.work.legs), 3.0) and int(f_pt.move_count.legs) == 1,
		"their sets and held seconds are counted for Flow; a heavy band on a PT lift is no strength score", [f_pt.mob_sets, f_pt.mob_hold_sec, f_pt.work])
	var unmarked = with_pt.duplicate(true)
	unmarked.pt = {}
	ok(changed(raws(with_pt), raws(unmarked)).has("legs") and float(raws(unmarked).flow) < float(raws(with_pt).flow), "without its PT mark the clamshell is a leg lift again")
	ok(near(RpgStats.flow_raw(60.0, 25.0, 3.0), 1.0 + 60.0 * log(1.0 + 60.0 / 30.0) / log(1.0 + 10000.0 / 30.0) + minf(12.0, 25.0 / 10.0) + minf(8.0, 3.0 / 4.0))
		and near(RpgStats.flow_raw(0.0, 500.0, 100.0), 1.0 + 12.0 + 8.0), "flow, to the letter")
	var weeks = blank_save()
	weeks.pt = base.pt
	# (a Monday to Sunday week: 2026-11-16 .. 22 gets nine sets, the one before eight)
	weeks.sessions = [lift("2026-11-16", {"Clamshell - Band": three(15, 0)}), lift("2026-11-18", {"Clamshell - Band": three(15, 0)}), lift("2026-11-22", {"Clamshell - Band": three(15, 0)}),
		lift("2026-11-09", {"Clamshell - Band": three(15, 0)}), lift("2026-11-11", {"Clamshell - Band": three(15, 0)}), lift("2026-11-15", {"Clamshell - Band": [[15, 0], [15, 0]]})]
	var f_weeks = RpgStats.scan(inp(weeks), TODAY)
	ok(int(f_weeks.mob_sets) == 17 and RpgStats._good_weeks(f_weeks) == 1, "a week with nine mobility sets is counted, one with eight is not", f_weeks.mob_weeks)

	# --- a day's sets (shared with the boosts) -------------------------------------------
	var day = blank_save()
	day.pt = base.pt
	day.sessions = [lift(TODAY, {"Bench Press - Barbell": three(5, 80), "Chest Fly - Cable": three(12, 15), "Clamshell - Band": three(15, 0), "Calf Stretch": [[1, 0, 30], [1, 0, 30]]}),
		lift(TODAY, {"Clean - Power": [[3, 60], [3, 60]], "Overhead Press - Barbell": [[5, 40], [0, 40]]}), climb(TODAY, [[3, "send", 4]]),
		lift("2026-11-24", {"Squat - Barbell": three(5, 100)})]
	var by = RpgStats.sets_by_part(day.sessions, day.pt, day.settings, TODAY)
	ok(by.keys() == RpgDefs.BODY and near(float(by.chest), 6.0 + 0.5) and near(float(by.arms), 1.5 + 0.5) and near(float(by.shoulders), 1.5 + 0.75 + 1.0)
		and near(float(by.legs), 1.0) and near(float(by.back), 1.0) and near(float(by.core), 1.0),
		"a day's sets per stat: direct 1, also-works at its share, PT, stretches, empty sets and climbing left out", by)
	ok(RpgStats.mobility_sets_on(day.sessions, day.pt, TODAY) == 5 and RpgStats.mobility_sets_on(day.sessions, day.pt, "2026-11-24") == 0 and near(float(RpgStats.sets_by_part(day.sessions, day.pt, day.settings, "2026-11-24").legs), 3.0),
		"a day's mobility sets, and another day's sets")
	var one_day = RpgStats.lift_sets(day.sessions[0], day.pt)
	ok(bool(one_day.strength) and int(one_day.mobility) == 5 and not bool(RpgStats.lift_sets(lift(TODAY, {"Clamshell - Band": three(15, 0)}), day.pt).strength) and RpgStats.lift_sets(day.sessions[2], day.pt).sets.is_empty(),
		"one session: its sets, its mobility sets, whether it is strength work")

	# --- speed ---------------------------------------------------------------------
	var sp_want = 1.0 + 40.0 * clampf((180.0 / 300.0 - 0.2) / 0.65, 0.0, 1.1) * (1.0 - exp(-10.0 / 3.0)) + 25.0 * log(1.0 + 10.0 / 4.0) / log(1.0 + 150.0 / 4.0) + 15.0 * log(1.0 + 50.0 / 20.0) / log(1.0 + 1500.0 / 20.0)
	ok(near(RpgStats.speed_raw(300.0, 10.0, 50.0), sp_want) and near(RpgStats.speed_raw(0.0, 0.0, 0.0), 1.0) and RpgStats.speed_raw(100.0, 1000.0, 9000.0) < 99.991
		and near(RpgStats.speed_raw(120.0, 3.0, 0.0) - RpgStats.speed_raw(0.0, 3.0, 0.0), 40.0 * 1.1 * (1.0 - exp(-1.0))),
		"speed, to the letter (no timed run: no pace part; the pace part stops at 1.1)", [RpgStats.speed_raw(300.0, 10.0, 50.0), sp_want])
	var runs = blank_save()
	runs.sessions = [run("2026-11-10", 5000.0, 1500), run("2026-11-12", 8000.0), run("2026-11-14", 1200.0, 240)]
	var f_run = RpgStats.scan(inp(runs), TODAY)
	ok(near(float(f_run.pace), 300.0) and int(f_run.runs) == 3 and near(float(f_run.run_m), 14200.0) and near(float(f_run.longest_run_m), 8000.0),
		"the best pace of the timed runs of 1.5 km or more (a 1.2 km sprint does not count)", [f_run.pace, f_run.pace_from])
	runs.sessions.append(run("2026-11-16", 10000.0, 3300, {"5k": 1400, "1k": 250}))
	var f_split = RpgStats.scan(inp(runs), TODAY)
	ok(near(float(f_split.pace), 250.0) and str(f_split.pace_from.what) == "split" and str(f_split.pace_from.id) == "1k", "a best split inside a run counts as a pace", f_split.pace_from)
	var slip = runs.duplicate(true)
	slip.sessions.append(run("2026-11-18", 8000.0, 2700, {"mile": 45}))
	slip.sessions.append(run("2026-11-19", 5000.0, 50))
	var f_slip = RpgStats.scan(inp(slip), TODAY)
	ok(near(float(f_slip.pace), 250.0) and near(float(raws(slip).speed), RpgStats.speed_raw(250.0, 6.0, 37.2)), "a time no one can run (a mile in 45 s, 5 km in 50 s) is a typing slip: no pace of it counts", [f_slip.pace, f_slip.pace_from])
	var untimed = blank_save()
	untimed.sessions = [run("2026-11-10", 5000.0), run("2026-11-12", 6000.0)]
	var r_unt = raws(untimed)
	ok(near(float(r_unt.speed), 1.0 + 25.0 * log(1.0 + 2.0 / 4.0) / log(1.0 + 150.0 / 4.0) + 15.0 * log(1.0 + 11.0 / 20.0) / log(76.0)), "runs with no time: the pace part is 0", r_unt.speed)
	var st_runs = state_of(runs, TODAY)
	ok(st_runs.prs.bestPaceSecPerKm != null and float(f_split.pace) <= float(st_runs.prs.bestPaceSecPerKm) + 1e-9, "never slower than the rules' own best pace record", [f_split.pace, st_runs.prs.bestPaceSecPerKm])

	# --- endurance -------------------------------------------------------------------
	var en_want = 1.0 + 60.0 * log(1.0 + 10.0 / 2.0) / log(1.0 + 42.2 / 2.0) * (1.0 - exp(-4.0 / 3.0)) + 20.0 * log(1.0 + 60.0 / 30.0) / log(1.0 + 5000.0 / 30.0) + 12.0 * log(1.0 + 30.0 / 20.0) / log(1.0 + 2000.0 / 20.0)
	ok(near(RpgStats.endurance_raw(10.0, 4.0, 60.0, 30.0), en_want), "endurance, to the letter", [RpgStats.endurance_raw(10.0, 4.0, 60.0, 30.0), en_want])
	var far = blank_save()
	far.sessions = [run("2026-11-10", 10000.0, 3300), ride("2026-11-11", 40000.0), walk("2026-11-12", 6000.0, 10.0), lift("2026-11-13", {"Squat - Barbell": three(5, 60)})]
	var f_far = RpgStats.scan(inp(far), TODAY)
	ok(near(RpgStats._km(f_far), 10.0 + 0.3 * 40.0 + 0.5 * 6.0) and int(f_far.sessions) == 4 and near(float(raws(far).endurance), RpgStats.endurance_raw(10.0, 1.0, 25.0, 4.0)),
		"its distance: runs, 0.3 of the rides, 0.5 of the vest walks; every session of any kind counts", [RpgStats._km(f_far), f_far.sessions])

	# --- grip ----------------------------------------------------------------------
	ok(near(RpgStats.grade_pts(-1, null), 9.0) and near(RpgStats.grade_pts(0, null), 14.0) and near(RpgStats.grade_pts(4, null), 34.0) and near(RpgStats.grade_pts(10, null), 64.0) and near(RpgStats.grade_pts(null, null), 0.0),
		"the hardest send: VB 9, V0 14, V4 34, V10 64; never sent 0")
	ok(near(RpgStats.grade_pts(5, 4), 41.0) and near(RpgStats.grade_pts(5, 5), 41.0) and near(RpgStats.grade_pts(5, 3), 39.0) and near(RpgStats.grade_pts(5, null), 39.0), "+2 when the hardest flash is within a grade of it")
	var gr_want = 1.0 + (34.0 + minf(10.0, 0.2 * 20.0) + minf(6.0, 45.0 / 20.0)) * (1.0 - exp(-12.0 / 3.0)) + 20.0 * log(1.0 + 150.0 / 30.0) / log(1.0 + 3000.0 / 30.0) + 6.0 * log(1.0 + 80.0 / 100.0) / log(1.0 + 3000.0 / 100.0)
	ok(near(RpgStats.grip_raw(34.0, 20.0, 45.0, 12.0, 150.0, 80.0), gr_want) and near(RpgStats.grip_raw(34.0, -15.0, 0.0, 12.0, 0.0, 0.0), 1.0 + 34.0 * (1.0 - exp(-4.0)))
		and near(RpgStats.grip_raw(0.0, 500.0, 900.0, 300.0, 0.0, 0.0), 1.0 + 16.0 * (1.0 - exp(-100.0))),
		"grip, to the letter (an assisted hang adds nothing; the hang parts stop at 10 and 6)", [RpgStats.grip_raw(34.0, 20.0, 45.0, 12.0, 150.0, 80.0), gr_want])
	var crag = blank_save()
	crag.sessions = [climb("2026-11-10", [[2, "flash", 3], [3, "send", 2], [6, "attempt", 5], [5, "send", 0]]),
		climb("2026-11-12", [["5.11a", "send", 1], ["5.12a", "attempt", 2]], [{"edgeMm": 20, "sec": 10, "arms": 2, "addKg": 12.5, "count": 3}, {"edgeMm": 20, "sec": 4, "arms": 2, "addKg": 40.0, "count": 1}, {"edgeMm": 20, "sec": 8, "arms": 1, "addKg": 30.0, "count": 1}, {"edgeMm": 0, "sec": 50, "arms": 2, "addKg": -10.0, "count": 1}])]
	var f_crag = RpgStats.scan(inp(crag), TODAY)
	ok(int(f_crag.max_send) == 3 and int(f_crag.max_flash) == 2 and int(f_crag.sends) == 6 and int(f_crag.climb_sessions) == 2,
		"sends and flashes count, tries that did not go and entries with no count do not; a 5.11a is a V3", [f_crag.max_send, f_crag.max_flash, f_crag.sends])
	ok(near(float(f_crag.best_hang_kg), 12.5) and int(f_crag.longest_hang_sec) == 50, "the heaviest two-arm hang of 5 s or more, and the longest hang", [f_crag.best_hang_kg, f_crag.longest_hang_sec])
	var st_crag = state_of(crag, TODAY)
	ok(near(float(st_crag.prs.bestHangKg), float(f_crag.best_hang_kg)) and int(st_crag.prs.longestHangSec) == int(f_crag.longest_hang_sec) and int(st_crag.totals.climbSends) == int(f_crag.sends),
		"the same records and totals as the rules keep", [st_crag.prs.bestHangKg, st_crag.prs.longestHangSec, st_crag.totals.climbSends])
	crag.sessions.append(climb("2026-11-14", [["5.12a", "flash", 1]]))
	var f_route = RpgStats.scan(inp(crag), TODAY)
	ok(int(f_route.max_send) == Xp.yds_to_v(Xp.yds_index("5.12a")) and int(f_route.max_flash) == int(f_route.max_send), "a route counts as the boulder grade it is worth", [f_route.max_send])

	# --- mind ----------------------------------------------------------------------
	var mi_want = 1.0 + 45.0 * log(1.0 + 600.0 / 150.0) / log(1.0 + 30000.0 / 150.0) + minf(20.0, 7.0) + minf(15.0, 9.0 / 2.0) + minf(8.0, 40.0 / 25.0)
	ok(near(RpgStats.mind_raw(600.0, 7.0, 9.0, 40.0), mi_want) and near(RpgStats.mind_raw(0.0, 99.0, 99.0, 9999.0), 1.0 + 20.0 + 15.0 + 8.0), "mind, to the letter", [RpgStats.mind_raw(600.0, 7.0, 9.0, 40.0), mi_want])
	ok(near(RpgStats.book_pts(3, 3), 6.0) and near(RpgStats.book_pts(7, 7), 12.0) and near(RpgStats.book_pts(3, 0), 3.0) and near(RpgStats.book_pts(7, 2), 2.0 + 2.0 + 1.0 + 1.0 + 1.0 + 0.5 + 0.5) and near(RpgStats.book_pts(0, 0), 0.0),
		"a finished book 2 (1 after the fifth); one never read through the game half")
	var reader = blank_save()
	reader.reading = [read("2026-11-01", 30), read("2026-11-02", 30), read("2026-11-03", 30), read("2026-11-10", 50), read("2026-11-11", 10), read("2026-11-11", 15), read("2026-11-30", 400)]
	reader.books = [book("On The Shelf", "finished"), book("Read Here", "finished", "2026-11-11", {"2026-11-11": [280, 300]}), book("Not Yet", "reading"), book("Next Month", "finished", "2026-12-02", {"2026-12-02": [1, 300]})]
	var f_read = RpgStats.scan(inp(reader), TODAY)
	ok(int(f_read.pages) == 165 and int(f_read.read_days) == 5 and int(f_read.best_read_streak) == 3 and int(f_read.books) == 2 and int(f_read.books_logged) == 1,
		"pages, days read, the longest run of days and the finished books, up to today", [f_read.pages, f_read.read_days, f_read.best_read_streak, f_read.books])
	ok(near(float(raws(reader).mind), RpgStats.mind_raw(165.0, 3.0, 3.0, 5.0)), "and the stat they make")
	var st_read = state_of(reader, "2026-11-25")
	ok(int(Reading.best_streak(st_read)) >= 3 and int(RpgStats.scan(inp(reader, "2026-12-05"), "2026-12-05").pages) == int(Reading.pages(st_read)), "the rules count the same pages")

	# --- grit ----------------------------------------------------------------------
	var gt_want = 1.0 + 40.0 * log(1.0 + 100.0 / 20.0) / log(1.0 + 1500.0 / 20.0) + minf(20.0, 2.0 * 6.0) + minf(15.0, 0.5 * 4.0) + 3.0
	ok(near(RpgStats.grit_raw(100.0, 6.0, 4.0), gt_want) and near(RpgStats.grit_raw(100.0, 0.0, 0.0), 1.0 + 40.0 * log(6.0) / log(76.0)) and near(RpgStats.grit_raw(0.0, 40.0, 99.0), 1.0 + 20.0 + 15.0 + 3.0),
		"grit, to the letter (+3 once a week was on the goal)", [RpgStats.grit_raw(100.0, 6.0, 4.0), gt_want])
	var mixed = mixed_log()
	var st_mixed = state_of(mixed, TODAY)
	var f_mixed = RpgStats.scan(inp(mixed), TODAY)
	ok(int(f_mixed.active_days) == int(st_mixed.totals.activeDays) and int(f_mixed.best_week_streak) == int(st_mixed.streak.best) and int(f_mixed.sessions) == int(st_mixed.totals.sessions),
		"days trained and the best run of weeks on the goal are the rules' own (state.totals.activeDays, state.streak.best)", [f_mixed.active_days, st_mixed.totals.activeDays, f_mixed.best_week_streak, st_mixed.streak.best])
	ok(int(f_mixed.perfect_days) == mixed.claims.size() and mixed.claims.size() >= 3, "perfect days are the claims ending in :perfect", f_mixed.perfect_days)
	var other_claims = mixed.duplicate(true)
	other_claims.claims.append({"id": "x1", "questId": "t:2026-11-20:show", "xp": 50, "claimedAt": 5, "date": "2026-11-20"})
	other_claims.claims.append({"id": "x2", "questId": "todo:abc", "xp": 20, "claimedAt": 6, "date": "2026-11-20"})
	ok(changed(raws(mixed), raws(other_claims)).is_empty(), "other claims change nothing")
	var with_goal = inp(mixed, TODAY, true)
	ok(near(float(RpgStats.sheet(with_goal).stats.grit.raw), float(raws(mixed).grit)), "with the real state passed in the sheet is the same")

	# --- the long mixed log: the sheet is whole ----------------------------------------
	var sh = RpgStats.sheet(inp(mixed))
	bad = []
	for id in RpgDefs.STATS:
		var s = sh.stats[id]
		if not (float(s.raw) >= 1.0 and float(s.raw) <= 99.99) or is_nan(float(s.raw)) or int(s.v) != int(floor(float(s.raw))) or float(s.was) > float(s.raw) + 1e-12 or float(s.was) < 1.0 or s.lines.is_empty() or str(s.next) == "":
			bad.append(id)
		for line in s.lines:
			if not (line is String) or str(line).strip_edges() == "":
				bad.append(id + ": an empty line")
	ok(bad.is_empty(), "a long mixed log: every stat between 1 and 99.99, v its floor, was not above it, lines and next said", bad)
	ok(RpgDefs.STATS.all(func(id): return float(sh.stats[id].raw) > 3.0), "everything was trained, so every stat is above 3", short(mixed))
	var body_mean = 0.0
	for id in RpgDefs.BODY:
		body_mean += float(sh.stats[id].raw)
	ok(near(float(sh.might), body_mean / 6.0) and int(sh.days) == int(st_mixed.totals.activeDays) and int(sh.sessions) == mixed.sessions.size(), "might is the mean of the six body stats; days and sessions are counted")
	var words = ""
	for id in RpgDefs.STATS:
		words += "\n".join(PackedStringArray(sh.stats[id].lines)) + "\n" + str(sh.stats[id].next) + "\n"
	ok(not words.contains(" kg") and not words.contains(" km") and not words.contains("/km") and words.contains(" lb") and words.contains(" mi") and words.contains("/mi"),
		"a player in pounds and miles reads no kg and no km", words)
	ok(sh.stats.legs.lines[0] == "Best: Squat 220.5 lb x 5" and sh.stats.chest.lines[0] == "Best: Bench Press 181.9 lb x 5", "the best set as it was really lifted, in the player's unit", [sh.stats.legs.lines, sh.stats.chest.lines])
	ok(str(sh.stats.shoulders.lines[1]).contains("L+R") or str(sh.stats.shoulders.lines[0]).contains("L+R"), "reps that are both sides added up say so", sh.stats.shoulders.lines)
	ok(not words.contains("1RM") and not words.contains("e1rm") and not words.contains("estimated"), "no estimated max is shown anywhere")
	var metric = mixed.duplicate(true)
	metric.settings.weightUnit = "kg"
	metric.settings.distanceUnit = "km"
	var shm = RpgStats.sheet(inp(metric))
	ok(shm.stats.legs.lines[0] == "Best: Squat 100 kg x 5" and str(shm.stats.endurance.lines[0]) == "Longest run: 5.2 km" and near(float(shm.stats.legs.raw), float(sh.stats.legs.raw)) and str(shm.stats.speed.lines[0]).contains("/km"),
		"the same log in kg and km: other words, the same numbers", [shm.stats.legs.lines, shm.stats.endurance.lines, shm.stats.speed.lines])
	var kinds_seen = {}
	for mk in f_mixed.moves:
		kinds_seen[str(f_mixed.moves[mk].kind)] = true
	ok(kinds_seen.has("kg") and kinds_seen.has("reps") and kinds_seen.has("bw") and kinds_seen.has("hold") and kinds_seen.has("band"), "the log holds weighted, bodyweight, weighted bodyweight, hold and band bests", kinds_seen.keys())
	var back_json = JSON.parse_string(JSON.stringify(mixed))
	ok(changed(raws(mixed), raws(back_json)).is_empty(), "the same sheet from a save that went through a file (whole numbers as floats)")
	var stored_backwards = mixed.duplicate(true)
	stored_backwards.sessions.reverse()
	stored_backwards.reading.reverse()
	var sh_back = RpgStats.sheet(inp(stored_backwards))
	ok(changed(raws(mixed), raws(stored_backwards)).is_empty() and RpgDefs.STATS.all(func(id): return sh_back.stats[id].lines == sh.stats[id].lines and str(sh_back.stats[id].next) == str(sh.stats[id].next)),
		"the order the sessions are stored in changes nothing: the same numbers, the same words")
	var tie = blank_save()
	tie.sessions = [lift("2026-11-20", {"Squat - Front": three(5, 100)}), lift("2026-11-05", {"Squat - Barbell": three(5, 100)}), lift("2026-11-12", {"Squat - Barbell": three(5, 100)})]
	var f_tie = RpgStats.scan(inp(tie), TODAY)
	ok(str(f_tie.top.legs[0].date) == "2026-11-05" and str(f_tie.top.legs[0].name) == "Squat - Barbell", "of two sets as good, the earlier day's is the best ever", f_tie.top.legs[0])

	# --- "was" is the sheet of a week earlier ------------------------------------------
	var earlier = RpgStats.sheet(inp(mixed, Dates.add_days(TODAY, -7)))
	bad = []
	for id in RpgDefs.STATS:
		if not near(float(sh.stats[id].was), float(earlier.stats[id].raw), 1e-12):
			bad.append("%s %s / %s" % [id, str(sh.stats[id].was), str(earlier.stats[id].raw)])
	ok(bad.is_empty(), "was = the raw of the same log seven days ago", bad)
	ok(RpgDefs.STATS.any(func(id): return float(sh.stats[id].raw) > float(sh.stats[id].was) + 0.01), "a week of training moved something")
	# (the sheet takes both days from one pass: each must be what its own pass gives)
	var alone_now = RpgStats.raws_of(RpgStats.scan(inp(mixed), TODAY))
	var alone_was = RpgStats.raws_of(RpgStats.scan(inp(mixed), Dates.add_days(TODAY, -7)))
	var pair = RpgStats.scan_pair(inp(stored_backwards), Dates.add_days(TODAY, -7), TODAY)
	var pair_was = RpgStats.raws_of(pair[0])
	var pair_now = RpgStats.raws_of(pair[1])
	bad = []
	for id in RpgDefs.STATS:
		if not near(float(sh.stats[id].raw), float(alone_now[id]), 1e-12) or not near(float(sh.stats[id].was), float(alone_was[id]), 1e-12):
			bad.append("%s: the sheet" % id)
		if not near(float(pair_was[id]), float(alone_was[id])) or not near(float(pair_now[id]), float(alone_now[id])):
			bad.append("%s: the pair" % id)
	ok(bad.is_empty() and str(pair[0].cutoff) == Dates.add_days(TODAY, -7) and str(pair[1].cutoff) == TODAY and int(pair[1].sessions) == mixed.sessions.size() and int(pair[0].sessions) < int(pair[1].sessions)
		and int(sh.facts.sessions) == int(RpgStats.scan(inp(mixed), TODAY).sessions) and JSON.stringify(sh.facts.top) == JSON.stringify(RpgStats.scan(inp(mixed), TODAY).top),
		"two days from one pass are the two days each from its own pass, however the sessions are stored", bad)
	var same_day = RpgStats.scan_pair(inp(mixed), TODAY, TODAY)
	var same_a = RpgStats.raws_of(same_day[0])
	var same_b = RpgStats.raws_of(same_day[1])
	ok(RpgDefs.STATS.all(func(id): return near(float(same_a[id]), float(alone_now[id])) and near(float(same_b[id]), float(alone_now[id]))), "(and the same day twice is that day twice)")
	var future = mixed.duplicate(true)
	future.sessions.append(lift(Dates.add_days(TODAY, 3), {"Squat - Barbell": three(5, 300)}))
	future.reading.append(read(Dates.add_days(TODAY, 2), 900))
	future.claims.append(perfect(Dates.add_days(TODAY, 1)))
	future.body.append(weigh(Dates.add_days(TODAY, 1), 60.0))
	ok(changed(raws(mixed), raws(future)).is_empty(), "nothing dated after today is counted")

	# --- nothing depends on a CURRENT streak --------------------------------------------
	var later = raws(mixed, Dates.add_days(TODAY, 400))
	ok(changed(raws(mixed), later).is_empty(), "the same log looked at 400 days later, with nothing new: every stat is the same", changed(raws(mixed), later))
	var later_sheet = RpgStats.sheet(inp(mixed, Dates.add_days(TODAY, 400)))
	ok(RpgDefs.STATS.all(func(id): return near(float(later_sheet.stats[id].was), float(later_sheet.stats[id].raw))), "and then was is the same as now")

	# --- monotonic: more never lowers anything -------------------------------------------
	var before = raws(mixed)
	var worst = []
	var tried = 0
	for si in range(mixed.sessions.size()):
		var s = mixed.sessions[si]
		if str(s.discipline) != "lift" or si % 3 != 0:
			continue
		for ei in range(s.exercises.size()):
			var heavier = mixed.duplicate(true)
			var sets = heavier.sessions[si].exercises[ei].sets
			sets[0].weightKg = float(sets[0].weightKg) + 2.5
			worst.append_array(lower(before, raws(heavier)))
			var more = mixed.duplicate(true)
			more.sessions[si].exercises[ei].sets.append(more.sessions[si].exercises[ei].sets[0].duplicate())
			worst.append_array(lower(before, raws(more)))
			var reps = mixed.duplicate(true)
			reps.sessions[si].exercises[ei].sets[0].reps = int(reps.sessions[si].exercises[ei].sets[0].reps) + 2
			worst.append_array(lower(before, raws(reps)))
			tried += 3
	ok(worst.is_empty() and tried > 150, "more weight, another set or more reps on any exercise never lowers a stat (%d tries)" % tried, worst.slice(0, 5))
	var up = mixed.duplicate(true)
	up.sessions.append(lift(TODAY, {"Bench Press - Barbell": three(5, 90), "Squat - Barbell": three(5, 110), "Lat Pulldown": three(10, 60), "Overhead Press - Barbell": three(6, 50),
		"Bicep Curl - Dumbbell": three(10, 16), "Plank": [[1, 0, 90]]}))
	var after_up = raws(up)
	ok(lower(before, after_up).is_empty() and RpgDefs.BODY.all(func(id): return float(after_up[id]) > float(before[id])), "a heavier session raises all six body stats", [before, after_up])
	worst = []
	var faster_better = true
	var harder_better = true
	for si in range(mixed.sessions.size()):
		var s = mixed.sessions[si]
		if str(s.discipline) == "run" and s.has("durationSec"):
			var quick = mixed.duplicate(true)
			quick.sessions[si].durationSec = int(quick.sessions[si].durationSec) - 120
			var r = raws(quick)
			worst.append_array(lower(before, r))
			faster_better = faster_better and float(r.speed) >= float(before.speed)
		if str(s.discipline) == "run":
			var longer = mixed.duplicate(true)
			longer.sessions[si].distanceM = float(longer.sessions[si].distanceM) + 2000.0
			if longer.sessions[si].has("durationSec"):
				longer.sessions[si].durationSec = int(float(longer.sessions[si].durationSec) * float(longer.sessions[si].distanceM) / float(s.distanceM))
			worst.append_array(lower(before, raws(longer)))
		if str(s.discipline) == "climb":
			var hard = mixed.duplicate(true)
			for c in hard.sessions[si].climbs:
				if not c.has("yds"):
					c.grade = int(c.grade) + 1
			var r = raws(hard)
			worst.append_array(lower(before, r))
			harder_better = harder_better and float(r.grip) >= float(before.grip)
	ok(worst.is_empty() and faster_better and harder_better, "a faster run, a longer run at the same pace and harder sends never lower a stat", worst.slice(0, 5))
	var fastest = mixed.duplicate(true)
	for s in fastest.sessions:
		if str(s.discipline) == "run" and s.has("durationSec"):
			s.durationSec = int(float(s.durationSec) * 0.8)
			s.erase("splits")
	var hardest = mixed.duplicate(true)
	for s in hardest.sessions:
		if str(s.discipline) == "climb":
			s.climbs.append({"grade": 6, "result": "send", "count": 1})
	ok(float(raws(fastest).speed) > float(before.speed) + 1.0 and float(raws(hardest).grip) > float(before.grip) + 5.0 and changed(before, raws(hardest)) == ["grip"],
		"runs a fifth faster raise speed; a V6 raises grip and only grip", [before.speed, raws(fastest).speed, before.grip, raws(hardest).grip])
	var pages_up = mixed.duplicate(true)
	for e in pages_up.reading:
		e.pages = int(e.pages) + 10
	var shelf_up = mixed.duplicate(true)
	shelf_up.books.append(book("One More", "finished", TODAY, {TODAY: [200, 300]}))
	ok(changed(before, raws(pages_up)) == ["mind"] and float(raws(pages_up).mind) > float(before.mind) and changed(before, raws(shelf_up)) == ["mind"] and float(raws(shelf_up).mind) >= float(before.mind) + 0.99,
		"more pages and another finished book raise mind and only mind", [before.mind, raws(pages_up).mind, raws(shelf_up).mind])
	var pt_up = mixed.duplicate(true)
	for s in pt_up.sessions:
		if str(s.discipline) == "lift":
			for ex in s.exercises:
				if str(ex.name) == "Clamshell - Band":
					ex.sets.append({"reps": 15, "weightKg": 0.0, "band": "red"})
	ok(changed(before, raws(pt_up)) == ["flow"] and float(raws(pt_up).flow) > float(before.flow), "more PT raises flow and only flow", [before.flow, raws(pt_up).flow])
	var heavier_me = mixed.duplicate(true)
	heavier_me.body.append(weigh(TODAY, 99.0))
	ok(changed(before, raws(heavier_me)).is_empty(), "a new weigh-in changes no stat (a weighted dip done today is measured against the check-in before it)", changed(before, raws(heavier_me)))
	var bw_log = blank_save()
	bw_log.body = [weigh("2026-11-10", 80.0), weigh("2026-11-20", 100.0)]
	bw_log.sessions = [lift("2026-11-10", {"Pull-up - Weighted": [[10, 20]]}), lift("2026-11-12", {"Chin-up - Weighted": [[10, 20]]}), lift("2026-11-22", {"Dip - Weighted": [[7, 20]]})]
	var f_bw = RpgStats.scan(inp(bw_log), TODAY)
	ok(near(float(f_bw.moves["pull-up"].ss), 0.4 * (1.0 + 20.0 / 75.0)) and near(float(f_bw.moves["chin-up"].ss), 0.4 * (1.0 + 20.0 / 80.0)) and near(float(f_bw.moves["dip"].ss), 0.2 * (1.0 + 20.0 / 100.0)),
		"the bodyweight a set is measured against: the newest check-in before its day, 75 kg when there is none yet", [f_bw.moves["pull-up"].ss, f_bw.moves["chin-up"].ss, f_bw.moves["dip"].ss])
	var claim_up = mixed.duplicate(true)
	claim_up.claims.append(perfect(Dates.add_days(TODAY, -1)))
	ok(changed(before, raws(claim_up)) == ["grit"] and near(float(raws(claim_up).grit) - float(before.grit), 0.5), "a perfect day is half a point of grit", raws(claim_up).grit)

	# --- deleting nothing can raise a stat ------------------------------------------------
	worst = []
	for si in range(mixed.sessions.size()):
		var less = mixed.duplicate(true)
		less.sessions.remove_at(si)
		worst.append_array(lower(raws(less), before))
	ok(worst.is_empty(), "taking any one session out never raises a stat (%d sessions)" % mixed.sessions.size(), worst.slice(0, 5))
	worst = []
	for key in ["reading", "books", "claims"]:
		for i in range(mixed[key].size()):
			var less = mixed.duplicate(true)
			less[key].remove_at(i)
			worst.append_array(lower(raws(less), before))
	ok(worst.is_empty(), "nor does taking out a day's pages, a book or a claim", worst.slice(0, 5))
	var cut = mixed.duplicate(true)
	cut.sessions = cut.sessions.filter(func(s): return str(s.date) <= Dates.add_days(TODAY, -30))
	cut.reading = cut.reading.filter(func(e): return str(e.date) <= Dates.add_days(TODAY, -30))
	ok(lower(raws(cut), before).is_empty() and changed(raws(cut), before).size() >= 10, "the log as it was a month ago: nothing was higher then")
	var week_by_week = []
	var prev = raws(blank_save())
	for w in range(11):
		var now = raws(mixed, Dates.add_days(TODAY, -70 + w * 7))
		week_by_week.append_array(lower(prev, now))
		prev = now
	ok(week_by_week.is_empty(), "week after week of the log no stat ever goes down", week_by_week)

	# --- the nearest way to the next point is true -----------------------------------------
	var pt_set = {"reps": 15, "weightKg": 0.0}
	var n_flow = number_before(str(sh.stats.flow.next), "more sets? of physical therapy")
	ok(n_flow > 0 and str(sh.stats.flow.next).begins_with("Next point: ")
		and int(RpgStats.sheet(inp(with_sets(mixed, "Clamshell - Band", n_flow, pt_set))).stats.flow.v) == int(sh.stats.flow.v) + 1
		and int(RpgStats.sheet(inp(with_sets(mixed, "Clamshell - Band", n_flow - 1, pt_set))).stats.flow.v) == int(sh.stats.flow.v),
		"flow: that many more PT sets is the next point, one fewer is not", [sh.stats.flow.next, n_flow])
	var n_mind = number_before(str(sh.stats.mind.next), "more pages?")
	var mind_more = mixed.duplicate(true)
	mind_more.reading[0].pages = int(mind_more.reading[0].pages) + n_mind
	var mind_less = mixed.duplicate(true)
	mind_less.reading[0].pages = int(mind_less.reading[0].pages) + n_mind - 1
	ok(n_mind > 0 and int(RpgStats.sheet(inp(mind_more)).stats.mind.v) == int(sh.stats.mind.v) + 1 and int(RpgStats.sheet(inp(mind_less)).stats.mind.v) == int(sh.stats.mind.v),
		"mind: that many more pages is the next point, one fewer is not", [sh.stats.mind.next, n_mind])
	var light = {"reps": 5, "weightKg": 60.0}
	var n_back = number_before(str(sh.stats.back.next), "more sets? for it")
	ok(n_back > 0 and int(RpgStats.sheet(inp(with_sets(mixed, "Bent Over Row - Barbell", n_back, light))).stats.back.v) == int(sh.stats.back.v) + 1
		and int(RpgStats.sheet(inp(with_sets(mixed, "Bent Over Row - Barbell", n_back - 1, light))).stats.back.v) == int(sh.stats.back.v),
		"back: that many more sets is the next point, one fewer is not", [sh.stats.back.next, n_back])
	var n_grit = number_before(str(sh.stats.grit.next), "more days? trained")
	var grit_more = mixed.duplicate(true)
	var grit_less = mixed.duplicate(true)
	for k in range(n_grit):
		# (days before the log began: no week of it changes)
		grit_more.sessions.append(ride(Dates.add_days(TODAY, -400 - k * 9), 1000.0))
		if k < n_grit - 1:
			grit_less.sessions.append(ride(Dates.add_days(TODAY, -400 - k * 9), 1000.0))
	ok(n_grit > 0 and int(RpgStats.sheet(inp(grit_more)).stats.grit.v) == int(sh.stats.grit.v) + 1 and int(RpgStats.sheet(inp(grit_less)).stats.grit.v) == int(sh.stats.grit.v),
		"grit: that many more days trained is the next point, one fewer is not", [sh.stats.grit.next, n_grit])
	var first = player_first()
	var sh_first = RpgStats.sheet(inp(first))
	ok(str(sh_first.stats.chest.next).contains("one more chest day") and str(sh_first.stats.speed.next) == "Log a run to start it." and str(sh_first.stats.grip.next) == "Log a climbing session to start it."
		and str(sh_first.stats.mind.next) == "Log the pages you read to start it." and str(sh_first.stats.flow.next) == "Log physical therapy or a stretch to start it.",
		"after a first session: a second day of a part is the nearest point; untouched traits say how to start", [sh_first.stats.chest.next, sh_first.stats.speed.next])
	ok(str(sh_first.stats.endurance.next).begins_with("Next point: a run, or ") and str(sh.stats.endurance.next).contains("a run of ") and str(sh.stats.endurance.next).contains(" mi"),
		"endurance: with no run yet any run is the next point; later it is a run longer than the longest, in miles", [sh_first.stats.endurance.next, sh.stats.endurance.next])
	var ran = first.duplicate(true)
	ran.sessions.append(run(TODAY, 1000.0))
	ok(int(RpgStats.sheet(inp(ran)).stats.endurance.v) > int(sh_first.stats.endurance.v), "and a first short run does give it")
	var next_day = first.duplicate(true)
	next_day.sessions.append(lift(Dates.add_days(TODAY, -2), {"Bench Press - Barbell": [[8, 40], [8, 40], [8, 40], [8, 40]]}))
	ok(int(RpgStats.sheet(inp(next_day)).stats.chest.v) > int(sh_first.stats.chest.v), "and one more chest day does give it")
	var strong = only_lifts({"Squat - Barbell": three(5, 100)})
	for d in range(1, 14):
		strong.sessions.append(lift(Dates.add_days(TODAY, -d), {"Squat - Barbell": three(5, 100)}))
	strong.settings.weightUnit = "lb"
	var sh_strong = RpgStats.sheet(inp(strong))
	var rx_w = RegEx.new()
	rx_w.compile("Squat ([0-9.]+) lb x 5")
	var m_w = rx_w.search(str(sh_strong.stats.legs.next))
	var goal_lb = float(m_w.get_string(1)) if m_w != null else 0.0
	var did = strong.duplicate(true)
	did.sessions[0].exercises[0].sets[0].weightKg = Fmt.unit_to_kg(goal_lb, "lb")
	var not_quite = strong.duplicate(true)
	not_quite.sessions[0].exercises[0].sets[0].weightKg = Fmt.unit_to_kg(goal_lb - 5.0, "lb")
	ok(goal_lb > 220.5 and is_equal_approx(fmod(goal_lb, 5.0), 0.0) and int(RpgStats.sheet(inp(did)).stats.legs.v) == int(sh_strong.stats.legs.v) + 1 and int(RpgStats.sheet(inp(not_quite)).stats.legs.v) == int(sh_strong.stats.legs.v),
		"legs: the heavier set it names (a whole plate step in pounds) is the next point, a step less is not", [sh_strong.stats.legs.next, goal_lb])

	# --- one session, a month, eight months -----------------------------------------------
	ok(RpgDefs.BODY.all(func(id): return float(sh_first.stats[id].raw) > 1.0 and float(sh_first.stats[id].raw) < 12.0) and float(sh_first.stats.grit.raw) < 5.0 and float(sh_first.might) < 8.0,
		"a first session: every part trained is above 1 and nothing is high yet", short(first))
	var month = player_month()
	var sh_month = RpgStats.sheet(inp(month))
	ok(int(sh_month.sessions) == 12 and int(sh_month.days) == 12 and RpgDefs.BODY.all(func(id): return float(sh_month.stats[id].raw) > float(sh_first.stats[id].raw))
		and float(sh_month.might) > 10.0 and float(sh_month.might) < 35.0 and float(sh_month.stats.grit.raw) > float(sh_first.stats.grit.raw) + 5.0,
		"a month of three days a week: every body stat above the first day's, a beginner's might", short(month))
	var eight = player_eight_months()
	var t0 = Time.get_ticks_msec()
	var sh_eight = RpgStats.sheet(inp(eight))
	var took = Time.get_ticks_msec() - t0
	ok(RpgDefs.STATS.all(func(id): return float(sh_eight.stats[id].raw) > float(sh_month.stats[id].raw) and float(sh_eight.stats[id].raw) < 90.0) and float(sh_eight.might) > float(sh_month.might) + 10.0,
		"eight months of everything: every stat above the month's, none at the top", short(eight))
	ok(took < 3000, "the sheet of %d sessions takes %d ms" % [eight.sessions.size(), took])
	var st_eight = state_of(eight, TODAY)
	ok(int(sh_eight.days) == int(st_eight.totals.activeDays) and int(sh_eight.facts.best_week_streak) == int(st_eight.streak.best) and int(sh_eight.facts.pages) == Reading.pages(st_eight)
		and int(sh_eight.facts.sends) == int(st_eight.totals.climbSends) and near(float(sh_eight.facts.longest_run_m), float(st_eight.prs.longestRunM)) and int(sh_eight.facts.max_send) == int(st_eight.prs.climbMaxSend),
		"its counts are the rules' own", [sh_eight.days, st_eight.totals.activeDays])
	print("PLAYER first         %s" % short(first))
	print("PLAYER month         %s" % short(month))
	print("PLAYER eight months  %s" % short(eight))
	print("PLAYER mixed 10 wk   %s" % short(mixed))

	var folder = OS.get_environment("RPG_STATS_DUMP")
	if folder != "":
		dump(folder, "first.json", first)
		dump(folder, "month.json", month)
		dump(folder, "eight_months.json", eight)

	print("RPG STATS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
