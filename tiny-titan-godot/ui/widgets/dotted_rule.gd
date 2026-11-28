class_name DottedRule
extends Control
## A dotted line across a row (Kit.dotted_rule): 4 px of brown, 4 px of nothing, 2 px high, in the middle.

var color = null


func _draw() -> void:
	var c: Color = Pal.LINE.darkened(0.12) if color == null else color
	var y = floor(size.y / 2.0) - 1.0
	var x = 0.0
	while x < size.x:
		draw_rect(Rect2(x, y, minf(4.0, size.x - x), 2.0), c)
		x += 8.0
