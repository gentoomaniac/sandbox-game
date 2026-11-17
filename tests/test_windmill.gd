extends ResourceCase
## The windmill (#26): flour is ground at its millstone, only in a wind and faster in a strong
## one, and a save of before, with a run of flour in the oven, still loads.

const FLOURS: Array[StringName] = [&"flour", &"rye_flour", &"buckwheat_flour"]
const SAVE_DIR := "user://test_windmill"
const SAVE_PATH := SAVE_DIR + "/world.json"

var _millstone: WorldObject
var _station: ProcessStation


func before_each() -> void:
	super.before_each()
	_millstone = WorldObject.new(WorldObjectTypes.MILLSTONE, _tile)
	_world.add_object(_millstone)
	_station = ProcessStation.new(_state, Crafting.new(_state), _millstone)
	_state.player.inventory.add(&"wheat", 3)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))


## Loads the grid with the wheat of a load and tries to start the run in the wind of `weather`
## (a forced condition, see Weather FORCED); returns whether it started.
func _grind_in(weather: StringName) -> bool:
	_state.weather_override = weather
	assert_true(_station.fill(&"flour", 1))
	return _station.start()


func test_flour_is_ground_at_the_mill_and_neither_at_the_oven_nor_by_hand() -> void:
	var rules := RecipeRules.default_rules()
	for recipe_id in FLOURS:
		assert_eq(rules.result(recipe_id), ItemTypes.FLOUR)
		assert_has(rules.recipes_at(&"mill"), recipe_id)
		assert_does_not_have(rules.recipes_at(&"oven"), recipe_id)
		assert_does_not_have(rules.recipes_at(&""), recipe_id)


func test_the_windmill_has_a_millstone_inside_that_is_the_mill_station() -> void:
	var building := _place_building_nearby(BuildingTypes.WINDMILL)
	var millstone := building.inside().object_at(Vector2i(3, 2))

	assert_eq(millstone.type, WorldObjectTypes.MILLSTONE)
	assert_eq(StationRules.default_rules().station_of(millstone.type), &"mill")
	assert_null(building.inside().object_at(building.inside().entry_tile()), "room to come in")


func test_nothing_is_ground_in_a_calm() -> void:
	assert_false(_grind_in(&"fog"))
	assert_false(_millstone.state.has(ProcessStation.RUN))
	assert_eq(_station.speed(), 0.0)


func test_a_strong_wind_grinds_faster_than_a_light_one() -> void:
	assert_true(_grind_in(&"cloudy"))
	assert_gt(_station.speed(), 0.0, "a light wind turns the sails")
	var light_minutes := _station.minutes_left()
	_state.player.inventory.add(&"wheat", 3)
	var strong_station := ProcessStation.new(
		_state, Crafting.new(_state), _place_millstone(_tile + Vector2i(1, 0))
	)
	_state.weather_override = &"wind"
	assert_true(strong_station.fill(&"flour", 1))
	assert_true(strong_station.start())

	assert_lt(strong_station.minutes_left(), light_minutes)


func test_a_save_with_flour_being_made_in_the_oven_loads_and_the_run_finishes() -> void:
	var oven := WorldObject.new(WorldObjectTypes.OVEN, Vector2i(3, 4))
	oven.storage.add(&"wheat", 3)
	oven.state[ProcessStation.RUN] = {
		"recipe": "flour", "start_minute": 0, "done_minute": 60, "products": {"flour": 1}
	}
	_world.add_object(oven)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var coords := Chunk.world_to_chunk(oven.pos)
	if not restored.world.is_chunk_loaded(coords):
		restored.world.add_chunk(
			WorldGenerator.new(restored.world.world_seed).generate_chunk(coords)
		)
	var loaded := restored.world.object_at(oven.pos)
	ProcessStation.settle(loaded, 60)
	assert_eq(loaded.storage.totals(), {ItemTypes.FLOUR: 1}, "the flour of the old run is theirs")
	assert_false(loaded.state[ProcessStation.RUN].has("products"))


func _place_millstone(pos: Vector2i) -> WorldObject:
	var millstone := WorldObject.new(WorldObjectTypes.MILLSTONE, pos)
	_world.add_object(millstone)
	return millstone


func test_a_save_with_wheat_in_the_oven_and_no_run_loads_and_the_wheat_stays() -> void:
	var oven := WorldObject.new(WorldObjectTypes.OVEN, Vector2i(3, 4))
	oven.storage.add(&"wheat", 3)
	_world.add_object(oven)
	assert_true(SaveFile.write(_state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	var coords := Chunk.world_to_chunk(oven.pos)
	if not restored.world.is_chunk_loaded(coords):
		restored.world.add_chunk(
			WorldGenerator.new(restored.world.world_seed).generate_chunk(coords)
		)
	assert_eq(restored.world.object_at(oven.pos).storage.totals(), {&"wheat": 3})


func test_a_windmill_with_wheat_in_its_millstone_is_not_taken_down() -> void:
	var building := _place_building_nearby(BuildingTypes.WINDMILL)
	assert_eq(Demolition.why_not(_state, building), "", "the built-in millstone is not put in")
	var millstone := building.inside().object_at(Vector2i(3, 2))

	millstone.storage.add(&"wheat", 3)

	assert_eq(Demolition.why_not(_state, building), "Take out what you put in it first.")


func test_a_fresh_windmill_can_still_be_furnished() -> void:
	var building := _place_building_nearby(BuildingTypes.WINDMILL)
	building.inside()

	assert_true(building.can_be_furnished())
