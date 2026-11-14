class_name Equipment
extends RefCounted
## Draws equipment onto the procedural body using its anchors (port of
## avatar/equipment.ts). Each visual "kind" is a template shared by several
## items that differ only in colour.
##
## `v` is an item visual: `Items.by_id(id).visual`, a Dictionary with a `kind`
## and the TS field names (color, accent, visor, aero, gem, frame, pattern,
## knee, shorts, long, fingerless, sole, wings, inner, buckle, ribbon, disc,
## style). Optional fields may be absent. `m` is the Metrics Dictionary of
## HeroBody.body_metrics().

# --- back ---------------------------------------------------------------

static func draw_back_item(p: Pix, v: Dictionary, m: Dictionary, frame: int) -> void:
	match v.kind:
		"cape":
			var top: int = m.torsoTop + 1
			var bottom: int = m.legTop + 4
			var wave: int = 0 if frame % 4 < 2 else 1
			for y in range(top, bottom + 1):
				var t: float = float(y - top) / maxi(1, bottom - top)
				var cw: int = TTUtil.jsround(m.shoulderW + 2 + t * 6)
				if cw % 2 != 0:
					cw += 1
				var x: int = m.cx - int(cw / 2.0) + (wave if y > top + 3 else 0)
				p.hline(x, y, cw, v.color)
				p.set_px(x + 1, y, v.inner)
				if y == bottom:
					for k in range(0, cw, 3):
						p.set_px(x + k + 1, y + 1, v.color)
		"crashpad":
			var cw: int = m.shoulderW + 10
			var ch: int = m.torsoH + 6
			var x: int = m.cx - int(floor(cw / 2.0))
			var y: int = m.torsoTop - 3
			p.round_rect(x, y, cw, ch, v.color, 1)
			p.hline(x, y + int(floor(ch / 2.0)), cw, v.accent)
			p.vline(x + cw - 2, y + 1, ch - 2, Pix.shade(v.color, 0.8))
			# straps on the shoulders
			p.rect(m.cx - 4, m.torsoTop, 2, 3, Pix.shade(v.accent, 0.7))
			p.rect(m.cx + 2, m.torsoTop, 2, 3, Pix.shade(v.accent, 0.7))
		"barbell":
			var y: int = m.torsoTop + 1
			var half: int = 18
			p.hline(m.cx - half, y, half * 2, "#aab2bd")
			p.hline(m.cx - half, y + 1, half * 2, "#7b8491")
			for side in [-1, 1]:
				var px: int = (m.cx - half - 1) if side < 0 else (m.cx + half - 3)
				p.rect(px, y - 3, 3, 8, "#3b4452")
				p.rect(px + 1, y - 2, 1, 6, "#d64545")
		"backpack":
			var tl: int = m.torsoLeft.call(m.torsoTop + 2)
			var tw: int = m.torsoW.call(m.torsoTop + 2)
			p.rect(tl - 2, m.torsoTop + 1, 2, 8, v.color)
			p.rect(tl + tw, m.torsoTop + 1, 2, 8, v.color)
			var accent = v.get("accent")
			if accent != null:
				p.rect(tl - 2, m.torsoTop + 2, 1, 3, accent)
				p.rect(tl + tw + 1, m.torsoTop + 2, 1, 3, accent)
		"saddlebag":
			var t_right: int = m.torsoLeft.call(m.torsoBottom) + m.torsoW.call(m.torsoBottom)
			p.round_rect(t_right, m.torsoBottom - 3, 4, 4, v.color, 1)
			p.set_px(t_right + 1, m.torsoBottom - 2, Pix.shade(v.color, 1.4))
		"shield":
			# A chainring slung across the back: toothed disc peeking out behind the torso.
			var cy: int = m.torsoTop + int(floor(m.torsoH / 2.0))
			var r: int = int(floor(m.shoulderW / 2.0)) + 3
			p.ellipse(m.cx, cy, r, r, v.color)
			p.ellipse(m.cx, cy, r - 2, r - 2, Pix.shade(v.color, 0.75))
			for a in range(12):
				var ang: float = (a / 12.0) * PI * 2
				p.set_px(floor(m.cx + cos(ang) * (r + 1.2)), floor(cy + sin(ang) * (r + 1.2)), v.accent)
			p.rect(m.cx - 3, m.torsoTop, 2, 3, Pix.shade(v.accent, 0.7))
			p.rect(m.cx + 1, m.torsoTop, 2, 3, Pix.shade(v.accent, 0.7))


# --- legs ---------------------------------------------------------------

static func draw_leg_garment(p: Pix, v: Dictionary, m: Dictionary) -> void:
	var legs: Array = [m.legL, m.legR]
	match v.kind:
		"shorts":
			var accent = v.get("accent")
			var knee = v.get("knee")
			for l in legs:
				p.rect(l.x, l.top, l.thighW, l.kneeY - l.top - 1, v.color)
				p.hline(l.x, l.top, l.thighW, Pix.shade(v.color, 0.8))
				if accent != null:
					p.vline(l.x if l.side < 0 else l.x + l.thighW - 1, l.top + 1, l.kneeY - l.top - 2, accent)
				if knee != null:
					p.rect(l.calfX, l.kneeY - 1, l.calfW, 3, knee)
			# waistband across the hips
			p.hline(m.torsoLeft.call(m.torsoBottom), m.torsoBottom, m.torsoW.call(m.torsoBottom), Pix.shade(v.color, 0.9))
		"tights":
			var accent = v.get("accent")
			for l in legs:
				p.rect(l.x, l.top, l.thighW, l.kneeY - l.top, v.color)
				p.rect(l.calfX, l.kneeY, l.calfW, m.feetTop - l.kneeY, v.color)
				if accent != null and accent != v.color:
					p.vline(l.x if l.side < 0 else l.x + l.thighW - 1, l.top + 1, l.kneeY - l.top - 1, accent)
			p.hline(m.torsoLeft.call(m.torsoBottom), m.torsoBottom, m.torsoW.call(m.torsoBottom), Pix.shade(v.color, 0.9))
		"harness":
			draw_leg_garment(p, {"kind": "shorts", "color": v.shorts}, m)
			p.hline(m.torsoLeft.call(m.torsoBottom), m.torsoBottom, m.torsoW.call(m.torsoBottom), v.color)
			for l in legs:
				p.hline(l.x, l.top + 3, l.thighW, v.color)
				p.set_px(l.x + l.thighW - 1 if l.side < 0 else l.x, l.top + 1, v.color)
				p.set_px(l.x + l.thighW - 1 if l.side < 0 else l.x, l.top + 2, v.color)
			p.rect(m.cx - 1, m.torsoBottom - 1, 2, 2, Pix.shade(v.color, 1.3))


# --- feet ---------------------------------------------------------------

## `v` may be null: bare feet.
static func draw_feet(p: Pix, v, m: Dictionary, frame: int) -> void:
	var feet: Array = [m.footL, m.footR]
	var y: int = m.feetTop
	var fh: int = m.footH
	if v == null:
		for f in feet:
			p.rect(f.x, y, f.w, fh, m.skin)
		for f in feet:
			p.hline(f.x, y + fh - 1, f.w, Pix.shade(m.skin, 0.85))
		return
	match v.kind:
		"shoes":
			var sole = v.get("sole")
			if sole == null:
				sole = Pix.shade(v.color, 0.6)
			for fi in range(2):
				var f: Dictionary = feet[fi]
				var is_left: bool = fi == 0
				p.rect(f.x, y, f.w, fh, v.color)
				p.hline(f.x, y + fh - 1, f.w, sole)
				var ax: int = f.x if is_left else f.x + f.w - 2
				p.hline(ax, y + 1, 2, v.accent)
				p.set_px(f.x + f.w - 1 if is_left else f.x, y, Pix.shade(v.color, 0.8))
		"climbshoes":
			for fi in range(2):
				var f: Dictionary = feet[fi]
				var is_left: bool = fi == 0
				p.rect(f.x, y, f.w, fh, v.color)
				p.hline(f.x, y + fh - 1, f.w, "#222222")
				# pointed toe
				p.set_px(f.x - 1 if is_left else f.x + f.w, y + fh - 2, v.color)
				p.set_px(f.x - 1 if is_left else f.x + f.w, y + fh - 1, "#222222")
				p.set_px(f.x + f.w - 1 if is_left else f.x, y, Pix.shade(v.color, 0.7))
		"sandals":
			for fi in range(2):
				var f: Dictionary = feet[fi]
				var is_left: bool = fi == 0
				p.rect(f.x, y, f.w, fh, m.skin)
				p.hline(f.x, y, f.w, v.color)
				p.hline(f.x, y + fh - 1, f.w, Pix.shade(v.color, 0.6))
				if v.get("wings", false):
					var up: int = frame % 2
					var wx: int = f.x + f.w - 1 if is_left else f.x
					var dir: int = 1 if is_left else -1
					p.set_px(wx + dir, y - up, "#ffffff")
					p.set_px(wx + dir * 2, y - 1 - up, "#ffffff")
					p.set_px(wx + dir, y + 1 - up, "#e0e0e0")
		_:
			for f in feet:
				p.rect(f.x, y, f.w, fh, m.skin)


# --- body ---------------------------------------------------------------

static func _fill_torso(p: Pix, m: Dictionary, color: String, from_row: int = 0) -> void:
	for y in range(m.torsoTop + from_row, m.torsoBottom + 1):
		p.hline(m.torsoLeft.call(y), y, m.torsoW.call(y), color)


static func _sleeves(p: Pix, m: Dictionary, color: String, rows: int = 3) -> void:
	for a in [m.armL, m.armR]:
		var half: int = int(floor(a.upperW / 2.0))
		if m.pose == "flex":
			var x0: int = a.shoulder.x - 2 if a.side < 0 else a.shoulder.x - half
			p.rect(x0, a.shoulder.y - half, 3, a.upperW, color)
		else:
			p.rect(a.shoulder.x - half, a.shoulder.y - half, a.upperW, rows, color)


static func draw_body_garment(p: Pix, v: Dictionary, m: Dictionary) -> void:
	match v.kind:
		"shirt":
			_fill_torso(p, m, v.color)
			_sleeves(p, m, v.color)
			var collar: String = Pix.shade(v.color, 0.75)
			p.hline(m.cx - 2, m.torsoTop, 4, collar)
			var acc = v.get("accent")
			if acc == null:
				acc = Pix.shade(v.color, 1.3)
			var pattern = v.get("pattern")
			if pattern == "stripe":
				p.hline(m.torsoLeft.call(m.torsoTop + 4), m.torsoTop + 4, m.torsoW.call(m.torsoTop + 4), acc)
				p.hline(m.torsoLeft.call(m.torsoTop + 7), m.torsoTop + 7, m.torsoW.call(m.torsoTop + 7), acc)
			elif pattern == "polka":
				for y in range(m.torsoTop + 2, m.torsoBottom, 3):
					var l: int = m.torsoLeft.call(y)
					var tw: int = m.torsoW.call(y)
					for x in range(l + int(y / 3.0) % 2, l + tw, 3):
						p.set_px(x, y, acc)
			elif pattern == "reflective":
				for y in range(m.torsoTop + 2, m.torsoBottom, 4):
					p.hline(m.torsoLeft.call(y), y, m.torsoW.call(y), acc)
			elif pattern == "hood":
				var hl: int = m.torsoLeft.call(m.torsoTop) - 1
				var hw: int = m.torsoW.call(m.torsoTop) + 2
				p.hline(hl, m.torsoTop, hw, acc)
				p.hline(hl, m.torsoTop + 1, hw, acc)
				p.vline(m.cx - 2, m.torsoTop + 2, 3, Pix.shade(acc, 1.5))
				p.vline(m.cx + 1, m.torsoTop + 2, 3, Pix.shade(acc, 1.5))
				# front pocket
				p.hline(m.cx - 3, m.torsoBottom - 3, 6, Pix.shade(v.color, 0.8))
		"tank":
			_fill_torso(p, m, v.color, 2)
			var tl: int = m.torsoLeft.call(m.torsoTop)
			var tw: int = m.torsoW.call(m.torsoTop)
			p.rect(tl + 1, m.torsoTop, 2, 2, v.color)
			p.rect(tl + tw - 3, m.torsoTop, 2, 2, v.color)
			var accent = v.get("accent")
			if accent != null:
				p.hline(m.cx - 2, m.torsoTop + 5, 4, accent)
		"singlet":
			_fill_torso(p, m, v.color, 1)
			var tl: int = m.torsoLeft.call(m.torsoTop)
			var tw: int = m.torsoW.call(m.torsoTop)
			p.rect(tl + 1, m.torsoTop, 2, 1, v.color)
			p.rect(tl + tw - 3, m.torsoTop, 2, 1, v.color)
			var accent = v.get("accent")
			if accent != null:
				p.vline(m.cx - 1, m.torsoTop + 3, 4, accent)
				p.vline(m.cx, m.torsoTop + 3, 4, accent)


# --- hands ---------------------------------------------------------------

static func draw_hands(p: Pix, v: Dictionary, m: Dictionary) -> void:
	for a in [m.armL, m.armR]:
		var hd: Dictionary = a.hand
		match v.kind:
			"chalk":
				var c: String = Pix.mix(m.skin, "#ffffff", 0.7)
				p.rect(hd.x, hd.y, hd.w, hd.h, c)
				p.set_px(a.wrist.x + (-1 if a.side < 0 else 1), a.wrist.y - 1, "#ffffff")
			"wraps":
				var half: int = int(floor(a.foreW / 2.0))
				if v.get("long", false):
					p.limb(a.elbow.x, a.elbow.y + (-1 if m.pose == "flex" else 1), a.wrist.x, a.wrist.y, a.foreW, v.color)
					p.set_px(a.wrist.x - half, TTUtil.jsround((a.elbow.y + a.wrist.y) / 2.0), Pix.shade(v.color, 0.8))
				else:
					var dir: int = -1 if m.pose == "flex" else 1
					p.rect(a.wrist.x - half, a.wrist.y - (0 if dir < 0 else 1), a.foreW, 2, v.color)
					p.rect(a.wrist.x - half, a.wrist.y - (-1 if dir < 0 else 0), a.foreW, 1, Pix.shade(v.color, 0.8))
				p.rect(hd.x, hd.y, hd.w, 1, v.color)
			"gloves":
				p.rect(hd.x, hd.y, hd.w, hd.h, v.color)
				if v.get("fingerless", false):
					p.rect(hd.x, hd.y + (0 if m.pose == "flex" else hd.h - 1), hd.w, 1, m.skin)


# --- accessory ------------------------------------------------------------

static func draw_accessory(p: Pix, v: Dictionary, m: Dictionary, frame: int) -> void:
	match v.kind:
		"belt":
			var y: int = m.torsoBottom - 1
			for yy in range(y, m.torsoBottom + 1):
				p.hline(m.torsoLeft.call(yy), yy, m.torsoW.call(yy), v.color)
			p.rect(m.cx - 1, y, 2, 2, v.buckle)
		"chalkbag":
			var t_right: int = m.torsoLeft.call(m.torsoBottom) + m.torsoW.call(m.torsoBottom)
			p.round_rect(t_right - 1, m.torsoBottom - 1, 4, 5, v.color, 1)
			p.hline(t_right - 1, m.torsoBottom - 1, 4, "#f4f4f4")
			p.set_px(t_right, m.torsoBottom + 1, Pix.shade(v.color, 1.3))
		"pendant":
			var y: int = m.torsoTop
			p.set_px(m.cx - 2, y, "#c0c0c0")
			p.set_px(m.cx + 1, y, "#c0c0c0")
			p.set_px(m.cx - 1, y + 1, "#c0c0c0")
			p.set_px(m.cx, y + 1, "#c0c0c0")
			p.rect(m.cx - 1, y + 2, 2, 2, v.color)
			p.set_px(m.cx - 1, y + 2, Pix.shade(v.color, 1.3))
		"medal":
			var tl: int = m.torsoLeft.call(m.torsoTop)
			var tw: int = m.torsoW.call(m.torsoTop)
			for k in range(4):
				p.set_px(tl + 2 + k, m.torsoTop + k, v.ribbon)
				p.set_px(tl + tw - 3 - k, m.torsoTop + k, v.ribbon)
			p.rect(m.cx - 1, m.torsoTop + 4, 3, 3, v.disc)
			p.set_px(m.cx, m.torsoTop + 5, Pix.shade(v.disc, 0.7))
			if frame % 8 == 0:
				p.set_px(m.cx + 1, m.torsoTop + 4, "#ffffff")
		"bib":
			var bw: int = mini(7, m.torsoW.call(m.torsoTop + 3) - 2)
			var x: int = m.cx - int(floor(bw / 2.0))
			var y: int = m.torsoTop + 3
			p.rect(x, y, bw, 4, v.color)
			p.set_px(x + 1, y + 2, "#222222")
			p.set_px(x + 3, y + 2, "#222222")
			p.set_px(x + 5, y + 2, "#222222")
			p.set_px(x, y, "#9e9e9e")
			p.set_px(x + bw - 1, y, "#9e9e9e")


# --- head / face ----------------------------------------------------------

static func draw_head_item(p: Pix, v: Dictionary, m: Dictionary) -> void:
	var x: int = m.headLeft
	var y: int = m.headTop
	var hw: int = m.headW
	match v.kind:
		"headband":
			p.hline(x - 1, m.eyeY - 3, hw + 2, v.color)
			p.hline(x - 1, m.eyeY - 2, hw + 2, Pix.shade(v.color, 0.8))
		"beanie":
			p.round_rect(x - 1, y - 3, hw + 2, 7, v.color, 2)
			var band = v.get("accent")
			if band == null:
				band = Pix.shade(v.color, 0.75)
			p.hline(x - 1, y + 2, hw + 2, band)
			p.hline(x - 1, y + 3, hw + 2, band)
			p.rect(m.cx - 1, y - 5, 2, 2, Pix.shade(v.color, 1.3))
		"cap":
			var accent = v.get("accent")
			var visor: bool = v.get("visor", false)
			if not visor:
				p.round_rect(x, y - 2, hw, 5, v.color, 1)
				if accent != null:
					p.rect(m.cx - 1, y - 1, 2, 2, accent)
			else:
				p.hline(x - 1, y + 1, hw + 2, v.color)
				p.hline(x - 1, y + 2, hw + 2, v.color)
			var brim_y: int = y + 3
			p.hline(x - 2, brim_y, hw + 4, accent if (accent != null and visor) else Pix.shade(v.color, 0.8))
		"helmet":
			p.round_rect(x - 1, y - 3, hw + 2, 7, v.color, 2)
			var d: String = Pix.shade(v.color, 0.7)
			if v.get("aero", false):
				p.hline(x - 1, y + 3, hw + 2, "#444a52")
				p.hline(x + 2, y - 1, hw - 4, Pix.shade(v.color, 1.4))
			else:
				p.vline(x + 2, y - 2, 4, d)
				p.vline(x + 5, y - 3, 5, d)
				p.vline(x + 8, y - 2, 4, d)
			# chin strap
			p.set_px(x - 1, y + 6, "#222222")
			p.set_px(x + hw, y + 6, "#222222")
		"crown":
			p.rect(x, y - 2, hw, 2, v.color)
			p.set_px(x + 1, y - 3, v.color)
			p.set_px(x + 5, y - 3, v.color)
			p.set_px(x + 6, y - 3, v.color)
			p.set_px(x + 10, y - 3, v.color)
			p.set_px(x + 5, y - 4, v.color)
			p.set_px(x + 6, y - 4, v.color)
			p.set_px(m.cx - 1, y - 2, v.gem)
			p.set_px(m.cx, y - 2, v.gem)
			p.set_px(x + 2, y - 1, Pix.shade(v.color, 1.3))
		"laurel":
			# Wreath of leaves around the brow with a golden clasp.
			for k in range(0, hw, 2):
				p.set_px(x + k, y, v.accent)
				p.set_px(x + k + 1, y - 1, Pix.shade(v.accent, 1.25 if k % 4 == 0 else 0.85))
			for sx in [x - 1, x + hw]:
				p.set_px(sx, y + 1, v.accent)
				p.set_px(sx, y + 2, Pix.shade(v.accent, 0.85))
				p.set_px(sx, y + 3, v.accent)
			p.set_px(x - 2, y, v.accent)
			p.set_px(x + hw + 1, y, v.accent)
			p.set_px(x - 2, y - 2, Pix.shade(v.accent, 1.25))
			p.set_px(x + hw + 1, y - 2, Pix.shade(v.accent, 1.25))
			p.rect(m.cx - 1, y - 2, 2, 2, v.color)
			p.set_px(m.cx - 1, y - 2, Pix.shade(v.color, 1.4))
		"bandana":
			p.round_rect(x, y - 1, hw, 4, v.color, 1)
			p.rect(x + hw, y + 1, 2, 2, v.color)
			p.set_px(x + hw + 2, y + 3, v.color)
			p.set_px(x + hw + 1, y + 3, Pix.shade(v.color, 0.8))
			p.set_px(x + 3, y, Pix.shade(v.color, 1.25))
		"headlamp":
			p.hline(x - 1, m.eyeY - 3, hw + 2, v.color)
			p.rect(m.cx - 1, m.eyeY - 4, 3, 2, Pix.shade(v.color, 1.2))
			p.set_px(m.cx, m.eyeY - 4, "#fff176")


static func draw_face_item(p: Pix, v: Dictionary, m: Dictionary) -> void:
	if v.kind != "sunglasses":
		return
	var y: int = m.eyeY
	var rim = v.get("frame")
	if rim == null:
		rim = Pix.shade(v.color, 0.6)
	p.rect(m.cx - 4, y, 3, 2, v.color)
	p.rect(m.cx + 1, y, 3, 2, v.color)
	p.set_px(m.cx - 1, y, rim)
	p.set_px(m.cx, y, rim)
	p.set_px(m.headLeft, y, rim)
	p.set_px(m.headLeft + m.headW - 1, y, rim)
	p.set_px(m.cx - 3, y, Pix.shade(v.color, 1.5))
	p.set_px(m.cx + 2, y, Pix.shade(v.color, 1.5))


# --- aura -----------------------------------------------------------------

## CSS `hsl(h, s%, l%)` as "#rrggbb". The web version hands the hsl() string
## to the canvas, which does this conversion; here it has to be explicit
## (CSS Color 4 algorithm, channels rounded half-up).
static func hsl(hue: float, s: float, l: float) -> String:
	var hh: int = TTUtil.jsround(hue)
	var sat: float = s / 100.0
	var lig: float = l / 100.0
	var a: float = sat * minf(lig, 1.0 - lig)
	return Pix.rgb_to_hex(_hsl_channel(0, hh, lig, a) * 255, _hsl_channel(8, hh, lig, a) * 255, _hsl_channel(4, hh, lig, a) * 255)


static func _hsl_channel(n: int, hue: int, lig: float, a: float) -> float:
	var k: float = fmod(n + hue / 30.0, 12.0)
	return lig - a * maxf(-1.0, minf(minf(k - 3.0, 9.0 - k), 1.0))


## Aura pixels are drawn only into empty cells so they sit "behind" the hero.
static func _put(p: Pix, x: int, y: int, c: String) -> void:
	if p.get_raw(x, y) == 0:
		p.set_px(x, y, c)


## `style` is "flame" | "gold" | "rainbow" | "frost".
static func draw_aura(p: Pix, style: String, m: Dictionary, frame: int) -> void:
	var left: int = m.cx - int(m.shoulderW / 2.0) - m.armL.upperW - 2
	var right: int = m.cx + int(m.shoulderW / 2.0) + m.armR.upperW + 1
	var top: int = m.headTop - 4
	var bottom: int = m.baseline - 1
	match style:
		"flame":
			var cols: Array = ["#ff7a1a", "#ffb13b", "#ffe066", "#ff5a1a"]
			for i in range(18):
				var side: int = -1 if i % 2 == 0 else 1
				var span: int = bottom - top
				var yy: int = bottom - ((frame * 2 + i * 5) % span)
				var wiggle: int = ((frame + i) % 3) - 1
				var x: int = (left - (i % 3) + wiggle) if side < 0 else (right + (i % 3) + wiggle)
				var c: String = cols[(i + frame) % cols.size()]
				_put(p, x, yy, c)
				if i % 3 == 0:
					_put(p, x, yy + 1, c)
			for x in range(left - 2, right + 3, 2):
				_put(p, x + (frame % 2), bottom, "#ff7a1a")
		"gold":
			for i in range(10):
				var phase: int = (frame + i * 4) % 16
				var x: int = left - 3 + ((i * 7 + frame) % (right - left + 8))
				var y: int = top + ((i * 11 + phase * 2) % (bottom - top))
				var c: String = "#ffd54f" if phase < 8 else "#fff8e1"
				_put(p, x, y, c)
				if phase % 8 < 3:
					_put(p, x - 1, y, c)
					_put(p, x + 1, y, c)
					_put(p, x, y - 1, c)
					_put(p, x, y + 1, c)
		"frost":
			for i in range(14):
				var x: int = left - 2 + ((i * 5) % (right - left + 6))
				var y: int = top + ((i * 9 + frame * 1) % (bottom - top + 2))
				_put(p, x, y, "#e3f2fd" if i % 3 == 0 else "#81d4fa")
		"rainbow":
			var cy: float = (top + bottom) / 2.0
			var rx: float = (right - left) / 2.0 + 3
			var ry: float = (bottom - top) / 2.0 + 1
			for i in range(12):
				var a: float = ((frame * 0.25 + i) / 12.0) * PI * 2
				var x: int = TTUtil.jsround(m.cx + cos(a) * rx)
				var y: int = TTUtil.jsround(cy + sin(a) * ry)
				_put(p, x, y, hsl((i * 30 + frame * 6) % 360, 90, 60))
