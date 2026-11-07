extends ResourceCase
## The saddle: the use key puts it on the horse in front of the player, and with an empty hand
## takes it off again, back into the inventory (the empty hand's slot always has room for it). A
## horse keeps it through a save.


func _put_horse_on_target() -> FarmAnimal:
	var horse := FarmAnimal.new(LivestockRules.HORSE, &"bay", Vector2(_tile) + Vector2(0.5, 0.6))
	_state.livestock.add(horse)
	return horse


## Empties the selected slot: the hand holds nothing.
func _hold_nothing() -> void:
	_state.player.inventory.slots[_state.player.inventory.selected_slot] = {}


func test_the_console_gives_a_saddle() -> void:
	var lines := Console.new(_state).run("give saddle")
	assert_eq(lines, ["Gave 1 Saddle"] as Array[String])
	assert_eq(_count(ItemTypes.SADDLE), 1)


func test_the_saddle_goes_on_the_horse_in_front() -> void:
	var horse := _put_horse_on_target()
	_state.player.inventory.add(ItemTypes.SADDLE, 1)
	_hold(ItemTypes.SADDLE)

	assert_true(_state.can_use_held_item())
	assert_eq(_state.use_facing_tile(), ToolUse.Use.SADDLE)

	assert_true(horse.is_saddled)
	assert_eq(_count(ItemTypes.SADDLE), 0)


func test_a_saddle_does_nothing_on_a_saddled_horse_or_a_cow() -> void:
	var horse := _put_horse_on_target()
	horse.is_saddled = true
	_state.player.inventory.add(ItemTypes.SADDLE, 1)
	_hold(ItemTypes.SADDLE)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)

	_state.livestock = Livestock.new(_state.sun)
	var cow := FarmAnimal.new(LivestockRules.COW, &"angler", Vector2(_tile) + Vector2(0.5, 0.5))
	_state.livestock.add(cow)
	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_count(ItemTypes.SADDLE), 1)


func test_an_empty_hand_takes_the_saddle_off() -> void:
	var horse := _put_horse_on_target()
	horse.is_saddled = true
	_hold_nothing()

	assert_eq(_state.use_facing_tile(), ToolUse.Use.UNSADDLE)

	assert_false(horse.is_saddled)
	assert_eq(_count(ItemTypes.SADDLE), 1)


func test_the_saddle_is_saved() -> void:
	_put_horse_on_target().is_saddled = true
	var restored := _through_save()
	assert_true(restored.livestock.all()[0].is_saddled)
