class_name HoverCard
extends PanelContainer
## A small card that floats next to a control while the mouse is over it: what
## the thing is, how it was earned, what it does. The content is built on
## demand by a Callable, so it always shows the current state.
##
##   HoverCard.attach(tile, func(): return my_vbox, Pal.rarity("rare"))
##
## The card never takes the mouse (clicks go to what is under it), follows the
## rules of a tooltip (gone on a click, on the wheel, or when the mouse leaves
## the control) and stays inside the app column. There is at most one.

const WIDTH = 252.0
const GAP = 8.0
const EDGE = 6.0

static var _live = null

var _target: Control = null
var _placed: bool = false
## Put the card beside the control (not above it), so a column of small
## things can be swept through without the card covering the next one.
var _beside: bool = false


## Show a card built by `build.call()` (it returns a Control) while the mouse is
## over `target`. `ring` (a Color or null) colours the card's edge. With
## `beside` the card goes to the left or right of the control instead of above.
static func attach(target: Control, build: Callable, ring = null, beside: bool = false) -> void:
	if target.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		target.mouse_filter = Control.MOUSE_FILTER_PASS
	target.mouse_entered.connect(HoverCard._open.bind(target, build, ring, beside))


## Close the card that is showing, if any.
static func dismiss() -> void:
	if _live != null and is_instance_valid(_live):
		_live.queue_free()
	_live = null


static func _open(target: Control, build: Callable, ring, beside: bool = false) -> void:
	dismiss()
	if Kit.overlay_root == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	# A press is under way (the tile is being clicked or dragged): no card.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var content = build.call()
	if not (content is Control):
		return
	var card = HoverCard.new()
	card._target = target
	card._beside = beside
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card.add_theme_stylebox_override("panel", PixBox.make(Pal.BG2.lightened(0.04), {"ring": Pal.BORDER if ring == null else ring, "lip": 1, "lip_color": Pal.OUTLINE, "pad_h": 12, "pad_v": 10}))
	card.custom_minimum_size = Vector2(WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	Kit.passthrough(card)
	card.modulate.a = 0.0
	Kit.overlay_root.add_child(card)
	_live = card


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_close()
		return
	if not _placed:
		# One frame after it was added the card knows how tall its text is.
		_placed = true
		_place()
		create_tween().tween_property(self, "modulate:a", 1.0, 0.09)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
	elif event is InputEventScreenTouch:
		_close()
	elif event is InputEventMouseMotion:
		# The mouse is followed through its own events (not by asking where it
		# is), so the card also goes when it moves onto a button inside the
		# control's own area and out again.
		if _target != null and is_instance_valid(_target) and not _target.get_global_rect().has_point(event.global_position):
			_close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_close()


func _close() -> void:
	if _live == self:
		_live = null
	queue_free()


## Above the control when there is room, else below it; always inside the column.
func _place() -> void:
	var root: Control = get_parent()
	if root == null:
		return
	reset_size()
	var r: Rect2 = _target.get_global_rect()
	r.position -= root.global_position
	if _beside:
		# On the side with more room, level with the control.
		var right: bool = r.get_center().x < root.size.x / 2.0
		var bx: float = (r.end.x + GAP) if right else (r.position.x - GAP - size.x)
		if bx >= EDGE and bx + size.x <= root.size.x - EDGE:
			position = Vector2(bx, clampf(r.position.y, EDGE, maxf(EDGE, root.size.y - size.y - EDGE))).floor()
			return
	var x: float = clampf(r.get_center().x - size.x / 2.0, EDGE, maxf(EDGE, root.size.x - size.x - EDGE))
	var y: float = r.position.y - GAP - size.y
	if y < EDGE:
		y = r.end.y + GAP
		if y + size.y > root.size.y - EDGE:
			y = maxf(EDGE, root.size.y - size.y - EDGE)
	position = Vector2(x, y).floor()
