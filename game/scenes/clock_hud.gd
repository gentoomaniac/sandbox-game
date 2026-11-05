class_name ClockHud
extends CanvasLayer
## Day and time in the top left corner. On its own canvas layer, so the day/night tint
## doesn't touch it.

@onready var _label: Label = $Label


func show_time(clock: GameClock) -> void:
	_label.text = "Day %d · %s" % [clock.day, clock.time_text()]
