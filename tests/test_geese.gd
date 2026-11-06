extends WildlifeCase
## Geese in the view: a grazing flock keeps together, raises its heads as one when the player
## comes near and takes off as one when nearer, closing up into a V; a skein crosses the view in
## a V and is gone.


func _flock() -> GooseFlock:
	_wildlife.spawn_in_view(WildlifeRules.GEESE, 1)
	return _animals_of(GooseFlock)[0]


func _walk_player_to(distance_tiles: float, flock: GooseFlock) -> void:
	_wildlife.world_view.player_feet = (
		flock.position + Vector2(distance_tiles * TerrainTileset.TILE_SIZE, 0.0)
	)


func test_a_flock_has_six_to_twelve_geese_spread_around_its_middle() -> void:
	var flock := _flock()
	assert_between(flock._geese.size(), GooseFlock.FLOCK_SIZE.x, GooseFlock.FLOCK_SIZE.y)
	for goose in flock._geese:
		assert_lte(goose.spot.length(), GooseFlock.RADIUS)


func test_grazing_geese_keep_together() -> void:
	var flock := _flock()
	_run(flock, 60.0)
	assert_eq(flock._state, GooseFlock.GRAZE)
	for goose in flock._geese:
		assert_lte(goose.spot.length(), GooseFlock.RADIUS + 0.01)
		assert_true(_wildlife.can_stand(flock.position + goose.spot), "on dry land")


func test_the_whole_flock_looks_up_then_takes_off_together() -> void:
	var flock := _flock()
	_wildlife.is_player_ignored = false
	_walk_player_to(8.0, flock)
	_run(flock, STEP)
	assert_eq(flock._state, GooseFlock.ALERT)
	for goose in flock._geese:
		assert_eq(goose.action, &"stand", "every head up")
	_walk_player_to(5.0, flock)
	_run(flock, STEP)
	assert_eq(flock._state, GooseFlock.FLY)
	for goose in flock._geese:
		assert_eq(goose.action, &"fly", "all at once")


func test_the_alarm_passes_when_the_player_goes_away() -> void:
	var flock := _flock()
	_wildlife.is_player_ignored = false
	_walk_player_to(8.0, flock)
	_run(flock, STEP)
	_walk_player_to(12.0, flock)
	_run(flock, STEP)
	assert_eq(flock._state, GooseFlock.GRAZE)


func test_in_the_air_they_close_up_into_a_v_and_fly_out_of_the_view() -> void:
	var flock := _flock()
	flock.dismiss()
	_run(flock, GooseFlock.FORMING_SECONDS + STEP)
	var heading := flock._flight_direction
	var v_spots := Flock.v_offsets(heading, flock._geese.size(), GooseFlock.V_SPACING)
	for i in flock._geese.size():
		assert_almost_eq(flock._geese[i].spot, v_spots[i], Vector2(0.01, 0.01))
	_run(flock, GooseFlock.FLIGHT_HEIGHT / GooseFlock.CLIMB_SPEED)
	assert_almost_eq(flock._lift, GooseFlock.FLIGHT_HEIGHT, 0.01, "up at their height")
	_run(flock, 60.0)
	assert_true(flock.is_done)


func test_a_v_has_its_leader_ahead_and_the_others_in_pairs_behind() -> void:
	var offsets := Flock.v_offsets(Vector2.RIGHT, 5, Vector2(10.0, 8.0))
	assert_eq(offsets[0], Vector2.ZERO)
	assert_eq(offsets[1], Vector2(-10.0, 8.0))
	assert_eq(offsets[2], Vector2(-10.0, -8.0))
	assert_eq(offsets[3], Vector2(-20.0, 16.0))
	assert_eq(offsets[4], Vector2(-20.0, -16.0))


func test_a_skein_of_geese_crosses_the_view_high_up_and_is_gone() -> void:
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.FLYING_GEESE, 1), 1)
	var skein: Flock = _animals_of(Flock)[0]
	assert_between(skein._birds.size(), 7, 13)
	assert_false(skein._is_out_of_view(), "one made by hand starts in view")
	_run(skein, 90.0)
	assert_true(skein.is_done)
