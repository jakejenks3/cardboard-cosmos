class_name HeroFigure
extends RefCounted
## The hero in the game's own look (Pix.classic false): a person, drawn the
## way a pixel artist builds a figure (a 6-head model shrunk to about 5 heads,
## references: Slynyrd's Pixelblog 17, "Human Anatomy", and the player's own
## progress photos).
##
## The body is a set of rounded parts (capsules that taper and bulge,
## ellipses, rows) laid out on a skeleton from the player's levels, filled
## pixel by pixel. Each pixel keeps the surface normal of its part, so the
## shading is volume (lit from the top left, five warm skin tones with the
## shadows shifted towards red and the lights towards yellow), not flat
## colour; a part that overlaps another casts a one-pixel shadow on it (under
## the pecs, the deltoids, the chin), and lines of definition appear as the
## hero trains (sternum, abs, obliques, quads).
##
## What grows with what (the same as the original look):
##   hero level   overall size and bulk        lifting   shoulders, traps, chest, arms
##   climbing     forearms, grip               running   leaner waist, calves, abs
##   cycling      thighs, calves
##
## `metrics(i)` gives the same Metrics fields as HeroBody.body_metrics (so the
## gear in Equipment fits) on a W x H canvas, plus "fig" (the parts and the
## pixel maps). `draw_body(p, m)` paints the skin, `draw_face(p, m, i)` and
## `draw_hair(p, m, i, covered)` the head. HeroBody.draw_hero puts them
## together with the gear.

const W = 64
const H = 70

## Light from the top left, a little in front.
const LIGHT_X = -0.74
const LIGHT_Y = -0.46
const LIGHT_Z = 0.49

## The shorts the hero wears when nothing is on the legs.
const PLAIN_SHORTS = "#4a5068"

## Ramp steps: 0 deepest shadow .. 4 highlight.
const DEEP = 0
const SHADE = 1
const BASE = 2
const LIT = 3
const HIGH = 4


static func _clamp01(x: float) -> float:
	return maxf(0.0, minf(1.0, x))


static func _smooth(s: float) -> float:
	s = _clamp01(s)
	return s * s * (3.0 - 2.0 * s)


## Five tones of a skin colour, darkest first, the shadows leaning red and the
## lights leaning yellow (hue shifting).
static func skin_ramp(base: String) -> Array:
	return [
		Pix.mix(Pix.shade(base, 0.5), "#3c1830", 0.26),
		Pix.mix(Pix.shade(base, 0.7), "#7a2a40", 0.16),
		base,
		Pix.mix(Pix.shade(base, 1.12), "#fff0c0", 0.18),
		Pix.mix(Pix.shade(base, 1.24), "#fff8e0", 0.4),
	]


## Five tones of any material (hair, cloth), the same way but softer.
static func ramp(base: String) -> Array:
	return [
		Pix.mix(Pix.shade(base, 0.55), "#1a1030", 0.25),
		Pix.mix(Pix.shade(base, 0.76), "#2a1840", 0.12),
		base,
		Pix.mix(Pix.shade(base, 1.14), "#fff4d0", 0.08),
		Pix.mix(Pix.shade(base, 1.3), "#ffffff", 0.2),
	]


## Five tones of hair: the lights stay in the hair's own hue (dark hair turns
## warm brown in the light, not grey).
static func hair_ramp(base: String) -> Array:
	return [
		Pix.mix(Pix.shade(base, 0.55), "#120818", 0.3),
		Pix.shade(base, 0.78),
		base,
		Pix.mix(_brighter(base, 1.35), "#ffd8a8", 0.05),
		Pix.mix(_brighter(base, 1.75), "#ffe8c8", 0.12),
	]


## A colour made brighter in its own hue (Pix.shade above 1 mixes in white).
static func _brighter(hex: String, f: float) -> String:
	var c: Array = Pix.hex_to_rgb(hex)
	return Pix.rgb_to_hex(minf(255.0, c[0] * f + 6.0), minf(255.0, c[1] * f + 5.0), minf(255.0, c[2] * f + 4.0))


## The ramp step of a surface normal (nx, ny in -1..1, the rest faces the viewer).
static func tone(nx: float, ny: float) -> int:
	var l = sqrt(LIGHT_X * LIGHT_X + LIGHT_Y * LIGHT_Y + LIGHT_Z * LIGHT_Z)
	var nz = sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
	var d = (nx * LIGHT_X + ny * LIGHT_Y + nz * LIGHT_Z) / l
	if d >= 0.84:
		return HIGH
	if d >= 0.64:
		return LIT
	if d >= 0.2:
		return BASE
	if d >= -0.25:
		return SHADE
	return DEEP


# ---------------------------------------------------------------------------
# The skeleton
# ---------------------------------------------------------------------------

static func metrics(i: Dictionary) -> Dictionary:
	var b: float = _clamp01((int(i.heroLevel) - 1) / 50.0)
	var lift: float = _clamp01((int(i.liftLevel) - 1) / 35.0)
	var climb: float = _clamp01((int(i.climbLevel) - 1) / 35.0)
	var run: float = _clamp01((int(i.runLevel) - 1) / 35.0)
	var ride: float = _clamp01((int(i.rideLevel) - 1) / 35.0)
	# Mood (Recovery.mood): a workout day pumps the muscles up a little; a
	# tired hero's shoulders sag a pixel.
	var mood: String = str(i.get("mood", ""))
	if mood == "pumped":
		lift = minf(1.0, lift + 0.07)
		b = minf(1.0, b + 0.03)
	var stage: int = Xp.stage_for_level(i.heroLevel)
	var pose: String = str(i.pose)
	var frame: int = int(i.frame)
	var bob: int = 0
	if pose == "idle":
		bob = 0 if frame % 4 < 2 else 1
	else:
		bob = frame % 2
	var ax: float = W / 2.0

	# --- heights, from the floor up --------------------------------------------
	var base: int = H - 2
	var foot_h: int = 2
	# A squat (the workout replay): the hips sink, the knees go out.
	var leg_len: int = 23 + TTUtil.jsround(b * 2.0) - (6 if pose == "squat" else 0)
	var torso_len: int = 19 + TTUtil.jsround(b * 2.0)
	var ankle_y: float = base - foot_h - 0.5
	var hip_y: float = ankle_y - leg_len
	var crotch_y: int = int(hip_y) + 1
	var shoulder_y: int = crotch_y - torso_len + bob + (1 if mood == "tired" else 0)
	var neck_h: int = 3
	var head_h: int = 12
	var head_w: int = 12
	var neck_top: int = shoulder_y - neck_h
	var head_top: int = neck_top - head_h + 1 + (1 if stage == 0 else 0)
	var chin_y: int = head_top + head_h - 1

	# --- widths ---------------------------------------------------------------------
	var delt_r: float = 2.2 + lift * 1.6 + b * 0.6
	var shoulder_w: float = 19.0 + lift * 7.0 + b * 3.0
	var sh_jx: float = shoulder_w / 2.0 - delt_r
	var top_hw: float = sh_jx + 0.4
	var lat_hw: float = sh_jx - 0.6 + lift * 0.9 + b * 0.3
	var waist_hw: float = (10.0 + b * 2.0 - run * 2.0 + lift * 0.4) / 2.0
	var hip_hw: float = waist_hw + 0.3 + ride * 0.3
	var neck_hw: float = 2.2 + b * 0.7 + lift * 1.0
	var trap_h: float = 0.8 + lift * 1.4 + b * 0.4
	var armpit_y: float = shoulder_y + delt_r + 2.0
	var waist_y: float = shoulder_y + torso_len * 0.64
	var hips_y: float = crotch_y - 1.5

	# --- arms ----------------------------------------------------------------------
	var ua_len: float = 9.0 + b * 1.5
	var fa_len: float = 8.0 + b * 1.0
	var bi_r: float = 1.5 + lift * 1.6 + b * 0.6
	var el_r: float = 1.3 + lift * 0.5 + b * 0.2
	var fo_r: float = 1.4 + climb * 1.1 + lift * 0.5 + b * 0.4
	var wr_r: float = 1.1 + climb * 0.4 + b * 0.2
	var arms = []
	for side in [-1, 1]:
		var sh = Vector2(ax + side * sh_jx, shoulder_y + delt_r * 0.9 + 0.4 + (1.0 - lift) * 0.8)
		var elbow: Vector2
		var wrist: Vector2
		if pose == "flex":
			elbow = Vector2(sh.x + side * ua_len * 0.95, sh.y - 1.0)
			wrist = Vector2(elbow.x - side * 1.0, elbow.y - fa_len + 0.5)
		elif pose == "press":
			# pressing overhead (the workout replay)
			elbow = Vector2(sh.x + side * ua_len * 0.4, sh.y - ua_len * 0.78)
			wrist = Vector2(elbow.x + side * 0.5, elbow.y - fa_len * 0.82)
		elif pose == "pull":
			# hanging from a bar, hands wide
			elbow = Vector2(sh.x + side * ua_len * 0.8, sh.y - ua_len * 0.5)
			wrist = Vector2(elbow.x + side * 1.0, elbow.y - fa_len * 0.8)
		elif pose == "squat":
			# hands on the bar across the shoulders
			elbow = Vector2(sh.x + side * ua_len * 0.75, sh.y + 2.0)
			wrist = Vector2(elbow.x - side * 1.2, sh.y - 2.0)
		elif pose == "curl":
			# the top of a curl: elbows at the sides, forearms up
			var cs: float = 1.0 + lift * 1.4 + b * 0.6
			elbow = Vector2(sh.x + side * cs, sh.y + ua_len)
			wrist = Vector2(elbow.x + side * 0.6, elbow.y - fa_len * 0.8)
		else:
			# Hanging just off the lats: the arm may overlap their edge (it is in front).
			var spread: float = 1.0 + lift * 1.4 + b * 0.6
			elbow = Vector2(sh.x + side * spread, sh.y + ua_len)
			wrist = Vector2(elbow.x + side * (0.3 + lift * 0.4), elbow.y + fa_len)
		arms.append({"side": side, "sh": sh, "elbow": elbow, "wrist": wrist})

	# --- legs ----------------------------------------------------------------------
	var th_r: float = 2.4 + ride * 0.9 + b * 0.6 + run * 0.2
	var th_bulge: float = th_r + 0.3 + ride * 0.4 + lift * 0.15
	var kn_r: float = 1.7 + b * 0.2
	var ca_r: float = 1.8 + run * 0.7 + ride * 0.5 + b * 0.3
	var an_r: float = 1.1 + b * 0.15
	var hip_jx: float = hip_hw - th_r * 0.75
	var knee_y: float = hip_y + leg_len * 0.56
	# The calves never meet: a pixel of air between them however big they get.
	var low_jx: float = maxf(hip_jx - 0.3, ca_r + 0.8)
	var legs = []
	for side in [-1, 1]:
		legs.append({"side": side, "hip": Vector2(ax + side * hip_jx, hip_y), "knee": Vector2(ax + side * (low_jx + (2.5 if pose == "squat" else 0.0)), knee_y),
			"ankle": Vector2(ax + side * (low_jx - 0.3), ankle_y)})

	var g = {"b": b, "lift": lift, "climb": climb, "run": run, "ride": ride, "ax": ax, "base": base, "foot_h": foot_h,
		"shoulder_y": shoulder_y, "crotch_y": crotch_y, "hip_y": hip_y, "neck_top": neck_top, "head_top": head_top, "chin_y": chin_y,
		"delt_r": delt_r, "sh_jx": sh_jx, "top_hw": top_hw, "lat_hw": lat_hw, "waist_hw": waist_hw, "hip_hw": hip_hw,
		"neck_hw": neck_hw, "trap_h": trap_h, "armpit_y": armpit_y, "waist_y": waist_y, "hips_y": hips_y,
		"bi_r": bi_r, "el_r": el_r, "fo_r": fo_r, "wr_r": wr_r, "ua_len": ua_len, "fa_len": fa_len, "arms": arms,
		"th_r": th_r, "th_bulge": th_bulge, "kn_r": kn_r, "ca_r": ca_r, "an_r": an_r, "legs": legs, "pose": pose,
		"head_w": head_w, "head_h": head_h}
	var fig = _rasterize(g)
	return _gear_metrics(g, fig, i, stage, bob)


## The torso's half width on row y (traps above the shoulder line, lats, waist, hips).
static func torso_hw(g: Dictionary, y: float) -> float:
	var sy: float = g.shoulder_y
	if y < sy:
		# traps: from the neck out to the shoulders
		var t: float = _clamp01((y - (sy - g.trap_h)) / maxf(0.5, g.trap_h))
		return lerpf(g.neck_hw, g.top_hw - 0.6, pow(t, 0.7))
	if y < g.armpit_y:
		return lerpf(g.top_hw, g.lat_hw, _smooth((y - sy) / maxf(1.0, g.armpit_y - sy)))
	if y < g.waist_y:
		return lerpf(g.lat_hw, g.waist_hw, _smooth((y - g.armpit_y) / maxf(1.0, g.waist_y - g.armpit_y)))
	return lerpf(g.waist_hw, g.hip_hw, _smooth((y - g.waist_y) / maxf(1.0, g.hips_y - g.waist_y)))


## A capsule that tapers and bulges: radius ra at a, rm at t = tm, rb at b.
static func _cap_r(t: float, ra: float, rm: float, rb: float, tm: float) -> float:
	if t <= tm:
		return lerpf(ra, rm, _smooth(t / maxf(0.001, tm)))
	return lerpf(rm, rb, _smooth((t - tm) / maxf(0.001, 1.0 - tm)))


static func _part_cap(name: String, z: int, a: Vector2, bb: Vector2, ra: float, rm: float, rb: float, tm: float) -> Dictionary:
	return {"name": name, "z": z, "kind": "cap", "a": a, "b": bb, "ra": ra, "rm": rm, "rb": rb, "tm": tm}


static func _part_ell(name: String, z: int, c: Vector2, rx: float, ry: float) -> Dictionary:
	return {"name": name, "z": z, "kind": "ell", "c": c, "rx": rx, "ry": ry}


## The parts of the body, back to front.
static func _parts(g: Dictionary) -> Array:
	var parts = []
	var ax: float = g.ax
	# legs (behind the hips)
	for leg in g.legs:
		var s: String = "L" if leg.side < 0 else "R"
		# the calf under the thigh (the knee belongs to the thigh), the foot under the calf
		parts.append(_part_ell("foot" + s, 0, Vector2(leg.ankle.x + leg.side * 1.2, g.base - 1.3), 2.8, 1.5))
		parts.append(_part_cap("calf" + s, 0, leg.knee, leg.ankle, g.kn_r, g.ca_r, g.an_r, 0.34))
		parts.append(_part_cap("thigh" + s, 1, leg.hip, leg.knee, g.th_r, g.th_bulge, g.kn_r, 0.35))
	# the torso is rows (see torso_hw), then what sits on it
	parts.append({"name": "torso", "z": 2, "kind": "torso"})
	parts.append({"name": "neck", "z": 3, "kind": "cap", "a": Vector2(ax, g.neck_top - 1.0), "b": Vector2(ax, g.shoulder_y + 1.0), "ra": g.neck_hw - 0.3, "rm": g.neck_hw, "rb": g.neck_hw + 0.3, "tm": 0.5})
	var chest: float = g.lift * 0.8 + g.b * 0.5
	if chest > 0.12:
		# broad, flat plates under the collarbones, with a hard lower edge
		var prx: float = 2.9 + g.lift * 2.2 + g.b * 0.6
		var pry: float = 1.6 + g.lift * 0.9 + g.b * 0.3
		for side in [-1, 1]:
			var pec = _part_ell("pec" + ("L" if side < 0 else "R"), 4, Vector2(ax + side * (prx * 0.9 + 0.2), g.shoulder_y + 2.0 + pry * 0.7), prx, pry)
			pec["flat"] = 0.45
			parts.append(pec)
	# arms and their deltoids (in front of the torso)
	for arm in g.arms:
		var s: String = "L" if arm.side < 0 else "R"
		parts.append(_part_cap("upper" + s, 5, arm.sh, arm.elbow, g.delt_r * 0.8, g.bi_r, g.el_r, 0.5))
		if g.pose == "flex":
			# the biceps peak, on top of the bent arm
			var mid: Vector2 = arm.sh.lerp(arm.elbow, 0.58)
			parts.append(_part_ell("peak" + s, 6, mid + Vector2(0, -g.bi_r * 0.55), g.ua_len * 0.26 + g.lift * 0.6, g.bi_r * 0.85))
		var fore_boost: float = 0.4 if g.pose == "flex" else 0.0
		parts.append(_part_cap("fore" + s, 6, arm.elbow, arm.wrist, g.el_r + 0.2 + fore_boost, g.fo_r + fore_boost, g.wr_r + fore_boost * 0.5, 0.28))
		var hand_c: Vector2
		if g.pose == "flex":
			hand_c = arm.wrist + Vector2(0, -2.0)
			parts.append(_part_ell("hand" + s, 7, hand_c, 2.2 + g.climb * 0.5 + g.b * 0.2, 2.3))
		else:
			hand_c = arm.wrist + Vector2(arm.side * 0.2, 2.6)
			parts.append(_part_ell("hand" + s, 7, hand_c, 1.5 + g.climb * 0.4, 2.3))
		arm["hand_c"] = hand_c
		parts.append(_part_ell("delt" + s, 8 if g.lift + g.b * 0.5 > 0.25 else 5, arm.sh + Vector2(arm.side * 0.3, -0.3), g.delt_r, g.delt_r * 1.08))
	# the head: ears, then the skull and jaw (rows, see HEAD_HW)
	for side in [-1, 1]:
		parts.append(_part_ell("ear" + ("L" if side < 0 else "R"), 9, Vector2(ax + side * 6.1, g.head_top + 6.0), 0.9, 1.6))
	parts.append({"name": "head", "z": 10, "kind": "head"})
	return parts


# ---------------------------------------------------------------------------
# Filling the parts
# ---------------------------------------------------------------------------

## Every part filled in: {owner (part index per pixel, -1 none), nx, ny, parts}.
static func _rasterize(g: Dictionary) -> Dictionary:
	var parts = _parts(g)
	var owner = PackedInt32Array()
	owner.resize(W * H)
	owner.fill(-1)
	var zb = PackedInt32Array()
	zb.resize(W * H)
	zb.fill(-1000)
	var nxs = PackedFloat32Array()
	nxs.resize(W * H)
	var nys = PackedFloat32Array()
	nys.resize(W * H)
	for pi in range(parts.size()):
		var pt = parts[pi]
		match str(pt.kind):
			"cap":
				_fill_cap(pt, pi, owner, zb, nxs, nys)
			"ell":
				_fill_ell(pt, pi, owner, zb, nxs, nys)
			"torso":
				_fill_torso(g, pt, pi, owner, zb, nxs, nys)
			"head":
				_fill_head(g, pt, pi, owner, zb, nxs, nys)
	_band_limbs(owner, nxs, parts)
	return {"owner": owner, "nx": nxs, "ny": nys, "parts": parts}


## Limbs are a few pixels wide: their light comes from where a pixel sits
## across the limb on its row (lit edge, middle, shaded edge), so the bands run
## clean down the arm or leg instead of flickering as the width changes.
static func _band_limbs(owner: PackedInt32Array, nxs: PackedFloat32Array, parts: Array) -> void:
	for y in range(H):
		var x: int = 0
		while x < W:
			var pi: int = owner[y * W + x]
			if pi < 0 or str(parts[pi].kind) != "cap" or str(parts[pi].name) == "neck":
				x += 1
				continue
			var l: int = x
			while x < W and owner[y * W + x] == pi:
				x += 1
			var r: int = x - 1
			var n: int = r - l + 1
			for k in range(l, r + 1):
				nxs[y * W + k] = -0.95 if n == 1 else lerpf(-0.95, 0.95, float(k - l) / float(n - 1))


static func _put(i: int, pi: int, z: int, nx: float, ny: float, owner: PackedInt32Array, zb: PackedInt32Array, nxs: PackedFloat32Array, nys: PackedFloat32Array) -> void:
	if z >= zb[i]:
		zb[i] = z
		owner[i] = pi
		nxs[i] = nx
		nys[i] = ny


static func _fill_cap(pt: Dictionary, pi: int, owner, zb, nxs, nys) -> void:
	var a: Vector2 = pt.a
	var bb: Vector2 = pt.b
	var rmax: float = maxf(maxf(pt.ra, pt.rm), pt.rb)
	var x0: int = maxi(0, int(floor(minf(a.x, bb.x) - rmax - 1)))
	var x1: int = mini(W - 1, int(ceil(maxf(a.x, bb.x) + rmax + 1)))
	var y0: int = maxi(0, int(floor(minf(a.y, bb.y) - rmax - 1)))
	var y1: int = mini(H - 1, int(ceil(maxf(a.y, bb.y) + rmax + 1)))
	var ab: Vector2 = bb - a
	var ll: float = maxf(0.0001, ab.length_squared())
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p = Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - a).dot(ab) / ll, 0.0, 1.0)
			var q: Vector2 = a + ab * t
			var r: float = _cap_r(t, pt.ra, pt.rm, pt.rb, pt.tm)
			var v: Vector2 = p - q
			var d: float = v.length()
			if d <= r:
				var n: Vector2 = v / maxf(r, 0.5)
				_put(y * W + x, pi, pt.z, n.x * 0.92, n.y * 0.92, owner, zb, nxs, nys)


static func _fill_ell(pt: Dictionary, pi: int, owner, zb, nxs, nys) -> void:
	var c: Vector2 = pt.c
	var x0: int = maxi(0, int(floor(c.x - pt.rx - 1)))
	var x1: int = mini(W - 1, int(ceil(c.x + pt.rx + 1)))
	var y0: int = maxi(0, int(floor(c.y - pt.ry - 1)))
	var y1: int = mini(H - 1, int(ceil(c.y + pt.ry + 1)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = (x + 0.5 - c.x) / maxf(0.5, pt.rx)
			var dy: float = (y + 0.5 - c.y) / maxf(0.5, pt.ry)
			if dx * dx + dy * dy <= 1.0:
				var f: float = float(pt.get("flat", 0.9))
				_put(y * W + x, pi, pt.z, dx * f, dy * f, owner, zb, nxs, nys)


static func _fill_torso(g: Dictionary, pt: Dictionary, pi: int, owner, zb, nxs, nys) -> void:
	var top: int = int(floor(g.shoulder_y - g.trap_h))
	var bottom: int = g.crotch_y
	for y in range(maxi(0, top), mini(H, bottom + 1)):
		var yc: float = y + 0.5
		var hw: float = torso_hw(g, yc)
		var span: float = float(bottom - g.shoulder_y)
		var t: float = (yc - g.shoulder_y) / maxf(1.0, span)
		# the upper chest faces up a little, the belly forward, the bottom down
		var ny: float = -0.38 if yc < g.shoulder_y else lerpf(-0.22, 0.28, _clamp01(t))
		for x in range(maxi(0, int(floor(g.ax - hw - 1))), mini(W, int(ceil(g.ax + hw + 1)))):
			var dx: float = x + 0.5 - g.ax
			if absf(dx) <= hw:
				_put(y * W + x, pi, pt.z, dx / maxf(1.0, hw) * 0.86, ny, owner, zb, nxs, nys)
	# the crotch: the hips round off between the legs
	pass


## The head's half width on each of its 12 rows, crown to chin: a rounded
## skull, full cheeks, a jaw that narrows to the chin.
const HEAD_HW = [3.4, 4.9, 5.6, 6.0, 6.0, 6.0, 6.0, 5.8, 5.4, 4.8, 4.1, 3.1]
## How much each of those rows faces up (-) or down (+).
const HEAD_NY = [-0.72, -0.55, -0.38, -0.2, -0.08, 0.0, 0.0, 0.06, 0.2, 0.36, 0.52, 0.66]


static func _fill_head(g: Dictionary, pt: Dictionary, pi: int, owner, zb, nxs, nys) -> void:
	var top: int = g.head_top
	for r in range(HEAD_HW.size()):
		var y: int = top + r
		if y < 0 or y >= H:
			continue
		var hw: float = HEAD_HW[r]
		for x in range(int(floor(g.ax - hw - 1)), int(ceil(g.ax + hw + 1))):
			var dx: float = x + 0.5 - g.ax
			if absf(dx) <= hw and x >= 0 and x < W:
				_put(y * W + x, pi, pt.z, dx / hw * 0.8, HEAD_NY[r], owner, zb, nxs, nys)


# ---------------------------------------------------------------------------
# The face and the hair
# ---------------------------------------------------------------------------

## The skin tone in a mood: a little flushed when pumped, a little pale when tired.
static func _mood_skin(skin: String, mood: String) -> String:
	if mood == "pumped":
		return Pix.mix(skin, "#e0503c", 0.07)
	if mood == "tired":
		return Pix.mix(skin, "#b4b0b8", 0.18)
	return skin


## Eyes, brows, nose and mouth on the painted head. i: blink, happy, look,
## mood ("tired": heavy lids and a drop of sweat; "pumped": a grin).
static func draw_face(p: Pix, m: Dictionary, i: Dictionary) -> void:
	var g: Dictionary = m.g
	var ht: int = g.head_top
	var c: int = int(g.ax)
	var rp: Array = skin_ramp(str(m.skin))
	var ey: int = ht + 5
	var look: int = int(i.get("look", 0))
	var iris: String = "#2a1a22"
	var white: String = Pix.mix("#f4efe8", str(m.skin), 0.18)
	var lid: String = Pix.mix(rp[0], "#2a1a22", 0.4)
	# brows: the hair's colour on the skin, angled down to the middle once the hero is older
	var brow: String = Pix.mix(Pix.shade(str(m.hair), 0.8), rp[0], 0.35)
	var stage: int = int(m.stage)
	if stage >= 3:
		p.hline(c - 5, ey - 2, 2, brow)
		p.set_px(c - 3, ey - 1, brow)
		p.hline(c + 3, ey - 2, 2, brow)
		p.set_px(c + 2, ey - 1, brow)
	else:
		p.hline(c - 5, ey - 2, 3, brow)
		p.hline(c + 2, ey - 2, 3, brow)
	var mood: String = str(i.get("mood", ""))
	if bool(i.get("blink", false)):
		p.hline(c - 4, ey + 1, 2, lid)
		p.hline(c + 2, ey + 1, 2, lid)
	elif mood == "tired":
		# heavy lids: the lid comes down over the white, only the iris shows
		p.hline(c - 4, ey, 2, lid)
		p.hline(c + 2, ey, 2, lid)
		p.hline(c - 4, ey + 1, 2, lid)
		p.hline(c + 2, ey + 1, 2, lid)
		p.set_px(c - 3, ey + 1, iris)
		p.set_px(c + 2, ey + 1, iris)
		# a drop of sweat at the temple
		p.set_px(c + 6, ey - 1, "#bfe6ff")
		p.set_px(c + 6, ey, "#7cc4f2")
		p.set_px(c + 7, ey, "#bfe6ff")
	else:
		# each eye: a lid line, then the white and the iris
		var li: int = c - 3 + look
		var ri: int = c + 2 + look
		p.hline(c - 4, ey, 2, lid)
		p.hline(c + 2, ey, 2, lid)
		p.hline(c - 4, ey + 1, 2, white)
		p.hline(c + 2, ey + 1, 2, white)
		p.set_px(clampi(li, c - 4, c - 3), ey + 1, iris)
		p.set_px(clampi(ri, c + 2, c + 3), ey + 1, iris)
	# nose: lit on the bridge, its shadow on the right, the nostrils under
	p.set_px(c - 1, ey + 2, rp[3])
	p.set_px(c, ey + 2, rp[1])
	p.set_px(c - 1, ey + 3, rp[1])
	p.set_px(c, ey + 3, rp[0])
	# mouth
	var lip: String = Pix.mix(rp[0], "#8a2a3a", 0.25)
	var my: int = ht + 9
	var facial: int = int(i.get("facialHair", 0)) % HeroBody.FACIAL_HAIR.size()
	var grin: bool = bool(i.get("happy", false)) or mood == "pumped"
	if facial >= 2:
		_facial_hair(p, m, facial)
		# under a mustache only the lower lip shows
		p.hline(c - 1, my + 1, 2, lip)
		if grin:
			p.set_px(c - 2, my + 1, lip)
			p.set_px(c + 1, my + 1, lip)
		return
	if facial == 1:
		_facial_hair(p, m, facial)
	if grin:
		p.set_px(c - 2, my - 1, lip)
		p.set_px(c + 1, my - 1, lip)
		p.hline(c - 1, my, 2, lip)
		p.hline(c - 1, my + 1, 2, rp[3])
	else:
		p.hline(c - 1, my, 2, lip)
		p.set_px(c - 2, my, rp[1])
		p.set_px(c + 1, my, rp[1])
		p.hline(c - 1, my + 1, 2, rp[3])


## Stubble (1), a mustache (2) or a beard with a mustache (3), in the hair's
## colour: the mustache over the upper lip with its ends turned down, the
## beard along the jaw and the chin, stubble a dusting where a beard would be.
static func _facial_hair(p: Pix, m: Dictionary, kind: int) -> void:
	var g: Dictionary = m.g
	var ht: int = g.head_top
	var c: int = int(g.ax)
	var hr: Array = hair_ramp(str(m.hair))
	var sr: Array = skin_ramp(str(m.skin))
	var jaw = []
	for r in range(8, 12):
		var y: int = ht + r
		var hw: float = HEAD_HW[r]
		for x in range(int(floor(g.ax - hw)), int(ceil(g.ax + hw))):
			if absf(x + 0.5 - g.ax) > hw:
				continue
			# the cheeks above the jaw stay clear; around the mouth only below it
			if r == 8 and absf(x + 0.5 - g.ax) < hw - 1.6:
				continue
			if r == 9 and absf(x + 0.5 - g.ax) < 3.0:
				continue
			jaw.append(Vector2i(x, y))
	if kind == 1 or kind == 2:
		# stubble: every other pixel of the beard's place a little darker
		var dust: String = Pix.mix(sr[1], str(m.hair), 0.35)
		for q in jaw:
			if (q.x + q.y) % 2 == 0:
				p.set_px(q.x, q.y, dust)
	if kind == 3:
		for q in jaw:
			var t: int = BASE
			if q.x + 0.5 > g.ax + 2.0:
				t = SHADE
			elif q.x + 0.5 < g.ax - 3.0 and q.y < ht + 10:
				t = LIT
			if q.y == ht + 11:
				t = SHADE
			p.set_px(q.x, q.y, hr[t])
	if kind >= 2:
		var my: int = ht + 9
		for x in range(c - 3, c + 3):
			p.set_px(x, my, hr[LIT] if x < c - 1 else (hr[BASE] if x < c + 1 else hr[SHADE]))
		p.set_px(c - 3, my + 1, hr[SHADE])
		p.set_px(c + 2, my + 1, hr[DEEP])


## The hair's pixels for a style, as {index: true}: drawn over the head.
static func _hair_mask(g: Dictionary, style: int, covered: bool) -> Dictionary:
	var out = {}
	var ax: float = g.ax
	var ht: int = g.head_top
	var add = func(x: int, y: int):
		if x >= 0 and y >= 0 and x < W and y < H:
			out[y * W + x] = true
	var span = func(y: int, hw: float, x_off: float = 0.0):
		for x in range(int(floor(ax - hw - 1)), int(ceil(ax + hw + 1))):
			if absf(x + 0.5 - ax - x_off) <= hw:
				add.call(x, y)
	if covered:
		# under a hat only the sides show
		for y in range(ht + 2, ht + 5):
			add.call(int(ax - 6), y)
			add.call(int(ax + 5), y)
		return out
	match style:
		5:
			# buzz: a close crop on the skull
			span.call(ht, 3.4)
			span.call(ht + 1, 4.9)
			span.call(ht + 2, 5.6)
			for y in range(ht + 3, ht + 5):
				add.call(int(ax - 6), y)
				add.call(int(ax + 5), y)
			return out
		6:
			# mohawk: a strip up the middle, the sides shaved
			for y in range(ht - 4, ht + 3):
				span.call(y, 1.6 if y < ht else 2.0)
			return out
	if style == 0:
		# short: tight at the sides, the top grown out and swept up and back
		span.call(ht - 3, 3.2, -0.8)
		span.call(ht - 2, 4.8, -0.4)
		span.call(ht - 1, 5.8)
		span.call(ht, 6.3)
		span.call(ht + 1, 6.3)
		for y in range(ht + 2, ht + 5):
			add.call(int(ax - 7), y)
			add.call(int(ax + 6), y)
		add.call(int(ax - 6), ht + 2)
		add.call(int(ax + 5), ht + 2)
		# the front lifts off the forehead on one side
		for x in range(int(ax - 5), int(ax - 1)):
			add.call(x, ht + 2)
		return out
	# the cap of hair every other style starts from
	span.call(ht - 2, 3.6, -0.5)
	span.call(ht - 1, 5.2)
	span.call(ht, 6.2)
	span.call(ht + 1, 6.4)
	span.call(ht + 2, 6.4)
	for y in range(ht + 3, ht + 6):
		add.call(int(ax - 7), y)
		add.call(int(ax - 6), y)
		add.call(int(ax + 5), y)
		add.call(int(ax + 6), y)
	# a fringe swept to one side
	for x in range(int(ax - 5), int(ax + 1)):
		add.call(x, ht + 3)
	add.call(int(ax - 5), ht + 4)
	add.call(int(ax - 4), ht + 4)
	match style:
		1:
			# spiky
			for k in range(5):
				var sx: int = int(ax - 5) + k * 2 + (k % 2)
				add.call(sx, ht - 3)
				if k % 2 == 0:
					add.call(sx, ht - 4)
				add.call(sx + 1, ht - 3)
		2:
			# long: down past the jaw
			for y in range(ht + 6, ht + 14):
				add.call(int(ax - 7), y)
				add.call(int(ax - 6), y)
				add.call(int(ax + 5), y)
				add.call(int(ax + 6), y)
		3:
			# bun on top
			for y in range(ht - 5, ht - 1):
				for x in range(int(ax - 2), int(ax + 2)):
					if not ((y == ht - 5 or y == ht - 2) and (x == int(ax - 2) or x == int(ax + 1))):
						add.call(x, y)
		4:
			# curly: fuller all round, bumpy
			for x in range(int(ax - 6), int(ax + 6)):
				add.call(x, ht - 3 + (x % 2))
			for y in range(ht - 1, ht + 6):
				add.call(int(ax - 8 + (y % 2)), y)
				add.call(int(ax + 7 - (y % 2)), y)
	return out


## Paint the hair (shaded like a ball lit from the top left, darker tips).
## `covered`: a hat sits on top.
static func draw_hair(p: Pix, m: Dictionary, i: Dictionary, covered: bool) -> void:
	var g: Dictionary = m.g
	var style: int = int(i.hairStyle) % HeroBody.HAIR_STYLES.size()
	var mask: Dictionary = _hair_mask(g, style, covered)
	var rp: Array = hair_ramp(str(m.hair))
	var cy: float = g.head_top + 4.0
	for k in mask:
		var x: int = int(k) % W
		var y: int = int(int(k) / W)
		var nx: float = clampf((x + 0.5 - g.ax) / 7.5, -1.0, 1.0)
		var ny: float = clampf((y + 0.5 - cy) / 7.0, -1.0, 1.0)
		var t: int = tone(nx * 0.95, ny * 0.95)
		# the tips at the bottom of the hair fall into shade
		if not mask.has(int(k) + W) and y > g.head_top + 1:
			t = mini(t, SHADE)
		# strands: every third column a step darker in the thick of it
		if t >= BASE and (x + y) % 3 == 0 and mask.has(int(k) - W) and mask.has(int(k) + W):
			t -= 1
		if style == 5:
			p.set_px(x, y, Pix.mix(rp[clampi(t, 1, 3)], str(m.skin), 0.35))
		else:
			p.set_px(x, y, rp[clampi(t, 0, 4)])


# ---------------------------------------------------------------------------
# Cloth on the body
# ---------------------------------------------------------------------------

## The pixels of a region of the body (shorts, tights, a shirt, sleeves...),
## from the parts they cover: {index: true}. `rows` limits each part to a
## band of rows: {part name prefix: [from_y, to_y]} (inclusive).
static func region(m: Dictionary, rows: Dictionary) -> Dictionary:
	var fig: Dictionary = m.fig
	var owner: PackedInt32Array = fig.owner
	var parts: Array = fig.parts
	var out = {}
	for i in range(W * H):
		var pi: int = owner[i]
		if pi < 0:
			continue
		var name: String = parts[pi].name
		for pre in rows:
			if name.begins_with(pre):
				var y: int = int(i / W)
				var band: Array = rows[pre]
				if y >= int(band[0]) and y <= int(band[1]):
					out[i] = true
	return out


## Paint cloth over a region, shaded by the body under it (the same light),
## with a darker seam on its top and bottom edges.
static func paint_cloth(p: Pix, m: Dictionary, px: Dictionary, color: String, seams: bool = true) -> void:
	var fig: Dictionary = m.fig
	var rp: Array = ramp(color)
	for k in px:
		var i: int = int(k)
		var t: int = tone(fig.nx[i] * 0.9, fig.ny[i] * 0.9)
		if seams and (not px.has(i - W) or not px.has(i + W)):
			t = mini(t, SHADE) if not px.has(i + W) else maxi(t - 1, SHADE)
		p.set_px(i % W, int(i / W), rp[clampi(t, 0, 4)])


## The shorts region: hips and the top third of the thighs.
static func shorts_region(m: Dictionary, long: bool = false) -> Dictionary:
	var g: Dictionary = m.g
	var top: int = int(g.waist_y + 2.0)
	var leg_to: int = int(g.hip_y + (g.knee_y_len if g.has("knee_y_len") else 11.0) * (1.0 if long else 0.62))
	return region(m, {"torso": [top, g.crotch_y + 2], "thigh": [0, leg_to]})


# ---------------------------------------------------------------------------
# Painting the skin
# ---------------------------------------------------------------------------

## Paint the body's skin into p, shaded, with its definition. Returns the
## ramp-step map (PackedInt32Array, -1 where there is no skin).
static func draw_body(p: Pix, m: Dictionary) -> void:
	var fig: Dictionary = m.fig
	var g: Dictionary = m.g
	var owner: PackedInt32Array = fig.owner
	var parts: Array = fig.parts
	var steps = PackedInt32Array()
	steps.resize(W * H)
	steps.fill(-1)
	for i in range(W * H):
		var pi: int = owner[i]
		if pi < 0:
			continue
		steps[i] = tone(fig.nx[i], fig.ny[i])
	# A part over another throws a shadow down and to the right onto it.
	for y in range(H):
		for x in range(W):
			var i: int = y * W + x
			var pi: int = owner[i]
			if pi < 0:
				continue
			var z: int = parts[pi].z
			var over = false
			if y > 0 and owner[i - W] >= 0 and parts[owner[i - W]].z > z and owner[i - W] != pi and not _same_limb(parts[pi].name, parts[owner[i - W]].name):
				over = true
			elif x > 0 and owner[i - 1] >= 0 and parts[owner[i - 1]].z > z and owner[i - 1] != pi and not _same_limb(parts[pi].name, parts[owner[i - 1]].name):
				over = true
			if over:
				steps[i] = maxi(DEEP, mini(steps[i], BASE) - 1)
	_clean(steps, owner)
	_definition(steps, owner, parts, g)
	m["skinSteps"] = steps
	var ramp_c: Array = skin_ramp(str(m.skin))
	for i in range(W * H):
		if steps[i] >= 0:
			p.set_px(i % W, int(i / W), ramp_c[steps[i]])


## Parts of one limb flow into each other without a shadow line (thigh and
## calf at the knee, upper arm and forearm at the elbow).
static func _same_limb(a: String, b: String) -> bool:
	if a.right(1) != b.right(1):
		return false
	var pair = [a.left(a.length() - 1), b.left(b.length() - 1)]
	pair.sort()
	return pair == ["calf", "thigh"] or pair == ["fore", "upper"]


## A pixel artist's clean-up: a lone pixel whose neighbours on its own part
## all share another step takes theirs (noise, not form).
static func _clean(steps: PackedInt32Array, owner: PackedInt32Array) -> void:
	var src: PackedInt32Array = steps.duplicate()
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i: int = y * W + x
			var s: int = src[i]
			if s < 0:
				continue
			var counts = {}
			var same: int = 0
			for j in [i - 1, i + 1, i - W, i + W]:
				if src[j] < 0 or owner[j] != owner[i]:
					continue
				if src[j] == s:
					same += 1
				else:
					counts[src[j]] = int(counts.get(src[j], 0)) + 1
			if same > 0:
				continue
			for t in counts:
				if int(counts[t]) >= 3:
					steps[i] = int(t)


## Lines of muscle that show as the hero trains: sternum, abs, obliques,
## quads, the knees. Drawn as darker steps into the map.
static func _definition(steps: PackedInt32Array, owner: PackedInt32Array, parts: Array, g: Dictionary) -> void:
	var ax: float = g.ax
	var cl: int = int(ax) - 1
	var cr: int = int(ax)
	var torso_i: int = _part_index(parts, "torso")
	var darken = func(x: int, y: int, k: int):
		if x < 0 or y < 0 or x >= W or y >= H:
			return
		var i: int = y * W + x
		if steps[i] >= 0:
			steps[i] = maxi(DEEP, steps[i] - k)
	var lighten = func(x: int, y: int):
		if x < 0 or y < 0 or x >= W or y >= H:
			return
		var i: int = y * W + x
		if steps[i] >= 0 and steps[i] < LIT:
			steps[i] = steps[i] + 1
	# sternum between the pecs
	var chest: float = g.lift * 0.8 + g.b * 0.5
	if chest > 0.25:
		for y in range(g.shoulder_y + 2, g.shoulder_y + 5 + int(g.lift * 2.0)):
			darken.call(cr, y, 1)
	# abs: the line down the middle and the rows across, deeper the fitter
	var abs_def: float = g.run * 0.6 + g.lift * 0.35 + g.b * 0.35
	if abs_def > 0.28:
		var top: int = int(g.shoulder_y + 5.5 + g.lift * 2.0)
		var bottom: int = int(g.waist_y + 3.0)
		for y in range(top, bottom):
			darken.call(cr, y, 1)
		var rows: int = 3 if abs_def < 0.6 else 4
		for k in range(rows):
			var y: int = top + 2 + k * 3
			if y >= bottom - 1:
				break
			darken.call(cl - 2, y, 1)
			darken.call(cl - 1, y, 1)
			darken.call(cr + 1, y, 1)
			darken.call(cr + 2, y, 1)
			lighten.call(cl - 2, y + 1)
			lighten.call(cl - 1, y + 1)
		# the navel
		darken.call(cr, bottom + 1, 2)
		if abs_def > 0.55:
			# obliques: the line where the abs meet the sides
			for y in range(int(g.waist_y - 2), int(g.hips_y)):
				var hw: float = torso_hw(g, y + 0.5)
				darken.call(int(ax - hw + 1.5), y, 1)
				darken.call(int(ax + hw - 1.5), y, 1)
	# quads and knees
	for leg in g.legs:
		var kx: int = int(leg.knee.x)
		var ky: int = int(leg.knee.y)
		if g.ride + g.b > 0.5:
			# the teardrop above the knee on the inside
			var ix: int = int(leg.knee.x - leg.side * (g.kn_r + 0.2))
			darken.call(ix, ky - 2, 1)
			darken.call(ix + leg.side, ky - 3, 1)


static func _part_index(parts: Array, name: String) -> int:
	for k in range(parts.size()):
		if parts[k].name == name:
			return k
	return -1


# ---------------------------------------------------------------------------
# The fields the gear reads (HeroBody's Metrics)
# ---------------------------------------------------------------------------

static func _gear_metrics(g: Dictionary, fig: Dictionary, i: Dictionary, stage: int, bob: int) -> Dictionary:
	var ax: float = g.ax
	var cx: int = int(ax)
	# Torso rows as the gear sees them: the torso's own width on each row (the
	# same pixels _fill_torso fills, whether an arm is in front or not).
	var lefts = {}
	var widths = {}
	for y in range(int(floor(g.shoulder_y - g.trap_h)), g.crotch_y + 1):
		var hw: float = torso_hw(g, y + 0.5)
		var l: int = -1
		var r: int = -1
		for x in range(W):
			if absf(x + 0.5 - ax) <= hw:
				if l < 0:
					l = x
				r = x
		if l >= 0:
			lefts[y] = l
			widths[y] = r - l + 1
	var torso_top: int = g.shoulder_y
	var torso_bottom: int = g.crotch_y
	var fallback_l: int = int(lefts.get(torso_top, cx - 6))
	var fallback_w: int = int(widths.get(torso_top, 12))
	var torso_w_fn: Callable = func(y): return int(widths.get(int(y), fallback_w))
	var torso_left_fn: Callable = func(y): return int(lefts.get(int(y), fallback_l))
	var arm_l: Dictionary = _gear_arm(g, g.arms[0])
	var arm_r: Dictionary = _gear_arm(g, g.arms[1])
	var leg_l: Dictionary = _gear_leg(g, g.legs[0])
	var leg_r: Dictionary = _gear_leg(g, g.legs[1])
	var feet_top: int = g.base - g.foot_h
	var head_left: int = cx - int(g.head_w / 2.0)
	var neck_w: int = int(round(g.neck_hw * 2.0))
	if neck_w % 2 != 0:
		neck_w += 1
	return {
		"t": {"bulk": g.b, "lift": g.lift, "climb": g.climb, "run": g.run, "ride": g.ride},
		"stage": stage,
		"cx": cx,
		"baseline": g.base,
		"bob": bob,
		"headW": g.head_w,
		"headH": g.head_h,
		"headTop": g.head_top,
		"headLeft": head_left,
		"eyeY": g.head_top + 5,
		"neckW": neck_w,
		"neckTop": g.neck_top,
		"neckH": g.shoulder_y - g.neck_top,
		"torsoTop": torso_top,
		"torsoBottom": torso_bottom,
		"torsoH": torso_bottom - torso_top + 1,
		"shoulderW": int(round((g.sh_jx + g.delt_r) * 2.0)),
		"waistW": int(widths.get(int(g.waist_y), 10)),
		"torsoW": torso_w_fn,
		"torsoLeft": torso_left_fn,
		"armL": arm_l,
		"armR": arm_r,
		"legL": leg_l,
		"legR": leg_r,
		"legTop": int(g.hip_y),
		"legLen": int(g.base - g.foot_h - g.hip_y),
		"feetTop": feet_top,
		"footH": g.foot_h,
		"footL": {"x": int(g.legs[0].ankle.x) - 3, "w": 5},
		"footR": {"x": int(g.legs[1].ankle.x) - 1, "w": 5},
		"pose": g.pose,
		"skin": _mood_skin(HeroBody.SKIN_TONES[int(i.skin) % HeroBody.SKIN_TONES.size()], str(i.get("mood", ""))),
		"hair": HeroBody.HAIR_COLORS[int(i.hairColor) % HeroBody.HAIR_COLORS.size()],
		"g": g,
		"fig": fig,
		"figure": true,
	}


static func _gear_arm(g: Dictionary, arm: Dictionary) -> Dictionary:
	var hc: Vector2 = arm.get("hand_c", arm.wrist)
	var hw: int = maxi(3, int(round((1.6 + g.climb * 0.4) * 2.0)))
	var hand = {"x": int(hc.x) - int(hw / 2.0), "y": int(hc.y) - 2, "w": hw, "h": 4}
	return {"shoulder": {"x": int(arm.sh.x), "y": int(arm.sh.y)}, "elbow": {"x": int(arm.elbow.x), "y": int(arm.elbow.y)},
		"wrist": {"x": int(arm.wrist.x), "y": int(arm.wrist.y)}, "upperW": maxi(3, int(round(g.bi_r * 2.0))),
		"foreW": maxi(3, int(round(g.fo_r * 2.0))), "hand": hand, "side": arm.side}


static func _gear_leg(g: Dictionary, leg: Dictionary) -> Dictionary:
	var tw: int = int(round(g.th_bulge * 2.0))
	var cw: int = int(round(g.ca_r * 2.0))
	var x: int = int(round(leg.hip.x - tw / 2.0))
	var calf_x: int = int(round(leg.knee.x - cw / 2.0))
	return {"x": x, "thighW": tw, "calfX": calf_x, "calfW": cw, "top": int(leg.hip.y), "kneeY": int(leg.knee.y), "side": leg.side}
