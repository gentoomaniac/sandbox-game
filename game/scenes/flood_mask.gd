class_name FloodMask
extends RefCounted
## The picture of the water on a chunk for flood.gdshader: one pixel a tile, the red the depth in
## centimetres, up to MAX_DEPTH_CM.

const MAX_DEPTH_CM := 255
const SIZE := Chunk.CHUNK_SIZE


## The mask of a chunk, from the tiles that are under water in it.
static func image_of(flood: FloodState, chunk_coords: Vector2i) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_R8)
	for tile in flood.wet_in_chunk(chunk_coords):
		var depth_cm := mini(roundi(flood.depth_at(tile) * FloodState.METRES_TO_CM), MAX_DEPTH_CM)
		var local := Chunk.local_pos(tile)
		image.set_pixel(local.x, local.y, Color.from_rgba8(depth_cm, 0, 0))
	return image
