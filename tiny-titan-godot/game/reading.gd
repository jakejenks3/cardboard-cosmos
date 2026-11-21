class_name Reading
extends RefCounted
## Reading: pages read per day (added after the port).
##
## Not a workout: it has no session, hits no boss and drops no loot. A page is
## worth a little hero XP (so reading levels the hero and pays coins), reading
## has a level of its own that grows with the pages, and days in a row make a
## streak. Like everything else it is derived from the log, never stored.
##
## The log is `saved.reading` = [{id, date, pages, createdAt, inbox?}], ONE
## entry per day: adding pages on the same day raises that day's number. Each
## entry is a step of the replay (Derive._apply_reading), placed by its
## createdAt. `inbox` is {phone-note entry key: pages it brought}: when a
## reading line of the note is edited after it was imported, the day changes
## by the difference instead of counting the line twice.
##
## `state.reading` is made by the first entry (a log without reading has no
## such key, which keeps the parity tests as they are):
##   {pages, days (days with any reading), xp (hero XP paid),
##    byDate: {date: pages}, xpByDate: {date: XP paid for that day},
##    bestDay (most pages in a day), bestDayDate, firstDate, lastDate,
##    streak (days in a row up to today or yesterday), bestStreak,
##    bothDays (days with reading AND a workout),
##    level: {level, into, toNext, total, progress} (in pages)}

## Hero XP per page, for the first DAILY_XP_PAGES pages of a day. A longer day
## still counts every page (totals, level, records); it just pays no more XP,
## so a typo cannot move the hero ten levels.
const XP_PER_PAGE = 2
const DAILY_XP_PAGES = 100
## Pages a day the ring on the Hero tab fills to, unless settings.readingGoal says otherwise.
const DEFAULT_GOAL = 10
const MAX_PAGES_A_DAY = 2000
const MAX_LEVEL = 99


## Pages needed to finish a reading level: 30 for the first, ten more each time.
static func pages_for_level(level) -> int:
	return 20 + 10 * int(level)


## Level info for a page count: {level, into, toNext, total, progress}.
static func level(pages) -> Dictionary:
	var lv: int = 1
	var rem: int = maxi(0, int(pages))
	while lv < MAX_LEVEL and rem >= pages_for_level(lv):
		rem -= pages_for_level(lv)
		lv += 1
	var to_next: int = pages_for_level(lv)
	return {"level": lv, "into": rem, "toNext": to_next, "total": int(pages), "progress": 1.0 if lv >= MAX_LEVEL else float(rem) / float(to_next)}


## Hero XP a day's pages are worth.
static func day_xp(pages) -> int:
	return XP_PER_PAGE * clampi(int(pages), 0, DAILY_XP_PAGES)


static func clamp_pages(pages) -> int:
	return clampi(int(pages), 0, MAX_PAGES_A_DAY)


static func goal(settings) -> int:
	var g = settings.get("readingGoal") if settings is Dictionary else null
	if (g is int or g is float) and int(g) > 0:
		return clampi(int(g), 1, 500)
	return DEFAULT_GOAL


static func _blank() -> Dictionary:
	return {"pages": 0, "days": 0, "xp": 0, "byDate": {}, "xpByDate": {}, "bestDay": 0, "bestDayDate": null,
		"firstDate": null, "lastDate": null, "streak": 0, "bestStreak": 0, "bothDays": 0, "level": level(0)}


## Count one day's entry into `s.reading`. Returns the hero XP it pays.
## `trained` says whether a workout is already logged on that day.
static func record(s: Dictionary, entry: Dictionary, trained: bool) -> int:
	var pages: int = clamp_pages(entry.get("pages", 0))
	var date: String = str(entry.get("date", ""))
	if pages <= 0 or date == "":
		return 0
	if not (s.get("reading") is Dictionary):
		s["reading"] = _blank()
	var r: Dictionary = s.reading
	var before: int = int(r.byDate.get(date, 0))
	var now: int = clamp_pages(before + pages)
	r.byDate[date] = now
	r.pages += now - before
	if before == 0:
		r.days += 1
		if trained:
			r.bothDays += 1
	if r.firstDate == null or date < str(r.firstDate):
		r.firstDate = date
	if r.lastDate == null or date > str(r.lastDate):
		r.lastDate = date
	if now > int(r.bestDay):
		r.bestDay = now
		r.bestDayDate = date
	var paid: int = day_xp(now) - int(r.xpByDate.get(date, 0))
	if paid > 0:
		r.xpByDate[date] = int(r.xpByDate.get(date, 0)) + paid
		r.xp += paid
	r.level = level(r.pages)
	r.bestStreak = maxi(int(r.bestStreak), _run_ending(r.byDate, date))
	return maxi(0, paid)


## A workout was logged on `date`, the first one that day: if the day has
## reading too it is a "both" day. (Called by Derive for every session.)
static func note_trained(s: Dictionary, date: String) -> void:
	var r = s.get("reading")
	if r is Dictionary and int(r.byDate.get(date, 0)) > 0:
		r.bothDays += 1


# Days in a row with reading, ending on `date` (which has reading).
static func _run_ending(by_date: Dictionary, date: String) -> int:
	var n: int = 0
	var d: String = date
	while int(by_date.get(d, 0)) > 0 and n < 5000:
		n += 1
		d = Dates.add_days(d, -1)
	# The run may also continue forward when an older day is filled in.
	var f: String = Dates.add_days(date, 1)
	while int(by_date.get(f, 0)) > 0 and n < 5000:
		n += 1
		f = Dates.add_days(f, 1)
	return n


## Work out the current streak once the replay is done: days in a row ending
## today, or yesterday when today has no pages yet (the day is not over).
static func settle(s: Dictionary, today: String) -> void:
	var r = s.get("reading")
	if not (r is Dictionary):
		return
	var d: String = today
	if int(r.byDate.get(d, 0)) <= 0:
		d = Dates.add_days(today, -1)
	var n: int = 0
	while int(r.byDate.get(d, 0)) > 0 and n < 5000:
		n += 1
		d = Dates.add_days(d, -1)
	r.streak = n
	r.bestStreak = maxi(int(r.bestStreak), n)


# ---------------------------------------------------------------------------
# Reading the state (safe on a state without reading)
# ---------------------------------------------------------------------------

static func of(s: Dictionary):
	var r = s.get("reading")
	return r if r is Dictionary else null


static func pages(s: Dictionary) -> int:
	var r = of(s)
	return int(r.pages) if r != null else 0


static func pages_on(s: Dictionary, date: String) -> int:
	var r = of(s)
	return int(r.byDate.get(date, 0)) if r != null else 0


static func days(s: Dictionary) -> int:
	var r = of(s)
	return int(r.days) if r != null else 0


static func streak(s: Dictionary) -> int:
	var r = of(s)
	return int(r.streak) if r != null else 0


static func best_streak(s: Dictionary) -> int:
	var r = of(s)
	return int(r.bestStreak) if r != null else 0


static func best_day(s: Dictionary) -> int:
	var r = of(s)
	return int(r.bestDay) if r != null else 0


static func both_days(s: Dictionary) -> int:
	var r = of(s)
	return int(r.bothDays) if r != null else 0


static func level_of(s: Dictionary) -> Dictionary:
	var r = of(s)
	return r.level if r != null else level(0)


## Pages read from `from` to `to` (date keys, inclusive).
static func pages_between(s: Dictionary, from: String, to: String) -> int:
	var r = of(s)
	if r == null:
		return 0
	var n: int = 0
	for d in r.byDate:
		if str(d) >= from and str(d) <= to:
			n += int(r.byDate[d])
	return n


## Books on the shelf: one for every BOOK_PAGES pages read.
const BOOK_PAGES = 100


static func books(s: Dictionary) -> int:
	return int(floor(float(pages(s)) / float(BOOK_PAGES)))


# ---------------------------------------------------------------------------
# The log (saved.reading)
# ---------------------------------------------------------------------------

## The entry of a day in a reading log, or null.
static func entry_on(log: Array, date: String):
	for e in log:
		if e is Dictionary and str(e.get("date", "")) == date:
			return e
	return null


## A copy of `log` with the pages of `date` set to `pages` (0 removes the day).
## `uid` and `now_ms` are used when the day is new. `inbox` (a Dictionary, or
## null to leave it as it is) replaces the day's phone-note record.
static func with_day(log: Array, date: String, pages, uid: String, now_ms: int, inbox = null) -> Array:
	var out: Array = []
	var want: int = clamp_pages(pages)
	var done: bool = false
	for e in log:
		if e is Dictionary and str(e.get("date", "")) == date:
			if not done and want > 0:
				var c: Dictionary = e.duplicate(true)
				c["pages"] = want
				if inbox is Dictionary:
					c["inbox"] = inbox
				out.append(c)
			done = true
		else:
			out.append(e)
	if not done and want > 0:
		var fresh: Dictionary = {"id": uid, "date": date, "pages": want, "createdAt": now_ms}
		if inbox is Dictionary:
			fresh["inbox"] = inbox
		out.append(fresh)
	return out


## The day of the log that a phone-note entry (by its key) was imported into, or null.
static func entry_with_key(log: Array, key: String):
	for e in log:
		if e is Dictionary and e.get("inbox") is Dictionary and e.inbox.has(key):
			return e
	return null


## Keep what is a reading entry in a parsed save (one per day, the last one wins).
static func parse_log(raw) -> Array:
	var by_date: Dictionary = {}
	var order: Array = []
	if raw is Array:
		for e in raw:
			if not (e is Dictionary) or not (e.get("date") is String):
				continue
			var p = e.get("pages")
			if not (p is int or p is float) or int(p) <= 0:
				continue
			var date: String = e.date
			if not by_date.has(date):
				order.append(date)
			var created = e.get("createdAt")
			by_date[date] = {"id": str(e.get("id", "r_" + date)), "date": date, "pages": clamp_pages(p),
				"createdAt": int(created) if (created is int or created is float) else 0}
			var from_note = e.get("inbox")
			if from_note is Dictionary and not from_note.is_empty():
				var kept: Dictionary = {}
				for k in from_note:
					if from_note[k] is int or from_note[k] is float:
						kept[str(k)] = int(from_note[k])
				by_date[date]["inbox"] = kept
	var out: Array = []
	for d in order:
		out.append(by_date[d])
	return out
