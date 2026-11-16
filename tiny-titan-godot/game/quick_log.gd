class_name QuickLog
extends RefCounted
## Reads workout shorthand typed on a phone ("bench 3x5 @ 80", "v4 flash x2",
## "run 5.2km 27:30") into sessions and body check-ins. Pure logic: no scene,
## no autoload, so it runs headless from tests/quick_log_test.gd.
##
## QuickLog.parse(text, opts) -> {"entries": [...], "problems": [{"line", "why"}]}
## opts = {"today": "YYYY-MM-DD", "weightUnit": "kg"|"lb", "distanceUnit": "km"|"mi",
##         "exercises": [known display names], "loaded": [normalised names that have weights in the log],
##         "shots": {picture name: what it says (ShotReader.read plus "seen": the day it was first seen)},
##         "lastLoadKg": {misc kind: the weight carried last time, used when a line gives none}}
## Every line that is not a comment either becomes part of an entry or a problem:
## nothing is dropped silently.

const NO_DATE_NOTE = "no date given, assumed today"
const SHOT_TODAY = "the picture says \"Today\": taken as the day the game first saw it"
const SHOT_YESTERDAY = "the picture says \"Yesterday\": counted back from the day the game first saw it"
const SHOT_NO_DATE = "no date on the picture: taken as the day the game first saw it"

## What the app shows as the cheat sheet. Every line here must parse (the unit test checks).
const CHEAT_SHEET = "nov 14\nbench 3x5 @ 80\nsquat 5,5,4 @ 100\npull-up 3x8\nv4 flash x2, v5 send\ntr 5.10a flash, 5.11a\nhang 20mm 10s x6\nrun 5.2km 27:30 +80m\nride 40km 1h35\nvest walk 3km 40:00 10kg\nweight 82.4  bf 18"

const MONTHS = {
	"jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "apr": 4, "april": 4,
	"may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8, "sep": 9, "sept": 9,
	"september": 9, "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12,
}
const WEEKDAYS = {
	"mon": 0, "monday": 0, "tue": 1, "tues": 1, "tuesday": 1, "wed": 2, "weds": 2, "wednesday": 2,
	"thu": 3, "thur": 3, "thurs": 3, "thursday": 3, "fri": 4, "friday": 4, "sat": 5, "saturday": 5,
	"sun": 6, "sunday": 6,
}
const WEEKDAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

## Shorthand -> exercise name. Keys are "compact" (lower case, no spaces or hyphens).
const ALIASES = {
	"bench": "Bench Press", "bp": "Bench Press",
	"ohp": "Overhead Press", "press": "Overhead Press", "overhead": "Overhead Press", "shoulderpress": "Overhead Press", "militarypress": "Overhead Press",
	"dl": "Deadlift", "dls": "Deadlift", "dead": "Deadlift", "deads": "Deadlift",
	"squats": "Squat", "sq": "Squat", "backsquat": "Squat",
	"pullups": "Pull-up", "pullup": "Pull-up",
	"chins": "Chin-up", "chinups": "Chin-up", "chinup": "Chin-up",
	"rows": "Barbell Row", "row": "Barbell Row", "bbrow": "Barbell Row",
	"rdl": "Romanian Deadlift", "rdls": "Romanian Deadlift",
	"dips": "Dip",
	"pushups": "Push-up", "pushup": "Push-up",
	"curls": "Bicep Curl", "curl": "Bicep Curl", "bicepcurls": "Bicep Curl", "barbellcurl": "Bicep Curl",
	"thrusts": "Hip Thrust", "pulldown": "Lat Pulldown", "pulldowns": "Lat Pulldown",
	"incline": "Incline Bench Press", "inclinebench": "Incline Bench Press",
	"laterals": "Lateral Raise", "latraises": "Lateral Raise",
	"kbswing": "Kettlebell Swing", "kbswings": "Kettlebell Swing", "swings": "Kettlebell Swing",
	"pushdowns": "Tricep Pushdown", "dbpress": "Dumbbell Press",
}
## An exercise whose name contains one of these is normally done with a weight.
const LOADED_WORDS = ["squat", "bench", "deadlift", "press", "row", "curl", "thrust", "lunge", "pulldown",
	"pushdown", "clean", "snatch", "swing", "raise", "face pull", "extension", "fly", "shrug", "weighted"]

const RESULT_WORDS = {
	"flash": "flash", "f": "flash", "flashed": "flash", "fl": "flash",
	"send": "send", "s": "send", "sent": "send", "top": "send", "topped": "send",
	"attempt": "attempt", "attempts": "attempt", "att": "attempt", "a": "attempt", "fail": "attempt",
	"failed": "attempt", "project": "attempt", "proj": "attempt", "tried": "attempt",
}
const CARDIO_WORDS = {
	"run": "run", "ran": "run", "running": "run", "jog": "run", "jogged": "run", "jogging": "run",
	"ride": "ride", "rode": "ride", "bike": "ride", "biked": "ride", "cycle": "ride", "cycled": "ride", "cycling": "ride",
}
const CLIMB_WORDS = ["climb", "climbing", "climbed", "boulder", "bouldering", "bouldered"]
## Roped climbing: these words, or a 5.xx grade, make a climb a route.
const ROPE_WORDS = ["tr", "toprope", "rope", "roped", "route", "routes", "lead", "led", "sport"]
const HANG_WORDS = ["hang", "hangs", "hangboard", "hangboarding", "deadhang", "deadhangs", "fingerboard", "fingerboarding"]
const LIFT_WORDS = ["lift", "lifting", "gym", "weights"]
const BODY_WORDS = ["weight", "bw", "weighed", "weigh", "wt", "bf", "bodyfat", "bodyweight", "body", "fat"]
## "progress pics 11/15" dates a block like "11/15" does; a bare "pics" line is a label and is skipped.
const PHOTO_LABEL = "^(?:progress (?:pics?|photos?|pictures?)|progress|pics?|pix|photos?|pictures?)"
const TOO_MANY_PHOTOS = "more than three pictures on this day: the first three are kept (front, side, back)"
const FILLER = ["in", "for", "at", "of", "and", "with", "-", ":", "total", "="]
const ELEV_WORDS = ["elev", "elevation", "gain", "up", "vert", "ascent", "climbing"]
const UNIT_WORDS = ["km", "k", "mi", "mile", "miles", "m", "min", "mins", "minute", "minutes", "h", "hr", "hrs",
	"hour", "hours", "ft", "feet", "s", "sec", "secs", "meters", "metres"]
const FT_TO_M = 0.3048

static var _cache = {}


static func _rx(pattern: String) -> RegEx:
	if not _cache.has(pattern):
		var r = RegEx.new()
		r.compile(pattern)
		_cache[pattern] = r
	return _cache[pattern]


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

static func parse(text: String, opts: Dictionary) -> Dictionary:
	var ctx = _ctx(opts)
	var out = {"entries": [], "problems": []}
	_run(split_lines(text), ctx, out, null)
	return out


## A Google Form responses sheet exported as CSV: each row whose first cell is a
## timestamp is one block dated by it; the header row is skipped.
static func parse_csv(text: String, opts: Dictionary) -> Dictionary:
	var ctx = _ctx(opts)
	var out = {"entries": [], "problems": []}
	var rows = csv_rows(text.replace("﻿", ""))
	var seen_first = false
	for row in rows:
		var cells = []
		for c in row:
			cells.append(str(c))
		var blank = true
		for c in cells:
			if c.strip_edges() != "":
				blank = false
		if blank:
			continue
		var first = cells[0].strip_edges()
		var ts = timestamp_date(first)
		if ts == "":
			if seen_first:
				out.problems.append({"line": ", ".join(PackedStringArray(cells)).strip_edges(), "why": "row has no date in the first column"})
			seen_first = true
			continue
		seen_first = true
		var lines = []
		for j in range(1, cells.size()):
			lines.append_array(split_lines(cells[j]))
		_run(lines, ctx, out, {"header": "row " + normalize_line(first), "date": ts, "note": ""})
	return out


## CSV when the first line looks like a form export ("Timestamp,…" or a date-and-time cell), else plain text.
static func parse_any(text: String, opts: Dictionary) -> Dictionary:
	if looks_like_csv(text):
		return parse_csv(text, opts)
	return parse(text, opts)


static func looks_like_csv(text: String) -> bool:
	for raw in split_lines(text):
		var t = raw.strip_edges()
		if t == "":
			continue
		var first = t.get_slice(",", 0).strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
		if not t.contains(","):
			return false
		if first.to_lower() == "timestamp":
			return true
		return first.contains(":") and timestamp_date(first) != ""
	return false


static func split_lines(text: String) -> Array:
	var t = text.replace("﻿", "").replace("\r\n", "\n").replace("\r", "\n")
	return Array(t.split("\n"))


## Phone-keyboard text -> plain lower-case ASCII-ish shorthand with single spaces.
static func normalize_line(raw: String) -> String:
	var t = raw.replace("﻿", "").replace("​", "")
	for c in [" ", " ", " ", " ", "\t"]:
		t = t.replace(c, " ")
	for c in ["–", "—", "−"]:
		t = t.replace(c, "-")
	t = t.replace("‘", "'").replace("’", "'").replace("“", "\"").replace("”", "\"")
	t = t.strip_edges()
	# List bullets and numbering from notes apps: "- bench …", "* bench …", "• bench …", "1. bench …".
	t = _rx("^(?:[-*\\x{2022}\\x{00B7}>]+|\\d+[.)])\\s+(?=\\S)").sub(t, "")
	t = t.to_lower().replace("×", "x").replace("*", "x")
	t = _rx("\\s+").sub(t, " ", true)
	return t.strip_edges()


# ---------------------------------------------------------------------------
# Blocks: a date line starts one; the entries after it get its date
# ---------------------------------------------------------------------------

static func _ctx(opts: Dictionary) -> Dictionary:
	var today = str(opts.get("today", "2026-01-01"))
	var known = opts.get("exercises", [])
	if not (known is Array) or known.is_empty():
		known = Summary.DEFAULT_EXERCISES
	var known_norm = {}
	for n in known:
		known_norm[Xp.normalize_exercise(n)] = str(n)
	var loaded = {}
	for n in opts.get("loaded", []):
		loaded[Xp.normalize_exercise(n)] = true
	return {
		"today": today,
		"wu": str(opts.get("weightUnit", "kg")),
		"du": str(opts.get("distanceUnit", "km")),
		"known_norm": known_norm,
		"loaded": loaded,
		"shots": opts.get("shots", {}) if opts.get("shots", {}) is Dictionary else {},
		"used_shots": {},
		"last_load": opts.get("lastLoadKg", {}) if opts.get("lastLoadKg", {}) is Dictionary else {},
	}


static func _new_block(header: String, date: String, note: String) -> Dictionary:
	return {"header": header, "date": date, "note": note, "lift": null, "climb": null, "body": null,
		"current": null, "pending": [], "entries": [], "shot_bodies": {}}


static func _run(lines: Array, ctx: Dictionary, out: Dictionary, fixed) -> void:
	var block
	if fixed == null:
		block = _new_block("", ctx.today, NO_DATE_NOTE)
	else:
		block = _new_block(fixed.header, fixed.date, fixed.note)
	for raw in lines:
		var orig = str(raw).replace("﻿", "").strip_edges()
		var t = normalize_line(orig)
		if t == "" or t.begins_with("#") or t.begins_with("//"):
			continue
		block = _line(block, orig, t, ctx, out)
	_close(block, ctx, out)


static func _line(block: Dictionary, orig: String, t: String, ctx: Dictionary, out: Dictionary) -> Dictionary:
	# Separators: "---" starts new lift / climb sessions for the same day; a bare
	# "lift" / "gym" starts a new lift session, a bare "climb" a new climb session.
	if _rx("^(?:-{3,}|={3,}|_{3,})$").search(t) != null:
		block.lift = null
		block.climb = null
		block.current = null
		return block
	var word = t.trim_suffix(":").strip_edges()
	if LIFT_WORDS.has(word):
		block.lift = null
		return block
	if CLIMB_WORDS.has(word):
		block.climb = null
		return block

	# Date lines, also "nov 14: bench 3x5 @ 80" (a date, a colon, then an entry).
	var d = date_line(t, ctx.today)
	var rest = ""
	if d.is_empty() and t.contains(":"):
		var head = t.get_slice(":", 0)
		d = date_line(head, ctx.today)
		if not d.is_empty():
			rest = t.substr(head.length() + 1).strip_edges()
	if d.has("invalid"):
		out.problems.append({"line": orig, "why": "that date does not exist"})
		return block
	if not d.is_empty():
		_close(block, ctx, out)
		var nb = _new_block(d.header, d.date, d.note)
		if rest != "":
			return _line(nb, orig, rest, ctx, out)
		return nb

	# "progress pics" on its own line is a label for the pictures under it.
	if _rx(PHOTO_LABEL + "$").search(t) != null:
		return block

	var toks = t.split(" ", false)
	var first = toks[0].trim_suffix(":")

	# A picture in the note: the inbox turns each image of a Google Doc into
	# "photo images/image1.jpg". Up to three join the day's check-in, in order.
	if first == "photo" and toks.size() == 2 and (toks[1].contains("/") or toks[1].contains(".")):
		# A picture the game could read (a workout or weigh-in screenshot) is that
		# workout or weigh-in, not a progress photo.
		var shot = ctx.shots.get(toks[1])
		if shot is Dictionary and str(shot.get("kind", "photo")) != "photo":
			# The same screenshot pasted twice is still one workout.
			var sid = str(shot.get("id", toks[1]))
			if ctx.used_shots.has(sid):
				return block
			ctx.used_shots[sid] = true
			var kind = str(shot.get("kind", "photo"))
			if kind == "run" or kind == "ride" or kind == "walk":
				_shot_session(block, toks[1], shot, orig, ctx, out)
				return block
			if kind == "body":
				_shot_body(block, toks[1], shot, orig, ctx, out)
				return block
			if kind == "text":
				out.problems.append({"line": orig, "why": str(shot.get("why", ShotReader.WHY_TEXT)), "picture": toks[1]})
				return block
		var e = _body_entry(block)
		var refs = e.data.get("photoRefs", [])
		if refs.size() >= TT.PHOTO_ANGLES.size():
			if not e.warnings.has(TOO_MANY_PHOTOS):
				e.warnings.append(TOO_MANY_PHOTOS)
			return block
		refs.append(toks[1])
		e.data["photoRefs"] = refs
		e.raw.append(orig)
		e.norm.append(t)
		return block

	# Extras for the session being built: title / note / duration.
	if (first == "title" or first == "note" or first == "notes") and (toks.size() > 1 or toks[0].ends_with(":")):
		var value = orig
		var colon = orig.find(":")
		if colon >= 0:
			value = orig.substr(colon + 1).strip_edges()
		else:
			value = orig.substr(orig.to_lower().find(first) + first.length()).strip_edges()
		if value == "":
			out.problems.append({"line": orig, "why": "the %s is empty" % first})
			return block
		_extra(block, {"field": "title" if first == "title" else "notes", "value": value, "orig": orig, "norm": t})
		return block
	if first == "duration" or first == "time":
		var sec = parse_duration(t.substr(t.find(" ") + 1) if t.contains(" ") else "")
		if sec <= 0:
			out.problems.append({"line": orig, "why": "could not read the time (try 70min or 1h10)"})
			return block
		_extra(block, {"field": "durationSec", "value": sec, "orig": orig, "norm": t})
		return block

	# Body check-in.
	if BODY_WORDS.has(first) and (first != "body" or t.begins_with("body fat") or t.begins_with("body weight")):
		var b = _parse_body(t, ctx)
		if not b.ok:
			out.problems.append({"line": orig, "why": b.why})
			return block
		var e = _body_entry(block)
		for k in ["weightKg", "bodyFatPct"]:
			if b.has(k):
				if e.data.has(k):
					e.warnings.append("two %s values for this day, kept the last" % ("weights" if k == "weightKg" else "body fat"))
				e.data[k] = b[k]
		e.raw.append(orig)
		e.norm.append(t)
		return block

	# Misc activities (game/misc.gd): "vest walk 3km 40:00 10kg" is its own
	# session; a "vest 10kg" line under one sets the weight carried.
	var mk = _misc_kind(t)
	if mk.kind != "":
		var mres = _parse_misc(mk.kind, mk.rest, ctx)
		if not mres.ok:
			out.problems.append({"line": orig, "why": mres.why})
			return block
		var me = _session(block, TT.MISC)
		me.data["kind"] = mk.kind
		me.data["distanceM"] = mres.distanceM
		me.data["elevationM"] = mres.elevationM
		if mres.durationSec > 0:
			me.data["durationSec"] = mres.durationSec
		me.warnings.append_array(mres.warnings)
		_set_load(me, mk.kind, mres.loadKg, ctx)
		_take(block, me, orig, t)
		return block
	var lw = _load_line(t, ctx)
	if not lw.is_empty():
		var cur = block.current
		if cur == null or str(cur.data.get("discipline", "")) != TT.MISC or str(Misc.meta(cur.data.get("kind")).loadWord) != str(lw.word):
			out.problems.append({"line": orig, "why": "no %s walk above it to put the %s on" % [lw.word, lw.word]})
			return block
		if float(lw.kg) <= 0.0 or float(lw.kg) > MAX_LOAD_KG:
			out.problems.append({"line": orig, "why": "that %s weight looks wrong" % lw.word})
			return block
		_set_load(cur, str(cur.data.kind), float(lw.kg), ctx)
		cur.raw.append(orig)
		cur.norm.append(t)
		return block

	# Running / cycling: every line is its own session.
	if CARDIO_WORDS.has(first):
		var c = _parse_cardio(t, ctx)
		if not c.ok:
			out.problems.append({"line": orig, "why": c.why})
			return block
		var e = _session(block, c.disc)
		e.data["distanceM"] = c.distanceM
		e.data["elevationM"] = c.elevationM
		if c.durationSec > 0:
			e.data["durationSec"] = c.durationSec
		e.warnings.append_array(c.warnings)
		_take(block, e, orig, t)
		return block

	# Hangboard: joins the day's climb session.
	# ("hang clean" and "hanging leg raise" are lifts, not hangs.)
	if (HANG_WORDS.has(first) or _rx("^(?:(?:one|single|1|two|2|both)[ -]?arms? )?(?:dead ?)?hangs?\\b").search(t) != null) and _rx("\\b(?:clean|cleans|snatch|leg|knee|raise|raises|pull|pulls|power)\\b").search(t) == null:
		var hg = _parse_hang(t, ctx.wu)
		for bad in hg.bad:
			out.problems.append({"line": orig, "why": "could not read \"%s\" (try hang 20mm 10s x6)" % bad})
		if hg.hangs.is_empty():
			if hg.bad.is_empty():
				out.problems.append({"line": orig, "why": "no hang found (try hang 20mm 10s x6)"})
			return block
		if block.climb == null:
			block.climb = _session(block, "climb")
		var he = block.climb
		if not he.data.has("hangs"):
			he.data["hangs"] = []
		for x in hg.hangs:
			var merged = false
			for y in he.data.hangs:
				if int(y.edgeMm) == int(x.edgeMm) and int(y.sec) == int(x.sec) and int(y.arms) == int(x.arms) and absf(float(y.addKg) - float(x.addKg)) < 0.01:
					y.count = int(y.count) + int(x.count)
					merged = true
			if not merged:
				he.data.hangs.append(x)
		_take(block, he, orig, t)
		return block

	# Climbing: boulders (V grades) and routes (5.xx).
	if CLIMB_WORDS.has(first) or ROPE_WORDS.has(first) or t.begins_with("top rope") or _rx("^(?:\\d+\\s*x\\s*)?(?:vb|v\\d{1,2}|5\\.\\d{1,2}[a-d]?)(?![\\d.])").search(t) != null:
		var cl = _parse_climb(t)
		for bad in cl.bad:
			out.problems.append({"line": orig, "why": "could not read \"%s\" (try v4 flash x2, or 5.10a flash)" % bad})
		if cl.climbs.is_empty():
			if cl.bad.is_empty():
				out.problems.append({"line": orig, "why": "no grades found (try v4 flash x2, or 5.10a flash)"})
			return block
		if block.climb == null:
			block.climb = _session(block, "climb")
		var e = block.climb
		for x in cl.climbs:
			var merged = false
			for y in e.data.climbs:
				if int(y.grade) == int(x.grade) and y.result == x.result and y.get("yds") == x.get("yds"):
					y.count = int(y.count) + int(x.count)
					merged = true
			if not merged:
				e.data.climbs.append(x)
		_take(block, e, orig, t)
		return block

	# Lifting.
	var l = _parse_lift(t, ctx)
	if not l.ok:
		out.problems.append({"line": orig, "why": l.why})
		return block
	if block.lift == null:
		block.lift = _session(block, "lift")
	var le = block.lift
	var target = null
	for ex in le.data.exercises:
		if ex.name == l.name:
			target = ex
	if target == null:
		target = {"name": l.name, "sets": []}
		le.data.exercises.append(target)
	target.sets.append_array(l.sets)
	le.warnings.append_array(l.warnings)
	_take(block, le, orig, t)
	return block


## The day's one body check-in (weight, body fat and pictures share it).
static func _body_entry(block: Dictionary) -> Dictionary:
	if block.body == null:
		block.body = {"kind": "body", "disc": "body", "data": {"date": block.date}, "raw": [], "norm": [], "warnings": []}
		block.entries.append(block.body)
	return block.body


static func _session(block: Dictionary, disc: String) -> Dictionary:
	var e = {"kind": "session", "disc": disc, "data": {"discipline": disc, "date": block.date}, "raw": [], "norm": [], "warnings": []}
	if disc == "lift":
		e.data["exercises"] = []
	elif disc == "climb":
		e.data["climbs"] = []
	block.entries.append(e)
	return e


## Record a line as part of `e` and make it the session extras attach to.
static func _take(block: Dictionary, e: Dictionary, orig: String, t: String) -> void:
	e.raw.append(orig)
	e.norm.append(t)
	block.current = e
	for x in block.pending:
		_apply_extra(e, x)
	block.pending = []


static func _extra(block: Dictionary, x: Dictionary) -> void:
	if block.current != null:
		_apply_extra(block.current, x)
	else:
		# "title: Push day" written above the lifts: hold it for the next session.
		block.pending.append(x)


static func _apply_extra(e: Dictionary, x: Dictionary) -> void:
	e.raw.append(x.orig)
	e.norm.append(x.norm)
	if x.field == "notes" and e.data.has("notes"):
		e.data["notes"] = str(e.data.notes) + "\n" + str(x.value)
	else:
		e.data[x.field] = x.value


static func _close(block: Dictionary, ctx: Dictionary, out: Dictionary) -> void:
	for x in block.pending:
		out.problems.append({"line": x.orig, "why": "no session on that day to attach it to"})
	block.pending = []
	for e in block.entries:
		# An entry read from a picture may carry its own day, and is keyed by what
		# the picture says: another picture is another entry, never an edit of this one.
		var date = str(e.get("date", block.date))
		e.data["date"] = date
		var header = block.header
		var shown = e.data
		if e.has("shots"):
			header += "|" + str(e.get("shot_tag", ""))
			if e.kind == "session":
				shown = e.data.duplicate()
				shown.erase("notes")
		var entry = {
			"key": entry_key(e.disc, header, e.norm),
			"kind": e.kind,
			"date": date,
			"date_note": str(e.get("date_note", block.note)),
			"data": e.data,
			"summary": summary(e.kind, shown, ctx.wu, ctx.du),
			"warnings": e.warnings,
			"raw": e.raw,
		}
		if e.has("shots"):
			entry["shots"] = e.shots
			entry["extras"] = e.get("extras", [])
		out.entries.append(entry)
	block.entries = []
	block.shot_bodies = {}


## Stable id for an entry: its kind, the raw date-header text and its raw lines
## (not the resolved date, so the same note gives the same keys on any day).
static func entry_key(disc: String, header: String, norm_lines: Array) -> String:
	var content = disc + "\n" + header + "\n" + "\n".join(PackedStringArray(norm_lines))
	return "%s-%s-%s" % [disc, header.md5_text().substr(0, 6), content.md5_text().substr(0, 12)]


## The part of a key that names the day and kind ("lift-1a2b3c"): two keys with
## the same prefix are the same kind of entry under the same date line.
static func key_prefix(key: String) -> String:
	var parts = key.split("-")
	if parts.size() < 3:
		return key
	return parts[0] + "-" + parts[1]


# ---------------------------------------------------------------------------
# Misc activities (game/misc.gd)
# ---------------------------------------------------------------------------

## What a walk read from a screenshot becomes.
const WALK_KIND = "vest_walk"
const MAX_LOAD_KG = 150.0


## {"kind", "rest"} when the line starts with a misc kind's words ("vest walk ..."), else kind "".
static func _misc_kind(t: String) -> Dictionary:
	for k in Misc.ORDER:
		for phrase in Misc.KINDS[k].words:
			var w: String = str(phrase)
			if t == w or t.begins_with(w + " ") or t.begins_with(w + ":"):
				return {"kind": str(k), "rest": t.substr(w.length()).trim_prefix(":").strip_edges()}
	return {"kind": "", "rest": ""}


## {"word", "kg"} for a line that only sets a carried weight ("vest 10kg", "vest: 20 lb", "vest 20"), else {}.
static func _load_line(t: String, ctx: Dictionary) -> Dictionary:
	for k in Misc.ORDER:
		var word: String = str(Misc.KINDS[k].loadWord)
		if word == "":
			continue
		var m = _rx("^%s:? ?(\\d+(?:[.,]\\d+)?) ?(kg|kgs|lb|lbs)?$" % word).search(t)
		if m != null:
			var unit: String = ctx.wu
			if m.get_string(2) != "":
				unit = "kg" if m.get_string(2).begins_with("k") else "lb"
			return {"word": word, "kg": Fmt.unit_to_kg(float(m.get_string(1).replace(",", ".")), unit)}
	return {}


## Put the carried weight on a misc entry. Below zero means none was written:
## the one used last time is taken (and said so), else none at all.
static func _set_load(e: Dictionary, kind: String, kg: float, ctx: Dictionary) -> void:
	var name: String = str(Misc.meta(kind).loadName).to_lower()
	# The note about a weight that was not written goes when one is.
	if e.has("load_note"):
		e.warnings.erase(e.load_note)
		e.erase("load_note")
	if not Misc.has_field(kind, "load"):
		return
	if kg >= 0.0:
		e.data["loadKg"] = kg
		return
	var usual: float = float(ctx.last_load.get(kind, 0.0))
	if usual > 0.0:
		e.data["loadKg"] = usual
		e["load_note"] = "used your last %s weight (%s); a line \"%s 10\" under it changes it" % [name, Fmt.fmt_weight(usual, ctx.wu), name]
	else:
		e.data.erase("loadKg")
		e["load_note"] = "no %s weight; add a line like \"%s 10\" under it, or edit it after importing" % [name, name]
	e.warnings.append(e.load_note)


## The weight carried, taken out of a misc line: "10kg", "20 lb", "@10kg",
## "with 10 kg", or a bare number that is not the distance (in the player's unit).
## Returns {"kg": float (-1.0 when none is written), "rest": the line without it}.
static func _take_load(rest: String, ctx: Dictionary) -> Dictionary:
	var m = _rx("(?:^| )(?:@ ?|with |w/ ?)?(\\d+(?:\\.\\d+)?) ?(kg|kgs|lb|lbs)\\b(?: vest)?").search(rest)
	if m != null:
		var unit: String = "kg" if m.get_string(2).begins_with("k") else "lb"
		return {"kg": Fmt.unit_to_kg(float(m.get_string(1)), unit), "rest": (rest.substr(0, m.get_start()) + " " + rest.substr(m.get_end())).strip_edges()}
	m = _rx("(?:^| )@ ?(\\d+(?:\\.\\d+)?)(?= |$)").search(rest)
	if m != null:
		return {"kg": Fmt.unit_to_kg(float(m.get_string(1)), ctx.wu), "rest": (rest.substr(0, m.get_start()) + " " + rest.substr(m.get_end())).strip_edges()}
	var toks = _merge_units(_rx("(\\d),(\\d)").sub(rest, "$1.$2", true).replace(",", " "))
	var has_dist = false
	for tok in toks:
		if _rx("^\\d+(?:\\.\\d+)?(?:km|k|mi|mile|miles)$").search(tok) != null:
			has_dist = true
	var bare = []
	for i in range(toks.size()):
		if _rx("^\\d+(?:\\.\\d+)?$").search(toks[i]) == null:
			continue
		var prev = toks[i - 1] if i > 0 else ""
		var nxt = toks[i + 1] if i + 1 < toks.size() else ""
		if ELEV_WORDS.has(prev) or ELEV_WORDS.has(nxt):
			continue
		if _rx("^\\d+(?:\\.\\d+)?(?:h|hr|hrs|hour|hours)$").search(prev) != null:
			continue
		bare.append(i)
	# With a written distance the first bare number is the weight; without one
	# the first is the distance and the second the weight.
	var pick = -1
	if has_dist and bare.size() >= 1:
		pick = bare[0]
	elif not has_dist and bare.size() >= 2:
		pick = bare[1]
	if pick < 0:
		return {"kg": -1.0, "rest": rest}
	var kg = Fmt.unit_to_kg(float(toks[pick]), ctx.wu)
	toks.remove_at(pick)
	return {"kg": kg, "rest": " ".join(PackedStringArray(toks))}


## A misc line after its opening words: distance, time and climb read like a
## run, plus the weight carried.
## Returns {"ok", "why", "distanceM", "elevationM", "durationSec", "loadKg" (-1 = none written), "warnings"}.
static func _parse_misc(kind: String, rest: String, ctx: Dictionary) -> Dictionary:
	var short: String = str(Misc.meta(kind).short).to_lower()
	var example: String = "%s 3km 40:00 10kg" % short
	var carried = {"kg": -1.0, "rest": rest}
	if Misc.has_field(kind, "load"):
		carried = _take_load(rest, ctx)
		if float(carried.kg) > MAX_LOAD_KG:
			return {"ok": false, "why": "that %s weight looks wrong" % str(Misc.meta(kind).loadName).to_lower()}
	var c = _parse_cardio("run " + str(carried.rest), ctx)
	if not c.ok:
		return {"ok": false, "why": str(c.why).replace("run 5.2km 27:30", example)}
	return {"ok": true, "why": "", "distanceM": snappedf(float(c.distRaw), 0.1), "elevationM": snappedf(float(c.elevRaw), 0.01),
		"durationSec": int(c.durationSec), "loadKg": float(carried.kg), "warnings": c.warnings}


# ---------------------------------------------------------------------------
# Pictures the game could read (game/shot_reader.gd)
# ---------------------------------------------------------------------------

## The day a picture's entry belongs to: {"date", "note", "printed", "warn"}.
## A calendar date printed on the picture wins, then the note's own date line,
## then the day the game first saw the picture ("Today" and "Yesterday" on it
## are counted from that day, so the answer does not drift while it waits).
static func shot_date(block: Dictionary, shot: Dictionary, ctx: Dictionary) -> Dictionary:
	var seen = str(shot.get("seen", ctx.today))
	if _rx("^\\d{4}-\\d{2}-\\d{2}$").search(seen) == null or seen > ctx.today:
		seen = ctx.today
	var month = int(shot.get("month", 0))
	if month > 0:
		var year = int(shot.get("year", 0))
		var key = _year_or_last(str(year) if year > 0 else "", month, int(shot.get("day", 0)), seen)
		if key != "" and key <= ctx.today:
			var warn = ""
			if block.header != "" and block.date != key:
				warn = "the picture is dated %s, so it is not on the day written above it" % Dates.format_date(key, {"month": "short", "day": "numeric"})
			return {"date": key, "note": "", "printed": true, "warn": warn}
	if block.header != "":
		return {"date": block.date, "note": block.note, "printed": false, "warn": ""}
	match str(shot.get("rel", "")):
		"today":
			return {"date": seen, "note": SHOT_TODAY, "printed": false, "warn": ""}
		"yesterday":
			return {"date": Dates.add_days(seen, -1), "note": SHOT_YESTERDAY, "printed": false, "warn": ""}
	return {"date": seen, "note": SHOT_NO_DATE, "printed": false, "warn": ""}


## A workout screenshot: its own run or ride.
static func _shot_session(block: Dictionary, ref: String, shot: Dictionary, orig: String, ctx: Dictionary, out: Dictionary) -> void:
	var v = float(shot.get("dist", 0.0))
	var dist = 0.0
	match str(shot.get("distUnit", "")):
		"km":
			dist = v * 1000.0
		"mi":
			dist = v * Fmt.M_PER_MI
		"m":
			dist = v
		"yd":
			dist = v * 0.9144
		_:
			dist = Fmt.unit_to_m(v, ctx.du)
	if dist <= 0.0 or dist > 1000000.0:
		out.problems.append({"line": orig, "why": "the distance on the picture looks wrong", "picture": ref})
		return
	var ev = float(shot.get("elev", 0.0))
	var elev = 0.0
	match str(shot.get("elevUnit", "")):
		"ft":
			elev = ev * FT_TO_M
		"m":
			elev = ev
		_:
			elev = ev * (1.0 if ctx.du == "km" else FT_TO_M)
	# A walk is a misc activity: the vest walk, with the vest worn last time
	# (the picture cannot say; a "vest 10kg" line under it does).
	var walk: bool = str(shot.kind) == "walk"
	var e = _session(block, TT.MISC if walk else str(shot.kind))
	if walk:
		e.data["kind"] = WALK_KIND
	# Kept as exact as the picture: 4.02 mi must still read 4.02 mi afterwards.
	e.data["distanceM"] = snappedf(dist, 0.1)
	e.data["elevationM"] = snappedf(maxf(elev, 0.0), 0.01)
	var sec = int(shot.get("sec", 0))
	if sec > 0:
		e.data["durationSec"] = sec
	var title = str(shot.get("title", "")).strip_edges()
	if title != "":
		e.data["title"] = title
	var extras = []
	for x in shot.get("extras", []):
		extras.append(str(x))
	if not extras.is_empty():
		e.data["notes"] = " · ".join(PackedStringArray(extras))
	var d = shot_date(block, shot, ctx)
	e["date"] = d.date
	e["date_note"] = d.note
	if d.warn != "":
		e.warnings.append(d.warn)
	var tag = "shot %s %dm %ds +%dm" % [str(shot.kind), TTUtil.jsround(dist), sec, TTUtil.jsround(elev)]
	e["shots"] = [ref]
	e["extras"] = extras
	e["shot_tag"] = tag
	if walk:
		_set_load(e, WALK_KIND, -1.0, ctx)
	_take(block, e, orig, tag)


## A weigh-in screenshot: weight and body fat for the day's check-in (its own
## check-in when the picture itself is dated).
static func _shot_body(block: Dictionary, ref: String, shot: Dictionary, orig: String, ctx: Dictionary, out: Dictionary) -> void:
	var kg = -1.0
	if shot.get("weight") != null:
		var unit = str(shot.get("weightUnit", ""))
		kg = Fmt.unit_to_kg(float(shot.weight), unit if unit != "" else ctx.wu)
		if kg < 25.0 or kg > 350.0:
			out.problems.append({"line": orig, "why": "the weight on the picture looks wrong", "picture": ref})
			return
		kg = snappedf(kg, 0.01)
	var fat = -1.0
	if shot.get("fat") != null:
		fat = float(shot.fat)
		if fat < 2.0 or fat > 70.0:
			fat = -1.0
	if kg < 0.0 and fat < 0.0:
		out.problems.append({"line": orig, "why": "no weight could be read from the picture", "picture": ref})
		return
	var d = shot_date(block, shot, ctx)
	var e
	if d.printed:
		e = block.shot_bodies.get(d.date)
		if e == null:
			e = {"kind": "body", "disc": "body", "data": {"date": d.date}, "raw": [], "norm": [], "warnings": [],
				"date": d.date, "date_note": ""}
			block.shot_bodies[d.date] = e
			block.entries.append(e)
	else:
		e = _body_entry(block)
		if not e.has("date"):
			e["date"] = d.date
			e["date_note"] = d.note
	if d.warn != "" and not e.warnings.has(d.warn):
		e.warnings.append(d.warn)
	if kg >= 0.0:
		if e.data.has("weightKg"):
			e.warnings.append("two weights for this day, kept the last")
		e.data["weightKg"] = kg
	if fat >= 0.0:
		if e.data.has("bodyFatPct"):
			e.warnings.append("two body fat readings for this day, kept the last")
		e.data["bodyFatPct"] = fat
	var tag = "shot body %d %d" % [TTUtil.jsround(kg * 100.0), TTUtil.jsround(fat * 10.0)]
	if not e.has("shots"):
		e["shots"] = []
		e["extras"] = []
		e["shot_tag"] = tag
	for x in shot.get("extras", []):
		e.extras.append(str(x))
	if not e.extras.is_empty():
		e.data["note"] = " · ".join(PackedStringArray(e.extras))
	e.shots.append(ref)
	e.raw.append(orig)
	e.norm.append(tag)


# ---------------------------------------------------------------------------
# Dates
# ---------------------------------------------------------------------------

## {"date", "note", "header"} when `t` is a date line, else {}.
static func date_line(t: String, today: String) -> Dictionary:
	var s = t.strip_edges().trim_suffix(":").replace(",", " ").strip_edges()
	s = _rx("\\s+").sub(s, " ", true)
	var lead = _rx(PHOTO_LABEL + "(?= )").search(s)
	if lead != null:
		s = s.substr(lead.get_end()).strip_edges()
	var words = s.split(" ", false)
	if words.is_empty():
		return {}
	var w0 = words[0].trim_suffix(".")
	if words.size() == 1:
		if w0 == "today":
			return {"date": today, "note": "\"today\" = the day you import", "header": s}
		if w0 == "yesterday":
			return {"date": Dates.add_days(today, -1), "note": "\"yesterday\" = the day before you import", "header": s}
		if WEEKDAYS.has(w0):
			var back = (Dates.weekday_index(today) - int(WEEKDAYS[w0]) + 7) % 7
			return {"date": Dates.add_days(today, -back), "note": "\"%s\" = %s, counted back from the day you import" % [w0, WEEKDAY_NAMES[WEEKDAYS[w0]]], "header": s}
	# "sat nov 14": the weekday is decoration.
	var core = s
	if words.size() > 1 and WEEKDAYS.has(w0):
		core = " ".join(words.slice(1))
	var key = _explicit_date(core, today)
	if key == "":
		return {}
	if key == "!":
		return {"invalid": true}
	return {"date": key, "note": "", "header": s}


static func _explicit_date(s: String, today: String) -> String:
	var m = _rx("^(\\d{4})[-/.](\\d{1,2})[-/.](\\d{1,2})$").search(s)
	if m != null:
		return _or_bad(_ymd(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))))
	m = _rx("^(\\d{1,2})/(\\d{1,2})(?:/(\\d{2}|\\d{4}))?$").search(s)
	if m != null:
		var a = int(m.get_string(1))
		var b = int(m.get_string(2))
		# Month/day, unless the first number cannot be a month (14/11 = 14 November).
		var mo = a
		var dy = b
		if a > 12 and b <= 12:
			mo = b
			dy = a
		return _or_bad(_year_or_last(m.get_string(3), mo, dy, today))
	m = _rx("^([a-z]+)\\.? (\\d{1,2})(?:st|nd|rd|th)?(?: (\\d{4}))?$").search(s)
	if m != null and MONTHS.has(m.get_string(1)):
		return _or_bad(_year_or_last(m.get_string(3), int(MONTHS[m.get_string(1)]), int(m.get_string(2)), today))
	m = _rx("^(\\d{1,2})(?:st|nd|rd|th)? (?:of )?([a-z]+)\\.?(?: (\\d{4}))?$").search(s)
	if m != null and MONTHS.has(m.get_string(2)):
		return _or_bad(_year_or_last(m.get_string(3), int(MONTHS[m.get_string(2)]), int(m.get_string(1)), today))
	return ""


## "!" marks a line shaped like a date that does not exist ("feb 30").
static func _or_bad(key: String) -> String:
	return "!" if key == "" else key


## No year written: this year, or last year when that date is still to come.
static func _year_or_last(year_text: String, mo: int, dy: int, today: String) -> String:
	if year_text != "":
		var y = int(year_text)
		if y < 100:
			y += 2000
		return _ymd(y, mo, dy)
	var ty = int(today.substr(0, 4))
	var key = _ymd(ty, mo, dy)
	if key != "" and key > today:
		key = _ymd(ty - 1, mo, dy)
	return key


static func _ymd(y: int, mo: int, dy: int) -> String:
	if y < 1900 or y > 2200 or mo < 1 or mo > 12 or dy < 1:
		return ""
	var dim = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][mo - 1]
	if mo == 2 and ((y % 4 == 0 and y % 100 != 0) or y % 400 == 0):
		dim = 29
	if dy > dim:
		return ""
	return "%04d-%02d-%02d" % [y, mo, dy]


## The date of a form timestamp cell ("11/14/2026 18:32:10", "2026-11-14 18:32"), or "".
static func timestamp_date(cell: String) -> String:
	var s = cell.strip_edges().to_lower()
	var m = _rx("^(\\d{4})-(\\d{1,2})-(\\d{1,2})(?:[ t]\\d{1,2}:\\d{2}.*)?$").search(s)
	if m != null:
		return _ymd(int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)))
	m = _rx("^(\\d{1,2})([/.])(\\d{1,2})[/.](\\d{4})(?:[ ,]+\\d{1,2}:\\d{2}(?::\\d{2})?(?: ?[ap]m)?)?$").search(s)
	if m != null:
		var a = int(m.get_string(1))
		var b = int(m.get_string(3))
		# Sheets in US locale write M/D/YYYY; dotted dates (and a first number over 12) are day first.
		if m.get_string(2) == "." or (a > 12 and b <= 12):
			return _ymd(int(m.get_string(4)), b, a)
		return _ymd(int(m.get_string(4)), a, b)
	return ""


# ---------------------------------------------------------------------------
# Lifting
# ---------------------------------------------------------------------------

static func _parse_lift(t: String, ctx: Dictionary) -> Dictionary:
	var toks = t.split(" ", false)
	var i = 0
	while i < toks.size() and _rx("^(?:[\\d@+]|x\\d)").search(toks[i]) == null:
		i += 1
	var words = []
	for w in toks.slice(0, i):
		var c = w.trim_suffix(":").trim_suffix("-")
		if c != "" and c != "-" and c != "=":
			words.append(c)
	var typed = " ".join(PackedStringArray(words))
	if i >= toks.size():
		return {"ok": false, "why": "not a date, workout or check-in I know"}
	if _rx("[a-z]").search(typed) == null:
		return {"ok": false, "why": "no exercise name before the sets"}
	var name = resolve_exercise(typed, ctx)
	var spec = " ".join(toks.slice(i))
	var p = parse_sets(spec, ctx.wu)
	if not p.ok:
		return {"ok": false, "why": p.why}
	var warnings = []
	var sets = []
	if p.bare:
		if is_loaded(name, ctx):
			if p.ab.size() == 2 and int(p.ab[1]) > 30:
				sets.append({"reps": int(p.ab[0]), "weightKg": Fmt.unit_to_kg(float(p.ab[1]), ctx.wu)})
				warnings.append("%s: read as %d reps at %d %s" % [name, int(p.ab[0]), int(p.ab[1]), ctx.wu])
			else:
				warnings.append("%s: no weight given, saved as bodyweight" % name)
		if sets.is_empty():
			for r in p.reps:
				sets.append({"reps": int(r), "weightKg": 0})
	else:
		sets = p.sets
	for st in sets:
		if int(st.reps) < 1 or int(st.reps) > 200:
			return {"ok": false, "why": "%d reps looks wrong" % int(st.reps)}
		if float(st.weightKg) > 600.0:
			return {"ok": false, "why": "that weight looks wrong"}
	if sets.size() > 40:
		return {"ok": false, "why": "too many sets"}
	return {"ok": true, "name": name, "sets": sets, "warnings": warnings}


## The sets part of a lifting line. Returns {"ok", "why", "sets": [{reps, weightKg}],
## "bare": true when no weight was written anywhere, "reps": [...] then, "ab": [A, B] for a lone AxB}.
static func parse_sets(spec: String, wu: String) -> Dictionary:
	var s = " " + spec + " "
	s = _rx("\\bat\\s+(?=[+\\d]|bw\\b)").sub(s, "@ ", true)
	# "@ 82,5" is 82.5, but "5 @ 100, 5 @ 105" / "@ 100,5,5" keep their commas.
	s = _rx("@\\s*(\\+?\\d+),(\\d{1,2})(?![\\d.,])(?!\\s*(?:@|x))").sub(s, "@ $1.$2", true)
	s = _rx("\\s*@\\s*").sub(s, " @ ", true)
	s = _rx("\\s*,\\s*").sub(s, ",", true)
	s = _rx("(\\d)\\s+(kg|lbs|lb)\\b").sub(s, "$1$2", true)
	s = _rx("(\\d)\\s*x\\s*(?=\\d)").sub(s, "$1x", true)
	s = _rx("(kg|lbs|lb)x(?=\\d)").sub(s, "$1 x", true)
	s = _rx("(?<![\\d.a-z])x\\s+(?=\\d)").sub(s, "x", true)
	var items = []
	for g in s.strip_edges().split(",", false):
		var toks = Array(g.strip_edges().split(" ", false))
		if toks.is_empty():
			continue
		var item = {"reps": [], "w": null, "ab": []}
		var left = toks
		var at = toks.find("@")
		if at >= 0:
			left = toks.slice(0, at)
			var right = toks.slice(at + 1)
			if right.size() != 1 or weight_token(right[0], wu, true) < 0.0:
				return {"ok": false, "why": "could not read the weight in \"%s\"" % g.strip_edges()}
			item.w = weight_token(right[0], wu, true)
		elif weight_token(toks[0], wu, false) >= 0.0:
			# Weight first: "80kg x5" (5 reps), "80kg x5 x3" (5 reps, 3 sets), "100kg 3x5".
			item.w = weight_token(toks[0], wu, false)
			var rest = "".join(PackedStringArray(toks.slice(1)))
			var m = _rx("^x(\\d+)(?:x(\\d+))?$").search(rest)
			var m2 = _rx("^(\\d+)x(\\d+)$").search(rest)
			if m != null:
				var n_sets = int(m.get_string(2)) if m.get_string(2) != "" else 1
				for k in range(n_sets):
					item.reps.append(int(m.get_string(1)))
			elif m2 != null:
				for k in range(int(m2.get_string(1))):
					item.reps.append(int(m2.get_string(2)))
			elif _rx("^\\d+$").search(rest) != null:
				item.reps.append(int(rest))
			else:
				return {"ok": false, "why": "could not read the reps in \"%s\"" % g.strip_edges()}
			items.append(item)
			continue
		elif _rx("^x\\d+(?:x\\d+)*$").search(toks[0]) != null:
			# Reps first, one set per line: "x5 135" (5 reps at 135), "x8" (bodyweight),
			# "x5 x5 x4 80" (three sets, last number is the weight).
			left = []
			for tok in toks:
				var mx = _rx("^x(\\d+(?:x\\d+)*)$").search(tok)
				if mx != null and item.w == null:
					left.append_array(Array(mx.get_string(1).split("x", false)))
				elif item.w == null and tok == toks[toks.size() - 1] and weight_token(tok, wu, true) >= 0.0:
					item.w = weight_token(tok, wu, true)
				else:
					return {"ok": false, "why": "could not read \"%s\" (try x5 135 or 3x5 @ 80)" % g.strip_edges()}
		elif toks.size() > 1 and weight_token(toks[toks.size() - 1], wu, false) >= 0.0:
			item.w = weight_token(toks[toks.size() - 1], wu, false)
			left = toks.slice(0, toks.size() - 1)
		if left.is_empty():
			return {"ok": false, "why": "no reps before the weight in \"%s\"" % g.strip_edges()}
		var ab = _rx("^(\\d+)x(\\d+)$").search(left[0]) if left.size() == 1 else null
		if ab != null:
			item.ab = [int(ab.get_string(1)), int(ab.get_string(2))]
			for k in range(int(ab.get_string(1))):
				item.reps.append(int(ab.get_string(2)))
		else:
			for tok in left:
				if _rx("^\\d+$").search(tok) == null:
					return {"ok": false, "why": "could not read \"%s\" (try 3x5 @ 80)" % g.strip_edges()}
				item.reps.append(int(tok))
		items.append(item)
	if items.is_empty():
		return {"ok": false, "why": "no sets found"}
	var sets = []
	var pending = []
	var last_w = null
	for it in items:
		if it.w == null:
			pending.append_array(it.reps)
		else:
			for r in pending + it.reps:
				sets.append({"reps": int(r), "weightKg": it.w})
			pending = []
			last_w = it.w
	if last_w == null:
		var lone = items[0].ab if items.size() == 1 else []
		return {"ok": true, "bare": true, "reps": pending, "ab": lone, "sets": []}
	for r in pending:
		sets.append({"reps": int(r), "weightKg": last_w})
	return {"ok": true, "bare": false, "reps": [], "ab": [], "sets": sets}


## "80", "+10", "82.5kg", "181lb", "bw" -> kg; -1 when it is not a weight (or has no unit and one is required).
static func weight_token(tok: String, wu: String, unit_optional: bool) -> float:
	if unit_optional and (tok == "bw" or tok == "bodyweight"):
		return 0.0
	var m = _rx("^\\+?(\\d+(?:\\.\\d+)?)(kg|lbs|lb)?$").search(tok)
	if m == null:
		return -1.0
	var u = m.get_string(2)
	if u == "" and not unit_optional:
		return -1.0
	var unit = wu if u == "" else ("kg" if u == "kg" else "lb")
	return Fmt.unit_to_kg(float(m.get_string(1)), unit)


static func _compact(s: String) -> String:
	return s.replace(" ", "").replace("-", "").replace("_", "")


## Typed name -> a known exercise name where possible, else the typed name in Title Case.
static func resolve_exercise(typed: String, ctx: Dictionary) -> String:
	var n = Xp.normalize_exercise(typed)
	if ctx.known_norm.has(n):
		return ctx.known_norm[n]
	var c = _compact(n)
	if ALIASES.has(c):
		return ALIASES[c]
	var singular = c.trim_suffix("s") if c.length() > 3 else c
	for k in ctx.known_norm:
		var kc = _compact(k)
		if kc == c or kc == singular:
			return ctx.known_norm[k]
	if n.length() >= 3:
		var hits = []
		for k in ctx.known_norm:
			if k.begins_with(n):
				hits.append(ctx.known_norm[k])
		if hits.size() == 1:
			return hits[0]
	var out = []
	for w in n.split(" ", false):
		out.append(w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(PackedStringArray(out))


static func is_loaded(name: String, ctx: Dictionary) -> bool:
	var n = Xp.normalize_exercise(name)
	if ctx.loaded.has(n):
		return true
	for w in LOADED_WORDS:
		if n.contains(w):
			return true
	return false


# ---------------------------------------------------------------------------
# Climbing
# ---------------------------------------------------------------------------

static func _parse_climb(t: String) -> Dictionary:
	var s = t.replace("top rope", "toprope").replace("top-rope", "toprope")
	var toks = s.split(" ", false)
	while not toks.is_empty() and (CLIMB_WORDS.has(toks[0].trim_suffix(":")) or ROPE_WORDS.has(toks[0].trim_suffix(":"))):
		toks = toks.slice(1)
	s = " ".join(toks)
	s = s.replace(";", ",").replace(" and ", ",")
	var climbs = []
	var bad = []
	for item in s.split(",", false):
		var it = item.strip_edges()
		if it == "":
			continue
		it = _rx("(vb|v\\d{1,2})(?=[a-z])").sub(it, "$1 ", true)
		it = _rx("(\\d)x(?=v|5\\.)").sub(it, "$1x ", true)
		it = _rx("\\bx\\s+(?=\\d)").sub(it, "x", true)
		it = _rx("(\\d)\\s+x\\b").sub(it, "$1x", true)
		var grade = null
		var yds = ""
		var count = 1
		var result = "send"
		var ok = true
		for tok in it.split(" ", false):
			var mg = _rx("^v(\\d{1,2})$").search(tok)
			var my = _rx("^5\\.\\d{1,2}[a-d]?$").search(tok)
			var mc = _rx("^(?:x(\\d+)|(\\d+)x)$").search(tok)
			if tok == "vb" and grade == null:
				grade = -1
			elif mg != null and grade == null and int(mg.get_string(1)) <= 17:
				grade = int(mg.get_string(1))
			elif my != null and grade == null and Xp.yds_index(tok) >= 0:
				yds = Xp.yds_label(Xp.yds_index(tok))
				grade = Xp.yds_to_v(Xp.yds_index(tok))
			elif mc != null:
				count = int(mc.get_string(1) if mc.get_string(1) != "" else mc.get_string(2))
			elif _rx("^\\d+$").search(tok) != null:
				count = int(tok)
			elif RESULT_WORDS.has(tok):
				result = RESULT_WORDS[tok]
			elif ROPE_WORDS.has(tok):
				pass
			else:
				ok = false
		if grade == null or not ok or count < 1 or count > 99:
			bad.append(item.strip_edges())
		elif yds != "":
			climbs.append({"grade": grade, "result": result, "count": count, "style": "rope", "yds": yds})
		else:
			climbs.append({"grade": grade, "result": result, "count": count})
	return {"climbs": climbs, "bad": bad}


## "hang 20mm 10s x6", "one arm hang 15mm 7s x3 +10", "hangboard 10mm 10s x4 -20lb"
## (assisted), "hang jug 20s x3". Edge defaults to 20 mm, arms to both; a second
## hang on the same line ("hang 20mm 10s x6, 15mm 7s x3") keeps the edge / arms
## of the one before it. Returns {"hangs": [{edgeMm, sec, arms, addKg, count}], "bad": [...]}.
static func _parse_hang(t: String, wu: String) -> Dictionary:
	var s = " " + t + " "
	for w in ["single arm", "one arm", "1 arm", "one-arm", "single-arm", "onearm"]:
		s = s.replace(w, " onearm ")
	for w in ["two arms", "two arm", "both arms", "2 arm", "2 arms", "two-arm"]:
		s = s.replace(w, " twoarms ")
	s = s.replace("dead hang", "deadhang")
	s = _rx("(\\d)\\s+(mm|s|sec|secs|second|seconds|kg|lb|lbs)\\b").sub(s, "$1$2", true)
	s = _rx("\\bx\\s+(?=\\d)").sub(s, "x", true)
	s = _rx("(\\d)\\s+x\\b").sub(s, "$1x", true)
	s = _rx("([+-])\\s+(?=\\d)").sub(s, "$1", true)
	s = s.replace(";", ",").replace(" and ", ",")
	var hangs = []
	var bad = []
	var line_arms = 2
	var line_edge = -1
	for item in s.split(",", false):
		var it = item.strip_edges()
		if it == "":
			continue
		var h = {"edgeMm": -1, "sec": -1, "arms": 0, "addKg": 0.0, "count": 1}
		var ok = true
		for tok in it.split(" ", false):
			if HANG_WORDS.has(tok) or FILLER.has(tok) or tok == "on" or tok == "edge" or tok == "bw" or tok == "bodyweight":
				continue
			if tok == "onearm":
				h.arms = 1
				continue
			if tok == "twoarms":
				h.arms = 2
				continue
			if tok == "jug" or tok == "jugs" or tok == "bar":
				h.edgeMm = 0
				continue
			var mm = _rx("^(\\d+)mm$").search(tok)
			var ms = _rx("^(\\d+)(?:s|sec|secs|second|seconds)$").search(tok)
			var mc = _rx("^(?:x(\\d+)|(\\d+)x)$").search(tok)
			var mw = _rx("^([+-])(\\d+(?:\\.\\d+)?)(kg|lb|lbs)?$").search(tok)
			if mm != null:
				h.edgeMm = int(mm.get_string(1))
			elif ms != null:
				h.sec = int(ms.get_string(1))
			elif mc != null:
				h.count = int(mc.get_string(1) if mc.get_string(1) != "" else mc.get_string(2))
			elif mw != null:
				var unit = wu if mw.get_string(3) == "" else ("kg" if mw.get_string(3) == "kg" else "lb")
				var kg = Fmt.unit_to_kg(float(mw.get_string(2)), unit)
				h.addKg = -kg if mw.get_string(1) == "-" else kg
			else:
				ok = false
		if int(h.edgeMm) < 0:
			h.edgeMm = line_edge if line_edge >= 0 else 20
		else:
			line_edge = int(h.edgeMm)
		if int(h.arms) == 0:
			h.arms = line_arms
		else:
			line_arms = int(h.arms)
		if not ok or int(h.sec) <= 0 or int(h.sec) > 600 or int(h.count) < 1 or int(h.count) > 99 or int(h.edgeMm) > 100:
			bad.append(item.strip_edges())
		else:
			hangs.append(h)
	return {"hangs": hangs, "bad": bad}


# ---------------------------------------------------------------------------
# Running / cycling and times
# ---------------------------------------------------------------------------

## A single time token -> seconds, or -1. `hm_colon`: read "1:10" as h:mm (durations) instead of mm:ss.
static func time_token(tok: String, hm_colon: bool = false) -> int:
	var m = _rx("^(\\d+):(\\d{2}):(\\d{2})$").search(tok)
	if m != null:
		return int(m.get_string(1)) * 3600 + int(m.get_string(2)) * 60 + int(m.get_string(3))
	m = _rx("^(\\d+):(\\d{2})$").search(tok)
	if m != null:
		if hm_colon and int(m.get_string(1)) <= 4:
			return int(m.get_string(1)) * 3600 + int(m.get_string(2)) * 60
		return int(m.get_string(1)) * 60 + int(m.get_string(2))
	m = _rx("^(\\d+(?:\\.\\d+)?)(?:h|hr|hrs|hour|hours)$").search(tok)
	if m != null:
		return TTUtil.jsround(float(m.get_string(1)) * 3600.0)
	m = _rx("^(\\d+)h(\\d+)(?:m|min)?$").search(tok)
	if m != null:
		return int(m.get_string(1)) * 3600 + int(m.get_string(2)) * 60
	m = _rx("^(\\d+(?:\\.\\d+)?)(?:min|mins|minute|minutes)$").search(tok)
	if m != null:
		return TTUtil.jsround(float(m.get_string(1)) * 60.0)
	m = _rx("^(\\d+)(?:s|sec|secs)$").search(tok)
	if m != null:
		return int(m.get_string(1))
	return -1


## Number + separate unit word become one token ("5.2 km" -> "5.2km", "+ 80" -> "+80").
static func _merge_units(s: String) -> Array:
	var toks = Array(s.split(" ", false))
	var out = []
	var i = 0
	while i < toks.size():
		var tok = toks[i]
		if tok == "+" and i + 1 < toks.size():
			i += 1
			tok = "+" + toks[i]
		if i + 1 < toks.size() and _rx("^\\+?\\d+(?:\\.\\d+)?$").search(tok) != null and UNIT_WORDS.has(toks[i + 1]):
			i += 1
			tok += toks[i]
		out.append(tok)
		i += 1
	return out


## "70min", "1h10", "1h 10m", "1:10", "90" (minutes) -> seconds, or 0.
static func parse_duration(text: String) -> int:
	var total = 0
	for tok in _merge_units(text.strip_edges()):
		if FILLER.has(tok):
			continue
		var sec = time_token(tok, true)
		var mm = _rx("^(\\d+)m$").search(tok)
		if sec >= 0:
			total += sec
		elif mm != null:
			total += int(mm.get_string(1)) * 60
		elif _rx("^\\d+$").search(tok) != null:
			total += int(tok) * 60
		else:
			return 0
	return total


static func _parse_cardio(t: String, ctx: Dictionary) -> Dictionary:
	var s = _rx("(\\d),(\\d)").sub(t, "$1.$2", true).replace(",", " ")
	var toks = _merge_units(s)
	var disc = CARDIO_WORDS[toks[0].trim_suffix(":")]
	toks = toks.slice(1)
	var dist = -1.0
	var secs = -1
	var elev = -1.0
	var hours_only = false  # the previous token was "1h": a following "30m" / "30" is minutes
	var ignored = []
	var elev_unit_m = 1.0 if ctx.du == "km" else FT_TO_M
	for i in range(toks.size()):
		var tok = toks[i]
		var prev = toks[i - 1] if i > 0 else ""
		var nxt = toks[i + 1] if i + 1 < toks.size() else ""
		var was_hours = hours_only
		hours_only = false
		if FILLER.has(tok) or ELEV_WORDS.has(tok):
			continue
		var near_elev = ELEV_WORDS.has(nxt) or ELEV_WORDS.has(prev)
		var m = _rx("^\\+(\\d+(?:\\.\\d+)?)(m|ft|feet)?$").search(tok)
		if m != null:
			var u = m.get_string(2)
			elev = float(m.get_string(1)) * (1.0 if u == "m" else (FT_TO_M if u != "" else elev_unit_m))
			continue
		m = _rx("^(\\d+(?:\\.\\d+)?)(?:ft|feet)$").search(tok)
		if m != null:
			elev = float(m.get_string(1)) * FT_TO_M
			continue
		m = _rx("^(\\d+(?:\\.\\d+)?)(?:m|meters|metres)$").search(tok)
		if m != null:
			var v = float(m.get_string(1))
			if near_elev:
				elev = v
			elif was_hours:
				secs += TTUtil.jsround(v * 60.0)
			elif dist < 0.0 and v >= 100.0:
				# "run 400m", "ride 5000m": a distance in metres, not 400 minutes.
				dist = v
			elif secs < 0:
				secs = TTUtil.jsround(v * 60.0)
			else:
				elev = v
			continue
		m = _rx("^(\\d+(?:\\.\\d+)?)(km|k|mi|mile|miles)$").search(tok)
		if m != null:
			dist = Fmt.unit_to_m(float(m.get_string(1)), "km" if m.get_string(2) == "km" or m.get_string(2) == "k" else "mi")
			continue
		if _rx("^\\d+(?:\\.\\d+)?$").search(tok) != null:
			var v = float(tok)
			if near_elev:
				elev = v * elev_unit_m
			elif was_hours:
				secs += TTUtil.jsround(v * 60.0)
			elif dist < 0.0:
				dist = Fmt.unit_to_m(v, ctx.du)
			else:
				ignored.append(tok)
			continue
		var sec = time_token(tok)
		if sec >= 0:
			if secs < 0:
				secs = sec
			else:
				secs += sec
			hours_only = _rx("^\\d+(?:\\.\\d+)?(?:h|hr|hrs|hour|hours)$").search(tok) != null
			continue
		ignored.append(tok)
	if dist <= 0.0:
		return {"ok": false, "why": "no distance found (try %s 5.2km 27:30)" % disc}
	if dist > 1000000.0:
		return {"ok": false, "why": "that distance looks wrong"}
	var warnings = []
	if not ignored.is_empty():
		warnings.append("ignored \"%s\"" % " ".join(PackedStringArray(ignored)))
	return {"ok": true, "disc": disc, "distanceM": TTUtil.jsround(dist), "elevationM": TTUtil.jsround(maxf(elev, 0.0)),
		"durationSec": maxi(secs, 0), "warnings": warnings, "distRaw": dist, "elevRaw": maxf(elev, 0.0)}


# ---------------------------------------------------------------------------
# Body check-ins
# ---------------------------------------------------------------------------

static func _parse_body(t: String, ctx: Dictionary) -> Dictionary:
	var s = _rx("(\\d),(\\d)").sub(t, "$1.$2", true)
	s = s.replace("body fat", "bf").replace("bodyfat", "bf").replace("body weight", "weight").replace("bodyweight", "weight")
	s = s.replace("%", " ").replace(":", " ").replace("=", " ")
	s = _rx("(\\d)(kg|lbs|lb)\\b").sub(s, "$1 $2", true)
	var want = ""
	var w = -1.0
	var w_unit = ctx.wu
	var bf = -1.0
	for tok in s.split(" ", false):
		if ["weight", "bw", "weighed", "weigh", "wt"].has(tok):
			want = "w"
		elif tok == "bf" or tok == "fat":
			want = "bf"
		elif ["in", "at", "was", "of", "-"].has(tok):
			continue
		elif tok == "kg" or tok == "lb" or tok == "lbs":
			w_unit = "kg" if tok == "kg" else "lb"
		elif tok.is_valid_float():
			if want == "w":
				w = float(tok)
			elif want == "bf":
				bf = float(tok)
			else:
				return {"ok": false, "why": "is %s a weight or body fat?" % tok}
			want = ""
		else:
			return {"ok": false, "why": "could not read \"%s\" (try weight 82.4 bf 18)" % tok}
	var out = {"ok": true}
	if w >= 0.0:
		var kg = Fmt.unit_to_kg(w, w_unit)
		if kg < 25.0 or kg > 350.0:
			return {"ok": false, "why": "that weight looks wrong"}
		out["weightKg"] = snappedf(kg, 0.01)
	if bf >= 0.0:
		if bf < 2.0 or bf > 70.0:
			return {"ok": false, "why": "that body fat looks wrong"}
		out["bodyFatPct"] = bf
	if out.size() == 1:
		return {"ok": false, "why": "no number found (try weight 82.4 bf 18)"}
	return out


# ---------------------------------------------------------------------------
# One readable line per entry
# ---------------------------------------------------------------------------

static func _w(kg: float, unit: String) -> String:
	return "%s %s" % [Fmt.fmt_num(snappedf(Fmt.kg_to_unit(kg, unit), 0.1), 1), unit]


static func sets_text(sets: Array, unit: String) -> String:
	var groups = []
	for st in sets:
		var w = float(st.weightKg)
		if groups.is_empty() or not is_equal_approx(float(groups[groups.size() - 1].w), w):
			groups.append({"w": w, "reps": []})
		groups[groups.size() - 1].reps.append(int(st.reps))
	var parts = []
	for g in groups:
		var same = true
		for r in g.reps:
			if r != g.reps[0]:
				same = false
		var txt = ""
		if g.reps.size() > 1 and same:
			txt = "%d×%d" % [g.reps.size(), g.reps[0]]
		else:
			var rs = []
			for r in g.reps:
				rs.append(str(r))
			txt = ",".join(PackedStringArray(rs))
		if g.w > 0.0:
			txt += " @ " + _w(g.w, unit)
		parts.append(txt)
	return ", ".join(PackedStringArray(parts))


static func summary(kind: String, data: Dictionary, wu: String, du: String) -> String:
	var parts = []
	if kind == "body":
		if data.has("weightKg"):
			parts.append("Weight " + Fmt.fmt_weight(float(data.weightKg), wu))
		if data.has("bodyFatPct"):
			parts.append("body fat %s%%" % TTUtil.num_str(snappedf(float(data.bodyFatPct), 0.1)))
		var n = data.get("photoRefs", []).size()
		if n > 0:
			parts.append("%d progress photo%s" % [n, "" if n == 1 else "s"])
		return " · ".join(PackedStringArray(parts))
	match str(data.discipline):
		"lift":
			for ex in data.exercises:
				parts.append("%s %s" % [ex.name, sets_text(ex.sets, wu)])
		"climb":
			for c in data.climbs:
				var g = Xp.climb_label(c) + (" TR" if Xp.is_route(c) else "")
				parts.append("%s %s%s" % [g, c.result, (" ×%d" % int(c.count)) if int(c.count) > 1 else ""])
			for h in data.get("hangs", []):
				parts.append("Hang " + Xp.hang_text(h, wu))
		"misc":
			var mk = str(data.get("kind", ""))
			var mhead = str(Misc.meta(mk).short)
			if Misc.has_field(mk, "distance"):
				mhead += " " + Fmt.fmt_distance(float(data.get("distanceM", 0.0)), du, 2)
			parts.append(mhead)
		_:
			var head = "Run " if data.discipline == "run" else "Ride "
			parts.append(head + Fmt.fmt_distance(float(data.distanceM), du, 2))
	var timed = data.discipline == "run" or data.discipline == "ride" or data.discipline == "misc"
	if data.get("durationSec") != null and int(data.durationSec) > 0:
		if timed:
			parts.append(Fmt.fmt_duration(float(data.durationSec)))
		else:
			parts.append(Fmt.fmt_duration_short(float(data.durationSec)))
	if data.discipline == "misc" and float(data.get("loadKg", 0.0)) > 0.0:
		parts.append(Misc.load_text(data.get("kind"), float(data.loadKg), wu))
	if timed and float(data.get("elevationM", 0)) >= 0.5:
		parts.append(Fmt.fmt_elevation(float(data.elevationM), du) + " up")
	var text = " · ".join(PackedStringArray(parts))
	if data.get("title") != null:
		text = "%s: %s" % [data.title, text]
	if data.get("notes") != null:
		text += " (\"%s\")" % str(data.notes).replace("\n", " / ")
	return text


# ---------------------------------------------------------------------------
# CSV (RFC 4180: quoted fields may hold commas, quotes and newlines)
# ---------------------------------------------------------------------------

static func csv_rows(text: String) -> Array:
	var rows = []
	var row = []
	var field = ""
	var quoted = false
	var i = 0
	var n = text.length()
	while i < n:
		var ch = text[i]
		if quoted:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					quoted = false
			else:
				field += ch
		elif ch == "\"":
			quoted = true
		elif ch == ",":
			row.append(field)
			field = ""
		elif ch == "\n" or ch == "\r":
			if ch == "\r" and i + 1 < n and text[i + 1] == "\n":
				i += 1
			row.append(field)
			rows.append(row)
			row = []
			field = ""
		else:
			field += ch
		i += 1
	if field != "" or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows
