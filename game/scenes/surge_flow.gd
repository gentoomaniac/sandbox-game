class_name SurgeFlow
extends Node
## What the game scene shows of the storm surge (see design/world/storm-surge.md): the warning line
## when one is rolled and when the sea breaks a dyke. The flood itself runs in the state (see
## SurgeUpkeep `frame_work`). Main creates it with the game it shows.

## The key of the warning (see NotificationHud `post`).
const WARNING_NOTE := &"surge"


func _init(state: GameState, notifications: NotificationHud) -> void:
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
