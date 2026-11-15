class_name MapFog
extends RefCounted
## The fog of war on the world map: land the player has not seen (see Exploration) lies under a
## soft grey fog that dims it and takes much of its colour, and still leaves it readable. Explored
## land is clear. The fog's edge is soft: a tile is as foggy as the share of the tiles about it
## that are unexplored, within SOFT_RADIUS.
##
## It works on a chunk's image, a pixel a tile in RGBA8 (see MapPainter): `foggy` makes the fogged
## look of a clear image once, and `apply` mixes the two by the exploration, which is all a chunk
## needs when the player has walked on.

## How much of its colour the fog takes from the land, 0 to 1.
const DESATURATION := 0.65
## How far the fogged land is pulled to the fog's grey, 0 to 1: the dimming.
const GREYING := 0.5
const FOG_GREY := 0.27
## The fog's edge reaches this many tiles each side of a tile, a box of 2 * SOFT_RADIUS + 1.
const SOFT_RADIUS := 2
## A chunk with its window of SOFT_RADIUS more tiles all round.
const WINDOW := Chunk.CHUNK_SIZE + 2 * SOFT_RADIUS
const CLEAR := 255
const BYTES_PER_PIXEL := 4


## The look of a clear image under the fog.
static func foggy(clear: Image) -> Image:
	var bytes := clear.get_data()
	for offset in range(0, bytes.size(), BYTES_PER_PIXEL):
		# The weights of the eye for red, green and blue, in 256ths.
		var luma := (bytes[offset] * 54 + bytes[offset + 1] * 183 + bytes[offset + 2] * 19) >> 8
		for channel in 3:
			var kept := bytes[offset + channel] * (1.0 - DESATURATION) + luma * DESATURATION
			bytes[offset + channel] = roundi(kept * (1.0 - GREYING) + FOG_GREY * 255.0 * GREYING)
	return Image.create_from_data(
		clear.get_width(), clear.get_height(), false, clear.get_format(), bytes
	)


## The image of a chunk with the fog over the land that is not explored: `clear` and its `foggy`
## look, mixed tile by tile. It is one of the two as they are where the chunk and the chunks about
## it are all unexplored or all explored, which is most of them: do not change what comes back.
static func apply(
	clear: Image, foggy_look: Image, exploration: Exploration, coords: Vector2i
) -> Image:
	var is_all_clear := true
	var is_all_foggy := true
	for step_y in range(-1, 2):
		for step_x in range(-1, 2):
			var around := coords + Vector2i(step_x, step_y)
			is_all_clear = is_all_clear and exploration.is_chunk_full(around)
			is_all_foggy = is_all_foggy and not exploration.is_chunk_touched(around)
	if is_all_clear:
		return clear
	if is_all_foggy:
		return foggy_look
	var clearness := _clearness(exploration, coords)
	var clear_bytes := clear.get_data()
	var foggy_bytes := foggy_look.get_data()
	for tile in clearness.size():
		var share := clearness[tile]
		for channel in 3:
			var offset := tile * BYTES_PER_PIXEL + channel
			var fog_byte := foggy_bytes[offset]
			foggy_bytes[offset] = fog_byte + (clear_bytes[offset] - fog_byte) * share / CLEAR
	return Image.create_from_data(
		clear.get_width(), clear.get_height(), false, clear.get_format(), foggy_bytes
	)


## How clear each tile of a chunk is, 0 to CLEAR: the share of the explored tiles in the box of
## SOFT_RADIUS tiles about it, in the order of the bits.
static func _clearness(exploration: Exploration, coords: Vector2i) -> PackedByteArray:
	var window := _window_around(exploration, coords)
	var box := 2 * SOFT_RADIUS + 1
	# The box is summed along the rows first, then down the columns.
	var row_sums := PackedInt32Array()
	row_sums.resize(WINDOW * Chunk.CHUNK_SIZE)
	for row in WINDOW:
		for column in Chunk.CHUNK_SIZE:
			var sum := 0
			for step in box:
				sum += window[row * WINDOW + column + step]
			row_sums[row * Chunk.CHUNK_SIZE + column] = sum
	var clearness := PackedByteArray()
	clearness.resize(Exploration.TILES_PER_CHUNK)
	for row in Chunk.CHUNK_SIZE:
		for column in Chunk.CHUNK_SIZE:
			var sum := 0
			for step in box:
				sum += row_sums[(row + step) * Chunk.CHUNK_SIZE + column]
			clearness[row * Chunk.CHUNK_SIZE + column] = sum * CLEAR / (box * box)
	return clearness


## The explored tiles (1, else 0) of a chunk and SOFT_RADIUS tiles more all round, row by row.
static func _window_around(exploration: Exploration, coords: Vector2i) -> PackedByteArray:
	var masks: Array[PackedByteArray] = []
	for step_y in range(-1, 2):
		for step_x in range(-1, 2):
			masks.append(exploration.mask_of(coords + Vector2i(step_x, step_y)))
	var window := PackedByteArray()
	window.resize(WINDOW * WINDOW)
	for row in WINDOW:
		var tile_y := row - SOFT_RADIUS
		var local_y := posmod(tile_y, Chunk.CHUNK_SIZE)
		var chunk_row := ((tile_y - local_y) / Chunk.CHUNK_SIZE + 1) * 3
		for column in WINDOW:
			var tile_x := column - SOFT_RADIUS
			var local_x := posmod(tile_x, Chunk.CHUNK_SIZE)
			var mask := masks[chunk_row + (tile_x - local_x) / Chunk.CHUNK_SIZE + 1]
			window[row * WINDOW + column] = mask[local_y * Chunk.CHUNK_SIZE + local_x]
	return window
