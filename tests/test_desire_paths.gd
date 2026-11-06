extends GutTest
## Desire paths: grass wears to a trodden tile and then a path, step by step, and only grass and
## the floodplain wear, outdoors and not under a building.

const HOUSE := BuildingTypes.KATE
const TILE := Vector2i(5, 5)

var _world: World
var _rules := PathRules.default_rules()


func before_each() -> void:
	_world = World.new(1)
	_world.add_chunk(Chunk.new(Vector2i.ZERO))


func _wear(tile: Vector2i, steps: float) -> void:
	for _i in int(steps):
		_world.wear_tile(tile)


func _set_terrain(world_pos: Vector2i, terrain: Tile.Terrain) -> void:
	_world.chunk_at(Vector2i.ZERO).set_terrain(Chunk.local_pos(world_pos), terrain)


func test_grass_turns_trodden_and_then_a_path_step_by_step() -> void:
	_wear(TILE, _rules.trodden_from() - 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)
	_world.wear_tile(TILE)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	_wear(TILE, _rules.path_from() - _rules.trodden_from() - 1)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	_world.wear_tile(TILE)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.PATH)
	assert_eq(_world.wear_stage(TILE + Vector2i.RIGHT), PathRules.Stage.UNWORN, "only that tile")


func test_the_look_changes_only_when_the_stage_does() -> void:
	watch_signals(_world)
	_wear(TILE, _rules.path_from())
	assert_signal_emit_count(_world, "tile_changed", 2, "trodden, then a path")
	assert_signal_emitted_with_parameters(_world, "tile_changed", [TILE])


func test_the_wear_stops_at_the_most() -> void:
	_wear(TILE, _rules.most() * 3)
	var saved: Array = _world.to_dict()["wear"]
	assert_eq(saved, [[TILE.x, TILE.y, _rules.most()]])


func test_the_floodplain_and_every_grass_wear() -> void:
	_set_terrain(TILE, Tile.Terrain.FLOODPLAIN)
	_wear(TILE, _rules.path_from())
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.PATH)


func test_fields_water_and_wetland_do_not_wear() -> void:
	for terrain in [Tile.Terrain.SOIL, Tile.Terrain.WATER, Tile.Terrain.WETLAND]:
		_set_terrain(TILE, terrain)
		_wear(TILE, _rules.path_from())
		assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN, "terrain %s" % terrain)
	assert_eq(_world.to_dict()["wear"], [], "nothing stored")


func test_a_building_does_not_wear_not_even_at_its_door() -> void:
	var building := _world.place_building(HOUSE, Vector2i(2, 2))
	_wear(building.door_tile(), _rules.path_from())
	assert_eq(_world.wear_stage(building.door_tile()), PathRules.Stage.UNWORN)


func test_a_tile_out_of_the_loaded_chunks_does_not_wear() -> void:
	_wear(Vector2i(-3, -3), _rules.path_from())
	assert_eq(_world.to_dict()["wear"], [])


func test_tilling_a_path_tills_it_and_leaves_no_wear() -> void:
	_wear(TILE, _rules.path_from())
	_world.set_terrain(TILE, Tile.Terrain.SOIL)
	assert_true(_world.is_tilled(TILE))
	_world.set_terrain(TILE, Tile.Terrain.GRASS)
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN, "grassed over, it starts anew")


func test_the_wear_survives_a_save_round_trip() -> void:
	_wear(TILE, _rules.path_from())
	_wear(TILE + Vector2i.DOWN, _rules.trodden_from())
	var restored := World.from_dict(
		JSON.parse_string(JSON.stringify(_world.to_dict())), GameClock.new()
	)
	restored.add_chunk(Chunk.new(Vector2i.ZERO))
	assert_eq(restored.wear_stage(TILE), PathRules.Stage.PATH)
	assert_eq(restored.wear_stage(TILE + Vector2i.DOWN), PathRules.Stage.TRODDEN)


func test_a_path_left_alone_grows_back_to_trodden_and_then_grass() -> void:
	_wear(TILE, _rules.path_from())
	_world.regrow_paths()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.TRODDEN)
	for _i in ceili(_rules.path_from() / _rules.regrowth_per_night()):
		_world.regrow_paths()
	assert_eq(_world.wear_stage(TILE), PathRules.Stage.UNWORN)
	assert_eq(_world.to_dict()["wear"], [], "a tile grown back is forgotten")


func test_growing_back_changes_the_look_only_when_the_stage_does() -> void:
	_wear(TILE, _rules.trodden_from() + _rules.regrowth_per_night())
	watch_signals(_world)
	_world.regrow_paths()
	assert_signal_emit_count(_world, "tile_changed", 0, "still trodden")
	_world.regrow_paths()
	assert_signal_emitted_with_parameters(_world, "tile_changed", [TILE])
