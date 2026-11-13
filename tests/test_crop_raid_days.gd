extends CropRaidCase
## The crows' raids over time: the caps of a day, the hours, the flocks coming and going, the crops
## of unloaded chunks, and what sowing draws.


func test_a_day_has_its_caps_and_the_next_day_its_own() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"max_plants_per_day": 3, "reach_tiles": FIELD_WIDTH})
	_raids.add_flock(_tile)
	for hour in 5:
		_raids.raid_hour(HOUR + hour)
	assert_eq(_crops_left(), FIELD_WIDTH - 3)
	_raids.raid_hour(HOUR + CropLife.HOURS_PER_DAY)
	assert_eq(_crops_left(), FIELD_WIDTH - 5, "the next day: two more")
	assert_eq(_raids.plants_eaten_today, 2)


func test_the_cap_of_items_stops_the_eating_of_produce() -> void:
	_plant_row(&"wheat", 3)
	_raids = _raids_with({"max_items_per_day": 1})
	_raids.add_flock(_tile)
	for hour in 5:
		_raids.raid_hour(HOUR + hour)
	assert_eq(_items_eaten(), 1)


func test_the_same_hour_of_the_same_world_eats_the_same() -> void:
	var chances := {"hour_chance": 0.6, "stage_chances": [0.5, 0.5, 0.5, 0.5]}
	var eaten_by_world: Array[Array] = []
	for _world_number in 2:
		before_each()
		_plant_row(&"turnip", 0)
		_raids = _raids_with(chances)
		_raids.add_flock(_tile)
		for hour in 6:
			_raids.raid_hour(HOUR + hour)
		var standing: Array[int] = []
		for crop in _field:
			standing.append(int(_world.object_at(crop.pos) != null))
		eaten_by_world.append(standing)
	assert_eq(eaten_by_world[0], eaten_by_world[1])
	assert_has(eaten_by_world[0], 0, "something was eaten")
	assert_has(eaten_by_world[0], 1, "not everything")


func test_crops_of_an_unloaded_chunk_are_not_raided() -> void:
	_plant_row(&"turnip", 0)
	_raids.add_flock(_tile)
	_world.remove_chunk(Chunk.world_to_chunk(_tile))
	_raids.raid_hour(HOUR)
	assert_eq(_raids.plants_eaten_today, 0)
	assert_eq(_world.crops().size(), FIELD_WIDTH)


func test_a_flock_that_left_raids_no_more() -> void:
	_plant_row(&"turnip", 0)
	var flock := _raids.add_flock(_tile)
	_raids.remove_flock(flock)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH)
	assert_eq(_raids.flock_tiles().size(), 0)


func test_a_moved_flock_raids_where_it_is() -> void:
	_plant_row(&"turnip", 0, 1)
	var flock := _raids.add_flock(_tile + Vector2i(30, 30))
	_raids.move_flock(flock, _tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), 0)


func test_the_end_of_an_hour_is_a_raid_and_the_middle_of_one_is_not() -> void:
	_plant_row(&"turnip", 0, 1)
	_raids.add_flock(_tile)
	_state.clock.minute_of_day = 10 * GameClock.MINUTES_PER_HOUR + 30
	_raids.advance(30, _state.clock)
	assert_eq(_crops_left(), 1)
	_state.clock.minute_of_day = 11 * GameClock.MINUTES_PER_HOUR
	_raids.advance(30, _state.clock)
	assert_eq(_crops_left(), 0)


func test_sown_fields_make_a_flock_likelier_up_to_a_limit() -> void:
	assert_eq(_raids.appearing_boost(_tile), 1.0)
	_plant_row(&"turnip", 0)
	# Seven of the eight crops stand within the six tiles of the rules.
	assert_almost_eq(_raids.appearing_boost(_tile), 1.7, 0.0001)
	_raids = _raids_with({"sown_boost_max": 1.5})
	assert_eq(_raids.appearing_boost(_tile), 1.5)


func test_a_grown_crop_draws_no_flock() -> void:
	_plant_row(&"wheat", 2)
	assert_eq(_raids.appearing_boost(_tile), 1.0)


func test_the_description_says_where_the_flocks_are_and_what_they_ate() -> void:
	assert_eq(_raids.describe()[0], "No crow flocks")
	_plant_row(&"turnip", 0)
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	var lines := _raids.describe()
	assert_string_contains(lines[0], "Flock 1 at %d, %d" % [_tile.x, _tile.y])
	assert_string_contains(lines[1], "ate 2 of 100 plants")
