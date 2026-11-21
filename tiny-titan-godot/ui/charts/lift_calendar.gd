class_name LiftCalendar
extends ChartBase
## The days a lift was done, as a calendar: a column per week (Monday on top),
## brighter for a bigger day, a gold ring on the days a new best was set and an
## outline on today. Cells come from LiftTrend.calendar.
##
##   setup(cells, weeks, color)

const TOP = 16.0
const LEFT = 16.0
const GAP = 3.0

var cells = []
var weeks = 16
var color = Pal.LIFT
var today = ""


func setup(the_cells: Array, n_weeks: int, col: Color, today_key: String) -> void:
	cells = the_cells
	weeks = n_weeks
	color = col
	today = today_key
	custom_minimum_size = Vector2(0, TOP + 7 * 18.0)


func _cell() -> float:
	return clampf(floorf((size.x - LEFT) / float(weeks)), 10.0, 26.0)


func _on_resized() -> void:
	var h = TOP + 7.0 * _cell() + 2.0
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size = Vector2(0, h)
	queue_redraw()


## Where the grid starts: centred when the cells reach their largest size.
func _x0() -> float:
	return maxf(0.0, floorf((size.x - LEFT - weeks * _cell()) / 2.0))


func _rect(i: int) -> Rect2:
	var c = _cell()
	var w = int(i / 7.0)
	var d = i % 7
	return Rect2(_x0() + LEFT + w * c, TOP + d * c, c - GAP, c - GAP)


func hit_test(pos: Vector2) -> int:
	var c = _cell()
	var w = int(floor((pos.x - _x0() - LEFT) / c))
	var d = int(floor((pos.y - TOP) / c))
	if w < 0 or w >= weeks or d < 0 or d > 6:
		return -1
	return w * 7 + d


func _shade(level: int) -> Color:
	match level:
		0:
			return Pal.WELL.lightened(0.07)
		1:
			return Pal.deep(color).lerp(color, 0.3)
		2:
			return color.darkened(0.2)
		3:
			return color
	return color.lightened(0.35)


func _draw() -> void:
	if cells.is_empty():
		return
	var shown_month = ""
	for w in range(weeks):
		var first = cells[w * 7]
		var month = str(first.date).substr(0, 7)
		if month != shown_month:
			# The month's name over the first week that starts in it (and the first column).
			var day_of = int(str(first.date).substr(8, 2))
			if w == 0 or day_of <= 7:
				txt(_x0() + LEFT + w * _cell(), 11.0, Dates.format_date(str(first.date), {"month": "short"}), Pal.MUTED, 0, 10, true)
			shown_month = month
	var letters = {0: "M", 2: "W", 4: "F", 6: "S"}
	for d in letters:
		txt(_x0(), TOP + d * _cell() + _cell() * 0.5 + 2.0, letters[d], Pal.MUTED, 0, 9, true)
	for i in range(cells.size()):
		var cell = cells[i]
		var r = _rect(i)
		if bool(cell.future):
			draw_rect(r, Pal.with_alpha(Pal.WELL, 0.35))
			continue
		draw_rect(r, _shade(int(cell.level)))
		if int(cell.level) > 0:
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), _shade(int(cell.level)).lightened(0.3))
		if bool(cell.pr):
			draw_rect(r.grow(1.0), Pal.ACCENT, false, 2.0)
		if str(cell.date) == today:
			draw_rect(r.grow(2.0), Pal.TEXT, false, 1.0)
		if i == hover:
			draw_rect(r.grow(1.0), Pal.TEXT, false, 1.0)
	if hover >= 0 and hover < cells.size():
		var c = cells[hover]
		var lines = [{"t": Dates.format_date(str(c.date), {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true}]
		if bool(c.future):
			lines.append({"t": "Still to come"})
		elif int(c.sets) > 0:
			lines.append({"t": "%d set%s" % [int(c.sets), "" if int(c.sets) == 1 else "s"], "sw": _shade(int(c.level))})
		else:
			lines.append({"t": "Not done"})
		if bool(c.pr):
			lines.append({"t": "New best", "sw": Pal.ACCENT})
		draw_tip(lines, _rect(hover).position.x)
