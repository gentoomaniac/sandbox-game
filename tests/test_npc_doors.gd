extends NpcCase
## Villagers and doors: they stand in front of a door, never on a building tile, in play, over
## a skip and when found in a doorway.


## Places a house in the yard, and returns it.
func _place_house() -> Building:
	var house := _world.place_building(BuildingTypes.KATE, _middle + Vector2i(-3, -5))
	assert_not_null(house)
	return house


func _in_front_of(house: Building) -> Vector2:
	return Vector2(house.door_tile() + Vector2i.DOWN) + Vector2(0.5, 0.5)


func test_a_villager_at_a_door_never_stands_on_a_building_tile() -> void:
	var house := _place_house()
	var npcs: Array[Npc] = []
	for index in 6:
		npcs.append(_add_villager(_in_front_of(house) + Vector2(index - 3, 0), _in_front_of(house)))
	for _step_index in int(240.0 / STEP_SECONDS):
		_step()
		for npc in npcs:
			assert_false(
				PlayerState.touches_building(_world, npc.position),
				"on a building at %s" % npc.position
			)


func test_a_catch_up_never_puts_a_villager_on_a_building_tile() -> void:
	var house := _place_house()
	for index in 10:
		_add_villager(_in_front_of(house), _in_front_of(house))
	for seed_value in 20:
		_npcs.catch_up(_world, seed_value)
		for npc in _npcs.all():
			assert_false(PlayerState.touches_building(_world, npc.position), str(npc.position))


func test_a_villager_found_in_a_doorway_is_moved_to_the_tile_in_front() -> void:
	var house := _place_house()
	var npc := _add_villager(Vector2(house.door_tile()) + Vector2(0.5, 0.5), _in_front_of(house))
	_npcs.catch_up(_world, SEED)
	assert_false(PlayerState.touches_building(_world, npc.position))
	assert_lte(
		npc.position.distance_to(_in_front_of(house)), _npcs.rules.behaviour("anchor_radius")
	)
	var other := _add_villager(Vector2(house.door_tile()) + Vector2(0.5, 0.5), _in_front_of(house))
	_step()
	assert_eq(other.position, _in_front_of(house))


func test_villagers_are_not_spawned_on_a_building() -> void:
	var house := _place_house()
	_npcs.spawn(20, house.centre(), _world)
	for npc in _npcs.all():
		assert_false(PlayerState.touches_building(_world, npc.position))
