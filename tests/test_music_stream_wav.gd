extends GutTest
## Rendered music in AudioStreamInteractive (task 169): a MusicStreamWAV tells its beat, so a switch
## between two crossfades on the next beat or bar, where a plain AudioStreamWAV switches at once.
## Mixed offline (AudioStreamPlayback.mix_audio), so nothing is heard. The clips hold a level each,
## +0.5 and -0.5, so where the crossfade begins and ends can be read off the samples.

const RATE := 22050
const BPM := 150.0
const BEAT_SECONDS := 60.0 / BPM
const BEATS := 4
## When the switch is asked for: within the first beat.
const SWITCH_SECONDS := 0.1
const TOLERANCE_SECONDS := 0.01


func _clip(level: float, stream: AudioStreamWAV) -> AudioStreamWAV:
	var frames := roundi(RATE * BEAT_SECONDS * BEATS)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame in frames:
		data.encode_s16(frame * 2, roundi(level * 32767))
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream


func _music_clip(level: float) -> MusicStreamWAV:
	var stream := MusicStreamWAV.new()
	stream.bpm = BPM
	stream.beat_count = BEATS
	return _clip(level, stream)


## The seconds at which the crossfade from the first clip to the second begins and ends, switched
## at SWITCH_SECONDS with `from_time` (an AudioStreamInteractive.TransitionFromTime).
func _crossfade(first: AudioStreamWAV, second: AudioStreamWAV, from_time: int) -> Vector2:
	var interactive := AudioStreamInteractive.new()
	interactive.clip_count = 2
	interactive.set_clip_stream(0, first)
	interactive.set_clip_stream(1, second)
	interactive.add_transition(
		0,
		1,
		from_time,
		AudioStreamInteractive.TRANSITION_TO_TIME_START,
		AudioStreamInteractive.FADE_CROSS,
		1.0
	)
	var playback: AudioStreamPlaybackInteractive = interactive.instantiate_playback()
	var mix_rate := AudioServer.get_mix_rate()
	playback.start(0.0)
	var mixed := playback.mix_audio(1.0, roundi(SWITCH_SECONDS * mix_rate))
	playback.switch_to_clip(1)
	mixed.append_array(playback.mix_audio(1.0, roundi(3.0 * mix_rate)))
	var begins := -1
	var ends := -1
	# The very first samples fade in from silence.
	for frame in range(roundi(0.05 * mix_rate), mixed.size()):
		if begins < 0 and mixed[frame].x < 0.49:
			begins = frame
		if ends < 0 and mixed[frame].x < -0.49:
			ends = frame
	return Vector2(begins, ends) / mix_rate


func test_switches_on_the_next_beat_and_crossfades_for_a_beat() -> void:
	var fade := _crossfade(
		_music_clip(0.5), _music_clip(-0.5), AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT
	)
	assert_almost_eq(fade.x, BEAT_SECONDS, TOLERANCE_SECONDS, "begins on the second beat")
	assert_almost_eq(fade.y, 2 * BEAT_SECONDS, TOLERANCE_SECONDS, "ends a beat later")


func test_switches_on_the_next_bar() -> void:
	var fade := _crossfade(
		_music_clip(0.5), _music_clip(-0.5), AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR
	)
	assert_almost_eq(fade.x, BEATS * BEAT_SECONDS, TOLERANCE_SECONDS, "begins on the next bar")


func test_a_plain_wav_has_no_beat_and_switches_at_once() -> void:
	var plain := func(level: float) -> AudioStreamWAV: return _clip(level, AudioStreamWAV.new())
	var fade := _crossfade(
		plain.call(0.5), plain.call(-0.5), AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT
	)
	assert_almost_eq(fade.x, SWITCH_SECONDS, TOLERANCE_SECONDS, "begins when asked")
