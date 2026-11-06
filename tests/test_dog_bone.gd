extends ResourceCase
## A bone given to a dog: the use key on a dog in front of the player uses it up, and the dog
## then follows them for a while.


func _put_dog_on_target() -> FarmAnimal:
	var dog := FarmAnimal.new(LivestockRules.DOG, &"collie", Vector2(_tile) + Vector2(0.5, 0.6))
	_state.livestock.add(dog)
	return dog


func test_a_bone_given_to_the_dog_in_front_is_used_up_and_the_dog_follows() -> void:
	var dog := _put_dog_on_target()
	_state.player.inventory.add(ItemTypes.BONE, 2)
	_hold(ItemTypes.BONE)
	_state.clock.advance(100)
	var now := _state.clock.total_minutes()

	assert_true(_state.can_use_held_item())
	assert_eq(_state.use_facing_tile(), ToolUse.Use.GIVE_BONE)

	assert_eq(_count(ItemTypes.BONE), 1)
	var follow_minutes := int(_state.livestock.rules.general("follow_minutes"))
	assert_eq(dog.follow_until_minute, now + follow_minutes)


func test_a_bone_does_nothing_without_a_dog() -> void:
	var cat := FarmAnimal.new(LivestockRules.CAT, &"tabby", Vector2(_tile) + Vector2(0.5, 0.5))
	_state.livestock.add(cat)
	_state.player.inventory.add(ItemTypes.BONE, 1)
	_hold(ItemTypes.BONE)

	assert_eq(_state.use_facing_tile(), ToolUse.Use.NOTHING)
	assert_eq(_count(ItemTypes.BONE), 1)
	assert_eq(cat.follow_until_minute, 0)


func test_the_console_gives_bones() -> void:
	var lines := Console.new(_state).run("give bone 3")
	assert_eq(lines, ["Gave 3 Bone"] as Array[String])
	assert_eq(_count(ItemTypes.BONE), 3)


func test_the_follow_time_is_saved() -> void:
	var dog := _put_dog_on_target()
	dog.follow_until_minute = 1234
	var restored := _through_save()
	assert_eq(restored.livestock.all()[0].follow_until_minute, 1234)
