class_name FigureGear
extends RefCounted
## Clothes on the game's own hero (HeroFigure): a garment is the pixels of the
## body parts it covers, painted in its colour and shaded by the body under it
## (the same light as the skin), so a shirt follows the chest and the
## shoulders and shorts follow the thighs. The same visuals as Equipment (the
## item catalog's `visual` dictionaries); kinds this file does not know are
## drawn by Equipment on the figure's metrics.
##
##   leg_garment(p, v, m)    shorts, tights, harness, kilt
##   body_garment(p, v, m)   shirt (and its patterns), tank, singlet, armor, gi
##   hands(p, v, m)          chalk, wraps, gloves, boxing
##   feet(p, v, m, frame)    shoes, climbshoes, sandals, boots (null: bare feet, already drawn)
## Each returns true when it drew the kind.

const W = HeroFigure.W
const H = HeroFigure.H


# ---------------------------------------------------------------------------
# Regions
# ---------------------------------------------------------------------------

## Pixels of the parts whose name starts with one of `prefixes`, within rows.
static func _parts_px(m: Dictionary, prefixes: Array, y0: int = 0, y1: int = 9999) -> Dictionary:
	var rows = {}
	for pre in prefixes:
		rows[pre] = [y0, y1]
	return HeroFigure.region(m, rows)


## How far along its arm (0 shoulder .. 1 elbow, then past it on the forearm)
## a pixel of an arm part is.
static func _arm_t(m: Dictionary, i: int, side: int) -> float:
	var arm = m.g.arms[0 if side < 0 else 1]
	var p = Vector2(i % W + 0.5, int(i / W) + 0.5)
	var ab: Vector2 = arm.elbow - arm.sh
	var t: float = (p - arm.sh).dot(ab) / maxf(0.001, ab.length_squared())
	if t <= 1.0:
		return t
	var fb: Vector2 = arm.wrist - arm.elbow
	return 1.0 + (p - arm.elbow).dot(fb) / maxf(0.001, fb.length_squared())


## A shirt: torso (down to `bottom`), chest, shoulders, and the arms up to
## `sleeve` (0.45: a short sleeve; 1.6: to the middle of the forearm). `neck`:
## "crew" | "v" | "open" (how much of the chest shows at the neck).
static func shirt_px(m: Dictionary, sleeve: float, bottom: int, neck: String = "crew") -> Dictionary:
	var g: Dictionary = m.g
	var fig: Dictionary = m.fig
	var owner: PackedInt32Array = fig.owner
	var parts: Array = fig.parts
	var out = {}
	for i in range(W * H):
		var pi: int = owner[i]
		if pi < 0:
			continue
		var name: String = parts[pi].name
		var y: int = int(i / W)
		var x: int = i % W
		var keep = false
		if name == "torso" or name.begins_with("pec"):
			keep = y <= bottom
		elif name.begins_with("delt"):
			keep = sleeve > 0.0
		elif name.begins_with("upper") or name.begins_with("peak") or name.begins_with("fore"):
			var side: int = -1 if name.ends_with("L") else 1
			keep = _arm_t(m, i, side) <= sleeve
		if not keep:
			continue
		# the opening at the neck
		var dx: float = absf(x + 0.5 - g.ax)
		if neck == "crew" and y < g.shoulder_y + 1 and dx < g.neck_hw + 0.6:
			continue
		if neck == "v" and y < g.shoulder_y + 4 and dx < g.neck_hw + 0.6 - (y - g.shoulder_y) * 0.7:
			continue
		if neck == "open" and y < g.shoulder_y + 6 and dx < 2.6 - (y - g.shoulder_y) * 0.35:
			continue
		out[i] = true
	return out


## The outermost pixel of a region on each row, on one side: {y: x}.
static func _edge(px: Dictionary, side: int) -> Dictionary:
	var out = {}
	for k in px:
		var x: int = int(k) % W
		var y: int = int(int(k) / W)
		if not out.has(y) or (side < 0 and x < out[y]) or (side > 0 and x > out[y]):
			out[y] = x
	return out


static func _paint(p: Pix, m: Dictionary, px: Dictionary, color: String, seams: bool = true) -> void:
	HeroFigure.paint_cloth(p, m, px, color, seams)


## Recolour some pixels with a colour, keeping the light of what is under them.
static func _tint(p: Pix, m: Dictionary, idx: Array, color: String) -> void:
	var rp: Array = HeroFigure.ramp(color)
	var fig: Dictionary = m.fig
	for i in idx:
		if i < 0 or i >= W * H:
			continue
		var t: int = HeroFigure.tone(fig.nx[i] * 0.9, fig.ny[i] * 0.9) if fig.owner[i] >= 0 else HeroFigure.BASE
		p.set_px(i % W, int(i / W), rp[clampi(t, 1, 4)])


# ---------------------------------------------------------------------------
# Legs
# ---------------------------------------------------------------------------

static func leg_garment(p: Pix, v: Dictionary, m: Dictionary) -> bool:
	var g: Dictionary = m.g
	match str(v.kind):
		"shorts":
			var px: Dictionary = HeroFigure.shorts_region(m)
			_paint(p, m, px, str(v.color))
			var accent = v.get("accent")
			if accent != null:
				for side in [-1, 1]:
					var e: Dictionary = _edge(px, side)
					var stripe = []
					for y in e:
						if y > int(g.hip_y) - 1:
							stripe.append(int(y) * W + int(e[y]) - side)
					_tint(p, m, stripe, str(accent))
			var knee = v.get("knee")
			if knee != null:
				var pads: Dictionary = _parts_px(m, ["thigh", "calf"], int(g.legs[0].knee.y) - 1, int(g.legs[0].knee.y) + 2)
				_paint(p, m, pads, str(knee))
			return true
		"tights":
			var px: Dictionary = HeroFigure.region(m, {"torso": [int(g.waist_y + 2.0), g.crotch_y + 2], "thigh": [0, H], "calf": [0, int(g.legs[0].ankle.y) - 1]})
			_paint(p, m, px, str(v.color))
			var accent = v.get("accent")
			if accent != null and str(accent) != str(v.color):
				for side in [-1, 1]:
					var e: Dictionary = _edge(px, side)
					var stripe = []
					for y in e:
						if y > int(g.hip_y) and y < int(g.legs[0].knee.y):
							stripe.append(int(y) * W + int(e[y]) - side)
					_tint(p, m, stripe, str(accent))
			return true
		"harness":
			leg_garment(p, {"kind": "shorts", "color": v.shorts}, m)
			var px: Dictionary = HeroFigure.shorts_region(m)
			var belt = []
			var top: int = 9999
			for k in px:
				top = mini(top, int(int(k) / W))
			for k in px:
				var y: int = int(int(k) / W)
				if y == top or y == int(g.hip_y) + 4:
					belt.append(int(k))
			_tint(p, m, belt, str(v.color))
			_tint(p, m, [(top + 1) * W + int(g.ax) - 1, (top + 1) * W + int(g.ax)], Pix.shade(str(v.color), 1.3))
			return true
		"kilt":
			var line = v.get("accent")
			if line == null:
				line = Pix.shade(str(v.color), 1.4)
			var top: int = int(g.waist_y + 2.0)
			var bottom: int = int(g.legs[0].knee.y) - 1
			var rp: Array = HeroFigure.ramp(str(v.color))
			var lx: int = 9999
			var rx: int = -1
			for k in _parts_px(m, ["thigh", "torso"], top, bottom):
				lx = mini(lx, int(k) % W)
				rx = maxi(rx, int(k) % W)
			for y in range(top, bottom + 1):
				var flare: int = mini(2, int((y - top) / 3.0))
				for x in range(lx - flare, rx + flare + 1):
					var t: float = float(x - lx + flare) / maxf(1.0, rx - lx + flare * 2)
					var step: int = HeroFigure.LIT if t < 0.3 else (HeroFigure.BASE if t < 0.75 else HeroFigure.SHADE)
					if y == bottom:
						step = HeroFigure.SHADE
					var c: String = rp[step]
					if (x - lx) % 3 == 0 and y > top:
						c = Pix.mix(c, str(line), 0.7)
					if y == top + int((bottom - top) / 2.0) + 1:
						c = Pix.mix(c, Pix.shade(str(line), 0.8), 0.7)
					p.set_px(x, y, c)
			for x in range(lx, rx + 1):
				p.set_px(x, top, rp[HeroFigure.DEEP])
			return true
	return false


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

static func body_garment(p: Pix, v: Dictionary, m: Dictionary) -> bool:
	var g: Dictionary = m.g
	var color: String = str(v.color)
	var hem: int = g.crotch_y - 1
	match str(v.kind):
		"shirt":
			var px: Dictionary = shirt_px(m, 0.5, hem, "crew")
			_paint(p, m, px, color)
			var acc = v.get("accent")
			if acc == null:
				acc = Pix.shade(color, 1.3)
			_pattern(p, m, px, str(v.get("pattern", "")), str(acc), color)
			return true
		"tank", "singlet":
			# open at the shoulders and under the arms; two straps over the traps
			var px: Dictionary = shirt_px(m, 0.0, hem, "v")
			var cut = []
			for k in px:
				var x: int = int(k) % W
				var y: int = int(int(k) / W)
				var dx: float = absf(x + 0.5 - g.ax)
				var strap_lo: float = g.neck_hw + 0.6
				var strap_hi: float = g.neck_hw + 2.6
				if y < g.shoulder_y + 2 and (dx < strap_lo or dx > strap_hi):
					cut.append(k)
				elif y < g.armpit_y + 1.0 and dx > HeroFigure.torso_hw(g, y + 0.5) - 2.2:
					cut.append(k)
			for k in cut:
				px.erase(k)
			_paint(p, m, px, color)
			var accent = v.get("accent")
			if accent != null:
				var y: int = int(g.shoulder_y + 6.0)
				if str(v.kind) == "singlet":
					var stripe = []
					for yy in range(int(g.shoulder_y + 4.0), int(g.waist_y)):
						stripe.append(yy * W + int(g.ax) - 1)
						stripe.append(yy * W + int(g.ax))
					_tint(p, m, stripe, str(accent))
				else:
					var band = []
					for k in px:
						if int(int(k) / W) == y and absf(int(k) % W + 0.5 - g.ax) < 3.0:
							band.append(int(k))
					_tint(p, m, band, str(accent))
			return true
		"armor":
			var trim = v.get("accent")
			if trim == null:
				trim = "#ffd54f"
			var px: Dictionary = shirt_px(m, 0.42, hem, "crew")
			var metal: String = color
			var rp: Array = HeroFigure.ramp(metal)
			var fig: Dictionary = m.fig
			for k in px:
				var i: int = int(k)
				# metal: harder light than cloth
				var t: int = HeroFigure.tone(fig.nx[i], fig.ny[i])
				if t == HeroFigure.LIT and (i % W + int(i / W)) % 4 == 0:
					t = HeroFigure.HIGH
				p.set_px(i % W, int(i / W), rp[t])
			var lines = []
			for k in px:
				var y: int = int(int(k) / W)
				var x: int = int(k) % W
				if fig.parts[fig.owner[int(k)]].name == "torso" and y > g.shoulder_y + 4 and (y - g.shoulder_y) % 4 == 0:
					lines.append(int(k))
				if fig.parts[fig.owner[int(k)]].name == "torso" and x == int(g.ax) and y > g.shoulder_y:
					lines.append(int(k))
			_tint(p, m, lines, Pix.shade(metal, 0.6))
			# trim: the pauldrons' rims and the bottom edge
			var trim_px = []
			for k in px:
				var name: String = fig.parts[fig.owner[int(k)]].name
				if (name.begins_with("delt") and not px.has(int(k) + W)) or int(int(k) / W) == hem:
					trim_px.append(int(k))
				elif name.begins_with("delt") and fig.owner[int(k) + W] >= 0 and not fig.parts[fig.owner[int(k) + W]].name.begins_with("delt"):
					trim_px.append(int(k))
			_tint(p, m, trim_px, str(trim))
			return true
		"gi":
			var belt = v.get("accent")
			if belt == null:
				belt = "#212121"
			var px: Dictionary = shirt_px(m, 1.45, hem, "open")
			_paint(p, m, px, color)
			# lapels along the opening, and the belt
			var fold = []
			for y in range(g.shoulder_y, g.shoulder_y + 7):
				var half: float = 2.6 - (y - g.shoulder_y) * 0.35
				for side in [-1, 1]:
					var x: int = int(floor(g.ax + side * (half + 0.6))) if side > 0 else int(floor(g.ax - half - 0.6))
					fold.append(y * W + x)
			_tint(p, m, fold, Pix.shade(color, 0.8))
			var by: int = int(g.waist_y + 1.0)
			var bpx = []
			for k in px:
				var y: int = int(int(k) / W)
				if y == by or y == by + 1:
					bpx.append(int(k))
			_tint(p, m, bpx, str(belt))
			_tint(p, m, [(by + 2) * W + int(g.ax) - 2, (by + 2) * W + int(g.ax) + 1, (by + 3) * W + int(g.ax) - 2, (by + 3) * W + int(g.ax) + 1], str(belt))
			return true
	return false


## The prints of a shirt, on the shirt's own pixels.
static func _pattern(p: Pix, m: Dictionary, px: Dictionary, pattern: String, acc: String, color: String) -> void:
	var g: Dictionary = m.g
	var fig: Dictionary = m.fig
	var on_torso = func(k):
		var n: String = fig.parts[fig.owner[int(k)]].name
		return n == "torso" or n.begins_with("pec")
	match pattern:
		"stripe":
			var band = []
			for k in px:
				var y: int = int(int(k) / W)
				if on_torso.call(k) and (y == g.shoulder_y + 5 or y == g.shoulder_y + 8):
					band.append(int(k))
			_tint(p, m, band, acc)
		"polka":
			var dots = []
			for k in px:
				var x: int = int(k) % W
				var y: int = int(int(k) / W)
				if on_torso.call(k) and y > g.shoulder_y + 1 and (y - g.shoulder_y) % 3 == 0 and (x + int((y - g.shoulder_y) / 3.0) * 2) % 4 == 0:
					dots.append(int(k))
			_tint(p, m, dots, acc)
		"reflective":
			var band = []
			for k in px:
				var y: int = int(int(k) / W)
				if on_torso.call(k) and y > g.shoulder_y + 1 and (y - g.shoulder_y) % 5 == 2:
					band.append(int(k))
			_tint(p, m, band, acc)
		"hood":
			# a hood bunched at the back of the neck, the strings, a pocket
			var hood = []
			for y in range(g.shoulder_y - 1, g.shoulder_y + 2):
				for x in range(int(g.ax - g.neck_hw - 2), int(g.ax + g.neck_hw + 2)):
					if absf(x + 0.5 - g.ax) > g.neck_hw - 0.5:
						hood.append(y * W + x)
			_tint(p, m, hood, acc)
			_tint(p, m, [(g.shoulder_y + 2) * W + int(g.ax) - 2, (g.shoulder_y + 3) * W + int(g.ax) - 2, (g.shoulder_y + 2) * W + int(g.ax) + 1, (g.shoulder_y + 3) * W + int(g.ax) + 1], Pix.shade(acc, 1.5))
			var pocket = []
			for x in range(int(g.ax) - 3, int(g.ax) + 3):
				pocket.append(int(g.crotch_y - 4) * W + x)
			_tint(p, m, pocket, Pix.shade(color, 0.8))
		"flower":
			var dots = []
			var dots2 = []
			for k in px:
				var x: int = int(k) % W
				var y: int = int(int(k) / W)
				if on_torso.call(k) and y > g.shoulder_y + 1 and (y - g.shoulder_y) % 3 == 1 and (x + (y % 2) * 2) % 4 == 0:
					dots.append(int(k))
					dots2.append(int(k) + 1)
			_tint(p, m, dots, acc)
			_tint(p, m, dots2, "#ffffff")
		"tux":
			var bib = []
			for k in px:
				var x: int = int(k) % W
				var y: int = int(int(k) / W)
				var half: float = 2.5 if y < g.shoulder_y + 3 else 1.5
				if on_torso.call(k) and absf(x + 0.5 - g.ax) < half:
					bib.append(int(k))
			_tint(p, m, bib, acc)
			var c: int = int(g.ax)
			_tint(p, m, [(g.shoulder_y + 4) * W + c, (g.shoulder_y + 7) * W + c], "#212121")
			_tint(p, m, [g.shoulder_y * W + c - 2, g.shoulder_y * W + c + 1], "#d32f2f")
			_tint(p, m, [g.shoulder_y * W + c - 1, g.shoulder_y * W + c], "#b71c1c")


# ---------------------------------------------------------------------------
# Back items that show from the front
# ---------------------------------------------------------------------------

## Behind the body: the top of a pack above the shoulders. True when drawn.
static func back_behind(p: Pix, v: Dictionary, m: Dictionary) -> bool:
	var g: Dictionary = m.g
	if str(v.kind) != "backpack":
		return false
	var rp: Array = HeroFigure.ramp(str(v.color))
	var top: int = int(g.shoulder_y - g.trap_h) - 3
	var half: float = g.top_hw - 1.0
	for y in range(top, g.shoulder_y + 10):
		for x in range(int(g.ax - half), int(g.ax + half)):
			var t: int = HeroFigure.LIT if x < g.ax - half + 2 else (HeroFigure.SHADE if x > g.ax + half - 3 else HeroFigure.BASE)
			if y == top:
				t = HeroFigure.LIT
			p.set_px(x, y, rp[t])
	return true


## In front of the body: a pack's shoulder straps (and its chest strap), a
## saddlebag on the hip. True when drawn.
static func back_front(p: Pix, v: Dictionary, m: Dictionary) -> bool:
	var g: Dictionary = m.g
	match str(v.kind):
		"backpack":
			var straps = []
			for y in range(int(g.shoulder_y - g.trap_h), int(g.armpit_y + 4.0)):
				for side in [-1, 1]:
					var x0: int = int(floor(g.ax + side * (g.top_hw - 3.5)))
					for x in [x0, x0 + 1]:
						if m.fig.owner[y * W + x] >= 0:
							straps.append(y * W + x)
			_tint(p, m, straps, str(v.color))
			var accent = v.get("accent")
			if accent != null:
				var y: int = int(g.shoulder_y + 5.0)
				var band = []
				for x in range(int(floor(g.ax - g.top_hw + 3.5)), int(ceil(g.ax + g.top_hw - 3.5))):
					band.append(y * W + x)
				_tint(p, m, band, str(accent))
			return true
		"saddlebag":
			var rp: Array = HeroFigure.ramp(str(v.color))
			var x0: int = int(g.ax + g.hip_hw - 1.0)
			var y0: int = g.crotch_y - 4
			for y in range(y0, y0 + 5):
				for x in range(x0, x0 + 4):
					if (y == y0 or y == y0 + 4) and (x == x0 or x == x0 + 3):
						continue
					p.set_px(x, y, rp[HeroFigure.LIT if x == x0 else (HeroFigure.SHADE if x == x0 + 3 or y == y0 + 4 else HeroFigure.BASE)])
			p.hline(x0, y0 + 1, 4, rp[HeroFigure.DEEP])
			return true
	return false


# ---------------------------------------------------------------------------
# Hands and feet
# ---------------------------------------------------------------------------

static func hands(p: Pix, v: Dictionary, m: Dictionary) -> bool:
	var g: Dictionary = m.g
	var fig: Dictionary = m.fig
	match str(v.kind):
		"chalk":
			var px: Dictionary = _parts_px(m, ["hand"])
			HeroFigure.paint_cloth(p, m, px, Pix.mix(str(m.skin), "#ffffff", 0.7), false)
			return true
		"wraps":
			var long: bool = bool(v.get("long", false))
			var px = {}
			for i in range(W * H):
				var pi: int = fig.owner[i]
				if pi < 0:
					continue
				var name: String = fig.parts[pi].name
				if name.begins_with("fore"):
					var side: int = -1 if name.ends_with("L") else 1
					var t: float = _arm_t(m, i, side)
					if t >= (1.15 if long else 1.68):
						px[i] = true
			_paint(p, m, px, str(v.color))
			# a band over the knuckles
			var hand: Dictionary = _parts_px(m, ["hand"])
			var knuckles = []
			for k in hand:
				var y: int = int(int(k) / W)
				var far: bool = (g.pose == "flex" and not hand.has(int(k) - W)) or (g.pose != "flex" and not hand.has(int(k) + W))
				if far or (g.pose != "flex" and not hand.has(int(k) + 2 * W)):
					knuckles.append(int(k))
			_tint(p, m, knuckles, str(v.color))
			return true
		"gloves":
			var px: Dictionary = _parts_px(m, ["hand"])
			if bool(v.get("fingerless", false)):
				var keep_skin = []
				for k in px:
					if (g.pose == "flex" and not px.has(int(k) - W)) or (g.pose != "flex" and not px.has(int(k) + W)):
						keep_skin.append(k)
				for k in keep_skin:
					px.erase(k)
			_paint(p, m, px, str(v.color), false)
			return true
		"boxing":
			# padded gloves a size bigger than the hand, with a cuff
			var cuff = v.get("accent")
			if cuff == null:
				cuff = "#ffffff"
			var rp: Array = HeroFigure.ramp(str(v.color))
			for arm in g.arms:
				var c: Vector2 = arm.hand_c
				var rx: float = 2.9
				var ry: float = 3.0
				for y in range(int(c.y - ry - 1), int(c.y + ry + 1)):
					for x in range(int(c.x - rx - 1), int(c.x + rx + 1)):
						var dx: float = (x + 0.5 - c.x) / rx
						var dy: float = (y + 0.5 - c.y) / ry
						if dx * dx + dy * dy <= 1.0:
							p.set_px(x, y, rp[HeroFigure.tone(dx * 0.85, dy * 0.85)])
				# the cuff is on the wrist side: above a hanging hand, under a raised fist
				var cy: int = int(c.y - ry) if g.pose != "flex" else int(c.y + ry) - 1
				for x in range(int(c.x - 1.5), int(c.x + 1.5)):
					p.set_px(x, cy, str(cuff))
			return true
	return false


static func feet(p: Pix, v, m: Dictionary, frame: int) -> bool:
	if v == null:
		return true
	var g: Dictionary = m.g
	var fig: Dictionary = m.fig
	var feet_px: Dictionary = _parts_px(m, ["foot"])
	match str(v.kind):
		"shoes":
			_paint(p, m, feet_px, str(v.color), false)
			var sole = v.get("sole")
			if sole == null:
				sole = Pix.shade(str(v.color), 0.6)
			var bottom = []
			var stripe = []
			for k in feet_px:
				if not feet_px.has(int(k) + W):
					bottom.append(int(k))
				elif not feet_px.has(int(k) - W) and v.get("accent") != null:
					stripe.append(int(k))
			_tint(p, m, bottom, str(sole))
			if v.get("accent") != null:
				_tint(p, m, stripe, str(v.accent))
			return true
		"climbshoes":
			_paint(p, m, feet_px, str(v.color), false)
			var bottom = []
			for k in feet_px:
				if not feet_px.has(int(k) + W):
					bottom.append(int(k))
			_tint(p, m, bottom, "#222222")
			# pointed toes, turned in
			for leg in g.legs:
				var tip: int = int(leg.ankle.x + leg.side * 1.2 - leg.side * 3.6)
				p.set_px(tip, g.base - 2, str(v.color))
			return true
		"sandals":
			var straps = []
			var soles = []
			for k in feet_px:
				if not feet_px.has(int(k) + W):
					soles.append(int(k))
				elif not feet_px.has(int(k) - W):
					straps.append(int(k))
			_tint(p, m, straps, str(v.color))
			_tint(p, m, soles, Pix.shade(str(v.color), 0.6))
			if bool(v.get("wings", false)):
				var up: int = frame % 2
				for leg in g.legs:
					var wx: int = int(leg.ankle.x + leg.side * 4.0)
					p.set_px(wx, g.base - 3 - up, "#ffffff")
					p.set_px(wx + leg.side, g.base - 4 - up, "#ffffff")
					p.set_px(wx, g.base - 2 - up, "#e0e0e0")
			return true
		"boots":
			var cuff = v.get("accent")
			if cuff == null:
				cuff = Pix.shade(str(v.color), 1.3)
			var shaft: Dictionary = _parts_px(m, ["calf"], int(g.legs[0].ankle.y) - 6, H)
			for k in feet_px:
				shaft[k] = true
			_paint(p, m, shaft, str(v.color), false)
			var top_row: int = int(g.legs[0].ankle.y) - 6
			var cuff_px = []
			var soles = []
			for k in shaft:
				var y: int = int(int(k) / W)
				if y == top_row:
					cuff_px.append(int(k))
				if not shaft.has(int(k) + W):
					soles.append(int(k))
			_tint(p, m, cuff_px, str(cuff))
			_tint(p, m, soles, Pix.shade(str(v.color), 0.55))
			if bool(v.get("jets", false)):
				var fl: int = frame % 2
				for leg in g.legs:
					var fx: int = int(leg.ankle.x + leg.side * 1.2)
					p.set_px(fx - 1, g.base, "#ffe066")
					p.set_px(fx + 1, g.base, "#ffb13b")
					p.set_px(fx + fl - 1, g.base + 1, "#ff7a1a")
			return true
	return false
