class_name AnimalNeeds
extends RefCounted
## The hunger and thirst of the farm animals (see Livestock and YardRules): how they rise, how an
## animal looks for what meets one and walks there, and how a skip meets them in one go. It keeps
## nothing: every function is given the animal and what it needs.


## Lets `minutes` of game time make the animal hungrier and thirstier; none with the needs off.
static func rise(animal: FarmAnimal, minutes: float, yard: YardRules, are_needs_off: bool) -> void:
	if are_needs_off or minutes <= 0.0:
		return
	var species := animal.species
	animal.hunger = minf(1.0, animal.hunger + minutes / yard.need_minutes(species, &"hunger"))
	animal.thirst = minf(1.0, animal.thirst + minutes / yard.need_minutes(species, &"thirst"))


## The needs an animal can meet and has not, the stronger first: the need has reached `seek_at`, and
## the species has a way to meet it (every one drinks; hay is for those that eat feed).
static func pressing_needs(animal: FarmAnimal, yard: YardRules) -> Array[StringName]:
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
static func start_trip(
	animal: FarmAnimal, map: GameMap, yard: YardRules, searches: AnimalSearches
) -> bool:
	if animal.search_seconds > 0.0 or searches.left <= 0:
		return false
	var has_searched := false
	for need in pressing_needs(animal, yard):
		if searches.left <= 0:
			break
		searches.left -= 1
		has_searched = true
		var found := find_source(animal, need, map, yard, searches)
		if found.is_empty():
			continue
		animal.goal = found["spot"]
		animal.goal_source = found["source"]
		animal.goal_need = need
		animal.activity = FarmAnimal.Activity.WALK
		animal.progress_anchor = Vector2.INF
		animal.seconds_left = yard.needs("trip_seconds")
		return true
	if has_searched:
		animal.search_seconds = yard.needs("retry_seconds")
	return false


## Where an animal can meet a need: the nearest tile it can walk to (within `search_tiles`) that
## has a source of it beside it, as `{"spot": its feet there, "source": the tile of the source}`,
## or an empty dictionary.
static func find_source(
	animal: FarmAnimal, need: StringName, map: GameMap, yard: YardRules, searches: AnimalSearches
) -> Dictionary:
	searches.made += 1
	var tiles := ReachableTiles.within(
		animal.tile(), yard.needs("search_tiles"), map.is_walkable_for_animals
	)
	for tile in tiles:
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if NeedSources.gives(map, tile + step, need):
				return {"spot": Vector2(tile) + Vector2(0.5, 0.5), "source": tile + step}
	return {}


## Walks the animal to its goal, and meets the need on arrival. A goal it cannot walk to is given
## up: it walks straight at its goal, round what is small, and has no way to find a long one, so it
## gives up after a short try and does not look again for a while. Returns whether it gave up, and
## is left to start something else. `walk` is Livestock `_walk`.
static func walk_to_goal(
	animal: FarmAnimal,
	speed: float,
	delta: float,
	map: GameMap,
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator,
	walk: Callable
) -> bool:
	var to_goal := animal.goal - animal.position
	if to_goal.length() <= speed * delta + AnimalMotion.GOAL_REACHED_TILES:
		animal.position = animal.goal
		_meet_need_at_source(animal, map, rules, yard, rng)
		return false
	if (
		animal.seconds_left <= 0.0
		or AnimalMotion.is_blocked_too_long(animal, rules)
		or not walk.call(animal, to_goal.normalized(), speed, delta, map)
	):
		animal.goal = Vector2.INF
		animal.search_seconds = yard.needs("retry_seconds")
		return true
	return false


## The animal has come to its source: it drinks or eats there with its head down, if the source
## still has something (water that is a tile has always), and the need is 0 again.
static func _meet_need_at_source(
	animal: FarmAnimal,
	map: GameMap,
	rules: LivestockRules,
	yard: YardRules,
	rng: RandomNumberGenerator
) -> void:
	var need := animal.goal_need
	var source := animal.goal_source
	animal.goal = Vector2.INF
	if not NeedSources.gives(map, source, need):
		AnimalMotion.start_activity(animal, FarmAnimal.Activity.IDLE, rules, rng)
		return
	NeedSources.take(map, source, yard.units_per_need(animal.species, need))
	if need == &"thirst":
		animal.thirst = 0.0
	else:
		animal.hunger = 0.0
	var dx := float(source.x) + 0.5 - animal.position.x
	if absf(dx) > 0.1:
		animal.facing = signf(dx)
	animal.activity = FarmAnimal.Activity.GRAZE
	animal.seconds_left = yard.needs("drink_seconds" if need == &"thirst" else "eat_seconds")


## An animal in a skip of `minutes` meets each need that rose to `seek_at` if it can reach what
## meets it (fresh water or a trough; a hay rack, or grass for a grazer): it did so at some time in
## them, so the need is now somewhere between 0 and `seek_at` by the dice, and a source that is a
## stock has lost what the meals took (the need rose by whole `seek_at`s, so that many meals, at
## least one). One that cannot reach any stays as risen.
static func meet_in_skip(
	animal: FarmAnimal,
	map: GameMap,
	minutes: int,
	yard: YardRules,
	rng: RandomNumberGenerator,
	searches: AnimalSearches
) -> void:
	var seek_at := yard.needs("seek_at")
	for need: StringName in [&"thirst", &"hunger"]:
		var level: float = animal.thirst if need == &"thirst" else animal.hunger
		if level < seek_at:
			continue
		var found := {}
		if need == &"thirst" or yard.eats_feed(animal.species):
			found = find_source(animal, need, map, yard, searches)
		var grazes := need == &"hunger" and yard.grazes_for_food(animal.species)
		if found.is_empty() and not grazes:
			continue
		if not found.is_empty():
			var meals := maxi(1, int(minutes / yard.need_minutes(animal.species, need) / seek_at))
			NeedSources.take(
				map, found["source"], meals * yard.units_per_need(animal.species, need)
			)
		var met := rng.randf() * seek_at
		if need == &"thirst":
			animal.thirst = met
		else:
			animal.hunger = met
