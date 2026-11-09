extends GutTest
## The arrows pick in the build menu while it is up, and the player walks with WASD (see
## BuildMode `walk_direction`); otherwise both walk.


func after_each() -> void:
	for key in [KEY_LEFT, KEY_UP, KEY_A, KEY_W]:
		_press(key, false)


func _press(code: Key, is_pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = is_pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _first_key(action: StringName, index: int) -> Key:
	return (InputMap.action_get_events(action)[index] as InputEventKey).physical_keycode


func test_the_arrows_pick_buildings_and_styles_next_to_q_and_e() -> void:
	assert_eq(_first_key(&"build_previous", 1), KEY_LEFT)
	assert_eq(_first_key(&"build_next", 1), KEY_RIGHT)
	assert_eq(_first_key(&"build_style_up", 0), KEY_UP)
	assert_eq(_first_key(&"build_style_down", 0), KEY_DOWN)
	for action in [&"build_style_up", &"build_style_down"]:
		assert_ne(GameSettings.action_label(action), str(action).capitalize())


func test_while_the_menu_is_up_the_arrows_do_not_walk_but_wasd_does() -> void:
	_press(KEY_LEFT)
	assert_eq(BuildMode.walk_direction(true), Vector2.ZERO)
	assert_eq(BuildMode.walk_direction(false), Vector2.LEFT)
	_press(KEY_W)
	assert_eq(BuildMode.walk_direction(true), Vector2.UP)


func test_walking_diagonally_with_wasd_is_as_fast_as_straight() -> void:
	_press(KEY_A)
	_press(KEY_W)
	assert_almost_eq(BuildMode.walk_direction(true).length(), 1.0, 0.001)
