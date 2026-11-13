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


func test_a_flock_on_the_ground_tells_the_crop_raids_where_it_stands_until_it_flies_off() -> void:
	var raids := _state.crop_raids
	var flock := _flock()
	assert_eq(raids.flock_tiles().size(), 1)
	assert_eq(raids.flock_tiles()[0], Vector2i((flock.position / TerrainTileset.TILE_SIZE).floor()))
	flock.dismiss()
	assert_eq(raids.flock_tiles().size(), 0)


func test_a_flock_that_is_taken_away_leaves_the_crop_raids() -> void:
	_flock()
	_wildlife.remove_kind(WildlifeRules.CROWS)
	await get_tree().process_frame
	assert_eq(_state.crop_raids.flock_tiles().size(), 0)


func test_other_flocks_do_not_tell_the_crop_raids() -> void:
	_wildlife.spawn_in_view(WildlifeRules.GEESE, 1)
	assert_eq(_state.crop_raids.flock_tiles().size(), 0)


func test_crows_are_drawn_to_fresh_sowing_and_less_to_the_rest_of_the_land() -> void:
	var point := Vector2(80.0, 160.0)
	var tile := Vector2i((point / TerrainTileset.TILE_SIZE).floor())
	var bare := 0
	for _i in 300:
		bare += int(_wildlife._is_drawn_to(WildlifeRules.CROWS, point))
	assert_between(bare, 60, 140, "about a third of the time")
	for x in range(-3, 4):
		for y in range(-3, 4):
			var pos := tile + Vector2i(x, y)
			_state.world.remove_object(pos)
			_state.world.set_terrain(pos, Tile.Terrain.SOIL)
			_state.world.add_object(WorldObject.new(&"turnip", pos))
	var sown := 0
	for _i in 300:
		sown += int(_wildlife._is_drawn_to(WildlifeRules.CROWS, point))
	assert_eq(sown, 300)
	assert_true(_wildlife._is_drawn_to(WildlifeRules.GEESE, point))
