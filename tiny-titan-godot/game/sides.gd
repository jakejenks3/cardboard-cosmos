class_name Sides
extends RefCounted
## Lifts whose reps are logged as BOTH SIDES ADDED UP: a single arm or single
## leg lift done one side after the other and typed as one number (the user,
## 2026-11-23: "There are some exercises where I am putting the total reps
## because they're split between two single arm movements... I think I've done
## 12 and 13 reps in a set before, so I usually put the combined total... Need
## that to be differentiated somehow so that you or the app doesn't think I
## need to increase the weight because my reps are at 25, when in reality each
## arm is only doing about 10 to 15").
##
## STORED: settings.bothSides = {normalized lift name: {"name", "on"}}, only
## where the player's switch differs from USUAL. A lift without a mark goes by
## USUAL: the two the user named (a lateral raise on a cable, a single arm lat
## pulldown) are both sides with nothing stored, and switching one off sticks.
## A mark is on one lift, movement and variation together.
##
## The rules do not know it and need not: a rep is a rep, so XP, records and
## the weight moved are right for the total. What goes by ONE side:
##   - the aim (LiftTrend.next_target): "too many reps, go heavier" only past
##     HIGH_REPS a side, and back down to DOWN_TO a side;
##   - the estimated one-rep max, the rep ladder, the "change the reps" advice;
##   - the training summary (Dosage): reps a set and sets by rep range.
## They know from the SETS: tag_sets / tagged put "sides": 2 on COPIES of a
## lift's sets (Missions.day_plan for the day's plan, the lift's page for its
## history) and the tag travels with them. Stored sets are never tagged.
##
## Pure logic: tests/sides_test.gd.

const KEY = "bothSides"
## On screen, where there is little room.
const SHORT = "L+R"
## Both sides unless the player says otherwise: [movement, a word its
## variation holds], lower case.
const USUAL = [["lateral raise", "cable"], ["lat pulldown", "single arm"]]


static func key(lift_name: String) -> String:
	return Xp.normalize_exercise(lift_name)


## The stored marks: {key: {"name", "on"}}.
static func marks(settings: Dictionary) -> Dictionary:
	var m = settings.get(KEY)
	return m if m is Dictionary else {}


## Is this lift both sides added up when the player has said nothing about it?
static func usual(lift_name: String) -> bool:
	var sp = LiftNames.split(lift_name)
	var move = str(sp.move).to_lower().strip_edges()
	var variation = str(sp.variation).to_lower()
	for u in USUAL:
		if move == str(u[0]) and variation.contains(str(u[1])):
			return true
	return false


## Are this lift's reps both sides added up?
static func both(settings: Dictionary, lift_name: String) -> bool:
	var m = marks(settings).get(key(lift_name))
	if m is Dictionary and m.has("on"):
		return bool(m.on)
	return usual(lift_name)


## How many sides a rep count of this lift holds: 2 or 1.
static func n(settings: Dictionary, lift_name: String) -> int:
	return 2 if both(settings, lift_name) else 1


## The marks with this lift switched on or off (a new dictionary). Only a
## switch that differs from USUAL is kept.
static func with_mark(settings: Dictionary, lift_name: String, on: bool) -> Dictionary:
	var out = marks(settings).duplicate(true)
	var k = key(lift_name)
	if k == "":
		return out
	if on == usual(lift_name):
		out.erase(k)
	else:
		out[k] = {"name": lift_name.strip_edges(), "on": on}
	return out


## The marks after a lift was renamed: it stays what it was. `joined`: a lift
## of the new name was there already, and that one's way of counting is kept.
static func renamed(settings: Dictionary, old_name: String, new_name: String, joined: bool) -> Dictionary:
	var was = both(settings, old_name)
	var out = marks(settings).duplicate(true)
	out.erase(key(old_name))
	if joined or key(new_name) == "":
		return out
	var now = {KEY: out}
	if both(now, new_name) != was:
		out = with_mark(now, new_name, was)
	return out


## The names among these that are both sides added up.
static func names(settings: Dictionary, lift_names: Array) -> Array:
	return lift_names.filter(func(nm): return both(settings, str(nm)))


## How many sides the reps of these sets hold: 2 when they are tagged, else 1.
static func of_sets(sets: Array) -> int:
	var out = 1
	for one in sets:
		if one is Dictionary:
			out = maxi(out, int(one.get("sides", 1)))
	return out


## Copies of these sets that say how many sides their reps hold ("sides": 2);
## with 1 side the tag is taken off. The sets given are left as they are.
static func tag_sets(sets: Array, sides: int) -> Array:
	var out = []
	for one in sets:
		if not (one is Dictionary):
			out.append(one)
			continue
		var c = one.duplicate()
		if sides > 1:
			c["sides"] = sides
		else:
			c.erase("sides")
		out.append(c)
	return out


## A lift's history ([{date, id, sets}]) with its sets tagged: new rows, new sets.
static func tagged(history: Array, sides: int) -> Array:
	var out = []
	for h in history:
		var row = h.duplicate()
		row["sets"] = tag_sets(h.get("sets", []), sides)
		out.append(row)
	return out


## The reps of ONE side in a set logged as both: 25 is 12.5.
static func a_side(reps, sides: int = 2) -> float:
	return float(reps) / float(maxi(1, sides))


## The reps of one side over these sets, fewest and most: [12, 13] for sets of
## 24, 25 and 26 (25 is a 12 and a 13). [0, 0] without reps.
static func side_range(sets: Array) -> Array:
	var lo = -1
	var hi = 0
	for one in sets:
		var r = int(one.get("reps", 0)) if one is Dictionary else 0
		if r <= 0:
			continue
		var a = int(floor(r / 2.0))
		var b = int(ceil(r / 2.0))
		lo = a if lo < 0 else mini(lo, a)
		hi = maxi(hi, b)
	return [maxi(0, lo), hi]


## "13 a side", "12 to 13 a side"; "" without reps.
static func side_words(sets: Array) -> String:
	var r = side_range(sets)
	var hi = int(r[1])
	if hi <= 0:
		return ""
	var lo = clampi(int(r[0]), 1, hi)
	if lo == hi:
		return "%d a side" % hi
	return "%d to %d a side" % [lo, hi]


## The best estimate (one-rep max, kg) of these sets going by one side.
static func side_e1rm(sets: Array) -> float:
	return float(LiftTrend.day(tag_sets(sets, 2)).e1rm)


## The results reel says "est. 1RM PR" from the rules, which count reps as
## they were logged. For a lift logged as both sides added up that card is
## worked out again going by one side: its numbers change, and the card goes
## when one side's estimate is no new best. `fresh`: the sessions just
## logged; `before`: the log before them. Returns the events (a new array).
static func fix_estimates(events: Array, fresh: Array, before: Array, settings: Dictionary) -> Array:
	var now = {}
	var names_of = {}
	for s in fresh:
		if str(s.get("discipline", "")) != "lift":
			continue
		for ex in s.get("exercises", []):
			var nm = str(ex.get("name", "")) if ex is Dictionary else ""
			var k = key(nm)
			if k == "" or not both(settings, nm):
				continue
			now[k] = maxf(float(now.get(k, 0.0)), side_e1rm(ex.get("sets", [])))
			names_of[k] = nm
	if now.is_empty():
		return events.duplicate()
	var hist = LiftLibrary.stats(before)
	var out = []
	for ev in events:
		var hit = ""
		if ev is Dictionary and str(ev.get("type", "")) == "pr":
			for k in now:
				if str(ev.get("title", "")) == "%s est. 1RM PR" % Diff._title_case(k):
					hit = k
		if hit == "":
			out.append(ev)
			continue
		var was = 0.0
		var st = hist.get(hit)
		if st != null:
			for h in st.history:
				was = maxf(was, side_e1rm(h.get("sets", [])))
		if was > 0.0 and float(now[hit]) > was + 1e-6:
			var fixed = ev.duplicate()
			var wu = Units.weight_unit(settings)
			if wu == "kg":
				fixed["detail"] = "%s kg (was %s kg), going by one side" % [Diff._trim(float(now[hit])), Diff._trim(was)]
			else:
				fixed["detail"] = "%s (was %s), going by one side" % [Fmt.fmt_weight(float(now[hit]), wu), Fmt.fmt_weight(was, wu)]
			out.append(fixed)
	return out
