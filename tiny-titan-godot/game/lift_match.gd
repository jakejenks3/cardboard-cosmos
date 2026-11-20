class_name LiftMatch
extends RefCounted
## Which lift a typed name means, when it is not exactly one the player has.
##
## Names are compared by their WORDS, not their letters: order, dashes, commas,
## plurals, short forms ("db", "1UE", "pulley") and a one-letter typo do not
## count, and a word that only says what a library lift already is ("chest fly
## - cable" for Cable Fly) is not held against it.
##
##   LiftMatch.find(typed, known)      -> [{name, score, own}], best first
##   LiftMatch.library_name(typed)     -> the library's own name for it, or ""
##   LiftMatch.same_lift(name, own)    -> the player's name for that library lift, or ""
##   LiftMatch.key(typed)              -> what a decision about a typed name is filed under
##
## A score of SAME or more means the same words (taken as the same lift); CLOSE
## or more is worth offering as "closest". The phone note uses it
## (QuickLog.pick_exercise), and the review sheet lets the player say yes, no
## or pick another. Pure logic, no scene and no autoload: tests/lift_match_test.gd.

## The same words: taken as the same lift.
const SAME = 0.95
## Enough words in common to offer it as the closest one.
const CLOSE = 0.5
## What is left of a score when the typed name says other equipment than the lift uses.
const WRONG_GEAR = 0.6

## Words that say nothing about which lift it is.
const STOP = ["with", "and", "the", "a", "an", "on", "in", "of", "at", "to", "for", "using", "w", "attachment",
	"home", "my", "grip", "style", "variation", "version"]

## Short forms and other spellings, and the words they stand for.
const WORDS = {
	"db": ["dumbbell"], "dbs": ["dumbbell"], "dumbell": ["dumbbell"], "dumbells": ["dumbbell"],
	"bb": ["barbell"], "kb": ["kettlebell"], "kbs": ["kettlebell"], "bw": ["bodyweight"],
	"oh": ["overhead"], "ohp": ["overhead", "press"],
	"rdl": ["romanian", "deadlift"], "rdls": ["romanian", "deadlift"], "sldl": ["stiff", "leg", "deadlift"],
	"sa": ["single", "arm"], "sl": ["single", "leg"], "1ue": ["single", "arm"], "1le": ["single", "leg"],
	"unilateral": ["single"],
	"pulley": ["cable"], "pulleys": ["cable"], "banded": ["band"],
	"tri": ["tricep"], "tris": ["tricep"], "bis": ["bicep"],
	"ext": ["extension"], "exts": ["extension"],
	"rev": ["reverse"], "inc": ["incline"], "dec": ["decline"], "alt": ["alternating"], "alternate": ["alternating"],
	"wtd": ["weighted"],
	"lats": ["lat"], "delts": ["delt"], "deltoid": ["delt"], "deltoids": ["delt"], "calves": ["calf"], "abs": ["ab"],
	"pec": ["chest"], "pecs": ["chest"],
	"flyes": ["fly"], "flye": ["fly"], "flys": ["fly"], "flies": ["fly"],
	"armed": ["arm"], "legged": ["leg"], "handed": ["hand"],
}

## Two words written apart that are one.
const PAIRS = {
	"dead lift": "deadlift", "skull crusher": "skullcrusher", "kick back": "kickback", "t bar": "tbar",
	"ez bar": "ez", "over head": "overhead", "up right": "upright", "good morning": "goodmorning",
	"body weight": "bodyweight", "dumb bell": "dumbbell", "bar bell": "barbell", "kettle bell": "kettlebell",
	"pull through": "pullthrough", "home gym": "home",
}
## "push up" is "pushup", "pull down" is "pulldown", "bent over" is "bentover", "roll out" is "rollout".
const TAILS = ["up", "down", "over", "out"]
const LIMBS = ["arm", "leg", "hand"]
const ONE = ["1", "one"]
const TWO = ["2", "two", "both", "dual"]

## Equipment the library sorts lifts by (LiftLibrary.EQUIPMENT without "other").
const GEAR = ["barbell", "dumbbell", "cable", "machine", "bodyweight", "kettlebell", "band"]
## The words a typed name may use for a library lift's body part.
const PART_WORDS = {
	"chest": ["chest"], "back": ["back"], "shoulders": ["shoulder", "delt"], "biceps": ["bicep"],
	"triceps": ["tricep"], "forearms": ["forearm"], "quads": ["quad"], "hamstrings": ["hamstring"],
	"glutes": ["glute"], "calves": ["calf"], "core": ["core", "ab"],
}

static var _rx_cache = {}
static var _tok_cache = {}
static var _rows = null
static var _exact = {}
static var _row_cache = {}


static func _rx(pattern: String) -> RegEx:
	if not _rx_cache.has(pattern):
		var r = RegEx.new()
		r.compile(pattern)
		_rx_cache[pattern] = r
	return _rx_cache[pattern]


## What a decision about a typed name is filed under: its letters and digits.
static func key(typed: String) -> String:
	return _rx("[^a-z0-9]+").sub(typed.to_lower(), "", true)


static func _singular(w: String) -> String:
	if w.length() <= 3 or not w.ends_with("s") or w.ends_with("ss") or w.ends_with("us") or w.ends_with("is"):
		return w
	if w.ends_with("sses") or w.ends_with("ches") or w.ends_with("shes") or w.ends_with("xes"):
		return w.substr(0, w.length() - 2)
	return w.substr(0, w.length() - 1)


## The words of a lift name, each in one plain form, in the order written:
## "Triceps push-downs w/ rope" -> ["tricep", "pushdown", "rope"].
static func tokens(lift_name: String) -> Array:
	if _tok_cache.has(lift_name):
		return _tok_cache[lift_name]
	var raw = Array(_rx("[^a-z0-9]+").sub(lift_name.to_lower().replace("&", " and "), " ", true).split(" ", false))
	var joined = []
	var i = 0
	while i < raw.size():
		var w: String = raw[i]
		var pair = w + " " + _singular(str(raw[i + 1])) if i + 1 < raw.size() else ""
		if PAIRS.has(pair):
			joined.append(PAIRS[pair])
			i += 2
			continue
		var tail = w.trim_suffix("s")
		if TAILS.has(tail) and not joined.is_empty() and _rx("^[a-z]{2,}$").search(joined[joined.size() - 1]) != null:
			joined[joined.size() - 1] = str(joined[joined.size() - 1]) + tail
		else:
			joined.append(w)
		i += 1
	var words = []
	for w in joined:
		var parts = WORDS.get(w)
		if parts == null:
			var one = _singular(w)
			parts = WORDS.get(one, [one])
		words.append_array(parts)
	var out = []
	for k in range(words.size()):
		var w: String = words[k]
		var nxt: String = words[k + 1] if k + 1 < words.size() else ""
		if LIMBS.has(nxt):
			if ONE.has(w):
				w = "single"
			elif TWO.has(w):
				w = "double"
		if STOP.has(w) or out.has(w):
			continue
		out.append(w)
	_tok_cache[lift_name] = out
	return out


## How many edits apart two words are (a letter added, dropped, changed, or two
## neighbours swapped), counted up to 2.
static func typo(a: String, b: String) -> int:
	if a == b:
		return 0
	var la = a.length()
	var lb = b.length()
	if absi(la - lb) > 1:
		return 2
	var before = []
	var prev = []
	for j in range(lb + 1):
		prev.append(j)
	for x in range(1, la + 1):
		var cur = [x]
		for y in range(1, lb + 1):
			var cost = 0 if a[x - 1] == b[y - 1] else 1
			var v = mini(mini(int(prev[y]) + 1, int(cur[y - 1]) + 1), int(prev[y - 1]) + cost)
			if x > 1 and y > 1 and a[x - 1] == b[y - 2] and a[x - 2] == b[y - 1]:
				v = mini(v, int(before[y - 2]) + 1)
			cur.append(v)
		before = prev
		prev = cur
	return mini(int(prev[lb]), 2)


## The same word, give or take one typo in a word of five letters or more
## (short words are too close to each other: "dip" / "hip", "row" / "bow").
static func same_word(a: String, b: String) -> bool:
	return a == b or (a.length() >= 5 and b.length() >= 5 and typo(a, b) <= 1)


## How alike two lists of words are, 0 to 1: words in common, twice, over the
## words of both (1 = the same words).
static func alike(t: Array, c: Array) -> float:
	if t.is_empty() or c.is_empty():
		return 0.0
	var used = {}
	var left = []
	var m = 0
	for w in t:
		var at = c.find(w)
		if at >= 0 and not used.has(at):
			used[at] = true
			m += 1
		else:
			left.append(w)
	for w in left:
		for j in range(c.size()):
			if not used.has(j) and same_word(w, c[j]):
				used[j] = true
				m += 1
				break
	return 2.0 * m / float(t.size() + c.size())


static func _compact(s: String) -> String:
	return s.replace(" ", "").replace("-", "").replace("_", "")


## The library as match candidates: {name, keys, lists (the words of its name
## and of each other name), equip ("" when it has no one kind), context (words
## that only say what it already is: its equipment and body part)}.
static func _library() -> Array:
	if _rows == null:
		_rows = []
		_exact = {}
		for e in LiftLibrary.catalog():
			var lists = []
			var seen = {}
			for k in [str(e.name)] + e.keys:
				var tk = tokens(str(k))
				var sig = " ".join(PackedStringArray(tk))
				if not tk.is_empty() and not seen.has(sig):
					seen[sig] = true
					lists.append(tk)
			var context = PART_WORDS.get(str(e.part), []).duplicate()
			if GEAR.has(str(e.equip)):
				context.append(str(e.equip))
			for k in e.keys:
				if not _exact.has(_compact(str(k))):
					_exact[_compact(str(k))] = _rows.size()
			_rows.append({"name": str(e.name), "keys": e.keys, "lists": lists, "equip": str(e.equip) if GEAR.has(str(e.equip)) else "", "context": context})
	return _rows


## How well typed words fit one library lift (the best of its names). A typed
## word that only says the lift's equipment or body part is left out; one that
## says OTHER equipment costs.
static func _fit(t: Array, row: Dictionary) -> float:
	var best = 0.0
	for c in row.lists:
		var said = []
		var factor = 1.0
		for w in t:
			if c.has(w) or not row.context.has(w):
				said.append(w)
				if not c.has(w) and GEAR.has(w) and row.equip != "":
					factor = WRONG_GEAR
		best = maxf(best, alike(said, c) * factor)
	return best


## The library row a name is exactly (a name or other name of it, give or take
## spaces, dashes and a plural), or -1.
static func _exact_row(lift_name: String) -> int:
	_library()
	var c = _compact(Xp.normalize_exercise(lift_name))
	if _exact.has(c):
		return int(_exact[c])
	if c.length() > 3 and _exact.has(c.trim_suffix("s")):
		return int(_exact[c.trim_suffix("s")])
	return -1


## The library row a name IS: exactly, or by the same words ("Chest Fly Cable"
## is Cable Fly). -1 when it is none, or when two rows fit equally well.
static func row_of(lift_name: String) -> int:
	if _row_cache.has(lift_name):
		return int(_row_cache[lift_name])
	var found = _exact_row(lift_name)
	if found < 0:
		var t = tokens(lift_name)
		var rows = _library()
		var best = 0.0
		var ties = 0
		for ri in range(rows.size()):
			var sc = _fit(t, rows[ri])
			if sc > best + 1e-6:
				best = sc
				found = ri
				ties = 1
			elif absf(sc - best) <= 1e-6:
				ties += 1
		if best < SAME or ties != 1:
			found = -1
	_row_cache[lift_name] = found
	return found


## The library's own name for a typed name that is exactly one of its lifts
## ("db bench" -> "Dumbbell Bench Press"), or "".
static func library_name(typed: String) -> String:
	var ri = _exact_row(typed)
	return "" if ri < 0 else str(_library()[ri].name)


## The player's own name for a library lift, when they log it under other
## words ("Chest Fly Cable" for Cable Fly): so a new spelling joins the history
## they already have. `own` is their lifts, newest first. "" when there is none.
static func same_lift(lift_name: String, own: Array) -> String:
	var ri = _exact_row(lift_name)
	if ri < 0:
		return ""
	var n = Xp.normalize_exercise(lift_name)
	for o in own:
		if Xp.normalize_exercise(str(o)) != n and row_of(str(o)) == ri:
			return str(o)
	return ""


## The lifts a typed name could be, best first: [{name, score, own}]. `known`
## is the names the player has (theirs first); the library is added. A lift of
## theirs that is a library lift under other words stands for that library lift.
static func find(typed: String, known: Array, limit: int = 6) -> Array:
	var t = tokens(typed)
	var out = []
	if t.is_empty():
		return out
	var rows = _library()
	var claimed = {}
	var seen = {}
	for o in known:
		var own_name = str(o)
		var nk = Xp.normalize_exercise(own_name)
		if nk == "" or seen.has(nk):
			continue
		seen[nk] = true
		var sc = alike(t, tokens(own_name))
		var ri = row_of(own_name)
		if ri >= 0:
			if claimed.has(ri):
				continue
			claimed[ri] = true
			sc = maxf(sc, _fit(t, rows[ri]))
		if sc > 0.0:
			out.append({"name": own_name, "score": sc, "own": true})
	for ri in range(rows.size()):
		if claimed.has(ri):
			continue
		var sc = _fit(t, rows[ri])
		if sc > 0.0:
			out.append({"name": str(rows[ri].name), "score": sc, "own": false})
	TTUtil.stable_sort(out, func(a, b):
		if absf(float(a.score) - float(b.score)) > 1e-6:
			return float(a.score) > float(b.score)
		if bool(a.own) != bool(b.own):
			return bool(a.own)
		return false)
	return out.slice(0, limit)
