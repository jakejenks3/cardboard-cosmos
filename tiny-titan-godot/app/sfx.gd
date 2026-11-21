extends Node
## Tiny synthesized sound effects (no audio files): every sound is a few notes
## rendered into a small buffer the first time it is needed. Autoload "Sfx".

const RATE = 22050
const VOICES = 6
## The web version's oscillator gains are tiny; scale them to a comfortable level.
const LOUDNESS = 3.2

var enabled: bool = true

var _cache = {}
var _players = []
var _next = 0


func _ready() -> void:
	for i in range(VOICES):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _exit_tree() -> void:
	# Let go of any sound still playing so nothing is left alive when the game quits.
	for p in _players:
		p.stop()
		p.stream = null
	_cache.clear()


func tick() -> void:
	_play("tick", [[880, 0.0, 0.04, "square", 0.03]])


func tap() -> void:
	_play("tap", [[520, 0.0, 0.05, "triangle", 0.05]])


func xp() -> void:
	_play("xp", [[660, 0.0, 0.08, "triangle", 0.06], [990, 0.06, 0.1, "triangle", 0.05]])


func level_up() -> void:
	var notes = []
	var seq = [523, 659, 784, 1047]
	for i in range(seq.size()):
		notes.append([seq[i], i * 0.09, 0.18, "square", 0.07])
	notes.append([1319, 0.38, 0.4, "triangle", 0.06])
	_play("level_up", notes)


func pr() -> void:
	_play("pr", [[784, 0.0, 0.1, "square", 0.06], [988, 0.1, 0.1, "square", 0.06], [1175, 0.2, 0.25, "square", 0.07]])


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


func _play(key: String, notes: Array) -> void:
	if not enabled or _players.is_empty():
		return
	if not _cache.has(key):
		_cache[key] = _render(notes)
	var p = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[key]
	p.play()


## notes: [[frequency_hz, start_sec, duration_sec, wave, gain], ...]
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
		var length = int((dur + 0.02) * RATE)
		for i in range(length):
			var idx = first + i
			if idx >= count:
				break
			var t = float(i) / RATE
			# Same envelope as the web oscillators: a 10 ms attack, then an exponential fade.
			var env
			if t < 0.01:
				env = 0.0001 * pow(gain / 0.0001, t / 0.01)
			else:
				env = gain * pow(0.0001 / gain, minf(1.0, (t - 0.01) / maxf(0.001, dur - 0.01)))
			var ph = fmod(t * freq, 1.0)
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
