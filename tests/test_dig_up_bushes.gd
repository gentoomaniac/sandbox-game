extends ResourceCase
## Digging a bush up with the shovel and planting it again elsewhere (task 208), in midsummer.

const BUSHES := {
	WorldObjectTypes.BERRY_BUSH: ItemTypes.BERRY_BUSH,
	WorldObjectTypes.SHRUB: ItemTypes.SHRUB,
	WorldObjectTypes.FERN_BUSH: ItemTypes.FERN_BUSH,
}
## What the rusty shovel (power 1) needs to dig a bush up (`dig_hits`).
const HITS_TO_DIG := 3


func before_each() -> void:
	super.before_each()
	_set_midsummer()


## Puts a bush of the type on the tile in front of the player and digs it up.
func _dig_up(type: StringName) -> void:
	_place(type)
	_hit(ItemTypes.RUSTY_IRON_SHOVEL, HITS_TO_DIG)


func test_the_shovel_digs_each_bush_up_whole_in_a_few_hits() -> void:
	for type: StringName in BUSHES:
		_place(type)
		_hold(ItemTypes.RUSTY_IRON_SHOVEL)
		for hit in HITS_TO_DIG - 1:
			assert_eq(_state.use_facing_tile(), ToolUse.Use.DIG_UP)
			assert_eq(_world.object_at(_tile).type, type, "hit %d leaves it" % (hit + 1))
		assert_eq(_state.use_facing_tile(), ToolUse.Use.DIG_UP)
		assert_null(_world.object_at(_tile), type)
		assert_eq(_count(BUSHES[type]), 1, type)
		assert_eq(_dropped(ItemTypes.BERRIES) + _dropped(ItemTypes.FIBRE), 0, "it is not picked")
		assert_true(_world.is_free_on(_tile, Tile.Terrain.GRASS), "grass is left")


func test_a_better_shovel_digs_faster() -> void:
	_place(WorldObjectTypes.SHRUB)
	var iron_shovel := ItemTypes.tool_item(&"shovel", 1)
	_state.player.inventory.add(iron_shovel, 1)
	_hit(iron_shovel, 2)
	assert_null(_world.object_at(_tile))


func test_digging_a_bush_costs_energy_like_other_shovel_work() -> void:
	_place(WorldObjectTypes.SHRUB)
	var before := _state.player.energy
	_hit(ItemTypes.RUSTY_IRON_SHOVEL, 1)
	assert_lt(_state.player.energy, before)


func test_the_hits_heal_overnight() -> void:
	_place(WorldObjectTypes.SHRUB)
	_hit(ItemTypes.RUSTY_IRON_SHOVEL, HITS_TO_DIG - 1)
	_sleep_days(1)
	_hit(ItemTypes.RUSTY_IRON_SHOVEL, 1)
	assert_not_null(_world.object_at(_tile))


func test_a_dug_up_bush_goes_to_the_ground_when_the_inventory_is_full() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.RUSTY_IRON_SHOVEL)
	_fill_inventory()
	_hit(ItemTypes.RUSTY_IRON_SHOVEL, HITS_TO_DIG)
	assert_eq(_dropped(ItemTypes.BERRY_BUSH), 1)


func test_the_hand_and_the_axe_work_on_bushes_as_before() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)
	_world.remove_object(_tile)
	_place(WorldObjectTypes.SHRUB)
	assert_eq(_hit(ItemTypes.RUSTY_IRON_AXE, 1), ToolUse.Use.NOTHING, "the axe does not cut it")


func test_the_hammer_does_not_take_a_bush_down() -> void:
	_place(WorldObjectTypes.BERRY_BUSH)
	assert_null(Builder.new(_state).take_down_target(_tile))


func test_a_dug_up_bush_is_planted_on_free_grass_as_the_same_object() -> void:
	for type: StringName in BUSHES:
		_dig_up(type)
		_hold(BUSHES[type])
		assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE, type)
		assert_eq(_world.object_at(_tile).type, type)
		assert_eq(_count(BUSHES[type]), 0)
		_world.remove_object(_tile)


func test_a_bush_is_refused_where_it_cannot_grow() -> void:
	_state.player.inventory.add(ItemTypes.BERRY_BUSH, 1)
	_hold(ItemTypes.BERRY_BUSH)
	_world.set_terrain(_tile, Tile.Terrain.WATER)
	assert_ne(_state.use_at(_tile), ToolUse.Use.PLACE, "on water")
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	assert_ne(_state.use_at(_tile), ToolUse.Use.PLACE, "on tilled soil")
	_world.set_terrain(_tile, Tile.Terrain.GRASS)
	_place(WorldObjectTypes.SHRUB)
	assert_ne(_state.use_at(_tile), ToolUse.Use.PLACE, "on another object")
	_world.remove_object(_tile)
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE, "free grass again")


func test_a_bush_is_refused_in_front_of_a_door_and_on_a_building() -> void:
	_state.player.inventory.add(ItemTypes.BERRY_BUSH, 1)
	_hold(ItemTypes.BERRY_BUSH)
	var house := _place_building_nearby(BuildingTypes.KATE)
	var in_front := house.door_tile() + Vector2i.DOWN
	_world.set_terrain(in_front, Tile.Terrain.GRASS)
	_world.remove_object(in_front)
	_state.player.position = Vector2(in_front) + Vector2(0.5, -1.5)
	assert_ne(_state.use_at(in_front), ToolUse.Use.PLACE, "in front of a door")
	assert_ne(_state.use_at(house.door_tile()), ToolUse.Use.PLACE, "on the building")


func test_a_replanted_berry_bush_bears_again_after_its_regrowth_days() -> void:
	_dig_up(WorldObjectTypes.BERRY_BUSH)
	_hold(ItemTypes.BERRY_BUSH)
	_state.use_facing_tile()
	var bush := _world.object_at(_tile)
	assert_true(bush.is_picked(), "it does not bear at once")
	_hold(ItemTypes.NONE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	_sleep_days(3)
	assert_false(bush.is_picked())
	assert_eq(_state.use_facing_tile(), ToolUse.Use.FORAGE)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)


func test_a_dug_up_and_a_replanted_bush_survive_the_save() -> void:
	_dig_up(WorldObjectTypes.BERRY_BUSH)
	assert_eq(_through_save().player.inventory.count_of(ItemTypes.BERRY_BUSH), 1)
	_hold(ItemTypes.BERRY_BUSH)
	_state.use_facing_tile()
	_sleep_days(3)
	var bush := _through_save().world.object_at(_tile)
	assert_eq(bush.type, WorldObjectTypes.BERRY_BUSH)
	assert_false(bush.is_picked())
