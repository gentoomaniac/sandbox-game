extends WildlifeCase
## The wild ground animals carry a friendship with the player that is 0 and stays 0 (task 173): it
## is not for birds or insects, the use key never pets a wild animal, and none of it is saved.

const BIRDS_AND_INSECTS: Array[StringName] = [
	WildlifeRules.BIRD,
	WildlifeRules.STORK,
	WildlifeRules.BEE,
	WildlifeRules.BUTTERFLY,
	WildlifeRules.FIREFLY,
	WildlifeRules.GEESE,
	WildlifeRules.GULL,
	WildlifeRules.TERN,
	WildlifeRules.OYSTERCATCHER,
	WildlifeRules.DUNLIN,
]


func _spawn_at(kind: StringName, tile: Vector2i) -> Animal:
	_wildlife._spawn(kind, TerrainTileset.tile_centre(tile), true)
	return _wildlife._animals.back()


func test_the_wild_ground_animals_have_a_friendship_of_zero() -> void:
	for kind in WildlifeRules.GROUND_KINDS:
		var animal := _spawn_at(kind, Vector2i(3, 5))
		assert_true(animal.has_friendship(), str(kind))
		assert_eq(animal.friendship, 0, str(kind))


func test_birds_and_insects_have_none() -> void:
	for kind in BIRDS_AND_INSECTS:
		assert_false(_spawn_at(kind, Vector2i(3, 5)).has_friendship(), str(kind))


func test_the_tame_rabbit_is_not_mistaken_for_the_wild_one() -> void:
	var tame := FarmAnimal.new(LivestockRules.RABBIT, &"agouti", Vector2(3.5, 5.5))
	_state.livestock.add(tame)
	_wildlife._show_farm_animal_if_near(tame)

	assert_false(_wildlife._farm_animals[tame].has_friendship(), "its value is the FarmAnimal's")
	assert_true(_spawn_at(WildlifeRules.RABBIT, Vector2(3, 5)).has_friendship())


func test_the_wild_kinds_are_not_in_the_list_of_those_that_can_be_petted() -> void:
	for kind in WildlifeRules.GROUND_KINDS:
		assert_true(WildlifeRules.KINDS.has(kind), str(kind))
	assert_false(LivestockRules.default_rules().is_pettable(WildlifeRules.DEER))
	assert_false(LivestockRules.default_rules().is_pettable(WildlifeRules.SQUIRREL))


func test_the_use_key_never_pets_a_wild_animal() -> void:
	var tile := _state.player.tile() + Vector2i(1, 0)
	for kind in WildlifeRules.GROUND_KINDS:
		var animal := _spawn_at(kind, tile)
		_state.player.inventory.slots[_state.player.inventory.selected_slot] = {}

		assert_ne(_state.use_at(tile), ToolUse.Use.PET, str(kind))
		assert_eq(animal.friendship, 0)


func test_nothing_about_wild_animals_is_saved() -> void:
	for kind in WildlifeRules.GROUND_KINDS:
		_spawn_at(kind, Vector2i(3, 5))

	assert_false(JSON.stringify(_state.to_dict()).contains("friendship"))
