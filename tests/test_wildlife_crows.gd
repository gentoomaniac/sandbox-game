extends GutTest
## When and where crows are about (rules in data/wildlife.cfg, what they do to the crops in
## test_crop_raids.gd).

const SPRING := 15
const SUMMER := 45
const AUTUMN := 75
const WINTER := 105
const NOON := 12 * 60
const MIDNIGHT := 0

var _rules := WildlifeRules.default_rules()


func _count(day: int, minute: int, weather := WeatherSample.new()) -> int:
	return _rules.target_count(WildlifeRules.CROWS, day, minute, weather)


func test_the_data_file_holds_every_key_of_the_crows() -> void:
	assert_true(_rules.is_valid(), "missing: %s" % [_rules.problems()])


func test_crows_are_about_by_day_in_every_season_and_most_in_autumn_and_winter() -> void:
	for day in [SPRING, SUMMER, AUTUMN, WINTER]:
		assert_gt(_count(day, NOON), 0, "day %d" % day)
	assert_gt(
		_rules.activity(WildlifeRules.CROWS, AUTUMN, NOON, WeatherSample.new()),
		_rules.activity(WildlifeRules.CROWS, SUMMER, NOON, WeatherSample.new())
	)
	assert_gt(
		_rules.activity(WildlifeRules.CROWS, WINTER, NOON, WeatherSample.new()),
		_rules.activity(WildlifeRules.CROWS, SPRING, NOON, WeatherSample.new())
	)


func test_no_crows_at_night() -> void:
	assert_eq(_count(AUTUMN, MIDNIGHT), 0)


func test_no_crows_in_heavy_rain() -> void:
	var rain := WeatherSample.new()
	rain.rain = 0.9
	assert_eq(_count(AUTUMN, NOON, rain), 0)


func test_crows_live_on_meadows_and_fields_without_farmland_near() -> void:
	for terrain in [Tile.Terrain.GRASS, Tile.Terrain.FLOODPLAIN, Tile.Terrain.SOIL]:
		assert_true(_rules.is_habitat(WildlifeRules.CROWS, terrain, 0, false), str(terrain))
	assert_false(_rules.is_habitat(WildlifeRules.CROWS, Tile.Terrain.SEA, 0, false))


func test_the_crows_look_up_and_then_fly_off_as_the_player_comes_near() -> void:
	assert_eq(_rules.reaction(WildlifeRules.CROWS, 8.0), WildlifeRules.Reaction.ALERT)
	assert_eq(_rules.reaction(WildlifeRules.CROWS, 4.0), WildlifeRules.Reaction.FLEE)
	assert_eq(_rules.reaction(WildlifeRules.CROWS, 20.0), WildlifeRules.Reaction.NONE)
