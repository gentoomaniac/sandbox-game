class_name WeatherYear
extends RefCounted
## A year of one seed's weather at tile 0,0, sampled hour by hour: how wet it is and in what
## spells (for tests/test_weather_year.gd and `make weather-probe`).

## An hour is wet when rain or snow falls harder than this, as the mean of the hour's three
## samples (as Weather.rain_in_hour counts the rain).
const WET_FROM := 0.05
const SAMPLES_PER_HOUR := 3
const PARTLY_CLOUDED_FROM := 0.1
const PARTLY_CLOUDED_UNTIL := 0.8
const HOURS_PER_YEAR := GameClock.DAYS_PER_YEAR * 24
const ORIGIN := Vector2i.ZERO

## Per hour of the year, from the first of spring: whether rain or snow falls.
var wet := PackedByteArray()
var _weather: Weather
var _snow_cover: SnowCover


func _init(world_seed: int) -> void:
	_weather = Weather.new(world_seed)
	_snow_cover = SnowCover.new(_weather)
	wet.resize(HOURS_PER_YEAR)
	for hour in HOURS_PER_YEAR:
		wet[hour] = int(_precipitation_in_hour(hour) > WET_FROM)


func wet_share() -> float:
	return float(wet_hours(0, HOURS_PER_YEAR)) / HOURS_PER_YEAR


func wet_hours(from_hour: int, until_hour: int) -> int:
	var count := 0
	for hour in range(from_hour, until_hour):
		count += wet[hour]
	return count


## The wet hours of a season (a GameClock.Season).
func wet_hours_in(season: int) -> int:
	var hours_per_season := GameClock.DAYS_PER_SEASON * 24
	return wet_hours(season * hours_per_season, (season + 1) * hours_per_season)


## Hours of the longest run of wet hours.
func longest_spell() -> int:
	var longest := 0
	var run := 0
	for hour in HOURS_PER_YEAR:
		run = run + 1 if wet[hour] else 0
		longest = maxi(longest, run)
	return longest


## Days of a season (days from 1) on which the snow lies at noon.
func snow_days_in(season: int) -> int:
	return _days_in(season, func(day: int) -> bool: return _snow_cover.at(ORIGIN, day, 720) > 0.1)


## Days of a season whose noon sky is partly clouded and dry: the days with cloud shadows on the
## ground (see WeatherView._show_cloud_shadows).
func days_partly_clouded_in(season: int) -> int:
	return _days_in(season, func(day: int) -> bool: return _is_partly_clouded_at_noon(day))


## One character per hour of a season, `#` wet and `.` dry, a line for each day.
func season_strip(season: int) -> String:
	var lines := PackedStringArray()
	for day in GameClock.DAYS_PER_SEASON:
		var line := ""
		for hour in 24:
			line += "#" if wet[(season * GameClock.DAYS_PER_SEASON + day) * 24 + hour] else "."
		lines.append(line)
	return "\n".join(lines)


func _days_in(season: int, is_counted: Callable) -> int:
	var count := 0
	var first_day := 1 + season * GameClock.DAYS_PER_SEASON
	for day in range(first_day, first_day + GameClock.DAYS_PER_SEASON):
		count += int(is_counted.call(day))
	return count


func _precipitation_in_hour(hour_of_year: int) -> float:
	var day := 1 + hour_of_year / 24
	var minute_of_hour := hour_of_year % 24 * GameClock.MINUTES_PER_HOUR
	var part := GameClock.MINUTES_PER_HOUR / SAMPLES_PER_HOUR
	var total := 0.0
	for index in SAMPLES_PER_HOUR:
		var sample := _weather.at(ORIGIN, day, minute_of_hour + part * index + part / 2)
		total += sample.rain + sample.snow
	return total / SAMPLES_PER_HOUR


func _is_partly_clouded_at_noon(day: int) -> bool:
	var sample := _weather.at(ORIGIN, day, 720)
	return (
		sample.cloud_cover >= PARTLY_CLOUDED_FROM
		and sample.cloud_cover <= PARTLY_CLOUDED_UNTIL
		and sample.rain + sample.snow == 0.0
	)
