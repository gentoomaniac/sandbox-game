class_name MusicCrossfade
extends Node
## Plays music on two AudioStreamPlayers and crossfades from one stream to the next on the beat.
## A prototype of task 169 for rendered music (plain AudioStreamWAVs from ModuleRenderer), as
## AudioStreamInteractive only switches on the beat with a stream subclass that crashes the quit.
## Nothing in the game uses it yet.
##
## `crossfade` waits for the next beat of what plays: each frame it reads how far the playing
## player has been mixed. The first frame past the beat, it starts the new stream on the other
## player from as far into it as the old one is past the beat, so from the next mix on both beat
## grids coincide, however late in the frame or the mix the beat came. The audio thread is held
## between reading the old position and starting the new stream, so no mix falls in between. Then
## the new stream fades in and the old one out, linearly in amplitude, over `fade_seconds` of the
## new stream's play (counted on across its loop's wraps, however many fall between two frames, so
## a fade may be longer than the loop and a stalled frame doesn't hold it back),
## and the old player stops. A crossfade asked for while one waits for its beat replaces it; one
## asked for while a fade runs waits until the fade is over (the newest only), so the gains never
## jump.
##
## A player's position runs READ_AHEAD_FRAMES ahead of what it has mixed (Godot's resampling reads
## its stream ahead in blocks), so that much is taken off. With that the beat grids line up within
## a frame or two when the streams have the mix rate (tests/test_music_crossfade.gd); at another
## rate the read-ahead is not constant, up to 128 frames of the stream (not measured). The fade
## begins late by up to a frame and a mix buffer (`lateness`): the new stream's first moments are
## skipped, under a fade from silence. `lateness` is when the new stream was scheduled; it is heard
## a little later still, as its gain rises from 0 from the next frame on.

## How far a player's position runs ahead of its mix, in frames of a stream at the mix rate: the
## block Godot 4.7.2's resampling reads ahead (AudioStreamPlaybackResampled), as measured.
const READ_AHEAD_FRAMES := 128

## How late the last crossfade began after its beat, in seconds.
var lateness := 0.0

var _players: Array[AudioStreamPlayer] = []
## The player that plays, or fades in.
var _current := 0
var _beat_seconds := 0.0
## The crossfade asked for: its stream, beat and fade, and the beat it starts on.
var _next: AudioStreamWAV
var _next_beat_seconds := 0.0
var _fade_seconds := 0.0
var _switch_seconds := 0.0
## How far the playing player was mixed when last looked at: a loop wraps past its end.
var _last_position := 0.0
var _is_fading := false
## How far the new stream has played since its fade began, its loop's wraps counted on.
var _fade_played := 0.0
## When the audio server mixed last as the fade looked (see `_last_mix_time`), in seconds.
var _last_mix_seconds := 0.0
## A crossfade asked for during a fade: [stream, beat seconds, fade seconds], or empty.
var _queued := []


func _init(bus := &"Master") -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = bus
		_players.append(player)
		add_child(player)


## Plays `stream` at once, alone, at full volume; `beat_seconds` is its beat.
func play(stream: AudioStreamWAV, beat_seconds: float) -> void:
	for player in _players:
		player.stop()
	_next = null
	_queued = []
	_is_fading = false
	_beat_seconds = beat_seconds
	_players[_current].volume_db = 0.0
	_players[_current].stream = stream
	_players[_current].play()


## Crossfades to `stream` (whose beat is `beat_seconds`) from the next beat of what plays, over
## `fade_seconds`; during a fade, from the next beat after it.
func crossfade(stream: AudioStreamWAV, beat_seconds: float, fade_seconds: float) -> void:
	if _is_fading:
		_queued = [stream, beat_seconds, fade_seconds]
		return
	var player := _players[_current]
	var position := _mixed_position(player)
	_next = stream
	_next_beat_seconds = beat_seconds
	_fade_seconds = fade_seconds
	_switch_seconds = ceilf(position / _beat_seconds) * _beat_seconds
	if _switch_seconds <= position:
		_switch_seconds += _beat_seconds
	# A loop's last beat ends on its start.
	_switch_seconds = fmod(_switch_seconds, player.stream.get_length())
	_last_position = position


## Whether a crossfade waits for its beat or fades.
func is_crossfading() -> bool:
	return _next != null or _is_fading or not _queued.is_empty()


func _process(_delta: float) -> void:
	if _next != null:
		_start_on_the_beat()
	elif _is_fading:
		_fade()


func _start_on_the_beat() -> void:
	var old := _players[_current]
	var new := _players[1 - _current]
	AudioServer.lock()
	var position := _mixed_position(old)
	var is_past := _last_position < _switch_seconds and position >= _switch_seconds
	if position < _last_position:
		# Wrapped from the loop's end onto its start: past the beat if it lay in between.
		is_past = _last_position < _switch_seconds or position >= _switch_seconds
	_last_position = position
	if not is_past:
		AudioServer.unlock()
		return
	lateness = fposmod(position - _switch_seconds, old.stream.get_length())
	new.stream = _next
	new.volume_db = linear_to_db(0.0)
	new.play(lateness)
	_last_mix_seconds = _last_mix_time()
	AudioServer.unlock()
	_current = 1 - _current
	_beat_seconds = _next_beat_seconds
	_next = null
	_is_fading = true
	_fade_played = 0.0
	_last_position = lateness


func _fade() -> void:
	var new := _players[_current]
	var old := _players[1 - _current]
	var mix_seconds := _last_mix_time()
	# Nothing to count before the new stream's first mix (its position may not be set yet).
	# (Two looks at the same mix may differ by a microsecond or so: a mix is far longer than 1 ms.)
	if mix_seconds > _last_mix_seconds + 0.001:
		var position := _mixed_position(new)
		var length := new.stream.get_length()
		_fade_played += played_seconds(
			_last_position, position, length, mix_seconds - _last_mix_seconds
		)
		_last_position = position
		_last_mix_seconds = mix_seconds
	var share := clampf(_fade_played / _fade_seconds, 0.0, 1.0)
	new.volume_db = linear_to_db(share)
	old.volume_db = linear_to_db(1.0 - share)
	if share < 1.0:
		return
	old.stop()
	_is_fading = false
	if not _queued.is_empty():
		var queued := _queued
		_queued = []
		crossfade(queued[0], queued[1], queued[2])


## How far a looping stream of `length` seconds played between two looks, from `last_position` to
## `position`, when the mixes between them took `mix_seconds`. The positions tell it to the sample
## but for whole loops; those follow from the mix time, however short the loop or long the frame.
## Known limit: the mix time is when the mixes happened, not how much they mixed; an audio thread
## held up for a while and then mixing one block looks like a long stretch of play, and a fade may
## end early by that much (see docs/music-viability.md).
static func played_seconds(
	last_position: float, position: float, length: float, mix_seconds: float
) -> float:
	var moved := fposmod(position - last_position, length)
	var loops := maxf(roundf((mix_seconds - moved) / length), 0.0)
	return moved + loops * length


## When the audio server last mixed, in seconds of the game's clock (Time.get_ticks_usec): the mixes
## keep pace with real time, so the time between two of them is the time they mixed.
static func _last_mix_time() -> float:
	return Time.get_ticks_usec() / 1e6 - AudioServer.get_time_since_last_mix()


## How far `player` has been mixed, in seconds of its stream (a loop's wrap included).
static func _mixed_position(player: AudioStreamPlayer) -> float:
	var stream := player.stream as AudioStreamWAV
	var ahead := READ_AHEAD_FRAMES / float(stream.mix_rate)
	return fposmod(player.get_playback_position() - ahead, stream.get_length())
