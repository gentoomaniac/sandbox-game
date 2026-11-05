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
			if _world.is_tillable(pos) and _world.is_tillable(pos - Vector2i(0, 1)):
				return pos
	fail_test("no grass near the camp")
	return center


func _hold(item: StringName) -> void:
	var inventory := _state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == item:
			inventory.select(slot)
			return
	fail_test("not on the hotbar: %s" % item)


func _plant_and_ripen() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.add_object(WorldObject.new(GameState.CROP, _tile))
	_state.clock.advance(5 * GameClock.MINUTES_PER_DAY)


## Every slot but the last hotbar slot holds a tool, so the hand is empty and nothing stacks.
func _fill_all_but_the_last_hotbar_slot() -> void:
	var inventory := _state.player.inventory
	for slot in Inventory.SLOT_COUNT:
		inventory.slots[slot] = (
			{} if slot == Inventory.HOTBAR_SIZE - 1 else {"item": ItemTypes.HOE, "count": 1}
		)


func test_a_new_game_starts_with_the_tools_and_fifteen_seeds_on_the_hotbar() -> void:
	var inventory := _state.player.inventory
	for tool in [ItemTypes.HOE, ItemTypes.AXE, ItemTypes.PICKAXE, ItemTypes.WATERING_CAN]:
		assert_eq(inventory.count_of(tool), 1, str(tool))
	assert_eq(inventory.count_of(ItemTypes.TURNIP_SEEDS), 15)
	assert_eq(inventory.held_item(), ItemTypes.HOE)


func test_the_hoe_tills_grass_and_nothing_else() -> void:
	_hold(ItemTypes.HOE)
	assert_eq(_state.use_facing_tile(), GameState.Use.TILL)
	assert_eq(_world.tile_at(_tile).terrain, Tile.Terrain.SOIL)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING, "soil can't be tilled")


func test_seeds_plant_on_soil_and_use_up_one_seed() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), GameState.Use.PLANT)
	assert_eq(_world.object_at(_tile).type, GameState.CROP)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 14)


func test_seeds_do_not_plant_on_grass() -> void:
	_hold(ItemTypes.TURNIP_SEEDS)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 15)


func test_the_last_seed_leaves_an_empty_hand() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.remove(ItemTypes.TURNIP_SEEDS, 14)
	_hold(ItemTypes.TURNIP_SEEDS)
	_state.use_facing_tile()
	assert_eq(_state.player.inventory.held_item(), ItemTypes.NONE)


func test_an_empty_hand_harvests_a_ripe_crop_and_gets_a_seed_back() -> void:
	_plant_and_ripen()
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.HARVEST)
	assert_null(_world.object_at(_tile))
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP), 1)
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP_SEEDS), 16)


func test_a_harvest_that_does_not_fit_is_not_done() -> void:
	# The crop would take the one free slot, and its seed has nowhere to go.
	_plant_and_ripen()
	_fill_all_but_the_last_hotbar_slot()
	_state.player.inventory.select(Inventory.HOTBAR_SIZE - 1)
	assert_eq(_state.use_facing_tile(), GameState.Use.INVENTORY_FULL)
	assert_not_null(_world.object_at(_tile))
	assert_eq(_state.player.inventory.count_of(ItemTypes.TURNIP), 0)


func test_an_empty_hand_does_not_harvest_an_unripe_crop() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_world.add_object(WorldObject.new(GameState.CROP, _tile))
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)


func test_tools_without_a_use_yet_do_nothing_anywhere() -> void:
	_plant_and_ripen()
	for tool in [ItemTypes.AXE, ItemTypes.PICKAXE, ItemTypes.WATERING_CAN]:
		_hold(tool)
		assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING, str(tool))
		assert_false(_state.can_use_held_item(), str(tool))
	_hold(ItemTypes.HOE)
	assert_true(_state.can_use_held_item())
	_hold(ItemTypes.NONE)
	assert_true(_state.can_use_held_item())


func test_a_held_turnip_does_nothing() -> void:
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	_state.player.inventory.add(ItemTypes.TURNIP, 1)
	_hold(ItemTypes.TURNIP)
	assert_eq(_state.use_facing_tile(), GameState.Use.NOTHING)
