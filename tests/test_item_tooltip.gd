extends GutTest
## The text of item tooltips, built from the item and energy data, and the descriptions of
## items and actions that feed it.


func test_an_empty_slot_has_no_tooltip() -> void:
	assert_eq(ItemTooltip.text_for(ItemTypes.NONE), "")


func test_food_shows_its_energy() -> void:
	var lines := ItemTooltip.text_for(&"turnip").split("\n")
	assert_eq(lines[0], "Turnip")
	assert_eq(lines[1], "Food")
	assert_eq(lines[2], ItemTypes.TYPES[&"turnip"]["description"])
	assert_has(lines, "+8 energy")
	assert_eq(lines[-1], "0.4 kg each")


func test_a_tool_shows_its_level() -> void:
	var lines := ItemTooltip.text_for(ItemTypes.HOE).split("\n")
	assert_eq(lines[1], "Tool, level 1")
	assert_eq(lines[-1], "2 kg each")


func test_crop_seeds_show_the_crop_and_tilled_soil() -> void:
	var lines := ItemTooltip.text_for(ItemTypes.TURNIP_SEEDS).split("\n")
	assert_eq(lines[1], "Seeds")
	assert_has(lines, "Grows into: Turnip")
	assert_has(lines, "Plant on: tilled soil")


func test_tree_seeds_show_the_tree_and_grass() -> void:
	var lines := ItemTooltip.text_for(ItemTypes.ACORN).split("\n")
	assert_eq(lines[1], "Seeds")
	assert_has(lines, "Grows into: Oak tree")
	assert_has(lines, "Plant on: grass")


func test_a_plain_resource_shows_name_kind_description_and_weight() -> void:
	var lines := ItemTooltip.text_for(ItemTypes.LOGS).split("\n")
	assert_eq(lines.size(), 4)
	assert_eq(lines[1], "Resource")
	assert_eq(lines[3], "1 kg each")


func test_equipment_shows_its_slot() -> void:
	var lines := ItemTooltip.text_for(ItemTypes.STRAW_HAT).split("\n")
	assert_eq(lines[1], "Equipment")
	assert_has(lines, "Worn on: Head")
	assert_eq(lines[-1], "0.3 kg each")


func test_equipment_stats_are_listed_when_an_item_has_them() -> void:
	ItemTypes.TYPES[&"test_cloak"] = {
		"name": "Cloak",
		"description": "Test.",
		"weight": 1.0,
		"stack_limit": 1,
		"equip_slot": Equipment.BACK,
		"stats": {"Warmth": 2},
	}
	assert_has(ItemTooltip.text_for(&"test_cloak").split("\n"), "Warmth +2")
	ItemTypes.TYPES.erase(&"test_cloak")


func test_a_stack_shows_its_weight_each_and_together() -> void:
	assert_eq(ItemTooltip.weight_text(0.3, 1), "0.3 kg each")
	assert_eq(ItemTooltip.weight_text(0.3, 5), "0.3 kg each, 5 = 1.5 kg")
	assert_eq(ItemTooltip.weight_text(0.05, 3), "0.05 kg each, 3 = 0.15 kg")
	assert_eq(ItemTooltip.weight_text(1.5, 99), "1.5 kg each, 99 = 148.5 kg")


func test_the_stack_weight_is_in_the_tooltip_of_a_stack() -> void:
	assert_true(ItemTooltip.text_for(ItemTypes.FIBRE, 4).ends_with("0.1 kg each, 4 = 0.4 kg"))


func test_every_item_has_a_description() -> void:
	for item: StringName in ItemTypes.TYPES:
		assert_true(ItemTypes.TYPES[item].get("description", "") != "", str(item))


func test_every_item_has_a_tooltip() -> void:
	for item: StringName in ItemTypes.TYPES:
		assert_ne(ItemTooltip.text_for(item), "", str(item))


func test_every_action_has_a_description() -> void:
	for action in GameSettings.actions():
		assert_ne(GameSettings.action_description(action), "", str(action))
