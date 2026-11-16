extends GutTest
## What the storm surge's water does to the land (#103): it drowns crops, leaves salt that spoils a
## field and runs out, leaves mud, soaks the soil and washes items away.

const SEED := 7
const NOW := 1000

var _state: GameState
var _world: World
var _tile: Vector2i


func before_each() -> void:
	_state = GameFactory.new_game(SEED)
	_world = _state.world
	_tile = _state.player.tile() + Vector2i(3, 2)
	for y in range(-2, 3):
		for x in range(-2, 3):
			_world.remove_object(_tile + Vector2i(x, y))
	_world.set_terrain(_tile, Tile.Terrain.SOIL)


func _flood_the_tile(depth_cm: int, salt_days := 40, mud_days := 0) -> void:
	var entry := [_tile.x, _tile.y]
	(
		_world
		. flood
		. load_dict(
			{
				"flood": {"phase": "standing", "level_cm": 300, "drain_minute": NOW},
				"flood_wet": [entry + [depth_cm]] if depth_cm > 0 else [],
				"flood_salt": [entry + [salt_days]] if salt_days > 0 else [],
				"flood_mud": [entry + [mud_days]] if mud_days > 0 else [],
				"flood_repairs": [],
				"flood_met_chunks": [],
			}
		)
	)


func _plant() -> WorldObject:
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _tile)
	crop.state["days_growing"] = 0
	_world.add_object(crop)
	return crop


func _grow(crop: WorldObject) -> void:
	crop.state["growth"] = 1.5 * crop.type_data()["growth_per_stage"]
	assert_gt(CropLife.stage(crop), 0)


func test_a_seedling_under_water_dies_at_once() -> void:
	var crop := _plant()
	assert_true(CropLife.live_through_flood_hour(crop, 0.05))
	assert_true(CropLife.is_dead(crop))


func test_a_grown_crop_survives_shallow_water_and_dies_after_a_day_in_deeper() -> void:
	var crop := _plant()
	_grow(crop)
	for _hour in 30:
		assert_false(CropLife.live_through_flood_hour(crop, 0.05), "a sheet of water is no harm")
	for _hour in 23:
		assert_false(CropLife.live_through_flood_hour(crop, 0.4))
	assert_true(CropLife.live_through_flood_hour(crop, 0.4))
	assert_true(CropLife.is_dead(crop))


func test_the_hours_of_the_upkeep_drown_the_crops_in_the_water() -> void:
	var crop := _plant()
	_flood_the_tile(80)
	var simulation := Simulation.new(_state.clock)
	simulation.add_system(SurgeUpkeep.new(_world, _state.weather))
	simulation.advance(GameClock.MINUTES_PER_HOUR)
	assert_true(CropLife.is_dead(crop))


func test_a_crop_on_dry_land_is_left_alone() -> void:
	var crop := _plant()
	var simulation := Simulation.new(_state.clock)
	simulation.add_system(SurgeUpkeep.new(_world, _state.weather))
	simulation.advance(GameClock.MINUTES_PER_HOUR)
	assert_false(CropLife.is_dead(crop))


func test_salt_spoils_a_field_until_it_runs_out() -> void:
	_flood_the_tile(10, 2)
	assert_eq(_world.flood.salt_days_at(_tile), 2)
	assert_eq(WorldHoverText.object_text_at(_state, _tile), "Salt: 2 days")
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5) - Vector2(0, 1)
	_state.player.facing = Vector2i.DOWN
	HotbarHold.hold(_state.player.inventory, ItemTypes.TURNIP_SEEDS)
	assert_ne(_state.use_facing_tile(), ToolUse.Use.PLANT, "nothing is planted on salt")
	_world.flood.end_day(0.0)
	_world.flood.end_day(0.0)
	assert_eq(_world.flood.salt_days_at(_tile), 0)
	assert_eq(WorldHoverText.object_text_at(_state, _tile), "")
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)


func test_rain_takes_a_day_of_salt_off_for_each_hour() -> void:
	_flood_the_tile(10, 40)
	_world.flood.end_day(0.0)
	assert_eq(_world.flood.salt_days_at(_tile), 39)
	_world.flood.end_day(6.5)
	assert_eq(_world.flood.salt_days_at(_tile), 32)


func test_the_mud_a_flood_leaves_dries_after_its_days() -> void:
	_flood_the_tile(0, 0, 2)
	assert_true(_world.is_muddy_at(_tile))
	_world.flood.end_day(0.0)
	assert_true(_world.is_muddy_at(_tile))
	_world.flood.end_day(0.0)
	assert_false(_world.is_muddy_at(_tile))


func test_the_water_soaks_tilled_soil() -> void:
	var world := CoastWorld.make()
	var tile := CoastWorld.sea_dykes(world)[0].pos + Vector2i(1, 0)
	world.set_terrain(tile, Tile.Terrain.SOIL)
	world.set_moisture(tile, 0.2)
	world.flood.begin(world, 3.4, NOW, 1)
	world.flood.settle(world)
	assert_gt(world.flood.depth_at(tile), 0.5)
	assert_eq(world.moisture_at(tile), 1.0)


func test_items_on_deep_ground_drift_inland_or_are_lost() -> void:
	var world := CoastWorld.make()
	var starts: Dictionary[GroundItem, Vector2] = {}
	for dyke in CoastWorld.sea_dykes(world).slice(0, 30):
		var pile := GroundItem.new(ItemTypes.STONE, 1, Vector2(dyke.pos) + Vector2(1.5, 0.5))
		world.ground_items.add(pile)
		starts[pile] = pile.position
	world.flood.begin(world, 3.4, NOW, 1)
	world.flood.settle(world)
	var lost := 0
	for pile in starts:
		if not world.ground_items.all().has(pile):
			lost += 1
		else:
			assert_between(pile.position.x - starts[pile].x, 1.0, 3.0, "drifted inland")
			assert_eq(pile.position.y, starts[pile].y)
	assert_between(lost, 1, 29, "some are lost, not all")
