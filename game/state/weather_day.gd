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
## Hours of the heaviest rain: every hour counts as much as its rain intensity.
var rain_hours := 0.0
## The rain of each of the day's 24 hours, as its intensity at the hour's start (`rain_hours` is
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
