extends SaveUpgradeCase
## Version 32 had one grade of each tool, with the ids of the tools (hoe, axe, ...): task 207 makes
## them the rusty iron ones (rusty_iron_hoe, ...), and an old save keeps them.

const TOOLS := ["hoe", "axe", "pickaxe", "watering_can", "scythe", "shovel", "hammer"]


func test_a_version_32_save_keeps_its_tools_as_rusty_iron_ones() -> void:
	var game := _version_32_game()
	assert_string_contains(JSON.stringify(game), '"item":"hoe"')
	_write_save(32, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_not_null(restored)
	var inventory := restored.player.inventory
	for tool_kind: String in TOOLS:
		assert_eq(inventory.count_of(StringName("rusty_iron_" + tool_kind)), 1, tool_kind)
	assert_eq(inventory.count_of(ItemTypes.TURNIP_SEEDS), 15, "other items are as they were")


func test_the_tool_in_the_hand_of_a_version_32_save_is_shown_in_the_hand() -> void:
	var game := _version_32_game()
	var layers: Array = game["player"]["appearance"]["layers"]
	assert_true(layers.any(func(layer: Dictionary) -> bool: return layer["variant"] == "hoe"))
	_write_save(32, game)

	var restored := SaveFile.read(SAVE_PATH)

	assert_true(
		restored.player.appearance.layers.any(
			func(layer: Dictionary) -> bool: return layer.variant == "rusty_iron_hoe"
		)
	)


func test_a_tool_in_a_chest_or_on_the_ground_is_renamed_too() -> void:
	var game := _version_32_game()
	game["world"]["objects"] = [{"stack": {"item": "axe"}}, ["pickaxe", {"item": "shovel"}]]
	SaveFile._upgrade_from_version_32(game)

	assert_eq(game["world"]["objects"][0]["stack"]["item"], "rusty_iron_axe")
	assert_eq(game["world"]["objects"][1], ["pickaxe", {"item": "rusty_iron_shovel"}])


func test_a_version_33_save_has_no_old_tool_ids_and_loads() -> void:
	var state := GameState.new_game(7)
	assert_true(SaveFile.write(state, SAVE_PATH))

	var restored := SaveFile.read(SAVE_PATH)

	assert_eq(restored.player.inventory.count_of(ItemTypes.RUSTY_IRON_HOE), 1)
	assert_eq(restored.player.inventory.count_of(&"hoe"), 0)


## A current game as the last save version wrote it: the tools with their old ids.
func _version_32_game() -> Dictionary:
	var text := JSON.stringify(GameState.new_game(7).to_dict())
	return JSON.parse_string(text.replace("rusty_iron_", ""))
