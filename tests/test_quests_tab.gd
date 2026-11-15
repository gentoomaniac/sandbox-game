extends GutTest
## The quests tab of the character screen: the rows of the quests the player has taken, the empty
## text, the counts that follow the bag, and the screen opening on the tab.

var _state: GameState
var _screen: CharacterScreen


func before_each() -> void:
	_state = GameState.new_game(7)
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

	var row := _panel().get_child(1)

	assert_eq(
		row.get_meta(TooltipView.TEXT_META), "Reward: 10 turnip seeds and goodwill in the village"
	)
