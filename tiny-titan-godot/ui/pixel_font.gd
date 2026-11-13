class_name PixelFont
extends RefCounted
## A small arcade-style bitmap font for short retro captions ("LV 12",
## "+240 XP", "PR!"). Glyphs are 7 pixels tall and up to 5 wide; lowercase is
## drawn with the capitals. Anything longer than a caption should use normal
## text (Kit.label).

const HEIGHT = 7
const SPACING = 1
const SHADOW = Color("1a1026")

const GLYPHS = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	" ": ["...", "...", "...", "...", "...", "...", "..."],
	".": [".", ".", ".", ".", ".", ".", "#"],
	",": ["..", "..", "..", "..", "..", ".#", "#."],
	":": [".", ".", "#", ".", "#", ".", "."],
	";": ["..", "..", ".#", "..", ".#", ".#", "#."],
	"!": ["#", "#", "#", "#", "#", ".", "#"],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	"'": ["#", "#", ".", ".", ".", ".", "."],
	"\"": ["#.#", "#.#", "...", "...", "...", "...", "..."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	"-": ["....", "....", "....", "####", "....", "....", "...."],
	"×": [".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "....."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	"%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
	"(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
	"#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
	">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
	"→": [".....", "..#..", "...#.", "#####", "...#.", "..#..", "....."],
}

static var _cache = {}


static func _glyph(ch: String) -> Array:
	var up = ch.to_upper()
	if up == "X" and ch == "x":
		return GLYPHS["X"]
	if GLYPHS.has(up):
		return GLYPHS[up]
	if up == "−" or up == "–" or up == "—":
		return GLYPHS["-"]
	return GLYPHS[" "]


## Size of the rendered text in font pixels (without the shadow).
static func measure(text: String) -> Vector2i:
	var w = 0
	for i in range(text.length()):
		w += _glyph(text[i])[0].length() + SPACING
	return Vector2i(maxi(1, w - SPACING), HEIGHT)


## The text as a texture, one texture pixel per font pixel (cached).
static func tex(text: String, color: Color = Color.WHITE, shadow: bool = true) -> ImageTexture:
	var key = "%s|%s|%s" % [text, color.to_html(), shadow]
	if _cache.has(key):
		return _cache[key]
	var m = measure(text)
	var extra = 1 if shadow else 0
	var img = Image.create_empty(m.x + extra, m.y + extra, false, Image.FORMAT_RGBA8)
	# Shadow first, then the letters on top.
	for layer in range(2):
		if layer == 0 and not shadow:
			continue
		var off = 1 if layer == 0 else 0
		var col = SHADOW if layer == 0 else color
		var x0 = 0
		for i in range(text.length()):
			var g = _glyph(text[i])
			var gw = g[0].length()
			for y in range(HEIGHT):
				var row = g[y]
				for x in range(gw):
					if row[x] == "#":
						img.set_pixel(x0 + x + off, y + off, col)
			x0 += gw + SPACING
	var t = ImageTexture.create_from_image(img)
	if _cache.size() > 300:
		_cache.clear()
	_cache[key] = t
	return t


## A crisp TextureRect showing the text, each font pixel drawn `px_scale` pixels big.
static func rect(text: String, px_scale: int = 2, color: Color = Color.WHITE, shadow: bool = true) -> TextureRect:
	var t = tex(text, color, shadow)
	var r = TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(t.get_width() * px_scale, t.get_height() * px_scale)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r
