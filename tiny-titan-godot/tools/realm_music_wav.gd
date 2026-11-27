extends SceneTree
## Writes the Realm's music (app/realm_music.gd) as .wav files to listen to:
## the hub, the result, and the eight regions' battle and boss tunes, each
## loop twice in a row (so the place where it goes round is heard).
##   set REALM_MUSIC_OUT=<folder>
##   godot --headless --path . --script res://tools/realm_music_wav.gd
## The files are LOUDER than the game plays the tunes (BOOST_DB over the level
## they are rendered at, which the game then turns down further), so they can
## be judged at an ordinary volume. REALM_MUSIC_BOOST=0 writes them as rendered.
## REALM_MUSIC_SEAM=breath writes them as the phone app plays them: each loop
## dying away at its end, and GAP_SEC of nothing before it starts again (the
## web build starts a looping sound again when it has ended; see
## RealmMusic.breath). Without it: the loop that goes round, as on the PC.

const BOOST_DB = 9.0
const TIMES = 2
const GAP_SEC = 0.04


func _init() -> void:
	var M = load("res://app/realm_music.gd")
	var dir = OS.get_environment("REALM_MUSIC_OUT")
	if dir == "":
		print("Set REALM_MUSIC_OUT to the folder the .wav files go in.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var boost = BOOST_DB
	if OS.has_environment("REALM_MUSIC_BOOST"):
		boost = float(OS.get_environment("REALM_MUSIC_BOOST"))
	var up = db_to_linear(boost)
	var breathe = OS.get_environment("REALM_MUSIC_SEAM") == "breath"
	var gap = int(GAP_SEC * M.RATE) if breathe else 0
	var keys = ["hub", "result"]
	for r in range(M.REGIONS):
		keys.append("battle:%d" % r)
	for r in range(M.REGIONS):
		keys.append("boss:%d" % r)
	for key in keys:
		var sc = M.score_of_key(key)
		if breathe:
			sc["seam"] = "breath"
		var t0 = Time.get_ticks_msec()
		var s = M.render_all(sc)
		var ms = Time.get_ticks_msec() - t0
		var n = s.size()
		var bytes = PackedByteArray()
		bytes.resize((n + gap) * TIMES * 2)
		bytes.fill(0)
		for t in range(TIMES):
			for i in range(n):
				bytes.encode_s16((t * (n + gap) + i) * 2, roundi(clampf(s[i] * up, -1.0, 1.0) * 32767.0))
		var st = AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = M.RATE
		st.stereo = false
		st.data = bytes
		var name = "%s.wav" % key.replace(":", "_")
		var err = st.save_to_wav(dir.path_join(name))
		print("%-14s %5.1f s x%d  %3d bpm  %s %s  rendered in %d ms%s" % [name, float(sc.seconds), TIMES, int(sc.tempo), note_name(int(sc.tonic)), sc.mode, ms, "" if err == OK else "  NOT WRITTEN (%d)" % err])
	print("Written to %s, %.0f dB louder than the game renders them%s." % [dir, boost, ", breathing at the seam with a gap of %d ms" % int(GAP_SEC * 1000.0) if breathe else ""])
	quit(0)


func note_name(midi: int) -> String:
	return ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"][posmod(midi, 12)]
