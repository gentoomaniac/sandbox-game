extends ResourceCase
## E on a station opens the crafting menu of its recipes: which objects E opens, the menu's title
## and rows, the locked rows with the skill they need, and the note on what a craft taught.

const RECIPES := {
	"stew":
	{
		"result": "turnip",
		"count": 1,
		"materials": {"berries": 2},
		"station": "hearth",
		"skill": "cooking",
	},
	"feast":
	{
		"result": "potato",
		"count": 1,
		"materials": {"berries": 2},
		"station": "hearth",
		"skill": "cooking",
		"level": 25,
	},
	"box": {"result": "chest", "count": 1, "materials": {"logs": 1}},
}

var _screen: CraftingScreen


func before_each() -> void:
	super.before_each()
	_screen = CraftingScreen.new()
	add_child_autofree(_screen)
	_screen.show_crafting(Crafting.new(_state, RecipeRules.new(RECIPES)), _state.player.inventory)
	_state.player.inventory.add(ItemTypes.BERRIES, 10)


func _rows() -> Array:
	return _screen.find_children("*", "RecipeRow", true, false)


func _row(recipe_id: StringName) -> RecipeRow:
	for row: RecipeRow in _rows():
		if row.recipe_id == recipe_id:
			return row
	return null


func _visible_texts() -> Array:
	var labels := _screen.find_children("*", "Label", true, false).filter(
		func(label: Label) -> bool: return label.is_visible_in_tree()
	)
	return labels.map(func(label: Label) -> String: return label.text)


func _open_at_the_hearth() -> void:
	_screen.open(_place(WorldObjectTypes.FIREPLACE))


# --- What E opens ---


func test_e_opens_a_station_on_the_targeted_tile_before_sleeping() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	_world.add_object(
		WorldObject.new(WorldObjectTypes.SLEEPING_BAG, _state.player.tile() + Vector2i.LEFT)
	)
	assert_eq(Interaction.object_to_open(_state, _tile), fire)


func test_e_opens_the_nearest_station_in_reach_when_there_is_no_bed() -> void:
	var fire := _place(WorldObjectTypes.FIREPLACE)
	assert_eq(Interaction.object_to_open(_state, _tile + Vector2i.RIGHT * 3), fire)


func test_an_object_that_is_no_station_is_not_opened() -> void:
	_place(WorldObjectTypes.STONE)
	assert_null(Interaction.object_to_open(_state, _tile))


# --- The menu ---


func test_the_menu_of_a_station_lists_its_recipes_under_its_name() -> void:
	_open_at_the_hearth()
	assert_eq(
		_rows().map(func(row: RecipeRow) -> StringName: return row.recipe_id), [&"stew", &"feast"]
	)
	assert_has(_visible_texts(), "Hearth")
	assert_has(_visible_texts(), "Cooking 0.0")


func test_the_menu_made_by_hand_lists_the_recipes_without_a_station() -> void:
	_open_at_the_hearth()
	_screen.close()
	_screen.toggle()
	assert_eq(_rows().map(func(row: RecipeRow) -> StringName: return row.recipe_id), [&"box"])
	assert_has(_visible_texts(), CraftingScreen.HAND_TITLE)


func test_a_locked_recipe_is_greyed_and_says_the_skill_it_needs() -> void:
	_open_at_the_hearth()
	var row := _row(&"feast")
	assert_true(row.disabled)
	assert_has(_visible_texts(), "Cooking 25")
	assert_string_contains(row.get_meta(TooltipView.TEXT_META), "Needs Cooking 25 (you have 0.0)")
	_state.player.skills.set_points(&"cooking", 25.0)
	assert_false(row.disabled, "it unlocks as the skill grows")


func test_a_recipe_that_teaches_says_how_much() -> void:
	_open_at_the_hearth()
	assert_string_contains(_row(&"stew").get_meta(TooltipView.TEXT_META), "Teaches Cooking +2.0")


func test_a_craft_notes_what_it_taught_and_the_skill_line_follows() -> void:
	_open_at_the_hearth()
	_row(&"stew").pressed.emit()
	assert_has(_visible_texts(), "+2.0 Cooking")
	assert_has(_visible_texts(), "Cooking 2.0")


func test_a_craft_at_the_skill_cap_says_to_let_a_skill_fade() -> void:
	_state.player.skills.set_points(&"woodworking", 100.0)
	_state.player.skills.set_points(&"masonry", 100.0)
	_open_at_the_hearth()
	_row(&"stew").pressed.emit()
	assert_has(_visible_texts(), CraftingScreen.AT_CAP_NOTE % "Cooking")


func test_a_station_with_no_recipes_says_so() -> void:
	var screen := CraftingScreen.new()
	add_child_autofree(screen)
	var hand_only := {"box": RECIPES["box"]}
	screen.show_crafting(Crafting.new(_state, RecipeRules.new(hand_only)), _state.player.inventory)
	screen.open(_place(WorldObjectTypes.FIREPLACE))
	var texts := screen.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text
	)
	assert_has(texts, CraftingScreen.NOTHING_NOTE)
