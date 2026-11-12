extends GutTest
## A crowing rooster is heard from where it stands (task 204); the ambience node plays what the
## livestock tells. The audio service is real; what it plays is recorded.

var _state: GameState
var _events: Array[StringName] = []


func before_each() -> void:
	_state = GameState.new_game(7)
	var audio := AudioService.new()
	add_child_autofree(audio)
	audio.played.connect(func(event: StringName, _position: Variant) -> void: _events.append(event))
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
	ambience.listen(audio, _state, wildlife, weather_view)
	_events.clear()


func test_a_crowing_rooster_is_heard() -> void:
	var rooster := FarmAnimal.new(LivestockRules.CHICKEN, &"rooster", Vector2(3.5, 4.5))

	_state.livestock.crowed.emit(rooster)

	assert_true(_events.has(&"rooster_crow"))
