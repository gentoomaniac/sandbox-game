extends LivestockCase
## Farm animals keep off the tiles of buildings, the door included, which the player walks in by.


func _house_in_the_pen() -> Building:
	var origin := _middle + Vector2i(-1, -3)
	for y in range(-1, 10):
		for x in range(-1, 10):
			_world.remove_object(origin + Vector2i(x, y))
			_world.set_terrain(origin + Vector2i(x, y), Tile.Terrain.GRASS)
	var house := _world.place_building(BuildingTypes.KATE, origin)
	assert_not_null(house)
	return house


func _sheep_in_front_of(house: Building) -> FarmAnimal:
	var sheep := FarmAnimal.new(
		LivestockRules.SHEEP,
		&"white",
		Vector2(house.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5)
	)
	_livestock.add(sheep)
	_livestock.stand_still(sheep)
	return sheep


func test_the_door_is_walkable_for_the_player_and_not_for_the_animals() -> void:
	var house := _house_in_the_pen()
	assert_true(_world.is_walkable(house.door_tile()))
	assert_false(_world.is_walkable_for_animals(house.door_tile()))


func test_animals_never_stand_on_a_building_in_play_or_over_a_skip() -> void:
	var house := _house_in_the_pen()
	var sheep := _sheep_in_front_of(house)
	for _step_index in 2000:
		_step()
		assert_false(house.tiles().has(sheep.tile()), "at %s" % sheep.position)
	for seed_value in 20:
		_livestock.catch_up(_world, _state.clock, _state.player.position, seed_value, 600)
		assert_false(house.tiles().has(sheep.tile()), "at %s" % sheep.position)


func test_an_animal_found_in_a_doorway_is_put_off_the_building_by_a_skip() -> void:
	var house := _house_in_the_pen()
	var sheep := _sheep_in_front_of(house)
	for seed_value in 100:
		sheep.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
		_livestock.catch_up(_world, _state.clock, _state.player.position, seed_value, 600)
		assert_false(
			house.tiles().has(sheep.tile()), "seed %d at %s" % [seed_value, sheep.position]
		)
