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
##
## Terrain atlas: one row per layer. EDGE_VARIANTS blocks of 15 columns hold the edge
## shapes for masks 0..14 (0 is empty), the columns from FULL_COLUMN on the full-tile
## variants. Decoration atlas: one row per layer, one column per decoration, and below them the
## row of meadow flowers (FLOWER_ROW).

## Draw order and atlas row, bottom to top.
enum Layer { WATER, FLOODPLAIN, WETLAND, GRASS, LUSH_GRASS, DRY_GRASS, TRODDEN, PATH, SOIL }
## The tiles of a meadow flower (see FLOWER_ROW).
enum FlowerVariant { SMALL, FEW, DRIFT, OTHER_DRIFT }

const TILE_SIZE := 16
## Every look of the ground (see SeasonBlend.GROUND_LOOKS) has an atlas source of its own with
## the same tiles: the terrain source's id is the look, the decoration source's id is this far
## on from it.
const DECORATION_SOURCE_OFFSET := 10
const TERRAIN_ATLAS_PATH := "res://assets/terrain.png"
const DECORATION_ATLAS_PATH := "res://assets/decorations.png"
## The few reddish-grey pixels that hint at a clay spot: one tile, the same in every look.
const CLAY_HINT_PATH := "res://assets/clay_hint.png"
const CLAY_HINT_SOURCE_ID := 2 * DECORATION_SOURCE_OFFSET

## Corner bits of a mask, as in the generator.
const TOP_LEFT := 1
const TOP_RIGHT := 2
const BOTTOM_LEFT := 4
const BOTTOM_RIGHT := 8
const FULL := 15
## Edge-shape variants per mask, as in the generator.
const EDGE_VARIANTS := 3
const FULL_COLUMN := EDGE_VARIANTS * FULL

## The code of a tile packs what its drawing needs into one int, so a corner of a cell is one
## value to read, fill in and pass on:
##   bits 0-3   the layer (Layer, 0..8)
##   bits 4-7   the look it has by the season (SeasonBlend.Look, 0..8)
##   bits 8-11  the look over it by the weather (SeasonBlend.Look: FROST, DUSTING, SNOW, or
##              SUMMER for none)
const LAYER_BITS := 4
const LOOK_BITS := 4
const SEASON_SHIFT := LAYER_BITS
const WEATHER_SHIFT := SEASON_SHIFT + LOOK_BITS
const LAYER_MASK := (1 << LAYER_BITS) - 1
const LOOK_MASK := (1 << LOOK_BITS) - 1

## The code of a corner whose tile is not loaded. It is no packed code (it has all bits set),
## so check for it before reading a field.
const MISSING := -1
const NO_DECORATION := Vector2i(-1, -1)

const LAYER_COUNT := 9
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
	&"red_clover",
	&"white_clover",
	&"yarrow",
	&"knapweed",
	&"meadowsweet",
	&"heather",
]
const FLOWER_VARIANTS := 4
## Layer per terrain, indexed by Tile.Terrain. Grass is ordinary grass here; terrain_layer()
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
	Layer.TRODDEN,
	Layer.PATH,
	Layer.SOIL,
]
## The looks drawn over the base terrain (which is the summer look), bottom to top: a tile in
## one of them has that look's tile drawn over it, shaped by the same dual-grid masks as a
## terrain layer, so the looks fade into each other with soft edges.
const OVERLAY_LOOKS: Array[SeasonBlend.Look] = [
	SeasonBlend.Look.SPRING,
	SeasonBlend.Look.AUTUMN,
	SeasonBlend.Look.BARE,
	SeasonBlend.Look.FROST,
	SeasonBlend.Look.DUSTING,
	SeasonBlend.Look.SNOW,
]
## The layers of grass that are drawn over ordinary grass.
const VARIETY_LAYERS: Array[Layer] = [Layer.LUSH_GRASS, Layer.DRY_GRASS]
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
}

var tile_set := TileSet.new()
var _full_variant_counts: Array[int] = []
var _decoration_counts: Array[int] = []


## Builds a tile for every non-empty atlas cell, so the generator alone decides how many
## variants and decorations each layer has. Every look's atlases have the same layout. The
## decorations that move get the materials of `motion` (none without it).
func _init(motion: AmbientMotion = null) -> void:
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for look: SeasonBlend.Look in SeasonBlend.GROUND_LOOKS:
		var counts: Array[int] = []
		tile_set.add_source(
			_atlas_source(SeasonalArt.path(TERRAIN_ATLAS_PATH, look), FULL_COLUMN, counts),
			terrain_source_id(look)
		)
		if look == SeasonBlend.Look.SUMMER:
			_full_variant_counts = counts
		var no_counts: Array[int] = []
		var decorations := _atlas_source(
			SeasonalArt.path(DECORATION_ATLAS_PATH, look), 0, no_counts, LAYER_COUNT + 1
		)
		if motion != null:
			_set_motion(decorations, motion)
		tile_set.add_source(decorations, decoration_source_id(look))
		if look == SeasonBlend.Look.SUMMER:
			_decoration_counts = no_counts
	var clay_hint := TileSetAtlasSource.new()
	clay_hint.texture = load(CLAY_HINT_PATH)
	clay_hint.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	clay_hint.create_tile(Vector2i.ZERO)
	tile_set.add_source(clay_hint, CLAY_HINT_SOURCE_ID)
	for layer in LAYER_COUNT:
		assert(_full_variant_counts[layer] > 0, "Terrain atlas row %d has no full tile" % layer)


static func terrain_source_id(look: SeasonBlend.Look) -> int:
	return look


static func decoration_source_id(look: SeasonBlend.Look) -> int:
	return DECORATION_SOURCE_OFFSET + look


## Which layer a world tile is drawn on. `variety` is the slow variety noise at the tile.
static func terrain_layer(terrain: Tile.Terrain, variety: float) -> int:
	var layer := LAYER_OF_TERRAIN[terrain]
	if layer == Layer.GRASS and variety < LUSH_BELOW:
		return Layer.LUSH_GRASS
	if layer == Layer.GRASS and variety > DRY_ABOVE:
		return Layer.DRY_GRASS
	return layer


## The middle of a tile, in world pixels.
static func tile_centre(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE


## The code of a tile (see MISSING for the bit fields).
static func tile_code(
	layer: int, season_look: SeasonBlend.Look, weather_look: SeasonBlend.Look
) -> int:
	return layer | season_look << SEASON_SHIFT | weather_look << WEATHER_SHIFT


## The layer of a tile code, or MISSING for MISSING.
static func layer_of(code: int) -> int:
	return MISSING if code == MISSING else code & LAYER_MASK


## The look by the season of a tile code (not for MISSING).
static func season_of(code: int) -> SeasonBlend.Look:
	return (code >> SEASON_SHIFT & LOOK_MASK) as SeasonBlend.Look


## The look by the weather of a tile code (not for MISSING).
static func weather_of(code: int) -> SeasonBlend.Look:
	return (code >> WEATHER_SHIFT & LOOK_MASK) as SeasonBlend.Look


## The layers of the 4 corner codes, MISSING where a corner is.
static func layers_of(codes: PackedInt32Array) -> PackedInt32Array:
	var layers := PackedInt32Array()
	for code in codes:
		layers.append(layer_of(code))
	return layers


## Whether an overlay look comes from the weather (snow, frost) and not the season.
static func is_weather_look(look: SeasonBlend.Look) -> bool:
	return (
		look == SeasonBlend.Look.FROST
		or look == SeasonBlend.Look.DUSTING
		or look == SeasonBlend.Look.SNOW
	)


## The season look a tile shows, given the look its place has by the season (see SeasonBlend)
## and its layer: the foliage of the seasons on all land the plough has not turned; water and
## tilled soil keep the summer look.
static func shown_season_look(layer: int, season_look: SeasonBlend.Look) -> SeasonBlend.Look:
	if layer == Layer.WATER or layer == Layer.SOIL or layer == MISSING:
		return SeasonBlend.Look.SUMMER
	return season_look


## The weather look a tile shows (SeasonBlend.Look.SUMMER for none): snow and frost cover any
## land.
static func shown_weather_look(layer: int, weather_look: SeasonBlend.Look) -> SeasonBlend.Look:
	if layer == Layer.WATER or layer == MISSING:
		return SeasonBlend.Look.SUMMER
	return weather_look


## The look a tile shows as a whole.
static func shown_look(
	layer: int, season_look: SeasonBlend.Look, weather_look: SeasonBlend.Look
) -> SeasonBlend.Look:
	var weather := shown_weather_look(layer, weather_look)
	return weather if weather != SeasonBlend.Look.SUMMER else shown_season_look(layer, season_look)


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
