class_name SeasonBlend
extends RefCounted
## What the grass and the plants look like on a day: the foliage of each tree and bush by the
## season, and the colour of the whole ground. The seasons fade into each other (see
## data/seasons.cfg): around each boundary between two looks, a share of the plants has changed
## over, growing day by day. Which ones is decided by a fixed random threshold of each (from the
## seed and its position), so the change goes tree by tree. The ground's colour does not change by
## the tile but evenly (`ground_mix`), and the leaves, frost and snow lie over the ground and the
## plants as overlays (see GroundCover). Pure functions of seed, position and day: nothing is saved.

## What the art generator draws (see tools/art/seasons.py). SPRING, SUMMER and AUTUMN are the
## foliage of those seasons, BARE is winter without snow. FROST and SNOW are the ground in a
## frost and under snow: the ground shader takes the colours of the frost and of the snow from
## them (see GroundLook), and the generator takes the cover of objects and roofs from them. BUDS
## and YOUNG_LEAVES are the steps of the leaf-out between BARE and SPRING; only plants have them.
enum Look { SPRING, SUMMER, AUTUMN, BARE, FROST, SNOW, BUDS, YOUNG_LEAVES }

## The looks of grass and ground (all but the leaf-out steps).
const GROUND_LOOKS: Array[Look] = [
	Look.SPRING, Look.SUMMER, Look.AUTUMN, Look.BARE, Look.FROST, Look.SNOW
]
## The seasons of the year in order, as the looks the grass shifts between (see `ground_mix`).
const YEAR_LOOKS: Array[Look] = [Look.SPRING, Look.SUMMER, Look.AUTUMN, Look.BARE]
## The steps of a plant's leaf-out in spring, from bare to full leaves.
const LEAF_OUT: Array[Look] = [Look.BARE, Look.BUDS, Look.YOUNG_LEAVES, Look.SPRING]

## Keeps the thresholds apart from other hashes of the same positions.
const SALT := 21


## What a day makes of a tile or plant: its look from its threshold by the season. Built once per
## refresh of the view (`conditions`), then asked for every tile and plant.
class Conditions:
	extends RefCounted
	## The shares of each blend window that have passed, per boundary in the order of
	## SeasonRules.BOUNDARIES.
	var ground: Array[float] = []
	var foliage: Array[float] = []
	## The share of the spring window that one plant takes to leaf out.
	var leaf_out_span := 1.0

	## The season's look of the grass on a roof (SPRING to BARE), by the roof's threshold.
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


func _init(world_seed: int, rules := SeasonRules.default_rules()) -> void:
	_world_seed = world_seed
	_rules = rules


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


## The fixed threshold of a tile or plant, in [0, 1): a hash of its position alone, held against
## the share of each blend window that has passed.
func season_threshold(pos: Vector2i) -> float:
	return PositionHash.of(pos, _world_seed + SALT) % 10000 / 10000.0
