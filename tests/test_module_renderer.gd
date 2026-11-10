extends GutTest
## The prototype module renderer of task 169 on the test piece (tools/music/pieces/test_reel.txt):
## the module is read, a section renders to its exact length, the loop wraps without a seam, the
## fill leads back into the loop on the bar, and a render on a worker thread is the same.
## (How the render compares with an independent player: `make music-check`.)

const MODULE := "res://assets/music/test_reel.mod"
const RATE := 22050
## Speed 6 at tempo 106: six ticks of 22050 * 2.5 / 106 = 520.05 samples, cut to 520.
const ROW_FRAMES := 6 * 520
const LOOP_ROWS := 128
const FILL_ROWS := 16
const LOOP := Vector2i(0, LOOP_ROWS)
## The fill is the third pattern of the order list, after the loop's two.
const FILL := Vector2i(2, FILL_ROWS)

var _module: TrackerModule


func before_all() -> void:
	_module = TrackerModule.from_bytes(FileAccess.get_file_as_bytes(MODULE))


func _render(parts: Array[Vector2i], stereo := false) -> AudioStreamWAV:
	return ModuleRenderer.new(_module, RATE, stereo).render(parts)


func test_reads_the_samples_order_and_patterns() -> void:
	assert_eq(_module.order, PackedInt32Array([0, 1, 2]))
	assert_eq(_module.patterns.size(), 3)
	assert_eq(_module.samples.size(), TrackerModule.SAMPLE_SLOTS)
	var saw := _module.samples[0]
	assert_eq([saw.data.size(), saw.loop_start, saw.loop_length], [32, 0, 32], "a looped cycle")
	assert_eq(_module.samples[3].loop_length, 0, "the noise is one-shot")
	assert_eq(_module.samples[4].data.size(), 0, "the unused slots are empty")


func test_refuses_bytes_that_are_no_module() -> void:
	assert_null(TrackerModule.from_bytes(PackedByteArray([1, 2, 3])))
	var bytes := FileAccess.get_file_as_bytes(MODULE)
	bytes[TrackerModule.PATTERNS_START - 1] = 0
	assert_null(TrackerModule.from_bytes(bytes), "no M.K.")


func test_renders_a_section_to_its_rows_and_tells_its_beat() -> void:
	var renderer := ModuleRenderer.new(_module, RATE)
	var stream := renderer.render([LOOP])
	assert_eq(stream.data.size(), LOOP_ROWS * ROW_FRAMES * 2, "16 bit mono, whole ticks")
	assert_eq(stream.mix_rate, RATE)
	assert_almost_eq(renderer.beat_seconds, 4 * ROW_FRAMES / float(RATE), 0.000001, "4 rows")
	assert_gt(_peak(stream.data), 0.1, "it is not silent")


## Which side each channel is on: tests/test_module_effects.gd.
func test_renders_stereo_as_two_samples_a_frame() -> void:
	var stream := _render([LOOP], true)
	assert_eq(stream.data.size(), LOOP_ROWS * ROW_FRAMES * 4)
	assert_true(stream.stereo)


func test_the_loop_wraps_into_its_own_start_without_a_seam() -> void:
	var once := _render([LOOP]).data
	var twice := _render([LOOP, LOOP]).data
	# The loop played on into itself sounds as its start, sample for sample: so a stream of the
	# loop wrapping from its last sample to its first plays what the music would, no click.
	assert_true(twice.slice(once.size()) == once, "the second time through is the first")


func test_the_fill_breaks_after_a_bar_and_the_loop_resumes_on_the_bar() -> void:
	var loop := _render([LOOP]).data
	var fill := _render([FILL]).data
	# The order list from the start: the loop, the fill (a bar, then its pattern break), and the
	# order list's start again.
	var played := _render([Vector2i(0, LOOP_ROWS + FILL_ROWS + LOOP_ROWS)]).data
	assert_eq(played.size(), loop.size() * 2 + fill.size())
	assert_true(played.slice(loop.size(), loop.size() + fill.size()) == fill, "the fill on the bar")
	assert_true(played.slice(loop.size() + fill.size()) == loop, "then the loop from its start")


func test_a_render_on_a_worker_thread_is_the_same() -> void:
	var renderer := ModuleRenderer.new(_module, RATE)
	renderer.start([FILL])
	await wait_until(renderer.is_done, 10.0)
	var stream := renderer.take()
	assert_true(stream.data == _render([FILL]).data)


func _peak(data: PackedByteArray) -> float:
	var peak := 0
	for index in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(index)))
	return peak / 32768.0
