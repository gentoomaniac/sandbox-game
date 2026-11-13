extends GutTest
## Playing beside the bag and the character window: the hammer's hold to take down counts only a
## press that began on the world, and a door or a sleep closes the windows.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0

var _main: Node


func before_each() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await wait_until(
		func() -> bool: return _main._view != null and _main._view.is_settled, SETTLE_SECONDS
	)


func after_each() -> void:
	Input.action_release(&"use_click")
	_main._saves.wait()
	_main.free()


func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_main._unhandled_input(event)


## A house on the first free spot near the player.
func _place_a_house() -> Building:
	var tile: Vector2i = _main._state.player.tile()
	for offset in range(4, 40):
		var house: Building = _main._state.world.place_building(
			BuildingTypes.KATE, tile + Vector2i(offset, offset)
		)
		if house != null:
			return house
	return null


## The hammer in hand in taking-down mode, aimed at a house that is free to go.
func _aim_the_hammer_at_a_house() -> Building:
	var house := _place_a_house()
	var inventory: Inventory = _main._state.player.inventory
	for slot in Inventory.HOTBAR_SIZE:
		if inventory.item_in(slot) == ItemTypes.RUSTY_IRON_HAMMER:
			inventory.select(slot)
	_main._builder.resume()
	_main._builder.toggle_taking_down()
	_main._build_mode.start_options.ghost = house.origin
	return house


func _hold_use_for_a_second() -> void:
	Input.action_press(&"use_click")
	await wait_seconds(BuildMode.TAKE_DOWN_SECONDS + 0.5)


func test_a_press_that_began_on_the_world_takes_the_house_down() -> void:
	var house := _aim_the_hammer_at_a_house()
	_press_key(KEY_B)
	var press := InputEventAction.new()
	press.action = &"use_click"
	press.pressed = true
	_main._unhandled_input(press)
	await _hold_use_for_a_second()
	assert_null(_main._state.world.building_at(house.origin))


func test_a_press_held_on_the_bag_takes_nothing_down() -> void:
	var house := _aim_the_hammer_at_a_house()
	_press_key(KEY_B)
	await _hold_use_for_a_second()
	assert_not_null(_main._state.world.building_at(house.origin))


func test_a_door_or_a_sleep_closes_the_docked_windows() -> void:
	_press_key(KEY_B)
	_press_key(KEY_C)
	_main._fade_through(func() -> void: pass)
	assert_false(_main._bag_screen.is_open())
	assert_false(_main._character_screen.is_open())
	await wait_until(func() -> bool: return not _main._is_in_transition, SETTLE_SECONDS)
