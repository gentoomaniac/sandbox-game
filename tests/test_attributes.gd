extends GutTest
## The attributes file and its validation, the levels and bonuses, and the numbers derived from
## them.

const DATA_DIR := "user://test_attributes"
const DATA_FILE := DATA_DIR + "/attributes.cfg"
const RULES := {
	"levels": {"min": 2, "max": 50},
	"effects": {"energy_per_stamina": 7.0, "health_per_hp": 5.0, "free_kg_per_strength": 3.0},
	"strength": {"name": "Strength", "description": "Carry.", "base": 4},
	"agility": {"name": "Agility", "description": "Nothing.", "base": 5},
	"stamina": {"name": "Stamina", "description": "Energy.", "base": 6},
	"hp": {"name": "HP", "description": "Health.", "base": 8},
}


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _attributes() -> Attributes:
	return Attributes.new(AttributeRules.new(RULES))


# --- The data ---


func test_the_attributes_file_is_valid_and_gives_todays_numbers_at_the_base_levels() -> void:
	var rules := AttributeRules.from_file(AttributeRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	var ids: Array[StringName] = [
		Attributes.STRENGTH, Attributes.AGILITY, Attributes.STAMINA, Attributes.HP
	]
	assert_eq(rules.attribute_ids(), ids)
	assert_eq(rules.attribute_name(Attributes.HP), "HP")
	var attributes := Attributes.new(rules)
	assert_eq(attributes.max_energy(), 100.0)
	assert_eq(attributes.max_health(), 100.0)
	assert_eq(attributes.carry_capacity(), 40.0)


func test_every_missing_or_wrong_key_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string('[levels]\nmin=0\n\n[strength]\nname="Strength"\nbase=1.5\n')
	file.close()
	var rules := AttributeRules.from_file(DATA_FILE)
	var expected: Array[String] = [
		"[levels] min must be a number above 0",
		"[levels] no max",
		"[effects] no energy_per_stamina",
		"[effects] no health_per_hp",
		"[effects] no free_kg_per_strength",
		"[strength] no description",
		"[strength] base must be a whole number",
	]
	assert_eq(rules.problems(), expected)
	assert_push_error_count(7)


func test_a_file_with_no_attributes_is_invalid() -> void:
	var rules := AttributeRules.new({"levels": RULES["levels"], "effects": RULES["effects"]})
	assert_eq(rules.problems(), ["no attributes"] as Array[String])


func test_a_missing_file_is_reported() -> void:
	var rules := AttributeRules.from_file(DATA_DIR + "/none.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)


# --- Levels and bonuses ---


func test_a_new_character_has_the_base_levels() -> void:
	var attributes := _attributes()
	assert_eq(attributes.level(Attributes.STRENGTH), 4)
	assert_eq(attributes.level(Attributes.HP), 8)


func test_a_level_stays_within_the_lowest_and_highest() -> void:
	var attributes := _attributes()
	attributes.set_level(Attributes.STRENGTH, 0)
	assert_eq(attributes.level(Attributes.STRENGTH), 2)
	attributes.set_level(Attributes.STRENGTH, 999)
	assert_eq(attributes.level(Attributes.STRENGTH), 50)


func test_bonuses_add_to_the_value_and_not_to_the_level() -> void:
	var attributes := _attributes()
	attributes.add_bonus(&"stew", Attributes.STRENGTH, 2)
	attributes.add_bonus(&"belt", Attributes.STRENGTH, 1)
	assert_eq(attributes.level(Attributes.STRENGTH), 4)
	assert_eq(attributes.bonus(Attributes.STRENGTH), 3)
	assert_eq(attributes.value(Attributes.STRENGTH), 7)


func test_a_source_replaces_its_own_bonus_and_removes_all_of_it() -> void:
	var attributes := _attributes()
	attributes.add_bonus(&"stew", Attributes.STRENGTH, 2)
	attributes.add_bonus(&"stew", Attributes.STRENGTH, 5)
	assert_eq(attributes.bonus(Attributes.STRENGTH), 5)
	attributes.add_bonus(&"stew", Attributes.HP, 1)
	attributes.remove_bonus(&"stew")
	assert_eq(attributes.bonus(Attributes.STRENGTH), 0)
	assert_eq(attributes.bonus(Attributes.HP), 0)


func test_changes_are_announced() -> void:
	var attributes := _attributes()
	watch_signals(attributes)
	attributes.set_level(Attributes.HP, 9)
	attributes.add_bonus(&"stew", Attributes.HP, 1)
	attributes.remove_bonus(&"stew")
	assert_signal_emit_count(attributes, "changed", 3)


# --- The derived numbers ---


func test_the_derived_numbers_follow_the_value_of_their_attribute() -> void:
	var attributes := _attributes()
	assert_eq(attributes.max_energy(), 42.0)
	assert_eq(attributes.max_health(), 40.0)
	assert_eq(attributes.carry_capacity(), 12.0)
	attributes.set_level(Attributes.STAMINA, 10)
	attributes.add_bonus(&"stew", Attributes.STRENGTH, 2)
	assert_eq(attributes.max_energy(), 70.0)
	assert_eq(attributes.carry_capacity(), 18.0)


func test_a_whole_number_shows_without_decimals() -> void:
	assert_eq(Attributes.number_text(100.0), "100")
	assert_eq(Attributes.number_text(42.5), "42.5")


func test_agility_changes_none_of_them() -> void:
	var attributes := _attributes()
	attributes.set_level(Attributes.AGILITY, 30)
	assert_eq(attributes.max_energy(), 42.0)
	assert_eq(attributes.max_health(), 40.0)
	assert_eq(attributes.carry_capacity(), 12.0)
