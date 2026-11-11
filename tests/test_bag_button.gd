extends GutTest
## The bag button beside the hotbar, and the place the bag opens at (a bit right of the middle).

const WINDOW := Vector2i(640, 360)

var _viewport: SubViewport


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = WINDOW
	add_child_autofree(_viewport)


func _button(hotbar: HotbarHud) -> Button:
	return hotbar.find_children("*", "Button", true, false)[0]


func test_clicking_the_button_asks_for_the_bag() -> void:
	var hotbar := HotbarCase.new_hotbar()
	_viewport.add_child(hotbar)
	watch_signals(hotbar)
	_button(hotbar).pressed.emit()
	assert_signal_emitted(hotbar, "bag_requested")


func test_the_button_sits_beside_the_hotbar_a_little_apart_and_as_high_as_a_slot() -> void:
	var hotbar := HotbarCase.new_hotbar()
	_viewport.add_child(hotbar)
	await wait_process_frames(2)
	var button_rect := _button(hotbar).get_global_rect()
	var row_rect: Rect2 = hotbar._row.get_global_rect()
	assert_eq(button_rect.position.x - row_rect.end.x, float(HotbarHud.BAG_GAP))
	assert_eq(button_rect.size, Vector2(SlotView.SIZE, SlotView.SIZE))
	assert_eq(button_rect.end.y, row_rect.end.y)
	assert_true(hotbar.covers(button_rect.get_center()), "a click on it is not the game's")
	assert_true(Rect2(Vector2.ZERO, Vector2(WINDOW)).encloses(button_rect))


func test_the_button_takes_no_focus_so_space_still_uses_the_held_item() -> void:
	assert_eq(_button(autofree(HotbarCase.new_hotbar())).focus_mode, Control.FOCUS_NONE)


func test_the_bag_opens_right_of_the_middle_on_the_screen_and_again_after_being_closed() -> void:
	var state := GameState.new_game(7)
	var screen := BagScreen.new(autofree(HotbarCase.new_hotbar(state.player.inventory)))
	_viewport.add_child(screen)
	screen.show_player(state.player)
	for time in 2:
		screen.open()
		await wait_process_frames(2)
		var panel: Rect2 = screen._panel.get_global_rect()
		assert_gt(panel.get_center().x, WINDOW.x / 2.0, "right of the middle")
		assert_true(Rect2(Vector2.ZERO, Vector2(WINDOW)).encloses(panel), "on the screen")
		screen.close()
