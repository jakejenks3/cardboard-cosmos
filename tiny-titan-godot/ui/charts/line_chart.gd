class_name LineChart
extends ChartBase

const H = 150.0
const PAD_R = 14.0
const PAD_T = 14.0
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
		pad_l = maxf(pad_l, text_w(fmt.call(t)) + 10.0)
	for t in ticks:
		draw_line(Vector2(pad_l, _py(t)), Vector2(size.x - PAD_R, _py(t)), Pal.LINE, 1.0)
		txt(pad_l - 6.0, _py(t) + 4.0, fmt.call(t), Pal.MUTED, 2)
	if trend.size() > 1:
		var tp = PackedVector2Array()
		for i in range(trend.size()):
			tp.append(Vector2(_px(tdx[i]), _py(float(trend[i].y))))
		dashed(tp, Pal.with_alpha(Pal.MUTED, 0.8), 1.5, 4.0, 3.0)
	var pp = PackedVector2Array()
	for i in range(points.size()):
		pp.append(Vector2(_px(dx[i]), _py(float(points[i].y))))
	if points.size() > 1:
		draw_polyline(pp, color, 2.0, true)
	if hover >= 0:
		dashed(PackedVector2Array([Vector2(pp[hover].x, PAD_T), Vector2(pp[hover].x, H - PAD_B)]), Pal.MUTED, 1.0, 2.0, 2.0)
	if points.size() <= 40:
		for i in range(points.size()):
			var r = 4.5 if i == hover else 3.0
			draw_circle(pp[i], r + 1.5, Pal.PANEL, true, -1.0, true)
			draw_circle(pp[i], r, color, true, -1.0, true)
	elif hover >= 0:
		draw_circle(pp[hover], 6.0, Pal.PANEL, true, -1.0, true)
		draw_circle(pp[hover], 4.5, color, true, -1.0, true)
	var last = points[points.size() - 1]
	if hover == -1:
		var lbl = fmt.call(float(last.y))
		txt(maxf(pad_l + text_w(lbl, 11, true), minf(size.x - PAD_R, pp[pp.size() - 1].x)), maxf(12.0, pp[pp.size() - 1].y - 8.0), lbl, Pal.TEXT, 2, 11, true)
	txt(pad_l, H - 6.0, Dates.format_date(points[0].x), Pal.MUTED, 0)
	var mid_i = int(floor(points.size() / 2.0))
	if span >= 21 and points.size() > 2:
		txt(pp[mid_i].x, H - 6.0, Dates.format_date(points[mid_i].x), Pal.MUTED, 1)
	if points.size() > 1:
		txt(size.x - PAD_R, H - 6.0, Dates.format_date(last.x), Pal.MUTED, 2)
	if hover >= 0 and hover < points.size():
		draw_tip([
			{"t": Dates.format_date(points[hover].x, {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true},
			{"t": fmt.call(float(points[hover].y))},
		], pp[hover].x)
