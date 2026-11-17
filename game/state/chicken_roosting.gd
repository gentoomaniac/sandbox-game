class_name ChickenRoosting
extends RefCounted
## How a hen goes to bed in a coop (see Coop and Livestock): at bedtime she walks to the nearest
## coop with a free roost and goes in, lays an egg, and comes out in the morning; a skip puts her
## there, and counts the eggs of the nights, with no walking. It keeps nothing: every function is
## given the hen and what it needs.


## Makes a hen go to roost: she stays in the coop she is in, or walks to the front of the door of
## the nearest one with a free roost and goes in. Returns false if she has nowhere to go: she sleeps
## where she is. A hen that is already asleep outdoors stays there, and one that found no coop does
## not look again for `retry_seconds`. `walk` is Livestock `_walk`.
static func roost(
	hen: FarmAnimal,
	delta: float,
	map: GameMap,
	animals: Array[FarmAnimal],
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator,
	searches: AnimalSearches,
	walk: Callable
) -> bool:
	if hen.is_housed:
		hen.activity = FarmAnimal.Activity.SLEEP
		return true
	if hen.goal_need == Coop.ROOST and hen.goal.is_finite():
		return _walk_to_coop(hen, delta, map, animals, rules, yard, rng, walk)
	# A roost that is due (see `missed_roost`) is not held up by the cooldown of a failed search.
	var is_waiting := hen.search_seconds > 0.0 and not hen.missed_roost
	if (hen.activity == FarmAnimal.Activity.SLEEP and not hen.missed_roost) or is_waiting:
		return false
	if searches.left <= 0:
		# Not this time: she goes on as she is and looks in a later update.
		return true
	hen.missed_roost = false
	var coop := _reachable_free_coop(hen, map as World, animals, yard, searches)
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
static func _walk_to_coop(
	hen: FarmAnimal,
	delta: float,
	map: GameMap,
	animals: Array[FarmAnimal],
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator,
	walk: Callable
) -> bool:
	hen.seconds_left -= delta
	var coop := Coop.of((map as World).building_at(hen.goal_source), yard)
	var speed := rules.walk_speed(hen.species)
	var to_door := hen.goal - hen.position
	var is_arrived := to_door.length() <= speed * delta + AnimalMotion.GOAL_REACHED_TILES
	if (
		coop == null
		or hen.seconds_left <= 0.0
		or (is_arrived and not Coop.has_room(map as World, coop, animals, yard))
		or not (is_arrived or walk.call(hen, to_door.normalized(), speed, delta, map))
	):
		hen.goal = Vector2.INF
		return false
	if is_arrived:
		_enter_coop(hen, coop, yard, rng)
	else:
		hen.activity = FarmAnimal.Activity.WALK
	return true


## The hen goes in: she is on a tile of the coop, asleep, and lays an egg by the dice (a rooster
## lays none).
static func _enter_coop(
	hen: FarmAnimal, coop: Building, yard: YardRules, rng: RandomNumberGenerator
) -> void:
	hen.position = Coop.roost_spot(coop)
	hen.goal = Vector2.INF
	hen.is_housed = true
	hen.activity = FarmAnimal.Activity.SLEEP
	if not hen.is_rooster():
		Coop.lay_egg(coop, yard, rng)


## The hen comes out in the morning, to the front of the door.
static func leave_coop(
	hen: FarmAnimal,
	map: GameMap,
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator
) -> void:
	var coop := Coop.housing(map as World, hen.tile(), yard)
	hen.is_housed = false
	hen.position = Coop.door_front(coop)
	AnimalMotion.start_activity(hen, FarmAnimal.Activity.IDLE, rules, rng)


## A hen in a skip of `minutes`, in which her bedtime came `bedtimes` times (the walked minutes
## before it included, see `bedtimes_between`), and that ends asleep or not as `is_asleep` says. If
## she is in a coop or could walk to one with a free roost (see `Coop.nearest_free`) she laid an
## egg in it (by `egg_chance`) for each bedtime (no hen goes to a coop while they are walked), met
## her needs from its front like the others, and is in it if it is time to sleep, else she has come
## out in front of its door. Returns whether she was settled so (one with no coop is left to the
## others' rules).
static func settle_in_skip(
	hen: FarmAnimal,
	map: GameMap,
	bedtimes: int,
	is_asleep: bool,
	minutes: int,
	animals: Array[FarmAnimal],
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator,
	searches: AnimalSearches
) -> bool:
	if not map is World:
		return false
	var world := map as World
	var coop := Coop.housing(world, hen.tile(), yard)
	hen.is_housed = coop != null
	if coop == null:
		coop = _reachable_free_coop(hen, world, animals, yard, searches)
	if coop == null:
		return false
	for _night in bedtimes:
		if not hen.is_rooster():
			Coop.lay_egg(coop, yard, rng)
	hen.position = Coop.door_front(coop)
	hen.is_housed = false
	AnimalNeeds.meet_in_skip(hen, map, minutes, yard, rng, searches)
	hen.goal = Vector2.INF
	if is_asleep:
		hen.position = Coop.roost_spot(coop)
		hen.is_housed = true
		hen.activity = FarmAnimal.Activity.SLEEP
	else:
		# The night took a roost that nobody is in now.
		var taken := searches.roost_taken
		taken[coop.origin] = int(taken.get(coop.origin, 0)) + 1
		AnimalMotion.start_activity(hen, FarmAnimal.Activity.IDLE, rules, rng)
	return true


## How many times the animal's bedtime (see Livestock `is_sleep_time`) came after the game minute
## `from` and up to `to`.
static func bedtimes_between(
	animal: FarmAnimal, from: int, to: int, sun: Sun, rules: LivestockRules
) -> int:
	var count := 0
	var first_day := floori(from / float(GameClock.MINUTES_PER_DAY)) + 1
	var last_day := floori(to / float(GameClock.MINUTES_PER_DAY)) + 2
	for day in range(first_day, last_day):
		var bedtime := (
			(day - 1) * GameClock.MINUTES_PER_DAY
			+ ceili(sun.sunset(day) + rules.sleep_minutes(animal.species) + animal.bedtime_delay)
		)
		if bedtime > from and bedtime <= to:
			count += 1
	return count


## The coop with a free roost nearest to the hen that she can walk to (see `Coop.nearest_free`), or
## null. It costs a flood fill of the ground round her.
static func _reachable_free_coop(
	hen: FarmAnimal,
	world: World,
	animals: Array[FarmAnimal],
	yard: YardRules,
	searches: AnimalSearches
) -> Building:
	searches.left -= 1
	searches.made += 1
	var reach := {}
	for tile in ReachableTiles.within(
		hen.tile(), float(yard.coop("call_tiles")) + 1.0, world.is_walkable_for_animals
	):
		reach[tile] = true
	var can_reach := func(front: Vector2i) -> bool: return reach.has(front)
	return Coop.nearest_free(world, animals, hen.position, yard, searches.roost_taken, can_reach)
