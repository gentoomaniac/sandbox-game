extends MusicPlayerCase
## MusicDirector on the tiny pieces of MusicPlayerCase: "tiny" by day and "other" from the
## afternoon to the morning. What it chooses is asked of `next_piece` with the time played set by
## hand; the real thing (it starts the music, takes turns, follows the door, stays quiet once
## stopped) runs on short times.

const DIRECTOR_RULES := {
	"everyday": {"pieces": ["tiny", "other"], "min_seconds": 0.2, "switch_seconds": 0.4},
	"piece.tiny": {"hours": [4, 22]},
	"piece.other": {"hours": [15, 7]},
	"indoors": {"channel_levels": [0.5, 0.7, 0.8, 0.0], "fade_seconds": 0.05},
	"versions": {"fade_seconds": 0.05},
	"fades": {"crossfade_seconds": 0.05, "stop_seconds": 0.05},
	"cache": {"max_megabytes": 10},
}
const NOON := 12
const EVENING := 18
const NIGHT := 23

## What the director chooses by: null for no game yet.
var _moment: MusicMoment
var _director: MusicDirector


func before_each() -> void:
	super.before_each()
	_music.crossfade_seconds = 0.05
	_music.rules = MusicRules.new(DIRECTOR_RULES)
	_moment = MusicMoment.new(NOON)
	_director = autofree(
		MusicDirector.new(
			_music, func() -> MusicMoment: return _moment, MusicRules.new(DIRECTOR_RULES)
		)
	)
	watch_signals(_music)


func _start_director() -> void:
	add_child(_director)


## Waits for the next piece to start; returns its name.
func _next_started() -> String:
	await wait_for_signal(_music.started, PATIENCE_SECONDS)
	return get_signal_parameters(_music, "started")[0]


## What the director would choose at `hour` after `seconds` of `track`.
func _next_after(track: String, seconds: float, hour: int) -> String:
	_music.play(track)
	_director._played_seconds = seconds
	return _director.next_piece(MusicMoment.new(hour))


func test_the_game_plays_music_by_itself_only_where_it_is_heard() -> void:
	assert_true(MusicDirector.is_wanted(false, "PulseAudio"))
	assert_false(MusicDirector.is_wanted(true, "PulseAudio"), "muted")
	assert_false(MusicDirector.is_wanted(false, "Dummy"), "headless")


func test_the_pieces_that_fit_go_by_the_hour() -> void:
	var rules := MusicRules.new(DIRECTOR_RULES)
	assert_eq(rules.fitting_pieces(NOON), ["tiny"] as Array[String])
	assert_eq(rules.fitting_pieces(EVENING), ["tiny", "other"] as Array[String])
	assert_eq(rules.fitting_pieces(NIGHT), ["other"] as Array[String], "over midnight")
	assert_eq(rules.fitting_pieces(4), ["tiny", "other"] as Array[String])
	assert_eq(rules.fitting_pieces(7), ["tiny"] as Array[String], "the end hour is not in")
	var values := DIRECTOR_RULES.duplicate(true)
	values["piece.tiny"]["hours"] = [1, 2]
	values["piece.other"]["hours"] = [1, 2]
	assert_eq(MusicRules.new(values).fitting_pieces(NOON), ["tiny", "other"] as Array[String])


func test_a_piece_plays_its_least_time_before_another_takes_over() -> void:
	assert_eq(_next_after("tiny", 0.1, NIGHT), "", "too soon, though the hour is over")
	assert_eq(_next_after("other", 0.25, NOON), "tiny", "then the piece of the hour")


func test_a_piece_that_fits_gives_way_to_the_next_that_fits_after_its_time() -> void:
	assert_eq(_next_after("tiny", 0.3, EVENING), "", "it fits and has time left")
	assert_eq(_next_after("tiny", 0.5, EVENING), "other")
	assert_eq(_next_after("other", 0.5, EVENING), "tiny", "round to the first")
	assert_eq(_next_after("tiny", 5.0, NOON), "", "the only one that fits plays on")


func test_a_piece_the_console_played_goes_on_with_one_that_fits() -> void:
	_write_module("third")
	assert_eq(_next_after("third", 0.3, NIGHT), "other")


func test_nothing_starts_before_there_is_a_moment() -> void:
	_moment = null
	_start_director()
	await wait_process_frames(3)
	assert_eq(_music.wanted_track(), "")
	_moment = MusicMoment.new(NIGHT)
	assert_eq(await _next_started(), "other", "the piece of the hour")


func test_the_pieces_take_turns_while_both_fit() -> void:
	_moment = MusicMoment.new(EVENING)
	_start_director()
	var order: Array[String] = []
	for count in 3:
		order.append(await _next_started())
	assert_eq(order, ["tiny", "other", "tiny"] as Array[String])


func test_indoors_the_quieter_mix_plays() -> void:
	_start_director()
	await _next_started()
	_moment = MusicMoment.new(NOON, true)
	await wait_process_frames(2)
	assert_true(_music.is_indoors())
	_moment = MusicMoment.new(NOON, false)
	await wait_process_frames(2)
	assert_false(_music.is_indoors(), "the whole mix outside")


func test_with_the_classic_art_the_chiptune_version_plays() -> void:
	_start_director()
	await _next_started()
	assert_false(_music.is_classic(), "the 32 px art: the fuller version")
	_moment = MusicMoment.new(NOON, false, true)
	await wait_process_frames(2)
	assert_true(_music.is_classic())


func test_a_stopped_player_stays_quiet() -> void:
	_start_director()
	await _next_started()
	_music.stop()
	var started_before: int = get_signal_emit_count(_music, "started")
	await wait_seconds(1.0)
	assert_eq(get_signal_emit_count(_music, "started"), started_before)
	assert_false(_music.is_playing())


func test_the_moment_of_a_game_is_its_hour_and_place() -> void:
	var state := GameState.new()
	state.clock.minute_of_day = 17 * GameClock.MINUTES_PER_HOUR + 59
	var moment := MusicMoment.of(state, true)
	assert_eq([moment.hour, moment.is_inside, moment.is_classic_art], [17, false, true])
