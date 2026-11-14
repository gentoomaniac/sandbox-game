extends GutTest
## World.change_count: it rises when something happens that can open or close a way (an object,
## the terrain, a building, a chunk loading or unloading), and not when grass is merely worn.

const SEED := 7
const CHUNK := Vector2i(20, 20)

var _world: World
var _tile := Chunk.to_world(CHUNK, Vector2i(8, 8))


func before_each() -> void:
	_world = World.new(SEED)
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(CHUNK))
	for y in range(-1, 8):
		for x in range(-1, 8):
			_world.remove_object(_tile + Vector2i(x, y))
			_world.set_terrain(_tile + Vector2i(x, y), Tile.Terrain.GRASS)


func test_an_object_put_there_or_taken_away_counts() -> void:
	var before := _world.change_count
	_world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, _tile))
	assert_gt(_world.change_count, before)
	before = _world.change_count
	_world.remove_object(_tile)
	assert_gt(_world.change_count, before)


func test_a_change_of_terrain_counts() -> void:
	var before := _world.change_count
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	assert_gt(_world.change_count, before)


func test_a_building_put_up_or_taken_down_counts() -> void:
	var before := _world.change_count
	var building := _world.place_building(BuildingTypes.SHACK, _tile)
	assert_not_null(building)
	assert_gt(_world.change_count, before)
	before = _world.change_count
	_world.remove_building(building)
	assert_gt(_world.change_count, before)


func test_a_chunk_loading_or_unloading_counts() -> void:
	var before := _world.change_count
	_world.add_chunk(WorldGenerator.new(SEED).generate_chunk(CHUNK + Vector2i.RIGHT))
	assert_gt(_world.change_count, before)
	before = _world.change_count
	_world.remove_chunk(CHUNK + Vector2i.RIGHT)
	assert_gt(_world.change_count, before)


func test_grass_wearing_does_not_count() -> void:
	var before := _world.change_count
	_world.wear_tile(_tile, 1.0)
	assert_eq(_world.change_count, before)


func test_an_interior_counts_its_objects() -> void:
	var room := Interior.new()
	room.set_terrain(Vector2i.ZERO, Tile.Terrain.FLOOR)
	var before := room.change_count
	room.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, Vector2i.ZERO))
	assert_gt(room.change_count, before)
