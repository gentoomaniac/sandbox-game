extends GutTest
## WorldBuildings on its own: the list and the tile index, without a world.

const HOUSE := BuildingTypes.KATE
const ORIGIN := Vector2i(2, 2)

var _buildings := WorldBuildings.new()


func before_each() -> void:
	_buildings = WorldBuildings.new()


func test_a_building_is_found_on_each_tile_of_its_footprint_until_it_is_removed() -> void:
	var building := Building.new(HOUSE, ORIGIN)
	_buildings.add(building)
	for tile in building.tiles():
		assert_same(_buildings.at(tile), building)
	_buildings.remove(building)
	assert_null(_buildings.at(building.tiles()[0]))
	assert_true(_buildings.all().is_empty())


func test_the_tile_below_the_door_is_in_front_of_it() -> void:
	var building := Building.new(HOUSE, ORIGIN)
	_buildings.add(building)
	assert_true(_buildings.is_in_front_of_door(building.door_tile() + Vector2i.DOWN))
	assert_false(_buildings.is_in_front_of_door(building.door_tile()))


func test_the_copies_share_nothing_with_the_list() -> void:
	var building := Building.new(HOUSE, ORIGIN)
	_buildings.add(building)
	_buildings.all().clear()
	_buildings.tiles().clear()
	assert_same(_buildings.at(building.tiles()[0]), building)
	assert_eq(_buildings.all().size(), 1)
