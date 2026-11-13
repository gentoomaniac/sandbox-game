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
