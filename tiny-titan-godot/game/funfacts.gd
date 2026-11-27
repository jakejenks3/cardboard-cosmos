class_name FunFacts
extends RefCounted
## Lifetime totals, put in perspective (port of funfacts.ts).
##
## FunFact: {icon: String, headline: String (e.g. "3.0 elephants"), detail: String}

# Each scale is a list of [name, size, icon], smallest first; the largest
# thing the total covers at least once is the one that gets shown.
const _WEIGHT = [
	["house cats", 4.5, "🐈"],
	["grand pianos", 450, "🎹"],
	["cars", 1500, "🚗"],
	["elephants", 5000, "🐘"],
	["blue whales", 150000, "🐋"],
	["Eiffel Towers", 10100000, "🗼"],
]
const _HEIGHT = [
	["giraffes", 5, "🦒"],
	["Statues of Liberty", 93, "🗽"],
	["Eiffel Towers", 330, "🗼"],
	["El Capitans", 914, "🧗"],
	["Mount Everests", 8849, "🏔️"],
]
const _RUN = [
	["laps of a track", 400, "🏟️"],
	["marathons", 42195, "🏅"],
	["lengths of Great Britain", 1407000, "🇬🇧"],
	["crossings of the USA", 4500000, "🗺️"],
	["laps of the Earth", 40075000, "🌍"],
]
const _RIDE = [
	["Tour de France stages", 170000, "🚴"],
	["Tours de France", 3400000, "🇫🇷"],
	["laps of the Earth", 40075000, "🌍"],
]


## {name, n, icon} of the biggest unit that fits into `total`, or null.
static func _pick(total: float, scale: Array):
	var best = null
	for row in scale:
		var n: float = total / row[1]
		if n >= 1.0:
			best = {"name": row[0], "n": n, "icon": row[2]}
	return best


static func _num(n: float) -> String:
	if n >= 100.0:
		return Fmt.fmt_num(TTUtil.jsround(n))
	if n >= 10.0:
		return Fmt.to_fixed(n, 0)
	return Fmt.to_fixed(n, 1)


static func _fact(icon: String, headline: String, detail: String) -> Dictionary:
	return {"icon": icon, "headline": headline, "detail": detail}


static func fun_facts(s: Dictionary) -> Array:
	var out: Array = []
	var t: Dictionary = s.totals
	var w = _pick(t.liftVolumeKg, _WEIGHT)
	if w != null:
		out.append(_fact(w.icon, "%s %s" % [_num(w.n), w.name], "lifted, in total volume"))
	# A boulder problem is roughly 4 m of climbing.
	var climbed = t.climbSends * 4
	var c = _pick(climbed, _HEIGHT)
	if c != null:
		out.append(_fact(c.icon, "%s %s" % [_num(c.n), c.name], "of rock climbed (%s sends)" % TTUtil.num_str(t.climbSends)))
	var r = _pick(t.runDistanceM, _RUN)
	if r != null:
		out.append(_fact(r.icon, "%s %s" % [_num(r.n), r.name], "covered on foot"))
	var b = _pick(t.rideDistanceM, _RIDE)
	if b != null:
		out.append(_fact(b.icon, "%s %s" % [_num(b.n), b.name], "ridden"))
	var e = _pick(t.runElevationM + t.rideElevationM, _HEIGHT)
	if e != null:
		out.append(_fact(e.icon, "%s %s" % [_num(e.n), e.name], "of elevation gained running and riding"))
	var hours: float = t.durationSec / 3600.0
	if hours >= 2.0:
		out.append(_fact("🎬", "%s feature films" % _num(hours / 2.0), "worth of training (%s hours)" % _num(hours)))
	if s.campaign.totalDamage >= 1000:
		out.append(_fact("💥", "%s damage" % Fmt.fmt_num(TTUtil.jsround(s.campaign.totalDamage)), "dealt to %s defeated bosses and counting" % str(s.campaign.defeated.size())))
	return out
