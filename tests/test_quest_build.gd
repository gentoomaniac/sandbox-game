extends QuestsCase
## A build quest (BuildObjective): speaking to the giver counts the pieces the player put up since
## it was posted near the giver's home, and nothing is taken from the player.

const FENCE := &"wattle_fence"
const RADIUS := 8

var _antje: Npc
var _home: Vector2i


func before_each() -> void:
	super.before_each()
	_antje = _state.npcs.find(ANTJE)
	_home = _state.player.tile() + Vector2i(0, 4)
	_antje.anchor = Vector2(_home)
	for y in range(-2, 3):
		for x in range(-RADIUS - 2, RADIUS + 3):
			_state.world.remove_object(_home + Vector2i(x, y))
	_state.player.inventory = Inventory.new()


func _take_the_wattle_quest(count := 6) -> void:
	var objective := {
		"type": "build", "object": "wattle_fence", "count": count, "near": "home", "radius": RADIUS
	}
	_use_rules(
		{
			"a":
			{
				"objective": objective,
				"short": "Not yet six, neighbour. {have} of {count} stand by the garden.",
				"reward": {"items": {"wax": 2}},
			}
		}
	)
	_state.clock.day = 5
	_quests.post("a", ANTJE)
	QuestTalk.greet_and_say(_state, _antje)
	_antje.chat_history.clear()


## Puts a fence piece down at `offset` from the home, as of `day`.
func _put_up(offset: Vector2i, day: int, type := FENCE) -> WorldObject:
	var piece := WorldObject.new(type, _home + offset)
	piece.state["placed_day"] = day
	_state.world.add_object(piece)
	return piece


func _progress() -> int:
	var entry := _quests.entry_of("a")
	return _quests.rules.objective_of("a").progress(entry_objective(), entry, _quests)


func entry_objective() -> Dictionary:
	return _quests.rules.quest("a")["objective"]


func _fences_standing() -> int:
	var fences := _state.world.edited_objects().filter(
		func(object: WorldObject) -> bool: return object.type == FENCE
	)
	return fences.size()


func _said() -> Array[String]:
	var lines: Array[String] = []
	for line in _antje.chat_history:
		lines.append(line["text"])
	return lines


func test_the_pieces_put_up_since_it_was_posted_near_the_home_count() -> void:
	_take_the_wattle_quest()

	_put_up(Vector2i(1, 0), 5)
	_put_up(Vector2i(2, 0), 6)
	_put_up(Vector2i(RADIUS, 0), 7)

	assert_eq(_progress(), 3)


func test_a_piece_put_up_before_the_quest_was_posted_does_not_count() -> void:
	_take_the_wattle_quest()

	_put_up(Vector2i(1, 0), 4)

	assert_eq(_progress(), 0, "an old fence is no cheat")


func test_a_piece_that_is_not_the_player_s_has_no_day_and_does_not_count() -> void:
	_take_the_wattle_quest()
	_state.world.add_object(WorldObject.new(FENCE, _home + Vector2i(1, 0)))

	assert_eq(_progress(), 0)


func test_a_piece_taken_down_does_not_count() -> void:
	_take_the_wattle_quest()
	var piece := _put_up(Vector2i(1, 0), 5)
	_put_up(Vector2i(2, 0), 5)

	_state.world.remove_object(piece.pos)

	assert_eq(_progress(), 1)


func test_a_piece_too_far_from_the_home_or_of_another_kind_does_not_count() -> void:
	_take_the_wattle_quest()

	_put_up(Vector2i(RADIUS + 1, 0), 5)
	_put_up(Vector2i(1, 1), 5, WorldObjectTypes.STONE_WALL)

	assert_eq(_progress(), 0)


func test_a_house_makes_its_door_the_home() -> void:
	_take_the_wattle_quest(1)
	var house := _build_house_far_from_the_anchor()
	_state.homes.move_in(_antje, house)
	var near_door := house.door_tile() + Vector2i(1, 2)
	var piece := WorldObject.new(FENCE, near_door)
	piece.state["placed_day"] = 5
	_state.world.add_object(piece)

	assert_eq(_progress(), 1)


func _build_house_far_from_the_anchor() -> Building:
	var around := _state.player.tile() + Vector2i(-30, 0)
	for y in range(-12, 13):
		for x in range(-12, 13):
			var house := _state.world.place_building(BuildingTypes.KATE, around + Vector2i(x, y))
			if house != null:
				return house
	fail_test("no room for a building")
	return null


func test_speaking_with_too_few_up_says_the_short_line_and_changes_nothing() -> void:
	_take_the_wattle_quest()
	_put_up(Vector2i(1, 0), 5)

	QuestTalk.greet_and_say(_state, _antje)

	assert_eq(_said(), ["Not yet six, neighbour. 1 of 6 stand by the garden."])
	assert_true(_quests.is_open("a"))


func test_speaking_with_enough_up_finishes_it_and_takes_nothing() -> void:
	_take_the_wattle_quest()
	for x in 6:
		_put_up(Vector2i(x, 0), 5)

	QuestTalk.greet_and_say(_state, _antje)

	assert_true(_quests.is_done("a"))
	assert_eq(_said().size(), 2, "the turn-in lines")
	assert_eq(_fences_standing(), 6)
	assert_eq(_state.player.inventory.count_of(ItemTypes.WAX), 2)


func test_the_objects_quests_ask_for_are_the_ones_the_game_stamps_with_the_day() -> void:
	assert_eq(QuestRules.default_rules().placed_objects(), [FENCE] as Array[StringName])
