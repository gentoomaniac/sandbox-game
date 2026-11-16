class_name SurgeFlow
extends Node
## What the game scene does about the storm surge (see design/world/storm-surge.md): the warning
## line when one is rolled, and the work of the flood a few tiles each frame. Main creates it with
## the game it shows.

## The key of the warning (see NotificationHud `post`).
const WARNING_NOTE := &"surge"

var _state: GameState


func _init(state: GameState, notifications: NotificationHud) -> void:
	_state = state
	state.world.surge.coming.connect(
		func(level: float, start_minute: int) -> void:
			var time := Sun.time_text(start_minute % GameClock.MINUTES_PER_DAY)
			notifications.post(
				WARNING_NOTE,
				"Storm surge: the sea will run over the dykes at %s (%.1f m)" % [time, level],
				NotificationHud.Tone.ERROR
			)
	)
	state.world.flood.breached.connect(
		func(_count: int) -> void:
			notifications.post(
				WARNING_NOTE, "The sea is running over the dyke", NotificationHud.Tone.ERROR
			)
	)


func _process(delta: float) -> void:
	_state.world.flood.step(_state.world, delta)
