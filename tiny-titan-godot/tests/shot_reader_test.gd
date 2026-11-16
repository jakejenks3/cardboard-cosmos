extends SceneTree
## Unit tests for game/shot_reader.gd (what a screenshot says) and for how
## game/quick_log.gd turns that into runs, rides and weigh-ins.
##   godot --headless --path . --script res://tests/shot_reader_test.gd
## Prints SHOTS: X/Y passed and exits with 1 when anything fails.
##
## The pages below are laid out like real phone screenshots (positions in
## pixels on a 920 x 1999 picture) with made-up names and numbers.

const TODAY = "2026-11-15"  # a Sunday

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


## One line of text as the text reader reports it: words with their boxes.
## `tall_first` makes the first word taller (a logo or avatar letter on the line).
func line(text: String, x: int, y: int, w: int, h: int, tall_first: int = 0) -> Dictionary:
	var parts = text.split(" ", false)
	var chars = 0
	for p in parts:
		chars += p.length()
	var gap = h * 0.3
	var per = (float(w) - gap * float(parts.size() - 1)) / float(maxi(chars, 1))
	var words = []
	var cx = float(x)
	for i in range(parts.size()):
		var ww = per * float(parts[i].length())
		var hh = tall_first if i == 0 and tall_first > 0 else h
		words.append({"t": parts[i], "x": int(cx), "y": y - (hh - h), "w": int(ww), "h": hh})
		cx += ww + gap
	return {"t": text, "words": words}


func page_of(lines: Array, w: int = 920, h: int = 1999) -> Dictionary:
	return ShotReader.page({"w": w, "h": h, "lines": lines})


func read(lines: Array, w: int = 920, h: int = 1999) -> Dictionary:
	return ShotReader.read(page_of(lines, w, h))


# --- pages -------------------------------------------------------------------

func strava_run() -> Array:
	return [
		line("9:41", 106, 42, 83, 30), line("< Music", 29, 80, 113, 24), line("Run", 427, 178, 67, 29),
		line("alex doe", 174, 328, 150, 28),
		line("A Today at 6:15 AM • Springfield, Oregon", 84, 381, 551, 24, 46),
		line("Morning Run", 40, 497, 283, 48),
		line("You reached a 3 week streak!", 165, 647, 392, 23), line("View", 760, 648, 56, 20),
		line("Distance", 201, 770, 95, 20), line("4.02 mi", 184, 812, 128, 30),
		line("Moving Time", 180, 899, 138, 23), line("41:37", 197, 941, 102, 29),
		line("Max Elevation", 172, 1027, 152, 19), line("1,240 ft", 178, 1068, 139, 35),
		line("Athlete Intelligence", 149, 1232, 264, 28),
		line("Avg Pace", 620, 771, 102, 23), line("10:21 Imi", 586, 811, 168, 35),
		line("Elevation Gain", 594, 898, 155, 20), line("112 ft", 629, 940, 83, 30),
		line("Steps", 640, 1027, 62, 23), line("6,480", 622, 1069, 99, 34),
		line("Steady effort on a route you know well by now", 95, 1302, 699, 36),
		line("—a little quicker than last week, and it was", 93, 1355, 710, 35),
		line("your longest outing of the month so far.", 94, 1405, 647, 37),
		line("Say More", 397, 1521, 124, 27), line("With someone who didn't record?", 37, 1732, 499, 27),
		line("Strava App", 120, 1868, 164, 31), line("Add Others", 724, 1736, 130, 19),
	]


func strava_ride() -> Array:
	return [
		line("17:02", 106, 42, 83, 30), line("Ride", 422, 178, 77, 29),
		line("alex doe", 174, 328, 150, 28),
		line("A November 14, 2026 at 6:02 PM • Bend, Oregon", 84, 381, 600, 24, 46),
		line("Evening Ride", 40, 497, 300, 48),
		line("Distance", 201, 770, 95, 20), line("32.5 km", 184, 812, 128, 30),
		line("Moving Time", 180, 899, 138, 23), line("1:20:15", 190, 941, 120, 29),
		line("Calories", 196, 1027, 100, 19), line("850", 210, 1068, 70, 35),
		line("Avg Speed", 620, 771, 110, 23), line("24.3 km/h", 586, 811, 168, 35),
		line("Elevation Gain", 594, 898, 155, 20), line("412 m", 629, 940, 83, 30),
	]


## The short card from the feed: three numbers in a row under their labels.
func feed_card() -> Array:
	return [
		line("alex doe", 120, 60, 150, 28), line("Today at 7:05 AM", 120, 100, 220, 22),
		line("Lunch Run", 40, 170, 230, 40),
		line("Distance", 40, 260, 95, 20), line("Pace", 340, 260, 55, 20), line("Time", 640, 260, 55, 20),
		line("5.01 km", 40, 296, 120, 30), line("5:12 /km", 340, 296, 130, 30), line("26m 4s", 640, 296, 110, 30),
	]


## The same card when the reader returns each row as one line: the columns must not run together.
func feed_card_merged() -> Array:
	var labels = {"t": "Distance Pace Time", "words": [
		{"t": "Distance", "x": 40, "y": 260, "w": 95, "h": 20},
		{"t": "Pace", "x": 340, "y": 260, "w": 55, "h": 20},
		{"t": "Time", "x": 640, "y": 260, "w": 55, "h": 20}]}
	var values = {"t": "5.01 km 5:12 /km 26m 4s", "words": [
		{"t": "5.01", "x": 40, "y": 296, "w": 70, "h": 30}, {"t": "km", "x": 118, "y": 296, "w": 40, "h": 30},
		{"t": "5:12", "x": 340, "y": 296, "w": 70, "h": 30}, {"t": "/km", "x": 418, "y": 296, "w": 50, "h": 30},
		{"t": "26m", "x": 640, "y": 296, "w": 60, "h": 30}, {"t": "4s", "x": 708, "y": 296, "w": 36, "h": 30}]}
	return [line("Lunch Run", 40, 170, 230, 40), line("Today at 7:05 AM", 120, 100, 220, 22), labels, values]


func strava_walk() -> Array:
	return [
		line("Walk", 422, 178, 77, 29), line("Today at 12:10 PM • Bend, Oregon", 84, 381, 420, 24),
		line("Lunch Walk", 40, 497, 260, 48),
		line("Distance", 201, 770, 95, 20), line("1.20 mi", 184, 812, 128, 30),
		line("Moving Time", 180, 899, 138, 23), line("24:10", 197, 941, 102, 29),
		line("Avg Pace", 620, 771, 102, 23), line("20:08 /mi", 586, 811, 168, 35),
	]


func scale() -> Array:
	return [
		line("9:12", 64, 61, 96, 28), line("Weigh-in", 384, 186, 149, 36),
		line("TODAY • 6:50 AM • SCALE X PRO", 47, 301, 508, 21),
		line("180.4", 49, 361, 261, 92), line("lb", 332, 421, 28, 29),
		line("2.1 lb vs sat, Oct 3", 596, 458, 276, 28),
		line("Composition", 46, 602, 214, 36), line("Tap a key for its trend", 569, 608, 303, 28),
		line("Body fat", 75, 704, 103, 26), line("17.2", 74, 755, 72, 31), line("• Healthy 31.0 lb", 73, 821, 211, 23),
		line("Muscle", 357, 704, 88, 21), line("77.1", 355, 754, 80, 32), line("• High", 355, 820, 79, 24), line("139 lb", 500, 821, 66, 19),
		line("Skeletal muscle", 639, 704, 196, 22), line("47.0", 639, 754, 81, 32), line("84.8 lb", 773, 821, 77, 19),
		line("Body water", 75, 916, 141, 27), line("60.2", 74, 966, 73, 32), line("108.6 lb", 196, 1032, 88, 20),
		line("Protein", 357, 916, 87, 21), line("16.1", 356, 966, 73, 32),
		line("Bone mass", 640, 917, 136, 20), line("9.6", 639, 966, 75, 32), line("lb", 721, 978, 19, 19),
		line("Lean body mass", 75, 1129, 203, 26), line("149.4", 74, 1179, 89, 32), line("lb", 171, 1191, 18, 19),
		line("Subcutaneous...", 356, 1129, 201, 22), line("12.4", 356, 1180, 50, 30),
		line("Visceral fat", 639, 1129, 140, 21), line("5", 639, 1179, 25, 31), line("• Normal", 638, 1240, 110, 20), line("of 59", 788, 1240, 60, 20),
		line("Segmental analysis", 78, 1398, 288, 32), line("Fat", 581, 1402, 41, 22), line("Muscle", 708, 1401, 98, 23),
		line("Right arm", 80, 1529, 121, 26), line("1.5 lb", 78, 1574, 79, 29), line("Trunk", 769, 1673, 72, 22), line("19 lb", 773, 1718, 69, 29),
	]


## Another scale app: labels on the left, numbers on the right of the same row.
func scale_rows() -> Array:
	return [
		line("Measurement", 300, 120, 320, 40), line("Nov 12, 2026 at 7:02", 300, 180, 300, 24),
		line("Weight", 60, 400, 110, 30), line("82.4 kg", 700, 400, 140, 30),
		line("Body Fat", 60, 500, 140, 30), line("18.5 %", 720, 500, 120, 30),
		line("BMI", 60, 600, 60, 30), line("24.1", 760, 600, 80, 30),
		line("Muscle Mass", 60, 700, 190, 30), line("63.9 kg", 700, 700, 140, 30),
	]


func words_page(n: int) -> Array:
	var out = []
	for i in range(n):
		out.append(line("some words here", 60, 100 + i * 60, 400, 30))
	return out


# --- parsing -------------------------------------------------------------------

func opts(shots: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var o = {"today": TODAY, "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES, "shots": shots}
	o.merge(extra, true)
	return o


func shot(lines: Array, seen: String = TODAY, id: String = "") -> Dictionary:
	var r = read(lines)
	r["seen"] = seen
	if id != "":
		r["id"] = id
	return r


func p(text: String, shots: Dictionary, extra: Dictionary = {}) -> Dictionary:
	return QuickLog.parse(text, opts(shots, extra))


func near(a, b, eps: float = 0.011) -> bool:
	return a != null and absf(float(a) - float(b)) <= eps


func _init() -> void:
	# --- numbers -----------------------------------------------------------------
	ok(near(ShotReader.num("1,240"), 1240.0) and near(ShotReader.num("4,02"), 4.02) and near(ShotReader.num("12.5"), 12.5) and near(ShotReader.num("1,234.5"), 1234.5), "numbers with commas")
	ok(is_nan(ShotReader.num("2.41b")) and is_nan(ShotReader.num("abc")) and is_nan(ShotReader.num("")), "not numbers")
	ok(ShotReader.clock("41:37") == 2497 and ShotReader.clock("1:02:33") == 3753 and ShotReader.clock("41m 37s") == 2497 and ShotReader.clock("1h 5m") == 3900 and ShotReader.clock("45 min") == 2700 and ShotReader.clock("2h") == 7200, "clock times")
	ok(ShotReader.clock("112 ft") == -1 and ShotReader.clock("") == -1 and ShotReader.clock("10:21 imi") == -1, "not clock times")
	var m = ShotReader.measure("4.02 mi", ShotReader.DIST_UNITS)
	ok(m != null and near(m.v, 4.02) and m.u == "mi", "4.02 mi", m)
	ok(ShotReader.measure("4.02 bananas", ShotReader.DIST_UNITS) == null and ShotReader.measure("6,480", ShotReader.DIST_UNITS).u == "", "units")
	ok(ShotReader.label_key(ShotReader.norm("Avg. Pace:")) == "avg pace" and ShotReader.label_key(ShotReader.norm("Subcutaneous...")) == "subcutaneous", "label keys")

	# --- a Strava run ---------------------------------------------------------------
	var run = read(strava_run())
	ok(run.kind == "run", "run: kind", run)
	ok(near(run.get("dist"), 4.02) and run.get("distUnit") == "mi", "run: 4.02 mi", run)
	ok(run.get("sec") == 2497, "run: 41:37", run)
	ok(near(run.get("elev"), 112.0) and run.get("elevUnit") == "ft", "run: 112 ft up", run)
	ok(run.get("title") == "Morning Run", "run: title", run)
	ok(run.rel == "today" and run.month == 0, "run: says Today", run)
	ok(run.extras == ["Max elevation 1,240 ft", "Steps 6,480"], "run: the rest is kept", run.extras)

	# --- a ride, dated, in km ---------------------------------------------------------
	var ride = read(strava_ride())
	ok(ride.kind == "ride" and near(ride.get("dist"), 32.5) and ride.get("distUnit") == "km", "ride: 32.5 km", ride)
	ok(ride.get("sec") == 4815 and near(ride.get("elev"), 412.0) and ride.get("elevUnit") == "m", "ride: 1:20:15, 412 m", ride)
	ok(ride.month == 11 and ride.day == 14 and ride.year == 2026 and ride.rel == "", "ride: dated November 14, 2026", ride)
	ok(ride.get("title") == "Evening Ride" and ride.extras == ["Calories 850"], "ride: title and calories", ride)

	# --- the feed card ------------------------------------------------------------------
	var card = read(feed_card())
	ok(card.kind == "run" and near(card.get("dist"), 5.01) and card.get("distUnit") == "km" and card.get("sec") == 1564, "feed card: 5.01 km in 26m 4s", card)
	ok(card.get("title") == "Lunch Run" and card.rel == "today", "feed card: title and day", card)
	var merged = read(feed_card_merged())
	ok(merged.kind == "run" and near(merged.get("dist"), 5.01) and merged.get("sec") == 1564, "columns on one line are split", merged)
	ok(page_of(feed_card_merged()).segs.size() == 8, "two lines of three columns -> 6 segments (+2)", page_of(feed_card_merged()).segs.size())

	# --- things that are not runs or rides ------------------------------------------------
	var walk = read(strava_walk())
	ok(walk.kind == "text" and str(walk.why).contains("a walk"), "a walk is left out, with the reason", walk)
	var hike = strava_walk()
	hike[0] = line("Activity", 400, 178, 120, 29)
	hike[2] = line("Evening Hike", 40, 497, 280, 48)
	ok(read(hike).kind == "text" and str(read(hike).why).contains("a hike"), "a hike named only in the title", read(hike))
	var plain = strava_run()
	plain[2] = line("Activity", 400, 178, 120, 29)
	plain[5] = line("Tempo with Sam", 40, 497, 330, 48)
	ok(read(plain).kind == "run", "no sport named: a pace means a run", read(plain))
	var fast = strava_ride()
	fast[1] = line("Activity", 400, 178, 120, 29)
	fast[4] = line("To the lake", 40, 497, 260, 48)
	ok(read(fast).kind == "ride", "no sport named: a speed means a ride", read(fast))
	var nounit = feed_card()
	nounit[6] = line("5.01", 40, 296, 70, 30)
	ok(read(nounit).get("distUnit") == "km", "a distance without a unit takes it from the pace", read(nounit))
	var nodist = [line("Morning Run", 40, 497, 283, 48), line("Moving Time", 180, 899, 138, 23), line("41:37", 197, 941, 102, 29),
		line("Avg Pace", 620, 771, 102, 23), line("10:21 /mi", 586, 811, 168, 35), line("Elevation Gain", 594, 898, 155, 20), line("112 ft", 629, 940, 83, 30)]
	ok(read(nodist).kind == "text" and read(nodist).why == ShotReader.WHY_NO_DISTANCE, "a workout without its distance", read(nodist))
	ok(read([line("Distance", 100, 100, 95, 20), line("4.02 mi", 100, 140, 128, 30), line("to the next turn", 100, 300, 300, 30)]).kind == "photo", "a distance alone is not a workout")

	# --- a weigh-in ---------------------------------------------------------------------------
	var sc = read(scale())
	ok(sc.kind == "body" and near(sc.get("weight"), 180.4) and sc.get("weightUnit") == "lb", "scale: 180.4 lb", sc)
	ok(near(sc.get("fat"), 17.2), "scale: body fat 17.2", sc)
	ok(sc.rel == "today" and sc.month == 0, "scale: Today, and 'vs Sat, Oct 3' is not its date", sc)
	ok(sc.extras == ["Muscle 77.1%", "Skeletal muscle 47.0%", "Body water 60.2%", "Protein 16.1%", "Bone mass 9.6 lb", "Lean body mass 149.4 lb", "Subcutaneous fat 12.4%", "Visceral fat 5"], "scale: the other readings", sc.extras)
	var rows = read(scale_rows())
	ok(rows.kind == "body" and near(rows.get("weight"), 82.4) and rows.get("weightUnit") == "kg" and near(rows.get("fat"), 18.5), "rows: 82.4 kg, 18.5%", rows)
	ok(rows.month == 11 and rows.day == 12 and rows.year == 2026, "rows: dated Nov 12, 2026", rows)
	ok(rows.extras == ["BMI 24.1", "Muscle mass 63.9 kg"], "rows: BMI and muscle mass", rows.extras)

	# Small units next to big digits are often not read at all, or read as "Ib".
	var bare = scale()
	bare.remove_at(4)
	ok(read(bare).kind == "body" and near(read(bare).get("weight"), 180.4) and read(bare).get("weightUnit") == "lb", "the headline number without its unit: lb, as the rest of the page", read(bare))
	var alone = [line("Weigh-in", 300, 141, 120, 26), line("TODAY 6:50 AM SCALE X PRO", 36, 240, 244, 12), line("180.4", 45, 293, 205, 61),
		line("Body fat", 60, 556, 71, 18), line("17.2", 61, 594, 55, 21), line("Muscle", 280, 556, 60, 14), line("77.1", 279, 594, 54, 21)]
	ok(read(alone).kind == "body" and near(read(alone).get("weight"), 180.4) and read(alone).get("weightUnit") == "" and near(read(alone).get("fat"), 17.2), "no unit anywhere: the weight is still found", read(alone))
	var ib = scale()
	ib[4] = line("Ib", 332, 421, 28, 29)
	ok(read(ib).get("weightUnit") == "lb" and near(read(ib).get("weight"), 180.4), "'Ib' is lb", read(ib))
	var w1 = ShotReader.weight_of("2.41b")
	ok(w1 != null and near(w1.v, 2.4) and w1.u == "lb" and near(ShotReader.weight_of("180.4 lb").v, 180.4) and ShotReader.weight_of("82.4 kg").u == "kg" and ShotReader.weight_of("180.4").u == "", "weights as printed, even '2.41b'", w1)
	var small = [line("Settings", 300, 100, 200, 30), line("Weight", 60, 300, 100, 30), line("on", 700, 300, 40, 30), line("Body fat", 60, 400, 120, 30), line("off", 700, 400, 40, 30),
		line("Version 55", 60, 600, 150, 30), line("Sync every 30 minutes", 60, 700, 320, 30)]
	ok(read(small).kind != "body", "numbers of ordinary size on a page about weight are not a weigh-in", read(small))

	var lifts = [line("Bench Press", 60, 200, 260, 40), line("Set", 60, 300, 50, 26), line("Weight", 300, 300, 100, 26), line("Reps", 600, 300, 70, 26),
		line("1", 60, 360, 14, 26), line("225 lb", 300, 360, 90, 26), line("5", 600, 360, 14, 26), line("2", 60, 420, 14, 26), line("225 lb", 300, 420, 90, 26), line("5", 600, 420, 14, 26),
		line("Finish workout", 300, 1500, 300, 40)]
	ok(read(lifts).kind != "body", "a lifting log with a Weight column is not a weigh-in", read(lifts))
	var gym = [line("Weight Training", 330, 178, 260, 29), line("Today at 5:30 PM • Bend, Oregon", 84, 381, 420, 24), line("Evening Weight Training", 40, 497, 560, 48),
		line("Elapsed Time", 180, 770, 150, 22), line("1:05:32", 190, 812, 120, 30), line("Calories", 620, 771, 100, 22), line("320", 640, 811, 60, 32),
		line("Nice work getting it done today.", 95, 1302, 500, 30)]
	ok(read(gym).kind == "text" and str(read(gym).why).contains("a weights session"), "a weights session is named as the reason", read(gym))

	# --- photos and other screenshots ---------------------------------------------------------
	ok(read([]).kind == "photo" and read([line("NIKE", 300, 900, 120, 40)]).kind == "photo", "no words: a photo")
	ok(read(words_page(3)).kind == "photo", "a few words: still a photo", read(words_page(3)))
	ok(read(words_page(8)).kind == "text" and read(words_page(8)).why == ShotReader.WHY_TEXT, "a phone-shaped picture full of words: a screenshot it cannot read", read(words_page(8)))
	ok(read(words_page(5), 1200, 1600).kind == "photo" and read(words_page(12), 1200, 1600).kind == "text", "a photo-shaped picture needs more words to count as a screenshot")

	# --- into the log: a run --------------------------------------------------------------------
	var shots = {"images/run.jpg": shot(strava_run()), "images/scale.png": shot(scale()), "images/ride.jpg": shot(strava_ride()),
		"images/walk.jpg": shot(strava_walk())}
	var r1 = p("photo images/run.jpg", shots)
	var e1 = r1.entries[0] if r1.entries.size() == 1 else {"data": {}}
	ok(r1.entries.size() == 1 and r1.problems.is_empty() and e1.kind == "session" and e1.data.discipline == "run", "run picture -> one run", r1)
	ok(near(e1.data.get("distanceM"), 6469.6, 0.06) and e1.data.get("durationSec") == 2497 and near(e1.data.get("elevationM"), 34.14), "run: metres, seconds, metres up", e1.data)
	ok(e1.data.get("title") == "Morning Run" and e1.data.get("notes") == "Max elevation 1,240 ft · Steps 6,480", "run: title and note", e1.data)
	ok(e1.get("date") == TODAY and e1.get("date_note") == QuickLog.SHOT_TODAY and e1.data.date == TODAY, "run: 'Today' = the day it was first seen", e1)
	ok(e1.get("shots") == ["images/run.jpg"] and e1.get("extras") == ["Max elevation 1,240 ft", "Steps 6,480"], "run: remembers its picture", e1)
	ok(p("photo images/run.jpg", shots, {"distanceUnit": "mi"}).entries[0].summary == "Morning Run: Run 4.02 mi · 41:37 · 112 ft up", "run: summary in miles", p("photo images/run.jpg", shots, {"distanceUnit": "mi"}).entries[0].summary)
	ok(e1.get("summary") == "Morning Run: Run 6.47 km · 41:37 · 34 m up", "run: summary in km", e1.get("summary"))

	# --- into the log: dates ----------------------------------------------------------------------
	var old = {"images/run.jpg": shot(strava_run(), "2026-11-10")}
	ok(p("photo images/run.jpg", old).entries[0].date == "2026-11-10", "'Today' on a picture first seen Nov 10 stays Nov 10", p("photo images/run.jpg", old).entries[0])
	var yest = shot(strava_run(), "2026-11-10")
	yest.rel = "yesterday"
	ok(p("photo images/run.jpg", {"images/run.jpg": yest}).entries[0].date == "2026-11-09" and p("photo images/run.jpg", {"images/run.jpg": yest}).entries[0].date_note == QuickLog.SHOT_YESTERDAY, "'Yesterday' counts back from the day it was seen")
	var under = p("nov 12\nphoto images/run.jpg", old).entries[0]
	ok(under.date == "2026-11-12" and under.date_note == "", "a date line above the picture wins over 'Today'", under)
	var rd = p("photo images/ride.jpg", shots).entries[0]
	ok(rd.date == "2026-11-14" and rd.date_note == "" and rd.data.discipline == "ride" and rd.warnings.is_empty(), "a date printed on the picture is used", rd)
	var rd2 = p("nov 12\nphoto images/ride.jpg", shots).entries[0]
	ok(rd2.date == "2026-11-14" and rd2.warnings.size() == 1 and str(rd2.warnings[0]).contains("Nov 14"), "printed date beats the note's line, with a warning", rd2)
	var future = shot(strava_ride())
	future.year = 2027
	ok(p("photo images/ride.jpg", {"images/ride.jpg": future}).entries[0].date == TODAY, "a printed date in the future is not believed")
	var nodate = shot(strava_run(), "2026-11-11")
	nodate.rel = ""
	ok(p("photo images/run.jpg", {"images/run.jpg": nodate}).entries[0].date == "2026-11-11" and p("photo images/run.jpg", {"images/run.jpg": nodate}).entries[0].date_note == QuickLog.SHOT_NO_DATE, "no date anywhere: the day it was first seen")
	var late = shot(strava_run(), "2027-01-01")
	ok(p("photo images/run.jpg", {"images/run.jpg": late}).entries[0].date == TODAY, "a first-seen day in the future falls back to today")

	# --- into the log: keys ---------------------------------------------------------------------------
	var k1 = p("photo images/run.jpg", shots).entries[0].key
	var k2 = QuickLog.parse("photo images/run.jpg", opts(shots, {"today": "2026-11-20"})).entries[0].key
	var k3 = p("photo images/renamed.jpg", {"images/renamed.jpg": shot(strava_run())}).entries[0].key
	ok(k1 == k2 and k1 == k3, "the key is what the picture says: same on any day, under any file name", [k1, k2, k3])
	var kr = p("photo images/ride.jpg", shots).entries[0].key
	var other_run = strava_run()
	other_run[9] = line("5.50 mi", 184, 812, 128, 30)
	var ko = p("photo images/run2.jpg", {"images/run2.jpg": shot(other_run)}).entries[0].key
	ok(QuickLog.key_prefix(k1) != QuickLog.key_prefix(ko) and QuickLog.key_prefix(k1) != QuickLog.key_prefix(kr), "another picture is another entry, never an edit of this one", [k1, ko, kr])
	var sp = PhoneInbox.split_entries(p("photo images/run2.jpg", {"images/run2.jpg": shot(other_run)}).entries, {k1: 1})
	ok(sp.fresh.size() == 1 and not sp.fresh[0].has("replaces_key") and not bool(sp.fresh[0].get("skip", false)), "a new run picture after an imported one is new", sp.fresh)
	var again = PhoneInbox.split_entries(p("photo images/run.jpg", shots).entries, {k1: 1})
	ok(again.fresh.is_empty() and again.already == 1, "an imported picture is not offered again", again)
	var twice = p("photo images/a.jpg\nphoto images/b.jpg", {"images/a.jpg": shot(strava_run(), TODAY, "same"), "images/b.jpg": shot(strava_run(), TODAY, "same")})
	ok(twice.entries.size() == 1, "the same picture pasted twice is one run", twice.entries.size())

	# --- into the log: a weigh-in ------------------------------------------------------------------------
	var b1 = p("photo images/scale.png", shots)
	var be = b1.entries[0] if b1.entries.size() == 1 else {"data": {}}
	ok(b1.entries.size() == 1 and be.kind == "body" and near(be.data.get("weightKg"), 81.83) and near(be.data.get("bodyFatPct"), 17.2), "scale picture -> weight in kg and body fat", b1)
	ok(str(be.data.get("note", "")).begins_with("Muscle 77.1% · Skeletal muscle 47.0%") and not be.data.has("photoRefs"), "scale: the rest is the note, and it is not a progress photo", be.data)
	ok(be.get("summary") == "Weight 81.8 kg · body fat 17.2%" and be.get("shots") == ["images/scale.png"] and be.get("date") == TODAY, "scale: summary, picture, day", be)
	var both = p("photo images/me.jpg\nphoto images/scale.png\nphoto images/side.jpg", shots)
	ok(both.entries.size() == 1 and both.entries[0].data.get("photoRefs") == ["images/me.jpg", "images/side.jpg"] and both.entries[0].data.has("weightKg"), "photos and a weigh-in on one day share the check-in", both)
	var typed = p("weight 82\nphoto images/scale.png", shots)
	ok(typed.entries.size() == 1 and near(typed.entries[0].data.weightKg, 81.83) and typed.entries[0].warnings.size() == 1, "a typed weight and a picture: the last wins, with a warning", typed)
	var dated = p("nov 10\nweight 83\nphoto images/rows.png", {"images/rows.png": shot(scale_rows())})
	ok(dated.entries.size() == 2 and dated.entries[0].date == "2026-11-10" and near(dated.entries[0].data.weightKg, 83.0) and dated.entries[1].date == "2026-11-12" and near(dated.entries[1].data.weightKg, 82.4), "a weigh-in dated by its picture is its own check-in", dated)
	var lb = p("photo images/rows.png", {"images/rows.png": shot(scale_rows())}, {"weightUnit": "lb"})
	ok(near(lb.entries[0].data.weightKg, 82.4) and lb.entries[0].summary == "Weight 181.7 lb · body fat 18.5%", "kg on the picture stays kg whatever the player's unit", lb.entries[0])
	var kb1 = p("photo images/scale.png", shots).entries[0].key
	var other_scale = scale()
	other_scale[3] = line("179.8", 49, 361, 261, 92)
	var kb2 = p("photo images/s2.png", {"images/s2.png": shot(other_scale)}).entries[0].key
	ok(QuickLog.key_prefix(kb1) != QuickLog.key_prefix(kb2), "another weigh-in picture is another check-in", [kb1, kb2])
	var heavy = shot(scale())
	heavy.weight = 900.0
	var hv = p("photo images/s.png", {"images/s.png": heavy})
	ok(hv.entries.is_empty() and hv.problems.size() == 1 and hv.problems[0].get("picture") == "images/s.png", "a weight that cannot be right is a problem, not an entry", hv)
	var al = [line("Weigh-in", 300, 141, 120, 26), line("TODAY 6:50 AM SCALE X PRO", 36, 240, 244, 12), line("180.4", 45, 293, 205, 61), line("Body fat", 60, 556, 71, 18), line("17.2", 61, 594, 55, 21)]
	ok(near(p("photo images/s.png", {"images/s.png": shot(al)}, {"weightUnit": "lb"}).entries[0].data.weightKg, 81.83) and near(p("photo images/s.png", {"images/s.png": shot(al)}).entries[0].data.weightKg, 180.4), "a weight printed without a unit is in the player's unit")

	# --- into the log: everything else ----------------------------------------------------------------------
	var w = p("photo images/walk.jpg", shots)
	ok(w.entries.is_empty() and w.problems.size() == 1 and w.problems[0].get("picture") == "images/walk.jpg" and str(w.problems[0].why).contains("a walk"), "a walk is reported with its picture", w)
	var ph = p("photo images/me.jpg", {"images/me.jpg": shot([line("NIKE", 300, 900, 120, 40)])})
	ok(ph.entries.size() == 1 and ph.entries[0].kind == "body" and ph.entries[0].data.get("photoRefs") == ["images/me.jpg"] and not ph.entries[0].has("shots"), "a picture with no words is a progress photo, as before", ph)
	var unk = p("photo images/me.jpg", {})
	ok(unk.entries.size() == 1 and unk.entries[0].data.get("photoRefs") == ["images/me.jpg"], "a picture nobody read is a progress photo, as before", unk)
	var mixed = p("nov 14\nbench 3x5 @ 80\nphoto images/run.jpg\nsquat 3x5 @ 100\nnote: felt strong", shots)
	ok(mixed.entries.size() == 2 and mixed.problems.is_empty() and mixed.entries[0].data.discipline == "lift" and mixed.entries[0].data.exercises.size() == 2 and mixed.entries[1].data.discipline == "run" and mixed.entries[1].date == "2026-11-14", "a picture between typed lines does not split the lifting", mixed)
	var titled = p("title: Tempo day\nphoto images/run.jpg", shots)
	ok(titled.entries.size() == 1 and titled.entries[0].data.get("title") == "Tempo day", "a typed title wins over the picture's", titled)
	var mi = p("photo images/run.jpg\nphoto images/ride.jpg\nphoto images/scale.png\nphoto images/walk.jpg", shots, {"distanceUnit": "mi", "weightUnit": "lb"})
	ok(mi.entries.size() == 3 and mi.problems.size() == 1, "four pictures: a run, a ride, a weigh-in and one left out", [mi.entries.size(), mi.problems.size()])

	print("SHOTS: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
