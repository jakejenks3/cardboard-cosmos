class_name LiftNames
extends RefCounted
## Exercise names. The MOVEMENT is the exercise ("Shrug", "Lat Pulldown"); the
## VARIATION says how: position and equipment ("Barbell", "Single arm",
## "Incline dumbbell"). A lift in the log is stored as one name,
## "Movement - Variation" ("Shrug - Barbell"), or the movement alone when it has
## no variation ("Pull-up", "Neck 4 Way"). Records, history and the rules key a
## lift by that name, so two variations are two lifts, each with its own
## records, and the screens group them under their movement.
##
##   split(name) / join(move, variation)
##   canon(words, move)       a variation in one spelling and one word order
##   resolve(typed, own)      which movement and variation a typed name is:
##                            {name, move, variation, kind, closest}
##                            kind "exact" (sure), "match" (the review asks),
##                            "new" (a movement of the player's own)
##   plain(typed)             a movement of their own, from what was typed
##   migrate(name, specials)  an old-style name ("Barbell Shrug") in this form
##
## The movements are LiftLibrary.MOVES. Pure logic: tests/lift_names_test.gd.

const SEP = " - "

## Words of a variation, in the order they are written: positions and styles,
## then band colours, then equipment. Each is [words, how it is written, kind,
## equipment id (LiftLibrary.EQUIPMENT)]. Longer phrases come before the words
## they start with.
const VOCAB = [
	[["single", "arm"], "Single arm", "pos", ""],
	[["single", "leg"], "Single leg", "pos", ""],
	[["single"], "Single", "pos", ""],
	[["alternating"], "Alternating", "pos", ""],
	[["incline"], "Incline", "pos", ""],
	[["decline"], "Decline", "pos", ""],
	[["flat"], "Flat", "pos", ""],
	[["seated"], "Seated", "pos", ""],
	[["standing"], "Standing", "pos", ""],
	[["lying"], "Lying", "pos", ""],
	[["half", "kneeling"], "Half kneeling", "pos", ""],
	[["kneeling"], "Kneeling", "pos", ""],
	[["reclined"], "Reclined", "pos", ""],
	[["prone"], "Prone", "pos", ""],
	[["bentover"], "Bent over", "pos", ""],
	[["hanging"], "Hanging", "pos", ""],
	[["overhead"], "Overhead", "pos", ""],
	[["behind", "neck"], "Behind the neck", "pos", ""],
	[["front"], "Front", "pos", ""],
	[["side"], "Side", "pos", ""],
	[["cross", "body"], "Cross body", "pos", ""],
	[["low", "high"], "Low to high", "pos", ""],
	[["high", "low"], "High to low", "pos", ""],
	[["wide"], "Wide grip", "pos", ""],
	[["close"], "Close grip", "pos", ""],
	[["narrow"], "Close grip", "pos", ""],
	[["neutral"], "Neutral grip", "pos", ""],
	[["underhand"], "Underhand", "pos", ""],
	[["overhand"], "Overhand", "pos", ""],
	[["reverse"], "Reverse", "pos", ""],
	[["sumo"], "Sumo", "pos", ""],
	[["goblet"], "Goblet", "pos", ""],
	[["zercher"], "Zercher", "pos", ""],
	[["pendlay"], "Pendlay", "pos", ""],
	[["preacher"], "Preacher", "pos", ""],
	[["concentration"], "Concentration", "pos", ""],
	[["spider"], "Spider", "pos", ""],
	[["bayesian"], "Bayesian", "pos", ""],
	[["hang"], "Hang", "pos", ""],
	[["power"], "Power", "pos", ""],
	[["box"], "Box", "pos", ""],
	[["deficit"], "Deficit", "pos", ""],
	[["paused"], "Paused", "pos", ""],
	[["pause"], "Paused", "pos", ""],
	[["tempo"], "Tempo", "pos", ""],
	[["walking"], "Walking", "pos", ""],
	[["diamond"], "Diamond", "pos", ""],
	[["pike"], "Pike", "pos", ""],
	[["donkey"], "Donkey", "pos", ""],
	[["feet", "elevated"], "Feet elevated", "pos", ""],
	[["45", "degree"], "45 degree", "pos", ""],
	[["assisted"], "Assisted", "pos", ""],
	[["weighted"], "Weighted", "pos", ""],
	[["green"], "green", "color", ""],
	[["red"], "red", "color", ""],
	[["blue"], "blue", "color", ""],
	[["black"], "black", "color", ""],
	[["yellow"], "yellow", "color", ""],
	[["purple"], "purple", "color", ""],
	[["orange"], "orange", "color", ""],
	[["gray"], "gray", "color", ""],
	[["grey"], "gray", "color", ""],
	[["pink"], "pink", "color", ""],
	[["light"], "light", "color", ""],
	[["medium"], "medium", "color", ""],
	[["heavy"], "heavy", "color", ""],
	[["smith", "machine"], "Smith machine", "equip", "machine"],
	[["smith"], "Smith machine", "equip", "machine"],
	[["trapbar"], "Trap bar", "equip", "barbell"],
	[["ez"], "EZ bar", "equip", "barbell"],
	[["safety", "bar"], "Safety bar", "equip", "barbell"],
	[["straight", "bar"], "Straight bar", "equip", "cable"],
	[["v", "bar"], "V bar", "equip", "cable"],
	[["rope"], "Rope", "equip", "cable"],
	[["leg", "press"], "Leg press", "equip", "machine"],
	[["barbell"], "Barbell", "equip", "barbell"],
	[["dumbbell"], "Dumbbell", "equip", "dumbbell"],
	[["kettlebell"], "Kettlebell", "equip", "kettlebell"],
	[["cable"], "Cable", "equip", "cable"],
	[["machine"], "Machine", "equip", "machine"],
	[["landmine"], "Landmine", "equip", "barbell"],
	[["band"], "Band", "equip", "band"],
	[["plate"], "Plate", "equip", "other"],
	[["ghd"], "GHD", "equip", "machine"],
	[["trx"], "TRX", "equip", "bodyweight"],
	[["ring"], "Rings", "equip", "bodyweight"],
	[["bench"], "Bench", "equip", "other"],
	[["ab", "wheel"], "Ab wheel", "equip", "other"],
	[["medicine", "ball"], "Medicine ball", "equip", "other"],
	[["med", "ball"], "Medicine ball", "equip", "other"],
	[["stability", "ball"], "Stability ball", "equip", "other"],
	[["swiss", "ball"], "Stability ball", "equip", "other"],
	[["foam", "roller"], "Foam roller", "equip", "other"],
	[["slant", "board"], "Slant board", "equip", "other"],
	[["wall"], "Wall", "equip", "other"],
	[["bodyweight"], "Bodyweight", "equip", "bodyweight"],
]

## Equipment words a new movement's name gives up to its variation ("cable
## woodchopper" is Woodchopper - Cable). Other words stay in the name.
const NAME_GEAR = ["barbell", "dumbbell", "kettlebell", "cable", "machine", "band", "landmine", "smith", "ez", "trapbar", "bodyweight"]
## Attachments that are only ever used on a cable: with one, "Cable" is not said.
const CABLE_PARTS = ["Rope", "Straight bar", "V bar"]

## Names that hide a variation, and what they are (keys as LiftMatch.key).
const ALIASES = {
	"pecdeck": "Chest Fly - Machine",
	"reversepecdeck": "Rear Delt Fly - Machine",
	"chestpress": "Bench Press - Machine",
	"machinechestpress": "Bench Press - Machine",
	"cablecrossover": "Chest Fly - Cable",
	"crossover": "Chest Fly - Cable",
	"incline": "Bench Press - Incline",
	"inclinebench": "Bench Press - Incline",
	"decline": "Bench Press - Decline",
	"declinebench": "Bench Press - Decline",
	"dbpress": "Bench Press - Dumbbell",
	"dumbbellpress": "Bench Press - Dumbbell",
	"skullcrusher": "Tricep Extension - Lying EZ bar",
	"skullcrushers": "Tricep Extension - Lying EZ bar",
	"machinerow": "Seated Row - Machine",
	"suitcasecarry": "Farmer Carry - Single arm",
	"latraise": "Lateral Raise - Dumbbell",
	"inclinepress": "Bench Press - Incline",
	"declinepress": "Bench Press - Decline",
	"inclinedbpress": "Bench Press - Incline dumbbell",
	"inclinedumbbellpress": "Bench Press - Incline dumbbell",
	"declinedbpress": "Bench Press - Decline dumbbell",
	"declinedumbbellpress": "Bench Press - Decline dumbbell",
	"slantboardstretch": "Calf Stretch - Slant board",
	"slantboard": "Calf Stretch - Slant board",
}

## Short forms that stay in capitals in a name: "GHD", "RDL".
const CAPITALS = ["ghd", "ghr", "db", "kb", "bb", "ez", "trx", "rdl", "ohp", "1ue", "1le", "sa", "sl", "bw", "t2b"]

static var _vocab_words = null
static var _cands = null
static var _by_name = null
## word -> how many movements have it in a name or another name.
static var _word_moves = null


# ---------------------------------------------------------------------------
# The two halves of a name
# ---------------------------------------------------------------------------

## {"move", "variation"} of a stored name: "Shrug - Barbell" -> Shrug / Barbell.
static func split(lift_name: String) -> Dictionary:
	var n = lift_name.strip_edges()
	var at = n.find(SEP)
	if at < 0:
		return {"move": n, "variation": ""}
	return {"move": n.substr(0, at).strip_edges(), "variation": n.substr(at + SEP.length()).strip_edges()}


static func join(move: String, variation: String) -> String:
	return move if variation.strip_edges() == "" else move + SEP + variation.strip_edges()


## The catalog entry of a movement by its name or another name of it, or null.
static func movement(move_name: String):
	_load()
	return _by_name.get(Xp.normalize_exercise(move_name))


# ---------------------------------------------------------------------------
# Variations in one spelling
# ---------------------------------------------------------------------------

static func _vocab_set() -> Dictionary:
	if _vocab_words == null:
		_vocab_words = {}
		for v in VOCAB:
			for w in v[0]:
				_vocab_words[str(w)] = true
	return _vocab_words


static func is_vocab(word: String) -> bool:
	return _vocab_set().has(word)


## The words of a variation in one spelling and one order: positions, any other
## words, band colours, then equipment ("cable, single arm" -> "Single
## arm cable"). With `move` (a catalog entry): its only equipment is never said
## ("Lat Pulldown - Single arm", not "... cable"); its usual equipment is the
## variation when nothing else is written, and is left out next to other words
## ("Squat - Front", "Squat - Barbell").
static func canon(words: Array, move = null) -> String:
	var parsed = parse(words)
	var picked: Array = parsed.picked
	var unknown: Array = parsed.unknown
	return _written(picked, unknown, move)


## The variation words found in a list of words: {"picked": [VOCAB indexes],
## "unknown": [the other words, in order]}. Longer phrases win.
static func parse(words: Array) -> Dictionary:
	var picked = []
	var unknown = []
	var i = 0
	while i < words.size():
		var hit = -1
		var hit_len = 0
		for vi in range(VOCAB.size()):
			var phrase: Array = VOCAB[vi][0]
			if phrase.size() <= hit_len or i + phrase.size() > words.size():
				continue
			var same = true
			for k in range(phrase.size()):
				if str(words[i + k]) != str(phrase[k]):
					same = false
					break
			if same:
				hit = vi
				hit_len = phrase.size()
		if hit >= 0:
			if not picked.has(hit):
				picked.append(hit)
			i += hit_len
		else:
			var w = str(words[i])
			if not unknown.has(w):
				unknown.append(w)
			i += 1
	return {"picked": picked, "unknown": unknown}


static func _written(picked: Array, unknown: Array, move) -> String:
	var shown = {}
	for vi in picked:
		shown[str(VOCAB[vi][1])] = vi
	if move is Dictionary:
		for gone in move.get("only", []):
			shown.erase(str(gone))
	for part in CABLE_PARTS:
		if shown.has(part):
			shown.erase("Cable")
	var usual = str(move.get("usual", "")) if move is Dictionary else ""
	if usual != "" and (shown.size() > 1 or not unknown.is_empty()):
		shown.erase(usual)
	if shown.is_empty() and unknown.is_empty():
		return usual
	var order = shown.values()
	order.sort()
	var pos = []
	var colors = []
	var gear = []
	for vi in order:
		var kind = str(VOCAB[vi][2])
		var said = str(VOCAB[vi][1])
		if kind == "pos":
			pos.append(said)
		elif kind == "color":
			colors.append(said)
		else:
			gear.append(said)
	var parts = pos + unknown + colors + gear
	var out = []
	for k in range(parts.size()):
		var p: String = str(parts[k])
		if k == 0:
			p = p.substr(0, 1).to_upper() + p.substr(1)
		elif p.length() > 1 and p.substr(0, 2) != p.substr(0, 2).to_upper():
			p = p.substr(0, 1).to_lower() + p.substr(1)
		out.append(p)
	return " ".join(PackedStringArray(out))


## The equipment ids (LiftLibrary.EQUIPMENT) a variation's words name.
static func gear_of(variation: String) -> Array:
	var out = []
	var words = LiftMatch.words(variation)
	for v in VOCAB:
		if str(v[2]) != "equip":
			continue
		var phrase: Array = v[0]
		for i in range(words.size() - phrase.size() + 1):
			var same = true
			for k in range(phrase.size()):
				if str(words[i + k]) != str(phrase[k]):
					same = false
					break
			if same and not out.has(str(v[3])):
				out.append(str(v[3]))
	return out


# ---------------------------------------------------------------------------
# Which movement a typed name is
# ---------------------------------------------------------------------------

## The movements as match candidates: {"name", "entry", "lists": [{"w": words, "is_name"}]}.
static func _load() -> void:
	if _cands != null:
		return
	_cands = []
	_by_name = {}
	for e in LiftLibrary.catalog():
		var lists = [{"w": LiftMatch.words(str(e.name)), "is_name": true}]
		for o in e.names:
			lists.append({"w": LiftMatch.words(str(o)), "is_name": false})
		_cands.append({"name": str(e.name), "entry": e, "lists": lists})
		_by_name[Xp.normalize_exercise(str(e.name))] = e
		for o in e.names:
			_by_name[Xp.normalize_exercise(str(o))] = e
	_word_moves = {}
	for c in _cands:
		var mine = {}
		for l in c.lists:
			for w in l.w:
				mine[str(w)] = true
		for w in mine:
			_word_moves[w] = int(_word_moves.get(w, 0)) + 1


## Is every word of `want` among `have` (one typo allowed in a word of five
## letters or more)? {"ok", "left": the words of `have` not used, "typo"}.
static func _covers(have: Array, want: Array) -> Dictionary:
	var left = have.duplicate()
	var typo = false
	for w in want:
		var at = left.find(w)
		if at < 0:
			for j in range(left.size()):
				if LiftMatch.same_word(str(w), str(left[j])):
					at = j
					typo = true
					break
		if at < 0:
			return {"ok": false}
		left.remove_at(at)
	return {"ok": true, "left": left, "typo": typo}


static func _all_vocab(words: Array) -> bool:
	return parse(words).unknown.is_empty()


## The variation phrases a list of words holds, as written ("Single arm", "Cable").
static func phrases_in(words: Array) -> Array:
	var out = []
	for vi in parse(words).picked:
		out.append(str(VOCAB[vi][1]))
	return out


## The movement a name's words start from: the one whose name (or another name)
## is all there, the longest such; what is left over is the variation.
## Movements of the player's own (`own_moves`: names) count too.
static func _best_cover(words: Array, own_moves: Array) -> Dictionary:
	_load()
	var cands = _cands.duplicate()
	for m in own_moves:
		cands.append({"name": str(m), "entry": null, "lists": [{"w": LiftMatch.words(str(m)), "is_name": true}]})
	var best = {}
	var best_score = -1
	for c in cands:
		for l in c.lists:
			var w: Array = l.w
			if w.is_empty():
				continue
			var cov = _covers(words, w)
			if not cov.ok:
				continue
			var vocab_left = _all_vocab(cov.left)
			# A one-word other name ("row", "curl") with unknown words beside it
			# is too loose to be sure of ("jefferson curl" is not a bicep curl).
			if not vocab_left and not l.is_name and w.size() < 2:
				continue
			var score = w.size() * 10 + (5 if vocab_left else 0) + (2 if l.is_name else 0) + (0 if cov.typo else 1)
			if score > best_score:
				best_score = score
				# One word is enough when no other movement has it ("bench", "dl"),
				# not when several do ("row", "curl", "press").
				var alone = w.size() == 1 and int(_word_moves.get(str(w[0]), 0)) <= 1
				best = {"name": c.name, "entry": c.entry, "left": cov.left, "typo": cov.typo,
					"sure": not cov.typo and (l.is_name or w.size() >= 2 or alone)}
	return best


## The nearest movement by how many words they share, for "Same as ...?": {"name", "score"}.
static func _nearest(words: Array, own_moves: Array) -> Dictionary:
	_load()
	var core = parse(words).unknown
	if core.is_empty():
		return {"name": "", "score": 0.0}
	var best = {"name": "", "score": 0.0}
	var second = 0.0
	var pool = []
	for c in _cands:
		for l in c.lists:
			pool.append({"name": c.name, "w": l.w})
	for m in own_moves:
		pool.append({"name": str(m), "w": LiftMatch.words(str(m))})
	var seen = {}
	for p in pool:
		var sc = LiftMatch.alike(core, p.w)
		var nm = str(p.name)
		if sc > float(seen.get(nm, -1.0)):
			seen[nm] = sc
	for nm in seen:
		var sc = float(seen[nm])
		if sc > float(best.score):
			second = float(best.score)
			best = {"name": nm, "score": sc}
		elif sc > second:
			second = sc
	# Two movements equally near are no "closest".
	if float(best.score) - second < 0.04:
		return {"name": "", "score": 0.0}
	return best


## The two halves of a typed name: "chest fly - cable" -> chest fly / cable.
static func _halves(typed: String) -> Dictionary:
	var t = typed.strip_edges()
	var at = t.find(" - ")
	if at < 0:
		return {"move": t, "variation": ""}
	return {"move": t.substr(0, at).strip_edges(), "variation": t.substr(at + 3).strip_edges()}


## The movements of a player's own (not in the catalog), from their lift names.
static func own_movements(own: Array) -> Array:
	_load()
	var out = []
	for n in own:
		var m = str(split(str(n)).move)
		if m != "" and not _by_name.has(Xp.normalize_exercise(m)) and not out.has(m):
			out.append(m)
	return out


## Which lift a typed name is. `own`: the names already in the player's log.
## {"name", "move", "variation", "kind", "closest"}:
##   "exact"  a lift already in the log as typed; a known name for a variation
##            ("pec deck"); a movement found by its name or a name of two words
##            or more, with the rest as its variation
##   "match"  found by a one-word other name ("row", "curl") or with a typo:
##            the review asks whether it is right
##   "new"    a movement of the player's own; `closest` names the nearest one
static func resolve(typed: String, own: Array = []) -> Dictionary:
	var raw = typed.strip_edges()
	var out = {"name": "", "move": "", "variation": "", "kind": "new", "closest": ""}
	if raw == "":
		return out
	var key = LiftMatch.key(raw)
	for o in own:
		if LiftMatch.key(str(o)) == key:
			return _result(str(o), "exact", "")
	if ALIASES.has(key):
		return _result(str(ALIASES[key]), "exact", "")
	var halves = _halves(raw)
	var mw = LiftMatch.words(str(halves.move))
	var vw = LiftMatch.words(str(halves.variation))
	var mkey = LiftMatch.key(str(halves.move))
	if ALIASES.has(mkey):
		var base = split(str(ALIASES[mkey]))
		var be = movement(str(base.move))
		var v = canon(LiftMatch.words(str(base.variation)) + vw, be)
		return _result(join(str(base.move), v), "exact", "")
	var own_moves = own_movements(own)
	var best = _best_cover(mw, own_moves)
	if not best.is_empty():
		var v = canon(best.left + vw, best.entry)
		return _result(join(str(best.name), v), "exact" if best.sure else "match", "")
	var near = _nearest(mw, own_moves)
	var made = plain(raw)
	made.kind = "new"
	made.closest = str(near.name) if float(near.score) >= LiftMatch.CLOSE else ""
	return made


static func _result(full: String, kind: String, closest: String) -> Dictionary:
	var sp = split(full)
	return {"name": full, "move": sp.move, "variation": sp.variation, "kind": kind, "closest": closest}


## A movement of the player's own from what they typed: their words, in title
## case, except equipment words, which become its variation ("cable woodchopper"
## is Woodchopper - Cable; "Slant Board Stretch" stays as it is). Words lose a
## plural ending ("preacher curls" is Preacher Curl, like the library's names),
## except with `singular` false: a name the player typed as the name to give.
static func plain(typed: String, singular: bool = true) -> Dictionary:
	var halves = _halves(typed)
	var raw_words = Array(str(halves.move).split(" ", false))
	var keep = []
	var gear = []
	for w in raw_words:
		var ws = LiftMatch.words(str(w))
		if ["home", "with", "w", "attachment", "using"].has(str(w).to_lower().trim_suffix(",")):
			# Words that say where or with what, nothing about the movement.
			continue
		if ws.size() == 1 and NAME_GEAR.has(str(ws[0])):
			gear.append_array(ws)
		else:
			keep.append(_singular(str(w).trim_suffix(","), ws) if singular else str(w).trim_suffix(","))
	if keep.is_empty():
		keep = raw_words
		gear = []
	var v = canon(gear + LiftMatch.words(str(halves.variation)), null)
	return _result(join(title_case(" ".join(PackedStringArray(keep))), v), "new", "")


## One typed word without its plural ending, when that is all that sets it apart
## from the word the matching reads ("Curls" -> "Curl", "sit-ups" -> "sit-up",
## "Presses" -> "Press"). `ws`: LiftMatch.words(word).
static func _singular(word: String, ws: Array) -> String:
	if ws.size() != 1 or str(ws[0]).length() < 3:
		return word
	var bare = word.to_lower().replace("-", "")
	for end in ["s", "es"]:
		if bare == str(ws[0]) + end:
			return word.substr(0, word.length() - end.length())
	return word


## "ghd sit-ups" -> "GHD Sit-ups"; "neck 4 way" -> "Neck 4 Way".
static func title_case(text: String) -> String:
	var out = []
	for w in Xp.normalize_exercise(text).split(" ", false):
		var bare = w.trim_suffix(",")
		if CAPITALS.has(bare):
			out.append(bare.to_upper() + w.substr(bare.length()))
		else:
			out.append(w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(PackedStringArray(out))


static var _defaults = null


## The exercises the Log tab suggests before anything is logged
## (Summary.DEFAULT_EXERCISES), in this form: "Squat - Barbell", "Pull-up"...
static func defaults() -> Array:
	if _defaults == null:
		_defaults = []
		for n in Summary.DEFAULT_EXERCISES:
			var full = str(resolve(str(n)).name)
			if not _defaults.has(full):
				_defaults.append(full)
	return _defaults.duplicate()


## An old-style name in the "Movement - Variation" form ("Barbell Shrug" ->
## "Shrug - Barbell"). `specials`: {old name: new name} for names that cannot be
## worked out from their words alone. Names already in this form come back the same.
static func migrate(old_name: String, specials: Dictionary = {}) -> String:
	if specials.has(old_name):
		return str(specials[old_name])
	return str(resolve(old_name, []).name)
