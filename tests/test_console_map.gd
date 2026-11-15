extends EnergyCase
## The console's `map` command opens and closes the world map, and a click on the map teleports
## the player as `tp` does.

var _console: Console
var _screen: MapScreen


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)
	_screen = MapScreen.new()
	add_child_autofree(_screen)
	_screen.show_state(_state)
	_screen.teleporter = func(tile: Vector2i) -> Array[String]:
		return _console.run("tp %d %d" % [tile.x, tile.y])
	_console.context.map_toggler = _screen.toggled


func after_each() -> void:
	_screen.close()


## Clicks the middle of the tile on the map and waits for the screen to have a size.
func _click_on(tile: Vector2i) -> void:
	var view := _screen._view
	var point := view.point_of(Vector2(tile) + Vector2(0.5, 0.5))
	for is_pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = point
		view._gui_input(click)


func _press(label: String) -> void:
	for button: Button in _screen._confirm.find_children("*", "Button", true, false):
		if button.text == label:
			button.pressed.emit()


func test_map_opens_the_map_and_map_again_closes_it() -> void:
	assert_eq(_console.run("map"), ["Map opened"] as Array[String])
	assert_true(_screen.is_open())

	assert_eq(_console.run("map"), ["Map closed"] as Array[String])
	assert_false(_screen.is_open())


func test_escape_closes_the_map() -> void:
	_console.run("map")

	_screen.request_close()

	assert_false(_screen.is_open())


func test_without_a_map_the_command_says_so() -> void:
	var bare := Console.new(_state)

	assert_eq(bare.run("map"), [ConsoleHelper.NO_MAP] as Array[String])


func test_map_takes_no_arguments() -> void:
	assert_eq(_console.run("map 1"), ["Usage: map"] as Array[String])
	assert_false(_screen.is_open())


func test_the_map_is_in_the_help() -> void:
	assert_true(
		_console.run("help").any(func(line: String) -> bool: return line.begins_with("map"))
	)


func test_a_click_offers_a_teleport_and_teleporting_takes_the_player_there() -> void:
	_screen.open()
	await get_tree().process_frame
	var tile := _tile_where(true)
	var before := _state.player.tile()
	assert_ne(tile, before)

	_click_on(tile)

	assert_true(_screen._confirm.visible)
	assert_string_contains(_screen._confirm_text.text, "%d, %d" % [tile.x, tile.y])
	assert_eq(_state.player.tile(), before, "nothing happens before the player agrees")
	_press("Teleport")
	assert_eq(_state.player.tile(), tile)
	assert_false(_screen.is_open(), "the map closes after a teleport")


func test_cancel_leaves_the_player_where_they_are() -> void:
	_screen.open()
	await get_tree().process_frame
	var before := _state.player.tile()

	_click_on(_tile_where(true))
	_press("Cancel")

	assert_false(_screen._confirm.visible)
	assert_eq(_state.player.tile(), before)
	assert_true(_screen.is_open())


func test_a_teleport_the_game_refuses_keeps_the_map_open_and_says_why() -> void:
	_screen.open()
	await get_tree().process_frame
	var water := _tile_where(false)
	var before := _state.player.tile()

	_click_on(water)
	_press("Teleport")

	assert_eq(_state.player.tile(), before)
	assert_true(_screen.is_open())
	assert_string_contains(_screen._note.text, "Can't walk")


func test_escape_dismisses_the_offer_before_it_closes_the_map() -> void:
	_screen.open()
	await get_tree().process_frame
	_click_on(_tile_where(true))

	_screen.request_close()
	assert_true(_screen.is_open())
	assert_false(_screen._confirm.visible)

	_screen.request_close()
	assert_false(_screen.is_open())
