extends GutTest
## The rain of a year at the North Frisian coast: showers and fronts of hours with dry hours
## between, autumn and winter the wettest and spring the driest (task 221).

const SEEDS: Array[int] = [1, 12345, 987654]
## Hours: a spell of rain or snow lasts hours, rarely more than about a day.
const LONGEST_SPELL_HOURS := 30
const WET_SHARE_RANGE := Vector2(0.08, 0.20)
## Days of a season on which the winter snow lies at noon, and the least days with cloud shadows.
const LEAST_SNOW_DAYS := 10
const LEAST_SHADOW_DAYS := 3

var _years: Dictionary[int, WeatherYear] = {}


func before_all() -> void:
	for world_seed in SEEDS:
		_years[world_seed] = WeatherYear.new(world_seed)


func test_no_spell_of_rain_lasts_more_than_about_a_day() -> void:
	for world_seed in SEEDS:
		assert_lte(_years[world_seed].longest_spell(), LONGEST_SPELL_HOURS, "seed %d" % world_seed)


func test_a_share_of_the_hours_is_wet() -> void:
	for world_seed in SEEDS:
		var share := _years[world_seed].wet_share()
		assert_between(share, WET_SHARE_RANGE.x, WET_SHARE_RANGE.y, "seed %d" % world_seed)


func test_autumn_is_the_wettest_season_then_winter_summer_and_spring() -> void:
	for world_seed in SEEDS:
		var year := _years[world_seed]
		var autumn := year.wet_hours_in(GameClock.Season.AUTUMN)
		var winter := year.wet_hours_in(GameClock.Season.WINTER)
		var summer := year.wet_hours_in(GameClock.Season.SUMMER)
		var spring := year.wet_hours_in(GameClock.Season.SPRING)
		var seasons := "seed %d: %s" % [world_seed, [spring, summer, autumn, winter]]
		assert_gt(autumn, winter, seasons)
		assert_gt(winter, summer, seasons)
		assert_gt(summer, spring, seasons)


func test_there_are_dry_hours_between_the_wet_ones() -> void:
	for world_seed in SEEDS:
		var year := _years[world_seed]
		var changes := 0
		for hour in range(1, WeatherYear.HOURS_PER_YEAR):
			changes += int(year.wet[hour] != year.wet[hour - 1])
		# Each spell has two edges: spells are many, so they are short.
		assert_gt(changes / 2, 40, "seed %d" % world_seed)


func test_snow_still_lies_on_many_winter_days() -> void:
	for world_seed in SEEDS:
		var days := _years[world_seed].snow_days_in(GameClock.Season.WINTER)
		assert_gte(days, LEAST_SNOW_DAYS, "seed %d" % world_seed)


func test_cloud_shadows_fall_on_some_days_of_every_season() -> void:
	for world_seed in SEEDS:
		for season in 4:
			var days := _years[world_seed].days_partly_clouded_in(season)
			assert_gte(days, LEAST_SHADOW_DAYS, "seed %d, season %d" % [world_seed, season])
