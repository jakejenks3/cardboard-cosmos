class_name PyramidChart
extends ChartBase

const ROW = 22.0
const BAR_H = 14.0
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
	var bar_x = 34.0 + 10.0
	var bar_w = maxf(10.0, size.x - bar_x - 10.0 - 34.0)
	for i in range(grades.size()):
		var g = grades[i]
		var e = _entry(g)
		var total = _total(g)
		var y = floorf(i * ROW + (ROW - BAR_H) / 2.0)
		var base = y + BAR_H - 2.0
		var lit = hover == -1 or hover == i
		txt(34.0, base, Xp.grade_label(g), Pal.TEXT if lit else Pal.MUTED, 2, 12, true)
		draw_rect(Rect2(bar_x - 1.0, y - 1.0, bar_w + 2.0, BAR_H + 2.0), Pal.OUTLINE)
		draw_rect(Rect2(bar_x, y, bar_w, BAR_H), Pal.WELL)
		var fw = floorf(maxf(2.0, total / mx * bar_w)) if total > 0.0 else 0.0
		var col = Pal.CLIMB if lit else Pal.CLIMB.lerp(Pal.WELL, 0.5)
		block(Rect2(bar_x, y, fw, BAR_H), col)
		if total > 0.0 and e.flashes > 0:
			var flw = floorf(float(e.flashes) / total * fw)
			var fcol = Charts.flash() if lit else Charts.flash().lerp(Pal.WELL, 0.5)
			block(Rect2(bar_x + fw - flw, y, flw, BAR_H), fcol)
		txt(bar_x + bar_w + 8.0, base, Xp.fmt_int(total), Pal.TEXT if lit else Pal.MUTED, 0, 12, true)
	if hover >= 0 and hover < grades.size():
		var g2 = grades[hover]
		var e2 = _entry(g2)
		draw_tip([
			{"t": Xp.grade_label(g2), "bold": true},
			{"t": "%s sends" % Xp.fmt_int(e2.sends), "sw": Pal.CLIMB},
			{"t": "%s flashes" % Xp.fmt_int(e2.flashes), "sw": Charts.flash()},
		], size.x)
