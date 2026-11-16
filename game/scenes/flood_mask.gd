class_name FloodMask
extends RefCounted
## The picture of the water on a chunk for flood.gdshader: one pixel a tile, the red the depth in
## centimetres, up to MAX_DEPTH_CM. A ring of BORDER tiles of the neighbouring chunks lies around
## the chunk's own, so the shader can blend the depths across the chunk seams.

const MAX_DEPTH_CM := 255
const BORDER := 1
const BORDER_TILES := Vector2i(BORDER, BORDER)
const SIZE := Chunk.CHUNK_SIZE + 2 * BORDER


## The mask of a chunk and its border, from the tiles that are under water.
static func image_of(flood: FloodState, chunk_coords: Vector2i) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_R8)
	var origin := chunk_coords * Chunk.CHUNK_SIZE - BORDER_TILES
	for tile in flood.wet_in_chunk(chunk_coords):
		var pixel := tile - origin
		_set_depth(image, pixel, flood.depth_at(tile))
	for i in SIZE:
		for pixel in [Vector2i(i, 0), Vector2i(i, SIZE - 1), Vector2i(0, i), Vector2i(SIZE - 1, i)]:
			_set_depth(image, pixel, flood.depth_at(origin + pixel))
	return image


static func _set_depth(image: Image, pixel: Vector2i, depth: float) -> void:
	var depth_cm := mini(roundi(depth * FloodState.METRES_TO_CM), MAX_DEPTH_CM)
	image.set_pixel(pixel.x, pixel.y, Color.from_rgba8(depth_cm, 0, 0))
