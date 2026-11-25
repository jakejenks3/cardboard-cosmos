class_name WeekBars
extends ChartBase
## One chunky bar per week: on how many days something was done (or, with
## `unit` "set", how many sets: physical therapy). With a goal a dashed line
## marks it, and the weeks that reached it are the bright ones. The scale is
## the goal or the biggest week, whichever is more, so a count of 21 fits.
##
##   var b = WeekBars.new()
##   b.setup(weeks, Pal.LIFT, 3)          # weeks = [{"week": monday key, "n": days}], oldest first
##   b.setup(weeks, Pal.PT, 9, "set")     # n = sets; the tip says "6 sets"
##
## `WeekBars.Dots` is the same idea for one week: seven squares, Monday to
## Sunday, filled on the days it was done (or partly, by a share), with a
## ring round today.

const H = 104.0
const PXS = 2.0

var _weeks: Array = []
var _color: Color = Pal.ACCENT
var _goal: int = 0
var _unit: String = "day"


func setup(weeks: Array, color: Color, goal: int = 0, unit: String = "day") -> void:
	_weeks = weeks
	_color = color
	_goal = maxi(0, goal)
	_unit = unit
	custom_minimum_size = Vector2(160, H)
	queue_redraw()


func _col_w() -> float:
	return floor(size.x / float(maxi(1, _weeks.size())) / PXS) * PXS


func hit_test(pos: Vector2) -> int:
	var i = int(floor(pos.x / maxf(1.0, _col_w())))
	return i if i >= 0 and i < _weeks.size() and pos.y <= H else -1


func _draw() -> void:
	if _weeks.is_empty():
		return
	var cw = _col_w()
	var label_h = 16.0
	var top_h = 14.0
	var plot_h = H - label_h - top_h - 4.0
	var most = maxi(_goal, 1)
	for w in _weeks:
		most = maxi(most, int(w.n))
	var base_y = top_h + plot_h
	draw_rect(Rect2(0, 0, cw * _weeks.size(), base_y + 2.0), Pal.WELL)
	var font = Kit.font_bold()
	for i in range(_weeks.size()):
		var w = _weeks[i]
		var n = int(w.n)
		var x = float(i) * cw
		var now = i == _weeks.size() - 1
		if i == hover:
			draw_rect(Rect2(x, 0, cw, base_y + 2.0), Pal.with_alpha(_color, 0.14))
		if n > 0:
			var h = maxf(PXS * 2.0, floor(plot_h * float(n) / float(most) / PXS) * PXS)
			var col = _color if (_goal == 0 or n >= _goal) else _color.darkened(0.42)
			var bx = x + PXS * 3.0
			var bw = cw - PXS * 6.0
			draw_rect(Rect2(bx - PXS, base_y - h, bw + PXS * 2.0, h), Pal.OUTLINE)
			draw_rect(Rect2(bx, base_y - h + PXS, bw, h - PXS), col)
			draw_rect(Rect2(bx, base_y - h + PXS, PXS, h - PXS), col.lightened(0.35))
			draw_rect(Rect2(bx + bw - PXS, base_y - h + PXS, PXS, h - PXS), col.darkened(0.25))
			draw_string(font, Vector2(x, base_y - h - 3.0), str(n), HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Pal.TEXT)
		var parts = Dates.parse_date_key(str(w.week))
		var label = "%d/%d" % [int(parts.month), int(parts.day)]
		draw_string(ThemeDB.fallback_font, Vector2(x, H - 3.0), "now" if now else label, HORIZONTAL_ALIGNMENT_CENTER, cw, 10, Pal.ACCENT if now else Pal.MUTED)
	if _goal > 0:
		var gy = floor((base_y - plot_h * float(_goal) / float(most)) / PXS) * PXS
		var gx = 0.0
		while gx < cw * _weeks.size():
			draw_rect(Rect2(gx, gy, PXS * 3.0, PXS), Pal.with_alpha(Pal.GOOD, 0.85))
			gx += PXS * 6.0
	if hover >= 0 and hover < _weeks.size():
		var hw = _weeks[hover]
		var n_hover = int(hw.n)
		var said = "%d %s%s" % [n_hover, _unit, "" if n_hover == 1 else "s"]
		if _goal > 0:
			said += " of %d" % _goal
		draw_tip([{"t": "Week of %s" % Dates.format_date(str(hw.week)), "bold": true}, {"t": said}], (float(hover) + 0.5) * cw)


class Dots:
	extends Control
	## Seven squares for one week, Monday first: filled when done that day
	## (partly, from the bottom, for a share of a day), a ring round today, the
	## days still to come dimmer.

	var _week: Array = []
	var _today: int = -1
	var _color: Color = Pal.ACCENT
	var _px: int = 10

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	## `week`: seven values, Monday first: a bool (done or not) or a number
	## 0..1 (the share of the day done: a third of the square for one set of
	## three); `today_index`: 0 = Monday (-1 for a week that is over).
	func setup(week: Array, today_index: int, color: Color, px: int = 10) -> void:
		_week = week
		_today = today_index
		_color = color
		_px = px
		custom_minimum_size = Vector2(7 * (px + 2) - 2, px)
		queue_redraw()

	## How much of day `i` is done, 0..1.
	func share(i: int) -> float:
		var v = _week[i]
		if typeof(v) == TYPE_BOOL:
			return 1.0 if v else 0.0
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return clampf(float(v), 0.0, 1.0)
		return 0.0

	func _draw() -> void:
		for i in range(mini(7, _week.size())):
			var r = Rect2(i * (_px + 2), 0, _px, _px)
			draw_rect(r, Pal.TEXT if i == _today else Pal.OUTLINE)
			var inner = r.grow(-1.0)
			var got = share(i)
			if got >= 1.0:
				draw_rect(inner, _color)
				draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2.0)), _color.lightened(0.35))
				continue
			draw_rect(inner, Pal.WELL if (_today < 0 or i <= _today) else Pal.with_alpha(Pal.WELL, 0.45))
			if got > 0.0:
				# Part of a day: that share of the square, from the bottom, in
				# whole pixels (at least one, never the whole square).
				var h = clampf(roundf(inner.size.y * got), 1.0, inner.size.y - 1.0)
				draw_rect(Rect2(inner.position.x, inner.end.y - h, inner.size.x, h), _color)
