extends Node
## Tiny synthesized sound effects (no audio files): every sound is a few notes
## rendered into a small buffer the first time it is needed. Autoload "Sfx".

const RATE = 22050
const VOICES = 6
## The web version's oscillator gains are tiny; scale them to a comfortable level.
const LOUDNESS = 3.2

## The clicks: a key going down, a step of a stepper, something added or taken
## away. Soft sine pops whose pitch rises (a bubble, a fruit plucked) or falls,
## each a little higher or lower than the last. The user, 2026-11-23, about the
## square-wave tick every key used to make: "The sound is really jarring, make
## it more satisfying/clicky/bubbly. I like the Stardew Valley sound effects
## when harvesting". A note: [hz, start, seconds, wave, gain, {"to": the pitch it
## glides to, "glide": the seconds that takes, "attack": seconds to full level}].
## (A note fades fast: half way through it is at a twentieth of its level, so
## the glide is done early, while it can be heard.) Kept quiet: a key is
## pressed hundreds of times a workout. No square or sawtooth here: at this
## sample rate their overtones fold back and grate, which is what the old tick
## did (a fifth of its energy sat above 2.5 kHz; these have none there).
const CLICKS = {
	# A key going down: light and short, up a fifth.
	"tick": [[620, 0.0, 0.065, "sine", 0.030, {"to": 930, "glide": 0.028, "attack": 0.003}], [1240, 0.0, 0.030, "sine", 0.006, {"to": 1860, "glide": 0.014, "attack": 0.002}]],
	# Opening something, moving on: rounder and lower.
	"tap": [[400, 0.0, 0.090, "sine", 0.044, {"to": 640, "glide": 0.040, "attack": 0.004}], [800, 0.0, 0.040, "sine", 0.008, {"to": 1280, "glide": 0.020, "attack": 0.002}]],
	# Something added (a set, an exercise, a lift from the plan): a bubble, up
	# more than an octave.
	"pop": [[340, 0.0, 0.120, "sine", 0.050, {"to": 760, "glide": 0.055, "attack": 0.004}], [680, 0.0, 0.050, "sine", 0.010, {"to": 1520, "glide": 0.028, "attack": 0.002}]],
	# Something taken away again: the same bubble, falling.
	"unpop": [[720, 0.0, 0.100, "sine", 0.042, {"to": 400, "glide": 0.050, "attack": 0.004}], [1440, 0.0, 0.040, "sine", 0.007, {"to": 800, "glide": 0.025, "attack": 0.002}]],
}
## How far a click's pitch strays from its own, each time.
const CLICK_DRIFT = 0.05
## Buzzes this close together are one (a key's tick and what its handler asks for).
const BUZZ_GAP_MS = 90

var enabled: bool = true
## Buzzes on a phone (settings.haptics): a light tick with every tap, more for
## a record, a level, a claim, a workout finished.
var buzz_on: bool = true
var _tt_app = null

var _cache = {}
var _players = []
var _next = 0
## The click asked for in this frame ([key, pitch]): played once, in _process,
## so a key's own tick and the sound its handler asks for are one click (the
## last one asked for), not two on top of each other.
var _click = null
var _buzz_at: int = -100000
var _buzz_n: int = 0


func _ready() -> void:
	for i in range(VOICES):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	set_process(false)


func _process(_delta: float) -> void:
	set_process(false)
	if _click == null:
		return
	var c = _click
	_click = null
	_play(str(c[0]), CLICKS[str(c[0])], float(c[1]) * randf_range(1.0 - CLICK_DRIFT, 1.0 + CLICK_DRIFT))


## One of the CLICKS, at `pitch` times its own (a stepper's plus is higher than
## its minus). The last one asked for in a frame is the one that is heard.
func _click_sound(key: String, pitch: float = 1.0) -> void:
	if not enabled:
		return
	_click = [key, pitch]
	set_process(true)


func _exit_tree() -> void:
	# Let go of any sound still playing so nothing is left alive when the game quits.
	for p in _players:
		p.stop()
		p.stream = null
	_cache.clear()


## A short buzz on a phone (web/tt.js, ttApp.buzz): 1 light, 2 two, 3 three.
## Nothing anywhere else. It is asked for at once, never a frame later: an
## iPhone only ticks from inside the finger's own event (a tap's click is made
## inside the lift, ui/touch_scroll.gd). Buzzes that come BUZZ_GAP_MS apart or
## less are one: a tap is one tick, and a longer buzz right after a tick only
## adds what is missing.
func buzz(n: int = 1) -> void:
	if not buzz_on or not OS.has_feature("web"):
		return
	if _tt_app == null:
		_tt_app = JavaScriptBridge.get_interface("ttApp")
	if _tt_app == null:
		return
	var now = Time.get_ticks_msec()
	if now - _buzz_at < BUZZ_GAP_MS:
		if n <= _buzz_n:
			return
		_tt_app.buzz(n, _buzz_n)
		_buzz_n = n
		return
	_buzz_at = now
	_buzz_n = n
	_tt_app.buzz(n, 0)


## A key going down under a finger or the mouse: its sound, and a light tick
## in the hand on a phone.
func click() -> void:
	_click_sound("tick")
	buzz(1)


## One step of a stepper: up is a little higher than down.
func step(dir: int) -> void:
	_click_sound("tick", 1.12 if dir > 0 else 0.9)
	buzz(1)


func tick() -> void:
	_click_sound("tick")


func tap() -> void:
	_click_sound("tap")


## Something added: a set, an exercise, a lift from the plan.
func pop() -> void:
	_click_sound("pop")


## Something taken away again.
func unpop() -> void:
	_click_sound("unpop")


func xp() -> void:
	_play("xp", [[660, 0.0, 0.08, "triangle", 0.06], [990, 0.06, 0.1, "triangle", 0.05]])


func level_up() -> void:
	var notes = []
	var seq = [523, 659, 784, 1047]
	for i in range(seq.size()):
		notes.append([seq[i], i * 0.09, 0.18, "square", 0.07])
	notes.append([1319, 0.38, 0.4, "triangle", 0.06])
	_play("level_up", notes)
	buzz(3)


func pr() -> void:
	_play("pr", [[784, 0.0, 0.1, "square", 0.06], [988, 0.1, 0.1, "square", 0.06], [1175, 0.2, 0.25, "square", 0.07]])
	buzz(2)


func achievement() -> void:
	_play("achievement", [[659, 0.0, 0.12, "triangle", 0.07], [880, 0.12, 0.12, "triangle", 0.07], [1319, 0.24, 0.3, "triangle", 0.08]])


func drop(rarity: String = "common") -> void:
	var bases = {"common": 440.0, "uncommon": 523.0, "rare": 659.0, "epic": 784.0, "legendary": 988.0}
	var base = float(bases.get(rarity, 440.0))
	var notes = [[base, 0.0, 0.1, "sawtooth", 0.04], [base * 1.5, 0.1, 0.15, "sawtooth", 0.04]]
	if rarity == "epic" or rarity == "legendary":
		notes.append([base * 2.0, 0.25, 0.2, "square", 0.05])
		notes.append([base * 2.5, 0.4, 0.4, "triangle", 0.06])
	_play("drop:" + rarity, notes)


func pet() -> void:
	_play("pet", [[1047, 0.0, 0.08, "sine", 0.07], [1319, 0.1, 0.08, "sine", 0.07], [1047, 0.2, 0.08, "sine", 0.07], [1568, 0.3, 0.25, "sine", 0.08]])


func claim() -> void:
	_play("claim", [[587, 0.0, 0.08, "square", 0.05], [880, 0.08, 0.08, "square", 0.05], [1175, 0.16, 0.2, "square", 0.06]])
	buzz(2)


func stage() -> void:
	var notes = []
	var seq = [392, 523, 659, 784, 1047, 1319]
	for i in range(seq.size()):
		notes.append([seq[i], i * 0.1, 0.3, "triangle", 0.07])
	_play("stage", notes)


func hit() -> void:
	_play("hit", [[180, 0.0, 0.08, "sawtooth", 0.07], [120, 0.05, 0.12, "square", 0.06]])


func boss_down() -> void:
	var notes = []
	var low = [196, 147, 98]
	for i in range(low.size()):
		notes.append([low[i], i * 0.09, 0.2, "sawtooth", 0.06])
	var high = [523, 659, 784, 1047, 1319]
	for i in range(high.size()):
		notes.append([high[i], 0.35 + i * 0.08, 0.25, "square", 0.06])
	_play("boss_down", notes)


func rank() -> void:
	var notes = []
	var seq = [440, 554, 659, 880]
	for i in range(seq.size()):
		notes.append([seq[i], i * 0.1, 0.22, "triangle", 0.07])
	_play("rank", notes)


func shutter() -> void:
	_play("shutter", [[1200, 0.0, 0.03, "square", 0.04], [600, 0.04, 0.05, "square", 0.04]])


func error() -> void:
	_play("error", [[220, 0.0, 0.15, "sawtooth", 0.04], [180, 0.12, 0.2, "sawtooth", 0.04]])
	buzz(2)


## A sound of another catalog (the Realm's, ui/rpg/rpg_sfx.gd): rendered once
## under `key`, played at `pitch` times its own.
func play_notes(key: String, notes: Array, pitch: float = 1.0) -> void:
	_play(key, notes, pitch)


func _play(key: String, notes: Array, pitch: float = 1.0) -> void:
	if not enabled or _players.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = _render(notes)
	var p = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[key]
	p.pitch_scale = pitch
	p.play()


## notes: [[frequency_hz, start_sec, duration_sec, wave, gain, opts?], ...]
## opts: {"to": the frequency the note glides to (a pop rises, a drop falls),
## "glide": the seconds the glide takes (the note's length when not given),
## "attack": seconds to full level (0.01 when not given), "lp": for the wave
## "noise" the cut-off of its low-pass in Hz (1800 when not given)}.
## "noise" is a hiss made soft: white noise through a one-pole low-pass, the
## same every time (its own little generator, no randf), for a thud, a whoosh,
## a puff of dust. Its frequency is not used.
func _render(notes: Array) -> AudioStreamWAV:
	var total = 0.0
	for n in notes:
		total = maxf(total, float(n[1]) + float(n[2]) + 0.03)
	var count = int(total * RATE) + 1
	var mix = PackedFloat32Array()
	mix.resize(count)
	for n in notes:
		var freq = float(n[0])
		var first = int(float(n[1]) * RATE)
		var dur = float(n[2])
		var wave = str(n[3])
		var gain = float(n[4])
		var opts = n[5] if n.size() > 5 else {}
		var freq_to = float(opts.get("to", freq))
		var attack = float(opts.get("attack", 0.01))
		var glide = maxf(0.001, float(opts.get("glide", dur)))
		var length = int((dur + 0.02) * RATE)
		var ph = 0.0
		var noisy = wave == "noise"
		var nz = 22695477 + first * 7 + int(gain * 100000.0)
		var lp_a = 1.0 - exp(-TAU * float(opts.get("lp", 1800.0)) / RATE)
		var lp_y = 0.0
		for i in range(length):
			var idx = first + i
			if idx >= count:
				break
			var t = float(i) / RATE
			# Same envelope as the web oscillators: a short attack (10 ms unless
			# the note says otherwise), then an exponential fade.
			var env
			if t < attack:
				env = 0.0001 * pow(gain / 0.0001, t / attack)
			else:
				env = gain * pow(0.0001 / gain, minf(1.0, (t - attack) / maxf(0.001, dur - attack)))
			# The pitch glides from `freq` to `freq_to` (a ratio a second, so it
			# sounds even); the phase is added up sample by sample.
			if noisy:
				nz = (nz * 1103515245 + 12345) & 0x7fffffff
				lp_y += lp_a * ((float(nz) / 1073741824.0 - 1.0) - lp_y)
				mix[idx] += lp_y * env
				continue
			var f = freq if freq_to == freq else freq * pow(freq_to / freq, minf(1.0, t / glide))
			ph = fmod(ph + f / RATE, 1.0)
			var w
			match wave:
				"square":
					w = 0.55 if ph < 0.5 else -0.55
				"triangle":
					w = 4.0 * absf(ph - 0.5) - 1.0
				"sawtooth":
					w = (2.0 * ph - 1.0) * 0.6
				_:
					w = sin(TAU * ph)
			mix[idx] += w * env
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var v = clampf(mix[i] * LOUDNESS, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
