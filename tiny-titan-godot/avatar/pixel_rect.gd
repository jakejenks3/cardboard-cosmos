class_name PixelRect
extends TextureRect
## A TextureRect for pixel art: nearest-neighbour filtering, aspect kept,
## centred in whatever rect the layout gives it.
##
##   var thumb = PixelRect.make(Art.item_texture("iron_crown"), 2.0)
##
## `custom_minimum_size` is the texture size times `px_scale`, so with
## px_scale 2 a 48x60 hero asks for 96x120.


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


static func make(tex: Texture2D, px_scale: float = 1.0) -> PixelRect:
	var r: PixelRect = PixelRect.new()
	r.set_art(tex, px_scale)
	return r


## Swap the texture (and the minimum size that goes with it).
func set_art(tex: Texture2D, px_scale: float = 1.0) -> void:
	texture = tex
	if tex == null:
		custom_minimum_size = Vector2.ZERO
	else:
		custom_minimum_size = Vector2(tex.get_width(), tex.get_height()) * px_scale
