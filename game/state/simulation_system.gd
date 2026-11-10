class_name SimulationSystem
extends RefCounted
## Something that changes with the passing of game time, run by the Simulation after the clock
## has moved. Spans never cross a full hour, so a span that ends on one (see `is_hour_end`) is
## the end of the hour, and one that ends at midnight (see `is_day_end`) the end of the day.


## `minutes` have passed and `clock` shows the time they ended at.
func advance(_minutes: int, _clock: GameClock) -> void:
	pass


static func is_hour_end(clock: GameClock) -> bool:
	return clock.minute_of_day % GameClock.MINUTES_PER_HOUR == 0


static func is_day_end(clock: GameClock) -> bool:
	return clock.minute_of_day == 0
