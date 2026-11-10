extends GutTest
## Streams that loop (ModuleRenderer.render(parts, true)) on modules built here: they sound as the
## parts repeated, sample for sample, also where a part's start depends on what played before, and
## parts without rows add nothing.

const RATE := 44100
const C_2 := 428
const E_3 := 170


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


## Asserts that `parts` looping sound as they do from their second time through, and that the
## second time through is the third: so the stream wraps as the music repeats, sample for sample.
func _assert_loops_as_it_repeats(cells: Dictionary, parts: Array[Vector2i], why: String) -> void:
	var renderer := ModuleRenderer.new(_module(cells), RATE)
	var looping := renderer.render(parts, true).data
	var thrice: Array[Vector2i] = parts + parts + parts
	var played := renderer.render(thrice).data
	var size := looping.size()
	assert_eq(played.size(), size * 3, why)
	assert_true(played.slice(size, size * 2) == looping, "%s: the second time through" % why)
	assert_true(played.slice(size * 2) == looping, "%s: the third the same" % why)


func test_a_held_note_fades_out_into_the_start() -> void:
	var cells := {Vector3i(0, 0, 0): [C_2, 1, 0, 0], Vector3i(0, 4, 1): [E_3, 1, 0, 0]}
	_assert_loops_as_it_repeats(cells, [Vector2i(0, 8)], "E-3 held over the wrap")


func test_a_cut_note_raised_again_in_a_later_part() -> void:
	# Cut on the first row, a volume without a note in the second part: the note before sounds
	# again, from the second time through.
	var cells := {
		Vector3i(0, 0, 1): [0, 0, 0xC, 0],
		Vector3i(1, 2, 1): [0, 0, 0xC, 0x20],
		Vector3i(1, 6, 1): [E_3, 1, 0, 0],
	}
	_assert_loops_as_it_repeats(cells, [Vector2i(0, 4), Vector2i(1, 8)], "C20 after C00")


func test_a_sample_named_without_a_note() -> void:
	# A sample without a note sets its volume again: the cut note before sounds again.
	var cells := {
		Vector3i(0, 0, 1): [0, 0, 0xC, 0],
		Vector3i(0, 3, 1): [0, 1, 0, 0],
		Vector3i(0, 6, 1): [E_3, 1, 0, 0],
	}
	_assert_loops_as_it_repeats(cells, [Vector2i(0, 8)], "a sample without a note")


func test_a_tone_portamento_without_a_note_slides_to_the_last_one() -> void:
	# On the first time through it has no note to slide to; from the second, E-3 of the end.
	var cells := {
		Vector3i(0, 0, 1): [C_2, 1, 0, 0],
		Vector3i(0, 2, 1): [0, 0, 0x3, 0x08],
		Vector3i(0, 5, 1): [E_3, 1, 0x3, 0x08],
	}
	_assert_loops_as_it_repeats(cells, [Vector2i(0, 8)], "308 without a note")


func test_a_loop_of_parts_without_rows_is_empty_and_they_are_left_out() -> void:
	var cells := {Vector3i(1, 0, 0): [C_2, 1, 0, 0], Vector3i(1, 2, 1): [E_3, 1, 0, 0]}
	var renderer := ModuleRenderer.new(_module(cells), RATE)
	assert_eq(renderer.render([Vector2i(0, 0)], true).data.size(), 0, "nothing to loop")
	var looping := renderer.render([Vector2i(0, 0), Vector2i(1, 4)], true).data
	assert_true(looping == renderer.render([Vector2i(1, 4)], true).data, "the second part alone")
