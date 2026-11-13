extends WildlifeCase
## The heart and the anger mark over a petted animal's head (task 173): the view of the animal shows
## the one Livestock says, and it is gone after a moment.

const SPOT := Vector2(2.5, 5.5)

var _cow: FarmAnimal
var _cow_view: FarmAnimalView


func before_each() -> void:
	super()
	_cow = FarmAnimal.new(LivestockRules.COW, &"angler", SPOT)
	_state.livestock.add(_cow)
	_wildlife._show_farm_animal_if_near(_cow)
	_cow_view = _wildlife._farm_animals[_cow]
	_state.livestock.petted.connect(_wildlife._show_pet_reaction)


func _reactions() -> Array[PetReaction]:
	var found: Array[PetReaction] = []
	for child in _cow_view.get_children():
		if child is PetReaction:
			found.append(child)
	return found


func test_a_heart_rises_over_the_head_of_an_animal_petted_awake() -> void:
	_state.livestock.pet(_cow, _state.clock)

	var reactions := _reactions()
	assert_eq(reactions.size(), 1)
	assert_eq(reactions[0].texture.resource_path, "res://assets/effects/pet_heart.png")
	assert_eq(reactions[0].position, Vector2(26, -41), "just above a standing cow's head")
	assert_eq(reactions[0].offset.y, -reactions[0].texture.get_height() / 2.0, "standing on it")


func test_the_anger_mark_rises_over_an_animal_petted_asleep() -> void:
	_cow.activity = FarmAnimal.Activity.SLEEP

	_state.livestock.pet(_cow, _state.clock)

	assert_eq(_reactions()[0].texture.resource_path, "res://assets/effects/pet_annoyed.png")
	assert_eq(_reactions()[0].position, Vector2(26, -29), "lower, over a cow lying down")


func test_a_heart_rises_over_the_rooster_at_his_own_height() -> void:
	var rooster := FarmAnimal.new(LivestockRules.CHICKEN, LivestockRules.ROOSTER_LOOK, SPOT)
	_state.livestock.add(rooster)
	_wildlife._show_farm_animal_if_near(rooster)
	var view: FarmAnimalView = _wildlife._farm_animals[rooster]

	_state.livestock.pet(rooster, _state.clock)

	var found: Array[PetReaction] = []
	for child in view.get_children():
		if child is PetReaction:
			found.append(child)
	assert_eq(found.size(), 1)
	assert_eq(found[0].position, Vector2(8, -34), "over his comb, higher than over a hen")


func test_a_petting_that_shows_nothing_adds_nothing() -> void:
	_state.livestock.pet(_cow, _state.clock)
	_state.livestock.pet(_cow, _state.clock)

	assert_eq(_reactions().size(), 1)


func test_the_reaction_is_gone_after_its_seconds() -> void:
	_state.livestock.pet(_cow, _state.clock)

	await get_tree().create_timer(PetReaction.SECONDS + 0.3).timeout

	assert_eq(_reactions().size(), 0)


func test_every_species_has_a_head_for_each_pose() -> void:
	for species in LivestockRules.SPECIES:
		assert_eq(FarmAnimalView.HEADS[species].size(), 3, str(species))
	for kind: StringName in FarmAnimalView.LOOK_HEADS:
		assert_true(WildlifeSprites.SHEETS.has(kind), str(kind))
		assert_eq(FarmAnimalView.LOOK_HEADS[kind].size(), 3, str(kind))
