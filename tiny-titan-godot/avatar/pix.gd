class_name Pix
extends RefCounted
## A tiny pixel buffer (port of avatar/pixel.ts). Everything in the avatar is
## drawn into one of these and then turned into a texture that is shown with
## nearest-neighbour scaling.
##
## Colours are "#rrggbb" strings at the API level, exactly like the TS (null
## means "transparent / erase"), but every pixel is stored as one packed int
## in a PackedInt32Array: the little-endian bytes of an element are R, G, B, A
## (A is always 255 for a filled pixel) and 0 is an empty pixel, so
## `data.to_byte_array()` is directly an RGBA8 image.
##
## TS `get` / `set` are called `get_px` / `set_px` here because `Object.get`
## and `Object.set` cannot be redefined.

const OUTLINE = "#1a1026"

## Added to a 24-bit 0xBBGGRR value this gives the signed 32-bit int whose
## bytes are R, G, B, 255.
const _OPAQUE = -16777216

static var _raw_cache = {} # "#rrggbb" -> packed int
static var _hex_cache = {} # packed int -> "#rrggbb"

var w: int = 0
var h: int = 0
var data: PackedInt32Array = PackedInt32Array()


func _init(width: int = 1, height: int = 1) -> void:
	w = width
	h = height
	data = PackedInt32Array()
	data.resize(width * height)
	data.fill(0)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


## Packed value of a pixel, 0 when empty or out of bounds.
func get_raw(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	return data[y * w + x]


## TS `get`: the "#rrggbb" colour of a pixel, or null when empty / out of bounds.
func get_px(x: int, y: int):
	var v: int = get_raw(x, y)
	if v == 0:
		return null
	return Pix.raw_to_hex(v)


## TS `set`: coordinates are rounded like Math.round, out of bounds is ignored,
## a null colour erases the pixel.
func set_px(x: float, y: float, c) -> void:
	var xi: int = int(floor(x + 0.5))
	var yi: int = int(floor(y + 0.5))
	if xi < 0 or yi < 0 or xi >= w or yi >= h:
		return
	data[yi * w + xi] = Pix.to_raw(c)


func _put_raw(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	data[y * w + x] = v


func rect(x: float, y: float, rw: float, rh: float, c) -> void:
	var x0: int = int(floor(x + 0.5))
	var y0: int = int(floor(y + 0.5))
	# The TS loops `for (xx = x; xx < x + w; xx++)`: ceil(w) columns.
	var x1: int = x0 + int(ceil(rw))
	var y1: int = y0 + int(ceil(rh))
	if x0 < 0:
		x0 = 0
	if y0 < 0:
		y0 = 0
	if x1 > w:
		x1 = w
	if y1 > h:
		y1 = h
	if x1 <= x0 or y1 <= y0:
		return
	var v: int = Pix.to_raw(c)
	for yy in range(y0, y1):
		var row: int = yy * w
		for xx in range(x0, x1):
			data[row + xx] = v


func hline(x: float, y: float, rw: float, c) -> void:
	rect(x, y, rw, 1, c)


func vline(x: float, y: float, rh: float, c) -> void:
	rect(x, y, 1, rh, c)


## Rectangle with the four corner pixels chamfered off.
func round_rect(x: float, y: float, rw: float, rh: float, c, r: int = 1) -> void:
	rect(x, y, rw, rh, c)
	for i in range(r):
		for j in range(r - i):
			set_px(x + i, y + j, null)
			set_px(x + rw - 1 - i, y + j, null)
			set_px(x + i, y + rh - 1 - j, null)
			set_px(x + rw - 1 - i, y + rh - 1 - j, null)


## Filled ellipse.
func ellipse(cx: float, cy: float, rx: float, ry: float, c) -> void:
	var v: int = Pix.to_raw(c)
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx: float = (x + 0.5 - cx) / (rx + 0.5)
			var dy: float = (y + 0.5 - cy) / (ry + 0.5)
			if dx * dx + dy * dy <= 1.0:
				_put_raw(x, y, v)


## A thick line drawn with a square brush: used for limbs so they can bend.
func limb(x0: float, y0: float, x1: float, y1: float, width: int, c) -> void:
	var steps: float = maxf(maxf(absf(x1 - x0), absf(y1 - y0)), 1.0)
	var half: int = int(floor(width / 2.0))
	var i: int = 0
	while i <= steps:
		var t: float = i / steps
		var x: float = floor(x0 + (x1 - x0) * t + 0.5)
		var y: float = floor(y0 + (y1 - y0) * t + 0.5)
		rect(x - half, y - half, width, width, c)
		i += 1


## Draw a sprite given as rows of characters, mapping chars to colours.
## '.' and ' ' are transparent, chars missing from the palette are skipped.
func sprite(x: int, y: int, rows: Array, palette: Dictionary, flip_x: bool = false) -> void:
	for r in range(rows.size()):
		var row: String = rows[r]
		var n: int = row.length()
		for i in range(n):
			var ch: String = row[i]
			if ch == "." or ch == " ":
				continue
			var c = palette.get(ch)
			if c == null:
				continue
			var px: int = (x + (n - 1 - i)) if flip_x else (x + i)
			_put_raw(px, y + r, Pix.to_raw(c))


## Blit another buffer onto this one (empty source pixels are skipped).
func blit(src: Pix, x: int, y: int) -> void:
	var sw: int = src.w
	var sh: int = src.h
	for yy in range(sh):
		var ty: int = y + yy
		if ty < 0 or ty >= h:
			continue
		var srow: int = yy * sw
		var trow: int = ty * w
		for xx in range(sw):
			var v: int = src.data[srow + xx]
			if v == 0:
				continue
			var tx: int = x + xx
			if tx < 0 or tx >= w:
				continue
			data[trow + tx] = v


## Add a 1px outline around every filled pixel (into empty pixels only).
func outline(color) -> void:
	var add: Array = []
	for y in range(h):
		var row: int = y * w
		for x in range(w):
			var i: int = row + x
			if data[i] != 0:
				continue
			if (x > 0 and data[i - 1] != 0) or (x < w - 1 and data[i + 1] != 0) or (y > 0 and data[i - w] != 0) or (y < h - 1 and data[i + w] != 0):
				add.append(i)
	var v: int = Pix.to_raw(color)
	for i in add:
		data[i] = v


## An independent copy of this buffer.
func clone() -> Pix:
	var p: Pix = Pix.new(w, h)
	p.data = data.duplicate()
	return p


## Greyscale + darkened copy: what the web UI does with the CSS filter
## `grayscale(1) brightness(b)` on locked items / pets and beaten bosses.
func dimmed(brightness: float = 0.4) -> Pix:
	var p: Pix = Pix.new(w, h)
	for i in range(w * h):
		var v: int = data[i]
		if v == 0:
			continue
		var u: int = v - _OPAQUE
		var lum: float = 0.2126 * (u & 255) + 0.7152 * ((u >> 8) & 255) + 0.0722 * ((u >> 16) & 255)
		var g: int = clampi(int(floor(lum * brightness + 0.5)), 0, 255)
		p.data[i] = Pix.pack_rgb(g, g, g)
	return p


## Raw RGBA8 bytes, row by row (4 bytes per pixel).
func to_bytes() -> PackedByteArray:
	return data.to_byte_array()


func to_image() -> Image:
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data.to_byte_array())


func to_texture() -> ImageTexture:
	return ImageTexture.create_from_image(to_image())


# --- colour helpers ---------------------------------------------------------

## "#rrggbb" (or "#rgb") -> [r, g, b].
static func hex_to_rgb(hex: String) -> Array:
	var s: String = hex.replace("#", "")
	if s.length() == 3:
		s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2]
	var n: int = s.hex_to_int()
	return [(n >> 16) & 255, (n >> 8) & 255, n & 255]


## Channels are rounded like Math.round and clamped to 0-255.
static func rgb_to_hex(r: float, g: float, b: float) -> String:
	return "#%02x%02x%02x" % [_channel(r), _channel(g), _channel(b)]


static func _channel(v: float) -> int:
	return clampi(int(floor(v + 0.5)), 0, 255)


## factor < 1 darkens, > 1 lightens.
static func shade(hex: String, factor: float) -> String:
	var rgb: Array = hex_to_rgb(hex)
	var r: int = rgb[0]
	var g: int = rgb[1]
	var b: int = rgb[2]
	if factor >= 1.0:
		var t: float = minf(1.0, factor - 1.0)
		return rgb_to_hex(r + (255 - r) * t, g + (255 - g) * t, b + (255 - b) * t)
	return rgb_to_hex(r * factor, g * factor, b * factor)


static func mix(a: String, b: String, t: float) -> String:
	var c1: Array = hex_to_rgb(a)
	var c2: Array = hex_to_rgb(b)
	return rgb_to_hex(c1[0] + (c2[0] - c1[0]) * t, c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t)


## Packed pixel value for 0-255 channels (see the class comment).
static func pack_rgb(r: int, g: int, b: int) -> int:
	return (r | (g << 8) | (b << 16)) + _OPAQUE


## Packed pixel value of a colour string; null (or "") is the empty pixel 0.
static func to_raw(c) -> int:
	if c == null:
		return 0
	var v = _raw_cache.get(c)
	if v == null:
		if c == "":
			return 0
		var rgb: Array = hex_to_rgb(c)
		v = pack_rgb(rgb[0], rgb[1], rgb[2])
		_raw_cache[c] = v
	return v


## "#rrggbb" of a packed (non-empty) pixel value.
static func raw_to_hex(v: int) -> String:
	var s = _hex_cache.get(v)
	if s == null:
		var u: int = v - _OPAQUE
		s = "#%02x%02x%02x" % [u & 255, (u >> 8) & 255, (u >> 16) & 255]
		_hex_cache[v] = s
	return s
