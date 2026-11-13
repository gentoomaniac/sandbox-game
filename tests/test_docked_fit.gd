extends CharacterDragCase
## The bag and the character window dock side by side only where they fit: in a small window or at
## a large UI scale, the window opened second closes the first.


func before_each() -> void:
	_open_both_screens()
	await wait_process_frames(2)


func test_both_windows_fit_side_by_side_at_the_normal_size() -> void:
	assert_true(_bag.is_open())
	assert_true(_character.is_open())
	assert_false(_character._panel.get_global_rect().intersects(_bag._panel.get_global_rect()))


func test_opening_the_second_window_closes_the_first_when_they_do_not_fit() -> void:
	# The visible size at UI scale 1.75 and 2.0.
	for window_size: Vector2i in [Vector2i(366, 206), Vector2i(320, 180)]:
		_bag.close()
		_character.close()
		_window.size = window_size
		_bag.open()
		_character.open()
		assert_false(_bag.is_open(), "the first closed at %s" % window_size)
		assert_true(_character.is_open())
		_bag.open()
		assert_false(_character.is_open(), "and the other way round at %s" % window_size)
		assert_true(_bag.is_open())


func test_a_window_shrinking_closes_the_window_opened_first_when_they_stop_fitting() -> void:
	_window.size = Vector2i(320, 180)
	await wait_process_frames(2)
	assert_false(_bag.is_open())
	assert_true(_character.is_open())
