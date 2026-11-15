class_name Confetti
extends Control
## A one-shot burst of pixel confetti (port of components/Confetti.tsx).
## Lay it over the area it should cover (it ignores the mouse) and call
## `burst()` for every celebration; bursts stack.

const COLORS = ["#ffc83d", "#ff7a59", "#6fd37a", "#5ad1e6", "#c792ea", "#ffffff", "#ff6b9d"]

## Each particle: {pos: Vector2, vel: Vector2, size, color, rot, vr, life}
var _parts: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Throw a burst from the centre, 40 % down. `intensity` 1.0 = 90 pieces.
func burst(intensity: float = 1.0) -> void:
	var n = TTUtil.jsround(90.0 * intensity)
	var origin = Vector2(size.x / 2.0, size.y * 0.4)
	for i in range(n):
		var a = randf() * TAU
		var sp = 2.0 + randf() * 6.0
		_parts.append({
			"pos": origin,
			"vel": Vector2(cos(a) * sp, sin(a) * sp - 3.0),
			"size": 3.0 + randf() * 4.0,
			"color": Color(COLORS[i % COLORS.size()]),
			"rot": randf() * PI,
			"vr": (randf() - 0.5) * 0.3,
			"life": 60.0 + randf() * 40.0,
		})
	set_process(true)


func _process(delta: float) -> void:
	# The web steps once per animation frame (60 Hz); scale by real time.
	var k = clampf(delta * 60.0, 0.0, 3.0)
	var alive = []
	for p in _parts:
		p.pos += p.vel * k
		p.vel.y += 0.18 * k
		p.vel.x *= pow(0.98, k)
		p.rot += p.vr * k
		p.life -= k
		if p.life > 0.0:
			alive.append(p)
	_parts = alive
	if _parts.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	# Chunky pixels, like the rest of the art: each piece is snapped to a 2 px grid
	# and its spin shows as it flipping between a square and a flat strip.
	for p in _parts:
		var c: Color = p.color
		c.a = minf(1.0, p.life / 20.0)
		var w = maxf(2.0, floor(p.size / 2.0) * 2.0)
		var h = maxf(2.0, floor(absf(cos(p.rot)) * w / 2.0) * 2.0)
		var at = (p.pos / 2.0).floor() * 2.0
		draw_rect(Rect2(at.x - w / 2.0, at.y - h / 2.0, w, h), c)
