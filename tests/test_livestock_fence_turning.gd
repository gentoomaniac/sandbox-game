extends LivestockCase
## An animal that cannot get where it wants to go because of a fence across its way does not spin
## left and right: it turns at most a few times, gives the target up and picks another, and a
## follower that cannot reach the player waits for them, facing them.

const FENCE_ROW := 0
const WATCH_SECONDS := 5.0
const MOST_TURNS := 4
## Species that walk on their own: the farm animals and the pets.
const SPECIES: Array[StringName] = [
	LivestockRules.HORSE,
	LivestockRules.COW,
	LivestockRules.SHEEP,
	LivestockRules.PIG,
	LivestockRules.CHICKEN,
	LivestockRules.DOG,
	LivestockRules.CAT,
	LivestockRules.RABBIT,
]


func before_each() -> void:
	super()
	for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
		var tile := _middle + Vector2i(x, FENCE_ROW)
		_world.remove_object(tile)
		_world.add_object(WorldObject.new(WorldObjectTypes.PEN_FENCE, tile))


## An animal one tile south of the fence, standing where it is put.
func _animal_at_fence(species: StringName) -> FarmAnimal:
	var look: StringName = _livestock.rules.looks(species)[0]
	var animal := FarmAnimal.new(species, look, _pen_middle() + Vector2(0.0, 1.5))
	_livestock.add(animal)
	_livestock.stand_still(animal)
	return animal


## How often the animal's facing changed over `seconds`.
func _count_turns(animal: FarmAnimal, seconds: float) -> int:
	var turns := 0
	var facing := animal.facing
	for _frame in int(seconds / STEP_SECONDS):
		_step()
		if animal.facing != facing:
			turns += 1
			facing = animal.facing
	return turns


func test_an_animal_walking_at_a_goal_behind_the_fence_gives_it_up_without_spinning() -> void:
	for species in SPECIES:
		var animal := _animal_at_fence(species)
		animal.activity = FarmAnimal.Activity.WALK
		animal.seconds_left = 60.0
		animal.goal = _pen_middle() + Vector2(0.0, -1.5)
		animal.goal_need = &"thirst"
		animal.goal_source = Vector2i(animal.goal.floor())

		var turns := _count_turns(animal, WATCH_SECONDS)

		assert_lte(turns, MOST_TURNS, "%s turned %d times" % [species, turns])
		assert_false(animal.goal.is_finite(), "%s gave the goal up" % species)
		_livestock.remove_species(species)


func test_an_animal_wandering_at_the_fence_picks_another_way_without_spinning() -> void:
	for species in SPECIES:
		var animal := _animal_at_fence(species)
		animal.activity = FarmAnimal.Activity.WALK
		animal.seconds_left = 60.0
		animal.heading = Vector2.UP

		var turns := _count_turns(animal, WATCH_SECONDS)

		assert_lte(turns, MOST_TURNS, "%s turned %d times" % [species, turns])
		var is_still_at_it := (
			animal.activity == FarmAnimal.Activity.WALK and animal.heading == Vector2.UP
		)
		assert_false(is_still_at_it, "%s picked something else" % species)
		_livestock.remove_species(species)


func test_a_dog_that_cannot_reach_the_player_waits_facing_them() -> void:
	var dog := _animal_at_fence(LivestockRules.DOG)
	_state.clock.minute_of_day = NOON
	_livestock.start_following(dog, _state.clock.total_minutes())
	# Across the fence and to the right, near enough not to count as left behind.
	_state.player.position = _pen_middle() + Vector2(2.0, -2.0)
	_world.set_terrain(_state.player.tile(), Tile.Terrain.GRASS)
	dog.facing = -1.0

	var turns := _count_turns(dog, WATCH_SECONDS)

	assert_lte(turns, MOST_TURNS)
	assert_eq(dog.facing, 1.0, "it faces the player")
	assert_gt(dog.position.y, float(_middle.y + FENCE_ROW + 1), "it did not get across")


func test_an_animal_walks_round_the_end_of_a_short_fence_to_its_goal() -> void:
	for x in [-PEN_RADIUS, -PEN_RADIUS + 1, -1, 1, PEN_RADIUS - 1, PEN_RADIUS]:
		_world.remove_object(_middle + Vector2i(x, FENCE_ROW))
	for species in [LivestockRules.HORSE, LivestockRules.CAT]:
		var animal := _animal_at_fence(species)
		animal.activity = FarmAnimal.Activity.WALK
		animal.seconds_left = 60.0
		var goal := _pen_middle() + Vector2(1.5, -1.5)
		animal.goal = goal
		animal.goal_need = &"thirst"
		animal.goal_source = Vector2i(goal.floor())

		_run(10.0)

		assert_eq(animal.position, goal, "%s walked round the fence to its goal" % species)
		_livestock.remove_species(species)
