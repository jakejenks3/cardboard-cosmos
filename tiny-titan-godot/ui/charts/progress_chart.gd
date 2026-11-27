class_name ProgressChart
extends ChartBase
## One lift over time, like a stock chart: the line is the number the lift is
## about (top set, estimated strength, reps or seconds held), the bars along
## the bottom are how much work each day was (weight moved, reps or seconds),
## a crown marks the day of the best ever and gold squares every new best on
## the way there. The phone note's sets (not in the log yet) are a green point.
##
##   setup(points, opts)
##     points: [{"x": date, "y": value, "bar": work (optional), "tip": a line
##              for the tooltip (optional), "note": true for the note's sets,
##              "dot": a Color for its marker (optional: a band's colour)}]
##     opts:   {"color", "fmt": Callable(value) -> String, "bar_fmt": Callable,
##              "records": indexes of new bests (LiftTrend.record_points),
##              "ticks": the values the axis names (optional: else the lowest,
##              the middle and the highest; bands give their levels)}

const H = 196.0
const PAD_R = 16.0
const PAD_T = 34.0
const PAD_B = 22.0
## Part of the plot the work bars may fill, from the bottom.
const BAR_SHARE = 0.26

var points = []
var color = Pal.LIFT
var fmt = Callable()
var bar_fmt = Callable()
var records = []
var dx = []
var span = 1
var lo = 0.0
var hi = 1.0
var ticks = []
var bar_max = 0.0
var pad_l = 44.0
var best_i = -1


func setup(pts: Array, opts: Dictionary = {}) -> void:
	points = pts
	color = opts.get("color", Pal.LIFT)
	fmt = opts.get("fmt", func(v): return TTUtil.num_str(float(v)))
	bar_fmt = opts.get("bar_fmt", Callable())
	records = opts.get("records", [])
	custom_minimum_size = Vector2(0, H)
	if points.is_empty():
		return
	var x0 = str(points[0].x)
	dx = points.map(func(p): return Dates.days_between(x0, str(p.x)))
	span = maxi(1, Dates.days_between(x0, str(points[points.size() - 1].x)))
	var ys = points.map(func(p): return float(p.y))
	var mn = ys.min()
	var mx = ys.max()
	best_i = ys.rfind(mx)
	if mx - mn < 1e-9:
		mn -= 1.0
		mx += 1.0
	# Room under the line for the work bars.
	lo = mn - (mx - mn) * 0.45
	hi = mx + (mx - mn) * 0.1
	ticks = [mn, (mn + mx) / 2.0, mx]
	var own_ticks = opts.get("ticks", [])
	if own_ticks is Array and not own_ticks.is_empty():
		ticks = own_ticks
	bar_max = 0.0
	for p in points:
		bar_max = maxf(bar_max, float(p.get("bar", 0.0)))


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
	var plot = Rect2(pad_l, PAD_T, size.x - pad_l - PAD_R, bottom - PAD_T)
	draw_well(plot)
	for t in ticks:
		draw_rect(Rect2(pad_l, roundf(_py(t)), plot.size.x, 1.0), Charts.grid())
		txt(pad_l - 9.0, _py(t) + 4.0, fmt.call(t), Pal.MUTED, 2)
	# The work bars, along the bottom of the well.
	if bar_max > 0.0:
		# As wide as the points leave room for: thin bars read as noise.
		var bw = clampf(floorf(plot.size.x / float(points.size()) * 0.55), 3.0, 12.0)
		for i in range(points.size()):
			var v = float(points[i].get("bar", 0.0))
			if v <= 0.0:
				continue
			var bh = maxf(2.0, roundf(v / bar_max * plot.size.y * BAR_SHARE))
			var bc = Pal.GOOD if bool(points[i].get("note", false)) else Pal.with_alpha(Pal.MUTED, 0.38)
			if i == hover:
				bc = Pal.with_alpha(Pal.TEXT, 0.6)
			draw_rect(Rect2(roundf(_px(dx[i]) - bw / 2.0), bottom - bh, roundf(bw), bh), bc)
	var pp = PackedVector2Array()
	for i in range(points.size()):
		pp.append(Vector2(_px(dx[i]), _py(float(points[i].y))))
	if points.size() > 1:
		var area = PackedVector2Array(pp)
		area.append(Vector2(pp[pp.size() - 1].x, bottom))
		area.append(Vector2(pp[0].x, bottom))
		draw_colored_polygon(area, Pal.with_alpha(color, 0.13))
		draw_polyline(pp, Pal.OUTLINE, 5.0, true)
		draw_polyline(pp, color, 3.0, true)
	if hover >= 0:
		dashed(PackedVector2Array([Vector2(pp[hover].x, PAD_T), Vector2(pp[hover].x, bottom)]), Pal.MUTED, 1.0, 2.0, 2.0)
	var marks = {}
	for i in records:
		marks[int(i)] = true
	var dense = points.size() > 40
	for i in range(points.size()):
		var note = bool(points[i].get("note", false))
		if note:
			_marker(pp[i], 5.0, Pal.GOOD)
		elif marks.has(i):
			_marker(pp[i], 4.0 if i == hover else 3.0, Pal.ACCENT)
		elif not dense or i == hover:
			var dot = points[i].get("dot")
			_marker(pp[i], 4.0 if i == hover else 3.0, dot if dot is Color else color)
	# The crown over the best day ever (when it was beaten by nothing after it).
	if best_i > 0 and marks.has(best_i):
		var crown = Icons.tex("crown", Pal.ACCENT, 1)
		if crown != null:
			var at = Vector2(roundf(pp[best_i].x - crown.get_width() / 2.0), roundf(pp[best_i].y - crown.get_height() - 7.0))
			at.y = maxf(at.y, PAD_T - 14.0)
			draw_texture(crown, at)
	# The newest point's value, on a flag.
	if hover == -1:
		var li = points.size() - 1
		var lbl = fmt.call(float(points[li].y))
		var lw = text_w(lbl, 11, true) + 10.0
		var lx = clampf(pp[li].x - lw + 4.0, pad_l, size.x - PAD_R - lw)
		var ly = maxf(2.0, pp[li].y - 30.0)
		var flag = Pal.GOOD if bool(points[li].get("note", false)) else color
		draw_rect(Rect2(lx - 1.0, ly - 1.0, lw + 2.0, 18.0), Pal.OUTLINE)
		draw_rect(Rect2(lx, ly, lw, 16.0), flag)
		txt(lx + 5.0, ly + 12.0, lbl, Pal.INK, 0, 11, true)
	txt(pad_l, H - 4.0, Dates.format_date(str(points[0].x)), Pal.MUTED, 0)
	if span >= 21 and points.size() > 2:
		var mid_i = int(floor(points.size() / 2.0))
		txt(pp[mid_i].x, H - 4.0, Dates.format_date(str(points[mid_i].x)), Pal.MUTED, 1)
	if points.size() > 1:
		txt(size.x - PAD_R, H - 4.0, Dates.format_date(str(points[points.size() - 1].x)), Pal.MUTED, 2)
	if hover >= 0 and hover < points.size():
		var p = points[hover]
		var lines = [
			{"t": ("In your note · " if bool(p.get("note", false)) else "") + Dates.format_date(str(p.x), {"weekday": "short", "month": "short", "day": "numeric"}), "bold": true},
			{"t": fmt.call(float(p.y)), "sw": color},
		]
		if str(p.get("tip", "")) != "":
			lines.append({"t": str(p.tip)})
		if bar_fmt.is_valid() and float(p.get("bar", 0.0)) > 0.0:
			lines.append({"t": bar_fmt.call(float(p.bar)), "sw": Pal.with_alpha(Pal.MUTED, 0.6)})
		if marks.has(hover):
			lines.append({"t": "New best", "sw": Pal.ACCENT})
		draw_tip(lines, pp[hover].x)


## A square pixel marker with a dark outline and a lit top row.
func _marker(at: Vector2, r: float, col: Color) -> void:
	var c = Vector2(roundf(at.x), roundf(at.y))
	draw_rect(Rect2(c.x - r - 1.0, c.y - r - 1.0, r * 2.0 + 2.0, r * 2.0 + 2.0), Pal.OUTLINE)
	draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), col)
	draw_rect(Rect2(c.x - r, c.y - r, r * 2.0, 1.0), col.lightened(0.4))
