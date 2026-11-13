class_name EverydayMusic
extends Node
## The music that plays when nothing else asks for it: the everyday pieces of data/music.cfg one
## after the other, round and round. It has the MusicPlayer start the first, and once a piece has
## looped `loops_before_switch` times it asks for the next: that renders in the background while
## the piece goes on looping, and crossfades in on the next beat when done. Whatever the player
## plays (the console's `play`) is followed the same way, going on with the first everyday piece
## when it isn't one; a player stopped (the console's `stop`) stays quiet. The music director of
## task 171 will choose the pieces by the time of day and the weather instead.

var _player: MusicPlayer
var _rules: MusicRules
## Fires when the piece that plays has looped as often as the rules say.
var _loops_timer := Timer.new()


## Whether the game plays music by itself: not when it is muted (the tests and benchmarks
## mute it), and not where the audio driver is Dummy (headless: nothing could be heard).
static func is_wanted(is_muted: bool, driver := AudioServer.get_driver_name()) -> bool:
	return not is_muted and driver != "Dummy"


func _init(player: MusicPlayer, rules := MusicRules.default_rules()) -> void:
	_player = player
	_rules = rules
	# The music goes on while the game is paused, and so does what steers it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loops_timer.one_shot = true
	_loops_timer.timeout.connect(_play_next)
	add_child(_loops_timer)


func _ready() -> void:
	_player.started.connect(_on_started)
	_player.play(_rules.everyday_pieces()[0])


func _on_started(_track: String) -> void:
	_loops_timer.start(_rules.loops_before_switch() * _player.loop_seconds)


func _play_next() -> void:
	if not _player.is_playing():
		return
	var pieces := _rules.everyday_pieces()
	var after := pieces.find(_player.wanted_track()) + 1
	_player.play(pieces[after % pieces.size()])
