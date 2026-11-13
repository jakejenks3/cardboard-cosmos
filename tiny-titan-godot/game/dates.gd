class_name Dates
extends RefCounted
## Local-date helpers (port of dates.ts). Dates are stored as YYYY-MM-DD in
## the user's local calendar; weeks start on Monday.
##
## The calendar maths is done on whole days since 1970-01-01 with integer
## arithmetic, so it does not depend on time zones or daylight saving (the
## TS works on local midnights and rounds, which gives the same calendar
## results).

const MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
# Indexed like JS `getDay()`: 0 = Sunday ... 6 = Saturday.
const WEEKDAYS_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const WEEKDAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]


static func pad2(n: int) -> String:
	return ("0" + str(n)) if n < 10 else str(n)


# Floor division for ints (GDScript `/` truncates towards zero).
static func _fdiv(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))


# Days since 1970-01-01 for a proleptic Gregorian date (month 1..12).
static func _days_from_civil(y: int, m: int, d: int) -> int:
	var yy: int = y - 1 if m <= 2 else y
	var era: int = _fdiv(yy, 400)
	var yoe: int = yy - era * 400
	var mp: int = m - 3 if m > 2 else m + 9
	var doy: int = _fdiv(153 * mp + 2, 5) + d - 1
	var doe: int = yoe * 365 + _fdiv(yoe, 4) - _fdiv(yoe, 100) + doy
	return era * 146097 + doe - 719468


# Inverse of `_days_from_civil`: [year, month, day].
static func _civil_from_days(days: int) -> Array:
	var z: int = days + 719468
	var era: int = _fdiv(z, 146097)
	var doe: int = z - era * 146097
	var yoe: int = _fdiv(doe - _fdiv(doe, 1460) + _fdiv(doe, 36524) - _fdiv(doe, 146096), 365)
	var doy: int = doe - (365 * yoe + _fdiv(yoe, 4) - _fdiv(yoe, 100))
	var mp: int = _fdiv(5 * doy + 2, 153)
	var d: int = doy - _fdiv(153 * mp + 2, 5) + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	var y: int = yoe + era * 400
	if m <= 2:
		y += 1
	return [y, m, d]


# Day number of a date key. Mirrors `new Date(y, (m || 1) - 1, d || 1)`:
# missing parts default to 1 and out-of-range months/days roll over.
static func _key_to_days(key: String) -> int:
	var parts = key.split("-")
	var y: int = parts[0].to_int() if parts.size() > 0 else 0
	var m: int = parts[1].to_int() if parts.size() > 1 else 0
	var d: int = parts[2].to_int() if parts.size() > 2 else 0
	if m == 0:
		m = 1
	if d == 0:
		d = 1
	if y >= 0 and y <= 99:
		# JS Date quirk: two-digit years mean 19xx.
		y += 1900
	var m0: int = m - 1
	y += _fdiv(m0, 12)
	m = posmod(m0, 12) + 1
	return _days_from_civil(y, m, 1) + (d - 1)


static func _days_to_key(days: int) -> String:
	var c: Array = _civil_from_days(days)
	return "%d-%s-%s" % [c[0], pad2(c[1]), pad2(c[2])]


# JS `getDay()` of a day number: 0 = Sunday ... 6 = Saturday.
static func _js_weekday(days: int) -> int:
	return posmod(days + 4, 7)


## Date key from a date Dictionary with `year`, `month` (1..12) and `day`
## (what `Time.get_date_dict_from_system()` / `parse_date_key()` return).
static func to_date_key(d: Dictionary) -> String:
	return "%d-%s-%s" % [int(d.year), pad2(int(d.month)), pad2(int(d.day))]


## Today's LOCAL date as a key. `now` may be a date Dictionary (see
## `to_date_key`); leave it out for the system date.
static func today_key(now = null) -> String:
	if now is Dictionary:
		return to_date_key(now)
	return Time.get_date_string_from_system()


## Calendar parts of a date key (the stand-in for the JS `Date`):
## {year, month (1..12), day, weekday (0 = Sunday ... 6 = Saturday),
##  days (whole days since 1970-01-01), unix (UTC seconds at midnight)}.
static func parse_date_key(key: String) -> Dictionary:
	var days: int = _key_to_days(key)
	var c: Array = _civil_from_days(days)
	return {"year": c[0], "month": c[1], "day": c[2], "weekday": _js_weekday(days), "days": days, "unix": days * 86400}


static func add_days(key: String, n) -> String:
	return _days_to_key(_key_to_days(key) + int(n))


## Whole days from `a` to `b` (positive when `b` is later).
static func days_between(a: String, b: String) -> int:
	return _key_to_days(b) - _key_to_days(a)


## Monday of the week containing `key`, as a date key.
static func week_key(key: String) -> String:
	var days: int = _key_to_days(key)
	var diff: int = (_js_weekday(days) + 6) % 7  # Mon=0 ... Sun=6
	return _days_to_key(days - diff)


static func add_weeks(wk: String, n) -> String:
	return add_days(wk, int(n) * 7)


## 0 = Monday ... 6 = Sunday
static func weekday_index(key: String) -> int:
	return (_js_weekday(_key_to_days(key)) + 6) % 7


## en-US text for a date key. `opts` mirrors `Intl.DateTimeFormatOptions`
## with the fields the app uses: "weekday": "short"|"long",
## "month": "short"|"long", "day": "numeric", "year": "numeric".
## Default {"month": "short", "day": "numeric"} -> "Mar 2".
##   {"weekday": "short", "month": "short", "day": "numeric"}  -> "Mon, Mar 2"
##   {"month": "short", "day": "numeric", "year": "numeric"}   -> "Mar 2, 2026"
##   {"month": "long", "day": "numeric", "year": "numeric"}    -> "March 2, 2026"
##   {"weekday": "long"}                                         -> "Monday"
static func format_date(key, opts = null) -> String:
	if key == null:
		return ""
	if not (opts is Dictionary):
		opts = {"month": "short", "day": "numeric"}
	var p: Dictionary = parse_date_key(str(key))
	var wd = opts.get("weekday")
	var mo = opts.get("month")
	var dy = opts.get("day")
	var yr = opts.get("year")
	var month_text: String = ""
	if mo == "long":
		month_text = MONTHS_LONG[p.month - 1]
	elif mo != null:
		month_text = MONTHS_SHORT[p.month - 1]
	var out: String = ""
	if mo != null and dy != null:
		out = month_text + " " + str(p.day)
		if yr != null:
			out += ", " + str(p.year)
	elif mo != null:
		out = month_text
		if yr != null:
			out += " " + str(p.year)
	elif dy != null:
		out = str(p.day)
		if yr != null:
			out += ", " + str(p.year)
	elif yr != null:
		out = str(p.year)
	if wd != null:
		var wd_text: String = WEEKDAYS_LONG[p.weekday] if wd == "long" else WEEKDAYS_SHORT[p.weekday]
		if out == "":
			out = wd_text
		elif mo == null and yr == null:
			# en-US puts a bare day number before the weekday: "2 Mon".
			out = out + " " + wd_text
		else:
			out = wd_text + ", " + out
	return out


## "Mon, Mar 2, 2026"
static func format_date_long(key) -> String:
	return format_date(key, {"weekday": "short", "month": "short", "day": "numeric", "year": "numeric"})


## "Today", "Yesterday", the weekday name for the last week, otherwise
## "Mar 2". `today` defaults to the local system date.
static func relative_day(key, today = null) -> String:
	if key == null:
		return ""
	var now: String = today_key() if (today == null or str(today) == "") else str(today)
	var diff: int = days_between(str(key), now)
	if diff == 0:
		return "Today"
	if diff == 1:
		return "Yesterday"
	if diff < 7:
		return format_date(key, {"weekday": "long"})
	return format_date(key)
