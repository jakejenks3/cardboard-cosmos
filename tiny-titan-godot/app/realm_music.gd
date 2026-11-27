class_name RealmMusic
extends Node
## Background music for the Realm, synthesized (no audio files): a few small
## tunes written out as notes below, rendered into one looping sound each.
## It names no autoload (no Sfx, App, Kit), so a --script test can load it.
##
##   var m = RealmMusic.new(); add_child(m)
##   m.play("hub")            # also "map" (the same tune), "result"
##   m.play("battle", 3)      # regions 0..7: eight related battle tunes
##   m.play("boss", 3)
##   m.prepare("boss", 3)     # render it ahead, so it is there when asked for
##   m.stop()                 # fades out
##   m.enabled = false        # fades out and stays quiet; true plays it again
##   m.is_playing(), m.current(), m.is_ready("boss", 3)
##   m.volume = 0.5           # 0..1; the sound itself peaks at about -18 dBFS
##
## The user found square-wave clicks "really jarring" and likes Stardew
## Valley's soft sounds, so everything here is warm and quiet: sine notes with
## one or two soft overtones, a bass of a few sine overtones laid like a
## triangle wave, a kick that is a sine dropping in pitch, hats that are noise
## with the top taken off. Next to nothing above 3 kHz, and the whole loop is
## brought to one quiet level (RMS_AIM, never past PEAK_MAX).
##
## A tune is a `score` (pure, static): tempo, bars, the chord of each bar and
## the notes of each voice, all written in steps of the scale, so every note is
## in the key by construction and a region only has to name its key, mode,
## tempo and which patterns it uses. A `Render` renders a score a little at
## a time: the game calls step() with a few milliseconds a frame (_process),
## a test calls it once without a limit; both do the same work in the same
## order, so they give the same samples.
##
## Rendering, the lean way (a phone in a browser is several times slower):
## every different note is rendered ONCE into a small "stamp" (a decaying
## sine is a point turned by a fixed angle each sample: four multiplications,
## no sin()), then each note of the tune adds its stamp into the loop. A note
## that rings past the end of the loop goes on at its start, so the loop has
## no seam (in the web build it dies away at its end instead: see `breath`).
## 22,050 samples a second, the rate of the sound effects (the one known to
## play on the user's iPhone; 16,000 would be a quarter less work).

const RATE = 22050
## Frames repeated before and after the loop in the stream's data, so whatever
## reads a little past the loop's end (to smooth between two samples) finds
## the loop's start there, not silence.
const GUARD = 16
## The loudest sample of a loop is never past this (-18.4 dBFS)...
const PEAK_MAX = 0.12
## ...and its average level (RMS) is brought to this when the peak allows.
const RMS_AIM = 0.03
## Samples of one note rendered in one go (a multiple of BLOCK).
const CHUNK = 1024
## Samples of one note added into the loop in one go.
const MIX_CHUNK = 4096
## A note whose pitch moves (vibrato, a kick's drop) is re-aimed this often.
const BLOCK = 32
## Rendered tunes kept on the PC (the oldest is dropped; see `cache_max`).
const CACHE_MAX = 3
## Seconds one tune takes to give way to the next.
const CROSSFADE = 0.6
## Seconds the tune playing takes to fade when the next is not rendered yet.
const WAIT_FADE = 1.2
## Microseconds of rendering a frame.
const BUDGET_USEC = 3000
## Seconds a loop takes to die away at its end when it is rendered to "breathe"
## at the seam (see `breath`).
const BREATH_OUT = 0.06

const REGIONS = 8

const VIB_HZ = 5.2
const VIB_DEPTH = 0.003
const VIB_DELAY = 0.16
const VIB_RAMP = 0.22
## No overtone is rendered above this.
const TOP_HZ = 2800.0

## Scales, as semitones above the tonic.
const MODES = {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"aeolian": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"harmonic": [0, 2, 3, 5, 7, 8, 11],
}

## The eight regions' battle tunes: [the lead's tonic (a MIDI note), mode,
## beats a minute, which tune, bass pattern, arpeggio pattern, drum pattern].
const BATTLE_ROWS = [
	[69, "aeolian", 124, 0, 0, 0, 0],
	[64, "dorian", 128, 1, 1, 1, 0],
	[67, "aeolian", 120, 1, 0, 1, 1],
	[66, "dorian", 126, 0, 1, 0, 1],
	[62, "aeolian", 130, 1, 1, 0, 0],
	[60, "aeolian", 122, 0, 0, 1, 1],
	[65, "dorian", 132, 0, 0, 1, 0],
	[63, "dorian", 126, 1, 1, 0, 1],
]
## The eight regions' boss tunes (harmonic minor): [tonic, beats a minute,
## which tune, bass pattern, arpeggio pattern, drum pattern].
const BOSS_ROWS = [
	[62, 140, 0, 0, 0, 0],
	[64, 144, 1, 1, 1, 0],
	[67, 138, 0, 1, 0, 1],
	[66, 142, 1, 0, 1, 1],
	[61, 146, 0, 1, 1, 0],
	[60, 140, 1, 0, 0, 1],
	[65, 144, 0, 0, 1, 1],
	[63, 142, 1, 1, 0, 0],
]

## The chord of each bar, as the scale step its root is on (0 = the tonic).
## Battle, 12 bars (A, A again with another ending, B). Natural minor: i VI III
## VII, then VI VII i VII. Dorian has no good chord on its sixth step, so the
## second bar's chord is IV there (the same tunes fit both).
const PROG_AEOLIAN = [0, 5, 2, 6, 0, 5, 2, 6, 5, 6, 0, 6]
const PROG_DORIAN = [0, 3, 2, 6, 0, 3, 2, 6, 3, 6, 0, 6]
## Boss, 12 bars, harmonic minor: i i iv V, i VI iv V, then VI iv V V.
const PROG_BOSS = [0, 0, 3, 4, 0, 5, 3, 4, 5, 3, 4, 4]
## Hub, 8 bars, major: I V vi IV, then vi IV I V.
const PROG_HUB = [0, 4, 5, 3, 5, 3, 0, 4]
## Result, 8 bars, major: I IV I V, then vi IV V I.
const PROG_RESULT = [0, 3, 0, 4, 5, 3, 4, 0]

## The tunes. A row is a bar: [eighth it starts on (0..7), eighths it lasts,
## scale step (0 = the tonic, 7 = the tonic above), ...] for each note.
##
## Battle tune 0: a repeated note with a turn (bars 1-2), the same a third
## lower (3-4), again with a rising answer (5-8), then wide arpeggios (9-12).
const TUNE_BATTLE_0 = [
	[0, 2, 4, 2, 1, 4, 3, 1, 3, 4, 2, 4, 7, 1, 6],
	[0, 3, 5, 3, 1, 4, 4, 2, 2],
	[0, 2, 2, 2, 1, 2, 3, 1, 1, 4, 2, 2, 7, 1, 4],
	[0, 3, 3, 3, 1, 2, 4, 2, 1, 7, 1, 3],
	[0, 2, 4, 2, 1, 4, 3, 1, 3, 4, 2, 4, 7, 1, 6],
	[0, 3, 5, 3, 1, 4, 4, 2, 5, 6, 2, 7],
	[0, 3, 6, 3, 1, 4, 4, 2, 6, 6, 1, 4, 7, 1, 3],
	[0, 3, 3, 4, 2, 1],
	[0, 2, 0, 2, 2, 5, 4, 3, 7],
	[0, 2, 6, 2, 2, 3, 4, 3, 1],
	[0, 3, 4, 3, 1, 6, 4, 2, 7, 6, 1, 4],
	[0, 3, 3, 3, 1, 4, 4, 2, 3, 6, 1, 1, 7, 1, 3],
]
## Battle tune 1: a climb up the chord and a step back (bars 1-2), the same a
## third higher (3-4), again (5-8), then long notes that fall home (9-12).
const TUNE_BATTLE_1 = [
	[0, 1, 0, 1, 1, 2, 2, 2, 4, 5, 1, 3, 6, 2, 4],
	[0, 2, 5, 2, 2, 7, 5, 1, 5, 6, 1, 4],
	[0, 1, 2, 1, 1, 4, 2, 2, 6, 5, 1, 5, 6, 2, 4],
	[0, 2, 3, 2, 2, 6, 5, 1, 3, 6, 1, 1],
	[0, 1, 0, 1, 1, 2, 2, 2, 4, 5, 1, 3, 6, 2, 4],
	[0, 2, 5, 2, 2, 7, 5, 1, 6, 6, 2, 7],
	[0, 2, 6, 2, 2, 4, 5, 1, 2, 6, 2, 4],
	[0, 3, 3, 4, 2, 1],
	[0, 3, 7, 4, 2, 5, 6, 2, 7],
	[0, 3, 8, 4, 2, 6, 6, 2, 8],
	[0, 3, 7, 3, 1, 6, 4, 2, 4, 6, 1, 2],
	[0, 3, 3, 3, 1, 1, 4, 2, 3, 6, 2, -1],
]
## Boss tune 0: the fifth, pressed on by the note a semitone above it (bars
## 1-2), the same on the fourth chord (3), up the dominant to the leading note
## (4), which goes home (5); then falling arpeggios (9-10) and the dominant.
## The leading note (step 6) is only ever beside the tonic or inside the
## dominant chord, never next to step 5 (that step is the harsh one).
const TUNE_BOSS_0 = [
	[0, 2, 4, 2, 1, 4, 3, 1, 5, 4, 2, 4, 6, 1, 2],
	[0, 3, 0, 3, 1, 1, 4, 2, 2],
	[0, 2, 7, 2, 1, 7, 3, 1, 8, 4, 2, 7, 6, 1, 5],
	[0, 3, 4, 3, 1, 6, 4, 2, 8, 6, 2, 6],
	[0, 2, 7, 2, 1, 4, 3, 1, 5, 4, 2, 4, 6, 1, 2],
	[0, 3, 5, 3, 1, 7, 4, 2, 9],
	[0, 2, 7, 2, 1, 7, 3, 1, 8, 4, 2, 7, 6, 1, 5],
	[0, 2, 4, 2, 2, 6, 4, 3, 8],
	[0, 3, 9, 4, 2, 7, 6, 2, 5],
	[0, 3, 7, 4, 2, 5, 6, 2, 3],
	[0, 2, 4, 2, 2, 6, 4, 2, 8, 6, 2, 6],
	[0, 3, 8, 3, 1, 6, 4, 3, 4],
]
## Boss tune 1: the same, with a longer first note, an answer that climbs the
## tonic chord, and a B part that turns upward in its second bar.
const TUNE_BOSS_1 = [
	[0, 3, 4, 3, 1, 5, 4, 2, 4, 6, 1, 2],
	[0, 2, 0, 2, 2, 2, 4, 3, 4],
	[0, 3, 7, 3, 1, 8, 4, 2, 7, 6, 1, 5],
	[0, 3, 4, 3, 1, 6, 4, 2, 8, 6, 2, 6],
	[0, 2, 7, 2, 1, 4, 3, 1, 5, 4, 2, 4, 6, 1, 2],
	[0, 3, 5, 3, 1, 7, 4, 2, 9],
	[0, 3, 7, 3, 1, 8, 4, 2, 7, 6, 1, 5],
	[0, 2, 4, 2, 2, 6, 4, 3, 8],
	[0, 3, 9, 4, 2, 7, 6, 2, 5],
	[0, 2, 3, 2, 2, 5, 4, 3, 7],
	[0, 2, 8, 2, 2, 6, 4, 2, 4, 6, 2, 6],
	[0, 4, 8, 4, 3, 4],
]
## Hub: a lullaby. Bars 1-2 are the motif (long, short, long; then it settles),
## 3-4 the same over the next two chords, 5-8 an answer that walks back home.
const TUNE_HUB = [
	[0, 3, 2, 3, 1, 4, 4, 3, 7],
	[0, 3, 4, 4, 2, 1, 6, 2, 2],
	[0, 3, 2, 3, 1, 4, 4, 3, 5],
	[0, 3, 3, 4, 2, 2, 6, 2, 1],
	[0, 2, 0, 2, 2, 2, 4, 3, 5, 7, 1, 4],
	[0, 3, 5, 3, 1, 4, 4, 2, 3],
	[0, 3, 4, 3, 1, 2, 4, 3, 0],
	[0, 3, 1, 3, 1, 2, 4, 2, 1],
]
## Result: up the tonic chord and a long note, an answer, and home by the
## leading note.
const TUNE_RESULT = [
	[0, 1, 0, 1, 1, 2, 2, 2, 4, 4, 3, 7],
	[0, 3, 5, 3, 1, 7, 4, 2, 5, 6, 1, 3],
	[0, 3, 4, 3, 1, 2, 4, 3, 4],
	[0, 2, 1, 2, 2, 4, 4, 2, 6],
	[0, 3, 7, 3, 1, 5, 4, 2, 7, 6, 2, 9],
	[0, 3, 10, 3, 1, 9, 4, 3, 7],
	[0, 2, 8, 2, 2, 6, 4, 2, 4, 6, 2, 6],
	[0, 6, 7],
]

## Bass patterns of a bar: [eighth, eighths long, steps above the chord's root
## (0 the root, 4 its fifth, 7 the root an octave up), ...].
const BASS_BATTLE = [
	[0, 1, 0, 1, 1, 0, 2, 1, 7, 4, 1, 0, 5, 1, 0, 6, 1, 7, 7, 1, 0],
	[0, 1, 0, 2, 1, 7, 3, 1, 0, 4, 1, 4, 6, 1, 7, 7, 1, 4],
]
const BASS_BOSS = [
	[0, 1, 0, 1, 1, 0, 3, 1, 0, 4, 1, 0, 6, 1, 7, 7, 1, 0],
	[0, 1, 0, 1, 1, 0, 2, 1, 7, 4, 1, 0, 5, 1, 0, 6, 1, 7],
]
const BASS_CALM = [
	[0, 4, 0, 4, 3, 4],
	[0, 6, 0],
]
## Arpeggio patterns of a bar: [eighth, steps above the chord's root (always a
## note of the chord: 0, 2, 4, 7, 9, 11), loudness, ...].
const ARP_BATTLE = [
	[1, 4, 0.9, 3, 7, 1.0, 5, 9, 0.9, 7, 7, 0.8],
	[0, 4, 1.0, 1, 7, 0.8, 2, 9, 0.9, 4, 4, 1.0, 5, 7, 0.8, 6, 9, 0.9],
]
const ARP_BATTLE_B = [0, 7, 1.0, 2, 9, 0.85, 4, 11, 1.0, 6, 9, 0.85]
const ARP_BOSS = [
	[0, 2, 1.0, 1, 4, 0.8, 2, 7, 0.9, 3, 9, 0.8, 4, 7, 1.0, 5, 4, 0.8, 6, 7, 0.9, 7, 9, 0.8],
	[1, 4, 0.9, 3, 7, 1.0, 5, 9, 0.9, 7, 7, 0.8],
]
const ARP_CALM = [
	[0, 0, 1.0, 1, 4, 0.8, 2, 9, 0.9, 3, 4, 0.75, 4, 7, 0.9, 5, 4, 0.75, 6, 9, 0.85],
	[0, 0, 1.0, 2, 4, 0.8, 3, 7, 0.85, 4, 9, 0.9, 6, 7, 0.8],
]

## How loud each voice is in the mix, before the whole loop is brought to its
## level. The noise of a hat is quiet by itself, so its numbers are larger.
const MIX = {
	"calm": {"lead": 0.38, "bass": 0.32, "arp": 0.27, "pad": 0.085, "kick": 0.26, "snare": 0.0, "hat": 0.7, "shaker": 1.0},
	"battle": {"lead": 0.4, "bass": 0.36, "arp": 0.32, "pad": 0.08, "kick": 0.42, "snare": 0.8, "hat": 0.9, "shaker": 0.0},
	"boss": {"lead": 0.4, "bass": 0.4, "arp": 0.3, "pad": 0.06, "kick": 0.46, "snare": 0.85, "hat": 0.9, "shaker": 0.0},
}

## Off: what plays fades out and nothing starts. On again: the tune asked for
## last plays.
var enabled: bool = true:
	set(v):
		if v == enabled:
			return
		enabled = v
		if not is_inside_tree():
			return
		if v:
			if _want != "":
				_go()
		else:
			_fade_all(0.4)

## 0..1. Half is the usual: about 6 dB under the level the loops are rendered
## at, which is already well under the sound effects.
var volume: float = 0.5:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		for i in range(_players.size()):
			_level_to(i)

## Microseconds a frame spent rendering a tune that is not ready yet.
var budget_usec: int = BUDGET_USEC

## How a loop meets itself. false: notes that ring past the end go on at the
## start, and the loop goes round without a seam (what Godot's own mixer
## plays, on the PC). true: nothing rings over; the loop dies away in its last
## BREATH_OUT seconds and starts from silence. That is for the web build:
## there Godot plays a looping sound as a "sample" and loops it by STARTING IT
## AGAIN when the browser says it has ended (GodotAudio.SampleNode, the "ended"
## listener in the engine's index.js), which leaves a few hundredths of a
## second of nothing at the seam. A loop that is silent there has no click; the
## next bar is only that little bit late, like a breath. (Tunes already
## rendered keep the seam they were rendered with.)
var breath: bool = OS.has_feature("web")

## Rendered tunes kept. In the web build all of them (hub, result, eight
## battle and eight boss tunes at most, about 1 MB each): there a sound that
## has been played stays with the browser as a "sample" until the page closes
## (the engine never takes it back, and a script cannot), about 9 MB a tune,
## so rendering a tune a second time would only add another one.
var cache_max: int = (2 + 2 * REGIONS) if OS.has_feature("web") else CACHE_MAX

## The tune asked for ("hub", "battle:3", "" = none).
var _want: String = ""
var _players: Array = []
## Per player: the tune it carries, how far it is faded in (0..1), where that
## is heading and how fast (a second).
var _keys: Array = ["", ""]
var _level: Array = [0.0, 0.0]
var _aim: Array = [0.0, 0.0]
var _rate: Array = [0.0, 0.0]
## Rendered tunes by key, and their keys from the one used longest ago.
var _cache: Dictionary = {}
var _order: Array = []
## The tune being rendered, and the ones waiting.
var _stepper = null
var _render_key: String = ""
var _queue: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p = AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	set_process(false)
	if enabled and _want != "":
		_go()


func _exit_tree() -> void:
	# Let go of what plays and of every rendered tune, so nothing is left alive
	# when the game quits.
	for i in range(_players.size()):
		_players[i].stop()
		_players[i].stream = null
		_keys[i] = ""
		_level[i] = 0.0
		_aim[i] = 0.0
	_cache.clear()
	_order.clear()
	_queue.clear()
	_stepper = null
	_render_key = ""


## Plays a tune: "hub" (and "map", the same one), "battle" and "boss" with the
## region 0..7, "result". Asking for the tune already asked for does nothing.
## The tune before it gives way over CROSSFADE seconds; one that has to be
## rendered first comes in when it is ready.
func play(theme: String, region: int = 0) -> void:
	var key = key_of(theme, region)
	if key == "" or key == _want:
		return
	_want = key
	if enabled and is_inside_tree():
		_go()


## Renders a tune ahead (while the tune before it plays on), so play() has it
## at once.
func prepare(theme: String, region: int = 0) -> void:
	var key = key_of(theme, region)
	if key == "" or _cache.has(key) or key == _render_key or _queue.has(key):
		return
	_queue.append(key)
	set_process(true)


## Is this tune rendered (play() would start it at once)?
func is_ready(theme: String, region: int = 0) -> bool:
	return _cache.has(key_of(theme, region))


## Fades out and stops. play() starts again.
func stop(fade: float = 0.5) -> void:
	_want = ""
	_fade_all(fade)


## Is a tune sounding (or fading in)?
func is_playing() -> bool:
	for i in range(_players.size()):
		if _aim[i] > 0.0 and _players[i].playing:
			return true
	return false


## The tune asked for: "hub", "result", "battle:3", "boss:0"; "" when stopped.
## (It may still be rendering: is_playing() says whether it sounds.)
func current() -> String:
	return _want


func _process(delta: float) -> void:
	var busy = false
	# The fades first, so a tune started below begins from silence.
	var d = minf(delta, 0.1)
	for i in range(_players.size()):
		if _keys[i] == "":
			continue
		if _level[i] == _aim[i]:
			# (Told to fade out before it had faded in at all.)
			if _aim[i] <= 0.0:
				_silence(i)
			continue
		busy = true
		_level[i] = move_toward(float(_level[i]), float(_aim[i]), float(_rate[i]) * d)
		if _level[i] <= 0.0 and _aim[i] <= 0.0:
			_silence(i)
		else:
			_level_to(i)
	# Then a few milliseconds of rendering.
	if _stepper == null and not _queue.is_empty():
		busy = true
		_render_key = str(_queue.pop_front())
		if _cache.has(_render_key):
			_render_key = ""
		else:
			var sc = score_of_key(_render_key)
			if breath:
				sc["seam"] = "breath"
			_stepper = Render.new(sc)
	elif _stepper != null:
		busy = true
		if _stepper.step(budget_usec):
			var key = _render_key
			_store(key, _stepper.stream())
			_stepper = null
			_render_key = ""
			if enabled and key == _want:
				_start(key)
	if not busy and _queue.is_empty():
		set_process(false)


## Starts the tune asked for, or has it rendered first.
func _go() -> void:
	if _cache.has(_want):
		_start(_want)
		return
	# Not rendered yet: what plays now fades away, the new tune fades in when
	# it is ready (a tune under way for another key goes back in the queue).
	_fade_all(WAIT_FADE)
	if _render_key == _want:
		return
	_queue.erase(_want)
	if _stepper != null:
		_queue.push_front(_render_key)
		_stepper = null
		_render_key = ""
	_queue.push_front(_want)
	set_process(true)


## Fades a rendered tune in on one player and whatever else plays out.
func _start(key: String) -> void:
	var i = _keys.find(key)
	if i < 0:
		# A free player, else the quieter one.
		i = _keys.find("")
		if i < 0:
			i = 0 if float(_level[0]) <= float(_level[1]) else 1
		var p = _players[i]
		p.stop()
		p.stream = _cache[key]
		_keys[i] = key
		_level[i] = 0.0
		_level_to(i)
		p.play()
	_aim[i] = 1.0
	_rate[i] = 1.0 / CROSSFADE
	for o in range(_players.size()):
		if o != i and _keys[o] != "":
			_aim[o] = 0.0
			_rate[o] = 1.0 / CROSSFADE
	_touch(key)
	set_process(true)


func _fade_all(seconds: float) -> void:
	for i in range(_players.size()):
		if _keys[i] == "":
			continue
		if seconds <= 0.0:
			_silence(i)
		else:
			_aim[i] = 0.0
			_rate[i] = 1.0 / seconds
	set_process(true)


func _silence(i: int) -> void:
	_players[i].stop()
	_players[i].stream = null
	_players[i].volume_db = -80.0
	_keys[i] = ""
	_level[i] = 0.0
	_aim[i] = 0.0


## A player's loudness from how far it is faded in (a quarter of a sine, so
## two tunes crossing keep their loudness together) and the volume.
func _level_to(i: int) -> void:
	var g = sin(clampf(float(_level[i]), 0.0, 1.0) * PI * 0.5) * volume
	_players[i].volume_db = linear_to_db(maxf(g, 0.0001))


func _store(key: String, st: AudioStreamWAV) -> void:
	_cache[key] = st
	_touch(key)
	# Keep the newest few; never drop one that plays or is asked for.
	var n = 0
	while _order.size() > cache_max and n < _order.size():
		var old = str(_order[n])
		if old == _want or _keys.has(old) or old == key:
			n += 1
			continue
		_order.remove_at(n)
		_cache.erase(old)


func _touch(key: String) -> void:
	_order.erase(key)
	_order.append(key)


# --- the tunes (pure) ------------------------------------------------------------------------

## The key a tune is kept under: "hub" (also for "map"), "result",
## "battle:<region>", "boss:<region>"; "" for a name that is no tune.
static func key_of(theme: String, region: int = 0) -> String:
	match theme:
		"hub", "map":
			return "hub"
		"result":
			return "result"
		"battle", "boss":
			return "%s:%d" % [theme, posmod(region, REGIONS)]
	return ""


static func score_of_key(key: String) -> Dictionary:
	var parts = key.split(":")
	return score(parts[0], int(parts[1]) if parts.size() > 1 else 0)


## The MIDI note of a scale step (0 = the tonic, 7 = the tonic above, -1 the
## step under it).
static func pitch(tonic: int, mode: Array, step: int) -> int:
	var oct = floori(step / 7.0)
	return tonic + 12 * oct + int(mode[step - oct * 7])


## A note `steps` scale steps above the chord root on scale step `root`, with
## that root moved by octaves to lie in the twelve notes from `low` up.
static func chord_tone(tonic: int, mode: Array, root: int, steps: int, low: int) -> int:
	var base = pitch(tonic, mode, root)
	var shift = 0
	while base + shift < low:
		shift += 12
	while base + shift >= low + 12:
		shift -= 12
	return pitch(tonic, mode, root + steps) + shift


## A tune written out: {theme, region, style, tempo, bars, beats, rate, frames,
## seconds, tonic (the lead's, a MIDI note), root (0..11), mode, scale (the
## seven notes 0..11), chords (a scale step per bar), voices {lead, bass, arp,
## pad: [[beat, beats long, MIDI note, loudness], ...]}, drums {kick, snare,
## hat, shaker: [[beat, loudness], ...]}, mix {voice: loudness}, seam ("wrap":
## what rings past the end goes on at the start; "breath": the loop dies away
## at its end and nothing rings over, see `breath`)}.
static func score(theme: String, region: int = 0) -> Dictionary:
	var r = posmod(region, REGIONS)
	match theme:
		"battle":
			return _battle(r)
		"boss":
			return _boss(r)
		"result":
			return _calm("result", 62, 96, PROG_RESULT, TUNE_RESULT)
	return _calm("hub", 67, 84, PROG_HUB, TUNE_HUB)


static func _base(theme: String, region: int, style: String, tonic: int, mode_name: String, bpm: int, chords: Array) -> Dictionary:
	var bars = chords.size()
	var frames = roundi(bars * 4.0 * 60.0 / bpm * RATE)
	var scale = []
	for iv in MODES[mode_name]:
		scale.append((tonic + int(iv)) % 12)
	return {
		"theme": theme, "region": region, "style": style,
		"tempo": float(bpm), "bars": bars, "beats": bars * 4,
		"rate": RATE, "frames": frames, "seconds": frames / float(RATE),
		"tonic": tonic, "root": tonic % 12, "mode": mode_name, "scale": scale,
		"chords": chords.duplicate(),
		"voices": {"lead": [], "bass": [], "arp": [], "pad": []},
		"drums": {"kick": [], "snare": [], "hat": [], "shaker": []},
		"mix": MIX[style].duplicate(),
		"seam": "wrap",
	}


## The lead: the notes of a tune, a little louder on the beats.
static func _tune(sc: Dictionary, rows: Array) -> void:
	var mode = MODES[sc.mode]
	for b in range(rows.size()):
		var row = rows[b]
		var i = 0
		while i + 2 < row.size():
			var e = int(row[i])
			var vel = 1.0 if e % 4 == 0 else (0.9 if e % 2 == 0 else 0.8)
			sc.voices.lead.append([b * 4 + e * 0.5, int(row[i + 1]) * 0.5, pitch(int(sc.tonic), mode, int(row[i + 2])), vel])
			i += 3


## One bar of bass: `pattern` over the chord root on scale step `root`.
static func _bass(sc: Dictionary, bar: int, root: int, pattern: Array, low: int) -> void:
	var mode = MODES[sc.mode]
	var i = 0
	while i + 2 < pattern.size():
		var e = int(pattern[i])
		var vel = 1.0 if e % 4 == 0 else 0.85
		sc.voices.bass.append([bar * 4 + e * 0.5, int(pattern[i + 1]) * 0.5, chord_tone(int(sc.tonic), mode, root, int(pattern[i + 2]), low), vel])
		i += 3


## One bar of arpeggio.
static func _arp(sc: Dictionary, bar: int, root: int, pattern: Array, low: int) -> void:
	var mode = MODES[sc.mode]
	var i = 0
	while i + 2 < pattern.size():
		sc.voices.arp.append([bar * 4 + int(pattern[i]) * 0.5, 0.5, chord_tone(int(sc.tonic), mode, root, int(pattern[i + 1]), low), float(pattern[i + 2])])
		i += 3


## One bar of held notes under everything: the chord's root and the notes
## `steps` above it.
static func _pad(sc: Dictionary, bar: int, root: int, steps: Array, low: int) -> void:
	var mode = MODES[sc.mode]
	for s in steps:
		sc.voices.pad.append([bar * 4.0, 4.0, chord_tone(int(sc.tonic), mode, root, int(s), low), 1.0])


## Drum hits of a bar: [eighth, loudness, ...].
static func _hits(sc: Dictionary, drum: String, bar: int, hits: Array) -> void:
	var i = 0
	while i + 1 < hits.size():
		sc.drums[drum].append([bar * 4 + int(hits[i]) * 0.5, float(hits[i + 1])])
		i += 2


## Hub and result: a slow tune over held fifths, a soft arpeggio, a bass of
## long notes, a shaker on two and four.
static func _calm(theme: String, tonic: int, bpm: int, chords: Array, rows: Array) -> Dictionary:
	var sc = _base(theme, 0, "calm", tonic, "major", bpm, chords)
	_tune(sc, rows)
	for b in range(chords.size()):
		var ch = int(chords[b])
		var second_half = b >= chords.size() / 2
		# Root, fifth, ninth: stacked fifths, no third to rub against. Over a
		# minor chord the ninth would sit a semitone under the third the tune
		# and the arpeggio play, so there it is the octave.
		_pad(sc, b, ch, [0, 4, 7] if [1, 2, 5].has(ch) else [0, 4, 8], 48)
		_arp(sc, b, ch, ARP_CALM[1 if second_half else 0], 48)
		_bass(sc, b, ch, BASS_CALM[b % 2], 43)
		_hits(sc, "kick", b, [0, 0.8])
		_hits(sc, "shaker", b, [2, 0.8, 6, 1.0])
		if second_half:
			_hits(sc, "hat", b, [3, 0.5, 7, 0.6])
	return sc


## A region's battle tune: light and driving. Twelve bars: the tune twice over
## four chords, then four broader bars (held notes, a half-time beat) that
## lead back.
static func _battle(r: int) -> Dictionary:
	var row = BATTLE_ROWS[r]
	var mode_name = str(row[1])
	var chords = PROG_AEOLIAN if mode_name == "aeolian" else PROG_DORIAN
	var sc = _base("battle", r, "battle", int(row[0]), mode_name, int(row[2]), chords)
	_tune(sc, TUNE_BATTLE_0 if int(row[3]) == 0 else TUNE_BATTLE_1)
	var busy = int(row[6]) == 1
	for b in range(12):
		var ch = int(chords[b])
		_bass(sc, b, ch, BASS_BATTLE[int(row[4])], 43)
		if b < 8:
			_arp(sc, b, ch, ARP_BATTLE[int(row[5])], 48)
			_hits(sc, "kick", b, [0, 1.0, 3, 0.7, 4, 0.9] if busy else [0, 1.0, 4, 0.9])
			_hits(sc, "snare", b, [2, 0.9, 6, 1.0])
			if b % 4 == 3:
				_hits(sc, "kick", b, [7, 0.7])
		else:
			_arp(sc, b, ch, ARP_BATTLE_B, 48)
			_pad(sc, b, ch, [0, 4], 48)
			_hits(sc, "kick", b, [0, 1.0, 5, 0.7] if busy else [0, 1.0])
			if b == 11:
				_hits(sc, "snare", b, [4, 0.8, 6, 0.9, 7, 1.0])
			else:
				_hits(sc, "snare", b, [4, 1.0])
		if busy:
			_hits(sc, "hat", b, [0, 0.5, 1, 0.9, 2, 0.5, 3, 0.9, 4, 0.5, 5, 0.9, 6, 0.5, 7, 0.9])
		else:
			_hits(sc, "hat", b, [1, 0.9, 3, 0.8, 5, 0.9, 7, 0.8])
	return sc


## A region's boss tune: harmonic minor, faster. The bass stays on the tonic
## under every chord that holds it (i, iv, VI) and only moves to the fifth
## under the dominant; in the last four bars it follows the chords.
static func _boss(r: int) -> Dictionary:
	var row = BOSS_ROWS[r]
	var chords = PROG_BOSS
	var sc = _base("boss", r, "boss", int(row[0]), "harmonic", int(row[1]), chords)
	_tune(sc, TUNE_BOSS_0 if int(row[2]) == 0 else TUNE_BOSS_1)
	var busy = int(row[5]) == 1
	for b in range(12):
		var ch = int(chords[b])
		var under = ch
		if b < 8 and ch != 4:
			under = 0
		_bass(sc, b, under, BASS_BOSS[int(row[3])], 43)
		_arp(sc, b, ch, ARP_BOSS[int(row[4])], 48)
		_pad(sc, b, ch, [0, 4], 48)
		if b >= 8:
			_hits(sc, "kick", b, [0, 1.0, 2, 0.8, 4, 0.95, 6, 0.8])
		elif busy:
			_hits(sc, "kick", b, [0, 1.0, 4, 0.9, 5, 0.7])
		else:
			_hits(sc, "kick", b, [0, 1.0, 3, 0.7, 4, 0.9])
		_hits(sc, "snare", b, [2, 0.9, 6, 1.0])
		if b % 4 == 3:
			_hits(sc, "snare", b, [7, 0.7])
		if busy:
			_hits(sc, "hat", b, [0, 0.5, 1, 0.9, 2, 0.5, 3, 0.9, 4, 0.5, 5, 0.9, 6, 0.5, 7, 0.9])
		else:
			_hits(sc, "hat", b, [1, 0.9, 3, 0.8, 5, 0.9, 7, 0.8])
	return sc


# --- rendering (pure) ------------------------------------------------------------------------

## A score as samples (-1..1, at the level it is played at): one loop.
static func render_all(sc: Dictionary) -> PackedFloat32Array:
	var st = Render.new(sc)
	st.step(-1)
	return st.samples()


## The renderer of a score, to be stepped (see Render).
static func stepper(sc: Dictionary) -> Render:
	return Render.new(sc)


## Renders a score in small units of work: step(microseconds) does units
## until the time is up and says whether it is done; step(-1) does them all.
## The units and their order are the same either way. Then samples() (the
## loop as numbers), bytes (16 bit, with GUARD frames either side) and
## stream() (the looping sound).
class Render:
	extends RefCounted

	var frames: int = 0
	## "wrap" or "breath" (see RealmMusic.breath).
	var seam: String = "wrap"
	var done: bool = false
	## Units of work done so far.
	var units: int = 0
	## What the loop is multiplied by to bring it to its level.
	var gain: float = 1.0
	## Peak and RMS of the loop at that level.
	var peak: float = 0.0
	var rms: float = 0.0
	var bytes: PackedByteArray = PackedByteArray()
	## Different notes rendered (the tune's notes share them).
	var stamp_count: int = 0

	var _out: PackedFloat32Array = PackedFloat32Array()
	var _stamps: Array = []
	var _bufs: Array = []
	var _events: Array = []
	var _phase: int = 0
	var _si: int = 0
	var _pi: int = 0
	var _ei: int = 0
	var _pos: int = 0
	var _x: float = 0.0
	var _y: float = 0.0
	var _one: Array = [0.0, 0.0, 0.0, 0.0]
	var _two: Array = [0.0, 0.0, 0.0, 0.0]
	var _seed: int = 1
	var _l1: float = 0.0
	var _l2: float = 0.0
	var _l3: float = 0.0
	var _hp: float = 0.0
	var _g: float = 0.0
	var _sum: float = 0.0
	var _top: float = 0.0

	func _init(sc: Dictionary) -> void:
		frames = int(sc.frames)
		seam = str(sc.get("seam", "wrap"))
		_out.resize(frames)
		_out.fill(0.0)
		var fpb = 60.0 / float(sc.tempo) * RATE
		var style = str(sc.style)
		var mix = sc.mix
		var index = {}
		for voice in ["bass", "pad", "arp", "lead"]:
			var level = float(mix.get(voice, 0.0))
			if level <= 0.0:
				continue
			var artic = 1.0
			if voice == "lead":
				artic = 0.96 if style == "calm" else 0.92
			elif voice == "bass":
				artic = 0.9
			var notes = sc.voices.get(voice, [])
			if voice == "pad":
				notes = _chords(notes)
			for n in notes:
				var hold = maxi(1, roundi(float(n[1]) * fpb * artic))
				var key = "%s:%s:%d" % [voice, str(n[2]), 0 if voice == "arp" else hold]
				if not index.has(key):
					index[key] = _add(_tone_spec(style, voice, n[2], hold))
				_events.append([int(index[key]), posmod(roundi(float(n[0]) * fpb), frames), float(n[3]) * level])
		for drum in ["kick", "snare", "hat", "shaker"]:
			var level = float(mix.get(drum, 0.0))
			var hits = sc.drums.get(drum, [])
			if level <= 0.0 or hits.is_empty():
				continue
			var si = _add(_drum_spec(drum, style))
			for h in hits:
				_events.append([si, posmod(roundi(float(h[0]) * fpb), frames), float(h[1]) * level])
		stamp_count = _stamps.size()

	## Held notes that start together and last as long are one note of several
	## pitches (at most four): [beat, beats, [MIDI notes], loudness].
	static func _chords(notes: Array) -> Array:
		var out = []
		var at = {}
		for n in notes:
			var key = "%s:%s:%s" % [str(n[0]), str(n[1]), str(n[3])]
			if at.has(key) and out[int(at[key])][2].size() < 4:
				out[int(at[key])][2].append(int(n[2]))
			else:
				at[key] = out.size()
				out.append([n[0], n[1], [int(n[2])], n[3]])
		return out

	## A stamp to render. Its parts that keep their pitch ("plain", at most four
	## are rendered together) and those whose pitch moves ("moving").
	func _add(spec: Dictionary) -> int:
		var buf = PackedFloat32Array()
		buf.resize(int(spec.len))
		buf.fill(0.0)
		var plain = []
		var moving = []
		for p in spec.parts:
			if float(p[3]) == 0.0 and float(p[5]) == 0.0 and plain.size() < 4:
				plain.append(p)
			else:
				moving.append(p)
		spec["plain"] = plain
		spec["moving"] = moving
		# Two or three parts that only have vibrato (a long lead note and its
		# overtones) wobble as one and are rendered in one go.
		var together = moving.size() >= 2 and moving.size() <= 3
		for p in moving:
			if float(p[3]) != 0.0 or float(p[5]) == 0.0:
				together = false
		spec["together"] = together
		_stamps.append(spec)
		_bufs.append(buf)
		return _stamps.size() - 1

	static func hz(midi: int) -> float:
		return 440.0 * pow(2.0, (midi - 69) / 12.0)

	## A part of a note: [hertz, level, seconds to fade to 1/e (0 = it does not
	## fade), how far above its pitch it starts (0.5 = half as high again),
	## seconds that takes to settle, 1 = vibrato].
	static func _part(f: float, level: float, tau: float, drop: float = 0.0, drop_tau: float = 0.0, vib: bool = false) -> Array:
		return [f, level, tau, drop, drop_tau, 1.0 if vib else 0.0]

	## What a note of a voice is made of: {len, attack, release (frames), parts,
	## noise (null)}. `note` is its MIDI note (for held notes: the notes sounding
	## together), `hold` how long it is held, in frames.
	static func _tone_spec(style: String, voice: String, note, hold: int) -> Dictionary:
		var f = hz(int(note[0]) if note is Array else int(note))
		var calm = style == "calm"
		var parts = []
		var attack = 0.01
		var release = 0.05
		var length = hold
		match voice:
			"lead":
				# A sine with two soft overtones that die sooner; a little
				# vibrato once a long note has settled.
				var tau = 1.6 if calm else 1.0
				var h2 = 0.18 if calm else (0.3 if style == "boss" else 0.24)
				var h3 = 0.05 if calm else (0.12 if style == "boss" else 0.08)
				var vib = hold >= int(0.4 * RATE)
				attack = 0.03 if calm else 0.012
				release = 0.14 if calm else 0.06
				parts.append(_part(f, 1.0, tau, 0.0, 0.0, vib))
				parts.append(_part(f * 2.0, h2, tau * 0.7, 0.0, 0.0, vib))
				if f * 3.0 < TOP_HZ:
					parts.append(_part(f * 3.0, h3, tau * 0.5, 0.0, 0.0, vib))
			"bass":
				# The odd overtones of a triangle wave (1, 1/9, 1/25) and the
				# octave, so it is heard on a small speaker too.
				var tau = 1.2 if calm else 0.45
				attack = 0.02 if calm else 0.006
				release = 0.15 if calm else 0.04
				parts.append(_part(f, 1.0, tau))
				parts.append(_part(f * 2.0, 0.38, tau * 0.8))
				parts.append(_part(f * 3.0, 0.11, tau * 0.6))
				parts.append(_part(f * 5.0, 0.04, tau * 0.4))
			"arp":
				# A pluck: it rings out by itself, however long the note.
				var tau = 0.28 if calm else 0.11
				length = int((0.95 if calm else 0.42) * RATE)
				attack = 0.004
				release = (0.3 if calm else 0.13)
				parts.append(_part(f, 1.0, tau))
				parts.append(_part(f * 2.0, 0.12, tau * 0.6))
				return {"len": length, "attack": int(attack * RATE), "release": int(release * RATE), "parts": parts, "noise": null}
			_:
				# Held notes that swell in and out: a plain sine each.
				attack = 0.4 if calm else 0.25
				release = 0.7 if calm else 0.4
				for m in (note if note is Array else [note]):
					parts.append(_part(hz(int(m)), 1.0, 0.0))
		var rel = int(release * RATE)
		return {"len": length + rel, "attack": mini(int(attack * RATE), length), "release": rel, "parts": parts, "noise": null}

	## A drum. noise: {level, lp, hp (hertz it is kept between), tau, seed}.
	static func _drum_spec(drum: String, style: String) -> Dictionary:
		match drum:
			"kick":
				# A sine that drops from about 140 to 56 Hz, and a short knock
				# above it that a small speaker can play.
				var soft = style == "calm"
				return {"len": int(0.3 * RATE), "attack": int((0.004 if soft else 0.002) * RATE), "release": int(0.06 * RATE),
					"parts": [_part(56.0, 1.0, 0.1 if soft else 0.085, 1.5, 0.028), _part(150.0, 0.14 if soft else 0.24, 0.03, 0.5, 0.02)], "noise": null}
			"snare":
				# A soft tap: a short low note under a breath of noise.
				return {"len": int(0.2 * RATE), "attack": int(0.002 * RATE), "release": int(0.05 * RATE),
					"parts": [_part(185.0, 0.3, 0.04, 0.3, 0.02)], "noise": {"level": 1.0, "lp": 1900.0, "hp": 400.0, "tau": 0.045, "seed": 20261}}
			"hat":
				return {"len": int(0.07 * RATE), "attack": int(0.001 * RATE), "release": int(0.03 * RATE),
					"parts": [], "noise": {"level": 1.0, "lp": 2300.0, "hp": 1000.0, "tau": 0.016, "seed": 7103}}
		# A shaker: the same noise, coming in softly and lasting longer.
		return {"len": int(0.15 * RATE), "attack": int(0.012 * RATE), "release": int(0.06 * RATE),
			"parts": [], "noise": {"level": 1.0, "lp": 2100.0, "hp": 800.0, "tau": 0.045, "seed": 4219}}

	func step(budget_usec: int = -1) -> bool:
		var t0 = Time.get_ticks_usec()
		while not done:
			match _phase:
				0:
					_synth()
				1:
					_mix()
				2:
					_measure()
				_:
					_encode()
			units += 1
			if budget_usec >= 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				break
		return done

	## The loop as numbers, at the level it is played at.
	func samples() -> PackedFloat32Array:
		var res = PackedFloat32Array()
		if not done:
			return res
		res.resize(frames)
		var k: float = gain
		for i in range(frames):
			res[i] = _out[i] * k
		return res

	## The loop as a sound that goes round without a seam.
	func stream() -> AudioStreamWAV:
		if not done:
			return null
		var s = AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = RATE
		s.stereo = false
		s.data = bytes
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = GUARD
		s.loop_end = GUARD + frames
		return s

	## One unit: a stretch of a stamp's plain parts, of one moving part, of its
	## noise, or of its shape.
	func _synth() -> void:
		if _si >= _stamps.size():
			_phase = 1
			_pos = 0
			return
		var st = _stamps[_si]
		var moving = st.moving.size()
		if _pi == 0:
			if st.plain.is_empty():
				_pi = 1
			else:
				_plain(st)
		elif _pi <= moving:
			if st.together:
				_wobble(st)
			else:
				_moving(st, st.moving[_pi - 1])
		elif _pi == moving + 1:
			if st.noise == null:
				_pi += 1
				_pos = 0
			else:
				_noise(st)
		else:
			_shape(st)

	## The parts of a note that keep their pitch, together. A decaying sine is
	## worked out from its two samples before (no sin() per sample): `one` holds
	## each part's newest sample, `two` the one before, and a turn of the loop
	## makes two samples by swapping their roles.
	func _plain(st: Dictionary) -> void:
		var n: int = st.len
		var buf: PackedFloat32Array = _bufs[_si]
		var parts: Array = st.plain
		var count: int = parts.size()
		var k: Array = [0.0, 0.0, 0.0, 0.0]
		var q: Array = [0.0, 0.0, 0.0, 0.0]
		if _pos == 0:
			_one = [0.0, 0.0, 0.0, 0.0]
			_two = [0.0, 0.0, 0.0, 0.0]
		for j in range(count):
			var p = parts[j]
			var r = 1.0
			if float(p[2]) > 0.0:
				r = exp(-1.0 / (float(p[2]) * RATE))
			var w = TAU * float(p[0]) / RATE
			k[j] = 2.0 * r * cos(w)
			q[j] = r * r
			if _pos == 0:
				# As if the sample before the first were level * sin(-w) / r.
				_two[j] = -float(p[1]) * sin(w) / r
		var a: int = _pos
		var b: int = mini(n, a + CHUNK)
		var ka: float = k[0]
		var qa: float = q[0]
		var kb: float = k[1]
		var qb: float = q[1]
		var kc: float = k[2]
		var qc: float = q[2]
		var kd: float = k[3]
		var qd: float = q[3]
		var a1: float = _one[0]
		var a2: float = _two[0]
		var b1: float = _one[1]
		var b2: float = _two[1]
		var c1: float = _one[2]
		var c2: float = _two[2]
		var d1: float = _one[3]
		var d2: float = _two[3]
		match count:
			1:
				for i in range(a, b - 1, 2):
					a2 = ka * a1 - qa * a2
					buf[i] = a2
					a1 = ka * a2 - qa * a1
					buf[i + 1] = a1
			2:
				for i in range(a, b - 1, 2):
					a2 = ka * a1 - qa * a2
					b2 = kb * b1 - qb * b2
					buf[i] = a2 + b2
					a1 = ka * a2 - qa * a1
					b1 = kb * b2 - qb * b1
					buf[i + 1] = a1 + b1
			3:
				for i in range(a, b - 1, 2):
					a2 = ka * a1 - qa * a2
					b2 = kb * b1 - qb * b2
					c2 = kc * c1 - qc * c2
					buf[i] = a2 + b2 + c2
					a1 = ka * a2 - qa * a1
					b1 = kb * b2 - qb * b1
					c1 = kc * c2 - qc * c1
					buf[i + 1] = a1 + b1 + c1
			_:
				for i in range(a, b - 1, 2):
					a2 = ka * a1 - qa * a2
					b2 = kb * b1 - qb * b2
					c2 = kc * c1 - qc * c2
					d2 = kd * d1 - qd * d2
					buf[i] = a2 + b2 + c2 + d2
					a1 = ka * a2 - qa * a1
					b1 = kb * b2 - qb * b1
					c1 = kc * c2 - qc * c1
					d1 = kd * d2 - qd * d1
					buf[i + 1] = a1 + b1 + c1 + d1
		if (b - a) % 2 == 1:
			# The last sample of a stamp with an odd number of them.
			var t: float = ka * a1 - qa * a2
			a2 = a1
			a1 = t
			t = kb * b1 - qb * b2
			b2 = b1
			b1 = t
			t = kc * c1 - qc * c2
			c2 = c1
			c1 = t
			t = kd * d1 - qd * d2
			d2 = d1
			d1 = t
			buf[b - 1] = a1 + b1 + c1 + d1
		_one = [a1, b1, c1, d1]
		_two = [a2, b2, c2, d2]
		_pos = b
		if b >= n:
			_pi = 1
			_pos = 0

	## A part whose pitch moves (vibrato, a drum's drop): a point turned by the
	## note's angle each sample, and pulled in a little as it fades; its height
	## is the sound. The angle is set anew every BLOCK samples, and turning
	## never changes the point's distance, so the loudness is not disturbed.
	func _moving(st: Dictionary, p: Array) -> void:
		var n: int = st.len
		var buf: PackedFloat32Array = _bufs[_si]
		if _pos == 0:
			_x = float(p[1])
			_y = 0.0
		var freq: float = p[0]
		var tau: float = p[2]
		var r: float = 1.0
		if tau > 0.0:
			r = exp(-1.0 / (tau * RATE))
		var drop: float = p[3]
		var drop_tau: float = p[4]
		var vib: bool = float(p[5]) > 0.0
		var a: int = _pos
		var b: int = mini(n, a + CHUNK)
		var x: float = _x
		var y: float = _y
		var c: float = 0.0
		var s: float = 0.0
		var nx: float = 0.0
		var k: int = a
		while k < b:
			var e: int = mini(b, k + BLOCK)
			var t: float = float(k) / RATE
			var f: float = freq
			if drop != 0.0:
				f *= 1.0 + drop * exp(-t / drop_tau)
			if vib:
				f *= 1.0 + VIB_DEPTH * clampf((t - VIB_DELAY) / VIB_RAMP, 0.0, 1.0) * sin(TAU * VIB_HZ * t)
			var w: float = TAU * f / RATE
			c = r * cos(w)
			s = r * sin(w)
			for i in range(k, e):
				nx = x * c - y * s
				y = x * s + y * c
				x = nx
				buf[i] += y
			k = e
		_x = x
		_y = y
		_pos = b
		if b >= n:
			_pi += 1
			_pos = 0

	## A long lead note: its two or three parts turned together, with the same
	## vibrato (see _moving), one sum written per sample.
	func _wobble(st: Dictionary) -> void:
		var n: int = st.len
		var buf: PackedFloat32Array = _bufs[_si]
		var parts: Array = st.moving
		var count: int = parts.size()
		var fr: Array = [0.0, 0.0, 0.0]
		var rr: Array = [1.0, 1.0, 1.0]
		if _pos == 0:
			_one = [0.0, 0.0, 0.0, 0.0]
			_two = [0.0, 0.0, 0.0, 0.0]
		for j in range(count):
			var p = parts[j]
			fr[j] = TAU * float(p[0]) / RATE
			if float(p[2]) > 0.0:
				rr[j] = exp(-1.0 / (float(p[2]) * RATE))
			if _pos == 0:
				_one[j] = float(p[1])
		var a: int = _pos
		var b: int = mini(n, a + CHUNK)
		var xa: float = _one[0]
		var ya: float = _two[0]
		var xb: float = _one[1]
		var yb: float = _two[1]
		var xc: float = _one[2]
		var yc: float = _two[2]
		var wa: float = fr[0]
		var wb: float = fr[1]
		var wc: float = fr[2]
		var ra: float = rr[0]
		var rb: float = rr[1]
		var rc: float = rr[2]
		var ca: float = 0.0
		var sa: float = 0.0
		var cb: float = 0.0
		var sb: float = 0.0
		var cc: float = 0.0
		var sc: float = 0.0
		var nx: float = 0.0
		var k: int = a
		while k < b:
			var e: int = mini(b, k + BLOCK)
			var t: float = float(k) / RATE
			var m: float = 1.0 + VIB_DEPTH * clampf((t - VIB_DELAY) / VIB_RAMP, 0.0, 1.0) * sin(TAU * VIB_HZ * t)
			ca = ra * cos(wa * m)
			sa = ra * sin(wa * m)
			cb = rb * cos(wb * m)
			sb = rb * sin(wb * m)
			if count == 3:
				cc = rc * cos(wc * m)
				sc = rc * sin(wc * m)
				for i in range(k, e):
					nx = xa * ca - ya * sa
					ya = xa * sa + ya * ca
					xa = nx
					nx = xb * cb - yb * sb
					yb = xb * sb + yb * cb
					xb = nx
					nx = xc * cc - yc * sc
					yc = xc * sc + yc * cc
					xc = nx
					buf[i] += ya + yb + yc
			else:
				for i in range(k, e):
					nx = xa * ca - ya * sa
					ya = xa * sa + ya * ca
					xa = nx
					nx = xb * cb - yb * sb
					yb = xb * sb + yb * cb
					xb = nx
					buf[i] += ya + yb
			k = e
		_one = [xa, xb, xc, 0.0]
		_two = [ya, yb, yc, 0.0]
		_pos = b
		if b >= n:
			_pi = count + 1
			_pos = 0

	## Noise with the top taken off (three gentle low-passes) and the bottom
	## too, fading.
	func _noise(st: Dictionary) -> void:
		var n: int = st.len
		var buf: PackedFloat32Array = _bufs[_si]
		var nz = st.noise
		if _pos == 0:
			_seed = int(nz.seed)
			_l1 = 0.0
			_l2 = 0.0
			_l3 = 0.0
			_hp = 0.0
			_g = float(nz.level)
		var al: float = 1.0 - exp(-TAU * float(nz.lp) / RATE)
		var ah: float = 1.0 - exp(-TAU * float(nz.hp) / RATE)
		var r: float = exp(-1.0 / (float(nz.tau) * RATE))
		var a: int = _pos
		var b: int = mini(n, a + CHUNK)
		var sd: int = _seed
		var l1: float = _l1
		var l2: float = _l2
		var l3: float = _l3
		var hp: float = _hp
		var g: float = _g
		var v: float = 0.0
		for i in range(a, b):
			sd = (sd * 1103515245 + 12345) & 0x7fffffff
			v = sd / 1073741824.0 - 1.0
			l1 += al * (v - l1)
			l2 += al * (l1 - l2)
			l3 += al * (l2 - l3)
			hp += ah * (l3 - hp)
			buf[i] += (l3 - hp) * g
			g *= r
		_seed = sd
		_l1 = l1
		_l2 = l2
		_l3 = l3
		_hp = hp
		_g = g
		_pos = b
		if b >= n:
			_pi += 1
			_pos = 0

	## A stamp's beginning swells in and its end dies away (no click).
	func _shape(st: Dictionary) -> void:
		var n: int = st.len
		var buf: PackedFloat32Array = _bufs[_si]
		var na: int = mini(int(st.attack), n)
		var nr: int = mini(int(st.release), n - na)
		var total: int = na + nr
		var a: int = _pos
		var b: int = mini(total, a + CHUNK)
		var t: float = 0.0
		for i in range(a, b):
			if i < na:
				t = float(i) / na
				buf[i] *= t * t * (3.0 - 2.0 * t)
			else:
				t = float(i - na + 1) / nr
				buf[n - nr + i - na] *= 1.0 - t * t * (3.0 - 2.0 * t)
		_pos = b
		if b >= total:
			_si += 1
			_pi = 0
			_pos = 0

	## A stretch of one note's stamp added into the loop; what runs past the
	## loop's end goes on at its start (or, for a loop that breathes at its
	## seam, is left out).
	func _mix() -> void:
		if _ei >= _events.size():
			if seam == "breath":
				_die_away()
			_phase = 2
			_pos = 0
			_sum = 0.0
			_top = 0.0
			_stamps.clear()
			_bufs.clear()
			return
		var ev = _events[_ei]
		var sb: PackedFloat32Array = _bufs[int(ev[0])]
		var out: PackedFloat32Array = _out
		var n: int = sb.size()
		if seam == "breath":
			n = mini(n, frames - int(ev[1]))
		var g: float = ev[2]
		var a: int = _pos
		var b: int = mini(n, a + MIX_CHUNK)
		var at: int = (int(ev[1]) + a) % frames
		var off: int = at - a
		var first: int = mini(b, a + frames - at)
		for i in range(a, first):
			out[i + off] += sb[i] * g
		if first < b:
			off -= frames
			for i in range(first, b):
				out[i + off] += sb[i] * g
		_pos = b
		if b >= n:
			_ei += 1
			_pos = 0

	## The loop's last moment fades to nothing (a loop that breathes).
	func _die_away() -> void:
		var out: PackedFloat32Array = _out
		var n: int = mini(frames, int(BREATH_OUT * RATE))
		var t: float = 0.0
		for i in range(n):
			t = float(i + 1) / n
			out[frames - n + i] *= 1.0 - t * t * (3.0 - 2.0 * t)

	## How loud the loop came out, and so what to multiply it by.
	func _measure() -> void:
		var out: PackedFloat32Array = _out
		var a: int = _pos
		var b: int = mini(frames, a + MIX_CHUNK)
		var sum: float = _sum
		var top: float = _top
		var v: float = 0.0
		for i in range(a, b):
			v = out[i]
			sum += v * v
			if v > top:
				top = v
			elif -v > top:
				top = -v
		_sum = sum
		_top = top
		_pos = b
		if b >= frames:
			var raw = sqrt(sum / maxi(1, frames))
			gain = 0.0
			if raw > 0.0 and top > 0.0:
				gain = minf(RMS_AIM / raw, PEAK_MAX / top)
			rms = raw * gain
			peak = top * gain
			bytes.resize((frames + 2 * GUARD) * 2)
			bytes.fill(0)
			_phase = 3
			_pos = 0

	## The loop as 16 bit numbers, with the guard frames either side.
	func _encode() -> void:
		var out: PackedFloat32Array = _out
		var by: PackedByteArray = bytes
		var a: int = _pos
		var b: int = mini(frames, a + MIX_CHUNK)
		var k: float = gain * 32767.0
		var base: int = GUARD * 2
		for i in range(a, b):
			by.encode_s16(base + i * 2, roundi(out[i] * k))
		_pos = b
		if b >= frames:
			# Before the loop its last frames, after it its first ones (a loop
			# that breathes has silence there).
			if seam != "breath":
				for j in range(GUARD):
					bytes.encode_s16(j * 2, roundi(out[posmod(frames - GUARD + j, frames)] * k))
					bytes.encode_s16((GUARD + frames + j) * 2, roundi(out[j % frames] * k))
			done = true
