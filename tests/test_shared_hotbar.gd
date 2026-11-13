extends GutTest
## The bag and the chest screen share the HUD's hotbar: only the open one answers
## its clicks and marks its slots.

var _player: PlayerState
var _hotbar: HotbarHud
var _bag: BagScreen
var _storage: StorageScreen
var _chest: WorldObject


func before_each() -> void:
	_player = PlayerState.new()
	_hotbar = HotbarCase.new_hotbar()
	add_child_autofree(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_bag = BagScreen.new(_hotbar)
	add_child_autofree(_bag)
	_bag.show_player(_player)
	_storage = StorageScreen.new(_hotbar)
	add_child_autofree(_storage)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	_player.inventory.slots[2] = {"item": ItemTypes.LOGS, "count": 5}


func test_a_drag_from_the_hotbar_with_only_the_bag_screen_open_is_its_alone() -> void:
	_bag.open()
	_storage.open_chest(_chest, _player)
	_storage.close()
	_bag.open()
	var backpack_view: SlotView = _bag._backpack_views[Inventory.HOTBAR_SIZE]
	backpack_view._drop_data(Vector2.ZERO, {"from": _hotbar._slot_views[2]})
	assert_true(_player.inventory.slots[2].is_empty())
	assert_eq(_player.inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.LOGS, "count": 5})
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 0, "the chest seen before is not involved")


func test_shift_click_on_the_hotbar_goes_to_the_backpack_not_into_a_chest_seen_before() -> void:
	_storage.open_chest(_chest, _player)
	_storage.close()
	_bag.open()
	_hotbar._slot_views[2].quick_move_requested.emit()
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 0)
	assert_eq(_player.inventory.count_of(ItemTypes.LOGS), 5)
	assert_true(_player.inventory.slots[2].is_empty())


func test_shift_click_on_the_hotbar_with_the_chest_open_goes_into_the_chest_only() -> void:
	_storage.open_chest(_chest, _player)
	_hotbar._slot_views[2].quick_move_requested.emit()
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 5)
	assert_eq(_player.inventory.count_of(ItemTypes.LOGS), 0)


func test_a_closed_screen_leaves_the_hotbar_alone_and_on_the_hud_layer() -> void:
	_bag.open()
	assert_eq(_hotbar.layer, HotbarHud.CLICKABLE_LAYER)
	_bag.close()
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)
	assert_false(_hotbar._slot_views[2].is_clickable)


func _assert_hotbar_is_back_with_the_game() -> void:
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)
	for view in _hotbar._slot_views:
		assert_false(view.is_clickable)
		assert_null(view.container, "no screen's inventory left on the slots")
		assert_eq(view.modulate.a, 1.0)


func test_freeing_an_open_chest_screen_gives_the_hotbar_back() -> void:
	_storage.open_chest(_chest, _player)
	_hotbar._slot_views[2].modulate.a = SlotView.DRAGGED_ALPHA
	remove_child(_storage)
	_storage.free()
	_assert_hotbar_is_back_with_the_game()


func test_freeing_an_open_bag_screen_gives_the_hotbar_back() -> void:
	_bag.open()
	remove_child(_bag)
	_bag.free()
	_assert_hotbar_is_back_with_the_game()


func test_a_screen_that_does_not_have_the_hotbar_cannot_release_it() -> void:
	_bag.open()
	_hotbar.release(_storage)
	assert_eq(_hotbar.layer, HotbarHud.CLICKABLE_LAYER)


func test_screens_open_when_their_hotbar_is_freed_first_close_without_it() -> void:
	_storage.open_chest(_chest, _player)
	remove_child(_hotbar)
	_hotbar.free()
	remove_child(_storage)
	_storage.free()
	assert_false(Modal.is_any_open())
	_bag.open()
	remove_child(_bag)
	_bag.free()
	assert_false(Modal.is_any_open())


func test_the_first_screen_letting_go_leaves_the_hotbar_with_the_second() -> void:
	var first := RefCounted.new()
	var second := RefCounted.new()
	_hotbar.acquire(first)
	_hotbar.acquire(second)
	_hotbar.release(first)
	assert_true(_hotbar.is_borrowed_by(second))
	assert_eq(_hotbar.layer, HotbarHud.CLICKABLE_LAYER)
	assert_true(_hotbar._slot_views[2].is_clickable)
	assert_eq(_hotbar._slot_views[2].container, _player.inventory, "the slots stay bound")
	_hotbar.release(second)
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)


func test_a_screen_letting_go_ends_a_drag_from_the_hotbar_even_if_another_keeps_it() -> void:
	var first := RefCounted.new()
	var second := RefCounted.new()
	_hotbar.acquire(first)
	_hotbar.acquire(second)
	_hotbar._slot_views[2].modulate.a = SlotView.DRAGGED_ALPHA
	_hotbar.release(second)
	assert_eq(_hotbar._slot_views[2].modulate.a, 1.0)


func test_screens_sharing_the_hotbar_answer_in_turn_and_the_last_to_let_go_gives_it_back() -> void:
	var first := RefCounted.new()
	var second := RefCounted.new()
	_hotbar.acquire(first)
	_hotbar.acquire(second)
	assert_true(_hotbar.is_borrowed_by(second))
	assert_false(_hotbar.is_borrowed_by(first))
	_hotbar.release(second)
	assert_true(_hotbar.is_borrowed_by(first), "the one before answers again")
	assert_eq(_hotbar.layer, HotbarHud.CLICKABLE_LAYER)
	_hotbar.release(first)
	assert_false(_hotbar.is_borrowed_by(first))
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)
