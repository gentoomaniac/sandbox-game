extends GutTest
## The neighbours tab of the character screen: the rows (NeighbourRows), what the next level brings,
## the ten marks (FriendshipMarks) and the tab in the window. The points are never shown.

var _state: GameState
var _antje: Npc
var _gesche: Npc
var _friendship := FriendshipRules.default_rules()


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers)
	_gesche = Npc.create_villager("gesche", Vector2.ZERO, _state.npcs.villagers)
	_state.npcs.add(_antje)
	_state.npcs.add(_gesche)


func _screen() -> CharacterScreen:
	var screen := CharacterScreen.new(autofree(HotbarCase.new_hotbar()))
	add_child_autofree(screen)
	screen.show_player(_state.player)
	screen.show_neighbours(_state)
	return screen


func _row_of_level(level: int) -> Dictionary:
	var rows := NeighbourRows.of(_state).filter(
		func(row: Dictionary) -> bool: return row["level"] == level
	)
	return rows[0]


func _texts(screen: CharacterScreen) -> Array:
	var panel: NeighboursPanel = screen.find_children("*", "NeighboursPanel", true, false)[0]
	return panel.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)


func test_a_row_for_each_villager_closest_friend_first() -> void:
	_antje.opinion = _friendship.first_point_of(7)

	var rows := NeighbourRows.of(_state)

	assert_eq(
		rows.map(func(row: Dictionary) -> String: return row["name"]), [_antje.name, _gesche.name]
	)
	assert_eq(rows[0]["level"], 7)
	assert_eq(rows[0]["level_name"], "Friend")
	assert_eq(rows[1]["level_name"], "Stranger")
	assert_eq(rows[0]["look"], _antje.appearance)


func test_villagers_of_a_level_are_by_name() -> void:
	var names := NeighbourRows.of(_state).map(func(row: Dictionary) -> String: return row["name"])

	assert_eq(names, [_antje.name, _gesche.name])


func test_the_next_level_says_what_it_brings() -> void:
	_antje.opinion = _friendship.first_point_of(4)

	assert_eq(
		NeighbourRows.of(_state)[0]["next"],
		"Next: Neighbour. Brings: barters at the market price, says what they want this year."
	)


func test_the_next_level_of_a_mistrusted_villager_and_the_top_with_no_next() -> void:
	_antje.opinion = _friendship.first_point_of(2)
	assert_eq(
		_row_of_level(2)["next"], "Next: Stranger. Brings: trades with you, gives you errands."
	)
	_antje.opinion = _friendship.first_point_of(10)
	assert_eq(NeighbourRows.of(_state)[0]["next"], NeighbourRows.TOP_TEXT)


func test_the_first_level_brings_talk() -> void:
	_antje.opinion = _friendship.first_point_of(1)

	assert_eq(_row_of_level(1)["next"], "Next: Mistrusted. Brings: chats with you.")


func test_the_points_are_never_in_a_row() -> void:
	_antje.opinion = 321

	for row in NeighbourRows.of(_state):
		for value: Variant in row.values():
			assert_false(str(value).contains("321"))


func test_the_marks_are_filled_up_to_the_level_cold_then_warm_then_gilded() -> void:
	assert_eq(FriendshipMarks.look_of(1, 5), FriendshipMarks.Look.COLD)
	assert_eq(FriendshipMarks.look_of(2, 5), FriendshipMarks.Look.COLD)
	assert_eq(FriendshipMarks.look_of(3, 5), FriendshipMarks.Look.WARM)
	assert_eq(FriendshipMarks.look_of(6, 5), FriendshipMarks.Look.EMPTY)
	assert_eq(FriendshipMarks.look_of(10, 10), FriendshipMarks.Look.GILDED)
	assert_eq(FriendshipMarks.look_of(10, 9), FriendshipMarks.Look.EMPTY)


func test_the_marks_are_cells_of_their_picture_in_both_art_sets() -> void:
	for classic in [false, true]:
		var art_set := "the classic art" if classic else "the new art"
		var marks: Texture2D = load(ArtSet.path_in(FriendshipMarks.MARKS_PATH, classic))
		assert_eq(marks.resource_path.contains("/classic/"), classic, "%s has its marks" % art_set)
		assert_eq(
			marks.get_size(),
			Vector2(
				FriendshipMarks.MARK_SIZE.x * FriendshipMarks.Look.size(),
				FriendshipMarks.MARK_SIZE.y
			),
			marks.resource_path
		)


func test_the_tab_lists_the_villagers_with_their_level_names() -> void:
	_antje.opinion = _friendship.first_point_of(6)
	var screen := _screen()

	assert_eq(
		_texts(screen), ["Neighbours (2)", _antje.name, "Good neighbour", _gesche.name, "Stranger"]
	)


func test_the_window_opens_on_the_neighbours_tab_and_the_rows_follow_a_change() -> void:
	var screen := _screen()
	screen.open_tab(CharacterScreen.Tab.NEIGHBOURS)
	assert_eq(screen.current_tab(), CharacterScreen.Tab.NEIGHBOURS)

	_antje.opinion = _friendship.first_point_of(8)
	screen.open_tab(CharacterScreen.Tab.NEIGHBOURS)

	assert_has(_texts(screen), "Trusted friend")
	screen.close()


func test_every_benefit_has_its_words() -> void:
	for benefit in FriendshipRules.BENEFITS:
		assert_ne(_friendship.benefit_text(benefit), "", benefit)
