class_name ShotReader
extends RefCounted
## Works out what a picture says from the text found on it (app/ocr.gd): a
## workout screen from Strava or a similar app is a run or a ride, a smart-scale
## screen is a weigh-in, a picture with next to no text is just a photo.
## Pure logic: no scene, no autoload (tests/shot_reader_test.gd).
##
## A "page" is the text with its positions, in pixels from the top left:
##   {"v", "w", "h", "segs": [[text, x, y, width, height, text_height], ...]}
## ShotReader.page(ocr_image) builds one from the text reader's words (words far
## apart on one line are separate segments, so two columns never run together).
##
## ShotReader.read(page) -> reading:
##   {"kind": "run"|"ride"|"body"|"text"|"photo", "words", "why",
##    "rel": ""|"today"|"yesterday", "month", "day", "year" (0 = not printed),
##    run / ride: "dist", "distUnit", "sec", "elev", "elevUnit", "title",
##    body: "weight", "weightUnit", "fat",
##    "extras": ["Steps 6,480", ...]}
## "text" is a screenshot it could not turn into anything ("why" says so).
## Numbers are reported as printed with their unit ("" when none is printed);
## QuickLog turns them into metres, seconds and kg.

const VERSION = 1
## Unrecognised pictures with fewer words than this are ordinary photos.
const PHOTO_MAX_WORDS = 12
## Words further apart than this many line heights are separate segments.
const SPLIT_GAP = 1.8

const MONTHS = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8,
	"sep": 9, "oct": 10, "nov": 11, "dec": 12}
const MONTH_RX = "(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)"

## A label on a workout screen -> what the number under it is ("x:Name" is kept as a note).
const WORKOUT_LABELS = {
	"distance": "dist", "total distance": "dist",
	"moving time": "moving", "time": "time", "duration": "time", "total time": "time",
	"workout time": "time", "active time": "time", "elapsed time": "elapsed",
	"elevation gain": "elev", "elev gain": "elev", "total ascent": "elev", "ascent": "elev",
	"avg pace": "pace", "average pace": "pace", "pace": "pace",
	"avg speed": "speed", "average speed": "speed", "speed": "speed",
	"steps": "x:Steps", "calories": "x:Calories", "max elevation": "x:Max elevation",
	"avg heart rate": "x:Avg heart rate", "avg hr": "x:Avg heart rate", "max heart rate": "x:Max heart rate",
	"avg power": "x:Avg power", "avg cadence": "x:Avg cadence", "relative effort": "x:Relative effort",
}
const DIST_UNITS = {"mi": "mi", "mile": "mi", "miles": "mi", "km": "km", "k": "km", "kilometers": "km",
	"kilometres": "km", "m": "m", "meters": "m", "metres": "m", "yd": "yd", "yards": "yd"}
const ELEV_UNITS = {"ft": "ft", "feet": "ft", "m": "m", "meters": "m", "metres": "m"}
## "Ib" is how a small "lb" is often read.
const WEIGHT_UNITS = {"lb": "lb", "lbs": "lb", "ib": "lb", "ibs": "lb", "kg": "kg", "kgs": "kg"}

## The sport named at the top of the screen.
const RUN_SPORTS = ["run", "trail run", "virtual run", "treadmill", "treadmill run", "track run", "jog"]
const RIDE_SPORTS = ["ride", "virtual ride", "mountain bike ride", "gravel ride", "e-bike ride", "ebike ride",
	"e-mountain bike ride", "bike ride", "road ride", "indoor ride", "indoor cycling", "cycling", "bike"]
## Sports the game has no place for: named plainly instead of guessed at.
const OTHER_SPORTS = {"walk": "a walk", "hike": "a hike", "swim": "a swim", "row": "a row", "rowing": "a row",
	"weight training": "a weights session", "workout": "a workout", "yoga": "yoga", "rock climb": "a climb",
	"alpine ski": "skiing", "nordic ski": "skiing", "backcountry ski": "skiing", "snowboard": "snowboarding",
	"elliptical": "an elliptical session", "stair stepper": "a stair session", "kayaking": "kayaking"}
const OTHER_WORDS = {"walk": "a walk", "hike": "a hike", "swim": "a swim", "ski": "skiing", "row": "a row",
	"yoga": "yoga", "kayak": "kayaking"}

## Labels on a scale screen kept as a note with their number. Those in PERCENT
## are percentages even when the tiny "%" was not read.
const BODY_LABELS = {
	"muscle": "Muscle", "muscle mass": "Muscle mass", "skeletal muscle": "Skeletal muscle",
	"body water": "Body water", "water": "Body water", "protein": "Protein", "bone mass": "Bone mass",
	"lean body mass": "Lean body mass", "fat-free body weight": "Fat-free weight", "fat free mass": "Fat-free weight",
	"subcutaneous": "Subcutaneous fat", "subcutaneous fat": "Subcutaneous fat", "visceral fat": "Visceral fat",
	"bmi": "BMI", "bmr": "BMR", "metabolic age": "Metabolic age", "body age": "Body age",
}
const PERCENT = ["Muscle", "Skeletal muscle", "Body water", "Protein", "Subcutaneous fat"]
const WEIGHT_LABELS = ["weight", "body weight", "bodyweight", "current weight", "weight (lb)", "weight (lbs)", "weight (kg)"]
const FAT_LABELS = ["body fat", "body fat %", "body fat percentage", "body fat rate", "fat %", "fat", "bf", "bf %"]

const WHY_TEXT = "it has writing on it, but not a run, ride or weigh-in the game knows how to read"
const WHY_NO_DISTANCE = "it looks like a workout, but the distance on it could not be read"
const WHY_OTHER = "it shows %s, and the game reads only runs and rides from pictures"
## A page with these words is a lifting log, not a weigh-in, whatever "weight" it shows.
const LIFT_WORDS_RX = "\\b(?:reps?|sets?|exercises?|1rm|volume)\\b"

static var _cache = {}


static func _rx(pattern: String) -> RegEx:
	if not _cache.has(pattern):
		var r = RegEx.new()
		r.compile(pattern)
		_cache[pattern] = r
	return _cache[pattern]


# ---------------------------------------------------------------------------
# Words from the text reader -> a page of segments
# ---------------------------------------------------------------------------

## `img` = {"w", "h", "lines": [{"t", "words": [{"t", "x", "y", "w", "h"}]}]}.
static func page(img: Dictionary) -> Dictionary:
	var segs = []
	for line in img.get("lines", []):
		if not (line is Dictionary):
			continue
		var words = line.get("words", [])
		if not (words is Array) or words.is_empty():
			continue
		var lh = 0.0
		for w in words:
			lh = maxf(lh, float(w.get("h", 0)))
		var cur = []
		for w in words:
			if not cur.is_empty():
				var prev = cur[cur.size() - 1]
				var gap = float(w.get("x", 0)) - (float(prev.get("x", 0)) + float(prev.get("w", 0)))
				if gap > lh * SPLIT_GAP:
					segs.append(_seg(cur))
					cur = []
			cur.append(w)
		segs.append(_seg(cur))
	segs.sort_custom(func(a, b): return a[1] < b[1] if a[2] == b[2] else a[2] < b[2])
	return {"v": VERSION, "w": int(img.get("w", 0)), "h": int(img.get("h", 0)), "segs": segs}


## Words of one segment -> [text, x, y, width, height, text_height]. The text
## height is the middle word's, so one tall stray mark does not make a line "big".
static func _seg(words: Array) -> Array:
	var texts = []
	var heights = []
	var x0 = INF
	var y0 = INF
	var x1 = -INF
	var y1 = -INF
	for w in words:
		texts.append(str(w.get("t", "")))
		var x = float(w.get("x", 0))
		var y = float(w.get("y", 0))
		heights.append(float(w.get("h", 0)))
		x0 = minf(x0, x)
		y0 = minf(y0, y)
		x1 = maxf(x1, x + float(w.get("w", 0)))
		y1 = maxf(y1, y + float(w.get("h", 0)))
	heights.sort()
	var th = heights[int(heights.size() / 2.0)]
	return [" ".join(PackedStringArray(texts)), int(x0), int(y0), int(x1 - x0), int(y1 - y0), int(th)]


static func _segs(pg: Dictionary) -> Array:
	var out = []
	for a in pg.get("segs", []):
		if not (a is Array) or a.size() < 6:
			continue
		var t = str(a[0])
		out.append({"t": t, "n": norm(t), "x": float(a[1]), "y": float(a[2]), "w": float(a[3]),
			"h": float(a[4]), "th": maxf(float(a[5]), 1.0)})
	return out


## Lower case, bullets and odd dashes out, single spaces.
static func norm(t: String) -> String:
	var s = t.to_lower()
	for c in ["•", "·", "|", "●", "∙", "‧", "▪"]:
		s = s.replace(c, " ")
	for c in ["–", "—", "−"]:
		s = s.replace(c, "-")
	s = s.replace("’", "'").replace("…", "...")
	s = _rx("\\s+").sub(s, " ", true)
	return s.strip_edges()


## A label as its table key: "Avg. Pace:" -> "avg pace", "Subcutaneous..." -> "subcutaneous".
static func label_key(n: String) -> String:
	var s = n.replace(".", "").replace(":", "")
	return _rx("\\s+").sub(s, " ", true).strip_edges()


# ---------------------------------------------------------------------------
# Numbers as printed
# ---------------------------------------------------------------------------

## "1,240" -> 1240, "4,02" -> 4.02, "12.5" -> 12.5; NAN when it is not a number.
static func num(text: String) -> float:
	var t = text.strip_edges()
	if _rx("^\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?$").search(t) != null:
		return float(t.replace(",", ""))
	if _rx("^\\d+,\\d{1,2}$").search(t) != null:
		return float(t.replace(",", "."))
	if _rx("^\\d+(?:\\.\\d+)?$").search(t) != null:
		return float(t)
	return NAN


## "4.02 mi" -> {"v": 4.02, "u": "mi"} for a unit in `units` ("" when none is printed), else null.
static func measure(n: String, units: Dictionary):
	var m = _rx("^(\\d[\\d.,]*) ?([a-z]+)?\\.?$").search(n)
	if m == null:
		return null
	var v = num(m.get_string(1))
	if is_nan(v):
		return null
	var u = m.get_string(2)
	if u != "" and not units.has(u):
		return null
	return {"v": v, "u": str(units[u]) if u != "" else ""}


## "41:37", "1:02:33", "41m 37s", "1h 5m", "45 min" -> seconds, or -1.
static func clock(n: String) -> int:
	var m = _rx("^(\\d{1,3}):(\\d{2}):(\\d{2})$").search(n)
	if m != null:
		return int(m.get_string(1)) * 3600 + int(m.get_string(2)) * 60 + int(m.get_string(3))
	m = _rx("^(\\d{1,3}):(\\d{2})$").search(n)
	if m != null:
		return int(m.get_string(1)) * 60 + int(m.get_string(2))
	m = _rx("^(?:(\\d+) ?h(?:r|rs|ours?)?)? ?(?:(\\d+) ?m(?:in|ins)?)? ?(?:(\\d+) ?s(?:ec|ecs)?)?$").search(n)
	if m != null and (m.get_string(1) != "" or m.get_string(2) != "" or m.get_string(3) != ""):
		return int(m.get_string(1)) * 3600 + int(m.get_string(2)) * 60 + int(m.get_string(3))
	return -1


# ---------------------------------------------------------------------------
# Where a label's value sits
# ---------------------------------------------------------------------------

## The gap when `s` sits under `label` (same column, close by), else -1.
static func _below(label: Dictionary, s: Dictionary) -> float:
	if s.y < label.y + label.h * 0.6:
		return -1.0
	var gap = s.y - (label.y + label.h)
	if gap > maxf(label.th * 4.0, 48.0):
		return -1.0
	var l1 = label.x
	var r1 = label.x + label.w
	var l2 = s.x
	var r2 = s.x + s.w
	var overlap = minf(r1, r2) - maxf(l1, l2)
	var lined_up = absf(l1 - l2) <= label.th * 1.5 or absf((l1 + r1) / 2.0 - (l2 + r2) / 2.0) <= label.th * 1.5
	if overlap <= 0.0 and not lined_up:
		return -1.0
	return maxf(gap, 0.0)


## The gap when `s` is on the row of `label`, to its right, else -1.
static func _beside(label: Dictionary, s: Dictionary) -> float:
	var c1 = label.y + label.h / 2.0
	var c2 = s.y + s.h / 2.0
	if absf(c1 - c2) > maxf(label.th, s.th) * 0.6:
		return -1.0
	var gap = s.x - (label.x + label.w)
	return gap if gap >= 0.0 else -1.0


## The value of `label`: the nearest segment under it, then beside it, that
## `accept` can read (it returns null for one it cannot).
static func _value(label: Dictionary, segs: Array, accept: Callable):
	var under = []
	var beside = []
	for s in segs:
		if is_same(s, label):
			continue
		var g = _below(label, s)
		if g >= 0.0:
			under.append([g, s])
			continue
		g = _beside(label, s)
		if g >= 0.0:
			beside.append([g, s])
	under.sort_custom(func(a, b): return a[0] < b[0])
	beside.sort_custom(func(a, b): return a[0] < b[0])
	for pair in under + beside:
		var v = accept.call(pair[1])
		if v != null:
			return {"v": v, "seg": pair[1]}
	return null


## A unit printed on its own just right of a number ("180.4" then a small "lb").
static func _unit_beside(s: Dictionary, segs: Array, units: Dictionary) -> String:
	for u in segs:
		if not units.has(u.n):
			continue
		var cy = u.y + u.h / 2.0
		var gap = u.x - (s.x + s.w)
		if cy >= s.y and cy <= s.y + s.h and gap >= 0.0 and gap <= maxf(s.th * 1.2, 30.0):
			return str(units[u.n])
	return ""


# ---------------------------------------------------------------------------
# Reading a page
# ---------------------------------------------------------------------------

static func read(pg: Dictionary) -> Dictionary:
	var segs = _segs(pg)
	var words = 0
	for s in segs:
		words += s.t.split(" ", false).size()
	var out = {"kind": "photo", "words": words, "why": "", "rel": "", "month": 0, "day": 0, "year": 0, "extras": []}
	if words < 4:
		return out
	_read_date(segs, out)
	if _read_workout(segs, out):
		return out
	if _read_body(segs, out):
		return out
	var tall = float(pg.get("h", 0)) >= float(pg.get("w", 0)) * 1.9
	if words >= PHOTO_MAX_WORDS and (tall or words >= 30):
		out.kind = "text"
		out.why = WHY_TEXT
		for s in segs:
			if s.y < float(pg.get("h", 0)) * 0.3 and OTHER_SPORTS.has(label_key(s.n)):
				out.why = WHY_OTHER % str(OTHER_SPORTS[label_key(s.n)])
				break
	return out


## The day printed on the screen, from a line that also shows a clock time
## ("Today at 7:31 AM", "November 14, 2026 at 6:02 PM"). Comparisons such as
## "2.1 lb vs Sat, Oct 3" are not the day of the entry.
static func _read_date(segs: Array, out: Dictionary) -> void:
	for s in segs:
		var n = s.n
		if _rx("\\b(?:vs|since|than|from)\\b").search(n) != null:
			continue
		if _rx("\\b\\d{1,2}:\\d{2}\\b").search(n) == null:
			continue
		var m = _rx("\\b(today|yesterday)\\b").search(n)
		if m != null:
			out.rel = m.get_string(1)
			return
		m = _rx("\\b" + MONTH_RX + "\\.? (\\d{1,2})(?:st|nd|rd|th)?(?:,? (\\d{4}))?\\b").search(n)
		if m != null:
			out.month = int(MONTHS[m.get_string(1).substr(0, 3)])
			out.day = int(m.get_string(2))
			out.year = int(m.get_string(3)) if m.get_string(3) != "" else 0
			return
		m = _rx("\\b(\\d{1,2})/(\\d{1,2})/(\\d{4}|\\d{2})\\b").search(n)
		if m != null:
			var a = int(m.get_string(1))
			var b = int(m.get_string(2))
			out.month = b if a > 12 and b <= 12 else a
			out.day = a if a > 12 and b <= 12 else b
			out.year = int(m.get_string(3))
			if out.year < 100:
				out.year += 2000
			return


static func _accept_dist(s: Dictionary):
	var v = measure(s.n, DIST_UNITS)
	return v if v != null and float(v.v) > 0.0 else null


static func _accept_elev(s: Dictionary):
	return measure(s.n, ELEV_UNITS)


static func _accept_time(s: Dictionary):
	var sec = clock(s.n)
	return sec if sec > 0 else null


static func _accept_any(s: Dictionary):
	return s.n if _rx("^\\d").search(s.n) != null else null


static func _accept_extra(s: Dictionary):
	return s.t.strip_edges() if _rx("^\\d").search(s.n) != null and s.t.length() <= 16 else null


## A run or ride (true when the page was a workout screen, read or not).
static func _read_workout(segs: Array, out: Dictionary) -> bool:
	var found = {}
	var found_seg = {}
	var dist_label = null
	for s in segs:
		var what = WORKOUT_LABELS.get(label_key(s.n))
		if what == null or found.has(what):
			continue
		what = str(what)
		var got = null
		if what == "dist":
			got = _value(s, segs, ShotReader._accept_dist)
		elif what == "elev":
			got = _value(s, segs, ShotReader._accept_elev)
		elif what == "moving" or what == "time" or what == "elapsed":
			got = _value(s, segs, ShotReader._accept_time)
		elif what == "pace" or what == "speed":
			var beside = _value(s, segs, ShotReader._accept_any)
			found[what] = str(beside.v) if beside != null else ""
			continue
		else:
			got = _value(s, segs, ShotReader._accept_extra)
		if got == null:
			continue
		found[what] = got.v
		found_seg[what] = got.seg
		if what == "dist":
			dist_label = s
	var hints = 0
	for k in ["moving", "time", "elapsed", "pace", "speed", "elev"]:
		if found.has(k):
			hints += 1
	if not found.has("dist"):
		if hints >= 2:
			out.kind = "text"
			out.why = WHY_NO_DISTANCE
			return true
		return false
	if hints == 0:
		# "Distance" alone is not a workout screen (a map, a route planner...).
		return false
	var title = _title(segs, dist_label)
	var sport = _sport(segs, dist_label, title, found)
	if sport.kind == "other":
		out.kind = "text"
		out.why = WHY_OTHER % str(sport.name)
		return true
	out.kind = sport.kind
	# A unit the reader missed: printed beside the number, or told by the pace.
	var du = str(found.dist.u)
	if du == "":
		du = _unit_beside(found_seg.dist, segs, DIST_UNITS)
	if du == "":
		var rate = str(found.get("pace", "")) + " " + str(found.get("speed", ""))
		if _rx("km|kph").search(rate) != null:
			du = "km"
		elif _rx("mi|mph").search(rate) != null:
			du = "mi"
	out["dist"] = float(found.dist.v)
	out["distUnit"] = du
	var sec = 0
	for k in ["moving", "time", "elapsed"]:
		if found.has(k) and sec == 0:
			sec = int(found[k])
	out["sec"] = sec
	var eu = str(found.elev.u) if found.has("elev") else ""
	if found.has("elev") and eu == "":
		eu = _unit_beside(found_seg.elev, segs, ELEV_UNITS)
	if found.has("elev") and eu == "" and du != "":
		eu = "m" if du == "km" or du == "m" else "ft"
	out["elev"] = float(found.elev.v) if found.has("elev") else 0.0
	out["elevUnit"] = eu
	out["title"] = title
	for k in found:
		if str(k).begins_with("x:"):
			out.extras.append("%s %s" % [str(k).substr(2), str(found[k])])
	return true


## The name of the activity: the biggest writing above the numbers.
static func _title(segs: Array, dist_label: Dictionary) -> String:
	var best = null
	for s in segs:
		if s.y >= dist_label.y or s.th < dist_label.th * 1.25:
			continue
		if _rx("[a-z]").search(s.n) == null or _rx("\\b\\d{1,2}:\\d{2}\\b").search(s.n) != null:
			continue
		if best == null or s.th > best.th:
			best = s
	return "" if best == null else str(best.t).strip_edges().substr(0, 60)


## {"kind": "run"|"ride"|"other", "name"}: the sport named at the top of the
## screen, else what the title and the pace / speed label say, else the speed.
static func _sport(segs: Array, dist_label: Dictionary, title: String, found: Dictionary) -> Dictionary:
	for s in segs:
		if s.y >= dist_label.y:
			continue
		var k = label_key(s.n)
		if RUN_SPORTS.has(k):
			return {"kind": "run", "name": k}
		if RIDE_SPORTS.has(k):
			return {"kind": "ride", "name": k}
		if OTHER_SPORTS.has(k):
			return {"kind": "other", "name": OTHER_SPORTS[k]}
	var t = norm(title)
	for w in OTHER_WORDS:
		if _rx("\\b%s\\b" % w).search(t) != null:
			return {"kind": "other", "name": OTHER_WORDS[w]}
	if found.has("pace") and not found.has("speed"):
		return {"kind": "run", "name": "run"}
	if found.has("speed") and not found.has("pace"):
		return {"kind": "ride", "name": "ride"}
	if _rx("\\b(?:run|jog)\\b").search(t) != null:
		return {"kind": "run", "name": "run"}
	if _rx("\\b(?:ride|bike|cycle|cycling)\\b").search(t) != null:
		return {"kind": "ride", "name": "ride"}
	# Nothing says which: faster than about 17 km/h is a ride.
	var sec = 0
	for k in ["moving", "time", "elapsed"]:
		if found.has(k) and sec == 0:
			sec = int(found[k])
	var km = float(found.dist.v)
	match str(found.dist.u):
		"mi":
			km *= 1.609344
		"m":
			km /= 1000.0
		"yd":
			km *= 0.0009144
	if sec > 0 and km / (float(sec) / 3600.0) >= 17.0:
		return {"kind": "ride", "name": "ride"}
	return {"kind": "run", "name": "run"}


## A weight as printed: "180.4", "82.4 kg", and "2.41b" for a "2.4 lb" read badly.
static func weight_of(n: String):
	var m = _rx("^(\\d[\\d.,]*?) ?[1il]bs?$").search(n)
	if m != null and not is_nan(num(m.get_string(1))):
		return {"v": num(m.get_string(1)), "u": "lb"}
	return measure(n, WEIGHT_UNITS)


static func _accept_weight(s: Dictionary):
	return weight_of(s.n)


## lb or kg, whichever the weights on the page are mostly printed in ("" when none is).
static func _page_weight_unit(segs: Array) -> String:
	var lb = 0
	var kg = 0
	for s in segs:
		for hit in _rx("\\d ?(lbs?|ibs?|kgs?)\\b").search_all(s.n):
			if hit.get_string(1).begins_with("k"):
				kg += 1
			else:
				lb += 1
		if s.n == "lb" or s.n == "lbs" or s.n == "ib":
			lb += 1
		elif s.n == "kg":
			kg += 1
	if lb == 0 and kg == 0:
		return ""
	return "kg" if kg > lb else "lb"


static func _accept_fat(s: Dictionary):
	var m = _rx("^(\\d{1,2}(?:[.,]\\d{1,2})?) ?%?$").search(s.n)
	if m == null:
		return null
	var v = num(m.get_string(1))
	return v if not is_nan(v) and v >= 2.0 and v <= 75.0 else null


static func _accept_number(s: Dictionary):
	var m = _rx("^(\\d[\\d.,]*) ?(lbs?|kgs?|%)?$").search(s.n)
	if m == null or is_nan(num(m.get_string(1))):
		return null
	return {"text": m.get_string(1), "u": m.get_string(2)}


## A weigh-in: the weight (by its label, else the biggest number with lb / kg
## next to it), body fat, and the other readings as a note.
static func _read_body(segs: Array, out: Dictionary) -> bool:
	var weight = null
	var unit = ""
	var fat = null
	var lifting = false
	for s in segs:
		if _rx(LIFT_WORDS_RX).search(s.n) != null:
			lifting = true
	for s in segs:
		var k = label_key(s.n)
		if weight == null and WEIGHT_LABELS.has(k):
			var got = _value(s, segs, ShotReader._accept_weight)
			if got != null:
				weight = float(got.v.v)
				unit = str(got.v.u)
				if unit == "":
					unit = _unit_beside(got.seg, segs, WEIGHT_UNITS)
				if unit == "" and k.contains("("):
					unit = "kg" if k.contains("kg") else "lb"
		if fat == null and FAT_LABELS.has(k):
			var got = _value(s, segs, ShotReader._accept_fat)
			if got != null:
				fat = float(got.v)
	if weight == null:
		# No label: the headline number. A unit beside it settles it; without one
		# (small units next to big digits are often not read) it must clearly be
		# the biggest writing on a page that is about weight.
		var heights = []
		for s in segs:
			heights.append(s.th)
		heights.sort()
		var usual = heights[int(heights.size() / 2.0)] if not heights.is_empty() else 1.0
		var best = null
		for s in segs:
			var m = weight_of(s.n)
			if m == null or float(m.v) < 25.0 or float(m.v) > 770.0:
				continue
			var u = str(m.u) if str(m.u) != "" else _unit_beside(s, segs, WEIGHT_UNITS)
			if s.th < usual * 1.6:
				continue
			if best == null or s.th > best.seg.th:
				best = {"seg": s, "v": float(m.v), "u": u}
		if best != null:
			var mentions = false
			for s in segs:
				if _rx("\\b(?:weigh|weight|weighed|scale|bmi|body fat)\\b|weigh-in").search(s.n) != null:
					mentions = true
			if mentions or fat != null:
				weight = best.v
				unit = best.u if best.u != "" else _page_weight_unit(segs)
	if weight == null and fat == null:
		return false
	if lifting and fat == null:
		return false
	out.kind = "body"
	if weight != null:
		out["weight"] = weight
		out["weightUnit"] = unit
	if fat != null:
		out["fat"] = fat
	var seen = {}
	for s in segs:
		var name = BODY_LABELS.get(label_key(s.n))
		if name == null or seen.has(name):
			continue
		var got = _value(s, segs, ShotReader._accept_number)
		if got == null:
			continue
		var u = str(got.v.u)
		if u == "":
			u = _unit_beside(got.seg, segs, {"lb": "lb", "lbs": "lb", "kg": "kg", "%": "%"})
		if u == "" and PERCENT.has(name):
			u = "%"
		seen[name] = true
		out.extras.append("%s %s%s" % [str(name), str(got.v.text), "%" if u == "%" else ((" " + u) if u != "" else "")])
	return true
