extends GutTest
## The notification HUD: a few lines at the top left that fade, a keyed line replaced in place.

const KEY := &"save"

var _hud: NotificationHud


func before_each() -> void:
	_hud = NotificationHud.new()
	_hud.line_seconds = 0.05
	_hud.error_seconds = 0.2
	add_child_autofree(_hud)


func test_a_posted_line_is_shown() -> void:
	_hud.post(&"", "Saved")
	assert_eq(_hud.texts(), PackedStringArray(["Saved"]))


func test_lines_come_one_below_the_other_in_the_order_posted() -> void:
	_hud.post(&"", "first")
	_hud.post(&"", "second")
	assert_eq(_hud.texts(), PackedStringArray(["first", "second"]))


func test_a_line_with_the_same_key_replaces_the_old_one_in_place() -> void:
	_hud.hold(KEY, "Saving...")
	_hud.post(KEY, "Saved")
	assert_eq(_hud.texts(), PackedStringArray(["Saved"]))


func test_a_line_fades_away() -> void:
	_hud.post(KEY, "Saved")
	await wait_seconds(NotificationHud.FADE_SECONDS + 0.3)
	assert_eq(_hud.texts().size(), 0)


func test_a_held_line_stays_until_it_is_removed() -> void:
	_hud.hold(KEY, "Saving...")
	await wait_seconds(NotificationHud.FADE_SECONDS + 0.3)
	assert_eq(_hud.texts(), PackedStringArray(["Saving..."]))
	_hud.remove(KEY)
	assert_eq(_hud.texts().size(), 0)


func test_a_replaced_line_does_not_fade_with_the_timer_of_the_old_one() -> void:
	_hud.post(KEY, "one")
	await wait_seconds(0.04)
	_hud.hold(KEY, "two")
	await wait_seconds(NotificationHud.FADE_SECONDS + 0.3)
	assert_eq(_hud.texts(), PackedStringArray(["two"]))


func test_the_oldest_line_goes_when_there_are_too_many() -> void:
	for number in NotificationHud.MAX_LINES + 1:
		_hud.hold(&"", str(number))
	assert_eq(_hud.texts().size(), NotificationHud.MAX_LINES)
	assert_eq(_hud.texts()[0], "1")


func test_an_error_has_a_red_plate_and_stays_longer() -> void:
	_hud.post(&"error", "Can't save", NotificationHud.Tone.ERROR)
	_hud.post(&"news", "Saved")
	var plates := {}
	for line: Label in _hud._lines.get_children():
		plates[line.text] = line.get_theme_stylebox("normal").bg_color
	assert_eq(plates["Can't save"], UiColors.ERROR_PLATE)
	assert_eq(plates["Saved"], UiColors.BACKDROP)
	await wait_seconds(NotificationHud.FADE_SECONDS + 0.1)
	assert_eq(_hud.texts(), PackedStringArray(["Can't save"]))


func test_it_keeps_running_while_the_game_is_paused() -> void:
	assert_eq(_hud.process_mode, Node.PROCESS_MODE_ALWAYS)
