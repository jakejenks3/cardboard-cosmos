class_name LiftMatch
extends RefCounted
## Words of lift names, and how alike two names are.
##
## Names are compared by their WORDS, not their letters: order, dashes, commas,
## plurals, short forms ("db", "1UE", "pulley") and a one-letter typo do not
## count. Which movement and variation a name is: game/lift_names.gd, which
## reads names with `words`.
##
##   LiftMatch.tokens(name) / words(name)   the words of a name
##   LiftMatch.alike(a, b)                  0 to 1: how many words two names share
##   LiftMatch.find(typed, names)           [{name, score}], best first
##   LiftMatch.key(typed)                   what a decision about a typed name is filed under
##
## A score of SAME or more means the same words; CLOSE or more is worth offering
## as "closest". Pure logic, no scene and no autoload: tests/lift_match_test.gd.

## The same words: taken as the same lift.
const SAME = 0.95
## Enough words in common to offer it as the closest one.
const CLOSE = 0.5

## Words that say nothing about which lift it is. ("home" and "gym" are not
## among them: where it was done is part of the variation, a home cable is not
## the gym's. "home gym" is "home", see PAIRS.)
const STOP = ["with", "and", "the", "a", "an", "on", "in", "of", "at", "to", "for", "using", "w", "attachment",
	"my", "grip", "style", "variation", "version"]

## Short forms and other spellings, and the words they stand for.
const WORDS = {
	"db": ["dumbbell"], "dbs": ["dumbbell"], "dumbell": ["dumbbell"], "dumbells": ["dumbbell"],
	"bb": ["barbell"], "kb": ["kettlebell"], "kbs": ["kettlebell"], "bw": ["bodyweight"],
	"oh": ["overhead"], "ohp": ["overhead", "press"],
	"rdl": ["romanian", "deadlift"], "rdls": ["romanian", "deadlift"], "sldl": ["stiff", "leg", "deadlift"],
	"sa": ["single", "arm"], "sl": ["single", "leg"], "1ue": ["single", "arm"], "1le": ["single", "leg"],
	"unilateral": ["single"],
	"pulley": ["cable"], "pulleys": ["cable"], "banded": ["band"], "superband": ["band"], "miniband": ["band"],
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
	"trap bar": "trapbar", "hex bar": "trapbar", "super band": "band", "mini band": "band", "resistance band": "band",
}
## "push up" is "pushup", "pull down" is "pulldown", "bent over" is "bentover", "roll out" is "rollout".
const TAILS = ["up", "down", "over", "out"]
const LIMBS = ["arm", "leg", "hand"]
const ONE = ["1", "one"]
const TWO = ["2", "two", "both", "dual"]

static var _rx_cache = {}
static var _tok_cache = {}


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
	var out = _tokenize(lift_name, true)
	_tok_cache[lift_name] = out
	return out


static var _word_cache = {}


## The same words as `tokens`, but every one of them, in order: a word said
## twice stays twice ("single leg leg press"). LiftNames reads names with it.
static func words(text: String) -> Array:
	if _word_cache.has(text):
		return _word_cache[text]
	var out = _tokenize(text, false)
	_word_cache[text] = out
	return out


static func _tokenize(lift_name: String, dedupe: bool) -> Array:
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
		if STOP.has(w) or (dedupe and out.has(w)):
			continue
		out.append(w)
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


## Names a typed name could be, best first: [{name, score}]. `names` are full
## lift names ("Shrug - Barbell"); the score is how many words they share
## (`alike`, 0 to 1). For the review's "pick another lift" list.
static func find(typed: String, names: Array, limit: int = 6) -> Array:
	var t = tokens(typed)
	var out = []
	if t.is_empty():
		return out
	var seen = {}
	for n in names:
		var k = Xp.normalize_exercise(str(n))
		if k == "" or seen.has(k):
			continue
		seen[k] = true
		var sc = alike(t, tokens(str(n)))
		if sc > 0.0:
			out.append({"name": str(n), "score": sc})
	TTUtil.stable_sort(out, func(a, b): return float(a.score) > float(b.score))
	return out.slice(0, limit)
