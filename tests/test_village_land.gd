extends GutTest
## The village's land in play: its houses are not taken down, the console says where it is, and
## build mode shows its edge and warns on it (design/world/wehlsbuell.md, section 9).

var _state: GameState


func before_each() -> void:
	_state = GameState.new_game(1, true)


func _village_house() -> Building:
	return _state.world.building_at(_state.world.village.building_origins[0])


func test_a_house_of_the_village_is_not_taken_down() -> void:
	var house := _village_house()
	assert_eq(_state.why_not_take_down(house), "That is the village's.")
	assert_false(_state.take_down_building(house))
	assert_true(_state.world.buildings().has(house))


func test_a_house_of_the_player_is_taken_down() -> void:
	var tile := _state.player.tile() + Vector2i(0, -6)
	var shack := _state.world.place_building(BuildingTypes.SHACK, tile)
	assert_not_null(shack)
	assert_eq(_state.why_not_take_down(shack), "")
	assert_true(_state.take_down_building(shack))


func test_the_console_says_where_the_village_is_and_what_it_holds() -> void:
	var village := _state.world.village
	var lines := Console.new(_state).run("village")
	assert_string_contains(lines[0], "Wehlsbüll. It lies about")
	assert_string_contains(lines[0], "tiles west")
	assert_string_contains(lines[1], "%d by %d tiles" % [village.area.size.x, village.area.size.y])
	assert_string_contains(lines[1], "%d buildings" % village.building_origins.size())
	assert_string_contains(lines[1], "tp %d %d" % [village.meeting_spot.x, village.meeting_spot.y])


func test_on_the_land_the_console_says_so() -> void:
	_state.teleport_to(_state.world.village.meeting_spot)
	assert_string_contains(Console.new(_state).run("village")[0], "You are on its land")


func test_a_world_with_no_village_says_so() -> void:
	assert_eq(
		Console.new(GameState.new_game(7)).run("village"),
		["This world has no village"] as Array[String]
	)


func test_the_hint_is_given_where_the_ghost_stands_on_the_land_and_not_elsewhere() -> void:
	var builder := Builder.new(_state)
	builder.select_hammer()
	builder.choose(BuildingTypes.SHACK)
	var mode := BuildMode.new()
	mode.world = _state.world
	mode.builder = builder
	add_child_autofree(mode)
	var messages: Array[String] = []
	mode.message_changed.connect(messages.append)
	_state.cheats.is_cost_off = true

	mode._origin = _state.world.village.area.position + Vector2i(1, 1)
	mode._blockers = {}
	mode._show_message()
	mode._origin = _state.player.tile()
	mode._show_message()

	assert_eq(messages[0], "Wehlsbüll's land: the villagers will not like it.")
	assert_ne(messages[1], messages[0])
