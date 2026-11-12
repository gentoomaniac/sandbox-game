class_name SnowCover
extends RefCounted
## The snow on the ground of a weather region: 0 (bare) to 1 (covered), integrated hour by
## hour from the weather. Snowfall adds to it, and above 0 degrees it melts, faster in
## sunshine (the numbers are in data/seasons.cfg). Derived from the weather alone, so nothing
## is saved and any moment can be asked for: the sum is made from the start of the autumn
## (when it surely is 0) up to the moment, and kept, so a clock that moves on only adds the
## new hours. There is no snow from the first day of the year on, which the thaw has made
## true by then (a test checks it).

## Session-only (see Console): a cover that replaces the simulated one, or below 0 for none.
var forced := -1.0
## Session-only, like `forced`: a frost and a thaw (0 to 1) that replace the ones of the
## temperature, or below 0 for none (the startup options --frost and --melt).
var forced_frost := -1.0
var forced_thaw := -1.0

var _weather: Weather
var _rules: SeasonRules
## Per region: where its count starts (in game minutes) and the cover at the start of each
## hour from there.
var _counts: Dictionary[Vector2i, Count] = {}


## One region's cover so far: `hours[n]` is the cover n hours after `start_minute`.
class Count:
	extends RefCounted
	var start_minute := 0
	var hours := PackedFloat32Array([0.0])


func _init(weather: Weather, rules := SeasonRules.default_rules()) -> void:
	_weather = weather
	_rules = rules


## The snow cover at a world tile on a day (as GameClock.day) at a minute of that day.
func at(position: Vector2i, day: int, minute: int) -> float:
	if forced >= 0.0:
		return forced
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	var counted_from := int(_rules.value("snow", "counted_from_day"))
	if year_day < counted_from:
		return 0.0
	var region := Weather.region_of(position)
	var start_day := day - (year_day - counted_from)
	var count := _count_of(region, (start_day - 1) * GameClock.MINUTES_PER_DAY)
	var since_start := (day - start_day) * GameClock.MINUTES_PER_DAY + minute
	var hour := since_start / GameClock.MINUTES_PER_HOUR
	_extend(count, region, hour + 1)
	return lerpf(
		count.hours[hour],
		count.hours[hour + 1],
		float(since_start % GameClock.MINUTES_PER_HOUR) / GameClock.MINUTES_PER_HOUR
	)


## The frost at a temperature: none at 0 degrees or above, full at the cold of the data file.
func frost_at(temperature: float) -> float:
	if forced_frost >= 0.0:
		return forced_frost
	return clampf(temperature / _rules.value("frost", "full_at_temperature"), 0.0, 1.0)


## The thaw at a temperature and in a sunlight (0 to 100): none at 0 degrees or below, full at
## the warmth of the data file (sunshine counts as more warmth, as it melts more).
func thaw_at(temperature: float, sunlight: float) -> float:
	if forced_thaw >= 0.0:
		return forced_thaw
	var sun_gain: float = _rules.value("snow", "sun_melt_gain")
	var warmth := maxf(temperature, 0.0) * (1.0 + sun_gain * sunlight / 100.0)
	return clampf(warmth / _rules.value("snow", "full_thaw_at_temperature"), 0.0, 1.0)


## The cover of the region's count that starts at `start_minute` (a new one if that is another
## count than the one kept).
func _count_of(region: Vector2i, start_minute: int) -> Count:
	var count: Count = _counts.get(region)
	if count == null or count.start_minute != start_minute:
		count = Count.new()
		count.start_minute = start_minute
		_counts[region] = count
	return count


## Adds hours to a count until it holds the cover at the start of hour `until`.
func _extend(count: Count, region: Vector2i, until: int) -> void:
	var snowfall: float = _rules.value("snow", "snowfall_per_hour")
	var melt: float = _rules.value("snow", "melt_per_degree_hour")
	var sun_gain: float = _rules.value("snow", "sun_melt_gain")
	while count.hours.size() <= until:
		var hour := count.hours.size() - 1
		var half_hour := GameClock.MINUTES_PER_HOUR / 2
		var minutes := count.start_minute + hour * GameClock.MINUTES_PER_HOUR + half_hour
		var sample := _weather.at(
			region, minutes / GameClock.MINUTES_PER_DAY + 1, minutes % GameClock.MINUTES_PER_DAY
		)
		var change := sample.snow * snowfall
		if sample.temperature > 0.0:
			change -= sample.temperature * melt * (1.0 + sun_gain * sample.sunlight / 100.0)
		count.hours.append(clampf(count.hours[hour] + change, 0.0, 1.0))
