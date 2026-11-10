class_name StorkNests
extends RefCounted
## The stork nests on the roofs of the world and the year in each: which buildings have a nest, and
## who is in it at a date and time. The numbers are in data/wildlife.cfg ([stork_nest]).
##
## Nothing here is saved. Which buildings have a nest follows from the world seed and where a
## building stands, and who is in it from the date, the seed and the sun (as the weather does), so
## every game of a seed has the same nests, the player changes one only by taking its building down
## (the nest goes with the roof), and a loaded game finds each nest as it was.
##
## The year of a nest: empty in winter; the pair flies in in early spring and stands on it; the
## young hatch in late spring and grow through the summer; in late summer they stand on the rim, and
## leave one by one, the pair with the last; empty in autumn. By day the parents are away to the
## meadows now and then. Each nest has its own days, each year again.

enum Stage { EMPTY, PAIR, YOUNG, FLEDGING }

## Salts to keep the dice of one thing apart from those of another (see PositionHash).
const NEST_SALT := 0x57A1
const COLUMN_SALT := 0x57A2
const YEAR_SALT := 0x57A3
const TRIP_SALT := 0x57A4
## The dice of a year are those of the year before, moved on by this much.
const YEAR_STEP := 7919
## Arrivals and departures happen at noon of their day.
const NOON := 0.5
const PARENTS := 2

var _rules: StorkNestRules
var _sun: Sun
var _world_seed: int


## Who is in a nest at a moment.
class Occupants:
	var stage := Stage.EMPTY
	## How many of the pair are on the nest, 0 to 2.
	var parents_home := 0
	## How many young are in the nest or on its rim.
	var young := 0
	## How grown the young are, from 0 on the day they hatch to 1 on the day they stand on the rim.
	var growth := 0.0


func _init(rules: StorkNestRules, day_sun: Sun, world_seed: int) -> void:
	_rules = rules
	_sun = day_sun
	_world_seed = world_seed


## Whether a building has a nest on its roof.
func has_nest(building: Building) -> bool:
	var types: Array = _rules.value("building_types")
	return (
		types.has(String(building.type))
		and PositionHash.rolls(
			building.origin, _world_seed + NEST_SALT, _rules.value("nest_chance")
		)
	)


## The column of the building's picture, in pixels, that the nest sits at: on the ridge, the middle
## third of the roof, away from the hips.
func column(building: Building) -> int:
	var footprint: Vector2i = BuildingTypes.TYPES[building.type]["footprint"]
	var width := footprint.x * WildlifeRules.TILE_SIZE
	var third := width / 3
	return third + PositionHash.of(building.origin, _world_seed + COLUMN_SALT) % (third + 1)


## Who is in a building's nest on a day, at a minute of it. The building should have a nest.
func occupants(building: Building, day: int, minute: int) -> Occupants:
	var year := GameClock.year_of(day)
	var origin := building.origin
	var arrival := _arrival(origin, year)
	var hatching := _hatching(origin, year)
	var standing_on_rim := (
		hatching + _days("fledging_days") + _spread(origin, year, 2, "fledging_spread_days")
	)
	var min_young := int(_rules.value("min_young"))
	var brood := min_young + _spread(origin, year, 3, "max_young", min_young)
	var first_leaving := standing_on_rim + _days("first_leaves_days")
	var gap := _days("leaving_gap_days")
	var last_leaving := first_leaving + (brood - 1) * gap

	var time := _time_of_year(day, minute)
	var found := Occupants.new()
	if time < arrival + NOON or time >= last_leaving + NOON:
		return found
	if time < hatching + NOON:
		found.stage = Stage.PAIR
	elif time < standing_on_rim + NOON:
		found.stage = Stage.YOUNG
		found.young = brood
		found.growth = (time - hatching - NOON) / (standing_on_rim - hatching)
	else:
		found.stage = Stage.FLEDGING
		# The ones that have not gone yet: the first goes at `first_leaving`, one more every `gap`.
		var gone := clampi(floori((time - first_leaving - NOON) / gap) + 1, 0, brood)
		found.young = brood - gone
		found.growth = 1.0
	found.parents_home = _parents_home(origin, day, minute, found.stage)
	return found


## How many of the pair are on the nest: both by night, and by day each is away for a few hours at
## a time now and then, more while there are young to feed, though one stays by the newly hatched.
func _parents_home(origin: Vector2i, day: int, minute: int, stage: Stage) -> int:
	if minute < _sun.sunrise(day) or minute > _sun.sunset(day):
		return PARENTS
	var chance: float = _rules.value(
		"trip_chance_pair" if stage == Stage.PAIR else "trip_chance_brood"
	)
	var trip := minute / (int(_rules.value("trip_hours")) * GameClock.MINUTES_PER_HOUR)
	var days_hatched := (
		_time_of_year(day, minute) - _hatching(origin, GameClock.year_of(day)) - NOON
	)
	var is_guarding := stage == Stage.YOUNG and days_hatched < _days("brood_guard_days")
	var home := 0
	for parent in PARENTS:
		var dice := PositionHash.of(
			origin, _world_seed + TRIP_SALT + day * YEAR_STEP + trip * PARENTS + parent
		)
		if dice % 100 >= chance * 100 or (is_guarding and parent == 0):
			home += 1
	return home


func _arrival(origin: Vector2i, year: int) -> float:
	return _days("arrival_day") + _spread(origin, year, 0, "arrival_spread_days")


func _hatching(origin: Vector2i, year: int) -> float:
	return (
		_arrival(origin, year)
		+ _days("incubation_days")
		+ _spread(origin, year, 1, "incubation_spread_days")
	)


## The day of the year with the part of it that has passed: day 1 at midnight is 1.0.
func _time_of_year(day: int, minute: int) -> float:
	var day_of_year := (day - 1) % GameClock.DAYS_PER_YEAR + 1
	return day_of_year + float(minute) / GameClock.MINUTES_PER_DAY


func _days(key: String) -> float:
	return float(_rules.value(key))


## How many days later than the first a nest is, 0 to the file's value `key` less `base`: the same
## for one nest in one year, another for another.
func _spread(origin: Vector2i, year: int, number: int, key: String, base := 0) -> int:
	var salt := _world_seed + YEAR_SALT + year * YEAR_STEP + number
	return PositionHash.of(origin, salt) % (int(_rules.value(key)) - base + 1)
