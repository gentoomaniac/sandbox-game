class_name StormyWeather
extends Weather
## A weather with the same storm at every moment, for the tests of the storm surge.

var storm := 0.0


func at(position: Vector2i, day: int, minute: int) -> WeatherSample:
	var sample := super(position, day, minute)
	sample.storm = storm
	return sample
