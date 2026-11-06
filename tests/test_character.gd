extends GutTest
## The character's layers: what is worn is data, and the facing decides the draw order and
## the frame.

var _appearance: Appearance


func before_each() -> void:
	_appearance = Appearance.new()
	_appearance.wear(Appearance.HELD, "hoe")


func _equipment_with(item: StringName) -> Equipment:
	var equipment := Equipment.new()
	equipment.equip(Equipment.slot_of(item), item)
	return equipment


func _variant_of(slot: StringName) -> String:
	for layer in _appearance.layers:
		if layer.slot == slot:
			return layer.variant
	return ""


func _slots(layers: Array[Dictionary]) -> Array:
	return layers.map(func(layer: Dictionary) -> StringName: return layer.slot)


func _worn_appearance() -> Appearance:
	var equipment := Equipment.with_starting_outfit()
	equipment.equip(Equipment.HEAD, ItemTypes.STRAW_HAT)
	_appearance.dress(equipment)
	return _appearance


func test_layers_are_drawn_in_the_draw_order() -> void:
	assert_eq(
		_slots(_worn_appearance().layers_for(Vector2i.DOWN)),
		[
			Appearance.BODY,
			Appearance.LEGS,
			Appearance.CLOTHES,
			Appearance.HAIR,
			Appearance.HEAD,
			Appearance.HELD
		]
	)


func test_a_layer_worn_later_still_goes_in_its_place_in_the_order() -> void:
	_appearance.wear(Appearance.HEAD, "straw_hat")
	_appearance.wear(Appearance.LEGS, "0")
	assert_eq(
		_slots(_appearance.layers_for(Vector2i.DOWN)),
		[Appearance.BODY, Appearance.LEGS, Appearance.HAIR, Appearance.HEAD, Appearance.HELD]
	)


func test_a_hat_is_drawn_over_the_hair() -> void:
	_appearance.dress(_equipment_with(ItemTypes.STRAW_HAT))
	var slots := _slots(_appearance.layers_for(Vector2i.DOWN))
	assert_gt(slots.find(Appearance.HEAD), slots.find(Appearance.HAIR))


func test_a_jacket_is_drawn_over_the_clothes_and_under_the_hair() -> void:
	var equipment := Equipment.with_starting_outfit()
	equipment.equip(Equipment.COAT, ItemTypes.JACKET)
	_appearance.dress(equipment)
	var slots := _slots(_appearance.layers_for(Vector2i.DOWN))
	assert_eq(slots.find(Appearance.COAT), slots.find(Appearance.CLOTHES) + 1)
	assert_eq(slots.find(Appearance.HAIR), slots.find(Appearance.COAT) + 1)


func test_dressing_follows_the_equipment() -> void:
	var equipment := _equipment_with(ItemTypes.SHIRT)
	_appearance.dress(equipment)
	assert_eq(_variant_of(Appearance.CLOTHES), "1")
	assert_eq(_variant_of(Appearance.HEAD), "")
	equipment.unequip(Equipment.BODY)
	_appearance.dress(equipment)
	assert_eq(_variant_of(Appearance.CLOTHES), "")


func test_the_body_and_hair_stay_when_nothing_is_worn() -> void:
	_appearance.dress(Equipment.new())
	assert_eq(
		_slots(_appearance.layers_for(Vector2i.DOWN)),
		[Appearance.BODY, Appearance.HAIR, Appearance.HELD]
	)


func test_every_wearable_has_a_sheet() -> void:
	for item: StringName in ItemTypes.TYPES:
		if Equipment.slot_of(item) in Appearance.LAYER_OF_EQUIPMENT_SLOT:
			var layer_slot: StringName = Appearance.LAYER_OF_EQUIPMENT_SLOT[Equipment.slot_of(item)]
			var layer := {slot = layer_slot, variant = ItemTypes.TYPES[item]["layer_variant"]}
			assert_true(ResourceLoader.exists(Appearance.sheet_path(layer)), str(item))


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
	assert_eq(Appearance.sheet_path(layers[1]), "res://assets/character/clothes_7.png")


func test_a_slot_that_is_not_in_the_draw_order_is_added_on_top() -> void:
	_appearance.wear(&"cape", "red")
	assert_eq(_slots(_appearance.layers_for(Vector2i.DOWN)).back(), &"cape")


func test_taking_off_removes_the_layer() -> void:
	_appearance.take_off(Appearance.HELD)
	assert_false(Appearance.HELD in _slots(_appearance.layers_for(Vector2i.UP)))


func test_every_default_layer_has_a_sheet() -> void:
	for layer in _appearance.layers:
		assert_true(ResourceLoader.exists(Appearance.sheet_path(layer)), str(layer))


func test_hair_sheets_exist() -> void:
	for hair in PlayerView.HAIR_COUNT:
		assert_true(
			ResourceLoader.exists(
				Appearance.sheet_path({slot = Appearance.HAIR, variant = str(hair)})
			)
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
