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
## what to do next, and the whole hunt is decided without a view (see CatHunt).
## GameState owns it and moves the animals with `update` while the player is out in the world.
##
## It does not know the world, so the two never hold each other: the map the animals walk on is
## given to each call that needs it.

## An animal came into the world.
signal added(animal: FarmAnimal)
## An animal left the world for good (see `remove_species`); whoever shows it stops.
signal removed(animal: FarmAnimal)
## A rooster crows: whoever listens plays the sound from where it stands.
signal crowed(rooster: FarmAnimal)
## An animal was petted and shows what `pet` returned (a heart or the anger mark, never nothing).
signal petted(animal: FarmAnimal, shows: PetShows)

## What petting an animal shows over its head: nothing, a heart (the first petting of a day while it
## is awake) or the anger mark (the first while it sleeps).
enum PetShows { NOTHING, HEART, ANNOYED }

## Spawned animals stand this many tiles from the given point, at the least and at the most.
const SPAWN_DISTANCE := Vector2(1.5, 4.0)
const SPAWN_TRIES := 40
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
var rng := RandomNumberGenerator.new()
## The searches for water, feed or a coop an `update` may make (see [needs] `searches_per_update`).
var searches := AnimalSearches.new()
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


## Takes every animal of a species (of one `look` of it, if given) out of the world, and so out of
## the next save. Returns how many.
## The player riding a horse is not Livestock's to undo: PlayerTravel `dismount` comes first.
func remove_species(species: StringName, look := &"") -> int:
	var gone: Array[FarmAnimal] = []
	var staying: Array[FarmAnimal] = []
	for animal in _animals:
		var is_gone := animal.species == species and (look == &"" or animal.look == look)
		(gone if is_gone else staying).append(animal)
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
## New hens (chickens with no look given) bring a rooster to each flock that has none, which is
## not counted. Returns how many found a place.
func spawn(species: StringName, count: int, near: Vector2, map: GameMap, look := &"") -> int:
	var placed := 0
	for _try in SPAWN_TRIES:
		if placed == count:
			break
		var feet := AnimalMotion.point_around(near, SPAWN_DISTANCE, rng)
		if not map.is_walkable_for_animals(Vector2i(feet.floor())):
			continue
		var animal := FarmAnimal.create(species, rng.randi(), feet, rules)
		if look != &"":
			animal.look = look
		animal.facing = 1.0 if rng.randf() < 0.5 else -1.0
		_start_next_activity(animal)
		add(animal)
		placed += 1
	if species == LivestockRules.CHICKEN and look == &"" and map is World:
		var coops := Coop.spots(map as World, yard)
		for spot in ChickenFlocks.spots_without_rooster(
			_animals, coops, rules.rooster("flock_tiles")
		):
			spawn(species, 1, spot, map, LivestockRules.ROOSTER_LOOK)
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
	AnimalFollowing.start(animal, now, rules)


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


## Whether an animal would hunt a mouse now (see CatHunt).
func can_hunt(animal: FarmAnimal) -> bool:
	return CatHunt.can_hunt(animal)


## The cat starts to hunt a mouse (see CatHunt).
func start_hunt(animal: FarmAnimal, mouse: Prey) -> void:
	CatHunt.start(animal, mouse, rules)


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
	searches.left = int(yard.needs("searches_per_update"))
	var stamina_per_second := 1.0 / rules.general("stamina_stand_regain_seconds")
	for animal in _animals:
		# A ridden horse's stamina is GameState's (`walk`). The others get theirs back wherever
		# they are, also in chunks that are not loaded: it is a sum, not a walk.
		if not animal.is_ridden:
			animal.stamina = minf(1.0, animal.stamina + delta * stamina_per_second)
		if animal.is_ridden or (only_loaded and not _is_in_loaded_chunk(animal, map)):
			continue
		if not may_hunt:
			_abandon_hunt(animal)
		animal.search_seconds = maxf(0.0, animal.search_seconds - delta)
		if animal.species == LivestockRules.CHICKEN and map is World:
			animal.is_housed = Coop.housing(map as World, animal.tile(), yard) != null
		if AnimalFollowing.is_following(animal, now, player_feet):
			animal.goal = Vector2.INF
			AnimalFollowing.follow(animal, delta, map, player_feet, rules, rng, _walk)
		elif _is_sleep_time(animal, minute, sunrise, sunset):
			animal.crows_left = 0
			_go_to_sleep(animal, delta, map, may_hunt)
		elif animal.is_housed:
			ChickenRoosting.leave_coop(animal, map, rules, yard, rng)
		elif animal.activity == FarmAnimal.Activity.SLEEP:
			_start_activity(animal, FarmAnimal.Activity.IDLE, may_hunt)
		else:
			if animal.goal_need == Coop.ROOST:
				animal.goal = Vector2.INF
			if animal.is_rooster() and Crowing.update(animal, delta, clock, sunrise, rules, rng):
				crowed.emit(animal)
			_update_awake_animal(animal, delta, map, player_feet, may_hunt)


## Puts the animals where time that was skipped (see Simulation `skip`) has left them, at the
## time of the game clock: each animal in a loaded chunk is up to `catch_up_wander_tiles` from
## where it was, on a tile it could have walked to, and sleeping or doing something new as the hour
## has it. A follower is put beside the player, and the horse that is ridden stays with them; a
## player who is indoors (`player_feet` infinite) is not followed, and the follower is caught up
## like the others. The dice are thrown from `seed_value`. The needs have risen with the clock, and
## an animal that could reach what it needs has met it somewhere in the `minutes` (see
## `AnimalNeeds.meet_in_skip`).
func catch_up(
	map: GameMap, clock: GameClock, player_feet: Vector2, seed_value: int, minutes := 0
) -> void:
	_begin_catch_up(clock, seed_value)
	for animal in _animals:
		_catch_up_one(animal, map, clock, player_feet, minutes)
	searches.roost_taken.clear()


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
	searches.roost_taken.clear()


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
	if AnimalFollowing.is_following(animal, clock.total_minutes(), player_feet):
		AnimalFollowing.put_beside(animal, player_feet, map, rules, rng)
		return
	var is_asleep := _is_sleep_time(
		animal, clock.minute_of_day, _sun.sunrise(clock.day), _sun.sunset(clock.day)
	)
	if animal.species == LivestockRules.CHICKEN:
		var now := clock.total_minutes()
		var skip_began := now - minutes - Simulation.WALKED_MINUTES
		var bedtimes := ChickenRoosting.bedtimes_between(animal, skip_began, now, _sun, rules)
		if ChickenRoosting.settle_in_skip(
			animal, map, bedtimes, is_asleep, minutes, _animals, rules, yard, rng, searches
		):
			return
	AnimalMotion.wander_off(animal, map, rules, rng)
	AnimalNeeds.meet_in_skip(animal, map, minutes, yard, rng, searches)
	if is_asleep:
		animal.activity = FarmAnimal.Activity.SLEEP
	else:
		# The heading it was left with is one its nose is clear on; a new activity picks its
		# own, which a step turns away from ground it cannot walk on.
		var heading := animal.heading
		_start_next_activity(animal)
		animal.heading = heading


## What an animal does when it is time to sleep: a hen walks to a coop with a free roost and goes in
## (see ChickenRoosting `roost`), any other animal, or a hen with no coop to go to, sleeps where it
## is.
func _go_to_sleep(animal: FarmAnimal, delta: float, map: GameMap, may_walk: bool) -> void:
	var may_roost := map is World and (animal.is_housed or may_walk)
	if (
		animal.species == LivestockRules.CHICKEN
		and may_roost
		and ChickenRoosting.roost(animal, delta, map, _animals, rules, yard, rng, searches, _walk)
	):
		return
	# A hen that could not walk to a coop (the walked minutes of a skip) tries again once play goes on.
	if animal.species == LivestockRules.CHICKEN and not may_walk:
		animal.missed_roost = true
	animal.goal = Vector2.INF
	animal.activity = FarmAnimal.Activity.SLEEP


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
		CatHunt.track(animal)
	match animal.activity:
		FarmAnimal.Activity.CROUCH:
			animal.seconds_left -= delta
			if animal.seconds_left <= 0.0:
				animal.activity = FarmAnimal.Activity.CREEP
				animal.seconds_left = rules.hunting("give_up_seconds")
		FarmAnimal.Activity.CREEP:
			if CatHunt.creep(animal, delta, map, rules, rng, _walk):
				_end_hunt(animal)
		FarmAnimal.Activity.POUNCE:
			if CatHunt.pounce(animal, delta, map, rules, _walk):
				_end_hunt(animal)
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
			AnimalMotion.note_progress(animal, rules)
			if animal.goal.is_finite():
				var has_given_up := AnimalNeeds.walk_to_goal(
					animal, speed, delta, map, rules, yard, rng, _walk
				)
				if has_given_up:
					_start_activity(animal, FarmAnimal.Activity.IDLE, may_hunt)
			elif animal.seconds_left <= 0.0 or AnimalMotion.is_blocked_too_long(animal, rules):
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
	if not (may_walk and AnimalNeeds.start_trip(animal, map, yard, searches)):
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
			AnimalNeeds.rise(animal, float(now - _needs_minute), yard, cheats.are_needs_off)
	_needs_minute = now


## The hunt is over (see CatHunt `finish`): the cat does something else.
func _end_hunt(animal: FarmAnimal) -> void:
	CatHunt.finish(animal, rules)
	_start_activity(animal, FarmAnimal.Activity.IDLE)


## The cat gives up its hunt with no outcome for the mouse: the world moved on without it.
func _abandon_hunt(animal: FarmAnimal) -> void:
	animal.hunted = null
	if animal.activity in HUNT_ACTIVITIES:
		_start_activity(animal, FarmAnimal.Activity.IDLE)


func _start_next_activity(animal: FarmAnimal, may_hunt := false) -> void:
	_start_activity(animal, rules.pick_activity(animal.species, rng), may_hunt)


## Starts an activity (see AnimalMotion); with `may_hunt`, a cat that can hunt looks about for a
## mouse in sight instead, and starts the hunt of the nearest.
func _start_activity(animal: FarmAnimal, activity: FarmAnimal.Activity, may_hunt := false) -> void:
	AnimalMotion.start_activity(animal, activity, rules, rng)
	if not may_hunt or not can_hunt(animal):
		return
	var nearest := CatHunt.nearest_prey(animal, _mice, rules)
	if nearest != null:
		start_hunt(animal, nearest)


## A step for CatHunt, the needs and the roosting (see AnimalMotion `walk`).
func _walk(
	animal: FarmAnimal, direction: Vector2, speed: float, delta: float, map: GameMap
) -> bool:
	return AnimalMotion.walk(animal, direction, speed, delta, map, rules, _animal_step)
