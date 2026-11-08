extends GutTest
## What the player sees of passing out: the collapse frames over time, and the black screen
## whose message waits for a key or a click.

var _screen: FadeScreen


func before_each() -> void:
	_screen = FadeScreen.new()
	add_child_autofree(_screen)


func _key() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	return key


## Runs every running tween in the tree (here only the screen's fades) for `seconds` at once,
## so no test waits on the clock.
func _advance_fades(seconds: float) -> void:
	for tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func test_the_collapse_kneels_tips_over_lies_and_sleeps_in_that_order() -> void:
	assert_eq(PlayerView.collapse_frame(0.0), 0, "kneeling")
	assert_eq(PlayerView.collapse_frame(0.55), 1, "tipping over")
	assert_eq(PlayerView.collapse_frame(0.8), 2, "lying")
	assert_eq(PlayerView.collapse_frame(PlayerView.COLLAPSE_SECONDS), PlayerView.ASLEEP_FRAME)


func test_the_player_is_asleep_before_the_screen_fades() -> void:
	var asleep_at: float = PlayerView.COLLAPSE_FRAME_STARTS[PlayerView.ASLEEP_FRAME]
	assert_lt(asleep_at, PlayerView.COLLAPSE_SECONDS)


func test_the_message_waits_for_a_key() -> void:
	_screen.show_message("You collapsed.")
	_advance_fades(FadeScreen.TEXT_FADE_SECONDS)
	assert_true(_screen.is_waiting_for_key())
	_advance_fades(1.0)
	assert_true(_screen.is_waiting_for_key(), "still waiting without a key")
	_screen._input(_key())
	assert_false(_screen.is_waiting_for_key())


func test_a_click_goes_on_too() -> void:
	_screen.show_message("You collapsed.")
	_advance_fades(FadeScreen.TEXT_FADE_SECONDS)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_screen._input(click)
	assert_false(_screen.is_waiting_for_key())


func test_a_key_while_the_message_fades_in_does_not_go_on() -> void:
	var done := [false]
	var show := func() -> void:
		await _screen.show_message("You collapsed.")
		done[0] = true
	show.call()
	_screen._input(_key())
	_advance_fades(FadeScreen.TEXT_FADE_SECONDS)
	assert_true(_screen.is_waiting_for_key())
	assert_false(done[0])


func test_a_held_key_repeating_does_not_go_on() -> void:
	_screen.show_message("You collapsed.")
	_advance_fades(FadeScreen.TEXT_FADE_SECONDS)
	var repeat := _key()
	repeat.echo = true
	_screen._input(repeat)
	assert_true(_screen.is_waiting_for_key())


func test_fading_out_turns_the_screen_black_and_fading_in_clears_it() -> void:
	assert_false(_screen.is_black())
	_screen.fade_out()
	_advance_fades(FadeScreen.FADE_SECONDS)
	assert_true(_screen.is_black())
	_screen.fade_in()
	_advance_fades(FadeScreen.FADE_SECONDS)
	assert_false(_screen.is_black())


func test_every_worn_layer_has_collapse_frames() -> void:
	for file in DirAccess.get_files_at("res://assets/character"):
		if file.get_extension() != "png" or file.begins_with(str(Appearance.HELD)):
			continue
		var parts := file.get_basename().split("_", true, 1)
		var layer := {slot = StringName(parts[0]), variant = parts[1]}
		var sheet: Texture2D = load(Appearance.collapse_sheet_path(layer))
		assert_not_null(sheet, file)
		if sheet != null:
			assert_eq(
				sheet.get_width(),
				PlayerView.FRAME_HEIGHT * PlayerView.COLLAPSE_FRAME_STARTS.size(),
				file
			)
