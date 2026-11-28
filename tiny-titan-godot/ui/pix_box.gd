class_name PixBox
extends RefCounted
## Pixel-art boxes drawn in code: every panel, key, well and frame of the UI.
##
## THE WORKSHOP LOOK (2026-11-27; see the top of ui/pal.gd). Every box is a 9-slice made of RINGS round a
## fill, from the outside in: a ring is one colour, or a bevel (lit on the top and left, shaded on the bottom
## and right), or four sides. Its corners are nipped off (`cut` art pixels) and it is drawn at S screen
## pixels per art pixel, so it stretches to any size and stays crisp. Under a box may hang ROWS: a key's
## lip (its side, closed by the rim) and a shadow. A pressed key has empty rows on top instead (`gap`), so
## its face sinks by the depth of its lip.
##
## Every box carries meta "bg" = its fill, which ui/ink.gd reads to keep words readable on it.
##
## `make(fill, opts)` keeps the shape of the old API (ring, lip, gap, inset, outline, lip_color, pad_h,
## pad_v) so the 120 boxes made with it across the screens took the new look at once; `material(name)`
## gives the mock-up's own materials (Pal.MATERIALS), `block_set(name)` its keys (Pal.BLOCKS), `slot(color)`
## a framed icon slot, `window()` a wooden window, `planks()` the page's texture.

## Screen pixels per art pixel.
const S = 2

static var _cache = {}


static func clear_cache() -> void:
	_cache.clear()


## A bevel ring: `lit` on the top and left, `shade` on the bottom and right.
static func bev(lit: Color, shade: Color) -> Dictionary:
	return {"t": lit, "l": lit, "b": shade, "r": shade}


## A ring with four sides.
static func sides(t: Color, l: Color, b: Color, r: Color) -> Dictionary:
	return {"t": t, "l": l, "b": b, "r": r}


## A ring of Pal.MATERIALS ("hex", [lit, shade], [t, l, b, r]) as nine() takes it.
static func spec(r):
	if r is Color or r is Dictionary:
		return r
	if r is String:
		return Color(r)
	if r is Array and r.size() == 2:
		return bev(Color(r[0]), Color(r[1]))
	if r is Array and r.size() == 4:
		return sides(Color(r[0]), Color(r[1]), Color(r[2]), Color(r[3]))
	return Color.MAGENTA


static func _ring_key(r) -> String:
	if r is Color:
		return r.to_html()
	return "%s.%s.%s.%s" % [r.t.to_html(), r.l.to_html(), r.b.to_html(), r.r.to_html()]


## Which ring a pixel of an n x n box is in (0 = the outer one; >= rings = the fill) and on which side;
## -1 outside the nipped corners. A port of the mock-up's canvas code.
static func _where(x: int, y: int, n: int, cut: int) -> Array:
	var d_t = y
	var d_l = x
	var d_b = n - 1 - y
	var d_r = n - 1 - x
	var d = mini(mini(d_t, d_l), mini(d_b, d_r))
	var side = "r"
	if d == d_t:
		side = "t"
	elif d == d_b:
		side = "b"
	elif d == d_l:
		side = "l"
	if cut > 0:
		var dg = mini(d_l, d_r) + mini(d_t, d_b) - cut
		if dg < 0:
			return [-1, side]
		if dg < d:
			d = dg
			side = "t" if d_t <= d_b else "b"
	return [d, side]


## The 9-slice. opts: "cut" (corner chamfer, art px; default 1), "below" (rows under the box, nearest first:
## each a Color, or {"fill": Color, "edge": Color} for a lip whose ends are rim), "gap" (empty art rows
## above), "pad_h", "pad_v" (content margins in screen px from the box's edges; the top one adds the gap,
## the bottom one the rows below), "pad_t" / "pad_b" (instead of pad_v on that side).
static func nine(rings: Array, fill: Color, opts: Dictionary = {}) -> StyleBoxTexture:
	var cut = int(opts.get("cut", 1))
	var below: Array = opts.get("below", [])
	var gap = int(opts.get("gap", 0))
	var pad_h = int(opts.get("pad_h", 14))
	var pad_v = int(opts.get("pad_v", 10))
	var pad_t = int(opts.get("pad_t", pad_v))
	var pad_b = int(opts.get("pad_b", pad_v))
	var parts = PackedStringArray()
	for r in rings:
		parts.append(_ring_key(r))
	var low = PackedStringArray()
	for r in below:
		low.append(r.to_html() if r is Color else "%s/%s" % [r.fill.to_html(), r.edge.to_html()])
	var key = "9|%s|%s|%d|%s|%d|%d|%d|%d" % [",".join(parts), fill.to_html(), cut, ",".join(low), gap, pad_h, pad_t, pad_b]
	if _cache.has(key):
		return _cache[key]
	var b = rings.size()
	var n = 2 * b + 2
	var h = n + below.size() + gap
	var img = Image.create_empty(n * S, h * S, false, Image.FORMAT_RGBA8)
	# The rows below, deepest first: the box's outline shifted down, so they follow its nipped corners.
	for k in range(below.size() - 1, -1, -1):
		var low_fill: Color = below[k] if below[k] is Color else below[k].fill
		var low_edge: Color = below[k] if below[k] is Color else below[k].edge
		for y in range(n):
			for x in range(n):
				var w = _where(x, y, n, cut)
				if int(w[0]) < 0:
					continue
				img.fill_rect(Rect2i(x * S, (y + gap + k + 1) * S, S, S), low_edge if int(w[0]) == 0 else low_fill)
	for y in range(n):
		for x in range(n):
			var w2 = _where(x, y, n, cut)
			var d = int(w2[0])
			if d < 0:
				continue
			var col = fill
			if d < b:
				var r = rings[d]
				col = r if r is Color else r.get(w2[1], fill)
			img.fill_rect(Rect2i(x * S, (y + gap) * S, S, S), col)
	var sb = StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin(SIDE_LEFT, b * S)
	sb.set_texture_margin(SIDE_RIGHT, b * S)
	sb.set_texture_margin(SIDE_TOP, (b + gap) * S)
	sb.set_texture_margin(SIDE_BOTTOM, (b + below.size()) * S)
	sb.set_content_margin(SIDE_LEFT, pad_h)
	sb.set_content_margin(SIDE_RIGHT, pad_h)
	sb.set_content_margin(SIDE_TOP, pad_t + gap * S)
	sb.set_content_margin(SIDE_BOTTOM, pad_b + below.size() * S)
	sb.set_meta("bg", fill)
	if _cache.size() > 900:
		_cache.clear()
	_cache[key] = sb
	return sb


## A box filled with `fill` (the old API, in the new look).
## opts: "ring" (Color: a ring of colour inside the rim, or null), "lip" (art rows of the key's side under it;
## 0 = flat), "lip_color", "gap" (empty art rows above: a pressed key), "key" (a key's face even with no lip:
## pressed), "inset" (true = sunken: shaded at the top), "outline" (the rim's Color), "pad_h", "pad_v".
## A key's lip is `lip` rows of `lip_color` closed by a row of rim, so a key is as tall as it always was.
static func make(fill: Color, opts: Dictionary = {}) -> StyleBoxTexture:
	var ring = opts.get("ring", null)
	var lip = int(opts.get("lip", 1))
	var gap = int(opts.get("gap", 0))
	var inset = bool(opts.get("inset", false))
	var key_face = bool(opts.get("key", false)) or (lip > 0 and not inset)
	var outline: Color = opts.get("outline", Pal.OUTLINE)
	var shade: Color = opts.get("lip_color", fill.darkened(0.3))
	var rings = [outline]
	if ring is Color:
		rings.append(ring)
	if inset:
		rings.append(bev(fill.darkened(0.45), fill.lightened(0.2)))
	elif key_face:
		rings.append(bev(fill.lightened(0.32), fill.darkened(0.25)))
		rings.append(sides(fill, fill, fill.darkened(0.25), fill))
	else:
		rings.append(bev(fill.lightened(0.22), fill.darkened(0.16)))
	var below = []
	if lip > 0 and not inset:
		for i in range(lip):
			below.append({"fill": shade, "edge": outline})
		below.append(outline)
	return nine(rings, fill, {"cut": 1, "below": below, "gap": gap, "pad_h": int(opts.get("pad_h", 14)), "pad_v": int(opts.get("pad_v", 10))})


## One of the mock-up's materials (Pal.MATERIALS: wood, plate, board, slip, card, note, chip, track, well,
## cap). opts: "fill" (another fill colour), "shadow" (art rows of Pal.SHADOW under it), "pad_h", "pad_v",
## "pad_t", "pad_b", "edge" (a Color: the outer rim, e.g. a card's ring in a colour).
static func material(name: String, opts: Dictionary = {}) -> StyleBoxTexture:
	var m = Pal.MATERIALS.get(name, Pal.MATERIALS["slip"])
	var rings = []
	for r in m.rings:
		rings.append(spec(r))
	if opts.get("edge") is Color:
		rings[0] = opts.edge
	var below = []
	for i in range(int(opts.get("shadow", 0))):
		below.append(Pal.SHADOW)
	var fill = opts.get("fill", Color(m.fill))
	var o = {"cut": int(m.cut), "below": below}
	for k in ["pad_h", "pad_v", "pad_t", "pad_b"]:
		if opts.has(k):
			o[k] = opts[k]
	return nine(rings, fill, o)


## A wooden window (a section, a card on the page, a sheet): 14 px of frame, a shadow under it.
static func window(pad_h: int = 18, pad_v: int = 18, fill = null, shadow: int = 2) -> StyleBoxTexture:
	var o = {"pad_h": pad_h, "pad_v": pad_v, "shadow": shadow}
	if fill is Color:
		o["fill"] = fill
	return material("wood", o)


## The four looks of a key ("normal", "hover", "pressed", "disabled"). `face` is a Pal.BLOCKS name or a
## Color (its edges worked out from it). `lip` art rows of side under it.
static func block_set(face, pad_h: int, pad_v: int, lip: int = 1) -> Dictionary:
	var c = block_colors(face)
	var rim: Color = c[0]
	var lit: Color = c[1]
	var shade: Color = c[2]
	var f: Color = c[3]
	var out = {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var ff = f
		var ll = lit
		var ss = shade
		var rr = rim
		if state == "hover":
			ff = f.lightened(0.08)
			ll = lit.lightened(0.08)
		elif state == "pressed":
			ff = f.darkened(0.06)
		elif state == "disabled":
			ff = f.lerp(Pal.PANEL, 0.55)
			ll = lit.lerp(Pal.PANEL, 0.55)
			ss = shade.lerp(Pal.PANEL, 0.55)
			rr = rim.lerp(Pal.BORDER, 0.5)
		var rings = [rr, bev(ll, ss), sides(ff, ff, ss, ff)]
		var below = []
		var gap = 0
		if state == "pressed":
			gap = lip + 1 if lip > 0 else 0
		elif lip > 0:
			for i in range(lip):
				below.append({"fill": ss.darkened(0.25), "edge": rr})
			below.append(rr)
		out[state] = nine(rings, ff, {"cut": 1, "below": below, "gap": gap, "pad_h": pad_h, "pad_v": pad_v})
	return out


## [rim, lit, shade, face] of a key: a Pal.BLOCKS name, or worked out from a Color.
static func block_colors(face) -> Array:
	if face is String and Pal.BLOCKS.has(face):
		var b = Pal.BLOCKS[face]
		return [Color(b[0]), Color(b[1]), Color(b[2]), Color(b[3])]
	var c: Color = face if face is Color else Pal.ACCENT
	return [c.darkened(0.72), c.lightened(0.34), c.darkened(0.3), c]


## Should words on a key of this face be dark ink (a light face) or cream with a dark outline?
static func dark_words(face) -> bool:
	var c: Color = block_colors(face)[3]
	return Ink.luminance(c) > 0.42


## A framed icon slot: a dark rim, a ring in `color`, a sunken bevel and a dark brown well (`small`: no
## sunken bevel, so a 32 px icon fills a 40 px slot).
static func slot(color: Color, small: bool = false, pad: int = 2) -> StyleBoxTexture:
	var m = Pal.MATERIALS["slot"]
	var rings = [spec(m.rings[0]), bev(color.lightened(0.38), color.darkened(0.42))]
	if not small:
		rings.append(spec(m.rings[1]))
	return nine(rings, Color(m.fill), {"cut": 1, "pad_h": pad, "pad_v": pad})


## A card: the panel colour (sand) with a bevel, a small lip; `ring` a colour-coded edge.
static func panel(fill = null, ring = null, pad: int = 14) -> StyleBoxTexture:
	var f: Color = Pal.PANEL2 if fill == null else fill
	var rim = spec(Pal.MATERIALS["card"].rings[0])
	if ring is Color:
		return nine([rim, ring, bev(f.lightened(0.3), f.darkened(0.16))], f, {"cut": 1, "pad_h": pad, "pad_v": pad})
	if fill == null:
		return material("card", {"pad_h": pad, "pad_v": pad})
	return nine([rim, bev(f.lightened(0.3), f.darkened(0.16))], f, {"cut": 1, "pad_h": pad, "pad_v": pad})


## A sunken well: inputs, the track of a switch (dark; its words are cream).
static func well(pad_h: int = 12, pad_v: int = 8, ring = null) -> StyleBoxTexture:
	var m = Pal.MATERIALS["well"]
	var rings = [spec(m.rings[0])]
	if ring is Color:
		rings.append(ring.darkened(0.15))
	rings.append(spec(m.rings[1]))
	return nine(rings, Pal.WELL, {"cut": 1, "pad_h": pad_h, "pad_v": pad_v})


## The faces of a raised key in `face` with `lip_color` for its side ({"normal", "hover", "pressed",
## "disabled"}); `ring` an inner edge in another colour (old callers: the quiet key).
static func button_set(face: Color, lip_color: Color, pad_h: int, pad_v: int, lip: int = 2, ring = null) -> Dictionary:
	var drop = lip + 1
	var out = block_set(face, pad_h, pad_v, lip)
	if ring is Color:
		out["normal"] = make(face, {"ring": ring, "lip": lip, "lip_color": lip_color, "pad_h": pad_h, "pad_v": pad_v})
		out["hover"] = make(face.lightened(0.08), {"ring": ring.lightened(0.08), "lip": lip, "lip_color": lip_color, "pad_h": pad_h, "pad_v": pad_v})
		out["pressed"] = make(face.darkened(0.06), {"ring": ring, "lip": 0, "key": true, "gap": drop, "pad_h": pad_h, "pad_v": pad_v})
	return out


## The page's planks: a 96 x 32 art-pixel tile (two rows of boards with their joints, grain and nails),
## drawn at S, to tile behind everything.
static var _planks = null


static func planks() -> ImageTexture:
	if _planks != null:
		return _planks
	var w = 96
	var h = 32
	var img = Image.create_empty(w * S, h * S, false, Image.FORMAT_RGBA8)
	var seed = [11]
	var rnd = func() -> int:
		seed[0] = (seed[0] * 1103515245 + 12345) & 0x7fffffff
		return seed[0]
	var px = func(x: int, y: int, col: Color) -> void:
		img.fill_rect(Rect2i(((x % w) + w) % w * S, y * S, S, S), col)
	var rows = [{"y": 0, "s": [0, 52], "tone": [Color("33200f"), Color("2c1a10")]}, {"y": 16, "s": [26, 76], "tone": [Color("2a180e"), Color("311d12")]}]
	for r in rows:
		for x in range(w):
			var seg = 0 if (x >= r.s[0] and x < r.s[1]) else 1
			for yy in range(r.y, r.y + 16):
				px.call(x, yy, r.tone[seg])
			px.call(x, r.y, Color("45291a"))
			px.call(x, r.y + 14, Color("21130c"))
			px.call(x, r.y + 15, Color("150b06"))
		for i in range(14):
			var gx = rnd.call() % w
			var gy = r.y + 2 + rnd.call() % 11
			var ln = 3 + rnd.call() % 8
			var col = Color("24150d") if i % 2 == 1 else Color("3c2619")
			for k in range(ln):
				px.call(gx + k, gy, col)
		for s in r.s:
			for yy in range(r.y + 1, r.y + 15):
				px.call(s, yy, Color("150b06"))
				px.call(s + 1, yy, Color("45291a"))
			px.call(s + 3, r.y + 3, Color("6a4a34"))
			px.call(s + 3, r.y + 4, Color("120904"))
			px.call(s + 3, r.y + 11, Color("6a4a34"))
			px.call(s + 3, r.y + 12, Color("120904"))
	_planks = ImageTexture.create_from_image(img)
	return _planks
