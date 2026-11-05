class_name TerrainTileset
extends RefCounted
## The terrain and decoration atlases made by tools/art/generate.py, as one TileSet, plus
## the rules that pick a tile from them.
##
## Dual grid: each terrain layer is offset by half a tile, so the 4 corners of a layer cell
## sit on the centres of 4 world tiles. Layers are stacked by priority, and a layer draws
## the shape given by its mask: which of the 4 corner tiles are on that layer or above.
##
## Grass comes in three looks (ordinary, lush, dry), picked by slow noise across the world
## so the colour shifts gradually. Lush and dry grass are layers drawn over ordinary grass.
##
## Terrain atlas: one row per layer. EDGE_VARIANTS blocks of 15 columns hold the edge
## shapes for masks 0..14 (0 is empty), the columns from FULL_COLUMN on the full-tile
## variants. Decoration atlas: one row per layer, one column per decoration.

## Draw order and atlas row, bottom to top.
enum Layer { WATER, FLOODPLAIN, WETLAND, GRASS, LUSH_GRASS, DRY_GRASS, SOIL }

const TILE_SIZE := 16
const TERRAIN_SOURCE_ID := 0
const DECORATION_SOURCE_ID := 1
const TERRAIN_ATLAS_PATH := "res://assets/terrain.png"
const DECORATION_ATLAS_PATH := "res://assets/decorations.png"

## Corner bits of a mask, as in the generator.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_LEFT := 4
const BOTTOM_RIGHT := 8
const FULL := 15
## Edge-shape variants per mask, as in the generator.
const EDGE_VARIANTS := 3
const FULL_COLUMN := EDGE_VARIANTS * FULL

## A corner whose tile is not loaded.
const MISSING := -1
const NO_DECORATION := Vector2i(-1, -1)

const LAYER_COUNT := 7
## Layer per terrain, indexed by Tile.Terrain. Grass is ordinary grass here; layer_of()
## turns it lush or dry.
const LAYER_OF_TERRAIN: Array[Layer] = [
	Layer.GRASS, Layer.SOIL, Layer.WATER, Layer.WETLAND, Layer.FLOODPLAIN
]
## The layer each layer is drawn over: lush and dry grass need ordinary grass beneath.
const BASE_LAYER: Array[Layer] = [
	Layer.WATER,
	Layer.FLOODPLAIN,
	Layer.WETLAND,
	Layer.GRASS,
	Layer.GRASS,
	Layer.GRASS,
	Layer.SOIL,
]
## Grass is lush where the variety noise is below this, dry where it is above DRY_ABOVE.
const LUSH_BELOW := -0.2
const DRY_ABOVE := 0.25
## Chance of a decoration on a tile: a little everywhere, rising to the cluster chance
## where the cluster noise is above CLUSTER_START, so decorations gather in patches.
const DECORATION_CHANCE := 0.02
const CLUSTER_DECORATION_CHANCE := 0.5
const CLUSTER_START := 0.15

var tile_set := TileSet.new()
## The atlas sources, to swap their pictures when the season changes.
var _terrain_source: TileSetAtlasSource
var _decoration_source: TileSetAtlasSource
var _full_variant_counts: Array[int] = []
var _decoration_counts: Array[int] = []


## Builds a tile for every non-empty atlas cell, so the generator alone decides how many
## variants and decorations each layer has.
func _init() -> void:
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_terrain_source = _atlas_source(TERRAIN_ATLAS_PATH, FULL_COLUMN, _full_variant_counts)
	tile_set.add_source(_terrain_source, TERRAIN_SOURCE_ID)
	_decoration_source = _atlas_source(DECORATION_ATLAS_PATH, 0, _decoration_counts)
	tile_set.add_source(_decoration_source, DECORATION_SOURCE_ID)
	for layer in LAYER_COUNT:
		assert(_full_variant_counts[layer] > 0, "Terrain atlas row %d has no full tile" % layer)


## Shows the season's pictures. Every season's atlases have the same layout, so the tiles
## stay and the tile maps redraw with the new texture.
func set_season(season: GameClock.Season) -> void:
	_terrain_source.texture = load(SeasonalArt.path(TERRAIN_ATLAS_PATH, season))
	_decoration_source.texture = load(SeasonalArt.path(DECORATION_ATLAS_PATH, season))


## Which layer a world tile is drawn on. `variety` is the slow variety noise at the tile.
static func layer_of(terrain: Tile.Terrain, variety: float) -> int:
	var layer := LAYER_OF_TERRAIN[terrain]
	if layer == Layer.GRASS and variety < LUSH_BELOW:
		return Layer.LUSH_GRASS
	if layer == Layer.GRASS and variety > DRY_ABOVE:
		return Layer.DRY_GRASS
	return layer


## The layers a cell draws, as bits (1 << layer): only its corners' own layers and what
## they are drawn over. Lower layers are hidden under the lowest corner's full tile, and
## a layer between two corner terrains would peek out from under the upper one's edge.
static func drawn_layers(corners: PackedInt32Array) -> int:
	var layers := 0
	for layer in corners:
		layers |= 1 << layer | 1 << BASE_LAYER[layer]
	return layers


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


## The one place a (layer, mask) becomes a look. Variants come from the cell's position,
## so the choice is stable but does not repeat visibly. Every layer of a cell picks the
## same edge variant: lush and dry grass share their shapes with ordinary grass, and only
## stay inside it when the variant matches.
func atlas_cell(layer: int, mask: int, cell: Vector2i) -> Vector2i:
	var roll := PositionHash.of(cell)
	if mask != FULL:
		return Vector2i(roll % EDGE_VARIANTS * FULL + mask, layer)
	return Vector2i(FULL_COLUMN + roll % _full_variant_counts[layer], layer)


## The decoration on a world tile of `layer`, or NO_DECORATION. `cluster` is the
## decoration cluster noise at the tile.
func decoration_cell(layer: int, tile_pos: Vector2i, cluster: float) -> Vector2i:
	var count := _decoration_counts[layer]
	if count == 0:
		return NO_DECORATION
	var in_cluster := clampf((cluster - CLUSTER_START) * 3.0, 0.0, 1.0)
	var chance := lerpf(DECORATION_CHANCE, CLUSTER_DECORATION_CHANCE, in_cluster)
	# A different roll than atlas_cell's, so decorations don't follow the variants.
	var roll := PositionHash.of(tile_pos, 1)
	if roll % 1000 >= chance * 1000:
		return NO_DECORATION
	return Vector2i(roll / 1000 % count, layer)


## An atlas source with a tile for every non-empty cell of the image. Appends, per row,
## how many tiles sit at or right of `counted_from` to `counts`.
static func _atlas_source(
	path: String, counted_from: int, counts: Array[int]
) -> TileSetAtlasSource:
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for row in LAYER_COUNT:
		var count := 0
		for column in image.get_width() / TILE_SIZE:
			var region := Rect2i(column * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if image.get_region(region).is_invisible():
				continue
			source.create_tile(Vector2i(column, row))
			if column >= counted_from:
				count += 1
		counts.append(count)
	return source
