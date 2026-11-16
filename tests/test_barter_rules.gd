extends GutTest
## What the villagers barter (BarterRules, data/barter.cfg): the file is clean, the goods are read
## and each kind of fault is reported.


func _rules_with(section: String, changes: Dictionary) -> BarterRules:
	var values := DataFile.read_sections(BarterRules.DEFAULT_PATH)
	values[section].merge(changes, true)
	return BarterRules.new(values)


func test_the_data_file_is_clean() -> void:
	assert_eq(BarterRules.default_rules().problems(), [] as Array[String])
	assert_true(BarterRules.default_rules().is_valid())


func test_the_goods_and_the_cap_are_read() -> void:
	var rules := BarterRules.default_rules()
	assert_eq(rules.cap(), 100)
	assert_true(rules.has("antje"))
	assert_false(rules.has("trienke"), "a shopkeeper has her shop")
	assert_false(rules.has("deal"))
	assert_eq(rules.offers("antje"), [ItemTypes.EGG, ItemTypes.BERRIES] as Array[StringName])
	assert_eq(rules.wants("antje").size(), 3)
	assert_eq(rules.offers("trienke"), [] as Array[StringName])


func test_a_cap_that_is_not_a_whole_number_from_one_is_reported() -> void:
	var problem := ["[deal] cap is not a whole number from 1"] as Array[String]
	assert_eq(_rules_with("deal", {"cap": 0}).problems(), problem)
	assert_eq(_rules_with("deal", {"cap": 2.5}).problems(), problem)


func test_a_section_that_is_no_villager_is_reported() -> void:
	var values := DataFile.read_sections(BarterRules.DEFAULT_PATH)
	values["nobody"] = {"offers": ["egg"], "wants": ["flour"]}
	assert_eq(BarterRules.new(values).problems(), ["[nobody] is no villager"] as Array[String])


func test_a_good_with_no_worth_or_no_item_is_reported() -> void:
	var rules := _rules_with("antje", {"offers": ["egg", "lantern", "gold_bar"]})
	assert_eq(
		rules.problems(),
		(
			[
				"[antje] offers: lantern has no worth in data/prices.cfg",
				"[antje] offers: gold_bar is no item",
			]
			as Array[String]
		)
	)


func test_a_list_that_is_empty_or_missing_is_reported() -> void:
	assert_eq(
		_rules_with("antje", {"wants": []}).problems(),
		["[antje] wants is not a list of goods"] as Array[String]
	)
	var values := DataFile.read_sections(BarterRules.DEFAULT_PATH)
	values["antje"].erase("offers")
	var problems := BarterRules.new(values).problems()
	assert_eq(problems, ["[antje] offers is not a list of goods"] as Array[String])


func test_a_good_both_offered_and_wanted_is_reported() -> void:
	var rules := _rules_with("antje", {"wants": ["flour", "egg"]})
	assert_eq(rules.problems(), ["[antje] egg is both offered and wanted"] as Array[String])
