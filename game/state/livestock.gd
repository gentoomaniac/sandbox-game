class_name Livestock
extends RefCounted
## The farm animals of the world (FarmAnimal) and how they go about their day: they stand idle,
## walk and graze, turn away from water and anything solid, and rabbits run from the player. At
## night they sleep where they are, from a while after sunset until about sunrise (each species
## has its hours, and each animal is a little later than the rest).
## GameState owns it and moves the animals with `update` while the player is out in the world.
##
## It does not know the world, so the two never hold each other: the map the animals walk on is
## given to each call that needs it.

## An animal came into the world.
signal added(animal: FarmAnimal)

## Spawned animals stand this many tiles from the given point, at the least and at the most.
const SPAWN_DISTANCE := Vector2(1.5, 4.0)
const SPAWN_TRIES := 40
## An animal whose way is blocked turns by this many radians, by more each time and to either
## side (TURN_STEPS), before it gives up and stands still.
const TURN := 0.6
const TURN_STEPS := [0, 1, -1, 2, -2, 3, -3]
## A long frame (a hitch) moves the animals no further than this many seconds would, so that
## a fast one never skips over a narrow ditch.
const MAX_STEP_SECONDS := 0.05

var rules := LivestockRules.default_rules()
var rng := RandomNumberGenerator.new()
var _sun: Sun
var _animals: Array[FarmAnimal] = []


## `sun` gives the times of sunrise and sunset that the animals sleep by.
func _init(sun: Sun) -> void:
	_sun = sun
	rng.randomize()


func all() -> Array[FarmAnimal]:
	return _animals.duplicate()


## Puts an animal into the world as it is, doing what it is doing.
func add(animal: FarmAnimal) -> void:
	animal.bedtime_delay = rng.randf() * rules.general("bedtime_spread_minutes")
	_animals.append(animal)
	added.emit(animal)


## Puts up to `count` new animals of a species on ground of `map` they can stand on, a few tiles
## around `near`. Returns how many found a place.
func spawn(species: StringName, count: int, near: Vector2, map: GameMap) -> int:
	var placed := 0
	for _try in SPAWN_TRIES:
		if placed == count:
			break
		var distance := rng.randf_range(SPAWN_DISTANCE.x, SPAWN_DISTANCE.y)
		var feet := near + Vector2.from_angle(rng.randf() * TAU) * distance
		if not map.is_walkable(Vector2i(feet.floor())):
			continue
		var animal := FarmAnimal.create(species, rng.randi(), feet, rules)
		animal.facing = 1.0 if rng.randf() < 0.5 else -1.0
		_start_next_activity(animal)
		add(animal)
		placed += 1
	return placed


## Lets `delta` seconds pass for every animal on `map` at a time of the game clock. The
## player's feet are where the rabbits run from.
func update(delta: float, map: GameMap, player_feet: Vector2, day: int, minute: int) -> void:
	delta = minf(delta, MAX_STEP_SECONDS)
	var sunrise := _sun.sunrise(day)
	var sunset := _sun.sunset(day)
	for animal in _animals:
		if _is_sleep_time(animal, minute, sunrise, sunset):
			animal.activity = FarmAnimal.Activity.SLEEP
		elif animal.activity == FarmAnimal.Activity.SLEEP:
			_start_activity(animal, FarmAnimal.Activity.IDLE)
		else:
			_update_awake_animal(animal, delta, map, player_feet)


## Whether an animal sleeps at a time of day: from `sleep_minutes` after sunset until
## `wake_minutes` after sunrise, both later by its `bedtime_delay`.
func is_sleep_time(animal: FarmAnimal, day: int, minute: int) -> bool:
	return _is_sleep_time(animal, minute, _sun.sunrise(day), _sun.sunset(day))


func _is_sleep_time(animal: FarmAnimal, minute: int, sunrise: float, sunset: float) -> bool:
	var delay := animal.bedtime_delay
	var bedtime := sunset + rules.sleep_minutes(animal.species) + delay
	var waking := sunrise + rules.wake_minutes(animal.species) + delay
	return minute >= bedtime or minute < waking


func _update_awake_animal(
	animal: FarmAnimal, delta: float, map: GameMap, player_feet: Vector2
) -> void:
	var flee_tiles := rules.flee_tiles(animal.species)
	var player_distance := animal.position.distance_to(player_feet)
	if flee_tiles > 0.0 and player_distance <= flee_tiles:
		animal.activity = FarmAnimal.Activity.FLEE
	match animal.activity:
		FarmAnimal.Activity.FLEE:
			if player_distance > flee_tiles + rules.general("calm_extra_tiles"):
				_start_next_activity(animal)
				return
			var away := animal.position - player_feet
			var direction := animal.heading if away.is_zero_approx() else away.normalized()
			_walk(animal, direction, rules.flee_speed(animal.species), delta, map)
		FarmAnimal.Activity.WALK:
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				_start_next_activity(animal)
			elif not _walk(animal, animal.heading, rules.walk_speed(animal.species), delta, map):
				_start_activity(animal, FarmAnimal.Activity.IDLE)
		_:
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				_start_next_activity(animal)


func _start_next_activity(animal: FarmAnimal) -> void:
	_start_activity(animal, rules.pick_activity(animal.species, rng))


func _start_activity(animal: FarmAnimal, activity: FarmAnimal.Activity) -> void:
	animal.activity = activity
	animal.seconds_left = rules.pick_seconds(animal.species, activity, rng)
	match activity:
		FarmAnimal.Activity.WALK:
			animal.heading = Vector2.from_angle(rng.randf() * TAU)
		FarmAnimal.Activity.IDLE:
			# Now and then it turns round where it stands.
			if rng.randf() < 0.3:
				animal.facing = -animal.facing


## Takes a step in `direction`, or as near to it as it can turn; returns whether it moved. The
## ground under its feet and under its nose (`body_tiles` ahead) must be walkable.
##
## Asking the map is what costs (several microseconds a tile), so a step the same way as the last
## that stays on the same tiles is taken without asking again.
func _walk(
	animal: FarmAnimal, direction: Vector2, speed: float, delta: float, map: GameMap
) -> bool:
	var reach := rules.body_tiles(animal.species)
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
		if is_same_ground or (map.is_walkable(feet_tile) and map.is_walkable(nose_tile)):
			animal.position = feet
			animal.heading = way
			animal.last_step = way
			if absf(way.x) > 0.1:
				animal.facing = signf(way.x)
			return true
	return false
