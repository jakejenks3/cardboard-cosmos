class_name ChartBase
extends Control

## Index of the hovered bar / point / cell, -1 = none.
var hover = -1

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The well and tooltip are pixel-art boxes: keep them crisp.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	## (2026-11-27 review: dark ink on a near-black box could not be read. A tooltip in the Workshop look is a
	## paper note: dark words on it, and it stands out from the dark well under it.)
	draw_style_box(PixBox.material("note", {"pad_h": 0, "pad_v": 0, "shadow": 1}), r.grow(2.0))
	var y = 4.0 + 5.0 + 11.0
	for l in lines:
		var tx = x + 8.0
		if l.get("sw") != null:
			draw_rect(Rect2(tx - 1.0, y - 10.0, 11.0, 11.0), Pal.OUTLINE)
			draw_rect(Rect2(tx, y - 9.0, 9.0, 9.0), l.sw)
			tx += 13.0
		txt(tx, y, l.t, Pal.INK if l.get("bold", false) else Pal.TEXT, 0, 11, l.get("bold", false))
		y += 15.0

## The sunken well the plot sits in (grown a little past the plot rect).
func draw_well(r: Rect2) -> void:
	draw_style_box(PixBox.well(0, 0), r.grow(6.0))

## A chunky block: fill, a light top row and a dark bottom row, like the pixel boxes.
func block(r: Rect2, col: Color, cap: bool = true) -> void:
	if r.size.y <= 0.0 or r.size.x <= 0.0:
		return
	draw_rect(r, col)
	if cap and r.size.y >= 4.0:
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2.0), col.lightened(0.35))
	if r.size.x >= 6.0:
		draw_rect(Rect2(r.position.x + r.size.x - 2.0, r.position.y, 2.0, r.size.y), col.darkened(0.25))

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
