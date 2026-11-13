extends GutTest
## ModuleRenderer with a MusicCache: the render on its worker is kept, the next one for the same
## module and settings comes out of the cache (made whole there too), and any other setting finds
## nothing.

const MODULE := "res://assets/music/test_reel.mod"
const DIR := "user://test_module_renderer_cache"
const PATIENCE_SECONDS := 60.0
const RATE := 22050
const LOOP := Vector2i(0, 128)

var _bytes: PackedByteArray
var _cache: MusicCache


func before_all() -> void:
	_bytes = FileAccess.get_file_as_bytes(MODULE)


func before_each() -> void:
	_cache = MusicCache.new(DIR, 1000 * 1000 * 1000)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _renderer(bytes := _bytes, rate := RATE, stereo := false) -> ModuleRenderer:
	var renderer := ModuleRenderer.new(TrackerModule.from_bytes(bytes), rate, stereo)
	renderer.cache = _cache
	return renderer


## Renders `parts` on the worker and takes the stream when it is done.
func _started(renderer: ModuleRenderer, loops := false) -> AudioStreamWAV:
	renderer.start([LOOP], loops)
	await wait_until(renderer.is_done, PATIENCE_SECONDS)
	return renderer.take()


func test_the_second_render_of_the_same_module_comes_out_of_the_cache() -> void:
	var first := _renderer()
	var rendered := await _started(first, true)
	assert_false(first.was_cached)
	var second := _renderer()
	var loaded := await _started(second, true)
	assert_true(second.was_cached)
	assert_eq(loaded.data, rendered.data)
	assert_eq(second.beat_seconds, first.beat_seconds)
	assert_eq([loaded.mix_rate, loaded.stereo], [RATE, false])
	assert_eq([loaded.loop_mode, loaded.loop_end], [rendered.loop_mode, rendered.loop_end])


func test_a_render_with_no_cache_is_never_kept() -> void:
	var renderer := _renderer()
	renderer.cache = null
	await _started(renderer)
	assert_eq(_cache.size_bytes(), 0)


func test_any_other_setting_is_a_miss() -> void:
	await _started(_renderer())
	var changed_module := _bytes.duplicate()
	changed_module[20 + 25] ^= 1  # the first sample's volume
	var others := {
		"rate": _renderer(_bytes, 44100),
		"channels": _renderer(_bytes, RATE, true),
		"beat": _renderer(),
		"module": _renderer(changed_module),
	}
	others["beat"].rows_per_beat = 6
	for setting in others:
		await _started(others[setting])
		assert_false(others[setting].was_cached, "another %s" % setting)
	var loops := _renderer()
	await _started(loops, true)
	assert_false(loops.was_cached, "a looping render")
	var shorter := _renderer()
	shorter.start([Vector2i(0, 16)])
	await wait_until(shorter.is_done, PATIENCE_SECONDS)
	shorter.take()
	assert_false(shorter.was_cached, "other parts")


func test_a_broken_file_is_rendered_again() -> void:
	var renderer := _renderer()
	var rendered := await _started(renderer)
	var path := DIR.path_join(renderer.cache_key([LOOP], false) + ".render")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a render")
	file.close()
	var again := _renderer()
	var stream := await _started(again)
	assert_false(again.was_cached)
	assert_eq(stream.data, rendered.data)
	var third := _renderer()
	await _started(third)
	assert_true(third.was_cached, "the new render was kept")


func test_the_cache_stays_within_its_bound() -> void:
	_cache.max_bytes = 500 * 1000
	await _started(_renderer())
	assert_eq(_cache.size_bytes(), 0, "a render of 800 kB doesn't fit a bound of 500 kB")
