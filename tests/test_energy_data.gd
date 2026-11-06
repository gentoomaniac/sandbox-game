extends EnergyCase
## Saving energy and health, and the data file the rules come from.

const DATA_DIR := "user://test_energy"
const DATA_FILE := DATA_DIR + "/energy.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


# --- Saving ---


func test_energy_health_and_the_debuff_survive_a_save_round_trip() -> void:
	_state.player.energy = 12.5
	_state.player.health = 33.0
	_state.player.is_debuffed = true
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	assert_eq(restored.player.energy, 12.5)
	assert_eq(restored.player.health, 33.0)
	assert_true(restored.player.is_debuffed)


# --- The data file ---


func test_the_data_file_holds_every_rule_with_the_first_values() -> void:
	var rules := EnergyRules.from_file(EnergyRules.DEFAULT_PATH)
	assert_eq(rules.cost_of(&"till"), 2.0)
	assert_eq(rules.cost_of(&"hit"), 2.0)
	assert_eq(rules.cost_of(&"water"), 2.0)
	assert_eq(rules.cost_of(&"plant"), 0.5)
	assert_eq(rules.cost_of(&"pick"), 0.5)
	assert_true(rules.is_valid())
	assert_eq(rules.weight_factor(40.0), 1.0)
	assert_almost_eq(rules.weight_factor(50.0), 1.1, 0.0001)
	assert_eq(rules.sleep_fill(WorldObjectTypes.SLEEPING_BAG), 100.0)
	assert_eq(rules.sleep_fill(WorldObjectTypes.SMALL_BED), 100.0)
	assert_eq(rules.sleep_fill(WorldObjectTypes.SLEEPING_MAT), 80.0)
	assert_eq(rules.sleep_fill(WorldObjectTypes.BOX_BED), 100.0)
	assert_eq(rules.sleep_fill(&"ground"), 50.0)
	assert_eq(rules.food_restore(ItemTypes.BERRIES), 3.0)
	assert_eq(rules.food_restore(ItemTypes.TURNIP), 8.0)
	assert_eq(rules.walk_factor(10.0), 0.75)
	assert_eq(rules.walk_factor(4.9), 0.5)
	assert_eq(rules.walk_factor(10.1), 1.0)
	assert_eq(rules.debuff_walk_factor(), 0.5)
	assert_eq(rules.debuff_energy_max(), 50.0)
	assert_eq(rules.debuff_health(), 25.0)
	assert_eq(rules.warning_level(), 20.0)
	assert_eq(rules.tired_level(), 20.0)
	assert_eq(rules.exhausted_level(), 10.0)
	assert_eq(rules.late_warning_minutes(), [0, 30] as Array[int])


func test_every_missing_required_rule_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string("[cost]\ntill=3.0\n")
	file.close()
	var rules := EnergyRules.from_file(DATA_FILE)
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[cost] no hit"))
	assert_true(missing.has("[weight] no step_kg"))
	assert_false(missing.has("[cost] no till"))
	assert_push_error_count(missing.size())


func test_a_bed_or_food_without_a_rule_gives_nothing() -> void:
	var rules := EnergyRules.new(RULES)
	assert_eq(rules.sleep_fill(&"hammock"), 0.0)
	assert_false(rules.is_food(&"stone"))
	assert_eq(rules.food_restore(&"stone"), 0.0)


func test_a_missing_file_is_reported() -> void:
	var rules := EnergyRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)
