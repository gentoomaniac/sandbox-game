class_name SurgeRoll
extends RefCounted
## Whether the sea runs high enough to be a storm surge at a high water, and how high: a pure
## function of the world seed, the weather and the number of the tide, so the same world rolls the
## same surges (see design/world/storm-surge.md). The numbers are in the `[surge]` section of
## data/weather.cfg.

## Salts that keep the chance's roll and the level's noise independent.
const CHANCE_SALT := 1030
const LEVEL_SALT := 1031
## The resolution of a roll.
const ROLL_STEPS := 10000
## The storm is looked at this often, in game minutes, within the hours the surge holds.
const STORM_SAMPLE_MINUTES := 30

var _world_seed: int
var _weather: Weather
var _rules: WeatherRules


func _init(world_seed: int, weather: Weather, rules := WeatherRules.default_rules()) -> void:
	_world_seed = world_seed
	_weather = weather
	_rules = rules


## The number of the high water nearest a game minute (see `GameClock.total_minutes`): the first,
## at midnight before day 1, is 0.
static func tide_number_at(minutes: float) -> int:
	return roundi(minutes / Tide.PERIOD_MINUTES)


## The game minute of a high water.
static func peak_minute(tide_number: int) -> int:
	return roundi(tide_number * Tide.PERIOD_MINUTES)


## The chance of a surge at a high water, 0 to 1: it needs the season and a heavy storm.
func chance_for(tide_number: int) -> float:
	var day_of_year := GameClock.day_of_year_of(GameClock.day_of(peak_minute(tide_number)))
	if day_of_year < _rules.value("surge", "first_day"):
		return 0.0
	if day_of_year > _rules.value("surge", "last_day"):
		return 0.0
	var storm := _storm_share_at(tide_number)
	if storm < _rules.value("surge", "min_storm") / _rules.value("surge", "full_storm"):
		return 0.0
	var chance: float = _rules.value("surge", "base_chance") * storm * storm
	if day_of_year >= _rules.value("surge", "winter_from_day"):
		chance *= _rules.value("surge", "winter_share")
	return minf(chance, 1.0)


## How high the water rises over mean high water at a high water, in metres, or 0 when there is no
## surge.
func level_for(tide_number: int) -> float:
	if _roll(tide_number, CHANCE_SALT) >= chance_for(tide_number):
		return 0.0
	var share := minf(_storm_share_at(tide_number), 1.0)
	var noise: float = (
		_rules.value("surge", "level_noise") * (2.0 * _roll(tide_number, LEVEL_SALT) - 1.0)
	)
	return (
		lerpf(_rules.value("surge", "level_min"), _rules.value("surge", "level_max"), share) + noise
	)


## The strongest storm within the hours the surge holds around a high water, as a share of the
## storm that is as strong as it gets (`full_storm`), up to 1 and over.
func _storm_share_at(tide_number: int) -> float:
	var peak := peak_minute(tide_number)
	var half_hold := int(_rules.value("surge", "hold_hours") * GameClock.MINUTES_PER_HOUR / 2.0)
	var strongest := 0.0
	for minute in range(peak - half_hold, peak + half_hold + 1, STORM_SAMPLE_MINUTES):
		var day := GameClock.day_of(maxi(minute, 0))
		var minute_of_day := maxi(minute, 0) % GameClock.MINUTES_PER_DAY
		strongest = maxf(strongest, _weather.at(Vector2i.ZERO, day, minute_of_day).storm)
	return strongest / _rules.value("surge", "full_storm")


## A number from 0 up to 1 that is the same for the same tide, seed and salt.
func _roll(tide_number: int, salt: int) -> float:
	return (
		float(PositionHash.of(Vector2i(tide_number, 0), _world_seed + salt) % ROLL_STEPS)
		/ ROLL_STEPS
	)
