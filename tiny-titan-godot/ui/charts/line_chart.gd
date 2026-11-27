class_name LineChart
extends ChartBase

const H = 160.0
const PAD_R = 14.0
const PAD_T = 30.0
const PAD_B = 22.0
var points = []
var trend = []
var color = Pal.ACCENT
var fmt = Callable()
var dx = []
var tdx = []
var span = 1
var lo = 0.0
var hi = 1.0
var ticks = []
var pad_l = 44.0

func setup(pts: Array, col: Color, f: Callable, tr: Array) -> void:
	points = pts
	trend = tr
	color = col
	fmt = f
	custom_minimum_size = Vector2(0, H)
	if points.is_empty():
		return
	var x0 = points[0].x
	dx = points.map(func(p): return Dates.days_between(x0, p.x))
	tdx = trend.map(func(p): return Dates.days_between(x0, p.x))
	span = maxi(1, Dates.days_between(x0, points[points.size() - 1].x))
	var ys = points.map(func(p): return float(p.y)) + trend.map(func(p): return float(p.y))
	var mn = ys.min()
	var mx = ys.max()
	if mx - mn < 1e-9:
		mn -= 1.0
		mx += 1.0
	lo = mn - (mx - mn) * 0.12
	hi = mx + (mx - mn) * 0.12
	ticks = [mn, (mn + mx) / 2.0, mx]

func _px(d: int) -> float:
	var inner_w = size.x - pad_l - PAD_R
	if points.size() == 1:
		return pad_l + inner_w / 2.0
	return pad_l + float(d) / float(span) * inner_w

func _py(v: float) -> float:
	var inner_h = H - PAD_T - PAD_B
	return PAD_T + inner_h - ((v - lo) / (hi - lo)) * inner_h

func hit_test(pos: Vector2) -> int:
	if points.is_empty() or pos.y > H:
		return -1
	var best = 0
	var best_d = INF
	for i in range(points.size()):
		var d = absf(_px(dx[i]) - pos.x)
		if d < best_d:
			best_d = d
			best = i
	return best

func _draw() -> void:
	if points.is_empty():
		return
	pad_l = 30.0
	for t in ticks:
		pad_l = maxf(pad_l, text_w(fmt.call(t)) + 14.0)
	var bottom = H - PAD_B
	draw_well(Rect2(pad_l, PAD_T, size.x - pad_l - PAD_R, bottom - PAD_T))
	for t in ticks:
		draw_rect(Rect2(pad_l, roundf(_py(t)), size.x - pad_l - PAD_R, 1.0), Charts.grid())
		txt(pad_l - 9.0, _py(t) + 4.0, fmt.call(t), Pal.MUTED, 2)
	var pp = PackedVector2Array()
	for i in range(points.size()):
		pp.append(Vector2(_px(dx[i]), _py(float(points[i].y))))
	# A soft fill under the line, down to the bottom of the well.
	if points.size() > 1:
		var area = PackedVector2Array(pp)
		area.append(Vector2(pp[pp.size() - 1].x, bottom + 4.0))
		area.append(Vector2(pp[0].x, bottom + 4.0))
		draw_colored_polygon(area, Pal.with_alpha(color, 0.16))
	if trend.size() > 1:
		var tp = PackedVector2Array()
		for i in range(trend.size()):
			tp.append(Vector2(_px(tdx[i]), _py(float(trend[i].y))))
		dashed(tp, Pal.with_alpha(Pal.TEXT, 0.7), 2.0, 5.0, 4.0)
	if points.size() > 1:
		draw_polyline(pp, Pal.OUTLINE, 5.0, true)
		draw_polyline(pp, color, 3.0, true)
	if hover >= 0:
		dashed(PackedVector2Array([Vector2(pp[hover].x, PAD_T), Vector2(pp[hover].x, bottom)]), Pal.MUTED, 1.0, 2.0, 2.0)
	if points.size() <= 40:
		for i in range(points.size()):
			_marker(pp[i], 4.0 if i == hover else 3.0)
	elif hover >= 0:
		_marker(pp[hover], 4.0)
	var last = points[points.size() - 1]
	if hover == -1:
		_marker(pp[pp.size() - 1], 4.0)
		var lbl = fmt.call(float(last.y))
		var lw = text_w(lbl, 11, true) + 10.0
		var lx = clampf(pp[pp.size() - 1].x - lw + 4.0, pad_l, size.x - PAD_R - lw)
		var ly = maxf(2.0, pp[pp.size() - 1].y - 26.0)
		draw_rect(Rect2(lx - 1.0, ly - 1.0, lw + 2.0, 18.0), Pal.OUTLINE)
		draw_rect(Rect2(lx, ly, lw, 16.0), color)
		txt(lx + 5.0, ly + 12.0, lbl, Pal.INK, 0, 11, true)
	txt(pad_l, H - 4.0, Dates.format_date(points[0].x), Pal.MUTED, 0)
	var mid_i = int(floor(points.size() / 2.0))
	if span >= 21 and points.size() > 2:
		txt(pp[mid_i].x, H - 4.0, Dates.format_date(points[mid_i].x), Pal.MUTED, 1)
	if points.size() > 1:
		txt(size.x - PAD_R, H - 4.0, Dates.format_date(last.x), Pal.MUTED, 2)
	if hover >= 0 and hover < points.size():
		draw_tip([
			{"t": Dates.format_date(points[hover].x, {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true},
			{"t": fmt.call(float(points[hover].y))},
		], pp[hover].x)

## A square pixel marker with a dark outline.
func _marker(at: Vector2, r: float) -> void:
	var c = Vector2(roundf(at.x), roundf(at.y))
	draw_rect(Rect2(c.x - r - 1.0, c.y - r - 1.0, r * 2.0 + 2.0, r * 2.0 + 2.0), Pal.OUTLINE)
	draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), color)
	draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, 1.0), color.lightened(0.4))
