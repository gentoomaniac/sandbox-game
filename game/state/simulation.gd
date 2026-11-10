class_name Simulation
extends RefCounted
## The one owner of the game's time: whatever moves the clock (the frames of play, a night's
## sleep, passing out, the console's `skip`) calls `advance`, and everything that changes with
## time follows from it. The clock is cut at every full hour, so a span of any length passes as
## the same hours played one after the other.

var clock: GameClock


func _init(game_clock: GameClock) -> void:
	clock = game_clock


## Lets `minutes` game minutes pass, in whole-hour steps.
func advance(minutes: int) -> void:
	assert(minutes >= 0, "Time only moves forward")
	var left := minutes
	while left > 0:
		var to_full_hour := (
			GameClock.MINUTES_PER_HOUR - clock.minute_of_day % GameClock.MINUTES_PER_HOUR
		)
		var span := mini(left, to_full_hour)
		clock.advance(span)
		left -= span
