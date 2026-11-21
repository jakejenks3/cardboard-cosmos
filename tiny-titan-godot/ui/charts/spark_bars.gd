class_name SparkBars
extends Control
## A handful of small bars beside an exercise in a list: the last few times
## the lift was done, oldest first, and this time lit at the end, so "going
## up" or "a lighter day" shows before any number is read.
##
##   setup(values, last_color)   values: the lift's number each time (top set,
##                               reps or seconds), this time last

const H = 26.0
const W = 5.0
const GAP = 2.0

var values = []
var last_color = Pal.GOOD


func setup(vals: Array, col: Color) -> void:
	values = vals
	last_color = col
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(maxf(W, values.size() * (W + GAP) - GAP), H)


func _draw() -> void:
	if values.is_empty():
		return
	var mx = 0.0
	var mn = INF
	for v in values:
		mx = maxf(mx, float(v))
		mn = minf(mn, float(v))
	# The lowest bar keeps a third of the height, so small changes still show.
	var lo = mn - maxf((mx - mn) * 0.5, mx * 0.08)
	for i in range(values.size()):
		var v = float(values[i])
		var t = 1.0 if mx - lo <= 1e-9 else (v - lo) / (mx - lo)
		var bh = clampf(roundf(4.0 + t * (H - 6.0)), 3.0, H - 1.0)
		var x = i * (W + GAP)
		var last = i == values.size() - 1
		var col = last_color if last else Pal.with_alpha(Pal.MUTED, 0.45)
		if last:
			draw_rect(Rect2(x - 1.0, H - bh - 1.0, W + 2.0, bh + 1.0), Pal.OUTLINE)
		draw_rect(Rect2(x, H - bh, W, bh), col)
		if last:
			draw_rect(Rect2(x, H - bh, W, 1.0), col.lightened(0.4))
