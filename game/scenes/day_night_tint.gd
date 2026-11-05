class_name DayNightTint
extends CanvasModulate
## Colours the world canvas by time of day. Night stays bluish and readable, not black.

## Hour of day to tint colour. Blended linearly in between, and wraps around midnight.
const STOPS := {
	0.0: Color(0.40, 0.46, 0.74),
	5.0: Color(0.40, 0.46, 0.74),
	6.5: Color(1.00, 0.82, 0.70),
	8.5: Color(1.00, 1.00, 1.00),
	17.0: Color(1.00, 1.00, 1.00),
	18.5: Color(1.00, 0.70, 0.52),
	20.5: Color(0.62, 0.52, 0.72),
	22.0: Color(0.40, 0.46, 0.74),
	24.0: Color(0.40, 0.46, 0.74),
}

var _gradient := Gradient.new()


func _init() -> void:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for hour: float in STOPS:
		offsets.append(hour / 24.0)
		colors.append(STOPS[hour])
	_gradient.offsets = offsets
	_gradient.colors = colors


func show_time(clock: GameClock) -> void:
	color = _gradient.sample(float(clock.minute_of_day) / GameClock.MINUTES_PER_DAY)
