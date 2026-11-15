extends GutTest
## Desire paths: grass wears to a trodden tile and then a path after busy days in a row, and only
## grass and the floodplain wear, outdoors and not under a building.

const HOUSE := BuildingTypes.KATE
const TILE := Vector2i(5, 5)

var _world: World
var _rules := PathRules.default_rules()


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


## Walks the tile enough on `days` days in a row, each counted when it is over.
func _wear(tile: Vector2i, days: int) -> void:
	for _day in days:
		_world.wear_tile(tile, _rules.busy_steps())
		_world.end_wear_day()


func _set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	_world.chunk_at(Vector2i.ZERO).set_terrain(Chunk.local_pos(world_pos), terrain)


func test_grass_turns_trodden_and_then_a_path_after_busy_days() -> void:
	_wear(TILE, _rules.trodden_after_days() - 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)
	_wear(TILE, 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	_wear(TILE, _rules.path_after_days() - _rules.trodden_after_days() - 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	_wear(TILE, 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.PATH)
	assert_eq(_world.wear_stage(TILE + Vector2i.RIGHT), PathRules.Stage.UNWORN, "only that tile")


func test_a_day_of_many_steps_wears_nothing_until_the_day_is_counted() -> void:
	_world.wear_tile(TILE, _rules.busy_steps() * 100)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)


func test_a_day_of_a_few_steps_is_not_busy() -> void:
	for _day in _rules.most_days():
		_world.wear_tile(TILE, _rules.busy_steps() - 0.5)
		_world.end_wear_day()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)
	assert_eq(_world.to_dict()["wear"], [], "nothing stored")


func test_the_steps_of_a_day_add_up_from_every_walker() -> void:
	for _i in int(_rules.busy_steps() * 2):
		_world.wear_tile(TILE, 0.5)
	_world.end_wear_day()
	assert_eq(_world.to_dict()["wear"], [[TILE.x, TILE.y, 1]])


func test_the_steps_of_one_day_do_not_count_on_the_next() -> void:
	_world.wear_tile(TILE, _rules.busy_steps() - 1.0)
	_world.end_wear_day()
	_world.wear_tile(TILE, _rules.busy_steps() - 1.0)
	_world.end_wear_day()
	assert_eq(_world.to_dict()["wear"], [])


func test_the_look_changes_only_when_the_day_is_counted_and_the_stage_changes() -> void:
	watch_signals(_world)
	_wear(TILE, _rules.path_after_days())
	assert_signal_emit_count(_world, "tile_changed", 2, "trodden, then a path")
	assert_signal_emitted_with_parameters(_world, "tile_changed", [TILE])


func test_the_days_stop_at_the_most() -> void:
	_wear(TILE, _rules.most_days() + 5)
	assert_eq(_world.to_dict()["wear"], [[TILE.x, TILE.y, _rules.most_days()]])


func test_the_floodplain_and_every_grass_wear() -> void:
	_set_terrain(TILE, Tile.Terrain.FLOODPLAIN)
	_wear(TILE, _rules.path_after_days())
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.PATH)


func test_fields_water_and_wetland_do_not_wear() -> void:
	for terrain in [Tile.Terrain.SOIL, Tile.Terrain.WATER, Tile.Terrain.WETLAND]:
		_set_terrain(TILE, terrain)
		_wear(TILE, _rules.path_after_days())
		assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN, "terrain %s" % terrain)
	assert_eq(_world.to_dict()["wear"], [], "nothing stored")
	assert_eq(_world.to_dict()["wear_today"], [], "nothing stored")


func test_a_building_does_not_wear_not_even_at_its_door() -> void:
	var building := _world.place_building(HOUSE, Vector2i(2, 2))
	_wear(building.door_tile(), _rules.path_after_days())
	assert_eq(_world.wear_stage(building.door_tile()), PathRules.Stage.UNWORN)


func test_a_tile_out_of_the_loaded_chunks_does_not_wear() -> void:
	_wear(Vector2i(-3, -3), _rules.path_after_days())
	assert_eq(_world.to_dict()["wear"], [])
	assert_eq(_world.to_dict()["wear_today"], [])


func test_tilling_a_path_tills_it_and_leaves_no_wear() -> void:
	_wear(TILE, _rules.path_after_days())
	_world.set_terrain(TILE, Tile.Terrain.SOIL)
	assert_true(_world.is_tilled(TILE))
	_world.set_terrain(TILE, Tile.Terrain.GRASS)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN, "grassed over, it starts anew")


func test_the_wear_survives_a_save_round_trip() -> void:
	_world.set_wear_days(TILE, _rules.path_after_days())
	_world.set_wear_days(TILE + Vector2i.DOWN, _rules.trodden_after_days())
	var restored := World.from_dict(
		JSON.parse_string(JSON.stringify(_world.to_dict())), GameClock.new()
	)
	restored.add_chunk(Chunk.new(Vector2i.ZERO))
	assert_eq(restored.wear_stage(TILE), PathRules.Stage.PATH)
	assert_eq(restored.wear_stage(TILE + Vector2i.DOWN), PathRules.Stage.TRODDEN)


func test_the_steps_of_today_survive_a_save_round_trip() -> void:
	_world.wear_tile(TILE, 3.5)
	var restored := World.from_dict(
		JSON.parse_string(JSON.stringify(_world.to_dict())), GameClock.new()
	)
	assert_eq(restored.wear_steps(), {TILE: 3.5})


func test_a_path_left_alone_grows_back_to_trodden_and_then_grass() -> void:
	_wear(TILE, _rules.path_after_days())
	for _i in _rules.path_after_days() - _rules.trodden_after_days():
		_world.end_wear_day()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	for _i in _rules.trodden_after_days():
		_world.end_wear_day()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)
	assert_eq(_world.to_dict()["wear"], [], "a tile grown back is forgotten")


func test_a_quiet_day_takes_the_quiet_day_loss_off() -> void:
	_wear(TILE, 5)
	_world.end_wear_day()
	assert_eq(_world.to_dict()["wear"], [[TILE.x, TILE.y, 5 - _rules.quiet_day_loss()]])


func test_a_busy_day_after_a_quiet_one_counts_on_from_what_is_left() -> void:
	_wear(TILE, _rules.trodden_after_days())
	_world.end_wear_day()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN, "one day short of trodden")
	_wear(TILE, 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)


func test_growing_back_changes_the_look_only_when_the_stage_does() -> void:
	_wear(TILE, _rules.trodden_after_days() + 1)
	watch_signals(_world)
	_world.end_wear_day()
	assert_signal_emit_count(_world, "tile_changed", 0, "still trodden")
	_world.end_wear_day()
	assert_signal_emitted_with_parameters(_world, "tile_changed", [TILE])


func test_the_copy_of_the_wear_days_is_shared_until_they_change_and_never_changes() -> void:
	_wear(TILE, 2)
	var copy := _world.wear_days()

	assert_same(_world.wear_days(), copy, "the same copy while the wear has not changed")

	_world.wear_tile(TILE, _rules.busy_steps())
	assert_same(_world.wear_days(), copy, "steps only count at the end of the day")
	_world.end_wear_day()
	var next_day := _world.wear_days()
	_world.set_wear_days(TILE, 9)
	var after_debug_view := _world.wear_days()

	assert_ne(next_day, copy, "the end of the day made another")
	assert_eq(copy, {TILE: 2}, "what a worker was given stays as it was")
	assert_eq(next_day, {TILE: 3})
	assert_ne(after_debug_view, next_day)
	assert_eq(after_debug_view, {TILE: 9})
