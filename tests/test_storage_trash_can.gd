extends GutTest
## The chest screen's trash can: a stack of either side put on it is destroyed only after the
## question is answered with Destroy; Keep, Escape or a click elsewhere keep the pick.

var _inventory: Inventory
var _chest: WorldObject
var _screen: StorageScreen
var _trash_can: TrashCan


func before_each() -> void:
	_inventory = Inventory.new()
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	var player := PlayerState.new()
	player.inventory = _inventory
	_screen = StorageScreen.new(autofree(HotbarHud.new()))
	add_child_autofree(_screen)
	_screen.open_chest(_chest, player)
	_trash_can = _screen._trash_can
	# The window's centre container places the panel a frame later.
	await wait_process_frames(1)


## Picks 12 logs from slot 0 of `side` of the screen and puts them on the trash can.
func _put_logs_on_the_trash_can(side: int) -> void:
	var slots: ItemSlots = _inventory if side == StorageScreen.INVENTORY else _chest.storage
	slots.add(ItemTypes.LOGS, 12, [0])
	_screen._views[side][0].pressed.emit()
	_trash_can._slot.pressed.emit()


func _press_escape() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_screen._unhandled_input(event)


func _click(position: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = position
	get_viewport().push_input(click)


func test_a_stack_of_the_backpack_is_destroyed_after_the_question() -> void:
	_inventory.add(ItemTypes.STONE, 3, [1])
	_put_logs_on_the_trash_can(StorageScreen.INVENTORY)
	assert_eq(_trash_can._question.text, "Destroy Logs (12)?")
	assert_eq(_inventory.count_of(ItemTypes.LOGS), 12, "nothing is destroyed yet")
	_trash_can._destroy_button.pressed.emit()
	assert_eq(_inventory.count_of(ItemTypes.LOGS), 0)
	assert_eq(_inventory.count_of(ItemTypes.STONE), 3)
	assert_true(_screen._pick.is_empty())


func test_a_stack_of_the_chest_is_destroyed_after_the_question() -> void:
	_chest.storage.add(ItemTypes.STONE, 3, [1])
	_put_logs_on_the_trash_can(StorageScreen.CHEST)
	_trash_can._destroy_button.pressed.emit()
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 0)
	assert_eq(_chest.storage.count_of(ItemTypes.STONE), 3)


func test_keep_leaves_the_stack_picked() -> void:
	_put_logs_on_the_trash_can(StorageScreen.CHEST)
	_trash_can._keep_button.pressed.emit()
	assert_false(_trash_can.is_asking())
	assert_eq(_screen._pick, {"side": StorageScreen.CHEST, "slot": 0})
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 12)


func test_escape_answers_keep_and_does_not_close_the_screen() -> void:
	_put_logs_on_the_trash_can(StorageScreen.INVENTORY)
	_press_escape()
	assert_true(_screen.is_open())
	assert_false(_trash_can.is_asking())
	assert_false(_screen._pick.is_empty())
	_press_escape()
	assert_false(_screen.is_open())


func test_a_click_elsewhere_answers_keep_and_drops_nothing() -> void:
	_put_logs_on_the_trash_can(StorageScreen.INVENTORY)
	watch_signals(_screen)
	_click(Vector2(4, 4))
	assert_false(_trash_can.is_asking())
	assert_false(_screen._pick.is_empty())
	assert_signal_not_emitted(_screen, "drop_requested")


func test_a_click_on_a_slot_answers_keep_and_moves_nothing() -> void:
	_put_logs_on_the_trash_can(StorageScreen.INVENTORY)
	_click(_screen._views[StorageScreen.CHEST][1].get_global_rect().get_center())
	assert_false(_trash_can.is_asking())
	assert_eq(_inventory.slots[0], {"item": ItemTypes.LOGS, "count": 12})
	assert_true(_chest.storage.slots[1].is_empty())
	assert_false(_screen._pick.is_empty())


func test_closing_the_screen_while_asking_destroys_nothing() -> void:
	_put_logs_on_the_trash_can(StorageScreen.CHEST)
	_screen.close()
	assert_false(_trash_can.is_asking())
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 12)
