class_name TerrainTileset
extends RefCounted
## The terrain atlas made by tools/art/generate.py, as a TileSet, plus the dual-grid rules
## that pick a tile from it.
##
## Dual grid: each terrain layer is offset by half a tile, so the 4 corners of a layer cell
## sit on the centres of 4 world tiles. Terrains are stacked by priority, and a layer draws
## the shape given by its mask: which of the 4 corner tiles are on that layer or above.
##
## Atlas layout: one row per layer, bottom to top. Columns 0..14 hold the edge shapes for
## masks 0..14 (0 is empty), columns from FULL on hold the full-tile variants.

## Draw order and atlas row, bottom to top.
enum Layer { WATER, FLOODPLAIN, WETLAND, GRASS, SOIL }

const TILE_SIZE := 16
const SOURCE_ID := 0
const ATLAS_PATH := "res://assets/terrain.png"

## Corner bits of a mask, as in the generator.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_LEFT := 4
const BOTTOM_RIGHT := 8
const FULL := 15

## A corner whose tile is not loaded.
const MISSING := -1

const LAYER_COUNT := 5
## Layer per terrain, indexed by Tile.Terrain.
const LAYER_OF_TERRAIN: Array[Layer] = [
	Layer.GRASS, Layer.SOIL, Layer.WATER, Layer.WETLAND, Layer.FLOODPLAIN
]

var tile_set := TileSet.new()
var _full_variant_counts: Array[int] = []


## Builds a tile for every non-empty atlas cell, so the generator alone decides how many
## full variants each layer has.
func _init() -> void:
	var texture: Texture2D = load(ATLAS_PATH)
	var image := texture.get_image()
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var columns := image.get_width() / TILE_SIZE
	for layer in LAYER_COUNT:
		var full_variants := 0
		for column in columns:
			var region := Rect2i(column * TILE_SIZE, layer * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if image.get_region(region).is_invisible():
				continue
			source.create_tile(Vector2i(column, layer))
			if column >= FULL:
				full_variants += 1
		assert(full_variants > 0, "Atlas row %d has no full tile" % layer)
		_full_variant_counts.append(full_variants)
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, SOURCE_ID)


## Which corners are on `layer` or above. `corners` holds the layers of the top-left,
## top-right, bottom-left and bottom-right tile.
static func mask_for(corners: PackedInt32Array, layer: int) -> int:
	var mask := 0
	if corners[0] >= layer:
		mask |= TOP_LEFT
	if corners[1] >= layer:
		mask |= TOP_RIGHT
	if corners[2] >= layer:
		mask |= BOTTOM_LEFT
	if corners[3] >= layer:
		mask |= BOTTOM_RIGHT
	return mask


## Replaces MISSING corners with a loaded neighbour in the same cell: the one beside it,
## else the one above or below, else the diagonal one. That makes the terrain simply run on
## into a chunk that is not loaded yet, until it loads and the cell is redrawn.
static func fill_missing_corners(corners: PackedInt32Array) -> void:
	if not corners.has(MISSING):
		return
	var loaded := corners.duplicate()
	for corner in 4:
		if loaded[corner] != MISSING:
			continue
		# Corner index bit 0 is the column and bit 1 the row, so XOR finds neighbours.
		for partner: int in [corner ^ 1, corner ^ 2, corner ^ 3]:
			if loaded[partner] != MISSING:
				corners[corner] = loaded[partner]
				break


## The one place a (layer, mask) becomes a look. Full tiles pick a variant from the cell's
## position, so the choice is stable but does not repeat visibly.
func atlas_cell(layer: int, mask: int, cell: Vector2i) -> Vector2i:
	if mask != FULL:
		return Vector2i(mask, layer)
	return Vector2i(FULL + hash(cell) % _full_variant_counts[layer], layer)
