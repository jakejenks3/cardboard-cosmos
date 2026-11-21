extends SceneTree
## Unit test for the game's own hero (avatar/hero_figure.gd, avatar/figure_gear.gd):
## it fits its canvas at every level and pose, the body is symmetric, it grows
## with the levels, every piece of gear draws on it, facial hair shows, and the
## original look (Pix.classic) keeps its own canvas.
##   godot --headless --path . --script res://tests/figure_test.gd
## Prints FIGURE: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0


func ok(cond: bool, what: String, detail = "") -> void:
	total += 1
	if cond:
		passed += 1
	else:
		print("FAIL  %s  %s" % [what, str(detail)])


func input(lv: Array, pose: String, extra: Dictionary = {}) -> Dictionary:
	var i = {"heroLevel": lv[0], "liftLevel": lv[1], "climbLevel": lv[2], "runLevel": lv[3], "rideLevel": lv[4],
		"skin": 1, "hairStyle": 0, "hairColor": 1, "pose": pose, "frame": 0, "blink": false, "happy": false, "look": 0}
	i.merge(extra, true)
	return i


func filled(p: Pix) -> int:
	var n = 0
	for v in p.data:
		if v != 0:
			n += 1
	return n


func _init() -> void:
	Pix.classic = false
	ok(HeroBody.width() == HeroFigure.W and HeroBody.height() == HeroFigure.H, "the game's look draws on the figure's canvas")
	var levels = [[1, 1, 1, 1, 1], [12, 12, 6, 6, 6], [30, 30, 15, 15, 12], [60, 60, 40, 40, 40], [60, 1, 40, 1, 40], [60, 60, 1, 1, 1]]
	var keys = ["t", "stage", "cx", "baseline", "headW", "headH", "headTop", "headLeft", "eyeY", "neckW", "neckTop", "neckH", "torsoTop",
		"torsoBottom", "torsoH", "shoulderW", "waistW", "torsoW", "torsoLeft", "armL", "armR", "legL", "legR", "legTop", "legLen",
		"feetTop", "footH", "footL", "footR", "pose", "skin", "hair"]
	var bad_keys = []
	var edge = []
	var sizes = {}
	for lv in levels:
		for pose in ["idle", "flex", "press", "pull", "squat", "curl"]:
			var m = HeroFigure.metrics(input(lv, pose))
			for k in keys:
				if not m.has(k):
					bad_keys.append(k)
			var p = Pix.new(HeroFigure.W, HeroFigure.H)
			HeroBody.draw_hero(p, input(lv, pose), {"visuals": {}})
			# a free row and column all round (the outline is inside the canvas)
			for x in range(HeroFigure.W):
				if p.data[x] != 0:
					edge.append("%s %s top" % [str(lv), pose])
					break
			for y in range(HeroFigure.H):
				if p.data[y * HeroFigure.W] != 0 or p.data[y * HeroFigure.W + HeroFigure.W - 1] != 0:
					edge.append("%s %s side y%d" % [str(lv), pose, y])
					break
			sizes["%d.%s" % [lv[0] * 1000 + lv[1], pose]] = filled(p)
	ok(bad_keys.is_empty(), "the figure gives every field the gear reads", bad_keys)
	ok(edge.is_empty(), "every level and pose fits the canvas with room for the outline", edge)
	ok(sizes["1001.idle"] * 1.3 < sizes["60060.idle"], "a level 60 lifter is a lot bigger than a beginner", [sizes["1001.idle"], sizes["60060.idle"]])

	# shoulders come from lifting, thighs from riding
	var lifter = HeroFigure.metrics(input([60, 60, 1, 1, 1], "idle"))
	var rider = HeroFigure.metrics(input([60, 1, 1, 1, 60], "idle"))
	ok(int(lifter.shoulderW) > int(rider.shoulderW) and int(rider.legL.thighW) > int(lifter.legL.thighW), "lifting builds shoulders, riding builds thighs", [lifter.shoulderW, rider.shoulderW, lifter.legL.thighW, rider.legL.thighW])

	# the body (without the face, which looks one way) is a mirror image
	var m = HeroFigure.metrics(input([30, 30, 15, 15, 12], "idle"))
	var owner: PackedInt32Array = m.fig.owner
	var asym = 0
	for y in range(HeroFigure.H):
		for x in range(int(HeroFigure.W / 2.0)):
			var a = owner[y * HeroFigure.W + x] >= 0
			var b = owner[y * HeroFigure.W + HeroFigure.W - 1 - x] >= 0
			if a != b:
				asym += 1
	ok(asym == 0, "the body is symmetric", asym)

	# every visual kind of the catalog draws on the figure, idle and flexing
	var errors = []
	var base_v = {}
	for slot in Art.STARTER_LOADOUT:
		base_v[slot] = Items.by_id(Art.STARTER_LOADOUT[slot]).visual
	var plain = Pix.new(HeroFigure.W, HeroFigure.H)
	HeroBody.draw_hero(plain, input([30, 30, 15, 15, 12], "idle"), {"visuals": base_v})
	var unchanged = []
	for it in Items.all():
		for pose in ["idle", "flex", "press", "pull", "squat", "curl"]:
			var v = base_v.duplicate()
			v[it.slot] = it.visual
			var p = Pix.new(HeroFigure.W, HeroFigure.H)
			HeroBody.draw_hero(p, input([30, 30, 15, 15, 12], pose), {"visuals": v})
			if filled(p) < 400:
				errors.append(it.id)
			if pose == "idle" and p.data == plain.data and not Art.STARTER_LOADOUT.values().has(it.id):
				unchanged.append(it.id)
	ok(errors.is_empty(), "every item draws a whole hero", errors)
	ok(unchanged.is_empty(), "every item changes how the hero looks", unchanged)

	# facial hair
	var faces = []
	for f in range(HeroBody.FACIAL_HAIR.size()):
		var p = Pix.new(HeroFigure.W, HeroFigure.H)
		HeroBody.draw_hero(p, input([30, 30, 15, 15, 12], "idle", {"facialHair": f}), {"visuals": {}})
		faces.append(p.data)
	ok(faces[0] != faces[1] and faces[1] != faces[2] and faces[2] != faces[3], "stubble, a mustache and a beard each show")

	# the original look keeps its canvas and body
	Pix.classic = true
	ok(HeroBody.width() == 48 and HeroBody.height() == 60 and not HeroBody.body_metrics(input([30, 30, 15, 15, 12], "idle")).has("fig"), "the original look is untouched")
	Pix.classic = false
	print("FIGURE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
