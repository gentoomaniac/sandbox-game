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
## foliage of those seasons, BARE is winter without snow, FROST a cold morning without snow,
## SNOW the ground under snow and DUSTING its thin fringe: sparse flecks over what lies beneath.
## BUDS and YOUNG_LEAVES are the steps of the leaf-out between BARE and SPRING; only plants have
## them, grass and ground go from BARE to SPRING at once.
enum Look { SPRING, SUMMER, AUTUMN, BARE, FROST, SNOW, DUSTING, BUDS, YOUNG_LEAVES }

## The looks of grass and ground (all but the leaf-out steps).
const GROUND_LOOKS: Array[Look] = [
	Look.SPRING, Look.SUMMER, Look.AUTUMN, Look.BARE, Look.FROST, Look.SNOW, Look.DUSTING
]
## The seasons of the year in order, as the looks the grass shifts between (see `ground_mix`).
const YEAR_LOOKS: Array[Look] = [Look.SPRING, Look.SUMMER, Look.AUTUMN, Look.BARE]
## The steps of a plant's leaf-out in spring, from bare to full leaves.
const LEAF_OUT: Array[Look] = [Look.BARE, Look.BUDS, Look.YOUNG_LEAVES, Look.SPRING]

## Keeps the thresholds apart from other hashes of the same positions.
const SALT := 21
## How much of the weather threshold is slow noise (the rest is the hash), and how fast the
## noise changes over tiles.
const CLUSTER_WEIGHT := 0.45
const CLUSTER_FREQUENCY := 0.08
## The sample and resolution of the table that evens the mix out.
const CDF_SIDE := 96
const CDF_SAMPLES := CDF_SIDE * CDF_SIDE
const CDF_STEPS := 256


## What a day and an hour of weather make of a tile or plant: its look from its two thresholds,
## by the season alone, by the weather alone, or as it shows.
## Built once per refresh of the view (`conditions`), then asked for every tile.
class Conditions:
	extends RefCounted
	## The shares of each blend window that have passed, per boundary in the order of
	## SeasonRules.BOUNDARIES.
	var ground: Array[float] = []
	var foliage: Array[float] = []
	## The share of the spring window that one plant takes to leaf out.
	var leaf_out_span := 1.0

	## The look of grass and ground by the season alone (SPRING to BARE).
	func ground_season_look(season_threshold: float) -> Look:
		# Before the later boundaries, the first one decides between BARE and SPRING; grass has
		# no leaf-out steps.
		var spring_look := Look.SPRING if ground[0] > season_threshold else Look.BARE
		return _season_look(ground, season_threshold, spring_look)

	## The look of trees, bushes and ferns by the season alone.
	func foliage_season_look(season_threshold: float) -> Look:
		return _season_look(foliage, season_threshold, _leaf_out_look(season_threshold))

	## The look by the later boundaries of the year, which win over the earlier ones, or
	## `spring_look`, the look by the first, if none has passed the threshold.
	func _season_look(shares: Array[float], season_threshold: float, spring_look: Look) -> Look:
		if shares[3] > season_threshold:
			return Look.BARE
		if shares[2] > season_threshold:
			return Look.AUTUMN
		if shares[1] > season_threshold:
			return Look.SUMMER
		return spring_look

	## How far a plant has leafed out: it goes through the LEAF_OUT steps evenly over
	## `leaf_out_span` of the spring window, starting the later the higher its threshold, so
	## it is done by the end of the window.
	func _leaf_out_look(season_threshold: float) -> Look:
		var start := season_threshold * (1.0 - leaf_out_span)
		if foliage[0] <= start:
			return Look.BARE
		# BUDS and YOUNG_LEAVES lie between BARE and SPRING; each takes an equal part of the span.
		var steps_between := LEAF_OUT.size() - 2
		var step := leaf_out_span / steps_between
		return LEAF_OUT[mini(floori((foliage[0] - start) / step) + 1, LEAF_OUT.size() - 1)]


## The colour of the ground on a day: the look `from` mixing into the look `to` by `share`
## (0 is all `from`, 1 all `to`). Only the colour of the grass and ground follows it.
class GroundMix:
	extends RefCounted
	var from := Look.BARE
	var to := Look.BARE
	var share := 1.0


var _rules: SeasonRules
var _world_seed: int
var _noise := FastNoiseLite.new()
## The share of sampled mixes up to each of CDF_STEPS + 1 even steps from 0 to 1.
var _cdf := PackedFloat32Array()


func _init(world_seed: int, rules := SeasonRules.default_rules()) -> void:
	_world_seed = world_seed
	_rules = rules
	_noise.seed = world_seed + SALT
	_noise.frequency = CLUSTER_FREQUENCY
	_cdf = _build_cdf()


## The conditions of a day.
func conditions(day: int) -> Conditions:
	var result := Conditions.new()
	for boundary in SeasonRules.BOUNDARIES:
		result.ground.append(share_passed("ground", boundary, day))
		result.foliage.append(share_passed("foliage", boundary, day))
	result.leaf_out_span = _rules.value("foliage", "leaf_out_span")
	return result


## How far a blend window has got on a day, 0 (not begun) to 1 (over), eased smoothly.
func share_passed(section: String, boundary: StringName, day: int) -> float:
	var window := _rules.window(section, boundary)
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	return smoothstep(window.x, window.y, year_day)


## The colour of the whole ground on a day, which shifts evenly through the year (see
## [ground_mix] in data/seasons.cfg): from one season's look to the next, never a tile at a time.
func ground_mix(day: int) -> GroundMix:
	var mix := GroundMix.new()
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	for i in range(SeasonRules.BOUNDARIES.size() - 1, -1, -1):
		var window := _rules.window("ground_mix", SeasonRules.BOUNDARIES[i])
		if year_day > window.x:
			mix.to = YEAR_LOOKS[i]
			mix.from = YEAR_LOOKS[posmod(i - 1, YEAR_LOOKS.size())]
			mix.share = smoothstep(window.x, window.y, year_day)
			return mix
	return mix


## How many fallen leaves lie about on a day, 0 (none) to 1 (all the trees gave): they build up
## through the autumn, lie through the first of winter and thin out to nothing (see [litter]).
func litter(day: int) -> float:
	var year_day := posmod(day - 1, GameClock.DAYS_PER_YEAR) + 1
	var building := smoothstep(
		_rules.value("litter", "from_day"), _rules.value("litter", "full_day"), year_day
	)
	var thinning := smoothstep(
		_rules.value("litter", "thins_day"), _rules.value("litter", "gone_day"), year_day
	)
	return building * (1.0 - thinning)


## The two fixed thresholds of a tile or plant, each in [0, 1): x is held against the blend
## shares of the seasons, y against the snow cover and the frost. x is a hash of the position
## alone. y mixes in a slow noise, so snow lies in clusters: it builds and melts in patches
## that a dusting rings, not tile by tile. The mix is bent back to an even spread (see
## `_cdf`), so a cover of 0.3 still means about three in ten tiles.
func thresholds(pos: Vector2i) -> Vector2:
	var roll := PositionHash.of(pos, _world_seed + SALT)
	return Vector2(roll % 10000 / 10000.0, _evened(_clustered(pos, roll / 10000 % 10000 / 10000.0)))


## A hash roll in [0, 1) mixed with the slow noise at a position.
func _clustered(pos: Vector2i, roll: float) -> float:
	var noise := _noise.get_noise_2dv(Vector2(pos)) * 0.5 + 0.5
	return lerpf(roll, noise, CLUSTER_WEIGHT)


## Maps a mix to its rank among all mixes (from a sample), so that thresholds are spread evenly.
func _evened(mixed: float) -> float:
	var at := clampf(mixed, 0.0, 1.0) * (_cdf.size() - 1)
	var index := mini(int(at), _cdf.size() - 2)
	return minf(lerpf(_cdf[index], _cdf[index + 1], at - index), 0.9999)


func _build_cdf() -> PackedFloat32Array:
	var mixes := PackedFloat32Array()
	for i in CDF_SAMPLES:
		var pos := Vector2i(i % CDF_SIDE, i / CDF_SIDE)
		mixes.append(_clustered(pos, PositionHash.of(pos, _world_seed + SALT) % 10000 / 10000.0))
	mixes.sort()
	var cdf := PackedFloat32Array()
	for step in CDF_STEPS + 1:
		var value := float(step) / CDF_STEPS
		cdf.append(float(mixes.bsearch(value)) / mixes.size())
	return cdf
