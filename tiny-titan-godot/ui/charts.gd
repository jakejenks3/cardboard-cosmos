class_name Charts
extends RefCounted
## Small hand-drawn charts (port of components/charts.tsx): one y-axis, thin
## marks, recessive grid, direct labels, hover tooltips. Colours come from the
## discipline colours in `Pal`.
##
##   Charts.weekly_xp(points)                  stacked weekly XP bars + legend
##   Charts.heatmap(xp_by_date, today)          16-week training calendar
##   Charts.pyramid(counts, max_grade)          climbing send pyramid
##   Charts.line(points, color, fmt, trend)     single-series time line
##   Charts.moving_average(points, n)           centred moving average
##
## A line point is {"x": date key, "y": number}. A week point is
## {"week": monday key, "byDiscipline": {lift, climb, run, ride}, "total"}.

const TICK = 11
const HEAT = [Color("110d22"), Color("5a4a1a"), Color("9a7a22"), Color("d9ab2c"), Color("ffd766")]
const TIP_BG = Color("0f0b1f")
const FLASH = Color("8ad46a")


static func weekly_xp(points: Array) -> Control:
	var c = WeeklyXp.new()
	c.setup(points)
	return c


static func heatmap(xp_by_date: Dictionary, today: String, weeks: int = 16) -> Control:
	var c = Heatmap.new()
	c.setup(xp_by_date, today, weeks)
	return c


## counts = {grade (int): {"sends": n, "flashes": n}}
static func pyramid(counts: Dictionary, max_grade: int) -> Control:
	var c = Pyramid.new()
	c.setup(counts, max_grade)
	return c


## fmt = Callable(y) -> String for the axis, end label and tooltip.
static func line(points: Array, color: Color, fmt: Callable, trend: Array = []) -> Control:
	var c = Line.new()
	c.setup(points, color, fmt, trend)
	return c


## Centred moving average over `n` points (the window shrinks at the ends).
static func moving_average(points: Array, n: int = 5) -> Array:
	var half = int(floor(n / 2.0))
	var out = []
	for i in range(points.size()):
		var a = maxi(0, i - half)
		var b = mini(points.size(), i + half + 1)
		var sum = 0.0
		for j in range(a, b):
			sum += float(points[j].y)
		out.append({"x": points[i].x, "y": sum / float(b - a)})
	return out


static func nice_ceil(v: float) -> float:
	var p = pow(10.0, floor(log(v) / log(10.0) + 1e-9))
	var m = v / p
	var n = 10.0
	if m <= 1.0:
		n = 1.0
	elif m <= 2.0:
		n = 2.0
	elif m <= 5.0:
		n = 5.0
	return n * p


## Axis numbers: 1500 -> "1.5k", 2000 -> "2k", 250 -> "250".
static func fmt_k(v: float) -> String:
	if v >= 1000.0:
		var digits = 1 if fmod(v, 1000.0) != 0.0 else 0
		return Fmt.to_fixed(v / 1000.0, digits) + "k"
	return str(TTUtil.jsround(v))


# ---------------------------------------------------------------------------
# Shared drawing: text, tooltip box, hover tracking
# ---------------------------------------------------------------------------

class ChartBase extends Control:
	## Index of the hovered bar / point / cell, -1 = none.
	var hover = -1

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_exited.connect(_on_exit)
		resized.connect(_on_resized)

	func _on_resized() -> void:
		queue_redraw()

	func _on_exit() -> void:
		if hover != -1:
			hover = -1
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
			var h = hit_test(event.position)
			if h != hover:
				hover = h
				queue_redraw()

	## Override: which element is under `pos` (local), -1 for none.
	func hit_test(_pos: Vector2) -> int:
		return -1

	func text_w(s: String, fs: int = Charts.TICK, bold: bool = false) -> float:
		var f = Kit.font_bold() if bold else get_theme_default_font()
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	## align: 0 = left of x, 1 = centred on x, 2 = right of x (ends at x). `base` is the baseline.
	func txt(x: float, base: float, s: String, color: Color = Pal.MUTED, align: int = 0, fs: int = Charts.TICK, bold: bool = false) -> void:
		var f = Kit.font_bold() if bold else get_theme_default_font()
		var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 = x
		if align == 1:
			x0 = x - w / 2.0
		elif align == 2:
			x0 = x - w
		draw_string(f, Vector2(x0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	## Tooltip box. lines = [{"t": text, "bold": bool, "sw": swatch Color (optional)}].
	## Placed in the top corner away from `anchor_x` (the hovered element).
	func draw_tip(lines: Array, anchor_x: float) -> void:
		var w = 0.0
		for l in lines:
			var lw = text_w(l.t, 11, l.get("bold", false))
			if l.get("sw") != null:
				lw += 13.0
			w = maxf(w, lw)
		var bw = w + 16.0
		var bh = lines.size() * 15.0 + 9.0
		var x = size.x - bw - 4.0
		if anchor_x > size.x * 0.55:
			x = 40.0
		var r = Rect2(x, 4.0, bw, bh)
		draw_style_box(Kit.sbox(Charts.TIP_BG, 8, Pal.LINE, 1, 0, 0), r)
		var y = 4.0 + 5.0 + 11.0
		for l in lines:
			var tx = x + 8.0
			if l.get("sw") != null:
				draw_rect(Rect2(tx, y - 9.0, 9.0, 9.0), l.sw)
				tx += 13.0
			txt(tx, y, l.t, Pal.TEXT, 0, 11, l.get("bold", false))
			y += 15.0

	## A dashed polyline (continuous dash pattern across segments).
	func dashed(pts: PackedVector2Array, color: Color, width: float, dash: float, gap_len: float) -> void:
		var on = true
		var left = dash
		for i in range(pts.size() - 1):
			var a = pts[i]
			var b = pts[i + 1]
			var seg = a.distance_to(b)
			if seg <= 0.0001:
				continue
			var t = 0.0
			while t < seg:
				var stp = minf(left, seg - t)
				if on:
					draw_line(a.lerp(b, t / seg), a.lerp(b, (t + stp) / seg), color, width, true)
				t += stp
				left -= stp
				if left <= 0.0001:
					on = not on
					left = dash if on else gap_len


# ---------------------------------------------------------------------------
# Weekly XP: stacked bars by discipline
# ---------------------------------------------------------------------------

class WeeklyXp extends ChartBase:
	const PLOT_H = 150.0
	const PAD_L = 34.0
	const PAD_R = 8.0
	const PAD_T = 10.0
	const PAD_B = 22.0
	var data = []
	var used = []
	var nice_max = 1.0

	func setup(points: Array) -> void:
		data = points
		var mx = 1.0
		for p in data:
			mx = maxf(mx, float(p.total))
		nice_max = Charts.nice_ceil(mx)
		used = []
		for d in TT.DISCIPLINES:
			for p in data:
				if float(p.byDiscipline[d]) > 0.0:
					used.append(d)
					break
		custom_minimum_size = Vector2(0, PLOT_H + (22.0 if used.size() >= 2 else 0.0))

	func _slot() -> float:
		return (size.x - PAD_L - PAD_R) / float(maxi(1, data.size()))

	func _y(v: float) -> float:
		var inner_h = PLOT_H - PAD_T - PAD_B
		return PAD_T + inner_h - (v / nice_max) * inner_h

	func hit_test(pos: Vector2) -> int:
		if data.is_empty() or pos.y > PLOT_H or pos.x < PAD_L or pos.x > size.x - PAD_R:
			return -1
		return clampi(int(floor((pos.x - PAD_L) / _slot())), 0, data.size() - 1)

	func _draw() -> void:
		var n = data.size()
		if n == 0:
			return
		var empty = nice_max <= 1.0 and float(data.map(func(p): return p.total).max()) <= 0.0
		var ticks = [0.0] if empty else [0.0, nice_max / 2.0, nice_max]
		for t in ticks:
			draw_line(Vector2(PAD_L, _y(t)), Vector2(size.x - PAD_R, _y(t)), Pal.LINE, 1.0)
			txt(PAD_L - 6.0, _y(t) + 4.0, Charts.fmt_k(t), Pal.MUTED, 2)
		var slot = _slot()
		var bar_w = maxf(6.0, slot - 6.0)
		for i in range(n):
			var p = data[i]
			var x = PAD_L + i * slot + (slot - bar_w) / 2.0
			var segs = []
			for d in TT.DISCIPLINES:
				if float(p.byDiscipline[d]) > 0.0:
					segs.append(d)
			var acc = 0.0
			var alpha = 1.0 if (hover == -1 or hover == i) else 0.45
			for k in range(segs.size()):
				var v = float(p.byDiscipline[segs[k]])
				var y0 = _y(acc + v)
				var h = maxf(0.0, _y(acc) - y0)
				acc += v
				var top = k == segs.size() - 1
				var col = Pal.with_alpha(Pal.disc(segs[k]), alpha)
				if top:
					var sb = StyleBoxFlat.new()
					sb.bg_color = col
					sb.corner_radius_top_left = 3
					sb.corner_radius_top_right = 3
					draw_style_box(sb, Rect2(x, y0, bar_w, h))
				else:
					draw_rect(Rect2(x, y0 + 1.0, bar_w, maxf(0.0, h - 1.0)), col)
			if i == n - 1 or i % 4 == 0:
				var lbl = Dates.format_date(p.week)
				var cx = clampf(x + bar_w / 2.0, PAD_L + text_w(lbl) / 2.0, size.x - text_w(lbl) / 2.0)
				txt(cx, PLOT_H - 6.0, lbl, Pal.MUTED, 1)
		if empty:
			txt(PAD_L + (size.x - PAD_L - PAD_R) / 2.0, PLOT_H / 2.0, "No XP in the last 12 weeks yet", Pal.MUTED, 1, 12)
		# Legend
		if used.size() >= 2:
			var lx = 0.0
			var ly = PLOT_H + 14.0
			for d in used:
				draw_rect(Rect2(lx, ly - 9.0, 9.0, 9.0), Pal.disc(d))
				var name_text = TT.DISCIPLINE_META[d].name
				txt(lx + 13.0, ly, name_text, Pal.MUTED)
				lx += 13.0 + text_w(name_text) + 12.0
		if hover >= 0 and hover < n:
			var hp = data[hover]
			var lines = [
				{"t": "Week of " + Dates.format_date(hp.week), "bold": true},
				{"t": Xp.fmt_int(hp.total) + " XP"},
			]
			for d in TT.DISCIPLINES:
				if float(hp.byDiscipline[d]) > 0.0:
					lines.append({"t": "%s: %s" % [TT.DISCIPLINE_META[d].name, Xp.fmt_int(hp.byDiscipline[d])], "sw": Pal.disc(d)})
			draw_tip(lines, PAD_L + (hover + 0.5) * slot)


# ---------------------------------------------------------------------------
# Heatmap: one column per week (Monday on top), ending with this week
# ---------------------------------------------------------------------------

class Heatmap extends ChartBase:
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

	func _k() -> float:
		return minf(1.3, size.x / (weeks * 15.0 + 22.0))

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


# ---------------------------------------------------------------------------
# Send pyramid: one bar per grade, hardest on top; the lighter end = flashes
# ---------------------------------------------------------------------------

class Pyramid extends ChartBase:
	const ROW = 18.0
	const BAR_H = 12.0
	var grades = []
	var counts = {}
	var mx = 1.0

	func setup(c: Dictionary, max_grade: int) -> void:
		counts = c
		grades = []
		var g = maxi(-1, max_grade)
		while g >= -1:
			grades.append(g)
			g -= 1
		mx = 1.0
		for gr in grades:
			mx = maxf(mx, _total(gr))
		custom_minimum_size = Vector2(0, grades.size() * ROW)

	func _entry(g: int) -> Dictionary:
		return counts.get(g, {"sends": 0, "flashes": 0})

	func _total(g: int) -> float:
		var e = _entry(g)
		return float(e.sends + e.flashes)

	func hit_test(pos: Vector2) -> int:
		var i = int(floor(pos.y / ROW))
		return i if i >= 0 and i < grades.size() else -1

	func _draw() -> void:
		var bar_x = 34.0 + 8.0
		var bar_w = maxf(10.0, size.x - bar_x - 8.0 - 30.0)
		for i in range(grades.size()):
			var g = grades[i]
			var e = _entry(g)
			var total = _total(g)
			var y = i * ROW + (ROW - BAR_H) / 2.0
			var base = y + BAR_H - 1.0
			txt(34.0, base, Xp.grade_label(g), Pal.TEXT if hover == -1 or hover == i else Pal.MUTED, 2, 12, true)
			var well = StyleBoxFlat.new()
			well.bg_color = Charts.HEAT[0]
			well.set_corner_radius_all(4)
			draw_style_box(well, Rect2(bar_x, y, bar_w, BAR_H))
			var fw = maxf(2.0, total / mx * bar_w)
			var fill = StyleBoxFlat.new()
			fill.bg_color = Pal.CLIMB
			fill.set_corner_radius_all(4)
			draw_style_box(fill, Rect2(bar_x, y, fw, BAR_H))
			if total > 0.0 and e.flashes > 0:
				var flw = float(e.flashes) / total * fw
				var fl = StyleBoxFlat.new()
				fl.bg_color = Charts.FLASH
				fl.set_corner_radius_all(4)
				draw_style_box(fl, Rect2(bar_x + fw - flw, y, flw, BAR_H))
			txt(bar_x + bar_w + 8.0, base, Xp.fmt_int(total), Pal.MUTED, 0, 12)
		if hover >= 0 and hover < grades.size():
			var g2 = grades[hover]
			var e2 = _entry(g2)
			draw_tip([
				{"t": Xp.grade_label(g2), "bold": true},
				{"t": "%s sends" % Xp.fmt_int(e2.sends), "sw": Pal.CLIMB},
				{"t": "%s flashes" % Xp.fmt_int(e2.flashes), "sw": Charts.FLASH},
			], size.x)


# ---------------------------------------------------------------------------
# Line chart: 2 px line, ringed dots, end label, crosshair tooltip
# ---------------------------------------------------------------------------

class Line extends ChartBase:
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
