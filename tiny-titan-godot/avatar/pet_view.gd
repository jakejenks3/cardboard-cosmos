class_name PetView
extends Control
## A pet portrait (port of PetPortrait in Armory.tsx).
##
##   var pet = PetView.new()
##   pet.setup("slime", 30.0)
##
## The pet (outlined, with a one pixel margin) is fitted into a `px` x `px`
## square, the web's `size` prop, centred in the control. Like the web
## portrait it is a still of the first sprite frame; pass `animate = true` to
## cycle the pet's two sprite frames at the scene's pace (Art.FRAME_MS).

var _pet_id: String = ""
var _px: float = 30.0
var _animate: bool = false
var _locked: bool = false
var _frame: int = 0
var _since_frame_ms: float = 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_px, _px)


func _ready() -> void:
	# A node with _process() starts processing when it becomes ready: only
	# keep it on for an animated portrait.
	set_process(_animate)


## `px` is the on-screen square the portrait is fitted into.
func setup(pet_id: String, px: float = 30.0, animate: bool = false) -> void:
	_pet_id = pet_id
	_px = px
	_animate = animate
	_frame = 0
	_since_frame_ms = 0.0
	custom_minimum_size = Vector2(px, px)
	set_process(animate)
	queue_redraw()


## Grey out a pet that is not unlocked yet (the web's `locked` prop).
func set_locked(locked: bool) -> void:
	_locked = locked
	queue_redraw()


func _process(delta: float) -> void:
	if not _animate or not is_visible_in_tree():
		return
	_since_frame_ms += delta * 1000.0
	if _since_frame_ms >= Art.FRAME_MS:
		_since_frame_ms = 0.0
		_frame += 1
		queue_redraw()


func _draw() -> void:
	if _pet_id == "":
		return
	var tex: ImageTexture = Art.pet_texture(_pet_id, _frame, _locked)
	# The box is sized for frame 0, exactly like the web portrait; the few
	# frames that are a column wider grow to the right, so nothing jumps.
	var first: Dictionary = PetSprites.sprite_size(_pet_id, 0)
	var bw: float = first.w + 2
	var bh: float = first.h + 2
	var k: float = _px / maxf(bw, bh)
	var origin: Vector2 = (size - Vector2(bw, bh) * k) / 2.0
	draw_texture_rect(tex, Rect2(origin, Vector2(tex.get_width(), tex.get_height()) * k), false)
