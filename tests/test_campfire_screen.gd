extends GutTest
## The campfire window's backpack: stacks that are not wood are dimmed, Shift+click puts wood in the
## fuel slot, and closing the window gives the hotbar back plain.

var _state: GameState
var _inventory: Inventory
var _hotbar: HotbarHud
var _screen: CampfireScreen
var _fire: WorldObject


func before_each() -> void:
	_state = GameState.new_game(7)
	_inventory = Inventory.new()
	_state.player.inventory = _inventory
	_inventory.slots[1] = {"item": ItemTypes.STONE, "count": 2}
	_inventory.slots[2] = {"item": ItemTypes.LOGS, "count": 5}
	_inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 3}
	_inventory.slots[Inventory.HOTBAR_SIZE + 1] = {"item": ItemTypes.STONE, "count": 4}
	_hotbar = HotbarCase.new_hotbar(_inventory)
	add_child_autofree(_hotbar)
	_screen = CampfireScreen.new(_hotbar)
	add_child_autofree(_screen)
	_fire = WorldObject.new(WorldObjectTypes.FIREPLACE, Vector2i.ZERO)
	_screen.open_fire(_fire, _state)


func test_only_stacks_that_are_not_wood_are_dimmed() -> void:
	var views: Dictionary = _screen._backpack.views
	assert_false(views[Inventory.HOTBAR_SIZE].is_dimmed, "wood in the backpack")
	assert_true(views[Inventory.HOTBAR_SIZE + 1].is_dimmed, "stone in the backpack")
	assert_false(_hotbar._slot_views[2].is_dimmed, "wood on the hotbar")
	assert_true(_hotbar._slot_views[1].is_dimmed, "stone on the hotbar")


func test_shift_click_on_wood_of_the_backpack_or_the_hotbar_puts_it_in_the_fuel_slot() -> void:
	_screen._backpack.views[Inventory.HOTBAR_SIZE].quick_move_requested.emit()
	assert_eq(_fire.storage.count_of(ItemTypes.LOGS), 3)
	_hotbar._slot_views[2].quick_move_requested.emit()
	assert_eq(_fire.storage.count_of(ItemTypes.LOGS), 8)


func test_shift_click_on_stone_moves_nothing() -> void:
	_screen._backpack.views[Inventory.HOTBAR_SIZE + 1].quick_move_requested.emit()
	assert_eq(_fire.storage.count_of(ItemTypes.STONE), 0)
	assert_eq(_inventory.count_of(ItemTypes.STONE), 6)


func test_closing_resets_the_dimming_and_releases_the_hotbar() -> void:
	_screen.close()
	assert_false(_hotbar._slot_views[1].is_dimmed)
	assert_false(_hotbar.is_borrowed_by(_screen._backpack))
	assert_false(_hotbar._slot_views[2].is_clickable)
	_hotbar._slot_views[2].quick_move_requested.emit()
	assert_eq(_fire.storage.count_of(ItemTypes.LOGS), 0, "the closed window does not answer")
