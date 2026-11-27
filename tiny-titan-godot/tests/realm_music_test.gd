extends SceneTree
## Unit test for app/realm_music.gd: the Realm's music. Nobody hears it before
## it ships, so it is measured: every tune (hub, result, the eight regions'
## battle and boss tunes) renders to the right length, is quiet, has next to
## nothing in the harsh high end, loops without a seam, keeps to its scale and
## its register, leaves rests, and is rendered the same a little at a time as
## in one go. Then the player node: play, crossfade, the cache, stop, off.
##   godot --headless --path . --script res://tests/realm_music_test.gd
## Prints "ok N fail M" and exits with 1 when anything fails.

const RATE = 22050.0
## Samples in one look at the spectrum, and looks per tune.
const WIN = 512
const LOOKS = 16
## A tune must render faster than this on any PC (milliseconds).
const RENDER_MS = 2500.0

var passed = 0
var failed = 0
var M = null
var _cos = PackedFloat32Array()
var _sin = PackedFloat32Array()
var _hann = PackedFloat32Array()


func ok(cond: bool, what: String, detail = "") -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL  %s  %s" % [what, str(detail)])


func _init() -> void:
	_run()


## Peak, RMS and whether every sample is a real number.
func level(s: PackedFloat32Array) -> Dictionary:
	var top = 0.0
	var sum = 0.0
	var real = true
	for v in s:
		if is_nan(v) or is_inf(v):
			real = false
		sum += v * v
		top = maxf(top, absf(v))
	return {"peak": top, "rms": sqrt(sum / maxi(1, s.size())), "real": real}


## The share of a tune's energy above `hz`: LOOKS windows of WIN samples
## spread over the loop, each a plain transform (as tests/sfx_test.gd does),
## under a Hann window so a low note does not smear upward.
func share_above(s: PackedFloat32Array, hz: float) -> float:
	if _cos.is_empty():
		for i in range(WIN):
			_cos.append(cos(TAU * i / WIN))
			_sin.append(sin(TAU * i / WIN))
			_hann.append(0.5 - 0.5 * cos(TAU * i / WIN))
	var all = 0.0
	var high = 0.0
	var first_high = int(hz * WIN / RATE) + 1
	var w = PackedFloat32Array()
	w.resize(WIN)
	for j in range(LOOKS):
		var at = int((s.size() - WIN) * (j + 0.37) / LOOKS)
		for i in range(WIN):
			w[i] = s[at + i] * _hann[i]
		for k in range(1, WIN / 2):
			var re = 0.0
			var im = 0.0
			var a = 0
			for i in range(WIN):
				re += w[i] * _cos[a]
				im += w[i] * _sin[a]
				a = (a + k) & (WIN - 1)
			var m = re * re + im * im
			all += m
			if k >= first_high:
				high += m
	return high / all if all > 0.0 else 0.0


## The jump from the loop's last sample to its first, and the size 99 of 100
## steps between neighbouring samples stay under.
func seam(s: PackedFloat32Array) -> Array:
	var steps = PackedFloat32Array()
	steps.resize(s.size() - 1)
	for i in range(s.size() - 1):
		steps[i] = absf(s[i + 1] - s[i])
	steps.sort()
	return [absf(s[0] - s[s.size() - 1]), steps[int(steps.size() * 0.99)]]


## The three notes (0..11) of the chord of a bar.
func triad(sc: Dictionary, bar: int) -> Array:
	var mode = M.MODES[sc.mode]
	var out = []
	for k in [0, 2, 4]:
		out.append(posmod(M.pitch(int(sc.tonic), mode, int(sc.chords[bar]) + k), 12))
	return out


## Everything a score is checked for; returns what is wrong (nothing = fine).
func score_faults(sc: Dictionary) -> Array:
	var bad = []
	var scale = sc.scale
	for voice in sc.voices:
		for n in sc.voices[voice]:
			if not scale.has(posmod(int(n[2]), 12)):
				bad.append("%s note %d is not in the scale" % [voice, int(n[2])])
			if float(n[0]) < 0.0 or float(n[0]) >= float(sc.beats) or float(n[1]) <= 0.0:
				bad.append("%s note outside the loop" % voice)
	var lead = sc.voices.lead
	var sung = 0.0
	var on_chord = 0.0
	var rest_bars = {}
	var per_bar = {}
	for i in range(lead.size()):
		var n = lead[i]
		var m = int(n[2])
		if m < 60 or m > 84:
			bad.append("lead note %d is outside C4..C6" % m)
		sung += float(n[1])
		var bar = int(float(n[0]) / 4.0)
		per_bar[bar] = float(per_bar.get(bar, 0.0)) + float(n[1])
		if triad(sc, bar).has(posmod(m, 12)):
			on_chord += float(n[1])
		var nx = lead[(i + 1) % lead.size()]
		var leap = absi(int(nx[2]) - m)
		if leap == 6:
			bad.append("lead leaps a tritone at beat %.1f" % float(n[0]))
		if leap > 12:
			bad.append("lead leaps more than an octave at beat %.1f" % float(n[0]))
		if str(sc.mode) == "harmonic":
			# The step between the sixth and the raised seventh is the harsh one.
			var six = posmod(int(sc.tonic) + 8, 12)
			var seven = posmod(int(sc.tonic) + 11, 12)
			var pcs = [posmod(m, 12), posmod(int(nx[2]), 12)]
			if pcs.has(six) and pcs.has(seven):
				bad.append("lead steps between the sixth and the leading note at beat %.1f" % float(n[0]))
		if i + 1 < lead.size() and float(n[0]) + float(n[1]) > float(nx[0]) + 0.001:
			bad.append("two lead notes at once at beat %.1f" % float(n[0]))
	for b in range(int(sc.bars)):
		if float(per_bar.get(b, 0.0)) <= 3.5:
			rest_bars[b] = true
	var cover = sung / float(sc.beats)
	if cover > 0.9 or cover < 0.5:
		bad.append("the lead sounds %.0f%% of the time" % (cover * 100.0))
	if rest_bars.size() < int(sc.bars) / 2:
		bad.append("only %d bars have a rest in the lead" % rest_bars.size())
	if on_chord / maxf(0.001, sung) < 0.6:
		bad.append("only %.0f%% of the lead is on notes of the chord" % (on_chord / sung * 100.0))
	for n in sc.voices.arp:
		if not triad(sc, int(float(n[0]) / 4.0)).has(posmod(int(n[2]), 12)):
			bad.append("arpeggio note off its chord at beat %.1f" % float(n[0]))
	var tonic_pc = posmod(int(sc.tonic), 12)
	for n in sc.voices.bass:
		var t = triad(sc, int(float(n[0]) / 4.0))
		var pc = posmod(int(n[2]), 12)
		if pc != t[0] and pc != t[2] and pc != tonic_pc:
			bad.append("bass note that is no root, fifth or tonic at beat %.1f" % float(n[0]))
		if int(n[2]) < 40 or int(n[2]) > 67:
			bad.append("bass note %d out of its register" % int(n[2]))
	# No held note a semitone from the tune (or from another held note) for
	# half a beat or more: that is the interval that grates.
	var held = sc.voices.pad + lead
	for i in range(held.size()):
		for j in range(i + 1, held.size()):
			var both = minf(float(held[i][0]) + float(held[i][1]), float(held[j][0]) + float(held[j][1])) - maxf(float(held[i][0]), float(held[j][0]))
			if both >= 0.5 and absi(int(held[i][2]) - int(held[j][2])) == 1:
				bad.append("two notes a semitone apart sound together in bar %d" % (int(float(held[j][0]) / 4.0) + 1))
	if lead.size() < 20 or sc.voices.bass.is_empty() or sc.voices.arp.is_empty() or sc.drums.kick.is_empty():
		bad.append("a voice is missing")
	return bad


func _run() -> void:
	M = load("res://app/realm_music.gd")
	var keys = ["hub", "result"]
	for r in range(8):
		keys.append("battle:%d" % r)
	for r in range(8):
		keys.append("boss:%d" % r)
	ok(M.key_of("map") == "hub" and M.key_of("hub") == "hub" and M.key_of("battle", 3) == "battle:3" and M.key_of("boss", 11) == "boss:3" and M.key_of("nonsense") == "", "the names: map is the hub's tune, a region wraps round, a name that is no tune is none")
	ok(M.RATE == 22050, "rendered at the sound effects' rate", M.RATE)

	var hashes = {}
	var slowest = 0.0
	var loudest = 0.0
	var harshest = 0.0
	for key in keys:
		var sc = M.score_of_key(key)
		var theme = str(sc.theme)
		# --- the score ---
		var want = roundi(int(sc.bars) * 4.0 * 60.0 / float(sc.tempo) * RATE)
		ok(int(sc.frames) == want and int(sc.beats) == int(sc.bars) * 4 and sc.chords.size() == int(sc.bars), "%s: as long as its bars at its tempo" % key, [sc.frames, want])
		ok(float(sc.seconds) >= 16.0 and float(sc.seconds) <= 27.0, "%s: a loop of 16 to 27 seconds (%.1f)" % [key, float(sc.seconds)])
		var lo = 80.0
		var hi = 100.0
		if theme == "battle":
			lo = 120.0
			hi = 132.0
		elif theme == "boss":
			lo = 136.0
			hi = 148.0
		ok(float(sc.tempo) >= lo and float(sc.tempo) <= hi, "%s: its tempo (%d)" % [key, int(sc.tempo)])
		var want_mode = "major"
		if theme == "battle":
			want_mode = "aeolian dorian"
		elif theme == "boss":
			want_mode = "harmonic"
		ok(want_mode.contains(str(sc.mode)) and sc.scale.size() == 7, "%s: its scale (%s)" % [key, sc.mode])
		var faults = score_faults(sc)
		ok(faults.is_empty(), "%s: in its scale and register, with rests, no awkward leaps, the accompaniment on its chords" % key, faults.slice(0, 4))
		# --- the sound ---
		var t0 = Time.get_ticks_usec()
		var s = M.render_all(sc)
		var ms = (Time.get_ticks_usec() - t0) / 1000.0
		slowest = maxf(slowest, ms)
		ok(s.size() == int(sc.frames), "%s: renders, one loop long" % key, [s.size(), sc.frames])
		ok(ms < RENDER_MS, "%s: rendered in %.0f ms" % [key, ms])
		var lv = level(s)
		loudest = maxf(loudest, lv.peak)
		ok(lv.real and lv.peak <= M.PEAK_MAX + 0.0005 and lv.peak >= 0.05, "%s: its peak is under the ceiling (%.4f)" % [key, lv.peak])
		ok(lv.rms >= 0.018 and lv.rms <= 0.045, "%s: quiet, and not too quiet to hear (RMS %.4f)" % [key, lv.rms])
		var high = share_above(s, 3000.0)
		harshest = maxf(harshest, high)
		ok(high < 0.01, "%s: next to nothing above 3 kHz (%.2f%%)" % [key, high * 100.0])
		var sm = seam(s)
		ok(sm[0] <= sm[1], "%s: no jump where the loop goes round" % key, sm)
		hashes[key] = str(hash(s.to_byte_array()))
		print("  %-9s %5.1f s  %3d bpm  %-8s tonic %d  %4.0f ms  peak %.4f  rms %.4f  >3k %.3f%%  seam %.5f (steps %.5f)" % [key, float(sc.seconds), int(sc.tempo), sc.mode, int(sc.tonic), ms, lv.peak, lv.rms, high * 100.0, sm[0], sm[1]])
	print("  slowest %.0f ms, loudest peak %.4f (%.1f dBFS), most above 3 kHz %.3f%%" % [slowest, loudest, 20.0 * log(loudest) / log(10.0), harshest * 100.0])

	# --- the eight regions are eight tunes ---
	for theme in ["battle", "boss"]:
		var seen = {}
		var rows = {}
		for r in range(8):
			seen[hashes["%s:%d" % [theme, r]]] = true
			var sc = M.score(theme, r)
			rows["%d %s %d" % [int(sc.tonic), sc.mode, int(sc.tempo)]] = true
		ok(seen.size() == 8, "%s: the eight regions sound different" % theme, seen.size())
		ok(rows.size() == 8, "%s: each has its own key and tempo" % theme, rows.keys())
	ok(str(M.score("battle", 0).voices.lead) != str(M.score("battle", 1).voices.lead) and M.score("battle", 0).voices.lead.size() != M.score("battle", 1).voices.lead.size(), "two battle tunes, not one moved about")
	ok(str(M.score("map").voices) == str(M.score("hub").voices), "the map's tune is the hub's")
	ok(hashes["hub"] != hashes["result"], "the result has a tune of its own")

	# --- the notes are at their pitch (a note is made by turning a point or
	# from its two samples before, never with sin() per sample) ---
	var hub = M.score("hub")
	for voice in ["arp", "lead", "bass"]:
		var one = hub.duplicate(true)
		for v in one.mix:
			if v != voice:
				one.mix[v] = 0.0
		var s = M.render_all(one)
		var n0 = one.voices[voice][0]
		var hz = 440.0 * pow(2.0, (int(n0[2]) - 69) / 12.0)
		# Zero crossings over the note's first 0.3 s (a plucked note is over soon).
		var a = int(0.01 * RATE)
		var b = int(0.31 * RATE)
		var cross = 0
		for i in range(a + 1, b):
			if (s[i - 1] < 0.0) != (s[i] < 0.0):
				cross += 1
		var got = cross / 0.3 / 2.0
		ok(float(n0[0]) == 0.0 and absf(got - hz) < hz * 0.012 + 2.0, "the %s's first note is at its pitch (%.1f Hz, wanted %.1f)" % [voice, got, hz])

	# --- a little at a time gives what one go gives ---
	for key in ["hub", "battle:3", "boss:6"]:
		var sc = M.score_of_key(key)
		var whole = M.stepper(sc)
		whole.step(-1)
		var bit = M.stepper(sc)
		var steps = 0
		while not bit.step(0) and steps < 2000000:
			steps += 1
		ok(bit.done and steps > 500 and bit.units == whole.units, "%s: rendered in %d small steps" % [key, steps], [bit.units, whole.units])
		ok(bit.samples() == whole.samples() and bit.bytes == whole.bytes and bit.samples() == M.render_all(sc), "%s: and the samples are the same, to the last one" % key)
		# What a frame costs: a step with 3 ms to spend.
		var paced = M.stepper(sc)
		var times = []
		while true:
			var t0 = Time.get_ticks_usec()
			var fin = paced.step(M.BUDGET_USEC)
			times.append(Time.get_ticks_usec() - t0)
			if fin:
				break
		times.sort()
		var mid = times[times.size() / 2]
		ok(mid < 4500 and times.size() > 10 and paced.bytes == whole.bytes, "%s: %d frames of about 3 ms each (middle %.1f ms, longest %.1f ms)" % [key, times.size(), mid / 1000.0, times[times.size() - 1] / 1000.0])
		print("  %-9s at 3 ms a frame: %d frames (middle %.2f ms, longest %.2f ms), %d units of work, %d different notes" % [key, times.size(), mid / 1000.0, times[times.size() - 1] / 1000.0, whole.units, whole.stamp_count])
		# The sound itself: 16 bit, loops forward, the loop's start repeated
		# after its end and its end before its start.
		var st = whole.stream()
		var n = int(sc.frames)
		var g = int(M.GUARD)
		ok(st.format == AudioStreamWAV.FORMAT_16_BITS and st.mix_rate == M.RATE and not st.stereo and st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_begin == g and st.loop_end == g + n and st.data.size() == (n + 2 * g) * 2, "%s: a 16 bit sound that loops over exactly its bars" % key, [st.loop_begin, st.loop_end, st.data.size()])
		var fl = whole.samples()
		var far = 0.0
		for i in range(0, n, 7):
			far = maxf(far, absf(st.data.decode_s16((g + i) * 2) / 32767.0 - fl[i]))
		var guard_ok = true
		for j in range(g):
			if st.data.decode_s16(j * 2) != st.data.decode_s16((n + j) * 2) or st.data.decode_s16((g + n + j) * 2) != st.data.decode_s16((g + j) * 2):
				guard_ok = false
		ok(far <= 0.6 / 32767.0 and guard_ok, "%s: its bytes are its samples, with the loop carried on at both ends" % key, [far, guard_ok])

	# --- a loop that breathes at its seam (the web build restarts a looping
	# sound when it has ended, which leaves a moment of nothing there) ---
	for key in ["hub", "battle:1", "boss:4"]:
		var sc = M.score_of_key(key)
		ok(str(sc.seam) == "wrap", "%s: a score loops round unless told otherwise" % key)
		sc["seam"] = "breath"
		var s = M.render_all(sc)
		var lv = level(s)
		var n = s.size()
		# Its last 2 ms, and its very first samples (a note that starts there
		# swells in from nothing).
		var quiet = 0.0
		for i in range(int(0.002 * RATE)):
			quiet = maxf(quiet, absf(s[n - 1 - i]))
		for i in range(4):
			quiet = maxf(quiet, absf(s[i]))
		var tail = 0.0
		for i in range(n - int(M.BREATH_OUT * RATE), n):
			tail = maxf(tail, absf(s[i]))
		var before = 0.0
		for i in range(n - int(0.5 * RATE), n - int(M.BREATH_OUT * RATE)):
			before = maxf(before, absf(s[i]))
		ok(n == int(sc.frames) and lv.real and lv.peak <= M.PEAK_MAX + 0.0005 and lv.rms >= 0.018 and lv.rms <= 0.045, "%s, breathing: as long and as loud as the other" % key, [lv.peak, lv.rms])
		ok(s[n - 1] == 0.0 and quiet < 0.001, "%s, breathing: silent where it ends and where it starts (%.5f), so a gap there makes no click" % [key, quiet])
		ok(before > 0.02 and tail <= before, "%s, breathing: it plays up to its last %d ms and dies away in them" % [key, int(M.BREATH_OUT * 1000.0)], [before, tail])
		ok(s != M.render_all(M.score_of_key(key)), "%s, breathing: not the loop that goes round" % key)

	# --- the player -----------------------------------------------------------------------------
	var m = M.new()
	ok(m.breath == OS.has_feature("web") and not m.breath and m.cache_max == M.CACHE_MAX, "the player: here loops go round and three tunes are kept (in the web build they breathe, and all are kept)")
	root.add_child(m)
	await process_frame
	ok(m.enabled and absf(m.volume - 0.5) < 0.001 and m.current() == "" and not m.is_playing(), "the player: on, at half volume, silent until asked")
	m.play("hub")
	ok(m.current() == "hub" and not m.is_playing() and not m.is_ready("hub"), "a tune asked for is rendered first: nothing sounds yet")
	var frames = 0
	var longest = 0
	var last = Time.get_ticks_usec()
	while not m.is_ready("hub") and frames < 100000:
		await process_frame
		frames += 1
		longest = maxi(longest, Time.get_ticks_usec() - last)
		last = Time.get_ticks_usec()
	ok(m.is_ready("hub") and frames > 10, "it is rendered over %d frames (the longest took %.1f ms)" % [frames, longest / 1000.0])
	ok(m.is_playing() and m._players.any(func(p): return p.playing and p.stream == m._cache["hub"]), "and then it plays")
	var first = m._keys.find("hub")
	ok(first >= 0 and m._players[first].volume_db < -20.0, "starting from silence (%.0f dB)" % m._players[first].volume_db)
	await create_timer(0.9).timeout
	ok(absf(m._players[first].volume_db - linear_to_db(0.5)) < 0.2 and m._players[first].volume_db < 0.0, "faded in to half volume: %.1f dB, under the level it was rendered at" % m._players[first].volume_db)
	var pos = m._players[first].get_playback_position()
	m.play("map")
	m.play("hub")
	await process_frame
	ok(m._players[first].playing and m._players[first].get_playback_position() >= pos and m._keys.count("hub") == 1 and m._stepper == null, "asked for again (or as the map): it just plays on")
	m.volume = 1.0
	ok(absf(m._players[first].volume_db) < 0.2, "volume 1 is the level it was rendered at (%.1f dB)" % m._players[first].volume_db)
	m.volume = 0.0
	ok(m._players[first].volume_db <= -60.0, "volume 0 is silence")
	m.volume = 0.5
	# A tune rendered ahead, then a crossfade.
	m.prepare("battle", 2)
	ok(not m.is_ready("battle", 2) and m.current() == "hub", "a tune prepared ahead changes nothing that plays")
	frames = 0
	while not m.is_ready("battle", 2) and frames < 100000:
		await process_frame
		frames += 1
	ok(m.is_ready("battle", 2) and m.current() == "hub" and m._players[first].playing and m._keys.count("") == 1, "it is rendered while the hub plays on")
	m.play("battle", 2)
	await process_frame
	var second = m._keys.find("battle:2")
	ok(second >= 0 and second != first and m._players[first].playing and m._players[second].playing and m.current() == "battle:2", "a tune that is ready starts at once, over the one before")
	await create_timer(0.3).timeout
	ok(m._players[first].volume_db < linear_to_db(0.5) - 1.0 and m._players[second].volume_db > -30.0 and m._players[first].playing, "the two cross (%.1f dB going, %.1f dB coming)" % [m._players[first].volume_db, m._players[second].volume_db])
	await create_timer(0.6).timeout
	ok(not m._players[first].playing and m._players[first].stream == null and m._players[second].playing and m._keys[first] == "", "then only the new one is left")
	# Back before the fade is over: the old one comes back, nothing restarts.
	m.play("hub")
	await create_timer(0.2).timeout
	m.play("battle", 2)
	await create_timer(0.9).timeout
	ok(m._players[second].playing and m._keys[second] == "battle:2" and m._keys.count("") == 1 and m.is_playing(), "to and fro inside a fade leaves the one asked for last")
	# A tune that is not ready: what plays fades, the new one comes when done.
	m.play("boss", 2)
	ok(m.current() == "boss:2" and not m.is_playing(), "a tune not rendered yet: the old one is on its way out")
	frames = 0
	while not m.is_ready("boss", 2) and frames < 100000:
		await process_frame
		frames += 1
	await create_timer(1.4).timeout
	ok(m.is_playing() and m._keys.count("boss:2") == 1 and m._keys.count("") == 1, "and the new one plays once it is rendered")
	m.play("result")
	frames = 0
	while not m.is_ready("result") and frames < 100000:
		await process_frame
		frames += 1
	ok(m._cache.size() <= m.cache_max and m._cache.has("result") and not m._cache.has("hub"), "the newest tunes are kept, the oldest dropped", m._cache.keys())
	await create_timer(1.4).timeout
	# Off and on.
	m.enabled = false
	await create_timer(0.6).timeout
	ok(not m.is_playing() and not m._players.any(func(p): return p.playing) and m.current() == "result", "switched off: it fades out and stops, and remembers the tune")
	m.play("battle", 2)
	await create_timer(0.2).timeout
	ok(not m._players.any(func(p): return p.playing) and m.current() == "battle:2", "nothing starts while it is off")
	m.enabled = true
	await process_frame
	ok(m.is_playing() and m._keys.has("battle:2"), "switched on: the tune asked for last plays")
	m.stop(0.3)
	ok(m.current() == "" and not m.is_playing(), "stop: nothing is asked for any more")
	await create_timer(0.5).timeout
	ok(not m._players.any(func(p): return p.playing), "and it has faded out")
	await create_timer(0.2).timeout
	ok(not m.is_processing(), "with nothing to do it does no work each frame")
	m.play("battle", 2)
	await process_frame
	m.stop(0.0)
	ok(not m._players.any(func(p): return p.playing), "stop(0) is at once")
	m.play("nonsense")
	ok(m.current() == "", "a name that is no tune asks for nothing")
	# Told to breathe (as in the web build), the next tune it renders does.
	m.breath = true
	m.prepare("boss", 7)
	frames = 0
	while not m.is_ready("boss", 7) and frames < 100000:
		await process_frame
		frames += 1
	var bd = m._cache["boss:7"].data
	var edge = 0
	for i in range(M.GUARD + 3):
		edge = maxi(edge, maxi(absi(bd.decode_s16(i * 2)), absi(bd.decode_s16(bd.size() - 2 - i * 2))))
	ok(m.is_ready("boss", 7) and edge <= 8 and not m.is_playing(), "a tune rendered to breathe is silent at both ends of its sound (%d of 32767)" % edge)
	root.remove_child(m)
	ok(m._cache.is_empty() and m._players.all(func(p): return p.stream == null), "leaving the tree lets go of every sound")
	m.free()
	await process_frame
	print("ok %d fail %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
