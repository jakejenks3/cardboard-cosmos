class_name Charts
extends RefCounted
## Small hand-drawn charts (port of components/charts.tsx) in the pixel look:
## the plot sits in a sunken well, bars are chunky blocks in the discipline
## colours, lines are thick with square markers, and every colour comes from
## `Pal` so the charts follow the theme.
##
##   Charts.weekly_xp(points)                  stacked weekly XP bars + legend chips
##   Charts.heatmap(xp_by_date, today)          16-week training calendar
##   Charts.line(points, color, fmt, trend)     single-series time line
##   Charts.legend(items)                       a row of colour chips
##   Charts.moving_average(points, n)           centred moving average
##
## A line point is {"x": date key, "y": number}. A week point is
## {"week": monday key, "byDiscipline": {lift, climb, run, ride}, "total"}.

const TICK = 11


## Heat level 0..4 of the training calendar: an empty cell on the well, then
## deeper to brighter shades of the accent.
static func heat(level: int) -> Color:
	match level:
		0:
			return Pal.WELL.lightened(0.07)
		1:
			return Pal.deep(Pal.ACCENT).lerp(Pal.ACCENT, 0.25)
		2:
			return Pal.ACCENT_DARK
		3:
			return Pal.ACCENT
	return Pal.ACCENT.lightened(0.45)


## Grid lines on the well.
static func grid() -> Color:
	return Pal.with_alpha(Pal.MUTED, 0.16)


## A row of small colour chips. items = [{"name": String, "color": Color}].
static func legend(items: Array) -> Control:
	var f = Kit.flow(6)
	for it in items:
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", Kit.sbox(Pal.PANEL2, 5, Pal.LINE, 1, 6, 2))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h = Kit.hbox(5)
		var sw = ColorRect.new()
		sw.color = it.color
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		h.add_child(Kit.label(it.name, 11, Pal.TEXT, true))
		p.add_child(h)
		f.add_child(p)
	return f


static func weekly_xp(points: Array) -> Control:
	var c = WeeklyXpChart.new()
	c.setup(points)
	if c.used.size() < 2:
		return c
	var v = Kit.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(c)
	var items = []
	for d in c.used:
		items.append({"name": TT.DISCIPLINE_META[d].name, "color": Pal.disc(d)})
	v.add_child(legend(items))
	return v


static func heatmap(xp_by_date: Dictionary, today: String, weeks: int = 16) -> Control:
	var c = HeatmapChart.new()
	c.setup(xp_by_date, today, weeks)
	return c


## fmt = Callable(y) -> String for the axis, end label and tooltip.
static func line(points: Array, color: Color, fmt: Callable, trend: Array = []) -> Control:
	var c = LineChart.new()
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
