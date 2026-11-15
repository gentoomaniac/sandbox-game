extends ResourceCase
## A piece the player puts down that a quest asks for (the wattle fence of a build quest) notes the
## day it was put down, for the quest to count; other objects stay as they were.


func _put_down(item: StringName) -> WorldObject:
	_state.player.inventory.add(item, 1)
	_state.player.inventory.hold(item)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)
	return _world.object_at(_tile)


func test_a_wattle_fence_is_put_down_with_the_day() -> void:
	_state.clock.day = 9

	var fence := _put_down(ItemTypes.WATTLE_FENCE)

	assert_eq(fence.type, WorldObjectTypes.WATTLE_FENCE)
	assert_eq(int(fence.state["placed_day"]), 9)


func test_an_object_no_quest_asks_for_has_no_day() -> void:
	var wall := _put_down(ItemTypes.STONE_WALL)

	assert_eq(wall.type, WorldObjectTypes.STONE_WALL)
	assert_false(wall.state.has("placed_day"))
