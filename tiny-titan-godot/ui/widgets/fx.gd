class_name Fx
extends RefCounted
## Small looping effects laid over a control to make it feel alive, all drawn
## as chunky pixels on the same grid as the boxes (PixBox.S):
##
##   Fx.shine(badge)                 a band of light sweeps across, now and then
##   Fx.embers(flame_icon, color)    sparks rise from it and fade
##   Fx.twinkle(tile, color)         little stars blink on it (rare gear)
##   Fx.flicker(icon)                its brightness wavers like a flame
##
## Each returns the node it added (or the tween, for flicker). They never take
## the mouse, stop working while off screen, and go with their control.


static func _over(target: Control, fx: Control, inset: float = 0.0) -> Control:
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.offset_left = inset
	fx.offset_top = inset
	fx.offset_right = -inset
	fx.offset_bottom = -inset
	target.add_child(fx)
	return fx


## A band of light that crosses `target` every `period` seconds (the first one
## after `delay`). The band stays inside the box's rounded corners.
static func shine(target: Control, period: float = 4.5, delay: float = 1.0, strength: float = 0.4) -> Control:
	var s = Shine.new()
	s.period = maxf(1.0, period)
	s.wait = delay
	s.strength = strength
	s.clip_contents = true
	return _over(target, s, float(PixBox.S) * 2.0)


## Sparks that rise from `target` (a flame icon) and fade.
static func embers(target: Control, color = null, count: int = 3) -> Control:
	var e = Embers.new()
	e.color = Pal.ACCENT2 if color == null else color
	e.count = count
	return _over(target, e)


## Little four-point stars that blink on `target`.
static func twinkle(target: Control, color = null, count: int = 2) -> Control:
	var t = Twinkle.new()
	t.color = Color.WHITE if color == null else color
	t.count = count
	return _over(target, t, float(PixBox.S) * 2.0)


## Let a control's brightness waver like a flame. Returns the looping tween.
static func flicker(target: CanvasItem) -> Tween:
	var tw = target.create_tween().set_loops()
	tw.tween_property(target, "modulate", Color(1.16, 1.1, 0.96), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(target, "modulate", Color(0.94, 0.94, 0.94), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(target, "modulate", Color(1.1, 1.05, 0.98), 0.27).set_trans(Tween.TRANS_SINE)
	tw.tween_property(target, "modulate", Color(1, 1, 1), 0.19).set_trans(Tween.TRANS_SINE)
	return tw


class Shine:
	extends Control

	const SWEEP = 0.55
	var period: float = 4.5
	var wait: float = 1.0
	var strength: float = 0.4
	var _age: float = -1.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		if _age < 0.0:
			wait -= delta
			if wait <= 0.0:
				_age = 0.0
				wait = period
			return
		_age += delta
		if _age >= SWEEP:
			_age = -1.0
		queue_redraw()

	func _draw() -> void:
		if _age < 0.0:
			return
		var s = float(PixBox.S)
		var band = maxf(s * 3.0, floor(size.x * 0.16 / s) * s)
		var travel = size.x + band + size.y
		var x0 = floor((-band - size.y + travel * (_age / SWEEP)) / s) * s
		var y = 0.0
		# A slanted band: each row starts a pixel further left than the one above.
		while y < size.y:
			var x = x0 + (size.y - y)
			draw_rect(Rect2(x, y, band, s), Color(1, 1, 1, strength))
			draw_rect(Rect2(x + band + s, y, s, s), Color(1, 1, 1, strength * 0.6))
			y += s


class Embers:
	extends Control

	var color: Color = Color.WHITE
	var count: int = 3
	var _t: float = 0.0
	var _seed: int = 0

	func _ready() -> void:
		_seed = int(get_instance_id() % 997)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s = float(PixBox.S)
		for i in range(count):
			# Each spark lives 0.9 s and starts again somewhere else along the bottom.
			var life = 0.9
			var t = fposmod(_t + float(i) * life / float(count), life) / life
			var gen = int(floor((_t + float(i) * life / float(count)) / life))
			var h = Rng.hash_string("ember:%d:%d:%d" % [_seed, i, gen])
			var x = size.x * (0.3 + 0.4 * float(h % 100) / 100.0) + sin(t * 5.0 + float(i)) * s
			var y = size.y * 0.45 - t * (size.y * 0.75)
			var c = color.lightened(0.3 * (1.0 - t))
			c.a = clampf(1.2 - t * 1.3, 0.0, 1.0)
			var p = (Vector2(x, y) / s).floor() * s
			draw_rect(Rect2(p, Vector2(s, s)), c)


class Twinkle:
	extends Control

	var color: Color = Color.WHITE
	var count: int = 2
	var _t: float = 0.0
	var _seed: int = 0

	func _ready() -> void:
		_seed = int(get_instance_id() % 991)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s = float(PixBox.S)
		for i in range(count):
			var life = 1.5
			var off = float(i) * life / float(count)
			var t = fposmod(_t + off, life) / life
			if t > 0.5:
				continue
			var gen = int(floor((_t + off) / life))
			var h = Rng.hash_string("tw:%d:%d:%d" % [_seed, i, gen])
			var x = floor((size.x - 6.0 * s) * float(h % 97) / 97.0 / s) * s + 3.0 * s
			var y = floor((size.y - 6.0 * s) * float((h >> 8) % 89) / 89.0 / s) * s + 3.0 * s
			# Grows to a four-point star and shrinks again.
			var k = sin(t / 0.5 * PI)
			var c = color
			c.a = k
			draw_rect(Rect2(x, y, s, s), c)
			if k > 0.55:
				var c2 = color
				c2.a = (k - 0.55) * 2.0
				draw_rect(Rect2(x - s, y, s, s), c2)
				draw_rect(Rect2(x + s, y, s, s), c2)
				draw_rect(Rect2(x, y - s, s, s), c2)
				draw_rect(Rect2(x, y + s, s, s), c2)
