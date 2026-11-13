class_name MusicCache
extends RefCounted
## Renders kept in a folder (user://music_cache/ in the game), so a piece rendered once loads in a
## few milliseconds the next time instead of taking a second to render. A file is named by its key
## (what ModuleRenderer hashes: the module, the mix settings and the renderer's version, so a
## render made by another version is never found) and holds the stream's 16-bit data after a
## header. The folder is bounded: `write` drops the oldest files while the total is over
## `max_bytes`. A file that is cut off or not ours is a miss, and goes.
##
## Meant for a WorkerThreadPool thread, which reads and writes whole files; nothing here is
## shared between calls but the files, and a file is renamed into place when complete, so a
## reader never sees half of one.

const EXTENSION := "render"
const MAGIC := "SGMR"
## The header's bytes: the magic, then the fields of `Header`.
const HEADER_SIZE := 4 + 4 + 1 + 4 + 8 + 8 + 4

var directory := ""
var max_bytes := 0
## How old an unfinished file must be to count as left by a crash, not as being written.
var stray_seconds := 600.0


## What a file holds: the stream, made whole, and the beat of the render.
class Entry:
	var stream: AudioStreamWAV
	var beat_seconds := 0.0


## What precedes the data in a file.
class Header:
	var mix_rate := 0
	var is_stereo := false
	## The frame the stream loops from its end (0 when it doesn't loop).
	var loop_end := 0
	var beat_seconds := 0.0
	var written_at := 0.0
	var data_size := 0

	## The header in `bytes`, or null when they are not a header of ours.
	static func parse(bytes: PackedByteArray) -> Header:
		if bytes.size() != HEADER_SIZE or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
			return null
		var reader := StreamPeerBuffer.new()
		reader.data_array = bytes
		reader.seek(4)
		var header := Header.new()
		header.mix_rate = reader.get_u32()
		header.is_stereo = reader.get_u8() == 1
		header.loop_end = reader.get_u32()
		header.beat_seconds = reader.get_double()
		header.written_at = reader.get_double()
		header.data_size = reader.get_u32()
		return header

	func to_bytes() -> PackedByteArray:
		var writer := StreamPeerBuffer.new()
		writer.put_data(MAGIC.to_ascii_buffer())
		writer.put_u32(mix_rate)
		writer.put_u8(1 if is_stereo else 0)
		writer.put_u32(loop_end)
		writer.put_double(beat_seconds)
		writer.put_double(written_at)
		writer.put_u32(data_size)
		return writer.data_array


func _init(cache_directory: String, size_limit_bytes: int) -> void:
	directory = cache_directory
	max_bytes = size_limit_bytes


## The render kept under `key`; null when there is none, or when its file is broken (which is then
## removed).
func read(key: String) -> Entry:
	var path := _path(key)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var entry := _read_entry(file)
	file.close()
	if entry == null:
		DirAccess.remove_absolute(path)
	return entry


## Keeps `stream` (16-bit, as ModuleRenderer makes it) and its beat under `key`, replacing what
## was there, and then drops the oldest renders while the folder is over its bound.
func write(key: String, stream: AudioStreamWAV, beat_seconds: float) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var data := stream.data
	var header := Header.new()
	header.mix_rate = stream.mix_rate
	header.is_stereo = stream.stereo
	header.loop_end = stream.loop_end if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD else 0
	header.beat_seconds = beat_seconds
	header.written_at = Time.get_unix_time_from_system()
	header.data_size = data.size()
	var path := _path(key)
	# Its own name, so that two writes of one key (or two game instances) don't share the file.
	var unfinished := "%s.%d.tmp" % [path, randi()]
	var file := FileAccess.open(unfinished, FileAccess.WRITE)
	if file == null:
		push_error("MusicCache: can't write %s" % unfinished)
		return
	file.store_buffer(header.to_bytes())
	file.store_buffer(data)
	file.close()
	if DirAccess.rename_absolute(unfinished, path) != OK:
		push_error("MusicCache: can't move %s into place" % unfinished)
		DirAccess.remove_absolute(unfinished)
		return
	_drop_oldest()


## The bytes of all the renders in the folder.
func size_bytes() -> int:
	var total := 0
	for key in _keys():
		total += _file_size(_path(key))
	return total


## The keys of the renders in the folder.
func _keys() -> Array[String]:
	var keys: Array[String] = []
	if not DirAccess.dir_exists_absolute(directory):
		return keys
	for file_name in DirAccess.get_files_at(directory):
		if file_name.get_extension() == EXTENSION:
			keys.append(file_name.get_basename())
	return keys


func _path(key: String) -> String:
	return directory.path_join("%s.%s" % [key, EXTENSION])


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return 0 if file == null else file.get_length()


## The entry in an open file, or null when the file is not ours or cut off.
func _read_entry(file: FileAccess) -> Entry:
	var header := Header.parse(file.get_buffer(HEADER_SIZE))
	if (
		header == null
		or header.data_size == 0
		or file.get_length() != HEADER_SIZE + header.data_size
	):
		return null
	var entry := Entry.new()
	entry.beat_seconds = header.beat_seconds
	entry.stream = AudioStreamWAV.new()
	entry.stream.format = AudioStreamWAV.FORMAT_16_BITS
	entry.stream.mix_rate = header.mix_rate
	entry.stream.stereo = header.is_stereo
	entry.stream.data = file.get_buffer(header.data_size)
	if header.loop_end > 0:
		entry.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		entry.stream.loop_end = header.loop_end
	return entry


## When the render of `key` was written, 0 for a file that is not ours.
func _written_at(key: String) -> float:
	var file := FileAccess.open(_path(key), FileAccess.READ)
	var header := Header.parse(file.get_buffer(HEADER_SIZE)) if file != null else null
	return 0.0 if header == null else header.written_at


## Removes stray unfinished files, then the oldest renders (broken ones first) until the folder
## fits `max_bytes`.
func _drop_oldest() -> void:
	for file_name in DirAccess.get_files_at(directory):
		var path := directory.path_join(file_name)
		var age := Time.get_unix_time_from_system() - FileAccess.get_modified_time(path)
		if file_name.get_extension() == "tmp" and age >= stray_seconds:
			DirAccess.remove_absolute(path)
	var keys := _keys()
	var written := {}
	for key in keys:
		written[key] = _written_at(key)
	keys.sort_custom(func(a: String, b: String) -> bool: return written[a] < written[b])
	var total := size_bytes()
	for key in keys:
		if total <= max_bytes:
			return
		total -= _file_size(_path(key))
		DirAccess.remove_absolute(_path(key))
