extends SceneTree
## Pixel-exact parity test of the art port.
##
##   godot --headless --path <project> --script res://tests/parity_art.gd
##
## tests/parity/art_cases.json holds heroes, scenes, pets and bosses rendered
## by the original TypeScript drawing code (regenerate it with
## tests/parity/gen_art.ts). Every case is rendered again with the GDScript
## port and the raw RGBA bytes are compared. Exit code 0 = all cases identical.

const CASES_PATH = "res://tests/parity/art_cases.json"
const MAX_REPORTED = 5


func _init() -> void:
	var text: String = FileAccess.get_file_as_string(CASES_PATH)
	if text == "":
		print("PARITY art: cannot read " + CASES_PATH)
		quit(1)
		return
	var doc = TTUtil.normalize_json(JSON.parse_string(text))
	if doc == null or not (doc is Dictionary) or not doc.has("cases"):
		print("PARITY art: " + CASES_PATH + " is not a case file")
		quit(1)
		return
	var cases: Array = doc.cases
	var passed: int = 0
	var t0: int = Time.get_ticks_msec()
	for c in cases:
		if _check(c):
			passed += 1
	print("PARITY art: %d/%d passed (%d ms)" % [passed, cases.size(), Time.get_ticks_msec() - t0])
	quit(0 if passed == cases.size() else 1)


## Renders one case with the GDScript port. Returns null for an unknown kind.
func _render(kind: String, a: Dictionary):
	match kind:
		"hero":
			return Art.hero_pix(a.state, a.profile, a.loadout, a.pose, a.frame, a.happy)
		"visuals":
			# drawHero() fed with visuals directly (not through a loadout).
			var p: Pix = Pix.new(HeroBody.HERO_W, HeroBody.HERO_H)
			HeroBody.draw_hero(p, a.input, {"visuals": a.visuals, "noOutline": a.noOutline})
			return p
		"scene":
			return Art.scene_pix(a.state, a.profile, a.loadout, a.activePet, a.pose, a.frame, a.happy, a.hour)
		"pet":
			return Art.pet_pix(a.id, a.frame)
		"boss":
			return Art.boss_pix(a.id, a.silhouette)
		"item":
			return Art.item_pix(a.id)
	return null


func _check(c: Dictionary) -> bool:
	var case_name: String = c.name
	var p = _render(c.kind, c.args)
	if p == null:
		print("FAIL %s: unknown kind '%s'" % [case_name, c.kind])
		return false
	var cw: int = c.w
	var ch: int = c.h
	if p.w != cw or p.h != ch:
		print("FAIL %s: size %dx%d, expected %dx%d" % [case_name, p.w, p.h, cw, ch])
		return false
	var want: PackedByteArray = Marshalls.base64_to_raw(c.rgba)
	var got: PackedByteArray = p.to_bytes()
	if want.size() != cw * ch * 4 or got.size() != want.size():
		print("FAIL %s: %d bytes rendered, fixture has %d, expected %d" % [case_name, got.size(), want.size(), cw * ch * 4])
		return false
	if got == want:
		# The texture path must carry the very same bytes.
		var img: Image = p.to_image()
		if img.get_width() != cw or img.get_height() != ch or img.get_data() != want:
			print("FAIL %s: to_image() does not match the buffer" % case_name)
			return false
		return true
	var diffs: int = 0
	var lines: Array = []
	for i in range(cw * ch):
		var o: int = i * 4
		if got[o] == want[o] and got[o + 1] == want[o + 1] and got[o + 2] == want[o + 2] and got[o + 3] == want[o + 3]:
			continue
		diffs += 1
		if lines.size() < MAX_REPORTED:
			lines.append("    (%d,%d) got %s expected %s" % [i % cw, int(i / float(cw)), _rgba(got, o), _rgba(want, o)])
	print("FAIL %s: %d of %d pixels differ" % [case_name, diffs, cw * ch])
	for line in lines:
		print(line)
	return false


func _rgba(bytes: PackedByteArray, o: int) -> String:
	if bytes[o + 3] == 0:
		return "empty"
	return "#%02x%02x%02x%s" % [bytes[o], bytes[o + 1], bytes[o + 2], "" if bytes[o + 3] == 255 else "/a%d" % bytes[o + 3]]
