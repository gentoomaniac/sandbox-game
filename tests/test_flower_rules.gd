extends GutTest
## FlowerRules: the data file, and where the meadow flowers grow by habitat and drift.

var _rules := FlowerRules.default_rules()


func test_the_data_file_is_valid() -> void:
	assert_true(_rules.is_valid(), "problems: %s" % [_rules.problems()])


func test_missing_keys_and_unknown_species_are_reported() -> void:
	var values := DataFile.read_sections(FlowerRules.DEFAULT_PATH)
	values["drifts"].erase("core")
	values["wetland"].erase("chance")
	assert_true(FlowerRules.new(values).problems().has("[drifts] no core"))
	assert_true(FlowerRules.new(values).problems().has("[wetland] no chance"))
	values = DataFile.read_sections(FlowerRules.DEFAULT_PATH)
	values["grass"]["communities"] = [["daisy", "tulip"]]
	assert_eq(FlowerRules.new(values).problems(), ["[grass] no flower species tulip"])


func test_no_flowers_where_there_is_no_habitat() -> void:
	for roll in [0.0, 0.5, 0.99]:
		assert_eq(_rules.flowers_at("", 1.0, 0.0, roll), [] as Array[StringName])


func test_flowers_gather_in_drifts() -> void:
	var in_drift := 0
	var outside := 0
	for i in 1000:
		var roll := i / 1000.0
		in_drift += int(not _rules.flowers_at("grass", 1.0, 0.0, roll).is_empty())
		outside += int(not _rules.flowers_at("grass", -1.0, 0.0, roll).is_empty())
	assert_gt(in_drift, 600, "most of the thick of a drift flowers")
	assert_between(outside, 1, 100, "a few strays outside")


func test_woods_have_few_flowers_and_meadows_many() -> void:
	var woods := 0
	var meadow := 0
	for i in 1000:
		var roll := i / 1000.0
		woods += int(not _rules.flowers_at("woods", 1.0, 0.0, roll).is_empty())
		meadow += int(not _rules.flowers_at("grass", 1.0, 0.0, roll).is_empty())
	assert_lt(woods * 3, meadow)


func test_every_community_gets_its_share_of_the_mix() -> void:
	var seen := {}
	for i in 100:
		var mix := -0.6 + i * 0.012
		seen[_rules.flowers_at("grass", 1.0, mix, 0.0)] = true
	assert_eq(seen.size(), _rules._values["grass"]["communities"].size())


func test_heather_grows_on_the_dry_geest_grass() -> void:
	var found := false
	for i in 100:
		found = found or _rules.flowers_at("dry_grass", 1.0, -0.6 + i * 0.012, 0.0).has(&"heather")
	assert_true(found)
