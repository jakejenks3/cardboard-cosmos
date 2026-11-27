class_name RpgFeats
extends RefCounted
## Feats: the long goals of the Realm. Each is a LADDER of steps over one
## count (stars earned, bosses felled, kinds of foe met, days trained, Might
## reached...), and each step pays ore once, when it is claimed.
##
## Nothing is counted specially: every count is read from what the Realm
## already keeps (saved.rpg) or from the stat sheet (the log). The only thing
## stored is how many steps of a ladder have been claimed:
## saved.rpg.feats = {ladder id: steps claimed}.
##
##   RpgFeats.rows(rpg, sheet)      # one row per ladder: its next step, how far it is
##   RpgFeats.ready(rpg, sheet)     # how many can be claimed now
##   RpgSave.claim_feat(rpg, id, sheet)   # pays the step (rpg_save.gd)
##
## Pure and static: no autoload, no scene tree.

## [id, name, icon, words (with %d for the step's number), [[count needed, ore paid], ...]].
const LADDERS = [
	["stars", "Star Collector", "star_on", "Earn %d stars on the road", [[10, 40], [27, 80], [54, 150], [108, 300], [216, 600]]],
	["stages", "Trailblazer", "map", "Win %d stages of the road", [[5, 30], [20, 100], [40, 200], [80, 400]]],
	["bosses", "Giant Killer", "crown", "Fell %d bosses", [[1, 100], [3, 250], [8, 600]]],
	["foes", "Field Guide", "skull", "Meet %d kinds of foe", [[10, 50], [25, 150], [56, 400]]],
	["weak", "Sharp Eye", "fx_insight", "Find %d weaknesses", [[10, 50], [30, 150], [60, 300]]],
	["level", "Veteran", "realm", "Reach fighter level %d", [[5, 50], [10, 100], [20, 200], [40, 400], [60, 800]]],
	["skills", "Student", "sp", "Learn %d skills", [[5, 50], [15, 150], [30, 300]]],
	["plus", "Tinkerer", "power", "Upgrade gear %d times in all", [[5, 60], [20, 200], [50, 400]]],
	["relics", "Treasure Hunter", "relic", "Find %d relics", [[1, 50], [5, 150], [12, 300], [24, 600]]],
	["spire", "Climber", "spire", "Reach floor %d of the Spire", [[5, 100], [10, 200], [20, 400]]],
	["dares", "Daredevil", "flame", "Win the dare of %d stages", [[1, 40], [10, 150], [30, 400], [72, 900]]],
	["mastery", "Craftsman", "star_on", "Earn %d mastery stars", [[1, 30], [6, 100], [15, 250], [30, 500]]],
	["perfect", "Stone Wall", "guard", "Land %d perfect guards", [[1, 30], [10, 100], [40, 250], [100, 500]]],
	["breaks", "Breaker", "fx_broken", "Break %d guards", [[5, 30], [25, 100], [100, 250], [300, 500]]],
	["days", "Regular", "bolt", "Train on %d days", [[10, 50], [30, 100], [60, 200], [100, 300], [200, 500]]],
	["might", "Built", "muscle", "Reach Might %d", [[20, 60], [30, 120], [40, 200], [50, 350], [60, 600]]],
]
const ROMAN = ["I", "II", "III", "IV", "V", "VI"]


static func ids() -> Array:
	var out = []
	for l in LADDERS:
		out.append(str(l[0]))
	return out


static func ladder(id: String) -> Variant:
	for l in LADDERS:
		if str(l[0]) == id:
			return l
	return null


## The kinds of foe met: {foe id: true}. Met = one of its weaknesses was learned (saved.rpg.seen) or it
## stands in a stage that was won.
static func met(rpg: Dictionary) -> Dictionary:
	var out = {}
	var seen = rpg.get("seen", {})
	if seen is Dictionary:
		for k in seen:
			out[str(k).split("#")[0]] = true
	var stages = rpg.get("stages", {})
	if stages is Dictionary:
		for sid in stages:
			if not RpgWorld.done(rpg, str(sid)):
				continue
			var st = RpgWorld.stage(str(sid))
			if not (st is Dictionary):
				continue
			for wave in st.get("waves", []):
				if not (wave is Array):
					continue
				for en in wave:
					if en is Dictionary and str(en.get("foe", "")) != "":
						out[str(en.foe)] = true
	return out


## Every ladder's count as things stand: {id: whole number}. `sheet` is RpgStats.sheet's (for the days
## trained and Might); left out, those two count nothing.
static func counts(rpg: Dictionary, sheet = null) -> Dictionary:
	var out = {}
	for id in ids():
		out[id] = 0
	for st in RpgWorld.all_stages():
		if bool(st.get("echo", false)):
			continue
		if RpgWorld.done(rpg, str(st.id)):
			out.stages += 1
			if str(st.get("kind", "")) == "boss":
				out.bosses += 1
	for reg in RpgWorld.regions():
		out.stars += RpgWorld.star_count(rpg, str(reg.id))
	out.foes = met(rpg).size()
	var seen = rpg.get("seen", {})
	if seen is Dictionary:
		for k in seen:
			if seen[k] is Array:
				out.weak += seen[k].size()
	out.level = int(RpgDefs.level_of(int(rpg.get("xp", 0))).lvl)
	var nodes = rpg.get("nodes", {})
	out.skills = nodes.size() if nodes is Dictionary else 0
	var plus = rpg.get("plus", {})
	if plus is Dictionary:
		for k in plus:
			out.plus += maxi(0, int(plus[k]))
	var relics = rpg.get("relics", {})
	out.relics = relics.size() if relics is Dictionary else 0
	var spire = rpg.get("spire", {})
	out.spire = int(spire.get("best", 0)) if spire is Dictionary else 0
	out.dares = RpgWorld.dare_count(rpg)
	var mastery = rpg.get("mastery", {})
	if mastery is Dictionary:
		for mid in mastery:
			out.mastery += RpgDefs.mastery_level(int(mastery[mid]))
	var tally = rpg.get("tally", {})
	if tally is Dictionary:
		out.perfect = int(tally.get("perfect", 0))
		out.breaks = int(tally.get("breaks", 0))
	if sheet is Dictionary:
		out.days = int(sheet.get("days", 0))
		out.might = int(floor(float(sheet.get("might", 0.0)) + 0.0001))
	return out


static func claimed(rpg: Dictionary, id: String) -> int:
	var f = rpg.get("feats", {})
	var l = ladder(id)
	if not (f is Dictionary) or l == null:
		return 0
	return clampi(int(f.get(id, 0)), 0, l[4].size())


## One row per ladder, the ones that can be claimed first: {"id", "name" ("Star Collector II"), "icon",
## "words", "have", "need", "ore", "step" (1-based, the one shown), "steps", "done" (every step claimed),
## "ready" (the step shown can be claimed)}.
static func rows(rpg: Dictionary, sheet = null) -> Array:
	var have = counts(rpg, sheet)
	var out = []
	for l in LADDERS:
		var id = str(l[0])
		var steps = l[4]
		var got = claimed(rpg, id)
		var done = got >= steps.size()
		var i = mini(got, steps.size() - 1)
		var need = int(steps[i][0])
		var n = int(have.get(id, 0))
		out.append({"id": id, "name": "%s %s" % [str(l[1]), ROMAN[mini(i, ROMAN.size() - 1)]], "icon": str(l[2]),
			"words": _one(str(l[3]) % need, need), "have": mini(n, need) if not done else n, "need": need, "ore": int(steps[i][1]),
			"step": i + 1, "steps": steps.size(), "done": done, "ready": (not done) and n >= need})
	var order = []
	for r in out:
		if bool(r.ready):
			order.append(r)
	for r in out:
		if not bool(r.ready) and not bool(r.done):
			order.append(r)
	for r in out:
		if bool(r.done):
			order.append(r)
	return order


## "Fell 1 bosses" is "Fell 1 boss".
static func _one(words: String, n: int) -> String:
	if n != 1:
		return words
	return words.replace(" bosses", " boss").replace(" relics", " relic").replace(" days", " day").replace(" stages", " stage").replace(" stars", " star").replace(" guards", " guard").replace(" mastery stars", " mastery star")


static func ready(rpg: Dictionary, sheet = null) -> int:
	var n = 0
	for r in rows(rpg, sheet):
		if bool(r.ready):
			n += 1
	return n


## Every step of every ladder: how many there are, and how many are claimed.
static func tally(rpg: Dictionary) -> Dictionary:
	var all = 0
	var got = 0
	for l in LADDERS:
		all += l[4].size()
		got += claimed(rpg, str(l[0]))
	return {"claimed": got, "of": all}
