class_name SqueezeRow
extends Container
## Things side by side, like an HBoxContainer, except that the parts marked soft
## (`soften`) give way when the row is short of room: they are cut off with "…"
## instead of making the row, and with it the whole page, wider than the screen.
## (A long lift name with a long variation beside it once pushed the Hero page
## off the right edge of a phone.) The last soft part gives way first, so a
## lift's variation is cut before its movement.

var separation: float = 6.0


## Mark `c` soft: it is `want` wide when there is room and never under `least`.
## `c` must be able to be narrower than its text (a label with clip_text, or a
## tag around one).
static func soften(c: Control, want: float, least: float = 40.0) -> Control:
	c.set_meta("soft_w", want)
	c.custom_minimum_size.x = minf(least, want)
	c.size_flags_horizontal = Control.SIZE_FILL
	return c


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kids() -> Array:
	var out = []
	for c in get_children():
		if c is Control and c.visible and not c.top_level:
			out.append(c)
	return out


func _get_minimum_size() -> Vector2:
	var w = 0.0
	var h = 0.0
	var kids = _kids()
	for c in kids:
		var ms = c.get_combined_minimum_size()
		w += ms.x
		h = maxf(h, ms.y)
	return Vector2(w + separation * maxf(0.0, float(kids.size() - 1)), h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_place()


func _place() -> void:
	var kids = _kids()
	var widths = []
	var mins = []
	var total = separation * maxf(0.0, float(kids.size() - 1))
	for c in kids:
		var m = c.get_combined_minimum_size().x
		var w = maxf(m, float(c.get_meta("soft_w", m)))
		mins.append(m)
		widths.append(w)
		total += w
	var over = total - size.x
	var i = kids.size() - 1
	while over > 0.0 and i >= 0:
		var cut = minf(over, float(widths[i]) - float(mins[i]))
		widths[i] = float(widths[i]) - cut
		over -= cut
		i -= 1
	var x = 0.0
	for k in kids.size():
		fit_child_in_rect(kids[k], Rect2(x, 0.0, float(widths[k]), size.y))
		x += float(widths[k]) + separation
