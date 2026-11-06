class_name GameClock
extends RefCounted
## Day number and time of day, in whole game minutes. Pure state: whoever owns the clock
## decides how real time maps to game minutes and calls `advance`. The calendar (season,
## day of the season, year) is derived from the running day number.

## Emitted once for every midnight crossed, with the number of the day that begins.
signal new_day(day: int)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 24 * MINUTES_PER_HOUR
const START_MINUTE := 6 * MINUTES_PER_HOUR

const DAYS_PER_SEASON := 30
const DAYS_PER_YEAR := DAYS_PER_SEASON * 4
const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]

var day := 1
## Minutes since midnight, `0 <= minute_of_day < MINUTES_PER_DAY`.
var minute_of_day := START_MINUTE


## The minutes since the start of day 1: a running count for what takes time across days (a
## kiln's firing, see StationWork).
func total_minutes() -> int:
	return (day - 1) * MINUTES_PER_DAY + minute_of_day


func advance(minutes: int) -> void:
	assert(minutes >= 0, "Time only moves forward")
	var total := minute_of_day + minutes
	var days_passed := total / MINUTES_PER_DAY
	minute_of_day = total % MINUTES_PER_DAY
	for _i in days_passed:
		day += 1
		new_day.emit(day)


## The minutes from now until the clock next shows `time_of_day`: a whole day if it shows it
## now.
func minutes_until(time_of_day: int) -> int:
	return posmod(time_of_day - minute_of_day - 1, MINUTES_PER_DAY) + 1


func set_time(hour: int, minute: int) -> void:
	assert(hour >= 0 and hour < 24 and minute >= 0 and minute < 60, "Not a time of day")
	minute_of_day = hour * MINUTES_PER_HOUR + minute


func season() -> Season:
	return ((day - 1) % DAYS_PER_YEAR / DAYS_PER_SEASON) as Season


## 1 to DAYS_PER_SEASON.
func day_of_season() -> int:
	return (day - 1) % DAYS_PER_SEASON + 1


## Starts at 1.
func year() -> int:
	return (day - 1) / DAYS_PER_YEAR + 1


## "10th day of Spring Year 2"
func date_text() -> String:
	return "%s day of %s Year %d" % [_ordinal(day_of_season()), SEASON_NAMES[season()], year()]


## "06:00"
func time_text() -> String:
	return "%02d:%02d" % [minute_of_day / MINUTES_PER_HOUR, minute_of_day % MINUTES_PER_HOUR]


func to_dict() -> Dictionary:
	return {"day": day, "minute_of_day": minute_of_day}


## 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st.
static func _ordinal(number: int) -> String:
	var suffix := "th"
	if number % 100 < 11 or number % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(number % 10, "th")
	return "%d%s" % [number, suffix]


static func from_dict(data: Dictionary) -> GameClock:
	var clock := GameClock.new()
	clock.day = int(data["day"])
	clock.minute_of_day = int(data["minute_of_day"])
	return clock
