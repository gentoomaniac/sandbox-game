extends WildlifeCase
## Mice and frogs in the view: a mouse dashes off and is gone into cover when the player comes
## near; a frog sits and hops about, hops off from the player and stops once safe; both are made
## by the spawn command and the debug flag.


func _spawned(kind: StringName) -> Animal:
	assert_eq(_wildlife.spawn_in_view(kind, 1), 1)
	return _wildlife._animals.back()


func _player_beside(animal: Animal, distance_tiles: float) -> void:
	_wildlife.world_view.player_feet = (
		animal.position + Vector2(distance_tiles * TerrainTileset.TILE_SIZE, 0.0)
	)


func test_both_can_be_put_in_view_by_hand() -> void:
	assert_true(_spawned(WildlifeRules.MOUSE) is Mouse)
	assert_true(_spawned(WildlifeRules.FROG) is Frog)


func test_a_mouse_sits_and_scurries_about() -> void:
	var mouse := _spawned(WildlifeRules.MOUSE)
	var states := {}
	mouse.state_entered.connect(func(state: StringName) -> void: states[state] = true)
	_run(mouse, 30.0)
	assert_true(states.has(Mouse.SCURRY))
	assert_true(states.has(Mouse.SIT))
	assert_false(mouse.is_done)


func test_a_mouse_dashes_away_from_the_player_and_is_gone() -> void:
	var mouse := _spawned(WildlifeRules.MOUSE)
	_wildlife.is_player_ignored = false
	_player_beside(mouse, 1.0)
	var start := mouse.position
	_run(mouse, STEP)
	assert_eq(mouse._state, Mouse.FLEE)
	_run(mouse, Mouse.FLEE_SECONDS)
	assert_true(mouse.is_done, "gone into cover")
	# Its way may be blocked at once (it is gone sooner then), so the dash is checked by its
	# direction, and by where it got to only if it moved.
	assert_lt(mouse._direction.x, 0.0, "away from the player")
	assert_true(mouse.position.x <= start.x, "never towards the player")


func test_a_frog_sits_a_while_and_hops_about() -> void:
	var frog := _spawned(WildlifeRules.FROG)
	var start := frog.position
	_run(frog, 60.0)
	assert_ne(frog.position, start)
	assert_true(_wildlife.can_stand(frog.position), "never in the water")
	assert_false(frog.is_done)


func test_a_frog_hops_off_from_the_player_and_stops_once_safe() -> void:
	var frog := _spawned(WildlifeRules.FROG)
	_wildlife.is_player_ignored = false
	_player_beside(frog, 1.0)
	var player := _wildlife.world_view.player_feet
	_run(frog, STEP)
	assert_eq(frog._state, Frog.FLEE)
	_run(frog, 5.0)
	assert_eq(frog._state, Frog.SIT, "safe again")
	assert_false(frog.is_done)
	var safe_tiles: float = _wildlife.rules.flee_tiles(WildlifeRules.FROG) + Frog.SAFE_EXTRA_TILES
	assert_gt(frog.position.distance_to(player), safe_tiles * TerrainTileset.TILE_SIZE)
