class_name GradeLadder
extends ChartBase
## Climbing grades, hardest on top: one bar per grade as long as its tries,
## split into flashes (gold, first go), sends (climbing colour, after tries)
## and tries that did not go (the attempt colour, dimmer). The sent part
## (flashes + sends) is solid and comes first; "sent / tries" at the end.
## Hover shows the numbers; a click picks the grade (`picked`).

signal picked(index: int)

const ROW = 26.0
const BAR_H = 16.0

var rows = []
var sel = -1
var mx = 1.0
var label_w = 34.0
var end_w = 40.0


static func flash_col() -> Color:
	return LogSessionForm.flash_color()


static func send_col() -> Color:
	return Pal.CLIMB


static func miss_col() -> Color:
	return Pal.SECOND


func setup(r: Array, selected: int) -> void:
	rows = r
	sel = selected
	mx = 1.0
	for row in rows:
		mx = maxf(mx, float(row.tries))
	custom_minimum_size = Vector2(0, rows.size() * ROW)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func hit_test(pos: Vector2) -> int:
	var i = int(floor(pos.y / ROW))
	return i if i >= 0 and i < rows.size() else -1


func _gui_input(event: InputEvent) -> void:
	super._gui_input(event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i = hit_test(event.position)
		if i >= 0:
			accept_event()
			picked.emit(i)


func _draw() -> void:
	label_w = 10.0
	end_w = 10.0
	for r in rows:
		label_w = maxf(label_w, text_w(str(r.label), 12, true))
		end_w = maxf(end_w, text_w("%d/%d" % [int(r.sent), int(r.tries)], 12, true))
	label_w += 8.0
	var bar_x = label_w + 10.0
	var bar_w = maxf(10.0, size.x - bar_x - 12.0 - end_w)
	for i in range(rows.size()):
		var r = rows[i]
		var y = floorf(i * ROW + (ROW - BAR_H) / 2.0)
		var base = y + BAR_H - 3.0
		var lit = hover == -1 or hover == i or i == sel
		if i == sel:
			draw_style_box(PixBox.make(Pal.PANEL2, {"ring": Pal.CLIMB, "lip": 0, "pad_h": 0, "pad_v": 0}), Rect2(0.0, i * ROW + 1.0, size.x, ROW - 2.0))
		txt(label_w, base, str(r.label), Pal.TEXT if lit else Pal.MUTED, 2, 12, true)
		draw_rect(Rect2(bar_x - 1.0, y - 1.0, bar_w + 2.0, BAR_H + 2.0), Pal.OUTLINE)
		draw_rect(Rect2(bar_x, y, bar_w, BAR_H), Pal.WELL)
		var x = bar_x
		var parts = [[int(r.flash), flash_col(), true], [int(r.send), send_col(), true], [int(r.attempt), miss_col(), false]]
		for p in parts:
			if int(p[0]) <= 0:
				continue
			var w = floorf(maxf(3.0, float(p[0]) / mx * bar_w))
			w = minf(w, bar_x + bar_w - x)
			var col: Color = p[1]
			if not bool(p[2]):
				col = col.lerp(Pal.WELL, 0.35)
			if not lit:
				col = col.lerp(Pal.WELL, 0.5)
			block(Rect2(x, y, w, BAR_H), col)
			x += w
		var end_col = Pal.TEXT if int(r.sent) > 0 else Pal.MUTED
		txt(size.x - 6.0, base, "%d/%d" % [int(r.sent), int(r.tries)], end_col if lit else Pal.MUTED, 2, 12, true)
	if hover >= 0 and hover < rows.size():
		var h = rows[hover]
		var lines = [{"t": "%s · %d %s" % [str(h.label), int(h.tries), "try" if int(h.tries) == 1 else "tries"], "bold": true}]
		lines.append({"t": "%d flashed (first go)" % int(h.flash), "sw": flash_col()})
		lines.append({"t": "%d sent after tries" % int(h.send), "sw": send_col()})
		lines.append({"t": "%d didn't go" % int(h.attempt), "sw": miss_col()})
		lines.append({"t": "%d sent of %d (%d%%)" % [int(h.sent), int(h.tries), ClimbLadder.pct(int(h.sent), int(h.tries))]})
		draw_tip(lines, size.x * 0.25)
