class_name GameClockTicker
extends RefCounted
## Turns the real time of the game scene into game minutes: the fraction of a minute carries over
## to the next frame, and F2 runs time faster (for testing).

## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0

var is_fast_forward := false
## Whether something other than the game's own state keeps the time still: a screenshot with
## TIME=... must show exactly that time, and time stands still while the screen is black (a
## message there may wait long for a key).
var is_held: Callable

var _state: GameState
var _weather_view: WeatherView
var _show_clock: Callable
var _pending_minutes := 0.0


func _init(state: GameState, weather_view: WeatherView, show_clock: Callable) -> void:
	_state = state
	_weather_view = weather_view
	_show_clock = show_clock


## Lets `delta` seconds pass, unless the time is held or the console's freeze is on.
func tick(delta: float) -> void:
	if is_held.call() or _state.cheats.is_time_stopped:
		return
	var rate := (
		GameClock.GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if is_fast_forward else 1.0)
	)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		_state.pass_awake_time(whole_minutes)
		_weather_view.minutes_passed(whole_minutes)
		_show_clock.call()
