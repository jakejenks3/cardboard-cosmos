class_name HeatmapChart
extends ChartBase

var xp = {}
var today = ""
var weeks = 16
var days = []
var mx = 1.0
## Room above and below the grid for the well around it.
const Y0 = 7.0

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
	custom_minimum_size = Vector2(0, 7 * 15 * 1.3 + Y0 * 2.0)

func _on_resized() -> void:
	var h = roundf(7 * 15.0 * _k() + Y0 * 2.0)
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
	return Rect2(floorf((22.0 + c * 15.0) * k), floorf(Y0 + r * 15.0 * k), floorf(12.0 * k), floorf(12.0 * k))

func hit_test(pos: Vector2) -> int:
	var k = _k()
	var c = int(floor((pos.x / k - 22.0) / 15.0))
	var r = int(floor((pos.y - Y0) / (15.0 * k)))
	if c < 0 or c >= weeks or r < 0 or r > 6:
		return -1
	return c * 7 + r

func _draw() -> void:
	var k = _k()
	var first = _cell_rect(0)
	var last = _cell_rect(days.size() - 1)
	draw_well(Rect2(first.position, last.end - first.position).grow(-2.0))
	var labels = ["M", "W", "F"]
	for i in range(3):
		txt(0.0, Y0 + (i * 2) * 15.0 * k + 12.0 * k - 1.0, labels[i], Pal.MUTED)
	for i in range(days.size()):
		var day = days[i]
		var rect = _cell_rect(i)
		if day > today:
			draw_rect(rect, Pal.with_alpha(Pal.LINE, 0.5), false, 1.0)
			continue
		var lvl = _level(float(xp.get(day, 0)))
		var col = Charts.heat(lvl)
		draw_rect(rect, col)
		if lvl > 0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), col.lightened(0.3))
			draw_rect(Rect2(rect.position.x, rect.end.y - 2.0, rect.size.x, 2.0), col.darkened(0.3))
		if day == today:
			draw_rect(rect.grow(1.0), Pal.TEXT, false, 2.0)
		if i == hover:
			draw_rect(rect.grow(1.0), Pal.SECOND, false, 2.0)
	if hover >= 0 and hover < days.size():
		var d = days[hover]
		draw_tip([
			{"t": Dates.format_date(d, {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true},
			{"t": Xp.fmt_int(xp.get(d, 0)) + " XP"},
		], _cell_rect(hover).get_center().x)
