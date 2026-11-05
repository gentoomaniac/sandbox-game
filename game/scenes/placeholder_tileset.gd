class_name PlaceholderTileset
extends RefCounted
## Flat-colour stand-in for the real tileset. The atlas has one tile per terrain in a
## single row, in Tile.Terrain order. Real art replaces build() and keeps atlas_cell();
## a normal-map texture can later be added as a second layer of the same atlas source.

const TILE_SIZE := 16
const SOURCE_ID := 0
## Indexed by Tile.Terrain.
const COLORS: Array[Color] = [
	Color("5a9e4b"),  # grass
	Color("7a5230"),  # soil
	Color("2f6fb5"),  # water
	Color("4a7a64"),  # wetland
	Color("a8b46a"),  # floodplain
]


## Where a terrain's tile sits in the atlas.
static func atlas_cell(terrain: Tile.Terrain) -> Vector2i:
	return Vector2i(terrain, 0)


static func build() -> TileSet:
	var image := Image.create_empty(TILE_SIZE * COLORS.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	for terrain in COLORS.size():
		image.fill_rect(Rect2i(terrain * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE), COLORS[terrain])

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for terrain in COLORS.size():
		source.create_tile(atlas_cell(terrain as Tile.Terrain))

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, SOURCE_ID)
	return tile_set
