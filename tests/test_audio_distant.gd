extends GutTest
## A far-off sound of the audio service goes through a low-pass filter of its own cutoff, on its
## way to the Ambience bus (which the indoors muffle), and nothing changes that cutoff while it
## plays.

var _service: AudioService


func before_each() -> void:
	_service = AudioService.new()
	add_child_autofree(_service)


func _bus(bus_name: StringName) -> int:
	return AudioServer.get_bus_index(bus_name)


func _plain_players() -> Array[Node]:
	return _service.get_children().filter(
		func(node: Node) -> bool: return node is AudioStreamPlayer and node.playing
	)


func _cutoff_of(player: Node) -> float:
	var low_pass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_bus(player.bus), 0)
	return low_pass.cutoff_hz


func test_the_distant_buses_send_to_the_ambience_bus() -> void:
	for bus in AudioService.DISTANT_AMBIENCE:
		assert_eq(AudioServer.get_bus_send(_bus(bus)), AudioService.AMBIENCE)


func test_a_distant_sound_plays_on_a_distant_bus_with_its_cutoff() -> void:
	_service.play(&"wind_gust", null, true, 1.0, 900.0)
	var players := _plain_players()
	assert_eq(players.size(), 1)
	assert_true(AudioService.DISTANT_AMBIENCE.has(players[0].bus))
	assert_eq(_cutoff_of(players[0]), 900.0)


func test_overlapping_distant_sounds_keep_their_own_cutoffs() -> void:
	_service.play(&"wind_gust", null, true, 1.0, 9000.0)
	_service.play(&"wind_gust", null, true, 1.0, 700.0)
	var players := _plain_players()
	assert_eq(players.size(), 2)
	assert_eq(_cutoff_of(players[0]), 9000.0)
	assert_eq(_cutoff_of(players[1]), 700.0)


func test_a_sound_without_a_cutoff_stays_off_the_distant_buses() -> void:
	_service.play(&"wind_gust", null, true)
	var players := _plain_players()
	assert_eq(players.size(), 1)
	assert_eq(players[0].bus, AudioService.AMBIENCE)
