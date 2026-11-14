class_name WeeklyXpChart
extends ChartBase

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
