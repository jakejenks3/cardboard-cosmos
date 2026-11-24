class_name SaveMerge
extends RefCounted
## Two copies of the save that both changed since they last agreed (the PC and
## the phone, through the note's script: app/cloud_sync.gd) put back together,
## pure and from three copies: `base` (the last copy both had), `mine` and
## `theirs`. Nothing anybody logged is lost:
##
##   - lists of records with an `id` (sessions, check-ins, claims, purchases,
##     projects, to-dos) are merged record by record: one added on either side is kept;
##     one deleted on one side and left alone on the other goes; one deleted on
##     one side and changed on the other is KEPT (a change outweighs a delete);
##     one changed on both sides takes the side whose save is newer;
##   - pages read (`reading`, one entry a day) are merged by day, adding what
##     each side added (10 pages here and 20 there make 30);
##   - everything else (settings, physical therapy marks, the phone note's
##     state, the look) key by key: what one side changed wins over the other's
##     unchanged value; changed on both sides, the newer save wins; a key
##     removed on one side and untouched on the other goes;
##   - `updatedAt` is the later of the two.
##
## All three should be plain JSON data (numbers as JSON gives them); `merge`
## turns them into that first, so 3 and 3.0 are the same.

## Lists of records merged by their `id`.
const RECORD_LISTS = ["sessions", "body", "claims", "purchases", "projects", "todos", "books"]

## Stands for "not there" while comparing.
const NONE = "§tiny-titan:none§"


## The merged save. `prefer_theirs`: which side wins where both changed the same
## thing (null: the side with the newer `updatedAt`, theirs on a tie).
static func merge(base, mine, theirs, prefer_theirs = null) -> Dictionary:
	var b = plain(base if base is Dictionary else {})
	var m = plain(mine if mine is Dictionary else {})
	var t = plain(theirs if theirs is Dictionary else {})
	var pt = prefer_theirs
	if pt == null:
		pt = float(t.get("updatedAt", 0)) >= float(m.get("updatedAt", 0))
	var out = {}
	var keys = {}
	for d in [b, m, t]:
		for k in d:
			keys[k] = true
	for k in keys:
		var v
		if k == "updatedAt":
			v = maxf(float(m.get(k, 0)), float(t.get(k, 0)))
		elif RECORD_LISTS.has(k):
			v = _records(b.get(k, []), m.get(k, []), t.get(k, []), bool(pt))
		elif k == "reading":
			v = _reading(b.get(k, []), m.get(k, []), t.get(k, []), bool(pt))
		else:
			v = _value(b.get(k, NONE), m.get(k, NONE), t.get(k, NONE), bool(pt))
		if not _is_none(v):
			out[k] = v
	return out


## Plain JSON data: what JSON would give back (so 3 and 3.0 compare equal).
static func plain(v):
	return JSON.parse_string(JSON.stringify(v))


## Two values the same, as JSON (keys sorted, so key order does not count).
static func same(a, b) -> bool:
	if _is_none(a) or _is_none(b):
		return _is_none(a) and _is_none(b)
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


static func _is_none(v) -> bool:
	return v is String and v == NONE


## One value, three ways: a dictionary key by key, anything else as a whole.
static func _value(b, m, t, prefer_theirs: bool):
	if same(m, t):
		return m
	if same(m, b):
		return t
	if same(t, b):
		return m
	if m is Dictionary and t is Dictionary:
		var bd = b if b is Dictionary else {}
		var out = {}
		var keys = {}
		for d in [bd, m, t]:
			for k in d:
				keys[k] = true
		for k in keys:
			var v = _value(bd.get(k, NONE), m.get(k, NONE), t.get(k, NONE), prefer_theirs)
			if not _is_none(v):
				out[k] = v
		return out
	# Changed on both sides, in different ways. A change outweighs a removal.
	if _is_none(m):
		return t
	if _is_none(t):
		return m
	return t if prefer_theirs else m


static func _by_id(list) -> Dictionary:
	var out = {}
	if list is Array:
		for r in list:
			if r is Dictionary and r.has("id"):
				out[str(r.id)] = r
	return out


## Records merged by id, in their order on the winning side, the other side's
## new ones after them.
static func _records(b, m, t, prefer_theirs: bool) -> Array:
	var bi = _by_id(b)
	var mi = _by_id(m)
	var ti = _by_id(t)
	var order = []
	var seen = {}
	var first = t if prefer_theirs else m
	var second = m if prefer_theirs else t
	for list in [first, second]:
		if list is Array:
			for r in list:
				if r is Dictionary and r.has("id") and not seen.has(str(r.id)):
					seen[str(r.id)] = true
					order.append(str(r.id))
	var out = []
	for id in order:
		var v = _value(bi.get(id, NONE), mi.get(id, NONE), ti.get(id, NONE), prefer_theirs)
		if not _is_none(v):
			out.append(v)
	return out


## Pages read, one entry a day: what each side added to a day is added up.
static func _reading(b, m, t, prefer_theirs: bool) -> Array:
	var bd = _by_date(b)
	var md = _by_date(m)
	var td = _by_date(t)
	var days = {}
	for d in [bd, md, td]:
		for k in d:
			days[k] = true
	var keys = days.keys()
	keys.sort()
	var out = []
	for day in keys:
		var eb = bd.get(day)
		var em = md.get(day)
		var et = td.get(day)
		var pb = float(eb.get("pages", 0)) if eb != null else 0.0
		var pm = float(em.get("pages", 0)) if em != null else 0.0
		var pt = float(et.get("pages", 0)) if et != null else 0.0
		# A day deleted on one side and untouched on the other goes.
		if em == null and et != null and eb != null and same(et, eb):
			continue
		if et == null and em != null and eb != null and same(em, eb):
			continue
		if em == null and et == null:
			continue
		var entry = _value(eb if eb != null else NONE, em if em != null else NONE, et if et != null else NONE, prefer_theirs)
		if _is_none(entry):
			continue
		entry = entry.duplicate(true)
		entry["pages"] = maxf(0.0, pm + pt - pb) if em != null and et != null else (pm if et == null else pt)
		out.append(entry)
	return out


static func _by_date(list) -> Dictionary:
	var out = {}
	if list is Array:
		for r in list:
			if r is Dictionary and str(r.get("date", "")) != "":
				out[str(r.date)] = r
	return out
