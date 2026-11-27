extends SceneTree
## Unit test for app/sfx.gd: the clicks are soft pops (sine only, quiet, short,
## nothing in the harsh high end, the pitch gliding the way it should), and a
## frame plays one click: the last one asked for.
##   godot --headless --path . --script res://tests/sfx_test.gd
## Prints SFX: X/Y passed and exits with 1 when anything fails.

const RATE = 22050.0

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


## A rendered sound as numbers between -1 and 1.
func samples(st: AudioStreamWAV) -> Array:
	var out = []
	for i in range(st.data.size() / 2):
		out.append(st.data.decode_s16(i * 2) / 32768.0)
	return out


func peak_of(s: Array) -> float:
	var p = 0.0
	for x in s:
		p = maxf(p, absf(x))
	return p


## How long it can be heard: from the first to the last sample above a
## twentieth of its peak, in seconds.
func heard(s: Array) -> float:
	var p = peak_of(s)
	var first = -1
	var last = -1
	for i in range(s.size()):
		if absf(s[i]) > 0.05 * p:
			if first < 0:
				first = i
			last = i
	return (last - first) / RATE


## The share of its energy above `hz` (a plain 512-point transform of its start).
func share_above(s: Array, hz: float) -> float:
	var n = 512
	var all = 0.0
	var high = 0.0
	for k in range(1, n / 2):
		var re = 0.0
		var im = 0.0
		for i in range(mini(n, s.size())):
			var a = TAU * k * i / n
			re += s[i] * cos(a)
			im += s[i] * sin(a)
		var m = re * re + im * im
		all += m
		if k * RATE / n > hz:
			high += m
	return high / all if all > 0.0 else 0.0


## Zero crossings a second between two moments: a rough pitch (twice the hertz).
func crossings(s: Array, from_sec: float, to_sec: float) -> float:
	var a = int(from_sec * RATE)
	var b = mini(s.size() - 1, int(to_sec * RATE))
	var n = 0
	for i in range(a + 1, b):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n / maxf(0.001, to_sec - from_sec)


func _run() -> void:
	var S = load("res://app/sfx.gd").new()
	ok(S.CLICKS.has("tick") and S.CLICKS.has("tap") and S.CLICKS.has("pop") and S.CLICKS.has("unpop"), "the clicks: a key, an opening, something added, something taken away")
	var not_sine = []
	var loud = []
	var long = []
	var harsh = []
	var slow = []
	for k in S.CLICKS:
		for n in S.CLICKS[k]:
			if str(n[3]) != "sine":
				not_sine.append(k)
		var s = samples(S._render(S.CLICKS[k]))
		var p = peak_of(s)
		if p > 0.2 or p < 0.05:
			loud.append("%s %.3f" % [k, p])
		if heard(s) > 0.08 or heard(s) < 0.02:
			long.append("%s %.0f ms" % [k, heard(s) * 1000.0])
		if share_above(s, 2500.0) > 0.01:
			harsh.append("%s %.1f%%" % [k, share_above(s, 2500.0) * 100.0])
		# (clicky: at half its level within 6 ms)
		var half = 0
		while half < s.size() and absf(s[half]) < 0.5 * p:
			half += 1
		if half / RATE > 0.006:
			slow.append("%s %.1f ms" % [k, half / RATE * 1000.0])
	ok(not_sine.is_empty(), "every click is made of sine notes (a square or a sawtooth grates at this sample rate)", not_sine)
	ok(loud.is_empty(), "each is quiet, and not too quiet to hear", loud)
	ok(long.is_empty(), "each is heard for 20 to 80 ms", long)
	ok(harsh.is_empty(), "none has anything to speak of above 2.5 kHz", harsh)
	ok(slow.is_empty(), "each starts at once (clicky)", slow)
	var old = samples(S._render([[880, 0.0, 0.04, "square", 0.03]]))
	ok(share_above(old, 2500.0) > 0.1, "the tick these replaced, a square wave, had a tenth of its energy up there or more (%.0f%%)" % (share_above(old, 2500.0) * 100.0))
	# The pitch: a pop rises, an unpop falls, a plain note stays.
	var pop = samples(S._render([S.CLICKS.pop[0]]))
	var unpop = samples(S._render([S.CLICKS.unpop[0]]))
	ok(crossings(pop, 0.03, 0.06) > crossings(pop, 0.0, 0.02) * 1.5, "a pop goes up in pitch", [crossings(pop, 0.0, 0.02), crossings(pop, 0.03, 0.06)])
	ok(crossings(unpop, 0.03, 0.06) < crossings(unpop, 0.0, 0.02) * 0.8, "an unpop goes down", [crossings(unpop, 0.0, 0.02), crossings(unpop, 0.03, 0.06)])
	var flat = samples(S._render([[500, 0.0, 0.2, "sine", 0.05]]))
	ok(absf(crossings(flat, 0.02, 0.1) - 1000.0) < 40.0, "a note without a glide keeps its pitch (500 Hz)", crossings(flat, 0.02, 0.1))
	var glided = samples(S._render([[400, 0.0, 0.2, "sine", 0.05, {"to": 800, "glide": 0.05}]]))
	ok(absf(crossings(glided, 0.06, 0.12) - 1600.0) < 60.0, "a glide ends on the pitch it was sent to (800 Hz) and stays there", crossings(glided, 0.06, 0.12))
	# The fanfares still render (square and triangle notes, 10 ms attack).
	var fan = samples(S._render([[784, 0.0, 0.1, "square", 0.06], [988, 0.1, 0.1, "triangle", 0.06]]))
	ok(fan.size() > 4000 and peak_of(fan) > 0.05 and peak_of(fan) < 0.5, "the older notes render as before", [fan.size(), peak_of(fan)])

	# --- one click a frame: the last one asked for ---------------------------------------------
	root.add_child(S)
	await process_frame
	S.tick()
	S.pop()
	ok(S._click != null and str(S._click[0]) == "pop" and not S._players.any(func(p): return p.playing), "two clicks asked for in one frame: the last is kept, nothing plays yet", S._click)
	await process_frame
	await process_frame
	ok(S._click == null and S._cache.has("pop") and not S._cache.has("tick") and S._players.any(func(p): return p.stream == S._cache["pop"]), "and that one is played, once", S._cache.keys())
	var drift = S._players.filter(func(p): return p.stream == S._cache["pop"])[0].pitch_scale
	ok(drift >= 1.0 - S.CLICK_DRIFT - 0.001 and drift <= 1.0 + S.CLICK_DRIFT + 0.001, "a little higher or lower each time (%.3f)" % drift)
	S.step(1)
	await process_frame
	await process_frame
	var up = S._players.filter(func(p): return p.stream == S._cache.get("tick"))
	ok(not up.is_empty() and up[0].pitch_scale > 1.05, "a stepper's plus is higher than a plain tick (%.3f)" % (up[0].pitch_scale if not up.is_empty() else 0.0))
	S.step(-1)
	await process_frame
	await process_frame
	var down = S._players.filter(func(p): return p.stream == S._cache.get("tick") and p.pitch_scale < 1.0)
	ok(not down.is_empty() and down[0].pitch_scale < 0.96, "and its minus lower (%.3f)" % (down[0].pitch_scale if not down.is_empty() else 0.0))
	S.level_up()
	ok(S._cache.has("level_up") and S._players.any(func(p): return p.stream == S._cache["level_up"] and is_equal_approx(p.pitch_scale, 1.0)), "a fanfare plays at once, at its own pitch")
	S.enabled = false
	S.tick()
	S.click()
	ok(S._click == null, "with the sound switched off nothing is kept to play")
	S.buzz(1)
	ok(true, "a buzz on a PC is nothing at all (no error)")
	S.queue_free()
	await process_frame
	print("SFX: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
