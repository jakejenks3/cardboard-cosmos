class_name Misc
extends RefCounted
## Activities outside the four disciplines: a session with discipline "misc"
## and a `kind` from this catalog (for now only the weighted vest walk).
##
## A misc session earns hero XP, so it hits the bosses and the weekly bounty,
## pays coins, can drop loot and counts for the weekly goal and the streak. It
## has no level track of its own and the four disciplines never see it: their
## XP, totals, records and quests are untouched.
##
## A kind says which numbers it takes ("distance", "elevation", "load") and what
## they are worth. A new kind is one more row in KINDS (and its id in ORDER):
## the log form, the phone note, the history and the stats all read this table.
##
## Session fields: kind, distanceM, elevationM, loadKg (the weight carried),
## plus the ones every session has (date, durationSec, title, notes...).
##
## Totals and records live in `state.misc`, made by the first misc session (so
## a log without one has no such key, which keeps the parity tests as they are):
##   {sessions, xp, durationSec,
##    byKind: {kind: {sessions, xp, distanceM, elevationM, durationSec,
##                    loadKm (kg carried x km walked), longestM, heaviestKg}}}

const KINDS = {
	"vest_walk": {
		"name": "Weighted vest walk",
		"short": "Vest walk",
		"icon": "vest",
		"tip": "Distance, time and the weight of the vest",
		"fields": ["distance", "elevation", "load"],
		"loadName": "Vest",
		# Phone-note shorthand: how a line of this kind starts ("vest walk 3km 40:00 10kg"),
		# and the word that sets the weight on a line of its own under it ("vest 10kg").
		"words": ["weighted vest walk", "weighted walk", "vest walk", "vestwalk"],
		"loadWord": "vest",
		# A brisk hour (5 km) with a 9 kg vest is about 490 XP: half a solid hour's
		# run, and every kg in the vest adds 2.5% (a 20 kg vest is +50%).
		"xpPerKm": 60.0,
		"xpPerElevM": 0.8,
		"loadPerKg": 0.025,
		"loadMultMax": 2.0,
		"longestBonus": 75,
	},
}
## The order the kinds are offered in.
const ORDER = ["vest_walk"]
## A kind this version does not know (a save from a newer one): time still counts.
const UNKNOWN = {"name": "Activity", "short": "Activity", "icon": "misc", "tip": "", "fields": [], "loadName": "Load",
	"words": [], "loadWord": "",
	"xpPerKm": 0.0, "xpPerElevM": 0.0, "loadPerKg": 0.0, "loadMultMax": 1.0, "longestBonus": 0}


static func is_misc(s) -> bool:
	return s is Dictionary and str(s.get("discipline", "")) == TT.MISC


static func kind_of(s: Dictionary) -> String:
	return str(TTUtil.get_or(s, "kind", ""))


static func meta(kind) -> Dictionary:
	return KINDS.get(str(kind), UNKNOWN)


static func has_field(kind, field: String) -> bool:
	return meta(kind).fields.has(field)


## The weight carried, in kg (0 for a kind without one).
static func load_kg(s: Dictionary) -> float:
	if not has_field(kind_of(s), "load"):
		return 0.0
	return maxf(0.0, float(TTUtil.get_or(s, "loadKg", 0.0)))


## How much harder the carried weight makes it: x1 with nothing, more per kg, capped.
static func load_mult(kind, kg) -> float:
	var m: Dictionary = meta(kind)
	return minf(float(m.loadMultMax), 1.0 + maxf(0.0, float(kg)) * float(m.loadPerKg))


## The name to show for a session: its own title, else the name of its kind.
static func title(s: Dictionary) -> String:
	var t = TTUtil.get_or(s, "title", "")
	return str(t) if str(t) != "" else str(meta(kind_of(s)).name)


## A draft can be saved when it has what its kind is about: a distance, or for
## a kind without one, a duration.
static func is_valid(s: Dictionary) -> bool:
	if has_field(kind_of(s), "distance"):
		return float(TTUtil.get_or(s, "distanceM", 0.0)) > 0.0
	return int(TTUtil.get_or(s, "durationSec", 0)) > 0


# ---------------------------------------------------------------------------
# Numbers and XP (called by Xp.session_stats / Xp.base_session_xp)
# ---------------------------------------------------------------------------

## Fill the per-session numbers: the same keys a run or ride uses, plus loadKg.
static func fill_stats(s: Dictionary, st: Dictionary) -> void:
	var k: String = kind_of(s)
	st["loadKg"] = load_kg(s)
	if not has_field(k, "distance"):
		return
	st.distanceM = maxf(0.0, float(TTUtil.get_or(s, "distanceM", 0.0)))
	if has_field(k, "elevation"):
		st.elevationM = maxf(0.0, float(TTUtil.get_or(s, "elevationM", 0.0)))
	var dur: float = float(TTUtil.get_or(s, "durationSec", 0))
	if dur > 0.0 and float(st.distanceM) > 0.0:
		st.paceSecPerKm = dur / (float(st.distanceM) / 1000.0)
		st.speedKmh = (float(st.distanceM) / 1000.0) / (dur / 3600.0)


## The XP parts of a misc session, without the time (every session gets that).
static func xp_parts(s: Dictionary, st: Dictionary) -> Array:
	var k: String = kind_of(s)
	var m: Dictionary = meta(k)
	var kg: float = float(TTUtil.get_or(st, "loadKg", 0.0))
	var mult: float = load_mult(k, kg)
	var parts: Array = []
	var km: float = float(st.distanceM) / 1000.0
	if km > 0.0 and float(m.xpPerKm) > 0.0:
		var label: String = TTUtil.to_fixed1(km) + " km"
		if kg > 0.0:
			label += " carrying %s kg" % TTUtil.num_str(snappedf(kg, 0.1))
		parts.append({"label": label, "xp": km * float(m.xpPerKm) * mult})
	var elev: float = float(st.elevationM)
	if elev > 0.0 and float(m.xpPerElevM) > 0.0:
		parts.append({"label": Xp.fmt_int(elev) + " m climbed", "xp": elev * float(m.xpPerElevM) * mult})
	return parts


## "2.1 mi", "40:00", "19:03 /mi", "20 lb vest", "120 ft ↑" in the player's units.
static func summary_parts(s: Dictionary, st: Dictionary, settings: Dictionary) -> Array:
	var k: String = kind_of(s)
	var m: Dictionary = meta(k)
	var du: String = str(settings.distanceUnit)
	var parts: Array = []
	if has_field(k, "distance") and float(st.distanceM) > 0.0:
		parts.append(Fmt.fmt_distance(float(st.distanceM), du))
	var dur: int = int(TTUtil.get_or(s, "durationSec", 0))
	if dur != 0:
		parts.append(Fmt.fmt_duration(dur))
	if st.get("paceSecPerKm") != null:
		parts.append(Fmt.fmt_pace(float(st.paceSecPerKm), du))
	var kg: float = float(TTUtil.get_or(st, "loadKg", 0.0))
	if kg > 0.0:
		parts.append(load_text(k, kg, str(settings.weightUnit)))
	if float(st.elevationM) > 0.0:
		parts.append("%s ↑" % Fmt.fmt_elevation(float(st.elevationM), du))
	return parts


## "20 lb vest".
static func load_text(kind, kg: float, wu: String) -> String:
	return "%s %s" % [Fmt.fmt_weight(kg, wu), str(meta(kind).loadName).to_lower()]


# ---------------------------------------------------------------------------
# Totals and records (called by Derive for every misc session)
# ---------------------------------------------------------------------------

static func _blank_kind() -> Dictionary:
	return {"sessions": 0, "xp": 0, "distanceM": 0.0, "elevationM": 0.0, "durationSec": 0, "loadKm": 0.0,
		"longestM": 0.0, "heaviestKg": 0.0}


## Count a session into `s.misc` and check its records. The first session of a
## kind sets the marks; later ones that beat them are records (the Story gets a
## line, and the longest one pays the kind's bonus).
## Returns {"bonus": record XP, "prs": how many records}.
static func record(s: Dictionary, session: Dictionary, st: Dictionary) -> Dictionary:
	if not (s.get("misc") is Dictionary):
		s["misc"] = {"sessions": 0, "xp": 0, "durationSec": 0, "byKind": {}}
	var k: String = kind_of(session)
	var m: Dictionary = meta(k)
	if not s.misc.byKind.has(k):
		s.misc.byKind[k] = _blank_kind()
	var b: Dictionary = s.misc.byKind[k]
	var out: Dictionary = {"bonus": 0, "prs": 0}
	var dist: float = float(st.distanceM)
	var kg: float = float(TTUtil.get_or(st, "loadKg", 0.0))
	var dur: int = int(st.durationSec)
	if dist > float(b.longestM) + 1e-6:
		if float(b.longestM) > 0.0:
			out.bonus += int(m.longestBonus)
			out.prs += 1
			s.chronicle.append({"date": session.date, "kind": "pr", "icon": "🦺", "title": "Longest " + str(m.short).to_lower(),
				"val": {"n": dist, "unit": "m"}, "discipline": TT.MISC})
		b.longestM = dist
	if kg > float(b.heaviestKg) + 1e-6:
		if float(b.heaviestKg) > 0.0:
			out.prs += 1
			s.chronicle.append({"date": session.date, "kind": "pr", "icon": "🦺", "title": "Heaviest " + str(m.loadName).to_lower(),
				"val": {"n": kg, "unit": "kg"}, "discipline": TT.MISC})
		b.heaviestKg = kg
	b.sessions += 1
	b.distanceM += dist
	b.elevationM += float(st.elevationM)
	b.durationSec += dur
	b.loadKm += kg * dist / 1000.0
	s.misc.sessions += 1
	s.misc.durationSec += dur
	return out


## Credit the session's XP to the misc totals (the hero gets it from Derive).
static func add_xp(s: Dictionary, session: Dictionary, xp: int) -> void:
	if not (s.get("misc") is Dictionary):
		return
	s.misc.xp += xp
	var k: String = kind_of(session)
	if s.misc.byKind.has(k):
		s.misc.byKind[k].xp += xp


# ---------------------------------------------------------------------------
# Reading (safe on a state without misc sessions)
# ---------------------------------------------------------------------------

static func sessions(s: Dictionary) -> int:
	var m = s.get("misc")
	return int(m.sessions) if m is Dictionary else 0


## The totals of one kind, or null when it was never logged.
static func totals(s: Dictionary, kind: String):
	var m = s.get("misc")
	if m is Dictionary and m.byKind.has(kind):
		return m.byKind[kind]
	return null


## The weight carried in the most recent session of `kind` (0 when there is none).
static func last_load_kg(all_sessions: Array, kind: String) -> float:
	var best = null
	for x in all_sessions:
		if not is_misc(x) or kind_of(x) != kind or load_kg(x) <= 0.0:
			continue
		if best == null or str(x.date) > str(best.date) or (str(x.date) == str(best.date) and x.createdAt > best.createdAt):
			best = x
	return load_kg(best) if best != null else 0.0


## Records that `after` holds and `before` did not, for the results reel:
## [{type: "pr", icon, title, detail}] with the numbers in the player's units.
static func record_events(before: Dictionary, after: Dictionary, settings) -> Array:
	var ev: Array = []
	var am = after.get("misc")
	if not (am is Dictionary):
		return ev
	var du: String = str(settings.distanceUnit) if settings is Dictionary else "km"
	var wu: String = str(settings.weightUnit) if settings is Dictionary else "kg"
	for k in am.byKind:
		var a: Dictionary = am.byKind[k]
		var b = totals(before, str(k))
		if b == null:
			continue
		var m: Dictionary = meta(k)
		if float(b.longestM) > 0.0 and float(a.longestM) > float(b.longestM) + 1e-6:
			ev.append({"type": "pr", "icon": "🦺", "title": "Longest %s!" % str(m.short).to_lower(),
				"detail": "%s (was %s)" % [Fmt.fmt_distance(float(a.longestM), du, 2), Fmt.fmt_distance(float(b.longestM), du, 2)]})
		if float(b.heaviestKg) > 0.0 and float(a.heaviestKg) > float(b.heaviestKg) + 1e-6:
			ev.append({"type": "pr", "icon": "🦺", "title": "Heaviest %s!" % str(m.loadName).to_lower(),
				"detail": "%s (was %s)" % [Fmt.fmt_weight(float(a.heaviestKg), wu), Fmt.fmt_weight(float(b.heaviestKg), wu)]})
	return ev
