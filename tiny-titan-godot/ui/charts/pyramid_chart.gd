class_name PyramidChart
extends ChartBase

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
