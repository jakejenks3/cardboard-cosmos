class_name BattleFx
extends RefCounted
## What a fight looks like when something happens (the user, 2026-11-26: "feels
## like stuff is missing... combinations of animations, sounds and visual
## effects"). Small pixel effects that draw themselves for a moment over the
## arena and then free themselves; BattleView says where and when.
##
##   BattleFx.at(layer, "slash", pos, colour)       # one of KINDS, centred on pos
##   BattleFx.strike(layer, "legs", pos, feet, c)   # a school's hit on a fighter
##   BattleFx.number(layer, pos, "42", colour, 2)   # a damage number that pops and falls
##   BattleFx.word(layer, pos, "WEAK", colour)      # a word that rises
##   BattleFx.flash(over, colour, 0.5, 0.18)        # the whole arena lit for a blink
##   BattleFx.cutin(over, "IRON WILL", colour)      # an ultimate's name across the arena
##   BattleFx.bolt(layer, from, to, colour, 0.16)   # something thrown
##
## Everything is drawn on a grid of U screen pixels, in a few flat colours, so
## it reads as part of the pixel art and not as a smooth particle system.
## Nothing here reads the battle, the save or Pal: colours are handed in.
## `speed` (1 or 2) is the battle's own: effects run that much faster.

## Screen pixels per effect pixel.
const U = 3.0
const KINDS = ["impact", "slash", "stomp", "streaks", "claw", "ring", "spark", "heal", "up", "down", "shield", "shards",
	"poof", "flame", "drops", "gather", "rays", "block", "stars", "dust", "sparkle", "orb", "bite", "notes", "aura"]
## What a school's hit looks like where it lands.
const SCHOOL_FX = {"push": "impact", "pull": "slash", "legs": "stomp", "speed": "streaks", "grip": "claw", "mind": "ring",
	"flow": "spark", "grit": "impact", "plain": "spark"}
## Schools whose attack is thrown from where the hero stands.
const THROWN = ["mind"]

static var speed: float = 1.0


## One effect of KINDS, centred on `pos` (in `layer`'s own pixels). opts: "u"
## (pixel size), "flip" (mirror left / right), "loop" (it goes round until freed),
## "n" (how many parts), "delay" (seconds before it starts), "seed".
static func at(layer: Control, kind: String, pos: Vector2, color: Color, dur: float = 0.36, opts: Dictionary = {}) -> Spr:
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return null
	var s = Spr.new()
	s.kind = kind
	s.color = color
	s.dur = maxf(0.05, dur) / maxf(0.25, speed)
	s.u = float(opts.get("u", U))
	s.flip = -1.0 if bool(opts.get("flip", false)) else 1.0
	s.loop = bool(opts.get("loop", false))
	s.n = int(opts.get("n", 0))
	s.salt = int(opts.get("seed", int(pos.x) * 31 + int(pos.y) * 17))
	s.t = -float(opts.get("delay", 0.0)) / s.dur
	var half = float(opts.get("half", 20.0)) * s.u
	s.size = Vector2(half * 2.0, half * 2.0)
	s.position = (pos - Vector2(half, half)).floor()
	layer.add_child(s)
	return s


## A school's hit on a fighter: `pos` its middle, `feet` the ground under it.
static func strike(layer: Control, school: String, pos: Vector2, feet: Vector2, color: Color, big: bool = false) -> void:
	var kind = str(SCHOOL_FX.get(school, "spark"))
	var white = Color(1, 1, 1)
	match kind:
		"stomp":
			at(layer, "stomp", feet, color, 0.42)
			at(layer, "impact", pos, white, 0.26, {"n": 6})
		"streaks":
			at(layer, "streaks", pos, color, 0.3)
			at(layer, "spark", pos, white, 0.22, {"delay": 0.08})
		"claw":
			at(layer, "claw", pos, color, 0.36)
		"slash":
			at(layer, "slash", pos, color, 0.3)
			at(layer, "spark", pos, white, 0.2, {"delay": 0.1})
		"ring":
			at(layer, "ring", pos, color, 0.4)
			at(layer, "sparkle", pos, white, 0.4, {"n": 5})
		"impact":
			at(layer, "impact", pos, color, 0.3)
		_:
			at(layer, "spark", pos, color, 0.24)
	if big:
		at(layer, "ring", pos, white, 0.34, {"delay": 0.03})
		at(layer, "impact", pos, white, 0.34, {"n": 12, "u": U + 1.0})


## Something thrown from `from` to `to` in `secs`; `then` is called as it lands.
static func bolt(layer: Control, from: Vector2, to: Vector2, color: Color, secs: float = 0.16, then = null) -> void:
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return
	var s = at(layer, "orb", from, color, 9.0, {"loop": true, "half": 8.0})
	if s == null:
		return
	s.dir = (to - from).normalized()
	var half = s.size / 2.0
	var tw = s.create_tween()
	tw.tween_property(s, "position", (to - half).floor(), maxf(0.04, secs) / maxf(0.25, speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if then is Callable:
		tw.tween_callback(then)
	tw.tween_callback(s.queue_free)


## A damage number: it pops, hops to one side and falls away. `n` spreads the
## numbers of a move that hits several times.
static func number(layer: Control, pos: Vector2, text: String, color: Color, px: int = 2, n: int = 0, big: bool = false) -> void:
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return
	var r = PixelFont.rect(text, px, color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	r.size = r.custom_minimum_size
	r.pivot_offset = r.size / 2.0
	var side = 1.0 if n % 2 == 0 else -1.0
	var start = (pos - r.size / 2.0 + Vector2(side * float((n + 1) / 2) * 13.0, -float(n % 3) * 7.0)).floor()
	r.position = start
	r.scale = Vector2(1.9, 1.9) if big else Vector2(1.5, 1.5)
	var k = maxf(0.25, speed)
	var drift = side * (10.0 + float(n % 3) * 4.0)
	var tw = r.create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.16 / k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "position:y", start.y - (30.0 if big else 22.0), 0.22 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "position:x", start.x + drift * 0.5, 0.22 / k)
	if big:
		tw.tween_interval(0.22 / k)
	tw.tween_property(r, "position:y", start.y - 6.0, 0.3 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(r, "position:x", start.x + drift, 0.3 / k)
	tw.parallel().tween_property(r, "modulate:a", 0.0, 0.3 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)


## A word that pops and rises ("WEAK", "BREAK!", a status).
static func word(layer: Control, pos: Vector2, text: String, color: Color, px: int = 1, delay: float = 0.0, rise: float = 24.0) -> void:
	if layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():
		return
	var r = PixelFont.rect(text, px, color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	r.size = r.custom_minimum_size
	r.pivot_offset = r.size / 2.0
	var start = (pos - r.size / 2.0).floor()
	# Never off the layer's sides.
	start.x = clampf(start.x, 2.0, maxf(2.0, layer.size.x - r.size.x - 2.0))
	r.position = start
	r.modulate.a = 0.0
	r.scale = Vector2(1.4, 1.4)
	var k = maxf(0.25, speed)
	var tw = r.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay / k)
	tw.tween_property(r, "modulate:a", 1.0, 0.05 / k)
	tw.parallel().tween_property(r, "scale", Vector2.ONE, 0.14 / k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "position:y", start.y - rise, 0.6 / k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.18 / k)
	tw.tween_callback(r.queue_free)


## The whole of `over` lit in one colour for a blink.
static func flash(over: Control, color: Color, peak: float = 0.5, secs: float = 0.2) -> void:
	if over == null or not is_instance_valid(over) or not over.is_inside_tree():
		return
	var c = ColorRect.new()
	c.color = Color(color.r, color.g, color.b, clampf(peak, 0.0, 1.0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw = c.create_tween()
	tw.tween_property(c, "color:a", 0.0, maxf(0.04, secs) / maxf(0.25, speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(c.queue_free)


## `over` goes dark for `hold` seconds (an ultimate winds up; a boss steps out).
## Returns the cover (free it early with `lift`).
static func dim(over: Control, alpha: float = 0.55, hold: float = 0.6, color: Color = Color(0.02, 0.02, 0.06)) -> ColorRect:
	if over == null or not is_instance_valid(over) or not over.is_inside_tree():
		return null
	var c = ColorRect.new()
	c.color = Color(color.r, color.g, color.b, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k = maxf(0.25, speed)
	var tw = c.create_tween()
	tw.tween_property(c, "color:a", alpha, 0.1 / k)
	tw.tween_interval(maxf(0.02, hold) / k)
	tw.tween_property(c, "color:a", 0.0, 0.16 / k)
	tw.tween_callback(c.queue_free)
	return c


## An ultimate's name across the arena: a dark band with speed lines slides in,
## the words slam in from the other side, both leave.
static func cutin(over: Control, text: String, color: Color, hold: float = 0.5, tag: String = "") -> void:
	if over == null or not is_instance_valid(over) or not over.is_inside_tree():
		return
	var k = maxf(0.25, speed)
	var band = Band.new()
	band.color = color
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(band)
	var bh = 46.0
	band.size = Vector2(over.size.x, bh)
	var y = floor(over.size.y * 0.24 - bh / 2.0)
	band.position = Vector2(-over.size.x, y)
	band.set_meta("bv_cutin", text)
	var words = PixelFont.rect(text, 3 if text.length() <= 14 else 2, Color(1, 1, 1))
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(words)
	words.size = words.custom_minimum_size
	var wx = floor((over.size.x - words.size.x) / 2.0)
	var wy = floor((bh - words.size.y) / 2.0) + (5.0 if tag != "" else 0.0)
	words.position = Vector2(over.size.x + 40.0, wy)
	if tag != "":
		var small = PixelFont.rect(tag, 1, color.lightened(0.3))
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(small)
		small.size = small.custom_minimum_size
		small.position = Vector2(floor((over.size.x - small.size.x) / 2.0), 4.0)
	var tw = band.create_tween()
	tw.tween_property(band, "position:x", 0.0, 0.12 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(words, "position:x", wx, 0.16 / k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(words, "position:x", wx - 10.0, maxf(0.05, hold) / k)
	tw.tween_property(band, "position:x", over.size.x, 0.12 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(band.queue_free)


## A fighter knocked a few pixels and back.
static func knock(c: Control, home: Vector2, dx: float, secs: float = 0.2) -> Tween:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return null
	var k = maxf(0.25, speed)
	c.position = home
	var tw = c.create_tween()
	tw.tween_property(c, "position", home + Vector2(dx, 0), secs * 0.3 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", home, secs * 0.7 / k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


## A fighter tinted for a blink (red when it is hit, green when it is healed).
static func tint(c: CanvasItem, color: Color, secs: float = 0.22) -> void:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.modulate = color
	var tw = c.create_tween()
	tw.tween_property(c, "modulate", Color(1, 1, 1, c.modulate.a), maxf(0.04, secs) / maxf(0.25, speed))


static func _rand(i: int, salt: int) -> float:
	var v = sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


# =============================================================================

## The dark band of a cut-in, with lines rushing through it.
class Band extends Control:
	var color: Color = Color(1, 1, 1)
	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.03, 0.03, 0.08, 0.9))
		draw_rect(Rect2(0, 0, size.x, 3), color)
		draw_rect(Rect2(0, size.y - 3, size.x, 3), color)
		for i in range(7):
			var y = 6.0 + float(i) * (size.y - 12.0) / 6.0
			var w = 30.0 + 50.0 * BattleFx._rand(i, 3)
			var x = fmod(_age * (500.0 + 300.0 * BattleFx._rand(i, 5)) + 400.0 * BattleFx._rand(i, 7), size.x + w) - w
			draw_rect(Rect2(floor(x), floor(y), w, 2), Color(color.r, color.g, color.b, 0.35))


## One effect. `t` runs 0..1 over `dur` seconds.
class Spr extends Control:
	var kind: String = "spark"
	var color: Color = Color(1, 1, 1)
	var dur: float = 0.3
	var t: float = 0.0
	var u: float = 3.0
	var flip: float = 1.0
	var loop: bool = false
	var n: int = 0
	var salt: int = 0
	var dir: Vector2 = Vector2.RIGHT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		t += delta / dur
		if t >= 1.0:
			if loop:
				t = fmod(t, 1.0)
			else:
				queue_free()
				return
		queue_redraw()

	func _r(i: int, k: int) -> float:
		return BattleFx._rand(i + salt, k)

	## One effect pixel at (x, y) effect pixels from the middle.
	func _p(x: float, y: float, c: Color, a: float = 1.0, w: float = 1.0, h: float = 1.0) -> void:
		if a <= 0.02:
			return
		var cx = size.x / 2.0
		var cy = size.y / 2.0
		var gx = round(x * flip)
		if flip < 0.0:
			gx -= w - 1.0
		draw_rect(Rect2(floor(cx + gx * u), floor(cy + round(y) * u), u * w, u * h), Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0)))

	func _line(x0: float, y0: float, x1: float, y1: float, c: Color, a: float = 1.0) -> void:
		var steps = int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
		for i in range(steps + 1):
			var s = float(i) / float(maxi(1, steps))
			_p(lerpf(x0, x1, s), lerpf(y0, y1, s), c, a)

	func _circle(r: float, c: Color, a: float = 1.0, squash: float = 1.0) -> void:
		var steps = int(maxf(8.0, r * 6.3))
		for i in range(steps):
			var ang = TAU * float(i) / float(steps)
			_p(cos(ang) * r, sin(ang) * r * squash, c, a)

	func _plus(x: float, y: float, c: Color, a: float) -> void:
		_p(x, y, c, a)
		_p(x - 1, y, c, a * 0.8)
		_p(x + 1, y, c, a * 0.8)
		_p(x, y - 1, c, a * 0.8)
		_p(x, y + 1, c, a * 0.8)

	func _draw() -> void:
		if t < 0.0:
			return
		var e = 1.0 - pow(1.0 - t, 3.0)
		var fade = 1.0 - t * t
		var white = Color(1, 1, 1)
		var light = color.lightened(0.45)
		var dark = color.darkened(0.3)
		match kind:
			"impact":
				var rays = n if n > 0 else 8
				for i in range(rays):
					var ang = TAU * (float(i) + 0.5) / float(rays)
					var r0 = 2.0 + 9.0 * e
					var r1 = r0 + 5.0 * (1.0 - t) + 1.0
					_line(cos(ang) * r0, sin(ang) * r0, cos(ang) * r1, sin(ang) * r1, light if i % 2 == 0 else color, fade)
				if t < 0.35:
					var d = 3
					for y in range(-d, d + 1):
						for x in range(-d + absi(y), d - absi(y) + 1):
							_p(x, y, white, 1.0 - t / 0.35)
			"slash":
				var head = minf(1.0, t * 1.7)
				var tail = maxf(0.0, head - 0.5)
				var steps = 26
				for i in range(steps + 1):
					var s = float(i) / float(steps)
					if s < tail or s > head:
						continue
					var x = lerpf(12.0, -12.0, s) + sin(PI * s) * 5.0
					var y = lerpf(-13.0, 13.0, s) + sin(PI * s) * 4.0
					var mid = 1.0 - absf((s - tail) / maxf(0.01, head - tail) - 0.6) * 1.6
					_p(x, y, white, fade)
					_p(x + 1, y, light, fade)
					_p(x - 1, y + 1, white, fade * 0.8)
					if mid > 0.2:
						_p(x + 2, y, color, fade)
						_p(x + 1, y - 1, color, fade * 0.9)
					if mid > 0.6:
						_p(x + 3, y, color, fade * 0.8)
						_p(x + 4, y - 1, dark, fade * 0.6)
			"stomp":
				var reach = e * 15.0
				_line(-reach, 0, reach, 0, white if t < 0.3 else light, fade)
				_line(-reach * 0.6, 1, reach * 0.6, 1, dark, fade * 0.7)
				for i in range(8):
					var d2 = -1.0 if i % 2 == 0 else 1.0
					var px = d2 * (3.0 + e * (5.0 + float(i) * 1.6))
					var py = -e * (2.0 + float(i % 4) * 2.2) + t * t * 5.0
					var sz = 2.0 if t < 0.5 else 1.0
					_p(px, py, light if i % 3 == 0 else color, fade, sz, sz)
				# The ground cracks up towards the fighter.
				if t < 0.7:
					_line(0, 0, -2, -3 - e * 3.0, white, fade)
					_line(1, 0, 3, -2 - e * 4.0, white, fade)
			"streaks":
				for i in range(8):
					var y2 = [-10.0, -7.0, -4.0, -1.0, 2.0, 5.0, 8.0, 11.0][i]
					var lead = 18.0 - (t * 1.5 - float(i % 4) * 0.08) * 40.0
					var l2 = 13.0 - float(i % 3) * 3.0
					for j in range(int(l2)):
						var x2 = lead + float(j)
						if x2 > -19.0 and x2 < 19.0:
							_p(x2, y2, white if j < 2 else (light if j < 5 else color), fade * (1.0 - float(j) / l2 * 0.6))
			"claw":
				for i in range(3):
					var start = float(i) * 0.14
					if t < start:
						continue
					var prog = minf(1.0, (t - start) / 0.3)
					var ox = -5.0 + float(i) * 5.0
					var a2 = fade if t < 0.75 else fade * (1.0 - (t - 0.75) / 0.25)
					var y_end = lerpf(-9.0, 9.0, prog)
					_line(ox + 4.0, -9.0, ox + 4.0 - (y_end + 9.0) * 0.45, y_end, white, a2)
					_line(ox + 5.0, -9.0, ox + 5.0 - (y_end + 9.0) * 0.45, y_end, color, a2 * 0.8)
			"ring":
				_circle(2.0 + e * 11.0, light, fade)
				if t > 0.15:
					_circle(1.0 + (e - 0.1) * 8.0, color, fade * 0.6)
			"spark":
				var arm = 1.0 + 5.0 * (1.0 - t)
				_line(-arm, 0, arm, 0, white, fade)
				_line(0, -arm, 0, arm, white, fade)
				_p(-1, -1, light, fade)
				_p(1, -1, light, fade)
				_p(-1, 1, light, fade)
				_p(1, 1, light, fade)
			"heal":
				var count = n if n > 0 else 9
				_circle(4.0 + e * 9.0, color, fade * 0.7, 0.35)
				for i in range(count):
					var ph = fmod(t * 0.9 + _r(i, 1) * 0.5, 1.0)
					var x3 = -11.0 + 22.0 * _r(i, 2) + sin(ph * TAU + float(i)) * 1.2
					var y3 = 12.0 - ph * 28.0
					var a3 = sin(ph * PI) * (1.0 - maxf(0.0, t - 0.8) / 0.2 if not loop else 1.0)
					var c3 = white if i % 3 == 0 else (light if i % 3 == 1 else color)
					_plus(x3, y3, c3, a3)
					if i % 2 == 0:
						_p(x3 - 2, y3, c3, a3 * 0.8)
						_p(x3 + 2, y3, c3, a3 * 0.8)
						_p(x3, y3 - 2, c3, a3 * 0.8)
						_p(x3, y3 + 2, c3, a3 * 0.8)
			"up", "down":
				var sgn = -1.0 if kind == "up" else 1.0
				for i in range(5):
					var ph2 = clampf(t * 1.3 - float(i % 3) * 0.12, 0.0, 1.0)
					var x4 = -10.0 + float(i) * 5.0
					var y4 = (-sgn) * 10.0 + sgn * ph2 * 20.0 + float(i % 2) * 3.0
					var a4 = sin(ph2 * PI)
					# a chevron pointing the way it goes, two rows thick
					for row in range(2):
						var yy = y4 - sgn * float(row) * 3.0
						var cc = white if row == 0 else color
						_p(x4, yy, cc, a4)
						_p(x4 - 1, yy - sgn, cc, a4)
						_p(x4 + 1, yy - sgn, cc, a4)
						_p(x4 - 2, yy - sgn * 2.0, light if row == 0 else dark, a4)
						_p(x4 + 2, yy - sgn * 2.0, light if row == 0 else dark, a4)
			"shield":
				var a5 = (t / 0.15) if t < 0.15 else (1.0 - (t - 0.15) / 0.85)
				_circle(10.0, light, a5, 1.2)
				_circle(9.0, color, a5 * 0.5, 1.2)
				var gy = lerpf(-9.0, 9.0, t)
				_line(-5, gy, -2, gy - 3, white, a5)
				_line(2, gy + 2, 4, gy, white, a5 * 0.7)
			"shards":
				var count2 = n if n > 0 else 14
				for i in range(count2):
					var ang2 = TAU * _r(i, 1)
					var sp = 8.0 + 13.0 * _r(i, 2)
					var x5 = cos(ang2) * sp * e
					var y5 = sin(ang2) * sp * e * 0.8 - 4.0 * e + 12.0 * t * t
					var c5 = white if i % 3 == 0 else (light if i % 3 == 1 else color)
					# A shard is a little wedge that turns as it flies.
					var turn = int(t * 6.0 + float(i)) % 2
					if i % 2 == 0:
						_p(x5, y5, c5, fade, 2.0, 2.0)
						_p(x5 + (2.0 if turn == 0 else -1.0), y5 + 1.0, c5.darkened(0.2), fade)
					else:
						_p(x5, y5, c5, fade, 1.0, 3.0)
						_p(x5 + 1.0, y5 + float(turn), c5.darkened(0.2), fade, 1.0, 2.0)
			"poof":
				# Round puffs of smoke that swell, drift up and thin out.
				for i in range(8):
					var ang3 = TAU * float(i) / 8.0 + 0.4
					var rr = 1.0 + e * (6.0 + 4.0 * _r(i, 1))
					var px3 = cos(ang3) * rr
					var py3 = sin(ang3) * rr * 0.6 - e * 5.0
					var big3 = 2.0 if t < 0.3 else (3.0 if t < 0.6 else 2.0)
					var c3b = white if i % 2 == 0 else light
					var a3b = fade * 0.9
					# a puff: a block with its corners off
					_p(px3 - big3 / 2.0, py3 - big3 / 2.0, c3b, a3b, big3, big3)
					_p(px3 - big3 / 2.0 - 1.0, py3 - big3 / 2.0 + 1.0, c3b, a3b, 1.0, maxf(1.0, big3 - 2.0))
					_p(px3 + big3 / 2.0, py3 - big3 / 2.0 + 1.0, color, a3b, 1.0, maxf(1.0, big3 - 2.0))
					_p(px3 - big3 / 2.0 + 1.0, py3 + big3 / 2.0, color, a3b * 0.8, maxf(1.0, big3 - 2.0), 1.0)
				for i in range(4):
					var a6 = sin(clampf(t * 1.4 - float(i) * 0.12, 0.0, 1.0) * PI)
					_plus(-9.0 + 6.0 * float(i), -9.0 - e * 6.0 + 4.0 * _r(i, 4), white, a6)
			"flame":
				# A real little fire: tongues that lick up from a base, yellow at the root, red at the tip.
				var live2 = sin(minf(1.0, t) * PI)
				for xx in range(-5, 6):
					var lick = 0.5 + 0.5 * sin(t * TAU * 3.0 + float(xx) * 1.7 + _r(xx + 9, 1) * 6.0)
					var tall2 = (1.0 - absf(float(xx)) / 6.5) * (7.0 + 7.0 * lick) * (0.5 + 0.5 * live2)
					for j in range(int(tall2)):
						var share = float(j) / maxf(1.0, tall2)
						var c6 = Color(1.0, 0.95, 0.6) if share < 0.3 else (Color(1.0, 0.66, 0.2) if share < 0.65 else Color(0.9, 0.3, 0.16))
						_p(float(xx), 6.0 - float(j), c6, live2 * (1.0 - share * 0.4))
				for i in range(4):
					var ph3 = fmod(t * 1.5 + _r(i, 3), 1.0)
					_p(-5.0 + 10.0 * _r(i, 2), -4.0 - ph3 * 12.0, Color(1.0, 0.8, 0.3), (1.0 - ph3) * live2)
			"drops":
				for i in range(6):
					var st = float(i) * 0.08
					if t < st:
						continue
					var ph4 = clampf((t - st) / 0.55, 0.0, 1.0)
					var x7 = -8.0 + 16.0 * _r(i, 2)
					var y7 = -6.0 + ph4 * ph4 * 15.0
					var a7b = 1.0 - ph4 * 0.5
					# a drop: a point on top, a round belly, a glint
					_p(x7, y7 - 2.0, color, a7b)
					_p(x7 - 1.0, y7 - 1.0, color, a7b, 2.0, 1.0)
					_p(x7 - 1.0, y7, dark, a7b, 3.0, 2.0)
					_p(x7 - 1.0, y7, color, a7b, 2.0, 1.0)
					_p(x7 - 1.0, y7, light, a7b * 0.9)
					if ph4 > 0.9:
						_p(x7 - 3.0, y7 + 2.0, color, 0.7)
						_p(x7 + 3.0, y7 + 2.0, color, 0.7)
			"gather":
				var count3 = n if n > 0 else 10
				for i in range(count3):
					var ph5 = fmod(t * 1.6 + _r(i, 1), 1.0)
					var ang4 = TAU * _r(i, 2) + ph5 * 1.5
					var rr2 = 15.0 * (1.0 - ph5) + 1.0
					var s5 = 2.0 if ph5 < 0.6 else 1.0
					_p(cos(ang4) * rr2, sin(ang4) * rr2 * 0.8, light if i % 2 == 0 else color, (0.35 + 0.65 * ph5) * (1.0 if loop else fade), s5, s5)
				_plus(0, 0, white, 0.5 + 0.5 * sin(t * TAU * 3.0))
			"rays":
				var count4 = n if n > 0 else 10
				var a7 = sin(minf(1.0, t) * PI)
				for i in range(count4):
					var ang5 = TAU * float(i) / float(count4) + t * 1.6
					var r2 = 5.0 + 3.0 * _r(i, 1)
					var r3 = 14.0 + 5.0 * _r(i, 2)
					_line(cos(ang5) * r2, sin(ang5) * r2, cos(ang5) * r3, sin(ang5) * r3, light if i % 2 == 0 else color, a7 * 0.8)
			"block":
				var a8 = 1.0 - t
				_line(-3, -7, 3, -7, white, a8)
				_line(-3, -7, -5, -2, light, a8)
				_line(3, -7, 5, -2, light, a8)
				_line(-5, -2, 0, 7, color, a8)
				_line(5, -2, 0, 7, color, a8)
				var arm2 = 2.0 + 6.0 * e
				_line(-arm2 - 6.0, 0, -6.0, 0, white, a8)
				_line(-4.0 - arm2 * 0.7, -4.0 - arm2 * 0.7, -5.0, -5.0, white, a8)
				_line(-4.0 - arm2 * 0.7, 4.0 + arm2 * 0.7, -5.0, 5.0, white, a8)
			"stars":
				# Three stars going round a dazed head.
				for i in range(3):
					var ang6 = TAU * (t + float(i) / 3.0)
					var x8 = cos(ang6) * 9.0
					var y8 = sin(ang6) * 3.0
					var front = sin(ang6) > 0.0
					var c8 = color if front else dark
					var a8b = 1.0 if front else 0.7
					_plus(x8, y8, c8, a8b)
					if front:
						_p(x8 - 2, y8, c8, a8b)
						_p(x8 + 2, y8, c8, a8b)
						_p(x8, y8 - 2, c8, a8b)
						_p(x8, y8 + 2, c8, a8b)
						_p(x8, y8, white, 1.0)
			"dust":
				for i in range(6):
					var d3 = -1.0 if i % 2 == 0 else 1.0
					var sz3 = 3.0 if t < 0.35 else (2.0 if t < 0.7 else 1.0)
					var dx3 = d3 * (2.0 + e * (5.0 + float(i) * 1.5))
					var dy3 = -e * (1.0 + float(i % 3) * 1.5)
					_p(dx3 - sz3 / 2.0, dy3 - sz3, light if i % 2 == 0 else color, fade * 0.85, sz3, sz3)
					if sz3 >= 3.0:
						_p(dx3 - sz3 / 2.0 + 1.0, dy3 - sz3 - 1.0, light, fade * 0.7)
			"sparkle":
				var count5 = n if n > 0 else 9
				for i in range(count5):
					var st2 = _r(i, 1) * 0.5
					var ph6 = clampf((t - st2) / 0.5, 0.0, 1.0)
					if t < st2:
						continue
					var a9 = sin(ph6 * PI)
					var x9 = -11.0 + 22.0 * _r(i, 2)
					var y9 = -11.0 + 22.0 * _r(i, 3)
					_p(x9, y9, white, a9)
					if a9 > 0.5:
						_p(x9 - 1, y9, color, a9)
						_p(x9 + 1, y9, color, a9)
						_p(x9, y9 - 1, color, a9)
						_p(x9, y9 + 1, color, a9)
			"orb":
				var wob = sin(t * TAU * 6.0) * 0.5
				for j in range(1, 8):
					var ta = 0.9 - float(j) * 0.11
					_p(-dir.x * float(j) * 1.7, -dir.y * float(j) * 1.7 + wob, color, ta, 2.0 if j < 4 else 1.0, 2.0 if j < 4 else 1.0)
				for y12 in range(-2, 3):
					for x12 in range(-2, 3):
						var d12 = absi(x12) + absi(y12)
						if d12 <= 2:
							_p(x12, y12, white if d12 == 0 else (light if d12 == 1 else color), 1.0)
			"bite":
				# Two rows of teeth closing.
				var gap = 8.0 * (1.0 - minf(1.0, t / 0.35))
				var a10 = fade if t < 0.7 else fade * (1.0 - (t - 0.7) / 0.3)
				for i in range(5):
					var x10 = -6.0 + float(i) * 3.0
					_line(x10, -gap - 5.0, x10 + 1.0, -gap - 1.0, white, a10)
					_line(x10 + 1.0, gap + 5.0, x10, gap + 1.0, white, a10)
					_p(x10 - 1, -gap - 5.0, color, a10)
					_p(x10 + 2, gap + 5.0, color, a10)
			"notes":
				for i in range(3):
					var ph7 = clampf(t * 1.2 - float(i) * 0.15, 0.0, 1.0)
					var x11 = -6.0 + float(i) * 6.0 + sin(ph7 * 6.0) * 1.5
					var y11 = 6.0 - ph7 * 16.0
					var a11 = sin(ph7 * PI)
					_p(x11, y11, color, a11, 2.0, 2.0)
					_line(x11 + 1.0, y11, x11 + 1.0, y11 - 4.0, light, a11)
			"aura":
				# Light rising round a fighter (the effect is centred on its feet).
				var live = sin(minf(1.0, t) * PI)
				_circle(8.0 + 2.0 * sin(t * TAU), color, live * 0.8, 0.3)
				_circle(5.0 + 2.0 * sin(t * TAU), light, live * 0.5, 0.3)
				for i in range(9):
					var ph8 = fmod(t * 1.4 + _r(i, 1), 1.0)
					var x13 = -9.0 + 18.0 * float(i) / 8.0
					var top = -3.0 - ph8 * 24.0
					var a13 = sin(ph8 * PI) * live
					var tall = 3.0 + floor(4.0 * _r(i, 2))
					for j in range(int(tall)):
						_p(x13, top + float(j), white if j == 0 else (light if j < 2 else color), a13 * (1.0 - float(j) / tall))
			_:
				_plus(0, 0, color, fade)


## Motes in the air of a scene, behind the fighters: dust, embers, fireflies,
## rain, snow. Slow and few; it only decorates.
class Ambient extends Control:
	var mode: String = "dust"
	var color: Color = Color(1, 1, 1)
	var count: int = 14
	var _age: float = 0.0
	## A blink of lightning (the storm): seconds left.
	var _bolt: float = 0.0
	var _next_bolt: float = 5.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_age += delta
		if mode == "rain":
			_bolt = maxf(0.0, _bolt - delta)
			_next_bolt -= delta
			if _next_bolt <= 0.0:
				_next_bolt = 6.0 + 7.0 * BattleFx._rand(int(_age * 10.0), 3)
				_bolt = 0.22
		queue_redraw()

	func _draw() -> void:
		var w = size.x
		var h = size.y
		if w <= 0.0 or h <= 0.0:
			return
		var s = 2.0
		for i in range(count):
			var rx = BattleFx._rand(i, 11)
			var ry = BattleFx._rand(i, 13)
			var sp = 0.5 + BattleFx._rand(i, 17)
			var x = 0.0
			var y = 0.0
			var a = 0.5
			var c = color
			match mode:
				"embers":
					y = h - fmod(_age * 22.0 * sp + ry * h, h)
					x = rx * w + sin(_age * 1.3 * sp + float(i)) * 8.0
					a = clampf(y / h, 0.0, 1.0) * 0.8
					if i % 3 == 0:
						c = color.lightened(0.4)
				"fireflies":
					x = rx * w + sin(_age * 0.5 * sp + float(i) * 2.0) * 18.0
					y = h * (0.35 + 0.6 * ry) + cos(_age * 0.7 * sp + float(i)) * 9.0
					a = maxf(0.0, sin(_age * 1.6 * sp + float(i) * 1.7)) * 0.9
				"rain":
					var fall = fmod(_age * 520.0 * (0.8 + 0.4 * sp) + ry * (h + 40.0), h + 40.0) - 20.0
					x = fmod(rx * (w + 60.0) - fall * 0.3 + w, w)
					y = fall
					draw_rect(Rect2(floor(x), floor(y), s, s * 3.0), Color(color.r, color.g, color.b, 0.35))
					continue
				"snow":
					y = fmod(_age * 16.0 * sp + ry * h, h)
					x = rx * w + sin(_age * 0.8 * sp + float(i)) * 10.0
					a = 0.75
				"stars":
					x = rx * w
					y = ry * h * 0.6
					a = maxf(0.0, sin(_age * 1.1 * sp + float(i) * 2.3)) * 0.8
				"leaves":
					x = fmod(_age * 20.0 * sp + rx * (w + 20.0), w + 20.0) - 10.0
					y = fmod(_age * 9.0 * sp + ry * h, h) + sin(_age * 2.0 * sp + float(i)) * 5.0
					a = 0.7
				_:
					x = fmod(_age * 9.0 * sp + rx * (w + 20.0), w + 20.0) - 10.0
					y = h * (0.2 + 0.75 * ry) + sin(_age * 0.6 * sp + float(i)) * 6.0
					a = 0.25 + 0.3 * maxf(0.0, sin(_age * 0.9 * sp + float(i)))
			if a > 0.03:
				draw_rect(Rect2(floor(x / s) * s, floor(y / s) * s, s, s), Color(c.r, c.g, c.b, c.a * a))
		if _bolt > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.28 * (_bolt / 0.22)))


## A red edge that beats while the hero is nearly down.
class Vignette extends Control:
	var color: Color = Color(1.0, 0.2, 0.25)
	var on: bool = false
	var _a: float = 0.0
	var _age: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool) -> void:
		on = v
		set_process(true)

	func _process(delta: float) -> void:
		_age += delta
		_a = move_toward(_a, 1.0 if on else 0.0, delta * 3.0)
		if not on and _a <= 0.0:
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		if _a <= 0.01:
			return
		var beat = 0.55 + 0.45 * maxf(0.0, sin(_age * 4.4))
		var steps = 5
		var band = 6.0
		for i in range(steps):
			var a = _a * beat * 0.34 * (1.0 - float(i) / float(steps))
			var d = float(i) * band
			var c = Color(color.r, color.g, color.b, a)
			draw_rect(Rect2(d, d, size.x - 2.0 * d, band), c)
			draw_rect(Rect2(d, size.y - d - band, size.x - 2.0 * d, band), c)
			draw_rect(Rect2(d, d + band, band, size.y - 2.0 * d - 2.0 * band), c)
			draw_rect(Rect2(size.x - d - band, d + band, band, size.y - 2.0 * d - 2.0 * band), c)
