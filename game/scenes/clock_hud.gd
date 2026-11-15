class_name ClockHud
extends CanvasLayer
## Weekday, date (day, season, year) and time in the top left corner. On its own canvas layer, so
## the day/night tint doesn't touch it.

@onready var _label: Label = $Label


func show_time(clock: GameClock) -> void:
	_label.text = text_of(clock)


## "Monday, 10th day of Winter Year 1 · 06:00"
static func text_of(clock: GameClock) -> String:
	return "%s, %s · %s" % [clock.weekday_name(), clock.date_text(), clock.time_text()]
