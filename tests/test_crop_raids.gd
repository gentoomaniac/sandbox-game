extends CropRaidCase
## The crows' raids on the crops: which crops lose what, and when the player or a guard is near.


func test_the_rules_of_the_data_file_are_all_there() -> void:
	var rules := CropRaidRules.default_rules()
	assert_true(rules.is_valid(), "missing: %s" % [rules.problems()])


func test_a_missing_key_is_reported() -> void:
	assert_true(CropRaidRules.new({"hour_chance": 0.5}).problems().has("[raids] no player_tiles"))


func test_a_flock_eats_seeds_whole_up_to_the_crops_it_tries_in_a_raid() -> void:
	_plant_row(&"turnip", 0)
	_raids.add_flock(_tile + Vector2i(1, 0))
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH - 2)
	assert_eq(_raids.plants_eaten_today, 2)


func test_a_grown_crop_loses_an_item_and_keeps_one() -> void:
	_plant_row(&"wheat", 3, 1)
	var wheat := _field[0]
	_raids.add_flock(_tile)
	for hour in 5:
		_raids.raid_hour(HOUR + hour)
	assert_eq(CropLife.eaten(wheat), int(wheat.type_data()["yield"]) - 1)
	assert_eq(_raids.items_eaten_today, CropLife.eaten(wheat))
	assert_eq(_crops_left(), 1, "never taken whole")


func test_a_crop_with_a_yield_of_one_is_left_alone_once_it_is_past_the_seed() -> void:
	_plant_row(&"cabbage", 3, 1)
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_items_eaten(), 0)


func test_a_stage_with_no_chance_loses_nothing() -> void:
	_plant_row(&"wheat", 1)
	_raids = _raids_with({"stage_chances": [1.0, 0.0, 1.0, 1.0]})
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_items_eaten(), 0)


func test_only_the_crops_in_reach_are_raided() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"reach_tiles": 1, "crops_per_raid": 100})
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH - 2, "the flock's tile and the next one")


func test_dead_crops_are_not_eaten() -> void:
	_plant_row(&"wheat", 3, 1)
	_field[0].state["crop_damage"] = 1.0
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_items_eaten(), 0)


func test_a_flock_does_not_raid_with_the_player_near_unless_told_to() -> void:
	_plant_row(&"turnip", 0)
	_player_feet = Vector2(_tile) + Vector2(3.5, 0.5)
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH, "player near")
	_raids.raid_hour(HOUR, true)
	assert_lt(_crops_left(), FIELD_WIDTH, "told to")


func test_a_flock_raids_when_the_player_is_far_off() -> void:
	_plant_row(&"turnip", 0)
	_player_feet = Vector2(_tile) + Vector2(40.0, 0.5)
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_lt(_crops_left(), FIELD_WIDTH)


func test_a_flock_raids_by_the_chance_of_the_hour() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"hour_chance": 0.0})
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH)


func test_a_guarded_crop_is_not_raided() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"reach_tiles": FIELD_WIDTH, "crops_per_raid": FIELD_WIDTH})
	_raids.is_guarded = func(tile: Vector2i) -> bool: return tile != _tile
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), FIELD_WIDTH - 1, "only the unguarded one")
	assert_null(_world.object_at(_tile))


func test_crows_raid_only_where_the_player_is_farther_than_they_fly_off_at() -> void:
	var flee_tiles := WildlifeRules.default_rules().flee_tiles(WildlifeRules.CROWS)
	assert_gt(CropRaidRules.default_rules().value("player_tiles"), flee_tiles)


func test_a_forced_raid_ignores_the_player_and_the_chances_and_takes_every_crop_it_tries() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"hour_chance": 0.0, "stage_chances": [0.0, 0.0, 0.0, 0.0]})
	_player_feet = Vector2(_tile) + Vector2(1.5, 0.5)
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR, true)
	assert_eq(_crops_left(), FIELD_WIDTH - 2)
