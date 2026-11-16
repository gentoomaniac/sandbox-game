extends GutTest
## What the player is shown when a villager's opinion moves (FriendshipNotes, FriendshipPopups): a
## heart or a cloud, and the line when a level is crossed. Nothing is told for a first look.

var _state: GameState
var _antje: Npc
var _notes: FriendshipNotes
var _friendship := FriendshipRules.default_rules()
var _moves: Array = []
var _lines: Array[String] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	_antje = Npc.create_villager("antje", Vector2(2.5, 2.5), _state.npcs.villagers)
	_state.npcs.add(_antje)
	_notes = FriendshipNotes.new(_state.npcs)
	_moves = []
	_lines = []
	_notes.moved.connect(func(npc: Npc, is_gain: bool) -> void: _moves.append([npc, is_gain]))
	_notes.level_crossed.connect(func(_npc: Npc, text: String) -> void: _lines.append(text))
	_notes.check()


func test_a_first_look_tells_nothing_and_neither_does_no_change() -> void:
	_notes.check()

	assert_true(_moves.is_empty())
	assert_true(_lines.is_empty())


func test_a_rise_within_a_level_is_a_heart_and_a_fall_a_cloud() -> void:
	_antje.opinion += 5
	_notes.check()
	_antje.opinion -= 10
	_notes.check()

	assert_eq(_moves, [[_antje, true], [_antje, false]])
	assert_true(_lines.is_empty(), "the level is the same")


func test_crossing_into_another_level_has_a_line_up_or_down() -> void:
	_antje.opinion = _friendship.first_point_of(6) + 2
	_notes.check()
	_antje.opinion = _friendship.first_point_of(5)
	_notes.check()

	assert_eq(
		_lines,
		(
			[
				"Antje now thinks of you as a good neighbour.",
				"Antje now thinks of you as a neighbour.",
			]
			as Array[String]
		)
	)


func test_the_line_has_an_an_before_a_vowel() -> void:
	assert_eq(FriendshipNotes.line_for(_antje, 4), "Antje now thinks of you as an acquaintance.")
	assert_eq(FriendshipNotes.line_for(_antje, 10), "Antje now thinks of you as a heart's friend.")


func test_a_villager_who_comes_later_tells_nothing_the_first_time() -> void:
	var newcomer := Npc.create_villager("gesche", Vector2(3.5, 3.5), _state.npcs.villagers)
	newcomer.opinion = 500
	_state.npcs.add(newcomer)

	_notes.check()

	assert_true(_moves.is_empty())


func test_a_pop_up_comes_over_the_head_and_goes_away() -> void:
	var popups := FriendshipPopups.new(_state, _notes)
	add_child_autofree(popups)

	_antje.opinion += 20
	_notes.check()

	assert_eq(popups.get_child_count(), 1)
	assert_eq(popups.get_child(0).position.x, _antje.position.x * TerrainTileset.TILE_SIZE)
	var heart := popups.get_child(0) as Sprite2D
	assert_eq(heart.texture.resource_path, FriendshipPopups.HEART_PATH)
	await wait_seconds(FriendshipPopups.POP_SECONDS + 0.3)
	assert_eq(popups.get_child_count(), 0)


func test_a_fall_brings_the_cloud() -> void:
	var popups := FriendshipPopups.new(_state, _notes)
	add_child_autofree(popups)

	_antje.opinion -= 20
	_notes.check()

	var cloud := popups.get_child(0) as Sprite2D
	assert_eq(cloud.texture.resource_path, FriendshipPopups.CLOUD_PATH)
	assert_eq(cloud.hframes, FriendshipPopups.FRAMES)


func test_a_villager_indoors_has_no_pop_up() -> void:
	var popups := FriendshipPopups.new(_state, _notes)
	add_child_autofree(popups)
	_antje.inside = Building.new(BuildingTypes.KATE, Vector2i.ZERO)

	_antje.opinion += 20
	_notes.check()

	assert_eq(popups.get_child_count(), 0)
	assert_eq(_moves.size(), 1, "the move is told all the same")
