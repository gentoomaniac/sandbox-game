class_name AnimalFollowing
extends RefCounted
## An animal that follows the player, as a dog does once given a bone (see Livestock): it keeps
## near them in play, and a skip puts it beside them. It keeps nothing: every function is given the
## animal and what it needs.

## An animal is put beside the player at the first of this many random spots that suits it.
const PLACE_TRIES := 40


## The animal follows the player from the game minute `now` (see GameClock `total_minutes`) for
## the `follow_minutes` of the rules.
static func start(animal: FarmAnimal, now: int, rules: LivestockRules) -> void:
	animal.follow_until_minute = now + int(rules.general("follow_minutes"))
	animal.follow_wait_seconds = 0.0


## Whether the animal follows the player at the game minute `now`. A player who is indoors
## (`player_feet` infinite) is not followed.
static func is_following(animal: FarmAnimal, now: int, player_feet: Vector2) -> bool:
	return now < animal.follow_until_minute and player_feet.is_finite()


## Keeps a follower near the player: it waits within `follow_far_tiles` of them, and once they are
## further off it walks after them (runs, when they are far) until it is `follow_near_tiles` from
## them. One that is left far behind is put beside them; one that is stuck behind something waits,
## facing them, and tries again later. `walk` is Livestock `_walk`.
static func follow(
	animal: FarmAnimal,
	delta: float,
	map: GameMap,
	player_feet: Vector2,
	rules: LivestockRules,
	rng: RandomNumberGenerator,
	walk: Callable
) -> void:
	var distance := animal.position.distance_to(player_feet)
	if distance > rules.general("follow_lost_tiles"):
		put_beside(animal, player_feet, map, rules, rng)
		return
	if animal.follow_wait_seconds > 0.0:
		animal.follow_wait_seconds -= delta
		AnimalMotion.face_towards(animal, player_feet.x)
		return
	AnimalMotion.note_progress(animal, rules)
	if AnimalMotion.is_blocked_too_long(animal, rules):
		# It cannot get to them: it waits, facing them, before it tries again.
		animal.stuck_seconds = 0.0
		animal.progress_anchor = Vector2.INF
		animal.activity = FarmAnimal.Activity.IDLE
		animal.follow_wait_seconds = rules.general("follow_retry_seconds")
		AnimalMotion.face_towards(animal, player_feet.x)
		return
	var is_on_its_way := animal.activity in [FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN]
	var stop_tiles := rules.general("follow_near_tiles" if is_on_its_way else "follow_far_tiles")
	if distance <= stop_tiles:
		animal.activity = FarmAnimal.Activity.IDLE
		animal.stuck_seconds = 0.0
		AnimalMotion.face_towards(animal, player_feet.x)
		return
	var is_far := distance > rules.general("follow_run_tiles")
	animal.activity = FarmAnimal.Activity.RUN if is_far else FarmAnimal.Activity.WALK
	var speed := rules.run_speed(animal.species) if is_far else rules.walk_speed(animal.species)
	walk.call(animal, (player_feet - animal.position).normalized(), speed, delta, map)


## Puts an animal beside the player, facing them, where the ground under its feet and its nose is
## walkable (as for a step, see AnimalMotion `walk`); it stays where it is if no such place is
## found. A skip does it to a follower, and play to one that is left far behind.
static func put_beside(
	animal: FarmAnimal,
	player_feet: Vector2,
	map: GameMap,
	rules: LivestockRules,
	rng: RandomNumberGenerator
) -> void:
	animal.stuck_seconds = 0.0
	animal.follow_wait_seconds = 0.0
	var distances := Vector2(rules.general("follow_near_tiles"), rules.general("follow_far_tiles"))
	for _try in PLACE_TRIES:
		var feet := AnimalMotion.point_around(player_feet, distances, rng)
		var facing := 1.0 if player_feet.x >= feet.x else -1.0
		var nose := feet + Vector2(facing * rules.body_tiles(animal.species), 0.0)
		if (
			map.is_walkable_for_animals(Vector2i(feet.floor()))
			and map.is_walkable_for_animals(Vector2i(nose.floor()))
		):
			animal.position = feet
			animal.facing = facing
			animal.last_step = Vector2.ZERO
			animal.activity = FarmAnimal.Activity.IDLE
			return
