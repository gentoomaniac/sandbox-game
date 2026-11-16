extends ResourceCase
## What the box by the cursor says about the world (WorldHoverText): a building's occupants for
## the mouse only, a crop's state for the mouse and for the tile the player faces.


func _aim(tile: Vector2i, source: Targeting.Source) -> Targeting:
	var targeting := Targeting.new()
	targeting.tile = tile
	targeting.source = source
	return targeting


func test_a_crop_speaks_to_the_mouse_and_to_the_facing_tile() -> void:
	_place(WorldObjectTypes.TURNIP)
	var expected := WorldHoverText.object_text_at(_state, _tile)

	assert_ne(expected, "")
	for source: Targeting.Source in [Targeting.Source.MOUSE, Targeting.Source.FACING]:
		assert_eq(WorldHoverText.text_for(_state, _aim(_tile, source), true), expected)


func test_nothing_while_off_the_world() -> void:
	_place(WorldObjectTypes.TURNIP)

	assert_eq(WorldHoverText.text_for(_state, _aim(_tile, Targeting.Source.FACING), false), "")


func test_a_building_speaks_to_the_mouse_only() -> void:
	var barn: Building
	for y in range(-30, 31, 6):
		for x in range(-30, 31, 6):
			if barn == null:
				barn = _world.place_building(BuildingTypes.BARN, _tile + Vector2i(x, y))
	assert_not_null(barn, "room for a barn")
	var tile := barn.origin

	assert_eq(
		WorldHoverText.text_for(_state, _aim(tile, Targeting.Source.MOUSE), true),
		_state.homes.occupants_text(barn)
	)
	assert_eq(WorldHoverText.text_for(_state, _aim(tile, Targeting.Source.FACING), true), "")
