extends GutTest
## The notice board's window: the lines scroll in a window too small for them, from the top.

const SMALL_WINDOW := Vector2i(320, 110)

var _screen: NoticeBoardScreen


func before_each() -> void:
	var state := GameState.new_game(7)
	state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, state.npcs.villagers))
	state.npcs.add(Npc.create_villager("gesche", Vector2.ZERO, state.npcs.villagers))
	state.quests.post("fibre_for_beans", "antje")
	state.quests.post("stool_for_the_loom", "gesche")
	var window := SubViewport.new()
	window.size = SMALL_WINDOW
	add_child_autofree(window)
	_screen = NoticeBoardScreen.new()
	# The test waits for frames, which stand still while the game is paused.
	_screen.pauses_game = false
	window.add_child(_screen)
	_screen.open_board(state)


func _list() -> ScrollingList:
	return _screen.find_children("*", "ScrollingList", true, false)[0]


func test_the_lines_scroll_in_a_small_window() -> void:
	await wait_process_frames(2)

	assert_true(_list().get_v_scroll_bar().visible, "the window is too small for the lines")
	assert_lte(_list().get_global_rect().end.y, float(SMALL_WINDOW.y))


func test_the_board_opens_at_the_top() -> void:
	await wait_process_frames(2)
	_list().scroll_vertical = 20
	_screen.close()

	_screen.open()

	assert_eq(_list().scroll_vertical, 0)
