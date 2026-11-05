class_name GameClock
extends RefCounted
## Day number and time of day, in whole game minutes. Pure state: whoever owns the clock
## decides how real time maps to game minutes and calls `advance`.

## Emitted once for every midnight crossed, with the number of the day that begins.
signal new_day(day: int)

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 24 * MINUTES_PER_HOUR
const START_MINUTE := 6 * MINUTES_PER_HOUR

var day := 1
## Minutes since midnight, `0 <= minute_of_day < MINUTES_PER_DAY`.
var minute_of_day := START_MINUTE


func advance(minutes: int) -> void:
	var total := minute_of_day + minutes
	var days_passed := total / MINUTES_PER_DAY
	minute_of_day = total % MINUTES_PER_DAY
	for _i in days_passed:
		day += 1
		new_day.emit(day)


func set_time(hour: int, minute: int) -> void:
	minute_of_day = hour * MINUTES_PER_HOUR + minute


## "06:00"
func time_text() -> String:
	return "%02d:%02d" % [minute_of_day / MINUTES_PER_HOUR, minute_of_day % MINUTES_PER_HOUR]
