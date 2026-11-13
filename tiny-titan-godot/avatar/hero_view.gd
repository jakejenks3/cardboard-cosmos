class_name HeroView
extends Control
## The animated hero (port of the canvas logic in HeroScene.tsx): the hero in
## the home gym with the active pet, or the hero alone on a transparent
## background.
##
##   var view = HeroView.new()
##   view.setup(state, profile, loadout, active_pet)        # gym scene
##   view.setup(state, profile, loadout, null, false)       # hero only
##   view.tapped.connect(_on_hero_tapped)
##
## Timing is the web's: the frame counter goes up every Art.FRAME_MS (170 ms),
## the idle bob / blink / gear and scene animations all derive from it, and a
## click or tap makes the hero flex for Art.FLEX_MS (1.6 s) and emits `tapped`.
## The art is drawn at the largest whole-number scale that fits the control,
## centred. Frames come from Art (cached); nothing is rasterised per
## `_process` call, only when the frame counter moves.

## Emitted on every click / tap on the hero.
signal tapped

## false = a static render of frame 0 (the web's `animate={false}`).
var animate: bool = true:
	set(value):
		animate = value
		queue_redraw()

## Force the smile (the web's `happy` prop; a flexing hero always smiles).
var happy: bool = false:
	set(value):
		happy = value
		queue_redraw()

## "" = idle, flexing when tapped. "idle" or "flex" forces that pose (the
## web's `pose` prop); taps still emit `tapped`.
var forced_pose: String = "":
	set(value):
		forced_pose = value
		queue_redraw()

## custom_minimum_size is the art size times this (scene 96x72, hero 48x60).
var min_scale: int = 2:
	set(value):
		min_scale = maxi(1, value)
		_update_min_size()

var _state = null
var _profile = null
var _loadout: Dictionary = {}
var _active_pet = null
var _show_scene: bool = true
var _frame: int = 0
var _since_frame_ms: float = 0.0
var _flex_until_ms: int = 0
var _last_tap_ms: int = -100000


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_min_size()


## Show this hero. Call it again whenever the state, profile, loadout or pet
## changes; the animation keeps running.
func setup(state: Dictionary, profile: Dictionary, loadout: Dictionary, active_pet, show_scene: bool = true) -> void:
	_state = state
	_profile = profile
	_loadout = loadout
	_active_pet = active_pet
	_show_scene = show_scene
	_update_min_size()
	queue_redraw()


## Play the flex pose for Art.FLEX_MS (what a tap does).
func flex() -> void:
	_flex_until_ms = Time.get_ticks_msec() + Art.FLEX_MS
	queue_redraw()


## The pose being shown right now: "idle" or "flex".
func current_pose() -> String:
	if forced_pose != "":
		return forced_pose
	return "flex" if Time.get_ticks_msec() < _flex_until_ms else "idle"


## Size of the art in art pixels (before scaling).
func art_size() -> Vector2i:
	if _show_scene:
		return Vector2i(Art.SCENE_W, Art.SCENE_H)
	return Vector2i(Art.HERO_W, Art.HERO_H)


func _update_min_size() -> void:
	custom_minimum_size = Vector2(art_size()) * min_scale


func _process(delta: float) -> void:
	if _state == null or not is_visible_in_tree():
		return
	if animate:
		_since_frame_ms += delta * 1000.0
		if _since_frame_ms >= Art.FRAME_MS:
			# Like the web's `last = t`: one step per tick, no catching up.
			_since_frame_ms = 0.0
			_frame += 1
			queue_redraw()
	elif _flex_until_ms != 0 and Time.get_ticks_msec() >= _flex_until_ms:
		# A static hero still has to come back from a tap-flex.
		_flex_until_ms = 0
		queue_redraw()


func _draw() -> void:
	if _state == null or _profile == null:
		return
	var frame: int = _frame if animate else 0
	var pose: String = current_pose()
	var tex: ImageTexture
	if _show_scene:
		tex = Art.scene_texture(_state, _profile, _loadout, _active_pet, pose, frame, happy)
	else:
		tex = Art.hero_texture(_state, _profile, _loadout, pose, frame, happy)
	var art: Vector2 = Vector2(tex.get_width(), tex.get_height())
	var k: float = maxf(1.0, floor(minf(size.x / art.x, size.y / art.y)))
	var draw_size: Vector2 = art * k
	var pos: Vector2 = ((size - draw_size) / 2.0).floor()
	draw_texture_rect(tex, Rect2(pos, draw_size), false)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	accept_event()
	# A finger arrives twice (the touch and the mouse click emulated from it):
	# count it once.
	var now: int = Time.get_ticks_msec()
	if now - _last_tap_ms < 60:
		return
	_last_tap_ms = now
	flex()
	tapped.emit()
