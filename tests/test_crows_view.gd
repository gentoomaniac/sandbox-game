extends WildlifeCase
## Crows in the view: a flock pecks and walks about a field, looks up as one when the player comes
## near and flies off in a loose bunch when nearer.

const CROWS: Dictionary = GroundFlock.FLOCKS[WildlifeRules.CROWS]


func _flock() -> GroundFlock:
	_wildlife.spawn_in_view(WildlifeRules.CROWS, 1)
	return _animals_of(GroundFlock)[0]


func _walk_player_to(distance_tiles: float, flock: GroundFlock) -> void:
	_wildlife.world_view.player_feet = (
		flock.position + Vector2(distance_tiles * TerrainTileset.TILE_SIZE, 0.0)
	)


func test_a_flock_of_crows_is_a_few_hooded_crows_about_its_middle() -> void:
	var flock := _flock()
	assert_eq(flock.kind, WildlifeRules.CROWS)
	assert_between(flock._birds.size(), CROWS["size"].x, CROWS["size"].y)
	for crow in flock._birds:
		assert_lte(crow.spot.length(), CROWS["radius"])
		assert_true(_wildlife.can_stand(flock.position + crow.spot), "on the ground")


func test_the_crows_peck_walk_and_stand() -> void:
	var flock := _flock()
	var seen := {}
	for _i in 600:
		_run(flock, STEP)
		for crow in flock._birds:
			seen[crow.action] = true
	assert_true(seen.has(&"peck"))
	assert_true(seen.has(&"walk"))
	assert_true(seen.has(&"stand"))


func test_the_whole_flock_looks_up_then_flies_off_together() -> void:
	var flock := _flock()
	_wildlife.is_player_ignored = false
	_walk_player_to(8.0, flock)
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.ALERT)
	_walk_player_to(4.0, flock)
	_run(flock, STEP)
	assert_eq(flock._state, GroundFlock.FLY)
	for crow in flock._birds:
		assert_eq(crow.action, &"fly")


func test_in_the_air_they_close_up_into_a_bunch_and_leave_the_view() -> void:
	var flock := _flock()
	flock.dismiss()
	_run(flock, GroundFlock.FORMING_SECONDS + STEP)
	for crow in flock._birds:
		assert_almost_eq(
			crow.spot, crow.take_off_spot * GroundFlock.BUNCH_CLOSING, Vector2(0.01, 0.01)
		)
	_run(flock, 60.0)
	assert_true(flock.is_done)
