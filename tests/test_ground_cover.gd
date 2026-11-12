extends GutTest
## What lies on the ground: leaves thickest near broadleaved trees, snow thinner under crowns and
## in the lee of buildings, paths clearing first in a thaw, nothing on water; and the share only
## grows with the weather.

const ORIGIN := Vector2i(8, 8)
const OPEN := Vector2i(20, 20)

var _world: World
var _cover: GroundCover


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))
	_cover = GroundCover.new(_world)


func test_leaves_lie_thickest_under_a_broadleaved_tree_and_thinner_in_the_open() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, ORIGIN))
	_cover.set_weather(1.0, 0.0, 0.0, 0.0)
	assert_eq(_cover.leaves_at(ORIGIN), 1.0)
	assert_gt(_cover.leaves_at(ORIGIN + Vector2i(1, 0)), _cover.leaves_at(ORIGIN + Vector2i(2, 0)))
	assert_gt(_cover.leaves_at(OPEN), 0.0, "some leaves blow about the open")
	assert_lt(_cover.leaves_at(OPEN), 0.5)


func test_a_conifer_does_not_drop_leaves() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.SPRUCE, ORIGIN))
	_cover.set_weather(1.0, 0.0, 0.0, 0.0)
	assert_eq(_cover.leaves_at(ORIGIN), _cover.leaves_at(OPEN))


func test_there_are_no_leaves_without_litter_and_none_on_water() -> void:
	_cover.set_weather(0.0, 0.0, 0.0, 0.0)
	assert_eq(_cover.leaves_at(OPEN), 0.0)
	_world.set_terrain(OPEN, Tile.Terrain.WATER)
	_cover.set_weather(1.0, 1.0, 0.0, 1.0)
	assert_eq(_cover.leaves_at(OPEN), 0.0)
	assert_eq(_cover.snow_at(OPEN), 0.0)
	assert_eq(_cover.frost_at(OPEN), 0.0)
	_world.set_terrain(OPEN, Tile.Terrain.MUD)
	assert_eq(_cover.snow_at(OPEN), 0.0, "the tidal mud stays clear")


func test_more_snow_cover_never_snows_a_tile_less() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, ORIGIN))
	for tile in [OPEN, ORIGIN, ORIGIN + Vector2i(2, 1)]:
		var previous := -1.0
		for step in 11:
			_cover.set_weather(0.0, step / 10.0, 0.0, 0.0)
			var share := _cover.snow_at(tile)
			assert_gte(share, previous)
			previous = share


func test_snow_lies_thinner_under_a_tree_and_in_the_lee_of_a_house() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, ORIGIN))
	_cover.set_weather(0.0, 0.8, 0.0, 0.0)
	assert_lt(_cover.snow_at(ORIGIN), _cover.snow_at(OPEN))
	var house := _world.place_building(BuildingTypes.KATE, Vector2i(14, 14))
	var footprint := house.tiles()
	var right_edge := footprint.map(func(tile: Vector2i) -> int: return tile.x).max()
	var east_of_house := Vector2i(right_edge + 1, house.origin.y)
	assert_lt(_cover.snow_at(east_of_house), _cover.snow_at(OPEN))
	var west_of_house := house.origin - Vector2i(1, 0)
	assert_eq(_cover.snow_at(west_of_house), _cover.snow_at(OPEN), "the windward side is open")


func test_a_thaw_clears_a_path_before_open_ground() -> void:
	var path := Vector2i(10, 20)
	_world.wear_tile(path, PathRules.default_rules().most())
	assert_eq(_world.wear_stage(path), PathRules.Stage.PATH)
	_cover.set_weather(0.0, 1.0, 0.0, 0.0)
	assert_lt(_cover.snow_at(path), _cover.snow_at(OPEN), "a path catches less")
	_cover.set_weather(0.0, 0.5, 0.0, 0.0)
	var before_path := _cover.snow_at(path)
	var before_open := _cover.snow_at(OPEN)
	_cover.set_weather(0.0, 0.5, 1.0, 0.0)
	assert_lt(_cover.snow_at(path) / before_path, _cover.snow_at(OPEN) / before_open)


func test_frost_lies_thinner_under_a_crown_and_grows_with_the_cold() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.SPRUCE, ORIGIN))
	_cover.set_weather(0.0, 0.0, 0.0, 0.5)
	assert_lt(_cover.frost_at(ORIGIN), _cover.frost_at(OPEN))
	_cover.set_weather(0.0, 0.0, 0.0, 1.0)
	assert_gt(_cover.frost_at(OPEN), 0.5)


func test_a_tile_is_snowed_when_most_of_it_is() -> void:
	_cover.set_weather(0.0, 1.0, 0.0, 0.0)
	assert_true(_cover.is_snowed(OPEN))
	_cover.set_weather(0.0, 0.2, 0.0, 0.0)
	assert_false(_cover.is_snowed(OPEN))


func test_the_channels_are_whole_eighths_of_a_byte() -> void:
	_world.add_object(WorldObject.new(WorldObjectTypes.OAK, ORIGIN))
	var channels := _cover.channels_at(ORIGIN + Vector2i(1, 1))
	for value in [channels.leaves, channels.snow, channels.melt, channels.frost_shelter]:
		assert_almost_eq(value * 255.0, roundf(value * 255.0), 0.0001)
