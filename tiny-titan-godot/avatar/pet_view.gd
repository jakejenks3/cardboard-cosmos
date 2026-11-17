class_name PetView
extends Control
## A pet portrait (port of PetPortrait in Armory.tsx).
##
##   var pet = PetView.new()
##   pet.setup("slime", 30.0)
##
## The pet (outlined, with a one pixel margin) is fitted into a `px` x `px`
## square, the web's `size` prop, centred in the control, at the largest
## WHOLE-number scale that fits, so every pixel of it is the same size on
## screen. Like the web portrait it is a still of the first sprite frame; pass
## `animate = true` to cycle the pet's two sprite frames at the scene's pace
## (Art.FRAME_MS): an animated pet also stands on a small shadow and gives a
## little hop every few seconds (or when `hop()` is called).

## One hop lasts this long and goes this many art pixels up.
const HOP_MS = 360.0
const HOP_PX = 3.0

var _pet_id: String = ""
var _px: float = 30.0
var _animate: bool = false
var _locked: bool = false
var _frame: int = 0
var _since_frame_ms: float = 0.0
var _hop_ms: float = -1.0
var _next_hop_ms: float = 2600.0
var _lift: int = 0


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
	# Pets on one screen do not all hop on the same beat.
	_next_hop_ms = 1800.0 + float(Rng.hash_string("hop:" + pet_id) % 2600)
	custom_minimum_size = Vector2(px, px)
	set_process(animate)
	queue_redraw()


## Grey out a pet that is not unlocked yet (the web's `locked` prop).
func set_locked(locked: bool) -> void:
	_locked = locked
	queue_redraw()


## One little jump, now (an animated pet also does it by itself now and then).
func hop() -> void:
	_hop_ms = 0.0
	set_process(true)
	queue_redraw()


## The whole-number scale the pet is drawn at.
func art_scale() -> int:
	var first: Dictionary = PetSprites.sprite_size(_pet_id, 0)
	return maxi(1, int(floor(_px / maxf(1.0, maxf(first.w + 2, first.h + 2)))))


func _flies() -> bool:
	var sp = PetSprites.PET_SPRITES.get(_pet_id)
	return sp != null and sp.get("fly", false)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var ms: float = delta * 1000.0
	if _animate:
		_since_frame_ms += ms
		if _since_frame_ms >= Art.FRAME_MS:
			_since_frame_ms = 0.0
			_frame += 1
			queue_redraw()
		if _hop_ms < 0.0 and not _locked and not Pix.classic:
			_next_hop_ms -= ms
			if _next_hop_ms <= 0.0:
				_next_hop_ms = 3200.0 + float(Rng.hash_string("%s:%d" % [_pet_id, _frame]) % 3000)
				_hop_ms = 0.0
	if _hop_ms >= 0.0:
		_hop_ms += ms
		var t: float = clampf(_hop_ms / HOP_MS, 0.0, 1.0)
		# Up and down on a parabola, in whole art pixels.
		var lift: int = int(round(4.0 * t * (1.0 - t) * HOP_PX))
		if _hop_ms >= HOP_MS:
			_hop_ms = -1.0
			lift = 0
			if not _animate:
				set_process(false)
		if lift != _lift:
			_lift = lift
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
	if not Pix.classic:
		k = float(art_scale())
	var origin: Vector2 = ((size - Vector2(bw, bh) * k) / 2.0).floor()
	if _animate and not _locked and not Pix.classic:
		# The shadow it stands on (smaller while it is in the air or flying).
		var shrink: float = float(_lift) + (2.0 if _flies() else 0.0)
		var sw: float = maxf(2.0, bw - 4.0 - shrink)
		var sx: float = origin.x + floor((bw - sw) / 2.0) * k
		var sy: float = origin.y + (bh - 1.0) * k
		draw_rect(Rect2(sx + k, sy - k, (sw - 2.0) * k, k), Color(0, 0, 0, 0.22))
		draw_rect(Rect2(sx, sy, sw * k, k), Color(0, 0, 0, 0.22))
	origin.y -= float(_lift) * k
	draw_texture_rect(tex, Rect2(origin, Vector2(tex.get_width(), tex.get_height()) * k), false)
