extends ResourceCase
## Every tool comes in five grades, rusty iron to sharp steel (task 207, data/tools.cfg): their
## items, what they are called, how they are given.

const GRADE_NAMES := ["Rusty iron", "Iron", "Brittle steel", "Steel", "Sharp steel"]
const GRADE_IDS := ["rusty_iron", "iron", "brittle_steel", "steel", "sharp_steel"]
const TOOL_NAMES := {
	ItemTypes.HOE: "hoe",
	ItemTypes.AXE: "axe",
	ItemTypes.PICKAXE: "pickaxe",
	ItemTypes.WATERING_CAN: "watering can",
	ItemTypes.SCYTHE: "scythe",
	ItemTypes.SHOVEL: "shovel",
	ItemTypes.HAMMER: "hammer",
}
const RULES_FILE := "user://test_tool_grades.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(RULES_FILE)


func test_every_tool_is_an_item_in_five_grades() -> void:
	for tool_kind: StringName in TOOL_NAMES:
		for grade in GRADE_NAMES.size():
			var id := StringName("%s_%s" % [GRADE_IDS[grade], tool_kind])
			var type: Dictionary = ItemTypes.TYPES[id]
			assert_eq(type["name"], "%s %s" % [GRADE_NAMES[grade], TOOL_NAMES[tool_kind]])
			assert_eq(type["tool"], tool_kind)
			assert_eq(type["stack_limit"], 1)
			assert_eq(type["held_sheet"], id)


func test_the_ids_are_the_grade_and_the_tool() -> void:
	assert_eq(ItemTypes.tool_item(ItemTypes.HOE, 0), &"rusty_iron_hoe")
	assert_eq(ItemTypes.tool_item(ItemTypes.WATERING_CAN, 2), &"brittle_steel_watering_can")
	assert_eq(ItemTypes.tool_item(ItemTypes.AXE, 4), &"sharp_steel_axe")
	assert_eq(ItemTypes.RUSTY_IRON_PICKAXE, &"rusty_iron_pickaxe")


func test_the_old_tool_ids_are_no_items() -> void:
	for tool_kind: StringName in TOOL_NAMES:
		assert_false(ItemTypes.TYPES.has(tool_kind), tool_kind)


func test_the_tools_of_a_new_game_are_rusty_iron() -> void:
	for tool_kind: StringName in TOOL_NAMES:
		assert_eq(_count(ItemTypes.tool_item(tool_kind, 0)), 1, tool_kind)
		assert_eq(_count(ItemTypes.tool_item(tool_kind, 1)), 0, tool_kind)


func test_every_grade_has_its_icons_and_its_sheet_in_the_hand() -> void:
	for tool_kind: StringName in TOOL_NAMES:
		for grade in GRADE_NAMES.size():
			var id := ItemTypes.tool_item(tool_kind, grade)
			assert_true(ResourceLoader.exists(ItemTypes.icon_path(id)), id)
			assert_true(ResourceLoader.exists(ItemTypes.ground_icon_path(id)), id)
			assert_true(ResourceLoader.exists(Appearance.SHEET_PATH % ["held", id]), id)


func test_the_console_gives_each_grade() -> void:
	var console := Console.new(_state)
	for grade in GRADE_NAMES.size():
		var id := ItemTypes.tool_item(ItemTypes.SHOVEL, grade)
		var expected := "Gave 1 %s shovel" % GRADE_NAMES[grade]
		assert_eq(console.run("give %s" % id), [expected] as Array[String])
	assert_eq(_count(&"sharp_steel_shovel"), 1)


func test_the_console_knows_no_hoe_any_more() -> void:
	assert_eq(Console.new(_state).run("give hoe")[0], "Unknown item: hoe")


func test_every_grade_plays_as_the_tools_did() -> void:
	for tool_kind: StringName in TOOL_NAMES:
		for grade in GRADE_NAMES.size():
			var type: Dictionary = ItemTypes.TYPES[ItemTypes.tool_item(tool_kind, grade)]
			assert_eq(type["level"], 1)
			assert_eq(ItemTypes.tool_power(ItemTypes.tool_item(tool_kind, grade)), 1)


func test_a_tool_is_named_by_its_kind_for_what_it_needs() -> void:
	assert_eq(ItemTypes.tool_name(ItemTypes.tool_item(ItemTypes.WATERING_CAN, 3)), "watering can")
	assert_eq(ItemTypes.tool_name(ItemTypes.RUSTY_IRON_PICKAXE), "pickaxe")


func test_a_grade_without_a_name_is_reported() -> void:
	var file := ConfigFile.new()
	file.set_value("rusty_iron", "name", "Rusty iron")
	file.set_value("iron", "price", 3)
	file.save(RULES_FILE)

	var rules := ToolGradeRules.from_file(RULES_FILE)

	assert_eq(rules.problems(), ["[iron] no name"] as Array[String])
	assert_false(rules.is_valid())
	assert_push_error_count(1)


func test_a_file_without_grades_is_reported() -> void:
	var rules := ToolGradeRules.new({})
	assert_eq(rules.problems(), ["no grades"] as Array[String])
