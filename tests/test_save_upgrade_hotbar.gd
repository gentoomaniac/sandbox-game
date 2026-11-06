extends SaveUpgradeCase
## Version 11 saves have a hotbar of eight slots: a version 10 save moves what was in the other
## two (see SaveFile).


## A version 10 save with `slot_8` and `slot_9` (stacks as saved) in the two hotbar slots that
## version 11 dropped.
func _version_10_game_with(slot_8: Variant, slot_9: Variant) -> Dictionary:
	var game := _in_version_10_layout(_current_game())
	var slots: Array = game["player"]["inventory"]["slots"]
	slots[8] = slot_8
	slots[9] = slot_9
	return game


func test_a_version_10_save_moves_the_items_of_the_dropped_hotbar_slots_into_the_backpack() -> void:
	var game := _version_10_game_with({"item": "logs", "count": 8}, {"item": "berries", "count": 4})
	game["player"]["inventory"]["slots"][12] = {"item": "logs", "count": 5}
	game["player"]["inventory"]["selected_slot"] = 9
	_write_save(10, game)

	var restored := SaveFile.read(SAVE_PATH)

	var inventory := restored.player.inventory
	assert_eq(inventory.slots.size(), Inventory.SLOT_COUNT)
	assert_eq(inventory.item_in(0), ItemTypes.HOE)
	assert_eq(inventory.selected_slot, 0)
	# The backpack kept its order (slots 10 to 13 became 8 to 11); the logs joined their stack
	# (12 became 10), the berries took the first free slot.
	assert_eq(inventory.item_in(Inventory.HOTBAR_SIZE), ItemTypes.STRAW_HAT)
	assert_eq(inventory.slots[Inventory.HOTBAR_SIZE + 2], {"item": ItemTypes.LOGS, "count": 13})
	assert_eq(inventory.slots[Inventory.HOTBAR_SIZE + 4], {"item": ItemTypes.BERRIES, "count": 4})
	assert_eq(restored.world.ground_items.all().size(), 0)


func test_a_version_10_save_puts_what_has_no_room_in_the_backpack_at_the_players_feet() -> void:
	var game := _version_10_game_with({"item": "logs", "count": 8}, {"item": "stone", "count": 3})
	var slots: Array = game["player"]["inventory"]["slots"]
	for slot in range(Inventory.HOTBAR_SIZE + 2, 30):
		slots[slot] = {"item": "turnip", "count": 99}
	slots[10] = {"item": "stone", "count": 98}
	game["player"]["position"] = [12.5, 7.25]
	_write_save(10, game)

	var restored := SaveFile.read(SAVE_PATH)

	# One stone fits on the stack of stone; the logs and the other two stones lie down.
	var inventory := restored.player.inventory
	assert_eq(inventory.count_of(ItemTypes.STONE), 99)
	assert_eq(inventory.count_of(ItemTypes.LOGS), 0)
	var ground_items := restored.world.ground_items
	assert_eq(ground_items.count_of(ItemTypes.LOGS), 8)
	assert_eq(ground_items.count_of(ItemTypes.STONE), 2)
	for ground_item in ground_items.all():
		assert_almost_eq(ground_item.position.y, 7.25, 0.0001)
		assert_almost_eq(ground_item.position.x, 12.5, 0.5)
