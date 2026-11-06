extends GutTest
## The weather data file: its required keys and its first values.

const DATA_DIR := "user://test_weather"
const DATA_FILE := DATA_DIR + "/weather.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func test_the_data_file_holds_every_required_key() -> void:
	var rules := WeatherRules.from_file(WeatherRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), "missing: %s" % [rules.problems()])
	assert_eq(rules.value("sun", "longest_day"), 45.0)
	assert_eq(rules.season_value(GameClock.Season.WINTER, "temperature_mean"), -5.0)


func test_every_missing_key_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string("[sun]\nlongest_day=45.0\n[winter]\ncloudiness=0.1\n")
	file.close()
	var rules := WeatherRules.from_file(DATA_FILE)
	var missing := rules.problems()
	assert_false(rules.is_valid())
	assert_true(missing.has("[sun] no lowest_noon_height"))
	assert_true(missing.has("[winter] no wind_mean"))
	assert_true(missing.has("[summer] no cloudiness"))
	assert_false(missing.has("[sun] no longest_day"))
	assert_push_error_count(missing.size())


func test_a_missing_file_is_reported() -> void:
	var rules := WeatherRules.from_file(DATA_DIR + "/nothing.cfg")
	assert_false(rules.is_valid())
	assert_push_error_count(rules.problems().size() + 1)
