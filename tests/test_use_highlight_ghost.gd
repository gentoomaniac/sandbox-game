extends GutTest
## The ghost the highlight shows for a held item that places an object.

var _state: GameState
var _highlight: UseHighlight


func before_each() -> void:
	_state = GameState.new_game(7)
	_highlight = UseHighlight.new()
	add_child_autofree(_highlight)
	_highlight.show_for(_state, null)


func _hold(item: StringName) -> void:
	_state.player.inventory.add(item, 1)
	HotbarHold.hold(_state.player.inventory, item)


func test_an_item_that_places_nothing_has_no_ghost() -> void:
	_hold(ItemTypes.RUSTY_IRON_AXE)
	assert_null(_highlight._ghost_texture())


func test_furniture_shows_its_interior_picture() -> void:
	_hold(ItemTypes.CHEST)
	assert_not_null(_highlight._ghost_texture())


func test_an_outdoor_object_shows_its_cell_of_the_object_atlas() -> void:
	_hold(ItemTypes.STONE_WALL)
	var ghost := _highlight._ghost_texture() as AtlasTexture
	assert_not_null(ghost)
	assert_eq(ghost.region.size, Vector2(ObjectTileset.CELL_WIDTH, ObjectTileset.CELL_HEIGHT))
	assert_same(_highlight._ghost_texture(), ghost, "the same picture every frame")
