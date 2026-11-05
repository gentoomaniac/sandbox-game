class_name Sun
extends RefCounted
## Sunrise, sunset and the height of the sun over the year. The game is set in the Nordics:
## the day length follows a smooth cosine over the year, longest in mid-summer and shortest
## in mid-winter, and the sun is up around noon. `variation` scales the swing: 0 gives
## 12-hour days all year. The numbers are in data/weather.cfg (see WeatherRules).

## 0 to 1: how much of the yearly day length swing applies (the "Day length variation"
## setting).
var variation := 1.0

var _rules: WeatherRules


func _init(rules := WeatherRules.default_rules()) -> void:
	_rules = rules


## "05:40" for a time given in minutes since midnight.
static func time_text(minutes: float) -> String:
	var whole := roundi(minutes)
	return "%02d:%02d" % [whole / GameClock.MINUTES_PER_HOUR, whole % GameClock.MINUTES_PER_HOUR]


## Minutes since midnight at which the sun rises on a day (as GameClock.day).
func sunrise(day: int) -> float:
	return GameClock.MINUTES_PER_DAY / 2.0 - day_length(day) / 2.0


func sunset(day: int) -> float:
	return GameClock.MINUTES_PER_DAY / 2.0 + day_length(day) / 2.0


## Minutes the sun is up on a day.
func day_length(day: int) -> float:
	return (
		12.0 * GameClock.MINUTES_PER_HOUR
		+ (
			_rules.value("sun", "day_length_swing_hours")
			* GameClock.MINUTES_PER_HOUR
			* variation
			* _year_cosine(day)
		)
	)


## How high the sun is: 0 while it is down, rising to the day's noon height and back.
func height(day: int, minute: int) -> float:
	var rise := sunrise(day)
	var down := sunset(day)
	if minute <= rise or minute >= down:
		return 0.0
	return noon_height(day) * sin(PI * (minute - rise) / (down - rise))


## How high the sun gets at noon on a day, from 1 down to `lowest_noon_height` in mid-winter
## (the sun stays as high as ever without day length variation).
func noon_height(day: int) -> float:
	var lowest: float = _rules.value("sun", "lowest_noon_height")
	return 1.0 - (1.0 - lowest) * (1.0 - _year_cosine(day)) / 2.0 * variation


## 1 on the longest day, -1 on the shortest, 0 in between.
func _year_cosine(day: int) -> float:
	return cos(TAU * (day - _rules.value("sun", "longest_day")) / GameClock.DAYS_PER_YEAR)
