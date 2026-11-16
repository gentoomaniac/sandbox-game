extends GutTest
## The quests tab of the character screen: the rows of the quests the player has taken, the empty
## text, the counts that follow the bag, and the screen opening on the tab.

var _state: GameState
var _screen: CharacterScreen


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers))
	_state.player.inventory = Inventory.new()
	_screen = CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
	add_child_autofree(_screen)
	_screen.show_player(_state.player)
	_screen.show_quests(_state)


func _panel() -> QuestsPanel:
	return _screen.find_children("*", "QuestsPanel", true, false)[0]


func _texts() -> Array:
	return _panel().find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)


func _take_the_fibre_quest() -> void:
	_state.quests.post("fibre_for_beans", "antje")
	QuestTalk.greet_and_say(_state, _state.npcs.find("antje"))
	_panel().refresh()


func test_with_no_quest_taken_the_tab_says_so() -> void:
	assert_eq(_texts(), ["Open quests (0)", "No open quests."])


func test_a_taken_quest_is_a_row_with_who_what_how_far_and_the_days_left() -> void:
	_take_the_fibre_quest()

	assert_eq(
		_texts(),
		[
			"Open quests (1)",
			"Antje Boysen, a farmer's wife",
			"  5 fibre: you carry 0, 8 days left",
		]
	)


func test_a_quest_only_posted_is_not_shown() -> void:
	_state.quests.post("fibre_for_beans", "antje")
	_panel().refresh()

	assert_eq(_texts(), ["Open quests (0)", "No open quests."])


func test_the_counts_follow_the_bag() -> void:
	_take_the_fibre_quest()

	_state.player.inventory.add(ItemTypes.FIBRE, 4)
	_panel().refresh()

	assert_string_contains(_texts()[2], "you carry 4")


func test_the_tab_opens_and_toggles_like_the_others() -> void:
	_screen.toggle_tab(CharacterScreen.Tab.QUESTS)
	assert_eq(_screen.current_tab(), CharacterScreen.Tab.QUESTS)
	assert_true(_panel().visible)
	_screen.toggle_tab(CharacterScreen.Tab.SKILLS)
	assert_false(_panel().visible)
	_screen.toggle_tab(CharacterScreen.Tab.QUESTS)
	_screen.toggle_tab(CharacterScreen.Tab.QUESTS)
	assert_false(_screen.is_open())


func test_the_reward_is_the_tooltip_of_a_row() -> void:
	_take_the_fibre_quest()

	var row := _panel().list.get_child(0).get_child(0)

	assert_eq(
		row.get_meta(TooltipView.TEXT_META), "Reward: 10 turnip seeds and goodwill in the village"
	)


func test_the_first_drawing_of_an_empty_tab_is_the_empty_text() -> void:
	assert_eq(_panel().list.get_child(0).get_child_count(), 1, "one line: no open quests")


func _short_window_with_two_quests() -> QuestsPanel:
	_state.npcs.add(Npc.create_villager("gesche", Vector2.ZERO, _state.npcs.villagers))
	_state.quests.post("fibre_for_beans", "antje")
	QuestTalk.greet_and_say(_state, _state.npcs.find("antje"))
	_state.quests.post("stool_for_the_loom", "gesche")
	QuestTalk.greet_and_say(_state, _state.npcs.find("gesche"))
	var window := SubViewport.new()
	window.size = Vector2i(640, 110)
	add_child_autofree(window)
	_screen.get_parent().remove_child(_screen)
	window.add_child(_screen)
	_screen.show_quests(_state)
	_screen.open_tab(CharacterScreen.Tab.QUESTS)
	return _panel()


func test_in_a_short_window_the_rows_scroll_and_keep_their_place_when_they_change() -> void:
	var panel := _short_window_with_two_quests()
	await wait_process_frames(3)

	assert_true(panel.list.get_v_scroll_bar().visible, "the window is too small for the rows")
	assert_lte(panel.list.get_global_rect().end.y, 110.0, "the list ends inside the window")
	panel.list.scroll_vertical = 10
	_state.player.inventory.add(ItemTypes.FIBRE, 4)
	panel.refresh()
	await wait_process_frames(3)
	assert_eq(panel.list.scroll_vertical, 10, "a change of the rows keeps the place")


func test_showing_the_tab_starts_at_the_top() -> void:
	var panel := _short_window_with_two_quests()
	await wait_process_frames(3)
	panel.list.scroll_vertical = 10

	_screen.open_tab(CharacterScreen.Tab.SKILLS)
	_screen.open_tab(CharacterScreen.Tab.QUESTS)

	assert_eq(panel.list.scroll_vertical, 0)
