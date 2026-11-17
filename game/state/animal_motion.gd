class_name AnimalMotion
extends RefCounted
## How a farm animal moves, in play and in a skip (see Livestock): starting an activity, a step
## that turns away from what blocks it, whether it is getting anywhere, and where a skip leaves it
## (`wander_off`). It keeps nothing: every function is given the animal and what it needs.

## An animal whose way is blocked turns by this many radians, by more each time and to either
## side (TURN_STEPS), before it gives up and stands still.
const TURN := 0.6
const TURN_STEPS := [0, 1, -1, 2, -2, 3, -3]
## An animal that walks to its goal has come to it within this many tiles beyond a step.
const GOAL_REACHED_TILES := 0.05


## Starts an activity: how long it lasts, which way a walk or a run goes, whether an idle animal
## turns round where it stands.
static func start_activity(
	animal: FarmAnimal,
	activity: FarmAnimal.Activity,
	rules: LivestockRules,
	rng: RandomNumberGenerator
) -> void:
	animal.activity = activity
	animal.stuck_seconds = 0.0
	animal.progress_anchor = Vector2.INF
	animal.seconds_left = rules.pick_seconds(animal.species, activity, rng)
	match activity:
		FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN:
			animal.heading = Vector2.from_angle(rng.randf() * TAU)
		FarmAnimal.Activity.IDLE:
			# Now and then it turns round where it stands.
			if rng.randf() < 0.3:
				animal.facing = -animal.facing


## Takes a step in `direction`, or as near to it as it can turn; returns whether it moved. Every
## step that is not straight, and every one it cannot take, adds to its `stuck_seconds` (see
## `note_progress`, which restarts it). It turns to face a way it only found by turning round
## something no more often than `turn_hold_seconds`, or it would spin left and right at a fence.
## The ground under its feet and under its nose (`body_tiles` ahead) must be walkable for animals,
## or be the tile it stands on if anyone could walk there. `animal_step` is the wear it leaves on
## each tile it walks onto.
##
## Asking the map is what costs (several microseconds a tile), so a step the same way as the last
## that stays on the same tiles is taken without asking again.
static func walk(
	animal: FarmAnimal,
	direction: Vector2,
	speed: float,
	delta: float,
	map: GameMap,
	rules: LivestockRules,
	animal_step: float
) -> bool:
	var reach := rules.body_tiles(animal.species)
	var here := animal.tile()
	animal.turn_hold_seconds = maxf(0.0, animal.turn_hold_seconds - delta)
	for steps: int in TURN_STEPS:
		var way := direction.rotated(steps * TURN)
		var feet := animal.position + way * speed * delta
		var feet_tile := Vector2i(feet.floor())
		var nose_tile := Vector2i((feet + way * reach).floor())
		var is_same_ground := (
			way == animal.last_step
			and feet_tile == animal.tile()
			and nose_tile == Vector2i((animal.position + way * reach).floor())
		)
		# What stops animals and was put under its feet does not trap it: it may step off. Nor does
		# the rising tide: standing in the flooded mud, it may wade on over it.
		var is_wading := map.is_wadeable(here)
		var can_step := (
			(
				map.is_walkable_for_animals(feet_tile)
				or feet_tile == here and map.is_walkable(here)
				or is_wading and map.is_wadeable(feet_tile)
			)
			and (
				map.is_walkable_for_animals(nose_tile)
				or nose_tile == here and map.is_walkable(here)
				or is_wading and map.is_wadeable(nose_tile)
			)
		)
		if is_same_ground or can_step:
			if feet_tile != animal.tile() and map is World and animal_step > 0.0:
				(map as World).wear_tile(feet_tile, animal_step)
			animal.position = feet
			animal.last_step = way
			if steps == 0:
				animal.heading = way
			else:
				animal.stuck_seconds += delta
			if absf(way.x) > 0.1 and (steps == 0 or animal.turn_hold_seconds <= 0.0):
				_turn_to(animal, signf(way.x), rules)
			return true
	animal.stuck_seconds += delta
	return false


## Turns the animal to face `facing`, and holds that facing for `turn_hold_seconds`: a step round
## something does not turn it back before then (see `walk`).
static func _turn_to(animal: FarmAnimal, facing: float, rules: LivestockRules) -> void:
	if facing != animal.facing:
		animal.facing = facing
		animal.turn_hold_seconds = rules.general("turn_hold_seconds")


static func face_towards(animal: FarmAnimal, x: float) -> void:
	if absf(x - animal.position.x) > 0.1:
		animal.facing = signf(x - animal.position.x)


## An animal that has moved `progress_tiles` from where it last counted is getting somewhere, going
## round whatever is in its way however long that takes: it is not stuck. One that only shuffles
## to and fro at the obstacle is.
static func note_progress(animal: FarmAnimal, rules: LivestockRules) -> void:
	if animal.position.distance_to(animal.progress_anchor) > rules.general("progress_tiles"):
		animal.progress_anchor = animal.position
		animal.stuck_seconds = 0.0


## Whether the animal has had no free way ahead, and made no progress, for so long that it gives up
## where it was going.
static func is_blocked_too_long(animal: FarmAnimal, rules: LivestockRules) -> bool:
	return animal.stuck_seconds > rules.general("blocked_give_up_seconds")


## A point in a random direction from `near`, between `distances.x` and `distances.y` tiles away.
static func point_around(near: Vector2, distances: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var distance := rng.randf_range(distances.x, distances.y)
	return near + Vector2.from_angle(rng.randf() * TAU) * distance


## A skip's end for an animal that moves about: it is put on a random spot on a tile within
## `catch_up_wander_tiles` that it could have walked to (see ReachableTiles), standing as a step
## would leave it: feet and nose (a way it faces) on walkable ground, and never on a building. It
## stays where it is if five spots have no such way.
static func wander_off(
	animal: FarmAnimal, map: GameMap, rules: LivestockRules, rng: RandomNumberGenerator
) -> void:
	var reach := rules.body_tiles(animal.species)
	var tiles := ReachableTiles.within(
		animal.tile(), rules.general("catch_up_wander_tiles"), map.is_walkable_for_animals
	)
	for _spot in 5:
		var tile := tiles[rng.randi() % tiles.size()]
		if not map.is_walkable_for_animals(tile):
			continue
		var feet := Vector2(tile) + Vector2(rng.randf(), rng.randf())
		for _try in 5:
			var way := Vector2.from_angle(rng.randf() * TAU)
			if map.is_walkable_for_animals(Vector2i((feet + way * reach).floor())):
				animal.position = feet
				animal.heading = way
				animal.facing = signf(way.x) if absf(way.x) > 0.1 else animal.facing
				animal.last_step = Vector2.ZERO
				return
