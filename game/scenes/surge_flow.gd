class_name SurgeFlow
extends Node
## What the game scene does about the storm surge (see design/world/storm-surge.md): the warning
## line when one is rolled. Main creates it with the game it shows.


func _init(state: GameState, notifications: NotificationHud) -> void:
	state.world.surge.coming.connect(
		func(level: float, start_minute: int) -> void:
			var time := Sun.time_text(start_minute % GameClock.MINUTES_PER_DAY)
			notifications.post_line(
				"Storm surge: the sea will run over the dykes at %s (%.1f m)" % [time, level]
			)
	)
