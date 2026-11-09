extends GutTest
## The character screen and the chest screen share the HUD's hotbar: only the open one answers
## its clicks and marks its slots.

var _player: PlayerState
var _hotbar: HotbarHud
var _character: CharacterScreen
var _storage: StorageScreen
var _chest: WorldObject


func before_each() -> void:
	_player = PlayerState.new()
	_hotbar = HotbarHud.new()
	add_child_autofree(_hotbar)
	_hotbar.show_inventory(_player.inventory)
	_character = CharacterScreen.new(_hotbar)
	add_child_autofree(_character)
	_character.show_player(_player)
	_storage = StorageScreen.new(_hotbar)
	add_child_autofree(_storage)
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i.ZERO)
	_player.inventory.slots[2] = {"item": ItemTypes.LOGS, "count": 5}


func test_a_drag_from_the_hotbar_with_only_the_character_screen_open_is_its_alone() -> void:
	_character.open()
	_storage.open_chest(_chest, _player)
	_storage.close()
	_character.open()
	var backpack_view: SlotView = _character._inventory_views[Inventory.HOTBAR_SIZE]
	backpack_view._drop_data(Vector2.ZERO, {"from": _hotbar.slot_view(2)})
	assert_true(_player.inventory.slots[2].is_empty())
	assert_eq(_player.inventory.slots[Inventory.HOTBAR_SIZE], {"item": ItemTypes.LOGS, "count": 5})
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 0, "the chest seen before is not involved")


func test_shift_click_on_the_hotbar_goes_to_the_backpack_not_into_a_chest_seen_before() -> void:
	_storage.open_chest(_chest, _player)
	_storage.close()
	_character.open()
	_hotbar.slot_view(2).quick_move_requested.emit()
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 0)
	assert_eq(_player.inventory.count_of(ItemTypes.LOGS), 5)
	assert_true(_player.inventory.slots[2].is_empty())


func test_shift_click_on_the_hotbar_with_the_chest_open_goes_into_the_chest_only() -> void:
	_storage.open_chest(_chest, _player)
	_hotbar.slot_view(2).quick_move_requested.emit()
	assert_eq(_chest.storage.count_of(ItemTypes.LOGS), 5)
	assert_eq(_player.inventory.count_of(ItemTypes.LOGS), 0)


func test_a_closed_screen_leaves_the_hotbar_alone_and_on_the_hud_layer() -> void:
	_character.open()
	assert_eq(_hotbar.layer, HotbarHud.CLICKABLE_LAYER)
	_character.close()
	assert_eq(_hotbar.layer, HotbarHud.IDLE_LAYER)
	assert_false(_hotbar.slot_view(2).is_clickable)
