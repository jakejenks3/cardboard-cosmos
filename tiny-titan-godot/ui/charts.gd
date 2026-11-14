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
const HEAT = [Color("0a0e14"), Color("5a4a1a"), Color("9a7a22"), Color("d9ab2c"), Color("ffd766")]
const TIP_BG = Color("0a0e14")
const FLASH = Color("8ad46a")


static func weekly_xp(points: Array) -> Control:
	var c = WeeklyXpChart.new()
	c.setup(points)
	return c


static func heatmap(xp_by_date: Dictionary, today: String, weeks: int = 16) -> Control:
	var c = HeatmapChart.new()
	c.setup(xp_by_date, today, weeks)
	return c


## counts = {grade (int): {"sends": n, "flashes": n}}
static func pyramid(counts: Dictionary, max_grade: int) -> Control:
	var c = PyramidChart.new()
	c.setup(counts, max_grade)
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
