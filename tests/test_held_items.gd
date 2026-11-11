extends GutTest
## What the use action does with each held item.

const SEED := 7
const SEARCH := 6

var _state: GameState
var _world: World
var _tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(SEED)
	_world = _state.world
	_tile = _grass_tile()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5) - Vector2(0, 1)
	_state.player.facing = Vector2i.DOWN


func _grass_tile() -> Vector2i:
	var center := _state.player.tile()
	for y in range(-SEARCH, SEARCH):
		for x in range(-SEARCH, SEARCH):
			var pos := center + Vector2i(x, y + 1)
			if (
				_world.is_free_on(pos, Tile.Terrain.GRASS)
				and _world.is_free_on(pos - Vector2i(0, 1), Tile.Terrain.GRASS)
			):
				return pos
	fail_test("no grass near the camp")
	return center


func _hold(item: StringName) -> void:
	HotbarHold.hold(_state.player.inventory, item)


func _plant_and_ripen() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	var crop := WorldObject.new(WorldObjectTypes.TURNIP, _tile)
	crop.state["growth"] = 3.0 * crop.type_data()["growth_per_stage"]
	_world.add_object(crop)


func test_a_new_game_starts_with_the_tools_and_fifteen_seeds_on_the_hotbar() -> void:
	var inventory := _state.player.inventory
	for tool in [ItemTypes.HOE, ItemTypes.AXE, ItemTypes.PICKAXE, ItemTypes.WATERING_CAN]:
		assert_eq(inventory.count_of(tool), 1, str(tool))
	assert_eq(inventory.count_of(ItemTypes.TURNIP_SEEDS), 15)
	assert_eq(inventory.held_item(), ItemTypes.HOE)


func test_the_hoe_tills_grass_and_nothing_else() -> void:
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.TILL)
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "soil can't be tilled")


func test_seeds_plant_on_soil_and_use_up_one_seed() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLANT)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.TURNIP)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 14)


func test_seeds_do_not_plant_on_grass() -> void:
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 15)


func test_the_last_seed_leaves_an_empty_hand() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.remove(ItemTypes.TURNIP_SEEDS, 14)
	_hold(ItemTypes.TURNIP_SEEDS)
	_state.use_facing_tile()
	assert_eq(_state.player.inventory.held_item(), ItemTypes.NONE)


func test_an_empty_hand_harvests_a_ripe_crop_and_gets_what_the_dice_give() -> void:
	_plant_and_ripen()
	_state.harvest_rng.seed = SEED
	var dice := RandomNumberGenerator.new()
	dice.seed = SEED
	var expected := CropLife.harvest_of(_world.object_at(_tile), dice)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.HARVEST)
	assert_null(_world.object_at(_tile))
	assert_eq(_world.ground_items.count_of(ItemTypes.TURNIP), expected[ItemTypes.TURNIP])
	assert_eq(
		_world.ground_items.count_of(ItemTypes.TURNIP_SEEDS),
		expected.get(ItemTypes.TURNIP_SEEDS, 0)
	)


func test_an_empty_hand_does_not_harvest_an_unripe_crop() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.add_object(WorldObject.new(WorldObjectTypes.TURNIP, _tile))
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)


func test_the_watering_can_waters_dry_soil_and_nothing_else() -> void:
	_plant_and_ripen()
	_hold(ItemTypes.WATERING_CAN)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.WATER)
	assert_eq(_world.moisture_at(_tile), 1.0)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING, "soaked already")
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "grass is not watered")
	assert_true(_state.can_use_held_item())
	_hold(ItemTypes.HOE)
	assert_true(_state.can_use_held_item())
	_hold(ItemTypes.NONE)
	assert_true(_state.can_use_held_item())


func test_a_held_turnip_does_nothing() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.add(ItemTypes.TURNIP, 1)
	_hold(ItemTypes.TURNIP)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
