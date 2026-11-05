extends GutTest
## The character's layers: what is worn is data, and the facing decides the draw order and
## the frame.

var _appearance: Appearance


func before_each() -> void:
	_appearance = Appearance.new()


func _slots(layers: Array[Dictionary]) -> Array:
	return layers.map(func(layer: Dictionary) -> StringName: return layer.slot)


func test_layers_are_drawn_in_list_order() -> void:
	assert_eq(
		_slots(_appearance.layers_for(Vector2i.DOWN)),
		[Appearance.BODY, Appearance.LEGS, Appearance.CLOTHES, Appearance.HAIR, Appearance.HELD]
	)


func test_held_item_is_behind_the_body_when_facing_up() -> void:
	assert_eq(_slots(_appearance.layers_for(Vector2i.UP))[0], Appearance.HELD)
	assert_eq(_slots(_appearance.layers_for(Vector2i.UP))[1], Appearance.BODY)


func test_held_item_is_in_front_when_facing_sideways() -> void:
	assert_eq(_slots(_appearance.layers_for(Vector2i.LEFT)).back(), Appearance.HELD)
	assert_eq(_slots(_appearance.layers_for(Vector2i.RIGHT)).back(), Appearance.HELD)


func test_wearing_replaces_the_variant_in_a_slot() -> void:
	_appearance.wear(Appearance.CLOTHES, "1")
	var clothes := _appearance.layers.filter(
		func(l: Dictionary) -> bool: return l.slot == Appearance.CLOTHES
	)
	assert_eq(clothes.size(), 1)
	assert_eq(clothes[0].variant, "1")


func test_a_new_variant_needs_only_data() -> void:
	_appearance.wear(Appearance.CLOTHES, "7")
	var layers := _appearance.layers_for(Vector2i.DOWN)
	assert_eq(Appearance.sheet_path(layers[2]), "res://assets/character/clothes_7.png")


func test_a_new_slot_is_added_on_top() -> void:
	_appearance.wear(&"hat", "straw")
	assert_eq(_slots(_appearance.layers_for(Vector2i.DOWN)).back(), &"hat")


func test_taking_off_removes_the_layer() -> void:
	_appearance.take_off(Appearance.HELD)
	assert_false(Appearance.HELD in _slots(_appearance.layers_for(Vector2i.UP)))


func test_every_default_layer_has_a_sheet() -> void:
	for layer in _appearance.layers:
		assert_true(ResourceLoader.exists(Appearance.sheet_path(layer)), str(layer))


func test_outfit_sheets_exist() -> void:
	for slot in PlayerView.OUTFIT_SLOTS:
		for outfit in PlayerView.OUTFIT_COUNT:
			assert_true(
				ResourceLoader.exists(Appearance.sheet_path({slot = slot, variant = str(outfit)}))
			)


func test_standing_shows_the_idle_column() -> void:
	assert_eq(PlayerView.frame_column(false, 3.0), PlayerView.IDLE_COLUMN)


func test_walking_steps_through_the_cycle() -> void:
	var step := 1.0 / PlayerView.WALK_FRAMES_PER_SECOND
	var columns := []
	for i in PlayerView.WALK_COLUMNS.size():
		columns.append(PlayerView.frame_column(true, (i + 0.5) * step))
	assert_eq(columns, PlayerView.WALK_COLUMNS)


func test_frame_index_picks_the_row_of_the_facing() -> void:
	var frames := PlayerView.FRAMES_PER_FACING
	assert_eq(PlayerView.frame_index(Vector2i.DOWN, 2), 2)
	assert_eq(PlayerView.frame_index(Vector2i.UP, 0), frames)
	assert_eq(PlayerView.frame_index(Vector2i.LEFT, 1), 2 * frames + 1)
	assert_eq(PlayerView.frame_index(Vector2i.RIGHT, 4), 4 * frames - 1)


func test_every_sheet_has_the_frame_grid() -> void:
	for layer in _appearance.layers:
		var sheet: Texture2D = load(Appearance.sheet_path(layer))
		assert_eq(
			sheet.get_size(),
			Vector2(
				PlayerView.FRAMES_PER_FACING * 16,
				PlayerView.FACING_ROWS.size() * PlayerView.FRAME_HEIGHT
			),
			str(layer)
		)
