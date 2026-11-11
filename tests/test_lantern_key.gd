extends GutTest
## The use key (space) in the game lights the lantern and puts it out, but only while the lantern
## is the selected item (task 177).

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
	_main._saves.wait()
	_main.free()


func _press_use() -> void:
	var event := InputEventAction.new()
	event.action = &"use"
	event.pressed = true
	_main._unhandled_input(event)


func test_space_switches_the_selected_lantern_and_nothing_else() -> void:
	var player: PlayerState = _main._state.player
	player.inventory.slots[7] = {"item": ItemTypes.LANTERN, "count": 1}

	player.inventory.select(1)
	_press_use()
	assert_false(player.is_lantern_lit, "the axe selected")

	player.inventory.select(7)
	_press_use()
	assert_true(player.is_lantern_lit, "lit")
	_press_use()
	assert_false(player.is_lantern_lit, "put out")
