extends SceneTree
## Measures how late MusicCrossfade (game/audio/music_crossfade.gd) starts the new stream after the
## beat on a real audio driver, in silence. The driver is the one the command line names
## (`--audio-driver PulseAudio`; `--headless` alone picks the Dummy driver, whose 93 ms blocks say
## little). Master is muted and the probe's bus, which sends to it, has an AudioEffectCapture: the
## effect sees what the music mixes, the mute keeps it from the speakers.
##
## The old stream is a click up on every beat, the new one a constant level of the other sign, and
## the fade lasts a millisecond, so the new level is heard from the first frame of the fade on.
## From the captured frames: the clicks tell the old beats, the first frame at the new level tells
## when the new stream is heard, and how far past the last beat that lies is the lateness heard
## (in the mix's own time, which the driver runs ahead of the clock by its buffers: the beat and
## the new stream are both late by that much on the way to the speakers). `crossfade.lateness`, when
## the new stream was scheduled, is printed beside it, and how far the new beats lie from the old.
## `make music-latency` runs it: godot --headless --audio-driver PulseAudio --path . -s
## tools/bench/music_latency.gd -- [runs]

const BUS := &"MusicLatencyProbe"
const BEAT_SECONDS := 0.4
const BEATS := 4
const RUNS := 20
const FADE_SECONDS := 0.001
const FRAME_RATE := 60
const STEADY := 0.1
const CLICK := 0.9
## What a captured frame must pass to count as a click, and as the new level.
const CLICK_HEARD := 0.5
const NEW_HEARD := -0.05
const SETTLE_SECONDS := 1.0

var crossfade: MusicCrossfade
var capture := AudioEffectCapture.new()
var mix_rate := 0
var beat_frames := 0
## Per crossfade, how far the new stream's beats lay from the old grid, in ms (later is positive).
var off_grid_ms: Array[float] = []


func _initialize() -> void:
	Engine.max_fps = FRAME_RATE
	mix_rate = roundi(AudioServer.get_mix_rate())
	beat_frames = roundi(BEAT_SECONDS * mix_rate)
	AudioServer.set_bus_mute(0, true)
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, BUS)
	capture.buffer_length = 10.0
	AudioServer.add_bus_effect(bus, capture)
	crossfade = MusicCrossfade.new(BUS)
	root.add_child(crossfade)
	await process_frame
	var runs := (
		int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else RUNS
	)
	var scheduled_ms: Array[float] = []
	var heard_ms: Array[float] = []
	for run in runs:
		var measured := await _measure(run)
		scheduled_ms.append(crossfade.lateness * 1000.0)
		heard_ms.append(measured)
		print(
			(
				"run %2d: scheduled %5.1f ms after the beat, heard %5.1f ms"
				% [run, scheduled_ms[-1], measured]
			)
		)
	print(
		(
			"driver %s, mix rate %d, output latency %.1f ms, %d fps, %d crossfades"
			% [
				AudioServer.get_driver_name(),
				mix_rate,
				AudioServer.get_output_latency() * 1000.0,
				FRAME_RATE,
				runs
			]
		)
	)
	print("scheduled after the beat: %s" % _summary(scheduled_ms))
	print("heard after the beat:     %s" % _summary(heard_ms))
	print("new beats after the old:  %s" % _summary(off_grid_ms))
	quit()


## One crossfade asked for at a random point of a beat; how long after the beat the new level is
## heard, in ms (-1 if it never was).
func _measure(run: int) -> float:
	crossfade.play(_stream(1.0), BEAT_SECONDS)
	# What the last run left mixing is gone from the capture after a moment.
	await create_timer(SETTLE_SECONDS).timeout
	capture.clear_buffer()
	await create_timer(BEAT_SECONDS + BEAT_SECONDS * (run % 10) / 10.0).timeout
	crossfade.crossfade(_stream(-1.0), BEAT_SECONDS, FADE_SECONDS)
	var mixed := PackedFloat32Array()
	while crossfade.is_crossfading():
		await process_frame
		_take_captured(mixed)
	await create_timer(BEAT_SECONDS).timeout
	_take_captured(mixed)
	return _heard_lateness_ms(mixed)


func _take_captured(mixed: PackedFloat32Array) -> void:
	for frame in capture.get_buffer(capture.get_frames_available()):
		mixed.append(frame.x)


## A stream of a steady `level` (it must never be silent: Godot's bus skips the effects of a bus
## that mixes nothing, and the capture would miss those frames) with a click of 0.9 on every beat.
func _stream(level: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(beat_frames * BEATS * 2)
	for frame in beat_frames * BEATS:
		var is_click := frame % beat_frames == 0
		data.encode_s16(frame * 2, roundi((CLICK if is_click else STEADY) * signf(level) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = beat_frames * BEATS
	return stream


## How long after the last beat of the old stream the new one is heard (-1: never). Prints how far
## the new stream's own beats lie from the old grid, in frames, as a check of the capture.
func _heard_lateness_ms(mixed: PackedFloat32Array) -> float:
	var onset := -1
	for frame in mixed.size():
		if mixed[frame] < NEW_HEARD:
			onset = frame
			break
	if onset < 0:
		return -1.0
	var last_click := -1
	for frame in onset:
		if mixed[frame] > CLICK_HEARD:
			last_click = frame
	var new_click := onset
	while new_click < mixed.size() and mixed[new_click] > -CLICK_HEARD:
		new_click += 1
	var off_grid := posmod(new_click - last_click + beat_frames / 2, beat_frames) - beat_frames / 2
	off_grid_ms.append(off_grid * 1000.0 / mix_rate)
	var beats_after := int((onset - last_click) / float(beat_frames))
	return (onset - last_click - beats_after * beat_frames) * 1000.0 / mix_rate


static func _summary(values: Array[float]) -> String:
	var sorted := values.duplicate()
	sorted.sort()
	return (
		"median %.1f ms, 90th percentile %.1f ms, longest %.1f ms, shortest %.1f ms"
		% [sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.9)], sorted[-1], sorted[0]]
	)
