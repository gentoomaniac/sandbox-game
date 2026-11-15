extends DragCase
## The chest's screen tells what the player took out of the chest when it is closed (a harm if the
## chest is a villager's, see Harm); putting things in tells nothing.

var _inventory: Inventory
var _chest: WorldObject
var _screen: StorageScreen
var _taken: Array[Dictionary] = []


func before_each() -> void:
	_taken.clear()
	_inventory = Inventory.new()
	_chest = WorldObject.new(WorldObjectTypes.CHEST, Vector2i(3, 4))
	_chest.storage.add(ItemTypes.LOGS, 5)
	var player := PlayerState.new()
	player.inventory = _inventory
	_make_window()
	var hotbar := HotbarCase.new_hotbar()
	_window.add_child(hotbar)
	hotbar.show_inventory(_inventory)
	_screen = StorageScreen.new(hotbar)
	_window.add_child(_screen)
	_screen.taken_from.connect(
		func(chest: WorldObject, items: Dictionary) -> void: _taken.append(items)
	)
	_screen.open_chest(_chest, player)
	await wait_process_frames(2)


func test_what_was_taken_is_told_when_the_screen_closes() -> void:
	_chest.storage.send(0, _inventory)

	_screen.close()

	assert_eq(_taken, [{ItemTypes.LOGS: 5}] as Array[Dictionary])


func test_putting_things_in_is_not_taking() -> void:
	_inventory.add(ItemTypes.STONE, 2)
	_inventory.send(
		_inventory.slots.find_custom(func(s: Dictionary) -> bool: return not s.is_empty()),
		_chest.storage
	)

	_screen.close()

	assert_eq(_taken, [] as Array[Dictionary])
