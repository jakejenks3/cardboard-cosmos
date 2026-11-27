class_name UiScreen
extends VBoxContainer
## Base class for every screen. Override `build()` and add children to `self`.
##
## A screen is rebuilt from scratch whenever the saved data changes
## (App.changed) or the sub-navigation changes (App.nav_changed). Screens that
## hold a half-filled form set `auto_rebuild = false` and update themselves.
##
## A rebuild never moves what you are looking at: the scroll position is kept,
## and whatever is under the mouse (the button you just pressed) stays under
## the mouse, so you can press "+ Set" several times in a row without chasing it.

## How many end-of-frame passes the layout gets to settle before the view is pinned.
const SETTLE_PASSES = 8
## How long presses are dropped after a rebuild that could not keep the pressed
## control under the pointer (see `guard_shifts`).
const QUIET_MS = 350

var auto_rebuild: bool = true
## For a screen where a stray tap changes what was typed (the Log tab): when a
## rebuild cannot keep the pressed control where it was (it is gone, or the
## page cannot scroll that far: an exercise moved to the top of the workout),
## presses are dropped for QUIET_MS, so a second tap meant for it does not land
## on whatever took its place.
var guard_shifts: bool = false
## Presses are dropped until this moment (Time.get_ticks_msec).
static var quiet_until: int = 0
var _queued: bool = false
## The anchor_id of a control the next rebuild keeps where it is, whatever was tapped (set before the change
## that rebuilds; used once). For a tap whose key is gone after the rebuild: an exercise added from the
## Log tab's list keeps the search box in place.
var hold_anchor_id: String = ""
var _settle_gen: int = 0
## The ScrollContainer's follow_focus setting while a rebuild has it switched off.
var _follow = null


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	App.changed.connect(_on_app_changed)
	App.nav_changed.connect(_on_app_nav)
	rebuild_now()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() < quiet_until:
		get_viewport().set_input_as_handled()


func _on_app_changed() -> void:
	if auto_rebuild:
		rebuild()


func _on_app_nav() -> void:
	on_nav()


## Called when the tab / sub-tab / edit target changes. Default: rebuild.
func on_nav() -> void:
	rebuild()


## Rebuild at the end of this frame (several requests in one frame become one).
func rebuild() -> void:
	if _queued:
		return
	_queued = true
	call_deferred("rebuild_now")


func rebuild_now() -> void:
	_queued = false
	if not is_inside_tree():
		return
	var scroll = _scroll_parent()
	if scroll == null:
		Kit.clear(self)
		build()
		return
	var keep = scroll.scroll_vertical
	var anchor = _anchor_under_mouse()
	if hold_anchor_id != "":
		var held = _anchor_by_id(hold_anchor_id)
		hold_anchor_id = ""
		if held != null:
			anchor = held
	# While the children are swapped: do not let the scroll range collapse, and do
	# not let a focus change drag the view around.
	if _follow == null:
		_follow = scroll.follow_focus
	scroll.follow_focus = false
	custom_minimum_size.y = size.y
	Kit.clear(self)
	build()
	_settle_gen += 1
	_settle(scroll, keep, anchor, _settle_gen, 0)


## Override: create the screen's controls and add them to `self`.
func build() -> void:
	pass


## Jump to the top after the next rebuild instead of keeping the position
## (for a rebuild that shows something entirely different, e.g. another form).
func scroll_to_top() -> void:
	_settle_gen += 1
	custom_minimum_size.y = 0
	var scroll = _scroll_parent()
	if scroll != null:
		scroll.scroll_vertical = 0
	_release_follow(scroll)


func _exit_tree() -> void:
	_release_follow(_scroll_parent())


func _release_follow(scroll) -> void:
	if _follow != null and scroll != null and is_instance_valid(scroll):
		scroll.follow_focus = _follow
	_follow = null


# ---------------------------------------------------------------------------
# Keeping the view still across a rebuild
# ---------------------------------------------------------------------------

func _scroll_parent():
	var p = get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


static func _is_anchor(c: Node) -> bool:
	return c is BaseButton or c is LineEdit or c is Card


## A label that identifies a control across rebuilds (its text, tooltip or first caption).
static func _anchor_label(c: Node) -> String:
	# A control that names itself (a to-do row, a mission's Claim key): found
	# again by that name only, whatever its text or tooltip says by then.
	if c.has_meta("anchor_id"):
		return "id:" + str(c.get_meta("anchor_id"))
	if c is Button and c.text != "":
		return c.text
	if c is LineEdit:
		return c.placeholder_text
	if c is Control and c.tooltip_text != "":
		return c.tooltip_text
	if c is Card:
		for n in c.find_children("*", "Label", true, false):
			if n.text != "":
				return n.text
	return ""


func _collect_anchors(node: Node, cls: String, label: String, out: Array, any_cls: bool = false) -> void:
	for c in node.get_children():
		if c is CanvasItem and not c.visible:
			continue
		if _is_anchor(c) and (any_cls or c.get_class() == cls) and _anchor_label(c) == label:
			out.append(c)
		_collect_anchors(c, cls, label, out, any_cls)


## What is under the mouse right now: {cls, label, nth, rel} or null.
func _anchor_under_mouse():
	var h = get_viewport().gui_get_hovered_control()
	while h != null and h != self and not _is_anchor(h):
		h = h.get_parent()
	if h == null or h == self or not (h is Control) or not is_ancestor_of(h):
		return null
	var cls = h.get_class()
	var label = _anchor_label(h)
	var same = []
	_collect_anchors(self, cls, label, same)
	return {"cls": cls, "label": label, "nth": same.find(h), "count": same.size(), "rel": h.global_position.y - global_position.y}


## The anchor of the control with this anchor_id, as _anchor_under_mouse gives one, or null.
func _anchor_by_id(id: String):
	var same = []
	_collect_anchors(self, "", "id:" + id, same, true)
	if same.is_empty():
		return null
	var h = same[0]
	return {"cls": h.get_class(), "label": "id:" + id, "nth": 0, "count": 1, "rel": h.global_position.y - global_position.y}


func _find_anchor(anchor: Dictionary):
	var same = []
	_collect_anchors(self, anchor.cls, anchor.label, same)
	if same.is_empty():
		return null
	# The same position in the list; when rows were added or removed above, the list
	# only grows or shrinks at the end, so the index still points at the same button.
	var i = clampi(int(anchor.nth), 0, same.size() - 1)
	return same[i]


func _settle(scroll, keep: int, anchor, gen: int, step: int) -> void:
	if gen != _settle_gen or not is_instance_valid(scroll) or not is_inside_tree():
		return
	if step >= 2:
		custom_minimum_size.y = 0
	var want = keep
	if anchor != null:
		var c = _find_anchor(anchor)
		if c != null:
			# Positions relative to the screen do not depend on the scroll offset.
			want = keep + int(round((c.global_position.y - global_position.y) - float(anchor.rel)))
	scroll.scroll_vertical = maxi(0, want)
	if step < SETTLE_PASSES:
		_settle.call_deferred(scroll, keep, anchor, gen, step + 1)
	else:
		_release_follow(scroll)
		if guard_shifts and anchor != null and _anchor_moved(scroll, keep, anchor):
			quiet_until = Time.get_ticks_msec() + QUIET_MS


## Is the control that was under the pointer somewhere else on screen now (or
## gone)? `keep`: the scroll position it had then.
func _anchor_moved(scroll, keep: int, anchor: Dictionary) -> bool:
	var c = _find_anchor(anchor)
	if c == null:
		return true
	var now_y = (c.global_position.y - global_position.y) - float(scroll.scroll_vertical)
	return absf(now_y - (float(anchor.rel) - float(keep))) > 2.0
