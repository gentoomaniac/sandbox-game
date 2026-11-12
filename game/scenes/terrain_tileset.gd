class_name TerrainTileset
extends RefCounted
## The terrain and decoration atlases made by tools/art/terrain.py, as one TileSet, plus
## the rules that pick a tile from them.
##
## Dual grid: each terrain layer is offset by half a tile, so the 4 corners of a layer cell
## sit on the centres of 4 world tiles. Layers are stacked by priority, and a layer draws
## the shape given by its mask: which of the 4 corner tiles are on that layer or above.
##
## Grass comes in three looks (ordinary, lush, dry), picked by slow noise across the world
## so the colour shifts gradually. Lush and dry grass are layers drawn over ordinary grass.
## Grass walked often wears to a desire path (see World.wear_stage): trodden grass, then a
## path, two layers over any grass (and the floodplain) that fade into it. The tidal mud lies
## just over the water, so the tideways are water cut into it; it looks the same in every
## season and weather, as the tide washes it. The salt marsh is a grass too, drawn over ordinary
## grass like the lush and dry grass, with seasons of its own: red-purple in autumn. A Warft (a
## dwelling mound) is grass over grass too, whose edges are its slopes.
##
## Terrain atlas: one row per layer. EDGE_VARIANTS blocks of 15 columns hold the edge
## shapes for masks 0..14 (0 is empty), the columns from FULL_COLUMN on the full-tile
## variants. Decoration atlas: one row per layer, one column per decoration, and below them the
## row of meadow flowers (FLOWER_ROW).

## Draw order and atlas row, bottom to top.
enum Layer {
	WATER,
	MUD,
	FLOODPLAIN,
	WETLAND,
	GRASS,
	SALT_MARSH,
	WARFT,
	LUSH_GRASS,
	DRY_GRASS,
	TRODDEN,
	PATH,
	SOIL,
}
## The tiles of a meadow flower (see FLOWER_ROW).
enum FlowerVariant { SMALL, FEW, DRIFT, OTHER_DRIFT }

## World pixels per tile: the size of a tile in art pixels.
const TILE_SIZE := 32
## World pixels per pixel of the 16 px art. Since task 111 only the classic art (F7, task 117) is
## drawn at 16 px per tile and scaled up (DOUBLED in tools/art/classic/generate.py); a few game
## numbers are still written as 16 px numbers times this (see docs/art-style.md).
@warning_ignore("integer_division") const ART_16_SCALE := TILE_SIZE / 16
## The tile set has the summer atlases only: the other looks of the ground are read by the
## ground shader for their colours (see GroundLook), as they have the same layout.
const TERRAIN_SOURCE_ID := 0
const DECORATION_SOURCE_ID := 1
const TERRAIN_ATLAS_PATH := "res://assets/terrain.png"
const DECORATION_ATLAS_PATH := "res://assets/decorations.png"
## The few reddish-grey pixels that hint at a clay spot: one tile, the same in every look.
const CLAY_HINT_PATH := "res://assets/clay_hint.png"
const CLAY_HINT_SOURCE_ID := 2

## Corner bits of a mask, as in the generator.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_LEFT := 4
const BOTTOM_RIGHT := 8
const FULL := 15
## Edge-shape variants per mask, as in the generator.
const EDGE_VARIANTS := 3
const FULL_COLUMN := EDGE_VARIANTS * FULL

## The layer of a corner whose tile is not loaded.
const MISSING := -1
const NO_DECORATION := Vector2i(-1, -1)

const LAYER_COUNT := 12
## The row of the decoration atlas with the meadow flowers: FLOWER_VARIANTS columns per species
## of FLOWER_SPECIES, in that order (see tools/art/flowers.py): a small plant, a few, and two
## tiles of the thick of a drift.
const FLOWER_ROW := LAYER_COUNT
const FLOWER_SPECIES: Array[StringName] = [
	&"wood_anemone",
	&"dandelion",
	&"cuckooflower",
	&"daisy",
	&"buttercup",
	&"red_campion",
	&"thrift",
	&"red_clover",
	&"white_clover",
	&"yarrow",
	&"knapweed",
	&"meadowsweet",
	&"sea_lavender",
	&"heather",
]
const FLOWER_VARIANTS := 4
## Layer per terrain of the world (interiors are not drawn here). Grass is ordinary grass here;
## terrain_layer() turns it lush or dry.
const LAYER_OF_TERRAIN: Dictionary[Tile.Terrain, Layer] = {
	Tile.Terrain.GRASS: Layer.GRASS,
	Tile.Terrain.SOIL: Layer.SOIL,
	Tile.Terrain.WATER: Layer.WATER,
	Tile.Terrain.SEA: Layer.WATER,
	Tile.Terrain.WETLAND: Layer.WETLAND,
	Tile.Terrain.FLOODPLAIN: Layer.FLOODPLAIN,
	Tile.Terrain.MUD: Layer.MUD,
	Tile.Terrain.SALT_MARSH: Layer.SALT_MARSH,
	Tile.Terrain.WARFT: Layer.WARFT,
}
## The layer each layer is drawn over: the salt marsh, the Warft, lush and dry grass need ordinary
## grass beneath.
const BASE_LAYER: Array[Layer] = [
	Layer.WATER,
	Layer.MUD,
	Layer.FLOODPLAIN,
	Layer.WETLAND,
	Layer.GRASS,
	Layer.GRASS,
	Layer.GRASS,
	Layer.GRASS,
	Layer.GRASS,
	Layer.TRODDEN,
	Layer.PATH,
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

## The Vegetation kind of each decoration, per layer, in the order of the atlas row (see
## tools/art/terrain.py). &"" is a decoration that is there all year (pebbles, reeds); a
## layer that is not listed has only those. The flowers are not among them: they have a row of
## their own (FLOWER_ROW).
const DECORATION_KINDS := {
	Layer.GRASS: [&"small_plant", &"", &"small_plant", &"tuft", &"tuft", &"leaves"],
	Layer.LUSH_GRASS: [&"small_plant", &"small_plant", &"small_plant", &"small_plant", &"leaves"],
	Layer.DRY_GRASS: [&"tuft", &"", &"tuft", &"", &"leaves"],
	Layer.SALT_MARSH: [&"glasswort", &"glasswort", &"", &"glasswort"],
	Layer.WARFT: [&"tuft", &"tuft"],
}

var tile_set := TileSet.new()
var _full_variant_counts: Array[int] = []
var _decoration_counts: Array[int] = []
## Whether the atlases shown are the classic art's (see ArtSet).
var _is_classic := ArtSet.is_classic


## Builds a tile for every non-empty atlas cell, so the generator alone decides how many
## variants and decorations each layer has. Every look's atlases have the same layout, and so do
## the classic art's (see `show_art_set`). The decorations that move get the materials of
## `motion` (none without it).
func _init(motion: AmbientMotion = null) -> void:
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var counts: Array[int] = []
	tile_set.add_source(
		_atlas_source(ArtSet.path(TERRAIN_ATLAS_PATH), FULL_COLUMN, counts), TERRAIN_SOURCE_ID
	)
	_full_variant_counts = counts
	var decorations := _atlas_source(
		ArtSet.path(DECORATION_ATLAS_PATH), 0, _decoration_counts, LAYER_COUNT + 1
	)
	if motion != null:
		_set_motion(decorations, motion)
	tile_set.add_source(decorations, DECORATION_SOURCE_ID)
	var clay_hint := TileSetAtlasSource.new()
	clay_hint.texture = load(ArtSet.path(CLAY_HINT_PATH))
	clay_hint.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	clay_hint.create_tile(Vector2i.ZERO)
	tile_set.add_source(clay_hint, CLAY_HINT_SOURCE_ID)
	for layer in LAYER_COUNT:
		assert(_full_variant_counts[layer] > 0, "Terrain atlas row %d has no full tile" % layer)


## Shows the atlases of the chosen art set (see ArtSet), if they are not shown yet. Both sets have
## the same tiles (tests/test_terrain_tileset.gd), so the tiles stay and only their pictures
## change: the maps drawn with them need no redraw.
func show_art_set() -> void:
	if _is_classic == ArtSet.is_classic:
		return
	_is_classic = ArtSet.is_classic
	var terrain: TileSetAtlasSource = tile_set.get_source(TERRAIN_SOURCE_ID)
	terrain.texture = load(ArtSet.path(TERRAIN_ATLAS_PATH))
	var decorations: TileSetAtlasSource = tile_set.get_source(DECORATION_SOURCE_ID)
	decorations.texture = load(ArtSet.path(DECORATION_ATLAS_PATH))
	var clay_hint: TileSetAtlasSource = tile_set.get_source(CLAY_HINT_SOURCE_ID)
	clay_hint.texture = load(ArtSet.path(CLAY_HINT_PATH))


## Which layer a world tile is drawn on. `variety` is the slow variety noise at the tile, and
## `wear` how worn its grass is (World.wear_stage; only ground that wears is ever worn).
static func terrain_layer(
	terrain: Tile.Terrain, variety: float, wear := PathRules.Stage.UNWORN
) -> int:
	if wear == PathRules.Stage.TRODDEN:
		return Layer.TRODDEN
	if wear == PathRules.Stage.PATH:
		return Layer.PATH
	var layer := LAYER_OF_TERRAIN[terrain]
	if layer == Layer.GRASS and variety < LUSH_BELOW:
		return Layer.LUSH_GRASS
	if layer == Layer.GRASS and variety > DRY_ABOVE:
		return Layer.DRY_GRASS
	return layer


## The middle of a tile, in world pixels.
static func tile_centre(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE


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
## decoration cluster noise at the tile. Tilled soil has none: the decorations of its row are the
## weeds of soil left fallow, which only the soil's state brings up.
func decoration_cell(layer: int, tile_pos: Vector2i, cluster: float) -> Vector2i:
	var count := _decoration_counts[layer]
	if count == 0 or layer == Layer.SOIL:
		return NO_DECORATION
	var in_cluster := clampf((cluster - CLUSTER_START) * 3.0, 0.0, 1.0)
	var chance := lerpf(DECORATION_CHANCE, CLUSTER_DECORATION_CHANCE, in_cluster)
	# A different roll than atlas_cell's, so decorations don't follow the variants.
	var roll := PositionHash.of(tile_pos, 1)
	if roll % 1000 >= chance * 1000:
		return NO_DECORATION
	return Vector2i(roll / 1000 % count, layer)


## The weeds on a tile of tilled soil left fallow (see FallowSoil): one of the decorations of the
## soil's row, by the tile.
func weed_cell(tile_pos: Vector2i) -> Vector2i:
	var roll := PositionHash.of(tile_pos, 1)
	return Vector2i(roll % _decoration_counts[Layer.SOIL], Layer.SOIL)


## The decoration atlas cell of a meadow flower of FLOWER_SPECIES.
static func flower_cell(species: StringName, variant: FlowerVariant) -> Vector2i:
	var index := FLOWER_SPECIES.find(species)
	assert(index >= 0, "No flower species: %s" % species)
	return Vector2i(index * FLOWER_VARIANTS + variant, FLOWER_ROW)


## The Vegetation kind of a decoration (an atlas cell from `decoration_cell`), or &"" if it
## shows all year.
static func decoration_kind(atlas_cell: Vector2i) -> StringName:
	var kinds: Array = DECORATION_KINDS.get(atlas_cell.y, [])
	return kinds[atlas_cell.x] if not kinds.is_empty() else &""


## Puts the materials of `motion` on the decoration tiles that move.
static func _set_motion(decorations: TileSetAtlasSource, motion: AmbientMotion) -> void:
	# The motion shaders find a pixel's place in its tile from its texture coordinates.
	decorations.use_texture_padding = false
	for index in decorations.get_tiles_count():
		var atlas_cell := decorations.get_tile_id(index)
		decorations.get_tile_data(atlas_cell, 0).material = motion.decoration_material(atlas_cell)


## An atlas source with a tile for every non-empty cell of the first `rows` rows of the image.
## Appends, per row, how many tiles sit at or right of `counted_from` to `counts`.
static func _atlas_source(
	path: String, counted_from: int, counts: Array[int], rows := LAYER_COUNT
) -> TileSetAtlasSource:
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	var source := TileSetAtlasSource.new()
	source.texture = texture
	# The ground shaders find the same pixel in the atlases of the other looks by its coordinates.
	source.use_texture_padding = false
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for row in rows:
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
