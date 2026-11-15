extends GutTest
## The waves of the shore: the loop starts where the sea is near and is gone inland, falls with the
## distance, pans to the side of the water, follows the tide, and is quieter indoors. The audio
## service is real; what it plays is recorded.

var _state: GameState
var _audio: AudioService
var _sea: SeaSounds
var _events: Array[StringName] = []


func before_each() -> void:
	_events.clear()
	_state = GameState.new_game(7)
	_state.weather_override = &"clear"
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(func(event: StringName, _at: Variant) -> void: _events.append(event))
	_sea = SeaSounds.new()
	add_child_autofree(_sea)
	_sea.listen(_audio, _state)


## Turns the tiles of the loaded chunks to sea from `from_x` to `to_x` tiles east of the player
## (negative: west), over the rows around them, and the rest of the ground to grass.
func _make_sea(from_x: int, to_x: int) -> void:
	var centre := _state.player.tile()
	# As far as the game keeps chunks loaded around the player (the new game has only a few).
	var player_chunk := Chunk.world_to_chunk(centre)
	for y in range(-ChunkResidency.LOAD_RADIUS, ChunkResidency.LOAD_RADIUS + 1):
		for x in range(-ChunkResidency.LOAD_RADIUS, ChunkResidency.LOAD_RADIUS + 1):
			var coords := player_chunk + Vector2i(x, y)
			if not _state.world.is_chunk_loaded(coords):
				_state.world.add_chunk(Chunk.new(coords))
	for y in range(-80, 80):
		for x in range(-100, 100):
			var tile := centre + Vector2i(x, y)
			var chunk := _state.world.chunk_at(Chunk.world_to_chunk(tile))
			if chunk != null:
				var is_sea := x >= from_x and x <= to_x
				chunk.set_terrain(
					Chunk.local_pos(tile), Tile.Terrain.SEA if is_sea else Tile.Terrain.GRASS
				)


func _look() -> void:
	_sea._look()


func _level_at_high_tide_for(sea_distance: int) -> float:
	_state.clock.minute_of_day = 0
	_state.clock.day = 1
	_make_sea(-90, -sea_distance)
	_look()
	return _sea._level


func test_it_is_loudest_at_the_edge_and_falls_with_the_distance() -> void:
	var near := _level_at_high_tide_for(2)
	var middle := _level_at_high_tide_for(30)
	var far := _level_at_high_tide_for(60)
	assert_gt(near, middle)
	assert_gt(middle, far)
	assert_gt(far, 0.0, "still heard two chunks away")
	assert_almost_eq(near, AmbienceRules.default_rules().value("sea", "level"), 0.001)


func test_it_is_gone_a_few_chunks_inland_and_no_loop_plays() -> void:
	_level_at_high_tide_for(90)
	assert_eq(_sea._level, 0.0)
	assert_null(_sea._calm.loop)
	assert_false(_events.has(&"sea_loop"))


func test_it_starts_a_flat_loop_on_the_ambience_bus_and_stops_it_when_the_sea_is_gone() -> void:
	_level_at_high_tide_for(10)
	assert_eq(_events.count(&"sea_loop"), 1)
	var player: AudioStreamPlayer2D = _sea._calm.loop._player
	assert_eq(player.bus, AudioService.AMBIENCE, "muffled by the same bus as the weather")
	assert_eq(player.attenuation, 0.0, "the level is the rule's, not the engine's")
	_look()
	assert_eq(_events.count(&"sea_loop"), 1, "not started again")
	_make_sea(-90, -95)
	_look()
	assert_null(_sea._calm.loop)


func test_it_pans_to_the_side_the_water_is_on() -> void:
	_level_at_high_tide_for(10)
	assert_lt(_sea._pan_target, -0.5, "sea to the west: the left")
	_make_sea(15, 90)
	_look()
	assert_gt(_sea._pan_target, 0.5, "sea to the east: the right")


func test_the_loop_sounds_to_the_side_of_the_player() -> void:
	_level_at_high_tide_for(10)
	_sea._process(0.0)
	var player: AudioStreamPlayer2D = _sea._calm.loop._player
	var at := _state.player.position * TerrainTileset.TILE_SIZE
	assert_lt(player.position.x, at.x)
	assert_eq(player.position.y, at.y)
	var before := _sea._pan
	_sea._pan_target = 0.0
	_sea._process(0.05)
	assert_gt(_sea._pan, before, "it moves towards the new side, not at a jump")
	assert_lt(_sea._pan, 0.0)


func test_a_playing_loop_stops_only_well_below_the_least_level() -> void:
	# At 63 tiles the waves are a little below `[loops] min_level` but above half of it: a loop
	# that is not playing doesn't start, and one that is goes on.
	var least := AmbienceRules.default_rules().value("loops", "min_level")
	var level := _level_at_high_tide_for(63)
	assert_null(_sea._calm.loop, "not started")
	_level_at_high_tide_for(10)
	assert_not_null(_sea._calm.loop)
	_level_at_high_tide_for(63)
	assert_not_null(_sea._calm.loop, "not stopped at the edge of hearing")
	assert_between(_sea._level, least * SeaSounds.STOP_SHARE, least)
	assert_eq(level, 0.0)


func test_in_no_storm_only_the_calm_loop_plays() -> void:
	_level_at_high_tide_for(10)
	assert_not_null(_sea._calm.loop)
	assert_null(_sea._rough.loop)
	assert_false(_events.has(&"sea_storm_loop"))


func test_in_a_full_storm_the_rough_loop_plays_and_the_calm_one_is_gone() -> void:
	_state.weather_override = &"storm"
	_level_at_high_tide_for(10)
	assert_eq(_events.count(&"sea_storm_loop"), 1)
	assert_not_null(_sea._rough.loop)
	assert_gt(_sea._rough.level, 0.9 * _sea._level, "mostly the rough one")
	assert_null(_sea._calm.loop, "the calm waves have faded out")


func test_the_loops_crossfade_as_the_storm_rises_and_the_total_keeps_its_level() -> void:
	_level_at_high_tide_for(10)
	var level := _sea._level
	var rough_before := 0.0
	for step in range(1, 5):
		_sea._follow(level, step / 4.0 * 0.75)
		assert_gt(_sea._rough.level, rough_before, "rougher with every step")
		rough_before = _sea._rough.level
		var power := sqrt(_sea._calm.level ** 2 + _sea._rough.level ** 2)
		assert_almost_eq(power, level, 0.0001, "no dip while they swap")
	assert_not_null(_sea._calm.loop, "both are heard in between")
	assert_not_null(_sea._rough.loop)
	_sea._follow(level, 0.0)
	assert_null(_sea._rough.loop, "calm again: the rough loop fades out")
	assert_eq(_events.count(&"sea_loop"), 1, "the calm loop played on, not restarted")


func test_both_loops_stop_when_the_sea_is_gone() -> void:
	_state.weather_override = &"storm"
	_level_at_high_tide_for(10)
	_make_sea(-90, -150)
	_look()
	assert_null(_sea._rough.loop)
	assert_null(_sea._calm.loop)
