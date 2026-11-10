class_name SimulationSystem
extends RefCounted
## Something that changes with the passing of game time, run by the Simulation after the clock
## has moved. Spans never cross a full hour, so a span that ends at midnight is the end of the
## day (see `is_day_end`), and one that ends on a full hour the end of the hour.


## `minutes` have passed and `clock` shows the time they ended at.
func advance(_minutes: int, _clock: GameClock) -> void:
	pass


static func is_day_end(clock: GameClock) -> bool:
	return clock.minute_of_day == 0
