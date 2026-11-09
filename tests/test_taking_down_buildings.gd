extends GutTest
## Taking a building down: its materials and what is inside lie in front of its door, and the
## land is free again.

const SEED := 7
const ORIGIN := Vector2i(2, 2)

var _state: GameState
var _house: Building
var _door_front: Vector2i


func before_each() -> void:
	_state = GameState.new()
	_state.world = World.new(SEED)
	_state.world.add_chunk(Chunk.new(Vector2i.ZERO))
	_state.player.home_map = _state.world
	_house = _state.world.place_building(BuildingTypes.KATE, ORIGIN)
	_door_front = _house.door_tile() + Vector2i.DOWN
	_stand_on(_door_front + Vector2i.DOWN)


func _stand_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)


func _go_in() -> Interior:
	_stand_on(_house.door_tile())
	_state.pass_door()
	return _state.current_map as Interior


func _go_out() -> void:
	_stand_on(_house.interior.exit_tile)
	_state.pass_door()
	_stand_on(_door_front + Vector2i.DOWN)


func test_half_the_materials_lie_in_front_of_the_door_and_the_building_is_gone() -> void:
	assert_true(_state.take_down_building(_house))
	assert_null(_state.world.building_at(ORIGIN))
	assert_true(_state.world.buildings().is_empty())
	var costs: Dictionary = BuildingTypes.TYPES[BuildingTypes.KATE]["costs"]
	for item: StringName in costs:
		assert_eq(_state.world.ground_items.count_of(item), costs[item] / 2, item)
	assert_true(_state.world.is_buildable(ORIGIN))


func test_a_building_the_player_never_entered_can_be_taken_down() -> void:
	assert_null(_house.interior)
	assert_true(_state.take_down_building(_house))


func test_the_houses_own_furniture_goes_with_it_even_its_empty_chest() -> void:
	_go_in()
	_go_out()
	assert_eq(_state.why_not_take_down(_house), "")
	assert_true(_state.take_down_building(_house))
	assert_eq(_state.world.ground_items.count_of(ItemTypes.CHEST), 0)


func test_a_placed_thing_inside_keeps_it_standing() -> void:
	var interior := _go_in()
	interior.add_object(WorldObject.new(WorldObjectTypes.STOOL, Vector2i(3, 5)))
	_go_out()
	assert_ne(_state.why_not_take_down(_house), "")
	assert_false(_state.take_down_building(_house))
	assert_eq(_state.world.buildings(), [_house])
	assert_true(_state.world.ground_items.all().is_empty())


func test_something_in_the_houses_own_chest_keeps_it_standing() -> void:
	var interior := _go_in()
	var chests := interior.objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.CHEST
	)
	chests[0].storage.add(ItemTypes.TURNIP, 2)
	_go_out()
	assert_false(_state.take_down_building(_house))


func test_not_while_the_player_is_inside() -> void:
	_go_in()
	assert_ne(_state.why_not_take_down(_house), "")
	assert_false(_state.take_down_building(_house))
	assert_eq(_state.world.buildings(), [_house])


func test_the_cost_cheat_gives_no_materials() -> void:
	_state.cheats.is_cost_off = true
	_state.take_down_building(_house)
	assert_eq(_state.world.ground_items.count_of(ItemTypes.LOGS), 0)


func test_a_home_bed_in_it_is_the_camp_sleeping_bag_again() -> void:
	var bed := _go_in().object_at(Vector2i(1, 2))
	_stand_on(Vector2i(2, 3))
	_state.sleep_in(bed)
	_go_out()
	var bag := CampSite.sleeping_bag_of_seed(SEED)
	assert_ne(_state.player.home_bed, bag)
	_state.take_down_building(_house)
	assert_eq(_state.player.home_map, _state.world)
	assert_eq(_state.player.home_bed, bag)


func test_a_home_bed_elsewhere_stays() -> void:
	_state.player.home_bed = Vector2i(9, 9)
	_state.take_down_building(_house)
	assert_eq(_state.player.home_bed, Vector2i(9, 9))


func test_the_taken_down_building_is_not_saved() -> void:
	_go_in()
	_go_out()
	_state.take_down_building(_house)
	assert_true(_state.world.to_dict()["buildings"].is_empty())


func test_waking_after_the_home_house_is_gone_stands_at_the_start_point_when_the_bag_is_gone(
) -> void:
	var bed := _go_in().object_at(Vector2i(1, 2))
	_stand_on(Vector2i(2, 3))
	_state.sleep_in(bed)
	_go_out()
	_state.take_down_building(_house)
	# The test world has no camp objects: the spot is empty, as when the bag was picked up.
	var start := CampSite.spawn_of_seed(SEED)
	_state.world.add_chunk(Chunk.new(Chunk.world_to_chunk(start)))
	_state.go_to_home_bed()
	assert_eq(_state.player.tile(), start)
	assert_false(_state.is_inside())
	assert_null(_state.player.bed_lying_in)


func test_a_save_after_taking_a_house_down_loads_and_plays_on() -> void:
	var other := _state.world.place_building(BuildingTypes.SHACK, Vector2i(10, 2))
	var bed := _go_in().object_at(Vector2i(1, 2))
	_stand_on(Vector2i(2, 3))
	_state.sleep_in(bed)
	_go_out()
	_state.take_down_building(_house)
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	assert_eq(restored.world.buildings().size(), 1)
	assert_eq(restored.world.buildings()[0].origin, other.origin)
	assert_null(restored.world.building_at(ORIGIN))
	assert_eq(restored.player.home_map, restored.world)
	assert_eq(restored.player.home_bed, CampSite.sleeping_bag_of_seed(SEED))
	restored.world.add_chunk(Chunk.new(Vector2i.ZERO))
	var shack := restored.world.buildings()[0]
	restored.player.position = Vector2(shack.door_tile()) + Vector2(0.5, 0.5)
	restored.pass_door()
	assert_true(restored.is_inside())
