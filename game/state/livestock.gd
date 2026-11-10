class_name Livestock
extends RefCounted
## The farm animals of the world (FarmAnimal) and how they go about their day: they stand idle,
## walk, graze and run about, turn away from water and anything solid, and rabbits run from the
## player. At night they sleep where they are, from a while after sunset until about sunrise
## (each species has its hours, and each animal is a little later than the rest). A dog given a
## bone follows the player for a while instead, day and night. A horse the player rides does
## nothing of its own: it goes where they ride it. A cat hunts the mice it is shown (see
## `start_hunt`).
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
## The wear an animal's hooves or feet leave on each tile they walk onto, so a herd makes
## tracks (see data/paths.cfg).
var _animal_step := PathRules.default_rules().animal_step()
var _sun: Sun
var _animals: Array[FarmAnimal] = []


## `sun` gives the times of sunrise and sunset that the animals sleep by.
func _init(sun: Sun) -> void:
	_sun = sun
	rng.randomize()


func all() -> Array[FarmAnimal]:
	return _animals.duplicate()


## Puts an animal into the world as it is, doing what it is doing. How much later than its
## species it goes to bed follows from what it is and its place in the herd, so that the same
## saved game has the same animals going to bed at the same times.
func add(animal: FarmAnimal) -> void:
	# (An API that removes animals would need the delay saved, or a stable id of the animal.)
	var identity := hash([animal.species, animal.look, animal.tint.to_html(), _animals.size()])
	animal.bedtime_delay = (
		float(identity % 1000) / 1000.0 * rules.general("bedtime_spread_minutes")
	)
	_animals.append(animal)
	added.emit(animal)


func to_array() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for animal in _animals:
		data.append(animal.to_dict())
	return data


func load_array(data: Array) -> void:
	for animal_data: Dictionary in data:
		add(FarmAnimal.from_dict(animal_data, rules))


## Puts up to `count` new animals of a species on ground of `map` they can stand on, a few tiles
## around `near`. Returns how many found a place.
func spawn(species: StringName, count: int, near: Vector2, map: GameMap) -> int:
	var placed := 0
	for _try in SPAWN_TRIES:
		if placed == count:
			break
		var feet := _point_around(near, SPAWN_DISTANCE)
		if not map.is_walkable(Vector2i(feet.floor())):
			continue
		var animal := FarmAnimal.create(species, rng.randi(), feet, rules)
		animal.facing = 1.0 if rng.randf() < 0.5 else -1.0
		_start_next_activity(animal)
		add(animal)
		placed += 1
	return placed


## The animal of a species nearest to `point` within `reach` tiles (from its feet), or null.
func nearest(species: StringName, point: Vector2, reach: float) -> FarmAnimal:
	var found: FarmAnimal = null
	var found_distance := reach
	for animal in _animals:
		var distance := animal.position.distance_to(point)
		if animal.species == species and distance <= found_distance:
			found = animal
			found_distance = distance
	return found


## The animal follows the player from the game minute `now` (see GameClock `total_minutes`) for
## the `follow_minutes` of the rules.
func start_following(animal: FarmAnimal, now: int) -> void:
	animal.follow_until_minute = now + int(rules.general("follow_minutes"))


## The animal stands where it is, as one that has just been let go of (the player got off the
## horse), until it picks what to do next.
func stand_still(animal: FarmAnimal) -> void:
	_start_activity(animal, FarmAnimal.Activity.IDLE)
	animal.last_step = Vector2.ZERO


## Whether an animal would hunt a mouse now: a cat that is up and about, rested since its last
## hunt. The mice are the wildlife's, so the WildlifeView finds one for it (see FarmAnimalView).
func can_hunt(animal: FarmAnimal) -> bool:
	return (
		animal.species == LivestockRules.CAT
		and animal.activity in LivestockRules.CHOSEN_ACTIVITIES
		and animal.hunt_rest_seconds <= 0.0
	)


## The cat starts to hunt a mouse at `prey` (in tiles): it crouches facing it, creeps up on it
## and pounces from `pounce_tiles`. Then it rests for `rest_seconds`.
func start_hunt(animal: FarmAnimal, prey: Vector2) -> void:
	animal.activity = FarmAnimal.Activity.CROUCH
	animal.seconds_left = rules.hunting("crouch_seconds")
	track_prey(animal, prey)


## The mouse the cat crouches at or creeps up on is at `prey` now. A pounce goes where the mouse
## was when the cat leapt.
func track_prey(animal: FarmAnimal, prey: Vector2) -> void:
	if animal.activity in [FarmAnimal.Activity.CROUCH, FarmAnimal.Activity.CREEP]:
		animal.prey = prey
		if absf(prey.x - animal.position.x) > 0.1:
			animal.facing = signf(prey.x - animal.position.x)


## The cat gives up its hunt before it pounces: the mouse is gone.
func stop_hunt(animal: FarmAnimal) -> void:
	if animal.activity in [FarmAnimal.Activity.CROUCH, FarmAnimal.Activity.CREEP]:
		_end_hunt(animal)


## Lets `delta` seconds pass for every animal on `map` at the time of the game clock (only those
## in loaded chunks with `only_loaded`). The player's feet are where the rabbits run from and the
## followers go.
func update(
	delta: float, map: GameMap, player_feet: Vector2, clock: GameClock, only_loaded := false
) -> void:
	delta = minf(delta, MAX_STEP_SECONDS)
	var minute := clock.minute_of_day
	var now := clock.total_minutes()
	var sunrise := _sun.sunrise(clock.day)
	var sunset := _sun.sunset(clock.day)
	for animal in _animals:
		if animal.is_ridden or (only_loaded and not _is_in_loaded_chunk(animal, map)):
			continue
		# A player who is indoors (`player_feet` infinite) is not followed.
		if now < animal.follow_until_minute and player_feet.is_finite():
			_follow(animal, delta, map, player_feet)
		elif _is_sleep_time(animal, minute, sunrise, sunset):
			animal.activity = FarmAnimal.Activity.SLEEP
		elif animal.activity == FarmAnimal.Activity.SLEEP:
			_start_activity(animal, FarmAnimal.Activity.IDLE)
		else:
			_update_awake_animal(animal, delta, map, player_feet)


## Puts the animals where time that was skipped (see Simulation `skip`) has left them, at the
## time of the game clock: each animal in a loaded chunk is up to `catch_up_wander_tiles` from
## where it was, on a tile it could have walked to, and sleeping or doing something new as the hour
## has it. A follower is put beside the player, and the horse that is ridden stays with them; a
## player who is indoors (`player_feet` infinite) is not followed, and the follower is caught up
## like the others. The dice are thrown from `seed_value`.
func catch_up(map: GameMap, clock: GameClock, player_feet: Vector2, seed_value: int) -> void:
	rng.seed = seed_value
	var sunrise := _sun.sunrise(clock.day)
	var sunset := _sun.sunset(clock.day)
	for animal in _animals:
		if animal.is_ridden or not _is_in_loaded_chunk(animal, map):
			continue
		animal.hunt_rest_seconds = 0.0
		if clock.total_minutes() < animal.follow_until_minute and player_feet.is_finite():
			_put_beside(animal, player_feet, map)
			continue
		_wander_off(animal, map)
		if _is_sleep_time(animal, clock.minute_of_day, sunrise, sunset):
			animal.activity = FarmAnimal.Activity.SLEEP
		else:
			# The heading it was left with is one its nose is clear on; a new activity picks its
			# own, which a step turns away from ground it cannot walk on.
			var heading := animal.heading
			_start_next_activity(animal)
			animal.heading = heading


## Whether the chunk an animal stands in is loaded: the world beyond it is not there to walk on.
func _is_in_loaded_chunk(animal: FarmAnimal, map: GameMap) -> bool:
	return not map is World or (map as World).is_chunk_loaded(Chunk.world_to_chunk(animal.tile()))


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
	animal.hunt_rest_seconds = maxf(0.0, animal.hunt_rest_seconds - delta)
	match animal.activity:
		FarmAnimal.Activity.CROUCH:
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				animal.activity = FarmAnimal.Activity.CREEP
				animal.seconds_left = rules.hunting("give_up_seconds")
		FarmAnimal.Activity.CREEP:
			_creep(animal, delta, map)
		FarmAnimal.Activity.POUNCE:
			_pounce(animal, delta, map)
		FarmAnimal.Activity.FLEE:
			if player_distance > flee_tiles + rules.general("calm_extra_tiles"):
				_start_next_activity(animal)
				return
			var away := animal.position - player_feet
			var direction := animal.heading if away.is_zero_approx() else away.normalized()
			_walk(animal, direction, rules.run_speed(animal.species), delta, map)
		FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN:
			var speed := (
				rules.walk_speed(animal.species)
				if animal.activity == FarmAnimal.Activity.WALK
				else rules.run_speed(animal.species)
			)
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				_start_next_activity(animal)
			elif not _walk(animal, animal.heading, speed, delta, map):
				_start_activity(animal, FarmAnimal.Activity.IDLE)
		_:
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				_start_next_activity(animal)


## Creeps up on the mouse until it is near enough to pounce; gives up when it takes too long or
## the way is blocked.
func _creep(animal: FarmAnimal, delta: float, map: GameMap) -> void:
	animal.seconds_left -= delta
	var to_prey := animal.prey - animal.position
	if to_prey.length() <= rules.hunting("pounce_tiles"):
		animal.activity = FarmAnimal.Activity.POUNCE
	elif (
		animal.seconds_left <= 0.0
		or not _walk(animal, to_prey.normalized(), rules.hunting("creep_speed"), delta, map)
	):
		_end_hunt(animal)


## Leaps at where the mouse was when it pounced, and lands there; a leap that is blocked ends
## short of it.
func _pounce(animal: FarmAnimal, delta: float, map: GameMap) -> void:
	var speed := rules.hunting("pounce_speed")
	var to_prey := animal.prey - animal.position
	if to_prey.length() <= speed * delta:
		animal.position = animal.prey
		_end_hunt(animal)
	elif not _walk(animal, to_prey.normalized(), speed, delta, map):
		_end_hunt(animal)


func _end_hunt(animal: FarmAnimal) -> void:
	animal.hunt_rest_seconds = rules.hunting("rest_seconds")
	_start_activity(animal, FarmAnimal.Activity.IDLE)


## Keeps a follower near the player: it waits within `follow_far_tiles` of them, and once they are
## further off it walks after them (runs, when they are far) until it is `follow_near_tiles` from
## them. One that is left far behind, or is stuck behind something, is put beside them.
func _follow(animal: FarmAnimal, delta: float, map: GameMap, player_feet: Vector2) -> void:
	var distance := animal.position.distance_to(player_feet)
	if (
		distance > rules.general("follow_lost_tiles")
		or animal.stuck_seconds > rules.general("follow_stuck_seconds")
	):
		_put_beside(animal, player_feet, map)
		return
	var is_on_its_way := animal.activity in [FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN]
	var stop_tiles := rules.general("follow_near_tiles" if is_on_its_way else "follow_far_tiles")
	if distance <= stop_tiles:
		animal.activity = FarmAnimal.Activity.IDLE
		animal.stuck_seconds = 0.0
		if absf(player_feet.x - animal.position.x) > 0.1:
			animal.facing = signf(player_feet.x - animal.position.x)
		return
	var is_far := distance > rules.general("follow_run_tiles")
	animal.activity = FarmAnimal.Activity.RUN if is_far else FarmAnimal.Activity.WALK
	var speed := rules.run_speed(animal.species) if is_far else rules.walk_speed(animal.species)
	var toward := (player_feet - animal.position).normalized()
	if _walk(animal, toward, speed, delta, map):
		animal.stuck_seconds = 0.0
	else:
		animal.stuck_seconds += delta


## Puts an animal beside the player, facing them, where the ground under its feet and its nose is
## walkable (as for a step, see `_walk`); it stays where it is if no such place is found.
func _put_beside(animal: FarmAnimal, player_feet: Vector2, map: GameMap) -> void:
	animal.stuck_seconds = 0.0
	var distances := Vector2(rules.general("follow_near_tiles"), rules.general("follow_far_tiles"))
	for _try in SPAWN_TRIES:
		var feet := _point_around(player_feet, distances)
		var facing := 1.0 if player_feet.x >= feet.x else -1.0
		var nose := feet + Vector2(facing * rules.body_tiles(animal.species), 0.0)
		if map.is_walkable(Vector2i(feet.floor())) and map.is_walkable(Vector2i(nose.floor())):
			animal.position = feet
			animal.facing = facing
			animal.last_step = Vector2.ZERO
			animal.activity = FarmAnimal.Activity.IDLE
			return


## A point in a random direction from `near`, between `distances.x` and `distances.y` tiles away.
func _point_around(near: Vector2, distances: Vector2) -> Vector2:
	var distance := rng.randf_range(distances.x, distances.y)
	return near + Vector2.from_angle(rng.randf() * TAU) * distance


## Moves the animal to a random spot on a tile within `catch_up_wander_tiles` that it could have
## walked to (see ReachableTiles), standing as a step would leave it: feet and nose (a way it
## faces) on walkable ground. It stays where it is if five spots have no such way.
func _wander_off(animal: FarmAnimal, map: GameMap) -> void:
	var reach := rules.body_tiles(animal.species)
	var tiles := ReachableTiles.within(
		animal.tile(), rules.general("catch_up_wander_tiles"), map.is_walkable
	)
	for _spot in 5:
		var tile := tiles[rng.randi() % tiles.size()]
		var feet := Vector2(tile) + Vector2(rng.randf(), rng.randf())
		for _try in 5:
			var way := Vector2.from_angle(rng.randf() * TAU)
			if map.is_walkable(Vector2i((feet + way * reach).floor())):
				animal.position = feet
				animal.heading = way
				animal.facing = signf(way.x) if absf(way.x) > 0.1 else animal.facing
				animal.last_step = Vector2.ZERO
				return


func _start_next_activity(animal: FarmAnimal) -> void:
	_start_activity(animal, rules.pick_activity(animal.species, rng))


func _start_activity(animal: FarmAnimal, activity: FarmAnimal.Activity) -> void:
	animal.activity = activity
	animal.seconds_left = rules.pick_seconds(animal.species, activity, rng)
	match activity:
		FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN:
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
			if feet_tile != animal.tile() and map is World and _animal_step > 0.0:
				(map as World).wear_tile(feet_tile, _animal_step)
			animal.position = feet
			animal.heading = way
			animal.last_step = way
			if absf(way.x) > 0.1:
				animal.facing = signf(way.x)
			return true
	return false
