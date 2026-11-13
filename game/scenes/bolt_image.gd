class_name BoltImage
extends RefCounted
## The picture of a LightningBolt: one pixel per art pixel, which the weather view shows scaled up
## with no smoothing, so that it is crisp at every zoom and in both arts. A near-white core, two
## pixels wide in the main channel and one in the branches, with a softer glow of one pixel around
## the main channel and its first branches.

## Palette colours (tools/art/palette.py): snow_light and foam; the glow is see-through in part.
const CORE_COLOR := Color(230.0 / 255.0, 238.0 / 255.0, 242.0 / 255.0)
const GLOW_COLOR := Color(146.0 / 255.0, 180.0 / 255.0, 189.0 / 255.0, 140.0 / 255.0)
## Branches deeper than this have a core and no glow.
const GLOWING_DEPTH := 1


## The bolt as a picture of `size` art pixels, see-through where there is none.
static func render(bolt: LightningBolt, size: Vector2i) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for index in bolt.paths.size():
		if bolt.depths[index] > GLOWING_DEPTH:
			continue
		for cell in _cells(bolt.paths[index]):
			for next_to in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_paint(image, cell + next_to, GLOW_COLOR)
	for index in bolt.paths.size():
		for cell in _cells(bolt.paths[index]):
			_paint(image, cell, CORE_COLOR)
			if bolt.depths[index] == LightningBolt.MAIN:
				_paint(image, cell + Vector2i.RIGHT, CORE_COLOR)
	return image


## The pixels a polyline passes through.
static func _cells(path: PackedVector2Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index in range(1, path.size()):
		var from := path[index - 1].round()
		var to := path[index].round()
		var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
		for step in range(steps + 1):
			cells.append(Vector2i(from.lerp(to, float(step) / maxf(steps, 1.0)).round()))
	return cells


static func _paint(image: Image, cell: Vector2i, color: Color) -> void:
	if Rect2i(Vector2i.ZERO, image.get_size()).has_point(cell):
		image.set_pixelv(cell, color)
