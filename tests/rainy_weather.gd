class_name RainyWeather
extends Weather
## A weather that rains the same in every hour, for the tests of what rain does.

## How hard it rains, 0 to 1.
var rain := 0.0


func rain_in_hour(_position: Vector2i, _day: int, _hour: int) -> float:
	return rain
