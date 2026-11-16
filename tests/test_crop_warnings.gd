extends CropCase
## The warnings before a loss that can still be stopped: dry soil and ripe crops about to wither,
## as a toast once per field.

var _state: GameState
var _warnings: CropWarnings
var _texts: Array[String] = []
var _player_feet: Vector2


func before_each() -> void:
	_state = GameFactory.new_game(7)
	_warnings = CropWarnings.new(_state.world, func() -> Vector2: return _player_feet)
	_warnings.warned.connect(func(text: String) -> void: _texts.append(text))
	_texts.clear()
	_player_feet = Vector2(3, 3)


func _plant(tile: Vector2i, moisture: float, type := WorldObjectTypes.TURNIP) -> WorldObject:
	var in_the_way := _state.world.object_at(tile)
	if in_the_way != null:
		_state.world.take_off(in_the_way)
	_state.world.set_terrain(tile, Tile.Terrain.SOIL)
	var crop := WorldObject.new(type, tile)
	_state.world.add_object(crop)
	_state.world.set_moisture(tile, moisture)
	return crop


func _dry() -> float:
	return _need(_crop(), "moisture_min")


func _damp() -> float:
	return _best_moisture(_crop())


func test_a_field_of_dry_soil_is_warned_about_once_not_per_tile() -> void:
	for x in 4:
		_plant(Vector2i(x, 3), _dry())

	_warnings.look_at_crops()

	assert_eq(_texts, ["The turnip field is drying out: water it"] as Array[String])


func test_a_field_is_not_warned_about_again_every_hour() -> void:
	_plant(Vector2i(3, 3), _dry())

	_warnings.look_at_crops()
	_warnings.look_at_crops()

	assert_eq(_texts.size(), 1)


func test_a_field_that_was_watered_and_dries_again_is_warned_again() -> void:
	_plant(Vector2i(3, 3), _dry())
	_warnings.look_at_crops()

	_state.world.set_moisture(Vector2i(3, 3), _damp())
	_warnings.look_at_crops()
	_state.world.set_moisture(Vector2i(3, 3), _dry())
	_warnings.look_at_crops()

	assert_eq(_texts.size(), 2)


func test_a_tile_that_dries_in_a_field_already_warned_about_adds_no_warning() -> void:
	_plant(Vector2i(3, 3), _dry())
	_plant(Vector2i(4, 3), _damp())
	_warnings.look_at_crops()

	_state.world.set_moisture(Vector2i(4, 3), _dry())
	_warnings.look_at_crops()

	assert_eq(_texts.size(), 1)


func test_fields_apart_are_warned_about_each() -> void:
	_plant(Vector2i(3, 3), _dry())
	_plant(Vector2i(10, 3), _dry())

	_warnings.look_at_crops()

	assert_eq(_texts.size(), 2)


func test_damp_soil_is_not_warned_about() -> void:
	_plant(Vector2i(3, 3), _damp())

	_warnings.look_at_crops()

	assert_eq(_texts, [] as Array[String])


func test_soil_within_the_margin_of_the_crops_minimum_is_warned_about_before_it_hurts() -> void:
	var margin := CropRules.default_rules().farming("warn_dry_margin")
	_plant(Vector2i(3, 3), _dry() + margin - 0.01)
	_plant(Vector2i(10, 3), _dry() + margin + 0.01)

	_warnings.look_at_crops()

	assert_eq(_texts.size(), 1)


func test_crops_far_from_the_player_are_not_warned_about() -> void:
	_plant(Vector2i(3, 3), _dry())
	_player_feet = Vector2.INF

	_warnings.look_at_crops()

	assert_eq(_texts, [] as Array[String])


func test_a_dead_crop_is_not_warned_about() -> void:
	_plant(Vector2i(3, 3), _dry()).state["crop_damage"] = 1.0

	_warnings.look_at_crops()

	assert_eq(_texts, [] as Array[String])


func test_a_ripe_crop_about_to_wither_is_warned_about() -> void:
	var crop := _plant(Vector2i(3, 3), _damp())
	crop.state["growth"] = 9.0
	crop.state["ripe_at_dawn"] = 1
	crop.state["days_growing"] = 9
	crop.state["days_ripe"] = 9

	_warnings.look_at_crops()

	assert_eq(
		_texts, ["The turnip field is ripe and will wither tonight: harvest it"] as Array[String]
	)


func test_a_ripe_crop_with_days_to_spare_is_not_warned_about() -> void:
	var crop := _plant(Vector2i(3, 3), _damp())
	crop.state["growth"] = 9.0
	crop.state["ripe_at_dawn"] = 1
	crop.state["days_growing"] = 9
	crop.state["days_ripe"] = 2

	_warnings.look_at_crops()

	assert_eq(_texts, [] as Array[String])


func test_an_unripe_crop_is_not_warned_about_withering() -> void:
	_plant(Vector2i(3, 3), _damp())

	_warnings.look_at_crops()

	assert_eq(_texts, [] as Array[String])


func test_the_hours_of_the_simulation_look_at_the_crops() -> void:
	var simulation := Simulation.new(_state.clock)
	simulation.add_system(_warnings)
	_state.clock.set_time(0, 0)
	_plant(Vector2i(3, 3), _dry())

	simulation.advance(30)
	assert_eq(_texts.size(), 0, "the hour is not over")
	simulation.advance(30)

	assert_eq(_texts.size(), 1)
