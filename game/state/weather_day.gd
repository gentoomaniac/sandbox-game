class_name WeatherDay
extends RefCounted
## One whole day's weather at a place, boiled down to what farming needs (see
## Weather.day_summary).

## Degrees Celsius.
var min_temperature := 0.0
var mean_temperature := 0.0
var max_temperature := 0.0
## Hours of full sun: every hour counts as much as its sunlight percentage (a clear noon hour
## is 1, a dull one a fifth).
var sunlight_hours := 0.0
## Hours of the heaviest rain: every hour counts as much as its mean rain intensity.
var rain_hours := 0.0
## The rain of each of the day's 24 hours, as its mean intensity over the hour (`rain_hours` is
## their sum).
var rain_by_hour := PackedFloat32Array()
## Metres per second: the strongest wind of the day's hours.
var max_wind_speed := 0.0


## "2.1 to 11.8 °C (mean 7.4), sun 5.2 h, rain 1.3 h, wind up to 6.3 m/s"
func text() -> String:
	return (
		"%.1f to %.1f °C (mean %.1f), sun %.1f h, rain %.1f h, wind up to %.1f m/s"
		% [
			min_temperature,
			max_temperature,
			mean_temperature,
			sunlight_hours,
			rain_hours,
			max_wind_speed
		]
	)


## The day as a villager would tell it, for a prompt: "3 to 9 °C, rain from 06:00 to 08:00 and
## from 14:00 to 17:00, wind up to 6 m/s". An hour counts as rainy when its mean rain is at least
## `rain_hour_limit` (0 to 1, see ActivityRules `rain_hour_limit`), as it does for an activity that
## needs dry weather.
func words(rain_hour_limit: float) -> String:
	var spans: Array[String] = []
	var span_start := -1
	for hour in rain_by_hour.size() + 1:
		var is_rainy := hour < rain_by_hour.size() and rain_by_hour[hour] >= rain_hour_limit
		if is_rainy and span_start < 0:
			span_start = hour
		elif not is_rainy and span_start >= 0:
			spans.append("from %02d:00 to %02d:00" % [span_start, hour])
			span_start = -1
	var rain := "rain " + " and ".join(spans) if not spans.is_empty() else "no rain"
	return (
		"%d to %d °C, %s, wind up to %d m/s"
		% [roundi(min_temperature), roundi(max_temperature), rain, roundi(max_wind_speed)]
	)
