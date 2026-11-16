extends ResourceCase
## The notice board (issue #12): an object of the catalogue that is solid, that the village puts on
## its square, and that the player may also put up anywhere outdoors with the item (the console's
## `give notice_board`, no recipe) and take down with the axe for the item again.


func test_the_board_is_in_the_catalogue_and_has_an_item_that_places_it() -> void:
	assert_has(WorldObjectTypes.TYPES, WorldObjectTypes.NOTICE_BOARD)
	assert_eq(CatalogCheck.problems(ItemTypes.TYPES, WorldObjectTypes.TYPES), [] as Array[String])
	assert_eq(WorldObjectTypes.build_problems, [] as Array[String])
	assert_eq(ItemTypes.placed_object(ItemTypes.NOTICE_BOARD), WorldObjectTypes.NOTICE_BOARD)
	assert_eq(ItemTypes.item_placing(WorldObjectTypes.NOTICE_BOARD), ItemTypes.NOTICE_BOARD)


func test_it_has_no_recipe() -> void:
	var rules := RecipeRules.default_rules()
	for recipe in rules.recipe_ids():
		assert_ne(rules.result(recipe), ItemTypes.NOTICE_BOARD, recipe)


func test_the_tile_of_the_board_is_solid() -> void:
	_make_room()
	_world.add_object(WorldObject.new(WorldObjectTypes.NOTICE_BOARD, _tile))
	assert_false(_world.is_walkable(_tile))
	assert_true(_world.is_walkable(_tile + Vector2i.LEFT))


func test_the_console_gives_it_and_using_it_sets_it_up_in_any_world() -> void:
	var console := Console.new(_state)
	console.run("give notice_board")
	assert_eq(_count(ItemTypes.NOTICE_BOARD), 1)
	_hold(ItemTypes.NOTICE_BOARD)

	assert_eq(_state.use_facing_tile(), ToolUse.Use.PLACE)

	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.NOTICE_BOARD)
	assert_eq(_count(ItemTypes.NOTICE_BOARD), 0)
	assert_false(_world.is_walkable(_tile))


func test_the_axe_takes_a_placed_board_down_and_it_drops_the_item() -> void:
	_place(WorldObjectTypes.NOTICE_BOARD)

	var use := _hit(ItemTypes.RUSTY_IRON_AXE, 3)

	assert_eq(use, ToolUse.Use.HIT)
	assert_null(_world.object_at(_tile))
	assert_eq(_dropped(ItemTypes.NOTICE_BOARD), 1)


func test_taking_the_board_down_loses_no_quest() -> void:
	_state.npcs.add(Npc.create_villager("antje", Vector2.ZERO, _state.npcs.villagers))
	_state.quests.post("fibre_for_beans", "antje")
	_place(WorldObjectTypes.NOTICE_BOARD)

	_hit(ItemTypes.RUSTY_IRON_AXE, 3)

	assert_true(_state.quests.is_open("fibre_for_beans"))


func test_a_new_village_has_its_board_on_the_square() -> void:
	var state := GameFactory.new_game(1, true)

	var boards := state.world.edited_objects().filter(
		func(object: WorldObject) -> bool: return object.type == WorldObjectTypes.NOTICE_BOARD
	)

	assert_eq(boards.size(), 1)
	assert_true(state.world.village.square.has_point(boards[0].pos))
