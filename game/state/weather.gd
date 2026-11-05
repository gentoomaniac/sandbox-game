class_name Weather
extends RefCounted
## The weather of a world: a pure function of the world seed, the region and the game time,
## so nothing is saved and any past or future moment can be asked for. Every value is smooth
## noise over game time (spells of weeks and fronts of days down to gusts within the hour)
## around a baseline that runs smoothly through the seasons' values over the year. The daily
## cycle follows the Sun: no sunlight at night, and the temperature warms while the sun is up
## and cools through the night. The numbers are in data/weather.cfg (see WeatherRules).

## Which noise a value draws from, so that they don't move together. No list of octaves is
## longer than MAX_OCTAVES.
enum Channel { TEMPERATURE, HUMIDITY, WIND, DIRECTION }

## The conditions `forced` can make, besides the sample's own.
const FORCEABLE: Array[StringName] = [
	&"clear", &"rain", &"snow", &"fog", &"wind", &"storm", &"thunder"
]
## What `forced` sets for each of them: values, and the one condition (or none) that is on.
const FORCED := {
	&"clear": {"humidity": 35.0, "wind_speed": 2.0, "cloud_cover": 0.0},
	&"rain": {"humidity": 90.0, "temperature": 10.0, "cloud_cover": 0.7, "rain": 0.8},
	&"snow": {"humidity": 90.0, "temperature": -3.0, "cloud_cover": 0.7, "snow": 0.8},
	&"fog":
	{"humidity": 98.0, "wind_speed": 1.0, "temperature": 5.0, "cloud_cover": 0.5, "fog": 0.9},
	&"wind": {"wind_speed": 14.0, "wind": 0.8, "humidity": 50.0, "cloud_cover": 0.1},
	&"storm":
	{
		"humidity": 95.0,
		"temperature": 12.0,
		"wind_speed": 15.0,
		"cloud_cover": 0.9,
		"rain": 1.0,
		"wind": 0.9,
		"storm": 1.0,
	},
	&"thunder":
	{
		"humidity": 95.0,
		"temperature": 22.0,
		"wind_speed": 12.0,
		"cloud_cover": 1.0,
		"rain": 1.0,
		"wind": 0.6,
		"storm": 0.8,
		"thunder": 1.0,
	},
}

## Octaves of value noise as [period in game minutes, weight]: the first catches the spells
## of weeks that bring the odd out-of-season weather, the last the quickest changes.
const FRONT_OCTAVES := [[43200, 0.5], [8640, 1.0], [2880, 0.6], [480, 0.3]]
## For humidity and wind: gusts and showers within the hour on top.
const GUST_OCTAVES := [[43200, 0.3], [8640, 1.0], [2880, 0.6], [480, 0.4], [90, 0.25], [20, 0.1]]
const DIRECTION_OCTAVES := [[4320, 1.0], [360, 0.3]]
const MAX_OCTAVES := 8
## Averaged octaves seldom come near -1 or 1, so the noise is stretched (and cut off at 1).
const NOISE_GAIN := 1.8

var _world_seed: int
var _sun: Sun
var _rules: WeatherRules


func _init(world_seed: int, sun := Sun.new(), rules := WeatherRules.default_rules()) -> void:
	_world_seed = world_seed
	_sun = sun
	_rules = rules


## The weather region a world tile belongs to. There is one for now.
static func region_of(_position: Vector2i) -> Vector2i:
	return Vector2i.ZERO


## The weather at a world tile on a day (as GameClock.day, from 1) at a minute of that day.
func at(position: Vector2i, day: int, minute: int) -> WeatherSample:
	var minutes := (day - 1) * GameClock.MINUTES_PER_DAY + minute
	var salt := PositionHash.of(region_of(position), _world_seed)
	var season_curve := _season_curve(minutes)
	# Positive while the sun is up and the temperature rises, negative at night.
	var daily_cycle := _daily_cycle(day, minute)
	var sample := WeatherSample.new()
	sample.humidity = clampf(
		(
			_baseline(season_curve, "humidity_mean")
			+ (
				_baseline(season_curve, "humidity_spread")
				* _noise(salt, Channel.HUMIDITY, minutes, GUST_OCTAVES)
			)
			- _rules.value("daily", "humidity_swing") / 2.0 * daily_cycle
		),
		0.0,
		100.0
	)
	sample.wind_speed = maxf(
		0.0,
		(
			_baseline(season_curve, "wind_mean")
			+ (
				_baseline(season_curve, "wind_spread")
				* _noise(salt, Channel.WIND, minutes, GUST_OCTAVES)
			)
		)
	)
	sample.wind_direction = Vector2.from_angle(
		PI * _noise(salt, Channel.DIRECTION, minutes, DIRECTION_OCTAVES)
	)
	sample.cloud_cover = clampf(
		_ramp(sample.humidity, "clouds", "humidity") + _baseline(season_curve, "cloudiness"),
		0.0,
		1.0
	)
	sample.sun_height = _sun.height(day, minute)
	sample.sunlight = _sunlight(sample)
	sample.temperature = (
		_temperature_mean(season_curve, minutes)
		+ (
			_baseline(season_curve, "temperature_spread")
			* _noise(salt, Channel.TEMPERATURE, minutes, FRONT_OCTAVES)
		)
		+ (
			_baseline(season_curve, "temperature_swing")
			/ 2.0
			* daily_cycle
			* (1.0 - _rules.value("temperature", "cloud_damping") * sample.cloud_cover)
		)
	)
	sample.temperature = _kept_above_frost_floor(sample.temperature, minutes)
	_derive_conditions(sample, day, minute)
	return sample


## The sample with the condition made true, for tests and screenshots: `condition` is one of
## FORCEABLE. Values it doesn't set stay as they were.
func forced(sample: WeatherSample, condition: StringName) -> WeatherSample:
	assert(FORCED.has(condition), "Not a weather condition: %s" % condition)
	var result := sample.copy()
	for name in WeatherSample.CONDITIONS:
		result.set(name, 0.0)
	for property: String in FORCED[condition]:
		result.set(property, FORCED[condition][property])
	result.sunlight = _sunlight(result)
	result.lightning_chance = result.thunder * _rules.value("thunder", "lightning_per_minute")
	return result


## The temperature with winter's frost rule applied: below freezing only happens in winter.
## The floor under the temperature is a degree or so above freezing outside winter and gives
## way (smoothly) in the first days of winter; the temperature bends away from it instead of
## sitting flat on it.
func _kept_above_frost_floor(temperature: float, minutes: int) -> float:
	var ramp: float = _rules.value("frost", "ramp_days")
	var winter_day := (
		fposmod(float(minutes) / GameClock.MINUTES_PER_DAY, GameClock.DAYS_PER_YEAR)
		- 3 * GameClock.DAYS_PER_SEASON
	)
	var winter_share := (
		smoothstep(0.0, ramp, winter_day)
		* (
			1.0
			- smoothstep(GameClock.DAYS_PER_SEASON - ramp, GameClock.DAYS_PER_SEASON, winter_day)
		)
	)
	var floor_temperature := lerpf(
		_rules.value("frost", "floor_outside_winter"),
		_rules.value("frost", "winter_floor"),
		winter_share
	)
	var softness: float = _rules.value("frost", "softness")
	var above_floor := (temperature - floor_temperature) / softness
	if above_floor > 20.0:
		return temperature
	return floor_temperature + softness * log(1.0 + exp(above_floor))


## Percent of the sun's full light that gets through: nothing while it is down, more the
## higher it is and the fewer clouds there are.
func _sunlight(sample: WeatherSample) -> float:
	var overcast_share: float = _rules.value("clouds", "overcast_sunlight") / 100.0
	var cloud_factor := lerpf(1.0, overcast_share, sample.cloud_cover)
	return 100.0 * sample.sun_height * cloud_factor


## How the sun drives the temperature through the day, as a number that is 1 at the warmest
## and -1 at the coldest on an average day: it rises from the coldest at sunrise to the
## warmest in the afternoon, falls to a level at sunset and cools through the night, to the
## coldest again at the next sunrise. A long day warms more and a long night cools more.
func _daily_cycle(day: int, minute: int) -> float:
	var rise := _sun.sunrise(day)
	var down := _sun.sunset(day)
	if minute <= rise:
		# The night that started yesterday evening.
		var night_start := _sun.sunset(day - 1) - GameClock.MINUTES_PER_DAY
		return _night_cycle(day - 1, (minute - night_start) / (rise - night_start))
	if minute >= down:
		var night_end := _sun.sunrise(day + 1) + GameClock.MINUTES_PER_DAY
		return _night_cycle(day, (minute - down) / (night_end - down))
	var peak_at: float = _rules.value("temperature", "peak_at")
	var peak := _day_warmth(day)
	var day_fraction := (minute - rise) / (down - rise)
	if day_fraction < peak_at:
		var coldest := -_night_coldness(day - 1)
		return coldest + (peak - coldest) * sin(PI / 2.0 * day_fraction / peak_at)
	var sunset_level: float = _rules.value("temperature", "sunset_level") * peak
	return lerpf(peak, sunset_level, smoothstep(peak_at, 1.0, day_fraction))


## The cycle during the night that follows `day`, `progress` of the way from sunset to sunrise.
func _night_cycle(day: int, progress: float) -> float:
	var sunset_level: float = _rules.value("temperature", "sunset_level") * _day_warmth(day)
	var cooled := 1.0 - (1.0 - progress) * (1.0 - progress)
	return lerpf(sunset_level, -_night_coldness(day), cooled)


## How warm the day gets, 1 for a day of 12 hours.
func _day_warmth(day: int) -> float:
	return _length_effect(_sun.day_length(day))


## How cold the night after `day` gets, 1 for a night of 12 hours.
func _night_coldness(day: int) -> float:
	var night_length := GameClock.MINUTES_PER_DAY - _sun.sunset(day) + _sun.sunrise(day + 1)
	return _length_effect(night_length)


func _length_effect(minutes: float) -> float:
	return clampf(
		minutes / (12.0 * GameClock.MINUTES_PER_HOUR),
		_rules.value("temperature", "length_effect_min"),
		_rules.value("temperature", "length_effect_max")
	)


func _derive_conditions(sample: WeatherSample, day: int, minute: int) -> void:
	var precipitation := _ramp(sample.humidity, "precipitation", "humidity")
	var rain_share := clampf(
		sample.temperature / _rules.value("precipitation", "rain_from_temperature"), 0.0, 1.0
	)
	sample.rain = precipitation * rain_share
	sample.snow = precipitation * (1.0 - rain_share)
	sample.wind = _ramp_between(
		sample.wind_speed, _rules.value("wind", "strong_from"), _rules.value("wind", "strong_full")
	)
	sample.storm = minf(precipitation, sample.wind)
	var calm := 1.0 - clampf(sample.wind_speed / _rules.value("fog", "calm_wind"), 0.0, 1.0)
	# Rain washes the fog out of the air.
	sample.fog = (
		_ramp(sample.humidity, "fog", "humidity")
		* calm
		* (1.0 - 0.4 * precipitation)
		* _fog_hours_factor(day, minute)
	)
	sample.thunder = minf(
		_ramp(sample.temperature, "thunder", "temperature"),
		minf(
			_ramp(sample.humidity, "thunder", "humidity"),
			_ramp(sample.wind_speed, "thunder", "wind")
		)
	)
	sample.lightning_chance = sample.thunder * _rules.value("thunder", "lightning_per_minute")


## 1 within the fog hours around sunrise, fading to the share fog has the rest of the day.
func _fog_hours_factor(day: int, minute: int) -> float:
	var sunrise_hour := _sun.sunrise(day) / GameClock.MINUTES_PER_HOUR
	var from := sunrise_hour - _rules.value("daily", "fog_before_sunrise_hours")
	var until := sunrise_hour + _rules.value("daily", "fog_after_sunrise_hours")
	var fade := _rules.value("daily", "fog_fade_hours")
	var hour := float(minute) / GameClock.MINUTES_PER_HOUR
	var in_hours := (
		smoothstep(from - fade, from, hour) * (1.0 - smoothstep(until, until + fade, hour))
	)
	return lerpf(_rules.value("daily", "fog_other_hours"), 1.0, in_hours)


## Where the minute is on the yearly curve through the seasons' values, as [from season,
## to season, weight of `to`]: each season's values are those of its middle day, and between
## two middles the baseline eases from one to the other.
func _season_curve(minutes: int) -> Array:
	var days_since_middle := fposmod(
		float(minutes) / GameClock.MINUTES_PER_DAY - GameClock.DAYS_PER_SEASON / 2.0,
		GameClock.DAYS_PER_YEAR
	)
	var seasons_since_middle := days_since_middle / GameClock.DAYS_PER_SEASON
	var from := int(seasons_since_middle)
	return [from, (from + 1) % 4, smoothstep(0.0, 1.0, seasons_since_middle - from)]


## The mean temperature: the season curve, except between the middle of winter and the middle
## of spring, where it holds the winter value until late, thaws quickly and then rises on
## (see [thaw] in the data file).
func _temperature_mean(season_curve: Array, minutes: int) -> float:
	var year_day := fposmod(float(minutes) / GameClock.MINUTES_PER_DAY, GameClock.DAYS_PER_YEAR)
	# The span runs over the turn of the year, so the early days count past 120.
	if year_day < GameClock.DAYS_PER_YEAR / 2.0:
		year_day += GameClock.DAYS_PER_YEAR
	var winter_middle := 3.5 * GameClock.DAYS_PER_SEASON
	var spring_middle := 4.5 * GameClock.DAYS_PER_SEASON
	if year_day < winter_middle or year_day > spring_middle:
		return _baseline(season_curve, "temperature_mean")
	var winter_mean := _rules.season_value(GameClock.Season.WINTER, "temperature_mean")
	var points := [
		Vector2(winter_middle, winter_mean),
		Vector2(_rules.value("thaw", "start_day"), winter_mean),
		Vector2(_rules.value("thaw", "anchor_day"), _rules.value("thaw", "anchor_temperature")),
		Vector2(spring_middle, _rules.season_value(GameClock.Season.SPRING, "temperature_mean")),
	]
	for index in range(1, points.size()):
		if year_day <= points[index].x:
			return lerpf(
				points[index - 1].y,
				points[index].y,
				smoothstep(points[index - 1].x, points[index].x, year_day)
			)
	return points[-1].y


func _baseline(season_curve: Array, key: String) -> float:
	return lerpf(
		_rules.season_value(season_curve[0], key),
		_rules.season_value(season_curve[1], key),
		season_curve[2]
	)


## `value` from the section's `<name>_from` (0) to `<name>_full` (1).
func _ramp(value: float, section: String, name: String) -> float:
	return _ramp_between(
		value, _rules.value(section, name + "_from"), _rules.value(section, name + "_full")
	)


static func _ramp_between(value: float, from: float, full: float) -> float:
	return clampf((value - from) / (full - from), 0.0, 1.0)


## Smooth noise between -1 and 1 at a game minute: value noise, every octave a lattice of
## random values one period apart, blended with a smoothstep.
func _noise(salt: int, channel: Channel, minutes: int, octaves: Array) -> float:
	var total := 0.0
	var total_weight := 0.0
	for index in octaves.size():
		var period: int = octaves[index][0]
		var weight: float = octaves[index][1]
		var cell := floori(float(minutes) / period)
		var blend := smoothstep(0.0, 1.0, float(minutes) / period - cell)
		var octave_id := channel * MAX_OCTAVES + index
		total += (
			weight
			* lerpf(
				_lattice_value(salt, octave_id, cell),
				_lattice_value(salt, octave_id, cell + 1),
				blend
			)
		)
		total_weight += weight
	return clampf(total / total_weight * NOISE_GAIN, -1.0, 1.0)


## A random value between -1 and 1 for a lattice point of one octave.
func _lattice_value(salt: int, octave_id: int, cell: int) -> float:
	return float(PositionHash.of(Vector2i(cell, octave_id), salt)) / PositionHash.MASK * 2.0 - 1.0
