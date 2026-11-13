class_name Rng
extends RefCounted
## Small deterministic PRNG (port of rng.ts). Loot is rolled from a seed
## derived from the session id so replaying the log always reproduces the same
## drops. Both functions reproduce the JavaScript output bit for bit.
##
## Usage:
##   var rng = Rng.make_rng("drop:" + session_id)   # or an integer seed
##   rng.next()                  -> float in [0, 1)
##   rng.int(max_exclusive)      -> int in [0, max_exclusive)   (alias: rng.next_int)
##   rng.pick(arr)               -> one element (null for an empty array)
##   rng.weighted(arr, weight)   -> one element or null; `weight` is a
##                                  Callable(element) -> number
## The returned object is an `Rng.Stream` (RefCounted): call its methods
## directly, exactly like the TS object (`rng.next()`, not `rng.next.call()`).

const _MASK32 = 0xFFFFFFFF


## JS `Math.imul(a, b) >>> 0` for operands already masked to 32 bits. Split
## into 16-bit halves so that nothing ever exceeds 64 bits.
static func _imul(a: int, b: int) -> int:
	var ah: int = (a >> 16) & 0xFFFF
	var al: int = a & 0xFFFF
	var bh: int = (b >> 16) & 0xFFFF
	var bl: int = b & 0xFFFF
	return ((al * bl) + (((ah * bl + al * bh) & 0xFFFF) << 16)) & _MASK32


## FNV-1a over the UTF-16 code units of the string (what JS `charCodeAt`
## iterates), returned as an unsigned 32-bit int.
static func hash_string(text: String) -> int:
	var h: int = 2166136261
	for i in range(text.length()):
		var cp: int = text.unicode_at(i)
		if cp > 0xFFFF:
			# Godot strings hold whole code points; JS sees a surrogate pair.
			cp -= 0x10000
			h = _imul((h ^ (0xD800 + (cp >> 10))) & _MASK32, 16777619)
			h = _imul((h ^ (0xDC00 + (cp & 0x3FF))) & _MASK32, 16777619)
		else:
			h = _imul((h ^ cp) & _MASK32, 16777619)
	return h & _MASK32


## A mulberry32 stream. `seed_value` is a String (hashed with `hash_string`)
## or a number (taken as an unsigned 32-bit int); a zero seed becomes 1.
static func make_rng(seed_value) -> Stream:
	var s: int = 0
	if seed_value is String or seed_value is StringName:
		s = hash_string(String(seed_value))
	elif seed_value is int or seed_value is float:
		s = int(seed_value) & _MASK32
	if s == 0:
		s = 1
	return Stream.new(s)


## Unique-enough id: `prefix` + base36(now in ms) + base36(random 32-bit).
static func uid(prefix: String = "") -> String:
	var t: String = _base36(int(Time.get_unix_time_from_system() * 1000.0))
	var r: String = _base36(randi() % 0xFFFFFFFF)
	return prefix + t + r


static func _base36(value: int) -> String:
	if value <= 0:
		return "0"
	var digits: String = "0123456789abcdefghijklmnopqrstuvwxyz"
	var out: String = ""
	var v: int = value
	while v > 0:
		out = digits[v % 36] + out
		v = int(floor(v / 36.0))
	return out


class Stream extends RefCounted:
	# NOTE: this class has a method called `int` (to match the TS interface),
	# so never use `int(x)` as a conversion in here: use floori().
	var _s: int = 1

	func _init(initial_state: int = 1) -> void:
		_s = initial_state & 0xFFFFFFFF
		if _s == 0:
			_s = 1

	## Next float in [0, 1).
	func next() -> float:
		# mulberry32, every step masked to 32 bits like the JS `>>> 0` / `| 0`.
		_s = (_s + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = _s
		t = Rng._imul((t ^ (t >> 15)) & 0xFFFFFFFF, (t | 1) & 0xFFFFFFFF)
		var a: int = Rng._imul((t ^ (t >> 7)) & 0xFFFFFFFF, (t | 61) & 0xFFFFFFFF)
		t = (t ^ ((t + a) & 0xFFFFFFFF)) & 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	## Integer in [0, max_exclusive).
	func int(max_exclusive) -> int:
		return floori(next() * max_exclusive)

	## Same as `int`, for callers that prefer not to use a type name.
	func next_int(max_exclusive) -> int:
		return floori(next() * max_exclusive)

	## Uniform pick. Returns null for an empty array (JS: undefined), but still
	## consumes one number so the stream stays in step with the TS engine.
	func pick(arr: Array):
		var idx: int = floori(next() * arr.size())
		if arr.is_empty():
			return null
		return arr[idx]

	## Weighted pick. `weight` is called once per element (negative weights
	## count as 0). Returns null, without consuming a number, when the total
	## weight is 0.
	func weighted(arr: Array, weight: Callable):
		var total = 0
		var ws: Array = []
		for item in arr:
			var w = max(0, weight.call(item))
			total += w
			ws.append(w)
		if total <= 0:
			return null
		var r = next() * total
		for i in range(arr.size()):
			r -= ws[i]
			if r < 0:
				return arr[i]
		return arr[arr.size() - 1]
