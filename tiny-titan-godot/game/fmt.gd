class_name Fmt
extends RefCounted
## Unit conversion and all player-facing number formatting (port of format.ts).
##
## JavaScript turns numbers into text in two different ways and both are
## reproduced here by hand, because "%.1f" agrees with neither on .5 ties
## (41.25 kg has to read "41.3", not "41.2"):
##  - `x.toFixed(d)` rounds the exact binary value of the double, exact ties go
##    up in magnitude                                       -> `Fmt.to_fixed(x, d)`
##  - `x.toLocaleString('en-US', {maximumFractionDigits: d})` rounds the
##    shortest decimal spelling of the double half away from zero, drops
##    trailing zeros and groups thousands                   -> `Fmt.fmt_num(x, d)`
## So 1.45 is "1.4" through to_fixed (the double is 1.4499999...) but "1.5"
## through fmt_num (its shortest spelling is 1.45), exactly like in the web app.
##
## Units are the strings stored in Settings: weight "kg" | "lb", distance "km" | "mi".

const KG_PER_LB = 0.45359237
const M_PER_MI = 1609.344


static func kg_to_unit(kg: float, unit: String) -> float:
	return kg if unit == "kg" else kg / KG_PER_LB


static func unit_to_kg(v: float, unit: String) -> float:
	return v if unit == "kg" else v * KG_PER_LB


static func m_to_unit(m: float, unit: String) -> float:
	return m / 1000.0 if unit == "km" else m / M_PER_MI


static func unit_to_m(v: float, unit: String) -> float:
	return v * 1000.0 if unit == "km" else v * M_PER_MI


## `n.toLocaleString('en-US', {maximumFractionDigits: digits, minimumFractionDigits: 0})`:
## "1,234.5", "12", "0.25". `fmt_num(x, 3)` is a bare `x.toLocaleString('en-US')`.
static func fmt_num(n: float, digits: int = 0) -> String:
	if is_nan(n):
		return "NaN"
	if is_inf(n):
		return "∞" if n > 0.0 else "-∞"
	var x: float = absf(n)
	var whole: String = ""
	var frac: String = ""
	if x == floor(x):
		whole = str(int(x))
	else:
		var parts: Array = _split_scaled(_round_shortest(x, digits), digits)
		whole = parts[0]
		frac = parts[1]
		while frac.ends_with("0"):
			frac = frac.substr(0, frac.length() - 1)
	var out: String = _group_thousands(whole)
	if frac != "":
		out += "." + frac
	return ("-" + out) if n < 0.0 else out


## `x.toFixed(digits)`: always exactly `digits` decimals, no thousands separators.
static func to_fixed(x: float, digits: int = 0) -> String:
	if is_nan(x):
		return "NaN"
	if is_inf(x):
		return "Infinity" if x > 0.0 else "-Infinity"
	var parts: Array = _split_scaled(_round_exact(absf(x), digits), digits)
	var out: String = parts[0]
	if digits > 0:
		out += "." + parts[1]
	return ("-" + out) if x < 0.0 else out


## "82.5 kg" / "181.9 lb". Whole numbers never show decimals.
static func fmt_weight(kg: float, unit: String, digits: int = 1) -> String:
	var v: float = kg_to_unit(kg, unit)
	return "%s %s" % [fmt_num(v, 0 if v == floor(v) else digits), unit]


## "5.2 km" / "3.2 mi".
static func fmt_distance(m: float, unit: String, digits: int = 1) -> String:
	return "%s %s" % [fmt_num(m_to_unit(m, unit), digits), unit]


## "1,250 m" for km players, "4,101 ft" for mi players.
static func fmt_elevation(m: float, unit: String) -> String:
	if unit == "km":
		return "%s m" % fmt_num(m)
	return "%s ft" % fmt_num(m * 3.28084)


## "1:02:03" or "2:03".
static func fmt_duration(sec: float) -> String:
	var t: int = TTUtil.jsround(sec)
	var h: int = int(floor(t / 3600.0))
	var m: int = int(floor((t % 3600) / 60.0))
	var s: int = t % 60
	if h != 0:
		return "%s:%s:%s" % [str(h), str(m).lpad(2, "0"), str(s).lpad(2, "0")]
	return "%s:%s" % [str(m), str(s).lpad(2, "0")]


## "45 min", "2h", "1h 30m".
static func fmt_duration_short(sec: float) -> String:
	var m: int = TTUtil.jsround(sec / 60.0)
	if m < 60:
		return "%s min" % str(m)
	var h: int = int(floor(m / 60.0))
	var r: int = m % 60
	if r != 0:
		return "%sh %sm" % [str(h), str(r)]
	return "%sh" % str(h)


## Pace as m:ss per km or per mile: "5:12 /km".
static func fmt_pace(sec_per_km: float, unit: String) -> String:
	var per: float = sec_per_km if unit == "km" else sec_per_km * (M_PER_MI / 1000.0)
	var m: int = int(floor(per / 60.0))
	var s: int = TTUtil.jsround(fmod(per, 60.0))
	return "%s:%s /%s" % [str(m), str(s).lpad(2, "0"), unit]


## "24.3 km/h" / "15.1 mph".
static func fmt_speed(kmh: float, unit: String) -> String:
	if unit == "km":
		return "%s km/h" % to_fixed(kmh, 1)
	return "%s mph" % to_fixed(kmh / (M_PER_MI / 1000.0), 1)


## Lifetime-volume style weights: "8,250 kg", "12.5k kg", "1.25M kg".
static func fmt_big_kg(kg: float, unit: String) -> String:
	var v: float = kg_to_unit(kg, unit)
	if v >= 1000000.0:
		return "%sM %s" % [to_fixed(v / 1000000.0, 2), unit]
	if v >= 10000.0:
		return "%sk %s" % [to_fixed(v / 1000.0, 1), unit]
	return "%s %s" % [fmt_num(v), unit]


## Seconds from three h / m / s inputs. Each one may be a number or the text of
## an input box; anything that is not a number counts as 0.
static func parse_duration_input(h, m, s) -> int:
	var total: float = _to_number(h) * 3600.0 + _to_number(m) * 60.0 + _to_number(s)
	return maxi(0, TTUtil.jsround(total))


## Format a goal value in the player's units. `unit` is a Goals progress unit:
## "count" | "kg" | "m" | "elev" | "level" | "grade" | "weeks" | "xp" | "min" | "ratio".
## `settings` needs `weightUnit` and `distanceUnit`.
static func fmt_goal_value(n: float, unit: String, settings: Dictionary) -> String:
	match unit:
		"kg":
			if kg_to_unit(n, settings.weightUnit) >= 10000.0:
				return fmt_big_kg(n, settings.weightUnit)
			return fmt_weight(n, settings.weightUnit, 1)
		"m":
			return fmt_distance(n, settings.distanceUnit, 0 if n >= 100000.0 else 1)
		"elev":
			return fmt_elevation(n, settings.distanceUnit)
		"level":
			return "Lv %s" % str(int(floor(n)))
		"grade":
			if n < -1.0:
				return "—"
			if n < 0.0:
				return "VB"
			return "V%s" % str(int(floor(n)))
		"weeks":
			return "%s wk" % str(int(floor(n)))
		"xp":
			return "%s XP" % fmt_num(n)
		"min":
			return fmt_duration_short(n * 60.0)
		"ratio":
			return "%s×" % to_fixed(n, 2)
	return fmt_num(floor(n))


## "39 km / 100 km" for a `{cur, target, unit}` progress.
static func fmt_progress(p: Dictionary, settings: Dictionary) -> String:
	var cur = p.cur if p.unit == "grade" else min(p.cur, p.target)
	return "%s / %s" % [fmt_goal_value(cur, p.unit, settings), fmt_goal_value(p.target, p.unit, settings)]


## 0.42 -> "42%".
static func pct(n: float) -> String:
	return "%s%%" % str(TTUtil.jsround(n * 100.0))


# --- number-to-text internals -------------------------------------------------

## JS `Number(v) || 0` for the values an input box can hand over.
static func _to_number(v) -> float:
	if v == null:
		return 0.0
	if v is bool:
		return 1.0 if v else 0.0
	if v is int:
		return float(v)
	if v is float:
		return 0.0 if is_nan(v) else v
	if v is String or v is StringName:
		var t: String = String(v).strip_edges()
		# Number("") is 0, Number("abc") is NaN, and both end up as 0.
		if t.is_valid_float():
			return t.to_float()
	return 0.0


static func _pow10(digits: int) -> float:
	var scale: float = 1.0
	for i in range(digits):
		scale *= 10.0
	return scale


## Veltkamp split of a double into two halves whose products are exact.
static func _split(a: float) -> Array:
	var c: float = 134217729.0 * a
	var hi: float = c - (c - a)
	return [hi, a - hi]


## round-half-up of the EXACT value of x * 10^digits, for x >= 0 (toFixed).
## The product is not exact in floating point (1.45 * 10 would land on 14.5),
## so it is computed as hi + lo with Dekker's error-free multiplication and the
## rounding decision is taken on the pair.
static func _round_exact(x: float, digits: int) -> int:
	var scale: float = _pow10(digits)
	var hi: float = x * scale
	var xs: Array = _split(x)
	var ss: Array = _split(scale)
	var lo: float = ((xs[0] * ss[0] - hi) + xs[0] * ss[1] + xs[1] * ss[0]) + xs[1] * ss[1]
	var fl: float = floor(hi)
	var rem: float = (hi - fl) - 0.5
	var n: int = int(fl)
	if rem + lo >= 0.0:
		n += 1
	return n


## round-half-up of the SHORTEST DECIMAL SPELLING of x times 10^digits, for
## x >= 0 (toLocaleString). The shortest spelling of x is at or above a tie
## point (k + 0.5) / 10^digits exactly when x is at or above the double nearest
## to that tie point, and one IEEE division gives that double.
static func _round_shortest(x: float, digits: int) -> int:
	var scale: float = _pow10(digits)
	var den: float = 2.0 * scale
	var k: int = int(floor(x * scale + 0.5))
	while k > 0 and float(2 * k - 1) / den > x:
		k -= 1
	while float(2 * k + 1) / den <= x:
		k += 1
	return k


## 12345 with 2 digits -> ["123", "45"]; 5 with 2 digits -> ["0", "05"].
static func _split_scaled(k: int, digits: int) -> Array:
	var ks: String = str(k).lpad(digits + 1, "0")
	var cut: int = ks.length() - digits
	return [ks.substr(0, cut), ks.substr(cut)]


static func _group_thousands(whole: String) -> String:
	var out: String = ""
	var count: int = whole.length()
	for i in range(count):
		if i > 0 and (count - i) % 3 == 0:
			out += ","
		out += whole[i]
	return out
