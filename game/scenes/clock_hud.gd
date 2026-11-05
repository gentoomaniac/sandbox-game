class_name ClockHud
extends CanvasLayer
## Date (day, season, year) and time in the top left corner. On its own canvas layer, so
## the day/night tint doesn't touch it.

@onready var _label: Label = $Label


func show_time(clock: GameClock) -> void:
	_label.text = "%s · %s" % [clock.date_text(), clock.time_text()]
