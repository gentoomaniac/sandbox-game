extends GutTest
## The held layer of the appearance follows the selected item by itself, with no PlayerView
## processing (the character preview draws the same appearance).

var _player := PlayerState.new()


func _held_variant(player: PlayerState) -> Variant:
	for layer in player.appearance.layers:
		if layer.slot == Appearance.HELD:
			return layer.variant
	return null


func test_a_player_with_the_starting_items_holds_the_hoe() -> void:
	_player.inventory = Inventory.with_starting_items()
	assert_eq(_held_variant(_player), ItemTypes.TYPES[ItemTypes.HOE]["held_sheet"])


func test_selecting_another_slot_changes_the_held_layer() -> void:
	_player.inventory = Inventory.with_starting_items()
	_player.inventory.select(1)
	assert_eq(_held_variant(_player), ItemTypes.TYPES[ItemTypes.AXE]["held_sheet"])


func test_an_item_with_no_art_for_the_hand_empties_the_held_layer() -> void:
	_player.inventory = Inventory.with_starting_items()
	_player.inventory.select(4)
	assert_null(_held_variant(_player), "turnip seeds")


func test_moving_the_held_item_away_empties_the_held_layer() -> void:
	_player.inventory = Inventory.with_starting_items()
	_player.inventory.move_to(0, _player.inventory, Inventory.HOTBAR_SIZE + 10)
	assert_null(_held_variant(_player))


func test_a_loaded_player_holds_the_selected_item() -> void:
	_player.inventory = Inventory.with_starting_items()
	_player.inventory.select(2)
	var loaded := PlayerState.from_dict(_player.to_dict(), null)
	assert_eq(_held_variant(loaded), ItemTypes.TYPES[ItemTypes.PICKAXE]["held_sheet"])


func test_the_old_inventory_no_longer_changes_the_look() -> void:
	var old := Inventory.with_starting_items()
	_player.inventory = old
	_player.inventory = Inventory.new()
	old.select(1)
	assert_null(_held_variant(_player))
