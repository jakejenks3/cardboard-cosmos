class_name TTUtil
extends RefCounted
## Small helpers shared by the whole port. They paper over the places where
## GDScript and JavaScript disagree (rounding, sort stability, JSON numbers,
## number-to-text, truthiness).


## JS `Math.round`: nearest integer, exact halves go up (towards +infinity).
## Written as floor + compare instead of floor(x + 0.5) so that values just
## below a half (0.49999999999999994) do not get pushed over by the addition.
static func jsround(x: float) -> int:
	var f: float = floor(x)
	if x - f >= 0.5:
		return int(f) + 1
	return int(f)


## Stable in-place sort (merge sort). `less.call(a, b)` must return true when
## `a` has to come before `b`. Elements that compare equal keep their order,
## exactly like JS `Array.prototype.sort`; `Array.sort_custom` does not.
static func stable_sort(arr: Array, less: Callable) -> void:
	var n: int = arr.size()
	if n < 2:
		return
	var sorted: Array = _merge_sort(arr, less)
	for i in range(n):
		arr[i] = sorted[i]


static func _merge_sort(arr: Array, less: Callable) -> Array:
	var n: int = arr.size()
	if n <= 1:
		return arr
	var mid: int = n >> 1
	var left: Array = _merge_sort(arr.slice(0, mid), less)
	var right: Array = _merge_sort(arr.slice(mid), less)
	var out: Array = []
	var i: int = 0
	var j: int = 0
	var ln: int = left.size()
	var rn: int = right.size()
	while i < ln and j < rn:
		# Take from the right half only when it is strictly smaller: ties keep
		# the left (earlier) element first, which is what makes this stable.
		if less.call(right[j], left[i]):
			out.append(right[j])
			j += 1
		else:
			out.append(left[i])
			i += 1
	while i < ln:
		out.append(left[i])
		i += 1
	while j < rn:
		out.append(right[j])
		j += 1
	return out


## Godot's JSON parser returns every number as a float. This turns the
## integral ones back into ints (recursively, in place) so that `reps`,
## `count`, `grade`, `createdAt` ... behave like they do in JS. Returns `v`.
static func normalize_json(v):
	if v is float:
		if is_finite(v) and v == floor(v) and absf(v) < 9.0e15:
			return int(v)
		return v
	if v is Dictionary:
		for k in v.keys():
			v[k] = normalize_json(v[k])
		return v
	if v is Array:
		for i in range(v.size()):
			v[i] = normalize_json(v[i])
		return v
	return v


## Number to text without a trailing ".0": 5.0 -> "5", 2.5 -> "2.5".
static func num_str(x) -> String:
	if x == null:
		return ""
	if x is int:
		return str(x)
	if x is float:
		if is_finite(x) and x == floor(x) and absf(x) < 9.0e15:
			return str(int(x))
		return str(x)
	return str(x)


## Deep copy of a Dictionary/Array; every other value is passed through.
static func deep_copy(v):
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


static func clampf01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


## "#d95926" -> Color.
static func hex_color(hex: String) -> Color:
	return Color.html(hex)


# --- extras (not in the original helper list) --------------------------------

## JS truthiness for the values that show up in save data: null, false, 0,
## NaN and "" are falsy; everything else (including empty Arrays/Dictionaries,
## which are truthy objects in JS) is truthy.
static func truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int:
		return v != 0
	if v is float:
		return v != 0.0 and not is_nan(v)
	if v is String:
		return v != ""
	if v is StringName:
		return String(v) != ""
	return true


## `d[key] ?? fallback`: the value, or `fallback` when the key is missing OR
## present with a null value (`Dictionary.get(key, fallback)` only covers the
## first case).
static func get_or(d: Dictionary, key, fallback = null):
	var v = d.get(key)
	if v == null:
		return fallback
	return v


## JS `arr.includes(x)` for numbers. `Array.has` is type-strict in Godot
## (`[1, 2.5, 5].has(5.0)` is false), this compares numerically.
static func has_number(arr: Array, x) -> bool:
	if x == null:
		return false
	for item in arr:
		if (item is int or item is float) and item == x:
			return true
	return false


## JS `x.toFixed(1)` for non-negative numbers. "%.1f" rounds exact ties to
## even ("%.1f" % 0.25 is "0.2"), JS rounds them up ("0.3"). A decimal tie at
## one digit is only exactly representable for x.25 / x.75.
static func to_fixed1(x: float) -> String:
	var q: float = x * 4.0
	if x >= 0.0 and x < 1.0e12 and q == floor(q) and fmod(q, 2.0) == 1.0:
		var n: int = int(floor(x * 10.0)) + 1
		return "%d.%d" % [int(floor(n / 10.0)), n % 10]
	return "%.1f" % x
