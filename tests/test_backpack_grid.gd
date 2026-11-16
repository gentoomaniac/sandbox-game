extends GutTest
## The backpack of a container screen: it shows the inventory, passes on Shift+click of its slots
## and of the hotbar's with the inventory slot, and dims by the screen's rule.

var _inventory: Inventory
var _hotbar: HotbarHud
var _grid: BackpackGrid
var _quick_moved: Array[int] = []


func before_each() -> void:
	_inventory = Inventory.new()
	_inventory.slots[1] = {"item": ItemTypes.LOGS, "count": 5}
	_inventory.slots[Inventory.HOTBAR_SIZE] = {"item": ItemTypes.LOGS, "count": 3}
	_inventory.slots[Inventory.HOTBAR_SIZE + 1] = {"item": ItemTypes.STONE, "count": 2}
	_hotbar = HotbarCase.new_hotbar(_inventory)
	add_child_autofree(_hotbar)
	_grid = BackpackGrid.new(_hotbar)
	add_child_autofree(_grid)
	_quick_moved.clear()
	_grid.quick_move_requested.connect(_quick_moved.append)


func test_it_shows_the_slots_of_the_backpack_and_not_the_hotbar() -> void:
	_grid.bind(_inventory)
	_grid.refresh()
	assert_eq(_grid.views.size(), Inventory.BACKPACK_SIZE)
	assert_eq(_grid.views[Inventory.HOTBAR_SIZE].container, _inventory)
	assert_eq(_grid.views[Inventory.HOTBAR_SIZE].count(), 3)
	assert_false(_grid.views.has(0))


func test_shift_click_on_a_backpack_slot_says_which() -> void:
	_grid.bind(_inventory)
	_grid.views[Inventory.HOTBAR_SIZE + 2].quick_move_requested.emit()
	assert_eq(_quick_moved, [Inventory.HOTBAR_SIZE + 2])


func test_shift_click_on_the_hotbar_says_which_only_while_bound() -> void:
	_grid.bind(_inventory)
	_hotbar._slot_views[1].quick_move_requested.emit()
	_grid.unbind()
	_hotbar._slot_views[1].quick_move_requested.emit()
	assert_eq(_quick_moved, [1])


func test_the_rule_dims_stacks_of_the_backpack_and_the_hotbar_and_unbinding_resets_them() -> void:
	_grid.dims_item = func(item: StringName) -> bool: return item == ItemTypes.STONE
	_grid.bind(_inventory)
	_grid.refresh()
	assert_true(_grid.views[Inventory.HOTBAR_SIZE + 1].is_dimmed)
	assert_false(_grid.views[Inventory.HOTBAR_SIZE].is_dimmed)
	assert_false(_grid.views[Inventory.HOTBAR_SIZE + 2].is_dimmed, "an empty slot is never dimmed")
	assert_false(_hotbar._slot_views[1].is_dimmed)
	_inventory.slots[1] = {"item": ItemTypes.STONE, "count": 1}
	_grid.refresh()
	assert_true(_hotbar._slot_views[1].is_dimmed)
	_grid.unbind()
	assert_false(_hotbar._slot_views[1].is_dimmed)


func test_nothing_is_dimmed_without_a_rule() -> void:
	_grid.bind(_inventory)
	_grid.refresh()
	assert_false(_grid.views[Inventory.HOTBAR_SIZE + 1].is_dimmed)
