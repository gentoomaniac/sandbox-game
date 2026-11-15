extends ResourceCase
## The wild seeds (WildSeeds, data/wild_seeds.cfg, #11): picking a bush by hand sometimes also gives
## the seeds of a crop, by season, and the same bush on the same day always gives the same.

const BERRY_BUSH := WorldObjectTypes.BERRY_BUSH
const STRAWBERRIES := &"strawberries_seeds"
const WINTER_START := 106
const SUMMER_FIRST := 36
const SUMMER_LAST := 70
## The first and the last day of each season of the year.
const SEASON_DAYS := {
	"spring": [1, 35],
	"summer": [36, 70],
	"autumn": [71, 105],
	"winter": [106, 140],
}

var _rules := WildSeeds.default_rules()


func _rules_with(section: String, changes: Dictionary) -> WildSeeds:
	var values := DataFile.read_sections(WildSeeds.DEFAULT_PATH)
	values[section].merge(changes, true)
	return WildSeeds.new(values)


## How often the plant gave the seed, over every day of the season and ten tiles.
func _found_in(plant: StringName, seed_item: StringName, season: String) -> int:
	var count := 0
	for day in range(SEASON_DAYS[season][0], SEASON_DAYS[season][1] + 1):
		for x in 10:
			count += _rules.found(plant, Vector2i(x, 3), day).get(seed_item, 0)
	return count


## A day of high summer, when the bush bears, on which a bush in front of the player does
## (or does not) find the seed.
func _day_of_finding(seed_item: StringName, does_find := true) -> int:
	for day in range(MIDSUMMER, SUMMER_LAST + 1):
		if _rules.found(BERRY_BUSH, _tile, day).has(seed_item) == does_find:
			return day
	fail_test("no summer day for %s" % seed_item)
	return MIDSUMMER


func test_the_data_file_is_clean() -> void:
	assert_eq(_rules.problems(), [] as Array[String])
	assert_true(_rules.is_valid())


func test_each_kind_of_fault_is_reported() -> void:
	var section := "shrub.flax_seeds"
	var bad_plant := WildSeeds.new({"oak.flax_seeds": {"seasons": ["spring"], "chance": 0.1}})
	assert_string_contains(bad_plant.problems()[0], "oak is no plant picked by hand")
	var bad_seed := WildSeeds.new({"shrub.acorn": {"seasons": ["spring"], "chance": 0.1}})
	assert_string_contains(bad_seed.problems()[0], "acorn is the seed of no crop")
	var bad_season := _rules_with(section, {"seasons": ["monsoon"]})
	assert_string_contains(bad_season.problems()[0], "monsoon is no season")
	var no_seasons := _rules_with(section, {"seasons": []})
	assert_string_contains(no_seasons.problems()[0], "seasons is not a list")
	var no_chance := _rules_with(section, {"chance": 0.0})
	assert_string_contains(no_chance.problems()[0], "chance is not a number")
	var badly_named := WildSeeds.new({"shrub": {}})
	assert_string_contains(badly_named.problems()[0], "is not named <plant>.<seed>")


func test_a_seed_is_found_in_its_seasons_and_in_no_other() -> void:
	var values := DataFile.read_sections(WildSeeds.DEFAULT_PATH)
	for section: String in values:
		var plant := StringName(section.split(".")[0])
		var seed_item := StringName(section.split(".")[1])
		var expected := roundi(350 * values[section]["chance"])
		for season: String in SEASON_DAYS:
			var found := _found_in(plant, seed_item, season)
			if values[section]["seasons"].has(season):
				assert_between(
					found, expected / 2, expected * 8 / 5, "%s in %s" % [section, season]
				)
			else:
				assert_eq(found, 0, "%s is not found in %s" % [section, season])


func test_the_same_plant_on_the_same_day_gives_the_same() -> void:
	for day in range(SUMMER_FIRST, SUMMER_LAST + 1):
		var first := _rules.found(BERRY_BUSH, Vector2i(4, 9), day)
		assert_eq(_rules.found(BERRY_BUSH, Vector2i(4, 9), day), first)


func test_a_plant_that_is_not_in_the_file_gives_nothing() -> void:
	for day in range(1, 141):
		assert_eq(_rules.found(WorldObjectTypes.TALL_GRASS, Vector2i(1, 1), day), {})


func test_picking_a_bush_on_a_day_that_finds_seeds_drops_them_with_the_berries() -> void:
	_state.clock.day = _day_of_finding(STRAWBERRIES)
	_place(BERRY_BUSH)
	_hold(ItemTypes.NONE)

	assert_eq(_state.use_facing_tile(), ToolUse.Use.FORAGE)

	assert_eq(_dropped(STRAWBERRIES), 1)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)


func test_picking_a_bush_on_a_day_that_finds_nothing_drops_only_its_own() -> void:
	_state.clock.day = _day_of_finding(STRAWBERRIES, false)
	_place(BERRY_BUSH)
	_hold(ItemTypes.NONE)

	_state.use_facing_tile()

	assert_eq(_dropped(STRAWBERRIES), 0)
	assert_eq(_dropped(ItemTypes.BERRIES), 3)


func test_a_shrub_in_winter_gives_its_fibre_and_no_seeds_however_often_it_is_picked() -> void:
	for day in range(WINTER_START, WINTER_START + 20):
		_state.clock.day = day
		_world.remove_object(_tile)
		_clear_ground()
		_place(WorldObjectTypes.SHRUB)
		_hold(ItemTypes.NONE)
		_state.use_facing_tile()
		assert_eq(_dropped(ItemTypes.FIBRE), 2, "day %d" % day)
		assert_eq(_dropped(&"turnip_seeds"), 0)
		assert_eq(_dropped(&"rye_seeds"), 0)
	assert_eq(WorldObjectTypes.TYPES[WorldObjectTypes.SHRUB]["drops"], {&"fibre": 2})
