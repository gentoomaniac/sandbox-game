extends GutTest
## A step in a ford (issue #100) is the wading step, and on the floodplain next to it the sand's.

const SEED := 1

var _state: GameState
var _audio: AudioService
var _player_view: PlayerView
var _events: Array[StringName] = []
var _ford: Vector2i
var _plain: Vector2i


func before_each() -> void:
	_events.clear()
	_state = GameState.new_game(SEED)
	_find_ford_and_plain()
	_state.world.add_chunk(Chunk.new(Chunk.world_to_chunk(_ford), Tile.Terrain.FLOODPLAIN))
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(func(event: StringName, _at: Variant) -> void: _events.append(event))
	_player_view = PlayerView.new()
	autofree(_player_view)
	var view := WorldView.new()
	add_child_autofree(view)
	var sounds := GameSounds.new()
	add_child_autofree(sounds)
	var build_mode := BuildMode.new()
	autofree(build_mode)
	sounds.listen(_audio, _state, view, _player_view, build_mode)
	_events.clear()


## A ford of the world's creeks on floodplain, and a floodplain tile of its chunk that is none.
func _find_ford_and_plain() -> void:
	var generator := WorldGenerator.new(SEED)
	for x in range(0, 960):
		for y in range(-420, 420):
			var tile := Vector2i(x, y)
			if generator.is_ford(tile) and generator.terrain_at(tile) == Tile.Terrain.FLOODPLAIN:
				_ford = tile
				break
		if _ford != Vector2i.ZERO:
			break
	var origin := Chunk.to_world(Chunk.world_to_chunk(_ford), Vector2i.ZERO)
	for index in Chunk.CHUNK_SIZE * Chunk.CHUNK_SIZE:
		var tile := origin + Vector2i(index % Chunk.CHUNK_SIZE, index / Chunk.CHUNK_SIZE)
		if not generator.is_ford(tile):
			_plain = tile
			return


func _step_on(tile: Vector2i) -> void:
	_state.player.position = Vector2(tile) + Vector2(0.5, 0.5)
	_player_view.stepped.emit()


func test_a_step_in_a_ford_is_waded_and_on_the_floodplain_next_to_it_sand() -> void:
	assert_ne(_ford, Vector2i.ZERO, "found a ford")
	_step_on(_plain)
	_step_on(_ford)
	_step_on(_plain)
	assert_eq(_events, [&"step_sand", &"step_wade", &"step_sand"])
