extends SceneTree
## Unit test for the game's own hero (avatar/hero_figure.gd, avatar/figure_gear.gd):
## it fits its canvas at every level and pose, the body is symmetric, it grows
## with the levels, every piece of gear draws on it, facial hair shows, and the
## original look (Pix.classic) keeps its own canvas. The Realm's battle poses
## (strike, kick, guard, cast, hurt) each draw a picture of their own, keep the
## feet on the floor and the hands on the canvas whatever is worn on them, and
## leave the original look alone.
##   godot --headless --path . --script res://tests/figure_test.gd
## Prints FIGURE: X/Y passed and exits with 1 when anything fails.

var passed = 0
var total = 0

## The poses the game had before the Realm, and the ones its battles add.
const OLD_POSES = ["idle", "flex", "press", "pull", "squat", "curl"]
const REALM_POSES = ["strike", "kick", "guard", "cast", "hurt"]
const POSES = OLD_POSES + REALM_POSES


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


## The Realm's battle poses (HeroFigure.REALM_POSES), in the game's own look.
func _realm_poses(levels: Array) -> void:
	ok(HeroFigure.REALM_POSES == REALM_POSES, "the figure names the Realm's five poses", HeroFigure.REALM_POSES)
	var unknown = []
	for school in RpgDefs.SCHOOL_POSE:
		if not POSES.has(RpgDefs.SCHOOL_POSE[school]):
			unknown.append("%s: %s" % [school, RpgDefs.SCHOOL_POSE[school]])
	ok(unknown.is_empty(), "every pose a school's moves ask for is one the figure draws", unknown)

	# each is a picture of its own, whether the hero is small or big
	var mid = [30, 30, 15, 15, 12]
	var same = []
	for lv in [[1, 1, 1, 1, 1], mid, [60, 60, 40, 40, 40]]:
		var seen = {}
		for pose in POSES:
			var p = Pix.new(HeroFigure.W, HeroFigure.H)
			HeroBody.draw_hero(p, input(lv, pose), {"visuals": {}})
			# a pose that only nudged a few pixels would not read: ask for a real change
			for other in seen:
				var moved = 0
				for k in range(p.data.size()):
					if (p.data[k] != 0) != (seen[other][k] != 0):
						moved += 1
				if moved < 60 and (REALM_POSES.has(pose) or REALM_POSES.has(other)):
					same.append("%s %s ~ %s (%d)" % [str(lv), pose, other, moved])
			seen[pose] = p.data
	ok(same.is_empty(), "every Realm pose has a silhouette of its own", same)

	# the skeleton: wrists near the shoulders, both feet on the floor, only arms and legs move
	var far = []
	var feet = []
	var moved_head = []
	var fields = []
	for lv in levels:
		var idle = HeroFigure.metrics(input(lv, "idle"))
		for pose in REALM_POSES:
			var m = HeroFigure.metrics(input(lv, pose))
			var g: Dictionary = m.g
			for arm in g.arms:
				var reach: float = (arm.wrist - arm.sh).length()
				if reach > 16.0:
					far.append("%s %s %s" % [str(lv), pose, TTUtil.num_str(snappedf(reach, 0.1))])
			for k in range(2):
				if absf(float(g.legs[k].ankle.y) - float(idle.g.legs[k].ankle.y)) > 0.001:
					feet.append("%s %s" % [str(lv), pose])
			if int(m.baseline) != int(idle.baseline) or int(m.feetTop) != int(idle.feetTop) or int(m.cx) != int(idle.cx):
				feet.append("%s %s baseline" % [str(lv), pose])
			# the head and the torso keep their shape; they only ride lower when the hips sink
			var drop: int = int(m.torsoTop) - int(idle.torsoTop)
			if drop < 0 or drop > 6 or int(m.headTop) - int(idle.headTop) != drop or int(m.torsoH) != int(idle.torsoH) or int(m.shoulderW) != int(idle.shoulderW):
				moved_head.append("%s %s" % [str(lv), pose])
			# what the gear asks: are the hands up?
			var hands_up: bool = HeroFigure.HANDS_UP.has(pose)
			if str(m.act) != pose or str(g.act) != pose or str(m.pose) != ("flex" if hands_up else pose) or str(g.pose) != str(m.pose):
				fields.append("%s %s" % [str(lv), pose])
			for arm in g.arms:
				var up: bool = float(arm.hand_c.y) < float(arm.wrist.y)
				if up != hands_up and absf(float(arm.hand_c.y) - float(arm.wrist.y)) > 0.8:
					fields.append("%s %s hand %d" % [str(lv), pose, int(arm.side)])
	ok(far.is_empty(), "a wrist is never more than 16 px from its shoulder", far)
	ok(feet.is_empty(), "both feet stay on the floor line", feet)
	ok(moved_head.is_empty(), "only the arms and the legs move", moved_head)
	ok(fields.is_empty(), "the gear is told whether the hands are up (pose) and the pose asked for is kept (act)", fields)
	var old_fields = []
	for pose in OLD_POSES:
		var m = HeroFigure.metrics(input(mid, pose))
		if str(m.pose) != pose or str(m.act) != pose or m.g.arms[0].has("hand") or m.g.arms[1].has("hand"):
			old_fields.append(pose)
	ok(old_fields.is_empty(), "the older poses keep their own name and hands", old_fields)

	# whatever is on the hands (boxing gloves are a size bigger), nothing leaves the canvas
	var hand_items = Items.all().filter(func(it): return str(it.slot) == "hands")
	var clipped = []
	var bare_hands = []
	for it in hand_items:
		for lv in levels:
			for pose in REALM_POSES:
				var p = Pix.new(HeroFigure.W, HeroFigure.H)
				HeroBody.draw_hero(p, input(lv, pose), {"visuals": {"hands": it.visual}})
				var touches = false
				for x in range(HeroFigure.W):
					if p.data[x] != 0 or p.data[(HeroFigure.H - 1) * HeroFigure.W + x] != 0:
						touches = true
				for y in range(HeroFigure.H):
					if p.data[y * HeroFigure.W] != 0 or p.data[y * HeroFigure.W + HeroFigure.W - 1] != 0:
						touches = true
				if touches:
					clipped.append("%s %s %s" % [it.id, str(lv), pose])
				if lv == mid:
					var plain = Pix.new(HeroFigure.W, HeroFigure.H)
					HeroBody.draw_hero(plain, input(lv, pose), {"visuals": {}})
					if plain.data == p.data:
						bare_hands.append("%s %s" % [it.id, pose])
	ok(hand_items.size() >= 4 and clipped.is_empty(), "gloves and wraps stay on the canvas in every Realm pose", clipped.slice(0, 8))
	ok(bare_hands.is_empty(), "everything worn on the hands shows in every Realm pose", bare_hands)

	# a hit shows on the face, and only there
	var calm = Pix.new(HeroFigure.W, HeroFigure.H)
	var wince = Pix.new(HeroFigure.W, HeroFigure.H)
	var m_hurt = HeroFigure.metrics(input(mid, "hurt"))
	HeroFigure.draw_body(calm, m_hurt)
	HeroFigure.draw_body(wince, m_hurt)
	HeroFigure.draw_face(calm, m_hurt, input(mid, "idle"))
	HeroFigure.draw_face(wince, m_hurt, input(mid, "hurt"))
	var face_px = 0
	var off_face = 0
	for k in range(calm.data.size()):
		if calm.data[k] != wince.data[k]:
			face_px += 1
			var y: int = int(k / float(HeroFigure.W))
			if y < int(m_hurt.headTop) or y >= int(m_hurt.headTop) + int(m_hurt.headH):
				off_face += 1
	ok(face_px >= 6 and off_face == 0, "a hurt hero winces", [face_px, off_face])


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
		for pose in POSES:
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

	# every visual kind of the catalog draws on the figure, in every pose
	var errors = []
	var base_v = {}
	for slot in Art.STARTER_LOADOUT:
		base_v[slot] = Items.by_id(Art.STARTER_LOADOUT[slot]).visual
	var plain = Pix.new(HeroFigure.W, HeroFigure.H)
	HeroBody.draw_hero(plain, input([30, 30, 15, 15, 12], "idle"), {"visuals": base_v})
	var unchanged = []
	for it in Items.all():
		for pose in POSES:
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

	_realm_poses(levels)

	# the original look keeps its canvas and body
	Pix.classic = true
	ok(HeroBody.width() == 48 and HeroBody.height() == 60 and not HeroBody.body_metrics(input([30, 30, 15, 15, 12], "idle")).has("fig"), "the original look is untouched")
	# ... and knows none of the Realm's poses: each is drawn as the idle hero
	var classic_idle = Pix.new(HeroBody.width(), HeroBody.height())
	HeroBody.draw_hero(classic_idle, input([30, 30, 15, 15, 12], "idle"), {"visuals": base_v})
	var classic_moved = []
	for pose in REALM_POSES:
		var p = Pix.new(HeroBody.width(), HeroBody.height())
		HeroBody.draw_hero(p, input([30, 30, 15, 15, 12], pose), {"visuals": base_v})
		if p.data != classic_idle.data:
			classic_moved.append(pose)
	ok(classic_moved.is_empty(), "the original look draws the Realm's poses as idle", classic_moved)
	Pix.classic = false
	print("FIGURE: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)
