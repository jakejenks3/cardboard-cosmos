class_name SetBlocks
extends ChartBase
## One session's sets as a row of blocks, so the shape of a workout shows at a
## glance (straight sets, a pyramid, a drop set): each block is as tall as the
## set's weight (reps without weight, seconds for a hold) against the lift's
## best ever, with the reps on top. The heaviest set of the day is lit.
##
##   setup(sets, top_value, color, mode, fmt_w)
##     mode: "kg" | "reps" | "sec"   fmt_w: Callable(kg) -> "60 kg" for the tooltip

const H = 50.0
const W = 14.0
const GAP = 4.0
const MAX_SHOWN = 12

var sets = []
var top = 1.0
var color = Pal.LIFT
var mode = "kg"
var fmt_w = Callable()


func setup(the_sets: Array, top_value: float, col: Color, how: String, fmt: Callable) -> void:
	sets = LiftTrend.real_sets(the_sets)
	top = maxf(top_value, 1e-6)
	color = col
	mode = how
	fmt_w = fmt
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS
	var n = mini(sets.size(), MAX_SHOWN)
	custom_minimum_size = Vector2(maxf(W, n * (W + GAP) - GAP + (22.0 if sets.size() > MAX_SHOWN else 0.0)), H)


func _value(one: Dictionary) -> float:
	match mode:
		"sec":
			return float(one.get("holdSec", 0))
		"reps":
			return float(one.get("reps", 0))
	return float(one.get("weightKg", 0))


func hit_test(pos: Vector2) -> int:
	var i = int(floor(pos.x / (W + GAP)))
	if i < 0 or i >= mini(sets.size(), MAX_SHOWN):
		return -1
	return i


func _draw() -> void:
	if sets.is_empty():
		return
	var day_top = 0.0
	for one in sets:
		day_top = maxf(day_top, _value(one))
	var base = H - 2.0
	var room = H - 16.0
	for i in range(mini(sets.size(), MAX_SHOWN)):
		var one = sets[i]
		var v = _value(one)
		var bh = maxf(4.0, roundf(v / top * room))
		var x = i * (W + GAP)
		var lit = v >= day_top - 1e-6
		var col = color if lit else color.darkened(0.35)
		if i == hover:
			col = col.lightened(0.25)
		draw_rect(Rect2(x - 1.0, base - bh - 1.0, W + 2.0, bh + 2.0), Pal.OUTLINE)
		block(Rect2(x, base - bh, W, bh), col)
		var label = str(int(one.reps))
		if mode == "sec":
			label = str(int(one.get("holdSec", 0)))
		txt(x + W / 2.0, base - bh - 4.0, label, Pal.TEXT if lit else Pal.MUTED, 1, 10, true)
	if sets.size() > MAX_SHOWN:
		txt(MAX_SHOWN * (W + GAP) + 2.0, base - 4.0, "+%d" % (sets.size() - MAX_SHOWN), Pal.MUTED, 0, 10, true)
	if hover >= 0 and hover < sets.size():
		var one = sets[hover]
		var said = "%d reps" % int(one.reps)
		if mode == "sec":
			said = "%d × %d s hold" % [int(one.reps), int(one.get("holdSec", 0))]
		elif float(one.get("weightKg", 0)) > 0.0 and fmt_w.is_valid():
			said = "%s × %d" % [fmt_w.call(float(one.weightKg)), int(one.reps)]
		tooltip_text = "Set %d: %s" % [hover + 1, said]
