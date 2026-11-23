class_name SymbolFont
extends RefCounted
## The symbols Godot's own font lacks (→ ← ↑ ▲ ▼ ▾ ✓ ...), as a small MSDF font
## built from ui/symbol_font_data.gd (made by tools/make_symbol_font.gd).
##
## On a PC the missing glyphs come from the system's fonts; a phone's browser
## has none and draws a box instead. install() adds this font as a fallback of
## the game's font (and its bold variation), so the same text shows the same
## symbols everywhere. main.gd calls it in the web build.

static var _font: FontFile = null


static func font() -> FontFile:
	if _font != null:
		return _font
	var img = Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(SymbolFontData.PNG)) != OK:
		return null
	var f = FontFile.new()
	f.font_name = "Tiny Titan symbols"
	f.multichannel_signed_distance_field = true
	f.msdf_size = SymbolFontData.MSDF_SIZE
	f.msdf_pixel_range = SymbolFontData.PIXEL_RANGE
	var n = SymbolFontData.MSDF_SIZE
	var sz = Vector2i(n, 0)
	f.set_cache_ascent(0, n, SymbolFontData.ASCENT)
	f.set_cache_descent(0, n, SymbolFontData.DESCENT)
	f.set_cache_underline_position(0, n, SymbolFontData.UNDERLINE)
	f.set_cache_underline_thickness(0, n, SymbolFontData.UNDERLINE_W)
	f.set_texture_image(0, sz, 0, img)
	for code in SymbolFontData.GLYPHS:
		var g = SymbolFontData.GLYPHS[code]
		var c = int(code)
		f.set_glyph_advance(0, n, c, Vector2(float(g[0]), 0.0))
		f.set_glyph_offset(0, sz, c, Vector2(float(g[1]), float(g[2])))
		f.set_glyph_size(0, sz, c, Vector2(float(g[3]), float(g[4])))
		f.set_glyph_uv_rect(0, sz, c, Rect2(float(g[5]), float(g[6]), float(g[7]), float(g[8])))
		f.set_glyph_texture_idx(0, sz, c, 0)
	_font = f
	return f


## Add the symbols as the last fallback of `base` (the game's font) and of `bold`.
static func install(base: Font, bold: Font = null) -> void:
	var f = font()
	if f == null:
		return
	for target in [base, bold]:
		if target == null:
			continue
		var fb = target.fallbacks.duplicate()
		if not fb.has(f):
			fb.append(f)
			target.fallbacks = fb
