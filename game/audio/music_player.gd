class_name MusicPlayer
extends Node
## Plays the pieces of assets/music/ (made by tools/music/generate.py) on the Music bus, each
## looping its form (its sections one after the other, see MusicRules.form), when asked: `play`
## and `stop` are the console's commands and the MusicDirector's. A piece is rendered by a
## ModuleRenderer on a WorkerThreadPool thread (or loaded from the MusicCache there), so the main
## thread only takes the finished stream, and never waits for one: what plays goes on looping
## until the next is done; `started` tells when the music begins. Another piece while one plays
## is crossfaded to on the bar.
##
## Each piece has two mixes: the whole one, and a quieter one for indoors (task 171: each channel
## turned down by `channel_levels` of data/music.cfg's [indoors]). `set_indoors` picks the mix; the
## other mix of the piece that plays is rendered as soon as the first is done, so the switch is
## ready when the player passes the door, and blends in step (MusicCrossfade.blend). Both mixes of
## the wanted piece are kept while it is wanted.
##
## A piece is called by its file name without the extension (see Console for the short names).

## A piece has been rendered and begins to play (or to crossfade in); not for a switch of its mix.
signal started(track: String)

## The pieces are found by listing this folder, so a build that packs the game must export the
## .mod files of assets/music/ for DirAccess to see them on res:// (export_presets.cfg does).
const MUSIC_DIR := "res://assets/music"
const CACHE_DIR := "user://music_cache"
const MIX_RATE := 44100
## The whole mix: every channel at its full volume.
const WHOLE_MIX: Array[float] = [1.0, 1.0, 1.0, 1.0]

var music_dir := MUSIC_DIR
## The form each piece plays in, and the mix indoors.
var rules := MusicRules.default_rules()
## How long `stop` takes to fade the music out, a crossfade between two pieces to fade, and the
## switch between the mixes.
var stop_seconds := MusicRules.default_rules().stop_seconds()
var crossfade_seconds := MusicRules.default_rules().crossfade_seconds()
var mix_seconds := MusicRules.default_rules().indoors_fade_seconds()
var cache := MusicCache.new(CACHE_DIR, MusicRules.default_rules().cache_bytes())
## How long the loop that plays (its form once round) lasts, in seconds, once `started` was emitted.
var loop_seconds := 0.0

var _crossfade := MusicCrossfade.new(AudioService.MUSIC)
## The track that is to play once its render is done: older renders are dropped when they finish.
var _wanted := ""
var _wanted_piece: MusicPiece
## The rendered mixes of the wanted track: {is indoors: AudioStreamWAV}.
var _mixes := {}
## The wanted track's bar, in seconds, once a mix of it was rendered.
var _bar_seconds := 0.0
var _is_indoors := false
## The track the crossfade plays or heads for, "" once stopped, and which of its mixes.
var _heard := ""
var _heard_indoors := false
var _renders: Array[Render] = []


## A render under way.
class Render:
	var track: String
	var is_indoors: bool
	var renderer: ModuleRenderer
	var bar_beats: int


func _init() -> void:
	# The music goes on while the game is paused (the crossfade must too, or it stops half-way).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_child(_crossfade)


func _process(_delta: float) -> void:
	for render: Render in _renders.filter(func(r: Render) -> bool: return r.renderer.is_done()):
		_renders.erase(render)
		var stream := render.renderer.take()
		if render.track == _wanted and stream != null:
			_mixes[render.is_indoors] = stream
			_bar_seconds = render.renderer.beat_seconds * render.bar_beats
			loop_seconds = MusicCrossfade.loop_seconds(stream)
			_follow()


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
	return _heard != ""


## Whether a piece (or a mix of it) is being rendered.
func is_rendering() -> bool:
	return not _renders.is_empty()


## Whether the quieter mix of indoors is the one asked for.
func is_indoors() -> bool:
	return _is_indoors


## Starts rendering `track` (see `tracks`), to play it as soon as it is done, instead of the
## piece that was asked for before. Returns what to tell the player; asking again for the piece
## that is rendering or playing starts nothing.
func play(track: String) -> String:
	if track == _wanted:
		return "Already %s %s" % ["playing" if _heard == track else "rendering", track]
	var piece := MusicPiece.read(music_dir, track)
	if piece == null:
		return "Can't play %s" % track
	var problem := piece.form_problem(rules.form(track))
	if problem != "":
		push_error("MusicPlayer: the form of %s" % problem)
		return "Can't play %s" % track
	_wanted = track
	_wanted_piece = piece
	_mixes = {}
	_follow()
	return "Rendering %s..." % track


## Switches to the quieter mix indoors, or back to the whole one: blended in step at once when
## that mix is rendered, else as soon as it is.
func set_indoors(is_indoors_now: bool) -> void:
	if is_indoors_now == _is_indoors:
		return
	_is_indoors = is_indoors_now
	if _wanted != "":
		_follow()


## A render still under way when the game quits is waited for, so no thread is left running.
func _exit_tree() -> void:
	for render in _renders:
		render.renderer.take()
	_renders.clear()


## Fades the music out, and drops a piece that is still being rendered.
func stop() -> void:
	_wanted = ""
	_wanted_piece = null
	_mixes = {}
	_heard = ""
	_crossfade.fade_out(stop_seconds)


## Makes what is heard follow what is wanted: the wanted track's mix for here once it is rendered
## (crossfaded to on the bar from another track, blended from its other mix), and the renders
## that are still missing started.
func _follow() -> void:
	var stream: AudioStreamWAV = _mixes.get(_is_indoors)
	if stream == null:
		_render(_is_indoors)
		return
	if _heard != _wanted:
		if _heard == "":
			_crossfade.play(stream, _bar_seconds)
		else:
			_crossfade.crossfade(stream, _bar_seconds, crossfade_seconds)
		_heard = _wanted
		_heard_indoors = _is_indoors
		started.emit(_wanted)
	elif _heard_indoors != _is_indoors:
		_crossfade.blend(stream, mix_seconds)
		_heard_indoors = _is_indoors
	if not _mixes.has(not _is_indoors):
		_render(not _is_indoors)


## Starts rendering the wanted track's mix, indoors or not, unless that runs already.
func _render(is_indoors_mix: bool) -> void:
	for render in _renders:
		if render.track == _wanted and render.is_indoors == is_indoors_mix:
			return
	var render := Render.new()
	render.track = _wanted
	render.is_indoors = is_indoors_mix
	render.bar_beats = _wanted_piece.bar_beats
	render.renderer = ModuleRenderer.new(_wanted_piece.module, MIX_RATE, true)
	render.renderer.rows_per_beat = _wanted_piece.beat_rows
	render.renderer.channel_levels = (
		rules.indoors_levels() if is_indoors_mix else PackedFloat32Array(WHOLE_MIX)
	)
	render.renderer.cache = cache
	render.renderer.start(_wanted_piece.parts(rules.form(_wanted)), true)
	_renders.append(render)
