extends WildlifeCase
## A wild rabbit never sleeps, so whatever it is doing, sitting, nibbling or mid-hop, the player
## coming within its flee distance sends it off in flee hops.


func _rabbit() -> Rabbit:
	assert_eq(_wildlife.spawn_in_view(WildlifeRules.RABBIT, 1), 1)
	var rabbit: Rabbit = _wildlife._animals.back()
	_wildlife.is_player_ignored = false
	return rabbit


func _player_beside(rabbit: Rabbit, distance_tiles: float) -> void:
	_wildlife.world_view.player_feet = (
		rabbit.position + Vector2(distance_tiles * TerrainTileset.TILE_SIZE, 0.0)
	)


func test_a_rabbit_flees_from_the_player_whatever_it_was_doing() -> void:
	for resting in [Rabbit.SIT, Rabbit.NIBBLE, Rabbit.HOP]:
		var rabbit := _rabbit()
		_player_beside(rabbit, 100.0)
		_run(rabbit, STEP)
		rabbit._enter(resting)
		rabbit._state_seconds = 1000.0
		_player_beside(rabbit, _wildlife.rules.flee_tiles(WildlifeRules.RABBIT) - 0.5)
		_run(rabbit, STEP)
		assert_eq(rabbit._state, Rabbit.FLEE, "from %s" % resting)


func test_a_rabbit_far_from_the_player_stays_put() -> void:
	var rabbit := _rabbit()
	_player_beside(rabbit, 100.0)
	rabbit._enter(Rabbit.SIT)
	rabbit._state_seconds = 1000.0
	_run(rabbit, 5.0)
	assert_eq(rabbit._state, Rabbit.SIT)
