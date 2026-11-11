extends EnergyCase
## The console's `play` and `stop`, with the music faked: what they ask for and say.

var _console: Console
var _played: Array[String] = []
var _stops := 0


func before_each() -> void:
	super.before_each()
	_played.clear()
	_stops = 0
	_console = Console.new(_state)
	_console.music_tracks = func() -> Array[String]:
		return ["sketch_harbour", "sketch_tide", "test_reel"]
	_console.music_player = func(track: String) -> String:
		_played.append(track)
		return "Rendering %s..." % track
	_console.music_stopper = func() -> void: _stops += 1


func test_a_known_track_is_played_by_its_whole_name_or_without_its_first_word() -> void:
	assert_eq(_console.run("/play sketch_tide"), ["Rendering sketch_tide..."] as Array[String])
	_console.run("play tide")
	_console.run("play reel")
	assert_eq(_played, ["sketch_tide", "sketch_tide", "test_reel"] as Array[String])


func test_a_prefix_alone_is_no_name() -> void:
	var lines := _console.run("play sketch")
	assert_eq(lines[0], "Unknown track: sketch")
	assert_true(_played.is_empty())


func test_an_unknown_track_lists_the_tracks_and_plays_nothing() -> void:
	var lines := _console.run("play polka")
	assert_eq(lines[0], "Unknown track: polka")
	assert_eq(lines[1], "track: sketch_harbour, sketch_tide, test_reel")
	assert_true(_played.is_empty())


func test_play_without_a_track_shows_the_usage_and_the_tracks() -> void:
	var lines := _console.run("play")
	assert_eq(lines[0], "Usage: play <track>")
	assert_eq(lines.size(), 2)
	assert_true(_played.is_empty())


func test_stop_fades_the_music_out() -> void:
	assert_eq(_console.run("stop"), ["Music fading out"] as Array[String])
	assert_eq(_stops, 1)


func test_the_player_s_answer_is_shown() -> void:
	_console.music_player = func(track: String) -> String: return "Already playing %s" % track
	assert_eq(_console.run("play reel"), ["Already playing test_reel"] as Array[String])


func test_play_completes_with_tab() -> void:
	assert_eq(_console.complete("play sketch_t"), "play sketch_tide ")
	assert_eq(_console.complete("pla"), "play ")


func test_a_console_without_music_says_so_and_completes_nothing() -> void:
	var bare := Console.new(_state)
	assert_eq(bare.run("play reel"), ["No music here"] as Array[String])
	assert_eq(bare.run("stop"), ["No music here"] as Array[String])
	assert_eq(bare.complete("play s"), "play s")
