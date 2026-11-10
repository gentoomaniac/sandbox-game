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


## The rest of a skip has passed without being played: `minutes` of it, and `clock` shows the time
## it ended at. After the `advance` of the same minutes.
func skipped(_minutes: int, _clock: GameClock) -> void:
	pass


static func is_hour_end(clock: GameClock) -> bool:
	return clock.minute_of_day % GameClock.MINUTES_PER_HOUR == 0


static func is_day_end(clock: GameClock) -> bool:
	return clock.minute_of_day == 0
