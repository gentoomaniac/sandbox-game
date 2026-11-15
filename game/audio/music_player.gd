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
## A piece may have two versions (#15, MusicPiece): the chiptune for the classic art and a fuller
## one for the 32 px art. `set_classic` picks the version; when it changes, the other version's
## mix for here is rendered (the old one plays on meanwhile) and blends in on the next bar, in step,
## over the [versions] fade of data/music.cfg; then its other mix renders. Only the mixes of the
## version wanted are kept (the cache has the others).
##
## A piece is called by its file name without the extension (see Console for the short names); a
## fuller version is no piece of its own.

## A piece has been rendered and begins to play (or to crossfade in); not for a switch of its mix
## or version.
signal started(track: String)

## The pieces are found by listing this folder, so a build that packs the game must export the
## .mod files of assets/music/ for DirAccess to see them on res:// (export_presets.cfg does).
const MUSIC_DIR := "res://assets/music"
const CACHE_DIR := "user://music_cache"
const MIX_RATE := 44100

var music_dir := MUSIC_DIR
## The form each piece plays in, and the mix indoors.
var rules := MusicRules.default_rules()
## How long `stop` takes to fade the music out, a crossfade between two pieces to fade, and the
## switches between the mixes and between the versions.
var stop_seconds := MusicRules.default_rules().stop_seconds()
var crossfade_seconds := MusicRules.default_rules().crossfade_seconds()
var mix_seconds := MusicRules.default_rules().indoors_fade_seconds()
var version_seconds := MusicRules.default_rules().versions_fade_seconds()
var cache := MusicCache.new(CACHE_DIR, MusicRules.default_rules().cache_bytes())
## How long the loop that plays (its form once round) lasts, in seconds, once `started` was emitted.
var loop_seconds := 0.0

var _crossfade := MusicCrossfade.new(AudioService.MUSIC)
## The track that is to play once its render is done: older renders are dropped when they finish.
var _wanted := ""
var _wanted_piece: MusicPiece
## The rendered mixes of the wanted track's version: {mix (see `_mix`): AudioStreamWAV}.
var _mixes := {}
## The wanted track's bar, in seconds, once a mix of it was rendered.
var _bar_seconds := 0.0
var _is_indoors := false
var _is_classic := false
## The track the crossfade plays or heads for, "" once stopped, and which mix of it.
var _heard := ""
var _heard_mix := Vector2i.ZERO
var _renders: Array[Render] = []


## A render under way.
class Render:
	var track: String
	## Which mix of the track (see `_mix`).
	var mix: Vector2i
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
		if render.track == _wanted and render.mix.x == _mix().x and stream != null:
			_mixes[render.mix] = stream
			_bar_seconds = render.renderer.beat_seconds * render.bar_beats
			loop_seconds = MusicCrossfade.loop_seconds(stream)
			_follow()


## The pieces there are, by file name without the extension (their fuller versions not counted).
func tracks() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(music_dir):
		if (
			file.get_extension() == "mod"
			and not file.get_basename().ends_with(MusicPiece.FULL_SUFFIX)
		):
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


## Whether the chiptune version is the one asked for (with the classic art).
func is_classic() -> bool:
	return _is_classic


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


## Switches to the chiptune version of each piece (for the classic art), or back to the fuller one
## (the 32 px art): blended in step on the next bar once the other version is rendered.
func set_classic(is_classic_now: bool) -> void:
	if is_classic_now == _is_classic:
		return
	_is_classic = is_classic_now
	if _wanted == "":
		return
	for mix: Vector2i in _mixes.keys():
		if mix.x != _mix().x:
			_mixes.erase(mix)
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
## (crossfaded to on the bar from another track, blended from its other mix at once and from its
## other version on the bar), and the renders that are still missing started.
func _follow() -> void:
	var mix := _mix()
	var stream: AudioStreamWAV = _mixes.get(mix)
	if stream == null:
		_render(mix)
		return
	if _heard != _wanted:
		if _heard == "":
			_crossfade.play(stream, _bar_seconds)
		else:
			_crossfade.crossfade(stream, _bar_seconds, crossfade_seconds)
		_heard = _wanted
		started.emit(_wanted)
	elif _heard_mix.x != mix.x:
		_crossfade.blend(stream, version_seconds, _bar_seconds)
	elif _heard_mix != mix:
		_crossfade.blend(stream, mix_seconds)
	_heard_mix = mix
	var other_mix := Vector2i(mix.x, 1 - mix.y)
	if not _mixes.has(other_mix):
		_render(other_mix)


## The mix of the wanted track for here: Vector2i(1 for its fuller version (where it has one) or
## 0 for the chiptune, 1 indoors or 0 outdoors).
func _mix() -> Vector2i:
	var is_full := not _is_classic and _wanted_piece.full_module != null
	return Vector2i(int(is_full), int(_is_indoors))


## Starts rendering the wanted track's `mix` (see `_mix`), unless that runs already.
func _render(mix: Vector2i) -> void:
	for render in _renders:
		if render.track == _wanted and render.mix == mix:
			return
	var render := Render.new()
	render.track = _wanted
	render.mix = mix
	render.bar_beats = _wanted_piece.bar_beats
	var module := _wanted_piece.module_of(mix.x == 1)
	render.renderer = ModuleRenderer.new(module, MIX_RATE, true)
	render.renderer.rows_per_beat = _wanted_piece.beat_rows
	if mix.y == 1:
		render.renderer.channel_levels = rules.indoors_levels(module.channels)
	render.renderer.cache = cache
	render.renderer.start(_wanted_piece.parts(rules.form(_wanted)), true)
	_renders.append(render)
