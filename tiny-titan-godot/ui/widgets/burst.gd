class_name Burst
extends Control
## A short burst of pixel sparks (claiming a reward, earning something).
## Created by Kit.burst(); frees itself when the sparks have faded.

const LIFE = 0.7
const GRAVITY = 520.0

var _sparks = []
var _age = 0.0


func start(at: Vector2, color: Color, count: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var colors = [color, color.lightened(0.45), Color.WHITE, Pal.ACCENT]
	for i in range(count):
		var ang = rng.randf_range(-PI, 0.0) + rng.randf_range(-0.5, 0.5)
		var speed = rng.randf_range(120.0, 330.0)
		_sparks.append({
			"p": at + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0)),
			"v": Vector2(cos(ang), sin(ang)) * speed,
			"c": colors[rng.randi() % colors.size()],
			"s": float(PixBox.S) * float(rng.randi_range(1, 3)),
		})
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	for s in _sparks:
		s.v.y += GRAVITY * delta
		s.p += s.v * delta
	queue_redraw()


func _draw() -> void:
	var fade = clampf(1.0 - _age / LIFE, 0.0, 1.0)
	for s in _sparks:
		var c: Color = s.c
		c.a = fade
		# Snapped to the pixel grid so the sparks match the art.
		var p = (s.p / float(PixBox.S)).floor() * float(PixBox.S)
		draw_rect(Rect2(p, Vector2(s.s, s.s)), c)
