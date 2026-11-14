class_name HeatmapChart
extends ChartBase

var xp = {}
var today = ""
var weeks = 16
var days = []
var mx = 1.0
var _boxes = []

func setup(xp_by_date: Dictionary, today_key: String, n_weeks: int) -> void:
	xp = xp_by_date
	today = today_key
	weeks = n_weeks
	var start = Dates.add_weeks(Dates.week_key(today), -(weeks - 1))
	days = []
	for c in range(weeks):
		var wk = Dates.add_weeks(start, c)
		for r in range(7):
			days.append(Dates.add_days(wk, r))
	mx = 1.0
	for k in xp:
		mx = maxf(mx, float(xp[k]))
	_boxes = []
	for i in range(7):
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.anti_aliasing = true
		if i < 5:
			sb.bg_color = Charts.HEAT[i]
			sb.border_color = Pal.with_alpha(Pal.LINE, 0.6)
			sb.set_border_width_all(1 if i == 0 else 0)
		elif i == 5:
			# future day
			sb.draw_center = false
			sb.border_color = Pal.with_alpha(Pal.LINE, 0.7)
			sb.set_border_width_all(1)
		else:
			# today's outline
			sb.draw_center = false
			sb.border_color = Pal.TEXT
			sb.set_border_width_all(1)
		_boxes.append(sb)
	custom_minimum_size = Vector2(0, 7 * 15 * 1.3)

func _on_resized() -> void:
	var h = roundf(7 * 15.0 * _k())
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size = Vector2(0, h)
	queue_redraw()

## Scale of the 12 px cell / 3 px gap grid so the 16 weeks fill the width.
func _k() -> float:
	return clampf(size.x / (weeks * 15.0 + 22.0), 0.8, 1.8)

func _level(v: float) -> int:
	if v <= 0.0:
		return 0
	if v < mx * 0.25:
		return 1
	if v < mx * 0.5:
		return 2
	if v < mx * 0.8:
		return 3
	return 4

func _cell_rect(i: int) -> Rect2:
	var k = _k()
	var c = int(i / 7.0)
	var r = i % 7
	return Rect2((22.0 + c * 15.0) * k, r * 15.0 * k, 12.0 * k, 12.0 * k)

func hit_test(pos: Vector2) -> int:
	var k = _k()
	var c = int(floor((pos.x / k - 22.0) / 15.0))
	var r = int(floor(pos.y / (15.0 * k)))
	if c < 0 or c >= weeks or r < 0 or r > 6:
		return -1
	return c * 7 + r

func _draw() -> void:
	var k = _k()
	var labels = ["M", "W", "F"]
	for i in range(3):
		txt(0.0, (i * 2) * 15.0 * k + 12.0 * k - 1.0, labels[i], Pal.MUTED)
	for i in range(days.size()):
		var day = days[i]
		var rect = _cell_rect(i)
		if day > today:
			draw_style_box(_boxes[5], rect)
		else:
			draw_style_box(_boxes[_level(float(xp.get(day, 0)))], rect)
			if day == today:
				draw_style_box(_boxes[6], rect)
		if i == hover:
			draw_rect(rect.grow(1.0), Pal.ACCENT, false, 1.0)
	if hover >= 0 and hover < days.size():
		var d = days[hover]
		draw_tip([
			{"t": Dates.format_date(d, {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true},
			{"t": Xp.fmt_int(xp.get(d, 0)) + " XP"},
		], _cell_rect(hover).get_center().x)
