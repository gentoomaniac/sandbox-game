class_name ItemIcon
extends TextureRect
## An item's icon in the UI, outside a slot: in a recipe row, or picked up and following the
## mouse. Its picture is fitted into SIZE UI pixels whatever its own size: the icons are drawn
## at 32 px, an art pixel as big as a world pixel at the widest zoom, so they are shown at half
## size; the classic 16 px ones at full size. It shows the other art set on F7 (ArtSet).

const SIZE := 16

## Draws pixel art scaled with square pixels at any size of the window (sharp_pixels.gdshader).
const SHARP_PIXELS := preload("res://game/scenes/sharp_pixels.tres")

var _item := ItemTypes.NONE


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharpen(self)
	add_to_group(ArtSet.VIEWS)


func show_item(item: StringName) -> void:
	_item = item
	show_art_set()


func show_art_set() -> void:
	texture = null if _item == ItemTypes.NONE else load(ArtSet.path(ItemTypes.icon_path(_item)))


## Gives `item` the material that scales its pictures with square pixels: with a plain nearest
## filter, 1.5 window pixels per art pixel would make every other column of pixels wider.
static func sharpen(item: CanvasItem) -> void:
	item.material = SHARP_PIXELS
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
