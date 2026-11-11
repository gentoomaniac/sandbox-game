extends OutcomeCase
## The use key with an empty hand pets the animal in front of the player (task 173), but only when
## nothing else on the tile has a use for the empty hand: a saddled horse is unsaddled first, a
## gate opens, a ripe crop is picked. Held items keep their own uses, and riding allows no petting.


func _put_animal_on_target(species := LivestockRules.COW) -> FarmAnimal:
	var animal := FarmAnimal.new(
		species, _state.livestock.rules.looks(species)[0], Vector2(_tile) + Vector2(0.5, 0.6)
	)
	_state.livestock.add(animal)
	return animal


func _hold_nothing() -> void:
	_state.player.inventory.slots[_state.player.inventory.selected_slot] = {}


func test_an_empty_hand_pets_the_animal_in_front() -> void:
	var cow := _put_animal_on_target()
	_hold_nothing()

	assert_true(_state.can_use_held_item())
	assert_eq(_state.use_at(_tile), ToolUse.Use.PET)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PET)

	assert_eq(cow.friendship, 10)
	_assert_one(ActionOutcome.PET, _tile, LivestockRules.COW)


func test_petting_costs_no_energy() -> void:
	_put_animal_on_target()
	_hold_nothing()
	var energy := _state.player.energy

	_state.use_facing_tile()

	assert_eq(_state.player.energy, energy)


func test_a_second_petting_is_still_a_use_but_changes_nothing() -> void:
	var cow := _put_animal_on_target()
	_hold_nothing()
	_state.use_facing_tile()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.PET)

	assert_eq(cow.friendship, 10)


func test_a_sleeping_animal_is_petted_with_its_own_outcome() -> void:
	var cow := _put_animal_on_target()
	cow.friendship = 20
	cow.activity = FarmAnimal.Activity.SLEEP
	_hold_nothing()

	_state.use_facing_tile()

	assert_eq(cow.friendship, 15)
	_assert_one(ActionOutcome.PET_ASLEEP, _tile, LivestockRules.COW)


func test_nothing_is_there_to_pet_on_a_bare_tile_or_with_an_animal_too_far() -> void:
	_hold_nothing()
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)

	_put_animal_on_target().position += Vector2(3.0, 0.0)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)


func test_a_tame_rabbit_is_petted_too() -> void:
	var rabbit := _put_animal_on_target(LivestockRules.RABBIT)
	_hold_nothing()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.PET)
	assert_eq(rabbit.friendship, 10)


func test_a_saddled_horse_is_unsaddled_before_it_is_petted() -> void:
	var horse := _put_animal_on_target(LivestockRules.HORSE)
	horse.is_saddled = true
	_hold_nothing()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.UNSADDLE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.PET, "then it is a horse like another")


func test_a_pen_gate_opens_before_an_animal_in_it_is_petted() -> void:
	_put_animal_on_target()
	_world.add_object(WorldObject.new(WorldObjectTypes.PEN_GATE, _tile))
	_hold_nothing()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.GATE)


func test_the_held_items_keep_their_uses() -> void:
	var dog := _put_animal_on_target(LivestockRules.DOG)
	_state.player.inventory.add(ItemTypes.BONE, 1)
	_hold(ItemTypes.BONE)

	assert_eq(_state.use_facing_tile(), ToolUse.Use.GIVE_BONE)
	assert_eq(dog.friendship, 0)

	_state.player.inventory.add(ItemTypes.HOE, 1)
	_hold(ItemTypes.HOE)
	assert_ne(_state.use_facing_tile(), ToolUse.Use.PET)


func test_the_player_on_horseback_pets_nothing() -> void:
	var horse := _put_animal_on_target(LivestockRules.HORSE)
	_state.player.horse = horse
	_hold_nothing()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.RIDING)
	assert_eq(horse.friendship, 0)
