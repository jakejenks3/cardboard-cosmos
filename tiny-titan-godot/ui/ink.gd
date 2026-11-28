class_name Ink
extends Node
## Keeps every word readable on what it sits on (2026-11-27, the Workshop look: dark ink on parchment,
## cream on wood, on keys and on the dark planks).
##
## The screens were written for light words on dark panels and set many colours by hand (a green "done",
## the colour of a body part). On parchment some of those would be pale on pale, and a word in Pal.TEXT
## that sits on wood or a dark well would be dark on dark. So main.gd adds one Ink to the tree: every Label,
## every flat Button (a link, a tab: words with no key face of their own) and every pixel-font caption that
## enters the tree is checked a moment later against the SURFACE under it: the nearest ancestor with a fill
## (a StyleBoxFlat's bg_color, a PixBox's meta "bg", a ColorRect, a meta "ink_bg" on a control that draws
## its own surface), with see-through fills blended over what is under them, and the page (Pal.BG) at the
## root. When the contrast is under MIN_SMALL (MIN_BIG for big or bold text) the colour is moved towards dark
## ink or cream, whichever reads better, only as far as needed, so its hue stays.
##
## Left alone: text with an outline of OUTLINE_SKIP px or more (readable on anything), nodes with meta
## "ink_keep" (and everything inside them), text faded on purpose (alpha under FADED: only its hue moves).
## A colour set again after the check is not checked again: call `Ink.check(node)` after such a change.

const MIN_SMALL = 4.2
const MIN_BIG = 3.0
## Text of this size and up (or bold text from BOLD_BIG) is big.
const BIG_PX = 18
const BOLD_BIG = 15
const OUTLINE_SKIP = 3
const FADED = 0.6
## How far a colour may be moved before it is turned all the way to ink or cream instead.
const FLIP_AT = 0.6
## A word with less colour than this (its brightest channel less its darkest: plain ink, a brown, a grey) is
## turned all the way at once.
const NEUTRAL = 0.3
## Pixel-font captions are thin: they need more.
const MIN_PIXEL = 4.5

static var on: bool = true
## How many colours were changed (for tests and the speed corner).
static var fixed: int = 0

var _queue: Array = []
var _queued = false


func _ready() -> void:
	get_tree().node_added.connect(_added)


func _added(n: Node) -> void:
	if not on:
		return
	if n is Label or n is Button or n is RichTextLabel or (n is TextureRect and n.has_meta("pf_text")):
		_queue.append(n)
		if not _queued:
			_queued = true
			_flush.call_deferred()


func _flush() -> void:
	_queued = false
	var q = _queue
	_queue = []
	var memo = {}
	for n in q:
		if is_instance_valid(n) and n.is_inside_tree():
			_fix(n, memo)


## Check one node (and, for a container, everything in it) now.
static func check(n: Node) -> void:
	if not on or n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var memo = {}
	var stack = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is Label or c is Button or c is RichTextLabel or (c is TextureRect and c.has_meta("pf_text")):
			_fix(c, memo)
		for k in c.get_children():
			stack.append(k)


static func _fix(n: Node, memo: Dictionary) -> void:
	if _kept(n):
		return
	if n is Label:
		if n.get_theme_constant("outline_size") >= OUTLINE_SKIP:
			# Readable on anything, but only when the words stand off their outline: dark words with a dark
			# outline (a name on a dark map) turn cream, light words with a light outline dark.
			var oc: Color = n.get_theme_color("font_outline_color")
			var fo: Color = n.get_theme_color("font_color")
			if contrast(fo, oc) < 2.5:
				var flip = Pal.CREAM if luminance(oc) < 0.2 else Pal.INK
				n.add_theme_color_override("font_color", Color(flip.r, flip.g, flip.b, fo.a))
				fixed += 1
			return
		if n.get_theme_color("font_shadow_color").a > 0.5 and (n.get_theme_constant("shadow_offset_x") != 0 or n.get_theme_constant("shadow_offset_y") != 0):
			# Words with a shadow were given it for the surface they sit on (Kit.tag).
			return
		var bg = surface(n.get_parent(), memo)
		var own = _fill_of(n)
		if own is Color and own.a > 0.05:
			bg = bg.lerp(Color(own.r, own.g, own.b), own.a)
		var fg = n.get_theme_color("font_color")
		var px = n.get_theme_font_size("font_size")
		# (Kit.label sets a font only for bold words; Ink must not need Kit, so tests can use it without autoloads)
		var bold = n.has_theme_font_override("font")
		var want = adjust(fg, bg, MIN_BIG if (px >= BIG_PX or (bold and px >= BOLD_BIG)) else MIN_SMALL)
		if want != fg:
			n.add_theme_color_override("font_color", want)
			fixed += 1
	elif n is Button:
		if not _bare(n) or n.get_theme_constant("outline_size") >= OUTLINE_SKIP or n.text == "":
			return
		var bg2 = surface(n.get_parent(), memo)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			var fk = n.get_theme_color(k)
			var w = adjust(fk, bg2, MIN_SMALL)
			if w != fk:
				n.add_theme_color_override(k, w)
				fixed += 1
	elif n is RichTextLabel:
		# Its plain words (the [color] parts are its own business).
		var bg4 = surface(n.get_parent(), memo)
		var fr: Color = n.get_theme_color("default_color")
		var want4 = adjust(fr, bg4, MIN_SMALL)
		if want4 != fr:
			n.add_theme_color_override("default_color", want4)
			fixed += 1
	elif n is TextureRect:
		var bg3 = surface(n.get_parent(), memo)
		var fp: Color = n.get_meta("pf_color", Color.WHITE)
		var want3 = adjust(fp, bg3, MIN_PIXEL)
		var shadow = bool(n.get_meta("pf_shadow", true))
		var paper = luminance(bg3) > 0.35
		if want3 != fp or (shadow and paper):
			# (on paper a pixel caption has no shadow: a dark one doubles its strokes)
			n.texture = PixelFont.tex(str(n.get_meta("pf_text")), want3, shadow and not paper)
			n.set_meta("pf_color", want3)
			n.set_meta("pf_shadow", shadow and not paper)
			fixed += 1


static func _kept(n: Node) -> bool:
	var p = n
	var depth = 0
	while p != null and depth < 40:
		if p.has_meta("ink_keep"):
			return true
		p = p.get_parent()
		depth += 1
	return false


## A button with no face of its own: its words sit on what is under it.
static func _bare(b: Button) -> bool:
	if b.flat:
		return true
	var sb = b.get_theme_stylebox("normal")
	var f = _box_fill(sb)
	return f == null or (f is Color and f.a < 0.1)


## The colour under a node: its own fill, or what is under its parent (see the top).
static func surface(node: Node, memo: Dictionary = {}) -> Color:
	var chain = []
	var base = null
	var p = node
	while p != null:
		var id = p.get_instance_id()
		if memo.has(id):
			base = memo[id]
			break
		chain.append(p)
		var f = _fill_of(p)
		if f is Color and f.a >= 0.95:
			base = Color(f.r, f.g, f.b)
			chain.pop_back()
			memo[id] = base
			break
		p = p.get_parent()
	if base == null:
		base = Pal.BG
	# Blend the see-through fills found on the way up over the base, from the bottom up.
	for i in range(chain.size() - 1, -1, -1):
		var f2 = _fill_of(chain[i])
		if f2 is Color and f2.a > 0.05:
			base = base.lerp(Color(f2.r, f2.g, f2.b), f2.a)
		memo[chain[i].get_instance_id()] = base
	return base


static func _fill_of(n: Node):
	if not (n is CanvasItem):
		return null
	if n.has_meta("ink_bg"):
		return n.get_meta("ink_bg")
	if n is ColorRect:
		return n.color if n.visible else null
	if n is PanelContainer or n is Panel:
		return _box_fill(n.get_theme_stylebox("panel"))
	if n is Button:
		if n.flat:
			return null
		return _box_fill(n.get_theme_stylebox("disabled" if n.disabled else "normal"))
	if n is Label:
		return _box_fill(n.get_theme_stylebox("normal"))
	if n is LineEdit:
		return _box_fill(n.get_theme_stylebox("normal"))
	return null


static func _box_fill(sb):
	if sb == null:
		return null
	if sb.has_meta("bg"):
		return sb.get_meta("bg")
	if sb is StyleBoxFlat:
		return sb.bg_color if sb.draw_center else null
	return null


## Relative luminance (WCAG).
static func luminance(c: Color) -> float:
	var ch = [c.r, c.g, c.b]
	var lin = []
	for v in ch:
		lin.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


static func contrast(a: Color, b: Color) -> float:
	var la = luminance(a)
	var lb = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## `fg` moved towards dark ink or cream until it has `min_ratio` against `bg` (unchanged when it has).
static func adjust(fg: Color, bg: Color, min_ratio: float) -> Color:
	var seen = bg.lerp(Color(fg.r, fg.g, fg.b), fg.a)
	if contrast(seen, bg) >= min_ratio:
		return fg
	var dark = Pal.INK
	var light = Pal.CREAM
	var target = dark if contrast(dark, bg) >= contrast(light, bg) else light
	var base = Color(fg.r, fg.g, fg.b)
	var plain = maxf(base.r, maxf(base.g, base.b)) - minf(base.r, minf(base.g, base.b)) < NEUTRAL
	for i in range(1, 21):
		var t = i / 20.0
		# Towards dark, a coloured word is darkened in its own hue (gold becomes a deep gold, not khaki);
		# towards light it is mixed with cream.
		var c = base.darkened(t) if (target == dark and not plain) else base.lerp(target, t)
		if fg.a < FADED:
			# Faded on purpose (a key that cannot be used): only the hue moves.
			if contrast(bg.lerp(c, fg.a), bg) >= min_ratio * 0.5 or i == 20:
				return Color(c.r, c.g, c.b, fg.a)
			continue
		if contrast(c, bg) >= min_ratio:
			# Plain words (dark ink on dark wood, a pale grey on paper) and words that have to change a lot
			# are turned all the way: a half-way brown reads poorly. A coloured word a little off keeps its hue.
			if t >= FLIP_AT or plain:
				return Color(target.r, target.g, target.b, 1.0)
			return Color(c.r, c.g, c.b, 1.0)
	return Color(target.r, target.g, target.b, fg.a if fg.a < FADED else 1.0)
