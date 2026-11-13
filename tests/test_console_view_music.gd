extends EnergyCase
## The console view with the game's MusicPlayer: its `play` and `stop` reach the player, and the log
## says when a piece begins.

var _view: ConsoleView
var _music: MusicPlayer


func before_each() -> void:
	super.before_each()
	_music = MusicPlayer.new()
	add_child_autofree(_music)
	_view = ConsoleView.new()
	add_child_autofree(_view)
	_view.show_state(_state, Callable(), Callable(), _music)


func test_stop_fades_the_players_music_out() -> void:
	_view.run_line("stop")
	assert_string_contains(_view._log.text, "Music fading out")


func test_an_unknown_track_is_listed_from_the_players_folder() -> void:
	_view.run_line("play polka")
	assert_string_contains(_view._log.text, "sketch_tide")


func test_the_log_says_when_a_piece_begins() -> void:
	_music.started.emit("sketch_tide")
	assert_string_contains(_view._log.text, "Playing sketch_tide")


func test_without_a_player_play_says_there_is_no_music() -> void:
	var bare := ConsoleView.new()
	add_child_autofree(bare)
	bare.show_state(_state)
	bare.run_line("play tide")
	assert_string_contains(bare._log.text, Console.NO_MUSIC)
