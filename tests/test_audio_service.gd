extends GutTest
## The audio service: buses, the muffle indoors, the pool of players, loops, and silence while
## the window is unfocused with "Sound in background" off.

const SETTINGS_PATH := "user://test_audio/settings.cfg"

var _service: AudioService
var _played: Array[StringName] = []


func before_each() -> void:
	_service = AudioService.new()
	add_child_autofree(_service)
	_played.clear()
	_service.played.connect(
		func(event: StringName, _position: Variant) -> void: _played.append(event)
	)


func after_each() -> void:
	# The audio server is shared by all tests.
	_service.apply_settings(GameSettings.new(SETTINGS_PATH))
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	DirAccess.remove_absolute(SETTINGS_PATH)


func _bus(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


## The player of that class (AudioStreamPlayer or AudioStreamPlayer2D) that is playing.
func _playing(player_class: String) -> Node:
	for node in _service.get_children():
		if node.is_class(player_class) and node.playing:
			return node
	return null


func test_the_buses_exist_and_end_in_master() -> void:
	for bus in [AudioService.EFFECTS, AudioService.AMBIENCE, AudioService.MUSIC, AudioService.UI]:
		assert_ne(_bus(bus), -1, str(bus))
		assert_eq(AudioServer.get_bus_send(_bus(bus)), AudioService.MASTER)
	assert_eq(AudioServer.get_bus_send(_bus(AudioService.OUTSIDE_EFFECTS)), AudioService.EFFECTS)


func test_a_second_service_does_not_add_the_buses_again() -> void:
	var count := AudioServer.bus_count
	add_child_autofree(AudioService.new())
	assert_eq(AudioServer.bus_count, count)


func test_percent_to_db() -> void:
	assert_eq(AudioService.percent_to_db(100.0), 0.0)
	assert_almost_eq(AudioService.percent_to_db(50.0), -6.02, 0.01)
	assert_eq(AudioService.percent_to_db(0.0), AudioService.SILENT_DB)


func test_play_picks_a_file_and_a_pitch_of_the_event_and_uses_its_bus() -> void:
	_service.play(&"ui_click")
	assert_eq(_played, [&"ui_click"])
	var player: AudioStreamPlayer = _playing("AudioStreamPlayer")
	var values := SoundRules.default_rules().event(&"ui_click")
	assert_has(values["files"], player.stream.resource_path)
	assert_between(player.pitch_scale, values["pitch_min"], values["pitch_max"])
	assert_eq(player.bus, AudioService.UI)


func test_a_sound_with_a_position_is_positional() -> void:
	_service.play(&"axe_chop", Vector2(40, 8))
	assert_null(_playing("AudioStreamPlayer"))
	var player: AudioStreamPlayer2D = _playing("AudioStreamPlayer2D")
	assert_eq(player.position, Vector2(40, 8))
	assert_eq(player.bus, AudioService.EFFECTS)


func test_a_sound_of_the_world_outside_goes_to_the_muffled_effects_bus() -> void:
	_service.play(&"deer_hooves", Vector2.ZERO, true)
	var player: AudioStreamPlayer2D = _playing("AudioStreamPlayer2D")
	assert_eq(player.bus, AudioService.OUTSIDE_EFFECTS)


func test_many_sounds_reuse_the_pool() -> void:
	var children := _service.get_child_count()
	for _i in AudioService.POOL_SIZE * 3:
		_service.play(&"ui_click")
		_service.play(&"axe_chop", Vector2.ZERO)
	assert_eq(_service.get_child_count(), children)
	assert_eq(_played.size(), AudioService.POOL_SIZE * 6)


func test_an_unknown_event_plays_nothing() -> void:
	_service.play(&"no_such_sound")
	assert_eq(_played, [])
	assert_push_error("No sound event")


func test_entering_a_building_fades_the_muffle_in_and_leaving_fades_it_out() -> void:
	assert_eq(_service.muffle_amount(), 0.0)
	_service.set_inside(true)
	simulate(_service, 1, Muffle.FADE_SECONDS / 2.0)
	assert_between(_service.muffle_amount(), 0.4, 0.6, "half way")
	simulate(_service, 2, Muffle.FADE_SECONDS)
	assert_eq(_service.muffle_amount(), 1.0)
	var low_pass := AudioServer.get_bus_effect(_bus(AudioService.AMBIENCE), 0)
	assert_almost_eq(low_pass.cutoff_hz, Muffle.MUFFLED_CUTOFF_HZ, 1.0)
	_service.set_inside(false)
	simulate(_service, 2, Muffle.FADE_SECONDS)
	assert_eq(_service.muffle_amount(), 0.0)
	assert_almost_eq(low_pass.cutoff_hz, Muffle.OPEN_CUTOFF_HZ, 1.0)


func test_the_outside_effects_bus_is_muffled_with_the_ambience() -> void:
	_service.set_inside(true)
	simulate(_service, 2, Muffle.FADE_SECONDS)
	var low_pass := AudioServer.get_bus_effect(_bus(AudioService.OUTSIDE_EFFECTS), 0)
	assert_almost_eq(low_pass.cutoff_hz, Muffle.MUFFLED_CUTOFF_HZ, 1.0)


func test_the_weather_and_the_outside_effects_are_faint_indoors_and_fade_in_and_out() -> void:
	var faint_db: float = AmbienceRules.default_rules().value("indoors", "outside_db")
	assert_lt(faint_db, -12.0, "much quieter, not only duller")
	for bus in [AudioService.AMBIENCE, AudioService.OUTSIDE_EFFECTS]:
		var amplifier: AudioEffectAmplify = AudioServer.get_bus_effect(_bus(bus), 1)
		_service.set_inside(false)
		simulate(_service, 2, Muffle.FADE_SECONDS)
		assert_eq(amplifier.volume_db, 0.0, "%s in the open" % bus)
		_service.set_inside(true)
		simulate(_service, 1, Muffle.FADE_SECONDS / 2.0)
		assert_almost_eq(amplifier.volume_db, faint_db / 2.0, 0.5, "%s half way" % bus)
		simulate(_service, 2, Muffle.FADE_SECONDS)
		assert_almost_eq(amplifier.volume_db, faint_db, 0.01, "%s inside" % bus)
		_service.set_inside(false)
		simulate(_service, 2, Muffle.FADE_SECONDS)
		assert_eq(amplifier.volume_db, 0.0, "%s out again" % bus)


func test_the_volume_settings_set_the_buses() -> void:
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.set_volume(&"master", 50)
	settings.set_volume(&"effects", 0)
	settings.set_volume(&"music", 0)
	_service.apply_settings(settings)
	assert_almost_eq(AudioServer.get_bus_volume_db(_bus(AudioService.MASTER)), -6.02, 0.01)
	assert_eq(AudioServer.get_bus_volume_db(_bus(AudioService.EFFECTS)), AudioService.SILENT_DB)
	assert_eq(AudioServer.get_bus_volume_db(_bus(AudioService.AMBIENCE)), 0.0)
	assert_eq(AudioServer.get_bus_volume_db(_bus(AudioService.MUSIC)), AudioService.SILENT_DB)


func test_silent_only_when_unfocused_and_not_to_play_in_the_background() -> void:
	assert_false(AudioService.is_silenced(true, true))
	assert_false(AudioService.is_silenced(true, false))
	assert_false(AudioService.is_silenced(false, true))
	assert_true(AudioService.is_silenced(false, false))


func test_losing_the_focus_mutes_when_sound_in_background_is_off() -> void:
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.set_sound_in_background(false)
	_service.apply_settings(settings)
	assert_false(AudioServer.is_bus_mute(_bus(AudioService.MASTER)), "focused")
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(AudioServer.is_bus_mute(_bus(AudioService.MASTER)))
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(AudioServer.is_bus_mute(_bus(AudioService.MASTER)))


func test_losing_the_focus_keeps_the_sound_when_sound_in_background_is_on() -> void:
	_service.apply_settings(GameSettings.new(SETTINGS_PATH))
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(AudioServer.is_bus_mute(_bus(AudioService.MASTER)))


func test_muted_stays_silent_through_settings_and_focus() -> void:
	_service.is_muted = true
	_service.apply_settings(GameSettings.new(SETTINGS_PATH))
	assert_true(AudioServer.is_bus_mute(_bus(AudioService.MASTER)), "after the settings")
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(AudioServer.is_bus_mute(_bus(AudioService.MASTER)), "after the focus")
	_service.is_muted = false
	_service.apply_settings(GameSettings.new(SETTINGS_PATH))
	assert_false(AudioServer.is_bus_mute(_bus(AudioService.MASTER)), "unmuted again")


func test_turning_the_setting_off_while_unfocused_mutes_at_once() -> void:
	_service.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.set_sound_in_background(false)
	_service.apply_settings(settings)
	assert_true(AudioServer.is_bus_mute(_bus(AudioService.MASTER)))


func test_a_loop_can_be_faded_and_stopped() -> void:
	var loop := _service.start_loop(&"rain_loop", null, 0.0)
	var player: AudioStreamPlayer = _playing("AudioStreamPlayer")
	assert_eq(player.volume_db, AudioService.SILENT_DB)
	assert_eq(player.bus, AudioService.AMBIENCE)
	loop.fade_to(1.0, 0.1)
	await wait_seconds(0.3)
	assert_almost_eq(player.volume_db, 0.0, 0.5)
	loop.stop(0.05)
	await wait_seconds(0.3)
	assert_false(is_instance_valid(player), "a stopped loop is gone")
	loop.fade_to(1.0, 0.1)
	loop.move_to(Vector2.ONE)
	loop.stop()
