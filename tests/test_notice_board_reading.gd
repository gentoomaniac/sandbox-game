extends ResourceCase
## Reading the notice board (E on it): the lines of the quests posted and not taken, whom to see,
## the board giving no quest, the "!" over it while there is news, and the notices a world with a
## board and one without get.

var _board: WorldObject


func before_each() -> void:
	super.before_each()
	_state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers))
	_state.npcs.add(Npc.create_villager("gesche", Vector2.ZERO, _state.npcs.villagers))


func _put_up_the_board() -> void:
	_board = _place_beside(WorldObjectTypes.NOTICE_BOARD)


func _take(id: String, giver: String) -> void:
	_state.quests.post(id, giver)
	QuestTalk.greet_and_say(_state, _state.npcs.find(giver))


func test_e_on_the_board_reads_it() -> void:
	_put_up_the_board()

	var choice := Interaction.choice_at(_state, _board.pos)

	assert_eq(choice.kind, Interaction.Kind.READ_BOARD)
	assert_eq(choice.subject, _board)
	assert_eq(ActionHint.e_text(_state, _board.pos), "Read the notice board")


func test_a_villager_in_front_comes_before_the_board() -> void:
	_put_up_the_board()
	var antje := _state.npcs.find("antje")
	antje.position = Vector2(_board.pos) + Vector2(0.5, 0.5)

	assert_eq(Interaction.choice_at(_state, _board.pos).kind, Interaction.Kind.CHAT)


func test_the_board_says_the_rough_line_of_each_posted_quest_and_whom_to_see() -> void:
	_state.quests.post("fibre_for_beans", "antje")
	_state.quests.post("stool_for_the_loom", "gesche")

	assert_eq(
		BoardNotices.lines(_state),
		(
			[
				"Fibre is wanted for the bean rows. Go and see Antje Boysen, a farmer's wife.",
				"A stool is wanted at a loom. Go and see Gesche Hansen, %s." % _trade_of("gesche"),
			]
			as Array[String]
		)
	)


func test_reading_the_board_gives_no_quest() -> void:
	_state.quests.post("fibre_for_beans", "antje")

	BoardNotices.lines(_state)

	assert_false(_state.quests.entry_of("fibre_for_beans")["is_taken"])
	assert_true(QuestRows.of(_state).is_empty())


func test_a_taken_quest_is_not_on_the_board() -> void:
	_take("fibre_for_beans", "antje")
	_state.quests.post("stool_for_the_loom", "gesche")

	var lines := BoardNotices.lines(_state)

	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "stool")


func test_an_empty_board_says_so() -> void:
	assert_eq(BoardNotices.lines(_state), [BoardNotices.NOTHING_NEW_TEXT] as Array[String])
	assert_false(BoardNotices.has_news(_state))


func test_the_window_shows_the_lines() -> void:
	_state.quests.post("fibre_for_beans", "antje")
	var screen := NoticeBoardScreen.new()
	add_child_autofree(screen)

	screen.open_board(_state)

	assert_true(screen.is_open())
	var texts := screen.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)
	assert_has(texts, "Notice board")
	assert_has(
		texts, "Fibre is wanted for the bean rows. Go and see Antje Boysen, a farmer's wife."
	)


func test_the_mark_hangs_over_a_board_while_there_is_news_and_goes_when_it_is_taken() -> void:
	_put_up_the_board()
	var marks := QuestMarkView.new(_state)
	add_child_autofree(marks)
	marks._process(1.0)
	assert_eq(marks.get_child_count(), 0, "nothing posted")

	_state.quests.post("fibre_for_beans", "antje")
	marks._process(1.0)
	assert_eq(marks.get_child_count(), 1)

	QuestTalk.greet_and_say(_state, _state.npcs.find("antje"))
	marks._process(1.0)
	await wait_frames(2)
	assert_eq(
		(
			marks
			. get_children()
			. filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
			. size()
		),
		0
	)


func test_a_world_with_no_board_has_no_mark_and_still_gets_its_quests_as_a_message() -> void:
	var marks := QuestMarkView.new(_state)
	add_child_autofree(marks)
	var notices: Array[String] = []
	_state.quests.noticed.connect(func(text: String) -> void: notices.append(text))

	_state.quests.post("fibre_for_beans", "antje")
	marks._process(1.0)

	assert_eq(marks.get_child_count(), 0)
	assert_eq(notices, ["Antje Boysen has something for you."] as Array[String])


func test_with_a_board_a_posted_quest_is_a_notice_on_it() -> void:
	_put_up_the_board()
	var notices: Array[String] = []
	_state.quests.noticed.connect(func(text: String) -> void: notices.append(text))

	_state.quests.post("fibre_for_beans", "antje")

	assert_eq(notices, ["A new notice on the board."] as Array[String])


func test_in_a_village_the_notice_names_it() -> void:
	var state := GameState.new_game(1, true)
	var notices: Array[String] = []
	state.quests.noticed.connect(func(text: String) -> void: notices.append(text))

	state.quests.post("stool_for_the_loom")

	assert_eq(
		notices,
		["A new notice on the board in %s." % state.world.village.village_name] as Array[String]
	)


func _trade_of(villager: String) -> String:
	return _state.npcs.find(villager).trade
