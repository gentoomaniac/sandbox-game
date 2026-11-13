extends CropRaidCase
## What a scarecrow guards (task 226): the crops within its radius, fully at first, then less as
## the crows get used to it, and not at all once it is taken down or out of reach.

var _scarecrows: Scarecrows


func before_each() -> void:
	super.before_each()
	_scarecrows = Scarecrows.new(_world, CropRaidRules.new(SURE))


func test_the_rules_of_the_data_file_have_the_scarecrow() -> void:
	var rules := CropRaidRules.default_rules()
	assert_true(rules.is_valid(), "missing: %s" % [rules.problems()])
	assert_gt(rules.value("scarecrow_radius_tiles"), 0.0)
	assert_gt(rules.scarecrow_strength(0), rules.scarecrow_strength(1000))
	assert_gt(rules.scarecrow_strength(1000), 0.0, "the floor is more than nothing")


func test_a_scarecrow_guards_fully_for_its_first_days_then_less_down_to_a_floor() -> void:
	var rules := CropRaidRules.new(SURE)
	var fresh := int(rules.value("scarecrow_fresh_days"))
	var fade := int(rules.value("scarecrow_fade_days"))
	assert_eq(rules.scarecrow_strength(0), 1.0)
	assert_eq(rules.scarecrow_strength(fresh), 1.0)
	assert_lt(rules.scarecrow_strength(fresh + 1), 1.0)
	assert_gt(rules.scarecrow_strength(fresh + 1), rules.scarecrow_strength(fresh + 2))
	assert_almost_eq(rules.scarecrow_strength(fresh + fade), rules.value("scarecrow_floor"), 0.001)
	assert_almost_eq(
		rules.scarecrow_strength(fresh + fade + 50), rules.value("scarecrow_floor"), 0.001
	)


func test_a_scarecrow_guards_the_tiles_within_its_radius_only() -> void:
	var radius := int(CropRaidRules.new(SURE).value("scarecrow_radius_tiles"))
	_put_scarecrow(_tile)
	assert_eq(_scarecrows.strength_at(_tile + Vector2i(radius, 0)), 1.0)
	assert_eq(_scarecrows.strength_at(_tile + Vector2i(radius + 1, 0)), 0.0)
	assert_true(_scarecrows.is_guarding(_tile + Vector2i(radius, 0)))
	assert_false(_scarecrows.is_guarding(_tile + Vector2i(radius + 1, 0)))


func test_the_crows_get_used_to_it_as_the_days_pass() -> void:
	var scarecrow := _put_scarecrow(_tile)
	var strengths: Array[float] = []
	for day in [1, 5, 9, 40]:
		_world.clock.day = day
		strengths.append(_scarecrows.strength_of(scarecrow))
	assert_eq(strengths[0], 1.0)
	assert_gt(strengths[1], strengths[2])
	assert_almost_eq(strengths[3], CropRaidRules.new(SURE).value("scarecrow_floor"), 0.001)


func test_taking_it_down_and_putting_it_up_again_starts_it_anew() -> void:
	_world.clock.day = 40
	_put_scarecrow(_tile, 1)
	assert_lt(_scarecrows.strength_at(_tile), 1.0)
	_world.remove_object(_tile)
	assert_eq(_scarecrows.strength_at(_tile), 0.0, "nothing stands there")
	_put_scarecrow(_tile, 40)
	assert_eq(_scarecrows.strength_at(_tile), 1.0)


func test_the_strongest_scarecrow_counts() -> void:
	_world.clock.day = 40
	_put_scarecrow(_tile, 1)
	_put_scarecrow(_tile + Vector2i(3, 0), 40)
	assert_eq(_scarecrows.strength_at(_tile + Vector2i(1, 0)), 1.0)


func test_a_scarecrow_with_no_day_is_counted_as_new() -> void:
	var scarecrow := _put_scarecrow(_tile)
	scarecrow.state.erase("placed_day")
	assert_eq(_scarecrows.strength_of(scarecrow), 1.0)


func test_the_dice_of_a_tile_are_the_same_all_day() -> void:
	_world.clock.day = 40
	_put_scarecrow(_tile, 1)
	for x in 10:
		var tile := _tile + Vector2i(x % 5, 0)
		assert_eq(_scarecrows.is_guarding(tile), _scarecrows.is_guarding(tile))


func test_a_floor_guards_some_of_the_tiles_and_not_all() -> void:
	_world.clock.day = 400
	_put_scarecrow(_tile, 1)
	var guarded := 0
	var tiles := 0
	for y in range(-4, 5):
		for x in range(-4, 5):
			tiles += 1
			guarded += 1 if _scarecrows.is_guarding(_tile + Vector2i(x, y)) else 0
	assert_gt(guarded, 0)
	assert_lt(guarded, tiles)


func test_a_raid_leaves_the_guarded_crops_and_takes_the_others() -> void:
	_plant_row(&"turnip", 0)
	_raids = _raids_with({"reach_tiles": FIELD_WIDTH, "crops_per_raid": FIELD_WIDTH})
	_raids.is_guarded = _scarecrows.is_guarding
	# Beside the row's east end, a tile off it: the 5 crops nearest are in its radius of 5.
	_put_scarecrow(_tile + Vector2i(FIELD_WIDTH - 1, 1))
	_raids.add_flock(_tile)
	_raids.raid_hour(HOUR)
	assert_eq(_crops_left(), 5)


func test_the_game_lets_its_scarecrows_guard_the_crops_of_its_raids() -> void:
	_put_scarecrow(_tile)
	assert_true(_state.crop_raids.is_guarded.call(_tile + Vector2i(1, 0)))
	assert_false(_state.crop_raids.is_guarded.call(_tile + Vector2i(50, 0)))


func test_a_scarecrow_in_a_saved_game_still_guards() -> void:
	_put_scarecrow(_tile, 3)
	var kept := _through_save()
	assert_eq(kept.scarecrows.strength_at(_tile), 1.0)
	assert_eq(kept.world.scarecrows().size(), 1)


func _put_scarecrow(tile: Vector2i, placed_day := 1) -> WorldObject:
	_world.remove_object(tile)
	var scarecrow := WorldObject.new(WorldObjectTypes.SCARECROW, tile)
	scarecrow.state["placed_day"] = placed_day
	_world.add_object(scarecrow)
	_world.change_object(scarecrow)
	return scarecrow
