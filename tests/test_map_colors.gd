extends GutTest
## The colour a tile has on the maps of the land: the topmost thing on it.

var _world: World
var _chunk: Chunk


func before_each() -> void:
	_world = World.new(7)
	_chunk = Chunk.new(Vector2i.ZERO)
	_world.add_chunk(_chunk)


func test_the_ground_has_the_colour_of_its_terrain() -> void:
	_chunk.set_terrain(Vector2i(1, 1), Tile.Terrain.SEA)
	_chunk.set_terrain(Vector2i(2, 1), Tile.Terrain.MUD)

	assert_eq(
		MapColors.of_tile(_world, _chunk, Vector2i(1, 1)),
		MapColors.TERRAIN_COLORS[Tile.Terrain.SEA]
	)
	assert_eq(
		MapColors.of_tile(_world, _chunk, Vector2i(2, 1)),
		MapColors.TERRAIN_COLORS[Tile.Terrain.MUD]
	)
	assert_eq(
		MapColors.of_tile(_world, _chunk, Vector2i(3, 1)),
		MapColors.TERRAIN_COLORS[Tile.Terrain.GRASS]
	)


func test_an_object_is_over_the_ground() -> void:
	_chunk.add_object(WorldObject.new(WorldObjectTypes.OAK, Vector2i(4, 4)))

	assert_eq(MapColors.of_tile(_world, _chunk, Vector2i(4, 4)), MapColors.OBJECT_COLORS[&"oak"])


func test_a_building_is_over_an_object() -> void:
	var building := _world.place_building(BuildingTypes.SHACK, Vector2i(10, 10))
	assert_not_null(building)

	assert_eq(MapColors.of_tile(_world, _chunk, Vector2i(10, 10)), MapColors.BUILDING)


func test_worn_ground_is_not_grass_green() -> void:
	for day in 12:
		for step in 40:
			_world.wear_tile(Vector2i(6, 6))
		_world.end_wear_day()

	assert_eq(MapColors.of_tile(_world, _chunk, Vector2i(6, 6)), MapColors.WORN)


func test_a_ford_is_not_the_floodplain_it_lies_on() -> void:
	var ford := _first_ford()
	var chunk := Chunk.new(Chunk.world_to_chunk(ford), Tile.Terrain.FLOODPLAIN)

	assert_eq(MapColors.ground_of(1, chunk, Chunk.local_pos(ford)), MapColors.FORD)


## A ford of the creeks of seed 1 (see test_fords.gd).
func _first_ford() -> Vector2i:
	for x in range(0, 960):
		for y in range(-420, 420):
			if Fords.is_ford_bed(1, Vector2i(x, y)):
				return Vector2i(x, y)
	fail_test("no ford in seed 1")
	return Vector2i.ZERO
