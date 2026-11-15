extends SceneTree
## Unit tests for game/quick_log.gd (the phone-inbox parser) and the share-link rewriting.
##   godot --headless --path . --script res://tests/quick_log_test.gd
## Prints QUICKLOG: X/Y passed and exits with 1 when anything fails.

const TODAY = "2026-11-15"  # a Sunday

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func opts(extra: Dictionary = {}) -> Dictionary:
	var o = {"today": TODAY, "weightUnit": "kg", "distanceUnit": "km", "exercises": Summary.DEFAULT_EXERCISES}
	o.merge(extra, true)
	return o


func p(text: String, extra: Dictionary = {}) -> Dictionary:
	return QuickLog.parse(text, opts(extra))


## The single entry of `text` (or {} when there is not exactly one).
func one(text: String, extra: Dictionary = {}) -> Dictionary:
	var r = p(text, extra)
	if r.entries.size() != 1:
		print("  (%d entries, problems %s for %s)" % [r.entries.size(), str(r.problems), text])
		return {}
	return r.entries[0]


## [[reps, kg], ...] of the first exercise of a lift entry.
func sets_of(e: Dictionary, idx: int = 0) -> Array:
	if e.is_empty() or e.data.get("exercises") == null or e.data.exercises.size() <= idx:
		return []
	var out = []
	for s in e.data.exercises[idx].sets:
		out.append([int(s.reps), snappedf(float(s.weightKg), 0.01)])
	return out


func ex_name(text: String) -> String:
	var e = one(text)
	return "" if e.is_empty() else str(e.data.exercises[0].name)


func date_of(text: String) -> String:
	var r = p(text + "\nbench 3x5 @ 80")
	return "" if r.entries.is_empty() else str(r.entries[0].date)


func _init() -> void:
	# --- normalising -------------------------------------------------------------
	ok(sets_of(one("﻿Bench 3×5 @ 80\r\n")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "BOM, CRLF, times sign", sets_of(one("﻿Bench 3×5 @ 80\r\n")))
	ok(sets_of(one("BENCH 3X5 @ 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "upper case, X, nbsp")
	ok(sets_of(one("bench 3*5 @ 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "* as x")
	ok(sets_of(one("- bench 3x5 @ 80")).size() == 3, "list bullet")
	ok(p("# warmup\n// comment\n\n").entries.is_empty() and p("# warmup\n// c").problems.is_empty(), "comments are ignored")

	# --- lifting -------------------------------------------------------------------
	ok(sets_of(one("squat 5,5,4 @ 100")) == [[5, 100.0], [5, 100.0], [4, 100.0]], "reps list @ weight")
	ok(sets_of(one("ohp 5 @ 50, 5 @ 52.5, 3 @ 55")) == [[5, 50.0], [5, 52.5], [3, 55.0]], "per-set weights", sets_of(one("ohp 5 @ 50, 5 @ 52.5, 3 @ 55")))
	ok(sets_of(one("dl 1x3 @ 140kg")) == [[3, 140.0]], "dl 1x3 @ 140kg")
	ok(sets_of(one("pull-up 3x8")) == [[8, 0.0], [8, 0.0], [8, 0.0]], "bodyweight AxB")
	ok(sets_of(one("pull-up 8,8,6")) == [[8, 0.0], [8, 0.0], [6, 0.0]], "bodyweight list")
	ok(sets_of(one("dip 3x8 @ +10")) == [[8, 10.0], [8, 10.0], [8, 10.0]], "added weight +10")
	ok(sets_of(one("squat 80kg x 5")) == [[5, 80.0]], "weight first x reps")
	ok(sets_of(one("squat 80kg x5 x3")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "weight first x reps x sets")
	ok(sets_of(one("bench 3x5 @ 82,5")) == [[5, 82.5], [5, 82.5], [5, 82.5]], "decimal comma after @")
	ok(sets_of(one("bench 3x5 at 80")) == [[5, 80.0], [5, 80.0], [5, 80.0]], "'at' instead of @")
	ok(sets_of(one("bench 3 x 5 @ 80 kg")).size() == 3, "spaces around x and unit")
	ok(sets_of(one("squat 3x5 100kg")) == [[5, 100.0], [5, 100.0], [5, 100.0]], "unit on a trailing weight")
	ok(sets_of(one("bench 3x5 @ 80", {"weightUnit": "lb"})) == [[5, 36.29], [5, 36.29], [5, 36.29]], "player unit lb")
	ok(sets_of(one("bench 3x5 @ 80kg", {"weightUnit": "lb"}))[0] == [5, 80.0], "explicit kg for lb player")
	ok(sets_of(one("bench 3x5 @ 185lbs"))[0] == [5, 83.91], "explicit lbs for kg player", sets_of(one("bench 3x5 @ 185lbs")))
	var heur = one("squat 5x80")
	ok(sets_of(heur) == [[5, 80.0]] and str(heur.warnings).contains("read as 5 reps at 80"), "bare AxB, B > 30 on a loaded lift", heur)
	var bw = one("squat 3x5")
	ok(sets_of(bw) == [[5, 0.0], [5, 0.0], [5, 0.0]] and str(bw.warnings).contains("no weight given"), "bare AxB, small B on a loaded lift")
	ok(one("pull-up 3x50").warnings.is_empty(), "bare AxB on a bodyweight exercise: no warning")
	ok(str(one("hammer curl 3x10", {"loaded": []}).warnings).contains("no weight given"), "built-in loaded word (curl)")
	ok(str(one("ring row 3x10").warnings).contains("no weight given") and str(one("muscle up 3x5", {"loaded": ["muscle up"]}).warnings).contains("no weight given"), "history makes an exercise loaded")
	var two = one("bench 3x5 @ 80\nsquat 5,5,4 @ 100\npull-up 3x8")
	ok(two.get("data", {}).get("exercises", []).size() == 3, "all lifting lines of a day = one session")
	ok(p("bench 3x5 @ 80\n---\nsquat 3x5 @ 100").entries.size() == 2 and p("bench 3x5 @ 80\nlift\nsquat 3x5 @ 100").entries.size() == 2, "--- or 'lift' starts a second session")
	ok(sets_of(one("bench 3x5 @ 80\nbench 1x3 @ 85")).size() == 4, "same exercise twice merges sets")
	ok(p("bench 3x5 @").problems.size() == 1 and p("bench @ 80").problems.size() == 1, "broken lifting lines are problems")

	# --- exercise names -------------------------------------------------------------
	ok(ex_name("bench 3x5 @ 80") == "Bench Press", "alias bench")
	ok(ex_name("ohp 3x5 @ 40") == "Overhead Press", "alias ohp")
	ok(ex_name("deads 1x5 @ 140") == "Deadlift" and ex_name("dl 1x5 @ 140") == "Deadlift", "alias dl / deads")
	ok(ex_name("squats 3x5 @ 100") == "Squat", "plural squats")
	ok(ex_name("pull ups 3x8") == "Pull-up" and ex_name("pullups 3x8") == "Pull-up", "pull ups / pullups")
	ok(ex_name("chins 3x8") == "Chin-up" and ex_name("rows 3x8 @ 60") == "Barbell Row" and ex_name("rdl 3x8 @ 80") == "Romanian Deadlift", "chins, rows, rdl")
	ok(ex_name("dips 3x8") == "Dip" and ex_name("pushups 3x20") == "Push-up" and ex_name("curls 3x10 @ 30") == "Bicep Curl", "dips, pushups, curls")
	ok(ex_name("Romanian deadlift 3x8 @ 80") == "Romanian Deadlift", "exact match, any case")
	ok(ex_name("incline 3x8 @ 60") == "Incline Bench Press", "unique prefix")
	ok(ex_name("zercher squat 3x5 @ 60") == "Zercher Squat", "new exercise in Title Case")
	ok(ex_name("bench: 3x5 @ 80") == "Bench Press", "colon after the name")
	ok(ex_name("my move 3x5 @ 60") == "My Move" and QuickLog.parse("my move 3x5 @ 60", {"today": TODAY, "exercises": ["My Move"]}).entries[0].data.exercises[0].name == "My Move", "custom known exercise")

	# --- climbing ---------------------------------------------------------------------
	var cl = one("v4 flash x2, v5 send, v6 attempt x3")
	ok(not cl.is_empty() and cl.data.climbs == [{"grade": 4, "result": "flash", "count": 2}, {"grade": 5, "result": "send", "count": 1}, {"grade": 6, "result": "attempt", "count": 3}], "climb list", cl.get("data"))
	ok(one("climb vb x3").data.climbs == [{"grade": -1, "result": "send", "count": 3}], "climb vb x3")
	ok(one("v3").data.climbs == [{"grade": 3, "result": "send", "count": 1}], "bare v3 = one send")
	ok(one("2x v4f").data.climbs == [{"grade": 4, "result": "flash", "count": 2}], "2x v4f")
	ok(one("boulder v5 att, v6 project, v2 fail").data.climbs.all(func(c): return c.result == "attempt"), "attempt words")
	ok(one("v4 flash x2\nv5 s\nv4 f 2x").data.climbs.size() == 2, "climb lines of a day = one session, same grade+result merge")
	var badc = p("v4 flash x2, v4 crimpy")
	ok(badc.entries.size() == 1 and badc.problems.size() == 1, "a bad climb item is a problem, the rest kept")
	ok(p("v18").problems.size() == 1, "V18 is out of range")

	# --- running / cycling ------------------------------------------------------------
	var run = one("run 5.2km 27:30 +80m")
	ok(not run.is_empty() and run.data.discipline == "run" and int(run.data.distanceM) == 5200 and int(run.data.durationSec) == 1650 and int(run.data.elevationM) == 80, "run 5.2km 27:30 +80m", run.get("data"))
	var ride = one("ride 40km 1h35")
	ok(ride.data.discipline == "ride" and int(ride.data.distanceM) == 40000 and int(ride.data.durationSec) == 5700, "ride 40km 1h35")
	ok(int(one("ran 5.2 km in 45 min").data.durationSec) == 2700 and int(one("jog 10k 1:02:30").data.durationSec) == 3750, "5.2 km, 45 min, 10k, 1:02:30")
	ok(int(one("run 3mi 30min").data.distanceM) == 4828 and int(one("run 3", {"distanceUnit": "mi"}).data.distanceM) == 4828, "miles, bare number in the player's unit")
	ok(int(one("bike 30 1h 30m").data.durationSec) == 5400 and int(one("cycle 30km 1.5h").data.durationSec) == 5400 and int(one("ride 20km 1h").data.durationSec) == 3600, "1h 30m, 1.5h, 1h")
	var track = one("run 400m 1:30")
	ok(not track.is_empty() and int(track.data.distanceM) == 400 and int(track.data.durationSec) == 90, "run 400m 1:30 is 400 metres, not 400 minutes", track.get("data"))
	ok(int(one("ride 5000m").data.distanceM) == 5000, "ride 5000m is a distance")
	var mm = one("run 8km 45m 120m")
	ok(int(mm.data.durationSec) == 2700 and int(mm.data.elevationM) == 120, "bare NNm: minutes first, then metres")
	ok(int(one("run 8km 40:00 80m elev").data.elevationM) == 80 and int(one("run 8km elev 80").data.elevationM) == 80, "80m elev / elev 80")
	ok(int(one("ride 40km 300 ft gain").data.elevationM) == 91 and int(one("run 5km +100", {"distanceUnit": "mi"}).data.elevationM) == 30, "feet of climbing")
	ok(int(one("run 5,2km 27:30").data.distanceM) == 5200, "decimal comma in a distance")
	ok(p("run 5km\nrun 3km").entries.size() == 2, "each run is its own session")
	ok(p("run fast").problems.size() == 1 and p("run fast").entries.is_empty(), "run without distance is a problem")

	# --- body ---------------------------------------------------------------------------
	var body = one("weight 82.4  bf 18")
	ok(body.kind == "body" and float(body.data.weightKg) == 82.4 and float(body.data.bodyFatPct) == 18.0, "weight + bf on one line")
	ok(is_equal_approx(float(one("weighed 181 lb").data.weightKg), 82.1), "weighed 181 lb", one("weighed 181 lb").get("data"))
	ok(float(one("bw 82,4").data.weightKg) == 82.4 and float(one("body fat 18.5%").data.bodyFatPct) == 18.5, "bw with decimal comma, body fat %")
	var b2 = one("weight 82.4\nbf 18.5")
	ok(b2.data.has("weightKg") and b2.data.has("bodyFatPct"), "one body entry per date from two lines")
	ok(is_equal_approx(float(one("weight 181", {"weightUnit": "lb"}).data.weightKg), 82.1), "weight in the player's lb")
	ok(p("weight banana").problems.size() == 1 and p("weight 900").problems.size() == 1, "bad weights are problems")

	# --- extras --------------------------------------------------------------------------
	var ex = one("title: Push day\nbench 3x5 @ 80\nnote: felt strong\nduration 70min")
	ok(ex.data.get("title") == "Push day" and ex.data.get("notes") == "felt strong" and int(ex.data.get("durationSec", 0)) == 4200, "title above, note and duration below", ex.get("data"))
	var r2 = p("bench 3x5 @ 80\nrun 5km\ntime 1h10")
	ok(int(r2.entries[1].data.get("durationSec", 0)) == 4200 and r2.entries[0].data.get("durationSec") == null, "duration attaches to the last session (the run)")
	ok(p("note: nothing here").problems.size() == 1, "an extra with no session is a problem")

	# --- dates ---------------------------------------------------------------------------
	ok(date_of("2026-11-14") == "2026-11-14" and date_of("nov 14") == "2026-11-14" and date_of("November 14:") == "2026-11-14", "iso, nov 14, November 14:")
	ok(date_of("14 nov") == "2026-11-14" and date_of("11/14") == "2026-11-14" and date_of("11/14/2026") == "2026-11-14", "14 nov, 11/14, 11/14/2026")
	ok(date_of("dec 20") == "2025-12-20" and date_of("12/20") == "2025-12-20", "future month/day = last year")
	ok(date_of("today") == TODAY and date_of("yesterday") == "2026-11-14", "today, yesterday")
	ok(date_of("sat") == "2026-11-14" and date_of("saturday") == "2026-11-14" and date_of("sun") == TODAY and date_of("mon") == "2026-11-09", "weekday names (on or before today)")
	ok(date_of("sat nov 7") == "2026-11-07", "weekday before an explicit date is decoration")
	var nd = p("bench 3x5 @ 80")
	ok(nd.entries[0].date == TODAY and nd.entries[0].date_note == QuickLog.NO_DATE_NOTE, "no date line = today with a note")
	ok(p("yesterday\nbench 3x5 @ 80").entries[0].date_note != "" and p("nov 14\nbench 3x5 @ 80").entries[0].date_note == "", "relative dates carry a note, explicit ones do not")
	var days = p("nov 13\nbench 3x5 @ 80\nnov 14\nbench 3x5 @ 82.5\nrun 5km")
	ok(days.entries.size() == 3 and days.entries[0].date == "2026-11-13" and days.entries[2].date == "2026-11-14", "entries take the date above them")
	ok(p("nov 14: v4 flash x2").entries[0].date == "2026-11-14", "date: entry on one line")
	ok(date_of("feb 30") == TODAY and p("feb 30").problems.size() == 1, "an impossible date is a problem")

	# --- problems ---------------------------------------------------------------------------
	var junk = p("hello there\nbench 3x5 @ 80\nfelt great today!!")
	ok(junk.entries.size() == 1 and junk.problems.size() == 2 and junk.problems[0].line == "hello there", "junk lines are kept as problems with their text", junk.problems)
	ok(junk.problems[0].why != "", "problems say why")

	# --- summaries ----------------------------------------------------------------------------
	ok(one("bench 3x5 @ 80").summary == "Bench Press 3×5 @ 80 kg", "lift summary", one("bench 3x5 @ 80").summary)
	ok(one("run 5.2km 27:30 +80m").summary == "Run 5.2 km · 27:30 · 80 m up", "run summary", one("run 5.2km 27:30 +80m").summary)
	ok(one("v4 flash x2, v5 send").summary == "V4 flash ×2 · V5 send", "climb summary")

	# --- the cheat sheet the app shows parses cleanly ---------------------------------------------
	var cs = p(QuickLog.CHEAT_SHEET)
	ok(cs.problems.is_empty() and cs.entries.size() == 5, "cheat sheet: 5 entries, no problems", [cs.entries.size(), cs.problems])

	# --- keys ---------------------------------------------------------------------------------
	var k1 = p("yesterday\nbench 3x5 @ 80\nrun 5km")
	var k2 = QuickLog.parse("yesterday\nbench 3x5 @ 80\nrun 5km", opts({"today": "2026-12-03"}))
	ok(k1.entries[0].key == k2.entries[0].key and k1.entries[1].key == k2.entries[1].key, "same text, different today: same keys")
	ok(k1.entries[0].key != k1.entries[1].key, "different entries: different keys")
	ok(p("Bench 3X5 @ 80").entries[0].key == p("bench 3x5 @ 80").entries[0].key, "keys ignore case and spacing")
	ok(p("nov 14\nrun 5km").entries[0].key != p("nov 15\nrun 5km").entries[0].key, "the date header is part of the key")
	ok(QuickLog.key_prefix(p("nov 14\nbench 3x5 @ 80").entries[0].key) == QuickLog.key_prefix(p("nov 14\nbench 3x5 @ 80\nsquat 3x5 @ 100").entries[0].key), "key prefix names kind + day")

	# --- CSV (Google Form responses) ---------------------------------------------------------------
	var csv = "Timestamp,What did you do?\n\"11/14/2026 18:32:10\",\"bench 3x5 @ 80\nsquat 5,5,4 @ 100\"\n2026-11-13 07:05,run 5km 25:00\n11/12/2026 20:00:00,\"v4 flash x2, v5 send\"\n"
	ok(QuickLog.looks_like_csv(csv) and not QuickLog.looks_like_csv("nov 14\nbench 3x5 @ 80"), "CSV detection")
	var cr = QuickLog.parse_any(csv, opts())
	ok(cr.entries.size() == 3 and cr.problems.is_empty(), "CSV rows -> entries", [cr.entries.size(), cr.problems])
	ok(cr.entries[0].date == "2026-11-14" and cr.entries[0].date_note == "" and cr.entries[0].data.exercises.size() == 2, "quoted multi-line cell with commas, dated by the timestamp")
	ok(cr.entries[1].date == "2026-11-13" and cr.entries[2].data.climbs.size() == 2, "ISO timestamp, quoted commas in a climb cell")
	var csv2 = csv + "\"11/15/2026 09:00:00\",bench 3x5 @ 80\n"
	var cr2 = QuickLog.parse_csv(csv2, opts())
	ok(cr2.entries[3].key != cr2.entries[0].key and cr2.entries[0].key == cr.entries[0].key, "CSV keys include the timestamp and are stable")
	ok(QuickLog.csv_rows("a,\"b \"\"q\"\" c\",d\r\ne,f") == [["a", "b \"q\" c", "d"], ["e", "f"]], "CSV quote escaping and CRLF")
	ok(QuickLog.timestamp_date("14.11.2026 18:32:10") == "2026-11-14" and QuickLog.timestamp_date("hello") == "", "dotted day-first timestamps")

	# --- share links -> raw text (app/inbox.gd, static) ---------------------------------------------
	ok(PhoneInbox.fetch_url("https://docs.google.com/document/d/AbC_123-x/edit?usp=sharing") == "https://docs.google.com/document/d/AbC_123-x/export?format=txt", "Google Doc link")
	ok(PhoneInbox.fetch_url("https://docs.google.com/spreadsheets/d/XyZ9/edit#gid=12345") == "https://docs.google.com/spreadsheets/d/XyZ9/export?format=csv&gid=12345", "Google Sheet link keeps gid")
	ok(PhoneInbox.fetch_url("https://docs.google.com/spreadsheets/d/XyZ9/edit?usp=sharing") == "https://docs.google.com/spreadsheets/d/XyZ9/export?format=csv", "Google Sheet link")
	ok(PhoneInbox.fetch_url("https://www.dropbox.com/s/abc/log.txt?dl=0") == "https://www.dropbox.com/s/abc/log.txt?dl=1", "Dropbox dl=0 -> dl=1")
	ok(PhoneInbox.fetch_url("https://gist.github.com/someone/0123abcd") == "https://gist.github.com/someone/0123abcd/raw", "gist page -> raw")
	ok(PhoneInbox.fetch_url(" https://example.com/notes.txt ") == "https://example.com/notes.txt", "other links unchanged")

	print("QUICKLOG: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
