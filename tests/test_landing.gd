extends ResourceCase
## The fisherman's landing (task 103): the jetty is laid over water and walked on, the boat lies
## on two tiles of water or mud, the net frame and the eel traps stand on the land. Nobody ends up
## in the water: the jetty under the player stays, and a player who stands where they don't fit
## can always step onto a deck.

const SEA_REACH := 3


## Turns the tile in front of the player and the one right of it into sea.
func _make_sea() -> void:
	_make_room()
	for x in range(0, 2):
		_world.set_terrain(_tile + Vector2i(x, 0), Tile.Terrain.SEA)


## Sea all around the tile, and a jetty on the tile and the `length - 1` tiles right of it.
func _jetty_out_at_sea(length: int) -> void:
	for y in range(-SEA_REACH, SEA_REACH + 1):
		for x in range(-SEA_REACH, SEA_REACH + 1):
			_world.remove_object(_tile + Vector2i(x, y))
			_world.set_terrain(_tile + Vector2i(x, y), Tile.Terrain.SEA)
	for x in length:
		_world.add_object(WorldObject.new(WorldObjectTypes.JETTY, _tile + Vector2i(x, 0)))


## Puts the player astride the jetty's first two tiles, facing the first.
func _stand_astride() -> void:
	_state.player.position = Vector2(_tile) + Vector2(1.0, 0.5)
	_state.player.facing = Vector2i.LEFT


func _walk(direction: Vector2, seconds: float) -> void:
	for _step in int(seconds / 0.05):
		_state.walk(direction, 0.05, _state.walk_speed_factor())


func test_a_jetty_is_laid_over_the_sea_and_walked_on() -> void:
	_make_sea()
	assert_false(_world.is_walkable(_tile), "the sea")
	_state.player.inventory.add(ItemTypes.JETTY, 1)
	_hold(ItemTypes.JETTY)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.JETTY)
	assert_true(_world.is_walkable(_tile), "on the jetty")


func test_a_jetty_is_not_laid_on_grass() -> void:
	_state.player.inventory.add(ItemTypes.JETTY, 1)
	_hold(ItemTypes.JETTY)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING)


func test_the_boat_needs_both_its_tiles_on_water_or_mud() -> void:
	_make_sea()
	_state.player.inventory.add(ItemTypes.ROWING_BOAT, 1)
	_hold(ItemTypes.ROWING_BOAT)
	assert_eq(_state.use_at(_tile - Vector2i(1, 0)), ToolUse.Use.NOTHING, "half on grass")
	assert_eq(_state.use_at(_tile), ToolUse.Use.PLACE)
	_state.use_tile(_tile)
	assert_eq(_world.object_at(_tile + Vector2i.RIGHT).type, WorldObjectTypes.ROWING_BOAT)
	assert_false(_world.is_walkable(_tile + Vector2i.RIGHT))


func test_the_net_frame_needs_both_its_tiles_free() -> void:
	_make_room()
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, _tile + Vector2i.RIGHT))
	_state.player.inventory.add(ItemTypes.NET_FRAME, 1)
	_hold(ItemTypes.NET_FRAME)
	assert_eq(_state.use_at(_tile), ToolUse.Use.NOTHING, "a stone on its right tile")
	assert_eq(_state.use_at(_tile - Vector2i(2, 0)), ToolUse.Use.PLACE)


func test_eel_traps_are_put_down_on_the_land() -> void:
	_state.player.inventory.add(ItemTypes.EEL_TRAPS, 1)
	_hold(ItemTypes.EEL_TRAPS)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.EEL_TRAPS)
	assert_eq(_state.player.inventory.count_of(ItemTypes.EEL_TRAPS), 0)


func test_the_sea_past_the_end_of_the_jetty_is_not_walked_on() -> void:
	_jetty_out_at_sea(2)
	assert_false(_world.is_walkable(_tile + Vector2i.LEFT))
	assert_false(_world.is_walkable(_tile + Vector2i(2, 0)))
	_state.player.position = Vector2(_tile) + Vector2(0.5, 0.5)
	_walk(Vector2.LEFT, 2.0)
	assert_eq(_state.player.tile(), _tile, "stopped at the end")
	assert_true(PlayerState.can_stand_at(_world, _state.player.position))


func test_the_axe_leaves_the_jetty_the_player_stands_on() -> void:
	_jetty_out_at_sea(2)
	_stand_astride()
	_state.player.inventory.add(ItemTypes.AXE, 1)
	_hold(ItemTypes.AXE)
	assert_eq(_state.use_at(_tile), ToolUse.Use.STANDING_ON)
	for _i in 10:
		_state.use_facing_tile()
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.JETTY)
	_state.player.position = Vector2(_tile) + Vector2(1.5, 0.5)
	assert_eq(_state.use_at(_tile), ToolUse.Use.HIT, "stepped off it")


func test_the_hammer_leaves_the_jetty_the_player_stands_on() -> void:
	_jetty_out_at_sea(2)
	_stand_astride()
	var builder := Builder.new(_state)
	var target := builder.take_down_target(_tile)
	assert_ne(builder.why_not_take_down(target), "")
	assert_false(builder.take_down(target))
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.JETTY)


func test_a_player_left_over_the_water_can_step_back_onto_the_jetty() -> void:
	_jetty_out_at_sea(2)
	_stand_astride()
	_world.remove_object(_tile)
	assert_false(PlayerState.can_stand_at(_world, _state.player.position), "half in the sea")
	_walk(Vector2.RIGHT, 1.0)
	assert_true(PlayerState.can_stand_at(_world, _state.player.position), "back on the jetty")


func test_a_horse_ridden_onto_the_jetty_is_got_off_onto_the_jetty() -> void:
	_jetty_out_at_sea(3)
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.5))
	horse.is_saddled = true
	_state.livestock.add(horse)
	_state.mount(horse)
	_walk(Vector2.RIGHT, 0.5)
	assert_true(PlayerState.can_stand_at(_world, _state.player.position))
	assert_true(_state.dismount())
	assert_true(_world.is_walkable(_state.player.tile()), "on the jetty, not in the sea")
	assert_eq(_state.player.tile().y, _tile.y)
