extends GutTest
## The thunder of the ambience: it follows a flash after the sound's travel time from its strike,
## as the kind and with the dullness that fit the distance, and waits while the game is paused.
## The audio service is real; what it plays is recorded.

var _audio: AudioService
var _weather_view: WeatherView
var _events: Array[StringName] = []


func before_each() -> void:
	_events.clear()
	_audio = AudioService.new()
	add_child_autofree(_audio)
	_audio.played.connect(
		func(event: StringName, _position: Variant) -> void: _events.append(event)
	)
	var wildlife := WildlifeView.new()
	autofree(wildlife)
	wildlife.rules = WildlifeRules.default_rules()
	wildlife.world_view = WorldView.new()
	add_child_autofree(wildlife.world_view)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	wildlife.world_view.add_child(wildlife.ground)
	_weather_view = WeatherView.new()
	add_child_autofree(_weather_view)
	var ambience := AmbienceSounds.new()
	add_child_autofree(ambience)
	var state := GameState.new_game(7)
	wildlife.rules.sun = state.sun
	ambience.listen(_audio, state, wildlife, _weather_view)


func _strike_at(distance_km: float) -> LightningStrike:
	return LightningStrike.new(distance_km, WeatherRules.default_rules())


func test_a_close_strike_cracks_almost_with_its_flash_through_a_light_low_pass() -> void:
	var strike := _strike_at(0.1)
	_weather_view.flash(strike)
	assert_false(_events.has(LightningStrike.CLOSE), "not at once")
	await wait_seconds(1.0)
	assert_true(_events.has(LightningStrike.CLOSE))
	var low_pass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(
		AudioServer.get_bus_index(AudioService.DISTANT_AMBIENCE[0]), 0
	)
	assert_almost_eq(low_pass.cutoff_hz, strike.cutoff_hz(), 0.01)


func test_a_far_strike_is_heard_much_later() -> void:
	_weather_view.flash(_strike_at(10.0))
	await wait_seconds(1.0)
	assert_eq(_events, [] as Array[StringName], "nothing yet")


func test_a_thunder_due_in_a_pause_waits_for_the_game() -> void:
	_weather_view.flash(_strike_at(0.1))
	get_tree().paused = true
	# The test's own timer goes on in the pause, as the ambience's does not.
	await get_tree().create_timer(1.0, true).timeout
	assert_false(_events.has(LightningStrike.CLOSE), "not while paused")
	get_tree().paused = false
	await wait_seconds(1.0)
	assert_true(_events.has(LightningStrike.CLOSE), "after the pause")


func test_a_crawler_rumbles_as_thunder_crawl_after_the_same_delay() -> void:
	var crawler := LightningStrike.new(0.2, WeatherRules.default_rules(), true, 1)
	_weather_view.flash(crawler)
	assert_false(_events.has(LightningStrike.CRAWL), "not at once")
	await wait_seconds(1.0)
	assert_true(_events.has(LightningStrike.CRAWL))
	assert_false(_events.has(LightningStrike.CLOSE), "instead of the kind of its distance")
