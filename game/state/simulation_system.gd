class_name SimulationSystem
extends RefCounted
## Something that changes with the passing of game time, run by the Simulation after the clock
## has moved. Spans never cross a full hour, so a span that ends on one (see `is_hour_end`) is
## the end of the hour, and one that ends at midnight (see `is_day_end`) the end of the day.


## `minutes` have passed and `clock` shows the time they ended at.
func advance(_minutes: int, _clock: GameClock) -> void:
	pass


## One minute of a skip that is played through like the frames of play would (see Simulation
## `skip`): `clock` shows the time at its end.
func walked_minute(_clock: GameClock) -> void:
	pass


## The rest of a skip, `minutes` of it, is about to be made up for: its `advance` and then
## `skipped` (or `skipped_over_frames`) follow. For a system that leaves what the skip's spans
## would do for its end, to spread it over frames.
func skip_begins(_minutes: int) -> void:
	pass


## The rest of a skip has passed without being played: `minutes` of it, and `clock` shows the time
## it ended at. After the `advance` of the same minutes.
func skipped(_minutes: int, _clock: GameClock) -> void:
	pass


## `skipped` for a skip spread over frames (see Simulation `skip_over_frames`): a system with much
## to do awaits `next_frame` (a Callable that gives the signal of the next frame) when it has used
## up its share of one.
func skipped_over_frames(minutes: int, clock: GameClock, _next_frame: Callable) -> void:
	skipped(minutes, clock)


static func is_hour_end(clock: GameClock) -> bool:
	return clock.minute_of_day % GameClock.MINUTES_PER_HOUR == 0


static func is_day_end(clock: GameClock) -> bool:
	return clock.minute_of_day == 0
