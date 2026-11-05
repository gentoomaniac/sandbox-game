class_name ChunkStreaming
extends RefCounted
## Decides which chunks to load and unload around a focus point. Pure: no world access.


## Chunks to load and unload for a focus chunk.
##
## Every in-bounds chunk within `load_radius` (Chebyshev distance, in chunks) that is not
## loaded yet is returned in "load", nearest first. Every loaded chunk farther than
## `unload_radius` is returned in "unload". Keep unload_radius larger than load_radius, so
## a chunk at the edge does not flip between loaded and unloaded as the focus jitters.
static func plan(
	focus_chunk: Vector2i, loaded: Array[Vector2i], load_radius: int, unload_radius: int
) -> Dictionary:
	assert(unload_radius > load_radius, "unload_radius must exceed load_radius")
	var to_load: Array[Vector2i] = []
	for y in range(focus_chunk.y - load_radius, focus_chunk.y + load_radius + 1):
		for x in range(focus_chunk.x - load_radius, focus_chunk.x + load_radius + 1):
			var coords := Vector2i(x, y)
			if World.is_chunk_in_bounds(coords) and coords not in loaded:
				to_load.append(coords)
	to_load.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (a - focus_chunk).length_squared() < (b - focus_chunk).length_squared()
	)

	var to_unload: Array[Vector2i] = []
	for coords in loaded:
		var offset := (coords - focus_chunk).abs()
		if maxi(offset.x, offset.y) > unload_radius:
			to_unload.append(coords)
	return {"load": to_load, "unload": to_unload}
