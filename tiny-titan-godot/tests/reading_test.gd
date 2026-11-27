extends SceneTree
## Reading (game/reading.gd): pages per day, the XP they pay, the level, the
## streak, the trophies and what they unlock, and that a log without reading
## is untouched.
##
##   godot --headless --path . --script res://tests/reading_test.gd

var passed = 0
var failed = 0


func ok(cond: bool, what: String, extra = null) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL ", what, "" if extra == null else "  -> " + str(extra))


func derive(reading: Array, sessions: Array = [], today: String = "2026-03-20") -> Dictionary:
	return Derive.derive({"sessions": sessions, "claims": [], "body": [], "purchases": [], "reading": reading, "weeklyGoal": 3, "today": today})


func day(date: String, pages: int, t: int = 0) -> Dictionary:
	return {"id": "r_" + date, "date": date, "pages": pages, "createdAt": t if t != 0 else int(date.replace("-", "")) * 100}


func run_session(date: String, t: int) -> Dictionary:
	return {"id": "s_" + date, "discipline": "run", "date": date, "createdAt": t, "source": "manual", "distanceM": 5000, "elevationM": 20, "durationSec": 1700}


func _init() -> void:
	# --- a log without reading has no reading key at all ---------------------------
	var none = derive([])
	ok(not none.has("reading"), "no reading logged: the state has no reading key")
	ok(Reading.pages(none) == 0 and Reading.streak(none) == 0 and Reading.books(none) == 0 and int(Reading.level_of(none).level) == 1, "the readers are safe on such a state")
	ok(not none.coins.by.has("reading"), "and the coins have no reading line")

	# --- one day ----------------------------------------------------------------------
	var one = derive([day("2026-03-20", 12)])
	ok(Reading.pages(one) == 12 and Reading.days(one) == 1 and Reading.pages_on(one, "2026-03-20") == 12, "12 pages on one day")
	ok(int(one.reading.xp) == 24 and int(one.xp.hero) == 24 + 50, "2 XP a page for the hero, plus the First Chapter trophy", [one.reading.xp, one.xp.hero])
	ok(one.achievements.has("read_first") and not one.achievements.has("read_100"), "First Chapter is earned")
	ok(int(one.xp.lift) == 0 and int(one.totals.sessions) == 0 and one.weekCounts.is_empty() and int(one.streak.current) == 0, "reading is not a session: no discipline XP, no weekly streak")
	ok(int(one.campaign.totalDamage) == 0 and one.items.size() == none.items.size(), "it hits no boss and drops no loot")
	ok(int(one.coins.by.reading) == Wallet.xp_coins(24) and int(one.coins.earned) == Wallet.xp_coins(24) + 10, "it pays coins (and the trophy pays its own)", one.coins)
	ok(Reading.streak(one) == 1 and Reading.best_streak(one) == 1, "a streak of one day")
	ok(int(one.xpByDate.get("2026-03-20", 0)) == 74, "the day's XP is on the calendar")

	# --- the daily XP cap: every page counts, only the first 100 pay ---------------------
	var big = derive([day("2026-03-20", 250)])
	ok(Reading.pages(big) == 250 and int(big.reading.xp) == 200 and Reading.best_day(big) == 250, "250 pages in a day: all counted, 200 XP paid", big.reading.xp)
	ok(big.achievements.has("read_day_50") and big.achievements.has("read_day_100") and big.achievements.has("read_100"), "the big-day trophies")
	ok(Reading.clamp_pages(999999) == Reading.MAX_PAGES_A_DAY and Reading.clamp_pages(-4) == 0, "a typo is capped")

	# --- the level curve -------------------------------------------------------------------
	ok(int(Reading.level(0).level) == 1 and int(Reading.level(29).level) == 1 and int(Reading.level(30).level) == 2, "level 2 at 30 pages")
	ok(int(Reading.level(69).level) == 2 and int(Reading.level(70).level) == 3, "level 3 at 70 pages")
	var l = Reading.level(100)
	ok(int(l.level) == 3 and int(l.into) == 30 and int(l.toNext) == 50 and absf(float(l.progress) - 0.6) < 0.001, "100 pages: level 3, 30 of 50 pages in", l)
	ok(int(Reading.level(630).level) == 10, "level 10 at 630 pages", Reading.level(630))

	# --- streaks ----------------------------------------------------------------------------
	var days5 = []
	for i in range(5):
		days5.append(day(Dates.add_days("2026-03-16", i), 10))
	var st5 = derive(days5, [], "2026-03-20")
	ok(Reading.streak(st5) == 5 and Reading.best_streak(st5) == 5, "five days in a row up to today", [Reading.streak(st5), Reading.best_streak(st5)])
	ok(st5.achievements.has("read_streak_3") and not st5.achievements.has("read_streak_7"), "Three in a Row")
	var next_day = derive(days5, [], "2026-03-21")
	ok(Reading.streak(next_day) == 5, "the next morning the streak still stands (today is not over)")
	var missed = derive(days5, [], "2026-03-22")
	ok(Reading.streak(missed) == 0 and Reading.best_streak(missed) == 5, "a missed day ends it; the best stays")
	var gap = derive([day("2026-03-10", 5), day("2026-03-11", 5), day("2026-03-14", 5), day("2026-03-15", 5), day("2026-03-16", 5)], [], "2026-03-16")
	ok(Reading.streak(gap) == 3 and Reading.best_streak(gap) == 3, "a gap splits the runs", [Reading.streak(gap), Reading.best_streak(gap)])
	# A day filled in later joins two runs.
	var joined = derive([day("2026-03-10", 5), day("2026-03-11", 5), day("2026-03-13", 5), day("2026-03-14", 5), day("2026-03-12", 5, 2026031500)], [], "2026-03-14")
	ok(Reading.best_streak(joined) == 5 and Reading.streak(joined) == 5, "filling in a missed day joins the runs", [Reading.best_streak(joined), Reading.streak(joined)])

	# --- reading and training on the same day, in either order ---------------------------------
	var both_a = derive([day("2026-03-20", 10, 2000)], [run_session("2026-03-20", 1000)])
	var both_b = derive([day("2026-03-20", 10, 1000)], [run_session("2026-03-20", 2000)])
	ok(Reading.both_days(both_a) == 1 and Reading.both_days(both_b) == 1, "a day with both counts once, whichever came first", [Reading.both_days(both_a), Reading.both_days(both_b)])
	ok(both_a.achievements.has("read_both_1") and both_b.achievements.has("read_both_1"), "Brains and Brawn")
	var apart = derive([day("2026-03-19", 10)], [run_session("2026-03-20", 5000)])
	ok(Reading.both_days(apart) == 0, "different days do not")
	ok(int(both_a.totals.sessions) == 1 and int(both_a.xp.run) > 0 and int(both_a.xp.run) == int(derive([], [run_session("2026-03-20", 1000)]).xp.run), "the run is worth what it is worth without the reading")

	# --- what the pages unlock ---------------------------------------------------------------
	var lots = []
	for i in range(40):
		lots.append(day(Dates.add_days("2026-01-01", i), 30))
	var far = derive(lots, [], "2026-02-09")
	ok(Reading.pages(far) == 1200 and Reading.books(far) == 12, "1,200 pages: twelve books on the shelf")
	ok(far.items.has("read_glasses") and far.items.has("read_satchel") and str(far.items.read_glasses.how) == "unlock", "the reading glasses (250) and the satchel (1,000)")
	ok(far.pets.has("owl"), "Page the Owl joins at 300 pages")
	ok(far.achievements.has("read_1000") and far.achievements.has("read_streak_30") and not far.achievements.has("read_2500"), "Well Read and Thirty Nights")
	ok(Pets.by_id("owl") != null and Art.pet_frame_count("owl") == 2 and Art.pet_pix("owl", 0).w > 4, "the owl has a sprite")
	ok(Items.by_id("read_glasses").slot == "face" and Art.item_icon_pix("read_glasses").w > 3, "the glasses have a picture")
	var n_read = 0
	for a in Achievements.all():
		if str(a.id).begins_with("read_"):
			n_read += 1
			ok(str(a.group) == "read" and Icons.for_emoji(a.icon) != "", "trophy %s is in the reading group" % a.id)
	ok(n_read == 16, "sixteen reading trophies", n_read)

	# --- the log helpers -----------------------------------------------------------------------
	var log = []
	log = Reading.with_day(log, "2026-03-20", 10, "r_a", 111)
	ok(log.size() == 1 and int(log[0].pages) == 10 and str(log[0].id) == "r_a" and int(log[0].createdAt) == 111, "a new day is one entry")
	log = Reading.with_day(log, "2026-03-20", 25, "r_b", 222)
	ok(log.size() == 1 and int(log[0].pages) == 25 and str(log[0].id) == "r_a" and int(log[0].createdAt) == 111, "more pages the same day change that entry")
	log = Reading.with_day(log, "2026-03-21", 5, "r_c", 333)
	ok(log.size() == 2 and Reading.entry_on(log, "2026-03-21").id == "r_c", "another day is another entry")
	log = Reading.with_day(log, "2026-03-20", 0, "r_d", 444)
	ok(log.size() == 1 and Reading.entry_on(log, "2026-03-20") == null, "0 pages takes the day out")
	var parsed = Reading.parse_log([{"date": "2026-03-20", "pages": 5.0, "id": "x", "createdAt": 9.0}, {"date": "2026-03-20", "pages": 7}, {"pages": 3}, "junk", {"date": "2026-03-21", "pages": 0}])
	ok(parsed.size() == 1 and int(parsed[0].pages) == 7 and parsed[0].pages is int, "a loaded log keeps one entry per day and drops the junk", parsed)
	ok(Reading.parse_log(null).is_empty(), "a save without reading loads as an empty log")
	ok(Reading.goal({}) == Reading.DEFAULT_GOAL and Reading.goal({"readingGoal": 25}) == 25 and Reading.goal({"readingGoal": -3}) == Reading.DEFAULT_GOAL, "the daily goal")
	ok(Reading.pages_between(far, "2026-01-01", "2026-01-07") == 210, "pages in a week")

	print("READING: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
