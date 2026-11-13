extends GutTest
## MusicCache: renders kept in a folder of their own: a hit gives the stream and beat that were
## written, a miss or a broken file gives nothing, and the folder stays within its bound by
## dropping the oldest first.

const DIR := "user://test_music_cache"
const DATA_BYTES := 1000

var _cache: MusicCache


func before_each() -> void:
	_cache = MusicCache.new(DIR, 10 * DATA_BYTES)


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _stream(fill: int, loops := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(DATA_BYTES)
	data.fill(fill)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = true
	stream.data = data
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = DATA_BYTES / 4
	return stream


func _file_size(key: String) -> int:
	return FileAccess.get_file_as_bytes(DIR.path_join(key + ".render")).size()


func test_a_written_render_comes_back_as_it_was() -> void:
	_cache.write("a", _stream(7, true), 0.75)
	var entry := _cache.read("a")
	assert_eq(entry.beat_seconds, 0.75)
	assert_eq(entry.stream.data, _stream(7).data)
	assert_eq([entry.stream.mix_rate, entry.stream.stereo], [44100, true])
	assert_eq(entry.stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(entry.stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(entry.stream.loop_end, DATA_BYTES / 4)


func test_a_stream_that_does_not_loop_comes_back_without_a_loop() -> void:
	_cache.write("a", _stream(7), 0.5)
	assert_eq(_cache.read("a").stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_a_key_that_was_never_written_is_a_miss() -> void:
	assert_null(_cache.read("never"))
	_cache.write("a", _stream(1), 0.5)
	assert_null(_cache.read("b"))


func test_writing_again_replaces_the_render() -> void:
	_cache.write("a", _stream(1), 0.5)
	_cache.write("a", _stream(2), 0.25)
	assert_eq(_cache.read("a").stream.data, _stream(2).data)
	assert_eq(_cache.read("a").beat_seconds, 0.25)
	assert_eq(_cache.size_bytes(), _file_size("a"))


func test_a_file_that_is_cut_off_or_not_ours_is_a_miss_and_goes() -> void:
	_cache.write("cut", _stream(1), 0.5)
	_cache.write("foreign", _stream(1), 0.5)
	_cache.write("empty", _stream(1), 0.5)
	var bytes := FileAccess.get_file_as_bytes(DIR.path_join("cut.render"))
	var file := FileAccess.open(DIR.path_join("cut.render"), FileAccess.WRITE)
	file.store_buffer(bytes.slice(0, bytes.size() - 1))
	file.close()
	file = FileAccess.open(DIR.path_join("foreign.render"), FileAccess.WRITE)
	file.store_buffer(bytes.slice(1))
	file.close()
	FileAccess.open(DIR.path_join("empty.render"), FileAccess.WRITE).close()
	for key in ["cut", "foreign", "empty"]:
		assert_null(_cache.read(key), key)
		assert_false(FileAccess.file_exists(DIR.path_join(key + ".render")), key + " is removed")
	_cache.write("cut", _stream(3), 0.5)
	assert_eq(_cache.read("cut").stream.data, _stream(3).data, "and is rendered again")


func test_a_folder_that_does_not_exist_yet_holds_nothing() -> void:
	assert_eq(_cache.size_bytes(), 0)
	assert_null(_cache.read("a"))


func test_the_oldest_renders_go_when_the_folder_is_over_its_bound() -> void:
	var one := MusicCache.HEADER_SIZE + DATA_BYTES
	_cache.max_bytes = 2 * one
	for key in ["first", "second", "third"]:
		_cache.write(key, _stream(1), 0.5)
	assert_null(_cache.read("first"))
	assert_not_null(_cache.read("second"))
	assert_not_null(_cache.read("third"))
	assert_eq(_cache.size_bytes(), 2 * one)


func test_a_file_that_is_not_ours_goes_before_the_oldest_render() -> void:
	var one := MusicCache.HEADER_SIZE + DATA_BYTES
	_cache.max_bytes = 2 * one
	_cache.write("old", _stream(1), 0.5)
	var file := FileAccess.open(DIR.path_join("junk.render"), FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	_cache.write("new", _stream(1), 0.5)
	assert_not_null(_cache.read("old"))
	assert_not_null(_cache.read("new"))
	assert_false(FileAccess.file_exists(DIR.path_join("junk.render")))


func test_a_failed_move_leaves_no_unfinished_file() -> void:
	_cache.write("a", _stream(1), 0.5)
	DirAccess.remove_absolute(DIR.path_join("a.render"))
	DirAccess.make_dir_absolute(DIR.path_join("a.render"))
	_cache.write("a", _stream(2), 0.5)
	assert_push_error_count(1)
	assert_eq(DirAccess.get_files_at(DIR), PackedStringArray())
	DirAccess.remove_absolute(DIR.path_join("a.render"))


func test_a_fresh_unfinished_file_is_left_alone() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for count in 5:
		var file := FileAccess.open(DIR.path_join("x.render.%d.tmp" % randi()), FileAccess.WRITE)
		file.close()
	_cache.stray_seconds = 1000.0
	_cache.write("a", _stream(1), 0.5)
	assert_eq(DirAccess.get_files_at(DIR).size(), 6, "fresh unfinished files are left alone")


func test_stray_unfinished_files_of_a_crash_go() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR.path_join("old.render.1.tmp"), FileAccess.WRITE)
	file.close()
	_cache.stray_seconds = 0.0
	_cache.write("a", _stream(1), 0.5)
	assert_eq(DirAccess.get_files_at(DIR), PackedStringArray(["a.render"]))


func test_no_unfinished_file_stays_behind() -> void:
	_cache.write("a", _stream(1), 0.5)
	assert_eq(DirAccess.get_files_at(DIR), PackedStringArray(["a.render"]))
