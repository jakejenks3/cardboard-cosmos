class_name DoseWeeks
extends Control
## One muscle's sets a week over the last weeks, as bars against its target band (TrainingReport.weekly_sets).
## The band between the least and the most is shaded; a bar is green inside it, the muscle's colour under it,
## orange over it. The newest week is on the right. Drawn in whole pixels.

var values: Array = []
var least: float = 0.0
var most: float = 0.0
var color: Color = Color.WHITE
const H = 36


func setup(vals: Array, lo: float, hi: float, col: Color) -> void:
	values = vals
	least = lo
	most = hi
	color = col
	custom_minimum_size = Vector2(120, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w = size.x
	var h = size.y
	var top = 0.0
	for v in values:
		top = maxf(top, float(v))
	top = maxf(top, most if most > 0.0 else least)
	top = maxf(top * 1.1, 1.0)
	var y_of = func(v: float) -> float: return floor(h - 1.0 - (h - 2.0) * clampf(v / top, 0.0, 1.0))
	draw_rect(Rect2(0, 0, w, h), Pal.WELL)
	if least > 0.0 or most > 0.0:
		var y1 = y_of.call(most if most > 0.0 else least)
		var y0 = y_of.call(least)
		draw_rect(Rect2(0, y1, w, maxf(1.0, y0 - y1)), Pal.with_alpha(Pal.GOOD, 0.16))
		draw_rect(Rect2(0, y0, w, 1), Pal.with_alpha(Pal.GOOD, 0.6))
	var n = maxi(1, values.size())
	var slot = floor(w / float(n))
	var bw = maxf(2.0, slot - 3.0)
	for i in range(values.size()):
		var v = float(values[i])
		var x = floor(i * slot + (slot - bw) / 2.0)
		var y = y_of.call(v)
		var col = color
		if least > 0.0 or most > 0.0:
			if v < least - 0.01:
				col = Pal.with_alpha(color, 0.75)
			elif most > 0.0 and v > most + 0.01:
				col = Pal.ACCENT2
			else:
				col = Pal.GOOD
		if i == values.size() - 1:
			col = col.lightened(0.15)
		if v > 0.0:
			draw_rect(Rect2(x, y, bw, h - 1.0 - y), col)
