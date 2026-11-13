extends CharacterDragCase
## The bag and the character window open side by side: the character window docked at the left,
## the bag at the bottom right above the hotbar, neither dimming nor covering the other.


func before_each() -> void:
	_open_both_screens()
	await wait_process_frames(2)


func test_the_character_window_is_at_the_left_and_the_bag_at_the_bottom_right() -> void:
	var screen := _window.get_visible_rect()
	var character_rect := _character._panel.get_global_rect()
	var bag_rect := _bag._panel.get_global_rect()
	assert_almost_eq(character_rect.position.x, float(Modal.DOCK_MARGIN), 1.0)
	assert_almost_eq(character_rect.get_center().y, screen.get_center().y, 1.0)
	assert_almost_eq(bag_rect.end.x, screen.end.x - Modal.DOCK_MARGIN, 1.0)
	assert_false(character_rect.intersects(bag_rect), "side by side")


func test_the_bag_is_above_the_hotbar() -> void:
	var hotbar_top := _window.get_visible_rect().end.y - HotbarHud.BOTTOM_MARGIN - SlotView.SIZE
	assert_lt(_bag._panel.get_global_rect().end.y, hotbar_top)


func test_the_windows_stay_docked_when_the_character_window_changes_tab() -> void:
	_character.open_tab(CharacterScreen.Tab.SKILLS)
	await wait_process_frames(2)
	assert_almost_eq(_character._panel.get_global_rect().position.x, float(Modal.DOCK_MARGIN), 1.0)


func test_the_game_is_not_dimmed_and_does_not_pause() -> void:
	assert_eq(_bag._backdrop.color.a, 0.0)
	assert_eq(_character._backdrop.color.a, 0.0)
	assert_false(get_tree().paused)


func test_a_window_the_player_moved_stays_where_it_was_put() -> void:
	var grip := _character._panel.get_global_rect().position + Vector2(2, 2)
	_drag(grip, grip + Vector2(100, 0))
	assert_almost_eq(_character._panel.get_global_rect().position.x, 8.0 + 100.0, 2.0)
