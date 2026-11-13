extends GutTest
## A crowing rooster is heard from where it stands (task 204); the ambience node plays what the
## livestock tells. The audio service is real; what it plays is recorded.

var _state: GameState
var _audio: AudioService
var _events: Array[StringName] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	var wildlife := WildlifeView.new()
	autofree(wildlife)
	wildlife.rules = WildlifeRules.default_rules()
	wildlife.rules.sun = _state.sun
	wildlife.world_view = WorldView.new()
	add_child_autofree(wildlife.world_view)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	wildlife.world_view.add_child(wildlife.ground)
	var weather_view := WeatherView.new()
	add_child_autofree(weather_view)
	var ambience := AmbienceSounds.new()
	add_child_autofree(ambience)
	ambience.listen(_audio, _state, wildlife, weather_view)
	_events.clear()


func test_a_crowing_rooster_is_heard_from_where_it_stands_and_muffled_indoors() -> void:
	var rooster := FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2(3.5, 4.5))

	_state.livestock.crowed.emit(rooster)

	assert_eq(_events, [&"rooster_crow"])
	var player: AudioStreamPlayer2D = null
	for node in _audio.get_children():
		if node is AudioStreamPlayer2D and node.playing:
			player = node
	assert_not_null(player)
	assert_eq(player.position, rooster.position * TerrainTileset.TILE_SIZE)
	assert_eq(player.bus, AudioService.OUTSIDE_EFFECTS)
