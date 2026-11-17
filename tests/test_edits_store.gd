extends GutTest
## WorldEdits on its own: no world and no chunks, only what the player changed.

const POS := Vector2i(5, 7)

var _edits := WorldEdits.new()
var _edited_chunks: Array[Vector2i] = []


func before_each() -> void:
	_edits = WorldEdits.new()
	_edited_chunks = []
	_edits.edited.connect(_edited_chunks.append)


func test_an_edit_tells_the_chunk_it_is_in() -> void:
	_edits.edit_terrain(POS, Tile.Terrain.SOIL)
	_edits.edit_object(Vector2i(-1, 0), null)
	assert_eq(_edited_chunks, [Vector2i(0, 0), Vector2i(-1, 0)] as Array[Vector2i])


func test_a_removed_object_is_an_edit_that_holds_null() -> void:
	_edits.edit_object(POS, null)
	assert_true(_edits.has_object_edit(POS))
	assert_null(_edits.object_edit_at(POS))
	assert_false(_edits.has_object_edit(POS + Vector2i.RIGHT))


func test_scarecrows_and_campfires_are_found_until_they_are_replaced() -> void:
	var scarecrow := WorldObject.new(WorldObjectTypes.SCARECROW, POS)
	_edits.edit_object(POS, scarecrow)
	assert_eq(_edits.scarecrows(), [scarecrow] as Array[WorldObject])
	_edits.take_off(null, scarecrow)
	assert_eq(_edits.scarecrows(), [] as Array[WorldObject])
	assert_eq(_edits.edited_objects(), [] as Array[WorldObject], "a removed object is not listed")
