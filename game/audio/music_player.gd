class_name MusicPlayer
extends Node
## Plays the pieces of assets/music/ (made by tools/music/generate.py) on the Music bus, each
## looping its first section, when asked: `play` and `stop` are the console's commands and
## EverydayMusic's. A piece is rendered by a ModuleRenderer on a WorkerThreadPool thread (or
## loaded from the MusicCache there), so the main thread only takes the finished stream, and never
## waits for one: what plays goes on looping until the next is done; `started` tells when the
## music begins. Another piece while one plays is crossfaded to on the beat.
##
## A piece is called by its file name without the extension (see Console for the short names).

## A piece has been rendered and begins to play (or to crossfade in).
signal started(track: String)

## The pieces are found by listing this folder, so a build that packs the game must export the
## .mod files of assets/music/ for DirAccess to see them on res:// (export_presets.cfg does).
const MUSIC_DIR := "res://assets/music"
const CACHE_DIR := "user://music_cache"
const MIX_RATE := 44100

var music_dir := MUSIC_DIR
## How long `stop` takes to fade the music out, and a crossfade between two pieces to fade.
var stop_seconds := MusicRules.default_rules().stop_seconds()
var crossfade_seconds := MusicRules.default_rules().crossfade_seconds()
var cache := MusicCache.new(CACHE_DIR, MusicRules.default_rules().cache_bytes())
## How long the loop that plays lasts, in seconds, once `started` was emitted.
var loop_seconds := 0.0

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


func _init() -> void:
	# The music goes on while the game is paused (the crossfade must too, or it stops half-way).
	process_mode = Node.PROCESS_MODE_ALWAYS


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


## The piece that plays or is about to, "" when stopped.
func wanted_track() -> String:
	return _wanted


## Whether music plays, or is coming in; false once stopped.
func is_playing() -> bool:
	return _is_playing


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
	var piece := MusicPiece.read(music_dir, track)
	if piece == null:
		return "Can't play %s" % track
	_wanted = track
	var render := Render.new()
	render.track = track
	render.renderer = ModuleRenderer.new(piece.module, MIX_RATE, true)
	render.renderer.rows_per_beat = piece.beat_rows
	render.renderer.cache = cache
	render.renderer.start([piece.loop_section().part()], true)
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
	loop_seconds = stream.get_length()
	if _is_playing:
		_crossfade.crossfade(stream, render.renderer.beat_seconds, crossfade_seconds)
	else:
		_crossfade.play(stream, render.renderer.beat_seconds)
	_is_playing = true
	started.emit(render.track)
