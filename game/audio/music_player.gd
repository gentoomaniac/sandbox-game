class_name MusicPlayer
extends Node
## Plays the pieces of assets/music/ (made by tools/music/generate.py) on the Music bus, looping,
## when asked: `play` and `stop` are the console's commands, and nothing else starts music yet
## (the music director of tasks 170 and 171 comes later). A piece is rendered by a ModuleRenderer
## on a WorkerThreadPool thread, so the main thread only takes the finished stream; `started`
## tells when the music begins. Another piece while one plays is crossfaded to on the beat.
##
## A piece is called by its file name without the extension (see Console for the short names).

## A piece has been rendered and begins to play (or to crossfade in).
signal started(track: String)

## The pieces are found by listing this folder, so a build that packs the game must export the
## .mod files of assets/music/ for DirAccess to see them on res:// (export_presets.cfg does).
const MUSIC_DIR := "res://assets/music"
const MIX_RATE := 44100
## The pieces are 16-bit stereo.
const BYTES_PER_FRAME := 4

var music_dir := MUSIC_DIR
## How long `stop` takes to fade the music out, and a crossfade between two pieces to fade.
var stop_seconds := 2.0
var crossfade_seconds := 4.0

var _crossfade := MusicCrossfade.new(AudioService.MUSIC)
## The track that is to play once its render is done: older renders are dropped when they finish.
var _wanted := ""
var _renders: Array[Render] = []
## Whether music plays (or is being crossfaded in), so the next piece crossfades; false while it
## fades out.
var _is_playing := false


## A render under way.
class Render:
	var track: String
	var renderer: ModuleRenderer


func _ready() -> void:
	add_child(_crossfade)


func _process(_delta: float) -> void:
	for render: Render in _renders.filter(func(r: Render) -> bool: return r.renderer.is_done()):
		_renders.erase(render)
		var stream := render.renderer.take()
		if render.track == _wanted:
			_start(render, stream)


## The pieces there are, by file name without the extension.
func tracks() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(music_dir):
		if file.get_extension() == "mod":
			names.append(file.get_basename())
	names.sort()
	return names


## Whether a piece is being rendered, to play when it is ready.
func is_rendering() -> bool:
	return not _renders.is_empty()


## Starts rendering `track` (see `tracks`), to play it as soon as it is done, instead of the
## piece that was asked for before. Returns what to tell the player; asking again for the piece
## that is rendering or playing starts nothing.
func play(track: String) -> String:
	if track == _wanted:
		var is_rendering_it := _renders.any(
			func(render: Render) -> bool: return render.track == track
		)
		return "Already %s %s" % ["rendering" if is_rendering_it else "playing", track]
	_wanted = track
	var bytes := FileAccess.get_file_as_bytes(music_dir.path_join(track + ".mod"))
	var render := Render.new()
	render.track = track
	var module := TrackerModule.from_bytes(bytes)
	render.renderer = ModuleRenderer.new(module, MIX_RATE, true)
	render.renderer.start([Vector2i(0, render.renderer.rows_once_through())], true)
	_renders.append(render)
	return "Rendering %s..." % track


## A render still under way when the game quits is waited for, so no thread is left running.
func _exit_tree() -> void:
	for render in _renders:
		render.renderer.take()
	_renders.clear()


## Fades the music out, and drops a piece that is still being rendered.
func stop() -> void:
	_wanted = ""
	_is_playing = false
	_crossfade.fade_out(stop_seconds)


func _start(render: Render, stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / BYTES_PER_FRAME
	if _is_playing:
		_crossfade.crossfade(stream, render.renderer.beat_seconds, crossfade_seconds)
	else:
		_crossfade.play(stream, render.renderer.beat_seconds)
	_is_playing = true
	started.emit(render.track)
