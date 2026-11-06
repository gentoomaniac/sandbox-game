extends LivestockCase
## A dog given a bone follows the player: it catches up and waits near them, day and night,
## is put beside them when it is left far behind or stuck, and wanders again once its time
## is up.


func _following_dog() -> FarmAnimal:
	var dog := FarmAnimal.new(LivestockRules.DOG, &"collie", _pen_middle() + Vector2(-2.0, 0.0))
	_livestock.add(dog)
	_state.clock.day = DAY
	_state.clock.minute_of_day = NOON
	_livestock.start_following(dog, _state.clock.total_minutes())
	return dog


func test_a_following_dog_catches_up_and_keeps_near_the_player() -> void:
	var dog := _following_dog()
	_state.player.position = _pen_middle() + Vector2(2.0, 0.0)

	_run(3.0)

	var rules := _livestock.rules
	var distance := dog.position.distance_to(_state.player.position)
	assert_lte(distance, rules.general("follow_far_tiles"))
	assert_eq(dog.activity, FarmAnimal.Activity.IDLE, "it waits beside the player")


func test_a_following_dog_does_not_sleep_at_night() -> void:
	var dog := _following_dog()
	_state.player.position = _pen_middle()
	_run(1.0, MIDNIGHT)
	assert_ne(dog.activity, FarmAnimal.Activity.SLEEP)


func test_a_dog_left_far_behind_is_put_beside_the_player() -> void:
	var dog := _following_dog()
	_state.player.position = _pen_middle() + Vector2(0.0, 30.0)
	_world.set_terrain(_state.player.tile(), Tile.Terrain.GRASS)

	_step()

	assert_lte(
		dog.position.distance_to(_state.player.position),
		_livestock.rules.general("follow_far_tiles")
	)


func test_a_dog_stuck_behind_water_is_put_beside_the_player() -> void:
	var dog := _following_dog()
	# Just beyond the water round the pen, too near to count as left behind.
	_state.player.position = _pen_middle() + Vector2(PEN_RADIUS + 2.5, 0.0)
	_world.set_terrain(_state.player.tile(), Tile.Terrain.GRASS)

	_run(6.0)

	assert_lte(
		dog.position.distance_to(_state.player.position),
		_livestock.rules.general("follow_far_tiles")
	)


func test_a_dog_is_put_only_where_its_nose_is_on_dry_ground_too() -> void:
	var dog := _following_dog()
	# Two dry tiles side by side in the water: only standing on one, facing the other, will do.
	for y in range(-PEN_RADIUS, PEN_RADIUS + 1):
		for x in range(-PEN_RADIUS, PEN_RADIUS + 1):
			_world.set_terrain(_middle + Vector2i(x, y), Tile.Terrain.WATER)
	_world.set_terrain(_middle, Tile.Terrain.GRASS)
	_world.set_terrain(_middle + Vector2i.LEFT, Tile.Terrain.GRASS)
	_state.player.position = _pen_middle() + Vector2(0.3, 0.0)

	for _try in 20:
		dog.position = _pen_middle() + Vector2(0.0, 30.0)
		_step()
		var nose := dog.position + Vector2(dog.facing * _livestock.rules.body_tiles(dog.species), 0)
		assert_lt(dog.position.distance_to(_state.player.position), 2.5, "beside the player")
		assert_true(_world.is_walkable(dog.tile()), "feet on %s" % dog.tile())
		assert_true(_world.is_walkable(Vector2i(nose.floor())), "nose at %s" % nose)


func test_once_its_time_is_up_the_dog_wanders_again() -> void:
	var dog := _following_dog()
	_state.player.position = _pen_middle() + Vector2(0.0, 30.0)
	var after := NOON + int(_livestock.rules.general("follow_minutes")) + 1
	var before := dog.position

	_step(after)

	assert_lt(dog.position.distance_to(before), 1.0, "it was not put beside the player")
