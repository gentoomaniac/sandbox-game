class_name CatHunt
extends RefCounted
## How a cat hunts a mouse (see Livestock): it crouches facing it, creeps up on it and pounces from
## `pounce_tiles`. The mouse sees the pounce coming and dashes off, or is caught where the cat
## lands (`catch_chance`). A mouse that is gone before the pounce ends the hunt. Then the cat rests
## for `rest_seconds`. Plain functions on the animal; Livestock lends the walking and starts what
## the cat does next.


## Whether an animal would hunt a mouse now: a cat that is up and about, rested since its last
## hunt.
static func can_hunt(animal: FarmAnimal) -> bool:
	return (
		animal.species == LivestockRules.CAT
		and animal.activity in LivestockRules.CHOSEN_ACTIVITIES
		and animal.hunt_rest_seconds <= 0.0
	)


## The mouse of `mice` that is about and nearest the animal within its sight, or null.
static func nearest_prey(animal: FarmAnimal, mice: Array[Prey], rules: LivestockRules) -> Prey:
	var nearest: Prey = null
	var nearest_distance := rules.hunting("sight_tiles")
	for mouse in mice:
		var distance := mouse.position.distance_to(animal.position)
		if mouse.is_about and distance <= nearest_distance:
			nearest = mouse
			nearest_distance = distance
	return nearest


static func start(animal: FarmAnimal, mouse: Prey, rules: LivestockRules) -> void:
	animal.activity = FarmAnimal.Activity.CROUCH
	animal.seconds_left = rules.hunting("crouch_seconds")
	animal.hunted = mouse
	track(animal)


## The mouse the cat crouches at or creeps up on is where it is now. A pounce goes where the
## mouse was when the cat leapt.
static func track(animal: FarmAnimal) -> void:
	animal.pounce_at = animal.hunted.position
	if absf(animal.pounce_at.x - animal.position.x) > 0.1:
		animal.facing = signf(animal.pounce_at.x - animal.position.x)


## Creeps up on the mouse until it is near enough to pounce; gives up when it takes too long or
## the way is blocked. `walk` is Livestock `_walk`. Returns whether the hunt is over.
static func creep(
	animal: FarmAnimal,
	delta: float,
	map: GameMap,
	rules: LivestockRules,
	rng: RandomNumberGenerator,
	walk: Callable
) -> bool:
	animal.seconds_left -= delta
	var to_prey := animal.pounce_at - animal.position
	if to_prey.length() <= rules.hunting("pounce_tiles"):
		animal.activity = FarmAnimal.Activity.POUNCE
		if rng.randf() >= rules.hunting("catch_chance"):
			_scare_prey(animal)
		return false
	return (
		animal.seconds_left <= 0.0
		or not walk.call(animal, to_prey.normalized(), rules.hunting("creep_speed"), delta, map)
	)


## Leaps at where the mouse was when it pounced, and lands there; a leap that is blocked ends
## short of it. Returns whether the hunt is over.
static func pounce(
	animal: FarmAnimal, delta: float, map: GameMap, rules: LivestockRules, walk: Callable
) -> bool:
	var speed := rules.hunting("pounce_speed")
	var to_prey := animal.pounce_at - animal.position
	if to_prey.length() <= speed * delta:
		animal.position = animal.pounce_at
		return true
	return not walk.call(animal, to_prey.normalized(), speed, delta, map)


## The hunt is over: a cat that has landed catches the mouse if it is still under it, and rests.
static func finish(animal: FarmAnimal, rules: LivestockRules) -> void:
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


## The mouse sees the pounce coming and dashes off; the cat leaps at where it was.
static func _scare_prey(animal: FarmAnimal) -> void:
	animal.hunted.fate = Prey.Fate.SCARED
	animal.hunted.scare_point = animal.position
	animal.hunted.is_about = false
	animal.hunted = null
