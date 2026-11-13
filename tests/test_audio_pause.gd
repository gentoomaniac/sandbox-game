extends GutTest
## The audio service while the game is paused: the Game bus fades out, the music and the UI sounds
## go on, and unpausing brings everything back.

var _service: AudioService
var _game_amplifier: AudioEffectAmplify


func before_each() -> void:
	_service = AudioService.new()
	add_child_autofree(_service)
	_game_amplifier = AudioServer.get_bus_effect(AudioServer.get_bus_index(AudioService.GAME), 0)


func after_each() -> void:
	get_tree().paused = false


func _playing_player() -> AudioStreamPlayer:
	for node in _service.get_children():
		if node is AudioStreamPlayer and node.playing:
			return node
	return null


func _bus(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


## Steps the service for `seconds` of game time with the game paused or not.
func _step(is_paused: bool, seconds: float) -> void:
	get_tree().paused = is_paused
	simulate(_service, 1, seconds)
	get_tree().paused = false


func test_pausing_the_game_fades_the_game_bus_out_but_not_music_or_ui() -> void:
	_step(true, 0.15)
	assert_between(_service.pause_amount(), 0.4, 0.6, "half way")
	_step(true, 0.3)
	assert_eq(_service.pause_amount(), 1.0)
	assert_eq(_game_amplifier.volume_db, AudioService.SILENT_DB)
	for bus in [AudioService.MUSIC, AudioService.UI]:
		assert_eq(AudioServer.get_bus_effect_count(_bus(bus)), 0, str(bus))
		assert_eq(AudioServer.get_bus_volume_db(_bus(bus)), 0.0, str(bus))


func test_unpausing_brings_the_game_bus_back() -> void:
	_step(true, 0.5)
	_step(false, 0.15)
	assert_between(_service.pause_amount(), 0.4, 0.6, "half way back")
	_step(false, 0.3)
	assert_eq(_service.pause_amount(), 0.0)
	assert_eq(_game_amplifier.volume_db, 0.0)


func test_a_volume_test_clicks_on_the_ui_bus_at_the_level_of_the_slider() -> void:
	var played: Array[StringName] = []
	_service.played.connect(
		func(event: StringName, _position: Variant) -> void: played.append(event)
	)
	_service.play_volume_test(&"effects", 50.0)
	var player: AudioStreamPlayer = _playing_player()
	assert_eq(played, [&"ui_click"])
	assert_eq(player.bus, AudioService.UI)
	var full_volume_db: float = SoundRules.default_rules().event(&"ui_click")["volume_db"]
	assert_almost_eq(player.volume_db, full_volume_db + linear_to_db(0.5), 0.001)


func test_a_volume_test_is_silent_for_the_music_and_for_zero() -> void:
	var played: Array[StringName] = []
	_service.played.connect(
		func(event: StringName, _position: Variant) -> void: played.append(event)
	)
	_service.play_volume_test(&"music", 50.0)
	_service.play_volume_test(&"ambience", 0.0)
	assert_eq(played, [])


func test_a_dragged_slider_clicks_at_most_every_interval_and_ends_on_the_final_level() -> void:
	var clicks: Array[int] = [0]
	_service.played.connect(func(_event: StringName, _position: Variant) -> void: clicks[0] += 1)
	for percent in [10.0, 20.0, 30.0, 40.0]:
		_service.play_volume_test(&"effects", percent)
		simulate(_service, 1, 0.03)
	assert_eq(clicks[0], 1, "the first click only, the rest wait")
	simulate(_service, 1, AudioService.TEST_CLICK_SECONDS)
	assert_eq(clicks[0], 2)
	var click_db: float = SoundRules.default_rules().event(&"ui_click")["volume_db"]
	assert_almost_eq(_playing_volumes()[-1], click_db + linear_to_db(0.4), 0.001)
	simulate(_service, 1, AudioService.TEST_CLICK_SECONDS * 2.0)
	assert_eq(clicks[0], 2, "nothing more once the slider rests")
	_service.play_volume_test(&"effects", 50.0)
	assert_eq(clicks[0], 3, "a later move clicks at once")


func _playing_volumes() -> Array[float]:
	var volumes: Array[float] = []
	for node in _service.get_children():
		if node is AudioStreamPlayer and node.playing:
			volumes.append(node.volume_db)
	return volumes
