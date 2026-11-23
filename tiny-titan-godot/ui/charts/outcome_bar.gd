class_name OutcomeBar
extends ChartBase
## Every try in one bar: flashes, sends, then the tries that did not go. A
## bracket over the first two says "SENT n · p%", because a flash is a send;
## the last part says "DIDN'T GO n". Same colours as GradeLadder.

const TOP = 18.0
const BAR_H = 18.0

var t = {"flash": 0, "send": 0, "attempt": 0, "sent": 0, "tries": 0}


func setup(total: Dictionary) -> void:
	t = total
	custom_minimum_size = Vector2(0, TOP + BAR_H + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w = size.x
	var y = TOP
	var tries = maxi(1, int(t.tries))
	draw_rect(Rect2(-1.0, y - 1.0, w + 2.0, BAR_H + 2.0), Pal.OUTLINE)
	draw_rect(Rect2(0.0, y, w, BAR_H), Pal.WELL)
	var wf = floorf(float(t.flash) / tries * w)
	var ws = floorf(float(t.send) / tries * w)
	if int(t.flash) > 0:
		wf = maxf(wf, 3.0)
	if int(t.send) > 0:
		ws = maxf(ws, 3.0)
	var wa = maxf(0.0, w - wf - ws) if int(t.attempt) > 0 else 0.0
	block(Rect2(0.0, y, wf, BAR_H), GradeLadder.flash_col())
	block(Rect2(wf, y, ws, BAR_H), GradeLadder.send_col())
	block(Rect2(wf + ws, y, wa, BAR_H), GradeLadder.miss_col().lerp(Pal.WELL, 0.35))
	var sent_w = wf + ws
	if int(t.sent) > 0:
		# The bracket over flashes + sends.
		var by = y - 5.0
		draw_rect(Rect2(0.0, by, maxf(2.0, sent_w - 1.0), 2.0), Pal.TEXT)
		draw_rect(Rect2(0.0, by, 2.0, 5.0), Pal.TEXT)
		draw_rect(Rect2(maxf(0.0, sent_w - 3.0), by, 2.0, 5.0), Pal.TEXT)
		txt(0.0, by - 3.0, "SENT %d · %d%%" % [int(t.sent), ClimbLadder.pct(int(t.sent), int(t.tries))], Pal.TEXT, 0, 12, true)
	else:
		txt(0.0, y - 5.0, "Nothing sent yet", Pal.MUTED, 0, 12, true)
	if int(t.attempt) > 0:
		txt(w, y - 5.0, "DIDN'T GO %d" % int(t.attempt), Pal.MUTED, 2, 12, true)
