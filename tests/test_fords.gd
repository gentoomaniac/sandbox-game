extends GutTest
## Fords (issue #96): floodplain where a creek runs shallow over its stones. Fords knows them, and
## nobody leaves footprints in their water, in snow or in the rain's mud.

const SEED := 1

var _world: World
var _ford: Vector2i


func before_each() -> void:
	_world = World.new(SEED)
	_ford = _find_ford()
	_world.add_chunk(Chunk.new(Chunk.world_to_chunk(_ford), Tile.Terrain.FLOODPLAIN))


## A ford of the world's creeks, away from the river's own water.
func _find_ford() -> Vector2i:
	var generator := WorldGenerator.new(SEED)
	for x in range(0, 960):
		for y in range(-420, 420):
			var tile := Vector2i(x, y)
			if generator.is_ford(tile) and generator.terrain_at(tile) == Tile.Terrain.FLOODPLAIN:
				return tile
	fail_test("no ford in seed %d" % SEED)
	return Vector2i.ZERO


## A floodplain tile of the same chunk that is no ford.
func _plain_floodplain() -> Vector2i:
	var generator := WorldGenerator.new(SEED)
	var origin := Chunk.to_world(Chunk.world_to_chunk(_ford), Vector2i.ZERO)
	for index in Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE:
		var tile := origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE)
		if not generator.is_ford(tile):
			return tile
	fail_test("the whole chunk is a ford")
	return origin


func test_a_ford_is_one_only_while_it_is_floodplain() -> void:
	assert_true(Fords.is_ford(_world, _ford))
	assert_false(Fords.is_ford(_world, _plain_floodplain()))
	_world.set_terrain(_ford, Tile.Terrain.SOIL)
	assert_false(Fords.is_ford(_world, _ford), "tilled")


func test_a_ford_of_a_chunk_not_loaded_is_none() -> void:
	var far := _ford + Vector2i(Chunk.CHUNK_SIZE * 3, 0)
	assert_false(Fords.is_ford(_world, far))


func test_nobody_leaves_footprints_in_a_ford() -> void:
	_world.footprints.is_snowed_at = func(_tile: Vector2i) -> bool: return true
	assert_eq(_world.footprints.kind_at(_world, _ford), Footprints.Kind.NONE)
	assert_eq(_world.footprints.kind_at(_world, _plain_floodplain()), Footprints.Kind.SNOW)


func test_nor_in_the_rain_once_it_is_trodden() -> void:
	var rules := PathRules.default_rules()
	_world.set_wear_days(_ford, rules.path_after_days())
	_world.set_muddy(true)
	assert_eq(_world.footprints.kind_at(_world, _ford), Footprints.Kind.NONE)


func test_a_ford_is_drawn_as_the_ford_however_worn_or_muddy() -> void:
	for wear in [PathRules.Stage.UNWORN, PathRules.Stage.TRODDEN, PathRules.Stage.PATH]:
		for is_muddy in [false, true]:
			assert_eq(
				TerrainTileset.terrain_layer(Tile.Terrain.FLOODPLAIN, 0.0, wear, is_muddy, true),
				TerrainTileset.Layer.FORD
			)


func test_the_ford_lies_over_the_water_and_under_the_bank() -> void:
	var water := TerrainTileset.Layer.WATER
	var ford := TerrainTileset.Layer.FORD
	var bank := TerrainTileset.Layer.FLOODPLAIN
	assert_eq(ford, water + 1)
	assert_lt(ford, bank)
	# A ford beside the creek's water and its bank: the water, the ford's edge and the bank's.
	var drawn := TerrainTileset.drawn_layers(PackedInt32Array([ford, water, bank, ford]))
	assert_eq(drawn, 1 << water | 1 << ford | 1 << bank)
	var corners := PackedInt32Array([ford, water, bank, water])
	assert_eq(
		TerrainTileset.mask_for(corners, ford), TerrainTileset.TOP_LEFT | TerrainTileset.BOTTOM_LEFT
	)
	# The river's banks have no ford under them.
	drawn = TerrainTileset.drawn_layers(PackedInt32Array([water, water, bank, bank]))
	assert_eq(drawn & (1 << ford), 0)


func test_a_ford_has_no_decorations() -> void:
	var tileset := TerrainTileset.new()
	for x in 50:
		assert_eq(
			tileset.decoration_cell(TerrainTileset.Layer.FORD, Vector2i(x, 0), 1.0),
			TerrainTileset.NO_DECORATION
		)
