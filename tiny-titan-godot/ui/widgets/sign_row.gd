class_name SignRow
extends Container
## A section's head (Kit.section): its sign centred on the frame's top edge, as in the mock-up, when there
## is room for it beside what sits at the right end (a count, a link, a key on a paper note); else the sign
## moves left just enough. Children: the sign, then the note (optional).

const EDGE = 10
const GAP = 8


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kids() -> Array:
	return get_children().filter(func(c): return c is Control and c.visible)


func _get_minimum_size() -> Vector2:
	var kids = _kids()
	var w = float(EDGE * 2)
	var h = 0.0
	for c in kids:
		var m = c.get_combined_minimum_size()
		w += m.x
		h = maxf(h, m.y)
	if kids.size() > 1:
		w += GAP
	return Vector2(w, h)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var kids = _kids()
	if kids.is_empty():
		return
	var sign: Control = kids[0]
	var sm = sign.get_combined_minimum_size()
	var limit = size.x - EDGE
	if kids.size() > 1:
		var right: Control = kids[1]
		var rm = right.get_combined_minimum_size()
		fit_child_in_rect(right, Rect2(floor((size.x - EDGE - rm.x) / 2.0) * 2.0, floor((size.y - rm.y) / 4.0) * 2.0, rm.x, rm.y))
		limit = size.x - EDGE - rm.x - GAP
	var x = floor((size.x - sm.x) / 4.0) * 2.0
	x = minf(x, limit - sm.x)
	x = maxf(float(EDGE), x)
	fit_child_in_rect(sign, Rect2(x, floor((size.y - sm.y) / 4.0) * 2.0, sm.x, sm.y))
