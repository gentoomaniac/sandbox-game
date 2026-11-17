extends GutTest
## An object edit that a night has brought back to what the generator puts on its tile is dropped,
## so the save keeps only what is still different.

const SEED := 42
## A chunk with trees and tufts of tall grass on it.
const COORDS := Vector2i(0, -2)

var _world: World
var _generator := WorldGenerator.new(SEED)
var _night: NightUpkeep


func before_each() -> void:
	_world = World.new(SEED)
	_world.add_chunk(_generator.generate_chunk(COORDS))
	_night = NightUpkeep.new(_world, Weather.new(SEED), func() -> Array: return [])


func _generated(type: StringName) -> WorldObject:
	for object in _world.chunk_at(COORDS).objects():
		if object.type == type:
			return object
	fail_test("no %s in the chunk" % type)
	return null


## Whether the save would keep an edit of the tile.
func _is_saved(world: World, pos: Vector2i) -> bool:
	var saved_pos := SaveCodec.vector_to_json(pos)
	return world.to_dict()["object_edits"].any(
		func(edit: Dictionary) -> bool: return edit["pos"] == saved_pos
	)


func test_a_healed_tree_is_no_edit_any_more() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	_world.hit_object(tree, 1)
	assert_true(_is_saved(_world, tree.pos))
	_night.pass_night()
	assert_false(_is_saved(_world, tree.pos))
	assert_does_not_have(_world.edited_objects(), tree)


func test_a_tuft_that_regrew_is_no_edit_any_more() -> void:
	var tuft := _generated(WorldObjectTypes.TALL_GRASS)
	tuft.pick()
	_world.change_object(tuft)
	var nights := 0
	while _is_saved(_world, tuft.pos) and nights < 20:
		_night.pass_night()
		nights += 1
	assert_false(_is_saved(_world, tuft.pos))
	assert_gt(nights, 1, "it stayed an edit while it was picked")


func test_a_felled_tree_stays_an_edit() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	_world.take_off(tree)
	_night.pass_night()
	assert_true(_is_saved(_world, tree.pos))


func test_a_placed_object_stays_an_edit() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	_world.take_off(tree)
	_world.add_object(WorldObject.new(WorldObjectTypes.STONE, tree.pos))
	_night.pass_night()
	assert_true(_is_saved(_world, tree.pos))
	assert_eq(_world.object_at(tree.pos).type, WorldObjectTypes.STONE)


func test_a_state_that_holds_a_default_value_counts_as_changed() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	tree.state["damage"] = 0
	_world.change_object(tree)
	_world.drop_edit_if_generated(tree)
	assert_true(_is_saved(_world, tree.pos))


func test_an_edit_in_an_unloaded_chunk_is_dropped_too() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	_world.hit_object(tree, 1)
	_world.remove_chunk(COORDS)
	_night.pass_night()
	assert_false(_is_saved(_world, tree.pos))


func test_the_world_looks_the_same_after_saving_and_loading() -> void:
	var healed := _generated(WorldObjectTypes.OAK)
	_world.hit_object(healed, 1)
	var felled := _generated(WorldObjectTypes.BIRCH)
	_world.take_off(felled)
	_night.pass_night()
	var restored := World.from_dict(_world.to_dict(), GameClock.new())
	restored.add_chunk(_generator.generate_chunk(COORDS))
	assert_eq(restored.object_at(healed.pos).type, healed.type)
	assert_eq(restored.object_at(healed.pos).state, {})
	assert_null(restored.object_at(felled.pos))
	assert_eq(restored.edited_objects().size(), _world.edited_objects().size())


func test_a_save_with_a_redundant_edit_still_loads() -> void:
	var tree := _generated(WorldObjectTypes.OAK)
	_world.change_object(tree)
	var restored := World.from_dict(_world.to_dict(), GameClock.new())
	restored.add_chunk(_generator.generate_chunk(COORDS))
	assert_eq(restored.object_at(tree.pos).type, tree.type)
	assert_true(_is_saved(restored, tree.pos))
