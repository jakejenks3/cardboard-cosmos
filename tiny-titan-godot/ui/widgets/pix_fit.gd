class_name PixFit
extends Control
## Pixel art shown at the largest WHOLE-number scale that fits a box, centred.
## Every art pixel is then the same size on screen: no pixel is wider than its
## neighbour, which is what makes scaled pixel art look uneven.
##
##   var pic = PixFit.make(Art.item_icon_texture("iron_crown"), Vector2(40, 40))
##
## The box is the control's minimum size; art bigger than the box is shown at
## scale 1 and may stick out of it.

var _tex: Texture2D = null
var _max_scale: int = 8
var _tint: Color = Color.WHITE


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func make(tex: Texture2D, box: Vector2, max_scale: int = 8) -> PixFit:
	var p = PixFit.new()
	p.set_art(tex, box, max_scale)
	return p


func set_art(tex: Texture2D, box: Vector2, max_scale: int = 8) -> void:
	_tex = tex
	_max_scale = maxi(1, max_scale)
	custom_minimum_size = box
	queue_redraw()


## Multiply the art by a colour (Color(1, 1, 1, 0.4) fades it out).
func set_tint(c: Color) -> void:
	_tint = c
	queue_redraw()


## The whole-number scale the art is drawn at in a box of `box` pixels.
static func scale_for(tex_size: Vector2, box: Vector2, max_scale: int = 8) -> int:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return 1
	return clampi(int(floor(minf(box.x / tex_size.x, box.y / tex_size.y))), 1, max_scale)


func _draw() -> void:
	if _tex == null:
		return
	var art = Vector2(_tex.get_width(), _tex.get_height())
	var k = float(PixFit.scale_for(art, size, _max_scale))
	var draw_size = art * k
	draw_texture_rect(_tex, Rect2(((size - draw_size) / 2.0).floor(), draw_size), false, _tint)
