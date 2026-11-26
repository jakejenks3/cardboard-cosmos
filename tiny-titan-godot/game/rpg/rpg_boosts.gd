class_name RpgBoosts
extends RefCounted
## The Realm's boosts and training chests (RPG_PLAN.md 3): what today's and
## yesterday's training is worth in a fight. Derived from the log, never
## stored (only "this chest was paid" is, in saved.rpg.chests). Pure: no
## autoload, no screen.
##
##   active(input)                 the boosts in force today
##   schools(boosts)               the attack schools they favour (the daily hunt)
##   fx(boosts)                    their passive effects in one list
##   chest(input, date)            the training chest of today or yesterday
##   chest_pay(chest, rpg)         what opening it pays now (the difference rule)
##   waiting(input, rpg)           the chests with something to pay
##   chest_waiting(state, reading, rpg, today)   the tab dot's cheap check
##
## A boost earned on day D is in force on D and D + 1 and then gone; earned on
## both days, the stronger one counts (the same strength: today's, which lasts
## until tomorrow). A boost is always a bonus on top of 100%, never a penalty,
## and a rest day earns its own (well_rested).
##
## `input` is the stat sheet's (RpgStats.sheet): {"sessions", "state",
## "reading", "books", "body", "claims", "settings", "marks", "today"}.
## Effects are passive effects of the plan's vocabulary (section 6), every
## percentage a fraction: {"p": "stat_dmg", "stat": "chest", "pct": 0.15}.

## A run: Speed moves and speed, for any run and for one of RpgDefs.LONG_RUN_M.
const RUN_PCT = [0.10, 0.15]
const RUN_SPD = [0.05, 0.08]
## Energy at the start after a long run.
const RUN_EN = 1
## A climbing session: Grip moves and crit, without and with a flash that day.
const CLIMB_PCT = [0.10, 0.15]
const CLIMB_CRIT = [0.04, 0.06]
## The hero's debuffs last this many turns longer at the top reading tier.
const READ_TURNS = 1
## Healing after RpgDefs.MOBILITY_SETS[1] mobility sets.
const LIMBER_HEAL = 0.20
## Well rested: no strength work yesterday, and REST_MIN training days or more
## in the REST_DAYS days before it.
const REST_DAYS = 6
const REST_MIN = 2
const REST_HP = 0.10
const REST_EN = 2
## The gauge after a record.
const RUSH_GAUGE = 50
const GOLD_ORE = 0.25
## On a roll: training on ROLL_MIN of the last ROLL_DAYS days.
const ROLL_DAYS = 7
const ROLL_MIN = 4
const ROLL_ORE = 0.10

## What a day can hold, in the order a chest lists it.
const KINDS = ["lift", "run", "climb", "read", "mobility", "other"]
const KIND_NAMES = {"lift": "Lifting", "run": "A run", "climb": "Climbing", "read": "Reading", "mobility": "Mobility", "other": "Other training"}
## Pages that make reading one of a day's kinds (the first reading tier).
const CHEST_PAGES = 10
const TIERS = ["wood", "iron", "gold"]
## Kinds that make an iron chest.
const IRON_KINDS = 3
const CHEST_ITEMS_N = {"wood": 1, "iron": 2, "gold": 3}
const CHEST_ICONS = {"wood": "chest_wood", "iron": "chest_iron", "gold": "chest_gold"}
## What a chest's items are drawn from: [RpgItems id, weight]. The ids are
## written out here and the item catalog is NOT asked: this file is loaded with
## the tab bar (chest_waiting), so it must not pull the battle engine in with
## it, and whoever pays a chest skips an id it does not know (plan 11.0).
const CHEST_ITEMS = [["protein_shake", 4.0], ["electrolytes", 3.0], ["chalk_ball", 3.0], ["energy_gel", 3.0], ["ice_pack", 3.0],
	["smelling_salts", 2.0], ["pre_workout", 2.0], ["mega_shake", 1.0]]

## The attack schools a pumped body stat favours.
const PUMP_SCHOOLS = {"chest": ["push"], "shoulders": ["push"], "arms": ["push", "pull"], "back": ["pull"], "core": ["legs"], "legs": ["legs"]}
const BOOST_SCHOOLS = {"second_wind": ["speed"], "chalked_up": ["grip"], "sharp_mind": ["mind"]}


static func _arr(v) -> Array:
	return v if v is Array else []


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func _num(v) -> float:
	return float(v) if (v is int or v is float) else 0.0


static func _today(input: Dictionary) -> String:
	var today = str(input.get("today", ""))
	return today if today != "" else Dates.today_key()


static func _pct(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))


static func _when(date: String, today: String) -> String:
	return "today" if date == today else "yesterday"


# ---------------------------------------------------------------------------
# What a day held
# ---------------------------------------------------------------------------

static func _blank_day() -> Dictionary:
	return {"n": 0, "sets": {}, "mobility": 0, "strength": false, "run": false, "run_m": 0.0, "climb": false, "flash": false,
		"other": false, "pages": 0, "pr": "", "perfect": false}


## What each day from `from` to `to` held (date keys, both included), for the
## days with anything: {date: {"n" (sessions), "sets" ({body stat: sets}),
## "mobility" (PT and stretch sets), "strength" (a lift that is not mobility),
## "run", "run_m" (the longest run, a race distance counted as it), "climb",
## "flash", "other" (a ride, a vest walk, any other session), "pages", "pr"
## (the title of a record of that day, "" none), "perfect" (its perfect-day
## chest was claimed)}}. One pass over the sessions; the days outside are
## skipped on their date.
static func day_facts(input: Dictionary, from: String, to: String) -> Dictionary:
	var marks = _dict(input.get("marks"))
	var out = {}
	for s in _arr(input.get("sessions")):
		if not (s is Dictionary):
			continue
		var d = str(s.get("date", ""))
		if d < from or d > to:
			continue
		if not out.has(d):
			out[d] = _blank_day()
		var day = out[d]
		day.n = int(day.n) + 1
		var disc = str(s.get("discipline", ""))
		if disc == "lift":
			var got = RpgStats.lift_sets(s, marks)
			for p in got.sets:
				day.sets[p] = float(day.sets.get(p, 0.0)) + float(got.sets[p])
			day.mobility = int(day.mobility) + int(got.mobility)
			if bool(got.strength):
				day.strength = true
			elif int(got.mobility) == 0:
				day.other = true
		elif disc == "run":
			day.run = true
			day.run_m = maxf(float(day.run_m), _num(RunSplits.counted(_num(s.get("distanceM")))))
		elif disc == "climb":
			day.climb = true
			for c in _arr(s.get("climbs")):
				if c is Dictionary and str(c.get("result", "")) == "flash" and int(_num(c.get("count"))) > 0:
					day.flash = true
		else:
			day.other = true
	for e in _arr(input.get("reading")):
		if not (e is Dictionary):
			continue
		var d = str(e.get("date", ""))
		var pages = int(_num(e.get("pages")))
		if d < from or d > to or pages <= 0:
			continue
		if not out.has(d):
			out[d] = _blank_day()
		out[d].pages = int(out[d].pages) + pages
	for e in _arr(_dict(input.get("state")).get("chronicle")):
		if not (e is Dictionary) or str(e.get("kind", "")) != "pr":
			continue
		var d = str(e.get("date", ""))
		if d < from or d > to:
			continue
		if not out.has(d):
			out[d] = _blank_day()
		if str(out[d].pr) == "":
			out[d].pr = str(e.get("title", "A record"))
	for c in _arr(input.get("claims")):
		if not (c is Dictionary):
			continue
		var d = RpgStats.perfect_day_of(c)
		if d == "" or d < from or d > to:
			continue
		if not out.has(d):
			out[d] = _blank_day()
		out[d].perfect = true
	return out


static func _day(days: Dictionary, date: String) -> Dictionary:
	var d = days.get(date)
	return d if d is Dictionary else _blank_day()


## Which of KINDS a day held, in that order.
static func kinds_of(day: Dictionary) -> Array:
	var out = []
	if bool(day.strength):
		out.append("lift")
	if bool(day.run):
		out.append("run")
	if bool(day.climb):
		out.append("climb")
	if int(day.pages) >= CHEST_PAGES:
		out.append("read")
	if int(day.mobility) > 0:
		out.append("mobility")
	if bool(day.other):
		out.append("other")
	return out


# ---------------------------------------------------------------------------
# The boosts
# ---------------------------------------------------------------------------

static func _boost(id: String, boost_name: String, icon: String, school: String, text: String, why: String, from: String, days: int, effects: Array, tier: int) -> Dictionary:
	return {"id": id, "name": boost_name, "icon": icon, "school": school, "text": text, "why": why,
		"from": from, "until": Dates.add_days(from, days), "fx": effects, "tier": tier}


## Of a boost earned today and the same one earned yesterday (either may be
## null): the stronger, and of two as strong today's.
static func _stronger(mine, older):
	if mine == null:
		return older
	if older == null or int(mine.tier) >= int(older.tier):
		return mine
	return older


static func _pump(stat: String, day: Dictionary, date: String, when: String):
	var sets = float(day.sets.get(stat, 0.0))
	var t = RpgDefs.tier_index(sets + 1e-9, RpgDefs.PUMP_SETS)
	if t < 0:
		return null
	var pct = float(RpgDefs.PUMP_PCT[t])
	var stat_name = str(RpgDefs.STAT_NAMES[stat])
	return _boost("pump_" + stat, "%s Pump" % stat_name, str(RpgDefs.STAT_ICONS[stat]), str(RpgDefs.STAT_SCHOOL[stat]),
		"%s moves +%s damage" % [stat_name, _pct(pct)],
		"%s %s sets %s" % [Fmt.fmt_num(sets, 1), str(RpgStats.PART_WORDS[stat]), when],
		date, 1, [{"p": "stat_dmg", "stat": stat, "pct": pct}], t + 1)


static func _second_wind(day: Dictionary, date: String, when: String, du: String):
	if not bool(day.run):
		return null
	var t = 1 if float(day.run_m) >= RpgDefs.LONG_RUN_M else 0
	var effects = [{"p": "school_pct", "school": "speed", "pct": float(RUN_PCT[t])}, {"p": "spd_pct", "pct": float(RUN_SPD[t])}]
	var text = "Speed moves +%s, speed +%s" % [_pct(float(RUN_PCT[t])), _pct(float(RUN_SPD[t]))]
	if t == 1:
		effects.append({"p": "en_start", "n": RUN_EN})
		text += ", +%d energy at the start" % RUN_EN
	var far = Fmt.fmt_distance(float(day.run_m), du)
	return _boost("second_wind", "Second Wind", "sch_speed", "speed", text, "A %s run %s" % [far, when] if float(day.run_m) > 0.0 else "A run %s" % when,
		date, 1, effects, t + 1)


static func _chalked_up(day: Dictionary, date: String, when: String):
	if not bool(day.climb):
		return null
	var t = 1 if bool(day.flash) else 0
	return _boost("chalked_up", "Chalked Up", "sch_grip", "grip",
		"Grip moves +%s, crit +%s" % [_pct(float(CLIMB_PCT[t])), _pct(float(CLIMB_CRIT[t]))],
		"A climbing session %s%s" % [when, ", with a flash" if t == 1 else ""],
		date, 1, [{"p": "school_pct", "school": "grip", "pct": float(CLIMB_PCT[t])}, {"p": "crit_add", "v": float(CLIMB_CRIT[t])}], t + 1)


static func _sharp_mind(day: Dictionary, date: String, when: String):
	var t = RpgDefs.tier_index(float(int(day.pages)), RpgDefs.READ_PAGES)
	if t < 0:
		return null
	var pct = float(RpgDefs.READ_PCT[t])
	var effects = [{"p": "school_pct", "school": "mind", "pct": pct}]
	var text = "Mind moves +%s" % _pct(pct)
	if t == RpgDefs.READ_PAGES.size() - 1:
		effects.append({"p": "status_turns", "on": "debuff", "add": READ_TURNS})
		text += ", your debuffs last %d turn longer" % READ_TURNS
	return _boost("sharp_mind", "Sharp Mind", "sch_mind", "mind", text, "%d pages read %s" % [int(day.pages), when], date, 1, effects, t + 1)


static func _limber(day: Dictionary, date: String, when: String):
	var t = RpgDefs.tier_index(float(int(day.mobility)), RpgDefs.MOBILITY_SETS)
	if t < 0:
		return null
	var effects = [{"p": "bounce"}]
	var text = "The first debuff of a battle bounces off"
	if t >= 1:
		effects.append({"p": "heal_pct", "pct": LIMBER_HEAL})
		text += ", healing +%s" % _pct(LIMBER_HEAL)
	return _boost("limber", "Limber", "sch_flow", "flow", text, "%d sets of physical therapy and stretches %s" % [int(day.mobility), when],
		date, 1, effects, t + 1)


## Today only: yesterday was a rest from lifting after days of training.
static func _well_rested(days: Dictionary, today: String):
	var yday = Dates.add_days(today, -1)
	if bool(_day(days, yday).strength):
		return null
	var trained = 0
	for k in range(REST_DAYS):
		if int(_day(days, Dates.add_days(yday, -(k + 1))).n) > 0:
			trained += 1
	if trained < REST_MIN:
		return null
	return _boost("well_rested", "Well Rested", "moon", "",
		"Max HP +%s, +%d energy at the start" % [_pct(REST_HP), REST_EN],
		"No lifting yesterday, after %d training days in the %d before it" % [trained, REST_DAYS],
		today, 0, [{"p": "hp_pct", "pct": REST_HP}, {"p": "en_start", "n": REST_EN}], 1)


static func _record_rush(day: Dictionary, date: String, when: String):
	if str(day.pr) == "":
		return null
	return _boost("record_rush", "Record Rush", "trophy", "grit", "The ultimate gauge starts at %d" % RUSH_GAUGE,
		"A record %s: %s" % [when, str(day.pr)], date, 1, [{"p": "gauge_start", "n": RUSH_GAUGE}], 1)


static func _golden_day(day: Dictionary, date: String, when: String):
	if not bool(day.perfect):
		return null
	return _boost("golden_day", "Golden Day", "chest_gold", "", "Ore from battles +%s" % _pct(GOLD_ORE),
		"A perfect day %s" % when, date, 1, [{"p": "reward", "what": "ore", "pct": GOLD_ORE}], 1)


static func _on_a_roll(days: Dictionary, date: String, when: String):
	var trained = 0
	for k in range(ROLL_DAYS):
		if int(_day(days, Dates.add_days(date, -k)).n) > 0:
			trained += 1
	if trained < ROLL_MIN:
		return null
	return _boost("on_a_roll", "On a Roll", "flame", "grit", "Ore from battles +%s" % _pct(ROLL_ORE),
		"Trained on %d of the %d days up to %s" % [trained, ROLL_DAYS, when], date, 1, [{"p": "reward", "what": "ore", "pct": ROLL_ORE}], 1)


## The boosts in force today, in the plan's order: [{"id", "name", "icon",
## "school" (for the colour, "" = neutral), "text" (what it does), "why"
## (what earned it), "from" (the day it was earned), "until" (the last day it
## holds: today, or tomorrow), "fx": [passive effects], "tier" (1 up: how
## strong, for the screens)}].
static func active(input: Dictionary) -> Array:
	var today = _today(input)
	var yday = Dates.add_days(today, -1)
	var du = "mi" if str(_dict(input.get("settings")).get("distanceUnit", "km")) == "mi" else "km"
	var days = day_facts(input, Dates.add_days(today, -(maxi(ROLL_DAYS, REST_DAYS + 1))), today)
	var now = _day(days, today)
	var was = _day(days, yday)
	var out = []
	for stat in RpgDefs.BODY:
		out.append(_stronger(_pump(stat, now, today, "today"), _pump(stat, was, yday, "yesterday")))
	out.append(_stronger(_second_wind(now, today, "today", du), _second_wind(was, yday, "yesterday", du)))
	out.append(_stronger(_chalked_up(now, today, "today"), _chalked_up(was, yday, "yesterday")))
	out.append(_stronger(_sharp_mind(now, today, "today"), _sharp_mind(was, yday, "yesterday")))
	out.append(_stronger(_limber(now, today, "today"), _limber(was, yday, "yesterday")))
	out.append(_well_rested(days, today))
	out.append(_stronger(_record_rush(now, today, "today"), _record_rush(was, yday, "yesterday")))
	out.append(_stronger(_golden_day(now, today, "today"), _golden_day(was, yday, "yesterday")))
	out.append(_stronger(_on_a_roll(days, today, "today"), _on_a_roll(days, yday, "yesterday")))
	return out.filter(func(b): return b != null)


## The attack schools some boosts favour, the most favoured first (a pump of
## chest or shoulders: push; back: pull; arms: push and pull; legs or core:
## legs; second_wind: speed; chalked_up: grip; sharp_mind: mind). The daily
## hunt makes these its foes' weaknesses. [] when no boost favours a school.
static func schools(boosts: Array) -> Array:
	var score = {}
	for b in boosts:
		if not (b is Dictionary):
			continue
		var id = str(b.get("id", ""))
		var list = BOOST_SCHOOLS.get(id, [])
		if id.begins_with("pump_"):
			list = PUMP_SCHOOLS.get(id.substr(5), [])
		var best = 0.0
		for e in _arr(b.get("fx")):
			if e is Dictionary and (str(e.get("p", "")) == "stat_dmg" or str(e.get("p", "")) == "school_pct"):
				best = maxf(best, _num(e.get("pct")))
		for sc in list:
			score[sc] = maxf(float(score.get(sc, 0.0)), best)
	var out = []
	for sc in RpgDefs.ATTACK_SCHOOLS:
		if score.has(sc):
			out.append(sc)
	# (a stable order: the strongest first, then the order of the schools)
	out.sort_custom(func(a, b):
		if float(score[a]) != float(score[b]):
			return float(score[a]) > float(score[b])
		return RpgDefs.ATTACK_SCHOOLS.find(a) < RpgDefs.ATTACK_SCHOOLS.find(b))
	return out


## Every passive effect of some boosts, in their order.
static func fx(boosts: Array) -> Array:
	var out = []
	for b in boosts:
		if b is Dictionary:
			out.append_array(_arr(b.get("fx")))
	return out


# ---------------------------------------------------------------------------
# The training chest
# ---------------------------------------------------------------------------

## `count` items for the chest of a date: [{"id", "n"}], drawn from
## CHEST_ITEMS. Seeded by the date, one draw after another, so a chest that
## grows keeps what it had.
static func chest_items(date: String, count: int) -> Array:
	var out = []
	var st = Rng.make_rng("chest:" + date)
	for i in range(count):
		var row = st.weighted(CHEST_ITEMS, func(r): return float(r[1]))
		if row == null:
			continue
		var found = false
		for it in out:
			if str(it.id) == str(row[0]):
				it.n = int(it.n) + 1
				found = true
		if not found:
			out.append({"id": str(row[0]), "n": 1})
	return out


## The training chest of a day that had a session, CHEST_PAGES pages or a
## mobility set: {"date", "kinds" (which of KINDS happened), "tier" ("wood",
## "iron" at IRON_KINDS kinds, "gold" on a perfect day), "ore", "items":
## [{"id", "n"}], "rune" (a gold chest holds one: RpgLoot rolls it)}. Null for
## a day with none of those, and for any day but today and yesterday: only
## those two can be opened.
static func chest(input: Dictionary, date: String):
	var today = _today(input)
	if date != today and date != Dates.add_days(today, -1):
		return null
	var day = _day(day_facts(input, date, date), date)
	var kinds = kinds_of(day)
	if kinds.is_empty():
		return null
	var tier = "gold" if bool(day.perfect) else ("iron" if kinds.size() >= IRON_KINDS else "wood")
	return {"date": date, "kinds": kinds, "tier": tier, "ore": RpgDefs.CHEST_ORE + RpgDefs.CHEST_ORE_KIND * kinds.size(),
		"items": chest_items(date, int(CHEST_ITEMS_N[tier])), "rune": tier == "gold"}


## The kinds of a day's chest already paid (saved.rpg.chests[date]).
static func paid_kinds(rpg: Dictionary, date: String) -> int:
	return maxi(0, int(_num(_dict(rpg.get("chests")).get(date))))


## What opening a chest pays now: {"date", "first" (never opened), "kinds"
## (to store as saved.rpg.chests[date]), "ore", "items", "rune"}. Never
## opened: all of it. Opened when the day held fewer kinds: the ore of the
## kinds that came since, and nothing else. Otherwise nothing ("ore" 0).
static func chest_pay(a_chest: Dictionary, rpg: Dictionary) -> Dictionary:
	var date = str(a_chest.get("date", ""))
	var kinds = _arr(a_chest.get("kinds")).size()
	var paid = paid_kinds(rpg, date)
	if paid <= 0:
		return {"date": date, "first": true, "kinds": kinds, "ore": int(a_chest.get("ore", 0)),
			"items": _arr(a_chest.get("items")).duplicate(true), "rune": bool(a_chest.get("rune", false))}
	return {"date": date, "first": false, "kinds": maxi(kinds, paid), "ore": RpgDefs.CHEST_ORE_KIND * maxi(0, kinds - paid), "items": [], "rune": false}


## Does opening this chest pay anything?
static func pays(a_chest: Dictionary, rpg: Dictionary) -> bool:
	var pay = chest_pay(a_chest, rpg)
	return bool(pay.first) or int(pay.ore) > 0


## The chests with something to pay, today's first: [{"chest", "pay"}].
static func waiting(input: Dictionary, rpg: Dictionary) -> Array:
	var today = _today(input)
	var out = []
	for date in [today, Dates.add_days(today, -1)]:
		var c = chest(input, date)
		if c != null and pays(c, rpg):
			out.append({"chest": c, "pay": chest_pay(c, rpg)})
	return out


## Is a training chest waiting (today's or yesterday's)? A cheap check for the
## tab's dot, called on every change: it looks only at state.dateCounts (was
## there a session), the reading entries of the two days and rpg.chests. It
## cannot tell a day's kinds apart, so it knows a chest never opened, and one
## opened before a session or the day's pages came; `waiting` knows the rest.
static func chest_waiting(state: Dictionary, reading: Array, rpg: Dictionary, today: String) -> bool:
	if today == "":
		return false
	var counts = _dict(state.get("dateCounts"))
	var yday = Dates.add_days(today, -1)
	var pages = {today: 0, yday: 0}
	for e in reading:
		if e is Dictionary and pages.has(e.get("date")):
			pages[e.date] = int(pages[e.date]) + int(_num(e.get("pages")))
	for date in [today, yday]:
		var least = (1 if int(_num(counts.get(date))) > 0 else 0) + (1 if int(pages[date]) >= CHEST_PAGES else 0)
		if least > paid_kinds(rpg, date):
			return true
	return false
