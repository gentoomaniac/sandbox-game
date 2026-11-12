# gdlint: disable=max-public-methods
class_name Livestock
extends RefCounted
## The farm animals of the world (FarmAnimal) and how they go about their day: they stand idle,
## walk, graze and run about, turn away from water, anything solid and what stops animals (see
## GameMap `is_walkable_for_animals`), and rabbits run from the player. At night they sleep where
## they are, from a while after sunset until about sunrise (each species has its hours, and each
## animal is a little later than the rest). A dog given a bone follows the player for a while
## instead, day and night. A horse the player rides does nothing of its own: it goes where they ride
## it. A cat hunts the mice that report themselves (see `add_prey`): it looks for one when it picks
## what to do next, and the whole hunt is decided here, with no view needed.
## GameState owns it and moves the animals with `update` while the player is out in the world.
##
## It does not know the world, so the two never hold each other: the map the animals walk on is
## given to each call that needs it.

## An animal came into the world.
signal added(animal: FarmAnimal)
## An animal left the world for good (see `remove_species`); whoever shows it stops.
signal removed(animal: FarmAnimal)
## An animal was petted and shows what `pet` returned (a heart or the anger mark, never nothing).
signal petted(animal: FarmAnimal, shows: PetShows)

## What petting an animal shows over its head: nothing, a heart (the first petting of a day while it
## is awake) or the anger mark (the first while it sleeps).
enum PetShows { NOTHING, HEART, ANNOYED }

## Spawned animals stand this many tiles from the given point, at the least and at the most.
const SPAWN_DISTANCE := Vector2(1.5, 4.0)
const SPAWN_TRIES := 40
## An animal whose way is blocked turns by this many radians, by more each time and to either
## side (TURN_STEPS), before it gives up and stands still.
const TURN := 0.6
const TURN_STEPS := [0, 1, -1, 2, -2, 3, -3]
## An animal that walks to its goal has come to it within this many tiles beyond a step.
const GOAL_REACHED_TILES := 0.05
## A long frame (a hitch) moves the animals no further than this many seconds would, so that
## a fast one never skips over a narrow ditch.
const MAX_STEP_SECONDS := 0.05

## What a cat does from the start of a hunt to the landing of its pounce.
const HUNT_ACTIVITIES: Array[FarmAnimal.Activity] = [
	FarmAnimal.Activity.CROUCH, FarmAnimal.Activity.CREEP, FarmAnimal.Activity.POUNCE
]

var rules := LivestockRules.default_rules()
## What the animals need and how much of it a meal or a drink takes (see YardRules).
var yard := YardRules.default_rules()
## How many searches (flood fills of the ground round an animal) have been made, for the tests.
var search_count := 0
var rng := RandomNumberGenerator.new()
## The cheats of the session: with `are_needs_off` the needs do not rise.
var cheats: CheatFlags
## The wear an animal's hooves or feet leave on each tile they walk onto, so a herd makes
## tracks (see data/paths.cfg).
var _animal_step := PathRules.default_rules().animal_step()
var _sun: Sun
var _animals: Array[FarmAnimal] = []
## The game minute the needs of the animals were last brought up to (see `account_needs`), or -1.
var _needs_minute := -1
## The game day the friendship of the animals was last brought up to (see `account_friendship`), or
## 0 before the first time.
var _friendship_day := 0
## How many more searches for water, feed or a coop an `update` may make (see [needs]
## `searches_per_update`): each is a flood fill of the ground around an animal.
var _searches_left := 0
## The roosts of each coop (by its origin) that hens settled in this skip have used up and are not
## in now, because the skip ended in the morning. Only for the length of one catch-up.
var _roost_taken := {}
var _mice: Array[Prey] = []


## `sun` gives the times of sunrise and sunset that the animals sleep by.
func _init(sun: Sun, cheat_flags := CheatFlags.new()) -> void:
	_sun = sun
	cheats = cheat_flags
	rng.randomize()


func all() -> Array[FarmAnimal]:
	return _animals.duplicate()


## Puts an animal into the world as it is, doing what it is doing. How much later than its
## species it goes to bed follows from what it is and its place in the herd, so that the same
## saved game has the same animals going to bed at the same times.
func add(animal: FarmAnimal) -> void:
	# (The delay follows from the animal's place in the herd, so after `remove_species` and a reload
	# the animals that were behind the removed ones go to bed a little differently.)
	var identity := hash([animal.species, animal.look, animal.tint.to_html(), _animals.size()])
	animal.bedtime_delay = (
		float(identity % 1000) / 1000.0 * rules.general("bedtime_spread_minutes")
	)
	_animals.append(animal)
	added.emit(animal)


## Takes every animal of a species out of the world, and so out of the next save. Returns how many.
## The player riding a horse is not Livestock's to undo: GameState `dismount` comes first.
func remove_species(species: StringName) -> int:
	var gone: Array[FarmAnimal] = []
	var staying: Array[FarmAnimal] = []
	for animal in _animals:
		(gone if animal.species == species else staying).append(animal)
	_animals = staying
	for animal in gone:
		removed.emit(animal)
	return gone.size()


func to_array() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for animal in _animals:
		data.append(animal.to_dict())
	return data


func load_array(data: Array) -> void:
	for animal_data: Dictionary in data:
		add(FarmAnimal.from_dict(animal_data, rules))


## Puts up to `count` new animals of a species on ground of `map` they can stand on, a few tiles
## around `near`, all of one `look` if given (else each of a look drawn by the species' weights).
## Returns how many found a place.
func spawn(species: StringName, count: int, near: Vector2, map: GameMap, look := &"") -> int:
	var placed := 0
	for _try in SPAWN_TRIES:
		if placed == count:
			break
		var feet := _point_around(near, SPAWN_DISTANCE)
		if not map.is_walkable_for_animals(Vector2i(feet.floor())):
			continue
		var animal := FarmAnimal.create(species, rng.randi(), feet, rules)
		if look != &"":
			animal.look = look
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


## The animal that can be petted nearest to `point` within `reach` tiles (from its feet), or null.
## A hen in a coop is not seen, nor is a ridden horse touched.
func nearest_pettable(point: Vector2, reach: float) -> FarmAnimal:
	var found: FarmAnimal = null
	var found_distance := reach
	for animal in _animals:
		var distance := animal.position.distance_to(point)
		var is_reachable := rules.is_pettable(animal.species) and not animal.is_housed
		if is_reachable and not animal.is_ridden and distance <= found_distance:
			found = animal
			found_distance = distance
	return found


## The player pets the animal on the day of the game clock, and what that shows is returned (and
## told by `petted`). Awake, the first petting of a day adds `pet_gain` to its friendship (up to
## `max`) and shows a heart; asleep, the first of a day takes `sleep_pet_loss` (down to 0) and
## shows the anger mark and does not count as the day's petting. Any other petting does nothing.
func pet(animal: FarmAnimal, clock: GameClock) -> PetShows:
	# The days that ended before today are counted first: they need the day it was last petted.
	account_friendship(clock)
	var shows := PetShows.NOTHING
	if animal.activity == FarmAnimal.Activity.SLEEP:
		if animal.last_petted_asleep_day != clock.day:
			animal.last_petted_asleep_day = clock.day
			animal.friendship = maxi(0, animal.friendship - rules.friendship("sleep_pet_loss"))
			shows = PetShows.ANNOYED
	elif animal.last_petted_day != clock.day:
		animal.last_petted_day = clock.day
		animal.friendship = mini(
			rules.friendship("max"), animal.friendship + rules.friendship("pet_gain")
		)
		shows = PetShows.HEART
	if shows != PetShows.NOTHING:
		petted.emit(animal, shows)
	return shows


## The animal follows the player from the game minute `now` (see GameClock `total_minutes`) for
## the `follow_minutes` of the rules.
func start_following(animal: FarmAnimal, now: int) -> void:
	animal.follow_until_minute = now + int(rules.general("follow_minutes"))


## The animal stands where it is, as one that has just been let go of (the player got off the
## horse), until it picks what to do next.
func stand_still(animal: FarmAnimal) -> void:
	_start_activity(animal, FarmAnimal.Activity.IDLE)
	animal.last_step = Vector2.ZERO


## A mouse is about for the cats to hunt. Whoever shows it keeps its Prey up to date, and sets it
## no longer about once the mouse is gone; with no mouse about no cat hunts.
func add_prey(mouse: Prey) -> void:
	_mice.assign(_mice.filter(func(known: Prey) -> bool: return known.is_about))
	_mice.append(mouse)


## Whether an animal would hunt a mouse now: a cat that is up and about, rested since its last
## hunt.
func can_hunt(animal: FarmAnimal) -> bool:
	return (
		animal.species == LivestockRules.CAT
		and animal.activity in LivestockRules.CHOSEN_ACTIVITIES
		and animal.hunt_rest_seconds <= 0.0
	)


## The cat starts to hunt a mouse: it crouches facing it, creeps up on it and pounces from
## `pounce_tiles`. The mouse sees the pounce coming and dashes off, or is caught where the cat
## lands (`catch_chance`). A mouse that is gone before the pounce ends the hunt. Then the cat
## rests for `rest_seconds`.
func start_hunt(animal: FarmAnimal, mouse: Prey) -> void:
	animal.activity = FarmAnimal.Activity.CROUCH
	animal.seconds_left = rules.hunting("crouch_seconds")
	animal.hunted = mouse
	_track_prey(animal)


## Lets `delta` seconds pass for every animal on `map` at the time of the game clock (only those
## in loaded chunks with `only_loaded`). The player's feet are where the rabbits run from and the
## followers go. Time that is skipped (the minutes of a skip that are walked through) is played with
## `may_hunt` off: no cat looks for a mouse, and a hunt in progress is given up with no outcome.
func update(
	delta: float,
	map: GameMap,
	player_feet: Vector2,
	clock: GameClock,
	only_loaded := false,
	may_hunt := true
) -> void:
	delta = minf(delta, MAX_STEP_SECONDS)
	var minute := clock.minute_of_day
	var now := clock.total_minutes()
	var sunrise := _sun.sunrise(clock.day)
	var sunset := _sun.sunset(clock.day)
	account_clock(clock)
	_searches_left = int(yard.needs("searches_per_update"))
	for animal in _animals:
		if animal.is_ridden or (only_loaded and not _is_in_loaded_chunk(animal, map)):
			continue
		if not may_hunt:
			_abandon_hunt(animal)
		animal.search_seconds = maxf(0.0, animal.search_seconds - delta)
		if animal.species == LivestockRules.CHICKEN and map is World:
			animal.is_housed = Coop.housing(map as World, animal.tile(), yard) != null
		# A player who is indoors (`player_feet` infinite) is not followed.
		if now < animal.follow_until_minute and player_feet.is_finite():
			animal.goal = Vector2.INF
			_follow(animal, delta, map, player_feet)
		elif _is_sleep_time(animal, minute, sunrise, sunset):
			_go_to_sleep(animal, delta, map, may_hunt)
		elif animal.is_housed:
			_leave_coop(animal, map)
		elif animal.activity == FarmAnimal.Activity.SLEEP:
			_start_activity(animal, FarmAnimal.Activity.IDLE, may_hunt)
		else:
			if animal.goal_need == Coop.ROOST:
				animal.goal = Vector2.INF
			_update_awake_animal(animal, delta, map, player_feet, may_hunt)


## Puts the animals where time that was skipped (see Simulation `skip`) has left them, at the
## time of the game clock: each animal in a loaded chunk is up to `catch_up_wander_tiles` from
## where it was, on a tile it could have walked to, and sleeping or doing something new as the hour
## has it. A follower is put beside the player, and the horse that is ridden stays with them; a
## player who is indoors (`player_feet` infinite) is not followed, and the follower is caught up
## like the others. The dice are thrown from `seed_value`. The needs have risen with the clock, and
## an animal that could reach what it needs has met it somewhere in the `minutes` (see
## `_meet_needs_in_skip`).
func catch_up(
	map: GameMap, clock: GameClock, player_feet: Vector2, seed_value: int, minutes := 0
) -> void:
	_begin_catch_up(clock, seed_value)
	for animal in _animals:
		_catch_up_one(animal, map, clock, player_feet, minutes)
	_roost_taken.clear()


## The same, spread over frames: every animal after `Simulation.frame_budget_usec` of a frame is
## left to the next one (`next_frame` gives the signal of it), in the order of `catch_up`, so the
## dice give the same result.
func catch_up_over_frames(
	map: GameMap,
	clock: GameClock,
	player_feet: Vector2,
	seed_value: int,
	minutes: int,
	next_frame: Callable
) -> void:
	_begin_catch_up(clock, seed_value)
	var frame_started := Time.get_ticks_usec()
	for animal in _animals:
		if Time.get_ticks_usec() - frame_started > Simulation.frame_budget_usec:
			await next_frame.call()
			frame_started = Time.get_ticks_usec()
		_catch_up_one(animal, map, clock, player_feet, minutes)
	_roost_taken.clear()


func _begin_catch_up(clock: GameClock, seed_value: int) -> void:
	rng.seed = seed_value
	account_clock(clock)


func _catch_up_one(
	animal: FarmAnimal, map: GameMap, clock: GameClock, player_feet: Vector2, minutes: int
) -> void:
	if animal.is_ridden or not _is_in_loaded_chunk(animal, map):
		return
	_abandon_hunt(animal)
	animal.hunt_rest_seconds = 0.0
	animal.goal = Vector2.INF
	animal.search_seconds = 0.0
	animal.missed_roost = false
	if clock.total_minutes() < animal.follow_until_minute and player_feet.is_finite():
		_put_beside(animal, player_feet, map)
		return
	if (
		animal.species == LivestockRules.CHICKEN
		and _settle_hen_in_skip(animal, map, clock, minutes)
	):
		return
	_wander_off(animal, map)
	_meet_needs_in_skip(animal, map, minutes)
	var is_asleep := _is_sleep_time(
		animal, clock.minute_of_day, _sun.sunrise(clock.day), _sun.sunset(clock.day)
	)
	if is_asleep:
		animal.activity = FarmAnimal.Activity.SLEEP
	else:
		# The heading it was left with is one its nose is clear on; a new activity picks its
		# own, which a step turns away from ground it cannot walk on.
		var heading := animal.heading
		_start_next_activity(animal)
		animal.heading = heading


## A hen in a skip of `minutes` that ends at the time of `clock`. If she is in a coop or could walk
## to one with a free roost (see `Coop.nearest_free`) she laid an egg in it (by `egg_chance`) for
## each bedtime of hers since the skip began, the walked minutes before it included (no hen goes to
## a coop while they are walked), met her needs from its front like the others, and is in it if it
## is time to sleep, else she has come out in front of its door. Returns whether she was settled so
## (one with no coop is left to the others' rules).
func _settle_hen_in_skip(hen: FarmAnimal, map: GameMap, clock: GameClock, minutes: int) -> bool:
	if not map is World:
		return false
	var world := map as World
	var coop := Coop.housing(world, hen.tile(), yard)
	hen.is_housed = coop != null
	if coop == null:
		coop = _reachable_free_coop(hen, world)
	if coop == null:
		return false
	var now := clock.total_minutes()
	var from := now - minutes - Simulation.WALKED_MINUTES
	for _night in _bedtimes_between(hen, from, now):
		Coop.lay_egg(coop, yard, rng)
	hen.position = Coop.door_front(coop)
	hen.is_housed = false
	_meet_needs_in_skip(hen, map, minutes)
	hen.goal = Vector2.INF
	var is_asleep := _is_sleep_time(
		hen, clock.minute_of_day, _sun.sunrise(clock.day), _sun.sunset(clock.day)
	)
	if is_asleep:
		hen.position = Coop.roost_spot(coop)
		hen.is_housed = true
		hen.activity = FarmAnimal.Activity.SLEEP
	else:
		# The night took a roost that nobody is in now.
		_roost_taken[coop.origin] = int(_roost_taken.get(coop.origin, 0)) + 1
		_start_activity(hen, FarmAnimal.Activity.IDLE)
	return true


## The coop with a free roost nearest to the hen that she can walk to (see `Coop.nearest_free`), or
## null. It costs a flood fill of the ground round her.
func _reachable_free_coop(hen: FarmAnimal, world: World) -> Building:
	_searches_left -= 1
	search_count += 1
	var reach := {}
	for tile in ReachableTiles.within(
		hen.tile(), float(yard.coop("call_tiles")) + 1.0, world.is_walkable_for_animals
	):
		reach[tile] = true
	var can_reach := func(front: Vector2i) -> bool: return reach.has(front)
	return Coop.nearest_free(world, _animals, hen.position, yard, _roost_taken, can_reach)


## How many times the animal's bedtime (see `_is_sleep_time`) came after the game minute `from` and
## up to `to`.
func _bedtimes_between(animal: FarmAnimal, from: int, to: int) -> int:
	var count := 0
	var first_day := floori(from / float(GameClock.MINUTES_PER_DAY)) + 1
	var last_day := floori(to / float(GameClock.MINUTES_PER_DAY)) + 2
	for day in range(first_day, last_day):
		var bedtime := (
			(day - 1) * GameClock.MINUTES_PER_DAY
			+ ceili(_sun.sunset(day) + rules.sleep_minutes(animal.species) + animal.bedtime_delay)
		)
		if bedtime > from and bedtime <= to:
			count += 1
	return count


## What an animal does when it is time to sleep: a hen walks to a coop with a free roost and goes in
## (see `_roost`), any other animal, or a hen with no coop to go to, sleeps where it is.
func _go_to_sleep(animal: FarmAnimal, delta: float, map: GameMap, may_walk: bool) -> void:
	var may_roost := map is World and (animal.is_housed or may_walk)
	if animal.species == LivestockRules.CHICKEN and may_roost and _roost(animal, delta, map):
		return
	# A hen that could not walk to a coop (the walked minutes of a skip) tries again once play goes on.
	if animal.species == LivestockRules.CHICKEN and not may_walk:
		animal.missed_roost = true
	animal.goal = Vector2.INF
	animal.activity = FarmAnimal.Activity.SLEEP


## Makes a hen go to roost: she stays in the coop she is in, or walks to the front of the door of
## the nearest one with a free roost and goes in. Returns false if she has nowhere to go: she sleeps
## where she is. A hen that is already asleep outdoors stays there, and one that found no coop does
## not look again for `retry_seconds`.
func _roost(hen: FarmAnimal, delta: float, map: GameMap) -> bool:
	if hen.is_housed:
		hen.activity = FarmAnimal.Activity.SLEEP
		return true
	if hen.goal_need == Coop.ROOST and hen.goal.is_finite():
		return _walk_to_coop(hen, delta, map)
	# A roost that is due (see `missed_roost`) is not held up by the cooldown of a failed search.
	var is_waiting := hen.search_seconds > 0.0 and not hen.missed_roost
	if (hen.activity == FarmAnimal.Activity.SLEEP and not hen.missed_roost) or is_waiting:
		return false
	if _searches_left <= 0:
		# Not this time: she goes on as she is and looks in a later update.
		return true
	hen.missed_roost = false
	var coop := _reachable_free_coop(hen, map as World)
	if coop == null:
		hen.search_seconds = yard.needs("retry_seconds")
		return false
	hen.goal = Coop.door_front(coop)
	hen.goal_need = Coop.ROOST
	hen.goal_source = coop.origin
	hen.activity = FarmAnimal.Activity.WALK
	hen.seconds_left = yard.needs("trip_seconds")
	return true


## A step of a hen on her way to the front of a coop's door, and in when she is there. Returns false
## when she gives up: it took too long, the coop is gone, or her way is blocked.
func _walk_to_coop(hen: FarmAnimal, delta: float, map: GameMap) -> bool:
	hen.seconds_left -= delta
	var coop := Coop.of((map as World).building_at(hen.goal_source), yard)
	var speed := rules.walk_speed(hen.species)
	var to_door := hen.goal - hen.position
	var is_arrived := to_door.length() <= speed * delta + GOAL_REACHED_TILES
	if (
		coop == null
		or hen.seconds_left <= 0.0
		or (is_arrived and not Coop.has_room(map as World, coop, _animals, yard))
		or not (is_arrived or _walk(hen, to_door.normalized(), speed, delta, map))
	):
		hen.goal = Vector2.INF
		return false
	if is_arrived:
		_enter_coop(hen, coop)
	else:
		hen.activity = FarmAnimal.Activity.WALK
	return true


## The hen goes in: she is on a tile of the coop, asleep, and lays an egg by the dice.
func _enter_coop(hen: FarmAnimal, coop: Building) -> void:
	hen.position = Coop.roost_spot(coop)
	hen.goal = Vector2.INF
	hen.is_housed = true
	hen.activity = FarmAnimal.Activity.SLEEP
	Coop.lay_egg(coop, yard, rng)


## The hen comes out in the morning, to the front of the door.
func _leave_coop(hen: FarmAnimal, map: GameMap) -> void:
	var coop := Coop.housing(map as World, hen.tile(), yard)
	hen.is_housed = false
	hen.position = Coop.door_front(coop)
	_start_activity(hen, FarmAnimal.Activity.IDLE)


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
	animal: FarmAnimal, delta: float, map: GameMap, player_feet: Vector2, may_hunt: bool
) -> void:
	var flee_tiles := rules.flee_tiles(animal.species)
	var player_distance := animal.position.distance_to(player_feet)
	if flee_tiles > 0.0 and player_distance <= flee_tiles:
		animal.activity = FarmAnimal.Activity.FLEE
		animal.goal = Vector2.INF
		animal.hunted = null
	animal.hunt_rest_seconds = maxf(0.0, animal.hunt_rest_seconds - delta)
	if animal.activity in [FarmAnimal.Activity.CROUCH, FarmAnimal.Activity.CREEP]:
		if animal.hunted == null or not animal.hunted.is_about:
			_end_hunt(animal)
			return
		_track_prey(animal)
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
				_start_next(animal, map, may_hunt)
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
			if animal.goal.is_finite():
				_walk_to_goal(animal, speed, delta, map, may_hunt)
			elif animal.seconds_left <= 0.0:
				_start_next(animal, map, may_hunt)
			elif not _walk(animal, animal.heading, speed, delta, map):
				_start_activity(animal, FarmAnimal.Activity.IDLE, may_hunt)
		_:
			animal.seconds_left -= delta
			if (
				animal.activity == FarmAnimal.Activity.GRAZE
				and yard.grazes_for_food(animal.species)
			):
				var relief := yard.needs("graze_relief_per_second") * delta
				animal.hunger = maxf(0.0, animal.hunger - relief)
			if animal.seconds_left <= 0.0:
				_start_next(animal, map, may_hunt)


## What an animal does next: it goes to what it needs, if it needs something it can find, else
## something of its own.
func _start_next(animal: FarmAnimal, map: GameMap, may_walk: bool) -> void:
	if not (may_walk and _start_trip_to_need(animal, map)):
		_start_next_activity(animal, may_walk)


## Brings everything that follows the game clock up to it: the needs and the friendship.
func account_clock(clock: GameClock) -> void:
	account_needs(clock)
	account_friendship(clock)


## Takes `daily_loss` of friendship for each day that ended since the last time and in which the
## animal was not petted (awake; down to 0). The days are counted, not stepped, so a skip of any
## length costs a few sums for each animal and needs no frame budget. A day that has ended is
## looked at only here, so `pet` calls this first. The first time only notes the day.
func account_friendship(clock: GameClock) -> void:
	if _friendship_day > 0 and clock.day > _friendship_day:
		var ended_days := clock.day - _friendship_day
		var daily_loss := rules.friendship("daily_loss")
		for animal in _animals:
			var was_petted := (
				animal.last_petted_day >= _friendship_day and animal.last_petted_day < clock.day
			)
			var unpetted_days := ended_days - (1 if was_petted else 0)
			animal.friendship = maxi(0, animal.friendship - unpetted_days * daily_loss)
	_friendship_day = clock.day


## Brings the needs of every animal (ridden ones too) up to the game clock (GameState does it before
## a save, so the hours the player spent indoors are in it): they rise by the
## minutes that passed since the last time, whatever the frames did, and stand still while the clock
## does (frozen) or the cheat is on. The first time only notes the minute.
func account_needs(clock: GameClock) -> void:
	var now := clock.total_minutes()
	if _needs_minute >= 0 and now > _needs_minute:
		for animal in _animals:
			_rise_needs(animal, float(now - _needs_minute))
	_needs_minute = now


## Lets `minutes` of game time make the animal hungrier and thirstier; none with the cheat on.
func _rise_needs(animal: FarmAnimal, minutes: float) -> void:
	if cheats.are_needs_off or minutes <= 0.0:
		return
	var species := animal.species
	animal.hunger = minf(1.0, animal.hunger + minutes / yard.need_minutes(species, &"hunger"))
	animal.thirst = minf(1.0, animal.thirst + minutes / yard.need_minutes(species, &"thirst"))


## The needs an animal can meet and has not, the stronger first: the need has reached `seek_at`, and
## the species has a way to meet it (every one drinks; hay is for those that eat feed).
func _pressing_needs(animal: FarmAnimal) -> Array[StringName]:
	var needs: Array[StringName] = []
	var seek_at := yard.needs("seek_at")
	if animal.thirst >= seek_at:
		needs.append(&"thirst")
	if animal.hunger >= seek_at and yard.eats_feed(animal.species):
		needs.append(&"hunger")
	if needs.size() == 2 and animal.hunger > animal.thirst:
		needs.reverse()
	return needs


## Sets the animal walking to the nearest thing that meets its strongest need that it can find; a
## search that finds nothing is not repeated for a while. Returns whether it set off.
func _start_trip_to_need(animal: FarmAnimal, map: GameMap) -> bool:
	if animal.search_seconds > 0.0 or _searches_left <= 0:
		return false
	var needs := _pressing_needs(animal)
	var has_searched := false
	for need in needs:
		if _searches_left <= 0:
			break
		_searches_left -= 1
		has_searched = true
		var found := _find_source(animal, need, map)
		if found.is_empty():
			continue
		animal.goal = found["spot"]
		animal.goal_source = found["source"]
		animal.goal_need = need
		animal.activity = FarmAnimal.Activity.WALK
		animal.seconds_left = yard.needs("trip_seconds")
		return true
	if has_searched:
		animal.search_seconds = yard.needs("retry_seconds")
	return false


## Where an animal can meet a need: the nearest tile it can walk to (within `search_tiles`) that
## has a source of it beside it, as `{"spot": its feet there, "source": the tile of the source}`,
## or an empty dictionary.
func _find_source(animal: FarmAnimal, need: StringName, map: GameMap) -> Dictionary:
	search_count += 1
	var tiles := ReachableTiles.within(
		animal.tile(), yard.needs("search_tiles"), map.is_walkable_for_animals
	)
	for tile in tiles:
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if _gives(map, tile + step, need):
				return {"spot": Vector2(tile) + Vector2(0.5, 0.5), "source": tile + step}
	return {}


## Whether what is on a tile meets a need now: fresh water or a trough with water for thirst (a
## stock of kind water), a stock of feed (a hay rack, a feeding trough) for hunger.
func _gives(map: GameMap, pos: Vector2i, need: StringName) -> bool:
	var tile := map.tile_at(pos)
	if need == &"thirst" and tile != null and tile.is_fresh_water():
		return true
	var object := map.object_at(pos)
	if object == null or not ObjectStock.is_stocked(object) or ObjectStock.units(object) == 0:
		return false
	return object.type_data()["stock_kind"] == (&"water" if need == &"thirst" else &"feed")


## Walks the animal to its goal, and meets the need on arrival; a goal it cannot walk to is given
## up.
func _walk_to_goal(
	animal: FarmAnimal, speed: float, delta: float, map: GameMap, may_hunt: bool
) -> void:
	var to_goal := animal.goal - animal.position
	if to_goal.length() <= speed * delta + GOAL_REACHED_TILES:
		animal.position = animal.goal
		_meet_need_at_source(animal, map)
	elif animal.seconds_left <= 0.0 or not _walk(animal, to_goal.normalized(), speed, delta, map):
		# It walks straight at its goal, round what is small, and has no way to find a long one:
		# it gives up and does not look again for a while.
		animal.goal = Vector2.INF
		animal.search_seconds = yard.needs("retry_seconds")
		_start_activity(animal, FarmAnimal.Activity.IDLE, may_hunt)


## The animal has come to its source: it drinks or eats there with its head down, if the source
## still has something (water that is a tile has always), and the need is 0 again.
func _meet_need_at_source(animal: FarmAnimal, map: GameMap) -> void:
	var need := animal.goal_need
	var source := animal.goal_source
	animal.goal = Vector2.INF
	if not _gives(map, source, need):
		_start_activity(animal, FarmAnimal.Activity.IDLE)
		return
	_take_from(map, source, yard.units_per_need(animal.species, need))
	if need == &"thirst":
		animal.thirst = 0.0
	else:
		animal.hunger = 0.0
	var dx := float(source.x) + 0.5 - animal.position.x
	if absf(dx) > 0.1:
		animal.facing = signf(dx)
	animal.activity = FarmAnimal.Activity.GRAZE
	animal.seconds_left = yard.needs("drink_seconds" if need == &"thirst" else "eat_seconds")


## Takes `units` out of the stock of the object on a tile, if it has one, so that its picture
## follows; a tile of water has none to take.
func _take_from(map: GameMap, pos: Vector2i, units: int) -> void:
	var object := map.object_at(pos)
	if object != null and ObjectStock.is_stocked(object):
		ObjectStock.take(object, units)
		if map is World:
			(map as World).change_object(object)


## An animal in a skip of `minutes` meets each need that rose to `seek_at` if it can reach what
## meets it (fresh water or a trough; a hay rack, or grass for a grazer): it did so at some time in
## them, so the need is now somewhere between 0 and `seek_at` by the dice, and a source that is a
## stock has lost what the meals took (the need rose by whole `seek_at`s, so that many meals, at
## least one). One that cannot reach any stays as risen.
func _meet_needs_in_skip(animal: FarmAnimal, map: GameMap, minutes: int) -> void:
	var seek_at := yard.needs("seek_at")
	for need: StringName in [&"thirst", &"hunger"]:
		var level: float = animal.thirst if need == &"thirst" else animal.hunger
		if level < seek_at:
			continue
		var found := {}
		if need == &"thirst" or yard.eats_feed(animal.species):
			found = _find_source(animal, need, map)
		var grazes := need == &"hunger" and yard.grazes_for_food(animal.species)
		if found.is_empty() and not grazes:
			continue
		if not found.is_empty():
			var meals := maxi(1, int(minutes / yard.need_minutes(animal.species, need) / seek_at))
			_take_from(map, found["source"], meals * yard.units_per_need(animal.species, need))
		var met := rng.randf() * seek_at
		if need == &"thirst":
			animal.thirst = met
		else:
			animal.hunger = met


## Creeps up on the mouse until it is near enough to pounce; gives up when it takes too long or
## the way is blocked.
func _creep(animal: FarmAnimal, delta: float, map: GameMap) -> void:
	animal.seconds_left -= delta
	var to_prey := animal.pounce_at - animal.position
	if to_prey.length() <= rules.hunting("pounce_tiles"):
		animal.activity = FarmAnimal.Activity.POUNCE
		if rng.randf() >= rules.hunting("catch_chance"):
			_scare_prey(animal)
	elif (
		animal.seconds_left <= 0.0
		or not _walk(animal, to_prey.normalized(), rules.hunting("creep_speed"), delta, map)
	):
		_end_hunt(animal)


## Leaps at where the mouse was when it pounced, and lands there; a leap that is blocked ends
## short of it.
func _pounce(animal: FarmAnimal, delta: float, map: GameMap) -> void:
	var speed := rules.hunting("pounce_speed")
	var to_prey := animal.pounce_at - animal.position
	if to_prey.length() <= speed * delta:
		animal.position = animal.pounce_at
		_end_hunt(animal)
	elif not _walk(animal, to_prey.normalized(), speed, delta, map):
		_end_hunt(animal)


## The mouse the cat crouches at or creeps up on is where it is now. A pounce goes where the
## mouse was when the cat leapt.
func _track_prey(animal: FarmAnimal) -> void:
	animal.pounce_at = animal.hunted.position
	if absf(animal.pounce_at.x - animal.position.x) > 0.1:
		animal.facing = signf(animal.pounce_at.x - animal.position.x)


## The mouse sees the pounce coming and dashes off; the cat leaps at where it was.
func _scare_prey(animal: FarmAnimal) -> void:
	animal.hunted.fate = Prey.Fate.SCARED
	animal.hunted.scare_point = animal.position
	animal.hunted.is_about = false
	animal.hunted = null


## The hunt is over: a cat that has landed catches the mouse if it is still under it.
func _end_hunt(animal: FarmAnimal) -> void:
	var mouse := animal.hunted
	if (
		animal.activity == FarmAnimal.Activity.POUNCE
		and mouse != null
		and mouse.is_about
		and mouse.position.distance_to(animal.position) <= rules.hunting("catch_tiles")
	):
		mouse.fate = Prey.Fate.CAUGHT
		mouse.is_about = false
	animal.hunted = null
	animal.hunt_rest_seconds = rules.hunting("rest_seconds")
	_start_activity(animal, FarmAnimal.Activity.IDLE)


## The cat gives up its hunt with no outcome for the mouse: the world moved on without it.
func _abandon_hunt(animal: FarmAnimal) -> void:
	animal.hunted = null
	if animal.activity in HUNT_ACTIVITIES:
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
		if (
			map.is_walkable_for_animals(Vector2i(feet.floor()))
			and map.is_walkable_for_animals(Vector2i(nose.floor()))
		):
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
## faces) on walkable ground, and never on a building. It stays where it is if five spots have no
## such way.
func _wander_off(animal: FarmAnimal, map: GameMap) -> void:
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


func _start_next_activity(animal: FarmAnimal, may_hunt := false) -> void:
	_start_activity(animal, rules.pick_activity(animal.species, rng), may_hunt)


## Starts an activity; with `may_hunt`, a cat that can hunt looks about for a mouse in sight
## instead, and starts the hunt of the nearest.
func _start_activity(animal: FarmAnimal, activity: FarmAnimal.Activity, may_hunt := false) -> void:
	animal.activity = activity
	animal.seconds_left = rules.pick_seconds(animal.species, activity, rng)
	match activity:
		FarmAnimal.Activity.WALK, FarmAnimal.Activity.RUN:
			animal.heading = Vector2.from_angle(rng.randf() * TAU)
		FarmAnimal.Activity.IDLE:
			# Now and then it turns round where it stands.
			if rng.randf() < 0.3:
				animal.facing = -animal.facing
	if not may_hunt or not can_hunt(animal):
		return
	var nearest: Prey = null
	var nearest_distance := rules.hunting("sight_tiles")
	for mouse in _mice:
		var distance := mouse.position.distance_to(animal.position)
		if mouse.is_about and distance <= nearest_distance:
			nearest = mouse
			nearest_distance = distance
	if nearest != null:
		start_hunt(animal, nearest)


## Takes a step in `direction`, or as near to it as it can turn; returns whether it moved. The
## ground under its feet and under its nose (`body_tiles` ahead) must be walkable for animals, or be
## the tile it stands on if anyone could walk there.
##
## Asking the map is what costs (several microseconds a tile), so a step the same way as the last
## that stays on the same tiles is taken without asking again.
func _walk(
	animal: FarmAnimal, direction: Vector2, speed: float, delta: float, map: GameMap
) -> bool:
	var reach := rules.body_tiles(animal.species)
	var here := animal.tile()
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
			if feet_tile != animal.tile() and map is World and _animal_step > 0.0:
				(map as World).wear_tile(feet_tile, _animal_step)
			animal.position = feet
			animal.heading = way
			animal.last_step = way
			if absf(way.x) > 0.1:
				animal.facing = signf(way.x)
			return true
	return false
