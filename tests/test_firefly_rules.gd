extends GutTest
## When fireflies come: the season, the hours after sunset and the weather (see WildlifeRules).

const SUMMER := 45
const SPRING := 15
const AUTUMN := 75
const WINTER := 105
const NOON := 12 * 60

var _rules := WildlifeRules.default_rules()
var _sun := Sun.new()


## Warm and calm: fireflies keep away from cold, and a new sample is at 0 degrees.
func _mild() -> WeatherSample:
	var weather := WeatherSample.new()
	weather.temperature = 16.0
	return weather


func _dawn(day: int) -> int:
	return roundi(_sun.sunrise(day))


func test_fireflies_fly_in_summer_only() -> void:
	var firefly := WildlifeRules.FIREFLY
	var evening := _sunset(SUMMER) + 60
	assert_gt(_rules.target_count(firefly, SUMMER, evening, _mild()), 0)
	for day in [SPRING, AUTUMN, WINTER]:
		assert_eq(_rules.target_count(firefly, day, _sunset(day) + 60, _mild()), 0, "day %d" % day)


func test_fireflies_come_at_dusk_and_stay_for_the_first_hours_of_the_night() -> void:
	var firefly := WildlifeRules.FIREFLY
	var sunset := _sunset(SUMMER)
	assert_eq(_rules.target_count(firefly, SUMMER, NOON, _mild()), 0, "noon")
	assert_eq(_rules.target_count(firefly, SUMMER, sunset - 150, _mild()), 0, "afternoon")
	assert_gt(_rules.target_count(firefly, SUMMER, sunset - 30, _mild()), 0, "dusk begins")
	assert_gt(_rules.target_count(firefly, SUMMER, sunset + 120, _mild()), 0, "two hours after")
	assert_eq(_rules.target_count(firefly, SUMMER, sunset + 300, _mild()), 0, "late night")
	assert_eq(_rules.target_count(firefly, SUMMER, _dawn(SUMMER), _mild()), 0, "dawn")


func test_the_evening_of_fireflies_goes_on_past_midnight() -> void:
	# Sunset is at 21:00 on day 45, so 3:30 hours later is half past midnight.
	var after_midnight := _sunset(SUMMER) + 210 - GameClock.MINUTES_PER_DAY
	assert_gt(after_midnight, 0)
	assert_gt(_rules.target_count(WildlifeRules.FIREFLY, SUMMER, after_midnight, _mild()), 0)


func test_fireflies_stay_in_for_rain_wind_cold_fog_and_storms() -> void:
	var firefly := WildlifeRules.FIREFLY
	var evening := _sunset(SUMMER) + 60
	var rain := _mild()
	rain.rain = 0.2
	var wind := _mild()
	wind.wind = 0.5
	var cold := _mild()
	cold.temperature = 5.0
	var fog := _mild()
	fog.fog = 0.8
	var storm := _mild()
	storm.storm = 0.2
	for weather in [rain, wind, cold, fog, storm]:
		assert_eq(
			_rules.target_count(firefly, SUMMER, evening, weather), 0, weather.conditions_text()
		)
	var breeze := _mild()
	breeze.wind = 0.1
	assert_gt(_rules.target_count(firefly, SUMMER, evening, breeze), 0, "a mild breeze")


func _sunset(day: int) -> int:
	return roundi(_sun.sunset(day))
