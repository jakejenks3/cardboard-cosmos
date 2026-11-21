class_name RepLadder
extends ChartBase
## The heaviest weight a lift was done with for at least so many reps, as a
## staircase of bars (LiftTrend.rep_ladder): "1 rep 120 kg", "2-3 reps 110 kg"...
## It shows how strength holds up as the reps go up.
##
##   setup(steps, fmt_w, color)   fmt_w: Callable(kg) -> "120 kg"

const ROW = 26.0
const BAR_H = 16.0

var steps = []
var fmt_w = Callable()
var color = Pal.LIFT
var label_w = 64.0


func setup(the_steps: Array, fmt: Callable, col: Color) -> void:
	steps = the_steps
	fmt_w = fmt
	color = col
	custom_minimum_size = Vector2(0, steps.size() * ROW + 2.0)


static func step_label(st: Dictionary) -> String:
	if int(st.from) == int(st.to):
		return "%d rep%s" % [int(st.from), "" if int(st.from) == 1 else "s"]
	return "%d-%d reps" % [int(st.from), int(st.to)]


func hit_test(pos: Vector2) -> int:
	var i = int(floor(pos.y / ROW))
	return i if i >= 0 and i < steps.size() else -1


func _draw() -> void:
	if steps.is_empty():
		return
	label_w = 0.0
	var top = 0.0
	var value_w = 0.0
	for st in steps:
		label_w = maxf(label_w, text_w(step_label(st), 11, true) + 10.0)
		top = maxf(top, float(st.kg))
		value_w = maxf(value_w, text_w(fmt_w.call(float(st.kg)), 11, true) + 10.0)
	var room = maxf(20.0, size.x - label_w - value_w)
	for i in range(steps.size()):
		var st = steps[i]
		var y = i * ROW + (ROW - BAR_H) / 2.0
		txt(0.0, y + BAR_H - 4.0, step_label(st), Pal.TEXT if i == hover else Pal.MUTED, 0, 11, true)
		var bw = maxf(6.0, roundf(float(st.kg) / top * room))
		var col = color.lerp(Pal.ACCENT, 0.0 if i > 0 else 0.55)
		if i == hover:
			col = col.lightened(0.2)
		draw_rect(Rect2(label_w - 1.0, y - 1.0, bw + 2.0, BAR_H + 2.0), Pal.OUTLINE)
		block(Rect2(label_w, y, bw, BAR_H), col)
		txt(label_w + bw + 6.0, y + BAR_H - 4.0, fmt_w.call(float(st.kg)), Pal.TEXT, 0, 11, true)
	if hover >= 0 and hover < steps.size():
		var h = steps[hover]
		draw_tip([
			{"t": "At least %s" % step_label({"from": h.to, "to": h.to}), "bold": true},
			{"t": "%s · %s" % [fmt_w.call(float(h.kg)), Dates.format_date(str(h.date))], "sw": color},
		], size.x * 0.25)
