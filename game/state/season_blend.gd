class_name SeasonBlend
extends RefCounted
## What every tile and every plant looks like on a day, in the weather of the hour: one of the
## LOOKS. The seasons fade into each other (see data/seasons.cfg): around each boundary between
## two looks, a share of the tiles and plants has changed over, growing day by day. Which
## ones is decided by a fixed random threshold of each (from the seed and its position), so
## the change goes tile by tile and tree by tree. Snow and frost work the same way against
## the snow cover and the frost of the moment, and win over the season's look.
## Pure functions of seed, position, day and weather: nothing is saved.

## What the art generator draws (see tools/art/seasons.py). SPRING, SUMMER and AUTUMN are the
## foliage of those seasons, BARE is winter without snow, FROST a cold morning without snow
## and SNOW the ground under snow.
enum Look { SPRING, SUMMER, AUTUMN, BARE, FROST, SNOW }

## Keeps the thresholds apart from other hashes of the same positions.
const SALT := 21


## What a day and an hour of weather make of a tile or plant: its look from its two thresholds,
## by the season alone, by the weather alone, or as it shows.
## Built once per refresh of the view (`conditions`), then asked for every tile.
class Conditions:
	extends RefCounted
	## The shares of each blend window that have passed, per boundary in the order of
	## SeasonRules.BOUNDARIES.
	var ground: Array[float] = []
	var foliage: Array[float] = []
	var snow_cover := 0.0
	var frost := 0.0

	## The look of grass and ground by the season alone (SPRING to BARE).
	func ground_season_look(season_threshold: float) -> Look:
		return _season_look(ground, season_threshold)

	## The look of trees, bushes and ferns by the season alone.
	func foliage_season_look(season_threshold: float) -> Look:
		return _season_look(foliage, season_threshold)

	## What lies over the season's look: SNOW, FROST, or SUMMER for nothing (the base look).
	func weather_look(weather_threshold: float) -> Look:
		if snow_cover > weather_threshold:
			return Look.SNOW
		if frost > weather_threshold:
			return Look.FROST
		return Look.SUMMER

	## The look of a plant as it shows: snow or frost win over the season's look.
	func foliage_look(season_threshold: float, weather_threshold: float) -> Look:
		var weather := weather_look(weather_threshold)
		return weather if weather != Look.SUMMER else foliage_season_look(season_threshold)

	func _season_look(shares: Array[float], season_threshold: float) -> Look:
		# The later boundary of the year wins over the earlier ones.
		var look := Look.BARE
		if shares[0] > season_threshold:
			look = Look.SPRING
		if shares[1] > season_threshold:
			look = Look.SUMMER
		if shares[2] > season_threshold:
			look = Look.AUTUMN
		if shares[3] > season_threshold:
			look = Look.BARE
		return look


var _rules: SeasonRules
var _world_seed: int


func _init(world_seed: int, rules := SeasonRules.default_rules()) -> void:
	_world_seed = world_seed
	_rules = rules


## The conditions of a day with this snow cover and frost (both 0 to 1).
func conditions(day: int, snow_cover: float, frost: float) -> Conditions:
	var result := Conditions.new()
	for boundary in SeasonRules.BOUNDARIES:
		result.ground.append(share_passed("ground", boundary, day))
		result.foliage.append(share_passed("foliage", boundary, day))
	result.snow_cover = snow_cover
	result.frost = frost
	return result


## How far a blend window has got on a day, 0 (not begun) to 1 (over), eased smoothly.
func share_passed(section: String, boundary: StringName, day: int) -> float:
	var window := _rules.window(section, boundary)
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	return smoothstep(window.x, window.y, year_day)


## The two fixed thresholds of a tile or plant, each in [0, 1): x is held against the blend
## shares of the seasons, y against the snow cover and the frost. One hash gives both, as
## different digits of it.
func thresholds(pos: Vector2i) -> Vector2:
	var roll := PositionHash.of(pos, _world_seed + SALT)
	return Vector2(roll % 10000, roll / 10000 % 10000) / 10000.0
