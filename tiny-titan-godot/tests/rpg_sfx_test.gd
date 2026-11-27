extends SceneTree
## Unit test for the Realm's sounds (ui/rpg/rpg_sfx.gd): every one renders, is
## soft (sine, triangle and low-passed noise only, no clipping, little in the
## harsh high end), short, and every sound a screen asks for exists.
##   godot --headless --path . --script res://tests/rpg_sfx_test.gd
## Prints RPG SFX: X/Y passed and exits with 1 when anything fails.

const RATE = 22050.0
## Scripts that play the Realm's sounds by name.
const USERS = ["res://ui/rpg/battle_view.gd", "res://ui/rpg/battle_result.gd", "res://ui/rpg/realm.gd", "res://ui/rpg/realm_map.gd",
	"res://ui/rpg/realm_hero.gd", "res://ui/rpg/realm_moves.gd", "res://ui/rpg/realm_skills.gd", "res://ui/rpg/realm_gear.gd",
	"res://ui/rpg/rpg_ui.gd", "res://ui/rpg/rpg_sfx.gd", "res://ui/rpg/battle_widgets.gd"]

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


## The share of its energy above `hz`: a 512-point transform of its loudest stretch.
func share_above(s: Array, hz: float) -> float:
	var n = 512
	var best = 0
	var best_e = -1.0
	var step = 256
	var i0 = 0
	while i0 + n <= s.size():
		var en = 0.0
		for i in range(i0, i0 + n, 4):
			en += s[i] * s[i]
		if en > best_e:
			best_e = en
			best = i0
		i0 += step
	var all = 0.0
	var high = 0.0
	for k in range(1, n / 2):
		var re = 0.0
		var im = 0.0
		for i in range(mini(n, s.size() - best)):
			var a = TAU * k * i / n
			re += s[best + i] * cos(a)
			im += s[best + i] * sin(a)
		var m = re * re + im * im
		all += m
		if k * RATE / n > hz:
			high += m
	return high / all if all > 0.0 else 0.0


func _run() -> void:
	var S = load("res://app/sfx.gd").new()
	var R = load("res://ui/rpg/rpg_sfx.gd")
	ok(R.SOUNDS.size() >= 60, "a sound for every thing that happens: 60 or more", R.SOUNDS.size())
	var waves = []
	var clipped = []
	var quiet = []
	var long = []
	var harsh = []
	var worst = 0.0
	for k in R.SOUNDS:
		for n in R.SOUNDS[k]:
			if not ["sine", "triangle", "noise"].has(str(n[3])):
				waves.append(k)
			if str(n[3]) == "noise" and n.size() > 5 and float(n[5].get("lp", 1800.0)) > 3300.0:
				harsh.append("%s noise to %d Hz" % [k, int(n[5].lp)])
		var st = S._render(R.SOUNDS[k])
		var s = samples(st)
		var p = peak_of(s)
		if p > 0.8:
			clipped.append("%s %.2f" % [k, p])
		if p < 0.03:
			quiet.append("%s %.3f" % [k, p])
		if s.size() / RATE > 1.6:
			long.append("%s %.2f s" % [k, s.size() / RATE])
		var hi = share_above(s, 4000.0)
		worst = maxf(worst, hi)
		if hi > 0.12:
			harsh.append("%s %.0f%% over 4 kHz" % [k, hi * 100.0])
	ok(waves.is_empty(), "only sine, triangle and soft noise: no square, no sawtooth", waves)
	ok(clipped.is_empty(), "none is loud enough to clip", clipped)
	ok(quiet.is_empty(), "none is too quiet to hear", quiet)
	ok(long.is_empty(), "none runs longer than 1.6 seconds", long)
	ok(harsh.is_empty(), "little in the harsh high end (worst %.1f%% over 4 kHz)" % (worst * 100.0), harsh)
	# The same notes give the same sound (the noise is its own generator, not randf).
	var a = S._render(R.SOUNDS["hit_push"]).data
	var b = S._render(R.SOUNDS["hit_push"]).data
	ok(a == b, "a sound is the same every time it is rendered")
	for sc in ["push", "pull", "legs", "speed", "grip", "mind", "plain"]:
		ok(R.HITS.has(sc) and R.SOUNDS.has(str(R.HITS[sc])), "a hit of its own for %s" % sc)
	var hits = {}
	for sc in R.HITS:
		hits[str(R.HITS[sc])] = S._render(R.SOUNDS[R.HITS[sc]]).data
	var same = []
	var names = hits.keys()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			if hits[names[i]] == hits[names[j]]:
				same.append("%s = %s" % [names[i], names[j]])
	ok(same.is_empty(), "no two schools sound the same", same)
	# Every sound asked for by name exists.
	var missing = []
	var asked = {}
	var re = RegEx.new()
	re.compile("(?:_snd|RpgSfx\\.play|RpgUi\\.sound)\\(\"([a-z_0-9]+)\"")
	for path in USERS:
		if not FileAccess.file_exists(path):
			continue
		var text = FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var name = m.get_string(1)
			asked[name] = true
			if not R.SOUNDS.has(name):
				missing.append("%s in %s" % [name, path.get_file()])
	ok(missing.is_empty(), "every sound a screen asks for exists", missing)
	ok(asked.size() >= 30, "the fight asks for 30 sounds or more", asked.size())
	S.free()
	print("RPG SFX: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
