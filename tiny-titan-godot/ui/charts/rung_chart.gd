class_name RungChart
extends ChartBase
## A lift's progress the way it is earned: every day is a bar of the reps done at its working weight, and
## the bars stand in RUNGS, one band per weight (or band, or hold), labelled at the top. One more rep at the
## same weight is a taller bar; a step heavier starts a new rung (gold label with an arrow, a gold bar). A
## bar is green when that day beat the one before (with a gold top when it beat every day before), orange
## when it fell short, grey when it matched. A gold star and a gold number: a REP RECORD that day (more reps
## in a set at a weight than ever before: LiftProgress.rep_records). A dashed bar at the end is next time's aim. (LiftProgress; 2026-11-27.)
##
##   setup(rows, opts)
##     rows: LiftProgress.days (oldest first)
##     opts: {"fmt_rung": Callable(rung) -> String, "next": {"rung", "reps"} or null, "tips": [String per row]}

const H = 200.0
const PAD_T = 40.0
const PAD_B = 20.0
const PAD_X = 8.0
const NUM_H = 13.0

var rows = []
var fmt_rung = Callable()
var next = null
var tips = []
var lo = 0.0
var hi = 1.0
var _bars = []  # [Rect2] per row (and the aim last)


var levels = []  # the distinct rungs, lowest first


func setup(p_rows: Array, opts: Dictionary = {}) -> void:
	rows = p_rows
	fmt_rung = opts.get("fmt_rung", func(r): return TTUtil.num_str(float(r)))
	next = opts.get("next", null)
	tips = opts.get("tips", [])
	custom_minimum_size = Vector2(0, H)
	var mn = INF
	var mx = 0.0
	levels = []
	for i in range(_count()):
		var reps = _reps_at(i)
		mn = minf(mn, reps)
		mx = maxf(mx, reps)
		var r = _rung_at(i)
		if not levels.any(func(l): return absf(float(l) - r) <= LiftProgress.EPS):
			levels.append(r)
	levels.sort()
	if mn == INF:
		mn = 0.0
	lo = mn
	hi = mx
	queue_redraw()


func _reps_at(i: int) -> float:
	return float(rows[i].key.reps) if i < rows.size() else float(next.reps)


## Where a day stands, 0..1 of the plot's height: a STAIRCASE. Each weight is a step (the heavier, the higher)
## and the reps fill the day's bar within its step, so a rep more makes it taller and a heavier weight lifts it
## a whole step. With one weight the steps are the reps alone.
func _height_of(i: int) -> float:
	var r = _rung_at(i)
	var idx = 0
	for k in range(levels.size()):
		if absf(float(levels[k]) - r) <= LiftProgress.EPS:
			idx = k
	var fill = 1.0 if hi - lo <= 1e-6 else (_reps_at(i) - lo) / (hi - lo)
	var n = maxi(1, levels.size())
	if n == 1:
		return 0.2 + 0.8 * fill
	# A step is a share of the height; the reps fill a little more than half of it.
	return (float(idx) + 0.35 + 0.65 * fill) / float(n)


func _count() -> int:
	return rows.size() + (1 if next != null else 0)


func _layout() -> Array:
	var n = _count()
	var inner = size.x - 2.0 * PAD_X
	var gap = 3.0 if n <= 20 else 2.0
	var w = clampf((inner - gap * (n - 1)) / float(maxi(1, n)), 3.0, 30.0)
	var used = n * w + (n - 1) * gap
	var x0 = PAD_X + maxf(0.0, (inner - used) / 2.0)
	var plot_h = H - PAD_T - PAD_B - NUM_H
	var out = []
	for i in range(n):
		var bh = roundf(clampf(_height_of(i) * plot_h, 4.0, plot_h))
		out.append(Rect2(roundf(x0 + i * (w + gap)), H - PAD_B - bh, roundf(w), bh))
	return out


func hit_test(pos: Vector2) -> int:
	for i in range(_bars.size()):
		var r = _bars[i]
		if pos.x >= r.position.x - 1.0 and pos.x <= r.end.x + 1.0:
			return i
	return -1


func _bar_color(r: Dictionary) -> Color:
	if bool(r.rung_up):
		return Pal.ACCENT
	match int(r.beat):
		1:
			return Pal.GOOD
		-1:
			return Pal.ACCENT2
	return Pal.with_alpha(Pal.MUTED, 0.7)


func _draw() -> void:
	draw_well(Rect2(PAD_X - 2.0, 4.0, size.x - 2.0 * PAD_X + 4.0, H - 8.0))
	if rows.is_empty():
		return
	_bars = _layout()
	var n = _count()
	# The rungs: a band behind each run of days at one weight, its label at the top. A label may run past
	# its band; labels never overlap: each new (gold) rung's first, then the newest rung's, then the rest.
	var start = 0
	var band_i = 0
	var labels = []
	while start < n:
		var rung = _rung_at(start)
		var end = start
		while end + 1 < n and absf(_rung_at(end + 1) - rung) <= LiftProgress.EPS:
			end += 1
		var left = _bars[start].position.x - 1.0
		var right = _bars[end].end.x + 1.0
		var band = Rect2(left, PAD_T - 2.0, right - left, H - PAD_B - PAD_T + 2.0)
		draw_rect(band, Pal.with_alpha(Pal.TEXT, 0.05 if band_i % 2 == 0 else 0.1))
		var is_next = start >= rows.size()
		var up = start > 0 and (is_next or bool(rows[start].rung_up))
		var label = str(fmt_rung.call(rung))
		var col = Pal.ACCENT if up else Pal.MUTED
		if is_next:
			col = Pal.SECOND
		var lw = text_w(label, 10, true) + (9.0 if up else 0.0)
		var prio = 3 if up else (2 if end == n - 1 else 1)
		# Over its band from the left, else ending at its band's right edge.
		var xs = [clampf(left, PAD_X, size.x - PAD_X - lw), clampf(right - lw, PAD_X, size.x - PAD_X - lw)]
		labels.append({"xs": xs, "w": lw, "label": label, "col": col, "up": up, "prio": prio, "order": band_i})
		start = end + 1
		band_i += 1
	labels.sort_custom(func(a, b): return int(a.prio) > int(b.prio) or (int(a.prio) == int(b.prio) and int(a.order) > int(b.order)))
	var taken = []
	for lb in labels:
		var x0 = -1.0
		for cand in lb.xs:
			var c0 = float(cand)
			var c1 = c0 + float(lb.w)
			if not taken.any(func(t): return c0 < float(t[1]) + 6.0 and c1 > float(t[0]) - 6.0):
				x0 = c0
				break
		if x0 < 0.0:
			continue
		taken.append([x0, x0 + float(lb.w)])
		var lx2 = x0
		if bool(lb.up):
			_arrow(Vector2(lx2 + 3.0, PAD_T - 14.0), lb.col)
			lx2 += 9.0
		txt(lx2, PAD_T - 8.0, str(lb.label), lb.col, 0, 10, true)
	# The bars, the reps over each (when there is room).
	for i in range(n):
		var r = _bars[i]
		if i < rows.size():
			var row = rows[i]
			var col = _bar_color(row)
			block(r, col if i != hover else col.lightened(0.2))
			if bool(row.record) and not bool(row.rung_up):
				# A best ever: a gold top on its bar.
				draw_rect(Rect2(r.position.x, r.position.y, r.size.x, minf(4.0, r.size.y)), Pal.ACCENT)
			if i == rows.size() - 1:
				draw_rect(r.grow(1.0), Pal.OUTLINE, false, 1.0)
			var rep_rec = not (row.get("rep_records", []) as Array).is_empty()
			if r.size.x >= 11.0:
				var ncol = Pal.ACCENT if rep_rec else (Pal.TEXT if int(row.beat) == 1 or bool(row.record) else Pal.MUTED)
				txt(r.get_center().x, r.position.y - 3.0, str(int(row.key.reps)), ncol, 1, 10, true)
			if rep_rec:
				# A rep record: a gold star over the bar's number.
				_star(Vector2(r.get_center().x, r.position.y - (17.0 if r.size.x >= 11.0 else 6.0)))
		else:
			# Next time's aim: a dashed outline.
			var pts = PackedVector2Array([r.position + Vector2(0, r.size.y), r.position, Vector2(r.end.x, r.position.y), r.end])
			dashed(pts, Pal.SECOND, 2.0, 4.0, 3.0)
			if r.size.x >= 11.0:
				txt(r.get_center().x, r.position.y - 3.0, str(int(next.reps)), Pal.SECOND, 1, 10, true)
	# The first and last dates under the bars, and "next" under the aim.
	txt(_bars[0].position.x, H - 6.0, Dates.format_date(str(rows[0].date), {"month": "short", "day": "numeric"}), Pal.MUTED, 0, 10)
	var last_i = rows.size() - 1
	if last_i > 0:
		var last_x = _bars[last_i].end.x
		txt(last_x, H - 6.0, Dates.format_date(str(rows[last_i].date), {"month": "short", "day": "numeric"}), Pal.MUTED, 2, 10)
	if next != null:
		txt(_bars[n - 1].get_center().x, H - 6.0, "next", Pal.SECOND, 1, 10, true)
	if hover >= 0 and hover < rows.size() and hover < tips.size():
		var row = rows[hover]
		draw_tip([{"t": Dates.format_date(str(row.date)), "bold": true}, {"t": str(tips[hover])}], _bars[hover].get_center().x)


func _rung_at(i: int) -> float:
	return float(rows[i].key.rung) if i < rows.size() else float(next.rung)


func _star(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 1.0, at.y - 3.0, 2.0, 6.0), Pal.ACCENT)
	draw_rect(Rect2(at.x - 3.0, at.y - 1.0, 6.0, 2.0), Pal.ACCENT)


func _arrow(at: Vector2, col: Color) -> void:
	# A small pixel arrow pointing up.
	draw_rect(Rect2(at.x - 1.0, at.y + 2.0, 3.0, 6.0), col)
	draw_rect(Rect2(at.x - 3.0, at.y + 2.0, 7.0, 2.0), col)
	draw_rect(Rect2(at.x - 1.0, at.y, 3.0, 2.0), col)
