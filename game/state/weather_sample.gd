class_name WeatherSample
extends RefCounted
## The weather at one place and moment (see Weather): four measured values and the
## conditions derived from them. A condition's intensity runs from 0 (not there) to 1 (as
## strong as it gets).

## Conditions with an intensity of at least this are named in `conditions_text`.
const ACTIVE_INTENSITY := 0.05
const CONDITIONS: Array[StringName] = [&"rain", &"snow", &"fog", &"wind", &"storm", &"thunder"]

## Percent, 0 to 100.
var humidity := 0.0
## Metres per second.
var wind_speed := 0.0
## A unit vector: where the wind blows to.
var wind_direction := Vector2.RIGHT
## Degrees Celsius.
var temperature := 0.0
## Percent, 0 to 100: the light of the sun reaching the ground. 0 at night, more the higher
## the sun and the fewer clouds.
var sunlight := 100.0
## 0 (clear) to 1 (overcast).
var cloud_cover := 0.0
## 0 while the sun is down, 1 at its highest (see Sun).
var sun_height := 1.0
var rain := 0.0
var snow := 0.0
var fog := 0.0
## Strong wind.
var wind := 0.0
## Heavy rain or snow with strong wind.
var storm := 0.0
## A thunderstorm: warm, humid and windy.
var thunder := 0.0
## The chance of a lightning flash in one game minute.
var lightning_chance := 0.0


func copy() -> WeatherSample:
	var sample := WeatherSample.new()
	for property in [
		"humidity",
		"wind_speed",
		"wind_direction",
		"temperature",
		"sunlight",
		"cloud_cover",
		"sun_height",
	]:
		sample.set(property, get(property))
	for condition in CONDITIONS:
		sample.set(condition, get(condition))
	sample.lightning_chance = lightning_chance
	return sample


## "12 °C · 64 % · 5 m/s · sun 70 %", short enough for the F3 display.
func short_text() -> String:
	return (
		"%d °C · %d %% · %d m/s · sun %d %%"
		% [roundi(temperature), roundi(humidity), roundi(wind_speed), roundi(sunlight)]
	)


## "12.3 °C, humidity 64 %, wind 5.1 m/s, sunlight 70 %"
func values_text() -> String:
	return (
		"%.1f °C, humidity %d %%, wind %.1f m/s, sunlight %d %%"
		% [temperature, roundi(humidity), wind_speed, roundi(sunlight)]
	)


## "rain 0.4, wind 0.2", or "clear" if no condition is active.
func conditions_text() -> String:
	var parts: Array[String] = []
	for condition in CONDITIONS:
		if get(condition) >= ACTIVE_INTENSITY:
			parts.append("%s %.1f" % [condition, get(condition)])
	return ", ".join(parts) if not parts.is_empty() else "clear"
