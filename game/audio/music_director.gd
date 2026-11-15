class_name MusicDirector
extends Node
## Decides what music plays (task 171), by the rules of data/music.cfg, and has the MusicPlayer
## play it. Each frame it looks at the moment (a MusicMoment, from the Callable it is given; null
## while there is no game yet):
## - The pieces that fit the moment are the everyday pieces whose `hours` hold the hour (all of
##   them when none does). The first that fits starts the music.
## - A piece plays at least `min_seconds` before another may take over. After that a piece that no
##   longer fits gives way to the next that does; one that fits gives way after `switch_seconds`
##   when another fits too, the next in the order of the file (the first that fits, after one that
##   doesn't). The new piece renders in the background and crossfades in on the bar.
## - Inside a building the quieter mix of what plays blends in, and the whole one on the way out
##   (MusicPlayer.set_indoors).
## - With the classic art the chiptune version of each piece plays, with the 32 px art its fuller
##   one (#15); as the art changes, the other version blends in on the bar
##   (MusicPlayer.set_classic).
## Whatever the player is told to play (the console's `play`) is followed the same way; a player
## that was stopped (the console's `stop`) stays quiet. The fills come with each piece's form.

var _player: MusicPlayer
var _rules: MusicRules
var _moment_of: Callable
## Whether the director started the music: a player that wants nothing afterwards was stopped.
var _has_started := false
## How long the piece that plays has played, in seconds since it was asked for or started (paused
## or not).
var _played_seconds := 0.0


## Whether the game plays music by itself: not when it is muted (the tests and benchmarks
## mute it), and not where the audio driver is Dummy (headless: nothing could be heard).
static func is_wanted(is_muted: bool, driver := AudioServer.get_driver_name()) -> bool:
	return not is_muted and driver != "Dummy"


## `moment_of` returns the MusicMoment to choose by, or null while there is none.
func _init(player: MusicPlayer, moment_of: Callable, rules := MusicRules.default_rules()) -> void:
	_player = player
	_moment_of = moment_of
	_rules = rules
	# The music goes on while the game is paused, and so does what steers it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_player.started.connect(func(_track: String) -> void: _played_seconds = 0.0)


func _process(delta: float) -> void:
	_played_seconds += delta
	var moment: MusicMoment = _moment_of.call()
	if moment == null:
		return
	_player.set_indoors(moment.is_inside)
	_player.set_classic(moment.is_classic_art)
	var next := _rules.fitting_pieces(moment.hour)[0] if not _has_started else next_piece(moment)
	if next != "":
		_has_started = true
		_played_seconds = 0.0
		_player.play(next)


## The piece to take over from what plays at `moment`, or "" to go on with it (or stay quiet).
func next_piece(moment: MusicMoment) -> String:
	var current := _player.wanted_track()
	if current == "" or _played_seconds < _rules.min_seconds():
		return ""
	var fitting := _rules.fitting_pieces(moment.hour)
	var at := fitting.find(current)
	if at >= 0 and (fitting.size() == 1 or _played_seconds < _rules.switch_seconds()):
		return ""
	# The next that fits, or the first when what plays doesn't.
	return fitting[(at + 1) % fitting.size()]
