extends GutTest
## The prototype module renderer of task 169 effect by effect, on modules built here: what each
## effect does to a channel tick by tick (as ProTracker does it), the speed, tempo and pattern
## break in a render, stereo sides, a tempo whose tick is no whole number of samples, and the
## files TrackerModule refuses.

const MODULE := "res://assets/music/test_reel.mod"
const RATE := 44100
## The periods of some notes.
const C_1 := 856
const E_1 := 678
const G_SHARP_1 := 538
const C_2 := 428
const C_SHARP_2 := 404
const A_2 := 254
const C_3 := 214
const E_3 := 170
const B_3 := 113

var _renderer: ModuleRenderer
var _channel: ModuleRenderer.Channel


func before_each() -> void:
	_renderer = ModuleRenderer.new(_module({}))
	_channel = ModuleRenderer.Channel.new()


## A module of one looped 32-sample saw and two patterns played in order. `cells` holds cells by
## Vector3i(pattern, row, channel), each [period, sample, effect, parameter].
func _module(cells: Dictionary) -> TrackerModule:
	var module := TrackerModule.new()
	var saw := TrackerModule.Sample.new()
	for index in 32:
		saw.data.append(index / 16.0 - 1.0)
	saw.loop_length = 32
	saw.volume = 64
	module.samples.append(saw)
	module.order = PackedInt32Array([0, 1])
	for pattern in 2:
		var pattern_cells := PackedInt32Array()
		pattern_cells.resize(
			TrackerModule.PATTERN_ROWS * TrackerModule.CHANNELS * TrackerModule.CELL_SIZE
		)
		module.patterns.append(pattern_cells)
	for place: Vector3i in cells:
		var at := (place.y * TrackerModule.CHANNELS + place.z) * TrackerModule.CELL_SIZE
		for index in TrackerModule.CELL_SIZE:
			module.patterns[place.x][at + index] = cells[place][index]
	return module


## The periods the channel plays on ticks 1 to `ticks` of a row that starts with this cell.
func _row(period: int, effect: int, parameter: int, ticks := 4) -> Array[int]:
	_renderer._start_row(_channel, period, 1 if period > 0 else 0, effect, parameter)
	var played: Array[int] = []
	for tick in range(1, ticks + 1):
		_renderer._play_tick(_channel, tick)
		played.append(_channel.played_period)
	return played


func test_an_arpeggio_steps_through_the_period_table() -> void:
	assert_eq(_row(A_2, 0x0, 0x37), [C_3, E_3, A_2, C_3], "A, then C and E above it, and again")
	assert_eq(_row(B_3, 0x0, 0x37), [B_3, B_3, B_3, B_3], "no higher than B-3")


func test_an_arpeggio_after_a_slide_steps_from_the_note_at_or_below() -> void:
	_row(C_1, 0x1, 0x01)
	assert_eq(_channel.period, C_1 - 4, "four ticks of 1 up")
	# ProTracker finds C#1 (808), the first period at or below 852, and steps up from there: three
	# steps is E-1, seven G#1. A ratio to 852 would give 716 and 568.
	assert_eq(_row(0, 0x0, 0x37), [E_1, G_SHARP_1, C_1 - 4, E_1])


func test_portamentos_slide_every_tick_but_the_first_and_stop_at_the_range() -> void:
	assert_eq(_row(C_2, 0x1, 0x08), [420, 412, 404, 396])
	assert_eq(_row(B_3 + 4, 0x1, 0x08), [B_3, B_3, B_3, B_3])
	assert_eq(_row(C_2, 0x2, 0x08), [436, 444, 452, 460])
	assert_eq(_row(C_1 - 4, 0x2, 0x08), [C_1, C_1, C_1, C_1])


func test_a_tone_portamento_slides_to_its_note_without_striking_it() -> void:
	_row(C_2, 0, 0, 1)
	_channel.position = 5.0
	assert_eq(_row(C_SHARP_2, 0x3, 0x08), [420, 412, C_SHARP_2, C_SHARP_2])
	assert_eq(_channel.position, 5.0, "not struck again")


func test_a_vibrato_swings_around_the_period_from_the_note_start() -> void:
	# Speed 8 of 64 steps a cycle, depth 15: 255 * sin * 15 / 128 period steps at most.
	assert_eq(_row(C_2, 0x4, 0x8F), [C_2, C_2 + 21, C_2 + 30, C_2 + 21])
	assert_eq(_row(0, 0x4, 0x8F), [C_2, C_2 - 21, C_2 - 30, C_2 - 21], "goes on, below")
	assert_eq(_channel.period, C_2, "the note itself stays")


func test_volume_slides_set_volume_and_note_cut() -> void:
	_row(C_2, 0xA, 0x04)
	assert_eq(_channel.volume, 64 - 16)
	_row(0, 0xA, 0x0F)
	assert_eq(_channel.volume, 0, "not below 0")
	_row(0, 0xA, 0x40)
	assert_eq(_channel.volume, 16)
	_row(0, 0xC, 0x20, 0)
	assert_eq(_channel.volume, 32)
	_renderer._start_row(_channel, 0, 0, 0xE, 0xC2)
	_renderer._play_tick(_channel, 1)
	assert_eq(_channel.volume, 32, "not yet")
	_renderer._play_tick(_channel, 2)
	assert_eq(_channel.volume, 0, "cut on tick 2")


func test_speed_and_tempo_set_the_row_length() -> void:
	var cells := {Vector3i(0, 0, 0): [C_2, 1, 0xF, 3], Vector3i(0, 0, 1): [0, 0, 0xF, 250]}
	var renderer := ModuleRenderer.new(_module(cells), RATE)
	var stream := renderer.render([Vector2i(0, 4)])
	# Tempo 250: a tick of 10 ms, 441 samples; speed 3.
	assert_eq(stream.data.size(), 4 * 3 * 441 * 2)
	assert_almost_eq(renderer.beat_seconds, 4 * 0.03, 0.000001)


func test_a_tick_that_is_no_whole_number_of_samples_is_cut_as_libmodplug_cuts_it() -> void:
	var cells := {Vector3i(0, 0, 0): [C_2, 1, 0xF, 5], Vector3i(0, 0, 1): [0, 0, 0xF, 127]}
	var renderer := ModuleRenderer.new(_module(cells), RATE)
	var stream := renderer.render([Vector2i(0, 10)])
	# 44100 * 2.5 / 127 is 868.1 samples: 868 a tick, every tick.
	assert_eq(stream.data.size(), 10 * 5 * 868 * 2)
	assert_almost_eq(renderer.beat_seconds, 4 * 5 * 868 / float(RATE), 0.000001)


func test_a_pattern_break_goes_on_at_its_row_of_the_next_pattern() -> void:
	# D10 is decimal: row 10 of the next pattern, where a note plays.
	var cells := {Vector3i(0, 0, 0): [0, 0, 0xD, 0x10], Vector3i(1, 10, 0): [C_2, 1, 0, 0]}
	var stream := ModuleRenderer.new(_module(cells), RATE).render([Vector2i(0, 2)])
	var row_bytes := stream.data.size() / 2
	assert_eq(_peak(stream.data.slice(0, row_bytes)), 0, "the break's row is silent")
	assert_gt(_peak(stream.data.slice(row_bytes)), 0, "row 10 of the next pattern plays")


func test_channels_1_and_4_lean_left_2_and_3_right() -> void:
	for channel in TrackerModule.CHANNELS:
		var module := _module({Vector3i(0, 0, channel): [C_2, 1, 0, 0]})
		var data := ModuleRenderer.new(module, RATE, true).render([Vector2i(0, 1)]).data
		var sides := Vector2.ZERO
		for frame in range(0, data.size(), 4):
			sides += Vector2(absf(data.decode_s16(frame)), absf(data.decode_s16(frame + 2)))
		var louder := sides.x if channel in [0, 3] else sides.y
		var softer := sides.y if channel in [0, 3] else sides.x
		assert_almost_eq(
			louder / softer, 3.0, 0.02, "channel %d: three quarters on its side" % channel
		)


func test_a_short_loop_stepped_past_more_than_once_a_sample_stays_in_it() -> void:
	# B-3 swung lower by the deepest vibrato, at 8 kHz: over 5 samples a step, the loop is 4.
	var vibrato := [0, 0, 0x4, 0x8F]
	var module := _module({Vector3i(0, 0, 0): [B_3, 1, 0x4, 0x8F], Vector3i(0, 1, 0): vibrato})
	module.samples[0].data = PackedFloat32Array([0.5, -0.5, 0.5, -0.5])
	module.samples[0].loop_length = 4
	var stream := ModuleRenderer.new(module, 8000).render([Vector2i(0, 2)])
	assert_eq(stream.data.size(), 2 * 6 * (8000 * 5 / (2 * 125)) * 2, "rendered whole")


func test_a_note_plays_between_its_samples_and_its_loop_end_leads_into_the_loop_start() -> void:
	var module := _module({Vector3i(0, 0, 0): [C_2, 1, 0, 0]})
	# Starting at 0.5, the loop's end can't pass for leading into silence.
	var wave := PackedFloat32Array([0.5, 1.0, 0.0, -1.0])
	module.samples[0].data = wave
	module.samples[0].loop_length = 4
	var data := ModuleRenderer.new(module, RATE).render([Vector2i(0, 1)]).data
	var step := ModuleRenderer.PAL_RATE / (C_2 * RATE)
	# From when the note has faded in.
	for frame in range(100, 300):
		var position := fmod(frame * step, 4.0)
		var index := int(position)
		var expected := lerpf(wave[index], wave[(index + 1) % 4], position - index)
		var played := data.decode_s16(frame * 2) / 32767.0 / ModuleRenderer.CHANNEL_GAIN
		assert_almost_eq(played, expected, 0.001, "frame %d" % frame)


func test_a_struck_note_fades_the_note_before_out_instead_of_cutting_it() -> void:
	var data := _sine_rows([[C_2, 1, 0, 0], [E_3, 1, 0, 0]])
	var row := 6 * (RATE * 5 / (2 * 125))
	# The sine is half way up when E-3 is struck: cut there, it would jump by a quarter of the
	# channel's range; fading, no step is steeper than the higher note's own.
	assert_lte(_steepest_step(data, row - 10, row + 200), _steepest_step(data, row + 200, row * 2))


func test_volume_changes_and_cuts_ramp() -> void:
	var data := _sine_rows([[C_2, 1, 0, 0], [0, 0, 0xC, 0x10], [0, 0, 0xC, 0]])
	var row := 6 * (RATE * 5 / (2 * 125))
	var own := _steepest_step(data, 200, row) + _ramp_step()
	assert_lte(_steepest_step(data, row - 10, row + 200), own, "to a quarter of the volume")
	assert_lte(_steepest_step(data, row * 2 - 10, row * 2 + 200), own, "to silence")
	assert_eq(data.decode_s16((row * 2 + 200) * 2), 0, "silent after the ramp")


func test_note_cuts_and_volume_slides_ramp() -> void:
	var row := 6 * (RATE * 5 / (2 * 125))
	var cut := _sine_rows([[C_2, 1, 0, 0], [0, 0, 0xE, 0xC2]])
	var own := _steepest_step(cut, 200, row) + _ramp_step()
	assert_lte(_steepest_step(cut, row - 10, row * 2), own, "cut on tick 2")
	assert_eq(cut.decode_s16((row * 2 - 1) * 2), 0, "silent after it")
	var slide := _sine_rows([[C_2, 1, 0, 0], [0, 0, 0xA, 0x0F]])
	assert_lte(_steepest_step(slide, row - 10, row * 2), own, "down 15 a tick")


## Mono 16-bit data of a module playing a 32-sample sine on channel 1, a row for each of `cells`.
func _sine_rows(cells: Array) -> PackedByteArray:
	var placed := {}
	for row in cells.size():
		placed[Vector3i(0, row, 0)] = cells[row]
	var module := _module(placed)
	var sine := PackedFloat32Array()
	for index in 32:
		sine.append(sin(index * TAU / 32))
	module.samples[0].data = sine
	return ModuleRenderer.new(module, RATE).render([Vector2i(0, cells.size())]).data


## How far a ramp of a full channel over 1 ms (at least) moves a 16-bit sample in a frame: a step
## may be the wave's own and this.
func _ramp_step() -> int:
	return ceili(32767 * ModuleRenderer.CHANNEL_GAIN / (RATE * 0.001))


## The largest change from one sample to the next in frames `from` to `to` of mono 16-bit data.
func _steepest_step(data: PackedByteArray, from: int, to: int) -> int:
	var steepest := 0
	for frame in range(from + 1, to):
		steepest = maxi(steepest, absi(data.decode_s16(frame * 2) - data.decode_s16(frame * 2 - 2)))
	return steepest


func test_a_part_outside_the_order_list_renders_nothing() -> void:
	assert_null(_renderer.render([Vector2i(2, 4)]))
	assert_push_error("outside the order list")


func test_refuses_files_it_cannot_play() -> void:
	var good := FileAccess.get_file_as_bytes(MODULE)
	assert_eq(TrackerModule.refusal_of(good), "")
	var cases := {
		"too short": good.slice(0, 100),
		"cut off in the patterns": good.slice(0, TrackerModule.PATTERNS_START + 1000),
		"cut off in sample 4": good.slice(0, good.size() - 10),
	}
	var no_order := good.duplicate()
	no_order[TrackerModule.HEADER_SIZE] = 0
	cases["an order list of 0"] = no_order
	var finetune := good.duplicate()
	finetune[20 + 24] = 3
	cases["sample 1 has a finetune"] = finetune
	var long_loop := good.duplicate()
	long_loop[20 + 26 + 1] = 2
	cases["the loop of sample 1 goes past its end"] = long_loop
	# The first cell's effect: B (position jump), not played.
	var jump := good.duplicate()
	jump[TrackerModule.PATTERNS_START + 2] = (jump[TrackerModule.PATTERNS_START + 2] & 0xF0) | 0xB
	cases["effect B"] = jump
	var far_break := good.duplicate()
	far_break[TrackerModule.PATTERNS_START + 2] = (
		(far_break[TrackerModule.PATTERNS_START + 2] & 0xF0) | 0xD
	)
	far_break[TrackerModule.PATTERNS_START + 3] = 0x64
	cases["effect D64"] = far_break
	var memory := good.duplicate()
	memory[TrackerModule.PATTERNS_START + 2] = (
		(memory[TrackerModule.PATTERNS_START + 2] & 0xF0) | 0x3
	)
	memory[TrackerModule.PATTERNS_START + 3] = 0
	cases["effect 300"] = memory
	var sample_32 := good.duplicate()
	sample_32[TrackerModule.PATTERNS_START] = (
		(sample_32[TrackerModule.PATTERNS_START] & 0x0F) | 0x20
	)
	sample_32[TrackerModule.PATTERNS_START + 2] &= 0x0F
	cases["sample 32 in pattern 0"] = sample_32
	var high_note := good.duplicate()
	high_note[TrackerModule.PATTERNS_START] &= 0xF0
	high_note[TrackerModule.PATTERNS_START + 1] = 50
	cases["period 50 in pattern 0"] = high_note
	for refusal: String in cases:
		assert_string_contains(TrackerModule.refusal_of(cases[refusal]), refusal)
		assert_null(TrackerModule.from_bytes(cases[refusal]), refusal)


func _peak(data: PackedByteArray) -> int:
	var peak := 0
	for index in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(index)))
	return peak
