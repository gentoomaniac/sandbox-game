extends GutTest
## The recipes file and its validation, and crafting: it takes the materials and gives the item,
## and is refused when materials or room are short.

const DATA_DIR := "user://test_recipes"
const DATA_FILE := DATA_DIR + "/recipes.cfg"

var _state: GameState
var _crafting: Crafting


func before_each() -> void:
	_state = GameState.new_game(7)
	_crafting = Crafting.new(_state)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _write(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _problems_of(recipe: Dictionary) -> Array[String]:
	return RecipeRules.new({"thing": recipe}).problems()


func _inventory() -> Inventory:
	return _state.player.inventory


## Fills every slot with a tool, so nothing else fits.
func _fill_inventory() -> void:
	for slot in Inventory.SLOT_COUNT:
		_inventory().slots[slot] = {"item": ItemTypes.HOE, "count": 1}


# --- The data ---


func test_the_recipes_file_is_valid_and_its_first_recipe_is_the_chest_for_five_logs() -> void:
	var rules := RecipeRules.from_file(RecipeRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	var first := rules.recipe_ids()[0]
	assert_eq(first, &"chest")
	assert_eq(rules.result(first), ItemTypes.CHEST)
	assert_eq(rules.count(first), 1)
	assert_eq(rules.materials(first), {ItemTypes.LOGS: 5})
	assert_eq(RecipeRules.default_rules().recipe_ids(), rules.recipe_ids())


func test_every_missing_required_key_is_reported() -> void:
	_write('[chest]\nresult="chest"\n')
	var rules := RecipeRules.from_file(DATA_FILE)
	assert_false(rules.is_valid())
	assert_eq(rules.problems(), ["[chest] no count", "[chest] no materials"] as Array[String])
	assert_push_error_count(2)


func test_a_file_with_no_recipes_is_invalid() -> void:
	assert_eq(RecipeRules.new({}).problems(), ["no recipes"] as Array[String])


func test_a_result_that_is_not_an_item_is_reported() -> void:
	var problems := _problems_of({"result": "unobtainium", "count": 1, "materials": {"logs": 1}})
	assert_eq(problems, ["[thing] result is not an item: unobtainium"] as Array[String])


func test_a_count_below_one_or_not_whole_is_reported() -> void:
	for count: Variant in [0, 1.5, "two"]:
		var problems := _problems_of({"result": "chest", "count": count, "materials": {"logs": 1}})
		assert_eq(problems.size(), 1, "count %s" % count)


func test_bad_materials_are_reported() -> void:
	var recipe := {"result": "chest", "count": 1}
	assert_eq(_problems_of(recipe.merged({"materials": {}})).size(), 1, "none")
	assert_eq(_problems_of(recipe.merged({"materials": 5})).size(), 1, "not a dictionary")
	assert_eq(_problems_of(recipe.merged({"materials": {"dust": 1}})).size(), 1, "not an item")
	assert_eq(_problems_of(recipe.merged({"materials": {"logs": 0}})).size(), 1, "none of it")
	assert_eq(_problems_of(recipe.merged({"materials": {"logs": 2, "stone": 1}})).size(), 0)


# --- Crafting ---


func test_crafting_takes_the_materials_and_gives_the_item() -> void:
	_inventory().add(ItemTypes.LOGS, 7)
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.CRAFTED)
	assert_eq(_inventory().count_of(ItemTypes.LOGS), 2)
	assert_eq(_inventory().count_of(ItemTypes.CHEST), 1)


func test_crafting_with_too_few_materials_is_refused_and_changes_nothing() -> void:
	_inventory().add(ItemTypes.LOGS, 4)
	assert_eq(_crafting.shortfalls(&"chest"), {ItemTypes.LOGS: 1})
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.MISSING_MATERIALS)
	assert_eq(_inventory().count_of(ItemTypes.LOGS), 4)
	assert_eq(_inventory().count_of(ItemTypes.CHEST), 0)


func test_nothing_is_short_when_there_are_enough() -> void:
	_inventory().add(ItemTypes.LOGS, 5)
	assert_eq(_crafting.shortfalls(&"chest"), {})


func test_the_materials_can_be_spread_over_stacks() -> void:
	_inventory().add(ItemTypes.LOGS, 99)
	_inventory().add(ItemTypes.LOGS, 3)
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.CRAFTED)
	assert_eq(_inventory().count_of(ItemTypes.LOGS), 97)


func test_a_craft_the_inventory_has_no_room_for_is_refused_and_changes_nothing() -> void:
	_fill_inventory()
	_inventory().slots[3] = {"item": ItemTypes.LOGS, "count": 6}
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.NO_ROOM)
	assert_eq(_inventory().count_of(ItemTypes.LOGS), 6)
	assert_eq(_inventory().count_of(ItemTypes.CHEST), 0)


func test_the_room_the_materials_leave_is_enough() -> void:
	_fill_inventory()
	_inventory().slots[3] = {"item": ItemTypes.LOGS, "count": 5}
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.CRAFTED)
	assert_eq(_inventory().item_in(3), ItemTypes.CHEST)


func test_the_no_cost_cheat_crafts_for_nothing() -> void:
	_state.cheats.is_cost_off = true
	assert_eq(_crafting.shortfalls(&"chest"), {})
	assert_eq(_crafting.craft(&"chest"), Crafting.Result.CRAFTED)
	assert_eq(_inventory().count_of(ItemTypes.CHEST), 1)


# --- The key ---


func test_c_opens_the_crafting_menu_and_no_other_action_uses_it() -> void:
	var keys: Array[Key] = []
	for event in InputMap.action_get_events(&"crafting"):
		keys.append((event as InputEventKey).physical_keycode)
	assert_eq(keys, [KEY_C] as Array[Key])
	for action in GameSettings.actions():
		if action == &"crafting":
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_C, str(action))


func test_the_crafting_action_has_a_description_for_the_controls() -> void:
	assert_true(GameSettings.ACTION_DESCRIPTIONS.has(&"crafting"))
	assert_eq(GameSettings.action_label(&"crafting"), "Crafting")
