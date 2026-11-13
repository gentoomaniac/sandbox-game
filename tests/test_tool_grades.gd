extends EnergyCase
## Every tool comes in five grades, rusty iron to sharp steel (task 207, data/tools.cfg): their
## items, what they are called, how they are given and how a grade plays.

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


func test_a_rusty_iron_tool_is_what_the_tools_were() -> void:
	var type: Dictionary = ItemTypes.TYPES[&"rusty_iron_axe"]
	assert_eq([type["level"], type["power"], type["energy_factor"]], [1, 1, 1.0])


func test_a_better_grade_is_never_worse() -> void:
	var rules := ToolGradeRules.default_rules()
	var before := rules.grade(rules.grade_ids()[0])
	for grade_id in rules.grade_ids().slice(1):
		var values := rules.grade(grade_id)
		assert_gte(values["level"], before["level"], grade_id)
		assert_gte(values["power"], before["power"], grade_id)
		assert_lte(values["energy_factor"], before["energy_factor"], grade_id)
		before = values


func test_a_better_axe_needs_fewer_hits() -> void:
	var hits: Array[int] = []
	for grade in GRADE_IDS.size():
		hits.append(ceili(5.0 / ItemTypes.tool_power(ItemTypes.tool_item(ItemTypes.AXE, grade))))
	assert_eq(hits, [5, 3, 2, 2, 2])
	var oak := _place(WorldObjectTypes.OAK)
	_hit(&"iron_axe", 2)
	assert_same(_world.object_at(_tile), oak, "an oak stands after 2 iron hits")
	_hit(&"iron_axe", 1)
	assert_eq(_world.object_at(_tile).type, WorldObjectTypes.STUMP)


func test_iron_breaks_the_boulders_and_fells_the_pines_rusty_iron_can_not() -> void:
	var boulder := _place(WorldObjectTypes.BOULDER)
	assert_eq(_hit(&"rusty_iron_pickaxe", 1), ToolUse.Use.NEEDS_BETTER_TOOL)
	assert_eq(_hit(&"iron_pickaxe", 1), ToolUse.Use.HIT)
	assert_same(_world.object_at(_tile), boulder)
	assert_eq(_hit(&"iron_pickaxe", 2), ToolUse.Use.HIT)
	assert_null(_world.object_at(_tile), "a boulder of 6 hp takes 3 hits of 2")
	_place(WorldObjectTypes.PINE)
	assert_eq(_hit(&"rusty_iron_axe", 1), ToolUse.Use.NEEDS_BETTER_TOOL)
	assert_eq(_hit(&"iron_axe", 1), ToolUse.Use.HIT)


func test_a_better_tool_tires_less() -> void:
	var rules := ToolGradeRules.default_rules()
	var costs: Array[float] = []
	for grade in GRADE_IDS.size():
		_state.player.energy = 100.0
		_hold(ItemTypes.tool_item(ItemTypes.HOE, grade))
		assert_eq(_state.use_facing_tile(), ToolUse.Use.TILL)
		costs.append(100.0 - _state.player.energy)
		_world.set_terrain(_tile, Tile.Terrain.GRASS)
	for grade in GRADE_IDS.size():
		var factor: float = rules.grade(rules.grade_ids()[grade])["energy_factor"]
		assert_almost_eq(costs[grade], RULES["cost"]["till"] * factor, 0.001)
	assert_lt(costs[4], costs[0])


func test_what_is_not_a_tool_costs_the_usual() -> void:
	assert_eq(ItemTypes.energy_factor(ItemTypes.TURNIP_SEEDS), 1.0)
	assert_eq(ItemTypes.energy_factor(ItemTypes.NONE), 1.0)


func test_a_tool_is_named_by_its_kind_for_what_it_needs() -> void:
	assert_eq(ItemTypes.tool_name(ItemTypes.tool_item(ItemTypes.WATERING_CAN, 3)), "watering can")
	assert_eq(ItemTypes.tool_name(ItemTypes.RUSTY_IRON_PICKAXE), "pickaxe")


func test_a_grade_missing_a_key_is_reported() -> void:
	var file := ConfigFile.new()
	for key in ToolGradeRules.KEYS:
		file.set_value("rusty_iron", key, "x")
		file.set_value("iron", key, "x")
	file.erase_section_key("iron", "power")
	file.save(RULES_FILE)

	var rules := ToolGradeRules.from_file(RULES_FILE)

	assert_eq(rules.problems(), ["[iron] no power"] as Array[String])
	assert_false(rules.is_valid())
	assert_push_error_count(1)


func test_a_file_without_grades_is_reported() -> void:
	var rules := ToolGradeRules.new({})
	assert_eq(rules.problems(), ["no grades"] as Array[String])
