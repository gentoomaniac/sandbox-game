extends ClickCase
## The rows of the quests and neighbours tabs carry their tooltip: the mouse over any part of a
## row (a label, the portrait, the marks) is over the row, which is the control that has it.

var _screen: CharacterScreen


func before_each() -> void:
	_make_window()
	var state := GameFactory.new_game(7)
	state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, state.npcs.villagers))
	state.quests.post("fibre_for_beans", "antje")
	QuestTalk.greet_and_say(state, state.npcs.find("antje"))
	_screen = CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
	_window.add_child(_screen)
	_screen.show_player(state.player)
	_screen.show_quests(state)
	_screen.show_neighbours(state)


func _assert_parts_hover_the_row(
	tab: CharacterScreen.Tab, panel_class: String, kinds: Array
) -> void:
	_screen.open_tab(tab)
	await wait_process_frames(3)
	var panel: Control = _screen.find_children("*", panel_class, true, false)[0]
	for kind: String in kinds:
		for part: Control in panel.find_children("*", kind, true, false):
			var row := part.get_parent()
			while row != panel and not row.has_meta(TooltipView.TEXT_META):
				row = row.get_parent()
			if row == panel:
				continue
			_move_mouse(part.get_global_rect().get_center())
			assert_eq(_window.gui_get_hovered_control(), row, "%s of %s" % [kind, panel_class])


func test_any_part_of_a_quest_row_shows_the_reward() -> void:
	await _assert_parts_hover_the_row(CharacterScreen.Tab.QUESTS, "QuestsPanel", ["Label"])


func test_any_part_of_a_neighbour_row_shows_what_the_next_level_brings() -> void:
	await _assert_parts_hover_the_row(
		CharacterScreen.Tab.NEIGHBOURS, "NeighboursPanel", ["Label", "ColorRect", "FriendshipMarks"]
	)
