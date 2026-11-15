class_name PixBox
extends RefCounted
## Pixel-art boxes drawn in code: the panels, buttons and wells the whole UI
## is made of. Each is a tiny 9-patch (rounded corners, dark outline, bright
## inner edge, a highlight row and a raised "lip" underneath), so it stretches
## to any size while staying crisp, in the same chunky pixels as the art.

## Screen pixels per art pixel.
const S = 2
## Tile size and 9-patch margin, in art pixels.
const T = 12
const M = 4

static var _cache = {}


static func clear_cache() -> void:
	_cache.clear()


static func _in(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= T or y >= T:
		return false
	var cut = 0
	if y == 0 or y == T - 1:
		cut = 2
	elif y == 1 or y == T - 2:
		cut = 1
	return x >= cut and x < T - cut


## In the box or in the lip dropped below it.
static func _in_u(x: int, y: int, drop: int) -> bool:
	for d in range(drop + 1):
		if _in(x, y - d):
			return true
	return false


static func _interior(x: int, y: int) -> bool:
	return _in(x, y) and _in(x + 1, y) and _in(x - 1, y) and _in(x, y + 1) and _in(x, y - 1)


static func _inner(x: int, y: int) -> bool:
	return _interior(x, y) and _interior(x + 1, y) and _interior(x - 1, y) and _interior(x, y + 1) and _interior(x, y - 1)


## A box filled with `fill`.
## opts: "ring" (Color of the inner edge, or null), "lip" (art pixels of raised edge
## below, 0 = flat), "lip_color", "gap" (empty art pixels above: a pressed button),
## "inset" (true = sunken: shaded at the top instead of lit), "outline" (Color),
## "pad_h", "pad_v" (content padding in screen pixels).
static func make(fill: Color, opts: Dictionary = {}) -> StyleBoxTexture:
	var ring = opts.get("ring", null)
	var lip = int(opts.get("lip", 1))
	var gap = int(opts.get("gap", 0))
	var inset = bool(opts.get("inset", false))
	var outline: Color = opts.get("outline", Pal.OUTLINE)
	var lip_color: Color = opts.get("lip_color", fill.darkened(0.42))
	var pad_h = int(opts.get("pad_h", 14))
	var pad_v = int(opts.get("pad_v", 10))
	# The lip is `lip` rows of colour plus the outline row that closes it.
	var drop = lip + 1 if lip > 0 else 0
	var key = "%s|%s|%d|%d|%s|%s|%s|%d|%d" % [fill.to_html(), ring.to_html() if ring is Color else "-", lip, gap, inset, outline.to_html(), lip_color.to_html(), pad_h, pad_v]
	if _cache.has(key):
		return _cache[key]

	var top_row = fill.darkened(0.28) if inset else fill.lightened(0.22)
	var bottom_row = fill.lightened(0.05) if inset else fill.darkened(0.16)
	var ring_color: Color = ring if ring is Color else fill
	var h = T + drop + gap
	var img = Image.create_empty(T * S, h * S, false, Image.FORMAT_RGBA8)
	for ay in range(h):
		var y = ay - gap
		for x in range(T):
			if not _in_u(x, y, drop):
				continue
			var c: Color
			if not (_in_u(x + 1, y, drop) and _in_u(x - 1, y, drop) and _in_u(x, y + 1, drop) and _in_u(x, y - 1, drop)):
				c = outline
			elif not _in(x, y):
				c = lip_color
			elif not _interior(x, y):
				# The box's own bottom edge, where it meets the lip.
				c = outline
			elif not _inner(x, y):
				c = ring_color
			elif not _inner(x, y - 1):
				c = top_row
			elif not _inner(x, y + 1):
				c = bottom_row
			else:
				c = fill
			img.fill_rect(Rect2i(x * S, ay * S, S, S), c)

	var sb = StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin(SIDE_LEFT, M * S)
	sb.set_texture_margin(SIDE_RIGHT, M * S)
	sb.set_texture_margin(SIDE_TOP, (M + gap) * S)
	sb.set_texture_margin(SIDE_BOTTOM, (M + drop) * S)
	sb.set_content_margin(SIDE_LEFT, pad_h)
	sb.set_content_margin(SIDE_RIGHT, pad_h)
	sb.set_content_margin(SIDE_TOP, pad_v + gap * S)
	sb.set_content_margin(SIDE_BOTTOM, pad_v + drop * S)
	if _cache.size() > 600:
		_cache.clear()
	_cache[key] = sb
	return sb


## A card: panel colour, bright inner edge, a small lip.
static func panel(fill = null, ring = null, pad: int = 14) -> StyleBoxTexture:
	return make(Pal.PANEL if fill == null else fill, {"ring": Pal.BORDER if ring == null else ring, "lip": 1, "lip_color": Pal.OUTLINE.lightened(0.08), "pad_h": pad, "pad_v": pad})


## A sunken well: inputs, bar tracks, the track of a switch.
static func well(pad_h: int = 12, pad_v: int = 8, ring = null) -> StyleBoxTexture:
	return make(Pal.WELL, {"ring": ring, "lip": 0, "inset": true, "pad_h": pad_h, "pad_v": pad_v})


## The three faces of a raised button: {"normal", "hover", "pressed", "disabled"}.
static func button_set(face: Color, lip_color: Color, pad_h: int, pad_v: int, lip: int = 2, ring = null) -> Dictionary:
	var drop = lip + 1
	return {
		"normal": make(face, {"ring": ring, "lip": lip, "lip_color": lip_color, "pad_h": pad_h, "pad_v": pad_v}),
		"hover": make(face.lightened(0.1), {"ring": ring.lightened(0.1) if ring is Color else null, "lip": lip, "lip_color": lip_color, "pad_h": pad_h, "pad_v": pad_v}),
		"pressed": make(face.darkened(0.06), {"ring": ring, "lip": 0, "gap": drop, "pad_h": pad_h, "pad_v": pad_v}),
		"disabled": make(face.lerp(Pal.PANEL, 0.65), {"ring": null, "lip": lip, "lip_color": lip_color.lerp(Pal.OUTLINE, 0.6), "pad_h": pad_h, "pad_v": pad_v}),
	}
