extends ResourceCase
## The chest outdoors: placing it with the chest item under the rules of the land, opening it
## with E (before sleeping), taking it down with the axe, and saving it with what it holds.


## The player stands above the free tile `_tile` and faces it, with chests in the inventory.
func _hold_chests() -> void:
	_state.player.inventory.add(ItemTypes.CHEST, 3)
	_hold(ItemTypes.CHEST)


# --- Placing ---


func test_using_the_chest_item_puts_a_chest_on_the_tile_and_takes_one_item() -> void:
	_hold_chests()
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.CHEST)
	assert_true(_world.object_at(_tile).storage.is_empty())
	assert_eq(_count(ItemTypes.CHEST), 2)
	assert_eq(_world.object_at(_tile).blocks_walking(), true)


func test_the_last_chest_item_is_used_up() -> void:
	_state.player.inventory.add(ItemTypes.CHEST, 1)
	_hold(ItemTypes.CHEST)
	_state.use_facing_tile()
	assert_eq(_count(ItemTypes.CHEST), 0)
	assert_eq(_state.player.inventory.held_item(), ItemTypes.NONE)


func test_a_chest_is_not_placed_on_an_occupied_tile() -> void:
	_hold_chests()
	_place(WorldObjectTypes.STONE)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_count(ItemTypes.CHEST), 3)


func test_a_chest_is_not_placed_on_land_that_is_unsafe_to_build_on() -> void:
	_hold_chests()
	for terrain: Tile.Terrain in [
		Tile.Terrain.WATER, Tile.Terrain.WETLAND, Tile.Terrain.FLOODPLAIN
	]:
		_world.set_terrain(_tile, terrain)
		assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "on %s" % terrain)


func test_a_chest_can_stand_on_tilled_soil() -> void:
	_hold_chests()
	_world.set_terrain(_tile, Tile.Terrain.SOIL)
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE)


func _shack() -> Building:
	var around := _state.player.tile()
	for y in range(-12, 13):
		for x in range(-12, 13):
			var shack := _world.place_building(BuildingTypes.SHACK, around + Vector2i(x, y))
			if shack != null:
				return shack
	fail_test("no room for a shack")
	return null


func test_a_chest_is_not_placed_on_a_building() -> void:
	_hold_chests()
	var shack := _shack()
	for tile in shack.tiles():
		assert_eq(_state.use_at(tile), ToolUse.Use.NOTHING, "on %s" % tile)


func test_a_chest_is_not_placed_in_front_of_a_door() -> void:
	_hold_chests()
	var front := _shack().door_tile() + Vector2i.DOWN
	assert_true(_world.is_buildable(front), "the land in front of the door is fine to build on")
	assert_false(_world.is_placeable(front))
	assert_eq(_state.use_at(front), ToolUse.Use.NOTHING)


func test_a_chest_is_not_placed_where_the_player_stands_or_touches() -> void:
	_hold_chests()
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "on the tile")
	# Feet just inside the tile above: the body still reaches into the tile.
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.1)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "the body touches it")
	_state.player.position = Vector2(_tile) + Vector2(0.5, -0.5)
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE, "a tile away")


func test_the_chest_item_is_held_like_seeds() -> void:
	_hold_chests()
	assert_true(_state.can_use_held_item())
	assert_eq(ItemTypes.placed_object(ItemTypes.CHEST), WorldObjectTypes.CHEST)
	assert_eq(ItemTypes.placed_object(ItemTypes.HOE), &"")


func test_the_tooltip_of_the_chest_item_says_what_it_is() -> void:
	var text := ItemTooltip.text_for(ItemTypes.CHEST)
	assert_true(text.begins_with("Chest\nPlaceable\n"), text)
	assert_true(text.ends_with("4 kg each"), text)


# --- Opening ---


func test_e_opens_the_chest_on_the_targeted_tile_before_sleeping() -> void:
	var chest := _place(WorldObjectTypes.CHEST)
	var bag := WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _state.player.tile() + Vector2i.LEFT)
	_world.add_object(bag)
	assert_eq(_state.bed_in_reach(), bag, "a bed is in reach too")
	assert_eq(Interaction.chest_to_open(_state, _tile), chest)


func test_e_sleeps_when_a_bed_is_in_reach_and_the_chest_is_not_targeted() -> void:
	_place(WorldObjectTypes.CHEST)
	var bag := WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _state.player.tile() + Vector2i.LEFT)
	_world.add_object(bag)
	assert_null(Interaction.chest_to_open(_state, _state.player.tile() + Vector2i.UP))


func test_e_opens_the_nearest_chest_in_reach_when_there_is_no_bed() -> void:
	var chest := _place(WorldObjectTypes.CHEST)
	assert_null(_state.bed_in_reach())
	assert_eq(Interaction.chest_to_open(_state, _tile + Vector2i.RIGHT * 3), chest)


func test_e_does_nothing_for_a_chest_out_of_reach() -> void:
	_place(WorldObjectTypes.CHEST)
	_state.player.position += Vector2(0, -2)
	assert_null(Interaction.chest_to_open(_state, _tile))


func test_e_with_no_chest_and_no_bed_does_nothing() -> void:
	assert_null(_state.bed_in_reach())
	assert_null(Interaction.chest_to_open(_state, _tile))
